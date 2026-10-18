#!/usr/bin/env bash
# YADR 2027 — lib/transfer.sh: export/apply the user-owned state (cross-machine)
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.
#
# What travels and what does not:
#   * $HOME state that git cannot carry for you (identity, theme, mise user
#     pins, migrated classic files) is in the bundle.
#   * repo-managed files (symlinks, nvim/, mise base config) travel through
#     `git pull`; custom/ hooks travel with your fork. Neither is here, and
#     `apply` never writes inside $YADR_HOME.
#
# Safety model, in this order: parse the archive in a temp dir, verify every
# member against the SHA-256 manifest AND against a whitelist of known names,
# and only then write (backing up anything it overwrites). A tampered or
# foreign archive changes nothing.

sha256_file() { # portable SHA-256 of one file (bin/ must not depend on platform/)
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
  else return 1; fi
}

state_fixed_pairs() { # "archive-name:absolute-path" for the always-known files
  cat <<EOF
gitconfig.user:${HOME}/.gitconfig.user
theme:$(theme_file)
vimrc.before:${HOME}/.vimrc.before
vimrc.after:${HOME}/.vimrc.after
tmux.conf.user:${HOME}/.tmux.conf.user
EOF
}

state_glob_dirs() { # "archive-prefix:directory" — every file inside is user state
  printf 'migrated/:%s\n' "$(yadr_config_dir)/migrated"
  printf 'mise-conf.d/:%s\n' "$(mise_config_dir)/conf.d"
}

