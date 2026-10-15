#!/usr/bin/env bash
# YADR 2027 — lib/doctor.sh: doctor, gitsigns and their checks
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.

# --- doctor ---
DOCTOR_FAIL=0; DOCTOR_WARN=0
dc_ok()   { ok "$1"; }
dc_warn() { warn "$1${2:+ — hint: $2}"; DOCTOR_WARN=$((DOCTOR_WARN+1)); }
dc_fail() { err "$1${2:+ — hint: $2}"; DOCTOR_FAIL=$((DOCTOR_FAIL+1)); }
dc_cmd() { # dc_cmd name command hint
  if have "$2"; then dc_ok "$1 ($($2 --version 2>/dev/null | head -n1 || echo in PATH))"; else dc_fail "$1 missing" "$3"; fi
}
nerd_font_source() { # where the font was found: mac-fonts|fc-list|""
  local d
  for d in "${HOME}/Library/Fonts" "/Library/Fonts"; do
    if [[ -d "$d" ]] && compgen -G "${d}/*[Nn]erd*" >/dev/null 2>&1; then printf 'mac-fonts'; return 0; fi
  done
  if command -v fc-list >/dev/null 2>&1 && [[ -n "$(fc-list 2>/dev/null | grep -i nerd)" ]]; then printf 'fc-list'; return 0; fi
  return 1
}
nerd_font_present() { # 0 when a Nerd Font is detectable (macOS dirs first, fc-list fallback)
  [[ -n "$(nerd_font_source)" ]]
}

