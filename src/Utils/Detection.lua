-- ============================================================================
-- DETECTION - Funções de detecção (mobs, itens, líquidos, etc.)
-- ============================================================================

local Constants = require("Core/Constants")

local Detection = {}

-- Verificar se model é um mob
function Detection.IsMob(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    return Constants.MOBS[model.Name:lower()] == true
end

-- Verificar se é um item (nome numérico = item dropado)
function Detection.IsItem(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    return tonumber(model.Name) ~= nil
end

-- Verificar se parte é líquido (água/lava)
function Detection.IsLiquidBlock(part)
    if not part or not part:IsA("BasePart") then 
        return false 
    end
    
    local name = part.Name
    
    -- Verificar keywords
    for _, keyword in ipairs(Constants.LIQUID_KEYWORDS) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end
    
    -- Verificar padrão numérico
    if string.match(name, "^%d+[TiFtF]?$") then
        return true
    end
    
    -- Verificar material
    if part.Material == Enum.Material.Water then
        return true
    end
    
    return false
end

-- Verificar se é player
function Detection.IsPlayer(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    
    local Players = game:GetService("Players")
    return Players:GetPlayerFromCharacter(model) ~= nil
end

-- Obter player de um character
function Detection.GetPlayerFromCharacter(model)
    if not model or not model:IsA("Model") then 
        return nil 
    end
    
    local Players = game:GetService("Players")
    return Players:GetPlayerFromCharacter(model)
end

-- Verificar se é o player local
function Detection.IsLocalPlayer(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    return localPlayer and localPlayer.Character == model
end

-- Verificar se parte tem decal de minério
function Detection.HasMineralDecal(part)
    if not part or not part:IsA("BasePart") then 
        return false, nil 
    end
    
    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("Decal") then
            for id, data in pairs(Constants.MINERALS) do
                if d.Texture:find(id) then
                    return true, data
                end
            end
        end
    end
    
    return false, nil
end

-- Obter melhor minério em uma parte
function Detection.GetBestMineral(part)
    if not part or not part:IsA("BasePart") then 
        return nil 
    end
    
    local best, bestPriority = nil, -1
    local maxPriority = 0
    
    -- Calcular prioridade máxima
    for _, data in pairs(Constants.MINERALS) do
        if data.priority > maxPriority then
            maxPriority = data.priority
        end
    end
    
    for _, d in ipairs(part:GetDescendants()) do
        if not d:IsA("Decal") then continue end
        
        local texture = d.Texture
        for id, data in pairs(Constants.MINERALS) do
            if texture:find(id) then
                if data.priority > bestPriority then
                    best = data
                    bestPriority = data.priority
                    
                    -- Se encontrou o melhor possível, retornar
                    if bestPriority >= maxPriority then
                        return best
                    end
                end
                break
            end
        end
    end
    
    return best
end

-- Verificar se parte tem decal invisível
function Detection.HasInvisibleDecal(part)
    if not part or not part:IsA("BasePart") then 
        return false 
    end
    
    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("Decal") and d.Texture:find(Constants.INVISIBLE_ID) then
            return true
        end
    end
    
    return false
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.Detection = Detection

return Detection