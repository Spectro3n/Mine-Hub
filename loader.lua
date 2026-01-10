-- ============================================================================
-- MINE-HUB LOADER v1.1 - CORRIGIDO
-- ============================================================================

local REPO_BASE = "https://raw.githubusercontent.com/Spectro3n/Mine-Hub/main/src/"

-- Armazenamento global de módulos
_G.MineHubModules = _G.MineHubModules or {}
_G.MineHub = _G.MineHub or {}

local Modules = _G.MineHubModules

local function normalizePath(path)
    path = path:gsub("\\", "/")
    if not path:match("%.lua$") then
        path = path .. ".lua"
    end
    path = path:gsub("^%./", "")
    path = path:gsub("//+", "/")
    return path
end

local function fetchWithRetries(url, tries)
    tries = tries or 3
    local lastErr = "Unknown error"
    
    for i = 1, tries do
        local ok, result = pcall(function()
            return game:HttpGet(url, true)
        end)
        
        if ok and type(result) == "string" and #result > 0 and not result:match("^404") then
            return result, nil
        end
        
        lastErr = tostring(result)
        task.wait(0.3 * i)
    end
    
    return nil, lastErr
end

-- Função require global
local function MineHubRequire(path)
    path = normalizePath(path)
    
    -- Já carregado?
    if Modules[path] and Modules[path].__loaded then
        return Modules[path].exports
    end
    
    -- Está carregando? (dependência circular)
    if Modules[path] and Modules[path].__loading then
        return Modules[path].exports
    end
    
    -- Criar placeholder
    Modules[path] = {
        __loading = true,
        __loaded = false,
        exports = {}
    }
    
    local url = REPO_BASE .. path
    print("[Loader] Baixando: " .. path)
    
    local code, err = fetchWithRetries(url, 3)
    
    if not code then
        Modules[path] = nil
        error("[Loader] Falha ao baixar " .. path .. ": " .. tostring(err))
    end
    
    -- Compilar
    local func, compileErr = loadstring(code, "@" .. path)
    if not func then
        Modules[path] = nil
        error("[Loader] Erro de compilação em " .. path .. ": " .. tostring(compileErr))
    end
    
    -- Criar ambiente
    local moduleExports = Modules[path].exports
    
    local env = setmetatable({
        require = MineHubRequire,
        module = { exports = moduleExports },
        exports = moduleExports,
        _G = _G,
        game = game,
        workspace = workspace,
        script = { Parent = { Parent = {} } },
    }, { __index = getfenv(0) })
    
    setfenv(func, env)
    
    -- Executar
    local ok, result = pcall(func)
    
    if not ok then
        Modules[path] = nil
        error("[Loader] Erro ao executar " .. path .. ": " .. tostring(result))
    end
    
    -- Processar retorno
    if result ~= nil then
        Modules[path].exports = result
    elseif env.module and env.module.exports and next(env.module.exports) then
        Modules[path].exports = env.module.exports
    end
    
    Modules[path].__loading = false
    Modules[path].__loaded = true
    
    print("[Loader] ✅ Carregado: " .. path)
    
    return Modules[path].exports
end

-- Expor globalmente
_G.MineHubRequire = MineHubRequire
_G.MineHub.Require = MineHubRequire
_G.MineHub.Modules = Modules

-- Iniciar
print("🚀 Mine-Hub Loader v1.1")
print("📦 Iniciando carregamento...")

local success, err = pcall(function()
    MineHubRequire("Core/Init")
end)

if not success then
    warn("❌ Erro ao carregar Mine-Hub:")
    warn(tostring(err))
else
    print("✅ Mine-Hub carregado com sucesso!")
end