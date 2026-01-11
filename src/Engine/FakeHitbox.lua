-- ============================================================================
-- FAKE HITBOX v1.0 - Sistema de Hitbox Fake para Players
-- ============================================================================
-- ⚠️ IMPORTANTE:
-- - Usa Part SOLDADA ao HumanoidRootPart
-- - Não modifica hitbox real do player
-- - Funciona em qualquer executor
-- - CanQuery = true para raycasts funcionarem
-- ============================================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Helpers = require("Utils/Helpers")
local ConnectionManager = require("Engine/ConnectionManager")

local FakeHitbox = {
    -- ═══════════════════════════════════════════════
    -- CACHE DE FAKE HITBOXES
    -- ═══════════════════════════════════════════════
    _active = {},           -- character -> Part
    _welds = {},            -- character -> WeldConstraint
    _visualBoxes = {},      -- character -> BoxHandleAdornment
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO PADRÃO
    -- ═══════════════════════════════════════════════
    _config = {
        defaultSize = Vector3.new(8, 8, 8),
        transparency = 1,           -- Invisível por padrão
        showVisual = false,         -- Mostrar box visual?
        visualColor = Color3.fromRGB(255, 0, 0),
        visualTransparency = 0.7,
    },
    
    -- ═══════════════════════════════════════════════
    -- MÉTRICAS
    -- ═══════════════════════════════════════════════
    _metrics = {
        totalCreated = 0,
        totalRemoved = 0,
        currentActive = 0,
    },
    
    _initialized = false,
}

local player = Players.LocalPlayer

-- ============================================================================
-- CRIAR FAKE HITBOX
-- ============================================================================

function FakeHitbox:Create(character, size, showVisual)
    if not character then return nil end
    if not Helpers.IsValid(character) then return nil end
    
    -- Se já existe, apenas atualizar tamanho
    if self._active[character] then
        return self:UpdateSize(character, size)
    end
    
    -- Verificar se é um character válido (tem HumanoidRootPart)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        warn("[FakeHitbox] Character sem HumanoidRootPart:", character.Name)
        return nil
    end
    
    -- Criar a parte fake
    local part = Instance.new("Part")
    part.Name = "FakeHitbox"
    part.Size = size or self._config.defaultSize
    part.Transparency = self._config.transparency
    part.Color = Color3.fromRGB(255, 0, 0)
    
    -- ⚠️ PROPRIEDADES CRÍTICAS PARA FUNCIONAR
    part.CanCollide = false     -- Não colide com nada
    part.CanTouch = true        -- Pode ser tocado (para Touch events)
    part.CanQuery = true        -- ⚠️ CRÍTICO: Permite raycast detectar!
    part.Massless = true        -- Não afeta física
    part.Anchored = false       -- Não ancorado (segue o weld)
    
    -- Centralizar na posição do HRP
    part.CFrame = hrp.CFrame
    part.Parent = character
    
    -- Criar WeldConstraint para soldar ao HRP
    local weld = Instance.new("WeldConstraint")
    weld.Name = "FakeHitboxWeld"
    weld.Part0 = hrp
    weld.Part1 = part
    weld.Parent = part
    
    -- Armazenar referências
    self._active[character] = part
    self._welds[character] = weld
    
    -- Criar visual se solicitado
    if showVisual or self._config.showVisual then
        self:CreateVisual(character)
    end
    
    -- Métricas
    self._metrics.totalCreated = self._metrics.totalCreated + 1
    self._metrics.currentActive = self._metrics.currentActive + 1
    
    return part
end

-- ============================================================================
-- CRIAR VISUAL (BOXHANDLEADORNMENT)
-- ============================================================================

function FakeHitbox:CreateVisual(character)
    if not character then return nil end
    
    local part = self._active[character]
    if not part then return nil end
    
    -- Remover visual anterior se existir
    if self._visualBoxes[character] then
        Helpers.SafeDestroy(self._visualBoxes[character])
    end
    
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "FakeHitboxVisual"
    box.Adornee = part
    box.Size = part.Size
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Transparency = self._config.visualTransparency
    box.Color3 = self._config.visualColor
    box.Parent = part
    
    self._visualBoxes[character] = box
    
    return box
end

function FakeHitbox:RemoveVisual(character)
    if self._visualBoxes[character] then
        Helpers.SafeDestroy(self._visualBoxes[character])
        self._visualBoxes[character] = nil
    end
end

-- ============================================================================
-- ATUALIZAR TAMANHO
-- ============================================================================

