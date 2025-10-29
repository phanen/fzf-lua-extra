local curdir = assert(debug.getinfo(1, 'S').source:sub(2):match('(.*/)'))

local getdefault = function(f, name)
  local i = 1
  while true do
    local n, opts = debug.getupvalue(f, i)
    if not n then break end
    if n == name then return vim.is_callable(opts) and opts() or opts end
    i = i + 1
  end
end

---@diagnostic disable: no-unknown
local register = function(name, mod)
  require('fzf-lua')[name] = function(opts)
    local f = require(mod)
    local default = getdefault(f, '__DEFAULT__')
    if default then
      FzfLua.defaults[name] = default
      opts = require('fzf-lua.config').normalize_opts(opts or {}, name)
    end
    FzfLua.utils.set_info({ cmd = name, fnc = name, mod = mod })
    return f(opts)
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
    register(name, mod)
    ---@type fun(...: table): any
    M[name] = require('fzf-lua')[name]
    return M
  end
)
