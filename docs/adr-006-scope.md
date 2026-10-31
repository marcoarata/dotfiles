# ADR-006 — Scope and non-goals

- Status: accepted (v0.5.0).
- Context: YADR 2027 began as one person's dotfiles and became installable by
  third parties. Without an explicit boundary, every plausible subsystem can
  argue it belongs; each addition needs code, tests and documentation. This ADR
  declares what the project is and the rule that admits something.
- Decision:
  1. **What this is.** A personal Zsh + Tmux + Neovim environment — the
     Damoekri prompt, vi-everywhere, modern CLI fallbacks and a runtime layer —
     installable on macOS (Intel included), Linux (Debian/Ubuntu), WSL and
     headless SSH. Personal-first is a fact; third parties are welcome.
  2. **The lifecycle defines scope.** Install (bare machine → working
     shell/editor) → daily use → update → uninstall/backup/doctor. A subsystem
     is in scope when it serves one of those steps.
  3. **The admission rule (YAGNI).** A subsystem stays only if it names a real
     problem it prevents, or a test that fails without it. "It might be useful"
     and "a user could want it" are not reasons. The rule is applied
     retroactively: surface that cannot name either is removed.
  4. **Explicit non-goals:**
     - A general dotfile framework (chezmoi/stow/dotbot).
     - A secrets manager, server-provisioning tool or GUI configurator.
     - A package manager or runtime manager: those are delegated to the
       platform and to optional `mise`.
     - Native Windows: WSL only.
     - Moving arbitrary state between machines (`export`/`apply`) and a second
       vocabulary for the same action (`pack add` vs `install`) are retired.
     - Managing dotfiles outside the declared symlink map.
  5. **Portability targets are in scope.** macOS (Intel included), Linux, WSL
     and bash 3.2 compatibility are supported targets, not speculative extras;
     they are why `platform/*.sh` and the 3.2-safe shell code exist.
  6. **One-time tools are delimited.** `yadr migrate` addresses a single real
     event (coming from classic YADR); it is documented as one-shot and is not a
     maintenance surface to grow.
  7. **Documentation follows the same rule.** A line stays only if it carries a
     non-obvious constraint or trap, a recorded decision, a value the code
     cannot show, or re-executable evidence. Each topic has one home; other
     places link to it.
- Consequences:
  - The project loses surface that failed the admission rule and gains a test a
    reviewer can apply: name the problem or the failing test, or it does not get
    in.
  - Third-party users get a smaller contract instead of options the author
    never uses.
- Evidence: this ADR; the `Removed` section of the v0.5.0 `CHANGELOG.md`; the
  CLI contract and `usage()` agree on the same command set, enforced by the
  completion drift test.
