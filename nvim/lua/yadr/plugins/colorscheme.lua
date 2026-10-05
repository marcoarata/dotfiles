-- YADR 2027 :: colorscheme (Solarized) + classic-faithful statusline.
-- lightline.vim (el plugin del YADR original): dibuja `⮀ … ⮂` central,
-- texto plano, cero iconos Nerd en macOS y Linux.
-- (Function goes before return: in a Lua chunk nothing may follow it.)
-- Rama git para lightline. OJO: lightline (vimscript) solo ve funciones
-- Vimscript, no globales Lua: se define como comando Vim que delega en Lua.
-- Plain name, no glyphs: classic-faithful on any terminal.
vim.cmd([[
function! YadrLightlineBranch() abort
  return v:lua.YadrLightlineBranchImpl()
endfunction
]])
function _G.YadrLightlineBranchImpl()
  if vim.fn.exists("*FugitiveHead") == 1 then
    local ok, head = pcall(vim.fn.FugitiveHead)
    if ok and head ~= nil and head ~= "" then
      return head
    end
  end
  return ""
end

return {
  {
    "lifepillar/vim-solarized8",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      vim.o.termguicolors = true
      -- pcall: on first start the plugin is still installing
      -- (lazy lo instala y el segundo arranque ya es limpio).
      pcall(vim.cmd.colorscheme, "solarized8")
    end,
  },
  {
    "itchyny/lightline.vim",
    lazy = false,
    -- init (NO config): lightline lee g:lightline al cargarse; si se fija
    -- en config ya es tarde y cae en defaults. Orden garantizado por lazy.
    init = function()
      vim.g.lightline = {
        colorscheme = "solarized",
        active = {
          left = {
            { "mode", "paste" },
            { "gitbranch", "readonly", "filename", "modified" },
          },
          right = {
            { "lineinfo" },
            { "percent" },
            { "fileformat", "fileencoding", "filetype" },
          },
        },
        component_function = {
          gitbranch = "YadrLightlineBranch",
        },
        separator = { left = "", right = "" },
        subseparator = { left = "", right = "" },
      }
    end,
  },
}
