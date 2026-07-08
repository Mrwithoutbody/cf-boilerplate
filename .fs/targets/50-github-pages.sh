#!/usr/bin/env bash
# label: GitHub Pages
# Provider: GitHub Pages. needs_cf=0 — deploy przez GitHub (Actions albo gh-pages),
# nie przez Cloudflare. Wykrywa: workflow Pages, dep gh-pages, albo CNAME/.nojekyll.
describe(){
  local pj="$PROJECT/package.json" hit=0
  if [ "${FS_FORCED:-0}" != 1 ]; then
    grep -rqs 'actions/deploy-pages\|actions/upload-pages-artifact' "$PROJECT/.github/workflows" 2>/dev/null && hit=1
    [ -f "$pj" ] && grep -q 'gh-pages' "$pj" && hit=1
    { [ -f "$PROJECT/CNAME" ] || [ -f "$PROJECT/.nojekyll" ]; } && hit=1
    [ "$hit" = 1 ] || return 0
  fi

  # deploy: npm "deploy" > gh-pages CLI > push (Actions robi resztę).
  local dep='git push' prev='' dev=''
  if [ -f "$pj" ]; then
    grep -q 'gh-pages' "$pj" && dep='npx gh-pages -d dist'
    grep -qE '"deploy"[[:space:]]*:' "$pj" && dep='npm run deploy'
    grep -qE '"dev"[[:space:]]*:'    "$pj" && dev='npm run dev'
  fi
  cat <<E
name='github-pages'
deploy='$dep'
preview='$prev'
dev='$dev'
needs_cf=0
E
}
