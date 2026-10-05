# YADR 2027 — shell/damoekri.zsh
# Damoekri 2027 prompt: sober, Solarized, no Starship/P10k/OMZ.
# PROMPT: cyan cwd + git branch/state. RPROMPT: runtime (yadr_runtime_context).
# Works without runtime and outside git repos.

autoload -Uz colors && colors

# --- Git: branch + status (no vcs_info for speed and full control) ---
# Format: ` <branch> ✔|✗|↑↓` — blue branch, green clean, red dirty.
yadr_git_info() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local branch="" dirty="" ahead=0 behind=0 info=""
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)" || return 0
  [[ -z "$branch" ]] && return 0

  # dirty: staged/unstaged/untracked changes (fast, no stash)
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    dirty=1
  fi

  # ahead/behind vs upstream (silent when no upstream)
  local counts
  counts="$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)" || counts=""
  if [[ -n "$counts" ]]; then
    ahead="${counts%% *}"; behind="${counts##* }"
  fi

  info="%F{blue}‹${branch}%f"
  if [[ -n "$dirty" ]]; then
    info+=" %F{red}✗%f"    # red dirty
  else
    info+=" %F{green}✔%f"  # green clean
  fi
  (( ahead > 0 ))  && info+=" %F{yellow}↑${ahead}%f"
  (( behind > 0 )) && info+=" %F{yellow}↓${behind}%f"

  printf '%s' "$info"
  return 0
}

# --- Runtime: wrapper that never breaks prompt if runtime.zsh is missing ---
_yadr_runtime_segment() {
  if typeset -f yadr_runtime_context >/dev/null 2>&1; then
    yadr_runtime_context 2>/dev/null || true
  fi
  return 0
}

setopt PROMPT_SUBST

# PROMPT matching classic damoekri (Prezto): `dir »` on one line,
# green »; git branch/status after directory.
# RPROMPT: git goes left; runtime here (global outside
# project, project-scoped inside). Empty only when no runtime exists.
_yadr_damoekri_precmd() {
  local g
  g="$(yadr_git_info 2>/dev/null)"
  PROMPT="%F{cyan}%~%f${g:+ $g} %F{green}»%f "
}
autoload -Uz add-zsh-hook 2>/dev/null || true
add-zsh-hook precmd _yadr_damoekri_precmd 2>/dev/null || true
PROMPT='%F{cyan}%~%f %F{green}»%f '
# RPROMPT: red runtime by default (overridable: YADR_RUNTIME_COLOR).
# Global: node version. In project: project node/python/ruby.
RPROMPT='%F{${YADR_RUNTIME_COLOR:-red}}$(_yadr_runtime_segment)%f'

# Sober secondary prompt.
PROMPT2='%F{black}… %f'

return 0 2>/dev/null || true
