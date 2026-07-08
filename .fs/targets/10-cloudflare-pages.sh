#!/usr/bin/env bash
# label: Cloudflare Pages
# Provider: Cloudflare Pages. Bardziej specyficzny niż goły Worker — pierwszy.
# Łapie też Pages BEZ package.json (statyczny shell + Functions) po
# `pages_build_output_dir` w wrangler.*. describe(): echo assignments gdy pasuje.
describe(){
  local pj="$PROJECT/package.json" hit=0
  if [ "${FS_FORCED:-0}" != 1 ]; then
    if [ -f "$pj" ] && { grep -q 'pages deploy' "$pj" || grep -q '@astrojs/cloudflare' "$pj"; }; then hit=1; fi
    grep -qs 'pages_build_output_dir' "$PROJECT"/wrangler.toml "$PROJECT"/wrangler.jsonc 2>/dev/null && hit=1
    [ "$hit" = 1 ] || return 0
  fi

  # Priorytet komendy deployu (od najbezpieczniejszej/najbardziej jawnej):
  #   1. bespoke skrypt projektu (scripts/deploy-pages.sh) — projekt wie lepiej,
  #      często buduje CZYSTY dist żeby NIE wyciekły .env/sekrety (patrz smart-learning)
  #   2. skrypt npm "deploy"
  #   3. goły `wrangler pages deploy`
  local dep='npx wrangler pages deploy' prev='npx wrangler pages dev .' dev='npx wrangler pages dev .'
  if [ -f "$pj" ]; then
    grep -qE '"deploy"[[:space:]]*:'  "$pj" && dep='npm run deploy'
    grep -qE '"preview"[[:space:]]*:' "$pj" && prev='npm run preview'
    grep -qE '"dev"[[:space:]]*:'     "$pj" && dev='npm run dev'
  fi
  [ -f "$PROJECT/scripts/deploy-pages.sh" ] && dep='bash scripts/deploy-pages.sh'
  cat <<E
name='cloudflare-pages'
deploy='$dep'
preview='$prev'
dev='$dev'
needs_cf=1
E
}
