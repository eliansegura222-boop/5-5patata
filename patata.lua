--[[
    HX AvatarChange
    Universal avatar try-on/editor for Roblox.

    Core goals:
      • Search the Roblox avatar catalog (AvatarEditorService first, HTTP fallback).
      • Try assets by search or direct ID.
      • Edit a working HumanoidDescription and preview it on the local character.
      • Save the resulting avatar to the Roblox platform with PromptSaveAvatar.
      • Save an outfit with PromptCreateOutfit.
      • Copy avatars from players in the current server.
      • Local presets when readfile/writefile are supported.

    IMPORTANT:
      Local preview changes are client-side in games that do not replicate appearance edits.
      "SAVE ROBLOX" uses Roblox's official AvatarEditorService prompt and is the platform-persistent path.
]]

--// Cleanup previous instance
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.HXAvatarCleanup then
    pcall(ENV.HXAvatarCleanup)
    ENV.HXAvatarCleanup = nil
end

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local old = PlayerGui:FindFirstChild("HXAvatarChange")
if old then old:Destroy() end

--// Executor / compatibility helpers
local function getRequestFunction()
    local e = (type(getgenv) == "function" and getgenv()) or _G
    return (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (e.syn and type(e.syn.request) == "function" and e.syn.request)
        or (e.http and type(e.http.request) == "function" and e.http.request)
end

local requestFn = getRequestFunction()

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end

    if requestFn then
        local ok2, res = pcall(function()
            return requestFn({Url = url, Method = "GET"})
        end)
        if ok2 and res then
            local b = res.Body or res.body
            if type(b) == "string" and #b > 0 then
                return b
            end
        end
    end

    return nil
end

local function jsonGet(url)
    local body = httpGet(url)
    if not body then return nil end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    return ok and decoded or nil
end

local function safeSetClipboard(text)
    local f = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
    if f then
        pcall(f, tostring(text))
        return true
    end
    return false
end

--// Persistent local data (optional)
local DATA_FILE = "HXAvatarChange_" .. tostring(LocalPlayer.UserId) .. ".json"
local SavedData = {
    language = "ES",
    presets = {},
    favorites = {},
    recentIds = {},
    rememberWindow = true,
}

local function loadSavedData()
    if not (type(readfile) == "function" and type(isfile) == "function") then return end
    local ok, decoded = pcall(function()
        if not isfile(DATA_FILE) then return nil end
        return HttpService:JSONDecode(readfile(DATA_FILE))
    end)
    if ok and type(decoded) == "table" then
        for k, v in pairs(decoded) do
            SavedData[k] = v
        end
    end
    if type(SavedData.presets) ~= "table" then SavedData.presets = {} end
    if type(SavedData.favorites) ~= "table" then SavedData.favorites = {} end
    if type(SavedData.recentIds) ~= "table" then SavedData.recentIds = {} end
end

local saveQueued = false
local function saveSavedData()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.2, function()
        saveQueued = false
        if type(writefile) ~= "function" then return end
        pcall(function()
            writefile(DATA_FILE, HttpService:JSONEncode(SavedData))
        end)
    end)
end

loadSavedData()

--// Localization
local LANG = SavedData.language == "EN" and "EN" or "ES"
local T = {
    ES = {
        catalog = "CATÁLOGO",
        avatar = "MI AVATAR",
        players = "JUGADORES",
        presets = "PRESETS",
        search = "Buscar ropa, pelo, accesorios, UGC...",
        all = "TODO",
        hair = "PELO",
        face = "CARA",
        hats = "SOMBREROS",
        clothes = "ROPA",
        back = "ESPALDA",
        body = "CUERPO",
        more = "MÁS",
        equip = "PROBAR",
        remove = "QUITAR",
        buy = "COMPRAR",
        copyId = "COPIAR ID",
        saveRoblox = "GUARDAR ROBLOX",
        saveOutfit = "CREAR OUTFIT",
        restore = "RESTAURAR",
        clearAccessories = "QUITAR ACCESORIOS",
        directId = "PROBAR POR ID",
        idPlaceholder = "Asset ID...",
        apply = "APLICAR",
        current = "Avatar de trabajo",
        serverPlayers = "Copiar avatar de un jugador",
        copyAvatar = "COPIAR AVATAR",
        savePreset = "GUARDAR PRESET",
        presetName = "Nombre del preset...",
        load = "CARGAR",
        delete = "ELIMINAR",
        empty = "Sin resultados",
        loading = "Cargando...",
        noPresets = "No tienes presets guardados.",
        itemAdded = "Artículo aplicado",
        itemRemoved = "Artículo eliminado",
        failed = "No se pudo completar la acción.",
        saved = "Solicitud enviada a Roblox.",
        localOnly = "Vista previa aplicada. La visibilidad para otros depende del servidor.",
        ownedNotice = "Roblox solo guardará en tu avatar artículos que poseas.",
        page = "Página",
        selected = "SELECCIONADO",
        favorite = "FAVORITO",
        recent = "RECIENTES",
        noHumanoid = "No se encontró Humanoid.",
        copied = "ID copiado",
        resetSearch = "LIMPIAR",
        random = "RANDOM",
        preview = "PREVISUALIZAR",
        minimized = "HX AVATAR",
    },
    EN = {
        catalog = "CATALOG",
        avatar = "MY AVATAR",
        players = "PLAYERS",
        presets = "PRESETS",
        search = "Search clothes, hair, accessories, UGC...",
        all = "ALL",
        hair = "HAIR",
        face = "FACE",
        hats = "HATS",
        clothes = "CLOTHING",
        back = "BACK",
        body = "BODY",
        more = "MORE",
        equip = "TRY ON",
        remove = "REMOVE",
        buy = "BUY",
        copyId = "COPY ID",
        saveRoblox = "SAVE ROBLOX",
        saveOutfit = "CREATE OUTFIT",
        restore = "RESTORE",
        clearAccessories = "REMOVE ACCESSORIES",
        directId = "TRY BY ID",
        idPlaceholder = "Asset ID...",
        apply = "APPLY",
        current = "Working avatar",
        serverPlayers = "Copy a player's avatar",
        copyAvatar = "COPY AVATAR",
        savePreset = "SAVE PRESET",
        presetName = "Preset name...",
        load = "LOAD",
        delete = "DELETE",
        empty = "No results",
        loading = "Loading...",
        noPresets = "You have no saved presets.",
        itemAdded = "Item applied",
        itemRemoved = "Item removed",
        failed = "The action could not be completed.",
        saved = "Request sent to Roblox.",
        localOnly = "Preview applied. Visibility to others depends on the server.",
        ownedNotice = "Roblox will only save items you own to your avatar.",
        page = "Page",
        selected = "SELECTED",
        favorite = "FAVORITE",
        recent = "RECENT",
        noHumanoid = "Humanoid not found.",
        copied = "ID copied",
        resetSearch = "CLEAR",
        random = "RANDOM",
        preview = "PREVIEW",
        minimized = "HX AVATAR",
    }
}

local function L(key)
    return (T[LANG] and T[LANG][key]) or T.ES[key] or key
end

--// Theme
local COLORS = {
    bg = Color3.fromRGB(3,3,4),
    panel = Color3.fromRGB(8,8,10),
    panel2 = Color3.fromRGB(12,12,15),
    panel3 = Color3.fromRGB(17,17,20),
    text = Color3.fromRGB(245,245,248),
    dim = Color3.fromRGB(145,145,155),
    dim2 = Color3.fromRGB(90,90,98),
    edge = Color3.fromRGB(166,166,176),
    edgeSoft = Color3.fromRGB(96,96,106),
    edgeBright = Color3.fromRGB(240,240,246),
    selected = Color3.fromRGB(255,255,255),
    danger = Color3.fromRGB(210,210,215),
}

local isMobile = UserInputService.TouchEnabled

--// GUI helpers
local connections = {}
local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(connections, c)
    return c
end

local function new(className, props, parent)
    local obj = Instance.new(className)
    for k,v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    obj.Parent = parent
    return obj
end

local function addCorner(obj, radius)
    local c = new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
    return c
end

