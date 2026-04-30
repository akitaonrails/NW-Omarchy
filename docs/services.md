# Omarchy services audit

Every omarchy-shipped systemd unit, dropin, and sleep-hook, with a verdict on whether nw-omarchy needs to wire it. Last refreshed alongside the top-five gap closure.

## System-level (active for any session — no wiring needed)

These units / sleep hooks live in `~/.local/share/omarchy/default/systemd/` and are installed system-wide by `omarchy-update`. They run regardless of which X11/Wayland session is active, so they cover us automatically:

| Unit / hook | Effect | Hardware-conditional |
|---|---|---|
| `faster-shutdown.conf` (system + `user@.service.d/`) | `DefaultTimeoutStopSec=5s` — shutdown doesn't stall on hung services | no |
| `system-sleep/force-igpu` | Detaches NVIDIA dGPU on suspend in iGPU mode | yes — hybrid GPU |
| `system-sleep/keyboard-backlight` | Turns off keyboard LEDs before hibernate (avoids ASUS keyboard controller blocking S4) | yes — ASUS hardware |
| `system-sleep/unmount-fuse` | Lazy-unmounts gvfsd-fuse before suspend so fuse daemons don't deadlock the freeze | no |
| `supergfxd.service.d/delay-start.conf` | Delays supergfxd start so it doesn't race with login | yes — hybrid GPU |

**Verdict: nothing to do.** Nw-omarchy inherits these via the same omarchy install.

## User-level (`~/.config/systemd/user/`)

Three services omarchy enables in its first-run install. We deal with each as follows:

| Unit | Wayland-coupled? | nw-omarchy action |
|---|---|---|
| `omarchy-battery-monitor.timer` (+ `.service`) | no — pure shell + upower | ✅ **wired** — `default/bspwm/bspwmrc` runs `systemctl --user start omarchy-battery-monitor.timer` on session start. Idempotent. |
| `omarchy-recover-internal-monitor.service` | yes — gated on `~/.local/state/omarchy/toggles/hypr/internal-monitor-disable.conf`, which we never write (our `nw-omarchy-monitor-internal` uses `xrandr` and doesn't persist state). | ⛔ **skip** — `ConditionPathExists` short-circuits it for X11 users; nw-omarchy-monitor-internal is stateless across reboots, so no recovery is needed. |
| `elephant.service` | yes — daemon for walker's providers (apps/calc/etc) | ⛔ **skip** — walker is Wayland-only; we use rofi. |

The Wayland-only drop-ins `app-walker@autostart.service.d/` and `xdg-desktop-portal-hyprland.service` are likewise out of scope.

## omarchy-hook events (free-rider)

`omarchy-hook NAME` runs `~/.config/omarchy/hooks/NAME` if present — a user-extension surface. Events omarchy fires:

| Event | Where | nw-omarchy inherits? |
|---|---|---|
| `battery-low` | `omarchy-battery-monitor` (when battery hits ≤10% discharging) | ✅ yes — same monitor we activate |
| `theme-set` | `omarchy-theme-set` (when user switches theme) | ✅ yes — we use omarchy-theme-set as-is |
| `font-set` | `omarchy-font-set` | ✅ yes |
| `post-update` | `omarchy-update-perform` | ✅ yes |

**Verdict: nothing to do.** Anyone who's added custom scripts at `~/.config/omarchy/hooks/<event>/` keeps getting them fired in nw-bspwm too, since we delegate to the same omarchy commands.

## Anything we ourselves don't wire that we should?

After reviewing the surface:

- **No additional omarchy units to enable.** The three the install enables map cleanly to the three buckets above.
- **No nw-omarchy-specific systemd units** are warranted right now. Our daemons (sxhkd, picom, polybar, dunst, libinput-gestures, clipmenud, xidlehook, redshift-on-toggle) are bspwm-session-scoped and start from `bspwmrc`. systemd-managing them would mean fighting with the X session lifecycle — bspwm exits → daemons should exit too, and bspwmrc autostarts already handles that cleanly.

If we ever ship a daemon that needs to survive across X session restarts (e.g. a long-running indexer), `~/.config/systemd/user/nw-omarchy-X.service` would be the right home for it. Until then the bspwmrc autostart pattern is the lighter touch.

## Reference: where omarchy enables what

Pulled from `~/.local/share/omarchy/install/first-run/`:

```
elephant.sh                 → systemctl --user start  elephant.service               (Wayland-only)
battery-monitor.sh          → systemctl --user enable --now omarchy-battery-monitor.timer   (✅ we activate)
recover-internal-monitor.sh → systemctl --user enable omarchy-recover-internal-monitor.service  (Hypr-only)
```
