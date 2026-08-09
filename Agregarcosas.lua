local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Limpieza previa
if CoreGui:FindFirstChild("RuntimeErrorGUI") then
    CoreGui.RuntimeErrorGUI:Destroy()
end

-- == VARIABLES DE ESTADO ==
local States = {
    TriggerBot = false,
    Hitbox = false,
    HitboxSize = 5
}

-- == INTERFAZ GRÁFICA ==
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RuntimeErrorGUI"
ScreenGui.Parent = CoreGui
ScreenGui.DisplayOrder = 2147483647
ScreenGui.IgnoreGuiInset = true

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.BorderColor3 = Color3.fromRGB(138, 43, 226) -- Violeta neón
MainFrame.BorderSizePixel = 2
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -150)
MainFrame.Size = UDim2.new(0, 300, 0, 250) -- Reducido ya que quitamos el botón de aimbot
MainFrame.Active = true

local TitleBar = Instance.new("Frame")
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 30)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TitleBar
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Font = Enum.Font.Code
TitleLabel.Text = "Runtime Error // ZONE"
TitleLabel.TextColor3 = Color3.fromRGB(50, 205, 50) -- Verde lima
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = TitleBar
CloseBtn.BackgroundTransparency = 1
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
CloseBtn.TextSize = 14

local MinBtn = Instance.new("TextButton")
MinBtn.Parent = TitleBar
MinBtn.BackgroundTransparency = 1
MinBtn.Position = UDim2.new(1, -60, 0, 0)
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 18

local ButtonContainer = Instance.new("Frame")
ButtonContainer.Parent = MainFrame
ButtonContainer.BackgroundTransparency = 1
ButtonContainer.Position = UDim2.new(0, 0, 0, 40)
ButtonContainer.Size = UDim2.new(1, 0, 1, -40)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ButtonContainer
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 12)

local UIPadding = Instance.new("UIPadding")
UIPadding.Parent = ButtonContainer
UIPadding.PaddingTop = UDim.new(0, 10)

local function createFeatureButton(name, text)
    local Btn = Instance.new("TextButton")
    Btn.Name = name
    Btn.Parent = ButtonContainer
    Btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Btn.BorderColor3 = Color3.fromRGB(138, 43, 226)
    Btn.BorderSizePixel = 1
    Btn.Size = UDim2.new(0, 260, 0, 35)
    Btn.Font = Enum.Font.Code
    Btn.Text = text
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.TextSize = 14
    return Btn
end

local TriggerBotBtn = createFeatureButton("TriggerBotBtn", "Trigger Bot: OFF")
local HitboxBtn = createFeatureButton("HitboxBtn", "Hitbox Expander: OFF")

-- Slider UI para el Hitbox
local SliderContainer = Instance.new("Frame")
SliderContainer.Parent = ButtonContainer
SliderContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
SliderContainer.BorderColor3 = Color3.fromRGB(138, 43, 226)
SliderContainer.Size = UDim2.new(0, 260, 0, 40)

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Parent = SliderContainer
SliderLabel.BackgroundTransparency = 1
SliderLabel.Position = UDim2.new(0, 0, 0, 0)
SliderLabel.Size = UDim2.new(1, 0, 0, 20)
SliderLabel.Font = Enum.Font.Code
SliderLabel.Text = "Hitbox Size: 5"
SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderLabel.TextSize = 12

local SliderBG = Instance.new("Frame")
SliderBG.Parent = SliderContainer
SliderBG.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SliderBG.BorderSizePixel = 0
SliderBG.Position = UDim2.new(0.05, 0, 0.6, 0)
SliderBG.Size = UDim2.new(0.9, 0, 0, 8)

local SliderFill = Instance.new("Frame")
SliderFill.Parent = SliderBG
SliderFill.BackgroundColor3 = Color3.fromRGB(50, 205, 50) -- Verde lima
SliderFill.BorderSizePixel = 0
SliderFill.Size = UDim2.new((States.HitboxSize - 2) / 23, 0, 1, 0) -- Rango: 2 a 25

