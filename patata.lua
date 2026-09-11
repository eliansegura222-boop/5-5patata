local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local CATALOG_URL = "https://raw.githubusercontent.com/NonyH/universalh3xa/refs/heads/main/loaders.lua"
local DISCORD_URL = "https://discord.gg/sewRzHAG5J"
local KEY_URL = "https://raw.githubusercontent.com/eliansegura222-boop/5-5patata/refs/heads/main/key.lua"
local VIP_URL = "https://raw.githubusercontent.com/eliansegura222-boop/5-5patata/refs/heads/main/hx4v1p.lua"

local LANGUAGE_FILE = "H3X4_loader_language.txt"
local FAVORITES_FILE = "H3X4_loader_favorites.json"
local KEY_FILE = "H3X4_loader_key.json"
local sessionEnv = (typeof(getgenv) == "function" and getgenv()) or _G

-- VIP status resolved during key flow (before catalog/cards)
local userIsVip = false

local translations = {
    es = {
        loaderSubtitle = "Cargador Universal",
        scripts = "SCRIPTS",
        script = "SCRIPT",
        search = "Buscar script...",
        loadingScripts = "Cargando scripts...",
        noResults = "NO SE ENCONTRARON RESULTADOS",
        execute = "EJECUTAR",
        loading = "CARGANDO...",
        preparing = "Preparando %s...",
        loadError = "Error al cargar %s",
        available = "%d scripts disponibles.",
        oneAvailable = "1 script disponible.",
        results = "%d resultados",
        oneResult = "1 resultado",
        catalogError = "Error al cargar loaders.lua",
        catalogTableError = "loaders.lua debe devolver una tabla",
        boatFallback = "Script diseñado para Build A Boat For Treasure.",
        universalFallback = "Script universal con herramientas y funciones para múltiples juegos.",
        genericFallback = "Script disponible en el cargador universal H3X4.",
        discordCopied = "Enlace de Discord copiado al portapapeles.",
        discordCopyFailed = "No se pudo copiar el enlace de Discord.",
        keyDiscordCopied = "Discord copiado correctamente, ve al canal #🔑 • key para obtener tu key.",
        betaVipLocked = "ESTA VERSIÓN BETA ES DE ACCESO ANTICIPADO SOLO PARA USUARIOS VIP. VUELVE EN 2 DÍAS; SE PUBLICARÁ OFICIALMENTE PARA TODOS.",
        vipOnlyLocked = "Este script es solo para usuarios VIP.",
        maintenanceLocked = "Este script está en mantenimiento, pronto regresará.",
        details = "DETALLES",
        detailsTitle = "DETALLES DEL SCRIPT",
        closeDetails = "CERRAR",
        favoriteAdded = "Añadido a favoritos.",
        favoriteRemoved = "Eliminado de favoritos.",
        version = "Versión",
        updated = "Actualizado",
        author = "Autor",
        game = "Juego",
        tag = "Etiqueta",
        raw = "RAW",
        enabled = "Disponible",
        yes = "Sí",
        no = "No",
        noExtraInfo = "Sin información adicional.",
        keyTitle = "VERIFICAR KEY",
        keySubtitle = "Introduce la key para continuar",
        keyPlaceholder = "Escribe tu key...",
        verifyKey = "VERIFICAR",
        getKeyDiscord = "CONSEGUIR (DC)",
        rememberKey = "RECORDAR KEY POR 24H",
        checkingKey = "VERIFICANDO...",
        validKey = "KEY CORRECTA",
        invalidKey = "KEY INCORRECTA",
        keyLoadError = "No se pudo cargar la key. Inténtalo de nuevo.",
    },
    en = {
        loaderSubtitle = "Universal Loader",
        scripts = "SCRIPTS",
        script = "SCRIPT",
        search = "Search script...",
        loadingScripts = "Loading scripts...",
        noResults = "NO RESULTS FOUND",
        execute = "RUN",
        loading = "LOADING...",
        preparing = "Preparing %s...",
        loadError = "Failed to load %s",
        available = "%d scripts available.",
        oneAvailable = "1 script available.",
        results = "%d results",
        oneResult = "1 result",
        catalogError = "Failed to load loaders.lua",
        catalogTableError = "loaders.lua must return a table",
        boatFallback = "Script designed for Build A Boat For Treasure.",
        universalFallback = "Universal script with tools and features for multiple games.",
        genericFallback = "Script available in the H3X4 universal loader.",
        discordCopied = "Discord invite copied to clipboard.",
        discordCopyFailed = "Could not copy the Discord invite.",
        keyDiscordCopied = "Discord copied successfully. Go to #🔑 • key to get your key.",
        betaVipLocked = "THIS BETA VERSION IS EARLY ACCESS FOR VIP USERS ONLY. COME BACK IN 2 DAYS; IT WILL THEN BE OFFICIALLY RELEASED FOR EVERYONE.",
        vipOnlyLocked = "This script is for VIP users only.",
        maintenanceLocked = "This script is under maintenance. It will be back soon.",
        details = "DETAILS",
        detailsTitle = "SCRIPT DETAILS",
        closeDetails = "CLOSE",
        favoriteAdded = "Added to favorites.",
        favoriteRemoved = "Removed from favorites.",
        version = "Version",
        updated = "Updated",
        author = "Author",
        game = "Game",
        tag = "Tag",
        raw = "RAW",
        enabled = "Available",
        yes = "Yes",
        no = "No",
        noExtraInfo = "No additional information.",
        keyTitle = "KEY VERIFICATION",
        keySubtitle = "Enter the key to continue",
        keyPlaceholder = "Enter your key...",
        verifyKey = "VERIFY",
        getKeyDiscord = "GET (DC)",
        rememberKey = "REMEMBER KEY FOR 24H",
        checkingKey = "VERIFYING...",
        validKey = "KEY VERIFIED",
        invalidKey = "INVALID KEY",
        keyLoadError = "Could not load the key. Try again.",
    },

}

local function validLanguage(code)
    return code == "es" or code == "en"
end

local function readRememberedLanguage()
    local code = sessionEnv.H3X4LoaderLanguage
    if validLanguage(code) then
        return code
    end

    if type(isfile) == "function" and type(readfile) == "function" then
        local okExists, exists = pcall(isfile, LANGUAGE_FILE)
        if okExists and exists then
            local okRead, saved = pcall(readfile, LANGUAGE_FILE)
            if okRead then
                saved = tostring(saved):match("^%s*(.-)%s*$")
                if validLanguage(saved) then
                    sessionEnv.H3X4LoaderLanguage = saved
                    return saved
                end
            end
        end
    end

    return nil
end

local rememberedLanguage = readRememberedLanguage()
local currentLanguage = rememberedLanguage or "es"

local function T(key)
    local lang = translations[currentLanguage] or translations.es
    return lang[key] or translations.es[key] or key
end

local function saveLanguage(code)
    if not validLanguage(code) then
        return false
    end

    sessionEnv.H3X4LoaderLanguage = code
    rememberedLanguage = code

    if type(writefile) == "function" then
        local ok = pcall(writefile, LANGUAGE_FILE, code)
        return ok
    end

    return false
end

local function clearRememberedLanguage()
    sessionEnv.H3X4LoaderLanguage = nil
    rememberedLanguage = nil

    if type(isfile) == "function" and type(delfile) == "function" then
        pcall(function()
            if isfile(LANGUAGE_FILE) then
                delfile(LANGUAGE_FILE)
            end
        end)
    end
end

local function clearRememberedKey()
    sessionEnv.H3X4LoaderRememberedKey = nil
    if type(isfile) == "function" and type(delfile) == "function" then
        pcall(function()
            if isfile(KEY_FILE) then
                delfile(KEY_FILE)
            end
        end)
    end
end

local function readRememberedKey()
    local saved = sessionEnv.H3X4LoaderRememberedKey
    if type(saved) == "table" then
        local expires = tonumber(saved.expires) or 0
        if tostring(saved.key or "") ~= "" and expires > os.time() then
            return saved
        end
    end

    if type(isfile) == "function" and type(readfile) == "function" then
        local okExists, exists = pcall(isfile, KEY_FILE)
        if okExists and exists then
            local okRead, raw = pcall(readfile, KEY_FILE)
            if okRead and type(raw) == "string" and raw ~= "" then
                local okDecode, data = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if okDecode and type(data) == "table" then
                    local expires = tonumber(data.expires) or 0
                    if tostring(data.key or "") ~= "" and expires > os.time() then
                        sessionEnv.H3X4LoaderRememberedKey = data
                        return data
                    end
                end
            end
        end
    end

    clearRememberedKey()
    return nil
end

local function saveRememberedKey(key)
    local data = {
        key = tostring(key or ""),
        expires = os.time() + (24 * 60 * 60),
    }
    sessionEnv.H3X4LoaderRememberedKey = data

    if type(writefile) == "function" then
        pcall(function()
            writefile(KEY_FILE, HttpService:JSONEncode(data))
        end)
    end
end

local function loadKeyConfig()
    local ok, result = pcall(function()
        local src = game:HttpGet(KEY_URL, true)
        src = tostring(src or ""):gsub("^\239\187\191", "")
        local fn, err = loadstring(src)
        if not fn then
            error(err)
        end
        local data = fn()
        if typeof(data) ~= "table" then
            error("key.lua must return a table")
        end
        return data
    end)

    if not ok then
        return nil, tostring(result)
    end

    return {
        enabled = result.enabled ~= false,
        key = tostring(result.key or ""),
    }
end

local function loadVipStatus()
    local ok, result = pcall(function()
        local separator = string.find(VIP_URL, "?", 1, true) and "&" or "?"
        local src = game:HttpGet(VIP_URL .. separator .. "h3x4=" .. tostring(os.time()), true)
        src = tostring(src or ""):gsub("^\239\187\191", "")
        local fn, err = loadstring(src)
        if not fn then
            error(err)
        end
        local data = fn()
        if typeof(data) ~= "table" then
            error("VIP raw must return a table")
        end
        return data
    end)

    if not ok then
        return false, tostring(result)
    end

    local entry = result[tostring(Player.UserId)]
    if typeof(entry) ~= "table" or entry.vip ~= true then
        return false
    end

    local expires = string.lower(tostring(entry.expires or ""))
    if expires == "permanent" then
        return true
    end

    if expires:match("^%d%d%d%d%-%d%d%-%d%d$") then
        return expires >= os.date("%Y-%m-%d")
    end

    return false
end

