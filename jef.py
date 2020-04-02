#!/usr/bin/env python3
# Copyright (c) Ryax Technologies

import glob
import json
import os
import subprocess


class TCOLOR:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"
    ENDC = "\033[0m"


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
            deps = {}
            for p, d in release_json["dependencies"].items():
                lib["dependencies"][p] = d["version"]
        if len(lib["dependencies"]) == 0:
            repos_with_no_dep.append(lib["libname"])

        lib["git_version"] = (
            subprocess.run(
                f"cd {lib['dir']} ; git describe --dirty", shell=True, capture_output=True
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
            if depver != repos[dep]["version"]:
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


def print_dep(repos: dict, repos_with_no_dep: list, indent=0):
    # print(indent, repos_with_no_dep)
    for repo in repos_with_no_dep:
        print("  " * indent + "╰", end="")
        print(repo)
        print_dep(repos, repos[repo]["reverse_dependencies"], indent + 1)


def print_json(repos: dict, repos_with_no_dep: list):
    analyze_repos(repos, repos_with_no_dep, print_errors=False)
    print(json.dumps(repos, indent=2))


def update_release_json(repos: dict, repos_with_no_dep: list):
    # find problems
    analyze_repos(repos, repos_with_no_dep, print_errors=False)
    # determine next_version
    for repo in repos.values():
        if repo["need_update"]:
            semver = repo["last_tag"].split(".")
            semver[-1] = str(int(semver[-1]) + 1)
            repo["next_version"] = ".".join(semver)
        else:
            repo["next_version"] = repo["version"]
    # create release.json
    print(json.dumps(repos, indent=2))
    for repo in repos.values():
        print("=========", repo["libname"], repo["release_file"])
        deps = {}
        for dep, depver in repo["dependencies"].items():
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


def order_update_rec(repos: dict, repos_with_no_dep: list, score):
    for repo in repos_with_no_dep:
        repos[repo]["score"] += score
        order_update_rec(repos, repos[repo]["reverse_dependencies"], score + 3)


def order_update(repos: dict, repos_with_no_dep: list):
    analyze_repos(repos, repos_with_no_dep, print_errors=False)
    for repo in repos.values():
        repo["score"] = 0
    order_update_rec(repos, repos_with_no_dep, 1)
    repos_sorted = sorted(repos.values(), key=lambda x: x["score"])
    for i, repo in enumerate(repos_sorted):
        if repo["need_update"]:
            need_update = f"{TCOLOR.FAIL}NEED UPDATE{TCOLOR.ENDC}"
        else:
            need_update = f"{TCOLOR.OKGREEN}OK{TCOLOR.ENDC}"
        print(
            i + 1,
            ") ",
            repo["libname"],
            ": \t",
            repo["dir"],
            " \t",
            need_update,
            sep="",
        )
        # print_dep(repos, repos[repo]["reverse_dependencies"], score+1)


COMMANDS = {
    "print_json": {"description": "Print all infos in JSON.", "function": print_json},
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
    "order_update": {
        "description": "Print repo in order they should be updated",
        "function": order_update,
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
