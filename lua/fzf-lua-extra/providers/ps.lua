local utils = require 'fzf-lua.utils'
local shell = require 'fzf-lua.shell'
local core = require 'fzf-lua.core'
local libuv = require 'fzf-lua.libuv'

return function(opts)
  local cmd
  if vim.fn.executable('ps') == 1 then
    -- cmd = 'ps -ef'
    -- or use libuv to parse procfs...
    cmd = 'ps --sort=-pid -eo pid,ppid,cmd'
  else
    utils.warn("No executable 'ps' (https://gitlab.com/procps-ng/procps)")
    return
  end

  -- local exec_lua = function(_) return _ end
  opts = vim.tbl_deep_extend('force', {
    cmd = cmd,
    ps_preview_cmd = 'ps --no-headers -wwo cmd',
    -- requires_processing = true,
    -- multiprocess = true,
    -- can use TSInjector for bash line maybe
    -- __mt_transform = exec_lua [[return function(e) return e end]],
    fzf_opts = {
      ['--ansi'] = true,
      ['--header-lines'] = 1,
      ['--color'] = 'fg:dim,nth:regular',
      ['--multi'] = true,
      ['--no-multi'] = false,
      -- ['--nth'] = '-1',
      -- ['--track'] = true,
    },
    keymap = {
      fzf = {
        ['click-header'] = utils.fzf_version()[2] > 0.59
            and [[transform-nth(echo "$FZF_CLICK_HEADER_NTH")+transform-prompt(echo "$FZF_CLICK_HEADER_WORD> ")]]
          or nil,
        -- cursorhold? top? https://github.com/junegunn/fzf/issues/1211
        ['ctrl-r'] = ('reload:%s'):format(cmd),
        change = ('reload:%s'):format(cmd),
      },
    },
    previewer = {
      _ctor = function()
        local p = require('fzf-lua.previewer.fzf').cmd_async:extend()
        function p:fzf_delimiter() return '\\s+' end
        function p:cmdline(o)
          o = o or {}
          local act = shell.raw_preview_action_cmd(function(items)
            local pid = (items[1]):match('^%s*(%d+)')
            return opts.ps_preview_cmd .. ' ' .. pid
          end, '{}', self.opts.debug)
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
      ['ctrl-x'] = {
        fn = function(selected)
          local pids = vim.tbl_map(function(s) return tonumber(s:match('^%s*(%d+)')) end, selected)
          local sig = require('fzf-lua.utils').input('signal: ', 'sigkill')
          if not sig then return end
          vim.tbl_map(function(_pid) libuv.process_kill(_pid, sig) end, pids)
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
  local contents = core.mt_cmd_wrapper(opts)
  return core.fzf_exec(contents, opts)
end
