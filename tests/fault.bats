#!/usr/bin/env bats
# fault.bats — injected failures must fail loudly, never lie. Dedicated CI lane
# (job: fault-injection): every scenario breaks something on purpose and asserts
# two things at once — the right part reports the failure, and nothing prints a
# success line for work that did not happen. Policy under test: ADR-004 (runtime
# failures fatal, editor failures advisory, update never destroys anything).
# Requires: bats-core, git (zsh is not needed: SHELL is forced to /bin/zsh so the
# login-shell step short-circuits instead of calling chsh).

setup() {
  export YADR_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export TEST_HOME="$BATS_TMPDIR/yadr-fault-home"
  rm -rf "$TEST_HOME"; mkdir -p "$TEST_HOME"
  # Same hermetic-path rule as shell.bats: lib/paths.sh follows XDG_*/ZDOTDIR.
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
}

load helpers

# --- runtime failures are fatal -------------------------------------------

@test "fault: failed runtime on the full install path applies no success banner" {
  # The full path (links out of date) must report the failure AND still show
  # what it did do: symlinks applied, platform failure advisory-only.
  local home="$TEST_HOME" repo="$BATS_TMPDIR/fault-full-repo-$$" bin="$BATS_TMPDIR/fault-full-bin-$$"
  local plat="$BATS_TMPDIR/fault-full-plat-$$.sh"
  rm -rf "$repo" "$bin"; mkdir -p "$repo"
  printf 'payload\n' > "$repo/pair-src"
  printf '#!/usr/bin/env bash\necho "platform: would install packages (stub)" >&2\nexit 1\n' > "$plat"
  chmod +x "$plat"
  fake_mise "$bin" node >/dev/null
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin' YADR_YES=1 SHELL=/bin/zsh
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.zshrc\"; }
    detect_platform_script() { printf '%s\n' '$plat'; }
    do_install node"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not ensure node"* ]]
  [[ "$output" == *"some runtimes did not install"* ]]
  [[ "$output" != *"YADR 2027 installed"* ]]
  # ...but the rest of the run is reported truthfully.
  [[ "$output" == *"symlinks applied"* ]]
  [[ "$output" == *"platform script errored"* ]]
  [[ "$output" == *"nothing to back up (clean HOME)"* ]]
  [ -L "$home/.zshrc" ]
  [ "$(readlink "$home/.zshrc")" == "$repo/pair-src" ]
  rm -rf "$repo" "$bin" "$plat"
}

@test "fault: fast path names the runtime that failed and still attempts the rest" {
  # Partial failure: node installs, pnpm does not. The success banner must be
  # withheld and only the failing tool named.
  local home="$TEST_HOME" repo="$BATS_TMPDIR/fault-partial-repo-$$" bin="$BATS_TMPDIR/fault-partial-bin-$$"
  rm -rf "$repo" "$bin"; mkdir -p "$repo" "$home/.local/bin"
  printf 'payload\n' > "$repo/pair-src"
  ln -s "$repo/pair-src" "$home/.local/bin/yadr"   # links up to date -> fast path
  fake_mise "$bin" pnpm >/dev/null
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin' YADR_YES=1 SHELL=/bin/zsh
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.local/bin/yadr\"; }
    do_install node"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not ensure pnpm"* ]]
  [[ "$output" != *"could not ensure node"* ]]
  [[ "$output" == *"incomplete"* ]]
  [[ "$output" != *"complete (fast path)"* ]]
  # Both tools were attempted: one failure does not skip the rest.
  grep -q '^install node$' "$home/mise.log"
  grep -q '^install pnpm$' "$home/mise.log"
  rm -rf "$repo" "$bin"
}

@test "fault: a failing mise install never reports the runtime as ready" {
  local bin="$BATS_TMPDIR/fault-rt-bin-$$"
  rm -rf "$bin"; fake_mise "$bin" node >/dev/null
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin'
    source '$(yadr_funcs)'
    cmd_runtime_use node"
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed"* ]]
  [[ "$output" != *"ready (pin honored)"* ]]
  # Same command, working backend: the honest success line is printed.
  fake_mise "$bin" >/dev/null
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin'
    source '$(yadr_funcs)'
    cmd_runtime_use node"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready (pin honored)"* ]]
  rm -rf "$bin"
}

@test "fault: install rejects an unknown profile instead of silently doing nothing" {
  run bash -c "
    export HOME='$TEST_HOME' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$YADR_ROOT'
    do_install imaginary"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown profile: imaginary"* ]]
  [[ "$output" == *"core|node|javascript|typescript"* ]]
  [ ! -e "$TEST_HOME/.local/state/yadr/prev-shell" ]   # died before any side effect
}

# --- editor failures are advisory (the other half of the policy) ----------

