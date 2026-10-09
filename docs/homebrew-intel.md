# Report: installing YADR 2027 on macOS Ventura (Intel x86_64)

**Date:** October 7, 2026
**Machine:** macOS 13.7.8 Ventura, Intel x86_64
**Repo:** `https://github.com/marcoarata/dotfiles` (local checkout at `~/.yadr-2027`)
**Final result:** `yadr doctor → 0 errors, 0 warnings`. Working setup.

---

## 1. Context

With the arrival of **Homebrew 7.0.0 (Sep 13, 2026)**, the macOS `installer package` became **Apple Silicon only** and Homebrew stopped building *bottles* for Intel. On this machine (Ventura + Intel) Homebrew landed on **Tier 3**: it runs, but with no CI, no new binaries and strong warnings; `brew doctor` itself recommends migrating to **MacPorts**. Dependencies were therefore installed from `macports.org`, and that is where the problems below showed up.

Prior Homebrew state on the machine:

- `brew --prefix` → `/usr/local`, but empty `brew list` and missing `/usr/local/Cellar`, `/Frameworks`, `/include`, `/lib`, `/opt`, `/sbin`, `/share`.
- `brew doctor` → Tier 3 warnings + outdated CLT + MacPorts suggestion.
- Via MacPorts, present: `tmux`, `neovim 0.12.4`, `ripgrep`, `fd`, `zoxide`, `lazygit`, `mise` (in `~/.local/bin`), `node 24`, `python 3.14`. Missing: `zsh-syntax-highlighting`, `zsh-autosuggestions`, `fzf`, `eza`, `bat`, `git-delta`, `gh`.

---

## 2. Problems found

### P1. `zsh-syntax-highlighting` and `zsh-autosuggestions` never loaded
- Not installed in MacPorts (`port installed` did not list them).
- Even if installed, **`shell/plugins.zsh` would never have found them**: the lookup covered explicit `$YADR_ZSH_*` → `~/.local/share/yadr-plugins/` → `/usr/share/` (apt) → `$(brew --prefix)/share/`, but **never `/opt/local/share/`** (MacPorts). The shell started degraded **silently** (`HL_MISSING`, `SG_MISSING`, no `ZSH_HIGHLIGHT_HIGHLIGHTERS`, `Ctrl-E` unbound).
- `yadr doctor` did not check these plugins, so it reported green anyway.

### P2. Fragile `~/.zprofile` on Intel
- Unconditional `eval "$(/usr/local/bin/brew shellenv)"`: fails/noises when brew is broken or missing, and did not account for MacPorts-vs-brew order or `~/.local/bin` / `mise/shims` in login shells.

### P3. MacPorts `fzf` without integration
- `shell/zshrc` only looked for key-bindings in `/usr/share/fzf/`, `~/.fzf.zsh` and `$XDG_CONFIG_HOME/fzf/`. The MacPorts paths (`/opt/local/share/fzf/...`) and the modern `fzf --zsh` were not covered.

### P4. `platform/macos.sh` only knew Homebrew
- `ensure_brew` + direct `brew install`, with minimal fallback. On Intel Tier 3 `brew install` fails or builds from source; there was no MacPorts path, and the package name `delta` (brew) vs **`git-delta`** (MacPorts) broke 1:1 installs.

### P5. `vim` opened genuine Vim, not Neovim
- `vim` → `/usr/bin/vim` (genuine Vim 9.0), while `nvim` → `/opt/local/bin/nvim` 0.12.4 with the full config/lazy. `nvim .zshrc` looked complete; `vim .zshrc`, bare.
- The existing `ensure_vim` only lives in `platform/linux.sh` and is gated on the `provides-nvim-upstream` marker, so on macOS it **never** creates the `~/.local/bin/vim` shim.

### P6. Bug in `yadr benchmark shell` (macOS/Bash 3.2)
- `now_ns()` used `date +%s%N`; on BSD `date` that prints a literal `...N` (e.g. `1791386783N`), the check only filtered `%`, and arithmetic blew up: `value too great for base`. The benchmark would not run.

### P7. Nerd Font installed but iTerm2 profiles misaligned
- The manifest font (`JetBrainsMono Nerd Font 3.5.1`, `terminal/fonts/manifest.env`) was correctly installed (`fc-list` lists it, doctor ✓). But the `Default` profile used Monaco/Monaco with `Use Non-ASCII = 0` (broken glyphs) and `MasterDev` mixed `Monaco 15` + `JetBrainsMonoNFM-Regular 12` (different sizes → misaligned powerline). The goal was to **keep using Monaco** as the base font.

---

## 3. Fixes applied

> Everything verified by execution, not just reading: `yadr doctor/diff/benchmark`, `zsh -i -c` with function checks, `vim --version`, `bash -n`.

