-- ============================================================================
-- ITEM ESP v2.0 - Otimizado com loop único e heurística por níveis
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")

local ItemESP = {
    -- Cache principal: obj -> ESPData
    _cache = {},
    
    -- Referências importantes
    _entitiesFolder = nil,
    _espFolder = nil,           -- Folder dedicado para ESPs no PlayerGui
    _highlightFolder = nil,     -- Folder dedicado para Highlights no workspace
    
    -- Estado
    _initialized = false,
    _updateLoopRunning = false,
    
    -- Métricas
    _metrics = {
        totalCreated = 0,
        totalRemoved = 0,
        itemsIgnored = 0,
        lastUpdateTime = 0,
        averageUpdateTime = 0,
        updateCount = 0,
    },
}

local player = Players.LocalPlayer

-- ============================================================================
-- CONSTANTES DE CONFIANÇA
-- ============================================================================

local CONFIDENCE = {
    HIGH = 3,    -- Certeza que é item
    MEDIUM = 2,  -- Provavelmente item
    LOW = 1,     -- Talvez seja item
    NONE = 0,    -- Não é item
}

-- ============================================================================
-- HEURÍSTICA DE DETECÇÃO POR NÍVEIS
-- ============================================================================

local function getItemConfidence(obj)
    if not obj then return CONFIDENCE.NONE end
    
    local name = obj.Name
    local nameLower = string.lower(name)
    
    -- ═══════════════════════════════════════════════
    -- 🟢 ALTA CONFIANÇA (sempre é item)
    -- ═══════════════════════════════════════════════
    
    -- Nome numérico + está em Entities = certeza absoluta
    if tonumber(name) then
        return CONFIDENCE.HIGH
    end
    
    -- ═══════════════════════════════════════════════
    -- 🟡 MÉDIA CONFIANÇA (provavelmente item)
    -- ═══════════════════════════════════════════════
    
    -- Contém "item", "drop", "loot"
    if string.find(nameLower, "item") or 
       string.find(nameLower, "drop") or 
       string.find(nameLower, "loot") then
        return CONFIDENCE.MEDIUM
    end
    
    -- Model sem Humanoid
    if obj:IsA("Model") then
        local hasHumanoid = obj:FindFirstChildOfClass("Humanoid")
        if not hasHumanoid then
            -- Verificar se é pequeno (itens geralmente são pequenos)
            local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                local size = primaryPart.Size.Magnitude
                if size < 10 then -- Pequeno = provavelmente item
                    return CONFIDENCE.MEDIUM
                end
            end
        end
    end
    
    -- BasePart contendo "part" no nome
    if obj:IsA("BasePart") and string.find(nameLower, "part") then
        return CONFIDENCE.MEDIUM
    end
    
    -- ═══════════════════════════════════════════════
    -- 🔴 BAIXA CONFIANÇA (talvez seja item)
    -- ═══════════════════════════════════════════════
    
    -- Model grande ou com muitas partes
    if obj:IsA("Model") then
        local partCount = 0
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("BasePart") then
                partCount = partCount + 1
            end
        end
        
        -- Muitas partes = provavelmente estrutura, não item
        if partCount > 20 then
            return CONFIDENCE.NONE
        elseif partCount > 5 then
            return CONFIDENCE.LOW
        end
    end
    
    -- BasePart solta
    if obj:IsA("BasePart") then
        return CONFIDENCE.LOW
    end
    
    return CONFIDENCE.NONE
end

local function isItem(obj)
    return getItemConfidence(obj) >= CONFIDENCE.MEDIUM
end

local function isDefinitelyItem(obj)
    return getItemConfidence(obj) >= CONFIDENCE.HIGH
end

-- ============================================================================
-- OBTER PARTE PARA ADORNEE
-- ============================================================================

local function getAdorneePart(obj)
    if not obj or not obj.Parent then return nil end
    
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

-- ============================================================================
-- OBTER NOME DO ITEM (CACHED - SÓ CALCULA UMA VEZ)
-- ============================================================================

