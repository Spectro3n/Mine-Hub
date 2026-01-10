-- ============================================================================
-- ALWAYS DAY - Força o dia sempre
-- ============================================================================

local RunService = game:GetService("RunService")

local Config = require("Core/Config")
local ConnectionManager = require("Engine/ConnectionManager")
local Notifications = require("UI/Notifications")

local AlwaysDay = {
    _active = false,
}

function AlwaysDay:Enable()
    if self._active then return end
    
    self._active = true
    
    ConnectionManager:Add("alwaysDay", 
        RunService.RenderStepped:Connect(function()
            local worldInfo = workspace:FindFirstChild("WorldInfo")
            if not worldInfo then return end

            local clock = worldInfo:FindFirstChild("Clock")
            if clock and (clock:IsA("NumberValue") or clock:IsA("IntValue")) then
                if clock.Value ~= 1 then
                    clock.Value = 1
                end
            end
        end), 
        "world"
    )
    
    Notifications:Send("🌞 Sempre Dia", "Dia forçado ativado!", 2)
end

function AlwaysDay:Disable()
    if not self._active then return end
    
    ConnectionManager:Remove("alwaysDay")
    self._active = false
    
    Notifications:Send("🌞 Sempre Dia", "Ciclo normal restaurado", 2)
end

function AlwaysDay:Toggle(state)
    Config.AlwaysDay = state
    
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

function AlwaysDay:IsActive()
    return self._active
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.AlwaysDay = AlwaysDay

return AlwaysDay