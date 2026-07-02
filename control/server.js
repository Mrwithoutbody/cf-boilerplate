// Serwer-proxy: web UI głosowy + most do Claude Code (headless CLI, streaming).
// Sterowanie z telefonu przez Cloudflare Tunnel. WYSTAWIAĆ TYLKO za Cloudflare Access.
// Zero zależności — czysty Node.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_DIR = resolve(__dirname, '..', 'app');   // katalog budowanej aplikacji
const STYLES_DIR = join(__dirname, 'styles');      // presety stylu odpowiedzi (*.md)
const PORT = Number(process.env.PORT || 3000);

// Lista dostępnych stylów = pliki styles/*.md (nazwa = basename bez .md).
async function listStyles() {
  try {
    const files = await readdir(STYLES_DIR);
    return files.filter(f => f.endsWith('.md')).map(f => f.slice(0, -3)).sort();
  } catch { return []; }
}

// Treść stylu czytana per request — edycja pliku działa bez restartu serwera.
// Walidacja nazwy: tylko istniejący preset (anty path-traversal).
async function loadStyle(name) {
  const names = await listStyles();
  if (!name || !names.includes(name)) return '';
  try { return (await readFile(join(STYLES_DIR, name + '.md'), 'utf8')).trim(); } catch { return ''; }
}

if (!process.env.ANTHROPIC_API_KEY) {
  console.warn('! ANTHROPIC_API_KEY nieustawiony — Claude Code może nie ruszyć.');
}

const server = http.createServer(async (req, res) => {
  // Web UI
  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    try {
      const html = await readFile(join(__dirname, 'public', 'index.html'), 'utf8');
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      return res.end(html);
    } catch (e) {
      res.writeHead(500); return res.end('brak index.html: ' + e.message);
    }
  }

  // Lista stylów dla przełącznika w UI.
  if (req.method === 'GET' && req.url === '/styles') {
    res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
    return res.end(JSON.stringify({ styles: await listStyles() }));
  }

  // Most do Claude Code — streaming odpowiedzi
  if (req.method === 'POST' && req.url === '/ask') {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 1e6) req.destroy(); });
    req.on('end', async () => {
      let prompt = '', styleName = '';
      try { const j = JSON.parse(body); prompt = j.prompt || ''; styleName = j.style || ''; }
      catch { prompt = body; }
      prompt = String(prompt).trim();
      if (!prompt) { res.writeHead(400); return res.end('pusty prompt'); }

      res.writeHead(200, {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'no-cache',
        'transfer-encoding': 'chunked',
      });

      // Claude Code headless, w katalogu aplikacji, output strumieniowy JSON.
      const style = await loadStyle(styleName);
      const args = [
        '--print',
        '--output-format', 'stream-json',
        '--verbose',
        '--permission-mode', 'acceptEdits',
      ];
      if (style) args.push('--append-system-prompt', style);
      args.push('-p', prompt);
      const child = spawn('claude', args, { cwd: APP_DIR, env: process.env });

      let buf = '';
      child.stdout.on('data', chunk => {
        buf += chunk.toString();
        let nl;
        while ((nl = buf.indexOf('\n')) >= 0) {
          const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
          if (!line.trim()) continue;
          try {
            const ev = JSON.parse(line);
            const text = extractText(ev);
            if (text) res.write(text);
          } catch {
            res.write(line + '\n');   // nie-JSON → przekaż surowo
          }
        }
      });
      child.stderr.on('data', d => res.write('\n[err] ' + d.toString()));
      // Flaga chroni przed podwójnym res.end(): przy błędzie spawn Node emituje
      // 'error' ORAZ 'close' — drugi handler by rzucił write-after-end.
      let finished = false;
      child.on('close', code => { if (finished) return; finished = true; res.write(`\n\n— koniec (exit ${code}) —\n`); res.end(); });
      child.on('error', e => { if (finished) return; finished = true; res.write('\n[spawn error] ' + e.message); res.end(); });
      // Ubij dziecko tylko gdy klient rozłączył się PRZED zakończeniem odpowiedzi.
      res.on('close', () => { if (!res.writableEnded) child.kill(); });
    });
    return;
  }

  res.writeHead(404); res.end('not found');
});

// Wyciąga tekst asystenta ze zdarzeń stream-json Claude Code.
function extractText(ev) {
  if (ev?.type === 'assistant' && ev.message?.content) {
    return ev.message.content.filter(b => b.type === 'text').map(b => b.text).join('');
  }
  if (ev?.type === 'result' && typeof ev.result === 'string') return '';
  return '';
}

server.listen(PORT, () => {
  console.log(`▶ proxy: http://localhost:${PORT}  (app: ${APP_DIR})`);
  console.log('  Wystaw przez: cloudflared tunnel --url http://localhost:' + PORT);
});
