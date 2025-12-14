local utils = require('fzf-lua-extra.utils')

---@class fle.config.Icons: fzf-lua.config.Base
local __DEFAULT__ = {
  glyphnames_url = 'https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/glyphnames.json',
  emojis_url = 'https://raw.githubusercontent.com/muan/unicode-emoji-json/refs/heads/main/data-by-emoji.json',
  cache_invalid = utils.month_invalid,
  -- no complete.{fn, field_index}
  complete = function(sel, _o, line, col)
    local s = sel[1]
    if not s then return '' end
    if _o.__CTX.mode == 'i' then col = col - 1 end
    local cur_end = (line:len() == 0 or col == 0) and 0 or col + vim.str_utf_end(line, col)
    local icon = s:match(('^(.-)' .. FzfLua.utils.nbsp))
    local newline = line:sub(1, cur_end) .. icon .. line:sub(cur_end + 1)
    return newline, cur_end
  end,
  winopts = { relative = 'cursor', height = 0.2, width = 0.3, border = 'none' },
  actions = {
    ['ctrl-r'] = {
      fn = function(_, o)
        o.cache_invalid = function() return true end
      end,
      reload = true,
    },
  },
}

---@diagnostic disable-next-line: no-unknown
return function(opts)
  assert(__DEFAULT__)
  local contents = function(cb)
    utils.arun(function()
      local nerds = vim.json.decode(
        ---@diagnostic disable-next-line: param-type-mismatch
        utils.run(
          { 'curl', '-sL', opts.glyphnames_url },
          { cache_path = utils.path('glyphnames.json'), cache_invalid = opts.cache_invalid }
        ).stdout
      )
      local emojis = vim.json.decode(
        ---@diagnostic disable-next-line: param-type-mismatch
        utils.run(
          { 'curl', '-sL', opts.emojis_url },
          { cache_path = utils.path('emojis.json'), cache_invalid = opts.cache_invalid }
        ).stdout
      )
      local fu = FzfLua.utils
      local nbsp = fu.nbsp
      local cyan = fu.ansi_codes.cyan
      local yellow = fu.ansi_codes.yellow
      local magenta = fu.ansi_codes.magenta
      local co = coroutine.running() -- this work now anyway
      for k, v in pairs(nerds) do
        local str = ('%s%s%s%s(%s)'):format(cyan(v.char), nbsp, yellow(k), nbsp, magenta(v.code))
        cb(str, function() coroutine.resume(co) end)
        coroutine.yield()
      end
      for k, v in pairs(emojis) do
        local str = ('%s%s%s%s(%s)'):format(cyan(k), nbsp, yellow(v.name), nbsp, magenta('emoji'))
        cb(str, function() coroutine.resume(co) end)
        coroutine.yield()
      end
      cb(nil)
    end)
  end
  FzfLua.fzf_exec(contents, opts)
end
