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

## Headless SSH / minimal server

- Use Core: `yadr install core` (no runtimes; mise/Node only with `yadr install node`).
- Every modern alias has a POSIX fallback; if you see `command not found`, it is a bug.
- `nvim --headless` and `zsh -n` must always pass (see `tests/smoke.sh`).
