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

return function(opts)
  local scrshot = '/tmp/screenshot'
  vim.fn.system({ 'touch', scrshot })
  local default = {
    previewer = {
      -- TODO: should reload on preview fail
      cmd = [[nvim --clean --headless --remote-expr 'nvim__screenshot("/tmp/screenshot")' --server {} && cat /tmp/screenshot]],
      _ctor = require('fzf-lua.previewer').fzf.cmd,
    },
    actions = {
      ['enter'] = vim.schedule_wrap(function(sel) vim.cmd.connect(sel[1]) end),
      ['alt-n'] = {
        fn = vim.schedule_wrap(function() spawn({ vim.fn.exepath('nvim'), '--headless' }) end),
        reload = true,
      },
    },
  }
  opts = vim.tbl_deep_extend('force', default, opts or {})
  opts._resume_reload = true -- avoid list contain killed server unhide
  require('fzf-lua').fzf_exec(function(cb)
    vim
      .iter(vim.fn.serverlist({ peer = true }))
      :filter(
        function(e) return not e:match('fzf%-lua') and not vim.tbl_contains(vim.fn.serverlist(), e) end
      )
      :each(cb)
  end, opts)
end
