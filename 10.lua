-- ========================================================
-- VEHICLE HUB PRO - GUI SYSTEM
-- ========================================================

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Intentar usar gethui() (común en exploits modernos) para evitar detección, sino CoreGui
local targetParent = pcall(function() return gethui() end) and gethui() or CoreGui

-- ========================================================
-- VARIABLES DE ESTADO Y CONEXIONES
-- ========================================================
local activeToggles = {}
local activeConnections = {}

local function addConnection(name, connection)
    if activeConnections[name] then
        activeConnections[name]:Disconnect()
    end
    activeConnections[name] = connection
end

local function removeConnection(name)
    if activeConnections[name] then
        activeConnections[name]:Disconnect()
        activeConnections[name] = nil
    end
end

-- Utilidad para obtener el vehículo actual
local function getCurrentVehicle()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.SeatPart then
        return char.Humanoid.SeatPart.Parent
    end
    return nil
end

-- ========================================================
-- CREACIÓN DE LA INTERFAZ - MODERN UI
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VehicleHub_Overlay"
ScreenGui.Parent = targetParent
ScreenGui.DisplayOrder = 999999999
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local COLORS = {
    Background = Color3.fromRGB(10, 12, 17),
    Surface = Color3.fromRGB(17, 20, 28),
    SurfaceHover = Color3.fromRGB(22, 27, 37),
    SurfaceActive = Color3.fromRGB(19, 29, 43),
    Border = Color3.fromRGB(42, 49, 63),
    BorderSoft = Color3.fromRGB(32, 38, 50),
    Accent = Color3.fromRGB(67, 166, 255),
    Accent2 = Color3.fromRGB(118, 92, 255),
    Text = Color3.fromRGB(244, 247, 255),
    TextMuted = Color3.fromRGB(145, 154, 175),
    TextDim = Color3.fromRGB(94, 103, 123),
    Success = Color3.fromRGB(72, 218, 145),
    Danger = Color3.fromRGB(255, 94, 112),
}

local function tween(object, duration, properties, style, direction)
    local info = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(object, info, properties)
    animation:Play()
    return animation
end

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius)
    item.Parent = parent
    return item
end

local function stroke(parent, color, thickness, transparency)
    local item = Instance.new("UIStroke")
    item.Color = color
    item.Thickness = thickness or 1
    item.Transparency = transparency or 0
    item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    item.Parent = parent
    return item
end

-- Drag mejorado: arrastra desde una zona concreta sin interferir con los controles.
local function makeDraggable(guiObject, dragHandle, linkedObject)
    dragHandle = dragHandle or guiObject
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    local linkedStartPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            linkedStartPos = linkedObject and linkedObject.Position or nil

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            if linkedObject and linkedStartPos then
                linkedObject.Position = UDim2.new(
                    linkedStartPos.X.Scale,
                    linkedStartPos.X.Offset + delta.X,
                    linkedStartPos.Y.Scale,
                    linkedStartPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local compactMode = viewport.X < 700 or UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local panelWidth = math.min(compactMode and 332 or 390, math.max(280, viewport.X - 24))
local panelHeight = math.min(compactMode and 440 or 500, math.max(320, viewport.Y - 24))

-- Sombra exterior
local Shadow = Instance.new("Frame")
Shadow.Name = "Shadow"
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Size = UDim2.new(0, panelWidth + 18, 0, panelHeight + 18)
Shadow.Position = UDim2.new(0.5, 0, 0.5, 8)
Shadow.BackgroundColor3 = Color3.new(0, 0, 0)
Shadow.BackgroundTransparency = 0.55
Shadow.BorderSizePixel = 0
Shadow.ZIndex = 0
Shadow.Parent = ScreenGui
corner(Shadow, 22)

-- Panel principal
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Size = UDim2.new(0, panelWidth, 0, panelHeight)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = COLORS.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.ZIndex = 2
MainFrame.Parent = ScreenGui
corner(MainFrame, 18)
local MainStroke = stroke(MainFrame, COLORS.Border, 1, 0.05)

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.94
MainScale.Parent = MainFrame

-- Barra superior
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 72)
TopBar.BackgroundColor3 = COLORS.Surface
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 3
TopBar.Parent = MainFrame

