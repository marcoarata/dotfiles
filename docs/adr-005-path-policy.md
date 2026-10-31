# ADR-005 — Path policy: follow the variable of the tool that reads the file

- Status: accepted (v0.3.1), implemented and covered by tests.
- Context: YADR writes files that other programs read: Neovim config and plugin
  data, `mise` config, the zsh rc, git config. Those programs follow
  `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` and,
  for zsh, `ZDOTDIR`. The CLI used to assume `$HOME/.config` and
  `$HOME/.local/share`; on a machine that moved its XDG directories the two
  halves disagreed silently: plugin restore was skipped, the Neovim config link
  landed where Neovim never looked, and purge cleaned the wrong directories.
- Decision:
  1. **One module owns every path.** `bin/lib/paths.sh` is sourced before any
     other module and exposes `xdg_config/data/cache/state`,
     `yadr_config_dir`, `yadr_state_dir`, `yadr_plugins_dir`,
     `nvim_config_dir/data/cache/state`, `mise_config_dir/data`,
     `zoxide_data_dir` and `zshrc_path`. Destinations are computed there and
     nowhere else.
  2. **Follow the reader, not the writer.** A path honours XDG when the program
     that reads it does. `~/.gitconfig` and `~/.tmux.conf` stay HOME-based;
     executables stay in `~/.local/bin` because XDG defines no binary directory.
     The zsh rc follows `ZDOTDIR` when set.
  3. **Defaults are the XDG defaults.** Every helper falls back to
     `$HOME/.config`, `$HOME/.local/share`, `$HOME/.cache` and
     `$HOME/.local/state`, so a machine that sets nothing behaves as before.
  4. **Snapshot and purge share one list.** `share_dirs()` prints the
     `tag<TAB>directory` pairs; `snapshot_share_dirs` records them and
     `uninstall --purge` consumes the same function.
  5. **`platform/*.sh` mirror the defaults inline.** They are standalone
     entrypoints that must run without the CLI, so they compose
     `${XDG_*:-$HOME/...}` themselves and honour an exported `STATE_DIR` first.
     A test guards the class.
- Consequences:
  - Install, diagnose and purge agree with the tools they configure.
  - A regression guard rejects hardcoded `$HOME/.local/share/nvim`,
    `$HOME/.config/nvim`, `$HOME/.config/yadr` and `$HOME/.config/mise` in
    `bin/`, `platform/` and `bootstrap.sh`.
  - The Lua side and the macOS menu writer read the same
    `XDG_CONFIG_HOME/yadr/solarized-bg`.
  - Tests unset host XDG variables in `setup()`, so the suites are hermetic.
  - Cost: one module and one indirection in the hot path; both are small.
- Evidence: the path-policy tests in `tests/shell.bats`, `share_dirs()` in
  `bin/lib/install.sh`, and the moved-XDG run in `docs/e2e-report.md`.
