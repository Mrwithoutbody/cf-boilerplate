# cf-boilerplate

Start projektu na Cloudflare, git lokalny, sterowanie głosem z telefonu.

## 1. Pobierz do nowego folderu
```bash
npx degit Mrwithoutbody/cf-boilerplate ~/projekty/moja-apka
cd ~/projekty/moja-apka
```

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
./setup.sh
```
Wklej `CLOUDFLARE_ACCOUNT_ID` i `CLOUDFLARE_API_TOKEN`, wybierz **nowy [n]** lub **istniejący [e]**.
Istniejący: wrzuć kod projektu do `app/` (lub podaj ścieżkę).

## 4. Deploy
```bash
scripts/deploy.sh "opis"     # produkcja
scripts/preview.sh           # preview URL, bez ruszania produkcji
```

## 5. Sterowanie głosem z telefonu
Proxy woła **lokalny Claude Code** (`claude`), używa Twojej sesji/abonamentu —
`ANTHROPIC_API_KEY` NIE jest potrzebny (ustaw go tylko dla płatnego API).
Wymagane: `claude` w PATH i zalogowany (`claude` → `/login`).
```bash
bash scripts/proxy.sh          # serwer + tunel + kod QR — jedno polecenie, jeden terminal
```
W terminalu pojawi się **kod QR** — zeskanuj aparatem telefonu, otworzy się web UI.
Mów (🎤) albo pisz, Claude Code zmienia projekt w `app/`. Ctrl+C ubija serwer i tunel.

⚠️ Quick tunnel jest publiczny — kto zna link, steruje Twoim kompem. Stała domena
→ włącz **Cloudflare Access** (polityka: tylko Twój email).
