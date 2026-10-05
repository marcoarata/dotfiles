# CREDITS — YADR 2027

YADR 2027 is an evolution of classic YADR. Like it, it would not exist without
the work of many people. Explicit attribution (debt the project
pays here instead of diluting it).

## Classic YADR lineage (skwp/dotfiles)

- **Yan Pritzker (@skwp)** — initial YADR version.
- **@kylewest** — cleanup, auto-installer.
- **@JeanMertz** — switch from oh-my-zsh to Prezto.
- **@duhanebel** — migration to Vundle.
- **@lfilho** — Docker support.
- **Sorin Ionescu** and Prezto — classic Zsh base.
- **Daniel Møller Kristensen (damoekri)** — author of the prompt theme that
  YADR 2027 keeps as visual identity (`shell/damoekri.zsh` is a
  reimplementation, not a copy).
- **Tim Pope, scrooloose, kana, nelstrom** and the vim-scripts community —
  Vim philosophy inherited by `Vim Everywhere`.
- **Ethan Schoonover** — Solarized palette: https://ethanschoonover.com/solarized/
- **Janus (carlhuda), dotvim (astrails)** — historical inspiration for the plugin set.

## 2027 layer (modern implementation, same philosophy)

- **folke/lazy.nvim** — Neovim plugin manager (replaces Vundle).
- **nvim-telescope/telescope.nvim** — picker (replaces CtrlP).
- **williamboman/mason.nvim** — language server installer.
- **nvim-treesitter** — modern parsing (replaces Exuberant Ctags + syntax files).
- Modern CLI tools used as-is (each with its license in its repo):
  `BurntSushi/ripgrep`, `sharkdp/fd`, `sharkdp/bat`, `eza-community/eza`,
  `ajeetdsouza/zoxide`, `junegunn/fzf`, `dandavison/delta`.
- **jdx/mise** — Runtime Layer (replaces RVM/Rake as mechanism, not as idea).
- **ryanoasis/nerd-fonts** — fonts (replace the 2012 Powerline-patched ones).
- **lewis6991/gitsigns.nvim, tpope/vim-fugitive, sindrets/diffview.nvim** —
  Git integration in the editor.
- **JetBrainsMono** (Apache-2.0) via Nerd Fonts — default family.
- **iTerm2-Color-Schemes (mbadolato)** — faithful Solarized ports for
  terminal (`terminal/solarized/`), original Schoonover palette.

## External dependencies note

YADR 2027 downloads ~27 plugin repos + toolchains on install/first use
(see `nvim/lazy-lock.json` and `runtime/mise.toml`, all pinned). If a
third-party repo is deleted, only fresh installs fail; an installed system never
breaks (caches in `~/.local/share`). Offline: shell/Git/tmux stay intact.
