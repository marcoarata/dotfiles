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
  local dir="$1" name="$2" state bak actual
  state="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  [[ -e "$dir" || -L "$dir" ]] || return 0
  if [[ -f "${state}/provides-${name}" ]]; then
    rm -rf "$dir" 2>/dev/null || true
    return 0
  fi
  mkdir -p "${state}/backups" 2>/dev/null || true
  bak="$(mktemp -d "${state}/backups/${name}-$(date +%Y%m%d-%H%M%S).XXXXXX" 2>/dev/null)" \
    || { warn "cannot create a backup for ${dir}; refusing to overwrite."; return 1; }
  actual="${bak}/$(basename "$dir")"
  if mv "$dir" "$bak/" 2>/dev/null; then
    warn "existing ${dir} was not installed by YADR; moved to ${actual}"
    return 0
  fi
  rmdir "$bak" 2>/dev/null || true
  warn "existing ${dir} is not YADR's and could not be moved; refusing to overwrite."
  return 1
}

binary_backup_root() { # binary backups live outside yadr/ so purge keeps them
  local state="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  printf '%s/yadr-binary-backups' "$(dirname "$state")"
}

claim_owned_binary() { # <target> <source> <marker-name> [link|copy]
  # Install one managed executable without ever silently overwriting a file
  # YADR cannot prove it owns. The provides-<marker> file is the ownership
  # proof (same markers v0.9.8 already wrote). A foreign target is moved to
  # yadr-binary-backups/ and reported; a managed one is replaced in place.
  # The marker is written only after the link/copy succeeds, so a failed
  # install leaves no claim behind.
  local target="$1" source="$2" name="$3" mode="${4:-link}"
  local state root bak saved="" tmp="" owned=0 foreign=0
  state="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  [[ -f "${state}/provides-${name}" ]] && owned=1
  [[ -n "$target" && -n "$source" && -n "$name" ]] \
    || { warn "claim_owned_binary: target, source and marker are required."; return 1; }
  [[ -e "$source" || -L "$source" ]] \
    || { warn "claim_owned_binary: source ${source} is missing."; return 1; }
  case "$mode" in link|copy) ;; *) warn "claim_owned_binary: unknown mode ${mode}."; return 1 ;; esac
  if [[ -d "$target" && ! -L "$target" ]]; then
    warn "existing ${target} is a directory; refusing to replace it."
    return 1
  fi
  # Already the managed target: idempotent reinstall/update. Adopt targets that
  # point at the expected source even if an older marker is missing.
  if [[ -L "$target" && "$(readlink "$target" 2>/dev/null || true)" == "$source" ]]; then
    yadr_marker "$name"
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    # A marker proves the default path belongs to YADR, but not that the user
    # left YADR's object there. Link targets that are no longer our symlink,
    # and copy targets replaced by a symlink, are foreign again.
    if [[ "$owned" == "0" ]]; then
      foreign=1
    elif [[ "$mode" == "link" ]]; then
      foreign=1
    elif [[ -L "$target" ]]; then
      foreign=1
    fi
    if [[ "$foreign" == "1" ]]; then
      root="$(binary_backup_root)"
      mkdir -p "$root" 2>/dev/null \
        || { warn "cannot create ${root}; refusing to overwrite ${target}."; return 1; }
      bak="$(mktemp -d "${root}/${name}-$(date +%Y%m%d-%H%M%S).XXXXXX" 2>/dev/null)" \
        || { warn "cannot create a backup for ${target}; refusing to overwrite."; return 1; }
      if mv "$target" "$bak/" 2>/dev/null; then
        saved="${bak}/$(basename "$target")"
        warn "existing ${target} was not installed by YADR; moved to ${saved}"
      else
        rmdir "$bak" 2>/dev/null || true
        warn "existing ${target} is not YADR's and could not be moved; refusing to overwrite."
        return 1
      fi
    fi
  fi
  mkdir -p "$(dirname "$target")" 2>/dev/null \
    || {
      warn "cannot create $(dirname "$target"); refusing to install ${target}."
      if [[ -n "$saved" ]]; then
        mv "$saved" "$target" 2>/dev/null && rmdir "$bak" 2>/dev/null || warn "could not restore ${target} from ${saved}"
      fi
      return 1
    }
  if [[ "$mode" == "copy" ]]; then
    tmp="$(mktemp "${target}.yadr-new.XXXXXX" 2>/dev/null)" \
      || {
        warn "cannot create a temporary file for ${target}."
        if [[ -n "$saved" ]]; then
          mv "$saved" "$target" 2>/dev/null && rmdir "$bak" 2>/dev/null || warn "could not restore ${target} from ${saved}"
        fi
        return 1
      }
    if ! { cp -f "$source" "$tmp" 2>/dev/null && chmod +x "$tmp" 2>/dev/null && mv -f "$tmp" "$target" 2>/dev/null; }; then
      warn "install failed for ${target}; restoring the previous file."
      rm -f "$tmp"
      if [[ -n "$saved" ]]; then
        rm -f "$target"
        mv "$saved" "$target" 2>/dev/null && rmdir "$bak" 2>/dev/null || warn "could not restore ${target} from ${saved}"
      fi
      return 1
    fi
  else
    if ! ln -sfn "$source" "$target" 2>/dev/null; then
      warn "install failed for ${target}; restoring the previous file."
      if [[ -n "$saved" ]]; then
        rm -f "$target"
        mv "$saved" "$target" 2>/dev/null && rmdir "$bak" 2>/dev/null || warn "could not restore ${target} from ${saved}"
      fi
      return 1
    fi
  fi
  yadr_marker "$name"
  return 0
}

