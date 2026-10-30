#!/usr/bin/env bash
# YADR 2027 — lib/install.sh: install/update flows plus platform and editor helpers
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.

# shellcheck disable=SC2120  # $1 is optional: the doctor passes "count", install passes nothing
detect_rogue_checkouts() { # $1=count → also adds ONE warning to the doctor total
  # A single sanctioned checkout: $YADR_HOME. Hand-made versioned copies
  # (~/yadr2027v4.0, ~/dotfiles-old…) plus cross symlinks produce ghost
  # states: nvim loads config from another checkout and nothing is
  # reproducible. This detects it before it bites.
  #
  # The per-link lines are detail; the count below is what the doctor summary
  # adds, once, no matter how many links are foreign (calling `detect_rogue_checkouts`
  # from `do_install` passes no argument and leaves DOCTOR_WARN untouched).
  local count="${1:-}"
  local found=0 d target rel link
  for d in "${HOME}"/yadr* "${HOME}"/dotfiles*; do
    [[ -e "$d" || -L "$d" ]] || continue
    [[ "$d" == "${YADR_HOME}" ]] && continue
    [[ "$d" == "${YADR_HOME}/"* ]] && continue
    warn "rogue checkout detected: ${d} (sanctioned: ${YADR_HOME})"
    found=1
  done
  # Every managed destination (not a hardcoded list): with XDG moved, the link
  # is not where the old literal said it was, and the check would miss it.
  while IFS=: read -r rel link; do
    [[ -z "$rel" || -z "$link" ]] && continue
    if [[ -L "$link" ]]; then
      target="$(readlink "$link")"
      [[ "$target" == /* ]] || target="${HOME}/${target}"
      case "$target" in
        "${YADR_HOME}/"*) ;;
        *) warn "foreign symlink: ${link} → ${target} (kept; YADR uses ${YADR_HOME})"; found=1 ;;
      esac
    fi
  done < <(managed_pairs)
  if [[ "$found" == "1" ]]; then
    if [[ "$count" == "count" ]]; then
      dc_warn "rogue checkout/symlinks outside ${YADR_HOME}: use a single clone; the rest confuses nvim/lazy."
    else
      warn "rogue checkout/symlinks outside ${YADR_HOME}: use a single clone; the rest confuses nvim/lazy."
    fi
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
  local src="$1" dst="$2" backup qdir qdst=""
  mkdir -p "$(dirname "$dst")" || { warn "  cannot create parent for ${dst}"; return 1; }

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then ok "  already linked: ${dst}"; return 0; fi
    rm -f "$dst" || { warn "  cannot replace symlink: ${dst}"; return 1; }
    if ! ln -s "$src" "$dst"; then warn "  cannot link ${dst}"; return 1; fi
  elif [[ -e "$dst" ]]; then
    # A real file or directory must have a verified backup before it is moved.
    # ln -sfn treats a real directory as a target directory and would create
    # the link inside it (for example ~/.config/nvim/nvim), leaving the old
    # config active while reporting success.
    backup="${YADR_LAST_BACKUP:-}"
    if [[ -z "$backup" ]] || ! backup_entry_for "$dst" "$backup" >/dev/null; then
      warn "  refusing to replace ${dst}: no verified backup (rerun 'yadr install')"
      return 1
    fi
    qdir="${backup}/displaced"
    mkdir -p "$qdir" || { warn "  cannot create ${qdir}"; return 1; }
    qdst="${qdir}/$(printf '%s' "$dst" | tr '/' '_')"
    if [[ -e "$qdst" || -L "$qdst" ]]; then qdst="${qdst}.$(date +%s).$$"; fi
    if ! mv "$dst" "$qdst"; then
      warn "  cannot move ${dst} aside; leaving it untouched"
      return 1
    fi
    if ! ln -s "$src" "$dst"; then
      mv "$qdst" "$dst" 2>/dev/null || warn "  cannot restore ${dst} from ${qdst}"
      warn "  cannot link ${dst}"
      return 1
    fi
  else
    if ! ln -s "$src" "$dst"; then warn "  cannot link ${dst}"; return 1; fi
  fi

  if [[ ! -L "$dst" || "$(readlink "$dst")" != "$src" ]]; then
    warn "  link verification failed: ${dst}"
    if [[ -n "$qdst" && ( -e "$qdst" || -L "$qdst" ) ]]; then
      rm -f "$dst" 2>/dev/null || true
      mv "$qdst" "$dst" 2>/dev/null || warn "  cannot restore ${dst} from ${qdst}"
    fi
    return 1
  fi
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
  # Post-install guide (mirrors the numbered steps in README).
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
  # Return nvim's status explicitly instead of inheriting it from the caller's
  # `set -o pipefail`: bin/yadr sets that option, but without it the pipeline
  # silently reports `tail`'s status and a crashed or timed-out nvim would look
  # like a clean restore. Capture the output to keep the last lines visible.
  local out rc=0
  out="$(run_timeout 600 nvim --headless "+Lazy! restore" +qa 2>&1)" || rc=$?
  printf '%s\n' "$out" | tail -n 5
  return "$rc"
}

# Set by ensure_nvim_plugins once it has run `Lazy! restore` in this process, so
# ensure_lsp_servers (called right after it for the same profile) does not launch
# nvim a second time to do the same lockfile sync. Empty on a standalone call.
_YADR_NVIM_RESTORED=""

ensure_nvim_plugins() {
  # Restores plugins exactly to the lockfile (Lazy! restore downgrades
  # any plugin ahead of its pin; fixes stale/broken checkouts).
  have nvim || return 0
  # Where Neovim itself keeps them: stdpath("data") follows XDG_DATA_HOME, so a
  # hardcoded ~/.local/share here made this step silently skip on a machine that
  # moved its XDG directories (ADR-005).
  local nvim_data; nvim_data="$(nvim_data_dir)"
  [[ -d "${nvim_data}/lazy/lazy.nvim" ]] || return 0
  # Leftover interrupted clones (*.cloning) block reinstalls.
  local stale
  for stale in "${nvim_data}"/lazy/*.cloning; do
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
  [[ -d "$(nvim_data_dir)/lazy/mason.nvim" ]] || { warn "mason still absent after sync; open nvim and retry yadr install typescript."; return 0; }
  info "installing LSP servers (mason, may take a while)…"
  if run_timeout 900 nvim --headless -c "MasonInstall typescript-language-server bash-language-server lua-language-server json-lsp marksman" -c "qa" 2>&1 | tail -n 8; then
    ok "LSP servers ready."
  else
    warn "some server failed; open nvim and run :Mason to complete."
  fi
}

share_dirs() { # "snapshot-tag<TAB>dir": every directory the purge inventory covers
  # TAB-separated (a moved XDG_DATA_HOME can hold anything but a newline) and
  # explicit about the tag: with XDG relocated, the tag can no longer be derived
  # from the path shape. Single source of truth for snapshot AND purge (ADR-005).
  printf '%s\t%s\n' share-nvim   "$(nvim_data_dir)"
  printf '%s\t%s\n' share-mise   "$(mise_data_dir)"
  printf '%s\t%s\n' share-zoxide "$(zoxide_data_dir)"
  printf '%s\t%s\n' cache-nvim   "$(nvim_cache_dir)"
  printf '%s\t%s\n' state-nvim   "$(nvim_state_dir)"
}

snapshot_share_dirs() { # records pre-existing share/cache entries once (first install wins)
  # Purge later deletes everything EXCEPT these entries, so user data that
  # predates YADR always survives. Filenames with newlines are out of scope.
  local tag d snap
  while IFS=$'\t' read -r tag d; do
    [[ -n "$tag" ]] || continue
    snap="${STATE_DIR}/preexisting-${tag}"
    [[ -f "$snap" ]] && continue
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    if [[ -d "$d" ]]; then ls -A "$d" > "$snap" 2>/dev/null || true; else : > "$snap"; fi
  done < <(share_dirs)
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

managed_pair_count() { # number of destinations the install manages
  local rel n=0
  while IFS=: read -r rel _; do [[ -n "$rel" ]] && n=$((n+1)); done < <(managed_pairs)
  printf '%s' "$n"
}

links_uptodate() { # 0 when every managed pair is already linked (silent)
  local rel dst src
  while IFS=: read -r rel dst; do
    [[ -z "$rel" ]] && continue
    src="${YADR_HOME}/${rel}"
    [[ -e "$src" || -L "$src" ]] || return 1
    # Content equality is not enough: a real file or directory is not managed
    # by YADR until it is a symlink to the checkout. Treating an identical copy
    # as up to date sent the fast path past the link step entirely.
    [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]] || return 1
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

normalize_profile() { # javascript -> node: same runtime, one vocabulary
  case "$1" in javascript) printf 'node' ;; *) printf '%s' "$1" ;; esac
}

do_install() {
  local dry=0 profile="" a
  for a in "$@"; do
    case "$a" in
      --dry-run) dry=1 ;;
      --*) die "install: unknown flag '$a' (--dry-run)" ;;
      *)
        [[ -z "$profile" ]] || die "install: unexpected argument '$a' (one profile at a time)"
        profile="$a"
        ;;
    esac
  done
  profile="$(normalize_profile "${profile:-core}")"
  case "$profile" in core|node|typescript|ruby|python|rust|development|macos-extras|lazygit|tools) ;; *) die "unknown profile: $profile (core|node|javascript|typescript|ruby|python|rust|development|macos-extras|lazygit|tools)" ;; esac
  # Read-only from here to the confirmation: no state, no packages, no links.
  detect_rogue_checkouts
  info "YADR 2027 $(version_str) — install [${profile}] in ${YADR_HOME}"

  if [[ "$profile" == "macos-extras" ]]; then
    [[ "$(uname -s)" == "Darwin" ]] || die "macos-extras on macOS only."
    if [[ "$dry" == "1" ]]; then
      info "plan: run platform/macos-extras.sh (optional macOS defaults)"
      info "dry-run: nothing modified."
      return 0
    fi
    confirm "Apply optional macOS defaults (platform/macos-extras.sh)?" || { info "cancelled."; return 0; }
    if bash "${YADR_HOME}/platform/macos-extras.sh"; then
      ok "macos-extras applied (optional, outside core)."
      return 0
    else
      local rc=$?
      err "macos-extras failed (see above)."
      return "$rc"
    fi
  fi
  if [[ "$profile" == "lazygit" ]]; then
    if [[ "$dry" == "1" ]]; then
      info "plan: run platform/lazygit.sh"
      info "dry-run: nothing modified."
      return 0
    fi
    info "installing lazygit (per-OS logic in platform/lazygit.sh)…"
    if bash "${YADR_HOME}/platform/lazygit.sh"; then
      ok "lazygit ready."
      return 0
    else
      local rc=$?
      err "lazygit failed (see above)."
      return "$rc"
    fi
  fi
  if [[ "$profile" == "tools" ]]; then
    if [[ "$dry" == "1" ]]; then
      info "plan: run platform/tools.sh"
      info "dry-run: nothing modified."
      return 0
    fi
    info "installing modern CLI tools (eza/bat/delta via platform/tools.sh)…"
    if bash "${YADR_HOME}/platform/tools.sh"; then
      ok "CLI tools ready."
      return 0
    else
      local rc=$?
      err "CLI tools failed (see above)."
      return "$rc"
    fi
  fi
  case "$profile" in node|typescript|ruby|python|rust|development)
    # Fast path: core links already correct → only the profile payload
    # (runtimes + editor), no platform rerun, no diff/confirm/backup/relink.
    # Anything else (or stale links) keeps the full safe flow.
    if links_uptodate; then
      if [[ "$dry" == "1" ]]; then
        info "plan: core links are up to date; would ensure completions + the ${profile} payload"
        info "dry-run: nothing modified."
        return 0
      fi
      info "core links up to date — fast path (no platform, symlinks or confirmations)."
      ensure_completions
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
  local tools; tools="$(runtime_tool_for "$profile")"
  # The plan is entirely read-only: diff + the side effects the user is about
  # to approve. Cancelling here must leave the system untouched (it used to run
  # the platform script and the payload first, then say "nothing modified").
  info "change preview (diff):"
  do_diff
  info "planned side effects:"
  info "  platform: ${plat}"
  if [[ -n "$tools" ]]; then info "  runtimes: ${tools}"; else info "  runtimes: none"; fi
  info "  links: $(managed_pair_count) from ${YADR_HOME}"
  info "  backup: ${BACKUP_ROOT}/<timestamp>"
  if [[ "$dry" == "1" ]]; then
    info "dry-run: nothing modified."
    return 0
  fi
  confirm "Install dependencies and apply links (with prior automatic backup)?" || { info "install cancelled; nothing modified."; return 0; }

  # --- side effects start here (nothing above this line writes) ---
  handle_legacy_yadr
  # Save the previous login shell once (uninstall restores it exactly).
  if [[ ! -f "${STATE_DIR}/prev-shell" ]]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    printf '%s' "${SHELL:-unknown}" > "${STATE_DIR}/prev-shell" 2>/dev/null || true
  fi
  snapshot_share_dirs
  if [[ -f "$plat" ]]; then info "platform: ${plat}"; bash "$plat" || warn "platform script errored; continuing with symlinks."
  else warn "platform script not found: ${plat}; continuing."
  fi
  # Profile runtimes via `runtime` abstraction (mise inside)
  local payload_rc=0
  ensure_profile_payload "$profile" || payload_rc=1
  if ! do_install_backup; then
    err "install backup failed; refusing to replace existing paths."
    return 1
  fi
  local n=0 skipped=0 failed=0
  while IFS=: read -r rel dst; do
    [[ -z "$rel" ]] && continue
    local src="${YADR_HOME}/${rel}"
    if [[ ! -e "$src" && ! -L "$src" ]]; then warn "  skipping ${rel} (not in checkout)"; skipped=$((skipped+1)); continue; fi
    if link_one "$src" "$dst"; then n=$((n+1)); else failed=$((failed+1)); fi
  done < <(managed_pairs)
  if [[ "$failed" -gt 0 ]]; then
    err "install incomplete: ${failed} link(s) failed (see above; ${n} applied)."
    next_steps
    return 1
  fi
  ensure_completions
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

installed_ref_path() { # where the last bootstrap/update recorded the checkout
  printf '%s/installed-ref' "${STATE_DIR:-$(yadr_state_dir)}"
}

record_installed_ref() {
  # R5: one file, key=value, written atomically. It answers "what did the last
  # bootstrap/update install?" even when the pull failed or the checkout was
  # moved; doctor compares it with the live HEAD. Never fatal: a read-only
  # HOME must not turn a successful install into a failure.
  #
  # Keep the format in sync with bootstrap.sh (it cannot source this file: a
  # --ref checkout may predate it). Tests assert both writers agree.
  local sha="" branch="" tag="" origin="" version="" ref="" dir tmp
  if [[ -d "${YADR_HOME}/.git" ]]; then
    sha="$(git -C "$YADR_HOME" rev-parse HEAD 2>/dev/null || true)"
    branch="$(git -C "$YADR_HOME" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    tag="$(git -C "$YADR_HOME" describe --tags --exact-match HEAD 2>/dev/null | head -n1 || true)"
    origin="$(git -C "$YADR_HOME" remote get-url origin 2>/dev/null || true)"
    # Never persist credentials embedded in an https remote.
    origin="$(printf '%s' "$origin" | sed -E 's#(https?://)[^/@]+@#\1#')"
  fi
  version="$(tr -d ' \t\n' < "${YADR_HOME}/VERSION" 2>/dev/null || true)"
  version="${version:-unknown}"
  if [[ -n "$tag" ]]; then ref="$tag"
  elif [[ -n "$branch" && "$branch" != "HEAD" ]]; then ref="$branch"
  elif [[ -n "$sha" ]]; then ref="detached"
  else ref="local"
  fi
  dir="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yadr}"
  mkdir -p "$dir" 2>/dev/null || { warn "cannot create ${dir}; installed ref not recorded."; return 1; }
  tmp="${dir}/.installed-ref.$$"
  {
    printf 'sha=%s\n' "$sha"
    printf 'ref=%s\n' "$ref"
    printf 'branch=%s\n' "$branch"
    printf 'tag=%s\n' "$tag"
    printf 'version=%s\n' "$version"
    printf 'origin=%s\n' "$origin"
    printf 'recorded=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$tmp" 2>/dev/null || { warn "cannot write ${tmp}; installed ref not recorded."; rm -f "$tmp"; return 1; }
  chmod 600 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "${dir}/installed-ref" 2>/dev/null || { warn "cannot replace ${dir}/installed-ref."; rm -f "$tmp"; return 1; }
  return 0
}

dirty_tree_list() { # prints up to 5 dirty paths of the live checkout, empty when clean/no-git
  [[ -d "${YADR_HOME}/.git" ]] || return 0
  # `|| true`: an unreadable/corrupt index must not abort update via set -e;
  # the pull itself will fail loudly a moment later if the repo is broken.
  git -C "$YADR_HOME" status --porcelain 2>/dev/null | head -n 5 || true
}

do_update() {
  info "updating YADR 2027…"
  local rc=0 has_repo=0 repo_updated=0
  if [[ -d "${YADR_HOME}/.git" ]]; then
    has_repo=1
    local _dirty; _dirty="$(dirty_tree_list)"
    if [[ -n "$_dirty" ]]; then
      warn "live checkout has local modifications (pull --ff-only may refuse):"
      printf '%s\n' "$_dirty" >&2
      info "stash, commit or discard them in ${YADR_HOME} first (often just nvim/lazy-lock.json from Lazy sync)."
    fi
    confirm "Update repo (git pull --ff-only in ${YADR_HOME})?" || { info "update cancelled."; return 0; }
    do_update_backup || warn "continuing update without a complete update backup."
    if git -C "$YADR_HOME" pull --ff-only; then
      ok "repo updated."
      repo_updated=1
      # Editor sync only makes sense on a checkout that actually moved; when the
      # pull failed there is nothing new to restore to.
      ensure_nvim_plugins || true
    else
      # Same policy as a failed runtime (ADR-004): never claim what did not
      # happen. "ok repo updated." used to print right after a failed pull.
      warn "pull failed (dirty checkout, conflicts or offline); the checkout is unchanged."
      info "fix by hand in ${YADR_HOME}, then run 'yadr update' again."
      rc=1
    fi
  else
    warn "no .git in ${YADR_HOME}; nothing to update (local checkout)."
  fi
  # Record even when the pull failed: the file says which revision the machine
  # is actually on, so doctor can explain a dirty/offline checkout instead of
  # claiming "not recorded". A cancelled update returns above and writes nothing.
  record_installed_ref || true
  # Two phases, reported separately: the config and the runtimes do not move
  # atomically, so a failed pull must not silently advance the runtimes while
  # the checkout stays behind.
  if [[ "$has_repo" == "1" && "$repo_updated" == "0" ]]; then
    info "runtimes: skipped (repo unchanged)."
    return "$rc"
  fi
  if have mise; then
    if confirm_yes "Update runtimes (mise)?"; then
      info "updating runtimes (mise)…"
      if mise upgrade 2>/dev/null || mise up 2>/dev/null; then
        ok "runtimes updated."
      else
        warn "runtime update failed."
        rc=1
      fi
    else
      info "runtimes: skipped."
    fi
  fi
  return "$rc"
}
