-- ============================================================================
-- DETECTION - Funções de detecção
-- ============================================================================

local Constants = require("Core/Constants")

local Detection = {}

function Detection.IsMob(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    local name = string.lower(model.Name)
    return Constants.MOBS[name] == true
end

function Detection.IsItem(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    return tonumber(model.Name) ~= nil
end

function Detection.IsLiquidBlock(part)
    if not part or not part:IsA("BasePart") then 
        return false 
    end
    
    local name = part.Name
    
    for _, keyword in ipairs(Constants.LIQUID_KEYWORDS) do
        if string.find(name, keyword, 1, true) then
            return true
        end
    end
    
    if string.match(name, "^%d+[TiFtF]?$") then
        return true
    end
    
    if part.Material == Enum.Material.Water then
        return true
    end
    
    return false
end

function Detection.IsPlayer(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    
    local Players = game:GetService("Players")
    return Players:GetPlayerFromCharacter(model) ~= nil
end

function Detection.GetPlayerFromCharacter(model)
    if not model or not model:IsA("Model") then 
        return nil 
    end
    
    local Players = game:GetService("Players")
    return Players:GetPlayerFromCharacter(model)
end

function Detection.IsLocalPlayer(model)
    if not model or not model:IsA("Model") then 
        return false 
    end
    
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    return localPlayer and localPlayer.Character == model
end

function Detection.GetBestMineral(part)
    if not part or not part:IsA("BasePart") then 
        return nil 
    end
    
    local best, bestPriority = nil, -1
    
    for _, d in ipairs(part:GetDescendants()) do
        if not d:IsA("Decal") then continue end
        
        local texture = d.Texture
        if not texture then continue end
        
        for id, data in pairs(Constants.MINERALS) do
            if string.find(texture, id, 1, true) then
                if data.priority > bestPriority then
                    best = data
                    bestPriority = data.priority
                end
                break
            end
        end
    end
    
    return best
end

function Detection.HasInvisibleDecal(part)
    if not part or not part:IsA("BasePart") then 
        return false 
    end
    
    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("Decal") and d.Texture and string.find(d.Texture, Constants.INVISIBLE_ID, 1, true) then
            return true
        end
    end
    
    return false
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.Detection = Detection

return Detection