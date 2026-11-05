#!/usr/bin/env bats
# fault.bats — injected failures must fail loudly, never lie. Dedicated CI lane
# (job: fault-injection): every scenario breaks something on purpose and asserts
# two things at once — the right part reports the failure, and nothing prints a
# success line for work that did not happen. Policy under test: ADR-004 (runtime
# failures fatal, editor failures advisory, update never destroys anything).
# Requires: bats-core, git. Bats has no controlling TTY, so the login-shell
# step takes the manual fallback instead of calling chsh.

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
  local backup="$home/.local/state/yadr/backups/20260101-000000"
  rm -rf "$clone"; mkdir -p "$clone/shell" "$home/.local/share/nvim" "$backup"
  : > "$clone/shell/aliases.zsh"
  printf '%s\n' "$backup" > "$home/.local/state/yadr/last-install-backup"
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

@test "fault: uninstall --purge refuses YADR_HOME equal to HOME" {
  local home="$TEST_HOME"
  printf 'keep\n' > "$home/keep-me"
  run bash -c "
    export HOME='$home' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$home'
    do_uninstall --purge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsafe YADR_HOME"* ]]
  [ -f "$home/keep-me" ]
}

@test "fault: uninstall --purge refuses without an install backup" {
  local home="$TEST_HOME" clone="$BATS_TMPDIR/fault-legacy-purge-$$"
  local state backup
  state="$home/.local/state/yadr"
  backup="$state/backups/20260101-000000"
  rm -rf "$clone"; mkdir -p "$clone/shell" "$backup"
  : > "$clone/shell/aliases.zsh"
  mkdir -p "$home/.config/yadr"
  ln -s "$clone/shell/aliases.zsh" "$home/.config/yadr/aliases.zsh"
  printf 'legacy-original\n' > "$backup/aliases.zsh"
  printf '%s\n' "$backup" > "$state/last-backup"
  run bash -c "
    export HOME='$home' YADR_YES=1
    source '$(yadr_funcs)'
    export YADR_HOME='$clone'
    do_uninstall --purge"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing --purge: no valid last-install-backup"* ]]
  [ -L "$home/.config/yadr/aliases.zsh" ]    # nothing was removed
  [ -d "$clone" ]                            # checkout preserved
  [ -f "$backup/aliases.zsh" ]               # legacy backup preserved
  [ "$(cat "$backup/aliases.zsh")" = "legacy-original" ]
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

# --- platform: neovim replacement is staged and rollback-safe ---------------

