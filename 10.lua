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
    BG = Color3.fromRGB(2, 4, 7),
    Panel = Color3.fromRGB(6, 10, 14),
    Panel2 = Color3.fromRGB(9, 15, 20),
    Panel3 = Color3.fromRGB(14, 22, 28),
    Card = Color3.fromRGB(7, 12, 17),
    CardHover = Color3.fromRGB(13, 28, 34),
    Accent = Color3.fromRGB(0, 239, 255),
    Accent2 = Color3.fromRGB(255, 36, 176),
    AccentDark = Color3.fromRGB(4, 48, 57),
    AccentSoft = Color3.fromRGB(29, 119, 129),
    Text = Color3.fromRGB(239, 252, 255),
    TextDim = Color3.fromRGB(147, 183, 190),
    TextMuted = Color3.fromRGB(79, 112, 120),
    Border = Color3.fromRGB(28, 91, 101),
    Danger = Color3.fromRGB(255, 61, 126),
    Warning = Color3.fromRGB(255, 214, 74),
    Success = Color3.fromRGB(74, 255, 174),
    ToggleOff = Color3.fromRGB(17, 31, 37),
}
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local CONFIG_FILE = ("H3X4_OBBY_%d.json"):format(LocalPlayer.UserId)

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
}

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
ScreenGui.DisplayOrder = 2147480000
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

local NotificationHolder = Instance.new("Frame")
NotificationHolder.Name = "Notifications"
NotificationHolder.BackgroundTransparency = 1
NotificationHolder.AnchorPoint = Vector2.new(1, 0)
NotificationHolder.Position = UDim2.new(1, -14, 0, 14)
NotificationHolder.Size = UDim2.fromOffset(330, 250)
NotificationHolder.ZIndex = 300
NotificationHolder.Parent = ScreenGui

local NotificationLayout = Instance.new("UIListLayout")
NotificationLayout.Padding = UDim.new(0, 8)
NotificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Top
NotificationLayout.Parent = NotificationHolder

