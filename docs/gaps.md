# Gaps vs vanilla Omarchy

Where nw-omarchy is at parity, what's intentionally dropped, and what's still worth building. Last refreshed after closing the top-five gap items (mic-mute LED, battery notifier, update indicator, idle screensaver, calculator).

## Footprint

|  | omarchy | nw-omarchy |
|---|---:|---:|
| `bin/` helpers | 227 | 49 |
| `default/` component dirs | 24 | 12 |

The 178-helper gap is mostly omarchy's hardware/install/system internals which we either reuse via PATH (no need to fork) or that target the boot/filesystem layer (out of scope here).

## At parity ✅

- **Window manager + bindings** — bspwm/sxhkd mirror hyprland's full binding map (apps, webapps, focus, swap, workspaces, resize, screenshots, multimedia, universal clipboard copy/paste/cut)
- **Top bar** — polybar with the omarchy-logo launcher, per-module click actions, and the same nerd-font icons waybar uses (audio/wifi/bluetooth/battery)
- **Compositor effects** — picom-ftlabs animations (zoom-open / squeeze-close / slide-on-tag-change), blur, rounded corners, fade
- **System menu** (`super+alt+space`) — 1:1 port of `omarchy-menu` via `rofi -dmenu`, every leaf
- **App launcher** (`super+space`) — pinned-apps cheat-sheet parsed from sxhkdrc, type to filter, chord shown next to each
- **Keybindings cheat-sheet** (`super+k`) — searchable list of every binding, with leading-comment as description
- **Theme integration** — bspwm border / rofi / polybar regenerate via `omarchy-theme-set-templates` on every theme change. Same path omarchy uses for hypr.
- **SDDM picker theme** — clone of the omarchy theme with a session selector added
- **Touchpad gestures** — 3-finger horizontal → workspace switch via `libinput-gestures`
- **Clipboard manager** — clipmenu (rofi-backed) via `super+ctrl+v`
- **Lock screen** — i3lock-color, palette pulled from active theme
- **Floating Setup TUIs** — wiremix / impala / bluetui / fastfetch open as centered floating overlays
- **Doctor / status** — `nw-omarchy-doctor` lints the live install in 8 categories
- **Input prefs** — natural-scroll, keyboard repeat 250/40, parity with omarchy's hypr `input.conf`
- **Idle handling** — xidlehook fires the tte terminal-art screensaver at 5 min, `loginctl lock-session` (→ xss-lock → nw-omarchy-lock) at 10 min
- **Battery notifier** — reuses omarchy's `omarchy-battery-monitor.timer`; bspwmrc starts it on session start
- **Mic-mute LED** — `nw-omarchy-cmd-mic-mute` flips `platform::micmute` on ThinkPads (no-ops on hardware without the LED)
- **Update-available indicator** — polybar `module/update` polls `omarchy-update-available` every 10 min; click runs `omarchy-update` in a floating terminal
- **Calculator in launcher** — `super+ctrl+c` opens rofi calc mode; Enter copies the result to clipboard

## Intentional drops ⛔

Wayland-only or out-of-scope, with no useful X11 cousin in our stack:

| Component | Reason |
|---|---|
| Walker rich preview pane (theme picker) | Walker is Wayland-only; rofi has no preview equivalent |
| Continuous workspace swipe with live preview | bspwm has no compositor camera; libinput-gestures fires on completion only |
| Hyprland's `dim_inactive` focus dimming | picom-ftlabs has no focus-aware dim |
| Voxtype dictation | Wayland-only |
| Native fractional scaling | X11 only does integer-per-output |
| Polybar tooltips on hover | polybar 3.x limitation; right-click is our secondary path |
| Plymouth boot splash, snapper snapshots, limine theme | Boot/filesystem layer — outside the project scope |
| Hyprsunset / hypridle (Wayland daemons) | Replaced with redshift / xss-lock |

## Gaps worth filling 🔨

The top five are now closed (see "At parity" above). What remains:

| # | Gap | Effort | Notes |
|---:|---|---|---|
| 1 | **Web-search provider in launcher** | ~30 min | Walker has a `websearch` provider; rofi has no built-in equivalent. Could ship a custom rofi mode (small bash script) that forwards typed input to a search engine via `xdg-open`. |
| 2 | **Icons in app launcher** | ~5 min | `show-icons` is currently off. Re-enabling for `nw-omarchy-launcher` shows app icons next to labels (matches walker). Minor cosmetic gain. |

## Not worth doing ❌

- **Walker-style preview pane** in theme picker — different UX, substantial rofi-mode rewrite for marginal gain. The 17-theme name list is fine.
- **Per-monitor scaling** — X11 doesn't support it cleanly; `nw-omarchy-cycle-scaling` does whole-screen integer scale and that's the ceiling.
- **Forking omarchy-pkg-* / -theme-* / -update / -setup-* / -font-*** — they're cross-stack-portable; we just call them.
- **First-run helper** parity (`omarchy-cmd-first-run`) — our install pipeline is idempotent and `nw-omarchy-doctor` is the equivalent post-install check.

## Recommended next moves

The top-5 gap items have landed. Beyond this, the project is in "polish" territory:

1. Web-search launcher provider (parity quirk; nice-to-have)
2. Icons in app launcher (5-minute cosmetic)

Beyond those, deeper omarchy parity work hits the X11 ceiling — see "Intentional drops" — so further effort returns diminishing UX gains. Live with it for a few weeks before deciding whether anything else needs revisiting.
