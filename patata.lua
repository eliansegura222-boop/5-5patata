local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	local oldGui = playerGui:FindFirstChild("H3X4_X_Redirect")
	if oldGui then oldGui:Destroy() end
end)

pcall(function()
	local oldBlur = Lighting:FindFirstChild("H3X4_X_RedirectBlur")
	if oldBlur then oldBlur:Destroy() end
end)

local function corner(object, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
	return c
end

local function stroke(object, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(255, 255, 255)
	s.Transparency = transparency
	s.Thickness = thickness or 1
	s.Parent = object
	return s
end

local function gradient(object, colors, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(colors)
	g.Rotation = rotation or 0
	g.Parent = object
	return g
end

local function tween(object, time, properties, style, direction)
	local t = TweenService:Create(
		object,
		TweenInfo.new(time, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
		properties
	)
	t:Play()
	return t
end

local gui = Instance.new("ScreenGui")
gui.Name = "H3X4_X_Redirect"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local blur = Instance.new("BlurEffect")
blur.Name = "H3X4_X_RedirectBlur"
blur.Size = 0
blur.Parent = Lighting
tween(blur, 0.45, {Size = 38})

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
root.BorderSizePixel = 0
root.Parent = gui

local bgBase = Instance.new("Frame")
bgBase.Name = "BgBase"
bgBase.Size = UDim2.new(1, 0, 1, 0)
bgBase.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bgBase.BorderSizePixel = 0
bgBase.Parent = root

local bgGradient = gradient(bgBase, {
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 6, 6)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
}, 90)

local vignette = Instance.new("Frame")
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 0.15
vignette.BorderSizePixel = 0
vignette.Parent = root
local vignetteGradient = gradient(vignette, {
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(12, 12, 12)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(12, 12, 12)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
}, 0)
vignetteGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.5, 0.55),
	NumberSequenceKeypoint.new(1, 0.15),
})

local motionLayer = Instance.new("Frame")
motionLayer.Name = "MotionLayer"
motionLayer.BackgroundTransparency = 1
motionLayer.Size = UDim2.new(1, 0, 1, 0)
motionLayer.Parent = root

local stripeInfo = {}
for i = 1, 16 do
	local stripe = Instance.new("Frame")
	stripe.AnchorPoint = Vector2.new(0.5, 0.5)
	stripe.Size = UDim2.fromOffset(3, 420 + (i % 4) * 120)
	stripe.Position = UDim2.new((i - 1) / 15, 0, 0.5, 0)
	stripe.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	stripe.BackgroundTransparency = 0.965 - (i % 3) * 0.008
	stripe.BorderSizePixel = 0
	stripe.Rotation = 24
	stripe.Parent = motionLayer
	stripeInfo[#stripeInfo + 1] = {
		Object = stripe,
		Speed = 5 + i * 0.22,
		Phase = i * 0.31,
		BaseX = (i - 1) / 15,
	}
end

local gridLayer = Instance.new("Frame")
gridLayer.Name = "GridLayer"
gridLayer.BackgroundTransparency = 1
gridLayer.Size = UDim2.new(1, 0, 1, 0)
gridLayer.Parent = root

local gridHolder = Instance.new("Frame")
gridHolder.AnchorPoint = Vector2.new(0.5, 0.5)
gridHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
gridHolder.Size = UDim2.new(1.3, 0, 1.3, 0)
gridHolder.BackgroundTransparency = 1
gridHolder.Rotation = 10
gridHolder.Parent = gridLayer

