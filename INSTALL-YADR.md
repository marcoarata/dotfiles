# INSTALL-YADR.md — YADR 2027 quick install

> Estimated time: 5-10 min. Does not install RVM, Ruby, or Rake.

## 1) macOS

**1. Homebrew (only if missing)**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. Minimal dependencies**

```bash
brew install curl git zsh
```

**3. Install YADR 2027**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"
```

**4. Enter (install already set zsh as the default shell, as classic YADR did)**

```bash
zsh
```

**5. Verify (1st run slow once, 2nd run instant — see section 3)**

```bash
yadr doctor
```

Without `curl | sh` (auditable):

```bash
git clone https://github.com/marcoarata/dotfiles.git ~/.yadr
```

```bash
~/.yadr/bootstrap.sh
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

## 2) Linux — Debian/Ubuntu, server, WSL

**1. Base**

```bash
sudo apt update && sudo apt upgrade -y
```

**2. Minimal dependencies**

```bash
sudo apt install zsh curl git -y
```

**3. Install YADR 2027**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh)"
```

**4. Enter (install already set zsh as the default shell, as classic YADR did)**

```bash
zsh
```

**5. Verify (1st run slow once, 2nd run instant — see section 3)**

```bash
yadr doctor
```

Without `curl | sh`:

```bash
git clone https://github.com/marcoarata/dotfiles.git ~/.yadr
```

```bash
~/.yadr/bootstrap.sh
```

```bash
zsh
```

```bash
yadr doctor
```

## 3) Verify (run doctor TWICE)

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

## 4) Profiles, in order (after core)

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
yadr install typescript  # TS + LSP servers via Mason (or: yadr pack add typescript)
```

```bash
yadr install ruby        # legacy Ruby pack (optional)
```

```bash
yadr install rust
```

```bash
yadr pack list           # list available packs
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
