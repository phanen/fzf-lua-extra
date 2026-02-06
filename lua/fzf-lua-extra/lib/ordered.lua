local KV = 1
local ORD = 2
local KIDX = 3

---ordered table/dict
---@class fle.Ordered<K, V>: fle.Iter<K, V>, fle.KV<K, V>
---@field private [1] table<K, V>
---@field private [2] K[]
---@field private [3] table<K, integer>
local M = {}
M.__index = M

---@return fle.Ordered
M.new = function()
  local obj = { [KV] = {}, [ORD] = {}, [KIDX] = {} } ---@type fle.Ordered
  return setmetatable(obj, M)
end

---@param k K
---@return V?, K?
function M:get(k)
  local kv = self[KV]
  return kv[k], k
end

---@param k K
---@param v V
function M:put(k, v)
  local kv = self[KV]
  kv[k] = v

  local ord = self[ORD]
  local idx = #ord + 1
  ord[idx] = k

  local kidx = self[KIDX]
  kidx[k] = idx
end

---@param k? K
---@return K?, V?
function M:next(k)
  local idx

  if k == nil then
    idx = 1
  else
    local kidx = self[KIDX]
    idx = kidx[k]
    if not idx then error('Invalid key: ' .. tostring(k)) end
    idx = idx + 1
  end

  local ord = self[ORD]
  local nextk = ord[idx]
  -- if not nextk then return nil, nil end
  return nextk, (self:get(nextk))
end

return M