local HeaderSeparator = Instance.new("Frame")
HeaderSeparator.Size = UDim2.new(1, -28, 0, 1)
HeaderSeparator.Position = UDim2.new(0, 14, 1, -1)
HeaderSeparator.BackgroundColor3 = COLORS.BorderSoft
HeaderSeparator.BorderSizePixel = 0
HeaderSeparator.ZIndex = 4
HeaderSeparator.Parent = TopBar

local BrandIcon = Instance.new("Frame")
BrandIcon.Size = UDim2.new(0, 38, 0, 38)
BrandIcon.Position = UDim2.new(0, 16, 0.5, -19)
BrandIcon.BackgroundColor3 = COLORS.Accent
BrandIcon.BorderSizePixel = 0
BrandIcon.ZIndex = 4
BrandIcon.Parent = TopBar
corner(BrandIcon, 11)

local BrandGradient = Instance.new("UIGradient")
BrandGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.Accent),
    ColorSequenceKeypoint.new(1, COLORS.Accent2),
})
BrandGradient.Rotation = 35
BrandGradient.Parent = BrandIcon

local BrandText = Instance.new("TextLabel")
BrandText.Size = UDim2.fromScale(1, 1)
BrandText.BackgroundTransparency = 1
BrandText.Text = "VH"
BrandText.TextColor3 = Color3.new(1, 1, 1)
BrandText.TextSize = 14
BrandText.Font = Enum.Font.GothamBold
BrandText.ZIndex = 5
BrandText.Parent = BrandIcon

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -150, 0, 24)
Title.Position = UDim2.new(0, 66, 0, 14)
Title.BackgroundTransparency = 1
Title.Text = "VEHICLE HUB PRO"
Title.TextColor3 = COLORS.Text
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 4
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -150, 0, 18)
Subtitle.Position = UDim2.new(0, 66, 0, 38)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Vehicle utilities  •  Universal"
Subtitle.TextColor3 = COLORS.TextMuted
Subtitle.TextSize = 11
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 4
Subtitle.Parent = TopBar

local function createWindowButton(text, xOffset, danger)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 30, 0, 30)
    button.Position = UDim2.new(1, xOffset, 0, 14)
    button.BackgroundColor3 = danger and Color3.fromRGB(48, 28, 35) or Color3.fromRGB(28, 32, 43)
    button.Text = text
    button.TextColor3 = danger and COLORS.Danger or COLORS.TextMuted
    button.TextSize = text == "−" and 20 or 17
    button.Font = Enum.Font.GothamSemibold
    button.AutoButtonColor = false
    button.ZIndex = 5
    button.Parent = TopBar
    corner(button, 9)
    stroke(button, danger and Color3.fromRGB(88, 45, 56) or COLORS.Border, 1, 0.15)

    button.MouseEnter:Connect(function()
        tween(button, 0.15, {
            BackgroundColor3 = danger and Color3.fromRGB(69, 32, 42) or Color3.fromRGB(36, 42, 56),
            TextColor3 = danger and Color3.fromRGB(255, 143, 155) or COLORS.Text,
        })
    end)

    button.MouseLeave:Connect(function()
        tween(button, 0.15, {
            BackgroundColor3 = danger and Color3.fromRGB(48, 28, 35) or Color3.fromRGB(28, 32, 43),
            TextColor3 = danger and COLORS.Danger or COLORS.TextMuted,
        })
    end)
    return button
end

local MinimizeBtn = createWindowButton("−", -76, false)
local CloseBtn = createWindowButton("×", -40, true)

makeDraggable(MainFrame, TopBar, Shadow)

-- Área de información / búsqueda
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -72)
Content.Position = UDim2.new(0, 0, 0, 72)
Content.BackgroundTransparency = 1
Content.ZIndex = 2
Content.Parent = MainFrame

