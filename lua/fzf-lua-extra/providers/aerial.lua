require('aerial').sync_load() -- ensure aerial config loaded
local config = require('aerial.config')
local backends = require('aerial.backends')
local data = require('aerial.data')
local highlight = require('aerial.highlight')
local api = vim.api
local ns = api.nvim_create_namespace('fzf-lua-extra.aerial')
local utils = require('fzf-lua-extra.utils')

local items = {} ---@type aerial.Symbol[]
local bufnr, filename ---@type integer, string

---@param entry_str string
---@return fzf-lua.buffer_or_file.Entry
local parse_entry = function(entry_str)
  local idx0, _ = entry_str:match('^(%d+)\t(.*)$')
  local idx = assert(utils.tointeger(idx0))
  local item = assert(items[idx], entry_str)
  return {
    bufnr = utils.tointeger(bufnr),
    bufname = filename,
    path = filename,
    line = item.lnum or 0,
    col = item.col or 0,
    -- end_line = item.end_lnum or 0,
    -- end_col = item.end_col or 0,
    end_line = (item.selection_range or {}).end_lnum or 0,
    end_col = (item.selection_range or {}).end_col or 0,
    item = item,
  }
end

local format = function(e)
  e = parse_entry(e)
  return ('%s:%s:%s'):format(e.bufname, e.line, e.col)
end

---@class fle.config.Aerial: fzf-lua.config.Base
local __DEFAULT__ = {
  fzf_opts = { ['--ansi'] = true, ['--with-nth'] = '2..' },
  _actions = function() return utils.fix_actions(format) end,
  previewer = {
    _ctor = function()
      local base = require 'fzf-lua.previewer.builtin'.buffer_or_file
      local previewer = base:extend()
      ---@diagnostic disable-next-line: unused
      function previewer:parse_entry(entry_str) return parse_entry(entry_str) end
      function previewer:set_cursor_hl(entry)
        pcall(api.nvim_win_call, self.win.preview_winid, function()
          api.nvim_buf_call(self.preview_bufnr, function()
            api.nvim_buf_clear_namespace(0, ns, 0, -1)
            api.nvim_win_set_cursor(0, { entry.line, entry.col })
            vim.hl.range(
              0,
              ns,
              self.win.hls.search,
              { entry.line - 1, entry.col },
              { entry.end_line - 1, entry.end_col },
              {}
            )
            self.orig_pos = api.nvim_win_get_cursor(0)
            FzfLua.utils.zz()
          end)
        end)
      end
      return previewer
    end,
  },
}

return function(opts)
  assert(__DEFAULT__)
  bufnr = api.nvim_get_current_buf()
  filename = api.nvim_buf_get_name(bufnr)
  items = {}
  local backend = backends.get()

  if not backend then
    backends.log_support_err()
    return
  elseif not data.has_symbols(bufnr) then
    backend.fetch_symbols_sync(bufnr, {})
  end

  if not data.has_symbols(bufnr) then
    vim.notify('No symbols found in buffer', vim.log.levels.WARN)
    return
  end

  local bufdata = data.get_or_create(bufnr)

  FzfLua.fzf_exec(function(fzf_cb)
    for i, item in bufdata:iter({ skip_hidden = false }) do
      local icon = config.get_icon(bufnr, item.kind)
      local icon_hl = highlight.get_highlight(item, true, false) or 'NONE'
      icon = FzfLua.utils.ansi_from_hl(icon_hl, icon)
      fzf_cb(('%s\t%s%s%s'):format(i, icon, FzfLua.utils.nbsp, item.name))
      items[#items + 1] = item
    end
    fzf_cb()
  end, opts)
end
