#!/bin/sh
#
# Remove the GPU startup taint from a node once its GPU stack is genuinely
# usable.
#
# A Deployment and not a DaemonSet, on purpose: a DaemonSet would have to
# tolerate the very taint it exists to remove, i.e. pull and start a pod on a
# node the gate has just declared not ready, on the critical path of every
# scale-up. It would also gain nothing -- the MIG check below reads node labels
# through the API, and RBAC cannot be scoped to "this node", so each of its N
# pods would hold the same cluster-wide nodes/patch this one pod holds.
#
# Two conditions must hold before a node is released:
#
#   * node-problem-detector reports the condition True: the driver answers and,
#     where MIG is on, every MIG-enabled card carries at least one instance;
#   * where the administrator asked for a partitioning (the node carries a
#     nvidia.com/mig.config label), the GPU Operator's MIG manager reports
#     nvidia.com/mig.config.state=success. The probe cannot check this: it sees
#     the geometry that exists, not the one that was requested, so a node still
#     carrying a previous geometry looks perfectly ready to it.
#
# Nothing here ever exits. An API error is a transient; a gate that dies leaves
# every GPU node tainted forever.

set -u

TAINT_KEY="${TAINT_KEY:?TAINT_KEY is required}"
CONDITION_TYPE="${CONDITION_TYPE:?CONDITION_TYPE is required}"
NODE_SELECTOR="${NODE_SELECTOR:-}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
REQUIRE_MIG_SUCCESS="${REQUIRE_MIG_SUCCESS:-true}"

# One list per cycle, projected server-side into five whitespace-separated
# columns. `<none>` is what kubectl prints for a column that resolved to
# nothing, so it doubles as the "absent" marker for the condition and the two
# MIG labels. The taint column is the comma-joined list of taint keys.
COLUMNS="NAME:.metadata.name"
COLUMNS="$COLUMNS,TAINTS:.spec.taints[*].key"
COLUMNS="$COLUMNS,GPUREADY:.status.conditions[?(@.type==\"$CONDITION_TYPE\")].status"
COLUMNS="$COLUMNS,MIG:.metadata.labels.nvidia\\.com/mig\\.config"
COLUMNS="$COLUMNS,MIGSTATE:.metadata.labels.nvidia\\.com/mig\\.config\\.state"

selector_arg=""
[ -n "$NODE_SELECTOR" ] && selector_arg="--selector=$NODE_SELECTOR"

echo "watching $TAINT_KEY on nodes matching '${NODE_SELECTOR:-<all>}', every ${INTERVAL_SECONDS}s"

while true; do
  # shellcheck disable=SC2086  # unquoted on purpose: empty means "no flag"
  if ! nodes=$(kubectl get nodes $selector_arg --no-headers -o "custom-columns=$COLUMNS" 2>&1); then
    echo "cannot list nodes, retrying: $nodes"
    sleep "$INTERVAL_SECONDS"
    continue
  fi

  echo "$nodes" | while read -r name taints ready mig migstate; do
    [ -n "${name:-}" ] || continue

    # The steady state: never tainted, or already released. Reading the taint
    # here instead of firing an unconditional `kubectl taint` is what keeps
    # this loop at zero API writes once the cluster has settled.
    case ",${taints}," in
      *",${TAINT_KEY},"*) ;;
      *) continue ;;
    esac

    # "<none>" while node-problem-detector has not reported yet, "Unknown" when
    # the probe timed out. Neither releases the node: this fails closed.
    [ "$ready" = "True" ] || continue

    if [ "$REQUIRE_MIG_SUCCESS" = "true" ] && [ "$mig" != "<none>" ] && [ "$migstate" != "success" ]; then
      echo "$name: GPU ready, MIG config '$mig' is '$migstate', waiting"
      continue
    fi

    if kubectl taint nodes "$name" "${TAINT_KEY}-" >/dev/null 2>&1; then
      echo "$name: released (mig.config=$mig state=$migstate)"
    else
      # Lost a race with another actor, or the API refused the patch. The next
      # cycle sees the taint either gone or still there and does the right thing.
      echo "$name: could not remove the taint, retrying next cycle"
    fi
  done

  sleep "$INTERVAL_SECONDS"
done