local function new(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        o[k] = v
    end
    if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
        o.Font = Enum.Font.Gotham
        o.TextStrokeTransparency = 1
    end
    return o
end

local function round(obj, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or 12)
    c.Parent = obj
    return c
end

local function stroke(obj, transparency)
    local s = Instance.new("UIStroke")
    s.Color = Color3.new(1, 1, 1)
    s.Transparency = transparency or 0.9
    s.Thickness = 1
    s.Parent = obj
    return s
end

local function clampDescription(text)
    text = tostring(text or "")
    if #text <= 180 then
        return text
    end
    return string.sub(text, 1, 177) .. "..."
end

local function fallbackDescription(data)
    local title = tostring(data.Title or "Script")
    local lower = string.lower(title)

    if string.find(lower, "boat", 1, true) then
        return T("boatFallback")
    elseif string.find(lower, "h3x4", 1, true) then
        return T("universalFallback")
    end

    return T("genericFallback")
end

local function localizedDescription(data)
    local value

    if currentLanguage == "en" then
        value = data.DescriptionEN or data.DescriptionEn or data.DescriptionEnglish
    else
        value = data.DescriptionES or data.DescriptionEs or data.DescriptionSpanish
    end

    if value == nil or tostring(value) == "" then
        if typeof(data.Description) == "table" then
            value = data.Description[currentLanguage]
                or data.Description[string.upper(currentLanguage)]
                or data.Description.Default
                or data.Description.default
        else
            value = data.Description
        end
    end

    if value ~= nil and tostring(value) ~= "" then
        return clampDescription(tostring(value))
    end

    return clampDescription(fallbackDescription(data))
end

local function localizedTitle(data)
    local value
    if currentLanguage == "en" then
        value = data.TitleEN or data.TitleEn or data.TitleEnglish
    else
        value = data.TitleES or data.TitleEs or data.TitleSpanish
    end

    if value == nil or tostring(value) == "" then
        value = data.Title
    end

    return tostring(value or "Script")
end

local function fullLocalizedDescription(data)
    local value
    if currentLanguage == "en" then
        value = data.DescriptionEN or data.DescriptionEn or data.DescriptionEnglish
    else
        value = data.DescriptionES or data.DescriptionEs or data.DescriptionSpanish
    end

    if value == nil or tostring(value) == "" then
        if typeof(data.Description) == "table" then
            value = data.Description[currentLanguage]
                or data.Description[string.upper(currentLanguage)]
                or data.Description.Default
                or data.Description.default
        else
            value = data.Description
        end
    end

    if value ~= nil and tostring(value) ~= "" then
        return tostring(value)
    end

    return fallbackDescription(data)
end

local function favoriteKey(data)
    local url = tostring(data.URL or "")
    if url ~= "" then
        return url
    end
    return tostring(data.Title or "Script")
end

local favorites = {}

do
    local saved = sessionEnv.H3X4LoaderFavorites
    if typeof(saved) == "table" then
        for k, v in pairs(saved) do
            if v == true then
                favorites[tostring(k)] = true
            end
        end
    end

    if type(isfile) == "function" and type(readfile) == "function" then
        local okExists, exists = pcall(isfile, FAVORITES_FILE)
        if okExists and exists then
            local okRead, raw = pcall(readfile, FAVORITES_FILE)
            if okRead then
                local okDecode, decoded = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if okDecode and typeof(decoded) == "table" then
                    for k, v in pairs(decoded) do
                        if v == true then
                            favorites[tostring(k)] = true
                        end
                    end
                end
            end
        end
    end

    sessionEnv.H3X4LoaderFavorites = favorites
end

local function saveFavorites()
    sessionEnv.H3X4LoaderFavorites = favorites
    if type(writefile) == "function" then
        pcall(function()
            writefile(FAVORITES_FILE, HttpService:JSONEncode(favorites))
        end)
    end
end

local function isFavorite(data)
    return favorites[favoriteKey(data)] == true
end

local function setFavorite(data, value)
    local key = favoriteKey(data)
    if value then
        favorites[key] = true
    else
        favorites[key] = nil
    end
    saveFavorites()
end

local function parseColor(value)
    if typeof(value) == "Color3" then
        return value
    end

    if type(value) == "string" then
        local hex = value:gsub("#", "")
        if #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if r and g and b then
                return Color3.fromRGB(r, g, b)
            end
        end
    elseif typeof(value) == "table" then
        local r = value.R or value.r or value[1]
        local g = value.G or value.g or value[2]
        local b = value.B or value.b or value[3]
        if tonumber(r) and tonumber(g) and tonumber(b) then
            r, g, b = tonumber(r), tonumber(g), tonumber(b)
            if r <= 1 and g <= 1 and b <= 1 then
                return Color3.new(r, g, b)
            end
            return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
        end
    end

    return Color3.new(1, 1, 1)
end

local function rawTagTable(data)
    local tag = data.Tag or data.Label or data.Etiqueta
    if typeof(tag) ~= "table" and typeof(data.Tags) == "table" then
        tag = data.Tags[1]
    end
    return typeof(tag) == "table" and tag or nil
end

local function collectTagNormalizedValues(data)
    local values = {}
    local seen = {}

    local function addValue(value)
        if value == nil then
            return
        end
        -- only accept scalar tags (ignore tables/objects)
        local t = typeof(value)
        if t ~= "string" and t ~= "number" then
            return
        end
        local normalized = tostring(value):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
        if normalized == "" or seen[normalized] then
            return
        end
        seen[normalized] = true
        table.insert(values, normalized)
    end

    local function addFromTag(tag)
        if typeof(tag) ~= "table" then
            return
        end
        addValue(tag.Title)
        addValue(tag.Text)
        addValue(tag.Name)
        addValue(tag.TitleES)
        addValue(tag.TitleEs)
        addValue(tag.TitleSpanish)
        addValue(tag.TitleEN)
        addValue(tag.TitleEn)
        addValue(tag.TitleEnglish)
        addValue(tag.Label)
        addValue(tag.Etiqueta)
    end

    addFromTag(rawTagTable(data))

    if typeof(data.Tags) == "table" then
        for _, tag in ipairs(data.Tags) do
            addFromTag(tag)
        end
    end

    -- also accept plain string tags if present
    addValue(data.Tag)
    addValue(data.Label)
    addValue(data.Etiqueta)

    return values
end

local function tagMatchesAny(data, patterns)
    local values = collectTagNormalizedValues(data)
    for _, value in ipairs(values) do
        for _, pattern in ipairs(patterns) do
            if value == pattern then
                return true
            end
        end
    end
    return false
end

local function isMaintenanceScript(data)
    return tagMatchesAny(data, {
        "mantenimiento",
        "maintenance",
        "en mantenimiento",
        "under maintenance",
    })
end

local function isBetaVipScript(data)
    return tagMatchesAny(data, { "beta vip" })
end

local function isVipOnlyScript(data)
    -- plain VIP tag (not beta vip)
    if isBetaVipScript(data) then
        return false
    end
    return tagMatchesAny(data, { "vip", "solo vip", "vip only", "vip only" })
end

-- Returns lock info for execute button, or nil if free to run.
-- Priority: maintenance (all users) > VIP/Beta VIP (free users only)
local function getExecuteLock(data)
    if isMaintenanceScript(data) then
        return {
            Locked = true,
            Reason = "maintenance",
            MessageKey = "maintenanceLocked",
        }
    end

    -- userIsVip is set in beginKeyFlow before catalog load
    local isVip = userIsVip == true
    if not isVip then
        if isBetaVipScript(data) then
            return {
                Locked = true,
                Reason = "beta_vip",
                MessageKey = "betaVipLocked",
            }
        end
        if isVipOnlyScript(data) then
            return {
                Locked = true,
                Reason = "vip",
                MessageKey = "vipOnlyLocked",
            }
        end
    end

    return nil
end

local function getTag(data)
    local tag = data.Tag or data.Label or data.Etiqueta
    if typeof(tag) ~= "table" and typeof(data.Tags) == "table" then
        tag = data.Tags[1]
    end
    if typeof(tag) ~= "table" then
        return nil
    end

    local title
    if currentLanguage == "en" then
        title = tag.TitleEN or tag.TitleEn or tag.TitleEnglish
    else
        title = tag.TitleES or tag.TitleEs or tag.TitleSpanish
    end

    if title == nil or tostring(title) == "" then
        title = tag.Title or tag.Text or tag.Name
    end

    title = tostring(title or "")
    if title == "" or string.lower(title) == "none" then
        return nil
    end

    return {
        Title = title,
        Color = parseColor(tag.Color or tag.Colour or tag.RGB),
    }
end

local parent = Player:WaitForChild("PlayerGui")
if typeof(gethui) == "function" then
    local ok, p = pcall(gethui)
    if ok and p then
        parent = p
    end
end

local old = parent:FindFirstChild("H3X4UniversalLoader")
if old then
    old:Destroy()
end

local gui = new("ScreenGui", {
    Name = "H3X4UniversalLoader",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = parent,
})

local noticeFrame = new("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.fromOffset(310, 68),
    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 250,
    Parent = gui,
})
round(noticeFrame, 12)
stroke(noticeFrame, 0.38).Thickness = 1.2

local noticeLabel = new("TextLabel", {
    Position = UDim2.fromOffset(12, 8),
    Size = UDim2.new(1, -24, 1, -16),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 251,
    Parent = noticeFrame,
})

local noticeId = 0
local function showNotice(message)
    noticeId += 1
    local id = noticeId
    noticeLabel.Text = tostring(message or "")
    noticeFrame.Visible = true
    noticeFrame.BackgroundTransparency = 0.05
    noticeLabel.TextTransparency = 0
    task.delay(3.4, function()
        if id ~= noticeId or not noticeFrame.Parent then
            return
        end
        local t1 = TweenService:Create(noticeFrame, TweenInfo.new(0.18), {BackgroundTransparency = 1})
        local t2 = TweenService:Create(noticeLabel, TweenInfo.new(0.18), {TextTransparency = 1})
        t1:Play()
        t2:Play()
        task.delay(0.2, function()
            if id == noticeId and noticeFrame.Parent then
                noticeFrame.Visible = false
                noticeFrame.BackgroundTransparency = 0.05
                noticeLabel.TextTransparency = 0
            end
        end)
    end)
end

local overlay = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 1,
    Parent = gui,
})

local main = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(420, 335),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2,
    Parent = gui,
    Visible = false,
})
round(main, 16)
stroke(main, 0.18).Thickness = 1.35

local scale = new("UIScale", {
    Scale = 0.82,
    Parent = main,
})

local galaxy = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2,
    Parent = main,
})
round(galaxy, 16)

local function animateStar(star)
    if not star or not star.Parent or not gui.Parent then
        return
    end

    local target = UDim2.fromScale(
        math.random(0, 1000) / 1000,
        math.random(0, 1000) / 1000
    )
    local duration = math.random(85, 170) / 10

    local tween = TweenService:Create(
        star,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {Position = target}
    )

    tween.Completed:Connect(function()
        if star and star.Parent and gui.Parent then
            animateStar(star)
        end
    end)

    tween:Play()
end

for i = 1, 105 do
    local size = math.random(1, 3)
    local star = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(math.random(), math.random()),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = math.random(8, 48) / 100,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = galaxy,
    })
    round(star, 999)
    animateStar(star)
end

for i = 1, 12 do
    local star = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(math.random(), math.random()),
        Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.62,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = galaxy,
    })
    round(star, 999)
    animateStar(star)
end


