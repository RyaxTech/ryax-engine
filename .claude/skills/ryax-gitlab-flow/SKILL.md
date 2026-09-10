---
name: ryax-gitlab-flow
description: The GitLab and cluster workflow for Ryax — where the release process lives, how to open issues in roadmap and MRs in the service repos, how to cut a release candidate, and how to deploy to local or a remote cluster. Use when creating an issue or MR, cutting a release, or running helm against any Ryax cluster.
---

# The Ryax GitLab and deployment flow

Where things live:

| Thing | Where |
|---|---|
| Code | `ryax-tech/ryax/<service>` — `ryax-engine` is the umbrella, the rest are submodules |
| **All issues** | `ryax-tech/ryax/roadmap` — never in the code repos |
| **Release process** | Group wiki, `3-Release/howto-release` — the canonical reference |
| Release note | `RELEASE.md` in `ryax-engine`, reused as the tag message |

## glab

Everything below uses [`glab`](https://gitlab.com/gitlab-org/cli), the GitLab
CLI. Install it however your machine does, then `glab auth login` once.

Authenticate before assuming a failure is a permissions problem:

```sh
glab auth status
```

Push options (`git push -o merge_request.*`) are the alternative to `glab`, but
they reject any value containing a newline, so they cannot carry a multi-line MR
description. Prefer `glab ... --description "$(cat file.md)"`.

> **On NixOS**, tools are not installed imperatively and `glab` may be absent
> from PATH in non-login shells even when present on the system. Check first:
>
> ```sh
> grep -q '^ID=nixos' /etc/os-release && echo "NixOS"
> ```
>
> If so, see the `nixos-tools` skill: in short, `nix run nixpkgs#glab -- <args>`
> for one-offs, or put an existing store path on PATH for a loop or script:
> `export PATH="$(ls -d /nix/store/*glab*/bin | head -1):$PATH"`.
> This applies to every other tool named here — `helm`, `kubectl`, `uv`,
> `helm-docs` — not just `glab`.

## Issues

Always in `roadmap`, whatever repo the code lives in.

```sh
glab issue create --repo ryax-tech/ryax/roadmap \
  --title "..." --description "$(cat issue.md)" \
  --label "Triage" --label "BUG" \
  --assignee mercierm --yes          # mercierm is the PO
```

- `Triage` goes on everything new; the PO triages from there.
- The bug label is **`BUG`**, uppercase. `--label` is repeatable.
- Assign to the PO (`mercierm`) unless it is already owned.
- Check a label exists before using it — a wrong name is silently dropped:
  `glab api "projects/ryax-tech%2Fryax%2Froadmap/labels?per_page=100"`

Verify afterwards, because create reports success either way:

```sh
glab api "projects/ryax-tech%2Fryax%2Froadmap/issues/<iid>" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['labels'], [a['username'] for a in d['assignees']])"
```

## Merge requests

```sh
glab mr create --title "..." --description "$(cat mr.md)" \
  --source-branch <branch> --target-branch master \
  --assignee <reviewer> --remove-source-branch --yes
```

Link the issue **in the description**, with the full path:
`Closes ryax-tech/ryax/roadmap#1445`. The `--related-issue` flag only resolves
issues in the *same* project, so it does not work for the roadmap → service-repo
direction, which is the normal case here.

### Branch names must not contain `/`

The `tag_image` CI job tags the built image with the branch name, and a `/` is an
invalid Docker reference — `skopeo` fails with `invalid reference format`. Use flat
dash-separated names (`fix-nz-tabs-selectors`, `bump-fast-uri-3.1.6`). An MR's
source branch cannot be changed after creation, so getting this wrong means
renaming the branch, recreating the MR and closing the old one.

### Every `mr note create` blocks the merge

Each note is filed as its own **resolvable discussion**, and `ryax-repository`
requires discussions resolved before merging. Adding a cross-link or a note of
context silently flips the MR to `discussions_not_resolved` — and it reads like a
reviewer objection rather than your own doing. After any note, resolve it:

```sh
P=ryax-tech%2Fryax%2Fryax-repository
for DID in $(glab api "projects/$P/merge_requests/<iid>/discussions" | python3 -c "
import json,sys
for d in json.load(sys.stdin):
    n = d.get('notes') or [{}]
    if n[0].get('resolvable') and not n[0].get('resolved'): print(d['id'])"); do
  glab api --method PUT "projects/$P/merge_requests/<iid>/discussions/$DID?resolved=true"
done
```

Merge preconditions differ per repo — check rather than assume:

```sh
glab api "projects/<enc>/merge_requests/<iid>" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['detailed_merge_status'])"
```

`ryax-front` requires a **green pipeline** (`only_allow_merge_if_pipeline_succeeds`),
so a newly published CVE in `yarn.lock` blocks every MR until it is cleared —
add a `resolutions` entry in `package.json` and regenerate the lockfile.

## Cutting a release candidate

**Read the wiki page first** (`3-Release/howto-release`); it is the reference and
covers the prerequisites, the recipes and the production rollout. The wiki is a
**group** wiki: it accepts no merge requests, files are CRLF, and the only way to
publish is pushing `main`.

For a respin (rc*N* → rc*N+1*) the dependency-refresh prerequisites are skipped.
From `ryax-engine` on the release branch:

```sh
export VERSION=26.9.0-rc4
git submodule foreach git checkout master && git submodule foreach git pull
./jef.py tag_release --tag $VERSION      # tags + pushes every submodule
./jef.py charts_update -v $VERSION       # chart versions, Chart.lock, helm-docs READMEs
./jef.py update_api                      # API spec; must run AFTER charts_update
git commit -a && git push origin <release-branch>
```

Then tag the engine. `git tag -F` strips every `#` line as a comment, which eats
the markdown headings, and the convention is a `Ryax <version>` subject line:

```sh
{ printf 'Ryax %s\n\n' "$VERSION"; cat RELEASE.md; } > /tmp/tag.txt
git tag -a $VERSION -F /tmp/tag.txt --cleanup=whitespace
git push origin $VERSION
./jef.py wait_all_pipes $VERSION
```

**Check every submodule is on the commit you mean to release before tagging.**
`tag_release` force-tags each submodule's *current HEAD*, so a submodule left on a
feature branch ships an unmerged commit:

```sh
for m in core front repository studio intelliscale action-wrappers; do
  printf "%-16s %-24s pinned=%.8s now=%.8s\n" "$m" \
    "$(git -C $m rev-parse --abbrev-ref HEAD)" \
    "$(git ls-tree HEAD $m | awk '{print $3}')" "$(git -C $m rev-parse HEAD)"
done
```

Review the API spec diff before committing — an endpoint that **disappeared** is a
breaking change and belongs in the upgrade section of `RELEASE.md`:

```sh
git diff docs/docs/reference/ryax-spec.json
```

## Deploying to a cluster

**Always check which cluster you are pointed at first.** The kubeconfig holds a
dozen contexts including AWS EKS and production-looking ones; never assume.

```sh
kubectl config current-context
```

Reuse the release's existing values rather than reconstructing them:

```sh
helm get values ryax -n ryaxns -o yaml > values.yaml
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine \
  --version $VERSION -n ryaxns -f values.yaml --wait --timeout 15m
```

Remote clusters usually run a worker release too — upgrade it with its own values
and the matching version:

```sh
helm get values ryax-worker-k8s -n ryaxns -o yaml > worker.yaml
helm upgrade ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s \
  --version $VERSION -n ryaxns -f worker.yaml --wait
```

`--take-ownership` is only needed coming **from 26.7.0**, where three credential
secrets were Helm hook resources; see the upgrade section of `RELEASE.md`.

Verify the rollout rather than trusting `deployed`:

```sh
kubectl get pods -n ryaxns | grep -vE "Running|Completed"
kubectl get pods -n ryaxns --no-headers \
  | awk '$3!="Completed" {split($2,a,"/"); if (a[1]!=a[2] || $4>0) print}'
```

## The local cluster

k3s in Docker, per the README. `docker-compose up -d`, then:

```sh
export KUBECONFIG=$PWD/kubeconfig.yaml     # the local cluster ONLY lives here
kubectl get pods -A
helm install ryax oci://registry.ryax.org/release-charts/ryax-engine \
  -n ryaxns --create-namespace -f ./charts/ryax/env/minimal.yaml
```

UI at <http://localhost/app/login>, `user1` / `pass1`. `docker-compose down -v`
destroys it, including the database.

### Register a worker — the engine alone cannot run anything

An engine with no site registered accepts a deployment and then hangs in
*Deploying* forever with no error (roadmap#1445). Installing the worker is part
of the install, not an optional extra.

The site and node pool come first, then the worker chart is installed pointing at
their IDs. In the UI that is **Infrastructure** → **New Site** (Kubernetes, e.g.
"Local"), then **Add node pool** with a "k3s" pool and the resources to give Ryax
actions — say 1000 mCPU and 2GB — and copying both IDs out.

Headless, the same two objects over the API — this is the route to use when
driving the install from a terminal:

```sh
JWT=$(curl -s -X POST http://localhost/api/authorization/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"user1","password":"pass1"}' | jq -r .jwt)

SITE_ID=$(curl -s -X POST http://localhost/api/runner/sites \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"name":"Local","type":"KUBERNETES"}' | jq -r .site_id)

NODE_POOL_ID=$(curl -s -X POST "http://localhost/api/runner/sites/$SITE_ID/node-pools" \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"name":"k3s","cpu":1000,"gpu":0,"memory":2147483648,
       "energy_score":50,"performance_score":50,"cost_score":50,
       "filter_no_gpu_action":true}' | jq -r .node_pool_id)
```

**`cpu` is millicores and `memory` is bytes**, though the schema types both as
plain integers — 1000 mCPU and 2GiB above. Passing `2` for 2GB creates a pool
nothing can ever fit on. The response keys are `site_id` and `node_pool_id`, not
`id`. A site created by mistake is removed with
`POST /api/runner/sites/{site_id}/archive`, not DELETE.

Then, either way:

```sh
helm install ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s -n ryaxns \
  --set config.site.id=$SITE_ID \
  --set 'config.site.spec.nodePools[0].id'=$NODE_POOL_ID \
  --set 'config.site.spec.nodePools[0].selector.node\.kubernetes\.io/instance-type'=k3s
```

On a minimal local install add `--set global.monitoring.otlpEndpoint=""`, or the
worker retries trace exports to a `ryax-tempo` that is not deployed, forever.
Note it is the *endpoint* that has to be blanked, not
`global.monitoring.enabled` — that already defaults to `false` and only gates the
ServiceMonitor CRD, while `RYAX_OTLP_ENDPOINT` is templated unconditionally from
`otlpEndpoint`, which defaults to `ryax-tempo:4317`.

Then add <https://gitlab.com/ryax-tech/workflows/default-actions.git> to the
**Library**, scan it, and build a few triggers (*Emit Every*, *HTTP API JSON*,
*Run once*, *HTTP POST*) and actions (*Echo*, *Cat content of a file*).

`helm list -n ryaxns` should show **both** `ryax` and `ryax-worker-k8s`. Only one
means nothing will ever deploy.
