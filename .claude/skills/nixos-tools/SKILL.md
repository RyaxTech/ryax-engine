---
name: nixos-tools
description: Getting a missing command-line tool when the machine runs NixOS, where there is no apt/dnf/brew and packages cannot be installed imperatively. Use only after confirming the machine is NixOS - when a shell command fails with "command not found", a tool is needed to finish a task, or you are reaching for a package manager, pip install, curl | sh, or a language toolchain that is not on PATH.
---

# Running missing tools on NixOS

**This applies only if the machine runs NixOS.** Several Ryax developers do, and
the repos lean on Nix for builds, but most distros install tools normally — check
before assuming:

```bash
grep -q '^ID=nixos' /etc/os-release && echo "NixOS"
```

If that prints nothing, install the tool the way your distro does and ignore the
rest of this page.

On NixOS, `/usr/bin` is nearly empty, PATH comes from the system closure, and
there is no `apt`, `dnf`, `yum`, `pacman`, or `brew`. Nothing can be installed
imperatively, and the system configuration is not the place to go for a tool
needed by one task.

## The rule

A command is missing? Run it from nixpkgs instead of installing it:

```bash
nix run nixpkgs#<package> -- <args>
```

Everything after `--` goes to the tool. Examples:

```bash
nix run nixpkgs#jq -- '.items[].name' file.json
nix run nixpkgs#glab -- mr list
nix run nixpkgs#httpie -- GET https://example.com
```

The first run downloads from cache.nixos.org and can take a minute; later runs
are instant. Give such calls a generous timeout rather than assuming a hang.

## Several tools at once, or a pipeline

`nix run` executes one program. For a pipeline or a script that needs several
binaries on PATH, use `nix shell`:

```bash
nix shell nixpkgs#jq nixpkgs#yq-go --command bash -c 'yq -o json f.yaml | jq .spec'
```

## When the attribute name is not the command name

`nix run nixpkgs#foo` fails outright if `foo` is not an attribute — the command
`yq` is `yq-go`, `nvim` is `neovim`, `rg` is `ripgrep`, `magick` is
`imagemagick`. Don't guess twice; look it up:

```bash
nix search nixpkgs <name>     # slow (evaluates nixpkgs) but authoritative
```

`search.nixos.org` covers the same index if a web fetch is quicker. If
`nix-locate` is not available (it needs nix-index), command-to-package lookup is
`nix search` or the web.

If a package genuinely is not in nixpkgs, say so instead of falling back to
`curl | sh` or `pip install`.

## Prefer the project's own dev shell

If the repo has a `flake.nix`, `shell.nix`, or `.envrc`, the tools the project
expects — at the versions it pins — are already in there. Use that first:

```bash
nix develop --command <cmd> <args>   # flake.nix
nix-shell --run '<cmd> <args>'       # shell.nix / default.nix
direnv exec . <cmd> <args>           # .envrc
```

Only reach for `nix run nixpkgs#…` for one-off tools the project does not pin.

## Python

Never `pip install` into the system interpreter — it will refuse or break
things. Use the project's virtualenv or `uv`. For a
throwaway script that needs a library:

```bash
uv run --with requests python -c 'import requests; ...'
```

For a nixpkgs-provided interpreter with libraries, note that `nixpkgs#…`
installables cannot call functions, so `withPackages` needs `--expr`:

```bash
nix shell --impure --expr 'with import <nixpkgs> {}; [ (python3.withPackages (ps: [ ps.requests ])) ]' \
  --command python -c 'import requests; ...'
```

## Things that are already there, just not on PATH

Some tools exist in `/nix/store` — pulled in by another package or a previous
build — without being on PATH. Worth a look before downloading:

```bash
ls -d /nix/store/*-<name>-*/bin/<command> 2>/dev/null
```

Use the full store path if you find one; it is pinned and immutable.

## Never do

- `sudo apt install` / `dnf` / `brew` / `pacman` — not present, not a fallback.
- `curl … | sh` installers — they write to paths that do not exist here.
- `pip install` outside a venv, or any `--user` install into `~/.local/bin`.
- Editing `/etc/nixos/configuration.nix` or the home-manager config to obtain a
  tool for the task at hand. That is a system change — ask the user first.
