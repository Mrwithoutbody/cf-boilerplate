// Serwer-proxy: web UI + most do Claude Code (headless CLI, streaming).
// Zarządzanie sesjami: lista sesji → rozmowa w sesji → zakończ → powrót do listy.
// Telefon widzi to samo co terminal: tekst Claude, edycje plików, komendy.
// Dostęp: capability URL — klucz we fragmencie linku z QR (#k=...), gate na
// każdym endpoincie poza statycznym HTML. Zero zależności — czysty Node.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFile, readdir, stat } from 'node:fs/promises';
import { existsSync, readFileSync } from 'node:fs';
import { randomUUID, randomBytes, timingSafeEqual } from 'node:crypto';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
// Projekt = rodzic .fs/ (server.js jest w .fs/control/). Futurestack żyje w
// .fs/, kod projektu w roocie — Claude Code pracuje na roocie, nie na podfolderze.
const PROJECT_DIR = resolve(__dirname, '..', '..');
const STYLES_DIR = join(__dirname, 'styles');      // presety stylu odpowiedzi (*.md)
const PORT = Number(process.env.PORT || 3000);
const CLAUDE_BIN = process.env.CLAUDE_BIN || 'claude';
// Klucz dostępu = jedyna granica zaufania. Rotuje z każdym startem (jak URL
// tunelu). W QR ląduje we FRAGMENCIE (#k=...) — fragment nie opuszcza
// przeglądarki: nie ma go w requestach, Refererze ani logach tunelu.
const KEY = process.env.PROXY_KEY || randomBytes(16).toString('hex');
// Headless = nie ma jak kliknąć zgody, komendy spoza listy są auto-odrzucane.
// Guardrail przeciw pomyłkom Claude'a, NIE granica bezpieczeństwa — tą jest
// gate z kluczem (git/npm i tak dają dowolne wykonanie, np. 'npm exec').
// Baza (git/npm/wrangler) + rozszerzenia per projekt z FS_ALLOW (.fs/target.env
// albo .fs/.env), np. FS_ALLOW=cargo,go,pnpm,bun → build/test nie-npm stacków.
const ALLOWED_TOOLS = ['Bash(npx wrangler:*)', 'Bash(git:*)', 'Bash(npm:*)',
  ...String(process.env.FS_ALLOW || '').split(',').map(s => s.trim()).filter(Boolean)
    .map(t => `Bash(${t}:*)`)];
// Katalog gdzie Claude Code trzyma transkrypty sesji dla PROJECT_DIR (ścieżka → myślniki).
const PROJDIR = join(homedir(), '.claude', 'projects', PROJECT_DIR.replace(/[/.]/g, '-'));

if (process.env.ANTHROPIC_API_KEY) {
  console.warn('! ANTHROPIC_API_KEY ustawiony — claude pójdzie przez płatne API, nie abonament.');
}

// ── Renderowanie zdarzeń stream-json do prostych bloków {who,text} ──────────
function toolLine(b) {
  const n = b.name, i = b.input || {};
  if (n === 'Edit' || n === 'MultiEdit' || n === 'Write') return `${n} ${i.file_path || ''}`;
  if (n === 'Read') return `Read ${i.file_path || ''}`;
  if (n === 'Bash') return `$ ${String(i.command || '').slice(0, 200)}`;
  if (n === 'Glob' || n === 'Grep') return `${n} ${i.pattern || ''}`;
  return `${n} ${JSON.stringify(i).slice(0, 160)}`;
}
// Zwraca tablicę bloków {who,text}. who: user|claude|tool|result.
function renderEvent(ev) {
  const out = [];
  if (ev?.type === 'assistant' && ev.message?.content) {
    for (const b of ev.message.content) {
      if (b.type === 'text' && b.text && b.text.trim()) out.push({ who: 'claude', text: b.text });
      else if (b.type === 'tool_use') out.push({ who: 'tool', text: toolLine(b) });
    }
  } else if (ev?.type === 'user' && ev.message?.content) {
    const c = ev.message.content;
    if (Array.isArray(c)) {
      for (const b of c) {
        if (b.type === 'text' && b.text && b.text.trim()) out.push({ who: 'user', text: b.text });
        else if (b.type === 'tool_result') {
          let t = b.content;
          if (Array.isArray(t)) t = t.map(x => x.text || '').join('');
          t = String(t || '').trim();
          if (t) out.push({ who: 'result', text: t.slice(0, 500) });
        }
      }
    } else if (typeof c === 'string' && c.trim()) {
      out.push({ who: 'user', text: c });
    }
  }
  return out;
}

