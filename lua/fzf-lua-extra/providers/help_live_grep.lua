---@class fle.config.HelpLiveGrep: fzf-lua.config.Base
local __DEFAULT__ = {}

local dedup = function(paths)
  table.sort(paths, function(a, b) return #a < #b end)
  local res = {}
  for _, path in ipairs(paths) do
    if not vim.iter(res):any(function(p) return vim.fs.relpath(p, path) end) then
      res[#res + 1] = path
    end
  end
  return res
end

---@return string[]
local get_help_paths = function()
  ---@type string[]
  local rtp = vim.opt.runtimepath:get()
  -- If using lazy.nvim, get all the lazy loaded plugin paths (#1296)
  local lazy = package.loaded['lazy.core.util']
  if lazy and lazy.get_unloaded_rtp then vim.list_extend(rtp, (lazy.get_unloaded_rtp(''))) end
  ---@type string[]
  local docs = {}
  for _, path in ipairs(rtp) do
    local doc = vim.fs.joinpath(path, 'doc')
    if vim.uv.fs_stat(doc) then docs[#docs + 1] = doc end
  end
  return dedup(docs)
end

return function(opts)
  opts = opts or {}
  FzfLua.live_grep(vim.tbl_deep_extend('keep', opts, {
    search_paths = get_help_paths(),
  }))
end
