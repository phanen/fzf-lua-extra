local __DEFAULT__ = {
  silent = true,
  previewer = 'builtin',
  file_icons = 1,
  color_icons = true,
  fzf_opts = { ['--no-sort'] = true },
  ---@diagnostic disable-next-line: undefined-field
  actions = _G.fzf_lua_actions and _G.fzf_lua_actions.files or nil,
}
---@diagnostic disable-next-line: no-unknown
return function(opts)
  assert(__DEFAULT__)
  local f = require('fzf-lua')
  local contents = function(cb)
    coroutine.wrap(function()
      local co = coroutine.running()
      ---damn
      ---@type string[]
      local paths = require('mini.visits').list_paths('')
      for _, file in ipairs(paths) do
        cb(f.make_entry.file(file, opts), function() coroutine.resume(co) end)
        coroutine.yield()
      end
      cb(nil)
    end)()
  end
  f.fzf_exec(contents, opts)
end
