---@class fle.config.Atuin: fzf-lua.config.Base
---@field atuin_args? string Extra args passed to `atuin search` before `--`, e.g. `"--human --limit 100"`
---@field format? string Forwarded to `atuin search --format`. Overrides atuin's `history_format` setting.
---@field delimiter? string Delimiter used between atuin fields (default tab, matching atuin's default).
---@field with_nth? string Forwarded to fzf `--with-nth`. Default shows fields from `command_field` onwards.
---@field command_field? integer 1-indexed column of the command in the tab-separated output (default 2).
---@field time_field? integer 1-indexed column of the timestamp in the tab-separated output (default 1).
---@field duration_field? integer 1-indexed column of the execution duration in the tab-separated output (default 3).
---@field preview? fzf-lua.PreviewCmdSpec|false Set to `false` to disable. Defaults to a bat-highlighted view of the command with a metadata header (time + duration).
---@field _treesitter? fun(line: string): string?, integer?, string
local __DEFAULT__ = {
  -- Run on open so users see their most recent history before typing anything
  exec_empty_query = true,

  -- Default atuin output is `{time}\t{command}\t{duration}` (tab separated)
  delimiter = '\t',
  with_nth = '2..',
  command_field = 2,
  time_field = 1,
  duration_field = 3,

  fzf_opts = {
    ['--no-sort'] = true,
    ['--no-hscroll'] = true,
    ['--delimiter'] = '\t',
    ['--with-nth'] = '2..',
  },

  -- Tell fzf-lua (e.g. previewer) that the command sits in column 2
  line_field_index = '{2}',
  field_index_expr = '{2}',

  _treesitter = function(line) return 'foo.sh', nil, line end,
}

---Pick the Nth tab-separated field from a line, falling back to the last field
---or the whole line if the requested column is missing.
---@param line string
---@param delim string
---@param field integer
---@return string
local function pick_field(line, delim, field)
  local fields = vim.split(line, delim, { plain = true })
  return fields[field] or fields[#fields] or line
end

---@param sel string[]
---@param delim string
---@param field integer
---@return string?
local function pick_cmd(sel, delim, field)
  local line = sel[1]
  if not line or line == '' then return nil end
  return pick_field(line, delim, field)
end

---@param delim string
---@param field integer
---@return fzf-lua.config.Actions
local function build_actions(delim, field)
  return {
    enter = function(sel)
      local cmd = pick_cmd(sel, delim, field)
      if not cmd then return end
      vim.api.nvim_set_current_line(cmd)
      vim.fn.histadd('cmd', cmd)
      if vim.fn.mode():sub(1, 1) == 'i' then
        vim.cmd([[noautocmd lua vim.api.nvim_feedkeys('a', 'n', true)]])
      end
    end,
    ['ctrl-y'] = function(sel)
      local cmd = pick_cmd(sel, delim, field)
      if not cmd then return end
      vim.fn.setreg('+', cmd)
      vim.fn.setreg('*', cmd)
      vim.notify('Yanked: ' .. cmd)
    end,
  }
end

---Build a preview function that prints a colored header (time + duration) above
---the command, syntax-highlighted via `bat` (or `batcat`) when available.
---@param delim string
---@param cmd_field integer
---@param time_field integer
---@param duration_field integer
---@return fun(items: string[]): string
local function build_preview_fn(delim, cmd_field, time_field, duration_field)
  local esc = FzfLua.libuv.shellescape
  local bat = vim.fn.executable('bat') == 1 and 'bat'
    or vim.fn.executable('batcat') == 1 and 'batcat'
  -- ANSI: dim / bold cyan / reset
  local DIM, BOLD_CYAN, RESET = '\27[2m', '\27[1;36m', '\27[0m'
  local NO_ENTRY = ('echo %s'):format(esc('No entry selected'))

  return function(items)
    local line = items[1]
    if not line or line == '' then return NO_ENTRY end

    local fields = vim.split(line, delim, { plain = true })
    local header = ('%sTime:%s %s%s%s  %sDuration:%s %s\n'):format(
      BOLD_CYAN,
      RESET,
      DIM,
      fields[time_field] or '?',
      RESET,
      BOLD_CYAN,
      RESET,
      fields[duration_field] or '?'
    )
    local body = fields[cmd_field] or fields[2] or ''
    if body == '' then body = '# (empty command)' end

    local pipe = bat
        and (' | %s --language=sh --style=plain --color=always --paging=never --wrap=never'):format(
          bat
        )
      or ''
    return ('printf "%%s" %s && printf "%%s\n" %s%s'):format(esc(header), esc(body), pipe)
  end
end

---Build `atuin search [...args] [--format X] -- <query>`.
---The `--` prevents a query starting with `-` from being parsed as a flag.
---@param o fle.config.Atuin
---@return string
local function build_cmd(o)
  local argv = { 'atuin', 'search' }
  if o.atuin_args and o.atuin_args ~= '' then
    for arg in o.atuin_args:gmatch('%S+') do
      argv[#argv + 1] = arg
    end
  end
  if o.format and o.format ~= '' then
    argv[#argv + 1] = '--format'
    argv[#argv + 1] = o.format
  end
  argv[#argv + 1] = '--'
  argv[#argv + 1] = '<query>'
  return table.concat(argv, ' ')
end

---@param opts fle.config.Atuin?
---@return fle.config.Atuin
local function merge_opts(opts)
  ---@type fle.config.Atuin
  local merged = vim.tbl_deep_extend('force', __DEFAULT__, opts or {})
  -- After merge these defaults are guaranteed to be present
  ---@cast merged.delimiter string
  ---@cast merged.with_nth string
  ---@cast merged.command_field integer
  ---@cast merged.time_field integer
  ---@cast merged.duration_field integer
  merged.fzf_opts = vim.tbl_deep_extend('force', __DEFAULT__.fzf_opts, merged.fzf_opts or {})
  merged.fzf_opts['--delimiter'] = merged.delimiter
  merged.fzf_opts['--with-nth'] = merged.with_nth
  merged.actions = merged.actions or build_actions(merged.delimiter, merged.command_field)
  if merged.preview == nil then
    ---@type fzf-lua.PreviewCmdSpec
    merged.preview = {
      fn = build_preview_fn(
        merged.delimiter,
        merged.command_field,
        merged.time_field,
        merged.duration_field
      ),
      type = 'cmd',
    }
  end
  return merged
end

return function(opts)
  assert(__DEFAULT__)
  if vim.fn.executable('atuin') ~= 1 then
    require('fzf-lua.utils').warn("'atuin' executable not found in $PATH (https://atuin.sh)")
    return
  end
  ---@type fle.config.Atuin
  local resolved = merge_opts(opts)
  ---@diagnostic disable-next-line: param-type-mismatch
  return FzfLua.fzf_live(build_cmd(resolved), resolved)
end
