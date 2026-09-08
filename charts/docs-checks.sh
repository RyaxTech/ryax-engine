#!/usr/bin/env bash
#
# Verify that the helm-docs-generated chart READMEs still match the values files
# they document.
#
#   charts/docs-checks.sh
#
# The READMEs are generated, so nothing stops a values change from landing
# without them: it has already happened twice, and a stale table is worse than no
# table because it reads as current. This regenerates them and reports whether
# anything moved.
#
# On failure the regenerated files are left in the worktree -- the fix is to
# commit them.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; CYAN=$'\e[36m'; YELLOW=$'\e[33m'
  RESET=$'\e[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; CYAN=''; YELLOW=''; RESET=''
fi
section() { printf '\n%s%s━━━ %s ━━━%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
ok()      { printf '%s  ✔ %s%s\n'          "$GREEN" "$1" "$RESET"; }
ko()      { printf '%s  ✘ %s%s\n'          "$RED"   "$1" "$RESET"; }
warn()    { printf '%s  ⚠ %s%s\n'          "$YELLOW" "$1" "$RESET"; }
info()    { printf '%s  · %s%s\n'          "$DIM"   "$1" "$RESET"; }

for tool in helm-docs git; do
  command -v "$tool" >/dev/null 2>&1 || { ko "$tool is not on PATH"; exit 1; }
done

section "Regenerating the chart READMEs"

# helm-docs stamps its own version into every file it writes, so the committed
# files say which version produced them. Comparing the two is what lets a stale
# README be told apart from a helm-docs release having changed its output.
recorded="$(sed -n 's|.*helm-docs v\([0-9][0-9.]*\).*|\1|p' charts/ryax/README.md | head -1)"
running="$(helm-docs --version 2>/dev/null | sed -n 's|.*version \([0-9][0-9.]*\).*|\1|p' | head -1)"
info "helm-docs ${running:-?} running, ${recorded:-?} produced the committed files"

if ! (cd charts && helm-docs >/dev/null 2>&1); then
  ko "helm-docs failed"
  (cd charts && helm-docs)
  exit 1
fi

changed="$(git diff --name-only -- 'charts/*README.md' 'charts/**/README.md')"
if [ -z "$changed" ]; then
  ok "Every chart README matches its values"
  exit 0
fi

# An upstream helm-docs release can reformat its output, which is nobody's fault
# and must not block a merge request that has nothing to do with it -- the same
# reasoning as check_helm_deps. A difference at the *same* version means a values
# change landed without regenerating, which is exactly what this guards.
if [ "$recorded" != "$running" ]; then
  warn "helm-docs moved from v$recorded to v$running, so its output changed:"
  printf '%s\n' "$changed" | sed 's/^/      /'
  warn "run 'cd charts && helm-docs' and commit the result"
  exit 0
fi

ko "these generated READMEs are behind their values:"
printf '%s\n' "$changed" | sed 's/^/      /'
git --no-pager diff --stat -- 'charts/*README.md' 'charts/**/README.md'
printf '\n%s  run '\''cd charts && helm-docs'\'' and commit the result%s\n' "$DIM" "$RESET"
exit 1
