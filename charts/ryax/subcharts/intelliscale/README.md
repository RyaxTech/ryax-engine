# intelliscale

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

Ryax Intelliscale, the AI-empowered vertical autoscaler for Ryax action executions

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-intelliscale>

## Values

### Ryax

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| brokerSecret | string | `"ryax-broker-secret"` | Name of the secret holding the central RabbitMQ broker URL (key "broker"). IntelliScale runs at the master site and consumes execution metrics / publishes recommendations over the broker (multi-site mode) in addition to the legacy per-site gRPC interface. Set to "" to disable the broker interface (legacy gRPC-only). |
| global.ryax.logLevel | string | `nil` | Global Ryax log level to use, ignored if empty |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override per subchart with its own `affinity`. |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.imageRegistry | string | `nil` | Global container image registry |
| global.monitoring.enabled | bool | `false` | Enables service monitoring |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| global.secrets | object | `{"create":true}` | Credential secrets the chart generates itself (database, broker, JWT, encryption keys, registry htpasswd and TLS). Set to false to supply every one of them yourself -- sealed-secrets, external-secrets, or a plain kubectl create -- under the names listed in the values below. This is what a GitOps deployment wants: the generated values come from `lookup()`, which returns nothing when the chart is rendered without a cluster connection (`helm template`, ArgoCD's and Flux's repo servers), so every render would otherwise mint fresh passwords and roll them out to running pods. |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Required to run Ryax on tainted nodes; override per subchart with its own `tolerations`. Example:   - key: mycompany/mesh     operator: Exists     effect: NoSchedule |

### Required for Production

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| resources | object | `{}` | Recommended resource requirement WARNING: This must be set in production ! Recomended values:  limits:    cpu: 150m    memory: 350Mi  requests:    cpu: 120m    memory: 300Mi |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| config | object | `{"MIG":{"enabled":true},"algorithm_configs":{"memory_oom_processor":{"bump_up_ratio":2},"simple_mig_recommender":{"gpu_mig_instance":{"a":100,"b":200}},"vpa_pilot_rule":{"cpu_limit":{"data_source":"max","fluctuation_reducer_duration_in_seconds":3600,"max_range_samples":10,"policy":"max","safety_margin_lower":0.2,"safety_margin_upper":0.3,"weighted_avg_decay_half_life_in_seconds":43200},"cpu_request":{"data_source":"sp_95","fluctuation_reducer_duration_in_seconds":3600,"max_range_samples":10,"policy":"weighted_avg","safety_margin_lower":0.1,"safety_margin_upper":0.15,"weighted_avg_decay_half_life_in_seconds":43200},"memory":{"data_source":"sp_98","fluctuation_reducer_duration_in_seconds":3600,"max_range_samples":10,"policy":"max","safety_margin_lower":0.1,"safety_margin_upper":0.15,"weighted_avg_decay_half_life_in_seconds":43200}}},"message_bus":{"keep_event_history":false},"otlp_endpoint":"tempo:4317","server_ports":{"api_grpc_server_port":8326,"metrics_server_port":8090}}` | Intelliscalse configuration |
| fullnameOverride | string | `""` |  |
| global.monitoring.otlpEndpoint | string | `""` |  |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io","repository":"ryaxtech/intelliscale","tag":"26.7.0"}` | container image name and version |
| imagePullSecrets | list | `[]` | This is for the secretes for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| nameOverride | string | `""` | This is to override the chart name. |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| priorityClass | string | `nil` | Deployment prority class |
| probes | object | `{"liveness":{"failureThreshold":3,"periodSeconds":30,"timeoutSeconds":5},"readiness":{"failureThreshold":3,"periodSeconds":20,"timeoutSeconds":5},"startup":{"failureThreshold":30,"periodSeconds":6,"timeoutSeconds":5}}` | Probe timings for the IntelliScale container. The startup probe gives the process room to connect to the broker and bind its metrics port before liveness starts counting: `startup.periodSeconds * startup.failureThreshold` is the budget (default 3 minutes). |
| tolerations | list | `[]` | Add theses toleration to the deployment   |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
