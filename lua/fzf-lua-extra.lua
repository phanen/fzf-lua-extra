local curdir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)')
return vim.iter(vim.fs.dir(vim.fs.joinpath(curdir, 'fzf-lua-extra/providers'))):fold(
  {},
  ---@param M table
  ---@param name string
  ---@return table
  function(M, name)
    ---@type string
    name = assert(name:match('(.*)%.lua$'))
    local mod = 'fzf-lua-extra.providers.' .. name
    ---@type fun(...: any): any
    M[name] = function(...)
      require('fzf-lua').set_info { mod = mod, cmd = name, fnc = name }
      return require(mod)(...)
    end
    ---@type fun(...: any): any
    require('fzf-lua')[name] = M[name]
    return M
  end
)
