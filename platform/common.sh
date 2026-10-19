#!/usr/bin/env bash
# YADR 2027 — platform/common.sh
# Shared platform helpers. SOURCED by platform/linux.sh and platform/macos.sh
# (never executed directly, never fetched alone): both define log/warn/have
# first and run under `set -euo pipefail`, which this file inherits.
# Override PLATFORM_COMMON only in tests to point at this file.

yadr_marker() { # $1 = short name: records provides-<name> for purge
  # STATE_DIR wins when the CLI exported it; else the XDG-aware default that
  # mirrors bin/lib/paths.sh (platform scripts also run standalone).
  local dir="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  mkdir -p "$dir" 2>/dev/null || true
  touch "${dir}/provides-$1" 2>/dev/null || true
}

claim_owned_dir() { # <dir> <marker-name>: 0 when safe to (re)create the dir
  # Never delete a directory YADR cannot prove it installed. Owned dirs (the
  # provides-<name> marker exists) are replaced; unowned ones are moved to the
  # backup root so anything the user put there survives.
  local dir="$1" name="$2" state bak
  state="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  [[ -e "$dir" || -L "$dir" ]] || return 0
  if [[ -f "${state}/provides-${name}" ]]; then
    rm -rf "$dir" 2>/dev/null || true
    return 0
  fi
  bak="${state}/backups/${name}-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$(dirname "$bak")" 2>/dev/null || true
  if mv "$dir" "$bak" 2>/dev/null; then
    warn "existing ${dir} was not installed by YADR; moved to ${bak}"
    return 0
  fi
  warn "existing ${dir} is not YADR's and could not be moved; refusing to overwrite."
  return 1
}

nvim_version_ok() { # $1 = nvim binary: echoes "M.m", exit 0 when >=0.11
  local ver maj min
  ver="$("$1" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  maj="${ver%%.*}"; min="${ver##*.}"
  printf '%s' "${ver:-unknown}"
  [[ "${maj:-0}" -gt 0 || "${min:-0}" -ge 11 ]] 2>/dev/null
}

fetch_verified_zip() { # <url> <sha256-or-empty> <destdir> [glob...]: download, verify, extract
  local url="$1" sha="${2:-}" dest="$3"
  shift 3
  if [[ $# -eq 0 ]]; then set -- '*.ttf' '*.otf'; fi
  have curl unzip || { warn "missing curl/unzip."; return 1; }
  local tmp sum
  tmp="$(mktemp -d)" || return 1
  curl -fsSL "$url" -o "$tmp/font.zip" || { warn "download failed."; rm -rf "$tmp"; return 1; }
  if [[ -n "$sha" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sum="$(sha256sum "$tmp/font.zip" | awk '{print $1}')"
    else
      sum="$(shasum -a 256 "$tmp/font.zip" | awk '{print $1}')"
    fi
    [[ "$sum" == "$sha" ]] || { warn "sha256 mismatch."; rm -rf "$tmp"; return 1; }
  else
    warn "no pinned sha256: only verifying zip integrity."
  fi
  unzip -t "$tmp/font.zip" >/dev/null 2>&1 || { warn "corrupt zip."; rm -rf "$tmp"; return 1; }
  mkdir -p "$dest" 2>/dev/null || true
  unzip -o -j "$tmp/font.zip" "$@" -d "$dest" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
