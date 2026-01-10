-- ============================================================================
-- MINE-HUB LOADER v5.0 (FIXED)
-- ============================================================================
-- GitHub: https://github.com/YOUR_USERNAME/Mine-Hub
-- Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/Mine-Hub/main/loader.lua"))()
-- ============================================================================

local REPO_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/Mine-Hub/main/src/"

print("🚀 [Mine-Hub] Iniciando carregamento...")

-- ============================================================================
-- SISTEMA DE MÓDULOS (HTTP-Based)
-- ============================================================================
local Modules = {}

local function LoadModule(path)
    if Modules[path] then
        return Modules[path]
    end
    
    local url = REPO_URL .. path
    local success, code = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success then
        error("[Mine-Hub] ❌ Falha ao carregar: " .. path .. "\n" .. tostring(code))
    end
    
    -- Substituir requires por referências aos módulos já carregados
    local function customRequire(modulePath)
        return Modules[modulePath]
    end
    
    -- Criar ambiente customizado
    local env = setmetatable({
        require = customRequire,
        script = {Parent = {Parent = {}}}, -- Mock do script object
    }, {__index = getfenv()})
    
    local func, err = loadstring(code)
    if not func then
        error("[Mine-Hub] ❌ Erro ao compilar: " .. path .. "\n" .. tostring(err))
    end
    
    setfenv(func, env)
    local result = func()
    Modules[path] = result
    
    return result
end

-- ============================================================================
-- CARREGAR TODOS OS MÓDULOS NA ORDEM CORRETA
-- ============================================================================

print("📦 Carregando módulos Core...")
local Constants = LoadModule("Core/Constants.lua")
local Config = LoadModule("Core/Config.lua")

print("⚙️ Carregando Engine...")
local ConnectionManager = LoadModule("Engine/ConnectionManager.lua")
local ObjectPool = LoadModule("Engine/ObjectPool.lua")
local Cache = LoadModule("Engine/Cache.lua")

print("🔨 Carregando Utils...")
local Helpers = LoadModule("Utils/Helpers.lua")
local Detection = LoadModule("Utils/Detection.lua")

print("🎨 Carregando Features...")
local AlwaysDay = LoadModule("Features/AlwaysDay.lua")
local WaterWalk = LoadModule("Features/WaterWalk.lua")
local Hitbox = LoadModule("Features/Hitbox.lua")
local AdminDetection = LoadModule("Features/AdminDetection.lua")
local ItemESP = LoadModule("Features/ItemESP.lua")
local MobESP = LoadModule("Features/MobESP.lua")
local PlayerESP = LoadModule("Features/PlayerESP.lua")
local MineralESP = LoadModule("Features/MineralESP.lua")

print("🖥️ Carregando UI...")
local Notifications = LoadModule("UI/Notifications.lua")
local RayfieldUI = LoadModule("UI/RayfieldUI.lua")

-- ============================================================================
-- INJETAR DEPENDÊNCIAS MANUALMENTE (CONTORNAR REQUIRE)
-- ============================================================================

-- Injetar nas Features
MineralESP._Config = Config
MineralESP._Constants = Constants
MineralESP._Cache = Cache
MineralESP._ObjectPool = ObjectPool
MineralESP._ConnectionManager = ConnectionManager
MineralESP._Helpers = Helpers

WaterWalk._Config = Config
WaterWalk._Constants = Constants
WaterWalk._ConnectionManager = ConnectionManager
WaterWalk._Detection = Detection

AlwaysDay._Config = Config
AlwaysDay._Constants = Constants
AlwaysDay._ConnectionManager = ConnectionManager

PlayerESP._Config = Config
PlayerESP._Constants = Constants
PlayerESP._Cache = Cache
PlayerESP._ConnectionManager = ConnectionManager
PlayerESP._Helpers = Helpers

MobESP._Config = Config
MobESP._Constants = Constants
MobESP._Cache = Cache
MobESP._ConnectionManager = ConnectionManager
MobESP._Helpers = Helpers
MobESP._Detection = Detection

ItemESP._Config = Config
ItemESP._Constants = Constants
ItemESP._Cache = Cache
ItemESP._ConnectionManager = ConnectionManager
ItemESP._Helpers = Helpers
ItemESP._Detection = Detection

AdminDetection._Config = Config
AdminDetection._Constants = Constants
AdminDetection._Cache = Cache
AdminDetection._ConnectionManager = ConnectionManager

