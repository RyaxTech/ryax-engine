We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 25.10.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

Optimize the Resources, make Build Simple

## New features

- More robust intelliscale, enhanced detection mechanism
- Improved monitoring
- Built-in action resource usage monitoring
- Track cpu and memory usage per execution
- Several features to enhance multi objective scheduling

## Bug fixes and Improvements

- Bug that made worker create queues indefinitely in some situations
- Fix sudden decomissioning of bitnami repo
- Prevent builder failure when the wrapper git reference is unavailable
- Fix builder persitency that was making automatically garbage collection fails
- Fixed bug that let actions build stuck on starting state
- Switch to uv for python packaging
- Upgrade to traefik 3

## Upgrade to this version

### Before you start

First delete the ryax-studio-scale-down job to avoid imagePullBackOff due the 
Install CRDs for traefik v3 migration.

```shell
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.5/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```
First if you have a job on ryaxns named `ryax-studio-scale-down` delete the ryax-studio-scale-down job to avoid imagePullBackOff due the 
sudden decommissioning of bitnami.

```shell
kubectl delete job -n ryaxns ryax-studio-scale-down
```

### Upgrade

Apply the upgrade with adm by changing version to `25.10.0` on values files.
Update all external workers installed by editing the values to use `25.10.0`.
Remove the vpa helm installation.

```shell
helm uninstall -n ryaxns ryax-vpa
```

