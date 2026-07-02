#!/usr/bin/env bash
# Stawia serwer-proxy (web UI głosowy + most do Claude Code) i tunel Cloudflare.
set -euo pipefail
cd "$(dirname "$0")/.."
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

# cloudflared na żądanie (Ubuntu/Debian)
if ! command -v cloudflared >/dev/null; then
  if command -v apt-get >/dev/null; then
    ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
    tmp="$(mktemp --suffix=.deb)"
    curl -fsSL "$URL" -o "$tmp" && sudo dpkg -i "$tmp" && rm -f "$tmp" && ok "cloudflared zainstalowany" \
      || warn "Auto-instalacja nie wyszła. Zainstaluj ręcznie: $URL"
  else
    warn "Brak apt — zainstaluj cloudflared ręcznie z github.com/cloudflare/cloudflared/releases"
  fi
fi

[ -f .env ] || cp .env.example .env
grep -q '^ANTHROPIC_API_KEY=.\+' .env 2>/dev/null || warn "Ustaw ANTHROPIC_API_KEY w .env przed startem proxy."

( cd control && npm install --silent )
ok "Zależności proxy zainstalowane."

PORT="$(ask 'Port proxy' 3000)"
echo
echo "Tunel Cloudflare (osobny terminal):"
echo "  cloudflared tunnel --url http://localhost:$PORT     # szybki trycloudflare.com"
echo
warn "BEZPIECZEŃSTWO: dla stałej domeny włącz Cloudflare Access (polityka = tylko Twój email, OTP)."
warn "Proxy wykonuje polecenia na tym komputerze. Bez Access = otwarte drzwi."

if [ "$(ask 'Odpalić serwer teraz? t/n' t)" = t ]; then
  set -a; . ./.env; set +a
  ( cd control && PORT="$PORT" node server.js )
fi
