We are proud to announce the release of:

✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨
# Ryax 26.10.0
✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨

GPU requests by model, memory and share of a card, a random initial admin password, a broker that no longer depends on Bitnami, and a round of fixes for imports, stuck executions and failed deployments.

## New features

### GPU scheduling by model, memory and share of a card

Ryax used to know a GPU only as a count, plus an opaque MIG profile name that had to match exactly. This release describes GPUs the way users think about them, from the action that asks to the node pool that answers.

- **Actions can ask for a kind of GPU.** In `ryax_metadata.yaml`, `spec.resources.gpu` still takes a number, and now also takes an object with a `count`, a `brand`, a `model`, a `memory` (with a unit, for example `40G`) and a `compute_fraction` (a share of one card, between 0 and 1, exclusive of 0). Everything in it is optional and describes **one** GPU: `count: 2` with `memory: 40G` means two cards of 40 GB each, not 80 GB across two. `gpu: 2` keeps its meaning of two GPUs of any kind. Brand and model must match the catalog; an action that names one no node pool has simply finds no place to run. A request with an unknown key, or a memory without a unit, is rejected when the action is scanned.
- **Node pools declare their card.** A GPU node pool now records its catalog model next to its partition (`full` or a MIG profile), so Ryax knows how much memory and compute one GPU of the pool really gives. The new `GET /api/runner/gpu-models?search=a100 1g` lists the catalog as one flat, searchable list (brand, model, partition, memory, compute share), and the node pool form in the web interface now picks the GPU with one searchable select. Existing node pools keep working: one with no recorded model stays eligible for every request, and is simply treated as of unknown size, never as too small. Fill in the model to get precise matching.
- **Placement takes any partition that is big enough, and the tightest one by default.** A recommendation of "3g.40gb" used to demand exactly that profile and fail when no pool had it; now any partition that meets the request will do. New setting `RYAX_SCHEDULER_GPU_FIT_POLICY` on the Runner: `best_fit` (the default) picks the pool that wastes the least of a card, leaving large partitions free for the actions that need them; `first_fit` keeps the previous behaviour of taking the best-scoring pool that fits. GPU requests are also now checked against the pool's CPU, memory and time, which they never were.
- **IntelliScale recommends a share of a card, not a MIG profile.** It now recommends GPU memory (the observed peak plus 10%) and a compute share, and Ryax rounds them up to a partition your pools actually offer. This also works on cards that do not split in sevenths such as the A30.
- **Recommendations are learned per piece of hardware, not per site.** A recommendation is only valid for the machine it was measured on, so IntelliScale now keeps one model per GPU model (for the GPU share) and per instance type (for CPU and memory). Two node pools of one site with different cards no longer contaminate each other, and two sites with the same card now learn together. The Runner asks for the recommendation after it has picked a candidate pool, one answer per pool, instead of merging every site's answer beforehand. Nothing fragments on upgrade: pools with no recorded GPU model, and HPC sites, share one model as before.
- **Autoscaled GPU nodes can be kept out of use until they are ready.** An autoscaled GPU node is reported `Ready` long before its driver and MIG layout are in place, so actions landing on it got a whole GPU instead of their slice. The Kubernetes worker chart can now hold new GPU nodes behind a startup taint and release them only when the GPU stack is usable and the MIG layout is the one the pool asked for. Off by default: see `gpuReadiness` and the new [GPU node pools and MIG](https://docs.ryax.tech/howto/gpu_node_pools/) guide.
  ([roadmap#1421](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1421),
  [roadmap#1458](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1458),
  [roadmap#1469](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1469),
  [roadmap#1428](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1428))

### Security and operations

- **The initial admin password is random.** Every installation used to boot with the same `user1` / `pass1` — hard-coded in the service, never set by the chart, and published in the README and the install guide. The chart now generates one per installation into the `ryax-admin-credentials` secret, and `helm install` prints the command to read it back. The account is `admin`. Existing installations keep their users and passwords: the secret is only ever read when the user table is empty, which is the very first start. The Edit password window now warns that changing the password does not update that secret.
  ([roadmap#1423](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1423))
- **`helm install` prints its notes.** `NOTES.txt` had always sat at the chart root rather than in `templates/`, where Helm is the only place it looks, so no install had ever printed anything. It now carries the admin credentials command and the Grafana one.
- **The broker no longer runs on a Bitnami image.** It ran on `bitnamilegacy/rabbitmq`, which Bitnami no longer updates. It is now a `RabbitmqCluster` run by the official [RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview) (2.23.0) on the official `rabbitmq:4.3.6-management` image. The chart deploys the operator in the Ryax namespace, watching that namespace only, and it needs neither cluster-wide rights nor cert-manager. The services reach the broker at the same address with the same credentials. **This needs one command before upgrading, see below.**
  ([roadmap#1320](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1320))
- **The `Authorization: Bearer <token>` header works on every service.** The Authorization and Repository services answered 401 to the form our own README documents, while Runner and Studio accepted it. All four now agree, and a header that is only `Bearer` answers 401 on Studio instead of 500.
  ([roadmap#1453](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1453))
- **Deploying a workflow that is already deploying returns 409 with its state.** `POST /workflows/{id}/deploy` answered 400 for this, the same code as for an invalid workflow, so clients had to match the error text. It now answers 409 `{"error": "Workflow can't be deployed at this status", "deployment_status": "Deploying"}`. An invalid workflow still gets 400. See the upgrade notes.
  ([roadmap#1467](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1467))

## Bug fixes and Improvements

- **An install reached through a proxy or by IP answers again.** 26.9.0 restricted the Ingresses to `global.tls.hostname`, so any other name got a 404. They are now restricted only to `global.ingress.hosts`, which is empty (any host) by default. The documentation gained a how-to for [running Ryax behind a proxy](https://docs.ryax.tech/).
  ([roadmap#1448](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1448))
- **Importing a workflow keeps its addons.** An imported workflow was valid and showed Deployed, but its HTTP services had no Ingress and every URL answered 404, because addons were dropped. Export now writes the editable addon values (`addons_inputs_values`), and import restores them; packages exported before this release still import and get the addons' defaults. A value for an addon parameter the action does not have now answers 400 instead of being silently dropped.
  ([roadmap#1464](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1464))
- **Importing a workflow with a numeric or directory input value no longer fails with a 500.** A value such as `max_tokens: 1024` or a directory input in a re-imported export now imports correctly, and a bad package answers 400. The deprecated `table` input/output type is removed; existing values are converted to `file`.
  ([roadmap#1465](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1465),
  [roadmap#1468](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1468))
- **An HTTP service trigger is no longer killed at startup.** Addon inputs and resources were frozen at the first deploy of an action and shared by every workflow using it, so a workflow using the HTTP addon on an action first deployed without it lost the addon's inputs. Each workflow action now owns its own, and two workflows can use one action with different addons and resources. Addon values are merged parameter by parameter: a value set in the interface beats the action's, which beats the addon default.
  ([roadmap#1463](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1463))
- **A workflow can be undeployed when it has several running deployments.** Undeploy used to fail and leave Studio in "Undeploying", with the portal and trigger views answering 500. It now stops all of them, and a stopped deployment is never brought back to running by a late trigger event. The leftover `PAUSED` state, which nothing has set since 26.7.0, is retired.
  ([roadmap#1337](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1337))
- **A failed deployment says why.** A deployment whose trigger failed (no site registered, trigger error, trigger cancelled by itself, deployment that could not even be created) stayed in "Deploying" forever or went back to "not deployed" with no explanation. It now fails and Studio shows `The trigger '<name>' failed: <reason>`.
  ([roadmap#1445](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1445),
  [roadmap#1466](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1466))
- **Executions that outlive their time allotment are cancelled.** An execution whose Worker crashed or never reported its end stayed running forever, holding its resources. The Runner now cancels any action execution still running 5 minutes past its allotment (`RYAX_EXECUTION_REAPER_GRACE_SECONDS`, checked every 60 seconds, `RYAX_EXECUTION_REAPER_INTERVAL_SECONDS`; a grace of 0 disables it). Triggers, which have no allotment, are not touched.
  ([roadmap#1299](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1299))
- **Stopping a workflow ends all its executions.** Trigger runs of an http trigger stayed RUNNING when the trigger ended gracefully or crashed, and executions stayed STOPPING when the Worker did not know them or had restarted. They now end as cancelled, and no longer enter the retry chain. Executions already stuck are not repaired and need a one-off cleanup.
  ([roadmap#1473](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1473))
- **Execution logs come out in the order the action wrote them.** The Workers now number each batch of log lines and the Runner reads them in that order. Logs stored before the upgrade keep their previous order.
  ([roadmap#1449](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1449))
- **Upgrades no longer deadlock on Grafana and MinIO.** Their `ReadWriteOnce` volume stopped the new pod from starting while the old one still held it, so `helm upgrade --wait` timed out and marked the release failed. Both now replace their pod instead of rolling it.
  ([roadmap#1451](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1451))
- **The registry garbage collector works again.** It pointed at a configuration path that does not exist since the registry moved to v3, and hid the failure behind a success message, so no image was ever collected. A failing run now fails its Job.
  ([roadmap#1294](https://gitlab.com/ryax-tech/ryax/roadmap/-/issues/1294))
- **Security and dependencies.** The web interface's advisories are cleared (Angular 21.2.25, axios 1.20, undici 6.29, piscina 5.3, adm-zip 0.6.1, brace-expansion 2.1.6; the unpatched `braces` advisory only affects the build tooling and is tracked), and Python dependencies and nixpkgs (26.05) are refreshed across all services. Observability charts: kube-prometheus-stack 89.x (Grafana 13), Alloy 1.13, Traefik 41.6.
- **Documentation.** New GPU node pools guide, rewritten IntelliScale reference, `global.ingress.hosts`, proxy configuration and the RabbitMQ operator in the install, airgap and ArgoCD guides.

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
  `secretKeyRef`s are `optional`. The service also no longer has a built-in fallback for the initial user name (now `admin` when unset, not `user1`) nor for the JWT signing key: the chart has always injected the latter from `api-jwt-secret-key`, but a deployment that starts the services without the chart must now set `RYAX_JWT_SECRET_KEY`.

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

- **Grafana 13 (kube-prometheus-stack 89).** The bundled Grafana runs the `-distroless` image with a read-only root filesystem and an `emptyDir` on `/tmp`. `GF_*__FILE` environment variables and `GF_INSTALL_PLUGINS` are no longer supported. The Ryax values set none of them, and the plugins (`grafana-piechart-panel`, `grafana-clock-panel`, `vonage-status-panel`) are now preinstalled synchronously at startup, so no values change is needed, but check that the Grafana pod starts. If your own overrides set `GF_*__FILE`, `GF_INSTALL_PLUGINS` or an `extraVolumeMounts` on `/tmp`, migrate them first. The rollout also replaces the Grafana and MinIO pods instead of rolling them, so both are briefly unavailable during the upgrade.

- **Kubernetes worker: the MIG auto-labeler is removed.** The values `config.MIG` and `labeler` are gone, along with the node-labeler DaemonSet. If you relied on it to turn a `gpu-pool-mig-*` node label into `nvidia.com/mig.config`, label the GPU nodes with `nvidia.com/mig.config` yourself (cloud node-pool labels are the usual way), as the NVIDIA GPU Operator's MIG Manager expects. Remove both keys from your worker values. To keep actions off GPU nodes that are not ready yet, see the new opt-in `gpuReadiness` values: enable it **before** adding the startup taint to the node pool, as a tainted pool with the gate off never runs anything.

- **GPU node pools: record the card, and mind the renamed field.** Existing pools keep working without it, but record the catalog `gpu_model` on each GPU pool (web interface, or `GET /api/runner/gpu-models` then the node pool API) to get precise matching and per-hardware recommendations. If your clusters are all A30 (4 compute slices), also set `intelliscale.config.algorithm_configs.simple_mig_recommender.total_compute_slices` to 4 for pools with no recorded model. Placement now defaults to `best_fit`; to keep the previous behaviour set `RYAX_SCHEDULER_GPU_FIT_POLICY=first_fit` through `runner.extraEnv`.

- **API users:**
  - `POST /workflows/{id}/deploy` returns **409** (with `deployment_status` in the body) instead of 400 when the workflow is already deploying, deployed or undeploying. A client that matched the 400 text must handle 409 instead.
  - Node pools take and return `gpu_count`, not `gpu` (the stored value is migrated). A client that still sends `gpu` when creating a node pool gets a 422.
  - New root endpoints `/api/runner/node-pools` (filters on GPU, site, CPU and memory; the GPU is named by `gpu_config_id`) and `GET /api/runner/gpu-models` returns a flat list. The nested `/sites/{id}/node-pools` routes remain, marked deprecated.
  - `GET /modules/{id}` and workflow action views now return `gpu_brand`, `gpu_model`, `gpu_memory_gb` and `gpu_compute_fraction` in `resources`.
  - The `table` input/output type no longer exists.
  - `Authorization: Bearer <token>` is accepted by all services.

- **Registry garbage collection now actually runs.** The first scheduled run after the upgrade removes every untagged image left in the registry, and a failing run now shows as a failed Job.

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
