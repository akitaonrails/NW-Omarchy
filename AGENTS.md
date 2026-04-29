# Agent instructions for nw-omarchy

This is a **layered** add-on for Omarchy that adds a bspwm/picom login session **alongside** Hyprland on stock Xorg. It must never modify the Omarchy install or break the Hyprland session.

**XLibre note:** the original target was XLibre as the X server, but `xlibre-xserver-common-git` declares `Conflicts=xorg-server-common` without `Provides=`, and `xorg-xwayland` (required by Hyprland) depends on `xorg-server-common`. So XLibre and Hyprland are mutually exclusive. We use stock Xorg and document the situation. Don't try to "fix" this by replacing xorg-server unless the user explicitly asks for it on a Hyprland-free machine.

## The hard rules

1. **Never edit `~/.local/share/omarchy/`.** That's clobbered by `omarchy-update`. Anything we need from there, we read; we never write.
2. **Never edit `~/.config/hypr/*`.** The user's Hyprland configuration is sacred. Our session file goes to `/usr/share/xsessions/nw-bspwm.desktop` only.
3. **Every install action goes through `bin/nw-omarchy-track`.** No exceptions. If you `pacman -S` a package, record it. If you write a file, record it. If you symlink, record it. The manifest is the source of truth for uninstall.
4. **All install scripts must be idempotent.** Re-running install on a fully-installed system: zero changes, zero errors. Use `pacman -Qq pkg`, `[ -L target ]`, `nw-omarchy-track has`.
5. **Default to dry-run.** `install.sh` without `--apply` prints what it would do. Real changes only behind `--apply`.
6. **Backup before overwrite.** If a target file or directory exists and isn't our symlink, copy it to `~/.local/state/nw-omarchy/backups/` and record the backup path in the manifest.

## The one philosophical rule (from Omarchy)

Document what **worked**, tersely. Reachable from `docs/README.md`. Skip most failed trials; only document a gotcha when the next person would lose hours without it.

## Directory layout (see [docs/architecture.md](docs/architecture.md))

```
nw-omarchy/
├── install.sh, uninstall.sh   # bootstraps; thin wrappers around bin/
├── bin/                        # runtime CLI
├── install/                    # ordered install steps
├── default/                    # configs symlinked into ~/.config
├── packages/                   # package lists
└── docs/
```

State (NOT in the repo): `~/.local/state/nw-omarchy/{manifest.tsv,backups/,install.log}`.

## Commit style

Same as the user's `~/.config` repo:

- Imperative subject ≤72 chars, scoped: `install:`, `bspwm:`, `picom:`, `sxhkd:`, `docs:`, `fix(...)`.
- Body explains the **why**, not the what.
- Trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

## When the user asks for changes

1. Make the change in `default/*` or the relevant `install/*.sh`.
2. If it changes user-visible behavior (binding, look, what's installed): update the matching doc in `docs/`.
3. Verify on a current bspwm session (or run install in dry-run and read the diff).
4. Commit + push, pausing for review at non-trivial checkpoints.
