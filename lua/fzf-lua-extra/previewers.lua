local M = {}

local previewer = require('fzf-lua.previewer.builtin')
local utils = require('fzf-lua-extra.utils')
local fs = vim.fs

---@param _self fzf-lua.previewer.Gitignore
---@param content string[]
local preview_with = vim.schedule_wrap(function(_self, content)
  local tmpbuf = _self:get_tmp_buffer()
  vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, content)
  if _self.filetype then vim.bo[tmpbuf].filetype = _self.filetype end
  _self:set_preview_buf(tmpbuf)
  _self.win:update_preview_scrollbar()
end)

local github_raw_url = function(url, filepath)
  return url:gsub('github.com', 'raw.githubusercontent.com'):gsub('%.git$', '')
    .. '/master/'
    .. filepath
end

---@enum plugin_type
local p_type = {
  LOCAL = 1, -- local module
  UNINS_GH = 2, -- uninstall, url is github
  UNINS_NO_GH = 3, -- uninstall, not github
  INS_MD = 4, -- installed, readme found
  INS_NO_MD = 5, -- installed, readme not found
}

-- Helper to check for README variants
local function find_readme(dir)
  local readme_names = {
    'README.md',
    'readme.md',
    'Readme.md',
    'README.markdown',
    'readme.markdown',
    'Readme.markdown',
    'README',
    'readme',
    'Readme',
  }
  for name, type in fs.dir(dir) do
    if type == 'file' then
      for _, rname in ipairs(readme_names) do
        if name:lower() == rname:lower() then return fs.joinpath(dir, name) end
      end
    end
  end
  return nil
end

---@param entry_str string
---@return LazyPlugin
local parse_entry = function(_, entry_str)
  local slices = vim.split(entry_str, '/')
  local name = assert(slices[#slices])
  return assert(utils.get_lazy_plugins()[name])
end

-- item can be a fullname or just a plugin name
---@param plugin LazyPlugin plugin spec
---@return plugin_type, any
local parse_plugin_type = function(_, plugin)
  local dir = plugin.dir

  -- clear preview buf?
  if not vim.uv.fs_stat(dir) then
    if not plugin.url then return p_type.LOCAL end
    if plugin.url:match('github') then return p_type.UNINS_GH end
    return p_type.UNINS_NO_GH
  end

  -- README check
  local readme_path = find_readme(dir)
  if readme_path then return p_type.INS_MD, readme_path end

  return p_type.INS_NO_MD
end

M.lazy = previewer.base:extend()

function M.lazy:new(o, opts, fzf_win)
  M.lazy.super.new(self, o, opts, fzf_win)
  -- self.filetype = 'man'
  self.cmd = o.cmd or 'man -c %s | col -bx'
  self.cmd = type(self.cmd) == 'function' and self.cmd() or self.cmd

  -- lazy_builtin.super.new(self, o, op, fzf_win)
  self.ls_cmd = 'ls -lh'
  return self
end

function M.lazy:populate_preview_buf(entry_str)
  local plugin = parse_entry(self, entry_str)
  local t, data = parse_plugin_type(self, plugin)

  ---@type table<plugin_type, string|fun():string>
  local handlers = {
    [p_type.LOCAL] = function()
      local path = vim.fn.stdpath('config') .. '/lua/' .. plugin.dir .. '.lua'
      if path then return ('cat %s'):format(path) end
      return 'echo Local module!'
    end,

    [p_type.UNINS_GH] = function()
      return ('echo "> Not Installed (fetch from github)!\n" && curl -sL %s && curl -sL %s'):format(
        github_raw_url(plugin.url, 'README.md'),
        github_raw_url(plugin.url, 'readme.md')
      )
    end,

    [p_type.UNINS_NO_GH] = 'echo "Not Installed (not github)"!',

    [p_type.INS_MD] = ('cat %s'):format(data),

    [p_type.INS_NO_MD] = ('%s %s'):format(self.ls_cmd, plugin.dir),
  }

  local handler = handlers[t]
  if not handler then return end
  local cmd = type(handler) == 'function' and handler() or handler
  if t == p_type.INS_MD or t == p_type.UNINS_GH then
    self.filetype = 'markdown'
  elseif t == p_type.LOCAL then
    self.filetype = 'lua'
  end

  utils.arun(function()
    local obj = utils.run({ 'sh', '-c', cmd })
    local content = vim.split(obj.stdout or '', '\n')
    preview_with(self, content)
  end)
end

---@class fzf-lua.previewer.Gitignore: fzf-lua.previewer.Builtin
---@field super fzf-lua.previewer.Builtin
---@field api_root string
---@field filetype string
---@field json_key string
M.gitignore = previewer.buffer_or_file:extend()

function M.gitignore:new(o, opts)
  M.gitignore.super.new(self, o, opts)
  self.api_root = opts.api_root
  self.filetype = opts.filetype
  self.json_key = opts.json_key
  return self
end

function M.gitignore:populate_preview_buf(entry_str)
  utils.arun(function()
    local route = fs.joinpath(self.api_root, entry_str)
    local json = utils.gh(route)
    ---@type string
    local content = assert(json[self.json_key])
    preview_with(self, vim.split(content, '\n'))
  end)
end

return M