local function notify(title, text, kind)
    if State.Destroyed then return end

    local dotColor = Theme.Accent
    if kind == "success" then dotColor = Theme.Success end
    if kind == "danger" then dotColor = Theme.Danger end
    if kind == "warning" then dotColor = Theme.Warning end

    local card = Instance.new("Frame")
    card.BackgroundColor3 = Theme.Panel
    card.BackgroundTransparency = 0.12
    card.BorderSizePixel = 0
    card.Size = UDim2.fromOffset(316, 0)
    card.ClipsDescendants = true
    card.ZIndex = 301
    card.Parent = NotificationHolder
    corner(card, 14)
    stroke(card, Theme.Border, 0.1, 1)

    local dot = Instance.new("Frame")
    dot.BackgroundColor3 = dotColor
    dot.BorderSizePixel = 0
    dot.Position = UDim2.fromOffset(14, 14)
    dot.Size = UDim2.fromOffset(9, 9)
    dot.ZIndex = 302
    dot.Parent = card
    corner(dot, 99)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(32, 8)
    titleLabel.Size = UDim2.new(1, -44, 0, 19)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title or "H3X4 OBBY"
    titleLabel.ZIndex = 302
    titleLabel.Parent = card

    local body = Instance.new("TextLabel")
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(14, 29)
    body.Size = UDim2.new(1, -28, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Font = Enum.Font.GothamMedium
    body.TextSize = 9
    body.TextColor3 = Theme.TextDim
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Text = text or ""
    body.ZIndex = 302
    body.Parent = card

    task.defer(function()
        if not card.Parent then return end
        local targetHeight = math.max(62, body.AbsoluteSize.Y + 42)
        card.Size = UDim2.fromOffset(316, 0)
        card.Position = UDim2.fromOffset(22, 0)
        tween(card, 0.24, {Size = UDim2.fromOffset(316, targetHeight), Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Quint)
        task.delay(3.0, function()
            if card and card.Parent then
                local tw = tween(card, 0.2, {Size = UDim2.fromOffset(316, 0), BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
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

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.Size = IS_MOBILE and UDim2.fromOffset(600, 378) or UDim2.fromOffset(730, 466)
Main.BackgroundColor3 = Theme.BG
Main.BackgroundTransparency = 0.52
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.ZIndex = 10
Main.Parent = ScreenGui
corner(Main, 20)
stroke(Main, Theme.Accent, 0.48, 1)

-- Fondo visual tenue. Roblox no ofrece blur local real para UI; usamos
-- varias capas casi transparentes + overlay oscuro para un efecto suave/glass.
local BackgroundImage = Instance.new("ImageLabel")
BackgroundImage.Name = "BackgroundImage"
BackgroundImage.BackgroundTransparency = 1
BackgroundImage.Position = UDim2.fromOffset(-2, -2)
BackgroundImage.Size = UDim2.new(1, 4, 1, 4)
BackgroundImage.Image = "rbxassetid://110238194996163"
BackgroundImage.ImageColor3 = Color3.fromRGB(150, 225, 235)
BackgroundImage.ImageTransparency = 0.33
BackgroundImage.ScaleType = Enum.ScaleType.Crop
BackgroundImage.ZIndex = 10
BackgroundImage.Parent = Main

local BackgroundSoftLayer = BackgroundImage:Clone()
BackgroundSoftLayer.Name = "BackgroundSoftLayer"
BackgroundSoftLayer.Position = UDim2.fromOffset(2, 2)
BackgroundSoftLayer.Size = UDim2.new(1, -4, 1, -4)
BackgroundSoftLayer.ImageColor3 = Color3.fromRGB(255, 105, 210)
BackgroundSoftLayer.ImageTransparency = 0.88
BackgroundSoftLayer.ZIndex = 10
BackgroundSoftLayer.Parent = Main

local GlassOverlay = Instance.new("Frame")
GlassOverlay.Name = "GlassOverlay"
GlassOverlay.BackgroundColor3 = Color3.fromRGB(0, 7, 10)
GlassOverlay.BackgroundTransparency = 0.82
GlassOverlay.BorderSizePixel = 0
GlassOverlay.Size = UDim2.fromScale(1, 1)
GlassOverlay.ZIndex = 10
GlassOverlay.Parent = Main
corner(GlassOverlay, 20)

local GlassShade = Instance.new("Frame")
GlassShade.Name = "GlassShade"
GlassShade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
GlassShade.BackgroundTransparency = 0.95
GlassShade.BorderSizePixel = 0
GlassShade.Position = UDim2.new(0, 0, 0.48, 0)
GlassShade.Size = UDim2.new(1, 0, 0.52, 0)
GlassShade.ZIndex = 10
GlassShade.Parent = Main

local UIScale = Instance.new("UIScale")
UIScale.Scale = 1
UIScale.Parent = Main

local Top = Instance.new("Frame")
Top.BackgroundColor3 = Theme.Panel
Top.BackgroundTransparency = 0.54
Top.BorderSizePixel = 0
Top.Size = UDim2.new(1, 0, 0, 66)
Top.ZIndex = 11
Top.Parent = Main

local AccentLine = Instance.new("Frame")
AccentLine.BorderSizePixel = 0
AccentLine.BackgroundColor3 = Theme.Accent
AccentLine.Size = UDim2.new(1, 0, 0, 1)
AccentLine.Position = UDim2.new(0, 0, 1, -1)
AccentLine.ZIndex = 12
AccentLine.Parent = Top
gradient(AccentLine, Theme.Accent, Theme.Accent2, 0)

local Logo = Instance.new("ImageLabel")
Logo.Name = "BrandLogo"
Logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Logo.BackgroundTransparency = 1
Logo.BorderSizePixel = 0
Logo.Position = UDim2.fromOffset(16, 13)
Logo.Size = UDim2.fromOffset(40, 40)
Logo.Image = "rbxassetid://72742584610344"
Logo.ImageColor3 = Color3.fromRGB(220, 252, 255)
Logo.ImageTransparency = 0
Logo.ScaleType = Enum.ScaleType.Fit
Logo.ZIndex = 13
Logo.Parent = Top
corner(Logo, 12)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(68, 13)
Title.Size = UDim2.new(1, -200, 0, 22)
Title.Font = Enum.Font.Code
Title.TextSize = 18
Title.TextColor3 = Theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "H3X4 // OBBY"
Title.ZIndex = 12
Title.Parent = Top

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.fromOffset(68, 35)
Subtitle.Size = UDim2.new(1, -220, 0, 16)
Subtitle.Font = Enum.Font.Code
Subtitle.TextSize = 9
Subtitle.TextColor3 = Theme.TextDim
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Text = "[ PARKOUR SYSTEM / SPEEDRUN MODULE ]"
Subtitle.ZIndex = 12
Subtitle.Parent = Top

local StatusPill = Instance.new("Frame")
StatusPill.AnchorPoint = Vector2.new(1, 0.5)
StatusPill.Position = UDim2.new(1, -94, 0.5, 0)
StatusPill.Size = UDim2.fromOffset(82, 26)
StatusPill.BackgroundColor3 = Theme.Panel2
StatusPill.BackgroundTransparency = 0.46
StatusPill.BorderSizePixel = 0
StatusPill.ZIndex = 12
StatusPill.Parent = Top
corner(StatusPill, 3)
stroke(StatusPill, Theme.Accent, 0.52, 1)

local StatusDot = Instance.new("Frame")
StatusDot.BackgroundColor3 = Theme.Accent
StatusDot.BorderSizePixel = 0
StatusDot.Position = UDim2.fromOffset(10, 9)
StatusDot.Size = UDim2.fromOffset(8, 8)
StatusDot.ZIndex = 13
StatusDot.Parent = StatusPill
corner(StatusDot, 99)

local StatusText = Instance.new("TextLabel")
StatusText.BackgroundTransparency = 1
StatusText.Position = UDim2.fromOffset(23, 0)
StatusText.Size = UDim2.new(1, -27, 1, 0)
StatusText.Text = IS_MOBILE and "MOBILE::ON" or "PC::ON"
StatusText.TextColor3 = Theme.TextDim
StatusText.TextSize = 7
StatusText.Font = Enum.Font.Code
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.ZIndex = 13
StatusText.Parent = StatusPill

local function topButton(text, offset)
    local button = Instance.new("TextButton")
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, offset, 0.5, 0)
    button.Size = UDim2.fromOffset(34, 34)
    button.BackgroundColor3 = Theme.Panel2
    button.BackgroundTransparency = 0.46
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Theme.Text
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false
    button.ZIndex = 13
    button.Parent = Top
    corner(button, 3)
    stroke(button, Theme.Border, 0.50, 1)
    button.MouseEnter:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.26, BackgroundColor3 = Theme.CardHover})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.14, {BackgroundTransparency = 0.46, BackgroundColor3 = Theme.Panel2})
    end)
    return button
end

local MinimizeButton = topButton("—", -48)
local CloseButton = topButton("×", -10)
CloseButton.TextColor3 = Theme.Danger

local Sidebar = Instance.new("Frame")
Sidebar.BackgroundColor3 = Theme.Panel
Sidebar.BackgroundTransparency = 0.56
Sidebar.BorderSizePixel = 0
Sidebar.Position = UDim2.fromOffset(10, 76)
Sidebar.Size = UDim2.new(0, 170, 1, -86)
Sidebar.ZIndex = 11
Sidebar.Parent = Main
corner(Sidebar, 16)
stroke(Sidebar, Theme.Accent, 0.64, 1)

local SidebarTitle = Instance.new("TextLabel")
SidebarTitle.BackgroundTransparency = 1
SidebarTitle.Position = UDim2.fromOffset(14, 10)
SidebarTitle.Size = UDim2.new(1, -24, 0, 20)
SidebarTitle.Text = "CATEGORÍAS"
SidebarTitle.TextColor3 = Theme.TextDim
SidebarTitle.TextSize = 9
SidebarTitle.Font = Enum.Font.Code
SidebarTitle.TextXAlignment = Enum.TextXAlignment.Left
SidebarTitle.ZIndex = 12
SidebarTitle.Parent = Sidebar

local CategoryScroll = Instance.new("ScrollingFrame")
CategoryScroll.BackgroundTransparency = 1
CategoryScroll.BorderSizePixel = 0
CategoryScroll.Position = UDim2.fromOffset(10, 36)
CategoryScroll.Size = UDim2.new(1, -20, 1, -46)
CategoryScroll.ScrollBarThickness = 3
CategoryScroll.ScrollBarImageColor3 = Theme.Accent
CategoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
CategoryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CategoryScroll.ZIndex = 12
CategoryScroll.Parent = Sidebar

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Padding = UDim.new(0, 6)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.Parent = CategoryScroll

local function updateCategoryCanvas()
    CategoryScroll.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 6)