local SectionLabel = Instance.new("TextLabel")
SectionLabel.Size = UDim2.new(0.6, 0, 0, 18)
SectionLabel.Position = UDim2.new(0, 18, 0, 15)
SectionLabel.BackgroundTransparency = 1
SectionLabel.Text = "VEHICLE CONTROLS"
SectionLabel.TextColor3 = COLORS.TextMuted
SectionLabel.TextSize = 11
SectionLabel.Font = Enum.Font.GothamBold
SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
SectionLabel.ZIndex = 3
SectionLabel.Parent = Content

local ActivePill = Instance.new("Frame")
ActivePill.Size = UDim2.new(0, 78, 0, 24)
ActivePill.Position = UDim2.new(1, -96, 0, 12)
ActivePill.BackgroundColor3 = Color3.fromRGB(20, 35, 35)
ActivePill.BorderSizePixel = 0
ActivePill.ZIndex = 3
ActivePill.Parent = Content
corner(ActivePill, 12)
stroke(ActivePill, Color3.fromRGB(36, 74, 64), 1, 0.1)

local ActiveDot = Instance.new("Frame")
ActiveDot.Size = UDim2.new(0, 6, 0, 6)
ActiveDot.Position = UDim2.new(0, 11, 0.5, -3)
ActiveDot.BackgroundColor3 = COLORS.Success
ActiveDot.BorderSizePixel = 0
ActiveDot.ZIndex = 4
ActiveDot.Parent = ActivePill
corner(ActiveDot, 6)

local ActiveLabel = Instance.new("TextLabel")
ActiveLabel.Size = UDim2.new(1, -24, 1, 0)
ActiveLabel.Position = UDim2.new(0, 22, 0, 0)
ActiveLabel.BackgroundTransparency = 1
ActiveLabel.Text = "0 ACTIVE"
ActiveLabel.TextColor3 = Color3.fromRGB(175, 223, 204)
ActiveLabel.TextSize = 9
ActiveLabel.Font = Enum.Font.GothamBold
ActiveLabel.TextXAlignment = Enum.TextXAlignment.Left
ActiveLabel.ZIndex = 4
ActiveLabel.Parent = ActivePill

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.Size = UDim2.new(1, -36, 0, 38)
SearchBox.Position = UDim2.new(0, 18, 0, 46)
SearchBox.BackgroundColor3 = COLORS.Surface
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Buscar función..."
SearchBox.PlaceholderColor3 = COLORS.TextDim
SearchBox.Text = ""
SearchBox.TextColor3 = COLORS.Text
SearchBox.TextSize = 12
SearchBox.Font = Enum.Font.GothamMedium
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.ZIndex = 3
SearchBox.Parent = Content
corner(SearchBox, 10)
local SearchStroke = stroke(SearchBox, COLORS.BorderSoft, 1, 0.1)

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 13)
SearchPadding.PaddingRight = UDim.new(0, 13)
SearchPadding.Parent = SearchBox

SearchBox.Focused:Connect(function()
    tween(SearchStroke, 0.18, {Color = COLORS.Accent, Transparency = 0.05})
end)
SearchBox.FocusLost:Connect(function()
    tween(SearchStroke, 0.18, {Color = COLORS.BorderSoft, Transparency = 0.1})
end)

-- Lista de funciones
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "Features"
ScrollFrame.Size = UDim2.new(1, -24, 1, -102)
ScrollFrame.Position = UDim2.new(0, 12, 0, 94)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = compactMode and 3 or 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(72, 83, 105)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.ZIndex = 3
ScrollFrame.Parent = Content

local ScrollPadding = Instance.new("UIPadding")
ScrollPadding.PaddingTop = UDim.new(0, 2)
ScrollPadding.PaddingBottom = UDim.new(0, 8)
ScrollPadding.PaddingLeft = UDim.new(0, 6)
ScrollPadding.PaddingRight = UDim.new(0, 8)
ScrollPadding.Parent = ScrollFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = ScrollFrame

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 14)
end)

local toggleEntries = {}
local activeCount = 0

local function updateActiveCounter()
    ActiveLabel.Text = tostring(activeCount) .. " ACTIVE"
    tween(ActiveDot, 0.18, {
        BackgroundColor3 = activeCount > 0 and COLORS.Accent or COLORS.Success,
    })
