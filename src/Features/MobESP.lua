-- ============================================================================
-- MOB ESP - ESP para mobs com vida real
-- ============================================================================

local MobESP = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local Cache = require(script.Parent.Parent.Engine.Cache)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Detection = require(script.Parent.Parent.Utils.Detection)

local Players = Constants.Services.Players
local ReplicatedStorage = Constants.Services.ReplicatedStorage

local UpdateWorld = ReplicatedStorage:WaitForChild("UpdateWorld", 10)

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function createHealthESP(model, name)
    if not model then return nil end
    if Cache.PlayerMobESP[model] and Cache.PlayerMobESP[model].healthBB then
        return Cache.PlayerMobESP[model]
    end

    local part = Helpers.GetPrimaryPart(model)
    if not part then return nil end

    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthESP"
    bb.Adornee = part
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(160, 40)
    bb.StudsOffset = Vector3.new(0, Helpers.GetYOffset(part), 0)
    bb.Parent = part

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Text = name .. " | ??? ❤"
    text.Parent = frame

    if not Cache.PlayerMobESP[model] then
        Cache.PlayerMobESP[model] = {}
    end
    Cache.PlayerMobESP[model].healthBB = bb
    Cache.PlayerMobESP[model].healthLabel = text
    Cache.PlayerMobESP[model].name = name

    return Cache.PlayerMobESP[model]
end

local function updateHealthESP(model, health, maxHealth)
    local esp = Cache.PlayerMobESP[model]
    if not esp or not esp.healthLabel then return end
    
    local name = esp.name or model.Name
    local healthText = tostring(math.floor(health))
    
    if maxHealth and maxHealth > 0 then
        healthText = healthText .. "/" .. tostring(math.floor(maxHealth))
    end
    
    esp.healthLabel.Text = name .. " | " .. healthText .. " ❤"

    local percent = maxHealth and (health / maxHealth) or 1
    if percent <= 0.25 then
        esp.healthLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif percent <= 0.5 then
        esp.healthLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    else
        esp.healthLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
    end
end

local function createHighlight(model)
    if Cache.PlayerMobESP[model] and Cache.PlayerMobESP[model].highlight then
        return
    end

    local hl = Instance.new("Highlight")
    hl.Name = "MobESP"
    hl.FillColor = Color3.fromRGB(255, 200, 0)
    hl.OutlineColor = Color3.fromRGB(255, 150, 0)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model
    hl.Parent = model
    
    if not Cache.PlayerMobESP[model] then
        Cache.PlayerMobESP[model] = {}
    end
    Cache.PlayerMobESP[model].highlight = hl
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function MobESP:Initialize()
    if not UpdateWorld then
        warn("⚠️ UpdateWorld não encontrado - vida real desativada")
        return
    end

    ConnectionManager:Add("updateWorldMobs", UpdateWorld.OnClientEvent:Connect(function(data)
        if not Config.ShowHealth or not Config.MobESP then return end
        if Config.SafeMode then return end
        if typeof(data) ~= "table" then return end

        if data.chunks then
            for _, chunk in ipairs(data.chunks) do
                local chunkData = chunk[3]
                if chunkData and chunkData.entitydata then
                    for _, ent in ipairs(chunkData.entitydata) do
                        if ent.UUID and ent.Health and ent.id then
                            -- Buscar na pasta Entities
                            local entitiesFolder = workspace:FindFirstChild("Entities")
                            if entitiesFolder then
                                for _, model in ipairs(entitiesFolder:GetChildren()) do
                                    if model:IsA("Model") and model.Name == ent.id then
                                        if not Detection.IsItem(model) then
                                            local esp = createHealthESP(model, ent.id)
                                            if esp then
                                                updateHealthESP(model, ent.Health, ent.MaxHealth or 20)
                                            end
                                            
                                            createHighlight(model)
                                            
                                            Cache.RealHealth[model] = {
                                                health = ent.Health,
                                                maxHealth = ent.MaxHealth or 20,
                                                lastUpdate = tick()
                                            }
                                        end
                                    end
                                end
                            end
                            
                            -- Buscar também no workspace direto
                            for _, model in ipairs(workspace:GetChildren()) do
                                if model:IsA("Model") and model.Name == ent.id then
                                    if not Detection.IsItem(model) then
                                        local esp = createHealthESP(model, ent.id)
                                        if esp then
                                            updateHealthESP(model, ent.Health, ent.MaxHealth or 20)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end), "health")
    
    print("✅ MobESP inicializado - vida real ativa!")
end

function MobESP:Remove(model)
    if Cache.PlayerMobESP[model] then
        if Cache.PlayerMobESP[model].healthBB then
            Cache.PlayerMobESP[model].healthBB:Destroy()
        end
        if Cache.PlayerMobESP[model].highlight then
            Cache.PlayerMobESP[model].highlight:Destroy()
        end
        Cache.PlayerMobESP[model] = nil
    end
end

function MobESP:Clear()
    for model in pairs(Cache.PlayerMobESP) do
        if not model or not model.Parent then
            self:Remove(model)
        elseif not Players:GetPlayerFromCharacter(model) and not Detection.IsItem(model) then
            if not Config.MobESP then
                self:Remove(model)
            end
        end
    end
end

function MobESP:Cleanup()
    for model in pairs(Cache.PlayerMobESP) do
        if not model or not model.Parent then
            self:Remove(model)
        end
    end
end

return MobESP