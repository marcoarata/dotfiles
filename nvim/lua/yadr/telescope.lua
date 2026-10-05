-- YADR 2027 :: telescope (ripgrep backed)
local ok, telescope = pcall(require, "telescope")
if not ok then
  return
end

telescope.setup({
  defaults = {
    vimgrep_arguments = {
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--hidden",
      "--glob=!.git/",
    },
    file_ignore_patterns = { "node_modules", ".git/" },
    layout_strategy = "horizontal",
    layout_config = { prompt_position = "top" },
    sorting_strategy = "ascending",
    mappings = {
      i = {
        ["<C-j>"] = require("telescope.actions").move_selection_next,
        ["<C-k>"] = require("telescope.actions").move_selection_previous,
      },
    },
  },
  pickers = {
    find_files = { hidden = true },
    live_grep = { additional_args = { "--hidden" } },
  },
})

-- Mappings: <C-p> find files, ,t files, ,b buffers, ,gg grep
local map = vim.keymap.set
local builtin_ok, builtin = pcall(require, "telescope.builtin")
if builtin_ok then
  map("n", "<C-p>", builtin.find_files, { desc = "Find files" })
  map("n", ",t", builtin.find_files, { desc = "Find files" })
  map("n", ",b", builtin.buffers, { desc = "Buffers" })
  map("n", ",gg", builtin.live_grep, { desc = "Live grep" })
end
