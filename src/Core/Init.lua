-- ============================================================================
-- INIT.lua - Entry Point Principal
-- ============================================================================

print("🚀 Mine-Hub v5.0 - Iniciando...")

-- Carregar módulos core
local Constants = require("Core/Constants")
local Config = require("Core/Config")

-- Carregar engine
local ConnectionManager = require("Engine/ConnectionManager")
local ObjectPool = require("Engine/ObjectPool")
local Cache = require("Engine/Cache")

-- Carregar utils
local Helpers = require("Utils/Helpers")
local Detection = require("Utils/Detection")

-- Carregar features
local MineralESP = require("Features/MineralESP")
local PlayerESP = require("Features/PlayerESP")
local MobESP = require("Features/MobESP")
local ItemESP = require("Features/ItemESP")
local AdminDetection = require("Features/AdminDetection")
local WaterWalk = require("Features/WaterWalk")
local AlwaysDay = require("Features/AlwaysDay")
local Hitbox = require("Features/Hitbox")

-- Carregar UI
local Notifications = require("UI/Notifications")
local RayfieldUI = require("UI/RayfieldUI")

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ============================================================================
-- UPDATEWORLD INTERCEPTOR (VIDA REAL)
-- ============================================================================
local UpdateWorld = ReplicatedStorage:WaitForChild("UpdateWorld", 10)

if UpdateWorld then
    ConnectionManager:Add("updateWorld", UpdateWorld.OnClientEvent:Connect(function(data)
        if not Config.ShowHealth then return end
        if Config.SafeMode then return end
        if typeof(data) ~= "table" then return end

        -- Players
        if data.players and Config.PlayerESP then
            for _, info in ipairs(data.players) do
                if info.Player and info.Health then
                    local plr = info.Player
                    if plr ~= player then
                        PlayerESP:Update(plr, info.Health, info.MaxHealth or 20)
                    end
                end
            end
        end

        -- Mobs/Entities
        if data.chunks and Config.MobESP then
            for _, chunk in ipairs(data.chunks) do
                local chunkData = chunk[3]
                if chunkData and chunkData.entitydata then
                    for _, ent in ipairs(chunkData.entitydata) do
                        if ent.UUID and ent.Health and ent.id then
                            local entitiesFolder = workspace:FindFirstChild("Entities")
                            if entitiesFolder then
                                for _, model in ipairs(entitiesFolder:GetChildren()) do
                                    if model:IsA("Model") and model.Name == ent.id then
                                        if Detection.IsItem(model) then
                                            if Config.ItemESP then
                                                ItemESP:Create(model)
                                            end
                                        else
                                            MobESP:Update(model, ent.Health, ent.MaxHealth or 20, ent.id)
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
    
    print("✅ UpdateWorld interceptor conectado!")
else
    warn("⚠️ UpdateWorld não encontrado - usando fallback de vida")
end

-- ============================================================================
-- CLEANUP LOOP
-- ============================================================================
ConnectionManager:Add("cleanupLoop", RunService.Heartbeat:Connect(function()
    -- Atualizar cache
    Cache:Update()
end), "system")

-- ============================================================================
-- INPUT HANDLER
-- ============================================================================
ConnectionManager:Add("inputBegan", UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Constants.TOGGLE_KEY then
        MineralESP:Toggle()
    end
end), "general")

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================
task.spawn(function()
    RayfieldUI:Create()
end)

-- Iniciar admin detection
task.spawn(function()
    AdminDetection:Init()
    task.wait(2)
    AdminDetection:Check()
    AdminDetection:StartWatcher()
end)

-- Cleanup on close
game:BindToClose(function()
    ConnectionManager:RemoveAll()
    ObjectPool:ClearAll()
end)

print("✅ Mine-Hub v" .. Constants.VERSION .. " carregado com sucesso!")
print("📦 Pressione R para ativar | K para abrir menu")

-- Expor API global
_G.MineHub = _G.MineHub or {}
_G.MineHub.Version = Constants.VERSION
_G.MineHub.Toggle = function() MineralESP:Toggle() end
_G.MineHub.Config = Config
_G.MineHub.Constants = Constants

return {
    Config = Config,
    Constants = Constants,
    MineralESP = MineralESP,
    PlayerESP = PlayerESP,
    MobESP = MobESP,
    ItemESP = ItemESP,
    AdminDetection = AdminDetection,
    WaterWalk = WaterWalk,
    AlwaysDay = AlwaysDay,
    Hitbox = Hitbox,
}