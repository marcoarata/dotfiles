#!/usr/bin/env bash
# YADR 2027 — lib/runtime.sh: runtime and theme user commands
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.

# --- runtime (abstracts mise; mise is never exposed as API) ---
runtime_backend() { have mise && echo "mise" || echo "none"; }
cmd_runtime_current() {
  if [[ "$(runtime_backend)" == "none" ]]; then warn "no runtime backend (install mise: yadr install core)"; return 1; fi
  mise current 2>/dev/null || mise ls 2>/dev/null || warn "no active runtimes. Try: yadr runtime use node"
}
cmd_runtime_list() {
  if [[ "$(runtime_backend)" == "none" ]]; then warn "no runtime backend."; return 1; fi
  mise ls 2>/dev/null || warn "mise ls failed."
}
cmd_runtime_use() { # cmd_runtime_use tool[@version]
  local spec="${1:?usage: yadr runtime use <tool[@version]>  (e.g. node, node@24, python@3.12)}"
  if [[ "$(runtime_backend)" == "none" ]]; then err "no backend (mise missing). Hint: yadr install core"; return 1; fi
  # Without explicit version: `mise install` honors the runtime/mise.toml pin
  # and NEVER rewrites the repo (mise use -g would mutate the pinned version).
  if [[ "$spec" != *"@"* ]]; then
    info "installing '${spec}' per runtime/mise.toml pin…"
    mise install "$spec" || { err "'mise install ${spec}' failed."; return 1; }
    ok "runtime '${spec}' ready (pin honored)."
    return 0
  fi
  info "activating runtime '${spec}'…"
  mise use -g "$spec" || { err "'mise use -g ${spec}' failed."; return 1; }
  ok "runtime '${spec}' active globally."
  info "note: this updated the managed runtime/mise.toml (git-tracked); for your own global tools prefer $(mise_config_dir)/conf.d/<name>.toml"
}
cmd_runtime_doctor() {
  if [[ "$(runtime_backend)" == "none" ]]; then dc_fail "runtime backend missing" "yadr install core"; return 1; fi
  ok "backend: mise ($(mise --version 2>/dev/null))"
  mise doctor 2>/dev/null || mise dr 2>/dev/null || warn "mise doctor unavailable in this version."
}

# --- theme (Solarized background; same file the macOS menu writes) ---
theme_file() { printf '%s' "$(yadr_config_dir)/solarized-bg"; }
theme_normalize() { # light|solarized-light|dark|solarized-dark|none -> canonical or ""
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    light|solarized-light) echo "light" ;;
    dark|solarized-dark)   echo "dark" ;;
    none)                  echo "none" ;;
    *)                     echo "" ;;
  esac
}
theme_effective() { # env wins (nvim honors the same precedence), then file, then none
  local v=""
  v="$(theme_normalize "${YADR_SOLARIZED_BG:-}")"
  [[ -n "$v" ]] && { printf '%s' "$v"; return 0; }
  if [[ -f "$(theme_file)" ]]; then
    v="$(theme_normalize "$(head -n1 "$(theme_file)" 2>/dev/null || true)")"
    [[ -n "$v" ]] && { printf '%s' "$v"; return 0; }
  fi
  printf 'none'
}
cmd_theme_list() {
  local cur; cur="$(theme_effective)"
  info "Solarized themes (apply when reopening nvim; default: transparent none):"
  local t mark desc
  for t in light dark none; do
    mark=" "; [[ "$t" == "$cur" ]] && mark="*"
    desc="(solid)"; [[ "$t" == "none" ]] && desc="(default, transparent)"
    printf '  %s %-5s %s\n' "$mark" "$t" "$desc"
  done
  info "usage: yadr theme use light|dark|none"
}
cmd_theme_use() { # cmd_theme_use <name>
  local want; want="$(theme_normalize "${1:-}")"
  [[ -n "$want" ]] || { usage; die "theme: unknown name '${1:-}' (light|dark|solarized-light|solarized-dark|none)"; }
  mkdir -p "$(dirname "$(theme_file)")" 2>/dev/null || true
  printf '%s\n' "$want" > "$(theme_file)" || die "could not save to $(theme_file)"
  ok "theme: ${want} (saved; applies when reopening nvim)."
}
cmd_theme_current() {
  local cur src="default"
  cur="$(theme_effective)"
  if [[ -n "${YADR_SOLARIZED_BG:-}" ]]; then src="env YADR_SOLARIZED_BG";
  elif [[ -f "$(theme_file)" ]]; then src="$(theme_file)"; fi
  info "current theme: ${cur} (${src})"
}
cmd_theme() { # list|use <name>|current|<name>|(interactive menu)
  local sub="${1:-}"
  case "$sub" in
    list)    cmd_theme_list ;;
    current) cmd_theme_current ;;
    use)     cmd_theme_use "${2:-}" ;;
    "") # no args: TTY menu (Enter = keep), no TTY shows status
      if [[ ! -t 0 ]]; then cmd_theme_current; info "usage: yadr theme use light|dark|none"; return 0; fi
      cmd_theme_list
      printf 'Choose [1 light / 2 dark / 3 none] (Enter = keep current): ' >&2
      local ans=""; IFS= read -r ans || ans=""
      case "$ans" in
        1) cmd_theme_use light ;;
        2) cmd_theme_use dark ;;
        3) cmd_theme_use none ;;
        "") info "no changes (current: $(theme_effective))." ;;
        *) warn "invalid choice; no changes." ;;
      esac ;;
    *) # atajo directo: yadr theme dark
      if [[ -n "$(theme_normalize "$sub")" ]]; then cmd_theme_use "$sub";
      else usage; die "theme: unknown subcommand '${sub}' (list|use|current|<name>)"; fi ;;
  esac
}
