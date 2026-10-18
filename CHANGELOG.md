# Changelog

Newest first. Each date is the day its tag was cut. The process (pin sync,
local green, tag, post-tag verification) lives in `docs/releases.md`, and the
command behind every claim is in `docs/evaluation.md`.

## [0.4.1] — 2026-10-18 — evidence that runs everywhere

`v0.4.0` was tagged before its CI finished and came back with two of eight jobs
red. Both were defects of the evidence added in that release, not of the
product, and this patch fixes them:

### Fixed

- The completion tests compared the command lists and the installed script with
  `diff -u` and `cmp -s`; Arch's base container ships neither (no diffutils).
  The drift test now compares the two sorted lists as strings, and the
  byte-identical check uses `file_sha` (coreutils `sha256sum`).
- The CI `install` assertion assumed the three files land under the default XDG
  directories. That runner exports a non-default `XDG_CONFIG_HOME`, so the fish
  file was looked for in the wrong place. The step now resolves the paths with
  `bin/lib/paths.sh`, exactly as the install did, and prints each one.

No shipped code changes: `v0.4.0` and `v0.4.1` are byte-identical outside
`tests/` and `.github/`. This is the tag whose eight CI jobs are green.

## [0.4.0] — 2026-10-18 — yadr completes itself

### Added

- `yadr completion bash|zsh|fish` prints a completion script for that shell to
  stdout; `yadr completion --install` writes all three. `yadr install` writes
  them too, on both the full and the fast path, so a normal install gets them
  without an extra step. Each file lands where its shell reads it:
  `$XDG_DATA_HOME/bash-completion/completions`, `$XDG_DATA_HOME/zsh/site-functions`
  and `$XDG_CONFIG_HOME/fish/completions`. `shell/zshrc` puts the zsh directory
  on `$fpath` before `compinit`. A shell other than zsh can now complete `yadr`,
  which was the standing Developer UX limit since v0.3.0.

### Changed

- `uninstall` removes the completion files it wrote (the `--dry-run` lists them
  first). They are generated text, not symlinks, so they could not ride along
  with the managed pairs.
- `yadr --help` now lists `completion` and `help`, and a test keeps that list
  and the three completion scripts in sync: adding a command without completing
  it (or the reverse) fails the suite.
- Coverage: core 59.3% -> 56.0%. No test was lost — the line recorder counts the
  static payload of the three completion scripts as executable lines, and they
  are data. The 50% floor still holds with margin.

## [0.3.1] — 2026-10-18 — paths that follow the tools

### Fixed

- `doctor`, `install`, `uninstall --purge` and `export`/`apply` resolved paths
  under `$HOME` while the programs they configure read `XDG_CONFIG_HOME`,
  `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_STATE_HOME`. On a machine whose
  XDG directories are moved (a desktop session exports them; Zorin/GNOME did on
  the machine where this was found) every failure was silent: `install core`
  skipped the Neovim plugin restore without a message, `doctor` then warned
  "neovim plugins not installed" forever (a hint that could not be cleared),
  the Neovim config symlink landed in a directory Neovim does not read while
  `doctor` reported the editor as configured, and `--purge` snapshotted and
  cleaned the wrong plugin/cache directories. Every destination is now computed
  by `bin/lib/paths.sh` (ADR-005): XDG where the reader honours it, `HOME`
  where git (`~/.gitconfig`) and tmux (`~/.tmux.conf`) always look, and
  `$ZDOTDIR` for the zsh rc. With the variables unset the fallbacks are the XDG
  spec defaults, so nothing moves and no migration is needed.
- `doctor`'s "live checkout has local modifications" hint now names the most
  common cause first: `~/.gitconfig` is a symlink into the checkout, so a plain
  `git config --global user.email` edits `git/gitconfig` in the repository and
  makes later `yadr update` runs refuse to fast-forward. The hint now says to
  keep the identity in `~/.gitconfig.user` (where `git/gitconfig` already
  `include`s it). Found while verifying the v0.3.0 tag on a fresh `HOME`.
- `docs/evaluation.md`: the `doctor` invariant read `0 errors, 0 warnings` as
  if it held on any fresh `HOME`. It does not, and the tag itself shows why: a
  fresh install reports `0 errors` and a warning per thing this machine cannot
  provide (distro packages need `sudo`; LSP servers need `yadr install
  typescript`). The row and the `--ref` row now state what was measured.

### Added

- `bin/lib/paths.sh`: the single place that computes a destination, sourced by
  `bin/yadr` before any other module, with `docs/adr-005-path-policy.md`.
- 7 path-policy tests (`bats tests/shell.bats -f "path policy"`), including one
  that asks Neovim itself (`stdpath()`) and one that fails if `bin/`,
  `platform/` or `bootstrap.sh` hardcode one of those paths again.
