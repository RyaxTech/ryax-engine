# worker

![Version: 0.0.0-dev](https://img.shields.io/badge/Version-0.0.0--dev-informational?style=flat-square) ![AppVersion: SERVICE-VERSION](https://img.shields.io/badge/AppVersion-SERVICE--VERSION-informational?style=flat-square)

The Ryax Worker service manages the deployment and the execution of Actions on each site.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-runner>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://grafana.github.io/helm-charts | loki | ~6.16.0 |
| https://grafana.github.io/helm-charts | promtail | ~6.16.6 |
| oci://registry-1.docker.io/bitnamicharts | postgresql | ~16.1.2 |
| oci://registry.ryax.org/release-charts | intelliscale | 26.1.x |

## Values

### Ryax User Actions Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| actionLogsQueryRate | int | `5` | Rate at which the User Action logging system is queried to get the logs in seconds. |
| userActionResources | object | `{"limit":{"memory":"64Mi"},"request":{"cpu":0.1,"memory":"64Mi"}}` | Resource limit and request for individual user actions if not set in the action `resources` section. Requires a LimitRange Kubernetes object. See for more details: https://kubernetes.io/docs/concepts/policy/limit-range/ |

### Ryax

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| config | object | `{"site":{"spec":{"namespace":"{{ .Values.global.ryax.userNamespace }}"},"type":"KUBERNETES"}}` | Ryax Worker configuration use for the registration. See documentation for more details: https://docs.ryax.tech/reference/configuration.html#worker-configuration |

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
| hpcOffloading | bool | `true` | Set as true to enable ssh slurm hpc offloading, will run worker container as root so singularity build works without --fakeroot Disable it to avoid running as root inside the container |

### Resource Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| hpcResources | object | `{}` | Default resources request when enabling `hpcOffloading` This is needed because the Runner build the action using Singularity which requires more memory. Example:   requests:     memory: "4Gi"     cpu: "1000m"   limits:     memory: "4Gi" |
| resources | object | `{}` | Recommended resource requirement Example:   requests:     memory: "2Gi"     cpu: "1000m"   limits:     memory: "2Gi" |
| userNamespaceResources | object | `{}` | Activate this to limit users' resource total usage. Highly recommended in production! Resource quota for the user namespace set as-is in the Kubernetes ResourceQuota: Example:   requests.cpu: "2"   requests.memory: 2Gi   limits.cpu: "16"   limits.memory: 32Gi See for more details: https://kubernetes.io/docs/concepts/policy/resource-quotas/ |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Name of the secret that contains credentials to access the registry hosting Ryax actions. Leave empty to use public access registry Secret must be of type: kubernetes.io/dockerconfigjson |
| affinity | object | `{}` | Add affinity injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) Example:   nodeAffinity:     requiredDuringSchedulingIgnoredDuringExecution:       nodeSelectorTerms:       - matchExpressions:         - key: topology.kubernetes.io/zone           operator: In           values:           - antarctica-east1           - antarctica-west1 |
| apiPort | int | `8880` |  |
| brokerSecret | string | `"ryax-broker-secret"` |  |
| databaseURL | string | `nil` | Database URL in a SQLAlchemy compatible format. If you choose SQLite, be sure to enable persistence so the /data/db is preserved on restart example: "sqlite:////data/db/ryax-worker.db" WARNING: only use sqlite for testing or for very light usage, or you will face "database is locked" errors. |
| datastoreSecret | string | `nil` | Datastore secret: if set, use the Ryax internal database instead the local one You should disable persistence when enabling this |
| extraEnv | list | `[]` | Add extra environment variables |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| global.ryax.userNamespace | string | `"ryaxns-execs"` |  |
| hpcConfigFile | string | `nil` | Inject the SSH config to customize the access to the HPC site here with `--set-file` |
| hpcPrivateKeyFile | string | `nil` | Inject the private key to SSH to the HPC site with `--set-file hpcPrivateKeyFile=./my-private.key` |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"worker","tag":"SERVICE-VERSION"}` | container image name and version |
| intelliscale.enabled | bool | `true` |  |
| intelliscale.ryax.worker.configMapName | string | `"{{ .Release.Name }}-worker-config"` |  |
| intelliscale.ryax.worker.serviceName | string | `"{{ .Release.Name }}-worker"` |  |
| internalRegistryOverride | string | `"ryax-registry:5000"` | this is used for SLURM_SSH deployment mode on a private network mode. Don't change it unless you know what you are doing |
| logLevel | string | `nil` | log level of the service (override global.ryax.logLevel) |
| loki | object | `{"backend":{"replicas":0},"chunksCache":{"enabled":false},"deploymentMode":"SingleBinary","enabled":true,"gateway":{"enabled":false},"loki":{"auth_enabled":false,"commonConfig":{"replication_factor":1},"extraMemberlistConfig":{"bind_addr":["${POD_IP}"]},"limits_config":{"retention_period":"7d"},"query_scheduler":{"max_outstanding_requests_per_tenant":2048},"schemaConfig":{"configs":[{"from":"2024-01-01","index":{"period":"24h","prefix":"loki_index_"},"object_store":"filesystem","schema":"v13","store":"tsdb"}]},"server":{"log_level":"warn"},"storage":{"type":"filesystem"}},"lokiCanary":{"enabled":false},"read":{"replicas":0},"resultsCache":{"enabled":false},"singleBinary":{"extraArgs":["-config.expand-env=true"],"extraEnv":[{"name":"POD_IP","valueFrom":{"fieldRef":{"fieldPath":"status.podIP"}}}],"replicas":1,"resources":{"limits":{"cpu":1,"memory":"512Mi"},"requests":{"cpu":0.5,"memory":"512Mi"}}},"test":{"enabled":false},"write":{"replicas":0}}` | Loki is an extrenal dependency that provide log collection on Kubernetes. Disable this if the site type is different from KUBERNETES |
| metricsPort | int | `8090` |  |
| monitoring.datasource | object | `{"enabled":true}` | Grafana datasource for loki |
| monitoring.serviceMonitor | object | `{"enabled":true}` | Enable service monitor for prometheus using ServiceMonitor CRD |
| persistence | object | `{"accessMode":"ReadWriteOnce","annotations":{},"enabled":false,"size":"1Gi"}` | Only necessary for SQLite database in /data/db, Disabled by default WARNING: only use sqlite for testing or for very light usage, or you will face "database is locked" errors. |
| persistence.accessMode | string | `"ReadWriteOnce"` | Database data Persistent Volume Storage Class If defined, storageClassName: <storageClass> If set to "-", storageClassName: "", which disables dynamic provisioning If undefined (the default) or set to null, no storageClassName spec is set, choosing the default provisioner.  Example: storageClass: "-" |
| postgresql | object | `{"auth":{"database":"worker","existingSecret":"{{ include \"worker.postgresql.secret\" . }}","username":"worker"},"enabled":true,"image":{"repository":"bitnamilegacy/postgresql"},"metrics":{"image":{"repository":"bitnamilegacy/postgres-exporter"}},"nameOverride":"worker-postgresql","primary":{"persistence":{"size":"1Gi"}}}` | local postgresql database |
| postgresql.enabled | bool | `true` | Enables PostgreSQL local database instead of remote or local sqlite |
| priorityClass | string | `nil` | Add priority class |
| promtail.config.clients[0].url | string | `"{{ printf \"http://%s-loki:3100/loki/api/v1/push\" .Release.Name }}"` |  |
| promtail.config.snippets.extraRelabelConfigs[0].action | string | `"labelmap"` |  |
| promtail.config.snippets.extraRelabelConfigs[0].regex | string | `"__meta_kubernetes_pod_label_(.+)"` |  |
| promtail.config.snippets.extraRelabelConfigs[1].action | string | `"labeldrop"` |  |
| promtail.config.snippets.extraRelabelConfigs[1].regex | string | `"app_kubernetes_io_(.+)"` |  |
| promtail.serviceMonitor.enabled | bool | `false` |  |
| promtail.tolerations[0].effect | string | `"NoSchedule"` |  |
| promtail.tolerations[0].operator | string | `"Exists"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
