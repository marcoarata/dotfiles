-- YADR 2027 :: LSP / completion / format / lint
-- Without nvim-lspconfig: explicit configs via native vim.lsp (the plugin
-- triggers the deprecated-framework notice even when using the new API).
return {
  { "williamboman/mason.nvim" },
  { "hrsh7th/nvim-cmp", event = "InsertEnter" },
  { "hrsh7th/cmp-nvim-lsp", event = "InsertEnter" },
  { "hrsh7th/cmp-buffer", event = "InsertEnter" },
  { "hrsh7th/cmp-path", event = "InsertEnter" },
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    dependencies = { "saadparwaiz1/cmp_luasnip", "rafamadriz/friendly-snippets" },
    config = function()
      pcall(require("luasnip.loaders.from_vscode").lazy_load)
    end,
  },
  { "saadparwaiz1/cmp_luasnip", event = "InsertEnter" },
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      opts = opts or {}
      opts.snippet = { expand = function(args) luasnip.lsp_expand(args.body) end }
      opts.mapping = cmp.mapping.preset.insert({
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { "i", "s" }),
      })
      opts.sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "path" },
        { name = "buffer" },
      })
      return opts
    end,
    config = function(_, opts)
      require("cmp").setup(opts or {})
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          json = { "prettier" },
          markdown = { "prettier" },
          sh = { "shfmt" },
        },
        format_on_save = { timeout_ms = 500, lsp_fallback = true },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      -- Only linters with a binary present: avoids "ENOENT" on first start.
      local by_ft = {}
      local wanted = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        sh = { "shellcheck" },
        markdown = { "markdownlint" },
      }
      for ft, names in pairs(wanted) do
        for _, n in ipairs(names) do
          if vim.fn.executable(n) == 1 then
            by_ft[ft] = by_ft[ft] or {}
            table.insert(by_ft[ft], n)
          end
        end
      end
      require("lint").linters_by_ft = by_ft
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("YadrLint", { clear = true }),
        callback = function()
          pcall(require("lint").try_lint)
        end,
      })
    end,
  },
}
