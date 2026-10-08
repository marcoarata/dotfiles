#!/usr/bin/env bash
# YADR 2027 — platform/macos.sh
# Installs YADR dependencies on macOS via Homebrew. No mandatory iTerm/MacVim.
set -euo pipefail

PACKAGES=(git zsh tmux neovim ripgrep fd zoxide mise fzf gh delta eza bat lazygit zsh-syntax-highlighting zsh-autosuggestions unzip)

# MacPorts names differ for some packages (Intel Tier 3 path).
PORT_PACKAGES=(git zsh tmux neovim ripgrep fd zoxide mise fzf gh git-delta eza bat lazygit unzip)

log()  { printf '[yadr:macos] %s\n' "$*"; }
warn() { printf '[yadr:macos] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

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
  if [[ -n "$(ls "${HOME}/Library/Fonts" 2>/dev/null | grep -i "NerdFont")" ]]; then
    log "Nerd font already installed."
    return 0
  fi
  have curl unzip || { warn "missing curl/unzip."; return 0; }
  local tmp; tmp="$(mktemp -d)" || return 1
  log "downloading ${YADR_FONT_FAMILY} ${YADR_FONT_VERSION}..."
  curl -fsSL "$YADR_FONT_URL" -o "$tmp/font.zip" || { warn "download failed."; rm -rf "$tmp"; return 1; }
  if [[ -n "${YADR_FONT_SHA256:-}" ]]; then
    [[ "$(shasum -a 256 "$tmp/font.zip" | awk '{print $1}')" == "$YADR_FONT_SHA256" ]] || { warn "sha256 mismatch."; rm -rf "$tmp"; return 1; }
  fi
  unzip -t "$tmp/font.zip" >/dev/null 2>&1 || { warn "corrupt zip."; rm -rf "$tmp"; return 1; }
  mkdir -p "${HOME}/Library/Fonts" 2>/dev/null || true
  unzip -o -j "$tmp/font.zip" '*.ttf' '*.otf' -d "${HOME}/Library/Fonts" >/dev/null 2>&1 || true
  rm -rf "$tmp"
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

clone_xdg_plugin() {
  # Last resort without sudo: upstream repos straight into XDG (plugins.zsh lookup #2).
  local repo="$1" subdir="$2" file="$3"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/yadr-plugins/${subdir}"
  [[ -f "${dest}/${file}" ]] && return 0
  have git || { warn "no git for XDG clone."; return 1; }
  mkdir -p "$dest" 2>/dev/null || return 1
  log "cloning ${repo} → ${dest} (no sudo)…"
  git clone --depth 1 "https://github.com/${repo}.git" "$dest" 2>/dev/null || { warn "clone ${repo} failed."; return 1; }
}

ensure_zsh_plugins_macos() {
  # zsh-syntax-highlighting/autosuggestions are not in MacPorts: XDG clones.
  clone_xdg_plugin "zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting" "zsh-syntax-highlighting.zsh" || true
  clone_xdg_plugin "zsh-users/zsh-autosuggestions" "zsh-autosuggestions" "zsh-autosuggestions.zsh" || true
}

ensure_vim_macos() {
  # ~/.local/bin/vim -> best available nvim. Never touches /usr/bin/vim.
  # Genuine Apple Vim stays intact unless the user picks the shim via PATH.
  local nvim_bin=""
  nvim_bin="$(command -v nvim 2>/dev/null || true)"
  [[ -n "$nvim_bin" ]] || { warn "no nvim; skipping vim shim."; return 0; }
  local ver maj min
  ver="$("$nvim_bin" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  maj="${ver%%.*}"; min="${ver##*.}"
  if [[ "$maj" -gt 0 || "$min" -ge 11 ]] 2>/dev/null; then
    mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
    ln -sfn "$nvim_bin" "${HOME}/.local/bin/vim"
    mkdir -p "${HOME}/.local/state/yadr" 2>/dev/null || true
    touch "${HOME}/.local/state/yadr/provides-vim" 2>/dev/null || true
    log "vim -> ${nvim_bin} (shim; purge removes it)."
  else
    warn "nvim $ver <0.11; skipping vim shim."
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
