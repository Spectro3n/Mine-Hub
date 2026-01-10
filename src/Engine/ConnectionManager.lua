-- ============================================================================
-- CONNECTION MANAGER - Gerenciamento centralizado de conexões
-- ============================================================================

local ConnectionManager = {
    _connections = {},
    _categories = {},
}

function ConnectionManager:Add(name, connection, category)
    category = category or "general"
    if self._connections[name] then
        self._connections[name]:Disconnect()
    end
    self._connections[name] = connection
    if not self._categories[category] then
        self._categories[category] = {}
    end
    self._categories[category][name] = true
end

function ConnectionManager:Remove(name)
    if self._connections[name] then
        self._connections[name]:Disconnect()
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
            self._connections[name]:Disconnect()
            self._connections[name] = nil
        end
    end
    self._categories[category] = {}
end

function ConnectionManager:RemoveAll()
    for _, conn in pairs(self._connections) do
        if conn then conn:Disconnect() end
    end
    self._connections = {}
    self._categories = {}
end

return ConnectionManager