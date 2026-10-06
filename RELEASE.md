We are proud to announce the release of:

✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨
# Ryax 26.10.0
✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨

> **DRAFT — 26.10.0 is not released.** Entries are added here as the work lands, and
> this banner goes away when the release is cut. Nothing below has shipped yet.

<!-- One-line summary of the release, written when it is cut. -->

## New features

- **The initial admin password is random.** Every installation used to boot with the
  same `user1` / `pass1` — hard-coded in the service, never set by the chart, and
  published in the README and the install guide. The chart now generates one per
  installation into the `ryax-admin-credentials` secret, and `helm install` prints the
  command to read it back. The account is `admin`. Existing installations keep their
  users and passwords: the secret is only ever read when the user table is empty, which
  is the very first start.
- **`helm install` prints its notes.** `NOTES.txt` had always sat at the chart root
  rather than in `templates/`, where Helm is the only place it looks, so no install had
  ever printed anything. It now carries the admin credentials command and the Grafana
  one.

## Bug fixes and Improvements

- **An install reached through a proxy or by IP answers again.**
  ([roadmap#1448](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1448))
- **The broker no longer runs on a Bitnami image.** It ran on `bitnamilegacy/rabbitmq`,
  which Bitnami no longer updates. It is now a `RabbitmqCluster` run by the official
  [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview)
  (2.23.0) on the official `rabbitmq:4.3.6-management` image. The chart deploys the
  operator in the Ryax namespace, watching that namespace only, and it needs neither
  cluster-wide rights nor cert-manager. The services reach the broker at the same
  address with the same credentials.
  ([roadmap#1320](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1320))
- **The filestore no longer runs MinIO.** MinIO's community edition is no longer
  maintained, and the chart ran it from the Bitnami `bitnamilegacy/minio` image. The
  filestore is now [versitygw](https://github.com/versity/versitygw) v1.8.0, a small S3
  gateway that keeps every object as a plain file on its volume. On a test cluster it
  answers Ryax's requests faster than MinIO did (about 3x on small writes, 1.3x on small
  reads) with a tenth of its memory. The services reach it at the same address
  (`ryax-minio:9000`) with the same credentials (`ryax-minio-secret`), and the upgrade
  copies the existing objects into it.
  ([roadmap#1471](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1471))

## Upgrade to this version

Restore your values file if you do not have it:
```sh
helm get values -n ryaxns ryax --output yaml > values.yaml
```

Admins should take care of the following elements when upgrading to this version:

- **⚠️ If you set `global.tls.hostname`, Ryax answers for every host again.** 26.9.0
  restricted the Ingresses to that name; they are now restricted only to the names in
  `global.ingress.hosts`, which is empty (any host) by default. To keep Ryax to its own
  names, typically on a cluster shared with other applications, list them:
  ```yaml
  global:
    ingress:
      hosts: ["ryax.example.com"]
  ```
  If you keep `global.tls.hostname` as well, it must be one of these hosts, or the chart
  refuses to render. Installs that set neither value need nothing. More in
  [Install Ryax with ArgoCD › Routing](https://docs.ryax.tech/howto/install_ryax_argocd/#routing).

- **A new GitOps install needs one more secret.** With `global.secrets.create=false`,
  create `ryax-admin-credentials` (keys `admin-user` and `admin-password`) before the
  first sync, or set `authorization.adminUsername` and `authorization.adminPassword`.
  Without it the authorization pod stops with `No initial admin password configured`.
  An **existing** installation needs nothing — it never seeds again, and both
  `secretKeyRef`s are `optional`.

- **⚠️ Apply the RabbitMQ CRD before upgrading.** The broker moves to the RabbitMQ
  Cluster Operator, whose `RabbitmqCluster` CRD ships in the chart, and Helm never
  installs a CRD on an upgrade. Without it the upgrade stops before changing anything,
  and prints this command:
  ```sh
  kubectl apply --server-side -f https://gitlab.com/ryax-tech/ryax/ryax-engine/-/raw/26.10.0/charts/ryax/subcharts/rabbitmq/crds/rabbitmqclusters.rabbitmq.com.yaml
  ```
  Offline, take it from the chart package instead:
  ```sh
  tar -xzOf ryax-engine-26.10.0.tgz ryax-engine/charts/rabbitmq/crds/rabbitmqclusters.rabbitmq.com.yaml \
    | kubectl apply --server-side -f -
  ```
  `--server-side` is required: the CRD is too large for a client-side apply. ArgoCD
  applies the CRD itself, with the `ServerSideApply=true` the reference Application
  already sets.

- **The broker is replaced, not upgraded, and starts empty.** Helm removes the Bitnami
  StatefulSet and the operator starts `ryax-broker-server-0` in its place, about a minute
  later. The services keep the same address (`ryax-broker:5672`) and the same
  credentials (`ryax-broker-secret`), and reconnect by themselves. There is nothing to
  migrate: Ryax publishes its messages as transient, so a broker restart has always
  dropped whatever was still queued. As for any upgrade, run it while no workflow is
  running. The services retry on their own during the switch, which took about a minute
  on a test cluster. Once Ryax is back, delete the old broker volume, if there is one
  (there is none with `rabbitmq.persistence.enabled: false`, as in `minimal.yaml`):
  ```sh
  kubectl -n ryaxns delete pvc data-ryax-broker-0
  ```

- **The `rabbitmq:` values now configure the new broker.** `persistence.*`,
  `resources`, `tolerations`, `nodeSelector`, `affinity`, `priorityClassName` and
  `metrics.enabled` keep their meaning. Every other Bitnami key (`auth.*`, `image.*`,
  `clustering`, `plugins`, ...) is ignored: remove them. A `rabbitmq.image.repository`
  still naming a Bitnami image stops the render. The broker password is always the one
  in `ryax-broker-secret`, so a `rabbitmq.auth.password` set by the old troubleshooting
  guide does nothing. The broker also follows `global.tolerations`, `nodeSelector` and
  `affinity` now.

- **Uninstalling now takes one more step.** `helm uninstall` removes the operator at
  the same time as the broker, so nothing clears the `RabbitmqCluster` finalizer: the
  broker pod keeps running, and `helm uninstall --wait` times out. Delete the broker
  first, while the operator still runs:
  ```sh
  kubectl -n ryaxns delete rabbitmqcluster ryax-broker
  helm uninstall ryax -n ryaxns
  ```
  If an uninstall is already stuck, clear the finalizer:
  `kubectl -n ryaxns patch rabbitmqcluster ryax-broker --type merge -p '{"metadata":{"finalizers":[]}}'`.

- **If the cluster already runs a RabbitMQ Cluster Operator** that watches the Ryax
  namespace, set `rabbitmq.operator.enabled: false`. Two operators would reconcile the
  same broker.

- **Multi-site with Skupper:** the `ryax-broker-ext` and `ryax-minio-ext` connectors
  copied the pod selectors of the old broker and of MinIO when they were created. After
  the upgrade the first matches no pod, and the second matches the old MinIO, which
  refuses their connections. Recreate both on the main site right after the upgrade,
  before running workflows on remote sites:
  ```sh
  skupper -n ryaxns connector delete ryax-broker-ext
  skupper -n ryaxns connector create ryax-broker-ext 5672 --workload service/ryax-broker
  skupper -n ryaxns connector delete ryax-minio-ext
  skupper -n ryaxns connector create ryax-minio-ext 9000 --workload service/ryax-minio
  ```

- **GitOps (`global.secrets.create=false`):** `ryax-broker-cookie` is no longer read,
  delete it whenever you like. `ryax-broker-secret` keeps its keys; its `broker-user`
  and `rabbitmq-password` now seed the broker's user, so they must match the `broker`
  URL as before. With automated pruning off, prune the old broker resources in the same
  sync: the operator cannot create its `ryax-broker` Service while the Bitnami one is
  still there.

- **⚠️ The filestore moves from MinIO to versitygw, and the upgrade copies its
  objects.** Helm keeps the old MinIO, `ryax-minio`, running on its volume, and marks
  that volume so that neither Helm nor ArgoCD ever deletes it. The new filestore,
  `ryax-filestore`, gets a volume of its own, the size of MinIO's. Before it starts
  serving, its pod copies every object out of MinIO, checks that both sides list the same
  objects and sizes, and leaves a marker so that it never copies again. The address and
  the credentials do not change.

  **Downtime:** the services cannot reach the filestore until the copy is over. Without
  a pre-copy (below), count the time to read the whole MinIO volume once: on a test
  cluster, 750 MiB in 3,000 objects took a few seconds, and a large volume on network
  storage takes minutes. On a local k3s upgrade of a 26.9.0 install holding 58 MiB in
  410 objects, the copy itself took a second, the filestore was unreachable for 15 to
  50 seconds while MinIO restarted, and the whole of Ryax was back within 3 minutes,
  the broker switch being the longest part. The runner and studio restart while they
  wait, and their restart back-off can add up to five minutes once the copy is over.
  They reconnect on their own; to skip the back-off, restart them once the filestore is
  Ready:
  ```sh
  kubectl -n ryaxns rollout status deploy/ryax-filestore --timeout=24h
  kubectl -n ryaxns rollout restart deploy/ryax-runner deploy/ryax-studio
  ```
  Follow the copy with
  `kubectl -n ryaxns logs -f deploy/ryax-filestore -c migrate-from-minio`. The new
  volume's storage class must support user extended attributes, as ext4 and xfs do.

  If MinIO ran without persistence (`minio.persistence.enabled: false`), it has no
  volume to copy from, and its objects go away with it, as they did whenever its pod
  restarted. The `minio:` values are ignored now: remove them, but carry a
  `minio.persistence.storageClass` over as
  `filestore.migration.legacy.persistence.storageClass`, as the class of MinIO's volume
  cannot change. To give the filestore more room than MinIO had, set
  `filestore.persistence.size`.

- **Optional: pre-copy the objects to shorten the upgrade.** While 26.9.0 still runs,
  this copies the objects into the volume the filestore will use, and the upgrade then
  only copies what changed since. It can run several times, and it can be interrupted:
  the copy at the upgrade makes the result exact whatever it left. Use the same values
  file as for the upgrade:
  ```sh
  SIZE=$(kubectl -n ryaxns get pvc ryax-minio -o jsonpath='{.spec.resources.requests.storage}')
  helm template ryax oci://registry.ryax.org/release-charts/ryax-engine --version 26.10.0 \
    -n ryaxns -f values.yaml \
    --set filestore.migration.precopy.enabled=true \
    --set filestore.persistence.size="$SIZE" \
    --show-only charts/filestore/templates/precopy.yaml > precopy.yaml
  kubectl -n ryaxns delete job ryax-filestore-precopy --ignore-not-found
  kubectl -n ryaxns apply -f precopy.yaml
  kubectl -n ryaxns wait --for=condition=complete job/ryax-filestore-precopy --timeout=24h
  kubectl -n ryaxns logs job/ryax-filestore-precopy | tail -n 1
  kubectl -n ryaxns delete job ryax-filestore-precopy
  ```
  It creates the `ryax-filestore` volume, which the upgrade then takes over, and a Job
  that reads MinIO while Ryax keeps working. The upgrade refuses to start while that Job
  runs. Delete the Job once it is done, as above: as long as it exists, the volume
  cannot be deleted, which a rollback or an uninstall does. The pre-copy only shortens
  the upgrade when the volume is large: on the test cluster above, both copies took
  about a second. Offline, render it from the chart package (`helm template ryax
  ryax-engine-26.10.0.tgz ...`): it only uses the MinIO image 26.9.0 already ran.

- **Once 26.10.0 runs, decommission the old MinIO.** It only serves the copy, and
  makes a rollback possible until then. First check that the copy is done:
  ```sh
  kubectl -n ryaxns exec deploy/ryax-filestore -c versitygw -- cat /data/.ryax-migrated-from-minio
  ```
  It prints the date of the copy. Then remove MinIO, and delete its volume:
  ```sh
  helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine:26.10.0 \
    -n ryaxns --reuse-values --set filestore.migration.enabled=false
  kubectl -n ryaxns delete pvc ryax-minio
  ```
  The chart refuses to remove MinIO while no filestore pod has finished the copy
  (`filestore.migration.allowDecommissionWithoutCopy=true` forces it), and refuses
  `filestore.migration.enabled=false` on an upgrade from 26.9.0, which would delete
  MinIO's volume before the copy. Like any upgrade, the decommission restarts the
  runner and studio, and it restarts the filestore, unreachable for a few seconds.
  **After the decommission, a rollback to 26.9.0 is no longer possible** without
  restoring MinIO's volume from a backup.

- **Rolling back to 26.9.0 before the decommission** brings MinIO back on its volume,
  untouched, and deletes the filestore and its volume. Objects written since the
  upgrade are lost, unless you copy them back into MinIO first, while 26.10.0 still runs
  and no workflow runs. That copy rewrites every object, not only the new ones, so it
  takes about as long as the copy at the upgrade. Then delete the broker while its
  operator still runs, for the Bitnami broker cannot take its `ryax-broker` Service
  back otherwise, and roll back:
  ```sh
  kubectl -n ryaxns exec deploy/ryax-minio -- sh -c 'export HOME=/tmp
    mc=/opt/bitnami/minio-client/bin/mc
    $mc alias set new http://ryax-minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
    $mc alias set old http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
    $mc mirror --overwrite new/ryax-filestore old/ryax-filestore'
  kubectl -n ryaxns delete rabbitmqcluster ryax-broker
  helm rollback ryax <the 26.9.0 revision> -n ryaxns
  ```
  Without the `delete rabbitmqcluster`, the rollback stops part-way on
  `no Service with the name "ryax-broker" found`. Do not run a failed rollback again:
  each attempt leaves more of both versions behind. Upgrade to 26.10.0 again with the
  same values file, wait for every pod to be Ready, and roll back as above. Upgrading
  again later copies MinIO afresh. A `ryax-worker-k8s` already on 26.10.0 can stay
  there: on the test cluster it ran workflows with the rolled-back engine.

- **GitOps (ArgoCD, Flux):** the chart cannot see the cluster, so it always renders
  the old MinIO and its volume while `filestore.migration.enabled` is on, the default.
  The upgrade copies as above. If you changed `minio.persistence.size` or
  `storageClass`, set them as `filestore.migration.legacy.persistence.size` and
  `storageClass`, or the sync fails on the volume, which cannot shrink. To decommission,
  check the marker as above, then set `filestore.migration.enabled: false`: ArgoCD
  removes MinIO but keeps its volume (`Prune=false`), which you delete by hand. **A new
  GitOps install** has nothing to migrate: set `filestore.migration.enabled: false` from
  the start.

- **`global.security.allowInsecureImages` is gone.** It only served the Bitnami
  charts, and the engine chart no longer has any. Remove it from your values; it is
  ignored.

Then run the upgrade:
```sh
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine:26.10.0 \
  -n ryaxns \
  -f values.yaml
```

And each worker with its own values:
```sh
helm upgrade ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s:26.10.0 \
  -n ryaxns \
  -f worker.yaml
```
