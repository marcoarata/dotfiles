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
- **Packs:** ship their own partial `mise.toml`, aliases and extra `nvim` config. Enabled with `yadr pack add <name>`.
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
- CI/SSH without mise = shell still loads; `yadr doctor` warns, does not fail.

## Why mise (experimental)

RVM/Rake solved 2012: getting a Ruby to run the installer. That problem no longer exists.

mise is evaluated as a replacement because:

1. Single binary (Rust) for node/python/ruby/go/rust/java.
2. Declarative per-repo `mise.toml` + `mise use node@lts`.
3. Compatible with `asdf` `.tool-versions`.
4. No heavy RVM shims, no `gem install rake` in bootstrap.

It is **experimental/opt-in**: bootstrap never requires mise. `yadr doctor` marks it `optional`. If mise breaks or changes format, Core keeps working. The contract is: *YADR installs without Ruby; Ruby/Node/Python are packs*.

## YADR Zsh Core — audited Prezto subset (frozen v0.1)

Prezto is out as a framework. YADR natively reproduces only what it uses:

| Prezto module | YADR 2027 | Location |
|---|---|---|
| `editor` (vi mode) | `bindkey -v`, `KEYTIMEOUT=1` | `shell/keybindings.zsh` |
| `history` | 100k history + `SHARE_HISTORY` + XDG | `shell/zshrc` |
| `completion` | `compinit` + fuzzy `matcher-list` | `shell/zshrc` |
| `syntax-highlighting` | optional `zsh-syntax-highlighting` with guard | `shell/plugins.zsh` |
| `autosuggestions` | optional `zsh-autosuggestions` with guard | `shell/plugins.zsh` |
| `prompt` (damoekri) | reimplemented, runtime-aware | `shell/damoekri.zsh` + `shell/runtime.zsh` |
| `git`/`utility`/`terminal` | aliases, functions, `LS_COLORS` | `shell/aliases.zsh` |
| `ruby`/`rvm` | removed from core → Ruby Pack | `packs/ruby/` |

Out: everything else from Prezto (themes, `fasd`, `pacman` helpers, etc.).
