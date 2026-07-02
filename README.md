# cf-boilerplate

Start projektu na Cloudflare, git lokalny, sterowanie głosem z telefonu.

## 1. Pobierz do nowego folderu
```bash
npx degit Mrwithoutbody/cf-boilerplate ~/projekty/moja-apka
cd ~/projekty/moja-apka
```

## 2. Token Cloudflare (jedno konto)
Dash → wejdź na konto → **API Tokens** (URL: `dash.cloudflare.com/<ACCOUNT_ID>/api-tokens`)
→ Create Token → „Edit Cloudflare Workers" → Create. Skopiuj token.
Token z tej strony jest przypięty do jednego konta. **Account ID = `<ACCOUNT_ID>` z adresu.**

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
