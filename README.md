# nw-omarchy

A secondary login option for Omarchy: **bspwm + picom (FT-Labs)** on Xorg, layered on top of an existing Omarchy install. Ports as much of the Hyprland look-and-feel and keybindings as the X11 stack allows.

> "Not Wayland Omarchy." Sits parallel to Hyprland — your Omarchy session is untouched.

XLibre was the original X-server target but it can't coexist with Hyprland on the same machine — see [docs/README.md](docs/README.md#xlibre-skipped-by-default). On a Hyprland-free machine you can opt in manually after install.

## What this is not

- A replacement for Omarchy. Hyprland keeps working. Pick your session at SDDM.
- A fork. Nothing under `~/.local/share/omarchy/` is modified.
- Magic. Wayland-only features (real GPU compositing, native fractional scaling) don't come back; we approximate.

## Bootstrap (from a clone)

```bash
cd ~/.local/share/nw-omarchy
./install.sh           # dry-run by default; prints what it would do
./install.sh --apply   # actually install
```

Pick `nw-bspwm` from the SDDM session selector on next login.

## Uninstall

```bash
~/.local/share/nw-omarchy/uninstall.sh --apply
```

Reads `~/.local/state/nw-omarchy/manifest.tsv` and undoes everything: removes only packages it installed, restores backed-up configs, deletes the SDDM session entry, wipes state.

## Status / introspection

```bash
nw-omarchy-status        # what's tracked, what would be removed
nw-omarchy-doctor        # lint live install (packages, themes, daemons, ...)
```

## Documentation

- [docs/README.md](docs/README.md) — what works, what doesn't, gotchas
- [docs/architecture.md](docs/architecture.md) — directory layout and conventions
- [docs/porting-hypr.md](docs/porting-hypr.md) — Hyprland binding/feature → X11 map

## Repo layout

| Path | Purpose |
|---|---|
| `install.sh` / `uninstall.sh` | Top-level entry points |
| `bin/nw-omarchy-*` | Runtime CLI (install, uninstall, status, track) |
| `install/*.sh` | Idempotent install steps; each calls `nw-omarchy-track` |
| `default/{bspwm,sxhkd,picom,polybar,rofi,xinit}/` | Configs symlinked into `~/.config` |
| `default/xsessions/nw-bspwm.desktop` | The SDDM session file |
| `packages/nw-omarchy.packages` | Pacman/AUR package list |
| `docs/` | The "what worked" docs (omarchy-style) |

## Conventions inherited from Omarchy

- Idempotent scripts (re-running install does nothing on a clean state).
- "Document what worked" — every shipped change reachable from `docs/README.md`.
- Imperative commit subjects, scoped: `bspwm:`, `picom:`, `install:`, `docs:`, `fix(...)`.
- Never edit `~/.local/share/omarchy/` (their tree, clobbered by `omarchy-update`).

## State directory

Install actions are recorded in `~/.local/state/nw-omarchy/`:

```
manifest.tsv     # one row per action: pkg | pkg-skip | file | symlink | dir
backups/         # files we displaced
install.log      # last install run output
```

Uninstall replays this in reverse. Lose the state dir → uninstall becomes manual; back it up if you care.
