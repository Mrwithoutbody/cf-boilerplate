#!/usr/bin/env bash
# Nowy projekt: scaffold Cloudflare Worker + git lokalny + pierwszy deploy.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; . ./.env; set +a; }   # CLOUDFLARE_ACCOUNT_ID dla pierwszego deploy
say(){ printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
ask(){ local p="$1" d="${2:-}"; local a; read -rp "$(printf '\033[1;33m? %s%s: \033[0m' "$p" "${d:+ [$d]}")" a; echo "${a:-$d}"; }

[ -d app ] && { ok "Katalog app/ już istnieje — pomijam scaffold."; exit 0; }

NAME="$(ask 'Nazwa projektu (a-z0-9-)' my-app)"
FRAMEWORK="$(ask 'Framework: hono / react-router / none' hono)"

say "Scaffold ($FRAMEWORK)"
if [ "$FRAMEWORK" = none ]; then
  npm create cloudflare@latest app -- --type=hello-world --lang=ts --no-git --no-deploy
else
  npm create cloudflare@latest app -- --framework="$FRAMEWORK" --no-git --no-deploy
fi

say "Git lokalny (bez remote)"
cp -n .gitignore app/.gitignore 2>/dev/null || true
git init -q
git add -A
git commit -qm "init: $NAME (Cloudflare Workers / $FRAMEWORK)"
ok "Repo lokalne utworzone. Zero remote, zero push."

say "Pierwszy deploy (dowód środowiska)"
if [ "$(ask 'Deploy teraz na Cloudflare? t/n' t)" = t ]; then
  ( cd app && wrangler deploy )
  ok "Live. URL powyżej (*.workers.dev) — jedyne miejsce podglądu."
else
  ok "Deploy później: scripts/deploy.sh"
fi
