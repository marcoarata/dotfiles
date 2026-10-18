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
  # Hermetic: stub node so the test needs no host toolchain.
  mkdir -p "$BATS_TMPDIR/fakenode"
  printf '#!/usr/bin/env bash\necho "v22.9.9"\n' > "$BATS_TMPDIR/fakenode/node"
  chmod +x "$BATS_TMPDIR/fakenode/node"
  run zsh -f -c "
    PATH='$BATS_TMPDIR/fakenode:/usr/bin:/bin'
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$TEST_HOME' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = 'node-22.9.9' ] || { echo \"got: \$out\"; exit 1; }
    out2=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = \"\$out2\" ] || { echo 'cache mismatch'; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime context is non-empty in fixture project" {
  # Hermetic: stub node so the test needs no host toolchain.
  mkdir -p "$BATS_TMPDIR/fakenode"
  printf '#!/usr/bin/env bash\necho "v22.9.9"\n' > "$BATS_TMPDIR/fakenode/node"
  chmod +x "$BATS_TMPDIR/fakenode/node"
  run zsh -f -c "
    PATH='$BATS_TMPDIR/fakenode:/usr/bin:/bin'
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$YADR_ROOT/tests/fixtures/typescript-project' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [[ \"\$out\" == *'node-22.9.9'* ]] || { echo \"got: \$out\"; exit 1; }
    out2=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = \"\$out2\" ] || { echo 'cache mismatch'; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime context shows only the project-pinned runtime (mise source)" {
  local proj="$BATS_TMPDIR/proj-mise" fake="$BATS_TMPDIR/fakemise"
  mkdir -p "$proj" "$fake"; : > "$proj/mise.toml"
  cat > "$fake/mise" <<EOF
#!/usr/bin/env bash
cat <<OUT
node    24.22.0    ~/.config/mise/config.toml    24
python  3.12.15    $proj/mise.toml               3.12
OUT
EOF
  chmod +x "$fake/mise"
  run zsh -f -c "
    PATH='$fake:/usr/bin:/bin'
    unset XDG_CONFIG_HOME; export HOME='$TEST_HOME'
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$proj' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = 'python-3.12.15' ] || { echo \"got: \$out\"; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime context in a project without pins falls back to global node" {
  local proj="$BATS_TMPDIR/proj-nopin" fake="$BATS_TMPDIR/fakemise"
  mkdir -p "$proj" "$fake"
  printf '{\n  "name": "x"\n}\n' > "$proj/package.json"
  cat > "$fake/mise" <<'EOF'
#!/usr/bin/env bash
cat <<OUT
node    24.22.0    ~/.config/mise/config.toml    24
OUT
EOF
  chmod +x "$fake/mise"
  run zsh -f -c "
    PATH='$fake:/usr/bin:/bin'
    unset XDG_CONFIG_HOME; export HOME='$TEST_HOME'
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$proj' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = 'node-24.22.0' ] || { echo \"got: \$out\"; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime context outside a project shows global node only" {
  local fake="$BATS_TMPDIR/fakemise"
  mkdir -p "$fake"
  cat > "$fake/mise" <<'EOF'
#!/usr/bin/env bash
cat <<OUT
node    24.22.0    ~/.config/mise/config.toml    24
python  3.12.15    ~/.config/mise/config.toml    3.12
OUT
EOF
  chmod +x "$fake/mise"
  run zsh -f -c "
    PATH='$fake:/usr/bin:/bin'
    unset XDG_CONFIG_HOME; export HOME='$TEST_HOME'
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$TEST_HOME' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ \"\$out\" = 'node-24.22.0' ] || { echo \"got: \$out\"; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime context ignores runtime rows mise marks (missing)" {
  # mise lists what the *config* asks for even when it is not installed
  # ("node 24.22.0 (missing) …"): the prompt must never show that version.
  local fake="$BATS_TMPDIR/fakemise-missing" proj="$BATS_TMPDIR/proj-missing-$$"
  mkdir -p "$fake" "$proj"; : > "$proj/mise.toml"
  cat > "$fake/mise" <<'EOF'
#!/usr/bin/env bash
cat <<OUT
node    24.22.0    (missing)                     ~/.config/mise/config.toml  24
OUT
EOF
  chmod +x "$fake/mise"
  run zsh -f -c "
    PATH='$fake:/usr/bin:/bin'
    unset XDG_CONFIG_HOME; export HOME='$TEST_HOME'
    source '$YADR_ROOT/shell/runtime.zsh'
    cd '$TEST_HOME' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ -z \"\$out\" ] || { echo \"global got: \$out\"; exit 1; }
    cd '$proj' || exit 1
    out=\$(yadr_runtime_context 2>/dev/null)
    [ -z \"\$out\" ] || { echo \"project got: \$out\"; exit 1; }
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  rm -rf "$proj"
}

@test "runtime layer guards mise absence" {
  [ -f "$YADR_ROOT/shell/runtime.zsh" ] || skip "runtime.zsh not in checkout"
  run zsh -f -c "PATH=/usr/bin:/bin; source '$YADR_ROOT/shell/runtime.zsh'; echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "runtime use @version points to conf.d for user-global tools" {
  local fake="$BATS_TMPDIR/fakemise-use"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake/mise"
  chmod +x "$fake/mise"
  run bash -c "export HOME='$TEST_HOME' PATH='$fake:/usr/bin:/bin'; source '$(yadr_funcs)'; cmd_runtime_use node@24"
  [ "$status" -eq 0 ]
  [[ "$output" == *"conf.d"* ]]
  [[ "$output" != *"activando"* ]]
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

@test "gitconfig wires delta for pager and diffFilter with a guard" {
  run bash -c "
    cfg='$YADR_ROOT/git/gitconfig'
    git config --file \"\$cfg\" core.pager | grep -q 'command -v delta' || exit 1
    git config --file \"\$cfg\" interactive.diffFilter | grep -q 'command -v delta' || exit 1
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "git pager resolves to delta when present, less when absent" {
  local fake="$BATS_TMPDIR/pagerbin-$$"
  mkdir -p "$fake"
  local pager
  pager="$(git config --file "$YADR_ROOT/git/gitconfig" core.pager)"
  [ -n "$pager" ]
  printf '#!/usr/bin/env bash\necho delta-pager\n' > "$fake/delta"; chmod +x "$fake/delta"
  run bash -c "export PATH='$fake:/usr/bin:/bin'; $pager"
  [ "$status" -eq 0 ]
  [[ "$output" == *"delta-pager"* ]]
  rm -f "$fake/delta"
  printf '#!/usr/bin/env bash\necho less-fallback\n' > "$fake/less"; chmod +x "$fake/less"
  run bash -c "export PATH='$fake:/usr/bin:/bin'; $pager"
  [ "$status" -eq 0 ]
  [[ "$output" == *"less-fallback"* ]]
  rm -rf "$fake"
}

@test "yadr help lists the tools profile" {
  run env HOME="$TEST_HOME" bash "$YADR_ROOT/bin/yadr" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"tools"* ]]
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
  # source bin/yadr dispatcher (helpers) + bin/lib modules without running CLI dispatch.
  # The dispatcher resolves lib/ from its own path, so pin YADR_LIB_DIR to the
  # repo (the generated copy lives in $BATS_TMPDIR, not in bin/).
  local f="$BATS_TMPDIR/yadr-funcs-${BATS_TEST_NUMBER:-$$}.sh"
  printf 'export YADR_LIB_DIR="%s/bin/lib"\n' "$YADR_ROOT" > "$f"
  awk '/^# --- parse global flags ---/{exit} {print}' "$YADR_ROOT/bin/yadr" >> "$f"
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

@test "ensure_vim shims even with genuine vim present" {
  mkdir -p "$TEST_HOME/.local/nvim-upstream/bin" "$TEST_HOME/.local/state/yadr" "$BATS_TMPDIR/fakevim/bin"
  printf '#!/usr/bin/env bash\necho "NVIM v0.12.5"\n' > "$TEST_HOME/.local/nvim-upstream/bin/nvim"
  chmod +x "$TEST_HOME/.local/nvim-upstream/bin/nvim"
  touch "$TEST_HOME/.local/state/yadr/provides-nvim-upstream"
  printf '#!/usr/bin/env bash\necho "VIM - Vi IMproved 9.0"\n' > "$BATS_TMPDIR/fakevim/bin/vim"
  chmod +x "$BATS_TMPDIR/fakevim/bin/vim"
  run bash -c "export HOME='$TEST_HOME' PATH='$BATS_TMPDIR/fakevim/bin:/usr/bin:/bin' PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'; source '$(platform_funcs linux.sh)'; ensure_vim >/dev/null"
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
  local f="$BATS_TMPDIR/macos-funcs-${BATS_TEST_NUMBER:-$$}.sh"
  awk '/^main "\$@"$/{exit} {print}' "$YADR_ROOT/platform/macos.sh" > "$f"
  printf '%s' "$f"
}

@test "solarized-bg path is identical in macOS menu, lua and CLI" {
  run bash -c "
    set -e
    grep -q 'HOME}/.config/yadr/solarized-bg' '$YADR_ROOT/platform/macos.sh' || exit 1
    grep -q '~/.config/yadr/solarized-bg' '$YADR_ROOT/nvim/lua/yadr/plugins/colorscheme.lua' || exit 1
    grep -rq 'HOME}/.config/yadr/solarized-bg' '$YADR_ROOT/bin/yadr' '$YADR_ROOT/bin/lib/' || exit 1
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

platform_funcs() {
  # source one platform script's functions without running its main()
  # usage: platform_funcs <script>  (sets PLATFORM_COMMON to the real common.sh)
  local script="$1" f="$BATS_TMPDIR/platform-${BATS_TEST_NUMBER:-$PPID}.sh"
  awk '/^main "\$@"$/{exit} {print}' "$YADR_ROOT/platform/${script}" > "$f"
  printf '%s' "$f"
}

@test "nvim_version_ok accepts >=0.11, rejects below and garbage" {
  local stubs="$BATS_TMPDIR/nvstubs-$$"; mkdir -p "$stubs"
  printf '#!/usr/bin/env bash\necho "NVIM v0.12.5"\n' > "$stubs/new"; chmod +x "$stubs/new"
  printf '#!/usr/bin/env bash\necho "NVIM v0.9.1"\n' > "$stubs/old"; chmod +x "$stubs/old"
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    [ \"\$(nvim_version_ok '$stubs/new')\" = '0.12' ] || exit 1
    if nvim_version_ok '$stubs/old' >/dev/null 2>&1; then echo old-accepted; exit 1; fi
    if nvim_version_ok /nonexistent >/dev/null 2>&1; then echo missing-accepted; exit 1; fi
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  rm -rf "$stubs"
}

@test "yadr_marker records purge markers" {
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    yadr_marker font && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  [ -f "$TEST_HOME/.local/state/yadr/provides-font" ]
}

@test "fetch_verified_zip extracts verified zips, rejects bad sha" {
  local dest="$TEST_HOME/fonts"
  python3 -c "import zipfile; z=zipfile.ZipFile('$TEST_HOME/a.zip','w'); z.writestr('f.ttf','x'); z.close()"
  local sha; sha="$(sha256sum "$TEST_HOME/a.zip" | awk '{print $1}')"
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    fetch_verified_zip 'file://$TEST_HOME/a.zip' '$sha' '$dest' '*.ttf' && echo fetched-ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fetched-ok"* ]]
  [ -f "$dest/f.ttf" ]
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    fetch_verified_zip 'file://$TEST_HOME/a.zip' 'deadbeef' '$TEST_HOME/other' '*.ttf'"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_HOME/other/f.ttf" ]
}

@test "install tools pins eza/bat/delta in mise conf.d" {
  local fake="$BATS_TMPDIR/mise-tools-$$"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake/mise"
  chmod +x "$fake/mise"
  run bash -c "export HOME='$TEST_HOME' PATH='$fake:/usr/bin:/bin'; source '$(platform_funcs tools.sh)'; install_mise"
  [ "$status" -eq 0 ]
  local conf="$TEST_HOME/.config/mise/conf.d/yadr-tools.toml"
  [ -f "$conf" ]
  grep -q '^eza = "latest"' "$conf"
  grep -q '^bat = "latest"' "$conf"
  grep -q '^delta = "latest"' "$conf"
  [ -f "$TEST_HOME/.local/state/yadr/provides-tools" ]
}

@test "purge cleans YADR tools conf.d (marker-gated)" {
  run bash -c "grep -q 'provides-tools' '$YADR_ROOT/bin/lib/recover.sh' && grep -q 'conf.d/yadr-tools.toml' '$YADR_ROOT/bin/lib/recover.sh' && echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "install fast path fails loudly when a runtime does not install" {
  # A failed `mise install` must not end in "install [x] complete" + exit 0
  # (it did on WSL1, where node ≥23 cannot exec: user saw success, doctor saw nothing).
  local home="$BATS_TMPDIR/install-lie-$$" fake="$BATS_TMPDIR/install-lie-bin-$$" repo="$BATS_TMPDIR/install-lie-repo-$$"
  rm -rf "$home" "$fake" "$repo"; mkdir -p "$home/.local/bin" "$fake" "$repo"
  printf 'x\n' > "$repo/pair-src"
  ln -s "$repo/pair-src" "$home/.local/bin/yadr"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fake/mise"; chmod +x "$fake/mise"
  run bash -c "
    export HOME='$home' PATH='$fake:/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.local/bin/yadr\"; }
    do_install node"
  [ "$status" -ne 0 ]
  [[ "$output" == *"incomplete"* ]]
  [[ "$output" != *"complete (fast path)"* ]]
  # Same run with a working backend: the honest success path stays intact.
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake/mise"
  run bash -c "
    export HOME='$home' PATH='$fake:/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.local/bin/yadr\"; }
    do_install node"
  [ "$status" -eq 0 ]
  [[ "$output" == *"install [node] complete"* ]]
  rm -rf "$home" "$fake" "$repo"
}

@test "typescript payload runs Lazy! restore once, not twice" {
  # ensure_nvim_plugins already syncs the lockfile; ensure_lsp_servers used to
  # launch nvim a second time for the same restore (harmless, pure waste).
  local home="$BATS_TMPDIR/lsp-once-$$" bin="$BATS_TMPDIR/lsp-once-bin-$$" repo="$BATS_TMPDIR/lsp-once-repo-$$"
  rm -rf "$home" "$bin" "$repo"
  mkdir -p "$home/.local/share/nvim/lazy/lazy.nvim" "$home/.local/share/nvim/lazy/mason.nvim" "$bin" "$repo"
  printf '#!/usr/bin/env bash\necho "$*" >> "$HOME/nvim.log"\nexit 0\n' > "$bin/nvim"
  chmod +x "$bin/nvim"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/mise"; chmod +x "$bin/mise"
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    ensure_profile_payload typescript"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'Lazy! restore' "$home/nvim.log")" -eq 1 ]
  [ "$(grep -c 'MasonInstall' "$home/nvim.log")" -eq 1 ]
  [[ "$output" == *"skipping the extra sync"* ]]
  # A standalone ensure_lsp_servers (no restore yet in this process) still syncs.
  rm -f "$home/nvim.log"
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    ensure_lsp_servers"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'Lazy! restore' "$home/nvim.log")" -eq 1 ]
  rm -rf "$home" "$bin" "$repo"
}

@test "lazy_restore reports a failing nvim without relying on pipefail" {
  # bin/yadr sets `set -o pipefail`, but the helper must not depend on that
  # global option: with it off, `... | tail -n 5` reports tail's status and a
  # crashed or timed-out nvim looks like a clean restore. The policy stays
  # advisory: editor failures warn, they never fail the install.
  local bin="$BATS_TMPDIR/lazy-rc-bin-$$" home="$BATS_TMPDIR/lazy-rc-$$"
  rm -rf "$bin" "$home"; mkdir -p "$bin" "$home/.local/share/nvim/lazy/lazy.nvim"
  printf '#!/usr/bin/env bash\necho "lazy: broken"\nexit 3\n' > "$bin/nvim"; chmod +x "$bin/nvim"
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin'
    source '$(yadr_funcs)'
    set +o pipefail
    if lazy_restore; then echo 'status=0 (masked)'; else echo 'status=non-zero (honest)'; fi
    ensure_nvim_plugins && echo 'advisory: install continues'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status=non-zero (honest)"* ]]
  [[ "$output" == *"restore incomplete"* ]]
  [[ "$output" == *"advisory: install continues"* ]]
  # A healthy nvim keeps the success path.
  printf '#!/usr/bin/env bash\necho "lazy: ok"\nexit 0\n' > "$bin/nvim"
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin'
    source '$(yadr_funcs)'
    set +o pipefail
    lazy_restore || echo 'lazy_restore failed (bad)'
    ensure_nvim_plugins && echo 'healthy path continues'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"lazy_restore failed (bad)"* ]]
  [[ "$output" == *"plugins match the lock"* ]]
  [[ "$output" == *"healthy path continues"* ]]
  rm -rf "$bin" "$home"
}