local gridLines = {}
for i = 0, 28 do
	local v = Instance.new("Frame")
	v.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	v.BackgroundTransparency = 0.972
	v.BorderSizePixel = 0
	v.Size = UDim2.new(0, 1, 1, 0)
	v.Position = UDim2.new(i / 28, 0, 0, 0)
	v.Parent = gridHolder
	gridLines[#gridLines + 1] = {"v", v}
end

for i = 0, 18 do
	local h = Instance.new("Frame")
	h.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	h.BackgroundTransparency = 0.975
	h.BorderSizePixel = 0
	h.Size = UDim2.new(1, 0, 0, 1)
	h.Position = UDim2.new(0, 0, i / 18, 0)
	h.Parent = gridHolder
	gridLines[#gridLines + 1] = {"h", h}
end

local particleLayer = Instance.new("Frame")
particleLayer.Name = "ParticleLayer"
particleLayer.BackgroundTransparency = 1
particleLayer.Size = UDim2.new(1, 0, 1, 0)
particleLayer.Parent = root

local rng = Random.new()
local particleInfo = {}
for i = 1, 86 do
	local dot = Instance.new("Frame")
	local size = rng:NextInteger(1, 3)
	dot.Size = UDim2.fromOffset(size, size)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(rng:NextNumber(), 0, rng:NextNumber(), 0)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = rng:NextNumber(0.30, 0.88)
	dot.BorderSizePixel = 0
	dot.Parent = particleLayer
	corner(dot, 999)
	particleInfo[#particleInfo + 1] = {
		Object = dot,
		X = dot.Position.X.Scale,
		Y = dot.Position.Y.Scale,
		Speed = rng:NextNumber(0.010, 0.040),
		Drift = rng:NextNumber(-0.020, 0.020),
		Pulse = rng:NextNumber(0.8, 2.2),
		Phase = rng:NextNumber(0, 6.28),
		BaseTransparency = dot.BackgroundTransparency,
	}
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 0, 0, 0)
panel.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
panel.BackgroundTransparency = 0.03
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = root
corner(panel, 24)
local panelStroke = stroke(panel, 0.18, 1.5)

local panelGlow = stroke(panel, 0.76, 3)
panelGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local panelSheen = Instance.new("Frame")
panelSheen.Name = "PanelSheen"
panelSheen.AnchorPoint = Vector2.new(0.5, 0.5)
panelSheen.Position = UDim2.new(-0.15, 0, 0.5, 0)
panelSheen.Size = UDim2.new(0, 110, 1.4, 0)
panelSheen.Rotation = 20
panelSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panelSheen.BackgroundTransparency = 1
panelSheen.BorderSizePixel = 0
panelSheen.Parent = panel
gradient(panelSheen, {
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
}, 90).Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.92),
	NumberSequenceKeypoint.new(1, 1),
})

local inner = Instance.new("Frame")
inner.Name = "Inner"
inner.Position = UDim2.new(0, 10, 0, 10)
inner.Size = UDim2.new(1, -20, 1, -20)
inner.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
inner.BackgroundTransparency = 0.10
inner.BorderSizePixel = 0
inner.ClipsDescendants = true
inner.Parent = panel
corner(inner, 18)
stroke(inner, 0.62, 1)

local panelBg = Instance.new("Frame")
panelBg.Name = "PanelBg"
panelBg.Size = UDim2.new(1, 0, 1, 0)
panelBg.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
panelBg.BackgroundTransparency = 0.20
panelBg.BorderSizePixel = 0
panelBg.Parent = inner
gradient(panelBg, {
	ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 6, 6)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 12, 12)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 6))
}, 90)

local logoMark = Instance.new("ImageLabel")
logoMark.Position = UDim2.new(0, 18, 0, 31)
logoMark.Size = UDim2.fromOffset(46, 46)
logoMark.BackgroundTransparency = 1
logoMark.BorderSizePixel = 0
logoMark.Image = "rbxassetid://72742584610344"
logoMark.ImageColor3 = Color3.fromRGB(255, 255, 255)
logoMark.ScaleType = Enum.ScaleType.Fit
logoMark.Parent = inner

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 78, 0, 32)
title.Size = UDim2.new(1, -88, 0, 28)
title.Text = "H3XA"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 20
title.Font = Enum.Font.GothamSemibold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = inner

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 78, 0, 58)
subtitle.Size = UDim2.new(1, -88, 0, 18)
subtitle.Text = "UNIVERSAL ACCESS"
subtitle.TextColor3 = Color3.fromRGB(168, 168, 168)
subtitle.TextSize = 10
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = inner

