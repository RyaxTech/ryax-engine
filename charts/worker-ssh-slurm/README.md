# ryax-worker-slurm-ssh

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

Ryax Worker that manages execution of Actions on SLURM cluster through SSH.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-runner>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/bitnamicharts | postgresql | ~16.7.27 |

## Values

### Ryax

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config | object | `{"site":{"spec":{"credentials":null,"partitions":null}}}` | Ryax Worker configuration use for the registration. See documentation for more details: https://docs.ryax.tech/reference/configuration.html#worker-ssh-slurm-configuration Example: site:   id: Site-iahoindsoia-ae   spec:     credentials:        ...     partitions:     - name: debug       id: NodePool-10I31U3421-azea |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.defaultStorageClass | string | `nil` | Global default StorageClass for Persistent Volume(s) |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.imageRegistry | string | `nil` | Global container image registry |
| global.monitoring.enabled | bool | `false` | Enables service monitoring |
| global.monitoring.otlpEndpoint | string | `""` | Traces collector (Tempo) endpoint Trace collection (disabled if empty) |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |

### Important Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hpcOffloading | bool | `true` | Set as true to enable ssh slurm hpc offloading, will run worker-ssh-slurm container as root so singularity build works without --fakeroot Disable it to avoid running as root inside the container |

### Resource Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| resources | object | `{}` | Recommended resources request This is needed because the Worker build the action using Singularity which requires some memory. Example:   requests:     memory: "4Gi"     cpu: "1000m"   limits:     memory: "4Gi" |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Name of the secret that contains credentials to access the registry hosting Ryax actions. Leave empty to use public access registry Secret must be of type: kubernetes.io/dockerconfigjson |
| affinity | object | `{}` | Add affinity injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) Example:   nodeAffinity:     requiredDuringSchedulingIgnoredDuringExecution:       nodeSelectorTerms:       - matchExpressions:         - key: topology.kubernetes.io/zone           operator: In           values:           - antarctica-east1           - antarctica-west1 |
| apiPort | int | `8084` |  |
| brokerSecret | string | `"ryax-broker-secret"` |  |
| databaseURL | string | `nil` | To override the default posgresql URL. Database URL in a SQLAlchemy compatible format. |
| extraEnv | list | `[]` | Add extra environment variables |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| global.ryax.userNamespace | string | `"ryaxns-execs"` |  |
| hpcConfigFile | string | `nil` | Inject the SSH config to customize the access to the HPC site here with `--set-file` |
| hpcPrivateKeyFile | string | `nil` | Inject the private key to SSH to the HPC site with `--set-file hpcPrivateKeyFile=./my-private.key` |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"worker-ssh-slurm","tag":"26.7.0"}` | container image name and version |
| internalRegistryOverride | string | `"ryax-registry:5000"` | this is used for SLURM_SSH deployment mode on a private network mode. Don't change it unless you know what you are doing |
| logLevel | string | `nil` | log level of the service (override global.ryax.logLevel) |
| metricsPort | int | `8093` |  |
| monitoring.serviceMonitor | object | `{"enabled":false}` | Enable service monitor for prometheus using ServiceMonitor CRD |
| postgresql.auth.database | string | `"worker-ssh-slurm"` |  |
| postgresql.auth.existingSecret | string | `"{{ include \"worker-ssh-slurm.postgresql.secret\" . }}"` |  |
| postgresql.auth.username | string | `"worker-ssh-slurm"` |  |
| postgresql.enabled | bool | `true` | Enables PostgreSQL local database instead of remote or local sqlite |
| postgresql.image.repository | string | `"bitnamilegacy/postgresql"` |  |
| postgresql.metrics.image.repository | string | `"bitnamilegacy/postgres-exporter"` |  |
| postgresql.primary.persistence.size | string | `"1Gi"` |  |
| priorityClass | string | `nil` | Add priority class |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
