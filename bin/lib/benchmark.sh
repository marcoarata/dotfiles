#!/usr/bin/env bash
# YADR 2027 — lib/benchmark.sh: startup/cd/prompt benchmarks
# Sourced by bin/yadr into the same shell (and by tests);
# never executed directly. Bash 3.2-compatible, no new dependencies.

do_benchmark() {
  local target="${1:-shell}"
  case "$target" in
    shell)
      # Measures YADR ZSHRC startup (not the user's ~/.zshrc) with
      # isolated HOME: touches nothing of your real ~.
      # Threshold <500ms. Measured references: ~150ms on workstation,
      # ~425ms on a slow 2vCPU quickemu VM (cost is base zsh+compinit,
      # not YADR: guarded plugins and runtime add <50ms together).
      have zsh || { warn "zsh missing; measuring with bash."; }
      local bench_home bench_zd
      bench_home="$(mktemp -d)"; bench_zd="$(mktemp -d)"
      printf 'source "%s/shell/zshrc"\n' "$YADR_HOME" > "${bench_zd}/.zshrc"
      info "benchmark shell YADR (5 arranques, HOME aislado)…"
      local i t0 t1 sum=0 n=5
      i=1; while [[ "$i" -le "$n" ]]; do
        t0=$(now_ns)
        HOME="$bench_home" ZDOTDIR="$bench_zd" zsh -i -c exit >/dev/null 2>&1 || true
        t1=$(now_ns); sum=$((sum + (t1 - t0)))
        i=$((i + 1))
      done
      printf 'YADR zshrc startup average: %d ms (threshold <500ms)\n' $((sum / n / 1000000))
      rm -rf "$bench_home" "$bench_zd"
      ;;
    nvim)
      have nvim || die "nvim missing."
      local f; f="$(mktemp)"
      nvim --headless --startuptime "$f" -c q >/dev/null 2>&1 || true
      tail -n 3 "$f"; rm -f "$f"
      ;;
    cd)
      # Directory-switch overhead (runtime auto-switch: mise/fnm hooks).
      # Threshold: mean <30ms on local machine; re-measured in VM.
      have zsh || die "zsh missing (runtime hook lives in zsh)."
      local d1 d2; d1="$(mktemp -d)"; d2="$(mktemp -d)"
      info "cd benchmark (20 round trips ${d1} ↔ ${d2})…"
      local t0 t1 sum=0 n=20 i
      t0=$(now_ns)
      i=1; while [[ "$i" -le "$n" ]]; do
        zsh -f -c "cd '$d1' >/dev/null 2>&1; cd '$d2' >/dev/null 2>&1" || true
        i=$((i + 1))
      done
      t1=$(now_ns); sum=$((t1 - t0))
      printf 'average per cd+cd cycle: %d ms (threshold: <30ms)\n' $((sum / n / 1000000))
      rmdir "$d1" "$d2" 2>/dev/null || true
      ;;
    prompt)
      # Damoekri prompt cost outside and inside a git repo.
      # Measures renders inside ONE zsh (not counting its startup).
      # Thresholds: <50ms per render outside git, <120ms inside.
      have zsh || die "zsh missing."
      local gdir; gdir="$(mktemp -d)"
      info "prompt benchmark (50 renders outside/inside git, one zsh)…"
      zsh -f -c "
        source '${YADR_HOME}/shell/runtime.zsh' >/dev/null 2>&1
        source '${YADR_HOME}/shell/damoekri.zsh' >/dev/null 2>&1
        t0=\${EPOCHREALTIME//./}; t0=\$((t0/1000))
        for _ in {1..50}; do yadr_git_info >/dev/null 2>&1; _yadr_runtime_segment >/dev/null 2>&1; done
        t1=\${EPOCHREALTIME//./}; t1=\$((t1/1000)); printf 'outside git: %d ms/render (threshold <50ms)\n' \$(((t1 - t0) / 50))
      " || warn "benchmark outside git failed."
      git init -q "$gdir" 2>/dev/null || true
      zsh -f -c "
        cd '$gdir' >/dev/null 2>&1
        source '${YADR_HOME}/shell/runtime.zsh' >/dev/null 2>&1
        source '${YADR_HOME}/shell/damoekri.zsh' >/dev/null 2>&1
        t0=\${EPOCHREALTIME//./}; t0=\$((t0/1000))
        for _ in {1..50}; do yadr_git_info >/dev/null 2>&1; _yadr_runtime_segment >/dev/null 2>&1; done
        t1=\${EPOCHREALTIME//./}; t1=\$((t1/1000)); printf 'inside git: %d ms/render (threshold <120ms)\n' \$(((t1 - t0) / 50))
      " || warn "benchmark inside git failed."
      rm -rf "$gdir"
      ;;
    *) die "unknown benchmark: $target (shell|nvim|cd|prompt)" ;;
  esac
}