end

-- ========================================================
-- SISTEMA DE TOGGLES MODERNO
-- ========================================================
local function createToggle(name, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, -2, 0, compactMode and 46 or 50)
    btn.BackgroundColor3 = COLORS.Surface
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 4
    btn.Parent = ScrollFrame
    corner(btn, 12)
    local btnStroke = stroke(btn, COLORS.BorderSoft, 1, 0.14)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 0, 22)
    accentBar.Position = UDim2.new(0, 0, 0.5, -11)
    accentBar.BackgroundColor3 = COLORS.Accent
    accentBar.BackgroundTransparency = 1
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 5
    accentBar.Parent = btn
    corner(accentBar, 3)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -84, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(210, 216, 230)
    label.TextSize = compactMode and 12 or 13
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 5
    label.Parent = btn

    local switchTrack = Instance.new("Frame")
    switchTrack.Size = UDim2.new(0, 42, 0, 22)
    switchTrack.Position = UDim2.new(1, -56, 0.5, -11)
    switchTrack.BackgroundColor3 = Color3.fromRGB(48, 54, 67)
    switchTrack.BorderSizePixel = 0
    switchTrack.ZIndex = 5
    switchTrack.Parent = btn
    corner(switchTrack, 11)

    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 16, 0, 16)
    switchKnob.Position = UDim2.new(0, 3, 0.5, -8)
    switchKnob.BackgroundColor3 = Color3.fromRGB(188, 195, 211)
    switchKnob.BorderSizePixel = 0
    switchKnob.ZIndex = 6
    switchKnob.Parent = switchTrack
    corner(switchKnob, 8)

    activeToggles[name] = false
    table.insert(toggleEntries, {button = btn, name = string.lower(name)})

    btn.MouseEnter:Connect(function()
        if not activeToggles[name] then
            tween(btn, 0.15, {BackgroundColor3 = COLORS.SurfaceHover})
            tween(btnStroke, 0.15, {Color = COLORS.Border, Transparency = 0.05})
        end
    end)

    btn.MouseLeave:Connect(function()
        if not activeToggles[name] then
            tween(btn, 0.15, {BackgroundColor3 = COLORS.Surface})
            tween(btnStroke, 0.15, {Color = COLORS.BorderSoft, Transparency = 0.14})
        end
    end)

    btn.MouseButton1Click:Connect(function()
        activeToggles[name] = not activeToggles[name]
        local state = activeToggles[name]
        activeCount = math.max(0, activeCount + (state and 1 or -1))
        updateActiveCounter()

        if state then
            tween(btn, 0.2, {BackgroundColor3 = COLORS.SurfaceActive})
            tween(btnStroke, 0.2, {Color = Color3.fromRGB(48, 91, 132), Transparency = 0.02})
            tween(label, 0.2, {TextColor3 = COLORS.Text})
            tween(accentBar, 0.2, {BackgroundTransparency = 0})
            tween(switchTrack, 0.2, {BackgroundColor3 = COLORS.Accent})
            tween(switchKnob, 0.22, {
                Position = UDim2.new(1, -19, 0.5, -8),
                BackgroundColor3 = Color3.new(1, 1, 1),
            }, Enum.EasingStyle.Back)
        else
            tween(btn, 0.2, {BackgroundColor3 = COLORS.Surface})
            tween(btnStroke, 0.2, {Color = COLORS.BorderSoft, Transparency = 0.14})
            tween(label, 0.2, {TextColor3 = Color3.fromRGB(210, 216, 230)})
            tween(accentBar, 0.2, {BackgroundTransparency = 1})
            tween(switchTrack, 0.2, {BackgroundColor3 = Color3.fromRGB(48, 54, 67)})
            tween(switchKnob, 0.22, {
                Position = UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(188, 195, 211),
            }, Enum.EasingStyle.Back)
        end

        callback(state)
    end)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(SearchBox.Text)
    for _, entry in ipairs(toggleEntries) do
        entry.button.Visible = query == "" or string.find(entry.name, query, 1, true) ~= nil
    end
