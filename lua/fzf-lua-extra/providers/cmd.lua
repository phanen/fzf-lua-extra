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
  require('fzf-lua').fzf_live(function(s)
    local q = s[1]
    local cmd = q:match('^%s*(%S+)')
    if not opts.allow[cmd] then return vim.tbl_keys(opts.allow) end
    u.pp(q)
    return q
  end, opts)
end
