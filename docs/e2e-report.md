# E2E evidence report

How YADR 2027 is proven to work. Evidence over prose: every claim below
links a reproducible run. Last verified: 2026-10-18 (CI all green).

## 1. CI matrix (GitHub Actions, `.github/workflows/ci.yml`)

Runs on every `main` push + PR:

| Job | Runs on | What it proves | Status |
|---|---|---|---|
| `lint` | Ubuntu | `shellcheck -S warning` + `zsh -n` + `bash -n` clean | green |
| `test` | Ubuntu, macOS | `smoke.sh` + `bats` (`shell.bats`, `bootstrap.bats`) green on both OSes | green |
| `coverage` | Ubuntu | line coverage of `bin/` measured from the bats suite, against a floor | green |
| `fault-injection` | Ubuntu | injected failures fail loudly and never print success for work that did not happen (`tests/fault.bats`) | green |
| `arch-container` | Arch (`archlinux:latest`) | the unit suites *and* a real core install + `doctor` inside the distro (pacman branch) | green |
| `install` | Ubuntu, macOS | core install in isolated HOME + `doctor` exit 0 + idempotent reinstall | green |

All six jobs are green on the `main` commit this file was last updated from;
`docs/releases.md` documents what each one blocks before a tag.

The Arch lane earned its place before it went green. Its first runs failed
and named, one at a time, four defects that a Debian-plus-macOS matrix had
tolerated: a test that needed `python3` to build a fixture (Arch's base has
none), a `fail` helper that bats-core does not ship (so assertions reported
`command not found` instead of their message), a byte comparison that used
`cmp` from diffutils (absent from Arch's `base`), and a `set -e` trap where
a failed `dirname`/`cd` aborted a platform script before its documented
"missing common.sh" warning could run. The lane also had to be made
diagnosable: GitHub keeps job logs behind a login, so the bats step now
re-emits failing tests and assertion lines as annotations, which are public.
A lane whose failures cannot be read is not evidence.

History: the first green run followed 4 test failures with diagnosed
root causes (CWD assumed outside repos, shared `TEST_HOME` pollution,
`command cd` exit 127 on zsh 5.8, fallback masking a missing zsh) — all
fixed in `tests/shell.bats`, none in production code.

Graceful-failure paths are covered by `bats` in isolated `HOME`/`YADR_HOME`:
`uninstall --purge` end-to-end (managed symlinks go; user files and
pre-existing shared data stay; YADR-added share entries and the tools
`conf.d` fragment go; clone and state removed), `fetch_verified_zip` on an
unreachable source (no leftovers), and `do_update` without a git checkout
(warns, exits 0). The dedicated lane in `tests/fault.bats` goes further:
it breaks a runtime, the editor, the network, the plugin cache and the
purge snapshots on purpose and asserts the absence of success lines.

WSL is covered at the **logic level** (platform selection from the version
string, and the three clipboard branches), not with a full runner. This is a
deliberate omission: GitHub-hosted Windows + WSL is slow and flaky, and
`platform/wsl.sh` mostly delegates to `linux.sh`, which the Ubuntu job
already exercises. Revisit only if a reliable hosted WSL runner appears.

The WSL path was additionally exercised end-to-end on 2026-10-17 in a real
Windows 11 guest (quickemu, WSL 2 with nested VT-x): `yadr install node`
installed node 24.22.0 via mise and `yadr doctor` finished **0 errors,
0 warnings**. The same install on **WSL 1** fails for a host-side reason
(official Node ≥23 cannot `execve` there, microsoft/WSL#8151); that case is
documented, not worked around in code: see `docs/troubleshooting.md`.

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
bats tests/fault.bats                     # injected failures
bash tests/coverage.sh                    # coverage floor for bin/
HOME=/tmp/fake-home YADR_HOME=<copy> ./bootstrap.sh --local --yes
HOME=/tmp/fake-home ./bin/yadr doctor     # expect 0 errors; warnings name what this machine lacks
```

`docs/evaluation.md` is the ledger: the rubric, the score history and the
command behind every claim (including the limits this release does not claim).

`doctor`/`diff`/`backup`/`theme`/`uninstall --dry-run` are safe to run
anytime (read-only or dry-run); nothing below touches a real `$HOME`
when `HOME` points elsewhere.

## 6. The published tag, verified after the fact (2026-10-18)

Not the local checkout: `v0.3.0` itself, fetched and installed the way the
installer documents it.

```sh
curl -fsSL https://raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh -o bootstrap.sh
HOME=/tmp/verify-home bash bootstrap.sh --ref v0.3.0 --yes
```

- The clone is a detached `HEAD` on the tagged commit, and `bootstrap.sh`
  refuses to continue unless the checkout's `VERSION` equals the tag name
  (`tests/bootstrap.bats` covers both directions).
- `yadr version` prints `0.3.0` -- the tag's version, not `main`'s.
- `yadr install core` inside that isolated `HOME` restored the pinned plugins
  (`✓ nvim plugins (lockfile OK)`, `✓ clean nvim startup`).
- `yadr doctor` reported **0 errors**. Its warnings were the honest ones: the
  two distro-provided zsh plugins (this machine has no `sudo`; the shell
  fallback clones them), the LSP servers (`yadr install typescript`, not run),
  and `git/gitconfig`, which this verification dirtied itself with a
  `git config --global` because `~/.gitconfig` is a symlink into the checkout.
  That last one is the fix recorded under `Unreleased` in the changelog: the
  hint did not name the most likely cause.

An isolated `HOME` is not isolation on its own: the host session's `XDG_*`
variables leak, so `nvim` and `doctor` looked at the real
`~/.local/share/nvim` until `XDG_CONFIG_HOME`/`XDG_DATA_HOME` were pointed
under `/tmp` as well. Worth knowing before trusting a "clean HOME" run.
