-- ============================================================================
-- INIT v2.0 - Entry Point Principal (OTIMIZADO)
-- ============================================================================

print("🚀 Mine-Hub v5.0 - Iniciando...")

-- Serviços
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================================
-- CARREGAR MÓDULOS (ORDEM IMPORTA)
-- ============================================================================

-- Core primeiro
local Constants = require("Core/Constants")
local Config = require("Core/Config")

-- Engine (Cache precisa ser primeiro)
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local ObjectPool = require("Engine/ObjectPool")

-- Utils
local Helpers = require("Utils/Helpers")
local Detection = require("Utils/Detection")

-- UI (Notifications primeiro)
local Notifications = require("UI/Notifications")

-- Features
local MineralESP = require("Features/MineralESP")
local PlayerESP = require("Features/PlayerESP")
local MobESP = require("Features/MobESP")
local ItemESP = require("Features/ItemESP")
local AdminDetection = require("Features/AdminDetection")
local WaterWalk = require("Features/WaterWalk")
local AlwaysDay = require("Features/AlwaysDay")
local Hitbox = require("Features/Hitbox")

-- UI principal (por último)
local RayfieldUI = require("UI/RayfieldUI")

local player = Players.LocalPlayer

-- ============================================================================
-- INICIALIZAR CACHE PRIMEIRO
-- ============================================================================

Cache:Init()
print("✅ Cache inicializado!")

-- ============================================================================
-- UPDATEWORLD INTERCEPTOR (MELHORADO)
-- ============================================================================

local function setupUpdateWorldInterceptor()
    local UpdateWorld = ReplicatedStorage:FindFirstChild("UpdateWorld")
    
    if not UpdateWorld then
        UpdateWorld = ReplicatedStorage:WaitForChild("UpdateWorld", 10)
    end
    
    if not UpdateWorld then
        warn("⚠️ UpdateWorld não encontrado")
        return false
    end
    
    ConnectionManager:Add("updateWorld", UpdateWorld.OnClientEvent:Connect(function(data)
        if not Config.ShowHealth then return end
        if Config.SafeMode then return end
        if typeof(data) ~= "table" then return end
        
        -- ═══════════════════════════════════════════════
        -- PROCESSAR PLAYERS
        -- ═══════════════════════════════════════════════
        if data.players and Config.PlayerESP then
            for _, info in ipairs(data.players) do
                if info.Player and info.Health then
                    local plr = info.Player
                    if plr ~= player then
                        -- Usar Cache para armazenar health
                        Cache:SetRealHealth(plr, info.Health, info.MaxHealth or 20)
                        PlayerESP:Update(plr, info.Health, info.MaxHealth or 20)
                    end
                end
            end
        end
        
        -- ═══════════════════════════════════════════════
        -- PROCESSAR MOBS/ENTITIES
        -- ═══════════════════════════════════════════════
        if data.chunks then
            local entitiesFolder = workspace:FindFirstChild("Entities")
            if not entitiesFolder then return end
            
            for _, chunk in ipairs(data.chunks) do
                local chunkData = chunk[3]
                if chunkData and chunkData.entitydata then
                    for _, ent in ipairs(chunkData.entitydata) do
                        if ent.UUID and ent.Health and ent.id then
                            -- Buscar model correspondente
                            for _, model in ipairs(entitiesFolder:GetChildren()) do
                                if model:IsA("Model") and model.Name == ent.id then
                                    -- Armazenar no Cache
                                    Cache:SetEntityData(model, {
                                        uuid = ent.UUID,
                                        health = ent.Health,
                                        maxHealth = ent.MaxHealth or 20,
                                        id = ent.id
                                    })
                                    
                                    -- Detectar se é item ou mob
                                    if Detection.IsItem(model) then
                                        -- ItemESP cuida de criar/atualizar
                                        -- Não precisa fazer nada aqui, ItemESP monitora a pasta
                                    elseif Config.MobESP then
                                        MobESP:Update(model, ent.Health, ent.MaxHealth or 20, ent.id)
                                    end
                                    
                                    break -- Encontrou, próxima entity
                                end
                            end
                        end
                    end
                end
            end
        end
    end), "health")
    
    print("✅ UpdateWorld interceptor conectado!")
    return true
end

-- ============================================================================
-- CACHE UPDATE LOOP (OTIMIZADO)
-- ============================================================================

