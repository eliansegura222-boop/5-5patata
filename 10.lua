--// BABFT VOID Galaxy Hub
--// Build A Boat For Treasure - monochrome gamer GUI + optimized utilities
--// Designed for common Roblox executors. Some functions depend on executor APIs.

--====================================================
-- Services / boot
--====================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local ENV = (getgenv and getgenv()) or _G

if ENV.__BABFT_NIGHTFALL_CLEANUP then
    pcall(ENV.__BABFT_NIGHTFALL_CLEANUP)
end

local alive = true
local connections = {}
local cleanupTasks = {}
local activeStates = {}
local characterCollisionCache = {}
local hazardTouchCache = {}
local espPlayerObjects = {}
local espBlockObjects = {}
local flyObjects = {}
local playerFlyObjects = {}
local boatUtilityObjects = {}
local boatCollisionCache = {}
local boatTouchCache = {}
local hiddenPlayerCache = {}
local hiddenBoatCache = {}
local particleCache = {}
local shadowCache = {}
local pressed = {}
local followTarget
local lastSeat
local selectedQuestTarget
local runsCompleted = 0

-- Lightweight world caches. Expensive Workspace scans are throttled instead of
-- running every frame. This is the main performance safeguard for large BABFT maps.
local worldCache = {
    chest = nil, chestAt = 0,
    nearestSeat = nil, seatAt = 0, seatRadius = 0,
    boatRoot = nil, boatRootAt = 0,
    teamSpawn = nil, teamSpawnAt = 0, teamKey = nil,
}
local autoCollectTargets = {}
local autoCollectScanAt = 0
local cachedGoldValueObject = nil

local function track(conn)
    connections[#connections + 1] = conn
    return conn
end

local function addCleanup(fn)
    cleanupTasks[#cleanupTasks + 1] = fn
end

local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
end

local function getChar()
    return LP.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local function toast(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "BABFT Hub",
            Text = tostring(text),
            Duration = 3
        })
    end)
end

--====================================================
-- Helpers: workspace / BABFT
--====================================================
local function isBasePart(x)
    return x and x:IsA("BasePart")
end

local function findFirstPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function getObjectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, pivot = pcall(function() return obj:GetPivot() end)
        if ok then return pivot.Position end
    end
    local p = findFirstPart(obj)
    return p and p.Position or nil
end

local function tpToCFrame(cf)
    local root = getRoot()
    if not root or not cf then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if activeStates.tweenTP then
        local speed = tonumber(ENV.__BABFT_TWEEN_SPEED) or 180
        local distance = (root.Position - cf.Position).Magnitude
        local duration = math.clamp(distance / math.max(speed, 1), 0.05, 12)
        local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = cf})
        tw:Play()
        tw.Completed:Wait()
    else
        root.CFrame = cf
    end
    return true
end

local function tpToPart(part, offset)
    if not isBasePart(part) then return false end
    return tpToCFrame(part.CFrame * CFrame.new(offset or Vector3.new(0, 3.5, 0)))
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function containsAny(s, words)
    s = lower(s)
    for _, w in ipairs(words) do
        if string.find(s, w, 1, true) then return true end
    end
    return false
end

local function findChestPart(forceRefresh)
    local now = os.clock()
    if not forceRefresh and worldCache.chest and worldCache.chest.Parent and (now - worldCache.chestAt) < 3.5 then
        return worldCache.chest
    end

    local preferredNames = {
        "goldenchest", "treasurechest", "treasure", "chest"
    }

    local best, bestScore
    for _, d in ipairs(Workspace:GetDescendants()) do
        local n = lower(d.Name)
        local score = nil
        if d:IsA("BasePart") then
            if n == "trigger" and d.Parent and containsAny(d.Parent.Name, preferredNames) then score = 100 end
            if containsAny(n, {"goldenchest", "treasurechest"}) then score = math.max(score or 0, 95) end
            if containsAny(n, {"treasure", "chest"}) then score = math.max(score or 0, 60) end
        elseif d:IsA("Model") and containsAny(n, preferredNames) then
            local p = d:FindFirstChild("Trigger", true) or findFirstPart(d)
            if p then
                local modelScore = containsAny(n, {"goldenchest", "treasurechest"}) and 90 or 55
                if not bestScore or modelScore > bestScore then
                    best, bestScore = p, modelScore
                end
            end
        end
        if score and (not bestScore or score > bestScore) then
            best, bestScore = d, score
        end
    end

    worldCache.chest = best
    worldCache.chestAt = now
    return best
end

local function getNormalStages()
    local boatStages = Workspace:FindFirstChild("BoatStages")
    if not boatStages then return nil end
    return boatStages:FindFirstChild("NormalStages") or boatStages
end

local function numericSuffix(name)
    return tonumber(string.match(name or "", "(%d+)%s*$"))
end

local function getStageTargets()
    local holder = getNormalStages()
    local targets = {}
    if not holder then return targets end

    -- Preferred BABFT structure: stage containers such as CaveStage1..N.
    for _, stage in ipairs(holder:GetChildren()) do
        if stage:IsA("Model") or stage:IsA("Folder") then
            local n = lower(stage.Name)
            if not containsAny(n, {"theend", "treasure", "chest"}) then
                local target = stage:FindFirstChild("DarknessPart", true)
                    or stage:FindFirstChild("StageTrigger", true)
                    or stage:FindFirstChild("Trigger", true)
                    or findFirstPart(stage)
                if isBasePart(target) then
                    targets[#targets + 1] = {
                        name = stage.Name,
                        part = target,
                        index = numericSuffix(stage.Name)
                    }
                end
            end
        end
    end

    -- Prefer explicit numeric stage order. If names changed, sort by distance to current player.
    local root = getRoot()
    table.sort(targets, function(a, b)
        if a.index and b.index then return a.index < b.index end
        if a.index then return true end
        if b.index then return false end
        if root then
            return (a.part.Position - root.Position).Magnitude < (b.part.Position - root.Position).Magnitude
        end
        return a.name < b.name
    end)
    return targets
end

local function touchPart(part)
    local root = getRoot()
    if not root or not isBasePart(part) then return false end
    if firetouchinterest then
        pcall(function()
            firetouchinterest(root, part, 0)
            task.wait(0.05)
            firetouchinterest(root, part, 1)
        end)
        return true
    end
    return tpToPart(part, Vector3.new(0, 2.5, 0))
end

local function finishRun(stepDelay)
    stepDelay = stepDelay or 0.35
    local root = getRoot()
    if not root then return false, "Personaje no disponible" end

    local stages = getStageTargets()
    if #stages == 0 then
        local chest = findChestPart()
        if chest then
            tpToPart(chest, Vector3.new(0, 2.5, 0))
            touchPart(chest)
            runsCompleted += 1
            return true
        end
        return false, "No pude localizar los stages"
    end

    for _, info in ipairs(stages) do
        if not alive then return false, "Cerrado" end
        local r = getRoot()
        if not r then return false, "Personaje no disponible" end
        tpToPart(info.part, Vector3.new(0, 2.5, 0))
        task.wait(stepDelay)
        touchPart(info.part)
        task.wait(0.10)
    end

    local chest = findChestPart()
    if chest then
        tpToPart(chest, Vector3.new(0, 2.5, 0))
        task.wait(0.2)
        touchPart(chest)
        runsCompleted += 1
        return true
    end
    return false, "Stages recorridos, pero no encontré el cofre final"
end

local function findLaunchButton()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            local text = d:IsA("TextButton") and d.Text or ""
            if containsAny(d.Name .. " " .. text, {"launch", "lanzar"}) then
                return d
            end
        end
    end
end

local function launchBoat()
    local button = findLaunchButton()
    if button then
        local fired = false
        if firesignal then
            fired = pcall(function()
                firesignal(button.MouseButton1Click)
                firesignal(button.Activated)
            end)
        end
        if not fired then
            fired = pcall(function() button:Activate() end)
        end
        if fired then return true end
    end

    -- Fallback: only remotes explicitly named as a launch action.
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") and containsAny(d.Name, {"launch", "lanzar"}) then
            local ok = pcall(function() d:FireServer() end)
            if ok then return true end
        end
    end
    return false
end

local function getSeat()
    local hum = getHum()
    if not hum then return nil end
    local seat = hum.SeatPart
    if seat and seat:IsA("BasePart") then return seat end
    return nil
end

--====================================================
-- Persistent positions
--====================================================
local POS_FILE = "BABFT_Nightfall_Positions.json"
local savedPositions = {}

local function serializeCFrame(cf)
    return {cf:GetComponents()}
end

local function deserializeCFrame(t)
    if type(t) ~= "table" or #t < 12 then return nil end
    return CFrame.new(table.unpack(t, 1, 12))
end

local function savePositionsToDisk()
    if not writefile then return end
    pcall(function()
        writefile(POS_FILE, HttpService:JSONEncode(savedPositions))
    end)
end

local function loadPositionsFromDisk()
    if not (readfile and isfile and isfile(POS_FILE)) then return end
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(POS_FILE))
        if type(decoded) == "table" then savedPositions = decoded end
    end)
end

loadPositionsFromDisk()

--====================================================
-- ESP
--====================================================
local function clearPlayerESP()
    for _, o in pairs(espPlayerObjects) do
        if o.highlight then pcall(function() o.highlight:Destroy() end) end
        if o.billboard then pcall(function() o.billboard:Destroy() end) end
    end
    table.clear(espPlayerObjects)
end

local function addPlayerESP(plr)
    if plr == LP or not plr.Character or espPlayerObjects[plr] then return end
    local char = plr.Character
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not root then return end

    local h = Instance.new("Highlight")
    h.Name = "BABFT_PlayerESP"
    h.Adornee = char
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 0.78
    h.OutlineTransparency = 0.05
    h.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "BABFT_PlayerName"
    bb.Adornee = root
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(180, 34)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.Parent = root

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.fromScale(1, 1)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 13
    txt.TextColor3 = Color3.fromRGB(245, 245, 255)
    txt.TextStrokeTransparency = 0.55
    txt.Text = plr.DisplayName .. "  @" .. plr.Name
    txt.Parent = bb

    espPlayerObjects[plr] = {highlight = h, billboard = bb}
end

local function refreshPlayerESP()
    if not activeStates.playerESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do addPlayerESP(plr) end
    for plr, o in pairs(espPlayerObjects) do
        if not plr.Parent or not plr.Character or o.highlight.Adornee ~= plr.Character then
            if o.highlight then pcall(function() o.highlight:Destroy() end) end
            if o.billboard then pcall(function() o.billboard:Destroy() end) end
            espPlayerObjects[plr] = nil
            if plr.Parent and plr.Character then addPlayerESP(plr) end
        end
    end
end

local function clearBlockESP()
    for _, o in ipairs(espBlockObjects) do pcall(function() o:Destroy() end) end
    table.clear(espBlockObjects)
end

local function isCharacterPart(part)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return true end
    end
    return false
end

