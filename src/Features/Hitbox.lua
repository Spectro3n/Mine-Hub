-- ============================================================================
-- HITBOX
-- ============================================================================

local Config = require("Core/Config")
local Helpers = require("Utils/Helpers")

local Hitbox = {
    _espCache = {},
    _originalSizes = {},
}

function Hitbox:CreateESP(part, color)
    if not part or not part:IsA("BasePart") then return end
    if self._espCache[part] then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Adornee = part
    box.Size = part.Size
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.6
    box.Color3 = color or Color3.fromRGB(255, 0, 0)
    box.Parent = part

    self._espCache[part] = box
end

function Hitbox:RemoveESP(part)
    if self._espCache[part] then
        Helpers.SafeDestroy(self._espCache[part])
        self._espCache[part] = nil
    end
end

function Hitbox:ClearAllESP()
    Helpers.SafeTableClear(self._espCache, function(_, box)
        Helpers.SafeDestroy(box)
    end)
end

function Hitbox:Expand(part)
    if not part or not part:IsA("BasePart") then return end
    if self._originalSizes[part] then return end
    
    self._originalSizes[part] = part.Size
    part.Size = Config.HitboxSize
    
    if self._espCache[part] then
        self._espCache[part].Size = Config.HitboxSize
    end
end

function Hitbox:Restore(part)
    if self._originalSizes[part] then
        if part and part.Parent then
            part.Size = self._originalSizes[part]
            if self._espCache[part] then
                self._espCache[part].Size = self._originalSizes[part]
            end
        end
        self._originalSizes[part] = nil
    end
end

function Hitbox:RestoreAll()
    Helpers.SafeTableClear(self._originalSizes, function(part, size)
        if part and part.Parent then
            part.Size = size
            if self._espCache[part] then
                self._espCache[part].Size = size
            end
        end
    end)
end

function Hitbox:UpdateSize(newSize)
    Config.HitboxSize = newSize
    for part in pairs(self._originalSizes) do
        if part and part.Parent then
            part.Size = newSize
            if self._espCache[part] then
                self._espCache[part].Size = newSize
            end
        end
    end
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.Hitbox = Hitbox

return Hitbox