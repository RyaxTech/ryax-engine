#!/usr/bin/env bash
#
# Ryax Helm chart GitOps checks.
#
#   charts/gitops-checks.sh              run every check
#   charts/gitops-checks.sh determinism  run a subset, in the given order
#   charts/gitops-checks.sh --list       list the available checks
#
# These guard the properties that make the chart installable by a GitOps engine
# (ArgoCD, Flux) rather than only by `helm install`. Such an engine renders the
# chart with `helm template` -- no cluster connection, so `lookup()` returns
# nothing -- and has no install/upgrade distinction, so it runs every `pre-*`
# hook on every sync, including the very first one. Both properties are easy to
# break by accident and impossible to notice with `helm lint`.
#
# Every selected check runs even when an earlier one fails, so one broken check
# never hides the result of another; the exit status is non-zero if any failed.
set -u

CHART="${CHART:-charts/ryax}"

# ---------------------------------------------------------------------------
# Colors (auto-disabled when stdout is not a TTY or when NO_COLOR is set)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; CYAN=$'\e[36m'
  RESET=$'\e[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; CYAN=''; RESET=''
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

section() { printf '\n%s%s━━━ %s ━━━%s\n' "$BOLD" "$CYAN" "$1" "$RESET"; }
ok()      { printf '%s  ✔ %s%s\n'          "$GREEN" "$1" "$RESET"; }
ko()      { printf '%s  ✘ %s%s\n'          "$RED"   "$1" "$RESET"; }
info()    { printf '%s  · %s%s\n'          "$DIM"   "$1" "$RESET"; }

CHECKS="determinism secret-scope hook-guards hook-priority placement ingress-switch"

describe_check() {
  case "$1" in
    determinism)    echo "the chart renders identically twice with secret generation off" ;;
    secret-scope)   echo "with generation on, only Secret data churns between renders" ;;
    hook-guards)    echo "every pre-* hook pod can start, and skips itself, on a first sync" ;;
    hook-priority)  echo "no hook pod depends on a PriorityClass applied after its phase" ;;
    placement)      echo "every Ryax pod spec renders global.tolerations" ;;
    ingress-switch) echo "ingress.enabled=false renders no Ingress and no Traefik Middleware" ;;
    *)              echo "?" ;;
  esac
}

render() { helm template ryax "$CHART" "$@"; }

# ---------------------------------------------------------------------------
# determinism -- the reason a GitOps engine would otherwise rotate credentials
# out from under running pods on every reconcile.
# ---------------------------------------------------------------------------
check_determinism() {
  section "Rendering twice with global.secrets.create=false"
  local a b
  a="$(mktemp)"; b="$(mktemp)"
  render --set global.secrets.create=false > "$a" || { ko "render failed"; return 1; }
  render --set global.secrets.create=false > "$b" || { ko "render failed"; return 1; }
  if ! diff -u "$a" "$b" > /dev/null; then
    ko "the chart does not render deterministically:"
    diff -u "$a" "$b" | head -40
    rm -f "$a" "$b"
    return 1
  fi
  info "$(wc -l < "$a" | tr -d ' ') lines, byte-identical"
  rm -f "$a" "$b"
  ok "Deterministic with operator-supplied secrets"
}

# ---------------------------------------------------------------------------
# secret-scope -- with the chart generating its own credentials, `lookup()`
# still churns; that is expected, but it must not leak outside Secret objects.
# ---------------------------------------------------------------------------
check_secret_scope() {
  section "Checking that render churn stays inside Secrets"
  render > "$WORKDIR/gitops-a.yaml" 2>/dev/null || { ko "render failed"; return 1; }
  render > "$WORKDIR/gitops-b.yaml" 2>/dev/null || { ko "render failed"; return 1; }
  python3 - "$WORKDIR/gitops-a.yaml" "$WORKDIR/gitops-b.yaml" <<'PY'
import difflib, sys

a = open(sys.argv[1]).read().split("\n")
b = open(sys.argv[2]).read().split("\n")

# tag every line with the kind of the document it belongs to
kinds, kind = [], "?"
for line in a:
    if line.startswith("---"):
        kind = "?"
    elif line.startswith("kind:"):
        kind = line.split(":", 1)[1].strip().strip('"')
    kinds.append(kind)

offenders = {}
for tag, i1, i2, _, _ in difflib.SequenceMatcher(None, a, b).get_opcodes():
    if tag == "equal":
        continue
    for i in range(i1, min(i2, len(kinds))):
        if kinds[i] != "Secret":
            offenders.setdefault(kinds[i], []).append(a[i].strip()[:70])

if offenders:
    for kind, lines in offenders.items():
        print(f"  {kind}: {len(lines)} churning line(s), e.g. {lines[0]!r}")
    sys.exit(1)
PY
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    ko "Something outside a Secret changes between two identical renders"
    return 1
  fi
  ok "Only Secret data churns, which the create flags turn off"
}

