# nw-omarchy

A secondary login option for Omarchy: **bspwm + picom (FT-Labs) on XLibre**, layered on top of an existing Omarchy install. Ports as much of the Hyprland look-and-feel and keybindings as the X11 stack allows, on a maintained X server.

> "Not Wayland Omarchy." Sits parallel to Hyprland — your Omarchy session is untouched.

XLibre is the project's X server target (a maintained `xorg-server` fork). It coexists cleanly with omarchy's hyprland — the install pipeline does not swap your X server automatically because the operation is risky enough to warrant a deliberate confirmation step; run `nw-omarchy-xlibre-migrate --apply` after `install.sh --apply` to swap. Stock `xorg-server` still works as a fallback if you'd rather skip the migration. See [docs/xlibre.md](docs/xlibre.md) for the full story.

## What this is not

- A replacement for Omarchy. Hyprland keeps working. Pick your session at SDDM.
- A fork. Nothing under `~/.local/share/omarchy/` is modified.
- Magic. Wayland-only features (real GPU compositing, native fractional scaling) don't come back; we approximate.

## Bootstrap (from a clone)

```bash
cd ~/.local/share/nw-omarchy
./install.sh                          # dry-run by default; prints what it would do
./install.sh --apply                  # install bspwm/picom/polybar/sxhkd/rofi configs

# recommended: swap xorg-server for XLibre (idempotent; reboot after)
nw-omarchy-xlibre-migrate             # preview
nw-omarchy-xlibre-migrate --apply     # commit
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
- [docs/gaps.md](docs/gaps.md) — parity with vanilla omarchy: what's done, what's intentionally dropped, what's still worth building
- [docs/porting-hypr.md](docs/porting-hypr.md) — Hyprland binding/feature → X11 map
- [docs/xlibre.md](docs/xlibre.md) — opt-in XLibre migration: what it touches, compatibility, revert recipe

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
