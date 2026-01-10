-- ============================================================================
-- MINE-HUB LOADER v1.0
-- Entry point para loadstring
-- ============================================================================

local REPO_BASE = "https://raw.githubusercontent.com/Spectro3n/Mine-Hub/main/src/"
local CDN_BASE = "https://cdn.jsdelivr.net/gh/Spectro3n/Mine-Hub@main/src/"

local Modules = {}
local LoadOrder = {}

local function normalizePath(path)
    if not path:match("%.lua$") then
        path = path .. ".lua"
    end
    path = path:gsub("%./", "")
    return path
end

local function fetchWithRetries(url, tries)
    tries = tries or 3
    local lastErr
    for i = 1, tries do
        local ok, ret = pcall(function() 
            return game:HttpGet(url) 
        end)
        if ok and type(ret) == "string" and #ret > 0 then
            return ret
        end
        lastErr = ret
        task.wait(0.25 * i)
    end
    return nil, lastErr
end

local function LoadModule(path)
    path = normalizePath(path)

    local mod = Modules[path]
    if mod and not mod.__loading then
        return mod.exports or mod
    end

    if mod and mod.__loading then
        return mod.exports
    end

    Modules[path] = { __loading = true, exports = {} }
    local placeholder = Modules[path]

    local url = REPO_BASE .. path
    local code, fetchErr = fetchWithRetries(url, 3)
    
    if not code then
        local cdn = CDN_BASE .. path
        code, fetchErr = fetchWithRetries(cdn, 2)
    end

    if not code then
        Modules[path] = nil
        error(("[Loader] Falha ao baixar %s: %s"):format(path, tostring(fetchErr)))
    end

    local function customRequire(reqPath)
        reqPath = normalizePath(reqPath)
        if Modules[reqPath] and not Modules[reqPath].__loading then
            return Modules[reqPath].exports or Modules[reqPath]
        end
        return LoadModule(reqPath)
    end

    local env = {
        require = customRequire,
        exports = placeholder.exports,
        module = { exports = placeholder.exports },
        script = { Parent = { Parent = {} } },
        _G = _G,
        game = game,
        workspace = workspace,
        task = task,
        wait = wait,
        spawn = spawn,
        delay = delay,
        tick = tick,
        time = time,
        typeof = typeof,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        pcall = pcall,
        xpcall = xpcall,
        error = error,
        warn = warn,
        print = print,
        tostring = tostring,
        tonumber = tonumber,
        string = string,
        table = table,
        math = math,
        coroutine = coroutine,
        debug = debug,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        rawget = rawget,
        rawset = rawset,
        select = select,
        unpack = unpack or table.unpack,
        Instance = Instance,
        Vector3 = Vector3,
        Vector2 = Vector2,
        CFrame = CFrame,
        Color3 = Color3,
        UDim2 = UDim2,
        UDim = UDim,
        Enum = Enum,
        Ray = Ray,
        RaycastParams = RaycastParams,
        loadstring = loadstring,
        getfenv = getfenv,
        setfenv = setfenv,
    }
    setmetatable(env, { __index = getfenv() })

    local func, compileErr = loadstring(code, "@" .. path)
    if not func then
        Modules[path] = nil
        error(("[Loader] Erro de compilação em %s: %s"):format(path, tostring(compileErr)))
    end

    setfenv(func, env)
    local ok, res = pcall(func)
    if not ok then
        Modules[path] = nil
        error(("[Loader] Erro ao executar %s: %s\n%s"):format(path, tostring(res), debug.traceback()))
    end

    if res ~= nil then
        if type(res) == "table" then
            Modules[path] = { exports = res }
        else
            Modules[path] = { exports = res }
        end
    else
        Modules[path] = { exports = env.module.exports }
    end

    Modules[path].__loading = nil
    table.insert(LoadOrder, path)

    return Modules[path].exports
end

-- Expor globalmente
_G.MineHub = _G.MineHub or {}
_G.MineHub.Loader = {
    LoadModule = LoadModule,
    Modules = Modules,
    LoadOrder = LoadOrder,
}

-- Iniciar carregando o Init
print("🚀 Mine-Hub Loader v1.0")
print("📦 Carregando módulos...")

local success, err = pcall(function()
    LoadModule("Core/Init.lua")
end)

if not success then
    warn("❌ Erro ao carregar Mine-Hub: " .. tostring(err))
else
    print("✅ Mine-Hub carregado com sucesso!")
end