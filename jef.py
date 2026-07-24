#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
Jef, a tool to help you release and maintain Ryax.
"""

import glob
import json
import os
import re
import subprocess
import sys
import time
import shutil
from typing import Any, Dict, List, Optional
import argparse

import yaml
from git import Repo, BadName


class TCOLOR:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"
    ENDC = "\033[0m"


REPOS_TO_BE_RELEASED = {
    "intelliscale": {"gitlab_project": "ryax-tech/ryax/ryax-intelliscale"},
    "authorization": {
        "gitlab_project": "ryax-tech/ryax/ryax-authorization",
    },
    "default-actions": {
        "gitlab_project": "ryax-tech/workflows/default-actions",
        "path": "./actions/",
    },
    "action-wrappers": {
        "gitlab_project": "ryax-tech/ryax/ryax-action-wrappers",
    },
    "repository": {
        "gitlab_project": "ryax-tech/ryax/ryax-repository",
    },
    "studio": {
        "gitlab_project": "ryax-tech/ryax/ryax-studio",
    },
    "runner": {
        "gitlab_project": "ryax-tech/ryax/ryax-runner",
    },
    "front": {
        "gitlab_project": "ryax-tech/ryax/ryax-front",
    },
}

MAIN_RELEASE_REPO = {
    "gitlab_project": "ryax-tech/ryax/ryax-engine",
}

MAX_REPO_NAME_LEN = max([len(r) for r in REPOS_TO_BE_RELEASED.keys()])

# Upstream changelog / upgrade-instructions for each external Helm dependency.
# Shown by check_helm_deps next to any dependency that is behind (or being
# bumped) so the maintainer can quickly read the upgrade notes before applying.
HELM_DEP_CHANGELOGS = {
    "traefik": "https://github.com/traefik/traefik-helm-chart/blob/master/traefik/Changelog.md",
    "kube-prometheus-stack": "https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/UPGRADE.md",
    "minio": "https://github.com/bitnami/charts/tree/main/bitnami/minio#upgrading",
    "rabbitmq": "https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#upgrading",
    "postgresql": "https://github.com/bitnami/charts/tree/main/bitnami/postgresql#upgrading",
    "tempo": "https://github.com/grafana/helm-charts/tree/main/charts/tempo",
    "loki": "https://github.com/grafana/loki/blob/main/production/helm/loki/CHANGELOG.md",
    "alloy": "https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/CHANGELOG.md",
}


def _print_changelog_link(name: str, indent: str = "      ") -> None:
    """Print the upstream changelog/upgrade doc link for a dependency, if known."""
    link = HELM_DEP_CHANGELOGS.get(name)
    if link:
        print(f"{indent}{TCOLOR.UNDERLINE}changelog:{TCOLOR.ENDC} {link}")


class Version:
    """
    We do semver, but some old versions have leading "0" which is forbidden
    with semver.
    """

    _REGEX = re.compile(
        r"""
            ^
            (?P<major>\d*)
            \.
            (?P<minor>\d*)
            \.
            (?P<patch>\d*)
            (?:-(?P<prerelease>
                (?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)
                (?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*
            ))?
            (?:\+(?P<build>
                [0-9a-zA-Z-]+
                (?:\.[0-9a-zA-Z-]+)*
            ))?
            $
        """,
        re.VERBOSE,
    )

    def __init__(self, version_string: str) -> None:
        match = self._REGEX.match(version_string)
        if match is None:
            raise ValueError(f"{version_string} is not valid SemVer string")
        matched_version_parts: Dict[str, Any] = match.groupdict()
        self.major = int(matched_version_parts["major"])
        self.minor = int(matched_version_parts["minor"])
        self.patch = int(matched_version_parts["patch"])
        self.prerelease = matched_version_parts["prerelease"]
        self.build = matched_version_parts["build"]
        self.txt = version_string

    def compare(self, other: "Version") -> int:
        if self.major > other.major:
            return 1
        elif self.major < other.major:
            return -1
        else:
            if self.minor > other.minor:
                return 1
            elif self.minor < other.minor:
                return -1
            else:
                if self.patch > other.patch:
                    return 1
                elif self.patch < other.patch:
                    return -1
                else:
                    try:
                        spr = int(0 if self.prerelease is None else self.prerelease)
                        opr = int(0 if other.prerelease is None else other.prerelease)
                        if spr > opr:
                            return 1
                        elif spr < opr:
                            return -1
                        else:
                            return 0
                    except ValueError:
                        return 0

    def __eq__(self, other) -> bool:
        return self.compare(other) == 0

    def __ne__(self, other) -> bool:
        return self.compare(other) != 0

    def __lt__(self, other) -> bool:
        return self.compare(other) < 0

    def __le__(self, other) -> bool:
        return self.compare(other) <= 0

    def __gt__(self, other) -> bool:
        return self.compare(other) > 0

    def __ge__(self, other) -> bool:
        return self.compare(other) >= 0

    def __repr__(self) -> str:
        return f"<Version {self.txt}>"


def get_all_versions(repo) -> List:
    versions = []
    for tag in repo.tags:
        try:
            ver = Version(tag.name)
        except ValueError:
            continue
        versions.append({"tag": tag, "version": ver})
    return versions


def get_last_version(repo):
    return sorted(get_all_versions(repo), reverse=True, key=lambda x: x["version"])[0][
        "tag"
    ]


def get_last_3_version(repo):
    return sorted(get_all_versions(repo), reverse=True, key=lambda x: x["version"])[:3]


def print_last_versions_order(repo) -> None:
    try:
        v = [
            ("master", repo.commit("master")),
            ("staging", repo.commit("staging")),
        ]
        for ver in get_last_3_version(repo):
            v.append((ver["tag"], repo.commit(ver["tag"])))

        v = sorted(v, key=lambda x: x[1].committed_datetime, reverse=True)

        prev_commit = None
        for c in v:
            if prev_commit is not None:
                if prev_commit == c[1]:
                    print(f" {TCOLOR.OKGREEN}=={TCOLOR.ENDC} ", end="")
                else:
                    print(f" {TCOLOR.OKBLUE}>>{TCOLOR.ENDC} ", end="")
            print(c[0], end="")
            prev_commit = c[1]
        print("")
    except BadName:
        print(f"{TCOLOR.WARNING}no staging or master tag found on repo{TCOLOR.ENDC} ")


def command_check_stagings(args) -> None:
    print(
        f"'{TCOLOR.OKGREEN}=={TCOLOR.ENDC}' if it is the same commit; '{TCOLOR.OKBLUE}>>{TCOLOR.ENDC}' if the left commit is more recent than the right one."
    )
    for repo_name, repo_d in REPOS_TO_BE_RELEASED.items():
        repo = Repo(repo_d.get("path", "") + repo_name)
        print(f"{repo_name: <19}", end="")
        print_last_versions_order(repo)


def command_graph(args) -> None:
    subprocess.run(
        "git log --decorate --oneline --graph", shell=True, cwd=args.repo, check=True
    )


def command_pull_all(args) -> None:
    if args.checkout:
        print(
            f"{TCOLOR.OKBLUE}$ git submodule foreach git checkout master{TCOLOR.ENDC}"
        )
        subprocess.run(
            "git submodule foreach git checkout master", shell=True, check=True
        )
    print(f"{TCOLOR.OKBLUE}$ git submodule foreach git pull --tags -f{TCOLOR.ENDC}")
    subprocess.run("git submodule foreach git pull --tags -f", shell=True, check=True)


def _force_tag(tag: str) -> None:
    assert tag
    print(f"{TCOLOR.OKBLUE}$ git submodule foreach git tag -f {tag}{TCOLOR.ENDC}")
    subprocess.run(f"git submodule foreach git tag -f {tag}", shell=True, check=True)
    print(
        f"{TCOLOR.OKBLUE}$ git submodule foreach git push -f origin {tag}{TCOLOR.ENDC}"
    )
    subprocess.run(
        f"git submodule foreach git push -f origin {tag}", shell=True, check=True
    )


def command_force_staging(args) -> None:
    _force_tag("staging")


def command_tag_release(args) -> None:
    _force_tag(args.tag)


def _run_cmd(cmd) -> None:
    print(f"{TCOLOR.OKBLUE}$ {cmd} {TCOLOR.ENDC}")
    subprocess.run(cmd, shell=True, check=True)


def command_remove_local_tags(args) -> None:
    # Delete all tags on ryax-engine
    _run_cmd("git tag -l | xargs git tag -d")
    # Restore only remote tags
    _run_cmd("git fetch --tags")
    # Delete tags on each submodule
    _run_cmd('git submodule foreach "git tag -l | xargs git tag -d "')
    # Restore only remote tags for each submodule
    _run_cmd('git submodule foreach "git fetch --tags"')


def command_update_ci_common_version(args):
    """
    Update the ref version in the include section of .gitlab-ci.yml for each submodule using `git submodule foreach` and `sed`.

    Parameters:
    submodules (list of str): List of submodule directories to update.
    new_ref_version (str): The new ref version to set.
    """
    new_ref_version = args.version
    try:
        # Run the sed command to replace the ref in the .gitlab-ci.yml file
        sed_command = f"git submodule foreach 'sed -i \"s/ref: .*/ref: {new_ref_version}/\" .gitlab-ci.yml && git diff || true'"

        subprocess.run(sed_command, shell=True, check=True)

        print(f"Updated ref to {new_ref_version} in all submodules .gitlab-ci.yml")

    except subprocess.CalledProcessError as e:
        print(f"Error updating ref in submodules: {e}")


def command_update_charts_version(args):
    """
    Update the image tag in all Ryax services Helm charts.
    """
    version = args.version
    app_version = args.app_version if args.app_version else version
    try:
        # Files to update
        files_to_update = [
            "charts/ryax/subcharts/authorization/values.yaml",
            "charts/ryax/subcharts/repository/values.yaml",
            "charts/ryax/subcharts/action-builder/values.yaml",
            "charts/ryax/subcharts/studio/values.yaml",
            "charts/ryax/subcharts/runner/values.yaml",
            "charts/ryax/subcharts/front/values.yaml",
            "charts/ryax/subcharts/intelliscale/values.yaml",
            "charts/worker-k8s/values.yaml",
            "charts/worker-ssh-slurm/values.yaml",
        ]

        for file_path in files_to_update:
            if os.path.exists(file_path):
                # Replace tag: "..." or tag: ... with tag: "app_version"
                # We want to keep the indentation.
                sed_command = (
                    f"sed -i 's/\\(tag: \\).*/\\1\"{app_version}\"/' {file_path}"
                )
                subprocess.run(sed_command, shell=True, check=True)
                print(f"Updated image tag to {app_version} in {file_path}")

        # Update version and appVersion in all Chart.yaml files
        for root, dirs, files in os.walk("charts"):
            for file in files:
                if file == "Chart.yaml":
                    chart_path = os.path.join(root, file)
                    # Update version
                    sed_command_v = (
                        f"sed -i 's/^version: .*/version: \"{version}\"/' {chart_path}"
                    )
                    subprocess.run(sed_command_v, shell=True, check=True)
                    # Update appVersion
                    sed_command_av = f"sed -i 's/^appVersion: .*/appVersion: \"{app_version}\"/' {chart_path}"
                    subprocess.run(sed_command_av, shell=True, check=True)
                    print(
                        f"Updated version to {version} and appVersion to {app_version} in {chart_path}"
                    )

        # Update local dependencies in parent charts
        for parent_chart_path in [
            "charts/ryax/Chart.yaml",
            "charts/worker-k8s/Chart.yaml",
            "charts/worker-ssh-slurm/Chart.yaml",
        ]:
            if os.path.exists(parent_chart_path):
                with open(parent_chart_path, "r") as f:
                    content = f.read()

                # Split by dependency entry
                # It can be '  - name:' or '- name:'
                parts = re.split(r"(\n\s*-\s+name:)", content)
                new_parts = [parts[0]]
                for i in range(1, len(parts), 2):
                    header = parts[i]
                    block = parts[i + 1]
                    if (
                        'repository: "file://' in block
                        or "repository: 'file://" in block
                    ):
                        block = re.sub(r"(version: ).*", rf'\1"{version}"', block)
                    new_parts.append(header)
                    new_parts.append(block)

                with open(parent_chart_path, "w") as f:
                    f.write("".join(new_parts))
                print(
                    f"Updated local dependencies version to {version} in {parent_chart_path}"
                )

        # Update Chart.lock
        for parent_dir in [
            "charts/ryax",
            "charts/worker-k8s",
            "charts/worker-ssh-slurm",
        ]:
            if os.path.exists(parent_dir):
                print(f"Updating Chart.lock for {parent_dir}...")
                subprocess.run(
                    f"helm dependency update {parent_dir}", shell=True, check=True
                )

        # Update chart READMEs with helm-docs
        if os.path.exists("charts"):
            print("Updating chart READMEs with helm-docs...")
            subprocess.run("helm-docs", cwd="charts", shell=True, check=True)

    except Exception as e:
        print(f"Error updating charts version: {e}")


def _load_chart_dependencies() -> Dict[str, List[Dict]]:
    """
    Load dependencies of every top-level chart (charts/*/Chart.yaml).

    Returns a mapping {chart_file_path: [dependency, ...]}.
    """
    charts: Dict[str, List[Dict]] = {}
    for chart_file in sorted(glob.glob("charts/*/Chart.yaml")):
        with open(chart_file) as f:
            data = yaml.safe_load(f) or {}
        charts[chart_file] = data.get("dependencies") or []
    return charts


def _load_chart_lock(chart_file: str) -> Dict[str, str]:
    """
    Return {dependency_name: locked_version} from the chart's Chart.lock, i.e.
    the versions actually resolved by `helm dependency update`.
    """
    lock_file = os.path.join(os.path.dirname(chart_file), "Chart.lock")
    if not os.path.exists(lock_file):
        return {}
    with open(lock_file) as f:
        data = yaml.safe_load(f) or {}
    return {
        d.get("name"): str(d.get("version", ""))
        for d in (data.get("dependencies") or [])
    }


def _sorted_stable_versions(version_strings: List[str]) -> List[Version]:
    """Parse, drop pre-releases and invalid strings, sort newest first."""
    parsed: List[Version] = []
    seen = set()
    for vs in version_strings:
        try:
            ver = Version(str(vs))
        except ValueError:
            continue
        if ver.prerelease is not None:
            continue
        if ver.txt in seen:
            continue
        seen.add(ver.txt)
        parsed.append(ver)
    return sorted(parsed, reverse=True)


def _get_helm_repo_map() -> Dict[str, str]:
    """Return a mapping {normalized_url: local_repo_name} of configured helm repos."""
    result = subprocess.run(
        ["helm", "repo", "list", "-o", "json"], capture_output=True, text=True
    )
    if result.returncode != 0:
        return {}
    try:
        repos = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        return {}
    return {r["url"].rstrip("/"): r["name"] for r in repos}


def _helm_search_versions(repo_name: str, chart_name: str) -> List[Version]:
    """List available versions of an http(s) helm chart via `helm search repo`."""
    full_name = f"{repo_name}/{chart_name}"
    result = subprocess.run(
        ["helm", "search", "repo", full_name, "--versions", "-o", "json"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    try:
        entries = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        return []
    return _sorted_stable_versions(
        [e["version"] for e in entries if e.get("name") == full_name]
    )


def _skopeo_list_versions(repo_url: str, chart_name: str) -> List[Version]:
    """List available versions of an OCI helm chart via `skopeo list-tags`.

    Retries a few times to survive transient registry rate-limits (Docker Hub
    throttles anonymous requests).
    """
    ref = "docker://" + repo_url[len("oci://") :].rstrip("/") + "/" + chart_name
    for attempt in range(3):
        result = subprocess.run(
            ["skopeo", "list-tags", ref], capture_output=True, text=True
        )
        if result.returncode == 0:
            try:
                data = json.loads(result.stdout or "{}")
            except json.JSONDecodeError:
                return []
            return _sorted_stable_versions(data.get("Tags", []))
        if attempt < 2:
            time.sleep(2 * (attempt + 1))
    return []


def _constraint_major(constraint: str) -> Optional[int]:
    """Extract the leading major version number from a version constraint."""
    match = re.search(r"(\d+)", constraint)
    return int(match.group(1)) if match else None


def _current_major(locked: str, constraint: str) -> Optional[int]:
    """
    Major version of the real current dependency: the one pinned in Chart.lock,
    falling back to the constraint when the lock has no entry.
    """
    if locked and locked != "-":
        try:
            return Version(locked).major
        except ValueError:
            pass
    return _constraint_major(constraint)


def _major_of(value: str) -> Optional[int]:
    """Major version of a concrete version (16.0.10) or a constraint (16.x.x)."""
    try:
        return Version(value).major
    except ValueError:
        return _constraint_major(value)


def _previous_release_ref() -> Optional[str]:
    """
    Highest final (non pre-release) semver tag strictly older than the version
    declared in charts/ryax/Chart.yaml.

    Used as the upgrade baseline so that at most one major upgrade is proposed
    per release, no matter how often the check (or --update) is run within a
    release cycle.
    """
    try:
        repo = Repo(".")
    except Exception:
        return None

    current = None
    try:
        with open("charts/ryax/Chart.yaml") as f:
            current = Version(str((yaml.safe_load(f) or {}).get("version", "")))
    except (OSError, ValueError):
        current = None

    finals = []
    for tag in repo.tags:
        try:
            v = Version(tag.name)
        except ValueError:
            continue
        if v.prerelease is not None:
            continue
        if current is not None and v >= current:
            continue
        finals.append((v, tag.name))
    if not finals:
        return None
    finals.sort(key=lambda x: x[0], reverse=True)
    return finals[0][1]


def _previous_release_versions(ref: str, chart_file: str) -> Dict[str, str]:
    """
    {dependency_name: version} as pinned at the given git ref, read from
    Chart.lock and falling back to the Chart.yaml constraint.
    """
    versions: Dict[str, str] = {}
    chart_dir = os.path.dirname(chart_file)
    for fname in ("Chart.lock", "Chart.yaml"):
        path = f"{chart_dir}/{fname}"
        out = subprocess.run(
            ["git", "show", f"{ref}:{path}"], capture_output=True, text=True
        )
        if out.returncode != 0:
            continue
        try:
            data = yaml.safe_load(out.stdout) or {}
        except yaml.YAMLError:
            continue
        for dep in data.get("dependencies") or []:
            name = dep.get("name")
            version = str(dep.get("version", ""))
            if name and version and name not in versions:
                versions[name] = version
    return versions


def _recommended_version(
    versions: List[Version], baseline_major: Optional[int]
) -> Optional[Version]:
    """
    Recommend the +1 major above the baseline (when it exists) at its latest
    minor and patch; otherwise the latest release of the baseline major. Never
    goes more than one major above the baseline, which is the previous release,
    so at most one major upgrade is proposed per release cycle.
    """
    if not versions:
        return None
    if baseline_major is not None:
        candidates = [v for v in versions if v.major <= baseline_major + 1]
    else:
        candidates = versions
    if not candidates:
        candidates = versions
    return candidates[0]


def _bump_constraint(old: str, recommended: Version) -> str:
    """
    Rewrite a version constraint to target `recommended`, preserving the style
    used in Chart.yaml (`~`, `^`, `N.x.x`, `N.N.x`, or an exact pin).
    """
    stripped = old.strip()
    rec = recommended
    if stripped.startswith("~"):
        return f"~{rec.major}.{rec.minor}.{rec.patch}"
    if stripped.startswith("^"):
        return f"^{rec.major}.{rec.minor}.{rec.patch}"
    if re.fullmatch(r"v?\d+\.x(\.x)?", stripped):
        return f"{rec.major}.x.x"
    if re.fullmatch(r"v?\d+\.\d+\.x", stripped):
        return f"{rec.major}.{rec.minor}.x"
    return rec.txt


def _edit_chart_constraints(chart_file: str, bumps: Dict[str, str]) -> None:
    """
    Rewrite the `version:` line of each dependency named in `bumps`
    ({dep_name: new_constraint}) in the given Chart.yaml, preserving all other
    formatting and comments.
    """
    with open(chart_file) as f:
        content = f.read()

    parts = re.split(r"(\n\s*-\s+name:)", content)
    new_parts = [parts[0]]
    for i in range(1, len(parts), 2):
        header = parts[i]
        block = parts[i + 1]
        name_match = re.match(r"\s*([^\s#]+)", block)
        dep_name = name_match.group(1) if name_match else None
        if dep_name in bumps:
            block = re.sub(
                r"(version:\s*).*", rf"\g<1>{bumps[dep_name]}", block, count=1
            )
        new_parts.append(header)
        new_parts.append(block)

    with open(chart_file, "w") as f:
        f.write("".join(new_parts))


def _apply_helm_updates(report: List[tuple]) -> None:
    """
    Edit the constraints in each Chart.yaml to the recommended versions and run
    `helm dependency update` to regenerate the Chart.lock files.

    Only upgrades are applied: a dependency already at (or beyond) its
    recommendation is left untouched, so an over-shot dependency is never
    silently downgraded.
    """
    print(f"\n{TCOLOR.BOLD}Applying updates{TCOLOR.ENDC}")
    for chart_file, rows, _internal in report:
        bumps: Dict[str, str] = {}
        need_refresh = False
        for r in rows:
            rec = r.get("recommended")
            if rec is None:
                continue
            try:
                locked_v = Version(r["locked"]) if r["locked"] != "-" else None
            except ValueError:
                locked_v = None
            # Skip deps already up to date or beyond the recommendation.
            if locked_v is not None and rec <= locked_v:
                continue
            need_refresh = True
            new_constraint = _bump_constraint(r["constraint"], rec)
            if new_constraint != r["constraint"].strip():
                bumps[r["name"]] = new_constraint

        print(f"\n{TCOLOR.HEADER}{TCOLOR.BOLD}{chart_file}{TCOLOR.ENDC}")
        if not need_refresh:
            print(f"  {TCOLOR.OKGREEN}already up to date{TCOLOR.ENDC}")
            continue

        for r in rows:
            if r["name"] in bumps:
                print(
                    f"  {r['name']}: {r['constraint']} "
                    f"{TCOLOR.OKBLUE}->{TCOLOR.ENDC} {bumps[r['name']]}"
                )
                _print_changelog_link(r["name"])
        if bumps:
            _edit_chart_constraints(chart_file, bumps)

        chart_dir = os.path.dirname(chart_file)
        _run_cmd(f"helm dependency update {chart_dir}")


def command_check_helm_deps(args) -> int:
    """
    Check external Helm dependencies of charts/*/Chart.yaml against their
    upstream repositories, and suggest an upgrade target: the latest minor/patch
    within at most +1 major above the previous release (from its Chart.lock /
    Chart.yaml), so that no more than one major is proposed per release cycle
    regardless of how often the check runs.

    Returns 1 (unless --update is given) when at least one locked dependency is
    behind its recommendation or is already more than one major above the
    previous release, so it can be used as a CI gate.
    """
    number = args.number
    has_skopeo = shutil.which("skopeo") is not None
    prev_ref = _previous_release_ref()

    print(
        f"{TCOLOR.BOLD}Helm dependencies version check{TCOLOR.ENDC}  "
        f"(recommended {TCOLOR.OKGREEN}→{TCOLOR.ENDC} = latest minor/patch, at "
        f"most +1 major above the previous release baseline)"
    )
    if prev_ref:
        print(
            f"Baseline: previous release {TCOLOR.BOLD}{prev_ref}{TCOLOR.ENDC} "
            f"(RELEASE column) — at most one major upgrade per release."
        )
    else:
        print(
            f"{TCOLOR.WARNING}No previous release tag found: using the locked "
            f"versions as baseline.{TCOLOR.ENDC}"
        )
    if not has_skopeo:
        print(
            f"{TCOLOR.WARNING}skopeo not found: OCI (oci://) charts cannot be "
            f"checked, install it to enable them.{TCOLOR.ENDC}"
        )

    repo_map = _get_helm_repo_map()
    temp_repos: List[str] = []
    updated: set = set()

    # First gather everything so we can align columns nicely.
    charts = _load_chart_dependencies()
    report: List[tuple] = []  # (chart_file, rows, internal_names)
    outdated: List[tuple] = []  # (chart_file, name, locked, recommended)
    overshoot: List[tuple] = []  # (chart_file, name, locked, allowed, baseline)
    unknown: List[str] = []  # deps whose available versions could not be found

    try:
        for chart_file, deps in charts.items():
            lock_map = _load_chart_lock(chart_file)
            prev_versions = (
                _previous_release_versions(prev_ref, chart_file) if prev_ref else {}
            )
            rows = []
            internal = []
            for dep in deps:
                name = dep.get("name", "?")
                repo = str(dep.get("repository", ""))
                constraint = str(dep.get("version", ""))

                if repo.startswith("file://") or not repo:
                    internal.append(name)
                    continue

                if repo.startswith("oci://"):
                    versions = (
                        _skopeo_list_versions(repo, name) if has_skopeo else []
                    )
                else:  # http(s) helm repository
                    url = repo.rstrip("/")
                    repo_name = repo_map.get(url)
                    if repo_name is None:
                        repo_name = f"jefcheck{len(temp_repos)}"
                        subprocess.run(
                            ["helm", "repo", "add", "--force-update", repo_name, url],
                            capture_output=True,
                            text=True,
                        )
                        temp_repos.append(repo_name)
                        repo_map[url] = repo_name
                    if repo_name not in updated:
                        subprocess.run(
                            ["helm", "repo", "update", repo_name],
                            capture_output=True,
                            text=True,
                        )
                        updated.add(repo_name)
                    versions = _helm_search_versions(repo_name, name)

                locked = lock_map.get(name) or "-"
                # Anchor the +1 major cap to the previous release so that
                # repeated runs never propose more than one major per release.
                # New deps (absent from the previous release) fall back to the
                # currently locked version.
                release = prev_versions.get(name)
                if release:
                    baseline = _major_of(release)
                else:
                    baseline = _current_major(locked, constraint)
                rows.append(
                    {
                        "name": name,
                        "constraint": constraint,
                        "locked": locked,
                        "release": release or "-",
                        "versions": versions,
                        "cmajor": baseline,
                        "recommended": _recommended_version(versions, baseline),
                    }
                )
            report.append((chart_file, rows, internal))

        # Compute column widths across all rows for consistent alignment.
        all_rows = [r for _, rows, _ in report for r in rows]
        name_w = max([len(r["name"]) for r in all_rows], default=10)
        cons_w = max([len(r["constraint"]) for r in all_rows] + [len("CONSTRAINT")])
        lock_w = max([len(r["locked"]) for r in all_rows] + [len("LOCKED")])
        rel_w = max([len(r["release"]) for r in all_rows] + [len("RELEASE")])
        lat_w = max(
            [len(r["versions"][0].txt) for r in all_rows if r["versions"]]
            + [len("LATEST")]
        )
        rec_w = lat_w

        for chart_file, rows, internal in report:
            print(f"\n{TCOLOR.HEADER}{TCOLOR.BOLD}{chart_file}{TCOLOR.ENDC}")
            if not rows:
                print("  (no external dependencies)")
            else:
                print(
                    f"  {'DEPENDENCY': <{name_w}}  {'CONSTRAINT': <{cons_w}}  "
                    f"{'LOCKED': <{lock_w}}  {'RELEASE': <{rel_w}}  "
                    f"{'LATEST': <{lat_w}}  {'RECOMMENDED': <{rec_w}}  AVAILABLE"
                )
            for r in rows:
                versions = r["versions"]
                if not versions:
                    unknown.append(r["name"])
                    latest = f"{TCOLOR.FAIL}N/A{TCOLOR.ENDC}"
                    recommended = f"{TCOLOR.FAIL}N/A{TCOLOR.ENDC}"
                    available = f"{TCOLOR.FAIL}not found{TCOLOR.ENDC}"
                    latest_pad = " " * (lat_w - len("N/A"))
                    rec_pad = " " * (rec_w - len("N/A"))
                else:
                    latest_v = versions[0]
                    recommended_v = r["recommended"]

                    try:
                        locked_v = (
                            Version(r["locked"]) if r["locked"] != "-" else None
                        )
                    except ValueError:
                        locked_v = None

                    major_bump = (
                        r["cmajor"] is not None
                        and r["cmajor"] < recommended_v.major
                    )
                    if locked_v is None:
                        # No parseable lock entry: cannot tell if it is behind.
                        unknown.append(r["name"])
                        rec_color = TCOLOR.OKBLUE
                        marker = "→"
                    elif (
                        r["cmajor"] is not None
                        and locked_v.major > r["cmajor"] + 1
                    ):
                        # More than one major above the previous release.
                        overshoot.append(
                            (
                                chart_file,
                                r["name"],
                                r["locked"],
                                recommended_v.txt,
                                r["cmajor"],
                            )
                        )
                        rec_color = TCOLOR.FAIL
                        marker = "⚠"
                    elif locked_v < recommended_v:
                        outdated.append(
                            (chart_file, r["name"], r["locked"], recommended_v.txt)
                        )
                        rec_color = TCOLOR.WARNING if major_bump else TCOLOR.OKBLUE
                        marker = "→"
                    else:
                        rec_color = TCOLOR.OKGREEN
                        marker = "✓"

                    latest = latest_v.txt
                    recommended = (
                        f"{rec_color}{marker} {recommended_v.txt}{TCOLOR.ENDC}"
                    )
                    available = "  ".join(v.txt for v in versions[:number])
                    latest_pad = " " * (lat_w - len(latest_v.txt))
                    rec_pad = " " * max(0, rec_w - len(recommended_v.txt))

                print(
                    f"  {r['name']: <{name_w}}  {r['constraint']: <{cons_w}}  "
                    f"{r['locked']: <{lock_w}}  {r['release']: <{rel_w}}  "
                    f"{latest}{latest_pad}  {recommended}{rec_pad}  {available}"
                )
            if internal:
                print(
                    f"  {TCOLOR.OKBLUE}(+ {len(internal)} internal subcharts: "
                    f"{', '.join(internal)}){TCOLOR.ENDC}"
                )

        print("")
        if outdated:
            print(
                f"{TCOLOR.WARNING}{TCOLOR.BOLD}{len(outdated)} dependency(ies) "
                f"behind the recommendation:{TCOLOR.ENDC}"
            )
            for cf, name, locked, rec in outdated:
                print(f"  {cf}: {name} {locked} {TCOLOR.OKBLUE}→{TCOLOR.ENDC} {rec}")
                _print_changelog_link(name)
            print(
                "Run 'jef.py check_helm_deps --update' to apply the "
                "recommended versions."
            )
        if overshoot:
            print(
                f"{TCOLOR.FAIL}{TCOLOR.BOLD}{len(overshoot)} dependency(ies) more "
                f"than one major above the previous release "
                f"({prev_ref}):{TCOLOR.ENDC}"
            )
            for cf, name, locked, allowed, base in overshoot:
                print(
                    f"  {cf}: {name} locked {locked} but the release baseline is "
                    f"major {base} (max allowed this release: {allowed})"
                )
                _print_changelog_link(name)
        if not outdated and not overshoot:
            print(
                f"{TCOLOR.OKGREEN}All dependencies are up to date with the "
                f"recommendation.{TCOLOR.ENDC}"
            )
        if unknown:
            print(
                f"{TCOLOR.WARNING}Could not determine available versions "
                f"(skipped): {', '.join(unknown)}{TCOLOR.ENDC}"
            )

        if args.update:
            _apply_helm_updates(report)
    finally:
        for tr in temp_repos:
            subprocess.run(
                ["helm", "repo", "remove", tr], capture_output=True, text=True
            )

    if args.update:
        return 0
    return 1 if (outdated or overshoot) else 0


def get_last_pipe(projgit, tag) -> Dict:
    for pipe in projgit.pipelines.list(get_all=False):
        if tag != pipe.ref:
            continue
        return {
            "ref": pipe.ref,
            "sha": pipe.sha,
            "url": pipe.web_url,
            "status": pipe.status,
        }
    return {
        "ref": tag,
        "sha": "",
        "url": "",
        "status": "NOT_FOUND",
    }


def print_pipe(reponame, pipe) -> None:
    if pipe["status"] == "NOT_FOUND":
        print(f"{reponame: <15} NOT_FOUND")
        return
    status = pipe["status"]
    if status == "success":
        status = f"{TCOLOR.OKGREEN}success{TCOLOR.ENDC}"
    elif status == "failed":
        status = f"{TCOLOR.FAIL}failed{TCOLOR.ENDC} "
    else:
        status = f"{TCOLOR.WARNING}{status}{TCOLOR.ENDC} "

    print(
        f"{reponame: <15} {pipe['ref']: <7} v{pipe['sha'][:8]} {status} {pipe['url']}"
    )


def command_wait_all_pipes(args) -> None:
    tag = args.tag
    GITLAB_TOKEN = os.environ["GITLAB_TOKEN"]
    import gitlab

    gl = gitlab.Gitlab("https://gitlab.com/", private_token=GITLAB_TOKEN)
    gl.auth()

    repo_temp = []
    for reponame in REPOS_TO_BE_RELEASED.keys():
        REPOS_TO_BE_RELEASED[reponame]["pipe"] = {"status": "UNKNOWN"}
        repo_temp.append(reponame)
    repo_temp.sort()

    repo_not_finished = []
    # TODO: restore this went the pipeline is restored
    # REPOS_TO_BE_RELEASED["engine"] = {
    #     "gitlab_project": MAIN_RELEASE_REPO["gitlab_project"]
    # }
    # repo_not_finished.append("engine")
    repo_not_finished.extend(repo_temp)
    repo_not_finished.append("SLEEP")

    while len(repo_not_finished) > 1:
        reponame = repo_not_finished.pop(0)
        if reponame == "SLEEP":
            print("...")
            time.sleep(5.5)
            repo_not_finished.append(reponame)
            continue
        repo = REPOS_TO_BE_RELEASED[reponame]
        pipe = get_last_pipe(gl.projects.get(repo["gitlab_project"]), tag)
        print_pipe(reponame, pipe)
        if (
            pipe["status"] == "success"
            or pipe["status"] == "failed"
            or pipe["status"] == "NOT_FOUND"
        ):
            continue
        else:
            repo_not_finished.append(reponame)


def command_update_API(args) -> None:
    server = args.server
    version = args.version

    print("+=+  Get swagger and generate SDK  +=+")
    print(f"{TCOLOR.OKBLUE}$ ./genrate.sh{TCOLOR.ENDC}")
    os.environ["API_SERVER"] = server
    os.environ["API_VERSION"] = version
    subprocess.run("./generate.sh", cwd="sdk/ryax-python-sdk/", shell=True, check=True)

    print("+=+  Copy SDK to CLI  +=+")
    print(f"{TCOLOR.OKBLUE}$ rm -rf ../../cli/ryax_sdk/*{TCOLOR.ENDC}")
    subprocess.run(
        "rm -rf ../../cli/ryax_sdk/*",
        cwd="sdk/ryax-python-sdk/",
        shell=True,
        check=True,
    )
    print(f"{TCOLOR.OKBLUE}$ cp -r ryax_sdk/* ../../cli/ryax_sdk{TCOLOR.ENDC}")
    subprocess.run(
        "cp -r ryax_sdk/* ../../cli/ryax_sdk",
        cwd="sdk/ryax-python-sdk/",
        shell=True,
        check=True,
    )

    if not args.sdk_only:
        print("+=+  Update the public doc  +=+")
        subprocess.run(
            f""" sed  "s/__RYAX_API_VERSION__/{version}/g" ryax-public-doc/api_template/spec.rst > ryax-public-doc/api/{version}.rst""",
            shell=True,
            check=True,
        )
        shutil.copy(
            "sdk/ryax-python-sdk/ryax-spec.json",
            f"ryax-public-doc/_static/api/{version}-spec.json",
        )

    print("+=+  You need to manually run the tests and commit everything!  +=+")


if __name__ == "__main__":
    # create the top-level parser
    parser = argparse.ArgumentParser(
        description="The ultimate tool to help JEllyFishes releasing the Ryax software."
    )
    subparsers = parser.add_subparsers()

    # create command parsers

    description = (
        "Give an overview of the state of the staging tag in all released repo"
    )
    sp = subparsers.add_parser(
        "check_stagings", description=description, help=description
    )
    sp.set_defaults(func=command_check_stagings)

    description = "Display the git graph of the given <repo> `git log --decorate --oneline --graph`"
    sp = subparsers.add_parser("graph", description=description, help=description)
    sp.add_argument("repo", type=str)
    sp.set_defaults(func=command_graph)

    description = "`git submodule foreach git pull`"
    sp = subparsers.add_parser("pull_all", description=description, help=description)
    sp.add_argument("-c", "--checkout", action="store_true")
    sp.set_defaults(func=command_pull_all)

    description = "Wait for all gitlab pipelines with <TAG> to finish"
    sp = subparsers.add_parser(
        "wait_all_pipes", description=description, help=description
    )
    sp.add_argument("tag", type=str)
    sp.set_defaults(func=command_wait_all_pipes)

    description = "Update CI Common version in all Gitlab config"
    sp = subparsers.add_parser(
        "ci_common_update", description=description, help=description
    )
    sp.add_argument("-v", "--version")
    sp.set_defaults(func=command_update_ci_common_version)

    description = "Update image version in all Ryax services Helm charts"
    sp = subparsers.add_parser(
        "charts_update", description=description, help=description
    )
    sp.add_argument("-v", "--version", required=True)
    sp.add_argument(
        "-a",
        "--app-version",
        help="The app version to use for images and appVersion field. Defaults to version if not set.",
    )
    sp.set_defaults(func=command_update_charts_version)

    description = "Check external Helm chart dependencies (charts/*/Chart.yaml) against upstream repos and suggest an upgrade target (the release before the latest)"
    sp = subparsers.add_parser(
        "check_helm_deps", description=description, help=description
    )
    sp.add_argument(
        "-n",
        "--number",
        type=int,
        default=5,
        help="Number of latest available versions to display (default: 5).",
    )
    sp.add_argument(
        "-u",
        "--update",
        action="store_true",
        help="Apply the recommended versions: edit the constraints in "
        "charts/*/Chart.yaml and run `helm dependency update` to refresh the "
        "Chart.lock files.",
    )
    sp.set_defaults(func=command_check_helm_deps)

    description = "Force all submodule staging branch to align with current version"
    sp = subparsers.add_parser(
        "force_staging", description=description, help=description
    )
    sp.add_argument("-v", "--version")
    sp.set_defaults(func=command_force_staging)

    description = "Tag release in all projects, WARNING overwrites existing ones if so"
    sp = subparsers.add_parser("tag_release", description=description, help=description)
    sp.add_argument("-t", "--tag")
    sp.set_defaults(func=command_tag_release)

    description = "Remove all local tags"
    sp = subparsers.add_parser(
        "remove_local_tags", description=description, help=description
    )
    sp.add_argument("-v", "--version")
    sp.set_defaults(func=command_remove_local_tags)

    description = "Update API: generate from the running server <SERVER> a swagger doc, put it on the public doc and generate the SDK for the CLI. Do not commit anything."
    sp = subparsers.add_parser("update_API", description=description, help=description)
    sp.add_argument("server", type=str, default="https://staging.ryax.io")
    sp.add_argument("version", type=str)
    sp.add_argument(
        "-s",
        "--sdk-only",
        action="store_true",
        help="Only generate the SDK, do not update the documentation.",
    )
    sp.set_defaults(func=command_update_API)

    args = parser.parse_args()
    if hasattr(args, "func"):
        sys.exit(args.func(args) or 0)
    else:
        parser.print_help()
