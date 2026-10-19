# E2E evidence report

How YADR 2027 is proven to work. Evidence over prose: every claim below links a
reproducible run. Last verified: 2026-10-19.

## 1. CI matrix (GitHub Actions, `.github/workflows/ci.yml`)

Runs on every `main` push + PR. All six job definitions (eight runner instances)
are green on the `main` commit this file was last updated from;
`docs/releases.md` documents what each one blocks before a tag.

| Job | Runs on | What it proves |
|---|---|---|
| `lint` | Ubuntu | `shellcheck -S warning` + `zsh -n` + `bash -n` clean |
| `test` | Ubuntu, macOS | `smoke.sh` + `bats` (`shell.bats`, `bootstrap.bats`) on both OSes |
| `coverage` | Ubuntu | line coverage of `bin/` from the bats suite, against a floor |
| `fault-injection` | Ubuntu | injected failures fail loudly, never print success for work not done (`tests/fault.bats`) |
| `arch-container` | Arch | the suites + a real core install + `doctor` (pacman), plus a second install with moved `XDG_*` (links and completions) |
| `install` | Ubuntu, macOS | core install in an isolated HOME + `doctor` exit 0 + idempotent reinstall |

The Arch lane earned its place by failing first: it exposed a `python3` fixture
dependency, a `fail` helper bats-core does not ship, `cmp` from diffutils
(absent from Arch's base) and a `set -e` trap in a platform script. GitHub keeps
job logs behind a login, so the bats step re-emits failing tests as annotations.
History: the first green run followed 4 diagnosed test-only defects (CWD assumed
outside repos, shared `TEST_HOME`, `command cd` on zsh 5.8, a masked missing zsh).

Graceful paths are covered in isolated `HOME`/`YADR_HOME`: `uninstall --purge`
(managed links go; user files and pre-existing shared data stay), an unreachable
font source (no leftovers), `do_update` without a checkout (warns, exit 0), and
`tests/fault.bats` (broken runtime/editor/network/cache/snapshots, no success
lines). WSL is covered at the logic level (platform selection + clipboard
branches): a hosted Windows+WSL runner is slow and flaky, and `platform/wsl.sh`
delegates to `linux.sh`. The WSL path was also exercised end-to-end on
2026-10-17 in a real Windows 11 guest (WSL 2, nested VT-x): node 24.22.0 via
mise, `doctor` 0/0. WSL 1 fails for a host-side reason (Node ≥23 cannot
`execve`, microsoft/WSL#8151) — documented, not worked around.

## 2. Ephemeral Ubuntu 24.04 VM (quickemu, 2vCPU/4GB, all under `/tmp`)

Isolated HOME, project copied in, `--local` mode: `bootstrap --local --yes`,
`doctor` ×2, `diff`, `theme list|use|current` (invalid rejected, env override
wins), `install node|python|lazygit|typescript` (fast path), `install core`
again (idempotent), final `doctor`, `smoke.sh`, `benchmark shell|cd|prompt`.
Result: **19/19** (17 direct + 2 early `doctor` exits explained: cloud-init held
the apt lock so `rg`/`fd` were missing; a later profile re-ran cleanly and
`doctor` finished 0/0, re-verified twice). VM destroyed; no residues.

## 3. Visual matrix (4 platforms × main/check + light/dark/none)

Reviewed captures (temporary, since removed): Ubuntu 24.04 Intel, Zorin 17.3/22.04
Intel, Apple Silicon M2/Sequoia iTerm2, Apple Intel Ventura/iTerm2 (MacPorts
Tier-3 path). Damoekri prompt + runtime segment, `node v24.21.0` + `python
3.14.8` via mise, 15-point statusline per reference, transparent `none` default,
classic `"f" NL, NB` message line. Apple Silicon closed the never-tested
milestone; Intel validated the MacPorts fallback on real hardware.

## 4. Byte-level proofs (no-trust-me checks)

- `flatten()` output of `yadr.vim` verified against real lightline.vim:
  per-mode smoke-on-color groups exactly per spec.
- Emitted SGR bytes captured on-VM per statusline cell match `:hi` groups;
  `TestFG` red-on-blue proved faithful terminal rendering.
- The historical inversion was `StatusLine`/`StatusLineNC` `reverse` from
  solarized8 (SGR 7 on all 38 cells); `colorscheme.lua` clears it — verified
  zero `0;7` afterwards.

## 5. How to reproduce

```bash
bash tests/smoke.sh
bats tests/shell.bats                     # needs bats-core, zsh, git
bats tests/fault.bats                     # injected failures
bash tests/coverage.sh                    # coverage floor for bin/
HOME=/tmp/fake-home YADR_HOME=<copy> ./bootstrap.sh --local --yes
HOME=/tmp/fake-home ./bin/yadr doctor     # 0 errors; warnings name what this machine lacks
```

`docs/evaluation.md` is the ledger: rubric, score history and the command behind
every claim (including the limits this release does not claim). `doctor`/`diff`/
`backup`/`theme`/`uninstall --dry-run` are safe anytime; nothing below touches a
real `$HOME` when `HOME` points elsewhere.

## 6. Published tags, verified after the fact

Each tag is cloned detached (never the local checkout) and installed the way the
installer documents it; `bootstrap.sh --ref vX.Y.Z` refuses to continue unless
the checkout's `VERSION` equals the tag. The most recent protocol:

```sh
E=/tmp/opencode/v060-verify
YADR_HOME=$E/home/.yadr-2027 HOME=$E/home XDG_CONFIG_HOME=$E/config \
  XDG_DATA_HOME=$E/data XDG_CACHE_HOME=$E/cache XDG_STATE_HOME=$E/state \
  bash bootstrap.sh --ref v0.6.0 --yes
```

| Tag | Commit | `yadr version` | `install core` | `doctor` | Note |
|---|---|---|---|---|---|
| `v0.3.0` | tag | 0.3.0 | plugins restored | 0 errors | the `git/gitconfig` hint was vague; fixed in v0.3.1 |
| `v0.3.1` | tag | 0.3.1 | plugins match the lock, no orphans | 0 errors / 4 warnings | `XDG_*` moved under `/tmp`; tag-side of the XDG case |
| `v0.4.0` | tag | 0.4.0 | 3 completions written | 0 errors | two CI jobs red on Arch; fixed in v0.4.1 |
| `v0.4.1` | tag | 0.4.1 | 3 completions under the moved XDG dirs | 0 errors / 6 warnings | confirms the tag; no shipped code changed |
| `v0.5.0` | `0947ec8` | 0.5.0 | 10 links, 0 pending; 3 completions | 0 errors (6→4 warnings after `nvim`) | `export`/`apply`/`pack` removed |
| `v0.6.0` | `d2f7317` | 0.6.0 | 10 links, 0 pending | 0 errors (6→4 warnings) | `yadr --version`, bold RPROMPT |
| `v0.6.1` | `a880ba0` | 0.6.1 | 10 links, 0 pending | 0 errors (6→4 warnings) | docs-only: README is the single entry, `INSTALL-YADR.md` and ADR-001..004 removed; every link resolves |

`v0.6.1` (docs-only) was verified the same way on 2026-10-19: the clone is
detached at `a880ba0`, `VERSION` and both `yadr version`/`--version` print
`0.6.1`, `install core` is idempotent (10 links, 0 pending), `doctor` reports
0 errors with the same 6→4 warning set, and a link check over the cloned
README/docs resolves every file and anchor. `INSTALL-YADR.md` and the four
folded ADRs are absent from the tag.

> **Update (2026-10-19):** the runs were reviewed afterwards — `ci` is green on
> the release commit (`a880ba0`, run 39316124354) and on the post-tag commit
> (`1c80a13`, run 39318747340). `a880ba0` is the commit the `v0.6.1` tag names.

The moved-`XDG` install is the case ADR-005 exists for: links follow the tools
(`$E/config/nvim`, `$E/config/mise/config.toml`, `$E/config/yadr/*.zsh`), while
`$E/home/.gitconfig` and `$E/home/.tmux.conf` stay HOME-based; nothing is left
in the un-moved location and Neovim's `stdpath()` agrees. A second `install core`
prints the plugin restore it used to hide, and `doctor` drops from 6 to 4
warnings after the first `nvim` start (`✓ nvim plugins (lockfile OK)`,
`✓ treesitter`). Caveats: the run inherits the host `PATH` (so `fd` may be the
host's mise shim) and it is one machine, one distro — the same install runs in
the `arch-container` lane.

The completions install writes exactly three files
(`.local/share/bash-completion/completions/yadr`,
`.local/share/zsh/site-functions/_yadr`, `.config/fish/completions/yadr.fish`);
`uninstall` removes exactly those. Each script parses in its own shell; the fish
syntax check runs only where `fish` exists, never as a silent pass.

**An isolated `HOME` is not isolation on its own:** the host's `XDG_*` leak, so
`nvim` and `doctor` can read the real `~/.local/share/nvim` unless the variables
are pointed under `/tmp` too. The suites `unset XDG_*`/`ZDOTDIR` in `setup()`;
the XDG run sets them deliberately.
