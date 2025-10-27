---@type fzf-lua.config.Base|{}
local __DEFAULT__ = {
  fzf_opts = {
    ['--no-sort'] = true,
    ['--with-nth'] = '2..',
  },
  preview = {
    -- TODO:
    fn = function(sel)
      ---@diagnostic disable-next-line: no-unknown
      sel = sel[1]
      if not sel then return end
      return vim.system({ 'cliphist', 'decode', sel }):wait().stdout
    end,
    field_index = '{1}',
  },
  -- TODO: handle binary?
  actions = {
    enter = {
      fn = function(sel)
        ---@diagnostic disable-next-line: no-unknown
        sel = sel[1]
        if not sel then return end
        local data = vim.fn.systemlist({ 'cliphist', 'decode', sel })
        ---@type string[], string
        local regs, cb = {}, vim.o.clipboard
        if cb:match('unnamed') then regs[#regs + 1] = [[*]] end
        if cb:match('unnamedplus') then regs[#regs + 1] = [[+]] end
        if #regs == 0 then regs[#regs + 1] = [["]] end
        for _, reg in ipairs(regs) do
          vim.fn.setreg(reg, data)
        end
      end,
      field_index = '{1}',
    },
  },
}

return function(opts)
  assert(__DEFAULT__)
  FzfLua.fzf_exec('cliphist list', opts)
end
