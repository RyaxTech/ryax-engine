#!/usr/bin/env bash
#
# Print every container image an airgapped Ryax install needs, one per line.
#
# Derived from `helm template` rather than a hand-maintained list, so a new
# dependency cannot be forgotten -- but only for what the render actually
# contains: a feature that is off by default (the GPU readiness gate, see
# gpuReadiness in the worker chart) contributes nothing unless it is turned on
# in the values file passed here.
set -ue

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$SELF_DIR/.."
RYAX_CONFIG="${1:-$SELF_DIR/ryax-airgap-helm-values.yaml}"

{
  helm template "$ROOT/charts/ryax" \
    --values "$ROOT/charts/ryax/env/minimal.yaml" \
    --values "$RYAX_CONFIG"
  # The worker is a separate chart and is not a dependency of the engine one, so
  # it has to be rendered on its own or none of its images are ever listed.
  helm template "$ROOT/charts/worker-k8s"
# `- image:` as well as `image:`: some pod specs render the container list
# inline, and anchoring on the bare key silently dropped those images.
} | sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*image:[[:space:]]*//p' | tr -d '"' | sort -u
