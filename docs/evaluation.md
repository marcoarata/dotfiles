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

> **Correction (appended 2026-10-18, with the v0.3.1 row).** The mean quoted
> above is an arithmetic slip: adding the table it refers to
> (8 x 9.5 + 2 x 9.0) gives **9.40**, not 9.45. Per rule 1 the row's scores and
> verdict are left exactly as published; the corrected number and what it
> implies are recorded in the v0.3.1 section below.

### v0.3.1, dimension by dimension

Scored on the tagged revision (ADR-005 implemented). Same rubric as above:
the cells listed here are the ones that moved, and every one of them is backed
by a command in the next section.

| # | Dimension | v0.3.0 | post-tag re-audit | v0.3.1 | What moved it (and the standing limit) |
|---|---|---|---|---|---|
| 1 | Architecture | 9.5 | 9.5 | 9.5 | `bin/lib/paths.sh` owns every destination and is sourced before any other module; `bin/yadr` is still the largest file |
| 2 | Install & reproducibility | 9.5 | 9.5 | 9.5 | `ensure_nvim_plugins` now checks the directory Neovim actually reads, so the restore cannot be skipped silently; a real install with moved `XDG` runs in CI |
| 3 | Operational safety | 9.5 | 9.5 | 9.5 | `share_dirs()` feeds the pre-install snapshot **and** `uninstall --purge` from one list, so they can no longer drift |
| 4 | Portability | 9.5 | **9.0** | 9.5 | restored. A moved-`XDG` box was measurably broken (silent skip, unclearable warning, purge leaving data behind); it is now covered by 7 tests and by a real install in CI. Limits unchanged: WSL 1 cannot run Node >= 23 (upstream), Intel mac is tier 3 |
| 5 | Developer UX | 9.0 | 9.0 | 9.0 | unchanged: English only; no completions for shells other than zsh |
| 6 | Neovim | 9.5 | 9.5 | 9.5 | `doctor` resolves config/data through `nvim_config_dir`/`nvim_data_dir`, and a test asserts Neovim's own `stdpath("config")`/`stdpath("data")` agree with the helpers |
| 7 | Shell scripting | 9.5 | 9.5 | 9.5 | `shellcheck -S warning` clean on every shipped bash file, `bash -n`/`zsh -n`, bash 3.2-compatible code |
| 8 | Documentation | 9.5 | 9.5 | 9.5 | ADR-005 plus a "Where files live" section in `docs/cli-contract.md`, the README and `docs/troubleshooting.md` |
| 9 | Testing & evidence | 9.5 | 9.5 | 9.5 | `smoke` (89 checks), 101 bats tests (7 of them the path policy), coverage floor 50% with 59.3% measured, 6 CI lanes; the coverage floor still covers `bin/` only |
| 10 | Simplicity | 9.0 | 9.0 | 9.0 | unchanged: one more small module (`paths.sh`, 100% line coverage) inside the same 6 lanes |

Aggregate: **9.4 / 10** -- the mean of the ten scores is exactly 9.40. Two
things are stated plainly instead of rounded away:

1. **The v0.3.0 row's arithmetic was wrong** (see the correction above): its
   own table averages 9.40, so the 9.5 verdict of that row was never supported
   by its own breakdown.
2. **The defect is fixed and Portability is back at 9.5**, which returns the
   mean from 9.35 (post-tag re-audit) to 9.40. Reaching 9.45 needs one more
   half point of real work, and this file names where it comes from rather than
   rounding for it. The cheapest honest one is dimension 5: completions for
   bash/fish, which its v0.3.0 limit already lists.

### v0.4.0, dimension by dimension

Scored on the tagged revision (`yadr completion` added). Only dimension 5
moves; every other cell repeats its v0.3.1 score, and the limit column keeps
each standing limit honest. This is the half point the v0.3.1 section named.