local languageScreen = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 50,
    Visible = rememberedLanguage == nil,
    Parent = gui,
})

do
    for i = 1, 145 do
        local size = math.random(1, 3)
        local star = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(math.random(), math.random()),
            Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = math.random(10, 55) / 100,
            BorderSizePixel = 0,
            ZIndex = 51,
            Parent = languageScreen,
        })
        round(star, 999)
        animateStar(star)
    end
end

local languagePanel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(360, 232),
    BackgroundColor3 = Color3.fromRGB(5, 5, 5),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ZIndex = 52,
    Parent = languageScreen,
})
round(languagePanel, 18)
stroke(languagePanel, 0.18).Thickness = 1.4

local languagePanelScale = new("UIScale", {
    Scale = 0.86,
    Parent = languagePanel,
})
if rememberedLanguage == nil then
    TweenService:Create(languagePanelScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

new("TextLabel", {
    Position = UDim2.fromOffset(18, 16),
    Size = UDim2.new(1, -36, 0, 22),
    BackgroundTransparency = 1,
    Text = "SELECT LANGUAGE",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 53,
    Parent = languagePanel,
})

new("TextLabel", {
    Position = UDim2.fromOffset(18, 40),
    Size = UDim2.new(1, -36, 0, 18),
    BackgroundTransparency = 1,
    Text = "Selecciona • Select",
    TextColor3 = Color3.fromRGB(150, 150, 150),
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 53,
    Parent = languagePanel,
})

local rememberChoice = false
local rememberButton = new("TextButton", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -16),
    Size = UDim2.new(1, -36, 0, 34),
    BackgroundColor3 = Color3.fromRGB(16, 16, 16),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Text = "○  RECORDAR IDIOMA / REMEMBER LANGUAGE",
    TextColor3 = Color3.fromRGB(190, 190, 190),
    TextSize = 9,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 53,
    Parent = languagePanel,
})
round(rememberButton, 10)
stroke(rememberButton, 0.76)

local function updateRememberButton()
    rememberButton.Text = (rememberChoice and "●  " or "○  ") .. "RECORDAR IDIOMA / REMEMBER LANGUAGE"
    rememberButton.TextColor3 = rememberChoice and Color3.new(1, 1, 1) or Color3.fromRGB(190, 190, 190)
    rememberButton.BackgroundTransparency = rememberChoice and 0.82 or 0.05
end

rememberButton.MouseButton1Click:Connect(function()
    rememberChoice = not rememberChoice
    if not rememberChoice then
        clearRememberedLanguage()
    end
    updateRememberButton()
end)

updateRememberButton()

local languageButtonsHolder = new("Frame", {
    Position = UDim2.fromOffset(18, 72),
    Size = UDim2.new(1, -36, 0, 86),
    BackgroundTransparency = 1,
    ZIndex = 53,
    Parent = languagePanel,
})

local languageList = new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = languageButtonsHolder,
})

local languageButtonDefs = {
    {code = "es", flag = "🇪🇸", label = "Español"},
    {code = "en", flag = "🇬🇧", label = "English"},
}

local languageChosen = false
local languageCallbacks = {}

for i, info in ipairs(languageButtonDefs) do
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(14, 14, 14),
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Text = info.flag .. "   " .. info.label,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        LayoutOrder = i,
        ZIndex = 54,
        Parent = languageButtonsHolder,
    })
    round(b, 11)
    stroke(b, 0.78)

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.82}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0.06}):Play()
    end)

    b.MouseButton1Click:Connect(function()
        if languageChosen then return end
        languageChosen = true
        currentLanguage = info.code
        if rememberChoice then
            saveLanguage(info.code)
        end
        if languageCallbacks.onSelected then
            languageCallbacks.onSelected()
        end
    end)
end

local keyScreen = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 60,
    Visible = false,
    Parent = gui,
})

for i = 1, 145 do
    local size = math.random(1, 3)
    local star = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(math.random(), math.random()),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = math.random(10, 55) / 100,
        BorderSizePixel = 0,
        ZIndex = 61,
        Parent = keyScreen,
    })
    round(star, 999)
    animateStar(star)
end

local keyPanel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(360, 280),
    BackgroundColor3 = Color3.fromRGB(5, 5, 5),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ZIndex = 62,
    Parent = keyScreen,
})
round(keyPanel, 18)
stroke(keyPanel, 0.18).Thickness = 1.4

local keyPanelScale = new("UIScale", {
    Scale = 0.86,
    Parent = keyPanel,
})

local keyLogo = new("ImageLabel", {
    Position = UDim2.fromOffset(10, 12),
    Size = UDim2.new(1, -20, 0, 72),
    BackgroundTransparency = 1,
    Image = "rbxassetid://85728959011477",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 63,
    Parent = keyPanel,
})

local keyInputFrame = new("Frame", {
    Position = UDim2.fromOffset(18, 94),
    Size = UDim2.new(1, -36, 0, 42),
    BackgroundColor3 = Color3.fromRGB(14, 14, 14),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ZIndex = 63,
    Parent = keyPanel,
})
round(keyInputFrame, 11)
stroke(keyInputFrame, 0.62)

local keyInput = new("TextBox", {
    Position = UDim2.fromOffset(11, 0),
    Size = UDim2.new(1, -22, 1, 0),
    BackgroundTransparency = 1,
    PlaceholderText = T("keyPlaceholder"),
    PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
    Text = "",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 64,
    Parent = keyInputFrame,
})

local rememberKeyChoice = false
local rememberKeyButton = new("TextButton", {
    Position = UDim2.fromOffset(18, 196),
    Size = UDim2.new(1, -36, 0, 36),
    BackgroundColor3 = Color3.fromRGB(22, 22, 22),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 63,
    Parent = keyPanel,
})
round(rememberKeyButton, 10)
local rememberKeyStroke = stroke(rememberKeyButton, 0.46)
rememberKeyStroke.Thickness = 1.2

local rememberKeyIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(16, 16),
    BackgroundTransparency = 1,
    Image = "rbxassetid://284402752",
    ImageColor3 = Color3.new(1, 1, 1),
    ZIndex = 64,
    Parent = rememberKeyButton,
})

local rememberKeyLabel = new("TextLabel", {
    Position = UDim2.new(0, 34, 0, 0),
    Size = UDim2.new(1, -90, 1, 0),
    BackgroundTransparency = 1,
    Text = T("rememberKey"),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 1,
    ZIndex = 64,
    Parent = rememberKeyButton,
})

local rememberKeyTrack = new("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -9, 0.5, 0),
    Size = UDim2.fromOffset(42, 22),
    BackgroundColor3 = Color3.fromRGB(58, 58, 58),
    BorderSizePixel = 0,
    ZIndex = 64,
    Parent = rememberKeyButton,
})
round(rememberKeyTrack, 999)

local rememberKeyKnob = new("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0),
    Size = UDim2.fromOffset(16, 16),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 65,
    Parent = rememberKeyTrack,
})
round(rememberKeyKnob, 999)

local verifyKeyButton = new("TextButton", {
    Position = UDim2.new(0, 18, 0, 148),
    Size = UDim2.new(0.5, -23, 0, 38),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 63,
    Parent = keyPanel,
})
round(verifyKeyButton, 11)

local verifyKeyIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(16, 16),
    BackgroundTransparency = 1,
    Image = "rbxassetid://16571012729",
    ImageColor3 = Color3.new(0, 0, 0),
    ZIndex = 64,
    Parent = verifyKeyButton,
})

local verifyKeyLabel = new("TextLabel", {
    Position = UDim2.new(0, 34, 0, 0),
    Size = UDim2.new(1, -42, 1, 0),
    BackgroundTransparency = 1,
    Text = T("verifyKey"),
    TextColor3 = Color3.new(0, 0, 0),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 64,
    Parent = verifyKeyButton,
})

local getKeyButton = new("TextButton", {
    Position = UDim2.new(0.5, 5, 0, 148),
    Size = UDim2.new(0.5, -23, 0, 38),
    BackgroundColor3 = Color3.fromRGB(24, 24, 24),
    BackgroundTransparency = 0.03,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 63,
    Parent = keyPanel,
})
round(getKeyButton, 10)

local getKeyIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(16, 16),
    BackgroundTransparency = 1,
    Image = "rbxassetid://284402785",
    ImageColor3 = Color3.new(1, 1, 1),
    ZIndex = 64,
    Parent = getKeyButton,
})

local getKeyLabel = new("TextLabel", {
    Position = UDim2.new(0, 34, 0, 0),
    Size = UDim2.new(1, -42, 1, 0),
    BackgroundTransparency = 1,
    Text = T("getKeyDiscord"),
    TextColor3 = Color3.new(1, 1, 1),
    TextStrokeTransparency = 1,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 64,
    Parent = getKeyButton,
})

local keyStatusLabel = new("TextLabel", {
    Position = UDim2.fromOffset(18, 240),
    Size = UDim2.new(1, -36, 0, 18),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(155, 155, 155),
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 63,
    Parent = keyPanel,
})

local function updateRememberKeyButton()
    rememberKeyLabel.Text = T("rememberKey")
    rememberKeyLabel.TextColor3 = Color3.new(1, 1, 1)

    TweenService:Create(
        rememberKeyTrack,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = rememberKeyChoice and Color3.new(1, 1, 1) or Color3.fromRGB(58, 58, 58)}
    ):Play()

    TweenService:Create(
        rememberKeyKnob,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = rememberKeyChoice and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = rememberKeyChoice and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
        }
    ):Play()

    rememberKeyButton.BackgroundColor3 = rememberKeyChoice and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(22, 22, 22)
    rememberKeyStroke.Transparency = rememberKeyChoice and 0.18 or 0.46
    rememberKeyStroke.Thickness = rememberKeyChoice and 1.5 or 1.2
end

local function updateKeyLanguage()
    keyInput.PlaceholderText = T("keyPlaceholder")
    verifyKeyLabel.Text = T("verifyKey")
    getKeyLabel.Text = T("getKeyDiscord")
    updateRememberKeyButton()
end

rememberKeyButton.MouseButton1Click:Connect(function()
    rememberKeyChoice = not rememberKeyChoice
    if not rememberKeyChoice then
        clearRememberedKey()
    end
    updateRememberKeyButton()
end)

getKeyButton.MouseButton1Click:Connect(function()
    local copied = false
    if type(setclipboard) == "function" then
        copied = pcall(setclipboard, DISCORD_URL)
    elseif type(toclipboard) == "function" then
        copied = pcall(toclipboard, DISCORD_URL)
    end
    keyStatusLabel.Text = copied and T("keyDiscordCopied") or T("discordCopyFailed")
    if copied then
        showNotice(T("keyDiscordCopied"))
    end
end)

local content = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 5,
    Parent = main,
})
new("UIPadding", {
    PaddingTop = UDim.new(0, 4),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    Parent = content,
})

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = content,
})

