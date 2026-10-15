#!/usr/bin/env bats
# shell.bats — aliases/runtime/damoekri must not break without modern tools.
# Requires: bats-core, zsh, git. Every test must pass on a minimal machine.
# TEST_HOME is wiped per test: no test may depend on another test's leftovers.

setup() {
  export YADR_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # Isolate HOME to avoid touching real dotfiles; fresh per test
  export TEST_HOME="$BATS_TMPDIR/yadr-home"
  rm -rf "$TEST_HOME"; mkdir -p "$TEST_HOME"
}

# Helper: source shell/aliases.zsh when present, else skip.
# zsh itself is required (no silent fallback: a missing zsh must fail loudly).
load_aliases() {
  [ -f "$YADR_ROOT/shell/aliases.zsh" ] || skip "shell/aliases.zsh not in checkout"
  command -v zsh >/dev/null 2>&1 || { echo "zsh required for shell tests" >&2; return 1; }
  # Simulate missing modern tools
  PATH="/usr/bin:/bin" HOME="$TEST_HOME" zsh -f -c "source '$YADR_ROOT/shell/aliases.zsh'; echo loaded" 2>/dev/null
}

@test "aliases load without eza/bat/rg/fd/zoxide" {
  run load_aliases
  [ "$status" -eq 0 ]
  [[ "$output" == *"loaded"* ]]
}

@test "ls fallback works without eza" {
  if [ ! -f "$YADR_ROOT/shell/aliases.zsh" ]; then skip "aliases.zsh not in checkout"; fi
  run zsh -f -c "PATH=/usr/bin:/bin; source '$YADR_ROOT/shell/aliases.zsh' 2>/dev/null; command ls --version >/dev/null 2>&1 || command ls >/dev/null 2>&1; echo ok"
  [ "$status" -eq 0 ]
}

@test "zsh has no repo-defined z without zoxide, cd still works" {
  [ -f "$YADR_ROOT/shell/aliases.zsh" ] || skip "aliases.zsh not in checkout"
  # Never executes `z` (a system-provided one must not fail the suite);
  # fails only when the REPO defines z as alias/function without zoxide.
  run zsh -f -c "
    PATH=/usr/bin:/bin
    source '$YADR_ROOT/shell/aliases.zsh' 2>/dev/null
    kind=\$(whence -w z 2>/dev/null); [ -n "\$kind" ] || kind='z: none'
    case \"\$kind\" in
      *alias*|*function*) echo \"repo-defined z without zoxide: \$kind\"; exit 1 ;;
    esac
    cd / >/dev/null 2>&1 && echo \"no-z-ok (\$kind)\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"no-z-ok"* ]]
}

@test "damoekri prompt file exists and has no ruby hard-dependency" {
  [ -f "$YADR_ROOT/shell/damoekri.zsh" ] || fail "shell/damoekri.zsh missing"
  # Must not invoke rvm/rbenv/nvm/fnm/mise directly: only via yadr_runtime_context.
  run grep -E "rvm-prompt|rbenv|mise current|fnm current" "$YADR_ROOT/shell/damoekri.zsh"
  # grep match (0) = bad, unless it is a comment; no match (1) = good.
  if [ "$status" -eq 0 ]; then
    run bash -c "grep -v '^#' '$YADR_ROOT/shell/damoekri.zsh' | grep -E 'rvm-prompt|rbenv|mise current|fnm current'"
    [ "$status" -ne 0 ]
  fi
}