local function refreshBlockESP()
    clearBlockESP()
    if not activeStates.blockESP then return end
    local root = getRoot()
    if not root then return end

    local candidates = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart")
            and d ~= Workspace.Terrain
            and not isCharacterPart(d)
            and d.Transparency < 1
            and (d.Position - root.Position).Magnitude <= 750
            and (not d.Anchored or containsAny(d.Name, {"block", "boat", "seat", "motor", "jet", "wheel"})) then
            candidates[#candidates + 1] = d
        end
        if #candidates >= 140 then break end
    end

    for _, part in ipairs(candidates) do
        local box = Instance.new("SelectionBox")
        box.Name = "BABFT_BlockESP"
        box.Adornee = part
        box.LineThickness = 0.025
        box.SurfaceTransparency = 1
        box.Parent = part
        espBlockObjects[#espBlockObjects + 1] = box
    end
end

--====================================================
-- Main ScreenGui
--====================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "BABFT_Nightfall_Hub"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 2147483647
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(function() Gui.OnTopOfCoreBlur = true end)

if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end

local guiParent
if gethui then
    local ok, result = pcall(gethui)
    if ok and result then guiParent = result end
end
if not guiParent then
    local ok = pcall(function() Gui.Parent = CoreGui end)
    if ok and Gui.Parent then guiParent = CoreGui end
end
if not guiParent then guiParent = LP:WaitForChild("PlayerGui") end
Gui.Parent = guiParent

local Theme = {
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(3, 3, 3),
    panel2 = Color3.fromRGB(8, 8, 8),
    soft = Color3.fromRGB(24, 24, 24),
    accent = Color3.fromRGB(255, 255, 255),
    accent2 = Color3.fromRGB(232, 232, 232),
    text = Color3.fromRGB(248, 248, 248),
    muted = Color3.fromRGB(150, 150, 150),
    danger = Color3.fromRGB(255, 255, 255),
    line = Color3.fromRGB(76, 76, 76),
    good = Color3.fromRGB(255, 255, 255)
}

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.line
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

local function tween(obj, props, time)
    local tw = TweenService:Create(obj, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(780, 540)
Main.Position = UDim2.new(0.5, -390, 0.5, -270)
Main.BackgroundColor3 = Theme.bg
Main.BackgroundTransparency = 0
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.ZIndex = 10
Main.Parent = Gui
corner(Main, 8)
stroke(Main, Theme.accent, 1, 0.48)

local InnerBorder = Instance.new("Frame")
InnerBorder.Name = "InnerBorder"
InnerBorder.Position = UDim2.fromOffset(4, 4)
InnerBorder.Size = UDim2.new(1, -8, 1, -8)
InnerBorder.BackgroundTransparency = 1
InnerBorder.BorderSizePixel = 0
InnerBorder.ZIndex = Main.ZIndex + 1
InnerBorder.Parent = Main
corner(InnerBorder, 6)
stroke(InnerBorder, Theme.accent, 1, 0.88)

-- Optimized monochrome galaxy: a tiny fixed pool of stars updated at ~12 FPS.
-- No ParticleEmitters and no RenderStepped-per-star connections.
local StarField = Instance.new("Frame")
StarField.Name = "GalaxyField"
StarField.Size = UDim2.fromScale(1, 1)
StarField.BackgroundTransparency = 1
StarField.BorderSizePixel = 0
StarField.ClipsDescendants = true
StarField.ZIndex = Main.ZIndex + 1
StarField.Parent = Main

local galaxyStars = {}
local rng = Random.new(84219)
for i = 1, 20 do
    local star = Instance.new("Frame")
    local size = (i % 7 == 0) and 3 or ((i % 3 == 0) and 2 or 1)
    star.Size = UDim2.fromOffset(size, size)
    star.BackgroundColor3 = Theme.text
    star.BackgroundTransparency = rng:NextNumber(0.18, 0.72)
    star.BorderSizePixel = 0
    star.ZIndex = StarField.ZIndex + 1
    star.Parent = StarField
    corner(star, size)
    local data = {
        object = star,
        x = rng:NextNumber(),
        y = rng:NextNumber(),
        speed = rng:NextNumber(0.010, 0.030),
        phase = rng:NextNumber(0, math.pi * 2),
        baseTransparency = star.BackgroundTransparency,
    }
    star.Position = UDim2.fromScale(data.x, data.y)
    galaxyStars[#galaxyStars + 1] = data
end

task.spawn(function()
    local last = os.clock()
    while alive do
        if Main.Visible then
            local now = os.clock()
            local dt = math.min(now - last, 0.2)
            last = now
            for i, data in ipairs(galaxyStars) do
                data.x += data.speed * dt
                data.y += data.speed * 0.18 * dt
                if data.x > 1.015 then data.x = -0.015 end
                if data.y > 1.015 then data.y = -0.015 end
                local star = data.object
                if star and star.Parent then
                    star.Position = UDim2.fromScale(data.x, data.y)
                    star.BackgroundTransparency = math.clamp(data.baseTransparency + math.sin(now * 1.35 + data.phase) * 0.12, 0.08, 0.86)
                end
            end
            task.wait(0.08)
        else
            last = os.clock()
            task.wait(0.35)
        end
    end
end)

local Top = Instance.new("Frame")
Top.Name = "TopBar"
Top.Size = UDim2.new(1, 0, 0, 68)
Top.BackgroundColor3 = Theme.panel
Top.BackgroundTransparency = 0.14
Top.BorderSizePixel = 0
Top.ZIndex = Main.ZIndex + 2
Top.Parent = Main

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(22, 10)
Title.Size = UDim2.new(1, -210, 0, 25)
Title.Font = Enum.Font.GothamBlack
Title.Text = "VOID // BABFT"
Title.TextColor3 = Theme.text
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = Top.ZIndex + 1
Title.Parent = Top

local Sub = Instance.new("TextLabel")
Sub.BackgroundTransparency = 1
Sub.Position = UDim2.fromOffset(22, 37)
Sub.Size = UDim2.new(1, -210, 0, 17)
Sub.Font = Enum.Font.Gotham
Sub.Text = "GALACTIC CONTROL SYSTEM  //  BUILD A BOAT FOR TREASURE"
Sub.TextColor3 = Theme.muted
Sub.TextSize = 10
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.ZIndex = Top.ZIndex + 1
Sub.Parent = Top

local HeaderLine = Instance.new("Frame")
HeaderLine.Position = UDim2.new(0, 18, 1, -1)
HeaderLine.Size = UDim2.new(1, -36, 0, 1)
HeaderLine.BackgroundColor3 = Theme.accent
HeaderLine.BackgroundTransparency = 0.72
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = Top.ZIndex + 1
HeaderLine.Parent = Top

local Status = Instance.new("TextLabel")
Status.AnchorPoint = Vector2.new(1, 0.5)
Status.Position = UDim2.new(1, -106, 0.5, 0)
Status.Size = UDim2.fromOffset(92, 24)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.GothamBold
Status.Text = "●  ONLINE"
Status.TextColor3 = Theme.muted
Status.TextSize = 9
Status.TextXAlignment = Enum.TextXAlignment.Right
Status.ZIndex = Top.ZIndex + 2
Status.Parent = Top

local function topButton(text, x, color)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, x, 0.5, 0)
    b.Size = UDim2.fromOffset(34, 34)
    b.BackgroundColor3 = Theme.bg
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.TextColor3 = color or Theme.text
    b.TextSize = 16
    b.ZIndex = Top.ZIndex + 3
    b.Parent = Top
    corner(b, 5)
    stroke(b, Theme.accent, 1, 0.72)
    track(b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = Theme.soft}, 0.12) end))
    track(b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Theme.panel2}, 0.12) end))
    return b
end

local Close = topButton("×", -16, Theme.danger)
local Minimize = topButton("—", -58, Theme.text)

local Sidebar = Instance.new("Frame")
Sidebar.Position = UDim2.fromOffset(0, 68)
Sidebar.Size = UDim2.new(0, 172, 1, -68)
Sidebar.BackgroundColor3 = Theme.panel
Sidebar.BackgroundTransparency = 0.20
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = Main.ZIndex + 1
Sidebar.Parent = Main

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 15)
SidePad.PaddingLeft = UDim.new(0, 14)
SidePad.PaddingRight = UDim.new(0, 14)
SidePad.Parent = Sidebar

local SideList = Instance.new("UIListLayout")
SideList.Padding = UDim.new(0, 7)
SideList.SortOrder = Enum.SortOrder.LayoutOrder
SideList.Parent = Sidebar

local ContentHolder = Instance.new("Frame")
ContentHolder.Position = UDim2.fromOffset(172, 68)
ContentHolder.Size = UDim2.new(1, -172, 1, -68)
ContentHolder.BackgroundTransparency = 1
ContentHolder.ZIndex = Main.ZIndex + 1
ContentHolder.Parent = Main

local pages = {}
local categoryButtons = {}
local currentPage

local categories = {
    {"FARM", "Farm"},
    {"BARCO", "Boat"},
    {"MOVIMIENTO", "Movement"},
    {"TELEPORT", "Teleport"},
    {"VISUALES", "Visuals"},
    {"SERVIDOR", "Server"},
}

local function makePage(key)
    local sc = Instance.new("ScrollingFrame")
    sc.Name = key
    sc.Size = UDim2.fromScale(1, 1)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 2
    sc.ScrollBarImageColor3 = Theme.accent
    sc.CanvasSize = UDim2.fromOffset(0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.Visible = false
    sc.ZIndex = ContentHolder.ZIndex + 1
    sc.Parent = ContentHolder

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 18)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = sc

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = sc

    pages[key] = sc
    return sc
end

for _, item in ipairs(categories) do makePage(item[2]) end

local function selectPage(key)
    if currentPage == key then return end
    currentPage = key
    for k, p in pairs(pages) do p.Visible = (k == key) end
    for k, b in pairs(categoryButtons) do
        local selected = k == key
        tween(b, {BackgroundColor3 = selected and Theme.accent or Theme.bg}, 0.14)
        b.TextColor3 = selected and Theme.bg or Theme.muted
        local border = b:FindFirstChild("Border")
        if border then border.Transparency = selected and 0.08 or 0.78 end
    end
end

for i, item in ipairs(categories) do
    local label, key = item[1], item[2]
    local b = Instance.new("TextButton")
    b.LayoutOrder = i
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = Theme.bg
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBold
    b.Text = "  //  " .. label
    b.TextColor3 = Theme.muted
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.ZIndex = Sidebar.ZIndex + 2
    b.Parent = Sidebar
    corner(b, 4)
    local bs = stroke(b, Theme.accent, 1, 0.78)
    bs.Name = "Border"
    track(b.Activated:Connect(function() selectPage(key) end))
    categoryButtons[key] = b
end

local Credit = Instance.new("TextLabel")
Credit.LayoutOrder = 100
Credit.Size = UDim2.new(1, 0, 0, 50)
Credit.BackgroundTransparency = 1
Credit.Font = Enum.Font.Gotham
Credit.Text = "VOID BUILD // v3\nOPTIMIZED GALAXY CORE"
Credit.TextColor3 = Color3.fromRGB(115, 115, 115)
Credit.TextSize = 10
Credit.TextWrapped = true
Credit.ZIndex = Sidebar.ZIndex + 1
Credit.Parent = Sidebar

--====================================================
-- Components
--====================================================
local function makeSection(page, titleText, desc)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 52)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.ZIndex = page.ZIndex + 1
    holder.Parent = page

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0, 22)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.Text = "// " .. titleText
    t.TextColor3 = Theme.text
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = holder.ZIndex + 1
    t.Parent = holder

    local d = Instance.new("TextLabel")
    d.Position = UDim2.fromOffset(0, 24)
    d.Size = UDim2.new(1, 0, 0, 22)
    d.BackgroundTransparency = 1
    d.Font = Enum.Font.Gotham
    d.Text = desc or ""
    d.TextColor3 = Theme.muted
    d.TextSize = 11
    d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.ZIndex = holder.ZIndex + 1
    d.Parent = holder
    return holder
end

