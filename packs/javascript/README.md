# Pack JavaScript (node + npm/pnpm)

Tools via mise. Global pin in `runtime/mise.toml` (`node = "24"`, LTS
bump policy documented there); each project can pin its own.

## Detection
- `node --version` (>=20 recommended; core pins LTS 24, see `runtime/mise.toml`).
- `pnpm --version || npm --version`.
- This pack ships `package.json` with `engines.node >=20` and `packageManager: pnpm@9`.
  With `idiomatic_version_file_enable_tools=[node,npm,pnpm]`, mise activates the
  version each project requests (`package.json`, `.nvmrc`).

## Usage
```sh
mise install
node --version
# pnpm when pnpm-lock.yaml exists, else npm
pnpm install || npm install
```

Per-project override in `./mise.toml`:
```toml
[tools]
node = "20"
pnpm = "9"
```
