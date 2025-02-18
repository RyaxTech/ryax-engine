We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 25.02.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

Optimize the Resources

## New features

- Automatic Action resource scaling
- Automatic Retries
- Resources accounting (Preview)
- Runtime Class support for the Kubernetes add-on

## Bug fixes and Improvements

- Fix: issue when enabling Action Builder Nix store persistence
- Fix: enable deletion of workflow even when on error

## Upgrade to this version

Because the Worker changes from SQLite database to PostgreSQL you have to reset its state.
To do so, remove the worker with:
```sh
helm uninstall ryax-worker -n ryaxns
```
We also need to clean broker state to clean internal state:
```
helm uninstall rabbitmq -n ryaxns
kubectl delete pvc -n ryaxns data-ryax-broker-0
```

Runner should be cleaned also:
```sh
ryax-adm clean runner
```

For external workers be sure that you have the values.yaml file that you used
for the previous installation and then run, for example:
```sh
helm uninstall ryax-other-worker -n ryaxns
helm install -n ryaxns --values ryax-other-worker.yaml
```

Then apply the update as usual.
