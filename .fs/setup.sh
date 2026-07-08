#!/usr/bin/env bash
# Boilerplate startowy: Cloudflare-only + git lokalny + proxy głosowy.
# Izolacja per konto: token API SCOPED na jedno konto (NIE 'wrangler login').
# Model: futurestack żyje w .fs/ WEWNĄTRZ Twojego projektu; kod projektu w roocie.
# Użycie: w projekcie → npx degit ...futurestack .fs && cd .fs && ./setup.sh
set -euo pipefail
cd "$(dirname "$0")"                   # .fs/ (tu są narzędzia)
PROJECT="$(cd .. && pwd)"              # projekt = rodzic .fs/ (tu jest/ląduje kod)

# Opcjonalny import: ./setup.sh /sciezka/do/kodu → kopiuje kod do roota projektu.
SRC="${1:-}"

say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }
asksec(){ local p="$1" a; read -rsp "$(printf '\033[1;33m? %s: \033[0m' "$p")" a; printf '\n' >&2; echo "$a"; }
setkv(){ local k="$1" v="$2"; if grep -q "^$k=" .env; then sed -i "s|^$k=.*|$k=$v|" .env; else printf '%s=%s\n' "$k" "$v" >> .env; fi; }

say "1/4 Sprawdzam narzędzia"
bash scripts/check.sh

# Czy w roocie projektu jest już kod (cokolwiek poza samym .fs/)?
has_code(){ [ -n "$(ls -A "$PROJECT" 2>/dev/null | grep -vx '.fs')" ]; }
export PROJECT

# Istniejący projekt → wybór targetu deployu (RAZ, zapis do .fs/target.env).
# Wykrywa domyślny, user potwierdza/zmienia. Pusty (nowy) → target znany po scaffoldzie.
has_code && bash scripts/pick-target.sh

# Czy target wymaga Cloudflare? Wykryj (honoruje FS_TARGET z target.env po wyborze).
# Pusty (nowy) → tak (domyślny scaffold to CF Worker).
NEED_CF=1
if has_code; then
  . scripts/target.sh
  NEED_CF="${T_NEEDS_CF:-1}"
  [ -n "$T_NAME" ] && ok "Target: $T_NAME (Cloudflare: $([ "$NEED_CF" = 1 ] && echo tak || echo nie))."
fi

[ -f .env ] || cp .env.example .env
if [ "$NEED_CF" != 1 ]; then
  say "2/4 Target bez Cloudflare (${T_NAME:-?}) — pomijam token CF"
  ok "Deploy pójdzie przez komendę targetu. Token CF niepotrzebny."
elif grep -q '^CLOUDFLARE_API_TOKEN=.\+' .env && grep -q '^CLOUDFLARE_ACCOUNT_ID=.\+' .env; then
  say "2/4 Konto Cloudflare — token SCOPED na jedno konto"
  ok "Config obecny w .env (account: $(grep '^CLOUDFLARE_ACCOUNT_ID=' .env | cut -d= -f2))."
else
  say "2/4 Konto Cloudflare — token SCOPED na jedno konto"
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

say "3/4 Wykrywam projekt"
# Import ze wskazanej ścieżki → root projektu (tylko gdy root jeszcze pusty).
if [ -n "$SRC" ] && ! has_code; then
  [ -d "$SRC" ] || die "Ścieżka nie istnieje: $SRC"
  cp -r "$SRC"/. "$PROJECT"/ && ok "Skopiowano $SRC → root projektu"
fi
# Reguła: kod w roocie → podłącz istniejący. Root pusty → scaffold nowego. Zero pytań.
if has_code; then
  ok "Kod w roocie ($PROJECT) — podłączam istniejący projekt."
  bash scripts/link.sh
else
  ok "Root projektu pusty — scaffold nowego."
  bash scripts/new.sh
fi

say "4/4 Proxy sterujący (głos z telefonu) — startuje. Ctrl+C = stop, później: bash .fs/scripts/proxy.sh"
bash scripts/proxy.sh
