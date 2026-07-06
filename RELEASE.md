We are proud to announce the release of:

​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​
# Ryax 26.7.0
​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​ ​✨​

## New features

### One Worker chart per site type

The generic `ryax-worker` chart is replaced by one dedicated chart per site type:

- `ryax-worker-k8s` for Kubernetes sites
- `ryax-worker-slurm-ssh` for SLURM HPC sites accessed over SSH

The site type is now determined by the chart you install, which simplifies the
configuration and reduces each Worker's footprint to what its site actually needs.

### IntelliScale on the main site

IntelliScale now runs on the main site as part of the `ryax-engine` chart, instead of
being deployed within each Worker. It consumes execution metrics and publishes resource
recommendations for all sites over the message broker. It is enabled by default and can
be disabled with `intelliscale.enabled=false`.

### Energy-aware scheduling

The scheduler now runs energy models directly so that placement decisions can take the
energy consumption of an execution into account, alongside performance and cost.

## Bug fixes and Improvements

- GPU sharing with [NVIDIA MIG](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/) works again
- Sites and Node Pools can now be activated and deactivated from the UI
- Passwords handled by workflows are now encrypted at rest, with the encryption key automatically provisioned by the Helm chart
- Log collection now uses Grafana Alloy, replacing the deprecated Promtail
- Deployment management moved from the Runner to the Workers to improve the multi-site architecture
- New MOS v1 placement policy and externalized scheduler to support custom scheduling policies
- Memory warm start (bump-up) logic moved from IntelliScale to the Runner for more robust allocations
- Fix Infrastructure view queries
- Studio API migrated to FastAPI
- Numerous dependency upgrades and security fixes across all services

## Upgrade to this version

To upgrade your main cluster, find the values file from your previous install or restore
it using:
```sh
helm get values -n ryaxns ryax --output yaml > values.yaml
```
IntelliScale is now part of the main chart and enabled by default. Also, if your values
customize Promtail (`promtail` section), port that configuration to Grafana Alloy
(`alloy` section).

Then, run the upgrade with:
!!! note  
    `--take-ownership` is required because loki migrate from the worker chart to the ryax one`


```sh
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine:26.7.0 \
  -n ryaxns \
  --take-ownership \
  -f values.yaml
```

To upgrade a Kubernetes Worker, note that the `ryax-worker` chart is replaced by
`ryax-worker-k8s`. First, restore your Worker values with:
```sh
helm get values -n ryaxns ryax-worker --output yaml > worker.yaml
```
Then, remove the `intelliscale`, `loki`, and `promtail` sections from this file if
present: IntelliScale now runs on the main site, and logs are collected by the main
site's Grafana Alloy. Finally, upgrade the release to the new chart:
```sh
helm uninstall -n ryaxns ryax-worker
helm install ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s:26.7.0 \
  -n ryaxns \
  -f worker.yaml
```

If your Worker was attached to a SLURM cluster (using the `hpcOffloading` option of the
old `ryax-worker` chart), it must now be installed from the dedicated
`ryax-worker-slurm-ssh` chart. Follow the
[SLURM_SSH Worker documentation](https://docs.ryax.tech/howto/worker-install.html#slurm_ssh-worker)
to write the new values file, then replace your old Worker with:
```sh
helm uninstall -n ryaxns ryax-worker-hpc
helm install ryax-worker-slurm oci://registry.ryax.org/release-charts/ryax-worker-slurm-ssh:26.7.0 \
  -n ryaxns \
  -f worker.yaml \
  --set-file hpcPrivateKeyFile=./my-ssh-private-key
```

Concerning the GPU sharing with [NVIDIA MIG](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/)
the GPU nodes must now be pre-partitioned into MIG instances by the cluster administrator,
as explained in the new [GPU node pools with MIG](https://docs.ryax.tech/howto/worker-install.html#gpu-node-pools-with-mig)
section of the installation documentation.
