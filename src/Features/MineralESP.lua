-- ============================================================================
-- MINERAL ESP - Sistema de detecção de minerais
-- ============================================================================

local MineralESP = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local Cache = require(script.Parent.Parent.Engine.Cache)
local ObjectPool = require(script.Parent.Parent.Engine.ObjectPool)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)
local Helpers = require(script.Parent.Parent.Utils.Helpers)

-- Lookup table para performance
local MINERAL_LOOKUP = {}
local MAX_PRIORITY = 0

for id, data in pairs(Constants.MINERALS) do
    MINERAL_LOOKUP[id] = data
    if data.priority > MAX_PRIORITY then
        MAX_PRIORITY = data.priority
    end
end

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function getBestMineral(part)
    if Cache.MineralResults[part] then
        return Cache.MineralResults[part]
    end
    
    local best, bestPriority = nil, -1
    
    for _, d in ipairs(part:GetDescendants()) do
        if not d:IsA("Decal") then continue end
        
        local texture = d.Texture
        for id, data in pairs(MINERAL_LOOKUP) do
            if texture:find(id) then
                if data.priority > bestPriority then
                    best = data
                    bestPriority = data.priority
                    
                    if bestPriority >= MAX_PRIORITY then
                        Cache.MineralResults[part] = best
                        return best
                    end
                end
                break
            end
        end
    end
    
    Cache.MineralResults[part] = best
    return best
end

local function createHighlight(part, color)
    if Cache.Highlights[part] then return end

    local hl = Instance.new("Highlight")
    hl.Name = "MineralHighlight"
    hl.Adornee = part
    hl.Parent = part
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.FillColor = color
    hl.OutlineColor = color
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    Cache.Highlights[part] = hl
end

local function createBillboard(part, mineralData)
    if Cache.Billboards[part] then return end

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

    Cache.Billboards[part] = bb
end

local function applyInvisible(part)
    if Cache.Parts[part] then return end

    Cache.Parts[part] = part.LocalTransparencyModifier
    part.LocalTransparencyModifier = 1

    for _, d in ipairs(part:GetDescendants()) do
        if Helpers.MatchDecal(d, Constants.INVISIBLE_ID) then
            Cache.Decals[d] = d.Transparency
            d.Transparency = 1
        end
    end

    ConnectionManager:Add("invisible_" .. tostring(part:GetDebugId()), part.ChildAdded:Connect(function(child)
        if not Config.Enabled then return end
        task.defer(function()
            if Helpers.MatchDecal(child, Constants.INVISIBLE_ID) then
                Cache.Decals[child] = child.Transparency
                child.Transparency = 1
            end

            for id, data in pairs(Constants.MINERALS) do
                if Helpers.MatchDecal(child, id) then
                    if Config.ShowHighlight then
                        createHighlight(part, data.color)
                    end
                    if Config.ShowBillboard then
                        createBillboard(part, data)
                    end
                    break
                end
            end
        end)
    end), "minerals")
end

local function processPart(part)
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
        applyInvisible(part)
    end

    if mineral then
        if Config.ShowHighlight then
            createHighlight(part, mineral.color)
        end
        if Config.ShowBillboard then
            createBillboard(part, mineral)
        end
    end
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function MineralESP:Enable()
    for _, obj in ipairs(workspace:GetDescendants()) do
        processPart(obj)
    end

    ConnectionManager:Add("mineralDescendant", workspace.DescendantAdded:Connect(function(obj)
        if not Config.Enabled then return end
        task.defer(function()
            processPart(obj)
        end)
    end), "minerals")
    
    print("✅ Mineral ESP Ativado")
end

function MineralESP:Disable()
    -- Restaurar transparências
    Cache:SafeTableClear(Cache.Parts, function(part, oldValue)
        if part and part.Parent then
            part.LocalTransparencyModifier = oldValue
        end
    end)

    Cache:SafeTableClear(Cache.Decals, function(decal, oldValue)
        if decal and decal.Parent then
            decal.Transparency = oldValue
        end
    end)

    Cache:SafeTableClear(Cache.Highlights, function(_, hl)
        if hl and hl.Parent then
            hl:Destroy()
        end
    end)

    Cache:SafeTableClear(Cache.Billboards, function(_, bb)
        if bb then
            ObjectPool:Return("BillboardGui", bb)
        end
    end)
    
    Cache.MineralResults = setmetatable({}, {__mode = "k"})
    ConnectionManager:RemoveCategory("minerals")
    
    print("❌ Mineral ESP Desativado")
end

function MineralESP:Toggle()
    if Config.SafeMode then
        warn("🛑 Safe Mode ativo - desative primeiro!")
        return false
    end
    
    Config.Enabled = not Config.Enabled

    if Config.Enabled then
        self:Enable()
    else
        self:Disable()
    end
    
    return Config.Enabled
end

return MineralESP