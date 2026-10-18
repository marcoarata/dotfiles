# ADR-006 — Scope and non-goals: personal first, installable by third parties

- Status: accepted (v0.5.0).
- Context: YADR 2027 began as one person's dotfiles — the classic YADR
  experience reborn — and only through its own development became something
  other people can install. That history left the boundary implicit: any
  plausible subsystem (a command, a pack vocabulary, a state-transfer format)
  could argue it belonged, because nothing said what the project *is not*.
  An undeclared boundary does not stay empty; it fills up, and every piece that
  fills it needs code, tests and docs to be maintained and reviewed. This ADR
  declares the boundary and the rule that admits something across it, so the
  surface stops growing by accretion.
- Decision:
  1. **What this is.** A personal Zsh + Tmux + Neovim environment — the
     Damoekri prompt, vi-everywhere, modern CLI fallbacks, a runtime layer —
     installable by third parties on macOS (Intel included), Linux
     (Debian/Ubuntu), WSL and headless SSH. Personal-first is a fact, not a
     limitation: the author is the primary user, and third parties are welcome
     to install the same thing.
  2. **The journey that defines scope.** Install (bare machine → working
     shell/editor) → daily use → update → uninstall/backup/doctor. A
     subsystem is in scope when it serves one of those steps.
  3. **The admission rule (YAGNI).** A subsystem stays only if it can name
     **(a)** a real problem it prevents, or **(b)** a test that fails without
     it. "It might be useful", "a user could want it" and "it is a feature"
     are not reasons. This rule is applied retroactively: surface that cannot
     name either is removed, not kept as decoration.
  4. **Explicit non-goals** (out of scope by design, not by omission):
     - A general dotfile framework (chezmoi / stow / dotbot): see ADR-001.
     - A secrets manager, a server-provisioning tool, a GUI/desktop
       configurator.
     - A package manager or a runtime manager: those are delegated to the
       platform's package manager and to `mise` (ADR-002), which stays optional.
     - Native Windows: WSL only.
     - **Moving arbitrary state between machines** (`export`/`apply`): retired
       in v0.5.0. `install`/`update`/`uninstall` are the supported lifecycle;
       a machine is reproduced by installing again, not by copying state.
     - A second vocabulary for the same action (`pack add` vs `install`):
       retired in v0.5.0. Profiles are installed with `yadr install <name>`.
     - Managing dotfiles outside the declared symlink map: the installer owns
       exactly the pairs `managed_pairs` lists and nothing else (ADR-005).
  5. **Portability targets are in scope, and are the reason for the cost.**
     macOS (Intel included), Linux, WSL and bash 3.2 compatibility are
     supported targets, not speculative extras: they are why `platform/*.sh`,
     `platform/macos-extras.sh` and the 3.2-safe shell code exist. Declaring
     them here turns an implicit "nice to have" into an explicit contract that
     the CI matrix holds.

  6. **One-time tools are allowed but delimited.** `yadr migrate` addresses a
     single, real event (coming from classic YADR) and is kept for that event;
     it is documented as one-shot and is not a maintenance surface to grow.

  7. **The written corpus follows the same rule.** Docs and comments are part of
     the surface to maintain, not free explanation. A line stays only if it
     carries information a reader cannot get elsewhere: a non-obvious constraint
     or trap, a recorded decision, a value the code cannot show, or re-executable
     evidence. Duplication across documents, restatement of what the code already
     says, and decorative text go. Each topic has **one home**; every other place
     links to it. The baseline this ADR was written against: 2348 lines of docs
     against 1944 lines of shipped code — the explanation had grown larger than
     the product, which is itself a scope failure.
- Consequences:
  - The project loses surface that failed the admission rule, and gains a test
    a reviewer can apply: *name the problem or the failing test, or it does not
    get in.*
  - Third-party users get a smaller, honest contract instead of a broad one
    padded with options the author never uses.
  - A future `export`/`apply` (or any removed feature) can return as an
    optional pack **only** with a demonstrated request — the decision is
    reversible, but the default is "no".
- Evidence: this ADR; the `Removed` section of the v0.5.0 `CHANGELOG.md`; the
  CLI contract (`docs/cli-contract.md`) and `usage()` agree on the same command
  set, which the completion drift test enforces.
