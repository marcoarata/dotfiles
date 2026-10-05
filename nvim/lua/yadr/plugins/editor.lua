-- YADR 2027 :: editor plugins
return {
  { "nvim-lua/plenary.nvim", lazy = false },
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  -- master: classic configs.setup API (stable). The main branch is the
  -- new rewrite with incompatible API; to evaluate in due time (ADR).
  { "nvim-treesitter/nvim-treesitter", branch = "master", build = ":TSUpdate" },
  { "christoomey/vim-tmux-navigator", lazy = false },
  { "tpope/vim-surround", event = "VeryLazy" },
  { "tpope/vim-repeat", event = "VeryLazy" },
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    config = function()
      require("Comment").setup()
    end,
  },
  { "editorconfig/editorconfig-vim", event = "VeryLazy" },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      -- Sin iconos Nerd: texto plano en el popup (breadcrumb/separador ASCII,
      -- sin iconos por tecla ni por mapping).
      require("which-key").setup({
        icons = {
          breadcrumb = "»",
          separator = "->",
          group = "+",
          ellipsis = "...",
          mappings = false,
          keys = {},
        },
      })
    end,
  },
  { "mg979/vim-visual-multi", event = "VeryLazy" },
}
