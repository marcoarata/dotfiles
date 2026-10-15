#!/usr/bin/env bash
# YADR 2027 — lib/recover.sh: install/uninstall/migrate/pack flows plus backup helpers
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

do_backup() {
  # do_backup: backs up managed pairs. (migrate/legacy use backup_one directly.)
  local ts dest n=0
  ts="$(timestamp)"; dest="${BACKUP_ROOT}/${ts}"
  mkdir -p "$dest"
  while IFS=: read -r _rel dst; do
    [[ -z "$dst" ]] && continue
    local got
    if got="$(backup_one "$dst" "$dest")"; then
      n=$((n+1)); info "backup: ${dst} → ${got}"
    fi
  done < <(managed_pairs)
  echo "$dest" > "${STATE_DIR}/last-backup" 2>/dev/null || true
  if [[ "$n" -eq 0 ]]; then info "nothing to back up (clean HOME). Dir: ${dest}"; else ok "backup at ${dest} (${n} entries)"; fi
}

do_migrate() {
  # Imports classic YADR customization into YADR 2027. Idempotent.
  # Untouched repo: files go to ~/.config/yadr/migrated/ + backup.
  # Usage: yadr migrate [--dry-run]
  local dry=0
  [[ "${1:-}" == "--dry-run" ]] && dry=1
  local dest
  dest="${BACKUP_ROOT}/migrate-$(timestamp)"
  local migdir="${HOME}/.config/yadr/migrated"
  info "Classic YADR → 2027 (dry-run=${dry})"
  [[ -d "${HOME}/.yadr" && -f "${HOME}/.yadr/Rakefile" ]] || info "no classic ~/.yadr; migrating loose files if any."
  local found=0
  local f src rel
  for f in .vimrc.before:.config/yadr/migrated/vimrc.before .vimrc.after:.config/yadr/migrated/vimrc.after .vundles.local:.config/yadr/migrated/vundles.local .gitconfig.user:"(already included via include, kept)" .tmux.conf.user:"(already included via source, kept)" .secrets:.config/yadr/migrated/secrets; do
    src="${HOME}/${f%%:*}"; rel="${f##*:}"
    [[ -e "$src" ]] || continue
    found=$((found+1))
    if [[ "$dry" == "1" ]]; then
      info "  would migrate: ${src} → ${rel}"
    else
      mkdir -p "$migdir" 2>/dev/null || true
      backup_one "$src" "$dest" >/dev/null || true
      case "$rel" in \(*) info "  keeping: ${src} ${rel}" ;;
        *) mkdir -p "$(dirname "${HOME}/${rel}")"; cp_preserve "$src" "${HOME}/${rel}" && info "  migrated: ${src} → ${HOME}/${rel}" ;;
      esac
    fi
  done
  [[ "$found" -eq 0 ]] && info "nothing classic to migrate."
  [[ "$dry" == "1" ]] && info "dry-run: nothing modified." || ok "migrate complete (backup in ${dest})."
}

do_pack_list() {
  info "available packs (packs/<name>/):"
  local d name desc
  for d in "${YADR_HOME}"/packs/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    desc="$(grep -m1 -E '^# ' "$d/README.md" 2>/dev/null | sed 's/^# //')"
    printf '  %-12s %s\n' "$name" "${desc:-pack YADR}"
  done
}

do_pack_add() { # do_pack_add <pack> — same as the matching install profile
  local pack="${1:?usage: yadr pack add <name>  (see: yadr pack list)}"
  [[ -d "${YADR_HOME}/packs/${pack}" ]] || die "unknown pack: ${pack} (see: yadr pack list)"
  local profile="$pack"
  case "$pack" in javascript) profile="node" ;; esac
  info "pack '${pack}' → install [${profile}]"
  do_install "$profile"
}

