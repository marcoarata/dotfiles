# Releases

How a YADR 2027 release is cut. No release exists until all boxes check.

## Process

1. Bump `VERSION` (`X.Y.Z`) and add the matching `CHANGELOG.md` entry.
2. Sync pins from a clean checkout: open `nvim` once (`Lazy! restore` and the
   `:Mason` servers the profiles declare), then `git diff -- nvim/lazy-lock.json`
   must contain only intended bumps. Commit the lockfile.
3. Run the full local suite:

   ```sh
   bash tests/smoke.sh
   bats tests/shell.bats
   bats tests/bootstrap.bats
   bats tests/fault.bats
   bash tests/coverage.sh
   shellcheck -S warning bin/yadr bin/lib/*.sh bootstrap.sh platform/*.sh \
     tests/smoke.sh tests/coverage.sh tests/coverage-hook.sh tests/helpers.bash
   bats tests/shell.bats -f "static provenance"
   nvim --headless -u NONE -l tests/treesitter-compat.lua
   nvim --headless -u NONE -l tests/telescope-style.lua
   ```

   Also run `yadr doctor` on a fresh isolated HOME (0 errors; warnings name what
   that machine lacks). For a release that touches paths, run
   `bats tests/shell.bats -f "path policy"` and one real install with moved
   `XDG_*` variables.
4. Tag annotated: `git tag -a vX.Y.Z -m "YADR 2027 vX.Y.Z"` and push
   `main` plus the tag. Compare `git rev-parse vX.Y.Z^{}` with the commit that
   passed CI before tagging; tag pushes do not trigger the workflow.
5. Publish `SHA256SUMS` generated from the tagged content:
   `sha256sum bootstrap.sh > SHA256SUMS` (macOS:
   `shasum -a 256 bootstrap.sh > SHA256SUMS`). Attach it to the GitHub release.
6. Install from the exact tag, not `main`:
   `bootstrap.sh --ref vX.Y.Z` checks out the tag detached and refuses when the
   tag and `VERSION` disagree. Verify `yadr version` prints `X.Y.Z`,
   `yadr doctor` reports 0 errors and shows the recorded revision, and
   `${XDG_STATE_HOME:-$HOME/.local/state}/yadr/installed-ref` contains that
   revision.

## CI on every push

| Job | Runs on | Measures |
|---|---|---|
| `lint` | Ubuntu | `shellcheck -S warning` on shipped bash + `zsh -n`/`bash -n` |
| `test` | Ubuntu, macOS | `tests/smoke.sh` + `bats tests/shell.bats tests/bootstrap.bats` |
| `coverage` | Ubuntu | line coverage of `bin/` against the floor |
| `fault-injection` | Ubuntu | injected failures fail loudly (`tests/fault.bats`) |
| `arch-container` | Arch | suites + real core install + `doctor`; second install with moved `XDG_*` |
| `install` | Ubuntu, macOS | isolated `$HOME` bootstrap, links, `PATH`, `doctor`, completions |

Runner images are pinned in `.github/workflows/ci.yml`. The same batteries run
by hand as part of step 3.

## Pinned inventory

| Artifact | Pin | Verified by |
|---|---|---|
| `runtime/mise.toml` | `node = "24"`, `python = "3.14"` (pnpm `latest` by policy) | `yadr runtime list`, E2E |
| `nvim/lazy-lock.json` | exact commits per plugin | `Lazy! restore` no-op; `doctor` lock check |
| `terminal/fonts/manifest.env` | URL + `YADR_FONT_SHA256` | `platform/*` verify SHA before unzip |
| mise installer | `2026.10.15` + SHA-256 | `install_mise` verifies before `sh` |
| zoxide Linux tarballs | `0.10.0` + SHA-256 per arch | `install_zoxide` verifies before extraction |
| Neovim Linux tarballs | `v0.12.6` + SHA-256 per arch | `ensure_nvim` verifies before extraction |
| lazygit tarball fallback | `0.66.2` + SHA-256 for linux/darwin x86_64/arm64 | `install_tarball` verifies before extraction |
| zsh plugin XDG fallback | syntax `0.8.0` → `db085e46…`; autosuggestions `v0.7.1` → `e52ee8ca…` | `clone_xdg_plugin` compares `HEAD` with the pinned commit |

Package managers (apt/dnf/pacman/Homebrew/MacPorts) and Homebrew's own installer
are documented rolling exceptions in `docs/supply-chain.md`.

Before tagging, verify the release changes none of the tracked pin files:

```sh
prev="$(git describe --tags --abbrev=0)"
git diff "${prev}..HEAD" -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env
```
