-- ============================================================================
-- CACHE v2.0 - Otimizado para ItemESP e Performance
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Cache = {
    -- ═══════════════════════════════════════════════
    -- CACHE DE POSIÇÃO/CÂMERA
    -- ═══════════════════════════════════════════════
    CameraPosition = Vector3.zero,
    CameraCFrame = CFrame.identity,
    
    -- ═══════════════════════════════════════════════
    -- REFERÊNCIAS DO PLAYER
    -- ═══════════════════════════════════════════════
    LocalPlayer = Players.LocalPlayer,
    Character = nil,
    HumanoidRootPart = nil,
    Humanoid = nil,
    
    -- ═══════════════════════════════════════════════
    -- TIMING
    -- ═══════════════════════════════════════════════
    LastUpdate = 0,
    UpdateInterval = 0.016, -- ~60fps
    FrameCount = 0,
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE DISTÂNCIAS (com TTL)
    -- ═══════════════════════════════════════════════
    _distanceCache = {},
    _distanceCacheTTL = 0.1, -- 100ms de validade
    _distanceCacheHits = 0,
    _distanceCacheMisses = 0,
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE SAÚDE (para ESPs)
    -- ═══════════════════════════════════════════════
    RealHealth = {},
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE MINERAIS
    -- ═══════════════════════════════════════════════
    MineralResults = setmetatable({}, {__mode = "k"}),
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE ENTIDADES
    -- ═══════════════════════════════════════════════
    _entityCache = setmetatable({}, {__mode = "k"}),
    _entityCacheLastClean = 0,
    _entityCacheCleanInterval = 5, -- Limpar a cada 5 segundos
    
    -- ═══════════════════════════════════════════════
    -- CACHE DE ITEMS (específico para ItemESP)
    -- ═══════════════════════════════════════════════
    _itemCache = setmetatable({}, {__mode = "k"}),
    _itemPositions = setmetatable({}, {__mode = "k"}),
    
    -- ═══════════════════════════════════════════════
    -- MÉTRICAS DE PERFORMANCE
    -- ═══════════════════════════════════════════════
    _metrics = {
        updateTime = 0,
        averageUpdateTime = 0,
        totalUpdates = 0,
        cacheCleans = 0,
    },
    
    -- ═══════════════════════════════════════════════
    -- FLAGS DE ESTADO
    -- ═══════════════════════════════════════════════
    _initialized = false,
    _updateConnection = nil,
}

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

function Cache:Init()
    if self._initialized then return end
    
    -- Setup inicial
    self:Update()
    
    -- Conectar ao CharacterAdded
    if self.LocalPlayer then
        self.LocalPlayer.CharacterAdded:Connect(function(char)
            self:_onCharacterAdded(char)
        end)
        
        -- Se já tem character
        if self.LocalPlayer.Character then
            self:_onCharacterAdded(self.LocalPlayer.Character)
        end
    end
    
    self._initialized = true
end

function Cache:_onCharacterAdded(char)
    self.Character = char
    self.HumanoidRootPart = char:WaitForChild("HumanoidRootPart", 5)
    self.Humanoid = char:FindFirstChildOfClass("Humanoid")
    
    -- Limpar caches antigos
    self:_cleanDistanceCache(true)
end

-- ============================================================================
-- UPDATE PRINCIPAL (OTIMIZADO)
-- ============================================================================

function Cache:Update()
    local now = tick()
    
    -- Throttle updates
    if now - self.LastUpdate < self.UpdateInterval then 
        return false 
    end
    
    local startTime = now
    self.LastUpdate = now
    self.FrameCount = self.FrameCount + 1
    
    -- ═══════════════════════════════════════════════
    -- ATUALIZAR CÂMERA
    -- ═══════════════════════════════════════════════
    local camera = workspace.CurrentCamera
    if camera then
        self.CameraCFrame = camera.CFrame
        self.CameraPosition = camera.CFrame.Position
    end
    
    -- ═══════════════════════════════════════════════
    -- ATUALIZAR REFERÊNCIAS DO PLAYER
    -- ═══════════════════════════════════════════════
    local char = self.LocalPlayer and self.LocalPlayer.Character
    if char then
        self.Character = char
        
        -- Só atualiza se mudou ou é nil
        if not self.HumanoidRootPart or not self.HumanoidRootPart.Parent then
            self.HumanoidRootPart = char:FindFirstChild("HumanoidRootPart")
        end
        
        if not self.Humanoid or not self.Humanoid.Parent then
            self.Humanoid = char:FindFirstChildOfClass("Humanoid")
        end
    else
        self.Character = nil
        self.HumanoidRootPart = nil
        self.Humanoid = nil
    end
    
    -- ═══════════════════════════════════════════════
    -- LIMPEZA PERIÓDICA DE CACHES
    -- ═══════════════════════════════════════════════
    if now - self._entityCacheLastClean > self._entityCacheCleanInterval then
        self:_cleanDistanceCache(false)
        self:_cleanEntityCache()
        self._entityCacheLastClean = now
        self._metrics.cacheCleans = self._metrics.cacheCleans + 1
    end
    
    -- ═══════════════════════════════════════════════
    -- MÉTRICAS
    -- ═══════════════════════════════════════════════
    local updateTime = tick() - startTime
    self._metrics.updateTime = updateTime
    self._metrics.totalUpdates = self._metrics.totalUpdates + 1
    self._metrics.averageUpdateTime = (self._metrics.averageUpdateTime * 0.95) + (updateTime * 0.05)
    
    return true
