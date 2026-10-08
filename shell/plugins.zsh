# YADR 2027 — shell/plugins.zsh
# Optional Zsh plugins: syntax-highlighting + autosuggestions.
# CAPABILITY is the contract; plugins are swappable. Shell runs
# degraded without them. Never fails (always return 0).
#
# Lookup order (first match wins):
#   1. $YADR_ZSH_SYNTAX_HL / $YADR_ZSH_AUTOSUGGEST (explicit, useful in tests)
#   2. $XDG_DATA_HOME/yadr-plugins/... (manual clone, no sudo)
#   3. apt: /usr/share/...
#   4. MacPorts: /opt/local/share/... (macOS Intel Tier 3)
#   5. brew: $(brew --prefix)/share/...
# Install: platform/linux.sh and platform/macos.sh already include them.

_yadr_brew_share() {
  command -v brew >/dev/null 2>&1 || return 1
  printf '%s/share' "$(brew --prefix 2>/dev/null)" || return 1
}

_yadr_plugin_first() {
  local explicit="$1" subdir="$2" file="$3" brew_share=""
  brew_share="$(_yadr_brew_share)" || brew_share=""
  local f
  for f in "$explicit" \
           "${XDG_DATA_HOME:-$HOME/.local/share}/yadr-plugins/${subdir}/${file}" \
           "/usr/share/${subdir}/${file}" \
           "/opt/local/share/${subdir}/${file}" \
           "${brew_share:+$brew_share/${subdir}/${file}}"; do
    if [[ -n "$f" && -f "$f" ]]; then
      source "$f" 2>/dev/null || true
      return 0
    fi
  done
  return 1
}

# --- syntax highlighting ---
if _yadr_plugin_first "${YADR_ZSH_SYNTAX_HL:-}" \
    "zsh-syntax-highlighting" "zsh-syntax-highlighting.zsh"; then
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
fi

# --- autosuggestions (Ctrl-E accepts; no clash with Vim mode or Ctrl-R) ---
if _yadr_plugin_first "${YADR_ZSH_AUTOSUGGEST:-}" \
    "zsh-autosuggestions" "zsh-autosuggestions.zsh"; then
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
  bindkey '^E' autosuggest-accept 2>/dev/null || true
fi

unfunction _yadr_brew_share _yadr_plugin_first 2>/dev/null || true
return 0 2>/dev/null || true
