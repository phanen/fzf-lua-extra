---@class fle.config.Ex: fzf-lua.config.Base
local __DEFAULT__ = {
  preview = 'true',
  line_query = function(q) return nil, (q:match('%S+$') or '') end,
  winopts = { preview = { hidden = true } },
  keymap = {
    fzf = {
      start = 'toggle-search',
      tab = 'transform:' .. FzfLua.shell.stringify_data(function(s, _, _)
        if not s[1] or not s[2] then return end
        return 'change-query:' .. (s[1]:gsub('%S+$', s[2]))
      end, {}, '{q} {}'),
    },
  },
  actions = {
    enter = { fn = function(s) vim.cmd(s[1]) end, field_index = '{q}' },
  },
}

return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_live(function(s)
    return function(cb)
      vim.iter(vim.fn.getcompletion(s[1], 'cmdline')):each(cb)
      cb(nil)
    end
  end, opts)
end
