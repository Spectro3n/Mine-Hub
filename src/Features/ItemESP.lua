-- ============================================================================
-- ITEM ESP - ESP para itens no chão
-- ============================================================================

local RunService = game:GetService("RunService")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")
local Detection = require("Utils/Detection")

local ItemESP = {
    _cache = {},  -- model -> {billboard, highlight, updateId}
}

function ItemESP:Create(model)
    if not Config.ItemESP then return end
    if not Detection.IsItem(model) then return end
    if self._cache[model] then return end
    
    local part = Helpers.GetPrimaryPart(model)
    if not part then return end
    
    -- Highlight
    local hl = Helpers.CreateHighlight(
        model,
        Constants.COLORS.ITEM,
        Constants.COLORS.ITEM_OUTLINE,
        0.6
    )
    hl.Name = "ItemESP"
    
    -- Billboard
    local bb = Helpers.CreateBillboard(
        part,
        UDim2.fromOffset(100, 30),
        Vector3.new(0, 2, 0)
    )
    bb.Name = "ItemBillboard"
    
    local frame = Helpers.CreateRoundedFrame(bb, Color3.fromRGB(40, 40, 0), 0.3)
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Constants.COLORS.ITEM_OUTLINE
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local label = Helpers.CreateTextLabel(frame, "📦 Item", Constants.COLORS.ITEM)
    
    -- Connection para atualização
    local updateId = "itemESP_" .. tostring(model:GetDebugId())
    ConnectionManager:Add(updateId, RunService.Heartbeat:Connect(function()
        if not model or not model.Parent then
            ConnectionManager:Remove(updateId)
            self:Remove(model)
            return
        end
        
        local currentPart = Helpers.GetPrimaryPart(model)
        if not currentPart then return end
        
        local dist = Cache:GetDistanceFromCamera(currentPart.Position)
        label.Text = string.format("📦 Item (%s)", Helpers.FormatDistance(dist))
    end), "itemESP")
    
    self._cache[model] = {
        billboard = bb,
        highlight = hl,
        updateId = updateId
    }
end

function ItemESP:Remove(model)
    local data = self._cache[model]
    if not data then return end
    
    Helpers.SafeDestroy(data.billboard)
    Helpers.SafeDestroy(data.highlight)
    
    if data.updateId then
        ConnectionManager:Remove(data.updateId)
    end
    
    self._cache[model] = nil
end

function ItemESP:ClearAll()
    local models = {}
    for model in pairs(self._cache) do
        table.insert(models, model)
    end
    
    for _, model in ipairs(models) do
        self:Remove(model)
    end
end

function ItemESP:GetCount()
    local count = 0
    for _ in pairs(self._cache) do
        count = count + 1
    end
    return count
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.ItemESP = ItemESP

return ItemESP