#!/usr/bin/env bash
# YADR 2027 — bootstrap.sh
# Brings a fresh machine to "ready for yadr install".
# Idempotent, non-destructive, headless OK.
set -euo pipefail

YADR_REPO_URL="${YADR_REPO_URL:-https://github.com/marcoarata/dotfiles.git}"
YADR_LOCAL="${YADR_LOCAL:-0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# When bootstrap.sh lives inside a checkout, that checkout IS YADR_HOME.
if [[ -f "${SCRIPT_DIR}/bin/yadr" ]]; then
  DEFAULT_HOME="${SCRIPT_DIR}"
else
  DEFAULT_HOME="${HOME}/.yadr-2027"
fi
YADR_HOME="${YADR_HOME:-${DEFAULT_HOME}}"
YADR_BRANCH="${YADR_BRANCH:-main}"

log()  { printf '[yadr-bootstrap] %s\n' "$*"; }
warn() { printf '[yadr-bootstrap] WARN: %s\n' "$*" >&2; }
die()  { printf '[yadr-bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl";
      else echo "linux"; fi ;;
    *) echo "unknown" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "x64" ;;
    *) uname -m ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }
have_sudo() { command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null || [[ "${EUID:-$(id -u)}" -eq 0 ]]; }
run_priv() { if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then "$@"; elif have_sudo || command -v sudo >/dev/null 2>&1; then sudo "$@"; else "$@"; fi; }

ensure_minimal_deps() {
  local os="$1"
  local missing=()
  for c in git curl zsh; do have "$c" || missing+=("$c"); done
  [[ ${#missing[@]} -eq 0 ]] && { log "minimal deps OK (git/curl/zsh)."; return 0; }
  log "missing: ${missing[*]} — trying to install..."
  case "$os" in
    macos)
      if ! have brew; then
        warn "Homebrew not found. Install it first: https://brew.sh — continuing without deps."
        return 0
      fi
      brew install git curl zsh || warn "brew failed; install manually: brew install ${missing[*]}"
      ;;
    linux|wsl)
      if have apt-get; then
        run_priv apt-get update && run_priv apt-get install -y "${missing[@]}" || warn "apt failed."
      elif have dnf; then
        run_priv dnf install -y "${missing[@]}" || warn "dnf failed."
      elif have pacman; then
        run_priv pacman -Sy --noconfirm "${missing[@]}" || warn "pacman failed."
      else
        warn "no apt/dnf/pacman. Install manually: ${missing[*]}"
      fi
      ;;
    *) warn "unknown OS; install manually: ${missing[*]}" ;;
  esac
}

sync_repo() {
  if [[ -d "${YADR_HOME}/.git" ]]; then
    log "updating ${YADR_HOME} (${YADR_BRANCH})..."
    git -C "$YADR_HOME" fetch --quiet origin || warn "fetch failed (offline?). Continuing."
    git -C "$YADR_HOME" checkout --quiet "$YADR_BRANCH" 2>/dev/null || true
    git -C "$YADR_HOME" pull --ff-only --quiet 2>/dev/null || warn "pull failed; using local checkout."
  elif [[ -f "${YADR_HOME}/bin/yadr" ]]; then
    log "YADR_HOME=${YADR_HOME} (local checkout without .git, no clone)."
  else
    log "cloning ${YADR_REPO_URL} -> ${YADR_HOME}..."
    git clone --branch "$YADR_BRANCH" --depth 1 "$YADR_REPO_URL" "$YADR_HOME" \
      || git clone "$YADR_REPO_URL" "$YADR_HOME" \
      || die "could not clone ${YADR_REPO_URL}. When no GitHub repo exists yet, copy the project and use: YADR_HOME=<copy> ./bootstrap.sh --local (see INSTALL-YADR.md)."
  fi
}

main() {
  # --local: skip clone and pull; use the current checkout as-is.
  # Useful for ephemeral VMs: copy the project (rsync/scp/tar) and test without GitHub.
  #   rsync -a --delete ./dotfiles/ vm:/tmp/yadr/
  #   YADR_HOME=/tmp/yadr ./bootstrap.sh --local
  # Also: YADR_LOCAL=1 ./bootstrap.sh
  local os arch filtered=()
  for a in "$@"; do
    case "$a" in --local) YADR_LOCAL=1 ;; *) filtered+=("$a") ;; esac
  done
  set -- ${filtered[@]+"${filtered[@]}"}
  os="$(detect_os)"; arch="$(detect_arch)"
  log "YADR 2027 bootstrap — os=${os} arch=${arch} home=${YADR_HOME}"
  ensure_minimal_deps "$os"
  if [[ "$YADR_LOCAL" == "1" ]]; then
    log "--local mode: no clone or pull; using ${YADR_HOME} as-is."
    [[ -f "${YADR_HOME}/bin/yadr" ]] || die "bin/yadr missing in ${YADR_HOME}."
    log "running: bin/yadr install"
    exec "${YADR_HOME}/bin/yadr" install "$@"
  fi
  # sync_repo only when YADR_HOME is not the current checkout already shipping bin/yadr without .git,
  # or when the user forced a different remote repo.
  if [[ "$SCRIPT_DIR" != "$YADR_HOME" ]] || [[ ! -f "${YADR_HOME}/bin/yadr" ]]; then
    have git || die "git is required and not installed."
    sync_repo
  else
    log "local checkout detected, skipping clone/pull."
    if [[ -d "${YADR_HOME}/.git" ]]; then
      git -C "$YADR_HOME" pull --ff-only --quiet 2>/dev/null || warn "pull failed; continuing with local checkout."
    fi
  fi
  [[ -f "${YADR_HOME}/bin/yadr" ]] || die "bin/yadr missing in ${YADR_HOME}."
  log "running: bin/yadr install"
  exec "${YADR_HOME}/bin/yadr" install "$@"
}

main "$@"
