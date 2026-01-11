-- ============================================================================
-- HITBOX v2.0 - Integrado com Helpers e Sistema de Tracking
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Helpers = require("Utils/Helpers")
local ConnectionManager = require("Engine/ConnectionManager")
local Cache = require("Engine/Cache")

local Hitbox = {
    -- ═══════════════════════════════════════════════
    -- CACHE DE ESP E TAMANHOS
    -- ═══════════════════════════════════════════════
    _espCache = {},           -- part -> BoxHandleAdornment
    _originalSizes = {},      -- part -> Vector3
    _trackedEntities = {},    -- model -> {parts = {}, type = string}
    
    -- ═══════════════════════════════════════════════
    -- CORES POR TIPO DE ENTIDADE
    -- ═══════════════════════════════════════════════
    _colors = {
        Player = Color3.fromRGB(255, 0, 0),      -- Vermelho
        Animal = Color3.fromRGB(255, 165, 0),    -- Laranja
        Mob = Color3.fromRGB(255, 100, 100),     -- Vermelho claro
        Item = Color3.fromRGB(255, 255, 0),      -- Amarelo
        Unknown = Color3.fromRGB(255, 255, 255), -- Branco
    },
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO
    -- ═══════════════════════════════════════════════
    _config = {
        updateInterval = 0.1,      -- Segundos entre updates
        autoTrackPlayers = true,   -- Auto-track de players
        autoTrackMobs = true,      -- Auto-track de mobs
        showOutline = true,        -- Mostrar outline da box
        adaptiveSize = false,      -- Tamanho adaptativo por tipo
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
        totalCreated = 0,
        totalRemoved = 0,
        totalExpanded = 0,
        totalRestored = 0,
        currentTracked = 0,
        lastUpdateTime = 0,
    },
}

local player = Players.LocalPlayer

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

function Hitbox:Init()
    if self._initialized then return end
    
    -- Iniciar loop de update se auto-track está ativado
    if self._config.autoTrackPlayers or self._config.autoTrackMobs then
        self:StartUpdateLoop()
    end
    
    self._initialized = true
end

-- ============================================================================
-- CRIAR ESP (MELHORADO)
-- ============================================================================

function Hitbox:CreateESP(part, color, entityType)
    if not part or not part:IsA("BasePart") then return nil end
    if not Helpers.IsValid(part) then return nil end
    if self._espCache[part] then return self._espCache[part] end
    
    -- Determinar cor baseada no tipo de entidade
    if not color then
        entityType = entityType or Helpers.GetEntityType(part.Parent or part)
        color = self._colors[entityType] or self._colors.Unknown
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
    
    -- Parent seguro
    box.Parent = part
    
    self._espCache[part] = box
    self._metrics.totalCreated = self._metrics.totalCreated + 1
    
    return box
end

-- Criar ESP para entidade completa (Model)
function Hitbox:CreateESPForEntity(entity, color)
    if not entity then return {} end
    if not Helpers.IsValid(entity) then return {} end
    
    local created = {}
    local entityType = Helpers.GetEntityType(entity)
    color = color or self._colors[entityType] or self._colors.Unknown
    
    -- Se for Model, criar para a hitbox principal
    if entity:IsA("Model") then
        local hitbox = Helpers.GetHitbox(entity)
        if hitbox then
            local esp = self:CreateESP(hitbox, color, entityType)
            if esp then
                table.insert(created, esp)
            end
        end
        
        -- Opcionalmente, criar para todas as partes
        if self._config.showAllParts then
            for _, child in ipairs(entity:GetDescendants()) do
                if child:IsA("BasePart") and child ~= hitbox then
                    local esp = self:CreateESP(child, color, entityType)
                    if esp then
                        table.insert(created, esp)
                    end
                end
            end
        end
    elseif entity:IsA("BasePart") then
        local esp = self:CreateESP(entity, color, entityType)
        if esp then
            table.insert(created, esp)
        end
    end
    
    -- Registrar tracking
    if #created > 0 then
        self._trackedEntities[entity] = {
            parts = created,
            type = entityType,
            createdAt = tick(),
        }
        self._metrics.currentTracked = self._metrics.currentTracked + 1
    end
    
    return created
end

-- ============================================================================
-- REMOVER ESP
-- ============================================================================

function Hitbox:RemoveESP(part)
    local box = self._espCache[part]
    if box then
        Helpers.SafeDestroy(box)
        self._espCache[part] = nil
        self._metrics.totalRemoved = self._metrics.totalRemoved + 1
        return true
    end
    return false