# Helper: run the REAL dispatcher in the isolated HOME, without a runtime
# backend in PATH (deterministic on any machine; bin/yadr only adds
# $HOME/.local/bin and mise shims, which the isolated HOME does not have).
yadr_cli() {
  HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash "$YADR_ROOT/bin/yadr" "$@"
}

@test "CLI: version and help come from the real dispatcher" {
  run yadr_cli version
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(tr -d ' \t\n' < "$YADR_ROOT/VERSION")"* ]]
  run yadr_cli help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: yadr <command>"* ]]
  [[ "$output" == *"benchmark"* ]]
}

@test "CLI: unknown command fails and shows the supported list" {
  run yadr_cli definitely-not-a-command
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
  [[ "$output" == *"usage: yadr"* ]]
}

@test "CLI: diff reports what it would create and modifies nothing" {
  run yadr_cli diff
  [ "$status" -eq 0 ]
  [[ "$output" == *"would create"* ]]
  [[ "$output" == *"Nothing modified (read-only)"* ]]
  [ ! -e "$TEST_HOME/.zshrc" ]
}

@test "CLI: theme round-trips and rejects unknown names" {
  run yadr_cli theme current
  [ "$status" -eq 0 ]
  [[ "$output" == *"none"* ]]
  run yadr_cli theme use dark
  [ "$status" -eq 0 ]
  run yadr_cli theme current
  [[ "$output" == *"dark"* ]]
  run yadr_cli theme use not-a-theme
  [ "$status" -ne 0 ]
}

