---@type fzf-lua.config.Base|{}
local __DEFAULT__ = {
  previewer = { _ctor = function() return require('fzf-lua-extra.previewers').gitignore end },
  api_root = 'gitignore/templates',
  json_key = 'source',
  filetype = 'gitignore',
  winopts = { preview = { hidden = true } },
  _actions = function()
    local utils = require('fzf-lua-extra.utils')
    ---@type fzf-lua.config.Actions
    return {
      -- TODO:
      ['enter'] = function(selected, opts)
        local root = vim.fs.root(0, '.git')
        if not root then error('Not in a git repo') end
        local path = root .. '/.gitignore'
        if vim.uv.fs_stat(path) then
          local confirm = vim.fn.confirm('Override?', '&Yes\n&No')
          if confirm ~= 1 then return end
        end
        ---@type string
        local filetype = assert(selected[1])
        utils.gh_cache(opts.api_root .. '/' .. filetype, function(_, json)
          ---@type string
          local content = assert(json.source)
          utils.write_file(path, content)
          vim.cmd.edit(path)
        end)
      end,
    }
  end,
}

return function(opts)
  assert(__DEFAULT__)
  local utils = require('fzf-lua-extra.utils')
  local contents = function(fzf_cb)
    utils.gh_cache(opts.api_root, function(_, json)
      vim.iter(json):each(function(item) fzf_cb(item) end)
      fzf_cb()
    end)
  end
  return require('fzf-lua.core').fzf_exec(contents, opts)
end
