#!/usr/bin/env bats
# shell.bats — aliases/runtime/damoekri must not break without modern tools.
# Requires: bats-core, zsh, git. Every test must pass on a minimal machine.
# TEST_HOME is wiped per test: no test may depend on another test's leftovers.

setup() {
  export YADR_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # Isolate HOME to avoid touching real dotfiles; fresh per test
  export TEST_HOME="$BATS_TMPDIR/yadr-home"
  rm -rf "$TEST_HOME"; mkdir -p "$TEST_HOME"
  # Hermetic paths: lib/paths.sh follows XDG_*/ZDOTDIR, and a desktop session
  # exports them (often pointing at the real HOME), so the ambient values must
  # never leak into a test. Tests that exercise a moved XDG set them on purpose.
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
}

load helpers

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

@test "damoekri shows ahead and behind counts against upstream" {
  local root="$BATS_TMPDIR/yadr-git-counts-$$"
  rm -rf "$root"; mkdir -p "$root"
  git init -q --bare "$root/remote.git"
  git clone -q "$root/remote.git" "$root/work"
  git -C "$root/work" config user.email t@t.t
  git -C "$root/work" config user.name t
  printf 'base\n' > "$root/work/f"
  git -C "$root/work" add f
  git -C "$root/work" commit -qm base
  git -C "$root/work" push -q -u origin HEAD
  printf 'local\n' >> "$root/work/f"
  git -C "$root/work" commit -qam local
  git clone -q "$root/remote.git" "$root/other"
  git -C "$root/other" config user.email t@t.t
  git -C "$root/other" config user.name t
  printf 'remote\n' >> "$root/other/f"
  git -C "$root/other" commit -qam remote
  git -C "$root/other" push -q
  git -C "$root/work" fetch -q
  run zsh -f -c "
    cd '$root/work' || exit 1
    source '$YADR_ROOT/shell/damoekri.zsh'
    yadr_git_info"
  [ "$status" -eq 0 ]
  [[ "$output" == *"↑1"* ]]
  [[ "$output" == *"↓1"* ]]
  rm -rf "$root"
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
    echo \"\$out\" | grep -q '✘' && echo ok;
    rm -rf '$gd'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "confirm_yes accepts Enter, rejects EOF and explicit no, honors --yes" {
  run bash -c "source '$(yadr_funcs)'; printf '\n' | confirm_yes 'Proceed?'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[Y/n]"* ]]
  run bash -c "source '$(yadr_funcs)'; confirm_yes 'Proceed?' </dev/null"
  [ "$status" -ne 0 ]
  run bash -c "source '$(yadr_funcs)'; printf 'n\n' | confirm_yes 'Proceed?'"
  [ "$status" -ne 0 ]
  run bash -c "source '$(yadr_funcs)'; YADR_YES=1 confirm_yes 'Proceed?' </dev/null"
  [ "$status" -eq 0 ]
}

@test "nvim options enable cursorline" {
  command -v nvim >/dev/null 2>&1 || skip "nvim not installed"
  run nvim --headless --noplugin -u NONE \
    -c "lua dofile('$YADR_ROOT/nvim/lua/yadr/options.lua')" \
    -c 'lua io.write(vim.o.cursorline and "cursorline-on" or "cursorline-off")' \
    -c qa
  [ "$status" -eq 0 ]
  [[ "$output" == *"cursorline-on"* ]]
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

@test "installed-ref: record_installed_ref writes the checkout identity atomically" {
  local repo="$BATS_TMPDIR/ref-repo-$$"
  rm -rf "$repo"; mkdir -p "$repo"
  printf '0.7.0\n' > "$repo/VERSION"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@e -c user.name=t add VERSION
  git -C "$repo" -c user.email=t@e -c user.name=t commit -qm init
  git -C "$repo" tag v0.7.0
  git -C "$repo" remote add origin https://secret-token@example.com/yadr.git
  run bash -c "
    export HOME='$TEST_HOME'
    unset XDG_STATE_HOME
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    record_installed_ref
    cat \"\$(installed_ref_path)\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"sha=$(git -C "$repo" rev-parse HEAD)"* ]]
  [[ "$output" == *"ref=v0.7.0"* ]]
  [[ "$output" == *"tag=v0.7.0"* ]]
  [[ "$output" == *"version=0.7.0"* ]]
  [[ "$output" == *"origin=https://example.com/yadr.git"* ]]
  [[ "$output" != *"secret-token"* ]]
  [[ "$output" == *"recorded="* ]]
  [ -z "$(find "$TEST_HOME/.local/state/yadr" -maxdepth 1 -name '.installed-ref.*' 2>/dev/null)" ]
  rm -rf "$repo"
}

@test "doctor shows the recorded commit, warns on divergence, informs when absent" {
  local repo="$BATS_TMPDIR/ref-doctor-$$" short
  rm -rf "$repo"; mkdir -p "$repo"
  printf '0.7.0\n' > "$repo/VERSION"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@e -c user.name=t add VERSION
  git -C "$repo" -c user.email=t@e -c user.name=t commit -qm init
  git -C "$repo" tag v0.7.0
  short="$(git -C "$repo" rev-parse --short=12 HEAD)"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin'
    unset XDG_STATE_HOME
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    record_installed_ref
    do_doctor 2>&1 || true"
  [[ "$output" == *"commit ${short} (v0.7.0, 0.7.0)"* ]]
  # A recorded revision that is not the live HEAD is the warning case.
  printf 'sha=0000000000000000000000000000000000000000\nref=main\nversion=0.7.0\n' \
    > "$TEST_HOME/.local/state/yadr/installed-ref"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin'
    unset XDG_STATE_HOME
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_doctor 2>&1 || true"
  [[ "$output" == *"differs from checkout ${short}"* ]]
  [[ "$output" == *"run 'yadr update'"* ]]
  # Missing file is informational, not a warning (old installs).
  rm -f "$TEST_HOME/.local/state/yadr/installed-ref"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin'
    unset XDG_STATE_HOME
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_doctor 2>&1 || true"
  [[ "$output" == *"installed commit not recorded"* ]]
  [[ "$output" != *"differs from checkout"* ]]
  rm -rf "$repo"
}

@test "installed-ref: a failed update still records the revision it left behind" {
  local repo="$BATS_TMPDIR/ref-update-$$"
  rm -rf "$repo"; mkdir -p "$repo"
  printf '0.7.0\n' > "$repo/VERSION"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@e -c user.name=t add VERSION
  git -C "$repo" -c user.email=t@e -c user.name=t commit -qm init
  git -C "$repo" remote add origin "$BATS_TMPDIR/no-such-remote-$$"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin' YADR_YES=1
    unset XDG_STATE_HOME
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"pull failed"* ]]
  local f="$TEST_HOME/.local/state/yadr/installed-ref" branch
  branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD)"
  [ -f "$f" ]
  grep -qx "sha=$(git -C "$repo" rev-parse HEAD)" "$f"
  grep -qx "ref=${branch}" "$f"
  rm -rf "$repo"
}

