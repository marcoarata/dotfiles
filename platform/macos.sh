#!/usr/bin/env bash
# YADR 2027 — platform/macos.sh
# Installs YADR dependencies on macOS via Homebrew. No mandatory iTerm/MacVim.
set -euo pipefail

PACKAGES=(git zsh tmux neovim ripgrep fd zoxide mise fzf gh delta eza bat lazygit zsh-syntax-highlighting zsh-autosuggestions unzip)

# Pinned XDG fallback for the zsh plugins (R6): tag + exact commit. Homebrew
# and apt/dnf still provide their own builds; this path only runs when the
# distro/package manager has no plugin package (notably MacPorts).
ZSH_SYNTAX_HIGHLIGHTING_TAG="0.8.0"
ZSH_SYNTAX_HIGHLIGHTING_COMMIT="db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e"
ZSH_AUTOSUGGESTIONS_TAG="v0.7.1"
ZSH_AUTOSUGGESTIONS_COMMIT="e52ee8ca55bcc56a17c828767a3f98f22a68d4eb"

# MacPorts names differ for some packages (Intel Tier 3 path).
PORT_PACKAGES=(git zsh tmux neovim ripgrep fd zoxide mise fzf gh git-delta eza bat lazygit unzip)

log()  { printf '[yadr:macos] %s\n' "$*"; }
warn() { printf '[yadr:macos] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Shared helpers (fonts download, version floor, purge markers).
# PLATFORM_COMMON override exists only for tests.
#
# Resolve it next to this script without letting a failed `dirname`/`cd` kill
# the script under `set -e`: the "missing common.sh" warning below is the
# documented fallback, and a failed substitution here used to abort before
# reaching it (found by the Arch lane: `cd ""` is not a no-op on every bash).
if [[ -z "${PLATFORM_COMMON:-}" ]]; then
  if _yadr_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"; then
    PLATFORM_COMMON="${_yadr_dir}/common.sh"
  else
    PLATFORM_COMMON=""
  fi
  unset _yadr_dir
fi
# shellcheck disable=SC1090
if [[ -f "$PLATFORM_COMMON" ]]; then source "$PLATFORM_COMMON" || { warn "cannot load platform/common.sh."; exit 1; }
else warn "platform/common.sh missing; shared helpers unavailable."; fi

ensure_brew() {
  if have brew; then return 0; fi
  log "Homebrew not found — installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]] && [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  have brew || { warn "brew still not in PATH. Open a new shell and retry."; return 1; }
}

install_fonts_macos() {
  local manifest
  manifest="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../terminal/fonts" 2>/dev/null && pwd)/manifest.env"
  [[ -f "$manifest" ]] || { warn "font manifest missing; skipping."; return 0; }
  # shellcheck disable=SC1090
  source "$manifest" || return 0
  local _nfont="" _f
  for _f in "${HOME}/Library/Fonts/"*[Nn]erd*; do
    [[ -e "$_f" ]] && { _nfont="$_f"; break; }
  done
  if [[ -n "$_nfont" ]]; then
    log "Nerd font already installed."
    return 0
  fi
  log "downloading ${YADR_FONT_FAMILY} ${YADR_FONT_VERSION}..."
  fetch_verified_zip "$YADR_FONT_URL" "${YADR_FONT_SHA256:-}" "${HOME}/Library/Fonts" '*.ttf' '*.otf' || return 0
  log "font installed in ~/Library/Fonts."
}

install_via_macports() {
  # Intel fallback: Homebrew Tier 3 has no bottles; MacPorts does.
  have port || { warn "MacPorts (port) not found: https://www.macports.org"; return 1; }
  log "installing via MacPorts…"
  sudo port -N selfupdate 2>/dev/null || warn "port selfupdate failed; continuing anyway."
  local p
  for p in "${PORT_PACKAGES[@]}"; do
    sudo port -N install "$p" 2>/dev/null || warn "port $p failed."
  done
}

clone_xdg_plugin() { # repo subdir file tag commit
  # Last resort without sudo: upstream repos straight into XDG (plugins.zsh lookup #2).
  # The checkout is pinned to a tag AND its exact commit: tags are movable, so
  # comparing HEAD is the part that actually protects an existing install.
  local repo="$1" subdir="$2" file="$3" tag="$4" commit="$5"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/yadr-plugins/${subdir}"
  local tmp got
  if [[ -f "${dest}/${file}" ]]; then
    got="$(git -C "$dest" rev-parse HEAD 2>/dev/null || true)"
    if [[ -d "${dest}/.git" && "$got" == "$commit" ]]; then return 0; fi
    warn "existing ${dest} is not at pinned ${tag}; re-cloning."
  fi
  have git || { warn "no git for XDG clone."; return 1; }
  mkdir -p "$(dirname "$dest")" 2>/dev/null || return 1
  tmp="${dest}.yadr-new.$$"
  rm -rf "$tmp"
  log "cloning ${repo}@${tag} → ${dest} (no sudo)…"
  git clone --depth 1 --branch "$tag" "https://github.com/${repo}.git" "$tmp" 2>/dev/null \
    || { warn "clone ${repo}@${tag} failed."; rm -rf "$tmp"; return 1; }
  got="$(git -C "$tmp" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$got" != "$commit" ]]; then
    warn "clone ${repo}@${tag} is at ${got:-unknown}, expected ${commit}; refusing it."
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$dest"
  mv "$tmp" "$dest" || { warn "could not move ${tmp} to ${dest}."; rm -rf "$tmp"; return 1; }
}

