#!/usr/bin/env bash
# YADR 2027 — lib/completion.sh: `yadr completion <shell>` and where the files go
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.
#
# The three scripts are written out in full on purpose. They are small, a human
# reads them, and every shell's completion syntax is different enough that
# "sharing" them would mean inventing a language of our own — the same
# deliberate non-DRY the CLI contract already documents.
#
#   yadr completion bash|zsh|fish   prints one script to stdout (wire by hand)
#   yadr completion --install       writes all three where each shell reads them
#   yadr install                    does the same write, plus the dotfiles
#
# Destinations come from bin/lib/paths.sh (ADR-005): every shell's own XDG
# directory, so a machine with moved XDG_* still loads them. shell/zshrc puts
# the zsh directory on $fpath; bash-completion and fish discover theirs.

completion_scripts() { # "shell<TAB>file" for every completion YADR installs
  printf '%s\t%s\n' bash "$(bash_completion_file)"
  printf '%s\t%s\n' zsh  "$(zsh_completion_file)"
  printf '%s\t%s\n' fish "$(fish_completion_file)"
}

completion_script() { # completion_script <bash|zsh|fish> — prints it to stdout
  case "$1" in
    bash) cat <<'YADR_COMPLETION_BASH'
# yadr(1) completion for bash — YADR 2027
# Install:  yadr completion bash > "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/yadr"
# Or just:  yadr install   (writes it there for you)
_yadr_complete() {
  local cur cmd words
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmd="${COMP_WORDS[1]}"
  local commands="backup benchmark completion diff doctor gitsigns help install migrate runtime theme uninstall update version"

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W '--yes --help -y -h' -- "$cur") )
    return 0
  fi
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi
  case "$cmd" in
    install)   words='core node javascript typescript ruby python rust lazygit tools development macos-extras' ;;
    uninstall) words='--dry-run --purge' ;;
    migrate)   words='--dry-run' ;;
    theme)     words='list use current' ;;
    gitsigns)  words='on off status' ;;
    runtime)   words='current list use doctor' ;;
    benchmark) words='shell nvim cd prompt' ;;
    *)         words='' ;;
  esac
  COMPREPLY=( $(compgen -W "$words --yes -y --help -h" -- "$cur") )
  return 0
}
complete -F _yadr_complete yadr
YADR_COMPLETION_BASH
      ;;
    zsh) cat <<'YADR_COMPLETION_ZSH'
