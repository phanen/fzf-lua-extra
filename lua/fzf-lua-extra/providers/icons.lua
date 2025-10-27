-- TODO: ttl
---@diagnostic disable-next-line: no-unknown
local f = require('fzf-lua')
return function(opts)
  local run = require('fzf-lua-extra.utils').cache_run
  local force_run ---@type boolean?
  local contents = function(cb)
    ---@type table<string, table>
    local nerds = vim.json.decode(run('glyphnames.json', {
      'curl',
      '-sL',
      'https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/glyphnames.json',
    }, force_run))
    ---@type table<string, table>
    local emojis = vim.json.decode(run('emojis.json', {
      'curl',
      '-sL',
      'https://raw.githubusercontent.com/muan/unicode-emoji-json/refs/heads/main/data-by-emoji.json',
    }, force_run))
    coroutine.wrap(function()
      local utils = require('fzf-lua.utils')
      local nbsp = utils.nbsp
      local cyan = utils.ansi_codes.cyan
      local yellow = utils.ansi_codes.yellow
      local magenta = utils.ansi_codes.magenta
      local co = coroutine.running()
      for k, v in pairs(nerds) do
        cb(
          ('%s%s%s%s(%s)'):format(cyan(v.char), nbsp, yellow(k), nbsp, magenta(v.code)),
          function() coroutine.resume(co) end
        )
        coroutine.yield()
      end
      for k, v in pairs(emojis) do
        cb(
          ('%s%s%s%s(%s)'):format(cyan(k), nbsp, yellow(v.name), nbsp, magenta('emoji')),
          function() coroutine.resume(co) end
        )
        coroutine.yield()
      end
      cb(nil)
    end)()
  end
  opts = vim.tbl_deep_extend('force', opts or {}, {
    -- no complete.{fn, field_index}
    -- TODO:
    ---@param sel string[]
    ---@param _o table
    ---@param line string
    ---@param col integer
    ---@return string, integer?
    complete = function(sel, _o, line, col)
      local s = sel[1]
      if not s then return '' end
      if _o.__CTX.mode == 'i' then col = col - 1 end
      local cur_end = (line:len() == 0 or col == 0) and 0 or col + vim.str_utf_end(line, col)
      ---@type string
      local icon = s:match(('^(.-)' .. FzfLua.utils.nbsp))
      ---@type string
      local newline = line:sub(1, cur_end) .. icon .. line:sub(cur_end + 1)
      return newline, cur_end
    end,
    winopts = { relative = 'cursor', height = 0.2, width = 0.3, border = 'none' },
    actions = {
      ['ctrl-r'] = {
        fn = function(_, o)
          force_run = true
          o.__call_fn(contents, o)
        end,
        -- reload = true,
      },
    },
  })
  f.fzf_exec(contents, opts)
end
