# front

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

Ryax platform web interface

## Values

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override per subchart with its own `affinity`. |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.imageRegistry | string | `nil` | Global container image registry |
| global.ingress.className | string | `""` | IngressClass the Ingress of this service targets, overridden by the local `ingress.className`. The umbrella chart points it at the bundled Traefik; empty means no class, i.e. whichever controller claims the cluster's default. WARN: templated with the release name, render it through tpl |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| global.secrets | object | `{"create":true}` | Credential secrets the chart generates itself (database, broker, JWT, encryption keys, registry htpasswd and TLS). Set to false to supply every one of them yourself -- sealed-secrets, external-secrets, or a plain kubectl create -- under the names listed in the values below. This is what a GitOps deployment wants: the generated values come from `lookup()`, which returns nothing when the chart is rendered without a cluster connection (`helm template`, ArgoCD's and Flux's repo servers), so every render would otherwise mint fresh passwords and roll them out to running pods. |
| global.tls.enabled | bool | `false` | Enables TLS for ingress |
| global.tls.environment | string | `"development"` | In production to get a valid certificat from let's encrypt, otherwise use the staging Let's encrypt cluster to avoid rate limit Should be: development or production |
| global.tls.existingCertificatSecret | string | `nil` | for self hosted instance with intenal TLS certificate |
| global.tls.hostname | string | `nil` | The Ryax cluster name, must be a valid DNS |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Required to run Ryax on tainted nodes; override per subchart with its own `tolerations`. Example:   - key: mycompany/mesh     operator: Exists     effect: NoSchedule |

### Resource Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| resources | object | `{}` | Recommended resource requirement Example:   requests:     memory: "125Mi"     cpu: "50m"   limits:     memory: "250Mi" |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| apiPort | int | `80` |  |
| extraEnv | object | `{}` | Add extra environment variables |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"front","tag":"26.7.0"}` | container image name and version |
| ingress.className | string | `""` | Value for `spec.ingressClassName`. Left empty, the Ingress is claimed by whichever IngressClass is marked default in the cluster -- which is a cluster-wide setting, not this chart's to rely on. |
| ingress.enabled | bool | `true` | Render an Ingress for this service. Turn it off when routing is handled outside the chart -- Gateway API, a service mesh, an external load balancer. With no controller to fill in `.status.loadBalancer`, a GitOps engine that health-checks Ingresses reports them Progressing forever and parks the sync. |
| ingress.hstsIncludeSubdomains | bool | `false` | Whether the Strict-Transport-Security header covers subdomains. Off by default: it would apply to every sibling host of the Ryax hostname, which is not this chart's to decide. |
| ingress.hstsSeconds | int | `31536000` | max-age of the Strict-Transport-Security header, in seconds. Only takes effect when `global.tls.enabled` is set: the header must never be sent by a deployment that serves plain HTTP, or browsers would pin users to an https:// origin that does not answer. Set to 0 to drop the header on a TLS deployment too. The nginx in the front image sets every other security header itself (see nix/nginx.conf in the front repository); this one lives here because it is the only one whose correctness depends on how the release is deployed. |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| priorityClass | string | `nil` |  |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
