# Boilerplate: Cloudflare-only + git lokalny + sterowanie głosem

Zestaw skryptów startowych. Wrzucasz katalog gdziekolwiek → `./setup.sh` → login →
nowy projekt albo istniejący → opcjonalnie proxy głosowe. Deploy na Cloudflare.

## Model
- **Bez GitHub.** Git tylko lokalny (init/add/commit), zero remote, zero push.
- **Cloudflare = jedyne środowisko.** Apki nie odpalasz lokalnie. Podgląd = URL Cloudflare.
- **Deploy** = `wrangler deploy` z PC. **Preview** = `wrangler versions upload`.
- **Sterowanie** = telefon (głos) → Cloudflare Tunnel → PC-proxy → Claude Code.

## Struktura
```
setup.sh            orkiestrator (check → login → new|existing → proxy)
scripts/
  check.sh          toolchain + auto-instal cloudflared
  new.sh            scaffold Worker + git init + pierwszy deploy
  link.sh           podłącz istniejący kod/Workera
  deploy.sh         commit lokalny + wrangler deploy (produkcja)
  preview.sh        wrangler versions upload (preview URL, bez ruszania prod)
  proxy.sh          instal+start serwera-proxy, instrukcja tunelu
control/            serwer-proxy (web UI głosowy + most Claude Code, zero deps)
  server.js  public/index.html  package.json
.env.example        ANTHROPIC_API_KEY, PORT
.gitignore
app/                <- tu ląduje budowana aplikacja (tworzy new.sh/link.sh)
```

## Start
```bash
cp -r <ten-katalog> ~/projekty/nowy && cd ~/projekty/nowy
./setup.sh
```
Kroki setup.sh:
1. sprawdza narzędzia, doinstaluje `cloudflared`
2. `wrangler login` (jeśli nie zalogowany) — projekt siada pod tym kontem
3. pytanie **nowy [n]** czy **istniejący [e]**
4. opcjonalnie stawia proxy głosowe + pokazuje komendę tunelu

## Po setupie
```bash
scripts/preview.sh          # preview URL na Cloudflare
scripts/deploy.sh "opis"    # commit lokalny + deploy produkcyjny
bash scripts/proxy.sh       # serwer głosowy, jeśli nie odpalony
```
Tunel (osobny terminal):
```bash
cloudflared tunnel --url http://localhost:3000    # szybki trycloudflare.com
```
Własna domena → włącz **Cloudflare Access** (polityka: tylko Twój email, OTP).

## Bezpieczeństwo
- Proxy wykonuje polecenia na PC. Bez Cloudflare Access = otwarte drzwi. Access obowiązkowy dla stałej domeny.
- `ANTHROPIC_API_KEY` tylko w `.env` (w .gitignore). Sekrety Workera przez `wrangler secret`.

## Domyślne / do zmiany
- Framework: `hono` (alt: `react-router`, `none`) — pyta new.sh
- Głos: Web Speech API w przeglądarce, `pl-PL` (offline-alt: Whisper — do dorobienia)
- Uprawnienia proxy: Claude Code w trybie `acceptEdits` (server.js) — podnieś/obniż wg potrzeb
