#!/usr/bin/env bash
#
# Ryax security checks.
#
#   ./lint.sh                  run every check
#   ./lint.sh images           run only the container image CVE scan
#   ./lint.sh dead-code deps   run a subset, in the given order
#   ./lint.sh --list           list the available checks
#
# Every selected check runs even when an earlier one fails, so one broken check
# never hides the result of another; the exit status is non-zero if any failed.
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
# Available checks, in the order `./lint.sh` runs them. A check named `foo-bar`
# is implemented by the function `check_foo_bar` and must return non-zero on
# failure rather than exiting, so the runner can carry on to the next one.
# ---------------------------------------------------------------------------
CHECKS="dead-code flaws deps node-deps images"

# The Python tools come from the dev dependency group, so report a missing one
# as a setup problem instead of blaming the code it was meant to inspect.
require_tool() {
  command -v "$1" >/dev/null 2>&1 && return 0
  ko "$1 is not on PATH: run 'uv sync --all-groups' and add ./.venv/bin to PATH"
  return 1
}

describe_check() {
  case "$1" in
    dead-code) echo "unreachable Python code (vulture)" ;;
    flaws)     echo "high-severity Python security flaws (bandit)" ;;
    deps)      echo "vulnerable Python dependencies of every submodule (uv audit)" ;;
    node-deps) echo "vulnerable Node dependencies of the front (osv-scanner)" ;;
    images)    echo "known CVEs in the runner container images (vulnix)" ;;
    *)         echo "?" ;;
  esac
}

# ---------------------------------------------------------------------------
# dead-code
# ---------------------------------------------------------------------------
check_dead_code() {
  section "Searching for dead code"
  require_tool vulture || return 1
  vulture ./**/ryax --exclude "*_pb2.py,*_pb2_grpc.py" --min-confidence=80 || {
    ko "Dead code found"
    return 1
  }
  ok "No dead code"
}

# ---------------------------------------------------------------------------
# flaws
# ---------------------------------------------------------------------------
check_flaws() {
  section "Searching for security flaws"
  require_tool bandit || return 1
  bandit --severity-level=high --confidence-level=high -r ./**/ryax || {
    ko "High-severity flaws found"
    return 1
  }
  ok "No high-severity flaw"
}

# ---------------------------------------------------------------------------
# deps
# ---------------------------------------------------------------------------
check_deps() {
  section "Searching for vulnerable dependencies"
  require_tool uv || return 1
  # Marker file remembers whether any submodule reported a vulnerability, so we
  # can audit every repo first and only fail at the very end.
  export RYAX_VULN_MARKER; RYAX_VULN_MARKER="$(mktemp -u)"
  export RYAX_BLUE="$BLUE" RYAX_DIM="$DIM" RYAX_RESET="$RESET"
  # Run the audit directly via foreach (no nested `bash -c`) so git's $displaypath
  # variable is visible; the script body is POSIX, so no extra shell is needed.
  #
  # --frozen audits the committed uv.lock instead of re-resolving. Without it uv
  # insists on an interpreter matching each submodule's `requires-python`, which
  # the CI image does not have (it ships one Python, and UV_PYTHON_DOWNLOADS is
  # deliberately `never` because a downloaded interpreter is not linked against
  # that image's loader) -- so four of the eight submodules failed to audit at all
  # rather than reporting anything. Auditing what is locked is also what we
  # actually want to know.
  # The body always succeeds (`|| touch`), so a non-zero status here means git
  # itself could not iterate the submodules. Without this check that reports
  # "no vulnerability" while having audited nothing at all.
  if ! git submodule foreach --quiet '
    if [ -f pyproject.toml ]; then
      printf "\n%s• %s%s\n" "$RYAX_BLUE" "$displaypath" "$RYAX_RESET"
      uv audit --preview-features audit --frozen || touch "$RYAX_VULN_MARKER"
    else
      printf "%s  - %s (no pyproject.toml, skipped)%s\n" "$RYAX_DIM" "$displaypath" "$RYAX_RESET"
    fi
  '; then
    rm -f "$RYAX_VULN_MARKER"
    ko "Could not iterate the submodules, nothing was audited"
    return 1
  fi
  if [ -f "$RYAX_VULN_MARKER" ]; then
    rm -f "$RYAX_VULN_MARKER"
    ko "Vulnerabilities found in dependencies"
    return 1
  fi
  ok "No high-severity vulnerability"
}

