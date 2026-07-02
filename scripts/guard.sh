#!/usr/bin/env bash
# Wspólny guard przed każdą operacją deploy/preview.
# Sourced (. guard.sh) — ustawia i eksportuje CLOUDFLARE_* z .env projektu.
# Blokuje: (1) deploy z boilerplate DEV, (2) deploy bez jawnego configu jednego konta.
guard_die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -f "$_ROOT/.is-boilerplate" ] && guard_die \
  "To jest boilerplate DEV — deploy zablokowany. Pobierz instancję (npx degit) do osobnego folderu i uruchom ./setup.sh."

[ -f "$_ROOT/.env" ] || guard_die \
  "Brak .env. Uruchom ./setup.sh i podaj account_id + token SCOPED na jedno konto."

set -a; . "$_ROOT/.env"; set +a

[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ] || guard_die \
  "CLOUDFLARE_ACCOUNT_ID pusty w .env. Deploy tylko na JAWNIE wskazane konto — nigdy zgadywane."
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || guard_die \
  "CLOUDFLARE_API_TOKEN pusty. Użyj tokenu API ograniczonego do JEDNEGO konta (nie 'wrangler login', bo widzi wszystkie konta)."

export CLOUDFLARE_ACCOUNT_ID CLOUDFLARE_API_TOKEN
printf "\033[1;32m✔ guard: deploy dozwolony na konto %s\033[0m\n" "$CLOUDFLARE_ACCOUNT_ID"
