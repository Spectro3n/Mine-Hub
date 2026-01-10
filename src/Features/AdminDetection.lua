-- ============================================================================
-- ADMIN DETECTION - Detecção e ESP de administradores
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Cache = require("Engine/Cache")
local ConnectionManager = require("Engine/ConnectionManager")
local Helpers = require("Utils/Helpers")
local Notifications = require("UI/Notifications")

local AdminDetection = {
    _espCache = {},      -- player -> {highlight, billboard, conn, charConn}
    _adminsOnline = {},  -- player -> true
    _remote = nil,
}

local localPlayer = Players.LocalPlayer

function AdminDetection:Init()
    self._remote = ReplicatedStorage:FindFirstChild("Admins")
end

function AdminDetection:GetAdminsInServer()
    if not self._remote or not self._remote:IsA("RemoteFunction") then
        return {}
    end

    local ok, result = pcall(function()
        return self._remote:InvokeServer()
    end)

    if not ok or typeof(result) ~= "table" then
        return {}
    end

    local playersById = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        playersById[plr.UserId] = plr
    end

    local admins = {}
    for _, userId in ipairs(result) do
        local uid = tonumber(userId)
        if uid and playersById[uid] then
            table.insert(admins, playersById[uid])
        end
    end

    return admins
end

function AdminDetection:CreateESP(player)
    if not Config.ShowAdminESP then return end
    if Config.SafeMode then return end
    if self._espCache[player] then return end
    if player == localPlayer then return end

    local function apply(char)
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end

        -- Limpar ESP anterior
        if self._espCache[player] then
            Helpers.SafeDestroy(self._espCache[player].hl)
            Helpers.SafeDestroy(self._espCache[player].bb)
            if self._espCache[player].conn then
                self._espCache[player].conn:Disconnect()
            end
        end

        -- Highlight
        local hl = Helpers.CreateHighlight(
            char,
            Constants.COLORS.ADMIN,
            Constants.COLORS.ADMIN_OUTLINE,
            0.25
        )
        hl.Name = "AdminESP"

        -- Billboard
        local bb = Instance.new("BillboardGui")
        bb.Name = "AdminBillboard"
        bb.Size = UDim2.fromOffset(180, 60)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = hrp

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.Parent = bb

        local conn = RunService.RenderStepped:Connect(function()
            if not player.Parent or not player.Character then
                conn:Disconnect()
                return
            end
            local dist = Cache:GetDistanceFromCamera(hrp.Position)
            lbl.Text = string.format("⚠️ ADMIN ⚠️\n👑 %s\n📏 %s", player.Name, Helpers.FormatDistance(dist))
        end)

        self._espCache[player] = {
            hl = hl,
            bb = bb,
            conn = conn
        }
    end

    self._espCache[player] = {}
    
    local charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        apply(char)
    end)
    self._espCache[player].charConn = charConn

    if player.Character then
        apply(player.Character)
    end
end

function AdminDetection:RemoveESP(player)
    local data = self._espCache[player]
    if not data then return end
    
    Helpers.SafeDestroy(data.hl)
    Helpers.SafeDestroy(data.bb)
    
    if data.conn then data.conn:Disconnect() end
    if data.charConn then data.charConn:Disconnect() end
    
    self._espCache[player] = nil
end

function AdminDetection:ClearAllESP()
    local players = {}
    for player in pairs(self._espCache) do
        table.insert(players, player)
    end
    
    for _, player in ipairs(players) do
        self:RemoveESP(player)
    end
end

function AdminDetection:Check()
    if Config.SafeMode then return end
    
    local currentAdmins = self:GetAdminsInServer()
    local currentSet = {}
    
    for _, admin in ipairs(currentAdmins) do
        currentSet[admin] = true
    end
    
    -- Detectar novos admins
    for _, admin in ipairs(currentAdmins) do
        if not self._adminsOnline[admin] then
            self._adminsOnline[admin] = true
            
            Notifications:Send(
                "⚠️ ADMIN DETECTADO!",
                "👑 " .. admin.Name .. " entrou no servidor!",
                5
            )
            
            if Constants.AUTO_DISABLE_ON_ADMIN and Config.Enabled then
                -- Desativar ESP principal
                Config.Enabled = false
                Notifications:Send("🛑 Auto-Disable", "ESP desativado por segurança!", 3)
            end
            
            if Config.ShowAdminESP then
                self:CreateESP(admin)
            end
        end
    end
    
    -- Detectar admins que saíram
    local toRemove = {}
    for admin in pairs(self._adminsOnline) do
        if not currentSet[admin] then
            table.insert(toRemove, admin)
        end
    end
    
    for _, admin in ipairs(toRemove) do
        self._adminsOnline[admin] = nil
        self:RemoveESP(admin)
        Notifications:Send("👑 Admin Saiu", admin.Name .. " saiu do servidor", 3)
    end
end

function AdminDetection:GetOnlineAdmins()
    local admins = {}
    for admin in pairs(self._adminsOnline) do
        table.insert(admins, admin)
    end
    return admins
end

function AdminDetection:IsAdmin(player)
    return self._adminsOnline[player] == true
end

function AdminDetection:StartWatcher()
    task.spawn(function()
        while true do
            task.wait(10)
            if not Config.SafeMode then
                pcall(function()
                    self:Check()
                end)
            end
        end
    end)
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.AdminDetection = AdminDetection

return AdminDetection