end)

-- Círculo flotante moderno
local FloatingCircle = Instance.new("TextButton")
FloatingCircle.Name = "FloatingCircle"
FloatingCircle.Size = UDim2.new(0, 54, 0, 54)
FloatingCircle.Position = UDim2.new(0, 22, 0, 90)
FloatingCircle.BackgroundColor3 = COLORS.Surface
FloatingCircle.Text = "VH"
FloatingCircle.TextColor3 = COLORS.Text
FloatingCircle.TextSize = 15
FloatingCircle.Font = Enum.Font.GothamBold
FloatingCircle.AutoButtonColor = false
FloatingCircle.Visible = false
FloatingCircle.ZIndex = 20
FloatingCircle.Parent = ScreenGui
corner(FloatingCircle, 16)
local FloatStroke = stroke(FloatingCircle, COLORS.Accent, 1.5, 0)

local FloatGradient = Instance.new("UIGradient")
FloatGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 45)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 20, 29)),
})
FloatGradient.Rotation = 45
FloatGradient.Parent = FloatingCircle

local FloatScale = Instance.new("UIScale")
FloatScale.Scale = 1
FloatScale.Parent = FloatingCircle

FloatingCircle.MouseEnter:Connect(function()
    tween(FloatScale, 0.16, {Scale = 1.06})
    tween(FloatStroke, 0.16, {Color = COLORS.Accent2})
end)
FloatingCircle.MouseLeave:Connect(function()
    tween(FloatScale, 0.16, {Scale = 1})
    tween(FloatStroke, 0.16, {Color = COLORS.Accent})
end)

makeDraggable(FloatingCircle)

-- Animación inicial
MainFrame.Visible = true
Shadow.Visible = true
tween(MainScale, 0.38, {Scale = 1}, Enum.EasingStyle.Back)


-- ========================================================
-- FUNCIONES DE LOS HACKS
-- ========================================================

-- 1. ESP Vehicles
createToggle("ESP Vehicles", function(state)
    if state then
        addConnection("ESP", RunService.RenderStepped:Connect(function()
            for _, v in pairs(Workspace:GetDescendants()) do
                if v:IsA("VehicleSeat") and not v:FindFirstChild("ESP_Box") then
                    local box = Instance.new("BoxHandleAdornment")
                    box.Name = "ESP_Box"
                    box.Size = v.Parent:GetExtentsSize()
                    box.Adornee = v.Parent
                    box.AlwaysOnTop = true
                    box.ZIndex = 5
                    box.Transparency = 0.5
                    box.Color3 = Color3.fromRGB(0, 255, 255)
                    box.Parent = v
                end
            end
        end))
    else
        removeConnection("ESP")
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "ESP_Box" then v:Destroy() end
        end
    end
end)

-- 2. Zero Torque Delay
createToggle("Zero Torque Delay", function(state)
    if state then
        addConnection("ZeroTorque", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh then
                for _, part in pairs(veh:GetDescendants()) do
                    if part:IsA("CylindricalConstraint") or part:IsA("HingeConstraint") then
                        part.MotorMaxTorque = 999999999
                        part.MotorMaxAcceleration = 999999999
                    end
                end
            end
        end))
    else
        removeConnection("ZeroTorque")
    end
end)

-- 3. Freno Instantáneo (Spacebar)
local isBraking = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space then isBraking = true end
end)
UserInputService.InputEnded:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space then isBraking = false end
end)

createToggle("Freno Instantáneo", function(state)
    if state then
        addConnection("InstantBrake", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh and isBraking then
                veh.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                veh.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end))
    else
        removeConnection("InstantBrake")
    end
end)

-- 4. Velocidad
createToggle("Velocidad X2", function(state)
    if state then
        addConnection("SpeedHack", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh and veh.PrimaryPart and UserInputService:IsKeyDown(Enum.KeyCode.W) then
                veh.PrimaryPart.AssemblyLinearVelocity = veh.PrimaryPart.AssemblyLinearVelocity + (veh.PrimaryPart.CFrame.LookVector * 2)
            end
        end))
    else
        removeConnection("SpeedHack")
    end
