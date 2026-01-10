-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

local Notifications = {
    _rayfield = nil,
}

function Notifications:SetRayfield(rayfield)
    self._rayfield = rayfield
    _G.Rayfield = rayfield
end

function Notifications:Send(title, content, duration)
    duration = duration or 3
    
    if self._rayfield then
        pcall(function()
            self._rayfield:Notify({
                Title = title,
                Content = content,
                Duration = duration,
            })
        end)
    else
        print(string.format("[%s] %s", title, content))
    end
end

function Notifications:SendWarning(content, duration)
    self:Send("⚠️ Aviso", content, duration or 3)
end

function Notifications:SendError(content, duration)
    self:Send("❌ Erro", content, duration or 4)
end

function Notifications:SendSuccess(content, duration)
    self:Send("✅ Sucesso", content, duration or 2)
end

_G.MineHub = _G.MineHub or {}
_G.MineHub.Notifications = Notifications

return Notifications