# Field report: YADR 2027 on macOS Ventura (Intel x86_64)

**Date:** 2026-10-07 · **Machine:** macOS 13.7.8 Ventura, Intel x86_64 ·
**Repo:** local checkout at `~/.yadr-2027` · **Result:** `yadr doctor` → 0 errors,
0 warnings.

## Context

Homebrew 7.0.0 (2026-09-13) made its installer Apple Silicon only and stopped
building Intel bottles, so this machine landed on **Tier 3**. Dependencies were
installed from MacPorts; the failures below appeared there. Before the fixes:
`brew --prefix` → `/usr/local` with an empty `brew list`, `brew doctor` warning
about Tier 3 + MacPorts, and MacPorts already providing `tmux`, `neovim 0.12.4`,
`ripgrep`, `fd`, `zoxide`, `lazygit`, `mise`, `node 24`, `python 3.14`.

## Problems → fixes

| # | Problem | Fix |
|---|---|---|
| P1 | `zsh-syntax-highlighting` / `zsh-autosuggestions` missing from MacPorts; `shell/plugins.zsh` never looked in `/opt/local/share/` | clone both into `~/.local/share/yadr-plugins/` (no sudo); added `/opt/local/share/` to the lookup; `doctor` now checks them (advisory) |
| P2 | `~/.zprofile` ran `brew shellenv` unconditionally | guard on `[[ -x /usr/local/bin/brew ]]` (fallback `command -v brew`), add `~/.local/bin` and `mise/shims` without duplicates |
| P3 | MacPorts `fzf` not integrated | `shell/zshrc` sources `/opt/local/share/fzf/{shell/,}key-bindings.zsh` + completion and `fzf --zsh`, all guarded |
| P4 | `platform/macos.sh` only knew Homebrew | new `PORT_PACKAGES` (`delta`→`git-delta`) + `install_via_macports()` with XDG clones as no-sudo fallback; Intel tries MacPorts first |
| P5 | `vim` opened genuine Vim, not Neovim | `ensure_vim_macos()` creates `~/.local/bin/vim → nvim` + `provides-vim` marker (removed by uninstall) |
| P6 | `yadr benchmark shell` broke on BSD `date +%s%N` | `now_ns()` validates the form and falls back to `python3 time.time_ns()` |
| P7 | iTerm2 profiles misaligned the Nerd Font | `MasterDev`: Monaco 15 + JetBrainsMonoNFM-Regular 15 (Mono, same size), `Use Non-ASCII = 1` |

## Final verified state

- `yadr doctor`: **0 errors, 0 warnings**; `yadr diff`: 0 changes.
- `zsh -i -c`: `HL_OK`, `SG_OK`, `^E` bound; `zsh -l -i -c`: `tmux/rg/fd/zoxide/mise/nvim` on PATH; `vim --version` → `NVIM v0.12.4`.
- `benchmark prompt`: 0 ms/render; `benchmark shell`: ~700 ms (over the 500 ms threshold; split: base 0.03 s, `mise activate` 0.18 s, plugins 0.06 s, cold `compinit` 2.1 s — Intel + mise cost, not a regression; informational).
- `nvim --headless +qa`: clean, plugins on lockfile.

## Pending / upstream

1. Keep Intel/Tier 3 detection + MacPorts/XDG fallback documented (README does).
2. Review MacPorts name mappings (`delta`→`git-delta`, `fd`, `mise`).
3. The advisory zsh-plugin doctor checks are portable upstream.
4. `~/.gitconfig.user` is optional; the placeholder identity stays until defined.
5. Keep the Monaco + Nerd Mono pattern documented (README/troubleshooting do).
