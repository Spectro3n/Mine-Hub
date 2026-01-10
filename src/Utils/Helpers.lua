-- ============================================================================
-- HELPERS - Funções utilitárias
-- ============================================================================

local Helpers = {}

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
    
    if model.PrimaryPart then 
        return model.PrimaryPart 
    end
    
    return model:FindFirstChild("Hitbox") 
        or model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("Head")
        or model:FindFirstChildWhichIsA("BasePart")
end

function Helpers.GetYOffset(part)
    if not part then return 3 end
    return (part.Size.Y / 2) + 1.5
end

function Helpers.CreateBillboard(adornee, size, offset)
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = size or UDim2.fromOffset(100, 30)
    bb.StudsOffset = offset or Vector3.new(0, 2, 0)
    bb.Adornee = adornee
    bb.Parent = adornee
    return bb
end

function Helpers.CreateHighlight(adornee, fillColor, outlineColor, fillTransparency)
    local hl = Instance.new("Highlight")
    hl.FillColor = fillColor or Color3.new(1, 1, 1)
    hl.OutlineColor = outlineColor or fillColor or Color3.new(1, 1, 1)
    hl.FillTransparency = fillTransparency or 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = adornee
    hl.Parent = adornee
    return hl
end

function Helpers.CreateRoundedFrame(parent, backgroundColor, transparency, cornerRadius)
    local frame = Instance.new("Frame")
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
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text or ""
    label.TextColor3 = textColor or Color3.new(1, 1, 1)
    label.Font = font or Enum.Font.GothamBold
    label.TextSize = textSize or 14
    label.TextScaled = textSize == nil
    label.Parent = parent
    return label
end

function Helpers.SafeDestroy(obj)
    if obj and typeof(obj) == "Instance" then
        pcall(function()
            obj:Destroy()
        end)
    end
end

function Helpers.IsValid(instance)
    return instance and typeof(instance) == "Instance" and instance.Parent ~= nil
end

function Helpers.FormatDistance(distance)
    return string.format("%.0fm", distance)
end

function Helpers.FormatHealth(health, maxHealth)
    if maxHealth and maxHealth > 0 then
        return string.format("%.0f/%.0f", health, maxHealth)
    end
    return string.format("%.0f", health)
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.Helpers = Helpers

return Helpers