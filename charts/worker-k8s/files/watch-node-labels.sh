#!/bin/sh
#
# Publish this node's nvidia.com/mig.config label to a file the readiness probe
# can read.
#
# The probe runs inside the node-problem-detector container, whose image
# carries no HTTP client at all -- no curl, wget, python or openssl -- so it
# cannot ask the API server itself, even though the ServiceAccount it runs
# under already holds the nodes:get that would allow it. This sidecar does the
# asking, with an image that has kubectl, and leaves the answer on a shared
# volume.
#
# Why the probe needs it: nvidia-smi can tell a card that cannot do MIG
# ("[N/A]") from one that can but has it switched off ("Disabled"), and it can
# never tell whether "off" is what the pool asked for. A full-GPU pool runs with
# MIG off for good; a MIG pool looks identical for the minute or two before MIG
# Manager enables it. The intent lives only in this label.

set -u

NODE_NAME="${NODE_NAME:?NODE_NAME is required}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
OUT="${OUT:-/nodeinfo/mig.config}"

echo "publishing nvidia.com/mig.config for $NODE_NAME to $OUT every ${INTERVAL_SECONDS}s"

while true; do
  # An absent label yields an empty string, which is itself the answer: this
  # node was never asked to run MIG. A failed call leaves the previous value
  # in place rather than replacing a known answer with a guess.
  if v=$(kubectl get node "$NODE_NAME" \
           -o jsonpath='{.metadata.labels.nvidia\.com/mig\.config}' 2>&1); then
    # Written through a temporary file: the probe reads this on its own
    # schedule and must never catch a half-written one.
    printf '%s' "$v" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
  else
    echo "cannot read node labels, keeping the last value: $v"
  fi
  sleep "$INTERVAL_SECONDS"
done
