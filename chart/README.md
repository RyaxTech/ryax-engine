# ryax-engine

![Version: 26.1](https://img.shields.io/badge/Version-26.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.1](https://img.shields.io/badge/AppVersion-26.1-informational?style=flat-square)

Ryax is a open-source Hybrid workflow orchestrator to optimize your AI workflows and applications on multiple infrastructure.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-engine>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://grafana.github.io/helm-charts | tempo | 1.x.x |
| https://helm.traefik.io/traefik | traefik | 39.x.x |
| https://prometheus-community.github.io/helm-charts | kube-prometheus-stack | 81.x.x |
| oci://registry-1.docker.io/bitnamicharts | minio | 16.x.x |
| oci://registry-1.docker.io/bitnamicharts | rabbitmq | 15.x.x |
| oci://registry.ryax.org/release-charts | action-builder | 26.1.x |
| oci://registry.ryax.org/release-charts | authorization | 26.1.x |
| oci://registry.ryax.org/release-charts | common-resources | 26.1.x |
| oci://registry.ryax.org/release-charts | datastore | 26.1.x |
| oci://registry.ryax.org/release-charts | front | 26.1.x |
| oci://registry.ryax.org/release-charts | intelliscale | 26.1.x |
| oci://registry.ryax.org/release-charts | registry | 26.1.x |
| oci://registry.ryax.org/release-charts | repository | 26.1.x |
| oci://registry.ryax.org/release-charts | runner | 26.1.x |
| oci://registry.ryax.org/release-charts | studio | 26.1.x |
| oci://registry.ryax.org/release-charts | webui | 26.1.0 |
| oci://registry.ryax.org/release-charts | worker | 26.1.x |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| action-builder.actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Only necessary if registry.credentials.enabled=true |
| action-builder.nix.storeSize | string | `"100Gi"` |  |
| action-builder.persitence.enabled | bool | `true` |  |
| action-builder.priorityClass | string | `"microservices"` |  |
| certManager | object | `{"enabled":false}` | All common configuration and secrets are created here |
| datastore.priorityClass | string | `"backbone"` |  |
| datastore.pvcSize | string | `"2Gi"` |  |
| front.enabled | bool | `true` |  |
| global.defaultStorageClass | string | `""` | Leave empty to use the default storage class |
| global.imagePullSecrets | list | `[]` |  |
| global.imageRegistry | string | `nil` | Override the container registry globaly. Useful to use development using registry.ryax.org/dev or for airgapped env |
| global.monitoring.enabled | bool | `true` |  |
| global.monitoring.otlpEndpoint | string | `"ryax-tempo:4317"` | TODO: use a tpl in sub chart to inject release name |
| global.nodeSelector | object | `{}` |  |
| global.ryax | object | `{"logLevel":"warning","userNamespace":"ryaxns-execs"}` | Ryax specific configuration |
| global.ryax.logLevel | string | `"warning"` | Global log level, can be overriden locally |
| global.ryax.userNamespace | string | `"ryaxns-execs"` | Namespace where user's actions are deployed |
| global.security | object | `{"allowInsecureImages":true}` | Needed by bitnami to avoid https://github.com/bitnami/charts/issues/30850 |
| global.tls.enabled | bool | `false` |  |
| global.tls.environment | string | `nil` | development or production |
| global.tls.hostname | string | `""` | must be a valid FQDN like "local.ryax.io", leave empty for local install |
| kube-prometheus-stack | object | `{"additionalPrometheusRulesMap":{"errors":{"groups":[{"name":"errors","rules":[{"alert":"RyaxErrorsInLogs","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/2D4_jbdGz","description":"{{ `\"Ryax internal services logs issues more then 2 errors in 1 minute\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Error in Ryax internal servies (container {{ $labels.container }})\"` }}\n"},"expr":"sum(increase(promtail_custom_ryax_internal_error_in_logs_sum[1m])) > 2","for":"2m","labels":{"severity":"warning"}}]}]},"meta-monitoring":{"groups":[{"name":"meta-monitoring","rules":[{"alert":"InstanceDown","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/HKcS6KdGk","description":"{{ `'{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute.'` }}\n","summary":"{{ `'Instance {{ $labels.instance }} down'` }}\n"},"expr":"up == 0","for":"5m","labels":{"severity":"critical"}}]}]},"resource-usage":{"groups":[{"name":"resource-usage","rules":[{"alert":"RyaxContainerCpuUsage","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/6581e46e4e5c7ba40a07646395ef7b23","description":"{{ `\"Container CPU usage is above 95% for 15 minutes\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Container CPU usage (instance {{ $labels.instance }})\"` }}\n"},"expr":"(sum(rate(container_cpu_usage_seconds_total{container=~\"ryax-.*\"}[15m])) BY (instance, name) * 100) > 95","for":"5m","labels":{"severity":"warning"}},{"alert":"RyaxContainerVolumeUsage","annotations":{"description":"{{ `\"Container Volume usage is above 80%\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Container Volume usage (instance {{ $labels.instance }})\"` }}\n"},"expr":"(1 - (sum(container_fs_inodes_free{container=~\"ryax-.*\"}) BY (instance) / sum(container_fs_inodes_total{container=~\"ryax-.*\"}) BY (instance)) * 100) > 80","for":"5m","labels":{"severity":"warning"}},{"alert":"RyaxContainerVolumeIoUsage","annotations":{"description":"{{ `\"Container Volume IO usage is above 80%\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Container Volume IO usage (instance {{ $labels.instance }})\"` }}\n"},"expr":"(sum(container_fs_io_current{container=~\"ryax-.*\"}) BY (instance, name) * 100) > 80","for":"5m","labels":{"severity":"warning"}}]}]},"traefik":{"groups":[{"name":"traefik","rules":[{"alert":"TraefikBackendDown","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/YLMncaOGz","description":"{{ `\"All Traefik backends are down\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Traefik backend down (instance {{ $labels.instance }})\"` }}\n"},"expr":"count(traefik_backend_server_up) by (backend) == 0","for":"5m","labels":{"severity":"critical"}},{"alert":"TraefikHighHttp4xxErrorRateBackend","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/YLMncaOGz","description":"{{ `\"Traefik backend 4xx error rate is above 5%\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Traefik high HTTP 4xx error rate backend (instance {{ $labels.instance }})\"` }}\n"},"expr":"sum(rate(traefik_backend_requests_total{code=~\"4.*\"}[3m])) by (backend) / sum(rate(traefik_backend_requests_total[3m])) by (backend) * 100 > 5","for":"5m","labels":{"severity":"critical"}},{"alert":"TraefikHighHttp5xxErrorRateBackend","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/YLMncaOGz","description":"{{ `\"Traefik backend 5xx error rate is above 5%\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Traefik high HTTP 5xx error rate backend (instance {{ $labels.instance }})\"` }}\n"},"expr":"sum(rate(traefik_backend_requests_total{code=~\"5.*\"}[3m])) by (backend) / sum(rate(traefik_backend_requests_total[3m])) by (backend) * 100 > 5","for":"5m","labels":{"severity":"critical"}},{"alert":"TraefikHighAvgResponseTime","annotations":{"dashboards":"{{ .Values.dashboardUrl }}/YLMncaOGz","description":"{{ `\"Traefik average response time is higher then 500ms\\n  VALUE = {{ $value }}\\n  LABELS: {{ $labels }}\"` }}\n","summary":"{{ `\"Traefik high average response time (instance {{ $labels.instance }})\"` }}\n"},"expr":"sum(traefik_entrypoint_request_duration_seconds_sum) / sum(traefik_entrypoint_requests_total) * 1000 > 500","for":"5m","labels":{"severity":"warning"}}]}]}},"alertmanager":{"enabled":false},"crds":{"enabled":true,"upgradeJob":{"enabled":true,"forceConflicts":true}},"enabled":true,"grafana":{"admin":{"existingSecret":"grafana-credentials","passwordKey":"admin-password","userKey":"admin-user"},"enabled":true,"grafana.ini":{"auth.anonymous":{"enabled":false},"users":{"allow_org_create":false,"allow_sign_up":false}},"ingress":{"enabled":false},"persistence":{"enabled":true,"size":"1Gi"},"plugins":["grafana-piechart-panel","grafana-clock-panel","vonage-status-panel"],"sidecar":{"dashboards":{"enabled":true,"label":"grafana_dashboard"},"datasources":{"enabled":true,"label":"grafana_datasource"}}},"kubeProxy":{"service":{"selector":{"component":"kube-proxy"}}},"prometheus":{"prometheusSpec":{"additionalScrapeConfigs":[{"job_name":"kubernetes-gpu-pod","kubernetes_sd_configs":[{"role":"pod"}],"relabel_configs":[{"action":"keep","regex":"nvidia-dcgm-exporter","source_labels":["__meta_kubernetes_pod_label_app"]},{"action":"keep","regex":"kube-system","source_labels":["__meta_kubernetes_namespace"]},{"action":"keep","regex":"9400","source_labels":["__meta_kubernetes_pod_container_port_number"]},{"action":"replace","separator":":","source_labels":["__meta_kubernetes_pod_ip","__meta_kubernetes_pod_container_port_number"],"target_label":"__address__"}],"scrape_interval":"5s"}],"externalLabels":{"cluster":"{{ .Values.global.tls.hostname }}","ryax-version":"{{ .Chart.Version }}"},"priorityClassName":"monitoring","serviceMonitorSelectorNilUsesHelmValues":false},"storage":{"volumeClaimTemplate":{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}}},"prometheusOperator":{"priorityClassName":"monitoring"}}` | Configuration for kube-prometheus-chart |
| kube-prometheus-stack.grafana | object | `{"admin":{"existingSecret":"grafana-credentials","passwordKey":"admin-password","userKey":"admin-user"},"enabled":true,"grafana.ini":{"auth.anonymous":{"enabled":false},"users":{"allow_org_create":false,"allow_sign_up":false}},"ingress":{"enabled":false},"persistence":{"enabled":true,"size":"1Gi"},"plugins":["grafana-piechart-panel","grafana-clock-panel","vonage-status-panel"],"sidecar":{"dashboards":{"enabled":true,"label":"grafana_dashboard"},"datasources":{"enabled":true,"label":"grafana_datasource"}}}` | Configuration for grafana component |
| kube-prometheus-stack.grafana.admin.existingSecret | string | `"grafana-credentials"` | This secret is created by common-resources |
| kube-prometheus-stack.kubeProxy.service.selector.component | string | `"kube-proxy"` | Needed on AKS to properly select the pod and avoid KubeProxyDown alerts |
| kube-prometheus-stack.prometheus.prometheusSpec.externalLabels | object | `{"cluster":"{{ .Values.global.tls.hostname }}","ryax-version":"{{ .Chart.Version }}"}` | inject more labels here like hostedOn: mycloud.com instanceType: production |
| kube-prometheus-stack.prometheus.storage.volumeClaimTemplate.spec.resources | object | `{"requests":{"storage":"10Gi"}}` | Select a storage class for prometheus metrics storage storageClassName: "{{ .Values.global.defaultStorageClass }}" |
| kube-prometheus-stack.prometheusOperator.priorityClassName | string | `"monitoring"` | Node selector for the prometheus  nodeSelector:  |
| minio.auth.existingSecret | string | `"ryax-minio-secret"` |  |
| minio.commonLabels."ryax.tech/resource-name" | string | `"minio"` |  |
| minio.containerSecurityContext.runAsUser | int | `1200` |  |
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
| minio.volumePermissions.enabled | bool | `false` |  |
| rabbitmq.auth.existingErlangSecret | string | `"ryax-broker-cookie"` |  |
| rabbitmq.auth.existingPasswordSecret | string | `"ryax-broker-secret"` |  |
| rabbitmq.auth.resources.limits.memory | string | `"1000Mi"` |  |
| rabbitmq.auth.resources.requests.cpu | string | `"100m"` |  |
| rabbitmq.auth.resources.requests.memory | string | `"500Mi"` |  |
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
| worker.actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Only necessary if registry.credentials.enabled=true |
| worker.config.site.name | string | `"local"` |  |
| worker.config.site.spec.namespace | string | `"{{ .Values.global.ryax.userNamespace }}"` |  |
| worker.config.site.spec.nodePools | list | `[{"cpu":4,"memory":"8G","name":"default","selector":{"kubernetes.io/os":"linux"}}]` | WARNING this is the worker config and the node pool resources and selector have to be set according to your infrastructure |
| worker.config.site.type | string | `"KUBERNETES"` |  |
| worker.intelliscale | object | `{"enabled":true,"priorityClass":"microservices"}` | install intelliscale in a separated helm chart instead |
| worker.loki.monitoring.serviceMonitor.enabled | bool | `true` |  |
| worker.postgresql.metrics.enabled | bool | `true` |  |
| worker.postgresql.metrics.serviceMonitor.enabled | bool | `true` |  |
| worker.priorityClass | string | `"microservices"` |  |
| worker.promtail.serviceMonitor.enabled | bool | `true` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