end
trackConnection(CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCategoryCanvas))
task.defer(updateCategoryCanvas)

local Content = Instance.new("Frame")
Content.BackgroundTransparency = 1
Content.Position = UDim2.fromOffset(190, 76)
Content.Size = UDim2.new(1, -200, 1, -86)
Content.ZIndex = 11
Content.Parent = Main

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

local function createPage(key)
    local page = Instance.new("ScrollingFrame")
    page.Name = key .. "_Page"
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.fromScale(1, 1)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Accent
    page.ScrollBarImageTransparency = 0.25
    page.AutomaticCanvasSize = Enum.AutomaticSize.None
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.ZIndex = 12
    page.Parent = Content
    padding(page, 10, 10, 10, 14)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local function updateCanvas()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
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
    for pageKey, page in pairs(Pages) do
        page.Visible = pageKey == key
        if pageKey == key then
            page.CanvasPosition = Vector2.zero
        end
    end

    for buttonKey, button in pairs(CategoryButtons) do
        local active = buttonKey == key
        local labelText = button:FindFirstChild("Label")
        local indexBox = button:FindFirstChild("IndexBox")
        local stateBox = button:FindFirstChild("StateBox")
        local buttonStroke = button:FindFirstChildOfClass("UIStroke")

        tween(button, 0.16, {
            BackgroundColor3 = active and Theme.AccentDark or Theme.Panel2,
            BackgroundTransparency = active and 0.26 or 0.56,
        })
        if labelText then
            tween(labelText, 0.16, {TextColor3 = active and Theme.Text or Theme.TextDim})
        end
        if indexBox then
            tween(indexBox, 0.16, {
                BackgroundColor3 = active and Theme.Accent or Theme.Panel3,
                BackgroundTransparency = active and 0.08 or 0.28,
            })
            local t = indexBox:FindFirstChildOfClass("TextLabel")
            if t then tween(t, 0.16, {TextColor3 = active and Theme.BG or Theme.Accent}) end
        end
        if stateBox then
            stateBox.Text = active and "ON" or ">"
            tween(stateBox, 0.16, {
                TextColor3 = active and Theme.Accent2 or Theme.TextMuted,
                BackgroundTransparency = active and 0.12 or 0.35,
            })
        end
        if buttonStroke then
            tween(buttonStroke, 0.16, {
                Transparency = active and 0.20 or 0.66,
                Color = active and Theme.Accent or Theme.Border,
            })
        end
    end
