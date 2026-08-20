--[[
    H3X4 OBBY
    Universal Obby / Speedrun Utility
    V1

    Sistemas incluidos:
    - Interfaz moderna y responsive
    - Checkpoints múltiples
    - Auto Checkpoint
    - Safe Position
    - Anti Void
    - Auto Retry
    - Killbrick ESP
    - Invisible Part ESP
    - Killbrick Bypass local
    - High Jump
    - Long Jump
    - Edge Assist
    - Ladder Assist
    - Timer / Best Time / Death Counter
    - Auto Finish Detector
    - Route Recorder
    - Route Path
    - Route Replay
    - Checkpoint / Finish Scanner
    - Objective Pointer
    - Config Save / Load
    - Keybinds configurables
    - HUD flotante para móvil
]]

-- =========================================================
-- SERVICES / BOOTSTRAP
-- =========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    local ok = pcall(function()
        return CoreGui.Name
    end)
    if ok then return CoreGui end
    return PlayerGui
end

local GuiParent = getGuiParent()

for _, parent in ipairs({GuiParent, PlayerGui, CoreGui}) do
    pcall(function()
        local old = parent:FindFirstChild("H3X4_Obby")
        if old then old:Destroy() end
    end)
end

pcall(function()
    local oldRouteVisuals = Workspace:FindFirstChild("H3X4_RouteVisuals")
    if oldRouteVisuals then oldRouteVisuals:Destroy() end
end)

-- =========================================================
-- THEME / CONSTANTS
-- =========================================================

local Theme = {
    BG = Color3.fromRGB(3, 3, 4),
    Panel = Color3.fromRGB(8, 8, 10),
    Panel2 = Color3.fromRGB(14, 14, 17),
    Panel3 = Color3.fromRGB(24, 24, 28),
    Card = Color3.fromRGB(10, 10, 12),
    CardHover = Color3.fromRGB(28, 28, 32),
    Accent = Color3.fromRGB(248, 248, 248),
    Accent2 = Color3.fromRGB(168, 168, 176),
    AccentDark = Color3.fromRGB(46, 46, 52),
    AccentSoft = Color3.fromRGB(112, 112, 120),
    Text = Color3.fromRGB(248, 248, 248),
    TextDim = Color3.fromRGB(178, 178, 186),
    TextMuted = Color3.fromRGB(104, 104, 112),
    Border = Color3.fromRGB(88, 88, 96),
    Danger = Color3.fromRGB(255, 102, 118),
    Warning = Color3.fromRGB(235, 235, 200),
    Success = Color3.fromRGB(220, 255, 232),
    ToggleOff = Color3.fromRGB(20, 20, 24),
}
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local CONFIG_FILE = ("H3X4_OBBY_%d.json"):format(LocalPlayer.UserId)
local PREF_FILE = ("H3X4_OBBY_PREFS_%d.json"):format(LocalPlayer.UserId)
local DISCORD_URL = "https://discord.gg/sewRzHAG5J"

local State = {
    Alive = true,
    Character = nil,
    Humanoid = nil,
    Root = nil,
    OriginalJumpPower = 50,
    PendingAutoTimer = false,

    Checkpoints = {},
    SelectedCheckpoint = 0,
    MaxCheckpoints = 12,

    LastSafeCFrame = nil,
    LastSafeAt = 0,
    AutoCheckpointLastCFrame = nil,
    AutoCheckpointLastAt = 0,

    Route = {},
    RouteRecording = false,
    RouteReplaying = false,
    RouteLastPosition = nil,
    RouteLastAt = 0,

    TimerRunning = false,
    TimerStartedAt = 0,
    TimerElapsed = 0,
    BestTime = nil,
    Deaths = 0,
    Splits = {},

    KillEspObjects = {},
    InvisibleEspObjects = {},
    BypassCache = {},

    Objective = nil,
    ObjectiveCandidates = {},
    ObjectiveLastScan = 0,

    Connections = {},
    RenderConnections = {},

    Hidden = false,
    Destroyed = false,
}

local Settings = {
    AutoCheckpoint = false,
    AutoCheckpointDistance = 45,
    AutoCheckpointInterval = 2,

    AntiVoid = true,
    VoidDropDistance = 70,
    AutoRetry = true,
    RetryDelay = 0.35,

    KillbrickESP = false,
    InvisibleESP = false,
    KillbrickBypass = false,

    HighJump = false,
    JumpPower = 85,
    LongJump = false,
    LongJumpPower = 42,
    EdgeAssist = false,
    EdgeAssistDistance = 3.5,
    LadderAssist = false,
    LadderSpeed = 34,

    AutoTimer = false,
    AutoFinish = true,

    RoutePath = true,
    RouteRecordInterval = 0.12,
    RouteRecordDistance = 2.5,
    RouteReplaySpeed = 36,

    ObjectivePointer = false,
    ObjectiveScanDistance = 600,

    MobileHud = IS_MOBILE,
    DeviceProfile = "AUTO",
    HideDiscordPrompt = false,
    AutoDeviceAlways = false,
}

local ActiveKeybindCapture = nil

local Keybinds = {
    ToggleUI = Enum.KeyCode.RightShift,
    SaveCheckpoint = Enum.KeyCode.F2,
    ReturnCheckpoint = Enum.KeyCode.F3,
    AntiVoid = Enum.KeyCode.F4,
    StartStopTimer = Enum.KeyCode.F5,
    RouteRecord = Enum.KeyCode.F6,
}

-- =========================================================
-- HELPERS
-- =========================================================

local function trackConnection(connection)
    table.insert(State.Connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(State.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(State.Connections)

    for _, connection in ipairs(State.RenderConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(State.RenderConnections)
end

local function tween(object, duration, props, style, direction)
    if not object or not object.Parent then return nil end
    local info = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(object, info, props)
    tw:Play()
    return tw
end

local function corner(parent, radius)
    local object = Instance.new("UICorner")
    object.CornerRadius = UDim.new(0, radius or 10)
    object.Parent = parent
    return object
end

local function stroke(parent, color, transparency, thickness)
    local object = Instance.new("UIStroke")
    object.Color = color or Theme.Accent
    object.Transparency = transparency == nil and 0.7 or transparency
    object.Thickness = thickness or 1
    object.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    object.Parent = parent
    return object
end

local function gradient(parent, colorA, colorB, rotation)
    local object = Instance.new("UIGradient")
    object.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB),
    })
    object.Rotation = rotation or 0
    object.Parent = parent
    return object
end

local function hoverColor(button, normalColor, hoverColorValue)
    button.MouseEnter:Connect(function()
        tween(button, 0.14, {BackgroundColor3 = hoverColorValue})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.14, {BackgroundColor3 = normalColor})
    end)
end

local function padding(parent, left, right, top, bottom)
    local object = Instance.new("UIPadding")
    object.PaddingLeft = UDim.new(0, left or 0)
    object.PaddingRight = UDim.new(0, right or 0)
    object.PaddingTop = UDim.new(0, top or 0)
    object.PaddingBottom = UDim.new(0, bottom or 0)
    object.Parent = parent
    return object
end

local function round(number, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor(number * power + 0.5) / power
end

local function formatTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local minutes = math.floor(seconds / 60)
    local remaining = seconds - minutes * 60
    return string.format("%02d:%05.2f", minutes, remaining)
end

local function copyText(value)
    local ok = false
    if type(setclipboard) == "function" then
        ok = pcall(setclipboard, value)
    elseif type(toclipboard) == "function" then
        ok = pcall(toclipboard, value)
    elseif type(toclipboard) == "function" then
        ok = pcall(toclipboard, value)
    end
    return ok
end

local function loadPrefsFile()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
    if not isfile(PREF_FILE) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(PREF_FILE))
    end)
    if ok and type(data) == "table" then return data end
    return nil
end

local function savePrefsFile(data)
    if type(writefile) ~= "function" then return false end
    local ok, payload = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then return false end
    return pcall(writefile, PREF_FILE, payload)
end

local PrefsData = loadPrefsFile() or {}
if PrefsData.DeviceProfile and type(PrefsData.DeviceProfile) == "string" then
    Settings.DeviceProfile = PrefsData.DeviceProfile
end
if PrefsData.HideDiscordPrompt ~= nil then
    Settings.HideDiscordPrompt = PrefsData.HideDiscordPrompt == true
end
if PrefsData.AutoDeviceAlways ~= nil then
    Settings.AutoDeviceAlways = PrefsData.AutoDeviceAlways == true
end
if not Settings.AutoDeviceAlways then
    Settings.DeviceProfile = "AUTO"
end

local function persistPrefs()
    PrefsData.DeviceProfile = Settings.DeviceProfile
    PrefsData.HideDiscordPrompt = Settings.HideDiscordPrompt == true
    PrefsData.AutoDeviceAlways = Settings.AutoDeviceAlways == true
    savePrefsFile(PrefsData)
end

local function isAlive()
    return State.Character
        and State.Character.Parent
        and State.Humanoid
        and State.Humanoid.Parent
        and State.Humanoid.Health > 0
        and State.Root
        and State.Root.Parent
end

local function safePivot(cf)
    if not isAlive() or not cf then return false end
    local success = pcall(function()
        State.Root.AssemblyLinearVelocity = Vector3.zero
        State.Root.AssemblyAngularVelocity = Vector3.zero
        State.Character:PivotTo(cf)
    end)
    return success
end

