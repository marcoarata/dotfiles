#!/usr/bin/env bash
# YADR 2027 — lib/recover.sh: install/uninstall/migrate flows plus backup helpers
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.

timestamp() { date +%Y%m%d-%H%M%S; }

# backup_one <src> <destdir>: copies with anti-collision name. Echoes dest.
backup_one() {
  local src="$1" destdir="$2"
  [[ -e "$src" || -L "$src" ]] || return 1
  mkdir -p "$destdir" 2>/dev/null || return 1
  local rel; rel="$(basename "$src")"
  if [[ -e "${destdir}/${rel}" || -L "${destdir}/${rel}" ]]; then
    rel="$(printf '%s' "$src" | tr '/' '_')"
  fi
  cp_preserve "$src" "${destdir}/${rel}" || return 1
  printf '%s' "${destdir}/${rel}"
}

backup_entry_for() {
  # backup_entry_for <src> <backup-dir>: echo the saved copy, or fail.
  # Mirrors backup_one's basename/full-path naming so link_one can prove that
  # the path it is about to replace was actually copied.
  local src="$1" destdir="$2" rel alt
  [[ -n "$src" && -n "$destdir" ]] || return 1
  rel="$(basename "$src")"
  if [[ -e "${destdir}/${rel}" || -L "${destdir}/${rel}" ]]; then
    printf '%s' "${destdir}/${rel}"; return 0
  fi
  alt="$(printf '%s' "$src" | tr '/' '_')"
  if [[ -e "${destdir}/${alt}" || -L "${destdir}/${alt}" ]]; then
    printf '%s' "${destdir}/${alt}"; return 0
  fi
  return 1
}

write_state_pointer() { # write_state_pointer <name> <value> — atomic, mode 0600
  local name="$1" value="$2" tmp
  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  tmp="${STATE_DIR}/.${name}.$$"
  printf '%s\n' "$value" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  chmod 600 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "${STATE_DIR}/${name}" 2>/dev/null || { rm -f "$tmp"; return 1; }
}

backup_managed_pairs() { # backup_managed_pairs <dir>; sets BACKUP_ENTRIES/BACKUP_FAILED
  local dest="$1" rel dst got
  BACKUP_ENTRIES=0; BACKUP_FAILED=0
  while IFS=: read -r rel dst; do
    [[ -z "$dst" ]] && continue
    [[ -e "$dst" || -L "$dst" ]] || continue
    if got="$(backup_one "$dst" "$dest")"; then
      BACKUP_ENTRIES=$((BACKUP_ENTRIES+1)); info "backup: ${dst} → ${got}"
    else
      BACKUP_FAILED=$((BACKUP_FAILED+1)); warn "could not back up ${dst}"
    fi
  done < <(managed_pairs)
}

install_backup_path() { # echo the valid install backup, or fail
  local f="${STATE_DIR}/last-install-backup" p=""
  [[ -f "$f" ]] || return 1
  p="$(cat "$f" 2>/dev/null || true)"
  [[ -n "$p" && -d "$p" ]] || return 1
  # An update snapshot must never become the install restore source.
  case "$(basename "$p")" in update-*) return 1 ;; esac
  printf '%s' "$p"
}

install_backup_is_first() {
  # First install: no install pointer AND no managed destination already
  # linked into this checkout. A reinstall/legacy run must not capture the
  # current symlinks as if they were the user's original files.
  [[ -f "${STATE_DIR}/last-install-backup" ]] && return 1
  local rel dst target
  while IFS=: read -r rel dst; do
    [[ -z "$dst" ]] && continue
    [[ -L "$dst" ]] || continue
    target="$(readlink "$dst" 2>/dev/null || true)"
    [[ "$target" == "${YADR_HOME}/"* ]] && return 1
  done < <(managed_pairs)
  return 0
}

do_backup() {
  # Manual backup: writes last-backup only; never touches the install pointer.
  local ts dest
  ts="$(timestamp)"; dest="${BACKUP_ROOT}/${ts}"
  if ! mkdir -p "$dest" 2>/dev/null; then warn "cannot create backup ${dest}"; return 1; fi
  # shellcheck disable=SC2034  # consumed by link_one in lib/install.sh
  YADR_LAST_BACKUP="$dest"
  backup_managed_pairs "$dest"
  write_state_pointer last-backup "$dest" || warn "cannot record last-backup pointer."
  if [[ "$BACKUP_ENTRIES" -eq 0 ]]; then info "nothing to back up (clean HOME). Dir: ${dest}"; else ok "backup at ${dest} (${BACKUP_ENTRIES} entries)"; fi
  if [[ "$BACKUP_FAILED" -gt 0 ]]; then warn "${BACKUP_FAILED} backup(s) failed; see above."; return 1; fi
  return 0
}

