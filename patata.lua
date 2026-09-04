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
        keyPlaceholder = "KEY",
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
        keyPlaceholder = "KEY",
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
    if #text <= 100 then
        return text
    end
    return string.sub(text, 1, 97) .. "..."
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

local function normalizeSearchText(value)
    local s = tostring(value or ""):lower()
    s = s:gsub("á", "a"):gsub("à", "a"):gsub("ä", "a"):gsub("â", "a")
    s = s:gsub("é", "e"):gsub("è", "e"):gsub("ë", "e"):gsub("ê", "e")
    s = s:gsub("í", "i"):gsub("ì", "i"):gsub("ï", "i"):gsub("î", "i")
    s = s:gsub("ó", "o"):gsub("ò", "o"):gsub("ö", "o"):gsub("ô", "o")
    s = s:gsub("ú", "u"):gsub("ù", "u"):gsub("ü", "u"):gsub("û", "u")
    s = s:gsub("ñ", "n"):gsub("ç", "c")
    s = s:gsub("[%p%c]", " ")
    s = s:gsub("%s+", " ")
    return s:match("^%s*(.-)%s*$") or s
end

local function buildSearchText(data)
    local parts = {
        data.Title,
        data.TitleES, data.TitleEs, data.TitleSpanish,
        data.TitleEN, data.TitleEn, data.TitleEnglish,
        data.Description,
        data.DescriptionES, data.DescriptionEs, data.DescriptionSpanish,
        data.DescriptionEN, data.DescriptionEn, data.DescriptionEnglish,
        fullLocalizedDescription(data),
    }
    local clean = {}
    for _, value in ipairs(parts) do
        if type(value) == "string" and value ~= "" then
            table.insert(clean, value)
        end
    end
    return normalizeSearchText(table.concat(clean, " "))
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
    Size = UDim2.fromOffset(1180, 760),
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


for i = 1, 18 do
    local line = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale((i % 6) / 5, (math.floor((i - 1) / 6) + 0.5) / 3),
        Size = UDim2.fromScale(0.38, 0.0012),
        Rotation = (i * 17) % 38 - 19,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = galaxy,
    })
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

for i = 1, 165 do
    local size = math.random(1, 3)
    local star = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(math.random(), math.random()),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = math.random(8, 58) / 100,
        BorderSizePixel = 0,
        ZIndex = 61,
        Parent = keyScreen,
    })
    round(star, 999)
    animateStar(star)
end

local keyGlowOuter = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 5),
    Size = UDim2.fromOffset(364, 276),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.28,
    BorderSizePixel = 0,
    ZIndex = 61,
    Parent = keyScreen,
})
round(keyGlowOuter, 22)
local keyGlowOuterStroke = stroke(keyGlowOuter, 0.72)
keyGlowOuterStroke.Thickness = 2
keyGlowOuterStroke.Color = Color3.fromRGB(255, 255, 255)

local keyPanel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(350, 262),
    BackgroundColor3 = Color3.fromRGB(7, 7, 8),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 62,
    Parent = keyScreen,
})
round(keyPanel, 18)
local keyPanelStroke = stroke(keyPanel, 0.28)
keyPanelStroke.Thickness = 1.2
keyPanelStroke.Color = Color3.fromRGB(255, 255, 255)

local keyPanelGradient = Instance.new("UIGradient")
keyPanelGradient.Rotation = 90
keyPanelGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 14, 15)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(8, 8, 9)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 5)),
})
keyPanelGradient.Parent = keyPanel

local topGlow = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 0),
    Size = UDim2.new(0.64, 0, 0, 1),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    ZIndex = 63,
    Parent = keyPanel,
})
round(topGlow, 999)

local keyPanelScale = new("UIScale", {
    Scale = 0.86,
    Parent = keyPanel,
})

local keyLogoGlow = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 13),
    Size = UDim2.fromOffset(136, 58),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.96,
    BorderSizePixel = 0,
    ZIndex = 63,
    Parent = keyPanel,
})
round(keyLogoGlow, 14)
local keyLogoGlowStroke = stroke(keyLogoGlow, 0.86)
keyLogoGlowStroke.Color = Color3.fromRGB(255, 255, 255)
keyLogoGlowStroke.Thickness = 1

local keyLogo = new("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(116, 50),
    BackgroundTransparency = 1,
    Image = "rbxassetid://85728959011477",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 64,
    Parent = keyLogoGlow,
})

local keyInputGlow = new("Frame", {
    Position = UDim2.fromOffset(18, 82),
    Size = UDim2.new(1, -36, 0, 46),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.95,
    BorderSizePixel = 0,
    ZIndex = 62,
    Parent = keyPanel,
})
round(keyInputGlow, 12)

local keyInputFrame = new("Frame", {
    Position = UDim2.fromOffset(19, 83),
    Size = UDim2.new(1, -38, 0, 44),
    BackgroundColor3 = Color3.fromRGB(12, 12, 13),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 63,
    Parent = keyPanel,
})
round(keyInputFrame, 11)
local keyInputStroke = stroke(keyInputFrame, 0.44)
keyInputStroke.Thickness = 1
keyInputStroke.Color = Color3.fromRGB(255, 255, 255)

local keyInput = new("TextBox", {
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -28, 1, 0),
    BackgroundTransparency = 1,
    PlaceholderText = T("keyPlaceholder"),
    PlaceholderColor3 = Color3.fromRGB(145, 145, 150),
    Text = "",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    TextStrokeTransparency = 1,
    ZIndex = 65,
    Parent = keyInputFrame,
})

