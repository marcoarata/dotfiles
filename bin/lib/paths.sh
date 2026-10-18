#!/usr/bin/env bash
# YADR 2027 — lib/paths.sh: one place for every filesystem path policy (ADR-005)
# Sourced by bin/yadr before any other module (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.
#
# Why this file exists: the installer, `doctor`, the purge inventory and the
# tools YADR configures all have an opinion about where a file lives. When those
# opinions differ, the failure is silent (a symlink nobody reads, a warning that
# cannot be cleared, a purge that leaves data behind). Every destination is
# therefore computed here, following the same environment variables as the tool
# that reads it:
#
#   YADR's own files        XDG_CONFIG_HOME/yadr, XDG_STATE_HOME/yadr
#   Neovim (config/data)    XDG_CONFIG_HOME/nvim, XDG_DATA_HOME/nvim, ...
#   mise / zoxide data      XDG_DATA_HOME/<tool>
#   zsh rc                  $ZDOTDIR/.zshrc (zsh's own variable, not XDG)
#   shell completions       XDG_DATA_HOME/bash-completion, XDG_DATA_HOME/zsh,
#                           XDG_CONFIG_HOME/fish: each shell's own directory
#   git / tmux              ~/.gitconfig, ~/.tmux.conf: read by the tool even
#                           when XDG is set, so they stay HOME-based
#   YADR's own binaries     ~/.local/bin (no XDG equivalent for executables)
#
# Every helper falls back to the XDG spec default ($HOME/.config, ...), so a
# machine that does not set the variables behaves exactly as before.

xdg_config() { printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
xdg_data()   { printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}"; }
xdg_cache()  { printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}"; }
xdg_state()  { printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}"; }

# YADR's own directories (theme, migrated/, markers, backups, snapshots).
yadr_config_dir() { printf '%s/yadr' "$(xdg_config)"; }
yadr_state_dir()  { printf '%s/yadr' "$(xdg_state)"; }
yadr_plugins_dir() { printf '%s/yadr-plugins' "$(xdg_data)"; }

# Directories owned by the tools YADR links or installs.
nvim_config_dir() { printf '%s/nvim' "$(xdg_config)"; }
nvim_data_dir()   { printf '%s/nvim' "$(xdg_data)"; }
nvim_cache_dir()  { printf '%s/nvim' "$(xdg_cache)"; }
nvim_state_dir()  { printf '%s/nvim' "$(xdg_state)"; }
mise_config_dir() { printf '%s/mise' "$(xdg_config)"; }
mise_data_dir()   { printf '%s/mise' "$(xdg_data)"; }
zoxide_data_dir() { printf '%s/zoxide' "$(xdg_data)"; }

# Shell completions: each shell loads its own directory. bash-completion reads
# $XDG_DATA_HOME/bash-completion/completions, fish reads
# $XDG_CONFIG_HOME/fish/completions, and zsh needs the file on $fpath (the
# same XDG data dir, added by shell/zshrc) — all three honour XDG.
bash_completion_file() { printf '%s/bash-completion/completions/yadr' "$(xdg_data)"; }
fish_completion_file() { printf '%s/fish/completions/yadr.fish' "$(xdg_config)"; }
zsh_completion_file()  { printf '%s/zsh/site-functions/_yadr' "$(xdg_data)"; }

# zsh reads $ZDOTDIR/.zshrc when the variable is set, ~/.zshrc otherwise.
zshrc_path() { printf '%s/.zshrc' "${ZDOTDIR:-$HOME}"; }
