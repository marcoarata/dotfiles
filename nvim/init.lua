-- YADR 2027 :: Neovim entry point
-- Hard floor: Neovim >=0.11 (vim.keymap needs 0.7+, vim.lsp.config needs 0.11).
-- Old system nvim (e.g. apt 0.6.1) must never load this config: fail fast with
-- the fix instead of a cryptic E5113. (Upstream >=0.11 lives in ~/.local/bin,
-- first on PATH inside YADR zsh; outside it the system nvim rules.)
if vim.fn.has("nvim-0.11") == 0 then
  local ver = vim.fn.execute("version"):match("NVIM v%s*([%d%.]+)")
  ver = ver or "?"
  vim.notify(
    "YADR 2027 needs Neovim >=0.11 (found "
      .. ver
      .. "). Fix: open YADR zsh (exec zsh) or run: yadr install core.",
    vim.log.levels.ERROR
  )
  return
end
require("yadr")