end

-- ============================================================================
-- CACHE DE DISTÂNCIAS (COM TTL AUTOMÁTICO)
-- ============================================================================

function Cache:GetDistanceFromCamera(position)
    if not position then return 9999 end
    
    local now = tick()
    
    -- Criar chave única baseada na posição (arredondada para cache hits)
    local key = string.format("%.1f_%.1f_%.1f", position.X, position.Y, position.Z)
    
    local cached = self._distanceCache[key]
    if cached and (now - cached.time) < self._distanceCacheTTL then
        self._distanceCacheHits = self._distanceCacheHits + 1
        return cached.distance
    end
    
    -- Cache miss - calcular
    self._distanceCacheMisses = self._distanceCacheMisses + 1
    
    local distance = (position - self.CameraPosition).Magnitude
    
    -- Armazenar no cache
    self._distanceCache[key] = {
        distance = distance,
        time = now
    }
    
    return distance
end

-- Versão sem cache para casos específicos
function Cache:GetRawDistanceFromCamera(position)
    if not position then return 9999 end
    return (position - self.CameraPosition).Magnitude
end

-- Distância do HumanoidRootPart
function Cache:GetDistanceFromPlayer(position)
    if not position or not self.HumanoidRootPart then return 9999 end
    return (position - self.HumanoidRootPart.Position).Magnitude
end

-- ============================================================================
-- CACHE DE ENTIDADES
-- ============================================================================

function Cache:SetEntityData(entity, data)
    if not entity then return end
    
    self._entityCache[entity] = {
        data = data,
        lastUpdate = tick()
    }
end

function Cache:GetEntityData(entity)
    local cached = self._entityCache[entity]
    if cached then
        return cached.data, cached.lastUpdate
    end
    return nil, 0
end

function Cache:ClearEntityData(entity)
    if entity then
        self._entityCache[entity] = nil
    end
end

-- ============================================================================
-- CACHE DE ITENS (ESPECÍFICO PARA ItemESP)
-- ============================================================================

function Cache:SetItemData(item, data)
    if not item then return end
    
    self._itemCache[item] = {
        data = data,
        lastUpdate = tick()
    }
end

function Cache:GetItemData(item)
    local cached = self._itemCache[item]
    if cached then
        return cached.data, cached.lastUpdate
    end
    return nil, 0
end

function Cache:ClearItemData(item)
    if item then
        self._itemCache[item] = nil
        self._itemPositions[item] = nil
    end
end

-- Cache de posição de item (para otimizar updates)
function Cache:UpdateItemPosition(item, position)
    if not item or not position then return false end
    
    local lastPos = self._itemPositions[item]
    if lastPos then
        -- Só considera "movido" se mudou mais de 0.5 studs
        local delta = (position - lastPos).Magnitude
        if delta < 0.5 then
            return false -- Não mudou significativamente
        end
    end
    
    self._itemPositions[item] = position
    return true -- Mudou
end

function Cache:GetItemPosition(item)
    return self._itemPositions[item]
end

-- ============================================================================
-- CACHE DE SAÚDE
-- ============================================================================

function Cache:SetRealHealth(model, health, maxHealth)
    if not model then return end
    
    self.RealHealth[model] = {
        health = health,
        maxHealth = maxHealth or 20,
        lastUpdate = tick()
    }
end

function Cache:GetRealHealth(model)
    return self.RealHealth[model]
end

function Cache:ClearRealHealth(model)
    if model then
        self.RealHealth[model] = nil
    else
        self.RealHealth = {}
    end
end

-- ============================================================================
-- CACHE DE MINERAIS
-- ============================================================================

function Cache:SetMineralResult(part, result)
    self.MineralResults[part] = result
end

function Cache:GetMineralResult(part)
    return self.MineralResults[part]
end

function Cache:ClearMineralResults()
    self.MineralResults = setmetatable({}, {__mode = "k"})
end

-- ============================================================================
-- LIMPEZA DE CACHES
-- ============================================================================

function Cache:_cleanDistanceCache(force)
    local now = tick()
    local threshold = self._distanceCacheTTL * 2 -- Limpar entries velhas
    
    if force then
        self._distanceCache = {}
        return
    end
    
    -- Limpar entries expiradas
    local toRemove = {}
    for key, data in pairs(self._distanceCache) do
        if (now - data.time) > threshold then
            table.insert(toRemove, key)
        end
    end
    
    for _, key in ipairs(toRemove) do
        self._distanceCache[key] = nil
    end
end

