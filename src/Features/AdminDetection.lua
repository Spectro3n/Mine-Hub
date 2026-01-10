-- ============================================================================
-- ADMIN DETECTION - Detecção e ESP de administradores
-- ============================================================================

local AdminDetection = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local Cache = require(script.Parent.Parent.Engine.Cache)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)

local Players = Constants.Services.Players
local RunService = Constants.Services.RunService
local ReplicatedStorage = Constants.Services.ReplicatedStorage
local player = Players.LocalPlayer

local AdminsRemote = ReplicatedStorage:FindFirstChild("Admins")

-- ============================================================================
-- FUNÇÕES INTERNAS
-- ============================================================================
local function getAdminsInServer()
    if not AdminsRemote or not AdminsRemote:IsA("RemoteFunction") then
        return {}
    end

    local ok, result = pcall(function()
        return AdminsRemote:InvokeServer()
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

local function addAdminESP(plr)
    if not Config.ShowAdminESP then return end
    if Config.SafeMode then return end
    if Cache.AdminESP[plr] then return end
    if plr == player then return end

    local function apply(char)
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end

        if Cache.AdminESP[plr] then
            if Cache.AdminESP[plr].hl and Cache.AdminESP[plr].hl.Parent then 
                Cache.AdminESP[plr].hl:Destroy() 
            end
            if Cache.AdminESP[plr].bb and Cache.AdminESP[plr].bb.Parent then 
                Cache.AdminESP[plr].bb:Destroy() 
            end
            if Cache.AdminESP[plr].conn then 
                Cache.AdminESP[plr].conn:Disconnect() 
            end
        end

        local hl = Instance.new("Highlight")
        hl.Name = "AdminESP"
        hl.FillColor = Color3.fromRGB(255, 60, 60)
        hl.OutlineColor = Color3.fromRGB(255, 0, 0)
        hl.FillTransparency = 0.25
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = char

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
            if not plr.Parent or not plr.Character then
                conn:Disconnect()
                return
            end
            local dist = Cache:GetDistanceFromCamera(hrp.Position)
            lbl.Text = string.format("⚠️ ADMIN ⚠️\n👑 %s\n📏 %.0fm", plr.Name, dist)
        end)

        Cache.AdminESP[plr] = {hl = hl, bb = bb, conn = conn}
    end

    Cache.AdminESP[plr] = {}
    local charConn = plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        apply(char)
    end)
    Cache.AdminESP[plr].charConn = charConn

    if plr.Character then
        apply(plr.Character)
    end
end

local function removeAdminESP(plr)
    local data = Cache.AdminESP[plr]
    if not data then return end
    if data.hl and data.hl.Parent then data.hl:Destroy() end
    if data.bb and data.bb.Parent then data.bb:Destroy() end
    if data.conn then data.conn:Disconnect() end
    if data.charConn then data.charConn:Disconnect() end
    Cache.AdminESP[plr] = nil
end

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function AdminDetection:Initialize()
    print("🔍 AdminDetection inicializado")
end

function AdminDetection:Check()
    if Config.SafeMode then return end
    
    local currentAdmins = getAdminsInServer()
    local currentSet = {}
    for _, admin in ipairs(currentAdmins) do
        currentSet[admin] = true
    end
    
    -- Novos admins
    for _, admin in ipairs(currentAdmins) do
        if not Cache.AdminsOnline[admin] then
            Cache.AdminsOnline[admin] = true
            
            warn("⚠️ ADMIN DETECTADO:", admin.Name)
            
            if Constants.AUTO_DISABLE_ON_ADMIN and Config.Enabled then
                if _G.MineHub then
                    _G.MineHub.Disable()
                end
            end
            
            if Config.ShowAdminESP then
                addAdminESP(admin)
            end
        end
    end
    
    -- Admins que saíram
    local toRemove = {}
    for admin in pairs(Cache.AdminsOnline) do
        if not currentSet[admin] then
            table.insert(toRemove, admin)
        end
    end
    
    for _, admin in ipairs(toRemove) do
        Cache.AdminsOnline[admin] = nil
        removeAdminESP(admin)
    end
end

function AdminDetection:AddESP(plr)
    addAdminESP(plr)
end

function AdminDetection:RemoveESP(plr)
    removeAdminESP(plr)
end

function AdminDetection:ClearESP()
    for plr, data in pairs(Cache.AdminESP) do
        if data.hl and data.hl.Parent then data.hl:Destroy() end
        if data.bb and data.bb.Parent then data.bb:Destroy() end
        if data.conn then data.conn:Disconnect() end
        if data.charConn then data.charConn:Disconnect() end
    end
    Cache.AdminESP = {}
end

function AdminDetection:RefreshAll()
    if Config.ShowAdminESP then
        for admin in pairs(Cache.AdminsOnline) do
            addAdminESP(admin)
        end
    end
end

return AdminDetection