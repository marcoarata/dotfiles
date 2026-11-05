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

# Shared marker contract from platform/common.sh. Resolve it next to this
# script; PLATFORM_COMMON exists only for tests that source a copied script.
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

CONF_D="${XDG_CONFIG_HOME:-$HOME/.config}/mise/conf.d/yadr-tools.toml"
TOOLS=(eza bat delta)

missing_tools() # prints each tool not on PATH, one per line
{
  local t
  for t in "${TOOLS[@]}"; do have "$t" || printf '%s\n' "$t"; done
}

install_macos() {
  # `delta` ships as git-delta in Homebrew/MacPorts; eza/bat keep their names.
  if have brew; then
    if brew install eza bat git-delta 2>/dev/null; then
      yadr_marker tools || { warn "cannot record provides-tools."; return 1; }
      return 0
    fi
    warn "brew install failed."
  fi
  if have port; then
    if port install eza bat git-delta 2>/dev/null; then
      yadr_marker tools || { warn "cannot record provides-tools."; return 1; }
      return 0
    fi
    warn "MacPorts install failed."
  fi
  warn "no brew/MacPorts (or install failed). Manual: https://github.com/eza-community/eza https://github.com/sharkdp/bat https://github.com/dandavison/delta"
  return 1
}

install_mise() { # Linux/WSL: user-global via conf.d, so the checkout stays clean
  have mise || return 1
  yadr_marker_writable tools \
    || { warn "cannot record provides-tools; refusing to install tools."; return 1; }
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
  yadr_marker tools || { warn "cannot record provides-tools."; return 1; }
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
