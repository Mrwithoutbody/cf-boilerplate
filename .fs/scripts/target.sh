#!/usr/bin/env bash
# Wykrywacz targetu w stylu MCP: iteruje providery w .fs/targets/, każdy sam
# sprawdza projekt i deklaruje komendy. Pierwszy trafiony (kolejność NN-) wygrywa.
# Dodanie stacka = nowy plik w .fs/targets/. Nadpisanie: .fs/target.env
#   FS_TARGET=nazwa                     # wymuś providera
#   FS_DEPLOY / FS_PREVIEW / FS_DEV     # własne komendy
#   FS_NEEDS_CF=0|1                     # czy wymaga creds Cloudflare
# Sourced. Wymaga PROJECT. Ustawia: T_NAME T_DEPLOY T_PREVIEW T_DEV T_NEEDS_CF.
_TS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_FS_DIR="$(cd "$_TS_DIR/.." && pwd)"
_TARGETS="$_FS_DIR/targets"
: "${PROJECT:?target.sh: PROJECT nie ustawiony}"

T_NAME=""; T_DEPLOY=""; T_PREVIEW=""; T_DEV=""; T_NEEDS_CF=1

# Override z .fs/target.env (opcjonalny).
_FORCE=""
[ -f "$_FS_DIR/target.env" ] && { set -a; . "$_FS_DIR/target.env"; set +a; _FORCE="${FS_TARGET:-}"; }

for _p in "$_TARGETS"/*.sh; do
  [ -f "$_p" ] || continue
  _nm="$(basename "$_p" .sh | sed 's/^[0-9]*-//')"
  [ -n "$_FORCE" ] && [ "$_FORCE" != "$_nm" ] && continue
  # Provider w subshellu (izolacja describe/zmiennych). Match → echo assignments.
  # FS_FORCED=1 dla jawnie wymuszonego (FS_TARGET) → provider omija detekcję,
  # emituje domyślne komendy nawet gdy projekt nie ma jego markerów.
  _fc=0; [ -n "$_FORCE" ] && _fc=1
  _out="$(PROJECT="$PROJECT" FS_FORCED="$_fc" bash -c 'source "$1"; describe' _ "$_p" 2>/dev/null)"
  [ -n "$_out" ] || continue
  name=""; deploy=""; preview=""; dev=""; needs_cf=1
  eval "$_out"
  T_NAME="${name:-$_nm}"; T_DEPLOY="$deploy"; T_PREVIEW="$preview"; T_DEV="$dev"; T_NEEDS_CF="$needs_cf"
  break
done

# Jawne komendy z target.env biją wykryte.
[ -n "${FS_DEPLOY:-}" ]  && T_DEPLOY="$FS_DEPLOY"
[ -n "${FS_PREVIEW:-}" ] && T_PREVIEW="$FS_PREVIEW"
[ -n "${FS_DEV:-}" ]     && T_DEV="$FS_DEV"
[ -n "${FS_NEEDS_CF:-}" ] && T_NEEDS_CF="$FS_NEEDS_CF"

# WAŻNE: sourced pod `set -e` — ostatnia komenda MUSI zwrócić 0, inaczej
# `. target.sh` ubije wołającego (deploy/preview) gdy powyższe [ -n ] = false.
true
