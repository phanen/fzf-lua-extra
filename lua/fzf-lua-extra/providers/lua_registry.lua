---@class fle..License: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = 'builtin',
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
}

local function format_func_info(src, info)
  local ac = FzfLua.utils.ansi_codes
  local home2tilde = FzfLua.path.HOME_to_tilde
  local src_path = home2tilde(src)
  local function pad(str, width)
    width = width or 20
    local padw = width + #str - vim.fn.strwidth(str)
    return ('%-' .. padw .. 's'):format(str)
  end
  local src_str = pad(src_path .. ':' .. info.linedefined .. ':0', 60)
  local args_str = ('nparams=%s isvararg=%s nups=%s'):format(
    ac.yellow(tostring(info.nparams)),
    info.isvararg and ac.red('true') or ac.green('false'),
    ac.cyan(tostring(info.nups))
  )
  return ('%s%s'):format(src_str, args_str)
end

return function(opts)
  assert(__DEFAULT__)
  local content = function(cb)
    local co = coroutine.running()
    vim.iter(debug.getregistry()):each(function(_, v)
      if type(v) == 'function' then
        local info = debug.getinfo(v)
        local src = info.source:sub(2)
        local line = format_func_info(src, info)
        cb(line, function() coroutine.resume(co) end)
        coroutine.yield()
      end
    end)
    cb()
  end
  FzfLua.fzf_exec(function(...) return coroutine.wrap(content)(...) end, opts)
end
