-- ============================================================================
-- HELPERS v2.0 - Funções Utilitárias Otimizadas
-- ============================================================================

local Players = game:GetService("Players")

local Helpers = {
    -- ═══════════════════════════════════════════════
    -- CACHE INTERNO (weak references)
    -- ═══════════════════════════════════════════════
    _hitboxCache = setmetatable({}, {__mode = "k"}),
    _entityTypeCache = setmetatable({}, {__mode = "k"}),
    _playerCache = setmetatable({}, {__mode = "k"}),
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO
    -- ═══════════════════════════════════════════════
    _config = {
        hitboxCacheTTL = 5,        -- Segundos de validade do cache
        debugMode = false,
    },
}

-- ============================================================================
-- TIPOS DE ENTIDADES
-- ============================================================================

Helpers.EntityTypes = {
    PLAYER = "Player",
    ANIMAL = "Animal",
    MOB = "Mob",
    ITEM = "Item",
    STRUCTURE = "Structure",
    UNKNOWN = "Unknown",
}

-- ============================================================================
-- DETECÇÃO DE TIPO DE ENTIDADE
-- ============================================================================

function Helpers.GetEntityType(obj)
    if not obj then return Helpers.EntityTypes.UNKNOWN end
    
    -- Verificar cache primeiro
    local cached = Helpers._entityTypeCache[obj]
    if cached then return cached end
    
    local entityType = Helpers.EntityTypes.UNKNOWN
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER - tem playerhitbox ou é character de player
    -- ═══════════════════════════════════════════════
    if obj:IsA("Model") then
        -- Verificar se é character de um player
        local player = Players:GetPlayerFromCharacter(obj)
        if player then
            entityType = Helpers.EntityTypes.PLAYER
        -- Verificar playerhitbox (comum em alguns jogos)
        elseif obj:FindFirstChild("playerhitbox") then
            entityType = Helpers.EntityTypes.PLAYER
        -- Verificar Humanoid com nome de player
        elseif obj:FindFirstChildOfClass("Humanoid") then
            local possiblePlayer = Players:FindFirstChild(obj.Name)
            if possiblePlayer then
                entityType = Helpers.EntityTypes.PLAYER
            end
        end
    end
    
    -- ═══════════════════════════════════════════════
    -- 🐷 ANIMAL/MOB - Model com Hitbox mas não é player
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.UNKNOWN and obj:IsA("Model") then
        local hasHitbox = obj:FindFirstChild("Hitbox")
        local hasHumanoid = obj:FindFirstChildOfClass("Humanoid")
        
        if hasHitbox or hasHumanoid then
            -- Verificar se tem animação (animais geralmente têm)
            local hasAnimator = obj:FindFirstChildOfClass("Animator", true)
            local hasAnimationController = obj:FindFirstChildOfClass("AnimationController", true)
            
            if hasAnimator or hasAnimationController then
                entityType = Helpers.EntityTypes.ANIMAL
            else
                entityType = Helpers.EntityTypes.MOB
            end
        end
    end
    
    -- ═══════════════════════════════════════════════
    -- 📦 ITEM - BasePart solta ou Model pequeno sem Humanoid
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.UNKNOWN then
        if obj:IsA("BasePart") then
            -- BasePart solta = provavelmente item
            entityType = Helpers.EntityTypes.ITEM
        elseif obj:IsA("Model") then
            -- Model pequeno sem Humanoid = provavelmente item
            local hasHumanoid = obj:FindFirstChildOfClass("Humanoid")
            if not hasHumanoid then
                local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    local size = primaryPart.Size.Magnitude
                    if size < 10 then
                        entityType = Helpers.EntityTypes.ITEM
                    else
                        entityType = Helpers.EntityTypes.STRUCTURE
                    end
                end
            end
        end
    end
    
    -- Cachear resultado
    Helpers._entityTypeCache[obj] = entityType
    
    return entityType
end

-- Verificações rápidas
function Helpers.IsPlayer(obj)
    return Helpers.GetEntityType(obj) == Helpers.EntityTypes.PLAYER
end

function Helpers.IsAnimal(obj)
    return Helpers.GetEntityType(obj) == Helpers.EntityTypes.ANIMAL
end

function Helpers.IsMob(obj)
    local t = Helpers.GetEntityType(obj)
    return t == Helpers.EntityTypes.ANIMAL or t == Helpers.EntityTypes.MOB
end

function Helpers.IsItem(obj)
    return Helpers.GetEntityType(obj) == Helpers.EntityTypes.ITEM
end

-- ============================================================================
-- HITBOX INTELIGENTE
-- ============================================================================