# ---------------------------------------------------------------------------
# hook-guards -- a `pre-*` hook runs in the first PreSync, before any Sync-phase
# resource exists. Its pod must therefore be able to start (every secretKeyRef
# `optional`, or it wedges in CreateContainerConfigError and the phase never
# ends) and must recognise that there is nothing to do yet.
# ---------------------------------------------------------------------------
check_hook_guards() {
  section "Checking the pre-sync hook pods"
  render > "$WORKDIR/gitops-hooks.yaml" 2>/dev/null || { ko "render failed"; return 1; }
  python3 - "$WORKDIR/gitops-hooks.yaml" <<'PY'
import sys, yaml

MARKER_ENV = "RYAX_RELEASE_INSTALLED"
# Ryax-owned subcharts. Upstream dependencies ship hooks of their own
# (kube-prometheus-stack's CRD upgrade and admission certgen jobs); they are
# self-contained, not ours to guard, and reported rather than silently skipped.
OURS = ("action-builder", "authorization", "common-resources", "datastore", "front",
        "intelliscale", "registry", "repository", "runner", "studio",
        "worker-k8s", "worker-ssh-slurm", "ryax-engine")
problems, checked, upstream = [], 0, []

for doc in yaml.safe_load_all(open(sys.argv[1])):
    if not doc or doc.get("kind") != "Job":
        continue
    hook = (doc["metadata"].get("annotations") or {}).get("helm.sh/hook", "")
    if "pre-" not in hook:
        continue
    name = doc["metadata"]["name"]
    chart = (doc["metadata"].get("labels") or {}).get("helm.sh/chart", "")
    if not any(chart.startswith(o + "-") for o in OURS):
        upstream.append(f"{name} ({chart or 'no helm.sh/chart label'})")
        continue
    checked += 1
    spec = doc["spec"]["template"]["spec"]
    for c in spec.get("initContainers", []) + spec["containers"]:
        where = f"{name}/{c['name']}"
        env = {e["name"]: e for e in c.get("env") or []}
        if MARKER_ENV not in env:
            problems.append(f"{where}: no {MARKER_ENV}, so it cannot tell a first sync from an upgrade")
        else:
            ref = (env[MARKER_ENV].get("valueFrom") or {}).get("configMapKeyRef") or {}
            if not ref.get("optional"):
                problems.append(f"{where}: {MARKER_ENV} is not optional, the pod cannot start without the marker")
        for e in c.get("env") or []:
            ref = (e.get("valueFrom") or {}).get("secretKeyRef")
            if ref and not ref.get("optional"):
                problems.append(f"{where}: env {e['name']} needs a Secret that does not exist on a first sync"
                                f" (add `optional: true`)")
        script = " ".join((c.get("command") or []) + (c.get("args") or []))
        if MARKER_ENV not in script:
            problems.append(f"{where}: the command never reads {MARKER_ENV}, so the guard cannot fire")

print(f"  {checked} Ryax hook Job(s) inspected")
for u in upstream:
    print(f"  upstream hook, not guarded by this chart: {u}")
for p in problems:
    print(f"  {p}")
sys.exit(1 if problems else 0)
PY
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    ko "A pre-sync hook would block the first sync"
    return 1
  fi
  ok "Every pre-sync hook can start and skips itself on a first sync"
}

