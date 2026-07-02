#!/usr/bin/env bash
# Boilerplate startowy: Cloudflare-only + git lokalny + proxy głosowy.
# Użycie: skopiuj katalog gdziekolwiek, potem: ./setup.sh
set -euo pipefail
cd "$(dirname "$0")"

say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

say "1/4 Sprawdzam narzędzia"
bash scripts/check.sh

say "2/4 Logowanie Cloudflare"
if wrangler whoami >/dev/null 2>&1; then
  ok "Zalogowany: $(wrangler whoami 2>/dev/null | grep -oE '[^ ]+@[^ ]+' | head -1 || echo '?')"
else
  echo "Otworzy się przeglądarka. Zaloguj się na swoje konto Cloudflare."
  wrangler login
fi

say "Konto Cloudflare"
[ -f .env ] || cp .env.example .env
if grep -q '^CLOUDFLARE_ACCOUNT_ID=.\+' .env; then
  ok "account_id z .env: $(grep '^CLOUDFLARE_ACCOUNT_ID=' .env | cut -d= -f2)"
else
  who="$(wrangler whoami 2>/dev/null || true)"
  n="$(printf '%s\n' "$who" | grep -coE '[0-9a-f]{32}' || true)"
  if [ "${n:-0}" -gt 1 ]; then
    echo "$who"
    id="$(ask 'Masz kilka kont — wklej account_id do użycia' '')"
    if [ -n "$id" ]; then
      if grep -q '^CLOUDFLARE_ACCOUNT_ID=' .env; then
        sed -i "s|^CLOUDFLARE_ACCOUNT_ID=.*|CLOUDFLARE_ACCOUNT_ID=$id|" .env
      else
        printf '\nCLOUDFLARE_ACCOUNT_ID=%s\n' "$id" >> .env
      fi
      ok "Zapisano account_id do .env"
    fi
  else
    ok "Jedno konto — wybór niepotrzebny."
  fi
fi

say "3/4 Nowy projekt czy istniejący?"
echo "  [n] nowy  — scaffold aplikacji, git init, pierwszy deploy pod tym loginem"
echo "  [e] istniejący — podłącz kod/Workera który już masz w tym katalogu"
mode="$(ask 'wybór n/e' n)"

case "$mode" in
  n|N) bash scripts/new.sh ;;
  e|E) bash scripts/link.sh ;;
  *)   die "Nieznany wybór: $mode" ;;
esac

say "4/4 Proxy sterujący (głos z telefonu)"
if [ "$(ask 'Postawić serwer-proxy + tunnel teraz? t/n' t)" = t ]; then
  bash scripts/proxy.sh
else
  echo "Później: bash scripts/proxy.sh"
fi

ok "Gotowe. Deploy: scripts/deploy.sh  ·  Preview: scripts/preview.sh"