end

for index, definition in ipairs(categories) do
    local key, label = definition[1], definition[2]
    local button = Instance.new("TextButton")
    button.Name = key
    button.Size = UDim2.new(1, 0, 0, 46)
    button.BackgroundColor3 = Theme.Panel2
    button.BackgroundTransparency = 0.56
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.LayoutOrder = index
    button.ZIndex = 13
    button.Parent = CategoryScroll
    corner(button, 3)
    stroke(button, Theme.Border, 0.66, 1)

    local indexBox = Instance.new("Frame")
    indexBox.Name = "IndexBox"
    indexBox.BackgroundColor3 = Theme.Panel3
    indexBox.BackgroundTransparency = 0.28
    indexBox.BorderSizePixel = 0
    indexBox.Position = UDim2.fromOffset(5, 5)
    indexBox.Size = UDim2.fromOffset(32, 36)
    indexBox.ZIndex = 14
    indexBox.Parent = button
    corner(indexBox, 2)

    local indexText = Instance.new("TextLabel")
    indexText.BackgroundTransparency = 1
    indexText.Size = UDim2.fromScale(1, 1)
    indexText.Text = string.format("%02d", index)
    indexText.TextColor3 = Theme.Accent
    indexText.TextSize = 9
    indexText.Font = Enum.Font.Code
    indexText.ZIndex = 15
    indexText.Parent = indexBox

    local labelText = Instance.new("TextLabel")
    labelText.Name = "Label"
    labelText.BackgroundTransparency = 1
    labelText.Position = UDim2.fromOffset(46, 0)
    labelText.Size = UDim2.new(1, -76, 1, 0)
    labelText.Text = label
    labelText.TextColor3 = Theme.TextDim
    labelText.TextSize = 10
    labelText.Font = Enum.Font.Code
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.ZIndex = 14
    labelText.Parent = button

    local stateBox = Instance.new("TextLabel")
    stateBox.Name = "StateBox"
    stateBox.AnchorPoint = Vector2.new(1, 0.5)
    stateBox.Position = UDim2.new(1, -8, 0.5, 0)
    stateBox.Size = UDim2.fromOffset(20, 20)
    stateBox.BackgroundColor3 = Theme.Panel3
    stateBox.BackgroundTransparency = 0.35
    stateBox.BorderSizePixel = 0
    stateBox.Text = ">"
    stateBox.TextColor3 = Theme.TextMuted
    stateBox.TextSize = 10
    stateBox.Font = Enum.Font.Code
    stateBox.ZIndex = 14
    stateBox.Parent = button
    corner(stateBox, 2)

    button.MouseEnter:Connect(function()
        if CurrentCategory ~= key then
            tween(button, 0.12, {BackgroundTransparency = 0.38, BackgroundColor3 = Theme.CardHover})
            tween(labelText, 0.12, {TextColor3 = Theme.Text})
            tween(stateBox, 0.12, {TextColor3 = Theme.Accent})
        end
    end)
    button.MouseLeave:Connect(function()
        if CurrentCategory ~= key then
            tween(button, 0.12, {BackgroundTransparency = 0.56, BackgroundColor3 = Theme.Panel2})
            tween(labelText, 0.12, {TextColor3 = Theme.TextDim})
            tween(stateBox, 0.12, {TextColor3 = Theme.TextMuted})
        end
    end)
    button.MouseButton1Click:Connect(function()
        setCategory(key)
    end)

    CategoryButtons[key] = button
end

local function makeCard(page, titleText, subtitleText)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Theme.Card
    card.BackgroundTransparency = 0.54
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 64)
    card.AutomaticSize = Enum.AutomaticSize.None
    card.ZIndex = 13
    card.Parent = page
    corner(card, 4)
    stroke(card, Theme.Border, 0.52, 1)
    padding(card, 14, 14, 12, 14)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 9)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Text = "[ " .. string.upper(titleText) .. " ]"
    title.TextColor3 = Theme.Text
    title.TextSize = 11
    title.Font = Enum.Font.Code
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
        subtitle.Font = Enum.Font.Code
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.TextYAlignment = Enum.TextYAlignment.Top
        subtitle.LayoutOrder = 2
        subtitle.ZIndex = 14
        subtitle.Parent = card
    end

    local function updateHeight()
        card.Size = UDim2.new(1, 0, 0, math.max(58, layout.AbsoluteContentSize.Y + 26))
    end
    trackConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateHeight))
    task.defer(updateHeight)

    return card
