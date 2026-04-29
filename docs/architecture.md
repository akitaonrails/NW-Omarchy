# Architecture

## Two trees, like Omarchy

| Tree | Owner | Purpose |
|---|---|---|
| `~/.local/share/nw-omarchy/default/` | this repo | full default configs, never edited by user |
| `~/.config/{bspwm,sxhkd,picom,polybar,rofi}/` | user | thin shims that source/include the defaults; user overrides go below the include line |

This is the same pattern Omarchy uses for hypr/bash. The shims are the only files our installer writes into `~/.config`; everything else lives under `default/` and gets pulled in by the shim's include directive.

## Include mechanism per tool

| Tool | Include | Shim looks like |
|---|---|---|
| bspwm | `. <path>` (shell source) | `#!/bin/sh` then `. ~/.local/share/nw-omarchy/default/bspwm/bspwmrc` |
| sxhkd | `sxhkd -c default -c user` (later wins) | empty file with comments — bspwmrc launches both |
| picom | `@include "..."` | `@include "<default>/picom.conf"` then user keys |
| rofi | `@import "..."` | `@import "<default>/config.rasi"` |
| polybar | (no native include) | shim `launch.sh` execs the default `launch.sh` |

## Install pipeline

`install.sh` → `bin/nw-omarchy-install` → `install/all.sh` runs five steps in order:

1. **preflight.sh** — sanity checks (Arch, Omarchy present, AUR helper, sudo, not in nw-bspwm session).
2. **packages.sh** — install repo + AUR packages from `packages/nw-omarchy.packages`. For each: classify as `pkg` (we installed) or `pkg-skip` (was pre-existing) and record.
3. **xlibre.sh** — diagnostic for the XLibre AUR package; surfaces fallbacks if the primary name fails to build.
4. **session.sh** — install `/usr/share/xsessions/nw-bspwm.desktop` (with backup if one already exists at that path).
5. **config.sh** — write the user-side shim files in `~/.config`. Each shim recorded in the manifest as `file` with backup if displaced.

Every step honours `$DRY_RUN`. With `DRY_RUN=1` (the default), commands are printed with a `[dry]` prefix and never run.

## State / manifest

State lives **outside** the source tree at `~/.local/state/nw-omarchy/`:

```
manifest.tsv     # the truth: every action recorded here
backups/         # files we displaced
install.log      # last --apply run output
```

Manifest schema:

```
timestamp <TAB> action <TAB> target <TAB> backup
```

Actions:

| action | target | backup | notes |
|---|---|---|---|
| `pkg` | package name | `-` | we installed it; uninstall removes via pacman -Rns |
| `pkg-skip` | package name | `-` | was already on the system; uninstall leaves alone |
| `file` | absolute path | path or `-` | regular file we wrote (or shim); restore backup on uninstall |
| `symlink` | absolute path | path or `-` | symlink we created (currently unused by config.sh — kept for future) |
| `xsession` | absolute path | path or `-` | the SDDM session file in /usr/share/xsessions |
| `dir` | absolute path | `-` | directory we created (only removed if empty on uninstall) |

Reads/writes go through `bin/nw-omarchy-track`:

```bash
nw-omarchy-track record <action> <target> [backup]   # idempotent: skips if already recorded
nw-omarchy-track has    <action> <target>            # exit 0 if present
nw-omarchy-track list                                # cat the manifest
nw-omarchy-track manifest-path                       # print path
```

## Idempotency rules

Re-running `install.sh --apply` on a fully-installed system must produce zero changes. The patterns:

- **Packages**: `pacman -Qq pkg` decides classification before touching pacman.
- **Files / shims**: `cmp` the target against expected content; skip if identical.
- **Manifest**: `nw-omarchy-track record` is a no-op if the same `(action,target)` is already present.
- **Sessions**: `cmp` the source against `/usr/share/xsessions/nw-bspwm.desktop`; skip if identical.

## Uninstall is just a manifest replay

`bin/nw-omarchy-uninstall` reads the manifest in **reverse** order and undoes each action:

- `file` / `symlink` → `rm` (with `sudo` for `/usr/*` and `/etc/*`); restore backup if present
- `xsession` → `sudo rm`
- `dir` → `rmdir` only if empty
- `pkg` → batched `sudo pacman -Rns --noconfirm` at the end
- `pkg-skip` → ignored

Then the state dir is wiped (unless `--keep-state`).

If the manifest is lost, uninstall becomes manual — back it up if you care.

## Why a separate state dir, not a `state/` subdir of the source tree?

Two reasons:
1. The source tree is supposed to be a checked-in repo eventually. State is per-machine, transient, doesn't belong in version control.
2. Wiping `~/.local/state/nw-omarchy/` is the documented "I lost the manifest, start fresh" recovery — easier when state is its own dir.