end

-- Remover ESP de entidade completa
function Hitbox:RemoveESPForEntity(entity)
    if not entity then return 0 end
    
    local tracking = self._trackedEntities[entity]
    if tracking then
        for _, esp in ipairs(tracking.parts) do
            Helpers.SafeDestroy(esp)
        end
        self._trackedEntities[entity] = nil
        self._metrics.currentTracked = math.max(0, self._metrics.currentTracked - 1)
    end
    
    -- Também remover do cache direto
    if entity:IsA("Model") then
        for _, child in ipairs(entity:GetDescendants()) do
            if child:IsA("BasePart") then
                self:RemoveESP(child)
            end
        end
    elseif entity:IsA("BasePart") then
        self:RemoveESP(entity)
    end
    
    return 1
end

-- Limpar todos os ESPs
function Hitbox:ClearAllESP()
    -- Limpar cache de ESP
    for part, box in pairs(self._espCache) do
        Helpers.SafeDestroy(box)
    end
    self._espCache = {}
    
    -- Limpar tracking
    self._trackedEntities = {}
    self._metrics.currentTracked = 0
end

-- ============================================================================
-- EXPANSÃO DE HITBOX (MELHORADO)
-- ============================================================================

function Hitbox:Expand(part, customSize)
    if not part or not part:IsA("BasePart") then return false end
    if not Helpers.IsValid(part) then return false end
    if self._originalSizes[part] then return false end -- Já expandido
    
    -- Salvar tamanho original
    self._originalSizes[part] = part.Size
    
    -- Determinar novo tamanho
    local newSize = customSize
    
    if not newSize then
        if self._config.adaptiveSize then
            -- Tamanho adaptativo baseado no tipo de entidade
            local entityType = Helpers.GetEntityType(part.Parent or part)
            if entityType == Helpers.EntityTypes.PLAYER then
                newSize = Config.HitboxSize or Vector3.new(6, 6, 6)
            elseif entityType == Helpers.EntityTypes.ANIMAL then
                newSize = (Config.HitboxSize or Vector3.new(6, 6, 6)) * 0.8
            else
                newSize = Config.HitboxSize or Vector3.new(6, 6, 6)
            end
        else
            newSize = Config.HitboxSize or Vector3.new(6, 6, 6)
        end
    end
    
    -- Aplicar novo tamanho
    local success = pcall(function()
        part.Size = newSize
    end)
    
    if not success then
        self._originalSizes[part] = nil
        return false
    end
    
    -- Atualizar ESP se existir
    if self._espCache[part] then
        self._espCache[part].Size = newSize
    end
    
    self._metrics.totalExpanded = self._metrics.totalExpanded + 1
    return true
end

-- Expandir hitbox de entidade
function Hitbox:ExpandEntity(entity, customSize)
    if not entity then return 0 end
    
    local expanded = 0
    
    if entity:IsA("Model") then
        local hitbox = Helpers.GetHitbox(entity)
        if hitbox and self:Expand(hitbox, customSize) then
            expanded = expanded + 1
        end
    elseif entity:IsA("BasePart") then
        if self:Expand(entity, customSize) then
            expanded = expanded + 1
        end
    end
    
    return expanded
end

-- ============================================================================
-- RESTAURAR HITBOX
-- ============================================================================

function Hitbox:Restore(part)
    local originalSize = self._originalSizes[part]
    if not originalSize then return false end
    
    if Helpers.IsValid(part) then
        local success = pcall(function()
            part.Size = originalSize
        end)
        
        if success then
            -- Atualizar ESP se existir
            if self._espCache[part] then
                self._espCache[part].Size = originalSize
            end
        end
    end
    
    self._originalSizes[part] = nil
    self._metrics.totalRestored = self._metrics.totalRestored + 1
    return true
end

-- Restaurar entidade
function Hitbox:RestoreEntity(entity)
    if not entity then return 0 end
    
    local restored = 0
    
    if entity:IsA("Model") then
        for _, child in ipairs(entity:GetDescendants()) do
            if child:IsA("BasePart") then
                if self:Restore(child) then
                    restored = restored + 1
                end
            end
        end
    elseif entity:IsA("BasePart") then
        if self:Restore(entity) then
            restored = restored + 1
        end
    end
    
    return restored
end

