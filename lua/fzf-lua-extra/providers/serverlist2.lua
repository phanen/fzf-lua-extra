local uv = vim.uv

local spawn = function()
  local cmd = { vim.fn.exepath('nvim'), '--headless' }
  uv.spawn(
    cmd[1],
    ---@diagnostic disable-next-line: missing-fields, missing-parameter
    {
      args = vim.list_slice(cmd, 2),
      env = (function()
        -- uv.spawn will override all env when table provided?
        -- steal from $VIMRUNTIME/lua/vim/_system.lua
        local env = vim.fn.environ() --- @type table<string,string>
        env['NVIM'] = nil
        env['NVIM_LISTEN_ADDRESS'] = nil
        local renv = {} --- @type string[]
        ---@diagnostic disable-next-line: no-unknown
        for k, v in pairs(env) do
          renv[#renv + 1] = string.format('%s=%s', k, tostring(v))
        end
        return renv
      end)(),
    },
    function(_) end
  )
end

local parse_entry = function(e) return e and e:match('%((.-)%)') or nil end

local remote_exec = function(path, method, ...)
  local chan = vim.fn.sockconnect('pipe', path, { rpc = true })
  if chan == 0 then return end
  local ret = { vim.rpcrequest(chan, method, ...) }
  vim.fn.chanclose(chan)
  return unpack(ret)
end

-- generate screenshot
-- spawn a temporary tui for non-tui/headless client
local make_screenshot = function(screenshot, addr, lines, columns)
  local closing = false
  local utils = require('fzf-lua-extra.utils')
  vim.fn.writefile(
    utils.center_message({ 'Failed to generate screenshot' }, lines, columns),
    screenshot
  )
  local uis = vim.F.npcall(remote_exec, addr, 'nvim_list_uis')
  if not uis then return end
  local has_tui = vim.iter(uis):find(function(info) return info.stdout_tty end)
  if has_tui then
    -- TODO: lines/columns don't fit in fzf preview...
    pcall(remote_exec, addr, 'nvim__screenshot', screenshot)
    return
  end
  local chan = vim.fn.jobstart({ vim.fn.exepath('nvim'), '--server', addr, '--remote-ui' }, {
    pty = true,
    height = lines,
    width = columns,
    env = { TERM = 'xterm-256color' },
    on_stdout = function(chan)
      if closing then return end
      closing = true
      -- TODO: we can loop check line1? (https://github.com/neovim/neovim/blob/460738e02de0b018c5caf1a2abe66441897ae5c8/src/nvim/tui/tui.c#L1692)
      vim.defer_fn(function() pcall(remote_exec, addr, 'nvim__screenshot', screenshot) end, 10)
      vim.defer_fn(function() vim.fn.jobstop(chan) end, 20)
    end,
  })
  return chan
end

---@type fzf-lua.config.Base|{}
local __DEFAULT__ = {
  screenshot = true and '/tmp/screenshot' or vim.fn.tempname(),
  previewer = {
    _ctor = function()
      local p = require('fzf-lua.previewer.fzf').cmd_async:extend()
      function p:cmdline(_)
        return FzfLua.shell.stringify_cmd(function(items, lines, columns)
          self._last_query = items[2] or ''
          local path = parse_entry(items[1])
          if not path then return 'true' end
          local screenshot = assert(self.opts.screenshot) ---@type string
          local chan = make_screenshot(screenshot, path, lines, columns)
          local wait = chan
              and vim.fn.executable('waitpid') == 1
              and ('waitpid %s;'):format(vim.fn.jobpid(chan))
            or ('sleep %s;'):format(50 / 1000)
          local pager = vim.fn.executable('tail') == 1 and 'tail -n+2 %s' or 'cat %s'
          return wait .. pager:format(screenshot)
        end, self.opts, '{} {q}')
      end
      return p
    end,
  },
  _resume_reload = true, -- avoid list contain killed server unhide
  keymap = {
    fzf = { resize = 'refresh-preview' },
  },
  actions = {
    ['enter'] = function(sel)
      local path = parse_entry(sel[1])
      if not path then return end
      vim.cmd.connect(path)
    end,
    ['alt-n'] = { fn = function() spawn() end, reload = true },
    ['ctrl-x'] = {
      fn = function(sel)
        local exec = function(path)
          local ok, err = pcall(remote_exec, path, 'nvim_exec2', 'qa!', {})
          assert(ok or err and err:match('Invalid channel'), err)
        end
        vim.iter(sel):map(parse_entry):each(exec)
      end,
      reload = true,
    },
  },
}

return function(opts)
  assert(__DEFAULT__)
  local f = function(cb)
    vim
      .iter(vim.fn.serverlist({ peer = true }))
      :filter(
        function(path)
          return not path:match('fzf%-lua') and not vim.tbl_contains(vim.fn.serverlist(), path)
        end
      )
      :map(function(path)
        local cwd = remote_exec(path, 'nvim_exec_lua', 'return vim.uv.cwd()', {})
        if not cwd then return end
        cwd = FzfLua.path.normalize(cwd)
        return ('%s (%s)'):format(cwd, path)
      end)
      :each(cb)
    cb(nil)
  end
  FzfLua.fzf_exec(function(cb)
    vim.defer_fn(function() f(cb) end, 50) -- wait for spawn/remote_exec?
  end, opts)
end
