# Troubleshooting

## First Neovim start: Lazy panel shows (normal)

On first `nvim` open the **Lazy** window installs the plugins pinned in
`nvim/lazy-lock.json` (26 pins; 25 by default, `gitsigns.nvim` is opt-in).
`:q` closes it and your file remains; the second start is direct. Persistent
`Failed`, `■ build failed` or `Error detected` after `:Lazy restore` is a bug.
The panel only appears in `nvim`; classic `vim` opens the file directly.

## Moved `XDG` directories (the files are still findable)

YADR writes where the programs it configures read, so moving
`XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_CACHE_HOME`/`XDG_STATE_HOME` (or
`ZDOTDIR`) moves YADR's files too — no flag, no reinstall. Check with:

```sh
yadr diff | grep -E 'nvim|mise|yadr/|zshrc'   # read-only
```

Neovim follows `stdpath()`; `~/.gitconfig`, `~/.tmux.conf` and `~/.local/bin`
stay HOME-based; with the variables unset everything falls back to
`~/.config`, `~/.local/share` and `~/.local/state`. Policy:
`docs/adr-005-path-policy.md`.

## `yadr doctor`: `foreign symlink` / `rogue checkout`

A managed link (or a second clone) points outside `YADR_HOME` — usually a config
left by an earlier `bootstrap.sh --local` run from another checkout. The doctor
keeps those links and reports them (one warning). Re-point them:

```sh
yadr install core --yes   # backs up, then links everything to YADR_HOME
yadr diff                 # must read: 0 with changes
```

Keep a single sanctioned checkout: edit in your dev clone, commit, push, and run
`yadr update` on the install.

## `yadr doctor`: installed commit not recorded / differs

`bootstrap.sh` and `yadr update` write
`${XDG_STATE_HOME:-$HOME/.local/state}/yadr/installed-ref` (one `key=value`
per line). `yadr doctor` prints that revision. A missing file is informational:
run `yadr update` once. A warning that the recorded commit differs from the
live `HEAD` means the checkout moved after the last install/update:

```sh
cat "${XDG_STATE_HOME:-$HOME/.local/state}/yadr/installed-ref"
git -C "$YADR_HOME" log --oneline "$(sed -n 's/^sha=//p' "${XDG_STATE_HOME:-$HOME/.local/state}/yadr/installed-ref")"..HEAD
```

Review those local commits (or discard them), then run `yadr update` again.
The file is local state, not a signature; see `docs/supply-chain.md`.

## `yadr install`: plan, cancel, and what it touches

`install` is read-only until you approve the plan: it prints the diff, the
platform step, the runtimes and the link count, then asks. Answering `n` leaves
the system as it was — no packages, no state, no links. Use `yadr plan` (or
`yadr install --dry-run`) to see that plan and stop there.

If `~/.local/nvim-upstream` exists and YADR cannot prove it created it (no
`provides-nvim-upstream` marker), the installer moves it to
`~/.local/state/yadr/backups/` instead of deleting it. Move it back if it was
yours.

`yadr update` reports two phases. A failed pull skips the runtime upgrade on
purpose (the checkout did not move); fix the checkout and rerun.

## Slow shell (<500ms slow VM / <300ms workstation; see `yadr benchmark shell`)

1. `yadr benchmark shell` (isolated HOME, does not touch your `~`).
2. Typical culprits: several version managers active at once + `compinit` without dump.
3. Fix: mise only (`architecture.md`); `compinit -C` with daily dump (default in
   `shell/zshrc`); optional plugins with guard (`shell/plugins.zsh`).

## mise not activating / broken shims

- `command -v mise || echo missing` → `yadr install core` (runs `platform/` and installs the pinned mise).
- `mise doctor`, `mise ls`; if the pinned version is missing: `yadr runtime use node`.
- Headless SSH: `bin/yadr` and `shell/zshrc` prepend `~/.local/bin` and the mise shims.
- Do not mix version managers: use only `yadr runtime`.

## WSL: `yadr install node` fails with `Syntax error: ")" unexpected`