do_install_backup() {
  # First install writes last-install-backup (and last-backup for compatibility).
  # Reinstall/legacy writes a diagnostic dir only; uninstall pointers stay put.
  local ts dest first=0 current_install=""
  if install_backup_is_first; then first=1; fi
  ts="$(timestamp)"; dest="${BACKUP_ROOT}/${ts}"
  if ! mkdir -p "$dest" 2>/dev/null; then
    warn "cannot create install backup ${dest}; real paths will not be replaced."
    return 1
  fi
  # shellcheck disable=SC2034  # consumed by link_one in lib/install.sh
  YADR_LAST_BACKUP="$dest"
  backup_managed_pairs "$dest"
  if [[ "$first" == "1" ]]; then
    if [[ "$BACKUP_ENTRIES" -eq 0 ]]; then info "nothing to back up (clean HOME). Dir: ${dest}"; fi
    if write_state_pointer last-install-backup "$dest"; then
      write_state_pointer last-backup "$dest" || warn "cannot record last-backup pointer."
      ok "install backup at ${dest} (${BACKUP_ENTRIES} entries)"
    else
      warn "cannot record last-install-backup; uninstall --purge will refuse."
    fi
  else
    current_install="$(install_backup_path 2>/dev/null || true)"
    if [[ -n "$current_install" ]]; then
      info "install backup preserved: ${current_install}"
    else
      warn "existing YADR links but no valid last-install-backup; not creating one from the current links."
      info "uninstall --purge will refuse until a real install backup exists."
    fi
    if [[ "$BACKUP_ENTRIES" -eq 0 ]]; then
      info "nothing to back up (clean HOME). Dir: ${dest}"
    else
      info "reinstall diagnostic backup: ${dest} (${BACKUP_ENTRIES} entries; pointers unchanged)"
    fi
  fi
  if [[ "$BACKUP_FAILED" -gt 0 ]]; then
    warn "${BACKUP_FAILED} backup(s) failed; affected real paths will not be replaced."
  fi
}

do_update_backup() {
  # Update snapshot: diagnostics only. It must never become uninstall's source.
  local ts dest
  ts="$(timestamp)"; dest="${BACKUP_ROOT}/update-${ts}"
  if ! mkdir -p "$dest" 2>/dev/null; then warn "cannot create update backup ${dest}"; return 1; fi
  # shellcheck disable=SC2034  # kept for symmetry with install/manual backups
  YADR_LAST_BACKUP="$dest"
  backup_managed_pairs "$dest"
  if [[ "$BACKUP_FAILED" -gt 0 ]]; then
    warn "update backup incomplete (${BACKUP_FAILED} failed); last-update-backup not advanced."
    return 1
  fi
  if write_state_pointer last-update-backup "$dest"; then
    info "update backup at ${dest} (${BACKUP_ENTRIES} entries)"
  else
    warn "cannot record last-update-backup."
    return 1
  fi
  return 0
}

do_migrate() {
  # Imports classic YADR customization into YADR 2027. Idempotent.
  # Untouched repo: files go to <yadr config>/migrated/ + backup.
  # Usage: yadr migrate [--dry-run]
  local dry=0
  [[ "${1:-}" == "--dry-run" ]] && dry=1
  local dest
  dest="${BACKUP_ROOT}/migrate-$(timestamp)"
  local migdir; migdir="$(yadr_config_dir)/migrated"
  info "Classic YADR → 2027 (dry-run=${dry})"
  [[ -d "${HOME}/.yadr" && -f "${HOME}/.yadr/Rakefile" ]] || info "no classic ~/.yadr; migrating loose files if any."
  local found=0
  local f src dst
  # "<file in HOME>=<absolute destination>"; "keep:" = honored by include/source
  # already, so only its presence is reported.
  while IFS='=' read -r f dst; do
    [[ -n "$f" ]] || continue
    src="${HOME}/${f}"
    [[ -e "$src" ]] || continue
    found=$((found+1))
    if [[ "$dry" == "1" ]]; then
      info "  would migrate: ${src} → ${dst}"
      continue
    fi
    case "$dst" in
      keep:*) info "  keeping: ${src} (${dst#keep:})" ;;
      *)
        backup_one "$src" "$dest" >/dev/null || true
        mkdir -p "$(dirname "$dst")" 2>/dev/null || true
        cp_preserve "$src" "$dst" && info "  migrated: ${src} → ${dst}"
        ;;
    esac
  done <<EOF
