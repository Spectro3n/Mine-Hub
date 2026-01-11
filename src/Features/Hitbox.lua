-- ============================================================================
-- HITBOX v3.0 - Sistema Correto de Expansão
-- ============================================================================
-- ✅ Player → Expande HumanoidRootPart REAL (único que funciona)
-- ✅ Mob/Animal → Expande Hitbox REAL
-- ✅ FakeHitbox → Apenas para ESP visual (não afeta hit)
-- ✅ CanQuery = true, CanTouch = true, CanCollide = false
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Helpers = require("Utils/Helpers")
local ConnectionManager = require("Engine/ConnectionManager")

local Hitbox = {
    -- ═══════════════════════════════════════════════
    -- CACHE DE TAMANHOS ORIGINAIS
    -- ═══════════════════════════════════════════════
    _originalSizes = {},      -- part -> Vector3
    _expandedParts = {},      -- part -> true
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE ESP (VISUAL ONLY)
    -- ═══════════════════════════════════════════════
    _espCache = {},           -- part -> BoxHandleAdornment
    
    -- ═══════════════════════════════════════════════
    -- TRACKING
    -- ═══════════════════════════════════════════════
    _trackedEntities = {},    -- entity -> { hitbox, type, isExpanded }
    
    -- ═══════════════════════════════════════════════
    -- CORES POR TIPO
    -- ═══════════════════════════════════════════════
    _colors = {
        [Helpers.EntityTypes.PLAYER] = Color3.fromRGB(255, 0, 0),
        [Helpers.EntityTypes.NPC] = Color3.fromRGB(255, 100, 100),
        [Helpers.EntityTypes.ANIMAL] = Color3.fromRGB(255, 165, 0),
        [Helpers.EntityTypes.ITEM] = Color3.fromRGB(255, 255, 0),
        [Helpers.EntityTypes.UNKNOWN] = Color3.fromRGB(255, 255, 255),
    },
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO
    -- ═══════════════════════════════════════════════
    _config = {
        autoTrackPlayers = true,
        autoTrackMobs = true,
        defaultSize = Vector3.new(8, 8, 8),
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
        playersExpanded = 0,
        mobsExpanded = 0,
        totalRestored = 0,
        espCreated = 0,
        espRemoved = 0,
        lastUpdateTime = 0,
    },
}

local player = Players.LocalPlayer

-- ============================================================================
-- HELPERS LOCAIS
-- ============================================================================

local function isValid(instance)
    if not instance then return false end
    if typeof(instance) ~= "Instance" then return false end
    local success, parent = pcall(function() return instance.Parent end)
    return success and parent ~= nil
end

local function safeDestroy(obj)
    if obj and typeof(obj) == "Instance" then
        pcall(function() obj:Destroy() end)
    end
end

-- ============================================================================
-- OBTER HITBOX REAL PARA EXPANSÃO
-- ============================================================================

local function getRealHitboxForExpansion(entity)
    if not entity then return nil, nil end
    if not isValid(entity) then return nil, nil end
    
    local entityType = Helpers.GetEntityType(entity)
    local hitbox = nil
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER → HumanoidRootPart (ÚNICO QUE FUNCIONA!)
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.PLAYER then
        -- ⚠️ NUNCA usar playerhitbox para expansão real
        -- ⚠️ NUNCA criar FakeHitbox para hit
        -- ✅ SEMPRE usar HumanoidRootPart
        hitbox = entity:FindFirstChild("HumanoidRootPart")
        
        if not hitbox then
            -- Fallback para R6
            hitbox = entity:FindFirstChild("Torso")
        end
        
        return hitbox, entityType
    end
    
    -- ═══════════════════════════════════════════════
    -- 🤖 NPC → HumanoidRootPart ou Hitbox
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.NPC then
        hitbox = entity:FindFirstChild("Hitbox")
            or entity:FindFirstChild("HumanoidRootPart")
            or entity.PrimaryPart
        
        return hitbox, entityType
    end
    
    -- ═══════════════════════════════════════════════
    -- 🐷 ANIMAL → Hitbox real
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.ANIMAL then
        hitbox = entity:FindFirstChild("Hitbox")
            or entity.PrimaryPart
            or entity:FindFirstChildWhichIsA("BasePart")
        
        return hitbox, entityType
    end
    
    return nil, entityType