local function raycast(origin, direction, extraIgnore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if State.Character then table.insert(ignore, State.Character) end
    if extraIgnore then
        for _, item in ipairs(extraIgnore) do
            table.insert(ignore, item)
        end
    end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = false
    return Workspace:Raycast(origin, direction, params)
end

local function isGrounded()
    if not isAlive() then return false end
    if State.Humanoid.FloorMaterial ~= Enum.Material.Air then return true end
    local hit = raycast(State.Root.Position, Vector3.new(0, -5, 0))
    return hit ~= nil
end

local function getHorizontalLook()
    local camera = Workspace.CurrentCamera
    if not camera then return Vector3.new(0, 0, -1) end
    local look = camera.CFrame.LookVector
    local horizontal = Vector3.new(look.X, 0, look.Z)
    if horizontal.Magnitude < 0.01 then
        local rootLook = State.Root and State.Root.CFrame.LookVector or Vector3.new(0, 0, -1)
        horizontal = Vector3.new(rootLook.X, 0, rootLook.Z)
    end
    return horizontal.Magnitude > 0 and horizontal.Unit or Vector3.new(0, 0, -1)
end

local function normalizedName(object)
    return string.lower(tostring(object and object.Name or ""))
end

local KILL_WORDS = {
    "kill", "lava", "death", "dead", "hazard", "damage", "acid", "laser",
    "void", "danger", "spike", "poison", "toxic", "fire", "burn"
}

local CHECKPOINT_WORDS = {
    "checkpoint", "check_point", "check point", "stage", "spawn", "respawn"
}

local FINISH_WORDS = {
    "finish", "end", "win", "winner", "goal", "complete", "victory"
}

local function nameContainsAny(name, words)
    name = string.lower(name or "")
    for _, word in ipairs(words) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end

local function isPotentialKillPart(part)
    if not part:IsA("BasePart") then return false end
    local name = normalizedName(part)
    if nameContainsAny(name, KILL_WORDS) then return true end

    if part.BrickColor == BrickColor.new("Really red")
        or part.BrickColor == BrickColor.new("Bright red") then
        if part.CanTouch then return true end
    end

    return false
end

local function isPotentialInvisiblePart(part)
    if not part:IsA("BasePart") then return false end
    if part == Workspace.Terrain then return false end
    if part.Transparency < 0.82 then return false end
    if not part.CanCollide then return false end
    if part.Size.Magnitude > 500 then return false end
    if State.Character and part:IsDescendantOf(State.Character) then return false end
    return true
end

local function isCheckpointPart(part)
    if not part:IsA("BasePart") then return false end
    if part:IsA("SpawnLocation") then return true end
    return nameContainsAny(normalizedName(part), CHECKPOINT_WORDS)
end

local function isFinishPart(part)
    return part:IsA("BasePart") and nameContainsAny(normalizedName(part), FINISH_WORDS)
end

-- =========================================================
-- GUI
-- =========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "H3X4_Obby"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 2147483647
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = GuiParent
pcall(function() ScreenGui.OnTopOfCoreBlur = true end)

-- =========================================================
-- NOTIFICATIONS — MONOCHROME FROSTED TOASTS
-- =========================================================

local NotificationHolder = Instance.new("Frame")
NotificationHolder.Name = "Notifications"
NotificationHolder.BackgroundTransparency = 1
NotificationHolder.AnchorPoint = Vector2.new(1, 0)
NotificationHolder.Position = UDim2.new(1, -16, 0, 16)
NotificationHolder.Size = UDim2.fromOffset(326, 260)
NotificationHolder.ZIndex = 12000
NotificationHolder.Parent = ScreenGui

local NotificationLayout = Instance.new("UIListLayout")
NotificationLayout.Padding = UDim.new(0, 8)
NotificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Top
NotificationLayout.Parent = NotificationHolder

local function notify(title, text, kind)
    if State.Destroyed then return end

    local marker = Theme.Text
    if kind == "danger" then marker = Theme.Danger end
    if kind == "warning" then marker = Theme.Warning end
    if kind == "success" then marker = Theme.Success end

    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    card.BackgroundTransparency = 0.26
    card.BorderSizePixel = 0
    card.Size = UDim2.fromOffset(314, 0)
    card.ClipsDescendants = true
    card.ZIndex = 12001
    card.Parent = NotificationHolder
    corner(card, 16)
    stroke(card, Color3.fromRGB(255, 255, 255), 0.76, 1)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(16, 10)
    titleLabel.Size = UDim2.new(1, -54, 0, 18)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title or "H3X4 OBBY"
    titleLabel.ZIndex = 12002
    titleLabel.Parent = card

    local markerDot = Instance.new("Frame")
    markerDot.AnchorPoint = Vector2.new(1, 0.5)
    markerDot.Position = UDim2.new(1, -16, 0, 19)
    markerDot.Size = UDim2.fromOffset(8, 8)
    markerDot.BackgroundColor3 = marker
    markerDot.BorderSizePixel = 0
    markerDot.ZIndex = 12002
    markerDot.Parent = card
    corner(markerDot, 99)

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(16, 31)
    body.Size = UDim2.new(1, -32, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Font = Enum.Font.GothamMedium
    body.TextSize = 9
    body.TextColor3 = Theme.TextDim
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Text = text or ""
    body.ZIndex = 12002
    body.Parent = card

    task.defer(function()
        if not card.Parent then return end
        local targetHeight = math.max(62, body.AbsoluteSize.Y + 44)
        card.Size = UDim2.fromOffset(314, 0)
        card.Position = UDim2.fromOffset(18, 0)
        tween(card, 0.22, {
            Size = UDim2.fromOffset(314, targetHeight),
            Position = UDim2.fromOffset(0, 0),
        }, Enum.EasingStyle.Quint)

        task.delay(3.0, function()
            if card and card.Parent then
                local tw = tween(card, 0.20, {
                    Size = UDim2.fromOffset(314, 0),
                    BackgroundTransparency = 1,
                }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                if tw then
                    tw.Completed:Connect(function()
                        if card then card:Destroy() end
                    end)
                else
                    card:Destroy()
                end
            end
        end)
    end)
end

-- =========================================================
-- MAIN SHELL — MONOCHROME FROSTED GLASS
-- =========================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.Size = IS_MOBILE and UDim2.fromOffset(600, 378) or UDim2.fromOffset(730, 466)
Main.BackgroundColor3 = Color3.fromRGB(5, 5, 6)
Main.BackgroundTransparency = 0.44
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.ZIndex = 10
Main.Parent = ScreenGui
Main.Visible = false
corner(Main, 24)
stroke(Main, Color3.fromRGB(255, 255, 255), 0.72, 1)

local BackgroundImage = Instance.new("ImageLabel")
BackgroundImage.Name = "BackgroundImage"
BackgroundImage.BackgroundTransparency = 1
BackgroundImage.Size = UDim2.fromScale(1, 1)
BackgroundImage.Image = "rbxassetid://110238194996163"
BackgroundImage.ImageColor3 = Color3.fromRGB(235, 235, 235)
BackgroundImage.ImageTransparency = 0.42
BackgroundImage.ScaleType = Enum.ScaleType.Crop
BackgroundImage.ZIndex = 10
BackgroundImage.Parent = Main

local BackgroundSoftLayer = BackgroundImage:Clone()
BackgroundSoftLayer.Name = "BackgroundSoftLayer"
BackgroundSoftLayer.Position = UDim2.fromOffset(2, 2)
BackgroundSoftLayer.Size = UDim2.new(1, -4, 1, -4)
BackgroundSoftLayer.ImageColor3 = Color3.fromRGB(105, 105, 110)
BackgroundSoftLayer.ImageTransparency = 0.84
BackgroundSoftLayer.ZIndex = 10
BackgroundSoftLayer.Parent = Main

local GlassOverlay = Instance.new("Frame")
GlassOverlay.Name = "GlassOverlay"
GlassOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
GlassOverlay.BackgroundTransparency = 0.64
GlassOverlay.BorderSizePixel = 0
GlassOverlay.Size = UDim2.fromScale(1, 1)
GlassOverlay.ZIndex = 10
GlassOverlay.Parent = Main
corner(GlassOverlay, 24)

local UIScale = Instance.new("UIScale")
UIScale.Scale = 1
UIScale.Parent = Main

-- =========================================================
-- TOP BAR
-- =========================================================

local Top = Instance.new("Frame")
Top.Name = "TopBar"
Top.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
Top.BackgroundTransparency = 0.42
Top.BorderSizePixel = 0
Top.Size = UDim2.new(1, 0, 0, 70)
Top.ZIndex = 11
Top.Parent = Main

local Logo = Instance.new("ImageLabel")
Logo.Name = "BrandLogo"
Logo.BackgroundTransparency = 1
Logo.BorderSizePixel = 0
Logo.Position = UDim2.fromOffset(18, 15)
Logo.Size = UDim2.fromOffset(40, 40)
Logo.Image = "rbxassetid://72742584610344"
Logo.ImageColor3 = Color3.fromRGB(255, 255, 255)
Logo.ImageTransparency = 0
Logo.ScaleType = Enum.ScaleType.Fit
Logo.ZIndex = 13
Logo.Parent = Top

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(70, 13)
Title.Size = UDim2.new(1, -250, 0, 25)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextColor3 = Theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "H3X4 OBBY"
Title.ZIndex = 12
Title.Parent = Top

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.fromOffset(70, 37)
Subtitle.Size = UDim2.new(1, -250, 0, 15)
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextSize = 8
Subtitle.TextColor3 = Theme.TextDim
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Text = "PARKOUR  /  CHECKPOINTS  /  SPEEDRUN"
Subtitle.ZIndex = 12
Subtitle.Parent = Top

local StatusPill = Instance.new("Frame")
StatusPill.AnchorPoint = Vector2.new(1, 0.5)
StatusPill.Position = UDim2.new(1, -92, 0.5, 0)
StatusPill.Size = UDim2.fromOffset(82, 28)
StatusPill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
StatusPill.BackgroundTransparency = 0.90
StatusPill.BorderSizePixel = 0
StatusPill.ZIndex = 12
StatusPill.Parent = Top
corner(StatusPill, 14)
stroke(StatusPill, Color3.fromRGB(255, 255, 255), 0.82, 1)

local StatusText = Instance.new("TextLabel")
StatusText.BackgroundTransparency = 1
StatusText.Size = UDim2.fromScale(1, 1)
StatusText.Text = IS_MOBILE and "MOBILE" or "DESKTOP"
StatusText.TextColor3 = Theme.TextDim
StatusText.TextSize = 8
StatusText.Font = Enum.Font.GothamSemibold
StatusText.ZIndex = 13
StatusText.Parent = StatusPill

local function topButton(text, offset)
    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, offset, 0.5, 0)
    button.Size = UDim2.fromOffset(34, 34)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.92
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Theme.Text
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false
    button.ZIndex = 13
    button.Parent = Top
    corner(button, 17)
    stroke(button, Color3.fromRGB(255, 255, 255), 0.84, 1)

    button.MouseEnter:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.78})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.92})
    end)
    return button
end

local MinimizeButton = topButton("−", -48)
local CloseButton = topButton("×", -10)
CloseButton.TextColor3 = Theme.Danger

-- =========================================================
-- SIDEBAR / NAVIGATION
-- =========================================================

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
Sidebar.BackgroundTransparency = 0.48
Sidebar.BorderSizePixel = 0
Sidebar.Position = UDim2.fromOffset(10, 80)
Sidebar.Size = UDim2.new(0, 170, 1, -90)
Sidebar.ZIndex = 11
Sidebar.Parent = Main
corner(Sidebar, 20)
stroke(Sidebar, Color3.fromRGB(255, 255, 255), 0.86, 1)

local SidebarTitle = Instance.new("TextLabel")
SidebarTitle.BackgroundTransparency = 1
SidebarTitle.Position = UDim2.fromOffset(14, 12)
SidebarTitle.Size = UDim2.new(1, -28, 0, 20)
SidebarTitle.Text = "MENÚ"
SidebarTitle.TextColor3 = Theme.TextMuted
SidebarTitle.TextSize = 8
SidebarTitle.Font = Enum.Font.GothamBold
SidebarTitle.TextXAlignment = Enum.TextXAlignment.Left
SidebarTitle.ZIndex = 12
SidebarTitle.Parent = Sidebar

local CategoryScroll = Instance.new("ScrollingFrame")
CategoryScroll.BackgroundTransparency = 1
CategoryScroll.BorderSizePixel = 0
CategoryScroll.Position = UDim2.fromOffset(8, 38)
CategoryScroll.Size = UDim2.new(1, -16, 1, -48)
CategoryScroll.ScrollBarThickness = 2
CategoryScroll.ScrollBarImageColor3 = Color3.fromRGB(225, 225, 225)
CategoryScroll.ScrollBarImageTransparency = 0.35
CategoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
CategoryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CategoryScroll.ZIndex = 12
CategoryScroll.Parent = Sidebar

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Padding = UDim.new(0, 6)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.Parent = CategoryScroll

local function updateCategoryCanvas()
    CategoryScroll.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 8)
end
trackConnection(CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCategoryCanvas))
task.defer(updateCategoryCanvas)

-- =========================================================
-- CONTENT SHELL / PAGE HEADER
-- =========================================================

local ContentShell = Instance.new("Frame")
ContentShell.Name = "ContentShell"
ContentShell.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
ContentShell.BackgroundTransparency = 0.52
ContentShell.BorderSizePixel = 0
ContentShell.Position = UDim2.fromOffset(190, 80)
ContentShell.Size = UDim2.new(1, -200, 1, -90)
ContentShell.ZIndex = 11
ContentShell.Parent = Main
corner(ContentShell, 20)
stroke(ContentShell, Color3.fromRGB(255, 255, 255), 0.88, 1)

local PageHeader = Instance.new("Frame")
PageHeader.BackgroundTransparency = 1
PageHeader.Size = UDim2.new(1, 0, 0, 52)
PageHeader.ZIndex = 12
PageHeader.Parent = ContentShell

local CurrentPageTitle = Instance.new("TextLabel")
CurrentPageTitle.BackgroundTransparency = 1
CurrentPageTitle.Position = UDim2.fromOffset(14, 9)
CurrentPageTitle.Size = UDim2.new(1, -120, 0, 22)
CurrentPageTitle.Text = "INICIO"
CurrentPageTitle.TextColor3 = Theme.Text
CurrentPageTitle.TextSize = 13
CurrentPageTitle.Font = Enum.Font.GothamBold
CurrentPageTitle.TextXAlignment = Enum.TextXAlignment.Left
CurrentPageTitle.ZIndex = 13
CurrentPageTitle.Parent = PageHeader

local CurrentPageHint = Instance.new("TextLabel")
CurrentPageHint.BackgroundTransparency = 1
CurrentPageHint.Position = UDim2.fromOffset(14, 30)
CurrentPageHint.Size = UDim2.new(1, -120, 0, 14)
CurrentPageHint.Text = "H3X4 / OBBY"
CurrentPageHint.TextColor3 = Theme.TextMuted
CurrentPageHint.TextSize = 8
CurrentPageHint.Font = Enum.Font.GothamMedium
CurrentPageHint.TextXAlignment = Enum.TextXAlignment.Left
CurrentPageHint.ZIndex = 13
CurrentPageHint.Parent = PageHeader

local PageCount = Instance.new("TextLabel")
PageCount.AnchorPoint = Vector2.new(1, 0.5)
PageCount.Position = UDim2.new(1, -14, 0.5, 0)
PageCount.Size = UDim2.fromOffset(70, 26)
PageCount.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PageCount.BackgroundTransparency = 0.92
PageCount.BorderSizePixel = 0
PageCount.Text = "01 / 09"
PageCount.TextColor3 = Theme.TextDim
PageCount.TextSize = 8
PageCount.Font = Enum.Font.GothamSemibold
PageCount.ZIndex = 13
PageCount.Parent = PageHeader
corner(PageCount, 13)
stroke(PageCount, Color3.fromRGB(255, 255, 255), 0.86, 1)

