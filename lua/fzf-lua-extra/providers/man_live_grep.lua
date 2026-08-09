local previewer = require('fzf-lua.previewer.builtin')

---@class fle.previewer.ManWithMatch: fzf-lua.previewer.BufferOrFile,{}
---@field super fzf-lua.previewer.BufferOrFile
local ManWithMatch = previewer.man_pages:extend()

---@param entry_str string mangrep's output line: 'name(section) -- snippet'
---@return table filetype=man, content=lines, line=N (matched term line)
function ManWithMatch:parse_entry(entry_str)
  local entry = previewer.man_pages.parse_entry(self, entry_str)
  if not entry.content then return entry end

  -- Pull the first <<term>> out of the mangrep snippet
  local first_term = entry_str:match('%<%<([^%>]-)%>')
  if not first_term or first_term == '' then return entry end

  local needle = first_term:lower()
  for i, line in ipairs(entry.content) do
    if type(line) == 'string' and line:lower():find(needle, 1, true) then
      entry.line = i
      entry.col = 1
      return entry
    end
  end

  entry.line = 1
  entry.col = 1
  return entry
end

---@class fle.config.ManLiveGrep: fzf-lua.config.Base|{}
local __DEFAULT__

local man_grep, man_live_grep
__DEFAULT__ = {
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
  actions = {
    enter = {
      fn = function(s)
        -- pcall defensive: parse_apropos occasionally returns nil for
        -- entries with weird snippet content (manpages.lua:26 asserts).
        local ok, err = pcall(FzfLua.actions.man, s)
        if not ok then
          vim.notify('[mangrep] failed to open manpage: ' .. tostring(err), vim.log.levels.WARN)
        end
      end,
      exec_silent = true,
    },
    ['ctrl-g'] = function(_, opts)
      local o = vim.deepcopy(__DEFAULT__)
      o.resume = true
      assert(opts.__ACT_TO)(o, assert(opts.__call_opts).query)
    end,
  },
  previewer = {
    _ctor = function() return ManWithMatch end,
    cmd = function() return require('fzf-lua.defaults')._man_cmd_fn() end,
  },
  fn_transform = function(line)
    local man, snippet = line:match('^(.-) %-%- (.*)$')
    if not man then return line end
    return string.format('%-30s %s', man, snippet)
  end,
}

---@param opts fle.config.ManLiveGrep|{}
---@param search string
---@return thread?, string?, table?
man_grep = function(opts, search)
  ---@diagnostic disable-next-line: param-type-mismatch
  opts = vim.tbl_deep_extend('force', __DEFAULT__, opts or {})
  opts.__ACT_TO = man_live_grep
  opts.__resume_key = man_grep
  return FzfLua.fzf_exec('mangrep ' .. FzfLua.libuv.shellescape(search), opts)
end

---@param opts fle.config.ManLiveGrep|{}
---@return thread?, string?, table?
man_live_grep = function(opts)
  ---@diagnostic disable-next-line: param-type-mismatch
  opts = vim.tbl_deep_extend('force', __DEFAULT__, opts or {})
  opts.__ACT_TO = man_live_grep
  opts.__resume_key = man_live_grep
  ---@diagnostic disable-next-line: param-type-mismatch
  return FzfLua.fzf_live('mangrep <query>', opts)
end

return man_live_grep
