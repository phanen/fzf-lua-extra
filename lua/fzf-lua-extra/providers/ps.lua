---@param opts table?
---@return any
return function(opts)
  local utils = require 'fzf-lua.utils'
  if vim.fn.executable('ps') ~= 1 then
    utils.warn("No executable 'ps' (https://gitlab.com/procps-ng/procps)")
    return
  end
  local cmd = 'ps --sort=-pid -eo pid,ppid,cmd'
  ---@generic T
  ---@param _ T
  ---@return T
  local exec_lua = function(_) return _ end
  opts = require('fzf-lua.config').normalize_opts(opts or {}, {})
  if not opts then return end
  opts = vim.tbl_deep_extend('force', {
    cmd = cmd,
    ps_preview_cmd = 'ps --no-headers -wwo cmd',
    requires_processing = true,
    -- debug = true,
    multiprocess = true,
    fn_preprocess = exec_lua [[
      local utils = FzfLua.utils
      _G.bold = utils.ansi_codes.bold
      _G.blue = utils.ansi_codes.blue
      _G.green = utils.ansi_codes.green
      _G.magenta = utils.ansi_codes.magenta
      _G.hl_cmd = function(cmd)
        return cmd
      end
    ]],
    fn_transform = exec_lua [[
      return function(e)
        if e:match('^%s*PID') then
          local sep1, pid, sep2, ppid, sep3, cmd = e:match('^(%s*)(%S+)(%s*)(%S+)(%s*)(%S+)$')
          return ('%s%s%s%s%s%s'):format(sep1, bold(pid), sep2, bold(ppid), sep3, bold(cmd))
        end
        local sep1, pid, sep2, ppid, sep3, cmd = e:match('^(%s*)(%d+)(%s*)(%d+)(%s*)(.*)$')
        return ('%s%s%s%s%s%s'):format(sep1, magenta(pid), sep2, blue(ppid), sep3, hl_cmd(cmd))
      end
    ]],
    fzf_opts = {
      ['--ansi'] = true,
      ['--header-lines'] = 1,
      ['--multi'] = true,
      ['--no-multi'] = false,
      -- ['--nth'] = '-1',
      -- ['--track'] = true,
      -- ['--no-hscroll'] = true,
    },
    fzf_colors = {
      ['fg'] = 'dim',
      ['nth'] = 'regular',
      ['hl+'] = '-1:reverse',
      ['hl'] = '-1:reverse',
    },
    keymap = {
      fzf = {
        ['click-header'] = utils.has(opts, 'fzf', { 0, 60 })
            and [[transform-nth(echo "$FZF_CLICK_HEADER_NTH")+transform-prompt(echo "$FZF_CLICK_HEADER_WORD> ")]]
          or nil,
      },
    },
    previewer = {
      _ctor = function()
        ---@type fzf-lua.previewer.Builtin
        local p = require('fzf-lua.previewer.fzf').cmd_async:extend()
        -- TODO:
        ---@diagnostic disable-next-line: inject-field
        function p:fzf_delimiter() return '\\s+' end
        function p:cmdline(o)
          o = o or {}
          local act = FzfLua.shell.stringify_cmd(function(items)
            local pid = (items[1]):match('^%s*(%d+)')
            if not pid then return 'echo no preview' end
            return opts.ps_preview_cmd .. ' ' .. pid
          end, self.opts, '{}')
          return act
        end
        return p
      end,
    },
    -- inject treesitter? but often truncated... seems useless
    -- upstream currently can only handle file entry
    -- _treesitter = true,
    winopts = {
      preview = { wrap = true },
      -- treesitter = true,
    },
    actions = {
      -- cursorhold? top? https://github.com/junegunn/fzf/issues/1211
      ['ctrl-r'] = { fn = function() end, reload = true },
      change = { fn = function() end, reload = true },
      ['ctrl-x'] = {
        ----@param selected string[]
        fn = function(selected)
          local pids = vim.tbl_map(
            ---@param s string
            ---@return integer
            function(s) return tonumber(s:match('^%s*(%d+)')) end,
            selected
          )
          local sig = require('fzf-lua.utils').input('signal: ', 'sigkill')
          if not sig then return end
          vim.tbl_map(
            ---@param _pid integer
            function(_pid) FzfLua.libuv.process_kill(_pid, sig) end,
            pids
          )
        end,
        field_index = '{+}',
        reload = true,
      },
      ['ctrl-s'] = { -- man ps | nvim +Man! +'norm! G' +'?STANDARD FORMAT SPECIFIERS'
        fn = function()
          local ps_preview_cmd = require('fzf-lua.utils').input('preview: ', opts.ps_preview_cmd)
          if not ps_preview_cmd then return end
          opts.ps_preview_cmd = ps_preview_cmd
        end,
        exec_silent = true,
        postfix = 'refresh-preview',
      },
    },
  }, opts or {})
  return FzfLua.core.fzf_exec(cmd, opts)
end
