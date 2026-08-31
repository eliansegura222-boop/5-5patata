--[[
	HEXA | +1 Speed Monkey Escape Hub | v37 Device Detection + Mobile Fix | Keyless

	Features:
	  - Auto Farm Wins (touch replication, no course running)
	  - Batch 1: Auto Farm Steps / best treadmill / treadmill selector / run in place
	  - Batch 1: World selector / Stage selector / Auto Best Stage
	  - Batch 1: Auto Equip Best Trail / Aura / Auto Buy Charms
	  - Stay Still + adjustable farm delay slider
	  - Auto Buy Trails / Auras / Upgrades
	  - Auto Rebirth / Auto Best World
	  - Auto Join Race / Auto Win Race
	  - Expanded Player movement: High Jump / Long Jump / Bunny Hop / Dash / Gravity / Hip Height
	  - God Mode
	  - Auto Collect Bananas / Tacos / Lucky Blocks / Hacker Portals
		  - Auto Free Reward / Offline Earnings / Streak Rewards
	  - Auto Equip Best Charms / Auto Use Potions
	
	Languages: Spanish / English
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local InputService = game:GetService("UserInputService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ================= DEVICE DETECTION =================
-- Do not infer the device only from viewport width. Mobile executors/tablets can
-- report unusual resolutions, so platform + touch capability are checked first.
local function detectHexaDevice()
	local platformName = ""
	pcall(function()
		platformName = tostring(InputService:GetPlatform())
	end)

	local mobilePlatform = platformName:find("Android", 1, true)
		or platformName:find("IOS", 1, true)
		or platformName:find("iOS", 1, true)

	if mobilePlatform then
		return "Mobile"
	end

	-- Strong fallback for executors where GetPlatform is unavailable/obfuscated.
	if InputService.TouchEnabled and not InputService.KeyboardEnabled then
		return "Mobile"
	end

	-- A mobile device can expose a software/virtual keyboard as KeyboardEnabled.
	-- In that case touch + a phone/tablet-sized viewport is the safest fallback.
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1000, 700)
	if InputService.TouchEnabled and math.min(vp.X, vp.Y) <= 700 then
		return "Mobile"
	end

	return "PC"
end

local HEXA_DEVICE = detectHexaDevice()
local HEXA_MOBILE = HEXA_DEVICE == "Mobile"

-- ================= LANGUAGE -> PLACE ID PREFLIGHT =================
-- Language is resolved before loading any +1 Speed Monkey Escape-only objects.
local TARGET_PLACE_ID = 114697347887839
local PREFLIGHT_LANGUAGE_FILE = "hexa_language_pref.json"
local TweenServicePreflight = game:GetService("TweenService")

local PREFLIGHT_THEME = {
	Black = Color3.fromRGB(2, 2, 2),
	Panel = Color3.fromRGB(12, 7, 4),
	Panel2 = Color3.fromRGB(24, 11, 5),
	Card = Color3.fromRGB(36, 16, 7),
	CardHover = Color3.fromRGB(48, 21, 8),
	Brown = Color3.fromRGB(112, 48, 14),
	Brown2 = Color3.fromRGB(194, 83, 20),
	BrownNeon = Color3.fromRGB(255, 118, 20),
	White = Color3.fromRGB(255, 252, 247),
	Muted = Color3.fromRGB(199, 180, 163),
	Line = Color3.fromRGB(122, 53, 18),
}

local function preflightParent(gui)
	local ok = pcall(function()
		gui.Parent = (gethui and gethui()) or game.CoreGui
	end)
	if not ok then
		gui.Parent = game.CoreGui
	end
end

local function preflightDestroy(name)
	pcall(function()
		local parent = (gethui and gethui()) or game.CoreGui
		local old = parent:FindFirstChild(name)
		if old then old:Destroy() end
	end)
end

local function preflightCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function preflightStroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function preflightTween(obj, duration, props, style)
	local tw = TweenServicePreflight:Create(obj, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function preflightLoadLanguage()
	if not (readfile and isfile and isfile(PREFLIGHT_LANGUAGE_FILE)) then return nil end
	local ok, content = pcall(readfile, PREFLIGHT_LANGUAGE_FILE)
	if not ok or not content or content == "" then return nil end
	local okData, data = pcall(function() return HttpService:JSONDecode(content) end)
	if okData and type(data) == "table" and data.remember and (data.language == "es" or data.language == "en") then
		return data.language
	end
	return nil
end

local function preflightSaveLanguage(code, remember)
	if remember then
		if writefile then
			pcall(function()
				writefile(PREFLIGHT_LANGUAGE_FILE, HttpService:JSONEncode({ remember = true, language = code }))
			end)
		end
	elseif delfile and isfile and isfile(PREFLIGHT_LANGUAGE_FILE) then
		pcall(delfile, PREFLIGHT_LANGUAGE_FILE)
	end
end

local function showPreflightLanguagePicker()
	local remembered = preflightLoadLanguage()
	if remembered then return remembered end

	preflightDestroy("HexaLanguagePremium")
	local selectedEvent = Instance.new("BindableEvent")
	local selectedLanguage = nil
	local rememberValue = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "HexaLanguagePremium"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2147483647
	preflightParent(gui)

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = PREFLIGHT_THEME.Black
	dim.BackgroundTransparency = 0.16
	dim.BorderSizePixel = 0
	dim.Parent = gui

	for i = 1, 3 do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.25 + (i - 1) * 0.25)
		band.Size = UDim2.new(1.35, 0, 0, 1)
		band.Rotation = -7
		band.BackgroundColor3 = PREFLIGHT_THEME.Brown
		band.BackgroundTransparency = 0.76 + (i - 1) * 0.06
		band.BorderSizePixel = 0
		band.Parent = dim
	end

	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(900, 600)
	local compact = HEXA_MOBILE
	local w = compact and math.min(326, math.max(270, vp.X - 42)) or math.min(430, math.max(290, vp.X - 28))
	local h = compact and math.min(312, math.max(270, vp.Y - 92)) or math.min(320, math.max(280, vp.Y - 60))

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = PREFLIGHT_THEME.Panel
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = dim
	preflightCorner(frame, 22)
	preflightStroke(frame, PREFLIGHT_THEME.BrownNeon, 0.20, 1.4)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.88
	scale.Parent = frame

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Position = UDim2.fromOffset(24, 18)
	brand.Size = UDim2.new(1, -48, 0, 34)
	brand.Font = Enum.Font.GothamBold
	brand.Text = "HEXA"
	brand.TextColor3 = PREFLIGHT_THEME.White
	brand.TextSize = compact and 24 or 28
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(24, 48)
	sub.Size = UDim2.new(1, -48, 0, 20)
	sub.Font = Enum.Font.GothamMedium
	sub.Text = "ENGLISH / ESPAÑOL"
	sub.TextColor3 = PREFLIGHT_THEME.BrownNeon
	sub.TextSize = compact and 10 or 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = frame

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(24, 78)
	divider.Size = UDim2.new(1, -48, 0, 1)
	divider.BackgroundColor3 = PREFLIGHT_THEME.Line
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local choose = Instance.new("TextLabel")
	choose.BackgroundTransparency = 1
	choose.Position = UDim2.fromOffset(24, 90)
	choose.Size = UDim2.new(1, -48, 0, 22)
	choose.Font = Enum.Font.GothamBold
	choose.Text = "SELECT LANGUAGE / SELECCIONA IDIOMA"
	choose.TextColor3 = PREFLIGHT_THEME.Muted
	choose.TextSize = compact and 11 or 12
	choose.TextXAlignment = Enum.TextXAlignment.Left
	choose.Parent = frame

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(24, 120)
	list.Size = UDim2.new(1, -48, 0, 118)
	list.Parent = frame
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = list

	local rememberCard = Instance.new("Frame")
	rememberCard.AnchorPoint = Vector2.new(0, 1)
	rememberCard.Position = UDim2.new(0, 24, 1, -18)
	rememberCard.Size = UDim2.new(1, -48, 0, 46)
	rememberCard.BackgroundColor3 = PREFLIGHT_THEME.Card
	rememberCard.BorderSizePixel = 0
	rememberCard.Parent = frame
	preflightCorner(rememberCard, 14)
	preflightStroke(rememberCard, PREFLIGHT_THEME.Line, 0.52, 0.8)

	local rememberText = Instance.new("TextLabel")
	rememberText.BackgroundTransparency = 1
	rememberText.Position = UDim2.fromOffset(14, 0)
	rememberText.Size = UDim2.new(1, -88, 1, 0)
	rememberText.Font = Enum.Font.GothamMedium
	rememberText.Text = "Remember / Recordar"
	rememberText.TextColor3 = PREFLIGHT_THEME.White
	rememberText.TextSize = compact and 11 or 12
	rememberText.TextXAlignment = Enum.TextXAlignment.Left
	rememberText.Parent = rememberCard

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Position = UDim2.new(1, -12, 0.5, 0)
	toggle.Size = UDim2.fromOffset(50, 26)
	toggle.BackgroundColor3 = PREFLIGHT_THEME.Panel2
	toggle.BorderSizePixel = 0
	toggle.Text = ""
	toggle.AutoButtonColor = false
	toggle.Parent = rememberCard
	preflightCorner(toggle, 99)
	preflightStroke(toggle, PREFLIGHT_THEME.Line, 0.56, 0.8)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = PREFLIGHT_THEME.White
	knob.BorderSizePixel = 0
	knob.Parent = toggle
	preflightCorner(knob, 99)

	local function refreshRemember()
		preflightTween(toggle, 0.15, { BackgroundColor3 = rememberValue and PREFLIGHT_THEME.Brown or PREFLIGHT_THEME.Panel2 })
		preflightTween(knob, 0.15, { Position = rememberValue and UDim2.fromOffset(27, 3) or UDim2.fromOffset(3, 3) })
	end
	toggle.Activated:Connect(function()
		rememberValue = not rememberValue
		refreshRemember()
	end)

	local langs = {
		{ code = "es", label = "Español" },
		{ code = "en", label = "English" },
	}
	for i, lang in ipairs(langs) do
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = i
		btn.Size = UDim2.new(1, 0, 0, compact and 50 or 54)
		btn.BackgroundColor3 = PREFLIGHT_THEME.Card
		btn.BorderSizePixel = 0
		btn.Text = lang.label
		btn.Font = Enum.Font.GothamMedium
		btn.TextColor3 = PREFLIGHT_THEME.White
		btn.TextSize = compact and 14 or 15
		btn.AutoButtonColor = false
		btn.Parent = list
		preflightCorner(btn, 14)
		local st = preflightStroke(btn, PREFLIGHT_THEME.Line, 0.54, 0.8)
		btn.MouseEnter:Connect(function()
			preflightTween(btn, 0.15, { BackgroundColor3 = PREFLIGHT_THEME.CardHover })
			st.Color = PREFLIGHT_THEME.Brown2
		end)
		btn.MouseLeave:Connect(function()
			preflightTween(btn, 0.15, { BackgroundColor3 = PREFLIGHT_THEME.Card })
			st.Color = PREFLIGHT_THEME.Line
		end)
		btn.Activated:Connect(function()
			if selectedLanguage then return end
			selectedLanguage = lang.code
			preflightSaveLanguage(lang.code, rememberValue)
			preflightTween(scale, 0.14, { Scale = 0.90 })
			preflightTween(dim, 0.14, { BackgroundTransparency = 1 })
			task.delay(0.12, function()
				if gui and gui.Parent then gui:Destroy() end
				selectedEvent:Fire(lang.code)
			end)
		end)
	end

	preflightTween(scale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
	local code = selectedEvent.Event:Wait()
	selectedEvent:Destroy()
	return code
end

local PREFLIGHT_LANGUAGE = showPreflightLanguagePicker()

local function showWrongGame(languageCode)
	preflightDestroy("HexaWrongGame")
	local english = languageCode == "en"
	local titleText = english and "WRONG GAME" or "JUEGO INCORRECTO"
	local descText = english
		and "This script only works in +1 Speed Monkey Escape.\nPress GO TO GAME to enter the correct experience."
		or "Este script solo funciona en +1 Speed Monkey Escape.\nPulsa IR AL JUEGO para entrar al juego correcto."
	local goText = english and "GO TO GAME" or "IR AL JUEGO"
	local enteringText = english and "JOINING..." or "ENTRANDO..."

	local gui = Instance.new("ScreenGui")
	gui.Name = "HexaWrongGame"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2147483647
	preflightParent(gui)

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = PREFLIGHT_THEME.Black
	dim.BackgroundTransparency = 0.22
	dim.BorderSizePixel = 0
	dim.Parent = gui

	for i = 1, 3 do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.27 + (i - 1) * 0.23)
		band.Size = UDim2.new(1.35, 0, 0, 1)
		band.Rotation = -7
		band.BackgroundColor3 = PREFLIGHT_THEME.Brown
		band.BackgroundTransparency = 0.78 + (i - 1) * 0.05
		band.BorderSizePixel = 0
		band.Parent = dim
	end

	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(900, 600)
	local compact = HEXA_MOBILE
	local w = compact and math.min(282, math.max(250, vp.X - 54)) or math.min(420, math.max(300, vp.X - 34))
	local h = compact and 214 or 265

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = PREFLIGHT_THEME.Panel
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = dim
	preflightCorner(frame, 22)
	preflightStroke(frame, PREFLIGHT_THEME.BrownNeon, 0.20, 1.4)

	local scale = Instance.new("UIScale")
	scale.Scale = compact and 0.86 or 0.82
	scale.Parent = frame

	-- Close button for the wrong-game panel (works on touch and mouse).
	local closeWrongGame = Instance.new("TextButton")
	closeWrongGame.Name = "Close"
	closeWrongGame.AnchorPoint = Vector2.new(1, 0)
	closeWrongGame.Position = UDim2.new(1, -12, 0, 12)
	closeWrongGame.Size = UDim2.fromOffset(compact and 30 or 34, compact and 30 or 34)
	closeWrongGame.BackgroundColor3 = PREFLIGHT_THEME.Panel2
	closeWrongGame.BorderSizePixel = 0
	closeWrongGame.AutoButtonColor = false
	closeWrongGame.Text = "×"
	closeWrongGame.TextColor3 = PREFLIGHT_THEME.White
	closeWrongGame.TextSize = compact and 17 or 19
	closeWrongGame.Font = Enum.Font.GothamBold
	closeWrongGame.ZIndex = 10
	closeWrongGame.Parent = frame
	preflightCorner(closeWrongGame, 10)
	preflightStroke(closeWrongGame, PREFLIGHT_THEME.Line, 0.48, 0.8)
	closeWrongGame.Activated:Connect(function()
		if gui and gui.Parent then
			gui:Destroy()
		end
	end)

	local logo = Instance.new("ImageLabel")
	logo.BackgroundTransparency = 1
	logo.Image = "rbxassetid://80552458381492"
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Size = UDim2.fromOffset(compact and 50 or 58, compact and 50 or 58)
	logo.Position = UDim2.fromOffset(18, 14)
	logo.Parent = frame

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Position = UDim2.fromOffset(compact and 76 or 86, 14)
	brand.Size = UDim2.new(1, -(compact and 96 or 108), 0, 30)
	brand.Font = Enum.Font.GothamBold
	brand.Text = "HEXA"
	brand.TextColor3 = PREFLIGHT_THEME.White
	brand.TextSize = compact and 21 or 24
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.Parent = frame

	local gameLabel = Instance.new("TextLabel")
	gameLabel.BackgroundTransparency = 1
	gameLabel.Position = UDim2.fromOffset(compact and 76 or 86, 42)
	gameLabel.Size = UDim2.new(1, -(compact and 96 or 108), 0, 22)
	gameLabel.Font = Enum.Font.GothamMedium
	gameLabel.Text = "+1 SPEED MONKEY ESCAPE"
	gameLabel.TextColor3 = PREFLIGHT_THEME.BrownNeon
	gameLabel.TextSize = compact and 11 or 12
	gameLabel.TextXAlignment = Enum.TextXAlignment.Left
	gameLabel.Parent = frame

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(18, 80)
	divider.Size = UDim2.new(1, -36, 0, 1)
	divider.BackgroundColor3 = PREFLIGHT_THEME.Line
	divider.BackgroundTransparency = 0.42
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(22, 96)
	title.Size = UDim2.new(1, -44, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextColor3 = PREFLIGHT_THEME.White
	title.TextSize = compact and 18 or 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(22, 126)
	desc.Size = UDim2.new(1, -44, 0, 48)
	desc.Font = Enum.Font.Gotham
	desc.Text = descText
	desc.TextColor3 = PREFLIGHT_THEME.Muted
	desc.TextSize = compact and 12 or 13
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = frame

	local go = Instance.new("TextButton")
	go.AutoButtonColor = false
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -18)
	go.Size = UDim2.new(1, -44, 0, 46)
	go.BackgroundColor3 = PREFLIGHT_THEME.Brown2
	go.BorderSizePixel = 0
	go.Font = Enum.Font.GothamBold
	go.Text = goText
	go.TextColor3 = PREFLIGHT_THEME.White
	go.TextSize = 14
	go.Parent = frame
	preflightCorner(go, 13)
	preflightStroke(go, PREFLIGHT_THEME.BrownNeon, 0.16, 1)

	go.MouseEnter:Connect(function()
		preflightTween(go, 0.14, { BackgroundColor3 = PREFLIGHT_THEME.BrownNeon })
	end)
	go.MouseLeave:Connect(function()
		preflightTween(go, 0.14, { BackgroundColor3 = PREFLIGHT_THEME.Brown2 })
	end)
	local teleportBusy = false
	local lastTeleportError = nil

	-- Listen for Roblox teleport failures instead of silently resetting the button.
	local teleportFailConnection
	pcall(function()
		teleportFailConnection = TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage, placeId)
			if player ~= LocalPlayer then return end
			if tonumber(placeId) and tonumber(placeId) ~= TARGET_PLACE_ID then return end
			lastTeleportError = tostring(errorMessage or result or "Teleport failed")
		end)
	end)

	local function requestTeleport()
		-- Teleport() is the supported client-side route. TeleportAsync is intentionally
		-- not used here because it is primarily server-side and fails in many executors.
		local ok, err = pcall(function()
			TeleportService:Teleport(TARGET_PLACE_ID, LocalPlayer)
		end)
		if not ok then
			lastTeleportError = tostring(err)
		end
		return ok
	end

	local function goToCorrectGame()
		if teleportBusy or not go or not go.Parent then return end
		teleportBusy = true
		lastTeleportError = nil
		go.Active = false
		go.Text = enteringText

		task.spawn(function()
			-- First request immediately from the user gesture.
			requestTeleport()

			-- Mobile executors occasionally swallow the first teleport request. Retry
			-- using the same supported client method while the current PlaceId remains.
			if HEXA_MOBILE then
				task.wait(1.1)
				if game.PlaceId ~= TARGET_PLACE_ID and gui and gui.Parent then
					requestTeleport()
				end
				task.wait(1.6)
				if game.PlaceId ~= TARGET_PLACE_ID and gui and gui.Parent then
					requestTeleport()
				end
			else
				task.wait(1.8)
				if game.PlaceId ~= TARGET_PLACE_ID and gui and gui.Parent then
					requestTeleport()
				end
			end

			-- Do not leave the panel permanently stuck on JOINING if Roblox rejected it.
			task.wait(2.6)
			if game.PlaceId ~= TARGET_PLACE_ID and go and go.Parent then
				teleportBusy = false
				go.Active = true
				if lastTeleportError and lastTeleportError ~= "" then
					go.Text = english and "RETRY" or "REINTENTAR"
				else
					go.Text = goText
				end
			end
		end)
	end

	-- Activated is touch-native and also works with mouse/gamepad.
	go.Activated:Connect(goToCorrectGame)

	gui.Destroying:Connect(function()
		if teleportFailConnection then
			pcall(function() teleportFailConnection:Disconnect() end)
		end
	end)

	preflightTween(scale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
	preflightTween(dim, 0.28, { BackgroundTransparency = 0.12 })
end

if game.PlaceId ~= TARGET_PLACE_ID then
	showWrongGame(PREFLIGHT_LANGUAGE)
	return
end

local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes", 15)
local Map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 15)
local Data = LocalPlayer:WaitForChild("Data")

