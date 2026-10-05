#!/usr/bin/env bash
# YADR 2027 — platform/macos.sh
# Installs YADR dependencies on macOS via Homebrew. No mandatory iTerm/MacVim.
set -euo pipefail

PACKAGES=(git zsh tmux neovim ripgrep fd zoxide mise fzf gh delta eza bat lazygit zsh-syntax-highlighting zsh-autosuggestions unzip)

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

main() {
  [[ "$(uname -s)" == "Darwin" ]] || { warn "not macOS ($(uname -s)). Aborting."; return 1; }
  have curl || { warn "curl is required."; return 1; }
  ensure_brew || return 1
  log "brew update…"
  brew update || warn "brew update failed (offline?). Continuing."
  log "installing: ${PACKAGES[*]}"
  brew install "${PACKAGES[@]}" || brew install git zsh tmux neovim ripgrep fd zoxide mise fzf zsh-syntax-highlighting zsh-autosuggestions unzip || warn "some packages failed."
  # fzf key-bindings (best effort)
  if [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish 2>/dev/null || true
  fi
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
