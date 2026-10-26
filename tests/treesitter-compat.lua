-- Regression test for nvim/lua/yadr/treesitter_compat.lua.
-- Runs without the plugin or parsers: vim.treesitter.query is stubbed only for
-- directive registration, and get_node_text() is replaced with a fixture.
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":h:h")
local shim = root .. "/nvim/lua/yadr/treesitter_compat.lua"

local directives = {}
vim.treesitter.query.add_directive = function(name, handler, opts)
  assert(opts and opts.force, name .. " must be registered with force = true")
  directives[name] = handler
end
vim.treesitter.get_node_text = function(node)
  return node.value
end

dofile(shim)

for _, name in ipairs({ "set-lang-from-mimetype!", "set-lang-from-info-string!", "downcase!" }) do
  assert(directives[name], name .. " was not registered")
end

local function check(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    print("FAIL treesitter-compat: " .. name .. ": " .. tostring(err))
    os.exit(1)
  end
end

check("mimetype module is unwrapped", function()
  local metadata = {}
  directives["set-lang-from-mimetype!"](
    { [1] = { { value = "module" } } },
    0,
    1,
    { "set-lang-from-mimetype!", 1 },
    metadata
  )
  assert(metadata["injection.language"] == "javascript")
end)

check("mimetype fallback keeps the subtype", function()
  local metadata = {}
  directives["set-lang-from-mimetype!"](
    { [1] = { { value = "text/css" } } },
    0,
    1,
    { "set-lang-from-mimetype!", 1 },
    metadata
  )
  assert(metadata["injection.language"] == "css")
end)

check("markdown info string maps to a filetype", function()
  local metadata = {}
  directives["set-lang-from-info-string!"](
    { [1] = { { value = "JS" } } },
    0,
    1,
    { "set-lang-from-info-string!", 1 },
    metadata
  )
  assert(metadata["injection.language"] == "javascript")
end)

check("downcase uses the first node", function()
  local metadata = {}
  directives["downcase!"](
    { [1] = { { value = "BASH" } } },
    0,
    1,
    { "downcase!", 1 },
    metadata
  )
  assert(metadata[1].text == "bash")
end)

print("treesitter-compat: ok")
