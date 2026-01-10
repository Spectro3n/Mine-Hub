-- ============================================================================
-- CONFIG.lua - Configurações globais mutáveis
-- ============================================================================

local Config = {
    -- Estado principal
    Enabled = false,
    
    -- Visuais de minério
    ShowHighlight = true,
    ShowBillboard = true,
    MakeInvisible = true,
    
    -- Safe Mode
    SafeMode = false,
    
    -- World ESP toggles
    PlayerESP = true,
    MobESP = true,
    ItemESP = true,
    
    -- Informações exibidas
    ShowHealth = true,
    ShowArmor = true,
    ShowDistance = true,
    
    -- Hitbox
    ShowHitboxESP = true,
    ExpandHitbox = false,
    HitboxSize = Vector3.new(6, 6, 6),
    
    -- Admin
    ShowAdminESP = true,
    
    -- Ambiente
    AlwaysDay = false,
    WaterWalk = false,
}

-- Função para resetar configurações
function Config:Reset()
    self.Enabled = false
    self.ShowHighlight = true
    self.ShowBillboard = true
    self.MakeInvisible = true
    self.SafeMode = false
    self.PlayerESP = true
    self.MobESP = true
    self.ItemESP = true
    self.ShowHealth = true
    self.ShowArmor = true
    self.ShowDistance = true
    self.ShowHitboxESP = true
    self.ExpandHitbox = false
    self.HitboxSize = Vector3.new(6, 6, 6)
    self.ShowAdminESP = true
    self.AlwaysDay = false
    self.WaterWalk = false
end

-- Função para obter todas as configurações como tabela
function Config:GetAll()
    local result = {}
    for key, value in pairs(self) do
        if type(value) ~= "function" then
            result[key] = value
        end
    end
    return result
end

-- Expor globalmente para acesso fácil
_G.MineHub = _G.MineHub or {}
_G.MineHub.Config = Config

return Config