local CommunityHeaderButton = Instance.new("TextButton")
CommunityHeaderButton.AnchorPoint = Vector2.new(1, 0.5)
CommunityHeaderButton.Position = UDim2.new(1, -136, 0.5, 0)
CommunityHeaderButton.Size = UDim2.fromOffset(120, 28)
CommunityHeaderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CommunityHeaderButton.BackgroundTransparency = 0.93
CommunityHeaderButton.BorderSizePixel = 0
CommunityHeaderButton.Text = "UNIRSE AL DISCORD"
CommunityHeaderButton.TextColor3 = Theme.TextDim
CommunityHeaderButton.TextSize = 8
CommunityHeaderButton.Font = Enum.Font.GothamBold
CommunityHeaderButton.ZIndex = 13
CommunityHeaderButton.AutoButtonColor = false
CommunityHeaderButton.Parent = PageHeader
corner(CommunityHeaderButton, 13)
stroke(CommunityHeaderButton, Color3.fromRGB(255, 255, 255), 0.88, 1)
CommunityHeaderButton.MouseEnter:Connect(function()
    tween(CommunityHeaderButton, 0.14, {BackgroundTransparency = 0.88})
end)
CommunityHeaderButton.MouseLeave:Connect(function()
    tween(CommunityHeaderButton, 0.14, {BackgroundTransparency = 0.93})
end)


local Content = Instance.new("Frame")
Content.Name = "Pages"
Content.BackgroundTransparency = 1
Content.Position = UDim2.fromOffset(0, 52)
Content.Size = UDim2.new(1, 0, 1, -52)
Content.ZIndex = 12
Content.Parent = ContentShell

local Pages = {}
local CategoryButtons = {}
local CurrentCategory = nil

local categories = {
    {"HOME", "INICIO"},
    {"CHECKPOINTS", "CHECKPOINTS"},
    {"MOVEMENT", "MOVIMIENTO"},
    {"SAFETY", "SEGURIDAD"},
    {"VISUALS", "VISUALES"},
    {"SPEEDRUN", "SPEEDRUN"},
    {"ROUTES", "RUTAS"},
    {"SYSTEM", "SISTEMA"},
    {"KEYBINDS", "KEYBINDS"},
}

local function iconPart(parent, x, y, w, h, fill, round)
    local part = Instance.new("Frame")
    part.BackgroundColor3 = fill or Theme.TextMuted
    part.BorderSizePixel = 0
    part.Position = UDim2.fromOffset(x, y)
    part.Size = UDim2.fromOffset(w, h)
    part.Parent = parent
    if round then corner(part, round) end
    return part
end

local function iconStrokeBox(parent, x, y, w, h, color, round, thick)
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Position = UDim2.fromOffset(x, y)
    box.Size = UDim2.fromOffset(w, h)
    box.Parent = parent
    if round then corner(box, round) end
    stroke(box, color or Theme.TextMuted, 0, thick or 1)
    return box
end

local function setCategoryIconColor(iconRoot, color)
    if not iconRoot then return end
    for _, d in ipairs(iconRoot:GetDescendants()) do
        if d:IsA("Frame") and d.BackgroundTransparency < 1 then
            d.BackgroundColor3 = color
        elseif d:IsA("UIStroke") then
            d.Color = color
        end
    end
end

local function createCategoryIcon(parent, key, color)
    local root = Instance.new("Frame")
    root.Name = "Icon"
    root.BackgroundTransparency = 1
    root.Position = UDim2.fromOffset(12, 9)
    root.Size = UDim2.fromOffset(22, 22)
    root.Parent = parent

    if key == "HOME" then
        iconPart(root, 5, 10, 12, 9, color, 2)
        local leftRoof = iconPart(root, 4, 7, 9, 2, color, 1)
        leftRoof.Rotation = -35
        local rightRoof = iconPart(root, 9, 7, 9, 2, color, 1)
        rightRoof.Rotation = 35
        iconPart(root, 9, 13, 4, 6, color, 1)
    elseif key == "CHECKPOINTS" then
        iconPart(root, 5, 3, 2, 16, color, 1)
        iconPart(root, 7, 4, 10, 6, color, 2)
        iconPart(root, 4, 19, 6, 2, color, 1)
    elseif key == "MOVEMENT" then
        iconPart(root, 4, 10, 10, 2, color, 1)
        local up = iconPart(root, 12, 7, 6, 2, color, 1)
        up.Rotation = 35
        local down = iconPart(root, 12, 13, 6, 2, color, 1)
        down.Rotation = -35
    elseif key == "SAFETY" then
        iconStrokeBox(root, 3, 3, 16, 16, color, 8, 1)
        local check1 = iconPart(root, 6, 11, 4, 2, color, 1)
        check1.Rotation = 35
        local check2 = iconPart(root, 9, 10, 6, 2, color, 1)
        check2.Rotation = -35
    elseif key == "VISUALS" then
        iconStrokeBox(root, 2, 6, 18, 10, color, 8, 1)
        iconPart(root, 8, 8, 6, 6, color, 999)
        iconPart(root, 10, 10, 2, 2, Color3.fromRGB(8,8,10), 999)
    elseif key == "SPEEDRUN" then
        iconStrokeBox(root, 3, 3, 16, 16, color, 8, 1)
        iconPart(root, 10, 6, 2, 5, color, 1)
        local hand = iconPart(root, 10, 10, 5, 2, color, 1)
        hand.Rotation = 35
        iconPart(root, 8, 1, 6, 2, color, 1)
    elseif key == "ROUTES" then
        local n1 = iconPart(root, 3, 14, 5, 5, color, 999)
        local n2 = iconPart(root, 9, 7, 5, 5, color, 999)
        local n3 = iconPart(root, 15, 14, 5, 5, color, 999)
        local l1 = iconPart(root, 6, 12, 6, 2, color, 1)
        l1.Rotation = -35
        local l2 = iconPart(root, 12, 12, 6, 2, color, 1)
        l2.Rotation = 35
    elseif key == "SYSTEM" then
        iconStrokeBox(root, 5, 5, 12, 12, color, 999, 1)
        iconPart(root, 10, 1, 2, 4, color, 1)
        iconPart(root, 10, 17, 2, 4, color, 1)
        iconPart(root, 1, 10, 4, 2, color, 1)
        iconPart(root, 17, 10, 4, 2, color, 1)
    elseif key == "KEYBINDS" then
        iconStrokeBox(root, 2, 5, 18, 12, color, 4, 1)
        for row = 0, 1 do
            for col = 0, 3 do
                iconPart(root, 5 + col * 4, 8 + row * 4, 2, 2, color, 1)
            end
        end
        iconPart(root, 7, 16, 8, 1, color, 1)
    end

    return root
end

local function createPage(key)
    local page = Instance.new("ScrollingFrame")
    page.Name = key .. "_Page"
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.fromScale(1, 1)
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Color3.fromRGB(230, 230, 230)
    page.ScrollBarImageTransparency = 0.36
    page.AutomaticCanvasSize = Enum.AutomaticSize.None
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.ZIndex = 12
    page.Parent = Content
    padding(page, 10, 10, 6, 14)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local function updateCanvas()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 22)
    end
    trackConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
    task.defer(updateCanvas)

    Pages[key] = page
    return page
end

for _, definition in ipairs(categories) do
    createPage(definition[1])
end

local function setCategory(key)
    CurrentCategory = key

    local selectedIndex = 1
    local selectedLabel = key
    for i, definition in ipairs(categories) do
        if definition[1] == key then
            selectedIndex = i
            selectedLabel = definition[2]
            break
        end
    end

    CurrentPageTitle.Text = selectedLabel
    CurrentPageHint.Text = "H3X4  /  " .. selectedLabel
    PageCount.Text = string.format("%02d / %02d", selectedIndex, #categories)

    for pageKey, page in pairs(Pages) do
        page.Visible = pageKey == key
        if pageKey == key then page.CanvasPosition = Vector2.zero end
    end

    for buttonKey, button in pairs(CategoryButtons) do
        local active = buttonKey == key
        local label = button:FindFirstChild("Label")
        local iconRoot = button:FindFirstChild("Icon")
        local buttonStroke = button:FindFirstChildOfClass("UIStroke")

        tween(button, 0.16, {
            BackgroundColor3 = active and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = active and 0.08 or 0.965,
        })
        if label then
            tween(label, 0.16, {TextColor3 = active and Color3.fromRGB(5, 5, 6) or Theme.TextDim})
        end
        if iconRoot then
            setCategoryIconColor(iconRoot, active and Color3.fromRGB(18, 18, 22) or Theme.TextMuted)
        end
        if buttonStroke then
            tween(buttonStroke, 0.16, {Transparency = active and 1 or 0.90})
        end
    end
end

for index, definition in ipairs(categories) do
    local key, labelText = definition[1], definition[2]

    local button = Instance.new("TextButton")
    button.Name = key
    button.Size = UDim2.new(1, 0, 0, 40)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.965
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.LayoutOrder = index
    button.ZIndex = 13
    button.Parent = CategoryScroll
    corner(button, 14)
    stroke(button, Color3.fromRGB(255, 255, 255), 0.92, 1)

    local iconRoot = createCategoryIcon(button, key, Theme.TextMuted)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(42, 0)
    label.Size = UDim2.new(1, -52, 1, 0)
    label.Text = labelText
    label.TextColor3 = Theme.TextDim
    label.TextSize = 9
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 14
    label.Parent = button

    button.MouseEnter:Connect(function()
        if CurrentCategory ~= key then
            tween(button, 0.14, {BackgroundTransparency = 0.94})
            tween(label, 0.14, {TextColor3 = Theme.Text})
            setCategoryIconColor(iconRoot, Theme.TextDim)
        end
    end)
    button.MouseLeave:Connect(function()
        if CurrentCategory ~= key then
            tween(button, 0.14, {BackgroundTransparency = 0.965})
            tween(label, 0.14, {TextColor3 = Theme.TextDim})
            setCategoryIconColor(iconRoot, Theme.TextMuted)
        end
    end)
    button.MouseButton1Click:Connect(function()
        setCategory(key)
    end)

    CategoryButtons[key] = button
end

-- =========================================================
-- COMPONENT FACTORY
-- IMPORTANT: cards calculate their own height explicitly so controls never
-- disappear because of AutomaticSize/AutomaticCanvasSize inconsistencies.
-- =========================================================

local function makeCard(page, titleText, subtitleText)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
    card.BackgroundTransparency = 0.46
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 60)
    card.ZIndex = 13
    card.Parent = page
    corner(card, 18)
    stroke(card, Color3.fromRGB(255, 255, 255), 0.86, 1)
    padding(card, 14, 14, 13, 14)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 9)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Text = titleText
    title.TextColor3 = Theme.Text
    title.TextSize = 11
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.LayoutOrder = 1
    title.ZIndex = 14
    title.Parent = card

    if subtitleText and subtitleText ~= "" then
        local subtitle = Instance.new("TextLabel")
        subtitle.BackgroundTransparency = 1
        subtitle.Size = UDim2.new(1, 0, 0, 0)
        subtitle.AutomaticSize = Enum.AutomaticSize.Y
        subtitle.TextWrapped = true
        subtitle.Text = subtitleText
        subtitle.TextColor3 = Theme.TextDim
        subtitle.TextSize = 9
        subtitle.Font = Enum.Font.GothamMedium
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.TextYAlignment = Enum.TextYAlignment.Top
        subtitle.LayoutOrder = 2
        subtitle.ZIndex = 14
        subtitle.Parent = card
    end

    local function updateCardHeight()
        card.Size = UDim2.new(1, 0, 0, math.max(54, layout.AbsoluteContentSize.Y + 27))
    end
    trackConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCardHeight))
    task.defer(updateCardHeight)

    return card
end

local function makeDivider(parent)
    local line = Instance.new("Frame")
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BackgroundTransparency = 0.90
    line.BorderSizePixel = 0
    line.Size = UDim2.new(1, 0, 0, 1)
    line.ZIndex = 14
    line.Parent = parent
    return line
end

local function makeButton(parent, text, callback, danger)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 42)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.93
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.ZIndex = 14
    button.Parent = parent
    corner(button, 16)
    stroke(button, danger and Theme.Danger or Color3.fromRGB(255, 255, 255), danger and 0.65 or 0.88, 1)

    local actionLabel = Instance.new("TextLabel")
    actionLabel.Name = "ActionLabel"
    actionLabel.BackgroundTransparency = 1
    actionLabel.Position = UDim2.fromOffset(14, 0)
    actionLabel.Size = UDim2.new(1, -58, 1, 0)
    actionLabel.Text = text
    actionLabel.TextColor3 = danger and Theme.Danger or Theme.Text
    actionLabel.TextSize = 9
    actionLabel.Font = Enum.Font.GothamSemibold
    actionLabel.TextXAlignment = Enum.TextXAlignment.Left
    actionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    actionLabel.ZIndex = 15
    actionLabel.Parent = button

    local actionIcon = Instance.new("TextLabel")
    actionIcon.Name = "ActionIcon"
    actionIcon.AnchorPoint = Vector2.new(1, 0.5)
    actionIcon.Position = UDim2.new(1, -8, 0.5, 0)
    actionIcon.Size = UDim2.fromOffset(28, 28)
    actionIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    actionIcon.BackgroundTransparency = danger and 0.93 or 0.08
    actionIcon.BorderSizePixel = 0
    actionIcon.Text = danger and "!" or "›"
    actionIcon.TextColor3 = danger and Theme.Danger or Color3.fromRGB(8, 8, 10)
    actionIcon.TextSize = 14
    actionIcon.Font = Enum.Font.GothamBold
    actionIcon.ZIndex = 15
    actionIcon.Parent = button
    corner(actionIcon, 14)

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = button

    button.MouseEnter:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.86})
        tween(scale, 0.14, {Scale = 1.008})
        if not danger then
            tween(actionIcon, 0.14, {BackgroundTransparency = 0})
        end
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.93})
        tween(scale, 0.14, {Scale = 1})
        if not danger then
            tween(actionIcon, 0.14, {BackgroundTransparency = 0.08})
        end
    end)

    if callback then
        button.MouseButton1Click:Connect(function()
            tween(scale, 0.07, {Scale = 0.985})
            task.delay(0.07, function()
                if scale and scale.Parent then tween(scale, 0.10, {Scale = 1}) end
            end)
            local ok, err = pcall(callback, button)
            if not ok then warn("[H3X4 OBBY] " .. tostring(err)) end
        end)
    end

    return button
