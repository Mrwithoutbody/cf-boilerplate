# futurestack

Start projektu na Cloudflare, git lokalny, sterowanie głosem z telefonu.

Futurestack żyje w `.fs/` **wewnątrz Twojego projektu**. Twój kod zostaje w roocie
(własny git, własna struktura); `.fs/` to odizolowane narzędzia (deploy + proxy),
dopisane do `.gitignore` — zero miszmaszu „który plik do czego".

## 1. Zainstaluj w projekcie (istniejącym albo nowym pustym folderze)
```bash
cd ~/projekty/moja-apka           # Twój projekt (z kodem) albo pusty folder na nowy
npx degit Mrwithoutbody/futurestack/.fs .fs   # pobiera SAM payload (podkatalog .fs/) — bez gita, bez historii
cd .fs
```
Działa z projektami, których futurestack NIE zakładał — nie rusza Twojego kodu
ani gita, tylko dokłada `.fs/` obok.

## 2. Token Cloudflare (szablon, zawężony do jednego konta)
Izolacja zależy od **zakresu** tokenu, nie od właściciela: token zawężony do
jednego konta deployuje tylko na to konto, inne są nieosiągalne.

1. `dash.cloudflare.com/profile/api-tokens` → **Create Token**
   (użyj tej strony — tokeny na poziomie konta NIE mają szablonów, wpadniesz
   w ręczny custom builder)
2. Sekcja **API token templates** → przy **„Edit Cloudflare Workers"** klik **Use template**
3. **Account Resources** → `Include` → `Specific account` → wybierz **to jedno konto**
   (to zawężenie = izolacja; bez niego przycisk „Review token" jest nieaktywny)
4. **Zone Resources** → szablon domaga się strefy. Na `*.workers.dev` stref nie
   masz → zmień `Specific zone` na **`All zones from an account`** → wybierz to
   samo konto. (Workers Routes dotyczy tylko własnych domen — deploya nie rusza.)
5. **Review token** → **Create Token** → **Copy** (token widać RAZ)

**Account ID** (strona tokenu go NIE pokazuje) — weź z jednego z dwóch miejsc:
- Twoje konto → **Workers & Pages** → prawy panel **„Account ID"** (przycisk kopiowania)
- albo z URL dowolnej strony konta: `dash.cloudflare.com/`**`<ACCOUNT_ID>`**`/...`

## 3. Setup
```bash
./setup.sh                    # wykrywa sam: root ma kod → podłącza, pusty → scaffold
./setup.sh ~/kod/moja-apka    # import istniejącego kodu ze ścieżki → root projektu
```
Wklej `CLOUDFLARE_ACCOUNT_ID` i `CLOUDFLARE_API_TOKEN`. Reszta bez pytań:
**root ma kod → podłącza istniejący, pusty → scaffolduje nowy.**
Kod Workera zawsze w roocie projektu (nie w podfolderze); `.fs/` obok, w `.gitignore`.

## 4. Deploy — target wykrywany, nie hardcode
```bash
.fs/scripts/deploy.sh "opis"     # produkcja (z roota projektu)
.fs/scripts/preview.sh           # preview, bez ruszania produkcji
```
Stack **podmienialny** (styl MCP): providery w `.fs/targets/` same sprawdzają
projekt, pierwszy trafiony wygrywa. Ogarnięte out-of-box:

| stack | wykrywa po | deploy | creds CF? |
|---|---|---|---|
| Cloudflare Pages | `@astrojs/cloudflare` / `pages deploy` | `npm run deploy` | tak |
| Cloudflare Workers | `wrangler.*` | `wrangler deploy` | tak |
| Expo / RN | `expo` / `app.json` | `eas build` | **nie** |
| npm (Next/Nuxt/...) | skrypt `deploy` w package.json | `npm run deploy` | tylko gdy wrangler |

Przy `setup.sh` wybierasz target **raz** z listy (domyślny = wykryty, Enter
akceptuje) — zapis do `.fs/target.env`, deploy z telefonu już nie pyta. Nowy
stack = wrzuć plik do `.fs/targets/`, sam pojawi się w wyborze. Ręczne
nadpisanie: `.fs/target.env` (`FS_TARGET=...` albo `FS_DEPLOY=...`, `FS_NEEDS_CF=0`).
Setup pomija token CF gdy target go nie potrzebuje.

## 5. Sterowanie głosem z telefonu
Proxy woła **lokalny Claude Code** (`claude`), używa Twojej sesji/abonamentu —
`ANTHROPIC_API_KEY` NIE jest potrzebny (ustaw go tylko dla płatnego API).
Wymagane: `claude` w PATH i zalogowany (`claude` → `/login`).
```bash
bash .fs/scripts/proxy.sh      # serwer + tunel + kod QR — jedno polecenie, jeden terminal
```
W terminalu pojawi się **kod QR** — zeskanuj aparatem telefonu, otworzy się web UI.
Mów (🎤) albo pisz, Claude Code zmienia kod w roocie projektu. Ctrl+C ubija serwer i tunel.

**🚀 Deploy LIVE z telefonu:** przycisk `🚀` w sesji → potwierdzenie → wypycha na
**produkcję** przez guarded `deploy.sh` (wykryty target + guard scoped-token +
commit). Działa dla każdego stacka — komenda z wybranego targetu, nie przez
allowlistę Claude. Wynik streamuje się na żywo, na końcu `✅ LIVE`.

🔑 Dostęp chroni **klucz w linku z QR** (rotuje przy każdym starcie proxy; server
odrzuca requesty bez niego, nasłuchuje tylko na loopbacku). Link z QR = pełna
kontrola nad Twoim komputerem — traktuj jak hasło, nie udostępniaj i nie wklejaj
nigdzie. Po restarcie proxy stary link umiera — zeskanuj nowy QR.
