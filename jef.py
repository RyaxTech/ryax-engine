#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""
Jef, a tool to help you release and maintain Ryax.
"""

import yaml
import os
import re
import subprocess
import time
import shutil
from typing import Any, Dict, List
import argparse

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
    "adm": {
        "gitlab_project": "ryax-tech/ryax/ryax-adm",
    },
    "intelliscale": {"gitlab_project": "ryax-tech/ryax/ryax-intelliscale"},
    "authorization": {
        "gitlab_project": "ryax-tech/ryax/ryax-authorization",
    },
    "common-helm-charts": {
        "gitlab_project": "ryax-tech/ryax/common-helm-charts",
    },
    "default-actions": {
        "gitlab_project": "ryax-tech/workflows/default-actions",
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
    "webui": {
        "gitlab_project": "ryax-tech/ryax/ryax-webui",
    },
}

MAIN_RELEASE_REPO = {
    "gitlab_project": "ryax-tech/ryax/ryax-release",
}

MAX_REPO_NAME_LEN = max([len(r) for r in REPOS_TO_BE_RELEASED.keys()])


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
        repo = Repo(repo_name)
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


def command_update_ryax_adm_version(args):
    """
    Update the RYAX_ADM_VERSION in the .gitlab-ci.yml file for each submodule.

    Parameters:
    submodules (list of str): List of submodule directories to update.
    new_version (str): The new RYAX_ADM_VERSION to set.
    """
    version = args.version
    try:
        # Run the sed command to replace the RYAX_ADM_VERSION in the .gitlab-ci.yml file
        sed_command = f"git submodule foreach 'sed -i \"s/RYAX_ADM_VERSION: .*/RYAX_ADM_VERSION: {version}/\" .gitlab-ci.yml && git diff  || true'"

        subprocess.run(sed_command, shell=True, check=True)

        print(f"Updated RYAX_ADM_VERSION to {version} in all submodules .gitlab-ci.yml")

    except subprocess.CalledProcessError as e:
        print(f"Error updating ref in submodules: {e}")


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
    REPOS_TO_BE_RELEASED["release"] = {
        "gitlab_project": MAIN_RELEASE_REPO["gitlab_project"]
    }
    repo_not_finished.append("release")
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

    description = "Update RYAX_ADM_VERSION in all Gitlab config"
    sp = subparsers.add_parser("adm_update", description=description, help=description)
    sp.add_argument("-v", "--version")
    sp.set_defaults(func=command_update_ryax_adm_version)

    description = "Update CI Common version in all Gitlab config"
    sp = subparsers.add_parser(
        "ci_common_update", description=description, help=description
    )
    sp.add_argument("-v", "--version")
    sp.set_defaults(func=command_update_ci_common_version)

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
        args.func(args)
    else:
        parser.print_help()