#compdef yadr
# yadr(1) completion for zsh — YADR 2027
# Install:  yadr completion zsh > "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions/_yadr"
# Or just:  yadr install   (writes it there and shell/zshrc puts it on $fpath)
_yadr() {
  local -a sub
  if (( CURRENT == 2 )); then
    compadd -- backup benchmark completion diff doctor gitsigns help install migrate runtime theme uninstall update version
    return
  fi
  case "${words[2]}" in
    install)   sub=(core node javascript typescript ruby python rust lazygit tools development macos-extras) ;;
    uninstall) sub=(--dry-run --purge) ;;
    migrate)   sub=(--dry-run) ;;
    theme)     sub=(list use current) ;;
    gitsigns)  sub=(on off status) ;;
    runtime)   sub=(current list use doctor) ;;
    benchmark) sub=(shell nvim cd prompt) ;;
  esac
  (( ${#sub} )) && compadd -- "${sub[@]}"
}
_yadr "$@"
YADR_COMPLETION_ZSH
      ;;
    fish) cat <<'YADR_COMPLETION_FISH'
# yadr(1) completion for fish — YADR 2027
# Install:  yadr completion fish > "${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/yadr.fish"
# Or just:  yadr install   (writes it there; fish loads it automatically)
complete -c yadr -f
complete -c yadr -n __fish_use_subcommand -a backup -d 'copy current dotfiles to the backup dir'
complete -c yadr -n __fish_use_subcommand -a benchmark -d 'measure startup (shell|nvim|cd|prompt)'
complete -c yadr -n __fish_use_subcommand -a completion -d 'print a shell completion script (bash|zsh|fish)'
complete -c yadr -n __fish_use_subcommand -a diff -d 'show what would change, modifies nothing'
complete -c yadr -n __fish_use_subcommand -a doctor -d 'check the environment with hints'
complete -c yadr -n __fish_use_subcommand -a gitsigns -d 'Git signs in Neovim (on|off|status)'
complete -c yadr -n __fish_use_subcommand -a help -d 'show usage'
complete -c yadr -n __fish_use_subcommand -a install -d 'install YADR (profile)'
complete -c yadr -n __fish_use_subcommand -a migrate -d 'import classic YADR customization'
complete -c yadr -n __fish_use_subcommand -a runtime -d 'current|list|use|doctor'
complete -c yadr -n __fish_use_subcommand -a theme -d 'Solarized background (list|use|current)'
complete -c yadr -n __fish_use_subcommand -a uninstall -d 'revert install and restore your backup'
complete -c yadr -n __fish_use_subcommand -a update -d 'git pull + runtime upgrades'
complete -c yadr -n __fish_use_subcommand -a version -d 'print version'
complete -c yadr -n '__fish_seen_subcommand_from install' -a 'core node javascript typescript ruby python rust lazygit tools development macos-extras'
complete -c yadr -n '__fish_seen_subcommand_from uninstall' -a '--dry-run --purge'
complete -c yadr -n '__fish_seen_subcommand_from migrate' -a '--dry-run'
complete -c yadr -n '__fish_seen_subcommand_from theme' -a 'list use current'
complete -c yadr -n '__fish_seen_subcommand_from gitsigns' -a 'on off status'
complete -c yadr -n '__fish_seen_subcommand_from runtime' -a 'current list use doctor'
complete -c yadr -n '__fish_seen_subcommand_from benchmark' -a 'shell nvim cd prompt'
complete -c yadr -l yes -s y -d 'skip confirmations'
complete -c yadr -l help -s h -d 'show usage'
YADR_COMPLETION_FISH
      ;;
    *) return 1 ;;
  esac
}

ensure_completions() { # writes all three where each shell reads them (idempotent)
  local shell file tmp n=0
  while IFS=$'\t' read -r shell file; do
    [[ -n "$shell" ]] || continue
    mkdir -p "$(dirname "$file")" 2>/dev/null || { warn "cannot create $(dirname "$file")"; continue; }
    tmp="${file}.tmp.$$"
    if completion_script "$shell" > "$tmp" 2>/dev/null; then
      if mv -f "$tmp" "$file"; then n=$((n+1)); else rm -f "$tmp"; warn "cannot write ${file}"; fi
    else
      rm -f "$tmp"; warn "cannot generate the ${shell} completion"
    fi
  done < <(completion_scripts)
  [[ "$n" -gt 0 ]] && info "shell completions installed: ${n} (bash, zsh, fish)"
  return 0
}

completions_inventory() { # the files install wrote and uninstall would remove
  local shell file
  while IFS=$'\t' read -r shell file; do
    [[ -n "$file" ]] || continue
    if [[ -e "$file" || -L "$file" ]]; then printf '  %s\n' "$file"; fi
  done < <(completion_scripts)
  return 0
}

remove_completions() { # deletes only the files install wrote; empty dirs go too
  local shell file
  while IFS=$'\t' read -r shell file; do
    [[ -n "$file" ]] || continue
    if [[ -e "$file" || -L "$file" ]]; then
      rm -f "$file" && info "  removed: ${file}"
      rmdir "$(dirname "$file")" 2>/dev/null || true
    fi
  done < <(completion_scripts)
  return 0
}

cmd_completion() {
  case "${1:-}" in
    bash|zsh|fish) completion_script "$1" ;;
    --install)     ensure_completions ;;
    ""|--help|-h)
      cat <<'EOF'
usage: yadr completion <bash|zsh|fish>
       yadr completion --install

prints a shell completion script to stdout, or installs all of them (bash,
zsh, fish) where each shell reads them. `yadr install` writes them too.
EOF
      ;;
    *) die "completion: unknown shell '${1}' (bash|zsh|fish)" ;;
  esac
}