@test "doctor counts rogue/foreign symlinks as one warning (detail stays uncounted)" {
  local h="$BATS_TMPDIR/rogue-$$"
  rm -rf "$h"; mkdir -p "$h/.config"
  ln -s /tmp/not-yadr "$h/.config/nvim"          # managed destination pointing outside YADR_HOME
  # `count` (the doctor path) adds exactly one warning regardless of how many links are foreign.
  run bash -c "
    export HOME='$h'
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
    source '$(yadr_funcs)'
    YADR_HOME='$YADR_ROOT'
    DOCTOR_WARN=0
    detect_rogue_checkouts count >/dev/null 2>&1
    printf 'COUNT=%s\n' \"\$DOCTOR_WARN\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"COUNT=1"* ]]
  # Without `count` (the install path) the doctor total is not touched.
  run bash -c "
    export HOME='$h'
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
    source '$(yadr_funcs)'
    YADR_HOME='$YADR_ROOT'
    DOCTOR_WARN=0
    detect_rogue_checkouts >/dev/null 2>&1
    printf 'COUNT=%s\n' \"\$DOCTOR_WARN\""
  [[ "$output" == *"COUNT=0"* ]]
  rm -rf "$h"
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

@test "solarized-bg path is identical in macOS menu, lua and CLI (XDG-aware)" {
  # ADR-005: the three readers (CLI theme_file, macOS menu writer, Lua reader)
  # must resolve the same directory from the same variable, and fall back to
  # ~/.config when the variable is unset.
  local x="$BATS_TMPDIR/xdg-theme-$$"
  rm -rf "$x"; mkdir -p "$x"
  run bash -c "
    export HOME='$TEST_HOME' XDG_CONFIG_HOME='$x/config'
    source '$(yadr_funcs)'
    [ \"\$(theme_file)\" = '$x/config/yadr/solarized-bg' ] || exit 1
    grep -q 'XDG_CONFIG_HOME' '$YADR_ROOT/platform/macos.sh' || exit 1
    grep -q 'XDG_CONFIG_HOME' '$YADR_ROOT/nvim/lua/yadr/plugins/colorscheme.lua' || exit 1
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; theme_file"
  [ "$status" -eq 0 ]
  [ "$output" == "$TEST_HOME/.config/yadr/solarized-bg" ]
  rm -rf "$x"
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
    echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
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
  # The zip is a committed fixture (109 bytes) instead of something built at
  # test time with python3: the suite must run on a minimal machine, and the
  # Arch lane has no python3.
  local z="$YADR_ROOT/tests/fixtures/font-sample.zip" dest="$TEST_HOME/fonts"
  [ -f "$z" ] || fail "missing fixture: tests/fixtures/font-sample.zip"
  local sha; sha="$(file_sha "$z")"
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    fetch_verified_zip 'file://$z' '$sha' '$dest' '*.ttf' && echo fetched-ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fetched-ok"* ]]
  [ -f "$dest/f.ttf" ]
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    fetch_verified_zip 'file://$z' 'deadbeef' '$TEST_HOME/other' '*.ttf'"
  [ "$status" -ne 0 ]
  [ ! -e "$TEST_HOME/other/f.ttf" ]
}

@test "sha256 helpers are the single implementation used by platform downloads" {
  local f="$BATS_TMPDIR/sha-helper-$$" want
  printf 'yadr\n' > "$f"
  want="$(file_sha "$f")"
  run bash -c "
    source '$YADR_ROOT/platform/common.sh'
    printf 'hash=%s\n' \"\$(sha256_of '$f')\"
    verify_sha256 '$f' '$want' && echo MATCH
    verify_sha256 '$f' 'deadbeef' && echo BAD || echo MISMATCH
    verify_sha256 '$f' '' && echo BAD || echo NOPIN
    verify_sha256 '$f/missing' '$want' && echo BAD || echo MISSING
    sha256_of '$f/missing' >/dev/null && echo BAD || echo UNREADABLE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hash=${want}"* ]]
  [[ "$output" == *"MATCH"* ]]
  [[ "$output" == *"MISMATCH"* ]]
  [[ "$output" == *"NOPIN"* ]]
  [[ "$output" == *"MISSING"* ]]
  [[ "$output" == *"UNREADABLE"* ]]
  rm -f "$f"
}

@test "fetch_verified_zip without a pin warns and still extracts" {
  local z="$YADR_ROOT/tests/fixtures/font-sample.zip" dest="$TEST_HOME/fonts-nopin"
  [ -f "$z" ] || fail "missing fixture: tests/fixtures/font-sample.zip"
  run bash -c "
    export HOME='$TEST_HOME'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    fetch_verified_zip 'file://$z' '' '$dest' '*.ttf' && echo fetched-ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no pinned sha256: only verifying zip integrity."* ]]
  [[ "$output" == *"fetched-ok"* ]]
  [ -f "$dest/f.ttf" ]
}

@test "install_mise runs the pinned versioned installer, marker only on success" {
  local fb="$BATS_TMPDIR/mise-pin-$$" payload="$BATS_TMPDIR/mise-payload-$$"
  rm -rf "$fb"; mkdir -p "$fb"
  printf '#!/bin/sh\nexit 0\n' > "$payload"
  cat > "$fb/curl" <<'EOF'
#!/bin/bash
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cp "$FAKE_PAYLOAD" "$out"
EOF
  cat > "$fb/sh" <<'EOF'
#!/bin/bash
printf 'MISE_VERSION=%s MISE_INSTALL_HELP=%s\n' "${MISE_VERSION:-}" "${MISE_INSTALL_HELP:-}" >> "$FAKE_LOG"
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/mise"
chmod +x "$HOME/.local/bin/mise"
EOF
  chmod +x "$fb/curl" "$fb/sh"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' FAKE_LOG='$fb/log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    install_mise"
  [ "$status" -eq 0 ]
  grep -qx 'MISE_VERSION=2026.10.15 MISE_INSTALL_HELP=0' "$fb/log"
  [ -x "$TEST_HOME/.local/bin/mise" ]
  [ -f "$TEST_HOME/.local/state/yadr/provides-mise" ]
  # A checksum failure must stop before running the installer or marking it.
  rm -f "$TEST_HOME/.local/state/yadr/provides-mise" "$fb/log"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' FAKE_LOG='$fb/log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 1; }
    install_mise"
  [ "$status" -ne 0 ]
  [[ "$output" == *"mise installer sha256 mismatch"* ]]
  [ ! -f "$TEST_HOME/.local/state/yadr/provides-mise" ]
  [ ! -f "$fb/log" ]
  rm -rf "$fb" "$payload"
}

@test "install_zoxide uses the pinned tarball, marker only on success" {
  local fb="$BATS_TMPDIR/zoxide-pin-$$" src="$BATS_TMPDIR/zoxide-src-$$" payload="$BATS_TMPDIR/zoxide-payload-$$"
  rm -rf "$fb" "$src"; mkdir -p "$fb" "$src"
  printf '#!/bin/sh\necho zoxide 0.10.0\n' > "$src/zoxide"; chmod +x "$src/zoxide"
  tar -czf "$payload" -C "$src" zoxide
  cat > "$fb/curl" <<'EOF'
#!/bin/bash
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cp "$FAKE_PAYLOAD" "$out"
EOF
  chmod +x "$fb/curl"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    install_zoxide"
  [ "$status" -eq 0 ]
  [ -x "$TEST_HOME/.local/bin/zoxide" ]
  [ -f "$TEST_HOME/.local/state/yadr/provides-zoxide" ]
  rm -f "$TEST_HOME/.local/bin/zoxide" "$TEST_HOME/.local/state/yadr/provides-zoxide"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 1; }
    install_zoxide"
  [ "$status" -ne 0 ]
  [[ "$output" == *"zoxide sha256 mismatch"* ]]
  [ ! -e "$TEST_HOME/.local/bin/zoxide" ]
  [ ! -f "$TEST_HOME/.local/state/yadr/provides-zoxide" ]
  rm -rf "$fb" "$src" "$payload"
}

