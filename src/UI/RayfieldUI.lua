-- ============================================================================
-- RAYFIELD UI - Interface do usuário
-- ============================================================================

local Config = require("Core/Config")
local Constants = require("Core/Constants")
local Notifications = require("UI/Notifications")
local MineralESP = require("Features/MineralESP")
local PlayerESP = require("Features/PlayerESP")
local MobESP = require("Features/MobESP")
local ItemESP = require("Features/ItemESP")
local AdminDetection = require("Features/AdminDetection")
local WaterWalk = require("Features/WaterWalk")
local AlwaysDay = require("Features/AlwaysDay")
local Hitbox = require("Features/Hitbox")

local RayfieldUI = {
    _window = nil,
    _rayfield = nil,
}

local function setSafeMode(state)
    Config.SafeMode = state

    if state then
        if Config.Enabled then
            MineralESP:Toggle()
        end

        AdminDetection:ClearAllESP()
        PlayerESP:ClearAll()
        MobESP:ClearAll()
        ItemESP:ClearAll()
        Hitbox:ClearAllESP()
        Hitbox:RestoreAll()
        
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
    end
end

function RayfieldUI:Create()
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
        Name = "⛏️ Mineral ESP v" .. Constants.VERSION,
        LoadingTitle = "Carregando...",
        LoadingSubtitle = "ESP Completo + Vida Real",
        Theme = "AmberGlow",
        ToggleUIKeybind = Enum.KeyCode.K,
        ConfigurationSaving = {Enabled = false}
    })

    self:CreateMainTab()
    self:CreateWorldTab()
    self:CreateMineralsTab()
    self:CreateInfoTab()

    Rayfield:Notify({
        Title = "⛏️ Mineral ESP v" .. Constants.VERSION,
        Content = "Carregado! Pressione R para ativar\n❤️ Vida Real ativa via UpdateWorld!",
        Duration = 5,
    })

    return self._window
end

function RayfieldUI:CreateMainTab()
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
end

function RayfieldUI:CreateWorldTab()
    local WorldTab = self._window:CreateTab("🌍 World")

    WorldTab:CreateSection("🛡️ Segurança")

    WorldTab:CreateToggle({
        Name = "🛑 SAFE MODE (Desliga Tudo!)",
        CurrentValue = Config.SafeMode,
        Callback = function(Value)
            setSafeMode(Value)
        end,
    })

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
        Name = "🌊 Andar sobre a Água (FIXED)",
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
        Name = "📦 Item ESP (Itens no Chão)",
        CurrentValue = Config.ItemESP,
        Callback = function(Value)
            Config.ItemESP = Value
            if not Value then
                ItemESP:ClearAll()
            end
            Notifications:Send("📦 Item ESP", Value and "✅ Ativado" or "❌ Desativado", 2)
        end,
    })

    WorldTab:CreateSection("❤️ Informações de Vida")

    WorldTab:CreateToggle({
        Name = "❤️ Mostrar Vida Real (UpdateWorld)",
        CurrentValue = Config.ShowHealth,
        Callback = function(Value)
            Config.ShowHealth = Value
            Notifications:Send("❤️ Vida Real", Value and "✅ Interceptando vida!" or "❌ Desativado", 2)
        end,
    })

    WorldTab:CreateParagraph({
        Title = "💡 Sobre a Vida Real",
        Content = "O sistema intercepta o RemoteEvent\n'UpdateWorld' do servidor para mostrar\na vida REAL de todos os mobs e players."
    })

    WorldTab:CreateSection("📦 Hitbox")

    WorldTab:CreateToggle({
        Name = "🟥 Hitbox ESP",
        CurrentValue = Config.ShowHitboxESP,
        Callback = function(Value)
            Config.ShowHitboxESP = Value
            if not Value then
                Hitbox:ClearAllESP()
            end
        end,
    })

    WorldTab:CreateToggle({
        Name = "📈 Expandir Hitbox (Client)",
        CurrentValue = Config.ExpandHitbox,
        Callback = function(Value)
            Config.ExpandHitbox = Value
            if not Value then
                Hitbox:RestoreAll()
            end
        end,
    })

    WorldTab:CreateSlider({
        Name = "📐 Tamanho da Hitbox",
        Range = {3, 15},
        Increment = 0.5,
        Suffix = " studs",
        CurrentValue = 6,
        Callback = function(Value)
            Hitbox:UpdateSize(Vector3.new(Value, Value, Value))
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

    WorldTab:CreateSection("🧹 Limpeza")

    WorldTab:CreateButton({
        Name = "🧹 Limpar Todos os ESPs",
        Callback = function()
            PlayerESP:ClearAll()
            MobESP:ClearAll()
            ItemESP:ClearAll()
            AdminDetection:ClearAllESP()
            Hitbox:ClearAllESP()
            Notifications:Send("🧹 Limpeza", "Todos os ESPs foram removidos!", 2)
        end,
    })
end

function RayfieldUI:CreateMineralsTab()
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

function RayfieldUI:CreateInfoTab()
    local InfoTab = self._window:CreateTab("ℹ️ Info")

    InfoTab:CreateSection("📖 Como Usar")

    InfoTab:CreateParagraph({
        Title = "🎮 Controles",
        Content = "• R = Ativar/Desativar ESP\n• K = Abrir/Fechar Menu"
    })

    InfoTab:CreateParagraph({
        Title = "🆕 Novidades v" .. Constants.VERSION,
        Content = "• ❤️ VIDA REAL via UpdateWorld!\n• 📦 ITEM ESP (itens no chão)\n• 🌊 Water Walk CORRIGIDO\n• 🧑 Player/Mob ESP separados\n• ⚡ Sistema modular"
    })

    InfoTab:CreateButton({
        Name = "🔄 Reescanear Mapa",
        Callback = function()
            MineralESP:Refresh()
            Notifications:Send("⛏️ Mineral ESP", "Mapa reescaneado!", 2)
        end,
    })
end

function RayfieldUI:GetWindow()
    return self._window
end

function RayfieldUI:GetRayfield()
    return self._rayfield
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.RayfieldUI = RayfieldUI

return RayfieldUI