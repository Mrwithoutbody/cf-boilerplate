#!/usr/bin/env bash
# Istniejący projekt: kod jest już w roocie (rodzic .fs/). Podłącz go — dopilnuj
# wrangler.*, odizoluj .fs/ w .gitignore, NIE ruszaj cudzego gita.
set -euo pipefail
DIR="$(dirname "$0")"
FS="$(cd "$DIR/.." && pwd)"           # katalog .fs/ (narzędzia futurestack)
PROJECT="$(cd "$FS/.." && pwd)"       # projekt = rodzic .fs/ (kod usera w roocie)
cd "$PROJECT"
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

# Izolacja: .fs/ nie miesza się z plikami projektu w gicie usera.
if [ -f .gitignore ] && grep -qx '.fs/' .gitignore 2>/dev/null; then :; else
  printf '\n# futurestack (narzędzia deploy/proxy — nie część aplikacji)\n.fs/\n' >> .gitignore
  ok ".fs/ dopisane do .gitignore (izolacja od kodu projektu)."
fi

if [ -f wrangler.toml ] || [ -f wrangler.jsonc ] || [ -f wrangler.json ]; then
  ok "Konfiguracja wrangler znaleziona w roocie."
else
  warn "Brak wrangler.* w roocie — Worker nie zdeployuje się bez niej."
  NAME="$(ask 'Nazwa Workera' "$(basename "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')")"
  MAIN="$(ask 'Plik wejściowy' src/index.ts)"
  cat > wrangler.toml <<EOF
name = "$NAME"
main = "$MAIN"
compatibility_date = "$(date +%Y-%m-%d)"
EOF
  ok "Utworzono wrangler.toml"
fi

rm -f "$FS/.is-boilerplate" && ok "Marker usunięty — deploy odblokowany."

# Git usera nietknięty. Brak gita w projekcie? Załóż lokalny (bez remote).
if [ -d .git ]; then
  ok "Git projektu już jest — nie ruszam."
else
  git init -q && git add -A && git commit -qm "chore: init (futurestack, git lokalny)"
  ok "Git lokalny założony."
fi

echo "Deploy: .fs/scripts/deploy.sh   (guard sprawdzi token+account z .fs/.env)"
