// Serwer-proxy: web UI + most do Claude Code (headless CLI, streaming).
// Zarządzanie sesjami: lista sesji → rozmowa w sesji → zakończ → powrót do listy.
// Telefon widzi to samo co terminal: tekst Claude, edycje plików, komendy.
// WYSTAWIAĆ TYLKO za Cloudflare Access. Zero zależności — czysty Node.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFile, readdir, stat } from 'node:fs/promises';
import { existsSync, readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_DIR = resolve(__dirname, '..', 'app');   // katalog budowanej aplikacji
const STYLES_DIR = join(__dirname, 'styles');      // presety stylu odpowiedzi (*.md)
const PORT = Number(process.env.PORT || 3000);
const CLAUDE_BIN = process.env.CLAUDE_BIN || 'claude';
// Katalog gdzie Claude Code trzyma transkrypty sesji dla APP_DIR (ścieżka → myślniki).
const PROJDIR = join(homedir(), '.claude', 'projects', APP_DIR.replace(/[/.]/g, '-'));

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
  });
}

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, 'http://x');
  const path = u.pathname;

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

    if (!existsSync(APP_DIR)) {
      res.writeHead(200, { 'content-type': 'application/x-ndjson; charset=utf-8' });
      return res.end(JSON.stringify({ who: 'result', text: 'Brak katalogu app/. Uruchom ./setup.sh (scaffold + deploy).' }) + '\n');
    }

    res.writeHead(200, {
      'content-type': 'application/x-ndjson; charset=utf-8',
      'cache-control': 'no-cache',
      'transfer-encoding': 'chunked',
    });

    const emit = (o) => res.write(JSON.stringify(o) + '\n');

    // Nowa sesja gdy plik jeszcze nie istnieje, inaczej wznów.
    const started = existsSync(join(PROJDIR, sessionId + '.jsonl'));
    const style = await loadStyle(styleName);
    const args = ['--print', '--output-format', 'stream-json', '--verbose', '--permission-mode', 'acceptEdits'];
    if (started) args.push('--resume', sessionId);
    else args.push('--session-id', sessionId);
    if (style) args.push('--append-system-prompt', style);
    args.push('-p', prompt);

    const child = spawn(CLAUDE_BIN, args, {
      cwd: APP_DIR, env: process.env, stdio: ['ignore', 'pipe', 'pipe'],
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
    child.on('close', () => { if (finished) return; finished = true; emit({ who: 'done', text: '' }); res.end(); });
    child.on('error', e => { if (finished) return; finished = true; emit({ who: 'result', text: '[spawn error] ' + e.message }); res.end(); });
    res.on('close', () => { if (!res.writableEnded) child.kill(); });
    return;
  }

  res.writeHead(404); res.end('not found');
});

server.listen(PORT, () => {
  console.log(`▶ proxy: http://localhost:${PORT}  (app: ${APP_DIR})`);
  console.log(`  sesje z: ${PROJDIR}`);
  console.log('  Wystaw przez: cloudflared tunnel --url http://localhost:' + PORT);
});
