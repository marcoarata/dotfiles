# Changelog

Newest first. Each date is the day its tag was cut. The process (pin sync,
local green, tag, post-tag verification) lives in `docs/releases.md`, and the
command behind every claim is in `docs/evaluation.md`.

## [0.8.1] — 2026-10-25 — prompt counts, cursorline, confirmed runtimes

### Fixed

- **Ahead/behind counts now render in the Damoekri RPROMPT.** `git rev-list
  --left-right --count` separates the two numbers with a tab; the old
  space-based split produced `0<TAB>0` and never matched the arrow conditions.
  The prompt now reads both fields with `read -r ahead behind`.
- **The dirty mark is `✘` instead of `✗`.** The cleaner glyph keeps the prompt
  distinct from the CLI's red error marker; the clean `✔` is unchanged.
- **`yadr update` asks before upgrading runtimes.** The new `[Y/n]` prompt
  defaults to yes on Enter, skips on EOF/non-interactive input, and honors
  `--yes`. A declined runtime phase leaves the repository update successful.

### Changed

- **`cursorline` is enabled.** The current line is highlighted again, matching
  classic YADR; absolute line numbers and the narrow sign column are unchanged.

### Tests

- Regression tests cover ahead/behind against a local upstream, the `✘` dirty
  mark, `cursorline`, and the runtime prompt's Enter/no/EOF paths.
- Test count: 134 (four new tests). Core line coverage: 56.9% (611/1073,
  floor 50%).

### Notes

- No new commands, options or dependencies. No pinned artifact changed
  (`runtime/mise.toml`, `nvim/lazy-lock.json`, `terminal/fonts/manifest.env`).
- The documented install commands are pinned to `v0.8.1`.

## [0.8.0] — 2026-10-20 — debt closure: trustworthy bootstrap and recovery evidence

### Changed

- **The documented bootstrap is pinned to the release tag.** The README no
  longer installs from `main`; it names `v0.8.0`, verifies `VERSION`, and
  explains the checksum path. `main` remains the development branch.
- **Releases publish `SHA256SUMS`.** It is generated from the tagged
  `bootstrap.sh` and attached to the GitHub release. It is an integrity check,
  not a signature; tags remain annotated but unsigned.
- **GitHub Actions are pinned by full commit SHA.** `actions/checkout` is pinned
  to `v4.4.0` and Dependabot is configured for GitHub Actions. A static test
  rejects any workflow `uses:` that is not a 40-character lowercase SHA.

### Tests

- **Recovery coverage now includes a dirty checkout and dry-run uninstall.**
  `update` warns before a pull that may refuse, leaves the working tree alone,
  skips runtimes and exits non-zero. `uninstall --dry-run` proves it changes
  nothing.
- **Uninstall restore is exercised end to end.** A managed symlink is replaced
  by its last backup while unrelated user files and the checkout survive.
- Test count: 130 (five new tests; no shipped behavior changed). Core line
  coverage: 57.4% (610/1062, floor 50%).

### Docs

- `docs/supply-chain.md` documents the bootstrap trust model, the Actions pins,
  the checksum limits, and the fact that v0.8.0 does not ship an SBOM.
- `docs/releases.md` records the exact-tag install and `SHA256SUMS` release
  step.

### Notes

- No new commands, options or interfaces. `doctor --json`, CycloneDX SBOM,
  new distro CI lanes and GPG signing remain out of scope for this release.
- No pinned artifact changed (`runtime/mise.toml`, `nvim/lazy-lock.json`,
  `terminal/fonts/manifest.env`).

## [0.7.1] — 2026-10-19 — tag aligned with main

### Notes

- **Release metadata only.** `main` and `v0.7.1` point to the same commit; no
  runtime, installer, pin, path or CLI behavior changed from `v0.7.0`.
- Tests and evidence from `v0.7.0` still apply: 125 tests, 56.7% coverage, and
  the three tracked pin files are unchanged (`runtime/mise.toml`,
  `nvim/lazy-lock.json`, `terminal/fonts/manifest.env`).

## [0.7.0] — 2026-10-19 — traceable installs, pinned downloads

### Added

