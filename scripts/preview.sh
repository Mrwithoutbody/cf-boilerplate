#!/usr/bin/env bash
# Podgląd na Cloudflare bez ruszania produkcji (preview URL). TYLKO konto z .env.
set -euo pipefail
DIR="$(dirname "$0")"
. "$DIR/guard.sh"                 # ładuje+eksportuje CLOUDFLARE_*, blokuje jak trzeba
cd "$DIR/.."
[ -d app ] || { echo "Brak app/. Uruchom ./setup.sh."; exit 1; }
cd app
wrangler versions upload