local textCard = Instance.new("Frame")
textCard.Position = UDim2.new(0, 18, 0, 92)
textCard.Size = UDim2.new(1, -36, 0, 154)
textCard.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
textCard.BackgroundTransparency = 0.15
textCard.BorderSizePixel = 0
textCard.Parent = inner
corner(textCard, 14)
stroke(textCard, 0.70, 1)

local message = Instance.new("TextLabel")
message.BackgroundTransparency = 1
message.Position = UDim2.new(0, 16, 0, 12)
message.Size = UDim2.new(1, -32, 1, -24)
message.Text =
	"HEXA ya no es una comunidad de un solo script.\n\n" ..
	"Ahora cuenta con varios proyectos y un sistema universal, por lo que este acceso ha sido movido a un nuevo lugar.\n\n" ..
	"Copia una de las opciones de abajo para continuar."
message.TextColor3 = Color3.fromRGB(226, 226, 226)
message.TextSize = 13
message.Font = Enum.Font.Gotham
message.TextWrapped = true
message.TextXAlignment = Enum.TextXAlignment.Left
message.TextYAlignment = Enum.TextYAlignment.Top
message.Parent = textCard

local function createButton(text, yOffset)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -36, 0, 48)
	holder.Position = UDim2.new(0, 18, 1, yOffset)
	holder.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
	holder.BackgroundTransparency = 0.05
	holder.BorderSizePixel = 0
	holder.Parent = inner
	corner(holder, 14)
	stroke(holder, 0.48, 1)

	local glow = stroke(holder, 0.82, 2)
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.new(-0.2, 0, 0.5, 0)
	shine.Size = UDim2.new(0, 58, 1.6, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 1
	shine.BorderSizePixel = 0
	shine.Rotation = 18
	shine.Parent = holder
	gradient(shine, {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
	}, 90).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.94),
		NumberSequenceKeypoint.new(1, 1),
	})

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.Font = Enum.Font.Gotham
	button.AutoButtonColor = false
	button.Parent = holder

	return holder, button, shine
end

local discordHolder, discordButton, discordShine = createButton("COPIAR DISCORD", -124)
local scriptHolder, scriptButton, scriptShine = createButton("COPIAR NUEVO SCRIPT", -68)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -18, 0, 18)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BorderSizePixel = 0
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(8, 8, 8)
closeButton.TextSize = 20
closeButton.Font = Enum.Font.Gotham
closeButton.Visible = false
closeButton.AutoButtonColor = false
closeButton.Parent = inner
corner(closeButton, 11)

local closeGlow = stroke(closeButton, 0.72, 2)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 18, 1, -22)
status.Size = UDim2.new(1, -36, 0, 14)
status.Text = ""
status.TextColor3 = Color3.fromRGB(165, 165, 165)
status.TextSize = 9
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Center
status.Parent = inner

local copiedSomething = false
local closing = false
local discordUrl = "https://discord.gg/sewRzHAG5J"
local newScript = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/NonyH/universalh3xa/refs/heads/main/loader1.lua"))()'

local function setButtonHover(holder, shine)
	local baseColor = Color3.fromRGB(9, 9, 9)
	local hoverColor = Color3.fromRGB(18, 18, 18)

	holder.MouseEnter:Connect(function()
		tween(holder, 0.16, {BackgroundColor3 = hoverColor})
		shine.BackgroundTransparency = 0.96
	end)

	holder.MouseLeave:Connect(function()
		tween(holder, 0.16, {BackgroundColor3 = baseColor})
		shine.BackgroundTransparency = 1
	end)
end

setButtonHover(discordHolder, discordShine)
setButtonHover(scriptHolder, scriptShine)

