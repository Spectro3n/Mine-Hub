-- ============================================================================
-- INIT v3.1 - Entry Point Principal (COM SAFE LOADING)
-- ============================================================================

print("🚀 Mine-Hub v5.0 - Iniciando...")

-- Serviços
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================================
-- SAFE REQUIRE (CARREGAMENTO SEGURO)
-- ============================================================================

local function safeRequire(path)
    local success, result = pcall(function()
        return require(path)
    end)
    
    if success then
        return result, nil
    else
        warn("[MineHub] Falha ao carregar módulo:", path, "-", tostring(result))
        return nil, result
    end
end

-- ============================================================================
-- DEBUG MODE
-- ============================================================================

local DEBUG_MODE = false

local function log(...)
    if DEBUG_MODE then
        print("[MineHub]", ...)
    end
end

local function logError(...)
    warn("[MineHub ERROR]", ...)
end

-- ============================================================================
-- CARREGAR MÓDULOS CORE (OBRIGATÓRIOS)
-- ============================================================================

local Constants = require("Core/Constants")
local Config = require("Core/Config")

-- ============================================================================
-- CARREGAR MÓDULOS ENGINE (COM FALLBACK)
-- ============================================================================

local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local ObjectPool, _ = safeRequire("Engine/ObjectPool")

-- ============================================================================
-- CARREGAR UTILS
-- ============================================================================

local Helpers = require("Utils/Helpers")
local Detection, _ = safeRequire("Utils/Detection")

-- Se Detection não existir, criar stub básico
if not Detection then
    Detection = {
        IsItem = function(model)
            if not model or not model:IsA("Model") then return false end
            return tonumber(model.Name) ~= nil and not model:FindFirstChildOfClass("Humanoid")
        end,
        IsMob = function(model)
            if not model or not model:IsA("Model") then return false end
            return model:FindFirstChild("Hitbox") ~= nil or model:FindFirstChildOfClass("Humanoid") ~= nil
        end,
        IsPlayer = function(model)
            return Players:GetPlayerFromCharacter(model) ~= nil
        end,
    }
end

-- ============================================================================
-- CARREGAR UI
-- ============================================================================

local Notifications, _ = safeRequire("UI/Notifications")
if not Notifications then
    Notifications = {
        Send = function(title, msg, duration)
            print("[Notification]", title, "-", msg)
        end,
        SetRayfield = function() end,
    }
end

-- ============================================================================
-- CARREGAR FEATURES (COM FALLBACK)
-- ============================================================================

local MineralESP = require("Features/MineralESP")
local PlayerESP, _ = safeRequire("Features/PlayerESP")
local MobESP, _ = safeRequire("Features/MobESP")
local ItemESP, _ = safeRequire("Features/ItemESP")
local AdminDetection, _ = safeRequire("Features/AdminDetection")
local WaterWalk, _ = safeRequire("Features/WaterWalk")
local AlwaysDay, _ = safeRequire("Features/AlwaysDay")
local Hitbox, _ = safeRequire("Features/Hitbox")

-- Criar stubs para módulos não carregados
PlayerESP = PlayerESP or { Update = function() end, ClearAll = function() end, Refresh = function() end }
MobESP = MobESP or { Update = function() end, ClearAll = function() end, OnEntityData = function() end }
ItemESP = ItemESP or { Init = function() end, Enable = function() end, Disable = function() end, ClearAll = function() end, Refresh = function() end, GetCount = function() return 0 end, GetMetrics = function() return {} end, IsInitialized = function() return false end }
AdminDetection = AdminDetection or { Init = function() end, Check = function() end, StartWatcher = function() end, ClearAllESP = function() end, GetOnlineAdmins = function() return {} end }
WaterWalk = WaterWalk or { Toggle = function() end }
AlwaysDay = AlwaysDay or { Toggle = function() end }
Hitbox = Hitbox or { Init = function() end, StartUpdateLoop = function() end, StopUpdateLoop = function() end, ClearAllESP = function() end, RestoreAll = function() end, GetMetrics = function() return {} end }

