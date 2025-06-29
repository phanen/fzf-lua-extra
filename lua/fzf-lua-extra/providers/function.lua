local getfunc = function(s)
  if not s then return end
  local name = s:match('function (.*)%(')
  if not name then return end
  local content = vim.split(vim.api.nvim_exec2('function ' .. name, { output = true }).output, '\n')
  local skip_col = #content[1]:match('(.*)function')
  local new_content = vim
    .iter(content)
    :map(function(line) return line:sub(skip_col + 1) end)
    :totable()
  return name, new_content
end

local preview_with = function(_self, content)
  local tmpbuf = _self:get_tmp_buffer()
  vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, content)
  if _self.filetype then vim.bo[tmpbuf].filetype = _self.filetype end
  _self:set_preview_buf(tmpbuf)
  _self.win:update_preview_scrollbar()
end

return function(opts)
  opts = opts or {}
  opts._treesitter = function(line) return 'foo.vim', nil, line end
  opts.actions = {
    enter = {
      fn = function(sel)
        local name, content = getfunc(sel[1])
        if not name or not content then return end
        vim.cmd.tabnew()
        vim.bo.ft = 'vim'
        vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), 0, -1, false, content)
      end,
    },
  }
  -- opts.preview = {
  --   fn = function(sel)
  --     local name = d(sel[1])
  --     if not name then return end
  --     return vim.api.nvim_exec2('function ' .. name, { output = true }).output
  --   end,
  -- }
  opts.previewer = {
    _ctor = function()
      local p = require('fzf-lua.previewer.builtin').buffer_or_file:extend()
      function p:populate_preview_buf(sel)
        local name, content = getfunc(sel)
        if not name or not content then return end
        self.filetype = 'vim'
        preview_with(self, content)
      end
      return p
    end,
  }

  opts.fzf_colors = { ['hl'] = '-1:reverse', ['hl+'] = '-1:reverse' }
  require('fzf-lua').fzf_exec(
    vim.split(vim.api.nvim_exec2('function', { output = true }).output, '\n'),
    opts
  )
end
