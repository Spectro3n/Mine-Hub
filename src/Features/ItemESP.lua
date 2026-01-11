-- ============================================================================
-- ITEM ESP v3.0 - Detecção Correta com Filtro Negativo
-- ============================================================================
-- ✅ Regra de OURO: Detectar o que NÃO é (player, mob, mapa) primeiro
-- ✅ Item = MODEL, não BasePart solta
-- ✅ Billboard = no Model, Adornee = PrimaryPart
-- ✅ Nunca aceitar BasePart solta fora de contexto
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")

local ItemESP = {
    -- ═══════════════════════════════════════════════
    -- CACHE PRINCIPAL
    -- ═══════════════════════════════════════════════
    _cache = {},                -- obj -> ESPData
    _blacklist = {},            -- obj -> true (objetos rejeitados)
    
    -- ═══════════════════════════════════════════════
    -- REFERÊNCIAS
    -- ═══════════════════════════════════════════════
    _entitiesFolder = nil,
    _espFolder = nil,
    _highlightFolder = nil,
    
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
        itemsIgnored = 0,
        playersIgnored = 0,
        mobsIgnored = 0,
        partsIgnored = 0,
        lastUpdateTime = 0,
        averageUpdateTime = 0,
        updateCount = 0,
    },
}

local player = Players.LocalPlayer

-- ============================================================================
-- NÍVEIS DE CONFIANÇA
-- ============================================================================

local CONFIDENCE = {
    ABSOLUTE = 4,   -- Certeza absoluta (Attribute, nome conhecido)
    HIGH = 3,       -- Alta confiança (Model numérico em Entities)
    MEDIUM = 2,     -- Média confiança (heurística passou)
    LOW = 1,        -- Baixa confiança (NÃO USAR para criar ESP)
    NONE = 0,       -- Não é item (player, mob, estrutura)
}

-- ============================================================================
-- NOMES DE ITEMS CONHECIDOS (WHITELIST)
-- ============================================================================

local KNOWN_ITEM_PATTERNS = {
    -- Minérios/Recursos
    "ore", "coal", "iron", "gold", "diamond", "emerald", "ruby", "sapphire",
    "copper", "tin", "silver", "platinum", "titanium", "uranium",
    
    -- Materiais
    "wood", "stone", "brick", "plank", "ingot", "bar", "nugget",
    "leather", "cloth", "fiber", "string", "wool",
    
    -- Drops comuns
    "drop", "loot", "item", "pickup", "collectible",
    "meat", "bone", "feather", "hide", "pelt", "scale",
    
    -- Ferramentas/Armas
    "sword", "axe", "pickaxe", "shovel", "hoe", "hammer",
    "bow", "arrow", "spear", "shield", "helmet", "armor",
    
    -- Consumíveis
    "food", "potion", "apple", "bread", "fish", "berry",
    "health", "mana", "stamina", "buff",
    
    -- Containers
    "chest", "bag", "crate", "barrel", "box", "package",
}

-- Compilar patterns para performance
local KNOWN_ITEM_PATTERNS_LOWER = {}
for _, pattern in ipairs(KNOWN_ITEM_PATTERNS) do
    table.insert(KNOWN_ITEM_PATTERNS_LOWER, string.lower(pattern))
end

-- ============================================================================
-- DETECÇÃO PRINCIPAL (FILTRO NEGATIVO PRIMEIRO)
-- ============================================================================