end

local ToggleControllers = {}

local function makeToggle(parent, text, defaultValue, callback, settingKey)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 44)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.95
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.ZIndex = 14
    button.Parent = parent
    corner(button, 16)
    local buttonStroke = stroke(button, Color3.fromRGB(255, 255, 255), 0.90, 1)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(14, 0)
    label.Size = UDim2.new(1, -82, 1, 0)
    label.Text = text
    label.TextColor3 = Theme.Text
    label.TextSize = 9
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 15
    label.Parent = button

    local track = Instance.new("Frame")
    track.Name = "ToggleTrack"
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -10, 0.5, 0)
    track.Size = UDim2.fromOffset(48, 26)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
    track.BackgroundTransparency = 0.18
    track.BorderSizePixel = 0
    track.ZIndex = 15
    track.Parent = button
    corner(track, 13)
    stroke(track, Color3.fromRGB(255, 255, 255), 0.82, 1)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 13, 0.5, 0)
    knob.Size = UDim2.fromOffset(18, 18)
    knob.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
    knob.BorderSizePixel = 0
    knob.ZIndex = 16
    knob.Parent = track
    corner(knob, 9)

    local value = defaultValue == true
    local controller = {}

    function controller.Set(newValue, silent)
        value = newValue == true
        if settingKey then Settings[settingKey] = value end

        tween(track, 0.17, {
            BackgroundColor3 = value and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(30, 30, 34),
            BackgroundTransparency = value and 0.02 or 0.18,
        })
        tween(knob, 0.17, {
            Position = value and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 13, 0.5, 0),
            BackgroundColor3 = value and Color3.fromRGB(8, 8, 10) or Color3.fromRGB(235, 235, 235),
        })
        tween(buttonStroke, 0.17, {Transparency = value and 0.78 or 0.90})

        if not silent and callback then
            local ok, err = pcall(callback, value)
            if not ok then warn("[H3X4 OBBY] " .. tostring(err)) end
        end
    end

    function controller.Get()
        return value
    end

    controller.Button = button
    controller.Set(value, true)

    button.MouseButton1Click:Connect(function()
        controller.Set(not value, false)
    end)
    button.MouseEnter:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.89})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.95})
    end)

    if settingKey then ToggleControllers[settingKey] = controller end
    return controller
end

local SliderControllers = {}

local function makeSlider(parent, text, minValue, maxValue, defaultValue, callback, settingKey)
    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    holder.BackgroundTransparency = 0.96
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 62)
    holder.ZIndex = 14
    holder.Parent = parent
    corner(holder, 16)
    stroke(holder, Color3.fromRGB(255, 255, 255), 0.92, 1)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(14, 6)
    label.Size = UDim2.new(1, -92, 0, 20)
    label.Text = text
    label.TextColor3 = Theme.TextDim
    label.TextSize = 9
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 15
    label.Parent = holder

    local valueBox = Instance.new("TextBox")
    valueBox.AnchorPoint = Vector2.new(1, 0)
    valueBox.Position = UDim2.new(1, -10, 0, 5)
    valueBox.Size = UDim2.fromOffset(66, 24)
    valueBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    valueBox.BackgroundTransparency = 0.90
    valueBox.BorderSizePixel = 0
    valueBox.ClearTextOnFocus = false
    valueBox.TextColor3 = Theme.Text
    valueBox.TextSize = 9
    valueBox.Font = Enum.Font.GothamBold
    valueBox.Text = tostring(defaultValue)
    valueBox.ZIndex = 16
    valueBox.Parent = holder
    corner(valueBox, 12)

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(14, 41)
    bar.Size = UDim2.new(1, -28, 0, 5)
    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bar.BackgroundTransparency = 0.82
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.ZIndex = 15
    bar.Parent = holder
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.ZIndex = 16
    fill.Parent = bar
    corner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 17
    knob.Parent = bar
    corner(knob, 8)
    stroke(knob, Color3.fromRGB(0, 0, 0), 0.48, 1)

    local value = defaultValue
    local dragging = false
    local controller = {}

    function controller.Set(newValue, silent)
        newValue = tonumber(newValue) or minValue
        value = math.clamp(newValue, minValue, maxValue)
        if settingKey then Settings[settingKey] = value end

        local ratio = (value - minValue) / math.max(0.0001, maxValue - minValue)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueBox.Text = tostring(round(value, 1))

        if not silent and callback then
            local ok, err = pcall(callback, value)
            if not ok then warn("[H3X4 OBBY] " .. tostring(err)) end
        end
    end

    function controller.Get() return value end

    local function applyInput(input)
        local x = input.Position.X
        local ratio = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        controller.Set(minValue + (maxValue - minValue) * ratio, false)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            applyInput(input)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            applyInput(input)
        end
    end))
    valueBox.FocusLost:Connect(function()
        controller.Set(tonumber(valueBox.Text) or value, false)
    end)

    controller.Set(defaultValue, true)
    if settingKey then SliderControllers[settingKey] = controller end
    return controller
end

local function makeStat(parent, titleText, valueText)
    local row = Instance.new("Frame")
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 0.96
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 48)
    row.ZIndex = 14
    row.Parent = parent
    corner(row, 16)
    stroke(row, Color3.fromRGB(255, 255, 255), 0.92, 1)

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(14, 5)
    name.Size = UDim2.new(0.58, -14, 1, -10)
    name.Text = titleText
    name.TextColor3 = Theme.TextDim
    name.TextSize = 9
    name.Font = Enum.Font.GothamMedium
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 15
    name.Parent = row

    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.AnchorPoint = Vector2.new(1, 0)
    value.Position = UDim2.new(1, -14, 0, 5)
    value.Size = UDim2.new(0.42, 0, 1, -10)
    value.Text = valueText or "-"
    value.TextColor3 = Theme.Text
    value.TextSize = 11
    value.Font = Enum.Font.GothamBold
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.ZIndex = 15
    value.Parent = row

    return value
end

-- =========================================================
-- DRAG / MINIMIZE / RESPONSIVE
-- =========================================================

local draggingMain = false
local dragInput = nil
local dragStart = nil
local dragStartPosition = nil

Top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true
        dragInput = input
        dragStart = input.Position
        dragStartPosition = Main.Position
    end
end)

Top.InputEnded:Connect(function(input)
    if input == dragInput then
        draggingMain = false
        dragInput = nil
    end
end)

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if draggingMain and dragInput and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            dragStartPosition.X.Scale,
            dragStartPosition.X.Offset + delta.X,
            dragStartPosition.Y.Scale,
            dragStartPosition.Y.Offset + delta.Y
        )
    end
end))

local function usingMobileLayout()
    if Settings.DeviceProfile == "MOBILE" then return true end
    if Settings.DeviceProfile == "PC" then return false end
    return IS_MOBILE
end

local function basePanelSize()
    if usingMobileLayout() then
        return 600, 378
    end
    return 730, 466
end

local RestoreOrb = Instance.new("ImageButton")
RestoreOrb.Name = "RestoreOrb"
RestoreOrb.Visible = false
RestoreOrb.Size = UDim2.fromOffset(58, 58)
RestoreOrb.Position = UDim2.fromOffset(18, 82)
RestoreOrb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
RestoreOrb.BackgroundTransparency = 1
RestoreOrb.BorderSizePixel = 0
RestoreOrb.Image = "rbxassetid://72742584610344"
RestoreOrb.ImageColor3 = Color3.fromRGB(255, 255, 255)
RestoreOrb.ImageTransparency = 0
RestoreOrb.ScaleType = Enum.ScaleType.Fit
RestoreOrb.AutoButtonColor = false
RestoreOrb.ZIndex = 15000
RestoreOrb.Parent = ScreenGui
corner(RestoreOrb, 18)

local OrbScale = Instance.new("UIScale")
OrbScale.Scale = 1
OrbScale.Parent = RestoreOrb

RestoreOrb.MouseEnter:Connect(function()
    tween(OrbScale, 0.15, {Scale = 1.08})
    tween(RestoreOrb, 0.15, {ImageTransparency = 0.08})
end)
RestoreOrb.MouseLeave:Connect(function()
    tween(OrbScale, 0.15, {Scale = 1})
    tween(RestoreOrb, 0.15, {ImageTransparency = 0})
end)

MinimizeButton.MouseButton1Click:Connect(function()
    local tw = tween(Main, 0.24, {Size = UDim2.fromOffset(80, 50), BackgroundTransparency = 0.64}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    if tw then
        tw.Completed:Connect(function()
            Main.Visible = false
            RestoreOrb.Visible = true
        end)
    end
end)

local orbDragging = false
local orbDragInput = nil
local orbDragStart = nil
local orbStartPosition = nil
local orbSuppressClickUntil = 0

RestoreOrb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        orbDragging = true
        orbDragInput = input
        orbDragStart = input.Position
        orbStartPosition = RestoreOrb.Position
    end
end)

RestoreOrb.InputEnded:Connect(function(input)
    if input == orbDragInput then
        local moved = orbDragStart and ((input.Position - orbDragStart).Magnitude > 5)
        orbDragging = false
        orbDragInput = nil
        if moved then
            orbSuppressClickUntil = os.clock() + 0.20
        end
    end
end)

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if not orbDragging or not orbDragInput or not orbDragStart or not orbStartPosition then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - orbDragStart
    RestoreOrb.Position = UDim2.new(
        orbStartPosition.X.Scale,
        orbStartPosition.X.Offset + delta.X,
        orbStartPosition.Y.Scale,
        orbStartPosition.Y.Offset + delta.Y
    )
end))

RestoreOrb.MouseButton1Click:Connect(function()
    if os.clock() < orbSuppressClickUntil then return end
    RestoreOrb.Visible = false
    Main.Visible = true
    local _w, _h = basePanelSize()
    local targetSize = UDim2.fromOffset(_w, _h)
    Main.Size = UDim2.fromOffset(80, 50)
    Main.BackgroundTransparency = 0.64
    tween(Main, 0.28, {Size = targetSize, BackgroundTransparency = 0.44}, Enum.EasingStyle.Back)
end)

local MobileHud

local function applyDeviceMode(skipResize)
    local mobile = usingMobileLayout()
    StatusText.Text = mobile and "MOBILE" or "DESKTOP"

    -- En móvil, KEYBINDS no se muestra en la navegación.
    local keybindCategoryButton = CategoryButtons and CategoryButtons.KEYBINDS
    if keybindCategoryButton then
        keybindCategoryButton.Visible = not mobile
    end

    -- Si el usuario cambia a móvil mientras está dentro de KEYBINDS,
    -- volver a Inicio para no dejar una página oculta seleccionada.
    if mobile and CurrentCategory == "KEYBINDS" then
        setCategory("HOME")
    end

    -- Layout real por dispositivo: no es solo cambiar el tamaño del Frame.
    if mobile then
        Sidebar.Position = UDim2.fromOffset(8, 76)
        Sidebar.Size = UDim2.new(0, 146, 1, -84)
        ContentShell.Position = UDim2.fromOffset(162, 76)
        ContentShell.Size = UDim2.new(1, -170, 1, -84)
        Title.Position = UDim2.fromOffset(64, 12)
        Title.Size = UDim2.new(1, -230, 0, 24)
        Title.TextSize = 15
        Subtitle.Position = UDim2.fromOffset(64, 35)
        Subtitle.Size = UDim2.new(1, -230, 0, 14)
        Subtitle.TextSize = 7
        StatusPill.Size = UDim2.fromOffset(70, 26)
    else
        Sidebar.Position = UDim2.fromOffset(10, 80)
        Sidebar.Size = UDim2.new(0, 170, 1, -90)
        ContentShell.Position = UDim2.fromOffset(190, 80)
        ContentShell.Size = UDim2.new(1, -200, 1, -90)
        Title.Position = UDim2.fromOffset(70, 13)
        Title.Size = UDim2.new(1, -250, 0, 25)
        Title.TextSize = 17
        Subtitle.Position = UDim2.fromOffset(70, 37)
        Subtitle.Size = UDim2.new(1, -250, 0, 15)
        Subtitle.TextSize = 8
        StatusPill.Size = UDim2.fromOffset(82, 28)
    end

    if MobileHud then
        MobileHud.Visible = mobile and Settings.MobileHud
    end
    if not skipResize and Main and Main.Visible then
        local w, h = basePanelSize()
        Main.Size = UDim2.fromOffset(w, h)
    end

    if updateCategoryCanvas then
        task.defer(updateCategoryCanvas)
    end