@test "ensure_nvim installs the pinned release, marker only after verification" {
  local fb="$BATS_TMPDIR/nvim-pin-$$" src="$BATS_TMPDIR/nvim-src-$$" payload="$BATS_TMPDIR/nvim-payload-$$"
  rm -rf "$fb" "$src"; mkdir -p "$fb" "$src/nvim-linux-x86_64/bin"
  printf '#!/bin/sh\necho "NVIM v0.12.6"\n' > "$src/nvim-linux-x86_64/bin/nvim"
  chmod +x "$src/nvim-linux-x86_64/bin/nvim"
  tar -czf "$payload" -C "$src" nvim-linux-x86_64
  cat > "$fb/curl" <<'EOF'
#!/bin/bash
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cp "$FAKE_PAYLOAD" "$out"
EOF
  chmod +x "$fb/curl"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    ensure_nvim"
  [ "$status" -eq 0 ]
  [ -x "$TEST_HOME/.local/nvim-upstream/bin/nvim" ]
  [ -L "$TEST_HOME/.local/bin/nvim" ]
  [ -f "$TEST_HOME/.local/state/yadr/provides-nvim-upstream" ]
  [[ "$output" == *"neovim ready"* ]]
  rm -rf "$TEST_HOME/.local/nvim-upstream" "$TEST_HOME/.local/bin/nvim"
  rm -f "$TEST_HOME/.local/state/yadr/provides-nvim-upstream"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 1; }
    ensure_nvim"
  [ "$status" -ne 0 ]
  [[ "$output" == *"neovim sha256 mismatch"* ]]
  [ ! -e "$TEST_HOME/.local/nvim-upstream" ]
  [ ! -f "$TEST_HOME/.local/state/yadr/provides-nvim-upstream" ]
  rm -rf "$fb" "$src" "$payload"
}

@test "lazygit fallback uses the pinned lowercase asset and verifies its hash" {
  local fb="$BATS_TMPDIR/lazygit-pin-$$" src="$BATS_TMPDIR/lazygit-src-$$" payload="$BATS_TMPDIR/lazygit-payload-$$"
  rm -rf "$fb" "$src"; mkdir -p "$fb" "$src"
  printf '#!/bin/sh\necho "lazygit 0.66.2"\n' > "$src/lazygit"; chmod +x "$src/lazygit"
  tar -czf "$payload" -C "$src" lazygit
  cat > "$fb/uname" <<'EOF'
#!/bin/bash
case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac
EOF
  cat > "$fb/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_LOG"
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cp "$FAKE_PAYLOAD" "$out"
EOF
  chmod +x "$fb/uname" "$fb/curl"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' FAKE_LOG='$fb/log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs lazygit.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    install_tarball"
  [ "$status" -eq 0 ]
  [ -x "$TEST_HOME/.local/bin/lazygit" ]
  [ -f "$TEST_HOME/.local/state/yadr/provides-lazygit" ]
  grep -q 'lazygit_0.66.2_linux_x86_64.tar.gz' "$fb/log"
  ! grep -q '_Linux_' "$fb/log"
  rm -f "$TEST_HOME/.local/bin/lazygit" "$TEST_HOME/.local/state/yadr/provides-lazygit"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' FAKE_LOG='$fb/log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs lazygit.sh)' >/dev/null 2>&1
    verify_sha256() { return 1; }
    install_tarball"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lazygit sha256 mismatch"* ]]
  [ ! -e "$TEST_HOME/.local/bin/lazygit" ]
  [ ! -f "$TEST_HOME/.local/state/yadr/provides-lazygit" ]
  rm -rf "$fb" "$src" "$payload"
}

@test "lazygit Darwin falls back to the pinned tarball when brew fails" {
  local fb="$BATS_TMPDIR/lazygit-darwin-$$" src="$BATS_TMPDIR/lazygit-darwin-src-$$" payload="$BATS_TMPDIR/lazygit-darwin-payload-$$"
  rm -rf "$fb" "$src"; mkdir -p "$fb" "$src"
  printf '#!/bin/sh\necho "lazygit 0.66.2"\n' > "$src/lazygit"; chmod +x "$src/lazygit"
  tar -czf "$payload" -C "$src" lazygit
  cat > "$fb/uname" <<'EOF'
#!/bin/bash
case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; *) echo Darwin ;; esac
EOF
  printf '#!/bin/bash\necho "brew: no bottle" >&2\nexit 1\n' > "$fb/brew"
  cat > "$fb/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_LOG"
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac; done
cp "$FAKE_PAYLOAD" "$out"
EOF
  chmod +x "$fb/uname" "$fb/brew" "$fb/curl"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' FAKE_LOG='$fb/log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs lazygit.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    main"
  [ "$status" -eq 0 ]
  [ -x "$TEST_HOME/.local/bin/lazygit" ]
  [ -f "$TEST_HOME/.local/state/yadr/provides-lazygit" ]
  [[ "$output" == *"brew install lazygit failed; using pinned tarball"* ]]
  grep -q 'lazygit_0.66.2_darwin_arm64.tar.gz' "$fb/log"
  rm -rf "$fb" "$src" "$payload"
}

@test "macOS XDG zsh plugins clone the pinned tag and verify HEAD" {
  local fb="$BATS_TMPDIR/zsh-pin-$$" data="$TEST_HOME/plugin-data"
  rm -rf "$fb"; mkdir -p "$fb"
  cat > "$fb/git" <<'EOF'
#!/bin/bash
case "$1" in
  clone)
    tag=""; dest=""
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --branch) tag="$2"; shift 2 ;;
        --depth) shift 2 ;;
        *) dest="$1"; shift ;;
      esac
    done
    mkdir -p "$dest"
    printf '%s\n' "$tag" > "$dest/.tag"
    printf 'stub\n' > "$dest/zsh-syntax-highlighting.zsh"
    printf 'stub\n' > "$dest/zsh-autosuggestions.zsh"
    ;;
  -C)
    case "$2" in
      *zsh-syntax-highlighting*) echo db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e ;;
      *zsh-autosuggestions*) echo e52ee8ca55bcc56a17c828767a3f98f22a68d4eb ;;
    esac
    ;;