local function getItemConfidence(obj)
    if not obj then return CONFIDENCE.NONE end
    if not obj.Parent then return CONFIDENCE.NONE end
    
    -- ═══════════════════════════════════════════════
    -- 🔴 FASE 1: FILTRO NEGATIVO (O QUE NÃO É ITEM)
    -- ═══════════════════════════════════════════════
    
    -- ❌ NUNCA aceitar se for BasePart SOLTA (sem parent Model válido)
    if obj:IsA("BasePart") and not obj:IsA("MeshPart") then
        local parent = obj.Parent
        
        -- Se parent não é Model, REJECT
        if not parent or not parent:IsA("Model") then
            return CONFIDENCE.NONE
        end
        
        -- Se parent é Workspace direto, REJECT (parte do mapa)
        if parent == workspace then
            return CONFIDENCE.NONE
        end
        
        -- Se parent tem Humanoid, REJECT (parte de mob/player)
        if parent:FindFirstChildOfClass("Humanoid") then
            return CONFIDENCE.NONE
        end
    end
    
    -- ❌ Se for Model, verificar se é Player ou Mob
    if obj:IsA("Model") then
        -- Verificar se é Player
        if Players:GetPlayerFromCharacter(obj) then
            return CONFIDENCE.NONE
        end
        
        -- Verificar se tem Humanoid (mob/npc)
        if obj:FindFirstChildOfClass("Humanoid") then
            return CONFIDENCE.NONE
        end
        
        -- Verificar se tem Hitbox típico de mob
        local hitbox = obj:FindFirstChild("Hitbox")
        if hitbox and hitbox:IsA("BasePart") then
            -- Se hitbox é grande, provavelmente é mob
            if hitbox.Size.Magnitude > 5 then
                return CONFIDENCE.NONE
            end
        end
        
        -- Verificar se tem animações (mobs geralmente têm)
        if obj:FindFirstChildOfClass("AnimationController") or
           obj:FindFirstChild("Animate") or
           obj:FindFirstChildOfClass("Animator", true) then
            return CONFIDENCE.NONE
        end
    end
    
    -- ❌ Verificar se está fora da pasta Entities
    local isInEntities = false
    local current = obj
    while current and current ~= workspace do
        if current.Name == "Entities" then
            isInEntities = true
            break
        end
        current = current.Parent
    end
    
    if not isInEntities then
        return CONFIDENCE.NONE
    end
    
    -- ═══════════════════════════════════════════════
    -- 🟢 FASE 2: DETECÇÃO POSITIVA (O QUE É ITEM)
    -- ═══════════════════════════════════════════════
    
    local name = obj.Name
    local nameLower = string.lower(name)
    
    -- ✅ ABSOLUTO: Attribute de item
    if obj:GetAttribute("IsItem") == true or
       obj:GetAttribute("ItemId") ~= nil or
       obj:GetAttribute("ItemType") ~= nil or
       obj:GetAttribute("Droppable") == true then
        return CONFIDENCE.ABSOLUTE
    end
    
    -- ✅ ALTO: Model com nome numérico (ID de item)
    if obj:IsA("Model") and tonumber(name) then
        return CONFIDENCE.HIGH
    end
    
    -- ✅ ALTO: Nome contém padrão conhecido de item
    for _, pattern in ipairs(KNOWN_ITEM_PATTERNS_LOWER) do
        if string.find(nameLower, pattern, 1, true) then
            return CONFIDENCE.HIGH
        end
    end
    
    -- ✅ MÉDIO: Model pequeno sem Humanoid (já filtrado acima)
    if obj:IsA("Model") then
        local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            local size = primaryPart.Size.Magnitude
            
            -- Item: geralmente pequeno (< 5 studs de magnitude)
            if size < 5 then
                -- Verificar se tem poucas partes (items são simples)
                local partCount = 0
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") then
                        partCount = partCount + 1
                        if partCount > 10 then
                            -- Muitas partes = provavelmente não é item
                            return CONFIDENCE.NONE
                        end
                    end
                end
                
                return CONFIDENCE.MEDIUM
            end
        end
    end
    
    -- ✅ MÉDIO: MeshPart/UnionOperation com nome específico
    if (obj:IsA("MeshPart") or obj:IsA("UnionOperation")) then
        local parent = obj.Parent
        if parent and parent:IsA("Model") then
            -- Verificar se parent é Model numérico
            if tonumber(parent.Name) then
                return CONFIDENCE.MEDIUM
            end
        end
    end
    
    -- ❌ Fallback: Não é item
    return CONFIDENCE.NONE
end

-- Wrapper functions
local function isItem(obj)
    return getItemConfidence(obj) >= CONFIDENCE.MEDIUM
end

local function isDefinitelyItem(obj)
    return getItemConfidence(obj) >= CONFIDENCE.HIGH
end

-- ============================================================================
-- OBTER PARTE PARA ADORNEE (SEMPRE DO MODEL)
-- ============================================================================

