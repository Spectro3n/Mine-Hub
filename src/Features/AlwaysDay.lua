-- ============================================================================
-- ALWAYS DAY - Força o dia permanentemente
-- ============================================================================

local AlwaysDay = {}

local Config = require(script.Parent.Parent.Core.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local ConnectionManager = require(script.Parent.Parent.Engine.ConnectionManager)

local RunService = Constants.Services.RunService

-- ============================================================================
-- API PÚBLICA
-- ============================================================================
function AlwaysDay:Enable()
    ConnectionManager:Add("alwaysDay", RunService.RenderStepped:Connect(function()
        local worldInfo = workspace:FindFirstChild("WorldInfo")
        if not worldInfo then return end

        local clock = worldInfo:FindFirstChild("Clock")
        if clock and (clock:IsA("NumberValue") or clock:IsA("IntValue")) then
            if clock.Value ~= 1 then
                clock.Value = 1
            end
        end
    end), "world")
    
    print("🌞 Always Day Ativado!")
end

function AlwaysDay:Disable()
    ConnectionManager:Remove("alwaysDay")
    print("🌙 Ciclo normal restaurado")
end

function AlwaysDay:Toggle(state)
    Config.AlwaysDay = state
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

return AlwaysDay