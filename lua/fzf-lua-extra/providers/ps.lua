local utils = require 'fzf-lua.utils'
local exec_lua = function(_) return _ end

---@class fle.config.Ps: fzf-lua.config.Base
local __DEFAULT__ = {
  cmd = 'ps --sort=-pid -eo pid,ppid,cmd',
  ps_preview_cmd = 'ps --no-headers -wwo cmd',
  requires_processing = true,
  -- debug = true,
  multiprocess = true,
  fn_preprocess = exec_lua [[return function(e)
      local utils = FzfLua.utils
      _G.bold = utils.ansi_codes.bold
      _G.red = utils.ansi_codes.red
      _G.green = utils.ansi_codes.green
      _G.magenta = utils.ansi_codes.magenta
      _G.hl_cmd = function(cmd) return cmd end
    end]],
  fn_transform = exec_lua [[return function(e)
        if e:match('^%s*PID') then
          local sep1, pid, sep2, ppid, sep3, cmd = e:match('^(%s*)(%S+)(%s*)(%S+)(%s*)(%S+)$')
          return ('%s%s%s%s%s%s'):format(sep1, bold(pid), sep2, bold(ppid), sep3, bold(cmd))
        end
        local sep1, pid, sep2, ppid, sep3, cmd = e:match('^(%s*)(%d+)(%s*)(%d+)(%s*)(.*)$')
        return ('%s%s%s%s%s%s'):format(sep1, magenta(pid), sep2, red(ppid), sep3, hl_cmd(cmd))
      end]],
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
  keymap = function(opts)
    return { -- TODO: emmylua bug, code action applied on wrong pos
      ---@diagnostic disable-next-line: assign-type-mismatch
      fzf = {
        ['click-header'] = utils.has(opts, 'fzf', { 0, 60 })
            and [[transform-nth(echo "$FZF_CLICK_HEADER_NTH")+transform-prompt(echo "$FZF_CLICK_HEADER_WORD> ")]]
          or nil,
      },
    }
  end,
  -- inject treesitter? but often truncated... seems useless
  -- upstream currently can only handle file entry
  _treesitter = function(line) return 'foo.sh', nil, line:match('%d+%s+%d+%s+(.*)') end,
  winopts = {
    preview = { wrap = true },
    -- treesitter = true,
  },
  previewer = {
    _ctor = function()
      ---@class fle.previewer.Ps: fzf-lua.previewer.Fzf
      ---@field opts fle.config.Ps
      local p = require('fzf-lua.previewer.fzf').cmd_async:extend()
      ---@diagnostic disable-next-line: unused
      function p:fzf_delimiter() return '\\s+' end
      function p:cmdline(_)
        return (
          FzfLua.shell.stringify_cmd(function(items)
            if not items[1] then return FzfLua.utils.shell_nop() end
            local pid = items[1]:match('^%s*(%d+)')
            if not pid then return 'echo no preview' end
            return self.opts.ps_preview_cmd .. ' ' .. pid
          end, self.opts, '{}')
        )
      end
      return p
    end,
  },
  ---@type fzf-lua.config.Actions
  actions = {
    -- cursorhold? top? https://github.com/junegunn/fzf/issues/1211
    ['ctrl-r'] = { fn = function() end, reload = true },
    change = { fn = function() end, reload = true },
    ['ctrl-x'] = {
      fn = function(selected)
        ---@type integer[]
        local pids = vim.tbl_map(function(s) return tonumber(s:match('^%s*(%d+)')) end, selected)
        local sig = require('fzf-lua.utils').input('signal: ', 'sigkill')
        if not sig then return end
        vim.tbl_map(function(_pid) FzfLua.libuv.process_kill(_pid, sig) end, pids)
      end,
      field_index = '{+}',
      reload = true,
    },
    ['ctrl-s'] = { -- man ps | nvim +Man! +'norm! G' +'?STANDARD FORMAT SPECIFIERS'
      fn = function(_, opts)
        local ps_preview_cmd = require('fzf-lua.utils').input('preview: ', opts.ps_preview_cmd)
        if not ps_preview_cmd then return end
        opts.ps_preview_cmd = ps_preview_cmd
      end,
      exec_silent = true,
      postfix = 'refresh-preview',
    },
  },
}

return function(opts)
  assert(__DEFAULT__)
  if vim.fn.executable('ps') ~= 1 then
    utils.warn("No executable 'ps' (https://gitlab.com/procps-ng/procps)")
    return
  end
  return FzfLua.fzf_exec(opts.cmd, opts)
end
