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
    images)    echo "known CVEs in the Ryax container images (vulnix)" ;;
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
# Same rule as core/nix/vulnix-whitelist.toml: no entry without a reason.
FRONT_LOCKFILE="front/yarn.lock"

# Where vulnix keeps the NVD feeds it downloads (vulnix's own default). CI
# points it inside the project and caches it between pipelines: downloading
# the whole database every run is what times out against nvd.nist.gov.
VULNIX_CACHE_DIR="${VULNIX_CACHE_DIR:-$HOME/.cache/vulnix}"
# Seconds one vulnix run may take before it is killed and retried.
VULNIX_ATTEMPT_TIMEOUT="${VULNIX_ATTEMPT_TIMEOUT:-900}"
# Where vulnix downloads the NVD feeds from, when not nvd.nist.gov (vulnix's
# default). Empty: the default. See nix-community/vulnix#171.
VULNIX_MIRROR="${VULNIX_MIRROR:-}"
# Set (CI does), the feeds are fetched into this directory first -- resumed,
# retried, checked against their .meta, and only when they changed -- and
# served to vulnix from 127.0.0.1. vulnix's own download gives up after 10s
# without data and starts over each time, which nvd.nist.gov and its mirrors
# are too slow for from CI. Empty: vulnix downloads the feeds itself.
VULNIX_FEEDS_DIR="${VULNIX_FEEDS_DIR:-}"
# Where to fetch them from, tried in order.
VULNIX_FEED_SOURCES="${VULNIX_FEED_SOURCES:-https://nvd.nist.gov/feeds/json/cve/2.0/ https://mirror.cveb.in/nvd/json/cve/2.0/}"

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
# See core/docs/development.md for the image list, why the build needs a
# relaxed sandbox, and how to triage and whitelist findings.
CORE_IMAGES="runner worker-k8s worker-ssh-slurm action-builder authorization"
CORE_WHITELIST="core/nix/vulnix-whitelist.toml"
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
  elif [ ! -f core/flake.nix ]; then
    skip="the core submodule is not checked out"
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
  if [ -f "$CORE_WHITELIST" ]; then
    whitelist="$PWD/$CORE_WHITELIST"
  else
    printf '%s  no whitelist at %s, every finding will be reported%s\n' \
      "$DIM" "$CORE_WHITELIST" "$RESET"
  fi

  local scan_dir image rc verdict split_rc level pkg worst count ids msg
  local scan_errors=0
  local blocking=0
  scan_dir="$(mktemp -d)"

  # Realise every closure in one invocation first. The four images share most of
  # their dependency graph, so building them one at a time serialises four
  # batches of substitution -- several hundred MiB in total -- that nix would
  # otherwise overlap with each other and with the derivations it has to build.
  # The per-image builds below then hit the local store. Failures are ignored
  # here on purpose: the loop reports which image failed and why.
  local -a all_attrs=()
  for image in $CORE_IMAGES; do
    all_attrs+=(".#${image}.image")
  done
  printf '%s  realising %d image closures%s\n' "$DIM" "${#all_attrs[@]}" "$RESET"
  (cd core && nix build "${all_attrs[@]}" \
      --option sandbox relaxed --no-warn-dirty --no-link) || true

  local feed_server_pid=""
  if [ -n "$VULNIX_FEEDS_DIR" ]; then
    printf '%s  fetching the NVD feeds into %s%s\n' "$DIM" "$VULNIX_FEEDS_DIR" "$RESET"
    # shellcheck disable=SC2086 # the sources are a space-separated list
    if ! python3 - "$VULNIX_FEEDS_DIR" $VULNIX_FEED_SOURCES <<'NVDPY'
import gzip, hashlib, os, sys, time, urllib.request
from datetime import date

