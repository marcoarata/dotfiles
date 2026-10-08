# Troubleshooting

## First Neovim start: Lazy panel shows (normal)

On first `nvim` open you will see the **Lazy** manager window installing
the ~27 plugins from the lockfile. This is expected behavior, not an error:
when it finishes, `:q` closes it and your file remains. The second start is
direct. Real problem signals (then it is a bug): persistent `Failed`,
`■ build failed` or `Error detected` lines after retry
(`:Lazy restore`). Note: the panel only appears in `nvim`; classic `vim` opens
the file directly (YADR configures Neovim, not Vim).

## Slow shell (<500ms slow VM / <300ms workstation threshold; see `yadr benchmark shell`)

1. `yadr benchmark shell` (measures the YADR zshrc with isolated HOME, without touching your `~`).
2. Typical culprits: several version managers active at once + `compinit` without dump.
3. Fix:
   - Single version manager: mise only (see `docs/adr-002-runtime-manager.md`).
   - `compinit -C` with daily dump (already the default in `shell/zshrc`).
   - Optional plugins with guard (`shell/plugins.zsh`): without them the shell works degraded.

## mise not activating / broken shims

- `command -v mise || echo missing` → `yadr install node` (installs mise via `platform/`).
- `mise doctor` and `mise ls`. If `runtime/mise.toml` pins a version that is not installed: `yadr runtime use node`.
- Headless SSH: `bin/yadr` and `shell/zshrc` prepend `~/.local/bin` and the mise shims to PATH.
- Do not mix external version managers: use only the Runtime Layer (`yadr runtime`).

## LSP not starting (Neovim)

- Old system binary (e.g. apt 0.6.1 on Ubuntu 22.04): outside YADR zsh, the
  system `nvim` rules. Our config fails fast with the fix (`exec zsh` to use
  upstream `~/.local/bin/nvim`, or `yadr install core`) instead of E5113.
- `vim` resolving into an old nvim (Ubuntu `vim → nvim` link) gets a
  `~/.local/bin/vim` shim to upstream automatically (`provides-vim` marker;
  removed by `yadr uninstall --purge`). Genuine Vim is never touched.
  Check: `yadr doctor` reports what `vim` resolves to.

- `:checkhealth` (lsp section) and `:=vim.lsp.get_clients()`.
- `yadr doctor` checks `node`, `rg`, `fd` and warns if servers are missing.
- Install servers via `:Mason`, or `yadr install typescript` (installs them via Mason headless).
- Floor: Neovim ≥0.11 (`platform/linux.sh` installs upstream into `~/.local/bin` if apt ships 0.9.x).
- Project without `tsconfig.json`/`package.json`: server only starts inside projects with markers (prompt/runtime design). Normal.
- Headless/SSH: `nvim --headless "+checkhealth" +q` — without Nerd Font it must still show no errors.

## Fonts / Neovim statusline

- The statusline is lightline with Solarized, as the classic: Powerline separators + text,
  **zero Nerd icons** (so you never see boxes or hex codes on macOS or Linux).
- `platform/` installs JetBrainsMono Nerd Font (see `terminal/fonts/`); select it
  in your terminal for the prompt and vim Powerline separators.
- Neovim background is transparent (`none`) by default on macOS and
  Linux (terminal shows through); solid Solarized only via the macOS
  install menu (`1 light / 2 dark / 3 none`, default `none`) or
  `YADR_SOLARIZED_BG`. Details: `terminal/solarized/README.md`.

### iTerm2: keep Monaco, fix glyphs (recipe from Intel field report)

- Keep `Monaco 15` as base, add `JetBrainsMonoNFM-Regular 15` (Mono, not
  Propo) as Non-ASCII fallback, same point size, `Use Non-ASCII = 1`.
- Test line must render complete: `   ± ✓ →`.
- See `docs/homebrew-intel.md` R7 for the verified profile.

## macOS Intel / Homebrew Tier 3 (Homebrew 7.0.0, Sep 2026)

- Homebrew no longer builds bottles for Intel and its installer is Apple
  Silicon only. YADR detects Intel (`uname -m != arm64`) and installs via
  MacPorts first (`platform/macos.sh` → `PORT_PACKAGES`).
- Package name mapping: `delta` (brew) → `git-delta` (MacPorts).
- `zsh-syntax-highlighting` / `zsh-autosuggestions` are not in MacPorts:
  YADR clones them into `~/.local/share/yadr-plugins/` (no sudo), which
  `shell/plugins.zsh` already checks before brew paths.
- `fzf` from MacPorts lives under `/opt/local/share/fzf/`; `shell/zshrc`
  sources those paths plus the modern `fzf --zsh` hook, all guarded.
- `vim` on macOS resolves to genuine Apple Vim (`/usr/bin/vim`):
  YADR creates `~/.local/bin/vim → nvim` with a `provides-vim` marker
  (removed by `yadr uninstall --purge`). Genuine Vim is never touched.
- Full field report with verification: `docs/homebrew-intel.md`.

## Support matrix

- macOS Apple Silicon: Homebrew (bottles), primary path.
- macOS Intel: MacPorts first, Homebrew best-effort (Tier 3, may build
  from source), XDG clones as no-sudo fallback.
- Linux (Debian/Ubuntu), server, WSL: apt/dnf/pacman via `platform/`.

## Headless SSH / minimal server

- Use Core: `yadr install core` (no runtimes; mise/Node only with `yadr install node`).
- Every modern alias has a POSIX fallback; if you see `command not found`, it is a bug.
- `nvim --headless` and `zsh -n` must always pass (see `tests/smoke.sh`).