state_dest_for() { # archive-name -> absolute destination, empty when not user state
  case "$1" in
    gitconfig.user) echo "${HOME}/.gitconfig.user" ;;
    theme)          theme_file ;;
    vimrc.before)   echo "${HOME}/.vimrc.before" ;;
    vimrc.after)    echo "${HOME}/.vimrc.after" ;;
    tmux.conf.user) echo "${HOME}/.tmux.conf.user" ;;
    migrated/*)     echo "$(yadr_config_dir)/migrated/${1#migrated/}" ;;
    mise-conf.d/*)  echo "$(mise_config_dir)/conf.d/${1#mise-conf.d/}" ;;
    *)              echo "" ;;
  esac
}

user_state_pairs() { # existing state on THIS machine: "archive-name<TAB>absolute-path"
  # TAB separator: user paths may contain colons (macOS volumes).
  local rel abs f
  while IFS=: read -r rel abs; do
    [[ -n "$rel" && -e "$abs" ]] || continue
    printf '%s\t%s\n' "$rel" "$abs"
  done < <(state_fixed_pairs)
  while IFS=: read -r prefix dir; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*; do
      [[ -f "$f" ]] || continue
      printf '%s%s\t%s\n' "$prefix" "$(basename "$f")" "$f"
    done
  done < <(state_glob_dirs)
}

do_export() { # [--out FILE]
  local out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out) out="${2:?usage: yadr export [--out FILE]}"; shift 2 ;;
      *) die "export: unknown argument '$1' (usage: yadr export [--out FILE])" ;;
    esac
  done
  local ts tmp n=0 rel abs
  ts="$(timestamp)"
  [[ -n "$out" ]] || out="${PWD}/yadr-export-${ts}.tar.gz"
  case "$out" in /*) ;; *) out="${PWD}/${out}" ;; esac
  tmp="$(mktemp -d)" || die "export: cannot create a temp dir."
  mkdir -p "$tmp/files"
  while IFS=$'\t' read -r rel abs; do
    [[ -n "$rel" ]] || continue
    mkdir -p "$tmp/files/$(dirname "$rel")" || { rm -rf "$tmp"; die "export: cannot stage ${rel}"; }
    cp_preserve "$abs" "$tmp/files/$rel" || { rm -rf "$tmp"; die "export: cannot copy ${abs}"; }
    n=$((n+1))
  done < <(user_state_pairs)
  if [[ "$n" -eq 0 ]]; then
    rm -rf "$tmp"
    warn "nothing to export: no user-owned state found in this HOME."
    info "looked for: ~/.gitconfig.user, theme, mise conf.d, migrated/ classic files."
    return 0
  fi
  {
    printf 'YADR_EXPORT_VERSION=1\n'
    printf 'YADR_EXPORT_DATE=%s\n' "$ts"
    printf 'YADR_EXPORT_HOST=%s/%s\n' "$(uname -s)" "$(uname -m)"
    printf 'YADR_EXPORT_YADR=%s\n' "$(version_str)"
    printf 'YADR_EXPORT_FILES=%s\n' "$n"
  } > "$tmp/manifest.env" || { rm -rf "$tmp"; die "export: cannot write the manifest."; }
  while IFS=$'\t' read -r rel abs; do
    [[ -n "$rel" ]] || continue
    local sum
    sum="$(sha256_file "$tmp/files/$rel")" || { rm -rf "$tmp"; die "export: no SHA-256 tool (sha256sum/shasum/openssl)."; }
    printf '%s  %s\n' "$sum" "$rel" >> "$tmp/sha256"
  done < <(user_state_pairs)
  tar -czf "$out" -C "$tmp" manifest.env sha256 files 2>/dev/null || { rm -rf "$tmp"; die "export: cannot write ${out}"; }
  rm -rf "$tmp"
  ok "export: ${n} file(s) in ${out}"
  info "on the other machine: yadr apply ${out}"
  info "the bundle holds user state only (no repos, no secrets beyond those files)."
}

do_apply() { # <archive.tar.gz> [--dry-run]
  local archive="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      -*) die "apply: unknown flag '$1' (usage: yadr apply <FILE> [--dry-run])" ;;
      *) if [[ -z "$archive" ]]; then archive="$1"; shift; else die "apply: unexpected argument '$1'"; fi ;;
    esac
  done
  [[ -n "$archive" ]] || die "usage: yadr apply <export.tar.gz> [--dry-run]"
  [[ -f "$archive" ]] || die "apply: no such file: ${archive}"
  local tmp; tmp="$(mktemp -d)" || die "apply: cannot create a temp dir."
  if ! tar -xzf "$archive" -C "$tmp" 2>/dev/null; then
    rm -rf "$tmp"; die "apply: not a readable tar.gz archive: ${archive}"
  fi
  [[ -f "$tmp/manifest.env" && -f "$tmp/sha256" ]] || {
    rm -rf "$tmp"; die "apply: missing manifest.env/sha256 (not a YADR export bundle)."
  }
  # Manifest sanity: a bundle from a future exporter may mean future semantics.
  local mver; mver="$(sed -n 's/^YADR_EXPORT_VERSION=//p' "$tmp/manifest.env" | head -n1)"
  [[ "$mver" == "1" ]] || { rm -rf "$tmp"; die "apply: unsupported bundle version '${mver:-none}' (this build reads 1)."; }
  info "bundle: $(sed -n 's/^YADR_EXPORT_DATE=//p' "$tmp/manifest.env" | head -n1) from $(sed -n 's/^YADR_EXPORT_HOST=//p' "$tmp/manifest.env" | head -n1) (YADR $(sed -n 's/^YADR_EXPORT_YADR=//p' "$tmp/manifest.env" | head -n1))"

  # --- verify everything BEFORE writing anything ---
  local names; names=()
  local want rel dst sum ok_n=0 bad=0
  while read -r want rel; do
    [[ -n "$rel" ]] || continue
    case "$rel" in
      /*|*..*) rm -rf "$tmp"; die "apply: refusing unsafe path in archive: ${rel}" ;;
    esac
    dst="$(state_dest_for "$rel")"
    [[ -n "$dst" ]] || { rm -rf "$tmp"; die "apply: '${rel}' is not user state YADR knows how to place."; }
    if [[ ! -f "$tmp/files/$rel" ]]; then
      warn "apply: member missing from bundle: ${rel}"; bad=1; continue
    fi
    sum="$(sha256_file "$tmp/files/$rel")" || { rm -rf "$tmp"; die "apply: no SHA-256 tool (sha256sum/shasum/openssl)."; }
    if [[ "$sum" == "$want" ]]; then
      names+=("$rel"); ok_n=$((ok_n+1))
    else
      warn "apply: checksum mismatch: ${rel}"; bad=1
    fi
  done < "$tmp/sha256"
  [[ "$bad" == "0" ]] || { rm -rf "$tmp"; die "apply: bundle failed verification; nothing was written."; }
  [[ "$ok_n" -gt 0 ]] || { rm -rf "$tmp"; die "apply: bundle carries no verifiable files."; }

  if [[ "$dry" == "1" ]]; then
    info "dry-run: would restore ${ok_n} file(s):"
    for rel in ${names[@]+"${names[@]}"}; do printf '  %s → %s\n' "$rel" "$(state_dest_for "$rel")"; done
    info "dry-run: nothing modified."
    rm -rf "$tmp"
    return 0
  fi

  # --- write: back up first, then restore ---
  local b restored=0
  b="${BACKUP_ROOT}/apply-$(timestamp)"
  for rel in ${names[@]+"${names[@]}"}; do
    dst="$(state_dest_for "$rel")"
    if [[ -e "$dst" || -L "$dst" ]]; then
      mkdir -p "$b" 2>/dev/null || true
      backup_one "$dst" "$b" >/dev/null || warn "could not back up ${dst}"
    fi
    mkdir -p "$(dirname "$dst")" 2>/dev/null || true
    if cp_preserve "$tmp/files/$rel" "$dst"; then
      ok "  restored: ${dst}"
      restored=$((restored+1))
    else
      err "  could not write ${dst}"
    fi
  done
  rm -rf "$tmp"
  [[ -d "$b" ]] && info "previous versions kept in ${b}"
  if [[ "$restored" -eq "$ok_n" ]]; then
    ok "apply complete: ${restored} file(s) restored. Run 'yadr doctor' to verify."
    return 0
  fi
  err "apply incomplete: ${restored}/${ok_n} file(s) restored (see above)."
  return 1
}
