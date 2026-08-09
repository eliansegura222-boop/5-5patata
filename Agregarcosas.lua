local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 1. CREACIÓN DE LA INTERFAZ
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CustomExploitGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999999 

local success, err = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not success then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ==========================================
-- 2. SISTEMA DE ARRASTRE
-- ==========================================
local function MakeDraggable(topbarObject, object)
    local dragging, dragInput, dragStart, startPos

    topbarObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topbarObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ==========================================
-- 3. DISEÑO DEL GUI Y BOTONES
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 320)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainUICorner = Instance.new("UICorner")
MainUICorner.CornerRadius = UDim.new(0, 8)
MainUICorner.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TopBar.Parent = MainFrame

local TopBarUICorner = Instance.new("UICorner")
TopBarUICorner.CornerRadius = UDim.new(0, 8)
TopBarUICorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Panel de Control"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -60, 0, 0)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 22
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = TopBar

local ButtonContainer = Instance.new("Frame")
ButtonContainer.Size = UDim2.new(1, -20, 1, -40)
ButtonContainer.Position = UDim2.new(0, 10, 0, 40)
ButtonContainer.BackgroundTransparency = 1
ButtonContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 12)
UIListLayout.Parent = ButtonContainer

-- Botón ESP
local EspBtn = Instance.new("TextButton")
EspBtn.Size = UDim2.new(1, 0, 0, 40)
EspBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
EspBtn.Text = "ESP HIGHLIGHTS: [OFF]"
EspBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
EspBtn.Font = Enum.Font.GothamSemibold
EspBtn.TextSize = 14
EspBtn.Parent = ButtonContainer
Instance.new("UICorner", EspBtn).CornerRadius = UDim.new(0, 6)

-- Botón Hitbox
local HitboxBtn = Instance.new("TextButton")
HitboxBtn.Size = UDim2.new(1, 0, 0, 40)
HitboxBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
HitboxBtn.Text = "HITBOX CABEZA: [OFF]"
HitboxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HitboxBtn.Font = Enum.Font.GothamSemibold
HitboxBtn.TextSize = 14
HitboxBtn.Parent = ButtonContainer
Instance.new("UICorner", HitboxBtn).CornerRadius = UDim.new(0, 6)

-- Slider Contenedor
local SliderContainer = Instance.new("Frame")
SliderContainer.Size = UDim2.new(1, 0, 0, 50)
SliderContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SliderContainer.Parent = ButtonContainer
Instance.new("UICorner", SliderContainer).CornerRadius = UDim.new(0, 6)

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 20)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "Tamaño Cabeza: 3"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.Font = Enum.Font.Gotham
SliderLabel.TextSize = 12
SliderLabel.Parent = SliderContainer

local SliderBackground = Instance.new("Frame")
SliderBackground.Size = UDim2.new(1, -20, 0, 8)
SliderBackground.Position = UDim2.new(0, 10, 0, 30)
SliderBackground.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SliderBackground.Parent = SliderContainer
Instance.new("UICorner", SliderBackground).CornerRadius = UDim.new(1, 0)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
SliderFill.Parent = SliderBackground
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

-- Círculo Flotante
local FloatingCircle = Instance.new("TextButton")
FloatingCircle.Size = UDim2.new(0, 50, 0, 50)
FloatingCircle.Position = UDim2.new(0.05, 0, 0.5, -25)
FloatingCircle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
FloatingCircle.Text = "⚡"
FloatingCircle.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatingCircle.TextSize = 20
FloatingCircle.Visible = false
FloatingCircle.Parent = ScreenGui
Instance.new("UICorner", FloatingCircle).CornerRadius = UDim.new(1, 0)

-- ==========================================
-- 4. LÓGICA DE INTERFAZ
-- ==========================================
MakeDraggable(TopBar, MainFrame)
MakeDraggable(FloatingCircle, FloatingCircle)

CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false FloatingCircle.Visible = true end)
FloatingCircle.MouseButton1Click:Connect(function() FloatingCircle.Visible = false MainFrame.Visible = true end)

-- Lógica Slider (Modificado máximo a 25)
local minSize, maxSize = 1, 25
local hitboxSize = 3
local sliderDragging = false

SliderBackground.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = input.Position.X
        local absPos = SliderBackground.AbsolutePosition.X
        local absSize = SliderBackground.AbsoluteSize.X
        local percentage = math.clamp((mousePos - absPos) / absSize, 0, 1)
        SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        hitboxSize = math.floor(minSize + ((maxSize - minSize) * percentage))
        SliderLabel.Text = "Tamaño Cabeza: " .. tostring(hitboxSize)
    end
end)

-- ==========================================
-- 5. LÓGICA ESP HIGHLIGHTS
-- ==========================================
local espActive = false
EspBtn.MouseButton1Click:Connect(function()
    espActive = not espActive
    if espActive then
        EspBtn.Text = "ESP HIGHLIGHTS: [ON]"
        EspBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
    else
        EspBtn.Text = "ESP HIGHLIGHTS: [OFF]"
        EspBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("CustomESP") then
                p.Character.CustomESP:Destroy()
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if espActive then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                if not p.Character:FindFirstChild("CustomESP") then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "CustomESP"
                    highlight.Adornee = p.Character
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.Parent = p.Character
                end
            end
        end
    end
end)

-- ==========================================
-- 6. LÓGICA HITBOX CABEZA (SIN LAG + VISUALIZADOR)
-- ==========================================
local hitboxActive = false
HitboxBtn.MouseButton1Click:Connect(function()
    hitboxActive = not hitboxActive
    if hitboxActive then
        HitboxBtn.Text = "HITBOX CABEZA: [ON]"
        HitboxBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
    else
        HitboxBtn.Text = "HITBOX CABEZA: [OFF]"
        HitboxBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        
        -- Restaurar las cabezas al apagar
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("Head") then
                local head = p.Character.Head
                head.Size = Vector3.new(2, 1, 1) -- Tamaño original
                head.Massless = false
                head.CanCollide = true
                
                -- Eliminar el visualizador (caja roja)
                if head:FindFirstChild("HitboxBox") then
                    head.HitboxBox:Destroy()
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if hitboxActive then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
                local head = p.Character.Head
                
                -- Extender hitbox
                head.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                
                -- EVITAR LAG Y QUE SE CONGELEN
                head.Massless = true
                head.CanCollide = false
                
                -- AGREGAR VISUALIZADOR (Caja roja semitransparente)
                if not head:FindFirstChild("HitboxBox") then
                    local box = Instance.new("SelectionBox")
                    box.Name = "HitboxBox"
                    box.Adornee = head
                    box.LineThickness = 0.05
                    box.Color3 = Color3.fromRGB(255, 0, 0)
                    box.SurfaceTransparency = 0.8
                    box.SurfaceColor3 = Color3.fromRGB(255, 0, 0)
                    box.Parent = head
                end
            end
        end
    end
end)