-- Circulo Flotante
local FloatingCircle = Instance.new("TextButton")
FloatingCircle.Name = "FloatingCircle"
FloatingCircle.Parent = ScreenGui
FloatingCircle.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
FloatingCircle.BorderColor3 = Color3.fromRGB(138, 43, 226)
FloatingCircle.BorderSizePixel = 2
FloatingCircle.Position = UDim2.new(0.05, 0, 0.05, 0)
FloatingCircle.Size = UDim2.new(0, 50, 0, 50)
FloatingCircle.Font = Enum.Font.Code
FloatingCircle.Text = "RE"
FloatingCircle.TextColor3 = Color3.fromRGB(50, 205, 50)
FloatingCircle.TextSize = 18
FloatingCircle.Visible = false
FloatingCircle.Active = true
Instance.new("UICorner", FloatingCircle).CornerRadius = UDim.new(1, 0)

-- == LÓGICA DE INTERFAZ ==
local function makeDraggable(guiObj, dragHandle)
    dragHandle = dragHandle or guiObj
    local dragging, dragInput, dragStart, startPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObj.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

makeDraggable(MainFrame, TitleBar)
makeDraggable(FloatingCircle)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; FloatingCircle.Visible = true end)
FloatingCircle.MouseButton1Click:Connect(function() FloatingCircle.Visible = false; MainFrame.Visible = true end)

local function toggleColor(btn, state)
    if state then
        btn.TextColor3 = Color3.fromRGB(50, 205, 50)
    else
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- == LÓGICA DE HACKS ==

-- 1. Trigger Bot Logic (Arreglado y optimizado)
local triggerCooldown = false
RunService.RenderStepped:Connect(function()
    if States.TriggerBot and not triggerCooldown then
        local target = Mouse.Target
        if target and target.Parent then
            local character = target.Parent
            -- Si el target es un accesorio o ropa, intentamos buscar el modelo del jugador principal
            if character:IsA("Accessory") or character:IsA("Model") and not character:FindFirstChild("Humanoid") then
                if character.Parent and character.Parent:FindFirstChild("Humanoid") then
                    character = character.Parent
                end
            end
            
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                -- Validar que no sea el jugador local
                local player = Players:GetPlayerFromCharacter(character)
                if player and player ~= LocalPlayer then
                    triggerCooldown = true
                    if mouse1click then 
                        mouse1click() 
                    end
                    task.wait(0.08) -- Pequeña pausa estable para evitar bloqueos por spam de clics
                    triggerCooldown = false
                end
            end
        end
    end
end)

TriggerBotBtn.MouseButton1Click:Connect(function()
    States.TriggerBot = not States.TriggerBot
    TriggerBotBtn.Text = "Trigger Bot: " .. (States.TriggerBot and "ON" or "OFF")
    toggleColor(TriggerBotBtn, States.TriggerBot)
end)

-- 2. Hitbox Expander Logic
local function updateHitboxes()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            if States.Hitbox then
                hrp.Size = Vector3.new(States.HitboxSize, States.HitboxSize, States.HitboxSize)
                hrp.Transparency = 0.6
                hrp.BrickColor = BrickColor.new("Bright purple")
                hrp.Material = Enum.Material.Neon
                hrp.CanCollide = false
            else
                hrp.Size = Vector3.new(2, 2, 1) -- Tamaño por defecto en Roblox
                hrp.Transparency = 1
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if States.Hitbox then
        updateHitboxes()
    end
end)

HitboxBtn.MouseButton1Click:Connect(function()
    States.Hitbox = not States.Hitbox
    HitboxBtn.Text = "Hitbox Expander: " .. (States.Hitbox and "ON" or "OFF")
    toggleColor(HitboxBtn, States.Hitbox)
    if not States.Hitbox then updateHitboxes() end -- Revertir al apagar
end)

-- 3. Lógica del Slider
local draggingSlider = false
SliderBG.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = UserInputService:GetMouseLocation().X
        local sliderPos = SliderBG.AbsolutePosition.X
        local sliderSize = SliderBG.AbsoluteSize.X
        
        local rawPercentage = (mousePos - sliderPos) / sliderSize
        local clampedPercentage = math.clamp(rawPercentage, 0, 1)
        
        SliderFill.Size = UDim2.new(clampedPercentage, 0, 1, 0)
        
        -- Mapear de porcentaje (0 - 1) a tamaño real (2 - 25)
        local minSize, maxSize = 2, 25
        States.HitboxSize = math.floor(minSize + ((maxSize - minSize) * clampedPercentage))
        SliderLabel.Text = "Hitbox Size: " .. States.HitboxSize
    end
end)
