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
    sorting_strategy = "descending",
    layout_config = {
      horizontal = {
        width = 0.88,
        height = 0.88,
        preview_width = 0.40,
        prompt_position = "bottom",
      },
    },
    border = true,
    borderchars = {
      "─", "│", "─", "│",
      "╭", "╮", "╯", "╰",
    },
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

-- Cosmetic borders: results/preview blue, prompt orange. Reapply after a
-- colorscheme change because `:hi clear` drops non-linked groups.
local telescope_colors = {
  TelescopeBorder = "#7aa2f7",
  TelescopeResultsBorder = "#7aa2f7",
  TelescopePreviewBorder = "#7aa2f7",
  TelescopePromptBorder = "#ff9e64",
  TelescopeTitle = "#7aa2f7",
  TelescopeResultsTitle = "#7aa2f7",
  TelescopePreviewTitle = "#7aa2f7",
  TelescopePromptTitle = "#ff9e64",
}

local function apply_telescope_colors()
  for group, fg in pairs(telescope_colors) do
    vim.api.nvim_set_hl(0, group, { fg = fg, bg = "NONE" })
  end
end

apply_telescope_colors()
vim.api.nvim_create_augroup("YadrTelescopeHighlights", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = "YadrTelescopeHighlights",
  pattern = "*",
  callback = apply_telescope_colors,
})

-- Key mappings live in yadr/keymaps.lua (single source of truth).
