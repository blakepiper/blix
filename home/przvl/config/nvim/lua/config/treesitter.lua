-- Some environments supply parsers through TREE_SITTER_GRAMMAR_PATH.
-- Prefer parsers built by nvim-treesitter alongside its matching queries,
-- Fall back to the original loader when no runtime parser is installed.
local language = vim.treesitter.language
local add = language.add

language.add = function(lang, opts)
  if type(lang) == "string" and lang:match("^[%w_]+$") and (opts == nil or opts.path == nil) then
    local parser = vim.api.nvim_get_runtime_file("parser/" .. lang:lower() .. ".so", false)[1]
    if parser then
      opts = vim.tbl_extend("force", opts or {}, { path = parser })
    end
  end
  return add(lang, opts)
end
