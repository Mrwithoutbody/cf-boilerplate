#!/usr/bin/env bash
# Istniejący projekt: podłącz kod który już jest w app/ (albo wskaż źródło),
# dołóż git lokalny jeśli brak, zweryfikuj wrangler.toml.
set -euo pipefail
cd "$(dirname "$0")/.."
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

if [ ! -d app ]; then
  SRC="$(ask 'Ścieżka do istniejącego kodu (skopiuję do app/)' '')"
  [ -n "$SRC" ] && [ -d "$SRC" ] || { warn "Brak katalogu app/ i nie podano źródła. Wrzuć kod do app/ i uruchom ponownie."; exit 1; }
  cp -r "$SRC" app
  ok "Skopiowano $SRC → app/"
fi

if [ -f app/wrangler.toml ] || [ -f app/wrangler.jsonc ] || [ -f app/wrangler.json ]; then
  ok "Konfiguracja wrangler znaleziona."
else
  warn "Brak wrangler.toml w app/ — Worker nie zdeployuje się bez niej."
  NAME="$(ask 'Nazwa Workera (do wrangler.toml)' my-app)"
  MAIN="$(ask 'Plik wejściowy' src/index.ts)"
  cat > app/wrangler.toml <<EOF
name = "$NAME"
main = "$MAIN"
compatibility_date = "$(date +%Y-%m-%d)"
EOF
  ok "Utworzono app/wrangler.toml"
fi

if [ ! -d .git ]; then
  cp -n .gitignore app/.gitignore 2>/dev/null || true
  git init -q && git add -A && git commit -qm "chore: podłączenie istniejącego projektu (git lokalny)"
  ok "Git lokalny założony."
else
  ok "Git już jest."
fi

echo "Weryfikacja: cd app && wrangler deploy   (albo scripts/deploy.sh)"