### R1. Zsh plugins (immediate fix + robustness)
- Cloned without sudo (path already supported by lookup #2):
  - `~/.local/share/yadr-plugins/zsh-syntax-highlighting`
  - `~/.local/share/yadr-plugins/zsh-autosuggestions`
  - Result: `HL_OK`, `SG_OK`, `bindkey '^E' = autosuggest-accept`.
- `shell/plugins.zsh`: added `/opt/local/share/${subdir}/${file}` to the lookup (between apt and brew) + Intel/Tier 3 comment with the XDG-clone alternative.

### R2. Hardened `~/.zprofile` (user file, not repo)
- Guarded `brew shellenv` (`[[ -x /usr/local/bin/brew ]]`, fallback to `command -v brew`).
- Kept the MacPorts installer block; added `~/.local/bin` and `mise/shims` to PATH without duplicates.

### R3. `shell/zshrc`: fzf via MacPorts
- Added `/opt/local/share/fzf/shell/key-bindings.zsh`, `/opt/local/share/fzf/shell/completion.zsh`, `/opt/local/share/fzf/key-bindings.zsh`, `/opt/local/share/fzf/completion.zsh` and `eval "$(fzf --zsh)"`, all guarded.

### R4. `platform/macos.sh`: MacPorts fallback
- New `PORT_PACKAGES` (maps `delta` → `git-delta`).
- New `install_via_macports()` (with no-sudo XDG clones as backup).
- `main()`: on Intel (`uname -m != arm64`) tries MacPorts first; when brew is missing it continues with MacPorts/XDG only instead of aborting.
- New `ensure_vim_macos()` (see R5), called from both `main()` branches.

### R5. `vim` → Neovim
- Created `~/.local/bin/vim → /opt/local/bin/nvim` + `~/.local/state/yadr/provides-vim` marker (so `yadr uninstall` cleans it). `/usr/bin/vim` untouched; the shim wins via PATH.
- Doctor went from `vim genuine` to `✓ vim → Neovim (NVIM v0.12.4)`.

### R6. `bin/yadr`
- `now_ns()`: `case` match against `''|*%*|*N*|*[^0-9]*` with `python3 time.time_ns()` fallback — shell benchmark runs again.
- `doctor`: new **advisory** checks (warn, no fail) for `zsh-syntax-highlighting` and `zsh-autosuggestions` in XDG, `/opt/local`, `/usr/share` and brew.

### R7. iTerm2 (user-side config, verified)
- `MasterDev` kept at `Monaco 15` + `JetBrainsMonoNFM-Regular 15` with `Use Non-ASCII = 1` (Mono variant, not Propo). Test line `    ± ✓ →` renders fully and the nvim capture shows a continuous powerline statusline. `Default` stays on Monaco without fallback (only matters when that profile is used).

### Packages installed by the user (item 1, via `sudo port install`)
`zsh-syntax-highlighting`, `zsh-autosuggestions`, `fzf 0.74.4`, `eza`, `bat 0.26.1`, `git-delta 0.20.1`, `gh 2.102.0` — all active and on PATH; `ls=eza`, `cat=bat` confirmed.

---

## 4. Final verified state

- `yadr doctor`: **0 errors, 0 warnings** (before: 0 errors, 1 Nerd Font warning).
- `yadr diff`: 0 with changes; symlinks intact (`.zshrc`, `.gitconfig`, `.tmux.conf`, `nvim`, `mise.toml`, `yadr`).
- `zsh -i -c`: `HL_OK`, `SG_OK`, `^E` bound.
- `zsh -l -i -c`: `tmux/rg/fd/zoxide/mise/nvim` on PATH; `vim --version` → `NVIM v0.12.4`.
- `benchmark prompt`: 0 ms/render outside and inside git. `benchmark shell`: ~700 ms (over the 500 ms threshold; measured split: base 0.03 s, `mise activate` 0.18 s, plugins 0.06 s, cold `compinit` 2.1 s — Intel hardware + `mise` cost, not a YADR regression; kept informational).
- `nvim --headless +qa`: clean, plugins on lockfile.

---

## 5. Pending / upstream suggestions

1. **Documented Intel support:** `INSTALL-YADR.md`/`README` assume working brew on macOS. Suggestion: detect Intel/Tier 3 and point to MacPorts (or the no-sudo XDG clone) like the patched `macos.sh` now does.
2. **MacPorts name mapping:** `delta` → `git-delta` (and review `fd`, `mise`, etc. against Intel bottle availability).
3. **Doctor:** the zsh plugin checks added here could go upstream as-is (advisory, portable).
4. **`~/.gitconfig.user`:** not created on this machine (personal data, optional); git uses the `YADR User / user@example.com` placeholder until the user defines it.
5. **iTerm2:** document the Monaco + Nerd Mono pattern with Non-ASCII enabled, same point size, Mono variant (not Propo), for anyone keeping their base font.

---

*Report generated on Oct 7, 2026 from on-machine diagnosis and execution-based verification.*
