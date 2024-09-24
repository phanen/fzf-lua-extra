# fzf-lua-overlay
[![CI](https://github.com/phanen/fzf-lua-overlay/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/phanen/fzf-lua-overlay/actions/workflows/ci.yml)
Wrapper and pickers for [fzf-lua](https://github.com/ibhagwan/fzf-lua).

[mp4: showcase](https://github.com/phanen/fzf-lua-overlay/assets/91544758/134e1dc3-eb1d-4b52-a462-dbe6c23ef53d)

## features
* wrapper for all fzf-lua's builtin pickers (support visual selection support, and accept the same options)
* new pickers
  * recent files (`vim.v.oldfiles` + recent closed files)
  * `lazy.nvim` (preview in fzf-lua, chdir, open in browser)
  * zoxide integration for `chdir` actions
  * notes/dotfiles management
  * runtimepath, scriptnames, gitignore, license

## usage
> <https://github.com/phanen/.dotfiles/blob/master/.config/nvim/lua/pack/fzf.lua>
```lua
local fl = setmetatable({}, { __index = function(_, k) return ([[<cmd>lua require('flo').%s()<cr>]]):format(k) end })

return {
  {

    'phanen/fzf-lua-overlay',
    main = 'flo',
    cond = not vim.g.vscode,
    -- stylua: ignore
    keys = {
      -- try new pickers
      { '+<c-f>',        fl.lazy,                  mode = { 'n', 'x' } },
      { '+e',            fl.grep_notes,            mode = { 'n' } },
      { "+fi",           fl.gitignore,             mode = { 'n', 'x' } },
      { "+fl",           fl.license,               mode = { 'n', 'x' } },
      { '+fr',           fl.rtp,                   mode = { 'n', 'x' } },
      { '+fs',           fl.scriptnames,           mode = { 'n', 'x' } },
      { '<leader><c-f>', fl.zoxide,                mode = { 'n', 'x' } },
      { '<leader><c-j>', fl.todo_comment,          mode = { 'n', 'x' } },
      { '<leader>e',     fl.find_notes,            mode = { 'n', 'x' } },
      { '<leader>fo',    fl.recentfiles,           mode = { 'n', 'x' } },
      { '<leader>l',     fl.find_dots,             mode = { 'n', 'x' } },
      { '+l',            fl.grep_dots,             mode = { 'n', 'x' } },

      -- all fzf-lua's builtin pickers work transparently with visual mode support
      { '<c-b>',         fl.buffers,               mode = { 'n', 'x' } },
      { '<c-l>',         fl.files,                 mode = { 'n', 'x' } },
      { '<c-n>',         fl.live_grep_native,      mode = { 'n', 'x' } },
    },
    opts = {},
  },
  -- config fzf-lua still work well
  { 'ibhagwan/fzf-lua', cmd = { 'FzfLua' }, opts = {} },
}
```

## requirement
`flo.recentfiles`: initialize `_G.__recent_hlist` (since `vim.g` is buggy, https://github.com/neovim/neovim/issues/20107)
```lua
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(ev)
    if not _G.__recent_hlist then _G.__recent_hlist = require('flo.hashlist') {} end
    -- ignore no name buffer on enter...
    if api.nvim_buf_get_name(ev.buf) == '' then return end
    print(ev.match)
    _G.__recent_hlist:access(ev.match)
  end,
})
```

## credit
* <https://github.com/ibhagwan/fzf-lua>
* <https://github.com/kilavila/nvim-gitignore>
* <https://github.com/roginfarrer/fzf-lua-lazy.nvim>

## todo
* [x] integration with dirstack.nvim (https://github.com/phanen/dirstack.nvim/commit/f5efd5e8c7768c22d2d52f6d1ae827a54ccaf416)
* [x] inject new pickers into fzflua builtin
