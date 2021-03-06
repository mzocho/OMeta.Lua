
local tostring, tonumber, select, type, getmetatable, setmetatable, rawget
    = tostring, tonumber, select, type, getmetatable, setmetatable, rawget

local Any, Array

local __instances = {}

local term, toTree, used = true
toTree = function(levelprefix, subtree)
  local result = ''
  local al, ml = 0, 0
  if used[subtree] then
    return false
  end
  local copy = {}
  used[subtree] = copy
  for k, v in pairs(subtree) do
    if type(k) == 'number' then 
      al = al + 1
      copy[k] = v
    elseif type(k) == 'string' then 
      if k:sub(1, 1) ~= '_' then
        ml = ml + 1 
        copy[k] = v
      end
    end
  end
  for k, v in pairs(copy) do
    local hasnext = next(copy, k)
    local pf = levelprefix .. (hasnext and (term and '\195\196' or '+-') or (term and '\192\196' or '--'))
    if type(v) == 'table' then
      local mt = getmetatable(v)
      local nt = mt and mt.name or '[table]'
      local nested, aln, mln = toTree(levelprefix .. (hasnext and (term and '\179 ' or '| ') or '  '), v)
      if nested then
        result = result .. (pf .. ((aln + mln == 0) and (term and '\205' or '-') or (term and '\203' or '+')) .. ' ' .. k .. ': ' .. nt .. ' (' .. tostring(aln) .. '/' .. tostring(mln) .. ')\n') .. nested
      else
        result = result .. (pf .. (term and '\205' or '-') .. ' ' .. k .. ': ' .. nt .. ' (<recursion>)\n')
      end
    else
      result = result .. (pf .. (term and '\205' or '-') .. ' ' .. k .. ': ' .. tostring(v)) .. '\n'
    end
  end
  return result, al, ml
end


local typetemp = {

  tostring = function(self)
    return 'type: ' .. self.name
  end;
  
  dispatch = function(self, index) 
    for i = 2, #self.linearization do
      local f = rawget(self.linearization[i], index)
      if f then return f end
    end
  end;
  
  constructor = function(self, ...)
    local instance = self.constructor and self.constructor(self, ...) or select(1, ...) or {}
    setmetatable(instance, self.metatable)
    __instances[self] = __instances[self] + 1
    return instance
  end;
}

local instancetemp = {

  tostring = function(self)
    local p = (term and '\201' or '=') .. ' ' .. getmetatable(self).name .. ':\n'
    used = {}
    return p .. toTree('', self)
  end;    
}

