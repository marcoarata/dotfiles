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

Intermediate revisions are not itemized; only revisions where the rubric was
actually re-scored appear. The v0.3.0 row is appended by the release commit.
Self-audited rows are marked as such on purpose: the external 8.0 is the only
number in this table that came from someone else.

## Re-executable checks

Every command below runs from the repository root and touches nothing outside an
isolated `$HOME`/`/tmp`. "Must" is the invariant, not a snapshot number: counts
grow, invariants do not.

| Command | Proves | Must |
|---|---|---|
| `bash tests/smoke.sh` | Structure, shipped-file presence, `zsh -n`/`bash -n`, nvim Lua parse, lockfile pins | `fail=0` |
| `bats tests/shell.bats` | Aliases, runtime prompt, theme, font, purge, install honesty, CLI contract, benchmarks | only environment-dependent skips (see limits) |
| `bats tests/fault.bats` | Injected failures fail loudly and print no success line for work that did not happen | 0 failures |
| `bash tests/coverage.sh` | Line coverage of `bin/` measured from the bats suite, against a floor | `core >= floor`, exit 0 |
| `shellcheck -S warning bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh tests/smoke.sh tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash` | Shell hygiene of every shipped and test bash file | no output, exit 0 |
| `bootstrap.sh --local --yes` with `HOME=/tmp/<fresh>` | Install from a clean HOME: symlinks, CLI on `PATH`, idempotent second run | exit 0 both times |
| `HOME=/tmp/<fresh> bin/yadr doctor` | Environment contract after install | `0 errors, 0 warnings` |
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
