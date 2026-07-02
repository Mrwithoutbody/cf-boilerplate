#!/usr/bin/env bash
# Deploy produkcyjny na Cloudflare — TYLKO na konto z .env (token scoped).
# Guard blokuje deploy z boilerplate i bez configu.
set -euo pipefail
DIR="$(dirname "$0")"
. "$DIR/guard.sh"                 # ładuje+eksportuje CLOUDFLARE_*, blokuje jak trzeba
cd "$DIR/.."
[ -d app ] || { echo "Brak app/. Uruchom ./setup.sh."; exit 1; }

MSG="${1:-deploy: $(date +%F' '%T)}"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git add -A && git commit -qm "$MSG" && echo "Commit lokalny: $MSG"
fi

cd app && wrangler deploy
