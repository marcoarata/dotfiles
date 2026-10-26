-- YADR 2027 :: keymaps (historical "," leader mappings)
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

local function map_opts(desc)
  return vim.tbl_extend("force", opts, { desc = desc })
end

-- Buffers: ,z previous, ,x next, ,d close, ,b list (Telescope)
map("n", ",z", "<cmd>bprevious<cr>", map_opts("Prev buffer"))
map("n", ",x", "<cmd>bnext<cr>", map_opts("Next buffer"))
map("n", ",d", "<cmd>bdelete<cr>", map_opts("Close buffer"))
map("n", ",b", "<cmd>Telescope buffers<cr>", map_opts("List buffers"))

-- LSP definition search: ,f jump to definition, ,F jump back / declaration
map("n", ",f", vim.lsp.buf.definition, map_opts("LSP: find definition"))
map("n", ",F", vim.lsp.buf.declaration, map_opts("LSP: find declaration"))

-- Grep via Telescope + ripgrep: ,gf file word, ,gg live grep, ,gd cursor word, ,gcf git changed grep
map("n", ",gf", "<cmd>Telescope grep_string<cr>", map_opts("Grep string under cursor"))
map("n", ",gg", "<cmd>Telescope live_grep<cr>", map_opts("Live grep (rg)"))
map("n", ",gd", function()
  require("telescope.builtin").grep_string({ search = vim.fn.expand("<cword>") })
end, map_opts("Grep word under cursor"))
map("n", ",gcf", "<cmd>Telescope git_status<cr>", map_opts("Grep changed files"))

-- Files: ,t find files (project), Ctrl-P same
map("n", ",t", "<cmd>Telescope find_files<cr>", map_opts("Find files"))
map("n", "<C-p>", "<cmd>Telescope find_files<cr>", map_opts("Find files"))

-- Quickfix: ,qo open, ,qc close, ,qn/,qp next/prev
map("n", ",qo", "<cmd>copen<cr>", map_opts("Quickfix open"))
map("n", ",qc", "<cmd>cclose<cr>", map_opts("Quickfix close"))
map("n", ",qn", "<cmd>cnext<cr>", map_opts("Quickfix next"))
map("n", ",qp", "<cmd>cprev<cr>", map_opts("Quickfix prev"))

-- Whitespace: ,w trim trailing whitespace (preserve view)
map("n", ",w", function()
  local view = vim.fn.winsaveview()
  vim.cmd([[keeppatterns %s/\s\+$//e]])
  vim.fn.winrestview(view)
  vim.notify("Trailing whitespace trimmed", vim.log.levels.INFO)
end, map_opts("Trim trailing whitespace"))

-- Last edit: ,. jump to last edit position
map("n", ",.", "`.", map_opts("Jump to last edit"))

-- Comment toggle: ,ci (YADR classic), powered by Comment.nvim if present else fallback
map("n", ",ci", function()
  local ok, api = pcall(require, "Comment.api")
  if ok then
    api.toggle.linewise.current()
  else
    vim.notify("Comment.nvim not loaded", vim.log.levels.WARN)
  end
end, map_opts("Toggle comment"))
map("v", ",ci", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", opts)

-- Indent guides toggle: ,ig
map("n", ",ig", function()
  vim.opt.list = not vim.opt.list:get()
  vim.notify("Indent guides: " .. (vim.opt.list:get() and "on" or "off"))
end, map_opts("Toggle indent guides"))

-- Copy filename: ,cf relative path, ,cn absolute path with line
map("n", ",cf", function()
  local f = vim.fn.expand("%:.")
  vim.fn.setreg("+", f)
  vim.notify("Copied: " .. f)
end, map_opts("Copy relative filename"))
map("n", ",cn", function()
  local f = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", f)
  vim.notify("Copied: " .. f)
end, map_opts("Copy filename with line"))

-- Open changed files: ,ocf (git status quickfix)
map("n", ",ocf", function()
  local out = vim.fn.systemlist("git diff --name-only")
  if vim.v.shell_error ~= 0 or #out == 0 then
    vim.notify("No changed files", vim.log.levels.INFO)
    return
  end
  vim.fn.setqflist({}, " ", { title = "Changed files", lines = out })
  vim.cmd("copen")
end, map_opts("Open changed files"))

-- Vim config: ,vc edit nvim config, ,vr reload config
map("n", ",vc", "<cmd>edit " .. vim.fn.stdpath("config") .. "/init.lua<cr>", map_opts("Edit nvim config"))
map("n", ",vr", function()
  for name, _ in pairs(package.loaded) do
    if name:match("^yadr") then
      package.loaded[name] = nil
    end
  end
  dofile(vim.env.MYVIMRC or vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded", vim.log.levels.INFO)
end, map_opts("Reload nvim config"))

-- Tmux navigator: Ctrl-h/j/k/l (vim-tmux-navigator commands, work even without tmux)
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", opts)
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", opts)
map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", opts)
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", opts)

-- Multicursor-style: Ctrl-n next occurrence, Ctrl-p previous (vim-visual-multi)
vim.g.VM_maps = {
  ["Find Under"] = "<C-n>",
  ["Find Subword Under"] = "<C-n>",
  ["Select All"] = "\\A",
  ["Skip Region"] = "<C-x>",
  ["Remove Region"] = "<C-S-x>",
}
map("n", "<C-n>", "<Plug>(VM-Find-Under)", { silent = true })
map("v", "<C-n>", "<Plug>(VM-Find-Subword-Under)", { silent = true })

-- Better defaults: keep visual selection on indent, escape clears highlight
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)
map("n", "<Esc>", "<cmd>nohlsearch<cr>", opts)
