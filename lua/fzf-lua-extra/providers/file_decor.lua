local ns = vim.api.nvim_create_namespace('fzf-lua-extra.decor')
local lmarks = {} ---@type [integer, string, string][] -- line number -> { extmark id, icon, hl }

local overlay = true

---@class fle.config.FileDecor: fzf-lua.config.Base
local __DEFAULT__ = {
  file_icons = false,
  cmd = 'fd --color=never --hidden --type f --type l --exclude .git',
  git_icons = false,
  fn_transform = overlay and function(e) return ' ' .. e end or nil,
  _fmt = overlay and { from = function(e) return e:match('%S.*') end } or nil,
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
  previewer = 'builtin',
  winopts = {
    on_create = function(e)
      vim.api.nvim_set_decoration_provider(ns, {
        on_line = function(_, _, buf, lnum)
          -- skip prompt 0, maybe not the first line though
          if buf ~= e.bufnr or lnum == 0 then return end
          local line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, true)[1]
          if not line then return end
          local content = line:match('^%s*(%S+)')
          if not content then
            if lmarks[lnum] then
              vim.api.nvim_buf_del_extmark(buf, ns, lmarks[lnum][1])
              lmarks[lnum] = nil
            end
            return
          end
          -- FIXME: scroll...
          ---@type string?, string?
          local icon, hl = require('mini.icons').get('file', content)
          if icon and (not lmarks[lnum] or (lmarks[lnum][2] ~= icon and lmarks[lnum][3] ~= hl)) then
            local id = vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
              id = (lmarks[lnum] or {})[1],
              -- virt_text_pos = 'inline', -- this break fzf match hl
              virt_text_pos = overlay and 'overlay' or 'right_align',
              virt_text = { { icon .. ' ', hl or 'Error' } },
            })
            lmarks[lnum] = lmarks[lnum] or {}
            lmarks[lnum][1] = id
            lmarks[lnum][2] = icon
            lmarks[lnum][3] = hl
          end
        end,
      })
    end,
    on_close = function() vim.api.nvim_set_decoration_provider(ns, { on_line = nil }) end,
  },
}

return function(opts)
  assert(__DEFAULT__)
  lmarks = {}
  -- require('fzf-lua.devicons').load()
  FzfLua.fzf_exec(opts.cmd, opts)
end
