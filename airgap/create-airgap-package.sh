#!/usr/bin/env bash
set -e
# set -x

RYAX_CONFIG=${1:-./ryax-airgap-helm-values.yaml}
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

$SELF_DIR/generate-image-list.sh $1 > /tmp/image-list.txt
$SELF_DIR/create-k3s-tarball.sh /tmp/image-list.txt
$SELF_DIR/create-helm-package.sh

echo -- Arigap packages completed !
