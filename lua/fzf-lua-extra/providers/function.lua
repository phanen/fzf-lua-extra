local funcinfo = function(s)
  if not s then return end
  ---@type string?
  local name = s:match('function (.*)%(')
  if not name then return end
  local content =
    vim.split(vim.api.nvim_exec2('verb function ' .. name, { output = true }).output, '\n')
  if not content[1] or not content[2] then return end
  local path, lnum = content[2]:match('Last set from (.*) line (%d+)')
  return path and vim.fs.normalize(path) or nil, tonumber(lnum)
end

local format = function(e) return ('%s:%s:'):format(funcinfo(e)) end

---@class fle.config.Function: fzf-lua.config.Base
local __DEFAULT__ = {
  _treesitter = function(line) return 'foo.vim', nil, line end,
  fzf_colors = { ['hl'] = '-1:reverse', ['hl+'] = '-1:reverse' },
  _actions = function() return require('fzf-lua-extra.utils').fix_actions(format) end,
  previewer = {
    _ctor = function()
      local p = require('fzf-lua.previewer.builtin').buffer_or_file:extend()
      function p:parse_entry(sel)
        local path, lnum = funcinfo(sel)
        return { path = path, line = lnum }
      end
      return p
    end,
  },
}

return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_exec(vim.split(vim.api.nvim_exec2('function', { output = true }).output, '\n'), opts)
end