local function makeRow(page, titleText, desc)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 68)
    row.BackgroundColor3 = Theme.bg
    row.BackgroundTransparency = 0.10
    row.BorderSizePixel = 0
    row.ZIndex = page.ZIndex + 2
    row.Parent = page
    corner(row, 5)
    stroke(row, Theme.accent, 1, 0.84)

    local accentBar = Instance.new("Frame")
    accentBar.Position = UDim2.fromOffset(0, 10)
    accentBar.Size = UDim2.new(0, 2, 1, -20)
    accentBar.BackgroundColor3 = Theme.accent
    accentBar.BackgroundTransparency = 0.35
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = row.ZIndex + 1
    accentBar.Parent = row

    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(14, 11)
    t.Size = UDim2.new(1, -150, 0, 20)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = titleText
    t.TextColor3 = Theme.text
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = row.ZIndex + 1
    t.Parent = row

    local d = Instance.new("TextLabel")
    d.Position = UDim2.fromOffset(14, 33)
    d.Size = UDim2.new(1, -150, 0, 21)
    d.BackgroundTransparency = 1
    d.Font = Enum.Font.Gotham
    d.Text = desc or ""
    d.TextColor3 = Theme.muted
    d.TextSize = 10
    d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.ZIndex = row.ZIndex + 1
    d.Parent = row
    return row, t, d
end

local function actionButton(page, titleText, desc, callback, buttonText)
    local row = makeRow(page, titleText, desc)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -12, 0.5, 0)
    b.Size = UDim2.fromOffset(112, 38)
    b.BackgroundColor3 = Theme.accent
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBold
    b.Text = buttonText or "EJECUTAR"
    b.TextColor3 = Theme.bg
    b.TextSize = 10
    b.ZIndex = row.ZIndex + 3
    b.Parent = row
    corner(b, 4)
    track(b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = Theme.text}, 0.10) end))
    track(b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Theme.accent}, 0.10) end))
    track(b.Activated:Connect(function()
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then toast("Error: " .. tostring(err)) end
        end)
    end))
    return b, row
end

local function toggleRow(page, titleText, desc, stateKey, default, callback)
    activeStates[stateKey] = default == true
    local row = makeRow(page, titleText, desc)
    local toggle = Instance.new("TextButton")
    toggle.AnchorPoint = Vector2.new(1, 0.5)
    toggle.Position = UDim2.new(1, -14, 0.5, 0)
    toggle.Size = UDim2.fromOffset(50, 26)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Text = ""
    toggle.ZIndex = row.ZIndex + 3
    toggle.Parent = row
    corner(toggle, 4)

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Size = UDim2.fromOffset(18, 18)
    dot.BorderSizePixel = 0
    dot.ZIndex = toggle.ZIndex + 1
    dot.Parent = toggle
    corner(dot, 3)

    local function render(instant)
        local on = activeStates[stateKey]
        local propsToggle = {BackgroundColor3 = on and Theme.accent or Theme.soft}
        local propsDot = {
            Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
            BackgroundColor3 = on and Theme.bg or Theme.muted
        }
        if instant then
            for k,v in pairs(propsToggle) do toggle[k] = v end
            for k,v in pairs(propsDot) do dot[k] = v end
        else
            tween(toggle, propsToggle, 0.16)
            tween(dot, propsDot, 0.16)
        end
    end

    render(true)
    track(toggle.Activated:Connect(function()
        activeStates[stateKey] = not activeStates[stateKey]
        render(false)
        if callback then task.spawn(callback, activeStates[stateKey]) end
    end))
    return toggle, row
end

local function sliderRow(page, titleText, desc, minValue, maxValue, defaultValue, step, callback)
    local row, title = makeRow(page, titleText, desc)
    row.Size = UDim2.new(1, 0, 0, 84)
    title.Size = UDim2.new(1, -90, 0, 20)

    local valueLabel = Instance.new("TextLabel")
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, -16, 0, 11)
    valueLabel.Size = UDim2.fromOffset(70, 20)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextColor3 = Theme.text
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = row.ZIndex + 2
    valueLabel.Parent = row

    local bar = Instance.new("Frame")
    bar.Position = UDim2.new(0, 16, 1, -20)
    bar.Size = UDim2.new(1, -32, 0, 5)
    bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bar.BorderSizePixel = 0
    bar.ZIndex = row.ZIndex + 2
    bar.Parent = row
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Theme.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = bar.ZIndex + 1
    fill.Parent = bar
    corner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Theme.accent
    knob.BorderSizePixel = 0
    knob.ZIndex = fill.ZIndex + 1
    knob.Parent = bar
    corner(knob, 7)

    local current = defaultValue
    local dragging = false
    local function quantize(v)
        local q = math.floor(((v - minValue) / step) + 0.5) * step + minValue
        return math.clamp(q, minValue, maxValue)
    end
    local function setValue(v, fire)
        current = quantize(v)
        local alpha = (current - minValue) / (maxValue - minValue)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(current)
        if fire and callback then callback(current) end
    end
    local function fromInput(input)
        local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        setValue(minValue + (maxValue - minValue) * alpha, true)
    end

    track(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(input)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    setValue(defaultValue, true)
    return {Get = function() return current end, Set = function(v) setValue(v, true) end}, row
end

--====================================================
-- Modal / dynamic lists
--====================================================
local ModalShade = Instance.new("TextButton")
ModalShade.Name = "ModalShade"
ModalShade.Size = UDim2.fromScale(1, 1)
ModalShade.BackgroundColor3 = Color3.new(0, 0, 0)
ModalShade.BackgroundTransparency = 0.38
ModalShade.BorderSizePixel = 0
ModalShade.Text = ""
ModalShade.AutoButtonColor = false
ModalShade.Visible = false
ModalShade.ZIndex = 70
ModalShade.Parent = Main

local Modal = Instance.new("Frame")
Modal.AnchorPoint = Vector2.new(0.5, 0.5)
Modal.Position = UDim2.fromScale(0.5, 0.5)
Modal.Size = UDim2.fromOffset(430, 360)
Modal.BackgroundColor3 = Theme.bg
Modal.BorderSizePixel = 0
Modal.Visible = false
Modal.ZIndex = ModalShade.ZIndex + 1
Modal.Parent = Main
corner(Modal, 6)
stroke(Modal, Theme.accent, 1, 0.48)

local ModalTitle = Instance.new("TextLabel")
ModalTitle.Position = UDim2.fromOffset(16, 12)
ModalTitle.Size = UDim2.new(1, -62, 0, 28)
ModalTitle.BackgroundTransparency = 1
ModalTitle.Font = Enum.Font.GothamBold
ModalTitle.TextColor3 = Theme.text
ModalTitle.TextSize = 15
ModalTitle.TextXAlignment = Enum.TextXAlignment.Left
ModalTitle.ZIndex = Modal.ZIndex + 2
ModalTitle.Parent = Modal

local ModalClose = Instance.new("TextButton")
ModalClose.AnchorPoint = Vector2.new(1, 0)
ModalClose.Position = UDim2.new(1, -10, 0, 10)
ModalClose.Size = UDim2.fromOffset(32, 32)
ModalClose.BackgroundColor3 = Theme.bg
ModalClose.BorderSizePixel = 0
ModalClose.Font = Enum.Font.GothamBold
ModalClose.Text = "×"
ModalClose.TextColor3 = Theme.text
ModalClose.TextSize = 15
ModalClose.ZIndex = Modal.ZIndex + 3
ModalClose.Parent = Modal
corner(ModalClose, 4)

local ModalScroll = Instance.new("ScrollingFrame")
ModalScroll.Position = UDim2.fromOffset(12, 52)
ModalScroll.Size = UDim2.new(1, -24, 1, -64)
ModalScroll.BackgroundTransparency = 1
ModalScroll.BorderSizePixel = 0
ModalScroll.ScrollBarThickness = 3
ModalScroll.ScrollBarImageColor3 = Theme.accent
ModalScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ModalScroll.CanvasSize = UDim2.fromOffset(0, 0)
ModalScroll.ZIndex = Modal.ZIndex + 2
ModalScroll.Parent = Modal

local ModalList = Instance.new("UIListLayout")
ModalList.Padding = UDim.new(0, 7)
ModalList.SortOrder = Enum.SortOrder.LayoutOrder
ModalList.Parent = ModalScroll

local function closeModal()
    Modal.Visible = false
    ModalShade.Visible = false
end

local function clearModal()
    for _, c in ipairs(ModalScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function modalButton(text, subtext, callback, danger)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 52)
    b.BackgroundColor3 = Theme.panel2
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.ZIndex = ModalScroll.ZIndex + 2
    b.Parent = ModalScroll
    corner(b, 10)

    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(13, 8)
    t.Size = UDim2.new(1, -26, 0, 18)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = text
    t.TextColor3 = danger and Theme.danger or Theme.text
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = b.ZIndex + 1
    t.Parent = b

    local s = Instance.new("TextLabel")
    s.Position = UDim2.fromOffset(13, 28)
    s.Size = UDim2.new(1, -26, 0, 15)
    s.BackgroundTransparency = 1
    s.Font = Enum.Font.Gotham
    s.Text = subtext or ""
    s.TextColor3 = Theme.muted
    s.TextSize = 9
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.ZIndex = b.ZIndex + 1
    s.Parent = b

    track(b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = Theme.soft}, 0.12) end))
    track(b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Theme.panel2}, 0.12) end))
    track(b.Activated:Connect(function() task.spawn(callback) end))
    return b
end

local function modalSearchBox(placeholder, callback)
    local box = Instance.new("TextBox")
    box.Name = "SearchBox"
    box.LayoutOrder = -1000
    box.Size = UDim2.new(1, -4, 0, 42)
    box.BackgroundColor3 = Theme.panel2
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.PlaceholderText = placeholder or "Buscar..."
    box.PlaceholderColor3 = Theme.muted
    box.Text = ""
    box.TextColor3 = Theme.text
    box.TextSize = 12
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ZIndex = ModalScroll.ZIndex + 3
    box.Parent = ModalScroll
    corner(box, 10)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 13)
    pad.PaddingRight = UDim.new(0, 13)
    pad.Parent = box

    track(box:GetPropertyChangedSignal("Text"):Connect(function()
        if callback then callback(box.Text) end
    end))
    return box
end

local function openModal(titleText, builder)
    clearModal()
    ModalTitle.Text = titleText
    builder()
    ModalShade.Visible = true
    Modal.Visible = true
    Modal.Size = UDim2.fromOffset(390, 320)
    Modal.BackgroundTransparency = 0.15
    tween(Modal, {Size = UDim2.fromOffset(430, 360), BackgroundTransparency = 0}, 0.16)
end

track(ModalClose.Activated:Connect(closeModal))
track(ModalShade.Activated:Connect(closeModal))

