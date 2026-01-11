-- ============================================================================
-- ALWAYS DAY v2.0 - Otimizado com Interceptação de Propriedades
-- ============================================================================
-- ✅ Usa GetPropertyChangedSignal (não spamma valores)
-- ✅ Suporta Lighting padrão + sistema custom (WorldInfo.Clock)
-- ✅ Trava propriedades de iluminação adicionais
-- ✅ Fallback para RenderStepped se necessário
-- ============================================================================

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Config = require("Core/Config")
local ConnectionManager = require("Engine/ConnectionManager")
local Notifications = require("UI/Notifications")

local AlwaysDay = {
    -- ═══════════════════════════════════════════════
    -- ESTADO
    -- ═══════════════════════════════════════════════
    _active = false,
    _mode = nil,  -- "lighting", "worldinfo", "fallback"
    
    -- ═══════════════════════════════════════════════
    -- CONFIGURAÇÃO PADRÃO
    -- ═══════════════════════════════════════════════
    _config = {
        -- Horário alvo (12 = meio-dia)
        targetClockTime = 12,
        targetTimeOfDay = "12:00:00",
        
        -- Valor para WorldInfo.Clock (se o jogo usar)
        targetWorldClock = 1,
        
        -- Propriedades extras para travar
        lockExtraProperties = true,
        
        -- Valores de iluminação
        brightness = 2,
        ambient = Color3.fromRGB(128, 128, 128),
        outdoorAmbient = Color3.fromRGB(200, 200, 200),
        
        -- Usar fallback RenderStepped se signals não funcionarem
        useFallback = false,
    },
    
    -- ═══════════════════════════════════════════════
    -- MÉTRICAS
    -- ═══════════════════════════════════════════════
    _metrics = {
        interceptCount = 0,
        lastInterceptTime = 0,
    },
}

-- ============================================================================
-- DETECTAR SISTEMA DE CLOCK DO JOGO
-- ============================================================================

function AlwaysDay:_detectClockSystem()
    -- Verificar se o jogo usa WorldInfo.Clock (sistema custom)
    local worldInfo = workspace:FindFirstChild("WorldInfo")
    if worldInfo then
        local clock = worldInfo:FindFirstChild("Clock")
        if clock and (clock:IsA("NumberValue") or clock:IsA("IntValue")) then
            return "worldinfo", clock
        end
    end
    
    -- Fallback: usar Lighting padrão do Roblox
    return "lighting", Lighting
end

-- ============================================================================
-- TRAVAR PROPRIEDADES DO LIGHTING (PADRÃO ROBLOX)
-- ============================================================================

function AlwaysDay:_lockLighting()
    -- Forçar valores iniciais
    Lighting.ClockTime = self._config.targetClockTime
    
    if self._config.lockExtraProperties then
        Lighting.Brightness = self._config.brightness
        Lighting.Ambient = self._config.ambient
        Lighting.OutdoorAmbient = self._config.outdoorAmbient
    end
    
    -- ═══════════════════════════════════════════════
    -- INTERCEPTAR ClockTime
    -- ═══════════════════════════════════════════════
    ConnectionManager:Add("alwaysDay_clockTime", 
        Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
            if not self._active then return end
            
            -- Só corrige se mudou significativamente
            if math.abs(Lighting.ClockTime - self._config.targetClockTime) > 0.01 then
                Lighting.ClockTime = self._config.targetClockTime
                self._metrics.interceptCount = self._metrics.interceptCount + 1
                self._metrics.lastInterceptTime = tick()
            end
        end), "alwaysDay")
    
    -- ═══════════════════════════════════════════════
    -- INTERCEPTAR TimeOfDay (alguns jogos usam isso)
    -- ═══════════════════════════════════════════════
    ConnectionManager:Add("alwaysDay_timeOfDay", 
        Lighting:GetPropertyChangedSignal("TimeOfDay"):Connect(function()
            if not self._active then return end
            
            if Lighting.TimeOfDay ~= self._config.targetTimeOfDay then
                Lighting.TimeOfDay = self._config.targetTimeOfDay
                self._metrics.interceptCount = self._metrics.interceptCount + 1
            end
        end), "alwaysDay")
    
    -- ═══════════════════════════════════════════════
    -- INTERCEPTAR PROPRIEDADES EXTRAS (opcional)
    -- ═══════════════════════════════════════════════
    if self._config.lockExtraProperties then
        ConnectionManager:Add("alwaysDay_brightness", 
            Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
                if not self._active then return end
                Lighting.Brightness = self._config.brightness
            end), "alwaysDay")
        
        ConnectionManager:Add("alwaysDay_ambient", 
            Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
                if not self._active then return end
                Lighting.Ambient = self._config.ambient
            end), "alwaysDay")
        
        ConnectionManager:Add("alwaysDay_outdoorAmbient", 
            Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function()
                if not self._active then return end
                Lighting.OutdoorAmbient = self._config.outdoorAmbient
            end), "alwaysDay")
    end
end

-- ============================================================================
-- TRAVAR WORLDINFO.CLOCK (SISTEMA CUSTOM)
-- ============================================================================

function AlwaysDay:_lockWorldInfo(clockValue)
    if not clockValue then return end
    
    -- Forçar valor inicial
    clockValue.Value = self._config.targetWorldClock
    
    -- Interceptar mudanças
    ConnectionManager:Add("alwaysDay_worldClock", 
        clockValue:GetPropertyChangedSignal("Value"):Connect(function()
            if not self._active then return end
            
            if clockValue.Value ~= self._config.targetWorldClock then
                clockValue.Value = self._config.targetWorldClock
                self._metrics.interceptCount = self._metrics.interceptCount + 1
                self._metrics.lastInterceptTime = tick()
            end
        end), "alwaysDay")
    
    -- Também travar o Lighting para garantir
    self:_lockLighting()
