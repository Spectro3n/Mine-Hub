-- ============================================================================
-- OBJECT POOL
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
    
    pcall(function()
        obj.Parent = nil
    end)
    
    if #self._pools[className] < self._maxSize then
        table.insert(self._pools[className], obj)
    else
        pcall(function()
            obj:Destroy()
        end)
    end
end

function ObjectPool:ClearAll()
    for className, pool in pairs(self._pools) do
        for _, obj in ipairs(pool) do
            pcall(function()
                obj:Destroy()
            end)
        end
    end
    self._pools = {}
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.ObjectPool = ObjectPool

return ObjectPool