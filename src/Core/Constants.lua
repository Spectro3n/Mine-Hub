-- ============================================================================
-- CONSTANTS - Todas as constantes do projeto
-- ============================================================================

return {
    -- Controles
    TOGGLE_KEY = Enum.KeyCode.R,
    UI_KEY = Enum.KeyCode.K,
    
    -- IDs
    INVISIBLE_ID = "75880927",
    
    -- Configurações de Admin
    AUTO_DISABLE_ON_ADMIN = true,
    
    -- Minerais
    MINERALS = {
        ["88662911730235"] = {name = "Diamond", color = Color3.fromRGB(0, 170, 255), priority = 3},
        ["82164848622194"] = {name = "Iron", color = Color3.fromRGB(235, 235, 235), priority = 2},
        ["3502987719"] = {name = "Gold", color = Color3.fromRGB(255, 215, 90), priority = 4},
        ["73240653680711"] = {name = "Coal", color = Color3.fromRGB(40, 40, 40), priority = 1},
    },
    
    -- Mobs
    MOBS = {
        chicken = true, zombie = true, cow = true, pig = true,
        sheep = true, spider = true, skeleton = true, creeper = true,
        enderman = true, wolf = true, rabbit = true, villager = true,
        slime = true, bat = true, squid = true, horse = true,
        donkey = true, mule = true, ocelot = true, cat = true,
        parrot = true, fox = true, bee = true, goat = true,
        axolotl = true, glow_squid = true, warden = true,
        blaze = true, ghast = true, magma_cube = true,
        piglin = true, hoglin = true, zoglin = true,
        wither_skeleton = true, stray = true, husk = true,
        drowned = true, phantom = true, ravager = true,
        pillager = true, vindicator = true, evoker = true,
        witch = true, guardian = true, elder_guardian = true,
        shulker = true, endermite = true, silverfish = true,
        cave_spider = true, iron_golem = true, snow_golem = true,
    },
    
    -- Palavras-chave de líquidos
    LIQUID_KEYWORDS = {
        "Still", "Falling", "1", "1T", "2", "2T", "3", "3T",
        "4", "4T", "5", "5T", "6", "6T", "7", "7T", "7F",
        "1i", "2i", "3i", "4i", "5i", "6i", "7i",
    },
    
    -- Serviços do Roblox (cache)
    Services = {
        Players = game:GetService("Players"),
        UserInputService = game:GetService("UserInputService"),
        RunService = game:GetService("RunService"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
    },
    
    -- Versão
    VERSION = "5.0",
}