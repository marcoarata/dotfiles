# YADR 2027

[![ci](https://github.com/marcoarata/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/marcoarata/dotfiles/actions/workflows/ci.yml)

Yet Another Development Runtime — the classic YADR experience for Zsh, Tmux and
Neovim, rebuilt on a modern stack without complex configuration.

<p align="center">
  <img src="docs/yadr2027.png" width="720" alt="YADR 2027">
</p>

## Overview

YADR 2027 keeps the classic YADR experience contract — Zsh + Vim everywhere + mnemonic aliases + tmux + fluid Git + Damoekri prompt — and replaces the aged implementation (RVM + Rake + Vundle + fasd + ag + hub) with a modern stack with no mandatory Ruby.

Philosophy:

- **Experience > plugins.** Capabilities and muscle memory are preserved, not plugin lists.
- **Vim Everywhere.** Zsh vi-mode, Neovim/Vim, tmux hjkl.
- **Fallbacks, never hard failures.** Every modern alias (`eza`, `bat`, `rg`, `fd`, `zoxide`, `delta`) degrades to the POSIX tool when missing; `delta` is wired as the git pager only when it is installed.
- **Core vs extras.** Portable core for macOS/Linux/WSL/SSH. macOS hacks and iTerm go to extras.
- **Customization without forking.** `before / after` hooks around the defaults.
- **Damoekri is sacred.** The prompt is modernized internally, its personality stays unchanged.

## Installation — YADR 2027

One command installs the core: it detects the platform, installs prerequisites,
clones into `~/.yadr-2027` and runs `yadr install` with an automatic backup.

```bash
# macOS — Homebrew when present; Intel falls back to MacPorts
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"
```

```bash
# Linux / WSL — Debian/Ubuntu (sudo for system packages)
sudo apt update && sudo apt install zsh curl git -y
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"
```

Then enter the shell and verify — the first `yadr doctor` is slow once (it
installs the Neovim plugins); the second is instant and shows the real state:

```bash
exec zsh
yadr doctor
```

Prefer to audit the source first? `git clone https://github.com/marcoarata/dotfiles.git ~/.yadr-2027 && ~/.yadr-2027/bootstrap.sh` — no `curl | sh`. To install one exact release, pass `--ref vX.Y.Z`: the tag is checked out detached and its `VERSION` must match.

**Full guide: [INSTALL-YADR.md](INSTALL-YADR.md)** — per-platform steps, WSL
and macOS Intel (MacPorts) specifics, pinning a release, the profiles you add
after core, and what is no longer done (no RVM, Ruby or Rake). Uninstall and
safety: `yadr uninstall --dry-run`, `docs/troubleshooting.md`.

> ⚠️ **Nerd Font required.** The Damoekri prompt and tmux glyphs render broken
> without one. Install a [Nerd Font](https://www.nerdfonts.com) and select it in
> your terminal emulator before checking the prompt. Without it, everything
> still works (degrades to plain glyphs).

## Support matrix

Tiers say how a platform is verified, not just that it is "supported":

| Tier | Meaning | Platforms |
|---|---|---|
| 1 | CI on every push: unit suites, a real install in an isolated `$HOME`, and `doctor` | macOS arm64; Debian/Ubuntu (server, no GUI) |
| 2 | Dedicated CI lane that does the same install inside the distro | Arch Linux (`archlinux:latest` container) |
| 3 | Covered by tests and, where noted, by hand on real hardware; no dedicated CI lane yet | WSL2 (real Windows 11 guest with WSL 2, `docs/e2e-report.md` §1); Fedora/RHEL (`dnf` branch tested); macOS Intel (MacPorts path) |
| 4 | Documented limits, deliberately not worked around | WSL 1 (Node ≥ 23 cannot exec, microsoft/WSL#8151) |

Windows native is not supported — WSL is the Windows story, and `yadr` never
tries to serve both. The `dnf`/`pacman`/`apt` branches are exercised by the
package-manager tests in `tests/shell.bats`, which fake the whole world so no
real manager is reachable while they run. What each CI job proves is listed in
`docs/releases.md`; the historical evidence is in `docs/e2e-report.md`.

## `yadr` commands

**Environment and profiles**

- `yadr install [profile]` — symlinks, backup and dependencies.
  Profiles: `core|node|javascript|typescript|ruby|python|rust|lazygit|tools|development|macos-extras`
  (no profile = `core`).
- `yadr update` — `git pull` + `mise upgrade` (with backup and confirmation).
  When the pull fails it keeps your checkout as it was, says so and exits
  non-zero (it never prints a success line for an update that did not happen).
- `yadr uninstall [--dry-run] [--purge]` — removes symlinks, restores your
  backup and reverts the login shell.
- `yadr runtime current|list|use|doctor` — runtime abstraction (mise underneath).

**Diagnostics and safety**

- `yadr doctor` — checks the environment with repair hints.
- `yadr diff` — shows what would change, without modifying anything.
- `yadr backup` — copies to the state dir (`~/.local/state/yadr/backups/<timestamp>/`
  by default; see "Where files live" below).
- `yadr benchmark shell|nvim|cd|prompt` — measures startup and cd/prompt cost.

**Customization and extensions**

- `yadr theme [list|use <name>|current]` — Solarized background (light|dark|none, default none).
- `yadr gitsigns [on|off|status]` — Git signs in Neovim (default: off).
- `yadr migrate [--dry-run]` — one-shot import of classic YADR customization
  (`.vimrc.before/.after`, `.vundles.local`…); safe to re-run.
- `yadr version` — prints the version.
- `yadr completion bash|zsh|fish` — prints that shell's completion script
  (`yadr completion --install` writes all three; `yadr install` does it for you).

> **Global toolchains.** Your custom tool pins live in
> `~/.config/mise/conf.d/*.toml`; mise merges them over the base. Do not edit
> the managed `runtime/mise.toml` (symlinked as `~/.config/mise/config.toml`):
> editing it dirties the checkout and can make `yadr update` refuse to
> fast-forward. `yadr install tools` writes `~/.config/mise/conf.d/yadr-tools.toml`
> for you when it installs `eza`/`bat`/`delta` on Linux/WSL (on macOS they come
> from Homebrew/MacPorts).

> **Where files live (moved `XDG` directories).** YADR writes where the programs
> it configures read: Neovim and `mise` follow the `XDG_*` variables (Neovim via
> exactly `stdpath()`), the zsh rc follows `$ZDOTDIR`, and the completions follow
> each shell's own directory; `~/.gitconfig`, `~/.tmux.conf` and `~/.local/bin`
> stay HOME-based. With the variables unset nothing moves. Full policy and the
> per-file table: `docs/cli-contract.md`, `docs/adr-005-path-policy.md`.

## Scope

YADR 2027 is a **personal** Zsh + Tmux + Neovim environment — installable by third
parties on macOS (Intel included), Linux (Debian/Ubuntu), WSL and headless SSH. Its
lifecycle is `install` → use → `update` → `uninstall` / `backup` / `doctor`.

It is deliberately **not**: a general dotfile framework, a secrets manager, a package
or runtime manager (those belong to your package manager and to `mise`, which stays
optional), a Windows-native setup (WSL only), or a way to move state between machines.
A subsystem is kept only if it prevents a real problem or a test fails without it —
see [ADR-006](docs/adr-006-scope.md) for the full scope and non-goals.

## Classic YADR → 2027

| Classic | 2027 | Note |
|---|---|---|
| RVM + Ruby + Rake | `bootstrap.sh` + `yadr` (bash/zsh) + optional mise | Ruby is no longer an install dependency |
| `rake install` | `yadr install` | idempotent, with prior backup and `yadr diff` as dry-run |
| `rake update` | `yadr update` | same contract |
| Vundle + 90 plugins | lazy.nvim, curated subset + LSP + Treesitter | see `docs/mappings.md` |
| fasd / `z` | zoxide, `z` command preserved | fallback to `cd` |
| ag | ripgrep (`rg`), `,gg/,gd/` mappings preserved | |
| `ls/cat/find/grep/diff` | eza/bat/fd/rg/delta with fallback | `delta` wired as git pager only when present; originals always available via `command` |
| hub / ghi | `gh` | |
| Exuberant ctags | Universal ctags and/or LSP | `,f` preserved |
| Powerline fonts | Nerd Fonts | verify Damoekri/tmux glyphs |
| Prezto | YADR Zsh Core (audited subset) | no mandatory heavy framework |
| Vim | Vim + Neovim (shared Editor Layer) | shared mappings |
| tmux + Solarized + iTerm | tmux + Solarized/Damoekri + terminal abstraction | iTerm to `platform/macos/` |
| `~/.vimrc.before/.after` | `custom/before/`, `custom/after/` hooks around the defaults | never need to fork; import classic files with `yadr migrate` |
| `~/.gitconfig.user` | `~/.gitconfig.user` (unchanged) | included from the managed `git/gitconfig`, so your identity never lands in the repo |

Full details: `docs/mappings.md`, `docs/migration.md`.

## Repo layout

```text
.
├── bootstrap.sh        # portable entrypoint
├── bin/yadr + bin/lib/ # CLI dispatcher + modules (paths/install/recover/doctor/runtime/benchmark/completion; see docs/cli-contract.md)
├── shell/             # zshrc, aliases, functions, completion, damoekri prompt
├── git/               # base gitconfig + YADR aliases
├── nvim/ / vim/      # shared Editor Layer
├── tmux/              # Vim-key tmux.conf
├── runtime/           # Runtime Layer: mise.toml, node/python/ruby/rust
├── packs/             # per-project reference bases (typescript, python, ruby, rust, javascript)
├── platform/          # macos/ linux/ wsl/ tools/ common/
├── custom/            # optional before/ after/ hooks (user-owned; never touched by update)
├── docs/              # architecture + ADRs, cli-contract, mappings, migration,
│                       troubleshooting, releases, e2e-report, evaluation
└── tests/             # smoke.sh, shell.bats, fault.bats, coverage.sh, fixtures/
```

## Packs

`packs/<name>/` holds per-project reference material — a short README plus a
copyable base (`tsconfig.base.json`, a `mise` fragment, a `package.json`) — for
optional layers beyond core. Installing the layer is a normal profile:

```bash
yadr install typescript   # node + pnpm + LSP servers
yadr install javascript   # alias of `node`
yadr install ruby         # legacy Ruby
```

Core never depends on a pack; the profiles are self-contained, and the `packs/`
files are there to copy into your own project. See `docs/architecture.md`.

## Damoekri

Damoekri is a first-class component, not a swappable theme. Preserved:

- directory + editor mode on the left
- git branch + status on the right
- Solarized look by default

The right side is runtime-aware: outside a project it shows the global node; inside a project it shows **only the runtimes the project itself pins** (a per-project `mise.toml`/`.tool-versions`, or a local version file), never the inherited globals. A project with no pins falls back to the global node. Implemented in `shell/damoekri.zsh`, which consumes `yadr_runtime_context` from `shell/runtime.zsh` and never invokes managers directly. Without a Nerd Font it renders degraded (no broken glyphs).

More: `docs/architecture.md`, `docs/troubleshooting.md`.
