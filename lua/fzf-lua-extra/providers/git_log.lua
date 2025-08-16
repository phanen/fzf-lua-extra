-- --grep=a -S=b
return function()
  local q ---@type string?
  local pager = vim.fn.executable('delta') == 1 and ('delta --%s'):format(vim.o.bg) or nil
  local bpstart = '\27[200~'
  local bpend = '\27[201~'
  return require('fzf-lua').fzf_live(function(s)
    ---@type string
    q = s[1]
    local cmd = [[git log --color --pretty=format:"%C(yellow)%h%Creset %Cgreen(%cs)%Creset %s %Cblue<%an>%Creset" ]]
      .. q
    return cmd
  end, {
    winopts = {
      on_create = function(e)
        vim.keymap.set('t', '<c-r>#', function()
          local altfile = vim.fn.expand('#')
          local root = assert(vim.fs.root(0, '.git'))
          altfile = assert(vim.fs.relpath(root, altfile))
          vim.api.nvim_chan_send(vim.bo.channel, bpend .. altfile .. bpstart)
        end, { buffer = e.bufnr })
      end,
    },
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
  })
end
