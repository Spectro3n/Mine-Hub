-- ============================================================================
-- HITBOX v2.1 - Sistema Completo com FakeHitbox para Players
-- ============================================================================
-- ✅ Player → FakeHitbox (soldada ao HRP)
-- ✅ Animal/NPC → Hitbox real expandida
-- ✅ Item → Não expande
-- ✅ CanQuery = true sempre
-- ✅ ESP separado de hitbox real
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Helpers = require("Utils/Helpers")
local ConnectionManager = require("Engine/ConnectionManager")
local Cache = require("Engine/Cache")
local FakeHitbox = require("Engine/FakeHitbox")

local Hitbox = {
    -- ═══════════════════════════════════════════════
    -- CACHE DE ESP (VISUAL ONLY)
    -- ═══════════════════════════════════════════════
    _espCache = {},           -- part -> BoxHandleAdornment
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE EXPANSÃO REAL (PARA MOBS/ANIMALS)
    -- ═══════════════════════════════════════════════
    _originalSizes = {},      -- part -> Vector3
    _expandedParts = {},      -- part -> true
    
    -- ═══════════════════════════════════════════════
    -- TRACKING DE ENTIDADES
    -- ═══════════════════════════════════════════════
    _trackedEntities = {},    -- model -> {type, hitbox, hasESP, isExpanded}
    
    -- ═══════════════════════════════════════════════
    -- CORES POR TIPO
    -- ═══════════════════════════════════════════════
    _colors = {
        [Helpers.EntityTypes.PLAYER] = Color3.fromRGB(255, 0, 0),      -- Vermelho
        [Helpers.EntityTypes.NPC] = Color3.fromRGB(255, 100, 100),     -- Rosa
        [Helpers.EntityTypes.ANIMAL] = Color3.fromRGB(255, 165, 0),    -- Laranja
        [Helpers.EntityTypes.ITEM] = Color3.fromRGB(255, 255, 0),      -- Amarelo
        [Helpers.EntityTypes.UNKNOWN] = Color3.fromRGB(255, 255, 255), -- Branco
    },
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO
    -- ═══════════════════════════════════════════════
    _config = {
        autoTrackPlayers = true,
        autoTrackMobs = true,
        showVisualForFake = false,  -- Mostrar visual do FakeHitbox
        updateInterval = 0.1,
    },
    
    -- ═══════════════════════════════════════════════
    -- ESTADO
    -- ═══════════════════════════════════════════════
    _initialized = false,
    _updateLoopRunning = false,
    
    -- ═══════════════════════════════════════════════
    -- MÉTRICAS
    -- ═══════════════════════════════════════════════
    _metrics = {
        espCreated = 0,
        espRemoved = 0,
        mobsExpanded = 0,
        mobsRestored = 0,
        playersWithFake = 0,
        lastUpdateTime = 0,
    },
}

local player = Players.LocalPlayer

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

function Hitbox:Init()
    if self._initialized then return end
    
    -- Iniciar FakeHitbox cleanup
    FakeHitbox:StartAutoCleanup()
    
    -- Iniciar loop se auto-track está ativado
    if self._config.autoTrackPlayers or self._config.autoTrackMobs then
        self:StartUpdateLoop()
    end
    
    self._initialized = true
end

-- ============================================================================
-- CRIAR ESP (VISUAL ONLY - NÃO AFETA HIT)
-- ============================================================================

function Hitbox:CreateESP(part, color, entityType)
    if not part or not part:IsA("BasePart") then return nil end
    if not Helpers.IsValid(part) then return nil end
    if self._espCache[part] then return self._espCache[part] end
    
    -- Determinar cor
    if not color then
        entityType = entityType or Helpers.GetEntityType(part.Parent or part)
        color = self._colors[entityType] or self._colors[Helpers.EntityTypes.UNKNOWN]
    end
    
    -- Criar BoxHandleAdornment
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "HitboxESP"
    box.Adornee = part
    box.Size = part.Size
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.6
    box.Color3 = color
    box.Parent = part
    
    self._espCache[part] = box
    self._metrics.espCreated = self._metrics.espCreated + 1
    
    return box
