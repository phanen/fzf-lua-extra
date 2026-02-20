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
      local kwin = vim.fn.system(
        [[kitten @ ls | jq -r '.[] | select(.is_focused == true) | .tabs[] | select(.is_focused == true) | .windows[] | select(.is_focused == true) | .id']]
      )
      vim.fn.system('kitten @ launch --type=overlay-main zmx a ' .. r)
      vim.fn.system('kitten @ close-window --match id:' .. kwin)
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
