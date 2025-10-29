---@class fle.config.SwiperBlines: fzf-lua.config.Base
local __DEFAULT__ = {}

---@class swiper_state
---@field lnum integer?
---@field parsing_lnum integer?
---@field in_matched boolean?
---@field start_col integer?
---@field text string[]?

return function()
  assert(__DEFAULT__)
  local off = vim.o.cmdheight + (vim.o.laststatus and 1 or 0)
  local height = math.ceil(vim.o.lines / 4)
  local ns = vim.api.nvim_create_namespace('swiper')
  local buf = vim.api.nvim_get_current_buf()
  local hl = function(start_row, start_col, end_row, end_col)
    assert(start_col >= 0 and end_col >= 0, 'start_col and end_col must be non-negative')
    vim.hl.range(buf, ns, 'IncSearch', { start_row, start_col }, { end_row, end_col }, {})
  end
  local on_buf_change = function()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local lines = vim.o.lines
    local l_s = lines - height - off + 1
    local l_e = lines - off - 1
    local max_columns = vim.o.columns
    for r = l_s, l_e do
      local state = {} ---@type swiper_state
      for c = 1, max_columns do
        local ok, ret = pcall(vim.api.nvim__inspect_cell, 1, r, c)
        if not ok or not ret[1] then break end
        (function()
          if not state.lnum then -- parsing lnum
            local d = tonumber(ret[1])
            if not state.parsing_lnum and not d then return end
            if not state.parsing_lnum then
              state.parsing_lnum = d
              return
            end
            if d then
              state.parsing_lnum = state.parsing_lnum * 10 + d
              return
            end
            state.lnum, state.parsing_lnum = assert(state.parsing_lnum), nil
            return
          end
          ---TODO: neovim upstream type
          ---@diagnostic disable-next-line: no-unknown
          local in_matched = ret[2] and ret[2].reverse
          if in_matched and not state.in_matched then
            state.start_col = math.max(c - 8, 0)
            state.text = { ret[1] }
            state.in_matched = in_matched
            return
          end
          if in_matched then
            state.text[#state.text + 1] = ret[1]
            return
          end
          if state.in_matched then
            hl(state.lnum - 1, state.start_col, state.lnum - 1, c - 8)
            state.in_matched = nil
          end
        end)()
      end
    end
  end

  FzfLua.blines {
    silent = true,
    _treesitter = function(line) return 'foo.lua', nil, line:sub(2) end,
    start = 'cursor',
    fzf_colors = { ['hl'] = '-1:reverse', ['hl+'] = '-1:reverse' },
    fzf_opts = {
      ['--with-nth'] = '4..',
      ['--nth'] = '1..',
      ['--exact'] = true,
    },
    fzf_args = '--pointer=',
    winopts = {
      split = ('botright %snew +set\\ nobl'):format(height),
      preview = { hidden = true },
      on_create = function(e)
        vim.api.nvim_create_autocmd('TextChangedT', { buffer = e.bufnr, callback = on_buf_change })
      end,
      on_close = function()
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.api.nvim_win_set_cursor(0, FzfLua.utils.__CTX().cursor)
        FzfLua.utils.zz()
      end,
    },
    actions = {
      focus = {
        ---@param sel string[]
        ---@param opts table
        fn = function(sel, opts)
          if not sel[1] then return end
          local entry = FzfLua.path.entry_to_file(sel[1], opts)
          if not entry.line then return end
          local ctx = FzfLua.utils.CTX()
          pcall(vim.api.nvim_win_set_cursor, ctx.winid, { entry.line, entry.col })
        end,
        field_index = '{}',
        exec_silent = true,
      },
    },
  }
end
