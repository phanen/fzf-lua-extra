---@diagnostic disable: invisible, no-unknown, assign-type-mismatch, param-type-mismatch, need-check-nil
local n = require('nvim-test.helpers')
local Screen = require('nvim-test.screen')
local exec_lua = n.exec_lua

local scale = (os.getenv('CI') and 10 or 1)
local row_expr_no_attr = function(self, gridnr, rownr, cursor)
  local rv = {}
  local i = 1
  local has_windows = self._options.ext_multigrid and gridnr == 1
  local row = self._grids[gridnr].rows[rownr]
  if has_windows and self.msg_grid and self.msg_grid_pos < rownr then
    return '[' .. self.msg_grid .. ':' .. string.rep('-', #row) .. ']'
  end
  while i <= #row do
    local did_window = false
    if has_windows then
      for id, pos in pairs(self.win_position) do
        if
          i - 1 == pos.startcol
          and pos.startrow <= rownr - 1
          and rownr - 1 < pos.startrow + pos.height
        then
          table.insert(rv, '[' .. id .. ':' .. string.rep('-', pos.width) .. ']')
          i = i + pos.width
          did_window = true
        end
      end
    end

    if not did_window then
      if not self._busy and cursor and self._cursor.col == i then table.insert(rv, '^') end
      table.insert(rv, row[i].text)
      i = i + 1
    end
  end
  -- trailing whitespace
  return table.concat(rv, '') --:gsub('%s+$', '')
end

---@param self test.screen
local function render_no_attr(self)
  local rv = {}
  for igrid, grid in pairs(self._grids) do
    local height = grid.height
    if igrid == self.msg_grid then height = self._grids[1].height - self.msg_grid_pos end
    for i = 1, height do
      -- local cursor = self._cursor.grid == igrid and self._cursor.row == i
      local cursor = false
      table.insert(rv, row_expr_no_attr(self, igrid, i, cursor) .. '|')
    end
  end
  print(table.concat(rv, '\n'))
end

describe('main', function()
  local screen --- @type test.screen
  local red = '\27[0;31m'
  local green = '\27[0;32m'
  local clear = '\27[0m'
  local color = red
  local prompt_mark = '\27]133;A;\a\27'
  before_each(function()
    n.clear()
    screen = Screen.new(80, 24)
    screen:attach({ ext_messages = true })
    ---@diagnostic disable-next-line: inject-field
    screen._handle_screenshot = function() end
    -- screen:set_default_attr_ids(nil)
    exec_lua(function() ---@diagnostic disable-next-line: duplicate-set-field
      -- for plocated
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.input = function() return 'input' end
      -- vim.fn.confirm = function() return 1 end
      -- cannot print https://github.com/neovim/neovim/blob/12689c73d882a29695d3fff4f6f5af642681f0a6/runtime/lua/vim/pack.lua#L370
      ---@diagnostic disable-next-line: duplicate-set-field
      -- _G.save_print, _G.print = _G.print, function() end
      vim.env.XDG_DATA_HOME = vim.fs.abspath('./deps/.data')
      vim.env.XDG_CONFIG_HOME = vim.fs.abspath('./deps/.config')
      vim.opt.pp:append(
        -- TODO: we don't need lockfile, modify HOME+NVIM_APPNAME?
        vim.fs.joinpath(vim.env.XDG_DATA_HOME, vim.env.NVIM_APPNAME or 'nvim', 'site')
      )
      vim.pack.add({
        { src = 'https://github.com/ibhagwan/fzf-lua' },
        { src = 'https://github.com/stevearc/aerial.nvim' },
        { src = 'https://github.com/echasnovski/mini.nvim' },
        { src = 'https://github.com/folke/lazy.nvim' },
        { src = 'https://github.com/lewis6991/gitsigns.nvim' },
      }, { confirm = false })
      vim.pack.update(nil, { force = true })
      ---@diagnostic disable-next-line: missing-parameter
      -- pass spec to let lazy konw it's not a plugins...
      require('lazy').setup({ spec = {}, performance = { rtp = { reset = false } } })
      require('aerial').setup({})
      require('fzf-lua').setup({ 'hide' })
      require('mini.visits').setup()
      require('mini.icons').setup()
      require('gitsigns').setup()
      vim.opt.rtp:append('.')
      vim.cmd.runtime { 'plugin/fzf-lua-extra.lua', bang = true }
    end)
    if os.getenv('update_only') then os.exit(0) end
    -- print('SERVERNAME:', n.api.nvim_get_vvar('servername'))
    -- n.feed('y')
    -- screen:print_snapshot()
    -- exec_lua(function() _G.print = _G.save_print end)
  end)

  after_each(function() n.eq(n.api.nvim_get_vvar('errmsg'), '') end)

  local curdir = debug.getinfo(1, 'S').source:sub(2):match('(.*/)')
  for name, _ in vim.fs.dir(vim.fs.joinpath(curdir, '../lua/fzf-lua-extra/providers')) do
    name = name:match('(.*)%.lua$')
    it(('%s no error'):format(name), function()
      color = color == red and green or red
      print(clear, prompt_mark, color)
      n.api.nvim_command('edit test/main_spec.lua')
      n.fn.search('function(')
      exec_lua(function(name0, scale0)
        local opts = {
          cmd = { query = 'journalctl --user -u kanata' },
          ex = { query = 'ls' },
          repl = { query = 'vim.api.nvim_list_uis()' },
        }
        assert(xpcall(function() require('fzf-lua-extra')[name0](opts[name0]) end, debug.traceback))
        -- vim.api.nvim_command('sleep 100m') wait jobstart, check callback codepath
        vim.uv.sleep(100 * scale0)
        vim.defer_fn(function() vim.api.nvim_input(('<c-j>'):rep(4)) end, 100 * scale0)
      end, name, scale)
      n.sleep(200 * scale)
      -- screen:sleep(200 * scale)
      ---@diagnostic disable-next-line: redundant-parameter
      n.run_session(screen._session, nil, function(method, args)
        if method == 'nvim_print_event' then return end
        screen:_redraw(args)
      end, 200 * scale)
      render_no_attr(screen)
      -- screen:expect({ messages = {} })
    end)
  end
end)
