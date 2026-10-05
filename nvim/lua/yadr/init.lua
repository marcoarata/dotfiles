-- YADR 2027 :: core loader
-- Order matters: options -> keymaps -> plugin manager -> feature configs.
require("yadr.options")
require("yadr.keymaps")
require("yadr.lazy")
require("yadr.treesitter")
require("yadr.telescope")
require("yadr.lsp")