// ── Style odpowiedzi: presety styles/*.md doklejane przez --append-system-prompt ─
async function listStyles() {
  try {
    const files = await readdir(STYLES_DIR);
    return files.filter(f => f.endsWith('.md')).map(f => f.slice(0, -3)).sort();
  } catch { return []; }
}
// Treść czytana per request (edycja bez restartu). Walidacja nazwy = anty path-traversal.
async function loadStyle(name) {
  const names = await listStyles();
  if (!name || !names.includes(name)) return '';
  try { return (await readFile(join(STYLES_DIR, name + '.md'), 'utf8')).trim(); } catch { return ''; }
}
// System prompt = protokół pracy (zawsze) + wybrany ton.
async function systemPrompt(styleName) {
  const parts = [];
  try { parts.push((await readFile(join(__dirname, 'protocol.md'), 'utf8')).trim()); } catch {}
  const s = await loadStyle(styleName);
  if (s) parts.push(s);
  return parts.join('\n\n');
}

// ── URL aplikacji (podgląd wyników). Zależny od targetu, nie tylko Workers:
//    1. jawny FS_APP_URL (target.env) — dowolny stack (Pages custom domain, Expo, ...)
//    2. Cloudflare Pages (pages_build_output_dir) → <name>.pages.dev
//    3. Cloudflare Worker → <name>.<subdomena>.workers.dev (subdomena z CF API)
let appUrlCache = null;
async function getAppUrl() {
  if (appUrlCache !== null) return appUrlCache;
  appUrlCache = '';
  try {
    if (process.env.FS_APP_URL) { appUrlCache = process.env.FS_APP_URL; return appUrlCache; }
    let name = '', isPages = false;
    for (const wf of ['wrangler.jsonc', 'wrangler.json', 'wrangler.toml']) {
      try {
        const txt = await readFile(join(PROJECT_DIR, wf), 'utf8');
        if (/pages_build_output_dir/.test(txt)) isPages = true;
        name = (txt.match(/"name"\s*:\s*"([^"]+)"/) || txt.match(/^name\s*=\s*"([^"]+)"/m) || [])[1] || '';
        if (name) break;
      } catch {}
    }
    if (isPages && name) { appUrlCache = `https://${name}.pages.dev`; return appUrlCache; }
    const acc = process.env.CLOUDFLARE_ACCOUNT_ID, token = process.env.CLOUDFLARE_API_TOKEN;
    if (!name || !acc || !token) return appUrlCache;
    const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${acc}/workers/subdomain`,
      { headers: { authorization: `Bearer ${token}` } });
    const sub = (await r.json())?.result?.subdomain;
    if (sub) appUrlCache = `https://${name}.${sub}.workers.dev`;
  } catch {}
  return appUrlCache;
}

// ── Sesje: lista + historia z transkryptów na dysku ────────────────────────
async function listSessions() {
  if (!existsSync(PROJDIR)) return [];
  const files = (await readdir(PROJDIR)).filter(f => f.endsWith('.jsonl'));
  const out = [];
  for (const f of files) {
    const id = f.slice(0, -6);
    const full = join(PROJDIR, f);
    let title = '', count = 0, mtime = 0;
    try {
      mtime = (await stat(full)).mtimeMs;
      const lines = readFileSync(full, 'utf8').split('\n');
      for (const line of lines) {
        if (!line.trim()) continue;
        let ev; try { ev = JSON.parse(line); } catch { continue; }
        for (const blk of renderEvent(ev)) {
          if (blk.who === 'user' || blk.who === 'claude') count++;
          if (!title && blk.who === 'user') title = blk.text.replace(/\s+/g, ' ').slice(0, 60);
        }
      }
    } catch { /* pomiń uszkodzony plik */ }
    out.push({ id, title: title || '(pusta)', count, mtime });
  }
  out.sort((a, b) => b.mtime - a.mtime);
  return out;
}