keyInput.Focused:Connect(function()
    TweenService:Create(keyInputStroke, TweenInfo.new(0.14), {Transparency = 0.05, Thickness = 1.5}):Play()
    TweenService:Create(keyInputFrame, TweenInfo.new(0.14), {BackgroundColor3 = Color3.fromRGB(17, 17, 18)}):Play()
    TweenService:Create(keyInputGlow, TweenInfo.new(0.14), {BackgroundTransparency = 0.89}):Play()
end)

keyInput.FocusLost:Connect(function()
    TweenService:Create(keyInputStroke, TweenInfo.new(0.14), {Transparency = 0.44, Thickness = 1}):Play()
    TweenService:Create(keyInputFrame, TweenInfo.new(0.14), {BackgroundColor3 = Color3.fromRGB(12, 12, 13)}):Play()
    TweenService:Create(keyInputGlow, TweenInfo.new(0.14), {BackgroundTransparency = 0.95}):Play()
end)

local rememberKeyChoice = false

local verifyKeyButton = new("TextButton", {
    Position = UDim2.fromOffset(19, 140),
    Size = UDim2.new(0.5, -24, 0, 38),
    BackgroundColor3 = Color3.fromRGB(245, 245, 245),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Text = T("verifyKey"),
    TextColor3 = Color3.fromRGB(5, 5, 6),
    TextStrokeTransparency = 1,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 63,
    Parent = keyPanel,
})
round(verifyKeyButton, 10)
local verifyStroke = stroke(verifyKeyButton, 0.72)
verifyStroke.Color = Color3.fromRGB(255, 255, 255)
verifyStroke.Thickness = 1

local getKeyButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -19, 0, 140),
    Size = UDim2.new(0.5, -24, 0, 38),
    BackgroundColor3 = Color3.fromRGB(14, 14, 15),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Text = T("getKeyDiscord"),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextStrokeTransparency = 1,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 63,
    Parent = keyPanel,
})
round(getKeyButton, 10)
local getKeyStroke = stroke(getKeyButton, 0.35)
getKeyStroke.Color = Color3.fromRGB(255, 255, 255)
getKeyStroke.Thickness = 1

local rememberKeyButton = new("TextButton", {
    Position = UDim2.fromOffset(19, 190),
    Size = UDim2.new(1, -38, 0, 40),
    BackgroundColor3 = Color3.fromRGB(11, 11, 12),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 63,
    Parent = keyPanel,
})
round(rememberKeyButton, 10)
local rememberKeyStroke = stroke(rememberKeyButton, 0.58)
rememberKeyStroke.Thickness = 1
rememberKeyStroke.Color = Color3.fromRGB(255, 255, 255)

local rememberKeyLabel = new("TextLabel", {
    Position = UDim2.fromOffset(13, 0),
    Size = UDim2.new(1, -72, 1, 0),
    BackgroundTransparency = 1,
    Text = T("rememberKey"),
    TextColor3 = Color3.fromRGB(218, 218, 222),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 1,
    ZIndex = 64,
    Parent = rememberKeyButton,
})

local rememberKeyTrack = new("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(42, 22),
    BackgroundColor3 = Color3.fromRGB(43, 43, 46),
    BorderSizePixel = 0,
    ZIndex = 64,
    Parent = rememberKeyButton,
})
round(rememberKeyTrack, 999)
local rememberTrackStroke = stroke(rememberKeyTrack, 0.74)
rememberTrackStroke.Color = Color3.fromRGB(255, 255, 255)
rememberTrackStroke.Thickness = 1

local rememberKeyKnob = new("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 3, 0.5, 0),
    Size = UDim2.fromOffset(16, 16),
    BackgroundColor3 = Color3.fromRGB(245, 245, 245),
    BorderSizePixel = 0,
    ZIndex = 65,
    Parent = rememberKeyTrack,
})
round(rememberKeyKnob, 999)

local keyStatusLabel = new("TextLabel", {
    Position = UDim2.fromOffset(19, 232),
    Size = UDim2.new(1, -38, 0, 16),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Color3.fromRGB(188, 188, 192),
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextWrapped = true,
    TextStrokeTransparency = 1,
    ZIndex = 63,
    Parent = keyPanel,
})

local function updateRememberKeyButton()
    rememberKeyLabel.Text = T("rememberKey")
    rememberKeyLabel.TextColor3 = rememberKeyChoice and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 190, 194)

    TweenService:Create(
        rememberKeyTrack,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = rememberKeyChoice and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(43, 43, 46)}
    ):Play()

    TweenService:Create(
        rememberKeyKnob,
        TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = rememberKeyChoice and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = rememberKeyChoice and Color3.fromRGB(12, 12, 13) or Color3.fromRGB(245, 245, 245),
        }
    ):Play()

    rememberKeyButton.BackgroundColor3 = rememberKeyChoice and Color3.fromRGB(17, 17, 18) or Color3.fromRGB(11, 11, 12)
    rememberKeyStroke.Transparency = rememberKeyChoice and 0.28 or 0.58
    rememberKeyStroke.Thickness = rememberKeyChoice and 1.2 or 1
end

local function updateKeyLanguage()
    keyInput.PlaceholderText = T("keyPlaceholder")
    verifyKeyButton.Text = T("verifyKey")
    getKeyButton.Text = T("getKeyDiscord")
    updateRememberKeyButton()
end