end

local function makeDivider(parent)
    local line = Instance.new("Frame")
    line.BackgroundColor3 = Theme.Text
    line.BackgroundTransparency = 0.92
    line.BorderSizePixel = 0
    line.Size = UDim2.new(1, 0, 0, 1)
    line.ZIndex = 14
    line.Parent = parent
    return line
end

local ActionButtonSerial = 0
local function makeButton(parent, text, callback, danger)
    ActionButtonSerial += 1
    local normal = danger and Color3.fromRGB(30, 13, 20) or Theme.Panel2
    local hovered = danger and Color3.fromRGB(48, 18, 29) or Theme.CardHover
    local accentColor = danger and Theme.Danger or Theme.Accent

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 46)
    button.BackgroundColor3 = normal
    button.BackgroundTransparency = 0.55
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.ZIndex = 14
    button.Parent = parent
    corner(button, 3)
    stroke(button, accentColor, danger and 0.42 or 0.62, 1)

    local serial = Instance.new("TextLabel")
    serial.Name = "Serial"
    serial.Position = UDim2.fromOffset(6, 6)
    serial.Size = UDim2.fromOffset(38, 34)
    serial.BackgroundColor3 = danger and Color3.fromRGB(56, 18, 31) or Theme.Panel3
    serial.BackgroundTransparency = 0.22
    serial.BorderSizePixel = 0
    serial.Text = string.format("A%02d", ((ActionButtonSerial - 1) % 99) + 1)
    serial.TextColor3 = accentColor
    serial.TextSize = 8
    serial.Font = Enum.Font.Code
    serial.ZIndex = 15
    serial.Parent = button
    corner(serial, 2)

    local label = Instance.new("TextLabel")
    label.Name = "ActionLabel"
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(54, 0)
    label.Size = UDim2.new(1, -104, 1, 0)
    label.Text = string.upper(text)
    label.TextColor3 = danger and Theme.Danger or Theme.Text
    label.TextSize = 10
    label.Font = Enum.Font.Code
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 15
    label.Parent = button

    local actionBox = Instance.new("TextLabel")
    actionBox.Name = "ActionBox"
    actionBox.AnchorPoint = Vector2.new(1, 0.5)
    actionBox.Position = UDim2.new(1, -6, 0.5, 0)
    actionBox.Size = UDim2.fromOffset(38, 34)
    actionBox.BackgroundColor3 = danger and Color3.fromRGB(56, 18, 31) or Theme.AccentDark
    actionBox.BackgroundTransparency = 0.20
    actionBox.BorderSizePixel = 0
    actionBox.Text = danger and "DEL" or "RUN"
    actionBox.TextColor3 = accentColor
    actionBox.TextSize = 8
    actionBox.Font = Enum.Font.Code
    actionBox.ZIndex = 15
    actionBox.Parent = button
    corner(actionBox, 2)

    button.MouseEnter:Connect(function()
        tween(button, 0.12, {BackgroundColor3 = hovered, BackgroundTransparency = 0.34})
        tween(actionBox, 0.12, {BackgroundTransparency = 0.04, TextColor3 = danger and Theme.Text or Theme.BG, BackgroundColor3 = accentColor})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.12, {BackgroundColor3 = normal, BackgroundTransparency = 0.55})
        tween(actionBox, 0.12, {BackgroundTransparency = 0.20, TextColor3 = accentColor, BackgroundColor3 = danger and Color3.fromRGB(56, 18, 31) or Theme.AccentDark})
    end)

    if callback then
        button.MouseButton1Click:Connect(function()
            actionBox.Text = "..."
            tween(button, 0.06, {BackgroundTransparency = 0.20})
            task.delay(0.10, function()
                if actionBox and actionBox.Parent then
                    actionBox.Text = danger and "DEL" or "RUN"
                end
                if button and button.Parent then
                    tween(button, 0.10, {BackgroundTransparency = 0.34})
                end
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
    button.Size = UDim2.new(1, 0, 0, 46)
    button.BackgroundColor3 = Theme.Panel2
    button.BackgroundTransparency = 0.55
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.ZIndex = 14
    button.Parent = parent
    corner(button, 3)
    stroke(button, Theme.Border, 0.62, 1)

    local tag = Instance.new("TextLabel")
    tag.Position = UDim2.fromOffset(6, 6)
    tag.Size = UDim2.fromOffset(38, 34)
    tag.BackgroundColor3 = Theme.Panel3
    tag.BackgroundTransparency = 0.22
    tag.BorderSizePixel = 0
    tag.Text = "TGL"
    tag.TextColor3 = Theme.Accent2
    tag.TextSize = 8
    tag.Font = Enum.Font.Code
    tag.ZIndex = 15
    tag.Parent = button
    corner(tag, 2)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(54, 0)
    label.Size = UDim2.new(1, -154, 1, 0)
    label.Text = string.upper(text)
    label.TextColor3 = Theme.Text
    label.TextSize = 10
    label.Font = Enum.Font.Code
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 15
    label.Parent = button

    local switch = Instance.new("Frame")
    switch.Name = "ToggleTrack"
    switch.AnchorPoint = Vector2.new(1, 0.5)
    switch.Position = UDim2.new(1, -6, 0.5, 0)
    switch.Size = UDim2.fromOffset(88, 34)
    switch.BackgroundColor3 = Theme.Panel3
    switch.BackgroundTransparency = 0.18
    switch.BorderSizePixel = 0
    switch.ZIndex = 15
    switch.Parent = button
    corner(switch, 2)
    stroke(switch, Theme.Border, 0.56, 1)

    local offBox = Instance.new("TextLabel")
    offBox.Name = "OffBox"
    offBox.Position = UDim2.fromOffset(3, 3)
    offBox.Size = UDim2.fromOffset(39, 28)
    offBox.BackgroundColor3 = Theme.ToggleOff
    offBox.BackgroundTransparency = 0.08
    offBox.BorderSizePixel = 0
    offBox.Text = "OFF"
    offBox.TextColor3 = Theme.TextDim
    offBox.TextSize = 8
    offBox.Font = Enum.Font.Code
    offBox.ZIndex = 16
    offBox.Parent = switch
    corner(offBox, 2)

    local onBox = Instance.new("TextLabel")
    onBox.Name = "OnBox"
    onBox.Position = UDim2.fromOffset(46, 3)
    onBox.Size = UDim2.fromOffset(39, 28)
    onBox.BackgroundColor3 = Theme.AccentDark
    onBox.BackgroundTransparency = 0.65
    onBox.BorderSizePixel = 0
    onBox.Text = "ON"
    onBox.TextColor3 = Theme.TextMuted
    onBox.TextSize = 8
    onBox.Font = Enum.Font.Code
    onBox.ZIndex = 16
    onBox.Parent = switch
    corner(onBox, 2)

    local value = defaultValue == true
    local controller = {}

    function controller.Set(newValue, silent)
        value = newValue == true
        if settingKey then Settings[settingKey] = value end

        tween(offBox, 0.14, {
            BackgroundTransparency = value and 0.72 or 0.08,
            TextColor3 = value and Theme.TextMuted or Theme.Text,
        })
        tween(onBox, 0.14, {
            BackgroundColor3 = value and Theme.Accent or Theme.AccentDark,
            BackgroundTransparency = value and 0.02 or 0.65,
            TextColor3 = value and Theme.BG or Theme.TextMuted,
        })
        local bs = button:FindFirstChildOfClass("UIStroke")
        if bs then tween(bs, 0.14, {Color = value and Theme.Accent or Theme.Border, Transparency = value and 0.28 or 0.62}) end

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
        tween(button, 0.12, {BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 0.34})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.12, {BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.55})
    end)

    if settingKey then ToggleControllers[settingKey] = controller end
    return controller
