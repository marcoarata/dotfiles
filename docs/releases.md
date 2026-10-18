# Releases

How a YADR 2027 release is cut. No release exists until all boxes check.

## Process

1. Bump `VERSION` (`X.Y.Z`, semver: breaking installer/config change = major).
2. Sync pins from a clean checkout: open `nvim` once (`Lazy! restore` +
   `:Mason` per `packs/`), then `git diff -- nvim/lazy-lock.json` must
   contain only intended bumps. Commit the lockfile.
3. Green locally: `bash tests/smoke.sh`, `bats tests/shell.bats`,
   `bats tests/bootstrap.bats` (installer flags and release pinning),
   `bats tests/fault.bats` (injected failures), `bash tests/coverage.sh`
   (coverage floor), `shellcheck -S warning` on
   `bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh tests/smoke.sh
   tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash`,
   `yadr doctor` 0/0 on a fresh isolated HOME.
4. Tag annotated: `git tag -a vX.Y.Z -m "YADR 2027 vX.Y.Z"` + `git push origin main vX.Y.Z`.
5. Bootstrap installs `main` by default (`YADR_BRANCH` override exists);
   pin-sensitive users install the tag instead:
   `bootstrap.sh --ref vX.Y.Z` (checks out the tag detached and refuses to
   continue when the tag and its `VERSION` file disagree), then verify both
   sides: `yadr version` prints `X.Y.Z` and `yadr doctor` reports 0/0.

## What CI enforces on every push

| Job | Runs on | Blocks the release by measuring |
|---|---|---|
| `lint` | ubuntu | `shellcheck -S warning` on every shipped bash file + `zsh -n`/`bash -n` |
| `test` | ubuntu, macos | `tests/smoke.sh` (structure, syntax, nvim lua parse, lockfile pins) + `bats tests/shell.bats tests/bootstrap.bats` |
| `coverage` | ubuntu | line coverage of `bin/` from the bats suite, with a floor (`tests/coverage.sh`) |
| `fault-injection` | ubuntu | injected failures: broken runtime, failing editor, failed pull, blind purge (`tests/fault.bats`) |
| `arch-container` | Arch | the suites and a real core install + `doctor` inside `archlinux:latest` (pacman branch) |
| `install` | ubuntu, macos | `bootstrap.sh` in an isolated `$HOME`: symlinks, CLI on `PATH`, `yadr doctor` |

Runner images are pinned (`ubuntu-24.04`, deliberate bumps); see the header
of `.github/workflows/ci.yml`. All five batteries (smoke, shell, bootstrap,
fault, coverage) run by hand exactly as CI runs them; `tests/coverage.sh`,
`tests/fault.bats` and `tests/bootstrap.bats` exist because "the suite is
green" is not evidence on its own.

## Pinned inventory (verify before tagging)

| Artifact | Pin | Verified by |
|---|---|---|
| `runtime/mise.toml` | `node = "24"`, `python = "3.14"` (pnpm `latest` by policy) | `yadr runtime list`, E2E matrix |
| `nvim/lazy-lock.json` | exact commits per plugin | `Lazy! restore` is a no-op on clean checkout; `doctor` lock check |
| `terminal/fonts/manifest.env` | URL + `YADR_FONT_SHA256` | `platform/*` verify SHA before unzip |
| `mise` backend itself | unpinned installer (`https://mise.run`) | `mise --version` in `runtime doctor`; pin on demand via `runtime/mise.toml` |

Anything downloaded without a pin or checksum is a release blocker:
list it here or pin it before tagging.
