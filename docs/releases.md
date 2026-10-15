# Releases

How a YADR 2027 release is cut. No release exists until all boxes check.

## Process

1. Bump `VERSION` (`X.Y.Z`, semver: breaking installer/config change = major).
2. Sync pins from a clean checkout: open `nvim` once (`Lazy! restore` +
   `:Mason` per `packs/`), then `git diff -- nvim/lazy-lock.json` must
   contain only intended bumps. Commit the lockfile.
3. Green locally: `bash tests/smoke.sh`, `bats tests/shell.bats`,
   `shellcheck -S warning` on `bin/yadr bootstrap.sh platform/*.sh`,
   `yadr doctor` 0/0 on a fresh isolated HOME.
4. Tag annotated: `git tag -a vX.Y.Z -m "YADR 2027 vX.Y.Z"` + `git push origin main vX.Y.Z`.
5. Bootstrap installs `main` by default (`YADR_BRANCH` override exists);
   pin-sensitive users install from the tag instead of `main`.

## Pinned inventory (verify before tagging)

| Artifact | Pin | Verified by |
|---|---|---|
| `runtime/mise.toml` | `node = "24"`, `python = "3.14"` (pnpm `latest` by policy) | `yadr runtime list`, E2E matrix |
| `nvim/lazy-lock.json` | exact commits per plugin | `Lazy! restore` is a no-op on clean checkout; `doctor` lock check |
| `terminal/fonts/manifest.env` | URL + `YADR_FONT_SHA256` | `platform/*` verify SHA before unzip |
| `mise` backend itself | unpinned installer (`https://mise.run`) | `mise --version` in `runtime doctor`; pin on demand via `runtime/mise.toml` |

Anything downloaded without a pin or checksum is a release blocker:
list it here or pin it before tagging.