local BigNumOK, BigNum = false, nil
do
	local util = RS:FindFirstChild("Util")
	local module = util and util:FindFirstChild("BigNum")
	if module then
		BigNumOK, BigNum = pcall(require, module)
	end
end

local S = {
	FarmWins = false,
	FarmSteps = false,
	AutoTreadmill = false,
	TreadmillMode = "Auto",
	RunInPlace = false,
	FarmWorldMode = "Auto",
	StageMode = "Auto",
	AutoBestStage = false,
	StayStill = false,
	FarmDelay = 0.35,
	BuyTrail = false,
	BuyAura = false,
	BuyUpgrades = false,
	EquipBestTrail = false,
	EquipBestAura = false,
	BuyCharms = false,
	RebirthMode = "Instant",
	MinRebirthLevel = 50,
	SpeedPotion = false,
	WinsPotion = false,
	OpenChests = false,
	AutoSecretEvent = false,
	CollectRadius = 250,
	CollectNearestFirst = true,
	WalkSpeedValue = 16,
	HighJump = false,
	JumpPowerValue = 85,
	InfiniteJump = false,
	LongJump = false,
	LongJumpPower = 80,
	BunnyHop = false,
	DashPower = 90,
	GravityValue = workspace.Gravity,
	HipHeightOffset = 0,
	Noclip = false,
	IgnoreHazards = false,
	AntiFall = false,
	AutoRespawn = false,
	AntiAFK = false,
	AutoRejoin = false,
	SmartFarmDelay = false,
	AutoResume = false,
	PerformanceMode = false,
	AutoRebirth = false,
	BestWorld = false,
	JoinRace = false,
	WinRace = false,
	GodMode = false,
	Bananas = false,
	Tacos = false,
	LuckyBlocks = false,
	HackerPortals = false,
	FreeReward = false,
	OfflineEarnings = false,
	StreakRewards = false,
	BestCharms = false,
}

local lastRun = {}
local HUB_ALIVE = true


local function normalizeName(v)
	return string.lower((tostring(v):gsub("[%s_%-%./]", "")))
end

local remoteCache = {}
local remoteMissUntil = {}
local function getRemote(name)
	if not Remotes then return nil end
	local cached = remoteCache[name]
	if cached and cached.Parent then return cached end
	local now = os.clock()
	if remoteMissUntil[name] and now < remoteMissUntil[name] then return nil end
	local direct = Remotes:FindFirstChild(name)
	if direct then
		remoteCache[name] = direct
		return direct
	end
	local wanted = normalizeName(name)
	for _, obj in ipairs(Remotes:GetDescendants()) do
		if normalizeName(obj.Name) == wanted then
			remoteCache[name] = obj
			return obj
		end
	end
	-- Evita volver a recorrer todos los remotes cada frame si uno no existe.
	remoteMissUntil[name] = now + 10
	return nil
end

local function fireRemote(name, ...)
	local remote = getRemote(name)
	if not remote then return false end
	local args = table.pack(...)
	local ok = pcall(function()
		if remote:IsA("RemoteEvent") then
			remote:FireServer(table.unpack(args, 1, args.n))
		elseif remote:IsA("RemoteFunction") then
			remote:InvokeServer(table.unpack(args, 1, args.n))
		else
			error("Unsupported remote")
		end
	end)
	return ok
end

local function invokeRemote(name, ...)
	local remote = getRemote(name)
	if not remote or not remote:IsA("RemoteFunction") then return false, nil end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	return ok, result
end

local function dataChild(name)
	return Data and Data:FindFirstChild(name)
end

local function hrp()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function touchPart(part)
	local root = hrp()
	if not root or not part or not part:IsA("BasePart") then return end
	if firetouchinterest then
		pcall(firetouchinterest, root, part, 0)
		pcall(firetouchinterest, root, part, 1)
	else
		root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
	end
end

local function ready(name, interval, now)
	local t = lastRun[name]
	if t and (now - t) < interval then return false end
	lastRun[name] = now
	return true
end

local cfgCache = {}
local function cfgModule(name)
	if cfgCache[name] ~= nil then return cfgCache[name] end
	local config = RS:FindFirstChild("Config")
	local f = config and config:FindFirstChild(name)
	if not f then return nil end
	local ok, m = pcall(require, f)
	if ok then cfgCache[name] = m end
	return ok and m or nil
end

local bestWorldNumber

local function valueNumber(obj)
	if not obj then return 0 end
	local ok, raw = pcall(function() return obj.Value end)
	if not ok then return 0 end
	if type(raw) == "number" then return raw end
	return tonumber(tostring(raw):gsub(",", "")) or 0
end

local function getDataNumber(...)
	for _, name in ipairs({ ... }) do
		local obj = dataChild(name)
		if obj then return valueNumber(obj) end
	end
	return 0
end

local function objectPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function scoreObject(obj)
	if not obj then return 0 end
	local best = 0
	for _, attr in ipairs({ "Reward", "Wins", "Speed", "Multiplier", "Level", "Stage", "Index" }) do
		local v = tonumber(obj:GetAttribute(attr))
		if v then best = math.max(best, v) end
	end
	local n = tonumber(tostring(obj.Name):match("(%d+)%D*$")) or tonumber(tostring(obj.Name):match("(%d+)")) or 0
	return math.max(best, n)
end

local function worldNumberFromObject(obj)
	return tonumber(tostring(obj and obj.Name or ""):match("[Ww]orld%s*(%d+)"))
		or tonumber(tostring(obj and obj.Name or ""):match("(%d+)"))
end

local function getWorldObject(number)
	if not Map then return nil end
	local direct = Map:FindFirstChild("World" .. tostring(number))
	if direct then return direct end
	for _, obj in ipairs(Map:GetChildren()) do
		if worldNumberFromObject(obj) == number then return obj end
	end
end

local function selectedWorldNumber()
	if S.FarmWorldMode == "Auto" then return bestWorldNumber() end
	return tonumber(tostring(S.FarmWorldMode):match("(%d+)"))
		or tonumber(dataChild("World") and dataChild("World").Value) or 1
end

local function stageNumber(stage)
	return tonumber(tostring(stage and stage.Name or ""):match("(%d+)")) or math.floor(scoreObject(stage))
end

local function getStages(worldNumber)
	local world = getWorldObject(worldNumber)
	local holder = world and (world:FindFirstChild("Stages") or world:FindFirstChild("Stage"))
	local result = {}
	if holder then
		for _, obj in ipairs(holder:GetChildren()) do
			if obj:IsA("Folder") or obj:IsA("Model") or obj:IsA("BasePart") then table.insert(result, obj) end
		end
	elseif world then
		for _, obj in ipairs(world:GetChildren()) do
			if tostring(obj.Name):lower():find("stage", 1, true) then table.insert(result, obj) end
		end
	end
	table.sort(result, function(a,b) return stageNumber(a) < stageNumber(b) end)
	return result
end

local function stageUsable(stage)
	if not stage then return false end
	if stage:GetAttribute("Locked") == true or stage:GetAttribute("Unlocked") == false then return false end
	local levelReq = tonumber(stage:GetAttribute("LevelRequirement") or stage:GetAttribute("LevelRequired") or stage:GetAttribute("RequiredLevel") or 0) or 0
	local rebirthReq = tonumber(stage:GetAttribute("RebirthRequirement") or stage:GetAttribute("RebirthsRequired") or stage:GetAttribute("RequiredRebirths") or 0) or 0
	return getDataNumber("Level", "Lvl", "PlayerLevel") >= levelReq and getDataNumber("Rebirths") >= rebirthReq
end

local function selectedStage(worldNumber)
	local stages = getStages(worldNumber)
	if #stages == 0 then return nil end
	if S.StageMode ~= "Auto" and not S.AutoBestStage then
		local wanted = tonumber(tostring(S.StageMode):match("(%d+)"))
		for _, stage in ipairs(stages) do
			if wanted and stageNumber(stage) == wanted then return stage end
		end
	end
	for i = #stages, 1, -1 do
		if stageUsable(stages[i]) then return stages[i] end
	end
	return stages[1]
end

local function stageWinPart(stage)
	if not stage then return nil end
	for _, name in ipairs({ "NormalWin", "Win", "Finish", "Checkpoint", "WinPlate", "Reward" }) do
		local obj = stage:FindFirstChild(name, true)
		if obj then
			local part = obj:FindFirstChild("Button", true) or objectPart(obj)
			if part and part:IsA("BasePart") then return part end
		end
	end
end

local function returnPart(worldNumber)
	local world = getWorldObject(worldNumber)
	for _, root in ipairs({ world, Map }) do
		if root then
			for _, name in ipairs({ "ReturnButton", "Return", "ReturnToStart", "Spawn", "Start" }) do
				local p = objectPart(root:FindFirstChild(name, true))
				if p then return p end
			end
		end
	end
end

local function ensureWorld(worldNumber)
	local world = dataChild("World")
	if world and tonumber(world.Value) == worldNumber then return true end
	if fireRemote("TeleportWorld", worldNumber) or fireRemote("ChangeWorld", worldNumber) then
		task.wait(0.75)
		return true
	end
	return false
end

local adaptiveFarmDelay = S.FarmDelay
local lastSmartWins = nil

local function farmWins()
	local worldNumber = selectedWorldNumber()
	ensureWorld(worldNumber)
	local stages = getStages(worldNumber)
	if #stages == 0 then return end
	local targets = {}
	if S.AutoBestStage or S.StageMode ~= "Auto" then
		local stage = selectedStage(worldNumber)
		if stage then table.insert(targets, stage) end
	else
		for _, stage in ipairs(stages) do
			if stageUsable(stage) then table.insert(targets, stage) end
		end
	end
	local back = returnPart(worldNumber)
	for _, stage in ipairs(targets) do
		local win = stageWinPart(stage)
		if win then
			touchPart(win)
			task.wait(0.05)
			if back then touchPart(back); task.wait(0.03) end
		end
	end
end

local function treadmillMultiplier(obj)
	local best = scoreObject(obj)
	for _, attr in ipairs({ "Multiplier", "SpeedMultiplier", "Boost", "Speed" }) do
		local v = tonumber(obj and obj:GetAttribute(attr))
		if v then best = math.max(best, v) end
	end
	local name = tostring(obj and obj.Name or "")
	local x = tonumber(name:match("[xX]%s*(%d+%.?%d*)"))
	if x then best = math.max(best, x) end
	if normalizeName(name):find("quantum", 1, true) then best = best + 100000 end
	return best
end

local function treadmillUsable(obj)
	if not obj then return false end
	if obj:GetAttribute("Locked") == true or obj:GetAttribute("Unlocked") == false then return false end
	local n = normalizeName(obj.Name)
	for _, bad in ipairs({ "robux", "gamepass", "viponly", "premiumonly" }) do
		if n:find(bad, 1, true) then return false end
	end
	local req = tonumber(obj:GetAttribute("RebirthRequirement") or obj:GetAttribute("RebirthsRequired") or 0) or 0
	return getDataNumber("Rebirths") >= req
end

local treadmillCache = {}
local treadmillCacheAt = 0
local function getTreadmills(forceRefresh)
	local now = os.clock()
	if not forceRefresh and (now - treadmillCacheAt) < 8 and #treadmillCache > 0 then
		local valid = {}
		for _, mill in ipairs(treadmillCache) do
			if mill and mill.Parent and objectPart(mill) then table.insert(valid, mill) end
		end
		if #valid > 0 then
			treadmillCache = valid
			return treadmillCache
		end
	end

	local result, seen = {}, {}
	-- Map ya pertenece a workspace; escanear ambos duplicaba trabajo innecesariamente.
	local scanRoot = Map or workspace
	if scanRoot then
		for _, obj in ipairs(scanRoot:GetDescendants()) do
			local n = normalizeName(obj.Name)
			if n:find("treadmill", 1, true) or n:find("runningmachine", 1, true) then
				local candidate = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model") or obj
				if candidate and not seen[candidate] and objectPart(candidate) then
					seen[candidate] = true
					table.insert(result, candidate)
				end
			end
		end
	end
	table.sort(result, function(a,b) return treadmillMultiplier(a) < treadmillMultiplier(b) end)
	treadmillCache = result
	treadmillCacheAt = now
	return treadmillCache
end

local function selectedTreadmill()
	local mills = getTreadmills()
	if #mills == 0 then return nil end
	if S.TreadmillMode ~= "Auto" then
		local wanted = normalizeName(S.TreadmillMode)
		for _, mill in ipairs(mills) do
			if normalizeName(mill.Name) == wanted then return mill end
		end
	end
	for i = #mills, 1, -1 do
		if treadmillUsable(mills[i]) then return mills[i] end
	end
	return nil
end

local treadmillInteractAt = setmetatable({}, { __mode = "k" })
local function useTreadmill(mill)
	local root, part = hrp(), objectPart(mill)
	if not root or not part then return false end
	local distance = (root.Position - part.Position).Magnitude
	-- No re-teletransportar al jugador si ya está correctamente sobre la cinta.
	if distance > 8 then
		root.CFrame = part.CFrame + Vector3.new(0, 3.15, 0)
	end
	local now = os.clock()
	if not treadmillInteractAt[mill] or (now - treadmillInteractAt[mill]) >= 2.5 then
		treadmillInteractAt[mill] = now
		for _, obj in ipairs(mill:GetDescendants()) do
			if obj:IsA("ProximityPrompt") and fireproximityprompt then pcall(fireproximityprompt, obj) end
			if obj:IsA("ClickDetector") and fireclickdetector then pcall(fireclickdetector, obj) end
		end
	end
	touchPart(part)
	return true
end

