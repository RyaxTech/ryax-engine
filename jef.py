#!/usr/bin/env python3
# Copyright (c) Ryax Technologies

import glob
import json
import os
import re
import subprocess
from operator import itemgetter
from typing import Any, BinaryIO, Dict, Iterator, List, Optional, Tuple, Union


class TCOLOR:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"
    ENDC = "\033[0m"


def print_list_of_dict_as_table(
    d: List[dict], headers_order: Optional[List[str]] = None, sort_by: str = None
) -> None:
    """
    print the list of dict <d> as a table in the console.  Items will be sorted
    using <headers_order> and only items that are in <headers_order> are
    printed.
    """
    if headers_order is None:
        if len(d) == 0:
            return
        else:
            headers_order = list(d[0].keys())

    sorted(d, key=itemgetter(*headers_order))
    if sort_by is not None:
        d = sorted(d, key=lambda x: (x[sort_by] or "?"))

    # convert non string values to strings
    for row in d:
        for h in headers_order:
            if type(row[h]) == list:
                row[h] = ",".join([str(x) for x in row[h]])
            elif not isinstance((row[h]), str):
                row[h] = str(row[h])

    def len_without_color(s):
        return len(re.sub(r"\033\[[0-9]+m", "", s))

    headers_width = {}
    for h in headers_order:
        headers_width[h] = len_without_color(h)
        for row in d:
            headers_width[h] = max(headers_width[h], len_without_color(str(row[h])))

    print(TCOLOR.UNDERLINE + "|", end="")
    for h in headers_order:
        print(" {: >{}}|".format(h, headers_width[h]), end="")
    print(TCOLOR.ENDC)

    for row in d:
        print("|", end="")
        for h in headers_order:
            len_color_overhead = len(row[h]) - len_without_color(row[h])
            print(
                " {: >{}}|".format(row[h], headers_width[h] + len_color_overhead),
                end="",
            )
        print("")


def describe_repos():
    repos = {}
    repos_with_no_dep = []
    for d in glob.glob("*/release.json") + glob.glob("*/*/release.json"):
        lib = {"release_file": d, "dir": os.path.dirname(d)}
        lib["libname"] = (
            subprocess.run(
                f"cd {lib['dir']} ; git remote get-url --push origin",
                shell=True,
                capture_output=True,
            )
            .stdout.decode()
            .strip()
            .split("/")[-1][: -len(".git")]
        )
        release_json = json.load(open(d))
        lib["version"] = release_json["version"]
        lib["dependencies"] = {}
        if "dependencies" in release_json:
            for p, d in release_json["dependencies"].items():
                lib["dependencies"][p] = d["version"]
        if len(lib["dependencies"]) == 0:
            repos_with_no_dep.append(lib["libname"])

        lib["git_version"] = (
            subprocess.run(
                f"cd {lib['dir']} ; git describe --dirty",
                shell=True,
                capture_output=True,
            )
            .stdout.decode()
            .strip()
        )
        lib["last_tag"] = (
            subprocess.run(
                f"cd {lib['dir']} ; git describe --abbrev=0",
                shell=True,
                capture_output=True,
            )
            .stdout.decode()
            .strip()
        )

        lib["reverse_dependencies"] = []

        repos[lib["libname"]] = lib

    # find reverse dependencies
    for reponame, repo in repos.items():
        for dep, depver in repo["dependencies"].items():
            repos[dep]["reverse_dependencies"].append(reponame)

    return repos, repos_with_no_dep