function Helpers.GetHitbox(obj)
    if not Helpers.IsValid(obj) then return nil end
    
    -- Verificar cache
    local cached = Helpers._hitboxCache[obj]
    if cached and cached.Parent then
        return cached
    end
    
    local hitbox = nil
    local entityType = Helpers.GetEntityType(obj)
    
    -- ═══════════════════════════════════════════════
    -- 👤 PLAYER - prioridade: playerhitbox > HumanoidRootPart > Head
    -- ═══════════════════════════════════════════════
    if entityType == Helpers.EntityTypes.PLAYER then
        hitbox = obj:FindFirstChild("playerhitbox")
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Head")
            or obj:FindFirstChild("UpperTorso")
            or obj:FindFirstChild("Torso")
            or obj:FindFirstChildWhichIsA("BasePart")
    
    -- ═══════════════════════════════════════════════
    -- 🐷 ANIMAL/MOB - prioridade: Hitbox > PrimaryPart > Head
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.ANIMAL or entityType == Helpers.EntityTypes.MOB then
        hitbox = obj:FindFirstChild("Hitbox")
            or obj.PrimaryPart
            or obj:FindFirstChild("Head")
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChildWhichIsA("BasePart")
    
    -- ═══════════════════════════════════════════════
    -- 📦 ITEM - o próprio objeto ou primeira BasePart
    -- ═══════════════════════════════════════════════
    elseif entityType == Helpers.EntityTypes.ITEM then
        if obj:IsA("BasePart") then
            hitbox = obj
        elseif obj:IsA("Model") then
            hitbox = obj.PrimaryPart
                or obj:FindFirstChild("Handle")
                or obj:FindFirstChildWhichIsA("BasePart")
        end
    
    -- ═══════════════════════════════════════════════
    -- 🆘 FALLBACK GENÉRICO
    -- ═══════════════════════════════════════════════
    else
        if obj:IsA("BasePart") then
            hitbox = obj
        elseif obj:IsA("Model") then
            hitbox = obj.PrimaryPart
                or obj:FindFirstChild("Hitbox")
                or obj:FindFirstChild("HumanoidRootPart")
                or obj:FindFirstChildWhichIsA("BasePart")
        end
    end
    
    -- Cachear resultado
    if hitbox then
        Helpers._hitboxCache[obj] = hitbox
    end
    
    return hitbox
end

-- Limpar cache de hitbox para um objeto
function Helpers.ClearHitboxCache(obj)
    if obj then
        Helpers._hitboxCache[obj] = nil
        Helpers._entityTypeCache[obj] = nil
    else
        Helpers._hitboxCache = setmetatable({}, {__mode = "k"})
        Helpers._entityTypeCache = setmetatable({}, {__mode = "k"})
    end
end

-- ============================================================================
-- OFFSET INTELIGENTE PARA ESP
-- ============================================================================

function Helpers.GetSmartYOffset(hitbox, entityType)
    if not hitbox then return 2 end
    
    local sizeY = hitbox.Size.Y
    entityType = entityType or Helpers.GetEntityType(hitbox.Parent or hitbox)
    
    -- ═══════════════════════════════════════════════
    -- OFFSETS POR TIPO
    -- ═══════════════════════════════════════════════
    
    -- Players: offset maior para não cobrir a cabeça
    if entityType == Helpers.EntityTypes.PLAYER then
        return math.clamp(sizeY * 0.7 + 1, 2.5, 5)
    end
    
    -- Animais/Mobs: offset médio
    if entityType == Helpers.EntityTypes.ANIMAL or entityType == Helpers.EntityTypes.MOB then
        return math.clamp(sizeY * 0.6 + 0.5, 1.5, 6)
    end
    
    -- Items: offset pequeno
    if entityType == Helpers.EntityTypes.ITEM then
        return math.clamp(sizeY * 0.5 + 1, 1, 3)
    end
    
    -- Fallback genérico
    return math.clamp(sizeY * 0.6, 1.5, 5)
end

-- Versão antiga mantida para compatibilidade
function Helpers.GetYOffset(part)
    if not part then return 3 end
    return Helpers.GetSmartYOffset(part)
end

-- ============================================================================
-- FUNÇÕES ORIGINAIS (MANTIDAS E MELHORADAS)
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

-- Mantida para compatibilidade, usa GetHitbox internamente
function Helpers.GetPrimaryPart(model)
    if not model or not model:IsA("Model") then return nil end
    
    -- Usar GetHitbox para consistência
    local hitbox = Helpers.GetHitbox(model)
    if hitbox then return hitbox end
    
    -- Fallback original
    if model.PrimaryPart then 
        return model.PrimaryPart 
    end
    
    return model:FindFirstChild("Hitbox") 
        or model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")
end

-- ============================================================================
-- CRIAÇÃO DE UI ELEMENTS (MELHORADOS)
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
-- CRIAÇÃO COMPLETA DE ESP (NOVO)
-- ============================================================================

