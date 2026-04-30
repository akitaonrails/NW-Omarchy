# Universal clipboard

Three keys mirror omarchy's universal copy/paste/cut. Implementation is asymmetric on purpose — terminal safety wins.

```
super + c   →   xdotool key --clearmodifiers ctrl+Insert
super + v   →   xdotool key --clearmodifiers ctrl+v
super + x   →   xdotool key --clearmodifiers ctrl+x
```

`--clearmodifiers` releases super (still physically held by the user) before the synthetic press, so apps see a clean `ctrl+Insert` / `ctrl+v` / `ctrl+x` and not `super+ctrl+…`.

## Why ctrl+Insert for copy but ctrl+v for paste

omarchy uses `ctrl+Insert` / `shift+Insert` / `ctrl+x`. We use `ctrl+Insert` / `ctrl+v` / `ctrl+x`. The difference is `super+v`:

| Keysym | Browser behavior on X11 | Terminal | Why we (don't) use it for paste |
|---|---|---|---|
| `shift+Insert` | Pastes from **PRIMARY** (X mouse-highlight buffer) | Default: pastes PRIMARY | Different buffer than CLIPBOARD — `super+c` writes CLIPBOARD, so `super+v` reading PRIMARY paste's the wrong thing |
| `ctrl+v` | Pastes from CLIPBOARD ✓ | Default: forwarded to running app (bash readline `verbatim`, tmux command, etc) | Universal in GUI apps; needs an override in terminals |

For copy, `ctrl+c` is unsafe (it's SIGINT in any terminal) so we keep `ctrl+Insert` which alacritty handles via our override. For paste, `ctrl+v` is universally CLIPBOARD-safe and we add the matching override in alacritty.

## App matrix

What works without any user config beyond what nw-omarchy ships:

| App class | super+c | super+v | super+x | Notes |
|---|---|---|---|---|
| Browsers (Firefox / Brave / Chrome / Edge / Opera / Vivaldi) | ✓ | ✓ | ✓ | Standard CLIPBOARD bindings |
| GTK apps (Nautilus, Gedit, GIMP, …) | ✓ | ✓ | ✓ | |
| Qt apps (KeePassXC, qBittorrent, …) | ✓ | ✓ | ✓ | |
| Electron (VSCode, Slack, Discord, Spotify, Signal, Obsidian, 1Password) | ✓ | ✓ | ✓ | Chromium under the hood |
| LibreOffice / Inkscape / Krita | ✓ | ✓ | ✓ | |
| Alacritty | ✓ | ✓ | terminal-app | We ship `default/alacritty/keybindings.toml` with Ctrl+Insert→Copy, Shift+Insert→Paste, Ctrl+V→Paste. ctrl+x is forwarded to whatever's running inside (bash readline, vim, etc) |
| JetBrains / Eclipse | ✓ | ✓ | ✓ | XTestFakeKeyEvent works in modern JVMs |

What needs additional user config (we don't ship these because you don't have them installed):

| App class | What to add |
|---|---|
| Kitty       | `~/.config/kitty/kitty.conf`: `map ctrl+v paste_from_clipboard` |
| Ghostty     | `~/.config/ghostty/config`:  `keybind = ctrl+v=paste_from_clipboard` |
| xterm / urxvt | Compile-time / Xresources clipboard support is scarce; consider switching |
| tmux         | tmux eats `ctrl+v` as `verbatim`; `unbind C-v` in `.tmux.conf` |
| Vim visual mode | `set clipboard=unnamedplus` (vim's own register routing) |

## Clipboard history

Separate from the universal copy/paste pair: `super + ctrl + v` opens a rofi-driven history of the last N CLIPBOARD entries (clipmenu, autostarted from bspwmrc).

## Diagnostic recipe

If `super+c` or `super+v` ever stops firing:

```bash
# 1. Is sxhkd alive and grabbing?
pgrep -af 'sxhkd -c' | head -1

# 2. What does sxhkd think super+c does? (it does silently — no list output)
grep -B 1 -A 1 '^super + c$' ~/.local/share/nw-omarchy/default/sxhkd/sxhkdrc

# 3. Add a temporary debug to the binding
#    super + c
#        sh -c 'notify-send "fired"; xdotool key --clearmodifiers ctrl+Insert'
#    Press the key from your real keyboard (xdotool injections don't always
#    reach passive grabs). If you see the notification → sxhkd works,
#    issue is xdotool / target app not honouring ctrl+Insert.

# 4. Test xdotool directly
focused_class=$(xdotool getactivewindow getwindowclassname)
echo "active window class: $focused_class"
```
