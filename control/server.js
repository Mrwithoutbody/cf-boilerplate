// Serwer-proxy: web UI głosowy + most do Claude Code (headless CLI, streaming).
// Sterowanie z telefonu przez Cloudflare Tunnel. WYSTAWIAĆ TYLKO za Cloudflare Access.
// Zero zależności — czysty Node.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_DIR = resolve(__dirname, '..', 'app');   // katalog budowanej aplikacji
const PORT = Number(process.env.PORT || 3000);

if (!process.env.ANTHROPIC_API_KEY) {
  console.warn('! ANTHROPIC_API_KEY nieustawiony — Claude Code może nie ruszyć.');
}

const server = http.createServer(async (req, res) => {
  // Web UI
  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    const html = await readFile(join(__dirname, 'public', 'index.html'), 'utf8');
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    return res.end(html);
  }

  // Most do Claude Code — streaming odpowiedzi
  if (req.method === 'POST' && req.url === '/ask') {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 1e6) req.destroy(); });
    req.on('end', () => {
      let prompt = '';
      try { prompt = JSON.parse(body).prompt || ''; } catch { prompt = body; }
      prompt = String(prompt).trim();
      if (!prompt) { res.writeHead(400); return res.end('pusty prompt'); }

      res.writeHead(200, {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'no-cache',
        'transfer-encoding': 'chunked',
      });

      // Claude Code headless, w katalogu aplikacji, output strumieniowy JSON.
      const child = spawn('claude', [
        '--print',
        '--output-format', 'stream-json',
        '--verbose',
        '--permission-mode', 'acceptEdits',
        '-p', prompt,
      ], { cwd: APP_DIR, env: process.env });

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
      child.on('close', code => { res.write(`\n\n— koniec (exit ${code}) —\n`); res.end(); });
      child.on('error', e => { res.write('\n[spawn error] ' + e.message); res.end(); });
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