local function addStroke(obj, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or COLORS.edgeSoft,
        Thickness = thickness or 1,
        Transparency = transparency == nil and 0.45 or transparency,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

-- Visual clipped-corner border. It never intercepts input.
local function addChamferBorder(obj, opts)
    opts = opts or {}
    local name = opts.name or "HXChamfer"
    local existing = obj:FindFirstChild(name)
    if existing then existing:Destroy() end

    local holder = new("Frame", {
        Name = name,
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        Selectable = false,
        ZIndex = (obj.ZIndex or 1) + (opts.zOffset or 3),
    }, obj)

    local thickness = opts.thickness or 1
    local cut = opts.cut or 7
    local color = opts.color or COLORS.edgeSoft
    local transparency = opts.transparency == nil and 0.4 or opts.transparency

    local segments = {}
    local function seg(name2, size, pos, rotation)
        local f = new("Frame", {
            Name = name2,
            Size = size,
            Position = pos,
            AnchorPoint = Vector2.new(0.5,0.5),
            Rotation = rotation or 0,
            BackgroundColor3 = color,
            BackgroundTransparency = transparency,
            BorderSizePixel = 0,
            Active = false,
            Selectable = false,
            ZIndex = holder.ZIndex,
        }, holder)
        segments[#segments+1] = f
        return f
    end

    seg("Top", UDim2.new(1,-cut*2,0,thickness), UDim2.new(0.5,0,0,thickness/2), 0)
    seg("Bottom", UDim2.new(1,-cut*2,0,thickness), UDim2.new(0.5,0,1,-thickness/2), 0)
    seg("Left", UDim2.new(0,thickness,1,-cut*2), UDim2.new(0,thickness/2,0.5,0), 0)
    seg("Right", UDim2.new(0,thickness,1,-cut*2), UDim2.new(1,-thickness/2,0.5,0), 0)

    local diagLen = math.max(4, math.floor(cut * 1.42))
    local half = cut/2
    seg("TL", UDim2.new(0,diagLen,0,thickness), UDim2.new(0,half,0,half), -45)
    seg("TR", UDim2.new(0,diagLen,0,thickness), UDim2.new(1,-half,0,half), 45)
    seg("BL", UDim2.new(0,diagLen,0,thickness), UDim2.new(0,half,1,-half), 45)
    seg("BR", UDim2.new(0,diagLen,0,thickness), UDim2.new(1,-half,1,-half), -45)

    local api = {}
    function api:SetStyle(newColor, newTransparency, cornerBoost)
        for _, s in ipairs(segments) do
            s.BackgroundColor3 = newColor or color
            local isCorner = s.Name == "TL" or s.Name == "TR" or s.Name == "BL" or s.Name == "BR"
            local t = newTransparency == nil and transparency or newTransparency
            if isCorner and cornerBoost then
                t = math.max(0, t - cornerBoost)
            end
            s.BackgroundTransparency = t
        end
    end
    function api:SetVisible(v)
        holder.Visible = v
    end
    function api:Destroy()
        if holder then holder:Destroy() end
    end
    api.Holder = holder
    api.Segments = segments
    return api
end

local function makeButton(parent, text, size, pos, opts)
    opts = opts or {}
    local b = new("TextButton", {
        Size = size,
        Position = pos or UDim2.new(),
        BackgroundColor3 = opts.bg or COLORS.panel2,
        BackgroundTransparency = opts.bgT == nil and 0.55 or opts.bgT,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = text or "",
        Font = opts.bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = opts.textSize or (isMobile and 10 or 12),
        TextColor3 = opts.textColor or COLORS.text,
        TextStrokeTransparency = 1,
        ZIndex = opts.z or 10,
    }, parent)
    if opts.rounded then addCorner(b, opts.radius or 8) end
    local border = addChamferBorder(b, {
        cut = opts.cut or 6,
        thickness = opts.thickness or 1,
        color = opts.borderColor or COLORS.edgeSoft,
        transparency = opts.borderT == nil and 0.42 or opts.borderT,
    })

    connect(b.MouseEnter, function()
        if b:GetAttribute("HXSelected") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = math.max(0.35, (opts.bgT or 0.55)-0.08)}):Play()
        border:SetStyle(COLORS.edge, 0.25)
    end)
    connect(b.MouseLeave, function()
        if b:GetAttribute("HXSelected") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = opts.bgT == nil and 0.55 or opts.bgT}):Play()
        border:SetStyle(opts.borderColor or COLORS.edgeSoft, opts.borderT == nil and 0.42 or opts.borderT)
    end)

    b:SetAttribute("HXSetSelected", true)
    local function setSelected(selected)
        b:SetAttribute("HXSelected", selected == true)
        if selected then
            TweenService:Create(b, TweenInfo.new(0.14), {BackgroundTransparency = opts.selectedBgT or 0.32}):Play()
            border:SetStyle(COLORS.edgeBright, opts.selectedBorderT or 0.05, 0.04)
        else
            TweenService:Create(b, TweenInfo.new(0.14), {BackgroundTransparency = opts.bgT == nil and 0.55 or opts.bgT}):Play()
            border:SetStyle(opts.borderColor or COLORS.edgeSoft, opts.borderT == nil and 0.42 or opts.borderT)
        end
    end
    return b, border, setSelected
end

local function makeLabel(parent, text, size, pos, opts)
    opts = opts or {}
    return new("TextLabel", {
        Size = size,
        Position = pos or UDim2.new(),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text or "",
        Font = opts.bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = opts.textSize or (isMobile and 10 or 12),
        TextColor3 = opts.color or COLORS.text,
        TextTransparency = opts.textT or 0,
        TextXAlignment = opts.align or Enum.TextXAlignment.Left,
        TextYAlignment = opts.yalign or Enum.TextYAlignment.Center,
        TextWrapped = opts.wrapped == true,
        TextTruncate = opts.truncate or Enum.TextTruncate.AtEnd,
        ZIndex = opts.z or 10,
    }, parent)
end

local function makeTextbox(parent, placeholder, size, pos, opts)
    opts = opts or {}
    local box = new("TextBox", {
        Size = size,
        Position = pos or UDim2.new(),
        BackgroundColor3 = COLORS.panel2,
        BackgroundTransparency = opts.bgT == nil and 0.55 or opts.bgT,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = COLORS.dim,
        TextColor3 = COLORS.text,
        Font = Enum.Font.Gotham,
        TextSize = opts.textSize or (isMobile and 10 or 12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextStrokeTransparency = 1,
        ZIndex = opts.z or 10,
    }, parent)
    new("UIPadding", {PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,8)}, box)
    local border = addChamferBorder(box, {cut=6, thickness=1, color=COLORS.edgeSoft, transparency=0.38})
    connect(box.Focused, function() border:SetStyle(COLORS.edgeBright, 0.08) end)
    connect(box.FocusLost, function() border:SetStyle(COLORS.edgeSoft, 0.38) end)
    return box, border
end

--// Root GUI
local Gui = new("ScreenGui", {
    Name = "HXAvatarChange",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 998,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local screenShade = new("Frame", {
    Size = UDim2.fromScale(1,1),
    BackgroundColor3 = Color3.fromRGB(0,0,0),
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    ZIndex = 1,
}, Gui)

-- subtle stars, deliberately different density from HX Emotes
local starFolder = new("Folder", {Name="AmbientDots"}, Gui)
local rng = Random.new()
for i=1,(isMobile and 44 or 80) do
    local s = rng:NextInteger(1,2)
    local dot = new("Frame", {
        Size = UDim2.fromOffset(s,s),
        Position = UDim2.fromScale(rng:NextNumber(0.02,0.98), rng:NextNumber(0.03,0.97)),
        BackgroundColor3 = Color3.fromRGB(220,220,225),
        BackgroundTransparency = rng:NextNumber(0.55,0.86),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, Gui)
    addCorner(dot, 8)
    task.spawn(function()
        while dot.Parent do
            local t = rng:NextNumber(2.8,5.5)
            local target = rng:NextNumber(0.55,0.9)
            local tw = TweenService:Create(dot, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency=target})
            tw:Play(); tw.Completed:Wait()
        end
    end)
end

local defaultW = isMobile and 610 or 900
local defaultH = isMobile and 360 or 560
local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(defaultW, defaultH),
    Position = UDim2.fromScale(0.5,0.5),
    AnchorPoint = Vector2.new(0.5,0.5),
    BackgroundColor3 = COLORS.panel,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    ZIndex = 5,
}, Gui)
addChamferBorder(Main, {cut=13, thickness=1.2, color=COLORS.edge, transparency=0.18, zOffset=5})

local MainScale = new("UIScale", {Scale = isMobile and 0.9 or 1}, Main)

--// Responsive clamp
local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local sx = (vp.X - 20) / defaultW
    local sy = (vp.Y - 20) / defaultH
    local fit = math.min(1, sx, sy)
    if isMobile then fit = math.min(0.95, fit) end
    MainScale.Scale = math.max(0.56, fit)
end
updateScale()
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), updateScale)
if workspace.CurrentCamera then connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale) end

