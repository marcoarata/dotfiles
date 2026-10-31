# E2E evidence report

How YADR 2027 is proven to work. Every claim below maps to a reproducible
command. Last local verification: 2026-10-31.

## 1. CI matrix (`.github/workflows/ci.yml`)

Runs on every `main` push and PR. The release commit must be green in every
lane before a tag is created.

| Job | Runs on | What it proves |
|---|---|---|
| `lint` | Ubuntu | `shellcheck -S warning` + `zsh -n` + `bash -n` clean |
| `test` | Ubuntu, macOS | `smoke.sh` + `bats` (`shell.bats`, `bootstrap.bats`) on both OSes |
| `coverage` | Ubuntu | line coverage of `bin/` from the bats suite, against a floor |
| `fault-injection` | Ubuntu | injected failures fail loudly, never print success for work not done |
| `arch-container` | Arch | suites + real core install + `doctor` (pacman), plus a second install with moved `XDG_*` |
| `install` | Ubuntu, macOS | core install in an isolated HOME + `doctor` exit 0 + idempotent reinstall |

The Arch lane earns its place by failing first: it exposed a `python3` fixture
dependency, a `fail` helper bats-core does not ship, `cmp` from diffutils and a
`set -e` trap in a platform script. GitHub keeps job logs behind a login, so the
bats step re-emits failing tests as annotations.

Graceful paths are covered in isolated `HOME`/`YADR_HOME`: `uninstall --purge`
(managed links go; user files and pre-existing shared data stay), an unreachable
font source (no leftovers), `do_update` without a checkout (warns, exit 0), and
`tests/fault.bats` (broken runtime/editor/network/cache/snapshots, no success
lines). WSL is covered at the logic level (platform selection + clipboard
branches); `platform/wsl.sh` delegates to `linux.sh`.

## 2. v0.9.5 maintenance coverage

The release fixes four failure modes and adds regressions for each:

- state pointers and completion writes use exclusive `mktemp` files;
- install, manual, update and migrate backups use unique directories;
- a failed managed-symlink replacement restores the previous link;
- a failed macOS plugin swap restores the previous checkout.

The shell suite runs on Bash 3.2 in the macOS CI lane and Bash 5.x on Linux.
Local Linux verification for this release: smoke 90/90, shell 131/131,
bootstrap 10/10, fault 19/19, core coverage 62.0% (floor 50%), shellcheck clean,
and both Neovim harness scripts print `ok`.

```sh
bash tests/smoke.sh
bats tests/shell.bats
bats tests/bootstrap.bats
bats tests/fault.bats
bash tests/coverage.sh
```

## 3. Isolated install

The standard manual check uses a throwaway `HOME` and a copy of the checkout:

```sh
HOME=/tmp/fake-home YADR_HOME=/tmp/yadr-checkout ./bootstrap.sh --local --yes
HOME=/tmp/fake-home /tmp/yadr-checkout/bin/yadr doctor
```

A moved-XDG check sets `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` and
`XDG_STATE_HOME` under `/tmp` and verifies that links, completions and Neovim's
`stdpath()` agree. `~/.gitconfig` and `~/.tmux.conf` stay HOME-based (ADR-005).

## 4. Published tags

Each release is installed from its tag, never from `main`:

```sh
E=/tmp/opencode/verify
YADR_HOME=$E/home/.yadr-2027 HOME=$E/home XDG_CONFIG_HOME=$E/config \
  XDG_DATA_HOME=$E/data XDG_CACHE_HOME=$E/cache XDG_STATE_HOME=$E/state \
  bash bootstrap.sh --ref v0.9.5 --yes
```

The tag must print `0.9.5` from `yadr version`, report 0 errors from
`yadr doctor`, and record the tag in `installed-ref`. Tag verification and the
CI run for the release commit are recorded in the release notes.

## 5. Reproduce

```sh
bash tests/smoke.sh
bats tests/shell.bats                     # needs bats-core, zsh, git
bats tests/fault.bats                     # injected failures
bash tests/coverage.sh                    # coverage floor for bin/
HOME=/tmp/fake-home YADR_HOME=<copy> ./bootstrap.sh --local --yes
HOME=/tmp/fake-home ./bin/yadr doctor     # 0 errors; warnings name what this machine lacks
```

`docs/evaluation.md` lists the command behind each claim and the limits this
release does not claim. `doctor`/`diff`/`backup`/`theme`/`uninstall --dry-run`
are safe anytime; nothing touches a real `$HOME` when `HOME` points elsewhere.

**An isolated `HOME` is not isolation on its own:** the host's `XDG_*` leak, so
`nvim` and `doctor` can read the real `~/.local/share/nvim` unless the variables
are pointed under `/tmp` too. The suites unset `XDG_*`/`ZDOTDIR` in `setup()`;
the XDG run sets them deliberately.
