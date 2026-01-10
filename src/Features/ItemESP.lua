-- ============================================================================
-- ITEM ESP - Detecta itens na pasta Entities
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")

local ItemESP = {
    _cache = {},           -- obj -> {billboard, highlight, updateId}
    _entitiesFolder = nil,
    _initialized = false,
}

local player = Players.LocalPlayer

-- ============================================================================
-- DETECÇÃO DE ITEM (MELHORADA)
-- ============================================================================

local function isItem(obj)
    if not obj then return false end
    
    -- Pode ser BasePart ou Model
    if not obj:IsA("BasePart") and not obj:IsA("Model") then
        return false
    end
    
    local name = obj.Name
    
    -- Nome numérico = item dropado
    if tonumber(name) then
        return true
    end
    
    -- Contém "part" no nome (case insensitive)
    if string.find(string.lower(name), "part") then
        return true
    end
    
    -- Verifica se é um item baseado em propriedades
    if obj:IsA("Model") then
        -- Models com nome numérico ou sem humanoid são itens
        local hasHumanoid = obj:FindFirstChildOfClass("Humanoid")
        if not hasHumanoid and tonumber(name) then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- OBTER PARTE PARA ADORNEE
-- ============================================================================

local function getAdorneePart(obj)
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        if obj.PrimaryPart then
            return obj.PrimaryPart
        end
        return obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

-- ============================================================================
-- OBTER NOME DO ITEM
-- ============================================================================

local function getItemDisplayName(obj)
    local name = obj.Name
    
    -- Se for numérico, tenta encontrar um nome melhor
    if tonumber(name) then
        -- Procura por uma parte com nome descritivo dentro
        if obj:IsA("Model") then
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("BasePart") and not tonumber(child.Name) then
                    return child.Name
                end
            end
        end
        return "Item #" .. name
    end
    
    return name
end

-- ============================================================================
-- CRIAR ESP PARA UM OBJETO
-- ============================================================================

