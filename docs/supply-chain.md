# Supply chain and traceability

What YADR 2027 downloads, what it verifies, and what it trusts to a package
manager. A floating download is a decision, not an accident.

## Policy

- **Direct artifacts are versioned and SHA-256 verified.** Anything YADR
  downloads itself has a version and a checksum in the source. A mismatch is a
  hard failure, never a warning followed by a retry with the same bytes.
- **Scripts are verified before they run.** The mise installer is downloaded to
  a temporary file, checked against its pin, then executed with `sh` and
  `MISE_VERSION` set. It is not piped from the network.
- **Archives are verified before extraction.** zoxide, Neovim and the lazygit
  fallback are checked before `tar` sees them.
- **Git checkouts are pinned to a tag and an exact commit.** The commit
  comparison protects an existing zsh plugin checkout when a tag moves.
- **Package managers stay rolling.** apt, dnf, pacman, Homebrew and MacPorts
  install the vendor build under their own trust model. YADR does not verify
  those bytes.
- **The bootstrap is installed from a tag.** The documented path fetches
  `bootstrap.sh` from the exact release tag and the release publishes
  `SHA256SUMS`. `main` is development, not an install target.
- **GitHub Actions are pinned by full commit SHA.** A static test rejects tag or
  branch references.
- **`sudo` stays in one helper.** `platform/linux.sh` defines `priv()`; other
  scripts do not scatter bare `sudo` calls.

## Bootstrap trust

```sh
V=v0.9.8
curl -fsSLO "https://raw.githubusercontent.com/marcoarata/dotfiles/${V}/bootstrap.sh"
curl -fsSLO "https://github.com/marcoarata/dotfiles/releases/download/${V}/SHA256SUMS"
sha256sum -c SHA256SUMS          # macOS: shasum -a 256 -c SHA256SUMS
bash bootstrap.sh --ref "$V"
```

`bootstrap.sh` fetches and checks out the tag, verifies that `VERSION` matches
it, and records the revision before handing off to `yadr install`. The release
asset and the tagged file are the same bytes; the checksum proves integrity, not
publisher identity. The manual alternative — clone the tag and run
`bootstrap.sh --local --ref "$V"` — avoids `curl | sh` entirely.

## Inventory (v0.9.8)

Checksums are the SHA-256 of the exact asset named in the URL. The full hashes
live in the source constants; this is the human index.

| Artifact | Pin | Verified before | Where |
|---|---|---|---|
| Nerd Fonts zip | JetBrainsMono Nerd Font `3.5.1`, `fab782a6…d6396e` | unzip, after SHA | `terminal/fonts/manifest.env`; `fetch_verified_zip` |
| mise installer | `2026.10.15`, `79db94ae…4a70d0` | execution | `platform/linux.sh`; `install_mise` |
| zoxide (Linux x86_64) | `0.10.0`, `2d93385b…68b1ae` | extraction | `platform/linux.sh`; `install_zoxide` |
| zoxide (Linux arm64) | `0.10.0`, `f1f16c5d…3ef641` | extraction | same |
| Neovim (Linux x86_64) | `v0.12.6`, `474430d5…811d87` | extraction | `platform/linux.sh`; `ensure_nvim` |
| Neovim (Linux arm64) | `v0.12.6`, `8f1f64a0…04c815` | extraction | same |
| lazygit (Linux x86_64) | `0.66.2`, `158efc9d…c52034` | extraction | `platform/lazygit.sh`; `install_tarball` |
| lazygit (Linux arm64) | `0.66.2`, `79a3161e…5c41a4` | extraction | same |
| lazygit (Darwin x86_64) | `0.66.2`, `de5d3771…7517ab` | extraction | same |
| lazygit (Darwin arm64) | `0.66.2`, `fadda59a…f906a0c` | extraction | same |
| zsh-syntax-highlighting | tag `0.8.0`, commit `db085e46…dddf3e` | clone HEAD | `platform/macos.sh`; `clone_xdg_plugin` |
| zsh-autosuggestions | tag `v0.7.1`, commit `e52ee8ca…68d4eb` | clone HEAD | same |
| Neovim plugins | exact commits | `Lazy! restore` | `nvim/lazy-lock.json` |
| Node / Python | `24` / `3.14` | mise resolution | `runtime/mise.toml` |
| pnpm | `latest` (package-manager policy) | mise resolution | `runtime/mise.toml` |