function FakeHitbox:UpdateSize(character, newSize)
    local part = self._active[character]
    if not part then return nil end
    
    if typeof(newSize) == "number" then
        newSize = Vector3.new(newSize, newSize, newSize)
    end
    
    part.Size = newSize or self._config.defaultSize
    
    -- Atualizar visual se existir
    if self._visualBoxes[character] then
        self._visualBoxes[character].Size = part.Size
    end
    
    return part
end

-- ============================================================================
-- REMOVER FAKE HITBOX
-- ============================================================================

function FakeHitbox:Remove(character)
    if not character then return false end
    
    -- Remover visual
    self:RemoveVisual(character)
    
    -- Remover weld
    if self._welds[character] then
        Helpers.SafeDestroy(self._welds[character])
        self._welds[character] = nil
    end
    
    -- Remover parte
    if self._active[character] then
        Helpers.SafeDestroy(self._active[character])
        self._active[character] = nil
        
        self._metrics.totalRemoved = self._metrics.totalRemoved + 1
        self._metrics.currentActive = math.max(0, self._metrics.currentActive - 1)
        
        return true
    end
    
    return false
end

-- ============================================================================
-- REMOVER TODOS
-- ============================================================================

function FakeHitbox:RemoveAll()
    local removed = 0
    
    local characters = {}
    for char in pairs(self._active) do
        table.insert(characters, char)
    end
    
    for _, char in ipairs(characters) do
        if self:Remove(char) then
            removed = removed + 1
        end
    end
    
    return removed
end

-- ============================================================================
-- VERIFICAÇÕES
-- ============================================================================

function FakeHitbox:Has(character)
    return self._active[character] ~= nil
end

function FakeHitbox:Get(character)
    return self._active[character]
end

function FakeHitbox:GetSize(character)
    local part = self._active[character]
    if part then
        return part.Size
    end
    return nil
end

-- ============================================================================
-- TOGGLE VISUAL GLOBAL
-- ============================================================================

function FakeHitbox:ToggleVisuals(show)
    self._config.showVisual = show
    
    if show then
        for char in pairs(self._active) do
            if not self._visualBoxes[char] then
                self:CreateVisual(char)
            end
        end
    else
        for char in pairs(self._visualBoxes) do
            self:RemoveVisual(char)
        end
    end
end

-- ============================================================================
-- CONFIGURAÇÃO
-- ============================================================================

function FakeHitbox:Configure(options)
    if options.defaultSize then
        if typeof(options.defaultSize) == "number" then
            self._config.defaultSize = Vector3.new(options.defaultSize, options.defaultSize, options.defaultSize)
        else
            self._config.defaultSize = options.defaultSize
        end
    end
    
    if options.showVisual ~= nil then
        self:ToggleVisuals(options.showVisual)
    end
    
    if options.visualColor then
        self._config.visualColor = options.visualColor
        
        -- Atualizar visuais existentes
        for _, box in pairs(self._visualBoxes) do
            if box and box.Parent then
                box.Color3 = options.visualColor
            end
        end
    end
    
    if options.visualTransparency then
        self._config.visualTransparency = options.visualTransparency
        
        for _, box in pairs(self._visualBoxes) do
            if box and box.Parent then
                box.Transparency = options.visualTransparency
            end
        end
    end
end

function FakeHitbox:GetConfig()
    return {
        defaultSize = self._config.defaultSize,
        showVisual = self._config.showVisual,
        visualColor = self._config.visualColor,
        visualTransparency = self._config.visualTransparency,
    }
end

-- ============================================================================
-- AUTO-CLEANUP
-- ============================================================================

function FakeHitbox:StartAutoCleanup()
    if self._cleanupConnection then return end
    
    ConnectionManager:Add("fakeHitbox_cleanup", RunService.Heartbeat:Connect(function()
        local toRemove = {}
        
        for char in pairs(self._active) do
            if not Helpers.IsValid(char) then
                table.insert(toRemove, char)
            end
        end
        
        for _, char in ipairs(toRemove) do
            self:Remove(char)
        end
    end), "fakeHitbox")
end

function FakeHitbox:StopAutoCleanup()
    ConnectionManager:Remove("fakeHitbox_cleanup")
end

-- ============================================================================
-- MÉTRICAS
-- ============================================================================

function FakeHitbox:GetMetrics()
    return {
        totalCreated = self._metrics.totalCreated,
        totalRemoved = self._metrics.totalRemoved,
        currentActive = self._metrics.currentActive,
        withVisual = self:GetVisualCount(),
    }
end

function FakeHitbox:GetCount()
    local count = 0
    for _ in pairs(self._active) do
        count = count + 1
    end
    return count
end

function FakeHitbox:GetVisualCount()
    local count = 0
    for _ in pairs(self._visualBoxes) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.FakeHitbox = FakeHitbox

return FakeHitbox