#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
Build the public Ryax API reference from the service sources.

    docs/api-spec.py                    regenerate docs/docs/reference/ryax-spec.json
    docs/api-spec.py --version 26.8.0   ... stamping that version into the document
    docs/api-spec.py --check            fail if the committed document is behind

The four public APIs are FastAPI applications spread over three submodules. Each
one builds its app in an `init()` factory that wants a dozen environment
variables, but the route table is installed by a separate `setup(app, container)`
that wants nothing: a bare `ApplicationContainer()` resolves without reaching a
database or a broker, because every connection is opened in the app's lifespan.
That is what makes an offline dump possible -- no running cluster, no
`$API_SERVER` -- and it is how the API tests build their apps too, see
`repository/tests/infrastructure/api/test_dependencies.py`.

One subprocess per service, run from the submodule root. The submodules pin
different FastAPI versions under the same `ryax` namespace package, so they
cannot share an interpreter, and `python -c` puts the working directory on
`sys.path`, which is what makes `ryax.<service>` importable: the submodule
virtualenvs do not install it.

Stdlib only, on purpose: CI needs no `uv sync` of this project to run --check.
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Tuple

ROOT = Path(__file__).resolve().parent.parent
SPEC_FILE = ROOT / "docs" / "docs" / "reference" / "ryax-spec.json"
# The version jef.py charts_update writes, so a release needs no second argument.
CHART_FILE = ROOT / "charts" / "ryax" / "Chart.yaml"

# The document every service must produce. Merging documents of two different
# OpenAPI versions is not something this script tries to do.
OPENAPI_VERSION = "3.1"

# Component names are namespaced per service to keep them apart. Security
# schemes are not: all four services declare the same Ryax bearer token, they
# are collapsed into a single scheme, and a security requirement names a scheme
# directly instead of going through a $ref, so nothing has to be rewritten.
SHARED_SECTIONS = ("securitySchemes",)


@dataclass(frozen=True)
class Service:
    """One public API: where its code lives and where its routes are served."""

    name: str
    # Directory holding the `ryax` package. authorization and runner both live
    # in core: the authorization service was absorbed into it (core a4c84458).
    submodule: str
    # Import path of the service package: `<package>.container` holds the
    # ApplicationContainer and `<package>.infrastructure.api.setup` the routes.
    package: str
    # The path its routes answer on from outside, as routed by the ingress
    # (charts/ryax/subcharts/*/templates/ingresses.yaml) and as called by the
    # front (front/proxy-staging.conf.js). An offline dump carries no prefix of
    # its own: FastAPI only injects root_path into servers[] when it serves the
    # live /openapi.json route, so the merge has to add these.
    prefix: str

    @property
    def label(self) -> str:
        """Name as it appears in the document, prefixing components and tags."""
        return self.name.capitalize()


SERVICES = (
    Service("authorization", "core", "ryax.authorization", "/api/authorization"),
    Service("repository", "repository", "ryax.repository", "/api/repository"),
    Service("studio", "studio", "ryax.studio", "/api/studio"),
    # The runner's own root_path is /runner, not /api/runner
    # (charts/ryax/subcharts/runner/values.yaml), but both ingress paths exist
    # and /api/runner is the one the UI calls.
    Service("runner", "core", "ryax.runner", "/api/runner"),
)

# Written to a file given in argv rather than to stdout: the services log while
# they import -- the runner emits an OpenTelemetry "already instrumented"
# warning -- and that must not end up in the JSON.
DUMP = """
import importlib, json, sys
from fastapi import FastAPI

package, out = sys.argv[1], sys.argv[2]
container = importlib.import_module(package + ".container").ApplicationContainer()
app = FastAPI(title=package)
importlib.import_module(package + ".infrastructure.api.setup").setup(app, container)
with open(out, "w") as fd:
    json.dump(app.openapi(), fd)
"""

