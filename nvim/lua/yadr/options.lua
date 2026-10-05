-- YADR 2027 :: options
-- Leader must be set before plugins / keymaps load.
vim.g.mapleader = ","
vim.g.maplocalleader = ","

local opt = vim.opt

-- Line numbers: absolute, fixed, no highlight (classic YADR).
-- Sin relativenumber ni cursorline: la columna es estrecha y estable.
opt.number = true
opt.relativenumber = false

-- Indentation: 2 spaces, expandtab (YADR default)
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- Solarized truecolor
opt.termguicolors = true
vim.o.background = "dark"

-- Clipboard + mouse
opt.clipboard = "unnamedplus"
opt.mouse = "a"

-- Persistent undo + backups
opt.undofile = true
opt.undolevels = 10000
opt.backup = false
opt.writebackup = false
opt.swapfile = false

-- Search (YADR: ignorecase + smartcase, rg powered)
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- UI (classic: no current-line highlight)
opt.cursorline = false
opt.signcolumn = "yes"
opt.colorcolumn = "80"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.list = true
opt.listchars = { tab = "▸ ", trail = "·", nbsp = "␣" }
opt.showmode = false
opt.showcmd = true
opt.laststatus = 3
opt.cmdheight = 1

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Completion / behaviour
opt.updatetime = 250
opt.timeoutlen = 500
opt.completeopt = { "menuone", "noselect", "noinsert" }
opt.wildmode = { "longest", "list", "full" }
opt.wildignore = { "*.o", "*.obj", "*.pyc", "*.class", ".git/*", "node_modules/*" }

-- Folding via treesitter (opened by default)
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevel = 99
