#!/usr/bin/env bash
# coverage.sh — line coverage of YADR's shipped bash code, with a floor. No
# external dependency: tests/coverage-hook.sh records executed lines via
# BASH_ENV + a DEBUG trap during the bats run.
# core = bin/yadr + bin/lib/*.sh (the bats suite owns it: the floor applies);
# context = bootstrap.sh + platform/*.sh (the CI install job exercises it:
# printed, never counted). The denominator approximates executable lines on
# purpose — evidence of movement and dead code, not a formal metric.
# Env: YADR_COV_FLOOR (default 50), YADR_COV_REQUIRE=1 (fail if unmeasurable),
# YADR_COV_ALLOW_FAIL=1 (measure despite failures; local only).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${ROOT}/tests/coverage-hook.sh"
FLOOR="${YADR_COV_FLOOR:-50}"
LOG="$(mktemp "${TMPDIR:-/tmp}/yadr-cov.XXXXXX")"

if ! command -v bats >/dev/null 2>&1; then
  echo "coverage: bats not found in PATH; install bats-core to measure."
  exit 1
fi

# Only trust a percentage the harness actually produced.
export BASH_ENV="$HOOK" YADR_COV_LOG="$LOG"
probe="$(bash -c '. "$0"; echo probe-ok' "$HOOK" 2>/dev/null || true)"
if [[ "$probe" != *"probe-ok"* ]]; then
  echo "coverage: harness did not load (BASH_ENV/functrace unsupported here)."
  [[ "${YADR_COV_REQUIRE:-0}" == "1" ]] && exit 1
  echo "coverage: skipped."
  exit 0
fi

echo "coverage: running the bats suite under the line recorder…"
if ! (cd "$ROOT" && bats tests/shell.bats) >"${LOG}.bats" 2>&1; then
  if [[ "${YADR_COV_ALLOW_FAIL:-0}" == "1" ]]; then
    echo "coverage: the bats suite reported failures; measuring anyway (YADR_COV_ALLOW_FAIL=1)."
  else
    echo "coverage: the bats suite failed; fix the suite before measuring."
    tail -n 20 "${LOG}.bats"
    exit 1
  fi
fi

if [[ ! -s "$LOG" ]]; then
  echo "coverage: no lines were recorded — the harness is broken, not the code."
  [[ "${YADR_COV_REQUIRE:-0}" == "1" ]] && exit 1
  echo "coverage: skipped."
  exit 0
fi

# Approximate executable lines: skip blanks, comments and pure closers.
exec_lines() {
  awk '
    { line = $0; sub(/^[ \t]+/, "", line) }
    line == "" { next }
    line ~ /^#/ { next }
    line ~ /^(\}|\)|fi|done|esac|else|elif|then|do|\{|\}|;;|;;&|;&|\)\)|\|\|)$/ { next }
    { n++ }
    END { print n+0 }' "$1"
}

report() { # report <group-label> <file...>
  local label="$1"; shift
  local g_lines=0 g_exec=0 f lines exec_n pct
  printf '\n%s\n' "${label}"
  printf '%-38s %6s %6s %8s\n' "file" "lines" "exec" "cover"
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    lines="$(exec_lines "$f")"
    exec_n="$(awk -F'\t' -v f="$f" '$1 == f { print $2 }' "$LOG" | sort -u | wc -l | tr -d ' ')"
    g_lines=$((g_lines + lines)); g_exec=$((g_exec + exec_n))
    pct="$(awk -v e="$exec_n" -v t="$lines" 'BEGIN { printf "%.1f", (t > 0 ? 100 * e / t : 0) }')"
    printf '%-38s %6s %6s %7s%%\n' "${f#"$ROOT"/}" "$lines" "$exec_n" "$pct"
  done
  printf '%-38s %6s %6s %7s%%\n' "TOTAL ${label%% *}" "$g_lines" "$g_exec" \
    "$(awk -v e="$g_exec" -v t="$g_lines" 'BEGIN { printf "%.1f", (t > 0 ? 100 * e / t : 0) }')"
  printf '%s\t%s\n' "$g_lines" "$g_exec" >"${LOG}.${label%% *}"
}

report "core (bats suite owns it — floor applies)" "$ROOT/bin/yadr" "$ROOT"/bin/lib/*.sh
read -r _core_lines _core_exec <"${LOG}.core"
core_pct="$(awk -v e="$_core_exec" -v t="$_core_lines" 'BEGIN { printf "%.1f", (t > 0 ? 100 * e / t : 0) }')"

report "context (exercised by the CI install job)" "$ROOT/bootstrap.sh" "$ROOT"/platform/*.sh

printf '\n%s\n' "coverage: core ${core_pct}% (${_core_exec}/${_core_lines} approximate executable lines), floor ${FLOOR}%"
if awk -v p="$core_pct" -v f="$FLOOR" 'BEGIN { exit !(p < f) }'; then
  echo "coverage: BELOW FLOOR — a shipped code path lost its test, or new code landed untested."
  echo "coverage: add the test (preferred) or lower YADR_COV_FLOOR on purpose, never silently."
  exit 1
fi

echo "coverage: OK (core >= ${FLOOR}%)."
rm -f "$LOG" "${LOG}.bats" "${LOG}.core" "${LOG}.context"