- The Arch lane now also performs a **real install with moved XDG
  directories** and runs `doctor` against it.

### Changed

- The bats suites unset `XDG_*`/`ZDOTDIR` in `setup()`: they no longer inherit
  the host session's variables, so no test can read or write the real
  `~/.config`/`~/.local/share` by accident. That also removed a local,
  environment-dependent failure of the Nerd Font test: a Nerd Font installed by
  the user leaks in through `XDG_DATA_HOME`, and the test asserts absence.
- `doctor`'s repair hints print the path that was actually resolved (for
  example `$(mise_config_dir)/conf.d/`) instead of a hardcoded `~/.config/...`.
- `docs/evaluation.md`: a v0.3.1 row, and the v0.3.0 row's aggregate is
  corrected (its own table averages 9.40, not the 9.45 it quotes). The row's
  scores and verdict are left exactly as published.

## [0.3.0] — 2026-10-18 — evidence you can re-run

### Added

- `yadr export` / `yadr apply`: move the state git cannot carry for you (git
  identity, theme, mise `conf.d` pins, migrated classic files) between machines
  as a tar.gz with a SHA-256 manifest. `apply` verifies every member against the
  manifest **and** a name whitelist — rejecting absolute and `..` paths —
  before writing a single byte, then backs up whatever it overwrites.
- `bootstrap.sh --ref vX.Y.Z`: install one exact release. The tag is checked out
  detached and the checkout's `VERSION` must match the tag, so a mislabelled tag
  stops the install instead of shipping something nobody can identify later.
  `--local --ref vX.Y.Z` verifies a hand-copied checkout; `--help` documents
  the flags.
- CI lanes: `coverage` (line coverage of `bin/`, own recorder, floor, no
  external service), `fault-injection` (`tests/fault.bats`), and
  `arch-container` (unit suites plus a real install on `archlinux:latest`).
- `tests/fault.bats`: one injected failure per test — broken runtime, failing
  editor step, failed `git pull`, cancelled update, blind purge, interrupted
  plugin clone — each asserting the failure is reported **and** that no success
  line was printed for work that did not happen.
- `tests/bootstrap.bats`: installer flags, release pinning, and the
  `curl | bash -s` path users actually paste.
- `docs/evaluation.md`: the rubric the project is judged by, the score history,
  the command behind each claim, and the limits this release does not claim.
- `docs/adr-003-purge-inventory.md` and `docs/adr-004-failure-policy.md`.
- README support matrix by verification tier (tier 1 = CI suites + real install
  on every push, tier 4 = documented limits).

### Fixed

- `yadr update` printed `ok repo updated.` right after a **failed** `git pull`
  and exited 0. It now warns, leaves the checkout untouched, skips the editor
  sync and returns non-zero. Both new update tests fail on the old code.
- `curl | bash -s`, the documented install, printed an unbound-variable error on
  its first line: `BASH_SOURCE` is unset when the script arrives on stdin.
- `lazy_restore` reported its status only because the caller set `pipefail`; it
  now returns it explicitly, so the advisory warnings are true in any context.
- `dirty_tree_list` could abort `update` with no message when `git status`
  itself failed.
- README `pack add` examples named packs that do not exist.

### Changed

- CI runner images are pinned to `ubuntu-24.04` (no silent migration to
  Ubuntu 26); bumps are deliberate and re-verified.
- `docs/cli-contract.md` states the real exit codes of `update` (failed pull is
  no longer a warning with exit 0).

## [0.2.1] — 2026-10-15

- `bin/yadr` split into `bin/lib/*.sh` modules plus shared `platform/common.sh`
  helpers: shellcheck-clean, one concern per file, behaviour unchanged.
- `tests/smoke.sh` gained the Lua parse check and `nvim/lazy-lock.json` drift
  check; shell tests made hermetic (isolated `HOME`, no PATH leakage).
- `docs/e2e-report.md` committed as a project artifact.

## [0.2.0] — 2026-10-14

- macOS Intel tier: MacPorts-first install, XDG plugin clones as no-sudo
  fallback.
- Neovim ≥ 0.11 as a hard floor with an actionable error; always-on `vim` shim
  that never hijacks a genuine Vim.
- Custom `yadr` lightline theme with per-mode statusline blocks; classic
  damoekri layout (git segment back in `RPROMPT`).
- Dirty-tree guard before `update`; advisory git identity check.
- Entire project translated to English (code, CLI output, docs).
- CI matrix, `docs/releases.md`, `docs/cli-contract.md`.

## [0.1.0] — 2026-10-05

- First release: Core + Damoekri prompt + Neovim layer + mise runtime layer.
