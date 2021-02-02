#!/usr/bin/env bash

set -e
# set -x

VERSION=${1:-"latest"}
FROM_VERSION=${2:-"staging"}

# ryaxpkgs is here for api proxy image (TODO move it to ./api)
SERVICES="./webui ./repository ./api ./core ./adm ./cli ./studio ./effects/orchestrator ./ryaxpkgs"

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

for service in $SERVICES
do
    echo === Entering $service
    cd $service
    git checkout master
    git pull
    git checkout "$FROM_VERSION"
    if [[ $(git tag --points-at HEAD | grep $VERSION) == $VERSION ]]
    then
        echo == Version $VERSION already on the reference $FROM_VERSION for $service
    else
        echo == Updating the $VERSION to the head of master
        git tag --delete "$VERSION" || true
        git push --delete origin "$VERSION" || true
        git tag "$VERSION" && git push origin "$VERSION"
    fi
    cd $CURRENT_DIR
done
