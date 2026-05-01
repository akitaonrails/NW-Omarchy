# Agent instructions for nw-omarchy

This is a **layered** add-on for Omarchy that adds a bspwm/picom login session **alongside** Hyprland. The project's X server target is **XLibre** (a maintained `xorg-server` fork). It must never modify the Omarchy install or break the Hyprland session.

**XLibre framing:** XLibre is supported via the official `[xlibre]` binary repo at `x11libre.net`, whose packages declare proper `provides=('xorg-server' ...)` and do **not** conflict with `xorg-xwayland`. So XLibre coexists with Hyprland (which uses `xorg-xwayland` for X11 client compat). The swap is part of the regular `install.sh --apply` pipeline (`install/xlibre.sh`, runs last, idempotent). `bin/nw-omarchy-xlibre-migrate` is a stub kept around for muscle-memory. Stock `xorg-server` still works as a fallback (every config in this repo is libxcb/libx11 client-side, not server-side).

## Versioning, releases, upgrades (post-1.0)

The project tagged 1.0 on 2026-05-01. From this point on:

- **Source of truth** for version is `VERSION` (one-line semver, repo root). It MUST stay in sync with the corresponding `vX.Y.Z` git tag.
- **Releases** are git tags of the form `vX.Y.Z`. Every release bumps `VERSION` in the same commit that gets tagged. Tag annotations should summarise what changed for users (not a changelog dump — a paragraph).
- **boot.sh and nw-omarchy-upgrade pin to the latest `v*` tag**, not master. Master is the dev branch; users only land on tagged releases.
- **Upgrades go through `nw-omarchy-upgrade`**, which runs `yay -Syu` (or `pacman -Syu`), checks out the new tag, runs every `migrations/<target>.sh` between current and latest in version-sort order, runs `install.sh --apply`, then writes the new version to `~/.local/state/nw-omarchy/version`.
- **Migrations** live in `migrations/<target-version>.sh`. They are for upgrade-specific deltas that the install pipeline can't express idempotently — package replacements pacman can't auto-resolve, file moves, config schema bumps. Write one *only when* `install.sh --apply` alone wouldn't get the user from version N-1 to N. See `migrations/README.md` for conventions (idempotent, self-contained, exit non-zero on failure, comment heavily).
- **Pre-1.0 leftover replacements** (the `PRE_INSTALL_REMOVE` list in `install/packages.sh`) move to migrations once they apply only to `<v1.0` users — keep them there until you're sure no one has a pre-1.0 install around any longer.

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
