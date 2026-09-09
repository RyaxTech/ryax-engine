We are proud to announce the release of:

✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨
# Ryax 26.9.0
✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨ ✨

This release makes Ryax easier to run the way you already run the rest of your
platform. The Helm chart is now installable by ArgoCD and other GitOps engines,
you choose which Ingress controller serves Ryax instead of having one imposed on
the cluster, and every Ryax pod can be steered onto the nodes you want. The web
interface has been rebuilt on a current Angular, the last two services moved to
FastAPI, the published API reference is now generated from the service sources,
and Prometheus finally keeps its metrics across restarts.

## New features

### GitOps installs with ArgoCD and Flux

The chart can now be rendered without a cluster connection, which is what
ArgoCD's and Flux's repo servers do. Previously the generated credentials came
from `lookup()`, which returns nothing in that situation, so every render minted
fresh passwords and rolled them out to the running pods.

Set `global.secrets.create=false` to supply every credential yourself --- with
sealed-secrets, external-secrets, or a plain `kubectl create` --- under the
secret names documented in the values files. The worker charts get the same
option, and the bundled PostgreSQL has its own `createSecret` switch.

### Choose the Ingress controller that serves Ryax

Ryax's Ingresses now name their IngressClass explicitly through
`global.ingress.className`, which defaults to the bundled Traefik. Point it at
your own controller, override it for a single service with
`<subchart>.ingress.className`, or turn an Ingress off entirely with
`<subchart>.ingress.enabled=false`.

The bundled Traefik also no longer registers itself as the cluster-wide default
IngressClass. That setting is cluster-scoped, so it used to claim every Ingress
in every namespace that did not name a class --- including ones belonging to
applications that have nothing to do with Ryax.

### Place Ryax pods where you want them

`global.tolerations` and `global.affinity` are injected into every Ryax pod, so
Ryax can run on tainted or dedicated nodes. Both can be overridden per subchart,
and the worker charts gained their own `tolerations` and `nodeSelector`.

### Per-site action image registry

The registry an action image is pulled from is now a property of the site that
runs it, rather than a single global address. A worker whose nodes cannot resolve
the address the Runner recorded overrides it with `internalRegistryOverride` in
its own values, and the Runner resolves the registry host at deploy time.

### A modernised web interface

The front end moved from Angular 16 to Angular 21, with Nx 22 and TypeScript
5.9. The interface behaves as before, on a supported and maintained toolchain.

### The published API reference is generated from the code

<https://docs.ryax.tech/reference/api/> and the
[`ryax-spec.json`](https://docs.ryax.tech/reference/ryax-spec.json) it is built
from are now generated from the Authorization, Repository, Studio and Runner
sources on every release, so they cannot drift from the running services again.
The document that shipped with 26.7.0 still described 26.2.0; the regenerated
one covers 89 endpoints, documents the `/api/...` paths as the ingress actually
serves them, and includes the Site and Node Pool management endpoints the old
document was missing.

## Bug fixes and Improvements

- Prometheus keeps its metrics across restarts. The 10Gi volume request had been
  one level too high in the values for a long time, so it was silently ignored
  and Prometheus ran on an `emptyDir`, losing every metric on each restart,
  reschedule and chart upgrade.
- Kubernetes worker database upgrades work again: the PostgreSQL service name and
  the database URL now agree, so the migration init container can resolve its
  host.
- IntelliScale no longer restarts when an unrelated part of the configuration
  changes.
- The Runner and Repository APIs migrated to FastAPI and pydantic, joining the
  Studio, which also dropped marshmallow. The Authorization service is now part
  of the core service, one less component to track.
- The V1 worker protocol and the legacy worker module are removed.
- Container image publishing is reproducible again. Image pushes failed
  intermittently with `Digest did not match` and missing layer tars, because the
  Python dependency closure was built by a derivation that downloaded from the
  network: the same store path held different bytes on different runners.
- Security fixes across the stack: `fast-uri` 3.1.6 and the `js-yaml`, `svgo`
  and `extract-zip` advisories in the front end, the image CVE scan pointed back
  at the right sources after a repository rename, and vulture and bandit now run
  in the core service's own CI.
- Observability dependencies updated: kube-prometheus-stack 88.x, Loki 7.3,
  Grafana Alloy 1.12 and Traefik 41.5.

## Upgrade to this version

To upgrade your main cluster, find the values file from your previous install or
restore it using:
```sh
helm get values -n ryaxns ryax --output yaml > values.yaml
```

Admins should take care of the following elements when upgrading to this version:

- **If your values customise Prometheus storage**, move the block from
  `kube-prometheus-stack.prometheus.storage.volumeClaimTemplate` to
  `kube-prometheus-stack.prometheus.prometheusSpec.storageSpec`, and include
  `accessModes: ["ReadWriteOnce"]`. The old key is not one the subchart reads, so
  it never took effect. Prometheus gets a PersistentVolumeClaim on upgrade;
  because it was previously running on an `emptyDir` there is no metric history
  to preserve.
- **If you relied on the bundled Traefik serving your own Ingresses** without
  naming an IngressClass, it no longer claims them. Name the class explicitly on
  those Ingresses (`<release-name>-traefik`), or mark your own controller as the
  cluster default.
- **If you run a SLURM_SSH worker on a private network**, the
  `internalRegistryOverride` default changed from `ryax-registry:5000` to empty.
  Set it explicitly in your worker values to keep pulling action images through
  the in-cluster registry.
- **On a Kubernetes worker whose nodes cannot resolve the registry address the
  Runner records**, set `internalRegistryOverride` to `127.0.0.1:30012` to reach
  the bundled registry through its NodePort.
- **API users:** the Repository V1 endpoints `/api/repository/modules` and
  `/api/repository/modules/{module_id}` are removed. Use the `/api/repository/v2/`
  endpoints; the current set is published at
  <https://docs.ryax.tech/reference/ryax-spec.json>.
- **If you are still on the pre-26.7.0 `ryax-worker` chart**, migrate to
  `ryax-worker-k8s` or `ryax-worker-slurm-ssh` following the 26.7.0 release note
  before upgrading: the V1 worker protocol is gone in this release.

Then, run the upgrade with:
```sh
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine:26.9.0 \
  -n ryaxns \
  -f values.yaml
```

And upgrade each worker with its own values, for example:
```sh
helm upgrade ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s:26.9.0 \
  -n ryaxns \
  -f worker.yaml
```
