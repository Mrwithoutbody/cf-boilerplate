# futurestack

Rozwijaj projekt (dowolny stack) głosem z telefonu → deploy LIVE na produkcję. Żyje w
`.fs/` w Twoim projekcie: kod i git zostają w roocie, `.fs/` w `.gitignore`. Nie rusza kodu.

## 1. Instalacja (istniejący projekt albo pusty folder)
```bash
cd ~/projekty/moja-apka
npx degit Mrwithoutbody/futurestack/.fs .fs   # sam payload, bez gita/historii
cd .fs && ./setup.sh                            # albo: ./setup.sh ~/kod/src (import kodu)
```

## 2. Token Cloudflare (tylko gdy target = Cloudflare)
Token zawężony do JEDNEGO konta = izolacja (NIE `wrangler login`). `.../profile/api-tokens`
→ szablon **Edit Cloudflare Workers** → **Account Resources: Include > Specific account** →
Zone: **All zones from an account** → Create. Account ID: **Workers & Pages** → prawy panel.
Wklejasz przy setup (do `.fs/.env`, gitignored); setup pomija gdy target nie wymaga (Expo).

## 3. Setup — bez pytań
Auto-detekcja: **root ma kod → podłącza, pusty → scaffold** (wybór stacka:
cloudflare / vite / astro / next / expo / własna). Kod zawsze w roocie.

## 4. Deploy — target wykrywany (styl MCP), nie hardcode
Providery w `.fs/targets/` same sprawdzają projekt; pierwszy trafiony wygrywa:

| stack | deploy | creds CF |
|---|---|---|
| Cloudflare Pages / Workers | `npm run deploy` / `wrangler deploy` | tak |
| Expo / RN | `eas build` | nie |
| npm (Next/Nuxt/...) | `npm run deploy` | gdy wrangler |

Przy setup wybierasz target **raz** (domyślny = wykryty) → `.fs/target.env`. Nowy stack =
plik w `.fs/targets/`. Override `.fs/target.env`: `FS_TARGET` / `FS_DEPLOY` / `FS_NEEDS_CF`
/ `FS_ALLOW=cargo,go` (komendy dla Claude) / `FS_APP_URL`. Ręcznie: `.fs/scripts/deploy.sh`.

## 5. Głos z telefonu + Deploy LIVE
Proxy woła lokalny `claude` (Twoja sesja; `ANTHROPIC_API_KEY` niepotrzebny). Wymóg: `claude` w PATH, zalogowany.
```bash
bash .fs/scripts/proxy.sh      # serwer + tunel + QR, jeden terminal
```
Skanujesz **QR** → web UI. Mów/pisz → Claude zmienia kod w roocie. Przycisk **🚀** →
potwierdzenie → deploy na **produkcję** (guarded, target-aware), wynik streamuje na żywo.

🔑 Dostęp chroni **klucz w linku z QR** (rotuje co start, tylko loopback). Link = pełna
kontrola nad komputerem — traktuj jak hasło. Restart proxy = nowy QR, stary link umiera.
