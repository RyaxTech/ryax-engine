# Ryax

This repository is the Ryax main repository for the backend.  At Ryax Tech, we
use several Git repositories.  This repository includes all of them using the
[submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) system.

To clone this repository:
```sh
git clone --recursive git@gitlab.com:ryax-tech/ryax/ryax-main.git
```

Got from detached head to master branch for all repo:
```sh
git submodule foreach git checkout master
```

Updates all submodules from their current branch:
```sh
git submodule foreach git pull
```

If a new submodule is added, clone it:
```sh
git submodule update
```