local runPulse = false
local function runInPlacePulse()
	local h, root = humanoid(), hrp()
	if not h or not root then return end
	runPulse = not runPulse
	local dir = runPulse and Vector3.new(0,0,-1) or Vector3.new(0,0,1)
	h:Move(dir, true)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.new(dir.X * 7, root.AssemblyLinearVelocity.Y, dir.Z * 7)
	end)
end

local trainingRemoteNames = { "AddStep", "GainSpeed", "TrainSpeed", "AddSpeed" }
local trainingRemoteCache = {}
local trainingRemoteCacheAt = 0
local function getTrainingRemotes()
	local now = os.clock()
	if (now - trainingRemoteCacheAt) < 10 then return trainingRemoteCache end
	trainingRemoteCacheAt = now
	trainingRemoteCache = {}
	for _, remoteName in ipairs(trainingRemoteNames) do
		local remote = getRemote(remoteName)
		if remote then table.insert(trainingRemoteCache, remote) end
	end
	return trainingRemoteCache
end

local function fireTrainingRemotes()
	for _, remote in ipairs(getTrainingRemotes()) do
		pcall(function()
			if remote:IsA("RemoteEvent") then remote:FireServer()
			elseif remote:IsA("RemoteFunction") then remote:InvokeServer() end
		end)
	end
end

local function ownedContains(folderName, name)
	local owned = dataChild(folderName)
	if not owned then return false end
	if owned:FindFirstChild(tostring(name)) then return true end
	for _, obj in ipairs(owned:GetChildren()) do
		if normalizeName(obj.Name) == normalizeName(name) then return true end
		local ok, value = pcall(function() return obj.Value end)
		if ok and tostring(value) == tostring(name) then return true end
	end
	return false
end

local function bestOwnedFromConfig(configName, ownedFolder)
	local cfg = cfgModule(configName)
	if type(cfg) ~= "table" then return nil end
	local bestName, bestScore = nil, -math.huge
	for name, info in pairs(cfg) do
		if ownedContains(ownedFolder, name) then
			local score = type(info) == "table" and (tonumber(info.Multiplier) or tonumber(info.Boost) or tonumber(info.Speed) or tonumber(info.Price) or 0) or 0
			if score >= bestScore then bestName, bestScore = tostring(name), score end
		end
	end
	return bestName
end

local function equipBestTrail()
	local name = bestOwnedFromConfig("Trails", "UnlockedTrails") or bestOwnedFromConfig("Tails", "UnlockedTails")
	if name then
		return fireRemote("EquipTrail", name) or fireRemote("SelectTrail", name) or fireRemote("EquipTail", name) or fireRemote("SelectTail", name)
	end
	return false
end

local function equipBestAura()
	local name = bestOwnedFromConfig("Auras", "UnlockedAuras")
	if name then return fireRemote("EquipAura", name) or fireRemote("SelectAura", name) end
	return false
end

local buyCharms

local function buyFromConfig(cfgTable, remoteName, unlockedFolderName)
	for name, info in pairs(cfgTable) do
		if type(info) == "table" and info.Price then
			local owned = dataChild(unlockedFolderName)
			if owned and not owned:FindFirstChild(tostring(name)) then
				local affordable = true
				local wins = dataChild("Wins")
				if BigNumOK and BigNum and BigNum.GreaterEqual and wins then
					affordable = BigNum.GreaterEqual(wins, info.Price)
				end
				if affordable then
					fireRemote(remoteName, tostring(name))
					break
				end
			end
		end
	end
end

buyCharms = function()
	local cfg = cfgModule("Charms") or cfgModule("Charm")
	if type(cfg) ~= "table" then return false end
	return pcall(function() buyFromConfig(cfg, "BuyCharm", "UnlockedCharms") end)
end

local function buyUpgrades()
	local upg = cfgModule("Upgrades")
	if type(upg) ~= "table" then return end
	for idx, entry in ipairs(upg) do
		if type(entry) == "table" and entry.WinsRequirement ~= nil then
			local unlocked = dataChild("UnlockedUpgrades")
			if unlocked and not unlocked:FindFirstChild(tostring(idx)) then
				local affordable = true
				if BigNumOK and BigNum and BigNum.GreaterEqual then
					local wins = dataChild("Wins")
					if wins then affordable = BigNum.GreaterEqual(wins, entry.WinsRequirement) end
				end
				if affordable then
					fireRemote("SelectUpgrade", idx)
					break
				end
			end
		end
	end
end

local function bestUpgradeNow()
	pcall(buyUpgrades)
	local cfg = cfgModule("Upgrades")
	local unlocked = dataChild("UnlockedUpgrades")
	if type(cfg) ~= "table" or not unlocked then return end
	local best = nil
	for idx, _ in ipairs(cfg) do
		if unlocked:FindFirstChild(tostring(idx)) then best = idx end
	end
	if best then fireRemote("SelectUpgrade", best) end
end

local function currentLevel()
	return getDataNumber("Level", "Lvl", "PlayerLevel")
end

local function shouldRebirth()
	if S.RebirthMode == "Instant" then return true end
	return currentLevel() >= S.MinRebirthLevel
end

local function usePotionKind(kind)
	local potions = dataChild("Potions")
	if not potions then return end
	local wanted = normalizeName(kind)
	for _, pot in ipairs(potions:GetChildren()) do
		local n = normalizeName(pot.Name)
		if n:find(wanted, 1, true) then fireRemote("UsePotion", pot.Name) end
	end
end

local function openAvailableChests()
	for _, remoteName in ipairs({ "OpenSkullChest", "OpenChest", "SpinChest", "ClaimChest" }) do
		if getRemote(remoteName) then pcall(fireRemote, remoteName) end
	end
	local root = hrp()
	if not root then return end
	local list = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		local n = normalizeName(obj.Name)
		if (n:find("skullchest",1,true) or n:find("treasurechest",1,true) or n == "chest") then
			local part = objectPart(obj)
			if part then table.insert(list, { obj=obj, part=part, d=(part.Position-root.Position).Magnitude }) end
		end
	end
	table.sort(list, function(a,b) return a.d < b.d end)
	for i=1, math.min(#list, 4) do
		local info=list[i]
		for _, d in ipairs(info.obj:GetDescendants()) do
			if d:IsA("ProximityPrompt") and fireproximityprompt then pcall(fireproximityprompt,d) end
			if d:IsA("ClickDetector") and fireclickdetector then pcall(fireclickdetector,d) end
		end
		touchPart(info.part)
	end
end

local function enterSecretOrEvent()
	for _, remoteName in ipairs({ "EnterSecretDoor", "JoinSecretDoor", "EnterEvent", "JoinEvent" }) do
		if getRemote(remoteName) and fireRemote(remoteName) then return true end
	end
	local root=hrp()
	if not root then return false end
	local best,bestD=nil,math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		local n=normalizeName(obj.Name)
		if n:find("secretdoor",1,true) or n:find("quantumtreadmill",1,true) or n:find("eventdoor",1,true) then
			local part=objectPart(obj)
			if part then
				local d=(part.Position-root.Position).Magnitude
				if d<bestD then best,bestD=part,d end
			end
		end
	end
	if best then root.CFrame=best.CFrame+Vector3.new(0,3,0); touchPart(best); return true end
	return false
end

local function teleportBestTreadmill()
	local mill=selectedTreadmill()
	if mill then return useTreadmill(mill) end
	return false
end

local function teleportSelectedStage()
	local worldNumber=selectedWorldNumber()
	ensureWorld(worldNumber)
	local stage=selectedStage(worldNumber)
	local part=stage and (stageWinPart(stage) or objectPart(stage))
	local root=hrp()
	if root and part then root.CFrame=part.CFrame+Vector3.new(0,4,0); return true end
	return false
end

local function teleportSelectedWorld()
	return ensureWorld(selectedWorldNumber())
end

local function teleportReturnSpawn()
	local root = hrp()
	local part = returnPart(selectedWorldNumber())
	if root and part then root.CFrame = part.CFrame + Vector3.new(0, 4, 0); return true end
	return false
end

local noclipOriginal = setmetatable({}, { __mode = "k" })
local noclipActive = false
local function applyNoclip(enabled)
	local c = LocalPlayer.Character
	if enabled then
		noclipActive = true
		if not c then return end
		for _, part in ipairs(c:GetDescendants()) do
			if part:IsA("BasePart") then
				if noclipOriginal[part] == nil then noclipOriginal[part] = part.CanCollide end
				if part.CanCollide then part.CanCollide = false end
			end
		end
	else
		noclipActive = false
		for part, old in pairs(noclipOriginal) do
			if part and part.Parent then pcall(function() part.CanCollide = old end) end
			noclipOriginal[part] = nil
		end
	end
end

LocalPlayer.CharacterAdded:Connect(function(char)
	if not noclipActive then return end
	char.DescendantAdded:Connect(function(obj)
		if noclipActive and obj:IsA("BasePart") then
			if noclipOriginal[obj] == nil then noclipOriginal[obj] = obj.CanCollide end
			obj.CanCollide = false
		end
	end)
end)

local antiFallSafe = nil
local function antiFallTick()
	local root, h = hrp(), humanoid()
	if not root or not h then return end
	local swimming = false
	pcall(function() swimming = h:GetState() == Enum.HumanoidStateType.Swimming end)
	if root.Position.Y <= -20 or swimming then
		if antiFallSafe then
			root.CFrame = antiFallSafe + Vector3.new(0, 3, 0)
			pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
		end
	elseif h.Health > 10 then
		antiFallSafe = root.CFrame
	end
end

local function tryRespawn()
	local h = humanoid()
	if h and h.Health > 0 then return end
	for _, remoteName in ipairs({ "Respawn", "Spawn", "RequestRespawn" }) do
		if getRemote(remoteName) and fireRemote(remoteName) then return end
	end
end

bestWorldNumber = function()
	local main = cfgModule("Main")
	local reqs = type(main) == "table" and main.WorldRebirthsRequired or nil
	local rebirthObj = dataChild("Rebirths")
	local rebirths = rebirthObj and rebirthObj.Value or 0
	local best = 1
	if type(reqs) == "table" then
		for key, need in pairs(reqs) do
			local n = tonumber(tostring(key):match("%d+"))
			if n and type(need) == "number" and rebirths >= need and n > best then
				best = n
			end
		end
	end
	return best
end

local function autoBestWorld()
	if LocalPlayer:GetAttribute("InRace") then return end
	local target = bestWorldNumber()
	local world = dataChild("World")
	if world and world.Value ~= target then
		fireRemote("TeleportWorld", target)
		task.wait(1.5)
	end
end

local collectFolderIndex = {}
local collectIndexAt = 0
local collectNames = { bananas=true, tacos=true, luckyblocks=true, hackerportals=true }
local function refreshCollectIndex()
	local now = os.clock()
	if (now - collectIndexAt) < 8 then return end
	collectIndexAt = now
	collectFolderIndex = {}
	local scanRoot = Map or workspace
	local descendants = scanRoot:GetDescendants()
	for i, obj in ipairs(descendants) do
		if obj:IsA("Folder") or obj:IsA("Model") then
			local key = normalizeName(obj.Name)
			if collectNames[key] then
				collectFolderIndex[key] = collectFolderIndex[key] or {}
				table.insert(collectFolderIndex[key], obj)
			end
		end
		if i % 500 == 0 then task.wait() end
	end
end

local function getCollectFolders(folderName)
	refreshCollectIndex()
	return collectFolderIndex[normalizeName(folderName)] or {}
end

local function collectFromFolder(folderName)
	local root = hrp()
	if not root then return end
	local candidates, seen = {}, {}
	for _, folder in ipairs(getCollectFolders(folderName)) do
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("BasePart") and not seen[item] then
				seen[item] = true
				local distance = (item.Position - root.Position).Magnitude
				if S.CollectRadius <= 0 or distance <= S.CollectRadius then
					table.insert(candidates, { part = item, distance = distance })
				end
			end
		end
	end
	if S.CollectNearestFirst then
		table.sort(candidates, function(a,b) return a.distance < b.distance end)
	end
	-- Limitar el trabajo por ciclo evita picos cuando aparecen cientos de objetos.
	for i = 1, math.min(#candidates, 35) do
		touchPart(candidates[i].part)
		task.wait(0.015)
	end
end

local streakNames = { "SlimeTail", "FlowerTail", "SkullChest" }

-- God Mode reforzado para +1 Speed Monkey Escape.
local safeCFrame = nil
local hazardOriginal = setmetatable({}, { __mode = "k" })
local antiDeathHookInstalled = false
local godHealthConn = nil
local godHumanoid = nil
local godOriginalHumanoid = setmetatable({}, { __mode = "k" })
local hazardWords = { "water", "flood", "tsunami", "lava", "kill", "death", "crusher", "crush", "press", "axe", "car", "spike", "acid", "closingwall", "movingwall", "deathwall" }

local function isHazardPart(part)
	if not part or not part:IsA("BasePart") then return false end
	local names = { normalizeName(part.Name) }
	local ancestor = part.Parent
	for _ = 1, 3 do
		if not ancestor then break end
		table.insert(names, normalizeName(ancestor.Name))
		ancestor = ancestor.Parent
	end
	for _, word in ipairs(hazardWords) do
		for _, name in ipairs(names) do
			if name:find(word, 1, true) then return true end
		end
	end
	return false
end

local function installAntiDeathHook()
	if antiDeathHookInstalled then return end
	if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then return end
	local died = getRemote("Died")
	if not died then return end
	local ok = pcall(function()
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if S.GodMode and self == died and (method == "FireServer" or method == "InvokeServer") then return nil end
			return old(self, ...)
		end))
	end)
	antiDeathHookInstalled = ok
end

local hazardProtectionActive = false
local hazardScanGeneration = 0
local function protectHazardPart(obj)
	if not isHazardPart(obj) then return end
	if not hazardOriginal[obj] then hazardOriginal[obj] = { obj.CanTouch, obj.CanCollide } end
	pcall(function() obj.CanTouch = false end)
	local n = normalizeName(obj.Name)
	if n:find("crusher", 1, true) or n:find("wall", 1, true) or n:find("press", 1, true) then
		pcall(function() obj.CanCollide = false end)
	end
end

local function applyHazardProtection(enabled)
	hazardScanGeneration += 1
	local generation = hazardScanGeneration
	if enabled then
		if hazardProtectionActive then return end
		hazardProtectionActive = true
		-- Escaneo inicial repartido por lotes para evitar un tirón al activar God Mode.
		task.spawn(function()
			local descendants = workspace:GetDescendants()
			for i, obj in ipairs(descendants) do
				if not hazardProtectionActive or generation ~= hazardScanGeneration then return end
				if obj:IsA("BasePart") then protectHazardPart(obj) end
				if i % 300 == 0 then task.wait() end
			end
		end)
	else
		hazardProtectionActive = false
		for part, oldValues in pairs(hazardOriginal) do
			if part and part.Parent then
				pcall(function() part.CanTouch = oldValues[1]; part.CanCollide = oldValues[2] end)
			end
			hazardOriginal[part] = nil
		end
	end
end

workspace.DescendantAdded:Connect(function(obj)
	if hazardProtectionActive and obj:IsA("BasePart") then
		task.defer(protectHazardPart, obj)
	end
end)

local godLastSafeUpdate = 0
local function protectCharacter()
	local c = LocalPlayer.Character
	local h, root = humanoid(), hrp()
	if not c or not h or not root then return end
	installAntiDeathHook()
	if godHumanoid ~= h then
		if godHealthConn then pcall(function() godHealthConn:Disconnect() end) end
		godHumanoid = h
		if not godOriginalHumanoid[h] then
			local original = { MaxHealth = h.MaxHealth, BreakJointsOnDeath = h.BreakJointsOnDeath }
			pcall(function() original.DeadEnabled = h:GetStateEnabled(Enum.HumanoidStateType.Dead) end)
			pcall(function() original.FallingEnabled = h:GetStateEnabled(Enum.HumanoidStateType.FallingDown) end)
			godOriginalHumanoid[h] = original
		end
		pcall(function()
			h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			h.PlatformStand = false
			h.BreakJointsOnDeath = false
			if h.MaxHealth < 10000 then h.MaxHealth = 10000 end
			h.Health = h.MaxHealth
		end)
		godHealthConn = h.HealthChanged:Connect(function(health)
			if S.GodMode and h.Parent and health < h.MaxHealth then
				pcall(function() h.Health = h.MaxHealth end)
			end
		end)
	end

	if not c:FindFirstChildOfClass("ForceField") then
		local ff = Instance.new("ForceField")
		ff.Name = "HEXA_GodForceField"
		ff.Visible = false
		ff.Parent = c
	end

	local swimming = false
	pcall(function() swimming = h:GetState() == Enum.HumanoidStateType.Swimming end)
	if swimming or root.Position.Y <= -15 or h.Health <= 1 then
		if safeCFrame then
			root.CFrame = safeCFrame + Vector3.new(0, 3, 0)
			pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
		end
	else
		local now = os.clock()
		if (now - godLastSafeUpdate) >= 0.6 and h.Health > 10 then
			godLastSafeUpdate = now
			safeCFrame = root.CFrame
		end
	end