local function getItemDisplayName(obj)
    local name = obj.Name
    
    if tonumber(name) then
        -- Procurar nome descritivo dentro do model
        if obj:IsA("Model") then
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("BasePart") and not tonumber(child.Name) then
                    local childName = child.Name
                    if childName ~= "Part" and childName ~= "Handle" then
                        return childName
                    end
                end
            end
        end
        return "Item #" .. name
    end
    
    -- Limpar nome
    name = string.gsub(name, "Part", "")
    name = string.gsub(name, "Model", "")
    name = string.gsub(name, "_", " ")
    
    if #name == 0 then
        return "Item"
    end
    
    return name
end

-- ============================================================================
-- SETUP DOS FOLDERS DEDICADOS
-- ============================================================================

function ItemESP:SetupFolders()
    -- Folder para Billboards no PlayerGui
    local playerGui = player:WaitForChild("PlayerGui")
    
    self._espFolder = playerGui:FindFirstChild("_ItemESP")
    if not self._espFolder then
        self._espFolder = Instance.new("Folder")
        self._espFolder.Name = "_ItemESP"
        self._espFolder.Parent = playerGui
    end
    
    -- Folder para Highlights no workspace
    self._highlightFolder = workspace:FindFirstChild("_ESPHighlights")
    if not self._highlightFolder then
        self._highlightFolder = Instance.new("Folder")
        self._highlightFolder.Name = "_ESPHighlights"
        self._highlightFolder.Parent = workspace
    end
end

-- ============================================================================
-- LIDAR COM RESPAWN DO PLAYER
-- ============================================================================

function ItemESP:SetupRespawnHandler()
    ConnectionManager:Add("itemESP_respawn", player.CharacterAdded:Connect(function()
        task.wait(0.5)
        -- Recriar folder de ESP
        self:SetupFolders()
        -- Reparentar todos os billboards existentes
        for obj, data in pairs(self._cache) do
            if data.billboard and data.billboard.Parent then
                data.billboard.Parent = self._espFolder
            end
        end
    end), "itemESP")
end

-- ============================================================================
-- CRIAR ESP PARA UM OBJETO
-- ============================================================================

function ItemESP:Create(obj)
    if not Config.ItemESP then return end
    if self._cache[obj] then return end
    
    local confidence = getItemConfidence(obj)
    if confidence < CONFIDENCE.MEDIUM then
        self._metrics.itemsIgnored = self._metrics.itemsIgnored + 1
        return
    end
    
    local part = getAdorneePart(obj)
    if not part then return end
    
    -- Nome é calculado UMA VEZ e cacheado
    local displayName = getItemDisplayName(obj)
    
    -- ═══════════════════════════════════════════════
    -- HIGHLIGHT (no folder dedicado)
    -- ═══════════════════════════════════════════════
    local targetForHighlight = obj:IsA("Model") and obj or obj
    
    local hl = Instance.new("Highlight")
    hl.Name = "ItemHL_" .. tostring(obj:GetDebugId())
    hl.FillColor = Constants.COLORS.ITEM
    hl.OutlineColor = Constants.COLORS.ITEM_OUTLINE
    hl.FillTransparency = confidence == CONFIDENCE.HIGH and 0.5 or 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = targetForHighlight
    hl.Parent = self._highlightFolder
    
    -- ═══════════════════════════════════════════════
    -- BILLBOARD (no folder dedicado do PlayerGui)
    -- ═══════════════════════════════════════════════
    local bb = Instance.new("BillboardGui")
    bb.Name = "ItemBB_" .. tostring(obj:GetDebugId())
    bb.Adornee = part
    bb.Size = UDim2.fromOffset(140, 45)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = self._espFolder
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Constants.COLORS.ITEM_OUTLINE
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "📦 " .. displayName
    label.TextColor3 = Constants.COLORS.ITEM
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    -- ═══════════════════════════════════════════════
    -- ARMAZENAR NO CACHE
    -- ═══════════════════════════════════════════════
    self._cache[obj] = {
        billboard = bb,
        highlight = hl,
        label = label,
        displayName = displayName,  -- CACHEADO, nunca recalcula
        confidence = confidence,
        part = part,
        createdAt = tick(),
    }
    
    self._metrics.totalCreated = self._metrics.totalCreated + 1
