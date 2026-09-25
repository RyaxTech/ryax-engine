---
name: ryax-issue-verification
description: How to settle whether a Ryax roadmap issue is still real — triage from the code, stand up a local instance, drive the REST API to build workflows and run them, and measure front-end bugs in Chrome. Use when asked to check if an issue is fixed, to sweep old or stalled issues, or to reproduce a reported bug on a working instance.
---

# Verifying Ryax issues

Issues live in `ryax-tech/ryax/roadmap`; the code lives in `ryax-engine` and its
submodules. Settling "is this still broken?" goes in three escalating steps, and most
issues never need step 3.

| Step | Settles | Cost |
|---|---|---|
| 1. Read the code | Chart shape, missing endpoints, dead config, unticked TODOs | seconds |
| 2. Local instance + REST API | Anything the backend or a wrapper does | ~20 min to first run |
| 3. Browser | Rendering and UI-only behaviour | slow and flaky — see the warnings |

Write the verdict as a comment on the issue whatever the outcome. A "still broken" comment
with the exact file and line is worth as much as a close.

## Skills and tooling this leans on

| Need | Where it comes from |
|---|---|
| `glab`, `helm`, `kubectl`, `uv` not on PATH | the `nixos-tools` skill — nothing is installed imperatively here |
| Opening the issue comment or an MR | the `ryax-gitlab-flow` skill — issues live in `roadmap`, and closing them is normally the human's call |
| Installing the engine and a worker | `ryax-gitlab-flow` again, plus the README for the k3s-in-Docker route |
| Driving Chrome | the `claude-in-chrome` skill — see step 3, it must be invoked before any browser tool exists |

`glab` is authenticated but absent from PATH in non-login shells:

```sh
export PATH="$(ls -d /nix/store/*glab*/bin | head -1):$PATH"
```

## Step 1: what the code alone can settle

Plenty of stalled issues are decidable without a cluster. Some patterns that paid off:

- **A TODO list in the description.** Check each box against the tree. `#1261` listed four
  services for Helm pre-upgrade hooks; two still had migration `initContainers` and
  `strategy: Recreate`, so the issue was accurate and stayed open.
