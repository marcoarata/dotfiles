# Migration — classic YADR → 2027

YADR 2027 does not install RVM, Ruby or Rake, and it never needs them. This page
maps the classic install to the 2027 one; the install steps themselves live in
[INSTALL-YADR.md](../INSTALL-YADR.md).

## Classic install (reference — do NOT use for 2027)

macOS: `brew install gnupg2` → import the RVM key (`rvm.io/mpapis.asc`) →
`get.rvm.io | bash` → `rvm install ruby-3.1.0` → `gem install rake` → run
`skwp/dotfiles/install.sh` (`rake install`) → hand-edit `~/.zshrc` for Damoekri.

Linux (Debian/Ubuntu, server, WSL): `apt install gnupg2` plus the same RVM/Rake
chain and the same shell edit.

## What changed, line by line

| Classic step | Status in 2027 | Reason |
|---|---|---|
| `gnupg2` install | Removed | Only existed to import the RVM key |
| `rvm.io` key + `get.rvm.io \| bash` | Removed | RVM is out of core (Runtime Layer) |
| `rvm install/use ruby-3.1.0` | Removed from bootstrap | Ruby moves to the optional `yadr install ruby`; the reference runtime is Node LTS via mise |
| `gem install rake` | Removed | `bootstrap.sh → bin/yadr install` (bash) is the engine |
| `skwp/dotfiles install.sh → rake install` | Replaced by `bootstrap.sh → bin/yadr install` | Native installer: idempotent, with `backup`/`diff`/`doctor`, multiplatform |
| manual `promptinit / prompt damoekri` | Automatic | `shell/zshrc` sources `shell/damoekri.zsh`; works without a runtime |
| manual `source ~/.zshrc` | `exec zsh` + `yadr doctor` | `doctor` checks the environment with repair hints |

Backups land in `~/.local/state/yadr/backups/<timestamp>/` (no more
`*.backup2/final2`). `mise` is only installed when a profile needs a runtime
(`yadr install node`); minimal SSH works without it — see
`adr-002-runtime-manager.md`.

## Parallel vs migrate

- **Parallel (recommended, implemented):** install 2027 into a `YADR_HOME`
  distinct from classic `~/.yadr` (with `Rakefile`). `bin/yadr install` detects
  it and offers `parallel/migrate/cancel` (default `parallel`). Test with an
  isolated `HOME` before changing the login shell.
- **Migrate (implemented):** `yadr migrate [--dry-run]` backs up and copies the
  classic customization; `.gitconfig.user`, `.tmux.conf.user` and `.secrets`
  stay in place (core includes them by reference, never overwrites).

  | Classic | 2027 |
  |---|---|
  | `~/.vimrc.before` | `~/.config/yadr/migrated/vimrc.before` (+ `nvim/lua/custom/before.lua` when `custom/` exists) |
  | `~/.vimrc.after` | `~/.config/yadr/migrated/vimrc.after` (+ `nvim/lua/custom/after.lua` when `custom/` exists) |
  | `~/.vundles.local` | `~/.config/yadr/migrated/vundles.local` (plugin list for lazy.nvim) |
  | `~/.gitconfig.user` | preserved as-is, `include` from `git/gitconfig` — **never overwritten** |
  | `~/.tmux.conf.user` | sourced as-is (already included, kept) |
  | `~/.secrets` | `~/.config/yadr/migrated/secrets` (chmod 700); migrate to age/sops |

## `.vimrc.before` / `.after` → nvim

- `before` loads **before** the defaults (options that must win over core).
- `after` loads **after** (overrides/mappings that win over everything).
- Classic Vimscript still loads in Neovim via the compat layer; new code goes in Lua (`custom/after/*.lua`).
- Do not edit `nvim/lua/yadr/*` (core); put overrides in `custom/`.

## `.gitconfig.user` preserved

`git/gitconfig` includes it:

```ini
[include]
  path = ~/.gitconfig.user
```

`yadr install` and `yadr update` never write to `~/.gitconfig.user`; if missing,
it is created empty with a comment. Identity, signing and `user.email` live there.
