-- ============================================================================
-- CONSTANTS - Todas as constantes do sistema
-- ============================================================================

local Constants = {}

Constants.VERSION = "5.5"
Constants.BUILD = "modular"

Constants.TOGGLE_KEY = Enum.KeyCode.R
Constants.INVISIBLE_ID = "75880927"
Constants.AUTO_DISABLE_ON_ADMIN = true

Constants.MINERALS = {
    ["88662911730235"] = {name = "Diamond", color = Color3.fromRGB(0, 170, 255), priority = 3},
    ["82164848622194"] = {name = "Iron", color = Color3.fromRGB(235, 235, 235), priority = 2},
    ["3502987719"]     = {name = "Gold", color = Color3.fromRGB(255, 215, 90), priority = 4},
    ["73240653680711"] = {name = "Coal", color = Color3.fromRGB(40, 40, 40), priority = 1},
}

Constants.MOBS = {
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
}

Constants.LIQUID_KEYWORDS = {
    "Still", "Falling", "1", "1T", "2", "2T", "3", "3T",
    "4", "4T", "5", "5T", "6", "6T","6F", "7", "7T", "7F",
    "1i", "2i", "3i", "4i", "5i", "6i", "7i",
}

Constants.COLORS = {
    PLAYER = Color3.fromRGB(0, 255, 255),
    PLAYER_OUTLINE = Color3.fromRGB(0, 200, 255),
    MOB = Color3.fromRGB(255, 200, 0),
    MOB_OUTLINE = Color3.fromRGB(255, 150, 0),
    ITEM = Color3.fromRGB(255, 255, 100),
    ITEM_OUTLINE = Color3.fromRGB(255, 200, 0),
    ADMIN = Color3.fromRGB(255, 60, 60),
    ADMIN_OUTLINE = Color3.fromRGB(255, 0, 0),
    HEALTH_HIGH = Color3.fromRGB(80, 255, 80),
    HEALTH_MID = Color3.fromRGB(255, 200, 80),
    HEALTH_LOW = Color3.fromRGB(255, 80, 80),
}

return Constants