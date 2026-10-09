-- YADR 2027 :: LSP (mason installs, native vim.lsp configures/activates)
-- Neovim 0.11 floor: native vim.lsp.config + vim.lsp.enable API.
-- (The require('lspconfig').X.setup framework is deprecated in lspconfig 2.x
-- and will be removed in 3.0; hence no nvim-lspconfig nor mason-lspconfig.
-- mason.nvim stays as server installer via :Mason.)
local servers = { "lua_ls", "ts_ls", "bashls", "jsonls", "marksman" }

-- Capabilities: extend with cmp_nvim_lsp when available
local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_ok then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

-- Keymaps on attach
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("YadrLsp", { clear = true }),
  callback = function(ev)
    local map = vim.keymap.set
    local b = { buffer = ev.buf, silent = true }
    map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", b, { desc = "LSP definition" }))
    map("n", "gr", "<cmd>Telescope lsp_references<cr>", vim.tbl_extend("force", b, { desc = "LSP references" }))
    map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", b, { desc = "LSP hover" }))
    map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", b, { desc = "LSP rename" }))
    map("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", b, { desc = "LSP code action" }))
    map("n", "gi", "<cmd>Telescope lsp_implementations<cr>", vim.tbl_extend("force", b, { desc = "LSP implementations" }))
    map("n", "[d", vim.diagnostic.goto_prev, vim.tbl_extend("force", b, { desc = "Prev diagnostic" }))
    map("n", "]d", vim.diagnostic.goto_next, vim.tbl_extend("force", b, { desc = "Next diagnostic" }))
  end,
})

-- Diagnostics UI
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Mason (guard: works even if plugin not installed yet at first bootstrap).
-- UI with ASCII icons (no Nerd): installed +, pending ~, missing -.
local mason_ok, mason = pcall(require, "mason")
if mason_ok then
  mason.setup({
    ui = {
      icons = {
        package_installed = "+",
        package_pending = "~",
        package_uninstalled = "-",
      },
    },
  })
end

-- Native registry (also works if mason already installed the servers).
-- Explicit configs: no require('lspconfig') (deprecated in 2.x, gone in 3.0).
-- mason.nvim stays as the installer (:Mason); mason-lspconfig is not used.
if vim.fn.has("nvim-0.11") == 1 then
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"
  -- All servers always register (like upstream lspconfig):
  -- when its runtime is missing (e.g. node outside the YADR zsh), the spawn
  -- message says so. Opening from the YADR zsh = everything active.
  vim.lsp.config("lua_ls", {
    capabilities = capabilities,
    cmd = { mason_bin .. "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".luacheckrc", ".git" },
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
  })
  vim.lsp.config("ts_ls", {
    capabilities = capabilities,
    cmd = { mason_bin .. "typescript-language-server", "--stdio" },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  })
  vim.lsp.config("bashls", {
    capabilities = capabilities,
    cmd = { mason_bin .. "bash-language-server", "start" },
    filetypes = { "sh", "bash" },
    root_markers = { ".git" },
  })
  vim.lsp.config("jsonls", {
    capabilities = capabilities,
    cmd = { mason_bin .. "vscode-json-language-server", "--stdio" },
    filetypes = { "json", "jsonc" },
    root_markers = { "package.json", ".git" },
  })
  vim.lsp.config("marksman", {
    capabilities = capabilities,
    cmd = { mason_bin .. "marksman", "server" },
    filetypes = { "markdown", "markdown.mdx" },
    root_markers = { ".git" },
  })
  vim.lsp.enable(servers)
else
  -- Fallback Neovim <0.11 (should not happen: YADR floor is 0.11).
  local lsp_ok, lspconfig = pcall(require, "lspconfig")
  if lsp_ok then
    lspconfig.lua_ls.setup({
      capabilities = capabilities,
      settings = { Lua = { diagnostics = { globals = { "vim" } } } },
    })
    lspconfig.ts_ls.setup({ capabilities = capabilities })
    lspconfig.bashls.setup({ capabilities = capabilities })
    lspconfig.jsonls.setup({ capabilities = capabilities })
    lspconfig.marksman.setup({ capabilities = capabilities })
  end
end
