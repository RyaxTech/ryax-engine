# Configure Ryax

To configure Ryax we use a single configuration file that you've created during the [installation of the cluster](../howto/install_ryax_kubernetes.md). You can set the configuration of any services of Ryax in this file of called `values.yaml`.

To set a configuration value for a specific service, add a values section in this service. For example, to set the default idle time before undeploying an Action, set in the `runner` section:

```yaml
runner:
  # undeploy after 10s instead of 300s
  userActionsRetentionTime: 10
```

Then, apply the configuration using Helm. See the [installation documentation](../howto/install_ryax_kubernetes.md#cluster-update)

Some configuration parameters are not exposed in the Helm charts directly. Thus, you can check at the source code in the `/ryax/<service name>/app.py` where all configuration environment variables are defines and add one using the `extraEnv` parameter. For example,
```yaml
runner:
  extraEnv:
    - name: RYAX_SCHEDULER_MAX_ACTION_DEPLOYMENTS
      value: "100"
```

More details on each service configuration on the following sections

## Runner configuration

Configuration parameter of Ryax regarding Action deployment and execution are set in the Runner service configuration under the name `runner`.
See the [Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-runner/-/blob/master/charts/runner/README.md?ref_type=heads) for more details.

## Studio configuration

Configuration parameter of Ryax regarding Workflow edition are set in the Studio service configuration under the name `studio`.
See the [Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-studio/-/blob/master/chart/README.md?ref_type=heads) for more details.

## Worker configuration

There is two type of site, `SLURM_SSH` and `KUBERNETES` with according configuration spec.
Here is a complete configuration for a KUBERNETES site type example with two node pools. Defining the Objective scores (`objectiveScores`) enable scheduling by Objectives (higher is better):
```yaml
config:
  site:
    name: local
    type: KUBERNETES
    spec:
      nodePools:  # list of node pools to be used by Ryax to deploy actions
        - name: gpu-h100
          cpu: 24  # cpu core count per node
          memory: 250G  # memory per node
          gpu: 1  # (Optional) defaults to 0
          time: 1h  # (Optional) maximum time accepted for an action run, unlimited by default
          arch: arm64  # (Optional) hardware architecture, defaults to x86_64
          objectiveScores:  # (Optional) defines static scores used by the scheduler for placement
            cost: 0
            energy: 0
            performance: 100
          selector:  # the Kubernetes nodes labels to select the node pool
            k8s.scaleway.com/pool-name: gpu-h100
          filter_no_gpu_action: true  # (Optional) If set to true (default) the node with GPU will not accept Action that are not explicitly asking for a GPU
        - name: small
          cpu: 4
          memory: 6G
          arch: arm64  # WARNING: Ryax only supports one arch at a time. Each node pool must have the same arch
          objectiveScores:
            cost: 70
            energy: 30
            performance: 80
          selector:
            kubernetes.azure.com/agentpool: default
```
And for SLURM_SSH site type with two partitions and some extra configuration for credentials and cache dir:
```yaml
config:
  site:
    name: Azure-1
    type: SLURM_SSH
    spec:
      credentials:  # Use for SSH connection to the SLURM cluster
        server: hpc.example.com
        username: ryax
        privateKeyFile: ./ryax-hpc.key  # defaults to ~/.ssh/id_rsa
        configFile: ./myconfig  # (Optional) defaults to ~/.ssh/config
      cache_dir: /scratch/ryax  # Use to store Singularity images and action IO. defaults to ~/.ryax_cache
      partitions:  # list of partition to be used by Ryax to deploy Actions (same field as Kubernetes node pools)
        - name: default
          cpu: 2
          memory: 600M
          time: 30s
          gpu: 1
          objectiveScores:
            energy: 100
            cost: 50
            performance: 20
        - name: large
          cpu: 16
          memory: 24G
```

### References

- Step-by-step configuration instructions can be found the [Worker installation Howto](../howto/worker-install.md)
- Worker Helm Chart configuration values can be found in the [Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-runner/-/blob/master/charts/worker/README.md?ref_type=heads)
- Ryax IntelliScale Helm Chart configuration can be found in the [Ryax IntelliScale Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-intelliscale/-/blob/master/chart/README.md?ref_type=heads)
