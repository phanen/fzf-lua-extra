---@type fzf-lua.config.Base|{}
local __DEFAULT__ = {
  silent = true,
  previewer = 'builtin',
  file_icons = 1,
  color_icons = true,
  fzf_opts = { ['--no-sort'] = true },
  ---@diagnostic disable-next-line: undefined-field
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
  filter = function(e) return (vim.uv.fs_stat(e.path) or {}).type == 'file' end,
}
---@diagnostic disable-next-line: no-unknown
return function(opts)
  assert(__DEFAULT__)
  local f = require('fzf-lua')
  local contents = function(cb)
    coroutine.wrap(function()
      local co = coroutine.running()
      ---@type string[]
      ---@diagnostic disable-next-line: no-unknown
      local paths = require('mini.visits').list_paths(opts.cwd or '', { filter = opts.filter })
      for _, file in ipairs(paths) do
        cb(f.make_entry.file(file, opts), function() coroutine.resume(co) end)
        coroutine.yield()
      end
      cb(nil)
    end)()
  end
  f.fzf_exec(contents, opts)
end
