-- ============================================================================
-- DETECTION - Funções de detecção de entidades
-- ============================================================================

local Constants = require(script.Parent.Parent.Core.Constants)

local Detection = {}

function Detection.IsMob(model)
    if not model or not model:IsA("Model") then return false end
    return Constants.MOBS[model.Name:lower()] == true
end

function Detection.IsItem(model)
    return tonumber(model.Name) ~= nil
end

function Detection.IsLiquidBlock(part)
    if not part or not part:IsA("BasePart") then return false end
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

return Detection