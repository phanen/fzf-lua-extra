local ns = vim.api.nvim_create_namespace('fzf-lua-extra.decor')

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
        on_win = function(_, win)
          if e.winid ~= win then return false end
        end,
        on_line = function(_, _, buf, lnum)
          -- skip prompt 0, maybe not the first line though
          if lnum == 0 then return end
          local line = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, true)[1]
          if not line then return end
          local content = line:match('^%s*(%S+)')
          if not content then return end
          -- FIXME: scroll...
          ---@type string?, string?
          local icon, hl = require('mini.icons').get('file', content)
          if not icon then return end
          vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
            -- virt_text_pos = 'inline', -- this break fzf match hl
            virt_text_pos = overlay and 'overlay' or 'right_align',
            virt_text = { { icon .. ' ', hl or 'Error' } },
            ephemeral = true,
          })
        end,
      })
    end,
    on_close = function() vim.api.nvim_set_decoration_provider(ns, {}) end,
  },
}

return function(opts)
  assert(__DEFAULT__)
  -- require('fzf-lua.devicons').load()
  FzfLua.fzf_exec(opts.cmd, opts)
end