end

-- ============================================================================
-- FALLBACK: RENDERSTEP (ÚLTIMO RECURSO)
-- ============================================================================

function AlwaysDay:_startFallbackLoop()
    ConnectionManager:Add("alwaysDay_fallback", RunService.RenderStepped:Connect(function()
        if not self._active then return end
        
        -- WorldInfo.Clock
        local worldInfo = workspace:FindFirstChild("WorldInfo")
        if worldInfo then
            local clock = worldInfo:FindFirstChild("Clock")
            if clock and (clock:IsA("NumberValue") or clock:IsA("IntValue")) then
                if clock.Value ~= self._config.targetWorldClock then
                    clock.Value = self._config.targetWorldClock
                end
            end
        end
        
        -- Lighting
        if math.abs(Lighting.ClockTime - self._config.targetClockTime) > 0.01 then
            Lighting.ClockTime = self._config.targetClockTime
        end
        
    end), "alwaysDay")
end

-- ============================================================================
-- ENABLE / DISABLE
-- ============================================================================

function AlwaysDay:Enable(clockTime)
    if self._active then return end
    
    self._active = true
    
    -- Atualizar horário alvo se fornecido
    if clockTime then
        self._config.targetClockTime = clockTime
        self._config.targetTimeOfDay = string.format("%02d:00:00", clockTime)
    end
    
    -- Detectar sistema do jogo
    local mode, target = self:_detectClockSystem()
    self._mode = mode
    
    -- ═══════════════════════════════════════════════
    -- INICIAR INTERCEPTAÇÃO BASEADA NO MODO
    -- ═══════════════════════════════════════════════
    if mode == "worldinfo" then
        self:_lockWorldInfo(target)
        Notifications:Send("🌞 Sempre Dia", "Ativado (WorldInfo)", 2)
    elseif mode == "lighting" then
        self:_lockLighting()
        Notifications:Send("🌞 Sempre Dia", "Ativado (Lighting)", 2)
    end
    
    -- Fallback se configurado
    if self._config.useFallback then
        self:_startFallbackLoop()
    end
    
    Config.AlwaysDay = true
end

function AlwaysDay:Disable()
    if not self._active then return end
    
    self._active = false
    self._mode = nil
    
    -- Remover todas as conexões
    ConnectionManager:RemoveCategory("alwaysDay")
    
    Config.AlwaysDay = false
    
    Notifications:Send("🌞 Sempre Dia", "Desativado", 2)
end

function AlwaysDay:Toggle(state)
    if state == nil then
        state = not self._active
    end
    
    if state then
        self:Enable()
    else
        self:Disable()
    end
end

-- ============================================================================
-- CONFIGURAÇÃO
-- ============================================================================

function AlwaysDay:SetTime(clockTime)
    self._config.targetClockTime = clockTime
    self._config.targetTimeOfDay = string.format("%02d:00:00", math.floor(clockTime))
    
    -- Aplicar imediatamente se ativo
    if self._active then
        Lighting.ClockTime = clockTime
        
        local worldInfo = workspace:FindFirstChild("WorldInfo")
        if worldInfo then
            local clock = worldInfo:FindFirstChild("Clock")
            if clock then
                clock.Value = self._config.targetWorldClock
            end
        end
    end
end

function AlwaysDay:SetBrightness(brightness)
    self._config.brightness = brightness
    if self._active then
        Lighting.Brightness = brightness
    end
end

function AlwaysDay:Configure(options)
    if options.clockTime then
        self:SetTime(options.clockTime)
    end
    
    if options.brightness then
        self._config.brightness = options.brightness
    end
    
    if options.ambient then
        self._config.ambient = options.ambient
    end
    
    if options.outdoorAmbient then
        self._config.outdoorAmbient = options.outdoorAmbient
    end
    
    if options.lockExtraProperties ~= nil then
        self._config.lockExtraProperties = options.lockExtraProperties
    end
    
    if options.useFallback ~= nil then
        self._config.useFallback = options.useFallback
    end
    
    if options.targetWorldClock then
        self._config.targetWorldClock = options.targetWorldClock
    end
end

-- ============================================================================
-- GETTERS
-- ============================================================================

function AlwaysDay:IsActive()
    return self._active
end

function AlwaysDay:GetMode()
    return self._mode
end

function AlwaysDay:GetConfig()
    return {
        targetClockTime = self._config.targetClockTime,
        targetTimeOfDay = self._config.targetTimeOfDay,
        targetWorldClock = self._config.targetWorldClock,
        brightness = self._config.brightness,
        lockExtraProperties = self._config.lockExtraProperties,
        useFallback = self._config.useFallback,
    }
end

function AlwaysDay:GetMetrics()
    return {
        active = self._active,
        mode = self._mode or "none",
        interceptCount = self._metrics.interceptCount,
        lastInterceptTime = self._metrics.lastInterceptTime > 0 
            and string.format("%.1fs ago", tick() - self._metrics.lastInterceptTime)
            or "never",
    }
end

-- ============================================================================
-- EXPORT
-- ============================================================================

_G.MineHub = _G.MineHub or {}
_G.MineHub.AlwaysDay = AlwaysDay

return AlwaysDay