nvim_version_ok() { # $1 = nvim binary: echoes "M.m", exit 0 when >=0.11
  local ver maj min
  ver="$("$1" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  maj="${ver%%.*}"; min="${ver##*.}"
  printf '%s' "${ver:-unknown}"
  [[ "${maj:-0}" -gt 0 || "${min:-0}" -ge 11 ]] 2>/dev/null
}

sha256_of() { # <file>: print the lowercase hex digest; 1 if unreadable/no tool
  local f="${1:-}"
  [[ -n "$f" && -f "$f" ]] || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    return 1
  fi
}

verify_sha256() { # <file> <expected-hex>: 0 on match, 1 otherwise (empty is not a pin)
  local f="${1:-}" want="${2:-}" got
  [[ -n "$f" && -n "$want" ]] || return 1
  got="$(sha256_of "$f")" || return 1
  [[ "$got" == "$want" ]]
}

fetch_verified_zip() { # <url> <sha256-or-empty> <destdir> [glob...]: download, verify, extract
  local url="$1" sha="${2:-}" dest="$3"
  shift 3
  if [[ $# -eq 0 ]]; then set -- '*.ttf' '*.otf'; fi
  have curl unzip || { warn "missing curl/unzip."; return 1; }
  local tmp
  tmp="$(mktemp -d)" || return 1
  curl -fsSL "$url" -o "$tmp/font.zip" || { warn "download failed."; rm -rf "$tmp"; return 1; }
  if [[ -n "$sha" ]]; then
    verify_sha256 "$tmp/font.zip" "$sha" || { warn "sha256 mismatch."; rm -rf "$tmp"; return 1; }
  else
    warn "no pinned sha256: only verifying zip integrity."
  fi
  unzip -t "$tmp/font.zip" >/dev/null 2>&1 || { warn "corrupt zip."; rm -rf "$tmp"; return 1; }
  mkdir -p "$dest" 2>/dev/null || { warn "cannot create ${dest}."; rm -rf "$tmp"; return 1; }
  # A missing optional glob (for example *.otf in a *.ttf-only font zip) makes
  # unzip return 11 even though the matching files were extracted. Filter the
  # patterns against the archive first: no match at all is a real failure; a
  # partial match is normal and must not leave the font unmarked.
  local p list="${tmp}/entries" matched=()
  for p in "$@"; do
    : > "$list"
    unzip -Z1 "$tmp/font.zip" "$p" > "$list" 2>/dev/null || true
    [[ -s "$list" ]] && matched+=("$p")
  done
  if [[ ${#matched[@]} -eq 0 ]]; then
    warn "font extraction failed: no archive entry matches ${*:-the requested patterns}."
    rm -rf "$tmp"
    return 1
  fi
  if ! unzip -o -j "$tmp/font.zip" "${matched[@]}" -d "$dest" >/dev/null 2>&1; then
    warn "font extraction failed."
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}
