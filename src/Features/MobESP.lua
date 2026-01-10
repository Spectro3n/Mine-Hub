-- ============================================================================
-- MOB ESP - ESP para mobs/entidades
-- ============================================================================

local RunService = game:GetService("RunService")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")
local Detection = require("Utils/Detection")
local Hitbox = require("Features/Hitbox")

local MobESP = {
    _cache = {},  -- model -> {billboard, highlight, healthLabel, updateId}
}

function MobESP:Create(model, name)
    if not Config.MobESP then return end
    if not model or not model:IsA("Model") then return end
    if self._cache[model] then return end
    
    local part = Helpers.GetPrimaryPart(model)
    if not part then return end
    
    name = name or model.Name
    
    -- Highlight
    local hl = Helpers.CreateHighlight(
        model,
        Constants.COLORS.MOB,
        Constants.COLORS.MOB_OUTLINE,
        0.5
    )
    hl.Name = "MobESP"
    
    -- Billboard
    local bb = Helpers.CreateBillboard(
        part,
        UDim2.fromOffset(160, 40),
        Vector3.new(0, Helpers.GetYOffset(part), 0)
    )
    bb.Name = "MobESP"
    
    local frame = Helpers.CreateRoundedFrame(bb, Color3.fromRGB(15, 15, 15), 0.2)
    local label = Helpers.CreateTextLabel(frame, name .. " | ??? ❤", Color3.new(1, 1, 1))
    
    -- Connection para atualização
    local updateId = "mobESP_" .. tostring(model:GetDebugId())
    ConnectionManager:Add(updateId, RunService.Heartbeat:Connect(function()
        if not model or not model.Parent then
            ConnectionManager:Remove(updateId)
            self:Remove(model)
            return
        end
        
        local currentPart = Helpers.GetPrimaryPart(model)
        if not currentPart then return end
        
        -- Atualizar distância
        local dist = Cache:GetDistanceFromCamera(currentPart.Position)
        local healthData = Cache:GetRealHealth(model)
        
        if healthData then
            local healthText = Helpers.FormatHealth(healthData.health, healthData.maxHealth)
            label.Text = string.format("%s | %s ❤ | %s", name, healthText, Helpers.FormatDistance(dist))
            
            -- Cor baseada na vida
            local percent = healthData.maxHealth > 0 and (healthData.health / healthData.maxHealth) or 1
            if percent <= 0.25 then
                label.TextColor3 = Constants.COLORS.HEALTH_LOW
            elseif percent <= 0.5 then
                label.TextColor3 = Constants.COLORS.HEALTH_MID
            else
                label.TextColor3 = Constants.COLORS.HEALTH_HIGH
            end
        else
            label.Text = string.format("%s | %s", name, Helpers.FormatDistance(dist))
        end
        
        -- Hitbox ESP
        local hitbox = model:FindFirstChild("Hitbox") or currentPart
        if hitbox and Config.ShowHitboxESP then
            Hitbox:CreateESP(hitbox, Constants.COLORS.MOB)
        end
        
        -- Expandir hitbox
        if hitbox and Config.ExpandHitbox then
            Hitbox:Expand(hitbox)
        end
    end), "mobESP")
    
    self._cache[model] = {
        billboard = bb,
        highlight = hl,
        healthLabel = label,
        name = name,
        updateId = updateId
    }
end

function MobESP:Remove(model)
    local data = self._cache[model]
    if not data then return end
    
    Helpers.SafeDestroy(data.billboard)
    Helpers.SafeDestroy(data.highlight)
    
    if data.updateId then
        ConnectionManager:Remove(data.updateId)
    end
    
    -- Remover hitbox ESP e restaurar tamanho
    if model and model.Parent then
        local hitbox = model:FindFirstChild("Hitbox") or Helpers.GetPrimaryPart(model)
        if hitbox then
            Hitbox:RemoveESP(hitbox)
            Hitbox:Restore(hitbox)
        end
    end
    
    self._cache[model] = nil
end

function MobESP:Update(model, health, maxHealth, name)
    if not self._cache[model] then
        self:Create(model, name)
    end
    
    Cache:SetRealHealth(model, health, maxHealth)
end

function MobESP:ClearAll()
    local models = {}
    for model in pairs(self._cache) do
        table.insert(models, model)
    end
    
    for _, model in ipairs(models) do
        self:Remove(model)
    end
end

function MobESP:GetCount()
    local count = 0
    for _ in pairs(self._cache) do
        count = count + 1
    end
    return count
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.MobESP = MobESP

return MobESP