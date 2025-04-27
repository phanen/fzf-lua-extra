local glob_regex = '(.*)%s%-%-%s(.*)'
local api = vim.api

return function()
  local port
  require('fzf-lua').fzf_live(function(q)
    local gq, sq = q:match(glob_regex)
    if port and sq then
      vim.system { 'curl', '-XPOST', ('localhost:%s'):format(port), '-d', ('search:%s'):format(sq) }
    end
    return api.nvim_get_runtime_file(gq or q, true)
  end, {
    fzf_opts = { ['--listen'] = true },
    previewer = 'builtin',
    actions = {
      start = {
        fn = function(s) port = unpack(s) end,
        field_index = '$FZF_PORT',
        exec_silent = true,
      },
    },
  })
end
