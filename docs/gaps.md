# Gaps vs vanilla Omarchy

Where nw-omarchy is at parity, what's intentionally dropped, and what's still worth building. Last refreshed after the picom v13 + XLibre + binding-parity sweep (early May 2026).

## Footprint

|  | omarchy | nw-omarchy |
|---|---:|---:|
| `bin/` helpers | 227 | 49 |
| `default/` component dirs | 24 | 12 |

The 178-helper gap is mostly omarchy's hardware/install/system internals which we either reuse via PATH (no need to fork) or that target the boot/filesystem layer (out of scope here).

## At parity ✅

- **X server** — XLibre (maintained xorg-server fork) installed by the regular `install.sh --apply` pipeline. Coexists with omarchy's hyprland (xorg-xwayland untouched). See [`why-xlibre.md`](why-xlibre.md), [`xlibre.md`](xlibre.md).
- **Window manager + bindings** — bspwm/sxhkd mirror hyprland's full binding map: apps + webapps, focus / swap / workspaces, resize, screenshots, multimedia, and the omarchy v2 `super+l` ↔ `super+ctrl+l` convention (layout vs lock). 73 bindings total.
- **Top bar** — polybar with the omarchy-logo launcher, per-module click actions, the same nerd-font icons waybar uses (audio/wifi/bluetooth/battery), and a custom-script battery module that handles the firmware-paused-on-AC state polybar's internal/battery silently dropped.
- **Compositor effects** — upstream picom v13: blur, rounded corners, shadows, opacity-rule, fade-on-open/close. Replaces the abandoned FT-Labs fork whose animation system never engaged on bspwm tag changes. (We tried a custom workspace-pan slide on top of v13's trigger system; reverted to plain fade — see `docs/README.md`.)
- **System menu** (`super+alt+space`) — 1:1 port of `omarchy-menu` via `rofi -dmenu`, every leaf
- **App launcher** (`super+space`) — pinned-apps cheat-sheet parsed from sxhkdrc, type to filter, chord shown next to each
- **Keybindings cheat-sheet** (`super+k`) — searchable list of every binding, with leading-comment as description
- **Notifications** — dunst, themed via the same template pipeline as polybar/rofi/bspwm. `super+,` family dismisses (last/all/silence-toggle), parity with omarchy's mako `super+,` chords. Toast actions: clicking the screenshot toast opens the image (mirrors omarchy-cmd-screenshot's `notify-send -A` pattern).
- **Per-app TUIs** — `super+ctrl+a/b/w/t/h/s` cover audio / bluetooth / wifi / btop / hardware-menu / share-menu via `nw-omarchy-launch-*` and `nw-omarchy-menu`, parity with omarchy's `super+ctrl+letter` family.
- **Theme integration** — bspwm border / rofi / polybar / dunst regenerate via `omarchy-theme-set-templates` on every theme change. Same path omarchy uses for hypr.
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
- **Color picker** — `super+Print` runs `xcolor` and copies the hex to clipboard (xcolor is the X11 substitute for hyprpicker)

## Intentional drops ⛔

Wayland-only or out-of-scope, with no useful X11 cousin in our stack:

