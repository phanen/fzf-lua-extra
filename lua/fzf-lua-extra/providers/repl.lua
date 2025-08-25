return function()
  require('fzf-lua').fzf_live(function(s)
    return function(cb)
      local f = loadstring('return ' .. s[1])
      if not f then return end
      local ret = { pcall(f) }
      if ret[1] then table.remove(ret, 1) end
      vim.iter(ret):map(vim.inspect):each(cb)
    end
  end, {})
end