end

local function updateResponsive()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

    local baseWidth, baseHeight = basePanelSize()

    local scaleX = (viewport.X - 12) / baseWidth
    local scaleY = (viewport.Y - 36) / baseHeight
    UIScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.62, 1)
end

if Workspace.CurrentCamera then
    trackConnection(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive))
end

trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(updateResponsive)
end))

-- =========================================================
-- FLOATING MOBILE HUD
-- =========================================================

MobileHud = Instance.new("Frame")
MobileHud.Name = "MobileHud"
MobileHud.Visible = usingMobileLayout() and Settings.MobileHud
MobileHud.BackgroundTransparency = 1
MobileHud.AnchorPoint = Vector2.new(1, 1)
MobileHud.Position = UDim2.new(1, -14, 1, -90)
MobileHud.Size = UDim2.fromOffset(180, 46)
MobileHud.ZIndex = 220
MobileHud.Parent = ScreenGui
applyDeviceMode(true)
updateResponsive()

local MobileLayout = Instance.new("UIListLayout")
MobileLayout.FillDirection = Enum.FillDirection.Horizontal
MobileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
MobileLayout.Padding = UDim.new(0, 6)
MobileLayout.Parent = MobileHud

local function mobileAction(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(58, 44)
    btn.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    btn.BackgroundTransparency = 0.34
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Theme.Text
    btn.TextSize = 8
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.ZIndex = 221
    btn.Parent = MobileHud
    corner(btn, 16)
    stroke(btn, Color3.fromRGB(255, 255, 255), 0.78, 1)

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = btn

    btn.MouseEnter:Connect(function()
        tween(btn, 0.14, {BackgroundTransparency = 0.18})
        tween(scale, 0.14, {Scale = 1.04})
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.14, {BackgroundTransparency = 0.34})
        tween(scale, 0.14, {Scale = 1})
    end)
    btn.MouseButton1Click:Connect(function()
        tween(scale, 0.07, {Scale = 0.96})
        task.delay(0.07, function()
            if scale and scale.Parent then tween(scale, 0.11, {Scale = 1}) end
        end)
        callback()
    end)
    return btn
end

-- callbacks assigned later
local MobileSave = nil
local MobileReturn = nil
local MobileRetry = nil


local function copyDiscordLink()
    local ok = copyText(DISCORD_URL)
    notify("COMUNIDAD", ok and "Link copiado al portapapeles." or ("Servidor: " .. DISCORD_URL), ok and "success" or nil)
end

CommunityHeaderButton.MouseButton1Click:Connect(copyDiscordLink)

local ModalOverlay = Instance.new("Frame")
ModalOverlay.Name = "ModalOverlay"
ModalOverlay.Visible = false
ModalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ModalOverlay.BackgroundTransparency = 0.26
ModalOverlay.BorderSizePixel = 0
ModalOverlay.Size = UDim2.fromScale(1, 1)
ModalOverlay.ZIndex = 20000
ModalOverlay.Parent = ScreenGui

local function buildModal(titleText, bodyText, height)
    local modal = Instance.new("Frame")
    modal.Visible = false
    modal.AnchorPoint = Vector2.new(0.5, 0.5)
    modal.Position = UDim2.new(0.5, 0, 0.5, 0)
    modal.Size = UDim2.fromOffset(380, height or 230)
    modal.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    modal.BackgroundTransparency = 0.12
    modal.BorderSizePixel = 0
    modal.ZIndex = 20010
    modal.Parent = ModalOverlay
    corner(modal, 18)
    stroke(modal, Color3.fromRGB(255,255,255), 0.78, 1)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(18, 16)
    title.Size = UDim2.new(1, -36, 0, 24)
    title.Text = titleText
    title.TextColor3 = Theme.Text
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 20011
    title.Parent = modal

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(18, 46)
    body.Size = UDim2.new(1, -36, 0, 70)
    body.TextWrapped = true
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.Text = bodyText
    body.TextColor3 = Theme.TextDim
    body.TextSize = 10
    body.Font = Enum.Font.GothamMedium
    body.ZIndex = 20011
    body.Parent = modal

    return modal
end

local DeviceModal = buildModal(
    "SELECCIONA TU DISPOSITIVO",
    "Selecciona el dispositivo que estés usando actualmente. La interfaz se adaptará automáticamente para que te resulte más cómoda.",
    232
)

local AutoDeviceModal = buildModal(
    "MODO AUTOMÁTICO",
    "¿Quieres que H3X4 detecte automáticamente tu dispositivo siempre, o usar la detección automática solamente esta vez?",
    238
)

local DiscordModal = buildModal(
    "ÚNETE A LA COMUNIDAD",
    "Únete a nuestro Discord para novedades, soporte y actualizaciones del proyecto H3X4 Obby.",
    230
)

