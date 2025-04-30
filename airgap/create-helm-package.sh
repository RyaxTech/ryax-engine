#!/usr/bin/env bash
set -e
# set -x

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
helm package $SELF_DIR/../chart
echo -- Helm package created !
