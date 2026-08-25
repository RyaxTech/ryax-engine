# ryax-engine

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

Ryax is a open-source Hybrid workflow orchestrator to optimize your AI workflows and applications on multiple infrastructure.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-engine>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://subcharts/action-builder | action-builder | 26.7.0 |
| file://subcharts/authorization | authorization | 26.7.0 |
| file://subcharts/common-resources | common-resources | 26.7.0 |
| file://subcharts/datastore | datastore | 26.7.0 |
| file://subcharts/front | front | 26.7.0 |
| file://subcharts/intelliscale | intelliscale | 26.7.0 |
| file://subcharts/registry | registry | 26.7.0 |
| file://subcharts/repository | repository | 26.7.0 |
| file://subcharts/runner | runner | 26.7.0 |
| file://subcharts/studio | studio | 26.7.0 |
| https://grafana.github.io/helm-charts | alloy | ~1.12.0 |
| https://grafana.github.io/helm-charts | loki | ~7.3.0 |
| https://grafana.github.io/helm-charts | tempo | 1.x.x |
| https://helm.traefik.io/traefik | traefik | 41.x.x |
| https://prometheus-community.github.io/helm-charts | kube-prometheus-stack | 88.x.x |
| oci://registry-1.docker.io/bitnamicharts | minio | 17.x.x |
| oci://registry-1.docker.io/bitnamicharts | rabbitmq | 16.x.x |

