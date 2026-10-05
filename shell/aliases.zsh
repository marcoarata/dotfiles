# YADR 2027 — shell/aliases.zsh
# Mnemonic aliases. Fallback-only: undefined if tool is missing.

# --- YADR legacy: ae (edit aliases) / ar (reload) ---
# ae opens this file; ar reloads it in current session.
alias ae="$EDITOR \"${0:A:h}/aliases.zsh\""
alias ar="source \"${0:A:h}/aliases.zsh\" && echo 'aliases reloaded'"

# --- Git shortcuts (classic YADR parity; `git <sub>` lives in git/gitconfig) ---
alias g="git"
alias gl="git log --oneline --graph --decorate -20"
alias gb="git branch -vv"
alias gt="git t"                           # tags (gitconfig t = tag -n)
alias gs="git status"
alias gstsh="git stash"
alias gst="git stash"
alias gsp="git stash pop"
alias gsa="git stash apply"
alias gsh="git show"
alias gshw="git show"
alias gshow="git show"
alias gi="$EDITOR .gitignore"
alias gcm="git ci -m"
alias gcim="git ci -m"
alias gci="git ci"
alias gco="git co"
alias gcp="git cherry-pick"              # gcp <sha>
alias ga="git add -A"
alias gap="git add -p"
alias guns="git unstage"                   # unstage, keep work
alias gunc="git uncommit"                  # undo commit, keep work
alias gm="git merge"
alias gms="git merge --squash"
alias gam="git amend --reset-author"
alias grv="git remote -v"
alias grr="git remote rm"
alias grad="git remote add"
alias gr="git rebase"
alias gra="git rebase --abort"
alias ggrc="git rebase --continue"
alias gbi="git rebase --interactive"
alias glg="git l"
alias glog="git l"
alias co="git co"
alias gf="git fetch"
alias gfp="git fetch --prune"
alias gfa="git fetch --all"
alias gfap="git fetch --all --prune"
alias gfch="git fetch"
alias gd="git diff"
alias gdc="git diff --cached -w"
alias gds="git diff --staged -w"
alias gpl="git pull"
alias gplr="git pull --rebase"
alias gps="git push"
alias gpsh="git push -u origin $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
alias gnb="git checkout -b"              # gnb <name>: new branch
alias grs="git reset"
alias grsh="git reset --hard"
alias gcln="git clean"
alias gclndf="git clean -df"
alias gclndfx="git clean -dfx"
alias gsm="git submodule"
alias gsmi="git submodule init"
alias gsmu="git submodule update"
alias gbg="git bisect good"
alias gbb="git bisect bad"
# gdmb as function (multi-stage pipeline; portable BSD/GNU, no xargs -r).
gdmb() { git branch --merged | grep -Ev '^\*|main|master|develop' | sed 's/^ *//' | while IFS= read -r b; do git branch -d "$b"; done; }
alias grb="git recent-branches"

# --- ls / ll / la: eza if present; else OS flags (BSD/macOS: -G, Linux: --color) ---
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -l --group-directories-first --git --time-style=relative"
  alias la="eza -la --group-directories-first --git --time-style=relative"
elif [[ "$(uname)" == "Darwin" ]]; then
  alias ls="ls -Gh"
  alias ll="ls -lGh"
  alias la="ls -laGh"
else
  alias ls="ls --color=auto"
  alias ll="ls -lh --color=auto"
  alias la="ls -lah --color=auto"
fi

# --- cat -> bat, with fallback ---
if command -v bat >/dev/null 2>&1; then
  alias cat="bat --paging=never"
elif command -v batcat >/dev/null 2>&1; then
  alias cat="batcat --paging=never"
fi

# --- rg / fd: first-class commands, NO aliases over grep/find ---
# Technical decision: rg and fd are NOT grep/find with other flags (`grep -Ev`,
# `find . -name` would break). Installed and documented, not shadowed.
# Use rg/fd directly; stock grep/find untouched.

# --- zoxide: `z` only if present (real init is in zshrc) ---
if command -v zoxide >/dev/null 2>&1; then
  alias z="__zoxide_z 2>/dev/null || z"
  alias zi="__zoxide_zi 2>/dev/null || z -i"
fi

# --- General shortcuts (classic YADR parity, portable only) ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias h="history -100"
alias e="$EDITOR"
alias v="$EDITOR"
alias cdb="cd -"
alias cls="clear;ls"
alias cl="clear"
alias lsg="ll | grep"
alias lh="ls -alt | head"
alias df="df -h"
alias du="du -h -d 2"
alias less="less -r"
alias tf="tail -f"
alias l="less"
alias gz="tar -zcvf"
alias ka9="killall -9"
alias k9="kill -9"
alias psa="ps aux"
alias psg="ps aux | grep "
alias :q="exit"
alias ve="$EDITOR ~/.config/nvim/init.lua"
alias ze="$EDITOR ~/.zshrc"
alias gar="killall -HUP -u \"$USER\" zsh"  # global zsh reload
alias yup="yadr update"
if command -v gh >/dev/null 2>&1; then
  alias hpr="gh pr create"   # classic: hub pull-request -> modern gh
fi
if command -v brew >/dev/null 2>&1; then
  alias brewu="brew update && brew upgrade && brew cleanup && brew doctor"
fi