local mainLogo = new("ImageLabel", {
    Position = UDim2.fromOffset(-4, -6),
    Size = UDim2.fromOffset(72, 72),
    BackgroundTransparency = 1,
    Image = "rbxassetid://85728959011477",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 7,
    Parent = header,
})

local discordButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -78, 0.5, 0),
    Size = UDim2.fromOffset(72, 26),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 8,
    Parent = header,
})
round(discordButton, 7)
local discordStroke = Instance.new("UIStroke")
discordStroke.Color = Color3.new(1, 1, 1)
discordStroke.Transparency = 0.2
discordStroke.Thickness = 1.4
discordStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
discordStroke.Parent = discordButton

local discordIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 6, 0.5, 0),
    Size = UDim2.fromOffset(14, 14),
    BackgroundTransparency = 1,
    Image = "rbxassetid://90573058965626",
    ImageColor3 = Color3.new(1, 1, 1),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 9,
    Parent = discordButton,
})

local discordLabel = new("TextLabel", {
    Position = UDim2.fromOffset(22, 0),
    Size = UDim2.new(1, -26, 1, 0),
    BackgroundTransparency = 1,
    Text = "Discord",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextStrokeTransparency = 1,
    ZIndex = 9,
    Parent = discordButton,
})

discordButton.MouseEnter:Connect(function()
    TweenService:Create(discordStroke, TweenInfo.new(0.12), {Thickness = 2, Transparency = 0}):Play()
end)

discordButton.MouseLeave:Connect(function()
    TweenService:Create(discordStroke, TweenInfo.new(0.12), {Thickness = 1.4, Transparency = 0.2}):Play()
end)

local languageButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -40, 0.5, 0),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 7,
    Parent = header,
})
round(languageButton, 999)
local languageStroke = Instance.new("UIStroke")
languageStroke.Color = Color3.new(1, 1, 1)
languageStroke.Transparency = 0.2
languageStroke.Thickness = 1.4
languageStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
languageStroke.Parent = languageButton

local languageIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(15, 15),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6034684930",
    ImageColor3 = Color3.new(1, 1, 1),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 8,
    Parent = languageButton,
})

local close = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 7,
    Parent = header,
})
round(close, 999)
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.new(1, 1, 1)
closeStroke.Transparency = 0.2
closeStroke.Thickness = 1.4
closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeStroke.Parent = close

close.MouseEnter:Connect(function()
    TweenService:Create(closeStroke, TweenInfo.new(0.12), {Thickness = 2, Transparency = 0}):Play()
end)
close.MouseLeave:Connect(function()
    TweenService:Create(closeStroke, TweenInfo.new(0.12), {Thickness = 1.4, Transparency = 0.2}):Play()
end)

local closing = false
local function closeLoader(callback)
    if closing then
        return
    end
    closing = true

    TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.88}):Play()
    TweenService:Create(main, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()

    task.delay(0.19, function()
        if gui and gui.Parent then
            gui:Destroy()
        end
        if callback then
            callback()
        end
    end)
end

close.MouseButton1Click:Connect(function()
    closeLoader()
end)

local searchRow = new("Frame", {
    Position = UDim2.fromOffset(0, 58),
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = content,
})

local searchFrame = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.42, 0, 0.5, 0),
    Size = UDim2.new(0.52, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(14, 14, 14),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = searchRow,
})
round(searchFrame, 8)
local searchStroke = Instance.new("UIStroke")
searchStroke.Color = Color3.new(1, 1, 1)
searchStroke.Transparency = 0.55
searchStroke.Thickness = 1.2
searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
searchStroke.Parent = searchFrame

local searchIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 8, 0.5, 0),
    Size = UDim2.fromOffset(13, 13),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6031154871",
    ImageColor3 = Color3.fromRGB(200, 200, 200),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 7,
    Parent = searchFrame,
})

local search = new("TextBox", {
    Position = UDim2.fromOffset(26, 0),
    Size = UDim2.new(1, -32, 1, 0),
    BackgroundTransparency = 1,
    PlaceholderText = T("search"),
    PlaceholderColor3 = Color3.fromRGB(160, 160, 160),
    Text = "",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 7,
    Parent = searchFrame,
})

search.Focused:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.14), {
        Transparency = 0.15,
        Thickness = 1.6
    }):Play()
end)

search.FocusLost:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.14), {
        Transparency = 0.55,
        Thickness = 1.2
    }):Play()
end)

-- Categories dropdown
local categoryFilter = "all" -- "all" | "favorites"
local refreshCategoryFilter = function() end -- assigned later after rebuildVisibleList

local categoryButton = new("TextButton", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0.7, 4, 0.5, 0),
    Size = UDim2.fromOffset(118, 26),
    BackgroundColor3 = Color3.fromRGB(14, 14, 14),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
    Parent = searchRow,
})
round(categoryButton, 7)
local categoryBtnStroke = Instance.new("UIStroke")
categoryBtnStroke.Color = Color3.new(1, 1, 1)
categoryBtnStroke.Transparency = 0.5
categoryBtnStroke.Thickness = 1.15
categoryBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
categoryBtnStroke.Parent = categoryButton

local categoryLabel = new("TextLabel", {
    Position = UDim2.fromOffset(6, 0),
    Size = UDim2.new(1, -12, 1, 0),
    BackgroundTransparency = 1,
    Text = (currentLanguage == "en" and "Category: All" or "Categoría: Todas"),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 8,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextStrokeTransparency = 1,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 7,
    Parent = categoryButton,
})

-- Dropdown parented to gui so it renders above cards
local categoryDrop = new("Frame", {
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(118, 0),
    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 200,
    Parent = gui,
})
round(categoryDrop, 8)
local categoryDropStroke = Instance.new("UIStroke")
categoryDropStroke.Color = Color3.new(1, 1, 1)
categoryDropStroke.Transparency = 0.35
categoryDropStroke.Thickness = 1.2
categoryDropStroke.Parent = categoryDrop

local categoryDropOpen = false
local categoryOptions = {
    {id = "all", es = "Todas", en = "All"},
    {id = "favorites", es = "Favoritos", en = "Favorites"},
}

local function categoryOptionText(opt)
    return currentLanguage == "en" and opt.en or opt.es
end

local function refreshCategoryLabel()
    local selectedName = "Todas"
    for _, opt in ipairs(categoryOptions) do
        if opt.id == categoryFilter then
            selectedName = categoryOptionText(opt)
            break
        end
    end
    local prefix = currentLanguage == "en" and "Category: " or "Categoría: "
    categoryLabel.Text = prefix .. selectedName

    for _, child in ipairs(categoryDrop:GetChildren()) do
        if child:IsA("TextButton") then
            for _, opt in ipairs(categoryOptions) do
                if child.Name == "cat_" .. opt.id then
                    child.Text = "  " .. categoryOptionText(opt)
                    if opt.id == categoryFilter then
                        child.TextColor3 = Color3.new(1, 1, 1)
                        child.BackgroundTransparency = 0.65
                    else
                        child.TextColor3 = Color3.fromRGB(180, 180, 180)
                        child.BackgroundTransparency = 1
                    end
                end
            end
        end
    end
end

local function positionCategoryDrop()
    local abs = categoryButton.AbsolutePosition
    local size = categoryButton.AbsoluteSize
    local guiAbs = gui.AbsolutePosition
    categoryDrop.Position = UDim2.fromOffset(abs.X - guiAbs.X, abs.Y - guiAbs.Y + size.Y + 4)
    categoryDrop.Size = UDim2.fromOffset(math.max(size.X, 118), categoryDrop.Size.Y.Offset)
end

local function setCategoryDropOpen(open)
    categoryDropOpen = open == true
    if categoryDropOpen then
        positionCategoryDrop()
        categoryDrop.Visible = true
        TweenService:Create(categoryDrop, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(math.max(categoryButton.AbsoluteSize.X, 100), 68),
        }):Play()
    else
        local t = TweenService:Create(categoryDrop, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(math.max(categoryButton.AbsoluteSize.X, 100), 0),
        })
        t:Play()
        t.Completed:Connect(function()
            if not categoryDropOpen then
                categoryDrop.Visible = false
            end
        end)
    end
end

for i, opt in ipairs(categoryOptions) do
    local optBtn = new("TextButton", {
        Name = "cat_" .. opt.id,
        Position = UDim2.fromOffset(4, 4 + (i - 1) * 30),
        Size = UDim2.new(1, -8, 0, 28),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = opt.id == categoryFilter and 0.65 or 1,
        BorderSizePixel = 0,
        Text = "  " .. categoryOptionText(opt),
        TextColor3 = opt.id == categoryFilter and Color3.new(1, 1, 1) or Color3.fromRGB(180, 180, 180),
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        ZIndex = 201,
        Parent = categoryDrop,
    })
    round(optBtn, 6)
    optBtn.MouseButton1Click:Connect(function()
        categoryFilter = opt.id
        setCategoryDropOpen(false)
        refreshCategoryLabel()
        refreshCategoryFilter()
    end)
end

categoryButton.MouseButton1Click:Connect(function()
    setCategoryDropOpen(not categoryDropOpen)
end)

-- Carousel container (horizontal selection of vertical cards)
local carouselArea = new("Frame", {
    Position = UDim2.fromOffset(0, 92),
    Size = UDim2.new(1, 0, 1, -134),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 6,
    Parent = content,
})

local cardsHolder = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 7,
    Parent = carouselArea,
})

local leftArrow = new("TextButton", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 6, 0.42, 0),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Text = "‹",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    ZIndex = 20,
    Parent = carouselArea,
})
round(leftArrow, 999)
local leftArrowStroke = Instance.new("UIStroke")
leftArrowStroke.Color = Color3.new(1, 1, 1)
leftArrowStroke.Transparency = 0.15
leftArrowStroke.Thickness = 1.5
leftArrowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
leftArrowStroke.Parent = leftArrow

local rightArrow = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -6, 0.42, 0),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Text = "›",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    ZIndex = 20,
    Parent = carouselArea,
})
round(rightArrow, 999)
local rightArrowStroke = Instance.new("UIStroke")
rightArrowStroke.Color = Color3.new(1, 1, 1)
rightArrowStroke.Transparency = 0.15
rightArrowStroke.Thickness = 1.5
rightArrowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rightArrowStroke.Parent = rightArrow

leftArrow.MouseEnter:Connect(function()
    TweenService:Create(leftArrowStroke, TweenInfo.new(0.12), {Transparency = 0, Thickness = 2.2}):Play()
end)
leftArrow.MouseLeave:Connect(function()
    TweenService:Create(leftArrowStroke, TweenInfo.new(0.12), {Transparency = 0.15, Thickness = 1.6}):Play()
end)
rightArrow.MouseEnter:Connect(function()
    TweenService:Create(rightArrowStroke, TweenInfo.new(0.12), {Transparency = 0, Thickness = 2.2}):Play()
end)
rightArrow.MouseLeave:Connect(function()
    TweenService:Create(rightArrowStroke, TweenInfo.new(0.12), {Transparency = 0.15, Thickness = 1.6}):Play()
end)

