# Quality ledger — rubric, history, and re-executable evidence

An evaluation that cannot be re-run is an opinion. This file keeps the rubric
YADR 2027 is judged against, the history of those judgements, and the exact
commands behind every claim. Nothing here is measured by reading prose.

Two rules keep it useful:

1. **Append, never rewrite.** A new evaluation adds a row with its revision and
   date; earlier rows stay as they were, including the ones that graded the
   project lower.
2. **A number with no command is not evidence.** If a dimension's score cannot
   be reproduced with a command in this file, it does not belong in a row.

## Rubric (10 dimensions)

| # | Dimension | What it measures |
|---|---|---|
| 1 | Architecture | Layer boundaries (Core/CLI/Editor/Runtime/Packs/Platform), swappable backends, decisions recorded as ADRs |
| 2 | Install & reproducibility | One command from a bare machine, idempotent re-runs, isolated `$HOME`, rollback path |
| 3 | Operational safety | Non-destructive by default, automatic backup, refuses blind wipes, never reports success for work that did not happen |
| 4 | Portability | Linux/macOS/WSL, bash 3.2 and 5, no GNU-only flags, graceful fallbacks |
| 5 | Developer UX | CLI contract, `doctor` repair hints, fast path, next-steps guide, discoverable docs |
| 6 | Neovim | Pinned plugins, LSP/Treesitter contract, colorscheme fidelity, prompt integration |
| 7 | Shell scripting | `shellcheck -S warning` clean, guard patterns, quoting, zsh/bash compatibility |
| 8 | Documentation | Scope and non-goals, ADRs, classic→2027 mapping, troubleshooting, evidence reports |
| 9 | Testing & evidence | smoke + bats + injected failures + coverage floor + CI lanes + E2E report |
| 10 | Simplicity | Dependency count, line count, no framework, deliberate non-DRY where it pays |

## Score history

