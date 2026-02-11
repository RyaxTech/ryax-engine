# ryax-engine

![Version: 26.01](https://img.shields.io/badge/Version-26.01-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.01](https://img.shields.io/badge/AppVersion-26.01-informational?style=flat-square)

Ryax is a open-source Hybrid workflow orchestrator to optimize your AI workflows and applications on multiple infrastructure.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-engine>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://grafana.github.io/helm-charts | tempo | 1.x.x |
| https://helm.traefik.io/traefik | traefik | 34.x.x |
| https://prometheus-community.github.io/helm-charts | kube-prometheus-stack | 70.x.x |
| oci://registry-1.docker.io/bitnamicharts | minio | 16.x.x |
| oci://registry-1.docker.io/bitnamicharts | rabbitmq | 15.x.x |
| oci://registry.ryax.org/release-charts | action-builder | 26.01.0 |
| oci://registry.ryax.org/release-charts | authorization | 26.01.0 |
| oci://registry.ryax.org/release-charts | common-resources | 26.01.0 |
| oci://registry.ryax.org/release-charts | datastore | 26.01.0 |
| oci://registry.ryax.org/release-charts | front | 26.01.0 |
| oci://registry.ryax.org/release-charts | intelliscale | 26.01.0 |
| oci://registry.ryax.org/release-charts | registry | 26.01.0 |
| oci://registry.ryax.org/release-charts | repository | 26.01.0 |
| oci://registry.ryax.org/release-charts | runner | 26.01.0 |
| oci://registry.ryax.org/release-charts | studio | 26.01.0 |
| oci://registry.ryax.org/release-charts | webui | 26.01.0 |
| oci://registry.ryax.org/release-charts | worker | 26.01.0 |

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
| global.nodeSelector | object | `{}` |  |
| global.ryax | object | `{"logLevel":"warning","userNamespace":"ryaxns-execs"}` | Ryax specific configuration |
| global.ryax.logLevel | string | `"warning"` | Global log level, can be overriden locally |
| global.ryax.userNamespace | string | `"ryaxns-execs"` | Namespace where user's actions are deployed |
| global.security | object | `{"allowInsecureImages":true}` | Needed by bitnami to avoid https://github.com/bitnami/charts/issues/30850 |
| global.tls.enabled | bool | `false` |  |
| global.tls.environment | string | `nil` | development or production |
| global.tls.hostname | string | `""` | must be a valid FQDN like "local.ryax.io", leave empty for local install |
| intelliscale.priorityClass | string | `"microservices"` |  |
| kube-prometheus-stack.enabled | bool | `true` |  |
| kube-prometheus-stack.grafana.enabled | bool | `true` |  |
| kube-prometheus-stack.grafana.ingress.annotations."cert-manager.io/cluster-issuer" | string | `"{{ if .Values.global.tls.enabled }}letsencrypt-{{ .Values.global.tls.environment }}{{ end }}"` |  |
| kube-prometheus-stack.grafana.ingress.enabled | bool | `true` |  |
| kube-prometheus-stack.grafana.ingress.hosts | list | `[]` |  |
| kube-prometheus-stack.grafana.ingress.path | string | `"/grafana"` |  |
| kube-prometheus-stack.grafana.ingress.tls[0].hosts[0] | string | `"{{ if .Values.global.tls.enabled }}{{ .Values.global.tls.hostname }}{{ end }}"` |  |
| kube-prometheus-stack.grafana.ingress.tls[0].secretName | string | `"{{ if .Values.global.tls.enabled }}{{ .Values.global.tls.existingCertificatSecret | default (printf \"ryax-cert-%s\" .Values.global.tls.environment) }}{{end}}"` |  |
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
| rabbitmq.auth.updatePassword | bool | `true` |  |
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
| registry.ingress.enabled | bool | `true` |  |
| registry.persistence.enabled | bool | `true` |  |
| registry.persistence.pvcSize | string | `"20Gi"` |  |
| registry.priorityClass | string | `"backbone"` |  |
| repository.priorityClass | string | `"microservices"` |  |
| repository.priorityClass | string | `"microservices"` |  |
| runner.priorityClass | string | `"microservices"` |  |
| studio.priorityClass | string | `"microservices"` |  |
| tempo.enabled | bool | `true` |  |
| worker.actionRegistrySecret | string | `"ryax-registry-creds-secret"` | Only necessary if registry.credentials.enabled=true |
| worker.config | object | `{"site":{"name":"local","spec":{"namespace":"{{ .Values.global.ryax.userNamespace }}","nodePools":[{"cpu":4,"memory":"8G","name":"default","selector":{"node.kubernetes.io/instance-type":"k3s"}}]},"type":"KUBERNETES"}}` | WARNING this is the worker config and the node pool resources and selector have to be set according to your infrastructure |
| worker.intelliscale | object | `{"enabled":false}` | install intelliscale in a separated helm chart instead |
| worker.loki.monitoring.serviceMonitor.enabled | bool | `true` |  |
| worker.postgresql.image.registry | string | `"docker.io"` |  |
| worker.postgresql.metrics.enabled | bool | `false` |  |
| worker.postgresql.metrics.serviceMonitor.enabled | bool | `true` |  |
| worker.priorityClass | string | `"microservices"` |  |
| worker.promtail.serviceMonitor.enabled | bool | `true` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
