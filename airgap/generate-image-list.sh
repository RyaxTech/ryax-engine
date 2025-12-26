#!/usr/bin/env bash

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
helm template $SELF_DIR/../chart --values $SELF_DIR/ryax-airgap-helm-values.yaml | tee /tmp/tmpl.yaml \
  >  >(grep 'image: ' | sed 's/.*image: //' | sed 's/\"\(.*\)\"/\1/' | sort | uniq)
  2> >(grep 'repo')
