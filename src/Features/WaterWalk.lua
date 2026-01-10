-- ============================================================================
-- WATER WALK - Andar sobre água (FIXED - sem bug de câmera)
-- ============================================================================

local WaterWalk = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)
local Detection = require(script.Parent.Parent.Utils.Detection)

local Players = Constants.Services.Players
local RunService = Constants.Services.RunService
local player = Players.LocalPlayer

local waterWalkActive = false
local originalSwimmingState = true

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function updateWaterWalkPosition()
    if not Config.WaterWalk then return end
    
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

    if result and Detection.IsLiquidBlock(result.Instance) then
        local targetY = result.Position.Y + 2.8
        
        -- ✅ CORREÇÃO 1: Cancelar velocidade vertical (sem empuxo)
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X,
            0,
            hrp.AssemblyLinearVelocity.Z
        )
        
        -- ✅ CORREÇÃO 2: Travar Y sem colisão física
        hrp.CFrame = CFrame.new(
            hrp.Position.X,
            targetY,
            hrp.Position.Z
        ) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
        
        -- ✅ CORREÇÃO 3: Forçar estado de corrida
        if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function WaterWalk:Enable()
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        -- ✅ Desativar natação completamente
        originalSwimmingState = humanoid:GetStateEnabled(Enum.HumanoidStateType.Swimming)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    end
    
    waterWalkActive = true
    
    -- Loop de posicionamento
    ConnectionManager:Add("waterWalkUpdate", RunService.RenderStepped:Connect(updateWaterWalkPosition), "waterWalk")
    
    print("🌊 Water Walk Ativado (sem bug de câmera!)")
end

function WaterWalk:Disable()
    ConnectionManager:RemoveCategory("waterWalk")
    waterWalkActive = false
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        -- ✅ Restaurar natação
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, originalSwimmingState)
    end
    
    print("🌊 Water Walk Desativado")
end

function WaterWalk:Toggle(state)
    Config.WaterWalk = state
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

function WaterWalk:OnCharacterAdded()
    -- Reconectar quando personagem respawna
    player.CharacterAdded:Connect(function(char)
        if Config.WaterWalk then
            task.wait(0.5)
            self:Disable()
            self:Enable()
        end
    end)
end

return WaterWalk