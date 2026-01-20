---@class fle..License: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = 'builtin',
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
}

local function format(v)
  local ac = FzfLua.utils.ansi_codes
  local info = v.info
  local file_col = ('%s:%d:0'):format(FzfLua.make_entry.file(v.src, v.opts), info.linedefined)
  local param_str = info.nparams > 0 and (' param=%s'):format(ac.yellow(tostring(info.nparams)))
    or ''
  local upv_str = info.nups > 0 and (' upv=%s'):format(ac.cyan(tostring(info.nups))) or ''
  local vararg_str = info.isvararg and (' ' .. ac.red('vararg')) or ''
  local ref_str = v.nref > 1 and (' ref=' .. ac.magenta(tostring(v.nref))) or ''
  local fold_str = v.fold_count > 1 and (' fold=' .. ac.magenta(tostring(v.fold_count))) or ''
  return ('%s\t%s%s%s%s%s'):format(file_col, param_str, upv_str, vararg_str, ref_str, fold_str)
end

return function(opts)
  assert(__DEFAULT__)

  ---@async
  local content = function(cb)
    local co = coroutine.running()
    local seen = {}
    for _, v in pairs(debug.getregistry()) do
      if type(v) == 'function' then
        local info = assert(debug.getinfo(v))
        local src = info.source:sub(1, 1) == '@' and info.source:sub(2) or info.source
        seen[v] = seen[v] or { nref = 0 }
        seen[v].nref = seen[v].nref + 1
        seen[v].info = info
        seen[v].src = src
        seen[v].opts = opts
      end
    end
    local folded = {}
    for _, v in pairs(seen) do
      local info = v.info
      local key = ('%s:%d:%d:%d'):format(
        info.source,
        info.linedefined,
        info.lastlinedefined,
        v.nref
      )
      folded[key] = folded[key] or v
      folded[key].fold_count = (folded[key].fold_count or 0) + 1
    end
    for _, v in pairs(folded) do
      cb(format(v), function() coroutine.resume(co) end)
      coroutine.yield()
    end
    cb()
  end
  FzfLua.fzf_exec(function(...) return coroutine.wrap(content)(...) end, opts)
end