# ---------------------------------------------------------------------------
# node-deps
# ---------------------------------------------------------------------------
# The front is the one submodule with no Python in it, and the ryax-ci image ships
# no node at all -- so this reads front/yarn.lock directly with osv-scanner rather
# than installing a JavaScript toolchain to ask the question.
#
# That also makes it wider than the audit the front's own pipeline runs: the npm
# registry's /security/audits/quick endpoint answers 400 Bad Request for a tree
# this size unless the request is narrowed to the production environment, so
# `yarn npm audit` over there cannot see the devDependencies at all. osv-scanner
# resolves every entry in the lockfile.
#
# Findings triaged as not applicable go in front/osv-scanner.toml, which the
# scanner picks up by itself because it sits next to the lockfile:
#
#   [[IgnoredVulns]]
#   id = "GHSA-xxxx-xxxx-xxxx"
#   reason = "why this one does not apply to us"
#
# Same rule as runner/nix/vulnix-whitelist.toml: no entry without a reason.
FRONT_LOCKFILE="front/yarn.lock"

check_node_deps() {
  section "Scanning the front dependencies for CVEs"

  # Skipping is a convenience for contributors without nix or without the
  # submodule checked out, never for CI: there a missing prerequisite means the
  # scan is broken and must not pass silently.
  local skip=""
  if ! command -v nix >/dev/null 2>&1; then
    skip="nix is not available, cannot run osv-scanner"
  elif [ ! -f "$FRONT_LOCKFILE" ]; then
    skip="$FRONT_LOCKFILE is missing, the front submodule is not checked out"
  fi
  if [ -n "$skip" ]; then
    if [ -n "${CI:-}" ]; then
      ko "$skip"
      return 1
    fi
    printf '%s  - skipped: %s%s\n' "$DIM" "$skip" "$RESET"
    return 0
  fi

  local scan_dir report errlog rc verdict split_rc level pkg worst count msg
  scan_dir="$(mktemp -d)"
  report="$scan_dir/osv.json"
  errlog="$scan_dir/osv.err"

  rc=0
  nix run nixpkgs#osv-scanner -- scan source --lockfile "$FRONT_LOCKFILE" \
    --format json > "$report" 2> "$errlog" || rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -rf "$scan_dir"
    ok "No known vulnerability in $FRONT_LOCKFILE"
    return 0
  fi

  # osv-scanner exits non-zero both when it finds something and when it fails
  # outright, so the report itself decides which happened: anything the splitter
  # below cannot parse is a broken scan, not a clean one.
  #
  # It has no severity threshold of its own either, so split the findings here on
  # the advisory severity, the way check_images splits vulnix findings on CVSS:
  # HIGH and CRITICAL fail the run, everything else is reported and tolerated. An
  # advisory carrying no severity at all counts as tolerated, so it warns rather
  # than blocks.
  split_rc=0
  verdict=$(python3 - "$report" <<'OSVPY'
import json, sys

try:
    data = json.load(open(sys.argv[1]))
except Exception as exc:  # empty or unparseable: the scan itself failed
    print(f"error|{exc}|-|0")
    sys.exit(2)

blocking, tolerated = [], []
for result in data.get("results", []):
    for pkg in result.get("packages", []):
        name = pkg.get("package", {}).get("name", "?")
        version = pkg.get("package", {}).get("version", "?")
        vulns = pkg.get("vulnerabilities", [])
        high = [
            severity
            for vuln in vulns
            for severity in [((vuln.get("database_specific") or {}).get("severity") or "").upper()]
            if severity in ("HIGH", "CRITICAL")
        ]
        if high:
            worst = "CRITICAL" if "CRITICAL" in high else "HIGH"
            blocking.append((f"{name}@{version}", worst, len(high)))
        elif vulns:
            tolerated.append((f"{name}@{version}", "moderate or lower", len(vulns)))

for level, rows in (("fail", blocking), ("warn", tolerated)):
    for pkg, worst, count in sorted(rows):
        print(f"{level}|{pkg}|{worst}|{count}")
sys.exit(1 if blocking else 0)
OSVPY
  ) || split_rc=$?
  if [ "$split_rc" -eq 2 ]; then
    printf '%s\n' "$verdict" | sed 's/^/    /'
    sed 's/^/    /' "$errlog"
    rm -rf "$scan_dir"
    ko "osv-scanner did not produce a usable report"
    return 1
  fi

  while IFS='|' read -r level pkg worst count; do
    [ -z "$level" ] && continue
    msg="$pkg — $count advisory(ies), worst $worst"
    if [ "$level" = "fail" ]; then ko "$msg"; else warn "$msg"; fi
  done <<< "$verdict"
  rm -rf "$scan_dir"

  if [ "$split_rc" -ne 0 ]; then
    ko "High or critical advisories found in $FRONT_LOCKFILE"
    return 1
  fi
  ok "Nothing high or critical in $FRONT_LOCKFILE"
}

# ---------------------------------------------------------------------------
# images
# ---------------------------------------------------------------------------
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