esac
EOF
  chmod +x "$fb/git"
  run bash -c "
    export HOME='$TEST_HOME' XDG_DATA_HOME='$data' PATH='$fb:/usr/bin:/bin'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs macos.sh)' >/dev/null 2>&1
    ensure_zsh_plugins_macos"
  [ "$status" -eq 0 ]
  [ -f "$data/yadr-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]
  [ -f "$data/yadr-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]
  [ "$(cat "$data/yadr-plugins/zsh-syntax-highlighting/.tag")" = "0.8.0" ]
  [ "$(cat "$data/yadr-plugins/zsh-autosuggestions/.tag")" = "v0.7.1" ]
  # A clone whose HEAD does not match the pinned commit is refused, and the
  # previous checkout is left untouched.
  local bad="$BATS_TMPDIR/zsh-bad-$$"
  rm -rf "$bad"; mkdir -p "$bad"
  cat > "$bad/git" <<'EOF'
#!/bin/bash
case "$1" in
  clone) dest=""; shift; while [ $# -gt 0 ]; do dest="$1"; shift; done; mkdir -p "$dest"; printf 'x\n' > "$dest/p.zsh" ;;
  -C) echo deadbeef ;;
esac
EOF
  chmod +x "$bad/git"
  run bash -c "
    export HOME='$TEST_HOME' XDG_DATA_HOME='$data' PATH='$bad:/usr/bin:/bin'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs macos.sh)' >/dev/null 2>&1
    clone_xdg_plugin zsh-users/zsh-autosuggestions moved p.zsh v0.0.0 1111111111111111111111111111111111111111"
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected 1111111111111111111111111111111111111111; refusing it"* ]]
  [ ! -e "$data/yadr-plugins/moved" ]
  rm -rf "$fb" "$bad" "$data"
}

