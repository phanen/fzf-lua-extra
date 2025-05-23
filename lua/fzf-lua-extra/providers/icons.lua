-- TODO: ttl
local f = require('fzf-lua')
return function(opts)
  local run = require('fzf-lua-extra.utils').cache_run
  local force_run
  local contents = function(cb)
    local nerds = vim.json.decode(run('glyphnames.json', {
      'curl',
      '-sL',
      'https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/glyphnames.json',
    }, force_run))
    local emojis = vim.json.decode(run('emojis.json', {
      'curl',
      '-sL',
      'https://raw.githubusercontent.com/muan/unicode-emoji-json/refs/heads/main/data-by-emoji.json',
    }, force_run))
    coroutine.wrap(function()
      local utils = require('fzf-lua').utils
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
    complete = function(sel, _o, line, col)
      sel = sel[1]
      if not sel then return '' end
      local icon = sel:match(('^(.-)' .. require('fzf-lua').utils.nbsp))
      local newline = line:sub(1, col) .. icon .. line:sub(col + 1)
      return newline, col
    end,
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
