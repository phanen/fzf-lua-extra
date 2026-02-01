-- tbh lazy load is not necessary now, just use alias here
local utils = require('fzf-lua-extra.utils')

---@param cb fun(plugin: table, o: table)
local p_do = function(cb)
  return function(selected, opts)
    vim.iter(selected):each(function(sel)
      sel = sel:match('[^%s]+')
      local bs_parts = vim.split(sel, '/')
      local name = bs_parts[#bs_parts]
      local plugin = utils.get_lazy_plugins()[name] or opts.previewer.items[sel]
      if plugin then cb(plugin, opts) end
    end)
  end
end

-- https://github.com/folke/lazy.nvim/blob/c6a57a3534d3494bcc5ff9b0586e141bdb0280eb/lua/lazy/core/util.lua#L68
---@param name string
---@return string
local normname = function(name)
  return (
    name:lower():gsub('^n?vim%-', ''):gsub('%.n?vim$', ''):gsub('[%.%-]lua', ''):gsub('[^a-z]+', '')
  )
end

-- https://github.com/alex-popov-tech/store.nvim/blob/e3aea13c354de465ca3a879158a1752e0c9c13ea/lua/store/actions.lua#L293
local write_conf = function(data)
  local repo = data.repo
  local filepath = vim.fn.expand(data.filepath)
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ':h'), 'p')
  local exist = vim.uv.fs_stat(filepath)
  local file = io.open(filepath, exist and 'a' or 'w')
  if not file then return vim.notify('Failed to open file: ' .. filepath) end
  if exist then file:write('\n\n') end
  file:write(data.config)
  file:flush()
  file:close()
  vim.notify(repo.full_name .. ' in: ' .. filepath)
end

