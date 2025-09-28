-- --grep=a -S=b
return function()
  local q ---@type string?
  local pager = vim.fn.executable('delta') == 1 and ('delta --%s'):format(vim.o.bg) or nil
  local opts = {
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
      end,
    },
    query = ' --grep=',
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
    keymap = {
      fzf = {
        start = 'beginning-of-line',
        ['alt-j'] = 'down-match',
        ['alt-k'] = 'up-match',
        ['ctrl-x'] = 'toggle-raw',
      },
    },
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
    -- fzf_opts = { ['--raw'] = true },
  }
  opts._fzf_cli_args = {
    '--bind='
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
      ),
  }
  return require('fzf-lua').fzf_exec('true', opts)
end
