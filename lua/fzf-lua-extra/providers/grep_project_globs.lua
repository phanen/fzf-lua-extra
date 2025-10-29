---@class fle.config.GrepProjectGlobs: fzf-lua.config.Base
local __DEFAULT__ = {}

return function()
  assert(__DEFAULT__)
  local last_gq ---@type string?
  local cmd = 'rg --column --line-number --no-heading --color=always --smart-case'
  local actions = require('fzf-lua.actions')
  FzfLua.fzf_exec(('%s ""'):format(cmd), {
    previewer = 'builtin',
    actions = {
      ['enter'] = actions.file_edit_or_qf,
      ['ctrl-s'] = actions.file_split,
      ['ctrl-v'] = actions.file_vsplit,
      ['ctrl-t'] = actions.file_tabedit,
      ['alt-q'] = actions.file_sel_to_qf,
      ['alt-Q'] = actions.file_sel_to_ll,
      ['alt-i'] = { fn = actions.toggle_ignore, reuse = true, header = false },
      ['alt-h'] = { fn = actions.toggle_hidden, reuse = true, header = false },
      ['alt-f'] = { fn = actions.toggle_follow, reuse = true, header = false },
      change = {
        fn = function() end,
        exec_silent = true,
        postfix = 'transform:'
          .. require('fzf-lua.shell').stringify_data(function(sel)
            local sq, gq = unpack(vim.split(unpack(sel), '%s%-%-%s'))
            local gq_changed = gq ~= last_gq
            last_gq = gq
            if gq_changed then return ('reload(%s "" --iglob %q)+search:%s'):format(cmd, gq, sq) end
            return ('+search:%s'):format(sq)
          end, {}, '{q}'),
      },
    },
  })
end