end

-- ============================================================================
-- REMOVER ESP
-- ============================================================================

function ItemESP:Remove(obj)
    local data = self._cache[obj]
    if not data then return end
    
    -- Destruir objetos de forma segura
    Helpers.SafeDestroy(data.billboard)
    Helpers.SafeDestroy(data.highlight)
    
    self._cache[obj] = nil
    self._metrics.totalRemoved = self._metrics.totalRemoved + 1
end

-- ============================================================================
-- LOOP DE UPDATE ÚNICO (UM HEARTBEAT PARA TODOS)
-- ============================================================================

function ItemESP:StartUpdateLoop()
    if self._updateLoopRunning then return end
    self._updateLoopRunning = true
    
    ConnectionManager:Add("itemESP_updateLoop", RunService.Heartbeat:Connect(function()
        if not Config.ItemESP then return end
        
        local startTime = tick()
        local itemsUpdated = 0
        
        -- Iterar sobre todos os itens de uma vez
        for obj, data in pairs(self._cache) do
            -- ═══════════════════════════════════════════════
            -- VALIDAÇÃO DE EXISTÊNCIA
            -- ═══════════════════════════════════════════════
            if not obj or not obj.Parent then
                self:Remove(obj)
                continue
            end
            
            -- ═══════════════════════════════════════════════
            -- ATUALIZAR ADORNEE SE NECESSÁRIO
            -- ═══════════════════════════════════════════════
            local currentPart = getAdorneePart(obj)
            if not currentPart then
                self:Remove(obj)
                continue
            end
            
            if data.part ~= currentPart then
                data.part = currentPart
                if data.billboard then
                    data.billboard.Adornee = currentPart
                end
            end
            
            -- ═══════════════════════════════════════════════
            -- ATUALIZAR DISTÂNCIA (USA CACHE GLOBAL)
            -- ═══════════════════════════════════════════════
            local dist = Cache:GetDistanceFromCamera(currentPart.Position)
            
            -- Só atualiza texto se o billboard existe
            if data.label then
                data.label.Text = string.format("📦 %s\n%.0fm", data.displayName, dist)
            end
            
            itemsUpdated = itemsUpdated + 1
        end
        
        -- Métricas
        local updateTime = tick() - startTime
        self._metrics.lastUpdateTime = updateTime
        self._metrics.updateCount = self._metrics.updateCount + 1
        
        -- Média móvel
        self._metrics.averageUpdateTime = (self._metrics.averageUpdateTime * 0.9) + (updateTime * 0.1)
        
    end), "itemESP")
end

function ItemESP:StopUpdateLoop()
    ConnectionManager:Remove("itemESP_updateLoop")
    self._updateLoopRunning = false
end

-- ============================================================================
-- PROCESSAR OBJETO
-- ============================================================================

function ItemESP:ProcessObject(obj)
    if not Config.ItemESP then return end
    
    self:Create(obj)
    
    -- Se for Model, verificar filhos também
    if obj:IsA("Model") then
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("BasePart") and isItem(child) then
                self:Create(child)
            end
        end
    end
end

-- ============================================================================
-- SCAN INICIAL
-- ============================================================================

function ItemESP:ScanEntities()
    if not self._entitiesFolder then return end
    
    local count = 0
    for _, obj in ipairs(self._entitiesFolder:GetChildren()) do
        self:ProcessObject(obj)
        count = count + 1
        
        -- Yield a cada 50 objetos para não travar
        if count % 50 == 0 then
            task.wait()
        end
    end
end

-- ============================================================================
-- SETUP CONEXÕES DA PASTA ENTITIES
-- ============================================================================

