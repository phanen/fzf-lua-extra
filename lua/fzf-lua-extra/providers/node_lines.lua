local api, fn = vim.api, vim.fn
---@param opts { query: string?, node: TSNode? }
local function nodelines(opts)
  opts = opts or {}
  local stop = { function_definition = true }
  local node = opts.node or vim.treesitter.get_node()
  while node and not stop[node:type()] do
    node = node:parent() ---@type TSNode?
  end
  if not node then return end
  local start_line, end_line ---@type integer, integer
  if api.nvim_get_mode().mode:match('[vV\022]') then
    start_line, end_line = fn.line '.', fn.line 'v'
    if start_line > end_line then
      start_line, end_line = end_line, start_line ---@type integer, integer
    end
  else
    start_line, _, end_line, _ = vim.treesitter.get_node_range(node)
    start_line = start_line + 1
    end_line = end_line + 1
  end
  require('fzf-lua').blines({
    start_line = start_line,
    end_line = end_line,
    query = opts.query,
    actions = {
      ['alt-g'] = {
        fn = function(sel) return nodelines({ node = node:parent(), query = unpack(sel) }) end,
        field_index = '{q}',
        exec_silent = true,
      },
    },
  })
end

return nodelines
