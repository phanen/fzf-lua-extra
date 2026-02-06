local Ordered = require('fzf-lua-extra.lib.ordered')
local Cyclic = require('fzf-lua-extra.lib.cyclic')
local State = require('fzf-lua-extra.lib.state')

local eq = assert.are.equal

describe('ordered', function()
  it('put && get', function()
    local o = Ordered.new()
    o:put('key1', 'value1')
    o:put(123, true)
    local table_key = {}
    o:put(table_key, 'table_value')

    eq('value1', o:get('key1'))
    eq('key1', select(2, o:get('key1')))

    eq(true, o:get(123))
    eq(123, select(2, o:get(123)))

    eq('table_value', o:get(table_key))
    eq(table_key, select(2, o:get(table_key)))
    -- eq(3, o:__len())
    -- __len don't work in 5.1
    eq(table.maxn(o), #o)
  end)

  it('next', function()
    local o = Ordered.new()
    o:put('a', 1)
    o:put('b', 2)
    o:put('c', 3)

    -- Test sequence 'a' -> 'b' -> 'c' -> 'a'
    local k1, v1 = o:next('a')
    eq('b', k1)
    eq(2, v1)

    local k2, v2 = o:next('b')
    eq('c', k2)
    eq(3, v2)

    local k3, v3 = o:next('c')
    eq(nil, k3)
    eq(nil, v3)

    local k, v = o:next(nil)
    eq('a', k)
    eq(1, v)

    -- Test non-existent key should throw an error
    assert.error(function() o:next('d') end, 'Invalid key: d')
    assert.error(function() o:next('false') end, 'Invalid key: false')

    -- Test with table key and wrap around
    local table_key = {}
    o:put(table_key, 'table_value')
    local k4, v4 = o:next(table_key) -- next after table_key should be nil
    eq(nil, k4)
    eq(nil, v4)

    -- Test starting from 'a' again after table_key
    local k5, v5 = o:next('a')
    eq('b', k5)
    eq(2, v5)
  end)
end)

describe('cyclic', function()
  local cyclic ---@type fle.Cyclic<any, any>

  before_each(function()
    local iter = Ordered.new() ---@type fle.Ordered<any, any>
    cyclic = Cyclic.from_iter(iter)
  end)

  it('put & get & cycle', function()
    cyclic:put('a', 1)
    cyclic:put('b', 2)
    eq(nil, cyclic:get())
    eq(1, cyclic:get('a'))
    eq(2, cyclic:get('b'))

    cyclic:next()
    eq(1, cyclic:get())

    cyclic:next()
    eq(2, cyclic:get())
  end)

  it('empty', function()
    eq(nil, cyclic:next())
    eq(nil, cyclic:get())
    cyclic:put('x', 10)
    eq('x', cyclic:next())
    eq(10, cyclic:get())
    cyclic:put('y', 20)
  end)

  it('error when put nil key without current key', function()
    assert.error(function() cyclic:put(nil, 1) end, 'table index is nil')
  end)
end)

describe('state', function()
  local state ---@type fle.State<any, any>

  before_each(function() state = State.new() end)

  it('put & get', function()
    state:put('map1', 'k1', 'v1')
    state:put('map1', 'k2', 'v2')
    state:put('map2', 'kA', 'vA')

    eq('v1', state:get('map1', 'k1'))
    eq('v2', state:get('map1', 'k2'))
    eq('vA', state:get('map2', 'kA'))
  end)

  it('empty', function()
    assert.error(function() state:put(nil, 'k1', 'v1') end, 'No map available')
    assert.error(function() eq('v1', state:get(nil, 'k1')) end, 'No map available')
  end)

  it('cycle', function()
    -- state:cycle()
    state:put('foo', 'a', 1)
    state:put('foo', 'b', 2)
    state:put('foo', 'c', 2)
    eq(1, state:get())
    eq(1, state:get('foo'))
    eq(1, state:get('foo', 'a'))
    eq('a', select(2, state:get()))
    eq('a', select(2, state:get('foo')))
    eq('a', select(2, state:get('foo', 'a')))

    local k, v = state:cycle('foo')
    eq('b', k)
    eq(2, v)

    k, v = state:cycle('foo')
    eq('c', k)
    eq(2, v)

    k, v = state:cycle('foo')
    eq('a', k)
    eq(1, v)
  end)
end)