-- Restaurar todos
function Hitbox:RestoreAll()
    local restored = 0
    
    local partsToRestore = {}
    for part in pairs(self._originalSizes) do
        table.insert(partsToRestore, part)
    end
    
    for _, part in ipairs(partsToRestore) do
        if self:Restore(part) then
            restored = restored + 1
        end
    end
    
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
    
    -- Atualizar todas as hitboxes expandidas
    for part in pairs(self._originalSizes) do
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
-- ATUALIZAR COR
-- ============================================================================

function Hitbox:UpdateColor(part, color)
    local box = self._espCache[part]
    if box then
        box.Color3 = color
        return true
    end
    return false
end

function Hitbox:UpdateColorByType(entityType, color)
    self._colors[entityType] = color
    
    -- Atualizar ESPs existentes do mesmo tipo
    for entity, tracking in pairs(self._trackedEntities) do
        if tracking.type == entityType then
            for _, esp in ipairs(tracking.parts) do
                if esp and esp.Parent then
                    esp.Color3 = color
                end
            end
        end
    end
end

-- ============================================================================
-- UPDATE LOOP (AUTO-TRACKING)
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
        if self._config.autoTrackPlayers and Config.ShowHitboxESP then
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    local hitbox = Helpers.GetHitbox(otherPlayer.Character)
                    if hitbox and not self._espCache[hitbox] then
                        self:CreateESP(hitbox, self._colors.Player, "Player")
                    end
                    
                    -- Expandir se configurado
                    if Config.ExpandHitbox and hitbox then
                        self:Expand(hitbox)
                    end
                end
            end
        end
        
        -- ═══════════════════════════════════════════════
        -- AUTO-TRACK MOBS (via Entities folder)
        -- ═══════════════════════════════════════════════
        if self._config.autoTrackMobs and Config.ShowHitboxESP then
            local entitiesFolder = workspace:FindFirstChild("Entities")
            if entitiesFolder then
                for _, entity in ipairs(entitiesFolder:GetChildren()) do
                    if entity:IsA("Model") then
                        local entityType = Helpers.GetEntityType(entity)
                        
                        if entityType == Helpers.EntityTypes.ANIMAL or entityType == Helpers.EntityTypes.MOB then
                            local hitbox = Helpers.GetHitbox(entity)
                            if hitbox and not self._espCache[hitbox] then
                                self:CreateESP(hitbox, self._colors[entityType], entityType)
                            end
                            
                            -- Expandir se configurado
                            if Config.ExpandHitbox and hitbox then
                                self:Expand(hitbox)
                            end
                        end
                    end
                end
            end
        end
        
        -- ═══════════════════════════════════════════════
        -- CLEANUP DE ESPS MORTOS
        -- ═══════════════════════════════════════════════
        local toRemove = {}
        for part, box in pairs(self._espCache) do
            if not Helpers.IsValid(part) or not Helpers.IsValid(box) then
                table.insert(toRemove, part)
            end
        end
        
        for _, part in ipairs(toRemove) do
            self._espCache[part] = nil
            self._originalSizes[part] = nil
        end
        
        -- Cleanup tracking
        local trackingToRemove = {}
        for entity in pairs(self._trackedEntities) do
            if not Helpers.IsValid(entity) then
                table.insert(trackingToRemove, entity)
            end
        end
        
        for _, entity in ipairs(trackingToRemove) do
            self._trackedEntities[entity] = nil
            self._metrics.currentTracked = math.max(0, self._metrics.currentTracked - 1)
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
    local count = 0
    for _ in pairs(self._originalSizes) do
        count = count + 1
    end
    return count
end

function Hitbox:GetTrackedCount()
    local count = 0
    for _ in pairs(self._trackedEntities) do
        count = count + 1
    end
    return count
end

function Hitbox:IsExpanded(part)
    return self._originalSizes[part] ~= nil
end

function Hitbox:HasESP(part)
    return self._espCache[part] ~= nil
end

function Hitbox:GetMetrics()
    return {
        espCount = self:GetESPCount(),
        expandedCount = self:GetExpandedCount(),
        trackedCount = self:GetTrackedCount(),
        totalCreated = self._metrics.totalCreated,
        totalRemoved = self._metrics.totalRemoved,
        totalExpanded = self._metrics.totalExpanded,
        totalRestored = self._metrics.totalRestored,
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
    
    if options.adaptiveSize ~= nil then
        self._config.adaptiveSize = options.adaptiveSize
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
        adaptiveSize = self._config.adaptiveSize,
        colors = self._colors,
    }
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Hitbox = Hitbox

return Hitbox