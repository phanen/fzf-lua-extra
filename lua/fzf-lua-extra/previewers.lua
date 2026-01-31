local M = {}

local previewer = require('fzf-lua.previewer.builtin')
local utils = require('fzf-lua-extra.utils')
---@diagnostic disable-next-line: unused
local api, fn, fs, uv = vim.api, vim.fn, vim.fs, vim.uv

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

---@diagnostic disable-next-line: unused
---@param entry_str string
---@param cb function
function M.lazy:parse_entry(entry_str, cb)
  local owner = entry_str:match('^%S+')
  if not owner then return end
  local slices = vim.split(owner, '/')
  local name = assert(slices[#slices])
  local plugin = utils.get_lazy_plugins()[name]
  if not plugin then return end
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
    [p_type.UNINS_NO_GH] = function() return center({ 'Not Installed (not github)!' }), 'markdown' end,
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
  -- no raise error
  utils.arun(function()
    local lines, filetype = handler()
    local entry = vim.deepcopy(plugin) ---@type LazyPlugin|{}
    entry.path, entry.filetype = '', filetype
    cb({ name = entry.name, filetype = filetype, content = lines })
  end)
end

---@diagnostic disable-next-line: unused
---@param entry LazyPlugin
function M.lazy:key_from_entry(entry) return entry.name end

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

function M.gitignore:parse_entry(entry_str, cb)
  utils.arun(function()
    local endpoint = fs.joinpath(self.endpoint, entry_str)
    local json = utils.gh({ endpoint = endpoint })
    local content = assert(json[self.json_key]) ---@type string
    cb({ key = entry_str, filetype = self.filetype, content = vim.split(content, '\n') })
  end)
end

---@diagnostic disable-next-line: unused
function M.gitignore:key_from_entry(entry) return entry.key end

return M
