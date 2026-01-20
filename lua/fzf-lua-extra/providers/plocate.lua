---@class fle.config.Plocate: fzf-lua.config.Base|{}
local __DEFAULT__

local lgrep, grep
__DEFAULT__ = {
  _actions = function() return require('fzf-lua-extra.utils').fix_actions() end,
  actions = {
    ['ctrl-g'] = function(_, opts)
      local o = vim.deepcopy(__DEFAULT__)
      o.resume = true
      assert(opts.__ACT_TO)(o, assert(opts.__call_opts).query)
    end,
  },
  previewer = 'builtin',
}

---@param opts fle.config.Plocate|{}
---@param search string
---@return thread?, string?, table?
grep = function(opts, search)
  ---@diagnostic disable-next-line: param-type-mismatch
  opts = vim.tbl_deep_extend('force', __DEFAULT__, opts or {})
  opts.__ACT_TO = lgrep
  opts.__resume_key = grep
  return FzfLua.fzf_exec('plocate -r ' .. FzfLua.libuv.shellescape(search), opts)
end

---@param opts fle.config.Plocate|{}
---@return thread?, string?, table?
lgrep = function(opts)
  ---@diagnostic disable-next-line: param-type-mismatch
  opts = vim.tbl_deep_extend('force', __DEFAULT__, opts or {})
  -- plocate can be slow, but this run plocate one more time on toggle
  opts.__ACT_TO = grep
  opts.__resume_key = lgrep
  ---@diagnostic disable-next-line: param-type-mismatch
  return FzfLua.fzf_live('plocate -r <query>', opts)
end

return lgrep