function ItemESP:SetupEntityConnections()
    if not self._entitiesFolder then return end
    
    -- Novo objeto
    ConnectionManager:Add("itemESP_childAdded", self._entitiesFolder.ChildAdded:Connect(function(obj)
        if not Config.ItemESP then return end
        task.defer(function()
            self:ProcessObject(obj)
        end)
    end), "itemESP")
    
    -- Objeto removido
    ConnectionManager:Add("itemESP_childRemoved", self._entitiesFolder.ChildRemoved:Connect(function(obj)
        self:Remove(obj)
        
        -- Remover filhos se era Model
        if obj:IsA("Model") then
            for _, child in ipairs(obj:GetChildren()) do
                self:Remove(child)
            end
        end
    end), "itemESP")
    
    -- Descendant adicionado
    ConnectionManager:Add("itemESP_descAdded", self._entitiesFolder.DescendantAdded:Connect(function(obj)
        if not Config.ItemESP then return end
        if obj:IsA("BasePart") and isItem(obj) then
            task.defer(function()
                self:Create(obj)
            end)
        end
    end), "itemESP")
    
    -- Descendant removido
    ConnectionManager:Add("itemESP_descRemoved", self._entitiesFolder.DescendantRemoved:Connect(function(obj)
        self:Remove(obj)
    end), "itemESP")
end

-- ============================================================================
-- INICIALIZAÇÃO PRINCIPAL
-- ============================================================================

function ItemESP:Init()
    if self._initialized then return end
    
    print("📦 ItemESP: Inicializando...")
    
    -- Setup folders
    self:SetupFolders()
    
    -- Setup respawn handler
    self:SetupRespawnHandler()
    
    -- Buscar pasta Entities
    self._entitiesFolder = workspace:FindFirstChild("Entities")
    
    if self._entitiesFolder then
        self:SetupEntityConnections()
        self:ScanEntities()
    else
        -- Esperar pela pasta
        task.spawn(function()
            self._entitiesFolder = workspace:WaitForChild("Entities", 60)
            if self._entitiesFolder then
                self:SetupEntityConnections()
                self:ScanEntities()
            else
                warn("📦 ItemESP: Pasta Entities não encontrada!")
            end
        end)
    end
    
    -- Iniciar loop de update
    self:StartUpdateLoop()
    
    self._initialized = true
    print("✅ ItemESP: Inicializado!")
end

-- ============================================================================
-- ENABLE / DISABLE / TOGGLE
-- ============================================================================

function ItemESP:Enable()
    if not self._initialized then
        self:Init()
    else
        self:StartUpdateLoop()
        self:ScanEntities()
    end
end

function ItemESP:Disable()
    self:StopUpdateLoop()
    self:ClearAll()
end

function ItemESP:Toggle(state)
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

-- ============================================================================
-- LIMPEZA
-- ============================================================================

function ItemESP:ClearAll()
    local objects = {}
    for obj in pairs(self._cache) do
        table.insert(objects, obj)
    end
    
    for _, obj in ipairs(objects) do
        self:Remove(obj)
    end
end

function ItemESP:Refresh()
    self:ClearAll()
    if Config.ItemESP then
        self:ScanEntities()
    end
end

-- ============================================================================
-- MÉTRICAS E DEBUG
-- ============================================================================

function ItemESP:GetCount()
    local count = 0
    for _ in pairs(self._cache) do
        count = count + 1
    end
    return count
end

function ItemESP:GetMetrics()
    return {
        currentCount = self:GetCount(),
        totalCreated = self._metrics.totalCreated,
        totalRemoved = self._metrics.totalRemoved,
        itemsIgnored = self._metrics.itemsIgnored,
        lastUpdateTime = string.format("%.4fms", self._metrics.lastUpdateTime * 1000),
        averageUpdateTime = string.format("%.4fms", self._metrics.averageUpdateTime * 1000),
        updateCount = self._metrics.updateCount,
        updateLoopRunning = self._updateLoopRunning,
    }
end

function ItemESP:IsTracking(obj)
    return self._cache[obj] ~= nil
end

function ItemESP:GetItemConfidence(obj)
    return getItemConfidence(obj)
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.ItemESP = ItemESP

return ItemESP