| # | Dimension | v0.3.1 | v0.4.0 | What moved it (and the standing limit) |
|---|---|---|---|---|
| 1 | Architecture | 9.5 | 9.5 | `bin/lib/completion.sh` is one more one-concern module; `bin/yadr` is still the largest file |
| 2 | Install & reproducibility | 9.5 | 9.5 | `install` writes the completions on both the full and the fast path; the CI `install` lane asserts the three files after a real install |
| 3 | Operational safety | 9.5 | 9.5 | `uninstall` removes exactly the three generated files (the dry-run lists them first); `share_dirs()` still feeds the snapshot and the purge from one list |
| 4 | Portability | 9.5 | 9.5 | the completion files land under the moved `XDG` directories, asserted in CI's Arch lane. Limits unchanged: WSL 1 cannot run Node >= 23 (upstream), Intel mac is tier 3 |
| 5 | Developer UX | 9.0 | **9.5** | `yadr completion bash\|zsh\|fish` prints a script, `install` writes all three where each shell reads them; the "no completions for shells other than zsh" limit is gone. The remaining "English only" is a deliberate repo-wide invariant, not a defect |
| 6 | Neovim | 9.5 | 9.5 | unchanged |
| 7 | Shell scripting | 9.5 | 9.5 | `shellcheck -S warning` clean including the new module; `bash -n`/`zsh -n`; bash 3.2-compatible code |
| 8 | Documentation | 9.5 | 9.5 | `docs/cli-contract.md` gains a "Shell completions" section; README, architecture and `--help` updated |
| 9 | Testing & evidence | 9.5 | 9.5 | `smoke` (90 checks), 105 bats tests (4 for completions: parse-in-shell, drift against `--help`, write+remove under moved `XDG`, install wiring), coverage floor 50% with 56.0% measured, 6 CI lanes. The dip from 59.3% is the recorder counting the static completion scripts as executable lines; the floor still covers `bin/` only |
| 10 | Simplicity | 9.0 | 9.0 | unchanged: one more small module (`completion.sh`) inside the same 6 lanes |

Aggregate: **9.45 / 10** -- the mean of the ten scores is exactly 9.45. It is
written as 9.45 and not as 9.5, on purpose: the v0.3.0 row once quoted 9.5 for
a table that averaged 9.40 (see the correction above). 9.45 is the first number
the breakdown actually supports, and it happens to round back to the 9.5 that
revision wanted. Every half point is named; none is rounded.

> **Correction (appended 2026-10-18, after the tag).** The `v0.4.0` revision was
> tagged before its CI finished, and two of its eight jobs came back red.
> `arch-container`: the new completion tests used `diff -u` and `cmp -s` to
> compare the command lists and the installed script, and Arch's base container
> ships neither (no diffutils) — `tests/helpers.bash` already documents that
> trap for `cmp`. `install (ubuntu-24.04)`: the new CI assertion assumed the
> default `XDG_CONFIG_HOME`, and that runner exports a non-default one, so the
> bash and zsh files (under `XDG_DATA_HOME`) were found and the fish file (under
> `XDG_CONFIG_HOME`) was not. Both are defects of the evidence added in that
> release, not of the product: `yadr` itself completed correctly on both
> runners. They are fixed after the tag — the drift test compares the two lists
> as strings, the byte-identical check uses `file_sha`, and the CI step resolves
> its paths with `bin/lib/paths.sh` exactly as the install did — and every job
> is green on the fixed revision. That fix is the only content of the `v0.4.1`
> row above; the `v0.4.0` row and its table are left exactly as published.

## Re-executable checks

Every command below runs from the repository root and touches nothing outside an
isolated `$HOME`/`/tmp`. "Must" is the invariant, not a snapshot number: counts
grow, invariants do not.

| Command | Proves | Must |
|---|---|---|
| `bash tests/smoke.sh` | Structure, shipped-file presence, `zsh -n`/`bash -n`, nvim Lua parse, lockfile pins, `VERSION` is semver and `CHANGELOG.md` has an entry for it | `fail=0` |
| `bats tests/shell.bats` | Aliases, runtime prompt, theme, font, purge, install honesty, CLI contract, shell completions, benchmarks, `export`/`apply` round-trip and tamper rejection, package-manager selection (apt/dnf/pacman) | only environment-dependent skips (see limits) |
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

## Appending the next evaluation

1. `git rev-parse HEAD` — the row is about a revision, not a date.
2. Run every command in the table above on that revision.
3. Score the 10 dimensions, each with the command that backs it.
4. Add the row (date, revision, verdict, source) without touching older rows.
5. Record the honest aggregate: if a blocker stays open, the score stays where
   the blocked dimension puts it.