local function modalButton(parent, text, position, width, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(width or 100, 38)
    btn.Position = position
    btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
    btn.BackgroundTransparency = 0.88
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Theme.Text
    btn.TextSize = 9
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.ZIndex = 20020
    btn.Parent = parent
    corner(btn, 12)
    stroke(btn, Color3.fromRGB(255,255,255), 0.84, 1)
    btn.MouseEnter:Connect(function() tween(btn, 0.14, {BackgroundTransparency = 0.80}) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.14, {BackgroundTransparency = 0.88}) end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local hideModals

local function showMainPanel()
    hideModals()
    RestoreOrb.Visible = false
    local w, h = basePanelSize()
    local targetSize = UDim2.fromOffset(w, h)
    Main.Visible = true
    Main.Size = UDim2.fromOffset(120, 70)
    Main.BackgroundTransparency = 0.40
    tween(Main, 0.38, {
        Size = targetSize,
        BackgroundTransparency = 0.44,
    }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

hideModals = function()
    ModalOverlay.Visible = false
    DeviceModal.Visible = false
    AutoDeviceModal.Visible = false
    DiscordModal.Visible = false
end

local function showDiscordModal()
    if Settings.HideDiscordPrompt then
        hideModals()
        return
    end
    ModalOverlay.Visible = true
    DeviceModal.Visible = false
    AutoDeviceModal.Visible = false
    DiscordModal.Visible = true
end

local function showDeviceModal()
    ModalOverlay.Visible = true
    DeviceModal.Visible = true
    AutoDeviceModal.Visible = false
    DiscordModal.Visible = false
end

local function showAutoDeviceModal()
    ModalOverlay.Visible = true
    DeviceModal.Visible = false
    AutoDeviceModal.Visible = true
    DiscordModal.Visible = false
end

local function finishDeviceSelection(profile, rememberAutomatic)
    Settings.DeviceProfile = profile
    if profile == "AUTO" then
        Settings.AutoDeviceAlways = rememberAutomatic == true
    else
        Settings.AutoDeviceAlways = false
    end
    persistPrefs()
    applyDeviceMode(false)
    updateResponsive()
    hideModals()
    task.delay(0.12, function()
        if Settings.HideDiscordPrompt then
            showMainPanel()
        else
            showDiscordModal()
        end
    end)
end

modalButton(DeviceModal, "PC", UDim2.fromOffset(18, 148), 104, function()
    finishDeviceSelection("PC", false)
end)

modalButton(DeviceModal, "MÓVIL", UDim2.fromOffset(138, 148), 104, function()
    finishDeviceSelection("MOBILE", false)
end)

modalButton(DeviceModal, "AUTOMÁTICO", UDim2.fromOffset(258, 148), 104, function()
    showAutoDeviceModal()
end)

modalButton(AutoDeviceModal, "SIEMPRE", UDim2.fromOffset(18, 150), 104, function()
    finishDeviceSelection("AUTO", true)
end)

modalButton(AutoDeviceModal, "SOLO ESTA VEZ", UDim2.fromOffset(138, 150), 118, function()
    finishDeviceSelection("AUTO", false)
end)

modalButton(AutoDeviceModal, "VOLVER", UDim2.fromOffset(272, 150), 90, function()
    showDeviceModal()
end)

modalButton(DiscordModal, "COPIAR LINK", UDim2.fromOffset(18, 158), 108, function()
    copyDiscordLink()
    showMainPanel()
end)

modalButton(DiscordModal, "CANCELAR", UDim2.fromOffset(136, 158), 100, function()
    showMainPanel()
end)

modalButton(DiscordModal, "NO MOSTRAR MÁS", UDim2.fromOffset(246, 158), 116, function()
    Settings.HideDiscordPrompt = true
    persistPrefs()
    showMainPanel()
end)

-- =========================================================
-- CHARACTER BINDING
-- =========================================================

local function bindCharacter(character)
    State.Character = character
    State.Humanoid = character:WaitForChild("Humanoid", 10)
    State.Root = character:WaitForChild("HumanoidRootPart", 10)
    State.Alive = true

    if State.Humanoid then
        State.OriginalJumpPower = tonumber(State.Humanoid.JumpPower) or 50
        State.Humanoid.UseJumpPower = true
        if Settings.HighJump then
            State.Humanoid.JumpPower = Settings.JumpPower
        end

        trackConnection(State.Humanoid.Died:Connect(function()
            State.Alive = false
            State.Deaths += 1

            if Settings.AutoRetry then
                local retryTarget = State.LastSafeCFrame
                if State.SelectedCheckpoint > 0 and State.Checkpoints[State.SelectedCheckpoint] then
                    retryTarget = State.Checkpoints[State.SelectedCheckpoint].CFrame
                end

                task.spawn(function()
                    task.wait(Settings.RetryDelay)
                    local newCharacter = LocalPlayer.CharacterAdded:Wait()
                    local newRoot = newCharacter:WaitForChild("HumanoidRootPart", 10)
                    newCharacter:WaitForChild("Humanoid", 10)
                    task.wait(0.12)
                    if retryTarget and newRoot and newCharacter.Parent then
                        pcall(function()
                            newCharacter:PivotTo(retryTarget)
                            newRoot.AssemblyLinearVelocity = Vector3.zero
                        end)
                    end
                end)
            end
        end))
    end

    if Settings.AutoTimer then
        State.PendingAutoTimer = true
    end

    if State.Root then
        trackConnection(State.Root.Touched:Connect(function(part)
            if not part or not part.Parent then return end
            if Settings.AutoFinish and isFinishPart(part) and State.TimerRunning then
                State.TimerElapsed = os.clock() - State.TimerStartedAt
                State.TimerRunning = false
                if not State.BestTime or State.TimerElapsed < State.BestTime then
                    State.BestTime = State.TimerElapsed
                    notify("NUEVO RÉCORD", "Tiempo: " .. formatTime(State.BestTime), "success")
                else
                    notify("META DETECTADA", "Tiempo: " .. formatTime(State.TimerElapsed), "success")
                end
            end
        end))
    end
end

if LocalPlayer.Character then
    task.spawn(bindCharacter, LocalPlayer.Character)
end

trackConnection(LocalPlayer.CharacterAdded:Connect(function(character)
    task.spawn(bindCharacter, character)
end))

-- =========================================================
-- CHECKPOINT SYSTEM
-- =========================================================

local function saveCheckpoint(auto)
    if not isAlive() then
        notify("CHECKPOINT", "No hay personaje disponible.", "warning")
        return false
    end

    local cf = State.Root.CFrame
    local entry = {
        CFrame = cf,
        CreatedAt = os.clock(),
        Auto = auto == true,
    }

    if #State.Checkpoints >= State.MaxCheckpoints then
        table.remove(State.Checkpoints, 1)
    end

    table.insert(State.Checkpoints, entry)
    State.SelectedCheckpoint = #State.Checkpoints

    if not auto then
        notify("CHECKPOINT GUARDADO", ("Slot %d guardado."):format(State.SelectedCheckpoint), "success")
    end

    return true
end

local function returnCheckpoint()
    local index = State.SelectedCheckpoint
    local checkpoint = index > 0 and State.Checkpoints[index] or nil

    if not checkpoint then
        notify("CHECKPOINT", "No tienes ningún checkpoint guardado.", "warning")
        return false
    end

    if safePivot(checkpoint.CFrame) then
        notify("CHECKPOINT", ("Volviste al slot %d."):format(index), "success")
        return true
    end

    return false
end

local function deleteCheckpoint()
    local index = State.SelectedCheckpoint
    if index <= 0 or not State.Checkpoints[index] then return end
    table.remove(State.Checkpoints, index)
    State.SelectedCheckpoint = math.clamp(index - 1, 0, #State.Checkpoints)
    notify("CHECKPOINT", "Checkpoint eliminado.", "warning")
end

local function selectPreviousCheckpoint()
    if #State.Checkpoints == 0 then
        State.SelectedCheckpoint = 0
        return
    end
    State.SelectedCheckpoint -= 1
    if State.SelectedCheckpoint < 1 then State.SelectedCheckpoint = #State.Checkpoints end
end

local function selectNextCheckpoint()
    if #State.Checkpoints == 0 then
        State.SelectedCheckpoint = 0
        return
    end
    State.SelectedCheckpoint += 1
    if State.SelectedCheckpoint > #State.Checkpoints then State.SelectedCheckpoint = 1 end
end

-- =========================================================
-- ESP / SCANNERS
-- =========================================================

local function destroyVisualMap(map)
    for object, visual in pairs(map) do
        pcall(function()
            if visual then visual:Destroy() end
        end)
        map[object] = nil
    end
end

local function addSelection(part, color, name)
    local box = Instance.new("SelectionBox")
    box.Name = name
    box.Adornee = part
    box.Color3 = color
    box.SurfaceColor3 = color
    box.SurfaceTransparency = 0.82
    box.LineThickness = 0.03
    box.Transparency = 0.08
    box.Parent = ScreenGui
    return box
end

local function scanKillBricks()
    if not Settings.KillbrickESP and not Settings.KillbrickBypass then
        destroyVisualMap(State.KillEspObjects)
        return
    end

    local seen = {}
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("BasePart") and isPotentialKillPart(object) then
            seen[object] = true

            if Settings.KillbrickESP and not State.KillEspObjects[object] then
                State.KillEspObjects[object] = addSelection(object, Theme.Danger, "H3X4_KillESP")
            end

            if Settings.KillbrickBypass and State.BypassCache[object] == nil then
                State.BypassCache[object] = object.CanTouch
                pcall(function() object.CanTouch = false end)
            end
        end
    end

    for object, visual in pairs(State.KillEspObjects) do
        if not object.Parent or not seen[object] or not Settings.KillbrickESP then
            pcall(function() visual:Destroy() end)
            State.KillEspObjects[object] = nil
        end
    end

    if not Settings.KillbrickBypass then
        for object, original in pairs(State.BypassCache) do
            if object and object.Parent then
                pcall(function() object.CanTouch = original end)
            end
            State.BypassCache[object] = nil
        end
    end
end

local function scanInvisibleParts()
    if not Settings.InvisibleESP then
        destroyVisualMap(State.InvisibleEspObjects)
        return
    end

    local seen = {}
    local created = 0
    for _, object in ipairs(Workspace:GetDescendants()) do
        if created >= 300 then break end
        if object:IsA("BasePart") and isPotentialInvisiblePart(object) then
            seen[object] = true
            if not State.InvisibleEspObjects[object] then
                State.InvisibleEspObjects[object] = addSelection(object, Theme.Accent, "H3X4_InvisibleESP")
                created += 1
            end
        end
    end

    for object, visual in pairs(State.InvisibleEspObjects) do
        if not object.Parent or not seen[object] then
            pcall(function() visual:Destroy() end)
            State.InvisibleEspObjects[object] = nil
        end
    end
end

local function scanObjectives()
    table.clear(State.ObjectiveCandidates)
    if not isAlive() then
        State.Objective = nil
        return
    end

    local rootPos = State.Root.Position
    local best = nil
    local bestDistance = math.huge

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("BasePart") and (isCheckpointPart(object) or isFinishPart(object)) then
            local distance = (object.Position - rootPos).Magnitude
            if distance <= Settings.ObjectiveScanDistance and distance > 8 then
                table.insert(State.ObjectiveCandidates, object)
                if distance < bestDistance then
                    bestDistance = distance
                    best = object
                end
            end
        end
    end

    State.Objective = best
end

-- =========================================================
-- ROUTE SYSTEM / PATH DRAWING
-- =========================================================

local RouteFolder = Instance.new("Folder")
RouteFolder.Name = "H3X4_RouteVisuals"
RouteFolder.Parent = Workspace

local RouteRecordToggleController = nil

local function clearRouteVisuals()
    for _, child in ipairs(RouteFolder:GetChildren()) do
        child:Destroy()
    end
end

local function redrawRoute()
    clearRouteVisuals()
    if not Settings.RoutePath or #State.Route < 2 then return end

    local lastNode = nil
    for index, cf in ipairs(State.Route) do
        if index % 2 == 1 or index == #State.Route then
            local node = Instance.new("Part")
            node.Name = "RouteNode"
            node.Anchored = true
            node.CanCollide = false
            node.CanQuery = false
            node.CanTouch = false
            node.Material = Enum.Material.Neon
            node.Color = Theme.Accent
            node.Transparency = 0.25
            node.Size = Vector3.new(0.35, 0.35, 0.35)
            node.Shape = Enum.PartType.Ball
            node.CFrame = cf
            node.Parent = RouteFolder

            if lastNode then
                local a0 = Instance.new("Attachment")
                a0.Parent = lastNode
                local a1 = Instance.new("Attachment")
                a1.Parent = node

                local beam = Instance.new("Beam")
                beam.Attachment0 = a0
                beam.Attachment1 = a1
                beam.FaceCamera = true
                beam.Width0 = 0.12
                beam.Width1 = 0.12
                beam.Color = ColorSequence.new(Theme.Accent)
                beam.Transparency = NumberSequence.new(0.28)
                beam.Parent = lastNode
            end

            lastNode = node
        end
    end
end

local function setRouteRecording(value)
    State.RouteRecording = value == true
    if RouteRecordToggleController and RouteRecordToggleController.Get() ~= State.RouteRecording then
        RouteRecordToggleController.Set(State.RouteRecording, true)
    end
    State.RouteLastPosition = nil
    State.RouteLastAt = 0

    if State.RouteRecording then
        table.clear(State.Route)
        clearRouteVisuals()
        notify("RUTA", "Grabación iniciada.", "success")
    else
        redrawRoute()
        notify("RUTA", ("Grabación detenida: %d puntos."):format(#State.Route), "warning")
    end
end

local function replayRoute()
    if State.RouteReplaying then
        State.RouteReplaying = false
        notify("RUTA", "Replay cancelado.", "warning")
        return
    end

    if #State.Route < 2 then
        notify("RUTA", "Primero graba una ruta.", "warning")
        return
    end

    if not isAlive() then return end

    State.RouteReplaying = true
    notify("RUTA", "Replay iniciado.", "success")

    task.spawn(function()
        for _, target in ipairs(State.Route) do
            if not State.RouteReplaying or not isAlive() then break end

            local current = State.Root.Position
            local distance = (target.Position - current).Magnitude
            local duration = math.clamp(distance / math.max(1, Settings.RouteReplaySpeed), 0.02, 0.4)

            local start = State.Root.CFrame
            local started = os.clock()
            while State.RouteReplaying and isAlive() and os.clock() - started < duration do
                local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
                pcall(function()
                    State.Root.CFrame = start:Lerp(target, alpha)
                    State.Root.AssemblyLinearVelocity = Vector3.zero
                end)
                RunService.Heartbeat:Wait()
            end
        end

        State.RouteReplaying = false
        notify("RUTA", "Replay terminado.", "success")
    end)
end

-- =========================================================
-- TIMER
-- =========================================================

local TimerLabels = {
    Current = {},
    Best = {},
    Deaths = {},
    Route = {},
    Checkpoint = {},
}

local function startTimer(reset)
    if reset then
        State.TimerElapsed = 0
        State.Splits = {}
    end
    if State.TimerRunning then return end
    State.TimerRunning = true
    State.TimerStartedAt = os.clock() - State.TimerElapsed
    notify("TIMER", "Cronómetro iniciado.", "success")
end

local function stopTimer()
    if not State.TimerRunning then return end
    State.TimerElapsed = os.clock() - State.TimerStartedAt
    State.TimerRunning = false
    notify("TIMER", "Cronómetro detenido en " .. formatTime(State.TimerElapsed), "warning")
end

local function toggleTimer()
    if State.TimerRunning then stopTimer() else startTimer(false) end
end

local function resetTimer()
    State.TimerRunning = false
    State.TimerElapsed = 0
    State.Splits = {}
    notify("TIMER", "Cronómetro reiniciado.")
end

local function addSplit()
    local current = State.TimerRunning and (os.clock() - State.TimerStartedAt) or State.TimerElapsed
    table.insert(State.Splits, current)
    notify("SPLIT", ("Split %d • %s"):format(#State.Splits, formatTime(current)), "success")
end

-- =========================================================
-- MOVEMENT / SAFETY LOOP
-- =========================================================

local lastKillScan = 0
local lastInvisibleScan = 0
local lastObjectiveScan = 0
local lastEdgeJump = 0

local function updateSafePosition(now)
    if not isAlive() or not isGrounded() then return end
    if State.Humanoid:GetState() == Enum.HumanoidStateType.Dead then return end
    if now - State.LastSafeAt < 0.35 then return end

    local hit = raycast(State.Root.Position, Vector3.new(0, -7, 0))
    if hit and hit.Instance and not isPotentialKillPart(hit.Instance) then
        State.LastSafeCFrame = State.Root.CFrame
        State.LastSafeAt = now
    end
end

local function updateAutoCheckpoint(now)
    if not Settings.AutoCheckpoint or not isAlive() or not isGrounded() then return end
    if now - State.AutoCheckpointLastAt < Settings.AutoCheckpointInterval then return end

    local current = State.Root.CFrame
    local last = State.AutoCheckpointLastCFrame
    if not last or (current.Position - last.Position).Magnitude >= Settings.AutoCheckpointDistance then
        saveCheckpoint(true)
        State.AutoCheckpointLastCFrame = current
        State.AutoCheckpointLastAt = now
    end
end

local function updateAntiVoid()
    if not Settings.AntiVoid or not isAlive() or not State.LastSafeCFrame then return end

    local currentY = State.Root.Position.Y
    local safeY = State.LastSafeCFrame.Position.Y

    if currentY < safeY - Settings.VoidDropDistance then
        safePivot(State.LastSafeCFrame)
        notify("ANTI VOID", "Caída detectada. Posición restaurada.", "warning")
    end
end

local function updateEdgeAssist(now)
    if not Settings.EdgeAssist or not isAlive() then return end
    if now - lastEdgeJump < 0.32 then return end
    if not isGrounded() then return end

    local moveDirection = State.Humanoid.MoveDirection
    if moveDirection.Magnitude < 0.15 then return end

    local origin = State.Root.Position + moveDirection.Unit * Settings.EdgeAssistDistance + Vector3.new(0, 1.5, 0)
    local floorAhead = raycast(origin, Vector3.new(0, -6, 0))

    if not floorAhead then
        lastEdgeJump = now
        pcall(function()
            State.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

local function updateLadderAssist()
    if not Settings.LadderAssist or not isAlive() then return end
    if State.Humanoid:GetState() == Enum.HumanoidStateType.Climbing then
        local velocity = State.Root.AssemblyLinearVelocity
        State.Root.AssemblyLinearVelocity = Vector3.new(
            velocity.X,
            math.max(velocity.Y, Settings.LadderSpeed),
            velocity.Z
        )
    end
end

local function updateRouteRecording(now)
    if not State.RouteRecording or not isAlive() then return end
    if now - State.RouteLastAt < Settings.RouteRecordInterval then return end

    local position = State.Root.Position
    if not State.RouteLastPosition or (position - State.RouteLastPosition).Magnitude >= Settings.RouteRecordDistance then
        table.insert(State.Route, State.Root.CFrame)
        State.RouteLastPosition = position
        State.RouteLastAt = now

        if #State.Route > 2500 then
            State.RouteRecording = false
            notify("RUTA", "Se alcanzó el límite de 2500 puntos.", "warning")
            redrawRoute()
        end
    end
end

trackConnection(UserInputService.JumpRequest:Connect(function()
    if not isAlive() then return end

    if Settings.HighJump then
        State.Humanoid.UseJumpPower = true
        State.Humanoid.JumpPower = Settings.JumpPower
    end

    if Settings.LongJump then
        local look = getHorizontalLook()
        local current = State.Root.AssemblyLinearVelocity
        State.Root.AssemblyLinearVelocity = Vector3.new(
            look.X * Settings.LongJumpPower,
            math.max(current.Y, Settings.HighJump and Settings.JumpPower * 0.58 or 32),
            look.Z * Settings.LongJumpPower
        )
    end
end))

local MainLoop = RunService.Heartbeat:Connect(function()
    if State.Destroyed then return end

    local now = os.clock()

    updateSafePosition(now)
    updateAutoCheckpoint(now)
    updateAntiVoid()
    updateEdgeAssist(now)
    updateLadderAssist()
    updateRouteRecording(now)

    if isAlive() and Settings.HighJump then
        if State.Humanoid.JumpPower ~= Settings.JumpPower then
            State.Humanoid.UseJumpPower = true
            State.Humanoid.JumpPower = Settings.JumpPower
        end
    end

    if now - lastKillScan >= 1.5 then
        lastKillScan = now
        if Settings.KillbrickESP or Settings.KillbrickBypass then
            task.spawn(scanKillBricks)
        end
    end

    if now - lastInvisibleScan >= 2.2 then
        lastInvisibleScan = now
        if Settings.InvisibleESP then
            task.spawn(scanInvisibleParts)
        end
    end

    if now - lastObjectiveScan >= 2 then
        lastObjectiveScan = now
        if Settings.ObjectivePointer then
            task.spawn(scanObjectives)
        else
            State.Objective = nil
        end
    end
end)
table.insert(State.Connections, MainLoop)

-- =========================================================
-- OBJECTIVE POINTER
-- =========================================================

local ObjectiveArrow = Instance.new("TextLabel")
ObjectiveArrow.Visible = false
ObjectiveArrow.AnchorPoint = Vector2.new(0.5, 0.5)
ObjectiveArrow.Size = UDim2.fromOffset(120, 44)
ObjectiveArrow.BackgroundColor3 = Theme.BG
ObjectiveArrow.BackgroundTransparency = 0.22
ObjectiveArrow.BorderSizePixel = 0
ObjectiveArrow.Text = "▲"
ObjectiveArrow.TextColor3 = Theme.Accent
ObjectiveArrow.TextSize = 22
ObjectiveArrow.Font = Enum.Font.GothamBlack
ObjectiveArrow.ZIndex = 180
ObjectiveArrow.Parent = ScreenGui
corner(ObjectiveArrow, 12)
stroke(ObjectiveArrow, Theme.Accent, 0.55, 1)

local ObjectiveDistance = Instance.new("TextLabel")
ObjectiveDistance.BackgroundTransparency = 1
ObjectiveDistance.Position = UDim2.new(0, 0, 1, -16)
ObjectiveDistance.Size = UDim2.new(1, 0, 0, 14)
ObjectiveDistance.Text = ""
ObjectiveDistance.TextColor3 = Theme.Text
ObjectiveDistance.TextSize = 8
ObjectiveDistance.Font = Enum.Font.GothamBold
ObjectiveDistance.ZIndex = 181
ObjectiveDistance.Parent = ObjectiveArrow

local RenderLoop = RunService.RenderStepped:Connect(function()
    if State.Destroyed then return end

    local currentElapsed = State.TimerRunning and (os.clock() - State.TimerStartedAt) or State.TimerElapsed

    for _, label in ipairs(TimerLabels.Current) do
        if label and label.Parent then label.Text = formatTime(currentElapsed) end
    end
    for _, label in ipairs(TimerLabels.Best) do
        if label and label.Parent then label.Text = State.BestTime and formatTime(State.BestTime) or "--:--.--" end
    end
    for _, label in ipairs(TimerLabels.Deaths) do
        if label and label.Parent then label.Text = tostring(State.Deaths) end
    end
    for _, label in ipairs(TimerLabels.Route) do
        if label and label.Parent then label.Text = tostring(#State.Route) .. " pts" end
    end
    for _, label in ipairs(TimerLabels.Checkpoint) do
        if label and label.Parent then
            label.Text = #State.Checkpoints > 0
                and ("%d / %d"):format(State.SelectedCheckpoint, #State.Checkpoints)
                or "0 / 0"
        end
    end

    if Settings.ObjectivePointer and State.Objective and State.Objective.Parent and isAlive() then
        local camera = Workspace.CurrentCamera
        if camera then
            local screenPosition, onScreen = camera:WorldToViewportPoint(State.Objective.Position)
            local viewport = camera.ViewportSize
            local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
            local target2D = Vector2.new(screenPosition.X, screenPosition.Y)

            if onScreen and screenPosition.Z > 0 then
                ObjectiveArrow.Position = UDim2.fromOffset(
                    math.clamp(screenPosition.X, 70, viewport.X - 70),
                    math.clamp(screenPosition.Y - 55, 70, viewport.Y - 70)
                )
                ObjectiveArrow.Rotation = 0
            else
                local direction = target2D - center
                if screenPosition.Z < 0 then direction = -direction end
                if direction.Magnitude < 1 then direction = Vector2.new(0, -1) end
                direction = direction.Unit

                local radiusX = math.max(50, viewport.X / 2 - 80)
                local radiusY = math.max(50, viewport.Y / 2 - 80)
                local position = center + Vector2.new(direction.X * radiusX, direction.Y * radiusY)

                ObjectiveArrow.Position = UDim2.fromOffset(position.X, position.Y)
                ObjectiveArrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
            end

            ObjectiveDistance.Text = ("%d studs"):format(math.floor((State.Objective.Position - State.Root.Position).Magnitude))
            ObjectiveArrow.Visible = true
        end
    else
        ObjectiveArrow.Visible = false
    end
end)
table.insert(State.RenderConnections, RenderLoop)

-- =========================================================
-- UI CONTENT
-- =========================================================

-- HOME
do
    local page = Pages.HOME

    local card = makeCard(page, "H3X4 OBBY", "Hub separado para obbies, parkour y speedruns. Las funciones genéricas intentan adaptarse a distintos juegos.")
    makeButton(card, "GUARDAR CHECKPOINT RÁPIDO", function()
        saveCheckpoint(false)
    end)
    makeButton(card, "VOLVER AL CHECKPOINT", returnCheckpoint)
    makeButton(card, "INICIAR / DETENER TIMER", toggleTimer)

    local stats = makeCard(page, "ESTADO DE SESIÓN")
    table.insert(TimerLabels.Current, makeStat(stats, "TIEMPO ACTUAL", "00:00.00"))
    table.insert(TimerLabels.Best, makeStat(stats, "MEJOR TIEMPO", "--:--.--"))
    table.insert(TimerLabels.Deaths, makeStat(stats, "MUERTES", "0"))
    table.insert(TimerLabels.Checkpoint, makeStat(stats, "CHECKPOINT", "0 / 0"))
    table.insert(TimerLabels.Route, makeStat(stats, "RUTA", "0 pts"))

    local community = makeCard(page, "UNIRSE AL DISCORD", "Únete al Discord oficial de la comunidad H3X4 para novedades, soporte y actualizaciones.")
    makeButton(community, "COPIAR LINK DEL DISCORD", function()
        copyDiscordLink()
    end)
    makeButton(community, "MOSTRAR PANEL DE DISCORD", function()
        showDiscordModal()
    end)

    local device = makeCard(page, "DISPOSITIVO", "Elige el dispositivo para adaptar el panel automáticamente y hacerlo más cómodo.")
    makeButton(device, "USAR MODO PC", function()
        Settings.AutoDeviceAlways = false
        finishDeviceSelection("PC", false)
        notify("DISPOSITIVO", "Modo PC aplicado.", "success")
    end)
    makeButton(device, "USAR MODO MÓVIL", function()
        Settings.AutoDeviceAlways = false
        finishDeviceSelection("MOBILE", false)
        notify("DISPOSITIVO", "Modo móvil aplicado.", "success")
    end)
    makeButton(device, "USAR MODO AUTOMÁTICO", function()
        showAutoDeviceModal()
    end)

    local help = makeCard(page, "NOTA", "Los detectores de killbricks, checkpoints y metas usan nombres/propiedades comunes. Algunos juegos pueden necesitar módulos específicos.")
end

-- CHECKPOINTS
local SelectedCheckpointLabel = nil
do
    local page = Pages.CHECKPOINTS

    local card = makeCard(page, "CHECKPOINTS MANUALES", "Hasta 12 checkpoints guardados durante la sesión.")
    SelectedCheckpointLabel = makeStat(card, "SELECCIONADO", "NINGUNO")

    makeButton(card, "GUARDAR NUEVO CHECKPOINT", function()
        saveCheckpoint(false)
    end)

    local nav = Instance.new("Frame")
    nav.BackgroundTransparency = 1
    nav.Size = UDim2.new(1, 0, 0, 36)
    nav.ZIndex = 14
    nav.Parent = card

    local previous = Instance.new("TextButton")
    previous.Size = UDim2.new(0.5, -4, 1, 0)
    previous.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    previous.BackgroundTransparency = 0.93
    previous.BorderSizePixel = 0
    previous.Text = "‹   ANTERIOR"
    previous.TextColor3 = Theme.Text
    previous.TextSize = 9
    previous.Font = Enum.Font.GothamSemibold
    previous.ZIndex = 15
    previous.AutoButtonColor = false
    previous.Parent = nav
    corner(previous, 15)
    stroke(previous, Color3.fromRGB(255, 255, 255), 0.88, 1)

    local nextButton = previous:Clone()
    nextButton.Position = UDim2.new(0.5, 4, 0, 0)
    nextButton.Text = "SIGUIENTE   ›"
    nextButton.Parent = nav

    local function navHover(button)
        button.MouseEnter:Connect(function()
            tween(button, 0.14, {BackgroundTransparency = 0.84})
        end)
        button.MouseLeave:Connect(function()
            tween(button, 0.14, {BackgroundTransparency = 0.93})
        end)
    end
    navHover(previous)
    navHover(nextButton)

    previous.MouseButton1Click:Connect(selectPreviousCheckpoint)
    nextButton.MouseButton1Click:Connect(selectNextCheckpoint)

    makeButton(card, "VOLVER AL SELECCIONADO", returnCheckpoint)
    makeButton(card, "ELIMINAR SELECCIONADO", deleteCheckpoint, true)

    local autoCard = makeCard(page, "AUTO CHECKPOINT", "Guarda una nueva posición segura al avanzar cierta distancia.")
    makeToggle(autoCard, "AUTO CHECKPOINT", Settings.AutoCheckpoint, nil, "AutoCheckpoint")
    makeSlider(autoCard, "DISTANCIA ENTRE CHECKPOINTS", 10, 150, Settings.AutoCheckpointDistance, nil, "AutoCheckpointDistance")
    makeSlider(autoCard, "INTERVALO MÍNIMO (s)", 0.5, 10, Settings.AutoCheckpointInterval, nil, "AutoCheckpointInterval")
end

-- MOVEMENT
do
    local page = Pages.MOVEMENT

    local jumpCard = makeCard(page, "SALTO Y PARKOUR")
    makeToggle(jumpCard, "SALTO ALTO", Settings.HighJump, function(value)
        if isAlive() then
            State.Humanoid.UseJumpPower = true
            State.Humanoid.JumpPower = value and Settings.JumpPower or State.OriginalJumpPower
        end
    end, "HighJump")
    makeSlider(jumpCard, "POTENCIA DE SALTO", 50, 220, Settings.JumpPower, function(value)
        if Settings.HighJump and isAlive() then
            State.Humanoid.JumpPower = value
        end
    end, "JumpPower")

    makeToggle(jumpCard, "LONG JUMP", Settings.LongJump, nil, "LongJump")
    makeSlider(jumpCard, "IMPULSO DE LONG JUMP", 15, 120, Settings.LongJumpPower, nil, "LongJumpPower")

    local assist = makeCard(page, "ASISTENCIA")
    makeToggle(assist, "EDGE ASSIST", Settings.EdgeAssist, nil, "EdgeAssist")
    makeSlider(assist, "DISTANCIA DE DETECCIÓN DEL BORDE", 1.5, 8, Settings.EdgeAssistDistance, nil, "EdgeAssistDistance")
    makeToggle(assist, "LADDER ASSIST", Settings.LadderAssist, nil, "LadderAssist")
    makeSlider(assist, "VELOCIDAD DE ESCALADA", 16, 100, Settings.LadderSpeed, nil, "LadderSpeed")
end

-- SAFETY
do
    local page = Pages.SAFETY

    local safety = makeCard(page, "RECUPERACIÓN")
    makeToggle(safety, "ANTI VOID", Settings.AntiVoid, nil, "AntiVoid")
    makeSlider(safety, "DISTANCIA DE CAÍDA", 20, 180, Settings.VoidDropDistance, nil, "VoidDropDistance")
    makeToggle(safety, "AUTO RETRY AL MORIR", Settings.AutoRetry, nil, "AutoRetry")
    makeSlider(safety, "RETRASO DEL RETRY (s)", 0, 3, Settings.RetryDelay, nil, "RetryDelay")

    makeButton(safety, "VOLVER A ÚLTIMA POSICIÓN SEGURA", function()
        if State.LastSafeCFrame then
            safePivot(State.LastSafeCFrame)
        else
            notify("POSICIÓN SEGURA", "Todavía no se ha detectado una posición segura.", "warning")
        end
    end)

    local hazards = makeCard(page, "OBSTÁCULOS")
    makeToggle(hazards, "BYPASS LOCAL DE KILLBRICKS", Settings.KillbrickBypass, function()
        task.spawn(scanKillBricks)
    end, "KillbrickBypass")
end

-- VISUALS
do
    local page = Pages.VISUALS

    local visual = makeCard(page, "DETECTORES VISUALES")
    makeToggle(visual, "KILLBRICK ESP", Settings.KillbrickESP, function()
        task.spawn(scanKillBricks)
    end, "KillbrickESP")
    makeToggle(visual, "INVISIBLE PART ESP", Settings.InvisibleESP, function(value)
        if value then task.spawn(scanInvisibleParts) else destroyVisualMap(State.InvisibleEspObjects) end
    end, "InvisibleESP")
    makeToggle(visual, "INDICADOR DE OBJETIVO", Settings.ObjectivePointer, function(value)
        if value then task.spawn(scanObjectives) else State.Objective = nil end
    end, "ObjectivePointer")
    makeSlider(visual, "RANGO DEL SCANNER", 100, 2000, Settings.ObjectiveScanDistance, nil, "ObjectiveScanDistance")

    local info = makeCard(page, "QUÉ BUSCA", "Killbrick ESP intenta detectar nombres como kill, lava, death, hazard, damage, acid, laser o spike. El indicador busca checkpoints, spawns y metas por nombres comunes.")
end

-- SPEEDRUN
do
    local page = Pages.SPEEDRUN

    local timerCard = makeCard(page, "CRONÓMETRO")
    table.insert(TimerLabels.Current, makeStat(timerCard, "TIEMPO", "00:00.00"))
    table.insert(TimerLabels.Best, makeStat(timerCard, "RÉCORD", "--:--.--"))
    table.insert(TimerLabels.Deaths, makeStat(timerCard, "MUERTES", "0"))

    makeButton(timerCard, "INICIAR / DETENER", toggleTimer)
    makeButton(timerCard, "NUEVO INTENTO", function()
        startTimer(true)
    end)
    makeButton(timerCard, "AÑADIR SPLIT", addSplit)
    makeButton(timerCard, "REINICIAR TIMER", resetTimer, true)

    local auto = makeCard(page, "AUTOMATIZACIÓN DE SPEEDRUN")
    makeToggle(auto, "DETECTAR META AUTOMÁTICAMENTE", Settings.AutoFinish, nil, "AutoFinish")
    makeToggle(auto, "AUTO TIMER AL RESPAWN", Settings.AutoTimer, nil, "AutoTimer")
end

-- ROUTES
do
    local page = Pages.ROUTES

    local route = makeCard(page, "ROUTE RECORDER", "Graba tu recorrido usando posiciones locales. Puedes visualizarlo y reproducirlo.")
    local recordToggle = makeToggle(route, "GRABAR RUTA", State.RouteRecording, function(value)
        setRouteRecording(value)
    end)
    RouteRecordToggleController = recordToggle

    makeToggle(route, "MOSTRAR CAMINO GRABADO", Settings.RoutePath, function(value)
        if value then redrawRoute() else clearRouteVisuals() end
    end, "RoutePath")
    makeSlider(route, "DISTANCIA ENTRE PUNTOS", 1, 12, Settings.RouteRecordDistance, nil, "RouteRecordDistance")
    makeSlider(route, "VELOCIDAD DE REPLAY", 8, 120, Settings.RouteReplaySpeed, nil, "RouteReplaySpeed")

    makeButton(route, "REPRODUCIR / CANCELAR RUTA", replayRoute)
    makeButton(route, "BORRAR RUTA", function()
        State.RouteReplaying = false
        State.RouteRecording = false
        recordToggle.Set(false, true)
        table.clear(State.Route)
        clearRouteVisuals()
        notify("RUTA", "Ruta eliminada.", "warning")
    end, true)
end

-- SYSTEM
local MobileHudToggle = nil
do
    local page = Pages.SYSTEM

    local config = makeCard(page, "CONFIGURACIÓN")
    makeButton(config, "GUARDAR CONFIGURACIÓN", function()
        if type(writefile) ~= "function" then
            notify("CONFIGURACIÓN", "Tu executor no permite writefile.", "warning")
            return
        end

        local payload = {
            version = 1,
            settings = Settings,
            keybinds = {},
            bestTime = State.BestTime,
        }

        for name, key in pairs(Keybinds) do
            payload.keybinds[name] = key.Name
        end

        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(payload)
        end)

        if ok then
            local wrote = pcall(function()
                writefile(CONFIG_FILE, encoded)
            end)
            notify("CONFIGURACIÓN", wrote and "Guardada correctamente." or "No se pudo guardar.", wrote and "success" or "danger")
        end
    end)

    makeButton(config, "CARGAR CONFIGURACIÓN", function()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then
            notify("CONFIGURACIÓN", "Tu executor no permite leer archivos.", "warning")
            return
        end

        if not isfile(CONFIG_FILE) then
            notify("CONFIGURACIÓN", "No existe una configuración guardada.", "warning")
            return
        end

        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)

        if not ok or type(data) ~= "table" then
            notify("CONFIGURACIÓN", "Archivo inválido.", "danger")
            return
        end

        if type(data.settings) == "table" then
            for key, value in pairs(data.settings) do
                if Settings[key] ~= nil then
                    Settings[key] = value
                    if ToggleControllers[key] then ToggleControllers[key].Set(value, true) end
                    if SliderControllers[key] then SliderControllers[key].Set(value, true) end
                end
            end
        end

        if type(data.keybinds) == "table" then
            for name, keyName in pairs(data.keybinds) do
                local enum = Enum.KeyCode[keyName]
                if enum then Keybinds[name] = enum end
            end
        end

        State.BestTime = tonumber(data.bestTime) or State.BestTime

        MobileHud.Visible = usingMobileLayout() and Settings.MobileHud
        task.spawn(scanKillBricks)
        task.spawn(scanInvisibleParts)
        if Settings.ObjectivePointer then task.spawn(scanObjectives) end
        if Settings.RoutePath then redrawRoute() else clearRouteVisuals() end

        notify("CONFIGURACIÓN", "Configuración cargada.", "success")
    end)

    local mobile = makeCard(page, "DISPOSITIVO Y HUD")
    MobileHudToggle = makeToggle(mobile, "HUD FLOTANTE", Settings.MobileHud, function(value)
        Settings.MobileHud = value
        MobileHud.Visible = value and usingMobileLayout()
    end, "MobileHud")
    makeButton(mobile, "MODO PC", function()
        finishDeviceSelection("PC", false)
    end)
    makeButton(mobile, "MODO MÓVIL", function()
        finishDeviceSelection("MOBILE", false)
    end)
    makeButton(mobile, "MODO AUTOMÁTICO", function()
        showAutoDeviceModal()
    end)

    local communitySystem = makeCard(page, "UNIRSE AL DISCORD")
    makeButton(communitySystem, "COPIAR LINK DEL DISCORD", copyDiscordLink)
    makeButton(communitySystem, "MOSTRAR AVISO DE DISCORD", showDiscordModal)

    local cleanup = makeCard(page, "PANEL")
    makeButton(cleanup, "RESTAURAR POSICIÓN DEL PANEL", function()
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    end)
end

-- KEYBINDS
local KeybindButtons = {}
do
    local page = Pages.KEYBINDS
    local keyCard = makeCard(page, "ATAJOS", "Pulsa un botón y después la nueva tecla. ESC cancela.")

    local names = {
        {"ToggleUI", "MOSTRAR / OCULTAR PANEL"},
        {"SaveCheckpoint", "GUARDAR CHECKPOINT"},
        {"ReturnCheckpoint", "VOLVER AL CHECKPOINT"},
        {"AntiVoid", "TOGGLE ANTI VOID"},
        {"StartStopTimer", "INICIAR / DETENER TIMER"},
        {"RouteRecord", "GRABAR RUTA"},
    }

    local capturing = nil
    local capturingButton = nil

    local function setActionButtonLabel(button, value)
        if not button then return end
        local visualLabel = button:FindFirstChild("ActionLabel")
        if visualLabel then
            visualLabel.Text = string.upper(value)
        else
            button.Text = value
        end
    end

    local function refreshKeyButton(name)
        local button = KeybindButtons[name]
        if not button then return end
        local key = Keybinds[name]
        setActionButtonLabel(button, button:GetAttribute("BaseLabel") .. "  •  " .. (key and key.Name or "SIN TECLA"))
    end

    for _, item in ipairs(names) do
        local name, label = item[1], item[2]
        local button
        button = makeButton(keyCard, label .. "  •  " .. Keybinds[name].Name, function()
            capturing = name
            capturingButton = button
            ActiveKeybindCapture = name
            setActionButtonLabel(button, label .. "  •  PRESIONA UNA TECLA...")
            notify("KEYBIND", "Presiona una tecla para asignarla. ESC cancela.")
        end)
        button:SetAttribute("BaseLabel", label)
        KeybindButtons[name] = button
    end

    trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if not capturing then return end

        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if input.KeyCode == Enum.KeyCode.Escape then
            refreshKeyButton(capturing)
            capturing = nil
            capturingButton = nil
            ActiveKeybindCapture = nil
            return
        end

        if input.KeyCode ~= Enum.KeyCode.Unknown then
            Keybinds[capturing] = input.KeyCode
            refreshKeyButton(capturing)
            notify("KEYBIND", "Atajo actualizado a " .. input.KeyCode.Name .. ".", "success")
            capturing = nil
            capturingButton = nil
            ActiveKeybindCapture = nil
        end
    end))

    task.spawn(function()
        while not State.Destroyed do
            task.wait(0.75)
            if not capturing then
                for name in pairs(KeybindButtons) do
                    refreshKeyButton(name)
                end
            end
        end
    end)
end

-- =========================================================
-- MOBILE ACTIONS
-- =========================================================

MobileSave = mobileAction("SAVE", function()
    saveCheckpoint(false)
end)

MobileReturn = mobileAction("BACK", function()
    returnCheckpoint()
end)

MobileRetry = mobileAction("SAFE", function()
    if State.LastSafeCFrame then
        safePivot(State.LastSafeCFrame)
    end
end)

-- =========================================================
-- UI REFRESH LOOP
-- =========================================================

task.spawn(function()
    while not State.Destroyed do
        task.wait(0.15)

        if SelectedCheckpointLabel then
            if #State.Checkpoints == 0 then
                SelectedCheckpointLabel.Text = "NINGUNO"
            else
                SelectedCheckpointLabel.Text = ("%d / %d"):format(State.SelectedCheckpoint, #State.Checkpoints)
            end
        end

        if State.PendingAutoTimer and Settings.AutoTimer and isAlive() then
            State.PendingAutoTimer = false
            startTimer(true)
        elseif State.PendingAutoTimer and not Settings.AutoTimer then
            State.PendingAutoTimer = false
        end
    end
end)

-- =========================================================
-- GLOBAL KEYBINDS
-- =========================================================

local function keyEquals(input, key)
    return input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == key
end

trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if ActiveKeybindCapture then return end
    if gpe then return end

    if keyEquals(input, Keybinds.ToggleUI) then
        if Main.Visible then
            Main.Visible = false
            RestoreOrb.Visible = true
        else
            RestoreOrb.Visible = false
            Main.Visible = true
        end
        return
    end

    if keyEquals(input, Keybinds.SaveCheckpoint) then
        saveCheckpoint(false)
        return
    end

    if keyEquals(input, Keybinds.ReturnCheckpoint) then
        returnCheckpoint()
        return
    end

    if keyEquals(input, Keybinds.AntiVoid) then
        Settings.AntiVoid = not Settings.AntiVoid
        if ToggleControllers.AntiVoid then
            ToggleControllers.AntiVoid.Set(Settings.AntiVoid, true)
        end
        notify("ANTI VOID", Settings.AntiVoid and "Activado." or "Desactivado.")
        return
    end

    if keyEquals(input, Keybinds.StartStopTimer) then
        toggleTimer()
        return
    end

    if keyEquals(input, Keybinds.RouteRecord) then
        setRouteRecording(not State.RouteRecording)
        return
    end
end))

-- =========================================================
-- CLEANUP
-- =========================================================

local function cleanup()
    if State.Destroyed then return end
    State.Destroyed = true
    State.RouteRecording = false
    State.RouteReplaying = false

    if isAlive() and Settings.HighJump then
        pcall(function()
            State.Humanoid.JumpPower = State.OriginalJumpPower
        end)
    end

    destroyVisualMap(State.KillEspObjects)
    destroyVisualMap(State.InvisibleEspObjects)

    for object, original in pairs(State.BypassCache) do
        if object and object.Parent then
            pcall(function() object.CanTouch = original end)
        end
    end
    table.clear(State.BypassCache)

    clearRouteVisuals()
    if RouteFolder then RouteFolder:Destroy() end

    disconnectAll()

    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
end

CloseButton.MouseButton1Click:Connect(function()
    cleanup()
end)

-- =========================================================
-- STARTUP FLOW
-- =========================================================

setCategory("HOME")
notify("H3X4 OBBY", "Interfaz Monochrome Glass cargada. Categorías completas y layout fijo.", "success")

task.delay(0.35, function()
    Main.Visible = false
    RestoreOrb.Visible = false
    if Settings.AutoDeviceAlways then
        Settings.DeviceProfile = "AUTO"
        applyDeviceMode(false)
        updateResponsive()
        if Settings.HideDiscordPrompt then
            showMainPanel()
        else
            showDiscordModal()
        end
    else
        showDeviceModal()
    end
end)

print("[H3X4 OBBY] Device Flow V10 cargada.")
