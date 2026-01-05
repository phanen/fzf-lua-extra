---@class fle.config.Runtime: fzf-lua.config.Base
local __DEFAULT__ = {}

local glob_regex = '(.*)%s%-%-%s(.*)'
local api = vim.api

local test = function()
  assert(__DEFAULT__)
  local port ---@type string?
  local glob ---@type string?
  local f ---@type string[]
  FzfLua.fzf_live(function(q)
    if not q[1] then return end
    ---@type string, string
    local sq, gq = q[1]:match(glob_regex)
    if port then
      sq = sq or q[1] ---@type string
      vim.system { 'curl', '-XPOST', ('localhost:%s'):format(port), '-d', ('search:%s'):format(sq) }
    end
    local new_glob = gq or '*'
    if new_glob == glob then return f end
    glob = new_glob
    -- sometimes we don't reload?
    f = api.nvim_get_runtime_file(glob, true)
    return f
    ---@diagnostic disable-next-line: param-type-mismatch
  end, {
    fzf_opts = { ['--listen'] = true },
    previewer = 'builtin',
    -- live_field_index = '{q} $FZF_PORT',
    actions = {
      start = {
        fn = function(s) port = unpack(s) end,
        field_index = '$FZF_PORT',
        exec_silent = true,
      },
    },
  })
end

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
local get_rtp = function()
  ---@type string[]
  local rtp = vim.opt.runtimepath:get()
  -- If using lazy.nvim, get all the lazy loaded plugin paths (#1296)
  local lazy = package.loaded['lazy.core.util']
  if lazy and lazy.get_unloaded_rtp then vim.list_extend(rtp, (lazy.get_unloaded_rtp(''))) end
  return dedup(rtp)
end

local _ = {}
local file_state = true

local make_opts = function(resume)
  file_state = not file_state
  return { query = resume == false and FzfLua.get_last_query() or nil, resume = resume }
end

_.lgrep = function(opts)
  opts = opts or {}
  FzfLua.live_grep(vim.tbl_deep_extend('keep', opts, {
    search_paths = get_rtp(),
    actions = {
      ['ctrl-g'] = function() _.files(make_opts(opts.resume ~= nil)) end,
      ['alt-g'] = FzfLua.actions.grep_lgrep,
    },
  }))
end

_.files = function(opts)
  opts = opts or {}
  FzfLua.files(vim.tbl_deep_extend('keep', opts, {
    search_paths = get_rtp(),
    actions = {
      ['ctrl-g'] = function() _.lgrep(make_opts(opts.resume ~= nil)) end,
    },
  }))
end

return function(...) return file_state and _.lgrep(...) or _.files(...) end
