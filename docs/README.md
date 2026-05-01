# nw-omarchy docs

Index of "what worked" notes for the bspwm/picom/XLibre layer on top of Omarchy.

## Bootstrap

```bash
cd ~/.local/share/nw-omarchy
./install.sh           # dry-run, prints planned actions
./install.sh --apply   # actually install

# Pick "nw-bspwm" at the SDDM session selector on next login.
```

## Uninstall

```bash
~/.local/share/nw-omarchy/uninstall.sh           # dry-run
~/.local/share/nw-omarchy/uninstall.sh --apply   # actually undo

# Or from anywhere on PATH:
nw-omarchy-uninstall --apply
```

The uninstaller reads `~/.local/state/nw-omarchy/manifest.tsv` and replays it in reverse:
- removes only the packages it installed (`pkg-skip` rows are left alone)
- restores backed-up configs from `~/.local/state/nw-omarchy/backups/`
- removes `/usr/share/xsessions/nw-bspwm.desktop`
- wipes the state dir (pass `--keep-state` to retain)

## Topics

- [architecture.md](architecture.md) — directory layout, manifest schema, install/uninstall pipeline
- [porting-hypr.md](porting-hypr.md) — Hyprland binding/feature → X11 map, omarchy helper substitutions
- [sddm-picker.md](sddm-picker.md) — adding a session picker to the omarchy SDDM greeter (so `nw-bspwm` is selectable)
- [theming.md](theming.md) — how bspwm/rofi/polybar pick up the active omarchy theme via `~/.config/omarchy/themed/`
- [menu.md](menu.md) — `nw-omarchy-menu`: 1-to-1 port of the omarchy system menu (super+alt+space)
- [gaps.md](gaps.md) — what's at parity vs vanilla omarchy, what's intentionally dropped, what's still worth building
- [services.md](services.md) — audit of every omarchy systemd unit / hook, with verdict on whether nw-omarchy needs to wire it
- [clipboard.md](clipboard.md) — what works (`ctrl+c/v/x`, alacritty CLIPBOARD overrides, `super+ctrl+v` history) and why omarchy's `super+c/v/x` synthesis didn't survive the X11 port
- [why-xlibre.md](why-xlibre.md) — what XLibre is, why we chose it, what we materially gain by staying on X11, what we lose vs Hypr/Wayland
- [xlibre.md](xlibre.md) — what the install pipeline does for the X server swap, compatibility matrix, revert recipe

## Health-checking the install

```bash
nw-omarchy-doctor
```

Lints the live system in eight sections (Packages, Manifest, SDDM picker, Theme integration, Alacritty, Session, Live daemons). Marks every line `[OK]` (healthy), `[!]` (broken — fix suggested), or `[-]` (informational). Read-only, no side effects. First thing to run when something feels off, or after any `omarchy-*` upgrade that might have shifted theme files around.

## Gotchas worth knowing

### XLibre is the X server target

nw-omarchy is **omarchy on XLibre**: a bspwm + picom v13 login session, on the maintained `xorg-server` fork. The project ships configs that work on either xorg-server or XLibre (every binding is libxcb/libx11 client-side), but the recommended deployment runs XLibre.

Why not auto-swap during `install.sh`? Replacing the X server is substantially riskier than the rest of the install pipeline (which only touches user configs and the SDDM session entry). Keeping it as a deliberate post-install step lets you decide and lets the rest of the pipeline stay safely re-runnable on a vanilla omarchy box. The migration script is idempotent and self-checks against the current state:

```bash
nw-omarchy-xlibre-migrate            # preview (dry-run)
nw-omarchy-xlibre-migrate --apply    # commit
nw-omarchy-xlibre-migrate --revert --apply  # roll back
```

