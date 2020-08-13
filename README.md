# Ryax main repository

Ryax main repository for the backend.
At Ryax Tech, we use several Git repositories.
This repository includes all of them using the [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) system.

To clone this repository:
```sh
git clone --recursive git@gitlab.com:ryax-tech/dev/backend/ryax-main.git
```

Got from detached head to master branch for all repo:
```sh
git submodule foreach git checkout master
```

Updates all submodules from their current branch:
```sh
git submodule foreach git pull
```

## Documentation

You can find documentation of all submodules in their gitlab page:
- Code stuff:
    - [workflows](https://ryax-tech.gitlab.io/dev/backend/workflows/):
        Some modules and workflows
    - [cli](https://ryax-tech.gitlab.io/dev/backend/cli/):
        The CLI to command Ryax
    - [core](https://ryax-tech.gitlab.io/dev/backend/core/):
        Home of the reducers, the core of Ryax logic
    - [launcher](https://ryax-tech.gitlab.io/dev/backend/launcher/):
        The piece of code that launch function (aka module) code
    - [sources](https://ryax-tech.gitlab.io/dev/backend/sources/):
        The piece of code that launch source (aka gateway) code
    - [modules](https://ryax-tech.gitlab.io/dev/backend/modules/)
        A library to manage modules.
    - [builder](https://ryax-tech.gitlab.io/dev/backend/effects/builder)
        An effect that builds modules
    - [orchestrator](https://ryax-tech.gitlab.io/dev/backend/effects/orchestrator/)
        An effect that manages Kubernetes
    - [ryax-webui](https://gitlab.com/ryax-tech/dev/ryax-webui)
        The WebUI. WARNING: it contains javascript.
- Operational and CI/CD stuff:
    - [adm](https://ryax-tech.gitlab.io/dev/backend/adm/):
        Everything you need to install Ryax
    - [integration_tests](https://ryax-tech.gitlab.io/dev/backend/integration_tests/):
        Integration tests
    - [internal_services](https://ryax-tech.gitlab.io/dev/backend/internal_services/):
        Ryax infrastructure definitions and deployment tools
    - [ci_common](https://ryax-tech.gitlab.io/dev/backend/ci_common/):
        Common CI stuff
    - [ryax-release](https://ryax-tech.gitlab.io/dev/ryax-release/):
        Everything to release a new version of Ryax, for testing purpose or in production.
- Nix stuff:
    - [ryaxpkgs](https://ryax-tech.gitlab.io/dev/backend/ryaxpkgs/):
        A Nix repository internal to Ryax
    - [ryaxuserpkgs](https://ryax-tech.gitlab.io/dev/backend/ryaxuserpkgs/):
        A Nix repository that may be opened one day


Ryax use several technologies, here are some tutorials:
- Nix, the package manager: [a generic tutorial](https://nix.dev/index.html)
- Docker and Kubernetes, the container system and its orchestration: [a page with tutorials covering everything](https://container.training/)
- Python3.asyncio, the concurrent python lib: [A generic tutorial](https://realpython.com/async-io-python/)
- RabbitMQ, the message broker: [the official tutorial](https://www.rabbitmq.com/tutorials/tutorial-one-python.html) and [an online simulator](http://tryrabbitmq.com/).


## Releasing

### Release of a submodule

To release a new version of a submodule, first you have to increase the `version` field in the
`release.json` file located the root of each subproject. Please follow the
semantic versioning guidelines: See [Semver](https://semver.org/).

Then, create a Merge request (or use an existing one) with your working branch.
If The CI run successfully, you can merge your MR into master.

After you have checked that the CI is still running successfully on the master
branch, you can tag your last commit and push it with the following command:

```sh
VERSION=$(cat release.json | jq -r .version) && git tag -a -m "Release $VERSION" "$VERSION" && git push origin $VERSION
```

Then, you can go to Gitlab and edit the description of the release:
```sh
# Get the link for ryax common:
SUBPROJECT=lib/common echo https://gitlab.com/ryax-tech/dev/backend/$SUBPROJECT/-/tags/$VERSION/release/edit
```

Here is an example template for your release note:
```
## Features:
- Nice feature A (#12)
- Super nice feature B (#23)

## Bug fix
- Feature C bug (#13)

### Know issues:
- In some case, feature A is failing (#55)
```

### Propagate the New Library Version

Now you can propagate the new library version in the other Ryax tools that
depends on it.

List all modules, with their current git version, current tag, current version in the `release.json` file and their potential next version:
```sh
python jef.py print_version
```

Submodules in red need to be updated, it can be because of:
- the tag is different than the version in release.json (columns `tag` and `rls.json` are different)
- their are somme commits done after the last tag (columns `tag` and `git` are different)
- some of its dependencies are not up to date.

If the `tag`, `git`, and `rls.json` are equals, you can use the same tool to update all `release.json` files:
```sh
python jef.py update
```

### Release of Ryax

See the [ryax-release](https://ryax-tech.gitlab.io/dev/ryax-release/) git repository.


### A new submodule has been added

If a new submodule is added, clone it:
```sh
git submodule update
```


---

[License](LICENSE.md)


