local glob_regex = '(.*)%s%-%-%s(.*)'
local api = vim.api

local test = function()
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
  end, {
    fzf_opts = { ['--listen'] = true },
    previewer = 'builtin',
    -- live_field_index = '{q} $FZF_PORT',
    actions = {
      start = {
        ---TODO:
        ---@param s string[]
        fn = function(s) port = unpack(s) end,
        field_index = '$FZF_PORT',
        exec_silent = true,
      },
    },
  })
end

return function()
  ---@type string[]
  local rtp = vim.opt.runtimepath:get()
  -- If using lazy.nvim, get all the lazy loaded plugin paths (#1296)
  local lazy = package.loaded['lazy.core.util'] ---@type table
  if lazy and lazy.get_unloaded_rtp then vim.list_extend(rtp, (lazy.get_unloaded_rtp(''))) end
  FzfLua.live_grep({ search_paths = rtp, actions = { ['alt-t'] = test } })
end
