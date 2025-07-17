require('aerial').sync_load() -- ensure aerial config loaded
local config = require('aerial.config')
local backends = require('aerial.backends')
local data = require('aerial.data')
local highlight = require('aerial.highlight')
local api = vim.api

return function(opts)
  local bufnr = api.nvim_get_current_buf()
  local filename = api.nvim_buf_get_name(bufnr)
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

  local utils = require('fzf-lua.utils')
  local ns = api.nvim_create_namespace('fzf-lua-extra.aerial')
  local bufdata = data.get_or_create(bufnr)
  local items = {} ---@type aerial.Symbol[]

  require('fzf-lua.core').fzf_exec(
    function(fzf_cb)
      for i, item in bufdata:iter({ skip_hidden = false }) do
        local icon = config.get_icon(bufnr, item.kind)
        local icon_hl = highlight.get_highlight(item, true, false) or 'NONE'
        icon = utils.ansi_from_hl(icon_hl, icon)
        fzf_cb(('%s\t%s%s%s'):format(i, icon, utils.nbsp, item.name))
        items[#items + 1] = item
      end
      fzf_cb()
    end,
    vim.tbl_deep_extend('force', opts or {}, {
      fzf_opts = { ['--ansi'] = true, ['--with-nth'] = '2..' },
      previewer = {
        _ctor = function()
          local base = require 'fzf-lua.previewer.builtin'.buffer_or_file
          local previewer = base:extend()
          function previewer:parse_entry(entry_str)
            ---@type string, string
            local idx, _ = entry_str:match('^(%d+)\t(.*)$')
            local item = items[tonumber(idx)]
            return {
              bufnr = tonumber(bufnr),
              bufname = filename,
              path = filename,
              line = item.lnum or 0,
              col = item.col or 0,
              -- end_line = item.end_lnum or 0,
              -- end_col = item.end_col or 0,
              end_line = item.selection_range.end_lnum or 0,
              end_col = item.selection_range.end_col or 0,
              item = item,
            }
          end
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
                utils.zz()
              end)
            end)
          end
          return previewer
        end,
      },
    })
  )
end
