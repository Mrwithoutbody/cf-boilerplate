#!/usr/bin/env bash
# Stawia serwer-proxy (web UI głosowy + most do Claude Code) i tunel Cloudflare.
set -euo pipefail
cd "$(dirname "$0")/.."
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

[ -f .env ] || cp .env.example .env
if ! grep -q '^ANTHROPIC_API_KEY=.\+' .env 2>/dev/null; then
  warn "Ustaw ANTHROPIC_API_KEY w pliku .env przed startem proxy."
fi

( cd control && npm install --silent )
ok "Zależności proxy zainstalowane."

PORT="$(ask 'Port proxy' 3000)"
echo "Start: (cd control && PORT=$PORT node server.js)"
echo
echo "Tunel Cloudflare (osobny terminal):"
echo "  cloudflared tunnel login"
echo "  cloudflared tunnel --url http://localhost:$PORT     # szybki trycloudflare.com"
echo
warn "BEZPIECZEŃSTWO: dla własnej domeny włącz Cloudflare Access (polityka = tylko Twój email, OTP)."
warn "Proxy wykonuje polecenia na tym komputerze. Bez Access = otwarte drzwi."

if [ "$(ask 'Odpalić serwer teraz? t/n' t)" = t ]; then
  set -a; . ./.env; set +a          # załaduj ANTHROPIC_API_KEY z .env
  ( cd control && PORT="$PORT" node server.js )
fi
