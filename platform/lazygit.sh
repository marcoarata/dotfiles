#!/usr/bin/env bash
# YADR 2027 — platform/lazygit.sh
# Installs lazygit per OS (logic from https://github.com/jesseduffield/lazygit).
# No sudo except apt (which requires it); tarball fallback goes to ~/.local/bin.
# Policy: package managers stay rolling; the tarball fallback is pinned (R6).
set -euo pipefail

log()  { printf '[yadr:lazygit] %s\n' "$*"; }
warn() { printf '[yadr:lazygit] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Shared helpers (markers, sha256 verification). PLATFORM_COMMON override
# exists only for tests. Resolve it next to this script without letting a
# failed `dirname`/`cd` abort before the documented missing-common warning.
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
else warn "platform/common.sh missing; shared helpers unavailable."; exit 1; fi

# Pinned fallback (R6). Assets are lowercase: lazygit_<ver>_<os>_<arch>.tar.gz.
LAZYGIT_VERSION="0.66.2"
LAZYGIT_SHA256_LINUX_X86_64="158efc9ddfa1241fab5fb3526bb442c8dc6c4b1904d73213b9e4e93e03c52034"
LAZYGIT_SHA256_LINUX_ARM64="79a3161eeb642f0473e23db6341f7baabd4a5933e921a9c1167c5d5c765c41a4"
LAZYGIT_SHA256_DARWIN_X86_64="de5d3771e4befa6fe17590e21445614998adc1ef34a71f4003df6764247517ab"
LAZYGIT_SHA256_DARWIN_ARM64="fadda59ae7665ba556fcbaa704c7eade6e40d016d3f3b25d6327dd1f3f906a0c"

os_id() { grep -E '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true; }
os_ver() { grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true; }

install_tarball() {
  # Pinned fallback: official release -> ~/.local/bin (no sudo).
  have curl || { warn "no curl."; return 1; }
  local os arch sha tmp url
  case "$(uname -s)" in
    Linux) os="linux" ;;
    Darwin) os="darwin" ;;
    *) warn "OS $(uname -s) has no official binary."; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) warn "arch $(uname -m) has no official binary."; return 1 ;;
  esac
  case "${os}-${arch}" in
    linux-x86_64) sha="$LAZYGIT_SHA256_LINUX_X86_64" ;;
    linux-arm64) sha="$LAZYGIT_SHA256_LINUX_ARM64" ;;
    darwin-x86_64) sha="$LAZYGIT_SHA256_DARWIN_X86_64" ;;
    darwin-arm64) sha="$LAZYGIT_SHA256_DARWIN_ARM64" ;;
  esac
  url="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_${os}_${arch}.tar.gz"
  tmp="$(mktemp -d)" || return 1
  log "downloading lazygit v${LAZYGIT_VERSION} (${os}/${arch})..."
  curl -fsSL --max-time 120 -o "$tmp/lazygit.tar.gz" "$url" \
    || { warn "download failed."; rm -rf "$tmp"; return 1; }
  verify_sha256 "$tmp/lazygit.tar.gz" "$sha" \
    || { warn "lazygit sha256 mismatch."; rm -rf "$tmp"; return 1; }
  tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit \
    || { warn "tar failed."; rm -rf "$tmp"; return 1; }
  mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
  cp -f "$tmp/lazygit" "${HOME}/.local/bin/lazygit" && chmod +x "${HOME}/.local/bin/lazygit" \
    || { warn "lazygit install failed."; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  yadr_marker lazygit
  log "lazygit v${LAZYGIT_VERSION} in ~/.local/bin."
}

main() {
  if have lazygit; then log "lazygit already present ($(lazygit --version 2>/dev/null | head -n1))."; return 0; fi
  case "$(uname -s)" in
    Darwin)
      if have brew; then
        if brew install lazygit; then
          yadr_marker lazygit
          log "lazygit via brew."
          return 0
        fi
        warn "brew install lazygit failed; using pinned tarball."
      else
        warn "brew missing; using pinned tarball."
      fi
      install_tarball || { warn "install failed. Manual: https://github.com/jesseduffield/lazygit."; return 1; }
      return 0
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