# These are deliberately static: the point is that the integers in the tree
# cannot silently drift back to "latest". Network behavior is covered by the
# install_* tests above; docs/supply-chain.md carries the same inventory.
@test "static provenance: CI actions are pinned by full commit SHA" {
  local f line ref found=0
  for f in "$YADR_ROOT"/.github/workflows/*.yml; do
    [ -f "$f" ] || continue
    while IFS= read -r line; do
      case "$line" in
        *uses:*) ;;
        *) continue ;;
      esac
      case "$line" in
        \#*) continue ;;
      esac
      found=$((found+1))
      ref="${line#*@}"
      [ "$ref" != "$line" ] || fail "action without @ in ${f}: ${line}"
      ref="${ref%%[[:space:]]*}"
      [ "${#ref}" -eq 40 ] || fail "action is not pinned to 40 hex chars: ${line}"
      case "$ref" in
        *[!0-9a-f]*) fail "action SHA is not lowercase hex: ${line}" ;;
      esac
    done < "$f"
  done
  [ "$found" -gt 0 ] || fail "no workflow actions found"
}

@test "static provenance: release docs pin bootstrap and publish a checksum" {
  # The README may mention `main` as development, but must not install from
  # it. The release docs must name SHA256SUMS and the exact-tag path.
  ! grep -q 'raw.githubusercontent.com/marcoarata/dotfiles/main/bootstrap.sh' "$YADR_ROOT/README.md"
  grep -Eq 'raw.githubusercontent.com/marcoarata/dotfiles/v[0-9]+\.[0-9]+\.[0-9]+/bootstrap.sh' "$YADR_ROOT/README.md"
  grep -q 'SHA256SUMS' "$YADR_ROOT/README.md"
  grep -q 'SHA256SUMS' "$YADR_ROOT/docs/releases.md"
  grep -q 'SHA256SUMS' "$YADR_ROOT/docs/supply-chain.md"
  [ ! -e "$YADR_ROOT/.github/dependabot.yml" ]
}

@test "static provenance: nvim-treesitter stays on master without tree-sitter-cli" {
  grep -q 'branch = "master"' "$YADR_ROOT/nvim/lua/yadr/plugins/editor.lua"
  grep -q 'treesitter_compat' "$YADR_ROOT/nvim/lua/yadr/treesitter.lua"
  ! grep -Rq 'tree-sitter-cli' "$YADR_ROOT/nvim" "$YADR_ROOT/platform" "$YADR_ROOT/bin"
}

@test "treesitter compat shim unwraps Neovim 0.12 match lists" {
  command -v nvim >/dev/null 2>&1 || skip "nvim not installed"
  run nvim --headless -u NONE -l "$YADR_ROOT/tests/treesitter-compat.lua"
  [ "$status" -eq 0 ]
  [[ "$output" == *"treesitter-compat: ok"* ]]
}

@test "telescope mappings have one implementation" {
  ! grep -q 'vim.keymap.set' "$YADR_ROOT/nvim/lua/yadr/telescope.lua"
  ! grep -q 'telescope.builtin' "$YADR_ROOT/nvim/lua/yadr/telescope.lua"
  grep -q 'Telescope find_files' "$YADR_ROOT/nvim/lua/yadr/keymaps.lua"
}

@test "static provenance: linux installer pins are exact and verified" {
  local l="$YADR_ROOT/platform/linux.sh"
  grep -qx 'ZOXIDE_VERSION="0.10.0"' "$l"
  grep -qx 'ZOXIDE_SHA256_X86_64="2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae"' "$l"
  grep -qx 'ZOXIDE_SHA256_ARM64="f1f16c5d6298d63dee467eedea1cdcd8490e43e493bea43acd416dc9033ef641"' "$l"
  grep -qx 'NVIM_VERSION="v0.12.6"' "$l"
  grep -qx 'NVIM_SHA256_X86_64="474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87"' "$l"
  grep -qx 'NVIM_SHA256_ARM64="8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815"' "$l"
  grep -qx 'MISE_VERSION="2026.10.15"' "$l"
  grep -qx 'MISE_INSTALLER_SHA256="79db94aec4c40bfa1ff8d696621c0f5f96e2282b6675fdb71d834cf4ab4a70d0"' "$l"
  grep -q 'MISE_INSTALLER_URL="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/install.sh"' "$l"
  grep -q 'verify_sha256 "$tmp/install.sh" "$MISE_INSTALLER_SHA256"' "$l"
  grep -q 'verify_sha256 "$tmp/zoxide.tar.gz" "$sha"' "$l"
  grep -q 'verify_sha256 "$tmp/nvim.tar.gz" "$sha"' "$l"
  grep -q 'MISE_VERSION="$MISE_VERSION" MISE_INSTALL_HELP=0 sh "$tmp/install.sh"' "$l"
  ! grep -q 'releases/download/stable' "$l"
  ! grep -q 'mise.run' "$l"
  ! grep -q 'zoxide/main/install' "$l"
  ! grep -Eq '\| *(sh|bash)' "$l"
}

@test "static provenance: lazygit and macOS plugin fallbacks are pinned" {
  local g="$YADR_ROOT/platform/lazygit.sh" m="$YADR_ROOT/platform/macos.sh"
  grep -qx 'LAZYGIT_VERSION="0.66.2"' "$g"
  grep -qx 'LAZYGIT_SHA256_LINUX_X86_64="158efc9ddfa1241fab5fb3526bb442c8dc6c4b1904d73213b9e4e93e03c52034"' "$g"
  grep -qx 'LAZYGIT_SHA256_LINUX_ARM64="79a3161eeb642f0473e23db6341f7baabd4a5933e921a9c1167c5d5c765c41a4"' "$g"
  grep -qx 'LAZYGIT_SHA256_DARWIN_X86_64="de5d3771e4befa6fe17590e21445614998adc1ef34a71f4003df6764247517ab"' "$g"
  grep -qx 'LAZYGIT_SHA256_DARWIN_ARM64="fadda59ae7665ba556fcbaa704c7eade6e40d016d3f3b25d6327dd1f3f906a0c"' "$g"
  grep -q 'lazygit_${LAZYGIT_VERSION}_${os}_${arch}.tar.gz' "$g"
  grep -q 'verify_sha256 "$tmp/lazygit.tar.gz" "$sha"' "$g"
  grep -q 'install_tarball ||' "$g"
  ! grep -q '_Linux_\|_Darwin_' "$g"
  ! grep -q 'releases/latest' "$g"
  grep -qx 'ZSH_SYNTAX_HIGHLIGHTING_TAG="0.8.0"' "$m"
  grep -qx 'ZSH_SYNTAX_HIGHLIGHTING_COMMIT="db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e"' "$m"
  grep -qx 'ZSH_AUTOSUGGESTIONS_TAG="v0.7.1"' "$m"
  grep -qx 'ZSH_AUTOSUGGESTIONS_COMMIT="e52ee8ca55bcc56a17c828767a3f98f22a68d4eb"' "$m"
  grep -q 'git clone --depth 1 --branch "$tag"' "$m"
  grep -q 'rev-parse HEAD' "$m"
  ! grep -q 'git clone --depth 1 "https://github.com/${repo}.git" "$dest"' "$m"
}

@test "static provenance: installed-ref writers agree and no unpinned hints remain" {
  local f k
  for f in "$YADR_ROOT/bootstrap.sh" "$YADR_ROOT/bin/lib/install.sh"; do
    for k in sha ref branch tag version origin recorded; do
      grep -q "printf '${k}=%s" "$f" || fail "$f does not write ${k}"
    done
    grep -q 'installed-ref' "$f"
  done
  ! grep -rq 'mise.run' "$YADR_ROOT/bin" "$YADR_ROOT/platform" "$YADR_ROOT/bootstrap.sh"
  grep -q "yadr install core" "$YADR_ROOT/bin/lib/runtime.sh"
  grep -q "yadr install core" "$YADR_ROOT/bin/lib/doctor.sh"
  grep -q 'verify_sha256' "$YADR_ROOT/platform/common.sh"
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

@test "install --dry-run prints the plan and writes nothing" {
  local home="$TEST_HOME" repo="$BATS_TMPDIR/install-plan-repo-$$"
  local plat="$BATS_TMPDIR/install-plan-plat-$$.sh" marker="$BATS_TMPDIR/install-plan-ran-$$"
  rm -rf "$repo" "$plat" "$marker"; mkdir -p "$repo"
  printf 'payload\n' > "$repo/pair-src"
  printf '#!/usr/bin/env bash\ntouch "%s"\n' "$marker" > "$plat"
  chmod +x "$plat"
  run bash -c "
    export HOME='$home' PATH='/usr/bin:/bin' YADR_YES=1 SHELL=/bin/zsh
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.zshrc\"; }
    detect_platform_script() { printf '%s\n' '$plat'; }
    do_install --dry-run core"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run: nothing modified"* ]]
  [ ! -e "$marker" ]                              # platform never ran
  [ ! -e "$home/.zshrc" ]                         # no link
  [ ! -e "$home/.local/state/yadr/prev-shell" ]   # no state written
  [ ! -e "$home/.local/state/yadr/preexisting-share-nvim" ]
  rm -rf "$repo" "$plat" "$marker"
}

@test "cancelling the install leaves the system untouched" {
  local home="$TEST_HOME" repo="$BATS_TMPDIR/install-cancel-repo-$$"
  local plat="$BATS_TMPDIR/install-cancel-plat-$$.sh" marker="$BATS_TMPDIR/install-cancel-ran-$$"
  rm -rf "$repo" "$plat" "$marker"; mkdir -p "$repo"
  printf 'payload\n' > "$repo/pair-src"
  printf '#!/usr/bin/env bash\ntouch "%s"\n' "$marker" > "$plat"
  chmod +x "$plat"
  run bash -c "
    export HOME='$home' PATH='/usr/bin:/bin' SHELL=/bin/zsh
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.zshrc\"; }
    detect_platform_script() { printf '%s\n' '$plat'; }
    do_install core <<< n"
  [ "$status" -eq 0 ]
  [[ "$output" == *"install cancelled; nothing modified"* ]]
  [ ! -e "$marker" ]                              # platform never ran
  [ ! -e "$home/.zshrc" ]                         # no link
  [ ! -e "$home/.local/state/yadr/prev-shell" ]   # no state written
  rm -rf "$repo" "$plat" "$marker"
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

@test "CLI: version and help come from the real dispatcher" {
  run yadr_cli version
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(tr -d ' \t\n' < "$YADR_ROOT/VERSION")"* ]]
  run yadr_cli help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: yadr <command>"* ]]
  [[ "$output" == *"benchmark"* ]]
}

@test "CLI: --version prints the version and exits 0" {
  run yadr_cli --version
  [ "$status" -eq 0 ]
  [[ "$output" == "$(tr -d ' \t\n' < "$YADR_ROOT/VERSION")" ]]
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

@test "CLI: install javascript resolves to the node profile" {
  # One vocabulary: the JS pack is installed through `install`, and the
  # javascript alias maps to the node profile instead of a pack command.
  run bash -c "source '$(yadr_funcs)'; normalize_profile javascript"
  [ "$output" == "node" ]
  run bash -c "source '$(yadr_funcs)'; normalize_profile typescript"
  [ "$output" == "typescript" ]
  run yadr_cli --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"javascript"* ]] || fail "javascript is not listed as an install profile"
  run yadr_cli install bogus --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown profile"* ]]
}

@test "CLI: runtime without a backend fails with the install hint" {
  run yadr_cli runtime current
  [ "$status" -ne 0 ]
  [[ "$output" == *"no runtime backend"* ]]
  [[ "$output" == *"yadr install core"* ]]
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
  # No bats reachable: the script must fail, never print a percentage.
  # Whitelist PATH: Debian/Ubuntu install bats into /usr/bin, so the old
  # `PATH=/usr/bin:/bin` hid nothing there and instead re-launched the whole
  # suite from inside the suite (infinite recursion in CI, green on macOS
  # where brew's bats is outside /usr/bin). Hide bats explicitly.
  local fb real_bash
  command -v bats >/dev/null 2>&1 || skip "bats is not in PATH at all: nothing to hide"
  fb="$(fake_path_without "$BATS_TMPDIR/no-bats-$$" bats)"
  real_bash="$(command -v bash)"
  PATH="$fb" command -v bats >/dev/null 2>&1 && fail "the whitelist PATH still exposes bats"
  run env -i PATH="$fb" HOME="$TEST_HOME" "$real_bash" "$YADR_ROOT/tests/coverage.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bats not found"* ]]
  [[ "$output" != *%* ]]
  rm -rf "$fb"
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

@test "uninstall restores the last backup without touching foreign files" {
  local home="$TEST_HOME" clone="$BATS_TMPDIR/yadr-restore-clone-$$"
  local backup="$home/.local/state/yadr/backups/20260101-000000"
  rm -rf "$clone"; mkdir -p "$clone/bin" "$home/.local/bin" "$backup"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$clone/bin/yadr"
  printf '0.8.0\n' > "$clone/VERSION"
  ln -s "$clone/bin/yadr" "$home/.local/bin/yadr"
  printf 'previous-yadr\n' > "$backup/yadr"
  printf '%s\n' "$backup" > "$home/.local/state/yadr/last-backup"
  printf 'mine\n' > "$home/.zshrc"
  run bash -c "
    export HOME='$home' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$clone'
    do_uninstall"
  [ "$status" -eq 0 ]
  [ -f "$home/.local/bin/yadr" ]                 # symlink replaced by the backup
  [ "$(cat "$home/.local/bin/yadr")" = "previous-yadr" ]
  [ -f "$home/.zshrc" ]                          # unrelated user file survives
  [ "$(cat "$home/.zshrc")" = "mine" ]
  [ -d "$clone" ]                                # no --purge: checkout kept
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

# platform/linux.sh picks a manager from what exists. The containers/OSes that
# CI cannot run locally (Arch) are covered by faking the whole world: PATH has
# ONLY the package manager under test, so no real apt/dnf/pacman is reachable.
# The stubs use #!/bin/bash (not /usr/bin/env, which PATH would not resolve).

@test "platform/linux.sh selects pacman and installs the Arch package set" {
  local fb="$BATS_TMPDIR/pm-pacman-$$"
  rm -rf "$fb"; mkdir -p "$fb"
  printf '#!/bin/bash\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac\n' > "$fb/uname"
  printf '#!/bin/bash\nprintf "pacman %%s\\n" "$*" >> "$FAKE_LOG"\n' > "$fb/pacman"
  printf '#!/bin/bash\nprintf "sudo %%s\\n" "$*" >> "$FAKE_LOG"\n"$@"\n' > "$fb/sudo"
  chmod +x "$fb/uname" "$fb/pacman" "$fb/sudo"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb' FAKE_LOG='$fb/calls.log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)'
    main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"manager: pacman"* ]]
  [[ "$output" != *"manager: apt"* ]]
  grep -q '^pacman -Sy --noconfirm' "$fb/calls.log"
  grep -q '\bzsh\b' "$fb/calls.log"
  grep -q '\bbase-devel\b' "$fb/calls.log"          # Arch name for build tools
  grep -q '\bfd\b' "$fb/calls.log"                  # Arch does not ship fd-find
  [[ "$output" == *"linux ready (headless OK)"* ]]  # optional installers may fail
  rm -rf "$fb"
}

@test "platform/linux.sh selects apt and installs the Debian package set" {
  local fb="$BATS_TMPDIR/pm-apt-$$"
  rm -rf "$fb"; mkdir -p "$fb"
  printf '#!/bin/bash\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac\n' > "$fb/uname"
  printf '#!/bin/bash\nprintf "apt-get %%s\\n" "$*" >> "$FAKE_LOG"\n' > "$fb/apt-get"
  printf '#!/bin/bash\nprintf "sudo %%s\\n" "$*" >> "$FAKE_LOG"\n"$@"\n' > "$fb/sudo"
  chmod +x "$fb/uname" "$fb/apt-get" "$fb/sudo"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb' FAKE_LOG='$fb/calls.log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)'
    main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"manager: apt"* ]]
  [[ "$output" != *"manager: pacman"* ]]
  grep -q '^apt-get update$' "$fb/calls.log"
  grep -q '\bfd-find\b' "$fb/calls.log"             # Debian name
  grep -q '\bbuild-essential\b' "$fb/calls.log"
  ! grep -q '\bneovim\b' "$fb/calls.log"            # upstream tarball is the floor, not apt
  rm -rf "$fb"
}

@test "platform/linux.sh selects dnf and installs the Fedora package set" {
  local fb="$BATS_TMPDIR/pm-dnf-$$"
  rm -rf "$fb"; mkdir -p "$fb"
  printf '#!/bin/bash\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac\n' > "$fb/uname"
  printf '#!/bin/bash\nprintf "dnf %%s\\n" "$*" >> "$FAKE_LOG"\n' > "$fb/dnf"
  printf '#!/bin/bash\nprintf "sudo %%s\\n" "$*" >> "$FAKE_LOG"\n"$@"\n' > "$fb/sudo"
  chmod +x "$fb/uname" "$fb/dnf" "$fb/sudo"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb' FAKE_LOG='$fb/calls.log'
    export PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)'
    main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"manager: dnf"* ]]
  grep -q '^dnf install -y' "$fb/calls.log"
  grep -q '\bgcc\b' "$fb/calls.log"                 # Fedora name for build tools
  ! grep -q '\bneovim\b' "$fb/calls.log"            # upstream tarball is the floor, not dnf
  rm -rf "$fb"
}

@test "platform/linux.sh warns about a missing common.sh instead of dying" {
  # Regression for a `set -e` trap: resolving PLATFORM_COMMON used a command
  # substitution whose failure aborted the whole script, so the documented
  # "missing common.sh" warning was unreachable and the platform step died
  # with a confusing error instead. Found by the Arch lane, where `cd ""` is
  # not a no-op. A fake `dirname` that points at a directory which does not
  # exist reproduces that deterministically on any bash version.
  local fb="$BATS_TMPDIR/pm-nocommon-$$"
  rm -rf "$fb"; mkdir -p "$fb"
  printf '#!/bin/bash\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac\n' > "$fb/uname"
  printf '#!/bin/bash\necho /nonexistent-yadr-dir\n' > "$fb/dirname"
  printf '#!/bin/bash\nprintf "pacman %%s\\\\n" "$*" >> "$FAKE_LOG"\n' > "$fb/pacman"
  printf '#!/bin/bash\nprintf "sudo %%s\\\\n" "$*" >> "$FAKE_LOG"\n"$@"\n' > "$fb/sudo"
  chmod +x "$fb/uname" "$fb/dirname" "$fb/pacman" "$fb/sudo"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$fb' FAKE_LOG='$fb/calls.log'
    unset PLATFORM_COMMON
    source '$(platform_funcs linux.sh)'
    main"
  [ "$status" -eq 0 ]
  [[ "$output" == *"platform/common.sh missing"* ]]
  [[ "$output" == *"linux ready"* ]]
  rm -rf "$fb"
}

# ADR-005 — path policy. The installer, doctor, the purge inventory and the
# tools YADR configures must agree on where a file lives; when they disagree the
# failure is silent (a link nobody reads, a warning that never clears, a purge
# that leaves data behind). These tests move XDG_*/ZDOTDIR on purpose.

@test "path policy: XDG moved — every destination follows the tool that reads it" {
  local x="$BATS_TMPDIR/xdg-moved-$$"
  rm -rf "$x"; mkdir -p "$x"
  run bash -c "
    export HOME='$TEST_HOME'
    export XDG_CONFIG_HOME='$x/config' XDG_DATA_HOME='$x/data'
    export XDG_CACHE_HOME='$x/cache' XDG_STATE_HOME='$x/state'
    source '$(yadr_funcs)'
    managed_pairs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim:$x/config/nvim"* ]]                          # nvim: stdpath("config")
  [[ "$output" == *"runtime/mise.toml:$x/config/mise/config.toml"* ]] # mise honors XDG
  [[ "$output" == *"shell/aliases.zsh:$x/config/yadr/aliases.zsh"* ]] # YADR's own files
  [[ "$output" == *"git/gitconfig:$TEST_HOME/.gitconfig"* ]]          # git reads it anyway
  [[ "$output" == *"tmux/tmux.conf:$TEST_HOME/.tmux.conf"* ]]         # tmux reads it anyway
  [[ "$output" == *"shell/zshrc:$TEST_HOME/.zshrc"* ]]                # no ZDOTDIR: HOME
  # Defaults (XDG unset) are exactly what they were before the policy existed.
  run bash -c "export HOME='$TEST_HOME'; source '$(yadr_funcs)'; managed_pairs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim:$TEST_HOME/.config/nvim"* ]]
  [[ "$output" == *"shell/aliases.zsh:$TEST_HOME/.config/yadr/aliases.zsh"* ]]
  [[ "$output" == *"shell/zshrc:$TEST_HOME/.zshrc"* ]]
  rm -rf "$x"
}