rememberKeyButton.MouseButton1Click:Connect(function()
    rememberKeyChoice = not rememberKeyChoice
    if not rememberKeyChoice then
        clearRememberedKey()
    end
    updateRememberKeyButton()
end)

verifyKeyButton.MouseEnter:Connect(function()
    TweenService:Create(verifyKeyButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(220, 220, 222)}):Play()
end)
verifyKeyButton.MouseLeave:Connect(function()
    TweenService:Create(verifyKeyButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(245, 245, 245)}):Play()
end)
verifyKeyButton.MouseButton1Down:Connect(function()
    TweenService:Create(verifyKeyButton, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(195, 195, 198)}):Play()
end)
verifyKeyButton.MouseButton1Up:Connect(function()
    TweenService:Create(verifyKeyButton, TweenInfo.new(0.09), {BackgroundColor3 = Color3.fromRGB(245, 245, 245)}):Play()
end)
getKeyButton.MouseEnter:Connect(function()
    TweenService:Create(getKeyButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(24, 24, 26)}):Play()
    TweenService:Create(getKeyStroke, TweenInfo.new(0.12), {Transparency = 0.08, Thickness = 1.3}):Play()
end)
getKeyButton.MouseLeave:Connect(function()
    TweenService:Create(getKeyButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(14, 14, 15)}):Play()
    TweenService:Create(getKeyStroke, TweenInfo.new(0.12), {Transparency = 0.35, Thickness = 1}):Play()
end)
getKeyButton.MouseButton1Down:Connect(function()
    TweenService:Create(getKeyButton, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(32, 32, 34)}):Play()
end)
getKeyButton.MouseButton1Up:Connect(function()
    TweenService:Create(getKeyButton, TweenInfo.new(0.09), {BackgroundColor3 = Color3.fromRGB(14, 14, 15)}):Play()
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


local updateCardOrder
local updateSearch
local sortRecentFirst = true
local closing = false

local content = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 5,
    Parent = main,
})

local header = new("Frame", {
    Position = UDim2.fromOffset(22, 18),
    Size = UDim2.new(1, -44, 0, 76),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = content,
})

local headerLogo = new("ImageLabel", {
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(155, 42),
    BackgroundTransparency = 1,
    Image = "rbxassetid://85728959011477",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 7,
    Parent = header,
})

local subtitleLabel = new("TextLabel", {
    Position = UDim2.fromOffset(0, 46),
    Size = UDim2.fromOffset(230, 22),
    BackgroundTransparency = 1,
    Text = T("loaderSubtitle"),
    TextColor3 = Color3.fromRGB(220, 220, 220),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = header,
})

local close = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 8),
    Size = UDim2.fromOffset(54, 54),
    BackgroundColor3 = Color3.fromRGB(8, 8, 9),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 30,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 8,
    Parent = header,
})
round(close, 13)
local closeStroke = stroke(close, 0.72)
closeStroke.Thickness = 1.1

local languageButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -76, 0, 8),
    Size = UDim2.fromOffset(132, 54),
    BackgroundColor3 = Color3.fromRGB(8, 8, 9),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "◎  " .. string.upper(currentLanguage) .. "  ˅",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 8,
    Parent = header,
})
round(languageButton, 13)
stroke(languageButton, 0.76).Thickness = 1.05

local countBadge = new("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -224, 0, 8),
    Size = UDim2.fromOffset(142, 54),
    BackgroundColor3 = Color3.fromRGB(8, 8, 9),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "0 " .. T("scripts"),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    ZIndex = 7,
    Parent = header,
})
round(countBadge, 13)
stroke(countBadge, 0.8).Thickness = 1

local discordButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -374, 0, 8),
    Size = UDim2.fromOffset(138, 54),
    BackgroundColor3 = Color3.fromRGB(8, 8, 9),
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    Text = "◉  Discord",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 8,
    Parent = header,
})
round(discordButton, 13)
local discordStroke = stroke(discordButton, 0.72)
discordStroke.Thickness = 1.1

local sidebar = new("Frame", {
    Position = UDim2.fromOffset(22, 116),
    Size = UDim2.fromOffset(56, 0),
    BackgroundColor3 = Color3.fromRGB(8, 8, 9),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ZIndex = 7,
    Parent = content,
})
round(sidebar, 18)
stroke(sidebar, 0.74).Thickness = 1

local sideLayout = new("UIListLayout", {
    Padding = UDim.new(0, 10),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = sidebar,
})
new("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingBottom = UDim.new(0, 12),
    Parent = sidebar,
})

local currentView = "all"

local function createSideButton(icon, order)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = Color3.fromRGB(14, 14, 15),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = icon,
        TextColor3 = Color3.fromRGB(210, 210, 212),
        TextSize = 20,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 8,
        Parent = sidebar,
    })
    round(b, 12)
    local s = stroke(b, 1)
    s.Thickness = 1
    return b, s
end

local homeButton, homeStroke = createSideButton("⌂", 1)
local favoritesViewButton, favoritesStroke = createSideButton("☆", 2)
local searchSideButton, searchSideStroke = createSideButton("⌕", 3)
local discordSideButton, discordSideStroke = createSideButton("◉", 4)

local function setSideActive(button, line, active)
    TweenService:Create(button, TweenInfo.new(0.15), {
        BackgroundTransparency = active and 0.18 or 1,
        TextColor3 = active and Color3.new(1,1,1) or Color3.fromRGB(210,210,212),
    }):Play()
    TweenService:Create(line, TweenInfo.new(0.15), {
        Transparency = active and 0.35 or 1,
        Thickness = active and 1.35 or 1,
    }):Play()