--====================================================
-- Draggable main + floating restore button
--====================================================
local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPos
    local dragInput

    track(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end))

    track(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

makeDraggable(Top, Main)

local Bubble = Instance.new("TextButton")
Bubble.Name = "RestoreBubble"
Bubble.Size = UDim2.fromOffset(60, 60)
Bubble.Position = UDim2.new(1, -88, 0.5, -29)
Bubble.BackgroundColor3 = Theme.bg
Bubble.BorderSizePixel = 0
Bubble.AutoButtonColor = false
Bubble.Font = Enum.Font.GothamBlack
Bubble.Text = "V"
Bubble.TextColor3 = Theme.text
Bubble.TextSize = 23
Bubble.Visible = false
Bubble.ZIndex = 90
Bubble.Parent = Gui
corner(Bubble, 29)
stroke(Bubble, Theme.accent, 2, 0.12)

local bubbleDragging = false
local bubbleStart
local bubbleStartPos
local bubbleMoved = false
local bubbleDragInput
track(Bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        bubbleDragging = true
        bubbleMoved = false
        bubbleStart = input.Position
        bubbleStartPos = Bubble.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then bubbleDragging = false end
        end)
    end
end))
track(Bubble.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then bubbleDragInput = input end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if bubbleDragging and input == bubbleDragInput then
        local delta = input.Position - bubbleStart
        if delta.Magnitude > 4 then bubbleMoved = true end
        Bubble.Position = UDim2.new(
            bubbleStartPos.X.Scale, bubbleStartPos.X.Offset + delta.X,
            bubbleStartPos.Y.Scale, bubbleStartPos.Y.Offset + delta.Y
        )
    end
end))
track(Bubble.Activated:Connect(function()
    if bubbleMoved then return end
    Bubble.Visible = false
    Main.Visible = true
    Main.Size = UDim2.fromOffset(730, 500)
    Main.BackgroundTransparency = 0.12
    tween(Main, {Size = UDim2.fromOffset(780, 540), BackgroundTransparency = 0}, 0.18)
end))

--====================================================
-- Feature implementations
--====================================================
local walkSpeed = 16
local jumpPower = 50
local boatSpeed = 120
local tweenTPSpeed = 180
local safeCFrame
local lastHealth
local initialGravity = Workspace.Gravity
local initialGlobalShadows = Lighting.GlobalShadows
local initialQuality
local initialTerrain = {
    WaterWaveSize = Workspace.Terrain.WaterWaveSize,
    WaterWaveSpeed = Workspace.Terrain.WaterWaveSpeed,
    WaterReflectance = Workspace.Terrain.WaterReflectance,
    WaterTransparency = Workspace.Terrain.WaterTransparency,
}
pcall(function() initialQuality = settings().Rendering.QualityLevel end)

local farmStartedAt
local farmAccumulated = 0
local sessionGoldStart
local lastKnownGold
local sessionGoldEarned = 0
local playerFlySpeed = 90
local lastSeatAttempt = 0

local function getFarmElapsed()
    local elapsed = farmAccumulated
    if farmStartedAt then elapsed += os.clock() - farmStartedAt end
    return elapsed
end

local function getGoldValue()
    if cachedGoldValueObject and cachedGoldValueObject.Parent then
        return tonumber(cachedGoldValueObject.Value)
    end

    local leaderstats = LP:FindFirstChild("leaderstats")
    if leaderstats then
        for _, v in ipairs(leaderstats:GetChildren()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) and containsAny(v.Name, {"gold", "oro"}) then
                cachedGoldValueObject = v
                return tonumber(v.Value)
            end
        end
    end
    for _, v in ipairs(LP:GetDescendants()) do
        if (v:IsA("IntValue") or v:IsA("NumberValue")) and containsAny(v.Name, {"gold", "oro"}) then
            cachedGoldValueObject = v
            return tonumber(v.Value)
        end
    end
    return nil
end

local function getTeamSpawn()
    local now = os.clock()
    local team = LP.Team
    local teamKey = team and (team.Name .. ":" .. tostring(team.TeamColor)) or "none"
    if worldCache.teamSpawn and worldCache.teamSpawn.Parent and worldCache.teamKey == teamKey and (now - worldCache.teamSpawnAt) < 8 then
        return worldCache.teamSpawn
    end

    local found
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            if team and not d.Neutral and d.TeamColor == team.TeamColor then found = d break end
            if team and containsAny(d.Name, {lower(team.Name), "spawn", "zone"}) then found = found or d end
        end
    end
    if not found and team then
        local teamName = lower(team.Name)
        local best, bestScore
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = lower(d.Name .. " " .. (d.Parent and d.Parent.Name or ""))
                local score = 0
                if string.find(n, teamName, 1, true) then score += 5 end
                if containsAny(n, {"zone", "build", "spawn", "team"}) then score += 3 end
                if score > 0 and (not bestScore or score > bestScore) then best, bestScore = d, score end
            end
        end
        found = best
    end

    worldCache.teamSpawn = found
    worldCache.teamSpawnAt = now
    worldCache.teamKey = teamKey
    return found
end
local function getNearestSeat(maxDistance)
    local root = getRoot()
    if not root then return nil end
    maxDistance = maxDistance or 450
    local now = os.clock()
    local cached = worldCache.nearestSeat
    if cached and cached.Parent and (cached.Position - root.Position).Magnitude <= maxDistance and (now - worldCache.seatAt) < 1.25 then
        return cached
    end
    if (now - worldCache.seatAt) < 1.25 and worldCache.seatRadius >= maxDistance then
        return nil
    end

    local best, dist = nil, maxDistance
    for _, d in ipairs(Workspace:GetDescendants()) do
        if (d:IsA("VehicleSeat") or d:IsA("Seat")) and not isCharacterPart(d) then
            local m = (d.Position - root.Position).Magnitude
            if m < dist then best, dist = d, m end
        end
    end
    worldCache.nearestSeat = best
    worldCache.seatAt = now
    worldCache.seatRadius = maxDistance
    return best
end
local function getBoatRoot()
    local now = os.clock()
    local seat = getSeat()
    if seat and seat.Parent then
        lastSeat = seat
        local root = seat.AssemblyRootPart or seat
        worldCache.boatRoot = root
        worldCache.boatRootAt = now
        return root
    end

    if lastSeat and lastSeat.Parent then
        local root = lastSeat.AssemblyRootPart or lastSeat
        worldCache.boatRoot = root
        worldCache.boatRootAt = now
        return root
    end

    if worldCache.boatRoot and worldCache.boatRoot.Parent and (now - worldCache.boatRootAt) < 1.25 then
        return worldCache.boatRoot
    end

    seat = getNearestSeat(500)
    if seat then
        lastSeat = seat
        local root = seat.AssemblyRootPart or seat
        worldCache.boatRoot = root
        worldCache.boatRootAt = now
        return root
    end

    worldCache.boatRoot = nil
    worldCache.boatRootAt = now
    return nil
end

local function getBoatParts()
    local root = getBoatRoot()
    if not root then return {}, nil end
    local parts = {root}
    local ok, connected = pcall(function() return root:GetConnectedParts(true) end)
    if ok and type(connected) == "table" then parts = connected end
    return parts, root
end

local function setPartCache(cache, part, property, value)
    if cache[part] == nil then
        local ok, old = pcall(function() return part[property] end)
        if ok then cache[part] = old end
    end
    pcall(function() part[property] = value end)
end

local function restorePartCache(cache, property)
    for part, old in pairs(cache) do
        if part and part.Parent then pcall(function() part[property] = old end) end
    end
    table.clear(cache)
end

local function setNoclip(enabled)
    if not enabled then
        for part, old in pairs(characterCollisionCache) do
            if part and part.Parent then pcall(function() part.CanCollide = old end) end
        end
        table.clear(characterCollisionCache)
    end
end

local function setAntiHazard(enabled)
    if not enabled then
        for part, old in pairs(hazardTouchCache) do
            if part and part.Parent then pcall(function() part.CanTouch = old end) end
        end
        table.clear(hazardTouchCache)
        return
    end

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and containsAny(d.Name, {"water", "lava", "acid", "toxic", "damage", "kill", "hazard"}) then
            if hazardTouchCache[d] == nil then hazardTouchCache[d] = d.CanTouch end
            pcall(function() d.CanTouch = false end)
        end
    end
end

local function destroyFlyObjects()
    for _, obj in pairs(flyObjects) do if obj then pcall(function() obj:Destroy() end) end end
    table.clear(flyObjects)
end

local function ensureBoatFlyObjects(seat)
    if flyObjects.seat == seat and flyObjects.velocity and flyObjects.velocity.Parent then return end
    destroyFlyObjects()

    local vel = Instance.new("BodyVelocity")
    vel.Name = "BABFT_BoatFlyVelocity"
    vel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    vel.P = 30000
    vel.Velocity = Vector3.zero
    vel.Parent = seat

    local gyro = Instance.new("BodyGyro")
    gyro.Name = "BABFT_BoatFlyGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 30000
    gyro.D = 700
    gyro.CFrame = seat.CFrame
    gyro.Parent = seat

    flyObjects.seat = seat
    flyObjects.velocity = vel
    flyObjects.gyro = gyro
end

local function getMoveVector()
    Camera = Workspace.CurrentCamera or Camera
    if not Camera then return Vector3.zero end
    local dir = Vector3.zero
    local look = Camera.CFrame.LookVector
    local right = Camera.CFrame.RightVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    local flatRight = Vector3.new(right.X, 0, right.Z)
    if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
    if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

    if pressed.W then dir += flatLook end
    if pressed.S then dir -= flatLook end
    if pressed.D then dir += flatRight end
    if pressed.A then dir -= flatRight end
    if pressed.Space then dir += Vector3.yAxis end
    if pressed.Ctrl then dir -= Vector3.yAxis end
    return dir.Magnitude > 0 and dir.Unit or Vector3.zero
end

local keyMap = {
    [Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S", [Enum.KeyCode.D] = "D",
    [Enum.KeyCode.Space] = "Space", [Enum.KeyCode.LeftControl] = "Ctrl", [Enum.KeyCode.RightControl] = "Ctrl"
}
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = keyMap[input.KeyCode]
    if k then pressed[k] = true end

    if activeStates.infiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local hum = getHum()
        if hum and hum.Health > 0 then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end

    if activeStates.clickTP and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = input.Position
        local function inside(obj)
            if not obj or not obj.Visible then return false end
            local a, z = obj.AbsolutePosition, obj.AbsoluteSize
            return pos.X >= a.X and pos.X <= a.X + z.X and pos.Y >= a.Y and pos.Y <= a.Y + z.Y
        end
        if not inside(Main) and not inside(Bubble) then
            local mouse = LP:GetMouse()
            if mouse and mouse.Hit then task.spawn(function() tpToCFrame(mouse.Hit * CFrame.new(0, 3, 0)) end) end
        end
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    local k = keyMap[input.KeyCode]
    if k then pressed[k] = false end
end))