# ---------------------------------------------------------------------------
# hook-priority -- PriorityClasses are Sync-phase resources, so they do not
# exist while the first PreSync runs. A hook pod naming one is rejected at
# admission and its Job retries forever, which no in-container guard can fix.
# ---------------------------------------------------------------------------
check_hook_priority() {
  section "Checking that no hook pod requires a PriorityClass"
  render > "$WORKDIR/gitops-prio.yaml" 2>/dev/null || { ko "render failed"; return 1; }
  python3 - "$WORKDIR/gitops-prio.yaml" <<'PY'
import sys, yaml

problems = []
for doc in yaml.safe_load_all(open(sys.argv[1])):
    if not doc:
        continue
    ann = doc["metadata"].get("annotations") or {}
    if doc.get("kind") == "PriorityClass" and "helm.sh/hook" in ann:
        problems.append(f"PriorityClass/{doc['metadata']['name']} is a hook: Helm stops tracking it "
                        f"and deletes/recreates it on every upgrade")
    if doc.get("kind") != "Job" or "helm.sh/hook" not in ann:
        continue
    pc = doc["spec"]["template"]["spec"].get("priorityClassName")
    if pc:
        problems.append(f"Job/{doc['metadata']['name']} is a {ann['helm.sh/hook']} hook and asks for "
                        f"priorityClassName {pc!r}, which does not exist yet on a first sync")
for p in problems:
    print(f"  {p}")
sys.exit(1 if problems else 0)
PY
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    ko "A hook pod would be rejected at admission on a first sync"
    return 1
  fi
  ok "No hook depends on a PriorityClass, and none of them is a hook itself"
}

# ---------------------------------------------------------------------------
# placement -- the failure this replaces was a hand-maintained list of workload
# names patched after the fact, which silently missed whatever the chart added
# or renamed. Counting rendered pod specs is what makes that impossible.
# ---------------------------------------------------------------------------
check_placement() {
  section "Checking that every Ryax pod accepts global.tolerations"
  render --set 'global.tolerations[0].key=gitops.ryax.tech/probe' \
         --set 'global.tolerations[0].operator=Exists' \
         --set 'global.tolerations[0].effect=NoSchedule' \
         > "$WORKDIR/gitops-place.yaml" 2>/dev/null || { ko "render failed"; return 1; }
  python3 - "$WORKDIR/gitops-place.yaml" <<'PY'
import sys, yaml

PROBE = "gitops.ryax.tech/probe"
# the Ryax-owned subcharts; anything else is an upstream dependency whose
# placement lives in its own values, and is reported rather than silently skipped
OURS = ("action-builder", "authorization", "common-resources", "datastore", "front",
        "intelliscale", "registry", "repository", "runner", "studio",
        "worker-k8s", "worker-ssh-slurm", "ryax-engine")
POD_PARENT = {
    "Deployment":  lambda d: [d["spec"]["template"]],
    "StatefulSet": lambda d: [d["spec"]["template"]],
    "DaemonSet":   lambda d: [d["spec"]["template"]],
    "Job":         lambda d: [d["spec"]["template"]],
    "CronJob":     lambda d: [d["spec"]["jobTemplate"]["spec"]["template"]],
}

ours = third_party = 0
missing, blanket = [], []
for doc in yaml.safe_load_all(open(sys.argv[1])):
    if not doc or doc.get("kind") not in POD_PARENT:
        continue
    chart = (doc["metadata"].get("labels") or {}).get("helm.sh/chart", "")
    name = f"{doc['kind']}/{doc['metadata']['name']}"
    if not any(chart.startswith(o + "-") for o in OURS):
        third_party += 1
        continue
    ours += 1
    for tmpl in POD_PARENT[doc["kind"]](doc):
        tols = tmpl["spec"].get("tolerations") or []
        if any(t.get("operator") == "Exists" and not t.get("key") for t in tols):
            blanket.append(name)          # already tolerates every taint
        elif PROBE not in [t.get("key") for t in tols]:
            missing.append(name)

print(f"  {ours} Ryax pod spec(s), {third_party} from upstream subcharts "
      f"(their placement lives in their own values, see the ArgoCD how-to)")
for b in blanket:
    print(f"  tolerates every taint already, nothing to inject: {b}")
for m in missing:
    print(f"  NO TOLERATIONS: {m}")
sys.exit(1 if missing else 0)
PY
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    ko "A Ryax pod would stay Pending on a tainted node"
    return 1
  fi
  ok "Every Ryax pod spec renders global.tolerations"
}