function ItemESP:Create(obj)
    if not Config.ItemESP then return end
    if not isItem(obj) then return end
    if self._cache[obj] then return end
    
    local part = getAdorneePart(obj)
    if not part then return end
    
    local displayName = getItemDisplayName(obj)
    
    -- Highlight
    local targetForHighlight = obj:IsA("Model") and obj or obj
    local hl = Instance.new("Highlight")
    hl.Name = "ItemESP"
    hl.FillColor = Constants.COLORS.ITEM
    hl.OutlineColor = Constants.COLORS.ITEM_OUTLINE
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = targetForHighlight
    hl.Parent = targetForHighlight
    
    -- Billboard (no PlayerGui para não ser afetado por hierarquia)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ItemESP_" .. tostring(obj:GetDebugId())
    bb.Adornee = part
    bb.Size = UDim2.fromOffset(150, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = player:WaitForChild("PlayerGui")
    
    -- Frame com estilo
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
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "📦 " .. displayName
    label.TextColor3 = Constants.COLORS.ITEM
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextScaled = false
    label.Parent = frame
    
    -- Update loop
    local updateId = "itemESP_" .. tostring(obj:GetDebugId())
    ConnectionManager:Add(updateId, RunService.Heartbeat:Connect(function()
        -- Verificar se objeto ainda existe
        if not obj or not obj.Parent then
            self:Remove(obj)
            return
        end
        
        -- Verificar se parte ainda existe
        local currentPart = getAdorneePart(obj)
        if not currentPart then
            self:Remove(obj)
            return
        end
        
        -- Atualizar adornee se mudou
        if bb.Adornee ~= currentPart then
            bb.Adornee = currentPart
        end
        
        -- Atualizar distância
        local dist = Cache:GetDistanceFromCamera(currentPart.Position)
        label.Text = string.format("📦 %s\n%.0fm", displayName, dist)
    end), "itemESP")
    
    -- Armazenar referências
    self._cache[obj] = {
        billboard = bb,
        highlight = hl,
        updateId = updateId,
        displayName = displayName
    }
end

-- ============================================================================
-- REMOVER ESP
-- ============================================================================

function ItemESP:Remove(obj)
    local data = self._cache[obj]
    if not data then return end
    
    -- Remover conexão primeiro
    if data.updateId then
        ConnectionManager:Remove(data.updateId)
    end
    
    -- Destruir objetos
    Helpers.SafeDestroy(data.billboard)
    Helpers.SafeDestroy(data.highlight)
    
    self._cache[obj] = nil
end

-- ============================================================================
-- PROCESSAR OBJETO (VERIFICA SE É ITEM OU MODEL COM ITENS)
-- ============================================================================

function ItemESP:ProcessObject(obj)
    if not Config.ItemESP then return end
    
    -- Tentar criar ESP para o objeto
    self:Create(obj)
    
    -- Se for Model, verificar filhos também
    if obj:IsA("Model") then
        for _, child in ipairs(obj:GetChildren()) do
            if isItem(child) then
                self:Create(child)
            end
        end
    end
end

-- ============================================================================
-- SCAN INICIAL DA PASTA ENTITIES
-- ============================================================================

function ItemESP:ScanEntities()
    if not self._entitiesFolder then return end
    
    for _, obj in ipairs(self._entitiesFolder:GetChildren()) do
        task.spawn(function()
            self:ProcessObject(obj)
        end)
    end
end

-- ============================================================================
-- INICIALIZAR MONITORAMENTO
-- ============================================================================

function ItemESP:Init()
    if self._initialized then return end
    
    -- Buscar pasta Entities
    self._entitiesFolder = workspace:FindFirstChild("Entities")
    
    if not self._entitiesFolder then
        -- Esperar pela pasta
        task.spawn(function()
            self._entitiesFolder = workspace:WaitForChild("Entities", 30)
            if self._entitiesFolder then
                self:SetupConnections()
                self:ScanEntities()
            end
        end)
    else
        self:SetupConnections()
        self:ScanEntities()
    end
    
    self._initialized = true
end

-- ============================================================================
-- CONFIGURAR CONEXÕES
-- ============================================================================

function ItemESP:SetupConnections()
    if not self._entitiesFolder then return end
    
    -- Novo objeto adicionado
    ConnectionManager:Add("itemESP_childAdded", self._entitiesFolder.ChildAdded:Connect(function(obj)
        if not Config.ItemESP then return end
        task.wait(0.1) -- Pequeno delay para garantir que o objeto está completo
        self:ProcessObject(obj)
    end), "itemESP")
    
    -- Objeto removido
    ConnectionManager:Add("itemESP_childRemoved", self._entitiesFolder.ChildRemoved:Connect(function(obj)
        self:Remove(obj)
        
        -- Remover filhos também se era um Model
        if obj:IsA("Model") then
            for _, child in ipairs(obj:GetChildren()) do
                self:Remove(child)
            end
        end
    end), "itemESP")
    
    -- Descendant adicionado (para itens dentro de models)
    ConnectionManager:Add("itemESP_descendantAdded", self._entitiesFolder.DescendantAdded:Connect(function(obj)
        if not Config.ItemESP then return end
        task.defer(function()
            if isItem(obj) then
                self:Create(obj)
            end
        end)
    end), "itemESP")
    
    -- Descendant removido
    ConnectionManager:Add("itemESP_descendantRemoved", self._entitiesFolder.DescendantRemoved:Connect(function(obj)
        self:Remove(obj)
    end), "itemESP")
    
    print("✅ ItemESP: Monitorando pasta Entities")
end

-- ============================================================================
-- LIMPAR TUDO
-- ============================================================================

function ItemESP:ClearAll()
    -- Coletar todas as keys primeiro (evita modificar durante iteração)
    local objects = {}
    for obj in pairs(self._cache) do
        table.insert(objects, obj)
    end
    
    -- Remover cada um
    for _, obj in ipairs(objects) do
        self:Remove(obj)
    end
end

-- ============================================================================
-- TOGGLE
-- ============================================================================

function ItemESP:Enable()
    if not self._initialized then
        self:Init()
    else
        self:ScanEntities()
    end
end

function ItemESP:Disable()
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
-- ESTATÍSTICAS
-- ============================================================================

function ItemESP:GetCount()
    local count = 0
    for _ in pairs(self._cache) do
        count = count + 1
    end
    return count
end

function ItemESP:IsTracking(obj)
    return self._cache[obj] ~= nil
end

-- ============================================================================
-- REFRESH (RESCAN)
-- ============================================================================

function ItemESP:Refresh()
    self:ClearAll()
    if Config.ItemESP then
        self:ScanEntities()
    end
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.ItemESP = ItemESP

return ItemESP