# Quality ledger — rubric and re-executable evidence

An evaluation that cannot be re-run is an opinion. This file keeps the rubric,
the current verification commands and the limits of the v0.9.5 release. A score
without a command is not evidence.

## Rubric

| # | Dimension | What it measures |
|---|---|---|
| 1 | Architecture | Layer boundaries, swappable backends, recorded decisions |
| 2 | Install & reproducibility | One command from a bare machine, idempotent re-runs, isolated `$HOME` |
| 3 | Operational safety | Non-destructive defaults, automatic backups, refuses blind wipes, never reports success for work not done |
| 4 | Portability | Linux/macOS/WSL, bash 3.2 and 5, no GNU-only flags, graceful fallbacks |
| 5 | Developer UX | CLI contract, `doctor` hints, fast path, discoverable docs |
| 6 | Neovim | Pinned plugins, LSP/Treesitter contract, colorscheme fidelity |
| 7 | Shell scripting | `shellcheck -S warning` clean, quoting, bash/zsh compatibility |
| 8 | Documentation | Scope, ADRs, classic→2027 mapping, troubleshooting, evidence |
| 9 | Testing & evidence | Smoke + bats + injected failures + coverage + CI lanes |
| 10 | Simplicity | Dependency count, line count, no framework, deliberate non-DRY |

## Current checks

Every command runs from the repository root and touches only an isolated
`$HOME` or `/tmp`.

| Command | Proves | Must |
|---|---|---|
| `bash tests/smoke.sh` | structure, shipped files, `zsh -n`/`bash -n`, Lua parse, lockfile pins, `VERSION` semver and a matching `CHANGELOG.md` entry | `fail=0` |
| `bats tests/shell.bats` | aliases, runtime prompt, theme, font, purge, install honesty, profiles, CLI contract, completions, benchmarks, package-manager selection | only environment-dependent skips |
| `bats tests/bootstrap.bats` | installer flags, `curl \| bash -s` stdin path, tag/VERSION agreement, usage errors | 0 failures |
| `bats tests/fault.bats` | injected failures fail loudly and never print success for work not done | 0 failures |
| `bash tests/coverage.sh` | line coverage of `bin/` against the floor | `core >= floor`, exit 0 |
| `bootstrap.sh --ref v0.9.5` from a fresh `HOME` | the published tag installs detached and its `VERSION` matches | `yadr version` prints `0.9.5`; `yadr doctor` reports 0 errors |
| `shellcheck -S warning bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh tests/smoke.sh tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash` | shell hygiene of shipped and test bash | no output, exit 0 |
| `bats tests/shell.bats -f "path policy"` | destinations follow the variables the tools read, with no hardcoded XDG paths | 0 failures |
| `bats tests/shell.bats -f "completions:"` | the three scripts parse in their own shell and match `yadr --help`; install/remove round-trip | 0 failures |
| `bootstrap.sh --local --yes` with `HOME=/tmp/<fresh>` | clean install: links, CLI on `PATH`, idempotent second run | exit 0 both times |
| `HOME=/tmp/<fresh> bin/yadr doctor` | environment contract after install | 0 errors; warnings name what the machine lacks |
| `bin/yadr diff` | nothing changes silently | read-only; no writes |
| `bin/yadr benchmark shell` | startup budget | `< 500ms` average |

The CI jobs that run these on every push are listed in `docs/releases.md`.
The local/E2E matrix is in `docs/e2e-report.md`.

## Known limits

- **Native Windows is not supported.** WSL is; `platform/wsl.sh` delegates to
  `linux.sh`.
- **WSL 1 cannot run Node ≥ 23** for a host-side reason (microsoft/WSL#8151).
  Documented in `docs/troubleshooting.md`, deliberately not worked around.
- **`mise` is installed from `https://mise.run` without a checksum.** Fonts,
  zoxide, Neovim and lazygit are SHA-256 verified; the runtime backend installer
  is not. See `docs/supply-chain.md`.
- **The release tag is annotated.** This project ships source, not binaries.
- **The coverage floor covers `bin/` only.** `bootstrap.sh` and `platform/*`
  are printed as context and exercised by the install CI lane.
- **CI distro coverage is Ubuntu, macOS and Arch.** Fedora/RHEL (`dnf`) is
  covered by a test that fakes the package manager, not a real install.
- **Font visibility is not asserted in CI.** The Nerd Font pin is verified by
  downloading the release and re-measuring the digest; installers warn when the
  font is not visible.
- **YADR executables stay in `~/.local/bin`.** XDG defines no binary directory;
  everything with an XDG variable follows it (ADR-005).
- **A real install with moved `XDG` directories runs in the Arch lane.** The
  Ubuntu/macOS lanes use default paths; the bats suite covers the moved case.
- **The coverage number counts static completion data as code.** The number is
  read as movement, not as a formal metric.