--// Dragging
local dragging = false
local dragStart, startPos
local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = Main.Position
end
local HeaderHit = new("TextButton", {
    Size = UDim2.new(1,-160,0,58),
    Position = UDim2.fromOffset(0,0),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 7,
}, Main)
connect(HeaderHit.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)
connect(UserInputService.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--// Header
local Logo = new("ImageLabel", {
    Size = UDim2.fromOffset(isMobile and 34 or 42, isMobile and 34 or 42),
    Position = UDim2.fromOffset(16, isMobile and 9 or 8),
    BackgroundTransparency = 1,
    Image = "rbxassetid://80552458381492",
    ScaleType = Enum.ScaleType.Fit,
    ImageColor3 = Color3.fromRGB(255,255,255),
    ZIndex = 12,
}, Main)

makeLabel(Main, "HX AVATAR", UDim2.fromOffset(170,22), UDim2.fromOffset(isMobile and 56 or 68, 10), {bold=true, textSize=isMobile and 15 or 18, z=12})
makeLabel(Main, "UNIVERSAL AVATAR EDITOR", UDim2.fromOffset(220,18), UDim2.fromOffset(isMobile and 56 or 68, 30), {textSize=isMobile and 8 or 9, color=COLORS.dim, z=12})

local topBtnSize = isMobile and 28 or 32
local closeBtn, _, _ = makeButton(Main, "×", UDim2.fromOffset(topBtnSize,topBtnSize), UDim2.new(1,-(topBtnSize+12),0,12), {bgT=1,borderT=0.34,textSize=isMobile and 16 or 19,bold=true,cut=5})
local maxBtn, _, _ = makeButton(Main, "□", UDim2.fromOffset(topBtnSize,topBtnSize), UDim2.new(1,-(topBtnSize*2+18),0,12), {bgT=1,borderT=0.34,textSize=isMobile and 12 or 14,bold=true,cut=5})
local minBtn, _, _ = makeButton(Main, "—", UDim2.fromOffset(topBtnSize,topBtnSize), UDim2.new(1,-(topBtnSize*3+24),0,12), {bgT=1,borderT=0.34,textSize=isMobile and 13 or 15,bold=true,cut=5})

local langBtn, _, _ = makeButton(Main, LANG, UDim2.fromOffset(isMobile and 34 or 40,topBtnSize), UDim2.new(1,-(topBtnSize*3+70),0,12), {bgT=0.78,borderT=0.48,textSize=isMobile and 9 or 10,bold=true,cut=5})

--// Minimized bubble
local Mini = new("TextButton", {
    Size = UDim2.fromOffset(isMobile and 52 or 60,isMobile and 52 or 60),
    Position = UDim2.new(0,18,0.5,-30),
    BackgroundColor3 = COLORS.panel,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Text = "",
    Visible = false,
    AutoButtonColor = false,
    ZIndex = 200,
}, Gui)
addChamferBorder(Mini,{cut=8,thickness=1.2,color=COLORS.edgeBright,transparency=0.15,zOffset=3})
new("ImageLabel", {
    Size = UDim2.new(1,-14,1,-14), Position=UDim2.fromOffset(7,7), BackgroundTransparency=1,
    Image="rbxassetid://80552458381492", ScaleType=Enum.ScaleType.Fit, ImageColor3=Color3.new(1,1,1), ZIndex=204
}, Mini)

local maximized = false
local savedSize, savedPos
connect(maxBtn.MouseButton1Click, function()
    maximized = not maximized
    if maximized then
        savedSize, savedPos = Main.Size, Main.Position
        MainScale.Scale = 1
        Main.Size = UDim2.fromScale(0.9,0.9)
        Main.Position = UDim2.fromScale(0.5,0.5)
        maxBtn.Text = "▣"
    else
        Main.Size = savedSize or UDim2.fromOffset(defaultW,defaultH)
        Main.Position = savedPos or UDim2.fromScale(0.5,0.5)
        maxBtn.Text = "□"
        updateScale()
    end
end)
connect(minBtn.MouseButton1Click, function()
    Main.Visible = false
    screenShade.Visible = false
    Mini.Visible = true
end)
connect(Mini.MouseButton1Click, function()
    Mini.Visible = false
    Main.Visible = true
    screenShade.Visible = true
end)
connect(closeBtn.MouseButton1Click, function()
    Gui:Destroy()
end)
connect(langBtn.MouseButton1Click, function()
    LANG = (LANG == "ES") and "EN" or "ES"
    SavedData.language = LANG
    saveSavedData()
    langBtn.Text = LANG
    -- texts are rebuilt through refresh hooks below
    if ENV.HXAvatarRefreshLanguage then pcall(ENV.HXAvatarRefreshLanguage) end
end)

--// Left navigation and content shell
local Nav = new("Frame", {
    Size = UDim2.new(0,isMobile and 105 or 132,1,-68),
    Position = UDim2.fromOffset(12,58),
    BackgroundColor3 = COLORS.panel2,
    BackgroundTransparency = 0.56,
    BorderSizePixel = 0,
    ZIndex = 8,
}, Main)
addChamferBorder(Nav,{cut=9,thickness=1,color=COLORS.edgeSoft,transparency=0.5})

local Content = new("Frame", {
    Size = UDim2.new(1,-(isMobile and 129 or 158),1,-68),
    Position = UDim2.fromOffset(isMobile and 117 or 146,58),
    BackgroundColor3 = COLORS.panel2,
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    ZIndex = 8,
}, Main)
addChamferBorder(Content,{cut=9,thickness=1,color=COLORS.edgeSoft,transparency=0.55})

local tabs = {"catalog","avatar","players","presets"}
local tabButtons = {}
local tabSetters = {}
local currentTab = "catalog"
local contentPanels = {}

for i, key in ipairs(tabs) do
    local b, _, setSel = makeButton(Nav, L(key), UDim2.new(1,-14,0,isMobile and 34 or 40), UDim2.fromOffset(7, 10+(i-1)*(isMobile and 40 or 47)), {
        bgT=0.88, borderT=0.58, selectedBgT=0.46, selectedBorderT=0.08, textSize=isMobile and 9 or 10, bold=true, cut=6
    })
    tabButtons[key] = b
    tabSetters[key] = setSel
end

local navInfo = makeLabel(Nav, "TRY-ON + ROBLOX SAVE", UDim2.new(1,-14,0,42), UDim2.new(0,7,1,-50), {textSize=isMobile and 7 or 8,color=COLORS.dim,wrapped=true,z=10})

--// Notification system
local Notifs = new("Frame", {
    Size=UDim2.fromOffset(isMobile and 250 or 310, 260),
    Position=UDim2.new(1,-12,0,12), AnchorPoint=Vector2.new(1,0),
    BackgroundTransparency=1, ZIndex=500
}, Gui)
local notifList = new("UIListLayout", {Padding=UDim.new(0,6),HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Top}, Notifs)

local function notify(title, body)
    local wrap = new("Frame", {Size=UDim2.fromOffset(isMobile and 220 or 280,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=COLORS.panel,BackgroundTransparency=0.08,BorderSizePixel=0,ZIndex=501}, Notifs)
    addChamferBorder(wrap,{cut=7,thickness=1,color=COLORS.edge,transparency=0.22,zOffset=3})
    local pad = new("UIPadding", {PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)}, wrap)
    local layout = new("UIListLayout", {Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder}, wrap)
    makeLabel(wrap,title,UDim2.new(1,0,0,16),nil,{bold=true,textSize=isMobile and 10 or 11,z=503})
    local bodyLbl = makeLabel(wrap,body,UDim2.new(1,0,0,0),nil,{textSize=isMobile and 8 or 9,color=COLORS.dim,wrapped=true,z=503})
    bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
    wrap.BackgroundTransparency = 1
    TweenService:Create(wrap,TweenInfo.new(0.18),{BackgroundTransparency=0.08}):Play()
    task.delay(3.3,function()
        if not wrap.Parent then return end
        local tw=TweenService:Create(wrap,TweenInfo.new(0.18),{BackgroundTransparency=1})
        tw:Play(); tw.Completed:Wait(); if wrap.Parent then wrap:Destroy() end
    end)
end

--// Avatar state
local OriginalDescription = nil
local WorkingDescription = nil
local WorkingRigType = Enum.HumanoidRigType.R15
local selectedAssetId = nil
local selectedItem = nil
local previewLock = false

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function cloneDescription(desc)
    if not desc then return nil end
    local ok, c = pcall(function() return desc:Clone() end)
    return ok and c or nil
end

local function captureCurrentDescription()
    local hum = getHumanoid()
    if not hum then return false end
    WorkingRigType = hum.RigType
    local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
    if not ok or not desc then
        local ok2, d2 = pcall(function()
            return Players:GetHumanoidDescriptionFromUserIdAsync(LocalPlayer.UserId)
        end)
        if ok2 then desc = d2 end
    end
    if not desc then return false end
    OriginalDescription = cloneDescription(desc)
    WorkingDescription = cloneDescription(desc)
    return WorkingDescription ~= nil
end

captureCurrentDescription()

local function applyWorkingDescription(showNotice)
    if previewLock then return false end
    local hum = getHumanoid()
    if not hum or not WorkingDescription then
        notify("HX AVATAR", L("noHumanoid"))
        return false
    end
    previewLock = true
    local ok, err = pcall(function()
        if hum.ApplyDescriptionAsync then
            hum:ApplyDescriptionAsync(WorkingDescription)
        else
            hum:ApplyDescription(WorkingDescription)
        end
    end)
    previewLock = false
    if not ok then
        warn("[HX Avatar] ApplyDescription failed:", err)
        notify("HX AVATAR", L("failed"))
        return false
    end
    if showNotice ~= false then notify("HX AVATAR", L("localOnly")) end
    return true
end

local function restoreOriginal()
    if not OriginalDescription then return end
    WorkingDescription = cloneDescription(OriginalDescription)
    applyWorkingDescription(false)
    notify("HX AVATAR", L("restore"))
end

-- Reapply working appearance after respawn so try-on remains while script is open.
connect(LocalPlayer.CharacterAdded, function(char)
    task.wait(1)
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
    if hum and WorkingDescription then
        WorkingRigType = hum.RigType
        pcall(function()
            if hum.ApplyDescriptionAsync then hum:ApplyDescriptionAsync(WorkingDescription) else hum:ApplyDescription(WorkingDescription) end
        end)
    end
end)

--// HumanoidDescription serialization for presets
local scalarProps = {
    "Shirt","Pants","GraphicTShirt","Face","Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg",
    "HeightScale","WidthScale","DepthScale","HeadScale","BodyTypeScale","ProportionScale",
    "IdleAnimation","WalkAnimation","RunAnimation","JumpAnimation","FallAnimation","ClimbAnimation","SwimAnimation","MoodAnimation",
}
local colorProps = {"HeadColor","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor"}
local stringAccessoryProps = {"HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory"}
local ACCESSORY_TYPE_ENUM = {}
for _, enumItem in ipairs(Enum.AccessoryType:GetEnumItems()) do
    ACCESSORY_TYPE_ENUM[enumItem.Name] = enumItem
end

local function serializeDescription(desc)
    local out = {props={}, colors={}, accessories={}}
    for _,p in ipairs(scalarProps) do
        pcall(function() out.props[p] = desc[p] end)
    end
    for _,p in ipairs(stringAccessoryProps) do
        pcall(function() out.props[p] = desc[p] end)
    end
    for _,p in ipairs(colorProps) do
        pcall(function()
            local c = desc[p]
            out.colors[p] = {c.R,c.G,c.B}
        end)
    end
    pcall(function()
        for _,a in ipairs(desc:GetAccessories(true)) do
            out.accessories[#out.accessories+1] = {
                AssetId = a.AssetId,
                AccessoryType = tostring(a.AccessoryType):gsub("Enum.AccessoryType%.",""),
                Order = a.Order,
                Puffiness = a.Puffiness,
            }
        end
    end)
    return out
end

local function deserializeDescription(data)
    local d = Instance.new("HumanoidDescription")
    if type(data) ~= "table" then return d end
    local hasAccessoryList = type(data.accessories)=="table" and #data.accessories>0
    local accessoryPropSet = {}
    for _,name in ipairs(stringAccessoryProps) do accessoryPropSet[name]=true end
    for p,v in pairs(data.props or {}) do
        if not (hasAccessoryList and accessoryPropSet[p]) then
            pcall(function() d[p]=v end)
        end
    end
    for p,c in pairs(data.colors or {}) do
        pcall(function() d[p]=Color3.new(c[1] or 0,c[2] or 0,c[3] or 0) end)
    end
    if type(data.accessories)=="table" and #data.accessories>0 then
        local list={}
        for _,a in ipairs(data.accessories) do
            local accType = ACCESSORY_TYPE_ENUM[tostring(a.AccessoryType or "Unknown")]
            if accType then
                list[#list+1]={AssetId=tonumber(a.AssetId),AccessoryType=accType,Order=tonumber(a.Order) or 1,Puffiness=tonumber(a.Puffiness) or 0}
            end
        end
        if #list>0 then pcall(function() d:SetAccessories(list,true) end) end
    end
    return d
end

--// Asset type mapping
local ASSET_TYPE_BY_ID = {
    [2]="TShirt",[8]="Hat",[11]="Shirt",[12]="Pants",[17]="Head",[18]="Face",[27]="Torso",
    [28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[41]="HairAccessory",[42]="FaceAccessory",
    [43]="NeckAccessory",[44]="ShoulderAccessory",[45]="FrontAccessory",[46]="BackAccessory",[47]="WaistAccessory",
    [64]="TShirtAccessory",[65]="ShirtAccessory",[66]="PantsAccessory",[67]="JacketAccessory",[68]="SweaterAccessory",
    [69]="ShortsAccessory",[70]="LeftShoeAccessory",[71]="RightShoeAccessory",[72]="DressSkirtAccessory",
    [76]="EyebrowAccessory",[77]="EyelashAccessory",[79]="DynamicHead",
}
local RIGID_PROP = {
    Hat="HatAccessory", HairAccessory="HairAccessory", FaceAccessory="FaceAccessory", NeckAccessory="NeckAccessory",
    ShoulderAccessory="ShouldersAccessory", ShouldersAccessory="ShouldersAccessory", FrontAccessory="FrontAccessory",
    BackAccessory="BackAccessory", WaistAccessory="WaistAccessory",
}
local DIRECT_PROP = {
    TShirt="GraphicTShirt", Shirt="Shirt", Pants="Pants", Head="Head", DynamicHead="Head", Face="Face", Torso="Torso",
    RightArm="RightArm",LeftArm="LeftArm",RightLeg="RightLeg",LeftLeg="LeftLeg",
}

local AVATAR_ASSET_ENUM = {}
for _, enumItem in ipairs(Enum.AvatarAssetType:GetEnumItems()) do
    AVATAR_ASSET_ENUM[enumItem.Name] = enumItem
    AVATAR_ASSET_ENUM[enumItem.Value] = enumItem
end
local function normalizeAssetType(item)
    if not item then return nil end
    local at = item.AssetType or item.assetType or item.assetTypeId
    if typeof(at) == "EnumItem" then return at.Name end
    if type(at) == "number" then return ASSET_TYPE_BY_ID[at] or (AVATAR_ASSET_ENUM[at] and AVATAR_ASSET_ENUM[at].Name) end
    local s = tostring(at or "")
    s = s:gsub("Enum.AvatarAssetType%.","")
    if tonumber(s) then return ASSET_TYPE_BY_ID[tonumber(s)] or (AVATAR_ASSET_ENUM[tonumber(s)] and AVATAR_ASSET_ENUM[tonumber(s)].Name) end
    return s ~= "" and s or nil
end

local function appendCsv(existing, id)
    local list, seen = {}, {}
    for num in tostring(existing or ""):gmatch("%d+") do
        if not seen[num] then list[#list+1]=num; seen[num]=true end
    end
    local sid=tostring(id)
    if not seen[sid] then list[#list+1]=sid end
    return table.concat(list,",")
end

local function removeCsv(existing, id)
    local out={}
    local sid=tostring(id)
    for num in tostring(existing or ""):gmatch("%d+") do
        if num~=sid then out[#out+1]=num end
    end
    return table.concat(out,",")
end

local function removeAssetFromWorking(id)
    if not WorkingDescription then return false end
    id=tonumber(id); if not id then return false end
    local sid=tostring(id)
    local changed=false
    for _,p in ipairs(stringAccessoryProps) do
        local before=WorkingDescription[p]
        local after=removeCsv(before,id)
        if after~=before then WorkingDescription[p]=after; changed=true end
    end
    for _,p in ipairs({"Shirt","Pants","GraphicTShirt","Face","Head","Torso","RightArm","LeftArm","RightLeg","LeftLeg"}) do
        pcall(function()
            if tonumber(WorkingDescription[p])==id then WorkingDescription[p]=0; changed=true end
        end)
    end
    pcall(function()
        local accs=WorkingDescription:GetAccessories(true)
        local out={}
        for _,a in ipairs(accs) do
            if tonumber(a.AssetId)~=id then out[#out+1]=a else changed=true end
        end
        WorkingDescription:SetAccessories(out,true)
    end)
    if changed then applyWorkingDescription(false); notify("HX AVATAR",L("itemRemoved")) end
    return changed
end

local function getItemDetails(id)
    id=tonumber(id); if not id then return nil end
    local ok, details = pcall(function()
        return AvatarEditorService:GetItemDetailsAsync(id, Enum.AvatarItemType.Asset)
    end)
    if ok and type(details)=="table" then
        details.Id = details.Id or id
        return details
    end
    local data=jsonGet("https://catalog.roblox.com/v1/catalog/items/"..id.."/details?itemType=Asset")
    if type(data)=="table" then data.Id=data.Id or id; return data end
    return {Id=id,Name="Asset "..id}
end

local function addLayeredAccessory(desc, id, assetTypeName)
    local enumAsset=AVATAR_ASSET_ENUM[assetTypeName]
    if not enumAsset then return false end
    local okType, accessoryType=pcall(function() return AvatarEditorService:GetAccessoryType(enumAsset) end)
    if not okType or not accessoryType or accessoryType==Enum.AccessoryType.Unknown then return false end
    local ok,list=pcall(function() return desc:GetAccessories(true) end)
    list=(ok and type(list)=="table") and list or {}
    for _,a in ipairs(list) do if tonumber(a.AssetId)==tonumber(id) then return true end end
    list[#list+1]={AssetId=tonumber(id),AccessoryType=accessoryType,Order=#list+1,Puffiness=0}
    local okSet=pcall(function() desc:SetAccessories(list,true) end)
    return okSet
end

local function applyAsset(item)
    if not WorkingDescription or not item then return false end
    local id=tonumber(item.Id or item.id or item.AssetId or item.assetId)
    if not id then return false end
    local assetType=normalizeAssetType(item)
    if not assetType or assetType=="nil" then
        local details=getItemDetails(id)
        assetType=normalizeAssetType(details)
        item=details or item
    end

    local changed=false
    if DIRECT_PROP[assetType] then
        local prop=DIRECT_PROP[assetType]
        local ok=pcall(function() WorkingDescription[prop]=id end)
        changed=ok
    elseif RIGID_PROP[assetType] then
        local prop=RIGID_PROP[assetType]
        local ok=pcall(function() WorkingDescription[prop]=appendCsv(WorkingDescription[prop],id) end)
        changed=ok
    else
        changed=addLayeredAccessory(WorkingDescription,id,assetType)
    end

    -- Generic fallback: if Roblox reports accessory type differently, SetAccessories may still work.
    if not changed and assetType then
        changed=addLayeredAccessory(WorkingDescription,id,assetType)
    end

    if not changed then
        notify("HX AVATAR",L("failed").." ["..tostring(assetType or "?").."]")
        return false
    end

    selectedAssetId=id
    selectedItem=item
    applyWorkingDescription(false)

    table.insert(SavedData.recentIds,1,id)
    local clean,seen={},{}
    for _,v in ipairs(SavedData.recentIds) do
        v=tonumber(v)
        if v and not seen[v] then clean[#clean+1]=v; seen[v]=true end
        if #clean>=20 then break end
    end
    SavedData.recentIds=clean
    saveSavedData()
    notify("HX AVATAR",L("itemAdded"))
    return true
end

local function clearAccessories()
    if not WorkingDescription then return end
    for _,p in ipairs(stringAccessoryProps) do pcall(function() WorkingDescription[p]="" end) end
    pcall(function() WorkingDescription:SetAccessories({},true) end)
    applyWorkingDescription(false)
    notify("HX AVATAR",L("clearAccessories"))
end

--// Catalog categories
local CATEGORY_FILTERS = {
    all = {
        "TShirt","Shirt","Pants","Hat","Head","Face","Torso","RightArm","LeftArm","RightLeg","LeftLeg",
        "HairAccessory","FaceAccessory","NeckAccessory","ShoulderAccessory","FrontAccessory","BackAccessory","WaistAccessory",
        "TShirtAccessory","ShirtAccessory","PantsAccessory","JacketAccessory","SweaterAccessory","ShortsAccessory",
        "LeftShoeAccessory","RightShoeAccessory","DressSkirtAccessory","EyebrowAccessory","EyelashAccessory","DynamicHead",
        "FaceMakeup","LipMakeup","EyeMakeup"
    },
    hair = {"HairAccessory"},
    face = {"FaceAccessory","EyebrowAccessory","EyelashAccessory","FaceMakeup","LipMakeup","EyeMakeup","Face","DynamicHead"},
    hats = {"Hat"},
    clothes = {"TShirt","Shirt","Pants","TShirtAccessory","ShirtAccessory","PantsAccessory","JacketAccessory","SweaterAccessory","ShortsAccessory","DressSkirtAccessory","LeftShoeAccessory","RightShoeAccessory"},
    back = {"BackAccessory","FrontAccessory","WaistAccessory","ShoulderAccessory","NeckAccessory"},
    body = {"Head","DynamicHead","Torso","RightArm","LeftArm","RightLeg","LeftLeg"},
    more = {"FrontAccessory","WaistAccessory","ShoulderAccessory","NeckAccessory"},
}

local function enumAssetList(names)
    if not names then return nil end
    local out={}
    for _,n in ipairs(names) do if AVATAR_ASSET_ENUM[n] then out[#out+1]=AVATAR_ASSET_ENUM[n] end end
    return out
end

local CatalogState={pages=nil,pageIndex=1,query="",category="all",loading=false,token=0,items={}}

local function fallbackCatalog(query, category)
    local url="https://catalog.roblox.com/v1/search/items/details?Category=1&SortType=Relevance&Limit=30"
    if query~="" then url=url.."&Keyword="..HttpService:UrlEncode(query) end
    local data=jsonGet(url)
    local list=(type(data)=="table" and data.data) or {}
    local allowed=CATEGORY_FILTERS[category]
    if allowed and #allowed>0 then
        local set={}
        for _,n in ipairs(allowed) do set[n]=true end
        local filtered={}
        for _,it in ipairs(list) do
            local typ=normalizeAssetType(it)
            if set[typ] then filtered[#filtered+1]=it end
        end
        list=filtered
    end
    return list
end

local function searchCatalog(query, category)
    CatalogState.token+=1
    local token=CatalogState.token
    CatalogState.loading=true
    CatalogState.query=query or ""
    CatalogState.category=category or "all"
    CatalogState.pageIndex=1
    CatalogState.pages=nil

    local params=CatalogSearchParams.new()
    params.SearchKeyword=CatalogState.query
    params.SortType=Enum.CatalogSortType.Relevance
    params.Limit=30
    local assets=enumAssetList(CATEGORY_FILTERS[CatalogState.category])
    if assets and #assets>0 then params.AssetTypes=assets end

    local ok,pages=pcall(function() return AvatarEditorService:SearchCatalogAsync(params) end)
    if token~=CatalogState.token then return nil end
    if ok and pages then
        CatalogState.pages=pages
        CatalogState.items=pages:GetCurrentPage() or {}
    else
        CatalogState.items=fallbackCatalog(CatalogState.query,CatalogState.category)
    end
    CatalogState.loading=false
    return CatalogState.items
end

local function nextCatalogPage()
    if CatalogState.loading then return end
    if CatalogState.pages then
        CatalogState.loading=true
        local ok=pcall(function()
            if not CatalogState.pages.IsFinished then
                CatalogState.pages:AdvanceToNextPageAsync()
                CatalogState.pageIndex+=1
                CatalogState.items=CatalogState.pages:GetCurrentPage() or {}
            end
        end)
        CatalogState.loading=false
        return ok
    end
end

--// Content Panels
for _,key in ipairs(tabs) do
    contentPanels[key]=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,ZIndex=9},Content)
end
contentPanels.catalog.Visible=true

local function switchTab(key)
    currentTab=key
    for _,k in ipairs(tabs) do
        contentPanels[k].Visible=(k==key)
        tabSetters[k](k==key)
    end
    if key=="avatar" and ENV.HXAvatarRefreshAvatar then ENV.HXAvatarRefreshAvatar() end
    if key=="players" and ENV.HXAvatarRefreshPlayers then ENV.HXAvatarRefreshPlayers() end
    if key=="presets" and ENV.HXAvatarRefreshPresets then ENV.HXAvatarRefreshPresets() end
end
for _,k in ipairs(tabs) do connect(tabButtons[k].MouseButton1Click,function() switchTab(k) end) end
switchTab("catalog")

--// Catalog UI
local CatalogPanel=contentPanels.catalog
local SearchBox=makeTextbox(CatalogPanel,L("search"),UDim2.new(1,-154,0,isMobile and 30 or 34),UDim2.fromOffset(10,10),{bgT=0.68})
local ClearSearch=makeButton(CatalogPanel,"×",UDim2.fromOffset(isMobile and 30 or 34,isMobile and 30 or 34),UDim2.new(1,-134,0,10),{bgT=0.78,borderT=0.52,textSize=14,bold=true,cut=5})
local RandomBtn=makeButton(CatalogPanel,"RND",UDim2.fromOffset(isMobile and 40 or 44,isMobile and 30 or 34),UDim2.new(1,-98,0,10),{bgT=0.76,borderT=0.5,textSize=isMobile and 7 or 8,bold=true,cut=5})
local IdToggle=makeButton(CatalogPanel,"+ ID",UDim2.fromOffset(isMobile and 42 or 48,isMobile and 30 or 34),UDim2.new(1,-50,0,10),{bgT=0.52,borderT=0.18,textSize=isMobile and 8 or 9,bold=true,cut=5})

local categoryBar=new("Frame",{Size=UDim2.new(1,-20,0,isMobile and 30 or 34),Position=UDim2.fromOffset(10,isMobile and 48 or 52),BackgroundTransparency=1,ZIndex=10},CatalogPanel)
local catOrder={"all","hair","face","hats","clothes","back","body","more"}
local catBtns,catSet={},{}
new("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder, VerticalAlignment=Enum.VerticalAlignment.Center}, categoryBar)
for i,k in ipairs(catOrder) do
    local w=isMobile and 50 or 66
    if k=="clothes" then w=isMobile and 54 or 70 end
    local b,_,ss=makeButton(categoryBar,L(k),UDim2.fromOffset(w,isMobile and 27 or 30),UDim2.fromOffset(0,0),{bgT=0.9,borderT=0.64,selectedBgT=0.46,selectedBorderT=0.06,textSize=isMobile and 7 or 8,bold=true,cut=5})
    b.LayoutOrder=i
    catBtns[k]=b; catSet[k]=ss
end

local idPanel=new("Frame",{Size=UDim2.new(1,-20,0,42),Position=UDim2.fromOffset(10,isMobile and 82 or 90),BackgroundColor3=COLORS.panel3,BackgroundTransparency=0.18,BorderSizePixel=0,Visible=false,ZIndex=20},CatalogPanel)
addChamferBorder(idPanel,{cut=7,thickness=1,color=COLORS.edge,transparency=0.25})
local IdBox=makeTextbox(idPanel,L("idPlaceholder"),UDim2.new(1,-92,0,28),UDim2.fromOffset(7,7),{bgT=0.65,z=22})
local IdApply=makeButton(idPanel,L("apply"),UDim2.fromOffset(72,28),UDim2.new(1,-79,0,7),{bgT=0.4,borderT=0.14,textSize=8,bold=true,cut=5,z=22})

local gridTop=isMobile and 86 or 94
local CatalogScroll=new("ScrollingFrame",{
    Size=UDim2.new(1,-20,1,-(gridTop+54)),Position=UDim2.fromOffset(10,gridTop),BackgroundTransparency=1,BorderSizePixel=0,
    CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=COLORS.edgeSoft,ZIndex=10
},CatalogPanel)
local grid=new("UIGridLayout",{
    CellSize=UDim2.fromOffset(isMobile and 106 or 154,isMobile and 135 or 188),
    CellPadding=UDim2.fromOffset(isMobile and 7 or 9,isMobile and 7 or 9),
    FillDirectionMaxCells=isMobile and 4 or 4,
    SortOrder=Enum.SortOrder.LayoutOrder,
},CatalogScroll)

local catalogFooter=new("Frame",{Size=UDim2.new(1,-20,0,38),Position=UDim2.new(0,10,1,-44),BackgroundTransparency=1,ZIndex=12},CatalogPanel)
local PrevBtn=makeButton(catalogFooter,"<",UDim2.fromOffset(36,30),UDim2.fromOffset(0,4),{bgT=0.72,borderT=0.36,textSize=14,bold=true,cut=5})
local PageLbl=makeLabel(catalogFooter,L("page").." 1",UDim2.fromOffset(90,30),UDim2.fromOffset(42,4),{align=Enum.TextXAlignment.Center,bold=true,textSize=9})
local NextBtn=makeButton(catalogFooter,">",UDim2.fromOffset(36,30),UDim2.fromOffset(136,4),{bgT=0.72,borderT=0.36,textSize=14,bold=true,cut=5})
local LoadingLbl=makeLabel(catalogFooter,"",UDim2.new(1,-180,0,30),UDim2.fromOffset(180,4),{align=Enum.TextXAlignment.Right,textSize=8,color=COLORS.dim})

local selectedCardBorder=nil
local itemCardButtons={}

local function clearChildrenExceptLayout(frame)
    for _,c in ipairs(frame:GetChildren()) do
        if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
end

local function itemName(it)
    return tostring(it.Name or it.name or ("Asset "..tostring(it.Id or it.id or "?")))
end
local function itemId(it)
    return tonumber(it.Id or it.id or it.AssetId or it.assetId)
end
local function itemCreator(it)
    return tostring(it.CreatorName or it.creatorName or (it.Creator and it.Creator.Name) or "")
end

local function createCatalogCard(it,index)
    local id=itemId(it); if not id then return end
    local card=new("Frame",{
        Name="Asset_"..id, BackgroundColor3=COLORS.panel3,BackgroundTransparency=0.66,BorderSizePixel=0,ZIndex=11,LayoutOrder=index
    },CatalogScroll)
    local cb=addChamferBorder(card,{cut=8,thickness=1,color=COLORS.edgeSoft,transparency=0.48,zOffset=3})
    local thumb=new("ImageLabel",{
        Size=UDim2.new(1,-10,0,isMobile and 72 or 106),Position=UDim2.fromOffset(5,5),BackgroundColor3=Color3.fromRGB(5,5,6),BackgroundTransparency=0.12,
        BorderSizePixel=0,Image="rbxthumb://type=Asset&id="..id.."&w=420&h=420",ScaleType=Enum.ScaleType.Fit,ZIndex=12
    },card)
    addChamferBorder(thumb,{cut=6,thickness=1,color=COLORS.edgeSoft,transparency=0.72,zOffset=2})
    makeLabel(card,itemName(it),UDim2.new(1,-10,0,isMobile and 25 or 34),UDim2.fromOffset(5,isMobile and 79 or 115),{bold=true,textSize=isMobile and 8 or 10,wrapped=true,z=13})
    local creator=itemCreator(it)
    if creator~="" then makeLabel(card,creator,UDim2.new(1,-10,0,14),UDim2.fromOffset(5,isMobile and 103 or 145),{textSize=isMobile and 6 or 7,color=COLORS.dim,z=13}) end
    local bottomH=isMobile and 22 or 26
    local tryBtn=makeButton(card,L("equip"),UDim2.new(0.62,-7,0,bottomH),UDim2.new(0,5,1,-(bottomH+5)),{bgT=0.7,borderT=0.45,textSize=isMobile and 7 or 8,bold=true,cut=5,z=14})
    local buyBtn=makeButton(card,L("buy"),UDim2.new(0.38,-5,0,bottomH),UDim2.new(0.62,2,1,-(bottomH+5)),{bgT=0.82,borderT=0.58,textSize=isMobile and 6 or 7,bold=true,cut=5,z=14})
    connect(tryBtn.MouseButton1Click,function()
        if selectedCardBorder and selectedCardBorder~=cb then selectedCardBorder:SetStyle(COLORS.edgeSoft,0.48) end
        selectedCardBorder=cb
        cb:SetStyle(COLORS.edgeBright,0.05,0.03)
        selectedAssetId=id; selectedItem=it
        applyAsset(it)
    end)
    connect(buyBtn.MouseButton1Click,function()
        task.spawn(function()
            local owned=false
            pcall(function() owned=MarketplaceService:PlayerOwnsAsset(LocalPlayer,id) end)
            if owned then
                notify("HX AVATAR", LANG=="ES" and "Ya posees este artículo." or "You already own this item.")
                return
            end
            local ok=pcall(function() MarketplaceService:PromptPurchase(LocalPlayer,id) end)
            if not ok then notify("HX AVATAR",L("failed")) end
        end)
    end)
    local click=new("TextButton",{Size=UDim2.new(1,0,1,-(isMobile and 30 or 34)),BackgroundTransparency=1,Text="",ZIndex=13,AutoButtonColor=false},card)
    connect(click.MouseButton1Click,function()
        if selectedCardBorder and selectedCardBorder~=cb then selectedCardBorder:SetStyle(COLORS.edgeSoft,0.48) end
        selectedCardBorder=cb; cb:SetStyle(COLORS.edgeBright,0.05,0.03)
        selectedAssetId=id; selectedItem=it
    end)
end

local function refreshCatalogGrid()
    clearChildrenExceptLayout(CatalogScroll)
    local items=CatalogState.items or {}
    for i,it in ipairs(items) do createCatalogCard(it,i) end
    PageLbl.Text=L("page").." "..tostring(CatalogState.pageIndex)
    LoadingLbl.Text=CatalogState.loading and L("loading") or (#items==0 and L("empty") or tostring(#items).." items")
end

local function runSearch()
    LoadingLbl.Text=L("loading")
    task.spawn(function()
        searchCatalog(SearchBox.Text,CatalogState.category)
        refreshCatalogGrid()
    end)
end

connect(SearchBox.FocusLost,function(enter) if enter or isMobile then runSearch() end end)
local searchDebounce=0
connect(SearchBox:GetPropertyChangedSignal("Text"),function()
    if isMobile then return end
    searchDebounce+=1; local t=searchDebounce
    task.delay(0.45,function() if t==searchDebounce then runSearch() end end)
end)
connect(ClearSearch.MouseButton1Click,function() SearchBox.Text=""; runSearch() end)
connect(RandomBtn.MouseButton1Click,function()
    local items=CatalogState.items or {}
    if #items==0 then notify("HX AVATAR",L("empty")); return end
    local it=items[math.random(1,#items)]
    if it then applyAsset(it) end
end)
connect(IdToggle.MouseButton1Click,function()
    idPanel.Visible=not idPanel.Visible
    CatalogScroll.Position=UDim2.fromOffset(10,idPanel.Visible and (gridTop+46) or gridTop)
    CatalogScroll.Size=UDim2.new(1,-20,1,-((idPanel.Visible and (gridTop+100) or (gridTop+54))))
end)
connect(IdApply.MouseButton1Click,function()
    local id=tonumber(IdBox.Text:match("%d+"))
    if not id then notify("HX AVATAR",L("failed")); return end
    task.spawn(function()
        local d=getItemDetails(id)
        if d then applyAsset(d) else notify("HX AVATAR",L("failed")) end
    end)
end)
for _,k in ipairs(catOrder) do
    connect(catBtns[k].MouseButton1Click,function()
        CatalogState.category=k
        for _,kk in ipairs(catOrder) do catSet[kk](kk==k) end
        runSearch()
    end)
end
catSet.all(true)
connect(PrevBtn.MouseButton1Click,function()
    if CatalogState.pages and CatalogState.pageIndex>1 then
        -- CatalogPages cannot go backwards. Re-run and advance to target page.
        local target=CatalogState.pageIndex-1
        task.spawn(function()
            searchCatalog(CatalogState.query,CatalogState.category)
            if CatalogState.pages then
                for _=2,target do
                    if CatalogState.pages.IsFinished then break end
                    pcall(function() CatalogState.pages:AdvanceToNextPageAsync() end)
                    CatalogState.pageIndex+=1
                end
                CatalogState.items=CatalogState.pages:GetCurrentPage() or {}
            end
            refreshCatalogGrid()
        end)
    end
end)
connect(NextBtn.MouseButton1Click,function()
    task.spawn(function()
        nextCatalogPage(); refreshCatalogGrid()
    end)
end)

--// Avatar tab
local AvatarPanel=contentPanels.avatar
local avatarTitle=makeLabel(AvatarPanel,L("current"),UDim2.new(1,-20,0,24),UDim2.fromOffset(10,10),{bold=true,textSize=isMobile and 12 or 15})
local avatarSub=makeLabel(AvatarPanel,L("ownedNotice"),UDim2.new(1,-20,0,28),UDim2.fromOffset(10,36),{textSize=isMobile and 7 or 9,color=COLORS.dim,wrapped=true})

local actionRow=new("Frame",{Size=UDim2.new(1,-20,0,isMobile and 68 or 78),Position=UDim2.fromOffset(10,70),BackgroundTransparency=1,ZIndex=10},AvatarPanel)
local saveRobloxBtn=makeButton(actionRow,L("saveRoblox"),UDim2.new(0.32,-6,0,isMobile and 30 or 34),UDim2.fromOffset(0,0),{bgT=0.38,borderT=0.08,textSize=isMobile and 7 or 9,bold=true,cut=6})
local saveOutfitBtn=makeButton(actionRow,L("saveOutfit"),UDim2.new(0.32,-6,0,isMobile and 30 or 34),UDim2.new(0.34,0,0,0),{bgT=0.55,borderT=0.26,textSize=isMobile and 7 or 9,bold=true,cut=6})
local restoreBtn=makeButton(actionRow,L("restore"),UDim2.new(0.32,-6,0,isMobile and 30 or 34),UDim2.new(0.68,0,0,0),{bgT=0.72,borderT=0.45,textSize=isMobile and 7 or 9,bold=true,cut=6})
local clearAccBtn=makeButton(actionRow,L("clearAccessories"),UDim2.new(0.49,-4,0,isMobile and 27 or 31),UDim2.new(0,0,0,isMobile and 37 or 42),{bgT=0.75,borderT=0.5,textSize=isMobile and 7 or 8,bold=true,cut=6})
local copyCurrentIdBtn=makeButton(actionRow,L("copyId"),UDim2.new(0.49,-4,0,isMobile and 27 or 31),UDim2.new(0.51,0,0,isMobile and 37 or 42),{bgT=0.8,borderT=0.55,textSize=isMobile and 7 or 8,bold=true,cut=6})

connect(saveRobloxBtn.MouseButton1Click,function()
    if not WorkingDescription then return end
    local hum=getHumanoid(); if not hum then return end
    local ok,err=pcall(function() AvatarEditorService:PromptSaveAvatar(WorkingDescription,hum.RigType) end)
    if ok then notify("HX AVATAR",L("saved")) else warn(err); notify("HX AVATAR",L("failed")) end
end)
connect(saveOutfitBtn.MouseButton1Click,function()
    if not WorkingDescription then return end
    local hum=getHumanoid(); if not hum then return end
    local ok,err=pcall(function()
        AvatarEditorService:PromptCreateOutfit(WorkingDescription,hum.RigType,{},Enum.OutfitType.Avatar)
    end)
    if not ok then
        -- Compatible fallback for clients that expose the older optional-argument behavior.
        ok,err=pcall(function() AvatarEditorService:PromptCreateOutfit(WorkingDescription,hum.RigType) end)
    end
    if ok then notify("HX AVATAR",L("saved")) else warn(err); notify("HX AVATAR",L("failed")) end
end)
connect(restoreBtn.MouseButton1Click,restoreOriginal)
connect(clearAccBtn.MouseButton1Click,clearAccessories)
connect(copyCurrentIdBtn.MouseButton1Click,function()
    if selectedAssetId and safeSetClipboard(selectedAssetId) then notify("HX AVATAR",L("copied")) end
end)

local EquippedScroll=new("ScrollingFrame",{
    Size=UDim2.new(1,-20,1,-165),Position=UDim2.fromOffset(10,150),BackgroundTransparency=1,BorderSizePixel=0,
    AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=COLORS.edgeSoft,ZIndex=10
},AvatarPanel)
new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},EquippedScroll)

local function collectDescriptionAssets(desc)
    local out,seen={},{}
    local function add(id,typ)
        id=tonumber(id); if id and id>0 and not seen[id] then seen[id]=true; out[#out+1]={id=id,type=typ} end
    end
    for _,p in ipairs(stringAccessoryProps) do for n in tostring(desc[p] or ""):gmatch("%d+") do add(n,p) end end
    for _,p in ipairs({"Shirt","Pants","GraphicTShirt","Face","Head","Torso","RightArm","LeftArm","RightLeg","LeftLeg"}) do pcall(function() add(desc[p],p) end) end
    pcall(function() for _,a in ipairs(desc:GetAccessories(true)) do add(a.AssetId,tostring(a.AccessoryType):gsub("Enum.AccessoryType%.","")) end end)
    return out
end

local function refreshAvatarTab()
    avatarTitle.Text=L("current")
    avatarSub.Text=L("ownedNotice")
    saveRobloxBtn.Text=L("saveRoblox"); saveOutfitBtn.Text=L("saveOutfit"); restoreBtn.Text=L("restore"); clearAccBtn.Text=L("clearAccessories"); copyCurrentIdBtn.Text=L("copyId")
    clearChildrenExceptLayout(EquippedScroll)
    if not WorkingDescription then return end
    local assets=collectDescriptionAssets(WorkingDescription)
    for i,a in ipairs(assets) do
        local row=new("Frame",{Size=UDim2.new(1,-4,0,isMobile and 48 or 56),BackgroundColor3=COLORS.panel3,BackgroundTransparency=0.66,BorderSizePixel=0,ZIndex=11,LayoutOrder=i},EquippedScroll)
        addChamferBorder(row,{cut=6,thickness=1,color=COLORS.edgeSoft,transparency=0.56,zOffset=2})
        new("ImageLabel",{Size=UDim2.fromOffset(isMobile and 38 or 46,isMobile and 38 or 46),Position=UDim2.fromOffset(5,5),BackgroundTransparency=1,Image="rbxthumb://type=Asset&id="..a.id.."&w=150&h=150",ScaleType=Enum.ScaleType.Fit,ZIndex=12},row)
        makeLabel(row,"#"..a.id,UDim2.new(1,-170,0,18),UDim2.fromOffset(isMobile and 49 or 57,7),{bold=true,textSize=isMobile and 8 or 10,z=12})
        makeLabel(row,a.type,UDim2.new(1,-170,0,16),UDim2.fromOffset(isMobile and 49 or 57,25),{textSize=isMobile and 7 or 8,color=COLORS.dim,z=12})
        local rb=makeButton(row,L("remove"),UDim2.fromOffset(isMobile and 62 or 76,isMobile and 26 or 30),UDim2.new(1,-(isMobile and 68 or 82),0.5,-(isMobile and 13 or 15)),{bgT=0.78,borderT=0.48,textSize=isMobile and 7 or 8,bold=true,cut=5,z=13})
        connect(rb.MouseButton1Click,function() removeAssetFromWorking(a.id); refreshAvatarTab() end)
    end
end
ENV.HXAvatarRefreshAvatar=refreshAvatarTab

--// Players tab
local PlayersPanel=contentPanels.players
local playerTitle=makeLabel(PlayersPanel,L("serverPlayers"),UDim2.new(1,-20,0,24),UDim2.fromOffset(10,10),{bold=true,textSize=isMobile and 12 or 15})
local playerSearch=makeTextbox(PlayersPanel,"Username...",UDim2.new(1,-104,0,isMobile and 30 or 34),UDim2.fromOffset(10,42),{bgT=0.68})
local lookupUserBtn=makeButton(PlayersPanel,LANG=="ES" and "BUSCAR" or "LOOKUP",UDim2.fromOffset(isMobile and 76 or 84,isMobile and 30 or 34),UDim2.new(1,-94,0,42),{bgT=0.52,borderT=0.25,textSize=isMobile and 7 or 8,bold=true,cut=5})
local PlayersScroll=new("ScrollingFrame",{
    Size=UDim2.new(1,-20,1,-86),Position=UDim2.fromOffset(10,80),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=COLORS.edgeSoft,ZIndex=10
},PlayersPanel)
new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},PlayersScroll)

local function applyPlayerAvatar(plr)
    if not plr then return end
    task.spawn(function()
        local ok,desc=pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(plr.UserId) end)
        if ok and desc then
            WorkingDescription=cloneDescription(desc)
            applyWorkingDescription(false)
            notify("HX AVATAR",L("itemAdded")..": "..plr.Name)
        else notify("HX AVATAR",L("failed")) end
    end)
end


local function applyAvatarByUsername(name)
    name=tostring(name or ""):gsub("^%s+",""):gsub("%s+$","")
    if name=="" then return end
    task.spawn(function()
        local userId=nil
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr.Name:lower()==name:lower() or plr.DisplayName:lower()==name:lower() then
                userId=plr.UserId; name=plr.Name; break
            end
        end
        if not userId then
            local ok,id=pcall(function() return Players:GetUserIdFromNameAsync(name) end)
            if ok then userId=id end
        end
        if not userId then notify("HX AVATAR",L("failed")); return end
        local ok,desc=pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(userId) end)
        if ok and desc then
            WorkingDescription=cloneDescription(desc)
            applyWorkingDescription(false)
            notify("HX AVATAR",(LANG=="ES" and "Avatar copiado: " or "Avatar copied: ")..name)
        else
            notify("HX AVATAR",L("failed"))
        end
    end)
end

local function refreshPlayersTab()
    playerTitle.Text=L("serverPlayers")
    lookupUserBtn.Text=LANG=="ES" and "BUSCAR" or "LOOKUP"
    clearChildrenExceptLayout(PlayersScroll)
    local q=playerSearch.Text:lower()
    local list=Players:GetPlayers()
    table.sort(list,function(a,b) return a.DisplayName:lower()<b.DisplayName:lower() end)
    local order=0
    for _,plr in ipairs(list) do
        if plr~=LocalPlayer and (q=="" or plr.Name:lower():find(q,1,true) or plr.DisplayName:lower():find(q,1,true)) then
            order+=1
            local row=new("Frame",{Size=UDim2.new(1,-4,0,isMobile and 54 or 64),BackgroundColor3=COLORS.panel3,BackgroundTransparency=0.68,BorderSizePixel=0,ZIndex=11,LayoutOrder=order},PlayersScroll)
            addChamferBorder(row,{cut=7,thickness=1,color=COLORS.edgeSoft,transparency=0.55,zOffset=2})
            local avatar=new("ImageLabel",{Size=UDim2.fromOffset(isMobile and 42 or 50,isMobile and 42 or 50),Position=UDim2.fromOffset(6,6),BackgroundTransparency=1,ZIndex=12},row)
            task.spawn(function()
                local ok,img=pcall(function() return Players:GetUserThumbnailAsync(plr.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150) end)
                if ok and avatar.Parent then avatar.Image=img end
            end)
            makeLabel(row,plr.DisplayName,UDim2.new(1,-190,0,20),UDim2.fromOffset(isMobile and 54 or 64,8),{bold=true,textSize=isMobile and 9 or 11,z=12})
            makeLabel(row,"@"..plr.Name,UDim2.new(1,-190,0,16),UDim2.fromOffset(isMobile and 54 or 64,29),{textSize=isMobile and 7 or 8,color=COLORS.dim,z=12})
            local copy=makeButton(row,L("copyAvatar"),UDim2.fromOffset(isMobile and 84 or 106,isMobile and 28 or 32),UDim2.new(1,-(isMobile and 90 or 112),0.5,-(isMobile and 14 or 16)),{bgT=0.55,borderT=0.28,textSize=isMobile and 7 or 8,bold=true,cut=5,z=13})
            connect(copy.MouseButton1Click,function() applyPlayerAvatar(plr) end)
        end
    end
end
ENV.HXAvatarRefreshPlayers=refreshPlayersTab
connect(playerSearch:GetPropertyChangedSignal("Text"),function() task.defer(refreshPlayersTab) end)
connect(playerSearch.FocusLost,function(enter) if enter then applyAvatarByUsername(playerSearch.Text) end end)
connect(lookupUserBtn.MouseButton1Click,function() applyAvatarByUsername(playerSearch.Text) end)
connect(Players.PlayerAdded,refreshPlayersTab); connect(Players.PlayerRemoving,refreshPlayersTab)

--// Presets tab
local PresetsPanel=contentPanels.presets
local presetTitle=makeLabel(PresetsPanel,L("presets"),UDim2.new(1,-20,0,24),UDim2.fromOffset(10,10),{bold=true,textSize=isMobile and 12 or 15})
local presetNameBox=makeTextbox(PresetsPanel,L("presetName"),UDim2.new(1,-126,0,isMobile and 30 or 34),UDim2.fromOffset(10,42),{bgT=0.68})
local savePresetBtn=makeButton(PresetsPanel,L("savePreset"),UDim2.fromOffset(isMobile and 100 or 110,isMobile and 30 or 34),UDim2.new(1,-120,0,42),{bgT=0.46,borderT=0.2,textSize=isMobile and 7 or 8,bold=true,cut=6})
local PresetsScroll=new("ScrollingFrame",{
    Size=UDim2.new(1,-20,1,-88),Position=UDim2.fromOffset(10,82),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=COLORS.edgeSoft,ZIndex=10
},PresetsPanel)
new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},PresetsScroll)

local function refreshPresetsTab()
    presetTitle.Text=L("presets"); presetNameBox.PlaceholderText=L("presetName"); savePresetBtn.Text=L("savePreset")
    clearChildrenExceptLayout(PresetsScroll)
    if #SavedData.presets==0 then
        makeLabel(PresetsScroll,L("noPresets"),UDim2.new(1,-10,0,30),UDim2.fromOffset(5,5),{color=COLORS.dim,textSize=isMobile and 8 or 9})
        return
    end
    for i,p in ipairs(SavedData.presets) do
        local row=new("Frame",{Size=UDim2.new(1,-4,0,isMobile and 46 or 54),BackgroundColor3=COLORS.panel3,BackgroundTransparency=0.68,BorderSizePixel=0,ZIndex=11,LayoutOrder=i},PresetsScroll)
        addChamferBorder(row,{cut=6,thickness=1,color=COLORS.edgeSoft,transparency=0.55,zOffset=2})
        makeLabel(row,tostring(p.name or ("Preset "..i)),UDim2.new(1,-180,1,0),UDim2.fromOffset(10,0),{bold=true,textSize=isMobile and 9 or 10,z=12})
        local load=makeButton(row,L("load"),UDim2.fromOffset(isMobile and 58 or 70,isMobile and 26 or 30),UDim2.new(1,-(isMobile and 130 or 150),0.5,-(isMobile and 13 or 15)),{bgT=0.5,borderT=0.25,textSize=isMobile and 7 or 8,bold=true,cut=5,z=13})
        local del=makeButton(row,"×",UDim2.fromOffset(isMobile and 28 or 32,isMobile and 26 or 30),UDim2.new(1,-(isMobile and 36 or 40),0.5,-(isMobile and 13 or 15)),{bgT=0.84,borderT=0.58,textSize=12,bold=true,cut=5,z=13})
        connect(load.MouseButton1Click,function()
            WorkingDescription=deserializeDescription(p.description)
            applyWorkingDescription(false)
            notify("HX AVATAR",L("load"))
        end)
        connect(del.MouseButton1Click,function()
            table.remove(SavedData.presets,i); saveSavedData(); refreshPresetsTab()
        end)
    end
end
ENV.HXAvatarRefreshPresets=refreshPresetsTab
connect(savePresetBtn.MouseButton1Click,function()
    if not WorkingDescription then return end
    local name=presetNameBox.Text:gsub("^%s+",""):gsub("%s+$","")
    if name=="" then name="Preset "..tostring(#SavedData.presets+1) end
    SavedData.presets[#SavedData.presets+1]={name=name,description=serializeDescription(WorkingDescription),created=os.time()}
    saveSavedData(); presetNameBox.Text=""; refreshPresetsTab(); notify("HX AVATAR",L("savePreset"))
end)

--// Footer status in main panel
local statusDot=new("Frame",{Size=UDim2.fromOffset(5,5),Position=UDim2.new(0,isMobile and 124 or 154,1,-8),BackgroundColor3=COLORS.edgeBright,BackgroundTransparency=0.25,BorderSizePixel=0,ZIndex=20},Main)
addCorner(statusDot,5)
local statusLbl=makeLabel(Main,"AvatarEditorService + HumanoidDescription",UDim2.new(1,-220,0,14),UDim2.new(0,isMobile and 135 or 165,1,-13),{textSize=isMobile and 6 or 7,color=COLORS.dim,z=20})

--// Language refresh
ENV.HXAvatarRefreshLanguage=function()
    for _,k in ipairs(tabs) do tabButtons[k].Text=L(k) end
    SearchBox.PlaceholderText=L("search")
    for _,k in ipairs(catOrder) do catBtns[k].Text=L(k) end
    IdBox.PlaceholderText=L("idPlaceholder"); IdApply.Text=L("apply")
    refreshAvatarTab(); refreshPlayersTab(); refreshPresetsTab(); refreshCatalogGrid()
end

--// Initial data
refreshAvatarTab(); refreshPlayersTab(); refreshPresetsTab()
task.spawn(function()
    runSearch()
end)

--// Close cleanup
local ancestryConn
ancestryConn=Gui.AncestryChanged:Connect(function(_,parent)
    if parent then return end
    if ancestryConn then ancestryConn:Disconnect() end
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections={}
    ENV.HXAvatarRefreshLanguage=nil
    ENV.HXAvatarRefreshAvatar=nil
    ENV.HXAvatarRefreshPlayers=nil
    ENV.HXAvatarRefreshPresets=nil
end)

ENV.HXAvatarCleanup=function()
    if Gui and Gui.Parent then Gui:Destroy() end
end

-- Expose a small API for advanced users / loader integration.
ENV.HXAvatar = {
    ApplyAssetId = function(id)
        local d=getItemDetails(tonumber(id)); if d then return applyAsset(d) end
        return false
    end,
    RemoveAssetId = removeAssetFromWorking,
    Restore = restoreOriginal,
    ClearAccessories = clearAccessories,
    SaveToRoblox = function()
        local hum=getHumanoid(); if hum and WorkingDescription then return pcall(function() AvatarEditorService:PromptSaveAvatar(WorkingDescription,hum.RigType) end) end
        return false
    end,
    GetWorkingDescription = function() return WorkingDescription and WorkingDescription:Clone() or nil end,
}

notify("HX AVATAR", L("localOnly"))
