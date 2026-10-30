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

> Estimated time: 5-10 min. Does not install RVM, Ruby, or Rake.

### 1) macOS

**1. Homebrew (only if missing)**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. Minimal dependencies**

```bash
brew install curl git zsh
```

**3. Install YADR 2027**

The install is pinned to the release tag, not to the moving `main` branch:

```bash
curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/v0.8.6/bootstrap.sh | bash -s -- --ref v0.8.6
```

For checksum verification before running the script, see “Pin a release” below.

**4. Enter (install already set zsh as the default shell, as classic YADR did)**

```bash
zsh
```

**5. Verify (1st run slow once, 2nd run instant — see section 4)**

```bash
yadr doctor
```

**Alternative: manual and auditable install (no `curl | sh`).** This replaces
steps 1-5 above; it is not a step after them.

```bash
git clone --branch v0.8.6 https://github.com/marcoarata/dotfiles.git ~/.yadr-2027
```

```bash
~/.yadr-2027/bootstrap.sh --local --ref v0.8.6
```

```bash
zsh
```

```bash
yadr doctor
```

> macOS Intel (Tier 3 since Homebrew 7.0.0, Sep 2026): Homebrew no longer
> builds bottles for Intel and its installer is Apple Silicon only.
> YADR detects Intel (`uname -m != arm64`) and installs via MacPorts first
> (`platform/macos.sh` → `PORT_PACKAGES`, `delta`→`git-delta`), with XDG
> clones for zsh plugins as no-sudo fallback.
> Install MacPorts from https://www.macports.org first, then run the same
> bootstrap. Field report: `docs/homebrew-intel.md`.

### 2) Linux — Debian/Ubuntu, server, WSL

**1. Base**

```bash
sudo apt update
```

**2. Minimal dependencies**

```bash
sudo apt install zsh curl git -y
```

**3. Install YADR 2027**

The install is pinned to the release tag, not to the moving `main` branch:

```bash
curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/v0.8.6/bootstrap.sh | bash -s -- --ref v0.8.6
```

For checksum verification before running the script, see “Pin a release” below.

**4. Enter (install already set zsh as the default shell, as classic YADR did)**

```bash
zsh
```

**5. Verify (1st run slow once, 2nd run instant — see section 4)**

```bash
yadr doctor
```

**Alternative: manual and auditable install (no `curl | sh`).** This replaces
steps 1-5 above; it is not a step after them.

```bash
git clone --branch v0.8.6 https://github.com/marcoarata/dotfiles.git ~/.yadr-2027
```

```bash
~/.yadr-2027/bootstrap.sh --local --ref v0.8.6
```

```bash
zsh
```

```bash
yadr doctor
```

### 3) Pin a release (recommended, especially for servers)

`main` is development; installs should name the release they want. The commands
above use `v0.8.6`. To verify the bootstrap before running it:

```bash
V=v0.8.6
curl -fsSLO "https://raw.githubusercontent.com/marcoarata/dotfiles/${V}/bootstrap.sh"
curl -fsSLO "https://github.com/marcoarata/dotfiles/releases/download/${V}/SHA256SUMS"
sha256sum -c SHA256SUMS
bash bootstrap.sh --ref "$V"
```

On macOS use `shasum -a 256 -c SHA256SUMS` instead of `sha256sum -c`.
`SHA256SUMS` is an integrity check published with the release, not a signature:
it only helps when the checksum file itself came from a trusted channel.

The tag is checked out detached and the checkout's `VERSION` file must match
the tag; a mislabelled tag stops the bootstrap. `--local --ref vX.Y.Z` applies
the same check to a checkout you copied by hand. `bootstrap` and `yadr update`
record the installed revision in `$XDG_STATE_HOME/yadr/installed-ref`, and
`yadr doctor` shows it. Direct downloads are versioned and SHA-256 verified;
the full inventory and its exceptions are in `docs/supply-chain.md`. Release
process: `docs/releases.md`.

### 4) Verify (run doctor TWICE)

```bash
exec zsh
```

**1st run: slow ONCE (first nvim start installs lazy plugins)**

```bash
yadr doctor
```

**2nd run: instant, shows the real state (✓ / ⚠ / ✗ + hints)**

```bash
yadr doctor
```

```bash
yadr diff     # what would change, without modifying anything
```

> `doctor` does not configure anything itself. If the first run takes a
> while, that is lazy.nvim installing plugins in the background (one time
> only); the second run reports without background work.

### 5) Profiles, in order (after core)

`bootstrap` / `yadr install` already installed **core** (`install` with no
profile means `core`). Then, only what you need:

```bash
yadr install node        # Node LTS + npm/pnpm via mise (fast when core links are ready)
```

```bash
yadr install python      # Python via mise (fast path, same as above)
```

```bash
yadr install lazygit     # direct + fastest (single script, no prompts)
```

