#!/usr/bin/env bash
# YADR 2027 — platform/lazygit.sh
# Installs lazygit per OS (logic from https://github.com/jesseduffield/lazygit).
# No sudo except apt (which requires it); tarball fallback goes to ~/.local/bin.
# Policy: floating latest (leaf tool). Marks provides-lazygit for purge.
set -euo pipefail

log()  { printf '[yadr:lazygit] %s\n' "$*"; }
warn() { printf '[yadr:lazygit] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
mark() {
  mkdir -p "${HOME}/.local/state/yadr" 2>/dev/null || true
  touch "${HOME}/.local/state/yadr/provides-lazygit" 2>/dev/null || true
}

os_id() { grep -E '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true; }
os_ver() { grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true; }

install_tarball() {
  # Universal fallback: latest GitHub release -> ~/.local/bin (no sudo).
  have curl || { warn "no curl."; return 1; }
  local ver arch tmp
  if command -v python3 >/dev/null 2>&1; then
    ver="$(curl -fsSL --max-time 30 https://api.github.com/repos/jesseduffield/lazygit/releases/latest 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))' 2>/dev/null || true)"
  else
    ver="$(curl -fsSL --max-time 30 https://api.github.com/repos/jesseduffield/lazygit/releases/latest 2>/dev/null | grep -Po '"tag_name": *"v\K[^"]*' 2>/dev/null || true)"
  fi
  [[ -n "$ver" ]] || { warn "could not resolve latest version."; return 1; }
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) warn "arch $(uname -m) has no official binary."; return 1 ;;
  esac
  tmp="$(mktemp -d)" || return 1
  log "downloading lazygit v${ver} (${arch})..."
  curl -fsSL --max-time 120 -o "$tmp/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_${arch}.tar.gz" \
    || { warn "download failed."; rm -rf "$tmp"; return 1; }
  tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit || { warn "tar failed."; rm -rf "$tmp"; return 1; }
  mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
  cp -f "$tmp/lazygit" "${HOME}/.local/bin/lazygit" && chmod +x "${HOME}/.local/bin/lazygit"
  rm -rf "$tmp"
  mark
  log "lazygit v${ver} in ~/.local/bin."
}

main() {
  if have lazygit; then log "lazygit already present ($(lazygit --version 2>/dev/null | head -n1))."; return 0; fi
  case "$(uname -s)" in
    Darwin)
      if have brew; then brew install lazygit && { mark; return 0; }; fi
      warn "brew missing or failed."
      return 1
      ;;
  esac
  # Linux: try the native manager first; fall back to tarball when unavailable.
  if have apt-get; then
    if [[ "$(id -u)" -eq 0 ]]; then apt-get install -y lazygit 2>/dev/null || true
    elif command -v sudo >/dev/null 2>&1; then sudo apt-get install -y lazygit 2>/dev/null || true
    fi
    # Debian >=13 / Ubuntu >=25.10 ship it in repos (ID/VERSION_ID informational only).
    have lazygit && { log "lazygit via apt (ID=$(os_id) $(os_ver))."; return 0; }
  elif have pacman; then
    if [[ "$(id -u)" -eq 0 ]]; then pacman -Sy --noconfirm lazygit 2>/dev/null || true
    elif command -v sudo >/dev/null 2>&1; then sudo pacman -Sy --noconfirm lazygit 2>/dev/null || true
    fi
    have lazygit && { log "lazygit via pacman."; return 0; }
  elif have dnf; then
    if [[ "$(id -u)" -eq 0 ]]; then dnf install -y lazygit 2>/dev/null || true
    elif command -v sudo >/dev/null 2>&1; then sudo dnf install -y lazygit 2>/dev/null || true
    fi
    have lazygit && { log "lazygit via dnf."; return 0; }
  fi
  log "manager lacks lazygit; tarball fallback..."
  install_tarball || { warn "install failed. Manual: https://github.com/jesseduffield/lazygit."; return 1; }
}

main "$@"