- **Installed-revision traceability (R5).** `bootstrap.sh` and `yadr update` write
  `$XDG_STATE_HOME/yadr/installed-ref` (default
  `~/.local/state/yadr/installed-ref`): `sha`, `ref`, `branch`, `tag`, `version`,
  `origin` (credentials stripped) and `recorded`. The write is atomic and mode
  `0600`. `yadr doctor` shows the commit/tag/version, treats a missing file as
  informational (old installs) and warns when the recorded commit differs from
  the live `HEAD`. `yadr install` does not write it; a cancelled update writes
  nothing.
- **Supply-chain pins (R6).** Direct downloads are versioned and SHA-256
  verified: the mise installer `2026.10.15` (run with `MISE_VERSION` and
  `MISE_INSTALL_HELP=0`), zoxide `0.10.0`, Neovim `v0.12.6`, the lazygit
  `0.66.2` fallback for linux/darwin x86_64/arm64, and the macOS zsh plugin
  fallback by tag + exact commit (syntax-highlighting `0.8.0`,
  autosuggestions `v0.7.1`). Inventory, threat model, exceptions and bump
  procedure: `docs/supply-chain.md`.

### Changed

- **A checksum mismatch is a hard failure.** No installer runs or archive is
  extracted before verification, and no `provides-*` marker is written on
  failure. `platform/common.sh` now owns `sha256_of`/`verify_sha256`, shared by
  the font, zoxide, Neovim, lazygit and mise downloads.
- **lazygit fallback uses the real asset names.** The tarball URL is lowercase
  (`lazygit_<ver>_linux_x86_64.tar.gz`, `..._darwin_...`), and macOS tries the
  pinned tarball when Homebrew fails or is absent instead of returning 1.
  Package-manager installs stay rolling.
- **macOS zsh plugin clones are pinned and revalidated.** A clone at the wrong
  commit is re-cloned; a clone whose `HEAD` does not match the pinned commit is
  refused and the previous checkout is left in place.
- **Hints point to a pinned path.** `yadr install core` replaces the old
  `curl https://mise.run | sh` suggestion in `doctor`, `runtime` and the
  troubleshooting guide.

### Notes

- Package managers (apt/dnf/pacman/Homebrew/MacPorts), Homebrew's own installer
  when `brew` is absent, and `pnpm = "latest"` remain documented rolling
  exceptions. No GPG key is configured in this release; tags are annotated but
  unsigned, and `git tag -v` is the future signed-tag check.
- Tests: 125. Coverage: 56.7% (floor 50%). Pinned artifacts unchanged
  (`runtime/mise.toml`, `nvim/lazy-lock.json`, `terminal/fonts/manifest.env`).

## [0.6.3] — 2026-10-19 — install plans first, update reports both phases

### Added

- **`yadr install --dry-run` (and `yadr plan`).** Prints the diff, the platform
  step, the runtimes and the link count, then stops; nothing is written. It is
  the same plan the real install shows before asking.

### Fixed

- **`install` no longer writes before the confirmation.** The platform script,
  the profile payload, `handle_legacy_yadr`, the previous-shell record and the
  share snapshots ran before the diff and the prompt, so answering "no" still
  installed packages and then printed "nothing modified". All of them now run
  after the confirmation; cancelling leaves the machine untouched.
- **`ensure_nvim` no longer deletes an `nvim-upstream` directory it does not
  own.** Without the `provides-nvim-upstream` marker, an existing
  `~/.local/nvim-upstream` is moved to the state backups and the install
  continues; it is replaced outright only when YADR created it.
- **`yadr update` reports its two phases separately.** A failed pull now skips
  the runtime upgrade (the checkout did not move) and returns non-zero; a failed
  `mise upgrade` also returns non-zero. It no longer advances the runtimes while
  the config stays behind.

### Changed

- **Behavior fix:** `lazygit`, `tools` and `macos-extras` now exit non-zero when
  their script fails (they used to warn and exit 0). Check the status if you
  call them from automation.

## [0.6.2] — 2026-10-19 — honest doctor total, leaner Linux packages

### Fixed

- **`yadr doctor` under-reported rogue/foreign symlinks.** The notices were
  printed with `warn`, so the summary said `0 warnings` right next to them.
  `detect_rogue_checkouts` now feeds one aggregate warning to the doctor total
  (`0 errors, 1 warning` when a managed link points outside `YADR_HOME`); the
  per-link lines stay as detail. `yadr install` is unaffected.

### Changed