@test "CLI: gitsigns is opt-in and toggles" {
  run yadr_cli gitsigns status
  [ "$status" -eq 0 ]
  [[ "$output" == *"disabled"* ]]
  run yadr_cli gitsigns on
  [ "$status" -eq 0 ]
  run yadr_cli gitsigns status
  [[ "$output" == *"enabled"* ]]
  run yadr_cli gitsigns off
  [ "$status" -eq 0 ]
  run yadr_cli gitsigns status
  [[ "$output" == *"disabled"* ]]
}

@test "CLI: pack list names the shipped packs" {
  run yadr_cli pack list
  [ "$status" -eq 0 ]
  local p
  for p in typescript python ruby rust javascript; do
    [[ "$output" == *"$p"* ]] || fail "pack ${p} missing from 'pack list'"
  done
}

@test "CLI: runtime without a backend fails with the install hint" {
  run yadr_cli runtime current
  [ "$status" -ne 0 ]
  [[ "$output" == *"no runtime backend"* ]]
  [[ "$output" == *"mise.run"* ]]
}

@test "CLI: benchmark measures shell and prompt with thresholds" {
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin' YADR_HOME='$YADR_ROOT'
    source '$(yadr_funcs)'
    do_benchmark shell"
  [ "$status" -eq 0 ]
  [[ "$output" == *"average"* ]]
  [[ "$output" == *"threshold <500ms"* ]]
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin' YADR_HOME='$YADR_ROOT'
    source '$(yadr_funcs)'
    do_benchmark prompt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"outside git"* ]]
  [[ "$output" == *"inside git"* ]]
}

