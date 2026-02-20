local api = vim.api
local parse = function(entry_str)
  if entry_str:match('^no sessions found') then return end
  local items = vim.split(entry_str, '%s', { trimempty = true })
  local c = {}
  for _, kv in ipairs(items) do
    local k, v = unpack(vim.split(kv, '='))
    c[k] = v
  end
  return c['session_name']
end

local w = function(s)
  if api.nvim_ui_send and vim.in_fast_event() then
    vim.schedule_wrap(api.nvim_ui_send)(s)
  elseif api.nvim_ui_send then
    api.nvim_ui_send(s)
  else
    io.stderr:write(s)
  end
end

-- https://github.com/kovidgoyal/kitty/blob/51a08d23cd90dc0c756fef3a702a525ce60a4304/docs/mapping.rst#L204
---@param varname string
local set_user_var = function(varname)
  if not jit then return end
  w(('\x1b]1337;SetUserVar=%s=MQo\007'):format(varname))
end

local ns = api.nvim_create_namespace('fzf-lua-extra.zmx')

---@class fle.config.Zmx: fzf-lua.config.Base
local __DEFAULT__ = {
  cmd = 'zmx l',
  previewer = {
    _ctor = function(...)
      local p = require('fzf-lua.previewer.builtin').buffer_or_file:extend()
      ---@diagnostic disable-next-line: unused
      function p:parse_entry(entry_str) return { cmd = { 'zmx', 'hi', '--vt', parse(entry_str) } } end
      return p
    end,
  },
  -- or we can also pop up a fzf after quit....
  actions = {
    enter = function(s)
      local sel = s[1]
      if not sel then return end
      local r = parse(sel)
      if not r then return end
      -- local kwin = assert(os.getenv('KITTY_WINDOW_ID'), 'only support kitty')
      local ksock = assert(os.getenv('KITTY_LISTEN_ON'), 'only support kitty')
      ksock = (ksock:gsub('unix:', ''))
      if not vim.uv.fs_stat(ksock) then -- fix kitty socket
        ksock = vim.split(vim.fn.glob(vim.fs.joinpath(vim.fs.dirname(ksock), '/kitty-*')), '\n')[1]
        if not ksock or not vim.uv.fs_stat(ksock) then error('kitty socket not found') end
        vim.env.KITTY_LISTEN_ON = 'unix:' .. ksock
      end
      local kwin = vim.fn.system(
        [[kitten @ ls | jq -r '.[] | select(.is_focused == true) | .tabs[] | select(.is_focused == true) | .windows[] | select(.is_focused == true) | .id']]
      )
      vim.fn.system('kitten @ launch --type=overlay-main zmx a ' .. r)
      vim.fn.system('kitten @ close-window --match id:' .. kwin)
      vim.on_key(function()
        set_user_var('in_editor')
        vim.on_key(nil, ns)
      end, ns)
    end,
    ['ctrl-n'] = {
      fn = function()
        local q = FzfLua.get_info().last_query
        if q and #q > 0 then vim.fn.system('zmx r ' .. q) end
      end,
      reload = true,
    },
    ['ctrl-x'] = {
      fn = function(s)
        vim.iter(s):map(parse):each(function(r)
          if r then vim.fn.system('zmx k ' .. r) end
        end)
      end,
      reload = true,
    },
  },
}
---@diagnostic disable-next-line: no-unknown
return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_exec(opts.cmd, opts)
end
