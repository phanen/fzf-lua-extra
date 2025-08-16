local curdir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)')
local register = function(name, fun, default_opts, _override)
  ---@diagnostic disable-next-line: no-unknown
  require('fzf-lua').defaults[name] = require('fzf-lua.utils').deepcopy(default_opts)
  ---@diagnostic disable-next-line: no-unknown
  require('fzf-lua')[name] = function(...)
    FzfLua.utils.set_info({ cmd = name, fnc = name })
    return fun(...)
  end
end

return vim.iter(vim.fs.dir(vim.fs.joinpath(curdir, 'fzf-lua-extra/providers'))):fold(
  {},
  ---@param M table
  ---@param name string
  ---@return table
  function(M, name)
    ---@type string
    name = assert(name:match('(.*)%.lua$'))
    local mod = 'fzf-lua-extra.providers.' .. name
    local r = require('fzf-lua').register_extension or register
    r(name, function(...) return require(mod)(...) end)
    ---@type fun(...: table): any
    M[name] = require('fzf-lua')[name]
    return M
  end
)
