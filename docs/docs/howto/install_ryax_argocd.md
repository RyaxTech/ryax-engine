# Install Ryax with ArgoCD

Ryax installs as an ordinary ArgoCD `Application`. This page covers what a GitOps
deployment needs that a plain `helm install` does not, and why.

A ready-to-edit manifest:

```yaml title="ryax-application.yaml"
--8<-- "examples/argocd/ryax-application.yaml"
```

```sh
kubectl apply -f ryax-application.yaml
argocd app sync ryax && argocd app wait ryax --health
```

That is the whole install. No bootstrap Job, no admission policies, no
pre-created PriorityClasses.

## Why a GitOps deployment is different

Two properties of ArgoCD (and Flux, and `helm template | kubectl apply`) shape
everything below.

**It renders without a cluster connection.** ArgoCD's repo server runs the
equivalent of `helm template`, where Helm's `lookup()` function returns nothing.
Any chart that generates a credential as `lookup ... | default (randAlphaNum 12)`
therefore mints a *new* value on every render.

**It has no install/upgrade distinction.** Every `pre-install` and `pre-upgrade`
Helm hook maps to ArgoCD's **PreSync** phase and runs on *every* sync, the first
one included. `helm install` skips `pre-upgrade` hooks; ArgoCD cannot.

## Supply the credentials yourself