function Cache:_cleanEntityCache()
    local now = tick()
    local threshold = 10 -- 10 segundos sem update
    
    -- Entities
    for entity, data in pairs(self._entityCache) do
        if not entity or not entity.Parent or (now - data.lastUpdate) > threshold then
            self._entityCache[entity] = nil
        end
    end
    
    -- Items
    for item, data in pairs(self._itemCache) do
        if not item or not item.Parent or (now - data.lastUpdate) > threshold then
            self._itemCache[item] = nil
            self._itemPositions[item] = nil
        end
    end
    
    -- Real Health
    for model, data in pairs(self.RealHealth) do
        if not model or not model.Parent or (now - data.lastUpdate) > 30 then
            self.RealHealth[model] = nil
        end
    end
end

-- ============================================================================
-- LIMPEZA TOTAL
-- ============================================================================

function Cache:ClearAll()
    self.RealHealth = {}
    self.MineralResults = setmetatable({}, {__mode = "k"})
    self._distanceCache = {}
    self._entityCache = setmetatable({}, {__mode = "k"})
    self._itemCache = setmetatable({}, {__mode = "k"})
    self._itemPositions = setmetatable({}, {__mode = "k"})
    self._distanceCacheHits = 0
    self._distanceCacheMisses = 0
end

-- ============================================================================
-- MÉTRICAS E DEBUG
-- ============================================================================

function Cache:GetMetrics()
    local hitRate = 0
    local totalRequests = self._distanceCacheHits + self._distanceCacheMisses
    if totalRequests > 0 then
        hitRate = (self._distanceCacheHits / totalRequests) * 100
    end
    
    return {
        updateTime = string.format("%.4fms", self._metrics.updateTime * 1000),
        averageUpdateTime = string.format("%.4fms", self._metrics.averageUpdateTime * 1000),
        totalUpdates = self._metrics.totalUpdates,
        cacheCleans = self._metrics.cacheCleans,
        distanceCacheHits = self._distanceCacheHits,
        distanceCacheMisses = self._distanceCacheMisses,
        distanceCacheHitRate = string.format("%.1f%%", hitRate),
        frameCount = self.FrameCount,
    }
end

function Cache:GetCacheSizes()
    local distCount = 0
    for _ in pairs(self._distanceCache) do distCount = distCount + 1 end
    
    local entityCount = 0
    for _ in pairs(self._entityCache) do entityCount = entityCount + 1 end
    
    local itemCount = 0
    for _ in pairs(self._itemCache) do itemCount = itemCount + 1 end
    
    local healthCount = 0
    for _ in pairs(self.RealHealth) do healthCount = healthCount + 1 end
    
    return {
        distanceCache = distCount,
        entityCache = entityCount,
        itemCache = itemCount,
        healthCache = healthCount,
    }
end

-- ============================================================================
-- Hitbox Cache Integration
-- ============================================================================

-- Cache de Hitbox (usa Helpers internamente)
function Cache:GetHitbox(obj)
    if not obj then return nil end
    
    -- Verificar cache interno primeiro
    local cached = self._hitboxCache and self._hitboxCache[obj]
    if cached and cached.hitbox and cached.hitbox.Parent then
        -- Verificar TTL
        if (tick() - cached.time) < 5 then
            return cached.hitbox
        end
    end
    
    -- Calcular usando Helpers
    local Helpers = _G.MineHub and _G.MineHub.Helpers
    if not Helpers then
        -- Fallback básico
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        end
        return nil
    end
    
    local hitbox = Helpers.GetHitbox(obj)
    
    -- Cachear
    self._hitboxCache = self._hitboxCache or setmetatable({}, {__mode = "k"})
    self._hitboxCache[obj] = {
        hitbox = hitbox,
        time = tick()
    }
    
    return hitbox
end

-- ============================================================================
-- ENTITY DATA CACHE
-- ============================================================================

Cache.EntityData = {}

function Cache:SetEntityData(model, data)
    if not model then return end
    
    self.EntityData[model] = {
        data = data,
        lastUpdate = tick()
    }
end

function Cache:GetEntityData(model)
    local cached = self.EntityData[model]
    if cached then
        return cached.data, cached.lastUpdate
    end
    return nil, 0
end

function Cache:ClearEntityData(model)
    if model then
        self.EntityData[model] = nil
    else
        self.EntityData = {}
    end
end

-- Cache de Entity Type
function Cache:GetEntityType(obj)
    if not obj then return "Unknown" end
    
    local Helpers = _G.MineHub and _G.MineHub.Helpers
    if Helpers then
        return Helpers.GetEntityType(obj)
    end
    
    return "Unknown"
end

-- ============================================================================
-- UTILITÁRIOS
-- ============================================================================

-- Verificar se objeto é válido
function Cache:IsValid(obj)
    return obj and typeof(obj) == "Instance" and obj.Parent ~= nil
end

-- Obter posição segura de um objeto
function Cache:GetPosition(obj)
    if not self:IsValid(obj) then return nil end
    
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local primary = obj.PrimaryPart
        if primary then
            return primary.Position
        end
        
        local part = obj:FindFirstChildWhichIsA("BasePart")
        if part then
            return part.Position
        end
    end
    
    return nil
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Cache = Cache

return Cache