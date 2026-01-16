-- vim:cole=2
-- 1. conceal can have at most one char
local ns = vim.api.nvim_create_namespace('fzf-lua-extra.decor')

-- TODO: we can use hlgroup only.. since we only want color icons!!
local overlay = false

local makeline = function(buf, lnum, line)
  local off, content = line:match('^(%s*)(%S+)')
  if not off or not content then return end
  local icon, hl = require('mini.icons').get('file', content)
  if not icon then return end
  local parts = vim.split(content, '/')
  -- dd(line, parts)
  local current_col = #off
  local n = #parts
  for i, part in ipairs(parts) do
    if i == n then return end
    vim.api.nvim_buf_set_extmark(buf, ns, lnum, current_col, {
      end_col = current_col + #part,
      hl_group = hl,
      conceal = part:sub(1, 1),
      ephemeral = true,
    })
    current_col = current_col + #part + 1
  end
end

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
      -- vim.wo[e.winid].conceallevel = 3
      vim.wo[e.winid][0].conceallevel = 2
      vim.schedule(function()
        -- vim.wo[e.winid][0].number = true
        -- vim.wo[e.winid][0].signcolumn = 'yes:1'
      end)
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
          makeline(buf, lnum, line)
          return
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
