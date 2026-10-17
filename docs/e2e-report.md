# E2E evidence report

How YADR 2027 is proven to work. Evidence over prose: every claim below
links a reproducible run. Last verified: 2026-10-17 (CI all green).

## 1. CI matrix (GitHub Actions, `.github/workflows/ci.yml`)

Runs on every `main` push + PR, Ubuntu + macOS:

| Job | What it proves | Status |
|---|---|---|
| `lint` | `shellcheck -S warning` + `zsh -n` + `bash -n` clean | green |
| `test` | `smoke.sh` + all `bats` (incl. `uninstall --purge` e2e and network-failure paths) green on both OSes | green |
| `install` | core install in isolated HOME + `doctor` exit 0 + idempotent reinstall | green |

History: the first green run followed 4 test failures with diagnosed
root causes (CWD assumed outside repos, shared `TEST_HOME` pollution,
`command cd` exit 127 on zsh 5.8, fallback masking a missing zsh) — all
fixed in `tests/shell.bats`, none in production code.

Graceful-failure paths are covered by `bats` in isolated `HOME`/`YADR_HOME`:
`uninstall --purge` end-to-end (managed symlinks go; user files and
pre-existing shared data stay; YADR-added share entries and the tools
`conf.d` fragment go; clone and state removed), `fetch_verified_zip` on an
unreachable source (no leftovers), and `do_update` without a git checkout
(warns, exits 0).

## 2. Ephemeral Ubuntu 24.04 VM (quickemu, 2vCPU/4GB, all under `/tmp`)

Full matrix with isolated HOME, project copied in, `--local` mode:

- `bootstrap --local --yes`, `doctor` ×2, `diff` (read-only)
- `theme list|use|current`, invalid rejected, env override wins
- `install node|python|lazygit|typescript` (fast path, no prompts/backup)
- `install core` again (idempotent), final `doctor`
- `smoke.sh`, `benchmark shell|cd|prompt` within thresholds

Result: **19/19** (17 direct passes + 2 early `doctor` exits explained:
cloud-init still held the apt lock so `rg`/`fd` were missing; a later
profile re-ran platform cleanly and `doctor` finished 0/0, re-verified
twice). VM destroyed afterwards; no residues.

## 3. Visual matrix (4 platforms × main/check + light/dark/none)

Reviewed captures (temporary evidence, since removed): Ubuntu 24.04
Intel, Zorin 17.3/22.04 Intel, Apple Silicon M2/Sequoia iTerm2, Apple
Intel Ventura/iTerm2 (MacPorts Tier-3 path). Damoekri prompt + runtime
segment, `node v24.21.0` + `python 3.14.8` via mise, 15-point statusline
per reference, transparent `none` default, classic `"f" NL, NB` message
line. Apple Silicon closed the never-tested milestone; Intel validated
the MacPorts fallback on real hardware.

## 4. Byte-level proofs (no-trust-me checks)

- `flatten()` output of `yadr.vim` verified against real lightline.vim:
  per-mode smoke-on-color groups exactly per spec.
- Emitted SGR bytes captured on-VM per statusline cell match `:hi`
  groups; `TestFG` red-on-blue proved faithful terminal rendering.
- Root-caused the historical inversion to `StatusLine`/`StatusLineNC`
  `reverse` from solarized8 (SGR 7 on all 38 cells); `colorscheme.lua`
  clears it — verified zero `0;7` afterwards.

## 5. How to reproduce

```bash
bash tests/smoke.sh
bats tests/shell.bats                     # needs bats-core, zsh, git
HOME=/tmp/fake-home YADR_HOME=<copy> ./bootstrap.sh --local --yes
HOME=/tmp/fake-home ./bin/yadr doctor     # expect 0 errors, 0 warnings
```

`doctor`/`diff`/`backup`/`theme`/`uninstall --dry-run` are safe to run
anytime (read-only or dry-run); nothing below touches a real `$HOME`
when `HOME` points elsewhere.
