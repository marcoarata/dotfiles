# INSTALL-YADR.md — YADR 2027 quick install

> Estimated time: 5-10 min. Does not install RVM, Ruby, or Rake.
>
> No GitHub yet: use the **local copy** (section 0).

## 0) Local copy — ephemeral VMs and testing without GitHub (recommended for now)

```bash
# From the host (project at ./dotfiles/):
rsync -a --delete ./dotfiles/ /tmp/marco/opencode/yadr-copy/
# or: tar -C dotfiles -cf - . | ssh vm 'mkdir -p /tmp/yadr && tar -C /tmp/yadr -xf -'

# Inside the machine (or same host with isolated HOME):
YADR_HOME=/tmp/marco/opencode/yadr-copy ./bootstrap.sh --local
# equivalent to: YADR_LOCAL=1 YADR_HOME=<copy> ./bootstrap.sh
zsh
yadr doctor
```

> Golden rule: **single checkout** (`~/yadr` or the `YADR_HOME` you use).
> Hand-made versioned copies (`yadr2027v4.0`, `dotfiles-old`...) plus cross symlinks
> produce ghost states that `doctor` detects and `install` cannot heal:
> use `--purge` plus a fresh copy between test rounds.

With isolated `HOME` (without touching your real `~`):

```bash
mkdir -p /tmp/marco/opencode/fake-home
HOME=/tmp/marco/opencode/fake-home YADR_HOME=/tmp/marco/opencode/yadr-copy \
  /tmp/marco/opencode/yadr-copy/bootstrap.sh --local --yes
HOME=/tmp/marco/opencode/fake-home zsh
```

Cleanup (temp resources under `/tmp/marco/opencode`, nothing in your `~`):

```bash
rm -rf /tmp/marco/opencode/yadr-copy /tmp/marco/opencode/fake-home
```

## 1) macOS (once a GitHub repo exists)

```bash
# 1. Homebrew (only if missing)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Minimal dependencies
brew install curl git zsh

# 3. Install YADR 2027
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"

# 4. Enter (install already set zsh as the default shell, as classic YADR did)
zsh
yadr doctor
```

Without `curl | sh` (auditable):

```bash
git clone https://github.com/marcoarata/dotfiles.git ~/.yadr
~/.yadr/bootstrap.sh
zsh
yadr doctor
```

> macOS Intel (Tier 3 since Homebrew 7.0.0, Sep 2026): Homebrew no longer
> builds bottles for Intel and its installer is Apple Silicon only.
> YADR detects Intel (`uname -m != arm64`) and installs via MacPorts first
> (`platform/macos.sh` → `PORT_PACKAGES`, `delta`→`git-delta`), with XDG
> clones for zsh plugins as no-sudo fallback.
> Install MacPorts from https://www.macports.org first, then run the same
> bootstrap. Field report: `docs/homebrew-intel.md`.

## 2) Linux — Debian/Ubuntu, server, WSL (once a GitHub repo exists)

```bash
# 1. Base
sudo apt update && sudo apt upgrade -y

# 2. Minimal dependencies
sudo apt install zsh curl git -y

# 3. Install YADR 2027
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"

# 4. Enter (install already set zsh as the default shell, as classic YADR did)
zsh
yadr doctor
```

Without `curl | sh`:

```bash
git clone https://github.com/marcoarata/dotfiles.git ~/.yadr
~/.yadr/bootstrap.sh
zsh
yadr doctor
```

## 3) Verify (run doctor TWICE)

```bash
exec zsh
yadr doctor   # 1st run: slow ONCE (first nvim start installs lazy plugins)
yadr doctor   # 2nd run: instant, shows the real state (✓ / ⚠ / ✗ + hints)
yadr diff     # what would change, without modifying anything
```

> `doctor` does not configure anything itself. If the first run takes a
> while, that is lazy.nvim installing plugins in the background (one time
> only); the second run reports without background work.

## 4) Profiles, in order (after core)

`bootstrap` / `yadr install` already installed **core** (`install` with no
profile means `core`). Then, only what you need:

```bash
yadr install node        # Node LTS + npm/pnpm via mise (fast when core links are ready)
yadr install python      # Python via mise (fast path, same as above)
yadr install lazygit     # direct + fastest (single script, no prompts)
yadr install typescript  # TS + LSP servers via Mason (or: yadr pack add typescript)
yadr install ruby        # legacy Ruby pack (optional)
yadr install rust
yadr pack list           # list available packs
yadr theme list          # Solarized background: light|dark|none (default none)
yadr migrate --dry-run   # import plan from classic YADR, without touching anything
yadr install macos-extras  # macOS only: optional defaults, outside core
yadr update              # update everything
```

Why `lazygit` feels instant and the others ask questions: language profiles
re-run the safe flow (platform deps + backup + symlinks + login shell with
`yes/no` confirmations, `sudo` password for system packages) unless core
links are already up to date — then they take the fast path with no prompts
(same as `lazygit`). Nothing destructive runs without confirmation; use
`--yes` (`yadr install node --yes`) to skip confirmations in scripts.

## 5) What is NO LONGER done

- `gnupg2`, `rvm.io/mpapis.asc` key, `get.rvm.io`, `rvm install/use`, `gem install rake`: removed.
- Legacy `skwp/dotfiles install.sh` + `rake install`: replaced by `bootstrap.sh -> bin/yadr install`.
- Manual `promptinit / prompt damoekri / source ~/.zshrc`: automatic via `shell/zshrc` + `shell/damoekri.zsh`.
- Damoekri shows `Node x.y` (or Ruby/Python per project) only when the runtime exists; without a runtime it works the same.

## 6) Safety

- `yadr diff` before installing when coming from another dotfiles setup.
- Automatic backup to `~/.local/state/yadr/backups/<timestamp>/`.
- On classic YADR detection (`~/.yadr` + `Rakefile`), prompts: `migrate / parallel / cancel` (default: `parallel`).
- Nothing destructive without confirmation.

## 7) Uninstall

```bash
yadr uninstall --dry-run   # preview without touching anything
yadr uninstall             # removes symlinks, restores your backup, reverts login shell (single confirmation)
yadr uninstall --purge     # also deletes clone, backups, Neovim plugins and toolchains (after second confirmation)
```

By default it keeps your data (backups, clone, plugins, toolchains); system
packages are listed for manual purge. Without a TTY nothing destructive runs.

More details: `README.md`, `docs/migration.md`, `docs/troubleshooting.md`.
