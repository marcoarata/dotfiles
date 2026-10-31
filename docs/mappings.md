# Mappings & aliases — YADR 2027 compatibility contract

Leader Vim/Neovim: `,`. Tmux prefix: `Ctrl-A`. Shell: vi-mode + Ctrl-R.
Prompt: `dir »` (green ») + git on the left, runtime on the right.

## Shell aliases

| Classic | 2027 | Status |
|---|---|---|
| `z <frag>` (fasd) | `z <frag>` (zoxide) | same key, new backend |
| `ae` / `ar` | `ae` / `ar` (edit `shell/aliases.zsh`) | kept |
| `gar` | `gar` (`killall -HUP zsh`) | kept |
| `cdb`, `cls`, `cl`, `lsg`, `lh`, `df -h`, `du -h -d2` | same | kept |
| `less -r`, `tf`, `l`, `gz`, `ka9`, `k9`, `psa`, `psg` | same | kept |
| `:q` → exit | same | kept |
| `ve` (`~/.vimrc`) | `ve` (`~/.config/nvim/init.lua`) | adapted to Neovim |
| `ze` (`~/.zshrc`) | same | kept |
| `yup` (update-plugins) | `yup` → `yadr update` | adapted |
| `hpr` (hub) | `hpr` → `gh pr create` (if `gh` exists) | modernized |
| `brewu` | same (if `brew` exists) | kept |
| `yav/ydv/ylv/yip`, Rails/zeus/spring/thin/mongrel/sprintly | — | removed: replaced by `:Lazy` or dead ecosystem |
| `showFiles/hideFiles/todo/portforward/sgi` | — | removed: old macOS/dead apps |

## Git (shell → `git <sub>`; subs live in `git/gitconfig`)

| Classic | 2027 | Status |
|---|---|---|
| `g`, `gs`, `gst/sh/pp/sa`, `gsh`, `gi` | same | kept |
| `gcm/gcim/gci`, `gco`, `co`, `ga`, `gap` | same | kept |
| `gm/gms/gam`, `grv/grr/grad`, `gr/gra/ggrc/gbi` | same | kept |
| `gl/glg/glog`, `gf*`, `gd/gdc/gds` | same | `gl` has its own rich format |
| `gpl/gplr/gps/gpsh`, `gnb`, `grs/grsh` | same | kept |
| `gcln/gclndf/gclndfx`, `gsm/gsmi/gsmu` | same | kept |
| `gbg/gbb`, `gdmb`, `grb`, `guns/gunc` | same | `guns`=unstage, `gunc`=uncommit; portable BSD/GNU |
| `gt` | `gt` → `git t` (`tag -n`) | aligned to classic |
| `gpub/gtr`, `svn*`, `mt` | — | removed: missing binary, dead workflow, no config |

## Vim/Neovim (leader `,`)

| Classic | 2027 | Status |
|---|---|---|
| `,z` / `,x` | previous / next buffer | kept |
| `,f` / `,F` | definition (LSP) / vertical | ctags→LSP; ctags not bundled |
| `,gf` | file under cursor | native |
| `,gg` / `,gd` / `,gcf` | project grep / definition / current file (rg) | ag→rg |
| `,t` | Telescope `find_files` | CtrlP→Telescope |
| `,b` | Telescope buffers | kept |
| `Ctrl-P` | Telescope files | kept |
| `Ctrl-R` | shell history | in Vim: native redo |
| `Ctrl-h/j/k/l` | seamless Vim/tmux navigation | kept |
| tmux prefix `Ctrl-A` | same (not `Ctrl-B`) | kept |
| `,hs/,hr/,hp/,hb` | gitsigns hunks | opt-in only (`yadr gitsigns on`) |

Rule: if a 2027-column mapping is missing or does something else, it is a bug.
Implementation may change (ag→rg, CtrlP→Telescope, ctags→LSP), the key does not.

`rg`/`fd` do not mask `grep`/`find` (`alias grep=rg` would break flags such as
`grep -Ev`). They are first-class commands; the originals stay intact.
