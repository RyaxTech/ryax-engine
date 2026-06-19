#!/usr/bin/env bash
set -e
set -u

# ---------------------------------------------------------------------------
# Colors (auto-disabled when stdout is not a TTY or when NO_COLOR is set)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; BLUE=$'\e[34m'; CYAN=$'\e[36m'
  RESET=$'\e[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; BLUE=''; CYAN=''; RESET=''
fi

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
section() { printf '\n%s%s━━━ %s ━━━%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
ok()      { printf '%s  ✔ %s%s\n'         "$GREEN" "$1" "$RESET"; }
ko()      { printf '%s  ✘ %s%s\n'         "$RED"   "$1" "$RESET"; }

# ---------------------------------------------------------------------------
# 1. Dead code
# ---------------------------------------------------------------------------
section "Searching for dead code"
vulture ./**/ryax --exclude "*_pb2.py,*_pb2_grpc.py" --min-confidence=80
ok "No dead code"

# ---------------------------------------------------------------------------
# 2. Security flaws
# ---------------------------------------------------------------------------
section "Searching for security flaws"
bandit --severity-level=high --confidence-level=high -r ./**/ryax
ok "No high-severity flaw"

# ---------------------------------------------------------------------------
# 3. Vulnerable dependencies
# ---------------------------------------------------------------------------
section "Searching for vulnerable dependencies"
# Marker file remembers whether any submodule reported a vulnerability, so we
# can audit every repo first and only fail at the very end.
export RYAX_VULN_MARKER; RYAX_VULN_MARKER="$(mktemp -u)"
export RYAX_BLUE="$BLUE" RYAX_DIM="$DIM" RYAX_RESET="$RESET"
# Run the audit directly via foreach (no nested `bash -c`) so git's $displaypath
# variable is visible; the script body is POSIX, so no extra shell is needed.
git submodule foreach --quiet '
  if [ -f pyproject.toml ]; then
    printf "\n%s• %s%s\n" "$RYAX_BLUE" "$displaypath" "$RYAX_RESET"
    uv audit --preview-features audit || touch "$RYAX_VULN_MARKER"
  else
    printf "%s  - %s (no pyproject.toml, skipped)%s\n" "$RYAX_DIM" "$displaypath" "$RYAX_RESET"
  fi
'
if [ -f "$RYAX_VULN_MARKER" ]; then
  rm -f "$RYAX_VULN_MARKER"
  ko "Vulnerabilities found in dependencies"
  exit 1
fi
ok "No high-severity vulnerability"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf '\n%s ✔ All security checks passed %s\n' "$BOLD$GREEN" "$RESET"
