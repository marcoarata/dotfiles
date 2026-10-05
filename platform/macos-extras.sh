#!/usr/bin/env bash
# YADR 2027 — platform/macos-extras.sh
# Optional macOS EXTRAS, OUTSIDE core (mathiasbynens .macos style).
# Only via: yadr install macos-extras. Idempotent, manually reversible.
# Never runs on Linux/WSL or headless/SSH installs.
set -euo pipefail

log()  { printf '[yadr:macos-extras] %s\n' "$*"; }
warn() { printf '[yadr:macos-extras] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

main() {
  [[ "$(uname -s)" == "Darwin" ]] || { warn "macOS only. Aborting."; return 1; }
  have defaults || { warn "no 'defaults'. Aborting."; return 1; }
  log "applying sensible defaults (keyboard, Finder, Dock, screenshots)..."

  # Keyboard: fast repeat, useful in Vim (classic key repeat equivalent).
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # Finder: show hidden files + extensions + path bar.
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder ShowPathbar -bool true

  # Screenshots to ~/Pictures/screenshots as PNG without shadow.
  mkdir -p "${HOME}/Pictures/screenshots" 2>/dev/null || true
  defaults write com.apple.screencapture location -string "${HOME}/Pictures/screenshots"
  defaults write com.apple.screencapture type -string "png"
  defaults write com.apple.screencapture disable-shadow -bool true

  # Dock: autohide + no launch animation (keyboard-friendly).
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock launchanim -bool false

  # Trackpad/click: tap-to-click (laptops).
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  for app in Finder Dock SystemUIServer; do killall "$app" >/dev/null 2>&1 || true; done
  log "extras applied. Revert: delete each key with 'defaults delete <domain> <key>'."
}

main "$@"
