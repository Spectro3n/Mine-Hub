-- ============================================================================
-- INIT v3.0 - Entry Point Principal (REFATORADO)
-- ============================================================================
-- ✅ Index de Entities para O(1) lookup
-- ✅ Config reativo (sem Heartbeat polling)
-- ✅ Inicialização segura e ordenada
-- ✅ FakeHitbox integrado
-- ✅ Separação de responsabilidades correta
-- ============================================================================

print("🚀 Mine-Hub v5.0 - Iniciando...")

-- Serviços
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================================
-- CONFIGURAÇÃO DE DEBUG
-- ============================================================================

local DEBUG_MODE = false -- Mudar para true durante desenvolvimento

local function log(...)
    if DEBUG_MODE then
        print("[MineHub]", ...)
    end
end

local function logError(...)
    warn("[MineHub ERROR]", ...)
end

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
local FakeHitbox = require("Engine/FakeHitbox")

-- Utils
local Helpers = require("Utils/Helpers")

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
-- ENTITY INDEX (PARA O(1) LOOKUP)
-- ============================================================================

local EntityIndex = {
    _index = {},           -- name/id -> model
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
            else
                logError("Pasta Entities não encontrada após 60s")
            end
        end)
        return
    end
    
    self:_setupConnections()
    self:_buildIndex()
    self._initialized = true
    log("EntityIndex inicializado")
end