`nvim-treesitter` remains on `master` at `cf12346a…`. Neovim 0.12 passes query
directive matches as lists of nodes, so YADR loads a local shim
(`nvim/lua/yadr/treesitter_compat.lua`) for HTML/Markdown injections and
`downcase!` heredocs. No `tree-sitter-cli` is downloaded or required; parser
builds use the C compiler.

### Platform paths

- **Linux:** pinned mise, zoxide and Neovim artifacts. Pacman's rolling
  `neovim` is accepted when it meets the `>=0.11` floor.
- **macOS:** Homebrew/MacPorts supply mise, zoxide, Neovim and lazygit. The
  lazygit fallback and the MacPorts zsh plugin clones use the pinned artifacts.
- **WSL:** follows the Linux path.

## Known exceptions

1. **Package managers.** apt/dnf/pacman/Homebrew/MacPorts bytes are rolling and
   verified by the platform's trust model.
2. **Homebrew's own installer.** If `brew` is absent on macOS, `ensure_brew()`
   runs the upstream installer unpinned. Preinstalling Homebrew (or using the
   MacPorts path) avoids it.
3. **`pnpm = "latest"` and `yadr install tools`.** Package-manager tools, not
   runtimes; projects pin their own versions.
4. **The bootstrap script itself.** A script cannot verify its own bytes before
   it runs. The release publishes `SHA256SUMS`; the checksum path above verifies
   it before `bash`, and the manual clone path avoids `curl | sh`.
5. **No reproducible build.** The inventory and static tests are the current
   record.

## Threat model

| Scenario | Mitigation |
|---|---|
| Upstream release replaced after the pin | SHA-256 mismatch stops the install |
| Moved git tag | clone HEAD compared with the pinned commit; old checkout kept |
| Mutable `main` bootstrap | install from the exact tag; `SHA256SUMS` published |
| MITM on HTTPS | TLS plus SHA-256 as the backstop |
| Compromised installer script | installer SHA-256 checked before execution |
| Temp-dir race / partial download | `mktemp -d`, verify, then extract/copy; no shared cache |
| Credentials in a remote URL | `installed-ref` strips `https://user:pass@` |
| Failed pull claims success | `update` records the revision it left behind and exits non-zero |
| Silent divergence after moving a checkout | `doctor` compares `installed-ref` with live `HEAD` |

## Traceability (`installed-ref`)

```text
$XDG_STATE_HOME/yadr/installed-ref      # default ~/.local/state/yadr/installed-ref
```

One `key=value` per line, mode `0600`, written through an exclusive `mktemp`
file and moved into place. Keys:

| Key | Meaning |
|---|---|
| `sha` | full `git rev-parse HEAD`; empty for a non-git local copy |
| `ref` | tag if HEAD is tagged, else branch, else `detached`/`local` |
| `branch` | branch name; `HEAD` when detached |
| `tag` | exact tag at HEAD, if any |
| `version` | contents of `VERSION` |
| `origin` | `origin` URL with embedded credentials removed |
| `recorded` | UTC timestamp, `YYYY-MM-DDTHH:MM:SSZ` |

`bootstrap.sh` writes it before handing off to `bin/yadr install`; `yadr update`
writes it after the pull attempt, including a failed pull. `yadr install` does
not write it. `yadr doctor` prints the recorded revision; a missing file is
informational and a differing SHA is a warning. It is local state, not proof of
provenance.

## Bumping a pin

1. Pick the new upstream release/tag and download every platform asset.
2. Measure `sha256sum <asset>` (or `shasum -a 256`) for each architecture.
3. Update the constants and URLs in `platform/linux.sh`,
   `platform/lazygit.sh` or `platform/macos.sh`.
4. Update this inventory and `docs/releases.md`.
5. Run `bats tests/shell.bats -f "static provenance"` and the install/update
   tests; run one real isolated install for the affected platform.
6. Tag only after the assets still resolve and the checksums match.

Never "fix" a mismatch by removing the check or changing the expected hash to
whatever the download produced: re-download from the official release page and
compare with the published checksum first.