end

-- Criar ESP para entidade (usa hitbox visual)
function Hitbox:CreateESPForEntity(entity, color)
    if not entity then return nil end
    if not Helpers.IsValid(entity) then return nil end
    
    local entityType = Helpers.GetEntityType(entity)
    local hitbox = Helpers.GetVisualHitbox(entity)
    
    if not hitbox then return nil end
    
    color = color or self._colors[entityType]
    
    local esp = self:CreateESP(hitbox, color, entityType)
    
    -- Registrar tracking
    if esp then
        self._trackedEntities[entity] = self._trackedEntities[entity] or {}
        self._trackedEntities[entity].hasESP = true
        self._trackedEntities[entity].type = entityType
        self._trackedEntities[entity].hitbox = hitbox
    end
    
    return esp
end

-- ============================================================================
-- REMOVER ESP
-- ============================================================================

function Hitbox:RemoveESP(part)
    local box = self._espCache[part]
    if box then
        Helpers.SafeDestroy(box)
        self._espCache[part] = nil
        self._metrics.espRemoved = self._metrics.espRemoved + 1
        return true
    end
    return false
end

function Hitbox:RemoveESPForEntity(entity)
    if not entity then return false end
    
    local tracking = self._trackedEntities[entity]
    if tracking and tracking.hitbox then
        self:RemoveESP(tracking.hitbox)
        tracking.hasESP = false
    end
    
    -- Também tentar remover de todas as partes do model
    if entity:IsA("Model") then
        for _, child in ipairs(entity:GetDescendants()) do
            if child:IsA("BasePart") then
                self:RemoveESP(child)
            end
        end
    elseif entity:IsA("BasePart") then
        self:RemoveESP(entity)
    end
    
    return true
end

function Hitbox:ClearAllESP()
    for part, box in pairs(self._espCache) do
        Helpers.SafeDestroy(box)
    end
    self._espCache = {}
    
    -- Limpar tracking de ESP
    for entity, tracking in pairs(self._trackedEntities) do
        tracking.hasESP = false
    end
end

-- ============================================================================
-- EXPANDIR HITBOX (LÓGICA PRINCIPAL)
-- ============================================================================

function Hitbox:Expand(entity, customSize)
    if not entity then return false end
    if not Helpers.IsValid(entity) then return false end
    
    local entityType = Helpers.GetEntityType(entity)
    
    -- Normalizar tamanho
    local size = customSize or Config.HitboxSize or Vector3.new(8, 8, 8)
    if typeof(size) == "number" then
        size = Vector3.new(size, size, size)
    end
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER → USAR FAKEHITBOX
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.PLAYER then
        local fakeHitbox = FakeHitbox:Create(entity, size, self._config.showVisualForFake)
        
        if fakeHitbox then
            self._trackedEntities[entity] = self._trackedEntities[entity] or {}
            self._trackedEntities[entity].type = entityType
            self._trackedEntities[entity].isExpanded = true
            self._trackedEntities[entity].useFake = true
            
            self._metrics.playersWithFake = self._metrics.playersWithFake + 1
            return true
        end
        
        return false
    end
    
    -- ═══════════════════════════════════════════════
    -- 🤖🐷 NPC/ANIMAL → EXPANDIR HITBOX REAL
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.NPC or entityType == Helpers.EntityTypes.ANIMAL then
        local hitbox = Helpers.GetRealHitbox(entity)
        if not hitbox then return false end
        
        -- Verificar se já está expandido
        if self._originalSizes[hitbox] then
            -- Apenas atualizar tamanho
            hitbox.Size = size
            if self._espCache[hitbox] then
                self._espCache[hitbox].Size = size
            end
            return true
        end
        
        -- Salvar tamanho original
        self._originalSizes[hitbox] = hitbox.Size
        
        -- Aplicar novo tamanho
        local success = pcall(function()
            hitbox.Size = size
            
            -- ⚠️ PROPRIEDADES CRÍTICAS
            hitbox.CanQuery = true
            hitbox.CanTouch = true
            hitbox.CanCollide = false
        end)
        
        if not success then
            self._originalSizes[hitbox] = nil
            return false
        end
        
        self._expandedParts[hitbox] = true
        
        -- Atualizar ESP se existir
        if self._espCache[hitbox] then
            self._espCache[hitbox].Size = size
        end
        
        -- Registrar tracking
        self._trackedEntities[entity] = self._trackedEntities[entity] or {}
        self._trackedEntities[entity].type = entityType
        self._trackedEntities[entity].isExpanded = true
        self._trackedEntities[entity].hitbox = hitbox
        
        self._metrics.mobsExpanded = self._metrics.mobsExpanded + 1
        return true
    end
    
    -- ═══════════════════════════════════════════════
    -- 📦 ITEM → NÃO EXPANDE
    -- ═══════════════════════════════════════════════
    return false
