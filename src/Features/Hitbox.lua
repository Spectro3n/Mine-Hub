-- ============================================================================
-- HITBOX - Visualização e expansão de hitboxes
-- ============================================================================

local Hitbox = {}

local Config = require(script.Parent.Parent.Core.Config)
local Cache = require(script.Parent.Parent.Engine.Cache)
local Helpers = require(script.Parent.Parent.Utils.Helpers)

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function createHitboxESP(part, color)
    if Cache.HitboxESP[part] then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Adornee = part
    box.Size = part.Size
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.6
    box.Color3 = color
    box.Parent = part

    Cache.HitboxESP[part] = box
end

local function removeHitboxESP(part)
    if Cache.HitboxESP[part] then
        Cache.HitboxESP[part]:Destroy()
        Cache.HitboxESP[part] = nil
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function Hitbox:CreateESP(model, color)
    if not Config.ShowHitboxESP then return end
    
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        createHitboxESP(root, color or Color3.fromRGB(255, 0, 0))
    end
end

function Hitbox:RemoveESP(model)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        removeHitboxESP(root)
    end
end

function Hitbox:Expand(part)
    if Cache.OriginalSizes[part] then return end
    if not part or not part.Parent then return end
    Cache.OriginalSizes[part] = part.Size
    part.Size = Config.HitboxSize
end

function Hitbox:Restore(part)
    if Cache.OriginalSizes[part] then
        if part and part.Parent then
            part.Size = Cache.OriginalSizes[part]
        end
        Cache.OriginalSizes[part] = nil
    end
end

function Hitbox:RestoreAll()
    Helpers.SafeTableClear(Cache.OriginalSizes, function(part, size)
        if part and part.Parent then
            part.Size = size
        end
    end)
end

function Hitbox:ClearAllESP()
    Helpers.SafeTableClear(Cache.HitboxESP, function(_, box)
        if box and box.Parent then
            box:Destroy()
        end
    end)
end

function Hitbox:ExpandPlayer(player)
    if not Config.ExpandHitbox then return end
    
    local char = player.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        self:Expand(root)
    end
end

function Hitbox:RestorePlayer(player)
    local char = player.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        self:Restore(root)
    end
end

return Hitbox