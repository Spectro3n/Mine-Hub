-- ============================================================================
-- MINERAL ESP - ESP principal para minérios
-- ============================================================================

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local ObjectPool = require("Engine/ObjectPool")
local Helpers = require("Utils/Helpers")
local Detection = require("Utils/Detection")
local Notifications = require("UI/Notifications")

local MineralESP = {
    _partCache = {},       -- part -> originalTransparency
    _decalCache = {},      -- decal -> originalTransparency
    _highlightCache = {},  -- part -> Highlight
    _billboardCache = {},  -- part -> BillboardGui
}

function MineralESP:CreateHighlight(part, color)
    if self._highlightCache[part] then return end

    local hl = Instance.new("Highlight")
    hl.Name = "MineralHighlight"
    hl.Adornee = part
    hl.Parent = part
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.FillColor = color
    hl.OutlineColor = color
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    self._highlightCache[part] = hl
end

function MineralESP:CreateBillboard(part, mineralData)
    if self._billboardCache[part] then return end

    local bb = ObjectPool:Get("BillboardGui")
    bb.Name = "MineralBillboard"
    bb.Size = UDim2.fromOffset(100, 30)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = part
    bb.Parent = part

    local frame = bb:FindFirstChild("Frame")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name = "Frame"
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = bb

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
    end

    local stroke = frame:FindFirstChild("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Name = "UIStroke"
        stroke.Thickness = 2
        stroke.Parent = frame
    end
    stroke.Color = mineralData.color

    local lbl = frame:FindFirstChild("Label")
    if not lbl then
        lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = frame
    end
    lbl.Text = "⛏️ " .. mineralData.name
    lbl.TextColor3 = mineralData.color

    self._billboardCache[part] = bb
end

function MineralESP:ApplyInvisible(part)
    if self._partCache[part] then return end

    self._partCache[part] = part.LocalTransparencyModifier
    part.LocalTransparencyModifier = 1

    for _, d in ipairs(part:GetDescendants()) do
        if Helpers.MatchDecal(d, Constants.INVISIBLE_ID) then
            self._decalCache[d] = d.Transparency
            d.Transparency = 1
        end
    end

    -- Observar novos decals
    local connId = "invisible_" .. tostring(part:GetDebugId())
    ConnectionManager:Add(connId, part.ChildAdded:Connect(function(child)
        if not Config.Enabled then return end
        task.defer(function()
            if Helpers.MatchDecal(child, Constants.INVISIBLE_ID) then
                self._decalCache[child] = child.Transparency
                child.Transparency = 1
            end

            -- Verificar se é mineral
            for id, data in pairs(Constants.MINERALS) do
                if Helpers.MatchDecal(child, id) then
                    if Config.ShowHighlight then
                        self:CreateHighlight(part, data.color)
                    end
                    if Config.ShowBillboard then
                        self:CreateBillboard(part, data)
                    end
                    break
                end
            end
        end)
    end), "minerals")
end

function MineralESP:ProcessPart(part)
    if not part:IsA("BasePart") then return end

    local hasInvisible = false
    local mineral = nil

    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("Decal") then
            if d.Texture:find(Constants.INVISIBLE_ID) then
                hasInvisible = true
            end

            for id, data in pairs(Constants.MINERALS) do
                if d.Texture:find(id) then
                    if not mineral or data.priority > mineral.priority then
                        mineral = data
                    end
                end
            end
        end
    end

    if hasInvisible and Config.MakeInvisible then
        self:ApplyInvisible(part)
    end

    if mineral then
        if Config.ShowHighlight then
            self:CreateHighlight(part, mineral.color)
        end
        if Config.ShowBillboard then
            self:CreateBillboard(part, mineral)
        end
    end
end

function MineralESP:RestoreAll()
    -- Restaurar transparência das partes
    Helpers.SafeTableClear(self._partCache, function(part, oldValue)
        if part and part.Parent then
            part.LocalTransparencyModifier = oldValue
        end
    end)

    -- Restaurar transparência dos decals
    Helpers.SafeTableClear(self._decalCache, function(decal, oldValue)
        if decal and decal.Parent then
            decal.Transparency = oldValue
        end
    end)

    -- Destruir highlights
    Helpers.SafeTableClear(self._highlightCache, function(_, hl)
        Helpers.SafeDestroy(hl)
    end)

    -- Devolver billboards ao pool
    Helpers.SafeTableClear(self._billboardCache, function(_, bb)
        if bb then
            ObjectPool:Return("BillboardGui", bb)
        end
    end)
    
    -- Limpar cache de resultados
    Cache:ClearMineralResults()
    
    -- Remover conexões
    ConnectionManager:RemoveCategory("minerals")
end

function MineralESP:Enable()
    for _, obj in ipairs(workspace:GetDescendants()) do
        self:ProcessPart(obj)
    end

    ConnectionManager:Add("mineralDescendant", workspace.DescendantAdded:Connect(function(obj)
        if not Config.Enabled then return end
        task.defer(function()
            self:ProcessPart(obj)
        end)
    end), "minerals")
end

function MineralESP:Disable()
    self:RestoreAll()
end

function MineralESP:Toggle()
    if Config.SafeMode then
        Notifications:Send("🛑 Safe Mode", "Desative o Safe Mode primeiro!", 2)
        return
    end
    
    Config.Enabled = not Config.Enabled

    if Config.Enabled then
        self:Enable()
        print("✅ Mineral ESP ACTIVATED")
    else
        self:Disable()
        print("❌ Mineral ESP DEACTIVATED")
    end

    Notifications:Send(
        "⛏️ Mineral ESP",
        Config.Enabled and "✅ Activated" or "❌ Deactivated",
        2
    )
end

function MineralESP:Refresh()
    if Config.Enabled then
        self:Disable()
        self:Enable()
    end
end

function MineralESP:GetStats()
    local highlightCount = 0
    local billboardCount = 0
    
    for _ in pairs(self._highlightCache) do
        highlightCount = highlightCount + 1
    end
    
    for _ in pairs(self._billboardCache) do
        billboardCount = billboardCount + 1
    end
    
    return {
        highlights = highlightCount,
        billboards = billboardCount,
        partsProcessed = highlightCount + billboardCount
    }
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.MineralESP = MineralESP

return MineralESP