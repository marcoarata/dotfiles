# Releases

How a YADR 2027 release is cut. No release exists until all boxes check.

## Process

1. Bump `VERSION` (`X.Y.Z`, semver: before 1.0 a breaking change bumps the
   minor — `0.4.x → 0.5.0`; at 1.0+ it is the major).
2. Sync pins from a clean checkout: open `nvim` once (`Lazy! restore` +
   the `:Mason` servers the profiles declare), then `git diff -- nvim/lazy-lock.json` must
   contain only intended bumps. Commit the lockfile.
3. Green locally: `bash tests/smoke.sh`, `bats tests/shell.bats`,
   `bats tests/bootstrap.bats` (installer flags and release pinning),
   `bats tests/fault.bats` (injected failures), `bash tests/coverage.sh`
   (coverage floor), `shellcheck -S warning` on
   `bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh tests/smoke.sh
   tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash`,
   `yadr doctor` reports 0 errors on a fresh isolated HOME (its warnings name
   what that machine still lacks; `0 warnings` needs the distro packages and
   the documented install loop). For a release that touches paths, also run
   `bats tests/shell.bats -f "path policy"` and one real install with the
   `XDG_*` variables moved, which is what `docs/e2e-report.md` §6 records.
4. Tag annotated: `git tag -a vX.Y.Z -m "YADR 2027 vX.Y.Z"` + `git push origin main vX.Y.Z`.
5. Bootstrap installs `main` by default (`YADR_BRANCH` override exists);
   pin-sensitive users install the tag instead:
   `bootstrap.sh --ref vX.Y.Z` (checks out the tag detached and refuses to
   continue when the tag and its `VERSION` file disagree), then verify both
   sides: `yadr version` prints `X.Y.Z` and `yadr doctor` reports 0 errors
   (on a fresh `HOME` that is what it can be -- see the note above; and see
   `docs/e2e-report.md` §6 for the v0.3.0 run itself).

## What CI enforces on every push

| Job | Runs on | Blocks the release by measuring |
|---|---|---|
| `lint` | ubuntu | `shellcheck -S warning` on every shipped bash file + `zsh -n`/`bash -n` |
| `test` | ubuntu, macos | `tests/smoke.sh` (structure, syntax, nvim lua parse, lockfile pins) + `bats tests/shell.bats tests/bootstrap.bats` |
| `coverage` | ubuntu | line coverage of `bin/` from the bats suite, with a floor (`tests/coverage.sh`) |
| `fault-injection` | ubuntu | injected failures: broken runtime, failing editor, failed pull, blind purge (`tests/fault.bats`) |
| `arch-container` | Arch | the suites and a real core install + `doctor` inside `archlinux:latest` (pacman branch), plus a second real install with moved `XDG` directories (links **and** shell completions) and `doctor` against it |
| `install` | ubuntu, macos | `bootstrap.sh` in an isolated `$HOME`: symlinks, CLI on `PATH`, `yadr doctor`, and the bash/zsh/fish completion files |

Runner images are pinned (`ubuntu-24.04`, deliberate bumps); see the header
of `.github/workflows/ci.yml`. All five batteries (smoke, shell, bootstrap,
fault, coverage) run by hand exactly as CI runs them; `tests/coverage.sh`,
`tests/fault.bats` and `tests/bootstrap.bats` exist because "the suite is
green" is not evidence on its own.

## Pinned inventory (verify before tagging)

Re-verified for `v0.3.0` on 2026-10-18: the Nerd Font release was downloaded
again and its SHA-256 re-measured against `manifest.env`, and `Lazy! restore`
on a clean `XDG` directory left `nvim/lazy-lock.json` byte-identical (26 pins,
25 installed, `gitsigns.nvim` opt-in).

`v0.3.1` changes no pinned artifact, so that verification still applies:
`git diff v0.3.0..v0.3.1 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.4.0` (shell completions) touches none of
them either:
`git diff v0.3.1..v0.4.0 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging), and `v0.4.1` changes no shipped code
(`tests/`, `.github/` and the release docs only):
`git diff v0.4.0..v0.4.1 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.5.0` removes commands and deduplicates
docs; it touches none of them either:
`git diff v0.4.1..v0.5.0 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.6.0` adds a CLI option, bolds the prompt
and moves one README note; it touches none of them either:
`git diff v0.5.0..v0.6.0 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.6.1` consolidates the docs and removes
`INSTALL-YADR.md`; it touches none of them either:
`git diff v0.6.0..v0.6.1 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging).

| Artifact | Pin | Verified by |
|---|---|---|
| `runtime/mise.toml` | `node = "24"`, `python = "3.14"` (pnpm `latest` by policy) | `yadr runtime list`, E2E matrix |
| `nvim/lazy-lock.json` | exact commits per plugin | `Lazy! restore` is a no-op on clean checkout; `doctor` lock check |
| `terminal/fonts/manifest.env` | URL + `YADR_FONT_SHA256` | `platform/*` verify SHA before unzip |
| `mise` backend itself | unpinned installer (`https://mise.run`) | `mise --version` in `runtime doctor`; pin on demand via `runtime/mise.toml` |

Anything downloaded without a pin or checksum is a release blocker:
list it here or pin it before tagging.
