# runner

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

The Ryax Runner service orchestrates the deployment and the execution of Actions inside Ryax.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-runner>

## Values

### Ryax User Actions Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| defaultActionLogLevel | string | `"info"` | User actions log level |
| userActionsRetentionTime | int | `30` | Set the retention time after an execution in seconds. Ryax Actions are kept for this amount of time waiting for new execution before undeploying to avoid cold start Note: For more settings, you can use extraEnv wth environment variables defined in ryax/runner/app.py |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override per subchart with its own `affinity`. |
| global.defaultStorageClass | string | `nil` | Global default StorageClass for Persistent Volume(s) |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.imageRegistry | string | `nil` | Global container image registry |
| global.ingress.className | string | `""` | IngressClass the Ingress of this service targets, overridden by the local `ingress.className`. The umbrella chart points it at the bundled Traefik; empty means no class, i.e. whichever controller claims the cluster's default. WARN: templated with the release name, render it through tpl |
| global.monitoring.enabled | bool | `false` | Enables service monitoring |
| global.monitoring.otlpEndpoint | string | `""` | Traces collector (Tempo) endpoint Trace collection (disabled if empty) |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| global.secrets | object | `{"create":true}` | Credential secrets the chart generates itself (database, broker, JWT, encryption keys, registry htpasswd and TLS). Set to false to supply every one of them yourself -- sealed-secrets, external-secrets, or a plain kubectl create -- under the names listed in the values below. This is what a GitOps deployment wants: the generated values come from `lookup()`, which returns nothing when the chart is rendered without a cluster connection (`helm template`, ArgoCD's and Flux's repo servers), so every render would otherwise mint fresh passwords and roll them out to running pods. |
| global.tls.enabled | bool | `false` | Enables TLS for ingress |
| global.tls.environment | string | `"development"` | In production to get a valid certificat from let's encrypt, otherwise use the staging Let's encrypt cluster to avoid rate limit Should be: development or production |
| global.tls.existingCertificatSecret | string | `nil` | for self hosted instance with intenal TLS certificate |
| global.tls.hostname | string | `nil` | The Ryax cluster name, must be a valid DNS |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Required to run Ryax on tainted nodes; override per subchart with its own `tolerations`. Example:   - key: mycompany/mesh     operator: Exists     effect: NoSchedule |

### Ryax

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.ryax.userNamespace | string | `"ryaxns-execs"` | Namespace where user's actions are deployed |

### Resource Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| resources | object | `{}` | Recommended resource requirement WARNING: This must be set in production ! Example:   requests:     memory: "2Gi"     cpu: "1000m"   limits:     memory: "2Gi" |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| apiPort | int | `8080` |  |
| authorizationUrl | string | `"ryax-authorization:8080"` |  |
| baseApiUrl | string | `"runner"` | Necessary to make the swagger interactive docs to show up properly |
| billing.enabled | bool | `false` |  |
| brokerSecret | string | `"ryax-broker-secret"` |  |
| datastoreSecret | string | `"ryax-datastore-secret"` |  |
| encryptionKeySecret | string | `"runner-encryption-key"` |  |
| encryptionKeySecretCreate | bool | `true` | Create the secret above. Set to false to provide it yourself; it must then carry the key(s): encryption-key. |
| extraEnv | list | `[]` | Add extra environment variables |
| fernetEncryptionKey | string | `nil` | You can set this by generating a Key with this script:    ```python3    #!/usr/bin/env python3    import base64    import os     print(base64.urlsafe_b64encode(os.urandom(32)).decode())    ``` |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"runner","tag":"26.7.0"}` | container image name and version |
| ingress.className | string | `""` | Value for `spec.ingressClassName`. Left empty, the Ingress is claimed by whichever IngressClass is marked default in the cluster -- which is a cluster-wide setting, not this chart's to rely on. |
| ingress.enabled | bool | `true` | Render an Ingress for this service. Turn it off when routing is handled outside the chart -- Gateway API, a service mesh, an external load balancer. With no controller to fill in `.status.loadBalancer`, a GitOps engine that health-checks Ingresses reports them Progressing forever and parks the sync. |
| internalRegistry | string | `"127.0.0.1:30012"` |  |
| jwtSecret | string | `"api-jwt-secret-key"` |  |
| logLevel | string | `nil` | log level of the service (overide global.ryax.logLevel) |
| metricsPort | int | `8090` |  |
| monitoring.dashboards.enabled | bool | `true` | Enables the injection of a grafana dashboard. |
| monitoring.serviceMonitor.enabled | bool | `true` | Enable service monitor for prometheus. Requires ServiceMonitor CRD |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| priorityClass | string | `nil` | Deployment prority class |
| releaseMarker | string | `"ryax-release-marker"` | Name of the ConfigMap that marks the release as installed. The database-migration hooks read it and skip themselves when it is absent, so a first sync cannot deadlock on a database that does not exist yet. Created by the common-resources subchart. |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). |
| upgradeJob.image | string | `"docker.io/bitnamilegacy/kubectl:1.33"` |  |
| userAPIPort | int | `10080` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
