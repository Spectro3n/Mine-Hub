-- ============================================================================
-- CONFIG - Configurações globais mutáveis
-- ============================================================================

local Config = {
    Enabled = false,
    ShowHighlight = true,
    ShowBillboard = true,
    MakeInvisible = true,
    SafeMode = false,
    PlayerESP = true,
    MobESP = true,
    ItemESP = true,
    ShowHealth = true,
    ShowArmor = true,
    ShowDistance = true,
    ShowHitboxESP = true,
    ExpandHitbox = false,
    HitboxSize = Vector3.new(6, 6, 6),
    ShowAdminESP = true,
    AlwaysDay = false,
    WaterWalk = false,
}

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

_G.MineHub = _G.MineHub or {}
_G.MineHub.Config = Config

return Config