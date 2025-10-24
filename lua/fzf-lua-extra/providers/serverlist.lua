local uv = vim.uv

local spawn = function(cmd)
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
    vim.schedule_wrap(function(rc)
      if #vim.api.nvim_get_proc_children(uv.os_getpid()) == 0 then
        vim.cmd.cquit { count = rc, bang = true }
      end
    end)
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

local __DEFAULT__ = {
  previewer = {
    -- TODO: should reload on preview fail
    -- cmd = [[>/tmp/screenshot; nvim --clean --headless --remote-expr 'nvim__screenshot("/tmp/screenshot")' --server {}; cat /tmp/screenshot]],
    _ctor = function()
      local p = require('fzf-lua.previewer.fzf').cmd_async:extend()
      local utils = require('fzf-lua-extra.utils')
      function p:cmdline(_)
        return FzfLua.shell.stringify_cmd(function(items, lines, columns)
          self._last_query = items[2] or ''
          local path = parse_entry(items[1])
          local tmpfile = vim.fn.tempname()
          local filelines = utils.center_message({ 'This instance seems headless' }, lines, columns)
          vim.fn.writefile(filelines, tmpfile)
          remote_exec(path, 'nvim__screenshot', tmpfile)
          return 'cat ' .. tmpfile
        end, self.opts, '{} {q}')
      end
      return p
    end,
  },
  _resume_reload = true, -- avoid list contain killed server unhide
  keymap = { fzf = { resize = 'refresh-preview' } },
  actions = {
    ['enter'] = function(sel) vim.cmd.connect(parse_entry(sel[1])) end,
    ['alt-n'] = {
      fn = function()
        spawn({ vim.fn.exepath('nvim'), '--headless' })
        vim.wait(10)
      end,
      reload = true,
    },
    ['ctrl-x'] = {
      fn = function(sel)
        local exec = function(path)
          remote_exec(path, 'nvim_exec_lua', 'vim.schedule(function() vim.cmd("qa!") end)', {})
        end
        vim.iter(sel):map(parse_entry):each(exec)
      end,
      reload = true,
    },
  },
}

return function(opts)
  assert(__DEFAULT__)
  require('fzf-lua').fzf_exec(function(cb)
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
  end, opts)
end