- Symptom: the runtime never lands (`mise ls --current` → `node 24.22.0 (missing)`);
  running node by hand prints `/…/bin/node: 1: Syntax error: ")" unexpected` (exit 2).
- Cause: **WSL 1** cannot `execve` official Node ≥23 binaries (microsoft/WSL#8151);
  the shell falls back to `/bin/sh` and dash chokes on the ELF. Not a YADR bug.
- Fix (preferred): move to WSL 2 — `wsl -l -v`, then `wsl --set-version <distro> 2` —
  and rerun `yadr install node`. WSL 2 needs hardware virtualization: inside a VM
  expose VT-x/AMD-V (quickemu: `extra_args="-cpu host,+vmx"` in `<vm>.conf`).
- Fallback on WSL 1: stay on Node 22.x, or wrap the official build: rename
  `bin/node` to `bin/node-orig`, make `bin/node` run
  `exec /lib64/ld-linux-x86-64.so.2 "$(dirname "$0")/node-orig" "$@"`, then
  `mise reshim`. Only `bin/node` is a binary; `npm`/`npx` are scripts.
- Check: WSL 2 reports `-microsoft-standard-WSL2` in `uname -r`; WSL 1 reports
  a `4.4.0-…-Microsoft` kernel.

## LSP not starting (Neovim)

- Old system binary (e.g. apt 0.6.1 on Ubuntu 22.04): outside YADR zsh the system
  `nvim` rules. Our config fails fast with the fix (`exec zsh`, or
  `yadr install core`) instead of E5113.
- `vim` resolves to YADR Neovim via a `~/.local/bin/vim` shim (`provides-vim`
  marker; removed by `yadr uninstall --purge`). System Vim is never touched.
- `:checkhealth` (lsp) and `:=vim.lsp.get_clients()`; `yadr doctor` checks
  `node`, `rg`, `fd`. Install servers via `:Mason` or `yadr install typescript`.
- Floor: Neovim ≥0.11. YADR installs the pinned upstream tarball (`v0.12.6`)
  when apt/dnf ships an older build; `platform/linux.sh` verifies its SHA-256
  before extraction. A checksum mismatch is a hard failure, not a reason to
  bypass the pin: re-download from the official release and update the pin in
  a reviewed commit (`docs/supply-chain.md`).
- A project without `tsconfig.json`/`package.json` starts no server. Normal.
- Headless/SSH: `nvim --headless "+checkhealth" +q` must show no errors.

## Fonts / Neovim statusline

- The statusline is lightline with Solarized: Powerline separators + text,
  **zero Nerd icons** (no boxes or hex codes).
- `platform/` installs JetBrainsMono Nerd Font (`terminal/fonts/`); select it in
  your terminal for the prompt and vim separators.
- Neovim background is transparent (`none`) by default; solid Solarized via the
  macOS install menu (`1 light / 2 dark / 3 none`) or `YADR_SOLARIZED_BG`.
  Details: `terminal/solarized/README.md`.

### iTerm2: keep Monaco, fix glyphs

- Keep `Monaco 15`, add `JetBrainsMonoNFM-Regular 15` (Mono, not Propo) as
  Non-ASCII fallback, same point size, `Use Non-ASCII = 1`.
- Test line must render complete: `   ± ✓ →`. Verified profile:
  `docs/homebrew-intel.md` R7.

## macOS Intel / Homebrew Tier 3

Homebrew 7.0.0 no longer builds Intel bottles and its installer is Apple Silicon
only. YADR detects Intel (`uname -m != arm64`) and uses MacPorts first
(`platform/macos.sh` → `PORT_PACKAGES`, `delta`→`git-delta`), with no-sudo XDG
clones for the zsh plugins. Full report: `docs/homebrew-intel.md`.

## Support matrix

Tiers by platform (how each is verified): [README.md](../README.md#support-matrix).

## Headless SSH / minimal server

- Use Core: `yadr install core` (no runtimes; mise/Node only with `yadr install node`).
- Every modern alias has a POSIX fallback; `command not found` is a bug.
- `nvim --headless` and `zsh -n` must always pass (see `tests/smoke.sh`).