end)

-- 5. Vuelo (Vehicle Fly)
createToggle("Vuelo", function(state)
    local veh = getCurrentVehicle()
    if state and veh then
        local bg = Instance.new("BodyGyro")
        bg.Name = "FlyGyro"
        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.P = 9e4
        bg.Parent = veh.PrimaryPart

        local bv = Instance.new("BodyVelocity")
        bv.Name = "FlyVelocity"
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Parent = veh.PrimaryPart

        addConnection("VehicleFly", RunService.Heartbeat:Connect(function()
            if not getCurrentVehicle() then return end
            local cam = Workspace.CurrentCamera
            bg.CFrame = cam.CFrame
            
            local dir = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            
            bv.Velocity = dir * 150 -- Velocidad de vuelo
        end))
    else
        removeConnection("VehicleFly")
        if veh and veh.PrimaryPart then
            if veh.PrimaryPart:FindFirstChild("FlyGyro") then veh.PrimaryPart.FlyGyro:Destroy() end
            if veh.PrimaryPart:FindFirstChild("FlyVelocity") then veh.PrimaryPart.FlyVelocity:Destroy() end
        end
    end
end)

-- 6. Vehicle Noclip
createToggle("Vehicle Noclip", function(state)
    if state then
        addConnection("VehNoclip", RunService.Stepped:Connect(function()
            local veh = getCurrentVehicle()
            if veh then
                for _, part in pairs(veh:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end))
    else
        removeConnection("VehNoclip")
    end
end)

-- 7. Anti-flip
createToggle("Anti-Flip", function(state)
    if state then
        addConnection("AntiFlip", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh and veh.PrimaryPart then
                local rot = veh.PrimaryPart.Orientation
                if math.abs(rot.Z) > 60 or math.abs(rot.X) > 60 then
                    veh.PrimaryPart.Rotation = Vector3.new(0, rot.Y, 0)
                    veh.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
                end
            end
        end))
    else
        removeConnection("AntiFlip")
    end
end)

-- 8. Nitro Infinito (Genérico)
createToggle("Nitro Infinito", function(state)
    if state then
        addConnection("InfNitro", RunService.Heartbeat:Connect(function()
            -- Lógica genérica: Intenta buscar valores llamados "Nitro" o "Boost" y mantenerlos al máximo
            local veh = getCurrentVehicle()
            if veh then
                for _, v in pairs(veh:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        if string.match(string.lower(v.Name), "nitro") or string.match(string.lower(v.Name), "boost") then
                            v.Value = 9999
                        end
                    end
                end
            end
        end))
    else
        removeConnection("InfNitro")
    end
end)

-- 9. Auto-fix
createToggle("Auto-fix", function(state)
    if state then
        addConnection("AutoFix", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh then
                -- Lógica genérica: Mantiene la salud del vehículo si usa un sistema de Health estándar
                local health = veh:FindFirstChild("Health") or veh:FindFirstChild("VehicleHealth")
                if health and health:IsA("NumberValue") then
                    health.Value = 9999
                end
            end
        end))
    else
        removeConnection("AutoFix")
    end
end)

-- 10. Ghost Mode
createToggle("Ghost Mode", function(state)
    if state then
        addConnection("GhostMode", RunService.RenderStepped:Connect(function()
            local veh = getCurrentVehicle()
            if veh then
                for _, part in pairs(veh:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 0.7
                        part.CanCollide = false
                    end
                end
            end
        end))
    else
        removeConnection("GhostMode")
        local veh = getCurrentVehicle()
        if veh then
            for _, part in pairs(veh:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 0
                    part.CanCollide = true
                end
            end
        end
    end
end)

-- 11. Drive on Water
createToggle("Drive on Water", function(state)
    if state then
        addConnection("WaterDrive", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh and veh.PrimaryPart then
                local rayOrigin = veh.PrimaryPart.Position
                local rayDirection = Vector3.new(0, -10, 0)
                
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {veh, LocalPlayer.Character}
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                raycastParams.IgnoreWater = false
                
                local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                if result and result.Material == Enum.Material.Water then
                    local velocity = veh.PrimaryPart.AssemblyLinearVelocity
                    veh.PrimaryPart.AssemblyLinearVelocity = Vector3.new(velocity.X, 5, velocity.Z)
                end
            end
        end))
    else
        removeConnection("WaterDrive")
    end
end)

-- 12. Vehículo Pesado
createToggle("Vehículo Pesado", function(state)
    local veh = getCurrentVehicle()
    if not veh then return end
    
    for _, part in pairs(veh:GetDescendants()) do
        if part:IsA("BasePart") then
            if state then
                part.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5) -- Densidad máxima
            else
                part.CustomPhysicalProperties = nil -- Vuelve a la normalidad
            end
        end
    end
end)