local function copyText(value)
	local copier = nil
	pcall(function()
		if type(setclipboard) == "function" then
			copier = setclipboard
		elseif type(toclipboard) == "function" then
			copier = toclipboard
		elseif type(Clipboard) == "table" and type(Clipboard.set) == "function" then
			copier = Clipboard.set
		end
	end)

	if type(copier) ~= "function" then
		status.Text = "TU EJECUTOR NO PERMITE COPIAR AL PORTAPAPELES"
		return false
	end

	local ok = pcall(function()
		copier(value)
	end)

	if ok then
		copiedSomething = true
		closeButton.Visible = true
		status.Text = "COPIADO CORRECTAMENTE · YA PUEDES CERRAR"
		tween(closeButton, 0.18, {BackgroundTransparency = 0})
		return true
	end

	status.Text = "NO SE PUDO COPIAR"
	return false
end

discordButton.MouseButton1Click:Connect(function()
	copyText(discordUrl)
end)

scriptButton.MouseButton1Click:Connect(function()
	copyText(newScript)
end)

local connections = {}
connections[#connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if copiedSomething and input.KeyCode == Enum.KeyCode.Escape then
		closeButton:Activate()
	end
end)

local function cleanup()
	for _, connection in ipairs(connections) do
		pcall(function() connection:Disconnect() end)
	end
end

local function closeInterface()
	if closing or not copiedSomething then return end
	closing = true
	cleanup()
	tween(blur, 0.28, {Size = 0})
	local t = tween(panel, 0.26, {Size = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	t.Completed:Connect(function()
		pcall(function() blur:Destroy() end)
		pcall(function() gui:Destroy() end)
	end)
end

closeButton.MouseButton1Click:Connect(closeInterface)

local timePosition = 0
connections[#connections + 1] = RunService.RenderStepped:Connect(function(dt)
	timePosition += dt

	bgGradient.Offset = Vector2.new(math.sin(timePosition * 0.12) * 0.08, 0)
	vignetteGradient.Offset = Vector2.new(math.cos(timePosition * 0.07) * 0.06, 0)

	for _, data in ipairs(stripeInfo) do
		local sway = math.sin(timePosition * data.Speed * 0.15 + data.Phase) * 0.03
		data.Object.Position = UDim2.new(data.BaseX + sway, 0, 0.5, 0)
	end


	for _, data in ipairs(particleInfo) do
		local dot = data.Object
		data.Y -= data.Speed * dt
		data.X += data.Drift * dt

		if data.Y < -0.03 then
			data.Y = 1.03
			data.X = rng:NextNumber()
		end
		if data.X < -0.03 then data.X = 1.03 end
		if data.X > 1.03 then data.X = -0.03 end

		dot.Position = UDim2.new(data.X, 0, data.Y, 0)
		dot.BackgroundTransparency = math.clamp(
			data.BaseTransparency + math.sin(timePosition * data.Pulse + data.Phase) * 0.12,
			0.22,
			0.92
		)
	end

	panelSheen.Position = UDim2.new((timePosition * 0.16) % 1.4 - 0.2, 0, 0.5, 0)
	discordShine.Position = UDim2.new((timePosition * 0.42) % 1.5 - 0.25, 0, 0.5, 0)
	scriptShine.Position = UDim2.new((timePosition * 0.38) % 1.5 - 0.25, 0, 0.5, 0)

	panelGlow.Transparency = 0.74 + math.sin(timePosition * 1.7) * 0.06
	closeGlow.Transparency = 0.72 + math.sin(timePosition * 2.0) * 0.10
end)

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
local mobile = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or viewport.X < 900)

local targetWidth = mobile and math.min(382, math.max(300, viewport.X - 18)) or 500
local targetHeight = mobile and math.min(420, math.max(360, viewport.Y - 26)) or 410

tween(panel, 0.50, {Size = UDim2.fromOffset(targetWidth, targetHeight)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
