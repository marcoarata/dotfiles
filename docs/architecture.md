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

- **Core:** minimal SSH-safe guarantee. Works without Nerd Fonts, without Rust tools, without GUI.
- **CLI:** UX improvement, never breaks. Mandatory pattern:

  ```zsh
  command -v eza >/dev/null && alias ls='eza' || alias ls='ls --color=auto'
  ```

- **Editor:** single `mappings.md` for Vim and Neovim. Vundle removed → lazy.nvim. 90 plugins → subset: LSP + Treesitter + Git + textobjects + search + project.
- **Packs:** `packs/<name>/` holds reference bases for optional per-project layers; installing one is a normal profile (`yadr install typescript`), and Core never depends on a pack.
- **Platform:** YADR declares *what* it needs (`git zsh fzf rg fd`), each platform decides *how* (`brew` / `apt` / `pacman`).

## Runtime Layer abstraction

```text
runtime/
  └── mise.toml        # global pin: node = "24" (LTS bump policy lives there)
```

The shell assumes no external version managers (`rvm`, `nvm`, `rbenv`). Only:

```zsh
# shell/zshrc (with guard; ~/.local/bin first for upstream mise/zoxide/nvim)
command -v mise >/dev/null && eval "$(mise activate zsh)"
```

- The user never touches mise directly: `yadr runtime current|list|use|doctor`.
- `yadr runtime use node` installs per the pin without rewriting the repo;
  `yadr runtime use node@<version>` does set an explicit global version.
- Per-project versions (`tests/fixtures/typescript-project/mise.toml`), no imposed globals.
- User-global extras go in `~/.config/mise/conf.d/*.toml`: mise merges them
  over the managed base (`runtime/mise.toml`), so the tracked file stays clean
  and `yadr update` keeps fast-forwarding.
- The prompt follows the same rule: `yadr_runtime_context` shows a runtime only
  when its active version comes from a project config (mise source not under
  `~/.config/mise`), not the global one.
- CI/SSH without mise = shell still loads; `yadr doctor` warns, does not fail.

Why `mise` and not `fnm`/`nvm`, and why Core never requires it: the decisions
table below.

## YADR Zsh Core — audited Prezto subset (frozen v0.1)

Prezto is out as a framework. YADR natively reproduces only what it uses:

| Prezto module | YADR 2027 | Location |
|---|---|---|
| `editor` (vi mode) | `bindkey -v`, `KEYTIMEOUT=1` | `shell/keybindings.zsh` |
| `history` | 100k history + `SHARE_HISTORY` + XDG | `shell/zshrc` |
| `completion` | zsh `compinit` + fuzzy `matcher-list`; `yadr` CLI completions for bash/zsh/fish | `shell/zshrc` + `bin/lib/completion.sh` |
| `syntax-highlighting` | optional `zsh-syntax-highlighting` with guard | `shell/plugins.zsh` |
| `autosuggestions` | optional `zsh-autosuggestions` with guard | `shell/plugins.zsh` |
| `prompt` (damoekri) | reimplemented, runtime-aware | `shell/damoekri.zsh` + `shell/runtime.zsh` |
| `git`/`utility`/`terminal` | aliases, functions, `LS_COLORS` | `shell/aliases.zsh` |
| `ruby`/`rvm` | removed from core → Ruby Pack | `packs/ruby/` |

Out: everything else from Prezto (themes, `fasd`, `pacman` helpers, etc.).

## Supply chain & trust

What YADR fetches, and how far it is pinned — so the trade-off is explicit
rather than accidental:

- **Direct downloads: pinned and verified.** Every artifact YADR downloads
  itself has a version and a SHA-256 in the tree: the Nerd Font zip
  (`terminal/fonts/manifest.env`), the mise installer, the zoxide/Neovim
  tarballs and the lazygit fallback. `platform/common.sh` provides the hash
  helpers; a mismatch is a hard failure before `sh` or `tar` runs. Full
  inventory, exceptions and bump procedure: `docs/supply-chain.md`.