local function doAutoCollect()
    local root = getRoot()
    if not root then return end
    local now = os.clock()

    -- Rebuild a small target cache only every few seconds instead of scanning
    -- the entire Workspace every collection tick.
    if (now - autoCollectScanAt) > 3.0 or #autoCollectTargets == 0 then
        table.clear(autoCollectTargets)
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") and containsAny(d.Name, {"gold", "collect", "pickup", "treasure", "chest"}) then
                autoCollectTargets[#autoCollectTargets + 1] = d
            elseif d:IsA("ProximityPrompt") then
                autoCollectTargets[#autoCollectTargets + 1] = d
            end
            if #autoCollectTargets >= 180 then break end
        end
        autoCollectScanAt = now
    end

    local touched = 0
    for i = #autoCollectTargets, 1, -1 do
        local d = autoCollectTargets[i]
        if not d or not d.Parent then
            table.remove(autoCollectTargets, i)
        elseif d:IsA("BasePart") then
            if (d.Position - root.Position).Magnitude <= 280 and firetouchinterest then
                pcall(function()
                    firetouchinterest(root, d, 0)
                    firetouchinterest(root, d, 1)
                end)
                touched += 1
                if touched >= 25 then break end
            end
        elseif d:IsA("ProximityPrompt") and d.Enabled and d.Parent and d.Parent:IsA("BasePart") then
            if (d.Parent.Position - root.Position).Magnitude <= d.MaxActivationDistance + 8 and fireproximityprompt then
                pcall(fireproximityprompt, d)
            end
        end
    end
end
local function rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
end

local function serverHop()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local body
    local ok, result = pcall(function() return game:HttpGet(url) end)
    if ok then body = result end

    if not body then
        local req = (syn and syn.request) or http_request or request
        if req then
            local okReq, response = pcall(req, {Url = url, Method = "GET"})
            if okReq and response then body = response.Body end
        end
    end

    if not body then
        toast("Tu executor no permitió consultar servidores")
        return
    end

    local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okJson or type(data) ~= "table" or type(data.data) ~= "table" then
        toast("No se pudo leer la lista de servidores")
        return
    end

    local candidates = {}
    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            candidates[#candidates + 1] = server
        end
    end
    if #candidates == 0 then
        toast("No encontré otro servidor disponible")
        return
    end
    local target = candidates[math.random(1, #candidates)]
    TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LP)
end

local function clearPlayerFlyObjects()
    for _, obj in pairs(playerFlyObjects) do
        if obj then pcall(function() obj:Destroy() end) end
    end
    table.clear(playerFlyObjects)
end

local function ensurePlayerFlyObjects(root)
    if playerFlyObjects.root == root and playerFlyObjects.velocity and playerFlyObjects.velocity.Parent then return end
    clearPlayerFlyObjects()
    local vel = Instance.new("BodyVelocity")
    vel.Name = "BABFT_PlayerFlyVelocity"
    vel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    vel.P = 30000
    vel.Velocity = Vector3.zero
    vel.Parent = root

    local gyro = Instance.new("BodyGyro")
    gyro.Name = "BABFT_PlayerFlyGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 30000
    gyro.D = 650
    gyro.CFrame = root.CFrame
    gyro.Parent = root

    playerFlyObjects.root = root
    playerFlyObjects.velocity = vel
    playerFlyObjects.gyro = gyro
end

local function clearBoatUtilityObjects()
    for _, obj in pairs(boatUtilityObjects) do
        if obj and typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
    end
    table.clear(boatUtilityObjects)
end

local function ensureBoatGyro(root)
    if boatUtilityObjects.root == root and boatUtilityObjects.gyro and boatUtilityObjects.gyro.Parent then
        return boatUtilityObjects.gyro
    end
    clearBoatUtilityObjects()
    local gyro = Instance.new("BodyGyro")
    gyro.Name = "BABFT_BoatUtilityGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 45000
    gyro.D = 900
    gyro.CFrame = root.CFrame
    gyro.Parent = root
    boatUtilityObjects.root = root
    boatUtilityObjects.gyro = gyro
    return gyro
end

local function setBoatNoclip(enabled)
    if not enabled then
        restorePartCache(boatCollisionCache, "CanCollide")
        return
    end
    local parts = getBoatParts()
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then setPartCache(boatCollisionCache, part, "CanCollide", false) end
    end
end

local function setBoatProtection(enabled)
    if not enabled then
        restorePartCache(boatTouchCache, "CanTouch")
        return
    end
    local parts = getBoatParts()
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then setPartCache(boatTouchCache, part, "CanTouch", false) end
    end
end

local function getThrusterObjects()
    local parts = getBoatParts()
    local found, seen = {}, {}
    for _, part in ipairs(parts) do
        local node = part
        for _ = 1, 3 do
            if node and not seen[node] and containsAny(node.Name, {"thruster", "propeller", "jet", "motor", "rocket"}) then
                seen[node] = true
                found[#found + 1] = node
            end
            node = node and node.Parent
        end
    end
    return found
end

local function activateThrusters()
    local found = getThrusterObjects()
    local activated = 0
    for _, obj in ipairs(found) do
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("ProximityPrompt") and fireproximityprompt then
                pcall(fireproximityprompt, d)
                activated += 1
            elseif d:IsA("ClickDetector") and fireclickdetector then
                pcall(fireclickdetector, d)
                activated += 1
            elseif d:IsA("BoolValue") and containsAny(d.Name, {"enabled", "active", "on"}) then
                pcall(function() d.Value = true end)
                activated += 1
            end
        end
    end
    return activated
end

local function refillFuel()
    local parts = getBoatParts()
    local changed = 0
    local seen = {}
    for _, part in ipairs(parts) do
        local parent = part.Parent
        if parent and not seen[parent] then
            seen[parent] = true
            for _, d in ipairs(parent:GetDescendants()) do
                if (d:IsA("NumberValue") or d:IsA("IntValue")) and containsAny(d.Name, {"fuel", "charge", "energy"}) then
                    pcall(function() d.Value = math.max(tonumber(d.Value) or 0, 999999) end)
                    changed += 1
                end
            end
        end
    end
    return changed
end

local function isVisibleGuiObject(obj)
    local cur = obj
    while cur and cur:IsA("GuiObject") do
        if not cur.Visible then return false end
        cur = cur.Parent
    end
    return true
end

local function guiButtonLabel(button)
    local text = ""
    if button:IsA("TextButton") then text = button.Text or "" end
    if text == "" then
        for _, d in ipairs(button:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then
                text ..= " " .. d.Text
            end
        end
    end
    return string.gsub((button.Name or "") .. " " .. text, "^%s+", "")
end

local function findGameButtons(words)
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local results = {}
    if not pg then return results end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("ImageButton")) and not d:IsDescendantOf(Gui) and isVisibleGuiObject(d) then
            local label = lower(guiButtonLabel(d))
            for _, word in ipairs(words) do
                if string.find(label, lower(word), 1, true) then
                    results[#results + 1] = {button = d, label = guiButtonLabel(d)}
                    break
                end
            end
        end
    end
    return results
end

local function activateGuiButton(button)
    if not button or not button.Parent then return false end
    local ok = false
    if firesignal then
        ok = pcall(function()
            firesignal(button.Activated)
            if button:IsA("TextButton") or button:IsA("ImageButton") then firesignal(button.MouseButton1Click) end
        end)
    end
    if not ok then ok = pcall(function() button:Activate() end) end
    return ok
end

local function autoSaveBuild()
    local buttons = findGameButtons({"save", "guardar"})
    if #buttons == 0 then
        toast("Abre el menú de guardar del juego y vuelve a intentarlo")
        return false
    end
    return activateGuiButton(buttons[1].button)
end

local function instantLaunch()
    local loads = findGameButtons({"load", "cargar"})
    if #loads > 0 then
        activateGuiButton(loads[1].button)
        task.wait(0.8)
    end
    return launchBoat()
end

local function getQuestTargets()
    local results = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local ancestry = d.Name .. " " .. d.ActionText .. " " .. d.ObjectText
            local cur = d.Parent
            for _ = 1, 3 do
                if cur then ancestry ..= " " .. cur.Name; cur = cur.Parent end
            end
            if containsAny(ancestry, {"quest", "mission", "npc", "misión", "mision"}) then
                results[#results + 1] = d
                if #results >= 40 then break end
            end
        end
    end
    return results
end

local function interactQuestPrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    local part = prompt.Parent:IsA("BasePart") and prompt.Parent or findFirstPart(prompt.Parent)
    if part then tpToPart(part, Vector3.new(0, 3, 0)) end
    task.wait(0.15)
    if fireproximityprompt then
        return pcall(fireproximityprompt, prompt)
    end
    return false
end

local function lowPlayerServer()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local body
    local ok, result = pcall(function() return game:HttpGet(url) end)
    if ok then body = result end
    if not body then
        local req = (syn and syn.request) or http_request or request
        if req then
            local okReq, response = pcall(req, {Url = url, Method = "GET"})
            if okReq and response then body = response.Body end
        end
    end
    if not body then return toast("Tu executor no permitió consultar servidores") end
    local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okJson or not data or type(data.data) ~= "table" then return toast("No pude leer los servidores") end
    table.sort(data.data, function(a, b) return (a.playing or 999) < (b.playing or 999) end)
    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LP)
            return
        end
    end
    toast("No encontré un servidor con menos jugadores")
end

local function restoreHiddenPlayers()
    for part, old in pairs(hiddenPlayerCache) do
        if part and part.Parent then pcall(function() part.LocalTransparencyModifier = old end) end
    end
    table.clear(hiddenPlayerCache)
end

local function applyHideOtherPlayers()
    if not activeStates.hideOtherPlayers then return restoreHiddenPlayers() end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            for _, d in ipairs(plr.Character:GetDescendants()) do
                if d:IsA("BasePart") then
                    if hiddenPlayerCache[d] == nil then hiddenPlayerCache[d] = d.LocalTransparencyModifier end
                    d.LocalTransparencyModifier = 1
                end
            end
        end
    end
end

local function restoreHiddenBoats()
    for part, old in pairs(hiddenBoatCache) do
        if part and part.Parent then pcall(function() part.LocalTransparencyModifier = old end) end
    end
    table.clear(hiddenBoatCache)
end

local function applyHideOtherBoats()
    if not activeStates.hideOtherBoats then return restoreHiddenBoats() end
    local ownRoot = getBoatRoot()
    local own = {}
    if ownRoot then
        local ok, parts = pcall(function() return ownRoot:GetConnectedParts(true) end)
        if ok then for _, p in ipairs(parts) do own[p] = true end end
        own[ownRoot] = true
    end
    local processedRoots = {}
    for _, seat in ipairs(Workspace:GetDescendants()) do
        if (seat:IsA("Seat") or seat:IsA("VehicleSeat")) and not isCharacterPart(seat) then
            local root = seat.AssemblyRootPart or seat
            if not processedRoots[root] and not own[root] then
                processedRoots[root] = true
                local ok, parts = pcall(function() return root:GetConnectedParts(true) end)
                if ok then
                    for _, p in ipairs(parts) do
                        if p:IsA("BasePart") and not own[p] then
                            if hiddenBoatCache[p] == nil then hiddenBoatCache[p] = p.LocalTransparencyModifier end
                            p.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
        end
    end
end

local function applyPerformanceState()
    local disableParticles = activeStates.removeParticles or activeStates.fpsBooster
    local disableShadows = activeStates.disableShadows or activeStates.fpsBooster or activeStates.lowGraphics
    local removeWater = activeStates.removeWaterEffects or activeStates.fpsBooster or activeStates.lowGraphics
    local lowQuality = activeStates.lowGraphics or activeStates.fpsBooster

    -- One Workspace pass maximum. The previous build could traverse the entire
    -- map multiple times for one graphics update.
    if disableParticles or disableShadows then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if disableParticles and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")) then
                if particleCache[d] == nil then particleCache[d] = d.Enabled end
                d.Enabled = false
            end
            if disableShadows and d:IsA("BasePart") then
                if shadowCache[d] == nil then shadowCache[d] = d.CastShadow end
                d.CastShadow = false
            end
        end
    end

    if not disableParticles then
        for d, old in pairs(particleCache) do if d and d.Parent then pcall(function() d.Enabled = old end) end end
        table.clear(particleCache)
    end

    if disableShadows then
        Lighting.GlobalShadows = false
    else
        Lighting.GlobalShadows = initialGlobalShadows
        for d, old in pairs(shadowCache) do if d and d.Parent then pcall(function() d.CastShadow = old end) end end
        table.clear(shadowCache)
    end

    if removeWater then
        pcall(function()
            Workspace.Terrain.WaterWaveSize = 0
            Workspace.Terrain.WaterWaveSpeed = 0
            Workspace.Terrain.WaterReflectance = 0
            Workspace.Terrain.WaterTransparency = 1
        end)
    else
        pcall(function()
            Workspace.Terrain.WaterWaveSize = initialTerrain.WaterWaveSize
            Workspace.Terrain.WaterWaveSpeed = initialTerrain.WaterWaveSpeed
            Workspace.Terrain.WaterReflectance = initialTerrain.WaterReflectance
            Workspace.Terrain.WaterTransparency = initialTerrain.WaterTransparency
        end)
    end

    pcall(function()
        if lowQuality then settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        elseif initialQuality then settings().Rendering.QualityLevel = initialQuality end
    end)
end

--====================================================
-- Populate UI
--====================================================
-- FARM
makeSection(pages.Farm, "FARM", "Finalización, oro y recolección automática.")

toggleRow(pages.Farm, "Auto Farm Gold / Auto Finish",
    "Recorre dinámicamente los stages y toca el cofre final; repite al reaparecer.",
    "autoFarm", false, function(on)
        if on then
            if not farmStartedAt then farmStartedAt = os.clock() end
            task.spawn(function()
                while alive and activeStates.autoFarm do
                    local root = getRoot()
                    if root then
                        local ok, msg = finishRun(0.34)
                        if not ok and msg then toast(msg) end
                        task.wait(2.5)
                    else
                        task.wait(1)
                    end
                end
            end)
        elseif farmStartedAt then
            farmAccumulated += os.clock() - farmStartedAt
            farmStartedAt = nil
        end
    end)

actionButton(pages.Farm, "Auto Finish ahora", "Hace una sola pasada hasta el Treasure.", function()
    local ok, msg = finishRun(0.34)
    toast(ok and "Finalización ejecutada" or (msg or "No se pudo finalizar"))
end, "FINALIZAR")

toggleRow(pages.Farm, "Auto Collect", "Intenta recoger pickups, cofres y prompts cercanos automáticamente.", "autoCollect", false)

toggleRow(pages.Farm, "Auto Launch", "Busca el botón/remoto de lanzamiento y lo activa automáticamente.", "autoLaunch", false, function(on)
    if on then
        task.spawn(function()
            while alive and activeStates.autoLaunch do
                launchBoat()
                task.wait(4)
            end
        end)
    end
end)

toggleRow(pages.Farm, "Auto Quest compatible", "Interactúa con el prompt de misión seleccionado cuando el mapa expone quests/NPCs mediante ProximityPrompt.", "autoQuest", false)

actionButton(pages.Farm, "Quest Selector", "Busca prompts de quests/NPCs compatibles y selecciona cuál automatizar.", function()
    openModal("Quest Selector", function()
        local quests = getQuestTargets()
        if #quests == 0 then
            modalButton("No se detectaron quests compatibles", "Solo aparecen misiones/NPCs expuestos como ProximityPrompt.", function() end)
            return
        end
        for i, prompt in ipairs(quests) do
            local parentName = prompt.Parent and prompt.Parent.Name or "NPC"
            modalButton(string.format("%02d · %s", i, prompt.ObjectText ~= "" and prompt.ObjectText or parentName), prompt.ActionText ~= "" and prompt.ActionText or prompt.Name, function()
                selectedQuestTarget = prompt
                closeModal()
                toast("Quest seleccionada")
            end)
        end
    end)
end, "SELECCIONAR")

local farmStatsRow, farmStatsTitle, farmStatsDesc = makeRow(pages.Farm, "FARM STATS", "Esperando datos de oro...")
farmStatsRow.Size = UDim2.new(1, 0, 0, 92)
farmStatsTitle.Size = UDim2.new(1, -32, 0, 20)
farmStatsDesc.Size = UDim2.new(1, -32, 0, 46)
farmStatsDesc.TextYAlignment = Enum.TextYAlignment.Top

-- BOAT
makeSection(pages.Boat, "BARCO", "Control de vuelo y velocidad del asiento/barco que estés usando.")

toggleRow(pages.Boat, "Boat Fly", "WASD para moverte, Espacio para subir y Ctrl para bajar.", "boatFly", false, function(on)
    if not on then destroyFlyObjects() end
end)

toggleRow(pages.Boat, "Boat Speed", "Aplica un boost de velocidad mientras conduces un asiento del barco.", "boatSpeed", false)

sliderRow(pages.Boat, "Potencia del barco", "Velocidad usada por Boat Fly, Boat Speed y Auto Pilot.", 40, 450, 120, 10, function(v)
    boatSpeed = v
end)

toggleRow(pages.Boat, "Auto Pilot", "Orienta y empuja el barco detectado hacia el Treasure automáticamente.", "autoPilot", false)
toggleRow(pages.Boat, "Boat Stabilizer", "Mantiene el barco vertical y reduce giros descontrolados.", "boatStabilizer", false)
toggleRow(pages.Boat, "Boat Anti Flip", "Endereza automáticamente el barco cuando detecta que está volcado.", "boatAntiFlip", false)
toggleRow(pages.Boat, "Boat Noclip", "Desactiva colisiones locales de la asamblea conectada al asiento/barco detectado.", "boatNoclip", false, setBoatNoclip)
toggleRow(pages.Boat, "Protect Boat", "Reduce contactos locales de las piezas del barco; no fuerza invencibilidad del servidor.", "protectBoat", false, setBoatProtection)
toggleRow(pages.Boat, "Infinite Fuel", "Mantiene altos los valores Fuel/Charge/Energy detectados dentro del barco.", "infiniteFuel", false)

actionButton(pages.Boat, "Propeller / Thruster Control", "Activa prompts/clicks/valores detectados en propulsores, jets, motores y rockets.", function()
    local n = activateThrusters()
    toast(n > 0 and ("Propulsores activados: " .. n) or "No detecté controles de propulsor compatibles")
end, "ACTIVAR")

toggleRow(pages.Boat, "Auto Activate Thrusters", "Intenta activar automáticamente propulsores detectados mientras esté habilitado.", "autoThrusters", false)

toggleRow(pages.Boat, "Auto Sit", "Busca un asiento cercano del barco y vuelve a sentarte automáticamente.", "autoSit", false)
toggleRow(pages.Boat, "Seat Lock", "Recuerda tu último asiento e intenta volver a sentarte si un obstáculo te expulsa.", "seatLock", false)
toggleRow(pages.Boat, "Anti Seat", "Evita permanecer sentado cuando no quieras usar asientos.", "antiSeat", false)

actionButton(pages.Boat, "Load Build / Auto Load Slot", "Usa los botones Load/Slot visibles del menú del juego, sin inventar remotes.", function()
    openModal("Load Build / Slots", function()
        local buttons = findGameButtons({"load", "slot", "cargar"})
        if #buttons == 0 then
            modalButton("No encontré botones Load/Slot", "Abre primero el menú de guardar/cargar del juego.", function() end)
            return
        end
        for i, item in ipairs(buttons) do
            modalButton(string.format("%02d · %s", i, item.label ~= "" and item.label or item.button.Name), "Activar este botón del menú del juego", function()
                activateGuiButton(item.button)
                closeModal()
            end)
        end
    end)
end, "ABRIR SLOTS")

actionButton(pages.Boat, "Auto Save Build", "Activa el botón Save visible del menú oficial cuando esté disponible.", function()
    toast(autoSaveBuild() and "Save activado" or "No pude activar Save")
end, "GUARDAR")

actionButton(pages.Boat, "Instant Launch", "Intenta cargar el slot visible y lanzar el barco inmediatamente.", function()
    toast(instantLaunch() and "Launch ejecutado" or "No pude ejecutar el lanzamiento")
end, "LANZAR")

-- MOVEMENT
makeSection(pages.Movement, "MOVIMIENTO", "Controles del personaje y protección básica.")

toggleRow(pages.Movement, "Noclip", "Desactiva colisiones de las partes del personaje mientras esté activo.", "noclip", false, setNoclip)

toggleRow(pages.Movement, "Anti Water / Anti Damage", "Bloquea hazards locales conocidos y vuelve a una posición segura si detecta daño.", "antiHazard", false, setAntiHazard)
toggleRow(pages.Movement, "Anti Void", "Si caes por debajo del límite del mapa, vuelve a la última posición segura o a tu zona de equipo.", "antiVoid", false)
toggleRow(pages.Movement, "No Fall / Anti Fall", "Limita la velocidad de caída para reducir caídas bruscas y mantener una recuperación segura.", "noFall", false)
toggleRow(pages.Movement, "Infinite Jump", "Permite volver a saltar en el aire usando Espacio.", "infiniteJump", false)
toggleRow(pages.Movement, "Player Fly", "Vuelo del personaje separado del Boat Fly: WASD, Espacio y Ctrl.", "playerFly", false, function(on)
    if not on then clearPlayerFlyObjects() end
end)

sliderRow(pages.Movement, "Player Fly Speed", "Velocidad usada únicamente por Player Fly.", 30, 300, 90, 10, function(v)
    playerFlySpeed = v
end)

sliderRow(pages.Movement, "Gravity", "Gravedad local del Workspace.", 0, 300, math.floor(initialGravity + 0.5), 5, function(v)
    Workspace.Gravity = v
end)

sliderRow(pages.Movement, "Character Speed", "WalkSpeed del personaje.", 16, 150, 16, 1, function(v)
    walkSpeed = v
    local hum = getHum()
    if hum then pcall(function() hum.WalkSpeed = v end) end
end)
sliderRow(pages.Movement, "Character Jump", "JumpPower / JumpHeight del personaje.", 50, 250, 50, 5, function(v)
    jumpPower = v
    local hum = getHum()
    if hum then
        pcall(function() hum.JumpPower = v end)
        pcall(function() hum.JumpHeight = math.max(7.2, v / 7) end)
    end
end)

-- TELEPORT
makeSection(pages.Teleport, "TELEPORT", "Stages, cofre, posiciones guardadas y jugadores.")

actionButton(pages.Teleport, "Teleport por zonas", "Muestra los stages detectados en el mapa actual.", function()
    openModal("Zonas detectadas", function()
        local stages = getStageTargets()
        if #stages == 0 then
            modalButton("No se encontraron stages", "El mapa todavía puede estar cargando.", function() end)
            return
        end
        for i, info in ipairs(stages) do
            modalButton(string.format("%02d  ·  %s", i, info.name), "Teleport al punto detectado del stage", function()
                tpToPart(info.part, Vector3.new(0, 3, 0))
                closeModal()
            end)
        end
        local chest = findChestPart()
        if chest then
            modalButton("TREASURE / COFRE FINAL", "Teleport al final del recorrido", function()
                tpToPart(chest, Vector3.new(0, 3, 0))
                closeModal()
            end)
        end
    end)
end, "VER ZONAS")

actionButton(pages.Teleport, "Teleport al cofre", "Localiza el Golden Chest / Treasure del mapa y te lleva a él.", function()
    local chest = findChestPart()
    if chest then
        tpToPart(chest, Vector3.new(0, 3, 0))
        touchPart(chest)
    else
        toast("No encontré el cofre final")
    end
end, "IR AL COFRE")

actionButton(pages.Teleport, "Teleport Last Stage", "Te lleva al último stage dinámico detectado antes del Treasure.", function()
    local stages = getStageTargets()
    local last = stages[#stages]
    if last then tpToPart(last.part, Vector3.new(0, 3, 0)) else toast("No encontré stages") end
end, "ÚLTIMO STAGE")

actionButton(pages.Teleport, "Return To Team", "Busca el spawn/zona asociada a tu equipo y vuelve a ella.", function()
    local zone = getTeamSpawn()
    if zone then tpToPart(zone, Vector3.new(0, 4, 0)) else toast("No pude detectar la zona de tu equipo") end
end, "VOLVER")

actionButton(pages.Teleport, "Teleport To Boat", "Vuelve a la asamblea del barco/asiento más probable.", function()
    local boat = getBoatRoot()
    if boat then tpToCFrame(boat.CFrame * CFrame.new(0, 5, 0)) else toast("No detecté un barco cercano") end
end, "IR AL BARCO")

actionButton(pages.Teleport, "Teleport To Seat", "Busca un asiento cercano, te lleva a él e intenta sentarte.", function()
    local seat = getSeat() or lastSeat or getNearestSeat(500)
    local hum = getHum()
    if not seat or not hum then return toast("No detecté un asiento") end
    tpToCFrame(seat.CFrame * CFrame.new(0, 2.5, 0))
    task.wait(0.15)
    pcall(function() seat:Sit(hum) end)
    lastSeat = seat
end, "SENTARSE")

toggleRow(pages.Teleport, "Click TP", "Con el toggle activo, haz clic en el mundo para teletransportarte al punto seleccionado.", "clickTP", false)
toggleRow(pages.Teleport, "Tween TP", "Convierte los teleports del hub en desplazamientos progresivos en vez de instantáneos.", "tweenTP", false)
sliderRow(pages.Teleport, "Tween TP Speed", "Velocidad del desplazamiento progresivo.", 50, 500, 180, 10, function(v)
    tweenTPSpeed = v
    ENV.__BABFT_TWEEN_SPEED = v
end)

actionButton(pages.Teleport, "Teleport To Quests / NPCs", "Lista NPCs, quests y prompts relevantes detectados en el mapa.", function()
    openModal("Quests / NPCs", function()
        local seen, count = {}, 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            if count >= 50 then break end
            if (d:IsA("Model") or d:IsA("BasePart")) and containsAny(d.Name, {"quest", "npc", "mission", "giver"}) then
                local part = d:IsA("BasePart") and d or findFirstPart(d)
                if part and not seen[d] then
                    seen[d] = true
                    count += 1
                    modalButton(d.Name, "Teleport al objetivo detectado", function()
                        tpToPart(part, Vector3.new(0, 3, 0))
                        closeModal()
                    end)
                end
            end
        end
        if count == 0 then modalButton("No se detectaron NPCs/quests", "El mapa actual no expone nombres compatibles.", function() end) end
    end)
end, "BUSCAR")

actionButton(pages.Teleport, "Guardar posición", "Guarda tu CFrame actual; usa archivo si el executor lo soporta.", function()
    local root = getRoot()
    if not root then return toast("Personaje no disponible") end
    local name = "Posición " .. tostring(#savedPositions + 1)
    savedPositions[#savedPositions + 1] = {name = name, cframe = serializeCFrame(root.CFrame)}
    savePositionsToDisk()
    toast(name .. " guardada")
end, "GUARDAR")

actionButton(pages.Teleport, "Posiciones guardadas", "Abre la lista para teletransportarte o eliminar posiciones.", function()
    openModal("Posiciones guardadas", function()
        if #savedPositions == 0 then
            modalButton("No hay posiciones", "Usa “Guardar posición” primero.", function() end)
            return
        end
        for i, item in ipairs(savedPositions) do
            modalButton(item.name or ("Posición " .. i), "Click: teletransportar", function()
                local cf = deserializeCFrame(item.cframe)
                if cf then tpToCFrame(cf) end
                closeModal()
            end)
        end
        modalButton("Eliminar todas", "Borra todas las posiciones guardadas.", function()
            table.clear(savedPositions)
            savePositionsToDisk()
            closeModal()
            toast("Posiciones eliminadas")
        end, true)
    end)
end, "ABRIR")

actionButton(pages.Teleport, "Teleport a jugadores", "Buscador de jugadores con Teleport, Spectate, Follow y Bring Boat To Player.", function()
    local function openPlayerActions(plr)
        openModal(plr.DisplayName .. "  @" .. plr.Name, function()
            modalButton("Teleport", "Ir junto a este jugador", function()
                local char = plr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then tpToCFrame(root.CFrame * CFrame.new(3, 0, 0)) end
                closeModal()
            end)
            modalButton("Spectate Player", "Poner la cámara sobre este jugador", function()
                local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    Camera = Workspace.CurrentCamera or Camera
                    if Camera then Camera.CameraSubject = hum end
                end
                closeModal()
            end)
            modalButton("Follow Player", "Seguir automáticamente a este jugador", function()
                followTarget = plr
                activeStates.followPlayer = true
                closeModal()
                toast("Follow activado: " .. plr.DisplayName)
            end)
            modalButton("Bring Boat To Player", "Mueve tu barco detectado cerca de este jugador cuando tienes control local de la asamblea.", function()
                local targetRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local boat = getBoatRoot()
                if targetRoot and boat then
                    boat.AssemblyLinearVelocity = Vector3.zero
                    boat.AssemblyAngularVelocity = Vector3.zero
                    boat.CFrame = targetRoot.CFrame * CFrame.new(8, 2, 0)
                    toast("Boat movido")
                else
                    toast("No pude detectar jugador/barco")
                end
                closeModal()
            end)
            modalButton("Detener Follow / Spectate", "Vuelve la cámara a tu personaje y detiene el seguimiento.", function()
                followTarget = nil
                activeStates.followPlayer = false
                local hum = getHum()
                Camera = Workspace.CurrentCamera or Camera
                if hum and Camera then Camera.CameraSubject = hum end
                closeModal()
            end, true)
        end)
    end

    openModal("Jugadores", function()
        local rows = {}
        modalSearchBox("Buscar jugador...", function(query)
            query = lower(query)
            for plr, button in pairs(rows) do
                local hay = lower(plr.DisplayName .. " " .. plr.Name)
                button.Visible = query == "" or string.find(hay, query, 1, true) ~= nil
            end
        end)
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                count += 1
                local b = modalButton(plr.DisplayName, "@" .. plr.Name, function() openPlayerActions(plr) end)
                rows[plr] = b
            end
        end
        if count == 0 then modalButton("No hay otros jugadores", "Servidor vacío.", function() end) end
    end)
end, "JUGADORES")

-- VISUALS
makeSection(pages.Visuals, "VISUALES", "ESP de jugadores y bloques cercanos.")

toggleRow(pages.Visuals, "ESP de jugadores", "Highlight AlwaysOnTop + nombre de cada jugador.", "playerESP", false, function(on)
    if on then refreshPlayerESP() else clearPlayerESP() end
end)

toggleRow(pages.Visuals, "ESP de bloques", "Marca hasta 140 bloques/partes cercanas con refresco lento para reducir carga.", "blockESP", false, function(on)
    if on then refreshBlockESP() else clearBlockESP() end
end)

makeSection(pages.Visuals, "RENDIMIENTO", "Opciones locales para reducir carga gráfica sin tocar tus funciones de farm.")
toggleRow(pages.Visuals, "FPS Booster", "Reduce partículas, sombras, agua y calidad de renderizado local mientras esté activo.", "fpsBooster", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Hide Other Boats", "Oculta localmente asambleas de otros asientos/barcos detectados.", "hideOtherBoats", false, function(on) if on then applyHideOtherBoats() else restoreHiddenBoats() end end)
toggleRow(pages.Visuals, "Hide Other Players", "Oculta localmente los personajes de otros jugadores.", "hideOtherPlayers", false, function(on) if on then applyHideOtherPlayers() else restoreHiddenPlayers() end end)
toggleRow(pages.Visuals, "Remove Water Effects", "Quita ondas, reflejo y visibilidad del agua de Terrain localmente.", "removeWaterEffects", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Remove Particles", "Desactiva ParticleEmitters, Trails, Beams, Smoke, Fire y Sparkles.", "removeParticles", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Disable Shadows", "Desactiva GlobalShadows y CastShadow localmente.", "disableShadows", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Low Graphics", "Fuerza calidad de render baja y reduce efectos pesados.", "lowGraphics", false, function() applyPerformanceState() end)

-- SERVER
makeSection(pages.Server, "SERVIDOR", "Reconexión y cambio de servidor.")

toggleRow(pages.Server, "Auto Rejoin", "Si Roblox reporta un error de conexión, intenta volver al mismo servidor.", "autoRejoin", false)
toggleRow(pages.Server, "Anti AFK", "Usa VirtualUser para evitar la expulsión automática por inactividad.", "antiAFK", false)

actionButton(pages.Server, "Rejoin", "Vuelve a entrar al servidor actual.", rejoin, "REJOIN")
actionButton(pages.Server, "Server Hop", "Busca otro servidor público con espacio disponible.", serverHop, "SERVER HOP")
actionButton(pages.Server, "Low Player Server", "Busca entre los servidores públicos disponibles y entra al de menor población encontrado.", lowPlayerServer, "BUSCAR")

selectPage("Farm")

--====================================================
-- Runtime loops (optimized)
--====================================================
local lastNoclipUpdate = 0
local lastMovementUpdate = 0
local lastSafetySample = 0

track(RunService.Stepped:Connect(function()
    if not alive or not activeStates.noclip then return end
    local now = os.clock()
    if now - lastNoclipUpdate < 0.12 then return end
    lastNoclipUpdate = now

    local char = getChar()
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                if characterCollisionCache[d] == nil then characterCollisionCache[d] = d.CanCollide end
                d.CanCollide = false
            end
        end
    end
end))

track(RunService.Heartbeat:Connect(function()
    if not alive then return end
    local now = os.clock()
    local hum = getHum()
    local root = getRoot()

    -- Character stats do not need to be rewritten 60 times per second.
    if hum and now - lastMovementUpdate >= 0.20 then
        lastMovementUpdate = now
        pcall(function() if hum.WalkSpeed ~= walkSpeed then hum.WalkSpeed = walkSpeed end end)
        pcall(function() if hum.JumpPower ~= jumpPower then hum.JumpPower = jumpPower end end)
        local desiredJumpHeight = math.max(7.2, jumpPower / 7)
        pcall(function() if math.abs(hum.JumpHeight - desiredJumpHeight) > 0.05 then hum.JumpHeight = desiredJumpHeight end end)
    end

    if hum and root then
        if now - lastSafetySample >= 0.20 then
            lastSafetySample = now
            if hum.Health > 0 and hum.FloorMaterial ~= Enum.Material.Air and root.Position.Y > Workspace.FallenPartsDestroyHeight + 35 then
                safeCFrame = root.CFrame
            end
        end

        if activeStates.antiHazard then
            local damaged = lastHealth and hum.Health < lastHealth
            if damaged and safeCFrame then
                root.CFrame = safeCFrame * CFrame.new(0, 3, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                pcall(function() hum.Health = hum.MaxHealth end)
            end
        end

        if activeStates.antiVoid and root.Position.Y <= Workspace.FallenPartsDestroyHeight + 28 then
            local rescue = safeCFrame
            if not rescue then
                local teamSpawn = getTeamSpawn()
                rescue = teamSpawn and (teamSpawn.CFrame * CFrame.new(0, 5, 0)) or CFrame.new(0, 50, 0)
            else
                rescue = rescue * CFrame.new(0, 4, 0)
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = rescue
        end

        if activeStates.noFall and root.AssemblyLinearVelocity.Y < -55 then
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(v.X, -24, v.Z)
        end
        lastHealth = hum.Health
    else
        lastHealth = nil
    end

    if activeStates.playerFly and root then
        ensurePlayerFlyObjects(root)
        local dir = getMoveVector()
        playerFlyObjects.velocity.Velocity = dir * playerFlySpeed
        Camera = Workspace.CurrentCamera or Camera
        if Camera then
            local look = Camera.CFrame.LookVector
            local horizontal = Vector3.new(look.X, 0, look.Z)
            if horizontal.Magnitude > 0.01 then
                playerFlyObjects.gyro.CFrame = CFrame.lookAt(root.Position, root.Position + horizontal.Unit)
            end
        end
    elseif next(playerFlyObjects) then
        clearPlayerFlyObjects()
    end

    if activeStates.followPlayer and followTarget and followTarget.Parent and root then
        local targetRoot = followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local desired = targetRoot.CFrame * CFrame.new(3, 0, 3)
            root.CFrame = root.CFrame:Lerp(desired, 0.22)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    elseif activeStates.followPlayer and (not followTarget or not followTarget.Parent) then
        activeStates.followPlayer = false
        followTarget = nil
    end

    local seatFeatureActive = activeStates.antiSeat or activeStates.seatLock or activeStates.autoSit
        or activeStates.boatFly or activeStates.boatSpeed or activeStates.boatAntiFlip
        or activeStates.autoPilot or activeStates.boatStabilizer

    if hum and seatFeatureActive then
        local seatNow = hum.SeatPart
        if seatNow then lastSeat = seatNow end
        if activeStates.antiSeat and seatNow then
            hum.Sit = false
            hum.Jump = true
        elseif not seatNow and now - lastSeatAttempt > 0.8 then
            if activeStates.seatLock and lastSeat and lastSeat.Parent then
                lastSeatAttempt = now
                pcall(function() lastSeat:Sit(hum) end)
            elseif activeStates.autoSit then
                local candidate = lastSeat and lastSeat.Parent and lastSeat or getNearestSeat(220)
                if candidate then
                    lastSeatAttempt = now
                    lastSeat = candidate
                    pcall(function() candidate:Sit(hum) end)
                end
            end
        end
    end

    local boatRealtime = activeStates.boatFly or activeStates.boatSpeed or activeStates.boatAntiFlip
        or activeStates.autoPilot or activeStates.boatStabilizer
    local seat = boatRealtime and getSeat() or nil

    if activeStates.boatFly and seat then
        ensureBoatFlyObjects(seat)
        local dir = getMoveVector()
        flyObjects.velocity.Velocity = dir * boatSpeed
        Camera = Workspace.CurrentCamera or Camera
        if Camera then
            local look = Camera.CFrame.LookVector
            local horizontal = Vector3.new(look.X, 0, look.Z)
            if horizontal.Magnitude > 0.01 then
                flyObjects.gyro.CFrame = CFrame.lookAt(seat.Position, seat.Position + horizontal.Unit)
            end
        end
    elseif activeStates.boatFly and not seat then
        destroyFlyObjects()
    elseif not activeStates.boatFly and next(flyObjects) then
        destroyFlyObjects()
    end

    if activeStates.boatSpeed and seat and not activeStates.boatFly then
        local throttle = 0
        if seat:IsA("VehicleSeat") then throttle = seat.ThrottleFloat end
        if pressed.W then throttle = 1 elseif pressed.S then throttle = -1 end
        if throttle ~= 0 then
            local look = seat.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then seat.AssemblyLinearVelocity = flat.Unit * boatSpeed * throttle end
        end
    end

    -- Critical optimization: never search the Workspace for a boat when no
    -- realtime boat feature is enabled.
    local boatRoot = boatRealtime and getBoatRoot() or nil
    if boatRoot and not activeStates.boatFly then
        if activeStates.boatAntiFlip and boatRoot.CFrame.UpVector.Y < 0.35 then
            local look = boatRoot.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            boatRoot.AssemblyAngularVelocity = Vector3.zero
            boatRoot.CFrame = CFrame.lookAt(boatRoot.Position, boatRoot.Position + flat.Unit)
        end

        if activeStates.autoPilot then
            local chest = findChestPart()
            local pos = chest and chest.Position
            if pos then
                local delta = pos - boatRoot.Position
                local flat = Vector3.new(delta.X, 0, delta.Z)
                if flat.Magnitude > 10 then
                    boatRoot.AssemblyLinearVelocity = flat.Unit * boatSpeed + Vector3.new(0, math.clamp(delta.Y * 0.6, -25, 25), 0)
                    local gyro = ensureBoatGyro(boatRoot)
                    gyro.CFrame = CFrame.lookAt(boatRoot.Position, boatRoot.Position + flat.Unit)
                else
                    boatRoot.AssemblyLinearVelocity = Vector3.zero
                end
            end
        elseif activeStates.boatStabilizer then
            local look = boatRoot.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            local gyro = ensureBoatGyro(boatRoot)
            gyro.CFrame = CFrame.lookAt(boatRoot.Position, boatRoot.Position + flat.Unit)
        elseif next(boatUtilityObjects) then
            clearBoatUtilityObjects()
        end
    elseif not boatRealtime and next(boatUtilityObjects) then
        clearBoatUtilityObjects()
    end
end))

-- Lightweight maintenance loop. Expensive map scans are cached inside the
-- feature functions and this loop is intentionally slower than the old build.
task.spawn(function()
    while alive do
        if activeStates.autoCollect then pcall(doAutoCollect) end
        if activeStates.playerESP then pcall(refreshPlayerESP) end
        if activeStates.boatNoclip then pcall(setBoatNoclip, true) end
        if activeStates.protectBoat then pcall(setBoatProtection, true) end
        if activeStates.infiniteFuel then pcall(refillFuel) end
        if activeStates.hideOtherPlayers then pcall(applyHideOtherPlayers) end

        local gold = getGoldValue()
        if gold ~= nil then
            if sessionGoldStart == nil then sessionGoldStart = gold end
            if lastKnownGold ~= nil and gold > lastKnownGold then sessionGoldEarned += gold - lastKnownGold end
            lastKnownGold = gold
        end
        local elapsed = getFarmElapsed()
        local perMinute = elapsed > 0 and (sessionGoldEarned / elapsed) * 60 or 0
        local perHour = perMinute * 60
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        farmStatsDesc.Text = string.format(
            "Oro ganado: +%s   ·   Runs: %d\nFarm: %02d:%02d   ·   Gold/min: %.1f   ·   Est. Gold/h: %.0f",
            tostring(sessionGoldEarned), runsCompleted, mins, secs, perMinute, perHour
        )
        task.wait(1.5)
    end
end)

task.spawn(function()
    while alive do
        if activeStates.blockESP then pcall(refreshBlockESP) end
        if activeStates.autoThrusters then pcall(activateThrusters) end
        if activeStates.hideOtherBoats then pcall(applyHideOtherBoats) end
        if activeStates.autoQuest then
            if not selectedQuestTarget or not selectedQuestTarget.Parent then
                local quests = getQuestTargets()
                selectedQuestTarget = quests[1]
            end
            if selectedQuestTarget then pcall(interactQuestPrompt, selectedQuestTarget) end
        end
        task.wait(5.0)
    end
end)

-- Process newly-created hazards/effects incrementally instead of rescanning the
-- entire Workspace every few seconds.
track(Workspace.DescendantAdded:Connect(function(d)
    if not alive then return end

    if activeStates.antiHazard and d:IsA("BasePart") and containsAny(d.Name, {"water", "lava", "acid", "toxic", "damage", "kill", "hazard"}) then
        if hazardTouchCache[d] == nil then hazardTouchCache[d] = d.CanTouch end
        pcall(function() d.CanTouch = false end)
    end

    local disableParticles = activeStates.removeParticles or activeStates.fpsBooster
    if disableParticles and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")) then
        if particleCache[d] == nil then particleCache[d] = d.Enabled end
        pcall(function() d.Enabled = false end)
    end

    local disableShadows = activeStates.disableShadows or activeStates.fpsBooster or activeStates.lowGraphics
    if disableShadows and d:IsA("BasePart") then
        if shadowCache[d] == nil then shadowCache[d] = d.CastShadow end
        pcall(function() d.CastShadow = false end)
    end

    if activeStates.autoCollect and #autoCollectTargets < 180 then
        if (d:IsA("BasePart") and containsAny(d.Name, {"gold", "collect", "pickup", "treasure", "chest"})) or d:IsA("ProximityPrompt") then
            autoCollectTargets[#autoCollectTargets + 1] = d
        end
    end
end))

track(LP.Idled:Connect(function()
    if not alive or not activeStates.antiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

track(Players.PlayerAdded:Connect(function(plr)
    track(plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if activeStates.playerESP then refreshPlayerESP() end
    end))
end))

track(Players.PlayerRemoving:Connect(function(plr)
    if followTarget == plr then
        followTarget = nil
        activeStates.followPlayer = false
        local hum = getHum()
        Camera = Workspace.CurrentCamera or Camera
        if hum and Camera then pcall(function() Camera.CameraSubject = hum end) end
    end
    local o = espPlayerObjects[plr]
    if o then
        if o.highlight then pcall(function() o.highlight:Destroy() end) end
        if o.billboard then pcall(function() o.billboard:Destroy() end) end
        espPlayerObjects[plr] = nil
    end
end))

track(LP.CharacterAdded:Connect(function()
    table.clear(characterCollisionCache)
    safeCFrame = nil
    lastHealth = nil
    lastSeat = nil
    worldCache.nearestSeat = nil
    worldCache.boatRoot = nil
    worldCache.seatAt = 0
    worldCache.boatRootAt = 0
    clearPlayerFlyObjects()
    task.wait(1)
end))

pcall(function()
    track(GuiService.ErrorMessageChanged:Connect(function(msg)
        if alive and activeStates.autoRejoin and msg and msg ~= "" then
            task.wait(1.5)
            rejoin()
        end
    end))
end)

--====================================================
-- Minimize / close / cleanup
--====================================================
local function cleanup()
    if not alive then return end
    alive = false
    for k in pairs(activeStates) do activeStates[k] = false end

    setNoclip(false)
    setAntiHazard(false)
    setBoatNoclip(false)
    setBoatProtection(false)
    destroyFlyObjects()
    clearPlayerFlyObjects()
    clearBoatUtilityObjects()
    clearPlayerESP()
    clearBlockESP()
    restoreHiddenPlayers()
    restoreHiddenBoats()
    applyPerformanceState()
    Workspace.Gravity = initialGravity
    ENV.__BABFT_TWEEN_SPEED = nil
    followTarget = nil

    local hum = getHum()
    if hum then
        pcall(function() hum.WalkSpeed = 16 end)
        pcall(function() hum.JumpPower = 50 end)
        pcall(function() hum.JumpHeight = 7.2 end)
        Camera = Workspace.CurrentCamera or Camera
        if Camera then pcall(function() Camera.CameraSubject = hum end) end
    end

    disconnectAll()

    for _, fn in ipairs(cleanupTasks) do pcall(fn) end
    table.clear(cleanupTasks)

    if Gui then pcall(function() Gui:Destroy() end) end
    if ENV.__BABFT_NIGHTFALL_CLEANUP == cleanup then ENV.__BABFT_NIGHTFALL_CLEANUP = nil end
end

ENV.__BABFT_NIGHTFALL_CLEANUP = cleanup

track(Minimize.Activated:Connect(function()
    closeModal()
    tween(Main, {Size = UDim2.fromOffset(730, 500), BackgroundTransparency = 0.08}, 0.12)
    task.delay(0.11, function()
        if alive then
            Main.Visible = false
            Bubble.Visible = true
        end
    end)
end))

track(Close.Activated:Connect(cleanup))

-- Entrance animation
Main.Size = UDim2.fromOffset(730, 500)
Main.BackgroundTransparency = 0.08
tween(Main, {Size = UDim2.fromOffset(780, 540), BackgroundTransparency = 0}, 0.22)

toast("VOID BABFT optimizado cargado")
