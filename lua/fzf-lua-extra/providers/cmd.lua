local c
---@class fle.config.Cmd: fzf-lua.config.Base
local __DEFAULT__ = {
  allow = {
    journalctl = true,
    curl = true,
  },
  fzf_opts = {
    ['--raw'] = true,
  },
  preview = {
    fn = function(...) return assert(c)(...) end,
    type = 'cmd',
    field_index = '{q}',
  },
}

---@param s string[]
---@param opts fle.config.Cmd
---@return any
c = function(s, opts)
  -- TODO: callback should have way to access cmd
  opts = type(opts) == 'table' and opts or __DEFAULT__
  local q = assert(s[1])
  local cmd = q:match('^%s*(%S+)')
  if not cmd or not opts.allow[cmd] then return vim.tbl_keys(opts.allow) end
  return q
end
return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_live(c, opts)
end