-- Bottom action buttons (Execute / Details) for selected card
local actionBar = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -16),
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    ZIndex = 8,
    Parent = content,
})

local executeButton = new("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.36, 0, 0.5, 0),
    Size = UDim2.new(0.26, 0, 0, 26),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = Color3.new(0, 0, 0),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextStrokeTransparency = 1,
    AutoButtonColor = false,
    ZIndex = 9,
    Parent = actionBar,
})
round(executeButton, 8)

local executeIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(14, 14),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6031097226",
    ImageColor3 = Color3.new(0, 0, 0),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 10,
    Parent = executeButton,
})

local executeLabel = new("TextLabel", {
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = T("execute"),
    TextColor3 = Color3.new(0, 0, 0),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextStrokeTransparency = 1,
    ZIndex = 10,
    Parent = executeButton,
})

-- spinning loader ring (hidden until executing)
local executeSpinner = new("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(16, 16),
    BackgroundTransparency = 1,
    Image = "rbxassetid://4965945816",
    ImageColor3 = Color3.new(0, 0, 0),
    ScaleType = Enum.ScaleType.Fit,
    Visible = false,
    ZIndex = 11,
    Parent = executeButton,
})

local executeLoading = false
local executeSpinConn = nil

local function setExecuteLoading(on)
    executeLoading = on == true
    if executeSpinConn then
        executeSpinConn:Disconnect()
        executeSpinConn = nil
    end

    if executeLoading then
        executeIcon.Visible = false
        executeLabel.Visible = false
        executeSpinner.Visible = true
        executeSpinner.Rotation = 0
        local RunService = game:GetService("RunService")
        executeSpinConn = RunService.RenderStepped:Connect(function(dt)
            if not executeSpinner or not executeSpinner.Parent then
                if executeSpinConn then
                    executeSpinConn:Disconnect()
                    executeSpinConn = nil
                end
                return
            end
            executeSpinner.Rotation = (executeSpinner.Rotation + dt * 360) % 360
        end)
    else
        executeSpinner.Visible = false
        executeSpinner.Rotation = 0
        executeIcon.Visible = true
        executeLabel.Visible = true
        executeLabel.Text = T("execute")
    end
end

local detailsActionButton = new("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.64, 0, 0.5, 0),
    Size = UDim2.new(0.26, 0, 0, 26),
    BackgroundColor3 = Color3.fromRGB(18, 18, 18),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextStrokeTransparency = 1,
    AutoButtonColor = false,
    ZIndex = 9,
    Parent = actionBar,
})
round(detailsActionButton, 8)
local detailsActionStroke = Instance.new("UIStroke")
detailsActionStroke.Color = Color3.new(1, 1, 1)
detailsActionStroke.Transparency = 0.45
detailsActionStroke.Thickness = 1.2
detailsActionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
detailsActionStroke.Parent = detailsActionButton

local detailsIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(14, 14),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6031229350",
    ImageColor3 = Color3.new(1, 1, 1),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 10,
    Parent = detailsActionButton,
})

local detailsActionLabel = new("TextLabel", {
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = T("details"),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextStrokeTransparency = 1,
    ZIndex = 10,
    Parent = detailsActionButton,
})

executeButton.MouseEnter:Connect(function()
    TweenService:Create(executeButton, TweenInfo.new(0.12), {BackgroundTransparency = 0.12}):Play()
end)
executeButton.MouseLeave:Connect(function()
    TweenService:Create(executeButton, TweenInfo.new(0.12), {BackgroundTransparency = 0.02}):Play()
end)
detailsActionButton.MouseEnter:Connect(function()
    TweenService:Create(detailsActionButton, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    TweenService:Create(detailsActionStroke, TweenInfo.new(0.12), {Transparency = 0.25}):Play()
end)
detailsActionButton.MouseLeave:Connect(function()
    TweenService:Create(detailsActionButton, TweenInfo.new(0.12), {BackgroundTransparency = 0.02}):Play()
    TweenService:Create(detailsActionStroke, TweenInfo.new(0.12), {Transparency = 0.45}):Play()
end)

local status = new("TextLabel", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = T("loadingScripts"),
    TextColor3 = Color3.fromRGB(130, 130, 130),
    TextSize = 8,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = content,
})

local noResults = new("TextLabel", {
    Position = UDim2.fromOffset(0, 92),
    Size = UDim2.new(1, 0, 1, -134),
    BackgroundTransparency = 1,
    Text = T("noResults"),
    TextColor3 = Color3.fromRGB(180, 180, 180),
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    Visible = false,
    ZIndex = 8,
    Parent = content,
})

local detailsShade = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    Visible = false,
    Active = true,
    ZIndex = 30,
    Parent = gui,
})

local detailsPanel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(560, 620),
    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 31,
    Parent = detailsShade,
})
round(detailsPanel, 14)
local detailsPanelStroke = stroke(detailsPanel, 0.18)
detailsPanelStroke.Thickness = 1.45

local detailsHeader = new("TextLabel", {
    Position = UDim2.fromOffset(14, 10),
    Size = UDim2.new(1, -58, 0, 22),
    BackgroundTransparency = 1,
    Text = T("detailsTitle"),
    TextColor3 = Color3.fromRGB(190, 190, 190),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 32,
    Parent = detailsPanel,
})

local detailsClose = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 7),
    Size = UDim2.fromOffset(29, 29),
    BackgroundColor3 = Color3.fromRGB(24, 24, 24),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 18,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 36,
    Parent = detailsPanel,
})
round(detailsClose, 9)
stroke(detailsClose, 0.68)

local detailsImageHolder = new("Frame", {
    Position = UDim2.fromOffset(14, 40),
    Size = UDim2.new(1, -28, 0, 132),
    BackgroundColor3 = Color3.fromRGB(4, 4, 4),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 32,
    Parent = detailsPanel,
})
round(detailsImageHolder, 11)
local detailsImageStroke = stroke(detailsImageHolder, 0.72)
detailsImageStroke.Thickness = 1.1

local detailsImage = new("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = "",
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 33,
    Parent = detailsImageHolder,
})

local detailsTag = new("TextLabel", {
    Position = UDim2.fromOffset(10, 10),
    Size = UDim2.fromOffset(90, 22),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.52,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 9,
    Font = Enum.Font.Gotham,
    Visible = false,
    ZIndex = 35,
    Parent = detailsImageHolder,
})
round(detailsTag, 7)

local detailsName = new("TextLabel", {
    Position = UDim2.fromOffset(15, 181),
    Size = UDim2.new(1, -30, 0, 26),
    BackgroundTransparency = 1,
    Text = "Script",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 18,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 32,
    Parent = detailsPanel,
})

local detailsInfoCard = new("Frame", {
    Position = UDim2.fromOffset(14, 214),
    Size = UDim2.new(1, -28, 1, -228),
    BackgroundColor3 = Color3.fromRGB(5, 5, 5),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 32,
    Parent = detailsPanel,
})
round(detailsInfoCard, 10)
local detailsInfoStroke = stroke(detailsInfoCard, 0.78)
detailsInfoStroke.Thickness = 1

local detailsScroll = new("ScrollingFrame", {
    Position = UDim2.fromOffset(10, 9),
    Size = UDim2.new(1, -20, 1, -18),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Color3.fromRGB(210, 210, 210),
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollingEnabled = true,
    ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    ZIndex = 33,
    Parent = detailsInfoCard,
})

local detailsText = new("TextLabel", {
    Size = UDim2.new(1, -8, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(220, 220, 220),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    RichText = false,
    ZIndex = 34,
    Parent = detailsScroll,
})

local function resizeDetailsPanel()
    local currentCam = workspace.CurrentCamera
    if not currentCam then return end

    local viewport = currentCam.ViewportSize
    local mobile = UIS.TouchEnabled and not (UIS.KeyboardEnabled and UIS.MouseEnabled)

    local panelWidth
    local panelHeight
    local imageHeight

    if mobile then
        panelWidth = math.max(180, math.min(math.floor(viewport.X * 0.72), 280, viewport.X - 40))
        panelHeight = math.max(220, math.min(math.floor(viewport.Y * 0.55), 360, viewport.Y - 60))
        imageHeight = math.max(50, math.min(math.floor(panelWidth * 0.3), 80))
    else
        panelWidth = math.max(320, math.min(math.floor(viewport.X * 0.52), 680, viewport.X - 50))
        panelHeight = math.max(360, math.min(math.floor(viewport.Y * 0.76), 700, viewport.Y - 50))
        imageHeight = math.max(120, math.min(math.floor(panelWidth * 0.34), 220))
    end

    detailsPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)

    local sidePad = mobile and 8 or 14
    local topImageY = mobile and 31 or 40

    detailsHeader.Position = UDim2.fromOffset(sidePad, mobile and 6 or 10)
    detailsHeader.Size = UDim2.new(1, -(sidePad + 38), 0, mobile and 17 or 22)
    detailsHeader.TextSize = mobile and 8 or 10

    detailsClose.Position = UDim2.new(1, -(mobile and 6 or 10), 0, mobile and 5 or 7)
    detailsClose.Size = UDim2.fromOffset(mobile and 22 or 29, mobile and 22 or 29)
    detailsClose.TextSize = mobile and 14 or 18

    detailsImageHolder.Position = UDim2.fromOffset(sidePad, topImageY)
    detailsImageHolder.Size = UDim2.new(1, -(sidePad * 2), 0, imageHeight)

    local titleY = topImageY + imageHeight + (mobile and 5 or 9)
    detailsName.Position = UDim2.fromOffset(sidePad + 1, titleY)
    detailsName.Size = UDim2.new(1, -((sidePad + 1) * 2), 0, mobile and 20 or 32)
    detailsName.TextSize = mobile and 13 or 21

    local infoY = titleY + (mobile and 23 or 40)
    detailsInfoCard.Position = UDim2.fromOffset(sidePad, infoY)
    detailsInfoCard.Size = UDim2.new(1, -(sidePad * 2), 1, -(infoY + sidePad))

    detailsScroll.Position = UDim2.fromOffset(mobile and 6 or 10, mobile and 5 or 9)
    detailsScroll.Size = UDim2.new(1, -(mobile and 12 or 20), 1, -(mobile and 10 or 18))
    detailsText.TextSize = mobile and 10 or 14
end

local currentDetailsData = nil

local function detailScalar(value)
    if value == nil then return nil end
    if typeof(value) == "boolean" then
        return value and T("yes") or T("no")
    end
    if typeof(value) == "string" or typeof(value) == "number" then
        local txt = tostring(value)
        if txt ~= "" then return txt end
    end
    return nil
end