local function setupCacheUpdateLoop()
    -- Usar Heartbeat para update mais consistente
    ConnectionManager:Add("cacheUpdate", RunService.Heartbeat:Connect(function(deltaTime)
        Cache:Update()
    end), "system")
    
    print("✅ Cache update loop ativo!")
end

-- ============================================================================
-- INPUT HANDLER
-- ============================================================================

local function setupInputHandler()
    ConnectionManager:Add("inputBegan", UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Constants.TOGGLE_KEY then
            MineralESP:Toggle()
        end
    end), "general")
    
    print("✅ Input handler configurado!")
end

-- ============================================================================
-- INICIALIZAÇÃO DAS FEATURES
-- ============================================================================

local function initializeFeatures()
    -- ═══════════════════════════════════════════════
    -- ITEM ESP (com delay para garantir que tudo carregou)
    -- ═══════════════════════════════════════════════
    task.spawn(function()
        task.wait(0.5)
        
        if Config.ItemESP then
            ItemESP:Init()
            print("✅ ItemESP inicializado!")
        end
    end)
    
    -- ═══════════════════════════════════════════════
    -- UI (RAYFIELD)
    -- ═══════════════════════════════════════════════
    task.spawn(function()
        task.wait(0.5)
        
        local success, err = pcall(function()
            RayfieldUI:Create()
        end)
        
        if success then
            print("✅ UI criada!")
        else
            warn("⚠️ Erro ao criar UI:", err)
        end
    end)
    
    -- ═══════════════════════════════════════════════
    -- ADMIN DETECTION
    -- ═══════════════════════════════════════════════
    task.spawn(function()
        task.wait(1)
        
        local success, err = pcall(function()
            AdminDetection:Init()
            task.wait(1)
            AdminDetection:Check()
            AdminDetection:StartWatcher()
        end)
        
        if success then
            print("✅ Admin Detection ativo!")
        else
            warn("⚠️ Erro no Admin Detection:", err)
        end
    end)
end

-- ============================================================================
-- CONFIG WATCHER (PARA TOGGLE DE FEATURES)
-- ============================================================================

local function setupConfigWatcher()
    -- Watcher para Config.ItemESP
    local lastItemESPState = Config.ItemESP
    
    ConnectionManager:Add("configWatcher", RunService.Heartbeat:Connect(function()
        -- ItemESP toggle
        if Config.ItemESP ~= lastItemESPState then
            lastItemESPState = Config.ItemESP
            
            if Config.ItemESP then
                if not ItemESP._initialized then
                    ItemESP:Init()
                else
                    ItemESP:Enable()
                end
            else
                ItemESP:Disable()
            end
        end
    end), "system")
end

-- ============================================================================
-- MAIN INITIALIZATION
-- ============================================================================

local function main()
    -- Setup na ordem correta
    setupCacheUpdateLoop()
    setupUpdateWorldInterceptor()
    setupInputHandler()
    setupConfigWatcher()
    
    -- Inicializar features
    initializeFeatures()
    
    print("═══════════════════════════════════════════════")
    print("✅ Mine-Hub v" .. Constants.VERSION .. " carregado!")
    print("📦 Pressione R para ativar | K para menu")
    print("═══════════════════════════════════════════════")
end

-- Executar
main()

-- ============================================================================
-- API GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Version = Constants.VERSION
_G.MineHub.Toggle = function() MineralESP:Toggle() end

-- Debug API
_G.MineHub.Debug = {
    GetCacheMetrics = function() return Cache:GetMetrics() end,
    GetCacheSizes = function() return Cache:GetCacheSizes() end,
    GetItemESPMetrics = function() return ItemESP:GetMetrics() end,
    GetItemESPCount = function() return ItemESP:GetCount() end,
    RefreshItemESP = function() ItemESP:Refresh() end,
}

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return {
    -- Core
    Config = Config,
    Constants = Constants,
    Cache = Cache,
    
    -- Features
    MineralESP = MineralESP,
    PlayerESP = PlayerESP,
    MobESP = MobESP,
    ItemESP = ItemESP,
    AdminDetection = AdminDetection,
    WaterWalk = WaterWalk,
    AlwaysDay = AlwaysDay,
    Hitbox = Hitbox,
    
    -- Engine
    ConnectionManager = ConnectionManager,
    ObjectPool = ObjectPool,
}