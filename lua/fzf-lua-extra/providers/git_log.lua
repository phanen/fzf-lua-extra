local pager ---@type string?
local q ---@type string?

---@type fzf-lua.config.Base|{}
local __DEFAULT__ = {
  winopts = {
    on_create = function(e)
      vim.keymap.set('t', '<c-r>#', function()
        local altfile = vim.fn.expand('#')
        local root = assert(vim.fs.root(vim.fn.expand('#'), '.git'))
        altfile = assert(vim.fs.relpath(root, altfile))
        local bpstart = '\27[200~'
        local bpend = '\27[201~'
        vim.api.nvim_chan_send(vim.bo.channel, bpstart .. altfile .. bpend)
      end, { buffer = e.bufnr })
      -- vim.keymap.set({ 't', 'n' }, '<Esc>', function()
      --   if not insert then FzfLua.hide() end
      --   vim.api.nvim_chan_send(vim.bo[e.bufnr].channel, '\x1b')
      -- end, { buffer = e.bufnr, nowait = true })
    end,
  },
  query = ' --grep=""',
  exec_empty_query = true,
  preview = {
    fn = function(s)
      ---@type string
      local h = vim.split(s[1], '%s')[1]
      if not h then return end
      ---@type string
      local S_args = q and q:match('%-S(%S+)')
      local cmd ---@type string
      if S_args then
        cmd = 'git grep --color ' .. S_args .. ' ' .. h
      else
        cmd = 'git show --color ' .. h
      end
      cmd = not pager and cmd or (cmd .. ' | ' .. pager)
      return cmd
    end,
    type = 'cmd',
  },
  keymap = function(opts)
    local s = FzfLua.shell.stringify_data2
    local insert = false
    local iOrN = function(a, b)
      return s(
        function(...)
          return insert and (type(a) == 'function' and a(...) or a)
            or (type(b) == 'function' and b(...) or b)
        end,
        opts,
        ''
      )
    end
    local toggle = function()
      insert = not insert
      return 'change-prompt:' .. (insert and '❯ ' or '[N]❯ ')
    end
    return {
      fzf = {
        j = ('transform:%s'):format(iOrN('put:j', 'down')),
        k = ('transform:%s'):format(iOrN('put:k', 'up')),
        u = ('transform:%s'):format(iOrN('put:d', 'half-page-down')),
        d = ('transform:%s'):format(iOrN('put:u', 'half-page-up')),
        i = ('transform:%s'):format(iOrN('put:i', toggle)),
        ['ctrl-/'] = ('transform:%s'):format(s(toggle, opts, '')),
        -- start = 'beginning-of-line',
        start = 'end-of-line+backward-char+change-prompt:' .. (insert and '❯ ' or '[N]❯ '),
        ['ctrl-j'] = ('transform:%s'):format(iOrN('down', 'down-match')),
        ['ctrl-k'] = ('transform:%s'):format(iOrN('up', 'up-match')),
        ['alt-j'] = 'down-match',
        ['alt-k'] = 'up-match',
        ['ctrl-x'] = 'toggle-raw',
        ['ctrl-w'] = 'backward-kill-word',
      },
    }
  end,
  actions = {
    enter = function(s)
      ---@type string
      local h = vim.split(s[1], '%s')[1]
      if not h then return end
      vim.cmd('Gedit ' .. h)
    end,
    ['ctrl-t'] = function(s)
      ---@type string
      local h = vim.split(s[1], '%s')[1]
      if not h then return end
      vim.cmd('Gtabedit ' .. h)
    end,
  },
  fzf_opts = { ['--raw'] = true },
}

-- --grep=a -S=b
return function(opts)
  assert(__DEFAULT__)
  pager = vim.fn.executable('delta') == 1 and ('delta --%s'):format(vim.o.bg) or nil
  opts._fzf_cli_args = opts._fzf_cli_args or {}
  ---@diagnostic disable-next-line: no-unknown
  opts._fzf_cli_args[#opts._fzf_cli_args + 1] = '--bind='
    .. require('fzf-lua.libuv').shellescape(
      'start,change:+transform:'
        .. FzfLua.shell.stringify_data(function(_q, _, _)
          q = _q[1]
          local cmd =
            [[git log --color --pretty=format:"%C(yellow)%h%Creset %Cgreen(%cs)%Creset %s %Cblue<%an>%Creset" ]]
          return ('reload(%s)+search:%s'):format(
            cmd .. (q:match('%-%-grep=.*$') or ''),
            q:match('(.*)%-%-grep=.*') or q or ''
          )
        end, opts, '{q}')
    )

  return require('fzf-lua').fzf_exec('true', opts)
end