local function buildDetailsText(data)
    local lines = {}
    local fullDescription = fullLocalizedDescription(data)
    if fullDescription ~= "" then
        table.insert(lines, fullDescription)
        table.insert(lines, "")
    end

    local standard = {
        {T("version"), data.Version},
        {T("author"), data.Author or data.Creator},
        {T("game"), data.Game or data.GameName},
    }

    for _, item in ipairs(standard) do
        local value = detailScalar(item[2])
        if value then
            table.insert(lines, item[1] .. ": " .. value)
        end
    end

    local ignored = {
        Title=true, TitleES=true, TitleEs=true, TitleEN=true, TitleEn=true,
        TitleSpanish=true, TitleEnglish=true,
        Description=true, DescriptionES=true, DescriptionEs=true, DescriptionEN=true,
        DescriptionEn=true, DescriptionSpanish=true, DescriptionEnglish=true,
        Image=true, URL=true, Enabled=true, Tag=true, Tags=true, Label=true, Etiqueta=true,
        Version=true, Author=true, Creator=true,
        Game=true, GameName=true,
    }
    local extras = {}
    for k, v in pairs(data) do
        if not ignored[k] then
            local scalar = detailScalar(v)
            if scalar then
                table.insert(extras, {Key=tostring(k), Value=scalar})
            end
        end
    end
    table.sort(extras, function(a, b) return a.Key < b.Key end)
    for _, item in ipairs(extras) do
        table.insert(lines, item.Key .. ": " .. item.Value)
    end

    if #lines == 0 then
        return T("noExtraInfo")
    end
    return table.concat(lines, "\n")
end

local function refreshDetails()
    if not currentDetailsData then return end
    local data = currentDetailsData
    detailsHeader.Text = T("detailsTitle")
    detailsName.Text = localizedTitle(data)
    detailsImage.Image = tostring(data.Image or "")
    detailsText.Text = buildDetailsText(data)
    detailsScroll.CanvasPosition = Vector2.new(0, 0)

    local tag = getTag(data)
    if tag then
        local tagWidth = math.clamp(30 + (#tag.Title * 6), 64, 150)
        detailsTag.Size = UDim2.fromOffset(tagWidth, 22)
        detailsTag.Visible = true
        detailsTag.Text = tag.Title
        detailsTag.BackgroundColor3 = tag.Color
        detailsTag.BackgroundTransparency = 0.52
        detailsTag.TextColor3 = Color3.new(1, 1, 1)
    else
        detailsTag.Visible = false
    end
end

local function openDetails(data)
    currentDetailsData = data
    resizeDetailsPanel()
    refreshDetails()
    detailsShade.Visible = true
end

local function closeDetailsPanel()
    detailsShade.Visible = false
    currentDetailsData = nil
end

detailsClose.MouseButton1Click:Connect(closeDetailsPanel)
detailsShade.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
        closeDetailsPanel()
    end
end)

discordButton.MouseButton1Click:Connect(function()
    local copied = false

    if type(setclipboard) == "function" then
        copied = pcall(setclipboard, DISCORD_URL)
    elseif type(toclipboard) == "function" then
        copied = pcall(toclipboard, DISCORD_URL)
    end

    if copied then
        status.Text = T("discordCopied")
        local oldText = discordLabel.Text
        discordLabel.Text = "✓ Copied"
        task.delay(1.1, function()
            if discordLabel and discordLabel.Parent then
                discordLabel.Text = oldText
            end
        end)
    else
        status.Text = T("discordCopyFailed")
    end
end)

local cards = {}
local visibleCards = {}
local selectedIndex = 1
local carouselAnimating = false
-- userIsVip declared near top; set during beginKeyFlow
local CARD_WIDTH = 320
local CARD_HEIGHT = 280
local CARD_GAP = 28

local function cardIsMobile()
    return UIS.TouchEnabled and not (UIS.KeyboardEnabled and UIS.MouseEnabled)
end

local function getSelectedCard()
    if #visibleCards == 0 then return nil end
    if selectedIndex < 1 then selectedIndex = 1 end
    if selectedIndex > #visibleCards then selectedIndex = #visibleCards end
    return visibleCards[selectedIndex]
end

local function updateActionButtons()
    local sel = getSelectedCard()
    if not sel then
        if not executeLoading then
            executeLabel.Text = T("execute")
            executeLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
            executeIcon.ImageColor3 = Color3.fromRGB(160, 160, 160)
        end
        executeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        detailsActionLabel.Text = T("details")
        return
    end
    if not executeLoading then
        executeLabel.Text = T("execute")
    end
    detailsActionLabel.Text = T("details")
    if sel.ExecuteLocked or sel.VipLocked then
        executeButton.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
        executeLabel.TextColor3 = Color3.fromRGB(178, 178, 178)
        executeIcon.ImageColor3 = Color3.fromRGB(178, 178, 178)
        executeSpinner.ImageColor3 = Color3.fromRGB(178, 178, 178)
    else
        executeButton.BackgroundColor3 = Color3.new(1, 1, 1)
        executeLabel.TextColor3 = Color3.new(0, 0, 0)
        executeIcon.ImageColor3 = Color3.new(0, 0, 0)
        executeSpinner.ImageColor3 = Color3.new(0, 0, 0)
    end
end

local function applyCarouselVisuals(animate)
    local total = #visibleCards
    if total == 0 then
        leftArrow.Visible = false
        rightArrow.Visible = false
        updateActionButtons()
        return
    end

    if selectedIndex < 1 then selectedIndex = 1 end
    if selectedIndex > total then selectedIndex = total end

    leftArrow.Visible = total > 1
    rightArrow.Visible = total > 1

    local areaW = carouselArea.AbsoluteSize.X
    if areaW < 10 then areaW = 400 end
    local centerX = areaW * 0.5

    local mobile = cardIsMobile()
    local selectedScale = mobile and 1.0 or 1.05
    local otherScale = mobile and 0.88 or 0.92
    local step = CARD_WIDTH + CARD_GAP

    local info = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    for i, c in ipairs(visibleCards) do
        local offset = i - selectedIndex
        local targetX = centerX + offset * step
        local isSelected = (i == selectedIndex)
        local targetScale = isSelected and selectedScale or otherScale
        local targetTrans = isSelected and (c.VipLocked and 0.18 or 0.06) or 0.45
        local targetImageTrans = isSelected and (c.VipLocked and 0.28 or 0) or 0.4
        local z = isSelected and 14 or (10 - math.abs(offset))

        c.Frame.ZIndex = z
        if c.ImageHolder then c.ImageHolder.ZIndex = z + 1 end
        if c.CardImage then c.CardImage.ZIndex = z + 2 end
        if c.DimOverlay then c.DimOverlay.ZIndex = z + 3 end
        if c.TagLabel then
            c.TagLabel.Visible = true
            c.TagLabel.ZIndex = z + 8
        end
        if c.FavoriteButton then
            c.FavoriteButton.ZIndex = z + 9
        end

        if not c.UIScale then
            c.UIScale = Instance.new("UIScale")
            c.UIScale.Parent = c.Frame
        end

        if animate then
            TweenService:Create(c.Frame, info, {
                Position = UDim2.new(0, targetX, 0.5, 0),
                BackgroundTransparency = targetTrans,
            }):Play()
            TweenService:Create(c.UIScale, info, {
                Scale = targetScale,
            }):Play()
            if c.CardImage then
                TweenService:Create(c.CardImage, info, {ImageTransparency = targetImageTrans}):Play()
            end
            if c.DimOverlay then
                TweenService:Create(c.DimOverlay, info, {
                    BackgroundTransparency = isSelected and 1 or 0.35,
                }):Play()
            end
            if c.CardStroke then
                TweenService:Create(c.CardStroke, info, {
                    Transparency = isSelected and 0.05 or 0.78,
                    Thickness = isSelected and 2.4 or 1.1,
                }):Play()
            end
        else
            c.Frame.Position = UDim2.new(0, targetX, 0.5, 0)
            c.Frame.BackgroundTransparency = targetTrans
            c.UIScale.Scale = targetScale
            if c.CardImage then c.CardImage.ImageTransparency = targetImageTrans end
            if c.DimOverlay then
                c.DimOverlay.BackgroundTransparency = isSelected and 1 or 0.35
            end
            if c.CardStroke then
                c.CardStroke.Transparency = isSelected and 0.05 or 0.78
                c.CardStroke.Thickness = isSelected and 2.4 or 1.1
            end
        end
    end

    updateActionButtons()
end

local function rebuildVisibleList(keepSelection)
    local prevData = keepSelection and getSelectedCard() and getSelectedCard().Data or nil
    visibleCards = {}
    local q = (search.Text or ""):lower()

    for _, c in ipairs(cards) do
        local match = q == ""
            or string.find(c.Title, q, 1, true) ~= nil
            or string.find(c.Description, q, 1, true) ~= nil
            or string.find(c.Tag or "", q, 1, true) ~= nil
        if categoryFilter == "favorites" and not isFavorite(c.Data) then
            match = false
        end
        c.Frame.Visible = match
        if match then
            table.insert(visibleCards, c)
        end
    end

    -- favorites first, then original order
    table.sort(visibleCards, function(a, b)
        local af = isFavorite(a.Data) and 1 or 0
        local bf = isFavorite(b.Data) and 1 or 0
        if af ~= bf then return af > bf end
        return (a.RawIndex or 0) < (b.RawIndex or 0)
    end)

    selectedIndex = 1
    if prevData then
        for i, c in ipairs(visibleCards) do
            if c.Data == prevData then
                selectedIndex = i
                break
            end
        end
    end

    local found = #visibleCards
    if q == "" then
        noResults.Visible = false
        status.Text = ""
    else
        noResults.Visible = found == 0
        status.Text = (found == 1) and T("oneResult") or string.format(T("results"), found)
    end

    applyCarouselVisuals(false)
end

local function moveCarousel(delta)
    if carouselAnimating or #visibleCards <= 1 then return end
    local newIndex = selectedIndex + delta
    if newIndex < 1 then newIndex = #visibleCards end
    if newIndex > #visibleCards then newIndex = 1 end
    if newIndex == selectedIndex then return end
    carouselAnimating = true
    selectedIndex = newIndex
    applyCarouselVisuals(true)
    task.delay(0.34, function()
        carouselAnimating = false
    end)
end

leftArrow.MouseButton1Click:Connect(function()
    moveCarousel(-1)
end)
rightArrow.MouseButton1Click:Connect(function()
    moveCarousel(1)
end)

local function createCard(data, index)
    if data.Enabled == false then
        return
    end

    local title = localizedTitle(data)
    local description = localizedDescription(data)
    local tag = getTag(data)
    local lockInfo = getExecuteLock(data)
    local executeLocked = lockInfo ~= nil

    local card = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = executeLocked and 0.28 or 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 7,
        Parent = cardsHolder,
        Visible = false,
    })
    round(card, 12)
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.new(1, 1, 1)
    cardStroke.Transparency = 0.78
    cardStroke.Thickness = 1.1
    cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cardStroke.Parent = card

    local imageHeight = math.floor(CARD_HEIGHT * 0.62)

    local imageHolder = new("Frame", {
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 0, imageHeight),
        BackgroundColor3 = Color3.fromRGB(4, 4, 4),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 8,
        Parent = card,
    })
    round(imageHolder, 9)
    stroke(imageHolder, 0.9)

    local cardImage = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = tostring(data.Image or ""),
        ImageTransparency = executeLocked and 0.35 or 0,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 9,
        Parent = imageHolder,
    })

    if executeLocked then
        new("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.48,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = imageHolder,
        })
    end

    -- dim only over image so title/desc stay readable; tag/favorite above dim
    local dimOverlay = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = imageHolder,
    })
    round(dimOverlay, 9)

    local tagLabel
    if tag then
        local tagWidth = math.clamp(26 + (#tag.Title * 6), 58, 118)
        tagLabel = new("TextLabel", {
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.fromOffset(tagWidth, 20),
            BackgroundColor3 = tag.Color,
            BackgroundTransparency = 0.52,
            BorderSizePixel = 0,
            Text = tag.Title,
            TextSize = 8,
            Font = Enum.Font.Gotham,
            TextStrokeTransparency = 1,
            Visible = true,
            ZIndex = 20,
            Parent = imageHolder,
        })
        tagLabel.TextColor3 = Color3.new(1, 1, 1)
        round(tagLabel, 7)
        local tagStroke = Instance.new("UIStroke")
        tagStroke.Color = tag.Color
        tagStroke.Transparency = 0.35
        tagStroke.Thickness = 1
        tagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        tagStroke.Parent = tagLabel
    end

    local favoriteButton = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = Color3.fromRGB(8, 8, 8),
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Text = isFavorite(data) and "★" or "☆",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        ZIndex = 21,
        Parent = imageHolder,
    })
    round(favoriteButton, 8)
    stroke(favoriteButton, 0.7)

    local titleY = imageHeight + 10
    local titleLabel = new("TextLabel", {
        Position = UDim2.fromOffset(8, titleY),
        Size = UDim2.new(1, -16, 0, 18),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = executeLocked and Color3.fromRGB(168, 168, 168) or Color3.new(1, 1, 1),
        TextSize = CARD_HEIGHT < 210 and 11 or 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextStrokeTransparency = 1,
        ZIndex = 8,
        Parent = card,
    })

    local descriptionLabel = new("TextLabel", {
        Position = UDim2.fromOffset(8, titleY + 18),
        Size = UDim2.new(1, -16, 0, math.max(28, CARD_HEIGHT - titleY - 26)),
        BackgroundTransparency = 1,
        Text = description,
        TextColor3 = executeLocked and Color3.fromRGB(105, 105, 105) or Color3.fromRGB(155, 155, 155),
        TextSize = CARD_HEIGHT < 210 and 10 or 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextStrokeTransparency = 1,
        ZIndex = 8,
        Parent = card,
    })

    favoriteButton.MouseButton1Click:Connect(function()
        local newValue = not isFavorite(data)
        setFavorite(data, newValue)
        favoriteButton.Text = newValue and "★" or "☆"
        status.Text = newValue and T("favoriteAdded") or T("favoriteRemoved")
        rebuildVisibleList(true)
    end)

    -- click card to select it
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            for i, vc in ipairs(visibleCards) do
                if vc.Frame == card then
                    if i ~= selectedIndex then
                        selectedIndex = i
                        applyCarouselVisuals(true)
                    end
                    break
                end
            end
        end
    end)

    table.insert(cards, {
        Frame = card,
        Data = data,
        TitleLabel = titleLabel,
        DescriptionLabel = descriptionLabel,
        FavoriteButton = favoriteButton,
        TagLabel = tagLabel,
        ImageHolder = imageHolder,
        CardImage = cardImage,
        DimOverlay = dimOverlay,
        CardStroke = cardStroke,
        RawIndex = index,
        VipLocked = executeLocked, -- backward-compat name used by carousel visuals
        ExecuteLocked = executeLocked,
        LockMessageKey = lockInfo and lockInfo.MessageKey or nil,
        Title = title:lower(),
        Description = description:lower(),
        Tag = tag and tag.Title:lower() or "",
    })
