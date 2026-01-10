-- ============================================================================
-- INIT - Entry Point Principal do Mine-Hub
-- ============================================================================

return function()
    print("🚀 Mine-Hub v5.0 - Inicializando...")
    
    -- ============================================================================
    -- CARREGAR MÓDULOS CORE
    -- ============================================================================
    local Constants = require(script.Parent.Constants)
    local Config = require(script.Parent.Config)
    
    -- ============================================================================
    -- CARREGAR ENGINE
    -- ============================================================================
    local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)
    local ObjectPool = require(script.Parent.Parent.Engine.ObjectPool)
    local Cache = require(script.Parent.Parent.Engine.Cache)
    
    -- ============================================================================
    -- CARREGAR UTILS
    -- ============================================================================
    local Helpers = require(script.Parent.Parent.Utils.Helpers)
    local Detection = require(script.Parent.Parent.Utils.Detection)
    
    -- ============================================================================
    -- CARREGAR FEATURES
    -- ============================================================================
    local MineralESP = require(script.Parent.Parent.Features.MineralESP)
    local WaterWalk = require(script.Parent.Parent.Features.WaterWalk)
    local AlwaysDay = require(script.Parent.Parent.Features.AlwaysDay)
    local PlayerESP = require(script.Parent.Parent.Features.PlayerESP)
    local MobESP = require(script.Parent.Parent.Features.MobESP)
    local ItemESP = require(script.Parent.Parent.Features.ItemESP)
    local AdminDetection = require(script.Parent.Parent.Features.AdminDetection)
    local Hitbox = require(script.Parent.Parent.Features.Hitbox)
    
    -- ============================================================================
    -- CARREGAR UI
    -- ============================================================================
    local RayfieldUI = require(script.Parent.Parent.UI.RayfieldUI)
    
    -- ============================================================================
    -- CRIAR SISTEMA GLOBAL
    -- ============================================================================
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
                -- Desativar tudo
                if Config.Enabled then MineralESP:Disable() end
                if Config.WaterWalk then WaterWalk:Disable() end
                if Config.AlwaysDay then AlwaysDay:Disable() end
                PlayerESP:Clear()
                MobESP:Clear()
                ItemESP:Clear()
                AdminDetection:ClearESP()
                Hitbox:RestoreAll()
                print("🛑 SAFE MODE ATIVADO - Tudo desligado!")
            else
                print("✅ Safe Mode desativado")
            end
        end,
    }
    
    -- ============================================================================
    -- CONFIGURAR INPUT
    -- ============================================================================
    local UserInputService = Constants.Services.UserInputService
    
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
    local RunService = Constants.Services.RunService
    ConnectionManager:Add("cacheUpdate", RunService.RenderStepped:Connect(function()
        Cache:UpdateCameraPosition()
    end), "system")
    
    -- Cleanup loop
    ConnectionManager:Add("cleanupLoop", RunService.Heartbeat:Connect(function()
        PlayerESP:Cleanup()
        MobESP:Cleanup()
        ItemESP:Cleanup()
    end), "system")
    
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
        local success, err = pcall(function()
            RayfieldUI.Create()
        end)
        
        if not success then
            warn("[Mine-Hub] Erro ao carregar UI:", err)
            warn("[Mine-Hub] Use a tecla", Constants.TOGGLE_KEY.Name, "para ativar")
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
    print("✅ Mine-Hub v5.0 carregado com sucesso!")
    print("📝 Pressione", Constants.TOGGLE_KEY.Name, "para ativar o ESP")
    print("📝 Pressione", Constants.UI_KEY.Name, "para abrir o menu")
    
    return _G.MineHub
end