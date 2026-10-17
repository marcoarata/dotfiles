# YADR 2027 — shell/runtime.zsh
# Runtime context for prompt. Never fails (always return 0).
# Priority: mise > fnm/nvm (node) > direct binaries.
#
# yadr_runtime_context: prints "python-3.12.15 · node-24.13.0" or "" when empty.
# Outside a project: the global node only (classic behavior).
# Inside a project: only the runtimes the project itself pins. Attribution
# comes from `mise ls --current` (authoritative source path): a version whose
# source is the global config (under ~/.config/mise) is inherited, not pinned,
# and is filtered out. Without mise, node is always shown and ruby/python only
# when the project has a local version file (.ruby-version/.python-version).
# Caches by $PWD: detection runs at most once per directory.
# Never fails (always return 0).
_YADR_RT_PWD=""
_YADR_RT_VAL=""
# Any project markers up the tree? (fast, no subprocesses)
_yadr_in_project() {
  local d="$PWD"
  while [[ "$d" != "/" && -n "$d" ]]; do
    for m in .tool-versions mise.toml .mise.toml .nvmrc .node-version package.json Gemfile .ruby-version pyproject.toml requirements.txt Cargo.toml go.mod .python-version; do
      [[ -e "$d/$m" ]] && return 0
    done
    d="${d:h}"
  done
  return 1
}
# Any of the given filenames exists walking up the tree? (no subprocesses)
_yadr_has_marker() {
  local d="$PWD" m
  while [[ "$d" != "/" && -n "$d" ]]; do
    for m in "$@"; do [[ -e "$d/$m" ]] && return 0; done
    d="${d:h}"
  done
  return 1
}
# "version source" for <tool> from `mise ls --current` output. "" when absent.
_yadr_mise_row() {
  [[ -n "${2:-}" ]] || return 1
  local row
  row="$(printf '%s' "$2" | awk -v t="$1" '$1 == t {print $2, $3; exit}')"
  [[ -n "$row" ]] && printf '%s' "$row" || return 1
}
# Is the source a project-local config file (not the global mise config)?
_yadr_is_local_src() {
  local src="${1:-}" global="${XDG_CONFIG_HOME:-$HOME/.config}/mise"
  [[ -n "$src" ]] || return 1
  case "$src" in
    "~/"*) src="$HOME/${src:2}" ;;
    "~")   src="$HOME" ;;
  esac
  [[ "$src" == "$global/"* ]] && return 1
  return 0
}
# Node version from fnm or the direct binary (fallback when mise lacks node).
_yadr_node_direct() {
  local v=""
  if command -v fnm >/dev/null 2>&1; then
    v="$(fnm current 2>/dev/null)"
    [[ "$v" == "system" || "$v" == "none" ]] && v=""
    v="${v#v}"
  fi
  if [[ -z "$v" ]] && command -v node >/dev/null 2>&1; then
    v="$(node --version 2>/dev/null)"
    v="${v#v}"
  fi
  printf '%s' "${v%% *}"
}
yadr_runtime_context() {
  if [[ "$PWD" == "$_YADR_RT_PWD" ]]; then
    [[ -n "$_YADR_RT_VAL" ]] && printf '%s' "$_YADR_RT_VAL"
    return 0
  fi
  _YADR_RT_PWD="$PWD"
  _YADR_RT_VAL=""
  local parts=() v="" src="" row="" mise_ls="" in_proj=0
  _yadr_in_project && in_proj=1
  if command -v mise >/dev/null 2>&1; then
    mise_ls="$(mise ls --current 2>/dev/null)"
  fi

  if [[ -n "$mise_ls" ]]; then
    local tool
    for tool in node ruby python; do
      row="$(_yadr_mise_row "$tool" "$mise_ls")" || continue
      v="${row%% *}"
      src="${row#* }"
      [[ -n "$v" && "$v" != "system" ]] || continue
      if (( in_proj )); then
        # Only project-pinned runtimes: drop inherited globals.
        _yadr_is_local_src "$src" || continue
      elif [[ "$tool" != node ]]; then
        continue
      fi
      parts+=("${tool}-${v%% *}")
    done
    # In a project without pins: keep a global node so the prompt is never empty.
    if (( in_proj )) && (( ${#parts[@]} == 0 )); then
      v="$(_yadr_mise_row node "$mise_ls" 2>/dev/null)"; v="${v%% *}"
      [[ -n "$v" && "$v" != "system" ]] && parts+=("node-${v%% *}")
    fi
    # mise present but not managing node: outside a project, keep classic node.
    if (( ! in_proj )) && (( ${#parts[@]} == 0 )); then
      v="$(_yadr_node_direct)"; [[ -n "$v" ]] && parts+=("node-${v%% *}")
    fi
  else
    # No mise: node always; ruby/python only with a local version file.
    v="$(_yadr_node_direct)"; [[ -n "$v" ]] && parts+=("node-${v%% *}")
    if (( in_proj )); then
      if _yadr_has_marker .ruby-version; then
        v="$(ruby -e 'print RUBY_VERSION' 2>/dev/null)"
        [[ -n "$v" ]] && parts+=("ruby-${v%% *}")
      fi
      if _yadr_has_marker .python-version; then
        v="$(python3 --version 2>/dev/null | awk '{print $2}')"
        [[ -n "$v" ]] && parts+=("python-${v%% *}")
      fi
    fi
  fi

  if (( ${#parts[@]} > 0 )); then
    _YADR_RT_VAL="${(j: · :)parts}"
    printf '%s' "$_YADR_RT_VAL"
  fi
  return 0
}

# --- fnm fallback: autoload env if present and not already active ---
if ! command -v node >/dev/null 2>&1; then
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd 2>/dev/null)" || true
  elif [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # nvm is slow: load on demand via function, not in every shell.
    nvm() {
      unset -f nvm
      # shellcheck disable=SC1091
      source "$HOME/.nvm/nvm.sh" 2>/dev/null || return 0
      nvm "$@"
    }
  fi
fi

return 0 2>/dev/null || true