end

-- ============================================================================
-- RESTAURAR HITBOX
-- ============================================================================

function Hitbox:Restore(entity)
    if not entity then return false end
    
    local entityType = Helpers.GetEntityType(entity)
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER → REMOVER FAKEHITBOX
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.PLAYER then
        local removed = FakeHitbox:Remove(entity)
        
        if removed then
            local tracking = self._trackedEntities[entity]
            if tracking then
                tracking.isExpanded = false
                tracking.useFake = false
            end
            self._metrics.playersWithFake = math.max(0, self._metrics.playersWithFake - 1)
        end
        
        return removed
    end
    
    -- ═══════════════════════════════════════════════
    -- 🤖🐷 NPC/ANIMAL → RESTAURAR HITBOX REAL
    -- ═══════════════════════════════════════════════
    local hitbox = Helpers.GetRealHitbox(entity)
    if not hitbox then return false end
    
    local originalSize = self._originalSizes[hitbox]
    if not originalSize then return false end
    
    if Helpers.IsValid(hitbox) then
        pcall(function()
            hitbox.Size = originalSize
        end)
        
        -- Atualizar ESP se existir
        if self._espCache[hitbox] then
            self._espCache[hitbox].Size = originalSize
        end
    end
    
    self._originalSizes[hitbox] = nil
    self._expandedParts[hitbox] = nil
    
    local tracking = self._trackedEntities[entity]
    if tracking then
        tracking.isExpanded = false
    end
    
    self._metrics.mobsRestored = self._metrics.mobsRestored + 1
    return true
end

function Hitbox:RestoreAll()
    local restored = 0
    
    -- Restaurar players (remover fake hitboxes)
    local fakeRemoved = FakeHitbox:RemoveAll()
    restored = restored + fakeRemoved
    self._metrics.playersWithFake = 0
    
    -- Restaurar mobs/animals
    local partsToRestore = {}
    for part in pairs(self._originalSizes) do
        table.insert(partsToRestore, part)
    end
    
    for _, part in ipairs(partsToRestore) do
        local originalSize = self._originalSizes[part]
        if originalSize and Helpers.IsValid(part) then
            pcall(function()
                part.Size = originalSize
            end)
            
            if self._espCache[part] then
                self._espCache[part].Size = originalSize
            end
            
            restored = restored + 1
        end
        
        self._originalSizes[part] = nil
        self._expandedParts[part] = nil
    end
    
    -- Limpar tracking de expansão
    for entity, tracking in pairs(self._trackedEntities) do
        tracking.isExpanded = false
        tracking.useFake = false
    end
    
    self._metrics.mobsRestored = self._metrics.mobsRestored + restored
    return restored
end

-- ============================================================================
-- ATUALIZAR TAMANHO GLOBAL
-- ============================================================================

