#!/usr/bin/env bash
# YADR 2027 — platform/wsl.sh
# Reuses linux.sh and adds clipboard integration + WSL-specific notes.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
log()  { printf '[yadr:wsl] %s\n' "$*"; }
warn() { printf '[yadr:wsl] WARN: %s\n' "$*" >&2; }

main() {
  log "WSL detected — applying Linux base then WSL tweaks."
  bash "${SCRIPT_DIR}/linux.sh" "$@"
  # Clipboard: win32yank or clip.exe/wslview when present; nothing mandatory is installed.
  if command -v win32yank.exe >/dev/null 2>&1; then
    log "clipboard: win32yank.exe available."
  elif command -v clip.exe >/dev/null 2>&1; then
    log "clipboard: clip.exe available (copy to Windows only)."
  else
    cat <<'NOTE'
[yadr:wsl] Clipboard: for yank/paste between Neovim/tmux and Windows install
  win32yank (recommended) or use clip.exe / wslview already present in your distro.
  YADR works without this; it only improves the clipboard.
NOTE
  fi
  cat <<'NOTE'
[yadr:wsl] Done. WSL notes:
  - No Linux GUI needed: use the Windows terminal (Terminal.app equivalent:
    Windows Terminal) with a Nerd Font.
  - Keep the repo on the Linux filesystem (~/...) for best performance, not under /mnt/c.
  - Windows/Linux interop enabled by default; 'wslview' opens URLs in your Windows browser.
NOTE
}

main "$@"
