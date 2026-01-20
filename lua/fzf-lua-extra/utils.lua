local M = {}

---@diagnostic disable-next-line: assign-type-mismatch
---@module 'vim._async'
local async = vim.F.npcall(require, 'vim._async') or require('fzf-lua-extra.compat.async')

---@diagnostic disable-next-line: unused-local
local api, fn, uv, fs = vim.api, vim.fn, vim.uv, vim.fs

local state_path ---@type string
---@param ... string
---@return string
M.path = function(...)
  state_path = state_path or M.stdpath('state')
  return fs.joinpath(state_path, 'fzf-lua-extra', ...)
end

---@param s string
---@return string
M.stdpath = function(s) ---@diagnostic disable-next-line: param-type-mismatch, return-type-mismatch
  return fn.stdpath(s)
end

M.arun = async.run

--- @param x any
--- @return integer?
function M.tointeger(x)
  local nx = tonumber(x)
  if nx and nx == math.floor(nx) then
    --- @cast nx integer
    return nx
  end
end

---@param path string
M.chdir = function(path)
  if fn.executable('zoxide') == 1 then vim.system { 'zoxide', 'add', path } end
  api.nvim_set_current_dir(path)
end

---@type fun(fmt: string, ...: any)
M.errf = function(fmt, ...) error(fmt:format(...)) end

---@param path string
---@param flag iolib.OpenMode?
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
---@param flag iolib.OpenMode?
---@return boolean
M.write_file = function(path, content, flag)
  if not uv.fs_stat(path) then fs_file_mkdir(path) end
  local fd = io.open(path, flag or 'w')
  if not fd then return false end
  if content then fd:write(content) end
  fd:close()
  return true
end

-- https://github.com/folke/lazy.nvim/blob/d3974346b6cef2116c8e7b08423256a834cb7cbc/lua/lazy/view/render.lua#L38-L40
---@return table<string, LazyPlugin?>
M.get_lazy_plugins = function()
  ---@module 'lazy.core.config'
  local cfg = package.loaded['lazy.core.config']
  if not cfg or not cfg.plugins then
    error('lazy.nvim is not loaded')
    return {}
  end
  local plugins = vim.tbl_deep_extend('force', cfg.plugins, cfg.spec.disabled)
  for _, p in ipairs(cfg.to_clean) do -- kind="clean" seems not named in table
    plugins[p.name] = p
  end
  return plugins
end

---@class fle.SystemOpts: vim.SystemOpts
---@field cache_path? string
---@field cache_invalid fun(cache_path: string): boolean

---@param path string
---@return boolean
M.month_invalid = function(path)
  local stat = uv.fs_stat(path)
  return not stat or (os.time() - stat.ctime.sec) > 30 * 24 * 60 * 60
end

---run with optional cache
---@async
---@param cmd string[]
---@param opts? fle.SystemOpts|{}
---@return vim.SystemCompleted
M.run = function(cmd, opts)
  opts = opts or {} ---@type fle.SystemOpts
  opts.cache_invalid = opts.cache_invalid or function(_) return false end
  local path = opts.cache_path
  if path then
    local res = M.read_file(path)
    if res and #res > 0 and not opts.cache_invalid(path) then
      return { code = 0, stdout = res, signal = 0 }
    end
  end
  local obj = async.await(3, vim.system, cmd, opts) ---@type vim.SystemCompleted
  if obj.code ~= 0 then M.errf('Fail %q (%s %s)', table.concat(cmd, ' '), obj.code, obj.stderr) end
  if path and obj.stdout then assert(M.write_file(path, obj.stdout or '')) end
  return obj
end

---@class fle.gh.Opts
---@field endpoint string
---@field method? string
---@field headers? table
---@field data? any

---github restful api with cache
---@async
---@param opts fle.gh.Opts
---@return table
M.gh = function(opts)
  local method = opts.method or 'GET'
  local headers = opts.headers or {}
  local data = opts.data

  local cmd = { 'gh', 'api', opts.endpoint, '--method', method }

  -- Add headers if provided
  for k, v in pairs(headers) do
    table.insert(cmd, '-H')
    table.insert(cmd, string.format('%s: %s', k, v))
  end

  -- Add data if provided
  if data then
    table.insert(cmd, '--input')
    table.insert(cmd, '-')
  end

  ---@param str string
  ---@return table
  local parse_gh_result = function(str)
    local ok, tbl = pcall(vim.json.decode, str)
    if not ok then error('Fail to parse json: ' .. tostring(tbl)) end ---@cast tbl table
    if tbl.message and tbl.message:match('API rate limit exceeded') then M.errf(tbl.message) end
    return tbl
  end

  local sopts = {} ---@type fle.SystemOpts
  if data then sopts.stdin = vim.json.encode(data) end
  sopts.cache_invalid = function(_) return false end
  sopts.cache_path = M.path(opts.endpoint .. '.json')

  local obj = M.run(cmd, sopts)
  local stdout = obj.stdout or ''
  -- local stderr = obj.stderr or ''
  -- if obj.code ~= 0 then M.errf('gh api failed: %s', stderr) end
  return parse_gh_result(stdout)
end

---@param name string
---@return string
M.format_env = function(name)
  local env_vars = {
    {
      key = 'LAZY',
      color = 'cyan',
      get = function(env)
        local v = vim.tbl_get(package.loaded['lazy.core.config'] or {}, 'options', 'root')
        env.LAZY = v
        return v
      end,
    },
    { key = 'XDG_CONFIG_HOME', color = 'yellow' },
    { key = 'XDG_STATE_HOME', color = 'red' },
    { key = 'XDG_CACHE_HOME', color = 'grey' },
    { key = 'XDG_DATA_HOME', color = 'green' },
    { key = 'VIMFILE', color = 'red', get = function() return '/usr/share/vim/vimfiles' end },
    { key = 'VIMRUNTIME', color = 'red' },
  }

  local ac = require('fzf-lua.utils').ansi_codes

  for _, env in ipairs(env_vars) do
    local value = env.get and env.get(vim.env) or vim.env[env.key]
    if value and name:match('^' .. vim.pesc(value)) then
      local color_fn = ac[env.color] or function(x) return x end
      name = name:gsub('^' .. vim.pesc(value), color_fn('$' .. env.key))
      break
    end
  end
  return name
end

---@param format? function
---@return fzf-lua.config.Actions
M.fix_actions = function(format)
  local actions = vim.deepcopy(FzfLua.config.globals.actions.files) ---@type fzf-lua.config.Actions
  for a, f in pairs(actions) do
    if type(a) == 'string' then
      if type(f) == 'function' then actions[a] = { fn = f } end
      local old_fn = actions[a].fn
      if old_fn then
        actions[a].fn = function(s, ...)
          if s[1] and vim.startswith(s[1], '/tmp/fzf-temp-') then -- {+f} is used as field_index
            ---@diagnostic disable-next-line: need-check-nil
            s = vim.split(io.open(s[1], 'r'):read('*a'), '\n')
            s[#s] = nil
          end
          s = format and vim.tbl_map(format, s) or s
          return old_fn(s, ...)
        end
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