end

-- ============================================================================
-- OBTER HITBOX PARA ESP (PODE USAR PLAYERHITBOX)
-- ============================================================================

local function getHitboxForESP(entity)
    if not entity then return nil end
    if not isValid(entity) then return nil end
    
    local entityType = Helpers.GetEntityType(entity)
    
    -- Player: pode usar playerhitbox para ESP
    if entityType == Helpers.EntityTypes.PLAYER then
        return entity:FindFirstChild("playerhitbox")
            or entity:FindFirstChild("HumanoidRootPart")
    end
    
    -- Outros: usar hitbox real
    return entity:FindFirstChild("Hitbox")
        or entity:FindFirstChild("HumanoidRootPart")
        or entity.PrimaryPart
        or entity:FindFirstChildWhichIsA("BasePart")
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

function Hitbox:Init()
    if self._initialized then return end
    
    if self._config.autoTrackPlayers or self._config.autoTrackMobs then
        self:StartUpdateLoop()
    end
    
    self._initialized = true
end

-- ============================================================================
-- EXPANDIR HITBOX (FUNCIONAL - AFETA HIT REAL)
-- ============================================================================

function Hitbox:Expand(entity, customSize)
    if not entity then return false end
    if not isValid(entity) then return false end
    
    -- Obter hitbox REAL para expansão
    local hitbox, entityType = getRealHitboxForExpansion(entity)
    
    if not hitbox then
        return false
    end
    
    -- Verificar se já está expandido
    if self._originalSizes[hitbox] then
        -- Apenas atualizar tamanho
        return self:UpdateSize(hitbox, customSize)
    end
    
    -- Normalizar tamanho
    local size = customSize or Config.HitboxSize or self._config.defaultSize
    if typeof(size) == "number" then
        size = Vector3.new(size, size, size)
    end
    
    -- ═══════════════════════════════════════════════
    -- SALVAR TAMANHO ORIGINAL
    -- ═══════════════════════════════════════════════
    self._originalSizes[hitbox] = hitbox.Size
    
    -- ═══════════════════════════════════════════════
    -- EXPANDIR COM PROPRIEDADES CORRETAS
    -- ═══════════════════════════════════════════════
    local success = pcall(function()
        hitbox.Size = size
        
        -- ⚠️ PROPRIEDADES CRÍTICAS PARA FUNCIONAR
        hitbox.CanQuery = true      -- Permite Raycast detectar
        hitbox.CanTouch = true      -- Permite Touch events
        hitbox.CanCollide = false   -- Não bloqueia movimento
    end)
    
    if not success then
        self._originalSizes[hitbox] = nil
        return false
    end
    
    -- Registrar
    self._expandedParts[hitbox] = true
    
    self._trackedEntities[entity] = self._trackedEntities[entity] or {}
    self._trackedEntities[entity].hitbox = hitbox
    self._trackedEntities[entity].type = entityType
    self._trackedEntities[entity].isExpanded = true
    
    -- Métricas
    if entityType == Helpers.EntityTypes.PLAYER then
        self._metrics.playersExpanded = self._metrics.playersExpanded + 1
    else
        self._metrics.mobsExpanded = self._metrics.mobsExpanded + 1
    end
    
    return true
end

-- ============================================================================
-- ATUALIZAR TAMANHO
-- ============================================================================

function Hitbox:UpdateSize(hitbox, newSize)
    if not hitbox then return false end
    if not self._expandedParts[hitbox] then return false end
    
    if typeof(newSize) == "number" then
        newSize = Vector3.new(newSize, newSize, newSize)
    end
    
    newSize = newSize or Config.HitboxSize or self._config.defaultSize
    
    local success = pcall(function()
        hitbox.Size = newSize
    end)
    
    -- Atualizar ESP se existir
    if self._espCache[hitbox] then
        self._espCache[hitbox].Size = newSize
    end
    
    return success
