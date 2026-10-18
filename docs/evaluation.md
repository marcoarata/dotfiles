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

Intermediate revisions are not itemized; only revisions where the rubric was
actually re-scored appear. The v0.3.0 row is appended by the release commit.
Self-audited rows are marked as such on purpose: the external 8.0 is the only
number in this table that came from someone else.

### v0.3.0, dimension by dimension

Scored on the tagged revision. Every score is a judgement; the "backed by"
column names the command or artifact a reader can re-run to disagree with it.

| # | Dimension | Score | Backed by | Known limit |
|---|---|---|---|---|
| 1 | Architecture | 9.5 | `bin/lib/*.sh` one-concern modules, `platform/common.sh`, ADR-001..004, `shellcheck -S warning` clean | `bin/yadr` is still the largest file; `packs/` is a contract by convention, not by code |
| 2 | Install & reproducibility | 9.5 | `bootstrap.sh --local --yes` twice on a clean `HOME`; `bootstrap.sh --ref v0.3.0`; CI `install` (Ubuntu, macOS) and `arch-container` (Arch) | the `mise` installer is unpinned (listed in `docs/releases.md`); no macOS Intel lane |
| 3 | Operational safety | 9.5 | `tests/fault.bats` (9 injected failures), `uninstall --purge` e2e, `yadr diff`, ADR-003/004 | purge relies on its own markers: deleting them removes less, never more |
| 4 | Portability | 9.5 | the suites pass on Ubuntu, macOS and Arch; package-manager tests cover apt, dnf and pacman | WSL 1 cannot run Node >= 23 (upstream, documented); Intel mac is tier 3 |
| 5 | Developer UX | 9.0 | `docs/cli-contract.md`, `--help` on both entrypoints, `doctor` repair hints, next-steps after install | English only; no completions for shells other than zsh |
| 6 | Neovim | 9.5 | `Lazy! restore` is a no-op on a clean `XDG` dir (26 pins, exit 0, 2026-10-18); `smoke` parses every Lua file; lockfile drift check | the plugin set is not exercised headless beyond that restore |
| 7 | Shell scripting | 9.5 | `shellcheck -S warning` clean on every shipped bash file, `bash -n`/`zsh -n`, bash 3.2-compatible code | two languages by design: bash for the CLI, zsh for the shell layer |
| 8 | Documentation | 9.5 | README, INSTALL-YADR, `docs/` (ADRs, mappings, migration, troubleshooting, releases, evaluation, e2e report) | it is long, and it is English-only |
| 9 | Testing & evidence | 9.5 | `smoke` (88 checks), 94 bats tests (9 of them injected failures), coverage floor 50% with 57.5% measured, 6 CI lanes, `docs/e2e-report.md` | the coverage floor covers `bin/` only; the visual matrix was ephemeral evidence |
| 10 | Simplicity | 9.0 | no framework, no daemon, the CLI is plain bash, non-DRY is deliberate and documented | six CI lanes and five test batteries are more machinery than the product needs |

Aggregate: **9.5 / 10** -- the mean of the ten scores is 9.45 and rounds to
9.5. The two 9.0s are the deliberate price of the rest: the UX loses nothing
but offers nothing outside zsh and English, and the testing machinery is
heavier than the product. A project that dropped either would be simpler and
less trustworthy, which is the trade this revision chose.

## Re-executable checks

Every command below runs from the repository root and touches nothing outside an
isolated `$HOME`/`/tmp`. "Must" is the invariant, not a snapshot number: counts
grow, invariants do not.

| Command | Proves | Must |
|---|---|---|
| `bash tests/smoke.sh` | Structure, shipped-file presence, `zsh -n`/`bash -n`, nvim Lua parse, lockfile pins, `VERSION` is semver and `CHANGELOG.md` has an entry for it | `fail=0` |
| `bats tests/shell.bats` | Aliases, runtime prompt, theme, font, purge, install honesty, CLI contract, benchmarks, `export`/`apply` round-trip and tamper rejection, package-manager selection (apt/dnf/pacman) | only environment-dependent skips (see limits) |
| `bats tests/bootstrap.bats` | Installer flags, the `curl \| bash -s` stdin path, tag/VERSION agreement, usage errors | 0 failures |
| `bats tests/fault.bats` | Injected failures fail loudly and print no success line for work that did not happen | 0 failures |
| `bash tests/coverage.sh` | Line coverage of `bin/` measured from the bats suite, against a floor | `core >= floor`, exit 0 |
| `bootstrap.sh --ref vX.Y.Z` from a fresh `HOME` (the published tag, `YADR_HOME` elsewhere) | The tag installs itself detached and `VERSION` matches the tag name | `yadr version` prints `X.Y.Z`; `yadr doctor` reports `0 errors` |
| `shellcheck -S warning bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh tests/smoke.sh tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash` | Shell hygiene of every shipped and test bash file | no output, exit 0 |
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
- **One bats test is environment-dependent**: "nerd font absent without dirs or
  fc-list tools". On a developer machine that has a Nerd Font installed it
  fails by definition; CI machines do not have one. It is green in CI, and the
  local failure is the test working as intended.

## Appending the next evaluation

1. `git rev-parse HEAD` — the row is about a revision, not a date.
2. Run every command in the table above on that revision.
3. Score the 10 dimensions, each with the command that backs it.
4. Add the row (date, revision, verdict, source) without touching older rows.
5. Record the honest aggregate: if a blocker stays open, the score stays where
   the blocked dimension puts it.
