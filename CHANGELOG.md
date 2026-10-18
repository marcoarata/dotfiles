# Changelog

Newest first. Each date is the day its tag was cut. The process (pin sync,
local green, tag, post-tag verification) lives in `docs/releases.md`, and the
command behind every claim is in `docs/evaluation.md`.

## [Unreleased]

### Fixed

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
