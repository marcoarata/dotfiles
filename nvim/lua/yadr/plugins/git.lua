-- YADR 2027 :: git plugins
return {
  { "tpope/vim-fugitive", event = "VeryLazy" },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    -- OPT-IN (off by default): enabled with `yadr gitsigns on`, which creates
    -- ~/.config/yadr/gitsigns.enabled. YADR_GITSIGNS=1 forces it per session
    -- without persisting. Pinned to the verified commit (schema matches below).
    enabled = vim.env.YADR_GITSIGNS == "1"
      or vim.fn.filereadable(
        (vim.env.XDG_CONFIG_HOME ~= nil and vim.env.XDG_CONFIG_HOME ~= "" and vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config"))
          .. "/yadr/gitsigns.enabled"
      ) == 1,
    commit = "070a5d7b985546cc57e1fc61e5bc507fecac6045",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local map = vim.keymap.set
          map("n", "]h", gs.next_hunk, { buffer = bufnr, desc = "Next hunk" })
          map("n", "[h", gs.prev_hunk, { buffer = bufnr, desc = "Prev hunk" })
          map("n", ",hs", gs.stage_hunk, { buffer = bufnr, desc = "Stage hunk" })
          map("n", ",hr", gs.reset_hunk, { buffer = bufnr, desc = "Reset hunk" })
          map("n", ",hp", gs.preview_hunk, { buffer = bufnr, desc = "Preview hunk" })
          map("n", ",hb", function() gs.blame_line({ full = true }) end, { buffer = bufnr, desc = "Blame line" })
        end,
      })
    end,
  },
  {
    "sindrets/diffview.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("diffview").setup({ use_icons = true })
    end,
  },
}
