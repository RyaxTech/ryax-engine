# studio

![Version: 26.7.0](https://img.shields.io/badge/Version-26.7.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.7.0](https://img.shields.io/badge/AppVersion-26.7.0-informational?style=flat-square)

The Ryax Studio manages the creation and edition of the workflows

**Homepage:** <https://ryax.tech>

## Source Code

* <https://gitlab.com/ryax-tech/ryax/ryax-studio>

## Values

### Ryax Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| apiMaxUploadSizeInBytes | string | `"1073741824"` | Max upload size in Bytes for the API. Change this to enable larger file to be used as static or inputs, of project variables. Default to 1GB |

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

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| apiPort | int | `8080` |  |
| authorizationUrl | string | `"ryax-authorization:8080"` |  |
| brokerSecret | string | `"ryax-broker-secret"` |  |
| datastoreSecret | string | `"ryax-datastore-secret"` |  |
| extraEnv | object | `{}` | Add extra environment variables Example:   name: TEST   value: TOTO |
| fernetEncryptionKey | string | `nil` | Fernet key used to encrypt PASSWORD values at rest. Leave empty to let Helm generate one (preserved across upgrades), or set it (see generate-secrets.py). |
| filestoreName | string | `"ryax-filestore"` |  |
| filestoreSecret | string | `"ryax-minio-secret"` |  |
| global.ryax.logLevel | string | `nil` |  |
| image | object | `{"digest":"","pullPolicy":"IfNotPresent","registry":"docker.io/ryaxtech","repository":"studio","tag":"26.7.0"}` | container image name and version |
| ingress.className | string | `""` | Value for `spec.ingressClassName`. Left empty, the Ingress is claimed by whichever IngressClass is marked default in the cluster -- which is a cluster-wide setting, not this chart's to rely on. |
| ingress.enabled | bool | `true` | Render an Ingress for this service. Turn it off when routing is handled outside the chart -- Gateway API, a service mesh, an external load balancer. With no controller to fill in `.status.loadBalancer`, a GitOps engine that health-checks Ingresses reports them Progressing forever and parks the sync. |
| jwtSecret | string | `"api-jwt-secret-key"` |  |
| logLevel | string | `nil` | log level of the service |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| passwordEncryptionKeySecret | string | `"studio-password-encryption-key"` | Name of the secret holding the Fernet key used to encrypt PASSWORD values at rest |
| passwordEncryptionKeySecretCreate | bool | `true` | Create the secret above. Set to false to provide it yourself; it must then carry the key(s): encryption-key. |
| priorityClass | string | `nil` | Deployment prority class |
| releaseMarker | string | `"ryax-release-marker"` | Name of the ConfigMap that marks the release as installed. The database-migration hooks read it and skip themselves when it is absent, so a first sync cannot deadlock on a database that does not exist yet. Created by the common-resources subchart. |
| resources | object | `{}` | resources for the pod Example:  requests:    memory: "200Mi"    cpu: "100m"  limits:    memory: "200Mi" |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). |
| updaterImage | string | `"docker.io/bitnamilegacy/kubectl:1.33"` | Image used by the updater job pod |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