function Helpers.CreateESP(config)
    --[[
        config = {
            adornee = Part/Model (required),
            name = string,
            color = Color3,
            outlineColor = Color3,
            transparency = number,
            billboardSize = UDim2,
            billboardOffset = Vector3,
            showHighlight = boolean,
            showBillboard = boolean,
            parent = Instance (para billboard),
            highlightParent = Instance (para highlight),
        }
    ]]
    
    local adornee = config.adornee
    if not Helpers.IsValid(adornee) then return nil end
    
    local hitbox = Helpers.GetHitbox(adornee)
    if not hitbox then return nil end
    
    local esp = {
        adornee = adornee,
        hitbox = hitbox,
        highlight = nil,
        billboard = nil,
        frame = nil,
        label = nil,
    }
    
    local color = config.color or Color3.new(1, 1, 1)
    local outlineColor = config.outlineColor or color
    
    -- Criar Highlight
    if config.showHighlight ~= false then
        esp.highlight = Helpers.CreateHighlight(
            adornee,
            color,
            outlineColor,
            config.transparency or 0.5,
            config.highlightParent
        )
    end
    
    -- Criar Billboard
    if config.showBillboard ~= false then
        local offset = config.billboardOffset or Vector3.new(0, Helpers.GetSmartYOffset(hitbox), 0)
        
        esp.billboard = Helpers.CreateBillboard(
            hitbox,
            config.billboardSize or UDim2.fromOffset(120, 35),
            offset,
            config.parent
        )
        
        esp.frame = Helpers.CreateRoundedFrame(
            esp.billboard,
            Color3.fromRGB(20, 20, 20),
            0.3
        )
        
        -- Stroke colorido
        local stroke = Instance.new("UIStroke")
        stroke.Color = outlineColor
        stroke.Thickness = 2
        stroke.Parent = esp.frame
        
        esp.label = Helpers.CreateTextLabel(
            esp.frame,
            config.name or "ESP",
            color
        )
    end
    
    return esp
end

-- Destruir ESP completo
function Helpers.DestroyESP(esp)
    if not esp then return end
    
    Helpers.SafeDestroy(esp.billboard)
    Helpers.SafeDestroy(esp.highlight)
    
    -- Limpar referências
    esp.adornee = nil
    esp.hitbox = nil
    esp.billboard = nil
    esp.highlight = nil
    esp.frame = nil
    esp.label = nil
end

-- ============================================================================
-- VALIDAÇÃO E UTILIDADES
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

-- Versão mais robusta
function Helpers.IsValidModel(model)
    if not Helpers.IsValid(model) then return false end
    if not model:IsA("Model") then return false end
    
    -- Verificar se tem pelo menos uma parte
    local part = model:FindFirstChildWhichIsA("BasePart")
    return part ~= nil
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

function Helpers.FormatNumber(num)
    if not num then return "0" end
    
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    
    return string.format("%.0f", num)
end

-- ============================================================================
-- CORES POR SAÚDE
-- ============================================================================

function Helpers.GetHealthColor(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return Color3.new(1, 1, 1) -- Branco
    end
    
    local percent = math.clamp(health / maxHealth, 0, 1)
    
    -- Verde -> Amarelo -> Vermelho
    if percent > 0.5 then
        -- Verde para Amarelo (1.0 -> 0.5)
        local t = (percent - 0.5) * 2
        return Color3.new(1 - t, 1, 0)
    else
        -- Amarelo para Vermelho (0.5 -> 0.0)
        local t = percent * 2
        return Color3.new(1, t, 0)
    end
end

function Helpers.GetHealthEmoji(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return "❓"
    end
    
    local percent = health / maxHealth
    
    if percent > 0.75 then return "💚"
    elseif percent > 0.5 then return "💛"
    elseif percent > 0.25 then return "🧡"
    else return "❤️"
    end
end

-- ============================================================================
-- DISTÂNCIA E POSIÇÃO
-- ============================================================================

function Helpers.GetDistance(pos1, pos2)
    if not pos1 or not pos2 then return 9999 end
    return (pos1 - pos2).Magnitude
end

function Helpers.GetPosition(obj)
    if not Helpers.IsValid(obj) then return nil end
    
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local hitbox = Helpers.GetHitbox(obj)
        if hitbox then
            return hitbox.Position
        end
    end
    
    return nil
end

-- ============================================================================
-- UTILIDADES DE STRING
-- ============================================================================

function Helpers.Truncate(str, maxLen)
    if not str then return "" end
    maxLen = maxLen or 20
    
    if #str > maxLen then
        return string.sub(str, 1, maxLen - 3) .. "..."
    end
    
    return str
end

function Helpers.CleanName(name)
    if not name then return "Unknown" end
    
    -- Remover prefixos/sufixos comuns
    name = string.gsub(name, "Part", "")
    name = string.gsub(name, "Model", "")
    name = string.gsub(name, "Clone", "")
    name = string.gsub(name, "_", " ")
    name = string.gsub(name, "  +", " ") -- Múltiplos espaços
    name = string.match(name, "^%s*(.-)%s*$") -- Trim
    
    if #name == 0 then
        return "Unknown"
    end
    
    return name
end

-- ============================================================================
-- BATCH OPERATIONS
-- ============================================================================

function Helpers.DestroyMultiple(objects)
    if not objects then return 0 end
    
    local destroyed = 0
    for _, obj in ipairs(objects) do
        if Helpers.SafeDestroy(obj) then
            destroyed = destroyed + 1
        end
    end
    
    return destroyed
end

function Helpers.SetPropertySafe(instance, property, value)
    if not Helpers.IsValid(instance) then return false end
    
    local success = pcall(function()
        instance[property] = value
    end)
    
    return success
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.Helpers = Helpers

return Helpers