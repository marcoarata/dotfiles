# E2E evidence report

How YADR 2027 is proven to work. Evidence over prose: every claim below links a
reproducible run. Last verified: 2026-10-25.

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
| `v0.6.2` | `d5b1947` | 0.6.2 | 10 links, 0 pending | 0 errors / 3 warnings (+1 with a foreign link) | doctor counts rogue/foreign notices; apt/dnf drop `neovim` |
| `v0.6.3` | `8e39d5d` | 0.6.3 | 10 links, 0 pending | 0 errors / 3 warnings (+1 with a foreign link) | install plans first (`--dry-run`/`plan`); update phases; unowned `nvim-upstream` kept |
| `v0.7.0` | `f34adb1` | 0.7.0 | 10 links, 0 pending | 0 errors / 7 warnings (9→8 after `nvim`; 7 after lazygit) | `installed-ref` + doctor commit; pinned mise/zoxide/neovim/lazygit verified |
| `v0.8.1` | `1e3790a` | 0.8.1 | 10 links, 0 pending | 0 errors / 9 warnings (8 after `nvim`) | prompt ahead/behind + `✘`; `cursorline`; confirmed `mise` upgrade |
| `v0.8.2` | `e7cd2b6` (tag adds docs) | 0.8.2 | 10 links, 0 pending | 0 errors / 9 warnings (8 after `nvim`; 7 after Tree-sitter parsers) | HTML/Markdown/Bash injections clean on Neovim 0.12; no `tree-sitter` CLI; shim unit test |

`v0.6.1` (docs-only) was verified the same way on 2026-10-19: the clone is
detached at `a880ba0`, `VERSION` and both `yadr version`/`--version` print
`0.6.1`, `install core` is idempotent (10 links, 0 pending), `doctor` reports
0 errors with the same 6→4 warning set, and a link check over the cloned
README/docs resolves every file and anchor. `INSTALL-YADR.md` and the four
folded ADRs are absent from the tag.

> **Update (2026-10-19):** the runs were reviewed afterwards — `ci` is green on
> the release commit (`a880ba0`, run 39316124354) and on the post-tag commit
> (`1c80a13`, run 39318747340). `a880ba0` is the commit the `v0.6.1` tag names.

`v0.6.2` was verified the same way on 2026-10-19: the clone is detached at
`d5b1947`, `VERSION` and both `yadr version`/`--version` print `0.6.2`, `install
core` is idempotent (10 links, 0 pending), and `doctor` reports 0 errors with 3
warnings. Re-pointing one managed link outside the clone (`aliases.zsh` →
`/tmp/not-yadr`) adds exactly one warning (3 → 4) and the aggregate `rogue
checkout/symlinks` line, proving the doctor counts the notices it prints. The
cloned `platform/linux.sh` has `neovim` out of `APT_PKGS`/`DNF_PKGS` and keeps it
in `PAC_PKGS`.

> **Update (2026-10-19):** `ci` is green on the release commit (`d5b1947`, run
> 39326365131, 8/8 jobs: `lint`, `test`/`install` on Ubuntu and macOS,
> `arch-container`, `fault-injection`, `coverage`) and on the post-tag commit
> (`71cc1d6`, run 39327307697, 8/8). Tags do not trigger CI, so the release-commit
> run is the one the `v0.6.2` tag names.

`v0.6.3` was verified the same way on 2026-10-19: the clone is detached at
`8e39d5d`, `VERSION` and both `yadr version`/`--version` print `0.6.3`, and
`install core` is idempotent (10 links, 0 pending; the second run exits 0).
`doctor` reports 0 errors with 3 warnings; re-pointing `aliases.zsh` to
`/tmp/not-yadr` adds exactly one aggregate warning (3 → 4) and the
`rogue checkout/symlinks` line, and restoring the link returns to 3. `yadr plan`
leaves the file count unchanged (5000 → 5000) while printing the platform,
runtimes, 10 links and backup path. The tagged tree carries `managed_pair_count`,
`claim_owned_dir` (used by `ensure_nvim`), the two-phase `update` message and
`plan` in the usage and the three completions. Pinned artifacts are unchanged
since `v0.6.2` (`git diff v0.6.2..v0.6.3 -- runtime/mise.toml
nvim/lazy-lock.json terminal/fonts/manifest.env` is empty). The isolated run had
no non-interactive `sudo`, so the apt step was skipped with a warning (the host
already has the packages); links, completions, the upstream nvim and `doctor`
were verified.