@test "damoekri prompt uses classic green » on a single line" {
  run zsh -f -c "
    source '$YADR_ROOT/shell/damoekri.zsh'
    [[ \"\$PROMPT\" == *'»'* ]] || exit 1
    [[ \"\$PROMPT\" != *\$'\n'* ]] || exit 1
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "damoekri loads without runtime.zsh and renders empty git outside repos" {
  run zsh -f -c "
    cd '$TEST_HOME' || exit 1
    source '$YADR_ROOT/shell/damoekri.zsh'
    out=\$(yadr_git_info 2>/dev/null)
    [ -z \"\$out\" ] || exit 1
    _yadr_runtime_segment >/dev/null 2>&1 || exit 1
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "damoekri shows branch and clean mark inside git repo" {
  gd="$BATS_TMPDIR/yadr-git-$$"
  run bash -c "
    rm -rf '$gd' && mkdir -p '$gd' && cd '$gd' &&
    git init -q . 2>/dev/null &&
    git config user.email t@t.t && git config user.name t &&
    touch f && git add f && git commit -qm init &&
    br=\$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD) &&
    out=\$(cd '$gd' && zsh -f -c \"source '$YADR_ROOT/shell/damoekri.zsh'; yadr_git_info\" 2>/dev/null) &&
    echo \"\$out\" | grep -q \"\$br\" && echo \"\$out\" | grep -q '✔' && echo ok;
    rm -rf '$gd'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "damoekri shows dirty mark on unstaged change" {
  gd="$BATS_TMPDIR/yadr-dirty-$$"
  run bash -c "
    rm -rf '$gd' && mkdir -p '$gd' && cd '$gd' &&
    git init -q . 2>/dev/null &&
    git config user.email t@t.t && git config user.name t &&
    touch f && git add f && git commit -qm init &&
    echo mod >> f &&
    out=\$(cd '$gd' && zsh -f -c \"source '$YADR_ROOT/shell/damoekri.zsh'; yadr_git_info\" 2>/dev/null) &&
    echo \"\$out\" | grep -q '✗' && echo ok;
    rm -rf '$gd'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "plugins.zsh loads cleanly without any plugin installed" {
  [ -f "$YADR_ROOT/shell/plugins.zsh" ] || fail "shell/plugins.zsh missing"
  run zsh -f -c "
    unset YADR_ZSH_SYNTAX_HL YADR_ZSH_AUTOSUGGEST
    XDG_DATA_HOME='$BATS_TMPDIR/empty-xdg' source '$YADR_ROOT/shell/plugins.zsh'
    echo status=\$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status=0"* ]]
}

@test "plugins.zsh sources explicit plugin files when present" {
  d="$BATS_TMPDIR/yadr-stubs-$$"
  mkdir -p "$d"
  echo 'YADR_STUB_HL_LOADED=1' > "$d/hl.zsh"
  printf 'YADR_STUB_AS_LOADED=1\nautosuggest-accept() { :; }\n' > "$d/as.zsh"
  run zsh -f -c "
    YADR_ZSH_SYNTAX_HL='$d/hl.zsh' YADR_ZSH_AUTOSUGGEST='$d/as.zsh' source '$YADR_ROOT/shell/plugins.zsh'
    echo hl=\$YADR_STUB_HL_LOADED as=\$YADR_STUB_AS_LOADED"
  rm -rf "$d"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hl=1 as=1"* ]]
}

@test "zshrc sources plugins module after compinit" {
  [ -f "$YADR_ROOT/shell/zshrc" ] || fail "shell/zshrc missing"
  run bash -c "grep -n 'plugins.zsh' '$YADR_ROOT/shell/zshrc' | head -1"
  [ "$status" -eq 0 ]
}
@test "runtime context never fails and is empty without tools" {
  run zsh -f -c "PATH=/usr/bin:/bin; source '$YADR_ROOT/shell/runtime.zsh'; yadr_runtime_context >/dev/null 2>&1; echo status=\$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status=0"* ]]
}

@test "runtime context shows global runtime outside projects (classic behavior)" {
  run zsh -f -c "
    source '$YADR_ROOT/shell/runtime.zsh'
    cd /tmp || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ -n \"\$out\" ] || { echo 'empty outside project (no runtimes on this host?)'; exit 1; }
    out2=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = \"\$out2\" ] || { echo 'cache mismatch'; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime context is non-empty in fixture project" {
  run zsh -f -c "
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$YADR_ROOT/tests/fixtures/typescript-project' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ -n \"\$out\" ] || { echo 'empty inside fixture project'; exit 1; }
    out2=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = \"\$out2\" ] || { echo 'cache mismatch'; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime layer guards mise absence" {
  [ -f "$YADR_ROOT/shell/runtime.zsh" ] || skip "runtime.zsh not in checkout"
  run zsh -f -c "PATH=/usr/bin:/bin; source '$YADR_ROOT/shell/runtime.zsh'; echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "classic shell aliases are present (ga/cl/gd/gco/gs/gf/gps/...)" {
  run zsh -f -c "
    source '$YADR_ROOT/shell/aliases.zsh' 2>/dev/null
    for a in ga gap gco gd gdc gds gs gst gsp gf gfp gpl gps gnb grs gcln gsm gb gl gt g cl cls cdb lsg less tf gz ka9 psa ve ze yup grb; do
      whence -w \$a >/dev/null 2>&1 || { echo \"missing alias: \$a\"; exit 1; }
    done
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "gitconfig provides subaliases used by shell aliases" {
  run bash -c "
    cfg='$YADR_ROOT/git/gitconfig'
    for s in a b c ca amend nb cp d dc l s st t unstage uncommit rc rs r pl ps ss sl sa sd co ci filelog; do
      grep -qE \"^[[:space:]]*\$s[[:space:]]*=\" \"\$cfg\" || { echo \"missing git alias: \$s\"; exit 1; }
    done
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "git user config include pattern preserved" {
  [ -f "$YADR_ROOT/git/gitconfig" ] || skip "git/gitconfig not in checkout"
  run grep -q "gitconfig.user" "$YADR_ROOT/git/gitconfig"
  [ "$status" -eq 0 ]
}

@test "theme defaults to none on clean HOME" {
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme current
  [ "$status" -eq 0 ]
  [[ "$output" == *"none"* ]]
}

@test "theme use persists canonical names (incl. solarized-* aliases)" {
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme use solarized-dark
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_HOME/.config/yadr/solarized-bg")" = "dark" ]
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme use light
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_HOME/.config/yadr/solarized-bg")" = "light" ]
}

@test "theme shorthand and list mark current" {
  env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme use dark >/dev/null
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme dark
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme list
  [ "$status" -eq 0 ]
  [[ "$output" == *"dark"* ]]
}

@test "theme rejects unknown names without touching the file" {
  env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme use light >/dev/null
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme use banana
  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_HOME/.config/yadr/solarized-bg")" = "light" ]
}

@test "theme env override wins over file" {
  env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme use dark >/dev/null
  run env HOME="$TEST_HOME" YADR_SOLARIZED_BG=light bash "$YADR_ROOT/bin/yadr" theme current
  [ "$status" -eq 0 ]
  [[ "$output" == *"light (env"* ]]
}

yadr_funcs() {
  # source bin/yadr function library without running its CLI dispatch
  local f="$BATS_TMPDIR/yadr-funcs-$$.sh"
  awk '/^# --- parse global flags ---/{exit} {print}' "$YADR_ROOT/bin/yadr" > "$f"
  printf '%s' "$f"
}

@test "nerd font detected via macOS Library/Fonts without fc-list" {
  mkdir -p "$TEST_HOME/Library/Fonts"
  touch "$TEST_HOME/Library/Fonts/JetBrainsMonoNerd.ttf"
  run bash -c "export HOME='$TEST_HOME' PATH='/usr/bin:/bin'; source '$(yadr_funcs)'; nerd_font_present && nerd_font_source"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mac-fonts"* ]]
}

@test "nerd font detected via fc-list fallback" {
  mkdir -p "$BATS_TMPDIR/fakebin"
  printf '#!/usr/bin/env bash\necho "JetBrainsMono Nerd Font"\n' > "$BATS_TMPDIR/fakebin/fc-list"
  chmod +x "$BATS_TMPDIR/fakebin/fc-list"
  run bash -c "export HOME='$TEST_HOME' PATH='$BATS_TMPDIR/fakebin:/usr/bin:/bin'; source '$(yadr_funcs)'; nerd_font_present && nerd_font_source"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fc-list"* ]]
}

@test "nerd font absent without dirs or fc-list tools" {
  rm -rf "$TEST_HOME/Library/Fonts"
  run bash -c "export HOME='$TEST_HOME' PATH='/usr/bin:/bin'; source '$(yadr_funcs)'; nerd_font_present"
  [ "$status" -ne 0 ]
}

platform_funcs() {
  # source platform/linux.sh functions without running its main()
  local f="$BATS_TMPDIR/platform-funcs-$$.sh"
  awk '/^main "\$@"$/{exit} {print}' "$YADR_ROOT/platform/linux.sh" > "$f"
  printf '%s' "$f"
}

@test "ensure_vim shims even with genuine vim present" {
  mkdir -p "$TEST_HOME/.local/nvim-upstream/bin" "$TEST_HOME/.local/state/yadr" "$BATS_TMPDIR/fakevim/bin"
  printf '#!/usr/bin/env bash\necho "NVIM v0.12.5"\n' > "$TEST_HOME/.local/nvim-upstream/bin/nvim"
  chmod +x "$TEST_HOME/.local/nvim-upstream/bin/nvim"
  touch "$TEST_HOME/.local/state/yadr/provides-nvim-upstream"
  printf '#!/usr/bin/env bash\necho "VIM - Vi IMproved 9.0"\n' > "$BATS_TMPDIR/fakevim/bin/vim"
  chmod +x "$BATS_TMPDIR/fakevim/bin/vim"
  run bash -c "export HOME='$TEST_HOME' PATH='$BATS_TMPDIR/fakevim/bin:/usr/bin:/bin'; source '$(platform_funcs)'; ensure_vim >/dev/null"
  [ "$status" -eq 0 ]
  [ "$(readlink "$TEST_HOME/.local/bin/vim")" = "$TEST_HOME/.local/nvim-upstream/bin/nvim" ]
  [ -f "$TEST_HOME/.local/state/yadr/provides-vim" ]
}

@test "doctor warns when git identity is missing, ok when present" {
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" doctor
  [[ "$output" == *"git identity not configured"* ]]
  printf '[user]\n\tname = Test User\n\temail = test@example.com\n' > "$TEST_HOME/.gitconfig.user"
  cp "$YADR_ROOT/git/gitconfig" "$TEST_HOME/.gitconfig"
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" doctor
  [[ "$output" == *"git identity configured"* ]]
}

@test "dirty_tree_list reports modifications, empty when clean" {
  local repo="$BATS_TMPDIR/dirtyrepo-$$"
  rm -rf "$repo"; mkdir -p "$repo"
  ( cd "$repo" && git init -q . && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init && echo mod > f && git add f )
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; YADR_HOME='$repo'; dirty_tree_list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"f"* ]]
  rm -rf "$repo"
}

macos_funcs() {
  # source platform/macos.sh functions without running its main()
  local f="$BATS_TMPDIR/macos-funcs-$$.sh"
  awk '/^main "\$@"$/{exit} {print}' "$YADR_ROOT/platform/macos.sh" > "$f"
  printf '%s' "$f"
}

@test "solarized-bg path is identical in macOS menu, lua and CLI" {
  run bash -c "
    set -e
    grep -q 'HOME}/.config/yadr/solarized-bg' '$YADR_ROOT/platform/macos.sh' || exit 1
    grep -q '~/.config/yadr/solarized-bg' '$YADR_ROOT/nvim/lua/yadr/plugins/colorscheme.lua' || exit 1
    grep -q 'HOME}/.config/yadr/solarized-bg' '$YADR_ROOT/bin/yadr' || exit 1
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "macOS menu writes canonical theme names the CLI reads" {
  run bash -c "export HOME='$TEST_HOME'; source '$(macos_funcs)' >/dev/null 2>&1; YADR_SOLARIZED_BG=dark choose_solarized_bg >/dev/null && cat '$TEST_HOME/.config/yadr/solarized-bg'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dark"* ]]
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" theme current
  [ "$status" -eq 0 ]
  [[ "$output" == *"dark"* ]]
}

@test "purge keeps pre-existing share entries, removes YADR-added ones" {
  local share="$TEST_HOME/.local/share/nvim"
  mkdir -p "$share" "$TEST_HOME/.local/state/yadr"
  touch "$share/precious-data" "$share/lazy.nvim"
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; export STATE_DIR='$TEST_HOME/.local/state/yadr'; printf 'precious-data\n' > \"\$STATE_DIR/preexisting-share-nvim\"; purge_dir_keep_preexisting '$share' share-nvim"
  [ "$status" -eq 0 ]
  [ -f "$share/precious-data" ]
  [ ! -e "$share/lazy.nvim" ]
}

@test "snapshot_share_dirs is first-install-wins" {
  local share="$TEST_HOME/.local/share/mise"
  mkdir -p "$share" "$TEST_HOME/.local/state/yadr"
  touch "$share/old-tool"
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; export STATE_DIR='$TEST_HOME/.local/state/yadr'; snapshot_share_dirs"
  [ "$status" -eq 0 ]
  touch "$share/new-tool"
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; export STATE_DIR='$TEST_HOME/.local/state/yadr'; snapshot_share_dirs; cat \"\$STATE_DIR/preexisting-share-mise\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"old-tool"* ]]
  [[ "$output" != *"new-tool"* ]]
}

@test "purge refuses blind wipe without snapshot" {
  local share="$TEST_HOME/.local/share/zoxide"
  mkdir -p "$share"
  touch "$share/something"
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; export STATE_DIR='$TEST_HOME/.local/state/yadr'; purge_dir_keep_preexisting '$share' share-zoxide"
  [ "$status" -eq 0 ]
  [ -f "$share/something" ]
}

@test "canonical home is ~/.yadr-2027 in bootstrap and docs" {
  run bash -c "
    set -e
    grep -q 'DEFAULT_HOME=\"\${HOME}/.yadr-2027\"' '$YADR_ROOT/bootstrap.sh' || exit 1
    grep -q 'marcoarata/dotfiles.git ~/\.yadr-2027' '$YADR_ROOT/README.md' || exit 1
    grep -q 'marcoarata/dotfiles.git ~/\.yadr-2027' '$YADR_ROOT/INSTALL-YADR.md' || exit 1
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
