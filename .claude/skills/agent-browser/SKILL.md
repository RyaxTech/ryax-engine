---
name: agent-browser
description: Driving a browser with Vercel Labs' agent-browser CLI — installing it (including on NixOS, where the default path fails), and the Ryax-specific selectors and techniques that work. Use when automating or testing a web UI, reproducing a front-end bug, or when a browser is needed and no tool is set up yet.
---

# Browser automation with agent-browser

[agent-browser](https://github.com/vercel-labs/agent-browser) is a Rust CLI that drives
Chrome/Chromium over CDP — no Playwright, no Node runtime at run time. It is the default
browser automation for this project, preferred over the `claude-in-chrome` extension for
anything testable against a disposable browser. See [Which tool](#which-tool).

**It ships its own skills, version-matched to the binary. Read those for the command
surface rather than guessing from `--help`:**

```sh
agent-browser skills get core          # overview + common patterns
agent-browser skills get core --full   # full command reference
agent-browser skills list              # electron, slack, exploratory testing, ...
```

This file covers only what those cannot know: installing where the normal path fails, and
the Ryax UI.

## Install

The documented route:

```sh
npm install -g agent-browser
agent-browser install            # downloads Chrome for Testing
agent-browser install --with-deps  # Linux: also the system libraries it needs
agent-browser doctor             # the line that matters is "Launch test: pass"
```

**Always set a named session**, whatever the platform:

```sh
export AGENT_BROWSER_SESSION=ryax
```

The unnamed session is one shared browser across every agent on the machine, persisting
between conversations — working in it can hijack another session's page or navigate away
from something a human left open.

### On NixOS

Both steps above fail here: `npm install -g` has no writable global prefix, and the
Chrome for Testing binary is dynamically linked and will not run unpatched. Install to a
local prefix and point the CLI at the nixpkgs chromium already on the system:

```sh
PREFIX=~/.local/agent-browser
nix shell nixpkgs#nodejs --command npm install -g --prefix "$PREFIX" agent-browser
```

npm warns that it skipped the `postinstall` script — fine, the binary still runs. Then a
wrapper, since every invocation needs the same three things:

```sh
#!/usr/bin/env bash
export PATH="$HOME/.local/agent-browser/bin:$PATH"
export AGENT_BROWSER_EXECUTABLE_PATH=/run/current-system/sw/bin/chromium
export AGENT_BROWSER_SESSION=ryax
exec nix shell nixpkgs#nodejs --command agent-browser "$@"
```

`agent-browser doctor` will report `Chrome for Testing CDN unreachable` — expected and
irrelevant, since that download is exactly what is being skipped. `Launch test: pass` is
the line to check. See the `nixos-tools` skill for the general pattern.

## Driving the Ryax UI

Log in — three commands, refs straight from the snapshot:

```sh
ab open http://localhost/app/login
ab snapshot -i            # textbox "Username" [ref=e7], "Password" [ref=e8], button "Log in" [ref=e6]
ab fill @e7 user1 && ab fill @e8 pass1 && ab click @e6
```

### ng-zorro: click the host, not the card

The studio's action and trigger cards expose no button. The Angular `(click)` sits on the
**component host**, so target that by CSS selector:

```sh
ab click "ryax-action-mini-card"                    # selects a trigger or action
ab click "ryax-action-mini-card:nth-of-type(2)"     # the second one
ab click "div.ant-tabs-tab:nth-child(3)"            # the Configure tab
```

Clicking the inner `nz-card` registers the event but does **not** select. This is the
single most useful line in this file: it is what makes the studio drivable at all, and it
is why the accessibility-tree-only approach of the Chrome extension could not.

### Never navigate straight to `/app/studio/new`

No workflow is created that way, so `workflowId` stays empty and adding a module posts to
`/api/studio/v2/workflows//modules` — note the double slash — and gets a 405, while the
page still says "Last save just now" (roadmap#1456). Create through the dashboard button,
which POSTs `/api/studio/workflows` and routes to `/app/studio/{id}`:

```sh
ab open http://localhost/app/dashboard
ab snapshot -i                    # button "New workflow" / "Create one now"
ab click @eN
```

Routes live in `front/apps/ryax/src/app/**/*.routes.ts`. Note `/app/settings` is the older
`project` module (it owns the variables list) while `/app/projects` is `project-new`.

## Three techniques worth reusing

**Measure, do not screenshot.** For any layout or styling question, read the box metrics.
Numbers beat a picture as evidence, and screenshots of this app time out.

**A/B a proposed fix at runtime.** Snapshot, inject a `<style>`, snapshot, remove it,
snapshot again — the third sample proves the measurement is reversible rather than drift.
Clear leftovers first (`document.querySelectorAll('style#ab').forEach(e => e.remove())`),
because a timed-out call can leave its style behind and the next run then measures the
*fixed* state.

**Sample state across an async action.** This is how to prove a missing loading indicator,
and it needs `eval --stdin` with an async IIFE — top-level `await` is rejected:

```sh
cat <<'EOF' | ab eval --stdin
(async () => {
  const btn = [...document.querySelectorAll('button')].find(b => /Download file/i.test(b.innerText) && !b.disabled);
  const shot = () => JSON.stringify({cls: btn.className, disabled: btn.disabled,
    spinner: !!btn.querySelector('.ant-btn-loading-icon'), pageSpinners: document.querySelectorAll('.ant-spin-spinning').length});
  const states = [shot()];
  btn.click();
  const t0 = performance.now();
  await new Promise(res => { const iv = setInterval(() => {
    const s = shot(); if (s !== states.at(-1)) states.push(s);
    if (performance.now() - t0 > 2500) { clearInterval(iv); res(); }
  }, 20); });
  return {distinctStates: states.length, states: states.map(JSON.parse)};
})();
EOF
```

`distinctStates: 1` across the whole request is proof there is no loading state — but only
if the request actually happened, so confirm it:

```sh
ab network requests --filter filestore     # GET .../StoredFile-.../file (XHR) 200
```

Without that check the result is vacuous: a button that never changes because nothing was
ever fetched proves nothing.

## Which tool

| Use | Tool |
|---|---|
| Anything testable against a clean browser | **agent-browser** |
| CI / unattended runs | **agent-browser** — the extension needs a human's Chrome |
| A real logged-in session, SSO, the user's own profile and extensions | `claude-in-chrome` |
| A rendering difference that is specifically *not* Chromium | neither — no Firefox in either |

`--hide-scrollbars` defaults to **true** in headless Chromium. Pass `--hide-scrollbars false`
for anything about scrollbar geometry, or the gutter being measured disappears.
