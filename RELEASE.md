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
  running. Once Ryax is back, delete the old broker volume:
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

- **If the cluster already runs a RabbitMQ Cluster Operator** that watches the Ryax
  namespace, set `rabbitmq.operator.enabled: false`. Two operators would reconcile the
  same broker.

- **Multi-site with Skupper:** the `ryax-broker-ext` connector copied the old broker's
  pod selector when it was created, so it matches no pod after the upgrade. Recreate it
  on the main site:
  ```sh
  skupper -n ryaxns connector delete ryax-broker-ext
  skupper -n ryaxns connector create ryax-broker-ext 5672 --workload service/ryax-broker
  ```

- **GitOps (`global.secrets.create=false`):** `ryax-broker-cookie` is no longer read,
  delete it whenever you like. `ryax-broker-secret` keeps its keys; its `broker-user`
  and `rabbitmq-password` now seed the broker's user, so they must match the `broker`
  URL as before. With automated pruning off, prune the old broker resources in the same
  sync: the operator cannot create its `ryax-broker` Service while the Bitnami one is
  still there.

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
