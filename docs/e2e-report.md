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
| `arch-container` | Arch (`archlinux:latest`) | the unit suites *and* a real core install + `doctor` inside the distro (pacman branch), plus a second real install with moved `XDG` directories and `doctor` against it (`§7`) | green |
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
  That last one is the fix released in v0.3.1: the hint did not name the most
  likely cause.

> **v0.3.1, verified the same way (2026-10-18).** The tag was cloned detached
> (`cloning … @ v0.3.1`, `VERSION` 0.3.1), `yadr install core` restored the
> pinned plugins (`✓ plugins match the lock`, `✓ no orphans`), and `yadr doctor`
> reported **0 errors / 4 warnings** (git identity, the two distro zsh plugins,
> the LSP servers — the same honest machine-local set, with the plugin warning
> gone). This run also moved `XDG_*` under `/tmp`, so it doubles as the
> tag-side of §7: the "clone into …" hint pointed at
> `<E>/data/yadr-plugins/`, the directory the tools actually read.

An isolated `HOME` is not isolation on its own: the host session's `XDG_*`
variables leak, so `nvim` and `doctor` looked at the real
`~/.local/share/nvim` until `XDG_CONFIG_HOME`/`XDG_DATA_HOME` were pointed
under `/tmp` as well. Worth knowing before trusting a "clean HOME" run. That
leak is also what the suites were fixed to avoid in v0.3.1 (they `unset
XDG_*`/`ZDOTDIR` in `setup()`); §7 uses the leak deliberately, as the test
environment.

## 7. A real install with moved XDG directories (2026-10-18, v0.3.1)

The environment ADR-005 exists for: a desktop session that exports `XDG_*`
(and a user who moved them). Everything runs under `/tmp`; the variables point
*into* the isolated tree, which is the interesting case.

```sh
REPO=$PWD; E=/tmp/opencode/xdg-e2e
export HOME=$E/home XDG_CONFIG_HOME=$E/config XDG_DATA_HOME=$E/data \
       XDG_CACHE_HOME=$E/cache XDG_STATE_HOME=$E/state
YADR_HOME=$REPO bash bootstrap.sh --local --yes
```

- The install links follow the tools, not `$HOME`:

  ```text
  $E/config/nvim              -> $REPO/nvim
  $E/config/mise/config.toml  -> $REPO/runtime/mise.toml
  $E/config/yadr/aliases.zsh  -> $REPO/shell/aliases.zsh
  $E/home/.gitconfig          -> $REPO/git/gitconfig      (git reads it anyway)
  $E/home/.tmux.conf          -> $REPO/tmux/tmux.conf     (tmux reads it anyway)
  ```

  Nothing is left in the un-moved location (`$HOME/.config/nvim` does not
  exist), and Neovim's own resolution agrees with the links:

  ```sh
  $ nvim --clean --headless -c 'lua io.write(vim.fn.stdpath("config") .. " " .. vim.fn.stdpath("data"))' -c qa
  /tmp/opencode/xdg-e2e/config/nvim /tmp/opencode/xdg-e2e/data/nvim
  ```

- **The silent skip is gone.** Before the fix, `ensure_nvim_plugins` gated on
  `$HOME/.local/share/nvim/lazy/lazy.nvim`; in this tree that path does not
  exist while `$XDG_DATA_HOME/nvim/lazy/lazy.nvim` does, so the restore
  returned 0 without a word. After the first `nvim` start (which bootstraps
  lazy and the 25 pinned plugins) a second `yadr install core` prints the work
  it used to hide:

  ```text
  » restoring Neovim plugins to lockfile (Lazy! restore)…
  ✓ plugins match the lock.
  » cleaning orphan plugins (Lazy! clean)…
  ```

- **The warning that could never be cleared now clears.** `yadr doctor`
  before that first `nvim` start: `0 errors, 7 warnings`, including
  `⚠ neovim plugins not installed`. After it: `0 errors, 5 warnings`, with
  `✓ nvim plugins (lockfile OK)` and `✓ treesitter (parsers nvim)`, and the
  remaining warnings are the honest machine-local ones (two distro-provided zsh
  plugins, no `sudo` here; LSP servers, `yadr install typescript` not run; git
  identity in an isolated `HOME`; and a dirty checkout, because the run was
  made from the working tree before the release commit).
- Caveats, stated rather than implied: the run inherits the host's `PATH`, so
  `fd` resolves to the host's mise shim (the Linux `fd/fzf` packages need
  `sudo`, which this machine does not have); and this is one machine, one
  distro — the moved-`XDG` install also runs in the `arch-container` lane.

## 8. Shell completions, installed and removed (2026-10-18, v0.4.0)

`yadr completion` is new; what matters is that a plain install writes the three
files where each shell reads them, and that `uninstall` takes them back.

```sh
E=/tmp/opencode/comp-install
env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
  HOME="$E/home" YADR_HOME="$PWD" PATH=/usr/bin:/bin bash bootstrap.sh --local --yes
```

