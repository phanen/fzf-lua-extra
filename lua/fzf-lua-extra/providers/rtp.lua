---@class fle.config.Rtp: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = {
    cmd = 'eza --color=always --tree --level=3 --icons=always',
    _ctor = require('fzf-lua.previewer').fzf.cmd,
  },
  _fmt = { from = function(e, _) return vim.fn.expand(e) end },
  actions = {
    ['enter'] = function(sel) require('fzf-lua-extra.utils').chdir(sel[1]) end,
    ['ctrl-l'] = function(sel) FzfLua.files { cwd = sel[1] } end,
    ['ctrl-n'] = function(sel) FzfLua.live_grep_native { cwd = sel[1] } end,
  },
}

return function(opts)
  assert(__DEFAULT__)
  local clear = FzfLua.utils.ansi_escseq.clear
  local clear_pat = vim.pesc(clear)
  local contents = vim
    .iter(vim.api.nvim_list_runtime_paths())
    :map(require('fzf-lua-extra.utils').format_env)
    :map(
      ---@param path string
      ---@return string
      function(path) -- hack...
        local cleared = (path:gsub(clear_pat, ''))
        return cleared and cleared .. clear or path
      end
    )
    :totable()

  return FzfLua.fzf_exec(contents, opts)
end
