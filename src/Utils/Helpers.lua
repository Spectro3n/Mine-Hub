-- ============================================================================
-- HELPERS - Funções utilitárias gerais
-- ============================================================================

local Helpers = {}

function Helpers.MatchDecal(decal, id)
    return decal:IsA("Decal") and decal.Texture:find(id)
end

function Helpers.GetHumanoid(model)
    return model:FindFirstChildOfClass("Humanoid")
end

function Helpers.GetPrimaryPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    return model:FindFirstChild("Hitbox") 
        or model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("Head")
end

function Helpers.GetYOffset(part)
    if not part then return 3 end
    return (part.Size.Y / 2) + 1.5
end

function Helpers.SafeTableClear(tbl, cleanupFunc)
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

return Helpers