function EntityIndex:_setupConnections()
    if not self._folder then return end
    
    ConnectionManager:Add("entityIndex_added", self._folder.ChildAdded:Connect(function(model)
        if model:IsA("Model") then
            self._index[model.Name] = model
            log("Entity adicionada ao index:", model.Name)
        end
    end), "entityIndex")
    
    ConnectionManager:Add("entityIndex_removed", self._folder.ChildRemoved:Connect(function(model)
        self._index[model.Name] = nil
        log("Entity removida do index:", model.Name)
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
    
    log("EntityIndex construído com", self:GetCount(), "entities")
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
-- CONFIG REATIVO (SEM HEARTBEAT POLLING)
-- ============================================================================

local ConfigWatcher = {
    _listeners = {},
    _lastValues = {},
}

function ConfigWatcher:Init()
    -- Capturar valores iniciais
    for key, value in pairs(Config) do
        if type(value) ~= "function" then
            self._lastValues[key] = value
        end
    end
    log("ConfigWatcher inicializado")
end

function ConfigWatcher:Watch(key, callback)
    if not self._listeners[key] then
        self._listeners[key] = {}
    end
    table.insert(self._listeners[key], callback)
    
    -- Executar callback com valor atual
    if Config[key] ~= nil then
        callback(Config[key])
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
            local success, err = pcall(callback, newValue, oldValue)
            if not success then
                logError("ConfigWatcher callback error:", key, err)
            end
        end)
    end
end

-- Checar mudanças periodicamente (fallback, menos frequente)
function ConfigWatcher:StartPolling()
    -- Polling a cada 0.5s em vez de cada frame
    ConnectionManager:Add("configWatcher_poll", RunService.Heartbeat:Connect(function()
        -- Throttle: só checar a cada 30 frames (~0.5s)
        if not self._frameCount then self._frameCount = 0 end
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
-- INICIALIZAÇÃO SEGURA
-- ============================================================================

local function safeInit(name, initFn, options)
    options = options or {}
    local delay = options.delay or 0
    local required = options.required or false
    
    local function doInit()
        if delay > 0 then
            task.wait(delay)
        end
        
        local success, err = pcall(initFn)
        
        if success then
            log("✅", name, "inicializado")
            return true
        else
            if required then
                logError("❌", name, "FALHOU (CRÍTICO):", err)
            else
                logError("⚠️", name, "falhou:", err)
            end
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
-- UPDATEWORLD INTERCEPTOR (OTIMIZADO)
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
        -- Early exits
        if not Config.ShowHealth then return end
        if Config.SafeMode then return end
        if typeof(data) ~= "table" then return end
        
        -- ═══════════════════════════════════════════════
        -- PROCESSAR PLAYERS (O(n) simples)
        -- ═══════════════════════════════════════════════
        if data.players and Config.PlayerESP then
            for _, info in ipairs(data.players) do
                if info.Player and info.Health and info.Player ~= player then
                    -- Apenas armazenar dados no Cache
                    -- PlayerESP decide como renderizar
                    Cache:SetRealHealth(info.Player, info.Health, info.MaxHealth or 20)
                    
                    -- Notificar PlayerESP (se estiver ativo)
                    if PlayerESP.OnHealthUpdate then
                        PlayerESP:OnHealthUpdate(info.Player, info.Health, info.MaxHealth or 20)
                    else
                        PlayerESP:Update(info.Player, info.Health, info.MaxHealth or 20)
                    end
                end
            end
        end
        
        -- ═══════════════════════════════════════════════
        -- PROCESSAR ENTITIES (O(n) com index O(1))
        -- ═══════════════════════════════════════════════
        if data.chunks then
            for _, chunk in ipairs(data.chunks) do
                local chunkData = chunk[3]
                if chunkData and chunkData.entitydata then
                    for _, ent in ipairs(chunkData.entitydata) do
                        if ent.UUID and ent.id then
                            -- ✅ O(1) lookup em vez de O(n)
                            local model = EntityIndex:Get(ent.id)
                            
                            if model then
                                -- Apenas armazenar dados no Cache
                                -- ESPs decidem como renderizar
                                Cache:SetEntityData(model, {
                                    uuid = ent.UUID,
                                    health = ent.Health,
                                    maxHealth = ent.MaxHealth or 20,
                                    id = ent.id,
                                    lastUpdate = tick(),
                                })
                                
                                -- ❌ NÃO decidir aqui se é item ou mob
                                -- Os ESPs fazem isso no próprio scan
                                
                                -- Apenas notificar MobESP se tiver health
                                if ent.Health and Config.MobESP then
                                    -- Deixar MobESP decidir se é mob
                                    if MobESP.OnEntityData then
                                        MobESP:OnEntityData(model, ent)
                                    end
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
-- CACHE UPDATE LOOP
-- ============================================================================

local function setupCacheUpdateLoop()
    ConnectionManager:Add("cacheUpdate", RunService.Heartbeat:Connect(function(deltaTime)
        Cache:Update(deltaTime)
    end), "system")
    
    log("Cache update loop ativo")
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
        
        -- Debug key (F9)
        if DEBUG_MODE and input.KeyCode == Enum.KeyCode.F9 then
            print("=== DEBUG INFO ===")
            print("EntityIndex count:", EntityIndex:GetCount())
            print("Cache metrics:", Cache:GetMetrics())
            print("ItemESP count:", ItemESP:GetCount())
            print("Hitbox metrics:", Hitbox:GetMetrics())
            print("==================")
        end
    end), "general")
    
    log("Input handler configurado")
end

-- ============================================================================
-- SETUP CONFIG WATCHERS
-- ============================================================================

local function setupConfigWatchers()
    -- ItemESP
    ConfigWatcher:Watch("ItemESP", function(enabled)
        if enabled then
            if ItemESP:IsInitialized() then
                ItemESP:Enable()
            else
                ItemESP:Init()
            end
        else
            ItemESP:Disable()
        end
    end)
    
    -- Hitbox ESP
    ConfigWatcher:Watch("ShowHitboxESP", function(enabled)
        if enabled then
            Hitbox:StartUpdateLoop()
        else
            Hitbox:ClearAllESP()
        end
    end)
    
    -- Expand Hitbox
    ConfigWatcher:Watch("ExpandHitbox", function(enabled)
        if enabled then
            Hitbox:StartUpdateLoop()
        else
            Hitbox:RestoreAll()
        end
    end)
    
    -- SafeMode
    ConfigWatcher:Watch("SafeMode", function(enabled)
        if enabled then
            -- Desativar tudo
            MineralESP:Disable()
            PlayerESP:ClearAll()
            MobESP:ClearAll()
            ItemESP:Disable()
            Hitbox:ClearAllESP()
            Hitbox:RestoreAll()
            FakeHitbox:RemoveAll()
            AdminDetection:ClearAllESP()
            
            if Config.AlwaysDay then
                AlwaysDay:Toggle(false)
            end
            if Config.WaterWalk then
                WaterWalk:Toggle(false)
            end
            
            Notifications:Send("🛑 SAFE MODE", "Todos os recursos desativados!", 3)
        end
    end)
    
    -- Iniciar polling como fallback
    ConfigWatcher:StartPolling()
    
    log("Config watchers configurados")
end

-- ============================================================================
-- INICIALIZAÇÃO DAS FEATURES
-- ============================================================================

local function initializeFeatures()
    -- ═══════════════════════════════════════════════
    -- HITBOX + FAKEHITBOX (inicializar primeiro)
    -- ═══════════════════════════════════════════════
    safeInit("FakeHitbox", function()
        FakeHitbox:StartAutoCleanup()
    end)
    
    safeInit("Hitbox", function()
        Hitbox:Init()
    end)
    
    -- ═══════════════════════════════════════════════
    -- ITEM ESP
    -- ═══════════════════════════════════════════════
    safeInit("ItemESP", function()
        if Config.ItemESP then
            ItemESP:Init()
        end
    end, { async = true, delay = 0.3 })
    
    -- ═══════════════════════════════════════════════
    -- ADMIN DETECTION
    -- ═══════════════════════════════════════════════
    safeInit("AdminDetection", function()
        AdminDetection:Init()
        AdminDetection:Check()
        AdminDetection:StartWatcher()
    end, { async = true, delay = 1 })
    
    -- ═══════════════════════════════════════════════
    -- UI (RAYFIELD)
    -- ═══════════════════════════════════════════════
    safeInit("RayfieldUI", function()
        RayfieldUI:Create()
    end, { async = true, delay = 0.5 })
end

-- ============================================================================
-- MAIN INITIALIZATION
-- ============================================================================

local function main()
    local startTime = tick()
    
    -- ═══════════════════════════════════════════════
    -- FASE 1: Core Systems (síncrono)
    -- ═══════════════════════════════════════════════
    safeInit("Cache", function()
        Cache:Init()
    end, { required = true })
    
    safeInit("ConfigWatcher", function()
        ConfigWatcher:Init()
    end)
    
    safeInit("EntityIndex", function()
        EntityIndex:Init()
    end)
    
    -- ═══════════════════════════════════════════════
    -- FASE 2: Connections (síncrono)
    -- ═══════════════════════════════════════════════
    setupCacheUpdateLoop()
    setupUpdateWorldInterceptor()
    setupInputHandler()
    setupConfigWatchers()
    
    -- ═══════════════════════════════════════════════
    -- FASE 3: Features (assíncrono)
    -- ═══════════════════════════════════════════════
    initializeFeatures()
    
    -- ═══════════════════════════════════════════════
    -- CONCLUÍDO
    -- ═══════════════════════════════════════════════
    local loadTime = tick() - startTime
    
    print("═══════════════════════════════════════════════")
    print("✅ Mine-Hub v" .. Constants.VERSION .. " carregado!")
    print("⏱️ Tempo de carregamento: " .. string.format("%.2fms", loadTime * 1000))
    print("📦 Pressione R para ativar | K para menu")
    print("═══════════════════════════════════════════════")
end

-- Executar
main()

-- ============================================================================
-- API GLOBAL (ENCAPSULADA)
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Version = Constants.VERSION

-- API Pública (segura)
_G.MineHub.API = {
    -- Toggles
    ToggleMineralESP = function()
        MineralESP:Toggle()
    end,
    
    ToggleItemESP = function(state)
        ConfigWatcher:Set("ItemESP", state)
    end,
    
    ToggleHitbox = function(state)
        ConfigWatcher:Set("ShowHitboxESP", state)
    end,
    
    ToggleSafeMode = function(state)
        ConfigWatcher:Set("SafeMode", state)
    end,
    
    -- Getters
    IsInitialized = function()
        return Cache._initialized and EntityIndex._initialized
    end,
    
    GetVersion = function()
        return Constants.VERSION
    end,
}

-- Debug API (separada)
_G.MineHub.Debug = {
    -- Métricas
    GetCacheMetrics = function()
        return Cache:GetMetrics()
    end,
    
    GetCacheSizes = function()
        return Cache:GetCacheSizes()
    end,
    
    GetItemESPMetrics = function()
        return ItemESP:GetMetrics()
    end,
    
    GetHitboxMetrics = function()
        return Hitbox:GetMetrics()
    end,
    
    GetFakeHitboxMetrics = function()
        return FakeHitbox:GetMetrics()
    end,
    
    GetEntityIndexCount = function()
        return EntityIndex:GetCount()
    end,
    
    GetConnectionsMetrics = function()
        return ConnectionManager:GetMetrics()
    end,
    
    -- Ações
    RefreshItemESP = function()
        ItemESP:Refresh()
    end,
    
    RefreshEntityIndex = function()
        EntityIndex:Rebuild()
    end,
    
    ClearAllCaches = function()
        Cache:ClearAll()
        Helpers.ClearCache()
    end,
    
    ForceCleanup = function()
        ConnectionManager:ForceCleanup()
        FakeHitbox:RemoveAll()
        Hitbox:RestoreAll()
    end,
    
    -- Debug mode
    SetDebugMode = function(enabled)
        DEBUG_MODE = enabled
    end,
    
    -- Listar tudo
    ListTrackedItems = function()
        return ItemESP:GetTrackedItems()
    end,
    
    ListEntities = function()
        return EntityIndex:GetAll()
    end,
}

-- ============================================================================
-- CLEANUP ON LEAVE
-- ============================================================================

game:BindToClose(function()
    log("Limpando antes de fechar...")
    ConnectionManager:RemoveAll()
    FakeHitbox:RemoveAll()
    Hitbox:RestoreAll()
end)

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return {
    -- Core
    Config = Config,
    Constants = Constants,
    Cache = Cache,
    
    -- Engine
    ConnectionManager = ConnectionManager,
    ObjectPool = ObjectPool,
    FakeHitbox = FakeHitbox,
    EntityIndex = EntityIndex,
    
    -- Features
    MineralESP = MineralESP,
    PlayerESP = PlayerESP,
    MobESP = MobESP,
    ItemESP = ItemESP,
    AdminDetection = AdminDetection,
    WaterWalk = WaterWalk,
    AlwaysDay = AlwaysDay,
    Hitbox = Hitbox,
    
    -- Utils
    Helpers = Helpers,
    ConfigWatcher = ConfigWatcher,
}