end

local searchFrame = new("Frame", {
    Position = UDim2.fromOffset(100, 104),
    Size = UDim2.new(1, -372, 0, 62),
    BackgroundColor3 = Color3.fromRGB(10, 10, 11),
    BackgroundTransparency = 0.03,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = content,
})
round(searchFrame, 16)
local searchStroke = stroke(searchFrame, 0.78)
searchStroke.Thickness = 1.05

local searchIcon = new("TextLabel", {
    Position = UDim2.fromOffset(18, 0),
    Size = UDim2.fromOffset(30, 62),
    BackgroundTransparency = 1,
    Text = "⌕",
    TextColor3 = Color3.fromRGB(220,220,220),
    TextSize = 24,
    Font = Enum.Font.Gotham,
    ZIndex = 7,
    Parent = searchFrame,
})

local search = new("TextBox", {
    Position = UDim2.fromOffset(58, 0),
    Size = UDim2.new(1, -72, 1, 0),
    BackgroundTransparency = 1,
    PlaceholderText = T("search"),
    PlaceholderColor3 = Color3.fromRGB(170, 170, 174),
    Text = "",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 15,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 7,
    Parent = searchFrame,
})

local orderButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -22, 0, 104),
    Size = UDim2.fromOffset(238, 62),
    BackgroundColor3 = Color3.fromRGB(10, 10, 11),
    BackgroundTransparency = 0.03,
    BorderSizePixel = 0,
    Text = "⇅   " .. (currentLanguage == "en" and "Order" or "Ordenar") .. "   ˅",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 15,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 7,
    Parent = content,
})
round(orderButton, 16)
stroke(orderButton, 0.78).Thickness = 1.05

local list = new("ScrollingFrame", {
    Position = UDim2.fromOffset(100, 190),
    Size = UDim2.new(1, -122, 1, -246),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Color3.fromRGB(220, 220, 220),
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    ScrollingDirection = Enum.ScrollingDirection.X,
    ClipsDescendants = false,
    ZIndex = 6,
    Parent = content,
})

local cardLayout = new("UIListLayout", {
    Padding = UDim.new(0, 18),
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = list,
})


new("UIPadding", {
    PaddingLeft = UDim.new(0, 18),
    PaddingRight = UDim.new(0, 18),
    PaddingTop = UDim.new(0, 12),
    PaddingBottom = UDim.new(0, 12),
    Parent = list,
})

local carouselLeft = new("TextButton", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 90, 0.5, 40),
    Size = UDim2.fromOffset(48, 48),
    BackgroundColor3 = Color3.fromRGB(8,8,9),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Text = "‹",
    TextColor3 = Color3.new(1,1,1),
    TextSize = 32,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 12,
    Parent = content,
})
round(carouselLeft, 999)
stroke(carouselLeft, 0.65)

local carouselRight = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -20, 0.5, 40),
    Size = UDim2.fromOffset(48, 48),
    BackgroundColor3 = Color3.fromRGB(8,8,9),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Text = "›",
    TextColor3 = Color3.new(1,1,1),
    TextSize = 32,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 12,
    Parent = content,
})
round(carouselRight, 999)
stroke(carouselRight, 0.65)

local function moveCarousel(direction)
    local maxX = math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteSize.X)
    local target = math.clamp(list.CanvasPosition.X + (direction * math.floor(list.AbsoluteSize.X * 0.72)), 0, maxX)
    TweenService:Create(list, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CanvasPosition = Vector2.new(target, 0),
    }):Play()
end

carouselLeft.MouseButton1Click:Connect(function()
    moveCarousel(-1)
end)
carouselRight.MouseButton1Click:Connect(function()
    moveCarousel(1)
end)

local status = new("TextLabel", {
    Position = UDim2.fromOffset(100, 1),
    Size = UDim2.fromOffset(0, 0),
    BackgroundTransparency = 1,
    Text = T("loadingScripts"),
    TextColor3 = Color3.fromRGB(145, 145, 148),
    TextSize = 0,
    Font = Enum.Font.Gotham,
    Visible = false,
    ZIndex = 7,
    Parent = content,
})

local noResults = new("TextLabel", {
    Position = UDim2.new(0, 100, 0, 185),
    Size = UDim2.new(1, -122, 1, -246),
    BackgroundTransparency = 1,
    Text = T("noResults"),
    TextColor3 = Color3.fromRGB(190, 190, 194),
    TextSize = 16,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    Visible = false,
    ZIndex = 8,
    Parent = content,
})

orderButton.MouseButton1Click:Connect(function()
    sortRecentFirst = not sortRecentFirst
    orderButton.Text = sortRecentFirst
        and ("⇅   " .. (currentLanguage == "en" and "Order: Recent" or "Ordenar: Recientes") .. "   ˅")
        or ("⇅   " .. (currentLanguage == "en" and "Order: Oldest" or "Ordenar: Antiguos") .. "   ˅")
    if updateCardOrder then
        updateCardOrder()
    end
end)

search.Focused:Connect(function()
    TweenService:Create(searchFrame, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(18, 18, 20),
        BackgroundTransparency = 0,
    }):Play()
    TweenService:Create(searchStroke, TweenInfo.new(0.15), {
        Transparency = 0.32,
        Thickness = 1.6,
    }):Play()
end)

