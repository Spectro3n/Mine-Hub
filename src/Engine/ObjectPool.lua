-- ============================================================================
-- OBJECT POOL - Reutilização de objetos para performance
-- ============================================================================

local ObjectPool = {
    _pools = {},
    _maxSize = 50,
}

function ObjectPool:Get(className)
    if not self._pools[className] then
        self._pools[className] = {}
    end
    local pool = self._pools[className]
    if #pool > 0 then
        return table.remove(pool)
    end
    return Instance.new(className)
end

function ObjectPool:Return(className, obj)
    if not obj then return end
    if not self._pools[className] then
        self._pools[className] = {}
    end
    obj.Parent = nil
    if #self._pools[className] < self._maxSize then
        table.insert(self._pools[className], obj)
    else
        obj:Destroy()
    end
end

function ObjectPool:ClearAll()
    for className, pool in pairs(self._pools) do
        for _, obj in ipairs(pool) do
            obj:Destroy()
        end
    end
    self._pools = {}
end

return ObjectPool