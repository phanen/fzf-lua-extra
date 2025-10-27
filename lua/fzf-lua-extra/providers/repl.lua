---@type fzf-lua.config.Base|{}
local __DEFAULT__ = {
  preview = 'true',
  winopts = { preview = { hidden = true } },
}

return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_live(function(s)
    return function(cb)
      local f, err = loadstring('return ' .. s[1])
      if not f then return cb(err) end
      local ret = vim.F.pack_len(pcall(f))
      if not ret[1] then return cb(ret[2]) end
      for i = 2, ret.n do
        cb(vim.inspect(ret[i]))
      end
      cb(nil)
    end
  end, opts)
end