local function getAdorneePart(obj)
    if not obj or not obj.Parent then return nil end
    
    if obj:IsA("Model") then
        return obj.PrimaryPart 
            or obj:FindFirstChild("Handle")
            or obj:FindFirstChildWhichIsA("MeshPart")
            or obj:FindFirstChildWhichIsA("BasePart")
    elseif obj:IsA("BasePart") then
        -- Se for BasePart, verificar se tem parent Model
        local parent = obj.Parent
        if parent and parent:IsA("Model") then
            return parent.PrimaryPart or obj
        end
        return obj
    end
    
    return nil
end

-- ============================================================================
-- OBTER OBJETO RAIZ (SEMPRE MODEL SE POSSÍVEL)
-- ============================================================================

local function getRootObject(obj)
    if not obj then return nil end
    
    -- Se já é Model, retornar
    if obj:IsA("Model") then
        return obj
    end
    
    -- Se é BasePart, verificar parent
    if obj:IsA("BasePart") then
        local parent = obj.Parent
        if parent and parent:IsA("Model") and parent.Parent then
            -- Verificar se parent também é item válido
            if isItem(parent) then
                return parent
            end
        end
    end
    
    return obj
end

-- ============================================================================
-- OBTER NOME DO ITEM
-- ============================================================================

local function getItemDisplayName(obj)
    if not obj then return "Item" end
    
    local name = obj.Name
    
    -- Se tem Attribute de nome
    local attrName = obj:GetAttribute("ItemName") or obj:GetAttribute("DisplayName")
    if attrName and type(attrName) == "string" then
        return attrName
    end
    
    -- Se nome é numérico, procurar nome descritivo
    if tonumber(name) then
        if obj:IsA("Model") then
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("BasePart") and not tonumber(child.Name) then
                    local childName = child.Name
                    if childName ~= "Part" and 
                       childName ~= "Handle" and 
                       childName ~= "MeshPart" then
                        return childName
                    end
                end
            end
        end
        return "Item #" .. name
    end
    
    -- Limpar nome
    name = string.gsub(name, "Part$", "")
    name = string.gsub(name, "Model$", "")
    name = string.gsub(name, "Clone$", "")
    name = string.gsub(name, "_", " ")
    name = string.gsub(name, "  +", " ")
    name = string.match(name, "^%s*(.-)%s*$") or name
    
    if #name == 0 then
        return "Item"
    end
    
    return name
end

-- ============================================================================
-- SETUP DOS FOLDERS
-- ============================================================================

function ItemESP:SetupFolders()
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Folder para Billboards
    self._espFolder = playerGui:FindFirstChild("_ItemESP")
    if not self._espFolder then
        self._espFolder = Instance.new("Folder")
        self._espFolder.Name = "_ItemESP"
        self._espFolder.Parent = playerGui
    end
    
    -- Folder para Highlights
    self._highlightFolder = workspace:FindFirstChild("_ESPHighlights")
    if not self._highlightFolder then
        self._highlightFolder = Instance.new("Folder")
        self._highlightFolder.Name = "_ESPHighlights"
        self._highlightFolder.Parent = workspace
    end
end

-- ============================================================================
-- HANDLER DE RESPAWN
-- ============================================================================

function ItemESP:SetupRespawnHandler()
    ConnectionManager:Add("itemESP_respawn", player.CharacterAdded:Connect(function()
        task.wait(0.5)
        self:SetupFolders()
        
        -- Reparentar billboards
        for obj, data in pairs(self._cache) do
            if data.billboard and data.billboard.Parent then
                data.billboard.Parent = self._espFolder
            end
        end
    end), "itemESP")
end

-- ============================================================================
-- CRIAR ESP (SEMPRE PARA MODEL, NÃO PARTES)
-- ============================================================================