end

local SliderControllers = {}

local function makeSlider(parent, text, minValue, maxValue, defaultValue, callback, settingKey)
    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = Theme.Panel2
    holder.BackgroundTransparency = 0.64
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 64)
    holder.ZIndex = 14
    holder.Parent = parent
    corner(holder, 3)
    stroke(holder, Theme.Border, 0.72, 1)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(10, 5)
    label.Size = UDim2.new(1, -92, 0, 22)
    label.Text = "SLD // " .. string.upper(text)
    label.TextColor3 = Theme.TextDim
    label.TextSize = 9
    label.Font = Enum.Font.Code
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 15
    label.Parent = holder

    local valueBox = Instance.new("TextBox")
    valueBox.AnchorPoint = Vector2.new(1, 0)
    valueBox.Position = UDim2.new(1, -7, 0, 5)
    valueBox.Size = UDim2.fromOffset(72, 23)
    valueBox.BackgroundColor3 = Theme.Panel3
    valueBox.BackgroundTransparency = 0.22
    valueBox.BorderSizePixel = 0
    valueBox.ClearTextOnFocus = false
    valueBox.TextColor3 = Theme.Accent
    valueBox.TextSize = 9
    valueBox.Font = Enum.Font.Code
    valueBox.Text = tostring(defaultValue)
    valueBox.ZIndex = 16
    valueBox.Parent = holder
    corner(valueBox, 2)
    stroke(valueBox, Theme.AccentSoft, 0.50, 1)

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(10, 39)
    bar.Size = UDim2.new(1, -20, 0, 12)
    bar.BackgroundColor3 = Theme.Panel3
    bar.BackgroundTransparency = 0.18
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.ZIndex = 15
    bar.Parent = holder
    corner(bar, 1)

    for i = 1, 9 do
        local tick = Instance.new("Frame")
        tick.BackgroundColor3 = Theme.Border
        tick.BackgroundTransparency = 0.40
        tick.BorderSizePixel = 0
        tick.Size = UDim2.fromOffset(1, 6)
        tick.Position = UDim2.new(i / 10, 0, 0.5, -3)
        tick.ZIndex = 16
        tick.Parent = bar
    end

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.ZIndex = 16
    fill.Parent = bar
    corner(fill, 1)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(10, 20)
    knob.BackgroundColor3 = Theme.Accent2
    knob.BorderSizePixel = 0
    knob.ZIndex = 17
    knob.Parent = bar
    corner(knob, 1)
    stroke(knob, Theme.Text, 0.50, 1)

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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            applyInput(input)
        end
    end))
    valueBox.FocusLost:Connect(function() controller.Set(tonumber(valueBox.Text) or value, false) end)

    controller.Set(defaultValue, true)
    if settingKey then SliderControllers[settingKey] = controller end
    return controller
