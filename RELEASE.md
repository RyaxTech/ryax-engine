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

<!-- Nothing recorded yet for 26.10.0. -->

## Upgrade to this version

Restore your values file if you do not have it:
```sh
helm get values -n ryaxns ryax --output yaml > values.yaml
```

Admins should take care of the following elements when upgrading to this version:

- **A new GitOps install needs one more secret.** With `global.secrets.create=false`,
  create `ryax-admin-credentials` (keys `admin-user` and `admin-password`) before the
  first sync, or set `authorization.adminUsername` and `authorization.adminPassword`.
  Without it the authorization pod stops with `No initial admin password configured`.
  An **existing** installation needs nothing — it never seeds again, and both
  `secretKeyRef`s are `optional`.

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