| Date | Revision | Verdict | Source |
|---|---|---|---|
| 2026-10-09 | pre-repo audit | 8.0 / 10 | External audit note (not stored in this repo) |
| 2026-10-17 | `52a8d7a` | 9.0 / 10 | Self-audit recorded in the E2E work of that revision |
| 2026-10-17 | `9084222` | 9.1 / 10 | Self-audit, 20 commits after the previous row |
| 2026-10-18 | `v0.3.0` (tag) | 9.5 / 10 | Self-audit; per-dimension breakdown below. The tag names the revision, so this row cannot drift |
| 2026-10-18 | `ac7b346` (post-tag `main`) | 9.4 / 10 | Re-audit of the tag published the same day: the release verification showed that `doctor` and `install` assumed `$HOME/.local/share` for Neovim's data, so a machine with moved `XDG` directories was silently broken (skipped plugin restore, unclearable warning, purge leaving data behind). Portability 9.5 → 9.0, mean 9.35. Self-audited |
| 2026-10-18 | `v0.3.1` (tag) | 9.4 / 10 | Self-audit; ADR-005 closes the split (Portability back to 9.5, mean 9.40) and the arithmetic of the v0.3.0 row is corrected without rewriting it. Per-dimension breakdown below. The tag names the revision |
| 2026-10-18 | `v0.4.0` (tag) | 9.45 / 10 | Self-audit; `yadr completion` closes dimension 5's standing limit ("no completions for shells other than zsh"), so Developer UX 9.0 -> 9.5 and the mean moves 9.40 -> 9.45. Written as 9.45, not rounded up to 9.5: this file names every half point it counts. Per-dimension breakdown below. The tag names the revision. **Two of its eight CI jobs were red** (evidence defects, not product); see the correction below |
| 2026-10-18 | `v0.4.1` (tag) | 9.45 / 10 | Self-audit, no re-score: the patch that makes the `v0.4.0` evidence green. The product is byte-identical to `v0.4.0` (only a test and a CI assertion changed), so the verdict stands and this is the tag whose eight jobs are green. Per-dimension breakdown: the `v0.4.0` table below, unchanged |
| 2026-10-19 | `v0.5.0` (tag) | 9.5 / 10 | Self-audit; ADR-006 declares the scope and non-goals the project never wrote down, and applies the rule retroactively — `export`/`apply` and the `pack` command are removed, the JS pack is installed with `yadr install javascript`, and the docs are deduplicated. Simplicity 9.0 → 9.5; the mean is exactly 9.50. Two things are stated, not rounded: the doc-line target (−30–40%) was not reached (8.8% cut — the rest is rationale and evidence), and the CI/test machinery is unchanged. Per-dimension breakdown below. The tag names the revision |
| 2026-10-19 | `v0.6.0` (tag) | 9.5 / 10 | Self-audit, no re-score: `yadr --version` is accepted (it used to fall through to `unknown command`), the Damoekri `RPROMPT` renders its git and runtime segments in bold (matching the syntax-highlighting error red, `fg=red,bold`, which is the plugin default), and the README states the Nerd Font requirement under the installation steps instead of the overview. No dimension moves; the verdict stands at 9.5 (the mean is exactly 9.50). Per-dimension breakdown: the `v0.5.0` table below, unchanged |
| 2026-10-19 | `v0.6.1` (tag) | 9.5 / 10 | Self-audit, no re-score: documentation consolidation. `README.md` is now the single entry point (it absorbs `INSTALL-YADR.md`), and `docs/` passed a YAGNI/DRY audit: ADR-001..004 were folded into `architecture.md`, the per-tag E2E sections were merged into one table, and the pre-v0.5.0 per-dimension tables were folded into their score-history rows. `docs/` 1,563 → 994 lines (−36%). No dimension moves; the verdict stands at 9.5 (the mean is exactly 9.50). Per-dimension breakdown: the `v0.5.0` table below, unchanged |
| 2026-10-19 | `v0.6.2` (tag) | 9.5 / 10 | Self-audit, no re-score: two small fixes. (1) `yadr doctor` now counts rogue/foreign symlink notices in its summary (one aggregate warning), so `0 warnings` no longer prints next to the ⚠ lines — the report stops under-reporting. (2) `platform/linux.sh` no longer installs `neovim` via apt/dnf, removing a redundant ~30 MB download before the pinned upstream tarball. No dimension's guarantee changes; the verdict stands at 9.5 (the mean is exactly 9.50). Per-dimension breakdown: the `v0.5.0` table below, unchanged |
| 2026-10-19 | `v0.6.3` (tag) | 9.5 / 10 | Self-audit, no re-score: the install flow is now plan → confirm → apply. `--dry-run`/`yadr plan` prints the diff and the planned side effects and writes nothing; cancelling leaves the machine untouched (the platform script, payload, legacy migration and snapshots moved after the confirmation). The optional profiles (`lazygit`, `tools`, `macos-extras`) propagate their exit status (behavior fix: they used to exit 0), `ensure_nvim` moves an unowned `~/.local/nvim-upstream` to the state backups instead of deleting it, and `yadr update` reports the repo and runtime phases separately (a failed pull skips the runtimes). No dimension's guarantee changes; the verdict stands at 9.5 (the mean is exactly 9.50). Per-dimension breakdown: the `v0.5.0` table below, unchanged. Tests: 109 (8 new in `tests/fault.bats`) |

Intermediate revisions are not itemized; only revisions where the rubric was
actually re-scored appear. The v0.3.0 row is appended by the release commit.
Self-audited rows are marked as such on purpose: the external 8.0 is the only
number in this table that came from someone else.

Per-dimension tables are kept only for the latest scored release
(`v0.5.0`); the earlier tables were removed in v0.6.1 to keep one home
per fact, and their scores remain in the rows above.

### v0.5.0, dimension by dimension

Scored on the tagged revision (ADR-006 "Scope and non-goals" applied). Only
dimension 10 moves; the other cells keep their previous score, and the limit
column states what did **not** change.

