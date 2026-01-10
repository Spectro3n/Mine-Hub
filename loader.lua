-- ============================================================================
-- MINE-HUB LOADER v5.0
-- ============================================================================
-- GitHub Repository: https://github.com/YOUR_USERNAME/Mine-Hub
-- Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/Mine-Hub/main/loader.lua"))()
-- ============================================================================

local REPO_URL = "https://raw.githubusercontent.com/Spectro3n/Mine-Hub/main/src/"

-- ============================================================================
-- LOADER SYSTEM
-- ============================================================================
local LoadedModules = {}

local function LoadModule(path)
    if LoadedModules[path] then
        return LoadedModules[path]
    end
    
    local url = REPO_URL .. path
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success then
        error("[Mine-Hub] Falha ao carregar: " .. path .. "\n" .. tostring(result))
    end
    
    local func, loadErr = loadstring(result)
    if not func then
        error("[Mine-Hub] Erro ao compilar: " .. path .. "\n" .. tostring(loadErr))
    end
    
    local moduleResult = func()
    LoadedModules[path] = moduleResult
    return moduleResult
end

-- ============================================================================
-- VERIFICAÇÃO DE JOGO
-- ============================================================================
local SUPPORTED_GAMES = {
    [12916540959] = true, -- Minecraft (exemplo)
}

if not SUPPORTED_GAMES[game.PlaceId] then
    warn("[Mine-Hub] Este jogo pode não ser suportado!")
end

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================
print("🚀 [Mine-Hub] Iniciando carregamento...")

-- Carregar módulos na ordem correta
local Init = LoadModule("Core/Init.lua")

-- Inicializar sistema
Init()