local function newtype(typeinit)

  typeinit.isType = true
  local name, super = typeinit.name, typeinit.super or {}
  
  if typeinit.abstract == nil then typeinit.abstract = false end
  __instances[typeinit] = 0
  
  local linearization = {typeinit}
  if #super ~= 0 then
    if #super == 1 then
      for i = 1, #super[1].linearization do
        linearization[1 + i] = super[1].linearization[i]
      end
    else
      local slsn, slsd, sls, lsn = {}, {}, {}, #super
      for si = 1, lsn do
        sls[si] = super[si].linearization
        slsn[si] = #sls[si]
        slsd[si] = 0
      end
      sls[lsn + 1] = super
      slsn[lsn + 1] = #super
      slsd[lsn + 1] = 0
      repeat
        local empty, dlock = true, true
        for si = 1, lsn + 1 do
          if slsn[si] ~= 0 then
            empty = false
            local head, fail = sls[si][slsd[si] + 1], false
            local rem = {si}
            for sii = 1, lsn + 1 do
              if sii ~= si and slsn[sii] ~= 0 then
                for sli = 1, slsn[sii] do
                  if sls[sii][slsd[sii] + sli] == head then
                    if sli == 1 then
                      rem[#rem + 1] = sii
                    else
                      fail = true
                      break
                    end
                  end
                end
                if fail then break end
              end
            end
            if not fail then
              for ri = 1, #rem do
                local sii = rem[ri]
                slsd[sii] = slsd[sii] + 1
                slsn[sii] = slsn[sii] - 1
              end
              linearization[#linearization + 1] = head
              dlock = false
              break
            end
          end
        end
        assert(not dlock or empty, 'Linearization for type ' .. name .. ' failed')
      until empty
    end
  end
  typeinit.linearization = linearization

  local instancemt = {
    __index = typeinit,
    __tostring = instancetemp.tostring,
    
    -- non standard
    name = name,
    type = typeinit;
  }
  typeinit.metatable = instancemt  
  local typemt = {
    __tostring = typetemp.tostring
  }
  if #super ~= 0 then typemt.__index = (#super == 1 and super[1] or typetemp.dispatch) end
  if not typetemp.abstract then typemt.__call = typetemp.constructor end
  setmetatable(typeinit, typemt)
  
  return typeinit
end

Any = newtype {

  abstract = true,
  name = 'Any',
  super = {};

  constructor = function(type, init)
    return init
  end;

  conformsTo = function(self, other)
    for li = 1, #self.linearization do
      if self.linearization[li] == other then
        return true
      end
    end
    return false
  end;
  
  isInstance = function(self, instance)
    local mt = getmetatable(instance)
    local _type = mt and mt.__index
    return _type and type(_type) == 'table' and _type.conformsTo and _type:conformsTo(self) or false
  end;
}

Array = newtype {

  name = 'Array', 
  abstract = false,
  super = {Any};

  at = function(self, i)
    return self[i]
  end,
  
  --append = function(self, e)
    --self[#self + 1] = e
  append = function(self, ...)
    local len = #self
    for i = 1, select('#', ...) do
      len = len + 1
      self[len] = select(i, ...)
    end
    return self
  end,
  
  --prepend = function(self, e)
    --table.insert(self, 1, e)
  prepend = function(self, ...)
    for i = 1, select('#', ...) do
      table.insert(self, i, (select(i, ...)))
    end
    return self
  end,
  
  including = function(self, e)
    local clone = Array {}
    for i = 1, #self do clone[i] = self[i] end
    clone[#clone + 1] = e
    return clone
  end,
  
  concat = function(self, sep)
    local r = ''
    for i = 1, #self do
      local v = self[i]
      if sep and i ~= 1 then r = r .. sep end
      r = r .. tostring(v)
    end
    return r
  end,
  
  sub = function(self, from, to, chars)
    chars = true --TODO: remove
    from = from or 1
    if from < 0 then from = #self + from + 1 end
    to = to or #self
    if to < 0 then to = #self + to + 1 end
    local sub, len = Array {}, 0
    for i = from, to do
      local e = self[i]
      if chars and (type(e) ~= 'string' or #e ~= 1) then chars = false end
      len = len + 1
      sub[len] = e
    end
    return chars and sub:concat() or sub
  end,
  
  appendAll = function(self, array)
    for i = 1, #array do
      --self:append(array[i])
      self[#self + 1] = array[i]
    end
    return self
  end,
  
  prependAll = function(self, array)
    local len = #array
    if len ~= 0 then
      for i = #self, 1, -1 do
        self[i + len] = self[i]
      end
      for i = 1, len do
        self[i] = array[i]
      end
    end
    return self
  end,
  
  flatten = function(self)
    local array = Array {}
    for i = 1, #self do
      local e = self[i]
      if Array:isInstance(e) then
        array:appendAll(e:flatten())
      elseif not Any:isInstance(e) and type(e) == 'table' then
        array:appendAll(Array.flatten(e))
      else
        array:append(e)
      end
    end
    return array
  end,
  
  applyMethod = function(self, name, ...)
    local res = Array {}
    for i = 1, #self do
      res[i] = self[i][name](self[i], ...)
    end
    return res
  end,
  
  applyFunction = function(self, fn, ...)
    local res = Array {}
    for i = 1, #self do
      res[i] = fn(self[i], ...)
    end
    return res
  end
}

local function typestat()
  local klen, vlen, kvlen, sum = 0, 0, 0, 0
  local vall = {}
  local tall = {}
  for k, v in pairs(__instances) do
    for p = 1, #k.linearization do
      local parent = k.linearization[p]
      if not vall[parent] then 
        vall[parent] = v 
      else
        vall[parent] = vall[parent] + v
      end
    end
    tall[#tall + 1] = k
    klen, vlen, kvlen, sum = math.max(klen, #k.name), math.max(vlen, #tostring(v)), math.max(kvlen, #k.name + #tostring(v)), sum + v
  end
  table.sort(tall, function(t1, t2) return __instances[t1] > __instances[t2] end)
  local sumlen = #tostring(sum)
  for i = 1, #tall do
    local k = tall[i]
    local v = __instances[k]
    local direct, all = k.abstract and '-' or tostring(v), tostring(vall[k])
    --print(k.name .. ' ' .. string.rep('.', klen - #k.name) .. '.'  .. string.rep('.', vlen - #direct) .. direct .. (direct ~= all and all ~= '0' and ' ' .. string.rep(' ', sumlen - #all) .. '(' .. all .. ')' or ''))
    local spcs = kvlen - #k.name - #direct + 1
    print(k.name .. string.rep(' ', spcs) .. direct .. (direct ~= all and all ~= '0' and string.rep(' ', sumlen - #all) .. ' (' .. all .. ')' or ''))
  end
end

getType = function(obj)
  return getmetatable(obj).type
end

return {
  dataType = newtype,
  primitive = newtype,
  class = newtype;
  
  typestat = typestat;

  Any = Any,
  Array = Array;
}
