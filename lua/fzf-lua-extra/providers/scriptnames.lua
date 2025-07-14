return function(opts)
  local default = {
    previewer = 'builtin',
    _fmt = { from = function(e, _) return vim.fn.expand(e) end },
    winopts = { preview = { hidden = 'nohidden' } },
    file_icons = true,
    actions = { ['enter'] = require('fzf-lua.actions').file_sel_to_qf },
  }
  opts = vim.tbl_deep_extend('force', default, opts or {})

  local utils = require('fzf-lua').utils
  local green = utils.ansi_codes.green
  local blue = utils.ansi_codes.blue
  local clear_pat = vim.pesc(utils.ansi_escseq.clear)
  local contents = vim
    .iter(vim.fn.getscriptinfo())
    :map(function(s) return s.name end)
    :map(require('fzf-lua-extra.utils').replace_with_envname)
    :map(function(path)
      local _, off = path:find(clear_pat)
      off = off or 0
      return path:match('%.vim$') and (path:sub(0, off) .. green(path:sub(off + 1, -1)))
        or path:match('%.lua$') and (path:sub(0, off) .. blue(path:sub(off + 1, -1)))
    end)
    :totable()

  return require('fzf-lua.core').fzf_exec(contents, opts)
end
