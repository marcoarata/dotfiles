# YADR 2027 — shell/runtime.zsh
# Runtime context for prompt. Never fails (always return 0).
# Priority: mise > fnm/nvm (node) > direct binaries.

# yadr_runtime_context: prints "node-24 · python-3.12" or "" when empty.
# Matches classic: CONTEXT runtime always visible (there it was RVM Ruby).
# In project: project node/ruby/python.
# Outside project: global node only (no noise).
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
# Runtime version from `mise current` output
# (_yadr_mise_ver <tool> <mise-out>). "" when system/missing.
_yadr_mise_ver() {
  [[ -n "${2:-}" ]] || return 1
  local got
  got="$(printf '%s' "$2" | awk -v t="$1" '$1 == t {print $2}')"
  [[ -n "$got" && "$got" != "system" ]] && printf '%s' "$got" || return 1
}
# Is runtime installed and active? (mise current reports CONFIGURED
# whether present or not; only show what actually runs).
_yadr_mise_active() {
  command -v mise >/dev/null 2>&1 || return 1
  mise which "$1" >/dev/null 2>&1
}
yadr_runtime_context() {
  if [[ "$PWD" == "$_YADR_RT_PWD" ]]; then
    [[ -n "$_YADR_RT_VAL" ]] && printf '%s' "$_YADR_RT_VAL"
    return 0
  fi
  _YADR_RT_PWD="$PWD"
  _YADR_RT_VAL=""
  local parts=() v="" mise_out=""
  # Single mise call (if present) for all 3 runtimes.
  if command -v mise >/dev/null 2>&1; then
    mise_out="$(mise current 2>/dev/null)"
  fi
  # --- node ---
  v="$(_yadr_mise_ver node "$mise_out")" || v=""
  # Pin may exist without being installed: only counts if it actually runs.
  if [[ -n "$v" ]] && ! _yadr_mise_active node; then v=""; fi
  if [[ -z "$v" ]] && command -v fnm >/dev/null 2>&1; then
    v="$(fnm current 2>/dev/null)"
    [[ "$v" == "system" || "$v" == "none" ]] && v=""
    v="${v#v}"
  fi
  if [[ -z "$v" ]] && command -v node >/dev/null 2>&1; then
    v="$(node --version 2>/dev/null)"
    v="${v#v}"
  fi
  [[ -n "$v" ]] && parts+=("node-${v%% *}")

  # ruby/python: only inside projects (outside, global node only).
  if _yadr_in_project; then
  # --- ruby ---
  v="$(_yadr_mise_ver ruby "$mise_out")" || v=""
  if [[ -n "$v" ]] && ! _yadr_mise_active ruby; then v=""; fi
  if [[ -z "$v" ]] && command -v ruby >/dev/null 2>&1; then
    v="$(ruby -e 'print RUBY_VERSION' 2>/dev/null)"
  fi
  [[ -n "$v" ]] && parts+=("ruby-${v%% *}")

  # --- python ---
  v="$(_yadr_mise_ver python "$mise_out")" || v=""
  if [[ -n "$v" ]] && ! _yadr_mise_active python; then v=""; fi
  if [[ -z "$v" ]] && command -v python3 >/dev/null 2>&1; then
    v="$(python3 --version 2>/dev/null | awk '{print $2}')"
  fi
  [[ -n "$v" ]] && parts+=("python-${v%% *}")
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
