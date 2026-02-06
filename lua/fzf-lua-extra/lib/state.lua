local Ordered = require('fzf-lua-extra.lib.ordered')
local Cyclic = require('fzf-lua-extra.lib.cyclic')

---V can be any..
---@class fle.CycOrdered<K, V>: fle.Cyclic<K, V>, fle.Ordered<K, V>
local CycOrdered = function() return Cyclic.from_iter(Ordered.new()) end

---@alias fle.uuid any
---@class fle.State<K, V>
---@field private map fle.Ordered<fle.uuid, fle.CycOrdered<K, V>>
local M = {}

M.__index = M

M.new = function()
  local obj = { map = Ordered.new() } ---@type fle.State
  return setmetatable(obj, M)
end

---@param id? fle.uuid
---@param k K
---@param v V
function M:put(id, k, v)
  id = id or assert(self.map:next(), 'No map available')
  local kv = self.map:get(id)
  if kv then
    kv:put(k, v)
  else
    kv = CycOrdered()
    kv:put(k, v)
    kv:next()
    self.map:put(id, kv)
  end
end

---@param id? fle.uuid
---@param k? K
---@return V?, K?
function M:get(id, k)
  id = id or assert(self.map:next(), 'No map available')
  local kv = self.map:get(id)
  if not kv then return end
  return kv:get(k)
end

---@param id? fle.uuid
function M:cycle(id)
  id = id or assert(self.map:next(), 'No map available')
  local kv = assert(self.map:get(id), 'No such map')
  return kv:next()
end

return M