end

local function runSelectedScript()
    if closing or executeLoading then return end
    local sel = getSelectedCard()
    if not sel then return end

    if sel.ExecuteLocked or sel.VipLocked then
        local msgKey = sel.LockMessageKey or "vipOnlyLocked"
        local msg = T(msgKey)
        status.Text = msg
        showNotice(msg)
        return
    end

    local data = sel.Data
    local activeTitle = localizedTitle(data)
    setExecuteLoading(true)
    status.Text = string.format(T("preparing"), activeTitle)

    task.spawn(function()
        local ok, result = pcall(function()
            local src = game:HttpGet(data.URL, true)
            local fn, err = loadstring(src)
            if not fn then error(err) end
            return fn
        end)

        if not ok then
            setExecuteLoading(false)
            executeLabel.Text = "ERROR"
            executeLabel.Visible = true
            executeIcon.Visible = false
            status.Text = string.format(T("loadError"), activeTitle)
            warn("[H3X4 Loader] " .. tostring(result))
            task.wait(1.1)
            executeLabel.Text = T("execute")
            executeIcon.Visible = true
            updateActionButtons()
            return
        end

        local fn = result
        if gui and gui.Parent then
            gui:Destroy()
        end
        closing = true
        task.spawn(function()
            local ran, err = pcall(fn)
            if not ran then
                warn("[H3X4 Loader] Error al ejecutar: " .. tostring(err))
            end
        end)
    end)
end

executeButton.MouseButton1Click:Connect(runSelectedScript)

detailsActionButton.MouseButton1Click:Connect(function()
    local sel = getSelectedCard()
    if sel then
        openDetails(sel.Data)
    end
end)

local function updateSearch()
    rebuildVisibleList(true)
end

refreshCategoryFilter = function()
    rebuildVisibleList(true)
end

search:GetPropertyChangedSignal("Text"):Connect(updateSearch)

local function cleanCatalogSource(source)
    source = tostring(source or "")

    source = source:gsub("^\239\187\191", "")

    source = source:gsub("^%s*```[%w_-]*%s*", "")
    source = source:gsub("%s*```%s*$", "")

    return source
end

local function fetchCatalog()
    local urls = {
        CATALOG_URL,
        "https://raw.githubusercontent.com/NonyH/universalh3xa/main/loaders.lua",
    }

    local lastError = "Unknown catalog error"

    for _, baseUrl in ipairs(urls) do
        local requestUrl = baseUrl
        local separator = string.find(baseUrl, "?", 1, true) and "&" or "?"
        requestUrl = requestUrl .. separator .. "h3x4=" .. tostring(os.time())

        local okHttp, source = pcall(function()
            return game:HttpGet(requestUrl, true)
        end)

        if okHttp and type(source) == "string" and source ~= "" then
            source = cleanCatalogSource(source)

            local fn, compileError = loadstring(source, "H3X4_loaders.lua")
            if fn then
                local okRun, catalog = pcall(fn)
                if okRun and typeof(catalog) == "table" then
                    return catalog
                elseif not okRun then
                    lastError = "Error ejecutando loaders.lua: " .. tostring(catalog)
                else
                    lastError = T("catalogTableError")
                end
            else
                lastError = "Error de sintaxis en loaders.lua: " .. tostring(compileError)
            end
        elseif not okHttp then
            lastError = "Error HTTP: " .. tostring(source)
        else
            lastError = "loaders.lua está vacío"
        end
    end

    error(lastError)
end

local function loadCatalog()
    local ok, result = pcall(fetchCatalog)

    if not ok then
        status.Text = T("catalogError")
        warn("[H3X4 Loader] " .. tostring(result))
        return
    end

    for i, data in ipairs(result) do
        if typeof(data) == "table" then
            createCard(data, i)
        end
    end

    rebuildVisibleList(false)
    status.Text = ""
    -- ensure layout after AbsoluteSize is ready
    task.defer(function()
        applyCarouselVisuals(false)
    end)
end


local catalogLoaded = false

