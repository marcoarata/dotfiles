# Migration — classic YADR → 2027

YADR 2027 does not install RVM, Ruby or Rake and never needs them. The install
steps live in [README.md](../README.md#installation--yadr-2027).

## What changed

| Classic step | Status in 2027 | Reason |
|---|---|---|
| `gnupg2` install | Removed | Only existed to import the RVM key |
| `rvm.io` key + `get.rvm.io \| bash` | Removed | RVM is out of core |
| `rvm install/use ruby-3.1.0` | Removed from bootstrap | Ruby is the optional `yadr install ruby`; Node LTS is the reference runtime |
| `gem install rake` | Removed | `bootstrap.sh → bin/yadr install` is the engine |
| `skwp/dotfiles install.sh → rake install` | Replaced by `bootstrap.sh → bin/yadr install` | Native installer: idempotent, backup/diff/doctor, multiplatform |
| manual `promptinit / prompt damoekri` | Automatic | `shell/zshrc` sources `shell/damoekri.zsh`; works without a runtime |
| manual `source ~/.zshrc` | `exec zsh` + `yadr doctor` | Doctor checks the environment with repair hints |

Backups land in a unique directory under `~/.local/state/yadr/backups/` (no more
`*.backup2/final2`). `mise` is installed only when a profile needs a runtime
(`yadr install node`); minimal SSH works without it (ADR-002).

## Parallel vs migrate

- **Parallel (recommended):** install 2027 into a `YADR_HOME` distinct from
  classic `~/.yadr` (with `Rakefile`). `bin/yadr install` detects it and offers
  `parallel/migrate/cancel` (default `parallel`). Test with an isolated `HOME`
  before changing the login shell.
- **Migrate:** `yadr migrate [--dry-run]` backs up and copies the classic
  customization; `.gitconfig.user`, `.tmux.conf.user` and `.secrets` stay in
  place (core includes them by reference, never overwrites).

  | Classic | 2027 |
  |---|---|
  | `~/.vimrc.before` | `~/.config/yadr/migrated/vimrc.before` (+ `nvim/lua/custom/before.lua` when `custom/` exists) |
  | `~/.vimrc.after` | `~/.config/yadr/migrated/vimrc.after` (+ `nvim/lua/custom/after.lua` when `custom/` exists) |
  | `~/.vundles.local` | `~/.config/yadr/migrated/vundles.local` (plugin list for lazy.nvim) |
  | `~/.gitconfig.user` | preserved as-is, included from `git/gitconfig` — never overwritten |
  | `~/.tmux.conf.user` | sourced as-is (already included, kept) |
  | `~/.secrets` | `~/.config/yadr/migrated/secrets` (chmod 700) |

## `.vimrc.before` / `.after` → nvim

- `before` loads before the defaults (options that must win over core).
- `after` loads after (overrides/mappings that win over everything).
- Classic Vimscript still loads in Neovim via the compat layer; new code goes in
  Lua (`custom/after/*.lua`).
- Do not edit `nvim/lua/yadr/*` (core); put overrides in `custom/`.

## `.gitconfig.user` preserved

`git/gitconfig` includes it:

```ini
[include]
  path = ~/.gitconfig.user
```

`yadr install` and `yadr update` never write to `~/.gitconfig.user`; if missing,
it is created empty with a comment. Identity and `user.email` live there.
