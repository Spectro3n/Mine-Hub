-- ============================================================================
-- NOTIFICATIONS - Sistema de notificações
-- ============================================================================

local Notifications = {}

function Notifications:Send(title, content, duration)
    duration = duration or 3
    
    if _G.Rayfield then
        _G.Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration,
        })
    else
        print(string.format("[%s] %s", title, content))
    end
end

function Notifications:Success(content, duration)
    self:Send("✅ Sucesso", content, duration)
end

function Notifications:Error(content, duration)
    self:Send("❌ Erro", content, duration)
end

function Notifications:Warning(content, duration)
    self:Send("⚠️ Aviso", content, duration)
end

function Notifications:Info(content, duration)
    self:Send("ℹ️ Info", content, duration)
end

function Notifications:AdminDetected(adminName)
    self:Send("⚠️ ADMIN DETECTADO!", "👑 " .. adminName .. " entrou no servidor!", 5)
end

function Notifications:SafeMode(enabled)
    if enabled then
        self:Send("🛑 SAFE MODE", "TODOS os recursos foram desativados!", 3)
    else
        self:Send("✅ SAFE MODE", "Safe Mode desligado", 2)
    end
end

function Notifications:FeatureToggle(featureName, enabled)
    local status = enabled and "✅ Ativado" or "❌ Desativado"
    self:Send(featureName, status, 2)
end

return Notifications