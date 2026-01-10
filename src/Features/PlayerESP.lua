-- ============================================================================
-- PLAYER ESP - ESP para jogadores com vida real
-- ============================================================================

local PlayerESP = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local Cache = require(script.Parent.Parent.Engine.Cache)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)
local Helpers = require(script.Parent.Parent.Utils.Helpers)

local Players = Constants.Services.Players
local RunService = Constants.Services.RunService
local ReplicatedStorage = Constants.Services.ReplicatedStorage
local player = Players.LocalPlayer

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
    hl.Name = "PlayerESP"
    hl.FillColor = Color3.fromRGB(0, 255, 255)
    hl.OutlineColor = Color3.fromRGB(0, 200, 255)
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
function PlayerESP:Initialize()
    if not UpdateWorld then
        warn("⚠️ UpdateWorld não encontrado - vida real desativada")
        return
    end

    ConnectionManager:Add("updateWorldPlayers", UpdateWorld.OnClientEvent:Connect(function(data)
        if not Config.ShowHealth or not Config.PlayerESP then return end
        if Config.SafeMode then return end
        if typeof(data) ~= "table" then return end

        if data.players then
            for _, info in ipairs(data.players) do
                if info.Player and info.Health then
                    local plr = info.Player
                    if plr ~= player then
                        local char = plr.Character
                        if char then
                            local esp = createHealthESP(char, plr.Name)
                            if esp then
                                updateHealthESP(char, info.Health, info.MaxHealth or 20)
                            end
                            
                            createHighlight(char)
                            
                            Cache.RealHealth[char] = {
                                health = info.Health,
                                maxHealth = info.MaxHealth or 20,
                                lastUpdate = tick()
                            }
                        end
                    end
                end
            end
        end
    end), "health")
    
    print("✅ PlayerESP inicializado - vida real ativa!")
end

function PlayerESP:Remove(model)
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

function PlayerESP:Clear()
    for model in pairs(Cache.PlayerMobESP) do
        if not model or not model.Parent then
            self:Remove(model)
        elseif Players:GetPlayerFromCharacter(model) then
            if not Config.PlayerESP then
                self:Remove(model)
            end
        end
    end
end

function PlayerESP:Cleanup()
    for model in pairs(Cache.PlayerMobESP) do
        if not model or not model.Parent then
            self:Remove(model)
        end
    end
end

return PlayerESP