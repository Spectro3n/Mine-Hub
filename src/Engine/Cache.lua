-- ============================================================================
-- CACHE
-- ============================================================================

local Players = game:GetService("Players")

local Cache = {
    CameraPosition = Vector3.zero,
    LocalPlayer = Players.LocalPlayer,
    Character = nil,
    HumanoidRootPart = nil,
    Humanoid = nil,
    LastUpdate = 0,
    UpdateInterval = 0.05,
    RealHealth = {},
    MineralResults = setmetatable({}, {__mode = "k"}),
}

function Cache:Update()
    local now = tick()
    if now - self.LastUpdate < self.UpdateInterval then 
        return false 
    end
    
    self.LastUpdate = now
    
    local camera = workspace.CurrentCamera
    if camera then
        self.CameraPosition = camera.CFrame.Position
    end
    
    local char = self.LocalPlayer and self.LocalPlayer.Character
    if char then
        self.Character = char
        self.HumanoidRootPart = char:FindFirstChild("HumanoidRootPart")
        self.Humanoid = char:FindFirstChildOfClass("Humanoid")
    else
        self.Character = nil
        self.HumanoidRootPart = nil
        self.Humanoid = nil
    end
    
    return true
end

function Cache:GetDistanceFromCamera(position)
    return (position - self.CameraPosition).Magnitude
end

function Cache:SetRealHealth(model, health, maxHealth)
    self.RealHealth[model] = {
        health = health,
        maxHealth = maxHealth or 20,
        lastUpdate = tick()
    }
end

function Cache:GetRealHealth(model)
    return self.RealHealth[model]
end

function Cache:ClearRealHealth(model)
    if model then
        self.RealHealth[model] = nil
    else
        self.RealHealth = {}
    end
end

function Cache:ClearMineralResults()
    self.MineralResults = setmetatable({}, {__mode = "k"})
end

function Cache:ClearAll()
    self.RealHealth = {}
    self.MineralResults = setmetatable({}, {__mode = "k"})
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.Cache = Cache

return Cache