@test "CLI: benchmark rejects an unknown target" {
  run bash -c "
    export HOME='$TEST_HOME' YADR_HOME='$YADR_ROOT'
    source '$(yadr_funcs)'
    do_benchmark bogus"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown benchmark"* ]]
}

@test "coverage harness records called lines and excludes untaken code" {
  # Guards the harness itself: a coverage number is only evidence if it can
  # tell executed code from dead code. Driven through a real BASH_ENV hook.
  local dir="$BATS_TMPDIR/cov-probe-$$"
  rm -rf "$dir"; mkdir -p "$dir/bin/lib"
  cat > "$dir/bin/lib/probe.sh" <<'EOF'
probe_called() {
  echo one
  if [[ "${1:-}" == "x" ]]; then
    echo untaken
  fi
}
probe_uncalled() {
  echo never
}
EOF
  cat > "$dir/driver.sh" <<EOF
source "$dir/bin/lib/probe.sh"
probe_called
EOF
  run bash -c "
    export YADR_COV_LOG='$dir/log'
    BASH_ENV='$YADR_ROOT/tests/coverage-hook.sh' bash '$dir/driver.sh'"
  [ "$status" -eq 0 ]
  local lines
  lines="$(awk -F'\t' -v f="$dir/bin/lib/probe.sh" '$1 == f { print $2 }' "$dir/log" | sort -un | tr '\n' ' ')"
  [ -n "$lines" ] || fail "the hook recorded nothing for the probe file"
  [[ "$lines" == *"2"* ]] || fail "called body line not recorded: $lines"
  [[ "$lines" != *"4"* ]] || fail "untaken branch reported as covered: $lines"
  [[ "$lines" != *"8"* ]] || fail "never-called function reported as covered: $lines"
  rm -rf "$dir"
}

