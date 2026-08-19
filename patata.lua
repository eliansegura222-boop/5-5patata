local __BootstrapPlayers = game:GetService("Players")
local __BootstrapPlayer = __BootstrapPlayers.LocalPlayer
if not __BootstrapPlayer then
	__BootstrapPlayers:GetPropertyChangedSignal("LocalPlayer"):Wait()
	__BootstrapPlayer = __BootstrapPlayers.LocalPlayer
end
local __BootstrapPlayerGui = __BootstrapPlayer:WaitForChild("PlayerGui")
local __BootstrapGui = Instance.new("ScreenGui")
__BootstrapGui.Name = "H4SK_Bootstrap"
__BootstrapGui.IgnoreGuiInset = true
__BootstrapGui.ResetOnSpawn = false
__BootstrapGui.DisplayOrder = 2147483647
__BootstrapGui.Parent = __BootstrapPlayerGui

local __BootstrapFrame = Instance.new("Frame")
__BootstrapFrame.Name = "Status"
__BootstrapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
__BootstrapFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
__BootstrapFrame.Size = UDim2.new(0, 290, 0, 96)
__BootstrapFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
__BootstrapFrame.BackgroundTransparency = 0.12
__BootstrapFrame.BorderSizePixel = 0
__BootstrapFrame.Parent = __BootstrapGui
local __BootstrapCorner = Instance.new("UICorner")
__BootstrapCorner.CornerRadius = UDim.new(0, 14)
__BootstrapCorner.Parent = __BootstrapFrame
local __BootstrapStroke = Instance.new("UIStroke")
__BootstrapStroke.Color = Color3.fromRGB(245, 245, 245)
__BootstrapStroke.Transparency = 0.20
__BootstrapStroke.Thickness = 2
__BootstrapStroke.Parent = __BootstrapFrame
local __BootstrapTitle = Instance.new("TextLabel")
__BootstrapTitle.BackgroundTransparency = 1
__BootstrapTitle.Position = UDim2.new(0, 14, 0, 12)
__BootstrapTitle.Size = UDim2.new(1, -28, 0, 24)
__BootstrapTitle.Text = "H3X4 X"
__BootstrapTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
__BootstrapTitle.TextSize = 16
__BootstrapTitle.Font = Enum.Font.GothamBold
__BootstrapTitle.Parent = __BootstrapFrame
local __BootstrapText = Instance.new("TextLabel")
__BootstrapText.BackgroundTransparency = 1
__BootstrapText.Position = UDim2.new(0, 14, 0, 42)
__BootstrapText.Size = UDim2.new(1, -28, 0, 40)
__BootstrapText.Text = "Cargando interfaz..."
__BootstrapText.TextColor3 = Color3.fromRGB(210, 210, 210)
__BootstrapText.TextSize = 12
__BootstrapText.Font = Enum.Font.GothamMedium
__BootstrapText.TextWrapped = true
__BootstrapText.Parent = __BootstrapFrame

task.wait()

local __HexaOk, __HexaError = xpcall(function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = __BootstrapPlayer

local RemoteVipState = (function()
	local VIP_RAW_URL = "https://raw.githubusercontent.com/eliansegura222-boop/5-5patata/refs/heads/main/hx4v1p.lua"

	local function parseExpiration(value)
		if value == nil then return 0 end
		if type(value) == "number" then return math.max(0, math.floor(value)) end
		local text = string.lower(tostring(value):gsub("%s+", ""))
		if text == "" or text == "permanent" or text == "permanente" or text == "never" then return 0 end
		local numeric = tonumber(text)
		if numeric then return math.max(0, math.floor(numeric)) end
		local year, month, day = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
		if not year then return nil end
		local ok, timestamp = pcall(os.time, {
			year = tonumber(year), month = tonumber(month), day = tonumber(day),
			hour = 23, min = 59, sec = 59,
		})
		return ok and timestamp or nil
	end

	local function downloadRaw()
		local url = VIP_RAW_URL .. "?hexax=" .. tostring(os.time())
		local requester = nil
		pcall(function()
			if type(request) == "function" then requester = request
			elseif type(http_request) == "function" then requester = http_request
			elseif type(syn) == "table" and type(syn.request) == "function" then requester = syn.request end
		end)
		if requester then
			local ok, response = pcall(requester, {
				Url = url,
				Method = "GET",
				Headers = { ["Cache-Control"] = "no-cache" },
			})
			if ok and type(response) == "table" then
				local statusCode = tonumber(response.StatusCode or response.Status or response.status_code) or 200
				local body = response.Body or response.body
				if statusCode >= 200 and statusCode < 300 and type(body) == "string" and body ~= "" then return body end
			end
		end
		local ok, body = pcall(function() return game:HttpGet(url, true) end)
		return ok and type(body) == "string" and body or nil
	end

	local function parseEntry(body)
		local userId = tostring(LocalPlayer.UserId)
		local jsonOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
		if jsonOk and type(decoded) == "table" then
			local users = type(decoded.users) == "table" and decoded.users or decoded
			local entry = users[userId]
			if entry == true then return true, 0 end
			if type(entry) == "string" or type(entry) == "number" then
				local expiration = parseExpiration(entry)
				return expiration ~= nil, expiration
			end
			if type(entry) == "table" and entry.vip ~= false and entry.enabled ~= false then
				local expiration = parseExpiration(entry.expires)
				return expiration ~= nil, expiration
			end
			return false, nil
		end

		local quotedKey = "%[%s*[\"']" .. userId .. "[\"']%s*%]"
		local numericKey = "%[%s*" .. userId .. "%s*%]"
		local block = body:match(quotedKey .. "%s*=%s*%{(.-)%}") or body:match(numericKey .. "%s*=%s*%{(.-)%}")
		if block then
			if block:match("vip%s*=%s*false") or block:match("enabled%s*=%s*false") then return false, nil end
			local expirationText = block:match("expires%s*=%s*[\"']([^\"']+)[\"']") or block:match("expires%s*=%s*(%d+)")
			local expiration = parseExpiration(expirationText)
			return expiration ~= nil, expiration
		end
		if body:match(quotedKey .. "%s*=%s*true") or body:match(numericKey .. "%s*=%s*true") then return true, 0 end
		local directExpiration = body:match(quotedKey .. "%s*=%s*[\"']([^\"']+)[\"']")
			or body:match(numericKey .. "%s*=%s*[\"']([^\"']+)[\"']")
		if directExpiration then
			local expiration = parseExpiration(directExpiration)
			return expiration ~= nil, expiration
		end
		return false, nil
	end

	local state = {
		valid = false,
		info = {scope = "REMOTE", targetUserId = LocalPlayer.UserId, expiresAt = 0, permanent = false},
	}
	function state:IsActive()
		return self.valid and (self.info.expiresAt == 0 or os.time() < self.info.expiresAt)
	end
	function state:Refresh()
		local body = downloadRaw()
		if not body then return false end
		local valid, expiresAt = parseEntry(body)
		self.valid = valid == true
		self.info = {
			scope = "REMOTE",
			targetUserId = LocalPlayer.UserId,
			expiresAt = expiresAt or 0,
			permanent = valid == true and expiresAt == 0,
		}
		return true
	end
	pcall(function() __BootstrapText.Text = "Verificando acceso VIP..." end)
	state:Refresh()
	return state
end)()

-- El acceso VIP se controla únicamente desde la lista remota de GitHub.
local HEXA_IS_VIP = RemoteVipState:IsActive()

local AllSliders = {}
local VipControls = {}
local VipStateListeners = {}
local notifyVipLocked = function() end
local BUTTON_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local MOBILE_DEVICE = false

-- Configuración persistente por usuario. Nada se carga automáticamente: el
-- usuario debe pulsar el botón CARGAR CONFIGURACIÓN de forma explícita.
local KeybindManager = nil
local FloatingButtonManager = nil
local ConfigManager = {
	FileName = ("H3X4_X_Config_%d.json"):format(LocalPlayer.UserId),
	ToggleButtons = {},
	ToggleCallbacks = {},
	Sliders = {},
	PendingToggles = nil,
	PendingSliders = nil,
	PendingKeybinds = nil,
	Loading = false,
}

function ConfigManager:NormalizeLabel(value)
	local text = string.lower(tostring(value or ""))
	text = text:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
	text = text:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	return text ~= "" and text or "control"
end

function ConfigManager:GetCardOrder(parent)
	local object = parent
	while object do
		if object:GetAttribute("HexaContentCard") == true then
			return tonumber(object.LayoutOrder) or 0
		end
		object = object.Parent
	end
	return 0
end

function ConfigManager:MakeId(kind, parent, label)
	return tostring(kind) .. ":" .. tostring(self:GetCardOrder(parent)) .. ":" .. self:NormalizeLabel(label)
end

function ConfigManager:RegisterToggle(button, parent, label)
	local id = self:MakeId("toggle", parent, label)
	button:SetAttribute("HexaConfigId", id)
	self.ToggleButtons[id] = button
	return id
end

function ConfigManager:RegisterSlider(controller, parent, label)
	local id = self:MakeId("slider", parent, label)
	controller.ConfigId = id
	self.Sliders[id] = controller
	if self.PendingSliders and self.PendingSliders[id] ~= nil then
		local value = tonumber(self.PendingSliders[id])
		if value then pcall(function() controller.Set(value) end) end
	end
	return id
end

function ConfigManager:SetToggleCallback(button, callback)
	if not button or type(callback) ~= "function" then return end
	local id = button:GetAttribute("HexaConfigId")
	if type(id) ~= "string" then return end
	self.ToggleCallbacks[id] = callback
	if self.PendingToggles and self.PendingToggles[id] ~= nil then
		local desired = self.PendingToggles[id] == true
		task.defer(function()
			if not button or not button.Parent then return end
			if button:GetAttribute("IsActive") ~= desired then
				pcall(callback)
			end
		end)
	end
end

function ConfigManager:AttachSignalCallback(signal, callback)
	if not signal or type(callback) ~= "function" then return end
	for _, button in pairs(self.ToggleButtons) do
		local ok, same = pcall(function() return button.MouseButton1Click == signal end)
		if ok and same then
			self:SetToggleCallback(button, callback)
			return
		end
	end
end

function ConfigManager:BindToggle(button, callback)
	self:SetToggleCallback(button, callback)
	return button.MouseButton1Click:Connect(callback)
end

function ConfigManager:ActivateToggle(button)
	if not button or not button.Parent then return false end
	local id = button:GetAttribute("HexaConfigId")
	local callback = type(id) == "string" and self.ToggleCallbacks[id] or nil
	if type(callback) == "function" then
		local ok = pcall(callback)
		return ok
	end

	-- Respaldo para ejecutores que exponen firesignal/getconnections.
	if type(firesignal) == "function" then
		local ok = pcall(firesignal, button.MouseButton1Click)
		if ok then return true end
	end
	if type(getconnections) == "function" then
		local ok, connections = pcall(getconnections, button.MouseButton1Click)
		if ok and type(connections) == "table" then
			local fired = false
			for _, connection in ipairs(connections) do
				local fn = connection and connection.Function
				if type(fn) == "function" then
					pcall(fn)
					fired = true
				end
			end
			if fired then return true end
		end
	end
	return false
end

function ConfigManager:SetToggleState(button, desired)
	if not button or not button.Parent then return false end
	desired = desired == true
	if button:GetAttribute("IsActive") == desired then return true end
	return self:ActivateToggle(button)
end

function ConfigManager:Save()
	if type(writefile) ~= "function" then return false, "TU EJECUTOR NO PERMITE GUARDAR ARCHIVOS" end
	local payload = {
		version = 3,
		userId = LocalPlayer.UserId,
		toggles = {},
		sliders = {},
		keybinds = KeybindManager and KeybindManager:Serialize() or {},
	}
	for id, button in pairs(self.ToggleButtons) do
		if button and button.Parent then payload.toggles[id] = button:GetAttribute("IsActive") == true end
	end
	for id, controller in pairs(self.Sliders) do
		if controller and type(controller.Get) == "function" then
			local ok, value = pcall(controller.Get)
			if ok and type(value) == "number" then payload.sliders[id] = value end
		end
	end
	local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
	if not ok then return false, "NO SE PUDO CODIFICAR LA CONFIGURACIÓN" end
	local wrote = pcall(function() writefile(self.FileName, encoded) end)
	return wrote, wrote and "CONFIGURACIÓN GUARDADA" or "NO SE PUDO GUARDAR"
end

function ConfigManager:Load()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false, "TU EJECUTOR NO PERMITE CARGAR ARCHIVOS"
	end
	local exists = false
	pcall(function() exists = isfile(self.FileName) end)
	if not exists then return false, "NO HAY CONFIGURACIÓN GUARDADA" end
	local ok, raw = pcall(function() return readfile(self.FileName) end)
	if not ok or type(raw) ~= "string" then return false, "NO SE PUDO LEER LA CONFIGURACIÓN" end
	local decodedOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not decodedOk or type(data) ~= "table" then return false, "CONFIGURACIÓN INVÁLIDA" end
	if tonumber(data.userId) ~= LocalPlayer.UserId then return false, "ESTA CONFIGURACIÓN ES DE OTRO USUARIO" end

	self.PendingToggles = type(data.toggles) == "table" and data.toggles or {}
	self.PendingSliders = type(data.sliders) == "table" and data.sliders or {}
	self.PendingKeybinds = type(data.keybinds) == "table" and data.keybinds or {}
	self.Loading = true

	-- Primero barras y keybinds, luego funciones activadas/desactivadas.
	for id, value in pairs(self.PendingSliders) do
		local controller = self.Sliders[id]
		if controller and type(controller.Set) == "function" then
			local numeric = tonumber(value)
			if numeric then pcall(function() controller.Set(numeric) end) end
		end
	end
	if KeybindManager then KeybindManager:LoadSerialized(self.PendingKeybinds) end
	for id, desired in pairs(self.PendingToggles) do
		local button = self.ToggleButtons[id]
		if button and button.Parent then self:SetToggleState(button, desired == true) end
	end

	self.Loading = false
	return true, "CONFIGURACIÓN CARGADA"
end

local function addVipStateListener(callback)
	table.insert(VipStateListeners, callback)
end

local function refreshVipControls()
	local locked = not HEXA_IS_VIP
	for _, control in ipairs(VipControls) do
		if control and control.Parent then
			-- Los botones VIP de tipo toggle deben conservar EXACTAMENTE la misma geometría
			-- que los toggles normales, incluso después de refrescar el estado VIP.
			if control:IsA("TextButton") and control:GetAttribute("IsToggle") == true then
				local padding = control:FindFirstChildOfClass("UIPadding")
				if padding then padding.PaddingRight = UDim.new(0, 0) end
				local toggleBg = control:FindFirstChild("ToggleBg")
				if toggleBg then
					toggleBg.Position = UDim2.new(1, -48, 0.5, -10)
					toggleBg.Size = UDim2.new(0, 38, 0, 20)
					toggleBg.Visible = true
				end
			end

			local objects = {control}
			for _, child in ipairs(control:GetDescendants()) do
				table.insert(objects, child)
			end

			for _, object in ipairs(objects) do
				local isVipBadge = string.find(object.Name, "HexaVipBadge", 1, true) == 1
				local isVipGlow = object.Name == "HexaVipGlowOuter" or object.Name == "HexaVipGlowInner"
				if not isVipBadge then
					-- Mantener siempre visibles los interruptores de ACTIVADO/DESACTIVADO.
					local isToggleBg = object.Name == "ToggleBg" and object:IsA("GuiObject")
					local isToggleKnob = object.Name == "ToggleKnob" and object:IsA("GuiObject")

					if isToggleBg then
						-- El toggle siempre permanece exactamente en su posición original.
						object.Position = UDim2.new(1, -48, 0.5, -10)
						object.Size = UDim2.new(0, 38, 0, 20)
						object.Visible = true
						object.BackgroundTransparency = locked and 0.02 or 0
						object.BackgroundColor3 = locked and Color3.fromRGB(28, 28, 28) or Color3.fromRGB(22, 22, 22)
					elseif isToggleKnob then
						object.Visible = true
						object.BackgroundTransparency = 0
						if locked then
							object.BackgroundColor3 = Color3.fromRGB(112, 112, 112)
						else
							local ownerButton = object.Parent and object.Parent.Parent
							local isActive = ownerButton and ownerButton:GetAttribute("IsActive") == true
							object.BackgroundColor3 = isActive and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(95, 95, 95)
							object.Position = isActive and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
						end
					elseif object:IsA("GuiObject") then
						if object:GetAttribute("HexaVipOrigBg") == nil then
							object:SetAttribute("HexaVipOrigBg", object.BackgroundColor3)
							object:SetAttribute("HexaVipOrigBgTransparency", object.BackgroundTransparency)
						end
						if locked then
							if object.BackgroundTransparency < 0.98 then
								object.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
							end
						else
							local originalBg = object:GetAttribute("HexaVipOrigBg")
							local originalTransparency = object:GetAttribute("HexaVipOrigBgTransparency")
							if typeof(originalBg) == "Color3" then object.BackgroundColor3 = originalBg end
							if typeof(originalTransparency) == "number" then object.BackgroundTransparency = originalTransparency end
						end
					end

					if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
						if object:GetAttribute("HexaVipOrigTextColor") == nil then
							object:SetAttribute("HexaVipOrigTextColor", object.TextColor3)
						end
						if locked then
							object.TextColor3 = Color3.fromRGB(150, 150, 150)
						else
							local originalTextColor = object:GetAttribute("HexaVipOrigTextColor")
							if typeof(originalTextColor) == "Color3" then object.TextColor3 = originalTextColor end
						end
					end

					if object:IsA("UIStroke") then
						if isVipGlow then
							-- El neón identifica la función bloqueada; al tener VIP desaparece.
							if object:GetAttribute("HexaVipOrigStrokeTransparency") == nil then
								object:SetAttribute("HexaVipOrigStrokeTransparency", object.Transparency)
							end
							local originalGlowTransparency = object:GetAttribute("HexaVipOrigStrokeTransparency")
							object.Transparency = locked and (typeof(originalGlowTransparency) == "number" and originalGlowTransparency or 0.1) or 1
						else
							if object:GetAttribute("HexaVipOrigStrokeColor") == nil then
								object:SetAttribute("HexaVipOrigStrokeColor", object.Color)
							end
							if locked then
								object.Color = Color3.fromRGB(45, 45, 45)
							else
								local originalStrokeColor = object:GetAttribute("HexaVipOrigStrokeColor")
								if typeof(originalStrokeColor) == "Color3" then object.Color = originalStrokeColor end
							end
						end
					end
				end
			end

			local badge = control:FindFirstChild("HexaVipBadge")
			if badge and badge:IsA("GuiObject") then badge.Visible = locked end
		end
	end
end

local function syncVipAccessFromGithub()
	HEXA_IS_VIP = RemoteVipState:IsActive()
	for _, slider in ipairs(AllSliders) do
		pcall(function() slider.Refresh() end)
	end
	refreshVipControls()
	for _, callback in ipairs(VipStateListeners) do
		pcall(callback, HEXA_IS_VIP)
	end
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TargetParent = PlayerGui

local function destroyExistingHexa(parent)
	if not parent then return end
	pcall(function()
		for _, guiName in ipairs({"H4SK", "HexaX"}) do
			local existing = parent:FindFirstChild(guiName)
			if existing then existing:Destroy() end
		end
	end)
end

destroyExistingHexa(PlayerGui)
destroyExistingHexa(CoreGui)
if type(gethui) == "function" then
	pcall(function() destroyExistingHexa(gethui()) end)
end

local Theme = {
	BG = Color3.fromRGB(8, 8, 8),
	Panel = Color3.fromRGB(14, 14, 14),
	Panel2 = Color3.fromRGB(245, 245, 245),
	Accent = Color3.fromRGB(255, 255, 255),
	Accent2 = Color3.fromRGB(218, 218, 218),
	Purple = Color3.fromRGB(245, 245, 245),
	PurpleDark = Color3.fromRGB(165, 165, 165),
	PurpleDeep = Color3.fromRGB(22, 22, 22),
	PurpleText = Color3.fromRGB(235, 235, 235),
	TextMain = Color3.fromRGB(245, 245, 245),
	TextOff = Color3.fromRGB(12, 12, 12),
	Active = Color3.fromRGB(255, 255, 255),
	ActiveText = Color3.fromRGB(255, 255, 255),
	ToggleOn = Color3.fromRGB(245, 245, 245),
	ToggleOff = Color3.fromRGB(95, 95, 95),
	VipGold = Color3.fromRGB(255, 211, 46),
	Danger = Color3.fromRGB(220, 50, 50),
}

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local GUI_VIEWPORT_SIZE = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
local DEVICE_HINT_MOBILE = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or GUI_VIEWPORT_SIZE.X < 900)
-- La detección automática se usa únicamente como sugerencia. Hasta que el usuario
-- elija PC/CELULAR después de la key, no se activa ningún perfil de dispositivo.
MOBILE_DEVICE = false
local function calculateMainSize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or GUI_VIEWPORT_SIZE
	return UDim2.fromOffset(
		math.min(600, math.max(270, viewport.X - 12)),
		math.min(384, math.max(224, viewport.Y - 58))
	)
end
local function calculateKeySize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or GUI_VIEWPORT_SIZE
	return UDim2.fromOffset(
		math.min(340, math.max(250, viewport.X - 12)),
		math.min(230, math.max(210, viewport.Y - 12))
	)
end
local MAIN_SIZE = calculateMainSize()
local KEY_SIZE = calculateKeySize()

local isInteractingWithSlider = false
local Lang = {Current = "ES"}
local UI_READY = false
local PERFORMANCE_MODE = false
local refreshCategoryView = function() end
local refreshFavoritesCard = function() end
local registerFunctionButton = function() end
local registerAllFunctionButtons = function() end
local FunctionSearchBox = nil

local function mkCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function mkStroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function tween(obj: Instance, ti: TweenInfo, props: {[string]: any})
	if PERFORMANCE_MODE then ti = TweenInfo.new(0) end
	local t = TweenService:Create(obj, ti, props)
	t:Play()
	return t
end

AllSliders.RootConnections = {}
function AllSliders.TrackConnection(connection)
	table.insert(AllSliders.RootConnections, connection)
	return connection
end

local function makeDraggable(frame: GuiObject, handle: GuiObject?)
	local dragTarget = handle or frame
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector2? = nil
	local startPos: UDim2? = nil

	dragTarget.InputBegan:Connect(function(input)
		if isInteractingWithSlider then return end 

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragTarget.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	AllSliders.TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and dragInput and input == dragInput and dragStart and startPos then
			local delta = input.Position - dragStart
			-- Actualizar directamente evita crear decenas de Tweens por segundo al arrastrar.
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
end

local function addHover(button: TextButton, idleBg: Color3, hoverBg: Color3, activeBg: Color3?)
	local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		if button:GetAttribute("HexaVipOnly") == true and not HEXA_IS_VIP then
			if PERFORMANCE_MODE then button.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
			else tween(button, ti, {BackgroundColor3 = Color3.fromRGB(18, 18, 18)}) end
			return
		end
		local isToggle = button:GetAttribute("IsToggle")
		local isActive = button:GetAttribute("IsActive") == true
		if isToggle then
			if PERFORMANCE_MODE then button.BackgroundColor3 = hoverBg
			else tween(button, ti, {BackgroundColor3 = hoverBg}) end
		else
			if not isActive then
				if PERFORMANCE_MODE then button.BackgroundColor3 = hoverBg
				else tween(button, ti, {BackgroundColor3 = hoverBg}) end
			end
		end
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("HexaVipOnly") == true and not HEXA_IS_VIP then
			if PERFORMANCE_MODE then button.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
			else tween(button, ti, {BackgroundColor3 = Color3.fromRGB(12, 12, 12)}) end
			return
		end
		local isToggle = button:GetAttribute("IsToggle")
		local isActive = button:GetAttribute("IsActive") == true
		if isToggle then
			if PERFORMANCE_MODE then button.BackgroundColor3 = idleBg
			else tween(button, ti, {BackgroundColor3 = idleBg}) end
		else
			local targetColor = isActive and (activeBg or Theme.Active) or idleBg
			if PERFORMANCE_MODE then button.BackgroundColor3 = targetColor
			else tween(button, ti, {BackgroundColor3 = targetColor}) end
		end
	end)
end

local function neonButton(parent: Instance, text: string, size: UDim2, pos: UDim2, z: number?)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = Theme.PurpleDeep
	btn.BackgroundTransparency = 0.14
	btn.Text = text
	btn.TextColor3 = BUTTON_TEXT_COLOR
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamSemibold
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.ZIndex = z or 2
	btn.Parent = parent
	mkCorner(btn, 12)
	local stroke = mkStroke(btn, Theme.Purple, 0.36, 1)
	btn:SetAttribute("BaseText", text)
	btn:SetAttribute("IsActive", false)
	addHover(btn, Theme.PurpleDeep, Theme.PurpleDark, Theme.Active)
	if UI_READY then
		task.defer(function()
			if btn and btn.Parent then registerFunctionButton(btn) end
		end)
	end
	return btn, stroke
end

local function decorateDeviceSelectorButton(button: TextButton, deviceKind: string)
	local originalText = tostring(button.Text or "")
	button.TextTransparency = 1
	button.TextXAlignment = Enum.TextXAlignment.Left

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "DeviceIcon"
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.fromOffset(20, 20)
	iconHolder.Position = UDim2.new(0, 12, 0.5, -10)
	iconHolder.ZIndex = (button.ZIndex or 2) + 1
	iconHolder.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "DeviceTextLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 40, 0, 0)
	label.Size = UDim2.new(1, -48, 1, 0)
	label.Text = originalText
	label.TextColor3 = BUTTON_TEXT_COLOR
	label.TextSize = 12
	label.Font = Enum.Font.GothamSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = iconHolder.ZIndex
	label.Parent = button
	label:SetAttribute("HexaNoTranslate", true)

	local function refreshLabel()
		label.Text = tostring(button.Text or button:GetAttribute("BaseText") or originalText)
	end
	button:GetPropertyChangedSignal("Text"):Connect(refreshLabel)
	button:GetAttributeChangedSignal("BaseText"):Connect(refreshLabel)
	refreshLabel()

	if deviceKind == "PC" then
		local screen = Instance.new("Frame")
		screen.BackgroundTransparency = 1
		screen.Size = UDim2.new(1, 0, 0.62, 0)
		screen.Position = UDim2.new(0, 0, 0.04, 0)
		screen.BorderSizePixel = 0
		screen.ZIndex = iconHolder.ZIndex
		screen.Parent = iconHolder
		mkCorner(screen, 4)
		mkStroke(screen, BUTTON_TEXT_COLOR, 0, 2)

		local stem = Instance.new("Frame")
		stem.BackgroundColor3 = BUTTON_TEXT_COLOR
		stem.BorderSizePixel = 0
		stem.Size = UDim2.fromOffset(3, 5)
		stem.Position = UDim2.new(0.5, -1, 0.66, 0)
		stem.ZIndex = iconHolder.ZIndex
		stem.Parent = iconHolder
		mkCorner(stem, 1)

		local base = Instance.new("Frame")
		base.BackgroundColor3 = BUTTON_TEXT_COLOR
		base.BorderSizePixel = 0
		base.Size = UDim2.fromOffset(12, 2)
		base.Position = UDim2.new(0.5, -6, 0.9, -2)
		base.ZIndex = iconHolder.ZIndex
		base.Parent = iconHolder
		mkCorner(base, 1)
	else
		local phone = Instance.new("Frame")
		phone.BackgroundTransparency = 1
		phone.Size = UDim2.fromOffset(12, 18)
		phone.Position = UDim2.new(0.5, -6, 0.5, -9)
		phone.BorderSizePixel = 0
		phone.ZIndex = iconHolder.ZIndex
		phone.Parent = iconHolder
		mkCorner(phone, 4)
		mkStroke(phone, BUTTON_TEXT_COLOR, 0, 2)

		local speaker = Instance.new("Frame")
		speaker.BackgroundColor3 = BUTTON_TEXT_COLOR
		speaker.BorderSizePixel = 0
		speaker.Size = UDim2.fromOffset(4, 1)
		speaker.Position = UDim2.new(0.5, -2, 0, 3)
		speaker.ZIndex = iconHolder.ZIndex
		speaker.Parent = phone
		mkCorner(speaker, 1)

		local homeBar = Instance.new("Frame")
		homeBar.BackgroundColor3 = BUTTON_TEXT_COLOR
		homeBar.BorderSizePixel = 0
		homeBar.Size = UDim2.fromOffset(5, 1)
		homeBar.Position = UDim2.new(0.5, -2, 1, -4)
		homeBar.ZIndex = iconHolder.ZIndex
		homeBar.Parent = phone
		mkCorner(homeBar, 1)
	end
end

local function createToggleButton(parent: Instance, text: string, size: UDim2, pos: UDim2)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = Theme.PurpleDeep
	btn.BackgroundTransparency = 0.14
	btn.Text = text
	btn.TextColor3 = BUTTON_TEXT_COLOR
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamSemibold
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.ZIndex = 2
	btn.Parent = parent
	mkCorner(btn, 12)
	mkStroke(btn, Theme.Purple, 0.36, 1)
	
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.Parent = btn

	local toggleBg = Instance.new("Frame")
	toggleBg.Name = "ToggleBg"
	toggleBg.Size = UDim2.new(0, 38, 0, 20)
	toggleBg.Position = UDim2.new(1, -48, 0.5, -10)
	toggleBg.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
	toggleBg.BorderSizePixel = 0
	toggleBg.ZIndex = 3
	toggleBg.Parent = btn
	mkCorner(toggleBg, 10)
	mkStroke(toggleBg, Theme.Purple, 0.58, 1)

	local toggleKnob = Instance.new("Frame")
	toggleKnob.Name = "ToggleKnob"
	toggleKnob.Size = UDim2.new(0, 16, 0, 16)
	toggleKnob.Position = UDim2.new(0, 2, 0.5, -8)
	toggleKnob.BackgroundColor3 = Theme.ToggleOff
	toggleKnob.BorderSizePixel = 0
	toggleKnob.ZIndex = 4
	toggleKnob.Parent = toggleBg
	mkCorner(toggleKnob, 8)

	btn:SetAttribute("BaseText", text)
	btn:SetAttribute("IsActive", false)
	btn:SetAttribute("IsToggle", true)
	ConfigManager:RegisterToggle(btn, parent, text)
	if KeybindManager then task.defer(function()
		if btn and btn.Parent then KeybindManager:RegisterToggleButton(btn) end
	end) end
	if FloatingButtonManager then task.defer(function()
		if btn and btn.Parent then FloatingButtonManager:RegisterToggleButton(btn) end
	end) end
	
	addHover(btn, Theme.PurpleDeep, Theme.PurpleDark, Theme.Active)
	if UI_READY then
		task.defer(function()
			if btn and btn.Parent then registerFunctionButton(btn) end
		end)
	end
	return btn
end

local function markVipControl(control: GuiObject)
	if control:GetAttribute("HexaVipOnly") == true then return control end
	control:SetAttribute("HexaVipOnly", true)
	table.insert(VipControls, control)

	-- Las barras deslizantes siguen siendo VIP y se bloquean normalmente,
	-- pero no muestran insignia para no tapar el valor ni la barra.
	if control:IsA("TextButton") then
		local isToggle = control:GetAttribute("IsToggle") == true

		local badge = Instance.new("TextLabel")
		badge.Name = "HexaVipBadge"
		badge.AnchorPoint = Vector2.new(1, 0.5)
		-- El toggle NO se mueve. La insignia se coloca justo antes de él, con separación visual.
		badge.Position = isToggle and UDim2.new(1, -58, 0.5, 0) or UDim2.new(1, -8, 0.5, 0)
		badge.Size = UDim2.fromOffset(40, 18)
		badge.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
		badge.BackgroundTransparency = 0.04
		badge.BorderSizePixel = 0
		badge.Text = "★ VIP"
		badge.TextColor3 = Color3.fromRGB(215, 215, 215)
		badge.TextStrokeTransparency = 1
		badge.TextSize = 9
		badge.Font = Enum.Font.GothamBold
		badge.ZIndex = math.max(control.ZIndex + 4, 8)
		badge.Active = false
		badge.Parent = control
		mkCorner(badge, 7)
		local badgeStroke = mkStroke(badge, Color3.fromRGB(70, 70, 70), 0.35, 1)
		badgeStroke.Name = "HexaVipBadgeStroke"

		-- IMPORTANTE: en los toggles VIP NO usamos PaddingRight.
		-- UIPadding modifica el área interna del botón y desplazaba ToggleBg hacia la izquierda,
		-- haciendo que el interruptor VIP no coincidiera con el de una función normal.
		local padding = control:FindFirstChildOfClass("UIPadding")
		if not padding then
			padding = Instance.new("UIPadding")
			padding.Parent = control
		end
		if isToggle then
			padding.PaddingRight = UDim.new(0, 0)
			local toggleBg = control:FindFirstChild("ToggleBg")
			if toggleBg then
				toggleBg.Position = UDim2.new(1, -48, 0.5, -10)
				toggleBg.Size = UDim2.new(0, 38, 0, 20)
				toggleBg.Visible = true
			end
		else
			if padding.PaddingRight.Offset < 54 then
				padding.PaddingRight = UDim.new(0, 54)
			end
		end
		control.TextTruncate = Enum.TextTruncate.AtEnd
	end

	refreshVipControls()
	return control
end

local function requireVip()
	if HEXA_IS_VIP then return true end
	notifyVipLocked()
	return false
end

local function setActive(button: TextButton, active: boolean)
	button:SetAttribute("IsActive", active)
	
	local isToggle = button:GetAttribute("IsToggle")
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	
	if isToggle then
		local toggleBg = button:FindFirstChild("ToggleBg")
		if toggleBg then
			toggleBg.Visible = true
			local toggleKnob = toggleBg:FindFirstChild("ToggleKnob")
			if toggleKnob then
				toggleKnob.Visible = true
				local lockedVip = button:GetAttribute("HexaVipOnly") == true and not HEXA_IS_VIP
				local targetPosition = active and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
				local targetColor = lockedVip and Color3.fromRGB(112, 112, 112) or (active and Theme.ToggleOn or Theme.ToggleOff)
				if lockedVip then
					toggleBg.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
					toggleBg.BackgroundTransparency = 0.02
				end
				if PERFORMANCE_MODE then
					toggleKnob.Position = targetPosition
					toggleKnob.BackgroundColor3 = targetColor
				else
					tween(toggleKnob, ti, {Position = targetPosition, BackgroundColor3 = targetColor})
				end
			end
		end
		button.TextColor3 = BUTTON_TEXT_COLOR
	else
		local title = button:GetAttribute("BaseText")
		if typeof(title) == "string" then
			button.Text = active and (title .. (Lang.Current == "EN" and "  •  ON" or "  •  ACTIVO")) or title
		end
		if PERFORMANCE_MODE then button.BackgroundColor3 = active and Theme.Active or Theme.PurpleDeep
		else tween(button, ti, { BackgroundColor3 = active and Theme.Active or Theme.PurpleDeep }) end
		button.TextColor3 = BUTTON_TEXT_COLOR
	end
	if button:GetAttribute("HexaVipOnly") == true and not HEXA_IS_VIP then
		button.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
		button.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
end

local function sectionTitle(parent: Instance, text: string, pos: UDim2)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Theme.PurpleText
	lbl.TextSize = 12
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Size = UDim2.new(1, -24, 0, 18)
	lbl.Position = pos
	lbl.ZIndex = 3
	lbl.Parent = parent
	return lbl
end

local function createSlider(parent: Instance, title: string, minVal: number, maxVal: number, defaultVal: number, posY: number, onChanged: (number) -> (), vipOnly: boolean?, freeMaximum: number?)
	local originalMax = maxVal
	local currentValue = defaultVal

	local container = Instance.new("Frame")
	container.Name = "HexaSegmentedSlider"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, -24, 0, 52)
	container.Position = UDim2.new(0, 12, 0, posY)
	container.ZIndex = 3
	container.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = title
	label.TextColor3 = Theme.TextMain
	label.TextSize = 12
	label.Font = Enum.Font.GothamMedium
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -78, 0, 20)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.ZIndex = 4
	label.Parent = container

	local valuePill = Instance.new("TextBox")
	valuePill.Name = "HexaSliderValue"
	valuePill.AnchorPoint = Vector2.new(1, 0)
	valuePill.Position = UDim2.new(1, 0, 0, 0)
	valuePill.Size = UDim2.fromOffset(66, 22)
	valuePill.BackgroundColor3 = Theme.Panel2
	valuePill.BackgroundTransparency = 0.06
	valuePill.BorderSizePixel = 0
	valuePill.TextColor3 = Theme.TextOff
	valuePill.TextSize = 11
	valuePill.Font = Enum.Font.GothamBold
	valuePill.TextXAlignment = Enum.TextXAlignment.Center
	valuePill.ClearTextOnFocus = false
	valuePill.MultiLine = false
	valuePill.TextEditable = true
	valuePill.ZIndex = 10
	valuePill.Parent = container
	valuePill:SetAttribute("HexaNoTranslate", true)
	valuePill:SetAttribute("HexaSliderValueInput", true)
	mkCorner(valuePill, 7)
	mkStroke(valuePill, Theme.Accent, 0.72, 1)

	local shell = Instance.new("Frame")
	shell.Name = "HexaSliderShell"
	shell.BackgroundColor3 = Theme.Panel2
	shell.BackgroundTransparency = 0.88
	shell.BorderSizePixel = 0
	shell.Size = UDim2.new(1, 0, 0, 18)
	shell.Position = UDim2.new(0, 0, 0, 31)
	shell.ZIndex = 4
	shell.Active = true
	shell.ClipsDescendants = false
	shell.Parent = container
	mkCorner(shell, 6)
	mkStroke(shell, Theme.Accent, 0.72, 1)

	local segmentHolder = Instance.new("Frame")
	segmentHolder.Name = "HexaSliderSegments"
	segmentHolder.BackgroundTransparency = 1
	segmentHolder.Position = UDim2.new(0, 6, 0, 5)
	segmentHolder.Size = UDim2.new(1, -12, 0, 8)
	segmentHolder.ZIndex = 5
	segmentHolder.Parent = shell

	local segmentCount = MOBILE_DEVICE and 5 or 10
	local segments = {}
	for index = 1, segmentCount do
		local segment = Instance.new("Frame")
		segment.Name = "Segment" .. index
		segment.BackgroundColor3 = Theme.Accent
		segment.BackgroundTransparency = 0.8
		segment.BorderSizePixel = 0
		segment.Size = UDim2.new(1 / segmentCount, -2, 1, 0)
		segment.Position = UDim2.new((index - 1) / segmentCount, 1, 0, 0)
		segment.ZIndex = 5
		segment.Parent = segmentHolder
		mkCorner(segment, 3)
		segments[index] = segment
	end

	local marker = Instance.new("Frame")
	marker.Name = "HexaSliderMarker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.BackgroundColor3 = Theme.Panel2
	marker.BorderSizePixel = 0
	marker.Size = UDim2.fromOffset(7, 24)
	marker.Position = UDim2.new(0, 0, 0.5, 0)
	marker.ZIndex = 7
	marker.Parent = shell
	mkCorner(marker, 3)
	mkStroke(marker, Theme.Accent, 0.28, 1)

	local markerInset = Instance.new("Frame")
	markerInset.Name = "HexaSliderMarkerInset"
	markerInset.AnchorPoint = Vector2.new(0.5, 0.5)
	markerInset.Position = UDim2.new(0.5, 0, 0.5, 0)
	markerInset.Size = UDim2.fromOffset(2, 14)
	markerInset.BackgroundColor3 = Theme.TextOff
	markerInset.BackgroundTransparency = 0.2
	markerInset.BorderSizePixel = 0
	markerInset.ZIndex = 8
	markerInset.Parent = marker
	mkCorner(markerInset, 2)

	local hitbox = Instance.new("Frame")
	hitbox.Name = "HexaSliderHitbox"
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.new(1, 0, 1, 12)
	hitbox.Position = UDim2.new(0, 0, 0, -6)
	hitbox.Active = true
	hitbox.ZIndex = 9
	hitbox.Parent = shell

	local dragging = false

	local function effectiveMax()
		if HEXA_IS_VIP then return originalMax end
		local freeLimit = tonumber(freeMaximum) or 400
		return math.max(minVal, math.min(originalMax, freeLimit))
	end

	local controller = {}
	function controller.Refresh()
		local allowedMax = effectiveMax()
		currentValue = math.clamp(currentValue, minVal, allowedMax)
		-- La barra siempre representa el rango completo real. Los usuarios FREE
		-- pueden verlo entero, aunque el valor aplicado se limite a allowedMax.
		local position = math.clamp((currentValue - minVal) / math.max(1, originalMax - minVal), 0, 1)
		local activeSegments = math.floor(position * segmentCount + 0.5)
		for index, segment in ipairs(segments) do
			segment.BackgroundTransparency = index <= activeSegments and 0.04 or 0.8
		end
		marker.Position = UDim2.new(position, 0, 0.5, 0)
		valuePill.Text = tostring(math.floor(currentValue + 0.5))
		onChanged(currentValue)
	end
	function controller.Set(value: number)
		currentValue = value
		controller.Refresh()
	end
	function controller.Get()
		return currentValue
	end
	controller.Container = container
	controller.Maximum = originalMax
	controller.TitleLabel = label
	ConfigManager:RegisterSlider(controller, parent, title)
	table.insert(AllSliders, controller)

	local limitNoticeShown = false
	local function setFromInput(input: InputObject)
		if vipOnly and not requireVip() then return end
		local allowedMax = effectiveMax()
		local position = math.clamp((input.Position.X - shell.AbsolutePosition.X) / math.max(1, shell.AbsoluteSize.X), 0, 1)
		local requestedValue = math.floor(minVal + (originalMax - minVal) * position + 0.5)

		if not HEXA_IS_VIP and requestedValue > allowedMax then
			requestedValue = allowedMax
			if not limitNoticeShown then
				limitNoticeShown = true
				notifyVipLocked(
					("Solo los usuarios VIP pueden sobrepasar el máximo FREE de %d."):format(math.floor(allowedMax + 0.5)),
					("Only VIP users can exceed the FREE maximum of %d."):format(math.floor(allowedMax + 0.5))
				)
			end
		end

		currentValue = requestedValue
		controller.Refresh()
	end

	local editingValue = false

	local function applyTypedValue()
		local typedText = tostring(valuePill.Text or ""):gsub(",", ".")
		local requestedValue = tonumber(typedText)

		if requestedValue == nil then
			-- Entrada inválida: restaurar el valor actual sin cambiar la barra.
			controller.Refresh()
			return
		end

		requestedValue = math.floor(requestedValue + 0.5)
		local allowedMax = effectiveMax()

		if vipOnly and not HEXA_IS_VIP then
			requireVip()
			controller.Refresh()
			return
		end

		if not HEXA_IS_VIP and requestedValue > allowedMax then
			requestedValue = allowedMax
			notifyVipLocked(
				("Solo los usuarios VIP pueden sobrepasar el máximo FREE de %d."):format(math.floor(allowedMax + 0.5)),
				("Only VIP users can exceed the FREE maximum of %d."):format(math.floor(allowedMax + 0.5))
			)
		end

		currentValue = math.clamp(requestedValue, minVal, allowedMax)
		controller.Refresh()
	end

	valuePill.Focused:Connect(function()
		if vipOnly and not HEXA_IS_VIP then
			requireVip()
			valuePill:ReleaseFocus()
			return
		end
		editingValue = true
		isInteractingWithSlider = true
		-- El TextBox ya recibió el foco por el toque/clic. Seleccionar el valor
		-- facilita reemplazarlo directamente tanto en PC como en móvil.
		task.defer(function()
			if valuePill:IsFocused() then
				valuePill.CursorPosition = #valuePill.Text + 1
				valuePill.SelectionStart = 1
			end
		end)
	end)

	valuePill.FocusLost:Connect(function()
		if not editingValue then return end
		editingValue = false
		isInteractingWithSlider = false
		applyTypedValue()
	end)

	hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if vipOnly and not HEXA_IS_VIP then
				requireVip()
				return
			end
			limitNoticeShown = false
			isInteractingWithSlider = true
			dragging = true
			tween(marker, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(9, 28)})
			tween(valuePill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
			setFromInput(input)
		end
	end)

	AllSliders.TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromInput(input)
		end
	end))

	AllSliders.TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			limitNoticeShown = false
			isInteractingWithSlider = false
			tween(marker, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(7, 24)})
			tween(valuePill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.06})
		end
	end))

	if vipOnly then markVipControl(container) end
	controller.Refresh()
	return controller
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "H4SK"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 2147483647

ScreenGui.Destroying:Connect(function()
	for _, connection in ipairs(AllSliders.RootConnections) do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(AllSliders.RootConnections)
end)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Antes de elegir dispositivo mantenemos la GUI en PlayerGui, que es el
-- contenedor más neutral para mostrar key + selector. El perfil PC puede moverla
-- después a gethui/CoreGui si el executor lo admite.
local parentedScreenGui = pcall(function()
	ScreenGui.Parent = PlayerGui
end)
if not parentedScreenGui or not ScreenGui.Parent then
	if CoreGui then ScreenGui.Parent = CoreGui else ScreenGui.Parent = PlayerGui end
end
TargetParent = ScreenGui.Parent

local MobileMovementControls = nil
local mobileFlyVertical = 0
local mobileFlyVerticalInput = nil
local MobileFlyControls = nil

do
	pcall(function()
		local playerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		MobileMovementControls = playerModule:GetControls()
	end)

	MobileFlyControls = Instance.new("Frame")
	MobileFlyControls.Name = "HexaMobileFlyControls"
	MobileFlyControls.AnchorPoint = Vector2.new(1, 0.5)
	MobileFlyControls.Position = UDim2.new(1, -14, 0.5, 70)
	MobileFlyControls.Size = UDim2.fromOffset(92, 96)
	MobileFlyControls.BackgroundTransparency = 1
	MobileFlyControls.Visible = false
	MobileFlyControls.ZIndex = 120
	MobileFlyControls.Parent = ScreenGui

	local mobileFlyUpButton = neonButton(MobileFlyControls, "SUBIR", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 0), 121)
	local mobileFlyDownButton = neonButton(MobileFlyControls, "BAJAR", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 1, -42), 121)

	local function bindMobileFlyButton(button, direction)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				mobileFlyVerticalInput = input
				mobileFlyVertical = direction
			end
		end)
		button.InputEnded:Connect(function(input)
			if mobileFlyVerticalInput == input then
				mobileFlyVerticalInput = nil
				mobileFlyVertical = 0
			end
		end)
	end

	bindMobileFlyButton(mobileFlyUpButton, 1)
	bindMobileFlyButton(mobileFlyDownButton, -1)
	AllSliders.TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if mobileFlyVerticalInput == input then
			mobileFlyVerticalInput = nil
			mobileFlyVertical = 0
		end
	end))
end

local function setMobileFlyControlsVisible(visible)
	mobileFlyVertical = 0
	mobileFlyVerticalInput = nil
	if MobileFlyControls then MobileFlyControls.Visible = visible == true end
end

task.spawn(function()
	local lastRemoteRefresh = os.clock()
	while ScreenGui and ScreenGui.Parent do
		task.wait(10)
		if os.clock() - lastRemoteRefresh >= 30 then
			lastRemoteRefresh = os.clock()
			if RemoteVipState:Refresh() then
				syncVipAccessFromGithub()
			end
		elseif HEXA_IS_VIP and not RemoteVipState:IsActive() then
			-- También retirar acceso al cumplirse una expiración remota,
			-- aunque el archivo de GitHub todavía no haya cambiado.
			syncVipAccessFromGithub()
		end
	end
end)

local VipNotification = Instance.new("Frame")
VipNotification.Name = "HexaVipNotification"
VipNotification.AnchorPoint = Vector2.new(0.5, 0)
VipNotification.Position = UDim2.new(0.5, 0, 0, -72)
VipNotification.Size = UDim2.fromOffset(math.min(360, math.max(230, GUI_VIEWPORT_SIZE.X - 16)), 58)
-- Centro negro compacto; se conserva únicamente el borde/acento exterior.
VipNotification.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
VipNotification.BackgroundTransparency = 0.02
VipNotification.BorderSizePixel = 0
VipNotification.ZIndex = 200
VipNotification.Parent = ScreenGui
mkCorner(VipNotification, 11)
mkStroke(VipNotification, Theme.Purple, 0.03, 2)

local VipNotificationTitle = Instance.new("TextLabel")
VipNotificationTitle.BackgroundTransparency = 1
VipNotificationTitle.Position = UDim2.new(0, 12, 0, 6)
VipNotificationTitle.Size = UDim2.new(1, -24, 0, 17)
VipNotificationTitle.Text = "★ FUNCIÓN VIP"
VipNotificationTitle.TextColor3 = Theme.TextMain
VipNotificationTitle.TextSize = 13
VipNotificationTitle.Font = Enum.Font.GothamBold
VipNotificationTitle.TextXAlignment = Enum.TextXAlignment.Left
VipNotificationTitle.ZIndex = 201
VipNotificationTitle.Parent = VipNotification
VipNotificationTitle:SetAttribute("HexaNoTranslate", true)

local VipNotificationText = Instance.new("TextLabel")
VipNotificationText.BackgroundTransparency = 1
VipNotificationText.Position = UDim2.new(0, 12, 0, 23)
VipNotificationText.Size = UDim2.new(1, -24, 0, 29)
VipNotificationText.Text = "Únete al Discord para saber cómo obtener VIP."
VipNotificationText.TextColor3 = Color3.fromRGB(235, 235, 230)
VipNotificationText.TextSize = 12
VipNotificationText.Font = Enum.Font.GothamMedium
VipNotificationText.TextWrapped = true
VipNotificationText.TextXAlignment = Enum.TextXAlignment.Left
VipNotificationText.TextYAlignment = Enum.TextYAlignment.Center
VipNotificationText.ZIndex = 201
VipNotificationText.Parent = VipNotification
VipNotificationText:SetAttribute("HexaNoTranslate", true)

local vipNotificationGeneration = 0
notifyVipLocked = function(customTextEs, customTextEn)
	vipNotificationGeneration += 1
	local generation = vipNotificationGeneration
	VipNotificationTitle.Text = Lang.Current == "EN" and "★ VIP FEATURE" or "★ FUNCIÓN VIP"
	VipNotificationTitle.TextColor3 = Theme.PurpleText
	VipNotificationText.Text = Lang.Current == "EN"
		and (customTextEn or "Join the Discord to learn how to obtain VIP.")
		or (customTextEs or "Únete al Discord para saber cómo obtener VIP.")
	tween(VipNotification, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18)
	})
	task.delay(3.2, function()
		if generation ~= vipNotificationGeneration or not VipNotification.Parent then return end
		tween(VipNotification, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -100)
		})
	end)
end

-- Notificación compacta reutilizable para avisos del sistema (por ejemplo,
-- conflictos de keybind). Comparte el contenedor para no apilar paneles.
local function showSystemNotification(titleEs, textEs, titleEn, textEn)
	vipNotificationGeneration += 1
	local generation = vipNotificationGeneration
	VipNotificationTitle.Text = Lang.Current == "EN" and (titleEn or titleEs) or titleEs
	VipNotificationTitle.TextColor3 = Theme.PurpleText
	VipNotificationText.Text = Lang.Current == "EN" and (textEn or textEs) or textEs
	tween(VipNotification, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18)
	})
	task.delay(3.2, function()
		if generation ~= vipNotificationGeneration or not VipNotification.Parent then return end
		tween(VipNotification, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -100)
		})
	end)
end

Lang.Pairs = {
	{[[PUNTERÍA AUTOMÁTICA
Activa la puntería a la cabeza o al cuerpo. Los atajos ya no aparecen dentro de las funciones: configúralos desde la categoría KEYBINDS.

KEYBINDS
Asigna teclas o botones del ratón a las funciones compatibles desde una sola categoría. Pulsa Retroceso o Escape al editar un atajo para dejarlo sin tecla.

CÍRCULO FOV
Limita el área en la que se seleccionan objetivos. Activa USAR CÍRCULO FOV y ajusta su radio.

MOVIMIENTO Y FÍSICA
Controla el vuelo, la velocidad, el salto, la gravedad, la caminata aérea y la colisión. En celular, el vuelo incluye botones para subir y bajar.

VISUALES ESP
Muestra esqueletos o líneas hacia otros jugadores y permite limitar la distancia.

TELETRANSPORTE
Selecciona un jugador y pulsa IR AL JUGADOR. En computadora puedes usar TP AL RATÓN; en celular se adapta como TP AL TOQUE.

FUNCIONES VIP
Las opciones que muestran la etiqueta VIP requieren una clave VIP activa.]], [[AUTO AIM
Enable aiming at the head or body. Keybind controls are no longer embedded inside each feature; configure them from the KEYBINDS category.

KEYBINDS
Assign keyboard keys or mouse buttons to compatible features from one category. Press Backspace or Escape while editing a bind to leave it unbound.

FOV CIRCLE
Limits the area where targets are selected. Enable USE FOV CIRCLE and adjust its radius.

MOVEMENT AND PHYSICS
Controls flight, speed, jumping, gravity, air walk and collision. On mobile, flight includes buttons to move up and down.

ESP VISUALS
Displays skeletons or lines toward other players and lets you limit the distance.

TELEPORT
Select a player and press GO TO PLAYER. On computer you can use TELEPORT TO MOUSE; on mobile it adapts to TELEPORT TO TOUCH.

VIP FEATURES
Options displaying the VIP label require an active VIP key.]]},
	{"CATEGORÍAS", "CATEGORIES"},
	{"TODAS", "ALL"},
	{"INICIO", "HOME"},
	{"MOVIMIENTO", "MOVEMENT"},
	{"COMBATE", "COMBAT"},
	{"VISUALES", "VISUALS"},
	{"TELETRANSPORTE", "TELEPORT"},
	{"JUGADOR", "PLAYER"},
	{"SISTEMA", "SYSTEM"},
	{"PERSONALIZAR", "CUSTOMIZE"},
	{"KEYBINDS", "KEYBINDS"},
	{"CONFIGURACIÓN DE USUARIO", "USER CONFIGURATION"},
	{"GUARDAR CONFIGURACIÓN", "SAVE CONFIGURATION"},
	{"CARGAR CONFIGURACIÓN", "LOAD CONFIGURATION"},
	{"FAVORITOS", "FAVORITES"},
	{"NO TIENES FUNCIONES FAVORITAS", "YOU HAVE NO FAVORITE FEATURES"},
	{"TELETRANSPORTARSE AL TOQUE", "TELEPORT TO TOUCH"},
	{"AUTO TOQUES", "AUTO TAP"},
	{"Toques por segundo", "Taps per second"},
	{"Elige si la clave será temporal o permanente. Cada código funcionará únicamente para el usuario indicado.", "Choose whether the key will be temporary or permanent. Each code will work only for the specified user."},
	{"EQUIPAR HERRAMIENTA AUTOMÁTICAMENTE", "AUTO EQUIP TOOL"},
	{"TELETRANSPORTARSE AL RATÓN", "TELEPORT TO MOUSE"},
	{"Clics por segundo", "Clicks per second"},
	{"VOLVER A LA POSICIÓN GUARDADA", "RETURN TO SAVED POSITION"},
	{"AIMBOT (CABEZA)", "AIMBOT (HEAD)"},
	{"AIMBOT (CUERPO)", "AIMBOT (BODY)"},
	{"DISTANCIA MÁXIMA DE PUNTERÍA (3D)", "MAX AIM DISTANCE (3D)"},
	{"Distancia máxima de puntería (3D)", "Max aim distance (3D)"},
	{"ANIMACIÓN DE APERTURA: RETROCESO", "OPENING ANIMATION: BACK"},
	{"ANIMACIÓN DE APERTURA:", "OPENING ANIMATION:"},
	{"TODAS LAS FUNCIONES DESACTIVADAS", "ALL FEATURES DISABLED"},
	{"SELECCIONAR JUGADOR: [NINGUNO]", "SELECT PLAYER: [NONE]"},
	{"Seleccionar jugador: [ninguno]", "Select player: [none]"},
	{"TELETRANSPORTE A JUGADOR", "PLAYER TELEPORT"},
	{"UTILIDADES DE TELETRANSPORTE", "TELEPORT UTILITIES"},
	{"REAPARICIÓN AUTOMÁTICA", "AUTO RESPAWN"},
	{"RECONECTAR AL SERVIDOR", "RECONNECT TO SERVER"},
	{"ACTIVAR MIRA PERSONALIZADA", "ENABLE CUSTOM CROSSHAIR"},
	{"TIPO DE MIRA: CRUZ", "CROSSHAIR TYPE: CROSS"},
	{"TIPO DE MIRA: PUNTO", "CROSSHAIR TYPE: DOT"},
	{"TIPO DE MIRA:", "CROSSHAIR TYPE:"},
	{"COLOR DE LA MIRA: BLANCO", "CROSSHAIR COLOR: WHITE"},
	{"COLOR DE LA MIRA:", "CROSSHAIR COLOR:"},
	{"Tamaño de la mira", "Crosshair size"},
	{"Grosor de la mira", "Crosshair thickness"},
	{"Espacio de la mira", "Crosshair gap"},
	{"MIRA PERSONALIZADA", "CUSTOM CROSSHAIR"},
	{"MIRA ARCOÍRIS", "RAINBOW CROSSHAIR"},
	{"BLOQUEAR PRIMERA PERSONA", "LOCK FIRST PERSON"},
	{"FORZAR TERCERA PERSONA", "FORCE THIRD PERSON"},
	{"JUGADOR Y CÁMARA", "PLAYER AND CAMERA"},
	{"ELIMINAR DESENFOQUE", "REMOVE BLUR"},
	{"ELIMINAR SOMBRAS", "REMOVE SHADOWS"},
	{"ELIMINAR NIEBLA", "REMOVE FOG"},
	{"RESTABLECER GRAVEDAD", "RESET GRAVITY"},
	{"CAMINATA AÉREA", "AIR WALK"},
	{"SALTO DE CONEJO", "BUNNY HOP"},
	{"SIN DAÑO POR CAÍDA", "NO FALL DAMAGE"},
	{"MOVIMIENTO Y FÍSICA", "MOVEMENT AND PHYSICS"},
	{"MOVIMIENTO EXTRA", "EXTRA MOVEMENT"},
	{"Velocidad al caminar", "Walk speed"},
	{"Velocidad de vuelo", "Fly speed"},
	{"Potencia de salto", "Jump power"},
	{"AUMENTO DE VELOCIDAD", "SPEED BOOST"},
	{"SALTO INFINITO", "INFINITE JUMP"},
	{"SALTO ALTO", "HIGH JUMP"},
	{"SIN COLISIÓN", "NOCLIP"},
	{"COMBATE Y PUNTERÍA", "COMBAT AND AIM"},
	{"COMBATE AVANZADO", "ADVANCED COMBAT"},
	{"COMPROBAR PAREDES", "WALL CHECK"},
	{"COMPROBAR EQUIPOS", "TEAM CHECK"},
	{"SIN RETROCESO", "NO RECOIL"},
	{"DISPARO RÁPIDO", "RAPID FIRE"},
	{"Disparos por segundo", "Shots per second"},
	{"CONVERSIÓN DE ARMA A AUTOMÁTICA", "FULL-AUTO WEAPON CONVERSION"},
	{"EXTENSOR DE ALCANCE DE BALA", "BULLET RANGE EXTENDER"},
	{"Multiplicador de alcance", "Range multiplier"},
	{"MODIFICADOR DE CAÍDA DE DAÑO", "DAMAGE FALLOFF MODIFIER"},
	{"MODIFICADOR DE VELOCIDAD DE BALA", "BULLET VELOCITY MODIFIER"},
	{"Multiplicador de velocidad de bala", "Bullet velocity multiplier"},
	{"EXTENSOR DE DURACIÓN DEL PROYECTIL", "PROJECTILE LIFETIME EXTENDER"},
	{"Duración del proyectil (s)", "Projectile lifetime (s)"},
	{"BALA PENETRANTE DE SUPERFICIES", "SURFACE-PENETRATING BULLET"},
	{"MODIFICADORES DE ARMAS Y PROYECTILES", "WEAPON AND PROJECTILE MODIFIERS"},
	{"SUAVIZADO DE PUNTERÍA", "AIM SMOOTHING"},
	{"CONTROL DE MIRA", "AIM CONTROL"},
	{"BLOQUEO DE ARMA", "WEAPON LOCK"},
	{"PREDICCIÓN DEL OBJETIVO", "TARGET PREDICTION"},
	{"RETARDO AL CAMBIAR OBJETIVO", "TARGET SWITCHING DELAY"},
	{"Retardo de cambio de objetivo (ms)", "Target switching delay (ms)"},
	{"SIN DISPERSIÓN", "NO SPREAD"},
	{"RECARGA AUTOMÁTICA", "AUTO RELOAD"},
	{"MUNICIÓN INFINITA", "INFINITE AMMO"},
	{"HITBOX", "HITBOX"},
	{"EXPANSOR DE HITBOX", "HITBOX EXPANDER"},
	{"HITBOX DE CABEZA", "HEAD HITBOX"},
	{"Tamaño del Hitbox", "Hitbox size"},
	{"COLOR DEL HITBOX: MORADO", "HITBOX COLOR: PURPLE"},
	{"COLOR DEL HITBOX:", "HITBOX COLOR:"},
	{"FULLBRIGHT", "FULLBRIGHT"},
	{"X-RAY", "X-RAY"},
	{"Transparencia X-Ray", "X-Ray transparency"},
	{"FUNCIONES ESENCIALES", "ESSENTIAL FEATURES"},
	{"INSTANT HIT", "INSTANT HIT"},
	{"MODO JESÚS (CAMINAR SOBRE AGUA)", "JESUS MODE (WALK ON WATER)"},
	{"CÁMARA LIBRE", "FREE CAMERA"},
	{"Velocidad de la cámara libre", "Free camera speed"},
	{"SPIN", "SPIN"},
	{"Velocidad del Spin", "Spin speed"},
	{"ANTI ATURDIMIENTO", "ANTI STUN"},
	{"ANTI RAGDOLL", "ANTI RAGDOLL"},
	{"ESP AVANZADO", "ADVANCED ESP"},
	{"CAJA ESP", "BOX ESP"},
	{"NOMBRE ESP", "NAME ESP"},
	{"BARRA DE VIDA ESP", "HEALTH BAR ESP"},
	{"ESP HIGHLIGHT", "ESP HIGHLIGHT"},
	{"IGNORAR AMIGOS", "IGNORE FRIENDS"},
	{"USAR CÍRCULO FOV", "USE FOV CIRCLE"},
	{"Radio del FOV", "FOV radius"},
	{"VISUALES (ESP)", "VISUALS (ESP)"},
	{"ESQUELETO ESP", "ESP SKELETON"},
	{"LÍNEAS ESP (TRAZADORES)", "ESP LINES (TRACERS)"},
	{"Distancia máxima del ESP", "Max ESP distance"},
	{"GUARDAR POSICIÓN", "SAVE POSITION"},
	{"POSICIÓN GUARDADA", "POSITION SAVED"},
	{"HISTORIAL: VOLVER", "HISTORY: RETURN"},
	{"IR AL JUGADOR", "GO TO PLAYER"},
	{"Jugador:", "Player:"},
	{"COMUNIDAD", "COMMUNITY"},
	{"UNIRSE AL DISCORD (COPIAR ENLACE)", "JOIN DISCORD (COPY LINK)"},
	{"¡ENLACE COPIADO AL PORTAPAPELES!", "LINK COPIED TO CLIPBOARD!"},
	{"INFORMACIÓN", "INFORMATION"},
	{"CONTADOR DE FPS", "FPS COUNTER"},
	{"CONTADOR DE PING", "PING COUNTER"},
	{"COORDENADAS", "COORDINATES"},
	{"MEDIDOR DE VELOCIDAD", "SPEEDOMETER"},
	{"HORA:", "TIME:"},
	{"VELOCIDAD:", "SPEED:"},
	{"NO DISP.", "UNAVAILABLE"},
	{"SEGURIDAD Y CONTROL", "SAFETY AND CONTROL"},
	{"AUTOMATIZACIÓN", "AUTOMATION"},
	{"SISTEMA Y UTILIDADES", "SYSTEM AND UTILITIES"},
	{"OPTIMIZACIÓN DE RENDIMIENTO", "PERFORMANCE OPTIMIZATION"},
	{"CÁMARA Y MOVIMIENTO", "CAMERA AND MOVEMENT"},
	{"PROTECCIÓN DEL PERSONAJE", "PLAYER PROTECTION"},
	{"MISCELÁNEO", "MISCELLANEOUS"},
	{"ANTI AUSENCIA (AFK)", "ANTI AFK"},
	{"MODO RENDIMIENTO: CARTÓN", "PERFORMANCE MODE: POTATO"},
	{"MODO RENDIMIENTO", "PERFORMANCE MODE"},
	{"MODO TRANSMISIÓN", "STREAMER MODE"},
	{"ACTIVAR MODO PÁNICO", "ACTIVATE PANIC MODE"},
	{"PERSONALIZACIÓN", "CUSTOMIZATION"},
	{"SUBIR", "UP"},
	{"BAJAR", "DOWN"},
	{"ARRIBA DERECHA", "TOP RIGHT"},
	{"ARRIBA IZQUIERDA", "TOP LEFT"},
	{"ABAJO DERECHA", "BOTTOM RIGHT"},
	{"ABAJO IZQUIERDA", "BOTTOM LEFT"},
	{"FUENTE:", "FONT:"},
	{"GOTHAM NEGRITA", "GOTHAM BOLD"},
	{"CÓDIGO", "CODE"},
	{"RETROCESO", "BACK"},
	{"SUAVE", "SMOOTH"},
	{"ELÁSTICA", "ELASTIC"},
	{"REBOTE", "BOUNCE"},
	{"DESLIZAR IZQUIERDA", "SLIDE LEFT"},
	{"DESLIZAR DERECHA", "SLIDE RIGHT"},
	{"DESLIZAR ARRIBA", "SLIDE UP"},
	{"DESLIZAR ABAJO", "SLIDE DOWN"},
	{"ZOOM", "ZOOM"},
	{"GIRO", "SPIN"},
	{"LATIDO", "PULSE"},
	{"GLITCH", "GLITCH"},
	{"CAÍDA", "DROP"},
	{"EXPLOSIÓN", "BURST"},
	{"H3X4 X - SISTEMA DE CLAVE", "H3X4 X - KEY SYSTEM"},
	{"Escribe la clave aquí...", "Enter the key here..."},
	{"Escribe la key", "Enter the key"},
	{"Verificar clave", "Check key"},
	{"Obtener clave (Discord)", "Get key (Discord)"},
	{"¡Clave incorrecta!", "Incorrect key!"},
	{"¡COPIADO!", "COPIED!"},
	{"Por Nony", "By Nony"},
	{"H3X4 X - TUTORIAL", "H3X4 X - TUTORIAL"},
	{"ENTENDIDO", "GOT IT"},
	{"¿CERRAR H3X4 X?", "CLOSE H3X4 X?"},
	{"CANCELAR", "CANCEL"},
	{"SÍ", "YES"},
	{"PRESIONA UNA TECLA...", "PRESS A KEY..."},
	{"BLANCO", "WHITE"},
	{"ROJO", "RED"},
	{"VERDE", "GREEN"},
	{"AZUL", "BLUE"},
	{"AMARILLO", "YELLOW"},
	{"MORADO", "PURPLE"},
	{"CRUZ", "CROSS"},
	{"PUNTO", "DOT"},
	{"RELOJ", "CLOCK"},
	{"VUELO", "FLY"},
	{"HERRAMIENTAS DEL JUGADOR", "PLAYER TOOLS"},
	{"SEGUIR AL JUGADOR", "FOLLOW PLAYER"},
	{"Distancia de seguimiento", "Follow distance"},
	{"ANTI VOID", "ANTI VOID"},
	{"ESPECTAR JUGADOR", "SPECTATE PLAYER"},
	{"BOTÓN AIM FLOTANTE", "FLOATING AIM BUTTON"},
	{"BOTONES FLOTANTES", "FLOATING BUTTONS"},
	{"BOTÓN FLOTANTE:", "FLOATING BUTTON:"},
	{"PRESIONA OTRA TECLA...", "PRESS ANOTHER KEY..."},
	{"PERSISTENCIA DE OBJETIVO", "TARGET PERSISTENCE"},
	{"ELIGE TU DISPOSITIVO", "CHOOSE YOUR DEVICE"},
	{"Selecciona el dispositivo que estás usando. El panel y los controles se adaptarán a esa elección.", "Select the device you are using. The panel and controls will adapt to that choice."},
	{"COMPUTADORA", "COMPUTER"},
	{"CELULAR", "MOBILE"},
	{"SUGERENCIA DETECTADA: CELULAR", "DETECTED SUGGESTION: MOBILE"},
	{"SUGERENCIA DETECTADA: PC", "DETECTED SUGGESTION: PC"},
	{"INSPECTOR DE JUGADOR", "PLAYER INSPECTOR"},
	{"SELECCIONA UN JUGADOR", "SELECT A PLAYER"},
}

Lang.Updating = setmetatable({}, {__mode = "k"})
Lang.Bound = setmetatable({}, {__mode = "k"})
Lang.English = {}
Lang.Spanish = {}
Lang.ReversePairs = {}

for _, pair in ipairs(Lang.Pairs) do
	Lang.English[pair[1]] = pair[2]
	Lang.Spanish[pair[2]] = pair[1]
	table.insert(Lang.ReversePairs, pair)
end

table.sort(Lang.Pairs, function(a, b) return #a[1] > #b[1] end)
table.sort(Lang.ReversePairs, function(a, b) return #a[2] > #b[2] end)

function Lang.ReplacePlain(text, fromText, toText)
	local startIndex = 1
	while true do
		local firstIndex, lastIndex = string.find(text, fromText, startIndex, true)
		if not firstIndex then break end
		text = string.sub(text, 1, firstIndex - 1) .. toText .. string.sub(text, lastIndex + 1)
		startIndex = firstIndex + #toText
	end
	return text
end

local function isAsciiWordCharacter(character)
	return character ~= "" and string.match(character, "^[%w_]$") ~= nil
end

function Lang.ReplacePlainBounded(text, fromText, toText)
	local startIndex = 1
	local sourceStartsAsWord = isAsciiWordCharacter(string.sub(fromText, 1, 1))
	local sourceEndsAsWord = isAsciiWordCharacter(string.sub(fromText, -1))
	while true do
		local firstIndex, lastIndex = string.find(text, fromText, startIndex, true)
		if not firstIndex then break end
		local before = firstIndex > 1 and string.sub(text, firstIndex - 1, firstIndex - 1) or ""
		local after = lastIndex < #text and string.sub(text, lastIndex + 1, lastIndex + 1) or ""
		local insideAnotherWord = (sourceStartsAsWord and isAsciiWordCharacter(before))
			or (sourceEndsAsWord and isAsciiWordCharacter(after))
		if insideAnotherWord then
			startIndex = lastIndex + 1
		else
			text = string.sub(text, 1, firstIndex - 1) .. toText .. string.sub(text, lastIndex + 1)
			startIndex = firstIndex + #toText
		end
	end
	return text
end

function Lang.ReplacePairsOnce(text, pairs, sourceIndex, targetIndex)
	local translated = text
	local replacements = {}
	for index, pair in ipairs(pairs) do
		local token = string.char(1) .. "HEXA_TRANSLATION_" .. tostring(index) .. string.char(2)
		translated = Lang.ReplacePlainBounded(translated, pair[sourceIndex], token)
		table.insert(replacements, {token, pair[targetIndex]})
	end
	for _, replacement in ipairs(replacements) do
		translated = Lang.ReplacePlain(translated, replacement[1], replacement[2])
	end
	return translated
end

function Lang.ToEnglish(text)
	if typeof(text) ~= "string" or text == "" then return text end
	if Lang.English[text] then return Lang.English[text] end
	-- Si ya es un texto inglés exacto, no volver a traducirlo.
	if Lang.Spanish[text] then return text end
	local translated = Lang.ReplacePairsOnce(text, Lang.Pairs, 1, 2)
	translated = Lang.ReplacePlain(translated, "  •  ACTIVO", "  •  ON")
	return translated
end

function Lang.ToSpanish(text)
	if typeof(text) ~= "string" or text == "" then return text end
	-- Evita convertir COMBATE en COMBATEE, CANCELAR en CANCELARAR y
	-- RED dentro de PAREDES/PREDICCIÓN. El texto ya está en español.
	if Lang.English[text] then return text end
	if Lang.Spanish[text] then return Lang.Spanish[text] end
	local translated = Lang.ReplacePairsOnce(text, Lang.ReversePairs, 2, 1)
	translated = Lang.ReplacePlain(translated, "  •  ON", "  •  ACTIVO")
	return translated
end

function Lang.WriteProperty(object, propertyName, value)
	Lang.Updating[object] = true
	pcall(function() object[propertyName] = value end)
	Lang.Updating[object] = nil
end

function Lang.WriteAttribute(object, attributeName, value)
	Lang.Updating[object] = true
	pcall(function() object:SetAttribute(attributeName, value) end)
	Lang.Updating[object] = nil
end

function Lang.ApplyObject(object)
	if object:GetAttribute("HexaNoTranslate") == true then return end
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return end

	local spanishText = object:GetAttribute("HexaSpanishText")
	if typeof(spanishText) ~= "string" then
		spanishText = Lang.Current == "EN" and Lang.ToSpanish(object.Text) or object.Text
		object:SetAttribute("HexaSpanishText", spanishText)
	end
	Lang.WriteProperty(object, "Text", Lang.Current == "EN" and Lang.ToEnglish(spanishText) or spanishText)

	if object:IsA("TextBox") then
		local spanishPlaceholder = object:GetAttribute("HexaSpanishPlaceholder")
		if typeof(spanishPlaceholder) ~= "string" then
			spanishPlaceholder = Lang.Current == "EN" and Lang.ToSpanish(object.PlaceholderText) or object.PlaceholderText
			object:SetAttribute("HexaSpanishPlaceholder", spanishPlaceholder)
		end
		Lang.WriteProperty(object, "PlaceholderText", Lang.Current == "EN" and Lang.ToEnglish(spanishPlaceholder) or spanishPlaceholder)
	end

	local baseText = object:GetAttribute("BaseText")
	if typeof(baseText) == "string" then
		local spanishBase = object:GetAttribute("HexaSpanishBaseText")
		if typeof(spanishBase) ~= "string" then
			spanishBase = Lang.Current == "EN" and Lang.ToSpanish(baseText) or baseText
			object:SetAttribute("HexaSpanishBaseText", spanishBase)
		end
		Lang.WriteAttribute(object, "BaseText", Lang.Current == "EN" and Lang.ToEnglish(spanishBase) or spanishBase)
	end
end

function Lang.Bind(object)
	if Lang.Bound[object] then return end
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return end
	Lang.Bound[object] = true
	if object:GetAttribute("HexaNoTranslate") == true then return end

	object:SetAttribute("HexaSpanishText", Lang.Current == "EN" and Lang.ToSpanish(object.Text) or object.Text)
	if object:IsA("TextBox") then
		object:SetAttribute("HexaSpanishPlaceholder", Lang.Current == "EN" and Lang.ToSpanish(object.PlaceholderText) or object.PlaceholderText)
	end
	local baseText = object:GetAttribute("BaseText")
	if typeof(baseText) == "string" then
		object:SetAttribute("HexaSpanishBaseText", Lang.Current == "EN" and Lang.ToSpanish(baseText) or baseText)
	end

	object:GetPropertyChangedSignal("Text"):Connect(function()
		if Lang.Updating[object] then return end
		local spanishText = Lang.Current == "EN" and Lang.ToSpanish(object.Text) or object.Text
		object:SetAttribute("HexaSpanishText", spanishText)
		if Lang.Current == "EN" then Lang.WriteProperty(object, "Text", Lang.ToEnglish(spanishText)) end
	end)

	if object:IsA("TextBox") then
		object:GetPropertyChangedSignal("PlaceholderText"):Connect(function()
			if Lang.Updating[object] then return end
			local spanishPlaceholder = Lang.Current == "EN" and Lang.ToSpanish(object.PlaceholderText) or object.PlaceholderText
			object:SetAttribute("HexaSpanishPlaceholder", spanishPlaceholder)
			if Lang.Current == "EN" then Lang.WriteProperty(object, "PlaceholderText", Lang.ToEnglish(spanishPlaceholder)) end
		end)
	end

	object:GetAttributeChangedSignal("BaseText"):Connect(function()
		if Lang.Updating[object] then return end
		local value = object:GetAttribute("BaseText")
		if typeof(value) ~= "string" then return end
		local spanishBase = Lang.Current == "EN" and Lang.ToSpanish(value) or value
		object:SetAttribute("HexaSpanishBaseText", spanishBase)
		if Lang.Current == "EN" then Lang.WriteAttribute(object, "BaseText", Lang.ToEnglish(spanishBase)) end
	end)

	Lang.ApplyObject(object)
end

-- Textos que dependen del dispositivo elegido. La GUI principal se construye
-- antes de que el usuario pulse PC/CELULAR, por eso estos textos no deben
-- decidirse durante la creación del botón: se actualizan al aplicar el perfil.
local function registerDeviceText(object, desktopEs, mobileEs, desktopEn, mobileEn)
	if not object then return object end
	object:SetAttribute("HexaDeviceDesktopES", desktopEs)
	object:SetAttribute("HexaDeviceMobileES", mobileEs)
	object:SetAttribute("HexaDeviceDesktopEN", desktopEn or Lang.ToEnglish(desktopEs))
	object:SetAttribute("HexaDeviceMobileEN", mobileEn or Lang.ToEnglish(mobileEs))
	-- La traducción normal no debe sobrescribir el texto específico del perfil.
	object:SetAttribute("HexaNoTranslate", true)
	return object
end

local function refreshDeviceSpecificTexts()
	local prefix = MOBILE_DEVICE and "HexaDeviceMobile" or "HexaDeviceDesktop"
	local suffix = Lang.Current == "EN" and "EN" or "ES"
	for _, object in ipairs(ScreenGui:GetDescendants()) do
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			local value = object:GetAttribute(prefix .. suffix)
			if typeof(value) == "string" then
				Lang.WriteProperty(object, "Text", value)
				if typeof(object:GetAttribute("BaseText")) == "string" then
					Lang.WriteAttribute(object, "BaseText", value)
				end
			end
		end
	end
	if FloatingButtonManager then FloatingButtonManager:RefreshAll() end
end

function Lang.Set(language)
	Lang.Current = language == "EN" and "EN" or "ES"
	for _, object in ipairs(ScreenGui:GetDescendants()) do
		Lang.Bind(object)
		Lang.ApplyObject(object)
	end
	if Lang.Button and Lang.Button.Parent then
		Lang.Updating[Lang.Button] = true
		Lang.Button.Text = Lang.Current == "EN" and "LANGUAGE: ENGLISH" or "IDIOMA: ESPAÑOL"
		Lang.Button:SetAttribute("BaseText", Lang.Button.Text)
		Lang.Updating[Lang.Button] = nil
	end
	if Lang.MainButton and Lang.MainButton.Parent then
		Lang.Updating[Lang.MainButton] = true
		Lang.MainButton.Text = Lang.Current
		Lang.MainButton:SetAttribute("BaseText", Lang.MainButton.Text)
		Lang.Updating[Lang.MainButton] = nil
	end
	if FunctionSearchBox and FunctionSearchBox.Parent then
		FunctionSearchBox.PlaceholderText = Lang.Current == "EN" and "SEARCH FUNCTIONS..." or "BUSCAR FUNCIONES..."
	end
	refreshDeviceSpecificTexts()
	task.defer(function()
		refreshFavoritesCard()
		refreshCategoryView()
	end)
end

ScreenGui.DescendantAdded:Connect(function(object)
	task.defer(function()
		if object and object.Parent then Lang.Bind(object) end
	end)
end)

local KeyFrame = Instance.new("Frame")
KeyFrame.Name = "KeyFrame"
KeyFrame.AnchorPoint = Vector2.new(0.5, 0.5)
KeyFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
KeyFrame.Size = UDim2.new(0, 0, 0, 0)
KeyFrame.BackgroundColor3 = Theme.BG
KeyFrame.BorderSizePixel = 0
KeyFrame.ClipsDescendants = true
KeyFrame.Visible = true
KeyFrame.Parent = ScreenGui
mkCorner(KeyFrame, 16)
mkStroke(KeyFrame, Theme.Purple, 0.10, 2)
makeDraggable(KeyFrame, KeyFrame)

local KeyHeaderLogo = Instance.new("ImageLabel")
KeyHeaderLogo.Name = "KeyHeaderLogo"
KeyHeaderLogo.BackgroundTransparency = 1
KeyHeaderLogo.Size = UDim2.fromOffset(28, 28)
KeyHeaderLogo.Position = UDim2.new(0, 18, 0, 15)
KeyHeaderLogo.Image = "rbxassetid://72742584610344"
KeyHeaderLogo.ScaleType = Enum.ScaleType.Fit
KeyHeaderLogo.Parent = KeyFrame

local KeyTitle = Instance.new("TextLabel")
KeyTitle.BackgroundTransparency = 1
KeyTitle.Size = UDim2.new(1, -58, 0, 40)
KeyTitle.Position = UDim2.new(0, 56, 0, 10)
KeyTitle.Text = "H3X4 X - SISTEMA DE CLAVE"
KeyTitle.TextColor3 = Theme.TextMain
KeyTitle.TextSize = 16
KeyTitle.Font = Enum.Font.GothamBold
KeyTitle.TextXAlignment = Enum.TextXAlignment.Left
KeyTitle.Parent = KeyFrame

local KeyBoxContainer = Instance.new("Frame")
KeyBoxContainer.BackgroundColor3 = Theme.Panel2
KeyBoxContainer.Size = UDim2.new(1, -40, 0, 40)
KeyBoxContainer.Position = UDim2.new(0, 20, 0, 60)
KeyBoxContainer.Parent = KeyFrame
mkCorner(KeyBoxContainer, 8)
mkStroke(KeyBoxContainer, Theme.Purple, 0.38, 1)

local KeyBox = Instance.new("TextBox")
KeyBox.BackgroundTransparency = 1
KeyBox.Size = UDim2.new(1, -20, 1, 0)
KeyBox.Position = UDim2.new(0, 10, 0, 0)
KeyBox.Text = ""
KeyBox.PlaceholderText = Lang.Current == "EN" and "Enter the key" or "Escribe la key"
KeyBox.TextColor3 = Theme.TextOff
KeyBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
KeyBox.TextSize = 14
KeyBox.Font = Enum.Font.GothamMedium
KeyBox.Parent = KeyBoxContainer

local CheckKeyBtn = neonButton(KeyFrame, "Verificar clave", UDim2.new(0.5, -25, 0, 40), UDim2.new(0, 20, 0, 115))
local GetKeyBtn = neonButton(KeyFrame, "Obtener clave (Discord)", UDim2.new(0.5, -25, 0, 40), UDim2.new(0.5, 5, 0, 115))

Lang.Button = neonButton(KeyFrame, "IDIOMA: ESPAÑOL", UDim2.new(1, -40, 0, 38), UDim2.new(0, 20, 0, 165))
Lang.Button:SetAttribute("HexaNoTranslate", true)
Lang.Button.MouseButton1Click:Connect(function()
	Lang.Set(Lang.Current == "ES" and "EN" or "ES")
end)

local ByNonyLabel = Instance.new("TextLabel")
ByNonyLabel.BackgroundTransparency = 1
ByNonyLabel.Size = UDim2.new(0, 100, 0, 20)
ByNonyLabel.Position = UDim2.new(1, -110, 1, -22)
ByNonyLabel.Text = "Por Nony"
ByNonyLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
ByNonyLabel.TextSize = 11
ByNonyLabel.Font = Enum.Font.GothamMedium
ByNonyLabel.TextXAlignment = Enum.TextXAlignment.Right
ByNonyLabel.ZIndex = 2
ByNonyLabel.Parent = KeyFrame

-- Selector manual de dispositivo. La detección automática NO decide el modo:
-- únicamente muestra una sugerencia. PC/CELULAR se aplica después de la key.
local DeviceSelector = {}
DeviceSelector.Frame = Instance.new("Frame")
DeviceSelector.Frame.Name = "DeviceFrame"
DeviceSelector.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
DeviceSelector.Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
DeviceSelector.Frame.Size = UDim2.new(0, 0, 0, 0)
DeviceSelector.Frame.BackgroundColor3 = Theme.BG
DeviceSelector.Frame.BackgroundTransparency = 0.05
DeviceSelector.Frame.BorderSizePixel = 0
DeviceSelector.Frame.ClipsDescendants = true
DeviceSelector.Frame.Visible = false
DeviceSelector.Frame.Parent = ScreenGui
mkCorner(DeviceSelector.Frame, 16)
mkStroke(DeviceSelector.Frame, Theme.Purple, 0.10, 2)
makeDraggable(DeviceSelector.Frame, DeviceSelector.Frame)

DeviceSelector.Logo = Instance.new("ImageLabel")
DeviceSelector.Logo.BackgroundTransparency = 1
DeviceSelector.Logo.Size = UDim2.fromOffset(30, 30)
DeviceSelector.Logo.Position = UDim2.new(0, 18, 0, 15)
DeviceSelector.Logo.Image = "rbxassetid://72742584610344"
DeviceSelector.Logo.ScaleType = Enum.ScaleType.Fit
DeviceSelector.Logo.Parent = DeviceSelector.Frame

DeviceSelector.Title = Instance.new("TextLabel")
DeviceSelector.Title.BackgroundTransparency = 1
DeviceSelector.Title.Position = UDim2.new(0, 58, 0, 10)
DeviceSelector.Title.Size = UDim2.new(1, -76, 0, 36)
DeviceSelector.Title.Text = "ELIGE TU DISPOSITIVO"
DeviceSelector.Title.TextColor3 = Theme.TextMain
DeviceSelector.Title.TextSize = 16
DeviceSelector.Title.Font = Enum.Font.GothamBold
DeviceSelector.Title.TextXAlignment = Enum.TextXAlignment.Left
DeviceSelector.Title.Parent = DeviceSelector.Frame

DeviceSelector.Subtitle = Instance.new("TextLabel")
DeviceSelector.Subtitle.BackgroundTransparency = 1
DeviceSelector.Subtitle.Position = UDim2.new(0, 20, 0, 55)
DeviceSelector.Subtitle.Size = UDim2.new(1, -40, 0, 44)
DeviceSelector.Subtitle.Text = "Selecciona el dispositivo que estás usando. El panel y los controles se adaptarán a esa elección."
DeviceSelector.Subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
DeviceSelector.Subtitle.TextSize = 11
DeviceSelector.Subtitle.Font = Enum.Font.GothamMedium
DeviceSelector.Subtitle.TextWrapped = true
DeviceSelector.Subtitle.TextXAlignment = Enum.TextXAlignment.Left
DeviceSelector.Subtitle.TextYAlignment = Enum.TextYAlignment.Top
DeviceSelector.Subtitle.Parent = DeviceSelector.Frame

DeviceSelector.PCButton = neonButton(DeviceSelector.Frame, "COMPUTADORA", UDim2.new(0.5, -25, 0, 44), UDim2.new(0, 20, 0, 111))
DeviceSelector.MobileButton = neonButton(DeviceSelector.Frame, "CELULAR", UDim2.new(0.5, -25, 0, 44), UDim2.new(0.5, 5, 0, 111))
decorateDeviceSelectorButton(DeviceSelector.PCButton, "PC")
decorateDeviceSelectorButton(DeviceSelector.MobileButton, "MOBILE")

DeviceSelector.Hint = Instance.new("TextLabel")
DeviceSelector.Hint.BackgroundTransparency = 1
DeviceSelector.Hint.Position = UDim2.new(0, 20, 0, 168)
DeviceSelector.Hint.Size = UDim2.new(1, -40, 0, 26)
DeviceSelector.Hint.Text = DEVICE_HINT_MOBILE and "SUGERENCIA DETECTADA: CELULAR" or "SUGERENCIA DETECTADA: PC"
DeviceSelector.Hint.TextColor3 = Color3.fromRGB(140, 140, 140)
DeviceSelector.Hint.TextSize = 10
DeviceSelector.Hint.Font = Enum.Font.GothamBold
DeviceSelector.Hint.TextXAlignment = Enum.TextXAlignment.Center
DeviceSelector.Hint.Parent = DeviceSelector.Frame

function DeviceSelector:GetSize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or GUI_VIEWPORT_SIZE
	return UDim2.fromOffset(math.min(350, math.max(280, viewport.X - 16)), math.min(214, math.max(200, viewport.Y - 16)))
end
DeviceSelector.Size = DeviceSelector:GetSize()

Lang.Set("ES")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 0, 0, 0) 
MainFrame.BackgroundColor3 = Theme.BG
MainFrame.BackgroundTransparency = 0.18
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
mkCorner(MainFrame, 18)
local MainFrameStroke = mkStroke(MainFrame, Theme.Purple, 0.04, 2)
MainFrameStroke.LineJoinMode = Enum.LineJoinMode.Round

local bgGradient = Instance.new("UIGradient")
bgGradient.Rotation = 32
bgGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 10)),
	ColorSequenceKeypoint.new(0.52, Color3.fromRGB(10, 25, 31)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 68, 90)),
})
bgGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.06),
	NumberSequenceKeypoint.new(0.55, 0.18),
	NumberSequenceKeypoint.new(1, 0.28),
})
bgGradient.Parent = MainFrame

local Header = Instance.new("Frame")
Header.BackgroundColor3 = Theme.Panel
Header.BackgroundTransparency = 0.22
Header.BorderSizePixel = 0
Header.Position = UDim2.new(0, 2, 0, 2)
Header.Size = UDim2.new(1, -4, 0, 58)
Header.ZIndex = 4
Header.Parent = MainFrame
mkCorner(Header, 16)

local HeaderGlow = Instance.new("Frame")
HeaderGlow.BackgroundColor3 = Theme.Purple
HeaderGlow.BackgroundTransparency = 0.08
HeaderGlow.BorderSizePixel = 0
HeaderGlow.Size = UDim2.new(1, 0, 0, 3)
HeaderGlow.Position = UDim2.new(0, 0, 1, -2)
HeaderGlow.Parent = Header

local HeaderLogo = Instance.new("ImageLabel")
HeaderLogo.Name = "HeaderLogo"
HeaderLogo.BackgroundTransparency = 1
HeaderLogo.Size = UDim2.fromOffset(36, 36)
HeaderLogo.Position = UDim2.new(0, 15, 0, 11)
HeaderLogo.Image = "rbxassetid://72742584610344"
HeaderLogo.ScaleType = Enum.ScaleType.Fit
HeaderLogo.ZIndex = 5
HeaderLogo.Parent = Header

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 59, 0, 5)
Title.Size = UDim2.new(1, -244, 0, 30)
Title.Text = "H3X4 X"
Title.TextColor3 = Theme.TextMain
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title:SetAttribute("HexaNoGlobalFont", true)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.Parent = Header
makeDraggable(MainFrame, Title)

do
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "HexaUniversalSubtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.new(0, 59, 0, 32)
	subtitle.Size = UDim2.new(1, -244, 0, 18)
	subtitle.Text = "UNIVERSAL"
	subtitle.TextColor3 = Theme.TextMain
	subtitle.TextTransparency = 0.48
	subtitle.TextSize = 10
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle:SetAttribute("HexaNoTranslate", true)
	subtitle.Parent = Header
	makeDraggable(MainFrame, subtitle)
end

local CloseButton = neonButton(Header, "X", UDim2.new(0, 36, 0, 34), UDim2.new(1, -48, 0, 12), 4)
CloseButton.TextColor3 = BUTTON_TEXT_COLOR
CloseButton.BackgroundColor3 = Theme.PurpleDeep

local MinButton = neonButton(Header, "-", UDim2.new(0, 36, 0, 34), UDim2.new(1, -90, 0, 12), 4)
MinButton.TextColor3 = BUTTON_TEXT_COLOR
MinButton.BackgroundColor3 = Theme.PurpleDeep
MinButton:SetAttribute("HexaNoFavorite", true)
CloseButton:SetAttribute("HexaNoFavorite", true)

local TutorialBtn = neonButton(Header, "?", UDim2.new(0, 36, 0, 34), UDim2.new(1, -132, 0, 12), 4)
TutorialBtn.TextColor3 = BUTTON_TEXT_COLOR
TutorialBtn.BackgroundColor3 = Theme.PurpleDeep
TutorialBtn:SetAttribute("HexaNoFavorite", true)

Lang.MainButton = neonButton(Header, "ES", UDim2.new(0, 44, 0, 34), UDim2.new(1, -182, 0, 12), 4)
Lang.MainButton.TextColor3 = BUTTON_TEXT_COLOR
Lang.MainButton.BackgroundColor3 = Theme.PurpleDeep
Lang.MainButton:SetAttribute("HexaNoTranslate", true)
Lang.MainButton:SetAttribute("HexaNoFavorite", true)
Lang.MainButton.MouseButton1Click:Connect(function()
	Lang.Set(Lang.Current == "ES" and "EN" or "ES")
end)

Lang.Set(Lang.Current)

local RestoreOrb = Instance.new("ImageButton")
RestoreOrb.Visible = false
RestoreOrb.Size = UDim2.new(0, 0, 0, 0)
RestoreOrb.Position = UDim2.new(0, 18, 0.2, 0)
RestoreOrb.BackgroundColor3 = Theme.Panel2
RestoreOrb.BackgroundTransparency = 1 
RestoreOrb.BorderSizePixel = 0
RestoreOrb.Image = "rbxassetid://72742584610344" 
RestoreOrb.ScaleType = Enum.ScaleType.Fit
RestoreOrb.AutoButtonColor = false
RestoreOrb.Parent = ScreenGui
makeDraggable(RestoreOrb, RestoreOrb)

-- Navegación por categorías. En computadora se muestra como barra lateral;
-- en dispositivos móviles se adapta a una fila horizontal desplazable.
local Content
local CategoryUI = {
	Active = "ALL",
	Buttons = {},
	Definitions = {
		{Key = "ALL", Label = "TODAS"},
		{Key = "HOME", Label = "INICIO"},
		{Key = "MOVEMENT", Label = "MOVIMIENTO"},
		{Key = "COMBAT", Label = "COMBATE"},
		{Key = "VIP", Label = "VIP"},
		{Key = "VISUALS", Label = "VISUALES"},
		{Key = "TELEPORT", Label = "TELETRANSPORTE"},
		{Key = "PLAYER", Label = "JUGADOR"},
		{Key = "INFO", Label = "INFORMACIÓN"},
		{Key = "SYSTEM", Label = "SISTEMA"},
		{Key = "KEYBINDS", Label = "KEYBINDS"},
		{Key = "FLOATING", Label = "BOTONES FLOTANTES"},
		{Key = "CUSTOMIZE", Label = "PERSONALIZAR"},
	},
}

CategoryUI.Frame = Instance.new("Frame")
CategoryUI.Frame.Name = "HexaCategoryNavigation"
CategoryUI.Frame.BackgroundColor3 = Theme.Panel
CategoryUI.Frame.BackgroundTransparency = 0.20
CategoryUI.Frame.BorderSizePixel = 0
CategoryUI.Frame.ClipsDescendants = true
CategoryUI.Frame.ZIndex = 3
CategoryUI.Frame.Parent = MainFrame
mkCorner(CategoryUI.Frame, 14)
mkStroke(CategoryUI.Frame, Theme.Accent, 0.78, 1)

if MOBILE_DEVICE then
	CategoryUI.Frame.Position = UDim2.new(0, 6, 0, 64)
	CategoryUI.Frame.Size = UDim2.new(1, -12, 0, 104)
else
	CategoryUI.Frame.Position = UDim2.new(0, 6, 0, 64)
	CategoryUI.Frame.Size = UDim2.new(0, 158, 1, -70)
end

CategoryUI.Title = Instance.new("TextLabel")
CategoryUI.Title.Name = "HexaCategoryTitle"
CategoryUI.Title.BackgroundTransparency = 1
CategoryUI.Title.Position = UDim2.new(0, 10, 0, 5)
CategoryUI.Title.Size = UDim2.new(1, -20, 0, 22)
CategoryUI.Title.Text = "CATEGORÍAS"
CategoryUI.Title.TextColor3 = Theme.TextMain
CategoryUI.Title.TextSize = 11
CategoryUI.Title.Font = Enum.Font.GothamBold
CategoryUI.Title.TextXAlignment = Enum.TextXAlignment.Left
CategoryUI.Title.Visible = not MOBILE_DEVICE
CategoryUI.Title.ZIndex = 4
CategoryUI.Title.Parent = CategoryUI.Frame

FunctionSearchBox = Instance.new("TextBox")
FunctionSearchBox.Name = "HexaFunctionSearch"
FunctionSearchBox.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
FunctionSearchBox.BackgroundTransparency = 0.06
FunctionSearchBox.BorderSizePixel = 0
FunctionSearchBox.Position = MOBILE_DEVICE and UDim2.new(0, 8, 0, 7) or UDim2.new(0, 8, 0, 29)
FunctionSearchBox.Size = UDim2.new(1, -16, 0, 30)
FunctionSearchBox.Text = ""
FunctionSearchBox.PlaceholderText = Lang.Current == "EN" and "SEARCH FUNCTIONS..." or "BUSCAR FUNCIONES..."
FunctionSearchBox.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
FunctionSearchBox.TextColor3 = Theme.TextMain
FunctionSearchBox.TextSize = 10
FunctionSearchBox.Font = Enum.Font.GothamMedium
FunctionSearchBox.TextXAlignment = Enum.TextXAlignment.Left
FunctionSearchBox.ClearTextOnFocus = false
FunctionSearchBox.MultiLine = false
FunctionSearchBox.ZIndex = 6
FunctionSearchBox:SetAttribute("HexaNoTranslate", true)
FunctionSearchBox.Parent = CategoryUI.Frame
mkCorner(FunctionSearchBox, 10)
local FunctionSearchStroke = mkStroke(FunctionSearchBox, Theme.Purple, 0.42, 1)
local FunctionSearchPadding = Instance.new("UIPadding")
FunctionSearchPadding.PaddingLeft = UDim.new(0, 10)
FunctionSearchPadding.PaddingRight = UDim.new(0, 8)
FunctionSearchPadding.Parent = FunctionSearchBox
FunctionSearchBox.Focused:Connect(function()
	FunctionSearchStroke.Color = Color3.fromRGB(255, 255, 255)
	FunctionSearchStroke.Transparency = 0.04
	FunctionSearchStroke.Thickness = 2
end)
FunctionSearchBox.FocusLost:Connect(function()
	FunctionSearchStroke.Color = Theme.Purple
	FunctionSearchStroke.Transparency = 0.42
	FunctionSearchStroke.Thickness = 1
end)

CategoryUI.Scroll = Instance.new("ScrollingFrame")
CategoryUI.Scroll.Name = "HexaCategoryButtons"
CategoryUI.Scroll.BackgroundTransparency = 1
CategoryUI.Scroll.BorderSizePixel = 0
CategoryUI.Scroll.Position = MOBILE_DEVICE and UDim2.new(0, 8, 0, 43) or UDim2.new(0, 8, 0, 65)
CategoryUI.Scroll.Size = MOBILE_DEVICE and UDim2.new(1, -16, 1, -49) or UDim2.new(1, -16, 1, -71)
CategoryUI.Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CategoryUI.Scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
CategoryUI.Scroll.ScrollingDirection = MOBILE_DEVICE and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
CategoryUI.Scroll.ScrollBarThickness = MOBILE_DEVICE and 0 or 3
CategoryUI.Scroll.ScrollBarImageColor3 = Theme.Accent
CategoryUI.Scroll.ScrollBarImageTransparency = 0.38
CategoryUI.Scroll.Active = true
CategoryUI.Scroll.ZIndex = 4
CategoryUI.Scroll.Parent = CategoryUI.Frame

CategoryUI.Layout = Instance.new("UIListLayout")
CategoryUI.Layout.FillDirection = MOBILE_DEVICE and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
CategoryUI.Layout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryUI.Layout.HorizontalAlignment = MOBILE_DEVICE and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
CategoryUI.Layout.VerticalAlignment = MOBILE_DEVICE and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top
CategoryUI.Layout.Padding = UDim.new(0, MOBILE_DEVICE and 6 or 2)
CategoryUI.Layout.Parent = CategoryUI.Scroll

local function refreshCategoryCanvas()
	local contentSize = CategoryUI.Layout.AbsoluteContentSize
	if MOBILE_DEVICE then
		CategoryUI.Scroll.CanvasSize = UDim2.new(0, contentSize.X + 16, 0, 0)
		local maximumX = math.max(0, contentSize.X + 16 - CategoryUI.Scroll.AbsoluteSize.X)
		if CategoryUI.Scroll.CanvasPosition.X > maximumX then
			CategoryUI.Scroll.CanvasPosition = Vector2.new(maximumX, 0)
		end
	else
		CategoryUI.Scroll.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 12)
	end
end
CategoryUI.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	task.defer(refreshCategoryCanvas)
end)

-- Iconos vectoriales nativos: no dependen de fuentes, emojis ni recursos externos.
local function createCategoryIcon(parent, categoryKey)
	local icon = Instance.new("Frame")
	icon.Name = "HexaCategoryIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.fromOffset(16, 16)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.ZIndex = parent.ZIndex + 1
	icon.Parent = parent

	local function part(name, x, y, width, height, rotation, radius, outlined)
		local object = Instance.new("Frame")
		object.Name = name
		object.Position = UDim2.fromOffset(x, y)
		object.Size = UDim2.fromOffset(width, height)
		object.Rotation = rotation or 0
		object.BackgroundColor3 = BUTTON_TEXT_COLOR
		object.BackgroundTransparency = outlined and 1 or 0
		object.BorderSizePixel = 0
		object.ZIndex = icon.ZIndex
		object.Parent = icon
		if radius then mkCorner(object, radius) end
		if outlined then mkStroke(object, BUTTON_TEXT_COLOR, 0, 1) end
		return object
	end

	local function line(name, x, y, width, height, rotation)
		return part(name, x, y, width, height, rotation, math.max(1, math.floor(height / 2)), false)
	end

	if categoryKey == "ALL" then
		for index, position in ipairs({{1, 1}, {9, 1}, {1, 9}, {9, 9}}) do
			part("Tile" .. index, position[1], position[2], 6, 6, 0, 2, true)
		end
	elseif categoryKey == "HOME" then
		line("RoofLeft", 1, 4, 9, 2, -35)
		line("RoofRight", 7, 4, 9, 2, 35)
		part("House", 3, 7, 10, 8, 0, 1, true)
		line("Door", 7, 11, 2, 4, 0)
	elseif categoryKey == "MOVEMENT" then
		line("ArrowBody", 1, 7, 13, 2, 0)
		line("ArrowTop", 9, 4, 7, 2, 45)
		line("ArrowBottom", 9, 10, 7, 2, -45)
	elseif categoryKey == "COMBAT" then
		part("SightRing", 3, 3, 10, 10, 0, 5, true)
		line("SightHorizontal", 0, 7, 16, 2, 0)
		line("SightVertical", 7, 0, 2, 16, 0)
	elseif categoryKey == "VIP" then
		part("OuterGem", 3, 3, 10, 10, 45, 1, true)
		part("InnerGem", 6, 6, 4, 4, 45, 1, true)
	elseif categoryKey == "VISUALS" then
		part("Eye", 0, 3, 16, 10, 0, 5, true)
		part("Pupil", 5, 5, 6, 6, 0, 3, false)
	elseif categoryKey == "TELEPORT" then
		part("Portal", 1, 1, 14, 14, 0, 7, true)
		line("PortalArrow", 4, 7, 8, 2, 0)
		line("PortalArrowTop", 9, 5, 5, 2, 45)
		line("PortalArrowBottom", 9, 9, 5, 2, -45)
	elseif categoryKey == "PLAYER" then
		part("Head", 5, 0, 6, 6, 0, 3, false)
		part("Body", 2, 8, 12, 8, 0, 6, true)
	elseif categoryKey == "INFO" then
		part("InfoRing", 1, 1, 14, 14, 0, 7, true)
		part("InfoDot", 7, 4, 2, 2, 0, 1, false)
		line("InfoStem", 7, 7, 2, 5, 0)
	elseif categoryKey == "SYSTEM" then
		part("GearRing", 3, 3, 10, 10, 0, 5, true)
		part("GearCenter", 6, 6, 4, 4, 0, 2, false)
		line("GearTop", 7, 0, 2, 4, 0)
		line("GearBottom", 7, 12, 2, 4, 0)
		line("GearLeft", 0, 7, 4, 2, 0)
		line("GearRight", 12, 7, 4, 2, 0)
	elseif categoryKey == "KEYBINDS" then
		part("KeyLeft", 1, 4, 4, 4, 0, 2, true)
		part("KeyMid", 6, 4, 4, 4, 0, 2, true)
		part("KeyRight", 11, 4, 4, 4, 0, 2, true)
		part("Space", 3, 10, 10, 4, 0, 2, true)
	elseif categoryKey == "FLOATING" then
		part("FloatOne", 1, 2, 6, 5, 0, 2, true)
		part("FloatTwo", 9, 2, 6, 5, 0, 2, true)
		part("FloatThree", 5, 9, 6, 5, 0, 2, true)
	elseif categoryKey == "CUSTOMIZE" then
		line("SliderTop", 1, 3, 14, 2, 0)
		line("SliderMiddle", 1, 7, 14, 2, 0)
		line("SliderBottom", 1, 11, 14, 2, 0)
		part("SliderTopKnob", 4, 1, 4, 6, 0, 2, false)
		part("SliderMiddleKnob", 10, 5, 4, 6, 0, 2, false)
		part("SliderBottomKnob", 6, 9, 4, 6, 0, 2, false)
	end

	return icon
end

function CategoryUI:GetCardCategory(card)
	if not card or not card:IsA("Frame") then return "ALL" end
	if card.Name == "HexaFavoritesCard" then return "HOME" end
	local override = card:GetAttribute("HexaCategoryOverride")
	if type(override) == "string" and override ~= "" then return override end
	local order = tonumber(card.LayoutOrder) or 0
	if order < -1 then return "SYSTEM" end
	if order < 10 or order >= 90 then return "HOME" end
	if (order >= 10 and order < 20) or (order >= 34 and order < 40) then return "MOVEMENT" end
	if order >= 20 and order < 30 then return "COMBAT" end
	if order >= 30 and order < 34 then return "VISUALS" end
	if order >= 40 and order < 50 then return "TELEPORT" end
	if order >= 50 and order < 60 then return "PLAYER" end
	if order >= 60 and order < 70 then return "INFO" end
	if order >= 70 and order < 80 then return "SYSTEM" end
	if order >= 80 and order < 90 then return "CUSTOMIZE" end
	return "HOME"
end

function CategoryUI:Matches(card)
	if self.Active == "VIP" then
		for _, object in ipairs(card:GetDescendants()) do
			if object:GetAttribute("HexaVipOnly") == true then return true end
		end
		return false
	end
	return self.Active == "ALL" or self:GetCardCategory(card) == self.Active
end

function CategoryUI:RefreshButtons()
	for key, button in pairs(self.Buttons) do
		local selected = key == self.Active
		button:SetAttribute("IsActive", selected)
		button:SetAttribute("HexaCategorySelected", selected)
		button.BackgroundColor3 = selected and Theme.PurpleDark or Theme.Panel2
		button.BackgroundTransparency = selected and 0.04 or 1
		button.TextColor3 = selected and Theme.PurpleText or BUTTON_TEXT_COLOR
		local label = button:FindFirstChild("HexaCategoryLabel")
		if label and label:IsA("TextLabel") then
			label.TextColor3 = selected and Theme.PurpleText or BUTTON_TEXT_COLOR
		end
		local icon = button:FindFirstChild("HexaCategoryIcon")
		if icon then
			for _, object in ipairs(icon:GetDescendants()) do
				if object:IsA("Frame") then
					object.BackgroundColor3 = selected and Theme.PurpleText or BUTTON_TEXT_COLOR
				elseif object:IsA("UIStroke") then
					object.Color = selected and Theme.PurpleText or BUTTON_TEXT_COLOR
				end
			end
		end
		local stroke = button:FindFirstChild("HexaCategoryStroke")
		if stroke then
			stroke.Color = selected and Theme.Purple or Theme.PurpleText
			stroke.Transparency = selected and 0.02 or 0.70
			stroke.Thickness = selected and 2 or 1
		end
	end
end

function CategoryUI:Select(key)
	self.Active = key or "ALL"
	self:RefreshButtons()
	task.defer(function()
		if Content and Content.Parent then
			Content.CanvasPosition = Vector2.new(0, 0)
			refreshCategoryView()
		end
	end)
end

for index, definition in ipairs(CategoryUI.Definitions) do
	local button = Instance.new("TextButton")
	button.Name = "HexaCategory_" .. definition.Key
	button.LayoutOrder = index
	button.Size = MOBILE_DEVICE and UDim2.fromOffset(math.max(92, #definition.Label * 6 + 46), 33) or UDim2.new(1, -8, 0, 27)
	button.BackgroundColor3 = Theme.Panel2
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.TextColor3 = BUTTON_TEXT_COLOR
	button.AutoButtonColor = false
	button.ZIndex = 5
	button.Parent = CategoryUI.Scroll
	button:SetAttribute("HexaNoFavorite", true)
	button:SetAttribute("HexaNoTranslate", true)
	mkCorner(button, MOBILE_DEVICE and 15 or 13)
	local stroke = mkStroke(button, Theme.Purple, 0.62, 1)
	stroke.Name = "HexaCategoryStroke"
	createCategoryIcon(button, definition.Key)

	local label = Instance.new("TextLabel")
	label.Name = "HexaCategoryLabel"
	label.Position = UDim2.new(0, 30, 0, 0)
	label.Size = UDim2.new(1, -36, 1, 0)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = definition.Label
	label.TextColor3 = BUTTON_TEXT_COLOR
	label.TextSize = 10
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.Active = false
	label.ZIndex = button.ZIndex + 1
	label.Parent = button
	label:SetAttribute("BaseText", definition.Label)

	addHover(button, Theme.Panel2, Theme.PurpleDeep, Theme.PurpleDark)
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		if button:GetAttribute("HexaCategorySelected") == true and button.BackgroundColor3 ~= Theme.PurpleDark then
			button.BackgroundColor3 = Theme.PurpleDark
		end
	end)
	button.MouseButton1Click:Connect(function()
		CategoryUI:Select(definition.Key)
	end)
	CategoryUI.Buttons[definition.Key] = button
end
CategoryUI:RefreshButtons()
task.defer(refreshCategoryCanvas)

Content = Instance.new("ScrollingFrame")
Content.Name = "HexaFunctionPanel"
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.Position = MOBILE_DEVICE and UDim2.new(0, 2, 0, 172) or UDim2.new(0, 168, 0, 62)
Content.Size = MOBILE_DEVICE and UDim2.new(1, -4, 1, -174) or UDim2.new(1, -170, 1, -64)
Content.ScrollBarThickness = MOBILE_DEVICE and 6 or 4
Content.ScrollBarImageColor3 = Theme.Purple
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = MOBILE_DEVICE and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
Content.ScrollingEnabled = true
Content.Active = true
Content.ScrollBarImageTransparency = 0.24
Content.ZIndex = 3
Content.Parent = MainFrame

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 14)
Padding.PaddingBottom = UDim.new(0, 16)
Padding.PaddingLeft = UDim.new(0, 14)
Padding.PaddingRight = UDim.new(0, 14)
Padding.Parent = Content

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 14)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

do
local FAVORITES_FILE_NAME = ("HexaX_Favorites_%d.json"):format(LocalPlayer.UserId)
local FavoriteIds = {}
local FavoriteRegistry = {}
local FavoriteStars = {}

local function normalizeFavoriteId(value)
	local text = string.lower(tostring(value or ""))
	text = text:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
	text = text:gsub("%s+", " ")
	return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function loadFavorites()
	if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
	local ok, raw = pcall(function()
		if isfile(FAVORITES_FILE_NAME) then return readfile(FAVORITES_FILE_NAME) end
	end)
	if not ok or type(raw) ~= "string" or raw == "" then return end
	local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if decodedOk and type(decoded) == "table" then
		for _, id in ipairs(decoded) do FavoriteIds[tostring(id)] = true end
	end
end

local function saveFavorites()
	if type(writefile) ~= "function" then return end
	local values = {}
	for id, enabled in pairs(FavoriteIds) do
		if enabled then table.insert(values, id) end
	end
	table.sort(values)
	pcall(function() writefile(FAVORITES_FILE_NAME, HttpService:JSONEncode(values)) end)
end

loadFavorites()

local FavoritesCard = Instance.new("Frame")
FavoritesCard.Name = "HexaFavoritesCard"
FavoritesCard.LayoutOrder = 0
FavoritesCard.Size = UDim2.new(1, 0, 0, 60)
FavoritesCard.BackgroundColor3 = Theme.Panel
FavoritesCard.BackgroundTransparency = 0.24
FavoritesCard.BorderSizePixel = 0
FavoritesCard.ClipsDescendants = true
FavoritesCard.Visible = false
FavoritesCard.Parent = Content
FavoritesCard:SetAttribute("HexaContentCard", true)
mkCorner(FavoritesCard, 16)
mkStroke(FavoritesCard, Theme.VipGold, 0.18, 1)

local FavoritesTitle = sectionTitle(FavoritesCard, "FAVORITOS", UDim2.new(0, 16, 0, 14))
FavoritesTitle.TextColor3 = Theme.VipGold
local FavoritesEmpty = Instance.new("TextLabel")
FavoritesEmpty.BackgroundTransparency = 1
FavoritesEmpty.Position = UDim2.new(0, 16, 0, 38)
FavoritesEmpty.Size = UDim2.new(1, -32, 0, 26)
FavoritesEmpty.Text = "NO TIENES FUNCIONES FAVORITAS"
FavoritesEmpty.TextColor3 = Color3.fromRGB(150, 150, 150)
FavoritesEmpty.TextSize = 11
FavoritesEmpty.Font = Enum.Font.GothamMedium
FavoritesEmpty.TextXAlignment = Enum.TextXAlignment.Left
FavoritesEmpty.Parent = FavoritesCard

local function getCardForButton(button)
	local current = button.Parent
	while current and current ~= Content do
		if current.Parent == Content and current:IsA("Frame") then return current end
		current = current.Parent
	end
	return nil
end

local function getFavoriteSourceText(button)
	local base = button:GetAttribute("HexaSpanishBaseText") or button:GetAttribute("BaseText") or button.Text
	base = Lang.ToSpanish(tostring(base or ""))
	base = base:gsub("  •  ACTIVO", "")
	return base
end

local function getFavoriteId(button)
	local card = getCardForButton(button)
	local cardTitle = "GENERAL"
	if card then
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("TextLabel") and child.Name ~= "HexaVipBadge" then
				cardTitle = Lang.ToSpanish(child.Text)
				break
			end
		end
	end
	return normalizeFavoriteId(cardTitle .. "|" .. getFavoriteSourceText(button))
end

local function updateFavoriteStars()
	for id, star in pairs(FavoriteStars) do
		if star and star.Parent then
			star.Visible = HEXA_IS_VIP
			star.Text = FavoriteIds[id] and "★" or "☆"
			star.TextColor3 = BUTTON_TEXT_COLOR
		end
	end
end

refreshFavoritesCard = function()
	for _, child in ipairs(FavoritesCard:GetChildren()) do
		if child:GetAttribute("HexaFavoriteShortcut") == true then child:Destroy() end
	end
	local entries = {}
	for id, enabled in pairs(FavoriteIds) do
		local entry = enabled and FavoriteRegistry[id] or nil
		if entry and entry.Button and entry.Button.Parent then
			table.insert(entries, {id = id, entry = entry, label = getFavoriteSourceText(entry.Button)})
		end
	end
	table.sort(entries, function(a, b) return a.label < b.label end)
	FavoritesEmpty.Visible = #entries == 0
	local y = 42
	for _, item in ipairs(entries) do
		local shortcut = Instance.new("TextButton")
		shortcut:SetAttribute("HexaFavoriteShortcut", true)
		shortcut:SetAttribute("HexaNoFavorite", true)
		shortcut.Position = UDim2.new(0, 16, 0, y)
		shortcut.Size = UDim2.new(1, -32, 0, 36)
		shortcut.BackgroundColor3 = Theme.Panel2
		shortcut.BackgroundTransparency = 1
		shortcut.BorderSizePixel = 0
		shortcut.Text = item.label
		shortcut.TextColor3 = BUTTON_TEXT_COLOR
		shortcut.TextSize = 11
		shortcut.Font = Enum.Font.GothamSemibold
		shortcut.AutoButtonColor = false
		shortcut.Parent = FavoritesCard
		shortcut:SetAttribute("BaseText", item.label)
		mkCorner(shortcut, 9)
		mkStroke(shortcut, Theme.VipGold, 0.45, 1)
		addHover(shortcut, Theme.Panel2, Theme.Accent2, Theme.Active)
		shortcut.MouseButton1Click:Connect(function()
			local target = item.entry.Button
			local targetCard = item.entry.Card
			if target and target.Parent and targetCard and targetCard.Parent then
				task.defer(function()
					local relativeY = targetCard.AbsolutePosition.Y - Content.AbsolutePosition.Y + Content.CanvasPosition.Y
					Content.CanvasPosition = Vector2.new(0, math.max(0, relativeY - 10))
					local pulse = target:FindFirstChild("HexaFavoritePulse")
					if not pulse then
						pulse = mkStroke(target, Theme.VipGold, 0, 3)
						pulse.Name = "HexaFavoritePulse"
					end
					pulse.Enabled = true
					task.delay(1.1, function()
						if pulse and pulse.Parent then pulse.Enabled = false end
					end)
				end)
			end
		end)
		y += 42
	end
	FavoritesCard.Size = UDim2.new(1, 0, 0, #entries > 0 and (y + 8) or 72)
	FavoritesCard:SetAttribute("HexaHasFavorites", #entries > 0)
	FavoritesCard.Visible = HEXA_IS_VIP and #entries > 0
	updateFavoriteStars()
end

registerFunctionButton = function(button)
	-- Favoritos deshabilitados: no crear estrellas ni accesos directos.
	if button and button:IsA("TextButton") then
		button:SetAttribute("HexaNoFavorite", true)
	end
end

registerAllFunctionButtons = function()
	if not Content or not Content.Parent then return end
	for _, object in ipairs(Content:GetDescendants()) do
		if object:IsA("TextButton") then
			pcall(registerFunctionButton, object)
		end
	end
	refreshFavoritesCard()
end

local CardOriginalPositions = setmetatable({}, {__mode = "k"})
local CardOriginalSizes = setmetatable({}, {__mode = "k"})

local function refreshMobileCanvas()
	if not MOBILE_DEVICE or not Content or not Content.Parent then return end
	local contentHeight = math.max(0, Layout.AbsoluteContentSize.Y + 34)
	Content.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
	local maximumY = math.max(0, contentHeight - Content.AbsoluteSize.Y)
	if Content.CanvasPosition.Y > maximumY then
		Content.CanvasPosition = Vector2.new(0, maximumY)
	end
end

local function fitContentCard(card, units)
	if not card or not card.Parent then return end

	-- Todas las tarjetas usan posiciones absolutas para sus controles. Antes este
	-- ajuste solo se hacía en móvil, por lo que en PC una tarjeta con una altura
	-- demasiado pequeña podía recortar y hacer desaparecer funciones completas.
	local baseHeight = tonumber(card:GetAttribute("HexaMobileBaseHeight")) or card.Size.Y.Offset
	local requiredHeight = math.max(1, baseHeight)

	if units then
		for _, unit in ipairs(units) do
			if not CardOriginalPositions[unit] then CardOriginalPositions[unit] = unit.Position end
		end
	end

	for _, object in ipairs(card:GetChildren()) do
		if object:IsA("GuiObject") then
			local originalPosition = CardOriginalPositions[object] or object.Position
			local objectHeight = math.max(0, object.Size.Y.Offset)
			local anchorOffset = object.AnchorPoint.Y * objectHeight
			local bottom = originalPosition.Y.Offset - anchorOffset + objectHeight + 20
			requiredHeight = math.max(requiredHeight, bottom)
		end
	end

	card.Size = UDim2.new(card.Size.X.Scale, card.Size.X.Offset, 0, math.ceil(requiredHeight))
	-- Guardar siempre la altura normal completa. Los modos VIP/buscador pueden
	-- encoger temporalmente la tarjeta, pero al volver se restaura este tamaño.
	CardOriginalSizes[card] = card.Size
end

local function isCardUnit(object)
	if not object:IsA("GuiObject") then return false end
	return object:IsA("TextButton")
		or object:IsA("TextBox")
		or object.Name == "HexaSegmentedSlider"
		or object:GetAttribute("HexaVipOnly") == true
end

local function getCardUnits(card)
	local units = {}
	for _, object in ipairs(card:GetChildren()) do
		if isCardUnit(object) and object.Name ~= "HexaFavoriteStar" then
			if not CardOriginalPositions[object] then CardOriginalPositions[object] = object.Position end
			table.insert(units, object)
		end
	end
	table.sort(units, function(a, b)
		local aPosition = CardOriginalPositions[a] or a.Position
		local bPosition = CardOriginalPositions[b] or b.Position
		if aPosition.Y.Offset == bPosition.Y.Offset then return aPosition.X.Offset < bPosition.X.Offset end
		return aPosition.Y.Offset < bPosition.Y.Offset
	end)
	return units
end

local function unitIsVip(unit)
	if unit:GetAttribute("HexaVipOnly") == true then return true end
	for _, object in ipairs(unit:GetDescendants()) do
		if object:GetAttribute("HexaVipOnly") == true then return true end
	end
	return false
end

local function restoreCardLayout(card, units)
	local originalSize = CardOriginalSizes[card]
	if originalSize then card.Size = originalSize end
	for _, unit in ipairs(units) do
		local originalPosition = CardOriginalPositions[unit]
		if originalPosition then unit.Position = originalPosition end
		unit.Visible = true
	end
end

local function showVipUnits(card, units)
	if not CardOriginalSizes[card] then CardOriginalSizes[card] = card.Size end
	local rows = {}
	local rowOrder = {}
	for _, unit in ipairs(units) do
		local include = unitIsVip(unit)
		unit.Visible = include
		if include then
			local originalPosition = CardOriginalPositions[unit] or unit.Position
			local rowKey = originalPosition.Y.Offset
			if not rows[rowKey] then
				rows[rowKey] = {}
				table.insert(rowOrder, rowKey)
			end
			table.insert(rows[rowKey], unit)
		end
	end

	table.sort(rowOrder)
	local nextY = 44
	local visibleUnits = 0
	for _, rowKey in ipairs(rowOrder) do
		local rowHeight = 0
		for _, unit in ipairs(rows[rowKey]) do
			local originalPosition = CardOriginalPositions[unit] or unit.Position
			unit.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, nextY)
			rowHeight = math.max(rowHeight, unit.Size.Y.Offset)
			visibleUnits += 1
		end
		nextY += math.max(30, rowHeight) + 8
	end

	if visibleUnits > 0 then
		local originalSize = CardOriginalSizes[card] or card.Size
		card.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, nextY + 2)
	end
	return visibleUnits
end

local function normalizeFunctionSearch(value)
	local normalized = string.lower(tostring(value or ""))
	normalized = normalized:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
	normalized = normalized:gsub("[^%w%s]", " ")
	normalized = normalized:gsub("%s+", " ")
	return normalized:gsub("^%s+", ""):gsub("%s+$", "")
end

local function appendFunctionSearchText(parts, value)
	if typeof(value) ~= "string" or value == "" then return end
	local spanish = Lang.ToSpanish(value)
	local english = Lang.ToEnglish(spanish)
	table.insert(parts, value)
	if spanish ~= value then table.insert(parts, spanish) end
	if english ~= value and english ~= spanish then table.insert(parts, english) end
end

local function getFunctionSearchText(unit)
	local parts = {}
	local function collect(object)
		if not (object:IsA("TextButton") or object:IsA("TextLabel") or object:IsA("TextBox")) then return end
		appendFunctionSearchText(parts, object.Text)
		appendFunctionSearchText(parts, object:GetAttribute("BaseText"))
		appendFunctionSearchText(parts, object:GetAttribute("HexaSpanishText"))
		appendFunctionSearchText(parts, object:GetAttribute("HexaSpanishBaseText"))
	end
	collect(unit)
	for _, object in ipairs(unit:GetDescendants()) do collect(object) end
	return normalizeFunctionSearch(table.concat(parts, " "))
end

local function unitMatchesFunctionSearch(unit, query)
	local normalizedQuery = normalizeFunctionSearch(query)
	if normalizedQuery == "" then return true end
	local haystack = getFunctionSearchText(unit)
	for token in string.gmatch(normalizedQuery, "%S+") do
		if not string.find(haystack, token, 1, true) then return false end
	end
	return true
end

local function showSearchUnits(card, units, query)
	if not CardOriginalSizes[card] then CardOriginalSizes[card] = card.Size end
	local rows = {}
	local rowOrder = {}
	for _, unit in ipairs(units) do
		local include = unitMatchesFunctionSearch(unit, query)
		unit.Visible = include
		if include then
			local originalPosition = CardOriginalPositions[unit] or unit.Position
			local rowKey = originalPosition.Y.Offset
			if not rows[rowKey] then
				rows[rowKey] = {}
				table.insert(rowOrder, rowKey)
			end
			table.insert(rows[rowKey], unit)
		end
	end
	table.sort(rowOrder)
	local nextY = 44
	local visibleUnits = 0
	for _, rowKey in ipairs(rowOrder) do
		local rowHeight = 0
		for _, unit in ipairs(rows[rowKey]) do
			local originalPosition = CardOriginalPositions[unit] or unit.Position
			unit.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, nextY)
			rowHeight = math.max(rowHeight, unit.Size.Y.Offset)
			visibleUnits += 1
		end
		nextY += math.max(30, rowHeight) + 8
	end
	if visibleUnits > 0 then
		local originalSize = CardOriginalSizes[card] or card.Size
		card.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, nextY + 2)
	end
	return visibleUnits
end

refreshCategoryView = function()
	local searchQuery = FunctionSearchBox and FunctionSearchBox.Text or ""
	local searching = normalizeFunctionSearch(searchQuery) ~= ""
	for _, card in ipairs(Content:GetChildren()) do
		if card:IsA("Frame") and card:GetAttribute("HexaContentCard") == true then
			local units = getCardUnits(card)
			restoreCardLayout(card, units)
			if not searching and CategoryUI.Active ~= "VIP" then fitContentCard(card, units) end
			local cardCategory = CategoryUI:GetCardCategory(card)
			local desktopOnly = card:GetAttribute("HexaDesktopOnly") == true or cardCategory == "KEYBINDS"
			local mobileOnly = card:GetAttribute("HexaMobileOnly") == true or cardCategory == "FLOATING"
			local defaultVisible = card ~= FavoritesCard or (HEXA_IS_VIP and card:GetAttribute("HexaHasFavorites") == true)
			local visible
			if (MOBILE_DEVICE and desktopOnly) or ((not MOBILE_DEVICE) and mobileOnly) then
				visible = false
			elseif searching then
				-- El buscador es global: muestra únicamente funciones coincidentes,
				-- independientemente de la categoría que estuviera seleccionada.
				visible = card ~= FavoritesCard and showSearchUnits(card, units, searchQuery) > 0
			elseif CategoryUI.Active == "VIP" then
				-- La categoría VIP reutiliza los controles originales; siguen presentes
				-- en sus categorías habituales y aquí se muestran solos y ordenados.
				visible = showVipUnits(card, units) > 0
			else
				visible = defaultVisible and CategoryUI:Matches(card)
			end
			card.Visible = visible
		end
	end
	task.defer(refreshMobileCanvas)
end

local functionSearchGeneration = 0
FunctionSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	functionSearchGeneration += 1
	local generation = functionSearchGeneration
	task.delay(0.06, function()
		if generation ~= functionSearchGeneration then return end
		if Content and Content.Parent then
			Content.CanvasPosition = Vector2.new(0, 0)
			refreshCategoryView()
		end
	end)
end)

local categoryRefreshPending = false
local function scheduleCategoryRefresh()
	if not UI_READY or categoryRefreshPending then return end
	categoryRefreshPending = true
	task.delay(0.12, function()
		categoryRefreshPending = false
		if Content and Content.Parent then refreshCategoryView() end
	end)
end

Content.DescendantAdded:Connect(function(object)
	if not UI_READY then return end
	if object:IsA("TextButton") then
		task.defer(function()
			if object and object.Parent then pcall(registerFunctionButton, object) end
		end)
	end
	-- Las extensiones crean tarjetas y funciones después de que la UI ya está
	-- abierta. Recalcular evita que una tarjeta conserve una altura vieja.
	scheduleCategoryRefresh()
end)

Content.DescendantRemoving:Connect(function()
	-- Si una función se elimina dinámicamente, restaurar también el layout/canvas.
	scheduleCategoryRefresh()
end)
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	if MOBILE_DEVICE then task.defer(refreshMobileCanvas) end
end)
addVipStateListener(function()
	refreshFavoritesCard()
	refreshCategoryView()
end)

end

local function sectionCard(height: number)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = Theme.Panel
	card.BackgroundTransparency = 0.24
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.Parent = Content
	card:SetAttribute("HexaContentCard", true)
	card:SetAttribute("HexaMobileBaseHeight", height)
	mkCorner(card, 16)
	mkStroke(card, Theme.Purple, 0.62, 1)
	return card
end

-- Categoría independiente para todos los atajos. Los botones originales ya no
-- muestran keybinds a su lado: aquí se centralizan los atajos de funciones de
-- movimiento, combate, visuales, teletransporte y jugador.
KeybindManager = {
	Card = sectionCard(96),
	Rows = 0,
	Bindings = {},
	Buttons = {},
	Targets = {},
	Capturing = nil,
	ReadyAt = 0,
}
KeybindManager.Card.LayoutOrder = 95
KeybindManager.Card:SetAttribute("HexaCategoryOverride", "KEYBINDS")
KeybindManager.Card:SetAttribute("HexaDesktopOnly", true)
sectionTitle(KeybindManager.Card, "KEYBINDS", UDim2.new(0, 16, 0, 14))

function KeybindManager:IsEligible(targetButton)
	if MOBILE_DEVICE then return false end
	if not targetButton or not targetButton.Parent then return false end
	if targetButton:GetAttribute("IsToggle") ~= true then return false end
	if targetButton:GetAttribute("HexaNoKeybind") == true then return false end
	local card = targetButton.Parent
	while card and card.Parent and card:GetAttribute("HexaContentCard") ~= true do card = card.Parent end
	if not card then return false end
	local category = CategoryUI:GetCardCategory(card)
	return category == "MOVEMENT" or category == "COMBAT" or category == "VISUALS"
		or category == "TELEPORT" or category == "PLAYER"
end

function KeybindManager:FormatBinding(binding)
	if typeof(binding) ~= "EnumItem" then return "SIN TECLA" end
	if binding.EnumType == Enum.UserInputType then
		if binding == Enum.UserInputType.MouseButton1 then return "CLIC IZQ." end
		if binding == Enum.UserInputType.MouseButton2 then return "CLIC DER." end
		if binding == Enum.UserInputType.MouseButton3 then return "CLIC CENTRAL" end
	end
	return binding.Name
end

function KeybindManager:RefreshButton(id)
	local keyButton = self.Buttons[id]
	local target = self.Targets[id]
	if not keyButton or not target then return end
	local label = tostring(target:GetAttribute("BaseText") or target.Text or "FUNCIÓN")
	keyButton.Text = label .. "  •  " .. self:FormatBinding(self.Bindings[id])
	keyButton:SetAttribute("BaseText", keyButton.Text)
end

function KeybindManager:FindBindingOwner(id, binding)
	if typeof(binding) ~= "EnumItem" then return nil end
	for otherId, otherBinding in pairs(self.Bindings) do
		if otherId ~= id and typeof(otherBinding) == "EnumItem" and otherBinding == binding then
			return otherId
		end
	end
	return nil
end

function KeybindManager:SetBinding(id, binding, silentDuplicate)
	local target = self.Targets[id]
	if target and target:GetAttribute("HexaVipOnly") == true and not HEXA_IS_VIP then
		return false, "vip"
	end

	local ownerId = self:FindBindingOwner(id, binding)
	if ownerId then
		if not silentDuplicate then
			local owner = self.Targets[ownerId]
			local ownerLabel = tostring(owner and (owner:GetAttribute("BaseText") or owner.Text) or "OTRA FUNCIÓN")
			local keyLabel = self:FormatBinding(binding)
			showSystemNotification(
				"KEYBIND REPETIDO",
				keyLabel .. " ya está asignada a " .. ownerLabel .. ". Elige otra tecla.",
				"DUPLICATE KEYBIND",
				keyLabel .. " is already assigned to " .. ownerLabel .. ". Choose another key."
			)
		end
		return false, "duplicate"
	end

	self.Bindings[id] = binding
	self:RefreshButton(id)
	return true
end

function KeybindManager:DecodeBinding(kind, name)
	local enumType = kind == "KeyCode" and Enum.KeyCode or Enum.UserInputType
	for _, item in ipairs(enumType:GetEnumItems()) do
		if item.Name == name then return item end
	end
	return nil
end

function KeybindManager:RegisterToggleButton(targetButton)
	if not self:IsEligible(targetButton) then return end
	local id = targetButton:GetAttribute("HexaConfigId")
	if type(id) ~= "string" or self.Targets[id] then return end
	self.Rows += 1
	self.Targets[id] = targetButton

	local y = 44 + (self.Rows - 1) * 46
	local keyButton = neonButton(self.Card, "", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, y))
	keyButton:SetAttribute("HexaNoFavorite", true)
	keyButton:SetAttribute("HexaNoTranslate", true)
	keyButton.TextXAlignment = Enum.TextXAlignment.Left
	local pad = keyButton:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.Parent = keyButton
	self.Buttons[id] = keyButton
	self.Card.Size = UDim2.new(1, 0, 0, math.max(96, y + 50))
	self.Card:SetAttribute("HexaMobileBaseHeight", self.Card.Size.Y.Offset)
	if targetButton:GetAttribute("HexaVipOnly") == true then
		keyButton:SetAttribute("HexaVipKeybind", true)
		markVipControl(keyButton)
	end
	self:RefreshButton(id)

	keyButton.MouseButton1Click:Connect(function()
		if MOBILE_DEVICE or self.Capturing then return end
		if targetButton:GetAttribute("HexaVipOnly") == true and not requireVip() then return end
		self.Capturing = id
		self.ReadyAt = os.clock() + 0.12
		local label = tostring(targetButton:GetAttribute("BaseText") or targetButton.Text or "FUNCIÓN")
		keyButton.Text = label .. "  •  PRESIONA UNA TECLA..."
	end)

	if ConfigManager.PendingKeybinds and ConfigManager.PendingKeybinds[id] then
		local packed = ConfigManager.PendingKeybinds[id]
		task.defer(function()
			if packed and packed.kind and packed.name then
				local binding = self:DecodeBinding(packed.kind, packed.name)
				if binding then self:SetBinding(id, binding, true) end
			end
		end)
	end
end

function KeybindManager:Serialize()
	local result = {}
	for id, binding in pairs(self.Bindings) do
		local target = self.Targets[id]
		local allowed = not target or target:GetAttribute("HexaVipOnly") ~= true or HEXA_IS_VIP
		if allowed and typeof(binding) == "EnumItem" then
			result[id] = {kind = binding.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType", name = binding.Name}
		end
	end
	return result
end

function KeybindManager:LoadSerialized(data)
	if type(data) ~= "table" then return end
	for id, packed in pairs(data) do
		if type(packed) == "table" and type(packed.kind) == "string" and type(packed.name) == "string" then
			local binding = self:DecodeBinding(packed.kind, packed.name)
			if binding then self:SetBinding(id, binding, true) end
		end
	end
end

addVipStateListener(function(isVip)
	if isVip then return end
	if KeybindManager.Capturing then
		local target = KeybindManager.Targets[KeybindManager.Capturing]
		if target and target:GetAttribute("HexaVipOnly") == true then KeybindManager.Capturing = nil end
	end
	for id, target in pairs(KeybindManager.Targets) do
		if target and target:GetAttribute("HexaVipOnly") == true then
			KeybindManager.Bindings[id] = nil
			KeybindManager:RefreshButton(id)
		end
	end
end)

AllSliders.TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
	if MOBILE_DEVICE then KeybindManager.Capturing = nil; return end
	if UserInputService:GetFocusedTextBox() then return end
	if KeybindManager.Capturing then
		if os.clock() < KeybindManager.ReadyAt then return end
		local id = KeybindManager.Capturing
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
				KeybindManager:SetBinding(id, nil)
				KeybindManager.Capturing = nil
			else
				local accepted, reason = KeybindManager:SetBinding(id, input.KeyCode)
				if accepted then
					KeybindManager.Capturing = nil
				elseif reason == "duplicate" then
					KeybindManager.ReadyAt = os.clock() + 0.18
					local target = KeybindManager.Targets[id]
					local label = tostring(target and (target:GetAttribute("BaseText") or target.Text) or "FUNCIÓN")
					local button = KeybindManager.Buttons[id]
					if button then button.Text = label .. "  •  " .. (Lang.Current == "EN" and "PRESS ANOTHER KEY..." or "PRESIONA OTRA TECLA...") end
				else
					KeybindManager.Capturing = nil
				end
			end
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			local accepted, reason = KeybindManager:SetBinding(id, input.UserInputType)
			if accepted then
				KeybindManager.Capturing = nil
			elseif reason == "duplicate" then
				KeybindManager.ReadyAt = os.clock() + 0.18
				local target = KeybindManager.Targets[id]
				local label = tostring(target and (target:GetAttribute("BaseText") or target.Text) or "FUNCIÓN")
				local button = KeybindManager.Buttons[id]
				if button then button.Text = label .. "  •  " .. (Lang.Current == "EN" and "PRESS ANOTHER KEY..." or "PRESIONA OTRA TECLA...") end
			else
				KeybindManager.Capturing = nil
			end
			return
		end
		return
	end
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3 then
		local point = input.Position
		local pos, size = MainFrame.AbsolutePosition, MainFrame.AbsoluteSize
		if MainFrame.Visible and point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y then
			return
		end
	end
	for id, binding in pairs(KeybindManager.Bindings) do
		local matched = false
		if typeof(binding) == "EnumItem" then
			if binding.EnumType == Enum.KeyCode then matched = input.KeyCode == binding
			elseif binding.EnumType == Enum.UserInputType then matched = input.UserInputType == binding end
		end
		if matched then
			local target = KeybindManager.Targets[id]
			if target and target.Parent and not (target:GetAttribute("HexaVipOnly") == true and not HEXA_IS_VIP) then
				ConfigManager:ActivateToggle(target)
			end
		end
	end
end))

-- Categoría exclusiva de CELULAR para construir un HUD flotante a gusto del
-- usuario. Cada opción solo controla la visibilidad del botón flotante; el botón
-- flotante ejecuta exactamente el toggle original mediante ConfigManager.
FloatingButtonManager = {
	Card = sectionCard(96),
	Rows = 0,
	Targets = {},
	Entries = {},
	FloatingCount = 0,
	DragEntry = nil,
	DragInput = nil,
	DragStart = nil,
	DragPosition = nil,
	DragMoved = false,
}
FloatingButtonManager.Card.LayoutOrder = 96
FloatingButtonManager.Card:SetAttribute("HexaCategoryOverride", "FLOATING")
FloatingButtonManager.Card:SetAttribute("HexaMobileOnly", true)
sectionTitle(FloatingButtonManager.Card, "BOTONES FLOTANTES", UDim2.new(0, 16, 0, 14))

function FloatingButtonManager:IsEligible(targetButton)
	if not targetButton or not targetButton.Parent then return false end
	if targetButton:GetAttribute("IsToggle") ~= true then return false end
	if targetButton:GetAttribute("HexaNoFloating") == true then return false end
	if targetButton:GetAttribute("HexaDesktopOnly") == true then return false end
	local card = targetButton.Parent
	while card and card.Parent and card:GetAttribute("HexaContentCard") ~= true do card = card.Parent end
	if not card or card:GetAttribute("HexaDesktopOnly") == true then return false end
	local category = CategoryUI:GetCardCategory(card)
	return category == "MOVEMENT" or category == "COMBAT" or category == "VISUALS"
		or category == "TELEPORT" or category == "PLAYER"
end

function FloatingButtonManager:AllocateRow()
	self.Rows += 1
	local y = 44 + (self.Rows - 1) * 46
	self.Card.Size = UDim2.new(1, 0, 0, math.max(96, y + 50))
	self.Card:SetAttribute("HexaMobileBaseHeight", self.Card.Size.Y.Offset)
	return y
end

function FloatingButtonManager:CreateSpecialOption(label)
	local option = createToggleButton(self.Card, label, UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, self:AllocateRow()))
	option:SetAttribute("HexaNoKeybind", true)
	option:SetAttribute("HexaNoFloating", true)
	option:SetAttribute("HexaNoFavorite", true)
	-- Se actualiza manualmente desde RefreshEntry para respetar dispositivo + idioma.
	option:SetAttribute("HexaNoTranslate", true)
	return option
end

function FloatingButtonManager:GetTargetLabel(target)
	-- Usa primero el texto específico del dispositivo. Esto evita que los
	-- controles flotantes de móvil conserven nombres creados para PC.
	local devicePrefix = MOBILE_DEVICE and "HexaDeviceMobile" or "HexaDeviceDesktop"
	local languageSuffix = Lang.Current == "EN" and "EN" or "ES"
	local deviceText = target:GetAttribute(devicePrefix .. languageSuffix)
	if typeof(deviceText) == "string" and deviceText ~= "" then
		return deviceText
	end

	local spanish = target:GetAttribute("HexaSpanishBaseText")
		or target:GetAttribute("BaseText")
		or target.Text
		or "FUNCIÓN"
	spanish = tostring(spanish)
	return Lang.Current == "EN" and Lang.ToEnglish(spanish) or spanish
end

function FloatingButtonManager:GetSpanishTargetLabel(target)
	local deviceText = target:GetAttribute(MOBILE_DEVICE and "HexaDeviceMobileES" or "HexaDeviceDesktopES")
	if typeof(deviceText) == "string" and deviceText ~= "" then
		return deviceText
	end
	return tostring(target:GetAttribute("HexaSpanishBaseText") or target:GetAttribute("BaseText") or target.Text or "FUNCIÓN")
end

function FloatingButtonManager:DefaultPosition(index)
	local slot = (index - 1) % 7
	local column = math.floor((index - 1) / 7)
	local rightSide = column % 2 == 0
	local xOffset = 74 + math.floor(column / 2) * 132
	local yScale = 0.28 + slot * 0.085
	return UDim2.new(rightSide and 1 or 0, rightSide and -xOffset or xOffset, yScale, 0)
end

function FloatingButtonManager:RefreshEntry(id)
	local entry = self.Entries[id]
	if not entry then return end
	local target = entry.Target
	local button = entry.Button
	if not target or not target.Parent or not button or not button.Parent then return end
	local active = target:GetAttribute("IsActive") == true
	local allowed = target:GetAttribute("HexaVipOnly") ~= true or HEXA_IS_VIP
	button.Visible = MOBILE_DEVICE and entry.Enabled == true and allowed
	local currentLabel = self:GetTargetLabel(target)
	button.Text = currentLabel

	-- El nombre de la opción dentro de BOTONES FLOTANTES también debe seguir
	-- el perfil/idioma actual (p. ej. Ratón -> Toque al elegir celular).
	if entry.Option and entry.Option.Parent then
		local prefix = Lang.Current == "EN" and "FLOATING BUTTON: " or "BOTÓN FLOTANTE: "
		local optionText = prefix .. currentLabel
		Lang.Updating[entry.Option] = true
		entry.Option.Text = optionText
		entry.Option:SetAttribute("BaseText", optionText)
		entry.Option:SetAttribute("HexaSpanishBaseText", "BOTÓN FLOTANTE: " .. self:GetSpanishTargetLabel(target))
		Lang.Updating[entry.Option] = nil
	end

	button.BackgroundColor3 = active and Color3.fromRGB(42, 42, 42) or Color3.fromRGB(12, 12, 12)
	if entry.Stroke then entry.Stroke.Transparency = active and 0 or 0.18 end
end

function FloatingButtonManager:RefreshAll()
	for id in pairs(self.Entries) do self:RefreshEntry(id) end
end

function FloatingButtonManager:IsPointerOverAny(position)
	local point = Vector2.new(position.X, position.Y)
	for _, entry in pairs(self.Entries) do
		local button = entry.Button
		if button and button.Parent and button.Visible then
			local p, size = button.AbsolutePosition, button.AbsoluteSize
			if point.X >= p.X and point.X <= p.X + size.X and point.Y >= p.Y and point.Y <= p.Y + size.Y then
				return true
			end
		end
	end
	return false
end

function FloatingButtonManager:RegisterToggleButton(targetButton)
	if not self:IsEligible(targetButton) then return end
	local id = targetButton:GetAttribute("HexaConfigId")
	if type(id) ~= "string" or self.Targets[id] then return end
	self.Targets[id] = targetButton
	self.FloatingCount += 1

	local spanishLabel = self:GetSpanishTargetLabel(targetButton)
	local option = createToggleButton(
		self.Card,
		"BOTÓN FLOTANTE: " .. spanishLabel,
		UDim2.new(1, -32, 0, 38),
		UDim2.new(0, 16, 0, self:AllocateRow())
	)
	option:SetAttribute("HexaNoKeybind", true)
	option:SetAttribute("HexaNoFloating", true)
	option:SetAttribute("HexaNoFavorite", true)

	local floatButton = Instance.new("TextButton")
	floatButton.Name = "HexaFloatingAction_" .. tostring(self.FloatingCount)
	floatButton.AnchorPoint = Vector2.new(0.5, 0.5)
	floatButton.Position = self:DefaultPosition(self.FloatingCount)
	floatButton.Size = UDim2.fromOffset(118, 46)
	floatButton.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	floatButton.BackgroundTransparency = 0.08
	floatButton.BorderSizePixel = 0
	floatButton.Text = self:GetTargetLabel(targetButton)
	floatButton.TextColor3 = Color3.fromRGB(245, 245, 245)
	floatButton.TextSize = 10
	floatButton.TextWrapped = true
	floatButton.Font = Enum.Font.GothamBold
	floatButton.AutoButtonColor = false
	floatButton.Visible = false
	floatButton.Active = true
	floatButton.ZIndex = 175
	floatButton:SetAttribute("HexaNoTranslate", true)
	floatButton.Parent = ScreenGui
	mkCorner(floatButton, 13)
	local stroke = mkStroke(floatButton, Theme.Purple, 0.18, 2)

	local entry = {
		Target = targetButton,
		Option = option,
		Button = floatButton,
		Stroke = stroke,
		Enabled = false,
	}
	self.Entries[id] = entry

	local function applyVipState()
		if targetButton:GetAttribute("HexaVipOnly") == true and option:GetAttribute("HexaVipOnly") ~= true then
			markVipControl(option)
		end
		self:RefreshEntry(id)
	end
	applyVipState()
	targetButton:GetAttributeChangedSignal("HexaVipOnly"):Connect(applyVipState)
	targetButton:GetAttributeChangedSignal("BaseText"):Connect(function() self:RefreshEntry(id) end)
	targetButton:GetAttributeChangedSignal("IsActive"):Connect(function() self:RefreshEntry(id) end)

	ConfigManager:BindToggle(option, function()
		if targetButton:GetAttribute("HexaVipOnly") == true and not requireVip() then
			entry.Enabled = false
			setActive(option, false)
			self:RefreshEntry(id)
			return
		end
		entry.Enabled = not entry.Enabled
		setActive(option, entry.Enabled)
		self:RefreshEntry(id)
	end)

	floatButton.InputBegan:Connect(function(input)
		if not MOBILE_DEVICE or not entry.Enabled then return end
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		self.DragEntry = entry
		self.DragInput = input
		self.DragStart = Vector2.new(input.Position.X, input.Position.Y)
		self.DragPosition = floatButton.Position
		self.DragMoved = false
	end)

	self:RefreshEntry(id)
end

AllSliders.TrackConnection(UserInputService.InputChanged:Connect(function(input)
	local manager = FloatingButtonManager
	local entry = manager and manager.DragEntry
	if not entry or not manager.DragInput or not manager.DragStart or not manager.DragPosition then return end
	local validMove = (manager.DragInput.UserInputType == Enum.UserInputType.Touch and input == manager.DragInput)
		or (manager.DragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
	if not validMove then return end
	local current = Vector2.new(input.Position.X, input.Position.Y)
	local delta = current - manager.DragStart
	if delta.Magnitude >= 7 then manager.DragMoved = true end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or GUI_VIEWPORT_SIZE
	local halfW, halfH = 59, 23
	local desiredX = math.clamp(manager.DragPosition.X.Scale * viewport.X + manager.DragPosition.X.Offset + delta.X, halfW + 4, viewport.X - halfW - 4)
	local desiredY = math.clamp(manager.DragPosition.Y.Scale * viewport.Y + manager.DragPosition.Y.Offset + delta.Y, halfH + 4, viewport.Y - halfH - 4)
	entry.Button.Position = UDim2.fromOffset(desiredX, desiredY)
end))

AllSliders.TrackConnection(UserInputService.InputEnded:Connect(function(input)
	local manager = FloatingButtonManager
	if not manager or input ~= manager.DragInput then return end
	local entry = manager.DragEntry
	if entry and MOBILE_DEVICE and entry.Enabled and not manager.DragMoved then
		local target = entry.Target
		if target and target.Parent then
			if target:GetAttribute("HexaVipOnly") == true and not requireVip() then
				manager:RefreshAll()
			else
				ConfigManager:ActivateToggle(target)
				task.defer(function() manager:RefreshAll() end)
			end
		end
	end
	manager.DragEntry = nil
	manager.DragInput = nil
	manager.DragStart = nil
	manager.DragPosition = nil
	manager.DragMoved = false
end))

addVipStateListener(function(isVip)
	if not isVip then
		for _, entry in pairs(FloatingButtonManager.Entries) do
			if entry.Target and entry.Target:GetAttribute("HexaVipOnly") == true then
				entry.Enabled = false
				setActive(entry.Option, false)
			end
		end
	end
	FloatingButtonManager:RefreshAll()
end)

ConfigManager.Card = sectionCard(140)
ConfigManager.Card.LayoutOrder = 72
sectionTitle(ConfigManager.Card, "CONFIGURACIÓN DE USUARIO", UDim2.new(0, 16, 0, 14))
ConfigManager.SaveButton = neonButton(ConfigManager.Card, "GUARDAR CONFIGURACIÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
ConfigManager.LoadButton = neonButton(ConfigManager.Card, "CARGAR CONFIGURACIÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
ConfigManager.SaveButton:SetAttribute("HexaNoFavorite", true)
ConfigManager.LoadButton:SetAttribute("HexaNoFavorite", true)

function ConfigManager:ShowButtonResult(button, message, baseText)
	button.Text = message
	task.delay(1.5, function()
		if button and button.Parent then
			button.Text = baseText
			button:SetAttribute("BaseText", baseText)
		end
	end)
end

ConfigManager.SaveButton.MouseButton1Click:Connect(function()
	local _, message = ConfigManager:Save()
	ConfigManager:ShowButtonResult(ConfigManager.SaveButton, message, "GUARDAR CONFIGURACIÓN")
end)
ConfigManager.LoadButton.MouseButton1Click:Connect(function()
	local _, message = ConfigManager:Load()
	ConfigManager:ShowButtonResult(ConfigManager.LoadButton, message, "CARGAR CONFIGURACIÓN")
end)

local ProfileCard = sectionCard(100)
ProfileCard.LayoutOrder = -1

local PlayerAvatar = Instance.new("ImageLabel")
PlayerAvatar.Size = UDim2.new(0, 50, 0, 50)
PlayerAvatar.AnchorPoint = Vector2.new(0.5, 0)
PlayerAvatar.Position = UDim2.new(0.5, 0, 0, 15)
PlayerAvatar.BackgroundTransparency = 1
PlayerAvatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
PlayerAvatar.Parent = ProfileCard
mkCorner(PlayerAvatar, 999)

local PlayerName = Instance.new("TextLabel")
PlayerName.BackgroundTransparency = 1
PlayerName.Size = UDim2.new(1, 0, 0, 20)
PlayerName.AnchorPoint = Vector2.new(0.5, 0)
PlayerName.Position = UDim2.new(0.5, 0, 0, 72)
PlayerName.Text = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")"
PlayerName.TextColor3 = Theme.TextMain
PlayerName.TextSize = 13
PlayerName.Font = Enum.Font.GothamBold
PlayerName.TextXAlignment = Enum.TextXAlignment.Center
PlayerName.Parent = ProfileCard

local VipProfileBadge = Instance.new("TextLabel")
VipProfileBadge.AnchorPoint = Vector2.new(1, 0)
VipProfileBadge.Position = UDim2.new(1, -12, 0, 12)
VipProfileBadge.Size = UDim2.new(0, 76, 0, 24)
VipProfileBadge.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
VipProfileBadge.BorderSizePixel = 0
VipProfileBadge.TextColor3 = Color3.fromRGB(215, 215, 215)
VipProfileBadge.TextSize = 10
VipProfileBadge.Font = Enum.Font.GothamBold
VipProfileBadge.ZIndex = 5
VipProfileBadge.Parent = ProfileCard
VipProfileBadge:SetAttribute("HexaNoTranslate", true)
mkCorner(VipProfileBadge, 8)
mkStroke(VipProfileBadge, Color3.fromRGB(75, 75, 75), 0.35, 1)

local function refreshProfileVipBadge()
	VipProfileBadge.Text = HEXA_IS_VIP and "★ VIP" or "FREE"
	VipProfileBadge.TextColor3 = HEXA_IS_VIP and Color3.fromRGB(215, 215, 215) or Color3.fromRGB(155, 155, 155)
	VipProfileBadge.BackgroundColor3 = HEXA_IS_VIP and Color3.fromRGB(22, 22, 22) or Color3.fromRGB(45, 45, 45)
end
addVipStateListener(refreshProfileVipBadge)
refreshProfileVipBadge()

local MoveCard = sectionCard(452)
MoveCard.LayoutOrder = 10
sectionTitle(MoveCard, "MOVIMIENTO Y FÍSICA", UDim2.new(0, 16, 0, 14))

local flyActive = false
local speedActive = false
local jumpActive = false
local infiniteJumpActive = false
local noclipActive = false

local currentFlySpeed = 200
local currentSpeed = 150
local currentJump = 300

local flySlider = createSlider(MoveCard, "Velocidad de vuelo", 10, 2500, currentFlySpeed, 42, function(v) currentFlySpeed = v end)
local flyButton = createToggleButton(MoveCard, "VUELO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 95))
local speedButton = createToggleButton(MoveCard, "AUMENTO DE VELOCIDAD", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 142))
local speedSlider = createSlider(MoveCard, "Velocidad al caminar", 16, 2500, currentSpeed, 191, function(v) currentSpeed = v end)
local jumpButton = createToggleButton(MoveCard, "SALTO ALTO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 244))
local jumpSlider = createSlider(MoveCard, "Potencia de salto", 50, 2500, currentJump, 293, function(v) currentJump = v end)
local infiniteJumpButton = createToggleButton(MoveCard, "SALTO INFINITO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 346))
local noclipButton = createToggleButton(MoveCard, "SIN COLISIÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 393))

local CombatCard = sectionCard(394)
CombatCard.LayoutOrder = 20
sectionTitle(CombatCard, "COMBATE Y PUNTERÍA", UDim2.new(0, 16, 0, 14))

local autoAimHeadActive = false
local autoAimBodyActive = false
local ignoreFriendsActive = false
local fovActive = false

-- Los aimbots ya no tienen controles de keybind incrustados en esta tarjeta.
-- Los atajos se administran desde la categoría KEYBINDS.
local maxAimDistance = 500
local fovRadius = 200

local FovCircle = Instance.new("Frame")
FovCircle.Name = "HexaFOVCircle"
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
FovCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = false
FovCircle.ZIndex = 1
FovCircle.Parent = ScreenGui
mkCorner(FovCircle, 999)
local FovStroke = mkStroke(FovCircle, Color3.fromRGB(255, 255, 255), 0.2, 1.5)

local aimDistanceSlider = createSlider(CombatCard, "Distancia máxima de puntería (3D)", 50, 2000, maxAimDistance, 38, function(v) maxAimDistance = v end)
local autoAimHeadButton = createToggleButton(CombatCard, "AIMBOT (CABEZA)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 96))
local autoAimBodyButton = createToggleButton(CombatCard, "AIMBOT (CUERPO)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 142))
-- En móvil ambos modos comparten el BOTÓN AIM FLOTANTE especial.
autoAimHeadButton:SetAttribute("HexaNoFloating", true)
autoAimBodyButton:SetAttribute("HexaNoFloating", true)
local ignoreFriendsButton = createToggleButton(CombatCard, "IGNORAR AMIGOS", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 234))
local fovButton = createToggleButton(CombatCard, "USAR CÍRCULO FOV", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 280))
local fovSlider = createSlider(CombatCard, "Radio del FOV", 30, 800, fovRadius, 326, function(v)
	fovRadius = v
	FovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
end)

-- Opción exclusiva del perfil CELULAR. El botón flotante se puede arrastrar y
-- funciona como un interruptor rápido del aim usando el último modo cabeza/cuerpo.
local MobileAim = {
	Enabled = false,
	PreferredHead = true,
	DragInput = nil,
	DragStart = nil,
	DragPosition = nil,
	DragMoved = false,
}
MobileAim.OptionButton = FloatingButtonManager:CreateSpecialOption("BOTÓN AIM FLOTANTE")
MobileAim.OptionButton.Visible = true

MobileAim.Button = Instance.new("TextButton")
MobileAim.Button.Name = "HexaMobileAimButton"
MobileAim.Button.AnchorPoint = Vector2.new(0.5, 0.5)
MobileAim.Button.Position = UDim2.new(1, -82, 0.62, 0)
MobileAim.Button.Size = UDim2.fromOffset(68, 68)
MobileAim.Button.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
MobileAim.Button.BackgroundTransparency = 0.08
MobileAim.Button.BorderSizePixel = 0
MobileAim.Button.Text = "AIM"
MobileAim.Button.TextColor3 = Color3.fromRGB(245, 245, 245)
MobileAim.Button.TextSize = 15
MobileAim.Button.Font = Enum.Font.GothamBold
MobileAim.Button.AutoButtonColor = false
MobileAim.Button.Visible = false
MobileAim.Button.Active = true
MobileAim.Button.ZIndex = 180
MobileAim.Button.Parent = ScreenGui
MobileAim.Button:SetAttribute("HexaNoTranslate", true)
mkCorner(MobileAim.Button, 34)
MobileAim.Stroke = mkStroke(MobileAim.Button, Theme.Purple, 0.15, 2)

function MobileAim:Refresh()
	local shouldShow = MOBILE_DEVICE and self.Enabled
	local aimActive = autoAimHeadActive or autoAimBodyActive
	self.Button.Visible = shouldShow
	self.Button.Text = aimActive and "AIM • ON" or "AIM"
	self.Button.BackgroundColor3 = aimActive and Color3.fromRGB(42, 42, 42) or Color3.fromRGB(12, 12, 12)
	self.Stroke.Transparency = aimActive and 0 or 0.15
end

MobileAim.Button.InputBegan:Connect(function(input)
	if not MOBILE_DEVICE or not MobileAim.Enabled then return end
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	MobileAim.DragInput = input
	MobileAim.DragStart = Vector2.new(input.Position.X, input.Position.Y)
	MobileAim.DragPosition = MobileAim.Button.Position
	MobileAim.DragMoved = false
end)

AllSliders.TrackConnection(UserInputService.InputChanged:Connect(function(input)
	if not MobileAim.DragInput or not MobileAim.DragStart or not MobileAim.DragPosition then return end
	local validMove = (MobileAim.DragInput.UserInputType == Enum.UserInputType.Touch and input == MobileAim.DragInput)
		or (MobileAim.DragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
	if not validMove then return end
	local current = Vector2.new(input.Position.X, input.Position.Y)
	local delta = current - MobileAim.DragStart
	if delta.Magnitude >= 7 then MobileAim.DragMoved = true end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or GUI_VIEWPORT_SIZE
	local half = 34
	local desiredX = math.clamp(MobileAim.DragPosition.X.Scale * viewport.X + MobileAim.DragPosition.X.Offset + delta.X, half + 4, viewport.X - half - 4)
	local desiredY = math.clamp(MobileAim.DragPosition.Y.Scale * viewport.Y + MobileAim.DragPosition.Y.Offset + delta.Y, half + 4, viewport.Y - half - 4)
	MobileAim.Button.Position = UDim2.fromOffset(desiredX, desiredY)
end))

AllSliders.TrackConnection(UserInputService.InputEnded:Connect(function(input)
	if input ~= MobileAim.DragInput then return end
	if MOBILE_DEVICE and MobileAim.Enabled and not MobileAim.DragMoved then
		if autoAimHeadActive then
			ConfigManager:ActivateToggle(autoAimHeadButton)
		elseif autoAimBodyActive then
			ConfigManager:ActivateToggle(autoAimBodyButton)
		elseif MobileAim.PreferredHead then
			ConfigManager:ActivateToggle(autoAimHeadButton)
		else
			ConfigManager:ActivateToggle(autoAimBodyButton)
		end
		task.defer(function() MobileAim:Refresh() end)
	end
	MobileAim.DragInput = nil
	MobileAim.DragStart = nil
	MobileAim.DragPosition = nil
	MobileAim.DragMoved = false
end))

local EspCard = sectionCard(204)
EspCard.LayoutOrder = 30
sectionTitle(EspCard, "VISUALES (ESP)", UDim2.new(0, 16, 0, 14))

local espSkeletonActive = false
local espLinesActive = false
local maxEspDistance = 2000

local espSkeletonButton = createToggleButton(EspCard, "ESQUELETO ESP", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
local espLinesButton = createToggleButton(EspCard, "LÍNEAS ESP (TRAZADORES)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
local espDistanceSlider = createSlider(EspCard, "Distancia máxima del ESP", 50, 5000, maxEspDistance, 136, function(v) maxEspDistance = v end)

local EspContainer = Instance.new("Folder")
EspContainer.Name = "HexaESPLines"
EspContainer.Parent = ScreenGui
local espCache = {}

local function getEspFrame(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = 0
	f.Parent = EspContainer
	return f
end

local function drawUILine(frame, p1, p2)
	local center = (p1 + p2) / 2
	local distance = (p2 - p1).Magnitude
	local angle = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
	frame.Position = UDim2.new(0, center.X, 0, center.Y)
	frame.Size = UDim2.new(0, distance, 0, 1)
	frame.Rotation = math.deg(angle)
end

local r15Bones = {
	{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}
local r6Bones = {
	{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
	{"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local TpCard = sectionCard(340)
TpCard.LayoutOrder = 40
local TpTitle = sectionTitle(TpCard, "HERRAMIENTAS DEL JUGADOR", UDim2.new(0, 16, 0, 14))

local selectedTargetPlayer: Player? = nil
local DropdownButton = neonButton(TpCard, "Seleccionar jugador: [ninguno]", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
DropdownButton.TextXAlignment = Enum.TextXAlignment.Left
DropdownButton.Text = "  Seleccionar jugador: [ninguno]"
DropdownButton:SetAttribute("HexaNoFavorite", true)

local DropdownList = Instance.new("ScrollingFrame")
DropdownList.Name = "HexaPlayerDropdown"
DropdownList.Visible = false
DropdownList.Position = UDim2.new(0, 16, 0, 88)
DropdownList.Size = UDim2.new(1, -32, 0, 180)
DropdownList.BackgroundColor3 = Theme.Panel
DropdownList.BackgroundTransparency = 0.12
DropdownList.BorderSizePixel = 0
DropdownList.ScrollBarThickness = 4
DropdownList.ScrollBarImageColor3 = Theme.Accent
DropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownList.ClipsDescendants = true
DropdownList.ZIndex = 20
DropdownList.Parent = TpCard
mkCorner(DropdownList, 12)
mkStroke(DropdownList, Theme.Accent, 0.6, 1)

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = DropdownList

local GotoButton = neonButton(TpCard, "IR AL JUGADOR", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))

local CommunityCard = sectionCard(96)
CommunityCard.LayoutOrder = 90
sectionTitle(CommunityCard, "COMUNIDAD", UDim2.new(0, 16, 0, 14))
local DiscordButton = neonButton(CommunityCard, "UNIRSE AL DISCORD (COPIAR ENLACE)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))

local AimHighlight = Instance.new("Highlight")
AimHighlight.Name = "HexaAimHighlight"
AimHighlight.FillColor = Color3.fromRGB(255, 255, 255)
AimHighlight.FillTransparency = 0.65
AimHighlight.OutlineColor = Theme.Purple
AimHighlight.OutlineTransparency = 0.02
AimHighlight.Parent = ScreenGui 

local ConfirmFrame = Instance.new("Frame")
ConfirmFrame.Visible = false
ConfirmFrame.AnchorPoint = Vector2.new(0.5, 0.5)
ConfirmFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
ConfirmFrame.Size = UDim2.new(0, 0, 0, 0)
ConfirmFrame.BackgroundColor3 = Theme.BG
ConfirmFrame.BorderSizePixel = 0
ConfirmFrame.ClipsDescendants = true
ConfirmFrame.ZIndex = 50
ConfirmFrame.Parent = ScreenGui
mkCorner(ConfirmFrame, 16)
mkStroke(ConfirmFrame, Theme.Purple, 0.05, 2)

local ConfirmTitle = Instance.new("TextLabel")
ConfirmTitle.BackgroundTransparency = 1
ConfirmTitle.Size = UDim2.new(1, -24, 0, 42)
ConfirmTitle.Position = UDim2.new(0, 12, 0, 18)
ConfirmTitle.Text = "¿CERRAR H3X4 X?"
ConfirmTitle.TextColor3 = Theme.TextMain
ConfirmTitle.TextSize = 15
ConfirmTitle.Font = Enum.Font.GothamBold
ConfirmTitle.ZIndex = 51
ConfirmTitle.Parent = ConfirmFrame

local YesBtn = neonButton(ConfirmFrame, "SÍ", UDim2.new(0, 110, 0, 38), UDim2.new(0.5, -116, 1, -56), 51)
YesBtn.BackgroundColor3 = Theme.PurpleDeep
YesBtn.TextColor3 = BUTTON_TEXT_COLOR

local NoBtn = neonButton(ConfirmFrame, "CANCELAR", UDim2.new(0, 110, 0, 38), UDim2.new(0.5, 6, 1, -56), 51)
NoBtn.BackgroundColor3 = Theme.PurpleDeep
NoBtn.TextColor3 = BUTTON_TEXT_COLOR

local Tutorial = {}
function Tutorial.getTargetSize()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or GUI_VIEWPORT_SIZE
	return UDim2.fromOffset(
		math.min(430, math.max(280, viewport.X - 24)),
		math.min(520, math.max(310, viewport.Y - 24))
	)
end

Tutorial.Frame = Instance.new("Frame")
Tutorial.Frame.Name = "HexaTutorialFrame"
Tutorial.Frame.Visible = false
Tutorial.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Tutorial.Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
Tutorial.Frame.Size = UDim2.new(0, 0, 0, 0)
Tutorial.Frame.BackgroundColor3 = Theme.BG
Tutorial.Frame.BackgroundTransparency = 0.16
Tutorial.Frame.BorderSizePixel = 0
Tutorial.Frame.ClipsDescendants = true
Tutorial.Frame.ZIndex = 60
Tutorial.Frame.Parent = ScreenGui
mkCorner(Tutorial.Frame, 16)
mkStroke(Tutorial.Frame, Theme.Purple, 0.24, 2)

Tutorial.Header = Instance.new("Frame")
Tutorial.Header.BackgroundColor3 = Theme.Panel
Tutorial.Header.BackgroundTransparency = 0.24
Tutorial.Header.BorderSizePixel = 0
Tutorial.Header.Size = UDim2.new(1, 0, 0, 52)
Tutorial.Header.ZIndex = 61
Tutorial.Header.Parent = Tutorial.Frame

Tutorial.Title = Instance.new("TextLabel")
Tutorial.Title.BackgroundTransparency = 1
Tutorial.Title.Size = UDim2.new(1, -24, 1, 0)
Tutorial.Title.Position = UDim2.new(0, 12, 0, 0)
Tutorial.Title.Text = "H3X4 X - TUTORIAL"
Tutorial.Title.TextColor3 = Theme.TextMain
Tutorial.Title.TextSize = 16
Tutorial.Title.Font = Enum.Font.GothamBold
Tutorial.Title.TextXAlignment = Enum.TextXAlignment.Left
Tutorial.Title.ZIndex = 62
Tutorial.Title.Parent = Tutorial.Header
makeDraggable(Tutorial.Frame, Tutorial.Title)

Tutorial.Scroll = Instance.new("ScrollingFrame")
Tutorial.Scroll.BackgroundColor3 = Theme.Panel
Tutorial.Scroll.BackgroundTransparency = 0.30
Tutorial.Scroll.BorderSizePixel = 0
Tutorial.Scroll.Position = UDim2.new(0, 14, 0, 64)
Tutorial.Scroll.Size = UDim2.new(1, -28, 1, -126)
Tutorial.Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Tutorial.Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Tutorial.Scroll.ScrollBarThickness = MOBILE_DEVICE and 6 or 4
Tutorial.Scroll.ScrollBarImageColor3 = Theme.Purple
Tutorial.Scroll.ScrollBarImageTransparency = 0.30
Tutorial.Scroll.ZIndex = 61
Tutorial.Scroll.Parent = Tutorial.Frame
mkCorner(Tutorial.Scroll, 12)
mkStroke(Tutorial.Scroll, Theme.Purple, 0.60, 1)

Tutorial.Text = Instance.new("TextLabel")
Tutorial.Text.BackgroundTransparency = 1
Tutorial.Text.Position = UDim2.new(0, 12, 0, 12)
Tutorial.Text.Size = UDim2.new(1, -24, 0, 0)
Tutorial.Text.AutomaticSize = Enum.AutomaticSize.Y
Tutorial.Text.Text = [[PUNTERÍA AUTOMÁTICA
Activa la puntería a la cabeza o al cuerpo. Configura los atajos desde KEYBINDS y asígnales una tecla o un botón del ratón.

PERSISTENCIA DE OBJETIVO
Mantiene el objetivo actual mientras siga siendo válido para evitar cambios de enemigo innecesarios.

CÍRCULO FOV
Limita el área en la que se seleccionan objetivos. Activa USAR CÍRCULO FOV y ajusta su radio.

MOVIMIENTO Y FÍSICA
Controla vuelo, velocidad, salto, gravedad, caminata aérea y colisión. Durante el vuelo usa W/A/S/D, Espacio para subir y Ctrl izquierdo para bajar.

CÁMARA LIBRE
Mantén el botón derecho del ratón para mirar. Usa W/A/S/D para moverte; Espacio/E para subir y Ctrl/Q para bajar.

TELETRANSPORTE
Selecciona un jugador y pulsa IR AL JUGADOR. TELETRANSPORTARSE AL RATÓN permite elegir el destino haciendo clic fuera de la interfaz.

FUNCIONES VIP
Las opciones que muestran la etiqueta VIP requieren acceso VIP activo.]]
registerDeviceText(Tutorial.Text,
[[PUNTERÍA AUTOMÁTICA
Activa la puntería a la cabeza o al cuerpo. Configura los atajos desde KEYBINDS y asígnales una tecla o un botón del ratón.

PERSISTENCIA DE OBJETIVO
Mantiene el objetivo actual mientras siga siendo válido para evitar cambios de enemigo innecesarios.

CÍRCULO FOV
Limita el área en la que se seleccionan objetivos. Activa USAR CÍRCULO FOV y ajusta su radio.

MOVIMIENTO Y FÍSICA
Controla vuelo, velocidad, salto, gravedad, caminata aérea y colisión. Durante el vuelo usa W/A/S/D, Espacio para subir y Ctrl izquierdo para bajar.

CÁMARA LIBRE
Mantén el botón derecho del ratón para mirar. Usa W/A/S/D para moverte; Espacio/E para subir y Ctrl/Q para bajar.

TELETRANSPORTE
Selecciona un jugador y pulsa IR AL JUGADOR. TELETRANSPORTARSE AL RATÓN permite elegir el destino haciendo clic fuera de la interfaz.

FUNCIONES VIP
Las opciones que muestran la etiqueta VIP requieren acceso VIP activo.]],
[[PUNTERÍA AUTOMÁTICA
Activa la puntería a la cabeza o al cuerpo. Puedes usar BOTÓN AIM FLOTANTE como acceso táctil rápido; no necesitas configurar teclas.

BOTONES FLOTANTES
Activa desde esta categoría únicamente los accesos que quieras tener sobre la pantalla. Puedes arrastrar cada botón sin activar la función accidentalmente.

PERSISTENCIA DE OBJETIVO
Mantiene el objetivo actual mientras siga siendo válido para evitar cambios de enemigo innecesarios.

CÍRCULO FOV
Limita el área en la que se seleccionan objetivos. Activa USAR CÍRCULO FOV y ajusta su radio.

MOVIMIENTO Y FÍSICA
Controla vuelo, velocidad, salto, gravedad, caminata aérea y colisión. Durante el vuelo usa el joystick normal y los botones SUBIR/BAJAR.

CÁMARA LIBRE
Arrastra el dedo por el lado derecho de la pantalla para mirar, usa el joystick para moverte y los botones SUBIR/BAJAR para cambiar de altura.

TELETRANSPORTE
Selecciona un jugador y pulsa IR AL JUGADOR. TELETRANSPORTARSE AL TOQUE permite elegir el destino tocando la pantalla fuera de la interfaz.

FUNCIONES VIP
Las opciones que muestran la etiqueta VIP requieren acceso VIP activo.]],
[[AUTO AIM
Aim at the head or body. Configure shortcuts from KEYBINDS and assign a keyboard key or mouse button.

TARGET PERSISTENCE
Keeps the current target while it remains valid to prevent unnecessary target switching.

FOV CIRCLE
Limits the area where targets are selected. Enable USE FOV CIRCLE and adjust its radius.

MOVEMENT AND PHYSICS
Controls flight, speed, jumping, gravity, air walk and collision. While flying use W/A/S/D, Space to go up and Left Ctrl to go down.

FREE CAMERA
Hold the right mouse button to look around. Use W/A/S/D to move; Space/E to go up and Ctrl/Q to go down.

TELEPORT
Select a player and press GO TO PLAYER. TELEPORT TO MOUSE lets you choose the destination by clicking outside the interface.

VIP FEATURES
Options displaying the VIP label require active VIP access.]],
[[AUTO AIM
Aim at the head or body. You can use FLOATING AIM BUTTON as a quick touch control; no keyboard binds are needed.

FLOATING BUTTONS
Enable only the shortcuts you want on screen from this category. You can drag each button without accidentally activating the feature.

TARGET PERSISTENCE
Keeps the current target while it remains valid to prevent unnecessary target switching.

FOV CIRCLE
Limits the area where targets are selected. Enable USE FOV CIRCLE and adjust its radius.

MOVEMENT AND PHYSICS
Controls flight, speed, jumping, gravity, air walk and collision. While flying use the normal joystick and the UP/DOWN buttons.

FREE CAMERA
Drag your finger on the right side of the screen to look around, use the joystick to move and the UP/DOWN buttons to change height.

TELEPORT
Select a player and press GO TO PLAYER. TELEPORT TO TOUCH lets you choose the destination by touching the screen outside the interface.

VIP FEATURES
Options displaying the VIP label require active VIP access.]])
Tutorial.Text.TextColor3 = Theme.TextMain
Tutorial.Text.TextSize = MOBILE_DEVICE and 12 or 13
Tutorial.Text.TextWrapped = true
Tutorial.Text.TextXAlignment = Enum.TextXAlignment.Left
Tutorial.Text.TextYAlignment = Enum.TextYAlignment.Top
Tutorial.Text.Font = Enum.Font.GothamMedium
Tutorial.Text.ZIndex = 62
Tutorial.Text.Parent = Tutorial.Scroll

Tutorial.CloseButton = neonButton(Tutorial.Frame, "ENTENDIDO", UDim2.new(0, 140, 0, 38), UDim2.new(0.5, -70, 1, -50), 62)
Tutorial.CloseButton.BackgroundColor3 = Theme.Panel2
Tutorial.CloseButton.TextColor3 = BUTTON_TEXT_COLOR
Tutorial.CloseButton:SetAttribute("HexaNoFavorite", true)

do
local function updateResponsiveLayout()
	GUI_VIEWPORT_SIZE = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or GUI_VIEWPORT_SIZE
	MAIN_SIZE = calculateMainSize()
	KEY_SIZE = calculateKeySize()
	VipNotification.Size = UDim2.fromOffset(math.min(360, math.max(230, GUI_VIEWPORT_SIZE.X - 16)), 58)
	if MainFrame.Visible and MainFrame.Size.X.Offset > 0 then MainFrame.Size = MAIN_SIZE end
	if KeyFrame.Visible and KeyFrame.Size.X.Offset > 0 then KeyFrame.Size = KEY_SIZE end
	if Tutorial.Frame.Visible and Tutorial.Frame.Size.X.Offset > 0 then Tutorial.Frame.Size = Tutorial.getTargetSize() end
end

local function bindViewportResize()
	if AllSliders.ViewportSizeConnection then
		AllSliders.ViewportSizeConnection:Disconnect()
		AllSliders.ViewportSizeConnection = nil
	end
	local camera = workspace.CurrentCamera
	if not camera then return end
	AllSliders.ViewportSizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end
bindViewportResize()
AllSliders.CurrentCameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(function()
		bindViewportResize()
		updateResponsiveLayout()
	end)
end)
ScreenGui.Destroying:Connect(function()
	if AllSliders.ViewportSizeConnection then AllSliders.ViewportSizeConnection:Disconnect() end
	if AllSliders.CurrentCameraConnection then AllSliders.CurrentCameraConnection:Disconnect() end
end)
end

local Runtime = {
	flyConn = nil,
	loopConn = nil,
	renderConn = nil,
	espConn = nil,
	charAddedConn = nil,
	flyBV = nil,
	flyBG = nil,
	noclipCache = {},
	speedBase = DEFAULT_WALK_SPEED,
	jumpBase = DEFAULT_JUMP_POWER,
	mobileAimTouchActive = false,
	mobileAimTouchInput = nil,
	mobileShotUntil = 0,
	syntheticRapidActivation = false,
	MobileToolConnections = setmetatable({}, {__mode = "k"}),
	character = nil,
	humanoid = nil,
	root = nil,
	lastNoclipScan = 0,
	lastNoclipUpdate = 0,
	lastBaseEspRender = 0,
	baseEspVisible = false,
	lastAimScan = 0,
	cachedAimCandidate = nil,
	cachedResolvedAimTarget = nil,
	cachedAimAtHead = nil,
	lastAimRender = 0,
	aimWasActive = false,
	currentAimWorldPosition = nil,
	currentAimSmoothing = false,
	weaponLockEnabled = false,
	weaponLockInputCaptured = false,
	weaponLockSavedMouseBehavior = nil,
	weaponLockSavedMouseIconEnabled = nil,
	weaponLockSavedMouseDeltaSensitivity = nil,
	weaponLockReleaseUntil = 0,
	friendCache = setmetatable({}, {__mode = "k"}),
	wallRaycastParams = RaycastParams.new(),
	wallFilterCharacter = nil,
	wallFilterCamera = nil,
	playerSnapshot = Players:GetPlayers(),
}
Runtime.wallRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
Runtime.wallRaycastParams.IgnoreWater = true

AllSliders.TrackConnection(Players.PlayerAdded:Connect(function(player)
	table.insert(Runtime.playerSnapshot, player)
end))
AllSliders.TrackConnection(Players.PlayerRemoving:Connect(function(player)
	for index = #Runtime.playerSnapshot, 1, -1 do
		if Runtime.playerSnapshot[index] == player then
			table.remove(Runtime.playerSnapshot, index)
			break
		end
	end
	Runtime.friendCache[player] = nil
end))

local function getCharacterData()
	local char = LocalPlayer.Character
	if not char then
		Runtime.character, Runtime.humanoid, Runtime.root = nil, nil, nil
		return nil, nil, nil
	end
	if Runtime.character ~= char then
		Runtime.character = char
		Runtime.humanoid = nil
		Runtime.root = nil
	end
	if not Runtime.humanoid or Runtime.humanoid.Parent ~= char then
		Runtime.humanoid = char:FindFirstChildOfClass("Humanoid")
	end
	if not Runtime.root or Runtime.root.Parent ~= char then
		Runtime.root = char:FindFirstChild("HumanoidRootPart")
	end
	return char, Runtime.humanoid, Runtime.root
end


local function bindMobileShotTool(tool)
	if not tool:IsA("Tool") or Runtime.MobileToolConnections[tool] then return end
	Runtime.MobileToolConnections[tool] = AllSliders.TrackConnection(tool.Activated:Connect(function()
		if MOBILE_DEVICE and not Runtime.syntheticRapidActivation then
			Runtime.mobileShotUntil = os.clock() + 0.24
		end
	end))
end

local function scanMobileTools(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do bindMobileShotTool(child) end
	AllSliders.TrackConnection(container.ChildAdded:Connect(bindMobileShotTool))
end

do
	AllSliders.TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
		if not MOBILE_DEVICE or processed or input.UserInputType ~= Enum.UserInputType.Touch then return end
		local camera = workspace.CurrentCamera
		if camera and input.Position.X >= camera.ViewportSize.X * 0.45 then
			Runtime.mobileAimTouchInput = input
			Runtime.mobileAimTouchActive = true
		end
	end))
	AllSliders.TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if input == Runtime.mobileAimTouchInput then
			Runtime.mobileAimTouchInput = nil
			Runtime.mobileAimTouchActive = false
		end
	end))
	scanMobileTools(LocalPlayer:FindFirstChildOfClass("Backpack"))
	scanMobileTools(LocalPlayer.Character)
	AllSliders.TrackConnection(LocalPlayer.CharacterAdded:Connect(function(character) scanMobileTools(character) end))
end

local HexaSharedTargetFilters = {
	TeamCheck = false,
	WallCheck = false,
	AimSmoothing = false,
	TargetPrediction = false,
	TargetSwitchDelay = false,
	TargetPersistence = false,
	TargetSwitchDelaySeconds = 0.35,
	SmoothingFactor = 5,
	PredictionFactor = 0.12,
	Listeners = {},
}

function Runtime.isIgnoredFriend(player)
	local cached = Runtime.friendCache[player]
	if cached ~= nil then return cached end
	local ok, result = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
	if ok then
		Runtime.friendCache[player] = result == true
		return result == true
	end
	return false
end

local function passesTeamCheck(player: Player): boolean
	-- Nunca permitir que una función dirigida a otros jugadores seleccione al usuario local.
	if not player or player == LocalPlayer or player.Parent ~= Players then return false end
	if not HexaSharedTargetFilters.TeamCheck then return true end

	-- Los objetos Team son la comprobación principal, incluso si el juego usa Neutral.
	local localTeam = LocalPlayer.Team
	local targetTeam = player.Team
	if localTeam ~= nil and targetTeam ~= nil then
		return targetTeam ~= localTeam
	end

	-- Respaldo para juegos que solamente configuran TeamColor.
	if not LocalPlayer.Neutral and not player.Neutral then
		local localColor = LocalPlayer.TeamColor
		local targetColor = player.TeamColor
		if localColor ~= nil and targetColor ~= nil and localColor == targetColor then
			return false
		end
	end

	return true
end

function HexaSharedTargetFilters:AllowsPlayer(player: Player?, requireAlive: boolean?): boolean
	if not passesTeamCheck(player) then return false end
	if requireAlive == false then return true end
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character ~= nil and humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

function HexaSharedTargetFilters:AddListener(callback)
	if type(callback) == "function" then table.insert(self.Listeners, callback) end
end

function HexaSharedTargetFilters:SetTeamCheck(enabled: boolean)
	self.TeamCheck = enabled == true
	for _, callback in ipairs(self.Listeners) do
		pcall(callback, self.TeamCheck)
	end
end

local function passesWallCheck(part: BasePart?): boolean
	if not HexaSharedTargetFilters.WallCheck then return true end
	if not part or not part.Parent then return false end
	local camera = workspace.CurrentCamera
	if not camera then return false end
	local origin = camera.CFrame.Position
	local character = LocalPlayer.Character
	if Runtime.wallFilterCharacter ~= character or Runtime.wallFilterCamera ~= camera then
		Runtime.wallFilterCharacter = character
		Runtime.wallFilterCamera = camera
		Runtime.wallRaycastParams.FilterDescendantsInstances = character and {camera, character} or {camera}
	end
	local result = workspace:Raycast(origin, part.Position - origin, Runtime.wallRaycastParams)
	return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function getClosestPlayer(aimAtHead: boolean?): Player?
	local closestPlayer: Player? = nil
	local shortestDistance3D = maxAimDistance
	local shortestDistance2D = math.huge

	local _, _, root = getCharacterData()
	if not root then return nil end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local viewportCenter = cam.ViewportSize / 2

	for _, player in ipairs(Runtime.playerSnapshot) do
		if not passesTeamCheck(player) then continue end

		if ignoreFriendsActive then
			if Runtime.isIgnoredFriend(player) then continue end
		end

		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not targetRoot then continue end

		-- Body mode now chooses torso parts explicitly instead of relying on the head toggle.
		local targetPart
		if aimAtHead then
			targetPart = character:FindFirstChild("Head") or targetRoot
		else
			targetPart = character:FindFirstChild("UpperTorso")
				or character:FindFirstChild("Torso")
				or character:FindFirstChild("LowerTorso")
				or targetRoot
		end
		if not targetPart or not targetPart:IsA("BasePart") then continue end
		if not passesWallCheck(targetPart) then continue end

		local dist3D = (root.Position - targetRoot.Position).Magnitude
		if dist3D > maxAimDistance then continue end

		if fovActive then
			local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
			if onScreen and screenPos.Z > 0 then
				local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
				if dist2D <= fovRadius and dist2D < shortestDistance2D then
					shortestDistance2D = dist2D
					closestPlayer = player
				end
			end
		elseif dist3D < shortestDistance3D then
			shortestDistance3D = dist3D
			closestPlayer = player
		end
	end

	return closestPlayer
end

Runtime.aimSwitchTarget = nil
Runtime.aimSwitchCandidate = nil
Runtime.aimSwitchCandidateSince = 0

function Runtime.captureWeaponLockInput()
	if MOBILE_DEVICE or not Runtime.weaponLockEnabled or Runtime.weaponLockInputCaptured then return end
	Runtime.weaponLockInputCaptured = true
	pcall(function() Runtime.weaponLockSavedMouseBehavior = UserInputService.MouseBehavior end)
	pcall(function() Runtime.weaponLockSavedMouseIconEnabled = UserInputService.MouseIconEnabled end)
	pcall(function() Runtime.weaponLockSavedMouseDeltaSensitivity = UserInputService.MouseDeltaSensitivity end)
end

function Runtime.enforceWeaponLockInput()
	if MOBILE_DEVICE or not Runtime.weaponLockEnabled or not Runtime.weaponLockInputCaptured then return end
	pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)
	pcall(function() UserInputService.MouseIconEnabled = false end)
	pcall(function() UserInputService.MouseDeltaSensitivity = 0 end)
end

function Runtime.releaseWeaponLockInput(forceUnlock)
	-- IMPORTANTE: no depender de weaponLockInputCaptured. Si el estado interno
	-- quedó desincronizado, igualmente hay que devolver el control del mouse.
	Runtime.weaponLockInputCaptured = false
	Runtime.currentAimWorldPosition = nil
	Runtime.currentAimSmoothing = false

	if not MOBILE_DEVICE then
		local savedBehavior = Runtime.weaponLockSavedMouseBehavior
		local savedIcon = Runtime.weaponLockSavedMouseIconEnabled
		local savedSensitivity = Runtime.weaponLockSavedMouseDeltaSensitivity

		pcall(function()
			if forceUnlock == true or not Runtime.weaponLockEnabled then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			else
				UserInputService.MouseBehavior = savedBehavior or Enum.MouseBehavior.Default
			end
		end)

		pcall(function()
			if forceUnlock == true or not Runtime.weaponLockEnabled then
				UserInputService.MouseIconEnabled = true
			elseif savedIcon ~= nil then
				UserInputService.MouseIconEnabled = savedIcon
			end
		end)

		pcall(function()
			local restoreSensitivity = tonumber(savedSensitivity)
			if restoreSensitivity == nil or restoreSensitivity <= 0 then
				restoreSensitivity = 1
			end
			UserInputService.MouseDeltaSensitivity = restoreSensitivity
		end)

		if forceUnlock == true or not Runtime.weaponLockEnabled then
			Runtime.weaponLockReleaseUntil = os.clock() + 0.35
		end
	end

	Runtime.weaponLockSavedMouseBehavior = nil
	Runtime.weaponLockSavedMouseIconEnabled = nil
	Runtime.weaponLockSavedMouseDeltaSensitivity = nil
end

function Runtime.resetAimbotTargetSwitching()
	Runtime.aimSwitchTarget = nil
	Runtime.aimSwitchCandidate = nil
	Runtime.aimSwitchCandidateSince = 0
end

function Runtime.isAimbotTargetEligible(player, aimAtHead)
	if not HexaSharedTargetFilters:AllowsPlayer(player, true) then return false end
	if ignoreFriendsActive and Runtime.isIgnoredFriend(player) then return false end
	local character = player.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	local targetPart = character and (aimAtHead
		and (character:FindFirstChild("Head") or targetRoot)
		or (character:FindFirstChild("UpperTorso")
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("LowerTorso")
			or targetRoot))
	local _, _, localRoot = getCharacterData()
	if not localRoot or not targetRoot or not targetPart or not targetPart:IsA("BasePart") then return false end
	if (localRoot.Position - targetRoot.Position).Magnitude > maxAimDistance then return false end
	if not passesWallCheck(targetPart) then return false end
	if fovActive then
		local camera = workspace.CurrentCamera
		if not camera then return false end
		local screenPosition, onScreen = camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen or screenPosition.Z <= 0 then return false end
		local distance2D = (Vector2.new(screenPosition.X, screenPosition.Y) - camera.ViewportSize / 2).Magnitude
		if distance2D > fovRadius then return false end
	end
	return true
end

function Runtime.resolveAimbotTarget(candidate, aimAtHead)
	-- Target Persistence mantiene el objetivo actual mientras siga siendo válido.
	-- Solo permite adquirir otro cuando el anterior muere, sale del rango/FOV,
	-- deja de cumplir filtros o queda bloqueado por Wall Check.
	if HexaSharedTargetFilters.TargetPersistence then
		local current = Runtime.aimSwitchTarget
		if current ~= nil and Runtime.isAimbotTargetEligible(current, aimAtHead) then
			Runtime.aimSwitchCandidate = nil
			Runtime.aimSwitchCandidateSince = 0
			return current
		end
		Runtime.aimSwitchTarget = candidate
		Runtime.aimSwitchCandidate = nil
		Runtime.aimSwitchCandidateSince = 0
		return candidate
	end

	if not HexaSharedTargetFilters.TargetSwitchDelay then
		Runtime.aimSwitchTarget = candidate
		Runtime.aimSwitchCandidate = nil
		Runtime.aimSwitchCandidateSince = 0
		return candidate
	end

	local current = Runtime.aimSwitchTarget
	local now = os.clock()
	if current ~= nil and not Runtime.isAimbotTargetEligible(current, aimAtHead) then
		Runtime.aimSwitchTarget = nil
		current = nil
		if candidate == nil then
			Runtime.aimSwitchCandidate = nil
			Runtime.aimSwitchCandidateSince = 0
			return nil
		end
		if Runtime.aimSwitchCandidate ~= candidate then
			Runtime.aimSwitchCandidate = candidate
			Runtime.aimSwitchCandidateSince = now
			return nil
		end
	end

	if current == nil then
		if Runtime.aimSwitchCandidate == nil then
			-- La primera adquisición es inmediata; el retardo se aplica únicamente
			-- cuando ya existía un objetivo y se va a cambiar por otro.
			Runtime.aimSwitchTarget = candidate
			return candidate
		end
		if candidate ~= Runtime.aimSwitchCandidate then
			Runtime.aimSwitchCandidate = candidate
			Runtime.aimSwitchCandidateSince = candidate and now or 0
			return nil
		end
		if candidate and now - Runtime.aimSwitchCandidateSince >= math.max(0, HexaSharedTargetFilters.TargetSwitchDelaySeconds) then
			Runtime.aimSwitchTarget = candidate
			Runtime.aimSwitchCandidate = nil
			Runtime.aimSwitchCandidateSince = 0
			return candidate
		end
		return nil
	end
	if candidate == nil or candidate == current then
		Runtime.aimSwitchCandidate = nil
		Runtime.aimSwitchCandidateSince = 0
		return current
	end

	if Runtime.aimSwitchCandidate ~= candidate then
		Runtime.aimSwitchCandidate = candidate
		Runtime.aimSwitchCandidateSince = now
		return current
	end
	if now - Runtime.aimSwitchCandidateSince >= math.max(0, HexaSharedTargetFilters.TargetSwitchDelaySeconds) then
		Runtime.aimSwitchTarget = candidate
		Runtime.aimSwitchCandidate = nil
		Runtime.aimSwitchCandidateSince = 0
		return candidate
	end
	return current
end

local function clearFly()
	if Runtime.flyConn then Runtime.flyConn:Disconnect(); Runtime.flyConn = nil end
	if Runtime.flyBV then Runtime.flyBV:Destroy(); Runtime.flyBV = nil end
	if Runtime.flyBG then Runtime.flyBG:Destroy(); Runtime.flyBG = nil end
	setMobileFlyControlsVisible(false)
	local _, hum = getCharacterData()
	if hum then pcall(function() hum.PlatformStand = false end) end
end

local function restoreNoclip()
	for part, original in pairs(Runtime.noclipCache) do
		if part and part.Parent then part.CanCollide = original end
	end
	table.clear(Runtime.noclipCache)
end

function Runtime.scanNoclipParts(character)
	for _, instance in ipairs(character:GetDescendants()) do
		if instance:IsA("BasePart") and Runtime.noclipCache[instance] == nil then
			Runtime.noclipCache[instance] = instance.CanCollide
		end
	end
end

function Runtime.updateNoclip(character, now)
	if now - Runtime.lastNoclipScan >= 0.5 or next(Runtime.noclipCache) == nil then
		Runtime.lastNoclipScan = now
		Runtime.scanNoclipParts(character)
	end
	for part in pairs(Runtime.noclipCache) do
		if part and part.Parent then
			if part.CanCollide then part.CanCollide = false end
		else
			Runtime.noclipCache[part] = nil
		end
	end
end

local function cleanupMovement()
	clearFly()
	restoreNoclip()
	local _, hum = getCharacterData()
	if hum then pcall(function() hum.WalkSpeed = Runtime.speedBase; hum.UseJumpPower = true; hum.JumpPower = Runtime.jumpBase; hum.PlatformStand = false end) end
	if AimHighlight then AimHighlight:Destroy() end
end

local function ensureFly()
	local char, hum, root = getCharacterData()
	if not char or not hum or not root or hum.Health <= 0 then return end
	clearFly()
	flyActive = true
	hum.PlatformStand = true
	Runtime.flyBG = Instance.new("BodyGyro", root); Runtime.flyBG.P = 9e4; Runtime.flyBG.MaxTorque = Vector3.new(9e4, 9e4, 9e4); Runtime.flyBG.CFrame = workspace.CurrentCamera.CFrame
	Runtime.flyBV = Instance.new("BodyVelocity", root); Runtime.flyBV.MaxForce = Vector3.new(9e4, 9e4, 9e4); Runtime.flyBV.Velocity = Vector3.new(0,0,0)
	setMobileFlyControlsVisible(MOBILE_DEVICE)

	Runtime.flyConn = RunService.RenderStepped:Connect(function()
		local _, hum2, root2 = getCharacterData()
		if not hum2 or not root2 or hum2.Health <= 0 then return end
		local cam = workspace.CurrentCamera
		if not cam then return end

		local move = Vector3.new(0, 0, 0)
		local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
		if MOBILE_DEVICE then
			local mobileMove = nil
			if MobileMovementControls then
				pcall(function() mobileMove = MobileMovementControls:GetMoveVector() end)
			end
			if mobileMove and mobileMove.Magnitude > 0.01 then
				local flatLook = Vector3.new(look.X, 0, look.Z)
				local flatRight = Vector3.new(right.X, 0, right.Z)
				if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
				if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
				move += (flatRight * mobileMove.X) - (flatLook * mobileMove.Z)
			elseif hum2.MoveDirection.Magnitude > 0.01 then
				move += hum2.MoveDirection
			end
			move += Vector3.new(0, mobileFlyVertical, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
		if move.Magnitude > 0 then move = move.Unit end
		pcall(function() Runtime.flyBG.CFrame = cam.CFrame; Runtime.flyBV.Velocity = move * currentFlySpeed end)
	end)
end

local function rebuildPlayerList()
	for _, child in ipairs(DropdownList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	for _, player in ipairs(Runtime.playerSnapshot) do
		if player ~= LocalPlayer and player.Parent == Players then
			local item = Instance.new("TextButton")
			item.Size = UDim2.new(1, 0, 0, 32)
			item.BackgroundColor3 = Theme.Panel2
			item.BackgroundTransparency = 1
			item.Text = ("  %s (@%s)"):format(player.DisplayName, player.Name)
			item.TextColor3 = BUTTON_TEXT_COLOR
			item.TextSize = 12
			item.Font = Enum.Font.GothamMedium
			item.AutoButtonColor = false
			item.ZIndex = 21
			item.Parent = DropdownList
			mkCorner(item, 10); mkStroke(item, Theme.Accent, 0.7, 1); addHover(item, Theme.Panel2, Theme.Accent2, Theme.Active)
			item.MouseButton1Click:Connect(function()
				if player == LocalPlayer or player.Parent ~= Players then return end
				selectedTargetPlayer = player; DropdownButton.Text = "  Jugador: " .. player.Name; DropdownList.Visible = false
			end)
		end
	end
end
HexaSharedTargetFilters:AddListener(function()
	rebuildPlayerList()
end)
AllSliders.TrackConnection(Players.PlayerAdded:Connect(rebuildPlayerList))
AllSliders.TrackConnection(Players.PlayerRemoving:Connect(function(player)
	if selectedTargetPlayer == player then selectedTargetPlayer = nil; DropdownButton.Text = "  Seleccionar jugador: [ninguno]" end
	rebuildPlayerList()
	if espCache[player] then
		if espCache[player].Tracer then espCache[player].Tracer:Destroy() end
		if espCache[player].Skel then for _, f in ipairs(espCache[player].Skel) do f:Destroy() end end
		espCache[player] = nil
	end
end))

ConfigManager:BindToggle(flyButton, function() flyActive = not flyActive; setActive(flyButton, flyActive); if flyActive then ensureFly() else clearFly() end end)
ConfigManager:BindToggle(speedButton, function() speedActive = not speedActive; setActive(speedButton, speedActive); if speedActive then local _,h = getCharacterData() if h then Runtime.speedBase=h.WalkSpeed end else local _,h=getCharacterData() if h then pcall(function() h.WalkSpeed=Runtime.speedBase end) end end end)
ConfigManager:BindToggle(jumpButton, function() jumpActive = not jumpActive; setActive(jumpButton, jumpActive); if jumpActive then local _,h = getCharacterData() if h then Runtime.jumpBase=h.JumpPower pcall(function() h.UseJumpPower=true end) end else local _,h=getCharacterData() if h then pcall(function() h.UseJumpPower=true; h.JumpPower=Runtime.jumpBase end) end end end)
ConfigManager:BindToggle(infiniteJumpButton, function() infiniteJumpActive = not infiniteJumpActive; setActive(infiniteJumpButton, infiniteJumpActive) end)
ConfigManager:BindToggle(noclipButton, function()
	noclipActive = not noclipActive
	setActive(noclipButton, noclipActive)
	if noclipActive then Runtime.lastNoclipScan = 0 else restoreNoclip() end
end)

ConfigManager:BindToggle(autoAimHeadButton, function()
	autoAimHeadActive = not autoAimHeadActive
	if autoAimHeadActive then MobileAim.PreferredHead = true end
	setActive(autoAimHeadButton, autoAimHeadActive)
	if autoAimHeadActive and autoAimBodyActive then autoAimBodyActive = false; setActive(autoAimBodyButton, false) end
	if not autoAimHeadActive and not autoAimBodyActive then AimHighlight.Adornee = nil end
	MobileAim:Refresh()
end)
ConfigManager:BindToggle(autoAimBodyButton, function()
	autoAimBodyActive = not autoAimBodyActive
	if autoAimBodyActive then MobileAim.PreferredHead = false end
	setActive(autoAimBodyButton, autoAimBodyActive)
	if autoAimBodyActive and autoAimHeadActive then autoAimHeadActive = false; setActive(autoAimHeadButton, false) end
	if not autoAimHeadActive and not autoAimBodyActive then AimHighlight.Adornee = nil end
	MobileAim:Refresh()
end)
ConfigManager:BindToggle(MobileAim.OptionButton, function()
	if not MOBILE_DEVICE then
		MobileAim.Enabled = false
		setActive(MobileAim.OptionButton, false)
		MobileAim:Refresh()
		return
	end
	MobileAim.Enabled = not MobileAim.Enabled
	setActive(MobileAim.OptionButton, MobileAim.Enabled)
	MobileAim:Refresh()
end)
ConfigManager:BindToggle(ignoreFriendsButton, function() ignoreFriendsActive = not ignoreFriendsActive; setActive(ignoreFriendsButton, ignoreFriendsActive) end)
ConfigManager:BindToggle(fovButton, function() fovActive = not fovActive; setActive(fovButton, fovActive); FovCircle.Visible = fovActive end)

ConfigManager:BindToggle(espSkeletonButton, function() espSkeletonActive = not espSkeletonActive; setActive(espSkeletonButton, espSkeletonActive) end)
ConfigManager:BindToggle(espLinesButton, function() espLinesActive = not espLinesActive; setActive(espLinesButton, espLinesActive) end)


-- ================================================================
-- FUNCIONES ADICIONALES HEXA X
-- Aisladas en una función propia para no superar el límite de
-- variables locales de la función principal.
-- ================================================================
task.spawn(function()
	local moduleOk, moduleError = xpcall(function()
		local Settings = {
			WallCheck = HexaSharedTargetFilters.WallCheck,
			TeamCheck = HexaSharedTargetFilters.TeamCheck,
			AimSmoothing = false,
			WeaponLock = false,
			TargetPrediction = false,
			TargetSwitchDelay = false,
			TargetPersistence = false,
			TargetSwitchDelayMs = 350,
			NoRecoil = false,
			RapidFire = false,
			RapidFireRate = 22,
			FullAutoConversion = false,
			RangeExtender = false,
			RangeMultiplier = 10,
			DamageFalloffModifier = false,
			BulletVelocityModifier = false,
			BulletVelocityMultiplier = 5,
			ProjectileLifetimeExtender = false,
			ProjectileLifetimeSeconds = 30,
			SurfacePenetration = false,
			NoSpread = false,
			AutoReload = false,
			InfiniteAmmo = false,
			Hitbox = false,
			HeadHitbox = false,
			HitboxSize = 5,
			HitboxColorIndex = 6,
			Fullbright = false,
			XRay = false,
			XRayTransparency = 75,
			DroneCamera = false,
			DroneSpeed = 50,
			Spin = false,
			SpinSpeed = 120,
			AntiStun = false,
			AntiRagdoll = false,
			BoxESP = false,
			NameESP = false,
			HealthESP = false,
			ESPHighlight = false,
		}

		local State = {
			Dead = false,
			LastWeaponScan = 0,
			LastRapidShot = 0,
			LastFullAutoShot = 0,
			LastLocalWeaponActivation = 0,
			LastAutoReload = 0,
			LastHitboxUpdate = 0,
			LastFullbrightUpdate = 0,
			LastCharacterControlUpdate = 0,
			LastHumanoidUpdate = 0,
			FullbrightOriginal = nil,
			FullbrightApplying = false,
			-- Debe ser una tabla fuerte: si las claves son débiles se pierden las
			-- paredes y luego no se pueden actualizar ni restaurar al apagar X-Ray.
			XRayOriginal = {},
			XRayGeneration = 0,
			LastEspRender = 0,
			LastHighlightUpdate = 0,
			Connections = {},
			EspCache = {},
			NoRecoilValues = setmetatable({}, {__mode = "k"}),
			NoRecoilAttributes = setmetatable({}, {__mode = "k"}),
			NoSpreadValues = setmetatable({}, {__mode = "k"}),
			NoSpreadAttributes = setmetatable({}, {__mode = "k"}),
			RapidValues = setmetatable({}, {__mode = "k"}),
			RapidAttributes = setmetatable({}, {__mode = "k"}),
			RapidToolEnabled = setmetatable({}, {__mode = "k"}),
			FullAutoValues = setmetatable({}, {__mode = "k"}),
			FullAutoAttributes = setmetatable({}, {__mode = "k"}),
			RangeValues = setmetatable({}, {__mode = "k"}),
			RangeAttributes = setmetatable({}, {__mode = "k"}),
			FalloffValues = setmetatable({}, {__mode = "k"}),
			FalloffAttributes = setmetatable({}, {__mode = "k"}),
			VelocityValues = setmetatable({}, {__mode = "k"}),
			VelocityAttributes = setmetatable({}, {__mode = "k"}),
			LifetimeValues = setmetatable({}, {__mode = "k"}),
			LifetimeAttributes = setmetatable({}, {__mode = "k"}),
			PenetrationValues = setmetatable({}, {__mode = "k"}),
			PenetrationAttributes = setmetatable({}, {__mode = "k"}),
			ProjectileCollision = setmetatable({}, {__mode = "k"}),
			ProjectileVelocityApplied = setmetatable({}, {__mode = "k"}),
			TrackedWeaponTools = setmetatable({}, {__mode = "k"}),
			WeaponObjectCache = setmetatable({}, {__mode = "k"}),
			InfiniteAmmoValues = setmetatable({}, {__mode = "k"}),
			InfiniteAmmoAttributes = setmetatable({}, {__mode = "k"}),
			HitboxOriginal = setmetatable({}, {__mode = "k"}),
			HighlightCache = {},
			Drone = {
				Active = false,
				SavedType = nil,
				SavedSubject = nil,
				Position = Vector3.new(),
				Pitch = 0,
				Yaw = 0,
				LookTouch = nil,
				LastTouch = nil,
				Vertical = 0,
				VerticalInput = nil,
				MouseLook = false,
				LookDelta = Vector2.zero,
				SavedMouseBehavior = nil,
				SavedMouseIconEnabled = nil,
			},
			CharacterControl = {
				Character = nil,
				Humanoid = nil,
				Root = nil,
				WalkSpeed = nil,
				JumpPower = nil,
				JumpHeight = nil,
				UseJumpPower = nil,
				AutoRotate = nil,
				RootAnchored = nil,
			},
		}

		local function connect(signal, callback)
			ConfigManager:AttachSignalCallback(signal, callback)
			local connection = signal:Connect(callback)
			table.insert(State.Connections, connection)
			return connection
		end

		local function containsAny(textValue, patterns)
			local lowered = string.lower(tostring(textValue or ""))
			for _, pattern in ipairs(patterns) do
				if string.find(lowered, pattern, 1, true) then
					return true
				end
			end
			return false
		end

		local WeaponModifierPatterns = {
			FullAuto = {"automatic", "fullauto", "full_auto", "firemode", "fire_mode", "firingmode", "shootmode", "semiauto", "semi_auto"},
			Range = {"bulletrange", "bullet_range", "projectilerange", "projectile_range", "weaponrange", "weapon_range", "maxrange", "max_range", "maxdistance", "max_distance", "traveldistance", "travel_distance", "raylength", "ray_length"},
			Falloff = {"damagefalloff", "damage_falloff", "falloff", "dropoff", "damageattenuation", "damage_attenuation", "damagereduction", "damage_reduction"},
			FalloffDistance = {"falloffstart", "falloff_start", "falloffend", "falloff_end", "dropoffstart", "dropoff_start", "dropoffend", "dropoff_end"},
			Velocity = {"bulletvelocity", "bullet_velocity", "projectilevelocity", "projectile_velocity", "muzzlevelocity", "muzzle_velocity", "bulletspeed", "bullet_speed", "projectilespeed", "projectile_speed"},
			Lifetime = {"projectilelifetime", "projectile_lifetime", "bulletlifetime", "bullet_lifetime", "maxlifetime", "max_lifetime", "lifetime", "despawntime", "despawn_time", "destroytime", "destroy_time", "projectileduration", "projectile_duration"},
			Penetration = {"penetration", "penetrate", "wallbang", "wall_bang", "pierce", "piercing", "surfacepenetration", "surface_penetration", "penetrationdepth", "penetration_depth", "penetrationpower", "penetration_power", "maxpenetrations", "max_penetrations"},
		}

		-- Aim Smoothing puede funcionar como modo independiente y usa su propia tecla.
		local AimSmoothingButton = createToggleButton(
			CombatCard,
			"SUAVIZADO DE PUNTERÍA",
			UDim2.new(1, -32, 0, 38),
			UDim2.new(0, 16, 0, 188)
		)

		local HitboxColors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(255, 65, 65),
			Color3.fromRGB(65, 255, 120),
			Color3.fromRGB(70, 160, 255),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(205, 90, 255),
		}
		local HitboxColorNames = {"BLANCO", "ROJO", "VERDE", "AZUL", "AMARILLO", "MORADO"}

		local CombatAdvancedCard = sectionCard(678)
		CombatAdvancedCard.LayoutOrder = 21
		sectionTitle(CombatAdvancedCard, "COMBATE AVANZADO", UDim2.new(0, 16, 0, 14))
		local WallButton = createToggleButton(CombatAdvancedCard, "WALL CHECK", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		WallButton:SetAttribute("HexaNoTranslate", true)
		local TeamButton = createToggleButton(CombatAdvancedCard, "COMPROBAR EQUIPOS", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
		local PredictionButton = createToggleButton(CombatAdvancedCard, "TARGET PREDICTION", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
		PredictionButton:SetAttribute("HexaNoTranslate", true)
		local TargetSwitchDelayButton = createToggleButton(CombatAdvancedCard, "RETARDO AL CAMBIAR OBJETIVO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 182))
		createSlider(CombatAdvancedCard, "Retardo de cambio de objetivo (ms)", 50, 2000, Settings.TargetSwitchDelayMs, 228, function(value)
			Settings.TargetSwitchDelayMs = math.clamp(math.floor(value + 0.5), 50, 2000)
			HexaSharedTargetFilters.TargetSwitchDelaySeconds = Settings.TargetSwitchDelayMs / 1000
		end, false, 2000)
		local NoRecoilButton = createToggleButton(CombatAdvancedCard, "SIN RETROCESO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 288))
		markVipControl(NoRecoilButton)
		local NoSpreadButton = createToggleButton(CombatAdvancedCard, "SIN DISPERSIÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 334))
		markVipControl(NoSpreadButton)
		local RapidButton = createToggleButton(CombatAdvancedCard, "DISPARO RÁPIDO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 380))
		markVipControl(RapidButton)
		createSlider(CombatAdvancedCard, "Disparos por segundo", 1, 800, Settings.RapidFireRate, 426, function(value)
			Settings.RapidFireRate = math.clamp(math.floor(value + 0.5), 1, 800)
		end, true)
		local AutoReloadButton = createToggleButton(CombatAdvancedCard, "RECARGA AUTOMÁTICA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 486))
		local InfiniteAmmoButton = createToggleButton(CombatAdvancedCard, "MUNICIÓN INFINITA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 532))
		markVipControl(InfiniteAmmoButton)
		local FullbrightButton = createToggleButton(CombatAdvancedCard, "FULLBRIGHT", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 578))
		local TargetPersistenceButton = createToggleButton(CombatAdvancedCard, "PERSISTENCIA DE OBJETIVO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 624))

		local WeaponLockCard = sectionCard(96)
		WeaponLockCard.LayoutOrder = 22
		sectionTitle(WeaponLockCard, "CONTROL DE MIRA", UDim2.new(0, 16, 0, 14))
		local WeaponLockButton = createToggleButton(
			WeaponLockCard,
			"BLOQUEO DE ARMA",
			UDim2.new(1, -32, 0, 38),
			UDim2.new(0, 16, 0, 44)
		)

		local ProjectileModifiersCard = sectionCard(510)
		ProjectileModifiersCard.LayoutOrder = 24
		sectionTitle(ProjectileModifiersCard, "MODIFICADORES DE ARMAS Y PROYECTILES", UDim2.new(0, 16, 0, 14))
		local FullAutoConversionButton = createToggleButton(ProjectileModifiersCard, "CONVERSIÓN DE ARMA A AUTOMÁTICA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		local RangeExtenderButton = createToggleButton(ProjectileModifiersCard, "EXTENSOR DE ALCANCE DE BALA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
		createSlider(ProjectileModifiersCard, "Multiplicador de alcance", 1, 20, Settings.RangeMultiplier, 136, function(value)
			Settings.RangeMultiplier = math.clamp(math.floor(value + 0.5), 1, 20)
		end)
		local DamageFalloffButton = createToggleButton(ProjectileModifiersCard, "MODIFICADOR DE CAÍDA DE DAÑO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 196))
		local BulletVelocityButton = createToggleButton(ProjectileModifiersCard, "MODIFICADOR DE VELOCIDAD DE BALA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 242))
		createSlider(ProjectileModifiersCard, "Multiplicador de velocidad de bala", 1, 20, Settings.BulletVelocityMultiplier, 288, function(value)
			Settings.BulletVelocityMultiplier = math.clamp(math.floor(value + 0.5), 1, 20)
		end)
		local ProjectileLifetimeButton = createToggleButton(ProjectileModifiersCard, "EXTENSOR DE DURACIÓN DEL PROYECTIL", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 348))
		createSlider(ProjectileModifiersCard, "Duración del proyectil (s)", 1, 60, Settings.ProjectileLifetimeSeconds, 394, function(value)
			Settings.ProjectileLifetimeSeconds = math.clamp(math.floor(value + 0.5), 1, 60)
		end)
		local SurfacePenetrationButton = createToggleButton(ProjectileModifiersCard, "BALA PENETRANTE DE SUPERFICIES", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 454))

		local HitboxCard = sectionCard(250)
		HitboxCard.LayoutOrder = 23
		sectionTitle(HitboxCard, "HITBOX", UDim2.new(0, 16, 0, 14))
		local HitboxButton = createToggleButton(HitboxCard, "EXPANSOR DE HITBOX", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		local HeadHitboxButton = createToggleButton(HitboxCard, "HITBOX DE CABEZA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
		createSlider(HitboxCard, "Tamaño del Hitbox", 2, 25, Settings.HitboxSize, 136, function(value)
			Settings.HitboxSize = math.floor(value + 0.5)
		end, false, 15)
		local HitboxColorButton = neonButton(HitboxCard, "COLOR DEL HITBOX: MORADO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 196))

		local EspAdvancedCard = sectionCard(340)
		EspAdvancedCard.LayoutOrder = 31
		sectionTitle(EspAdvancedCard, "ESP AVANZADO", UDim2.new(0, 16, 0, 14))
		local BoxButton = createToggleButton(EspAdvancedCard, "CAJA ESP", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		local NameButton = createToggleButton(EspAdvancedCard, "NOMBRE ESP", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
		local HealthButton = createToggleButton(EspAdvancedCard, "BARRA DE VIDA ESP", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
		local HighlightButton = createToggleButton(EspAdvancedCard, "ESP HIGHLIGHT", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 182))
		HighlightButton:SetAttribute("HexaNoTranslate", true)
		local XRayButton = createToggleButton(EspAdvancedCard, "X-RAY", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 228))
		XRayButton:SetAttribute("HexaNoTranslate", true)
		markVipControl(XRayButton)
		createSlider(EspAdvancedCard, "Transparencia X-Ray", 0, 100, Settings.XRayTransparency, 274, function(value)
			Settings.XRayTransparency = value
			if Settings.XRay then
				local transparency = math.clamp(value / 100, 0, 1)
				for object in pairs(State.XRayOriginal) do
					if object and object.Parent then
						pcall(function() object.LocalTransparencyModifier = transparency end)
					end
				end
			end
		end, true)

		local CameraMovementCard = sectionCard(264)
		CameraMovementCard.LayoutOrder = 34
		sectionTitle(CameraMovementCard, "CÁMARA Y MOVIMIENTO", UDim2.new(0, 16, 0, 14))
		local DroneButton = createToggleButton(CameraMovementCard, "CÁMARA LIBRE", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		markVipControl(DroneButton)
		createSlider(CameraMovementCard, "Velocidad de la cámara libre", 10, 300, Settings.DroneSpeed, 90, function(value)
			Settings.DroneSpeed = value
		end, true)
		local SpinButton = createToggleButton(CameraMovementCard, "SPIN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 150))
		createSlider(CameraMovementCard, "Velocidad del Spin", 10, 400, Settings.SpinSpeed, 196, function(value)
			Settings.SpinSpeed = value
		end)


		local ProtectionCard = sectionCard(140)
		ProtectionCard.LayoutOrder = 36
		sectionTitle(ProtectionCard, "PROTECCIÓN DEL PERSONAJE", UDim2.new(0, 16, 0, 14))
		local AntiStunButton = createToggleButton(ProtectionCard, "ANTI ATURDIMIENTO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		local AntiRagdollButton = createToggleButton(ProtectionCard, "ANTI RAGDOLL", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))

		local Buttons = {
			WallCheck = WallButton,
			TeamCheck = TeamButton,
			AimSmoothing = AimSmoothingButton,
			WeaponLock = WeaponLockButton,
			TargetPrediction = PredictionButton,
			TargetSwitchDelay = TargetSwitchDelayButton,
			TargetPersistence = TargetPersistenceButton,
			NoRecoil = NoRecoilButton,
			RapidFire = RapidButton,
			FullAutoConversion = FullAutoConversionButton,
			RangeExtender = RangeExtenderButton,
			DamageFalloffModifier = DamageFalloffButton,
			BulletVelocityModifier = BulletVelocityButton,
			ProjectileLifetimeExtender = ProjectileLifetimeButton,
			SurfacePenetration = SurfacePenetrationButton,
			NoSpread = NoSpreadButton,
			AutoReload = AutoReloadButton,
			InfiniteAmmo = InfiniteAmmoButton,
			Fullbright = FullbrightButton,
			Hitbox = HitboxButton,
			HeadHitbox = HeadHitboxButton,
			DroneCamera = DroneButton,
			Spin = SpinButton,
			AntiStun = AntiStunButton,
			AntiRagdoll = AntiRagdollButton,
			BoxESP = BoxButton,
			NameESP = NameButton,
			HealthESP = HealthButton,
			ESPHighlight = HighlightButton,
			XRay = XRayButton,
		}

		local EspLayer = Instance.new("Frame")
		EspLayer.Name = "HexaAdvancedEspLayer"
		EspLayer.BackgroundTransparency = 1
		EspLayer.BorderSizePixel = 0
		EspLayer.Position = UDim2.fromScale(0, 0)
		EspLayer.Size = UDim2.fromScale(1, 1)
		EspLayer.ClipsDescendants = false
		EspLayer.Active = false
		EspLayer.ZIndex = 2
		EspLayer.Parent = ScreenGui

		local MobileDroneControls = nil
		do
			MobileDroneControls = Instance.new("Frame")
			MobileDroneControls.Name = "HexaAdvancedDroneControls"
			MobileDroneControls.AnchorPoint = Vector2.new(1, 0.5)
			MobileDroneControls.Position = UDim2.new(1, -14, 0.5, -42)
			MobileDroneControls.Size = UDim2.fromOffset(92, 96)
			MobileDroneControls.BackgroundTransparency = 1
			MobileDroneControls.Visible = false
			MobileDroneControls.ZIndex = 130
			MobileDroneControls.Parent = ScreenGui

			local DroneUp = neonButton(MobileDroneControls, "SUBIR", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 0), 131)
			local DroneDown = neonButton(MobileDroneControls, "BAJAR", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 1, -42), 131)
			DroneUp:SetAttribute("HexaNoFavorite", true)
			DroneDown:SetAttribute("HexaNoFavorite", true)

			local function bindVertical(button, direction)
				connect(button.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
						State.Drone.VerticalInput = input
						State.Drone.Vertical = direction
					end
				end)
				connect(button.InputEnded, function(input)
					if State.Drone.VerticalInput == input then
						State.Drone.VerticalInput = nil
						State.Drone.Vertical = 0
					end
				end)
			end
			bindVertical(DroneUp, 1)
			bindVertical(DroneDown, -1)
		end

		local function getLocalCharacter()
			local character = LocalPlayer.Character
			if not character then return nil, nil, nil end
			return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
		end

		local function releaseCharacterControl()
			local control = State.CharacterControl
			if control.Humanoid and control.Humanoid.Parent then
				pcall(function()
					if control.WalkSpeed ~= nil then control.Humanoid.WalkSpeed = control.WalkSpeed end
					if control.UseJumpPower ~= nil then control.Humanoid.UseJumpPower = control.UseJumpPower end
					if control.JumpPower ~= nil then control.Humanoid.JumpPower = control.JumpPower end
					if control.JumpHeight ~= nil then control.Humanoid.JumpHeight = control.JumpHeight end
					if control.AutoRotate ~= nil then control.Humanoid.AutoRotate = control.AutoRotate end
				end)
			end
			if control.Root and control.Root.Parent and control.RootAnchored ~= nil then
				pcall(function() control.Root.Anchored = control.RootAnchored end)
			end
			State.CharacterControl = {
				Character = nil,
				Humanoid = nil,
				Root = nil,
				WalkSpeed = nil,
				JumpPower = nil,
				JumpHeight = nil,
				UseJumpPower = nil,
				AutoRotate = nil,
				RootAnchored = nil,
			}
		end

		local function ensureCharacterControl()
			local character, humanoid, root = getLocalCharacter()
			if not character or not humanoid or not root then return nil end
			local control = State.CharacterControl
			if control.Character ~= character then
				releaseCharacterControl()
				control = State.CharacterControl
				control.Character = character
				control.Humanoid = humanoid
				control.Root = root
				control.WalkSpeed = humanoid.WalkSpeed
				control.JumpPower = humanoid.JumpPower
				control.JumpHeight = humanoid.JumpHeight
				control.UseJumpPower = humanoid.UseJumpPower
				control.AutoRotate = humanoid.AutoRotate
				control.RootAnchored = root.Anchored
			end
			return control
		end

		local function applyCharacterControl()
			if not Settings.DroneCamera and not Settings.Spin then
				releaseCharacterControl()
				return
			end
			local control = ensureCharacterControl()
			if not control then return end
			if Settings.DroneCamera then
				pcall(function()
					control.Humanoid.WalkSpeed = 0
					control.Humanoid.AutoRotate = false
					if control.Humanoid.UseJumpPower then
						control.Humanoid.JumpPower = 0
					else
						control.Humanoid.JumpHeight = 0
					end
					control.Root.Anchored = true
					control.Root.AssemblyLinearVelocity = Vector3.zero
					control.Root.AssemblyAngularVelocity = Vector3.zero
				end)
			else
				pcall(function()
					control.Root.Anchored = control.RootAnchored == true
					if control.WalkSpeed ~= nil then control.Humanoid.WalkSpeed = control.WalkSpeed end
					if control.UseJumpPower ~= nil then control.Humanoid.UseJumpPower = control.UseJumpPower end
					if control.JumpPower ~= nil then control.Humanoid.JumpPower = control.JumpPower end
					if control.JumpHeight ~= nil then control.Humanoid.JumpHeight = control.JumpHeight end
					control.Humanoid.AutoRotate = false
				end)
			end
		end

		local function isValidPlayer(player)
			return passesTeamCheck(player)
		end

		local FullbrightLightingTargets = {
			Brightness = 3,
			ClockTime = 14,
			GlobalShadows = false,
			FogStart = 0,
			FogEnd = 1000000,
			FogColor = Color3.fromRGB(255, 255, 255),
			Ambient = Color3.fromRGB(178, 178, 178),
			OutdoorAmbient = Color3.fromRGB(178, 178, 178),
			ExposureCompensation = 0.45,
			ColorShift_Top = Color3.fromRGB(0, 0, 0),
			ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 1,
			ShadowSoftness = 0,
		}

		local function rememberFullbrightProperty(cache, object, propertyName)
			if cache[propertyName] ~= nil then return end
			local ok, value = pcall(function() return object[propertyName] end)
			if ok then cache[propertyName] = value end
		end

		local function setFullbrightProperty(object, propertyName, value)
			pcall(function()
				if object[propertyName] ~= value then object[propertyName] = value end
			end)
		end

		local function rememberFullbrightEffect(effect)
			local original = State.FullbrightOriginal
			if not original or original.Effects[effect] then return original and original.Effects[effect] end
			local cache = {}
			original.Effects[effect] = cache
			if effect:IsA("Atmosphere") then
				for _, propertyName in ipairs({"Density", "Offset", "Glare", "Haze"}) do
					rememberFullbrightProperty(cache, effect, propertyName)
				end
			elseif effect:IsA("PostEffect") then
				rememberFullbrightProperty(cache, effect, "Enabled")
			end
			return cache
		end

		local function applyFullbright()
			if State.FullbrightApplying then return end
			State.FullbrightApplying = true
			local ok, applyError = pcall(function()
				if not State.FullbrightOriginal then
					State.FullbrightOriginal = {
						Lighting = {},
						Effects = setmetatable({}, {__mode = "k"}),
					}
				end

				for propertyName, targetValue in pairs(FullbrightLightingTargets) do
					rememberFullbrightProperty(State.FullbrightOriginal.Lighting, Lighting, propertyName)
					setFullbrightProperty(Lighting, propertyName, targetValue)
				end

				for _, effect in ipairs(Lighting:GetDescendants()) do
					if effect:IsA("Atmosphere") then
						rememberFullbrightEffect(effect)
						setFullbrightProperty(effect, "Density", 0)
						setFullbrightProperty(effect, "Offset", 0)
						setFullbrightProperty(effect, "Glare", 0)
						setFullbrightProperty(effect, "Haze", 0)
					elseif effect:IsA("PostEffect") then
						rememberFullbrightEffect(effect)
						setFullbrightProperty(effect, "Enabled", false)
					end
				end
			end)
			State.FullbrightApplying = false
			if not ok then warn("[H4SK / FULLBRIGHT] " .. tostring(applyError)) end
		end

		local function restoreFullbright()
			local original = State.FullbrightOriginal
			if not original then return end
			State.FullbrightApplying = true
			pcall(function()
				for propertyName, value in pairs(original.Lighting) do
					pcall(function() Lighting[propertyName] = value end)
				end
				for effect, properties in pairs(original.Effects) do
					if effect and effect.Parent then
						for propertyName, value in pairs(properties) do
							pcall(function() effect[propertyName] = value end)
						end
					end
				end
			end)
			State.FullbrightOriginal = nil
			State.FullbrightApplying = false
		end

		local function isPlayerCharacterPart(object)
			if not object:IsA("BasePart") then return false end
			local ancestor = object.Parent
			while ancestor and ancestor ~= workspace do
				if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then return true end
				ancestor = ancestor.Parent
			end
			return false
		end

		local function applyXRayToPart(object, expectedGeneration)
			if expectedGeneration and expectedGeneration ~= State.XRayGeneration then return end
			if not Settings.XRay or not object:IsA("BasePart") or isPlayerCharacterPart(object) then return end
			local camera = workspace.CurrentCamera
			if camera and object:IsDescendantOf(camera) then return end
			if State.XRayOriginal[object] == nil then
				State.XRayOriginal[object] = {
					LocalTransparencyModifier = object.LocalTransparencyModifier,
				}
			end
			pcall(function()
				object.LocalTransparencyModifier = math.clamp(Settings.XRayTransparency / 100, 0, 1)
			end)
		end

		local function applyXRay()
			State.XRayGeneration += 1
			local generation = State.XRayGeneration
			task.spawn(function()
				-- Recorrido incremental: evita crear de golpe una lista gigantesca con
				-- todos los objetos del mapa, que antes congelaba uno o varios frames.
				local queue = workspace:GetChildren()
				local index = 1
				local processed = 0
				local batchSize = 45
				while index <= #queue do
					if not Settings.XRay or generation ~= State.XRayGeneration then return end
					local object = queue[index]
					index += 1
					for _, child in ipairs(object:GetChildren()) do
						table.insert(queue, child)
					end
					applyXRayToPart(object, generation)
					processed += 1
					if processed >= batchSize then
						processed = 0
						task.wait()
					end
				end
				table.clear(queue)
			end)
		end

		local function restoreXRay()
			State.XRayGeneration += 1
			local originals = State.XRayOriginal
			State.XRayOriginal = {}
			for object, properties in pairs(originals) do
				if object and object.Parent then
					pcall(function()
						object.LocalTransparencyModifier = properties.LocalTransparencyModifier
					end)
				end
			end
			table.clear(originals)
		end

		-- Disable any Silent Aim hook left by an older Hexa X execution in this Roblox session.
		pcall(function()
			_G.HexaXSilentTarget = nil
			if type(getgenv) == "function" then
				local environment = getgenv()
				local oldState = rawget(environment, "__HexaXStableSilentAimHook")
				if type(oldState) == "table" then
					oldState.Enabled = false
					oldState.Target = nil
				end
				environment.HexaXSilentTarget = nil
			end
		end)

		local function cacheValue(cache, object, newValue)
			if cache[object] == nil then cache[object] = object.Value end
			pcall(function() object.Value = newValue end)
		end

		local function cacheAttribute(cache, object, attributeName, originalValue, newValue)
			local attributes = cache[object]
			if not attributes then
				attributes = {}
				cache[object] = attributes
			end
			if attributes[attributeName] == nil then attributes[attributeName] = originalValue end
			pcall(function() object:SetAttribute(attributeName, newValue) end)
		end

		local function cacheTransformedValue(cache, object, transform)
			if cache[object] == nil then cache[object] = object.Value end
			local originalValue = cache[object]
			local ok, newValue = pcall(transform, originalValue)
			if ok then pcall(function() object.Value = newValue end) end
		end

		local function cacheTransformedAttribute(cache, object, attributeName, originalValue, transform)
			local attributes = cache[object]
			if not attributes then
				attributes = {}
				cache[object] = attributes
			end
			if attributes[attributeName] == nil then attributes[attributeName] = originalValue end
			local ok, newValue = pcall(transform, attributes[attributeName])
			if ok then pcall(function() object:SetAttribute(attributeName, newValue) end) end
		end

		local function restoreValues(cache)
			for object, value in pairs(cache) do
				if object and object.Parent then pcall(function() object.Value = value end) end
			end
			table.clear(cache)
		end

		local function restoreAttributes(cache)
			for object, attributes in pairs(cache) do
				if object and object.Parent then
					for attributeName, value in pairs(attributes) do
						pcall(function() object:SetAttribute(attributeName, value) end)
					end
				end
			end
			table.clear(cache)
		end

		local function restoreRapidTools()
			for tool, enabled in pairs(State.RapidToolEnabled) do
				if tool and tool.Parent then pcall(function() tool.Enabled = enabled end) end
			end
			table.clear(State.RapidToolEnabled)
		end

		local function restoreProjectileCollision()
			for projectile, canCollide in pairs(State.ProjectileCollision) do
				if projectile and projectile.Parent then
					pcall(function() projectile.CanCollide = canCollide end)
				end
			end
			table.clear(State.ProjectileCollision)
		end

		local function isProjectilePart(object)
			if not object:IsA("BasePart") then return false end
			local lowered = string.lower(object.Name)
			return containsAny(lowered, {"bullet", "projectile", "pellet", "rocket", "missile", "slug", "tracer"})
		end

		local function applyPhysicalProjectileModifiers(object)
			if not isProjectilePart(object) or os.clock() - State.LastLocalWeaponActivation > 0.35 then return end
			if Settings.SurfacePenetration then
				if State.ProjectileCollision[object] == nil then State.ProjectileCollision[object] = object.CanCollide end
				pcall(function() object.CanCollide = false end)
			end
			if Settings.BulletVelocityModifier and not State.ProjectileVelocityApplied[object] then
				State.ProjectileVelocityApplied[object] = true
				task.defer(function()
					if not object or not object.Parent then return end
					local multiplier = math.max(1, tonumber(Settings.BulletVelocityMultiplier) or 5)
					pcall(function()
						local velocity = object.AssemblyLinearVelocity
						if velocity.Magnitude > 0 then object.AssemblyLinearVelocity = velocity * multiplier end
					end)
				end)
			end
		end

		local function trackWeaponTool(tool)
			if State.TrackedWeaponTools[tool] then return end
			State.TrackedWeaponTools[tool] = true
			local activatedConnection = tool.Activated:Connect(function()
				State.LastLocalWeaponActivation = os.clock()
			end)
			local addedConnection = tool.DescendantAdded:Connect(function()
				State.WeaponObjectCache[tool] = nil
			end)
			local removingConnection = tool.DescendantRemoving:Connect(function()
				State.WeaponObjectCache[tool] = nil
			end)
			table.insert(State.Connections, activatedConnection)
			table.insert(State.Connections, addedConnection)
			table.insert(State.Connections, removingConnection)
		end

		local function getWeaponObjects(tool)
			local objects = State.WeaponObjectCache[tool]
			if objects then return objects end
			objects = {tool}
			for _, descendant in ipairs(tool:GetDescendants()) do
				table.insert(objects, descendant)
			end
			State.WeaponObjectCache[tool] = objects
			return objects
		end

		connect(workspace.DescendantAdded, function(object)
			if Settings.SurfacePenetration or Settings.BulletVelocityModifier then
				applyPhysicalProjectileModifiers(object)
			end
		end)
		connect(workspace.DescendantRemoving, function(object)
			State.ProjectileCollision[object] = nil
			State.ProjectileVelocityApplied[object] = nil
		end)

		local function restoreWeapons()
			restoreValues(State.NoRecoilValues)
			restoreAttributes(State.NoRecoilAttributes)
			restoreValues(State.NoSpreadValues)
			restoreAttributes(State.NoSpreadAttributes)
			restoreValues(State.RapidValues)
			restoreAttributes(State.RapidAttributes)
			restoreRapidTools()
			restoreValues(State.InfiniteAmmoValues)
			restoreAttributes(State.InfiniteAmmoAttributes)
			restoreValues(State.FullAutoValues)
			restoreAttributes(State.FullAutoAttributes)
			restoreValues(State.RangeValues)
			restoreAttributes(State.RangeAttributes)
			restoreValues(State.FalloffValues)
			restoreAttributes(State.FalloffAttributes)
			restoreValues(State.VelocityValues)
			restoreAttributes(State.VelocityAttributes)
			restoreValues(State.LifetimeValues)
			restoreAttributes(State.LifetimeAttributes)
			restoreValues(State.PenetrationValues)
			restoreAttributes(State.PenetrationAttributes)
			restoreProjectileCollision()
			table.clear(State.ProjectileVelocityApplied)
		end

		local function updateWeapons(now)
			local character = LocalPlayer.Character
			local tool = character and character:FindFirstChildOfClass("Tool")
			if not tool then
				State.LastWeaponScan = now
				return
			end
			trackWeaponTool(tool)
			if Settings.RapidFire or Settings.FullAutoConversion then
				if State.RapidToolEnabled[tool] == nil then State.RapidToolEnabled[tool] = tool.Enabled end
				pcall(function() tool.Enabled = true end)
			end
			local weaponScanInterval = PERFORMANCE_MODE and 0.45 or 0.35
			if now - State.LastWeaponScan >= weaponScanInterval then
				State.LastWeaponScan = now
				local shouldAutoReload = false
				local rapidRate = math.clamp(math.floor(tonumber(Settings.RapidFireRate) or 22), 1, 800)
				local rapidDelay = 1 / rapidRate
				local rapidRpm = rapidRate * 60
				local objects = getWeaponObjects(tool)
				for _, object in ipairs(objects) do
					local objectName = string.lower(object.Name)
					local isConfigValue = object:IsA("NumberValue") or object:IsA("IntValue") or object:IsA("BoolValue") or object:IsA("StringValue")
					if Settings.FullAutoConversion and isConfigValue and containsAny(objectName, WeaponModifierPatterns.FullAuto) then
						cacheTransformedValue(State.FullAutoValues, object, function(originalValue)
							if type(originalValue) == "boolean" then return not containsAny(objectName, {"semi"}) end
							if type(originalValue) == "number" then return containsAny(objectName, {"semi"}) and 0 or (containsAny(objectName, {"firemode", "fire_mode"}) and 2 or 1) end
							if type(originalValue) == "string" then return "Auto" end
							return originalValue
						end)
					end
					if Settings.SurfacePenetration and isConfigValue and containsAny(objectName, WeaponModifierPatterns.Penetration) then
						cacheTransformedValue(State.PenetrationValues, object, function(originalValue)
							if type(originalValue) == "boolean" then return true end
							if type(originalValue) == "number" then return math.max(originalValue, 1000) end
							if type(originalValue) == "string" then return "Enabled" end
							return originalValue
						end)
					end
					if object:IsA("NumberValue") or object:IsA("IntValue") then
						if Settings.NoRecoil and containsAny(objectName, {"recoil", "kick", "shake"}) then
							cacheValue(State.NoRecoilValues, object, 0)
						end
						if Settings.NoSpread and containsAny(objectName, {"spread", "accuracy", "bloom", "dispersion", "deviation", "cone"}) then
							cacheValue(State.NoSpreadValues, object, 0)
						end
						if Settings.AutoReload and containsAny(objectName, {"ammo", "clip", "bullets", "magazine", "mag", "municion", "munición"}) then
							local amount = tonumber(object.Value)
							if amount and amount <= 1 then shouldAutoReload = true end
						end
						if Settings.InfiniteAmmo and containsAny(objectName, {"ammo", "clip", "bullets", "magazine", "mag", "municion", "munición"}) then
							cacheValue(State.InfiniteAmmoValues, object, 999)
						end
						local falloffName = containsAny(objectName, WeaponModifierPatterns.Falloff)
						if Settings.RangeExtender and (objectName == "range" or containsAny(objectName, WeaponModifierPatterns.Range)) and not falloffName then
							cacheTransformedValue(State.RangeValues, object, function(originalValue)
								return math.max(0, tonumber(originalValue) or 0) * math.max(1, tonumber(Settings.RangeMultiplier) or 10)
							end)
						end
						if Settings.DamageFalloffModifier and falloffName then
							local isDistanceSetting = containsAny(objectName, WeaponModifierPatterns.FalloffDistance)
							cacheTransformedValue(State.FalloffValues, object, function(originalValue)
								return isDistanceSetting and math.max(tonumber(originalValue) or 0, 1000000) or 0
							end)
						end
						if Settings.BulletVelocityModifier and containsAny(objectName, WeaponModifierPatterns.Velocity) then
							cacheTransformedValue(State.VelocityValues, object, function(originalValue)
								return math.max(0, tonumber(originalValue) or 0) * math.max(1, tonumber(Settings.BulletVelocityMultiplier) or 5)
							end)
						end
						if Settings.ProjectileLifetimeExtender and containsAny(objectName, WeaponModifierPatterns.Lifetime) then
							cacheTransformedValue(State.LifetimeValues, object, function(originalValue)
								return math.max(tonumber(originalValue) or 0, tonumber(Settings.ProjectileLifetimeSeconds) or 30)
							end)
						end
						if Settings.RapidFire then
							if containsAny(objectName, {"cooldown", "delay", "interval", "wait", "firetime"}) then
								cacheValue(State.RapidValues, object, 0)
							elseif containsAny(objectName, {"firerate", "fire_rate", "rateoffire", "rpm"}) then
								cacheValue(State.RapidValues, object, rapidRpm)
							end
						end
					end
					for attributeName, attributeValue in pairs(object:GetAttributes()) do
						local lowered = string.lower(attributeName)
						if Settings.FullAutoConversion and containsAny(lowered, WeaponModifierPatterns.FullAuto) then
							cacheTransformedAttribute(State.FullAutoAttributes, object, attributeName, attributeValue, function(originalValue)
								if type(originalValue) == "boolean" then return not containsAny(lowered, {"semi"}) end
								if type(originalValue) == "number" then return containsAny(lowered, {"semi"}) and 0 or (containsAny(lowered, {"firemode", "fire_mode"}) and 2 or 1) end
								if type(originalValue) == "string" then return "Auto" end
								return originalValue
							end)
						end
						if Settings.SurfacePenetration and containsAny(lowered, WeaponModifierPatterns.Penetration) then
							cacheTransformedAttribute(State.PenetrationAttributes, object, attributeName, attributeValue, function(originalValue)
								if type(originalValue) == "boolean" then return true end
								if type(originalValue) == "number" then return math.max(originalValue, 1000) end
								if type(originalValue) == "string" then return "Enabled" end
								return originalValue
							end)
						end
						if type(attributeValue) == "number" then
							if Settings.NoRecoil and containsAny(lowered, {"recoil", "kick", "shake"}) then
								cacheAttribute(State.NoRecoilAttributes, object, attributeName, attributeValue, 0)
							end
							if Settings.NoSpread and containsAny(lowered, {"spread", "accuracy", "bloom", "dispersion", "deviation", "cone"}) then
								cacheAttribute(State.NoSpreadAttributes, object, attributeName, attributeValue, 0)
							end
							if Settings.AutoReload and containsAny(lowered, {"ammo", "clip", "bullets", "magazine", "mag", "municion", "munición"}) and attributeValue <= 1 then
								shouldAutoReload = true
							end
							if Settings.InfiniteAmmo and containsAny(lowered, {"ammo", "clip", "bullets", "magazine", "mag", "municion", "munición"}) then
								cacheAttribute(State.InfiniteAmmoAttributes, object, attributeName, attributeValue, 999)
							end
							local falloffName = containsAny(lowered, WeaponModifierPatterns.Falloff)
							if Settings.RangeExtender and (lowered == "range" or containsAny(lowered, WeaponModifierPatterns.Range)) and not falloffName then
								cacheTransformedAttribute(State.RangeAttributes, object, attributeName, attributeValue, function(originalValue)
									return math.max(0, tonumber(originalValue) or 0) * math.max(1, tonumber(Settings.RangeMultiplier) or 10)
								end)
							end
							if Settings.DamageFalloffModifier and falloffName then
								local isDistanceSetting = containsAny(lowered, WeaponModifierPatterns.FalloffDistance)
								cacheTransformedAttribute(State.FalloffAttributes, object, attributeName, attributeValue, function(originalValue)
									return isDistanceSetting and math.max(tonumber(originalValue) or 0, 1000000) or 0
								end)
							end
							if Settings.BulletVelocityModifier and containsAny(lowered, WeaponModifierPatterns.Velocity) then
								cacheTransformedAttribute(State.VelocityAttributes, object, attributeName, attributeValue, function(originalValue)
									return math.max(0, tonumber(originalValue) or 0) * math.max(1, tonumber(Settings.BulletVelocityMultiplier) or 5)
								end)
							end
							if Settings.ProjectileLifetimeExtender and containsAny(lowered, WeaponModifierPatterns.Lifetime) then
								cacheTransformedAttribute(State.LifetimeAttributes, object, attributeName, attributeValue, function(originalValue)
									return math.max(tonumber(originalValue) or 0, tonumber(Settings.ProjectileLifetimeSeconds) or 30)
								end)
							end
							if Settings.RapidFire then
								if containsAny(lowered, {"cooldown", "delay", "interval", "wait", "firetime"}) then
									cacheAttribute(State.RapidAttributes, object, attributeName, attributeValue, 0)
								elseif containsAny(lowered, {"firerate", "fire_rate", "rateoffire", "rpm"}) then
									cacheAttribute(State.RapidAttributes, object, attributeName, attributeValue, rapidRpm)
								end
							end
						end
					end
				end
				if Settings.AutoReload and shouldAutoReload and now - State.LastAutoReload >= 0.55 then
					State.LastAutoReload = now
					pcall(function()
						local virtualInputManager = game:GetService("VirtualInputManager")
						virtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
						task.delay(0.05, function()
							pcall(function() virtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
						end)
					end)
				end
			end
			local rapidTriggerActive = Settings.RapidFire and (
				(not MOBILE_DEVICE and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
				or (MOBILE_DEVICE and now <= Runtime.mobileShotUntil)
			)
			if rapidTriggerActive then
				local requestedRate = math.clamp(math.floor(tonumber(Settings.RapidFireRate) or 22), 1, 800)
				-- En monitores de 144/240 Hz, limitar las activaciones reales por segundo
				-- evita que RenderStepped multiplique el trabajo. El RPM interno conserva
				-- el valor completo elegido en la barra.
				local activationRateLimit = PERFORMANCE_MODE and (MOBILE_DEVICE and 180 or 120)
					or (MOBILE_DEVICE and 300 or 240)
				local rapidDelay = 1 / math.min(requestedRate, activationRateLimit)
				if State.LastRapidShot <= 0 or now - State.LastRapidShot > 0.25 then
					State.LastRapidShot = now - rapidDelay
				end
				local elapsed = now - State.LastRapidShot
				if elapsed >= rapidDelay then
					-- Evita ráfagas enormes en un solo frame (la causa principal de los tirones
					-- con valores altos). Los valores internos del arma conservan el RPM pedido.
					local maximumShotsThisFrame = PERFORMANCE_MODE and (MOBILE_DEVICE and 3 or 2) or (MOBILE_DEVICE and 5 or 4)
					local requestedShots = math.max(1, math.floor(elapsed / rapidDelay))
					local shotsDue = math.min(requestedShots, maximumShotsThisFrame)
					State.LastRapidShot = requestedShots > maximumShotsThisFrame and now
						or (State.LastRapidShot + shotsDue * rapidDelay)
					local signalAvailable = type(firesignal) == "function"
					Runtime.syntheticRapidActivation = true
					for _ = 1, shotsDue do
						if signalAvailable then
							pcall(function() firesignal(tool.Activated) end)
						else
							pcall(function()
								tool.Enabled = true
								tool:Deactivate()
								tool:Activate()
							end)
						end
					end
					-- Un pulso nativo por frame mantiene compatibilidad con armas que no
					-- escuchan firesignal sin duplicar el trabajo por cada disparo.
					if signalAvailable then
						pcall(function()
							tool.Enabled = true
							tool:Deactivate()
							tool:Activate()
						end)
					end
					Runtime.syntheticRapidActivation = false
				end
			else
				State.LastRapidShot = now
			end
			local fullAutoTriggerActive = Settings.FullAutoConversion and not Settings.RapidFire and (
				(not MOBILE_DEVICE and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
				or (MOBILE_DEVICE and now <= Runtime.mobileShotUntil)
			)
			if fullAutoTriggerActive then
				local fullAutoDelay = 1 / 12
				if now - State.LastFullAutoShot >= fullAutoDelay then
					State.LastFullAutoShot = now
					Runtime.syntheticRapidActivation = true
					pcall(function()
						tool.Enabled = true
						tool:Deactivate()
						tool:Activate()
					end)
					Runtime.syntheticRapidActivation = false
				end
			else
				State.LastFullAutoShot = now
			end
		end


		local function showDroneControls(visible)
			State.Drone.Vertical = 0
			State.Drone.VerticalInput = nil
			if MobileDroneControls then MobileDroneControls.Visible = visible == true end
		end

		local function setDesktopDroneLook(enabled)
			if MOBILE_DEVICE then return end

			-- IMPORTANTE: esta función solo puede modificar MouseBehavior cuando
			-- la cámara libre de H3X4 X realmente posee el control del mouse.
			-- Antes, soltar RMB podía ejecutar la rama de apagado aun con Drone
			-- desactivado y forzar MouseBehavior.Default, rompiendo el bloqueo
			-- de cursor nativo de shooters que usan clic derecho para apuntar.
			if enabled then
				if not State.Drone.Active then return end
				if not State.Drone.MouseLook then
					State.Drone.SavedMouseBehavior = UserInputService.MouseBehavior
					State.Drone.SavedMouseIconEnabled = UserInputService.MouseIconEnabled
				end
				State.Drone.MouseLook = true
				pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
				pcall(function() UserInputService.MouseIconEnabled = false end)
			else
				-- Si H3X4 X no había capturado el mouse, no tocar el estado que
				-- pertenece al juego. Esto mantiene Shift Lock / RMB camera lock.
				if not State.Drone.MouseLook then return end
				State.Drone.MouseLook = false
				State.Drone.LookDelta = Vector2.zero
				local savedBehavior = State.Drone.SavedMouseBehavior
				local savedIcon = State.Drone.SavedMouseIconEnabled
				State.Drone.SavedMouseBehavior = nil
				State.Drone.SavedMouseIconEnabled = nil
				if savedBehavior ~= nil then
					pcall(function() UserInputService.MouseBehavior = savedBehavior end)
				end
				if savedIcon ~= nil then
					pcall(function() UserInputService.MouseIconEnabled = savedIcon end)
				end
			end
		end

		local function startDrone()
			if State.Drone.Active then
				applyCharacterControl()
				return
			end
			local camera = workspace.CurrentCamera
			if not camera then return end
			State.Drone.Active = true
			State.Drone.SavedType = camera.CameraType
			State.Drone.SavedSubject = camera.CameraSubject
			State.Drone.Position = camera.CFrame.Position
			State.Drone.LookDelta = Vector2.zero
			local pitch, yaw = camera.CFrame:ToOrientation()
			State.Drone.Pitch = pitch
			State.Drone.Yaw = yaw
			camera.CameraType = Enum.CameraType.Scriptable
			applyCharacterControl()
			showDroneControls(MOBILE_DEVICE)
			autoAimHeadActive = false
			autoAimBodyActive = false
			setActive(autoAimHeadButton, false)
			setActive(autoAimBodyButton, false)
			AimHighlight.Adornee = nil
		end

		local function stopDrone()
			showDroneControls(false)
			setDesktopDroneLook(false)
			if not State.Drone.Active then
				applyCharacterControl()
				return
			end
			State.Drone.Active = false
			State.Drone.LookTouch = nil
			State.Drone.LastTouch = nil
			State.Drone.LookDelta = Vector2.zero
			local camera = workspace.CurrentCamera
			if camera then
				pcall(function() camera.CameraType = State.Drone.SavedType or Enum.CameraType.Custom end)
				local subject = State.Drone.SavedSubject
				if not subject or not subject.Parent then
					local _, humanoid = getLocalCharacter()
					subject = humanoid
				end
				if subject then pcall(function() camera.CameraSubject = subject end) end
			end
			applyCharacterControl()
		end

		local function pointInside(gui, point)
			if not gui or not gui.Parent or not gui.Visible then return false end
			local position = gui.AbsolutePosition
			local size = gui.AbsoluteSize
			return point.X >= position.X and point.X <= position.X + size.X and point.Y >= position.Y and point.Y <= position.Y + size.Y
		end

		local function updateDrone(dt)
			if not Settings.DroneCamera then
				if State.Drone.Active then stopDrone() end
				return
			end
			if not State.Drone.Active then startDrone() end
			local camera = workspace.CurrentCamera
			if not camera or not State.Drone.Active then return end
			if not MOBILE_DEVICE then
				local delta = State.Drone.LookDelta
				State.Drone.LookDelta = Vector2.zero
				if State.Drone.MouseLook and delta.Magnitude > 0 then
					State.Drone.Yaw = State.Drone.Yaw - delta.X * 0.0032
					State.Drone.Pitch = math.clamp(State.Drone.Pitch - delta.Y * 0.0032, math.rad(-85), math.rad(85))
				end
				local keyboardTurnSpeed = math.rad(115) * dt
				if UserInputService:IsKeyDown(Enum.KeyCode.Left) then State.Drone.Yaw = State.Drone.Yaw + keyboardTurnSpeed end
				if UserInputService:IsKeyDown(Enum.KeyCode.Right) then State.Drone.Yaw = State.Drone.Yaw - keyboardTurnSpeed end
				if UserInputService:IsKeyDown(Enum.KeyCode.Up) then
					State.Drone.Pitch = math.clamp(State.Drone.Pitch + keyboardTurnSpeed, math.rad(-85), math.rad(85))
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.Down) then
					State.Drone.Pitch = math.clamp(State.Drone.Pitch - keyboardTurnSpeed, math.rad(-85), math.rad(85))
				end
			end
			local orientation = CFrame.fromOrientation(State.Drone.Pitch, State.Drone.Yaw, 0)
			local movement = Vector3.new()
			if MOBILE_DEVICE then
				local mobileMove = nil
				if MobileMovementControls then pcall(function() mobileMove = MobileMovementControls:GetMoveVector() end) end
				if mobileMove and mobileMove.Magnitude > 0.01 then
					movement = movement + orientation.RightVector * mobileMove.X
					movement = movement - orientation.LookVector * mobileMove.Z
				end
				movement = movement + Vector3.new(0, State.Drone.Vertical, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then movement = movement + orientation.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then movement = movement - orientation.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then movement = movement - orientation.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then movement = movement + orientation.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then movement = movement + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then movement = movement - Vector3.new(0, 1, 0) end
			if movement.Magnitude > 1 then movement = movement.Unit end
			State.Drone.Position = State.Drone.Position + movement * Settings.DroneSpeed * dt
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(State.Drone.Position) * orientation
		end

		local function updateSpin(dt)
			if not Settings.Spin then return end
			local _, _, root = getLocalCharacter()
			if not root then return end
			local degreesPerSecond = math.clamp(tonumber(Settings.SpinSpeed) or 120, 10, 400) * 10
			pcall(function()
				root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(degreesPerSecond) * dt, 0)
				root.AssemblyAngularVelocity = Vector3.zero
			end)
		end

		local function newEspObjects(player)
			local outline = Instance.new("Frame")
			outline.BackgroundTransparency = 1
			outline.BorderSizePixel = 0
			outline.Visible = false
			outline.ZIndex = 3
			outline.Parent = EspLayer
			mkStroke(outline, Color3.fromRGB(0, 0, 0), 0.05, 3)

			local box = Instance.new("Frame")
			box.BackgroundTransparency = 1
			box.BorderSizePixel = 0
			box.Visible = false
			box.ZIndex = 4
			box.Parent = EspLayer
			mkStroke(box, Color3.fromRGB(255, 255, 255), 0.02, 1)

			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.BorderSizePixel = 0
			name.Text = player.Name
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			name.TextStrokeTransparency = 0
			name.TextSize = 13
			name.Font = Enum.Font.GothamSemibold
			name.TextXAlignment = Enum.TextXAlignment.Center
			name.Visible = false
			name.ZIndex = 5
			name.Parent = EspLayer
			name:SetAttribute("HexaNoTranslate", true)

			local healthBackground = Instance.new("Frame")
			healthBackground.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			healthBackground.BorderSizePixel = 0
			healthBackground.Visible = false
			healthBackground.ZIndex = 4
			healthBackground.Parent = EspLayer

			local health = Instance.new("Frame")
			health.AnchorPoint = Vector2.new(0, 1)
			health.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
			health.BorderSizePixel = 0
			health.Visible = false
			health.ZIndex = 5
			health.Parent = EspLayer

			local cache = {Outline = outline, Box = box, Name = name, HealthBackground = healthBackground, Health = health}
			State.EspCache[player] = cache
			return cache
		end

		local function hideEsp(cache)
			if not cache then return end
			for _, object in pairs(cache) do
				if object and object:IsA("GuiObject") then object.Visible = false end
			end
		end

		local function hideAllEsp()
			for _, cache in pairs(State.EspCache) do hideEsp(cache) end
		end

		local function getScreenBounds(character, camera)
			local minX, minY = math.huge, math.huge
			local maxX, maxY = -math.huge, -math.huge
			local visiblePoints = 0
			local ok, boundsCFrame, boundsSize = pcall(character.GetBoundingBox, character)
			if not ok then return nil end
			-- Cuatro puntos del plano frontal dan una caja estable con la mitad de
			-- proyecciones que las ocho esquinas tridimensionales anteriores.
			local halfWidth = math.max(boundsSize.X, boundsSize.Z) * 0.55
			local halfHeight = boundsSize.Y * 0.5
			local center = boundsCFrame.Position
			local right = boundsCFrame.RightVector * halfWidth
			local up = boundsCFrame.UpVector * halfHeight
			local function includePoint(worldPoint)
				local point = camera:WorldToViewportPoint(worldPoint)
				if point.Z > 0 then
					visiblePoints += 1
					minX = math.min(minX, point.X)
					minY = math.min(minY, point.Y)
					maxX = math.max(maxX, point.X)
					maxY = math.max(maxY, point.Y)
				end
			end
			includePoint(center - right - up)
			includePoint(center + right - up)
			includePoint(center - right + up)
			includePoint(center + right + up)
			if visiblePoints < 2 or minX == math.huge then return nil end
			return minX, minY, maxX, maxY
		end

		local function renderEsp()
			if not (Settings.BoxESP or Settings.NameESP or Settings.HealthESP) then
				hideAllEsp()
				return
			end
			local camera = workspace.CurrentCamera
			local _, _, localRoot = getLocalCharacter()
			if not camera then hideAllEsp(); return end
			local createdCaches = 0
			local cacheCreationLimit = 1
			for _, player in ipairs(Runtime.playerSnapshot) do
				if player ~= LocalPlayer then
					local cache = State.EspCache[player]
					if not cache then
						if createdCaches >= cacheCreationLimit then continue end
						cache = newEspObjects(player)
						createdCaches += 1
					end
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local valid = character and humanoid and root and humanoid.Health > 0 and isValidPlayer(player)
					if valid and localRoot and (root.Position - localRoot.Position).Magnitude > maxEspDistance then valid = false end
					if valid then
						local minX, minY, maxX, maxY = getScreenBounds(character, camera)
						if minX then
							local width = math.max(2, maxX - minX)
							local height = math.max(2, maxY - minY)
							cache.Outline.Position = UDim2.fromOffset(minX, minY)
							cache.Outline.Size = UDim2.fromOffset(width, height)
							cache.Box.Position = UDim2.fromOffset(minX, minY)
							cache.Box.Size = UDim2.fromOffset(width, height)
							cache.Outline.Visible = Settings.BoxESP
							cache.Box.Visible = Settings.BoxESP
							cache.Name.Position = UDim2.fromOffset(minX - 20, minY - 20)
							cache.Name.Size = UDim2.fromOffset(width + 40, 18)
							if cache.Name.Text ~= player.Name then cache.Name.Text = player.Name end
							cache.Name.Visible = Settings.NameESP
							local healthPercent = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
							cache.HealthBackground.Position = UDim2.fromOffset(minX - 8, minY)
							cache.HealthBackground.Size = UDim2.fromOffset(5, height)
							cache.Health.Position = UDim2.fromOffset(minX - 7, minY + height)
							cache.Health.Size = UDim2.fromOffset(3, height * healthPercent)
							cache.Health.BackgroundColor3 = Color3.fromHSV(healthPercent * 0.33, 1, 1)
							cache.HealthBackground.Visible = Settings.HealthESP
							cache.Health.Visible = Settings.HealthESP
						else
							hideEsp(cache)
						end
					else
						hideEsp(cache)
					end
				end
			end
		end

		local function destroyHighlights()
			for player, highlight in pairs(State.HighlightCache) do
				if highlight then pcall(function() highlight:Destroy() end) end
				State.HighlightCache[player] = nil
			end
		end

		local function updateHighlights()
			if not Settings.ESPHighlight then
				destroyHighlights()
				return
			end

			-- Crear/actualizar TODOS los highlights en esta misma actualización.
			-- No limitar la cantidad por ciclo: al activar ESP HIGHLIGHT debe
			-- aparecer instantáneamente en todos los jugadores válidos.
			for _, player in ipairs(Runtime.playerSnapshot) do
				if player ~= LocalPlayer then
					local character = player.Character
					local allowed = character and HexaSharedTargetFilters:AllowsPlayer(player, true)
					local highlight = State.HighlightCache[player]
					if allowed then
						if not highlight or not highlight.Parent then
							highlight = Instance.new("Highlight")
							highlight.Name = "HexaESPHighlight"
							highlight.FillColor = Color3.fromRGB(255, 0, 0)
							highlight.FillTransparency = 0.5
							highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
							highlight.OutlineTransparency = 0
							highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							highlight.Parent = ScreenGui
							State.HighlightCache[player] = highlight
						end
						highlight.Adornee = character
						highlight.Enabled = true
					elseif highlight then
						pcall(function() highlight:Destroy() end)
						State.HighlightCache[player] = nil
					end
				end
			end
		end


		local function restoreHumanoid()
			local _, humanoid = getLocalCharacter()
			if not humanoid then return end
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
		end

		local function restoreHitboxPart(part)
			local original = State.HitboxOriginal[part]
			if original and part and part.Parent then
				pcall(function()
					part.Size = original.Size
					part.Transparency = original.Transparency
					part.Color = original.Color
					part.Material = original.Material
					part.CanCollide = original.CanCollide
					part.Massless = original.Massless
				end)
				local box = part:FindFirstChild("HexaHitboxBox")
				if box then pcall(function() box:Destroy() end) end
			end
			State.HitboxOriginal[part] = nil
		end

		local function restoreHitboxes()
			for part in pairs(State.HitboxOriginal) do restoreHitboxPart(part) end
			for _, player in ipairs(Runtime.playerSnapshot) do
				local character = player.Character
				local stale = character and character:FindFirstChild("HexaBodyHitbox")
				if stale then pcall(function() stale:Destroy() end) end
			end
		end

		local function applyHitboxToPart(part, changeMassless)
			if not part or not part.Parent or not part:IsA("BasePart") then return end
			if not State.HitboxOriginal[part] then
				State.HitboxOriginal[part] = {
					Size = part.Size,
					Transparency = part.Transparency,
					Color = part.Color,
					Material = part.Material,
					CanCollide = part.CanCollide,
					Massless = part.Massless,
				}
			end
			local maximum = HEXA_IS_VIP and 25 or 15
			local size = math.clamp(Settings.HitboxSize, 2, maximum)
			local color = HitboxColors[Settings.HitboxColorIndex] or HitboxColors[6]
			local targetSize = Vector3.new(size, size, size)
			pcall(function()
				if part.Size ~= targetSize then part.Size = targetSize end
				if part.Transparency ~= 0.6 then part.Transparency = 0.6 end
				if part.Color ~= color then part.Color = color end
				if part.Material ~= Enum.Material.Neon then part.Material = Enum.Material.Neon end
				if part.CanCollide then part.CanCollide = false end
				if changeMassless and not part.Massless then part.Massless = true end
			end)
			local box = part:FindFirstChild("HexaHitboxBox")
			if not box then
				box = Instance.new("SelectionBox")
				box.Name = "HexaHitboxBox"
				box.Adornee = part
				box.LineThickness = 0.05
				box.SurfaceTransparency = 0.8
				box.Parent = part
			end
			pcall(function()
				box.Color3 = color
				box.SurfaceColor3 = color
			end)
		end

		local function updateHitboxes()
			local desiredParts = {}
			for _, player in ipairs(Runtime.playerSnapshot) do
				if player ~= LocalPlayer and HexaSharedTargetFilters:AllowsPlayer(player, true) then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local head = character and character:FindFirstChild("Head")
					-- El cuerpo usa la pieza real para que los juegos la reconozcan,
					-- pero conserva Massless para no alterar su física ni animación.
					if Settings.Hitbox and root then desiredParts[root] = false end
					if Settings.HeadHitbox and head then desiredParts[head] = true end
				end
			end
			for part, changeMassless in pairs(desiredParts) do applyHitboxToPart(part, changeMassless) end
			for part in pairs(State.HitboxOriginal) do
				if desiredParts[part] == nil then restoreHitboxPart(part) end
			end
		end

		local function updateHumanoid()
			local _, humanoid = getLocalCharacter()
			if not humanoid then return end
			if Settings.AntiStun then
				if not flyActive then pcall(function() humanoid.PlatformStand = false end) end
				if not Settings.DroneCamera and not Settings.Spin then
					pcall(function() humanoid.AutoRotate = true end)
				end
			end
			if Settings.AntiRagdoll then
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
				local currentState = humanoid:GetState()
				if currentState == Enum.HumanoidStateType.Ragdoll or currentState == Enum.HumanoidStateType.FallingDown or currentState == Enum.HumanoidStateType.Physics then
					pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
				end
			end
		end

		local function suspend()
			Runtime.weaponLockEnabled = false
			Runtime.releaseWeaponLockInput(true)
			stopDrone()
			restoreWeapons()
			restoreHitboxes()
			destroyHighlights()
			restoreFullbright()
			restoreXRay()
			restoreHumanoid()
			releaseCharacterControl()
			hideAllEsp()
		end

		local function disableAll(updateButtons)
			for settingName in pairs(Buttons) do Settings[settingName] = false end
			HexaSharedTargetFilters.WallCheck = false
			HexaSharedTargetFilters.AimSmoothing = false
			HexaSharedTargetFilters.TargetPrediction = false
			HexaSharedTargetFilters.TargetSwitchDelay = false
			HexaSharedTargetFilters.TargetPersistence = false
			Runtime.resetAimbotTargetSwitching()
			HexaSharedTargetFilters:SetTeamCheck(false)
			suspend()
			if updateButtons then
				for _, button in pairs(Buttons) do
					if button and button.Parent then setActive(button, false) end
				end
			end
		end

		local function cleanup()
			if State.Dead then return end
			State.Dead = true
			disableAll(false)
			for _, connection in ipairs(State.Connections) do pcall(function() connection:Disconnect() end) end
			table.clear(State.Connections)
			for player, cache in pairs(State.EspCache) do
				for _, object in pairs(cache) do if object and object.Parent then object:Destroy() end end
				State.EspCache[player] = nil
			end
			if EspLayer and EspLayer.Parent then EspLayer:Destroy() end
			if MobileDroneControls and MobileDroneControls.Parent then MobileDroneControls:Destroy() end
		end

		local function bindToggle(button, settingName, callback)
			local handler = function()
				if MOBILE_DEVICE and button:GetAttribute("HexaDesktopOnly") == true then
					Settings[settingName] = false
					setActive(button, false)
					return
				end
				if button:GetAttribute("HexaVipOnly") == true and not requireVip() then return end
				Settings[settingName] = not Settings[settingName]
				setActive(button, Settings[settingName])
				if callback then pcall(callback, Settings[settingName]) end
			end
			ConfigManager:SetToggleCallback(button, handler)
			connect(button.MouseButton1Click, handler)
		end

		local function refreshHitboxColorButton()
			local spanishText = "COLOR DEL HITBOX: " .. HitboxColorNames[Settings.HitboxColorIndex]
			HitboxColorButton:SetAttribute("HexaSpanishText", spanishText)
			HitboxColorButton:SetAttribute("HexaSpanishBaseText", spanishText)
			HitboxColorButton:SetAttribute("BaseText", spanishText)
			HitboxColorButton.Text = spanishText
			Lang.ApplyObject(HitboxColorButton)
		end

		connect(HitboxColorButton.MouseButton1Click, function()
			Settings.HitboxColorIndex = Settings.HitboxColorIndex % #HitboxColors + 1
			refreshHitboxColorButton()
			if Settings.Hitbox or Settings.HeadHitbox then updateHitboxes() end
		end)
		refreshHitboxColorButton()

		bindToggle(WallButton, "WallCheck", function(enabled) HexaSharedTargetFilters.WallCheck = enabled end)
		bindToggle(TeamButton, "TeamCheck", function(enabled)
			HexaSharedTargetFilters:SetTeamCheck(enabled)
			AimHighlight.Adornee = nil
			renderEsp()
			updateHitboxes()
			updateHighlights()
		end)
		bindToggle(AimSmoothingButton, "AimSmoothing", function(enabled)
			HexaSharedTargetFilters.AimSmoothing = enabled
		end)
		bindToggle(WeaponLockButton, "WeaponLock", function(enabled)
			Runtime.weaponLockEnabled = enabled == true
			if not Runtime.weaponLockEnabled then Runtime.releaseWeaponLockInput(true) end
		end)


		bindToggle(PredictionButton, "TargetPrediction", function(enabled)
			HexaSharedTargetFilters.TargetPrediction = enabled
		end)
		bindToggle(TargetSwitchDelayButton, "TargetSwitchDelay", function(enabled)
			HexaSharedTargetFilters.TargetSwitchDelay = enabled
			Runtime.resetAimbotTargetSwitching()
		end)
		bindToggle(TargetPersistenceButton, "TargetPersistence", function(enabled)
			HexaSharedTargetFilters.TargetPersistence = enabled == true
			Runtime.resetAimbotTargetSwitching()
		end)
		bindToggle(NoRecoilButton, "NoRecoil", function(enabled)
			if not enabled then
				restoreValues(State.NoRecoilValues)
				restoreAttributes(State.NoRecoilAttributes)
			end
		end)
		bindToggle(RapidButton, "RapidFire", function(enabled)
			State.LastRapidShot = os.clock()
			if not enabled then
				restoreValues(State.RapidValues)
				restoreAttributes(State.RapidAttributes)
				if not Settings.FullAutoConversion then restoreRapidTools() end
			end
		end)
		bindToggle(FullAutoConversionButton, "FullAutoConversion", function(enabled)
			State.LastFullAutoShot = os.clock()
			if not enabled then
				restoreValues(State.FullAutoValues)
				restoreAttributes(State.FullAutoAttributes)
				if not Settings.RapidFire then restoreRapidTools() end
			end
		end)
		bindToggle(RangeExtenderButton, "RangeExtender", function(enabled)
			if not enabled then
				restoreValues(State.RangeValues)
				restoreAttributes(State.RangeAttributes)
			end
		end)
		bindToggle(DamageFalloffButton, "DamageFalloffModifier", function(enabled)
			if not enabled then
				restoreValues(State.FalloffValues)
				restoreAttributes(State.FalloffAttributes)
			end
		end)
		bindToggle(BulletVelocityButton, "BulletVelocityModifier", function(enabled)
			if not enabled then
				restoreValues(State.VelocityValues)
				restoreAttributes(State.VelocityAttributes)
				table.clear(State.ProjectileVelocityApplied)
			end
		end)
		bindToggle(ProjectileLifetimeButton, "ProjectileLifetimeExtender", function(enabled)
			if not enabled then
				restoreValues(State.LifetimeValues)
				restoreAttributes(State.LifetimeAttributes)
			end
		end)
		bindToggle(SurfacePenetrationButton, "SurfacePenetration", function(enabled)
			if not enabled then
				restoreValues(State.PenetrationValues)
				restoreAttributes(State.PenetrationAttributes)
				restoreProjectileCollision()
			end
		end)
		bindToggle(NoSpreadButton, "NoSpread", function(enabled)
			if not enabled then
				restoreValues(State.NoSpreadValues)
				restoreAttributes(State.NoSpreadAttributes)
			end
		end)
		bindToggle(AutoReloadButton, "AutoReload")
		bindToggle(InfiniteAmmoButton, "InfiniteAmmo", function(enabled)
			if not enabled then
				restoreValues(State.InfiniteAmmoValues)
				restoreAttributes(State.InfiniteAmmoAttributes)
			end
		end)
		bindToggle(FullbrightButton, "Fullbright", function(enabled)
			if enabled then applyFullbright() else restoreFullbright() end
		end)
		bindToggle(HitboxButton, "Hitbox", function(enabled)
			if enabled or Settings.HeadHitbox then
				State.LastHitboxUpdate = 0
				updateHitboxes()
			else
				restoreHitboxes()
			end
		end)
		bindToggle(HeadHitboxButton, "HeadHitbox", function(enabled)
			if enabled or Settings.Hitbox then
				State.LastHitboxUpdate = 0
				updateHitboxes()
			else
				restoreHitboxes()
			end
		end)
		bindToggle(XRayButton, "XRay", function(enabled)
			if enabled then applyXRay() else restoreXRay() end
		end)
		bindToggle(DroneButton, "DroneCamera", function(enabled)
			if enabled then startDrone() else stopDrone() end
		end)
		bindToggle(SpinButton, "Spin", function()
			applyCharacterControl()
		end)
		bindToggle(AntiStunButton, "AntiStun")
		bindToggle(AntiRagdollButton, "AntiRagdoll", function(enabled) if not enabled then restoreHumanoid() end end)
		bindToggle(BoxButton, "BoxESP", function(enabled) if not enabled then renderEsp() end end)
		bindToggle(NameButton, "NameESP", function(enabled) if not enabled then renderEsp() end end)
		bindToggle(HealthButton, "HealthESP", function(enabled) if not enabled then renderEsp() end end)
		bindToggle(HighlightButton, "ESPHighlight", function() updateHighlights() end)

		-- Wall Check y Team Check deben iniciar apagados.
		HexaSharedTargetFilters.WallCheck = false
		HexaSharedTargetFilters.TargetSwitchDelay = false
		HexaSharedTargetFilters.TargetPersistence = false
		Runtime.resetAimbotTargetSwitching()
		HexaSharedTargetFilters:SetTeamCheck(false)
		setActive(WallButton, false)
		setActive(TeamButton, false)
		setActive(TargetSwitchDelayButton, false)
		setActive(TargetPersistenceButton, false)

		addVipStateListener(function(isVip)
			if State.Dead then return end
			if Settings.Hitbox or Settings.HeadHitbox then updateHitboxes() end
			if isVip then return end
			if Settings.NoRecoil then
				Settings.NoRecoil = false
				restoreValues(State.NoRecoilValues)
				restoreAttributes(State.NoRecoilAttributes)
				setActive(NoRecoilButton, false)
			end
			if Settings.RapidFire then
				Settings.RapidFire = false
				restoreValues(State.RapidValues)
				restoreAttributes(State.RapidAttributes)
				setActive(RapidButton, false)
			end
			if Settings.NoSpread then
				Settings.NoSpread = false
				restoreValues(State.NoSpreadValues)
				restoreAttributes(State.NoSpreadAttributes)
				setActive(NoSpreadButton, false)
			end
			if Settings.InfiniteAmmo then
				Settings.InfiniteAmmo = false
				restoreValues(State.InfiniteAmmoValues)
				restoreAttributes(State.InfiniteAmmoAttributes)
				setActive(InfiniteAmmoButton, false)
			end
			if Settings.DroneCamera then
				Settings.DroneCamera = false
				stopDrone()
				setActive(DroneButton, false)
			end
			if Settings.XRay then
				Settings.XRay = false
				restoreXRay()
				setActive(XRayButton, false)
			end
		end)

		connect(UserInputService.InputBegan, function(input, processed)
			if processed or not State.Drone.Active then return end
			if not MOBILE_DEVICE then
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					setDesktopDroneLook(true)
				end
				return
			end
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			local camera = workspace.CurrentCamera
			if not camera or input.Position.X < camera.ViewportSize.X * 0.42 then return end
			if pointInside(MainFrame, input.Position) or pointInside(MobileDroneControls, input.Position) then return end
			State.Drone.LookTouch = input
			State.Drone.LastTouch = input.Position
		end)

		connect(UserInputService.InputChanged, function(input)
			if not MOBILE_DEVICE and State.Drone.Active and State.Drone.MouseLook
				and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Delta
				State.Drone.LookDelta = State.Drone.LookDelta + Vector2.new(delta.X, delta.Y)
				return
			end
			if input ~= State.Drone.LookTouch or not State.Drone.LastTouch then return end
			local delta = input.Position - State.Drone.LastTouch
			State.Drone.LastTouch = input.Position
			State.Drone.Yaw = State.Drone.Yaw - delta.X * 0.004
			State.Drone.Pitch = math.clamp(State.Drone.Pitch - delta.Y * 0.004, math.rad(-85), math.rad(85))
		end)

		connect(UserInputService.InputEnded, function(input)
			if not MOBILE_DEVICE and input.UserInputType == Enum.UserInputType.MouseButton2
				and State.Drone.Active and State.Drone.MouseLook then
				setDesktopDroneLook(false)
			end
			if input == State.Drone.LookTouch then
				State.Drone.LookTouch = nil
				State.Drone.LastTouch = nil
			end
			if input == State.Drone.VerticalInput then
				State.Drone.VerticalInput = nil
				State.Drone.Vertical = 0
			end
		end)

		connect(UserInputService.WindowFocusReleased, function()
			setDesktopDroneLook(false)
		end)

		connect(workspace.DescendantAdded, function(object)
			if Settings.XRay then applyXRayToPart(object) end
		end)

		connect(Players.PlayerRemoving, function(player)
			local cache = State.EspCache[player]
			if cache then
				for _, object in pairs(cache) do if object and object.Parent then object:Destroy() end end
				State.EspCache[player] = nil
			end
			local highlight = State.HighlightCache[player]
			if highlight then pcall(function() highlight:Destroy() end) end
			State.HighlightCache[player] = nil
			local character = player.Character
			if character then
				for part in pairs(State.HitboxOriginal) do
					if part and part:IsDescendantOf(character) then restoreHitboxPart(part) end
				end
			end
		end)

		local function bindPanicButton(object)
			if not object:IsA("TextButton") or object:GetAttribute("HexaAdvancedPanicBound") then return end
			local baseText = tostring(object:GetAttribute("BaseText") or object.Text or "")
			if string.find(string.upper(baseText), "MODO PÁNICO", 1, true) or string.find(string.upper(baseText), "PANIC MODE", 1, true) then
				object:SetAttribute("HexaAdvancedPanicBound", true)
				connect(object.MouseButton1Click, function() disableAll(true) end)
			end
		end
		for _, object in ipairs(ScreenGui:GetDescendants()) do bindPanicButton(object) end
		connect(ScreenGui.DescendantAdded, function(object) task.defer(function() if object and object.Parent then bindPanicButton(object) end end) end)

		connect(ScreenGui.AncestryChanged, function(_, parent)
			if parent == nil then cleanup() end
		end)

		connect(RunService.RenderStepped, function(dt)
			if State.Dead then return end
			local weaponFeatureActive = Settings.NoRecoil or Settings.RapidFire or Settings.NoSpread or Settings.AutoReload or Settings.InfiniteAmmo
				or Settings.FullAutoConversion or Settings.RangeExtender or Settings.DamageFalloffModifier
				or Settings.BulletVelocityModifier or Settings.ProjectileLifetimeExtender or Settings.SurfacePenetration
			local advancedFeatureActive = weaponFeatureActive or Settings.Fullbright or Settings.Hitbox or Settings.HeadHitbox
				or Settings.DroneCamera or Settings.Spin or Settings.AntiStun or Settings.AntiRagdoll
				or Settings.BoxESP or Settings.NameESP or Settings.HealthESP or Settings.ESPHighlight
			if not advancedFeatureActive then return end

			local now = os.clock()
			local weaponScanInterval = PERFORMANCE_MODE and 0.45 or 0.35
			local continuousWeaponInput = Settings.RapidFire or Settings.FullAutoConversion
			if weaponFeatureActive and (continuousWeaponInput or now - State.LastWeaponScan >= weaponScanInterval) then
				updateWeapons(now)
			end
			local fullbrightInterval = PERFORMANCE_MODE and 1.5 or (MOBILE_DEVICE and 0.8 or 1.0)
			if Settings.Fullbright and now - State.LastFullbrightUpdate >= fullbrightInterval then
				State.LastFullbrightUpdate = now
				applyFullbright()
			end
			local hitboxInterval = PERFORMANCE_MODE and 0.4 or 0.3
			if (Settings.Hitbox or Settings.HeadHitbox) and now - State.LastHitboxUpdate >= hitboxInterval then
				State.LastHitboxUpdate = now
				updateHitboxes()
			end
			if (Settings.DroneCamera or Settings.Spin) and now - State.LastCharacterControlUpdate >= 0.5 then
				State.LastCharacterControlUpdate = now
				applyCharacterControl()
			end
			if Settings.DroneCamera or State.Drone.Active then updateDrone(dt) end
			if Settings.Spin then updateSpin(dt) end
			local humanoidInterval = MOBILE_DEVICE and 0.1 or 0.14
			if (Settings.AntiStun or Settings.AntiRagdoll) and now - State.LastHumanoidUpdate >= humanoidInterval then
				State.LastHumanoidUpdate = now
				updateHumanoid()
			end
			local screenEspActive = Settings.BoxESP or Settings.NameESP or Settings.HealthESP
			local espInterval = PERFORMANCE_MODE and (MOBILE_DEVICE and (1 / 16) or (1 / 14)) or (1 / 20)
			if screenEspActive and now - State.LastEspRender >= espInterval then
				State.LastEspRender = now
				renderEsp()
			end
			local highlightInterval = PERFORMANCE_MODE and 0.6 or (MOBILE_DEVICE and 0.35 or 0.45)
			if Settings.ESPHighlight and now - State.LastHighlightUpdate >= highlightInterval then
				State.LastHighlightUpdate = now
				updateHighlights()
			end
		end)
	end, function(errorMessage)
		local trace = tostring(errorMessage)
		pcall(function()
			if debug and debug.traceback then trace = debug.traceback(trace, 2) end
		end)
		return trace
	end)

	if not moduleOk then
		warn("[H4SK / FUNCIONES ADICIONALES] " .. tostring(moduleError))
	end
end)

-- ================================================================
-- INSTANT HIT Y MODO JESÚS
-- Integrados usando la interfaz principal de HEXA X.
-- ================================================================
task.spawn(function()
	local essentialsOk, essentialsError = xpcall(function()
		local State = {
			Dead = false,
			InstantHitActive = false,
			JesusActive = false,
			Connections = {},
			Projectiles = setmetatable({}, {__mode = "k"}),
			LastProjectileUpdate = 0,
			LastJesusUpdate = 0,
		}

		local function connect(signal, callback)
			ConfigManager:AttachSignalCallback(signal, callback)
			local connection = signal:Connect(callback)
			table.insert(State.Connections, connection)
			return connection
		end

		local EssentialsCard = sectionCard(160)
		EssentialsCard.LayoutOrder = 22
		sectionTitle(EssentialsCard, "FUNCIONES ESENCIALES", UDim2.new(0, 16, 0, 14))

		local InstantHitButton = createToggleButton(EssentialsCard, "INSTANT HIT", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
		markVipControl(InstantHitButton)
		local JesusButton = createToggleButton(EssentialsCard, "MODO JESÚS (CAMINAR SOBRE AGUA)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))

		local JesusPart = Instance.new("Part")
		JesusPart.Name = "HexaJesusPlatform"
		JesusPart.Size = Vector3.new(12, 1, 12)
		JesusPart.Anchored = true
		JesusPart.Transparency = 1
		JesusPart.CanCollide = true
		JesusPart.CanTouch = false
		JesusPart.CanQuery = false
		local JesusRaycastParams = RaycastParams.new()
		JesusRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
		JesusRaycastParams.IgnoreWater = false

		local function isProjectile(part)
			if not part:IsA("BasePart") then return false end
			local lowered = string.lower(part.Name)
			return string.find(lowered, "bullet", 1, true) ~= nil
				or string.find(lowered, "projectile", 1, true) ~= nil
		end

		local function accelerateProjectile(part)
			if not part or not part.Parent or not isProjectile(part) then return end
			State.Projectiles[part] = true
			pcall(function()
				local velocity = part.CFrame.LookVector * 9999
				part.AssemblyLinearVelocity = velocity
				part.Velocity = velocity
			end)
		end

		local function scanProjectiles()
			task.spawn(function()
				local queue = workspace:GetChildren()
				local index = 1
				local processed = 0
				local batchSize = 70
				while State.InstantHitActive and index <= #queue do
					local object = queue[index]
					index += 1
					for _, child in ipairs(object:GetChildren()) do
						table.insert(queue, child)
					end
					if isProjectile(object) then
						State.Projectiles[object] = true
						accelerateProjectile(object)
					end
					processed += 1
					if processed >= batchSize then
						processed = 0
						task.wait()
					end
				end
				table.clear(queue)
			end)
		end

		local function updateJesusPlatform()
			if not State.JesusActive then
				JesusPart.Parent = nil
				return
			end
			local character = LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 then
				JesusPart.Parent = nil
				return
			end

			JesusRaycastParams.FilterDescendantsInstances = {character, JesusPart}
			local result = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), JesusRaycastParams)
			if result and result.Material == Enum.Material.Water then
				JesusPart.Position = Vector3.new(root.Position.X, result.Position.Y - 0.45, root.Position.Z)
				JesusPart.Parent = workspace
			else
				JesusPart.Parent = nil
			end
		end

		local function setInstantHit(enabled)
			if enabled == true and not HEXA_IS_VIP then
				requireVip()
				enabled = false
			end
			State.InstantHitActive = enabled == true
			setActive(InstantHitButton, State.InstantHitActive)
			if State.InstantHitActive then
				scanProjectiles()
			else
				table.clear(State.Projectiles)
			end
		end

		local function setJesus(enabled)
			State.JesusActive = enabled == true
			setActive(JesusButton, State.JesusActive)
			if not State.JesusActive then JesusPart.Parent = nil end
		end

		local function disableAll()
			setInstantHit(false)
			setJesus(false)
		end

		local function cleanup()
			if State.Dead then return end
			State.Dead = true
			disableAll()
			for _, connection in ipairs(State.Connections) do
				pcall(function() connection:Disconnect() end)
			end
			table.clear(State.Connections)
			if JesusPart then JesusPart:Destroy() end
		end

		do
			local handler = function()
				if not State.InstantHitActive and not requireVip() then return end
				setInstantHit(not State.InstantHitActive)
			end
			ConfigManager:SetToggleCallback(InstantHitButton, handler)
			connect(InstantHitButton.MouseButton1Click, handler)
		end
		do
			local handler = function() setJesus(not State.JesusActive) end
			ConfigManager:SetToggleCallback(JesusButton, handler)
			connect(JesusButton.MouseButton1Click, handler)
		end

		addVipStateListener(function(isVip)
			if State.Dead then return end
			if not isVip and State.InstantHitActive then setInstantHit(false) end
		end)

		connect(workspace.DescendantAdded, function(object)
			if State.InstantHitActive and isProjectile(object) then
				State.Projectiles[object] = true
				accelerateProjectile(object)
			end
		end)
		connect(workspace.DescendantRemoving, function(object)
			State.Projectiles[object] = nil
		end)

		local function bindPanicButton(object)
			if not object:IsA("TextButton") or object:GetAttribute("HexaEssentialsPanicBound") then return end
			local baseText = tostring(object:GetAttribute("BaseText") or object.Text or "")
			local upper = string.upper(baseText)
			if string.find(upper, "MODO PÁNICO", 1, true) or string.find(upper, "PANIC MODE", 1, true) then
				object:SetAttribute("HexaEssentialsPanicBound", true)
				connect(object.MouseButton1Click, disableAll)
			end
		end
		for _, object in ipairs(ScreenGui:GetDescendants()) do bindPanicButton(object) end
		connect(ScreenGui.DescendantAdded, function(object)
			task.defer(function()
				if object and object.Parent then bindPanicButton(object) end
			end)
		end)

		connect(ScreenGui.AncestryChanged, function(_, parent)
			if parent == nil then cleanup() end
		end)

		connect(RunService.Stepped, function()
			if State.Dead then return end
			if not State.JesusActive and not State.InstantHitActive then return end
			local now = os.clock()
			local jesusInterval = PERFORMANCE_MODE and (MOBILE_DEVICE and 0.06 or 0.075)
				or (MOBILE_DEVICE and 0.033 or 0.05)
			if State.JesusActive and now - State.LastJesusUpdate >= jesusInterval then
				State.LastJesusUpdate = now
				updateJesusPlatform()
			end

			local projectileInterval = PERFORMANCE_MODE and 0.1 or (MOBILE_DEVICE and 0.05 or 0.075)
			if State.InstantHitActive and now - State.LastProjectileUpdate >= projectileInterval then
				State.LastProjectileUpdate = now
				for projectile in pairs(State.Projectiles) do
					if projectile and projectile.Parent then
						accelerateProjectile(projectile)
					else
						State.Projectiles[projectile] = nil
					end
				end
			end
		end)
	end, function(errorMessage)
		local trace = tostring(errorMessage)
		pcall(function()
			if debug and debug.traceback then trace = debug.traceback(trace, 2) end
		end)
		return trace
	end)

	if not essentialsOk then
		warn("[H4SK / FUNCIONES ESENCIALES] " .. tostring(essentialsError))
	end
end)

DiscordButton.MouseButton1Click:Connect(function() local link="https://discord.gg/sewRzHAG5J" if setclipboard then setclipboard(link) elseif toclipboard then toclipboard(link) end DiscordButton.Text="¡ENLACE COPIADO AL PORTAPAPELES!" task.delay(2, function() DiscordButton.Text="UNIRSE AL DISCORD (COPIAR ENLACE)" end) end)
DropdownButton.MouseButton1Click:Connect(function() rebuildPlayerList(); DropdownList.Visible = not DropdownList.Visible end)
GotoButton.MouseButton1Click:Connect(function()
	local target = selectedTargetPlayer
	if not target or target == LocalPlayer or target.Parent ~= Players then return end
	while target.Parent == Players and not target.Character do task.wait(0.10) end
	while LocalPlayer.Parent == Players and not LocalPlayer.Character do task.wait(0.10) end
	local targetCharacter = target.Character
	local localCharacter = LocalPlayer.Character
	if not targetCharacter or not localCharacter then return end

	local targetPart = targetCharacter:FindFirstChild("HumanoidRootPart")
		or targetCharacter.PrimaryPart
		or targetCharacter:FindFirstChild("UpperTorso")
		or targetCharacter:FindFirstChild("Torso")
		or targetCharacter:FindFirstChild("Head")
		or targetCharacter:FindFirstChildWhichIsA("BasePart", true)
	local destination = nil
	if targetPart then
		destination = targetPart.CFrame + Vector3.new(0, 3, 0)
	else
		pcall(function() destination = targetCharacter:GetPivot() + Vector3.new(0, 3, 0) end)
	end
	if not destination then return end

	pcall(function()
		local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
		if localRoot then
			localRoot.AssemblyLinearVelocity = Vector3.zero
			localRoot.AssemblyAngularVelocity = Vector3.zero
		end
		localCharacter:PivotTo(destination)
	end)
end)
AllSliders.TrackConnection(UserInputService.JumpRequest:Connect(function() if infiniteJumpActive then local _, hum = getCharacterData() if hum and hum.Health > 0 then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end end end))

local tweenIn = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenOut = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local openingStyle = "BACK"

local function offsetPosition(position: UDim2, xOffset: number, yOffset: number)
	return UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset + yOffset)
end

local function getOpeningScale(gui: GuiObject)
	local scale = gui:FindFirstChild("HexaOpeningScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "HexaOpeningScale"
		scale.Scale = 1
		scale.Parent = gui
	end
	return scale
end

local function animateOpen(gui: GuiObject, targetSize: UDim2, forcedStyle: string?)
	local style = forcedStyle or openingStyle
	local targetPosition = gui.Position
	local scale = getOpeningScale(gui)
	gui.Visible = true
	gui.Size = targetSize
	gui.Rotation = 0
	scale.Scale = 1
	if PERFORMANCE_MODE then
		gui.Position = targetPosition
		return tween(gui, TweenInfo.new(0), {Size = targetSize})
	end

	if style == "BACK" then
		gui.Size = UDim2.new(0, 0, 0, 0)
		return tween(gui, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = targetSize})
	elseif style == "QUAD" then
		gui.Size = UDim2.new(0, 0, 0, 0)
		return tween(gui, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
	elseif style == "ELASTIC" then
		gui.Size = UDim2.new(0, 0, 0, 0)
		return tween(gui, TweenInfo.new(0.72, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = targetSize})
	elseif style == "BOUNCE" then
		gui.Size = UDim2.new(0, 0, 0, 0)
		return tween(gui, TweenInfo.new(0.58, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Size = targetSize})
	elseif style == "SLIDE_LEFT" or style == "SLIDE_RIGHT" or style == "SLIDE_UP" or style == "SLIDE_DOWN" then
		local xOffset, yOffset = 0, 0
		if style == "SLIDE_LEFT" then xOffset = -180
		elseif style == "SLIDE_RIGHT" then xOffset = 180
		elseif style == "SLIDE_UP" then yOffset = -140
		else yOffset = 140 end
		gui.Position = offsetPosition(targetPosition, xOffset, yOffset)
		scale.Scale = 0.94
		tween(scale, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale = 1})
		local movement = tween(gui, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetPosition})
		movement.Completed:Connect(function()
			if gui and gui.Parent then gui.Position = targetPosition end
		end)
		return movement
	elseif style == "ZOOM" then
		scale.Scale = 0.35
		return tween(scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	elseif style == "SPIN" then
		scale.Scale = 0.55
		gui.Rotation = -16
		tween(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
		return tween(gui, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0})
	elseif style == "PULSE" then
		scale.Scale = 0.72
		local first = tween(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.08})
		first.Completed:Connect(function()
			if scale and scale.Parent then tween(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}) end
		end)
		return first
	elseif style == "GLITCH" then
		scale.Scale = 0.92
		gui.Position = offsetPosition(targetPosition, -18, 6)
		gui.Rotation = -2
		local first = tween(gui, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {Position = offsetPosition(targetPosition, 15, -5), Rotation = 2})
		first.Completed:Connect(function()
			if not (gui and gui.Parent) then return end
			local second = tween(gui, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {Position = offsetPosition(targetPosition, -8, 3), Rotation = -1})
			second.Completed:Connect(function()
				if gui and gui.Parent then
					tween(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
					tween(gui, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetPosition, Rotation = 0})
				end
			end)
		end)
		return first
	elseif style == "DROP" then
		gui.Position = offsetPosition(targetPosition, 0, -220)
		gui.Rotation = 3
		scale.Scale = 0.96
		tween(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
		return tween(gui, TweenInfo.new(0.58, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Position = targetPosition, Rotation = 0})
	elseif style == "BURST" then
		scale.Scale = 0.12
		gui.Rotation = 10
		tween(gui, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0})
		return tween(scale, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	end

	gui.Size = UDim2.new(0, 0, 0, 0)
	return tween(gui, tweenIn, {Size = targetSize})
end

local function applyDeviceProfile(mode)
	MOBILE_DEVICE = mode == "MOBILE"
	MAIN_SIZE = calculateMainSize()

	-- Reubicar la GUI según el modo elegido. La selección manual prevalece sobre
	-- TouchEnabled/KeyboardEnabled para evitar perfiles híbridos incorrectos.
	pcall(function()
		if MOBILE_DEVICE then
			ScreenGui.Parent = PlayerGui
		else
			local target = nil
			if type(gethui) == "function" then
				local ok, hiddenUi = pcall(gethui)
				if ok then target = hiddenUi end
			end
			if not target then target = CoreGui or PlayerGui end
			ScreenGui.Parent = target
		end
		TargetParent = ScreenGui.Parent
	end)

	-- Cabecera más compacta en móvil y más espaciosa en PC.
	MainFrame.BackgroundTransparency = MOBILE_DEVICE and 0.10 or 0.18
	HeaderLogo.Size = MOBILE_DEVICE and UDim2.fromOffset(30, 30) or UDim2.fromOffset(36, 36)
	HeaderLogo.Position = MOBILE_DEVICE and UDim2.new(0, 12, 0, 14) or UDim2.new(0, 15, 0, 11)
	Title.Position = MOBILE_DEVICE and UDim2.new(0, 49, 0, 6) or UDim2.new(0, 59, 0, 5)
	Title.TextSize = MOBILE_DEVICE and 16 or 18
	local universalSubtitle = Header:FindFirstChild("HexaUniversalSubtitle")
	if universalSubtitle then
		universalSubtitle.Position = MOBILE_DEVICE and UDim2.new(0, 49, 0, 32) or UDim2.new(0, 59, 0, 32)
		universalSubtitle.TextSize = MOBILE_DEVICE and 9 or 10
	end

	if MOBILE_DEVICE then
		CategoryUI.Frame.Position = UDim2.new(0, 6, 0, 64)
		CategoryUI.Frame.Size = UDim2.new(1, -12, 0, 104)
		CategoryUI.Title.Visible = false
		FunctionSearchBox.Position = UDim2.new(0, 8, 0, 7)
		CategoryUI.Scroll.Position = UDim2.new(0, 8, 0, 43)
		CategoryUI.Scroll.Size = UDim2.new(1, -16, 1, -49)
		CategoryUI.Scroll.ScrollingDirection = Enum.ScrollingDirection.X
		CategoryUI.Scroll.ScrollBarThickness = 0
		CategoryUI.Layout.FillDirection = Enum.FillDirection.Horizontal
		CategoryUI.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		CategoryUI.Layout.VerticalAlignment = Enum.VerticalAlignment.Center
		CategoryUI.Layout.Padding = UDim.new(0, 6)
		Content.Position = UDim2.new(0, 2, 0, 172)
		Content.Size = UDim2.new(1, -4, 1, -174)
		Content.ScrollBarThickness = 6
		Content.AutomaticCanvasSize = Enum.AutomaticSize.None
	else
		CategoryUI.Frame.Position = UDim2.new(0, 6, 0, 64)
		CategoryUI.Frame.Size = UDim2.new(0, 158, 1, -70)
		CategoryUI.Title.Visible = true
		FunctionSearchBox.Position = UDim2.new(0, 8, 0, 29)
		CategoryUI.Scroll.Position = UDim2.new(0, 8, 0, 65)
		CategoryUI.Scroll.Size = UDim2.new(1, -16, 1, -71)
		CategoryUI.Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		CategoryUI.Scroll.ScrollBarThickness = 3
		CategoryUI.Layout.FillDirection = Enum.FillDirection.Vertical
		CategoryUI.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		CategoryUI.Layout.VerticalAlignment = Enum.VerticalAlignment.Top
		CategoryUI.Layout.Padding = UDim.new(0, 2)
		Content.Position = UDim2.new(0, 168, 0, 62)
		Content.Size = UDim2.new(1, -170, 1, -64)
		Content.ScrollBarThickness = 4
		Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	end

	for _, definition in ipairs(CategoryUI.Definitions) do
		local button = CategoryUI.Buttons[definition.Key]
		if button then
			local hiddenForDevice = (MOBILE_DEVICE and definition.Key == "KEYBINDS")
				or ((not MOBILE_DEVICE) and definition.Key == "FLOATING")
			button.Visible = not hiddenForDevice
			button.Size = MOBILE_DEVICE
				and UDim2.fromOffset(math.max(92, #definition.Label * 6 + 46), 33)
				or UDim2.new(1, -8, 0, 27)
			local corner = button:FindFirstChildOfClass("UICorner")
			if corner then corner.CornerRadius = UDim.new(0, MOBILE_DEVICE and 15 or 13) end
		end
	end
	if MOBILE_DEVICE and CategoryUI.Active == "KEYBINDS" then CategoryUI.Active = "ALL" end
	if (not MOBILE_DEVICE) and CategoryUI.Active == "FLOATING" then CategoryUI.Active = "ALL" end
	CategoryUI:RefreshButtons()
	if KeybindManager and KeybindManager.Card then KeybindManager.Card.Visible = not MOBILE_DEVICE end
	if FloatingButtonManager and FloatingButtonManager.Card then FloatingButtonManager.Card.Visible = MOBILE_DEVICE end
	if FloatingButtonManager then FloatingButtonManager:RefreshAll() end

	CombatCard.Size = UDim2.new(1, 0, 0, 394)
	CombatCard:SetAttribute("HexaMobileBaseHeight", 394)
	MobileAim.OptionButton.Visible = true
	if not MOBILE_DEVICE then
		MobileAim.Enabled = false
		setActive(MobileAim.OptionButton, false)
		Runtime.mobileAimTouchActive = false
		Runtime.mobileAimTouchInput = nil
	end
	MobileAim:Refresh()
	setMobileFlyControlsVisible(MOBILE_DEVICE and flyActive)
	refreshDeviceSpecificTexts()
	refreshFavoritesCard()

	if Tutorial and Tutorial.Scroll then Tutorial.Scroll.ScrollBarThickness = MOBILE_DEVICE and 6 or 4 end
	if Tutorial and Tutorial.Text then Tutorial.Text.TextSize = MOBILE_DEVICE and 12 or 13 end

	CategoryUI.Scroll.CanvasPosition = Vector2.new(0, 0)
	Content.CanvasPosition = Vector2.new(0, 0)
	task.defer(function()
		refreshCategoryCanvas()
		refreshCategoryView()
		if MOBILE_DEVICE then refreshMobileCanvas() end
	end)
end

local function openDeviceSelector()
	KeyFrame.Visible = false
	MainFrame.Visible = false
	DeviceSelector.Frame.Visible = true
	DeviceSelector.Size = DeviceSelector:GetSize()
	DeviceSelector.Frame.Size = UDim2.new(0, 0, 0, 0)
	animateOpen(DeviceSelector.Frame, DeviceSelector.Size, "BACK")
end

local function openMainInterface()
	KeyFrame.Visible = false
	DeviceSelector.Frame.Visible = false
	MainFrame.Visible = true
	animateOpen(MainFrame, MAIN_SIZE)
end

local function chooseDevice(mode)
	local t = tween(DeviceSelector.Frame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
	t.Completed:Connect(function()
		applyDeviceProfile(mode)
		openMainInterface()
	end)
end

DeviceSelector.PCButton.MouseButton1Click:Connect(function() chooseDevice("PC") end)
DeviceSelector.MobileButton.MouseButton1Click:Connect(function() chooseDevice("MOBILE") end)

CheckKeyBtn.MouseButton1Click:Connect(function()
	local entered = tostring(KeyBox.Text or "")
	if entered == "ikaH" then
		local t = tween(KeyFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
		t.Completed:Connect(openDeviceSelector)
	else
		KeyBox.Text = ""
		KeyBox.PlaceholderText = "¡Clave incorrecta!"
		task.delay(1.5, function()
			KeyBox.PlaceholderText = Lang.Current == "EN" and "Enter the key" or "Escribe la key"
		end)
	end
end)

GetKeyBtn.MouseButton1Click:Connect(function()
	local link = "https://discord.gg/sewRzHAG5J"
	if setclipboard then setclipboard(link) elseif toclipboard then toclipboard(link) end
	GetKeyBtn.Text = Lang.Current == "EN" and "COPIED!" or "¡COPIADO!"

	vipNotificationGeneration += 1
	local generation = vipNotificationGeneration
	VipNotificationTitle.Text = "H3X4 X"
	VipNotificationTitle.TextColor3 = Theme.PurpleText
	VipNotificationText.Text = Lang.Current == "EN" and "Copied successfully, go to the #🔑・key channel" or "Copiado correctamente, ve Al canal #🔑・key"
	tween(VipNotification, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18)
	})
	task.delay(3.2, function()
		if generation ~= vipNotificationGeneration or not VipNotification.Parent then return end
		tween(VipNotification, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -100)
		})
	end)

	task.delay(1.5, function()
		GetKeyBtn.Text = Lang.Current == "EN" and "Get key (Discord)" or "Obtener clave (Discord)"
	end)
end)

Runtime.loopConn = RunService.Stepped:Connect(function()
	if not speedActive and not jumpActive and not noclipActive and next(Runtime.noclipCache) == nil then return end
	local char, hum = getCharacterData()
	if not char or not hum or hum.Health <= 0 then return end
	if speedActive and hum.WalkSpeed ~= currentSpeed then pcall(function() hum.WalkSpeed = currentSpeed end) end
	if jumpActive and (not hum.UseJumpPower or hum.JumpPower ~= currentJump) then
		pcall(function() hum.UseJumpPower = true; hum.JumpPower = currentJump end)
	end
	if noclipActive then
		local now = os.clock()
		local interval = PERFORMANCE_MODE and (MOBILE_DEVICE and (1 / 30) or (1 / 24)) or (1 / 30)
		if now - Runtime.lastNoclipUpdate >= interval then
			Runtime.lastNoclipUpdate = now
			Runtime.updateNoclip(char, now)
		end
	else
		if next(Runtime.noclipCache) ~= nil then restoreNoclip() end
	end
end)

Runtime.espConn = RunService.RenderStepped:Connect(function()
	if not espSkeletonActive and not espLinesActive then
		if Runtime.baseEspVisible then
			Runtime.baseEspVisible = false
			for _, cache in pairs(espCache) do
				cache.Tracer.Visible = false
				for _, bone in ipairs(cache.Skel) do bone.Visible = false end
			end
		end
		return
	end
	local now = os.clock()
	local renderInterval = PERFORMANCE_MODE and (MOBILE_DEVICE and (1 / 18) or (1 / 16))
		or (MOBILE_DEVICE and (1 / 22) or (1 / 20))
	if now - Runtime.lastBaseEspRender < renderInterval then return end
	Runtime.lastBaseEspRender = now
	Runtime.baseEspVisible = true
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vX, vY = cam.ViewportSize.X, cam.ViewportSize.Y
	local _, _, localRoot = getCharacterData()
	local createdCaches = 0
	local cacheCreationLimit = 1

	for _, player in ipairs(Runtime.playerSnapshot) do
		if player == LocalPlayer then continue end
		if not espCache[player] then
			if createdCaches >= cacheCreationLimit then continue end
			espCache[player] = { Tracer = getEspFrame("Tracer"), Skel = {} }
			createdCaches += 1
		end
		
		local cache = espCache[player]
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
		if not passesTeamCheck(player) or not hum or hum.Health <= 0 or not targetRoot then
			cache.Tracer.Visible = false
			for _, bone in ipairs(cache.Skel) do bone.Visible = false end
			continue
		end
		local drawTracers, drawBones, skelIndex = false, false, 1

		if char and hum and hum.Health > 0 then
			local inRange = true
			
			if targetRoot and localRoot then
				local dist = (targetRoot.Position - localRoot.Position).Magnitude
				if dist > maxEspDistance then
					inRange = false
				end
			end

			if inRange then
				if espLinesActive then
					if targetRoot then
						local pos, onScreen = cam:WorldToViewportPoint(targetRoot.Position)
						if onScreen then
							drawUILine(cache.Tracer, Vector2.new(vX / 2, vY), Vector2.new(pos.X, pos.Y))
							cache.Tracer.Visible = true; drawTracers = true
						end
					end
				end
				if espSkeletonActive then
					local isR15 = hum.RigType == Enum.HumanoidRigType.R15
					local connections = isR15 and r15Bones or r6Bones
					local projectedParts = {}
					local function project(part)
						local cached = projectedParts[part]
						if cached then return cached.Position, cached.OnScreen end
						local position, onScreen = cam:WorldToViewportPoint(part.Position)
						local result = {Position = Vector2.new(position.X, position.Y), OnScreen = onScreen and position.Z > 0}
						projectedParts[part] = result
						return result.Position, result.OnScreen
					end
					for _, conn in ipairs(connections) do
						local p1 = char:FindFirstChild(conn[1])
						local p2 = char:FindFirstChild(conn[2])
						if p1 and p2 then
							local pos1, on1 = project(p1)
							local pos2, on2 = project(p2)
							if on1 or on2 then
								local f = cache.Skel[skelIndex]
								if not f then f = getEspFrame("Bone"); cache.Skel[skelIndex] = f end
								drawUILine(f, pos1, pos2)
								f.Visible = true; skelIndex += 1; drawBones = true
							end
						end
					end
				end
			end
		end
		if not drawTracers then cache.Tracer.Visible = false end
		if not drawBones then skelIndex = 1 end
		for i = skelIndex, #cache.Skel do cache.Skel[i].Visible = false end
	end
end)

Runtime.renderConn = RunService.RenderStepped:Connect(function()
	-- El botón flotante móvil acciona los mismos toggles del Aimbot normal, por
	-- lo que el estado queda incluido en Guardar/Cargar configuración.
	local smoothingOnlyActive = HexaSharedTargetFilters.AimSmoothing
		and not autoAimHeadActive
		and not autoAimBodyActive
	local isHeadActive = autoAimHeadActive or smoothingOnlyActive
	local isBodyActive = autoAimBodyActive

	if isHeadActive or isBodyActive then
		Runtime.aimWasActive = true
		local now = os.clock()
		if not MOBILE_DEVICE then
			local aimRenderInterval = PERFORMANCE_MODE and (1 / 60) or (1 / 120)
			if now - Runtime.lastAimRender < aimRenderInterval then return end
			Runtime.lastAimRender = now
		end
		local scanInterval = PERFORMANCE_MODE and (MOBILE_DEVICE and (1 / 30) or (1 / 24)) or (1 / 30)
		if now - Runtime.lastAimScan >= scanInterval or Runtime.cachedAimAtHead ~= isHeadActive then
			Runtime.lastAimScan = now
			Runtime.cachedAimAtHead = isHeadActive
			Runtime.cachedAimCandidate = getClosestPlayer(isHeadActive)
			Runtime.cachedResolvedAimTarget = Runtime.resolveAimbotTarget(Runtime.cachedAimCandidate, isHeadActive)
		end
		local targetPlayer = Runtime.cachedResolvedAimTarget
		if HexaSharedTargetFilters:AllowsPlayer(targetPlayer, true) and targetPlayer.Character then
			local targetPart
			if isHeadActive then
				targetPart = targetPlayer.Character:FindFirstChild("Head") or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			else
				targetPart = targetPlayer.Character:FindFirstChild("UpperTorso")
					or targetPlayer.Character:FindFirstChild("Torso")
					or targetPlayer.Character:FindFirstChild("LowerTorso")
					or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			end
			if targetPart and passesWallCheck(targetPart) then
				if AimHighlight.Adornee ~= targetPlayer.Character then AimHighlight.Adornee = targetPlayer.Character end
				local cam = workspace.CurrentCamera
				if cam then
					local targetPosition = targetPart.Position
					if HexaSharedTargetFilters.TargetPrediction then
						pcall(function()
							targetPosition = targetPosition + targetPart.AssemblyLinearVelocity * HexaSharedTargetFilters.PredictionFactor
						end)
					end
					Runtime.currentAimWorldPosition = targetPosition
					Runtime.currentAimSmoothing = HexaSharedTargetFilters.AimSmoothing
					local targetCFrame = CFrame.new(cam.CFrame.Position, targetPosition)
					if HexaSharedTargetFilters.AimSmoothing then
						cam.CFrame = cam.CFrame:Lerp(targetCFrame, 1 / HexaSharedTargetFilters.SmoothingFactor)
					else
						cam.CFrame = targetCFrame
					end
				end
			else
				if AimHighlight.Adornee ~= nil then AimHighlight.Adornee = nil end
				Runtime.currentAimWorldPosition = nil
			end
		else
			if AimHighlight.Adornee ~= nil then AimHighlight.Adornee = nil end
			Runtime.currentAimWorldPosition = nil
		end
	elseif Runtime.aimWasActive then
		Runtime.aimWasActive = false
		Runtime.cachedAimCandidate = nil
		Runtime.cachedResolvedAimTarget = nil
		Runtime.cachedAimAtHead = nil
		Runtime.lastAimScan = 0
		Runtime.lastAimRender = 0
		Runtime.resetAimbotTargetSwitching()
		Runtime.currentAimWorldPosition = nil
		if AimHighlight.Adornee ~= nil then AimHighlight.Adornee = nil end
	end
end)

pcall(function()
	RunService:UnbindFromRenderStep("H3X4X_WeaponLock")
	RunService:UnbindFromRenderStep("H3X4X_AimWeaponLock")
end)
RunService:BindToRenderStep(
	"H3X4X_WeaponLock",
	Enum.RenderPriority.Camera.Value + 20,
	function()
		if not Runtime.weaponLockEnabled then
			if Runtime.weaponLockInputCaptured then Runtime.releaseWeaponLockInput(true) end
			if not MOBILE_DEVICE and os.clock() < Runtime.weaponLockReleaseUntil then
				pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
				pcall(function() UserInputService.MouseIconEnabled = true end)
				pcall(function()
					if UserInputService.MouseDeltaSensitivity <= 0 then
						UserInputService.MouseDeltaSensitivity = 1
					end
				end)
			end
			return
		end
		if Runtime.currentAimWorldPosition == nil then
			if Runtime.weaponLockInputCaptured then Runtime.releaseWeaponLockInput(false) end
			return
		end
		Runtime.captureWeaponLockInput()
		Runtime.enforceWeaponLockInput()
		if workspace.CurrentCamera then
			local targetCFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, Runtime.currentAimWorldPosition)
			if Runtime.currentAimSmoothing then
				workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(
					targetCFrame,
					1 / HexaSharedTargetFilters.SmoothingFactor
				)
			else
				workspace.CurrentCamera.CFrame = targetCFrame
			end
		end
	end
)

ScreenGui.Destroying:Connect(function()
	Runtime.weaponLockEnabled = false
	Runtime.releaseWeaponLockInput(true)
	pcall(function()
		RunService:UnbindFromRenderStep("H3X4X_WeaponLock")
		RunService:UnbindFromRenderStep("H3X4X_AimWeaponLock")
	end)
end)

Runtime.charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
	local hum = newChar:WaitForChild("Humanoid", 5)
	local root = newChar:WaitForChild("HumanoidRootPart", 5)
	if not hum or not root then return end
	table.clear(Runtime.noclipCache)
	Runtime.character, Runtime.humanoid, Runtime.root = newChar, hum, root
	Runtime.lastNoclipScan = 0
	if speedActive then pcall(function() hum.WalkSpeed = currentSpeed end) end
	if jumpActive then pcall(function() hum.UseJumpPower = true; hum.JumpPower = currentJump end) end
	if flyActive then ensureFly() end
end)

UI_READY = true
task.defer(function()
	registerAllFunctionButtons()
	refreshCategoryView()
end)

-- Flujo de acceso:
--   VIP  -> selector PC/CELULAR directamente (sin pedir key).
--   FREE -> key de inicio -> selector PC/CELULAR.
-- Si la primera consulta remota no marcó VIP, hacemos un reintento antes de
-- mostrar la key para evitar falsos FREE por un fallo temporal de red.
local startupIsVip = HEXA_IS_VIP
if not startupIsVip then
	local refreshed = RemoteVipState:Refresh()
	if refreshed then
		syncVipAccessFromGithub()
		startupIsVip = HEXA_IS_VIP
	end
end

MainFrame.Visible = false
DeviceSelector.Frame.Visible = false
if startupIsVip then
	KeyFrame.Visible = false
	task.defer(openDeviceSelector)
else
	KeyFrame.Visible = true
	animateOpen(KeyFrame, KEY_SIZE, "BACK")
end

local minimized = false
MinButton.MouseButton1Click:Connect(function()
	if minimized then return end
	minimized = true
	local t = tween(MainFrame, tweenOut, {Size = UDim2.new(0, 0, 0, 0)})
	t.Completed:Connect(function()
		if not minimized then return end
		MainFrame.Visible = false
		RestoreOrb.Visible = true
		tween(RestoreOrb, tweenIn, {Size = UDim2.new(0, 58, 0, 58)})
	end)
end)

RestoreOrb.MouseButton1Click:Connect(function()
	if not minimized then return end
	minimized = false
	local t = tween(RestoreOrb, tweenOut, {Size = UDim2.new(0, 0, 0, 0)})
	t.Completed:Connect(function()
		if minimized then return end
		RestoreOrb.Visible = false
		MainFrame.Visible = true
		animateOpen(MainFrame, MAIN_SIZE)
	end)
end)

TutorialBtn.MouseButton1Click:Connect(function()
	animateOpen(Tutorial.Frame, Tutorial.getTargetSize(), "BACK")
end)

Tutorial.CloseButton.MouseButton1Click:Connect(function()
	local closeTutorial = tween(Tutorial.Frame, tweenOut, {Size = UDim2.new(0, 0, 0, 0)})
	closeTutorial.Completed:Connect(function()
		Tutorial.Frame.Visible = false
	end)
end)

CloseButton.MouseButton1Click:Connect(function()
	ConfirmFrame.Visible = true
	animateOpen(ConfirmFrame, UDim2.new(0, 280, 0, 140))
	tween(MainFrame, tweenOut, {Size = UDim2.new(0, 0, 0, 0)})
	task.delay(0.35, function() MainFrame.Visible = false end)
end)

NoBtn.MouseButton1Click:Connect(function()
	local t = tween(ConfirmFrame, tweenOut, {Size = UDim2.new(0, 0, 0, 0)})
	MainFrame.Visible = true
	animateOpen(MainFrame, MAIN_SIZE)
	t.Completed:Connect(function()
		ConfirmFrame.Visible = false
	end)
end)

YesBtn.MouseButton1Click:Connect(function()
	local t = tween(ConfirmFrame, tweenOut, {Size = UDim2.new(0, 0, 0, 0)})
	t.Completed:Connect(function()
		cleanupMovement()
		if Runtime.loopConn then Runtime.loopConn:Disconnect() end
		if Runtime.espConn then Runtime.espConn:Disconnect() end
		if Runtime.renderConn then Runtime.renderConn:Disconnect() end
		if Runtime.charAddedConn then Runtime.charAddedConn:Disconnect() end
		Runtime.weaponLockEnabled = false
		Runtime.releaseWeaponLockInput(true)
		pcall(function()
			RunService:UnbindFromRenderStep("H3X4X_WeaponLock")
			RunService:UnbindFromRenderStep("H3X4X_AimWeaponLock")
		end)
		if ScreenGui then ScreenGui:Destroy() end
	end)
end)
task.spawn(function()
	local success, errorMessage = pcall(function()
		local Lighting = game:GetService("Lighting")
		local TeleportService = game:GetService("TeleportService")
		local VirtualUser = game:GetService("VirtualUser")
		local VirtualInputManager = nil
		pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
		local Stats = game:GetService("Stats")

		local X = {
			Dead = false,
			Connections = {},
			Resetters = {},
			CrosshairEnabled = false,
			CrosshairRainbow = false,
			CrosshairSize = 14,
			CrosshairThickness = 2,
			CrosshairGap = 5,
			CrosshairColorIndex = 1,
			CrosshairStyle = "CRUZ",
			CrosshairColors = {
				Color3.fromRGB(255, 255, 255),
				Color3.fromRGB(255, 65, 65),
				Color3.fromRGB(65, 255, 120),
				Color3.fromRGB(70, 160, 255),
				Color3.fromRGB(255, 220, 60),
				Color3.fromRGB(205, 90, 255),
			},
			GravityDefault = workspace.Gravity,
			AirWalk = false,
			BunnyHop = false,
			NoFall = false,
			SavedPosition = nil,
			MouseTeleport = false,
			MouseTeleportArmedAt = 0,
			TeleportHistory = {},
			MaxTeleportHistory = 12,
			FpsEnabled = false,
			PingEnabled = false,
			ClockEnabled = false,
			CoordsEnabled = false,
			SpeedEnabled = false,
			AntiAfk = false,
			AutoRespawn = false,
			AutoEquip = false,
			Performance = false,
			Streamer = false,
			FogRemoved = false,
			BlurRemoved = false,
			ShadowsRemoved = false,
			ThirdPerson = false,
			FirstPerson = false,
			FogBackup = {Start = Lighting.FogStart, Finish = Lighting.FogEnd},
			ShadowBackup = Lighting.GlobalShadows,
			AtmosphereBackup = {},
			BlurBackup = {},
			AnimationIndex = 1,
			FontIndex = 1,
			LastInfoUpdate = 0,
			LastVisualUpdate = 0,
			LastMovementUpdate = 0,
			LastPlayerToolsUpdate = 0,
			LastAutoEquip = 0,
			Frames = 0,
			LastFpsTime = os.clock(),
			CurrentFps = 0,
			FollowPlayer = false,
			FollowDistance = 8,
			LastFollowUpdate = 0,
			AntiVoid = false,
			LastSafeCFrame = nil,
			LastSafeUpdate = 0,
			AntiVoidCooldown = 0,
			Spectating = false,
			InspectorEnabled = false,
			LastInspectorUpdate = 0,
		}

		function X:connect(signal, callback)
			ConfigManager:AttachSignalCallback(signal, callback)
			local connection = signal:Connect(callback)
			table.insert(self.Connections, connection)
			return connection
		end

		function X:bindToggle(button, callback)
			ConfigManager:SetToggleCallback(button, callback)
			return self:connect(button.MouseButton1Click, callback)
		end

		function X:addReset(callback)
			table.insert(self.Resetters, callback)
		end

		function X:toggle(button, state)
			pcall(function()
				setActive(button, state)
			end)
		end

		function X:getCharacter()
			local character = LocalPlayer.Character
			if not character then return nil, nil, nil end
			return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
		end

		function X:makeCard(height, title)
			local card = sectionCard(height)
			local titleLabel = sectionTitle(card, title, UDim2.new(0, 16, 0, 14))
			return card, titleLabel
		end

		function X:setupCrosshair()
			self.CrosshairCard, self.CrosshairTitle = self:makeCard(394, "MIRA PERSONALIZADA")
			self.CrosshairCard.LayoutOrder = 32
			self.CrosshairOverlay = Instance.new("Frame")
			self.CrosshairOverlay.Name = "HexaCustomCrosshair"
			self.CrosshairOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
			self.CrosshairOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
			self.CrosshairOverlay.Size = UDim2.new(0, 1, 0, 1)
			self.CrosshairOverlay.BackgroundTransparency = 1
			self.CrosshairOverlay.Visible = false
			self.CrosshairOverlay.ZIndex = 100
			self.CrosshairOverlay.Parent = ScreenGui

			self.CrosshairLines = {}
			for i = 1, 4 do
				local line = Instance.new("Frame")
				line.Name = "Linea" .. i
				line.BorderSizePixel = 0
				line.ZIndex = 100
				line.Visible = false
				line.Parent = self.CrosshairOverlay
				self.CrosshairLines[i] = line
			end

			self.CrosshairDot = Instance.new("Frame")
			self.CrosshairDot.Name = "Punto"
			self.CrosshairDot.AnchorPoint = Vector2.new(0.5, 0.5)
			self.CrosshairDot.Position = UDim2.new(0, 0, 0, 0)
			self.CrosshairDot.BorderSizePixel = 0
			self.CrosshairDot.Visible = false
			self.CrosshairDot.ZIndex = 100
			self.CrosshairDot.Parent = self.CrosshairOverlay
			mkCorner(self.CrosshairDot, 999)

			self.CrosshairButton = createToggleButton(self.CrosshairCard, "ACTIVAR MIRA PERSONALIZADA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.CrosshairStyleButton = neonButton(self.CrosshairCard, "TIPO DE MIRA: CRUZ", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
			self.CrosshairColorButton = neonButton(self.CrosshairCard, "COLOR DE LA MIRA: BLANCO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
			self.CrosshairSizeSlider = createSlider(self.CrosshairCard, "Tamaño de la mira", 4, 50, self.CrosshairSize, 182, function(value)
				self.CrosshairSize = value
				self:updateCrosshair()
			end, true)
			self.CrosshairThicknessSlider = createSlider(self.CrosshairCard, "Grosor de la mira", 1, 10, self.CrosshairThickness, 234, function(value)
				self.CrosshairThickness = value
				self:updateCrosshair()
			end, true)
			self.CrosshairGapSlider = createSlider(self.CrosshairCard, "Espacio de la mira", 0, 30, self.CrosshairGap, 286, function(value)
				self.CrosshairGap = value
				self:updateCrosshair()
			end, true)
			self.CrosshairRainbowButton = createToggleButton(self.CrosshairCard, "MIRA ARCOÍRIS", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 340))
			-- El tipo de mira (CRUZ/PUNTO) está disponible también para usuarios FREE.
			markVipControl(self.CrosshairColorButton)
			markVipControl(self.CrosshairRainbowButton)

			self:bindToggle(self.CrosshairButton, function()
				self.CrosshairEnabled = not self.CrosshairEnabled
				self:toggle(self.CrosshairButton, self.CrosshairEnabled)
				self:updateCrosshair()
			end)
			self:connect(self.CrosshairStyleButton.MouseButton1Click, function()
				self.CrosshairStyle = self.CrosshairStyle == "CRUZ" and "PUNTO" or "CRUZ"
				self.CrosshairStyleButton.Text = "TIPO DE MIRA: " .. self.CrosshairStyle
				self:updateCrosshair()
			end)
			self:connect(self.CrosshairColorButton.MouseButton1Click, function()
				if not requireVip() then return end
				self.CrosshairColorIndex = self.CrosshairColorIndex % #self.CrosshairColors + 1
				local nombres = {"BLANCO", "ROJO", "VERDE", "AZUL", "AMARILLO", "MORADO"}
				self.CrosshairColorButton.Text = "COLOR DE LA MIRA: " .. nombres[self.CrosshairColorIndex]
				self:updateCrosshair()
			end)
			self:bindToggle(self.CrosshairRainbowButton, function()
				if not requireVip() then return end
				self.CrosshairRainbow = not self.CrosshairRainbow
				self:toggle(self.CrosshairRainbowButton, self.CrosshairRainbow)
				self:updateCrosshair()
			end)
			self:updateCrosshair()
			self:addReset(function()
				self.CrosshairEnabled = false
				self.CrosshairRainbow = false
				self:toggle(self.CrosshairButton, false)
				self:toggle(self.CrosshairRainbowButton, false)
				self:updateCrosshair()
			end)
		end

		function X:updateCrosshair()
			if not self.CrosshairOverlay or not self.CrosshairOverlay.Parent then return end
			local size = math.max(1, self.CrosshairSize)
			local thickness = math.max(1, self.CrosshairThickness)
			local gap = math.max(0, self.CrosshairGap)
			local color = self.CrosshairColors[self.CrosshairColorIndex]
			local showCross = self.CrosshairEnabled and self.CrosshairStyle == "CRUZ"
			local showDot = self.CrosshairEnabled and self.CrosshairStyle == "PUNTO"

			self.CrosshairLines[1].Size = UDim2.new(0, size, 0, thickness)
			self.CrosshairLines[1].Position = UDim2.new(0, gap, 0, -math.floor(thickness / 2))
			self.CrosshairLines[2].Size = UDim2.new(0, size, 0, thickness)
			self.CrosshairLines[2].Position = UDim2.new(0, -(gap + size), 0, -math.floor(thickness / 2))
			self.CrosshairLines[3].Size = UDim2.new(0, thickness, 0, size)
			self.CrosshairLines[3].Position = UDim2.new(0, -math.floor(thickness / 2), 0, gap)
			self.CrosshairLines[4].Size = UDim2.new(0, thickness, 0, size)
			self.CrosshairLines[4].Position = UDim2.new(0, -math.floor(thickness / 2), 0, -(gap + size))

			for _, line in ipairs(self.CrosshairLines) do
				line.BackgroundColor3 = color
				line.Visible = showCross
			end
			self.CrosshairDot.Size = UDim2.new(0, size, 0, size)
			self.CrosshairDot.BackgroundColor3 = color
			self.CrosshairDot.Visible = showDot
			self.CrosshairOverlay.Visible = self.CrosshairEnabled
		end

		function X:setupMovementExtra()
			self.MoveExtraCard, self.MoveExtraTitle = self:makeCard(332, "MOVIMIENTO EXTRA")
			self.MoveExtraCard.LayoutOrder = 11
			self.GravitySlider = createSlider(self.MoveExtraCard, "Gravedad", 0, 300, math.floor(self.GravityDefault + 0.5), 42, function(value)
				workspace.Gravity = value
			end)
			self.ResetGravityButton = neonButton(self.MoveExtraCard, "RESTABLECER GRAVEDAD", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 95))
			self.AirWalkButton = createToggleButton(self.MoveExtraCard, "CAMINATA AÉREA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 141))
			self.BunnyHopButton = createToggleButton(self.MoveExtraCard, "SALTO DE CONEJO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 187))
			self.NoFallButton = createToggleButton(self.MoveExtraCard, "SIN DAÑO POR CAÍDA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 233))
			markVipControl(self.NoFallButton)
			self.AntiVoidButton = createToggleButton(self.MoveExtraCard, "ANTI VOID", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 279))

			self:connect(self.ResetGravityButton.MouseButton1Click, function()
				workspace.Gravity = self.GravityDefault
				self.GravitySlider.Set(self.GravityDefault)
			end)
			self:bindToggle(self.AirWalkButton, function()
				self.AirWalk = not self.AirWalk
				self:toggle(self.AirWalkButton, self.AirWalk)
				if not self.AirWalk then self:destroyAirWalk() end
			end)
			self:bindToggle(self.BunnyHopButton, function()
				self.BunnyHop = not self.BunnyHop
				self:toggle(self.BunnyHopButton, self.BunnyHop)
			end)
			self:bindToggle(self.NoFallButton, function()
				if not requireVip() then return end
				self.NoFall = not self.NoFall
				self:toggle(self.NoFallButton, self.NoFall)
			end)
			self:bindToggle(self.AntiVoidButton, function()
				self.AntiVoid = not self.AntiVoid
				self.LastSafeCFrame = nil
				self.LastSafeUpdate = 0
				self:toggle(self.AntiVoidButton, self.AntiVoid)
			end)
			self:addReset(function()
				self.AirWalk = false
				self.BunnyHop = false
				self.NoFall = false
				self.AntiVoid = false
				self.LastSafeCFrame = nil
				self.LastSafeUpdate = 0
				workspace.Gravity = self.GravityDefault
				self:destroyAirWalk()
				self:toggle(self.AirWalkButton, false)
				self:toggle(self.BunnyHopButton, false)
				self:toggle(self.NoFallButton, false)
				self:toggle(self.AntiVoidButton, false)
			end)
		end

		function X:destroyAirWalk()
			if self.AirWalkPlatform then
				self.AirWalkPlatform:Destroy()
				self.AirWalkPlatform = nil
			end
		end

		function X:updateMovementExtra()
			if not self.AirWalk and not self.BunnyHop and not self.NoFall then
				if self.AirWalkPlatform then self:destroyAirWalk() end
				return
			end
			local _, humanoid, root = self:getCharacter()
			if not humanoid or not root or humanoid.Health <= 0 then
				self:destroyAirWalk()
				return
			end
			if self.AirWalk then
				if not self.AirWalkPlatform or not self.AirWalkPlatform.Parent then
					self.AirWalkPlatform = Instance.new("Part")
					self.AirWalkPlatform.Name = "HexaAirWalk"
					self.AirWalkPlatform.Anchored = true
					self.AirWalkPlatform.CanCollide = true
					self.AirWalkPlatform.Transparency = 1
					self.AirWalkPlatform.Size = Vector3.new(7, 0.35, 7)
					self.AirWalkPlatform.Parent = workspace
				end
				self.AirWalkPlatform.CFrame = CFrame.new(root.Position.X, root.Position.Y - 3.15, root.Position.Z)
			end
			if self.BunnyHop and humanoid.MoveDirection.Magnitude > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
				humanoid.Jump = true
			end
			if self.NoFall and root.AssemblyLinearVelocity.Y < -24 then
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, -24, velocity.Z)
			end
		end

		function X:setupPlayerVisuals()
			self.PlayerCard, self.PlayerTitle = self:makeCard(294, "JUGADOR Y CÁMARA")
			self.PlayerCard.LayoutOrder = 50
			self.RemoveFogButton = createToggleButton(self.PlayerCard, "ELIMINAR NIEBLA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.RemoveBlurButton = createToggleButton(self.PlayerCard, "ELIMINAR DESENFOQUE", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
			self.RemoveShadowsButton = createToggleButton(self.PlayerCard, "ELIMINAR SOMBRAS", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
			self.ThirdPersonButton = createToggleButton(self.PlayerCard, "FORZAR TERCERA PERSONA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 182))
			self.FirstPersonButton = createToggleButton(self.PlayerCard, "BLOQUEAR PRIMERA PERSONA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 228))

			self:bindToggle(self.RemoveFogButton, function()
				self.FogRemoved = not self.FogRemoved
				self:toggle(self.RemoveFogButton, self.FogRemoved)
				self:applyFog()
			end)
			self:bindToggle(self.RemoveBlurButton, function()
				self.BlurRemoved = not self.BlurRemoved
				self:toggle(self.RemoveBlurButton, self.BlurRemoved)
				self:applyBlur()
			end)
			self:bindToggle(self.RemoveShadowsButton, function()
				self.ShadowsRemoved = not self.ShadowsRemoved
				self:toggle(self.RemoveShadowsButton, self.ShadowsRemoved)
				Lighting.GlobalShadows = not self.ShadowsRemoved and self.ShadowBackup or false
			end)
			self:bindToggle(self.ThirdPersonButton, function()
				self.ThirdPerson = not self.ThirdPerson
				if self.ThirdPerson then self.FirstPerson = false end
				self:toggle(self.ThirdPersonButton, self.ThirdPerson)
				self:toggle(self.FirstPersonButton, self.FirstPerson)
				self:applyCameraMode()
			end)
			self:bindToggle(self.FirstPersonButton, function()
				self.FirstPerson = not self.FirstPerson
				if self.FirstPerson then self.ThirdPerson = false end
				self:toggle(self.FirstPersonButton, self.FirstPerson)
				self:toggle(self.ThirdPersonButton, self.ThirdPerson)
				self:applyCameraMode()
			end)
			self:addReset(function()
				self.FogRemoved = false
				self.BlurRemoved = false
				self.ShadowsRemoved = false
				self.ThirdPerson = false
				self.FirstPerson = false
				self:applyFog()
				self:applyBlur()
				Lighting.GlobalShadows = self.ShadowBackup
				self:applyCameraMode()
				self:toggle(self.RemoveFogButton, false)
				self:toggle(self.RemoveBlurButton, false)
				self:toggle(self.RemoveShadowsButton, false)
				self:toggle(self.ThirdPersonButton, false)
				self:toggle(self.FirstPersonButton, false)
			end)
		end

		function X:applyFog()
			if self.FogRemoved then
				Lighting.FogStart = 1000000
				Lighting.FogEnd = 1000000
				for _, effect in ipairs(Lighting:GetChildren()) do
					if effect:IsA("Atmosphere") then
						if not self.AtmosphereBackup[effect] then
							self.AtmosphereBackup[effect] = {Density = effect.Density, Haze = effect.Haze, Glare = effect.Glare}
						end
						effect.Density = 0
						effect.Haze = 0
						effect.Glare = 0
					end
				end
			else
				Lighting.FogStart = self.FogBackup.Start
				Lighting.FogEnd = self.FogBackup.Finish
				for effect, values in pairs(self.AtmosphereBackup) do
					if effect and effect.Parent then
						effect.Density = values.Density
						effect.Haze = values.Haze
						effect.Glare = values.Glare
					end
				end
			end
		end

		function X:applyBlur()
			for _, effect in ipairs(Lighting:GetDescendants()) do
				if effect:IsA("BlurEffect") then
					if self.BlurBackup[effect] == nil then self.BlurBackup[effect] = effect.Enabled end
					effect.Enabled = self.BlurRemoved and false or self.BlurBackup[effect]
				end
			end
		end

		function X:applyCameraMode()
			if not self.OriginalCameraMode then
				self.OriginalCameraMode = LocalPlayer.CameraMode
				self.OriginalMinZoom = LocalPlayer.CameraMinZoomDistance
				self.OriginalMaxZoom = LocalPlayer.CameraMaxZoomDistance
			end
			if self.FirstPerson then
				LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
			elseif self.ThirdPerson then
				LocalPlayer.CameraMode = Enum.CameraMode.Classic
				LocalPlayer.CameraMinZoomDistance = 8
				LocalPlayer.CameraMaxZoomDistance = 18
			else
				LocalPlayer.CameraMode = self.OriginalCameraMode
				LocalPlayer.CameraMinZoomDistance = self.OriginalMinZoom
				LocalPlayer.CameraMaxZoomDistance = self.OriginalMaxZoom
			end
		end

		function X:restoreCameraSubject()
			local camera = workspace.CurrentCamera
			local _, humanoid = self:getCharacter()
			if camera and humanoid then
				pcall(function()
					camera.CameraType = Enum.CameraType.Custom
					camera.CameraSubject = humanoid
				end)
			end
		end

		function X:setupPlayerTools()
			self.PlayerToolsCard = TpCard
			self.PlayerToolsTitle = TpTitle
			self.SpectateButton = createToggleButton(self.PlayerToolsCard, "ESPECTAR JUGADOR", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
			markVipControl(self.SpectateButton)
			self.InspectorButton = createToggleButton(self.PlayerToolsCard, "INSPECTOR DE JUGADOR", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 182))
			self.FollowPlayerButton = createToggleButton(self.PlayerToolsCard, "SEGUIR AL JUGADOR", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 228))
			self.FollowDistanceSlider = createSlider(self.PlayerToolsCard, "Distancia de seguimiento", 3, 40, self.FollowDistance, 274, function(value)
				self.FollowDistance = value
			end)

			self.InspectorFrame = Instance.new("Frame")
			self.InspectorFrame.Name = "HexaPlayerInspector"
			self.InspectorFrame.Size = UDim2.new(0, 300, 0, 168)
			self.InspectorFrame.Position = UDim2.new(1, -316, 0, 52)
			self.InspectorFrame.BackgroundColor3 = Theme.Panel2
			self.InspectorFrame.BackgroundTransparency = 0.12
			self.InspectorFrame.BorderSizePixel = 0
			self.InspectorFrame.Visible = false
			self.InspectorFrame.ZIndex = 96
			self.InspectorFrame.Parent = ScreenGui
			mkCorner(self.InspectorFrame, 12)
			mkStroke(self.InspectorFrame, Theme.Accent, 0.45, 1)
			makeDraggable(self.InspectorFrame, self.InspectorFrame)

			self.InspectorTitle = Instance.new("TextLabel")
			self.InspectorTitle.BackgroundTransparency = 1
			self.InspectorTitle.Size = UDim2.new(1, -24, 0, 26)
			self.InspectorTitle.Position = UDim2.new(0, 12, 0, 8)
			self.InspectorTitle.Text = "PLAYER INSPECTOR"
			self.InspectorTitle.TextColor3 = Theme.TextOff
			self.InspectorTitle.TextSize = 13
			self.InspectorTitle.Font = Enum.Font.GothamBold
			self.InspectorTitle.TextXAlignment = Enum.TextXAlignment.Left
			self.InspectorTitle.ZIndex = 97
			self.InspectorTitle.Parent = self.InspectorFrame
			self.InspectorTitle:SetAttribute("HexaNoTranslate", true)

			self.InspectorText = Instance.new("TextLabel")
			self.InspectorText.BackgroundTransparency = 1
			self.InspectorText.Size = UDim2.new(1, -24, 1, -44)
			self.InspectorText.Position = UDim2.new(0, 12, 0, 38)
			self.InspectorText.Text = "SELECCIONA UN JUGADOR"
			self.InspectorText.TextColor3 = Theme.TextOff
			self.InspectorText.TextSize = 12
			self.InspectorText.Font = Enum.Font.GothamMedium
			self.InspectorText.TextWrapped = true
			self.InspectorText.TextXAlignment = Enum.TextXAlignment.Left
			self.InspectorText.TextYAlignment = Enum.TextYAlignment.Top
			self.InspectorText.ZIndex = 97
			self.InspectorText.Parent = self.InspectorFrame
			self.InspectorText:SetAttribute("HexaNoTranslate", true)

			self:bindToggle(self.FollowPlayerButton, function()
				local enabling = not self.FollowPlayer
				if enabling and not HexaSharedTargetFilters:AllowsPlayer(selectedTargetPlayer, true) then return end
				self.FollowPlayer = enabling
				self:toggle(self.FollowPlayerButton, self.FollowPlayer)
				if not self.FollowPlayer then
					local _, humanoid, root = self:getCharacter()
					if humanoid and root then pcall(function() humanoid:MoveTo(root.Position) end) end
				end
			end)
			self:bindToggle(self.SpectateButton, function()
				if not requireVip() then return end
				local enabling = not self.Spectating
				if enabling and not HexaSharedTargetFilters:AllowsPlayer(selectedTargetPlayer, true) then return end
				self.Spectating = enabling
				self:toggle(self.SpectateButton, self.Spectating)
				if not self.Spectating then self:restoreCameraSubject() end
			end)
			self:bindToggle(self.InspectorButton, function()
				local enabling = not self.InspectorEnabled
				if enabling and not HexaSharedTargetFilters:AllowsPlayer(selectedTargetPlayer, false) then return end
				self.InspectorEnabled = enabling
				self:toggle(self.InspectorButton, self.InspectorEnabled)
				self.InspectorFrame.Visible = self.InspectorEnabled
				self:updatePlayerInspector(os.clock(), true)
			end)

			self:addReset(function()
				self.FollowPlayer = false
				self.Spectating = false
				self.InspectorEnabled = false
				self:toggle(self.FollowPlayerButton, false)
				self:toggle(self.SpectateButton, false)
				self:toggle(self.InspectorButton, false)
				if self.InspectorFrame then self.InspectorFrame.Visible = false end
				self:restoreCameraSubject()
			end)
		end

		function X:updateFollowPlayer(now)
			if not self.FollowPlayer or now - self.LastFollowUpdate < 0.1 then return end
			self.LastFollowUpdate = now
			local target = selectedTargetPlayer
			if not HexaSharedTargetFilters:AllowsPlayer(target, true) then
				self.FollowPlayer = false
				self:toggle(self.FollowPlayerButton, false)
				return
			end
			local _, humanoid, root = self:getCharacter()
			local targetCharacter = target and target.Character
			local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then return end
			local desiredPosition = targetRoot.Position - targetRoot.CFrame.LookVector * self.FollowDistance
			local distanceToDesired = (root.Position - desiredPosition).Magnitude
			if distanceToDesired > 2 then
				pcall(function() humanoid:MoveTo(desiredPosition) end)
			end
		end

		function X:updateAntiVoid(now)
			if not self.AntiVoid then return end
			local character, humanoid, root = self:getCharacter()
			if not character or not humanoid or not root or humanoid.Health <= 0 then return end
			local fallenHeight = workspace.FallenPartsDestroyHeight
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			if grounded and root.AssemblyLinearVelocity.Y > -20 and root.Position.Y > fallenHeight + 12 and now - self.LastSafeUpdate >= 0.2 then
				self.LastSafeCFrame = root.CFrame
				self.LastSafeUpdate = now
			end
			if not self.LastSafeCFrame then
				if grounded then
					self.LastSafeCFrame = root.CFrame
					self.LastSafeUpdate = now
				end
				return
			end
			local safeY = self.LastSafeCFrame.Position.Y
			local voidLimit = math.max(fallenHeight + 15, safeY - 120)
			if root.Position.Y <= voidLimit and now >= self.AntiVoidCooldown then
				self.AntiVoidCooldown = now + 1
				pcall(function()
					root.CFrame = self.LastSafeCFrame + Vector3.new(0, 4, 0)
					root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end)
			end
		end

		function X:updateSpectate()
			if not self.Spectating then return end
			local camera = workspace.CurrentCamera
			local target = selectedTargetPlayer
			if not HexaSharedTargetFilters:AllowsPlayer(target, true) then
				self.Spectating = false
				self:toggle(self.SpectateButton, false)
				self:restoreCameraSubject()
				return
			end
			local targetCharacter = target and target.Character
			local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
			if camera and targetHumanoid and targetHumanoid.Health > 0 then
				pcall(function()
					camera.CameraType = Enum.CameraType.Custom
					camera.CameraSubject = targetHumanoid
				end)
			else
				self:restoreCameraSubject()
			end
		end

		function X:updatePlayerInspector(now, force)
			if not self.InspectorEnabled or not self.InspectorFrame then return end
			if not force and now - self.LastInspectorUpdate < 0.2 then return end
			self.LastInspectorUpdate = now
			self.InspectorFrame.Visible = true
			local english = Lang.Current == "EN"
			self.InspectorTitle.Text = english and "PLAYER INSPECTOR" or "INSPECTOR DE JUGADOR"
			local target = selectedTargetPlayer
			if not target or not HexaSharedTargetFilters:AllowsPlayer(target, false) then
				self.InspectorText.Text = english and "SELECT AN ALLOWED PLAYER" or "SELECCIONA UN JUGADOR PERMITIDO"
				return
			end
			local _, _, localRoot = self:getCharacter()
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
			local teamName = target.Team and target.Team.Name or (english and "No team" or "Sin equipo")
			local distanceText = english and "N/A" or "N/D"
			if localRoot and targetRoot then distanceText = ("%.1f studs"):format((localRoot.Position - targetRoot.Position).Magnitude) end
			local statusText
			if humanoid and humanoid.Health > 0 then
				statusText = (english and "Alive" or "Vivo") .. (" • %d/%d HP • %s"):format(math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5), humanoid:GetState().Name)
			else
				statusText = english and "Dead / unavailable" or "Muerto / no disponible"
			end
			if english then
				self.InspectorText.Text = ("Name: %s (@%s)\nUserId: %d\nAccount age: %d days\nTeam: %s\nDistance: %s\nStatus: %s"):format(target.DisplayName, target.Name, target.UserId, target.AccountAge, teamName, distanceText, statusText)
			else
				self.InspectorText.Text = ("Nombre: %s (@%s)\nUserId: %d\nEdad de la cuenta: %d días\nEquipo: %s\nDistancia: %s\nEstado: %s"):format(target.DisplayName, target.Name, target.UserId, target.AccountAge, teamName, distanceText, statusText)
			end
		end

		function X:updatePlayerTools(now)
			if not self.FollowPlayer and not self.AntiVoid and not self.Spectating and not self.InspectorEnabled then return end
			self:updateFollowPlayer(now)
			self:updateAntiVoid(now)
			self:updateSpectate()
			self:updatePlayerInspector(now, false)
		end

		function X:setupTeleportTools()
			self.TeleportCard, self.TeleportTitle = self:makeCard(250, "UTILIDADES DE TELETRANSPORTE")
			self.TeleportCard.LayoutOrder = 41
			self.SavePositionButton = neonButton(self.TeleportCard, "GUARDAR POSICIÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.ReturnPositionButton = neonButton(self.TeleportCard, "VOLVER A LA POSICIÓN GUARDADA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
			self.HistoryButton = neonButton(self.TeleportCard, "HISTORIAL: VOLVER (0)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
			self.MouseTeleportButton = createToggleButton(self.TeleportCard, "TELETRANSPORTARSE AL RATÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 182))
			registerDeviceText(self.MouseTeleportButton,
				"TELETRANSPORTARSE AL RATÓN",
				"TELETRANSPORTARSE AL TOQUE",
				"TELEPORT TO MOUSE",
				"TELEPORT TO TOUCH")
			markVipControl(self.MouseTeleportButton)
			self:connect(self.SavePositionButton.MouseButton1Click, function()
				local _, _, root = self:getCharacter()
				if root then
					self.SavedPosition = root.CFrame
					self.SavePositionButton.Text = "POSICIÓN GUARDADA"
					task.delay(1.2, function()
						if self.SavePositionButton and self.SavePositionButton.Parent then self.SavePositionButton.Text = "GUARDAR POSICIÓN" end
					end)
				end
			end)
			self:connect(self.ReturnPositionButton.MouseButton1Click, function()
				if self.SavedPosition then self:teleportTo(self.SavedPosition) end
			end)
			self:connect(self.HistoryButton.MouseButton1Click, function()
				local _, _, root = self:getCharacter()
				local target = table.remove(self.TeleportHistory)
				if root and target then root.CFrame = target end
				self:updateHistoryText()
			end)
			self:bindToggle(self.MouseTeleportButton, function()
				if not requireVip() then return end
				self.MouseTeleport = not self.MouseTeleport
				self.MouseTeleportArmedAt = self.MouseTeleport and (os.clock() + 0.25) or 0
				self:toggle(self.MouseTeleportButton, self.MouseTeleport)
			end)
			self:addReset(function()
				self.MouseTeleport = false
				self.MouseTeleportArmedAt = 0
				self:toggle(self.MouseTeleportButton, false)
			end)
		end

		function X:teleportTo(target)
			local _, _, root = self:getCharacter()
			if not root then return end
			table.insert(self.TeleportHistory, root.CFrame)
			if #self.TeleportHistory > self.MaxTeleportHistory then table.remove(self.TeleportHistory, 1) end
			root.CFrame = target
			self:updateHistoryText()
		end

		function X:updateHistoryText()
			if self.HistoryButton then self.HistoryButton.Text = ("HISTORIAL: VOLVER (%d)"):format(#self.TeleportHistory) end
		end

		function X:setupInfoHud()
			self.InfoCard, self.InfoTitle = self:makeCard(282, "INFORMACIÓN")
			self.InfoCard.LayoutOrder = 60
			self.InfoHud = Instance.new("Frame")
			self.InfoHud.Name = "HexaInfoHud"
			self.InfoHud.Size = UDim2.new(0, 235, 0, 118)
			self.InfoHud.Position = UDim2.new(0, 16, 0, 16)
			self.InfoHud.BackgroundColor3 = Theme.Panel2
			self.InfoHud.BackgroundTransparency = 0.18
			self.InfoHud.BorderSizePixel = 0
			self.InfoHud.Visible = false
			self.InfoHud.ZIndex = 90
			self.InfoHud.Parent = ScreenGui
			mkCorner(self.InfoHud, 12)
			mkStroke(self.InfoHud, Theme.Accent, 0.45, 1)
			makeDraggable(self.InfoHud, self.InfoHud)
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 2)
			layout.Parent = self.InfoHud
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 10)
			padding.PaddingRight = UDim.new(0, 10)
			padding.Parent = self.InfoHud
			self.InfoLabels = {}
			for i = 1, 5 do
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, 0, 0, 18)
				label.Text = ""
				label.TextColor3 = Theme.TextOff
				label.TextSize = 12
				label.Font = Enum.Font.GothamMedium
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.LayoutOrder = i
				label.Visible = false
				label.ZIndex = 91
				label.Parent = self.InfoHud
				self.InfoLabels[i] = label
			end
			self.FpsButton = createToggleButton(self.InfoCard, "CONTADOR DE FPS", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.PingButton = createToggleButton(self.InfoCard, "CONTADOR DE PING", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
			self.ClockButton = createToggleButton(self.InfoCard, "RELOJ", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))
			self.CoordsButton = createToggleButton(self.InfoCard, "COORDENADAS", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 182))
			self.SpeedButton = createToggleButton(self.InfoCard, "MEDIDOR DE VELOCIDAD", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 228))
			local pairsList = {
				{self.FpsButton, "FpsEnabled"},
				{self.PingButton, "PingEnabled"},
				{self.ClockButton, "ClockEnabled"},
				{self.CoordsButton, "CoordsEnabled"},
				{self.SpeedButton, "SpeedEnabled"},
			}
			for _, item in ipairs(pairsList) do
				self:bindToggle(item[1], function()
					self[item[2]] = not self[item[2]]
					self:toggle(item[1], self[item[2]])
					self:updateInfoVisibility()
				end)
			end
			self:addReset(function()
				self.FpsEnabled = false
				self.PingEnabled = false
				self.ClockEnabled = false
				self.CoordsEnabled = false
				self.SpeedEnabled = false
				for _, item in ipairs(pairsList) do self:toggle(item[1], false) end
				self:updateInfoVisibility()
			end)
		end

		function X:updateInfoVisibility()
			local states = {self.FpsEnabled, self.PingEnabled, self.ClockEnabled, self.CoordsEnabled, self.SpeedEnabled}
			local anyVisible = false
			for i, state in ipairs(states) do
				self.InfoLabels[i].Visible = state
				if state then anyVisible = true end
			end
			self.InfoHud.Visible = anyVisible
		end

		function X:updateInfo(now)
			if not self.FpsEnabled and not self.PingEnabled and not self.ClockEnabled and not self.CoordsEnabled and not self.SpeedEnabled then return end
			if self.FpsEnabled then
				if now - self.LastFpsTime > 1 then
					self.Frames = 0
					self.LastFpsTime = now
				end
				self.Frames += 1
			end
			if self.FpsEnabled and now - self.LastFpsTime >= 0.5 then
				self.CurrentFps = math.floor(self.Frames / math.max(0.001, now - self.LastFpsTime) + 0.5)
				self.Frames = 0
				self.LastFpsTime = now
			end
			if now - self.LastInfoUpdate < 0.15 then return end
			self.LastInfoUpdate = now
			if self.FpsEnabled then self.InfoLabels[1].Text = "FPS: " .. self.CurrentFps end
			if self.PingEnabled then
				local ping = "NO DISP."
				pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString() end)
				self.InfoLabels[2].Text = "PING: " .. ping
			end
			if self.ClockEnabled then self.InfoLabels[3].Text = "HORA: " .. os.date("%H:%M:%S") end
			local _, _, root = self:getCharacter()
			if self.CoordsEnabled then
				if root then
					local position = root.Position
					self.InfoLabels[4].Text = ("XYZ: %.1f, %.1f, %.1f"):format(position.X, position.Y, position.Z)
				else
					self.InfoLabels[4].Text = "XYZ: NO DISP."
				end
			end
			if self.SpeedEnabled then
				self.InfoLabels[5].Text = root and ("VELOCIDAD: %.1f"):format(root.AssemblyLinearVelocity.Magnitude) or "VELOCIDAD: 0"
			end
		end

		function X:setupSafety()
			self.SafetyCard, self.SafetyTitle = self:makeCard(98, "SEGURIDAD Y CONTROL")
			self.SafetyCard.LayoutOrder = -3
			self.PanicButton = Instance.new("TextButton")
			self.PanicButton.Size = UDim2.new(1, -32, 0, 38)
			self.PanicButton.Position = UDim2.new(0, 16, 0, 44)
			self.PanicButton.BackgroundColor3 = Theme.Danger
			self.PanicButton.BackgroundTransparency = 1
			self.PanicButton.BorderSizePixel = 0
			self.PanicButton.Text = "ACTIVAR MODO PÁNICO"
			self.PanicButton.TextColor3 = BUTTON_TEXT_COLOR
			self.PanicButton.TextSize = 12
			self.PanicButton.Font = Enum.Font.GothamBold
			self.PanicButton.AutoButtonColor = false
			self.PanicButton.ZIndex = 2
			self.PanicButton.Parent = self.SafetyCard
			mkCorner(self.PanicButton, 10)
			mkStroke(self.PanicButton, Color3.fromRGB(255, 115, 115), 0.2, 1)
			self.PanicButton:SetAttribute("BaseText", "ACTIVAR MODO PÁNICO")
			self.PanicButton:SetAttribute("IsActive", false)
			self.PanicButton:SetAttribute("HexaNoFavorite", true)
			addHover(self.PanicButton, Theme.Danger, Color3.fromRGB(238, 70, 70), Color3.fromRGB(185, 35, 35))
			self:connect(self.PanicButton.MouseButton1Click, function()
				self:panic()
				self.PanicButton.Text = Lang.Current == "EN" and "ALL FEATURES DISABLED" or "TODAS LAS FUNCIONES DESACTIVADAS"
				task.delay(1.6, function()
					if self.PanicButton and self.PanicButton.Parent then
						self.PanicButton.Text = tostring(self.PanicButton:GetAttribute("BaseText") or "ACTIVAR MODO PÁNICO")
					end
				end)
			end)
		end

		function X:setupMisc()
			self.PerformanceCard, self.PerformanceTitle = self:makeCard(98, "OPTIMIZACIÓN DE RENDIMIENTO")
			self.PerformanceCard.LayoutOrder = 1
			self.PerformanceButton = createToggleButton(self.PerformanceCard, "MODO RENDIMIENTO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))

			self.AutomationCard, self.AutomationTitle = self:makeCard(140, "AUTOMATIZACIÓN")
			self.AutomationCard.LayoutOrder = 70
			self.AutoRespawnButton = createToggleButton(self.AutomationCard, "REAPARICIÓN AUTOMÁTICA", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.AutoEquipButton = createToggleButton(self.AutomationCard, "EQUIPAR HERRAMIENTA AUTOMÁTICAMENTE", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))

			self.SystemCard, self.SystemTitle = self:makeCard(186, "SISTEMA Y UTILIDADES")
			self.SystemCard.LayoutOrder = 71
			self.AntiAfkButton = createToggleButton(self.SystemCard, "ANTI AUSENCIA (AFK)", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.ReconnectButton = neonButton(self.SystemCard, "RECONECTAR AL SERVIDOR", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
			self.StreamerButton = createToggleButton(self.SystemCard, "MODO TRANSMISIÓN", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 136))

			self:bindToggle(self.AutoRespawnButton, function()
				self.AutoRespawn = not self.AutoRespawn
				self:toggle(self.AutoRespawnButton, self.AutoRespawn)
			end)
			self:bindToggle(self.AutoEquipButton, function()
				self.AutoEquip = not self.AutoEquip
				self:toggle(self.AutoEquipButton, self.AutoEquip)
			end)
			self:bindToggle(self.AntiAfkButton, function()
				self.AntiAfk = not self.AntiAfk
				self:toggle(self.AntiAfkButton, self.AntiAfk)
			end)
			self:connect(self.ReconnectButton.MouseButton1Click, function()
				pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
				end)
			end)
			self:bindToggle(self.PerformanceButton, function()
				self.Performance = not self.Performance
				self:toggle(self.PerformanceButton, self.Performance)
				self:applyPerformance()
			end)
			self:bindToggle(self.StreamerButton, function()
				self.Streamer = not self.Streamer
				self:toggle(self.StreamerButton, self.Streamer)
				self:applyStreamer()
			end)
			self:addReset(function()
				self.AntiAfk = false
				self.AutoRespawn = false
				self.AutoEquip = false
				self.Performance = false
				self.Streamer = false
				self:applyPerformance()
				self:applyStreamer()
				self:toggle(self.AntiAfkButton, false)
				self:toggle(self.AutoRespawnButton, false)
				self:toggle(self.AutoEquipButton, false)
				self:toggle(self.PerformanceButton, false)
				self:toggle(self.StreamerButton, false)
			end)
		end

		function X:setPanelPerformanceTransparency(object, enabled)
			if not object or not object.Parent then return end
			if enabled then
				if object:GetAttribute("HexaPerformanceTransparency") == nil then
					object:SetAttribute("HexaPerformanceTransparency", object.BackgroundTransparency)
				end
				object.BackgroundTransparency = 0
			else
				local original = object:GetAttribute("HexaPerformanceTransparency")
				if original ~= nil then
					object.BackgroundTransparency = original
					object:SetAttribute("HexaPerformanceTransparency", nil)
				end
			end
		end

		function X:applyPanelPerformance(enabled)
			if bgGradient then bgGradient.Enabled = not enabled end
			if HeaderGlow then HeaderGlow.Visible = not enabled end
			if MainFrameStroke then MainFrameStroke.Enabled = not enabled end
			self:setPanelPerformanceTransparency(MainFrame, enabled)
			self:setPanelPerformanceTransparency(Header, enabled)
			self:setPanelPerformanceTransparency(CategoryUI.Frame, enabled)
			for _, object in ipairs(Content:GetChildren()) do
				if object:IsA("Frame") and object:GetAttribute("HexaContentCard") == true then
					self:setPanelPerformanceTransparency(object, enabled)
				end
			end
			Content.ScrollBarThickness = enabled and 2 or (MOBILE_DEVICE and 6 or 4)
			CategoryUI.Scroll.ScrollBarThickness = enabled and 0 or (MOBILE_DEVICE and 0 or 3)
		end

		function X:applyPerformance()
			PERFORMANCE_MODE = self.Performance == true
			self:applyPanelPerformance(PERFORMANCE_MODE)
		end

		function X:applyStreamer()
			PlayerAvatar.Visible = not self.Streamer
			PlayerName.Text = self.Streamer and "MODO TRANSMISIÓN" or (LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")")
			ByNonyLabel.Visible = not self.Streamer
			VipProfileBadge.Visible = not self.Streamer
		end

		function X:setupPersonalization()
			self.PersonalCard, self.PersonalTitle = self:makeCard(158, "PERSONALIZACIÓN")
			self.PersonalCard.LayoutOrder = 80
			local categoryVipBadge = Instance.new("TextLabel")
			categoryVipBadge.Name = "HexaVipBadge"
			categoryVipBadge.AnchorPoint = Vector2.new(1, 0)
			categoryVipBadge.Position = UDim2.new(1, -14, 0, 10)
			categoryVipBadge.Size = UDim2.new(0, 54, 0, 20)
			categoryVipBadge.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
			categoryVipBadge.BorderSizePixel = 0
			categoryVipBadge.Text = "★ VIP"
			categoryVipBadge.TextColor3 = Color3.fromRGB(215, 215, 215)
			categoryVipBadge.TextSize = 10
			categoryVipBadge.Font = Enum.Font.GothamBold
			categoryVipBadge.ZIndex = 7
			categoryVipBadge.Parent = self.PersonalCard
			mkCorner(categoryVipBadge, 7)
			mkStroke(categoryVipBadge, Color3.fromRGB(70, 70, 70), 0.35, 1)
			local function refreshPersonalCardVip()
				if self.PersonalCard and self.PersonalCard.Parent then
					self.PersonalCard.BackgroundTransparency = HEXA_IS_VIP and 0.1 or 0.3
				end
			end
			addVipStateListener(refreshPersonalCardVip)
			refreshPersonalCardVip()
			self.AnimationStyles = {"BACK", "QUAD", "ELASTIC", "BOUNCE", "SLIDE_LEFT", "SLIDE_RIGHT", "SLIDE_UP", "SLIDE_DOWN", "ZOOM", "SPIN", "PULSE", "GLITCH", "DROP", "BURST"}
			self.FontOptions = {
				{name = "GOTHAM", font = Enum.Font.Gotham},
				{name = "SOURCE SANS", font = Enum.Font.SourceSans},
				{name = "CÓDIGO", font = Enum.Font.Code},
				{name = "GOTHAM NEGRITA", font = Enum.Font.GothamBold},
			}
			self.AnimationButton = neonButton(self.PersonalCard, "ANIMACIÓN DE APERTURA: RETROCESO", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 44))
			self.FontButton = neonButton(self.PersonalCard, "FUENTE: GOTHAM", UDim2.new(1, -32, 0, 38), UDim2.new(0, 16, 0, 90))
			markVipControl(self.AnimationButton)
			markVipControl(self.FontButton)
			self:connect(self.AnimationButton.MouseButton1Click, function()
				if not requireVip() then return end
				self.AnimationIndex = self.AnimationIndex % #self.AnimationStyles + 1
				local nombres = {
					BACK = "RETROCESO", QUAD = "SUAVE", ELASTIC = "ELÁSTICA", BOUNCE = "REBOTE",
					SLIDE_LEFT = "DESLIZAR IZQUIERDA", SLIDE_RIGHT = "DESLIZAR DERECHA",
					SLIDE_UP = "DESLIZAR ARRIBA", SLIDE_DOWN = "DESLIZAR ABAJO",
					ZOOM = "ZOOM", SPIN = "GIRO", PULSE = "LATIDO", GLITCH = "GLITCH",
					DROP = "CAÍDA", BURST = "EXPLOSIÓN",
				}
				self.AnimationButton.Text = "ANIMACIÓN DE APERTURA: " .. nombres[self.AnimationStyles[self.AnimationIndex]]
				self:applyAnimation(true)
			end)
			self:connect(self.FontButton.MouseButton1Click, function()
				if not requireVip() then return end
				self.FontIndex = self.FontIndex % #self.FontOptions + 1
				self.FontButton.Text = "FUENTE: " .. self.FontOptions[self.FontIndex].name
				self:applyFont()
			end)
		end

		function X:applyAnimation(preview)
			openingStyle = self.AnimationStyles[self.AnimationIndex] or "BACK"
			-- Solo reproducir la animación cuando el usuario la cambia manualmente.
			-- Los refrescos de estado/configuración pueden actualizar openingStyle sin
			-- hacer que un panel ya abierto parezca abrirse otra vez.
			if preview == true and MainFrame.Visible and MainFrame.Size.X.Offset > 0 then
				animateOpen(MainFrame, MAIN_SIZE, openingStyle)
			end
		end

		function X:applyFont()
			local font = self.FontOptions[self.FontIndex].font
			for _, object in ipairs(ScreenGui:GetDescendants()) do
				if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) and not object:GetAttribute("HexaNoGlobalFont") then
					object.Font = font
				end
			end
		end

		function X:disableOriginalFeatures()
			flyActive = false
			speedActive = false
			jumpActive = false
			infiniteJumpActive = false
			noclipActive = false
			autoAimHeadActive = false
			autoAimBodyActive = false
			ignoreFriendsActive = false
			fovActive = false
			espSkeletonActive = false
			espLinesActive = false
			pcall(clearFly)
			pcall(restoreNoclip)
			FovCircle.Visible = false
			AimHighlight.Adornee = nil
			local buttons = {flyButton, speedButton, jumpButton, infiniteJumpButton, noclipButton, autoAimHeadButton, autoAimBodyButton, ignoreFriendsButton, fovButton, espSkeletonButton, espLinesButton}
			for _, button in ipairs(buttons) do self:toggle(button, false) end
			local _, humanoid = self:getCharacter()
			if humanoid then
				humanoid.WalkSpeed = Runtime.speedBase
				humanoid.UseJumpPower = true
				humanoid.JumpPower = Runtime.jumpBase
			end
		end

		function X:panic()
			self:disableOriginalFeatures()
			for _, resetter in ipairs(self.Resetters) do
				pcall(resetter)
			end
			DropdownList.Visible = false
			FovCircle.Visible = false
			AimHighlight.Adornee = nil
			MainFrame.Visible = true
			RestoreOrb.Visible = false
		end

		function X:updateAutoEquip(now)
			if not self.AutoEquip or now - self.LastAutoEquip < 0.65 then return end
			self.LastAutoEquip = now
			local character, humanoid = self:getCharacter()
			local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
			if character and humanoid and backpack and not character:FindFirstChildOfClass("Tool") then
				local tool = backpack:FindFirstChildOfClass("Tool")
				if tool then pcall(function() humanoid:EquipTool(tool) end) end
			end
		end

		function X:watchHumanoid(humanoid)
			self:connect(humanoid.Died, function()
				if self.AutoRespawn then
					task.delay(1.5, function()
						pcall(function() LocalPlayer:LoadCharacter() end)
					end)
				end
			end)
		end

		function X:getTeleportTargetFromScreen(position)
			local camera = workspace.CurrentCamera
			if not camera then return nil end
			local ray = camera:ViewportPointToRay(position.X, position.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
			params.IgnoreWater = false
			local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
			if not result then return nil end
			return CFrame.new(result.Position + Vector3.new(0, 3, 0))
		end

		function X:isPointerOverInterface(position)
			local point = Vector2.new(position.X, position.Y)
			local function contains(guiObject)
				if not guiObject or not guiObject.Parent or not guiObject.Visible then return false end
				local absolutePosition = guiObject.AbsolutePosition
				local absoluteSize = guiObject.AbsoluteSize
				return point.X >= absolutePosition.X and point.X <= absolutePosition.X + absoluteSize.X
					and point.Y >= absolutePosition.Y and point.Y <= absolutePosition.Y + absoluteSize.Y
			end
			if contains(MainFrame) or contains(KeyFrame) or contains(ConfirmFrame) or contains(Tutorial.Frame)
				or contains(RestoreOrb) or contains(self.InfoHud) or contains(self.InspectorFrame)
				or contains(VipNotification) or contains(MobileFlyControls) or contains(MobileAim and MobileAim.Button) then
				return true
			end
			return FloatingButtonManager and FloatingButtonManager:IsPointerOverAny(point) or false
		end

		function X:setupGlobalConnections()
			self:connect(RunService.RenderStepped, function()
				if self.Dead then return end
				local rainbowActive = self.CrosshairRainbow and self.CrosshairEnabled
				local movementActive = self.AirWalk or self.BunnyHop or self.NoFall or self.AirWalkPlatform
				local playerToolsActive = self.FollowPlayer or self.AntiVoid or self.Spectating or self.InspectorEnabled
				local infoActive = self.FpsEnabled or self.PingEnabled or self.ClockEnabled or self.CoordsEnabled or self.SpeedEnabled
				if not rainbowActive and not movementActive and not playerToolsActive and not infoActive and not self.AutoEquip then return end
				local now = os.clock()
				local visualInterval = PERFORMANCE_MODE and (MOBILE_DEVICE and (1 / 18) or (1 / 16))
					or (MOBILE_DEVICE and (1 / 24) or (1 / 20))
				if rainbowActive and now - self.LastVisualUpdate >= visualInterval then
					self.LastVisualUpdate = now
					local color = Color3.fromHSV((now * 0.18) % 1, 1, 1)
					for _, line in ipairs(self.CrosshairLines) do line.BackgroundColor3 = color end
					if self.CrosshairDot then self.CrosshairDot.BackgroundColor3 = color end
				end
				local movementInterval = PERFORMANCE_MODE and (MOBILE_DEVICE and (1 / 20) or (1 / 16))
					or (MOBILE_DEVICE and (1 / 30) or (1 / 20))
				if movementActive and now - self.LastMovementUpdate >= movementInterval then
					self.LastMovementUpdate = now
					self:updateMovementExtra()
				end
				if playerToolsActive and now - self.LastPlayerToolsUpdate >= 0.05 then
					self.LastPlayerToolsUpdate = now
					self:updatePlayerTools(now)
				end
				if infoActive then self:updateInfo(now) end
				if self.AutoEquip then self:updateAutoEquip(now) end
			end)
			self:connect(UserInputService.InputBegan, function(input, processed)
				if processed then return end
				local pointerInput = input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				if pointerInput and self.MouseTeleport and HEXA_IS_VIP then
					if os.clock() >= self.MouseTeleportArmedAt and not self:isPointerOverInterface(input.Position) then
						local target = self:getTeleportTargetFromScreen(input.Position)
						if target then self:teleportTo(target) end
					end
				end
			end)
			self:connect(LocalPlayer.Idled, function()
				if self.AntiAfk then
					pcall(function()
						VirtualUser:CaptureController()
						VirtualUser:ClickButton2(Vector2.new(0, 0))
					end)
				end
			end)
			self:connect(LocalPlayer.CharacterAdded, function(character)
				self.LastSafeCFrame = nil
				self.LastSafeUpdate = 0
				local humanoid = character:WaitForChild("Humanoid", 5)
				if humanoid then self:watchHumanoid(humanoid) end
			end)
			local _, humanoid = self:getCharacter()
			if humanoid then self:watchHumanoid(humanoid) end
			self:connect(ScreenGui.Destroying, function()
				self.Dead = true
				self.Performance = false
				PERFORMANCE_MODE = false
				self:destroyAirWalk()
				self:restoreCameraSubject()
				workspace.Gravity = self.GravityDefault
				for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
			end)
		end

		pcall(function() X:setupSafety() end)
		pcall(function() X:setupCrosshair() end)
		pcall(function() X:setupMovementExtra() end)
		pcall(function() X:setupPlayerVisuals() end)
		pcall(function() X:setupPlayerTools() end)
		pcall(function() X:setupTeleportTools() end)
		pcall(function() X:setupInfoHud() end)
		pcall(function() X:setupMisc() end)
		pcall(function() X:setupPersonalization() end)
		addVipStateListener(function(isVip)
			if isVip then
				return
			end
			X.NoFall = false
			X.Spectating = false
			X.MouseTeleport = false
			X.MouseTeleportArmedAt = 0
			X.CrosshairRainbow = false
			X.CrosshairStyle = "CRUZ"
			X.CrosshairColorIndex = 1
			X.CrosshairSize = 14
			X.CrosshairThickness = 2
			X.CrosshairGap = 5
			X.AnimationIndex = 1
			X.FontIndex = 1
			pcall(function() X:toggle(X.NoFallButton, false) end)
			pcall(function() X:toggle(X.SpectateButton, false) end)
			pcall(function() X:toggle(X.MouseTeleportButton, false) end)
			pcall(function() X:toggle(X.CrosshairRainbowButton, false) end)
			pcall(function() X.CrosshairStyleButton.Text = "TIPO DE MIRA: CRUZ" end)
			pcall(function() X.CrosshairColorButton.Text = "COLOR DE LA MIRA: BLANCO" end)
			pcall(function() X.CrosshairSizeSlider.Set(14) end)
			pcall(function() X.CrosshairThicknessSlider.Set(2) end)
			pcall(function() X.CrosshairGapSlider.Set(5) end)
			pcall(function() X.AnimationButton.Text = "ANIMACIÓN DE APERTURA: RETROCESO" end)
			pcall(function() X.FontButton.Text = "FUENTE: GOTHAM" end)
			pcall(function() X:updateCrosshair() end)
			pcall(function() X:restoreCameraSubject() end)
			-- Resetear el estilo sin reproducir la animación durante un refresh VIP.
			-- Así no existe una "reapertura fantasma" mientras MainFrame ya está abierto.
			openingStyle = "BACK"
			pcall(function() X:applyFont() end)
		end)
		pcall(function() X:setupGlobalConnections() end)
		Lang.Set(Lang.Current)
		task.defer(function()
			registerAllFunctionButtons()
			refreshCategoryView()
		end)
	end)

	if not success then
		warn("[H4SK] Error al cargar la extensión modular: " .. tostring(errorMessage))
	end
end)

end, function(errorMessage)
	local trace = tostring(errorMessage)
	pcall(function()
		if debug and debug.traceback then trace = debug.traceback(trace, 2) end
	end)
	return trace
end)

if __HexaOk then
	pcall(function()
		if __BootstrapGui and __BootstrapGui.Parent then __BootstrapGui:Destroy() end
	end)
else
	warn("[H4SK] Error de inicio: " .. tostring(__HexaError))
	pcall(function()
		if not __BootstrapGui or not __BootstrapGui.Parent then
			__BootstrapGui = Instance.new("ScreenGui")
			__BootstrapGui.Name = "H4SK_Bootstrap"
			__BootstrapGui.IgnoreGuiInset = true
			__BootstrapGui.ResetOnSpawn = false
			__BootstrapGui.DisplayOrder = 2147483647
			__BootstrapGui.Parent = __BootstrapPlayerGui
		end
		if not __BootstrapFrame or not __BootstrapFrame.Parent then
			__BootstrapFrame = Instance.new("Frame")
			__BootstrapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			__BootstrapFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			__BootstrapFrame.Size = UDim2.new(0, 320, 0, 180)
			__BootstrapFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
			__BootstrapFrame.BorderSizePixel = 0
			__BootstrapFrame.Parent = __BootstrapGui
		end
		__BootstrapFrame.Size = UDim2.new(0, 320, 0, 180)
		__BootstrapTitle.Text = "ERROR AL ABRIR H3X4 X"
		__BootstrapTitle.TextColor3 = Color3.fromRGB(255, 90, 90)
		__BootstrapText.Position = UDim2.new(0, 14, 0, 42)
		__BootstrapText.Size = UDim2.new(1, -28, 1, -54)
		__BootstrapText.TextYAlignment = Enum.TextYAlignment.Top
		__BootstrapText.TextXAlignment = Enum.TextXAlignment.Left
		__BootstrapText.TextSize = 10
		__BootstrapText.Text = string.sub(tostring(__HexaError), 1, 900)
	end)
end
