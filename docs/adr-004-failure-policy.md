# ADR-004 — Failure policy: runtime failures are fatal, editor failures are advisory

- Status: accepted (v0.3.0). Implemented and covered by tests.
- Context: `install` and `update` do two very different kinds of work.
  **Runtimes** (`mise install node|pnpm|python…`) decide whether the promised
  environment exists at all. **Editor state** (`Lazy! restore`, `Lazy! clean`,
  Mason servers) is long-running, network-dependent, and recoverable from
  inside `nvim` with `:Lazy restore` / `:Mason`. Treating both the same way
  produced two opposite defects in practice: a failed `mise install` ended in
  `install [node] complete` plus exit 0 (reported on WSL1, where node ≥23
  cannot `execve`: the user saw success while `doctor` saw nothing), and making
  editor steps fatal would fail installs on a slow network for a step the user
  can finish by hand.
- Decision:
  1. **Runtime failure propagates.** `ensure_profile_payload` returns non-zero;
     the fast path prints `install [<profile>] incomplete: some runtimes did
     not install` and exits non-zero; the full path applies symlinks but
     withholds the success banner and returns the payload status. A runtime the
     profile promised is never reported as installed when it is not.
  2. **Editor failure is advisory.** `ensure_nvim_plugins || true` and
     `ensure_lsp_servers || true`; each step warns with the exact recovery
     command and the install keeps going. Rationale: recoverable at the user's
     convenience, and a fatal editor step would inject network flakiness into
     installs and CI.
  3. **`update` never destroys anything, and never claims a repo it did not
     update.** A failed `git pull --ff-only` leaves the checkout exactly as it
     was, skips the editor sync (there is nothing new to restore to) and returns
     non-zero; a dirty checkout is reported before pulling; editor restore stays
     advisory; a failed `mise upgrade` warns. The previous behavior printed
     `ok repo updated.` right after a failed pull and exited 0.
  4. **Helpers report their own status.** `lazy_restore` returns nvim's status
     explicitly instead of inheriting it from the caller's `set -o pipefail`,
     so the advisory warnings reflect reality in any calling context.
- Consequences:
  - An install can finish successfully with editor warnings. `yadr doctor` is
    the source of truth for plugin/LSP/Mason state, and it is the command the
    post-install guide points at.
  - The runtime contract is enforced by a test that fails on the previous
    implementation (a failing backend must not produce a success banner), so
    the honesty guarantee cannot regress silently.
  - Editor steps are best-effort by design: a user who ignores the warning
    gets a working shell and a repairable editor, not a half-installed system.
  - The asymmetry itself is regression-tested in a dedicated lane:
    `tests/fault.bats` (CI job `fault-injection`) breaks a runtime, the editor,
    the network and the purge snapshots on purpose, and asserts after each
    injection that no success line was printed for work that did not happen.
- Evidence: tests "install fast path fails loudly when a runtime does not
  install", "typescript payload runs Lazy! restore once, not twice",
  "lazy_restore reports a failing nvim without relying on pipefail" and the
  whole `tests/fault.bats` lane; code in `bin/lib/install.sh`
  (`ensure_profile_payload`, `do_install`, `do_update`, `dirty_tree_list`).
