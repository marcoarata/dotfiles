-- YADR 2027 :: treesitter
local ok, configs = pcall(require, "nvim-treesitter.configs")
if not ok then
  return
end

configs.setup({
  ensure_installed = {
    "lua",
    "javascript",
    "typescript",
    "bash",
    "json",
    "markdown",
    "markdown_inline",
    "vim",
    "vimdoc",
  },
  sync_install = false,
  auto_install = true,
  highlight = { enable = true, additional_vim_regex_highlighting = false },
  indent = { enable = true },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },
})

-- Keep nvim-treesitter on master: this local shim adapts its directives to
-- Neovim 0.12's list-of-nodes match values. Load it after setup so it wins.
require("yadr.treesitter_compat")
