local utils = require('fzf-lua-extra.utils')
local fn, uv = vim.fn, vim.uv
local api_root = 'licenses'

local license_path = function(root)
  local path = vim
    .iter({ 'LICENSE', 'license', 'License' })
    :map(function(license) return vim.fs.joinpath(root, license) end)
    :find(uv.fs_stat)
  if path and fn.confirm('Override?', '&Yes\n&No') ~= 1 then return end
  return path or vim.fs.joinpath(root, 'LICENSE')
end

---@class fle.config.License: fzf-lua.config.Base
local __DEFAULT__ = {
  previewer = { _ctor = function() return require('fzf-lua-extra.previewers').gitignore end },
  api_root = api_root,
  json_key = 'body',
  filetype = 'text',
  actions = {
    ---@param selected string[]
    ['enter'] = function(selected)
      local root = vim.fs.root(0, '.git')
      if not root then error('Not in a git repo') end
      if not selected[1] then return end
      local path = license_path(root)
      if not path then return end
      local license = assert(selected[1])
      utils.arun(function()
        local json = utils.gh(api_root .. '/' .. license)
        ---@type string
        local content = assert(json.body)
        utils.write_file(path, content)
        vim.cmd.edit(path)
      end)
    end,
  },
}

return function(opts)
  assert(__DEFAULT__)
  opts = vim.tbl_deep_extend('force', __DEFAULT__, opts or {})
  local contents = function(fzf_cb)
    utils.arun(function()
      local json = utils.gh(opts.api_root)
      vim.iter(json):each(function(item) fzf_cb(item.key) end)
      fzf_cb()
    end)
  end
  return FzfLua.fzf_exec(contents, opts)
end
