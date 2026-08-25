# ryax-worker-k8s

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

The Ryax Worker service manages deployments and executions on Kubernetes

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-runner>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/bitnamicharts | postgresql | ~16.7.27 |

## Values

### Ryax User Actions Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| actionLogsQueryRate | int | `5` | Rate at which the User Action logging system is queried to get the logs in seconds. |
| userActionResources | object | `{"limit":{"memory":"64Mi"},"request":{"cpu":0.1,"memory":"64Mi"}}` | Resource limit and request for individual user actions if not set in the action `resources` section. Requires a LimitRange Kubernetes object. See for more details: https://kubernetes.io/docs/concepts/policy/limit-range/ |

### Ryax

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config | object | `{"MIG":{"enabled":true},"site":{"spec":{"namespace":"{{ .Values.global.ryax.userNamespace }}"}}}` | Ryax Worker configuration use for the registration. See documentation for more details: https://docs.ryax.tech/reference/configuration.html#worker-configuration |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override per subchart with its own `affinity`. |
| global.defaultStorageClass | string | `nil` | Global default StorageClass for Persistent Volume(s) |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.imageRegistry | string | `nil` | Global container image registry |
| global.monitoring.enabled | bool | `false` | Enables service monitoring |
| global.monitoring.otlpEndpoint | string | `"ryax-tempo:4317"` | Traces collector (Tempo) endpoint Trace collection (disabled if empty) |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| global.secrets | object | `{"create":true}` | Credential secrets the chart generates itself (database, broker, JWT, encryption keys, registry htpasswd and TLS). Set to false to supply every one of them yourself -- sealed-secrets, external-secrets, or a plain kubectl create -- under the names listed in the values below. This is what a GitOps deployment wants: the generated values come from `lookup()`, which returns nothing when the chart is rendered without a cluster connection (`helm template`, ArgoCD's and Flux's repo servers), so every render would otherwise mint fresh passwords and roll them out to running pods. |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Required to run Ryax on tainted nodes; override per subchart with its own `tolerations`. Example:   - key: mycompany/mesh     operator: Exists     effect: NoSchedule |

### Resource Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| resources | object | `{}` | Recommended resource requirement Example:   requests:     memory: "2Gi"     cpu: "1000m"   limits:     memory: "2Gi" |
| userNamespaceResources | object | `{}` | Activate this to limit users' resource total usage. Highly recommended in production! Resource quota for the user namespace set as-is in the Kubernetes ResourceQuota: Example:   requests.cpu: "2"   requests.memory: 2Gi   limits.cpu: "16"   limits.memory: 32Gi See for more details: https://kubernetes.io/docs/concepts/policy/resource-quotas/ |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Name of the secret that contains credentials to access the registry hosting Ryax actions. Leave empty to use public access registry Secret must be of type: kubernetes.io/dockerconfigjson |
| affinity | object | `{}` |  |
| apiPort | int | `8083` |  |
| brokerSecret | string | `"ryax-broker-secret"` |  |
| config.MIG | object | `{"enabled":true}` | Enable NVIDIA MIG auto-labeler that partition the supported NVIDIA cards  |
| databaseURL | string | `nil` | Use this to override the default postgresql database included in the Helm |
| extraEnv | list | `[]` | Add extra environment variables |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| global.ryax.userNamespace | string | `"ryaxns-execs"` |  |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"worker-k8s","tag":"26.7.0"}` | container image name and version |
| labeler | object | `{"image":"bitnamilegacy/kubectl:latest","pauseImage":"k8s.gcr.io/pause:3.1"}` | Container images used by the labeler daemonSet |
| logLevel | string | `nil` | log level of the service (override global.ryax.logLevel) |
| metricsPort | int | `8092` |  |
| monitoring.serviceMonitor | object | `{"enabled":true}` | Enable service monitor for prometheus using ServiceMonitor CRD |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| postgresql | object | `{"auth":{"createSecret":true,"database":"worker_k8s","existingSecret":"{{ include \"worker-k8s.postgresql.secret\" . }}","username":"worker_k8s"},"enabled":true,"image":{"repository":"bitnamilegacy/postgresql"},"metrics":{"image":{"repository":"bitnamilegacy/postgres-exporter"}},"primary":{"persistence":{"size":"1Gi"}}}` | local postgresql database |
| postgresql.auth | object | `{"createSecret":true,"database":"worker_k8s","existingSecret":"{{ include \"worker-k8s.postgresql.secret\" . }}","username":"worker_k8s"}` | The bundled PostgreSQL is an upstream Bitnami subchart: it does not read `global.tolerations`, so a tainted node needs its placement set here, e.g.   primary:     tolerations: [...]     nodeSelector: {...} |
| postgresql.auth.createSecret | bool | `true` | Create the database credentials secret named by `existingSecret` below. Set to false to provide it yourself; it must then carry the keys `password`, `postgres-password` and `datastore-worker-k8s`. |
| postgresql.enabled | bool | `true` | Enables PostgreSQL local database |
| priorityClass | string | `nil` | Add priority class |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
