#!/usr/bin/env bash
# coverage-hook.sh — BASH_ENV shim for tests/coverage.sh. Every non-interactive
# bash the suite starts sources this file, so a DEBUG trap records
# "<file>\t<line>" for each command executed inside YADR's shipped code. Nothing
# goes to stdout: the suite stays indistinguishable from a normal run.
# `functrace` makes the trap apply inside functions and subshells, where the code
# under test lives (bash 3.2 supports both).

[[ -n "${YADR_COV_LOG:-}" ]] || return 0

_yadr_cov_record() {
  local f="${BASH_SOURCE[1]:-}" l="${BASH_LINENO[0]:-}"
  [[ -n "$f" && -n "$l" ]] || return 0
  case "$f" in /*) ;; *) f="${PWD}/${f}" ;; esac
  case "$f" in
    */bin/yadr|*/bin/lib/*.sh|*/bootstrap.sh|*/platform/*.sh)
      printf '%s\t%s\n' "$f" "$l" >>"${YADR_COV_LOG}" ;;
  esac
  return 0
}

set -o functrace 2>/dev/null || true
trap '_yadr_cov_record' DEBUG
