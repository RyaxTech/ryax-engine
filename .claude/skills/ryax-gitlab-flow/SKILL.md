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

## glab is not on PATH

It is installed but absent from non-login shells. Either works:

```sh
nix run nixpkgs#glab -- <args>                          # slower, always available
export PATH="$(ls -d /nix/store/*glab*/bin | head -1):$PATH"   # for loops and scripts
```

Already authenticated for gitlab.com. Push options (`git push -o merge_request.*`)
reject any value with a newline, so they cannot carry a multi-line MR body — use
`glab` with `--description "$(cat file.md)"`.

## Issues

Always in `roadmap`, whatever repo the code lives in.

```sh
glab issue create --repo ryax-tech/ryax/roadmap \
  --title "..." --description "$(cat issue.md)" \
  --label "Triage" --label "BUG" \
  --assignee mercierm --yes
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
  --assignee mercierm --remove-source-branch --yes
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

In the UI: **Infrastructure** → **New Site**, create a Kubernetes site (e.g.
"Local"), then **Add node pool** with a "k3s" pool and the resources to give Ryax
actions — say 1000 mCPU and 2GB. Copy both IDs out of the UI, then:

```sh
SITE_ID="GET ME FROM UI"
NODE_POOL_ID="GET ME FROM UI"
helm install ryax-worker-k8s oci://registry.ryax.org/release-charts/ryax-worker-k8s -n ryaxns \
  --set config.site.id=$SITE_ID \
  --set 'config.site.spec.nodePools[0].id'=$NODE_POOL_ID \
  --set 'config.site.spec.nodePools[0].selector.node\.kubernetes\.io/instance-type'=k3s
```

Then add <https://gitlab.com/ryax-tech/workflows/default-actions.git> to the
**Library**, scan it, and build a few triggers (*Emit Every*, *HTTP API JSON*,
*Run once*, *HTTP POST*) and actions (*Echo*, *Cat content of a file*).

`helm list -n ryaxns` should show **both** `ryax` and `ryax-worker-k8s`. Only one
means nothing will ever deploy.