.vimrc.before=${migdir}/vimrc.before
.vimrc.after=${migdir}/vimrc.after
.vundles.local=${migdir}/vundles.local
.secrets=${migdir}/secrets
.gitconfig.user=keep:already included via include
.tmux.conf.user=keep:already included via source
EOF
  [[ "$found" -eq 0 ]] && info "nothing classic to migrate."
  [[ "$dry" == "1" ]] && info "dry-run: nothing modified." || ok "migrate complete (backup in ${dest})."
}

restore_backup_entry() { # restore_backup_entry <backup-entry> <dest> <materialize>
  local cand="$1" dst="$2" materialize="${3:-0}" target=""
  if [[ "$materialize" == "1" && -L "$cand" ]]; then
    target="$(readlink "$cand" 2>/dev/null || true)"
    [[ -n "$target" ]] || { warn "  broken backup symlink: ${cand} (not restoring ${dst})"; return 1; }
    case "$target" in
      "${YADR_HOME}/"*)
        if [[ ! -e "$target" ]]; then
          warn "  backup target missing: ${target} (not restoring ${dst})"
          return 1
        fi
        if cp_preserve "$target" "$dst"; then info "  restored (materialized): ${dst}"; return 0; fi
        warn "  could not materialize ${dst}"; return 1
        ;;
    esac
  fi
  if cp_preserve "$cand" "$dst"; then info "  restored: ${dst}"; return 0; fi
  warn "  could not restore ${dst}"; return 1
}

