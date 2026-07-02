#!/usr/bin/env bash
# Boilerplate startowy: Cloudflare-only + git lokalny + proxy głosowy.
# Izolacja per konto: token API SCOPED na jedno konto (NIE 'wrangler login').
# Użycie: pobierz instancję do osobnego folderu, potem: ./setup.sh
set -euo pipefail
cd "$(dirname "$0")"

say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }
asksec(){ local p="$1" a; read -rsp "$(printf '\033[1;33m? %s: \033[0m' "$p")" a; printf '\n' >&2; echo "$a"; }
setkv(){ local k="$1" v="$2"; if grep -q "^$k=" .env; then sed -i "s|^$k=.*|$k=$v|" .env; else printf '%s=%s\n' "$k" "$v" >> .env; fi; }

say "1/4 Sprawdzam narzędzia"
bash scripts/check.sh

say "2/4 Konto Cloudflare — token SCOPED na jedno konto"
[ -f .env ] || cp .env.example .env
if grep -q '^CLOUDFLARE_API_TOKEN=.\+' .env && grep -q '^CLOUDFLARE_ACCOUNT_ID=.\+' .env; then
  ok "Config obecny w .env (account: $(grep '^CLOUDFLARE_ACCOUNT_ID=' .env | cut -d= -f2))."
else
  cat <<'TXT'
Ten projekt deployuje WYŁĄCZNIE na jedno konto — przez token API ograniczony do tego konta.
NIE używamy 'wrangler login' (globalny OAuth widzi wszystkie Twoje konta = brak izolacji,
ryzyko wgrania w cudzą produkcję).

Utwórz token z szablonu, zawężony do JEDNEGO konta (to zawężenie = izolacja):
  1) dash.cloudflare.com/profile/api-tokens → Create Token
     (ta strona ma szablony; tokeny na poziomie konta NIE mają — custom builder)
  2) API token templates → "Edit Cloudflare Workers" → Use template
  3) Account Resources → Include → Specific account → TO jedno konto
     (bez tego kroku przycisk "Review token" jest nieaktywny)
  4) Zone Resources → zmień "Specific zone" na "All zones from an account"
     → wybierz to konto (na *.workers.dev stref nie masz; Routes deploya nie rusza)
  5) Review token → Create Token → skopiuj token
Account ID: Workers & Pages → prawy panel "Account ID", albo z URL konta
  (dash.cloudflare.com/<ACCOUNT_ID>/...).

Token trafi do .env (jest w .gitignore — nie commituje się).
TXT
  acc="$(ask 'CLOUDFLARE_ACCOUNT_ID' '')"
  tok="$(asksec 'CLOUDFLARE_API_TOKEN (wpisywanie ukryte)')"
  [ -n "$acc" ] && [ -n "$tok" ] || die "Bez account_id i tokenu nie ruszamy — izolacja to twardy wymóg."
  setkv CLOUDFLARE_ACCOUNT_ID "$acc"
  setkv CLOUDFLARE_API_TOKEN "$tok"
  ok "Config zapisany do .env."
fi

say "3/4 Nowy projekt czy istniejący?"
echo "  [n] nowy  — scaffold aplikacji, git init, pierwszy deploy na skonfigurowane konto"
echo "  [e] istniejący — podłącz kod/Workera który już masz w tym katalogu"
mode="$(ask 'wybór n/e' n)"
case "$mode" in
  n|N) bash scripts/new.sh ;;
  e|E) bash scripts/link.sh ;;
  *)   die "Nieznany wybór: $mode" ;;
esac

say "4/4 Proxy sterujący (głos z telefonu) — startuje. Ctrl+C = stop, później: bash scripts/proxy.sh"
bash scripts/proxy.sh
