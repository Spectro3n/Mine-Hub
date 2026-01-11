-- ============================================================================
-- CONNECTION MANAGER v2.0 - Otimizado com Métricas e Auto-Cleanup
-- ============================================================================

local RunService = game:GetService("RunService")

local ConnectionManager = {
    -- ═══════════════════════════════════════════════
    -- STORAGE PRINCIPAL
    -- ═══════════════════════════════════════════════
    _connections = {},
    _categories = {},
    
    -- ═══════════════════════════════════════════════
    -- METADATA DAS CONEXÕES
    -- ═══════════════════════════════════════════════
    _metadata = {},  -- name -> {createdAt, category, isActive, callCount}
    
    -- ═══════════════════════════════════════════════
    -- CONEXÕES PAUSADAS (backup)
    -- ═══════════════════════════════════════════════
    _paused = {},           -- name -> original callback
    _pausedCategories = {}, -- category -> true
    
    -- ═══════════════════════════════════════════════
    -- MÉTRICAS
    -- ═══════════════════════════════════════════════
    _metrics = {
        totalCreated = 0,
        totalRemoved = 0,
        totalReconnected = 0,
        autoCleanups = 0,
        lastCleanupTime = 0,
    },
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO
    -- ═══════════════════════════════════════════════
    _config = {
        autoCleanup = true,
        cleanupInterval = 30,      -- Segundos entre limpezas automáticas
        debugMode = false,         -- Log de operações
        trackCallCount = false,    -- Rastrear número de chamadas (tem overhead)
    },
    
    -- ═══════════════════════════════════════════════
    -- ESTADO
    -- ═══════════════════════════════════════════════
    _initialized = false,
    _cleanupConnection = nil,
}

-- ============================================================================
-- FUNÇÕES INTERNAS (HELPERS)
-- ============================================================================

local function debugLog(...)
    if ConnectionManager._config.debugMode then
        print("[ConnectionManager]", ...)
    end
end

local function isConnectionValid(connection)
    if not connection then return false end
    if typeof(connection) ~= "RBXScriptConnection" then return false end
    
    -- Verificar se ainda está conectada
    local success, connected = pcall(function()
        return connection.Connected
    end)
    
    return success and connected
end

local function safeDisconnect(connection)
    if not connection then return false end
    
    local success = pcall(function()
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end)
    
    return success
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

function ConnectionManager:Init()
    if self._initialized then return end
    
    -- Setup auto-cleanup se habilitado
    if self._config.autoCleanup then
        self:_startAutoCleanup()
    end
    
    self._initialized = true
    debugLog("Initialized")
end

function ConnectionManager:_startAutoCleanup()
    if self._cleanupConnection then return end
    
    local lastCleanup = tick()
    
    self._cleanupConnection = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastCleanup >= self._config.cleanupInterval then
            lastCleanup = now
            self:_performAutoCleanup()
        end
    end)
end

function ConnectionManager:_stopAutoCleanup()
    if self._cleanupConnection then
        pcall(function()
            self._cleanupConnection:Disconnect()
        end)
        self._cleanupConnection = nil
    end
end

function ConnectionManager:_performAutoCleanup()
    local cleaned = 0
    local toRemove = {}
    
    for name, connection in pairs(self._connections) do
        if not isConnectionValid(connection) then
            table.insert(toRemove, name)
        end
    end
    
    for _, name in ipairs(toRemove) do
        self:Remove(name)
        cleaned = cleaned + 1
    end
    
    if cleaned > 0 then
        self._metrics.autoCleanups = self._metrics.autoCleanups + cleaned
        self._metrics.lastCleanupTime = tick()
        debugLog("Auto-cleaned", cleaned, "dead connections")
    end
end

-- ============================================================================
-- FUNÇÕES PRINCIPAIS (NOMES MANTIDOS)
-- ============================================================================

