# ryax-main

Ryax main repository

## Submodule management

Get all the submodules:
```sh
git clone --recursive git@gitlab.com:ryax-tech/dev/ryax-main.git
```

Got from detached head to master branch for all repo:
```sh
git submodule foreach git checkout master
```

Updates all submodules from master:
```sh
 git submodule foreach git pull
```
