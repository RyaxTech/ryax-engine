We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.01.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

Optimize the Resources, make Build Simple

## New features

- Ryax Airgap is finally out.
- Ryax Saas version.
- Ryax installation uses now a helm.
- Project navigation has been improved, the ui has now a top bar that enables to switch between your projects.
- For the platform administrators, the 
- Deprecation of ryax-adm.

## Bug fixes and Improvements

- ryax-adm is now deprecated from this release in favor of using helm only.

## Upgrade to this version

### Before you start

Install CRDs for traefik v3 migration.

```shell
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.5/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

First if you have a job on ryaxns named `ryax-studio-scale-down` delete the ryax-studio-scale-down job to avoid imagePullBackOff due the 
sudden decommissioning of bitnami.

```shell
kubectl delete job -n ryaxns ryax-studio-scale-down
```

If your ryax_values.yaml file has an empty `storageClass: """`, remove this entry
and ensure you have one and only one as default.

### Upgrade

Apply the upgrade with adm by changing version to `25.10.0` on values files.
Update all external workers installed by editing the values to use `25.10.0`.
Remove the vpa helm installation.

```shell
helm uninstall -n ryaxns ryax-vpa
```
