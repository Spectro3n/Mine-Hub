-- ============================================================================
-- HELPERS v2.1 - Com Detecção de Hitbox Real vs Visual
-- ============================================================================

local Players = game:GetService("Players")

local Helpers = {
    -- ═══════════════════════════════════════════════
    -- CACHE INTERNO (weak references)
    -- ═══════════════════════════════════════════════
    _hitboxCache = setmetatable({}, {__mode = "k"}),
    _entityTypeCache = setmetatable({}, {__mode = "k"}),
    _realHitboxCache = setmetatable({}, {__mode = "k"}),
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO
    -- ═══════════════════════════════════════════════
    _config = {
        hitboxCacheTTL = 5,
        debugMode = false,
    },
}

-- ============================================================================
-- TIPOS DE ENTIDADES (NUMÉRICOS PARA PERFORMANCE)
-- ============================================================================

Helpers.EntityTypes = {
    PLAYER = 1,
    NPC = 2,
    ANIMAL = 3,
    ITEM = 4,
    STRUCTURE = 5,
    UNKNOWN = 0,
}

-- Nomes para debug
Helpers.EntityTypeNames = {
    [0] = "Unknown",
    [1] = "Player",
    [2] = "NPC",
    [3] = "Animal",
    [4] = "Item",
    [5] = "Structure",
}

-- ============================================================================
-- DETECÇÃO DE TIPO DE ENTIDADE (OTIMIZADA)
-- ============================================================================

function Helpers.GetEntityType(model)
    if not model then return Helpers.EntityTypes.ITEM end
    
    -- Cache check
    local cached = Helpers._entityTypeCache[model]
    if cached then return cached end
    
    local entityType = Helpers.EntityTypes.UNKNOWN
    
    -- ═══════════════════════════════════════════════
    -- BASEPART SOLTA = ITEM
    -- ═══════════════════════════════════════════════
    if not model:IsA("Model") then
        if model:IsA("BasePart") then
            entityType = Helpers.EntityTypes.ITEM
        end
        Helpers._entityTypeCache[model] = entityType
        return entityType
    end
    
    -- ═══════════════════════════════════════════════
    -- MODEL COM HUMANOID
    -- ═══════════════════════════════════════════════
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        -- Verificar se é player
        local player = Players:GetPlayerFromCharacter(model)
        if player then
            entityType = Helpers.EntityTypes.PLAYER
        else
            -- NPC (tem Humanoid mas não é player)
            entityType = Helpers.EntityTypes.NPC
        end
        
        Helpers._entityTypeCache[model] = entityType
        return entityType
    end
    
    -- ═══════════════════════════════════════════════
    -- MODEL COM HITBOX (ANIMAL)
    -- ═══════════════════════════════════════════════
    if model:FindFirstChild("Hitbox") then
        entityType = Helpers.EntityTypes.ANIMAL
        Helpers._entityTypeCache[model] = entityType
        return entityType
    end
    
    -- ═══════════════════════════════════════════════
    -- MODEL SEM HUMANOID E SEM HITBOX
    -- ═══════════════════════════════════════════════
    local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        local size = primaryPart.Size.Magnitude
        if size < 10 then
            entityType = Helpers.EntityTypes.ITEM
        else
            entityType = Helpers.EntityTypes.STRUCTURE
        end
    else
        entityType = Helpers.EntityTypes.ITEM
    end
    
    Helpers._entityTypeCache[model] = entityType
    return entityType
end

-- Funções de verificação rápida
function Helpers.IsPlayer(model)
    return Helpers.GetEntityType(model) == Helpers.EntityTypes.PLAYER
end

function Helpers.IsNPC(model)
    return Helpers.GetEntityType(model) == Helpers.EntityTypes.NPC
end

function Helpers.IsAnimal(model)
    return Helpers.GetEntityType(model) == Helpers.EntityTypes.ANIMAL
end

function Helpers.IsItem(model)
    return Helpers.GetEntityType(model) == Helpers.EntityTypes.ITEM
end

function Helpers.IsMob(model)
    local t = Helpers.GetEntityType(model)
    return t == Helpers.EntityTypes.NPC or t == Helpers.EntityTypes.ANIMAL
end

function Helpers.GetEntityTypeName(model)
    local t = Helpers.GetEntityType(model)
    return Helpers.EntityTypeNames[t] or "Unknown"
end

-- ============================================================================
-- HITBOX REAL (PARA HIT/COMBAT) - NUNCA USA PLAYERHITBOX!
-- ============================================================================