end

local function makeStat(parent, titleText, valueText)
    local row = Instance.new("Frame")
    row.BackgroundColor3 = Theme.Panel2
    row.BackgroundTransparency = 0.60
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 44)
    row.ZIndex = 14
    row.Parent = parent
    corner(row, 3)
    stroke(row, Theme.Border, 0.70, 1)

    local code = Instance.new("TextLabel")
    code.Position = UDim2.fromOffset(6, 6)
    code.Size = UDim2.fromOffset(34, 32)
    code.BackgroundColor3 = Theme.Panel3
    code.BackgroundTransparency = 0.25
    code.BorderSizePixel = 0
    code.Text = "SYS"
    code.TextColor3 = Theme.Accent2
    code.TextSize = 7
    code.Font = Enum.Font.Code
    code.ZIndex = 15
    code.Parent = row
    corner(code, 2)

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(50, 5)
    name.Size = UDim2.new(0.56, -50, 1, -10)
    name.Text = string.upper(titleText)
    name.TextColor3 = Theme.TextDim
    name.TextSize = 9
    name.Font = Enum.Font.Code
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 15
    name.Parent = row

    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.AnchorPoint = Vector2.new(1, 0)
    value.Position = UDim2.new(1, -10, 0, 5)
    value.Size = UDim2.new(0.44, 0, 1, -10)
    value.Text = valueText or "-"
    value.TextColor3 = Theme.Accent
    value.TextSize = 10
    value.Font = Enum.Font.Code
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

local RestoreOrb = Instance.new("ImageButton")
RestoreOrb.Name = "RestoreOrb"
RestoreOrb.Visible = false
RestoreOrb.Size = UDim2.fromOffset(56, 56)
RestoreOrb.Position = UDim2.fromOffset(18, 80)
RestoreOrb.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
RestoreOrb.BackgroundTransparency = 1
RestoreOrb.BorderSizePixel = 0
RestoreOrb.Image = "rbxassetid://72742584610344"
RestoreOrb.ImageColor3 = Color3.fromRGB(255, 255, 255)
RestoreOrb.ImageTransparency = 0
RestoreOrb.ScaleType = Enum.ScaleType.Fit
RestoreOrb.AutoButtonColor = false
RestoreOrb.ZIndex = 200
RestoreOrb.Parent = ScreenGui
corner(RestoreOrb, 4)

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
    local tw = tween(Main, 0.24, {Size = UDim2.fromOffset(80, 50), BackgroundTransparency = 0.46}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    if tw then
        tw.Completed:Connect(function()
            Main.Visible = false
            RestoreOrb.Visible = true
        end)
    end
end)

RestoreOrb.MouseButton1Click:Connect(function()
    RestoreOrb.Visible = false
    Main.Visible = true
    local targetSize = IS_MOBILE and UDim2.fromOffset(600, 378) or UDim2.fromOffset(730, 466)
    Main.Size = UDim2.fromOffset(80, 50)
    Main.BackgroundTransparency = 0.46
    tween(Main, 0.28, {Size = targetSize, BackgroundTransparency = 0.32}, Enum.EasingStyle.Back)
end)

local function updateResponsive()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

    local baseWidth = IS_MOBILE and 600 or 730
    local baseHeight = IS_MOBILE and 378 or 466

    local scaleX = (viewport.X - 12) / baseWidth
    local scaleY = (viewport.Y - 36) / baseHeight
    UIScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.62, 1)
end

updateResponsive()

if Workspace.CurrentCamera then
    trackConnection(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive))
end

trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(updateResponsive)
end))

-- =========================================================
-- FLOATING MOBILE HUD
-- =========================================================

local MobileHud = Instance.new("Frame")
MobileHud.Name = "MobileHud"
MobileHud.Visible = Settings.MobileHud
MobileHud.BackgroundTransparency = 1
MobileHud.AnchorPoint = Vector2.new(1, 1)
MobileHud.Position = UDim2.new(1, -14, 1, -90)
MobileHud.Size = UDim2.fromOffset(180, 46)
MobileHud.ZIndex = 220
MobileHud.Parent = ScreenGui

