#!/usr/bin/env bash
set -e
# set -x

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$SELF_DIR/.."

# Both charts: an engine with no worker registered accepts a deployment and then
# hangs in "Deploying" forever, so the worker is part of the install rather than
# an optional extra.
helm package "$ROOT/charts/ryax"
helm package "$ROOT/charts/worker-k8s"
echo -- Helm packages created !