def analyze_repos(repos: dict, repos_with_no_dep: list, print_errors=True):
    for _, repo in repos.items():
        if print_errors:
            print("++", repo["libname"])
        repo["need_update"] = False

        if repo["version"] != repo["last_tag"]:
            if print_errors:
                print(
                    "The current version (",
                    repo["version"],
                    ") and the last tag (",
                    repo["last_tag"],
                    ") differ!",
                )
            repo["need_update"] = True

        if repo["version"] != repo["git_version"]:
            if print_errors:
                print(
                    "There are new commits since last version. (current git version:",
                    repo["version"],
                    " / version.json:",
                    repo["git_version"],
                    ")",
                )
            repo["need_update"] = True

        for dep, depver in repo["dependencies"].items():
            if depver != "master" and depver != repos[dep]["version"]:
                if print_errors:
                    print(
                        "Dependency",
                        dep,
                        "has version",
                        repos[dep]["version"],
                        "while you are using version",
                        depver,
                    )
                repo["need_update"] = True

        # determine next_version
        if repo["need_update"]:
            semver = repo["last_tag"].split(".")
            semver[-1] = str(int(semver[-1]) + 1)
            repo["next_version"] = ".".join(semver)
        else:
            repo["next_version"] = repo["version"]


def print_dep(repos: dict, repos_with_no_dep: list, indent=0):
    # print(indent, repos_with_no_dep)
    for repo in repos_with_no_dep:
        print("  " * indent + "╰", end="")
        print(repo)
        print_dep(repos, repos[repo]["reverse_dependencies"], indent + 1)


def print_json(repos: dict, repos_with_no_dep: list):
    analyze_repos(repos, repos_with_no_dep, print_errors=False)
    print(json.dumps(repos, indent=2))


def print_current_version(repos: dict, repos_with_no_dep: list):
    analyze_repos(repos, repos_with_no_dep, print_errors=False)

    # Compute a score to order repos.
    # The lower score should be updated first.
    # This doesn't work on some complex settings, but is enough for our case.
    for repo in repos.values():
        repo["score"] = len(repos)
    for repo in repos.values():
        for dep in repo["dependencies"]:
            repos[dep]["score"] -= 1

    repos_list = []
    for repo in repos.values():
        if repo["need_update"]:
            correct_version = f"{TCOLOR.FAIL}{repo['next_version']}{TCOLOR.ENDC}"
        else:
            correct_version = f"{TCOLOR.OKGREEN}{repo['next_version']}{TCOLOR.ENDC}"

        repos_list.append(
            {
                **repo,
                "next": correct_version,
                "rls.json": repo["version"],
                "tag": repo["last_tag"],
                "git": repo["git_version"],
                " ": repo["score"],
            }
        )
    print_list_of_dict_as_table(
        repos_list, [" ", "libname", "next", "rls.json", "tag", "git"], "score"
    )


def update_release_json(repos: dict, repos_with_no_dep: list):
    # find problems
    analyze_repos(repos, repos_with_no_dep, print_errors=False)
    # create release.json
    print(json.dumps(repos, indent=2))
    for repo in repos.values():
        print("=========", repo["libname"], repo["release_file"])
        deps = {}
        for dep, depver in repo["dependencies"].items():
            if depver == "master":
                deps[dep] = {"version": "master", "rolling": True}
            else:
                deps[dep] = {"version": repos[dep]["next_version"]}
        print(
            json.dumps(
                {
                    "version": repo["next_version"] + " WERE " + repo["version"],
                    "dependencies": deps,
                },
                indent=4,
            )
        )
        json.dump(
            {"version": repo["next_version"], "dependencies": deps},
            open(repo["release_file"], "w"),
            indent=4,
        )


COMMANDS = {
    "print_json": {"description": "Print all infos in JSON.", "function": print_json},
    "print_version": {
        "description": "Print versions of each package.",
        "function": print_current_version,
    },
    "print_dep": {
        "description": "Print dependencies in reverse order.",
        "function": print_dep,
    },
    "analyze_repos": {
        "description": "Tell us what's wrong.",
        "function": analyze_repos,
    },
    "update": {
        "description": "Update the release.json files.",
        "function": update_release_json,
    },
}


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="The ultimate tool to help JEllyFishes releasing the Ryax software."
    )
    subparsers = parser.add_subparsers(dest="command", required=True, metavar="COMMAND")
    for cmd, descr in COMMANDS.items():
        p = subparsers.add_parser(
            cmd, description=descr["description"], help=descr["description"]
        )
    args = parser.parse_args()
    COMMANDS[args.command]["function"](*describe_repos())