do_uninstall() {
  # Reverts install: removes ONLY symlinks pointing at $YADR_HOME, restores
  # last-backup and reverts the login shell. Usage: yadr uninstall [--dry-run] [--purge]
  # --purge also deletes clone, state, nvim plugins and toolchains (data, confirmation).
  # Without TTY nothing runs (like install chsh).
  local dry=0 purge=0
  local a
  for a in "$@"; do
    [[ -z "$a" ]] && continue
    case "$a" in --dry-run) dry=1 ;; --purge) purge=1 ;; *) die "uninstall: unknown flag '$a' (--dry-run|--purge)" ;; esac
  done
  info "YADR 2027 $(version_str) — uninstall (dry-run=${dry} purge=${purge})"
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
  local last=""; [[ -f "${STATE_DIR}/last-backup" ]] && last="$(cat "${STATE_DIR}/last-backup" 2>/dev/null)"
  local prev=""; [[ -f "${STATE_DIR}/prev-shell" ]] && prev="$(cat "${STATE_DIR}/prev-shell" 2>/dev/null)"
  printf '\n%sWould remove %d symlinks:%s\n' "$BOLD" "${#linked[@]}" "$RESET"
  printf '  %s\n' "${linked[@]:-(none)}"
  if [[ ${#foreign[@]} -gt 0 ]]; then printf '%sKept (not YADR):%s\n' "$DIM" "$RESET"; printf '  %s\n' "${foreign[@]}"; fi
  [[ -n "$last" && -d "$last" ]] && info "Would restore backup: ${last}" || warn "No prior backup to restore."
  if [[ "${SHELL:-}" == *zsh* && -n "$prev" && "$prev" != *zsh* ]]; then
    info "Would revert login shell to: ${prev}"
  fi
  if [[ "$dry" == "1" ]]; then info "dry-run: nothing modified."; return 0; fi
  confirm "Uninstall YADR 2027 and restore your previous config?" || { info "uninstall cancelled; nothing modified."; return 0; }
  # 2. Remove symlinks + restore backup.
  local d
  for d in "${linked[@]}"; do rm -f "$d" && info "  removed: ${d}"; done
  if [[ -n "$last" && -d "$last" ]]; then
    while IFS=: read -r _rel dst; do
      [[ -z "$dst" ]] && continue
      local base cand
      base="$(basename "$dst")"; cand="${last}/${base}"
      [[ -e "$cand" || -L "$cand" ]] || cand="${last}/$(printf '%s' "$dst" | tr '/' '_')"
      if [[ -e "$cand" || -L "$cand" ]]; then
        mkdir -p "$(dirname "$dst")" 2>/dev/null || true
        cp_preserve "$cand" "$dst" && info "  restored: ${dst}" || warn "  could not restore ${dst}"
      fi
    done < <(managed_pairs)
  fi
  # Empty YADR dirs (only if left empty).
  rmdir "${HOME}/.config/yadr" 2>/dev/null || true
  # 3. Previous login shell.
  if [[ "${SHELL:-}" == *zsh* && -n "$prev" && "$prev" != *zsh* && "$prev" != "unknown" ]]; then
    if [[ -t 0 ]]; then
      chsh -s "$prev" && ok "login shell restored to ${prev}." || warn "chsh failed. Manual: chsh -s ${prev}"
    else
      warn "no TTY: cannot ask your password. Manual: chsh -s ${prev}"
    fi
  fi
  # 4. Optional purge (data: clone, state, nvim plugins and toolchains).
  local do_purge=0
  if [[ "$purge" == "1" ]]; then
    if confirm "Also delete clone, backups, and YADR-added plugins/toolchains? (pre-existing data is kept; no way back for the rest)"; then
      do_purge=1
    else
      info "purge skipped."
    fi
  fi
  if [[ "$do_purge" == "1" ]]; then
    # ~/.local/bin: only what YADR installed (provides-* markers); never
    # pre-existing user binaries.
    [[ -f "${STATE_DIR}/provides-nvim-upstream" ]] && rm -rf "${HOME}/.local/nvim-upstream" "${HOME}/.local/bin/nvim" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-vim" ]] && rm -f "${HOME}/.local/bin/vim" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-mise" ]] && rm -f "${HOME}/.local/bin/mise" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-zoxide" ]] && rm -f "${HOME}/.local/bin/zoxide" 2>/dev/null || true
    [[ -f "${STATE_DIR}/provides-lazygit" ]] && rm -f "${HOME}/.local/bin/lazygit" 2>/dev/null || true
    # Share/cache dirs: only YADR-added entries go (pre-existing content
    # recorded at first install always survives). Runs before STATE_DIR
    # itself is removed (snapshots live there).
    purge_dir_keep_preexisting "${HOME}/.local/share/nvim" "share-nvim"
    purge_dir_keep_preexisting "${HOME}/.local/share/mise" "share-mise"
    purge_dir_keep_preexisting "${HOME}/.local/share/zoxide" "share-zoxide"
    purge_dir_keep_preexisting "${HOME}/.cache/nvim" "cache-nvim"
    purge_dir_keep_preexisting "${HOME}/.local/state/nvim" "state-nvim"
    rm -rf "${YADR_HOME}" "${STATE_DIR}" 2>/dev/null || true
    ok "purge complete."
  else
    info "Kept (your data): ${YADR_HOME} ${STATE_DIR} nvim-plugins mise-toolchains."
  fi
  info "System packages (if platform/ installed them): remove by hand, e.g. sudo apt remove zsh tmux neovim ripgrep fd-find fzf zsh-syntax-highlighting zsh-autosuggestions."
  ok "uninstall complete. Restart your terminal."
}
