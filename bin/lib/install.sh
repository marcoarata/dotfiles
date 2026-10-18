#!/usr/bin/env bash
# YADR 2027 — lib/install.sh: install/update flows plus platform and editor helpers
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.

detect_rogue_checkouts() {
  # A single sanctioned checkout: $YADR_HOME. Hand-made versioned copies
  # (~/yadr2027v4.0, ~/dotfiles-old…) plus cross symlinks produce ghost
  # states: nvim loads config from another checkout and nothing is
  # reproducible. This detects it before it bites.
  local found=0 d target
  for d in "${HOME}"/yadr* "${HOME}"/dotfiles*; do
    [[ -e "$d" || -L "$d" ]] || continue
    [[ "$d" == "${YADR_HOME}" ]] && continue
    [[ "$d" == "${YADR_HOME}/"* ]] && continue
    warn "rogue checkout detected: ${d} (sanctioned: ${YADR_HOME})"
    found=1
  done
  for link in "${HOME}/.config/nvim" "${HOME}/.zshrc" "${HOME}/.gitconfig" "${HOME}/.tmux.conf"; do
    if [[ -L "$link" ]]; then
      target="$(readlink "$link")"
      [[ "$target" == /* ]] || target="${HOME}/${target}"
      case "$target" in
        "${YADR_HOME}/"*) ;;
        *) warn "foreign symlink: ${link} → ${target} (kept; YADR uses ${YADR_HOME})"; found=1 ;;
      esac
    fi
  done
  if [[ "$found" == "1" ]]; then
    warn "rogue checkout/symlinks outside ${YADR_HOME}: use a single clone; the rest confuses nvim/lazy."
  fi
  return 0
}

detect_platform_script() {
  # YADR_PROC_VERSION is a test seam (defaults to the real file) so the WSL
  # branch can be exercised without a WSL host.
  local pv="${YADR_PROC_VERSION:-/proc/version}"
  if [[ "$(uname -s)" == "Darwin" ]]; then echo "${YADR_HOME}/platform/macos.sh"
  elif grep -qi microsoft "$pv" 2>/dev/null; then echo "${YADR_HOME}/platform/wsl.sh"
  else echo "${YADR_HOME}/platform/linux.sh"
  fi
}

handle_legacy_yadr() {
  # Classic YADR: ~/.yadr + Rakefile. Default: parallel (safe coexistence).
  [[ -d "${HOME}/.yadr" && -f "${HOME}/.yadr/Rakefile" ]] || return 0
  [[ "${YADR_HOME}" == "${HOME}/.yadr" ]] && return 0  # inside the old one
  warn "Classic YADR detected in ~/.yadr (with Rakefile)."
  info "options: [p]arallel (default, coexists) · [m]igrate (imports and retires) · [c]ancel"
  local ans=""
  if [[ "${YADR_YES:-0}" == "1" ]]; then ans="p"; else printf 'Choose [p/m/c] (Enter = parallel): ' >&2; IFS= read -r ans || true; ans="${ans:-p}"; fi
  case "$ans" in
    m|M|migrate)
      info "migrating: backing up the old + importing customs…"
      local b
      b="${BACKUP_ROOT}/legacy-$(timestamp)"
      mkdir -p "$b"
      backup_one "${HOME}/.yadr" "$b" >/dev/null || true
      local f
      for f in .vimrc.before .vimrc.after .gitconfig.user .tmux.conf.user; do
        backup_one "${HOME}/${f}" "$b" >/dev/null || true
      done
      ok "classic backed up in ${b}. Your ~/.yadr stays intact (rename it when you want)."
      ;;
    c|C|cancel) info "cancelled by user."; exit 0 ;;
    *) info "parallel mode: YADR 2027 installs in ${YADR_HOME}; your ~/.yadr untouched." ;;
  esac
}

link_one() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then ok "  already linked: ${dst}"; return 0; fi
  ln -sfn "$src" "$dst"
  ok "  linked: ${dst} → ${src}"
}

ensure_login_shell() {
  # Faithful to classic YADR (Rakefile install_prezto): sets zsh as login shell
  # with no extra prompt. Without TTY (CI/headless) skipped with notice.
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"
  [[ -n "$zsh_path" ]] || { warn "no zsh installed; skipping login shell."; return 0; }
  if [[ "${SHELL:-}" == *zsh* ]]; then
    info "zsh is already your default shell (${SHELL}). Restart your session to load changes."
    return 0
  fi
  info "setting zsh as default shell…"
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    info "adding ${zsh_path} to /etc/shells (only step with sudo)…"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null \
      || { warn "could not update /etc/shells. Manual: echo ${zsh_path} | sudo tee -a /etc/shells && chsh -s ${zsh_path}"; return 0; }
  fi
  if [[ -t 0 ]]; then
    chsh -s "$zsh_path" \
      || warn "chsh failed. Manual: chsh -s ${zsh_path}"
  else
    warn "no TTY: chsh needs your password. Manual: chsh -s ${zsh_path}"
  fi
}

success_msg() {
  cat <<'EOF'

   _     _           _
  | |   | |         | |
  | |___| |_____  __| | ____
  |_____  (____ |/ _  |/ ___)
   _____| / ___ ( (_| | |
  (_______\_____|\____|_|

EOF
  ok "YADR 2027 installed. Reboot to load zsh by default (or run 'exec zsh' to try now; and restart vim)."
}

next_steps() {
  # Post-install guide (mirrors the numbered steps in README/INSTALL-YADR).
  printf '%s\n' "${DIM}next steps:${RESET}"
  printf '  %s\n' \
    "1. exec zsh (or reboot and open a terminal)" \
    "2. yadr doctor (slow ONCE: installs nvim plugins)" \
    "3. yadr doctor (again: instant, shows the real state)" \
    "4. yadr install <whatever is still missing> until 0 errors / 0 warnings" \
    "   profiles: node|python|typescript|ruby|rust|lazygit|tools — theme: yadr theme list"
}

runtime_tool_for() { # profile -> "tool" list (mise). Never exposes mise to the user.
  case "$1" in
    core)       echo "" ;;
    node|typescript) echo "node pnpm" ;;
    ruby)       echo "ruby" ;;
    python)     echo "python" ;;
    rust)       echo "rust" ;;
    development) echo "node pnpm python rust ruby" ;;
    macos-extras) echo "" ;;
    lazygit) echo "" ;;
    tools) echo "" ;;
    *) echo "" ;;
  esac
}

lazy_restore() { # one headless `Lazy! restore`; 0 on success (caller reports)
  run_timeout 600 nvim --headless "+Lazy! restore" +qa 2>&1 | tail -n 5
}

# Set by ensure_nvim_plugins once it has run `Lazy! restore` in this process, so
# ensure_lsp_servers (called right after it for the same profile) does not launch
# nvim a second time to do the same lockfile sync. Empty on a standalone call.
_YADR_NVIM_RESTORED=""

ensure_nvim_plugins() {
  # Restores plugins exactly to the lockfile (Lazy! restore downgrades
  # any plugin ahead of its pin; fixes stale/broken checkouts).
  have nvim || return 0
  [[ -d "${HOME}/.local/share/nvim/lazy/lazy.nvim" ]] || return 0
  # Leftover interrupted clones (*.cloning) block reinstalls.
  local stale
  for stale in "${HOME}"/.local/share/nvim/lazy/*.cloning; do
    [[ -e "$stale" ]] || continue
    warn "cleaning interrupted clone: $(basename "$stale")"
    rm -rf "$stale"
  done
  info "restoring Neovim plugins to lockfile (Lazy! restore)…"
  if lazy_restore; then
    ok "plugins match the lock."
  else
    warn "restore incomplete; open nvim and run :Lazy restore."
  fi
  # Report to ensure_lsp_servers that the lockfile sync already happened.
  _YADR_NVIM_RESTORED=1
  # Cleans orphans (plugins no longer in the spec: lualine, devicons…).
  # Without them, Telescope and others cannot re-enable Nerd icons on their own.
  info "cleaning orphan plugins (Lazy! clean)…"
  if run_timeout 300 nvim --headless "+Lazy! clean" +qa 2>&1 | tail -n 4; then
    ok "no orphans."
  else
    warn "clean incomplete; open nvim and run :Lazy clean."
  fi
}

ensure_lsp_servers() {
  # Pack typescript: lazy plugins + 5 contract servers via Mason.
  # (Replaces mason-lspconfig ensure_installed, removed.)
  # Mandatory order: lazy first (mason.nvim only exists after opening nvim
  # once), Mason after. All visible: nothing to /dev/null.
  # The lazy step is skipped when ensure_nvim_plugins already did it in this
  # run (their common caller ensures both for one profile).
  have nvim || { warn "no nvim; skipping LSP servers."; return 0; }
  if [[ -n "$_YADR_NVIM_RESTORED" ]]; then
    info "lazy plugins already restored by this run; skipping the extra sync."
  else
    info "syncing Neovim plugins to lockfile (restore; slow the first time)…"
    if lazy_restore; then
      ok "plugins synced."
    else
      warn "Lazy restore failed or took >10min; open nvim and run :Lazy restore."
      return 0
    fi
  fi
  [[ -d "${HOME}/.local/share/nvim/lazy/mason.nvim" ]] || { warn "mason still absent after sync; open nvim and retry yadr install typescript."; return 0; }
  info "installing LSP servers (mason, may take a while)…"
  if run_timeout 900 nvim --headless -c "MasonInstall typescript-language-server bash-language-server lua-language-server json-lsp marksman" -c "qa" 2>&1 | tail -n 8; then
    ok "LSP servers ready."
  else
    warn "some server failed; open nvim and run :Mason to complete."
  fi
}

snapshot_share_dirs() { # records pre-existing share/cache entries once (first install wins)
  # Purge later deletes everything EXCEPT these entries, so user data that
  # predates YADR always survives. Filenames with newlines are out of scope.
  local d tag snap
  for d in "${HOME}/.local/share/nvim" "${HOME}/.local/share/mise" "${HOME}/.local/share/zoxide" "${HOME}/.cache/nvim" "${HOME}/.local/state/nvim"; do
    case "$d" in
      *share/nvim)  tag="share-nvim" ;;
      *share/mise)  tag="share-mise" ;;
      *share/zoxide) tag="share-zoxide" ;;
      *cache/nvim)  tag="cache-nvim" ;;
      *state/nvim)  tag="state-nvim" ;;
    esac
    snap="${STATE_DIR}/preexisting-${tag}"
    [[ -f "$snap" ]] && continue
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    if [[ -d "$d" ]]; then ls -A "$d" > "$snap" 2>/dev/null || true; else : > "$snap"; fi
  done
}

purge_dir_keep_preexisting() { # $1 = dir, $2 = snapshot tag: deletes all but recorded entries
  local dir="$1" snap="${STATE_DIR}/preexisting-$2" entry
  [[ -d "$dir" ]] || return 0
  if [[ ! -f "$snap" ]]; then
    warn "no pre-install snapshot for ${dir}; leaving it untouched (refusing blind wipe)."
    return 0
  fi
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -z "$entry" ]] && continue
    if grep -Fxq -- "$entry" "$snap" 2>/dev/null; then
      info "  kept (pre-existing): ${dir}/${entry}"
    else
      rm -rf "${dir:?}/${entry:?}" 2>/dev/null && info "  purged: ${dir}/${entry}" || warn "  could not purge ${dir}/${entry}"
    fi
  done < <(ls -A "$dir" 2>/dev/null)
  rmdir "$dir" 2>/dev/null || true
}

links_uptodate() { # 0 when every managed pair is already as it should be (silent)
  local rel dst src
  while IFS=: read -r rel dst; do
    [[ -z "$rel" ]] && continue
    src="${YADR_HOME}/${rel}"
    [[ -e "$src" || -L "$src" ]] || return 1
    if [[ -d "$src" && -d "$dst" && ! -L "$src" && ! -L "$dst" ]]; then
      diff -r -q "$src" "$dst" >/dev/null 2>&1 || return 1
    elif [[ -f "$src" && -f "$dst" && ! -L "$dst" ]]; then
      cmp -s "$src" "$dst" || return 1
    else
      [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]] || return 1
    fi
  done < <(managed_pairs)
  return 0
}

ensure_profile_payload() { # runtimes + editor for one profile (shared by fast/full paths)
  # Returns non-zero when a runtime could not be ensured. Callers must not
  # claim success then: a failed `mise install` used to end in
  # "install [node] complete" + exit 0, which is a lie the user only notices
  # in `yadr doctor` (or when the prompt shows nothing).
  local profile="$1" tools rc=0
  tools="$(runtime_tool_for "$profile")"
  if [[ -n "$tools" ]]; then
    info "profile ${profile}: ensuring runtimes (${tools})…"
    for t in $tools; do
      cmd_runtime_use "$t" || { warn "could not ensure ${t}; install with: yadr runtime use ${t}"; rc=1; }
    done
  fi
  # Neovim plugins matching lockfile (all profiles with nvim).
  ensure_nvim_plugins || true
  # Pack TypeScript: contract LSP servers.
  if [[ "$profile" == "typescript" || "$profile" == "development" ]]; then
    ensure_lsp_servers || true
  fi
  return "$rc"
}

do_install() {
  local profile="${1:-core}"
  case "$profile" in core|node|typescript|ruby|python|rust|development|macos-extras|lazygit|tools) ;; *) die "unknown profile: $profile (core|node|typescript|ruby|python|rust|development|macos-extras|lazygit|tools)" ;; esac
  handle_legacy_yadr
  detect_rogue_checkouts
  info "YADR 2027 $(version_str) — install [${profile}] in ${YADR_HOME}"
  # Save the previous login shell once (uninstall restores it exactly).
  if [[ ! -f "${STATE_DIR}/prev-shell" ]]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    printf '%s' "${SHELL:-unknown}" > "${STATE_DIR}/prev-shell" 2>/dev/null || true
  fi
  snapshot_share_dirs
  if [[ "$profile" == "macos-extras" ]]; then
    [[ "$(uname -s)" == "Darwin" ]] || die "macos-extras on macOS only."
    confirm "Apply optional macOS defaults (platform/macos-extras.sh)?" || { info "cancelled."; return 0; }
    bash "${YADR_HOME}/platform/macos-extras.sh" || warn "extras returned an error."
    ok "macos-extras applied (optional, outside core)."
    return 0
  fi
  if [[ "$profile" == "lazygit" ]]; then
    info "installing lazygit (per-OS logic in platform/lazygit.sh)…"
    bash "${YADR_HOME}/platform/lazygit.sh" && ok "lazygit ready." || warn "lazygit failed (see above)."
    return 0
  fi
  if [[ "$profile" == "tools" ]]; then
    info "installing modern CLI tools (eza/bat/delta via platform/tools.sh)…"
    bash "${YADR_HOME}/platform/tools.sh" && ok "CLI tools ready." || warn "CLI tools failed (see above)."
    return 0
  fi
  case "$profile" in node|typescript|ruby|python|rust|development)
    # Fast path: core links already correct → only the profile payload
    # (runtimes + editor), no platform rerun, no diff/confirm/backup/relink.
    # Anything else (or stale links) keeps the full safe flow.
    if links_uptodate; then
      info "core links up to date — fast path (no platform, symlinks or confirmations)."
      if ensure_profile_payload "$profile"; then
        ok "install [${profile}] complete (fast path). Run 'yadr doctor' to verify."
        next_steps
        return 0
      fi
      err "install [${profile}] incomplete: some runtimes did not install (see above)."
      info "retry with: yadr install ${profile} (or 'yadr runtime use <tool>' for one tool)."
      next_steps
      return 1
    fi
    info "links out of date — full install (with backup and confirmation)."
    ;;
  esac
  local plat; plat="$(detect_platform_script)"
  if [[ -f "$plat" ]]; then info "platform: ${plat}"; bash "$plat" || warn "platform script errored; continuing with symlinks."
  else warn "platform script not found: ${plat}; continuing."
  fi
  # Profile runtimes via `runtime` abstraction (mise inside)
  local payload_rc=0
  ensure_profile_payload "$profile" || payload_rc=1
  info "change preview (diff):"
  do_diff
  confirm "Apply symlinks (with prior automatic backup)?" || { info "install cancelled; nothing modified."; return 0; }
  do_backup
  local n=0 skipped=0
  while IFS=: read -r rel dst; do
    [[ -z "$rel" ]] && continue
    local src="${YADR_HOME}/${rel}"
    if [[ ! -e "$src" && ! -L "$src" ]]; then warn "  skipping ${rel} (not in checkout)"; skipped=$((skipped+1)); continue; fi
    link_one "$src" "$dst"; n=$((n+1))
  done < <(managed_pairs)
  ensure_login_shell
  if [[ "$payload_rc" == "0" ]]; then
    success_msg
    info "install complete: ${n} links, ${skipped} pending from repo. Run 'yadr doctor' to verify."
  else
    err "symlinks applied (${n} links) but some runtimes did not install (see above)."
    info "retry with: yadr install ${profile} (or 'yadr runtime use <tool>' for one tool)."
  fi
  next_steps
  return "$payload_rc"
}

dirty_tree_list() { # prints up to 5 dirty paths of the live checkout, empty when clean/no-git
  [[ -d "${YADR_HOME}/.git" ]] || return 0
  git -C "$YADR_HOME" status --porcelain 2>/dev/null | head -n 5
}

do_update() {
  info "updating YADR 2027…"
  if [[ -d "${YADR_HOME}/.git" ]]; then
    local _dirty; _dirty="$(dirty_tree_list)"
    if [[ -n "$_dirty" ]]; then
      warn "live checkout has local modifications (pull --ff-only may refuse):"
      printf '%s\n' "$_dirty" >&2
      info "stash, commit or discard them in ${YADR_HOME} first (often just nvim/lazy-lock.json from Lazy sync)."
    fi
    confirm "Update repo (git pull --ff-only in ${YADR_HOME})?" || { info "update cancelled."; return 0; }
    do_backup
    git -C "$YADR_HOME" pull --ff-only || warn "pull failed (conflicts or offline). Fix by hand."
    ok "repo updated."
    ensure_nvim_plugins || true
  else
    warn "no .git in ${YADR_HOME}; nothing to update (local checkout)."
  fi
  if have mise; then mise upgrade 2>/dev/null || mise up 2>/dev/null || warn "mise upgrade failed."; fi
}
