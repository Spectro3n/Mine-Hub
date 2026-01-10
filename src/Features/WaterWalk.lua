-- ============================================================================
-- WATER WALK - Andar sobre água (FIXED)
-- ============================================================================

local WaterWalk = {}

local Config, Constants, ConnectionManager, Detection
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local waterWalkActive = false
local originalSwimmingState = true

-- ============================================================================
-- DETECÇÃO DE LÍQUIDO LOCAL
-- ============================================================================
local LIQUID_KEYWORDS = {
    "Still", "Falling", "1", "1T", "2", "2T", "3", "3T",
    "4", "4T", "5", "5T", "6", "6T", "7", "7T", "7F",
    "1i", "2i", "3i", "4i", "5i", "6i", "7i",
}

local function isLiquidBlock(part)
    if not part or not part:IsA("BasePart") then return false end
    local name = part.Name
    
    for _, keyword in ipairs(LIQUID_KEYWORDS) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end
    
    if string.match(name, "^%d+[TiFtF]?$") then
        return true
    end
    
    if part.Material == Enum.Material.Water then
        return true
    end
    
    return false
end

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function updateWaterWalkPosition()
    if not Config or not Config.WaterWalk then return end
    
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(
        hrp.Position,
        Vector3.new(0, -8, 0),
        rayParams
    )

    if result and isLiquidBlock(result.Instance) then
        local targetY = result.Position.Y + 2.8
        
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X,
            0,
            hrp.AssemblyLinearVelocity.Z
        )
        
        hrp.CFrame = CFrame.new(
            hrp.Position.X,
            targetY,
            hrp.Position.Z
        ) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
        
        if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function WaterWalk:Enable()
    Config = self._Config or Config
    ConnectionManager = self._ConnectionManager or ConnectionManager
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        originalSwimmingState = humanoid:GetStateEnabled(Enum.HumanoidStateType.Swimming)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    end
    
    waterWalkActive = true
    
    ConnectionManager:Add("waterWalkUpdate", RunService.RenderStepped:Connect(updateWaterWalkPosition), "waterWalk")
    
    print("🌊 Water Walk Ativado (sem bug de câmera!)")
end

function WaterWalk:Disable()
    ConnectionManager = self._ConnectionManager or ConnectionManager
    
    ConnectionManager:RemoveCategory("waterWalk")
    waterWalkActive = false
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, originalSwimmingState)
    end
    
    print("🌊 Water Walk Desativado")
end

function WaterWalk:Toggle(state)
    Config = self._Config or Config
    Config.WaterWalk = state
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

function WaterWalk:OnCharacterAdded()
    Config = self._Config or Config
    
    player.CharacterAdded:Connect(function(char)
        if Config and Config.WaterWalk then
            task.wait(0.5)
            self:Disable()
            self:Enable()
        end
    end)
end

return WaterWalk