local MobileLayout = Instance.new("UIListLayout")
MobileLayout.FillDirection = Enum.FillDirection.Horizontal
MobileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
MobileLayout.Padding = UDim.new(0, 6)
MobileLayout.Parent = MobileHud

local function mobileAction(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(56, 44)
    btn.BackgroundColor3 = Theme.Panel2
    btn.BackgroundTransparency = 0.46
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Theme.Text
    btn.TextSize = 9
    btn.Font = Enum.Font.Code
    btn.AutoButtonColor = false
    btn.ZIndex = 221
    btn.Parent = MobileHud
    corner(btn, 14)
    stroke(btn, Theme.Accent, 0.58, 1)

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = btn

    btn.MouseEnter:Connect(function()
        tween(btn, 0.14, {BackgroundTransparency = 0.26, BackgroundColor3 = Theme.CardHover})
        tween(scale, 0.14, {Scale = 1.04})
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.14, {BackgroundTransparency = 0.46, BackgroundColor3 = Theme.Panel2})
        tween(scale, 0.14, {Scale = 1})
    end)
    btn.MouseButton1Click:Connect(function()
        tween(scale, 0.07, {Scale = 0.96})
        task.delay(0.07, function()
            if scale and scale.Parent then tween(scale, 0.12, {Scale = 1.04}) end
        end)
        callback()
    end)
    return btn
end

-- callbacks assigned later
local MobileSave = nil
local MobileReturn = nil
local MobileRetry = nil

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
    previous.BackgroundColor3 = Theme.Panel2
    previous.BackgroundTransparency = 0.58
    previous.BorderSizePixel = 0
    previous.Text = "‹   ANTERIOR"
    previous.TextColor3 = Theme.Text
    previous.TextSize = 9
    previous.Font = Enum.Font.Code
    previous.ZIndex = 15
    previous.AutoButtonColor = false
    previous.Parent = nav
    corner(previous, 3)
    stroke(previous, Theme.Accent, 0.50, 1)

    local nextButton = previous:Clone()
    nextButton.Position = UDim2.new(0.5, 4, 0, 0)
    nextButton.Text = "SIGUIENTE   ›"
    nextButton.Parent = nav

    local function navHover(button)
        button.MouseEnter:Connect(function()
            tween(button, 0.14, {BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 0.26})
        end)
        button.MouseLeave:Connect(function()
            tween(button, 0.14, {BackgroundColor3 = Theme.Panel2, BackgroundTransparency = 0.48})
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

        MobileHud.Visible = Settings.MobileHud and IS_MOBILE
        task.spawn(scanKillBricks)
        task.spawn(scanInvisibleParts)
        if Settings.ObjectivePointer then task.spawn(scanObjectives) end
        if Settings.RoutePath then redrawRoute() else clearRouteVisuals() end

        notify("CONFIGURACIÓN", "Configuración cargada.", "success")
    end)

    local mobile = makeCard(page, "MÓVIL")
    MobileHudToggle = makeToggle(mobile, "HUD FLOTANTE", Settings.MobileHud, function(value)
        Settings.MobileHud = value
        MobileHud.Visible = value and IS_MOBILE
    end, "MobileHud")

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

    local function refreshKeyButton(name)
        local button = KeybindButtons[name]
        if not button then return end
        local key = Keybinds[name]
        button.Text = button:GetAttribute("BaseLabel") .. "  •  " .. (key and key.Name or "SIN TECLA")
    end

    for _, item in ipairs(names) do
        local name, label = item[1], item[2]
        local button
        button = makeButton(keyCard, label .. "  •  " .. Keybinds[name].Name, function()
            capturing = name
            button.Text = label .. "  •  PRESIONA UNA TECLA..."
        end)
        button:SetAttribute("BaseLabel", label)
        KeybindButtons[name] = button
    end

    trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if not capturing then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            refreshKeyButton(capturing)
            capturing = nil
            return
        end

        if input.KeyCode ~= Enum.KeyCode.Unknown then
            Keybinds[capturing] = input.KeyCode
            refreshKeyButton(capturing)
            notify("KEYBIND", "Atajo actualizado.", "success")
            capturing = nil
        end
    end))

    task.spawn(function()
        while not State.Destroyed do
            task.wait(0.75)
            for name in pairs(KeybindButtons) do
                refreshKeyButton(name)
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
-- OPEN ANIMATION
-- =========================================================

setCategory("HOME")

local targetSize = Main.Size
Main.Size = UDim2.fromOffset(120, 70)
Main.BackgroundTransparency = 0.40
tween(Main, 0.38, {
    Size = targetSize,
    BackgroundTransparency = 0.32,
}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

notify("H3X4 // OBBY", "CYBER UI V5 cargada. Layout fijo y categorías completas.", "success")

print("[H3X4 OBBY] Cyber UI V5 FIXED cargada.")