end

local performanceOriginal = setmetatable({}, { __mode = "k" })
local performanceGeneration = 0
local function applyPerformanceMode(enabled)
	local Lighting = game:GetService("Lighting")
	local classes = {
		ParticleEmitter=true, Trail=true, Beam=true, Smoke=true, Fire=true, Sparkles=true,
		BloomEffect=true, BlurEffect=true, ColorCorrectionEffect=true, SunRaysEffect=true, DepthOfFieldEffect=true,
	}
	performanceGeneration += 1
	local generation = performanceGeneration
	if enabled then
		task.spawn(function()
			local processed = 0
			for _, root in ipairs({ workspace, Lighting }) do
				for _, obj in ipairs(root:GetDescendants()) do
					if not S.PerformanceMode or generation ~= performanceGeneration then return end
					if classes[obj.ClassName] then
						local ok, current = pcall(function() return obj.Enabled end)
						if ok then
							if performanceOriginal[obj] == nil then performanceOriginal[obj] = current end
							pcall(function() obj.Enabled = false end)
						end
					end
					processed += 1
					if processed % 400 == 0 then task.wait() end
				end
			end
		end)
	else
		for obj, oldValue in pairs(performanceOriginal) do
			if obj and obj.Parent then pcall(function() obj.Enabled = oldValue end) end
			performanceOriginal[obj] = nil
		end
	end
end

local function fetchPublicServers()
	local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if not ok then return {} end
	local decodedOk, data = pcall(function() return HttpService:JSONDecode(body) end)
	if not decodedOk or type(data) ~= "table" or type(data.data) ~= "table" then return {} end
	return data.data
end

local function hopServer(lowest)
	local servers = fetchPublicServers()
	local candidates = {}
	for _, server in ipairs(servers) do
		if server.id and server.id ~= game.JobId and tonumber(server.playing or 0) < tonumber(server.maxPlayers or 0) then
			table.insert(candidates, server)
		end
	end
	if lowest then
		table.sort(candidates, function(a,b) return tonumber(a.playing or 999) < tonumber(b.playing or 999) end)
	end
	local target = candidates[1]
	if target then pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer) end); return true end
	return false
end

local ORIGINAL_GRAVITY = workspace.Gravity
local movementOriginal = setmetatable({}, { __mode = "k" })

local function captureMovementOriginal(h)
	if not h or movementOriginal[h] then return end
	movementOriginal[h] = {
		WalkSpeed = h.WalkSpeed,
		JumpPower = h.JumpPower,
		JumpHeight = h.JumpHeight,
		HipHeight = h.HipHeight,
	}
end

local function applyMovementSettings()
	local h = humanoid()
	if not h then return end
	captureMovementOriginal(h)
	local original = movementOriginal[h]
	pcall(function()
		h.WalkSpeed = S.WalkSpeedValue
		if S.HighJump then
			h.JumpPower = S.JumpPowerValue
		else
			h.JumpPower = original.JumpPower
			h.JumpHeight = original.JumpHeight
		end
		h.HipHeight = original.HipHeight + S.HipHeightOffset
	end)
	workspace.Gravity = S.GravityValue
end

local function restoreMovementSettings()
	workspace.Gravity = ORIGINAL_GRAVITY
	local h = humanoid()
	if h then
		local original = movementOriginal[h]
		pcall(function()
			if original then
				h.WalkSpeed = original.WalkSpeed
				h.JumpPower = original.JumpPower
				h.JumpHeight = original.JumpHeight
				h.HipHeight = original.HipHeight
			else
				h.WalkSpeed = 16
			end
		end)
	end
end

local function dashForward()
	local root, h = hrp(), humanoid()
	if not root or not h then return end
	local direction = h.MoveDirection
	if direction.Magnitude < 0.05 then direction = root.CFrame.LookVector end
	if direction.Magnitude > 0 then direction = direction.Unit end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(direction.X * S.DashPower, v.Y, direction.Z * S.DashPower)
end

local function superJump()
	local root, h = hrp(), humanoid()
	if not root or not h then return end
	h:ChangeState(Enum.HumanoidStateType.Jumping)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, S.JumpPowerValue * 1.45), v.Z)
end

local PANIC_KEYS = {
	"FarmWins","FarmSteps","AutoTreadmill","RunInPlace","StayStill","BuyTrail","BuyAura","BuyUpgrades","EquipBestTrail","EquipBestAura","BuyCharms",
	"AutoRebirth","BestWorld","JoinRace","WinRace","GodMode","Bananas","Tacos","LuckyBlocks","HackerPortals","FreeReward","OfflineEarnings","StreakRewards",
	"BestCharms","SpeedPotion","WinsPotion","OpenChests","AutoSecretEvent","HighJump","InfiniteJump","LongJump","BunnyHop","Noclip","IgnoreHazards","AntiFall","AutoRespawn","AntiAFK","AutoRejoin",
	"SmartFarmDelay","AutoResume","PerformanceMode"
}

local function panicStop()
	for _, key in ipairs(PANIC_KEYS) do S[key] = false end
	S.WalkSpeedValue = 16
	S.JumpPowerValue = 85
	S.LongJumpPower = 80
	S.DashPower = 90
	S.GravityValue = ORIGINAL_GRAVITY
	S.HipHeightOffset = 0
	S.StayStill = false
	local root, h = hrp(), humanoid()
	if root then
		pcall(function()
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end)
	end
	if godHealthConn then pcall(function() godHealthConn:Disconnect() end); godHealthConn = nil end
	if h then
		local original = godOriginalHumanoid[h]
		pcall(function()
			h.WalkSpeed = 16
			h.PlatformStand = false
			if original then
				h.MaxHealth = original.MaxHealth or h.MaxHealth
				h.BreakJointsOnDeath = original.BreakJointsOnDeath ~= false
				if original.DeadEnabled ~= nil then h:SetStateEnabled(Enum.HumanoidStateType.Dead, original.DeadEnabled) else h:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
				if original.FallingEnabled ~= nil then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, original.FallingEnabled) else h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end
			else
				h:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
				h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			end
		end)
		local ff = h.Parent and h.Parent:FindFirstChild("HEXA_GodForceField")
		if ff then pcall(function() ff:Destroy() end) end
	end
	godHumanoid = nil
	pcall(applyNoclip, false)
	pcall(applyHazardProtection, false)
	pcall(applyPerformanceMode, false)
	pcall(restoreMovementSettings)
end

local function shutdownHub()
	if not HUB_ALIVE then return end
	HUB_ALIVE = false
	panicStop()
end

local function applyPreset(name)
	if name == "FullAuto" then
		S.FarmWins=true; S.SmartFarmDelay=true; S.BuyTrail=true; S.BuyAura=true; S.BuyUpgrades=true
		S.EquipBestTrail=true; S.EquipBestAura=true; S.BuyCharms=true; S.AutoRebirth=true; S.BestWorld=true
		S.FreeReward=true; S.OfflineEarnings=true; S.StreakRewards=true; S.BestCharms=true; S.SpeedPotion=true; S.WinsPotion=true
		S.OpenChests=true; S.AutoSecretEvent=true; S.AutoResume=true; S.AntiFall=true; S.IgnoreHazards=true
	elseif name == "FarmSpeed" then
		S.FarmSteps=true; S.AutoTreadmill=true; S.RunInPlace=true; S.SpeedPotion=true; S.AutoResume=true; S.AntiFall=true
	elseif name == "Progression" then
		S.FarmWins=true; S.SmartFarmDelay=true; S.BuyUpgrades=true; S.BuyTrail=true; S.BuyAura=true; S.BuyCharms=true
		S.EquipBestTrail=true; S.EquipBestAura=true; S.BestCharms=true; S.AutoRebirth=true; S.BestWorld=true; S.AutoResume=true
	end
end

-- ================= CEVRILER =================

local L = {
	en = {
		tabMain = "Farm", tabFarm = "Farm", tabProgress = "Progress", tabTeleport = "Teleports", tabPlayer = "Player", tabProtection = "Protection", tabRace = "Races", tabCollection = "Collect", tabRewards = "Rewards", tabUtilities = "Utilities",
		secFarm = "Autofarm", secTraining = "Speed Training", secRoute = "World & Stage", secBuy = "Auto Purchase", secRace = "Race Automation", secCollect = "Auto Collect", secProtection = "Survival & Protection", secTeleport = "Quick Teleports", secUtilities = "Utilities & Servers", secPresets = "Presets",
		farmWins = "Auto Farm Wins", farmSteps = "Auto Farm Steps", autoTreadmill = "Auto Best Treadmill", treadmillSelector = "Treadmill Selector", runInPlace = "Auto Run In Place",
		worldSelector = "Farm World", stageSelector = "Stage", autoBestStage = "Auto Best Stage",
		equipTrail = "Auto Equip Best Trail", equipAura = "Auto Equip Best Aura", buyCharms = "Auto Buy Charms",
		bestUpgradeNow = "Best Upgrade Now", rebirthMode = "Rebirth Mode", rebirthInstant = "As Soon As Possible", rebirthMinimum = "Wait For Minimum Level", minRebirth = "Minimum Rebirth Level",
		speedPotion = "Auto Speed Potion", winsPotion = "Auto Wins Potion", openChests = "Auto Open Chests", secretEvent = "Auto Secret / Event",
		collectRadius = "Collect Radius (0 = All)", nearestFirst = "Collect Nearest First", tpTreadmill = "Teleport to Best Treadmill", tpStage = "Teleport to Selected Stage",
		tpWorld = "Teleport to Selected World", tpReturn = "Teleport to Return / Spawn", secPlayer = "Movement", walkSpeed = "WalkSpeed", highJump = "High Jump", jumpPower = "Jump Power", infiniteJump = "Infinite Jump", longJump = "Long Jump", longJumpPower = "Long Jump Strength", bunnyHop = "Bunny Hop", dash = "Dash Forward", dashPower = "Dash Strength", superJump = "Super Jump", gravity = "Local Gravity", hipHeight = "Hip Height Offset", noclip = "Noclip",
		ignoreHazards = "Ignore Hazards", antiFall = "Anti Fall / Anti Void", autoRespawn = "Auto Respawn + Continue Farm", antiAFK = "Anti AFK", autoRejoin = "Auto Rejoin",
		serverHop = "Server Hop", lowServerHop = "Low Server Hop", panicStop = "Panic Stop - Disable All", smartDelay = "Smart Farm Delay", autoResume = "Auto Resume", performance = "Performance Mode",
		presetFull = "Preset: Full Auto", presetSpeed = "Preset: Farm Speed", presetProgression = "Preset: Progression",
		stayStill = "Stay Still", farmSpeed = "Farm Speed (delay s)",
		buyTrail = "Auto Buy Trail", buyAura = "Auto Buy Aura", buyUpgrades = "Auto Buy Upgrades",
		rebirth = "Auto Rebirth", bestWorld = "Auto Best World",
		joinRace = "Auto Join Race", winRace = "Auto Win Race", godMode = "God Mode",
		bananas = "Collect Bananas", tacos = "Collect Tacos", lucky = "Collect Lucky Blocks", portals = "Collect Hacker Portals",
		freeReward = "Auto Free Reward", offline = "Auto Offline Earnings", streak = "Auto Streak Rewards",
		charms = "Auto Equip Best Charms", potions = "Auto Use Potions",
		loaded = "HEXA loaded",
		closeTitle = "Exit HEXA?", closeDesc = "If you close this panel, the hub will stop and you will need to execute the script again to reopen it.", cancelBtn = "Go Back", closeBtn = "Exit", closeTag = "CONFIRM",
	},
	es = {
		tabMain = "Farm", tabFarm = "Farm", tabProgress = "Progreso", tabTeleport = "Teleports", tabPlayer = "Jugador", tabProtection = "Protección", tabRace = "Carreras", tabCollection = "Colección", tabRewards = "Recompensas", tabUtilities = "Utilidades",
		secFarm = "Autofarm", secTraining = "Entrenamiento de Velocidad", secRoute = "Mundo y Stage", secBuy = "Compra Automática", secRace = "Automatización de Carreras", secCollect = "Recolección", secProtection = "Supervivencia y Protección", secTeleport = "Teleports Rápidos", secUtilities = "Utilidades y Servidores", secPresets = "Presets",
		farmWins = "Farmear Victorias", farmSteps = "Farmear Pasos Auto", autoTreadmill = "Mejor Treadmill Auto", treadmillSelector = "Selector de Treadmill", runInPlace = "Correr en el Sitio Auto",
		worldSelector = "Mundo de Farm", stageSelector = "Stage", autoBestStage = "Mejor Stage Auto",
		equipTrail = "Equipar Mejor Trail Auto", equipAura = "Equipar Mejor Aura Auto", buyCharms = "Comprar Charms Auto",
		bestUpgradeNow = "Mejor Upgrade Ahora", rebirthMode = "Modo de Rebirth", rebirthInstant = "Apenas se pueda", rebirthMinimum = "Esperar nivel mínimo", minRebirth = "Nivel mínimo para Rebirth",
		speedPotion = "Poción de Velocidad Auto", winsPotion = "Poción de Wins Auto", openChests = "Abrir Cofres Auto", secretEvent = "Secret / Evento Auto",
		collectRadius = "Radio de Recolección (0 = Todo)", nearestFirst = "Recoger Más Cercano Primero", tpTreadmill = "TP al Mejor Treadmill", tpStage = "TP al Stage Seleccionado",
		tpWorld = "TP al Mundo Seleccionado", tpReturn = "TP a Return / Spawn", secPlayer = "Movimiento", walkSpeed = "WalkSpeed", highJump = "Salto Alto", jumpPower = "Potencia de Salto", infiniteJump = "Salto Infinito", longJump = "Long Jump", longJumpPower = "Fuerza de Long Jump", bunnyHop = "Bunny Hop", dash = "Dash Hacia Delante", dashPower = "Fuerza del Dash", superJump = "Super Salto", gravity = "Gravedad Local", hipHeight = "Altura del Personaje", noclip = "Noclip",
		ignoreHazards = "Ignorar Peligros", antiFall = "Anti Caída / Anti Void", autoRespawn = "Respawn Auto + Continuar Farm", antiAFK = "Anti AFK", autoRejoin = "Auto Rejoin",
		serverHop = "Cambiar Servidor", lowServerHop = "Servidor con Poca Gente", panicStop = "Panic Stop - Apagar Todo", smartDelay = "Delay Inteligente", autoResume = "Continuar Farm Auto", performance = "Modo Rendimiento",
		presetFull = "Preset: Full Auto", presetSpeed = "Preset: Farm Speed", presetProgression = "Preset: Progression",
		stayStill = "Quedarse Quieto", farmSpeed = "Velocidad de Farmeo (retraso s)",
		buyTrail = "Comprar Estelas Auto", buyAura = "Comprar Auras Auto", buyUpgrades = "Comprar Mejoras Auto",
		rebirth = "Renacer Auto", bestWorld = "Mejor Mundo Auto",
		joinRace = "Unirse a Carreras Auto", winRace = "Ganar Carreras Auto", godMode = "Modo Dios",
		bananas = "Recoger Plátanos", tacos = "Recoger Tacos", lucky = "Recoger Bloques de Suerte", portals = "Recoger Portales Hacker",
		freeReward = "Recompensa Gratis Auto", offline = "Ganancias Offline Auto", streak = "Recompensas de Racha Auto",
		charms = "Equipar Mejores Amuletos", potions = "Usar Pociones Auto",
		loaded = "HEXA cargado",
		closeTitle = "¿Salir de HEXA?", closeDesc = "Si cierras este panel, el hub se detendrá y tendrás que ejecutar el script otra vez para volver a abrirlo.", cancelBtn = "Volver", closeBtn = "Salir", closeTag = "CONFIRMAR",
	},
}

-- ================= ANA DÖNGÜ =================

InputService.JumpRequest:Connect(function()
	local h, root = humanoid(), hrp()
	if not h or not root then return end
	if S.InfiniteJump then
		pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
	end
	if S.HighJump then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, S.JumpPowerValue), v.Z)
	end
	if S.LongJump then
		local direction = h.MoveDirection
		if direction.Magnitude < 0.05 then direction = root.CFrame.LookVector end
		if direction.Magnitude > 0 then
			direction = direction.Unit
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(direction.X * S.LongJumpPower, math.max(v.Y, S.JumpPowerValue * 0.72), direction.Z * S.LongJumpPower)
		end
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.delay(0.6, function()
		if not HUB_ALIVE then return end
		pcall(applyMovementSettings)
	end)
	if not S.AutoResume then return end
	task.delay(1.5, function()
		if not HUB_ALIVE or not S.AutoResume then return end
		if S.FarmSteps or S.AutoTreadmill then
			local mill = selectedTreadmill()
			if mill then pcall(useTreadmill, mill) end
		end
		if S.GodMode then pcall(protectCharacter) end
	end)
