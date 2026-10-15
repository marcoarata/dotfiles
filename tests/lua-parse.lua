-- lua-parse.lua — parse-check one Lua file with Neovim's own Lua (no plugins, no network).
-- usage: nvim --headless --noplugin -u NONE -l lua-parse.lua <file>
-- exit 0 when it parses, 1 with a SYNTAX line otherwise.
local f = arg[1]
local ok, err = loadfile(f)
if not ok then
  io.stderr:write("SYNTAX " .. tostring(f) .. ": " .. tostring(err) .. "\n")
  os.exit(1)
end
