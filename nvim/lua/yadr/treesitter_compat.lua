-- YADR 2027 :: nvim-treesitter master compatibility shim
-- Neovim 0.12 passes directives a list of nodes per capture. nvim-treesitter
-- master still treats those values as a single node, so get_node_text() fails
-- with "attempt to call method 'range'". Unwrap the first node and re-register
-- the affected directives after configs.setup().
local query = vim.treesitter.query

local html_script_type_languages = {
  ["importmap"] = "json",
  ["module"] = "javascript",
  ["application" .. "/" .. "ecmascript"] = "javascript",
  ["text" .. "/" .. "ecmascript"] = "javascript",
}

-- Same aliases nvim-treesitter uses when vim.filetype.match() has no answer.
local non_filetype_match_aliases = {
  ex = "elixir",
  pl = "perl",
  sh = "bash",
  uxn = "uxntal",
  ts = "typescript",
}

local function first_node(match, id)
  local value = match[id]
  if type(value) == "table" then
    return value[1]
  end
  return value
end

local function add(name, handler)
  query.add_directive(name, handler, { force = true })
end

add("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
  local node = first_node(match, pred[2])
  if not node then
    return
  end

  local value = vim.treesitter.get_node_text(node, bufnr)
  local configured = html_script_type_languages[value]
  if configured then
    metadata["injection.language"] = configured
  else
    local parts = vim.split(value, "/", {})
    metadata["injection.language"] = parts[#parts]
  end
end)

add("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
  local node = first_node(match, pred[2])
  if not node then
    return
  end

  local alias = vim.treesitter.get_node_text(node, bufnr):lower()
  local filetype = vim.filetype.match({ filename = "a." .. alias })
  metadata["injection.language"] = filetype or non_filetype_match_aliases[alias] or alias
end)

-- Bash, Ruby, PHP and HCL heredocs use this directive too. It has the same
-- list-vs-node problem, so keep it in the shim rather than leaving those
-- languages half-fixed.
add("downcase!", function(match, _, bufnr, pred, metadata)
  local id = pred[2]
  local node = first_node(match, id)
  if not node then
    return
  end

  local node_metadata = metadata[id]
  local text = vim.treesitter.get_node_text(node, bufnr, { metadata = node_metadata }) or ""
  if not node_metadata then
    metadata[id] = {}
  end
  metadata[id].text = string.lower(text)
end)

return true
