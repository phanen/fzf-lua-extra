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
    require('fzf-lua').register_extension(name, function(...) return require(mod)(...) end)
    ---@type fun(...: table): any
    M[name] = require('fzf-lua')[name]
    return M
  end
)
