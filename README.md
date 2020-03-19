# ryax-main

Ryax main repository.

## Releasing

### Release the Library

To release a library, first you have to increase the `version` field in the
`release.json` file located the root of each subproject. Please follow the
semantic versioning guidelines: See https://semver.org/

Then, create a Merge request (or use an existing one) with your working branch.
If The CI run successfully, you can merge your MR into master.

After you have checked that the CI is still running successfully on the master
branch, you can tag your last commit and push it with the following command:

```sh
VERSION=$(cat release.json | jq -r .version) && git tag -a -m "Release $VERSION" "$VERSION" && git push
```

Then, you can go to Gitlab and edit the description of the release:
```sh
# Get the link for ryax common:
SUBPROJECT=ryax_common echo https://gitlab.com/ryax-tech/dev/backend/$SUBPROJECT/-/tags/$VERSION/release/edit
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

You can list these tools with the following command:
```sh
# From ryax-main for ryax_functions
export LIBRARY=ryax_functions
find . -name 'release.json' -exec grep -l $LIBRARY {} +
```

Increase the version of the new library on each of them along with the main
version of the tool and repeat the release process.

You can check the consistency of the library version with:
```sh
for file in $(find . -name release.json -exec grep -l $LIBRARY {} +)
do
echo $file
cat $file | jq .dependencies.$LIBRARY.version
done
```

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

When a new submodule is added, clone it:
```sh
git submodule update
```
