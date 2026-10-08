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
      -- Background choice: YADR_SOLARIZED_BG env wins, else the file written
      -- by platform/macos.sh (1 light / 2 dark / 3 none menu), else none.
      -- Default on macOS AND Linux is transparent (terminal shows through);
      -- solid dark/light only on explicit choice (or YADR_SOLID_BG=1 legacy).
      local bg = vim.env.YADR_SOLARIZED_BG or ""
      if bg == "" then
        local f = io.open(vim.fn.expand("~/.config/yadr/solarized-bg"), "r")
        if f then
          bg = f:read("*l") or ""
          f:close()
        end
      end
      bg = tostring(bg):lower():match("^%s*(.-)%s*$")
      if bg ~= "light" and bg ~= "dark" and bg ~= "none" then
        bg = "none"
      end
      vim.o.background = (bg == "light") and "light" or "dark"
      vim.o.termguicolors = true
      -- pcall: on first start the plugin is still installing
      -- (lazy lo instala y el segundo arranque ya es limpio).
      pcall(vim.cmd.colorscheme, "solarized8")
      if bg ~= "none" or vim.env.YADR_SOLID_BG == "1" then
        return -- explicit solid: nothing to clear
      end
      local groups = { "Normal", "NonText", "LineNr", "SignColumn" }
      local function clear_bg()
        for _, g in ipairs(groups) do
          pcall(vim.cmd, "highlight " .. g .. " guibg=NONE ctermbg=NONE")
        end
      end
      clear_bg()
      vim.api.nvim_create_augroup("YadrTransparentBg", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = "YadrTransparentBg",
        pattern = "*",
        callback = clear_bg,
      })
    end,
  },
  {
    "itchyny/lightline.vim",
    lazy = false,
    -- init (NO config): lightline lee g:lightline al cargarse; si se fija
    -- en config ya es tarde y cae en defaults. Orden garantizado por lazy.
    init = function()
      vim.g.lightline = {
        colorscheme = "yadr",
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
