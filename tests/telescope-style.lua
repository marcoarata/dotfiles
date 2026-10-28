-- Unit test for nvim/lua/yadr/telescope.lua.
-- Stubs Telescope so the layout and highlight contract is checked without the
-- plugin, a terminal, or a real picker window.
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":h:h")
local config = root .. "/nvim/lua/yadr/telescope.lua"

local setup_opts
package.loaded["telescope"] = {
  setup = function(opts)
    setup_opts = opts
  end,
}
package.loaded["telescope.actions"] = {
  move_selection_next = function() end,
  move_selection_previous = function() end,
}

local ok, err = pcall(dofile, config)
if not ok then
  print("FAIL telescope-style: load: " .. tostring(err))
  os.exit(1)
end
if not setup_opts then
  print("FAIL telescope-style: telescope.setup() was not called")
  os.exit(1)
end

local defaults = setup_opts.defaults
local horizontal = defaults.layout_config and defaults.layout_config.horizontal
local function check(name, actual, expected)
  if actual ~= expected then
    print(("FAIL telescope-style: %s: expected %q, got %q"):format(
      name,
      tostring(expected),
      tostring(actual)
    ))
    os.exit(1)
  end
end

check("layout_strategy", defaults.layout_strategy, "horizontal")
check("sorting_strategy", defaults.sorting_strategy, "descending")
check("border", defaults.border, true)
check("horizontal.width", horizontal and horizontal.width, 0.88)
check("horizontal.height", horizontal and horizontal.height, 0.88)
check("horizontal.preview_width", horizontal and horizontal.preview_width, 0.40)
check("horizontal.prompt_position", horizontal and horizontal.prompt_position, "bottom")

local borderchars = defaults.borderchars
if type(borderchars) ~= "table" or #borderchars ~= 8 then
  print("FAIL telescope-style: borderchars must have 8 entries")
  os.exit(1)
end
local expected_borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
for i, char in ipairs(expected_borderchars) do
  check("borderchars[" .. i .. "]", borderchars[i], char)
end

local expected_highlights = {
  TelescopeBorder = "#7aa2f7",
  TelescopeResultsBorder = "#7aa2f7",
  TelescopePreviewBorder = "#7aa2f7",
  TelescopePromptBorder = "#ff9e64",
  TelescopeTitle = "#7aa2f7",
  TelescopeResultsTitle = "#7aa2f7",
  TelescopePreviewTitle = "#7aa2f7",
  TelescopePromptTitle = "#ff9e64",
}

for group, expected in pairs(expected_highlights) do
  local hl = vim.api.nvim_get_hl(0, { name = group })
  local actual = hl.fg and string.format("#%06x", hl.fg) or nil
  check("highlight " .. group, actual, expected)
  if hl.bg ~= nil then
    print("FAIL telescope-style: highlight " .. group .. " must have bg=NONE")
    os.exit(1)
  end
end

print("telescope-style: ok")