@test "fault: a failing editor step stays advisory while a runtime failure does not" {
  # Same injected breakage, two subsystems, two different answers on purpose.
  local home="$TEST_HOME" repo="$BATS_TMPDIR/fault-editor-repo-$$" bin="$BATS_TMPDIR/fault-editor-bin-$$"
  rm -rf "$repo" "$bin"; mkdir -p "$repo" "$home/.local/bin" "$home/.local/share/nvim/lazy/lazy.nvim"
  printf 'payload\n' > "$repo/pair-src"
  ln -s "$repo/pair-src" "$home/.local/bin/yadr"
  fake_mise "$bin" >/dev/null
  printf '#!/usr/bin/env bash\necho "nvim: boom" >&2\nexit 1\n' > "$bin/nvim"; chmod +x "$bin/nvim"
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin' YADR_YES=1 SHELL=/bin/zsh
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    managed_pairs() { printf 'pair-src:%s\n' \"\$HOME/.local/bin/yadr\"; }
    do_install node"
  [ "$status" -eq 0 ]
  [[ "$output" == *"install [node] complete"* ]]
  [[ "$output" == *"restore incomplete"* ]]
  rm -rf "$repo" "$bin"
}

@test "fault: an interrupted plugin clone is cleaned instead of blocking restore" {
  local home="$TEST_HOME" bin="$BATS_TMPDIR/fault-clone-bin-$$"
  rm -rf "$bin"; mkdir -p "$bin" \
    "$home/.local/share/nvim/lazy/lazy.nvim" \
    "$home/.local/share/nvim/lazy/telescope.nvim.cloning"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/nvim"; chmod +x "$bin/nvim"
  run bash -c "
    export HOME='$home' PATH='$bin:/usr/bin:/bin'
    source '$(yadr_funcs)'
    ensure_nvim_plugins"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cleaning interrupted clone: telescope.nvim.cloning"* ]]
  [[ "$output" == *"plugins match the lock"* ]]
  [ ! -e "$home/.local/share/nvim/lazy/telescope.nvim.cloning" ]
  rm -rf "$bin"
}

# --- update: destroy nothing, claim nothing --------------------------------

@test "fault: update never claims 'repo updated' when the pull fails" {
  local repo="$BATS_TMPDIR/fault-update-$$"
  rm -rf "$repo"; mkdir -p "$repo"
  git -C "$repo" init -q 2>/dev/null || true
  printf 'x\n' > "$repo/file"
  git -C "$repo" -c user.email=t@e -c user.name=t add file
  git -C "$repo" -c user.email=t@e -c user.name=t commit -qm init
  git -C "$repo" remote add origin "$BATS_TMPDIR/fault-no-such-remote-$$"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"pull failed"* ]]
  [[ "$output" != *"repo updated"* ]]
  [ -f "$repo/file" ]                       # the checkout is untouched
  [[ "$output" == *"yadr update' again"* ]] # and the way out is spelled out
  rm -rf "$repo"
}

@test "fault: update cancelled by the user changes nothing and exits 0" {
  local repo="$BATS_TMPDIR/fault-cancel-$$"
  rm -rf "$repo"; mkdir -p "$repo/.git"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin'
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_update < /dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"update cancelled"* ]]
  [[ "$output" != *"repo updated"* ]]
  rm -rf "$repo"
}

# --- destructive path: purge refuses to wipe what it cannot classify -------

@test "fault: uninstall --purge refuses a blind wipe when no snapshot exists" {
  local home="$TEST_HOME" clone="$BATS_TMPDIR/fault-purge-clone-$$"
  rm -rf "$clone"; mkdir -p "$clone/shell" "$home/.local/share/nvim"
  : > "$clone/shell/aliases.zsh"
  printf 'user data\n' > "$home/.local/share/nvim/keep-me"   # never snapshotted
  run bash -c "
    export HOME='$home' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$clone'
    do_uninstall --purge"
  [ "$status" -eq 0 ]
  [[ "$output" == *"refusing blind wipe"* ]]
  [ -f "$home/.local/share/nvim/keep-me" ]   # unclassified data survives
  [ ! -e "$clone" ]                          # YADR's own clone still goes
  rm -rf "$clone"
}

# --- install: optional profiles --------------------------------------------

@test "fault: a failing optional profile returns non-zero" {
  local home="$TEST_HOME" repo="$BATS_TMPDIR/fault-prof-repo-$$"
  rm -rf "$repo"; mkdir -p "$repo/platform"
  printf '#!/usr/bin/env bash\necho "lazygit: boom" >&2\nexit 7\n' > "$repo/platform/lazygit.sh"
  printf '#!/usr/bin/env bash\necho "tools: boom" >&2\nexit 9\n' > "$repo/platform/tools.sh"
  chmod +x "$repo/platform/lazygit.sh" "$repo/platform/tools.sh"
  run bash -c "
    export HOME='$home' PATH='/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_install lazygit"
  [ "$status" -eq 7 ]
  [[ "$output" == *"lazygit failed"* ]]
  [[ "$output" != *"lazygit ready"* ]]
  run bash -c "
    export HOME='$home' PATH='/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_install tools"
  [ "$status" -eq 9 ]
  [[ "$output" == *"CLI tools failed"* ]]
  [[ "$output" != *"CLI tools ready"* ]]
  rm -rf "$repo"
}