@test "fault: failed neovim staging keeps the previous installation intact" {
  local home="$BATS_TMPDIR/fault-nvim-stage-$$"
  local fb="$BATS_TMPDIR/fault-nvim-stage-fb-$$" src="$BATS_TMPDIR/fault-nvim-stage-src-$$"
  local payload="$BATS_TMPDIR/fault-nvim-stage-payload-$$"
  rm -rf "$home" "$fb" "$src" "$payload"
  mkdir -p "$fb" "$src/nvim-linux-x86_64/bin" "$home/.local/nvim-upstream/bin" \
    "$home/.local/bin" "$home/.local/state/yadr"
  printf '#!/bin/sh\necho "NVIM v0.11.0"\n' > "$home/.local/nvim-upstream/bin/nvim"
  chmod +x "$home/.local/nvim-upstream/bin/nvim"
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
  : > "$home/.local/state/yadr/provides-nvim-upstream"
  ln -s "$home/.local/nvim-upstream/bin/nvim" "$home/.local/bin/nvim"
  run bash -c "
    export HOME='$home' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    cp() { return 1; }
    ensure_nvim"
  [ "$status" -ne 0 ]
  [[ "$output" == *"staging copy failed"* ]]
  [ -f "$home/.local/nvim-upstream/bin/nvim" ]
  [ "$(cat "$home/.local/nvim-upstream/bin/nvim")" = '#!/bin/sh
echo "NVIM v0.11.0"' ]
  [ -L "$home/.local/bin/nvim" ]
  [ "$(readlink "$home/.local/bin/nvim")" = "$home/.local/nvim-upstream/bin/nvim" ]
  [ -f "$home/.local/state/yadr/provides-nvim-upstream" ]
  [ -z "$(find "$home/.local" -maxdepth 1 -name 'nvim-upstream.new.*' -o -name 'nvim-upstream.old.*' 2>/dev/null)" ]
  rm -rf "$home" "$fb" "$src" "$payload"
}

@test "fault: nvim that fails its final smoke check restores the previous install" {
  local home="$BATS_TMPDIR/fault-nvim-final-$$"
  local fb="$BATS_TMPDIR/fault-nvim-final-fb-$$" src="$BATS_TMPDIR/fault-nvim-final-src-$$"
  local payload="$BATS_TMPDIR/fault-nvim-final-payload-$$" calls="$BATS_TMPDIR/fault-nvim-final-calls-$$"
  rm -rf "$home" "$fb" "$src" "$payload" "$calls"
  mkdir -p "$fb" "$src/nvim-linux-x86_64/bin"
  cat > "$src/nvim-linux-x86_64/bin/nvim" <<EOF
#!/bin/sh
n=0
[ -f "$calls" ] && n=\$(cat "$calls")
n=\$((n + 1))
printf '%s\n' "\$n" > "$calls"
if [ "\$n" -lt 3 ]; then echo "NVIM v0.12.6"; exit 0; fi
echo "nvim: boom" >&2
exit 1
EOF
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
    export HOME='$home' PATH='$fb:/usr/bin:/bin'
    export FAKE_PAYLOAD='$payload' PLATFORM_COMMON='$YADR_ROOT/platform/common.sh'
    source '$(platform_funcs linux.sh)' >/dev/null 2>&1
    verify_sha256() { return 0; }
    ensure_nvim"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start"* ]]
  [[ "$output" != *"neovim ready"* ]]
  [ ! -e "$home/.local/nvim-upstream" ]
  [ ! -e "$home/.local/bin/nvim" ]
  [ ! -f "$home/.local/state/yadr/provides-nvim-upstream" ]
  [ -z "$(find "$home/.local" -maxdepth 1 -name 'nvim-upstream.new.*' -o -name 'nvim-upstream.old.*' 2>/dev/null)" ]
  rm -rf "$home" "$fb" "$src" "$payload" "$calls"
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

