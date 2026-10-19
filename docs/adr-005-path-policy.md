# ADR-005 — Path policy: follow the variables of the tool that reads the file

- Status: accepted (v0.3.1). Implemented and covered by tests.
- Context: YADR writes files that **other programs** read: Neovim's config and
  plugin data, `mise`'s config, the zsh rc, git's config. Those programs follow
  the XDG base directory variables (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`,
  `XDG_CACHE_HOME`, `XDG_STATE_HOME`) and, for zsh, `ZDOTDIR`. The CLI did not:
  `managed_pairs`, `ensure_nvim_plugins`, `ensure_lsp_servers`, `doctor`'s
  plugin/Mason/Treesitter checks, the purge inventory and `theme_file` all
  assumed `$HOME/.config` and `$HOME/.local/share`. On a machine that moved its
  XDG directories the two halves disagreed, and every failure mode was silent:
  - `yadr install core` skipped the plugin restore without a message (the gate
    checked `$HOME/.local/share/nvim/lazy/lazy.nvim`, while Neovim loaded its
    plugins from `$XDG_DATA_HOME/nvim/lazy`), and `doctor` then warned
    "neovim plugins not installed" forever: the hint could never clear it.
  - The Neovim config symlink landed in `$HOME/.config/nvim`, a directory
    Neovim does not read when `XDG_CONFIG_HOME` is set, while `doctor` looked at
    that same symlink and reported the editor as configured.
  - `uninstall --purge` snapshotted and cleaned `$HOME/.local/share/nvim`,
    `$HOME/.cache/nvim` and `$HOME/.local/state/nvim` instead of the real
    directories, so a purge could leave hundreds of megabytes behind.
  The variables are not exotic: a desktop session exports them (Zorin/GNOME did
  on the machine where this was found), and the XDG spec makes relocating them
  the user's prerogative. Two places already got this right — Neovim's own
  `stdpath()` and the gitsigns marker (`bin/lib/doctor.sh` +
  `nvim/lua/yadr/plugins/git.lua`) — which is what made the split a defect
  rather than a design choice.
- Decision:
  1. **One module owns every path.** `bin/lib/paths.sh` is sourced by `bin/yadr`
     before any other module and exposes `xdg_config/data/cache/state`,
     `yadr_config_dir`, `yadr_state_dir`, `yadr_plugins_dir`,
     `nvim_config_dir/data/cache/state`, `mise_config_dir/data`,
     `zoxide_data_dir` and `zshrc_path`. Destinations are computed there and
     nowhere else: `managed_pairs`, the installer, `doctor`, the purge
     inventory, `export`/`apply` and the theme all consume the helpers.
  2. **Follow the reader, not the writer.** A path honours XDG when the program
     that reads it does. `~/.gitconfig` and `~/.tmux.conf` stay HOME-based
     because git and tmux always read them (`~/.gitconfig` in addition to the
     XDG one), and executables stay in `~/.local/bin` because XDG defines no
     binary directory. The zsh rc follows `ZDOTDIR` when set, since zsh reads
     `$ZDOTDIR/.zshrc` *instead of* `~/.zshrc`.
  3. **Defaults are the XDG defaults.** Every helper falls back to
     `$HOME/.config`, `$HOME/.local/share`, `$HOME/.cache` and
     `$HOME/.local/state`, so a machine that sets nothing behaves exactly as
     before this ADR: no migration, no moved files, no user-visible change.
  4. **The snapshot and the purge share one list.** `share_dirs()` prints the
     `tag<TAB>directory` pairs; `snapshot_share_dirs` records them and
     `uninstall --purge` consumes the same function, so the two can no longer
     drift (the tag used to be derived from the path shape, which breaks as soon
     as the path moves).
  5. **`platform/*.sh` mirror the defaults inline.** Those scripts are
     standalone entrypoints (`bash platform/linux.sh`) that must run without the
     CLI, so they compose `${XDG_*:-$HOME/...}` themselves and honour an
     exported `STATE_DIR` first. This is the same deliberate non-DRY trade the
     architecture document already records for `log`/`warn`/`have`; a test
     guards the class so the two halves cannot silently diverge again.
- Consequences:
  - Installing, diagnosing and purging now agree with the tools they configure.
    The specific failures above cannot happen silently any more.
  - A regression guard rejects hardcoded `$HOME/.local/share/nvim`,
    `$HOME/.config/nvim`, `$HOME/.config/yadr` and `$HOME/.config/mise` in
    `bin/`, `platform/` and `bootstrap.sh`, so this class stays closed by CI.
  - The Lua side reads the same variable (`XDG_CONFIG_HOME/yadr/solarized-bg`)
    as the CLI and the macOS menu writer, which keeps the theme single-sourced.
  - The tests no longer inherit the host's XDG variables (they are unset in
    `setup()`): the suites are hermetic, which also removed a local,
    environment-dependent failure of the Nerd Font test.
  - Cost: one more module and one more indirection in the hot path. Both are
    small, and `bin/lib/paths.sh` is measured at 100% line coverage.
- Evidence: tests "path policy: XDG moved — every destination follows the tool
  that reads it", "...the nvim config link lands where nvim resolves its
  config", "...nvim's own stdpath agrees with the helpers (XDG moved)",
  "...ZDOTDIR moves the zsh rc the installer manages", "...doctor sees nvim
  plugins under a moved XDG data dir", "...snapshot and purge cover the XDG
  directories the tools use" and "...shipped code never hardcodes the tools'
  XDG-derived dirs" in `tests/shell.bats`; `share_dirs()` in
  `bin/lib/install.sh`; the E2E run recorded in `docs/e2e-report.md` §6.
