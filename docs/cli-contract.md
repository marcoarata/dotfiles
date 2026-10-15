# CLI contract — why `bin/yadr` stays one file

`bin/yadr` (~1000 lines, bash 3.2-compatible) is intentionally monolithic:
it must run from `curl | sh` bootstraps, ancient macOS bash, and minimal
Linux boxes with zero dependencies beyond bash/git — a `lib/` tree sourced
at runtime would add load-path fragility exactly where installs must not
fail. Split it only on measured pain (a bug caused by coupling, not size).
`shellcheck -S warning` is enforced in CI as the coupling alarm.

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
| `update` | git checkout | repo pull, backup, plugins, mise upgrade | 0 (warns, never fails hard except cancelled=0) |
| `doctor` | nothing | nothing (read-only; first nvim start installs plugins once) | 1 when any FAIL row, else 0 |
| `diff` | nothing | nothing, always | 0 |
| `backup` | nothing | new dir under `backups/` + `last-backup` pointer | 0 |
| `uninstall` | nothing | removes own symlinks, restores backup, optional purge | 0, or 0 on cancel |
| `migrate` | nothing | copies into `~/.config/yadr/migrated/` + backup | 0 |
| `pack list|add` | list: nothing; add: same as profile install | 0; 1 on unknown pack |
| `runtime *` | mise for use/list/current | global tool versions (`use`) | 1 without backend/spec |
| `theme *` | nothing | `~/.config/yadr/solarized-bg` (use) | 1 on unknown name |
| `gitsigns *` | nothing | marker file (on/off) | 1 on unknown subcommand |
| `benchmark *` | zsh/nvim present | temp dirs only (removed) | 1 on unknown target/missing tool |
| `version` | nothing | nothing | 0 |
