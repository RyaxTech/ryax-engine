# ryax-worker-coelivia

![Version: 26.9.0](https://img.shields.io/badge/Version-26.9.0-informational?style=flat-square) ![AppVersion: 26.9.0](https://img.shields.io/badge/AppVersion-26.9.0-informational?style=flat-square)

Ryax Worker that manages execution of Actions on an HPC cluster through the Coelivia API.

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
| config | object | `{"site":{"spec":{"credentials":null,"partitions":null}}}` | Ryax Worker configuration use for the registration. See documentation for more details: https://docs.ryax.tech/reference/configuration.html#worker-coelivia-configuration `credentials.api_url` is required. `token`, `biscuit` and `system` are optional: an execution usually authenticates with the Biscuit passed in its `hpc` addon parameters, and without `system` the first system the API returns is used. Example: site:   id: Site-iahoindsoia-ae   spec:     credentials:       api_url: https://coelivia.example.com/api     partitions:     - name: debug       id: NodePool-10I31U3421-azea |

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
| hpcOffloading | bool | `true` | Set as true to enable hpc offloading, will run worker-coelivia container as root so singularity build works without --fakeroot Disable it to avoid running as root inside the container |

### Resource Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| resources | object | `{}` | Recommended resources request This is needed because the Worker build the action using Singularity which requires some memory. Example:   requests:     memory: "4Gi"     cpu: "1000m"   limits:     memory: "4Gi" |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Name of the secret that contains credentials to access the registry hosting Ryax actions. Leave empty to use public access registry Secret must be of type: kubernetes.io/dockerconfigjson |
| affinity | object | `{}` |  |
| apiPort | int | `8085` |  |
| biscuitPublicKey | string | `""` | Ed25519 public key (hex) of the Coelivia token-proxy. The worker uses it to verify the Biscuit of an execution and read its user, which gives the job HOME (`/home/{user}`). Leave empty to skip the verification. |
| brokerSecret | string | `"ryax-broker-secret"` |  |
| databaseURL | string | `nil` | To override the default posgresql URL. Database URL in a SQLAlchemy compatible format. |
| extraEnv | list | `[]` | Add extra environment variables |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| global.ryax.userNamespace | string | `"ryaxns-execs"` |  |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"registry.ryax.org/dev","repository":"worker-coelivia","tag":"26.9.0"}` | container image name and version. The Coelivia worker image is only published to the development registry for now; switch to docker.io/ryaxtech once ryax-core releases it to Docker Hub. |
| internalRegistryOverride | string | `""` | Registry host to pull action images from on this site, replacing the host the Runner recorded in the image reference. Only needed when that host is not reachable from the worker: set it to the in-cluster registry Service, `ryax-registry:5000`. Leave empty to pull from the address the Runner provides. |
| logLevel | string | `nil` | log level of the service (override global.ryax.logLevel) |
| metricsPort | int | `8094` |  |
| monitoring.serviceMonitor | object | `{"enabled":false}` | Enable service monitor for prometheus using ServiceMonitor CRD |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| postgresql.auth | object | `{"createSecret":true,"database":"worker-coelivia","existingSecret":"{{ include \"worker-coelivia.postgresql.secret\" . }}","username":"worker-coelivia"}` | The bundled PostgreSQL is an upstream Bitnami subchart: it does not read `global.tolerations`, so a tainted node needs its placement set here, e.g.   primary:     tolerations: [...]     nodeSelector: {...} |
| postgresql.auth.createSecret | bool | `true` | Create the database credentials secret named by `existingSecret` below. Set to false to provide it yourself; it must then carry the keys `password`, `postgres-password` and `datastore-worker-coelivia`. |
| postgresql.enabled | bool | `true` | Enables PostgreSQL local database instead of remote or local sqlite |
| postgresql.image.repository | string | `"bitnamilegacy/postgresql"` |  |
| postgresql.metrics.image.repository | string | `"bitnamilegacy/postgres-exporter"` |  |
| postgresql.primary.persistence.size | string | `"1Gi"` |  |
| priorityClass | string | `nil` | Add priority class |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
