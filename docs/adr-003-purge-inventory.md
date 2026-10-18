# ADR-003 — Purge inventory: delete only what YADR added, never the user's data

- Status: accepted (v0.3.0). Implemented and covered by tests.
- Context: `yadr uninstall --purge` removes data YADR created — nvim plugins
  (`~/.local/share/nvim/lazy`), Mason servers, mise toolchains, zoxide/pip
  caches (`~/.cache/nvim`, `~/.local/state/nvim`). Those directories mix
  YADR-created entries with content the user already had there. A plain
  `rm -rf` of the parent directory would destroy the user's own plugins,
  toolchains and caches, which is the worst failure mode of an installer and
  the reason `--purge` is opt-in and confirmed.
- Options considered:
  1. **Manifest of YADR-owned names** — keep a list of every file YADR expects
     and delete exactly those. Rejected: `lazy.nvim`, `mason.nvim` and `mise`
     choose their own layout and write wherever they want inside those trees,
     so the manifest would drift from reality and start leaking data.
  2. **Marker files next to each managed entry** — rejected: same drift
     problem plus hidden metadata inside directories that belong to other
     tools.
  3. **Age / mtime heuristics** — rejected: unpredictable, and it would delete
     a plugin the user installed last week while sparing a stale YADR one.
  4. **Pre-install snapshot of the directory's top-level entries (chosen)** —
     record what was already there before YADR touched the machine, then treat
     only the difference as YADR's.
- Decision: `snapshot_share_dirs` (`bin/lib/install.sh`) records the top-level
  entries of the five data directories at *first* install into
  `$STATE_DIR/preexisting-<tag>` (first-install-wins: an existing snapshot is
  never overwritten, so an upgrade cannot promote YADR data to "pre-existing").
  `purge_dir_keep_preexisting` then walks each directory and deletes everything
  that is **not** in its snapshot. Without a snapshot the function refuses to
  delete anything and warns instead ("refusing blind wipe").
- Consequences:
  - Pre-existing user data always survives a purge, by construction and by
    test, not by carefulness at delete time.
  - **Trade-off, accepted and documented:** entries created *after* the install
    by tools unrelated to YADR, inside the same five directories, are removed
    too. `--purge` is meant for leaving YADR for good; take `yadr backup` (or a
    copy) first if other tools write into those trees.
  - The inventory is top-level only: a pre-existing directory is kept whole,
    including anything created inside it later, because YADR never claims the
    contents of a directory it did not create.
  - Filenames containing newlines are out of scope (the inventory is read with
    `ls -A`), stated in the code.
- Evidence: `bin/lib/install.sh` (`snapshot_share_dirs`,
  `purge_dir_keep_preexisting`), `bin/lib/recover.sh` (`do_uninstall`), and the
  bats tests "purge keeps pre-existing share entries, removes YADR-added ones",
  "snapshot_share_dirs is first-install-wins", "purge refuses blind wipe
  without snapshot" and "uninstall --purge removes YADR state, keeps
  pre-existing data".