```bash
yadr install tools       # eza/bat/delta: full modern shell on Linux/WSL (mise conf.d)
```

```bash
yadr install typescript  # TS + LSP servers via Mason
```

```bash
yadr install ruby        # legacy Ruby pack (optional)
```

```bash
yadr install rust
```

```bash
yadr theme list          # Solarized background: light|dark|none (default none)
```

```bash
yadr migrate --dry-run   # import plan from classic YADR, without touching anything
```

```bash
yadr install macos-extras  # macOS only: optional defaults, outside core
```

```bash
yadr update              # update everything
```

Why `lazygit` feels instant and the others ask questions: language profiles
re-run the safe flow (platform deps + backup + symlinks + login shell with
`yes/no` confirmations, `sudo` password for system packages) unless core
links are already up to date — then they take the fast path with no prompts
(same as `lazygit`). Nothing destructive runs without confirmation; use
`--yes` (`yadr install node --yes`) to skip confirmations in scripts.

### 6) What is NO LONGER done

- `gnupg2`, `rvm.io/mpapis.asc` key, `get.rvm.io`, `rvm install/use`, `gem install rake`: removed.
- Legacy `skwp/dotfiles install.sh` + `rake install`: replaced by `bootstrap.sh -> bin/yadr install`.
- Manual `promptinit / prompt damoekri / source ~/.zshrc`: automatic via `shell/zshrc` + `shell/damoekri.zsh`.
- Damoekri shows `Node x.y` (or Ruby/Python per project) only when the runtime exists; without a runtime it works the same.

### 7) Safety

- `yadr diff` before installing when coming from another dotfiles setup.
- Automatic backup to `~/.local/state/yadr/backups/<timestamp>/`.
- On classic YADR detection (`~/.yadr` + `Rakefile`), prompts: `migrate / parallel / cancel` (default: `parallel`).
- Nothing destructive without confirmation.

### 8) Uninstall

```bash
yadr uninstall --dry-run   # preview without touching anything
yadr uninstall             # removes symlinks, restores your backup, reverts login shell (single confirmation)
yadr uninstall --purge     # also deletes clone, backups, Neovim plugins and toolchains (after second confirmation)
```

By default it keeps your data (backups, clone, plugins, toolchains); system
packages are listed for manual purge. Without a TTY nothing destructive runs.

More details: `README.md`, `docs/migration.md`, `docs/troubleshooting.md`.

## Basic `yadr` commands

**Environment and profiles**

- `yadr install [profile]` — symlinks, backup and dependencies. It prints the
  diff and the planned side effects first, and only touches the system after you
  confirm; `--dry-run` (or `yadr plan`) stops there and writes nothing.
  Profiles: `core|node|javascript|typescript|ruby|python|rust|lazygit|tools|development|macos-extras`
  (no profile = `core`).
- `yadr plan [profile]` — alias for `install --dry-run`: prints the diff and the
  planned side effects, writes nothing.
- `yadr update` — `git pull` + `mise upgrade` (with backup and confirmation).
  The runtime upgrade asks separately and defaults to yes on Enter; EOF or
  non-interactive input skips it, and `--yes` accepts both prompts. The two
  phases are reported separately: when the pull fails it keeps your checkout as
  it was, skips the runtime upgrade, says so and exits non-zero (it never prints
  a success line for an update that did not happen).
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

## Scope

YADR 2027 is a **personal** Zsh + Tmux + Neovim environment — installable by third
parties on macOS (Intel included), Linux (Debian/Ubuntu), WSL and headless SSH. Its
lifecycle is `install` → use → `update` → `uninstall` / `backup` / `doctor`.

It is deliberately **not**: a general dotfile framework, a secrets manager, a package
or runtime manager (those belong to your package manager and to `mise`, which stays
optional), a Windows-native setup (WSL only), or a way to move state between machines.
A subsystem is kept only if it prevents a real problem or a test fails without it —
see [ADR-006](docs/adr-006-scope.md) for the full scope and non-goals.

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
│                       troubleshooting, releases, supply-chain, e2e-report, evaluation
└── tests/             # smoke.sh, shell.bats, fault.bats, coverage.sh, fixtures/
```

## Damoekri

Damoekri is a first-class component, not a swappable theme. Preserved:

- directory + editor mode on the left
- git branch + status on the right
- Solarized look by default

The right side is runtime-aware: outside a project it shows the global node; inside a project it shows **only the runtimes the project itself pins** (a per-project `mise.toml`/`.tool-versions`, or a local version file), never the inherited globals. A project with no pins falls back to the global node. Implemented in `shell/damoekri.zsh`, which consumes `yadr_runtime_context` from `shell/runtime.zsh` and never invokes managers directly. Without a Nerd Font it renders degraded (no broken glyphs).

More: `docs/architecture.md`, `docs/troubleshooting.md`.
