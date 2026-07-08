#!/usr/bin/env bash
# label: Expo / React Native (EAS)
# Provider: Expo / React Native (EAS). needs_cf=0 — deploy nie idzie przez Cloudflare.
describe(){
  local pj="$PROJECT/package.json"
  [ "${FS_FORCED:-0}" = 1 ] \
    || { [ -f "$pj" ] && grep -q '"expo"' "$pj"; } \
    || [ -f "$PROJECT/app.json" ] || [ -f "$PROJECT/app.config.js" ] || [ -f "$PROJECT/app.config.ts" ] \
    || return 0
  cat <<'E'
name='expo'
deploy='npx eas build --platform all'
preview='npx eas update --auto'
dev='npx expo start'
needs_cf=0
E
}
