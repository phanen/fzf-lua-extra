local last_gq ---@type string?

---@class fle.config.GrepProjectGlobs: fzf-lua.config.Base
local __DEFAULT__ = {
  cmd = 'rg --column --line-number --no-heading --color=always --smart-case',
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
  previewer = 'builtin',
  keymap = function()
    return {
      fzf = {
        change = 'transform:' .. (FzfLua.shell.stringify_data(function(sel)
          if not sel[1] then return end
          local sq, gq = unpack(vim.split(sel[1], '%s%-%-%s'))
          local gq_changed = gq ~= last_gq
          last_gq = gq
          if gq_changed then
            local cmd = assert(FzfLua.utils.fzf_winobj())._o.cmd
            return ('reload(%s "" --iglob %q)+search:%s'):format(cmd, gq, sq)
          end
          return ('+search:%s'):format(sq)
        end, {}, '{q}')),
      },
    }
  end,
}

return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_exec(('%s ""'):format(opts.cmd), opts)
end
