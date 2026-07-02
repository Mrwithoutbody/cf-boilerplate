#!/usr/bin/env bash
# Nowy projekt z instancji boilerplate: scaffold Worker + git lokalny + (opcjonalny) deploy.
# Tworzy realny projekt => usuwa marker .is-boilerplate (odblokowuje deploy na skonfigurowane konto).
set -euo pipefail
DIR="$(dirname "$0")"
cd "$DIR/.."
say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

[ -d app ] && { ok "Katalog app/ już istnieje — pomijam scaffold."; exit 0; }

# Domyślna nazwa = nazwa folderu, znormalizowana do a-z0-9- (wymóg Cloudflare).
DEF_NAME="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')"
[ -n "$DEF_NAME" ] || DEF_NAME=my-app
NAME="$(ask 'Nazwa projektu (a-z0-9-)' "$DEF_NAME")"
FRAMEWORK="$(ask 'Framework: hono / react-router / none' hono)"

say "Scaffold ($FRAMEWORK)"
if [ "$FRAMEWORK" = none ]; then
  npm create cloudflare@latest app -- --type=hello-world --lang=ts --no-git --no-deploy
else
  npm create cloudflare@latest app -- --framework="$FRAMEWORK" --no-git --no-deploy
fi

# Scaffold nazywa Workera po katalogu ("app"). Nadaj nazwę projektu → ładny
# URL <NAME>.<sub>.workers.dev zamiast app.<sub>.workers.dev.
for wf in app/wrangler.jsonc app/wrangler.json app/wrangler.toml; do
  [ -f "$wf" ] || continue
  case "$wf" in
    *.toml) sed -i "s/^name[[:space:]]*=[[:space:]]*\"app\"/name = \"$NAME\"/" "$wf" ;;
    *)      sed -i "s/\"name\"[[:space:]]*:[[:space:]]*\"app\"/\"name\": \"$NAME\"/" "$wf" ;;
  esac
done
ok "Worker nazwany: $NAME"

say "Instancja → projekt"
rm -f .is-boilerplate && ok "Marker usunięty — to jest teraz projekt (nie boilerplate)."

say "Git lokalny (bez remote)"
cp -n .gitignore app/.gitignore 2>/dev/null || true
git init -q
git add -A
git commit -qm "init: $NAME (Cloudflare Workers / $FRAMEWORK)"
ok "Repo lokalne utworzone. Zero remote, zero push."

say "Pierwszy deploy (dowód środowiska)"
if [ "$(ask 'Deploy teraz na Cloudflare? t/n' t)" = t ]; then
  . "$DIR/guard.sh"              # wymusza token+account, blokuje jak brak
  ( cd app && wrangler deploy )
  ok "Live. URL powyżej (*.workers.dev) — jedyne miejsce podglądu."
else
  ok "Deploy później: scripts/deploy.sh"
fi
