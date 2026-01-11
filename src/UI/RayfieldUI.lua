-- ============================================================================
-- RAYFIELD UI v2.0 - Melhorada com Debug e Métricas
-- ============================================================================

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Notifications = require("UI/Notifications")

-- Features serão carregadas depois para evitar dependência circular
local MineralESP, PlayerESP, MobESP, ItemESP, AdminDetection, WaterWalk, AlwaysDay, Hitbox
local Cache, ConnectionManager

local RayfieldUI = {
    _window = nil,
    _rayfield = nil,
    _loaded = false,
    _debugLabels = {},
}

local function loadFeatures()
    if RayfieldUI._loaded then return end
    
    MineralESP = require("Features/MineralESP")
    PlayerESP = require("Features/PlayerESP")
    MobESP = require("Features/MobESP")
    ItemESP = require("Features/ItemESP")
    AdminDetection = require("Features/AdminDetection")
    WaterWalk = require("Features/WaterWalk")
    AlwaysDay = require("Features/AlwaysDay")
    Hitbox = require("Features/Hitbox")
    Cache = require("Engine/Cache")
    ConnectionManager = require("Engine/ConnectionManager")
    
    RayfieldUI._loaded = true
end

local function setSafeMode(state)
    loadFeatures()
    
    Config.SafeMode = state

    if state then
        if Config.Enabled then
            MineralESP:Toggle()
        end

        AdminDetection:ClearAllESP()
        PlayerESP:ClearAll()
        MobESP:ClearAll()
        ItemESP:Disable()
        Hitbox:ClearAllESP()
        Hitbox:RestoreAll()
        Hitbox:StopUpdateLoop()
        
        if Config.AlwaysDay then
            AlwaysDay:Toggle(false)
        end
        
        if Config.WaterWalk then
            WaterWalk:Toggle(false)
        end

        Notifications:Send("🛑 SAFE MODE ATIVADO", "TODOS os recursos desativados!", 3)
    else
        Notifications:Send("✅ SAFE MODE", "Safe Mode desligado", 2)
        
        if Config.ShowAdminESP then
            for _, admin in ipairs(AdminDetection:GetOnlineAdmins()) do
                AdminDetection:CreateESP(admin)
            end
        end
        
        -- Reiniciar sistemas
        if Config.ShowHitboxESP or Config.ExpandHitbox then
            Hitbox:StartUpdateLoop()
        end
    end
end

function RayfieldUI:Create()
    loadFeatures()
    
    local success, Rayfield = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)

    if not success or not Rayfield then
        warn("[MineralESP] Rayfield não carregou - use a tecla R")
        return nil
    end

    self._rayfield = Rayfield
    Notifications:SetRayfield(Rayfield)

    self._window = Rayfield:CreateWindow({
        Name = "⛏️ Mine-Hub v" .. Constants.VERSION,
        LoadingTitle = "Carregando...",
        LoadingSubtitle = "ESP Completo + Sistema Modular",
        Theme = "AmberGlow",
        ToggleUIKeybind = Enum.KeyCode.K,
        ConfigurationSaving = {Enabled = false}
    })

    self:CreateMainTab()
    self:CreateWorldTab()
    self:CreateHitboxTab()
    self:CreateMineralsTab()
    self:CreateDebugTab()
    self:CreateInfoTab()

    Rayfield:Notify({
        Title = "⛏️ Mine-Hub v" .. Constants.VERSION,
        Content = "Carregado! Pressione R para ativar | K para menu",
        Duration = 5,
    })

    return self._window
end

function RayfieldUI:CreateMainTab()
    loadFeatures()
    
    local MainTab = self._window:CreateTab("🎯 Main")

    MainTab:CreateSection("⚡ Controles Principais")

    MainTab:CreateToggle({
        Name = "🔍 Ativar Mineral ESP",
        CurrentValue = Config.Enabled,
        Callback = function(Value)
            if Value ~= Config.Enabled then
                MineralESP:Toggle()
            end
        end,
    })

    MainTab:CreateSection("👁️ Visuais de Minério")

    MainTab:CreateToggle({
        Name = "✨ Mostrar Highlight",
        CurrentValue = Config.ShowHighlight,
        Callback = function(Value)
            Config.ShowHighlight = Value
            MineralESP:Refresh()
        end,
    })

    MainTab:CreateToggle({
        Name = "🏷️ Mostrar Nome do Minério",
        CurrentValue = Config.ShowBillboard,
        Callback = function(Value)
            Config.ShowBillboard = Value
            MineralESP:Refresh()
        end,
    })

    MainTab:CreateToggle({
        Name = "👻 Tornar Blocos Invisíveis",
        CurrentValue = Config.MakeInvisible,
        Callback = function(Value)
            Config.MakeInvisible = Value
            MineralESP:Refresh()
        end,
    })
    
    MainTab:CreateSection("🛡️ Segurança")

    MainTab:CreateToggle({
        Name = "🛑 SAFE MODE (Emergência!)",
        CurrentValue = Config.SafeMode,
        Callback = function(Value)
            setSafeMode(Value)
        end,
    })