- The install reports and writes exactly three files, all under `$HOME`'s XDG
  defaults (the run unsets the host's `XDG_*` on purpose):

  ```text
  » shell completions installed: 3 (bash, zsh, fish)
  .local/share/bash-completion/completions/yadr     1316 bytes
  .local/share/zsh/site-functions/_yadr               979 bytes
  .config/fish/completions/yadr.fish                 2682 bytes
  ```

- `yadr uninstall --yes` removes exactly those files (nothing else in those
  directories existed to begin with, and the now-empty dirs go too):

  ```text
  »   removed: .../.local/share/bash-completion/completions/yadr
  »   removed: .../.local/share/zsh/site-functions/_yadr
  »   removed: .../.config/fish/completions/yadr.fish
  ✓ uninstall complete. Restart your terminal.
  ```

- Each script parses in its own shell (`bash -n`, `zsh -n`; `fish
  --no-execute` is skipped here because this machine has no fish — the bats
  test guards it and CI's Ubuntu image has no fish either, so the fish syntax
  check runs wherever fish exists, never as a silent pass).
- Caveat, stated: the first attempt at this run did **not** unset the host's
  `XDG_*`, and the completions landed in the real `~/.local/share` and
  `~/.config` — the same leak §5 warns about, seen from the writing side. The
  files were removed by hand; the command above is the one that is correct.

> **`v0.4.1`, verified the same way (2026-10-18).** The patch changes no
> shipped code, so this run confirms the tag rather than re-testing the
> feature: `bootstrap.sh --ref v0.4.1` cloned the tag detached (`VERSION`
> 0.4.1, `cloning … @ v0.4.1`) with the `XDG_*` variables moved, `install
> core` wrote the three completion files under the relocated directories
> (nothing under the un-moved ones), and `yadr doctor` reported **0 errors**
> (6 warnings, the state before the first `nvim` start). `v0.4.0`'s tag, by
> contrast, had two CI jobs red — the completion tests used `diff`/`cmp`
> (absent on Arch) and the CI assertion assumed the default `XDG_CONFIG_HOME`
> — which is why this patch exists; see the correction in
> `docs/evaluation.md`.

## 9. The published `v0.5.0` tag, verified after the fact (2026-10-19)

Not the local checkout: `v0.5.0` itself, fetched and installed the way the
installer documents it, with the `XDG_*` variables moved under `/tmp` (the case
ADR-005 exists for).

```sh
E=/tmp/opencode/v050-verify
HOME=$E/home XDG_CONFIG_HOME=$E/config XDG_DATA_HOME=$E/data \
  XDG_CACHE_HOME=$E/cache XDG_STATE_HOME=$E/state \
  bash bootstrap.sh --ref v0.5.0 --yes
```

- The clone is a detached `HEAD` on the tagged commit (`git describe` → `v0.5.0`,
  `rev-parse --short HEAD` → `0947ec8`) and `VERSION` says `0.5.0`; `yadr version`
  prints `0.5.0`.
- `yadr install core` linked 10 pairs under the moved `XDG` directories and wrote
  the three completion files; a second run is idempotent (10 links, 0 pending
  from the repo).
- `yadr doctor` reported **0 errors, 6 warnings** before the first `nvim` start
  (the honest machine-local set: no git identity in an isolated `HOME`; no LSP
  servers, since `yadr install typescript` was not run; and the two
  distro-provided zsh plugins, with no `sudo` on this machine), and **0 errors,
  4 warnings** after it — the plugin warning cleared (`✓ nvim plugins (lockfile
  OK)`, `✓ treesitter (parsers nvim)`).
- Under the moved `XDG` directories the second `install core` prints the plugin
  restore it used to hide (`» restoring Neovim plugins to lockfile`,
  `✓ plugins match the lock`, `» cleaning orphan plugins` … `✓ no orphans`), the
  behaviour §7 records for `v0.3.1`.
- This is the tag `docs/evaluation.md` scores: the command removals land here
  (`export`/`apply` and `pack` are gone from `yadr --help`), and it is the tag
  whose eight CI jobs are green.

## 10. The published `v0.6.0` tag, verified after the fact (2026-10-19)

`v0.6.0` adds `yadr --version`, renders the Damoekri `RPROMPT` git and runtime
segments in bold, and moves the Nerd Font note under the installation steps.
It is verified the same way as §9, cloning the tag itself into a fresh
`YADR_HOME` under `/tmp` (with the `XDG_*` variables moved, the case ADR-005
exists for):

```sh
E=/tmp/opencode/v060-verify
YADR_HOME=$E/home/.yadr-2027 HOME=$E/home XDG_CONFIG_HOME=$E/config \
  XDG_DATA_HOME=$E/data XDG_CACHE_HOME=$E/cache XDG_STATE_HOME=$E/state \
  bash bootstrap.sh --ref v0.6.0 --yes
```

- The clone is a detached `HEAD` on the tagged commit (`git describe` → `v0.6.0`,
  `rev-parse --short HEAD` → `d2f7317`) and `VERSION` says `0.6.0`; `yadr version`
  and `yadr --version` both print `0.6.0`.
- `yadr install core` linked 10 pairs under the moved `XDG` directories and wrote
  the three completion files; a second run is idempotent (10 links, 0 pending
  from the repo).
- `yadr doctor` reported **0 errors, 6 warnings** before the first `nvim` start
  (no LSP servers, since `yadr install typescript` was not run, and the two
  distro-provided zsh plugins, with no `sudo` on this machine) and **0 errors,
  4 warnings** after it — the plugin warning cleared (`✓ nvim plugins (lockfile
  OK)`, `✓ treesitter (parsers nvim)`). The set matches §9.
- No pinned artifact changed between `v0.5.0` and `v0.6.0`:
  `git diff v0.5.0..v0.6.0 -- runtime/mise.toml nvim/lazy-lock.json terminal/fonts/manifest.env`
  is empty.
- Local suites on the release revision are green (`smoke` 91/0, 100 bats tests,
  `shellcheck -S warning` clean). **CI is not claimed green here**: the run for
  the release commit could not be read when this was written (the unauthenticated
  GitHub API was rate-limited and the runner queue was backed up); the run on
  `main` must be reviewed before the tag is called CI-verified.
