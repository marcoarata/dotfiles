#!/usr/bin/env bats
# bootstrap.bats — the installer entrypoint: flags, release pinning, handoff.
#
# bootstrap.sh is run for real (never sourced): clone + tag checkout + VERSION
# verification against a throwaway git repo in $BATS_TMPDIR, and the handoff to
# `bin/yadr install` is observed through a stub binary, so nothing is installed.
# Requires: bats-core, git.

setup() {
  export YADR_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export TEST_HOME="$BATS_TMPDIR/yadr-bootstrap-home"
  rm -rf "$TEST_HOME"; mkdir -p "$TEST_HOME"
  # Same hermetic-path rule as shell.bats: lib/paths.sh follows XDG_*/ZDOTDIR.
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
}

load helpers

make_fixture_repo() {
  # make_fixture_repo <dir> <version>: throwaway project repo tagged v<version>
  # whose bin/yadr prints a marker instead of installing anything.
  local dir="$1" ver="$2"
  rm -rf "$dir"; mkdir -p "$dir/bin"
  printf '%s\n' "$ver" > "$dir/VERSION"
  cat > "$dir/bin/yadr" <<'EOF'
#!/usr/bin/env bash
here="$(cd "$(dirname "$0")/.." && pwd)"
printf 'stub: install %s (VERSION %s)\n' "$*" "$(tr -d ' \t\n' < "${here}/VERSION")"
exit 0
EOF
  chmod +x "$dir/bin/yadr"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@e -c user.name=t add -A
  git -C "$dir" -c user.email=t@e -c user.name=t commit -qm "release ${ver}"
  git -C "$dir" tag "v${ver}"
  printf '%s' "$dir"
}

@test "bootstrap piped from stdin defaults to ~/.yadr-2027 without unset errors" {
  # The documented install is `curl ... | bash -s -- ...`: BASH_SOURCE is unset
  # there, and with `set -u` the first line used to print an unbound-variable
  # error before doing anything else.
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash -s -- --local < "$YADR_ROOT/bootstrap.sh"
  [ "$status" -ne 0 ]                                     # no checkout yet: dies
  [[ "$output" == *"home=${TEST_HOME}/.yadr-2027"* ]]
  [[ "$output" == *"bin/yadr missing"* ]]
  [[ "$output" != *"BASH_SOURCE"* ]]
  [[ "$output" != *"unbound"* ]]
}

@test "bootstrap piped from stdin pins and hands off like the file form" {
  local checkout="$BATS_TMPDIR/bs-stdin-$$"
  make_fixture_repo "$checkout" 1.2.3 >/dev/null
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" YADR_HOME="$checkout" \
    bash -s -- --local --ref v1.2.3 < "$YADR_ROOT/bootstrap.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pinned ref v1.2.3 verified"* ]]
  [[ "$output" == *"stub: install"* ]]
  rm -rf "$checkout"
}

@test "bootstrap --help documents --local and --ref" {
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash "$YADR_ROOT/bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--ref <tag>"* ]]
  [[ "$output" == *"--local"* ]]
}

@test "bootstrap --ref clones the tag and verifies VERSION before installing" {
  local repo home
  repo="$BATS_TMPDIR/bs-fixture-$$"
  home="$TEST_HOME/.yadr-2027"
  make_fixture_repo "$repo" 1.2.3 >/dev/null
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" YADR_REPO_URL="$repo" YADR_HOME="$home" \
    bash "$YADR_ROOT/bootstrap.sh" --ref v1.2.3 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"requested release: v1.2.3"* ]]
  [[ "$output" == *"pinned ref v1.2.3 verified (VERSION 1.2.3)"* ]]
  [[ "$output" == *"stub: install"* ]]
  [[ "$output" == *"VERSION 1.2.3"* ]]
  [ "$(cat "$home/VERSION")" == "1.2.3" ]
  # The exact release commit, not whatever a branch points at today.
  [ "$(git -C "$home" rev-parse HEAD)" == "$(git -C "$repo" rev-parse 'v1.2.3^{commit}')" ]
  # Detached HEAD is the honest state for "this is v1.2.3 and nothing else".
  run git -C "$home" symbolic-ref -q HEAD
  [ "$status" -ne 0 ]
  rm -rf "$repo"
}

@test "bootstrap --ref accepts a checkout whose VERSION matches the tag" {
  local checkout="$BATS_TMPDIR/bs-match-$$"
  make_fixture_repo "$checkout" 1.2.3 >/dev/null
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" YADR_HOME="$checkout" \
    bash "$YADR_ROOT/bootstrap.sh" --local --ref v1.2.3
  [ "$status" -eq 0 ]
  [[ "$output" == *"pinned ref v1.2.3 verified"* ]]
  [[ "$output" == *"stub: install"* ]]
  rm -rf "$checkout"
}

@test "bootstrap --ref refuses a mislabelled tag without installing" {
  local checkout="$BATS_TMPDIR/bs-mismatch-$$"
  make_fixture_repo "$checkout" 1.2.3 >/dev/null
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" YADR_HOME="$checkout" \
    bash "$YADR_ROOT/bootstrap.sh" --local --ref v9.9.9
  [ "$status" -ne 0 ]
  [[ "$output" == *"VERSION says '1.2.3'"* ]]
  [[ "$output" == *"mislabelled tag"* ]]
  [[ "$output" != *"stub: install"* ]]
  rm -rf "$checkout"
}

@test "bootstrap --ref fails loudly on a tag that does not exist" {
  local repo home
  repo="$BATS_TMPDIR/bs-fixture-absent-$$"
  home="$TEST_HOME/.yadr-nope"
  make_fixture_repo "$repo" 1.0.0 >/dev/null
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" YADR_REPO_URL="$repo" YADR_HOME="$home" \
    bash "$YADR_ROOT/bootstrap.sh" --ref v0.0.0-absent
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not clone"* ]]
  [[ "$output" != *"stub: install"* ]]
  rm -rf "$repo"
}

@test "bootstrap --ref without a tag is a usage error" {
  run env HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash "$YADR_ROOT/bootstrap.sh" --ref
  [ "$status" -ne 0 ]
  [[ "$output" == *"--ref needs a tag"* ]]
}
