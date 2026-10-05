#!/usr/bin/env bash
# YADR 2027 — platform/linux.sh
# Detects apt/dnf/pacman and installs the same dependencies. Headless OK, no GUI.
set -euo pipefail

log()  { printf '[yadr:linux] %s\n' "$*"; }
warn() { printf '[yadr:linux] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
priv() { if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

APT_PKGS=(git zsh tmux neovim ripgrep fd-find fzf curl build-essential zsh-syntax-highlighting zsh-autosuggestions unzip fontconfig)
DNF_PKGS=(git zsh tmux neovim ripgrep fd-find fzf curl gcc make zsh-syntax-highlighting zsh-autosuggestions unzip fontconfig)
PAC_PKGS=(git zsh tmux neovim ripgrep fd fzf curl base-devel zsh-syntax-highlighting zsh-autosuggestions unzip fontconfig)

install_mise() {
  have mise && return 0
  log "installing mise (https://mise.jdx.dev)..."
  curl -fsSL https://mise.run | sh || { warn "mise install failed."; return 1; }
  mkdir -p "${HOME}/.local/state/yadr" 2>/dev/null || true
  touch "${HOME}/.local/state/yadr/provides-mise" 2>/dev/null || true
}

install_zoxide() {
  have zoxide && return 0
  log "installing zoxide..."
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || warn "zoxide failed (you can install it later)."
  mkdir -p "${HOME}/.local/state/yadr" 2>/dev/null || true
  touch "${HOME}/.local/state/yadr/provides-zoxide" 2>/dev/null || true
}

# Neovim >=0.11 is the YADR floor (treesitter/gitsigns/lspconfig HEAD require it;
# Ubuntu LTS ships 0.9.x). When apt falls short, use the official tarball into ~/.local/bin.
ensure_nvim() {
  if have nvim; then
    local ver maj min
    ver="$(nvim --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
    maj="${ver%%.*}"; min="${ver##*.}"
    if [[ "$maj" -gt 0 || "$min" -ge 11 ]] 2>/dev/null; then log "neovim $ver OK (>=0.11)."; return 0; fi
    warn "neovim $ver <0.11; installing upstream into ~/.local/bin..."
  else
    log "neovim missing; installing upstream into ~/.local/bin..."
  fi
  local arch url tmp
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) warn "arch $(uname -m) has no official tarball; use apt/manual neovim."; return 1 ;;
  esac
  url="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${arch}.tar.gz"
  tmp="$(mktemp -d)" || return 1
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz" || { warn "neovim download failed."; rm -rf "$tmp"; return 1; }
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp" || { warn "extraction failed."; rm -rf "$tmp"; return 1; }
  mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
  # Full relocatable install: the binary resolves its runtime
  # relative to its real location (resolves the symlink).
  rm -rf "${HOME}/.local/nvim-upstream" 2>/dev/null || true
  cp -a "$tmp"/nvim-linux-*/ "${HOME}/.local/nvim-upstream/" || { warn "copy failed."; rm -rf "$tmp"; return 1; }
  ln -sfn "${HOME}/.local/nvim-upstream/bin/nvim" "${HOME}/.local/bin/nvim"
  rm -rf "$tmp"
  mkdir -p "${HOME}/.local/state/yadr" 2>/dev/null || true
  touch "${HOME}/.local/state/yadr/provides-nvim-upstream" 2>/dev/null || true
  "${HOME}/.local/bin/nvim" --version >/dev/null 2>&1 && log "neovim ready: $("${HOME}/.local/bin/nvim" --version 2>/dev/null | head -n1)." || warn "nvim installed but does not start."
}

main() {
  [[ "$(uname -s)" == "Linux" ]] || { warn "not Linux ($(uname -s)). Aborting."; return 1; }
  if have apt-get; then
    log "manager: apt"
    priv apt-get update || warn "apt update failed."
    priv apt-get install -y "${APT_PKGS[@]}" || warn "some apt packages failed."
    # Debian/Ubuntu name the binary 'fdfind'; YADR expects 'fd'.
    if have fdfind && ! have fd; then priv ln -sf "$(command -v fdfind)" /usr/local/bin/fd || true; fi
  elif have dnf; then
    log "manager: dnf"
    priv dnf install -y "${DNF_PKGS[@]}" || warn "some dnf packages failed."
  elif have pacman; then
    log "manager: pacman"
    priv pacman -Sy --noconfirm "${PAC_PKGS[@]}" || warn "some pacman packages failed."
  else
    warn "no apt/dnf/pacman. Install manually: git zsh tmux nvim rg fd fzf zoxide mise."
  fi
  install_mise || true
  install_zoxide || true
  ensure_nvim || true
  install_fonts || true
  # eza/bat/delta/lazygit/gh: prefer mise or manual per distro; not forced here
  # to keep headless/SSH minimums intact.
  log "linux ready (headless OK). Optional: eza bat delta lazygit gh (via mise or package manager)."
}

# Nerd Fonts (faithful to classic install_fonts; modernized payload).
# Reads terminal/fonts/manifest.env next to this repo; installs to XDG + fc-cache.
install_fonts() {
  local manifest=""
  # No YADR_HOME here: derived from this script path.
  manifest="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../terminal/fonts" 2>/dev/null && pwd)/manifest.env"
  [[ -f "$manifest" ]] || { warn "font manifest missing; skipping."; return 0; }
  # shellcheck disable=SC1090
  source "$manifest" || { warn "unreadable manifest; skipping."; return 0; }
  if [[ -n "$(fc-list 2>/dev/null | grep -i "$YADR_FONT_FAMILY")" ]]; then
    log "font ${YADR_FONT_FAMILY} already installed."
    return 0
  fi
  have curl unzip fc-cache || { warn "missing curl/unzip/fontconfig; install the font manually (${YADR_FONT_URL})."; return 0; }
  local tmp; tmp="$(mktemp -d)" || return 1
  log "downloading ${YADR_FONT_FAMILY} ${YADR_FONT_VERSION}..."
  curl -fsSL "$YADR_FONT_URL" -o "$tmp/font.zip" || { warn "download failed."; rm -rf "$tmp"; return 1; }
  if [[ -n "${YADR_FONT_SHA256:-}" ]]; then
    local got; got="$(sha256sum "$tmp/font.zip" | awk '{print $1}')"
    [[ "$got" == "$YADR_FONT_SHA256" ]] || { warn "sha256 mismatch; aborting font install."; rm -rf "$tmp"; return 1; }
  else
    warn "no pinned sha256: only verifying zip integrity."
  fi
  unzip -t "$tmp/font.zip" >/dev/null 2>&1 || { warn "corrupt zip."; rm -rf "$tmp"; return 1; }
  mkdir -p "${HOME}/.local/share/fonts" 2>/dev/null || true
  unzip -o -j "$tmp/font.zip" '*.ttf' '*.otf' -d "${HOME}/.local/share/fonts" >/dev/null 2>&1 || true
  fc-cache -f "${HOME}/.local/share/fonts" >/dev/null 2>&1 || true
  rm -rf "$tmp"
  mkdir -p "${HOME}/.local/state/yadr" 2>/dev/null || true
  touch "${HOME}/.local/state/yadr/provides-font" 2>/dev/null || true
  [[ -n "$(fc-list 2>/dev/null | grep -i "$YADR_FONT_FAMILY")" ]] && log "font installed." || warn "installed but fc-list cannot see it (graphical session?)."
}

main "$@"