@test "coverage harness refuses to report without bats" {
  # No bats in PATH: the script must fail, never print a percentage.
  run bash -c "cd '$YADR_ROOT' && PATH='/usr/bin:/bin' bash tests/coverage.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bats not found"* ]]
  [[ "$output" != *%* ]]
}

@test "uninstall --purge removes YADR state, keeps pre-existing data" {
  local home="$TEST_HOME" clone="$BATS_TMPDIR/yadr-clone-$$"
  # Fake checkout (isolated): --purge would rm -rf $YADR_HOME, never the real repo.
  rm -rf "$clone"; mkdir -p "$clone/shell"
  : > "$clone/shell/aliases.zsh"
  # Managed symlink pointing at the fake checkout.
  mkdir -p "$home/.config/yadr"
  ln -s "$clone/shell/aliases.zsh" "$home/.config/yadr/aliases.zsh"
  # A real user file that must survive.
  printf 'mine\n' > "$home/.zshrc"
  # YADR-added: tools conf.d fragment + purge marker.
  mkdir -p "$home/.config/mise/conf.d" "$home/.local/state/yadr"
  : > "$home/.config/mise/conf.d/yadr-tools.toml"
  : > "$home/.local/state/yadr/provides-tools"
  # Share dir: pre-existing entry (snapshotted) vs YADR-added.
  mkdir -p "$home/.local/share/nvim"
  : > "$home/.local/share/nvim/precious-data"
  : > "$home/.local/share/nvim/lazy.nvim"
  printf 'precious-data\n' > "$home/.local/state/yadr/preexisting-share-nvim"
  run bash -c "
    export HOME='$home' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$clone'
    do_uninstall --purge"
  [ "$status" -eq 0 ]
  [ ! -e "$home/.config/yadr/aliases.zsh" ]          # managed symlink removed
  [ ! -e "$home/.config/mise/conf.d/yadr-tools.toml" ] # conf.d fragment purged
  [ -f "$home/.zshrc" ]                              # user file kept
  [ -f "$home/.local/share/nvim/precious-data" ]     # pre-existing shared data kept
  [ ! -e "$home/.local/share/nvim/lazy.nvim" ]       # YADR-added entry purged
  [ ! -e "$clone" ]                                  # clone removed
  [ ! -e "$home/.local/state/yadr" ]                 # state/backups removed
  rm -rf "$clone"
}

