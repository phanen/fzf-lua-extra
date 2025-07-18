local M = {}

---@diagnostic disable-next-line: unused-local
local api, fn, uv, fs = vim.api, vim.fn, vim.uv, vim.fs

local root = fn.stdpath 'state' .. '/fzf-lua-extra'

M.zoxide_chdir = function(path)
  if fn.executable('zoxide') == 1 then vim.system { 'zoxide', 'add', path } end
  return api.nvim_set_current_dir(path)
end

---@param path string
---@param flag string?
---@return string?
M.read_file = function(path, flag)
  local fd = io.open(path, flag or 'r')
  if not fd then return nil end
  local content = fd:read('*a')
  fd:close()
  return content or ''
end

-- mkdir for file
local fs_file_mkdir = function(path)
  ---@type string[]
  local parents = {}
  vim.iter(fs.parents(path)):all(function(dir)
    local fs_stat = uv.fs_stat(dir)
    if not fs_stat then
      parents[#parents + 1] = dir
      return true
    end
    return false
  end)
  vim.iter(parents):rev():each(function(p) return uv.fs_mkdir(p, 493) end)
end

-- path should be normalized
---@param path string
---@param content string
---@param flag string?
---@return boolean
M.write_file = function(path, content, flag)
  if not uv.fs_stat(path) then fs_file_mkdir(path) end
  local fd = io.open(path, flag or 'w')
  if not fd then return false end
  if content then fd:write(content) end
  fd:close()
  return true
end

---@type fun(name: string?): { [string]: LazyPlugin }|LazyPlugin
M.get_lazy_plugins = (function()
  local plugins ---@type { [string]: LazyPlugin }
  return function(name)
    if not plugins then
      -- https://github.com/folke/lazy.nvim/blob/d3974346b6cef2116c8e7b08423256a834cb7cbc/lua/lazy/view/render.lua#L38-L40
      ---@module 'lazy.core.config'
      local cfg = package.loaded['lazy.core.config']
      if not cfg or not cfg.plugins then
        error('lazy.nvim is not loaded')
        return {}
      end
      ---@type LazyPlugin[]
      plugins = vim.tbl_deep_extend('keep', {}, cfg.plugins, cfg.to_clean, cfg.spec.disabled)
      -- kind="clean" seems not named in table
      for i, p in ipairs(plugins) do
        plugins[p.name] = p
        plugins[i] = nil
      end
    end
    if name then return plugins[name] end
    return plugins
  end
end)()

---github restful api
---@param route string
---@param cb fun(string, table)
---@return vim.SystemObj
local gh = function(route, cb)
  local cmd = fn.executable('gh') == 1 and { 'gh', 'api', route }
    or { 'curl', '-sL', 'https://api.github.com/' .. route }

  ---@param str string
  ---@return string, table
  local parse_gh_result = function(str)
    local ok, tbl = pcall(vim.json.decode, str)
    if not ok then --
      error(('Fail to parse json: ' .. str))
    end
    if tbl.message and tbl.message:match('API rate limit exceeded') then
      error('API error: ' .. tbl.message)
    end
    return str, tbl
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  return vim.system(cmd, function(obj)
    local stdout = assert(obj.stdout) -- no disabled stdout
    return cb(parse_gh_result(stdout))
  end)
end

---gh but use local cache first
---@param route string
---@param path string
---@param cb fun(str: string, tbl: table)
---@return vim.SystemObj?
local gh_cache = function(route, path, cb)
  if uv.fs_stat(path) then
    local str = assert(M.read_file(path))
    local ok, tbl = pcall(vim.json.decode, str)
    if not ok then error('Fail to parse json: ' .. str) end
    return cb(str, tbl)
  end
  -- TODO: this just a conditional cache...
  return gh(route, function(str, tbl)
    assert(M.write_file(path, str), 'Fail to write to cache path: ' .. path)
    cb(str, tbl)
  end)
end

---@param route string
---@param cb fun(str: string, tbl: table)
---@return vim.SystemObj?
M.gh_cache = function(route, cb)
  local path = root .. '/' .. route .. '.json'
  return gh_cache(route, path, cb)
end

---@param name string
---@return string
M.replace_with_envname = function(name)
  local xdg_config = vim.env.XDG_CONFIG_HOME ---@type string
  local xdg_state = vim.env.XDG_STATE_HOME ---@type string
  local xdg_cache = vim.env.XDG_CACHE_HOME ---@type string
  local xdg_data = vim.env.XDG_DATA_HOME ---@type string
  local vimruntime = vim.env.VIMRUNTIME ---@type string

  -- archlinux specific system-wide configs...
  local vimfile = '/usr/share/vim/vimfiles'
  vim.env.VIMFILE = vimfile
  -- note: lazy root may locate in xdg_data
  -- so it should be mached before data_home
  local lazy = vim.tbl_get(package.loaded['lazy.core.config'] or {}, 'options', 'root')
  vim.env.LAZY = lazy

  local ac = require('fzf-lua.utils').ansi_codes
  if lazy and name:match('^' .. lazy) then
    name = name:gsub('^' .. lazy, ac.cyan('$LAZY'))
  elseif name:match('^' .. xdg_config) then
    name = name:gsub('^' .. xdg_config, ac.yellow('$XDG_CONFIG_HOME'))
  elseif name:match('^' .. xdg_state) then
    name = name:gsub('^' .. xdg_state, ac.red('$XDG_STATE_HOME'))
  elseif name:match('^' .. xdg_cache) then
    name = name:gsub('^' .. xdg_cache, ac.grey('$XDG_CACHE_HOME'))
  elseif name:match('^' .. xdg_data) then
    name = name:gsub('^' .. xdg_data, ac.green('$XDG_DATA_HOME'))
  elseif name:match(vimfile) then
    name = name:gsub('^' .. vimfile, ac.red('$VIMFILE'))
  elseif name:match(vimruntime) then
    name = name:gsub('^' .. vimruntime, ac.red('$VIMRUNTIME'))
  end
  return name
end

---TODO: cond cache, cond ttl
---@param filename string
---@param cmd string[]
---@param cond boolean?
---@return string
M.cache_run = function(filename, cmd, cond)
  local path = fs.joinpath(root, filename)
  local res = M.read_file(path)
  if not cond and res and #res > 0 then return res end
  res = vim.fn.system(cmd)
  assert(M.write_file(path, res))
  return res
end
return M
