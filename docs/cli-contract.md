# CLI contract — dependency-free `bin/yadr`

`bin/yadr` (bash 3.2-compatible dispatcher) and `bin/lib/*.sh` (paths, install,
recover, doctor, runtime, benchmark, completion) must run from a minimal Linux
box, a `curl | sh` bootstrap and ancient macOS bash with nothing beyond
bash/git. The library directory is resolved from the script's own path; the
split is mechanical and shares one shell and one behavior. `shellcheck -S
warning` runs on every shipped shell file in CI.

## Destinations (ADR-005)

`bin/lib/paths.sh` is the only place that computes a destination. Each helper
follows the variable of the program that reads the file, falling back to the
XDG default:

| Destination | Follows |
|---|---|
| Neovim config, plugin/Mason data, cache, state | `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` |
| mise config and data | `XDG_CONFIG_HOME`, `XDG_DATA_HOME` |
| theme, migrated files, gitsigns marker | `XDG_CONFIG_HOME/yadr` |
| backups, purge snapshots, `provides-*` markers, `installed-ref` | `XDG_STATE_HOME/yadr` |
| foreign binaries moved before replacement | `XDG_STATE_HOME/yadr-binary-backups` |
| bash/zsh completions | `XDG_DATA_HOME` (`bash-completion/completions`, `zsh/site-functions`) |
| fish completions | `XDG_CONFIG_HOME/fish/completions` |
| zsh rc | `ZDOTDIR` when set |
| `.gitconfig`, `.tmux.conf`, `~/.local/bin` | `$HOME` (git/tmux/XDG have no alternative) |

`platform/*.sh` compose the same defaults inline because they run standalone. A
test rejects hardcoded XDG-derived paths in `bin/`, `platform/` and
`bootstrap.sh`.

## Installed revision

`$XDG_STATE_HOME/yadr/installed-ref` (default
`~/.local/state/yadr/installed-ref`) is written by `bootstrap.sh` and by
`yadr update` after its repo attempt, including a failed pull/tag checkout. `yadr install`
does not write it. The file is written through an exclusive temporary file and
moved into place (mode `0600`).

Keys, one `key=value` per line: `sha`, `ref`, `branch`, `tag`, `version`,
`origin` (credentials stripped) and `recorded` (UTC ISO-8601). `yadr doctor`
prints the recorded revision; a missing file is informational and a recorded
SHA that differs from live `HEAD` is a warning with the recovery command. This
is local state, not an attestation.

## Backups

| Pointer | Written by | Used by |
|---|---|---|
| `last-install-backup` | first `yadr install` on a HOME | `yadr uninstall` |
| `last-update-backup` | `yadr update`, before the pull | diagnostics only |
| `last-backup` | `yadr backup`; first install keeps the compatibility pointer | legacy fallback when `last-install-backup` is absent |

The install pointer is first-install-wins. A reinstall or update does not
overwrite it. An existing checkout with managed symlinks but no install pointer
is legacy and does not create a fake install backup. The update snapshot records
topology for inspection and is never a restore source.

`uninstall --purge` requires a valid `last-install-backup`; without one it
refuses before removing anything and preserves the backups. Restored links that
point inside `$YADR_HOME` are materialized before the checkout is deleted;
external symlinks are preserved.

## Shell completions

`yadr completion bash|zsh|fish` prints a script to stdout with no side effects.
`yadr completion --install` and `yadr install` write all three where each shell
reads them. `uninstall` removes exactly those files. A test compares each
script's command list with `yadr --help`, so a new command without completion
fails the suite.

## Failure taxonomy

- **Required:** `die` / non-zero (bad profile, unknown command, missing
  mandatory `nvim`). The command reports failure.
- **Optional:** `warn`, exit 0 (missing font, LSP servers, pnpm). Success with
  warnings.
- **Best-effort:** `warn` plus recorded state (platform script error but links
  still applied; offline update fallback). `doctor` re-checks it.

## Per-command contract

| Command | Preconditions | Modifies | Exit |
|---|---|---|---|
| `install [profile] [--dry-run]` | checkout present | nothing with `--dry-run`; otherwise platform packages (sudo), links, first-install backup, login shell, toolchains — only after confirmation | 0 ok; 1 bad profile, failed optional profile or unwritable backup |
| `plan [profile]` | checkout present | nothing (alias of `install --dry-run`) | 0; 1 bad profile |
| `update` | git checkout | pull on a branch, latest release tag on a detached `--ref` checkout; update snapshot, plugins, `installed-ref`; runtimes only when the repo phase succeeds | 0; 1 failed repo or runtime phase |
| `doctor` | nothing | read-only (first nvim start installs plugins once) | 1 on any FAIL row |
| `diff` | nothing | nothing | 0 |
| `backup` | nothing | unique dir under `backups/` + `last-backup`; install pointer untouched | 0; 1 copy failure |
| `uninstall` | nothing | removes own links, restores `last-install-backup`, optional purge | 0; 0 on cancel; 1 when purge has no valid install backup |
| `migrate` | nothing | copies classic customization into `~/.config/yadr/migrated/` + backup | 0 |
| `runtime *` | mise for use/list/current | global tool versions (`use`) | 1 without backend/spec |
| `theme *` | nothing | `~/.config/yadr/solarized-bg` | 1 unknown name |
| `gitsigns *` | nothing | marker file | 1 unknown subcommand |
| `benchmark *` | zsh/nvim present | temporary dirs only | 1 unknown target/missing tool |
| `completion <shell>` | nothing | prints; `--install` writes the three files | 1 unknown shell |
| `version` | nothing | nothing | 0 |
