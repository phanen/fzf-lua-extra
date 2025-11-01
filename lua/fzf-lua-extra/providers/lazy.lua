-- tbh lazy load is not necessary now, just use alias here
local utils = require('fzf-lua-extra.utils')

---@param cb fun(plugin: LazyPlugin)
local p_do = function(cb)
  return function(selected)
    vim.iter(selected):each(function(sel)
      local bs_parts = vim.split(sel, '/')
      local name = bs_parts[#bs_parts]
      cb(utils.get_lazy_plugins()[name])
    end)
  end
end

local State = {}
State.state = {
  all_name = function()
    State.encode = function(p) return p.name end
  end,
  all_repo = function()
    ---@param p LazyPlugin
    ---@return string
    State.encode = function(p)
      local fullname = p[1]
      if not fullname then
        local url = p.url
        if not url then
          fullname = 'unknown/' .. p.name -- dummy name
        else
          local url_slice = vim.split(url, '/')
          local username = url_slice[#url_slice - 1]
          local repo = url_slice[#url_slice]
          fullname = username .. '/' .. repo
        end
      end
      return fullname
    end
  end,
}
State.cycle = function()
  State.key = next(State.state, State.key)
  if not State.key then State.key = next(State.state, State.key) end
  State.state[State.key]()
end

---@return function, function
State.get = function() return State.filter, State.encode end
State.cycle()

---@class fle.config.Lazy: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = { _ctor = function() return require('fzf-lua-extra.previewers').lazy end },
  actions = {
    ['enter'] = p_do(function(p)
      if p.dir and vim.uv.fs_stat(p.dir) then utils.chdir(p.dir) end
    end),
    ['ctrl-y'] = p_do(function(p) vim.fn.setreg('+', p.url) end),
    ['ctrl-o'] = p_do(function(p) -- search cleaned plugins
      vim.ui.open(p.url or ('https://github.com/search?q=%s'):format(p.name))
    end),
    ['ctrl-l'] = p_do(function(p)
      if p.dir and vim.uv.fs_stat(p.dir) then FzfLua.files { cwd = p.dir } end
    end),
    ['ctrl-n'] = p_do(function(p)
      if p.dir then FzfLua.live_grep_native { cwd = p.dir } end
    end),
    ['ctrl-r'] = p_do(
      function(p) require('lazy.core.loader')[p._ and p._.loaded and 'reload' or 'load'](p) end
    ),
    ['ctrl-g'] = { fn = State.cycle, reload = true },
  },
}

return function(opts)
  assert(__DEFAULT__)
  local contents = function(fzf_cb)
    local filter, encode = State.get()
    vim
      .iter(utils.get_lazy_plugins())
      :filter(filter or function() return true end)
      :each(function(_, p) fzf_cb(encode(p)) end)
    fzf_cb()
  end
  return FzfLua.fzf_exec(contents, opts)
end