check_images() {
  section "Scanning container images for CVEs"

  # Skipping is a convenience for contributors without a Nix install, never for
  # CI: there the ryax-ci image provides nix, so a missing prerequisite means the
  # scan is broken and must not pass silently.
  local skip=""
  if ! command -v nix >/dev/null 2>&1; then
    skip="nix is not available, cannot build the image closures"
  elif [ ! -f runner/flake.nix ]; then
    skip="the runner submodule is not checked out"
  fi
  if [ -n "$skip" ]; then
    if [ -n "${CI:-}" ]; then
      ko "$skip"
      return 1
    fi
    printf '%s  - skipped: %s%s\n' "$DIM" "$skip" "$RESET"
    return 0
  fi

  local whitelist=""
  if [ -f "$RUNNER_WHITELIST" ]; then
    whitelist="$PWD/$RUNNER_WHITELIST"
  else
    printf '%s  no whitelist at %s, every finding will be reported%s\n' \
      "$DIM" "$RUNNER_WHITELIST" "$RESET"
  fi

  local scan_dir image rc verdict split_rc level pkg worst count msg
  local blocking=0
  scan_dir="$(mktemp -d)"

  # Realise every closure in one invocation first. The four images share most of
  # their dependency graph, so building them one at a time serialises four
  # batches of substitution -- several hundred MiB in total -- that nix would
  # otherwise overlap with each other and with the derivations it has to build.
  # The per-image builds below then hit the local store. Failures are ignored
  # here on purpose: the loop reports which image failed and why.
  local -a all_attrs=()
  for image in $RUNNER_IMAGES; do
    all_attrs+=(".#${image}.image")
  done
  printf '%s  realising %d image closures%s\n' "$DIM" "${#all_attrs[@]}" "$RESET"
  (cd runner && nix build "${all_attrs[@]}" \
      --option sandbox relaxed --no-warn-dirty --no-link) || true

  for image in $RUNNER_IMAGES; do
    printf '\n%s• %s%s\n' "$BLUE" "$image" "$RESET"
    # A build failure is a real error, distinct from a vulnerability finding.
    if ! (cd runner && nix build ".#${image}.image" \
            --option sandbox relaxed --no-warn-dirty \
            --out-link "$scan_dir/$image"); then
      ko "$image: could not build the image"
      blocking=1
      continue
    fi
    # vulnix exits 0 when it finds nothing, 1 when only whitelisted issues
    # remain and 2 when something is not whitelisted.
    rc=0
    if [ -n "$whitelist" ]; then
      nix run nixpkgs#vulnix -- --closure "$scan_dir/$image" --whitelist "$whitelist" \
        --json > "$scan_dir/$image.json" || rc=$?
    else
      nix run nixpkgs#vulnix -- --closure "$scan_dir/$image" \
        --json > "$scan_dir/$image.json" || rc=$?
    fi
    if [ "$rc" -eq 0 ]; then ok "$image: no known vulnerability"; continue; fi
    if [ "$rc" -eq 1 ]; then ok "$image: only whitelisted findings"; continue; fi

    # vulnix has no severity threshold of its own, so split its findings here:
    # only a CVSSv3 base score of $VULNIX_FAIL_SCORE or above fails the build,
    # anything below is reported but tolerated. A finding whose CVEs carry no
    # score at all counts as 0, so it warns rather than blocks.
    split_rc=0
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
    ) || split_rc=$?
    while IFS='|' read -r level pkg worst count; do
      [ -z "$level" ] && continue
      msg="$image: $pkg — $count CVE(s), worst CVSS $worst"
      if [ "$level" = "fail" ]; then ko "$msg"; else warn "$msg"; fi
    done <<< "$verdict"
    if [ "$split_rc" -ne 0 ]; then
      blocking=1
    else
      ok "$image: nothing at or above CVSS $VULNIX_FAIL_SCORE"
    fi
  done
  rm -rf "$scan_dir"

  if [ "$blocking" -ne 0 ]; then
    ko "Vulnerabilities of CVSS $VULNIX_FAIL_SCORE or above found in the container images"
    return 1
  fi
  ok "No image vulnerability at or above CVSS $VULNIX_FAIL_SCORE"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
usage() {
  printf 'Usage: %s [CHECK...]\n\nWith no argument every check runs.\n\nChecks:\n' "$0"
  local name
  for name in $CHECKS; do
    printf '  %-10s %s\n' "$name" "$(describe_check "$name")"
  done
}

selected="$CHECKS"
if [ "$#" -gt 0 ]; then
  case "$1" in
    -h|--help|--list) usage; exit 0 ;;
  esac
  for name in "$@"; do
    case " $CHECKS " in
      *" $name "*) ;;
      *) ko "Unknown check: $name"; usage >&2; exit 2 ;;
    esac
  done
  selected="$*"
fi

failed=""
for name in $selected; do
  # `set -e` is suspended inside a function called in a condition, which is why
  # every check handles its own command failures explicitly.
  if ! "check_${name//-/_}"; then
    failed="$failed $name"
  fi
done

if [ -n "$failed" ]; then
  printf '\n%s ✘ Failed:%s %s\n' "$BOLD$RED" "$RESET" "${failed# }"
  exit 1
fi
printf '\n%s ✔ All security checks passed %s\n' "$BOLD$GREEN" "$RESET"
