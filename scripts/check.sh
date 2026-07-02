#!/usr/bin/env bash
# Sprawdza toolchain. Instaluje cloudflared jak brak.
set -euo pipefail
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

command -v node >/dev/null    || die "Brak node (wymagane 18+)."
command -v git  >/dev/null    || die "Brak git."
command -v npx  >/dev/null    || die "Brak npm/npx."
node -e 'process.exit(+process.versions.node.split(".")[0]>=18?0:1)' || die "Node za stary (<18)."
ok "node $(node -v) · git $(git --version | awk '{print $3}')"

if command -v wrangler >/dev/null; then
  ok "wrangler $(wrangler --version 2>/dev/null | head -1)"
else
  warn "wrangler globalnie brak — użyję 'npx wrangler'."
fi

if command -v cloudflared >/dev/null; then
  ok "cloudflared $(cloudflared --version 2>/dev/null | awk '{print $3}')"
else
  warn "cloudflared brak — instaluję (Ubuntu/Debian)."
  if command -v apt-get >/dev/null; then
    ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
    tmp="$(mktemp --suffix=.deb)"
    curl -fsSL "$URL" -o "$tmp" && sudo dpkg -i "$tmp" && rm -f "$tmp" \
      && ok "cloudflared zainstalowany" \
      || warn "Auto-instalacja nie wyszła. Zainstaluj ręcznie: $URL"
  else
    warn "Brak apt. Zainstaluj cloudflared ręcznie z github.com/cloudflare/cloudflared/releases"
  fi
fi