-- ============================================================================
-- CARREGAR UI PRINCIPAL
-- ============================================================================

local RayfieldUI, _ = safeRequire("UI/RayfieldUI")
if not RayfieldUI then
    RayfieldUI = { Create = function() end, GetWindow = function() return nil end }
end

local player = Players.LocalPlayer

-- ============================================================================
-- ENTITY INDEX
-- ============================================================================

local EntityIndex = {
    _index = {},
    _folder = nil,
    _initialized = false,
}

function EntityIndex:Init()
    if self._initialized then return end
    
    self._folder = workspace:FindFirstChild("Entities")
    
    if not self._folder then
        task.spawn(function()
            self._folder = workspace:WaitForChild("Entities", 60)
            if self._folder then
                self:_setupConnections()
                self:_buildIndex()
            end
        end)
        return
    end
    
    self:_setupConnections()
    self:_buildIndex()
    self._initialized = true
end

function EntityIndex:_setupConnections()
    if not self._folder then return end
    
    ConnectionManager:Add("entityIndex_added", self._folder.ChildAdded:Connect(function(model)
        if model:IsA("Model") then
            self._index[model.Name] = model
        end
    end), "entityIndex")
    
    ConnectionManager:Add("entityIndex_removed", self._folder.ChildRemoved:Connect(function(model)
        self._index[model.Name] = nil
    end), "entityIndex")
end

function EntityIndex:_buildIndex()
    if not self._folder then return end
    
    self._index = {}
    for _, model in ipairs(self._folder:GetChildren()) do
        if model:IsA("Model") then
            self._index[model.Name] = model
        end
    end
end

function EntityIndex:Get(nameOrId)
    return self._index[tostring(nameOrId)]
end

function EntityIndex:GetCount()
    local count = 0
    for _ in pairs(self._index) do
        count = count + 1
    end
    return count
end

function EntityIndex:GetAll()
    return self._index
end

function EntityIndex:Rebuild()
    self:_buildIndex()
end

-- ============================================================================
-- CONFIG WATCHER
-- ============================================================================

local ConfigWatcher = {
    _listeners = {},
    _lastValues = {},
    _frameCount = 0,
}

function ConfigWatcher:Init()
    for key, value in pairs(Config) do
        if type(value) ~= "function" then
            self._lastValues[key] = value
        end
    end
end

function ConfigWatcher:Watch(key, callback)
    if not self._listeners[key] then
        self._listeners[key] = {}
    end
    table.insert(self._listeners[key], callback)
    
    if Config[key] ~= nil then
        task.spawn(function()
            pcall(callback, Config[key])
        end)
    end
end

function ConfigWatcher:Set(key, value)
    local oldValue = Config[key]
    Config[key] = value
    
    if oldValue ~= value then
        self:_notify(key, value, oldValue)
    end
end

function ConfigWatcher:_notify(key, newValue, oldValue)
    local listeners = self._listeners[key]
    if not listeners then return end
    
    for _, callback in ipairs(listeners) do
        task.spawn(function()
            pcall(callback, newValue, oldValue)
        end)
    end
end

function ConfigWatcher:StartPolling()
    ConnectionManager:Add("configWatcher_poll", RunService.Heartbeat:Connect(function()
        self._frameCount = self._frameCount + 1
        if self._frameCount < 30 then return end
        self._frameCount = 0
        
        for key, lastValue in pairs(self._lastValues) do
            local currentValue = Config[key]
            if currentValue ~= lastValue then
                self._lastValues[key] = currentValue
                self:_notify(key, currentValue, lastValue)
            end
        end
    end), "system")
end

-- ============================================================================
-- SAFE INIT HELPER
-- ============================================================================

local function safeInit(name, initFn, options)
    options = options or {}
    
    local function doInit()
        if options.delay and options.delay > 0 then
            task.wait(options.delay)
        end
        
        local success, err = pcall(initFn)
        
        if success then
            log("✅", name, "inicializado")
            return true
        else
            logError("❌", name, "falhou:", err)
            return false
        end
    end
    
    if options.async then
        task.spawn(doInit)
    else
        return doInit()
    end