Hitbox._Config = Config
Hitbox._Cache = Cache
Hitbox._Helpers = Helpers

RayfieldUI._Constants = Constants
RayfieldUI._Config = Config
RayfieldUI._Notifications = Notifications

-- ============================================================================
-- CRIAR SISTEMA GLOBAL
-- ============================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

_G.MineHub = {
    Config = Config,
    Constants = Constants,
    
    -- Engine
    ConnectionManager = ConnectionManager,
    ObjectPool = ObjectPool,
    Cache = Cache,
    
    -- Utils
    Helpers = Helpers,
    Detection = Detection,
    
    -- Features
    MineralESP = MineralESP,
    WaterWalk = WaterWalk,
    AlwaysDay = AlwaysDay,
    PlayerESP = PlayerESP,
    MobESP = MobESP,
    ItemESP = ItemESP,
    AdminDetection = AdminDetection,
    Hitbox = Hitbox,
    
    -- UI
    Notifications = Notifications,
    
    -- Funções principais
    Toggle = function()
        return MineralESP:Toggle()
    end,
    
    Enable = function()
        if not Config.Enabled then
            MineralESP:Toggle()
        end
    end,
    
    Disable = function()
        if Config.Enabled then
            MineralESP:Toggle()
        end
    end,
    
    SafeMode = function(state)
        Config.SafeMode = state
        if state then
            if Config.Enabled then MineralESP:Disable() end
            if Config.WaterWalk then WaterWalk:Disable() end
            if Config.AlwaysDay then AlwaysDay:Disable() end
            PlayerESP:Clear()
            MobESP:Clear()
            ItemESP:Clear()
            AdminDetection:ClearESP()
            Hitbox:RestoreAll()
            Notifications:SafeMode(true)
        else
            Notifications:SafeMode(false)
        end
    end,
}

-- ============================================================================
-- CONFIGURAR INPUT
-- ============================================================================

ConnectionManager:Add("mainToggle", UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Constants.TOGGLE_KEY then
        _G.MineHub.Toggle()
    end
end), "general")

-- ============================================================================
-- INICIAR SISTEMAS
-- ============================================================================

-- Cache update loop
ConnectionManager:Add("cacheUpdate", RunService.RenderStepped:Connect(function()
    Cache:UpdateCameraPosition()
end), "system")

-- Cleanup loop
ConnectionManager:Add("cleanupLoop", RunService.Heartbeat:Connect(function()
    PlayerESP:Cleanup()
    MobESP:Cleanup()
    ItemESP:Cleanup()
end), "system")

-- Inicializar ESPs
PlayerESP:Initialize()
MobESP:Initialize()
ItemESP:Initialize()

-- Admin watcher
task.spawn(function()
    task.wait(2)
    AdminDetection:Initialize()
    
    while true do
        task.wait(10)
        if not Config.SafeMode then
            AdminDetection:Check()
        end
    end
end)

-- WaterWalk character respawn handler
WaterWalk:OnCharacterAdded()

-- ============================================================================
-- CARREGAR UI
-- ============================================================================

task.spawn(function()
    task.wait(1)
    local success, err = pcall(function()
        RayfieldUI.Create()
    end)
    
    if not success then
        warn("[Mine-Hub] ⚠️ Erro ao carregar UI:", err)
        warn("[Mine-Hub] 📝 Use a tecla", Constants.TOGGLE_KEY.Name, "para ativar")
        
        -- Notificação alternativa
        game.StarterGui:SetCore("SendNotification", {
            Title = "⛏️ Mine-Hub v5.0",
            Text = "Carregado! Pressione R para ativar",
            Duration = 5,
        })
    end
end)

-- ============================================================================
-- CLEANUP ON CLOSE
-- ============================================================================

game:BindToClose(function()
    ConnectionManager:RemoveAll()
    ObjectPool:ClearAll()
    Cache:ClearAll()
end)

-- ============================================================================
-- PRONTO!
-- ============================================================================

print("✅ [Mine-Hub] Carregado com sucesso!")
print("📝 Pressione", Constants.TOGGLE_KEY.Name, "para ativar o ESP")
print("📝 Pressione", Constants.UI_KEY.Name, "para abrir o menu")

-- Notificação de sucesso
pcall(function()
    game.StarterGui:SetCore("SendNotification", {
        Title = "✅ Mine-Hub v5.0",
        Text = "Sistema carregado com sucesso!",
        Duration = 3,
    })
end)