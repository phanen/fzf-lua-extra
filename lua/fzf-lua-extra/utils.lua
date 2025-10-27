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
      error(('Fail to parse json: ' .. tbl))
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
  local patterns = {
    { var = lazy, color = ac.cyan, label = '$LAZY' },
    { var = xdg_config, color = ac.yellow, label = '$XDG_CONFIG_HOME' },
    { var = xdg_state, color = ac.red, label = '$XDG_STATE_HOME' },
    { var = xdg_cache, color = ac.grey, label = '$XDG_CACHE_HOME' },
    { var = xdg_data, color = ac.green, label = '$XDG_DATA_HOME' },
    { var = vimfile, color = ac.red, label = '$VIMFILE' },
    { var = vimruntime, color = ac.red, label = '$VIMRUNTIME' },
  }
  for _, p in ipairs(patterns) do
    if p.var and name:match('^' .. p.var) then
      name = name:gsub('^' .. p.var, p.color(p.label))
      break
    end
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

---@param format? function
---@return fzf-lua.config.Actions
M.fix_actions = function(format)
  local actions = FzfLua.config.globals.actions.files ---@type fzf-lua.config.Actions
  for a, f in pairs(actions) do
    if type(f) == 'function' then actions[a] = { fn = f } end
    local old_fn = actions[a].fn
    if old_fn then
      actions[a].fn = function(s, ...)
        if s[1] and vim.startswith(s[1], '/tmp/fzf-temp-') then -- {+f} is used as field_index
          s = vim.split(io.open(s[1], 'r'):read('*a'), '\n')
          s[#s] = nil
        end
        s = format and vim.tbl_map(format, s) or s
        return old_fn(s, ...)
      end
    end
  end
  return actions
end

---@param messages string[]
---@param lines integer
---@param columns integer
---@return string[]
M.center_message = function(messages, lines, columns)
  -- messages: array of strings (each is a line)
  local msg_count = #messages
  local top = math.floor((lines - msg_count) / 2)
  local bottom = lines - top - msg_count

  -- Center each message line horizontally
  local centered_lines = {} ---@type string[]
  for _, line in ipairs(messages) do
    local pad = math.max(0, columns - #line)
    local left = math.floor(pad / 2)
    local right = pad - left
    table.insert(centered_lines, string.rep(' ', left) .. line .. string.rep(' ', right))
  end

  -- Build the array
  local result = {}
  for _ = 1, top do
    table.insert(result, string.rep(' ', columns))
  end
  for _, line in ipairs(centered_lines) do
    table.insert(result, line)
  end
  for _ = 1, bottom do
    table.insert(result, string.rep(' ', columns))
  end
  return result
end

return M