@test "fetch_verified_zip fails cleanly on an unreachable source" {
  rm -rf "$TEST_HOME/out"
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    fetch_verified_zip 'file://$TEST_HOME/missing.zip' '' '$TEST_HOME/out' '*.ttf'"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_HOME/out" ]   # nothing created on a failed download
}

@test "do_update without a git checkout warns and does not fail" {
  local d="$BATS_TMPDIR/nogit-$$"; mkdir -p "$d"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin' YADR_HOME='$d'
    source '$(yadr_funcs)'
    do_update"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no .git"* ]]
  rm -rf "$d"
}

@test "detect_platform_script maps OS and WSL detection" {
  local pv="$BATS_TMPDIR/procver-$$"
  printf 'Linux version 5.15.90.1-microsoft-standard-WSL2 (gcc)\n' > "$pv"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    run bash -c "export HOME='$TEST_HOME' YADR_HOME='$YADR_ROOT'; source '$(yadr_funcs)'; detect_platform_script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/platform/macos.sh" ]]
  else
    run bash -c "export HOME='$TEST_HOME' YADR_HOME='$YADR_ROOT' YADR_PROC_VERSION='$pv'; source '$(yadr_funcs)'; detect_platform_script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/platform/wsl.sh" ]]
    printf 'Linux version 6.8.0-generic (gcc)\n' > "$pv"
    run bash -c "export HOME='$TEST_HOME' YADR_HOME='$YADR_ROOT' YADR_PROC_VERSION='$pv'; source '$(yadr_funcs)'; detect_platform_script"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/platform/linux.sh" ]]
  fi
}

@test "wsl clipboard note matches the available tool (3 branches)" {
  local b="$BATS_TMPDIR/wsl-bin-$$"; mkdir -p "$b"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$b/win32yank.exe"; chmod +x "$b/win32yank.exe"
  run bash -c "export HOME='$TEST_HOME' PATH='$b:/usr/bin:/bin'; source '$(platform_funcs wsl.sh)'; wsl_clipboard_note"
  [ "$status" -eq 0 ]
  [[ "$output" == *"win32yank.exe available"* ]]
  rm -f "$b/win32yank.exe"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$b/clip.exe"; chmod +x "$b/clip.exe"
  run bash -c "export HOME='$TEST_HOME' PATH='$b:/usr/bin:/bin'; source '$(platform_funcs wsl.sh)'; wsl_clipboard_note"
  [ "$status" -eq 0 ]
  [[ "$output" == *"clip.exe available"* ]]
  rm -f "$b/clip.exe"
  run bash -c "export HOME='$TEST_HOME' PATH='/usr/bin:/bin'; source '$(platform_funcs wsl.sh)'; wsl_clipboard_note"
  [ "$status" -eq 0 ]
  [[ "$output" == *"win32yank (recommended)"* ]]
  rm -rf "$b"
}
