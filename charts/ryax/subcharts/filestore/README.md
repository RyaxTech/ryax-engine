# filestore

![Version: 26.9.0](https://img.shields.io/badge/Version-26.9.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.9.0](https://img.shields.io/badge/AppVersion-26.9.0-informational?style=flat-square)

Ryax filestore, the S3 store of action inputs and outputs, served by versitygw over a volume

**Homepage:** <https://ryax.tech>

## Values

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.affinity | object | `{}` | Affinity injected as-is into every Ryax pod. Override with this chart's own `affinity`. |
| global.defaultStorageClass | string | `""` | Leave empty to use the default storage class |
| global.imagePullSecrets | list | `[]` | Global container registry secret names as an array Example:   - name: myPullSercret |
| global.nodeSelector | object | `{}` | Add nodeSelector injected as-is (https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) |
| global.tolerations | list | `[]` | Tolerations injected as-is into every Ryax pod (https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Override with this chart's own `tolerations`. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity injected as-is, overriding `global.affinity` when set |
| extraEnv | list | `[]` | Extra environment variables of the gateway, e.g. VGW_* options. Do not turn VGW_KEEP_ALIVE off: without it every request pays a new TCP connection, and the filestore is slower than MinIO was. |
| filestoreSecret | string | `"ryax-minio-secret"` | Secret holding the S3 credentials, shared with the Ryax services. The gateway's root access key and secret are its `root-user` and `root-password` keys, the ones the MinIO chart used, so no Secret changes. Created by the common-resources subchart unless `global.secrets.create` is false. |
| fullnameOverride | string | `"ryax-filestore"` | Name of the Deployment and of its PVC. |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"ghcr.io/versity/versitygw","tag":"v1.8.0"}` | versitygw, an S3 gateway that keeps every object as a plain file on the volume, with its metadata in extended attributes. Pinned: never `latest`. |
| migration | object | `{"allowDecommissionWithoutCopy":false,"copyResources":{"limits":{"memory":"1000Mi"},"requests":{"cpu":"100m","memory":"128Mi"}},"enabled":true,"image":{"pullPolicy":"IfNotPresent","repository":"docker.io/bitnamilegacy/minio","tag":"2025.7.23-debian-12-r3"},"legacy":{"persistence":{"size":"20Gi","storageClass":""},"resources":{"limits":{"memory":"1000Mi"},"requests":{"cpu":"50m","memory":"256Mi"}}},"precopy":{"enabled":false,"source":"ryax-minio","waitSeconds":300}}` | The one-off move of the data from the MinIO of Ryax 26.9 and older. See the 26.10.0 upgrade notes in RELEASE.md. |
| migration.allowDecommissionWithoutCopy | bool | `false` | Let `enabled: false` remove the old MinIO although no filestore pod has finished the copy. Its data is then not in the filestore. |
| migration.copyResources | object | `{"limits":{"memory":"1000Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` | Resources of the copy, which runs in an init container of the filestore pod and in the pre-copy Job. |
| migration.enabled | bool | `true` | Copy the objects of the old MinIO volume into this filestore, once. With `helm install`/`upgrade` the chart only does so when the old volume (`<release>-minio`) exists, so a fresh install gets nothing extra. A GitOps render cannot see the cluster and always includes the old MinIO and its volume: set this to false on a fresh GitOps install.  Turning it off after the upgrade decommissions the old MinIO. Helm keeps its volume, which then has to be deleted by hand. The chart refuses to turn it off before the copy is done, and on a 26.9 install not yet migrated. |
| migration.image | object | `{"pullPolicy":"IfNotPresent","repository":"docker.io/bitnamilegacy/minio","tag":"2025.7.23-debian-12-r3"}` | The MinIO image of Ryax 26.9: it serves the old volume during the migration, and its `mc` client does the copy. Already in 26.9 airgap bundles. |
| migration.legacy | object | `{"persistence":{"size":"20Gi","storageClass":""},"resources":{"limits":{"memory":"1000Mi"},"requests":{"cpu":"50m","memory":"256Mi"}}}` | The MinIO of Ryax 26.9, `<release>-minio`, and its PVC of the same name. The chart takes the PVC over as it is, and annotates it so that neither Helm nor ArgoCD ever deletes it. |
| migration.legacy.persistence | object | `{"size":"20Gi","storageClass":""}` | Size and storage class of that PVC, for GitOps renders only: Helm reads them from the cluster. Set them to your former `minio.persistence.size` and `minio.persistence.storageClass`. |
| migration.precopy.enabled | bool | `false` | Render the optional pre-copy Job (and the PVC it fills) instead of installing anything: only with `helm template --show-only charts/filestore/templates/precopy.yaml`, while Ryax 26.9 still runs. See RELEASE.md. |
| migration.precopy.source | string | `"ryax-minio"` | Address of the MinIO the pre-copy reads from: the 26.9 Service. |
| migration.precopy.waitSeconds | int | `300` | How long the pre-copy waits for that MinIO before giving up. |
| nodeSelector | object | `{}` | nodeSelector injected as-is, overriding `global.nodeSelector` when set |
| persistence.existingClaim | string | `""` | Use this PVC instead of creating one. The objects are kept under `s3/`. |
| persistence.size | string | `""` | Size of the volume. Empty: the size of the volume already there, else that of the MinIO volume being migrated (`migration.legacy.persistence.size` in a GitOps render), else 20Gi. Set it to grow the volume, if its storage class allows it. |
| persistence.storageClass | string | `""` | Storage class of the volume. Defaults to `global.defaultStorageClass`, then to the cluster default. It must support user extended attributes (ext4 and xfs do). |
| priorityClassName | string | `"backbone"` |  |
| region | string | `"us-east-1"` | S3 region the gateway answers for. The Ryax services use minio-py, which asks for the bucket location and signs with `us-east-1` until told otherwise. |
| resources.limits.memory | string | `"512Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"128Mi"` |  |
| service.name | string | `"ryax-minio"` | Name of the Service. The services, the remote workers' Skupper connectors and GitOps secrets all reach the filestore as `ryax-minio.<namespace>:9000` (the `filestore` key of `filestoreSecret`), so the name stays that of the MinIO it replaces. Must match `common-resources.filestoreService`. |
| service.port | int | `9000` |  |
| tolerations | list | `[]` | Tolerations injected as-is, overriding `global.tolerations` when set |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
