#!/usr/bin/env bash
# Nowy projekt: scaffold wybranego stacka do ROOTA projektu (rodzic .fs/),
# git lokalny, opcjonalny pierwszy deploy. Kod w roocie — .fs/ obok, izolowane.
set -euo pipefail
DIR="$(dirname "$0")"
FS="$(cd "$DIR/.." && pwd)"           # katalog .fs/ (narzędzia futurestack)
PROJECT="$(cd "$FS/.." && pwd)"       # projekt = rodzic .fs/ (tu ląduje kod)
cd "$PROJECT"
say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

if [ -f wrangler.toml ] || [ -f wrangler.jsonc ] || [ -f wrangler.json ] || [ -f package.json ]; then
  ok "Projekt już w roocie — pomijam scaffold."; exit 0
fi

# Domyślna nazwa = nazwa folderu projektu, znormalizowana (wymóg Cloudflare/npm).
DEF_NAME="$(basename "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')"
[ -n "$DEF_NAME" ] || DEF_NAME=my-app
NAME="$(ask 'Nazwa projektu (a-z0-9-)' "$DEF_NAME")"

echo "  Stack: cloudflare (Workers/Pages) · vite · astro · next · expo · wlasna"
STACK="$(ask 'stack' cloudflare)"

# Scaffold do temp w .fs/ (scaffoldery wymagają pustego celu), potem move do roota.
TMP="$FS/.scaffold"; rm -rf "$TMP"
CF=0
say "Scaffold ($STACK) → root projektu"
case "$STACK" in
  cloudflare)
    FRAMEWORK="$(ask 'Framework CF: hono / react-router / none' hono)"
    if [ "$FRAMEWORK" = none ]; then
      npm create cloudflare@latest "$TMP" -- --type=hello-world --lang=ts --no-git --no-deploy
    else
      npm create cloudflare@latest "$TMP" -- --framework="$FRAMEWORK" --no-git --no-deploy
    fi
    CF=1 ;;
  vite)
    T="$(ask 'Template vite (vanilla/react/vue/svelte/...)' vanilla)"
    npm create vite@latest "$TMP" -- --template "$T" ;;
  astro)
    npm create astro@latest "$TMP" -- --template minimal --no-git --skip-houston --yes ;;
  next)
    npx create-next-app@latest "$TMP" --yes --no-git ;;
  expo)
    npx create-expo-app@latest "$TMP" ;;
  *)  # własna komenda: %DIR% = katalog docelowy scaffoldu
    CMD="$(ask 'Pełna komenda scaffoldu (cel = %DIR%)' '')"
    [ -n "$CMD" ] || { echo "Brak komendy — przerywam."; exit 1; }
    eval "${CMD//%DIR%/$TMP}" ;;
esac

shopt -s dotglob
mv "$TMP"/* "$PROJECT"/ 2>/dev/null || true
shopt -u dotglob
rm -rf "$TMP"
ok "Kod ($STACK) w roocie projektu."

# CF: nadaj nazwę Workera → ładny URL <NAME>.<sub>.workers.dev.
if [ "$CF" = 1 ]; then
  for wf in wrangler.jsonc wrangler.json wrangler.toml; do
    [ -f "$wf" ] || continue
    case "$wf" in
      *.toml) sed -i "s/^name[[:space:]]*=[[:space:]]*\"[^\"]*\"/name = \"$NAME\"/" "$wf" ;;
      *)      sed -i "s/\"name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"name\": \"$NAME\"/" "$wf" ;;
    esac
  done
  ok "Worker nazwany: $NAME"
fi

say "Instancja → projekt"
rm -f "$FS/.is-boilerplate" && ok "Marker usunięty — deploy odblokowany."

# Izolacja: .fs/ poza gitem projektu.
if [ -f .gitignore ] && grep -qx '.fs/' .gitignore 2>/dev/null; then :; else
  printf '\n# futurestack (narzędzia deploy/proxy — nie część aplikacji)\n.fs/\n' >> .gitignore
fi

say "Git lokalny (bez remote)"
if [ -d .git ]; then
  ok "Git już jest — nie ruszam."
else
  git init -q && git add -A && git commit -qm "init: $NAME ($STACK)"
  ok "Repo lokalne utworzone. Zero remote, zero push."
fi

if [ "$CF" = 1 ]; then
  say "Pierwszy deploy (dowód środowiska)"
  if [ "$(ask 'Deploy teraz na Cloudflare? t/n' t)" = t ]; then
    . "$DIR/guard.sh"              # wymusza token+account, blokuje jak brak
    wrangler deploy
    ok "Live. URL powyżej (*.workers.dev) — jedyne miejsce podglądu."
  else
    ok "Deploy później: .fs/scripts/deploy.sh"
  fi
else
  ok "Stack nie-CF. Deploy: wybierz target w setup (picker) albo ustaw .fs/target.env,"
  ok "potem .fs/scripts/deploy.sh lub przycisk LIVE z telefonu."
fi
