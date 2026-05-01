# Why XLibre

This doc covers the project's reasoning for targeting **XLibre** as its X server, the practical implications of staying on the X11 foundation in 2026, and the things that genuinely don't come back from Wayland/Hyprland that we've chosen to live without. The goal is to let you make an informed decision rather than to advocate for one side.

## What is XLibre

XLibre is a hard fork of the X.Org Server, started **June 2025** by **Enrico Weigelt** — a long-time, prolific X.Org contributor whose accounts and ~140 merge requests were abruptly removed from the freedesktop.org infrastructure earlier that year. The fork point is the upstream X.Org Server tree at the time of his departure; XLibre versions follow upstream's numbering ([XLibre 25.0](https://www.phoronix.com/news/XLibre-25.0-Released) was the inaugural release, mid-2025).

The project's core technical pitch is simple: the upstream X.Org Server is, in its own maintainers' words, *effectively unmaintained beyond security/bug triage* — Red Hat has [publicly committed to dropping it from RHEL 10](https://www.redhat.com/en/blog/rhel-10-plans-wayland-and-xorg-server) (2025) and was the primary funder of new X-server development. XLibre takes the position that there are still real users who depend on X11 and that the codebase deserves continued active maintenance: cleanups, security fixes, modernization, driver-ABI updates.

Distros that ship XLibre as default or tier-one packaging:
- **Artix Linux** ([2026.04+](https://linuxiac.com/artix-linux-2026-04-released-with-xlibre-as-default-x-serve/)) — default X server
- **Fedora** — [open Change proposal](https://fedoraproject.org/wiki/Changes) to migrate
- **Arch Linux** — official binary repo at `x11libre.net/repo/arch_based/` (what nw-omarchy uses)

A note on tone: XLibre's [README](https://github.com/X11Libre/xserver) and Weigelt's public statements include explicit political framing about the fork's circumstances and an empty Code of Conduct file ([coverage in El Reg](https://www.theregister.com/2025/06/10/xlibre_new_xorg_fork/), [Hacker News thread](https://news.ycombinator.com/item?id=44199502)). nw-omarchy uses XLibre on the technical merits — a maintained X server when nothing else fits — and has no opinion on its governance posture.

## Why XLibre over `xorg-server`

The relevant comparison isn't "X.Org Server vs XLibre" as two competing actively-developed projects. It's:

| | xorg-server | XLibre |
|---|---|---|
| Last meaningful release (non-security) | 21.1 (2022) | 25.0 (2025) |
| Active codebase work | none | yes |
| Driver ABI updates | frozen | bumped (`X-ABI-VIDEODRV_VERSION=28.0` in 25.0) |
| Stated future | "Use Wayland" (Red Hat) | continued X server development |
| Coexists with `xorg-xwayland` | yes (same repo) | yes (provides=, no conflict) |
| Maintainer responsiveness | minimal | active |

If you want to **stay on an X11 stack** for any reason — driver compatibility, tooling, workflow, or personal preference — XLibre is the path that gets you ongoing patches. It's a drop-in replacement: the X11 protocol, libxcb/libx11 client API, and pacman dependency graph are all unchanged. Your apps don't know which X server is running.

If you'd rather move to Wayland: just don't run `nw-omarchy`. Stay on Omarchy's Hyprland session — that's exactly the parallel choice this project is designed to coexist with.

## What we materially gain by keeping an X foundation

These are concrete things that work on X11 and don't have clean equivalents on Wayland/Hyprland in 2026:

- **`xdotool` / `wmctrl` / `xprop` / `xinput`** — global key/click synthesis, window-list queries, focus-by-class, modifier-state polling. The entire `nw-omarchy-launch-or-focus` family, the screenshot pipeline (`maim` + `slop` + `xclip`), and the gesture-to-workspace plumbing rely on these. Wayland's per-compositor protocols replace them piecemeal — `wlr-virtual-keyboard`, `xdg-desktop-portal`, `kwin-bindings` — but each compositor implements a different subset.
- **`xclip` / `clipmenu` / `xsel`** — straightforward clipboard plumbing, no permission dialogs. Wayland needs `wl-clipboard` plus a portal in many cases.
- **Mature tiling window managers** — bspwm, i3, awesome, openbox, xmonad, dwm. The Wayland tiling story (Hyprland, Sway, river) is improving but the WM ecosystem is much smaller and configs aren't portable.
- **Established compositor effects** — picom (now v13 upstream) gives blur, rounded corners, shadows, animations, and per-window opacity rules, all driven by simple text config. Hyprland matches this but is its own monolith.
- **Network transparency** — `ssh -X user@host firefox` still works. Wayland has no native equivalent (waypipe is a separate piece of software with a smaller surface area).
- **Older proprietary GPU drivers** — Nvidia legacy drivers, vintage Intel chips, Optimus laptops with quirky muxing — these are first-class on X11 and second-class or unsupported on Wayland.
- **Predictable input model** — every X11 client can read every input event by default. Bad for security, *great* for accessibility tools, screen readers, key remappers (kanata, xkeysnail), input-method editors, AutoKey, and global hotkey daemons that don't need compositor cooperation.

For nw-omarchy specifically, the codebase leans hard on this: ~30 of our `bin/nw-omarchy-*` helpers shell out to `xdotool` / `wmctrl` / `xprop` / `xclip`, and the entire bspwm + picom + polybar + sxhkd + rofi + dunst + clipmenu stack is X11-native.

## What we materially lose vs Hypr/Wayland

Honest tradeoffs. None of these have full X11 equivalents in our stack:

- **Tear-free rendering by design.** Wayland's frame protocol is synchronous with the display. X11 needs picom/compton (which we run) and even then needs `vsync = true` plus a cooperative GPU driver to come close.
- **Per-monitor fractional scaling.** X11 only does integer scaling per output (1×, 2×, 3×). Mixed-DPI multi-monitor setups are clumsy — you pick one scale globally or use xrandr `--scale` tricks that hurt sharpness. Wayland does proper per-output fractional scale natively.
- **HDR support.** Modern Wayland compositors (Hyprland, KDE) ship HDR pipelines. X11 has nothing.
- **Continuous live workspace swipe.** Hyprland's `workspace_swipe` shows the next workspace panning in under your finger as you 3-finger swipe. Our picom v13 + libinput-gestures setup animates the post-completion transition (windows pan together by `window-monitor-width`), but the actual gesture is one-shot — no live preview during the drag. See [`gaps.md`](gaps.md).
- **Direction-aware workspace animations.** Hyprland knows which direction you're swiping; picom v13 doesn't. Our slide is fixed (out-left / in-right) regardless of next/prev. Same `gaps.md` entry.
- **Per-window dimming on focus loss.** Hypr `dim_inactive`. picom has per-window opacity rules but no focus-aware dim.
- **Better security isolation.** On X11 any client can keylog any other client and screen-capture without consent. Wayland blocks this by default. For a single-user desktop this is rarely a real-world threat, but it's a real architectural difference.
- **First-class touch / gesture support.** Wayland compositors talk to libinput natively. On X11 we go through `libinput-gestures` (which only fires on completion, not progressively) and `xinput` for finer settings.
- **HiDPI text rendering.** Subpixel hinting and per-monitor DPI work better on Wayland in mixed-DPI setups.
- **Voxtype / dictation, Walker preview pane, hyprsunset, hypridle** — Wayland-only tools we replace with X11 cousins (`redshift` for nightlight, `xidlehook` + `xss-lock` for idle, no preview pane in rofi).

If any of these are dealbreakers for you, **stay on Omarchy/Hyprland**. nw-omarchy is for people who want the X11 stack on top of a maintained X server, not a Wayland replacement.

## So why does this project exist?

The project's origin story is one specific gap: omarchy is opinionated, beautifully-themed Hyprland — and Hyprland is Wayland-only. If you want the omarchy aesthetic, keybinding map, app launcher chord set, and workflow but you also want an X11 session (because of one or more of the things in the "what we gain" list above), there was no existing port. nw-omarchy fills that hole, on the most-maintained X server still being actively developed.

Pragmatically, the choice for **most omarchy users is "use the Hyprland session that ships by default"**. nw-omarchy is the secondary login option for the cases where X11 is worth the tradeoffs. SDDM picks between them at every login.

## See also

- [`xlibre.md`](xlibre.md) — what the install script actually does, compatibility matrix, revert recipe
- [`gaps.md`](gaps.md) — concrete list of what's at parity with omarchy/hyprland, what's intentionally dropped, what's still buildable
- [`porting-hypr.md`](porting-hypr.md) — Hyprland binding/feature → X11 map