INFO_DESCRIPTION = """\
The HTTP API of a Ryax installation: the API the Ryax web interface and the
`ryaxctl` command line use. It merges the four services that make up the public
surface, each under its own path prefix:

- `/api/authorization` -- users, projects and access tokens
- `/api/repository` -- git sources and the actions built from them
- `/api/studio` -- workflow authoring
- `/api/runner` -- deployments, runs and sites

Authenticate with the token of a Ryax user in an `Authorization: Bearer` header.
"""


class SpecError(Exception):
    """A merge the script refuses to guess its way through."""


def _dump_service(service: Service, out_dir: Path) -> Dict[str, Any]:
    """Import the service offline and return its OpenAPI document."""
    out_file = out_dir / f"{service.name}.json"
    print(f"  · {service.name}: dumping from {service.submodule}/")
    subprocess.run(
        ["uv", "run", "--frozen", "python", "-c", DUMP, service.package, str(out_file)],
        cwd=ROOT / service.submodule,
        check=True,
    )
    spec = json.loads(out_file.read_text())
    version = str(spec.get("openapi", ""))
    if not version.startswith(OPENAPI_VERSION):
        raise SpecError(
            f"{service.name} produced OpenAPI {version or '?'}, "
            f"expected {OPENAPI_VERSION}.x"
        )
    return spec


def _prefix_ref(ref: str, prefix: str) -> str:
    """Namespace a local component reference: #/components/<section>/<Name>."""
    parts = ref.split("/")
    if len(parts) != 4 or parts[0] != "#" or parts[1] != "components":
        raise SpecError(
            f"cannot namespace $ref {ref!r}: only local component references "
            "are handled"
        )
    if parts[2] in SHARED_SECTIONS:
        return ref
    parts[3] = prefix + parts[3]
    return "/".join(parts)


def _rewrite_refs(node: Any, prefix: str) -> None:
    """Namespace every local reference in a document, in place."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "$ref" and isinstance(value, str):
                node[key] = _prefix_ref(value, prefix)
            else:
                _rewrite_refs(value, prefix)
    elif isinstance(node, list):
        for item in node:
            _rewrite_refs(item, prefix)


def _namespace(spec: Dict[str, Any], service: Service) -> None:
    """Make one service's document mergeable with the others', in place.

    Every service builds on the same FastAPI and the same shared helpers, so
    without this the documents collide: all four declare `HTTPValidationError`,
    `ValidationError` and a `/healthz` tagged `Monitoring`
    (core/ryax/common/api/health.py), three declare `ErrorModel`, and both the
    studio and the runner declare `/workflows` and a `Workflows` tag.
    """
    _rewrite_refs(spec, service.label)

    components = spec.get("components", {})
    for section, entries in components.items():
        if section in SHARED_SECTIONS:
            continue
        components[section] = {
            service.label + name: entry for name, entry in entries.items()
        }

    for path, item in list(spec["paths"].items()):
        for operation in item.values():
            if not isinstance(operation, dict):
                continue
            if "operationId" in operation:
                operation["operationId"] = f"{service.name}_{operation['operationId']}"
            if "tags" in operation:
                operation["tags"] = [
                    f"{service.label} / {tag}" for tag in operation["tags"]
                ]
        spec["paths"][service.prefix + path] = spec["paths"].pop(path)


def _merge_section(
    target: Dict[str, Any], source: Dict[str, Any], what: str, service: Service
) -> None:
    """Fold one service's entries into the merged document."""
    for key, value in source.items():
        if key in target and target[key] != value:
            raise SpecError(
                f"{service.name} redefines {what} {key!r} with a different value"
            )
        target[key] = value