function ItemESP:Create(obj)
    if not Config.ItemESP then return end
    
    -- Obter objeto raiz (preferir Model)
    local rootObj = getRootObject(obj)
    if not rootObj then return end
    
    -- Se já tem cache, ignorar
    if self._cache[rootObj] then return end
    
    -- Se está na blacklist, ignorar
    if self._blacklist[rootObj] then return end
    
    -- Verificar confiança
    local confidence = getItemConfidence(rootObj)
    
    if confidence < CONFIDENCE.MEDIUM then
        -- Registrar na blacklist para não verificar novamente
        self._blacklist[rootObj] = true
        
        -- Métricas de debug
        if Helpers.IsPlayer(rootObj) then
            self._metrics.playersIgnored = self._metrics.playersIgnored + 1
        elseif Helpers.IsMob(rootObj) then
            self._metrics.mobsIgnored = self._metrics.mobsIgnored + 1
        elseif rootObj:IsA("BasePart") then
            self._metrics.partsIgnored = self._metrics.partsIgnored + 1
        else
            self._metrics.itemsIgnored = self._metrics.itemsIgnored + 1
        end
        
        return
    end
    
    -- Obter parte para adornee
    local part = getAdorneePart(rootObj)
    if not part then return end
    
    -- Nome é calculado uma vez e cacheado
    local displayName = getItemDisplayName(rootObj)
    
    -- ═══════════════════════════════════════════════
    -- HIGHLIGHT (no Model, não na parte)
    -- ═══════════════════════════════════════════════
    local targetForHighlight = rootObj:IsA("Model") and rootObj or rootObj
    
    local hl = Instance.new("Highlight")
    hl.Name = "ItemHL_" .. tostring(rootObj:GetDebugId())
    hl.FillColor = Constants.COLORS.ITEM or Color3.fromRGB(255, 255, 0)
    hl.OutlineColor = Constants.COLORS.ITEM_OUTLINE or Color3.fromRGB(255, 200, 0)
    hl.FillTransparency = confidence >= CONFIDENCE.HIGH and 0.5 or 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = targetForHighlight
    hl.Parent = self._highlightFolder
    
    -- ═══════════════════════════════════════════════
    -- BILLBOARD (adornee na parte, parent no folder)
    -- ═══════════════════════════════════════════════
    local yOffset = Helpers.GetSmartYOffset(part, Helpers.EntityTypes.ITEM)
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "ItemBB_" .. tostring(rootObj:GetDebugId())
    bb.Adornee = part
    bb.Size = UDim2.fromOffset(140, 45)
    bb.StudsOffset = Vector3.new(0, yOffset, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
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
    stroke.Color = Constants.COLORS.ITEM_OUTLINE or Color3.fromRGB(255, 200, 0)
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "📦 " .. displayName
    label.TextColor3 = Constants.COLORS.ITEM or Color3.fromRGB(255, 255, 0)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    -- ═══════════════════════════════════════════════
    -- ARMAZENAR NO CACHE
    -- ═══════════════════════════════════════════════
    self._cache[rootObj] = {
        billboard = bb,
        highlight = hl,
        label = label,
        displayName = displayName,
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
    -- Tentar obter objeto raiz
    local rootObj = getRootObject(obj) or obj
    
    local data = self._cache[rootObj]
    if not data then 
        -- Tentar remover pelo obj original também
        data = self._cache[obj]
        if data then
            rootObj = obj
        else
            return 
        end
    end
    
    Helpers.SafeDestroy(data.billboard)
    Helpers.SafeDestroy(data.highlight)
    
    self._cache[rootObj] = nil
    self._blacklist[rootObj] = nil
    
    self._metrics.totalRemoved = self._metrics.totalRemoved + 1
end

-- ============================================================================
-- LOOP DE UPDATE
-- ============================================================================

function ItemESP:StartUpdateLoop()
    if self._updateLoopRunning then return end
    self._updateLoopRunning = true
    
    ConnectionManager:Add("itemESP_updateLoop", RunService.Heartbeat:Connect(function()
        if not Config.ItemESP then return end
        
        local startTime = tick()
        
        for obj, data in pairs(self._cache) do
            -- Validação de existência
            if not obj or not obj.Parent then
                self:Remove(obj)
                continue
            end
            
            -- Atualizar adornee se necessário
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
            
            -- Atualizar distância
            local dist = Cache:GetDistanceFromCamera(currentPart.Position)
            
            if data.label then
                data.label.Text = string.format("📦 %s\n%.0fm", data.displayName, dist)
            end
        end
        
        -- Métricas
        local updateTime = tick() - startTime
        self._metrics.lastUpdateTime = updateTime
        self._metrics.updateCount = self._metrics.updateCount + 1
        self._metrics.averageUpdateTime = (self._metrics.averageUpdateTime * 0.9) + (updateTime * 0.1)
        
    end), "itemESP")
end

function ItemESP:StopUpdateLoop()
    ConnectionManager:Remove("itemESP_updateLoop")
    self._updateLoopRunning = false
end

-- ============================================================================
-- PROCESSAR OBJETO (CORRIGIDO - SÓ PROCESSA MODEL)
-- ============================================================================

function ItemESP:ProcessObject(obj)
    if not Config.ItemESP then return end
    if not obj then return end
    
    -- Obter objeto raiz
    local rootObj = getRootObject(obj)
    if not rootObj then return end
    
    -- Criar ESP para o objeto raiz (MODEL)
    -- NÃO criar para cada parte individual!
    self:Create(rootObj)
end

-- ============================================================================
-- SCAN INICIAL
-- ============================================================================

function ItemESP:ScanEntities()
    if not self._entitiesFolder then return end
    
    local count = 0
    for _, obj in ipairs(self._entitiesFolder:GetChildren()) do
        -- Processar apenas children diretos (Models)
        if obj:IsA("Model") then
            self:ProcessObject(obj)
            count = count + 1
            
            if count % 50 == 0 then
                task.wait()
            end
        end
    end
end

-- ============================================================================
-- SETUP CONEXÕES
-- ============================================================================

function ItemESP:SetupEntityConnections()
    if not self._entitiesFolder then return end
    
    -- Novo objeto adicionado
    ConnectionManager:Add("itemESP_childAdded", self._entitiesFolder.ChildAdded:Connect(function(obj)
        if not Config.ItemESP then return end
        
        -- Só processar Models (items são sempre Models)
        if obj:IsA("Model") then
            task.defer(function()
                self:ProcessObject(obj)
            end)
        end
    end), "itemESP")
    
    -- Objeto removido
    ConnectionManager:Add("itemESP_childRemoved", self._entitiesFolder.ChildRemoved:Connect(function(obj)
        self:Remove(obj)
    end), "itemESP")
    
    -- NÃO usar DescendantAdded/Removed para evitar pegar partes de mobs
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

function ItemESP:Init()
    if self._initialized then return end
    
    print("📦 ItemESP: Inicializando...")
    
    self:SetupFolders()
    self:SetupRespawnHandler()
    
    self._entitiesFolder = workspace:FindFirstChild("Entities")
    
    if self._entitiesFolder then
        self:SetupEntityConnections()
        self:ScanEntities()
    else
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
    
    -- Limpar blacklist também
    self._blacklist = {}
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

function ItemESP:GetBlacklistCount()
    local count = 0
    for _ in pairs(self._blacklist) do
        count = count + 1
    end
    return count
end

function ItemESP:GetMetrics()
    return {
        currentCount = self:GetCount(),
        blacklistCount = self:GetBlacklistCount(),
        totalCreated = self._metrics.totalCreated,
        totalRemoved = self._metrics.totalRemoved,
        itemsIgnored = self._metrics.itemsIgnored,
        playersIgnored = self._metrics.playersIgnored,
        mobsIgnored = self._metrics.mobsIgnored,
        partsIgnored = self._metrics.partsIgnored,
        lastUpdateTime = string.format("%.4fms", self._metrics.lastUpdateTime * 1000),
        averageUpdateTime = string.format("%.4fms", self._metrics.averageUpdateTime * 1000),
        updateCount = self._metrics.updateCount,
        updateLoopRunning = self._updateLoopRunning,
    }
end

function ItemESP:IsTracking(obj)
    local rootObj = getRootObject(obj) or obj
    return self._cache[rootObj] ~= nil
end

function ItemESP:IsBlacklisted(obj)
    local rootObj = getRootObject(obj) or obj
    return self._blacklist[rootObj] == true
end

function ItemESP:GetItemConfidence(obj)
    return getItemConfidence(obj)
end

-- Debug: Listar todos os items rastreados
function ItemESP:GetTrackedItems()
    local items = {}
    for obj, data in pairs(self._cache) do
        table.insert(items, {
            name = data.displayName,
            confidence = data.confidence,
            object = obj,
            age = tick() - data.createdAt,
        })
    end
    return items
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.ItemESP = ItemESP

return ItemESP