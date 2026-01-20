#!/usr/bin/env bash
set -e
# set -x

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RYAX_CONFIG=${1:-$SELF_DIR/ryax-airgap-helm-values.yaml}

$SELF_DIR/generate-image-list.sh $RYAX_CONFIG > /tmp/image-list.txt
$SELF_DIR/create-k3s-tarball.sh /tmp/image-list.txt
$SELF_DIR/create-helm-package.sh

echo -- Arigap packages completed !
