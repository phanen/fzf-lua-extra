local __DEFAULT__ = {
  previewer = 'builtin',
  _treesitter = function(line) return line:match('(.-):?(%d+)[: ].-:(.+)$') end,
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
}

--- @param buf_or_filename string|integer
--- @param hunks Gitsigns.Hunk.Hunk[]
--- @param cb function
--- @param opts table
local function cb_hunks(buf_or_filename, hunks, cb, opts)
  local utils = require('fzf-lua.utils')
  for _, hunk in ipairs(hunks) do
    local hl = hunk.type == 'add' and 'Added' or hunk.type == 'delete' and 'Removed' or 'Changed'
    local kind = hunk.type == 'add' and '+' or hunk.type == 'delete' and '-' or '~'
    local header = ('-%s%s/+%s%s'):format(
      hunk.removed.start,
      hunk.removed.count ~= 1 and ',' .. tostring(hunk.removed.count) or '',
      hunk.added.start,
      hunk.added.count ~= 1 and ',' .. tostring(hunk.added.count) or ''
    )
    local text = ('%s(%s): %s'):format(
      utils.ansi_from_hl(hl, kind),
      utils.ansi_from_hl(hl, header),
      hunk.added.lines[1] or hunk.removed.lines[1]
    )

    cb(require('fzf-lua.make_entry').lcol({
      bufnr = type(buf_or_filename) == 'number' and buf_or_filename or nil,
      filename = type(buf_or_filename) == 'string' and buf_or_filename or nil,
      lnum = hunk.added.start,
      text = text,
    }, opts))
  end
  cb()
end

return function(opts)
  assert(__DEFAULT__)
  if not pcall(require, 'gitsigns') then return end
  local config = require('gitsigns.config').config
  local git = require('gitsigns.git')
  local async = require('gitsigns.async')
  local uv = vim.uv or vim.loop
  local run_diff = require('gitsigns.diff')
  local util = require('gitsigns.util')
  local a = function()
    local repo = git.Repo.get((assert(uv.cwd())))
    if not repo then return end
    local func = async.create(1, function(cb)
      for _, f in ipairs(repo:files_changed(config.base)) do
        local f_abs = repo.toplevel .. '/' .. f
        local stat = uv.fs_stat(f_abs)
        if stat and stat.type == 'file' then
          ---@type string
          local obj
          if config.base and config.base ~= ':0' then
            obj = config.base .. ':' .. f
          else
            obj = ':0:' .. f
          end
          local a = repo:get_show_text(obj)
          async.schedule()
          local hunks = run_diff(a, util.file_lines(f_abs))
          async.schedule()
          ---@diagnostic disable-next-line: param-type-mismatch
          cb_hunks(f_abs, hunks, cb, opts)
        end
      end
    end)
    async.schedule()
    require('fzf-lua').fzf_exec(func, opts)
  end
  async.run(a):raise_on_error()
end
