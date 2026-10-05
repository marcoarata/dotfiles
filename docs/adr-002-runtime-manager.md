# ADR-002 — Runtime Manager: mise vs fnm vs nvm

- Status: proposed (Phase A). `mise` is the experimental reference
  implementation; `fnm` is the benchmark alternative; `nvm` is a conceptual
  fallback (historical RVM<->nvm analogy, not a technical decision).
- Context: YADR only exposes `yadr runtime current|list|use|doctor`. The
  backend is swappable without touching Damoekri/Zsh/Neovim. Node LTS is the
  reference runtime; Ruby/Python/Rust are optional packs.
- Pending benchmark (Phase B, host + ephemeral VM, same fixture
  `tests/fixtures/typescript-project`):
  1. Shell startup with each manager enabled/disabled (`yadr benchmark shell`).
  2. `cd` overhead with auto-switch (`yadr benchmark cd`, <30ms threshold).
  3. `.nvmrc` / `.node-version` / `mise.toml` /
     `packageManager` (`pnpm@x`) resolution — `engines.node` does NOT count as an exact pin.
  4. npm vs pnpm detection via lockfile without imposing a package manager.
  5. Multi-runtime support (node+ruby+python) and clean uninstall.
- Policy already fixed: explicit pinned LTS version in `VERSION`/docs (no
  floating `lts` forever), `npm install -g` only for exceptional CLI tools
  (never as a substitute for the project `package.json`).
- Acceptance criterion: whoever meets the thresholds with lowest complexity
  wins; if `fnm` wins for Node but loses on multi-runtime, `mise` stays as
  default and `fnm` is documented as an alternative.