end

-- ============================================================================
-- UPDATEWORLD INTERCEPTOR
-- ============================================================================

local function setupUpdateWorldInterceptor()
    local UpdateWorld = ReplicatedStorage:FindFirstChild("UpdateWorld")
    
    if not UpdateWorld then
        UpdateWorld = ReplicatedStorage:WaitForChild("UpdateWorld", 10)
    end
    
    if not UpdateWorld then
        logError("UpdateWorld não encontrado")
        return false
    end
    
    ConnectionManager:Add("updateWorld", UpdateWorld.OnClientEvent:Connect(function(data)
        if not Config.ShowHealth then return end
        if Config.SafeMode then return end
        if typeof(data) ~= "table" then return end
        
        -- Processar Players
        if data.players and Config.PlayerESP then
            for _, info in ipairs(data.players) do
                if info.Player and info.Health and info.Player ~= player then
                    Cache:SetRealHealth(info.Player, info.Health, info.MaxHealth or 20)
                    
                    if PlayerESP and PlayerESP.Update then
                        PlayerESP:Update(info.Player, info.Health, info.MaxHealth or 20)
                    end
                end
            end
        end
        
        -- Processar Entities
        if data.chunks then
            for _, chunk in ipairs(data.chunks) do
                local chunkData = chunk[3]
                if chunkData and chunkData.entitydata then
                    for _, ent in ipairs(chunkData.entitydata) do
                        if ent.UUID and ent.id then
                            local model = EntityIndex:Get(ent.id)
                            
                            if model then
                                Cache:SetEntityData(model, {
                                    uuid = ent.UUID,
                                    health = ent.Health,
                                    maxHealth = ent.MaxHealth or 20,
                                    id = ent.id,
                                    lastUpdate = tick(),
                                })
                                
                                if ent.Health and Config.MobESP and MobESP and MobESP.OnEntityData then
                                    MobESP:OnEntityData(model, ent)
                                end
                            end
                        end
                    end
                end
            end
        end
    end), "health")
    
    log("UpdateWorld interceptor conectado")
    return true
end

-- ============================================================================
-- SETUP FUNCTIONS
-- ============================================================================

local function setupCacheUpdateLoop()
    ConnectionManager:Add("cacheUpdate", RunService.Heartbeat:Connect(function(deltaTime)
        Cache:Update(deltaTime)
    end), "system")
end

local function setupInputHandler()
    ConnectionManager:Add("inputBegan", UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Constants.TOGGLE_KEY then
            MineralESP:Toggle()
        end
    end), "general")
end

local function setupConfigWatchers()
    ConfigWatcher:Watch("ItemESP", function(enabled)
        if enabled then
            if ItemESP.IsInitialized and ItemESP:IsInitialized() then
                ItemESP:Enable()
            elseif ItemESP.Init then
                ItemESP:Init()
            end
        else
            if ItemESP.Disable then
                ItemESP:Disable()
            end
        end
    end)
    
    ConfigWatcher:Watch("ShowHitboxESP", function(enabled)
        if enabled then
            if Hitbox.StartUpdateLoop then Hitbox:StartUpdateLoop() end
        else
            if Hitbox.ClearAllESP then Hitbox:ClearAllESP() end
        end
    end)
    
    ConfigWatcher:Watch("ExpandHitbox", function(enabled)
        if enabled then
            if Hitbox.StartUpdateLoop then Hitbox:StartUpdateLoop() end
        else
            if Hitbox.RestoreAll then Hitbox:RestoreAll() end
        end
    end)
    
    ConfigWatcher:Watch("SafeMode", function(enabled)
        if enabled then
            if MineralESP.Disable then MineralESP:Disable() end
            if PlayerESP.ClearAll then PlayerESP:ClearAll() end
            if MobESP.ClearAll then MobESP:ClearAll() end
            if ItemESP.Disable then ItemESP:Disable() end
            if Hitbox.ClearAllESP then Hitbox:ClearAllESP() end
            if Hitbox.RestoreAll then Hitbox:RestoreAll() end
            if AdminDetection.ClearAllESP then AdminDetection:ClearAllESP() end
            
            if Config.AlwaysDay and AlwaysDay.Toggle then
                AlwaysDay:Toggle(false)
            end
            if Config.WaterWalk and WaterWalk.Toggle then
                WaterWalk:Toggle(false)
            end
            
            Notifications:Send("🛑 SAFE MODE", "Todos os recursos desativados!", 3)
        end
    end)
    
    ConfigWatcher:StartPolling()