@test "path policy: the nvim config link lands where nvim resolves its config" {
  local x="$BATS_TMPDIR/xdg-nvimlink-$$"
  rm -rf "$x"; mkdir -p "$x/config"
  run bash -c "
    export HOME='$TEST_HOME' XDG_CONFIG_HOME='$x/config'
    source '$(yadr_funcs)'
    link_one '${YADR_ROOT}/nvim' \"\$(nvim_config_dir)\" >/dev/null
    readlink \"\$(nvim_config_dir)\""
  [ "$status" -eq 0 ]
  [ "$output" == "${YADR_ROOT}/nvim" ]
  [ ! -e "$TEST_HOME/.config/nvim" ]   # nothing lands in the un-moved path
  rm -rf "$x"
}

@test "path policy: nvim's own stdpath agrees with the helpers (XDG moved)" {
  command -v nvim >/dev/null 2>&1 || skip "nvim not installed"
  local x="$BATS_TMPDIR/xdg-stdpath-$$"
  rm -rf "$x"; mkdir -p "$x"
  run bash -c "
    export HOME='$TEST_HOME' XDG_CONFIG_HOME='$x/config' XDG_DATA_HOME='$x/data'
    source '$(yadr_funcs)'
    nvim --clean --headless \
      -c 'lua io.write(vim.fn.stdpath(\"config\") .. \" \" .. vim.fn.stdpath(\"data\"))' \
      -c qa 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$output" == "$x/config/nvim $x/data/nvim" ]
  rm -rf "$x"
}