search.FocusLost:Connect(function()
    TweenService:Create(searchFrame, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(10, 10, 11),
        BackgroundTransparency = 0.03,
    }):Play()
    TweenService:Create(searchStroke, TweenInfo.new(0.15), {
        Transparency = 0.78,
        Thickness = 1.05,
    }):Play()
end)

searchSideButton.MouseButton1Click:Connect(function()
    search:CaptureFocus()
end)

discordSideButton.MouseButton1Click:Connect(function()
    local copied = false
    if type(setclipboard) == "function" then
        copied = pcall(setclipboard, DISCORD_URL)
    elseif type(toclipboard) == "function" then
        copied = pcall(toclipboard, DISCORD_URL)
    end
    if copied then
        showNotice(T("discordCopied"))
    else
        showNotice(T("discordCopyFailed"))
    end
end)

local function updateSideState()
    setSideActive(homeButton, homeStroke, currentView == "all")
    setSideActive(favoritesViewButton, favoritesStroke, currentView == "favorites")
    setSideActive(searchSideButton, searchSideStroke, false)
    setSideActive(discordSideButton, discordSideStroke, false)
end

updateSideState()

local function resizeMainInterface()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local viewport = cam.ViewportSize
    local mobile = UIS.TouchEnabled and not (UIS.KeyboardEnabled and UIS.MouseEnabled)

    local width
    local height
    if mobile then
        width = math.floor(math.clamp(viewport.X * 0.94, 320, 560))
        height = math.floor(math.clamp(viewport.Y * 0.86, 500, 760))
    else
        width = math.floor(math.clamp(viewport.X * 0.94, 760, 1450))
        height = math.floor(math.clamp(viewport.Y * 0.90, 560, 900))
    end

    main.Size = UDim2.fromOffset(width, height)

    local sideW = mobile and 48 or 56
    local outer = mobile and 12 or 22
    local headerH = mobile and 66 or 76
    local searchY = mobile and 90 or 104
    local searchH = mobile and 50 or 62
    local sideY = mobile and 90 or 116
    local listY = mobile and 154 or 190
    local listBottom = mobile and 20 or 26
    local mainContentLeft = outer + sideW + (mobile and 12 or 22)
    local orderW = mobile and 118 or 238

    header.Position = UDim2.fromOffset(outer, mobile and 12 or 18)
    header.Size = UDim2.new(1, -(outer*2), 0, headerH)

    headerLogo.Size = UDim2.fromOffset(mobile and 108 or 155, mobile and 30 or 42)
    subtitleLabel.Position = UDim2.fromOffset(0, mobile and 32 or 46)
    subtitleLabel.Size = UDim2.fromOffset(mobile and 150 or 230, mobile and 18 or 22)
    subtitleLabel.TextSize = mobile and 10 or 13

    close.Size = UDim2.fromOffset(mobile and 40 or 54, mobile and 40 or 54)
    close.Position = UDim2.new(1, 0, 0, mobile and 0 or 8)
    close.TextSize = mobile and 24 or 30

    languageButton.Size = UDim2.fromOffset(mobile and 74 or 132, mobile and 40 or 54)
    languageButton.Position = UDim2.new(1, -(mobile and 50 or 76), 0, mobile and 0 or 8)
    languageButton.TextSize = mobile and 10 or 13

    countBadge.Size = UDim2.fromOffset(mobile and 78 or 142, mobile and 40 or 54)
    countBadge.Position = UDim2.new(1, -(mobile and 132 or 224), 0, mobile and 0 or 8)
    countBadge.TextSize = mobile and 9 or 13

    discordButton.Size = UDim2.fromOffset(mobile and 86 or 138, mobile and 40 or 54)
    discordButton.Position = UDim2.new(1, -(mobile and 220 or 374), 0, mobile and 0 or 8)
    discordButton.Text = mobile and "◉" or "◉  Discord"
    discordButton.TextSize = mobile and 12 or 13

    sidebar.Position = UDim2.fromOffset(outer, sideY)
    sidebar.Size = UDim2.fromOffset(sideW, math.max(210, height - sideY - outer))
    for _, child in ipairs(sidebar:GetChildren()) do
        if child:IsA("TextButton") then
            child.Size = UDim2.fromOffset(mobile and 34 or 40, mobile and 34 or 40)
            child.TextSize = mobile and 17 or 20
        end
    end

    if mobile then
        searchFrame.Position = UDim2.fromOffset(mainContentLeft, searchY)
        searchFrame.Size = UDim2.new(1, -(mainContentLeft + outer), 0, searchH)
        orderButton.Position = UDim2.fromOffset(mainContentLeft, searchY + searchH + 8)
        orderButton.AnchorPoint = Vector2.new(0, 0)
        orderButton.Size = UDim2.new(1, -(mainContentLeft + outer), 0, 42)
        listY = searchY + searchH + 62
        listBottom = 16
    else
        searchFrame.Position = UDim2.fromOffset(mainContentLeft, searchY)
        searchFrame.Size = UDim2.new(1, -(mainContentLeft + outer + orderW + 12), 0, searchH)
        orderButton.Position = UDim2.new(1, -outer, 0, searchY)
        orderButton.AnchorPoint = Vector2.new(1, 0)
        orderButton.Size = UDim2.fromOffset(orderW, searchH)
    end

    searchIcon.Size = UDim2.fromOffset(mobile and 26 or 30, searchH)
    searchIcon.Position = UDim2.fromOffset(mobile and 12 or 18, 0)
    searchIcon.TextSize = mobile and 20 or 24
    search.Position = UDim2.fromOffset(mobile and 46 or 58, 0)
    search.Size = UDim2.new(1, -(mobile and 56 or 72), 1, 0)
    search.TextSize = mobile and 12 or 15
    orderButton.TextSize = mobile and 11 or 15

    list.Position = UDim2.fromOffset(mainContentLeft, listY)
    list.Size = UDim2.new(1, -(mainContentLeft + outer), 1, -(listY + listBottom))

    noResults.Position = UDim2.fromOffset(mainContentLeft, listY)
    noResults.Size = UDim2.new(1, -(mainContentLeft + outer), 1, -(listY + listBottom))
    noResults.TextSize = mobile and 13 or 16

    carouselLeft.Position = UDim2.new(0, mainContentLeft - (mobile and 18 or 10), 0.5, mobile and 65 or 40)
    carouselLeft.Size = UDim2.fromOffset(mobile and 34 or 48, mobile and 34 or 48)
    carouselLeft.TextSize = mobile and 24 or 32
    carouselRight.Position = UDim2.new(1, -outer + (mobile and 8 or 2), 0.5, mobile and 65 or 40)
    carouselRight.Size = UDim2.fromOffset(mobile and 34 or 48, mobile and 34 or 48)
    carouselRight.TextSize = mobile and 24 or 32
