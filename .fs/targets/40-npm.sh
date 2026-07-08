#!/usr/bin/env bash
# label: npm (skrypt deploy w package.json)
# Provider generyczny: projekt npm z własnym skryptem "deploy". Fallback dla stacków
# nieobjętych wyżej (Next/Nuxt/Remix/cokolwiek). needs_cf=1 tylko gdy wrangler w package.json.
describe(){
  local pj="$PROJECT/package.json"
  if [ "${FS_FORCED:-0}" != 1 ]; then
    [ -f "$pj" ] || return 0
    grep -qE '"deploy"[[:space:]]*:' "$pj" || return 0
  fi
  local nc=0; [ -f "$pj" ] && grep -q 'wrangler' "$pj" && nc=1
  # preview/dev tylko jeśli istnieją — inaczej puste (deploy.sh je pominie).
  local prev=''; grep -qE '"preview"[[:space:]]*:' "$pj" && prev='npm run preview'
  local dev='';  grep -qE '"dev"[[:space:]]*:'     "$pj" && dev='npm run dev'
  cat <<E
name='npm'
deploy='npm run deploy'
preview='$prev'
dev='$dev'
needs_cf=$nc
E
}