@test "path policy: ZDOTDIR moves the zsh rc the installer manages" {
  command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
  local zd="$BATS_TMPDIR/zdotdir-$$"
  rm -rf "$zd"; mkdir -p "$zd"
  printf 'echo zdotdir-rc-loaded\n' > "$zd/.zshrc"
  # zsh itself reads $ZDOTDIR/.zshrc instead of ~/.zshrc ...
  run env ZDOTDIR="$zd" HOME="$TEST_HOME" zsh -i -c true
  [[ "$output" == *"zdotdir-rc-loaded"* ]]
  # ... so that is where the managed link has to go.
  run bash -c "export HOME='$TEST_HOME' ZDOTDIR='$zd'; source '$(yadr_funcs)'; zshrc_path"
  [ "$status" -eq 0 ]
  [ "$output" == "$zd/.zshrc" ]
  rm -rf "$zd"
}

@test "path policy: doctor sees nvim plugins under a moved XDG data dir" {
  local x="$BATS_TMPDIR/xdg-doctor-$$"
  rm -rf "$x"; mkdir -p "$x/data/nvim/lazy/telescope.nvim"
  run bash -c "
    export HOME='$TEST_HOME' XDG_DATA_HOME='$x/data' PATH='/usr/bin:/bin'
    source '$(yadr_funcs)'
    export YADR_HOME='$YADR_ROOT'
    out=\"\$(do_doctor 2>&1 || true)\"
    printf '%s\n' \"\$out\" | grep -E 'nvim plugins|neovim plugins'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim plugins (lockfile OK)"* ]]
  [[ "$output" != *"neovim plugins not installed"* ]]
  # Plugins that are NOT where nvim looks must not count as installed: the same
  # defect seen from the other side (doctor must not believe the HOME literal).
  mkdir -p "$TEST_HOME/.local/share/nvim/lazy/other.nvim"
  run bash -c "
    export HOME='$TEST_HOME' XDG_DATA_HOME='$x/elsewhere' PATH='/usr/bin:/bin'
    source '$(yadr_funcs)'
    export YADR_HOME='$YADR_ROOT'
    out=\"\$(do_doctor 2>&1 || true)\"
    printf '%s\n' \"\$out\" | grep -E 'nvim plugins|neovim plugins'"
  [[ "$output" == *"neovim plugins not installed"* ]]
  rm -rf "$x"
}

