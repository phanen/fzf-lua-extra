---@type FzfLuaOverlaySpec
local M = {}

M.inherit = 'oldfiles'

-- FIXME: twice `normalize_opts` in current overlay structure...
M.fn = function(opts)
  require('fzf-lua').fzf_exec(function(fzf_cb)
    local function add_entry(x, co)
      x = require('fzf-lua.make_entry').file(x, opts)
      if not x then return end
      fzf_cb(x, function(err)
        coroutine.resume(co)
        if err then fzf_cb() end
      end)
    end

    coroutine.wrap(function()
      local utils = require 'fzf-lua.utils'
      local co = coroutine.running()

      local bufnr = vim.api.nvim_get_current_buf()
      local curr_file = vim.api.nvim_buf_get_name(bufnr)

      local stat_fn = not opts.stat_file and function(_) return true end
        or type(opts.stat_file) == 'function' and opts.stat_file
        or function(file)
          local stat = vim.uv.fs_stat(file)
          return (
            not utils.path_is_directory(file, stat)
            -- FIFO blocks `fs_open` indefinitely (#908)
            and not utils.file_is_fifo(file, stat)
            and utils.file_is_readable(file)
          )
        end

      -- local buflist = vim.fn.getbufinfo { bufloaded = 1, buflisted = 1 }
      -- local bufmap = {}
      -- for _, buf in ipairs(buflist) do
      --   bufmap[buf.name] = true
      -- end

      if _G.__recent_hlist then
        _G.__recent_hlist:foreach(function(node)
          local file = node.key
          if stat_fn(file) and file ~= curr_file then add_entry(file, co) end
        end)
      end
      vim
        .iter(vim.v.oldfiles)
        :filter(stat_fn)
        :filter(function(file) return file ~= curr_file end)
        :filter(function(file) return not _G.__recent_hlist or not _G.__recent_hlist.hash[file] end)
        :each(function(file) add_entry(file, co) end)
      fzf_cb()
    end)()
  end, opts)
end

return M
