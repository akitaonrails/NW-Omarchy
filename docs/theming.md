# Theming

nw-omarchy borrows omarchy's theme machinery instead of inventing its own.
That means: when you run `omarchy-theme-set tokyo-night` (or any theme
omarchy knows about), bspwm borders, rofi, polybar and the wallpaper all
re-paint to match — same code path that re-themes Hyprland.

## How omarchy themes work (briefly)

- Themes ship at `~/.local/share/omarchy/themes/<name>/`. Each carries a
  `colors.toml` (universal palette: `accent`, `background`, `cursor`,
  `foreground`, `selection_*`, `color0..15`) plus per-app config files.
- Active theme lives at `~/.config/omarchy/current/theme/` (a regular
  directory, atomically swapped on theme change). `theme.name` next to it
  records the active theme's name.
- Every app that supports theming `import`s/`source`s an absolute path under
  `current/theme/`. When omarchy swaps the dir, every app reloads.
- Omarchy ships per-app templates at `~/.local/share/omarchy/default/themed/`
  and reads user templates from `~/.config/omarchy/themed/`. On every
  `omarchy-theme-set`, `omarchy-theme-set-templates` parses
  `colors.toml`, then `sed`-substitutes `{{ key }}`, `{{ key_strip }}` (no
  leading `#`), `{{ key_rgb }}` (decimal R,G,B) over each `.tpl` and writes
  the rendered file into `current/theme/`. User templates win over
  built-ins.

## What we plug in

`install/themed.sh` symlinks our `default/themed/*.tpl` files into
`~/.config/omarchy/themed/`. From then on every `omarchy-theme-set` (or
`omarchy-theme-update`) regenerates them. Symlinks are tracked in the
manifest so uninstall removes them.

| Template | Rendered to | Consumer |
|---|---|---|
| `bspwm-colors.conf.tpl` | `current/theme/bspwm-colors.conf` | bspwmrc sources it after the static fallback colors |
| `rofi-colors.rasi.tpl` | `current/theme/rofi-colors.rasi` | `default/rofi/config.rasi` `@import`s it |
| `polybar-colors.ini.tpl` | `current/theme/polybar-colors.ini` | `default/polybar/config.ini` `include-file`s it after the static `[colors]` |

For wallpaper, `bspwmrc` reads `~/.config/omarchy/current/background` (the
symlink omarchy maintains to the active theme's background image) and
hands it to `feh --bg-fill`.

Already-themed-for-free (no work from us — the omarchy configs already
import from `current/theme/`):

- alacritty (terminal palette)
- btop (TUI colors)

## Universal keys

All 17 (and counting) omarchy themes ship the same key set, so our
templates reference only:

- `accent`, `background`, `cursor`, `foreground`, `selection_background`, `selection_foreground`
- `color0..color15` (full ANSI palette)

Anything outside that set is theme-specific and would render as the literal
string `{{ key }}` on themes missing it. Don't use those.

## Adding a template

1. Drop `myapp-colors.conf.tpl` in `default/themed/`. Use only the universal
   keys above.
2. Re-run `./install.sh --apply` — the symlink step is idempotent and will
   pick up the new file.
3. Wire your consumer to source/include the rendered output at
   `~/.config/omarchy/current/theme/myapp-colors.conf`.
4. Run `omarchy-theme-refresh` once to render against the current theme
   (the install step does this for you on first run).

## When omarchy adds new themes

Nothing to do. `omarchy-theme-update` pulls new themes upstream;
`omarchy-theme-install <name>` fetches one. Whatever the user picks next via
`omarchy-theme-set <name>`, our templates render against that theme's
`colors.toml` automatically.

## Caveat: precedence

User templates (`~/.config/omarchy/themed/`) win over built-in templates
(`~/.local/share/omarchy/default/themed/`). If omarchy ever ships a template
with the same filename as one of ours (e.g. they invent a
`bspwm-colors.conf.tpl`), our symlink shadows theirs. Worth keeping in mind
when picking template names. We currently use a `bspwm-`/`rofi-`/`polybar-`
prefix to stay clear of any plausible omarchy upstream names.