# ---------------------------------------------------------------------------
# ingress-switch -- with no Ingress controller nothing fills in
# .status.loadBalancer, and ArgoCD's built-in Ingress health check reports
# Progressing forever, which parks the operation and starves every later sync.
# ---------------------------------------------------------------------------
check_ingress_switch() {
  section "Checking that the Ingresses can be turned off"
  local args=()
  local sub
  for sub in front authorization runner studio repository registry; do
    args+=(--set "${sub}.ingress.enabled=false")
  done
  local out
  out="$(render "${args[@]}" 2>/dev/null)" || { ko "render failed"; return 1; }
  local left
  left="$(printf '%s\n' "$out" | grep -cE '^kind: "?(Ingress|Middleware)"?$')"
  if [ "$left" -ne 0 ]; then
    ko "$left Ingress/Middleware object(s) still rendered with every ingress.enabled=false:"
    printf '%s\n' "$out" | grep -B4 -E '^kind: "?(Ingress|Middleware)"?$' | grep "name:" | head
    return 1
  fi
  ok "No Ingress and no Traefik Middleware left"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
usage() {
  printf 'Usage: %s [CHECK...]\n\nWith no argument every check runs.\n\nChecks:\n' "$0"
  local name
  for name in $CHECKS; do
    printf '  %-15s %s\n' "$name" "$(describe_check "$name")"
  done
}

for tool in helm python3; do
  command -v "$tool" >/dev/null 2>&1 || { ko "$tool is not on PATH"; exit 1; }
done
[ -d "$CHART" ] || { ko "no chart at $CHART (run from the repository root, or set CHART)"; exit 1; }

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

# The local subcharts are vendored as archives, so a stale .tgz would hide the
# very change being checked. This has to succeed: a render that cannot run is a
# check that did not run, and that must not read as a pass.
#
# `helm dependency build` is deliberate over `helm dependency update`: it honours
# Chart.lock instead of re-resolving, so these checks run against the pinned
# upstream versions and a run never leaves a modified Chart.lock behind. The
# price is that it refuses to resolve an https:// dependency whose repository is
# not registered -- the normal state of a CI runner -- so register them first,
# from the chart's own dependency list, in a throwaway config that leaves the
# caller's `helm repo list` alone.
ensure_dependencies() {
  local log="$WORKDIR/dep.log"
  if helm dependency build "$CHART" >"$log" 2>&1; then
    return 0
  fi
  info "registering the chart's Helm repositories"
  export HELM_REPOSITORY_CONFIG="$WORKDIR/repositories.yaml"
  export HELM_REPOSITORY_CACHE="$WORKDIR/repository-cache"
  local url i=0
  while read -r url; do
    [ -n "$url" ] || continue
    i=$((i + 1))
    if ! helm repo add "dep$i" "$url" >>"$log" 2>&1; then
      ko "could not add the Helm repository $url"
      cat "$log"
      return 1
    fi
  done < <(chart_http_repositories)
  if ! helm dependency build "$CHART" >>"$log" 2>&1; then
    ko "helm dependency build failed:"
    cat "$log"
    return 1
  fi
}

# The http(s) dependency repositories of the chart. oci:// and file:// ones need
# no registering.
chart_http_repositories() {
  python3 -c '
import sys, yaml

chart = yaml.safe_load(open(sys.argv[1]))
seen = []
for dep in chart.get("dependencies") or []:
    url = dep.get("repository", "")
    if url.startswith(("http://", "https://")) and url not in seen:
        seen.append(url)
print("\n".join(seen))
' "$CHART/Chart.yaml"
}

ensure_dependencies || exit 1

failed=""
for name in $selected; do
  if ! "check_${name//-/_}"; then
    failed="$failed $name"
  fi
done

if [ -n "$failed" ]; then
  printf '\n%s ✘ Failed:%s %s\n' "$BOLD$RED" "$RESET" "${failed# }"
  exit 1
fi
printf '\n%s ✔ All GitOps checks passed %s\n' "$BOLD$GREEN" "$RESET"
