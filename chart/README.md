# ryax-engine

![Version: 25.02.0](https://img.shields.io/badge/Version-25.02.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 25.02.0](https://img.shields.io/badge/AppVersion-25.02.0-informational?style=flat-square)

Ryax is a open-source Hybrid workflow orchestrator to optimize your AI workflows and applications on multiple infrastructure.

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-engine>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../action-builder/chart | action-builder | 0.0.0-dev |
| file://../authorization/chart | authorization | 0.0.0-dev |
| file://../common-helm-charts/common-resources | common-resources | 0.0.0-dev |
| file://../common-helm-charts/datastore | datastore | 0.0.0-dev |
| file://../common-helm-charts/registry | registry | 0.0.0-dev |
| file://../front/chart | front | 0.0.0-dev |
| file://../repository/chart | repository | 0.0.0-dev |
| file://../runner/charts/runner | runner | 0.0.0-dev |
| file://../runner/charts/worker | worker | 0.0.0-dev |
| file://../studio/chart | studio | 0.0.0-dev |
| file://../webui/chart | webui | 0.0.0-dev |
| https://grafana.github.io/helm-charts | tempo | 1.x.x |
| https://helm.traefik.io/traefik | traefik | 34.x.x |
| https://prometheus-community.github.io/helm-charts | kube-prometheus-stack | 70.x.x |
| oci://registry-1.docker.io/bitnamicharts | minio | 16.x.x |
| oci://registry-1.docker.io/bitnamicharts | rabbitmq | 15.x.x |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| action-builder.actionRegistrySecret | string | `"ryax-registry-creds-secret"` |  |
| action-builder.brokerSecret | string | `"ryax-broker-secret"` |  |
| action-builder.image.name | string | `"docker.io/ryaxtech/action-builder"` |  |
| action-builder.imagePullPolicy | string | `"IfNotPresent"` |  |
| action-builder.internalRegistry | string | `"ryax-registry:5000"` |  |
| action-builder.logLevel | string | `"warning"` |  |
| action-builder.tls.certSecret | string | `"ryax-cert-development"` |  |
| action-builder.tls.enabled | bool | `false` |  |
| action-builder.tls.hostname | string | `"local.ryax.io"` |  |
| authorization.image.name | string | `"docker.io/ryaxtech/authorization"` |  |
| authorization.imagePullPolicy | string | `"IfNotPresent"` |  |
| authorization.logLevel | string | `"warning"` |  |
| authorization.tls.certSecret | string | `"ryax-cert-development"` |  |
| authorization.tls.enabled | bool | `true` |  |
| authorization.tls.hostname | string | `"example.ryax.io"` |  |
| common-resources.brokerCookieName | string | `"ryax-broker-cookie"` |  |
| common-resources.brokerName | string | `"broker"` |  |
| common-resources.brokerSecret | string | `"ryax-broker-secret"` |  |
| common-resources.brokerService | string | `"ryax-broker"` |  |
| common-resources.brokerUser | string | `"ryaxmq"` |  |
| common-resources.certManager.enabled | bool | `false` |  |
| common-resources.environment | string | `"development"` |  |
| common-resources.filestoreSecret | string | `"ryax-minio-secret"` |  |
| common-resources.filestoreService | string | `"minio"` |  |
| common-resources.grafanaSecret | string | `"grafana-cedentials"` |  |
| common-resources.jwtSecret | string | `"api-jwt-secret-key"` |  |
| common-resources.monitoringNamespace | string | `"ryaxns-monitoring"` |  |
| common-resources.nameOverride | string | `"ryax"` |  |
| common-resources.registries.appregistry.url | string | `"docker.io/ryaxtech"` |  |
| common-resources.traefik.monitoring.enabled | bool | `false` |  |
| common-resources.userNamespace | string | `"ryaxns-execs"` |  |
| datastore.datastoreSecret | string | `"ryax-datastore-secret"` |  |
| datastore.imagePullPolicy | string | `"IfNotPresent"` |  |
| datastore.monitoring.enabled | bool | `false` |  |
| datastore.pvcName | string | `"ryax-datastore-pvc-0"` |  |
| datastore.pvcSize | string | `"2Gi"` |  |
| datastore.storageClass | string | `"local-path"` |  |
| front.environment | string | `"development"` |  |
| front.image.name | string | `"docker.io/ryaxtech/front"` |  |
| front.imagePullPolicy | string | `"IfNotPresent"` |  |
| front.logLevel | string | `"warning"` |  |
| front.tls.certSecret | string | `"ryax-cert-development"` |  |
| front.tls.enabled | bool | `false` |  |
| front.tls.hostname | string | `"local.ryax.io"` |  |
| global | object | `{"clusterName":"local","domainName":"ryax.io","environment":"development","imagePullPolicy":"IfNotPresent","imagePullSecrets":null,"imageRegistry":null,"logLevel":"info","nodeSelector":{},"persistence":{"enabled":true},"storageClass":"","tls":{"enabled":true},"userNamespace":"ryaxns-execs","version":"25.02.0"}` | This field has to be a release version. |
| minio.auth.existingSecret | string | `"ryax-minio-secret"` |  |
| minio.commonLabels."ryax.tech/resource-name" | string | `"minio"` |  |
| minio.containerSecurityContext.runAsUser | int | `1200` |  |
| minio.image.debug | bool | `false` |  |
| minio.metrics.enabled | bool | `false` |  |
| minio.mode | string | `"standalone"` |  |
| minio.persistence.enabled | bool | `true` |  |
| minio.persistence.size | string | `"20Gi"` |  |
| minio.persistence.storageClass | string | `"local-path"` |  |
| minio.podSecurityContext.fsGroup | int | `1200` |  |
| minio.priorityClassName | string | `"backbone"` |  |
| minio.resources.limits.memory | string | `"1000Mi"` |  |
| minio.resources.requests.cpu | string | `"100m"` |  |
| minio.resources.requests.memory | string | `"1000Mi"` |  |
| minio.serviceAccount.create | bool | `false` |  |
| minio.volumePermissions.enabled | bool | `false` |  |
| prometheus.enabled | bool | `false` |  |
| rabbitmq.auth.existingErlangSecret | string | `"ryax-broker-cookie"` |  |
| rabbitmq.auth.existingPasswordSecret | string | `"ryax-broker-secret"` |  |
| rabbitmq.auth.password | string | `"InsecurePassw0rd!"` |  |
| rabbitmq.auth.resources.limits.memory | string | `"1000Mi"` |  |
| rabbitmq.auth.resources.requests.cpu | string | `"100m"` |  |
| rabbitmq.auth.resources.requests.memory | string | `"500Mi"` |  |
| rabbitmq.auth.tls.autoGenerated | bool | `false` |  |
| rabbitmq.auth.tls.enabled | bool | `false` |  |
| rabbitmq.auth.username | string | `"ryaxmq"` |  |
| rabbitmq.clustering.enabled | bool | `false` |  |
| rabbitmq.extraPlugins | string | `""` |  |
| rabbitmq.fullnameOverride | string | `"ryax-broker"` |  |
| rabbitmq.image.debug | bool | `false` |  |
| rabbitmq.metrics.enabled | bool | `false` |  |
| rabbitmq.metrics.serviceMonitor.enabled | bool | `true` |  |
| rabbitmq.metrics.serviceMonitor.namespace | string | `"ryaxns-monitoring"` |  |
| rabbitmq.persistence.enabled | bool | `true` |  |
| rabbitmq.persistence.size | string | `"1Gi"` |  |
| rabbitmq.persistence.storageClass | string | `"local-path"` |  |
| rabbitmq.plugins | string | `"rabbitmq_management"` |  |
| rabbitmq.priorityClassName | string | `"backbone"` |  |
| rabbitmq.rbac.create | bool | `false` |  |
| rabbitmq.serviceAccount.create | bool | `false` |  |
| rabbitmq.ulimitNofiles | string | `""` |  |
| registry.credentials.enabled | bool | `true` |  |
| registry.credentials.htpasswd | string | `"ryax:$2a$12$L4zHsMG0d6UMcmum.egJ.OOP.UBP8pp9dntDWXIdsdST0X5x35wVy"` |  |
| registry.credentials.injectInNamespaces[0] | string | `"ryaxns-execs"` |  |
| registry.credentials.injectInNamespaces[1] | string | `"ryaxns"` |  |
| registry.credentials.password | string | `"R o93Wetj44yXAY9Rk-lWlklo0akQIYzp_Eg-UN721zA=="` |  |
| registry.credentials.pullSecretName | string | `"ryax-registry-creds-secret"` |  |
| registry.credentials.username | string | `"ryax"` |  |
| registry.imagePullPolicy | string | `"IfNotPresent"` |  |
| registry.ingress.enabled | bool | `false` |  |
| registry.monitoring.enabled | bool | `false` |  |
| registry.monitoring.namespace | string | `"ryaxns-monitoring"` |  |
| registry.nodePort | int | `30012` |  |
| registry.pvcSize | string | `"20Gi"` |  |
| registry.servicePort | int | `5000` |  |
| registry.storageClass | string | `"local-path"` |  |
| repository.authorizationUrl | string | `"ryax-authorization:8080"` |  |
| repository.brokerSecret | string | `"ryax-broker-secret"` |  |
| repository.datastoreSecret | string | `"ryax-datastore-secret"` |  |
| repository.environment | string | `"development"` |  |
| repository.fernetEncryptionKey | string | `"R tsPJX7WrANzevwwnhFJ-3YxwfSicrLzEEmRnXC9cXA=="` |  |
| repository.image.name | string | `"docker.io/ryaxtech/repository"` |  |
| repository.imagePullPolicy | string | `"IfNotPresent"` |  |
| repository.jwtSecret | string | `"api-jwt-secret-key"` |  |
| repository.logLevel | string | `"warning"` |  |
| repository.passwordEncryptionKeySecret | string | `"ryax-repository-password-encryption-key"` |  |
| repository.tls.certSecret | string | `"ryax-cert-development"` |  |
| repository.tls.enabled | bool | `false` |  |
| repository.tls.hostname | string | `"local.ryax.io"` |  |
| runner.authorizationUrl | string | `"ryax-authorization:8080"` |  |
| runner.brokerSecret | string | `"ryax-broker-secret"` |  |
| runner.datastoreSecret | string | `"ryax-datastore-secret"` |  |
| runner.environment | string | `"development"` |  |
| runner.fernetEncryptionKey | string | `"R LP2kPn8z-r9WGcckcZHkWLMVLXwKbugfbQONus6bIg=="` |  |
| runner.filestoreName | string | `"ryax-filestore"` |  |
| runner.filestoreSecret | string | `"ryax-minio-secret"` |  |
| runner.image.name | string | `"docker.io/ryaxtech/runner"` |  |
| runner.imagePullPolicy | string | `"IfNotPresent"` |  |
| runner.internalRegistry | string | `"127.0.0.1:30012"` |  |
| runner.jwtSecret | string | `"api-jwt-secret-key"` |  |
| runner.logLevel | string | `"warning"` |  |
| runner.monitoring.enabled | bool | `false` |  |
| runner.priorityClass | string | `"microservices"` |  |
| runner.ryaxUserNamespace | string | `"ryaxns-execs"` |  |
| runner.tls.certSecret | string | `"ryax-cert-development"` |  |
| runner.tls.enabled | bool | `false` |  |
| runner.tls.hostname | string | `"local.ryax.io"` |  |
| studio.authorizationUrl | string | `"ryax-authorization:8080"` |  |
| studio.brokerSecret | string | `"ryax-broker-secret"` |  |
| studio.datastoreSecret | string | `"ryax-datastore-secret"` |  |
| studio.environment | string | `"development"` |  |
| studio.filestoreName | string | `"ryax-filestore"` |  |
| studio.filestoreSecret | string | `"ryax-minio-secret"` |  |
| studio.image.name | string | `"docker.io/ryaxtech/studio"` |  |
| studio.imagePullPolicy | string | `"IfNotPresent"` |  |
| studio.jwtSecret | string | `"api-jwt-secret-key"` |  |
| studio.logLevel | string | `"warning"` |  |
| studio.tls.certSecret | string | `"ryax-cert-development"` |  |
| studio.tls.enabled | bool | `false` |  |
| studio.tls.hostname | string | `"local.ryax.io"` |  |
| tempo.enabled | bool | `false` |  |
| webui.environment | string | `"development"` |  |
| webui.image.name | string | `"docker.io/ryaxtech/webui"` |  |
| webui.imagePullPolicy | string | `"IfNotPresent"` |  |
| webui.logLevel | string | `"warning"` |  |
| webui.tls.certSecret | string | `"ryax-cert-development"` |  |
| webui.tls.enabled | bool | `false` |  |
| webui.tls.hostname | string | `"local.ryax.io"` |  |
| worker.actionRegistrySecret | string | `"ryax-registry-creds-secret"` |  |
| worker.brokerSecret | string | `"ryax-broker-secret"` |  |
| worker.config.site.name | string | `"local"` |  |
| worker.config.site.spec.namespace | string | `"ryaxns-execs"` |  |
| worker.config.site.spec.nodePools[0].cpu | int | `4` |  |
| worker.config.site.spec.nodePools[0].memory | string | `"8G"` |  |
| worker.config.site.spec.nodePools[0].name | string | `"default"` |  |
| worker.config.site.spec.nodePools[0].selector."node.kubernetes.io/instance-type" | string | `"k3s"` |  |
| worker.config.site.type | string | `"KUBERNETES"` |  |
| worker.environment | string | `"development"` |  |
| worker.filestoreName | string | `"ryax-filestore"` |  |
| worker.filestoreSecret | string | `"ryax-minio-secret"` |  |
| worker.image.name | string | `"docker.io/ryaxtech/worker"` |  |
| worker.imagePullPolicy | string | `"IfNotPresent"` |  |
| worker.logLevel | string | `"warning"` |  |
| worker.loki.monitoring.serviceMonitor.additionalLabels.app | string | `"prometheus-operator"` |  |
| worker.loki.monitoring.serviceMonitor.additionalLabels.release | string | `"prometheus"` |  |
| worker.loki.monitoring.serviceMonitor.enabled | bool | `false` |  |
| worker.loki.singleBinary.persistence.size | string | `"10Gi"` |  |
| worker.loki.singleBinary.persistence.storageClass | string | `"local-path"` |  |
| worker.postgresql.auth.password | string | `"InsecurePassw0rd!"` |  |
| worker.postgresql.primary.nodeSelector | object | `{}` |  |
| worker.priorityClass | string | `"microservices"` |  |
| worker.promtail.serviceMonitor.additionalLabels.app | string | `"prometheus-operator"` |  |
| worker.promtail.serviceMonitor.additionalLabels.release | string | `"prometheus"` |  |
| worker.promtail.serviceMonitor.enabled | bool | `false` |  |
| worker.vpa.config.MIG.enabled | bool | `false` |  |
| worker.vpa.image.pullPolicy | string | `"IfNotPresent"` |  |
| worker.vpa.image.repository | string | `"docker.io/ryaxtech/vpa"` |  |
| worker.vpa.monitoring.enabled | bool | `false` |  |
| worker.vpa.priorityClass | string | `"microservices"` |  |
| worker.vpa.ryax.worker.configMapName | string | `"ryax-worker-config"` |  |
| worker.vpa.ryax.worker.serviceName | string | `"ryax-worker"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
