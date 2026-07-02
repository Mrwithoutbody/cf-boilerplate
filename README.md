# cf-boilerplate

Start projektu na Cloudflare, git lokalny, sterowanie głosem z telefonu.

## 1. Pobierz do nowego folderu
```bash
npx degit Mrwithoutbody/cf-boilerplate ~/projekty/moja-apka
cd ~/projekty/moja-apka
```

## 2. Token Cloudflare (jedno konto)
Dash → My Profile → API Tokens → Create Token → „Edit Cloudflare Workers" →
Account Resources = **tylko to jedno konto** → Create. Skopiuj token i Account ID.

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
```bash
# ANTHROPIC_API_KEY w .env, potem:
bash scripts/proxy.sh
cloudflared tunnel --url http://localhost:3000   # osobny terminal
```
Otwórz URL `*.trycloudflare.com` na telefonie. Stała domena → włącz Cloudflare Access.
