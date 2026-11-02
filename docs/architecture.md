# Architecture — YADR 2027

## Layers

```text
YADR 2027
  ├── Core      # shell/zsh, git base, editor mappings, tmux, damoekri
  ├── CLI       # eza/bat/fd/rg/fzf/zoxide/delta/btop + fallbacks
  ├── Editor    # Vim + Neovim shared: leader `,`, LSP, Treesitter
  ├── Runtime   # mise (node/python/ruby/go/rust), version abstraction
  ├── Packs     # optional: node-typescript, ruby-rails, python, rust...
  └── Platform  # common/ macos/ linux/ wsl/ — package manager abstraction
```

- **Core:** minimal SSH-safe guarantee. Works without Nerd Fonts, Rust tools or
  a GUI.
- **CLI:** UX improvement, never a hard dependency:

  ```zsh
  command -v eza >/dev/null && alias ls='eza' || alias ls='ls --color=auto'
  ```

- **Editor:** one `mappings.md` for Vim and Neovim. lazy.nvim keeps a pinned
  subset: LSP, Treesitter, Git, text objects, search and project navigation.
- **Packs:** `packs/<name>/` contains optional per-project layers installed as
  a normal profile (`yadr install typescript`). Core never depends on a pack.
- **Platform:** YADR declares what it needs (`git zsh fzf rg fd`); each platform
  decides how (`brew`, `apt`, `pacman`, MacPorts).

## Runtime

`runtime/mise.toml` holds the global pins (`node = "24"`, `python = "3.14"`).
The shell assumes no other version manager and activates mise only when it is
present:

```zsh
command -v mise >/dev/null && eval "$(mise activate zsh)"
```

Users normally go through `yadr runtime current|list|use|doctor`. Per-project
versions belong in the project's `mise.toml`; user-wide extras belong in
`~/.config/mise/conf.d/*.toml`, which mise merges over the managed file. The
prompt only shows a runtime when its active version comes from a project config.
Without mise the shell still loads; `yadr doctor` warns.

## State and backups

`install`, `update`, `backup` and `uninstall` share one state directory but not
one pointer:

```text
$XDG_STATE_HOME/yadr/
  installed-ref          # last bootstrap/update revision (0600)
  last-install-backup    # first install only; uninstall restores from here
  last-update-backup     # diagnostic snapshot; uninstall never reads it
  last-backup            # manual backup / compatibility fallback
  backups/
    <timestamp>.<suffix>/ # install-time, manual and legacy backups
    update-<timestamp>.<suffix>/
    migrate-<timestamp>.<suffix>/
```

The install pointer is first-install-wins. Reinstalls and updates preserve it.
A checkout that already has managed symlinks but no install pointer is treated
as legacy and does not become a fake install backup. `uninstall --purge` refuses
to run without a valid install pointer and leaves `backups/` intact. When it
does run, restored links that point inside `$YADR_HOME` are materialized before
the checkout is deleted; external links stay links.

Foreign executables under `~/.local/bin` (`nvim`, `vim`, `zoxide`, `lazygit`)
are moved to `$XDG_STATE_HOME/yadr-binary-backups/`, a sibling of `yadr/`.
`uninstall --purge` therefore removes the managed binary and `yadr/`, but keeps
the pre-existing executable for inspection. `mise` is installed by its upstream
installer and is outside this ownership rule.

## Zsh core (audited Prezto subset)

YADR reproduces only the Prezto behaviour it uses:

| Prezto module | YADR 2027 | Location |
|---|---|---|
| `editor` (vi mode) | `bindkey -v`, `KEYTIMEOUT=1` | `shell/keybindings.zsh` |
| `history` | 100k history + `SHARE_HISTORY` + XDG | `shell/zshrc` |
| `completion` | zsh `compinit` + fuzzy `matcher-list`; bash/zsh/fish CLI completions | `shell/zshrc` + `bin/lib/completion.sh` |
| `syntax-highlighting` | optional, guarded | `shell/plugins.zsh` |
| `autosuggestions` | optional, guarded | `shell/plugins.zsh` |
| `prompt` (damoekri) | reimplemented, runtime-aware | `shell/damoekri.zsh` + `shell/runtime.zsh` |
| `git`/`utility`/`terminal` | aliases, functions, `LS_COLORS` | `shell/aliases.zsh` |
| `ruby`/`rvm` | moved out of core → Ruby pack | `packs/ruby/` |

## Supply chain

Direct downloads carry a version and SHA-256 in the tree (Nerd Font, mise
installer, zoxide/Neovim tarballs, lazygit fallback). Git fallbacks use a tag
plus an exact commit, and `nvim/lazy-lock.json` pins plugin commits. Package
managers remain rolling by design. The bootstrap installs from the release tag
and the release publishes `SHA256SUMS`. See `docs/supply-chain.md` for the
inventory, exceptions and bump procedure.

`bootstrap` and `yadr update` write `installed-ref`; `yadr doctor` compares it
with the live checkout. It is local self-reported state, not an attestation.
`platform/linux.sh` keeps privilege escalation in one `priv()` helper.

## Conventions

- `managed_pairs` in `bin/yadr` is the single symlink map consumed by `diff`,
  `backup` and `uninstall`.
- `bin/lib/paths.sh` is the single source of truth for destinations
  (ADR-005). A test rejects hardcoded XDG paths elsewhere.
- `log`/`warn`/`have` are redefined in each `platform/*.sh` because those files
  are standalone entrypoints. `platform/common.sh` holds only shared helpers.
- `shellcheck -S warning` runs on every shipped shell file in CI.

## Decisions

ADR-005 (path policy) and ADR-006 (scope) are full records:
[adr-005-path-policy.md](adr-005-path-policy.md) ·
[adr-006-scope.md](adr-006-scope.md).

| # | Decision | Why | Consequence |
|---|---|---|---|
| 001 | Own `bin/yadr` instead of chezmoi/stow/dotbot | Needs install/diff/backup/doctor, classic-YADR coexistence and hooks without a new dependency | Framework only if it covers the same contract |
| 002 | `mise` as runtime backend | One backend for node/python/ruby/rust; editor and prompt never call managers directly | Optional; Core installs without Ruby or mise |
| 003 | `--purge` deletes only what YADR added | Shared data dirs mix YADR data with user data | First-install snapshot; refuses a blind wipe |
| 004 | Runtime failures are fatal; editor failures are advisory | A promised runtime missing is a broken environment; editor state is recoverable | Failed runtime exits non-zero; editor warns with the recovery command |
