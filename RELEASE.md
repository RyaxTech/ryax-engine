We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.4.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

## New features

### New scheduling policy

We have added a new multi-objective scheduler that combines static scores, runtime prediction, node-pool pricing,
and empirical execution history to automatically select the best execution pool according to performance and cost preferences.

### Site Registation

The Ryax Site registration (from the main site to one with a Worker) is now done in the Ryax UI.
This simplifies the Worker configuration make it more secure and fix issues with dynamic registration token.
    
## Bug fixes and Improvements

- Fix unable to create user in the UI
- Centralized Helm repository in ryax-engine so simplify install and development
- Emit Evry and Stop action is now propely stopping in all case
- Fix memory warm start with last successful allocation in Intelliscale
- Reduce Intelliscale recomendation timeout to avoid stall deployment
- Modularize scheduling policies to prepare external policies support

## Upgrade to this version

The Worker that was packaged inside the Ryax installation is now removed and the Worker install will be done separately.
This simplify the configuration and make the Ryax installation independant of user code execution.

To upgrade your main cluster, find the values file from your previous install or restore them using:
```sh
helm get values -n ryaxns ryax --output yaml > values.yaml
```
Then, run the upgrade with :
```sh
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine:26.4.0 \
  -n ryaxns \
  -f values.yaml
```

To restore your local worker, we need to extract the worker config to be able to attach the database to the same volume.
To do so extract the worker values with:
```sh
yq -y .worker ./values.yaml > worker.yaml
```
The new registration mechanism requires you to enter the site and node pools ids.
To do so, edit this file to add the `config.site.id` and the `config.spec.nodePools[].id` ids that
you can find in the Web UI in the Infrastructure view.

Here is an example of configuration:
```yaml
postgresql:
  auth:
    password: KSODJAOPP2
config:
  site:
    id: Site-1777972967-vlyxkb72
    spec:
      nodePools:
      - id: NodePool-1777972967-duf9w7tu
        selector:
          k8s.scaleway.com/pool-name: default
      - id: NodePool-1777984371-q43o0vc6
        selector:
          k8s.scaleway.com/pool-name: small
```
And then run:
```sh
helm install -n ryaxns ryax-worker oci://registry.ryax.org/release-charts/ryax-worker:26.4.0 -f worker.yaml
```

