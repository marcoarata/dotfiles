#!/usr/bin/env bash
# smoke.sh — fast YADR 2027 checks. Non-zero exit when anything fails.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL - $1"; }

check_file() { [[ -f "$ROOT/$1" ]] && ok "$1" || fail "missing $1"; }

check_file README.md
check_file INSTALL-YADR.md
check_file .gitignore
check_file docs/architecture.md
check_file docs/mappings.md
check_file docs/migration.md
check_file docs/troubleshooting.md
check_file docs/adr-001-symlink-manager.md
check_file docs/adr-002-runtime-manager.md
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
check_file platform/lazygit.sh
check_file platform/macos-extras.sh
check_file terminal/solarized/README.md
check_file docs/homebrew-intel.md
check_file bin/yadr
check_file bootstrap.sh
check_file tests/shell.bats
check_file tests/fixtures/typescript-project/package.json
check_file tests/fixtures/typescript-project/mise.toml
check_file tests/fixtures/typescript-project/tsconfig.json
check_file tests/fixtures/typescript-project/pnpm-lock.yaml
check_file tests/fixtures/typescript-project/src/index.ts

# zsh syntax (only when zsh exists). Absolute glob: independent of CWD.
for _abs in "$ROOT"/shell/*.zsh "$ROOT"/bootstrap.sh "$ROOT"/bin/yadr; do
  [[ -f "$_abs" ]] || continue
  f="${_abs#"$ROOT"/}"
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$_abs" 2>/dev/null && ok "zsh -n $f" || fail "zsh -n $f"
  else
    echo "skip - zsh not installed ($f)"
  fi
done

# bash syntax
if [[ -f "$ROOT/tests/smoke.sh" ]]; then
  bash -n "$ROOT/tests/smoke.sh" && ok "bash -n tests/smoke.sh" || fail "bash -n tests/smoke.sh"
fi

# nvim headless (guard: only when nvim exists)
if command -v nvim >/dev/null 2>&1; then
  nvim --headless "+q" >/dev/null 2>&1 && ok "nvim --headless" || fail "nvim --headless"
else
  echo "skip - nvim not installed"
fi

echo "---"
echo "pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