end

resizeMainInterface()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        resizeMainInterface()
    end)
end

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
    BackgroundTransparency = 0.03,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = Color3.new(0, 0, 0),
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
        panelWidth = math.min(math.clamp(viewport.X * 0.58, 205, 270), viewport.X - 90)
        panelHeight = math.min(math.clamp(viewport.Y * 0.45, 245, 330), viewport.Y - 150)
        imageHeight = math.clamp(math.floor(panelWidth * 0.27), 56, 74)
    else
        panelWidth = math.min(math.clamp(viewport.X * 0.52, 520, 680), viewport.X - 50)
        panelHeight = math.min(math.clamp(viewport.Y * 0.76, 520, 700), viewport.Y - 50)
        imageHeight = math.clamp(math.floor(panelWidth * 0.34), 165, 220)
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
        local luminance = (tag.Color.R * 0.299) + (tag.Color.G * 0.587) + (tag.Color.B * 0.114)
        detailsTag.TextColor3 = luminance > 0.62 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
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
        local oldText = discordButton.Text
        discordButton.Text = "✓ Discord"
        task.delay(1.1, function()
            if discordButton and discordButton.Parent then
                discordButton.Text = oldText
            end
        end)
    else
        status.Text = T("discordCopyFailed")
    end
end)

local cards = {}
local userIsVip = false

updateCardOrder = function()
    for _, c in ipairs(cards) do
        if c.Frame and c.Frame.Parent then
            local rawIndex = tonumber(c.RawIndex) or 0
            local orderIndex = sortRecentFirst and -rawIndex or rawIndex
            if isFavorite(c.Data) then
                c.Frame.LayoutOrder = -100000 + orderIndex
            else
                c.Frame.LayoutOrder = 100000 + orderIndex
            end
        end
    end
end

local function cardIsMobile()
    return UIS.TouchEnabled and not (UIS.KeyboardEnabled and UIS.MouseEnabled)
end


local selectedCard = nil

local function setSelectedCard(entry)
    if selectedCard and selectedCard ~= entry and selectedCard.Stroke and selectedCard.Stroke.Parent then
        TweenService:Create(selectedCard.Stroke, TweenInfo.new(0.16), {
            Transparency = 0.82,
            Thickness = 1,
        }):Play()
        if selectedCard.Frame then
            TweenService:Create(selectedCard.Frame, TweenInfo.new(0.16), {
                BackgroundTransparency = 0.08,
            }):Play()
        end
    end

    selectedCard = entry

    if entry and entry.Stroke and entry.Stroke.Parent then
        TweenService:Create(entry.Stroke, TweenInfo.new(0.16), {
            Transparency = 0.18,
            Thickness = 1.65,
        }):Play()
        TweenService:Create(entry.Frame, TweenInfo.new(0.16), {
            BackgroundTransparency = 0.01,
        }):Play()
    end
end

