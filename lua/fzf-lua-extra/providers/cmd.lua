---@class fle.config.Cmd: fzf-lua.config.Base
local __DEFAULT__ = {
  allow = {
    journalctl = true,
  },
  fzf_opts = {
    ['--raw'] = true,
  },
}
return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_live(function(s)
    local q = s[1]
    local cmd = q:match('^%s*(%S+)')
    if not cmd or not opts.allow[cmd] then return vim.tbl_keys(opts.allow) end
    return q
  end, opts)
end
