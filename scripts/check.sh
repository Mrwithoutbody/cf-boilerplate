#!/usr/bin/env bash
# Sprawdza toolchain. cloudflared instaluje proxy.sh (tylko gdy stawiasz proxy).
set -euo pipefail
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m! %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

command -v node >/dev/null || die "Brak node (wymagane 18+)."
command -v git  >/dev/null || die "Brak git."
command -v npx  >/dev/null || die "Brak npm/npx."
node -e 'process.exit(+process.versions.node.split(".")[0]>=18?0:1)' || die "Node za stary (<18)."
ok "node $(node -v) · git $(git --version | awk '{print $3}')"

if command -v wrangler >/dev/null; then
  ok "wrangler $(wrangler --version 2>/dev/null | head -1)"
else
  warn "wrangler globalnie brak — użyję 'npx wrangler'."
fi

command -v cloudflared >/dev/null \
  && ok "cloudflared $(cloudflared --version 2>/dev/null | awk '{print $3}')" \
  || warn "cloudflared brak — doinstaluje się przy stawianiu proxy (scripts/proxy.sh)."