version_at_least() { # version_at_least <"M.m..."> <maj> <min> — YADR floor checks share this
  local ver="$1" want_maj="$2" want_min="$3" got
  got="$(printf '%s' "$ver" | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  local maj="${got%%.*}" min="${got##*.}"
  [[ "${maj:-0}" -gt "$want_maj" ]] || { [[ "${maj:-0}" -eq "$want_maj" ]] && [[ "${min:-0}" -ge "$want_min" ]]; }
}

do_doctor() {
  DOCTOR_FAIL=0; DOCTOR_WARN=0
  printf '%sYADR doctor %s%s\n' "$BOLD" "$(version_str)" "$RESET"
  detect_rogue_checkouts
  local _dirty; _dirty="$(dirty_tree_list)"
  if [[ -n "$_dirty" ]]; then
    dc_warn "live checkout has local modifications" "stash/commit/discard in ${YADR_HOME} (often just nvim/lazy-lock.json); updates may refuse to fast-forward"
  fi
  dc_cmd "zsh" zsh "sudo apt install zsh / brew install zsh; chsh -s \$(command -v zsh)"
  dc_cmd "git" git "sudo apt install git / brew install git"
  if have git; then
    # git identity (advisory only: install never asks for it and doctor
    # never fails over it). Empty until the user defines it in
    # ~/.gitconfig.user (never --global, never inside the repo).
    local _gname _gmail
    _gname="$(git config --includes --global user.name 2>/dev/null || true)"
    _gmail="$(git config --includes --global user.email 2>/dev/null || true)"
    if [[ -n "$_gname" && -n "$_gmail" ]]; then dc_ok "git identity configured (${_gname})";
    else dc_warn "git identity not configured" "add [user] name/email to ~/.gitconfig.user when you want to commit (optional)"; fi
  fi
  dc_cmd "tmux" tmux "sudo apt install tmux / brew install tmux"
  if have nvim; then
    local _nv; _nv="$(nvim --version 2>/dev/null | head -n1)"
    if version_at_least "$_nv" 0 11; then dc_ok "nvim (${_nv})";
    else dc_fail "nvim ${_nv} <0.11 (YADR floor)" "yadr install core (platform installs upstream ≥0.11 into ~/.local/bin)"; fi
  else dc_fail "nvim missing" "sudo apt install neovim / brew install neovim"; fi
  # vim must resolve to Neovim >=0.11 or to genuine Vim — never to old nvim.
  if have vim; then
    local _vv
    _vv="$(vim --version 2>/dev/null | head -n1)"
    case "$_vv" in
      NVIM*)
        if version_at_least "$_vv" 0 11; then dc_ok "vim → Neovim (${_vv})";
        else dc_fail "vim resolves to old Neovim (${_vv})" "yadr install core (creates ~/.local/bin/vim shim)"; fi
        ;;
      *) dc_ok "vim genuine (${_vv:-Vim})" ;;
    esac
  else dc_warn "vim missing" "yadr install core (provides vim via upstream Neovim)"; fi
  dc_cmd "rg (ripgrep)" rg "sudo apt install ripgrep / brew install ripgrep"
  if have fd || have fdfind; then dc_ok "fd ($(command -v fd || command -v fdfind))"; else dc_fail "fd missing" "sudo apt install fd-find (+ln -s fdfind→fd) / brew install fd"; fi
  if have zoxide; then dc_ok "zoxide ($(zoxide --version 2>/dev/null | head -n1 || echo in PATH))";
  else dc_warn "zoxide missing" "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash / brew install zoxide"; fi
  dc_cmd "mise (runtime backend)" mise "curl -fsSL https://mise.run | sh / brew install mise"
  # zsh plugins (advisory only: shell degrades gracefully without them, but
  # silent degradation is a bug — see Intel Mac Tier 3 report).
  for _plug in "zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "zsh-autosuggestions/zsh-autosuggestions.zsh"; do
    _found=""
    for _base in "${XDG_DATA_HOME:-$HOME/.local/share}/yadr-plugins" /opt/local/share /usr/share "$(brew --prefix 2>/dev/null)/share"; do
      if [[ -n "$_base" && -f "${_base}/${_plug}" ]]; then _found="${_base}/${_plug}"; break; fi
    done
    if [[ -n "$_found" ]]; then dc_ok "${_plug%%/*} (${_found})";
    else dc_warn "${_plug%%/*} not found" "yadr install core, or clone into ~/.local/share/yadr-plugins/"; fi
  done
  # runtimes via abstraction
  for t in node npm pnpm; do
    if have "$t"; then dc_ok "$t ($($t --version 2>/dev/null | head -n1))"; else dc_warn "$t missing" "yadr install node (Node LTS + npm/pnpm via mise)"; fi
  done
  if have python; then dc_ok "python ($(python --version 2>&1 | head -n1))"; else dc_warn "python missing" "yadr install python (installs Python 3.14 via mise)"; fi
  if have lazygit; then dc_ok "lazygit ($(lazygit --version 2>/dev/null | head -n1))"; else dc_warn "lazygit missing" "yadr install lazygit"; fi
  # lsp: server on PATH or installed by Mason (~/.local/share/nvim/mason/bin)
  if have rust-analyzer || have typescript-language-server || have pyright || have lua-language-server || have gopls || have clangd; then
    dc_ok "lsp (server en PATH)"
  elif [[ -n "$(ls "${HOME}/.local/share/nvim/mason/bin" 2>/dev/null)" ]]; then
    dc_ok "lsp (servers Mason: $(ls "${HOME}/.local/share/nvim/mason/bin" 2>/dev/null | tr '\n' ' '))"
  else dc_warn "lsp without servers" "yadr install typescript (installs the 5 servers via Mason)"; fi
  # treesitter: parsers o CLI.
  if have tree-sitter; then dc_ok "treesitter (cli)"
  elif [[ -n "$(ls "${HOME}/.local/share/nvim/lazy/nvim-treesitter"/parser 2>/dev/null)" ]]; then dc_ok "treesitter (parsers nvim)"
  else dc_warn "treesitter without parsers" "open nvim and run :TSUpdate, or install tree-sitter-cli"; fi
  # Solarized: palette referenced in repo or HOME configs.
  if [[ -n "$(grep -rli "solarized" "${YADR_HOME}/nvim" "${YADR_HOME}/tmux" "${YADR_HOME}/shell" "${HOME}/.config/nvim" "${HOME}/.tmux.conf" 2>/dev/null)" ]]; then
    dc_ok "Solarized (referenced in configs)"
  else dc_warn "Solarized missing" "reinstall: yadr install core (palette in nvim/tmux/shell)"; fi
  # Damoekri: prompt present
  if [[ -f "${YADR_HOME}/shell/damoekri.zsh" ]] || grep -q "damoekri" "${HOME}/.zshrc" 2>/dev/null; then
    dc_ok "Damoekri (prompt present)"
  else dc_warn "Damoekri missing" "reinstall: yadr install core (prompt in shell/damoekri.zsh)"; fi
  # Nerd Font (installed by platform/; without it nvim degrades icons).
  # No `| grep -q` or `| head`: with pipefail, early-reader SIGPIPE
  # skews the result. Capture and test instead.
  # On macOS fontconfig is often absent: ~/Library/Fonts is authoritative
  # (platform/macos.sh installs there); fc-list stays as fallback/Linux path.
  local _nfsrc
  if _nfsrc="$(nerd_font_present && nerd_font_source)"; then
    dc_ok "Nerd Font present (${_nfsrc})"
  else dc_warn "Nerd Font missing" "yadr install core installs it (terminal/fonts); without a font, icons degrade to text"; fi
  # Neovim plugins vs lockfile (detects ahead/behind checkouts).
  if [[ -f "${YADR_HOME}/nvim/lazy-lock.json" && -d "${HOME}/.local/share/nvim/lazy" ]]; then
    local _div="" _d _name _want _got
    for _d in "${HOME}"/.local/share/nvim/lazy/*/; do
      [[ -d "${_d}/.git" ]] || continue
      _name="$(basename "$_d")"
      _want="$(grep -o "\"${_name}\": { \"branch\": \"[^\"]*\", \"commit\": \"[0-9a-f]*\"" "${YADR_HOME}/nvim/lazy-lock.json" 2>/dev/null | grep -oE '[0-9a-f]{40}' || true)"
      [[ -z "$_want" ]] && continue
      _got="$(git -C "$_d" rev-parse HEAD 2>/dev/null || true)"
      [[ "$_got" == "$_want"* ]] || _div="${_div} ${_name}"
    done
    if [[ -z "$_div" ]]; then dc_ok "nvim plugins (lockfile OK)";
    else dc_warn "plugins out of lock:${_div}" "yadr install core (restores) or nvim +Lazy! restore"; fi
  else dc_warn "neovim plugins not installed" "open nvim once or run yadr install core"; fi
  # nvim: clean headless startup (catches E5113/broken configs like gitsigns).
  # Only with installed config; else the plugins check already warned.
  if have nvim && [[ -L "${HOME}/.config/nvim" ]]; then
    local _nerr
    _nerr="$(run_timeout 120 nvim --headless "+qa" 2>&1 | grep -iE "error|failed to|not installed|not found| Press ENTER" | head -n 5 || true)"
    if [[ -z "$_nerr" ]]; then dc_ok "clean nvim startup";
    else dc_fail "nvim starts with errors" "see above; try: yadr install core"; printf '%s\n' "$_nerr" >&2; fi
  fi
  # gitsigns opt-in (informa, no modifica).
  if [[ -f "$(gitsigns_marker)" ]]; then dc_ok "gitsigns active (opt-in)";
  else info "gitsigns off (default; enable: yadr gitsigns on)"; fi
  # yadr CLI on PATH (self-check: the binary itself must resolve).
  local _yv; _yv="$(command -v yadr 2>/dev/null || true)"
  if [[ "$_yv" == "${YADR_HOME}/bin/yadr" ]] || [[ "$_yv" == "${HOME}/.local/bin/yadr" ]]; then
    dc_ok "yadr CLI en PATH (${_yv})"
  else dc_fail "yadr CLI not on PATH" "run: yadr install (links ~/.local/bin/yadr) and add ~/.local/bin to PATH"; fi
  # current theme (informational; nvim reads it at startup).
  info "theme: $(theme_effective) (yadr theme use light|dark|none; applies when reopening nvim)"
  printf '\n%s\n' "${DIM}summary: ${DOCTOR_FAIL} errors, ${DOCTOR_WARN} warnings${RESET}"
  next_steps
  [[ "$DOCTOR_FAIL" -gt 0 ]] && return 1 || return 0
}

# --- gitsigns opt-in (off by default) ---
gitsigns_marker() { printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/yadr/gitsigns.enabled"; }
cmd_gitsigns() { # on|off|status
  local sub="${1:-status}" marker
  marker="$(gitsigns_marker)"
  case "$sub" in
    on) mkdir -p "$(dirname "$marker")"; touch "$marker" && ok "gitsigns enabled (opt-in). Reopen nvim." ;;
    off) rm -f "$marker" && ok "gitsigns disabled (default)." ;;
    status|"") [[ -f "$marker" ]] && info "gitsigns: enabled" || info "gitsigns: disabled (default)" ;;
    *) usage; die "gitsigns: unknown subcommand '${sub}' (on|off|status)" ;;
  esac
}
