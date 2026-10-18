#!/usr/bin/env bash
# YADR 2027 — platform/tools.sh
# Optional modern CLI tools the shell aliases prefer: eza, bat, delta.
# They already ship on macOS (see platform/macos.sh PACKAGES/PORT_PACKAGES);
# on Linux/WSL this profile adds them as user-global mise tools.
# Idempotent: installs only what is missing. No sudo. Never touches the
# managed runtime/mise.toml — it writes <mise config>/conf.d/yadr-tools.toml.
# Policy: floating latest (leaf tools). Marks provides-tools for purge.
set -euo pipefail

log()  { printf '[yadr:tools] %s\n' "$*"; }
warn() { printf '[yadr:tools] WARN: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

CONF_D="${XDG_CONFIG_HOME:-$HOME/.config}/mise/conf.d/yadr-tools.toml"
TOOLS=(eza bat delta)

missing_tools() # prints each tool not on PATH, one per line
{
  local t
  for t in "${TOOLS[@]}"; do have "$t" || printf '%s\n' "$t"; done
}

yadr_marker() { # records provides-tools for purge (same name as platform/common.sh)
  local dir="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  mkdir -p "$dir" 2>/dev/null || true
  touch "${dir}/provides-tools" 2>/dev/null || true
}

install_macos() {
  # `delta` ships as git-delta in Homebrew/MacPorts; eza/bat keep their names.
  if have brew; then
    brew install eza bat git-delta 2>/dev/null && { yadr_marker; return 0; }
    warn "brew install failed."
  fi
  if have port; then
    port install eza bat git-delta 2>/dev/null && { yadr_marker; return 0; }
    warn "MacPorts install failed."
  fi
  warn "no brew/MacPorts (or install failed). Manual: https://github.com/eza-community/eza https://github.com/sharkdp/bat https://github.com/dandavison/delta"
  return 1
}

install_mise() { # Linux/WSL: user-global via conf.d, so the checkout stays clean
  have mise || return 1
  mkdir -p "$(dirname "$CONF_D")" 2>/dev/null || true
  {
    printf '# YADR 2027 — optional modern CLI tools (managed by: yadr install tools).\n'
    printf '# mise merges conf.d over the base config; delete this file to drop them.\n'
    printf '[tools]\n'
    printf 'eza = "latest"\n'
    printf 'bat = "latest"\n'
    printf 'delta = "latest"\n'
  } > "$CONF_D"
  log "pinned eza/bat/delta in ${CONF_D}"
  mise install 2>&1 | tail -n 8 || { warn "mise install failed."; return 1; }
  mise reshim 2>/dev/null || true
  yadr_marker
  return 0
}

main() {
  local miss
  miss="$(missing_tools)"
  if [[ -z "$miss" ]]; then log "eza/bat/delta already present."; return 0; fi
  log "missing: ${miss//$'\n'/ }"
  case "$(uname -s)" in
    Darwin) install_macos || return 1 ;;
    *) install_mise || { warn "mise not available; install eza/bat/delta via your distro (apt/dnf/pacman) or https://mise.jdx.dev"; return 1; } ;;
  esac
  # The install step above already succeeded (or returned non-zero). Tools
  # installed as mise shims only appear once the shell reloads PATH, so a
  # still-missing binary here is advisory, not a failure.
  miss="$(missing_tools)"
  if [[ -z "$miss" ]]; then log "ready: eza/bat/delta."; else log "installed; reload your shell to pick up ${miss//$'\n'/ } (mise shims)."; fi
  return 0
}

main "$@"
