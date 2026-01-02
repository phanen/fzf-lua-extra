---@class fle.config.AstGrep: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = 'builtin',
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
  debug = true,
  fzf_opts = {
    ['--header-lines'] = 1,
  },
}

return function(opts)
  assert(__DEFAULT__)
  local sg = 'ast-grep run --color=always -p '
  FzfLua.fzf_live(function(s) return sg .. FzfLua.libuv.shellescape(s[1]) end, opts)
end