| # | Dimension | v0.4.1 | v0.5.0 | What moved it (and the standing limit) |
|---|---|---|---|---|
| 1 | Architecture | 9.5 | 9.5 | one concern fewer with the removal of `bin/lib/transfer.sh`; `bin/yadr` is still the largest file |
| 2 | Install & reproducibility | 9.5 | 9.5 | unchanged: `bootstrap.sh --local --yes` idempotent, CI `install` + `arch-container` |
| 3 | Operational safety | 9.5 | 9.5 | unchanged: `share_dirs()` still feeds the snapshot and the purge from one list; the purge e2e is intact |
| 4 | Portability | 9.5 | 9.5 | unchanged: the suites pass on Ubuntu/macOS/Arch; package-manager tests cover apt/dnf/pacman. `packs/` stays as per-project reference material, installed with `install <name>` |
| 5 | Developer UX | 9.5 | 9.5 | three fewer commands and one vocabulary for installing a layer; the completions list `install javascript`; English-only remains |
| 6 | Neovim | 9.5 | 9.5 | unchanged: 26 pins, `Lazy! restore` a no-op on a clean `XDG` dir |
| 7 | Shell scripting | 9.5 | 9.5 | unchanged: `shellcheck -S warning` clean, `bash -n`/`zsh -n`, bash 3.2-compatible |
| 8 | Documentation | 9.5 | 9.5 | ADR-006 declares scope, non-goals and the one-home-per-topic rule; `docs/` 2348 → 2141 lines. Limit: still long and English-only |
| 9 | Testing & evidence | 9.5 | 9.5 | 99 bats tests (6 removed with `export`/`apply`; the `pack` test replaced by the `javascript`-alias one), coverage floor 50% with 53.5% measured, the same 6 lanes. Limit: the floor still covers `bin/` only; the dip is the removal of a well-covered module |
| 10 | Simplicity | 9.0 | **9.5** | the product surface shrank (3 commands, 1 module, 259 code lines) and the scope is now declared instead of implicit, retiring the "undeclared scope" debt. Limit stated plainly: the CI/test machinery is unchanged (6 lanes, 5 batteries) and is the recorded price of dimensions 8/9; and the doc-line reduction fell short of the target — the remaining text is rationale and evidence, not duplication |

Aggregate: **9.5 / 10** — the mean of the ten scores is exactly 9.50, written as
9.5 because ten 9.5s average 9.50 with nothing rounded up. Two things are stated
instead of implied:

1. **The doc-line target (−30–40%) was not reached: `docs/` shrank 8.8%.** What
   was cut is the real duplication — the install guide written four times, a
   fourth copy of the Intel callout, the support matrix, a stale
   "(migrate on roadmap)". The rest is comments that explain a non-obvious
   "why" (ghost checkouts, WSL 1, regression causes, ADR references, test
   seams) and evidence (`e2e-report`, this ledger, `CHANGELOG`, ADRs); removing
   those would trade dimensions 8/9 for a smaller number.
2. **The Simplicity half point rests on the product surface, not the
   machinery.** Fewer commands, one fewer module and a declared scope are the
   change; the CI/test machinery is unchanged. A reader who counts the
   machinery as the product's cost can hold Simplicity at 9.0 and the mean at
   9.45 — the evidence behind both readings is the same, and the limit column
   says so.

## Re-executable checks

Every command below runs from the repository root and touches nothing outside an
isolated `$HOME`/`/tmp`. "Must" is the invariant, not a snapshot number: counts
grow, invariants do not.

| Command | Proves | Must |
|---|---|---|
| `bash tests/smoke.sh` | Structure, shipped-file presence, `zsh -n`/`bash -n`, nvim Lua parse, lockfile pins, `VERSION` is semver and `CHANGELOG.md` has an entry for it | `fail=0` |
| `bats tests/shell.bats` | Aliases, runtime prompt, theme, font, purge, install honesty, the `javascript` profile alias, CLI contract, shell completions, benchmarks, package-manager selection (apt/dnf/pacman) | only environment-dependent skips (see limits) |
| `bats tests/bootstrap.bats` | Installer flags, the `curl \| bash -s` stdin path, tag/VERSION agreement, usage errors | 0 failures |
| `bats tests/fault.bats` | Injected failures fail loudly and print no success line for work that did not happen | 0 failures |
| `bash tests/coverage.sh` | Line coverage of `bin/` measured from the bats suite, against a floor | `core >= floor`, exit 0 |
| `bootstrap.sh --ref vX.Y.Z` from a fresh `HOME` (the published tag, `YADR_HOME` elsewhere) | The tag installs itself detached and `VERSION` matches the tag name | `yadr version` prints `X.Y.Z`; `yadr doctor` reports `0 errors` |
| `shellcheck -S warning bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh tests/smoke.sh tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash` | Shell hygiene of every shipped and test bash file | no output, exit 0 |
| `bats tests/shell.bats -f "path policy"` | Installer, `doctor`, the purge inventory and the theme resolve destinations the way the tools they configure do (`XDG_*`, `ZDOTDIR`), including Neovim's own `stdpath()`; and no shipped file hardcodes one of those paths again | 7 tests, 0 failures |
| `bats tests/shell.bats -f "completions:"` | The three completion scripts parse in their own shell (`bash -n`, `zsh -n`, `fish --no-execute` when present) and name exactly the commands `yadr --help` lists; `--install` writes them under moved `XDG` dirs, byte-identical to `completion <shell>`, and removal takes them back | 4 tests, 0 failures |
| `bootstrap.sh --local --yes` with `HOME=/tmp/<fresh>` | Install from a clean HOME: symlinks, CLI on `PATH`, idempotent second run | exit 0 both times |
| `HOME=/tmp/<fresh> bin/yadr doctor` | Environment contract after install (run against the published tag on 2026-10-18) | `0 errors`; warnings name exactly what this machine still lacks -- identity, LSP servers, distro-provided shell plugins -- and each hint says how to add it. `0 warnings` needs the distro packages (sudo) and the documented install loop, which is what `docs/e2e-report.md` §2 records |
| `bin/yadr diff` | Nothing changes silently | read-only; no writes |
| `bin/yadr benchmark shell` | Startup budget (measured against the documented threshold) | `< 500ms` average |
| `git rev-list --count HEAD`, `grep -c '":' nvim/lazy-lock.json` | Commit and pin counts quoted in README/docs | match the tagged revision |

