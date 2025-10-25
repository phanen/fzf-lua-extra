local uv = vim.uv

local _spawn = function(cmd)
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

local C ---@type ffi.namespace*?
-- https://luvit.io/blog/pty-ffi.html
local pty_spawn = function(cmd)
  local ffi = require('ffi')
  if not C then
    ffi.cdef [[
      struct winsize {
          unsigned short ws_row;
          unsigned short ws_col;
          unsigned short ws_xpixel;   /* unused */
          unsigned short ws_ypixel;   /* unused */
      };
      int openpty(int *amaster, int *aslave, char *name,
                  void *termp, /* unused so change to void to avoid defining struct */
                  const struct winsize *winp);
    ]]
    C = ffi.C
  end

  local function openpty(rows, cols)
    -- Lua doesn't have out-args so we create short arrays of numbers.
    local amaster = ffi.new('int[1]')
    local aslave = ffi.new('int[1]')
    local winp = ffi.new('struct winsize')
    ---@diagnostic disable-next-line: inject-field
    winp.ws_row = rows
    ---@diagnostic disable-next-line: inject-field
    winp.ws_col = cols
    C.openpty(amaster, aslave, nil, nil, winp)
    -- And later extract the single value that was placed in the array.
    return amaster[0], aslave[0]
  end

  local spawn = function()
    -- local master, slave = openpty(vim.o.lines, vim.o.columns)
    ---@diagnostic disable-next-line: no-unknown
    local master, slave = openpty(1000, 1000) -- workaround with resizing
    local pipe
    local child = uv.spawn(
      cmd,
      ---@diagnostic disable-next-line: missing-fields
      {
        stdio = { slave, slave, slave },
        detached = true,
      },
      function(...)
        print(...)
        if pipe and not pipe:is_closing() then pipe:close() end
      end
    )
    pipe = assert(uv.new_pipe(false))
    pipe:open(master)
    -- 1. this will stop working when the process hold master handle is killed...
    -- so a "manager/reader/daemon/proxy process" seems still needed
    -- 2. jobstart pty=true cannot detach a terminal job
    -- 3. how about re-attach an headless peer on preview? (--remote-ui)
    pipe:read_start(function(_) end)
    return child
  end
  spawn()
end

local kitty_spawn = function(cmd)
  local os_wins = vim.json.decode(vim.system({ 'kitten', '@', 'ls' }):wait().stdout)
  local os_win = vim.iter(os_wins):find(function(w) return w.wm_class == 'kitty-rofi' end)
  local winid = tostring(assert(os_win.tabs[1].id))
  local obj
  obj = vim
    .system({
      'kitten',
      '@',
      'launch',
      '--dont-take-focus',
      -- '--type=tab',
      '--type=background',
      '--match',
      'id:' .. winid,
      '--',
      cmd,
    })
    :wait()
  assert(obj.code == 0, obj.stderr)
end

local spawn = function()
  if pcall(require, 'ffi') then return pty_spawn(vim.fn.exepath('nvim')) end

  if false and vim.env.KITTY_LISTEN_ON then return kitty_spawn(vim.fn.exepath('nvim')) end
  return _spawn({ vim.fn.exepath('nvim'), '--headless' })
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
    _ctor = function()
      local p = require('fzf-lua.previewer.fzf').cmd_async:extend()
      local utils = require('fzf-lua-extra.utils')
      function p:cmdline(_)
        return FzfLua.shell.stringify_cmd(function(items, lines, columns)
          self._last_query = items[2] or ''
          local path = parse_entry(items[1])
          if not path then return 'true' end
          local tmpfile = vim.fn.tempname()
          local filelines = utils.center_message({ 'This instance seems headless' }, lines, columns)
          vim.fn.writefile(filelines, tmpfile)
          if not pcall(remote_exec, path, 'nvim__screenshot', tmpfile) then
            vim.schedule(function() FzfLua.utils.fzf_winobj():SIGWINCH({}) end)
          end
          return 'cat ' .. tmpfile
        end, self.opts, '{} {q}')
      end
      return p
    end,
  },
  _resume_reload = true, -- avoid list contain killed server unhide
  keymap = { fzf = { resize = 'refresh-preview' } },
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
  require('fzf-lua').fzf_exec(function(cb)
    vim.defer_fn(function() f(cb) end, 50) -- wait for spawn/remote_exec?
  end, opts)
end