@test "fault: unowned directories get distinct backup directories" {
  local home="$BATS_TMPDIR/fault-own2-$$"
  local d1="$home/a/nvim-upstream" d2="$home/b/nvim-upstream"
  rm -rf "$home"; mkdir -p "$d1" "$d2"
  printf 'one\n' > "$d1/keep-me"
  printf 'two\n' > "$d2/keep-me"
  run bash -c "
    export HOME='$home'
    warn() { printf 'WARN: %s\n' \"\$*\"; }
    date() { printf '20260101-000000'; }
    source '$YADR_ROOT/platform/common.sh'
    claim_owned_dir '$d1' nvim-upstream
    claim_owned_dir '$d2' nvim-upstream"
  [ "$status" -eq 0 ]
  [ ! -e "$d1" ] && [ ! -e "$d2" ]
  [ "$(find "$home/.local/state/yadr/backups" -name keep-me -type f | wc -l)" -eq 2 ]
  [ "$(find "$home/.local/state/yadr/backups" -maxdepth 1 -type d -name 'nvim-upstream-*' | wc -l)" -eq 2 ]
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

@test "fault: a failed binary link restores the foreign file and writes no marker" {
  local home="$BATS_TMPDIR/fault-bin-link-$$" target source
  target="$home/.local/bin/tool"; source="$home/source-tool"
  rm -rf "$home"; mkdir -p "$(dirname "$target")"
  printf 'user file\n' > "$target"
  printf '#!/bin/sh\n' > "$source"; chmod +x "$source"
  run bash -c "
    export HOME='$home'
    warn() { printf 'WARN: %s\n' \"\$*\"; }
    source '$YADR_ROOT/platform/common.sh'
    ln() { return 1; }
    claim_owned_binary '$target' '$source' tool link"
  [ "$status" -ne 0 ]
  [ -f "$target" ] && [ ! -L "$target" ]
  [ "$(cat "$target")" = "user file" ]
  [ ! -f "$home/.local/state/yadr/provides-tool" ]
  [ -z "$(find "$home/.local/state/yadr-binary-backups" -type f -o -type l 2>/dev/null)" ]
  rm -rf "$home"
}

@test "fault: a failed binary copy restores the foreign file and leaves no temp file" {
  local home="$BATS_TMPDIR/fault-bin-copy-$$" target source
  target="$home/.local/bin/tool"; source="$home/source-tool"
  rm -rf "$home"; mkdir -p "$(dirname "$target")"
  printf 'user file\n' > "$target"
  printf '#!/bin/sh\n' > "$source"; chmod +x "$source"
  run bash -c "
    export HOME='$home'
    warn() { printf 'WARN: %s\n' \"\$*\"; }
    source '$YADR_ROOT/platform/common.sh'
    cp() { return 1; }
    claim_owned_binary '$target' '$source' tool copy"
  [ "$status" -ne 0 ]
  [ -f "$target" ] && [ ! -L "$target" ]
  [ "$(cat "$target")" = "user file" ]
  [ ! -f "$home/.local/state/yadr/provides-tool" ]
  ! find "$home/.local/bin" -maxdepth 1 -name '*.yadr-new.*' | grep -q .
  [ -z "$(find "$home/.local/state/yadr-binary-backups" -type f -o -type l 2>/dev/null)" ]
  rm -rf "$home"
}

@test "fault: purge removes a managed binary but preserves its binary backup" {
  local home="$TEST_HOME" clone="$BATS_TMPDIR/fault-bin-purge-$$"
  local state="$home/.local/state/yadr" backup="$home/.local/state/yadr-binary-backups/nvim-20260101-000000.abcd"
  rm -rf "$clone"; mkdir -p "$clone/bin" "$clone/shell" "$state/backups/20260101-000000" \
    "$home/.local/bin" "$backup"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$clone/bin/yadr"
  printf '0.9.8\n' > "$clone/VERSION"
  ln -s "$clone/bin/yadr" "$home/.local/bin/yadr"
  ln -s /bin/true "$home/.local/bin/nvim"
  : > "$state/provides-nvim-upstream"
  printf 'old nvim\n' > "$backup/nvim"
  printf '%s\n' "$state/backups/20260101-000000" > "$state/last-install-backup"
  run bash -c "
    export HOME='$home' YADR_YES=1 SHELL=/bin/bash
    source '$(yadr_funcs)'
    export YADR_HOME='$clone'
    do_uninstall --purge"
  [ "$status" -eq 0 ]
  [ ! -e "$home/.local/bin/nvim" ]
  [ ! -e "$home/.local/bin/yadr" ]
  [ -f "$backup/nvim" ]
  [ "$(cat "$backup/nvim")" = "old nvim" ]
  [ ! -e "$clone" ]
  [ ! -e "$state" ]
  rm -rf "$clone"
}



@test "update asks before mise: Enter accepts, n and EOF skip" {
  local repo="$BATS_TMPDIR/fault-upd-prompt-$$" bin="$BATS_TMPDIR/fault-upd-prompt-bin-$$"
  rm -rf "$repo" "$bin"; mkdir -p "$repo/.git" "$bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/git"
  cat > "$bin/mise" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/mise.log"
exit 0
EOF
  chmod +x "$bin/git" "$bin/mise"

  # Explicit no: repo updates, runtimes do not run.
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin'
    unset YADR_YES
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    printf 'y\nn\n' | do_update"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Update runtimes (mise)? [Y/n]"* ]]
  [[ "$output" == *"runtimes: skipped."* ]]
  [ ! -f "$TEST_HOME/mise.log" ]

  # Empty line: default yes.
  rm -f "$TEST_HOME/mise.log"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin'
    unset YADR_YES
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    printf 'y\n\n' | do_update"
  [ "$status" -eq 0 ]
  [[ "$output" == *"runtimes updated."* ]]
  grep -qE '^(upgrade|up)$' "$TEST_HOME/mise.log"

  # EOF at the runtime prompt: no, without hanging.
  rm -f "$TEST_HOME/mise.log"
  run bash -c "
    export HOME='$TEST_HOME' PATH='$bin:/usr/bin:/bin'
    unset YADR_YES
    source '$(yadr_funcs)'
    export YADR_HOME='$repo'
    printf 'y\n' | do_update"
  [ "$status" -eq 0 ]
  [[ "$output" == *"runtimes: skipped."* ]]
  [ ! -f "$TEST_HOME/mise.log" ]

  rm -rf "$repo" "$bin"
}

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
