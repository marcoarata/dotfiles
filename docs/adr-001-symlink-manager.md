# ADR-001 — Symlink manager: own `bin/yadr` vs chezmoi / stow / dotbot

- Status: proposed. Final decision after VM benchmark.
- Context: YADR needs `install/diff/backup/doctor`, coexistence with classic
  YADR (`parallel/migrate/cancel`), `before/after` overrides without fork, and
  headless operation over SSH. `chezmoi`, `GNU Stow` and `dotbot` solve
  part of the problem (symlinks, templates, secrets).
- Provisional decision: keep minimal `bin/yadr` as orchestrator and do not
  introduce another framework until measured.
- Pending benchmark (identical fixture on ephemeral VM):
  1. Current `bin/yadr install`.
  2. `stow` (per-topic packages, `--adopt`, `--simulate` as dry-run).
  3. `chezmoi` (`chezmoi diff/apply`, templates, `age` for secrets).
  4. `dotbot` (declarative `install.conf.yaml`).
  Metrics: manual steps, idempotence (2nd run with no changes), real dry-run,
  automatic backup, uninstall path, extra dependencies.
- Acceptance criterion: adopt a tool only if it covers
  `diff+backup+doctor+parallel` without reintroducing an equivalent hard
  dependency to the one removed (RVM/Rake). Otherwise, `bin/yadr` stays as
  the official CLI and the ADR closes as "keep own".