Set `global.secrets.create: false` and create the secrets below before the first
sync — with [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets),
[external-secrets](https://external-secrets.io/), or plain `kubectl`. This is the
supported GitOps path: with it, the chart renders byte-identically every time, so
ArgoCD reports the app Synced and never rewrites a password.

All of these live in the release namespace unless noted. `ryaxns-execs` below is
whatever `global.ryax.userNamespace` is set to.

| Secret | Type | Keys |
|---|---|---|
| `ryax-datastore-secret` | Opaque | `datastore`, `datastore-db`, `datastore-user`, `datastore-pass`, `all-databases`, and `datastore-<db>`, `datastore-<db>-db`, `datastore-<db>-user`, `datastore-<db>-pass` for each of `repository`, `studio`, `authorization`, `runner` |
| `ryax-broker-secret` (release ns **and** `ryaxns-execs`) | Opaque | `broker`, `broker-user`, `rabbitmq-password` |
| `ryax-broker-cookie` | Opaque | `rabbitmq-erlang-cookie` |
| `ryax-minio-secret` | Opaque | `filestore`, `filestore-access`, `filestore-secret`, `root-user`, `root-password` |
| `api-jwt-secret-key` | Opaque | `jwt-secret-key` |
| `grafana-credentials` | Opaque | `admin-user`, `admin-password` |
| `runner-encryption-key` | Opaque | `encryption-key` |
| `studio-password-encryption-key` | Opaque | `encryption-key` |
| `repository-password-encryption-key` | Opaque | `encryption-key` |
| `ryax-registry-credentials` | Opaque | `htpasswd` |
| `ryax-registry-creds-secret` (release ns **and** `ryaxns-execs`) | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` |
| `ryax-registry-cert` (only when `registryCertSetup.enabled`) | `kubernetes.io/tls` | `tls.crt`, `tls.key` |
| `<release>-db-pass` (worker charts, only when `postgresql.enabled`) | Opaque | `password`, `postgres-password`, `datastore-worker-k8s` / `datastore-worker-ssh-slurm` |

The `datastore-*` and `broker` values are connection URLs, so they must agree
with the passwords in the same secret:

```
datastore-runner = postgresql://runner:<datastore-runner-pass>@ryax-datastore/runner
broker           = ampq://ryaxmq:<rabbitmq-password>@ryax-broker.<release ns>:5672/
```

Each credential also has its own flag, so you can hand over one at a time —
`datastore.datastoreSecretCreate`, `common-resources.jwtSecretCreate`,
`registry.credentials.createSecret`, and so on. See the chart README for the
full list.

!!! note "Keeping chart-generated secrets"
    If you would rather let the chart generate them, add the `ignoreDifferences`
    block commented out at the bottom of the reference manifest. It tells ArgoCD
    to ignore `/data` on every Secret so the re-rendered values are never pushed.
    It is name-less on purpose: some secret names are derived from the release
    name and change between chart versions.

    This does not cover **worker** database passwords on an in-place chart
    version bump — see [Cluster update](#cluster-update).

## Routing

The chart renders an Ingress per web-facing service, and a bundled Traefik to
serve them. If your cluster routes traffic some other way — Gateway API, a
service mesh, an external load balancer — turn both off:

```yaml
traefik:
  deployment:
    enabled: false
front:
  ingress:
    enabled: false
# ... same for authorization, runner, studio, repository, registry
```

Leaving the Ingresses on with no controller to serve them does more than clutter
the namespace: nothing fills in `.status.loadBalancer`, ArgoCD's built-in Ingress
health check reports **Progressing** forever, and because an app can only run one
operation at a time, every later sync — `selfHeal` included — queues behind it.

To point the Ingresses at a controller of your own instead, set the class
rather than turning them off:

```yaml
global:
  ingress:
    className: nginx      # or per service: front.ingress.className
```

It defaults to the bundled Traefik's own IngressClass (`<release>-traefik`).
Setting it to `""` renders no class at all, which hands the Ingresses to whatever
IngressClass the cluster marks default.

Two things to know if you *do* keep the bundled Traefik:

- Set `global.tls.hostname`. Without it the Ingress rules match **every** host,
  so once Traefik's Service gets an external address it answers for everything in
  the cluster, not just Ryax.
- Do not set `traefik.ingressClass.isDefaultClass: true`. The
  `ingressclass.kubernetes.io/is-default-class` annotation is cluster-scoped, so
  the bundled Traefik would claim every classless Ingress in every namespace —
  including other applications' — and serve them on whatever address its Service
  holds. Ryax's own Ingresses name the class explicitly, so they do not need it.
- Its Service is a `LoadBalancer` by default, which on a cluster running MetalLB
  or kube-vip takes the shared ingress address on 80/443. Set
  `traefik.service.spec.type: ClusterIP` when something else fronts the cluster —
  and note the key is `service.spec.type`: Traefik 41.x moved it into a free-form
  `spec` block, and the old `service.type` is silently ignored, leaving a
  LoadBalancer behind while the values file says otherwise.

## Placement on tainted or heterogeneous nodes

`global.tolerations`, `global.nodeSelector` and `global.affinity` are injected into
every Ryax pod, and each subchart can override them with its own `tolerations`,
`nodeSelector` and `affinity`.

```yaml
global:
  tolerations:
    - key: mycompany/mesh
      operator: Exists
      effect: NoSchedule
```

The bundled upstream subcharts do **not** read those globals — they have their own
values:

| Subchart | Where placement goes |
|---|---|
| `kube-prometheus-stack` | `prometheusOperator.*`, `prometheus.prometheusSpec.*`, `grafana.*` (each takes `tolerations`, `nodeSelector`, `affinity`) |
| `minio`, `rabbitmq` | `tolerations`, `nodeSelector`, `affinity` |
| `loki` | `singleBinary.tolerations`, `singleBinary.nodeSelector` |
| `tempo` | `tolerations`, `nodeSelector` |
| `alloy` | `controller.tolerations` (already tolerates every taint by default) |
| `traefik` | `tolerations`, `nodeSelector` |
| worker charts' `postgresql` | `postgresql.primary.tolerations`, `postgresql.primary.nodeSelector` |

## The first sync runs no migration, on purpose

The database-migration and scale-down Jobs are `pre-upgrade` hooks, so ArgoCD runs
them in the first PreSync — before the database they migrate exists. They detect
this (a marker ConfigMap the chart only creates in the Sync phase), log
`No previous Ryax release in this namespace`, and exit 0. The database is then
created and initialised by the normal Sync-phase resources, which is where a
first install gets its schema anyway.

From the second sync on the marker is there, the hooks run against a live
database, and a real failure fails the sync loudly instead of being skipped.

So a fresh install converges in **one** sync, and you should expect to see those
Jobs Completed with nothing done.

## Cluster update

A chart version bump works the same as any other ArgoCD sync: change
`spec.source.targetRevision` and let it sync. The migration hooks run in PreSync,
against the live database.

One caveat if you kept chart-generated secrets: the **worker** database password
is regenerated on each render, and the worker's PostgreSQL keeps the old one, so
the worker cannot authenticate after the bump. Either supply that secret yourself
(`postgresql.auth.createSecret: false`, the recommended path) or reset the
password in the database to match the regenerated secret.

## Verification

```sh
argocd app get ryax
argocd app diff ryax                       # empty: no perpetual drift

kubectl get pods -n ryaxns                 # all Ready, migration Jobs Completed
kubectl get pvc  -n ryaxns                 # all Bound
kubectl get cm ryax-release-marker -n ryaxns

# secrets are stable across re-sync: nothing may restart
argocd app sync ryax && argocd app sync ryax
kubectl get pods -n ryaxns
```

To check the chart's GitOps properties yourself, from a clone of the engine
repository:

```sh
./charts/gitops-checks.sh
```