| Component | Reason |
|---|---|
| Walker rich preview pane (theme picker) | Walker is Wayland-only; rofi has no preview equivalent |
| Continuous workspace swipe with **live preview** during the gesture | bspwm has no in-progress switch state; libinput-gestures fires on completion only. Hyprland gets it because it's both WM and compositor. |
| **Workspace-pan slide animation** (windows slide as one on switch) | Built it on picom v13 with a custom `offset-x` script keyed off `window-monitor-width`. Reverted because (a) direction was fixed regardless of next/prev — picom can't tell which way the user moved; (b) the slop screenshot overlay got animated through the same `open` trigger, and suppressing it would require migrating every legacy exclude/wintype/opacity option to v13's new `rules` block in one shot. Simple opacity fade for now. |
| Hyprland's `dim_inactive` focus dimming | upstream picom has no focus-aware dim either; would need per-window opacity rule reshuffling on focus events |
| Voxtype dictation | Wayland-only |
| Native fractional scaling | X11 only does integer-per-output |
| Polybar tooltips on hover | polybar 3.x limitation; right-click is our secondary path |
| Plymouth boot splash, snapper snapshots, limine theme | Boot/filesystem layer — outside the project scope |
| Hyprsunset / hypridle (Wayland daemons) | Replaced with redshift / xss-lock |
| `super + c` / `super + v` / `super + x` universal clipboard | Couldn't make X11 key synthesis reliable while super was still physically held — see `docs/clipboard.md`. `ctrl + c` / `ctrl + v` / `ctrl + x` work natively; `super + ctrl + v` opens history. |
| Scratchpad (`super + s` → togglespecialworkspace) | bspwm's marked-node + hidden-flag combo could approximate it but needs a stateful daemon to track the scratch toggle. Niche enough to skip. |
| Window grouping (`super + g`, `super + alt + arrow`, `super + alt + Tab`) | hypr v2's tabbed/stacked groups have no clean bspwm analog. |
| Pop-out window (`super + o` → float + pin) | Trivial in hypr (`togglefloating`+pin), in bspwm needs `bspc node -t floating; bspc node -g sticky=on` plus state to restore. Skipped; users who care can add it locally. |
| Cursor zoom (`super + ctrl + z`) | X11 has no per-cursor zoom; xrandr `--scale` applies globally and looks heavy-handed. |
| Active-window transparency toggle (`super + BackSpace` in hypr) | Would require a per-window picom opacity-rule manager. We use `super + BackSpace` for the gap-toggle that omarchy puts on `super + shift + BackSpace`. |
| Waybar toggle (`super + shift + space`) | Reused that chord for `rofi -show drun` (full app listing) — felt more useful than a bar visibility toggle. polybar can still be toggled via `polybar-msg cmd toggle` if you bind it locally. |
| Capture menu chord (`super + ctrl + c` in omarchy) | Reused for rofi-calc — calculator is more valuable on a laptop. Capture menu still reachable through `super + alt + space` → Capture. |

## Gaps worth filling 🔨

What's still open and worth picking up. Ordered by effort × value:

| # | Gap | Effort | Notes |
|---:|---|---|---|
| 1 | **Icons in app launcher** | ~5 min | `show-icons` is currently off in `nw-omarchy-launcher`. Re-enabling shows app icons next to labels (matches walker). Pure cosmetic. |
| 2 | **Web-search provider in launcher** | ~30 min | Walker has a `websearch` provider; rofi has no built-in equivalent. Custom rofi mode (small bash script) that forwards typed input to a search engine via `xdg-open` would close it. |
| 3 | **Migrate picom config to v13 `rules` block** | ~2 h | Required to suppress per-window animations (e.g. on slop / rofi / dunst). Forces moving every legacy `shadow-exclude` / `blur-background-exclude` / `opacity-rule` / `wintypes` / `rounded-corners-exclude` into the rules block in one shot — picom v13 ignores those legacy keys when `rules` is set. Prerequisite if we ever want the workspace-pan slide back. |
| 4 | **Direction-aware workspace animation** | ~3 h | Daemon listening to `bspc subscribe desktop_focus`, computing forward / backward, and either swapping picom configs or sending a custom IPC. Depends on (3). |
| 5 | **Pre-1.0 → 1.0 migration story** | ~1 h | `bin/nw-omarchy-xlibre-migrate` is a stub. Before we cut 1.0, decide what migration deltas matter (picom-ftlabs-git → picom auto-removal, config schema bumps) and grow the script body. |
| 6 | **Pop-out / scratchpad** if you actually use them | ~1 h each | `super + o` and `super + s` from omarchy v2 — not core to bspwm's model but doable with `bspc node -g sticky=on, hidden=on` plus a state file. |

## Not worth doing ❌

- **Walker-style preview pane** in theme picker — different UX, substantial rofi-mode rewrite for marginal gain. The 17-theme name list is fine.
- **Per-monitor scaling** — X11 doesn't support it cleanly; `nw-omarchy-cycle-scaling` does whole-screen integer scale and that's the ceiling.
- **Forking omarchy-pkg-* / -theme-* / -update / -setup-* / -font-*** — they're cross-stack-portable; we just call them.
- **First-run helper** parity (`omarchy-cmd-first-run`) — our install pipeline is idempotent and `nw-omarchy-doctor` is the equivalent post-install check.

## Recommended next moves

The original "top five" items (mic-mute LED, battery notifier, update indicator, idle screensaver, calculator) all landed. Picom v13 + XLibre + binding parity also landed. The project is now in polish territory:

1. **Icons in app launcher** (5 min, cosmetic)
2. **Web-search launcher provider** (30 min, nice-to-have parity)
3. **picom rules-block migration** if you want to revisit the workspace-pan slide (2h, prereq for direction-aware swipe)
4. **Pre-1.0 → 1.0 migration story** before the first tag (1h)

Beyond those, deeper omarchy parity hits the X11 ceiling — see "Intentional drops" — so further effort returns diminishing UX gains. Live with it for a few weeks before deciding whether anything in the drops list is actually missed in daily use.
