#!/usr/bin/env bash
set -e
# set -x


SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# params
IMAGES_FILE="${1:-$SELF_DIR/images-list.txt}"
ARCH=${2:-"amd64"}
# TODO support private registry
#PRIVATE_REGISTRY_PREFIX="$3"

IMAGES=$(cat $IMAGES_FILE)

set -u

images=""
for image_name in $IMAGES; do
    echo -- Pulling image $image_name
    docker pull --platform="linux/$ARCH" "$image_name"
    #docker tag "$image_name" "$PRIVATE_REGISTRY_PREFIX/$image_name"
    images=" $images $image_name "
done

echo -- Saving to an archive: ryax-airgap-images-$ARCH.tar.gz
docker save $images -o ryax-airgap-images-$ARCH.tar
pigz -v ryax-airgap-images-$ARCH.tar
echo -- Done !
