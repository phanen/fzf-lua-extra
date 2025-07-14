local f = require('fzf-lua')
return function(opts)
  opts = vim.tbl_deep_extend('force', opts or {}, {
    silent = true,
    previewer = 'builtin',
    file_icons = 1,
    color_icons = true,
    fzf_opts = { ['--no-sort'] = true },
    ---@diagnostic disable-next-line: undefined-field
    actions = _G.fzf_lua_actions and _G.fzf_lua_actions.files,
  })
  local contents = function(cb)
    coroutine.wrap(function()
      local co = coroutine.running()
      for _, file in ipairs(require('mini.visits').list_paths('')) do
        cb(f.make_entry.file(file, opts), function() coroutine.resume(co) end)
        coroutine.yield()
      end
      cb(nil)
    end)()
  end
  f.fzf_exec(contents, opts)
end