function ConnectionManager:Add(name, connection, category)
    category = category or "general"
    
    -- Validar conexão
    if not connection then
        debugLog("Warning: Attempted to add nil connection:", name)
        return false
    end
    
    -- Verificar se é uma conexão válida
    if typeof(connection) ~= "RBXScriptConnection" then
        debugLog("Warning: Invalid connection type for:", name, typeof(connection))
        return false
    end
    
    -- Se já existe, desconectar a antiga
    if self._connections[name] then
        safeDisconnect(self._connections[name])
        self._metrics.totalReconnected = self._metrics.totalReconnected + 1
        debugLog("Reconnected:", name)
    else
        self._metrics.totalCreated = self._metrics.totalCreated + 1
        debugLog("Added:", name, "in category:", category)
    end
    
    -- Armazenar conexão
    self._connections[name] = connection
    
    -- Armazenar categoria
    if not self._categories[category] then
        self._categories[category] = {}
    end
    self._categories[category][name] = true
    
    -- Metadata
    self._metadata[name] = {
        createdAt = tick(),
        category = category,
        isActive = true,
        callCount = 0,
    }
    
    -- Verificar se categoria está pausada
    if self._pausedCategories[category] then
        self:PauseConnection(name)
    end
    
    return true
end

function ConnectionManager:Remove(name)
    local connection = self._connections[name]
    
    if connection then
        safeDisconnect(connection)
        self._connections[name] = nil
        self._metrics.totalRemoved = self._metrics.totalRemoved + 1
        debugLog("Removed:", name)
    end
    
    -- Remover da categoria
    local metadata = self._metadata[name]
    if metadata and self._categories[metadata.category] then
        self._categories[metadata.category][name] = nil
    end
    
    -- Limpar metadata
    self._metadata[name] = nil
    
    -- Limpar paused se existir
    self._paused[name] = nil
end

function ConnectionManager:RemoveCategory(category)
    if not self._categories[category] then return 0 end
    
    local removed = 0
    local toRemove = {}
    
    -- Coletar nomes primeiro (evitar modificar durante iteração)
    for name in pairs(self._categories[category]) do
        table.insert(toRemove, name)
    end
    
    -- Remover
    for _, name in ipairs(toRemove) do
        if self._connections[name] then
            safeDisconnect(self._connections[name])
            self._connections[name] = nil
            self._metadata[name] = nil
            self._paused[name] = nil
            removed = removed + 1
        end
    end
    
    self._categories[category] = {}
    self._pausedCategories[category] = nil
    self._metrics.totalRemoved = self._metrics.totalRemoved + removed
    
    debugLog("Removed category:", category, "(" .. removed .. " connections)")
    
    return removed
end

function ConnectionManager:RemoveAll()
    local count = 0
    
    for name, conn in pairs(self._connections) do
        safeDisconnect(conn)
        count = count + 1
    end
    
    -- Parar auto-cleanup
    self:_stopAutoCleanup()
    
    -- Limpar tudo
    self._connections = {}
    self._categories = {}
    self._metadata = {}
    self._paused = {}
    self._pausedCategories = {}
    
    self._metrics.totalRemoved = self._metrics.totalRemoved + count
    
    debugLog("Removed all:", count, "connections")
    
    -- Reiniciar auto-cleanup se configurado
    if self._config.autoCleanup then
        self:_startAutoCleanup()
    end
    
    return count
end

function ConnectionManager:Has(name)
    return self._connections[name] ~= nil
end

function ConnectionManager:GetCount()
    local count = 0
    for _ in pairs(self._connections) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- FUNÇÕES ADICIONAIS (NOVAS)
-- ============================================================================

-- Verificar se conexão está ativa (não pausada e conectada)
function ConnectionManager:IsActive(name)
    local connection = self._connections[name]
    if not connection then return false end
    
    local metadata = self._metadata[name]
    if metadata and not metadata.isActive then return false end
    
    return isConnectionValid(connection)
end

-- Pausar uma conexão específica
function ConnectionManager:PauseConnection(name)
    local connection = self._connections[name]
    if not connection or self._paused[name] then return false end
    
    -- Não podemos realmente pausar RBXScriptConnection
    -- Mas podemos desconectar e marcar como pausada
    safeDisconnect(connection)
    self._paused[name] = true
    
    local metadata = self._metadata[name]
    if metadata then
        metadata.isActive = false
    end
    
    debugLog("Paused:", name)
    return true
end

-- Pausar categoria inteira
function ConnectionManager:PauseCategory(category)
    if not self._categories[category] then return 0 end
    
    self._pausedCategories[category] = true
    local paused = 0
    
    for name in pairs(self._categories[category]) do
        if self:PauseConnection(name) then
            paused = paused + 1
        end
    end
    
    debugLog("Paused category:", category, "(" .. paused .. " connections)")
    return paused
end

-- Obter contagem por categoria
function ConnectionManager:GetCategoryCount(category)
    if not self._categories[category] then return 0 end
    
    local count = 0
    for name in pairs(self._categories[category]) do
        if self._connections[name] then
            count = count + 1
        end
    end
    return count