The CI jobs that run these on every push, and what each one blocks, are listed
in `docs/releases.md`. The E2E matrix behind the historical rows (ephemeral VM,
real macOS hardware, WSL guest) is in `docs/e2e-report.md`.

## Known limits (what this release does NOT claim)

- **Windows native is not supported.** WSL is; `platform/wsl.sh` delegates to
  `linux.sh`.
- **WSL 1 cannot run Node ≥ 23** for a host-side reason (microsoft/WSL#8151).
  Documented in `docs/troubleshooting.md`, deliberately not worked around.
- **`mise` is installed from `https://mise.run` without a checksum.** Fonts are
  SHA-256 verified; the runtime backend installer is not, and that is recorded
  in the pinned inventory of `docs/releases.md` instead of being hidden.
- **The release tag is annotated, not GPG-signed.** No SBOM, no signed
  artifacts: this project ships source, not binaries.
- **The coverage floor covers `bin/` only.** `bootstrap.sh` and `platform/*`
  are measured and printed as context; they are exercised by the CI `install`
  job, not by the bats suite.
- **Distro coverage in CI is Ubuntu, macOS and Arch.** Fedora/RHEL (`dnf`) is
  covered by a test that fakes the package manager and by the code path being
  identical, not by a real install on that distro.
- **Font visibility is not asserted in CI.** The Nerd Font pin (URL + SHA-256)
  was verified by downloading the release and re-measuring the digest, and the
  installers only warn when the font is not visible; the Arch lane reports how
  many font files landed in the isolated `HOME` and how many entries
  `fontconfig` sees, which is a headless-container question, not a product one.
- **The visual matrix is gone.** The screenshots of `docs/e2e-report.md` §3
  were temporary evidence and were removed; the section describes the review,
  it does not pretend to store the captures.
- **One bats test asserts a negative that depends on the machine**: "nerd font
  absent without dirs or fc-list tools". It is hermetic now — the suites unset
  `XDG_*`/`ZDOTDIR`, so a Nerd Font in the *user's* font directory no longer
  leaks into it and the local suite is green on a machine that has Nerd Fonts
  installed. A Nerd Font installed *system-wide* still makes it fail by
  definition, which is what the test is supposed to detect.
- **YADR's own executables stay in `~/.local/bin`.** XDG defines no binary
  directory, so `bin/yadr` and the tools YADR installs (nvim upstream, mise,
  zoxide, lazygit) keep the de-facto location. Everything that has an XDG
  variable (`config`, `data`, `cache`, `state`) follows it (ADR-005).
- **A real install with moved `XDG` directories runs in the Arch lane.** The
  Ubuntu/macOS `install` jobs install with the default paths; the moved-`XDG`
  behaviour is covered there by the bats suite.
- **The coverage number counts static data as code.** The three completion
  scripts live inside heredocs in `bin/lib/completion.sh`; the recorder counts
  their lines as executable even though the suite never "executes" them as
  code, which is what moved core coverage from 59.3% to 56.0% in v0.4.0. No
  test was lost and the 50% floor holds; the number is read as movement, not as
  a formal metric (see the header of `tests/coverage.sh`).
- **`docs/` is 994 lines after the v0.6.1 YAGNI/DRY pass** (from 1,563): what
  remains is rationale and evidence, and cutting it further would cost
  dimensions 8/9.

## Appending the next evaluation

1. `git rev-parse HEAD` — the row is about a revision, not a date.
2. Run every command in the table above on that revision.
3. Score the 10 dimensions, each with the command that backs it.
4. Add the row (date, revision, verdict, source) without touching older rows.
5. Record the honest aggregate: if a blocker stays open, the score stays where
   the blocked dimension puts it.