function Helpers.GetRealHitbox(model)
    if not model then return nil end
    
    -- Cache check
    local cached = Helpers._realHitboxCache[model]
    if cached and cached.Parent then
        return cached
    end
    
    local hitbox = nil
    local entityType = Helpers.GetEntityType(model)
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER - NUNCA playerhitbox! Sempre HumanoidRootPart
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.PLAYER then
        hitbox = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
            or model:FindFirstChild("Head")
    
    -- ═══════════════════════════════════════════════
    -- 🤖 NPC - Similar ao player
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.NPC then
        hitbox = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Hitbox")
            or model.PrimaryPart
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
            or model:FindFirstChildWhichIsA("BasePart")
    
    -- ═══════════════════════════════════════════════
    -- 🐷 ANIMAL - Usa Hitbox real
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.ANIMAL then
        hitbox = model:FindFirstChild("Hitbox")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart")
    
    -- ═══════════════════════════════════════════════
    -- 📦 ITEM - A própria parte
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.ITEM then
        if model:IsA("BasePart") then
            hitbox = model
        elseif model:IsA("Model") then
            hitbox = model.PrimaryPart
                or model:FindFirstChild("Handle")
                or model:FindFirstChildWhichIsA("BasePart")
        end
    
    -- ═══════════════════════════════════════════════
    -- 🆘 FALLBACK
    -- ═══════════════════════════════════════════════
    else
        if model:IsA("BasePart") then
            hitbox = model
        elseif model:IsA("Model") then
            hitbox = model.PrimaryPart
                or model:FindFirstChild("Hitbox")
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChildWhichIsA("BasePart")
        end
    end
    
    -- Cache result
    if hitbox then
        Helpers._realHitboxCache[model] = hitbox
    end
    
    return hitbox
end

-- ============================================================================
-- HITBOX VISUAL (PARA ESP) - PODE USAR PLAYERHITBOX
-- ============================================================================

function Helpers.GetVisualHitbox(model)
    if not model then return nil end
    
    -- Cache check
    local cached = Helpers._hitboxCache[model]
    if cached and cached.Parent then
        return cached
    end
    
    local hitbox = nil
    local entityType = Helpers.GetEntityType(model)
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER - playerhitbox OK para visual
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.PLAYER then
        hitbox = model:FindFirstChild("playerhitbox")
            or model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
            or model:FindFirstChild("Head")
    
    -- ═══════════════════════════════════════════════
    -- 🤖 NPC
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.NPC then
        hitbox = model:FindFirstChild("Hitbox")
            or model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart")
    
    -- ═══════════════════════════════════════════════
    -- 🐷 ANIMAL
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.ANIMAL then
        hitbox = model:FindFirstChild("Hitbox")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart")
    
    -- ═══════════════════════════════════════════════
    -- 📦 ITEM
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.ITEM then
        if model:IsA("BasePart") then
            hitbox = model
        elseif model:IsA("Model") then
            hitbox = model.PrimaryPart
                or model:FindFirstChild("Handle")
                or model:FindFirstChildWhichIsA("BasePart")
        end
    
    -- ═══════════════════════════════════════════════
    -- 🆘 FALLBACK
    -- ═══════════════════════════════════════════════
    else
        if model:IsA("BasePart") then
            hitbox = model
        elseif model:IsA("Model") then
            hitbox = model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")
        end
    end
    
    -- Cache result
    if hitbox then
        Helpers._hitboxCache[model] = hitbox
    end
    
    return hitbox
end

-- Alias para compatibilidade (usa visual por padrão)
function Helpers.GetHitbox(model)
    return Helpers.GetVisualHitbox(model)
end

-- ============================================================================
-- OFFSET INTELIGENTE PARA ESP
-- ============================================================================

function Helpers.GetSmartYOffset(hitbox, entityType)
    if not hitbox then return 2 end
    
    local sizeY = hitbox.Size.Y
    entityType = entityType or Helpers.GetEntityType(hitbox.Parent or hitbox)
    
    -- Players: offset maior
    if entityType == Helpers.EntityTypes.PLAYER then
        return math.clamp(sizeY * 0.7 + 1, 2.5, 5)
    end
    
    -- NPCs/Animals: offset médio
    if entityType == Helpers.EntityTypes.NPC or entityType == Helpers.EntityTypes.ANIMAL then
        return math.clamp(sizeY * 0.6 + 0.5, 1.5, 6)
    end
    
    -- Items: offset pequeno
    if entityType == Helpers.EntityTypes.ITEM then
        return math.clamp(sizeY * 0.5 + 1, 1, 3)
    end
    
    -- Fallback
    return math.clamp(sizeY * 0.6, 1.5, 5)
end

function Helpers.GetYOffset(part)
    if not part then return 3 end
    return Helpers.GetSmartYOffset(part)
end

-- ============================================================================
-- FUNÇÕES ORIGINAIS MANTIDAS
-- ============================================================================

function Helpers.SafeTableClear(tbl, cleanupFunc)
    if not tbl then return end
    
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    
    for _, key in ipairs(keys) do
        local value = tbl[key]
        if cleanupFunc then
            pcall(cleanupFunc, key, value)
        end
        tbl[key] = nil
    end