- **`platform/linux.sh` no longer installs `neovim` via apt/dnf.** Both usually
  ship <0.11, so `ensure_nvim` replaced them with the pinned upstream tarball
  right after apt had pulled an unused copy (~30 MB with `neovim-runtime` on
  Ubuntu 22.04). The upstream tarball is now the single source of the ≥0.11
  floor. `pacman` keeps the distro package (Arch is rolling and ships ≥0.11).

## [0.6.1] — 2026-10-19 — documentation consolidation

The install guide and the reference now live in one file, and `docs/` passed a
YAGNI/DRY audit: duplication was removed, evidence was kept.

### Changed

- **`README.md` is the single entry point.** It absorbs the full install guide
  (`INSTALL-YADR.md`, steps 1-8), adds the CI badge, and keeps one section order
  from Overview to Damoekri. The manual, auditable install path is still there.
- **`docs/` was consolidated.** ADR-001..004 are folded into the decisions table
  in `docs/architecture.md`; the per-tag E2E sections are one table; the
  pre-v0.5.0 per-dimension tables are folded into their score-history rows;
  `homebrew-intel.md`, `troubleshooting.md`, `migration.md` and
  `architecture.md` lost duplicated prose. `docs/` 1,563 → 994 lines (−36%).

### Removed

- **`INSTALL-YADR.md`** — fully contained in `README.md`.
- **`docs/adr-001-symlink-manager.md`, `docs/adr-002-runtime-manager.md`,
  `docs/adr-003-purge-inventory.md`, `docs/adr-004-failure-policy.md`** — the
  decisions and their rationale are in `docs/architecture.md`; ADR-005 and
  ADR-006 remain full records.

## [0.6.0] — 2026-10-19 — prompt bold, `yadr --version`

### Added

- **`yadr --version`.** Prints the version and exits 0, like `yadr version`.
  Before, `--version` fell through to `unknown command`. It is listed in the
  options line of `yadr --help`, off the indented command list, so the
  usage↔completions drift guard is unaffected.

### Changed

- **The Damoekri `RPROMPT` renders its git and runtime segments in bold.** The
  red of a mistyped command in zsh-syntax-highlighting is `fg=red,bold` (the
  plugin default); the prompt used the same `red` without the weight, which read
  as a different color. Both segments now match. No color changed, and
  `YADR_RUNTIME_COLOR` still overrides the runtime color.
- **The README states the Nerd Font requirement under the installation steps**
  instead of the overview, and moves the **Scope** section below the command
  list.

## [0.5.0] — 2026-10-19 — declared scope, one vocabulary

Two commands leave the core because they failed the scope rule ADR-006 now
writes down: a subsystem stays only if it prevents a real problem, or a test
fails without it.

### Removed

- **`yadr export` / `yadr apply`** (and `bin/lib/transfer.sh`, 194 lines).
  Moving user state between machines is not the lifecycle — a machine is
  reproduced by installing again, not by copying state — and the author never
  used them. If a third party needs it, it returns as an opt-in pack with a
  demonstrated request.
- **`yadr pack list` / `yadr pack add`.** `pack add X` only called
  `install X`: a second vocabulary for one action. Install a layer the normal
  way: `yadr install <name>`.

### Changed

- `yadr install javascript` is now an alias of the `node` profile
  (`normalize_profile`), so the memorable name survives without a `pack`
  command. `usage()` and the three completion scripts list it, and the drift
  test keeps them in sync.
- `yadr migrate` is documented as a one-shot classic-YADR import (ADR-006),
  not a maintenance surface.
- Docs follow **one home per topic** (ADR-006 point 7): the README install
  section now points at `INSTALL-YADR.md`, `migration.md` keeps the classic→2027
  map instead of repeating the install, and the duplicated Intel/Homebrew and
  support-matrix text is gone. `docs/` 2348 → 2141 lines.

### Migration

- Replace `yadr pack add <name>` with `yadr install <name>`.
- `export`/`apply` have no replacement in core. Reinstalling reproduces a
  machine; `~/.gitconfig.user`, `~/.tmux.conf.user` and `~/.secrets` stay
  user-owned and are read in place (`docs/migration.md`).

No shipped runtime behaviour changed beyond the command set: the installer,
`doctor`, the purge inventory and the theme are untouched.

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

No shipped code changes: `v0.4.0` and `v0.4.1` differ only in `tests/`,
`.github/`, this file, `VERSION` and `docs/`. This is the tag whose eight CI
jobs are green.

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
