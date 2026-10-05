# YADR 2027

Yet Another Development Runtime. The classic YADR experience with modern technology.

## Overview

YADR 2027 keeps the classic YADR experience contract — Zsh + Vim everywhere + mnemonic aliases + tmux + fluid Git + Damoekri prompt — and replaces the aged implementation (RVM + Rake + Vundle + fasd + ag + hub) with a modern stack with no mandatory Ruby.

Philosophy:

- **Experience > plugins.** Capabilities and muscle memory are preserved, not plugin lists.
- **Vim Everywhere.** Zsh vi-mode, Neovim/Vim, tmux hjkl, inputrc/editrc.
- **Fallbacks, never hard failures.** Every modern alias (`eza`, `bat`, `rg`, `fd`, `zoxide`, `delta`) degrades to the POSIX tool when missing.
- **Core vs extras.** Portable core for macOS/Linux/WSL/SSH. macOS hacks and iTerm go to extras.
- **Customization without forking.** `before / defaults / after`.
- **Damoekri is sacred.** The prompt is modernized internally, its personality stays unchanged.

## Installation — YADR 2027

### 1) macOS

```bash
# 1. Homebrew (only if missing)
 /bin/babash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Minimal dependencies
brew install curl git zsh

# 3. Install YADR 2027 (downloads bootstrap, detects macOS/arm64,
#    installs prerequisites via platform/macos.sh, clones into ~/.yadr
#    and runs bin/yadr install with automatic backup)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"

# 4. Enter your environment
zsh
yadr doctor
```

Auditable alternative (no `curl | sh`):

```bash
git clone https://github.com/marcoarata/dotfiles.git ~/.yadr
~/.yadr/bootstrap.sh
zsh
yadr doctor
```

### 2) Linux — Debian/Ubuntu, server, WSL

```bash
# 1. System base
sudo apt update && sudo apt upgrade -y

# 2. Minimal dependencies
sudo apt install zsh curl git -y

# 3. Install YADR 2027 (detects linux/wsl, installs via
#    platform/linux.sh or platform/wsl.sh, clones into ~/.yadr
#    and runs bin/yadr install with automatic backup)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"

# 4. Enter your environment
zsh
yadr doctor
```

Auditable alternative:

```bash
git clone https://github.com/marcoarata/dotfiles.git ~/.yadr
~/.yadr/bootstrap.sh
zsh
yadr doctor
```

### What is NO LONGER done (differences from classic YADR)

- No `gnupg2` install for RVM.
- No RVM or Ruby 3.1.0 install (`rvm install/use` removed).
- No `gem install rake` (Rake is no longer the engine).
- No legacy `install.sh` from `skwp/dotfiles`.
- No manual Damoekri setup (`promptinit / prompt damoekri`):
  `shell/zshrc` already sources `shell/damoekri.zsh`, with Git +
  `yadr_runtime_context` (shows Node/Ruby only when present).
- `yadr diff` shows what would change before touching anything;
  `yadr backup` saves to `~/.local/state/yadr/backups/<timestamp>/`.

### Verification

```bash
exec zsh
yadr doctor   # check zsh/git/tmux/nvim/rg/fd/zoxide/mise/node/...
yadr diff     # read-only, changes nothing
```

Equivalence details: `docs/migration.md`.
One-page quick install: `INSTALL-YADR.md`.

## `yadr` commands

```bash
yadr install [profile]  # symlinks + backup + deps (core|node|typescript|ruby|python|rust|development|macos-extras)
yadr update            # git pull + mise upgrade (with backup and confirmation)
yadr doctor            # checks with repair hints
yadr diff              # shows what would change, without modifying anything
yadr backup            # copies to ~/.local/state/yadr/backups/<timestamp>/
yadr uninstall [--dry-run] [--purge]  # removes symlinks, restores your backup and reverts login shell
yadr migrate [--dry-run]  # imports .vimrc.before/.after, .vundles.local... (idempotent)
yadr pack list|add <name>  # optional packs (javascript/typescript/ruby/python/rust)
yadr runtime current|list|use|doctor  # runtime abstraction (mise underneath)
yadr version           # shows version
yadr benchmark shell|nvim|cd|prompt   # measures startup and cd/prompt cost
```

## Classic YADR → 2027

| Classic | 2027 | Note |
|---|---|---|
| RVM + Ruby + Rake | `bootstrap.sh` + `yadr` (bash/zsh) + optional mise | Ruby is no longer an install dependency |
| `rake install` | `yadr install` | idempotent, with prior backup and `yadr diff` as dry-run |
| `rake update` | `yadr update` | same contract |
| Vundle + 90 plugins | lazy.nvim, curated subset + LSP + Treesitter | see `docs/mappings.md` |
| fasd / `z` | zoxide, `z` command preserved | fallback to `cd` |
| ag | ripgrep (`rg`), `,gg/,gd/` mappings preserved | |
| `ls/cat/find/grep/diff` | eza/bat/fd/rg/delta with fallback | originals always available via `command` |
| hub / ghi | `gh` | |
| Exuberant ctags | Universal ctags and/or LSP | `,f` preserved |
| Powerline fonts | Nerd Fonts | verify Damoekri/tmux glyphs |
| Prezto | YADR Zsh Core (audited subset) | no mandatory heavy framework |
| Vim | Vim + Neovim (shared Editor Layer) | shared mappings |
| tmux + Solarized + iTerm | tmux + Solarized/Damoekri + terminal abstraction | iTerm to `platform/macos/` |
| `~/.secrets` | `~/.config/yadr/local/` + optional providers (age/sops/1Password) | mode 700 |
| `~/.vimrc.before/.after`, `~/.gitconfig.user` | `custom/before/`, `custom/after/`, coexistence via parallel mode + backup (migrate on roadmap) | never need to fork |

Full details: `docs/mappings.md`, `docs/migration.md`.

## Repo layout

```text
.
├── bootstrap.sh        # portable entrypoint
├── bin/yadr           # CLI: install/update/doctor/migrate/pack
├── shell/             # zshrc, aliases, functions, completion, damoekri prompt
├── git/               # base gitconfig + YADR aliases
├── nvim/ / vim/      # shared Editor Layer
├── tmux/              # Vim-key tmux.conf
├── runtime/           # Runtime Layer: mise.toml, node/python/ruby/rust
├── packs/             # optional packs (rails, node, python...)
├── platform/          # macos/ linux/ wsl/ common/
├── custom/            # before/ after/ (user-owned, never touched by update)
├── docs/              # architecture, mappings, migration, troubleshooting
└── tests/             # smoke.sh, shell.bats, fixtures/
```

## Packs

Packs = optional on-demand installable layers:

```bash
yadr pack list
yadr pack add node-typescript
yadr pack add ruby-rails
```

Each pack ships a `mise.toml` fragment, aliases, and editor config. Core never depends on a pack. See `docs/architecture.md`.

## Damoekri

Damoekri is a first-class component, not a swappable theme. Preserved:

- directory + editor mode on the left
- git branch + status on the right
- Solarized look by default

Ruby info is removed from the prompt unless the ruby pack is active. Implemented in `shell/damoekri.zsh`, which consumes `yadr_runtime_context` from `shell/runtime.zsh` and never invokes managers directly. Without a Nerd Font it renders degraded (no broken glyphs).

More: `docs/architecture.md`, `docs/troubleshooting.md`.
