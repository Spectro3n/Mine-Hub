-- ============================================================================
-- CACHE SYSTEM - Sistema de cache para valores computados
-- ============================================================================

local Cache = {
    -- Cache de valores
    CameraPosition = Vector3.zero,
    LastUpdate = 0,
    UpdateInterval = 0.05,
    
    -- Caches de objetos
    Parts = {},
    Decals = {},
    Highlights = {},
    Billboards = {},
    MineralResults = setmetatable({}, {__mode = "k"}),
    
    -- ESP Caches
    AdminESP = {},
    AdminsOnline = {},
    PlayerMobESP = {},
    ItemESP = {},
    HitboxESP = {},
    OriginalSizes = {},
    
    -- Health Cache (UpdateWorld)
    RealHealth = {},  -- [model] = {health, maxHealth, lastUpdate}
}

function Cache:UpdateCameraPosition()
    local now = tick()
    if now - self.LastUpdate < self.UpdateInterval then return end
    self.LastUpdate = now
    
    local camera = workspace.CurrentCamera
    if camera then
        self.CameraPosition = camera.CFrame.Position
    end
end

function Cache:GetDistanceFromCamera(position)
    return (position - self.CameraPosition).Magnitude
end

function Cache:SafeTableClear(tbl, cleanupFunc)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    for _, key in ipairs(keys) do
        local value = tbl[key]
        if cleanupFunc then
            pcall(cleanupFunc, key, value)
        end
        tbl[key] = nil
    end
end

function Cache:ClearAll()
    self:SafeTableClear(self.Parts)
    self:SafeTableClear(self.Decals)
    self:SafeTableClear(self.Highlights)
    self:SafeTableClear(self.Billboards)
    self:SafeTableClear(self.AdminESP)
    self:SafeTableClear(self.PlayerMobESP)
    self:SafeTableClear(self.ItemESP)
    self:SafeTableClear(self.HitboxESP)
    self:SafeTableClear(self.OriginalSizes)
    self.MineralResults = setmetatable({}, {__mode = "k"})
end

return Cache