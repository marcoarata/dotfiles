# CLI contract — why `bin/yadr` stays dependency-free (`bin/` + `bin/lib/`)

`bin/yadr` (dispatcher, bash 3.2-compatible) + `bin/lib/*.sh` (one file per
area: paths, install, recover, doctor, runtime, benchmark, transfer, completion) stay dependency-free:
they must run from `curl | sh` bootstraps, ancient macOS bash, and minimal
Linux boxes with zero dependencies beyond bash/git. `lib/` is sourced via
a `BIN_DIR`-resolved absolute path (symlink-aware, `YADR_LIB_DIR` override
only for tests), so there is no load-path fragility. Split is mechanical
only — same shell, same behavior. `shellcheck -S warning` is enforced in CI
as the coupling alarm.

## Where files live (ADR-005)

`bin/lib/paths.sh` is the only place that computes a destination, and it is
loaded before any other module. Every helper follows the environment variable of
the program that reads the file, falling back to the XDG spec default
(`$HOME/.config`, `$HOME/.local/share`, `$HOME/.cache`, `$HOME/.local/state`):

| Destination | Follows | Why |
|---|---|---|
| Neovim config / plugin-Mason data / cache / state | `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` | Neovim resolves them with `stdpath()` |
| `mise` config and data | `XDG_CONFIG_HOME`, `XDG_DATA_HOME` | `mise` honours both |
| theme, migrated classic files, gitsigns marker | `XDG_CONFIG_HOME` (`/yadr`) | YADR's own state; the marker is read by the Lua side from the same variable |
| backups, purge snapshots, `provides-*` markers | `XDG_STATE_HOME` (`/yadr`) | YADR's own state |
| bash / zsh completion files | `XDG_DATA_HOME` (`/bash-completion/completions`, `/zsh/site-functions`) | bash-completion and zsh's `$fpath` read them there |
| fish completion file | `XDG_CONFIG_HOME` (`/fish/completions`) | fish loads its completions from there |
| zsh rc | `ZDOTDIR` when set | zsh reads `$ZDOTDIR/.zshrc` instead of `~/.zshrc` |
| `~/.gitconfig`, `~/.tmux.conf`, `~/.local/bin` | nothing (HOME) | git and tmux always read them; XDG defines no binary directory |

`install`, `doctor`, `diff`, `backup`, `uninstall --purge`, `export`/`apply` and
`theme` all consume these helpers, and `share_dirs()` feeds the purge snapshot
and the purge itself from one list. `platform/*.sh` compose the same defaults
inline because they run standalone; a test fails if `bin/`, `platform/` or
`bootstrap.sh` hardcode one of these paths again. See
`docs/adr-005-path-policy.md`.

## Shell completions

`yadr completion bash|zsh|fish` prints that shell's completion script to stdout
(no side effects); `yadr completion --install` writes all three where each
shell reads them; `yadr install` writes them too. The zsh script is a site
function (`_yadr`) and `shell/zshrc` adds its directory to `$fpath` before
`compinit`; bash-completion and fish discover theirs from their XDG
directories. `uninstall` removes exactly those three files. The scripts are
static text on purpose (small, human-readable, one syntax per shell); a test
compares the command list in each against `yadr --help`, so a command added
without a completion fails the build.

Failure taxonomy used throughout:

- **required** → `die` / exit non-zero (bad profile name, unknown command,
  missing `nvim` where mandatory). The command reports FAILURE.
- **optional** → `warn`, exit still 0 (missing font, lsp servers, pnpm).
  The command reports success with warnings.
- **best-effort** → `warn` + state recorded (platform script errored but
  symlinks still linked; offline `git pull` fallback). `doctor` re-checks it.

## Per-command contract

| Command | Preconditions | Modifies | Exit codes |
|---|---|---|---|
| `install [profile]` | checkout present | platform packages (sudo), symlinks, backup, login shell, toolchains | 0 ok (warnings allowed); 1 on bad profile |
| `update` | git checkout | repo pull, backup, plugins, mise upgrade | 0 (warns); 1 when the pull failed or a runtime did not install |
| `doctor` | nothing | nothing (read-only; first nvim start installs plugins once) | 1 when any FAIL row, else 0 |
| `diff` | nothing | nothing, always | 0 |
| `backup` | nothing | new dir under `backups/` + `last-backup` pointer | 0 |
| `uninstall` | nothing | removes own symlinks, restores backup, optional purge | 0, or 0 on cancel |
| `migrate` | nothing | copies into `~/.config/yadr/migrated/` + backup | 0 |
| `export` | nothing | writes a bundle file at `--out` (default `$PWD`) | 0 (warns when there is nothing to export) |
| `apply` | a YADR bundle | restores user state in `$HOME` after SHA-256 verification; backups first | 1 on tampered/foreign bundle, unsafe member or write failure |
| `pack list|add` | list: nothing; add: same as profile install | 0; 1 on unknown pack |
| `runtime *` | mise for use/list/current | global tool versions (`use`) | 1 without backend/spec |
| `theme *` | nothing | `~/.config/yadr/solarized-bg` (use) | 1 on unknown name |
| `gitsigns *` | nothing | marker file (on/off) | 1 on unknown subcommand |
| `benchmark *` | zsh/nvim present | temp dirs only (removed) | 1 on unknown target/missing tool |
| `completion <shell>` | nothing | nothing (prints to stdout); `--install` writes the three files into the XDG dirs above | 1 on an unknown shell |
| `version` | nothing | nothing | 0 |
