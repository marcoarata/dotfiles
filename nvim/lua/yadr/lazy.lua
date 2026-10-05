-- YADR 2027 :: lazy.nvim bootstrap + plugin specs
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local ok, lazy = pcall(require, "lazy")
if not ok then
  vim.notify("lazy.nvim not found", vim.log.levels.ERROR)
  return
end

lazy.setup({
  spec = {
    { import = "yadr.plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "solarized", "habamax" } },
  checker = { enabled = true, notify = false },
  change_detection = { enabled = true, notify = false },
  -- UI without Nerd icons (plain text; classic-faithful on any terminal).
  ui = {
    icons = {
      cmd = ":",
      config = "C",
      debug = "*",
      event = "E",
      favorite = "*",
      ft = "F",
      init = "I",
      import = "I",
      keys = "K",
      lazy = "L",
      loaded = "+",
      not_loaded = "o",
      plugin = "P",
      runtime = "R",
      require = "R",
      source = "S",
      start = ">",
      task = "ok",
      list = { "*", "->", "+", "-" },
    },
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
