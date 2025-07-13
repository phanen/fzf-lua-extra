return function(opts)
  local scrshot = '/tmp/screenshot'
  vim.fn.system({ 'touch', scrshot })
  local default = {
    previewer = {
      cmd = [[nvim --clean --headless --remote-expr 'nvim__screenshot("/tmp/screenshot")' --server {}; cat /tmp/screenshot]],
      _ctor = require('fzf-lua.previewer').fzf.cmd,
    },
    actions = { ['enter'] = function(sel) vim.cmd.connect(sel[1]) end },
  }
  opts = vim.tbl_deep_extend('force', default, opts or {})
  local list = vim
    .iter(vim.fn.serverlist())
    :filter(function(e) return not e:match('fzf%-lua') end)
    :totable()
  require('fzf-lua').fzf_exec(list, opts)
end
