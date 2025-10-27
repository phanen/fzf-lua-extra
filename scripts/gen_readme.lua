-- Update README.md providers section with generated list
-- Usage: nvim -l scripts/gen_readme.lua

local luv = vim.loop
local dir = 'lua/fzf-lua-extra/providers/'
local readme = 'README.md'
local section_start = '<!-- providers:start -->'
local section_end = '<!-- providers:end -->'

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then
    io.stderr:write('Could not open ' .. path .. '\n')
    os.exit(1)
  end
  local content = f:read('*a')
  f:close()
  return content
end

local function write_file(path, content)
  local f = io.open(path, 'w')
  if not f then
    io.stderr:write('Could not open ' .. path .. ' for writing\n')
    os.exit(1)
  end
  f:write(content)
  f:close()
end

local function gen_providers()
  local extra_info = {
    aerial = {
      desc = '`require("aerial").fzf_lua_picker()`',
      upstream_url = 'https://github.com/stevearc/aerial.nvim/issues/472',
    },
    serverlist2 = {
      desc = '`FzfLua serverlist`',
      upstream_url = 'https://github.com/ibhagwan/fzf-lua/pull/2320',
    },
    swiper_blines = {
      desc = '`FzfLua blines profile=ivy`',
      upstream_url = 'https://github.com/ibhagwan/fzf-lua/issues/2261',
    },
  }
  local handle = luv.fs_scandir(dir)
  if not handle then
    io.stderr:write('Could not open directory: ' .. dir .. '\n')
    os.exit(1)
  end
  local entries = {} ---@type string[]
  while true do
    local name, t = luv.fs_scandir_next(handle)
    if not name then break end
    if t == 'file' then
      local base = name:gsub('%.lua$', '')
      table.insert(entries, base)
    end
  end
  table.sort(entries)
  local lines = {}
  for _, base in ipairs(entries) do
    local info = extra_info[base]
    if info then
      table.insert(lines, string.format('* ~%s~ %s (%s)', base, info.desc, info.upstream_url))
    else
      table.insert(lines, '* ' .. base)
    end
  end
  return table.concat(lines, '\n')
end

local function update_readme()
  local f = io.open(readme, 'r')
  if not f then
    io.stderr:write('Could not open ' .. readme .. '\n')
    os.exit(1)
  end
  local content = read_file(readme) ---@type string
  -- Use vim.pesc to escape section markers for robust pattern matching
  local pattern = vim.pesc(section_start) .. '(.-)' .. vim.pesc(section_end)
  local new_section = gen_providers()
  local replaced, n = content:gsub(
    pattern,
    function(_) return section_start .. '\n' .. new_section .. '\n' .. section_end end
  )
  if n == 0 then
    io.stderr:write('Section markers not found in ' .. readme .. '\n')
    os.exit(1)
  end
  write_file(readme, replaced)
end

update_readme()