local function createCard(data, index)
    if data.Enabled == false then
        return
    end

    local title = localizedTitle(data)
    local description = localizedDescription(data)
    local tag = getTag(data)

    local mobileCard = cardIsMobile()
    local cardWidth = mobileCard and 215 or 260
    local cardHeight = mobileCard and 330 or 420
    local imageHeight = mobileCard and 126 or 176

    local card = new("Frame", {
        Size = UDim2.fromOffset(cardWidth, cardHeight),
        BackgroundColor3 = Color3.fromRGB(8, 8, 9),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        ClipsDescendants = false,
        Active = true,
        ZIndex = 7,
        Parent = list,
    })
    round(card, 18)
    local cardStroke = stroke(card, 0.82)
    cardStroke.Thickness = 1

    local imageHolder = new("Frame", {
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 0, imageHeight),
        BackgroundColor3 = Color3.fromRGB(4, 4, 5),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 8,
        Parent = card,
    })
    round(imageHolder, 14)
    stroke(imageHolder, 0.9)

    local cardImage = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = tostring(data.Image or ""),
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 9,
        Parent = imageHolder,
    })

    local tagLabel
    if tag then
        local tagWidth = math.clamp(32 + (#tag.Title * 7), 72, 155)
        tagLabel = new("TextLabel", {
            Position = UDim2.fromOffset(10, 10),
            Size = UDim2.fromOffset(tagWidth, 28),
            BackgroundColor3 = Color3.fromRGB(12, 12, 13),
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            Text = tag.Title,
            TextColor3 = Color3.new(1,1,1),
            TextSize = mobileCard and 9 or 11,
            Font = Enum.Font.Gotham,
            ZIndex = 12,
            Parent = imageHolder,
        })
        round(tagLabel, 9)
        local tagStroke = stroke(tagLabel, 0.76)
        tagStroke.Color = tag.Color
        tagStroke.Thickness = 1.1
    end

    local favoriteButton = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 10),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Color3.fromRGB(9, 9, 10),
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Text = isFavorite(data) and "★" or "☆",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 23,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        ZIndex = 13,
        Parent = imageHolder,
    })
    round(favoriteButton, 12)
    stroke(favoriteButton, 0.72)

    local detailsButton = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -52, 0, 10),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Color3.fromRGB(9, 9, 10),
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Text = "i",
        TextColor3 = Color3.new(1,1,1),
        TextSize = 19,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        ZIndex = 13,
        Parent = imageHolder,
    })
    round(detailsButton, 12)
    stroke(detailsButton, 0.72)

    local titleY = 20 + imageHeight
    local titleLabel = new("TextLabel", {
        Position = UDim2.fromOffset(16, titleY),
        Size = UDim2.new(1, -32, 0, mobileCard and 44 or 52),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = mobileCard and 15 or 19,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 8,
        Parent = card,
    })

    local descriptionY = titleY + (mobileCard and 48 or 58)
    local descriptionLabel = new("TextLabel", {
        Position = UDim2.fromOffset(16, descriptionY),
        Size = UDim2.new(1, -32, 0, mobileCard and 92 or 104),
        BackgroundTransparency = 1,
        Text = description,
        TextColor3 = Color3.fromRGB(190, 190, 194),
        TextSize = mobileCard and 12 or 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        ZIndex = 8,
        Parent = card,
    })

    local button = new("TextButton", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -14),
        Size = UDim2.new(1, -32, 0, mobileCard and 42 or 52),
        BackgroundColor3 = Color3.fromRGB(244, 244, 246),
        BorderSizePixel = 0,
        Text = T("execute") .. "     ▶",
        TextColor3 = Color3.fromRGB(8, 8, 9),
        TextSize = mobileCard and 11 or 14,
        Font = Enum.Font.Gotham,
        AutoButtonColor = false,
        ZIndex = 9,
        Parent = card,
    })
    round(button, 12)

    local entry = {
        Frame = card,
        Data = data,
        TitleLabel = titleLabel,
        DescriptionLabel = descriptionLabel,
        Button = button,
        DetailsButton = detailsButton,
        FavoriteButton = favoriteButton,
        TagLabel = tagLabel,
        RawIndex = index,
        Title = title:lower(),
        Description = description:lower(),
        Tag = tag and tag.Title:lower() or "",
        SearchText = buildSearchText(data) .. " " .. normalizeSearchText(tag and tag.Title or ""),
        Stroke = cardStroke,
    }

    favoriteButton.MouseButton1Click:Connect(function()
        local newValue = not isFavorite(data)
        setFavorite(data, newValue)
        favoriteButton.Text = newValue and "★" or "☆"
        updateCardOrder()
        status.Text = newValue and T("favoriteAdded") or T("favoriteRemoved")
        if currentView == "favorites" then
            updateSearch()
        end
    end)

    detailsButton.MouseButton1Click:Connect(function()
        setSelectedCard(entry)
        openDetails(data)
    end)

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setSelectedCard(entry)
        end
    end)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.new(1,1,1),
        }):Play()
        setSelectedCard(entry)
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(244,244,246),
        }):Play()
    end)
    button.MouseButton1Down:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.08), {
            BackgroundColor3 = Color3.fromRGB(210,210,212),
        }):Play()
    end)
    button.MouseButton1Up:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(244,244,246),
        }):Play()
    end)

    button.MouseButton1Click:Connect(function()
        if closing then return end

        setSelectedCard(entry)
        local activeTitle = localizedTitle(data)
        button.Text = T("loading")
        status.Text = string.format(T("preparing"), activeTitle)

        task.spawn(function()
            local ok, result = pcall(function()
                local src = game:HttpGet(data.URL, true)
                local fn, err = loadstring(src)
                if not fn then error(err) end
                return fn
            end)

            if not ok then
                if button and button.Parent then button.Text = "ERROR" end
                status.Text = string.format(T("loadError"), activeTitle)
                warn("[H3X4 Loader] " .. tostring(result))
                task.wait(1.1)
                if button and button.Parent then button.Text = T("execute") .. "     ▶" end
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
    end)

    table.insert(cards, entry)
    updateCardOrder()

    if not selectedCard then
        setSelectedCard(entry)
    end
end

updateSearch = function()
    local q = normalizeSearchText(search.Text)
    local found = 0

    for _, c in ipairs(cards) do
        local haystack = c.SearchText or normalizeSearchText((c.Title or "") .. " " .. (c.Description or "") .. " " .. (c.Tag or ""))
        local matchesText = q == "" or string.find(haystack, q, 1, true) ~= nil
        local matchesView = currentView ~= "favorites" or isFavorite(c.Data)
        local visible = matchesText and matchesView

        c.Frame.Visible = visible
        if visible then
            found += 1
        end
    end

    noResults.Visible = found == 0
    if q == "" and currentView == "all" then
        status.Text = (#cards == 1) and T("oneAvailable") or string.format(T("available"), #cards)
    elseif q == "" and currentView == "favorites" then
        status.Text = currentLanguage == "en" and (tostring(found) .. " favorites") or (tostring(found) .. " favoritos")
    else
        status.Text = (found == 1) and T("oneResult") or string.format(T("results"), found)
    end
end

homeButton.MouseButton1Click:Connect(function()
    currentView = "all"
    updateSideState()
    updateSearch()
end)

favoritesViewButton.MouseButton1Click:Connect(function()
    currentView = "favorites"
    updateSideState()
    updateSearch()
end)

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
        countBadge.Text = "0 " .. T("scripts")
        warn("[H3X4 Loader] " .. tostring(result))
        return
    end

    for i, data in ipairs(result) do
        if typeof(data) == "table" then
            createCard(data, i)
        end
    end

    updateCardOrder()
    countBadge.Text = tostring(#cards) .. " " .. ((#cards == 1) and T("script") or T("scripts"))
    status.Text = (#cards == 1) and T("oneAvailable") or string.format(T("available"), #cards)
end


local catalogLoaded = false

local function refreshCardsLanguage()
    for _, c in ipairs(cards) do
        if c.Data then
            local title = localizedTitle(c.Data)
            local description = localizedDescription(c.Data)

            c.Title = title:lower()
            c.Description = description:lower()
            c.SearchText = buildSearchText(c.Data)

            if c.TitleLabel and c.TitleLabel.Parent then
                c.TitleLabel.Text = title
            end
            if c.DescriptionLabel and c.DescriptionLabel.Parent then
                c.DescriptionLabel.Text = description
            end
            if c.Button and c.Button.Parent then
                c.Button.Text = T("execute")
            end
            if c.DetailsButton and c.DetailsButton.Parent then
                c.DetailsButton.Text = "i"
            end
            local tag = getTag(c.Data)
            c.Tag = tag and tag.Title:lower() or ""
            c.SearchText = c.SearchText .. " " .. normalizeSearchText(tag and tag.Title or "")

            if c.TagLabel and c.TagLabel.Parent then
                if tag then
                    local tagWidth = math.clamp(26 + (#tag.Title * 6), 58, 118)
                    c.TagLabel.Size = UDim2.fromOffset(math.clamp(32 + (#tag.Title * 7), 72, 155), 28)
                    c.TagLabel.Visible = true
                    c.TagLabel.Text = tag.Title
                    c.TagLabel.BackgroundColor3 = Color3.fromRGB(12, 12, 13)
                    c.TagLabel.TextColor3 = Color3.new(1, 1, 1)
                    local tagStroke = c.TagLabel:FindFirstChildOfClass("UIStroke")
                    if tagStroke then
                        tagStroke.Color = tag.Color
                    end
                else
                    c.TagLabel.Visible = false
                end
            elseif tag and c.Frame and c.Frame.Parent then
            end
        end
    end
end

local function applyLanguageToUI()
    subtitleLabel.Text = T("loaderSubtitle")
    search.PlaceholderText = T("search")
    noResults.Text = T("noResults")
    languageButton.Text = (UIS.TouchEnabled and not (UIS.KeyboardEnabled and UIS.MouseEnabled)) and ("◎  " .. string.upper(currentLanguage)) or ("◎  " .. string.upper(currentLanguage) .. "  ˅")
    detailsHeader.Text = T("detailsTitle")
    orderButton.Text = sortRecentFirst
        and ("⇅   " .. (currentLanguage == "en" and "Order: Recent" or "Ordenar: Recientes") .. "   ˅")
        or ("⇅   " .. (currentLanguage == "en" and "Order: Oldest" or "Ordenar: Antiguos") .. "   ˅")
    if detailsShade.Visible and currentDetailsData then
        refreshDetails()
    end

    if not catalogLoaded then
        status.Text = T("loadingScripts")
        countBadge.Text = "0 " .. T("scripts")
    else
        refreshCardsLanguage()
        countBadge.Text = tostring(#cards) .. " " .. ((#cards == 1) and T("script") or T("scripts"))
        updateSearch()
    end
end

local function openMainLoader()
    resizeMainInterface()
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

        local saved = readRememberedKey()
        if saved then
            keyFlowBusy = false
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
            keyAuthorized = true
            keyScreen.Visible = false
            openMainLoader()
            return
        end

        showKeyPanel("")
    end)
end

verifyKeyButton.MouseButton1Click:Connect(function()
    if keyFlowBusy then return end
    keyFlowBusy = true
    verifyKeyButton.Text = T("checkingKey")
    keyStatusLabel.Text = ""

    task.spawn(function()
        local config, err = loadKeyConfig()
        keyFlowBusy = false
        verifyKeyButton.Text = T("verifyKey")

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

close.MouseButton1Click:Connect(function()
    if closing then
        return
    end
    closing = true
    TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.94}):Play()
    TweenService:Create(overlay, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
    task.delay(0.19, function()
        if gui and gui.Parent then
            gui:Destroy()
        end
    end)
end)

resizeMainInterface()
resizeDetailsPanel()

if cam then
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        resizeMainInterface()
        resizeDetailsPanel()
    end)
end

UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
    resizeMainInterface()
    resizeDetailsPanel()
end)
UIS:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
    resizeMainInterface()
    resizeDetailsPanel()
end)
UIS:GetPropertyChangedSignal("MouseEnabled"):Connect(function()
    resizeMainInterface()
    resizeDetailsPanel()
end)

if rememberedLanguage ~= nil then
    beginKeyFlow()
end
