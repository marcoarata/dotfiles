# YADR 2027 — terminal/solarized/README.md
Solarized palettes for terminals (faithful to classic YADR `iTerm2/`).

- `Solarized-Dark.itermcolors` / `Solarized-Light.itermcolors`: iTerm2
  (iTerm2 → Settings → Profiles → Colors → Color Presets → Import).
  Source: iTerm2-Color-Schemes (faithful ports of the Schoonover palette).
- GNOME Terminal / others: use your terminal Solarized profile with the
  same 16 ANSI colors (base03…base3); exact values are in the
  `.itermcolors` above.

Palette credit: https://ethanschoonover.com/solarized/
(also in `CREDITS.md`).

## Background: transparent (`none`) by default

Neovim ships transparent on macOS **and** Linux: after `solarized8`
loads, `Normal/NonText/LineNr/SignColumn` are cleared to `guibg=NONE`
(`nvim/lua/yadr/plugins/colorscheme.lua`). Solid `dark`/`light` only
on explicit choice.

- macOS `install` asks: `1) light (solid) / 2) dark (solid) /
  3) none — transparent (default)`. `Enter`, invalid answer, no TTY
  (`curl | sh`, CI) or `--yes` all mean `none`.
- Choice is stored in `~/.config/yadr/solarized-bg` (read on every
  nvim start). `YADR_SOLARIZED_BG=light|dark|none` env wins without
  prompting; legacy `YADR_SOLID_BG=1` forces solid dark.
- Linux/WSL never prompt: always `none` unless you create that file
  or export the env var.

## Changing it later: `yadr theme`

```bash
yadr theme list              # shows light|dark|none, current marked with *
yadr theme use dark          # (also: solarized-dark; light|solarized-light|none)
yadr theme dark              # shorthand, same as use
yadr theme current           # prints the effective choice + where it comes from
yadr theme                   # interactive menu with TTY (Enter keeps current)
```

No sudo, instant, macOS and Linux. Takes effect when you reopen nvim
(the file is read at startup; `YADR_SOLARIZED_BG` env still wins).