end

function RayfieldUI:CreateWorldTab()
    loadFeatures()
    
    local WorldTab = self._window:CreateTab("🌍 World")

    WorldTab:CreateSection("🌤️ Ambiente")

    WorldTab:CreateToggle({
        Name = "🌞 Sempre Dia",
        CurrentValue = Config.AlwaysDay,
        Callback = function(Value)
            if not Config.SafeMode then
                AlwaysDay:Toggle(Value)
            else
                Notifications:Send("🛑 Safe Mode", "Desative o Safe Mode primeiro!", 2)
            end
        end,
    })

    WorldTab:CreateToggle({
        Name = "🌊 Andar sobre a Água",
        CurrentValue = Config.WaterWalk,
        Callback = function(Value)
            if not Config.SafeMode then
                WaterWalk:Toggle(Value)
            else
                Notifications:Send("🛑 Safe Mode", "Desative o Safe Mode primeiro!", 2)
            end
        end,
    })

    WorldTab:CreateSection("👥 Player ESP")

    WorldTab:CreateToggle({
        Name = "🧑 Player ESP",
        CurrentValue = Config.PlayerESP,
        Callback = function(Value)
            Config.PlayerESP = Value
            if not Value then
                PlayerESP:ClearAll()
            else
                PlayerESP:Refresh()
            end
            Notifications:Send("👥 Player ESP", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    WorldTab:CreateSection("🐔 Mob ESP")

    WorldTab:CreateToggle({
        Name = "🐔 Mob ESP",
        CurrentValue = Config.MobESP,
        Callback = function(Value)
            Config.MobESP = Value
            if not Value then
                MobESP:ClearAll()
            end
            Notifications:Send("🐔 Mob ESP", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    WorldTab:CreateSection("📦 Item ESP")

    WorldTab:CreateToggle({
        Name = "📦 Item ESP (Itens Dropados)",
        CurrentValue = Config.ItemESP,
        Callback = function(Value)
            Config.ItemESP = Value
            if Value then
                ItemESP:Enable()
            else
                ItemESP:Disable()
            end
            Notifications:Send("📦 Item ESP", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    WorldTab:CreateSection("❤️ Vida")

    WorldTab:CreateToggle({
        Name = "❤️ Mostrar Vida Real",
        CurrentValue = Config.ShowHealth,
        Callback = function(Value)
            Config.ShowHealth = Value
            Notifications:Send("❤️ Vida Real", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    WorldTab:CreateSection("👑 Admin ESP")

    WorldTab:CreateToggle({
        Name = "👑 Admin ESP",
        CurrentValue = Config.ShowAdminESP,
        Callback = function(Value)
            Config.ShowAdminESP = Value
            if not Value then
                AdminDetection:ClearAllESP()
            else
                for _, admin in ipairs(AdminDetection:GetOnlineAdmins()) do
                    AdminDetection:CreateESP(admin)
                end
            end
        end,
    })

    WorldTab:CreateSection("🧹 Limpeza Geral")

    WorldTab:CreateButton({
        Name = "🧹 Limpar Todos os ESPs",
        Callback = function()
            PlayerESP:ClearAll()
            MobESP:ClearAll()
            ItemESP:ClearAll()
            AdminDetection:ClearAllESP()
            Hitbox:ClearAllESP()
            Notifications:Send("🧹 Limpeza", "Todos os ESPs removidos!", 2)
        end,
    })
end

function RayfieldUI:CreateHitboxTab()
    loadFeatures()
    
    local HitboxTab = self._window:CreateTab("📦 Hitbox")

    HitboxTab:CreateSection("🎯 Hitbox ESP")

    HitboxTab:CreateToggle({
        Name = "🟥 Mostrar Hitbox ESP",
        CurrentValue = Config.ShowHitboxESP,
        Callback = function(Value)
            Config.ShowHitboxESP = Value
            if Value then
                Hitbox:StartUpdateLoop()
            else
                Hitbox:ClearAllESP()
            end
            Notifications:Send("📦 Hitbox ESP", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    HitboxTab:CreateSection("📈 Expansão de Hitbox")

    HitboxTab:CreateToggle({
        Name = "📈 Expandir Hitboxes",
        CurrentValue = Config.ExpandHitbox,
        Callback = function(Value)
            Config.ExpandHitbox = Value
            if Value then
                Hitbox:StartUpdateLoop()
            else
                Hitbox:RestoreAll()
            end
            Notifications:Send("📈 Expansão", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    HitboxTab:CreateSlider({
        Name = "📐 Tamanho da Hitbox",
        Range = {3, 40},
        Increment = 0.5,
        Suffix = " studs",
        CurrentValue = 6,
        Callback = function(Value)
            Hitbox:UpdateSize(Value)
        end,
    })

    HitboxTab:CreateSection("⚙️ Configuração")

    HitboxTab:CreateToggle({
        Name = "🎯 Auto-Track Players",
        CurrentValue = true,
        Callback = function(Value)
            Hitbox:Configure({ autoTrackPlayers = Value })
        end,
    })

    HitboxTab:CreateToggle({
        Name = "🐔 Auto-Track Mobs",
        CurrentValue = true,
        Callback = function(Value)
            Hitbox:Configure({ autoTrackMobs = Value })
        end,
    })

    HitboxTab:CreateToggle({
        Name = "📏 Tamanho Adaptativo",
        CurrentValue = false,
        Callback = function(Value)
            Hitbox:Configure({ adaptiveSize = Value })
        end,
    })

    HitboxTab:CreateSection("🎨 Cores por Tipo")

    HitboxTab:CreateColorPicker({
        Name = "👤 Cor Player",
        Color = Color3.fromRGB(255, 0, 0),
        Callback = function(Value)
            Hitbox:UpdateColorByType("Player", Value)
        end
    })

    HitboxTab:CreateColorPicker({
        Name = "🐷 Cor Animal/Mob",
        Color = Color3.fromRGB(255, 165, 0),
        Callback = function(Value)
            Hitbox:UpdateColorByType("Animal", Value)
            Hitbox:UpdateColorByType("Mob", Value)
        end
    })

    HitboxTab:CreateColorPicker({
        Name = "📦 Cor Item",
        Color = Color3.fromRGB(255, 255, 0),
        Callback = function(Value)
            Hitbox:UpdateColorByType("Item", Value)
        end
    })

    HitboxTab:CreateSection("🔧 Ações")

    HitboxTab:CreateButton({
        Name = "🔄 Restaurar Todas Hitboxes",
        Callback = function()
            local count = Hitbox:RestoreAll()
            Notifications:Send("📦 Hitbox", count .. " hitboxes restauradas!", 2)
        end,
    })

    HitboxTab:CreateButton({
        Name = "🧹 Limpar Hitbox ESP",
        Callback = function()
            Hitbox:ClearAllESP()
            Notifications:Send("📦 Hitbox", "ESP limpo!", 2)
        end,
    })
end

function RayfieldUI:CreateMineralsTab()
    loadFeatures()
    
    local MineralsTab = self._window:CreateTab("⛏️ Minerals")

    MineralsTab:CreateSection("🎨 Cores dos Minerais")

    for id, data in pairs(Constants.MINERALS) do
        MineralsTab:CreateColorPicker({
            Name = "🎨 " .. data.name,
            Color = data.color,
            Callback = function(Value)
                Constants.MINERALS[id].color = Value
                MineralESP:Refresh()
            end
        })
    end
end

function RayfieldUI:CreateDebugTab()
    loadFeatures()
    
    local DebugTab = self._window:CreateTab("🔧 Debug")

    DebugTab:CreateSection("📊 Métricas em Tempo Real")

    DebugTab:CreateButton({
        Name = "📊 Mostrar Métricas do Cache",
        Callback = function()
            local metrics = Cache:GetMetrics()
            local msg = ""
            for k, v in pairs(metrics) do
                msg = msg .. k .. ": " .. tostring(v) .. "\n"
            end
            Notifications:Send("📊 Cache Metrics", msg, 5)
        end,
    })

    DebugTab:CreateButton({
        Name = "📦 Mostrar Métricas do ItemESP",
        Callback = function()
            local metrics = ItemESP:GetMetrics()
            local msg = ""
            for k, v in pairs(metrics) do
                msg = msg .. k .. ": " .. tostring(v) .. "\n"
            end
            Notifications:Send("📦 ItemESP Metrics", msg, 5)
        end,
    })

    DebugTab:CreateButton({
        Name = "🎯 Mostrar Métricas do Hitbox",
        Callback = function()
            local metrics = Hitbox:GetMetrics()
            local msg = ""
            for k, v in pairs(metrics) do
                msg = msg .. k .. ": " .. tostring(v) .. "\n"
            end
            Notifications:Send("🎯 Hitbox Metrics", msg, 5)
        end,
    })

    DebugTab:CreateButton({
        Name = "🔗 Mostrar Conexões Ativas",
        Callback = function()
            local metrics = ConnectionManager:GetMetrics()
            local msg = ""
            for k, v in pairs(metrics) do
                msg = msg .. k .. ": " .. tostring(v) .. "\n"
            end
            Notifications:Send("🔗 Connections", msg, 5)
        end,
    })

    DebugTab:CreateSection("🔧 Ações de Debug")

    DebugTab:CreateButton({
        Name = "🔄 Forçar Refresh ItemESP",
        Callback = function()
            ItemESP:Refresh()
            Notifications:Send("📦 ItemESP", "Refresh completo!", 2)
        end,
    })

    DebugTab:CreateButton({
        Name = "🧹 Limpar Cache",
        Callback = function()
            Cache:ClearAll()
            Notifications:Send("📊 Cache", "Cache limpo!", 2)
        end,
    })

    DebugTab:CreateButton({
        Name = "🔗 Forçar Cleanup de Conexões",
        Callback = function()
            ConnectionManager:ForceCleanup()
            Notifications:Send("🔗 Connections", "Cleanup executado!", 2)
        end,
    })

    DebugTab:CreateSection("📈 Contadores")

    DebugTab:CreateButton({
        Name = "📈 Mostrar Contadores",
        Callback = function()
            local msg = string.format([[
ItemESP: %d itens
Hitbox ESP: %d
Hitbox Expandidos: %d
Conexões: %d
Cache Health: %d
            ]],
                ItemESP:GetCount(),
                Hitbox:GetESPCount(),
                Hitbox:GetExpandedCount(),
                ConnectionManager:GetCount(),
                Cache:GetCacheSizes().healthCache
            )
            Notifications:Send("📈 Contadores", msg, 5)
        end,
    })
end

function RayfieldUI:CreateInfoTab()
    loadFeatures()
    
    local InfoTab = self._window:CreateTab("ℹ️ Info")

    InfoTab:CreateSection("📖 Como Usar")

    InfoTab:CreateParagraph({
        Title = "🎮 Controles",
        Content = "• R = Ativar/Desativar Mineral ESP\n• K = Abrir/Fechar Menu"
    })

    InfoTab:CreateParagraph({
        Title = "🆕 Novidades v" .. Constants.VERSION,
        Content = [[
• Sistema modular completo
• Vida real via UpdateWorld
• Item ESP otimizado
• Hitbox com auto-tracking
• Cache inteligente
• Detecção por tipo de entidade
• Métricas de debug
        ]]
    })

    InfoTab:CreateSection("🔧 Utilitários")

    InfoTab:CreateButton({
        Name = "🔄 Reescanear Mapa",
        Callback = function()
            MineralESP:Refresh()
            Notifications:Send("⛏️ Mineral ESP", "Mapa reescaneado!", 2)
        end,
    })

    InfoTab:CreateButton({
        Name = "🔄 Reiniciar Todos os Sistemas",
        Callback = function()
            -- Reiniciar tudo
            ItemESP:Refresh()
            MineralESP:Refresh()
            PlayerESP:Refresh()
            Hitbox:ClearAllESP()
            Cache:ClearAll()
            Notifications:Send("🔄 Reinício", "Todos os sistemas reiniciados!", 2)
        end,
    })
end

function RayfieldUI:GetWindow()
    return self._window
end

function RayfieldUI:GetRayfield()
    return self._rayfield
end

-- ============================================================================
-- EXPORT GLOBAL
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.RayfieldUI = RayfieldUI

return RayfieldUI