- **A config knob that is set but never read.** `#1429` ("deployment timeout is not
  enforced"): `RYAX_DEPLOYMENT_K8S_TIMEOUT_SEC` is loaded in `runner/app.py` and grepping
  `deployment.k8s` across `core/ryax` finds no consumer, while the neighbouring
  `user_namespace` *is* wired through `container.py`. That asymmetry is the proof.
- **A function the traceback names.** If the frame is gone and the surrounding code was
  rewritten, the issue is *probably* fixed — but you cannot close on that alone. Reproduce
  it (step 2) or say plainly that you could not.
- **A named CSS property or symbol.** Grep it. Beware: it may still exist but have *moved*
  (`#1211`'s `overflow: scroll` migrated from `#ryax-variable-list` to a nested `th, td`
  rule). Re-point the issue's "possible fix" when that happens.

Get provenance before claiming a fix shipped:

```sh
git log -1 --format="%h %ad %s" --date=short -S "<the string that changed>" -- <path>
git tag --contains <sha> | head -3          # which release carries it
```

A fix landing *after* the issue was filed is the strongest evidence you can offer.

## Step 2: a local instance

### Do not assume port 80 is free

The `core` dev stack (`core/docker-compose.yml`, used by `./test.sh --init`) runs its own
k3s holding **80, 443 and 6443**. The engine's `docker-compose.yml` wants the same ports,
so a second cluster will not come up. Check first:

```sh
docker ps --format "{{.Names}}\t{{.Ports}}" | grep k3s
```

If the core k3s is up and idle (`helm list -A` shows only traefik), install into it rather
than tearing down someone's dev stack. Its kubeconfig is `core/kubeconfig.yaml`. The one
difference that matters: the engine's compose starts k3s with `--disable=traefik` so the
chart's own Traefik owns 80/443, while the core one keeps k3s's Traefik. So disable the
bundled one and borrow the cluster's:

```sh
export KUBECONFIG=$PWD/core/kubeconfig.yaml
helm install ryax oci://registry.ryax.org/release-charts/ryax-engine \
  -n ryaxns --create-namespace -f ./charts/ryax/env/minimal.yaml \
  --set traefik.deployment.enabled=false \
  --set global.ingress.className=traefik \
  --set global.monitoring.otlpEndpoint="" --wait --timeout 20m
```

Otherwise follow the README: `docker-compose up -d`, then
`export KUBECONFIG=$PWD/kubeconfig.yaml`.

Register the site and node pool and install the worker exactly as `ryax-gitlab-flow`
describes — an engine with no worker accepts a deployment and hangs in *Deploying* forever.

### Log in: the header is not `Bearer`

The README's API snippet says `Authorization: Bearer $JWT`. The **runner** and **studio**
accept that; **authorization** and **repository** answer 401 `{"error":"Access denied"}`.
The front sends the raw token (`headers.set('Authorization', token)`), so do the same —
it is the one form every service accepts:

```sh
JWT=$(curl -s -X POST http://localhost/api/authorization/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"user1","password":"pass1"}' | jq -r .jwt)
curl -s http://localhost/api/studio/workflows -H "Authorization: $JWT"   # no "Bearer "
```

This split is tracked as **ryax-tech/ryax/roadmap#1453** — the runner has a `bare_token()`
helper that strips the prefix, the studio has its own copy, and the other two have none. If
that is fixed, `Bearer` becomes safe everywhere and this paragraph can go.

Credentials depend on the version: **26.9.0 and earlier boot with `user1` / `pass1`**. The
per-install random password in `ryax-admin-credentials` is newer — if that secret is
missing, you are on the old behaviour, not looking at a bug.

### `minimal.yaml` sets `logLevel: error` — silence means nothing

This one wasted the most time. With `global.ryax.logLevel: error`, the repository's build
dispatch (`logger.debug`) and the builder's progress are both invisible, so a perfectly
healthy build queue looks like a stalled one. Before concluding "nothing is happening":

```sh
kubectl exec -n ryaxns deploy/ryax-action-builder -c ryax-action-builder -- ps aux | grep nix
kubectl exec -n ryaxns ryax-broker-0 -- rabbitmqctl list_queues name messages consumers
kubectl set env -n ryaxns deploy/ryax-repository RYAX_LOG_LEVEL=debug   # then re-trigger
```

The flip side: because the level *is* `error`, an absence of tracebacks is real evidence.
Say so explicitly when you use it — "zero tracebacks with the runner at `logLevel: error`"
is a much stronger claim than "no errors in the logs".

### Building actions

Add the library and scan it, then build. `POST /api/repository/v2/sources/{id}/build`
builds the whole source; builds run **one at a time**, so expect a long tail. Eleven of the
45 default actions were ready in ~15 minutes, which is enough to work with — poll rather
than wait for all of them:

```sh
curl -s "http://localhost/api/repository/v2/sources/$SRC" -H "Authorization: $JWT" \
  | jq '.last_scan.built_actions | length'
```

Useful actions and what they give you:

| Action | Why |
|---|---|
| `Emit Every` | trigger with a **required** `time` output, configurable period |
| `Echo inputs into outputs` | every type, in and out, all **optional** — the optional side of IO tests |
| `Cat content of a file` | a **required** `file` input |
| `Archive a directory` | directory input, file output you can download and inspect |

### Building a workflow over the API

Faster and far more reliable than the studio UI:

```sh
WF=$(curl -s -X POST http://localhost/api/studio/workflows -H "Authorization: $JWT" \
  -H 'Content-Type: application/json' -d '{"name":"repro"}' | jq -r .workflow_id)
# add modules -> each returns {"id": "<workflow module id>"}
curl -s -X POST "http://localhost/api/studio/workflows/$WF/modules" -H "Authorization: $JWT" \
  -H 'Content-Type: application/json' -d "{\"module_id\":\"$ACTION_ID\"}"
# order them
curl -s -X PUT "http://localhost/api/studio/v2/workflows/$WF/links" -H "Authorization: $JWT" \
  -H 'Content-Type: application/json' \
  -d "{\"links\":[{\"module_id\":\"$A\",\"next_modules_ids\":[\"$B\"]},{\"module_id\":\"$B\",\"next_modules_ids\":[]}]}"
# set inputs — this is the endpoint the UI uses, so validation matches the UI
curl -s -X PUT "http://localhost/api/studio/v2/workflows/$WF/modules/$B" -H "Authorization: $JWT" \
  -H 'Content-Type: application/json' \
  -d "{\"inputs\":[{\"id\":\"$INPUT\",\"reference_value\":\"$UPSTREAM_OUTPUT\"}]}"
curl -s "http://localhost/api/studio/workflows/$WF/errors" -H "Authorization: $JWT"   # [] = valid
curl -s -X POST "http://localhost/api/studio/workflows/$WF/deploy" -H "Authorization: $JWT"
```

Three keys for an input value, matching the UI's three modes: `static_value`,
`reference_value` (link to an upstream output), `project_variable_value`.

Gotchas:

- Workflow creation returns `{"workflow_id": …}`; adding a module returns `{"id": …}`.
- `POST /api/studio/workflows` responds **201** — a script that only accepts 200 silently
  gets an empty id and every following call fails confusingly.
- **Use the v2 batched module endpoint**, not the per-input one. The per-input route
  answers the same validation error with **404** while v2 answers **400**; the UI uses v2,
  so v2 is what reproduces what a user sees.
- Stop is on the *studio* API with a query param:
  `POST /api/studio/workflows/{wf}/stop?graceful=false`.
- Always stop or delete what you deployed — a trigger left running keeps firing.

### Reading results

```sh
curl -s "http://localhost/api/runner/workflow_runs" -H "Authorization: $JWT"
curl -s "http://localhost/api/runner/workflow_runs/$RUN" -H "Authorization: $JWT"
```

Per-action state is under `.runs[]` with `state` and `error_message`. A file output's
`value` looks like `/runner/filestore/<StoredFile-id>/<filename>` — the download URL keeps
**both** trailing segments:

```sh
curl -s "http://localhost/api/runner/filestore/<StoredFile-id>/<filename>" \
  -H "Authorization: $JWT" -o out.zip
```

Downloading the artefact and checking its bytes is the strongest evidence available — it
proved `#1245` by showing the directory round-tripped with its nesting intact. Prefer it
over "the run said Success".

## Step 3: the browser, and its limits

Only for rendering and UI-only behaviour — anything the backend decides belongs in step 2,
which is faster and far more reliable. Expect trouble here, and time-box it.

### Getting a browser at all

Automation runs through **Claude in Chrome**: a Chrome extension driving the user's own
browser, not a headless instance you spawn. Two consequences — it acts inside their real
profile and logged-in session, and it cannot run unattended.

**Invoke the `claude-in-chrome` skill first.** The `mcp__claude-in-chrome__*` tools do not
exist until you do, and invoking it is what installs and connects the extension.

What has to be true before any of it works:

- Chrome is running, and signed into claude.ai with the same account as Claude Code.
- The extension has **site-level permission for the origin** you are about to drive. For
  issue work that is `http://localhost` — a permission the user grants in the extension,
  so ask rather than assume it is there.
- A first install may need Chrome restarted before the connection comes up.

The tools are **deferred**: their schemas are not loaded, and calling one before loading it
fails with `InputValidationError`. Load them in a *single* `ToolSearch` — the `select:`
query takes a comma-separated list, and one call per tool wastes a round trip each:

```
select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,
mcp__claude-in-chrome__computer,mcp__claude-in-chrome__read_page,
mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__tabs_close_mcp,
mcp__claude-in-chrome__javascript_tool,mcp__claude-in-chrome__read_console_messages,
mcp__claude-in-chrome__find,mcp__claude-in-chrome__browser_batch
```

For this kind of work `javascript_tool` is the one that earns its place — see below.
`get_page_text` and `resize_window` are occasionally handy; `gif_creator` is for showing a
flow to someone, not for verification.

Session mechanics:

- Call `tabs_context_mcp` **once before anything else** — the other tools need a tab id.
  Create your own tab rather than reusing one of theirs, and close it when you are done.
- `browser_batch` runs a sequence in one round trip and stops at the first error.
  Coordinates inside a batch refer to the screenshot taken *before* the call, so a batch
  that clicks based on what a mid-batch screenshot shows will not work.
- `Browser extension is not connected` and `the renderer may be frozen` both turn up
  mid-session on this app. Recover by calling `tabs_context_mcp` again for fresh ids; if it
  keeps happening, that is the signal to stop, not to retry harder.
- Never trigger `alert`/`confirm`/`prompt`. A modal blocks every subsequent command and the
  session is stuck until a human dismisses it.

### What actually worked

- **Measure with JavaScript, not screenshots.** Screenshots time out
  (`Page.captureScreenshot timed out`) and sometimes return a wrongly scaled frame. For a
  CSS bug, read `getComputedStyle` and the box metrics instead — numbers are better
  evidence than a picture anyway.
- **A/B the proposed fix at runtime.** Snapshot, inject a `<style>` with the fix, snapshot
  again, remove it, snapshot a third time to prove the measurement is reversible. That
  turned `#1211` from "the property is still there" into "6×7px of gutter per cell, row
  79px → 61px, restored to 79px".
- **Clean up injected styles by every id you used.** A call that times out may still have
  appended its `<style>`; the next run then measures the *fixed* state and reports nonsense.
  Start with `document.querySelectorAll('style#myid').forEach(e => e.remove())`.
- **Navigate by route, not by clicking.** Routes come from `front/apps/ryax/src/app/**/*.routes.ts`.
  Note `/app/settings` is the older `project` module that owns the variables list, while
  `/app/projects` is the newer `project-new` module — easy to land on the wrong page.

A measurement in that shape, with `javascript_tool`:

```js
document.querySelectorAll('style#ab').forEach(e => e.remove());   // clear a leaked run
const t = document.querySelector('#ryax-variable-list');
const cell = [...t.querySelectorAll('td')].find(c => c.innerText.includes('…'));
const snap = () => ({
  overflow: getComputedStyle(cell).overflowX,
  gutterW: cell.offsetWidth - cell.clientWidth,
  gutterH: cell.offsetHeight - cell.clientHeight,
  rowH: t.querySelector('tbody tr').offsetHeight,
});
const before = snap();
const s = Object.assign(document.createElement('style'), {
  id: 'ab', textContent: '#ryax-variable-list th, #ryax-variable-list td { overflow: hidden !important; }',
});
document.head.appendChild(s);
void t.offsetHeight;                     // force layout
const after = snap();
s.remove(); void t.offsetHeight;
({ before, after, restored: snap() });
```

### What did not work

Clicking ng-zorro cards and selects. The studio's trigger cards and the config panel's
value-type dropdown are not exposed as buttons in the accessibility tree — `read_page`
with `filter: "interactive"` shows the tabs and the search box and nothing else — and
synthetic clicks on their coordinates did not register. `find` locates them by text and
returns a `ref`, but clicking the `ref` selects nothing either.

Console capture was also unreliable: `read_console_messages` reports tracking as starting
at the first call, and after an extension reconnect it came back empty even for errors the
app had definitely logged. Do not read "no console messages" as "no errors".

If a verdict depends on driving that panel, say so and hand it back rather than guessing.

When the UI blocks you, fall back to reasoning about the front's own code — the NgRx
`displayErrors$` effect in `studio/state/effects/builder.effects.ts` lists exactly which
error actions raise a toast, which settled `#1246`. Label that as code evidence, not an
observation.

## Writing the verdict

Comment on every issue you investigated, then close only the ones you actually settled.

- Quote the file and line, or the request and its response. "Still broken" without a
  pointer ages as badly as the issue did.
- Say **how** you checked. Distinguish "reproduced live" from "read the code" from
  "inferred from the commit that added it" — in the same comment if a verdict rests on more
  than one.
- State what you did **not** cover, and what would settle it. On `#1245` that was: the API
  path is proven, the upload widget is not.
- Ask for the missing detail when a report is unsettleable. `#1188`'s traceback was cut off
  before the exception type, which is precisely why it survived two years.

Closing an issue is reversible; a confident wrong close is not costless, so prefer a
detailed comment and an open issue when the evidence is thin. Per `ryax-gitlab-flow`,
closing issues is normally the human's call — get an explicit go-ahead before closing a
batch.
