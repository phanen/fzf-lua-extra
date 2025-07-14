local f = require('fzf-lua')
return function(opts)
  opts = opts or {}
  local search = f.utils.input('Grep > ')
  if not search then return end
  local last_gq
  local cmd = 'plocate -r'
  local actions = require('fzf-lua.actions')
  opts = vim.tbl_deep_extend('force', opts or {}, {
    raw_cmd = cmd .. ' ' .. search,
    search = search,
    previewer = 'builtin',
    actions = {
      ['enter'] = actions.file_edit_or_qf,
      ['ctrl-s'] = actions.file_split,
      ['ctrl-v'] = actions.file_vsplit,
      ['ctrl-t'] = actions.file_tabedit,
      ['alt-q'] = actions.file_sel_to_qf,
      ['alt-Q'] = actions.file_sel_to_ll,
      change = {
        fn = function() end,
        exec_silent = true,
        postfix = 'transform:' .. require('fzf-lua.shell').stringify_data(function(sel)
          local sq, gq = unpack(vim.split(unpack(sel), '%s%-%-%s'))
          local gq_changed = gq ~= last_gq
          last_gq = gq
          if gq_changed then return ('reload(%s %q)+search:%s'):format(cmd, gq, sq) end
          return ('+search:%s'):format(sq)
        end, {}, '{q}'),
      },
    },
  })
  f.grep(opts)
end
