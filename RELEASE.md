We are proud to announce the release of:

✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨
# Ryax 26.9.0
✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨

Stability and security updates, plus a GitOps-ready Helm chart and a rebuilt web interface.

## New features

- **GitOps installs.** The chart renders without a cluster connection, so ArgoCD and
  Flux no longer mint fresh credentials on every sync. Set `global.secrets.create=false`
  to supply the secrets yourself.
- **Pick the Ingress controller.** Ryax's Ingresses name their class through
  `global.ingress.className`, overridable per service or switched off with
  `<subchart>.ingress.enabled=false`. The bundled Traefik no longer registers itself as
  the cluster-wide default class.
- **Pod placement.** `global.tolerations` and `global.affinity` apply to every Ryax pod,
  with per-subchart overrides; the worker charts gained `tolerations` and `nodeSelector`.
- **Per-site action registry.** A worker whose nodes cannot resolve the registry the
  Runner recorded overrides it with `internalRegistryOverride`.
- **Rebuilt web interface.** Angular 16 → 21, Nx 22, TypeScript 5.9.
- **Generated API reference.** <https://docs.ryax.tech/reference/api/> is now built from
  the service sources on every release, so it cannot drift again — the 26.7.0 document
  still described 26.2.0.

## Bug fixes and Improvements

- Action builds no longer get stuck in "Starting". When the builder reported back before
  the queue had committed the action's status, the move to "Building" was lost, and the
  successful build that followed was refused as well — leaving the action in "Starting"
  for good and, since builds run one at a time, blocking every action queued behind it.
  The Library now also offers Cancel Build while an action is "Starting" or "Cancelling",
  so a stalled build can be cleared by hand.
- Prometheus keeps its metrics across restarts: the volume request sat one level too high
  in the values and was silently ignored, leaving it on an `emptyDir`.
- Kubernetes worker database upgrades work again — the PostgreSQL service name and the
  database URL now agree, so the migration init container resolves its host.
- IntelliScale no longer restarts on unrelated configuration changes.
- The Runner and Repository APIs moved to FastAPI and pydantic; Studio dropped
  marshmallow; the Authorization service is now part of the core service.
- The V1 worker protocol and the legacy worker module are removed.
- Container image publishing is reproducible again, fixing intermittent
  `Digest did not match` failures.
- Security fixes across the stack, including `fast-uri` 3.1.6 and the `js-yaml`, `svgo`
  and `extract-zip` advisories, plus a repaired image CVE scan.
- Observability dependencies updated: kube-prometheus-stack 88.x, Loki 7.3, Alloy 1.12,
  Traefik 41.5.

## Upgrade to this version

Restore your values file if you do not have it:
```sh
helm get values -n ryaxns ryax --output yaml > values.yaml
```

Admins should take care of the following elements when upgrading to this version:

- **`--take-ownership` is required when upgrading from 26.7.0.** Three credential
  secrets used to be created as Helm *hook* resources, which Helm never records as part
  of the release: the Studio password encryption key in the main chart, and the
  PostgreSQL credentials in both worker charts. They are now ordinary chart-managed
  resources, so Helm finds them un-owned and refuses the upgrade with
  `invalid ownership metadata` unless you let it adopt them. Adoption preserves the
  existing values -- the templates read the current secret before falling back -- so the
  encryption key and the database passwords are unchanged.
- **Prometheus storage:** if your values set
  `kube-prometheus-stack.prometheus.storage.volumeClaimTemplate`, move it to
  `prometheus.prometheusSpec.storageSpec` and add
  `accessModes: ["ReadWriteOnce"]`. The old key was never read. There is no metric
  history to preserve, since Prometheus was running on an `emptyDir`.
- **Traefik:** the bundled instance no longer claims Ingresses that name no class. Name
  `<release-name>-traefik` on your own Ingresses, or mark your controller as the cluster
  default.
- **Workers relying on the old `internalRegistryOverride` default:** on the SLURM_SSH
  chart it changed from `ryax-registry:5000` to empty. If you never set it yourself, set
  it explicitly to keep pulling through the in-cluster registry. On a Kubernetes worker
  whose nodes cannot resolve the Runner's address, use `127.0.0.1:30012`.
- **API users:** the Repository V1 endpoints `/api/repository/modules` and
  `/api/repository/modules/{module_id}` are removed; use `/api/repository/v2/`.
- **Still on the pre-26.7.0 `ryax-worker` chart:** migrate to `ryax-worker-k8s` or
  `ryax-worker-slurm-ssh` first, as the V1 worker protocol is gone.

Then run the upgrade:
```sh
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine:26.9.0 \
  -n ryaxns \
  --take-ownership \
  -f values.yaml
```

And each worker with its own values:
```sh
helm upgrade ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s:26.9.0 \
  -n ryaxns \
  --take-ownership \
  -f worker.yaml
```
