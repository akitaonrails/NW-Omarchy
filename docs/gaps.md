# Gaps vs vanilla Omarchy

Where nw-omarchy is at parity, what's intentionally dropped, and what's still worth building. Last refreshed alongside commit `5954564`.

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

Ranked by user-visible impact:

| # | Gap | Effort | Notes |
|---:|---|---|---|
| 1 | **Auto-launch screensaver on idle** | ~30 min | omarchy uses hypridle. xss-lock locks-on-idle but doesn't fire the tte terminal-art screensaver. Add `xidlehook` config or `xss-lock --notifier`. |
| 2 | **Update-available indicator in polybar** | ~20 min | omarchy waybar's `custom/update` module pulses on available updates. Add a polybar `custom/script` calling `omarchy-update-available`. |
| 3 | **Battery low-battery notifier** | ~5 min | `omarchy-battery-monitor` ships as a systemd user service. Reuse — autostart from bspwmrc or enable the existing unit. |
| 4 | **Calculator / web-search in launcher** | ~30 min | Walker has `calc` and `websearch` providers. Rofi via `rofi-calc` (AUR) + a custom websearch mode. |
| 5 | **Mic-mute LED on ThinkPads** | ~5 min | Bind `XF86AudioMicMute` to `omarchy-cmd-mic-mute-thinkpad` instead of plain `pactl`. |
| 6 | **Icons in app launcher** | ~5 min | We disabled `show-icons` in rofi. Re-enabling for `nw-omarchy-launcher` shows app icons next to labels (matches walker). Minor cosmetic gain. |

## Not worth doing ❌

- **Walker-style preview pane** in theme picker — different UX, substantial rofi-mode rewrite for marginal gain. The 17-theme name list is fine.
- **Per-monitor scaling** — X11 doesn't support it cleanly; `nw-omarchy-cycle-scaling` does whole-screen integer scale and that's the ceiling.
- **Forking omarchy-pkg-* / -theme-* / -update / -setup-* / -font-*** — they're cross-stack-portable; we just call them.
- **First-run helper** parity (`omarchy-cmd-first-run`) — our install pipeline is idempotent and `nw-omarchy-doctor` is the equivalent post-install check.

## Recommended next moves

If you want to keep building, the order with the highest-impact return:

1. Auto-launch screensaver on idle
2. Update-available indicator
3. Battery low-battery notifier
4. Mic-mute LED on ThinkPads
5. Calculator in launcher

Together these close the user-perceptible gap to roughly nothing on a daily-driver basis. Beyond them you're into "mostly identical" territory where further work returns diminishing UX gains.
