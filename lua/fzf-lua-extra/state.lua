---@class fle.State
---@field private iterables table<string, table<string, any>> iterator
---@field private keys table<string, string>
local M = {}

M.__index = M

M.new = function()
  return setmetatable({
    iterables = {},
    keys = {},
  }, M)
end

---@param ns string
---@param k any
---@param v any
function M:put(ns, k, v)
  if not self.iterables[ns] then
    self.iterables[ns] = {}
    self.keys[ns] = k
  end
  self.iterables[ns][k] = v
end

---@param ns? string
function M:cycle(ns)
  ns = ns or assert(next(self.iterables), 'No namespaces available to cycle')
  local iters = self.iterables[ns]
  local key = self.keys[ns]
  local nextkey = next(iters, key)
  if nextkey == nil then nextkey = next(iters) end
  self.keys[ns] = nextkey
end

---@param ns? string
---@return any, string
function M:get(ns)
  ns = ns or assert(next(self.iterables), 'No namespaces available to get')
  local key = assert(self.keys[ns])
  return self.iterables[ns][key], key
end

return M