-- 13. Drift Mode
createToggle("Drift Mode", function(state)
    local veh = getCurrentVehicle()
    if not veh then return end
    
    for _, part in pairs(veh:GetDescendants()) do
        if part:IsA("BasePart") and (string.match(string.lower(part.Name), "wheel") or string.match(string.lower(part.Name), "tire")) then
            if state then
                part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0.5) -- Fricción muy baja
            else
                part.CustomPhysicalProperties = nil
            end
        end
    end
end)

-- 14. Infinite Fuel
createToggle("Infinite Fuel", function(state)
    if state then
        addConnection("InfFuel", RunService.Heartbeat:Connect(function()
            local veh = getCurrentVehicle()
            if veh then
                for _, v in pairs(veh:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        if string.match(string.lower(v.Name), "fuel") or string.match(string.lower(v.Name), "gas") then
                            v.Value = 100
                        end
                    end
                end
            end
        end))
    else
        removeConnection("InfFuel")
    end
end)


-- ========================================================
-- FUNCIONES DE VENTANA (MINIMIZAR, RESTAURAR Y CERRAR)
-- ========================================================
local windowBusy = false

local function showFloatingButton()
    FloatingCircle.Visible = true
    FloatScale.Scale = 0.72
    tween(FloatScale, 0.26, {Scale = 1}, Enum.EasingStyle.Back)
end

local function restoreMainWindow()
    if windowBusy then return end
    windowBusy = true

    FloatingCircle.Visible = false
    MainFrame.Visible = true
    Shadow.Visible = true
    MainScale.Scale = 0.88
    tween(MainScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)

    task.delay(0.3, function()
        windowBusy = false
    end)
end

MinimizeBtn.MouseButton1Click:Connect(function()
    if windowBusy then return end
    windowBusy = true

    tween(MainScale, 0.18, {Scale = 0.9}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.16, function()
        MainFrame.Visible = false
        Shadow.Visible = false
        MainScale.Scale = 1
        showFloatingButton()
        windowBusy = false
    end)
end)

FloatingCircle.MouseButton1Click:Connect(function()
    restoreMainWindow()
end)

CloseBtn.MouseButton1Click:Connect(function()
    if windowBusy then return end
    windowBusy = true

    tween(MainScale, 0.16, {Scale = 0.88}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tween(MainStroke, 0.16, {Transparency = 1})

    task.delay(0.14, function()
        -- Detener todos los bucles
        for name, connection in pairs(activeConnections) do
            connection:Disconnect()
        end
        activeConnections = {}

        -- Apagar variables de estado
        for name, _ in pairs(activeToggles) do
            activeToggles[name] = false
        end

        -- Limpiar rastros (ESP, BodyMovers, etc)
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "ESP_Box" then v:Destroy() end
        end

        local veh = getCurrentVehicle()
        if veh and veh.PrimaryPart then
            if veh.PrimaryPart:FindFirstChild("FlyGyro") then veh.PrimaryPart.FlyGyro:Destroy() end
            if veh.PrimaryPart:FindFirstChild("FlyVelocity") then veh.PrimaryPart.FlyVelocity:Destroy() end
        end

        ScreenGui:Destroy()
        print("[Vehicle Hub Pro] - Cerrado y funciones desactivadas.")
    end)
end)