local function refreshCardsLanguage()
    for _, c in ipairs(cards) do
        if c.Data then
            local title = localizedTitle(c.Data)
            local description = localizedDescription(c.Data)

            c.Title = title:lower()
            c.Description = description:lower()

            if c.TitleLabel and c.TitleLabel.Parent then
                c.TitleLabel.Text = title
            end
            if c.DescriptionLabel and c.DescriptionLabel.Parent then
                c.DescriptionLabel.Text = description
            end
            local tag = getTag(c.Data)
            c.Tag = tag and tag.Title:lower() or ""

            if c.TagLabel and c.TagLabel.Parent then
                if tag then
                    local tagWidth = math.clamp(26 + (#tag.Title * 6), 58, 118)
                    c.TagLabel.Size = UDim2.fromOffset(tagWidth, 20)
                    c.TagLabel.Visible = true
                    c.TagLabel.Text = tag.Title
                    c.TagLabel.BackgroundColor3 = tag.Color
                    c.TagLabel.BackgroundTransparency = 0.52
                    c.TagLabel.TextColor3 = Color3.new(1, 1, 1)
                    local ts = c.TagLabel:FindFirstChildOfClass("UIStroke")
                    if ts then
                        ts.Color = tag.Color
                        ts.Transparency = 0.35
                    end
                else
                    c.TagLabel.Visible = false
                end
            end
        end
    end
    updateActionButtons()
end

local function applyLanguageToUI()
    search.PlaceholderText = T("search")
    noResults.Text = T("noResults")
    refreshCategoryLabel()
    detailsHeader.Text = T("detailsTitle")
    if not executeLoading then
        executeLabel.Text = T("execute")
    end
    detailsActionLabel.Text = T("details")
    if detailsShade.Visible and currentDetailsData then
        refreshDetails()
    end

    if not catalogLoaded then
        status.Text = T("loadingScripts")
    else
        refreshCardsLanguage()
        updateSearch()
    end
end

local function openMainLoader()
    applyLanguageToUI()
    main.Visible = true
    scale.Scale = 0.82
    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay, TweenInfo.new(0.25), {BackgroundTransparency = 0.36}):Play()
    TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

    if not catalogLoaded then
        catalogLoaded = true
        loadCatalog()
    end
end

local keyAuthorized = false
local languageOpenedFromMain = false
local keyFlowBusy = false

local function hideKeyScreenAndOpenMain()
    keyAuthorized = true
    TweenService:Create(keyPanelScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.9}):Play()
    TweenService:Create(keyScreen, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    task.delay(0.21, function()
        keyScreen.Visible = false
        keyScreen.BackgroundTransparency = 0
        openMainLoader()
    end)
end

local function showKeyPanel(message)
    updateKeyLanguage()
    keyStatusLabel.Text = message or ""
    keyInput.Text = ""
    rememberKeyChoice = readRememberedKey() ~= nil
    updateRememberKeyButton()
    keyScreen.BackgroundTransparency = 0
    keyScreen.Visible = true
    keyPanelScale.Scale = 0.86
    TweenService:Create(keyPanelScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function beginKeyFlow()
    if keyFlowBusy then return end
    keyFlowBusy = true

    task.spawn(function()
        local vip, vipErr = loadVipStatus()
        userIsVip = vip == true

        if vipErr then
            warn("[H3X4 Loader] VIP config error: " .. tostring(vipErr))
        end

        if userIsVip then
            keyFlowBusy = false
            clearRememberedKey()
            keyAuthorized = true
            keyScreen.Visible = false
            openMainLoader()
            return
        end

        local config, err = loadKeyConfig()
        keyFlowBusy = false

        if not config then
            showKeyPanel(T("keyLoadError"))
            warn("[H3X4 Loader] Key config error: " .. tostring(err))
            return
        end

        if not config.enabled then
            clearRememberedKey()
            keyAuthorized = true
            keyScreen.Visible = false
            openMainLoader()
            return
        end

        local saved = readRememberedKey()
        if saved and tostring(saved.key) == config.key and config.key ~= "" then
            keyAuthorized = true
            keyScreen.Visible = false
            openMainLoader()
            return
        end

        if saved then
            clearRememberedKey()
        end
        showKeyPanel("")
    end)
end

verifyKeyButton.MouseButton1Click:Connect(function()
    if keyFlowBusy then return end
    keyFlowBusy = true
    verifyKeyLabel.Text = T("checkingKey")
    keyStatusLabel.Text = ""

    task.spawn(function()
        local config, err = loadKeyConfig()
        keyFlowBusy = false
        verifyKeyLabel.Text = T("verifyKey")

        if not config then
            keyStatusLabel.Text = T("keyLoadError")
            warn("[H3X4 Loader] Key config error: " .. tostring(err))
            return
        end

        if not config.enabled then
            clearRememberedKey()
            hideKeyScreenAndOpenMain()
            return
        end

        local entered = tostring(keyInput.Text or ""):match("^%s*(.-)%s*$")
        if entered ~= "" and entered == config.key then
            keyStatusLabel.Text = T("validKey")
            if rememberKeyChoice then
                saveRememberedKey(entered)
            else
                clearRememberedKey()
            end
            task.delay(0.18, hideKeyScreenAndOpenMain)
        else
            keyStatusLabel.Text = T("invalidKey")
        end
    end)
end)

local function hideLanguageSelector()
    applyLanguageToUI()
    updateKeyLanguage()
    TweenService:Create(languagePanelScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.9}):Play()
    TweenService:Create(languageScreen, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()

    task.delay(0.21, function()
        languageScreen.Visible = false
        languageScreen.BackgroundTransparency = 0
        if languageOpenedFromMain and keyAuthorized then
            languageOpenedFromMain = false
            main.Visible = true
            applyLanguageToUI()
        else
            languageOpenedFromMain = false
            beginKeyFlow()
        end
    end)
end

local function openLanguageSelector()
    languageChosen = false
    rememberChoice = readRememberedLanguage() ~= nil
    updateRememberButton()

    languageScreen.BackgroundTransparency = 0
    languageScreen.Visible = true
    languagePanelScale.Scale = 0.86
    TweenService:Create(languagePanelScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

languageCallbacks.onSelected = hideLanguageSelector

languageButton.MouseButton1Click:Connect(function()
    if closing then
        return
    end
    languageOpenedFromMain = true
    openLanguageSelector()
end)

local dragging = false
local dragInput
local dragStart
local startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local cam = workspace.CurrentCamera

local function isMobileDevice()
    return cardIsMobile()
end

local function layoutCardContent(c)
    if not c or not c.Frame then return end
    local h = CARD_HEIGHT
    local imageH = math.floor(h * 0.62)
    local pad = 6

    if c.ImageHolder then
        c.ImageHolder.Position = UDim2.fromOffset(pad, pad)
        c.ImageHolder.Size = UDim2.new(1, -(pad * 2), 0, imageH)
    end
    if c.TitleLabel then
        c.TitleLabel.Position = UDim2.fromOffset(pad + 2, imageH + pad + 4)
        c.TitleLabel.Size = UDim2.new(1, -(pad * 2 + 4), 0, 18)
        c.TitleLabel.TextSize = h < 210 and 11 or 13
    end
    if c.DescriptionLabel then
        local titleY = imageH + pad + 4
        c.DescriptionLabel.Position = UDim2.fromOffset(pad + 2, titleY + 18)
        c.DescriptionLabel.Size = UDim2.new(1, -(pad * 2 + 4), 0, math.max(28, h - (titleY + 22) - pad))
        c.DescriptionLabel.TextSize = h < 210 and 10 or 11
    end
end

local function resize()
    if not cam then
        return
    end

    local v = cam.ViewportSize
    local mobile = isMobileDevice()
    local width
    local height

    if mobile then
        -- narrower panel horizontally; buttons lower
        width = math.max(220, math.min(math.floor(v.X * 0.78), v.X - 28))
        height = math.max(400, math.min(math.floor(v.Y * 0.90), v.Y - 16))

        local chrome = 120 -- header + search + action bar (extra room for lower buttons)
        local availH = math.max(160, height - chrome)
        -- wider cards so full image is visible
        CARD_HEIGHT = math.max(170, math.min(math.floor(availH * 0.88), 240))
        CARD_WIDTH = math.max(160, math.min(math.floor(CARD_HEIGHT * 1.05), 240))
        CARD_GAP = 12

        header.Size = UDim2.new(1, 0, 0, 42)
        mainLogo.Size = UDim2.fromOffset(46, 46)
        mainLogo.Position = UDim2.fromOffset(-2, -2)

        searchRow.Position = UDim2.fromOffset(0, 44)
        searchRow.Size = UDim2.new(1, 0, 0, 28)

        -- shorter search + category, centered as a pair
        searchFrame.AnchorPoint = Vector2.new(1, 0.5)
        searchFrame.Position = UDim2.new(0.5, -3, 0.5, 0)
        searchFrame.Size = UDim2.fromOffset(138, 24)

        categoryButton.AnchorPoint = Vector2.new(0, 0.5)
        categoryButton.Position = UDim2.new(0.5, 3, 0.5, 0)
        categoryButton.Size = UDim2.fromOffset(86, 24)

        carouselArea.Position = UDim2.fromOffset(0, 76)
        carouselArea.Size = UDim2.new(1, 0, 1, -128)

        noResults.Position = UDim2.fromOffset(0, 76)
        noResults.Size = UDim2.new(1, 0, 1, -128)

        -- action buttons lower on mobile
        actionBar.Position = UDim2.new(0.5, 0, 1, -6)
        leftArrow.Position = UDim2.new(0, 4, 0.42, 0)
        rightArrow.Position = UDim2.new(1, -4, 0.42, 0)
        leftArrow.Size = UDim2.fromOffset(26, 26)
        rightArrow.Size = UDim2.fromOffset(26, 26)

        discordButton.Position = UDim2.new(1, -72, 0.5, 0)
        discordButton.Size = UDim2.fromOffset(64, 24)
        languageButton.Position = UDim2.new(1, -36, 0.5, 0)
        languageButton.Size = UDim2.fromOffset(24, 24)
        close.Position = UDim2.new(1, 0, 0.5, 0)
        close.Size = UDim2.fromOffset(24, 24)
    else
        width = math.max(380, math.min(math.floor(v.X * 0.72), 780, v.X - 36))
        height = math.max(360, math.min(math.floor(v.Y * 0.62), 500, v.Y - 46))
        CARD_WIDTH = 320
        CARD_HEIGHT = 280
        CARD_GAP = 28

        header.Size = UDim2.new(1, 0, 0, 56)
        mainLogo.Size = UDim2.fromOffset(72, 72)
        mainLogo.Position = UDim2.fromOffset(-4, -6)

        searchRow.Position = UDim2.fromOffset(0, 58)
        searchRow.Size = UDim2.new(1, 0, 0, 30)

        searchFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        searchFrame.Position = UDim2.new(0.42, 0, 0.5, 0)
        searchFrame.Size = UDim2.new(0.52, 0, 0, 28)

        categoryButton.AnchorPoint = Vector2.new(0, 0.5)
        categoryButton.Position = UDim2.new(0.7, 4, 0.5, 0)
        categoryButton.Size = UDim2.fromOffset(118, 26)

        carouselArea.Position = UDim2.fromOffset(0, 92)
        carouselArea.Size = UDim2.new(1, 0, 1, -134)

        noResults.Position = UDim2.fromOffset(0, 92)
        noResults.Size = UDim2.new(1, 0, 1, -134)

        actionBar.Position = UDim2.new(0.5, 0, 1, -16)
        leftArrow.Position = UDim2.new(0, 6, 0.42, 0)
        rightArrow.Position = UDim2.new(1, -6, 0.42, 0)
        leftArrow.Size = UDim2.fromOffset(28, 28)
        rightArrow.Size = UDim2.fromOffset(28, 28)

        discordButton.Position = UDim2.new(1, -78, 0.5, 0)
        discordButton.Size = UDim2.fromOffset(72, 26)
        languageButton.Position = UDim2.new(1, -40, 0.5, 0)
        languageButton.Size = UDim2.fromOffset(26, 26)
        close.Position = UDim2.new(1, 0, 0.5, 0)
        close.Size = UDim2.fromOffset(26, 26)
    end

    main.Size = UDim2.fromOffset(width, height)
    noticeFrame.Size = UDim2.fromOffset(mobile and math.max(200, math.min(v.X - 28, 310)) or 310, mobile and 82 or 68)

    if mobile then
        local panelW = math.max(260, math.min(v.X - 32, 360))
        keyPanel.Size = UDim2.fromOffset(panelW, 280)
        languagePanel.Size = UDim2.fromOffset(panelW, 232)
    else
        keyPanel.Size = UDim2.fromOffset(360, 280)
        languagePanel.Size = UDim2.fromOffset(360, 232)
    end

    for _, c in ipairs(cards) do
        if c.Frame and c.Frame.Parent then
            c.Frame.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
            layoutCardContent(c)
        end
    end

    task.defer(function()
        applyCarouselVisuals(false)
    end)
end

local function safeResize()
    local ok, err = pcall(resize)
    if not ok then
        warn("[H3X4 Loader] resize error: " .. tostring(err))
    end
end

local function safeResizeDetails()
    local ok, err = pcall(resizeDetailsPanel)
    if not ok then
        warn("[H3X4 Loader] resizeDetails error: " .. tostring(err))
    end
end

safeResize()
if cam then
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(safeResize)
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(safeResizeDetails)
end
safeResizeDetails()

UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(safeResize)
UIS:GetPropertyChangedSignal("KeyboardEnabled"):Connect(safeResize)
UIS:GetPropertyChangedSignal("MouseEnabled"):Connect(safeResize)
UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(safeResizeDetails)
UIS:GetPropertyChangedSignal("KeyboardEnabled"):Connect(safeResizeDetails)
UIS:GetPropertyChangedSignal("MouseEnabled"):Connect(safeResizeDetails)

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not main.Visible or closing then return end
    if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
        moveCarousel(-1)
    elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
        moveCarousel(1)
    end
end)

if rememberedLanguage ~= nil then
    beginKeyFlow()
end
