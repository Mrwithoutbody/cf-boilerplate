#!/usr/bin/env bash
# Podgląd na Cloudflare bez ruszania produkcji (preview URL). Zero localhost.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d app ] || { echo "Brak app/. Uruchom setup.sh."; exit 1; }
cd app
# wrangler versions upload daje preview URL wersji bez przełączania produkcji
wrangler versions upload