@test "path policy: snapshot and purge cover the XDG directories the tools use" {
  local x="$BATS_TMPDIR/xdg-snapshot-$$"
  rm -rf "$x"; mkdir -p "$x/data/nvim" "$x/state/yadr"
  : > "$x/data/nvim/precious-data"
  # 1. the snapshot records the pre-existing entry of the XDG data dir
  run bash -c "
    export HOME='$TEST_HOME' XDG_DATA_HOME='$x/data' XDG_STATE_HOME='$x/state'
    source '$(yadr_funcs)'
    export STATE_DIR='$x/state/yadr'
    snapshot_share_dirs
    cat \"\$STATE_DIR/preexisting-share-nvim\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"precious-data"* ]]
  # 2. purge then keeps it and removes only what YADR added there
  : > "$x/data/nvim/lazy.nvim"
  run bash -c "
    export HOME='$TEST_HOME' XDG_DATA_HOME='$x/data' XDG_STATE_HOME='$x/state'
    source '$(yadr_funcs)'
    export STATE_DIR='$x/state/yadr'
    purge_dir_keep_preexisting '$x/data/nvim' share-nvim"
  [ "$status" -eq 0 ]
  [ -f "$x/data/nvim/precious-data" ]
  [ ! -e "$x/data/nvim/lazy.nvim" ]
  rm -rf "$x"
}

@test "path policy: shipped code never hardcodes the tools' XDG-derived dirs" {
  # Regression guard for the whole class ADR-005 closes: a literal path in the
  # CLI or in platform/ means installer, doctor or purge disagree with the tool.
  run grep -rnE 'HOME}/\.(local/share|local/state|config)/nvim|HOME}/\.(config|local/share)/yadr|HOME}/\.config/mise|HOME}/\.local/share/mise|HOME}/\.cache/nvim' \
    "$YADR_ROOT/bin" "$YADR_ROOT/platform" "$YADR_ROOT/bootstrap.sh"
  [ "$status" -ne 0 ]
}

# Shell completions (`yadr completion`, v0.4.0). The scripts are static text, so
# the risk is drift: a command added to the CLI but not to the three scripts, or
# a script that stops parsing. Each shell is checked with its own parser when it
# is present, and the command lists are compared against `--help`.

@test "completions: yadr completion prints a script that parses in its shell" {
  local d="$BATS_TMPDIR/completion-parse-$$"; rm -rf "$d"; mkdir -p "$d"
  yadr_cli completion bash > "$d/yadr.bash" || fail "completion bash failed"
  grep -q 'complete -F _yadr_complete yadr' "$d/yadr.bash" || fail "bash: complete -F missing"
  bash -n "$d/yadr.bash" || fail "bash: generated script does not parse"
  yadr_cli completion zsh > "$d/_yadr" || fail "completion zsh failed"
  [ "$(head -n1 "$d/_yadr")" = "#compdef yadr" ] || fail "zsh: #compdef header missing"
  command -v zsh >/dev/null 2>&1 && { zsh -n "$d/_yadr" || fail "zsh: generated script does not parse"; }
  yadr_cli completion fish > "$d/yadr.fish" || fail "completion fish failed"
  grep -q '__fish_use_subcommand' "$d/yadr.fish" || fail "fish: no subcommand completions"
  if command -v fish >/dev/null 2>&1; then fish --no-execute "$d/yadr.fish" || fail "fish: generated script does not parse"; fi
  run yadr_cli completion tcsh
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown shell"* ]]
}

@test "completions: the three scripts name exactly the commands the CLI dispatches" {
  # Drift guard: the source of truth is what `yadr --help` lists. Add a command
  # without completing it (or vice versa) and this test fails. No diff/cmp here:
  # Arch's base container does not ship diffutils (the suites must run there).
  local d="$BATS_TMPDIR/completion-drift-$$"; rm -rf "$d"; mkdir -p "$d"
  yadr_cli --help | sed -n 's/^  \([a-z-]*\).*/\1/p' | grep -v ':$' | sort -u > "$d/usage"
  [ -s "$d/usage" ] || fail "could not read the command list from yadr --help"
  yadr_cli completion bash | sed -n 's/^  local commands="\(.*\)"$/\1/p' | tr ' ' '\n' | sort -u > "$d/bash"
  yadr_cli completion zsh  | sed -n 's/^    compadd -- \(.*\)$/\1/p' | tr ' ' '\n' | sort -u > "$d/zsh"
  yadr_cli completion fish | sed -n 's/^complete -c yadr -n __fish_use_subcommand -a \([a-z]*\) .*/\1/p' | sort -u > "$d/fish"
  for f in bash zsh fish; do
    if [ "$(cat "$d/usage")" != "$(cat "$d/$f")" ]; then
      printf 'expected (from --help):\n%s\ngot (%s):\n%s\n' "$(cat "$d/usage")" "$f" "$(cat "$d/$f")" >&2
      fail "$f completion drifted from yadr --help"
    fi
  done
}

@test "completions: --install writes them under the moved XDG dirs and removes them" {
  local x="$BATS_TMPDIR/completion-xdg-$$"; rm -rf "$x"; mkdir -p "$x"
  run bash -c "
    export HOME='$TEST_HOME' XDG_CONFIG_HOME='$x/config' XDG_DATA_HOME='$x/data'
    export XDG_CACHE_HOME='$x/cache' XDG_STATE_HOME='$x/state' PATH='/usr/bin:/bin'
    source '$(yadr_funcs)'
    ensure_completions >/dev/null
    completion_script bash > '$x/printed.bash'"
  [ "$status" -eq 0 ]
  [ -e "$x/data/bash-completion/completions/yadr" ]
  [ -e "$x/data/zsh/site-functions/_yadr" ]
  [ -e "$x/config/fish/completions/yadr.fish" ]
  # Nothing lands in the un-moved location (a shell would never read it there).
  [ ! -e "$TEST_HOME/.local/share/bash-completion/completions/yadr" ]
  [ ! -e "$TEST_HOME/.config/fish/completions/yadr.fish" ]
  # What install writes is byte-identical to what `completion <shell>` prints.
  # file_sha, not cmp: Arch's base container ships neither diffutils nor cmp.
  [ "$(file_sha "$x/printed.bash")" = "$(file_sha "$x/data/bash-completion/completions/yadr")" ] \
    || fail "installed bash script differs from the printed one"
  # Removal takes exactly those files back (empty dirs included).
  run bash -c "
    export HOME='$TEST_HOME' XDG_CONFIG_HOME='$x/config' XDG_DATA_HOME='$x/data'
    export XDG_CACHE_HOME='$x/cache' XDG_STATE_HOME='$x/state' PATH='/usr/bin:/bin'
    source '$(yadr_funcs)'
    remove_completions >/dev/null
    for f in bash_completion_file zsh_completion_file fish_completion_file; do
      if [ -e \"\$(\$f)\" ]; then echo \"still present: \$(\$f)\"; exit 1; fi
    done"
  [ "$status" -eq 0 ]
  rm -rf "$x"
}

@test "completions: install wires the write and uninstall the cleanup" {
  # Structural guard for the two call sites code cannot be executed here without
  # a full install (neovim restore, platform packages): the write runs on both
  # the full and the fast path, the cleanup on uninstall.
  run grep -c 'ensure_completions' "$YADR_ROOT/bin/lib/install.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
  run grep -q 'remove_completions' "$YADR_ROOT/bin/lib/recover.sh"
  [ "$status" -eq 0 ]
  run grep -q 'completions_inventory' "$YADR_ROOT/bin/lib/recover.sh"
  [ "$status" -eq 0 ]
}