function sessionHistory(id) {
  const full = join(PROJDIR, id + '.jsonl');
  if (!existsSync(full)) return [];
  const blocks = [];
  for (const line of readFileSync(full, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    let ev; try { ev = JSON.parse(line); } catch { continue; }
    blocks.push(...renderEvent(ev));
  }
  return blocks;
}

function sendJSON(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'content-type': 'application/json; charset=utf-8' });
  res.end(body);
}
function readBody(req) {
  return new Promise((ok) => {
    let b = ''; req.on('data', c => { b += c; if (b.length > 1e6) req.destroy(); });
    req.on('end', () => ok(b));
    req.on('close', () => ok(''));   // po destroy() 'end' nie odpali — nie zostawiaj wiszącej promisy
  });
}
function checkKey(req) {
  const k = String(req.headers['x-key'] || '');
  return k.length === KEY.length && timingSafeEqual(Buffer.from(k), Buffer.from(KEY));
}
// Kolejka per sesja: drugi /ask na tę samą sesję czeka aż pierwszy skończy —
// współbieżne 'claude --resume' na jednym transkrypcie to korupcja historii.
const queues = new Map();
function enqueue(id, task) {
  const next = (queues.get(id) || Promise.resolve()).then(task, task);
  queues.set(id, next);
  next.finally(() => { if (queues.get(id) === next) queues.delete(id); });
  return next;
}

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, 'http://x');
  const path = u.pathname;

  // Gate: jedne drzwi, jeden klucz. Bez klucza tylko statyczny HTML — sam
  // w sobie bezużyteczny (UI bez klucza w hashu niczego nie wywoła).
  // Custom header 'x-key' = przy cross-origin wymusza preflight → CSRF odpada.
  if (!(req.method === 'GET' && (path === '/' || path === '/index.html')) && !checkKey(req)) {
    return sendJSON(res, 401, { error: 'brak klucza — zeskanuj aktualny QR' });
  }

  // Web UI
  if (req.method === 'GET' && (path === '/' || path === '/index.html')) {
    const html = await readFile(join(__dirname, 'public', 'index.html'), 'utf8');
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    return res.end(html);
  }

  // Lista stylów dla przełącznika w UI
  if (req.method === 'GET' && path === '/styles') {
    return sendJSON(res, 200, { styles: await listStyles() });
  }

  // Publiczny adres aplikacji (podgląd wyników na drugim urządzeniu)
  if (req.method === 'GET' && path === '/appurl') {
    return sendJSON(res, 200, { url: await getAppUrl() });
  }

  // Lista sesji
  if (req.method === 'GET' && path === '/sessions') {
    try { return sendJSON(res, 200, await listSessions()); }
    catch (e) { return sendJSON(res, 500, { error: String(e) }); }
  }

  // Nowa sesja — tylko rezerwuje ID; plik powstaje przy pierwszej wiadomości.
  if (req.method === 'POST' && path === '/session/new') {
    return sendJSON(res, 200, { id: randomUUID() });
  }

  // Historia sesji (do wyświetlenia po wejściu)
  if (req.method === 'GET' && path.startsWith('/session/') && path.endsWith('/history')) {
    const id = path.slice('/session/'.length, -'/history'.length);
    if (!/^[0-9a-f-]{36}$/.test(id)) return sendJSON(res, 400, { error: 'zła sesja' });
    return sendJSON(res, 200, sessionHistory(id));
  }

  // Most do Claude Code — streaming bloków {who,text} jako NDJSON
  if (req.method === 'POST' && path === '/ask') {
    const body = await readBody(req);
    let prompt = '', sessionId = '', styleName = '';
    try { const j = JSON.parse(body); prompt = j.prompt || ''; sessionId = j.sessionId || ''; styleName = j.style || ''; }
    catch { prompt = body; }
    prompt = String(prompt).trim();
    if (!prompt) return sendJSON(res, 400, { error: 'pusty prompt' });
    if (!/^[0-9a-f-]{36}$/.test(sessionId)) return sendJSON(res, 400, { error: 'brak/zła sesja' });

    if (!existsSync(PROJECT_DIR)) {
      res.writeHead(200, { 'content-type': 'application/x-ndjson; charset=utf-8' });
      return res.end(JSON.stringify({ who: 'result', text: 'Brak katalogu projektu. Uruchom .fs/setup.sh.' }) + '\n');
    }

    res.writeHead(200, {
      'content-type': 'application/x-ndjson; charset=utf-8',
      'cache-control': 'no-cache',
      'transfer-encoding': 'chunked',
    });

    const emit = (o) => { if (!res.destroyed && !res.writableEnded) res.write(JSON.stringify(o) + '\n'); };

    // Cała tura idzie przez kolejkę sesji. 'started' sprawdzany dopiero gdy
    // poprzednia tura skończy — wcześniej nie wiadomo, czy transkrypt istnieje.
    enqueue(sessionId, async () => {
      if (res.destroyed || res.writableEnded) return;   // klient odpadł w kolejce
      // Nowa sesja gdy plik jeszcze nie istnieje, inaczej wznów.
      const started = existsSync(join(PROJDIR, sessionId + '.jsonl'));
      const sys = await systemPrompt(styleName);
      const args = ['--print', '--output-format', 'stream-json', '--verbose',
                    '--permission-mode', 'acceptEdits', '--allowedTools', ...ALLOWED_TOOLS];
      if (started) args.push('--resume', sessionId);
      else args.push('--session-id', sessionId);
      if (sys) args.push('--append-system-prompt', sys);
      args.push('-p', prompt);

      await new Promise((done) => {
        const child = spawn(CLAUDE_BIN, args, {
          cwd: PROJECT_DIR, env: process.env, stdio: ['ignore', 'pipe', 'pipe'],
        });

        let buf = '';
        child.stdout.on('data', chunk => {
          buf += chunk.toString();
          let nl;
          while ((nl = buf.indexOf('\n')) >= 0) {
            const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
            if (!line.trim()) continue;
            try {
              const ev = JSON.parse(line);
              for (const blk of renderEvent(ev)) {
                if (blk.who === 'user') continue;   // telefon już pokazał prompt usera
                emit(blk);
              }
            } catch { /* pomiń nie-JSON */ }
          }
        });
        child.stderr.on('data', d => emit({ who: 'result', text: '[err] ' + d.toString().slice(0, 300) }));
        // Flaga chroni przed podwójnym res.end(): przy błędzie spawn Node emituje 'error' ORAZ 'close'.
        let finished = false;
        child.on('close', () => { if (finished) return; finished = true; emit({ who: 'done', text: '' }); res.end(); done(); });
        child.on('error', e => { if (finished) return; finished = true; emit({ who: 'result', text: '[spawn error] ' + e.message }); res.end(); done(); });
        res.on('close', () => { if (!res.writableEnded) child.kill(); });
      });
    });
    return;
  }

  // Deploy LIVE — odpala guarded .fs/scripts/deploy.sh (wykrywa target, guard
  // wymusza scoped token / blokuje boilerplate, commit + właściwa komenda deployu),
  // streaming wyjścia do telefonu. To idzie na PRODUKCJĘ. Klucz już sprawdzony wyżej.
  if (req.method === 'POST' && path === '/deploy') {
    res.writeHead(200, {
      'content-type': 'application/x-ndjson; charset=utf-8',
      'cache-control': 'no-cache',
      'transfer-encoding': 'chunked',
    });
    const emit = (o) => { if (!res.destroyed && !res.writableEnded) res.write(JSON.stringify(o) + '\n'); };
    const script = join(__dirname, '..', 'scripts', 'deploy.sh');
    emit({ who: 'result', text: '🚀 Deploy LIVE — start…' });
    const child = spawn('bash', [script, 'deploy z telefonu'], {
      cwd: PROJECT_DIR, env: process.env, stdio: ['ignore', 'pipe', 'pipe'],
    });
    // Wspólny bufor stdout+stderr → linie jako bloki {who:'result'}.
    const bufs = { o: '', e: '' };
    const pump = (k) => (d) => {
      bufs[k] += d.toString();
      let nl;
      while ((nl = bufs[k].indexOf('\n')) >= 0) {
        const line = bufs[k].slice(0, nl); bufs[k] = bufs[k].slice(nl + 1);
        if (line.trim()) emit({ who: 'result', text: line });
      }
    };
    child.stdout.on('data', pump('o'));
    child.stderr.on('data', pump('e'));
    let finished = false;
    child.on('close', (code) => {
      if (finished) return; finished = true;
      if (bufs.o.trim()) emit({ who: 'result', text: bufs.o });
      if (bufs.e.trim()) emit({ who: 'result', text: bufs.e });
      emit({ who: 'result', text: code === 0 ? '✅ LIVE — deploy OK' : `❌ deploy padł (exit ${code})` });
      emit({ who: 'done', text: '' });
      res.end();
    });
    child.on('error', (e) => {
      if (finished) return; finished = true;
      emit({ who: 'result', text: '[spawn error] ' + e.message });
      emit({ who: 'done', text: '' });
      res.end();
    });
    res.on('close', () => { if (!res.writableEnded) child.kill(); });
    return;
  }

  res.writeHead(404); res.end('not found');
});

// Loopback only: jedyne wejście z zewnątrz to tunel (łączy się lokalnie).
server.listen(PORT, '127.0.0.1', async () => {
  console.log(`▶ proxy: http://localhost:${PORT}/#k=${KEY}  (projekt: ${PROJECT_DIR})`);
  console.log(`  sesje z: ${PROJDIR}`);
  const url = await getAppUrl();
  console.log(url ? `  🌐 aplikacja (podgląd wyników): ${url}`
                  : '  ! adres aplikacji nieznany (brak wrangler.* w roocie lub CLOUDFLARE_* w .env)');
  console.log('  Wystaw przez: cloudflared tunnel --url http://localhost:' + PORT);
});
