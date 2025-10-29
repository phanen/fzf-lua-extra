local api_root = 'gitignore/templates'

---@class fle.config.Gitignore: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = { _ctor = function() return require('fzf-lua-extra.previewers').gitignore end },
  api_root = api_root,
  json_key = 'source',
  filetype = 'gitignore',
  winopts = { preview = { hidden = true } },
  _actions = function()
    local utils = require('fzf-lua-extra.utils')
    ---@type fzf-lua.config.Actions
    return {
      -- TODO:
      ['enter'] = function(selected)
        local root = vim.fs.root(0, '.git')
        if not root then error('Not in a git repo') end
        local path = root .. '/.gitignore'
        if vim.uv.fs_stat(path) then
          local confirm = vim.fn.confirm('Override?', '&Yes\n&No')
          if confirm ~= 1 then return end
        end
        ---@type string
        local filetype = assert(selected[1])
        local route = vim.fs.joinpath(api_root, filetype)
        utils.arun(function()
          local json = utils.gh(route)
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
    utils.arun(function()
      local json = utils.gh(opts.api_root)
      vim.iter(json):each(fzf_cb)
      fzf_cb()
    end)
  end
  return FzfLua.fzf_exec(contents, opts)
end