do_uninstall() {
  # Reverts install: removes ONLY symlinks pointing at $YADR_HOME, restores
  # the install-time backup and reverts the login shell.
  # Usage: yadr uninstall [--dry-run] [--purge]
  # --purge also deletes clone, state, nvim plugins and toolchains, but only
  # when a valid last-install-backup exists; legacy installs are never purged.
  # Without TTY nothing runs (like install chsh).
  local dry=0 purge=0
  local a
  for a in "$@"; do
    [[ -z "$a" ]] && continue
    case "$a" in --dry-run) dry=1 ;; --purge) purge=1 ;; *) die "uninstall: unknown flag '$a' (--dry-run|--purge)" ;; esac
  done
  info "YADR 2027 $(version_str) — uninstall (dry-run=${dry} purge=${purge})"

  local install_backup=""
  install_backup="$(install_backup_path 2>/dev/null || true)"
  if [[ "$purge" == "1" && -z "$install_backup" ]]; then
    if [[ "$dry" == "1" ]]; then
      warn "would refuse --purge: no valid last-install-backup."
      info "dry-run: nothing modified."
      return 1
    fi
    err "refusing --purge: no valid last-install-backup."
    info "This install predates v0.9.0 or its install backup is missing."
    info "Backups are preserved in: ${BACKUP_ROOT}"
    info "Run 'yadr uninstall' without --purge to restore best effort, then inspect them."
    return 1
  fi

  # 1. Inventory: which YADR symlinks would go.
  local linked=() foreign=()
  local rel dst
  while IFS=: read -r rel dst; do
    [[ -z "$rel" ]] && continue
    if [[ -L "$dst" ]]; then
      local target; target="$(readlink "$dst")"
      if [[ "$target" == "${YADR_HOME}/"* ]]; then linked+=("$dst"); else foreign+=("$dst (points at ${target}, kept)"); fi
    elif [[ -e "$dst" ]]; then
      foreign+=("$dst (real file, kept)")
    fi
  done < <(managed_pairs)
  local last="$install_backup" last_source="install"
  if [[ -z "$last" ]]; then
    last_source="legacy"
    [[ -f "${STATE_DIR}/last-backup" ]] && last="$(cat "${STATE_DIR}/last-backup" 2>/dev/null)"
  fi
  local prev=""; [[ -f "${STATE_DIR}/prev-shell" ]] && prev="$(cat "${STATE_DIR}/prev-shell" 2>/dev/null)"
  printf '\n%sWould remove %d symlinks:%s\n' "$BOLD" "${#linked[@]}" "$RESET"
  if [[ ${#linked[@]} -gt 0 ]]; then
    printf '  %s\n' "${linked[@]}"
  else
    printf '  %s\n' '(none)'
  fi
  if [[ ${#foreign[@]} -gt 0 ]]; then printf '%sKept (not YADR):%s\n' "$DIM" "$RESET"; printf '  %s\n' "${foreign[@]}"; fi
  local comp_files; comp_files="$(completions_inventory)"
  if [[ -n "$comp_files" ]]; then printf '%sWould remove shell completions:%s\n' "$BOLD" "$RESET"; printf '%s\n' "$comp_files"; fi
  if [[ -n "$last" && -d "$last" ]]; then
    info "Would restore backup: ${last}"
    if [[ "$last_source" == "legacy" ]]; then
      warn "legacy backup: no valid last-install-backup; original pre-install content is not guaranteed."
    fi
  else
    warn "No prior backup to restore."
  fi
  if [[ "${SHELL:-}" == *zsh* && -n "$prev" && "$prev" != *zsh* ]]; then
    info "Would revert login shell to: ${prev}"
  fi
  if [[ "$dry" == "1" ]]; then info "dry-run: nothing modified."; return 0; fi
  confirm "Uninstall YADR 2027 and restore your previous config?" || { info "uninstall cancelled; nothing modified."; return 0; }

  # 2. Purge intent first: materialization depends on the second confirmation.
  local do_purge=0
  if [[ "$purge" == "1" ]]; then
    if confirm "Also delete clone, backups, and YADR-added plugins/toolchains? (pre-existing data is kept; no way back for the rest)"; then
      do_purge=1
    else
      info "purge skipped."
    fi
  fi

  # 3. Remove symlinks + restore the install backup (never the update snapshot).
  local d
  if [[ ${#linked[@]} -gt 0 ]]; then
    for d in "${linked[@]}"; do rm -f "$d" && info "  removed: ${d}"; done
  fi
  remove_completions
  if [[ -n "$last" && -d "$last" ]]; then
    while IFS=: read -r _rel dst; do
      [[ -z "$dst" ]] && continue
      local base cand
      base="$(basename "$dst")"; cand="${last}/${base}"
      [[ -e "$cand" || -L "$cand" ]] || cand="${last}/$(printf '%s' "$dst" | tr '/' '_')"
      if [[ -e "$cand" || -L "$cand" ]]; then
        # Only restore where the YADR symlink was removed. A real path here
        # was kept as foreign; copying a directory backup over it would nest
        # the backup inside (for example ~/.config/nvim/nvim).
        if [[ -e "$dst" || -L "$dst" ]]; then
          info "  kept existing: ${dst} (not a YADR symlink)"
          continue
        fi
        mkdir -p "$(dirname "$dst")" 2>/dev/null || true
        restore_backup_entry "$cand" "$dst" "$do_purge" || true
      fi
    done < <(managed_pairs)
  fi
  # Empty YADR dirs (only if left empty).
  rmdir "$(yadr_config_dir)" 2>/dev/null || true

  # 4. Previous login shell.
  if [[ "${SHELL:-}" == *zsh* && -n "$prev" && "$prev" != *zsh* && "$prev" != "unknown" ]]; then
    if [[ -t 0 ]]; then
      chsh -s "$prev" && ok "login shell restored to ${prev}." || warn "chsh failed. Manual: chsh -s ${prev}"
    else
      warn "no TTY: cannot ask your password. Manual: chsh -s ${prev}"
    fi
  fi

  # 5. Optional purge (data: clone, state, nvim plugins and toolchains).
  if [[ "$do_purge" == "1" ]]; then
    # ~/.local/bin: only what YADR installed (provides-* markers); never
    # pre-existing user binaries.
    [[ -f "${STATE_DIR}/provides-nvim-upstream" ]] && rm -rf "${HOME}/.local/nvim-upstream" "${HOME}/.local/bin/nvim" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-vim" ]] && rm -f "${HOME}/.local/bin/vim" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-mise" ]] && rm -f "${HOME}/.local/bin/mise" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-zoxide" ]] && rm -f "${HOME}/.local/bin/zoxide" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-lazygit" ]] && rm -f "${HOME}/.local/bin/lazygit" 2>/dev/null || true
    # tools: drop the mise conf.d fragment YADR wrote (never the user's own).
    [[ -f "${STATE_DIR}/provides-tools" ]] && rm -f "$(mise_config_dir)/conf.d/yadr-tools.toml" 2>/dev/null || true
    # Share/cache dirs: only YADR-added entries go (pre-existing content
    # recorded at first install always survives). Runs before STATE_DIR
    # itself is removed (snapshots live there). Same list as the snapshot:
    # share_dirs computes both, so purge and snapshot cannot diverge (ADR-005).
    local _tag _dir
    while IFS=$'\t' read -r _tag _dir; do
      [[ -n "$_tag" ]] || continue
      purge_dir_keep_preexisting "$_dir" "$_tag"
    done < <(share_dirs)
    rm -rf "${YADR_HOME}" "${STATE_DIR}" 2>/dev/null || true
    ok "purge complete."
  else
    info "Kept (your data): ${YADR_HOME} ${STATE_DIR} nvim-plugins mise-toolchains."
  fi
  info "System packages (if platform/ installed them): remove by hand, e.g. sudo apt remove zsh tmux neovim ripgrep fd-find fzf zsh-syntax-highlighting zsh-autosuggestions."
  ok "uninstall complete. Restart your terminal."
}