end

-- ============================================================================
-- RESTAURAR HITBOX
-- ============================================================================

function Hitbox:Restore(entity)
    if not entity then return false end
    
    -- Obter hitbox
    local hitbox = nil
    local tracking = self._trackedEntities[entity]
    
    if tracking and tracking.hitbox then
        hitbox = tracking.hitbox
    else
        hitbox = getRealHitboxForExpansion(entity)
    end
    
    if not hitbox then return false end
    
    -- Restaurar tamanho original
    local originalSize = self._originalSizes[hitbox]
    if not originalSize then return false end
    
    if isValid(hitbox) then
        pcall(function()
            hitbox.Size = originalSize
        end)
        
        -- Atualizar ESP
        if self._espCache[hitbox] then
            self._espCache[hitbox].Size = originalSize
        end
    end
    
    -- Limpar registros
    self._originalSizes[hitbox] = nil
    self._expandedParts[hitbox] = nil
    
    if tracking then
        tracking.isExpanded = false
    end
    
    self._metrics.totalRestored = self._metrics.totalRestored + 1
    
    return true
end

function Hitbox:RestoreAll()
    local restored = 0
    
    -- Coletar partes para restaurar
    local partsToRestore = {}
    for part in pairs(self._originalSizes) do
        table.insert(partsToRestore, part)
    end
    
    -- Restaurar cada uma
    for _, part in ipairs(partsToRestore) do
        local originalSize = self._originalSizes[part]
        
        if originalSize and isValid(part) then
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
    
    -- Limpar tracking
    for entity, tracking in pairs(self._trackedEntities) do
        tracking.isExpanded = false
    end
    
    self._metrics.totalRestored = self._metrics.totalRestored + restored
    self._metrics.playersExpanded = 0
    self._metrics.mobsExpanded = 0
    
    return restored
end

-- ============================================================================
-- ATUALIZAR TAMANHO GLOBAL
-- ============================================================================

function Hitbox:UpdateGlobalSize(newSize)
    if typeof(newSize) == "number" then
        newSize = Vector3.new(newSize, newSize, newSize)
    end
    
    Config.HitboxSize = newSize
    self._config.defaultSize = newSize
    
    -- Atualizar todas as hitboxes expandidas
    for part in pairs(self._expandedParts) do
        if isValid(part) then
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
-- ESP (VISUAL ONLY - NÃO AFETA HIT)
-- ============================================================================

function Hitbox:CreateESP(part, color, entityType)
    if not part or not part:IsA("BasePart") then return nil end
    if not isValid(part) then return nil end
    if self._espCache[part] then return self._espCache[part] end
    
    if not color then
        entityType = entityType or Helpers.GetEntityType(part.Parent or part)
        color = self._colors[entityType] or self._colors[Helpers.EntityTypes.UNKNOWN]
    end
    
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

function Hitbox:CreateESPForEntity(entity, color)
    if not entity then return nil end
    
    local entityType = Helpers.GetEntityType(entity)
    local hitbox = getHitboxForESP(entity)
    
    if not hitbox then return nil end
    
    color = color or self._colors[entityType]
    
    return self:CreateESP(hitbox, color, entityType)
end

function Hitbox:RemoveESP(part)
    local box = self._espCache[part]
    if box then
        safeDestroy(box)
        self._espCache[part] = nil
        self._metrics.espRemoved = self._metrics.espRemoved + 1
        return true
    end
    return false
end

function Hitbox:RemoveESPForEntity(entity)
    if not entity then return false end
    
    local hitbox = getHitboxForESP(entity)
    if hitbox then
        self:RemoveESP(hitbox)
    end
    
    -- Também tentar remover de partes conhecidas
    if entity:IsA("Model") then
        for _, child in ipairs(entity:GetDescendants()) do
            if child:IsA("BasePart") then
                self:RemoveESP(child)
            end
        end
    end
    
    return true
