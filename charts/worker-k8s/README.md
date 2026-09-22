# ryax-worker-k8s

![Version: 26.9.0](https://img.shields.io/badge/Version-26.9.0-informational?style=flat-square) ![AppVersion: 26.9.0](https://img.shields.io/badge/AppVersion-26.9.0-informational?style=flat-square)

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
| config | object | `{"site":{"spec":{"namespace":"{{ .Values.global.ryax.userNamespace }}"}}}` | Ryax Worker configuration use for the registration. See documentation for more details: https://docs.ryax.tech/reference/configuration.html#worker-configuration |

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

### GPU Readiness

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| gpuReadiness | object | `{"conditionType":"nvidia.com/GPUReady","enabled":false,"intervalSeconds":10,"nodeLabelWatcher":{"image":"docker.io/bitnamilegacy/kubectl:1.33","resources":{"limits":{"memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}},"nodeProblemDetector":{"image":"registry.k8s.io/node-problem-detector/node-problem-detector:v0.8.20","resources":{"limits":{"memory":"128Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}},"nodeSelector":{"nvidia.com/gpu.present":"true"},"priorityClassName":null,"probeTimeoutSeconds":10,"taintKey":"readiness.k8s.io/nvidia-gpu-not-ready","tolerations":[{"operator":"Exists"}],"untainter":{"image":"docker.io/bitnamilegacy/kubectl:1.33","requireMigConfigSuccess":true,"resources":{"limits":{"memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}}}` | Gate GPU nodes so that no action pod lands on one before the NVIDIA stack is usable. On a scale-up the kubelet reports Ready long before the driver, the container toolkit, the device plugin and the MIG geometry are in place: a pod scheduled in that window is handed a whole GPU instead of its MIG slice, and nvidia-device-plugin crash-loops with "device 0 has no MIG devices configured" (NVIDIA/gpu-operator#2670).  This is only half of the setup, and the other half is outside this chart:   1. the node pool template must carry the startup taint itself, e.g. for     eksctl: `taints: [{key: readiness.k8s.io/nvidia-gpu-not-ready,     value: pending, effect: NoSchedule}]`;  2. the cluster-autoscaler must be told it is a *startup* taint --     `--startup-taint-prefix=readiness.k8s.io/` (>= 1.36) or     `--startup-taint=readiness.k8s.io/nvidia-gpu-not-ready` -- otherwise it     reads it as permanent and never scales the pool up at all;  3. the GPU Operator must tolerate it, in BOTH `daemonsets.tolerations` and     `node-feature-discovery.worker.tolerations`. Both replace their defaults,     so keep the entries that are already there. Miss the second one and     node-feature-discovery never labels the node `nvidia.com/gpu.present`,     the probe below never runs, and the pool is bricked.  See https://docs.ryax.tech/howto/gpu_node_pools/ |
| gpuReadiness.conditionType | string | `"nvidia.com/GPUReady"` | Node condition the probe publishes and the untainter waits for. |
| gpuReadiness.enabled | bool | `false` | Deploy the gate: a node-problem-detector DaemonSet that publishes the `nvidia.com/GPUReady` node condition, and a controller that removes the startup taint once that condition is True. Off by default -- it does nothing unless the node pools carry the taint, and a tainted pool with this off is a pool that never runs anything. Enable it *before* adding the taint. |
| gpuReadiness.intervalSeconds | int | `10` | How often the probe runs and the untainter polls, in seconds. |
| gpuReadiness.nodeLabelWatcher.image | string | `"docker.io/bitnamilegacy/kubectl:1.33"` | kubectl image of the sidecar that publishes this node's `nvidia.com/mig.config` to the readiness probe. The probe cannot read it itself: the node-problem-detector image ships no HTTP client, and that label is the only place the pool's MIG intent lives -- without it the probe cannot tell "MIG is off for good" on a full-GPU pool from "MIG is not enabled yet" on a MIG one. A full reference on purpose, see nodeProblemDetector.image. |
| gpuReadiness.nodeLabelWatcher.resources | object | `{"limits":{"memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Recommended resource requirement |
| gpuReadiness.nodeProblemDetector.image | string | `"registry.k8s.io/node-problem-detector/node-problem-detector:v0.8.20"` | Image that runs the GPU probe and publishes the node condition. A full reference on purpose: `global.imageRegistry` does not apply to it, so an airgapped install overrides this key with its mirror. |
| gpuReadiness.nodeProblemDetector.resources | object | `{"limits":{"memory":"128Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Recommended resource requirement |
| gpuReadiness.nodeSelector | object | `{"nvidia.com/gpu.present":"true"}` | Nodes the gate looks at. `nvidia.com/gpu.present` is set by the GPU Operator's node-feature-discovery. Set to `null` to run the probe on every node instead, which removes the dependency on node-feature-discovery being able to run on a tainted node at the cost of a privileged pod everywhere. It has to be `null` and not `{}`: Helm deep-merges maps, so an empty map leaves this default in place instead of clearing it. |
| gpuReadiness.priorityClassName | string | `nil` | Priority class for both gate workloads. Left empty it falls back to `priorityClass`. Do NOT set `system-node-critical` here: the Priority admission plugin refuses it outside the kube-system namespace, and the DaemonSet then produces no pod at all. |
| gpuReadiness.probeTimeoutSeconds | int | `10` | How long the probe may take before node-problem-detector gives up on it. A timed-out probe leaves the condition `Unknown`, which the untainter cannot tell apart from "never ready", so do not trim this: `nvidia-smi` on a node whose driver has just loaded is slow. |
| gpuReadiness.taintKey | string | `"readiness.k8s.io/nvidia-gpu-not-ready"` | The startup taint to remove. Must match the taint on the node pool template and the autoscaler's startup-taint flag. |
| gpuReadiness.tolerations | list | `[{"operator":"Exists"}]` | Tolerations for the probe DaemonSet. It exists to run on a node that is by definition still tainted, so it tolerates everything. Narrow it to the taints your GPU pools actually carry if you prefer. |
| gpuReadiness.untainter.image | string | `"docker.io/bitnamilegacy/kubectl:1.33"` | kubectl image of the loop that removes the startup taint. A full reference on purpose, see nodeProblemDetector.image. |
| gpuReadiness.untainter.requireMigConfigSuccess | bool | `true` | Also require `nvidia.com/mig.config.state: success` before releasing a node that carries a `nvidia.com/mig.config` label. This is what the probe cannot check: it sees the geometry that exists, not the one that was asked for, so a node still carrying the previous pool's geometry looks perfectly ready to it. |
| gpuReadiness.untainter.resources | object | `{"limits":{"memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Recommended resource requirement |

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
| databaseURL | string | `nil` | Use this to override the default postgresql database included in the Helm |
| extraEnv | list | `[]` | Add extra environment variables |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| global.ryax.userNamespace | string | `"ryaxns-execs"` |  |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"worker-k8s","tag":"26.9.0"}` | container image name and version |
| internalRegistryOverride | string | `""` | Registry host to pull action images from on this site, replacing the host the Runner recorded in the image reference. Only needed when the kubelet cannot resolve that host, e.g. when the Runner points at the in-cluster registry Service. With the bundled registry and no Ingress, the kubelet reaches it through the NodePort: set this to `127.0.0.1:30012`. Leave empty to pull from the address the Runner provides. |
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
