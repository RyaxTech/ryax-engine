#!/usr/bin/env bash
#
# Move the vendored RabbitMQ Cluster Operator to another upstream release:
# replace crds/ with the CRD of that release and bump operator.image.
#
#   ./update-operator.sh 2.24.0
#
# It does not touch templates/operator.yaml: diff the Deployment and the
# ClusterRole of the downloaded manifest against it by hand. The image is also
# asserted in tests/operator_test.yaml, which then fails until you bump it.
set -euo pipefail

V="${1:?usage: $0 <operator version, e.g. 2.23.0>}"
V="${V#v}"
cd "$(dirname "$0")"

MANIFEST="$(mktemp)"
trap 'rm -f "$MANIFEST"' EXIT
URL="https://github.com/rabbitmq/cluster-operator/releases/download/v$V/cluster-operator.yml"
curl -fsSL -o "$MANIFEST" "$URL"

python3 - "$MANIFEST" "$V" "$URL" <<'PY'
import re, sys

manifest, version, url = sys.argv[1:4]
docs = open(manifest).read().split("\n---\n")
crds = [d for d in docs if re.search(r"^kind: CustomResourceDefinition$", d, re.M)]
if len(crds) != 1:
    sys.exit(f"expected one CRD in the manifest, found {len(crds)}")
with open("crds/rabbitmqclusters.rabbitmq.com.yaml", "w") as f:
    f.write(f"# Vendored verbatim from the RabbitMQ Cluster Operator v{version} release manifest:\n"
            f"# {url}\n"
            "# Keep in step with operator.image in values.yaml; Chart.yaml says how to refresh it.\n")
    f.write(crds[0].strip("\n") + "\n")

images = sorted(set(re.findall(r"^\s*image:\s*(\S+cluster-operator:\S+)", open(manifest).read(), re.M)))
values = open("values.yaml").read()
new = re.sub(r"(?m)^(  image: ).*cluster-operator:.*$", r"\g<1>ghcr.io/rabbitmq/cluster-operator:" + version, values)
if new == values and f"cluster-operator:{version}" not in values:
    sys.exit("operator.image not found in values.yaml")
open("values.yaml", "w").write(new)
print(f"CRD and operator.image now at {version}; upstream manifest uses {images}")
PY