end

function Helpers.MatchDecal(decal, id)
    if not decal or not decal:IsA("Decal") then return false end
    local texture = decal.Texture
    if not texture then return false end
    return string.find(texture, id, 1, true) ~= nil
end

function Helpers.GetHumanoid(model)
    if not model or not model:IsA("Model") then return nil end
    return model:FindFirstChildOfClass("Humanoid")
end

function Helpers.GetPrimaryPart(model)
    if not model or not model:IsA("Model") then return nil end
    return Helpers.GetVisualHitbox(model)
end

-- ============================================================================
-- CRIAÇÃO DE UI
-- ============================================================================

function Helpers.CreateBillboard(adornee, size, offset, parent)
    if not adornee then return nil end
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPBillboard"
    bb.AlwaysOnTop = true
    bb.Size = size or UDim2.fromOffset(100, 30)
    bb.StudsOffset = offset or Vector3.new(0, 2, 0)
    bb.Adornee = adornee
    bb.ResetOnSpawn = false
    bb.Parent = parent or adornee
    
    return bb
end

function Helpers.CreateHighlight(adornee, fillColor, outlineColor, fillTransparency, parent)
    if not adornee then return nil end
    
    local hl = Instance.new("Highlight")
    hl.Name = "ESPHighlight"
    hl.FillColor = fillColor or Color3.new(1, 1, 1)
    hl.OutlineColor = outlineColor or fillColor or Color3.new(1, 1, 1)
    hl.FillTransparency = fillTransparency or 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = adornee
    hl.Parent = parent or adornee
    
    return hl
end

function Helpers.CreateRoundedFrame(parent, backgroundColor, transparency, cornerRadius)
    local frame = Instance.new("Frame")
    frame.Name = "ESPFrame"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = backgroundColor or Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = transparency or 0.3
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = cornerRadius or UDim.new(0, 6)
    corner.Parent = frame
    
    return frame
end

function Helpers.CreateTextLabel(parent, text, textColor, font, textSize)
    local label = Instance.new("TextLabel")
    label.Name = "ESPLabel"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.TextColor3 = textColor or Color3.new(1, 1, 1)
    label.Font = font or Enum.Font.GothamBold
    label.TextSize = textSize or 14
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = parent
    
    return label
end

-- ============================================================================
-- VALIDAÇÃO
-- ============================================================================

function Helpers.SafeDestroy(obj)
    if obj and typeof(obj) == "Instance" then
        pcall(function()
            obj:Destroy()
        end)
        return true
    end
    return false
end

function Helpers.IsValid(instance)
    if not instance then return false end
    if typeof(instance) ~= "Instance" then return false end
    
    local success, parent = pcall(function()
        return instance.Parent
    end)
    
    return success and parent ~= nil
end

function Helpers.IsValidModel(model)
    if not Helpers.IsValid(model) then return false end
    if not model:IsA("Model") then return false end
    return model:FindFirstChildWhichIsA("BasePart") ~= nil
end

-- ============================================================================
-- FORMATAÇÃO
-- ============================================================================

function Helpers.FormatDistance(distance)
    if distance < 0 then return "0m" end
    if distance > 9999 then return "999+m" end
    return string.format("%.0fm", distance)
end

function Helpers.FormatHealth(health, maxHealth)
    if not health then return "?" end
    health = math.max(0, health)
    
    if maxHealth and maxHealth > 0 then
        local percent = (health / maxHealth) * 100
        return string.format("%.0f/%.0f (%.0f%%)", health, maxHealth, percent)
    end
    
    return string.format("%.0f", health)
end

function Helpers.FormatHealthShort(health, maxHealth)
    if not health then return "?" end
    health = math.max(0, health)
    
    if maxHealth and maxHealth > 0 then
        return string.format("%.0f/%.0f", health, maxHealth)
    end
    
    return string.format("%.0f", health)
end

function Helpers.GetHealthColor(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return Color3.new(1, 1, 1)
    end
    
    local percent = math.clamp(health / maxHealth, 0, 1)
    
    if percent > 0.5 then
        local t = (percent - 0.5) * 2
        return Color3.new(1 - t, 1, 0)
    else
        local t = percent * 2
        return Color3.new(1, t, 0)
    end
end

-- ============================================================================
-- LIMPAR CACHES
-- ============================================================================

function Helpers.ClearCache(model)
    if model then
        Helpers._hitboxCache[model] = nil
        Helpers._entityTypeCache[model] = nil
        Helpers._realHitboxCache[model] = nil
    else
        Helpers._hitboxCache = setmetatable({}, {__mode = "k"})
        Helpers._entityTypeCache = setmetatable({}, {__mode = "k"})
        Helpers._realHitboxCache = setmetatable({}, {__mode = "k"})
    end
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Helpers = Helpers

return Helpers