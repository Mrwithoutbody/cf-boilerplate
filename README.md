# cf-boilerplate — Cloudflare-only starter z git lokalnym i sterowaniem głosem

Generator projektów webowych, które żyją **wyłącznie na Cloudflare**: kontrola
wersji lokalna, deploy przez `wrangler`, opcjonalne sterowanie głosem z telefonu
przez Claude Code za tunelem.

## Quick start

```bash
# najprościej — kopia bez historii git (wymaga tylko Node/npx):
npx degit <user>/cf-boilerplate moja-apka
cd moja-apka
./setup.sh
```
Albo `git clone https://github.com/<user>/cf-boilerplate moja-apka && rm -rf moja-apka/.git`.

`setup.sh` przeprowadzi przez: sprawdzenie narzędzi → `wrangler login` (Twoje konto
Cloudflare) → nowy/istniejący projekt → pierwszy deploy → opcjonalne proxy głosowe.
Na końcu dostajesz URL `*.workers.dev` — jedyne miejsce podglądu aplikacji.

## Narzędzie vs projekt (ważne)

- **To repo (boilerplate) = narzędzie.** Może i powinno leżeć na GitHub — to kanał,
  z którego je pobierasz.
- **Projekt zrobiony tym narzędziem = wytwór.** Git tylko lokalny, nigdy nie wraca
  na GitHub. Deploy prosto na Cloudflare.

Zasada „bez GitHub" poniżej dotyczy **projektów**, nie tego repo.

## Model (dla generowanych projektów)
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

## Wymagania
Node 18+, git, `wrangler` (globalnie lub przez `npx`). `cloudflared` doinstaluje się
sam (Ubuntu/Debian). Konto Cloudflare. `ANTHROPIC_API_KEY` — tylko jeśli używasz proxy głosowego.

## Kroki setup.sh
1. sprawdza narzędzia, doinstaluje `cloudflared`
2. `wrangler login` (jeśli nie zalogowany) — projekt siada pod tym kontem
3. pytanie **nowy [n]** czy **istniejący [e]**
4. opcjonalnie stawia proxy głosowe + pokazuje komendę tunelu

Alternatywa bez pobierania z sieci (masz katalog lokalnie):
```bash
cp -r <ten-katalog> ~/projekty/nowy && cd ~/projekty/nowy && ./setup.sh
```

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

## Licencja
MIT — patrz [LICENSE](LICENSE).
