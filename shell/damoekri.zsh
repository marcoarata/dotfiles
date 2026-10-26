# YADR 2027 — shell/damoekri.zsh
# Damoekri 2027 prompt: sober, Solarized, no Starship/P10k/OMZ.
# PROMPT: cyan cwd + green ». RPROMPT: git branch/state + runtime.
# Layout mirrors classic damoekri (Prezto): git lives on the right.
# Works without runtime and outside git repos.

autoload -Uz colors && colors

# --- Git: branch + status (no vcs_info for speed and full control) ---
# Format: `✔|✘ <branch> ↑↓` — mark first (green clean, red dirty), blue branch.
# Rendered in RPROMPT next to the runtime, like classic damoekri.
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
  # `rev-list --count` separates the two numbers with a TAB; splitting on a
  # space leaves ahead as "0\t0" and the prompt never renders the arrows.
  local counts
  if counts="$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)"; then
    read -r ahead behind <<< "$counts"
  fi

  info=""
  if [[ -n "$dirty" ]]; then
    info="%F{red}✘%f"    # dirty red
  else
    info="%F{green}✔%f"  # clean green
  fi
  info+=" %F{blue}${branch}%f"
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

# PROMPT is static (`dir »`); git moved to RPROMPT like classic damoekri.
# RPROMPT: `✔ main` + runtime (red by default, YADR_RUNTIME_COLOR overridable).
# Both segments render in bold, matching the syntax-highlighting error red
# (fg=red,bold). Global runtime outside projects, project-scoped inside.
# Empty only when neither git nor runtime exists.
_yadr_damoekri_precmd() {
  local g r
  g="$(yadr_git_info 2>/dev/null)"
  r="$(_yadr_runtime_segment 2>/dev/null)"
  PROMPT="%F{cyan}%~%f %F{green}»%f "
  RPROMPT=""
  [[ -n "$g" ]] && RPROMPT+="%B$g%b"
  [[ -n "$g" && -n "$r" ]] && RPROMPT+=" "
  [[ -n "$r" ]] && RPROMPT+="%B%F{${YADR_RUNTIME_COLOR:-red}}$r%f%b"
}
autoload -Uz add-zsh-hook 2>/dev/null || true
add-zsh-hook precmd _yadr_damoekri_precmd 2>/dev/null || true
PROMPT='%F{cyan}%~%f %F{green}»%f '
RPROMPT=''

# Sober secondary prompt.
PROMPT2='%F{black}… %f'

return 0 2>/dev/null || true
