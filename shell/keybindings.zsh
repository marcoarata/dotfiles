# YADR 2027 — shell/keybindings.zsh
# Vi mode + fuzzy search. No plugins.

# --- Vi mode as default ---
bindkey -v
export KEYTIMEOUT=1   # 10ms: fast Esc, no broken sequences

# --- History: Ctrl-R incremental backward search ---
bindkey '^R' history-incremental-search-backward
# In vicmd, `/` and `?` already search; reinforce:
bindkey -M vicmd '/' history-incremental-search-backward
bindkey -M vicmd '?' history-incremental-search-forward

# --- Ctrl-X Ctrl-L: clear + re-list ("clear list" mnemonic) ---
_clear-and-list() {
  clear
  zle list-choices 2>/dev/null || zle redisplay
}
zle -N _clear-and-list
bindkey '^X^L' _clear-and-list

# --- Edit line in $EDITOR ---
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line   # vicmd: `v` opens vim
bindkey '^X^E' edit-command-line         # emacs-style fallback

# --- Fuzzy-style completion navigation ---
bindkey -M menuselect '^N' forward-char 2>/dev/null || true
bindkey -M menuselect '^P' backward-char 2>/dev/null || true
bindkey -M menuselect '^J' accept-line 2>/dev/null || true

# --- Up/Down: substring history (type prefix + arrow) ---
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search    # Up
bindkey '^[[B' down-line-or-beginning-search  # Down
bindkey -M vicmd 'k' up-line-or-beginning-search
bindkey -M vicmd 'j' down-line-or-beginning-search

# --- Utilities ---
bindkey '^U' backward-kill-line   # clear line like emacs
bindkey '^?' backward-delete-char # consistent backspace in viins
