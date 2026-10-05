#!/usr/bin/env bash
#
# Run the helm-unittest suites of every chart that has a tests/ directory.
#
#   HELM_PLUGINS=$(nix build --no-link --print-out-paths nixpkgs#kubernetes-helmPlugins.helm-unittest) \
#     nix shell nixpkgs#kubernetes-helm --command charts/unit-tests.sh
#
# `helm lint` and gitops-checks.sh check that the charts render, not what they
# render: roadmap#1448 pinned every Ingress to the TLS hostname and passed both.
# These suites assert on the rendered resources (roadmap#1472).
#
# A chart gets covered by adding a tests/ directory to it; list `tests/` in its
# .helmignore too, or the suites ship in the packaged chart.
#
# A suite that several charts must pass, because their templates share the
# logic, lives once in charts/shared-tests/ and is symlinked into each chart's
# tests/. helm-unittest follows the link and reports the result per chart.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mapfile -t CHARTS < <(find charts -type d -name tests -not -path '*/templates/*' -printf '%h\n' | sort)
if [ "${#CHARTS[@]}" -eq 0 ]; then
  echo "No chart has a tests/ directory." >&2
  exit 1
fi

helm unittest "${CHARTS[@]}"
