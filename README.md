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

## Useful commands for development

Most repos have their own shell.nix, which setup all dependencies at the right version.
Thus, dont forget to:
```sh
nix-shell
```

However, this previous requires you to restart the nix-shell every time that you update a dependency.
It may be useful, for python dependencies, to make symlinks.
```sh
ln -s $(pwd)/lib/common/ryax_common/ core/ryax_core/
ln -s $(pwd)/lib/common/ryax_common/ core/tests/
ln -s $(pwd)/lib/common/ryax_common/ core/
ln -s $(pwd)/lib/common/ryax_common/ effects/orchestrator_kube_effect/
ln -s $(pwd)/lib/functions/ryax_functions/ effects/orchestrator_kube_effect/
ln -s $(pwd)/lib/common/ryax_common/ launcher/
ln -s $(pwd)/lib/functions/ryax_functions/ launcher/
```