dest, sources = sys.argv[1], [s.rstrip("/") + "/" for s in sys.argv[2:]]
os.makedirs(dest, exist_ok=True)
year = date.today().year
# What vulnix 1.12 asks its mirror for: the last six yearly feeds, and the
# "modified" one once its database is less than a week old.
names = [str(y) for y in range(year - 5, year + 1)] + ["modified"]


def get(url, timeout, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": "ryax-ci", **(headers or {})})
    return urllib.request.urlopen(req, timeout=timeout)


def parse_meta(text):
    fields = dict(line.split(":", 1) for line in text.strip().splitlines() if ":" in line)
    return {"sha256": fields["sha256"].strip().lower(), "gzSize": int(fields["gzSize"])}


def digest(path):
    # The .meta sha256 is the one of the uncompressed JSON
    h = hashlib.sha256()
    with gzip.open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(name):
    gz = os.path.join(dest, f"nvdcve-2.0-{name}.json.gz")
    meta_path = os.path.join(dest, f"nvdcve-2.0-{name}.meta")
    errors = []
    for src in sources:
        try:
            with get(f"{src}nvdcve-2.0-{name}.meta", 60) as r:
                meta_text = r.read().decode()
            meta = parse_meta(meta_text)
        except Exception as err:
            errors.append(f"{src}: {err}")
            continue
        if (os.path.exists(meta_path) and os.path.exists(gz)
                and parse_meta(open(meta_path).read()) == meta
                and os.path.getsize(gz) == meta["gzSize"]):
            print(f"    {name}: unchanged")
            return True
        part = gz + ".part"
        for attempt in range(8):
            have = os.path.getsize(part) if os.path.exists(part) else 0
            if have > meta["gzSize"]:
                os.remove(part)
                have = 0
            if have == meta["gzSize"]:
                break
            try:
                headers = {"Range": f"bytes={have}-"} if have else None
                with get(f"{src}nvdcve-2.0-{name}.json.gz", 120, headers) as r:
                    with open(part, "ab" if have and r.status == 206 else "wb") as out:
                        while chunk := r.read(1 << 20):
                            out.write(chunk)
            except Exception as err:
                errors.append(f"{src} attempt {attempt + 1}: {err}")
                time.sleep(min(60, 10 * (attempt + 1)))
        if os.path.exists(part) and os.path.getsize(part) == meta["gzSize"] \
                and digest(part) == meta["sha256"]:
            os.replace(part, gz)
            with open(meta_path, "w") as f:
                f.write(meta_text)
            print(f"    {name}: fetched from {src}")
            return True
        if os.path.exists(part):
            os.remove(part)
        errors.append(f"{src}: incomplete or corrupt download")
    if os.path.exists(gz):
        # An older complete copy still scans: report it, do not fail on it
        print(f"    {name}: could not refresh, using the cached copy ({errors[-1]})")
        return True
    print(f"    {name}: FAILED: {'; '.join(errors[-3:])}")
    return False


sys.exit(0 if all([fetch(name) for name in names]) else 1)
NVDPY
    then
      ko "could not fetch the NVD feeds"
      rm -rf "$scan_dir"
      return 1
    fi
    local port
    port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
    python3 -m http.server --bind 127.0.0.1 --directory "$VULNIX_FEEDS_DIR" "$port" \
      >/dev/null 2>&1 &
    feed_server_pid=$!
    VULNIX_MIRROR="http://127.0.0.1:$port/"
    local _
    for _ in $(seq 1 20); do
      python3 -c 'import sys, urllib.request; urllib.request.urlopen(sys.argv[1], timeout=2)' \
        "$VULNIX_MIRROR" >/dev/null 2>&1 && break
      sleep 0.5
    done
  fi

  for image in $CORE_IMAGES; do
    printf '\n%s• %s%s\n' "$BLUE" "$image" "$RESET"
    # A build failure is a real error, distinct from a vulnerability finding.
    if ! (cd core && nix build ".#${image}.image" \
            --option sandbox relaxed --no-warn-dirty \
            --out-link "$scan_dir/$image"); then
      ko "$image: could not build the image"
      blocking=1
      continue
    fi
    # vulnix exits 0 when nothing outside the whitelist is found and 2 when
    # something is. It only exits 1 for whitelisted findings with
    # --show-whitelisted, which is not passed here, so a 1 is a crash -- most
    # often a timeout downloading the NVD feeds -- and so is a 2 without a
    # report. The exit code alone cannot tell "clean" from "never scanned":
    # only a JSON report proves the scan ran. The NVD feeds are slow to answer
    # at times, so retry before giving up.
    #
    # Each attempt is bounded: a feed download that stalls rather than fails
    # used to hold the job until its one-hour timeout, with no attempt left.
    # A `timeout` kill exits 124, which counts as a failed attempt below.
    local -a mirror_args=()
    [ -n "$VULNIX_MIRROR" ] && mirror_args=(--mirror "$VULNIX_MIRROR")
    local attempt
    for attempt in 1 2 3; do
      rc=0
      if [ -n "$whitelist" ]; then
        timeout "$VULNIX_ATTEMPT_TIMEOUT" nix run nixpkgs#vulnix -- \
          "${mirror_args[@]}" --cache-dir "$VULNIX_CACHE_DIR" \
          --closure "$scan_dir/$image" --whitelist "$whitelist" \
          --json > "$scan_dir/$image.json" || rc=$?
      else
        timeout "$VULNIX_ATTEMPT_TIMEOUT" nix run nixpkgs#vulnix -- \
          "${mirror_args[@]}" --cache-dir "$VULNIX_CACHE_DIR" \
          --closure "$scan_dir/$image" --json > "$scan_dir/$image.json" || rc=$?
      fi
      if { [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; } \
          && python3 -c 'import json, sys; assert isinstance(json.load(open(sys.argv[1])), list)' \
               "$scan_dir/$image.json" 2>/dev/null; then
        break
      fi
      printf '%s  vulnix failed (exit %s, attempt %s of 3)%s\n' "$DIM" "$rc" "$attempt" "$RESET"
      rc=-1
      [ "$attempt" -lt 3 ] && sleep 30
    done
    if [ "$rc" -eq -1 ]; then
      ko "$image: could not scan the image, see the vulnix error above"
      blocking=1
      scan_errors=1
      continue
    fi
    if [ "$rc" -eq 0 ]; then ok "$image: nothing outside the whitelist"; continue; fi

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
    # The ids, worst first, so a failure can be triaged from the job log
    # without rerunning vulnix.
    ids = ", ".join(sorted(cves, key=lambda c: -(scores.get(c) or 0)))
    row = (f"{entry['pname']}-{entry['version']}", worst, len(cves), ids)
    (blocking if worst >= threshold else tolerated).append(row)

for level, rows in (("fail", blocking), ("warn", tolerated)):
    for pkg, worst, count, ids in sorted(rows, key=lambda r: -r[1]):
        print(f"{level}|{pkg}|{worst}|{count}|{ids}")
sys.exit(1 if blocking else 0)
PY
    ) || split_rc=$?
    while IFS='|' read -r level pkg worst count ids; do
      [ -z "$level" ] && continue
      msg="$image: $pkg — $count CVE(s), worst CVSS $worst: $ids"
      if [ "$level" = "fail" ]; then ko "$msg"; else warn "$msg"; fi
    done <<< "$verdict"
    if [ "$split_rc" -ne 0 ]; then
      blocking=1
    else
      ok "$image: nothing at or above CVSS $VULNIX_FAIL_SCORE"
    fi
  done
  rm -rf "$scan_dir"
  [ -n "$feed_server_pid" ] && kill "$feed_server_pid" 2>/dev/null

  if [ "$scan_errors" -ne 0 ]; then
    ko "Some container images could not be scanned"
    return 1
  fi
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