Coexistence with Hyprland: the official `[xlibre]` binary repo packages declare proper `provides=('xorg-server' ...)` and don't conflict with `xorg-xwayland`, so omarchy's hyprland session keeps working with XLibre installed. (An earlier blocker was specifically the `xlibre-xserver-common-git` AUR package, which declared `Conflicts=xorg-server-common` without the matching `Provides=`. The binary-repo packages don't have that flaw.)

Full rationale, compatibility matrix, and rollback plan: [docs/xlibre.md](xlibre.md). `install/xlibre.sh` (run during the regular install pipeline) is diagnostic-only — it just reports the current X server.

### Compositor: upstream picom v13 (not a fork)

We use **upstream `picom`** (Arch `extra` repo, v13, Feb 2026 release) — not a fork. Earlier iterations of this project shipped with `picom-ftlabs-git` (AUR), which is **abandoned** since Feb 2024. Worse, debug logs showed FT-Labs's animation system never actually engaged for bspwm workspace switches: `animation-for-next-tag` / `animation-for-prev-tag` were silently no-ops on bspwm because the FT-Labs hook listens for dwm-style retag events, not bspwm's unmap/map cycles.

Upstream v13 ships a proper trigger-based animation system with separate `show` / `hide` triggers (visibility changes) distinct from `open` / `close` (window lifecycle). Our `default/picom/picom.conf` defines a custom workspace-slide animation: each window's `offset-x` is animated by exactly one `window-monitor-width`, so all windows slide together as a coherent workspace pan rather than per-window-bounds wiggle.

Trade-offs:
- Direction is fixed: outgoing slides left, incoming slides in from the right, regardless of next/prev. picom doesn't know which direction the user asked bspwm to switch in. Direction-aware animation would need a `bspc subscribe`-driven daemon swapping picom configs per switch.
- `open` and `show` share the slide-in animation, because bspwm defers mapping windows on non-focused workspaces — a window's first visit fires `open`, subsequent visits fire `show`. New app launches therefore also slide in from the right.

If you upgrade picom past v13 and the schema changes, the relevant docs are in `man picom` under the **ANIMATIONS** section (presets + custom scripts + context variables).

### Battery name on T14 Gen 6

Polybar's `[module/battery]` defaults to `BAT0` / `ADP1`. Verify with `ls /sys/class/power_supply/`. If yours is `BAT1` or `AC0`, edit `~/.local/share/nw-omarchy/default/polybar/config.ini` (or override in your shim).

### bspwmrc is shell, not config

Reload bspwm config with `bspc wm -r` (re-execs `bspwmrc`). Reload sxhkd separately with `pkill -USR1 -x sxhkd`. They're independent daemons.

### sxhkd uses *two* config files

bspwmrc launches sxhkd with `-c default-rc user-rc` — the **main** config goes after `-c`, **additional** configs are passed as positional args. We initially used `-c A -c B` and lost every binding (the second `-c` overrides the first; `man sxhkd` says `-c` takes a single file). Later definitions across the loaded files override earlier ones on conflict, so to override a binding put the same `super + key` line in `~/.config/sxhkd/sxhkdrc`. To *unbind* a default, sxhkd doesn't have a clean way — just rebind it to `:` (no-op) in your override.

### Hypr session is untouched

Nothing under `~/.config/hypr/`, `~/.local/share/omarchy/`, or `/etc/sddm.conf` is modified. Hyprland keeps appearing in the SDDM session menu next to `nw-bspwm`.

### Stock omarchy SDDM theme has no session picker

The vanilla `/usr/share/sddm/themes/omarchy/` Main.qml hardcodes the session whose name contains `uwsm` and exposes no UI to switch — meaning a fresh nw-omarchy install can't actually reach `nw-bspwm` from the greeter. Fix: we ship a clone of the theme called `nw-omarchy` with an Up/Down session picker. See [sddm-picker.md](sddm-picker.md). Autologin (vanilla Omarchy ships it on by default) bypasses themes entirely and must be disabled separately.

### SDDM reads every file in `/etc/sddm.conf.d/`, not just `*.conf`

Renaming `autologin.conf` to `autologin.conf.disabled` does **not** disable it — SDDM parses every file in `/etc/sddm.conf.d/` regardless of extension. A `.disabled` autologin file still has its `[Theme] Current=omarchy` merged in (last-key-wins, alphabetical) and silently overrides our nw-omarchy theme override. To actually disable: `sudo mv /etc/sddm.conf.d/autologin.conf /etc/sddm-autologin.conf.disabled` (out of the directory entirely).

## Things that are TODO

- Hyprland-style **blurry lockscreen background** (`nw-omarchy-lock` is currently a flat color — needs maim+convert+i3lock-color piping)
- `omarchy-menu` parity (gum-based system menu) — the script may already work on X11; needs testing
- ~~`omarchy-launch-or-focus` parity for X11~~ — done; `nw-omarchy-launch-or-focus` ships in `bin/` (wmctrl-based). See [porting-hypr.md](porting-hypr.md).
- ~~Theming: pick up the active omarchy theme and translate its colors into picom + polybar + rofi~~ — done; templates in `default/themed/` regenerate via `omarchy-theme-set-templates`. See [theming.md](theming.md).
