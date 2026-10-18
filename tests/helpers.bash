#!/usr/bin/env bash
# helpers.bash — bats helpers shared by every test file (loaded with `load helpers`).
# The loading file must define, in its setup(): YADR_ROOT and TEST_HOME.
# Helpers never touch the real $HOME: TEST_HOME is the isolated one.

fail() { # fail <message>: fail the test with a readable message
  # bats-core has no `fail` helper: calling it is "command not found" (127),
  # which fails the test for the wrong reason and loses the message -- so the
  # message matters. Defined here because every test file loads this file.
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

file_sha() { # file_sha <file>: sha256 hex, coreutils or BSD shasum
  # `cmp` would be nicer but lives in diffutils, which Arch's base does not
  # ship; sha256sum is coreutils (always present) and shasum covers macOS.
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

load_aliases() {
  # Source shell/aliases.zsh with the modern tools hidden from PATH.
  # zsh itself is required (no silent fallback: a missing zsh must fail loudly).
  [ -f "$YADR_ROOT/shell/aliases.zsh" ] || skip "shell/aliases.zsh not in checkout"
  command -v zsh >/dev/null 2>&1 || { echo "zsh required for shell tests" >&2; return 1; }
  PATH="/usr/bin:/bin" HOME="$TEST_HOME" zsh -f -c "source '$YADR_ROOT/shell/aliases.zsh'; echo loaded" 2>/dev/null
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

platform_funcs() {
  # source one platform script's functions without running its main()
  # usage: platform_funcs <script> — echoes the path of a copy with the final
  # `main "$@"` removed. It does NOT resolve PLATFORM_COMMON: a caller that
  # needs common.sh must export PLATFORM_COMMON="$YADR_ROOT/platform/common.sh"
  # itself, otherwise the copy looks for common.sh in $BATS_TMPDIR.
  local script="$1" f="$BATS_TMPDIR/platform-${BATS_TEST_NUMBER:-$PPID}.sh"
  awk '/^main "\$@"$/{exit} {print}' "$YADR_ROOT/platform/${script}" > "$f"
  printf '%s' "$f"
}

yadr_cli() {
  # Run the REAL dispatcher in the isolated HOME, without a runtime backend in
  # PATH (deterministic on any machine: bin/yadr only adds $HOME/.local/bin and
  # mise shims, which the isolated HOME does not have).
  HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash "$YADR_ROOT/bin/yadr" "$@"
}

fake_mise() {
  # fake_mise <dir> [<tool-that-fails>] — stub `mise` that logs every call to
  # $HOME/mise.log and can fail for a single tool. Echoes the stub dir.
  local dir="$1" fail="${2:-}"
  mkdir -p "$dir"
  cat > "$dir/mise" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\$HOME/mise.log"
EOF
  if [ -n "$fail" ]; then
    cat >> "$dir/mise" <<EOF
case "\$*" in
  *${fail}*) echo "mise: refusing ${fail} (stub)" >&2; exit 1 ;;
esac
EOF
  fi
  printf 'exit 0\n' >> "$dir/mise"
  chmod +x "$dir/mise"
  printf '%s' "$dir"
}

fake_path_without() {
  # fake_path_without <dir> <tool-to-hide> — a whitelist PATH with common tools
  # but NOT the named one, for tests that must prove behavior when a tool is
  # missing. Needed because dropping /usr/bin is not an option on Linux (bash
  # and coreutils live there, and Debian ships bats there too, which is how a
  # naive `PATH=/usr/bin:/bin` "hides" nothing at all).
  local dir="$1" hide="$2" t p
  rm -rf "$dir"; mkdir -p "$dir"
  for t in bash sh env printf cat awk sed grep sort uname tr mktemp dirname \
           basename head tail wc rm mkdir date id ln find xargs; do
    [[ "$t" == "$hide" ]] && continue
    p="$(command -v "$t" 2>/dev/null || true)"
    case "$p" in /*) ln -sf "$p" "$dir/$t" ;; esac   # skip builtins ("printf")
  done
  printf '%s' "$dir"
}