## Values

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override per subchart with its own `affinity`. |
| global.secrets | object | `{"create":true}` | Credential secrets the chart generates itself (database, broker, JWT, encryption keys, registry htpasswd and TLS). Set to false to supply every one of them yourself -- sealed-secrets, external-secrets, or a plain kubectl create -- under the names listed in the values below. This is what a GitOps deployment wants: the generated values come from `lookup()`, which returns nothing when the chart is rendered without a cluster connection (`helm template`, ArgoCD's and Flux's repo servers), so every render would otherwise mint fresh passwords and roll them out to running pods. |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Required to run Ryax on tainted nodes; override per subchart with its own `tolerations`. Example:   - key: mycompany/mesh     operator: Exists     effect: NoSchedule |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| action-builder.actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Only necessary if registry.credentials.enabled=true |
| action-builder.nix.storeSize | string | `"100Gi"` |  |
| action-builder.persitence.enabled | bool | `true` |  |
| action-builder.priorityClass | string | `"microservices"` |  |
| alloy | object | `{"alloy":{"configMap":{"content":"// Collect logs only from the pods of the node Alloy runs on.\n// K8S_NODE_NAME is set by the Alloy chart.\ndiscovery.kubernetes \"pods\" {\n  role = \"pod\"\n  selectors {\n    role  = \"pod\"\n    field = \"spec.nodeName=\" + sys.env(\"K8S_NODE_NAME\")\n  }\n}\n\ndiscovery.relabel \"pod_logs\" {\n  targets = discovery.kubernetes.pods.targets\n\n  rule {\n    source_labels = [\"__meta_kubernetes_namespace\"]\n    target_label  = \"namespace\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_name\"]\n    target_label  = \"pod\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_container_name\"]\n    target_label  = \"container\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_node_name\"]\n    target_label  = \"node_name\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_namespace\", \"__meta_kubernetes_pod_name\"]\n    separator     = \"/\"\n    target_label  = \"job\"\n  }\n  // Map the pod labels then drop some to avoid the \"too many labels\" error\n  rule {\n    action = \"labelmap\"\n    regex  = \"__meta_kubernetes_pod_label_(.+)\"\n  }\n  rule {\n    action = \"labeldrop\"\n    regex  = \"app_kubernetes_io_(.+)\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_uid\", \"__meta_kubernetes_pod_container_name\"]\n    separator     = \"/\"\n    replacement   = \"/var/log/pods/*$1/*.log\"\n    target_label  = \"__path__\"\n  }\n}\n\nlocal.file_match \"pod_logs\" {\n  path_targets = discovery.relabel.pod_logs.output\n}\n\nloki.source.file \"pod_logs\" {\n  targets    = local.file_match.pod_logs.targets\n  forward_to = [loki.process.pod_logs.receiver]\n}\n\nloki.process \"pod_logs\" {\n  // Parse the containerd (CRI) log format\n  stage.cri {}\n  forward_to = [loki.write.loki.receiver]\n}\n\nloki.write \"loki\" {\n  endpoint {\n    url = \"{{ printf \"http://%s-loki:3100/loki/api/v1/push\" .Release.Name }}\"\n  }\n}"},"mounts":{"varlog":true},"securityContext":{"runAsGroup":0,"runAsUser":0}},"controller":{"tolerations":[{"effect":"NoSchedule","operator":"Exists"}]},"crds":{"create":false},"serviceMonitor":{"enabled":true}}` | Alloy is an external dependency that provides log collection on Kubernetes. It replaces the deprecated Promtail. |
| alloy.alloy.configMap.content | string | `"// Collect logs only from the pods of the node Alloy runs on.\n// K8S_NODE_NAME is set by the Alloy chart.\ndiscovery.kubernetes \"pods\" {\n  role = \"pod\"\n  selectors {\n    role  = \"pod\"\n    field = \"spec.nodeName=\" + sys.env(\"K8S_NODE_NAME\")\n  }\n}\n\ndiscovery.relabel \"pod_logs\" {\n  targets = discovery.kubernetes.pods.targets\n\n  rule {\n    source_labels = [\"__meta_kubernetes_namespace\"]\n    target_label  = \"namespace\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_name\"]\n    target_label  = \"pod\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_container_name\"]\n    target_label  = \"container\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_node_name\"]\n    target_label  = \"node_name\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_namespace\", \"__meta_kubernetes_pod_name\"]\n    separator     = \"/\"\n    target_label  = \"job\"\n  }\n  // Map the pod labels then drop some to avoid the \"too many labels\" error\n  rule {\n    action = \"labelmap\"\n    regex  = \"__meta_kubernetes_pod_label_(.+)\"\n  }\n  rule {\n    action = \"labeldrop\"\n    regex  = \"app_kubernetes_io_(.+)\"\n  }\n  rule {\n    source_labels = [\"__meta_kubernetes_pod_uid\", \"__meta_kubernetes_pod_container_name\"]\n    separator     = \"/\"\n    replacement   = \"/var/log/pods/*$1/*.log\"\n    target_label  = \"__path__\"\n  }\n}\n\nlocal.file_match \"pod_logs\" {\n  path_targets = discovery.relabel.pod_logs.output\n}\n\nloki.source.file \"pod_logs\" {\n  targets    = local.file_match.pod_logs.targets\n  forward_to = [loki.process.pod_logs.receiver]\n}\n\nloki.process \"pod_logs\" {\n  // Parse the containerd (CRI) log format\n  stage.cri {}\n  forward_to = [loki.write.loki.receiver]\n}\n\nloki.write \"loki\" {\n  endpoint {\n    url = \"{{ printf \"http://%s-loki:3100/loki/api/v1/push\" .Release.Name }}\"\n  }\n}"` | Equivalent of the previous Promtail configuration: collect the logs of all the pods of the node and push them to Loki. The loki.write url is templated to match the release name. |
| alloy.alloy.mounts | object | `{"varlog":true}` | Mount /var/log from the host to read the pod log files, as Promtail did |
| alloy.alloy.securityContext | object | `{"runAsGroup":0,"runAsUser":0}` | Required to read the pod log files on the host |
| alloy.controller.tolerations | list | `[{"effect":"NoSchedule","operator":"Exists"}]` | Be sure that Alloy runs on every node |
| alloy.crds | object | `{"create":false}` | No need for the PodLogs CRD: logs are collected from the node filesystem |
| datastore.priorityClass | string | `"backbone"` |  |
| datastore.pvcSize | string | `"2Gi"` |  |
| front.enabled | bool | `true` |  |
| global.defaultStorageClass | string | `""` | Leave empty to use the default storage class |
| global.imagePullSecrets | list | `[]` |  |
| global.imageRegistry | string | `nil` | Override the container registry globaly. Useful to use development using registry.ryax.org/dev or for airgapped env |
| global.monitoring.enabled | bool | `true` |  |
| global.monitoring.otlpEndpoint | string | `"{{ .Release.Name }}-tempo:4317"` | WARN: Be sure to use tpl in sub chart to inject release name |
| global.nodeSelector | object | `{}` |  |
| global.ryax | object | `{"logLevel":"warning","userNamespace":"ryaxns-execs"}` | Ryax specific configuration |
| global.ryax.logLevel | string | `"warning"` | Global log level, can be overriden locally |
| global.ryax.userNamespace | string | `"ryaxns-execs"` | Namespace where user's actions are deployed |
| global.security | object | `{"allowInsecureImages":true}` | Needed by bitnami to avoid https://github.com/bitnami/charts/issues/30850 |
| global.tls.enabled | bool | `false` |  |
| global.tls.environment | string | `nil` | development or production |
| global.tls.hostname | string | `""` | must be a valid FQDN like "local.ryax.io", leave empty for local install |
| intelliscale.enabled | bool | `true` |  |
| intelliscale.priorityClass | string | `"microservices"` |  |
| kube-prometheus-stack | object | `{"additionalPrometheusRulesMap":{"meta-monitoring":{"groups":[{"name":"meta-monitoring","rules":[{"alert":"InstanceDown","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/HKcS6KdGk","description":"{{ `'{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute.'` }}\n","summary":"{{ `'Instance {{ $labels.instance }} down'` }}\n"},"expr":"up == 0","for":"5m","labels":{"severity":"critical"}}]}]},"resource-usage":{"groups":[{"name":"resource-usage","rules":[{"alert":"RyaxContainerCpuUsage","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/6581e46e4e5c7ba40a07646395ef7b23","description":"{{ `\"Container CPU usage is above 95% for 15 minutes\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Container CPU usage (instance {{ $labels.instance }})\"` }}\n"},"expr":"(sum(rate(container_cpu_usage_seconds_total{container=~\"ryax-.*\"}[15m])) BY (instance, name) * 100) > 95","for":"5m","labels":{"severity":"warning"}},{"alert":"RyaxContainerVolumeUsage","annotations":{"description":"{{ `\"Container Volume usage is above 80%\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Container Volume usage (instance {{ $labels.instance }})\"` }}\n"},"expr":"(1 - (sum(container_fs_inodes_free{container=~\"ryax-.*\"}) BY (instance) / sum(container_fs_inodes_total{container=~\"ryax-.*\"}) BY (instance)) * 100) > 80","for":"5m","labels":{"severity":"warning"}},{"alert":"RyaxContainerVolumeIoUsage","annotations":{"description":"{{ `\"Container Volume IO usage is above 80%\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Container Volume IO usage (instance {{ $labels.instance }})\"` }}\n"},"expr":"(sum(container_fs_io_current{container=~\"ryax-.*\"}) BY (instance, name) * 100) > 80","for":"5m","labels":{"severity":"warning"}}]}]}},"alertmanager":{"enabled":false},"crds":{"enabled":true,"upgradeJob":{"enabled":true,"forceConflicts":true}},"enabled":true,"grafana":{"admin":{"existingSecret":"grafana-credentials","passwordKey":"admin-password","userKey":"admin-user"},"enabled":true,"grafana.ini":{"auth.anonymous":{"enabled":false},"users":{"allow_org_create":false,"allow_sign_up":false}},"ingress":{"enabled":false},"persistence":{"enabled":true,"size":"1Gi"},"plugins":["grafana-piechart-panel","grafana-clock-panel","vonage-status-panel"],"sidecar":{"dashboards":{"enabled":true,"label":"grafana_dashboard"},"datasources":{"enabled":true,"label":"grafana_datasource"}}},"kubeProxy":{"service":{"selector":{"component":"kube-proxy"}}},"prometheus":{"prometheusSpec":{"additionalScrapeConfigs":[{"job_name":"kubernetes-gpu-pod","kubernetes_sd_configs":[{"role":"pod"}],"relabel_configs":[{"action":"keep","regex":"nvidia-dcgm-exporter","source_labels":["__meta_kubernetes_pod_label_app"]},{"action":"keep","regex":"kube-system","source_labels":["__meta_kubernetes_namespace"]},{"action":"keep","regex":"9400","source_labels":["__meta_kubernetes_pod_container_port_number"]},{"action":"replace","separator":":","source_labels":["__meta_kubernetes_pod_ip","__meta_kubernetes_pod_container_port_number"],"target_label":"__address__"}],"scrape_interval":"5s"}],"externalLabels":{"cluster":"{{ .Values.global.tls.hostname }}","ryax-version":"{{ .Chart.Version }}"},"priorityClassName":"monitoring","serviceMonitorSelectorNilUsesHelmValues":false},"storage":{"volumeClaimTemplate":{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}}},"prometheusOperator":{"priorityClassName":"monitoring"}}` | Configuration for kube-prometheus-chart |
| kube-prometheus-stack.grafana | object | `{"admin":{"existingSecret":"grafana-credentials","passwordKey":"admin-password","userKey":"admin-user"},"enabled":true,"grafana.ini":{"auth.anonymous":{"enabled":false},"users":{"allow_org_create":false,"allow_sign_up":false}},"ingress":{"enabled":false},"persistence":{"enabled":true,"size":"1Gi"},"plugins":["grafana-piechart-panel","grafana-clock-panel","vonage-status-panel"],"sidecar":{"dashboards":{"enabled":true,"label":"grafana_dashboard"},"datasources":{"enabled":true,"label":"grafana_datasource"}}}` | Configuration for grafana component |
| kube-prometheus-stack.grafana.admin.existingSecret | string | `"grafana-credentials"` | This secret is created by common-resources |
| kube-prometheus-stack.kubeProxy.service.selector.component | string | `"kube-proxy"` | Needed on AKS to properly select the pod and avoid KubeProxyDown alerts |
| kube-prometheus-stack.prometheus.prometheusSpec.externalLabels | object | `{"cluster":"{{ .Values.global.tls.hostname }}","ryax-version":"{{ .Chart.Version }}"}` | inject more labels here like hostedOn: mycloud.com instanceType: production |
| kube-prometheus-stack.prometheus.storage.volumeClaimTemplate.spec.resources | object | `{"requests":{"storage":"10Gi"}}` | Select a storage class for prometheus metrics storage storageClassName: "{{ .Values.global.defaultStorageClass }}" |
| kube-prometheus-stack.prometheusOperator.priorityClassName | string | `"monitoring"` | Node selector for the prometheus  nodeSelector:  |
| loki | object | `{"backend":{"replicas":0},"chunksCache":{"enabled":false},"deploymentMode":"SingleBinary","enabled":true,"gateway":{"enabled":false},"loki":{"auth_enabled":false,"commonConfig":{"replication_factor":1},"extraMemberlistConfig":{"bind_addr":["${POD_IP}"]},"limits_config":{"max_label_names_per_series":30,"retention_period":"7d"},"query_scheduler":{"max_outstanding_requests_per_tenant":2048},"schemaConfig":{"configs":[{"from":"2024-01-01","index":{"period":"24h","prefix":"loki_index_"},"object_store":"filesystem","schema":"v13","store":"tsdb"}]},"server":{"log_level":"warn"},"storage":{"type":"filesystem"}},"lokiCanary":{"enabled":false},"read":{"replicas":0},"resultsCache":{"enabled":false},"singleBinary":{"extraArgs":["-config.expand-env=true"],"extraEnv":[{"name":"POD_IP","valueFrom":{"fieldRef":{"fieldPath":"status.podIP"}}}],"replicas":1,"resources":{"limits":{"cpu":1,"memory":"512Mi"},"requests":{"cpu":0.5,"memory":"512Mi"}}},"test":{"enabled":false},"write":{"replicas":0}}` | Loki is an external dependency that provides log collection on Kubernetes. |
| loki.loki.auth_enabled | bool | `false` | Avoid "No Org id error" in Grafana datasource. See Helm chart documentation for more details |
| loki.loki.limits_config.max_label_names_per_series | int | `30` | Increase the number of labels or logs from ryax services can be ignored |
| loki.loki.limits_config.retention_period | string | `"7d"` | Keep only one week of logs |
| loki.loki.query_scheduler | object | `{"max_outstanding_requests_per_tenant":2048}` | Adding this to avoid "too many outstanding requests" errors on the API See https://github.com/grafana/loki/issues/4613 |
| loki.loki.schemaConfig.configs[0].object_store | string | `"filesystem"` | storing on filesystem, so there's no real persistence here. if you want to persist logs on S3 change this config. See https://grafana.com/docs/loki/latest/operations/storage/ |
| loki.singleBinary.resources | object | `{"limits":{"cpu":1,"memory":"512Mi"},"requests":{"cpu":0.5,"memory":"512Mi"}}` | Avoid Loki using too many resources: Increase this if you experience OOM errors |
| minio.auth.existingSecret | string | `"ryax-minio-secret"` |  |
| minio.commonLabels."ryax.tech/resource-name" | string | `"minio"` |  |
| minio.console.enabled | bool | `false` | enable this to add internal Web console to browse Minio content |
| minio.console.image.repository | string | `"bitnamilegacy/minio-object-browser"` |  |
| minio.containerSecurityContext.runAsUser | int | `1200` |  |
| minio.defaultInitContainers.volumePermissions | object | `{"enabled":false}` | If you move data to NFS, enable this to force the permission of minio to match the one from ryax user (UID: 1200) |
| minio.image.repository | string | `"bitnamilegacy/minio"` |  |
| minio.metrics.enabled | bool | `true` |  |
| minio.mode | string | `"standalone"` |  |
| minio.persistence.enabled | bool | `true` |  |
| minio.persistence.size | string | `"20Gi"` |  |
| minio.podSecurityContext.fsGroup | int | `1200` |  |
| minio.priorityClassName | string | `"backbone"` |  |
| minio.resources.limits.memory | string | `"1000Mi"` |  |
| minio.resources.requests.cpu | string | `"100m"` |  |
| minio.resources.requests.memory | string | `"1000Mi"` |  |
| minio.serviceAccount.create | bool | `false` |  |
| rabbitmq.auth.existingErlangSecret | string | `"ryax-broker-cookie"` |  |
| rabbitmq.auth.existingPasswordSecret | string | `"ryax-broker-secret"` |  |
| rabbitmq.auth.tls.autoGenerated | bool | `false` |  |
| rabbitmq.auth.tls.enabled | bool | `false` |  |
| rabbitmq.auth.username | string | `"ryaxmq"` |  |
| rabbitmq.clustering.enabled | bool | `false` |  |
| rabbitmq.extraPlugins | string | `""` |  |
| rabbitmq.fullnameOverride | string | `"ryax-broker"` |  |
| rabbitmq.image.repository | string | `"bitnamilegacy/rabbitmq"` |  |
| rabbitmq.metrics.enabled | bool | `true` |  |
| rabbitmq.metrics.serviceMonitor.enabled | bool | `true` |  |
| rabbitmq.persistence.enabled | bool | `true` |  |
| rabbitmq.persistence.size | string | `"1Gi"` |  |
| rabbitmq.plugins | string | `"rabbitmq_management"` |  |
| rabbitmq.priorityClassName | string | `"backbone"` |  |
| rabbitmq.rbac.create | bool | `false` |  |
| rabbitmq.resources.limits.memory | string | `"1000Mi"` |  |
| rabbitmq.resources.requests.cpu | string | `"100m"` |  |
| rabbitmq.resources.requests.memory | string | `"500Mi"` |  |
| rabbitmq.serviceAccount.create | bool | `false` |  |
| rabbitmq.ulimitNofiles | string | `""` |  |
| registry.credentials.enabled | bool | `true` |  |
| registry.credentials.pullSecretName | string | `"ryax-registry-creds-secret"` |  |
| registry.ingress.enabled | bool | `false` |  |
| registry.persistence.enabled | bool | `true` |  |
| registry.persistence.pvcSize | string | `"20Gi"` |  |
| registry.priorityClass | string | `"backbone"` |  |
| repository.priorityClass | string | `"microservices"` |  |
| repository.priorityClass | string | `"microservices"` |  |
| runner.priorityClass | string | `"microservices"` |  |
| studio.priorityClass | string | `"microservices"` |  |
| tempo.enabled | bool | `true` |  |
| tempo.persistence.enabled | bool | `true` |  |
| tempo.persistence.size | string | `"10Gi"` |  |
| tempo.priorityClassName | string | `"monitoring"` |  |
| traefik.deployment.enabled | bool | `true` |  |
| traefik.metrics.prometheus.disableAPICheck | bool | `true` |  |
| traefik.metrics.prometheus.serviceMonitor.enabled | bool | `true` |  |
| traefik.nodeSelector | string | `nil` | set this to force Traefik on a node pool |
| traefik.priorityClassName | string | `"backbone"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
