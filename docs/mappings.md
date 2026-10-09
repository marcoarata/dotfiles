# Mappings & aliases — YADR 2027 compatibility contract

Leader Vim/Neovim: `,`. Tmux prefix: `Ctrl-A`. Shell: vi-mode + Ctrl-R.
Prompt: `dir »` (green ») + git on the left, runtime on the right.

## Shell: navigation and aliases (skwp/dotfiles parity verified)

| Classic | 2027 | Status |
|---|---|---|
| `z <frag>` (fasd) | `z <frag>` (zoxide) | ✅ same key, new backend |
| `ae` / `ar` | `ae` / `ar` (edit `shell/aliases.zsh`) | ✅ |
| `gar` | `gar` (`killall -HUP zsh`) | ✅ |
| `cdb`, `cls`, `cl` | same | ✅ |
| `lsg`, `lh`, `df -h`, `du -h -d2` | same | ✅ |
| `less -r`, `tf`, `l`, `gz`, `ka9`, `k9` | same | ✅ |
| `psa`, `psg` | same | ✅ (`psr` omitted: was ruby-only; see Ruby Pack) |
| `:q` → exit | same | ✅ |
| `ve` (`~/.vimrc`) | `ve` (`~/.config/nvim/init.lua`) | ✅ adapted to Neovim |
| `ze` (`~/.zshrc`) | same | ✅ |
| `yup` (update-plugins) | `yup` → `yadr update` | ✅ adapted |
| `hpr` (hub) | `hpr` → `gh pr create` (if `gh` exists) | ✅ modernized |
| `brewu` | same (if `brew` exists) | ✅ |
| `yav/ydv/ylv/yip` (ruby plugin script) | — | ❌ removed: replaced by `:Lazy` in Neovim |
| Rails/zeus/spring/thin/mongrel/sprintly | — | ❌ removed: dead ecosystem (see Ruby Pack if rescued) |
| `showFiles/hideFiles/todo/portforward/sgi` | — | ❌ removed: old macOS / dead apps |

## Git (shell → `git <sub>`; `sub`s live in `git/gitconfig`)

| Classic | 2027 | Status |
|---|---|---|
| `g`, `gs`, `gst/sh/pp/sa`, `gsh`, `gi` | same | ✅ |
| `gcm/gcim/gci`, `gco`, `co`, `ga`, `gap` | same | ✅ |
| `gm/gms/gam`, `grv/grr/grad`, `gr/gra/ggrc/gbi` | same | ✅ |
| `gl/glg/glog`, `gf*`, `gd/gdc/gds` | same | ✅ (`gl` with own rich format) |
| `gpl/gplr/gps/gpsh`, `gnb`, `grs/grsh` | same | ✅ |
| `gcln/gclndf/gclndfx`, `gsm/gsmi/gsmu` | same | ✅ |
| `gbg/gbb`, `gdmb`, `grb`, `guns/gunc` | same | ✅ (`guns`=`unstage`, `gunc`=`uncommit`; `gdmb` as function + `git gdmb`, portable BSD/GNU without `xargs -r`) |
| `gt` | `gt` → `git t` (`tag -n`) | ✅ aligned to classic |
| `gpub/gtr` (external `grb` script) | — | ❌ removed: depended on a nonexistent binary |
| `svn*`, `mt` (mergetool without config) | — | ❌ removed |

## Vim/Neovim (leader `,`)

| Classic | 2027 | Status |
|---|---|---|
| `,z` / `,x` | previous / next buffer | ✅ |
| `,f` / `,F` | definition (LSP) / vertical | ✅ ctags→LSP (`,f` preserved; ctags not bundled) |
| `,gf` | file under cursor | ✅ native |
| `,gg` / `,gd` / `,gcf` | project grep / definition / current file (rg) | ✅ ag→rg |
| `,t` | Telescope `find_files` | ✅ CtrlP→Telescope (txt default) |
| `,b` | Telescope buffers | ✅ |
| `Ctrl-P` | Telescope files | ✅ |
| `Ctrl-R` | shell history | ✅ (in Vim: native redo) |
| `Ctrl-h/j/k/l` | seamless Vim/tmux navigation | ✅ |
| tmux prefix `Ctrl-A` | same (not `Ctrl-B`) | ✅ |
| `,hs/,hr/,hp/,hb` | gitsigns hunks | ✅ opt-in only (`yadr gitsigns on`); without it they do not exist |

Rule: if a 2027-column mapping is missing or does something else, it is a bug.
Implementation may change (ag→rg, CtrlP→Telescope, ctags→LSP), the key does not.

Technical note: `rg`/`fd` do NOT mask `grep`/`find` (`alias grep=rg` would break
flags such as `grep -Ev`). They are first-class commands; originals left intact.
