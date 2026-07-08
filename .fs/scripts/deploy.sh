#!/usr/bin/env bash
# Deploy produkcyjny — komenda zależna od WYKRYTEGO targetu (.fs/targets/),
# nie hardcode. Guard blokuje boilerplate; creds CF tylko gdy target ich wymaga.
set -euo pipefail
DIR="$(dirname "$0")"
PROJECT="$(cd "$DIR/../.." && pwd)"   # projekt = rodzic .fs/ (kod w roocie)

export PROJECT
. "$DIR/target.sh"                     # wykryj target → T_NAME T_DEPLOY T_NEEDS_CF ...
[ -n "$T_DEPLOY" ] || {
  echo "Nie wykryto jak deployować $PROJECT."
  echo "Ustaw .fs/target.env (np. FS_DEPLOY='npm run deploy', FS_NEEDS_CF=0) albo dodaj provider w .fs/targets/."
  exit 1
}

export FS_NEEDS_CF="$T_NEEDS_CF"
. "$DIR/guard.sh"                      # boilerplate zawsze; CF creds gdy FS_NEEDS_CF=1

cd "$PROJECT"
MSG="${1:-deploy: $(date +%F' '%T)}"
# Commit w gicie PROJEKTU (.fs/ gitignorowane — nie trafi do stage).
if [ -d .git ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git add -A && git commit -qm "$MSG" && echo "Commit lokalny: $MSG"
fi

echo "▶ target: $T_NAME → $T_DEPLOY"
eval "$T_DEPLOY"
