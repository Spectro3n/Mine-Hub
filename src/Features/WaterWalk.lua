-- ============================================================================
-- WATER WALK
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local ConnectionManager = require("Engine/ConnectionManager")
local Detection = require("Utils/Detection")
local Notifications = require("UI/Notifications")

local WaterWalk = {
    _active = false,
    _originalSwimmingState = true,
}

local player = Players.LocalPlayer

local function updatePosition()
    if not Config.WaterWalk then return end
    
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0), rayParams)

    if result and Detection.IsLiquidBlock(result.Instance) then
        local targetY = result.Position.Y + 2.8
        
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X,
            0,
            hrp.AssemblyLinearVelocity.Z
        )
        
        hrp.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
        
        if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

function WaterWalk:Enable()
    if self._active then return end
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        self._originalSwimmingState = humanoid:GetStateEnabled(Enum.HumanoidStateType.Swimming)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    end
    
    self._active = true
    ConnectionManager:Add("waterWalkUpdate", RunService.RenderStepped:Connect(updatePosition), "waterWalk")
    Notifications:Send("🌊 Water Walk", "Ativado!", 2)
end

function WaterWalk:Disable()
    if not self._active then return end
    
    ConnectionManager:RemoveCategory("waterWalk")
    self._active = false
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, self._originalSwimmingState)
    end
    
    Notifications:Send("🌊 Water Walk", "Desativado", 2)
end

function WaterWalk:Toggle(state)
    Config.WaterWalk = state
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

function WaterWalk:IsActive()
    return self._active
end

player.CharacterAdded:Connect(function()
    if Config.WaterWalk then
        task.wait(0.5)
        WaterWalk:Disable()
        WaterWalk:Enable()
    end
end)

_G.MineHub = _G.MineHub or {}
_G.MineHub.WaterWalk = WaterWalk

return WaterWalk