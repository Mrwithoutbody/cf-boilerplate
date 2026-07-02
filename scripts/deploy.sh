#!/usr/bin/env bash
# Deploy produkcyjny na Cloudflare. Commit lokalny przed wypchnięciem.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d app ] || { echo "Brak app/. Uruchom setup.sh."; exit 1; }

MSG="${1:-deploy: $(date +%F' '%T)}"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git add -A && git commit -qm "$MSG" && echo "Commit lokalny: $MSG"
fi

cd app && wrangler deploy
