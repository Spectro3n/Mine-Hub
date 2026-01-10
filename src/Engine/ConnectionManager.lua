-- ============================================================================
-- CONNECTION MANAGER
-- ============================================================================

local ConnectionManager = {
    _connections = {},
    _categories = {},
}

function ConnectionManager:Add(name, connection, category)
    category = category or "general"
    
    if self._connections[name] then
        pcall(function()
            self._connections[name]:Disconnect()
        end)
    end
    
    self._connections[name] = connection
    
    if not self._categories[category] then
        self._categories[category] = {}
    end
    self._categories[category][name] = true
end

function ConnectionManager:Remove(name)
    if self._connections[name] then
        pcall(function()
            self._connections[name]:Disconnect()
        end)
        self._connections[name] = nil
        
        for _, names in pairs(self._categories) do
            names[name] = nil
        end
    end
end

function ConnectionManager:RemoveCategory(category)
    if not self._categories[category] then return end
    
    for name in pairs(self._categories[category]) do
        if self._connections[name] then
            pcall(function()
                self._connections[name]:Disconnect()
            end)
            self._connections[name] = nil
        end
    end
    
    self._categories[category] = {}
end

function ConnectionManager:RemoveAll()
    for _, conn in pairs(self._connections) do
        pcall(function()
            if conn then conn:Disconnect() end
        end)
    end
    self._connections = {}
    self._categories = {}
end

function ConnectionManager:Has(name)
    return self._connections[name] ~= nil
end

function ConnectionManager:GetCount()
    local count = 0
    for _ in pairs(self._connections) do
        count = count + 1
    end
    return count
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.ConnectionManager = ConnectionManager

return ConnectionManager