end

-- Listar todas as categorias
function ConnectionManager:GetCategories()
    local categories = {}
    for category in pairs(self._categories) do
        table.insert(categories, category)
    end
    return categories
end

-- Obter nomes de conexões em uma categoria
function ConnectionManager:GetConnectionsInCategory(category)
    if not self._categories[category] then return {} end
    
    local connections = {}
    for name in pairs(self._categories[category]) do
        if self._connections[name] then
            table.insert(connections, name)
        end
    end
    return connections
end

-- Verificar saúde das conexões
function ConnectionManager:GetHealthReport()
    local total = 0
    local active = 0
    local dead = 0
    local paused = 0
    
    for name, connection in pairs(self._connections) do
        total = total + 1
        
        if self._paused[name] then
            paused = paused + 1
        elseif isConnectionValid(connection) then
            active = active + 1
        else
            dead = dead + 1
        end
    end
    
    return {
        total = total,
        active = active,
        dead = dead,
        paused = paused,
        healthPercent = total > 0 and math.floor((active / total) * 100) or 100,
    }
end

-- Obter métricas
function ConnectionManager:GetMetrics()
    local health = self:GetHealthReport()
    
    return {
        -- Contagens
        currentCount = self:GetCount(),
        activeCount = health.active,
        deadCount = health.dead,
        pausedCount = health.paused,
        categoryCount = #self:GetCategories(),
        
        -- Histórico
        totalCreated = self._metrics.totalCreated,
        totalRemoved = self._metrics.totalRemoved,
        totalReconnected = self._metrics.totalReconnected,
        autoCleanups = self._metrics.autoCleanups,
        
        -- Saúde
        healthPercent = health.healthPercent .. "%",
        
        -- Tempo
        lastCleanupTime = self._metrics.lastCleanupTime > 0 
            and string.format("%.1fs ago", tick() - self._metrics.lastCleanupTime)
            or "never",
    }
end

-- Obter detalhes de uma conexão
function ConnectionManager:GetConnectionInfo(name)
    if not self._connections[name] then return nil end
    
    local metadata = self._metadata[name] or {}
    local connection = self._connections[name]
    
    return {
        name = name,
        category = metadata.category or "unknown",
        isActive = metadata.isActive ~= false,
        isPaused = self._paused[name] == true,
        isConnected = isConnectionValid(connection),
        createdAt = metadata.createdAt or 0,
        age = metadata.createdAt and (tick() - metadata.createdAt) or 0,
    }
end

-- Listar todas as conexões com info
function ConnectionManager:GetAllConnectionsInfo()
    local result = {}
    
    for name in pairs(self._connections) do
        result[name] = self:GetConnectionInfo(name)
    end
    
    return result
end

-- Forçar limpeza manual
function ConnectionManager:ForceCleanup()
    self:_performAutoCleanup()
end

-- Configurar
function ConnectionManager:Configure(options)
    if options.autoCleanup ~= nil then
        self._config.autoCleanup = options.autoCleanup
        if options.autoCleanup then
            self:_startAutoCleanup()
        else
            self:_stopAutoCleanup()
        end
    end
    
    if options.cleanupInterval then
        self._config.cleanupInterval = options.cleanupInterval
    end
    
    if options.debugMode ~= nil then
        self._config.debugMode = options.debugMode
    end
end

-- Batch add (adicionar múltiplas de uma vez)
function ConnectionManager:AddBatch(connections, category)
    category = category or "general"
    local added = 0
    
    for name, connection in pairs(connections) do
        if self:Add(name, connection, category) then
            added = added + 1
        end
    end
    
    return added
end

-- Batch remove
function ConnectionManager:RemoveBatch(names)
    local removed = 0
    
    for _, name in ipairs(names) do
        if self._connections[name] then
            self:Remove(name)
            removed = removed + 1
        end
    end
    
    return removed
end

-- Obter conexões por padrão de nome
function ConnectionManager:GetByPattern(pattern)
    local matches = {}
    
    for name in pairs(self._connections) do
        if string.match(name, pattern) then
            table.insert(matches, name)
        end
    end
    
    return matches
end

-- Remover por padrão
function ConnectionManager:RemoveByPattern(pattern)
    local matches = self:GetByPattern(pattern)
    return self:RemoveBatch(matches)
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.ConnectionManager = ConnectionManager

return ConnectionManager