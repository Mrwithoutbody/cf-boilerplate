#!/usr/bin/env bash
# label: Cloudflare Workers
# Provider: goły Cloudflare Worker (wrangler.* w roocie, deploy przez wrangler).
describe(){
  [ "${FS_FORCED:-0}" = 1 ] || [ -f "$PROJECT/wrangler.toml" ] || [ -f "$PROJECT/wrangler.jsonc" ] || [ -f "$PROJECT/wrangler.json" ] || return 0
  cat <<'E'
name='cloudflare-workers'
deploy='npx wrangler deploy'
preview='npx wrangler versions upload'
dev='npx wrangler dev'
needs_cf=1
E
}