end

-- ============================================================================
-- INITIALIZE FEATURES
-- ============================================================================

local function initializeFeatures()
    
    -- Hitbox
    safeInit("Hitbox", function()
        if Hitbox.Init then
            Hitbox:Init()
        end
    end)
    
    -- ItemESP
    safeInit("ItemESP", function()
        if Config.ItemESP and ItemESP.Init then
            ItemESP:Init()
        end
    end, { async = true, delay = 0.3 })
    
    -- AdminDetection
    safeInit("AdminDetection", function()
        if AdminDetection.Init then
            AdminDetection:Init()
            if AdminDetection.Check then AdminDetection:Check() end
            if AdminDetection.StartWatcher then AdminDetection:StartWatcher() end
        end
    end, { async = true, delay = 1 })
    
    -- UI
    safeInit("RayfieldUI", function()
        if RayfieldUI.Create then
            RayfieldUI:Create()
        end
    end, { async = true, delay = 0.5 })
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
    local startTime = tick()
    
    -- Fase 1: Core
    safeInit("Cache", function()
        if Cache.Init then Cache:Init() end
    end)
    
    safeInit("ConfigWatcher", function()
        ConfigWatcher:Init()
    end)
    
    safeInit("EntityIndex", function()
        EntityIndex:Init()
    end)
    
    -- Fase 2: Connections
    setupCacheUpdateLoop()
    setupUpdateWorldInterceptor()
    setupInputHandler()
    setupConfigWatchers()
    
    -- Fase 3: Features
    initializeFeatures()
    
    -- Done
    local loadTime = tick() - startTime
    
    print("═══════════════════════════════════════════════")
    print("✅ Mine-Hub v" .. Constants.VERSION .. " carregado!")
    print("⏱️ Tempo: " .. string.format("%.2fms", loadTime * 1000))
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

_G.MineHub.API = {
    ToggleMineralESP = function() MineralESP:Toggle() end,
    ToggleItemESP = function(state) ConfigWatcher:Set("ItemESP", state) end,
    ToggleHitbox = function(state) ConfigWatcher:Set("ShowHitboxESP", state) end,
    ToggleSafeMode = function(state) ConfigWatcher:Set("SafeMode", state) end,
    GetVersion = function() return Constants.VERSION end,
}

_G.MineHub.Debug = {
    GetCacheMetrics = function() return Cache.GetMetrics and Cache:GetMetrics() or {} end,
    GetItemESPMetrics = function() return ItemESP.GetMetrics and ItemESP:GetMetrics() or {} end,
    GetHitboxMetrics = function() return Hitbox.GetMetrics and Hitbox:GetMetrics() or {} end,
    GetEntityIndexCount = function() return EntityIndex:GetCount() end,
    RefreshItemESP = function() if ItemESP.Refresh then ItemESP:Refresh() end end,
    RefreshEntityIndex = function() EntityIndex:Rebuild() end,
    SetDebugMode = function(enabled) DEBUG_MODE = enabled end,
}

-- ============================================================================
-- RETURN
-- ============================================================================

return {
    Config = Config,
    Constants = Constants,
    Cache = Cache,
    ConnectionManager = ConnectionManager,
    EntityIndex = EntityIndex,
    MineralESP = MineralESP,
    PlayerESP = PlayerESP,
    MobESP = MobESP,
    ItemESP = ItemESP,
    Hitbox = Hitbox,
    Helpers = Helpers,
}