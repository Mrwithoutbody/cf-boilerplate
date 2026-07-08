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
# Proxy woła lokalny 'claude' (headless). Domyślnie używa Twojej sesji Claude Code
# (abonament, ~/.claude). ANTHROPIC_API_KEY NIE jest potrzebny — ustaw go tylko
# jeśli świadomie chcesz iść przez płatne API zamiast abonamentu.
CBIN="$(command -v claude 2>/dev/null || true)"
if [ -x "$CBIN" ]; then
  export CLAUDE_BIN="$CBIN"          # przekaż dokładną ścieżkę binarki do serwera
  ok "claude CLI: $(claude --version 2>/dev/null | head -1)  ($CBIN)"
else
  warn "Brak 'claude' w PATH. Zainstaluj Claude Code i zaloguj: 'claude' → /login."
fi

( cd control && npm install --silent )
ok "Zależności proxy zainstalowane."

PORT="$(ask 'Port proxy' 3000)"
set -a; . ./.env; set +a
# Config targetu do env serwera (FS_ALLOW = dodatkowe komendy dla Claude,
# FS_APP_URL = jawny URL podglądu). Bije .env gdy oba definiują.
[ -f ./target.env ] && { set -a; . ./target.env; set +a; }

# Klucz dostępu (capability URL): rotuje z każdym startem jak URL tunelu.
# Ląduje we FRAGMENCIE linku w QR (#k=...) — fragment nie opuszcza przeglądarki,
# nie trafia do logów tunelu ani Referera. Server odrzuca requesty bez klucza.
PROXY_KEY="$(node -e 'console.log(require("crypto").randomBytes(16).toString("hex"))')"
export PROXY_KEY

# Serwer w tle (most do lokalnego Claude Code).
( cd control && PORT="$PORT" node server.js ) &
SRV=$!
# Sprzątanie: ubij serwer i tunel przy wyjściu (Ctrl+C).
cleanup(){ kill "$SRV" 2>/dev/null || true; [ -n "${TUN:-}" ] && kill "$TUN" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
sleep 1
ok "Serwer: http://localhost:$PORT"

warn "BEZPIECZEŃSTWO: proxy wykonuje polecenia na TYM komputerze (Claude, tryb acceptEdits)."
warn "Dostęp tylko z kluczem z kodu QR (rotuje przy każdym starcie). Link z QR = pełna kontrola — nie udostępniaj."
echo
printf "\033[1;36m▶ Stawiam tunel Cloudflare — QR pojawi się niżej, zeskanuj telefonem...\033[0m\n"

# Tunel: wychwyć publiczny URL z logu i pokaż QR (raz).
SHOWN=""
cloudflared tunnel --url "http://localhost:$PORT" 2>&1 | while IFS= read -r line; do
  printf '%s\n' "$line"
  if [ -z "$SHOWN" ]; then
    url="$(printf '%s' "$line" | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1 || true)"
    if [ -n "$url" ]; then
      SHOWN=1
      ( cd control && node qr.js "$url/#k=$PROXY_KEY" ) 2>/dev/null \
        || printf '\n>>> OTWÓRZ NA TELEFONIE: %s\n\n' "$url/#k=$PROXY_KEY"
    fi
  fi
done
