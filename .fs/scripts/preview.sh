#!/usr/bin/env bash
# Podgląd/preview — komenda z wykrytego targetu (.fs/targets/), nie hardcode.
set -euo pipefail
DIR="$(dirname "$0")"
PROJECT="$(cd "$DIR/../.." && pwd)"   # projekt = rodzic .fs/ (kod w roocie)

export PROJECT
. "$DIR/target.sh"                     # wykryj target → T_PREVIEW T_NEEDS_CF ...
[ -n "$T_PREVIEW" ] || {
  echo "Target '$T_NAME' nie ma komendy preview. Ustaw FS_PREVIEW w .fs/target.env."
  exit 1
}

export FS_NEEDS_CF="$T_NEEDS_CF"
. "$DIR/guard.sh"                      # boilerplate zawsze; CF creds gdy FS_NEEDS_CF=1

cd "$PROJECT"
echo "▶ target: $T_NAME → $T_PREVIEW"
eval "$T_PREVIEW"