> **Update (2026-10-19):** `ci` is green on the tagged commit (`8e39d5d`, run
> 39334849805, 8/8 jobs: `lint`, `test`/`install` on Ubuntu and macOS,
> `arch-container`, `fault-injection`, `coverage`). The first v0.6.3 run
> (`d734c38`) failed only `coverage`: the plan/cancel tests lived in
> `fault.bats`, which that lane does not run, so the new code did not count and
> the job sat on the 50% floor (50.2% locally, below it on the runner). Moving
> them to `shell.bats` raised coverage to 52.2%. Tags do not trigger CI, so the
> tagged-commit run is the one the `v0.6.3` tag names. The post-tag commit
> (`e495578`) is also green (run 39335813649, 8/8).

`v0.7.0` was verified on 2026-10-19 from the published tag: the clone is
detached at `f34adb1`, `VERSION` and both `yadr version`/`--version` print
`0.7.0`, `yadr plan` reports `diff: 0 with changes` over 10 links, and `install
core` is idempotent. The isolated run had no non-interactive `sudo`
(a stub failed every privilege call), so the apt step was skipped with a
warning; the pinned path still installed `mise 2026.10.15 linux-x64`,
`zoxide 0.10.0`, `NVIM v0.12.6` and the Nerd Font. `yadr install lazygit
--yes` then exercised the tarball fallback (the manager lacked lazygit) and
installed `lazygit 0.66.2` (`build source=binaryRelease`). `doctor` reported
0 errors with 9 warnings, 8 after the first nvim start and 7 after lazygit
(git identity, node/npm/pnpm, python, LSP servers, treesitter parsers); the
first line was `✓ commit f34adb17804a (v0.7.0, 0.7.0)`.

R5 left a `0600` `installed-ref` under the moved state dir with
`sha=f34adb17804a143483f44dcce7c4202423d1d0dc`, `ref=v0.7.0`,
`tag=v0.7.0`, `branch=HEAD`, `version=0.7.0`,
`origin=https://github.com/marcoarata/dotfiles.git` (no credentials) and a UTC
`recorded` timestamp. The tag's tree carries the pinned download constants and
SHA-256 checks; `git diff v0.6.3..v0.7.0 -- runtime/mise.toml
nvim/lazy-lock.json terminal/fonts/manifest.env` is empty. The tagged-commit
CI run is green 8/8 (run 39354009595); tags do not trigger CI, so that is the
run the `v0.7.0` tag names.

`v0.8.1` was verified on 2026-10-25 from the published tag: the clone is
detached at `1e3790a`, `VERSION` and `yadr version` print `0.8.1`,
`install core` is idempotent (`diff: 0 with changes`, 10 links), and the first
line of `doctor` is `✓ commit 1e3790affcc7 (v0.8.1, 0.8.1)`. The isolated
run used a `sudo` stub so apt was skipped; the pinned path installed
`mise 2026.10.15`, `zoxide 0.10.0`, `NVIM v0.12.6` and the Nerd Font.
`doctor` reported 0 errors with 9 warnings, 8 after the first `nvim` start
(plugins installed on that pass). `installed-ref` records
`sha=1e3790affcc797b9a447be770d21d6516091fa6e`, `ref=v0.8.1`,
`tag=v0.8.1`, `branch=HEAD`, `version=0.8.1`, the credential-free GitHub
origin and a UTC timestamp. The tagged-commit CI run is green 8/8
(run 40248789127); tags do not trigger CI, so that is the run the `v0.8.1`
tag names.

`v0.8.2` was verified on 2026-10-25 from a local clone checked out at the code
commit `e7cd2b6`; the tagged commit adds only this evidence report and the
release documentation. `VERSION` and `yadr version` print `0.8.2`,
`install --local` created 10 links and `yadr diff` reports `0 with changes`.
The isolated run used a `sudo` stub, so apt was skipped. `doctor` reported 0
errors with 9 warnings, 8 after the first `nvim` start, and 7 after the
Tree-sitter parsers were installed. `command -v tree-sitter` stayed empty;
`:TSInstallSync` compiled `html`, `markdown`, `markdown_inline`, `bash`,
`javascript` and `css` with `cc`. Headless `treesitter.start()` on HTML,
Markdown and Bash fixtures produced no `attempt to call method 'range'` or
`Decoration provider` errors. The shim unit test prints `treesitter-compat:
ok`; the full suite is 137 tests, smoke is 89/89, core coverage is 56.8%
(610/1073) and shellcheck is clean. `installed-ref` records
`sha=e7cd2b6999380c3d890b95642ca54c3eeda4a082`, `ref=detached`,
`version=0.8.2`, `nvim/lazy-lock.json` is unchanged from `v0.8.1`, and the
GitHub origin is credential-free. The post-tag install records the published
tag itself; that log and the tagged-commit CI run are in the release notes.

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
