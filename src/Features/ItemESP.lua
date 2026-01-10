-- ============================================================================
-- ITEM ESP - ESP para itens no chão
-- ============================================================================

local ItemESP = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local Cache = require(script.Parent.Parent.Engine.Cache)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Detection = require(script.Parent.Parent.Utils.Detection)

local RunService = Constants.Services.RunService

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function createItemESP(model)
    if not Config.ItemESP then return end
    if Cache.ItemESP[model] then return end
    if not Detection.IsItem(model) then return end

    local part = Helpers.GetPrimaryPart(model)
    if not part then return end

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "ItemESP"
    hl.FillColor = Color3.fromRGB(255, 255, 100)
    hl.OutlineColor = Color3.fromRGB(255, 200, 0)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model
    hl.Parent = model

    -- Billboard
    local bb = Instance.new("BillboardGui")
    bb.Name = "ItemBillboard"
    bb.Adornee = part
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(100, 30)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.Parent = part

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 0)
    stroke.Thickness = 2
    stroke.Parent = frame

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextScaled = true
    text.TextColor3 = Color3.fromRGB(255, 255, 100)
    text.Text = "📦 Item"
    text.Parent = frame

    -- Atualizar distância
    local updateId = "item_" .. tostring(model:GetDebugId())
    ConnectionManager:Add(updateId, RunService.Heartbeat:Connect(function()
        if not model or not model.Parent then
            ConnectionManager:Remove(updateId)
            ItemESP:Remove(model)
            return
        end
        
        local dist = Cache:GetDistanceFromCamera(part.Position)
        text.Text = string.format("📦 Item (%.0fm)", dist)
    end), "itemESP")

    Cache.ItemESP[model] = {
        highlight = hl,
        billboard = bb,
        updateId = updateId
    }
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function ItemESP:Initialize()
    -- Escanear itens existentes
    local entitiesFolder = workspace:FindFirstChild("Entities")
    if entitiesFolder then
        for _, model in ipairs(entitiesFolder:GetChildren()) do
            if Detection.IsItem(model) then
                createItemESP(model)
            end
        end
    end
    
    -- Monitorar novos itens
    ConnectionManager:Add("itemAdded", workspace.DescendantAdded:Connect(function(obj)
        if not Config.ItemESP then return end
        if obj:IsA("Model") and Detection.IsItem(obj) then
            task.defer(function()
                createItemESP(obj)
            end)
        end
    end), "itemESP")
    
    print("✅ ItemESP inicializado!")
end

function ItemESP:Remove(model)
    if Cache.ItemESP[model] then
        if Cache.ItemESP[model].highlight then
            Cache.ItemESP[model].highlight:Destroy()
        end
        if Cache.ItemESP[model].billboard then
            Cache.ItemESP[model].billboard:Destroy()
        end
        if Cache.ItemESP[model].updateId then
            ConnectionManager:Remove(Cache.ItemESP[model].updateId)
        end
        Cache.ItemESP[model] = nil
    end
end

function ItemESP:Clear()
    Helpers.SafeTableClear(Cache.ItemESP, function(model, data)
        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end
        if data.billboard and data.billboard.Parent then
            data.billboard:Destroy()
        end
        if data.updateId then
            ConnectionManager:Remove(data.updateId)
        end
    end)
end

function ItemESP:Cleanup()
    for model in pairs(Cache.ItemESP) do
        if not model or not model.Parent then
            self:Remove(model)
        end
    end
end

return ItemESP