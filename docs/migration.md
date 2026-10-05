# Migration — classic YADR → 2027

## Old install (reference — DO NOT use for 2027)

### Classic macOS

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install curl
brew install gnupg2
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -sSL https://get.rvm.io | bash
rvm install ruby-3.1.0 && rvm use ruby-3.1.0 --default
gem install rake
sh -c "`curl -fsSL https://raw.githubusercontent.com/skwp/dotfiles/master/install.sh `"
zsh
vim ~/.zshrc
# Theme Damoekri
autoload -Uz promptinit
promptinit
prompt damoekri
source ~/.zshrc
```

### Classic Linux (Debian/Ubuntu, server, WSL)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install zsh -y
sudo apt install gnupg2 -y
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -sSL https://get.rvm.io | bash
rvm install ruby-3.1.0 && rvm use ruby-3.1.0 --default
gem install rake
sh -c "`curl -fsSL https://raw.githubusercontent.com/skwp/dotfiles/master/install.sh `"
zsh
vim ~/.zshrc
# Theme Damoekri
autoload -Uz promptinit
promptinit
prompt damoekri
source ~/.zshrc
```

## New YADR 2027 install (use this)

### macOS 2027

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install curl git zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"
zsh
yadr doctor
```

### Linux 2027 (Debian/Ubuntu, server, WSL)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install zsh curl git -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"
zsh
yadr doctor
```

One-page quick guide: `../INSTALL-YADR.md`.

## What changed, line by line

| Classic step | Status in 2027 | Reason |
|---|---|---|
| `brew install gnupg2` / `apt install gnupg2` | Removed | Only existed to import the RVM key |
| `curl rvm.io/mpapis.asc \| gpg --import` | Removed | RVM key, no more RVM |
| `curl get.rvm.io \| bash` | Removed | RVM out of core (see Runtime Layer) |
| `rvm install/use ruby-3.1.0` | Removed from bootstrap | Ruby moves to optional Pack (`yadr install ruby`); reference moves to Node LTS via mise |
| `gem install rake` | Removed | Rake is no longer the engine; it is `bootstrap.sh → bin/yadr install` (bash) |
| `skwp/dotfiles install.sh → rake install` | Replaced by `bootstrap.sh → bin/yadr install` | Native installer, idempotent, with `backup`/`diff`/`doctor`, multiplatform |
| `vim ~/.zshrc` + manual `promptinit/prompt damoekri` | Automatic | `shell/zshrc` already includes `shell/damoekri.zsh` (cwd + Git + `yadr_runtime_context`); works without runtime |
| manual `source ~/.zshrc` | Replaced by `exec zsh` + `yadr doctor` | `doctor` checks zsh/git/tmux/nvim/rg/fd/zoxide/mise/node with repair hints |

## From RVM+Rake to mise+Node (or no runtime)

Classic:

```bash
curl ...rvm.io | bash
rvm install ruby-3.1.0
gem install rake
sh -c "`curl .../skwp/dotfiles.../install.sh`"
# → rake install
```

2027: Ruby does not take part in bootstrap.

```bash
# Without GitHub yet (local copy, current primary mode):
rsync -a --delete ./dotfiles/ /tmp/marco/opencode/yadr-copy/
YADR_HOME=/tmp/marco/opencode/yadr-copy ./bootstrap.sh --local
# When repo exists:
# git clone <dotfiles> ~/.yadr && ./bootstrap.sh   # or: yadr install
```

- `install.sh → rake install` is replaced by `bootstrap.sh → bin/yadr install`.
- Automatic backups in `~/.local/state/yadr/backups/<timestamp>/` (no more `*.backup2/final2`).
- `mise` only if a pack requires it (e.g. `yadr install node`). Minimal SSH works without mise.
- See `docs/adr-002-runtime-manager.md` for the pending mise/fnm/nvm benchmark decision.

## Parallel vs migrate

- **Parallel (recommended, implemented):** installs YADR 2027 in a `YADR_HOME`
  distinct from classic `~/.yadr` (with `Rakefile`). `bin/yadr install` detects
  it and offers `parallel/migrate/cancel` (default `parallel`). Test with an
  isolated `HOME` before changing login shell.
- **Migrate (implemented):** `yadr migrate [--dry-run]` backs up and copies
  `.vimrc.before/.after` and `.vundles.local` to `~/.config/yadr/migrated/`;
  `.gitconfig.user`, `.tmux.conf.user` and `.secrets` stay in place
  (core includes them by reference, never overwrites). Idempotent.
- **Future `custom/before|after` table:** when the repo gains `custom/`,
  migrated content moves there 1:1. Today `~/.config/yadr/migrated/` is the
  documented stable destination.

## Parallel vs migrate

- **Parallel (recommended):** installs YADR 2027 in `~/.yadr` alongside classic `~/.dotfiles`/`~/.yadr.old`. Test with `zsh -d -f` + isolated `ZDOTDIR` before changing login shell.
- **Migrate:** `yadr migrate` imports classic customization:

  | Classic | 2027 |
  |---|---|
  | `~/.vimrc.before` | `custom/before/vim.vim` + `nvim/lua/custom/before.lua` |
  | `~/.vimrc.after` | `custom/after/vim.vim` + `nvim/lua/custom/after.lua` |
  | `~/.vundles.local` | `custom/*.lazy.lua` (lazy.nvim list) |
  | `~/.gitconfig.user` | preserved as-is, `include` from `git/gitconfig` — **never overwritten** |
  | `~/.tmux.conf.user` | `custom/after/tmux.conf` (sourced last) |
  | `~/.secrets` | `~/.config/yadr/local/secrets` (chmod 700), prompt to migrate to age/sops |

`yadr diff` shows the plan without touching anything (dry-run equivalent). The
future `yadr migrate` will be idempotent; until then, `do_backup` + parallel
mode cover safe coexistence.

## `.vimrc.before → nvim`

- `before` loads **before** defaults (options that must win over core).
- `after` loads **after** (overrides/mappings that win over everything).
- Classic Vimscript still loads in Neovim via compat layer; new code goes in Lua (`custom/after/*.lua`).
- Do not edit `nvim/lua/yadr/*` (core). All overrides in `custom/`.

## `.gitconfig.user` preserved

`git/gitconfig` does:

```ini
[include]
  path = ~/.gitconfig.user
```

`yadr install` and `yadr update` never write to `~/.gitconfig.user`. If missing, it is created empty with a comment. Identity, signing and `user.email` live there.
