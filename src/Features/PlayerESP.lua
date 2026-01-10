-- ============================================================================
-- PLAYER ESP
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")
local Hitbox = require("Features/Hitbox")

local PlayerESP = {
    _cache = {},
}

local localPlayer = Players.LocalPlayer

function PlayerESP:Create(plr)
    if not Config.PlayerESP then return end
    if plr == localPlayer then return end
    if self._cache[plr] then return end
    
    local char = plr.Character
    if not char then return end
    
    local part = Helpers.GetPrimaryPart(char)
    if not part then return end
    
    local hl = Helpers.CreateHighlight(char, Constants.COLORS.PLAYER, Constants.COLORS.PLAYER_OUTLINE, 0.5)
    hl.Name = "PlayerESP"
    
    local bb = Helpers.CreateBillboard(part, UDim2.fromOffset(160, 40), Vector3.new(0, Helpers.GetYOffset(part), 0))
    bb.Name = "PlayerESP"
    
    local frame = Helpers.CreateRoundedFrame(bb, Color3.fromRGB(15, 15, 15), 0.2)
    local label = Helpers.CreateTextLabel(frame, plr.Name .. " | ??? ❤", Color3.new(1, 1, 1))
    
    local updateId = "playerESP_" .. plr.UserId
    ConnectionManager:Add(updateId, RunService.Heartbeat:Connect(function()
        if not plr.Parent or not char or not char.Parent then
            ConnectionManager:Remove(updateId)
            self:Remove(plr)
            return
        end
        
        local currentPart = Helpers.GetPrimaryPart(char)
        if not currentPart then return end
        
        local dist = Cache:GetDistanceFromCamera(currentPart.Position)
        local healthData = Cache:GetRealHealth(char)
        
        if healthData then
            local healthText = Helpers.FormatHealth(healthData.health, healthData.maxHealth)
            label.Text = string.format("%s | %s ❤ | %s", plr.Name, healthText, Helpers.FormatDistance(dist))
            
            local percent = healthData.maxHealth > 0 and (healthData.health / healthData.maxHealth) or 1
            if percent <= 0.25 then
                label.TextColor3 = Constants.COLORS.HEALTH_LOW
            elseif percent <= 0.5 then
                label.TextColor3 = Constants.COLORS.HEALTH_MID
            else
                label.TextColor3 = Constants.COLORS.HEALTH_HIGH
            end
        else
            label.Text = string.format("%s | %s", plr.Name, Helpers.FormatDistance(dist))
        end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and Config.ShowHitboxESP then
            Hitbox:CreateESP(hrp, Constants.COLORS.PLAYER)
        end
        
        if hrp and Config.ExpandHitbox then
            Hitbox:Expand(hrp)
        end
    end), "playerESP")
    
    self._cache[plr] = {
        billboard = bb,
        highlight = hl,
        healthLabel = label,
        updateId = updateId
    }
end

function PlayerESP:Remove(plr)
    local data = self._cache[plr]
    if not data then return end
    
    Helpers.SafeDestroy(data.billboard)
    Helpers.SafeDestroy(data.highlight)
    
    if data.updateId then
        ConnectionManager:Remove(data.updateId)
    end
    
    local char = plr.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            Hitbox:RemoveESP(hrp)
            Hitbox:Restore(hrp)
        end
    end
    
    self._cache[plr] = nil
end

function PlayerESP:Update(plr, health, maxHealth)
    if not self._cache[plr] then
        self:Create(plr)
    end
    
    local char = plr.Character
    if char then
        Cache:SetRealHealth(char, health, maxHealth)
    end
end

function PlayerESP:ClearAll()
    local players = {}
    for plr in pairs(self._cache) do
        table.insert(players, plr)
    end
    for _, plr in ipairs(players) do
        self:Remove(plr)
    end
end

function PlayerESP:Refresh()
    self:ClearAll()
    if not Config.PlayerESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            self:Create(plr)
        end
    end
end

function PlayerESP:GetCount()
    local count = 0
    for _ in pairs(self._cache) do
        count = count + 1
    end
    return count
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.PlayerESP = PlayerESP

return PlayerESP