- **Git fallbacks: tag + commit.** The macOS zsh plugin fallback clones a
  pinned tag and then verifies `HEAD` against the pinned commit, so a moved
  tag is refused. `nvim/lazy-lock.json` pins plugin commits separately.
- **Package managers are rolling by design.** apt/dnf/pacman/Homebrew/MacPorts
  install vendor builds under their own trust model. The upstream Homebrew
  installer (only when `brew` is absent) is the one documented unpinned script.
- **No `curl | sh` is required.** YADR downloads the pinned mise installer to
  a temporary file, verifies it, and only then runs `sh` on it. The auditable
  path clones the repo and runs `bootstrap.sh` locally (README "Alternative:
  manual and auditable install").
- **Traceability.** `bootstrap` and `yadr update` write
  `$XDG_STATE_HOME/yadr/installed-ref`; `yadr doctor` compares it with the
  live checkout and reports a divergence. It is local state, not a signature.
- **`sudo` only through one helper.** `platform/linux.sh` defines `priv()`
  (root or `sudo`); there is no bare `sudo` scattered through the code.

## Conventions (and deliberate non-DRY)

Three things look like duplication but are intentional:

- **`log`/`warn`/`have` are redefined in each `platform/*.sh`.** Those scripts
  are standalone entrypoints (`bash platform/linux.sh`) and must run without
  `bin/yadr`; `platform/common.sh` holds only what genuinely needs sharing
  (fonts, purge markers, `nvim_version_ok`).
- **`managed_pairs` is defined once, in `bin/yadr`,** and is the single source
  of truth for the symlink map; `diff`, `backup` and `uninstall` consume it.
- **`bin/lib/paths.sh` is the single source of truth for destinations**
  (ADR-005); `managed_pairs`, the installer, `doctor`, the purge inventory and
  the theme consume it, so the CLI and the tools cannot disagree. A test rejects
  hardcoded XDG-derived paths in `bin/`, `platform/` and `bootstrap.sh`.

`shellcheck -S warning` runs over every shipped `bin/`, `platform/` and
`bootstrap.sh` file in CI as the coupling alarm.

## Decisions (ADRs)

ADR-005 (path policy) and ADR-006 (scope) are maintained as full records:
[adr-005-path-policy.md](adr-005-path-policy.md) ·
[adr-006-scope.md](adr-006-scope.md).

The four core decisions were folded here in v0.6.1 (the ADR files were removed;
the rationale is unchanged):

| # | Decision | Why | Consequence / evidence |
|---|---|---|---|
| 001 | Own `bin/yadr` orchestrator, not chezmoi/stow/dotbot | Needs `install/diff/backup/doctor`, classic-YADR coexistence (`parallel/migrate/cancel`), `before/after` hooks and headless SSH; the frameworks cover only part | A framework is adopted only if it covers `diff+backup+doctor+parallel` without a new hard dependency; the CLI stays dependency-free |
| 002 | `mise` as the runtime backend (`fnm` is the Node alternative) | One backend for node/python/ruby/rust behind `yadr runtime current\|list\|use\|doctor`; Damoekri/Zsh/Neovim never call managers directly | Swappable; explicit pinned LTS (no floating `lts`); Ruby/Node/Python are optional profiles, Core installs without Ruby |
| 003 | `--purge` deletes only what YADR added | The five data dirs (nvim/lazy, Mason, mise, zoxide/pip caches, nvim state) mix YADR data with the user's | First-install snapshot of the top-level entries (`snapshot_share_dirs`); `purge_dir_keep_preexisting` deletes only non-snapshot entries; refuses a blind wipe; the snapshot is first-install-wins |
| 004 | Runtime failures are fatal; editor failures are advisory | A promised runtime missing means the environment does not exist; editor state is long-running, network-dependent and recoverable with `:Lazy restore`/`:Mason` | Failed runtime → non-zero and no success banner; editor step warns with the recovery command; `update` never claims a pull that failed; enforced by `tests/fault.bats` |