def build_spec(version: str) -> Dict[str, Any]:
    """Dump every service and merge the result into one OpenAPI document."""
    paths: Dict[str, Any] = {}
    components: Dict[str, Dict[str, Any]] = {}
    # Swagger UI orders its groups by the top-level tag list when there is one,
    # so build it in service order, keeping each service's own tag order.
    tags: List[str] = []

    with tempfile.TemporaryDirectory() as tmp:
        specs: List[Tuple[Service, Dict[str, Any]]] = [
            (service, _dump_service(service, Path(tmp))) for service in SERVICES
        ]

    for service, spec in specs:
        _namespace(spec, service)
        _merge_section(paths, spec["paths"], "path", service)
        for section, entries in spec.get("components", {}).items():
            _merge_section(
                components.setdefault(section, {}), entries, section, service
            )
        for item in spec["paths"].values():
            for operation in item.values():
                if not isinstance(operation, dict):
                    continue
                for tag in operation.get("tags", []):
                    if tag not in tags:
                        tags.append(tag)

    return {
        "openapi": f"{OPENAPI_VERSION}.0",
        "info": {
            "title": "Ryax API",
            "version": version,
            "description": INFO_DESCRIPTION,
        },
        # Templated rather than hardcoded to one host, so that "Try it out"
        # targets the reader's own installation.
        "servers": [
            {
                "url": "https://{instance}",
                "description": "A Ryax installation",
                "variables": {"instance": {"default": "app.ryax.io"}},
            }
        ],
        "tags": [{"name": tag} for tag in tags],
        # Sorted so that a re-registered route or a renamed handler cannot churn
        # the diff: nothing downstream depends on the order.
        "paths": dict(sorted(paths.items())),
        "components": {
            section: dict(sorted(entries.items()))
            for section, entries in sorted(components.items())
        },
    }


def _serialize(spec: Dict[str, Any]) -> str:
    return json.dumps(spec, indent=2) + "\n"


def _chart_version() -> str:
    """The release version, from the chart jef.py charts_update writes."""
    match = re.search(
        r'^version:\s*"?([^"\s]+)"?', CHART_FILE.read_text(), re.MULTILINE
    )
    if match is None:
        raise SpecError(f"no version found in {CHART_FILE}")
    return match.group(1)


def _report_paths(committed: Dict[str, Any], current: Dict[str, Any]) -> bool:
    """List the paths that appeared and disappeared; say whether any did."""
    was, now = set(committed.get("paths", {})), set(current["paths"])
    for path in sorted(now - was):
        print(f"      + {path}")
    for path in sorted(was - now):
        print(f"      - {path}")
    return was != now


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "-v",
        "--version",
        help="API version to stamp into the document "
        f"(default: the version in {CHART_FILE.relative_to(ROOT)})",
    )
    parser.add_argument(
        "-c",
        "--check",
        action="store_true",
        help="do not write; exit 1 if the committed document is behind the sources",
    )
    args = parser.parse_args()

    committed: Dict[str, Any] = {}
    if SPEC_FILE.exists():
        committed = json.loads(SPEC_FILE.read_text())

    if args.check:
        # Compare against the version already committed: the release stamps a new
        # one, and that alone is not drift.
        version = str(committed.get("info", {}).get("version", ""))
    else:
        version = args.version or _chart_version()

    print(f"Building the Ryax {version or '(unversioned)'} API document")
    try:
        spec = build_spec(version)
    except (SpecError, subprocess.CalledProcessError) as error:
        print(f"  ✘ {error}", file=sys.stderr)
        return 1

    if args.check:
        if committed and _serialize(spec) == SPEC_FILE.read_text():
            print(f"  ✔ {SPEC_FILE.relative_to(ROOT)} matches the service sources")
            return 0
        if not committed:
            print(f"  ✘ {SPEC_FILE.relative_to(ROOT)} is missing")
        else:
            print(f"  ✘ {SPEC_FILE.relative_to(ROOT)} is behind the service sources:")
            if not _report_paths(committed, spec):
                print("      no path moved: an operation or a schema changed")
        print("\n  run './jef.py update_api' and commit the result")
        return 1

    SPEC_FILE.write_text(_serialize(spec))
    print(
        f"  ✔ {SPEC_FILE.relative_to(ROOT)}: "
        f"{len(spec['paths'])} paths, "
        f"{len(spec['components'].get('schemas', {}))} schemas"
    )
    if committed:
        _report_paths(committed, spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
