-- ============================================================================
-- RAYFIELD UI - Interface gráfica principal
-- ============================================================================

local RayfieldUI = {}

local Constants = require(script.Parent.Parent.Core.Constants)
local Config = require(script.Parent.Parent.Core.Config)
local Notifications = require(script.Parent.Notifications)

-- ============================================================================
-- CRIAR UI
-- ============================================================================
function RayfieldUI.Create()
    local success, Rayfield = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)

    if not success or not Rayfield then
        warn("[Mine-Hub] Rayfield não carregou - use a tecla", Constants.TOGGLE_KEY.Name)
        return nil
    end

    _G.Rayfield = Rayfield

    local Window = Rayfield:CreateWindow({
        Name = "⛏️ Mine-Hub v" .. Constants.VERSION,
        LoadingTitle = "Carregando Mine-Hub...",
        LoadingSubtitle = "Sistema Modular ESP",
        Theme = "AmberGlow",
        ToggleUIKeybind = Constants.UI_KEY,
        ConfigurationSaving = {Enabled = false}
    })

    -- ============================================================================
    -- TAB: MAIN
    -- ============================================================================
    local MainTab = Window:CreateTab("🎯 Main")

    MainTab:CreateSection("⚡ Controles Principais")

    MainTab:CreateToggle({
        Name = "🔓 Ativar Mineral ESP",
        CurrentValue = Config.Enabled,
        Callback = function(Value)
            if Value ~= Config.Enabled then
                if _G.MineHub then
                    _G.MineHub.Toggle()
                end
            end
        end,
    })

    MainTab:CreateSection("👁️ Visuais de Minério")

    MainTab:CreateToggle({
        Name = "✨ Mostrar Highlight",
        CurrentValue = Config.ShowHighlight,
        Callback = function(Value)
            Config.ShowHighlight = Value
            if Config.Enabled and _G.MineHub then
                _G.MineHub.MineralESP:Disable()
                _G.MineHub.MineralESP:Enable()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "🏷️ Mostrar Nome do Minério",
        CurrentValue = Config.ShowBillboard,
        Callback = function(Value)
            Config.ShowBillboard = Value
            if Config.Enabled and _G.MineHub then
                _G.MineHub.MineralESP:Disable()
                _G.MineHub.MineralESP:Enable()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "👻 Tornar Blocos Invisíveis",
        CurrentValue = Config.MakeInvisible,
        Callback = function(Value)
            Config.MakeInvisible = Value
            if Config.Enabled and _G.MineHub then
                _G.MineHub.MineralESP:Disable()
                _G.MineHub.MineralESP:Enable()
            end
        end,
    })

    MainTab:CreateButton({
        Name = "🔄 Reescanear Mapa",
        Callback = function()
            if Config.Enabled and _G.MineHub then
                _G.MineHub.MineralESP:Disable()
                _G.MineHub.MineralESP:Enable()
                Notifications:Success("Mapa reescaneado!", 2)
            else
                Notifications:Warning("Ative o ESP primeiro!", 2)
            end
        end,
    })

    -- ============================================================================
    -- TAB: WORLD
    -- ============================================================================
    local WorldTab = Window:CreateTab("🌍 World")

    WorldTab:CreateSection("🛡️ Segurança")

    WorldTab:CreateToggle({
        Name = "🛑 SAFE MODE (Desliga Tudo!)",
        CurrentValue = Config.SafeMode,
        Callback = function(Value)
            if _G.MineHub then
                _G.MineHub.SafeMode(Value)
                Notifications:SafeMode(Value)
            end
        end,
    })

    WorldTab:CreateSection("🌤️ Ambiente")

    WorldTab:CreateToggle({
        Name = "🌞 Sempre Dia",
        CurrentValue = Config.AlwaysDay,
        Callback = function(Value)
            if Config.SafeMode then
                Notifications:Warning("Desative o Safe Mode primeiro!", 2)
                return
            end
            if _G.MineHub then
                _G.MineHub.AlwaysDay:Toggle(Value)
                Notifications:FeatureToggle("🌞 Sempre Dia", Value)
            end
        end,
    })

    WorldTab:CreateToggle({
        Name = "🌊 Andar sobre a Água (FIXED)",
        CurrentValue = Config.WaterWalk,
        Callback = function(Value)
            if Config.SafeMode then
                Notifications:Warning("Desative o Safe Mode primeiro!", 2)
                return
            end
            if _G.MineHub then
                _G.MineHub.WaterWalk:Toggle(Value)
                Notifications:FeatureToggle("🌊 Water Walk", Value)
            end
        end,
    })

    WorldTab:CreateSection("👥 Player ESP")

    WorldTab:CreateToggle({
        Name = "🧑 Player ESP",
        CurrentValue = Config.PlayerESP,
        Callback = function(Value)
            Config.PlayerESP = Value
            if not Value and _G.MineHub then
                _G.MineHub.PlayerESP:Clear()
            end
            Notifications:FeatureToggle("👥 Player ESP", Value)
        end,
    })

    WorldTab:CreateSection("🐔 Mob ESP")

    WorldTab:CreateToggle({
        Name = "🐔 Mob ESP",
        CurrentValue = Config.MobESP,
        Callback = function(Value)
            Config.MobESP = Value
            if not Value and _G.MineHub then
                _G.MineHub.MobESP:Clear()
            end
            Notifications:FeatureToggle("🐔 Mob ESP", Value)
        end,
    })

    WorldTab:CreateSection("📦 Item ESP")

    WorldTab:CreateToggle({
        Name = "📦 Item ESP (Itens no Chão)",
        CurrentValue = Config.ItemESP,
        Callback = function(Value)
            Config.ItemESP = Value
            if not Value and _G.MineHub then
                _G.MineHub.ItemESP:Clear()
            else
                _G.MineHub.ItemESP:Initialize()
            end
            Notifications:FeatureToggle("📦 Item ESP", Value)
        end,
    })

    WorldTab:CreateSection("❤️ Informações de Vida")

    WorldTab:CreateToggle({
        Name = "❤️ Mostrar Vida Real (UpdateWorld)",
        CurrentValue = Config.ShowHealth,
        Callback = function(Value)
            Config.ShowHealth = Value
            Notifications:FeatureToggle("❤️ Vida Real", Value)
        end,
    })

    WorldTab:CreateParagraph({
        Title = "💡 Sobre a Vida Real",
        Content = "O sistema intercepta o RemoteEvent 'UpdateWorld' do servidor para mostrar a vida REAL de todos os mobs e players.\n\nIsso funciona diferente do Humanoid!"
    })

    WorldTab:CreateSection("📦 Hitbox")

    WorldTab:CreateToggle({
        Name = "🟥 Hitbox ESP",
        CurrentValue = Config.ShowHitboxESP,
        Callback = function(Value)
            Config.ShowHitboxESP = Value
            if not Value and _G.MineHub then
                _G.MineHub.Hitbox:ClearAllESP()
            end
        end,
    })

    WorldTab:CreateToggle({
        Name = "📈 Expandir Hitbox (Client)",
        CurrentValue = Config.ExpandHitbox,
        Callback = function(Value)
            Config.ExpandHitbox = Value
            if not Value and _G.MineHub then
                _G.MineHub.Hitbox:RestoreAll()
            end
        end,
    })

    WorldTab:CreateSlider({
        Name = "📏 Tamanho da Hitbox",
        Range = {3, 15},
        Increment = 0.5,
        Suffix = " studs",
        CurrentValue = 6,
        Callback = function(Value)
            Config.HitboxSize = Vector3.new(Value, Value, Value)
        end,
    })

    WorldTab:CreateSection("👑 Admin ESP")

    WorldTab:CreateToggle({
        Name = "👑 Admin ESP",
        CurrentValue = Config.ShowAdminESP,
        Callback = function(Value)
            Config.ShowAdminESP = Value
            if not Value and _G.MineHub then
                _G.MineHub.AdminDetection:ClearESP()
            else
                _G.MineHub.AdminDetection:RefreshAll()
            end
        end,
    })

    WorldTab:CreateSection("🧹 Limpeza")

    WorldTab:CreateButton({
        Name = "🧹 Limpar Todos os ESPs",
        Callback = function()
            if _G.MineHub then
                _G.MineHub.PlayerESP:Clear()
                _G.MineHub.MobESP:Clear()
                _G.MineHub.ItemESP:Clear()
                _G.MineHub.AdminDetection:ClearESP()
                _G.MineHub.Hitbox:ClearAllESP()
                Notifications:Success("Todos os ESPs foram removidos!", 2)
            end
        end,
    })

    -- ============================================================================
    -- TAB: MINERALS
    -- ============================================================================
    local MineralsTab = Window:CreateTab("⛏️ Minerals")

    MineralsTab:CreateSection("🎨 Cores dos Minerais")

    for id, data in pairs(Constants.MINERALS) do
        MineralsTab:CreateColorPicker({
            Name = "🎨 " .. data.name,
            Color = data.color,
            Callback = function(Value)
                Constants.MINERALS[id].color = Value
                if Config.Enabled and _G.MineHub then
                    _G.MineHub.MineralESP:Disable()
                    _G.MineHub.MineralESP:Enable()
                end
            end
        })
    end

    -- ============================================================================
    -- TAB: INFO
    -- ============================================================================
    local InfoTab = Window:CreateTab("ℹ️ Info")

    InfoTab:CreateSection("📖 Como Usar")

    InfoTab:CreateParagraph({
        Title = "🎮 Controles",
        Content = "• " .. Constants.TOGGLE_KEY.Name .. " = Ativar/Desativar ESP\n• " .. Constants.UI_KEY.Name .. " = Abrir/Fechar Menu"
    })

    InfoTab:CreateParagraph({
        Title = "🆕 Novidades v" .. Constants.VERSION,
        Content = "• ❤️ VIDA REAL via UpdateWorld!\n• 📦 ITEM ESP (itens no chão)\n• 🌊 Water Walk CORRIGIDO\n  (sem bug de câmera!)\n• 🧑 Player/Mob ESP separados\n• ⚡ Sistema modular\n• 🗂️ Código organizado em pastas"
    })

    InfoTab:CreateParagraph({
        Title = "🏗️ Arquitetura Modular",
        Content = "O Mine-Hub agora usa uma estrutura modular profissional:\n\n• Core/ - Núcleo do sistema\n• Engine/ - Sistemas base\n• Features/ - Features isoladas\n• UI/ - Interface\n• Utils/ - Utilitários\n\nFácil de modificar e expandir!"
    })

    InfoTab:CreateParagraph({
        Title = "🌊 Water Walk Fix",
        Content = "Agora usa:\n• Trava posição Y diretamente\n• Desativa estado Swimming\n• Cancela velocidade vertical\n• Sem plataforma física = sem bug!"
    })

    InfoTab:CreateSection("💡 Dicas")

    InfoTab:CreateParagraph({
        Title = "🎯 Performance",
        Content = "• Object Pooling para GUI\n• Cache de valores computados\n• Connection Manager centralizado\n• Sistema de cleanup automático"
    })

    InfoTab:CreateParagraph({
        Title = "🛡️ Segurança",
        Content = "• Safe Mode desliga tudo instantaneamente\n• Detecção de admins automática\n• Auto-disable quando admin entra\n• Sistema de notificações"
    })

    -- Notificação de carregamento
    Rayfield:Notify({
        Title = "⛏️ Mine-Hub v" .. Constants.VERSION,
        Content = "Carregado! Pressione " .. Constants.TOGGLE_KEY.Name .. " para ativar\n❤️ Vida Real ativa via UpdateWorld!",
        Duration = 5,
    })

    return Window
end

return RayfieldUI