---Format repository information for display in a single line for the picker
---@param repo store.Repository The repository to format
---@param compact? boolean Whether to use compact formatting
---@return string formatted_line
local function format_repository_info(repo, compact)
  local fu = FzfLua.utils
  local cyan = fu.ansi_codes.cyan
  local yellow = fu.ansi_codes.yellow
  local magenta = fu.ansi_codes.magenta
  local green = fu.ansi_codes.green

  local parts = {}
  parts[#parts + 1] = repo.full_name
  parts[#parts + 1] = '\t'
  -- Format stars: Truncate if longer than 8 bytes, then left-align to 8 bytes.
  local stars_str = '⭐' .. repo.stars
  local display_stars = stars_str
  if #display_stars > 8 then display_stars = string.sub(display_stars, 1, 8) end
  parts[#parts + 1] = magenta(string.format('%-8s', display_stars))

  -- Format issues: Truncate if longer than 8 bytes, then left-align to 8 bytes.
  local issues_str = '🚨' .. repo.issues
  local display_issues = issues_str
  if #display_issues > 8 then display_issues = string.sub(display_issues, 1, 8) end
  parts[#parts + 1] = magenta(string.format('%-8s', display_issues))

  parts[#parts + 1] = cyan(repo.full_name)
  if not compact and repo.description and repo.description ~= '' then
    parts[#parts + 1] = yellow(repo.description)
  end
  if #repo.tags > 0 then parts[#parts + 1] = green('[' .. table.concat(repo.tags, ',') .. ']') end
  return table.concat(parts, ' ')
end

local State = {}
State.state = {
  all = function()
    State.encode = function(p) return format_repository_info(p) end
  end,
  compat = function()
    State.encode = function(p) return format_repository_info(p, true) end
  end,
}
State.cycle = function()
  State.key = next(State.state, State.key)
  if not State.key then State.key = next(State.state, State.key) end
  State.state[State.key]()
end

---@return function, function
State.get = function() return State.filter, State.encode end
State.cycle()

---@class fle.config.Store: fzf-lua.config.Base
local __DEFAULT__ = {
  -- https://github.com/alex-popov-tech/store.nvim/blob/43e574b5aac28891fe50316fc69727cfc27727a4/lua/store/config.lua#L186
  urls = {
    store = 'https://gist.githubusercontent.com/alex-popov-tech/92d1366bfeb168d767153a24be1475b5/raw/db.json', -- URL for plugin data
    ['lazy.nvim'] = 'https://gist.githubusercontent.com/alex-popov-tech/6629a59e7910aa08b1aa5cdc0519b8b4/raw/lazy.nvim.json',
    ['vim.pack'] = 'https://gist.githubusercontent.com/alex-popov-tech/18a46177d6473e12bc2c854e2548f127/raw/vim.pack.json',
  },
  ---@param path string
  ---@return boolean
  cache_invalid = function(path)
    local stat = vim.uv.fs_stat(path)
    return not stat or (os.time() - stat.ctime.sec) > 2 * 24 * 60 * 60
  end,
  previewer = {
    _ctor = function() return require('fzf-lua-extra.previewers').store end,
    items = {},
  },
  fzf_opts = {
    ['--delimiter'] = '\t',
    ['--with-nth'] = '2..',
  },
  actions = {
    ['enter'] = p_do(function(p, o)
      if p.dir and vim.uv.fs_stat(p.dir) then
        utils.chdir(p.dir)
      elseif p.full_name then
        local cmd = { 'curl', '-sL', o.urls['lazy.nvim'] }
        local opts = { cache_path = utils.path('store-lazy.json'), cache_invalid = o.cache_invalid }
        utils.arun(function()
          local plugins_folder = require('store.utils').get_plugins_folder()
          local filepath = plugins_folder .. '/' .. (normname(p.name) .. '.lua')
          local res = utils.run(cmd, opts).stdout or ''
          local items = vim.json.decode(res).items
          write_conf({ config = items[p.full_name], filepath = filepath, repo = p })
        end)
      end
    end),
    ['ctrl-y'] = p_do(function(p) vim.fn.setreg('+', p.url) end),
    ['ctrl-o'] = p_do(function(p) -- search cleaned plugins
      vim.ui.open(p.url or ('https://github.com/search?q=%s'):format(p.name))
    end),
    ['ctrl-l'] = p_do(function(p)
      if p.dir and vim.uv.fs_stat(p.dir) then FzfLua.files { cwd = p.dir } end
    end),
    ['ctrl-n'] = p_do(function(p)
      if p.dir then FzfLua.live_grep_native { cwd = p.dir } end
    end),
    ['ctrl-r'] = p_do(
      function(p) require('lazy.core.loader')[p._ and p._.loaded and 'reload' or 'load'](p) end
    ),
    ['ctrl-g'] = { fn = State.cycle, reload = true },
  },
}

-- https://github.com/alex-popov-tech/store.nvim/blob/0dad6788ac69531f37f7b65939c6ee22ac812757/lua/store/types.lua#L1
---@class store.Repository
---@field source string Repository source (e.g., "github")
---@field author string Repository author/owner
---@field name string Repository name
---@field full_name string Repository full name (author/name)
---@field url string Repository URL
---@field description string Repository description
---@field tags string[] Array of topic tags
---@field stars number Number of stars
---@field issues number Number of open issues
---@field created_at string Creation timestamp (ISO format)
---@field updated_at string Last update timestamp (ISO format)
---@field pretty {stars: string, issues: string, created_at: string, updated_at: string} Formatted display values
---@field readme? string README reference in the form "branch/path"

---@class store.Meta
---@field created_at number Unix timestamp of database creation

---@class store.Database
---@field meta store.Meta Metadata about the dataset
---@field items store.Repository[] Array of repository objects

---@class store.RepositoryField
---@field content string Display content for this field
---@field limit number Maximum display width for this field

---@alias store.RepositoryRenderer fun(repo: store.Repository, isInstalled: boolean): store.RepositoryField[]
-- {
--   author = "Gaylord-kcf",
--   created_at = "2025-12-18T19:57:58Z",
--   description = "🎨 Enhance your Neovim experience with dookie.nvim, a unique color scheme inspired by Plan9's acme editor.",
--   full_name = "Gaylord-kcf/dookie.nvim",
--   issues = 1,
--   name = "dookie.nvim",
--   pretty = {
--     created_at = "last month",
--     issues = "1",
--     stars = "2",
--     updated_at = "today"
--   },
--   readme = "main/README.md",
--   source = "github",
--   stars = 2,
--   tags = { "acme", "colorscheme", "plan9", "theme" },
--   updated_at = "2026-01-31T10:04:17Z",
--   url = "https://github.com/Gaylord-kcf/dookie.nvim"
-- }

---@diagnostic disable-next-line: no-unknown
return function(opts)
  assert(__DEFAULT__)
  local contents = function(cb)
    utils.arun(function()
      local db = vim.json.decode(
        utils.run(
          { 'curl', '-sL', opts.urls['store'] },
          { cache_path = utils.path('store.json'), cache_invalid = opts.cache_invalid }
        ).stdout or ''
      )
      local items = db.items
      opts.previewer.items = opts.previewer.items or {}
      for _, item in ipairs(items) do
        opts.previewer.items[item.full_name] = item
        local filter, encode = State.get()
        if not filter or filter(item) then cb(encode(item)) end
      end
      cb(nil)
    end)
  end
  FzfLua.fzf_exec(contents, opts)
end
