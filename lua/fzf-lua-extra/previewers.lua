local M = {}

local previewer = require('fzf-lua.previewer.builtin')
local utils = require('fzf-lua-extra.utils')
---@diagnostic disable-next-line: unused
local api, fn, fs, uv = vim.api, vim.fn, vim.fs, vim.uv

---@param self fzf-lua.previewer.BufferOrFile
---@param entry table
---@param content string[]
local preview_with = vim.schedule_wrap(function(self, entry, content)
  local bufnr = self:get_tmp_buffer()
  api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  self:set_preview_buf(bufnr)
  self:preview_buf_post(entry)
end)

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

-- item can be a fullname or just a plugin name
---@param plugin LazyPlugin|{} plugin spec
---@return plugin_type, string?
local parse_plugin_type = function(_, plugin)
  local dir = assert(plugin.dir)

  -- clear preview buf?
  if not uv.fs_stat(dir) then
    if not plugin.url then return p_type.LOCAL end
    if plugin.url:match('github') then return p_type.UNINS_GH end
    return p_type.UNINS_NO_GH
  end

  -- README check
  local readme_path = find_readme(dir)
  if readme_path then return p_type.INS_MD, readme_path end

  return p_type.INS_NO_MD
end

---@class fle.previewer.Lazy: fzf-lua.previewer.BufferOrFile
---@field super fzf-lua.previewer.BufferOrFile
M.lazy = previewer.buffer_or_file:extend()

function M.lazy:new(...)
  self.super.new(self, ...)
  self.bcache = {}
  return self
end

---@diagnostic disable-next-line: unused
---@param entry_str string
---@return LazyPlugin
function M.lazy:parse_entry(entry_str)
  local slices = vim.split(entry_str, '/')
  local name = assert(slices[#slices])
  return assert(utils.get_lazy_plugins()[name])
end

---@diagnostic disable-next-line: unused
---@param entry LazyPlugin
function M.lazy:key_from_entry(entry) return entry.name end

function M.lazy:populate_preview_buf(entry_str)
  local plugin = self:parse_entry(entry_str)
  local t, data = parse_plugin_type(self, plugin)
  local win = api.nvim_win_get_config(self.win.preview_winid)
  local center = function(msg) return utils.center_message(msg, win.height, win.width) end
  ---@type table<plugin_type, string|(async fun():string[], string?)>
  local handlers = {
    [p_type.UNINS_GH] = function()
      local repo = assert(plugin[1] or plugin.url)
      repo = assert(repo:match('[^/]+/.+'))
      local res = utils.gh({ endpoint = fs.joinpath('repos', repo, 'readme') })
      local content = res.content or ''
      content = (content:gsub('[\n\r]', ''))
      if res.encoding == 'base64' then -- TODO: error now never bubble up in vim._async..
        content = vim.F.npcall(vim.base64.decode, content)
      else
        error('unimplemented encoding: ' .. res.encoding)
      end
      if not content then return center({ 'Failed to decode base64 content!' }), 'markdown' end
      local lines = vim.split(content, '\n')
      lines = vim.list_extend({ 'Not Installed (fetch from github)' }, lines)
      return lines, 'markdown'
    end,
    [p_type.UNINS_NO_GH] = function()
      return center({ 'echo "Not Installed (not github)"!' }), 'markdown'
    end,
    [p_type.INS_MD] = function()
      local content = utils.read_file(assert(data))
      local lines = content and vim.split(content, '\n') or center({ 'Failed to read README!' })
      return lines, 'markdown'
    end,
    ('cat %s'):format(data),
    [p_type.INS_NO_MD] = function()
      return vim.split(utils.run({ 'ls', '-lh', plugin.dir }).stdout or '', '\n'), 'dirpager'
    end,
  }
  local handler = handlers[t]
  if not handler then return end
  utils.arun(function()
    local lines, filetype = handler()
    local entry = vim.deepcopy(plugin) ---@type LazyPlugin|{}
    entry.path, entry.filetype = '', filetype
    preview_with(self, entry, lines)
  end)
end

---@class fle.previewer.Gitignore: fzf-lua.previewer.BufferOrFile
---@field super fzf-lua.previewer.BufferOrFile
---@field endpoint string
---@field filetype string
---@field json_key string
M.gitignore = previewer.buffer_or_file:extend()

function M.gitignore:new(o, opts)
  M.gitignore.super.new(self, o, opts)
  self.endpoint = opts.endpoint
  self.filetype = opts.filetype
  self.json_key = opts.json_key
  return self
end

function M.gitignore:populate_preview_buf(entry_str)
  utils.arun(function()
    local endpoint = fs.joinpath(self.endpoint, entry_str)
    local json = utils.gh({ endpoint = endpoint })
    local content = assert(json[self.json_key]) ---@type string
    preview_with(self, { path = '', filetype = self.filetype }, vim.split(content, '\n'))
  end)
end

return M
