return function(opts)
  opts = opts or {}
  opts.file_icons = false
  opts.git_icons = false
  opts.winopts = opts.winopts or {}
  local ns = vim.api.nvim_create_namespace('fzf-lua-extra.decor')
  local lmarks = {} ---@type [integer, string, string][] -- line number -> { extmark id, icon, hl }
  opts.winopts.on_close = function() vim.api.nvim_set_decoration_provider(ns, { on_line = nil }) end
  opts.winopts.on_create = function(e)
    vim.api.nvim_set_decoration_provider(ns, {
      on_line = function(_, _, buf, lnum)
        -- skip prompt 0, maybe not the first line though
        if buf ~= e.bufnr or lnum == 0 then return end
        local content = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, true)[1]:match('^%s*(%S+)')
        if not content then
          if lmarks[lnum] then
            vim.api.nvim_buf_del_extmark(buf, ns, lmarks[lnum][1])
            lmarks[lnum] = nil
          end
          return
        end
        -- FIXME: scroll...
        ---@type string?, string?
        local icon, hl = require('mini.icons').get('file', content)
        if icon and (not lmarks[lnum] or (lmarks[lnum][2] ~= icon and lmarks[lnum][3] ~= hl)) then
          local id = vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
            id = (lmarks[lnum] or {})[1],
            -- virt_text_pos = 'inline', -- TODO: this break fzf match hl
            virt_text_pos = 'right_align',
            virt_text = { { icon .. ' ', hl or 'Error' } },
          })
          lmarks[lnum] = lmarks[lnum] or {}
          lmarks[lnum][1] = id
          lmarks[lnum][2] = icon
          lmarks[lnum][3] = hl
        end
      end,
    })
  end
  require('fzf-lua').files(opts)
end
