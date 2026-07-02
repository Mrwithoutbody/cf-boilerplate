# cf-boilerplate — Cloudflare-only starter z git lokalnym i sterowaniem głosem

Generator projektów webowych, które żyją **wyłącznie na Cloudflare**: kontrola
wersji lokalna, deploy przez `wrangler`, opcjonalne sterowanie głosem z telefonu
przez Claude Code za tunelem.

## Quick start

```bash
# najprościej — kopia bez historii git (wymaga tylko Node/npx):
npx degit Mrwithoutbody/cf-boilerplate moja-apka
cd moja-apka
./setup.sh
```
Albo `git clone https://github.com/Mrwithoutbody/cf-boilerplate moja-apka && rm -rf moja-apka/.git`.

`setup.sh` przeprowadzi przez: sprawdzenie narzędzi → **wklejenie tokenu API scoped na
jedno konto** → nowy/istniejący projekt → pierwszy deploy → opcjonalne proxy głosowe.
Na końcu dostajesz URL `*.workers.dev` — jedyne miejsce podglądu aplikacji.

## Narzędzie vs projekt (ważne)

- **To repo (boilerplate) = narzędzie.** Może i powinno leżeć na GitHub — to kanał,
  z którego je pobierasz.
- **Projekt zrobiony tym narzędziem = wytwór.** Git tylko lokalny, nigdy nie wraca
  na GitHub. Deploy prosto na Cloudflare.

Zasada „bez GitHub" poniżej dotyczy **projektów**, nie tego repo.

## Model (dla generowanych projektów)
- **Izolacja per konto.** Deploy WYŁĄCZNIE na jedno konto — przez token API scoped na
  to konto w `.env`. Bez `wrangler login` (globalny OAuth widzi wszystkie konta = brak
  izolacji). Zły account_id albo bug → API odrzuca, nie wycieka do cudzej produkcji.
- **Bez GitHub.** Git tylko lokalny (init/add/commit), zero remote, zero push.
- **Cloudflare = jedyne środowisko.** Apki nie odpalasz lokalnie. Podgląd = URL Cloudflare.
- **Deploy** = `wrangler deploy` z PC. **Preview** = `wrangler versions upload`.
- **Sterowanie** = telefon (głos) → Cloudflare Tunnel → PC-proxy → Claude Code.

## Izolacja i guardy (dlaczego nie da się wgrać w cudze konto)
- **Token scoped, nie OAuth.** Utwórz token: dash → My Profile → API Tokens →
  „Edit Cloudflare Workers", **Account Resources = tylko to jedno konto**. Wklej do
  `.env` (`CLOUDFLARE_ACCOUNT_ID` + `CLOUDFLARE_API_TOKEN`). Token jest bezsilny na
  innych kontach — izolacja fizyczna, nie umowna.
- **Guard przed każdym deploy** (`scripts/guard.sh`, wołany przez deploy/preview/new):
  odmawia jeśli (a) katalog to boilerplate DEV (marker `.is-boilerplate`),
  (b) brak `.env`, (c) pusty `CLOUDFLARE_ACCOUNT_ID` lub `CLOUDFLARE_API_TOKEN`.
- **Boilerplate nigdy nie deployuje.** Marker `.is-boilerplate` blokuje deploy w repo
  narzędzia; `new.sh`/`link.sh` usuwają go dopiero gdy z instancji robisz realny projekt.
- **Zakaz zgadywania.** Skrypty nie czytają listy kont (`wrangler whoami`) i nie iterują
  po kontach. Konto zawsze jawne, z `.env`.

## Struktura
```
setup.sh            orkiestrator (check → config tokenu → new|existing → proxy)
scripts/
  check.sh          toolchain (node/git/wrangler)
  guard.sh          bramka: blokuje deploy z boilerplate i bez configu konta
  new.sh            scaffold Worker + git init + (opcjonalny) deploy; usuwa marker
  link.sh           podłącz istniejący kod/Workera; usuwa marker
  deploy.sh         guard + commit lokalny + wrangler deploy (produkcja)
  preview.sh        guard + wrangler versions upload (preview URL)
  proxy.sh          instal cloudflared + start serwera-proxy, instrukcja tunelu
control/            serwer-proxy (web UI głosowy + most Claude Code, zero deps)
  server.js  public/index.html  package.json
.env.example        CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN, ANTHROPIC_API_KEY, PORT
.is-boilerplate     marker DEV — obecny = deploy zablokowany (usuwany przy new/link)
.gitignore
app/                <- tu ląduje budowana aplikacja (tworzy new.sh/link.sh)
```

## Wymagania
Node 18+, git, `wrangler` (globalnie lub przez `npx`). Konto Cloudflare + **token API
scoped na to konto** (patrz „Izolacja i guardy"). `cloudflared` i `ANTHROPIC_API_KEY`
— tylko gdy używasz proxy głosowego.

## Kroki setup.sh
1. sprawdza narzędzia
2. config konta: wkleja `CLOUDFLARE_ACCOUNT_ID` + `CLOUDFLARE_API_TOKEN` (scoped) do `.env`
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