function Hitbox:UpdateSize(newSize)
    if typeof(newSize) == "number" then
        newSize = Vector3.new(newSize, newSize, newSize)
    end
    
    Config.HitboxSize = newSize
    
    -- Atualizar FakeHitbox config
    FakeHitbox:Configure({ defaultSize = newSize })
    
    -- Atualizar fake hitboxes existentes
    for char in pairs(FakeHitbox._active or {}) do
        FakeHitbox:UpdateSize(char, newSize)
    end
    
    -- Atualizar hitboxes de mobs expandidos
    for part in pairs(self._expandedParts) do
        if Helpers.IsValid(part) then
            pcall(function()
                part.Size = newSize
            end)
            
            if self._espCache[part] then
                self._espCache[part].Size = newSize
            end
        end
    end
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

function Hitbox:StartUpdateLoop()
    if self._updateLoopRunning then return end
    self._updateLoopRunning = true
    
    ConnectionManager:Add("hitbox_updateLoop", RunService.Heartbeat:Connect(function()
        if not Config.ShowHitboxESP and not Config.ExpandHitbox then return end
        if Config.SafeMode then return end
        
        local startTime = tick()
        
        -- ═══════════════════════════════════════════════
        -- AUTO-TRACK PLAYERS
        -- ═══════════════════════════════════════════════
        if self._config.autoTrackPlayers then
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    local char = otherPlayer.Character
                    
                    -- ESP
                    if Config.ShowHitboxESP then
                        local hitbox = Helpers.GetVisualHitbox(char)
                        if hitbox and not self._espCache[hitbox] then
                            self:CreateESP(hitbox, self._colors[Helpers.EntityTypes.PLAYER], Helpers.EntityTypes.PLAYER)
                        end
                    end
                    
                    -- Expandir (usa FakeHitbox)
                    if Config.ExpandHitbox then
                        if not FakeHitbox:Has(char) then
                            self:Expand(char)
                        end
                    end
                end
            end
        end
        
        -- ═══════════════════════════════════════════════
        -- AUTO-TRACK MOBS
        -- ═══════════════════════════════════════════════
        if self._config.autoTrackMobs then
            local entitiesFolder = workspace:FindFirstChild("Entities")
            if entitiesFolder then
                for _, entity in ipairs(entitiesFolder:GetChildren()) do
                    if entity:IsA("Model") then
                        local entityType = Helpers.GetEntityType(entity)
                        
                        if entityType == Helpers.EntityTypes.NPC or entityType == Helpers.EntityTypes.ANIMAL then
                            -- ESP
                            if Config.ShowHitboxESP then
                                local hitbox = Helpers.GetVisualHitbox(entity)
                                if hitbox and not self._espCache[hitbox] then
                                    self:CreateESP(hitbox, self._colors[entityType], entityType)
                                end
                            end
                            
                            -- Expandir
                            if Config.ExpandHitbox then
                                local hitbox = Helpers.GetRealHitbox(entity)
                                if hitbox and not self._expandedParts[hitbox] then
                                    self:Expand(entity)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- ═══════════════════════════════════════════════
        -- CLEANUP
        -- ═══════════════════════════════════════════════
        local toRemoveESP = {}
        for part in pairs(self._espCache) do
            if not Helpers.IsValid(part) then
                table.insert(toRemoveESP, part)
            end
        end
        
        for _, part in ipairs(toRemoveESP) do
            self._espCache[part] = nil
            self._originalSizes[part] = nil
            self._expandedParts[part] = nil
        end
        
        -- Cleanup tracking
        local toRemoveTracking = {}
        for entity in pairs(self._trackedEntities) do
            if not Helpers.IsValid(entity) then
                table.insert(toRemoveTracking, entity)
            end
        end
        
        for _, entity in ipairs(toRemoveTracking) do
            self._trackedEntities[entity] = nil
        end
        
        self._metrics.lastUpdateTime = tick() - startTime
        
    end), "hitbox")
end

function Hitbox:StopUpdateLoop()
    ConnectionManager:Remove("hitbox_updateLoop")
    self._updateLoopRunning = false
end

-- ============================================================================
-- TOGGLE FUNCTIONS
-- ============================================================================