end)

LocalPlayer.Idled:Connect(function()
	if S.AntiAFK then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end
end)

local rejoinBusy = false
GuiService.ErrorMessageChanged:Connect(function(message)
	if S.AutoRejoin and not rejoinBusy and tostring(message) ~= "" then
		rejoinBusy = true
		task.delay(1.5, function()
			if not HUB_ALIVE or not S.AutoRejoin then rejoinBusy = false; return end
			pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
			task.delay(5, function() rejoinBusy = false end)
		end)
	end
end)

task.spawn(function()
	while HUB_ALIVE do
		local now = os.clock()


		local farmInterval = S.SmartFarmDelay and adaptiveFarmDelay or S.FarmDelay
		if S.FarmWins and ready("farm", farmInterval, now) then
			if S.SmartFarmDelay then
				local winsNow = getDataNumber("Wins")
				if lastSmartWins ~= nil then
					if winsNow <= lastSmartWins then adaptiveFarmDelay = math.min(2, adaptiveFarmDelay + 0.05)
					else adaptiveFarmDelay = math.max(S.FarmDelay, adaptiveFarmDelay - 0.02) end
				end
				lastSmartWins = winsNow
			else
				adaptiveFarmDelay = S.FarmDelay
				lastSmartWins = nil
			end
			pcall(farmWins)
		end

		if S.FarmSteps and ready("farmsteps", 1.0, now) then
			-- Mantiene el entrenamiento activo sin volver a buscar/teletransportar cada ciclo.
			if ready("farmstepsmill", 3.0, now) then
				local mill = selectedTreadmill()
				if mill then pcall(useTreadmill, mill) end
			end
			pcall(runInPlacePulse)
			pcall(fireTrainingRemotes)
		end

		if S.AutoTreadmill and ready("autotreadmill", 3.0, now) then
			local mill = selectedTreadmill()
			if mill then pcall(useTreadmill, mill) end
		end

		if S.RunInPlace and ready("runinplace", 0.25, now) then
			pcall(runInPlacePulse)
		end

		local currentHumanoid = humanoid()
		if currentHumanoid and ready("movementrefresh", 0.8, now) then
			pcall(applyMovementSettings)
		end
		if S.BunnyHop and currentHumanoid and ready("bunnyhop", 0.14, now) then
			if currentHumanoid.MoveDirection.Magnitude > 0.05 and currentHumanoid.FloorMaterial ~= Enum.Material.Air then
				pcall(function() currentHumanoid.Jump = true end)
			end
		end

		if S.Noclip and ready("nocliprefresh", 0.65, now) then pcall(applyNoclip, true) end
		if S.AntiFall and ready("antifall", 0.2, now) then pcall(antiFallTick) end
		if S.AutoRespawn and ready("autorespawn", 1.5, now) then pcall(tryRespawn) end

		if S.StayStill then
			local root = hrp()
			if root and not root.Anchored then
				root.Anchored = true
			end
		end

		if S.BuyTrail and ready("trail", 3, now) then
			local t = cfgModule("Trails")
			if type(t) == "table" then pcall(buyFromConfig, t, "BuyTrail", "UnlockedTrails") end
		end

		if S.BuyAura and ready("aura", 3, now) then
			local a = cfgModule("Auras")
			if type(a) == "table" then pcall(buyFromConfig, a, "BuyAura", "UnlockedAuras") end
		end

		if S.BuyUpgrades and ready("upg", 3, now) then
			pcall(buyUpgrades)
		end

		if S.EquipBestTrail and ready("equiptrail", 4, now) then pcall(equipBestTrail) end
		if S.EquipBestAura and ready("equipaura", 4, now) then pcall(equipBestAura) end
		if S.BuyCharms and ready("buycharms", 4, now) then pcall(buyCharms) end

		if S.AutoRebirth and ready("rebirth", 5, now) and shouldRebirth() then
			pcall(function() fireRemote("Rebirth") end)
		end

		if S.BestWorld and ready("world", 5, now) then
			pcall(autoBestWorld)
		end

		if S.JoinRace and ready("joinrace", 2, now) then
			if not LocalPlayer:GetAttribute("InRace") then
				pcall(function()
					fireRemote("JoinRace")
				end)
			end
		end

		if S.WinRace and ready("winrace", 0.5, now) then
			if LocalPlayer:GetAttribute("InRace") then
				local races = Map and Map:FindFirstChild("Races")
				local root = hrp()
				if races and root then
					local nearest, dist = nil, math.huge
					for _, r in ipairs(races:GetChildren()) do
						local fin = r:FindFirstChild("RaceFinish", true)
						if fin and fin:IsA("BasePart") then
							local d = (fin.Position - root.Position).Magnitude
							if d < dist then
								dist = d
								nearest = fin
							end
						end
					end
					if nearest then
						root.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 3, 0))
						task.wait(0.05)
						touchPart(nearest)
					end
				end
			end
		end

		if S.GodMode and ready("godtick", 0.25, now) then pcall(protectCharacter) end

		if S.Bananas and ready("ban", 1, now) then
			pcall(collectFromFolder, "Bananas")
		end
		if S.Tacos and ready("tac", 1, now) then
			pcall(collectFromFolder, "Tacos")
		end
		if S.LuckyBlocks and ready("lucky", 1, now) then
			pcall(collectFromFolder, "LuckyBlocks")
		end
		if S.HackerPortals and ready("portal", 1, now) then
			pcall(collectFromFolder, "HackerPortals")
		end

		if S.FreeReward and ready("free", 10, now) then
			pcall(function()
				fireRemote("ClaimFreeReward")
			end)
		end

		if S.OfflineEarnings and ready("offline", 15, now) then
			pcall(function()
				fireRemote("ClaimOfflineEarnings")
			end)
		end

		if S.StreakRewards and ready("streak", 15, now) then
			local streakClaimed = dataChild("StreakClaimed")
			for _, name in ipairs(streakNames) do
				if not streakClaimed or not streakClaimed:FindFirstChild(name) then
					fireRemote("ClaimStreakReward", name)
				end
			end
		end

		if S.BestCharms and ready("charms", 20, now) then
			pcall(function()
				fireRemote("EquipBestCharms", "Speed")
				fireRemote("EquipBestCharms", "Wins")
			end)
		end

		if S.SpeedPotion and ready("speedpotion", 20, now) then pcall(usePotionKind, "Speed") end
		if S.WinsPotion and ready("winspotion", 20, now) then pcall(usePotionKind, "Win") end
		if S.OpenChests and ready("chests", 7, now) then pcall(openAvailableChests) end
		if S.AutoSecretEvent and ready("secretevent", 5, now) then pcall(enterSecretOrEvent) end

		task.wait(0.10)
	end
end)

-- ================= PREMIUM CUSTOM UI =================
-- Full custom interface: no external UI library is required.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local THEME = {
	Black = Color3.fromRGB(2, 2, 2),
	Black2 = Color3.fromRGB(7, 5, 4),
	Panel = Color3.fromRGB(12, 7, 4),
	Panel2 = Color3.fromRGB(24, 11, 5),
	Card = Color3.fromRGB(36, 16, 7),
	CardHover = Color3.fromRGB(57, 26, 10),
	Brown = Color3.fromRGB(112, 48, 14),
	Brown2 = Color3.fromRGB(194, 83, 20),
	Brown3 = Color3.fromRGB(255, 151, 50),
	BrownNeon = Color3.fromRGB(255, 118, 20),
	White = Color3.fromRGB(255, 252, 247),
	Muted = Color3.fromRGB(199, 180, 163),
	Soft = Color3.fromRGB(72, 34, 15),
	Line = Color3.fromRGB(122, 53, 18),
	Danger = Color3.fromRGB(255, 75, 55),
	Success = Color3.fromRGB(127, 255, 151),
}
local function parentGui(gui)
	local ok = pcall(function()
		gui.Parent = gethui and gethui() or game.CoreGui
	end)
	if not ok then
		gui.Parent = game.CoreGui
	end
	return gui
end

local function destroyOldGui(name)
	pcall(function()
		local p = gethui and gethui() or game.CoreGui
		local old = p:FindFirstChild(name)
		if old then old:Destroy() end
	end)
end

local function corner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.Line
	s.Transparency = transparency == nil and 0 or transparency
	-- Bordes finos y uniformes en toda la interfaz.
	s.Thickness = math.min(thickness or 0.30, 0.35)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function neonStroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.BrownNeon
	s.Transparency = transparency == nil and 0.28 or transparency
	-- Evita que cualquier panel/botón vuelva a crear un borde grueso.
	s.Thickness = math.min(thickness or 0.18, 0.22)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function gradient(inst, c1, c2, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 0
	g.Parent = inst
	return g
end

local function padding(inst, l, r, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingRight = UDim.new(0, r or l or 0)
	p.PaddingTop = UDim.new(0, t or 0)
	p.PaddingBottom = UDim.new(0, b or t or 0)
	p.Parent = inst
	return p
end

local function tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function getScale(inst, name)
	name = name or "HEXA_AnimScale"
	local scale = inst:FindFirstChild(name)
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Scale = 1
		scale.Parent = inst
	end
	return scale
end

local function pressBounce(inst, amount)
	if not inst or not inst.Parent then return end
	local scale = getScale(inst)
	amount = amount or 0.965
	tween(scale, 0.07, { Scale = amount }, Enum.EasingStyle.Quad)
	task.delay(0.07, function()
		if scale and scale.Parent then
			tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

local function animatePageIn(page)
	if not page or not page.Parent then return end
	local scale = getScale(page, "HEXA_PageScale")
	scale.Scale = 0.965
	page.ScrollBarImageTransparency = 1
	tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(page, 0.20, { ScrollBarImageTransparency = 0.15 })
end

local function makeLabel(parent, text, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = text or ""
	l.TextColor3 = color or THEME.White
	l.TextSize = size or 14
	l.Font = font or Enum.Font.Gotham
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

local function addHover(button, normalColor, hoverColor)
	button.MouseEnter:Connect(function()
		tween(button, 0.15, { BackgroundColor3 = hoverColor })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.15, { BackgroundColor3 = normalColor })
	end)
end

local function addTopAccent(parent)
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(14, 2)
	accent.Size = UDim2.new(1, -28, 0, 1)
	accent.BackgroundColor3 = THEME.Brown2
	accent.BorderSizePixel = 0
	accent.Parent = parent
	corner(accent, 99)
	gradient(accent, THEME.Brown, THEME.Brown3, 0)
	return accent
end


local function makeIconPart(parent, size, position, color, radius, rotation, partName)
	local part = Instance.new("Frame")
	part.Name = partName or "IconTint"
	part.Size = size
	part.Position = position
	part.BackgroundColor3 = color or THEME.Muted
	part.BorderSizePixel = 0
	part.Rotation = rotation or 0
	part.Parent = parent
	if radius and radius > 0 then
		corner(part, radius)
	end
	return part
end

local function setIconColor(iconRoot, color)
	for _, obj in ipairs(iconRoot:GetDescendants()) do
		if obj:IsA("Frame") and obj.Name == "IconTint" then
			obj.BackgroundColor3 = color
		end
	end
end

local function createNavIcon(parent, key, compact)
	local size = compact and 16 or 18
	local icon = Instance.new("Frame")
	icon.Name = "NavIcon"
	icon.Size = UDim2.fromOffset(size, size)
	icon.Position = UDim2.new(0, compact and 12 or 14, 0.5, -math.floor(size / 2))
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Parent = parent

	if key == "farm" then
		-- Principal: casa/home mucho más clara
		makeIconPart(icon, UDim2.fromOffset(size - 8, size - 9), UDim2.fromOffset(4, 8), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 6, 3), UDim2.fromOffset(2, 5), THEME.Muted, 2, 35)
		makeIconPart(icon, UDim2.fromOffset(size - 6, 3), UDim2.fromOffset(6, 5), THEME.Muted, 2, -35)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(math.floor(size / 2) - 2, size - 7), THEME.Black2, 2, 0, "IconCutout")
	elseif key == "progress" then
		-- Progreso: barras ascendentes.
		makeIconPart(icon, UDim2.fromOffset(3, 6), UDim2.fromOffset(2, size - 7), THEME.Muted, 1, 0)
		makeIconPart(icon, UDim2.fromOffset(3, 10), UDim2.fromOffset(7, size - 11), THEME.Muted, 1, 0)
		makeIconPart(icon, UDim2.fromOffset(3, 14), UDim2.fromOffset(12, size - 15), THEME.Muted, 1, 0)
	elseif key == "teleports" then
		-- Teleports: objetivo / punto de destino.
		makeIconPart(icon, UDim2.fromOffset(size - 4, 3), UDim2.fromOffset(2, 3), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 4, 3), UDim2.fromOffset(2, size - 6), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, size - 4), UDim2.fromOffset(3, 2), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, size - 4), UDim2.fromOffset(size - 6, 2), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(5, 5), UDim2.fromOffset(math.floor(size/2)-2, math.floor(size/2)-2), THEME.Muted, 99, 0)
	elseif key == "player" then
		-- Jugador: cabeza + cuerpo.
		makeIconPart(icon, UDim2.fromOffset(6, 6), UDim2.fromOffset(math.floor(size/2)-3, 1), THEME.Muted, 99, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 6, 8), UDim2.fromOffset(3, 9), THEME.Muted, 4, 0)
	elseif key == "protection" then
		-- Protección: escudo geométrico.
		makeIconPart(icon, UDim2.fromOffset(size - 6, size - 6), UDim2.fromOffset(3, 2), THEME.Muted, 4, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 10, size - 9), UDim2.fromOffset(5, 4), THEME.Black2, 3, 0, "IconCutout")
	elseif key == "races" then
		-- Carreras: bandera.
		makeIconPart(icon, UDim2.fromOffset(3, size - 2), UDim2.fromOffset(2, 1), THEME.Muted, 1, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 7, 7), UDim2.fromOffset(5, 2), THEME.Muted, 1, 0)
	elseif key == "collection" then
		-- Colección: varias tarjetas/cuadros apilados
		makeIconPart(icon, UDim2.fromOffset(size - 8, size - 8), UDim2.fromOffset(1, 5), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 8, size - 8), UDim2.fromOffset(4, 3), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 8, size - 8), UDim2.fromOffset(7, 1), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 12, 2), UDim2.fromOffset(3, 8), THEME.Black2, 2, 0, "IconCutout")
		makeIconPart(icon, UDim2.fromOffset(size - 12, 2), UDim2.fromOffset(6, 6), THEME.Black2, 2, 0, "IconCutout")
		makeIconPart(icon, UDim2.fromOffset(size - 12, 2), UDim2.fromOffset(9, 4), THEME.Black2, 2, 0, "IconCutout")
	elseif key == "rewards" then
		-- Recompensas: trofeo más claro
		makeIconPart(icon, UDim2.fromOffset(size - 10, size - 9), UDim2.fromOffset(5, 3), THEME.Muted, 3, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(2, 4), THEME.Muted, 3, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(size - 6, 4), THEME.Muted, 3, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 5), UDim2.fromOffset(math.floor(size / 2) - 2, size - 7), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 8, 3), UDim2.fromOffset(4, size - 3), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 14, 2), UDim2.fromOffset(7, 7), THEME.Black2, 2, 0, "IconCutout")
	elseif key == "utilities" then
		-- Utilidades: controles deslizantes.
		makeIconPart(icon, UDim2.fromOffset(size - 2, 2), UDim2.fromOffset(1, 3), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 2, 2), UDim2.fromOffset(1, 8), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 2, 2), UDim2.fromOffset(1, 13), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(5, 1), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(10, 6), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(4, 11), THEME.Muted, 2, 0)
	else
		makeIconPart(icon, UDim2.fromOffset(size - 3, size - 3), UDim2.fromOffset(1, 1), THEME.Muted, 4, 0)
	end

	return icon
end

local function createNavCornerAccent(parent, compact)
	local wrap = Instance.new("Frame")
	wrap.Name = "ActiveAccent"
	wrap.BackgroundTransparency = 1
	wrap.BorderSizePixel = 0
	wrap.Size = UDim2.fromScale(1, 1)
	wrap.Parent = parent
	wrap.Visible = false

	local edge = compact and 9 or 11
	local thick = 2
	local inset = compact and 5 or 6
	local fade = THEME.Brown3
	local bright = THEME.BrownNeon

	local function bar(size, pos, rotation, gradA, gradB, gradRot)
		local f = Instance.new("Frame")
		f.Name = "IconPart"
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = bright
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.Parent = wrap
		corner(f, 99)
		gradient(f, gradA, gradB, gradRot or 0)
		return f
	end

	bar(UDim2.fromOffset(edge, thick), UDim2.fromOffset(inset, inset), 0, bright, fade, 0)
	bar(UDim2.fromOffset(thick, edge), UDim2.fromOffset(inset, inset), 0, bright, fade, 90)
	bar(UDim2.fromOffset(edge, thick), UDim2.new(1, -(inset + edge), 0, inset), 0, fade, bright, 0)
	bar(UDim2.fromOffset(thick, edge), UDim2.new(1, -(inset + thick), 0, inset), 0, bright, fade, 90)
	bar(UDim2.fromOffset(edge, thick), UDim2.fromOffset(inset, compact and 37 or 41), 0, bright, fade, 0)
	bar(UDim2.fromOffset(thick, edge), UDim2.new(0, inset, 1, -(inset + edge)), 0, fade, bright, 90)
	bar(UDim2.fromOffset(edge, thick), UDim2.new(1, -(inset + edge), 1, -(inset + thick)), 0, fade, bright, 0)
	bar(UDim2.fromOffset(thick, edge), UDim2.new(1, -(inset + thick), 1, -(inset + edge)), 0, fade, bright, 90)

	return wrap
