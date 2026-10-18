#!/usr/bin/env bash
# smoke.sh — fast YADR 2027 checks. Non-zero exit when anything fails.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL - $1"; }

check_file() { [[ -f "$ROOT/$1" ]] && ok "$1" || fail "missing $1"; }

check_file README.md
check_file CHANGELOG.md
check_file INSTALL-YADR.md
check_file .gitignore
check_file docs/architecture.md
check_file docs/mappings.md
check_file docs/migration.md
check_file docs/troubleshooting.md
check_file docs/adr-001-symlink-manager.md
check_file docs/adr-002-runtime-manager.md
check_file docs/adr-003-purge-inventory.md
check_file docs/adr-004-failure-policy.md
check_file docs/e2e-report.md
check_file docs/evaluation.md
check_file shell/zshrc
check_file shell/aliases.zsh
check_file shell/keybindings.zsh
check_file shell/runtime.zsh
check_file shell/damoekri.zsh
check_file shell/plugins.zsh
check_file nvim/init.lua
check_file nvim/autoload/lightline/colorscheme/yadr.vim
check_file nvim/lua/yadr/options.lua
check_file nvim/lua/yadr/plugins/colorscheme.lua
check_file platform/macos.sh
check_file platform/linux.sh
check_file platform/wsl.sh
check_file platform/common.sh
check_file platform/lazygit.sh
check_file platform/tools.sh
check_file platform/macos-extras.sh
check_file terminal/solarized/README.md
check_file docs/homebrew-intel.md
check_file bin/yadr
check_file bootstrap.sh
check_file tests/shell.bats
check_file tests/bootstrap.bats
check_file tests/fault.bats
check_file tests/helpers.bash
check_file tests/coverage.sh
check_file tests/coverage-hook.sh
check_file tests/lua-parse.lua
check_file tests/fixtures/typescript-project/package.json
check_file tests/fixtures/typescript-project/mise.toml
check_file tests/fixtures/typescript-project/tsconfig.json
check_file tests/fixtures/typescript-project/pnpm-lock.yaml
check_file tests/fixtures/typescript-project/src/index.ts

# zsh syntax (only when zsh exists). Absolute glob: independent of CWD.
# shell/zshrc has no .zsh suffix: listed explicitly.
for _abs in "$ROOT"/shell/*.zsh "$ROOT"/shell/zshrc "$ROOT"/bootstrap.sh "$ROOT"/bin/yadr; do
  [[ -f "$_abs" ]] || continue
  f="${_abs#"$ROOT"/}"
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$_abs" 2>/dev/null && ok "zsh -n $f" || fail "zsh -n $f"
  else
    echo "skip - zsh not installed ($f)"
  fi
done

# bash syntax (every shipped bash file)
for _abs in "$ROOT"/bin/yadr "$ROOT"/bin/lib/*.sh "$ROOT"/bootstrap.sh "$ROOT"/platform/*.sh "$ROOT"/tests/smoke.sh; do
  [[ -f "$_abs" ]] || continue
  f="${_abs#"$ROOT"/}"
  bash -n "$_abs" && ok "bash -n $f" || fail "bash -n $f"
done

# nvim headless (guard: only when nvim exists)
if command -v nvim >/dev/null 2>&1; then
  nvim --headless "+q" >/dev/null 2>&1 && ok "nvim --headless" || fail "nvim --headless"
  # every repo lua must parse with nvim's own Lua (no plugins, no network)
  while IFS= read -r _lf; do
    [[ -n "$_lf" ]] || continue
    if nvim --headless --noplugin -u NONE -l "$ROOT/tests/lua-parse.lua" "$_lf" >/dev/null 2>&1; then
      ok "lua parse ${_lf#"$ROOT"/}"
    else
      fail "lua parse ${_lf#"$ROOT"/}"
    fi
  done < <(find "$ROOT/nvim" -name '*.lua' | sort)
else
  echo "skip - nvim not installed"
fi

# lazy-lock pins every declared plugin (lazy.nvim itself is the bootstrap)
_tmp="$(mktemp -d)" || fail "mktemp for lock check"
grep -rhoE '"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"' "$ROOT/nvim" 2>/dev/null | cut -d/ -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]' | sort -u > "$_tmp/spec.txt"
grep -oE '^  "[^"]+"' "$ROOT/nvim/lazy-lock.json" 2>/dev/null | tr -d ' "' | tr '[:upper:]' '[:lower:]' | sort -u > "$_tmp/lock.txt"
_missing="$(comm -23 "$_tmp/spec.txt" "$_tmp/lock.txt")"
_extra="$(comm -13 "$_tmp/spec.txt" "$_tmp/lock.txt" | grep -v '^lazy.nvim$' || true)"
if [[ -z "$_missing" && -z "$_extra" ]]; then
  ok "lazy-lock pins every declared plugin"
else
  [[ -n "$_missing" ]] && fail "unpinned plugins: ${_missing//$'\n'/ }"
  [[ -n "$_extra" ]] && fail "lock entries without spec: ${_extra//$'\n'/ }"
fi
rm -rf "$_tmp"

# --- release hygiene: VERSION is semver and the changelog documents it ---
_ver="$(cat "$ROOT/VERSION" 2>/dev/null)"
if [[ "$_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ok "VERSION is semver ($_ver)"
else
  fail "VERSION is not semver: '${_ver}'"
fi
if [[ -f "$ROOT/CHANGELOG.md" ]] && grep -qF "## [$_ver]" "$ROOT/CHANGELOG.md"; then
  ok "CHANGELOG has an entry for $_ver"
else
  fail "CHANGELOG lacks an entry for ${_ver}"
fi

echo "---"
echo "pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
