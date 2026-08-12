#!/usr/bin/env bash
set -e
set -u

# ---------------------------------------------------------------------------
# Colors (auto-disabled when stdout is not a TTY or when NO_COLOR is set)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; BLUE=$'\e[34m'; CYAN=$'\e[36m'
  YELLOW=$'\e[33m'
  RESET=$'\e[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; BLUE=''; CYAN=''; YELLOW=''; RESET=''
fi

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
section() { printf '\n%s%s━━━ %s ━━━%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
ok()      { printf '%s  ✔ %s%s\n'         "$GREEN" "$1" "$RESET"; }
ko()      { printf '%s  ✘ %s%s\n'         "$RED"   "$1" "$RESET"; }
warn()    { printf '%s  ⚠ %s%s\n'         "$YELLOW" "$1" "$RESET"; }

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
# 4. Vulnerable packages in the container images
# ---------------------------------------------------------------------------
section "Scanning container images for CVEs"
# The images are built with Nix, so their exact runtime closure is known and
# vulnix can match every store path against the NVD database. Building
# `.#<tool>.image` realises the nix2container JSON manifest and the closure it
# references, which is all vulnix needs -- no container runtime involved.
# See runner/docs/development.md for the image list, why the build needs a
# relaxed sandbox, and how to triage and whitelist findings.
RUNNER_IMAGES="runner worker-k8s worker-ssh-slurm action-builder"
RUNNER_WHITELIST="runner/nix/vulnix-whitelist.toml"
# CVSSv3 base score at which a finding stops being a warning and fails the run.
# 7.0 is the CVSS "high" boundary, so low and medium findings only warn.
VULNIX_FAIL_SCORE="${VULNIX_FAIL_SCORE:-7.0}"

# Skipping is a convenience for contributors without a Nix install, never for
# CI: there the ryax-ci image provides nix, so a missing prerequisite means the
# scan is broken and must not pass silently.
scan_skip=""
if ! command -v nix >/dev/null 2>&1; then
  scan_skip="nix is not available, cannot build the image closures"
elif [ ! -f runner/flake.nix ]; then
  scan_skip="the runner submodule is not checked out"
fi

if [ -n "$scan_skip" ]; then
  if [ -n "${CI:-}" ]; then
    ko "$scan_skip"
    exit 1
  fi
  printf '%s  - skipped: %s%s\n' "$DIM" "$scan_skip" "$RESET"
else
  whitelist=""
  if [ -f "$RUNNER_WHITELIST" ]; then
    whitelist="$PWD/$RUNNER_WHITELIST"
  else
    printf '%s  no whitelist at %s, every finding will be reported%s\n' \
      "$DIM" "$RUNNER_WHITELIST" "$RESET"
  fi
  scan_dir="$(mktemp -d)"
  scan_marker="$(mktemp -u)"
  for image in $RUNNER_IMAGES; do
    printf '\n%s• %s%s\n' "$BLUE" "$image" "$RESET"
    # A build failure is a real error, so leave `set -e` in charge of it.
    (cd runner && nix build ".#${image}.image" \
      --option sandbox relaxed --no-warn-dirty \
      --out-link "$scan_dir/$image")
    # vulnix exits 0 when it finds nothing, 1 when only whitelisted issues
    # remain and 2 when something is not whitelisted.
    set +e
    if [ -n "$whitelist" ]; then
      nix run nixpkgs#vulnix -- --closure "$scan_dir/$image" --whitelist "$whitelist" \
        --json > "$scan_dir/$image.json"
    else
      nix run nixpkgs#vulnix -- --closure "$scan_dir/$image" --json > "$scan_dir/$image.json"
    fi
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then ok "$image: no known vulnerability"; continue; fi
    if [ "$rc" -eq 1 ]; then ok "$image: only whitelisted findings"; continue; fi

    # vulnix has no severity threshold of its own, so split its findings here:
    # only a CVSSv3 base score of $VULNIX_FAIL_SCORE or above fails the build,
    # anything below is reported but tolerated. A finding whose CVEs carry no
    # score at all counts as 0, so it warns rather than blocks.
    set +e
    verdict=$(python3 - "$scan_dir/$image.json" "$VULNIX_FAIL_SCORE" <<'PY'
import json, sys

report, threshold = sys.argv[1], float(sys.argv[2])
blocking, tolerated = [], []
for entry in json.load(open(report)):
    scores = entry.get("cvssv3_basescore") or {}
    cves = entry.get("affected_by") or []
    worst = max((scores.get(c) or 0 for c in cves), default=0)
    row = (f"{entry['pname']}-{entry['version']}", worst, len(cves))
    (blocking if worst >= threshold else tolerated).append(row)

for level, rows in (("fail", blocking), ("warn", tolerated)):
    for pkg, worst, count in sorted(rows, key=lambda r: -r[1]):
        print(f"{level}|{pkg}|{worst}|{count}")
sys.exit(1 if blocking else 0)
PY
    )
    split_rc=$?
    set -e
    while IFS='|' read -r level pkg worst count; do
      [ -z "$level" ] && continue
      msg="$image: $pkg — $count CVE(s), worst CVSS $worst"
      if [ "$level" = "fail" ]; then ko "$msg"; else warn "$msg"; fi
    done <<< "$verdict"
    if [ "$split_rc" -ne 0 ]; then
      touch "$scan_marker"
    else
      ok "$image: nothing at or above CVSS $VULNIX_FAIL_SCORE"
    fi
  done
  rm -rf "$scan_dir"
  if [ -f "$scan_marker" ]; then
    rm -f "$scan_marker"
    ko "Vulnerabilities of CVSS $VULNIX_FAIL_SCORE or above found in the container images"
    exit 1
  fi
  ok "No image vulnerability at or above CVSS $VULNIX_FAIL_SCORE"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf '\n%s ✔ All security checks passed %s\n' "$BOLD$GREEN" "$RESET"
