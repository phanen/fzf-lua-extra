---@class fle.KV<K, V>
---@field put fun(self: fle.Iter<K, V>, k: K, v: V)
---@field get fun(self: fle.Iter<K, V>, k?: K): V?, K?

---statusless, kv..
---@class fle.Iter<K, V>: fle.KV<K, V>
---@field next fun(self: fle.Iter<K, V>, k?: K): K, V

---cyclic iterator, have pointer to last iterated key
---@class fle.Cyclic<K, V>: fle.Iter<K, V>
---@field private iter fle.Iter<K, V>
---@field private k K
local M = {}

M.__index = M

---@param iter fle.Iter<K, V>
---@return fle.Cyclic<K, V>
M.from_iter = function(iter)
  local obj = { iter = iter } ---@as fle.Cyclic<K, V>
  return setmetatable(obj, M)
end

---@param k? K
---@return V?, K?
function M:get(k)
  k = k or self.k
  return self.iter:get(k)
end

---@param k? K
---@param v V
function M:put(k, v)
  local iter = self.iter
  iter:put(k or self.k, v)
end

---@param k? K
---@return K?, V?
function M:next(k)
  local iter = self.iter
  local nextk, v = iter:next(k or self.k)
  if nextk == nil then
    nextk, v = iter:next()
    assert(nextk ~= nil, 'no elements')
  end
  self.k = nextk
  return nextk, v
end

return M
