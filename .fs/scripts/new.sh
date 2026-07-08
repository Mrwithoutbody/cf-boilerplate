#!/usr/bin/env bash
# Nowy projekt: scaffold Workera do ROOTA projektu (rodzic .fs/), git lokalny,
# opcjonalny pierwszy deploy. Kod ląduje w roocie — .fs/ zostaje obok, izolowane.
set -euo pipefail
DIR="$(dirname "$0")"
FS="$(cd "$DIR/.." && pwd)"           # katalog .fs/ (narzędzia futurestack)
PROJECT="$(cd "$FS/.." && pwd)"       # projekt = rodzic .fs/ (tu ląduje kod)
cd "$PROJECT"
say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

if [ -f wrangler.toml ] || [ -f wrangler.jsonc ] || [ -f wrangler.json ]; then
  ok "Worker już w roocie — pomijam scaffold."; exit 0
fi

# Domyślna nazwa = nazwa folderu projektu, znormalizowana (wymóg Cloudflare).
DEF_NAME="$(basename "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')"
[ -n "$DEF_NAME" ] || DEF_NAME=my-app
NAME="$(ask 'Nazwa projektu (a-z0-9-)' "$DEF_NAME")"
FRAMEWORK="$(ask 'Framework: hono / react-router / none' hono)"

say "Scaffold ($FRAMEWORK) → root projektu"
# C3 wymaga pustego celu — scaffolduj do temp w .fs/, potem przenieś do roota.
TMP="$FS/.scaffold"
rm -rf "$TMP"
if [ "$FRAMEWORK" = none ]; then
  npm create cloudflare@latest "$TMP" -- --type=hello-world --lang=ts --no-git --no-deploy
else
  npm create cloudflare@latest "$TMP" -- --framework="$FRAMEWORK" --no-git --no-deploy
fi
shopt -s dotglob
mv "$TMP"/* "$PROJECT"/ 2>/dev/null || true
shopt -u dotglob
rm -rf "$TMP"
ok "Kod Workera w roocie projektu."

# Nazwa Workera (scaffold nazywa po katalogu temp) → ładny URL <NAME>.<sub>.workers.dev.
for wf in wrangler.jsonc wrangler.json wrangler.toml; do
  [ -f "$wf" ] || continue
  case "$wf" in
    *.toml) sed -i "s/^name[[:space:]]*=[[:space:]]*\"[^\"]*\"/name = \"$NAME\"/" "$wf" ;;
    *)      sed -i "s/\"name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"name\": \"$NAME\"/" "$wf" ;;
  esac
done
ok "Worker nazwany: $NAME"

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
  git init -q && git add -A && git commit -qm "init: $NAME (Cloudflare Workers / $FRAMEWORK)"
  ok "Repo lokalne utworzone. Zero remote, zero push."
fi

say "Pierwszy deploy (dowód środowiska)"
if [ "$(ask 'Deploy teraz na Cloudflare? t/n' t)" = t ]; then
  . "$DIR/guard.sh"              # wymusza token+account, blokuje jak brak
  wrangler deploy
  ok "Live. URL powyżej (*.workers.dev) — jedyne miejsce podglądu."
else
  ok "Deploy później: .fs/scripts/deploy.sh"
fi