end

local function buildUI(T, languageCode)
	destroyOldGui("HexaPremiumHub")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HexaPremiumHub"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2147483647
	parentGui(gui)

	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1000, 700)
	local compact = HEXA_MOBILE
	local windowW = compact and math.floor(math.min(282, math.max(248, vp.X - 58))) or math.floor(math.min(700, math.max(590, vp.X - 170)))
	local windowH = compact and math.floor(math.min(410, math.max(340, vp.Y - 108))) or math.floor(math.min(470, math.max(400, vp.Y - 130)))
	local sideW = compact and math.max(94, math.floor(windowW * 0.30)) or 168
	local headerH = compact and 64 or 70

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 8)
	shadow.Size = UDim2.fromOffset(windowW + 14, windowH + 14)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.42
	shadow.BorderSizePixel = 0
	shadow.Parent = gui
	shadow.Visible = false
	corner(shadow, 26)

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromOffset(windowW, windowH)
	main.BackgroundColor3 = THEME.BrownNeon
	main.BorderSizePixel = 0
	main.ClipsDescendants = false
	main.Parent = gui
	corner(main, 30)

	-- Rounded shell + inset surface. Children never touch the outer corners,
	-- avoiding Roblox's rectangular child clipping behavior with UICorner.
	local shellInset = 1
	local shellRadius = 30
	local surfaceRadius = math.max(0, shellRadius - shellInset)
	local surface = Instance.new("Frame")
	surface.Name = "Surface"
	surface.Position = UDim2.fromOffset(shellInset, shellInset)
	surface.Size = UDim2.new(1, -(shellInset * 2), 1, -(shellInset * 2))
	surface.BackgroundColor3 = THEME.Black2
	surface.BorderSizePixel = 0
	surface.ClipsDescendants = true
	surface.Parent = main
	-- El radio interior debe seguir exactamente la curva exterior para que
	-- el borde de 1 px también sea visible en las cuatro esquinas.
	corner(surface, surfaceRadius)
	neonStroke(surface, THEME.Brown2, 0.72, 0.18)
	local surfaceGradient = Instance.new("UIGradient")
	surfaceGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, THEME.Black),
		ColorSequenceKeypoint.new(0.44, THEME.Black2),
		ColorSequenceKeypoint.new(0.52, THEME.Brown),
		ColorSequenceKeypoint.new(1.00, THEME.Brown2),
	})
	surfaceGradient.Rotation = 0
	surfaceGradient.Parent = surface

	local outerPad = 5
	local headerH2 = headerH - 2
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(outerPad, outerPad)
	header.Size = UDim2.new(1, -(outerPad * 2), 0, headerH2)
	header.BackgroundColor3 = THEME.Black2
	header.BorderSizePixel = 0
	header.Parent = surface
	corner(header, 17)
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(THEME.Black, THEME.Brown)
	headerGradient.Rotation = 0
	headerGradient.Parent = header
	neonStroke(header, THEME.Brown2, 0.7, 0.7)


	local logoImage = Instance.new("ImageLabel")
	logoImage.Name = "Logo"
	logoImage.BackgroundTransparency = 1
	logoImage.BorderSizePixel = 0
	logoImage.Image = "rbxassetid://80552458381492"
	logoImage.ScaleType = Enum.ScaleType.Fit
	logoImage.Size = UDim2.fromOffset(compact and 54 or 68, compact and 54 or 68)
	logoImage.Position = UDim2.new(0, compact and 10 or 14, 0.5, compact and -27 or -34)
	logoImage.Parent = header

	local titleWrap = Instance.new("Frame")
	titleWrap.Name = "TitleWrap"
	titleWrap.BackgroundTransparency = 1
	titleWrap.BorderSizePixel = 0
	titleWrap.Position = UDim2.new(0, compact and 68 or 94, 0.5, compact and -13 or -15)
	titleWrap.Size = UDim2.new(1, compact and -156 or -220, 0, compact and 26 or 30)
	titleWrap.Parent = header

	local title = makeLabel(titleWrap, 'SPEED <font color="rgb(194,83,20)">MONKEY</font> SCAPE', compact and 15 or 19, THEME.White, Enum.Font.GothamBlack)
	title.RichText = true
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.fromScale(1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextScaled = false
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.None

	local function headerButton(text, offset, danger)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, offset, 0.5, 0)
		b.Size = UDim2.fromOffset(compact and 34 or 38, compact and 34 or 38)
		b.BackgroundColor3 = THEME.Panel2
		b.BorderSizePixel = 0
		b.Text = text
		b.TextSize = compact and 15 or 17
		b.TextColor3 = danger and Color3.fromRGB(236, 178, 170) or THEME.White
		b.Font = Enum.Font.GothamBold
		b.AutoButtonColor = false
		b.Parent = header
		corner(b, 12)
		stroke(b, danger and THEME.Danger or THEME.Line, danger and 0.62 or 0.72, 0.7)
		addHover(b, THEME.Panel2, danger and Color3.fromRGB(69, 30, 27) or THEME.CardHover)
		return b
	end

	local close = headerButton("×", -16, true)
	local minimize = headerButton("—", compact and -56 or -62, false)

	local side = Instance.new("Frame")
	side.Name = "Sidebar"
	side.Position = UDim2.fromOffset(outerPad, headerH2 + outerPad + 4)
	side.Size = UDim2.new(0, sideW - outerPad, 1, -(headerH2 + outerPad * 3 + 4))
	side.BackgroundColor3 = THEME.Black2
	side.BorderSizePixel = 0
	side.Parent = surface
	corner(side, 16)
	local sideGradient = Instance.new("UIGradient")
	sideGradient.Color = ColorSequence.new(THEME.Black, THEME.Panel2)
	sideGradient.Rotation = 90
	sideGradient.Parent = side
	neonStroke(side, THEME.Brown, 0.76, 0.7)

	local sideDivider = Instance.new("Frame")
	sideDivider.AnchorPoint = Vector2.new(1, 0)
	sideDivider.Position = UDim2.new(1, 0, 0, 0)
	sideDivider.Size = UDim2.new(0, 1, 1, 0)
	sideDivider.BackgroundColor3 = THEME.BrownNeon
	sideDivider.BackgroundTransparency = 0.78
	sideDivider.BorderSizePixel = 0
	sideDivider.Parent = side

	local navTitle = makeLabel(side, compact and "MENU" or "SECTIONS", compact and 9 or 10, THEME.Brown3, Enum.Font.GothamBold)
	navTitle.Position = UDim2.fromOffset(compact and 12 or 18, 18)
	navTitle.Size = UDim2.new(1, -(compact and 24 or 36), 0, 20)

	local navHolder = Instance.new("ScrollingFrame")
	navHolder.BackgroundTransparency = 1
	navHolder.BorderSizePixel = 0
	navHolder.Position = UDim2.fromOffset(compact and 8 or 12, 46)
	navHolder.Size = UDim2.new(1, -(compact and 16 or 24), 1, -(compact and 112 or 122))
	navHolder.CanvasSize = UDim2.new()
	navHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	navHolder.ScrollingDirection = Enum.ScrollingDirection.Y
	navHolder.ScrollBarThickness = compact and 2 or 3
	navHolder.ScrollBarImageColor3 = THEME.Brown2
	navHolder.ScrollBarImageTransparency = 0.25
	navHolder.Parent = side

	local navLayout = Instance.new("UIListLayout")
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Padding = UDim.new(0, 9)
	navLayout.Parent = navHolder

	local profile = Instance.new("Frame")
	profile.AnchorPoint = Vector2.new(0, 1)
	profile.Position = UDim2.new(0, compact and 8 or 12, 1, -14)
	profile.Size = UDim2.new(1, -(compact and 16 or 24), 0, compact and 44 or 48)
	profile.BackgroundColor3 = THEME.Panel2
	profile.BorderSizePixel = 0
	profile.Parent = side
	corner(profile, 14)
	stroke(profile, THEME.Line, 0.62, 0.8)

	local avatar = Instance.new("ImageLabel")
	avatar.Size = UDim2.fromOffset(compact and 30 or 34, compact and 30 or 34)
	avatar.Position = UDim2.new(0, 9, 0.5, compact and -15 or -17)
	avatar.BackgroundColor3 = THEME.Card
	avatar.BorderSizePixel = 0
	avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150"
	avatar.Parent = profile
	corner(avatar, 10)

	local user = makeLabel(profile, LocalPlayer.DisplayName, compact and 10 or 12, THEME.White, Enum.Font.GothamBold)
	user.Position = UDim2.fromOffset(compact and 47 or 54, 0)
	user.Size = UDim2.new(1, -(compact and 54 or 62), 1, 0)
	user.TextTruncate = Enum.TextTruncate.AtEnd

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(sideW + outerPad + 4, headerH2 + outerPad + 4)
	content.Size = UDim2.new(1, -(sideW + outerPad * 3 + 4), 1, -(headerH2 + outerPad * 3 + 4))
	content.BackgroundColor3 = THEME.Brown
	content.BorderSizePixel = 0
	content.Parent = surface
	corner(content, 16)
	local contentGradient = Instance.new("UIGradient")
	contentGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, THEME.Brown),
		ColorSequenceKeypoint.new(0.48, THEME.Panel2),
		ColorSequenceKeypoint.new(1.00, THEME.Black2),
	})
	contentGradient.Rotation = 25
	contentGradient.Parent = content
	neonStroke(content, THEME.BrownNeon, 0.76, 0.7)

	local pageHolder = Instance.new("Frame")
	pageHolder.BackgroundTransparency = 1
	pageHolder.Position = UDim2.fromOffset(compact and 12 or 18, compact and 12 or 16)
	pageHolder.Size = UDim2.new(1, -(compact and 24 or 36), 1, -(compact and 24 or 32))
	pageHolder.Parent = content

	local pages = {}
	local navButtons = {}
	local currentPage = nil

	local function createPage(key, title)
		local page = Instance.new("ScrollingFrame")
		page.Name = key
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = compact and 3 or 4
		page.ScrollBarImageColor3 = THEME.Brown2
		page.ScrollBarImageTransparency = 0.15
		page.CanvasSize = UDim2.new()
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.ScrollingDirection = Enum.ScrollingDirection.Y
		page.Visible = false
		page.Parent = pageHolder
		padding(page, 0, compact and 4 or 8, 0, 12)

		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, compact and 10 or 12)
		list.Parent = page




		pages[key] = page
		return page
	end

	local function createSection(page, titleText)
		local section = Instance.new("Frame")
		section.BackgroundColor3 = THEME.Black2
		section.BorderSizePixel = 0
		section.Size = UDim2.new(1, 0, 0, 0)
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Parent = page
		corner(section, 13)
		local sectionGradient = Instance.new("UIGradient")
		sectionGradient.Color = ColorSequence.new(THEME.Black2, THEME.Panel2)
		sectionGradient.Rotation = 20
		sectionGradient.Parent = section
		neonStroke(section, THEME.Brown, 0.62, 0.8)
		padding(section, compact and 9 or 12, compact and 9 or 12, compact and 9 or 11, compact and 9 or 11)

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, compact and 7 or 8)
		layout.Parent = section

		local titleRow = Instance.new("Frame")
		titleRow.LayoutOrder = 1
		titleRow.BackgroundTransparency = 1
		titleRow.Size = UDim2.new(1, 0, 0, compact and 26 or 30)
		titleRow.Parent = section

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(7, 7)
		dot.Position = UDim2.new(0, 1, 0.5, -3)
		dot.BackgroundColor3 = THEME.Brown3
		dot.BorderSizePixel = 0
		dot.Parent = titleRow
		corner(dot, 4)
		local dotScale = getScale(dot, "HEXA_DotScale")
		dotScale.Scale = 0.35
		tween(dotScale, 0.30, { Scale = 1 }, Enum.EasingStyle.Back)

		local t = makeLabel(titleRow, string.upper(titleText), compact and 10 or 11, THEME.Muted, Enum.Font.GothamBold)
		t.Position = UDim2.fromOffset(17, 0)
		t.Size = UDim2.new(1, -17, 1, 0)

		return section
	end

	local function createToggle(section, titleText, initial, callback)
		local row = Instance.new("TextButton")
		row.BackgroundColor3 = THEME.Card
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, compact and 48 or 52)
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = section
		corner(row, 10)
		local rowStroke = neonStroke(row, THEME.Brown, 0.78, 0.7)

		local text = makeLabel(row, titleText, compact and 11 or 12, THEME.White, Enum.Font.GothamMedium)
		text.Position = UDim2.fromOffset(compact and 12 or 14, 0)
		text.Size = UDim2.new(1, compact and -62 or -72, 1, 0)
		text.TextTruncate = Enum.TextTruncate.AtEnd

		local track = Instance.new("Frame")
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.Position = UDim2.new(1, -(compact and 10 or 13), 0.5, 0)
		track.Size = UDim2.fromOffset(compact and 38 or 42, compact and 22 or 24)
		track.BackgroundColor3 = THEME.Soft
		track.BorderSizePixel = 0
		track.Parent = row
		corner(track, 20)
		stroke(track, THEME.Line, 0.62, 0.8)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(compact and 16 or 18, compact and 16 or 18)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Position = UDim2.new(0, 3, 0.5, 0)
		knob.BackgroundColor3 = THEME.White
		knob.BorderSizePixel = 0
		knob.Parent = track
		corner(knob, 20)

		local state = initial == true
		local function render(animated)
			local propsTrack = { BackgroundColor3 = state and THEME.BrownNeon or THEME.Soft }
			local propsKnob = { Position = state and UDim2.new(1, -(compact and 19 or 21), 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }
			if animated then
				tween(track, 0.18, propsTrack)
				tween(knob, 0.18, propsKnob)
			else
				for k, v in pairs(propsTrack) do track[k] = v end
				for k, v in pairs(propsKnob) do knob[k] = v end
			end
			rowStroke.Color = state and THEME.BrownNeon or THEME.Brown
			rowStroke.Transparency = state and 0.18 or 0.72
		end
		render(false)

		row.MouseEnter:Connect(function() tween(row, 0.14, { BackgroundColor3 = THEME.CardHover }) end)
		row.MouseLeave:Connect(function() tween(row, 0.14, { BackgroundColor3 = THEME.Card }) end)
		row.MouseButton1Click:Connect(function()
			pressBounce(row, 0.975)
			state = not state
			render(true)
			local knobScale = getScale(knob, "HEXA_KnobScale")
			knobScale.Scale = 0.78
			tween(knobScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
			pcall(callback, state)
		end)
		return row
	end

	local function createButton(section, titleText, callback)
		local row = Instance.new("TextButton")
		row.BackgroundColor3 = THEME.Card
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, compact and 48 or 52)
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = section
		corner(row, 10)
		local st = neonStroke(row, THEME.BrownNeon, 0.62, 0.7)


		local text = makeLabel(row, titleText, compact and 11 or 12, THEME.White, Enum.Font.GothamMedium)
		text.Position = UDim2.fromOffset(compact and 12 or 14, 0)
		text.Size = UDim2.new(1, compact and -56 or -68, 1, 0)
		text.TextTruncate = Enum.TextTruncate.AtEnd

		local action = makeLabel(row, "›", compact and 22 or 24, THEME.Brown3, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		action.AnchorPoint = Vector2.new(1, 0)
		action.Position = UDim2.new(1, -(compact and 9 or 12), 0, 0)
		action.Size = UDim2.fromOffset(compact and 30 or 34, compact and 48 or 52)

		row.MouseEnter:Connect(function()
			tween(row, 0.14, { BackgroundColor3 = THEME.CardHover })
			st.Transparency = 0.15
		end)
		row.MouseLeave:Connect(function()
			tween(row, 0.14, { BackgroundColor3 = THEME.Card })
			st.Transparency = 0.5
		end)
		row.MouseButton1Click:Connect(function()
			pressBounce(row, 0.97)
			tween(action, 0.08, { Position = UDim2.new(1, -(compact and 5 or 8), 0, 0) }, Enum.EasingStyle.Quad)
			task.delay(0.09, function() if action and action.Parent then tween(action, 0.16, { Position = UDim2.new(1, -(compact and 9 or 12), 0, 0) }, Enum.EasingStyle.Back) end end)
			task.spawn(callback)
		end)
		return row
	end

	local function createSelector(section, titleText, defaultValue, getOptions, callback)
		local row = Instance.new("TextButton")
		row.BackgroundColor3 = THEME.Card
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, compact and 48 or 52)
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = section
		corner(row, 10)
		stroke(row, THEME.Line, 0.72, 0.8)

		local title = makeLabel(row, titleText, compact and 10 or 11, THEME.White, Enum.Font.GothamMedium)
		title.Position = UDim2.fromOffset(compact and 12 or 14, 0)
		title.Size = UDim2.new(0.55, -12, 1, 0)
		title.TextTruncate = Enum.TextTruncate.AtEnd

		local current = tostring(defaultValue)
		local value = makeLabel(row, current .. "  ›", compact and 9 or 10, THEME.Brown3, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
		value.Position = UDim2.new(0.55, 0, 0, 0)
		value.Size = UDim2.new(0.45, -(compact and 12 or 14), 1, 0)
		value.TextTruncate = Enum.TextTruncate.AtEnd

		row.MouseButton1Click:Connect(function()
			pressBounce(row, 0.975)
			local options = type(getOptions) == "function" and getOptions() or getOptions
			if type(options) ~= "table" or #options == 0 then return end
			local index = 0
			for i, option in ipairs(options) do if tostring(option) == current then index = i break end end
			index = (index % #options) + 1
			current = tostring(options[index])
			value.Text = current .. "  ›"
			local valueScale = getScale(value, "HEXA_ValueScale")
			valueScale.Scale = 0.86
			tween(valueScale, 0.20, { Scale = 1 }, Enum.EasingStyle.Back)
			pcall(callback, current)
		end)
		return row
	end

	local function createSlider(section, titleText, minValue, maxValue, defaultValue, step, callback)
		local row = Instance.new("Frame")
		row.BackgroundColor3 = THEME.Card
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, compact and 72 or 78)
		row.Parent = section
		corner(row, 10)
		stroke(row, THEME.Line, 0.72, 0.8)

		local text = makeLabel(row, titleText, compact and 10 or 11, THEME.White, Enum.Font.GothamMedium)
		text.Position = UDim2.fromOffset(compact and 12 or 14, 7)
		text.Size = UDim2.new(1, -84, 0, 24)
		text.TextTruncate = Enum.TextTruncate.AtEnd

		local valueBox = Instance.new("Frame")
		valueBox.AnchorPoint = Vector2.new(1, 0)
		valueBox.Position = UDim2.new(1, -(compact and 10 or 13), 0, 8)
		valueBox.Size = UDim2.fromOffset(compact and 50 or 56, 23)
		valueBox.BackgroundColor3 = THEME.Panel2
		valueBox.BorderSizePixel = 0
		valueBox.Parent = row
		corner(valueBox, 7)
		stroke(valueBox, THEME.Brown, 0.68, 0.8)

		local valueLabel = makeLabel(valueBox, string.format("%.2f", defaultValue), compact and 9 or 10, THEME.Brown3, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		valueLabel.Size = UDim2.fromScale(1, 1)

		local bar = Instance.new("TextButton")
		bar.Position = UDim2.new(0, compact and 12 or 14, 1, -(compact and 25 or 28))
		bar.Size = UDim2.new(1, -(compact and 24 or 28), 0, 7)
		bar.BackgroundColor3 = THEME.Soft
		bar.BorderSizePixel = 0
		bar.Text = ""
		bar.AutoButtonColor = false
		bar.Parent = row
		corner(bar, 8)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 1, 0)
		fill.BackgroundColor3 = THEME.Brown2
		fill.BorderSizePixel = 0
		fill.Parent = bar
		corner(fill, 8)
		gradient(fill, THEME.Brown, THEME.BrownNeon, 0)

		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 0.5, 0)
		knob.Size = UDim2.fromOffset(compact and 14 or 16, compact and 14 or 16)
		knob.BackgroundColor3 = THEME.White
		knob.BorderSizePixel = 0
		knob.Parent = bar
		corner(knob, 10)
		neonStroke(knob, THEME.BrownNeon, 0.20, 1)

		local dragging = false
		local current = defaultValue
		local function setFromX(x)
			local width = math.max(bar.AbsoluteSize.X, 1)
			local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
			local raw = minValue + (maxValue - minValue) * alpha
			local snapped = math.floor((raw / step) + 0.5) * step
			current = math.clamp(snapped, minValue, maxValue)
			local a = (current - minValue) / (maxValue - minValue)
			tween(fill, 0.08, { Size = UDim2.new(a, 0, 1, 0) }, Enum.EasingStyle.Quad)
			tween(knob, 0.08, { Position = UDim2.new(a, 0, 0.5, 0) }, Enum.EasingStyle.Quad)
			valueLabel.Text = string.format("%.2f", current)
			pcall(callback, current)
		end

		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				local knobScale = getScale(knob, "HEXA_SliderKnobScale")
				tween(knobScale, 0.10, { Scale = 1.28 }, Enum.EasingStyle.Back)
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				local knobScale = getScale(knob, "HEXA_SliderKnobScale")
				tween(knobScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
		return row
	end

	-- Categorías separadas por propósito para que cada función esté donde corresponde.
	local farmPage = createPage("farm", T.tabFarm)
	local progressPage = createPage("progress", T.tabProgress)
	local teleportPage = createPage("teleports", T.tabTeleport)
	local playerPage = createPage("player", T.tabPlayer)
	local protectionPage = createPage("protection", T.tabProtection)
	local racePage = createPage("races", T.tabRace)
	local collectionPage = createPage("collection", T.tabCollection)
	local rewardPage = createPage("rewards", T.tabRewards)
	local utilitiesPage = createPage("utilities", T.tabUtilities)

	local farmSec = createSection(farmPage, T.secFarm)
	createToggle(farmSec, T.farmWins, false, function(v) S.FarmWins = v end)
	createToggle(farmSec, T.stayStill, false, function(v)
		S.StayStill = v
		if not v then
			local root = hrp()
			if root then root.Anchored = false end
		end
	end)
	createSlider(farmSec, T.farmSpeed, 0.05, 2, 0.35, 0.05, function(v) S.FarmDelay = v end)
	createToggle(farmSec, T.smartDelay, false, function(v) S.SmartFarmDelay = v; adaptiveFarmDelay = S.FarmDelay; lastSmartWins = nil end)

	local trainingSec = createSection(farmPage, T.secTraining)
	createToggle(trainingSec, T.farmSteps, false, function(v)
		S.FarmSteps = v
		if v then treadmillCacheAt = 0 end
	end)
	createToggle(trainingSec, T.autoTreadmill, false, function(v)
		S.AutoTreadmill = v
		if v then treadmillCacheAt = 0 end
	end)
	createSelector(trainingSec, T.treadmillSelector, "Auto", function()
		local out = { "Auto" }
		for _, mill in ipairs(getTreadmills()) do table.insert(out, mill.Name) end
		return out
	end, function(v) S.TreadmillMode = v end)
	createToggle(trainingSec, T.runInPlace, false, function(v) S.RunInPlace = v end)

	local routeSec = createSection(progressPage, T.secRoute)
	createSelector(routeSec, T.worldSelector, "Auto", { "Auto", "World 1", "World 2", "World 3", "World 4", "World 5" }, function(v) S.FarmWorldMode = v end)
	createSelector(routeSec, T.stageSelector, "Auto", function()
		local out = { "Auto" }
		local stages = getStages(selectedWorldNumber())
		if #stages > 0 then
			for _, stage in ipairs(stages) do table.insert(out, "Stage " .. tostring(stageNumber(stage))) end
		else
			for i = 1, 15 do table.insert(out, "Stage " .. tostring(i)) end
		end
		return out
	end, function(v) S.StageMode = v end)
	createToggle(routeSec, T.autoBestStage, false, function(v) S.AutoBestStage = v end)
	createToggle(routeSec, T.bestWorld, false, function(v) S.BestWorld = v end)

	local buySec = createSection(progressPage, T.secBuy)
	createToggle(buySec, T.buyTrail, false, function(v) S.BuyTrail = v end)
	createToggle(buySec, T.buyAura, false, function(v) S.BuyAura = v end)
	createToggle(buySec, T.buyUpgrades, false, function(v) S.BuyUpgrades = v end)
	createToggle(buySec, T.equipTrail, false, function(v) S.EquipBestTrail = v end)
	createToggle(buySec, T.equipAura, false, function(v) S.EquipBestAura = v end)
	createToggle(buySec, T.buyCharms, false, function(v) S.BuyCharms = v end)
	createToggle(buySec, T.charms, false, function(v) S.BestCharms = v end)
	createButton(buySec, T.bestUpgradeNow, bestUpgradeNow)
	createToggle(buySec, T.rebirth, false, function(v) S.AutoRebirth = v end)
	createSelector(buySec, T.rebirthMode, T.rebirthInstant, { T.rebirthInstant, T.rebirthMinimum }, function(v) S.RebirthMode = (v == T.rebirthInstant) and "Instant" or "Minimum" end)
	createSlider(buySec, T.minRebirth, 1, 500, 50, 1, function(v) S.MinRebirthLevel = math.floor(v) end)

	local teleportSec = createSection(teleportPage, T.secTeleport)
	createButton(teleportSec, T.tpTreadmill, teleportBestTreadmill)
	createButton(teleportSec, T.tpStage, teleportSelectedStage)
	createButton(teleportSec, T.tpWorld, teleportSelectedWorld)
	createButton(teleportSec, T.tpReturn, teleportReturnSpawn)

	local playerSec = createSection(playerPage, T.secPlayer)
	createSlider(playerSec, T.walkSpeed, 16, 250, 16, 1, function(v)
		S.WalkSpeedValue = math.floor(v)
		pcall(applyMovementSettings)
	end)
	createToggle(playerSec, T.highJump, false, function(v)
		S.HighJump = v
		pcall(applyMovementSettings)
	end)
	createSlider(playerSec, T.jumpPower, 50, 200, 85, 5, function(v)
		S.JumpPowerValue = math.floor(v)
		if S.HighJump then pcall(applyMovementSettings) end
	end)
	createToggle(playerSec, T.infiniteJump, false, function(v) S.InfiniteJump = v end)
	createToggle(playerSec, T.longJump, false, function(v) S.LongJump = v end)
	createSlider(playerSec, T.longJumpPower, 30, 180, 80, 5, function(v) S.LongJumpPower = math.floor(v) end)
	createToggle(playerSec, T.bunnyHop, false, function(v) S.BunnyHop = v end)
	createButton(playerSec, T.superJump, superJump)
	createButton(playerSec, T.dash, dashForward)
	createSlider(playerSec, T.dashPower, 30, 200, 90, 5, function(v) S.DashPower = math.floor(v) end)
	createSlider(playerSec, T.gravity, 60, 260, ORIGINAL_GRAVITY, 5, function(v)
		S.GravityValue = v
		workspace.Gravity = v
	end)
	createSlider(playerSec, T.hipHeight, 0, 8, 0, 0.5, function(v)
		S.HipHeightOffset = v
		pcall(applyMovementSettings)
	end)
	createToggle(playerSec, T.noclip, false, function(v)
		S.Noclip = v
		pcall(applyNoclip, v)
	end)

	local protectionSec = createSection(protectionPage, T.secProtection)
	createToggle(protectionSec, T.godMode, false, function(v)
		S.GodMode = v
		if v then
			installAntiDeathHook()
			pcall(applyHazardProtection, true)
			pcall(protectCharacter)
		else
			if not S.IgnoreHazards then pcall(applyHazardProtection, false) end
			if godHealthConn then pcall(function() godHealthConn:Disconnect() end); godHealthConn = nil end
			local h = humanoid()
			if h then
				local original = godOriginalHumanoid[h]
				pcall(function()
					h.PlatformStand = false
					if original then
						h.MaxHealth = original.MaxHealth or h.MaxHealth
						h.BreakJointsOnDeath = original.BreakJointsOnDeath ~= false
						if original.DeadEnabled ~= nil then h:SetStateEnabled(Enum.HumanoidStateType.Dead, original.DeadEnabled) else h:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
						if original.FallingEnabled ~= nil then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, original.FallingEnabled) else h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end
					else
						h:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
						h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
					end
				end)
				local ff = h.Parent and h.Parent:FindFirstChild("HEXA_GodForceField")
				if ff then pcall(function() ff:Destroy() end) end
			end
			godHumanoid = nil
		end
	end)
	createToggle(protectionSec, T.ignoreHazards, false, function(v)
		S.IgnoreHazards = v
		if v then pcall(applyHazardProtection, true) elseif not S.GodMode then pcall(applyHazardProtection, false) end
	end)
	createToggle(protectionSec, T.antiFall, false, function(v) S.AntiFall = v end)
	createToggle(protectionSec, T.autoRespawn, false, function(v) S.AutoRespawn = v end)
	createToggle(protectionSec, T.autoResume, false, function(v) S.AutoResume = v end)

	local raceSec = createSection(racePage, T.secRace)
	createToggle(raceSec, T.joinRace, false, function(v) S.JoinRace = v end)
	createToggle(raceSec, T.winRace, false, function(v) S.WinRace = v end)

	local collectSec = createSection(collectionPage, T.secCollect)
	createToggle(collectSec, T.bananas, false, function(v) S.Bananas = v end)
	createToggle(collectSec, T.tacos, false, function(v) S.Tacos = v end)
	createToggle(collectSec, T.lucky, false, function(v) S.LuckyBlocks = v end)
	createToggle(collectSec, T.portals, false, function(v) S.HackerPortals = v end)
	createSlider(collectSec, T.collectRadius, 0, 1000, 250, 50, function(v) S.CollectRadius = math.floor(v) end)
	createToggle(collectSec, T.nearestFirst, true, function(v) S.CollectNearestFirst = v end)

	local rewardSec = createSection(rewardPage, T.tabRewards)
	createToggle(rewardSec, T.freeReward, false, function(v) S.FreeReward = v end)
	createToggle(rewardSec, T.offline, false, function(v) S.OfflineEarnings = v end)
	createToggle(rewardSec, T.streak, false, function(v) S.StreakRewards = v end)
	createToggle(rewardSec, T.speedPotion, false, function(v) S.SpeedPotion = v end)
	createToggle(rewardSec, T.winsPotion, false, function(v) S.WinsPotion = v end)
	createToggle(rewardSec, T.openChests, false, function(v) S.OpenChests = v end)
	createToggle(rewardSec, T.secretEvent, false, function(v) S.AutoSecretEvent = v end)

	local utilitySec = createSection(utilitiesPage, T.secUtilities)
	createToggle(utilitySec, T.antiAFK, false, function(v) S.AntiAFK = v end)
	createToggle(utilitySec, T.autoRejoin, false, function(v) S.AutoRejoin = v end)
	createToggle(utilitySec, T.performance, false, function(v) S.PerformanceMode = v; pcall(applyPerformanceMode, v) end)
	createButton(utilitySec, T.serverHop, function() hopServer(false) end)
	createButton(utilitySec, T.lowServerHop, function() hopServer(true) end)
	createButton(utilitySec, T.panicStop, panicStop)

	local presetSec = createSection(utilitiesPage, T.secPresets)
	createButton(presetSec, T.presetFull, function() applyPreset("FullAuto") end)
	createButton(presetSec, T.presetSpeed, function() applyPreset("FarmSpeed") end)
	createButton(presetSec, T.presetProgression, function() applyPreset("Progression") end)


	local notifyHolder = Instance.new("Frame")
	notifyHolder.Name = "Notifications"
	notifyHolder.AnchorPoint = Vector2.new(1, 0)
	notifyHolder.Position = UDim2.new(1, -12, 0, 12)
	notifyHolder.Size = UDim2.fromOffset(compact and 250 or 310, 300)
	notifyHolder.BackgroundTransparency = 1
	notifyHolder.Parent = gui
	local notifyLayout = Instance.new("UIListLayout")
	notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifyLayout.Padding = UDim.new(0, 8)
	notifyLayout.Parent = notifyHolder

	local notifyOrder = 0
	local function notify(contentText, duration)
		notifyOrder += 1
		local note = Instance.new("Frame")
		note.LayoutOrder = notifyOrder
		note.Size = UDim2.new(1, 0, 0, compact and 58 or 64)
		note.BackgroundColor3 = THEME.Black2
		note.BackgroundTransparency = 1
		note.BorderSizePixel = 0
		note.Parent = notifyHolder
		corner(note, 12)
		neonStroke(note, THEME.BrownNeon, 0.30, 1)


		local nt = makeLabel(note, "HEXA", compact and 10 or 11, THEME.Brown3, Enum.Font.GothamBold)
		nt.Position = UDim2.fromOffset(14, 8)
		nt.Size = UDim2.new(1, -28, 0, 17)
		local nc = makeLabel(note, contentText, compact and 10 or 11, THEME.White, Enum.Font.Gotham)
		nc.Position = UDim2.fromOffset(14, 25)
		nc.Size = UDim2.new(1, -28, 0, compact and 25 or 29)
		nc.TextWrapped = true
		nc.TextYAlignment = Enum.TextYAlignment.Top

		note.Position = UDim2.fromOffset(30, 0)
		tween(note, 0.2, { BackgroundTransparency = 0.04, Position = UDim2.fromOffset(0, 0) })
		task.delay(duration or 3, function()
			if note and note.Parent then
				tween(note, 0.18, { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 0) })
				task.wait(0.2)
				if note then note:Destroy() end
			end
		end)
	end


	local function setNavButtonState(data, active, instant)
		local duration = instant and 0.01 or 0.18
		local bgColor = active and Color3.fromRGB(20, 12, 8) or THEME.Black2
		local tx = data.button:FindFirstChild("Title")

		tween(data.button, duration, { BackgroundColor3 = bgColor })
		tween(data.fill, duration, { BackgroundTransparency = active and 0.58 or 1 })
		tween(data.glow, duration, { BackgroundTransparency = active and 0.91 or 1 })
		tween(data.innerShade, duration, { BackgroundTransparency = active and 0.84 or 1 })
		data.stroke.Transparency = active and 0.12 or 0.84
		data.stroke.Color = active and THEME.BrownNeon or THEME.Line
		setIconColor(data.icon, active and THEME.BrownNeon or THEME.Muted)
		if tx then tx.TextColor3 = active and THEME.White or THEME.Muted end
	end

	local function createNavButton(key, titleText, order)
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, compact and 44 or 48)
		b.BackgroundColor3 = THEME.Black2
		b.BorderSizePixel = 0
		b.Text = ""
		b.AutoButtonColor = false
		b.ClipsDescendants = false
		b.Parent = navHolder
		corner(b, 14)
		local navStroke = neonStroke(b, THEME.BrownNeon, 0.84, 1)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Color3.fromRGB(48, 23, 12)
		fill.BackgroundTransparency = 1
		fill.BorderSizePixel = 0
		fill.Position = UDim2.fromOffset(1, 1)
		fill.Size = UDim2.new(1, -2, 1, -2)
		fill.ZIndex = 1
		fill.Parent = b
		corner(fill, 13)
		gradient(fill, THEME.Brown, THEME.Black2, 0)

		local innerShade = Instance.new("Frame")
		innerShade.Name = "InnerShade"
		innerShade.BackgroundColor3 = Color3.new(0, 0, 0)
		innerShade.BackgroundTransparency = 1
		innerShade.BorderSizePixel = 0
		innerShade.Position = UDim2.fromOffset(3, 3)
		innerShade.Size = UDim2.new(1, -6, 1, -6)
		innerShade.ZIndex = 2
		innerShade.Parent = b
		corner(innerShade, 11)

		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.BackgroundColor3 = THEME.BrownNeon
		glow.BackgroundTransparency = 1
		glow.BorderSizePixel = 0
		glow.Position = UDim2.fromOffset(-2, -2)
		glow.Size = UDim2.new(1, 4, 1, 4)
		glow.ZIndex = 0
		glow.Parent = b
		corner(glow, 16)
		gradient(glow, THEME.Brown2, THEME.BrownNeon, 0)

		local icon = createNavIcon(b, key, compact)
		icon.ZIndex = 3
		for _, obj in ipairs(icon:GetDescendants()) do
			if obj:IsA("GuiObject") then obj.ZIndex = 3 end
		end

		local tx = makeLabel(b, titleText, compact and 10 or 11, THEME.Muted, Enum.Font.GothamMedium)
		tx.Position = UDim2.fromOffset(compact and 36 or 40, 0)
		tx.Size = UDim2.new(1, -(compact and 44 or 50), 1, 0)
		tx.TextTruncate = Enum.TextTruncate.AtEnd
		tx.Name = "Title"
		tx.ZIndex = 3

		b.MouseEnter:Connect(function()
			if currentPage ~= key then tween(b, 0.12, { BackgroundColor3 = THEME.Panel2 }) end
		end)
		b.MouseLeave:Connect(function()
			if currentPage ~= key then tween(b, 0.12, { BackgroundColor3 = THEME.Black2 }) end
		end)
		b.MouseButton1Click:Connect(function()
			if currentPage == key then
				pressBounce(b, 0.96)
				return
			end
			pressBounce(b, 0.96)
			for k, pg in pairs(pages) do pg.Visible = k == key end
			for k, data in pairs(navButtons) do
				setNavButtonState(data, k == key, false)
			end
			currentPage = key
			animatePageIn(pages[key])
		end)
		navButtons[key] = { button = b, icon = icon, stroke = navStroke, fill = fill, glow = glow, innerShade = innerShade }
		return b
	end

	createNavButton("farm", T.tabFarm, 1)
	createNavButton("progress", T.tabProgress, 2)
	createNavButton("teleports", T.tabTeleport, 3)
	createNavButton("player", T.tabPlayer, 4)
	createNavButton("protection", T.tabProtection, 5)
	createNavButton("races", T.tabRace, 6)
	createNavButton("collection", T.tabCollection, 7)
	createNavButton("rewards", T.tabRewards, 8)
	createNavButton("utilities", T.tabUtilities, 9)

	-- Activate first page without relying on a synthetic button click.
	pages.farm.Visible = true
	currentPage = "farm"
	do
		local data = navButtons.farm
		setNavButtonState(data, true, true)
		animatePageIn(pages.farm)
	end

	-- Dragging: title/header area moves the whole panel.
	local dragging = false
	local dragStart, startPos, dragInput
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	header.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			shadow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset, main.Position.Y.Scale, main.Position.Y.Offset + 9)
		end
	end)

	local minimized = false
	local mini = Instance.new("Frame")
	mini.Name = "MinimizedPanel"
	mini.AnchorPoint = Vector2.new(1, 0.5)
	mini.Position = UDim2.new(1, -18, 0.5, 0)
	mini.Size = UDim2.fromOffset(compact and 214 or 250, compact and 54 or 60)
	mini.BackgroundColor3 = THEME.Panel
	mini.BorderSizePixel = 0
	mini.Visible = false
	mini.Active = true
	mini.Parent = gui
	corner(mini, 15)
	neonStroke(mini, THEME.BrownNeon, 0.24, 1)
	gradient(mini, THEME.Black2, THEME.Brown, 20)

	local restore = Instance.new("TextButton")
	restore.Size = UDim2.fromOffset(compact and 38 or 42, compact and 38 or 42)
	restore.Position = UDim2.fromOffset(8, compact and 8 or 9)
	restore.BackgroundColor3 = THEME.Brown
	restore.BorderSizePixel = 0
	restore.Text = "↗"
	restore.TextColor3 = THEME.White
	restore.TextSize = compact and 17 or 19
	restore.Font = Enum.Font.GothamBold
	restore.AutoButtonColor = false
	restore.Parent = mini
	corner(restore, 11)

	local miniTitle = makeLabel(mini, "HEXA", compact and 11 or 12, THEME.White, Enum.Font.GothamBold)
	miniTitle.Position = UDim2.fromOffset(compact and 54 or 58, 7)
	miniTitle.Size = UDim2.new(1, -(compact and 106 or 118), 0, 20)
	local miniSub = makeLabel(mini, "SPEED MONKEY SCAPE", compact and 8 or 9, THEME.Brown3, Enum.Font.GothamMedium)
	miniSub.Position = UDim2.fromOffset(compact and 54 or 58, 25)
	miniSub.Size = UDim2.new(1, -(compact and 106 or 118), 0, 20)
	miniSub.TextTruncate = Enum.TextTruncate.AtEnd

	local miniLogo = Instance.new("ImageLabel")
	miniLogo.AnchorPoint = Vector2.new(1, 0.5)
	miniLogo.Position = UDim2.new(1, -8, 0.5, 0)
	miniLogo.Size = UDim2.fromOffset(compact and 38 or 44, compact and 38 or 44)
	miniLogo.BackgroundTransparency = 1
	miniLogo.Image = "rbxassetid://80552458381492"
	miniLogo.ScaleType = Enum.ScaleType.Fit
	miniLogo.Parent = mini

	local miniDragging = false
	local miniMoved = false
	local miniStart, miniPos
	local miniScale = getScale(mini, "HEXA_MiniScale")
	miniScale.Scale = 1
	mini.MouseEnter:Connect(function()
		tween(miniScale, 0.14, { Scale = 1.035 }, Enum.EasingStyle.Back)
	end)
	mini.MouseLeave:Connect(function()
		if not miniDragging then tween(miniScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad) end
	end)

	local setMinimized

	-- Toda la superficie del mini panel sirve para restaurar.
	-- Si el usuario arrastra, solo se mueve; si toca/clickea sin arrastrar, se abre.
	local miniHitbox = Instance.new("TextButton")
	miniHitbox.Name = "FullPanelRestoreHitbox"
	miniHitbox.Size = UDim2.fromScale(1, 1)
	miniHitbox.Position = UDim2.fromScale(0, 0)
	miniHitbox.BackgroundTransparency = 1
	miniHitbox.BorderSizePixel = 0
	miniHitbox.Text = ""
	miniHitbox.AutoButtonColor = false
	miniHitbox.ZIndex = 20
	miniHitbox.Parent = mini

	miniHitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			miniDragging = true
			miniMoved = false
			miniStart = input.Position
			miniPos = mini.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if miniDragging and miniStart and miniPos and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - miniStart
			if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then miniMoved = true end
			mini.Position = UDim2.new(miniPos.X.Scale, miniPos.X.Offset + d.X, miniPos.Y.Scale, miniPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if miniDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			local shouldOpen = not miniMoved
			miniDragging = false
			miniMoved = false
			miniStart = nil
			miniPos = nil
			if shouldOpen and setMinimized then setMinimized(false) end
		end
	end)

	local mainScale = getScale(main, "HEXA_MainScale")
	setMinimized = function(value)
		if minimized == value then return end
		minimized = value
		if value then
			tween(mainScale, 0.14, { Scale = 0.92 }, Enum.EasingStyle.Quad)
			task.delay(0.12, function()
				if not minimized or not gui.Parent then return end
				main.Visible = false
				shadow.Visible = false
				mini.Visible = true
				miniScale.Scale = 0.84
				tween(miniScale, 0.20, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		else
			tween(miniScale, 0.10, { Scale = 0.86 }, Enum.EasingStyle.Quad)
			task.delay(0.08, function()
				if minimized or not gui.Parent then return end
				mini.Visible = false
				main.Visible = true
				shadow.Visible = false
				mainScale.Scale = 0.92
				tween(mainScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
				animatePageIn(pages[currentPage])
			end)
		end
	end
	minimize.MouseButton1Click:Connect(function() pressBounce(minimize, 0.90); setMinimized(true) end)

	-- Close confirmation modal.
	local function showCloseModal()
		local blocker = Instance.new("Frame")
		blocker.Size = UDim2.fromScale(1, 1)
		blocker.BackgroundColor3 = THEME.Black
		blocker.BackgroundTransparency = 0.28
		blocker.BorderSizePixel = 0
		blocker.ZIndex = 50
		blocker.Parent = surface
		corner(blocker, 23)

		local modal = Instance.new("Frame")
		modal.AnchorPoint = Vector2.new(0.5, 0.5)
		modal.Position = UDim2.fromScale(0.5, 0.5)
		modal.Size = UDim2.fromOffset(math.min(compact and 286 or 370, windowW - 40), compact and 198 or 214)
		modal.BackgroundColor3 = THEME.Panel2
		modal.BorderSizePixel = 0
		modal.ZIndex = 51
		modal.Parent = blocker
		local modalScale = getScale(modal, "HEXA_ModalScale")
		modalScale.Scale = 0.88
		blocker.BackgroundTransparency = 1
		tween(blocker, 0.16, { BackgroundTransparency = 0.28 })
		tween(modalScale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		corner(modal, 18)
		stroke(modal, THEME.Brown2, 0.42, 0.8)
		addTopAccent(modal).ZIndex = 52

		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.fromOffset(compact and 82 or 92, 24)
		badge.Position = UDim2.fromOffset(18, 16)
		badge.BackgroundColor3 = THEME.Card
		badge.BorderSizePixel = 0
		badge.Text = T.closeTag or "CONFIRM"
		badge.TextColor3 = THEME.Brown3
		badge.TextSize = compact and 9 or 10
		badge.Font = Enum.Font.GothamBold
		badge.ZIndex = 52
		badge.Parent = modal
		corner(badge, 99)
		stroke(badge, THEME.Line, 0.54, 0.8)

		local mt = makeLabel(modal, T.closeTitle, compact and 16 or 18, THEME.White, Enum.Font.GothamBold)
		mt.Position = UDim2.fromOffset(18, 48)
		mt.Size = UDim2.new(1, -36, 0, 28)
		mt.ZIndex = 52

		local md = makeLabel(modal, T.closeDesc, compact and 10 or 11, THEME.Muted, Enum.Font.Gotham)
		md.Position = UDim2.fromOffset(18, 82)
		md.Size = UDim2.new(1, -36, 0, compact and 54 or 60)
		md.TextWrapped = true
		md.TextYAlignment = Enum.TextYAlignment.Top
		md.ZIndex = 52

		local cancel = Instance.new("TextButton")
		cancel.Size = UDim2.new(0.5, -23, 0, 40)
		cancel.Position = UDim2.new(0, 18, 1, -54)
		cancel.BackgroundColor3 = THEME.Card
		cancel.BorderSizePixel = 0
		cancel.Text = T.cancelBtn
		cancel.TextColor3 = THEME.White
		cancel.TextSize = compact and 11 or 12
		cancel.Font = Enum.Font.GothamBold
		cancel.ZIndex = 52
		cancel.Parent = modal
		corner(cancel, 12)
		stroke(cancel, THEME.Line, 0.58, 0.8)

		local yes = Instance.new("TextButton")
		yes.AnchorPoint = Vector2.new(1, 0)
		yes.Size = UDim2.new(0.5, -23, 0, 40)
		yes.Position = UDim2.new(1, -18, 1, -54)
		yes.BackgroundColor3 = THEME.Brown
		yes.BorderSizePixel = 0
		yes.Text = T.closeBtn
		yes.TextColor3 = THEME.White
		yes.TextSize = compact and 11 or 12
		yes.Font = Enum.Font.GothamBold
		yes.ZIndex = 52
		yes.Parent = modal
		corner(yes, 12)
		stroke(yes, THEME.Brown3, 0.5, 0.8)
		gradient(yes, THEME.Brown, THEME.Brown2, 0)

		cancel.MouseEnter:Connect(function() tween(cancel, 0.12, { BackgroundColor3 = THEME.CardHover }) end)
		cancel.MouseLeave:Connect(function() tween(cancel, 0.12, { BackgroundColor3 = THEME.Card }) end)
		yes.MouseEnter:Connect(function() tween(yes, 0.12, { BackgroundColor3 = THEME.Brown2 }) end)
		yes.MouseLeave:Connect(function() tween(yes, 0.12, { BackgroundColor3 = THEME.Brown }) end)
		cancel.MouseButton1Click:Connect(function()
			pressBounce(cancel, 0.95)
			tween(modalScale, 0.12, { Scale = 0.88 }, Enum.EasingStyle.Quad)
			tween(blocker, 0.12, { BackgroundTransparency = 1 })
			task.delay(0.12, function() if blocker and blocker.Parent then blocker:Destroy() end end)
		end)
		yes.MouseButton1Click:Connect(function()
			pressBounce(yes, 0.95)
			shutdownHub()
			if gui and gui.Parent then gui:Destroy() end
		end)
	end
	close.MouseButton1Click:Connect(function() pressBounce(close, 0.90); showCloseModal() end)

	-- Entrada con escala + desplazamiento + aparición del logo.
	local finalPos = main.Position
	local entryScale = getScale(main, "HEXA_MainScale")
	entryScale.Scale = 0.90
	main.Position = UDim2.new(finalPos.X.Scale, finalPos.X.Offset, finalPos.Y.Scale, finalPos.Y.Offset + 22)
	main.BackgroundTransparency = 1
	shadow.BackgroundTransparency = 1
	local logoScale = getScale(logoImage, "HEXA_LogoScale")
	logoScale.Scale = 0.55
	tween(main, 0.30, { Position = finalPos, BackgroundTransparency = 0 }, Enum.EasingStyle.Quint)
	tween(entryScale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(logoScale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)

	logoImage.MouseEnter:Connect(function()
		tween(logoScale, 0.16, { Scale = 1.10 }, Enum.EasingStyle.Back)
	end)
	logoImage.MouseLeave:Connect(function()
		tween(logoScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad)
	end)

	notify(T.loaded, 4)
end

buildUI(L[PREFLIGHT_LANGUAGE] or L.en, PREFLIGHT_LANGUAGE)