function Hitbox:ToggleESP(state)
    Config.ShowHitboxESP = state
    
    if not state then
        self:ClearAllESP()
    end
end

function Hitbox:ToggleExpand(state)
    Config.ExpandHitbox = state
    
    if not state then
        self:RestoreAll()
    end
end

function Hitbox:ToggleFakeVisual(state)
    self._config.showVisualForFake = state
    FakeHitbox:ToggleVisuals(state)
end

-- ============================================================================
-- ATUALIZAR CORES
-- ============================================================================

function Hitbox:UpdateColor(entityType, color)
    self._colors[entityType] = color
    
    -- Atualizar ESPs existentes
    for entity, tracking in pairs(self._trackedEntities) do
        if tracking.type == entityType and tracking.hitbox then
            local esp = self._espCache[tracking.hitbox]
            if esp and esp.Parent then
                esp.Color3 = color
            end
        end
    end
    
    -- Atualizar cor do FakeHitbox para players
    if entityType == Helpers.EntityTypes.PLAYER then
        FakeHitbox:Configure({ visualColor = color })
    end
end

-- ============================================================================
-- GETTERS E MÉTRICAS
-- ============================================================================

function Hitbox:GetESPCount()
    local count = 0
    for _ in pairs(self._espCache) do
        count = count + 1
    end
    return count
end

function Hitbox:GetExpandedCount()
    local mobCount = 0
    for _ in pairs(self._expandedParts) do
        mobCount = mobCount + 1
    end
    return mobCount + FakeHitbox:GetCount()
end

function Hitbox:GetTrackedCount()
    local count = 0
    for _ in pairs(self._trackedEntities) do
        count = count + 1
    end
    return count
end

function Hitbox:IsExpanded(entity)
    local entityType = Helpers.GetEntityType(entity)
    
    if entityType == Helpers.EntityTypes.PLAYER then
        return FakeHitbox:Has(entity)
    end
    
    local hitbox = Helpers.GetRealHitbox(entity)
    return hitbox and self._expandedParts[hitbox] == true
end

function Hitbox:HasESP(part)
    return self._espCache[part] ~= nil
end

function Hitbox:GetMetrics()
    local fakeMetrics = FakeHitbox:GetMetrics()
    
    return {
        -- ESP
        espCount = self:GetESPCount(),
        espCreated = self._metrics.espCreated,
        espRemoved = self._metrics.espRemoved,
        
        -- Expansão
        expandedCount = self:GetExpandedCount(),
        mobsExpanded = self._metrics.mobsExpanded,
        mobsRestored = self._metrics.mobsRestored,
        
        -- FakeHitbox
        playersWithFake = fakeMetrics.currentActive,
        fakeCreated = fakeMetrics.totalCreated,
        fakeRemoved = fakeMetrics.totalRemoved,
        
        -- Tracking
        trackedCount = self:GetTrackedCount(),
        
        -- Performance
        lastUpdateTime = string.format("%.4fms", self._metrics.lastUpdateTime * 1000),
        updateLoopRunning = self._updateLoopRunning,
    }
end

-- ============================================================================
-- CONFIGURAÇÃO
-- ============================================================================

function Hitbox:Configure(options)
    if options.autoTrackPlayers ~= nil then
        self._config.autoTrackPlayers = options.autoTrackPlayers
    end
    
    if options.autoTrackMobs ~= nil then
        self._config.autoTrackMobs = options.autoTrackMobs
    end
    
    if options.showVisualForFake ~= nil then
        self:ToggleFakeVisual(options.showVisualForFake)
    end
    
    if options.colors then
        for entityType, color in pairs(options.colors) do
            self._colors[entityType] = color
        end
    end
end

function Hitbox:GetConfig()
    return {
        autoTrackPlayers = self._config.autoTrackPlayers,
        autoTrackMobs = self._config.autoTrackMobs,
        showVisualForFake = self._config.showVisualForFake,
        colors = self._colors,
    }
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Hitbox = Hitbox
_G.MineHub.FakeHitbox = FakeHitbox

return Hitbox