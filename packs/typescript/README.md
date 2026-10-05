# Pack TypeScript

Base: JavaScript pack (node via mise) + `tsconfig.base.json` from this dir.

## Usage
```sh
cp packs/typescript/tsconfig.base.json ./tsconfig.json
# or extend: { "extends": "./tsconfig.base.json" }
```

## LSP
- `typescript-language-server` (Neovim `ts_ls` / `tsserver`).
- Install: `npm i -g typescript typescript-language-server` or via Mason `:MasonInstall typescript-language-server`.

## Formatter
- Default Prettier: `npx prettier --write .`
- Alternative: `dprint` / `eslint --fix` per repo.