ensure_zsh_plugins_macos() {
  # zsh-syntax-highlighting/autosuggestions are not in MacPorts: XDG clones.
  clone_xdg_plugin "zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting" "zsh-syntax-highlighting.zsh" \
    "$ZSH_SYNTAX_HIGHLIGHTING_TAG" "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT" || true
  clone_xdg_plugin "zsh-users/zsh-autosuggestions" "zsh-autosuggestions" "zsh-autosuggestions.zsh" \
    "$ZSH_AUTOSUGGESTIONS_TAG" "$ZSH_AUTOSUGGESTIONS_COMMIT" || true
}

choose_solarized_bg() {
  # macOS background menu: 1 light (solid) / 2 dark (solid) / 3 none.
  # Enter / invalid / no TTY / --yes / env override missing -> none.
  # Stored in <XDG config>/yadr/solarized-bg (read by nvim on every start);
  # YADR_SOLARIZED_BG env (light|dark|none) wins without prompting.
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/yadr/solarized-bg" choice=""
  if [[ -n "${YADR_SOLARIZED_BG:-}" ]]; then
    case "${YADR_SOLARIZED_BG}" in light|dark|none) choice="${YADR_SOLARIZED_BG}" ;;
      *) warn "YADR_SOLARIZED_BG='${YADR_SOLARIZED_BG}' invalid (light|dark|none); using none."; choice="none" ;;
    esac
  elif [[ "${YADR_YES:-0}" == "1" || ! -t 0 ]]; then
    choice="none"
  else
    printf '\n[yadr:macos] Solarized background:\n  1) light (solid)\n  2) dark (solid)\n  3) none — transparent (default)\n'
    printf 'Choose [1/2/3] (Enter = none): '
    local ans=""; IFS= read -r ans || ans=""
    case "$ans" in 1) choice="light" ;; 2) choice="dark" ;; 3|"") choice="none" ;;
      *) warn "invalid choice; using none."; choice="none" ;;
    esac
  fi
  mkdir -p "$(dirname "$dest")" 2>/dev/null || true
  printf '%s\n' "$choice" > "$dest" 2>/dev/null || true
  log "solarized bg: ${choice} (stored in ${dest})."
}

ensure_vim_macos() {
  # ~/.local/bin/vim -> best available nvim. Never touches /usr/bin/vim.
  # Genuine Apple Vim stays intact unless the user picks the shim via PATH.
  local nvim_bin=""
  nvim_bin="$(command -v nvim 2>/dev/null || true)"
  [[ -n "$nvim_bin" ]] || { warn "no nvim; skipping vim shim."; return 0; }
  local ver
  if ver="$(nvim_version_ok "$nvim_bin")"; then
    mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
    ln -sfn "$nvim_bin" "${HOME}/.local/bin/vim"
    yadr_marker vim
    log "vim -> ${nvim_bin} (shim; purge removes it)."
  else
    warn "nvim ${ver} <0.11; skipping vim shim."
  fi
}

brew_install() {
  log "brew update…"
  brew update || warn "brew update failed (offline?). Continuing."
  log "installing: ${PACKAGES[*]}"
  brew install "${PACKAGES[@]}" || brew install git zsh tmux neovim ripgrep fd zoxide mise fzf zsh-syntax-highlighting zsh-autosuggestions unzip || warn "some packages failed."
  # fzf key-bindings (best effort)
  if [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish 2>/dev/null || true
  fi
}

is_arm64() { [[ "$(uname -m)" == "arm64" ]]; }

main() {
  [[ "$(uname -s)" == "Darwin" ]] || { warn "not macOS ($(uname -s)). Aborting."; return 1; }
  have curl || { warn "curl is required."; return 1; }
  if is_arm64; then
    # Apple Silicon: Homebrew with bottles, always first. Never MacPorts silently.
    ensure_brew || return 1
    brew_install || true
  else
    # Intel: Homebrew is Tier 3 (no bottles, may compile). MacPorts first.
    log "Intel Mac: preferring MacPorts (Homebrew Tier 3)…"
    if have port; then
      install_via_macports || true
    else
      warn "MacPorts not found. Recommended on Intel Macs: https://www.macports.org"
      if ensure_brew; then
        warn "trying Homebrew anyway (best effort, may build from source)…"
        brew_install || true
      else
        warn "continuing without a package manager."
      fi
    fi
    ensure_zsh_plugins_macos || true
  fi
  ensure_vim_macos || true
  choose_solarized_bg || true
  install_fonts_macos || true
  cat <<'NOTE'
[yadr:macos] Nerd font auto-installed (see terminal/fonts/).
  For another one: brew install --cask <your-nerd-font> (https://www.nerdfonts.com).
  iTerm2 / MacVim / Ghostty / WezTerm are optional: YADR works
  in Terminal.app and any truecolor terminal.
  Solarized palettes for iTerm2 in terminal/solarized/.
NOTE
  log "macOS ready."
}

main "$@"
