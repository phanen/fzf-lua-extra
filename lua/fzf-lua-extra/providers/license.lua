local utils = require('fzf-lua-extra.utils')
local fn, uv = vim.fn, vim.uv

return function(opts)
  local default = {
    previewer = { _ctor = function() return require('fzf-lua-extra.previewers').gitignore end },
    api_root = 'licenses',
    json_key = 'body',
    filetype = 'text',
    actions = {
      ---@param selected string[]
      ['enter'] = function(selected)
        local root = vim.fs.root(0, '.git')
        if not root then error('Not in a git repo') end
        local path = vim
          .iter {
            root .. '/License',
            root .. '/license',
            root .. '/LICENSE',
          }
          :find(uv.fs_stat)

        if path and fn.confirm('Override?', '&Yes\n&No') ~= 1 then return end
        local license = assert(selected[1])
        utils.gh_cache(opts.api_root .. '/' .. license, function(_, json)
          ---@type string
          local content = assert(json.body)
          utils.write_file(path, content)
          vim.cmd.edit(path)
        end)
      end,
    },
  }
  opts = vim.tbl_deep_extend('force', default, opts or {})
  local contents = function(fzf_cb)
    utils.gh_cache(opts.api_root, function(_, json)
      vim.iter(json):each(function(item) fzf_cb(item.key) end)
      fzf_cb()
    end)
  end
  return require('fzf-lua.core').fzf_exec(contents, opts)
end
