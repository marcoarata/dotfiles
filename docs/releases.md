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
   `bats tests/shell.bats -f "static provenance"` (pins cannot drift),
   `nvim --headless -u NONE -l tests/treesitter-compat.lua` (Neovim 0.12
   directive shim), `nvim --headless -u NONE -l tests/telescope-style.lua`
   (Telescope layout and border highlights), `yadr doctor` reports 0 errors on
   a fresh isolated HOME (its warnings name what that machine still lacks;
   `0 warnings` needs the distro packages and the documented install loop). For
   a release that touches paths, also run `bats tests/shell.bats -f "path
   policy"` and one real install with the `XDG_*` variables moved, which is
   what `docs/e2e-report.md` §6 records.
4. Tag annotated: `git tag -a vX.Y.Z -m "YADR 2027 vX.Y.Z"` + `git push origin main vX.Y.Z`.
   Tags are annotated but **not signed** (no project key exists). Once a
   signing key is configured, verify with `git tag -v vX.Y.Z`; until then
   compare `git rev-parse vX.Y.Z^{}` with the commit that passed CI. Tag pushes
   do not trigger the CI workflow, so the commit must be verified before the
   tag is created.
5. Publish `SHA256SUMS` with the release, generated from the tagged content:
   `sha256sum bootstrap.sh > SHA256SUMS` (or `shasum -a 256 bootstrap.sh` on
   macOS). Attach it to the GitHub release. The checksum is an integrity check,
   not a signature.
6. Install from the exact tag, not from `main`:
   `bootstrap.sh --ref vX.Y.Z` (checks out the tag detached and refuses to
   continue when the tag and its `VERSION` file disagree), then verify both
   sides: `yadr version` prints `X.Y.Z`, `yadr doctor` reports 0 errors and
   shows the recorded commit/tag, and
   `${XDG_STATE_HOME:-$HOME/.local/state}/yadr/installed-ref` contains that
   revision (on a fresh `HOME` 0 errors is what it can be -- see the note
   above; and see `docs/e2e-report.md` §6 for the v0.3.0 run itself).

## What CI enforces on every push

| Job | Runs on | Blocks the release by measuring |
|---|---|---|
| `lint` | ubuntu | `shellcheck -S warning` on every shipped bash file + `zsh -n`/`bash -n` |
| `test` | ubuntu, macos | `tests/smoke.sh` (structure, syntax, nvim lua parse, lockfile pins) + `bats tests/shell.bats tests/bootstrap.bats` |
| `coverage` | ubuntu | line coverage of `bin/` from the bats suite, with a floor (`tests/coverage.sh`) |
| `fault-injection` | ubuntu | injected failures: broken runtime, failing editor, failed pull, blind purge (`tests/fault.bats`) |
| `arch-container` | Arch | the suites and a real core install + `doctor` inside `archlinux:latest` (pacman branch), plus a second real install with moved `XDG` directories (links **and** shell completions) and `doctor` against it |
| `install` | ubuntu, macos | `bootstrap.sh` in an isolated `$HOME`: symlinks, CLI on `PATH`, `yadr doctor`, the Tree-sitter shim unit test, and the bash/zsh/fish completion files |

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
is empty (checked before tagging). `v0.6.2` fixes the doctor warning total and
drops `neovim` from the apt/dnf package sets; it touches none of them either:
`git diff v0.6.1..v0.6.2 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.6.3` changes the install/update flows, the
platform ownership check and the CLI/completions; it touches none of them either:
`git diff v0.6.2..v0.6.3 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.7.0` adds traceability and pinned
direct downloads; it changes none of the three tracked pin files either:
`git diff v0.6.3..v0.7.0 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). Its new download pins were re-verified on
2026-10-19: the mise installer, the zoxide/Neovim/lazygit assets and the zsh
tag/commit pairs match `docs/supply-chain.md`. `v0.7.1` is a tag-alignment
release: `main` and the tag point to the same commit, and it changes none of the
three tracked pin files either:
`git diff v0.7.0..v0.7.1 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). No code or test files changed from `v0.7.0`;
its E2E evidence still applies. `v0.8.0` is a debt-closure release: it changes
none of the three tracked pin files either, and its only supply-chain change is
that GitHub Actions are pinned by full commit SHA:
`git diff v0.7.1..v0.8.0 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). No SBOM, signing key or new distro CI lane is
claimed for this release. `v0.8.1` is a prompt/editor/update polish release; it
changes none of the three tracked pin files either:
`git diff v0.8.0..v0.8.1 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.8.2` adds the Tree-sitter Neovim 0.12
shim, consolidates Telescope mappings and removes Dependabot; it changes none
of the three tracked pin files either:
`git diff v0.8.1..v0.8.2 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.8.5` is a Telescope cosmetic release;
it changes none of the three tracked pin files either:
`git diff v0.8.2..v0.8.5 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.8.6` fixes installation over existing
destination paths and changes the statusline lineinfo ink; it changes none of
the three tracked pin files either:
`git diff v0.8.5..v0.8.6 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). `v0.8.6` was tagged but never released: its
macOS test lane failed under Bash 3.2. `v0.8.7` fixes that portability bug and
keeps the same link/statusline changes; the published `v0.8.6` tag was not
moved. The pin files are still unchanged:
`git diff v0.8.5..v0.8.7 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
is empty (checked before tagging). GitHub Actions remain pinned manually.

| Artifact | Pin | Verified by |
|---|---|---|
| `runtime/mise.toml` | `node = "24"`, `python = "3.14"` (pnpm `latest` by policy) | `yadr runtime list`, E2E matrix |
| `nvim/lazy-lock.json` | exact commits per plugin | `Lazy! restore` is a no-op on clean checkout; `doctor` lock check |
| `terminal/fonts/manifest.env` | URL + `YADR_FONT_SHA256` | `platform/*` verify SHA before unzip |
| mise installer | `2026.10.15` + SHA-256 | `install_mise` verifies before `sh`; runs with `MISE_VERSION` |
| zoxide Linux tarballs | `0.10.0` + SHA-256 per arch | `install_zoxide` verifies before extraction |
| Neovim Linux tarballs | `v0.12.6` + SHA-256 per arch | `ensure_nvim` verifies before extraction |
| lazygit tarball fallback | `0.66.2` + SHA-256 for linux/darwin x86_64/arm64 | `install_tarball` verifies before extraction; package-manager builds stay rolling |
| zsh plugin XDG fallback | syntax `0.8.0` → `db085e46…`; autosuggestions `v0.7.1` → `e52ee8ca…` | `clone_xdg_plugin` compares `HEAD` with the pinned commit |

Package managers (apt/dnf/pacman/Homebrew/MacPorts) and Homebrew's own
installer are documented exceptions in `docs/supply-chain.md`: they are
rolling by design and use the platform's trust model. Direct artifacts YADR
downloads itself must be pinned and checksummed before tagging.