# --- platform: never delete a directory YADR does not own ------------------

@test "fault: an unowned nvim-upstream is moved aside, not deleted" {
  local home="$BATS_TMPDIR/fault-own-$$" dir="$BATS_TMPDIR/fault-own-$$/.local/nvim-upstream"
  rm -rf "$home"; mkdir -p "$dir"
  printf 'mine\n' > "$dir/keep-me"
  run bash -c "
    export HOME='$home'
    warn() { printf 'WARN: %s\n' \"\$*\"; }
    source '$YADR_ROOT/platform/common.sh'
    claim_owned_dir '$dir' nvim-upstream"
  [ "$status" -eq 0 ]
  [ ! -e "$dir" ]
  find "$home/.local/state/yadr/backups" -name keep-me -type f | grep -q .
  [[ "$output" == *"not installed by YADR"* ]]
  rm -rf "$home"
}

@test "fault: an owned nvim-upstream is replaced" {
  local home="$BATS_TMPDIR/fault-owned-$$" dir="$BATS_TMPDIR/fault-owned-$$/.local/nvim-upstream"
  rm -rf "$home"; mkdir -p "$dir" "$home/.local/state/yadr"
  : > "$home/.local/state/yadr/provides-nvim-upstream"
  printf 'old\n' > "$dir/old"
  run bash -c "
    export HOME='$home'
    warn() { printf 'WARN: %s\n' \"\$*\"; }
    source '$YADR_ROOT/platform/common.sh'
    claim_owned_dir '$dir' nvim-upstream"
  [ "$status" -eq 0 ]
  [ ! -e "$dir" ]
  [ "$(find "$home/.local/state/yadr/backups" -maxdepth 1 -name 'nvim-upstream-*' 2>/dev/null | wc -l)" -eq 0 ]
  rm -rf "$home"
}

# --- update: report both phases, never mix them silently -------------------

@test "fault: update skips runtimes when the pull fails" {
  local repo="$BATS_TMPDIR/fault-upd-skip-$$" bin="$BATS_TMPDIR/fault-upd-skip-bin-$$"
  rm -rf "$repo" "$bin"; mkdir -p "$repo/.git" "$bin"
  cat > "$bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in *pull*) exit 1 ;; *) exit 0 ;; esac
EOF
  cat > "$bin/mise" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/mise.log"
exit 0
EOF
  chmod +x "$bin/git" "$bin/mise"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"pull failed"* ]]
  [[ "$output" == *"runtimes: skipped"* ]]
  [ ! -f "$TEST_HOME/mise.log" ]
  rm -rf "$repo" "$bin"
}

@test "fault: update warns about a dirty checkout and leaves it untouched" {
  local repo="$BATS_TMPDIR/fault-upd-dirty-$$"
  rm -rf "$repo"; mkdir -p "$repo"
  printf 'clean\n' > "$repo/file"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@e -c user.name=t add file
  git -C "$repo" -c user.email=t@e -c user.name=t commit -qm init
  printf 'dirty\n' > "$repo/file"
  run bash -c "
    export HOME='$TEST_HOME' PATH='/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"local modifications"* ]]
  [[ "$output" == *"pull failed"* ]]
  [[ "$output" != *"repo updated"* ]]
  [ "$(cat "$repo/file")" = "dirty" ]   # the working tree is not rewritten
  rm -rf "$repo"
}

@test "fault: uninstall --dry-run changes nothing" {
  local home="$TEST_HOME" clone="$BATS_TMPDIR/fault-uninstall-dry-$$"
  rm -rf "$clone"; mkdir -p "$clone/bin" "$home/.local/bin" "$home/.local/state/yadr"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$clone/bin/yadr"
  printf '0.8.0\n' > "$clone/VERSION"
  ln -s "$clone/bin/yadr" "$home/.local/bin/yadr"
  printf 'mine\n' > "$home/.zshrc"
  run bash -c "
    export HOME='$home' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$clone'
    do_uninstall --dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run: nothing modified"* ]]
  [ -L "$home/.local/bin/yadr" ]
  [ -f "$home/.zshrc" ]
  [ -d "$home/.local/state/yadr" ]
  [ -d "$clone" ]
  rm -rf "$clone"
}

@test "fault: update fails when the runtime phase fails" {
  local repo="$BATS_TMPDIR/fault-upd-rt-$$" bin="$BATS_TMPDIR/fault-upd-rt-bin-$$"
  rm -rf "$repo" "$bin"; mkdir -p "$repo/.git" "$bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/git"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$bin/mise"
  chmod +x "$bin/git" "$bin/mise"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    do_update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"repo updated"* ]]
  [[ "$output" == *"runtime update failed"* ]]
  [[ "$output" != *"runtimes updated"* ]]
  rm -rf "$repo" "$bin"
}

@test "fault: yadr plan is a dry run and exits 0" {
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash "$YADR_ROOT/bin/yadr" plan
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run: nothing modified"* ]]
  [ ! -e "$TEST_HOME/.zshrc" ]
  [ ! -e "$TEST_HOME/.local/state/yadr" ]
}
