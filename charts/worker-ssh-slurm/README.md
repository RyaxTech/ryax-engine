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
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override per subchart with its own `affinity`. |
| global.defaultStorageClass | string | `nil` | Global default StorageClass for Persistent Volume(s) |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.imageRegistry | string | `nil` | Global container image registry |
| global.monitoring.enabled | bool | `false` | Enables service monitoring |
| global.monitoring.otlpEndpoint | string | `""` | Traces collector (Tempo) endpoint Trace collection (disabled if empty) |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| global.secrets | object | `{"create":true}` | Credential secrets the chart generates itself (database, broker, JWT, encryption keys, registry htpasswd and TLS). Set to false to supply every one of them yourself -- sealed-secrets, external-secrets, or a plain kubectl create -- under the names listed in the values below. This is what a GitOps deployment wants: the generated values come from `lookup()`, which returns nothing when the chart is rendered without a cluster connection (`helm template`, ArgoCD's and Flux's repo servers), so every render would otherwise mint fresh passwords and roll them out to running pods. |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Required to run Ryax on tainted nodes; override per subchart with its own `tolerations`. Example:   - key: mycompany/mesh     operator: Exists     effect: NoSchedule |

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
| affinity | object | `{}` |  |
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
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| postgresql.auth | object | `{"createSecret":true,"database":"worker-ssh-slurm","existingSecret":"{{ include \"worker-ssh-slurm.postgresql.secret\" . }}","username":"worker-ssh-slurm"}` | The bundled PostgreSQL is an upstream Bitnami subchart: it does not read `global.tolerations`, so a tainted node needs its placement set here, e.g.   primary:     tolerations: [...]     nodeSelector: {...} |
| postgresql.auth.createSecret | bool | `true` | Create the database credentials secret named by `existingSecret` below. Set to false to provide it yourself; it must then carry the keys `password`, `postgres-password` and `datastore-worker-ssh-slurm`. |
| postgresql.enabled | bool | `true` | Enables PostgreSQL local database instead of remote or local sqlite |
| postgresql.image.repository | string | `"bitnamilegacy/postgresql"` |  |
| postgresql.metrics.image.repository | string | `"bitnamilegacy/postgres-exporter"` |  |
| postgresql.primary.persistence.size | string | `"1Gi"` |  |
| priorityClass | string | `nil` | Add priority class |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
