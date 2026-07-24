# Configure Ryax

To configure Ryax we use a single configuration file that you've created during the [installation of the cluster](../howto/install_ryax_kubernetes.md). You can set the configuration of any services of Ryax in the Helm configuration file.
Then, apply the configuration using `helm upgrade`.
See the [installation documentation](../howto/install_ryax_kubernetes.md#cluster-update) for more details.

Some configuration parameters are exposed in the Helm charts directly. For example you can set the user action default log level with:
```yaml
runner:
  defaultActionLogLevel: "debug"
```

For advanced configuration, you can look at the source code in `/ryax/<service name>/app.py` where all configuration environment variables are defined and add one using the `extraEnv` parameter in your values. For example,
```yaml
runner:
  extraEnv:
    - name: RYAX_LOGS_KUBERNETES
      value: "debug"
```

More details on each service configuration on the following sections.

## Runner configuration

Configuration parameters of Ryax regarding Workflow execution are set in the Runner service configuration under the name `runner`.
See the [Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/tree/master/charts/ryax/subcharts/runner?ref_type=heads) for more details.

## Studio configuration

Configuration parameters of Ryax regarding Workflow edition are set in the Studio service configuration under the name `studio`.
See the [Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-studio/-/blob/master/chart/README.md?ref_type=heads) for more details.

## IntelliScale configuration

Ryax IntelliScale provides resource recommendations to the Runner so Actions use the minimum amount of resources.
Helm Chart configuration can be found in the [Ryax IntelliScale Helm chart documentation](https://gitlab.com/ryax-tech/ryax/ryax-intelliscale/-/blob/master/chart/README.md?ref_type=heads)

## Workers configuration

Ryax workers register a *Site* with Ryax. There are two site types, each handled by its own dedicated Worker Helm chart:

- `KUBERNETES` sites are handled by the `ryax-worker-k8s` chart (documented below).
- `SLURM_SSH` sites are handled by the `ryax-worker-slurm-ssh` chart (see [Worker SSH SLURM configuration](#worker-ssh-slurm-configuration)).

The site type is determined by the Worker chart you install, so it is not part of the configuration.

Step-by-step configuration instructions can be found in the [Worker installation Howto](../howto/worker-install.md).

The Worker Helm chart configuration values, depending on the Worker type, can be found in:

- Kubernetes Worker: [`ryax-worker-k8s` chart](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/blob/master/charts/worker-k8s/README.md?ref_type=heads)
- Slurm over SSH Worker: [`ryax-worker-slurm-ssh` chart](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/blob/master/charts/worker-ssh-slurm/README.md?ref_type=heads)


## Worker Kubernetes configuration

Here is a complete configuration for a KUBERNETES site type example with two node pools.
```yaml
config:
  site:
    id: Site-173885748-ijdij
    spec:
      nodePools:  # list of node pools to be used by Ryax to deploy actions
        - id: NodePool-176373899-akoks
          selector:  # the Kubernetes nodes labels to select the node pool
            k8s.scaleway.com/pool-name: gpu-h100
        - id: NodePool-18939392-ahal
          selector:
            kubernetes.azure.com/agentpool: default
```

## Worker SSH SLURM configuration

Configuration for a `SLURM_SSH` site type with two partitions and some extra configuration for credentials and cache dir (partitions use the same fields as the Kubernetes node pools above):
```yaml
config:
  site:
    id: Site-183948493-aiijd
    spec:
      credentials:  # Use for SSH connection to the SLURM cluster
        server: hpc.example.com
        username: ryax
        privateKeyFile: ./ryax-hpc.key  # defaults to ~/.ssh/id_rsa
        configFile: ./myconfig  # (Optional) defaults to ~/.ssh/config
      cache_dir: /scratch/ryax  # (Optional) Used to store Singularity images and action IO. Defaults to ~/.ryax_cache
      partitions:  # list of partition to be used by Ryax to deploy Actions
        - id: NodePool-128394739-gadhj
          name: default # The name of the partition in Slurm
        - id: NodePool-128391092-aokde
          name: large
```

