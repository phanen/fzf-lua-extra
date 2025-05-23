local M = {}

---@diagnostic disable-next-line: unused-local
local api, fn, uv, fs = vim.api, vim.fn, vim.uv, vim.fs

local root = fn.stdpath 'state' .. '/fzf-lua-extra'

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

M.wrap_reload = function(opts, contents)
  opts.__fn_reload = opts.__fn_reload or function() return contents end
  local shell = require('fzf-lua.shell')
  -- build the "reload" cmd and remove '-- {+}' from the initial cmd
  local reload, id = shell.reload_action_cmd(opts, '{+}')
  local new_contents = reload:gsub('%-%-%s+{%+}$', '')
  opts.__reload_cmd = reload
  opts._fn_pre_fzf = function() shell.set_protected(id) end
  return new_contents
end

-- mkdir for file
local fs_file_mkdir = function(path)
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

---@type fun(name: string?): table<string, any>
M.get_lazy_plugins = (function()
  local plugins
  return function(name)
    if not plugins then
      -- https://github.com/folke/lazy.nvim/blob/d3974346b6cef2116c8e7b08423256a834cb7cbc/lua/lazy/view/render.lua#L38-L40
      local cfg = package.loaded['lazy.core.config']
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
    local stdout = obj.stdout
    return cb(parse_gh_result(stdout))
  end)
end

---gh but use local cache first
---@param route string
---@param path string
---@param cb fun(string, table)
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
---@param cb fun(string, table)
---@return vim.SystemObj?
M.gh_cache = function(route, cb)
  local path = root .. '/' .. route .. '.json'
  return gh_cache(route, path, cb)
end

M.replace_with_envname = function(name)
  local xdg_config = vim.env.XDG_CONFIG_HOME
  local xdg_state = vim.env.XDG_STATE_HOME
  local xdg_cache = vim.env.XDG_CACHE_HOME
  local xdg_data = vim.env.XDG_DATA_HOME
  local vimruntime = vim.env.VIMRUNTIME

  -- archlinux specific system-wide configs...
  local vimfile = '/usr/share/vim/vimfiles'
  vim.env.VIMFILE = vimfile
  -- note: lazy root may locate in xdg_data
  -- so it should be mached before data_home
  local lazy = package.loaded['lazy.core.config'].options.root
  vim.env.LAZY = lazy

  local ac = require('fzf-lua.utils').ansi_codes
  if name:match('^' .. lazy) then
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
---@param cond boolean
---@return string
M.cache_run = function(filename, cmd, cond)
  u.pp(cond, 'a')
  local path = fs.joinpath(root, filename)
  local res = M.read_file(path)
  if not cond and res and #res > 0 then return res end
  res = vim.fn.system(cmd)
  assert(M.write_file(path, res))
  return res
end
return M