end

function Hitbox:ClearAllESP()
    for part, box in pairs(self._espCache) do
        safeDestroy(box)
    end
    self._espCache = {}
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
                    
                    -- ESP (visual)
                    if Config.ShowHitboxESP then
                        local espHitbox = getHitboxForESP(char)
                        if espHitbox and not self._espCache[espHitbox] then
                            self:CreateESP(espHitbox, self._colors[Helpers.EntityTypes.PLAYER])
                        end
                    end
                    
                    -- Expandir (funcional - usa HRP real)
                    if Config.ExpandHitbox then
                        local realHitbox = getRealHitboxForExpansion(char)
                        if realHitbox and not self._expandedParts[realHitbox] then
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
                        
                        if entityType == Helpers.EntityTypes.NPC or 
                           entityType == Helpers.EntityTypes.ANIMAL then
                            
                            -- ESP
                            if Config.ShowHitboxESP then
                                local espHitbox = getHitboxForESP(entity)
                                if espHitbox and not self._espCache[espHitbox] then
                                    self:CreateESP(espHitbox, self._colors[entityType])
                                end
                            end
                            
                            -- Expandir
                            if Config.ExpandHitbox then
                                local realHitbox = getRealHitboxForExpansion(entity)
                                if realHitbox and not self._expandedParts[realHitbox] then
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
        
        -- Limpar ESPs de objetos mortos
        local toRemoveESP = {}
        for part in pairs(self._espCache) do
            if not isValid(part) then
                table.insert(toRemoveESP, part)
            end
        end
        for _, part in ipairs(toRemoveESP) do
            safeDestroy(self._espCache[part])
            self._espCache[part] = nil
        end
        
        -- Limpar expansões de objetos mortos
        local toRemoveExpand = {}
        for part in pairs(self._expandedParts) do
            if not isValid(part) then
                table.insert(toRemoveExpand, part)
            end
        end
        for _, part in ipairs(toRemoveExpand) do
            self._originalSizes[part] = nil
            self._expandedParts[part] = nil
        end
        
        -- Limpar tracking
        local toRemoveTracking = {}
        for entity in pairs(self._trackedEntities) do
            if not isValid(entity) then
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

-- ============================================================================
-- ATUALIZAR COR
-- ============================================================================

function Hitbox:UpdateColor(entityType, color)
    self._colors[entityType] = color
    
    for entity, tracking in pairs(self._trackedEntities) do
        if tracking.type == entityType and tracking.hitbox then
            local esp = self._espCache[tracking.hitbox]
            if esp and esp.Parent then
                esp.Color3 = color
            end
        end
    end
end

-- ============================================================================
-- GETTERS
-- ============================================================================

function Hitbox:GetESPCount()
    local count = 0
    for _ in pairs(self._espCache) do count = count + 1 end
    return count
end

function Hitbox:GetExpandedCount()
    local count = 0
    for _ in pairs(self._expandedParts) do count = count + 1 end
    return count
end

function Hitbox:IsExpanded(entity)
    local hitbox = getRealHitboxForExpansion(entity)
    return hitbox and self._expandedParts[hitbox] == true
end

function Hitbox:HasESP(part)
    return self._espCache[part] ~= nil
end

function Hitbox:GetMetrics()
    return {
        espCount = self:GetESPCount(),
        expandedCount = self:GetExpandedCount(),
        playersExpanded = self._metrics.playersExpanded,
        mobsExpanded = self._metrics.mobsExpanded,
        totalRestored = self._metrics.totalRestored,
        espCreated = self._metrics.espCreated,
        espRemoved = self._metrics.espRemoved,
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
    if options.defaultSize then
        self._config.defaultSize = options.defaultSize
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
        defaultSize = self._config.defaultSize,
        colors = self._colors,
    }
end

-- ============================================================================
-- EXPORT
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Hitbox = Hitbox

return Hitbox