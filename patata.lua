pcall(function()
	local b = game:GetService("Lighting"):FindFirstChild("HXGlassBlur")
	if b then b:Destroy() end
end)
pcall(function()
	local f = workspace:FindFirstChild("HXGlassBlurFolder")
	if f then f:Destroy() end
end)
local _genv = (type(getgenv) == "function") and getgenv or function() return {} end
if _genv().HXEmotesCleanup then
	pcall(_genv().HXEmotesCleanup)
	_genv().HXEmotesCleanup = nil
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local AvatarEditorService = game:GetService("AvatarEditorService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local function debugLog(msg) end

local old = playerGui:FindFirstChild("HXEmotes")
if old then old:Destroy() end


local DATA_FILE = "HXEmotes_Data_" .. tostring(player.UserId) .. ".json"
local Settings = {theme = "Dark", speed = 1, notifications = true, loopEmote = true, language = nil, copyEmoteEnabled = false, stopOnWalk = true, showHUD = false, panelScale = 1, reversePlayback = false, animationWeight = 1}

local FriendData = {
	friends        = {},
	autoReject     = false,
	acceptRequests = true,
	playFriendEmote = true,
	syncEmote      = true,
	addModeActive  = false,
	currentSyncPartner = nil,
}
_friendConns = {}
local RefreshFriendList
Playlists = {}
PlaylistFavorites = {}
local RefreshPlaylistsList
local trendingDropdown
local ShowSavePlaylistDialog
local ShowFriendRequestPanel
Favorites = {}
FavoritesSet = {}
Keybinds = {}
KeybindsSet = {}
RecentEmotes = {}
QuickEmotes = {}
CustomAnimations = {}
local _onSpeedChanged
local _onPauseStateChanged
local ResolveUGCAnimationId
local LoadUGCCatalog
local LoadUGCPage
local UGCEmotes = {}
local _ugcSearchBusyMain = false
local _ugcRequestTokenMain = 0
local _ugcAnimCacheMain = {}
local _ugcPageMode = true
local _ugcCurrentPage = 1
local _ugcHasNext = false
local _ugcHasPrevious = false
local _ugcActiveQuery = ""
local MAX_RECENT = 20

local _savePending = false
local function SaveData()
	if _savePending then return end
	_savePending = true
	task.delay(0.25, function()
		_savePending = false
		pcall(function()
			if writefile then
				writefile(DATA_FILE, HttpService:JSONEncode({
					favorites = Favorites,
					recent = RecentEmotes,
					settings = Settings,
					friendSettings = {
						autoReject = FriendData.autoReject,
						acceptRequests = FriendData.acceptRequests,
						playFriendEmote = FriendData.playFriendEmote,
						syncEmote = FriendData.syncEmote
					},
					friends = FriendData.friends,
					keybinds = Keybinds,
					playlists = Playlists,
					playlistFavorites = PlaylistFavorites,
					quickEmotes = QuickEmotes,
					customAnimations = CustomAnimations
				}))
			end
		end)
	end)
end

local function LoadData()
	debugLog("LoadData starting (local mode)")
	pcall(function()
		local sourceFile = nil
		if readfile and isfile then
			if isfile(DATA_FILE) then
				sourceFile = DATA_FILE
			end
		end

		if sourceFile then
			local data = HttpService:JSONDecode(readfile(sourceFile))
			if data then
				Playlists = type(data.playlists) == "table" and data.playlists or {}
				MockPlaylists = Playlists
				PlaylistFavorites = type(data.playlistFavorites) == "table" and data.playlistFavorites or {}
				QuickEmotes = type(data.quickEmotes) == "table" and data.quickEmotes or {}
				CustomAnimations = type(data.customAnimations) == "table" and data.customAnimations or {}

				Favorites = {}
				if type(data.favorites) == "table" then
					for _, v in pairs(data.favorites) do
						local n = tonumber(v)
						if n then Favorites[#Favorites + 1] = n end
					end
				end

				RecentEmotes = {}
				if type(data.recent) == "table" then
					for _, v in pairs(data.recent) do
						local n = tonumber(type(v) == "table" and v.emote or v)
						if n then RecentEmotes[#RecentEmotes + 1] = n end
					end
				end

				if type(data.settings) == "table" then
					Settings.theme = data.settings.theme or "Dark"
					Settings.speed = data.settings.speed or 1
					Settings.notifications = data.settings.notifications ~= false
					Settings.loopEmote = data.settings.loopEmote ~= false
					Settings.language = data.settings.language or nil
					Settings.stopOnWalk = data.settings.stopOnWalk ~= false
					Settings.showHUD = false
					Settings.copyEmoteEnabled = data.settings.copyEmoteEnabled == true
					Settings.panelScale = math.clamp(tonumber(data.settings.panelScale) or 1, 0.75, 1.35)
					Settings.reversePlayback = data.settings.reversePlayback == true
					Settings.animationWeight = math.clamp(tonumber(data.settings.animationWeight) or 1, 0.2, 1)
				end

				if type(data.friendSettings) == "table" then
					FriendData.autoReject = data.friendSettings.autoReject == true
					FriendData.acceptRequests = data.friendSettings.acceptRequests ~= false
					FriendData.playFriendEmote = data.friendSettings.playFriendEmote ~= false
					FriendData.syncEmote = data.friendSettings.syncEmote ~= false
				end
				FriendData.friends = type(data.friends) == "table" and data.friends or {}

				Keybinds = {}
				if type(data.keybinds) == "table" then
					for k, v in pairs(data.keybinds) do
						Keybinds[tostring(k)] = v
					end
				end
			end
		else
			Playlists = {}
			MockPlaylists = Playlists
		end
	end)

	FriendData.isLoaded = true
	FavoritesSet = {}
	for _, v in ipairs(Favorites) do FavoritesSet[v] = true end

	KeybindsSet = {}
	for k, v in pairs(Keybinds) do
		local num = tonumber(k)
		KeybindsSet[num or k] = v
	end
end

local function GetKeybind(emoteId) return KeybindsSet[emoteId] end
local function SetKeybind(emoteId, name, keyStr)
	KeybindsSet[emoteId] = {name = name, key = keyStr}
	Keybinds[tostring(emoteId)] = {name = name, key = keyStr}
	SaveData()
	if selectedEmote and tostring(selectedEmote.id) == tostring(emoteId) and UpdateSelectedEmoteUI then
		UpdateSelectedEmoteUI(selectedEmote, selectedCardStroke, selectedCardContainer)
	end
end
local function RemoveKeybind(emoteId)
	KeybindsSet[emoteId] = nil
	Keybinds[tostring(emoteId)] = nil
	SaveData()
	if selectedEmote and tostring(selectedEmote.id) == tostring(emoteId) and UpdateSelectedEmoteUI then
		UpdateSelectedEmoteUI(selectedEmote, selectedCardStroke, selectedCardContainer)
	end
end

local EmotesById = {}

local _emoteMetaCache = {}


local isMobile = UserInputService.TouchEnabled

local _resolvedCache = {}
local function ResolveAssetImage(assetIdOrUrl)
	if not assetIdOrUrl then return "" end
	local str = tostring(assetIdOrUrl)
	local rawId = str:gsub("rbxassetid://", ""):gsub("[^%d]", "")
	if rawId == "" then return str end
	if _resolvedCache[rawId] then return _resolvedCache[rawId] end
	local resolved = nil
	pcall(function()
		local objects = game:GetObjects("rbxassetid://" .. rawId)
		if objects and #objects > 0 then
			local obj = objects[1]
			if obj:IsA("Decal") or obj:IsA("Texture") then
				resolved = obj.Texture
			elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				resolved = obj.Image
			end
		end
	end)
	if not resolved or resolved == "" then
		resolved = "rbxthumb://type=Asset&id=" .. rawId .. "&w=420&h=420"
	end
	_resolvedCache[rawId] = resolved
	return resolved
end

local UTF8_FALLBACK = {
	[0x2605] = "*",
	[0x2606] = "-",
	[0x2705] = "[OK]",
	[0x274C] = "[X]",
}

local function SafeUtf8Char(code)
	if utf8 and type(utf8.char) == "function" then
		local ok, value = pcall(utf8.char, code)
		if ok and value then return value end
	end
	return UTF8_FALLBACK[code] or ""
end

local logo = "EMOTES — UNIVERSAL"


local Themes = {
    Dark = {
        primary = Color3.fromRGB(4,4,4), sidebar = Color3.fromRGB(7,7,7), secondary = Color3.fromRGB(12,12,12), tertiary = Color3.fromRGB(20,20,20),
        accent = Color3.fromRGB(255,255,255), text = Color3.fromRGB(250,250,250), textDim = Color3.fromRGB(150,150,150), stroke = Color3.fromRGB(82,82,82), strokeHover = Color3.fromRGB(255,255,255), critical = Color3.fromRGB(60,60,60), success = Color3.fromRGB(245,245,245)
    },
    Purple = nil,
    Blue = nil,
    Green = nil,
    Red = nil,
    Light = nil,
    MaterialYou = nil,
    FrostedGlass = nil,
    DarkGlass = nil,
}
Themes.Purple = Themes.Dark
Themes.Blue = Themes.Dark
Themes.Green = Themes.Dark
Themes.Red = Themes.Dark
Themes.Light = Themes.Dark
Themes.MaterialYou = Themes.Dark
Themes.FrostedGlass = Themes.Dark
Themes.DarkGlass = Themes.Dark

local currentTheme = Themes.Dark
local themeElements = {}
local mainStrokeGrad, miniIconGrad
local UpdateTabStyles
local UpdateTabData
local _updateTitleGrad

local function RegisterTheme(el, prop, key)
	if el then themeElements[#themeElements + 1] = {el = el, prop = prop, key = key} end
end

local function Notify(title, text, iconId)
	if not Settings.notifications then return end
	pcall(function()
		local screenGui = playerGui:FindFirstChild("HXEmotes") or game:GetService("CoreGui"):FindFirstChild("HXEmotes")
		if not screenGui then
			game:GetService("StarterGui"):SetCore("SendNotification", {Title = tostring(title or ""), Text = tostring(text or ""), Duration = 3})
			return
		end

		title = tostring(title or "")
		text = tostring(text or "")
		if title == "" and text == "" then return end

		local container = screenGui:FindFirstChild("NotificationContainer")
		local maxW = isMobile and 274 or 326
		if not container then
			container = Instance.new("Frame")
			container.Name = "NotificationContainer"
			container.Size = UDim2.new(0, maxW, 1, -24)
			container.Position = UDim2.new(1, -12, 0, 12)
			container.AnchorPoint = Vector2.new(1, 0)
			container.BackgroundTransparency = 1
			container.BorderSizePixel = 0
			container.ZIndex = 30000
			container.Parent = screenGui

			local uiList = Instance.new("UIListLayout")
			uiList.Padding = UDim.new(0, 7)
			uiList.HorizontalAlignment = Enum.HorizontalAlignment.Right
			uiList.VerticalAlignment = Enum.VerticalAlignment.Top
			uiList.SortOrder = Enum.SortOrder.LayoutOrder
			uiList.Parent = container
		end

		local theme = currentTheme or Themes.Dark
		local iconSpace = iconId and 26 or 0
		local minW = isMobile and 142 or 156
		local sidePad = 24 + iconSpace
		local titleSize = isMobile and 12 or 13
		local bodySize = isMobile and 10 or 11

		local titleNatural = title ~= "" and TextService:GetTextSize(title, titleSize, Enum.Font.GothamBold, Vector2.new(1000, 1000)).X or 0
		local bodyNatural = text ~= "" and TextService:GetTextSize(text, bodySize, Enum.Font.Gotham, Vector2.new(1000, 1000)).X or 0
		local toastW = math.clamp(math.max(titleNatural, bodyNatural) + sidePad + 18, minW, maxW)
		local textW = math.max(70, toastW - sidePad - 18)
		local bodyBounds = text ~= "" and TextService:GetTextSize(text, bodySize, Enum.Font.Gotham, Vector2.new(textW, 1000)) or Vector2.new(0, 0)
		local titleH = title ~= "" and (isMobile and 17 or 19) or 0
		local bodyH = text ~= "" and math.max(isMobile and 14 or 15, bodyBounds.Y) or 0
		local gap = (titleH > 0 and bodyH > 0) and 3 or 0
		local toastH = math.clamp(16 + titleH + gap + bodyH, isMobile and 38 or 40, isMobile and 92 or 104)

		local wrapper = Instance.new("Frame")
		wrapper.BackgroundTransparency = 1
		wrapper.BorderSizePixel = 0
		wrapper.Size = UDim2.new(0, toastW, 0, toastH)
		wrapper.ClipsDescendants = false
		wrapper.Parent = container

		local toast = Instance.new("Frame")
		toast.Name = "HXToast"
		toast.Size = UDim2.fromScale(1, 1)
		toast.Position = UDim2.new(1, 18, 0, 0)
		toast.BackgroundColor3 = Color3.fromRGB(8,8,8)
		toast.BackgroundTransparency = 0.08
		toast.BorderSizePixel = 0
		toast.ZIndex = 30001
		toast.ClipsDescendants = true
		toast.Parent = wrapper
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

		local toastStroke = Instance.new("UIStroke")
		toastStroke.Color = Color3.fromRGB(235,235,235)
		toastStroke.Thickness = 1
		toastStroke.Transparency = 0.48
		toastStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		toastStroke.Parent = toast

		local contentX = 12
		if iconId then
			local notifIcon = Instance.new("ImageLabel")
			notifIcon.Size = UDim2.new(0, isMobile and 17 or 19, 0, isMobile and 17 or 19)
			notifIcon.Position = UDim2.new(0, 12, 0, 10)
			notifIcon.BackgroundTransparency = 1
			notifIcon.Image = ResolveAssetImage("rbxassetid://" .. tostring(iconId))
			notifIcon.ImageColor3 = Color3.fromRGB(255,255,255)
			notifIcon.ScaleType = Enum.ScaleType.Fit
			notifIcon.ZIndex = 30003
			notifIcon.Parent = toast
			contentX = 38
		end

		local y = 8
		if title ~= "" then
			local titleLbl = Instance.new("TextLabel")
			titleLbl.Size = UDim2.new(1, -(contentX + 10), 0, titleH)
			titleLbl.Position = UDim2.new(0, contentX, 0, y)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Text = title
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.TextSize = titleSize
			titleLbl.TextColor3 = theme.text
			titleLbl.TextStrokeTransparency = 1
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.TextYAlignment = Enum.TextYAlignment.Center
			titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			titleLbl.ZIndex = 30004
			titleLbl.Parent = toast
			y = y + titleH + gap
		end

		if text ~= "" then
			local textLbl = Instance.new("TextLabel")
			textLbl.Size = UDim2.new(1, -(contentX + 10), 0, bodyH)
			textLbl.Position = UDim2.new(0, contentX, 0, y)
			textLbl.BackgroundTransparency = 1
			textLbl.Text = text
			textLbl.Font = Enum.Font.Gotham
			textLbl.TextSize = bodySize
			textLbl.TextColor3 = Color3.fromRGB(175,175,175)
			textLbl.TextStrokeTransparency = 1
			textLbl.TextXAlignment = Enum.TextXAlignment.Left
			textLbl.TextYAlignment = Enum.TextYAlignment.Top
			textLbl.TextWrapped = true
			textLbl.ZIndex = 30004
			textLbl.Parent = toast
		end

		toast.BackgroundTransparency = 1
		toastStroke.Transparency = 1
		TweenService:Create(toast, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 0.08
		}):Play()
		TweenService:Create(toastStroke, TweenInfo.new(0.20), {Transparency = 0.48}):Play()

		local duration = math.clamp(2.2 + (#title + #text) * 0.018, 2.4, 4.5)
		task.delay(duration, function()
			if not toast.Parent then return end
			local outTween = TweenService:Create(toast, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 18, 0, 0),
				BackgroundTransparency = 1
			})
			outTween:Play()
			TweenService:Create(toastStroke, TweenInfo.new(0.16), {Transparency = 1}):Play()
			outTween.Completed:Wait()
			if wrapper.Parent then wrapper:Destroy() end
		end)
	end)
end


local function ApplyTheme(name)
	currentTheme = Themes[name] or Themes.Dark
	local alive = {}
	for i = 1, #themeElements do
		local t = themeElements[i]
		if t.el and t.el.Parent then
			alive[#alive + 1] = t
			if currentTheme[t.key] then
				pcall(function()
					TweenService:Create(t.el, TweenInfo.new(0.3), {[t.prop] = currentTheme[t.key]}):Play()
				end)
			end
		end
	end
	themeElements = alive

	if mainStrokeGrad then
		mainStrokeGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255))
	end

	if miniIconGrad then
		miniIconGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, currentTheme.stroke),
			ColorSequenceKeypoint.new(0.33, currentTheme.accent),
			ColorSequenceKeypoint.new(0.66, currentTheme.stroke),
			ColorSequenceKeypoint.new(1, currentTheme.accent)
		}
	end

	if _updateTitleGrad then pcall(_updateTitleGrad) end
	if UpdateTabStyles then UpdateTabStyles() end
end


gui = Instance.new("ScreenGui")
gui.Name = "HXEmotes"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui


-- HX CUT-CORNER / NEON BORDER SYSTEM
-- Draws a true chamfer-style outline using 8 line segments instead of UICorner.
local function HXApplyChamfer(obj, opts)
    if not obj or not obj:IsA("GuiObject") then return end
    opts = opts or {}
    local cut = tonumber(opts.cut) or (isMobile and 6 or 8)
    local color = opts.color or Color3.fromRGB(238,238,238)
    local coreThickness = tonumber(opts.thickness) or 1.05
    local glowThickness = tonumber(opts.glowThickness) or 2.8
    local coreTransparency = tonumber(opts.coreTransparency)
    if coreTransparency == nil then coreTransparency = 0.42 end
    local glowTransparency = tonumber(opts.glowTransparency)
    if glowTransparency == nil then glowTransparency = 0.90 end
    local transparent = opts.transparent == true

    obj:SetAttribute("HXChamfer", true)
    if transparent then
        obj:SetAttribute("HXChamferTransparent", true)
        obj.BackgroundTransparency = 1
        if not obj:GetAttribute("HXChamferBgGuard") then
            obj:SetAttribute("HXChamferBgGuard", true)
            obj:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
                if obj and obj.Parent and obj:GetAttribute("HXChamferTransparent") and obj.BackgroundTransparency ~= 1 then
                    obj.BackgroundTransparency = 1
                end
            end)
        end
    end

    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("UICorner") then
            child:Destroy()
        elseif child:IsA("UIStroke") and not child:GetAttribute("HXKeepStroke") then
            child.Enabled = false
        elseif child.Name == "HXChamferBorder" then
            child:Destroy()
        end
    end

    local border = Instance.new("Frame")
    border.Name = "HXChamferBorder"
    border.Size = UDim2.fromScale(1,1)
    border.Position = UDim2.fromScale(0,0)
    border.BackgroundTransparency = 1
    border.BorderSizePixel = 0
    border.Active = false
    border.Selectable = false
    border.ZIndex = obj.ZIndex + 30
    border:SetAttribute("HXNoAutoCorner", true)
    border.Parent = obj

    local function line(name, size, pos, rotation, thickness, transparency, zadd)
        local f = Instance.new("Frame")
        f.Name = name
        f.Size = size
        f.Position = pos
        f.AnchorPoint = Vector2.new(0.5,0.5)
        f.Rotation = rotation or 0
        f.BackgroundColor3 = color
        f.BackgroundTransparency = transparency
        f.BorderSizePixel = 0
        f.Active = false
        f.Selectable = false
        f.ZIndex = border.ZIndex + (zadd or 0)
        f:SetAttribute("HXNoAutoCorner", true)
        f.Parent = border
        return f
    end

    local function build(prefix, thickness, transparency, zadd)
        local diagLen = math.max(2, math.floor(cut * 1.42))
        -- straight edges
        line(prefix.."Top",    UDim2.new(1,-cut*2,0,thickness), UDim2.new(0.5,0,0,thickness/2), 0, thickness, transparency, zadd)
        line(prefix.."Bottom", UDim2.new(1,-cut*2,0,thickness), UDim2.new(0.5,0,1,-thickness/2), 0, thickness, transparency, zadd)
        line(prefix.."Left",   UDim2.new(0,thickness,1,-cut*2), UDim2.new(0,thickness/2,0.5,0), 0, thickness, transparency, zadd)
        line(prefix.."Right",  UDim2.new(0,thickness,1,-cut*2), UDim2.new(1,-thickness/2,0.5,0), 0, thickness, transparency, zadd)
        -- diagonal cut corners
        line(prefix.."TL", UDim2.new(0,diagLen,0,thickness), UDim2.new(0,cut/2,0,cut/2), -45, thickness, transparency, zadd)
        line(prefix.."TR", UDim2.new(0,diagLen,0,thickness), UDim2.new(1,-cut/2,0,cut/2), 45, thickness, transparency, zadd)
        line(prefix.."BL", UDim2.new(0,diagLen,0,thickness), UDim2.new(0,cut/2,1,-cut/2), 45, thickness, transparency, zadd)
        line(prefix.."BR", UDim2.new(0,diagLen,0,thickness), UDim2.new(1,-cut/2,1,-cut/2), -45, thickness, transparency, zadd)
    end

    build("Glow", glowThickness, glowTransparency, 0)
    build("Core", coreThickness, coreTransparency, 2)
    return border
end

-- Restyle an existing chamfer without rebuilding it. Allows normal/hover/selected
-- states and lets selected cards emphasize only their cut corners.
local function HXStyleChamfer(obj, opts)
    if not obj then return end
    opts = opts or {}
    local border = obj:FindFirstChild("HXChamferBorder")
    if not border then return end
    local coreT = opts.coreTransparency
    local glowT = opts.glowTransparency
    local cornerCoreT = opts.cornerCoreTransparency
    local cornerGlowT = opts.cornerGlowTransparency
    local cornerCoreThickness = opts.cornerCoreThickness
    local cornerGlowThickness = opts.cornerGlowThickness
    local color = opts.color

    local function isCorner(name)
        return name:match("TL$") or name:match("TR$") or name:match("BL$") or name:match("BR$")
    end

    for _, seg in ipairs(border:GetChildren()) do
        if seg:IsA("Frame") then
            local name = seg.Name
            local corner = isCorner(name) ~= nil
            if color then seg.BackgroundColor3 = color end
            if name:sub(1,4) == "Core" then
                local t = corner and cornerCoreT or coreT
                if t ~= nil then seg.BackgroundTransparency = t end
                if corner and cornerCoreThickness then
                    seg.Size = UDim2.new(seg.Size.X.Scale, seg.Size.X.Offset, seg.Size.Y.Scale, cornerCoreThickness)
                end
            elseif name:sub(1,4) == "Glow" then
                local t = corner and cornerGlowT or glowT
                if t ~= nil then seg.BackgroundTransparency = t end
                if corner and cornerGlowThickness then
                    seg.Size = UDim2.new(seg.Size.X.Scale, seg.Size.X.Offset, seg.Size.Y.Scale, cornerGlowThickness)
                end
            end
        end
    end
end

local function HXNormalizeVisual(obj)
    if obj:IsA("UICorner") and obj.Parent and obj.Parent:GetAttribute("HXChamfer") then
        obj:Destroy()
        return
    end
    if obj:IsA("UIStroke") and obj.Parent and obj.Parent:GetAttribute("HXChamfer") and not obj:GetAttribute("HXKeepStroke") then
        obj.Enabled = false
        return
    end
    if obj:IsA("GuiObject") then
        obj.BorderSizePixel = 0
    end

    -- GLOBAL: no text outline/stroke anywhere in HX Emotes.
    -- This also protects text created later by notifications, dialogs, cards, etc.
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        obj.TextStrokeTransparency = 1
        pcall(function() obj.TextStrokeColor3 = obj.TextColor3 end)
        if not obj:GetAttribute("HXNoTextStroke") then
            obj:SetAttribute("HXNoTextStroke", true)
            obj:GetPropertyChangedSignal("TextStrokeTransparency"):Connect(function()
                if obj and obj.Parent and obj.TextStrokeTransparency ~= 1 then
                    obj.TextStrokeTransparency = 1
                end
            end)
        end
    end

    if obj:IsA("UIStroke") then
        local parent = obj.Parent
        -- UIStroke directly on a TextLabel can look like a glowing text outline.
        -- Disable it while keeping button/input/frame borders intact.
        if parent and parent:IsA("TextLabel") then
            obj.Enabled = false
            return
        end
        pcall(function() obj.LineJoinMode = Enum.LineJoinMode.Round end)
        if parent and parent:IsA("GuiObject") and not parent:GetAttribute("HXChamfer") and not parent:GetAttribute("HXNoAutoCorner") and not parent:FindFirstChildOfClass("UICorner") then
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 10)
            c.Parent = parent
        end
    end
    if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Parent and obj.Parent:IsA("TextButton") then
        if tostring(obj.Parent.Name):sub(1,4) == "Nav_" then
            obj.ImageColor3 = Color3.fromRGB(255,255,255)
        else
            obj.ImageColor3 = Color3.fromRGB(255,255,255)
        end
    end
    if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ImageButton") then
        if obj.BackgroundTransparency < 1 and not obj:GetAttribute("HXChamfer") and not obj:GetAttribute("HXNoAutoCorner") and not obj:FindFirstChildOfClass("UICorner") then
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 10)
            c.Parent = obj
        end
    end
end

for _, obj in ipairs(gui:GetDescendants()) do
    HXNormalizeVisual(obj)
end
local _hxVisualConn = gui.DescendantAdded:Connect(function(obj)
    task.defer(function()
        if obj and obj.Parent then HXNormalizeVisual(obj) end
    end)
end)


local function HXCreateStarfield(parent, zIndex, count, minX, maxX, minY, maxY)
    if not parent then return end
    count = count or (isMobile and 70 or 120)
    minX, maxX = minX or 3, maxX or 97
    minY, maxY = minY or 4, maxY or 96

    for i = 1, count do
        local star = Instance.new("Frame")
        local s = math.random(1, 3)
        if i % 11 == 0 then s = 4 end
        star.Name = "HXStar"
        star.Size = UDim2.new(0, s, 0, s)
        star.Position = UDim2.new(math.random(minX, maxX) / 100, 0, math.random(minY, maxY) / 100, 0)
        star.AnchorPoint = Vector2.new(0.5, 0.5)
        star.BackgroundColor3 = Color3.fromRGB(255,255,255)
        star.BackgroundTransparency = math.random(5, 36) / 100
        star.BorderSizePixel = 0
        star.ZIndex = zIndex
        star.Parent = parent
        Instance.new("UICorner", star).CornerRadius = UDim.new(1, 0)

        if i % 4 == 0 then
            local glow = Instance.new("Frame")
            glow.Name = "HXStarGlow"
            glow.Size = UDim2.new(0, s + math.random(4, 7), 0, s + math.random(4, 7))
            glow.Position = UDim2.fromScale(0.5, 0.5)
            glow.AnchorPoint = Vector2.new(0.5, 0.5)
            glow.BackgroundColor3 = Color3.fromRGB(255,255,255)
            glow.BackgroundTransparency = math.random(76, 88) / 100
            glow.BorderSizePixel = 0
            glow.ZIndex = zIndex - 1
            glow.Parent = star
            Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
        end

        task.spawn(function()
            while star.Parent and parent.Parent do
                local targetX = math.clamp(star.Position.X.Scale + math.random(-4,4)/100, minX/100, maxX/100)
                local targetY = math.clamp(star.Position.Y.Scale + math.random(-4,4)/100, minY/100, maxY/100)
                local targetT = math.random(2, 28) / 100
                local tw = TweenService:Create(star, TweenInfo.new(math.random(28, 55)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Position = UDim2.new(targetX, 0, targetY, 0),
                    BackgroundTransparency = targetT
                })
                tw:Play()
                tw.Completed:Wait()
            end
        end)
    end
end

-- Load saved data before showing the language gate.
LoadData()

local selectedLang = nil
local rememberLang = false

if Settings.language == "ES" or Settings.language == "EN" then
    selectedLang = Settings.language
else
    Settings.language = nil
end

if not selectedLang then
    local langTheme = Themes.Dark

    langScreen = Instance.new("Frame")
    langScreen.Name = "LanguageGate"
    langScreen.Size = UDim2.fromScale(1, 1)
    langScreen.BackgroundColor3 = currentTheme.primary
    langScreen.BackgroundTransparency = 0.22
    langScreen.BorderSizePixel = 0
    langScreen.ZIndex = 20000
    langScreen.Parent = gui

    local dimGrid = Instance.new("Frame")
    dimGrid.Size = UDim2.fromScale(1, 1)
    dimGrid.BackgroundColor3 = currentTheme.secondary
    dimGrid.BackgroundTransparency = 0.56
    dimGrid.BorderSizePixel = 0
    dimGrid.ZIndex = 20000
    dimGrid.Parent = langScreen

    HXCreateStarfield(langScreen, 20001, isMobile and 78 or 135, 2, 98, 3, 97)

    langBox = Instance.new("Frame")
    langBox.Name = "LanguagePanel"
    langBox.Size = UDim2.new(0, 0, 0, 0)
    langBox.Position = UDim2.fromScale(0.5, 0.5)
    langBox.AnchorPoint = Vector2.new(0.5, 0.5)
    langBox.BackgroundColor3 = currentTheme.secondary
    langBox.BackgroundTransparency = 0.14
    langBox.BorderSizePixel = 0
    langBox.ClipsDescendants = true
    langBox.ZIndex = 20002
    langBox.Parent = langScreen
    Instance.new("UICorner", langBox).CornerRadius = UDim.new(0, 18)

    local langStroke = Instance.new("UIStroke")
    langStroke.Color = Color3.fromRGB(235,235,235)
    langStroke.Thickness = 0
    langStroke.Transparency = 1
    langStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    langStroke.Parent = langBox

    local langInnerOutline = Instance.new("Frame")
    langInnerOutline.Name = "HXLanguageInnerOutline"
    langInnerOutline.Size = UDim2.new(1, -4, 1, -4)
    langInnerOutline.Position = UDim2.new(0, 2, 0, 2)
    langInnerOutline.BackgroundTransparency = 1
    langInnerOutline.BorderSizePixel = 0
    langInnerOutline.ZIndex = 20010
    langInnerOutline.Active = false
    langInnerOutline.Parent = langBox
    Instance.new("UICorner", langInnerOutline).CornerRadius = UDim.new(0, 15)

    local langInnerStroke = Instance.new("UIStroke")
    langInnerStroke.Color = Color3.fromRGB(235,235,235)
    langInnerStroke.Thickness = 1.2
    langInnerStroke.Transparency = 0.03
    langInnerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pcall(function() langInnerStroke.LineJoinMode = Enum.LineJoinMode.Round end)
    langInnerStroke.Parent = langInnerOutline

    local langLogo = Instance.new("ImageLabel")
    langLogo.Size = UDim2.new(0, 18, 0, 18)
    langLogo.Position = UDim2.new(1, -32, 0, 14)
    langLogo.BackgroundTransparency = 1
    langLogo.Image = "rbxassetid://72742584610344"
    langLogo.ImageColor3 = Color3.fromRGB(255,255,255)
    langLogo.ScaleType = Enum.ScaleType.Fit
    langLogo.ZIndex = 20003
    langLogo.Parent = langBox
    langLogo.Visible = false

    langTitle = Instance.new("TextLabel")
    langTitle.Size = UDim2.new(1, -52, 0, 34)
    langTitle.Position = UDim2.new(0, 16, 0, 12)
    langTitle.BackgroundTransparency = 1
    langTitle.Text = "SELECT LANGUAGE\nSELECCIONA IDIOMA"
    langTitle.TextColor3 = Color3.fromRGB(255,255,255)
    langTitle.Font = Enum.Font.GothamBlack
    langTitle.TextSize = isMobile and 12 or 15
    langTitle.TextXAlignment = Enum.TextXAlignment.Left
    langTitle.TextYAlignment = Enum.TextYAlignment.Center
    langTitle.ZIndex = 20003
    langTitle.Parent = langBox
    langTitle.Visible = false

    local langSub = Instance.new("TextLabel")
    langSub.Size = UDim2.new(1, -40, 0, 18)
    langSub.Position = UDim2.new(0, 16, 0, 45)
    langSub.BackgroundTransparency = 1
    langSub.Text = "EMOTES   UNIVERSAL   ES · EN"
    langSub.TextColor3 = Color3.fromRGB(130,130,130)
    langSub.Font = Enum.Font.GothamMedium
    langSub.TextSize = isMobile and 7 or 8
    langSub.TextXAlignment = Enum.TextXAlignment.Left
    langSub.ZIndex = 20003
    langSub.Parent = langBox
    langSub.Visible = false

    local function MakeLangBtn(flag, titleText, subText, lang, xScale)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.40, 0, 0, isMobile and 52 or 56)
        btn.Position = UDim2.new(xScale, 0, 0, 48)
        btn.BackgroundColor3 = currentTheme.tertiary
        btn.BackgroundTransparency = 0.16
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 20004
        btn.Parent = langBox
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(70,70,70)
        stroke.Thickness = 0.8
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        pcall(function() stroke.LineJoinMode = Enum.LineJoinMode.Round end)
        stroke.Parent = btn

        local flagLbl = Instance.new("TextLabel")
        flagLbl.Size = UDim2.new(0, 46, 1, 0)
        flagLbl.Position = UDim2.new(0, 8, 0, 0)
        flagLbl.BackgroundTransparency = 1
        flagLbl.Text = flag
        flagLbl.TextColor3 = Color3.fromRGB(255,255,255)
        flagLbl.Font = Enum.Font.GothamBold
        flagLbl.TextSize = isMobile and 22 or 24
        flagLbl.ZIndex = 20005
        flagLbl.Parent = btn

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -60, 0, 24)
        t.Position = UDim2.new(0, 52, 0, 8)
        t.BackgroundTransparency = 1
        t.Text = titleText
        t.TextColor3 = Color3.fromRGB(255,255,255)
        t.Font = Enum.Font.GothamBlack
        t.TextSize = isMobile and 11 or 13
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.ZIndex = 20005
        t.Parent = btn

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -60, 0, 17)
        sub.Position = UDim2.new(0, 52, 0, 28)
        sub.BackgroundTransparency = 1
        sub.Text = subText
        sub.TextColor3 = Color3.fromRGB(125,125,125)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = isMobile and 8 or 9
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.ZIndex = 20005
        sub.Parent = btn

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(30,30,30), BackgroundTransparency = 0.05}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.18), {Color = Color3.fromRGB(255,255,255)}):Play()
            TweenService:Create(t, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255,255,255)}):Play()
            TweenService:Create(sub, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(180,180,180)}):Play()
            TweenService:Create(flagLbl, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255,255,255)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundColor3 = currentTheme.tertiary, BackgroundTransparency = 0.16}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.18), {Color = Color3.fromRGB(70,70,70)}):Play()
            TweenService:Create(t, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255,255,255)}):Play()
            TweenService:Create(sub, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(125,125,125)}):Play()
            TweenService:Create(flagLbl, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255,255,255)}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            selectedLang = lang
        end)
    end

    MakeLangBtn("🇪🇸", "ESPAÑOL", "Interfaz en español", "ES", 0.07)
    MakeLangBtn("🇺🇸", "ENGLISH", "English interface", "EN", 0.53)

    rememberBtn = Instance.new("TextButton")
    rememberBtn.Size = UDim2.new(0.86, 0, 0, 28)
    rememberBtn.Position = UDim2.new(0.07, 0, 1, -48)
    rememberBtn.BackgroundColor3 = currentTheme.tertiary
    rememberBtn.BackgroundTransparency = 0.16
    rememberBtn.Text = "RECORDAR / REMEMBER"
    rememberBtn.TextColor3 = Color3.fromRGB(155,155,155)
    rememberBtn.Font = Enum.Font.GothamBold
    rememberBtn.TextSize = isMobile and 10 or 11
    rememberBtn.AutoButtonColor = false
    rememberBtn.ZIndex = 20004
    rememberBtn.Parent = langBox
    Instance.new("UICorner", rememberBtn).CornerRadius = UDim.new(0, 10)
    local remStroke = Instance.new("UIStroke")
    remStroke.Color = Color3.fromRGB(55,55,55)
    remStroke.Thickness = 0.8
    remStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pcall(function() remStroke.LineJoinMode = Enum.LineJoinMode.Round end)
    remStroke.Parent = rememberBtn

    rememberBtn.MouseButton1Click:Connect(function()
        rememberLang = not rememberLang
        rememberBtn.Text = "RECORDAR / REMEMBER"
        TweenService:Create(rememberBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = rememberLang and Color3.fromRGB(28,28,28) or Color3.fromRGB(14,14,14),
            TextColor3 = rememberLang and Color3.fromRGB(255,255,255) or Color3.fromRGB(155,155,155)
        }):Play()
        TweenService:Create(remStroke, TweenInfo.new(0.18), {
            Color = rememberLang and Color3.fromRGB(245,245,245) or Color3.fromRGB(55,55,55)
        }):Play()
    end)

    local targetSize = isMobile and UDim2.new(0, 286, 0, 176) or UDim2.new(0, 370, 0, 188)
    TweenService:Create(langBox, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = targetSize}):Play()

    repeat task.wait(0.05) until selectedLang

    if rememberLang then
        Settings.language = selectedLang
        SaveData()
    end

    TweenService:Create(langBox, TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
    TweenService:Create(langScreen, TweenInfo.new(0.20), {BackgroundTransparency = 1}):Play()
    task.wait(0.20)
    langScreen:Destroy()
end


local isTR, isES, isAR, isFR, isHI, isPT, isRU = false, selectedLang == "ES", false, false, false, false, false
local L = {
	r6Msg = isES and "Este juego usa R6. El panel seguirá abierto; algunos emotes pueden no ser compatibles." or "This game uses R6. The panel will stay open; some emotes may not be compatible.",
	loading = isES and "Cargando..." or "Loading...",
	madeBy = "",
	search = isES and "Buscar emote..." or "Search emote...",
	playing = isES and "Reproduciendo" or "Playing",
	stopped = isES and "Detenido" or "Stopped",
	ready = isES and "Listo!" or "Ready!",
	emotes = isES and "Emotes" or "Emotes",
	favorites = isES and "Favoritos" or "Favorites",
	recent = isES and "Recientes" or "Recent",
	settings = isES and "Ajustes" or "Settings",
	noFav = isES and "No tienes emotes favoritos." or "You have no favorite emotes.",
	noRecent = isES and "Sin recientes" or "No recent",
	theme = isES and "Tema" or "Theme",
	speed = isES and "Velocidad" or "Speed",
	notif = isES and "Notificaciones" or "Notifications",
	on = isES and "On" or "On",
	off = isES and "Off" or "Off",
	copied = isES and "Copiado!" or "Copied!",
	loopText = isES and "Bucle" or "Loop",
	comboTitle = isES and "Cola de Combo" or "Combo Queue",
	addEmote = isES and "+ Añadir" or "+ Add",
	playCombo = isES and "Reproducir" or "Play",
	clearCombo = isES and "Limpiar" or "Clear",
	selectFirst = isES and "¡Selecciona!" or "Select first!",
	slotLabel = isES and "Ranura" or "Slot",
	infoTitle = isES and "Info del Emote" or "Emote Info",
	noDesc = isES and "Sin descripción" or "No description",
	freePrice = isES and "Gratis" or "Free",
	copyId = isES and "Copiar ID" or "Copy ID",
	copyEmote = isES and "Copiar Emote" or "Copy Emote",
	favLimit = isES and "¡Máximo 25 favoritos!" or "Max 25 favorites!",
	copyEmoteDesc = isES and "Copia el emote que usa otro jugador" or "Copies the emote used by another player",
	stopOnWalk = isES and "Parar emote al caminar" or "Stop emote when walking",
	stopOnWalkDesc = isES and "El emote se detiene al caminar" or "Emote stops automatically when walking",
	showHUD = isES and "Mostrar barra de reproducción" or "Show playback bar",
	friendTab = isES and "Amigos" or "Friends",
	accept = isES and "Aceptar" or "Accept",
	reject = isES and "Rechazar" or "Reject",
	friendAlreadySyncing = isES and "Error! El jugador ya está sincronizado con otro." or "Error! Player is already syncing with someone else.",
	showHUDDesc = isES and "Muestra la barra de control al reproducir emotes" or "Shows the playback control bar while emote plays",
	keybinds = isES and "Teclas" or "Keybinds",
	newKeybind = isES and "Crear Nuevo Keybind" or "New Keybind",
	editKeybind = isES and "Cambiar Keybind" or "Edit Keybind",
	kbName = isES and "Nombre" or "Name",
	kbAssign = isES and "Asignación" or "Assign",
	kbRecording = isES and "Presiona Tecla" or "Press Key",
	kbCancel = isES and "Cancelar" or "Cancel",
	kbSave = isES and "Guardar" or "Save",
	kbEmpty = isES and "Sin keybinds aún" or "No keybinds yet",
	noSearch = isES and "Sin resultados" or "No results found",
	kbInvalidKey = isES and "¡Tecla inválida!" or "Invalid key!",
	autoRejectLbl = isES and "Rechazar solicitudes automáticamente." or "Auto-reject friend requests.",
	addFriendBtn = isES and "+ Añadir Amigo" or "+ Add Friend",
	blocked = isES and "Bloqueado" or "Blocked",
	requestSent = isES and "✓ Solicitud Enviada" or "✓ Request Sent",
	addFriendMode = isES and "+ Modo Añadir Amigo" or "+ Add Friend Mode",
	friendInfoTxt = isES and "Guarda jugadores del servidor y síguelos con SYNC sin usar servicios externos." or "Save players from this server and follow them with SYNC without external services.",
	friendListHeader = isES and "Lista de Amigos" or "Friend List",
	noFriends = isES and "Sin amigos. ¡Usa el botón Añadir Amigo!" or "No friends yet. Use Add Friend button!",
	emoteLoadFail = isES and "¡Error al cargar emote!" or "Failed to load emote!",
	alreadyFriends = isES and "¡Ya son amigos!" or "Already friends!",
	spamProtect = isES and "¡Protección spam! Espera %ds" or "Spam protection! Wait %ds",
	waitRequest = isES and "Espera %ds para enviar solicitud" or "Wait %ds to send request",
	tooFastRequest = isES and "¡Demasiado rápido! %ds timeout" or "Too fast! %ds timeout",
	friendReqSent = isES and "¡Solicitud enviada a %s!" or "Friend request sent to %s!",
	friendReqAcceptedYou = isES and "¡Aceptaste la solicitud de %s!" or "You accepted %s's request!",
	friendReqAcceptedThem = isES and "¡%s aceptó tu solicitud!" or "%s accepted your request!",
	acceptRequestsLbl = isES and "Aceptar solicitudes" or "Accept friend requests",
	resetLangLbl = isES and "Restablecer idioma" or "Reset Language",
	resetButton = isES and 'Restablecer' or 'Reset',
	searchPlaylists = isES and "Buscar Listas..." or "Search Playlists...",
	done = isES and "Listo" or "Done",
	createPlaylist = isES and "Crear Lista de Reproducción" or "Create Playlist",
	playlistName = isES and "Nombre de la Lista" or "Playlist Name",
	playlistNamePlaceholder = isES and "Ej: Mis favoritos" or "e.g., My favorites",
	selectEmote = isES and "Seleccionar" or "Select",
	deletePlaylist = isES and "Eliminar" or "Delete",
	deleteConfirm = isES and "¿Seguro?" or "Sure?",
	createdBy = isES and "Creado por " or "Created by ",
	playlistsTab = isES and "Listas de Reproducción" or "Playlists",
	serverPlayersDown = isES and "Jugadores en Servidor ▼" or "Server Players ▼",
	serverPlayersUp = isES and "Jugadores en Servidor ▲" or "Server Players ▲",
	noOneFound = isES and "Nadie encontrado" or "No one found",
	order = isES and "Orden" or "Order",
	defaultSort = isES and "PREDETERMINADO" or "DEFAULT",
	emoteType = "EMOTE",
	animationPack = isES and "PAQUETE DE ANIMACIÓN" or "ANIMATION PACK",
	discordCopied = isES and "Enlace de Discord copiado." or "Discord link copied.",
	emotesAvailable = isES and "%d emotes disponibles" or "%d emotes available",
}

local FriendL = {
	brandTitle = isES and "Reproductor Universal de Emotes" or "Universal Emote Player",
	requestIncoming = isES and "%s quiere agregarte como amigo." or "%s wants to add you as a friend.",
	playEmoteLbl = isES and "Reproducir emote de amigo" or "Play friend's emote",
	playEmoteDesc = isES and "Se reproduce automáticamente cuando tu amigo lo inicia." or "Plays automatically when your friend starts it.",
	syncEmoteLbl = isES and "Sincronizar emote con amigos" or "Sync emote with friends",
	syncEmoteDesc = isES and "Permite seguir localmente el emote de un jugador guardado del mismo servidor." or "Lets you locally follow a saved player emote in the same server.",
	syncOn = isES and "Sincronizado" or "Sync",
	syncOff = isES and "Desactivado" or "Off",
}

local EmoteNameES = {
    ["salute"]="Saludo", ["wave"]="Saludar", ["point"]="Señalar", ["dance"]="Baile", ["laugh"]="Risa", ["cheer"]="Animar",
    ["applaud"]="Aplaudir", ["applause"]="Aplauso", ["shrug"]="Encogerse de hombros", ["hello"]="Hola", ["bored"]="Aburrido",
    ["confused"]="Confundido", ["shy"]="Tímido", ["happy"]="Feliz", ["sad"]="Triste", ["sleep"]="Dormir", ["sleepy"]="Soñoliento",
    ["celebrate"]="Celebrar", ["celebration"]="Celebración", ["beckon"]="Llamar", ["dizzy"]="Mareado", ["sneaky"]="Sigiloso",
    ["twirl"]="Giro", ["tilt"]="Inclinar", ["fashionable"]="Elegante", ["stadium"]="Estadio", ["bodybuilder"]="Fisicoculturista",
    ["robot"]="Robot", ["monkey"]="Mono", ["fishing"]="Pescar", ["curtsy"]="Reverencia", ["air guitar"]="Guitarra aérea",
    ["air dance"]="Baile aéreo", ["break dance"]="Breakdance", ["floss dance"]="Baile Floss", ["hype dance"]="Baile Hype",
    ["country line dance"]="Baile country", ["side to side"]="De lado a lado", ["around town"]="Por la ciudad", ["baby dance"]="Baile de bebé",
    ["jumping wave"]="Saludo con salto", ["fancy feet"]="Pasos elegantes", ["bouncy twirl"]="Giro con rebote", ["top rock"]="Top Rock",
    ["ninja pack"]="Paquete Ninja", ["mage pack"]="Paquete Mago", ["great"]="Genial", ["godlike"]="Divino", ["agree"]="De acuerdo",
    ["disagree"]="En desacuerdo", ["excited"]="Emocionado", ["victory"]="Victoria", ["clap"]="Aplaudir", ["bow"]="Reverencia",
    ["sit"]="Sentarse", ["stand"]="De pie", ["spin"]="Girar", ["jump"]="Saltar", ["run"]="Correr", ["walk"]="Caminar"
}
local EmoteWordES = {
    dance="Baile", dancing="Baile", salute="Saludo", wave="Saludo", happy="Feliz", sad="Triste", sleepy="Soñoliento", sleep="Dormir",
    laugh="Risa", laughing="Riendo", cheer="Animar", confused="Confundido", shy="Tímido", fancy="Elegante", feet="Pasos", robot="Robot",
    monkey="Mono", spin="Giro", spinning="Girando", jump="Salto", jumping="Saltando", run="Correr", running="Corriendo", walk="Caminar",
    walking="Caminando", victory="Victoria", clap="Aplauso", clapping="Aplaudiendo", bow="Reverencia", sit="Sentarse", sitting="Sentado"
}
local function LocalizeEmoteName(name)
    local raw = tostring(name or (isES and "Emote" or "Emote"))
    if not isES or raw == "" then return raw end
    local exact = EmoteNameES[raw:lower()]
    if exact then return exact end
    local changed = false
    local translated = raw:gsub("%a+", function(word)
        local replacement = EmoteWordES[word:lower()]
        if replacement then changed = true; return replacement end
        return word
    end)
    return changed and translated or raw
end

local Icons = {
	Emote = "rbxassetid://138124492647096",
	Sort = "rbxassetid://113816420281431",
	Refresh = "rbxassetid://105648271243690",
	Info = "rbxassetid://84622089809608",
	Crown = "rbxassetid://73989246452336",
	Minus = "rbxassetid://113043537756950",
	Close = "rbxassetid://71734731066706",
	Search = "rbxassetid://100759629447583",
	FavoriteEmpty = "rbxassetid://139336655769578",
	FavoriteFull = "rbxassetid://114412745011584",
	Stop = "STOP_SHAPE",
	Keybind = "rbxassetid://122679509852670",
	KeybindActive = "rbxassetid://133187471200337",
	KeybindRemove = "rbxassetid://119388907849573",
	Settings = "rbxassetid://94488099205692",
	Recent = "rbxassetid://89358357551545",
	Check = "rbxassetid://71514022902819",
	Quatrefoil = "rbxassetid://98400541052448",
}


local char = player.Character or player.CharacterAdded:Wait()
local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)

local function HXRunR6WarningGate()
    if not hum or hum.RigType ~= Enum.HumanoidRigType.R6 then
        return true
    end

    local r6Screen = Instance.new("Frame")
    r6Screen.Name = "R6WarningGate"
    r6Screen.Size = UDim2.fromScale(1,1)
    r6Screen.BackgroundColor3 = currentTheme.primary
    r6Screen.BackgroundTransparency = 0.16
    r6Screen.BorderSizePixel = 0
    r6Screen.ZIndex = 22000
    r6Screen.Parent = gui
    HXCreateStarfield(r6Screen, 22001, isMobile and 88 or 150, 2, 98, 3, 97)

    local box = Instance.new("Frame")
    box.Name = "R6WarningPanel"
    box.Size = UDim2.new(0,0,0,0)
    box.Position = UDim2.fromScale(0.5,0.5)
    box.AnchorPoint = Vector2.new(0.5,0.5)
    box.BackgroundColor3 = currentTheme.secondary
    box.BackgroundTransparency = 0.08
    box.BorderSizePixel = 0
    box.ClipsDescendants = true
    box.ZIndex = 22002
    box.Parent = r6Screen
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,18)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(245,245,245)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.08
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = box

    local logoR6 = Instance.new("ImageLabel")
    logoR6.Size = UDim2.new(0,22,0,22)
    logoR6.Position = UDim2.new(1,-38,0,16)
    logoR6.BackgroundTransparency = 1
    logoR6.Image = "rbxassetid://72742584610344"
    logoR6.ImageColor3 = Color3.fromRGB(255,255,255)
    logoR6.ScaleType = Enum.ScaleType.Fit
    logoR6.ZIndex = 22004
    logoR6.Parent = box

    local titleR6 = Instance.new("TextLabel")
    titleR6.Size = UDim2.new(1,-60,0,26)
    titleR6.Position = UDim2.new(0,16,0,14)
    titleR6.BackgroundTransparency = 1
    titleR6.Text = isES and "COMPATIBILIDAD R6" or "R6 COMPATIBILITY"
    titleR6.TextColor3 = Color3.fromRGB(255,255,255)
    titleR6.Font = Enum.Font.Gotham
    titleR6.TextSize = isMobile and 13 or 15
    titleR6.TextXAlignment = Enum.TextXAlignment.Left
    titleR6.ZIndex = 22004
    titleR6.Parent = box

    local messageR6 = Instance.new("TextLabel")
    messageR6.Size = UDim2.new(1,-32,0,isMobile and 80 or 76)
    messageR6.Position = UDim2.new(0,16,0,48)
    messageR6.BackgroundTransparency = 1
    messageR6.Text = isES
        and "Este juego usa R6, por lo cual la mayoría de los emotes, o incluso todos, pueden dejar de funcionar correctamente. ¿Deseas continuar aun así?"
        or "This game uses R6, so most emotes, or even all of them, may not work correctly. Do you still want to continue?"
    messageR6.TextColor3 = Color3.fromRGB(185,185,185)
    messageR6.Font = Enum.Font.Gotham
    messageR6.TextSize = isMobile and 10 or 11
    messageR6.TextWrapped = true
    messageR6.TextXAlignment = Enum.TextXAlignment.Left
    messageR6.TextYAlignment = Enum.TextYAlignment.Top
    messageR6.ZIndex = 22004
    messageR6.Parent = box

    local continueBtn = Instance.new("TextButton")
    continueBtn.Size = UDim2.new(0.42,0,0,32)
    continueBtn.Position = UDim2.new(0.06,0,1,-48)
    continueBtn.BackgroundColor3 = Color3.fromRGB(245,245,245)
    continueBtn.BorderSizePixel = 0
    continueBtn.Text = isES and "CONTINUAR" or "CONTINUE"
    continueBtn.TextColor3 = Color3.fromRGB(6,6,6)
    continueBtn.Font = Enum.Font.Gotham
    continueBtn.TextSize = isMobile and 10 or 11
    continueBtn.AutoButtonColor = false
    continueBtn.ZIndex = 22004
    continueBtn.Parent = box
    Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0,10)

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.42,0,0,32)
    cancelBtn.Position = UDim2.new(0.52,0,1,-48)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(20,20,20)
    cancelBtn.BackgroundTransparency = 0.02
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = isES and "CANCELAR" or "CANCEL"
    cancelBtn.TextColor3 = Color3.fromRGB(235,235,235)
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.TextSize = isMobile and 10 or 11
    cancelBtn.AutoButtonColor = false
    cancelBtn.ZIndex = 22004
    cancelBtn.Parent = box
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0,10)
    local cancelStroke = Instance.new("UIStroke")
    cancelStroke.Color = Color3.fromRGB(90,90,90)
    cancelStroke.Thickness = 1
    cancelStroke.Parent = cancelBtn

    local choice = nil
    continueBtn.MouseButton1Click:Connect(function() choice = true end)
    cancelBtn.MouseButton1Click:Connect(function() choice = false end)

    local target = isMobile and UDim2.new(0,302,0,206) or UDim2.new(0,392,0,202)
    TweenService:Create(box, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target}):Play()

    repeat task.wait(0.05) until choice ~= nil

    TweenService:Create(box, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
    TweenService:Create(r6Screen, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
    task.wait(0.20)
    if r6Screen.Parent then r6Screen:Destroy() end
    return choice
end

if not HXRunR6WarningGate() then
    if gui and gui.Parent then gui:Destroy() end
    return
end

local Emotes = {}


local _bgMusic
do
local _splashTheme = Themes.Dark
local _splashPrimary = Color3.fromRGB(2,2,2)
local _splashAccent = Color3.fromRGB(255,255,255)
local _splashIsGlass = false

_bgMusic = Instance.new("Sound")
_bgMusic.Volume = 1
_bgMusic.Looped = true
_bgMusic.Parent = gui
task.spawn(function()
    local ok, audioId = pcall(getcustomasset, "gta_iv_theme.ogg")
    if ok and audioId and audioId ~= "" then
        _bgMusic.SoundId = audioId
        _bgMusic:Play()
    end
end)

splashBlur = Instance.new("BlurEffect")
splashBlur.Size = 14
splashBlur.Parent = game:GetService("Lighting")

splash = Instance.new("Frame")
splash.Size = UDim2.fromScale(1, 1)
splash.BackgroundColor3 = currentTheme.primary
splash.BackgroundTransparency = 0.20
splash.BorderSizePixel = 0
splash.ZIndex = 10000
splash.Parent = gui

HXCreateStarfield(splash, 10000, isMobile and 82 or 145, 2, 98, 3, 97)

splashBox = Instance.new("Frame")
splashBox.Size = UDim2.new(0,0,0,0)
splashBox.Position = UDim2.fromScale(0.5,0.5)
splashBox.AnchorPoint = Vector2.new(0.5,0.5)
splashBox.BackgroundColor3 = currentTheme.secondary
splashBox.BackgroundTransparency = 0.14
splashBox.BorderSizePixel = 0
splashBox.ClipsDescendants = true
splashBox.ZIndex = 10001
splashBox.Parent = splash
Instance.new("UICorner", splashBox).CornerRadius = UDim.new(0,18)

splashStroke = Instance.new("UIStroke")
splashStroke.Color = Color3.fromRGB(235,235,235)
splashStroke.Thickness = 1.2
splashStroke.Transparency = 0.16
splashStroke.Parent = splashBox

local splashLogo = Instance.new("ImageLabel")
splashLogo.Size = UDim2.new(0, isMobile and 42 or 48, 0, isMobile and 42 or 48)
splashLogo.Position = UDim2.new(0, 16, 0, 16)
splashLogo.BackgroundTransparency = 1
splashLogo.Image = "rbxassetid://72742584610344"
splashLogo.ImageColor3 = Color3.fromRGB(255,255,255)
splashLogo.ScaleType = Enum.ScaleType.Fit
splashLogo.ZIndex = 10003
splashLogo.Parent = splashBox

logo = Instance.new("TextLabel")
logo.Size = UDim2.new(1,-86,0,28)
logo.Position = UDim2.new(0,isMobile and 68 or 74,0,16)
logo.BackgroundTransparency = 1
logo.Text = "HX Emotes"
logo.TextColor3 = Color3.fromRGB(255,255,255)
logo.Font = Enum.Font.GothamBlack
logo.TextSize = isMobile and 16 or 20
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.TextYAlignment = Enum.TextYAlignment.Center
logo.ZIndex = 10003
logo.Parent = splashBox

local splashUniversal = Instance.new("TextLabel")
splashUniversal.Size = UDim2.new(1,-108,0,18)
splashUniversal.Position = UDim2.new(0,isMobile and 68 or 74,0,40)
splashUniversal.BackgroundTransparency = 1
splashUniversal.Text = "UNIVERSAL"
splashUniversal.TextColor3 = Color3.fromRGB(125,125,125)
splashUniversal.TextTransparency = 0.2
splashUniversal.Font = Enum.Font.GothamBold
splashUniversal.TextSize = isMobile and 8 or 9
splashUniversal.TextXAlignment = Enum.TextXAlignment.Left
splashUniversal.ZIndex = 10003
splashUniversal.Parent = splashBox

local splashTag = Instance.new("TextLabel")
splashTag.Size = UDim2.new(1,-40,0,20)
splashTag.Position = UDim2.new(0,16,0,68)
splashTag.BackgroundTransparency = 1
splashTag.Text = ""
splashTag.TextColor3 = Color3.fromRGB(125,125,125)
splashTag.Font = Enum.Font.GothamMedium
splashTag.TextSize = isMobile and 9 or 10
splashTag.TextXAlignment = Enum.TextXAlignment.Left
splashTag.ZIndex = 10003
splashTag.Parent = splashBox
splashTag.Visible = false

loadingLbl = Instance.new("TextLabel")
loadingLbl.Size = UDim2.new(1,-40,0,24)
loadingLbl.Position = UDim2.new(0,16,0,92)
loadingLbl.BackgroundTransparency = 1
loadingLbl.Text = isES and "CARGANDO BIBLIOTECA..." or "LOADING LIBRARY..."
loadingLbl.TextColor3 = Color3.fromRGB(205,205,205)
loadingLbl.Font = Enum.Font.GothamBold
loadingLbl.TextSize = isMobile and 11 or 12
loadingLbl.TextXAlignment = Enum.TextXAlignment.Left
loadingLbl.ZIndex = 10003
loadingLbl.Parent = splashBox

loadingBarBg = Instance.new("Frame")
loadingBarBg.Size = UDim2.new(1,-32,0,4)
loadingBarBg.Position = UDim2.new(0,16,0,118)
loadingBarBg.BackgroundColor3 = currentTheme.tertiary
loadingBarBg.BackgroundTransparency = 0.42
loadingBarBg.BorderSizePixel = 0
loadingBarBg.ZIndex = 10003
loadingBarBg.Parent = splashBox
Instance.new("UICorner", loadingBarBg).CornerRadius = UDim.new(0,4)
local loadBgStroke = Instance.new("UIStroke")
loadBgStroke.Color = Color3.fromRGB(65,65,65)
loadBgStroke.Thickness = 1
loadBgStroke.Parent = loadingBarBg

loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.new(0,0,1,0)
loadingBar.BackgroundColor3 = currentTheme.accent
loadingBar.BackgroundTransparency = 0.10
loadingBar.BorderSizePixel = 0
loadingBar.ZIndex = 10004
loadingBar.Parent = loadingBarBg
Instance.new("UICorner", loadingBar).CornerRadius = UDim.new(0,4)

loadingBarGrad = Instance.new("UIGradient")
loadingBarGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(155,155,155)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(205,205,205))
}
loadingBarGrad.Parent = loadingBar

local loadTicks = Instance.new("Frame")
loadTicks.Size = UDim2.new(1,-40,0,12)
loadTicks.Position = UDim2.new(0,16,0,126)
loadTicks.BackgroundTransparency = 1
loadTicks.ZIndex = 10003
loadTicks.Parent = splashBox
loadTicks.Visible = false
for i = 0, 7 do
    local tickMark = Instance.new("Frame")
    tickMark.Size = UDim2.new(0,1,0,math.max(3, 9 - (i % 2) * 3))
    tickMark.Position = UDim2.new(i/7,0,0,0)
    tickMark.BackgroundColor3 = Color3.fromRGB(85,85,85)
    tickMark.BorderSizePixel = 0
    tickMark.Parent = loadTicks
end

local loadingPercent = Instance.new("TextLabel")
loadingPercent.Name = "LoadPercent"
loadingPercent.Size = UDim2.new(1,-40,0,22)
loadingPercent.Position = UDim2.new(0,16,1,-32)
loadingPercent.BackgroundTransparency = 1
loadingPercent.Text = isES and "INICIALIZANDO" or "INITIALIZING"
loadingPercent.TextColor3 = Color3.fromRGB(105,105,105)
loadingPercent.Font = Enum.Font.GothamMedium
loadingPercent.TextSize = isMobile and 8 or 9
loadingPercent.TextXAlignment = Enum.TextXAlignment.Left
loadingPercent.ZIndex = 10003
loadingPercent.Parent = splashBox

discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0, isMobile and 104 or 118, 0, 28)
discordBtn.Position = UDim2.new(1, -(isMobile and 124 or 138), 1, -48)
discordBtn.BackgroundColor3 = currentTheme.tertiary
discordBtn.BackgroundTransparency = 0.38
discordBtn.Text = "DISCORD"
discordBtn.TextColor3 = Color3.fromRGB(205,205,205)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = isMobile and 9 or 10
discordBtn.AutoButtonColor = false
discordBtn.ZIndex = 10003
discordBtn.Parent = splashBox
discordBtn.Visible = false
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,5)
local discordStroke = Instance.new("UIStroke")
discordStroke.Color = Color3.fromRGB(65,65,65)
discordStroke.Thickness = 1
discordStroke.Parent = discordBtn

discordBtn.MouseEnter:Connect(function()
    TweenService:Create(discordBtn, TweenInfo.new(0.16), {BackgroundColor3 = Color3.fromRGB(28,28,28), TextColor3 = Color3.fromRGB(255,255,255)}):Play()
    TweenService:Create(discordStroke, TweenInfo.new(0.16), {Color = Color3.fromRGB(235,235,235)}):Play()
end)
discordBtn.MouseLeave:Connect(function()
    TweenService:Create(discordBtn, TweenInfo.new(0.16), {BackgroundColor3 = Color3.fromRGB(12,12,12), TextColor3 = Color3.fromRGB(205,205,205)}):Play()
    TweenService:Create(discordStroke, TweenInfo.new(0.16), {Color = Color3.fromRGB(65,65,65)}):Play()
end)
discordBtn.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard("https://discord.gg/sewRzHAG5J") end end)
    Notify(isES and "Copiado" or "Copied", L.discordCopied)
end)

local splashSize = isMobile and UDim2.new(0,296,0,164) or UDim2.new(0,372,0,178)
TweenService:Create(splashBox, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = splashSize}):Play()

end

TweenService:Create(loadingBar, TweenInfo.new(0.5), {Size = UDim2.new(0.3, 0, 1, 0)}):Play()
task.wait(0.3)

local function LoadEmotes()
	debugLog("LoadEmotes starting")
	local success, result = pcall(function()
		local response = game:HttpGet(("https://" .. string.char(118,101,120,114,111) .. "scripts.com.tr/emotes.json?t=") .. tick())
		return HttpService:JSONDecode(response)
	end)
	debugLog("LoadEmotes JSON loaded. success=" .. tostring(success) .. " resultType=" .. type(result))

	if success and result then
		local data = type(result) == "table" and (result.data or result)
		local _seenIds = {}
		for _, emote in ipairs(data) do
			if emote.id and emote.name then
				local numId = tonumber(emote.id)
				if numId and not _seenIds[numId] then
					_seenIds[numId] = true
					Emotes[#Emotes + 1] = {
						name          = tostring(emote.name),
						id            = numId,
						creatorName   = tostring(emote.creatorName      or ""),
						description   = tostring(emote.description      or ""),
						price         = emote.price,
						priceStatus   = tostring(emote.priceStatus      or ""),
						favoriteCount = emote.favoriteCount,
						createdUtc    = tostring(emote.itemCreatedUtc   or ""),
					}
				end
			end
		end
	end

	if #Emotes == 0 then
		Emotes = {
			{name = "Wave", id = 3576686446},
			{name = "Point", id = 3576823880},
			{name = "Dance", id = 3576720708},
			{name = "Laugh", id = 3576777185},
			{name = "Cheer", id = 3576738018}
		}
	end
	debugLog("LoadEmotes finished. Emotes count=" .. tostring(#Emotes))
end

AnimationPacks = {}
local function LoadAnimations()
	local success, result = pcall(function()
		local response = game:HttpGet(("https://" .. string.char(118,101,120,114,111) .. "scripts.com.tr/animations.json?t=") .. tick())
		return HttpService:JSONDecode(response)
	end)

	if success and result then
		local data = type(result) == "table" and (result.data or result)
		for _, pack in ipairs(data) do
			if pack.id and pack.name and pack.bundledItems then
				local function getAnimId(key)
					local arr = pack.bundledItems[key] or pack.bundledItems[tonumber(key)]
					if type(arr) == "table" and #arr > 0 then
						return tonumber(arr[1])
					elseif type(arr) == "number" then
						return arr
					end
					return nil
				end

				local climb = getAnimId("1")
				local fall = getAnimId("2")
				local walk = getAnimId("3")
				local swim = getAnimId("4")
				local idle = getAnimId("5")
				local run = getAnimId("6")
				local jump = getAnimId("7")

				if idle or walk then
					table.insert(AnimationPacks, {
						id = "anim_" .. tostring(pack.id),
						name = tostring(pack.name),
						isAnimationPack = true,
						Idle = idle,
						Walk = walk,
						Run = run,
						Jump = jump,
						Fall = fall,
						Climb = climb,
						Swim = swim
					})
				end
			end
		end
	end

	if #AnimationPacks == 0 then
		AnimationPacks = {
			{
				id = "anim_ninja",
				name = "Ninja Pack",
				isAnimationPack = true,
				Idle = 658832408,
				Walk = 658831143,
				Run = 658830056,
				Jump = 658832070,
				Fall = 658831500,
				Swim = 658832807,
				Climb = 658833139
			},
			{
				id = "anim_mage",
				name = "Mage Pack",
				isAnimationPack = true,
				Idle = 707742142,
				Walk = 707897309,
				Run = 707861613,
				Jump = 707853694,
				Fall = 707829716,
				Swim = 707876443,
				Climb = 707826056
			}
		}
	end
end


-- Roblox/UGC catalog is fetched on demand with the AFEM-style marketplace engine.
-- No full AvatarEditorService catalog preload is performed at startup.

local function EquipAnimationPack(pack)
	local char = player.Character
	if not char then return end
	local animate = char:FindFirstChild("Animate")
	if not animate then return end

	local ids = {
		pack.Idle,
		pack.Walk,
		pack.Run,
		pack.Jump,
		pack.Fall,
		pack.Climb,
		pack.Swim
	}

	local activeThreads = 0
	for _, catalogId in ipairs(ids) do
		if catalogId then
			activeThreads = activeThreads + 1
			task.spawn(function()
				local resolvedIds = {}
				local success, objs = pcall(function()
					return game:GetObjects("rbxassetid://" .. tostring(catalogId))
				end)

				local animName = nil
				if success and objs and #objs > 0 then
					local function scan(inst)
						if inst:IsA("Animation") then
							table.insert(resolvedIds, inst.AnimationId)
							local name = inst.Name:lower()
							if name:find("climb") then
								animName = "climb"
							elseif name:find("fall") then
								animName = "fall"
							elseif name:find("walk") then
								animName = "walk"
							elseif name:find("swim") then
								animName = "swim"
							elseif name:find("run") then
								animName = "run"
							elseif name:find("jump") then
								animName = "jump"
							elseif name:find("idle") or name:find("pose") or name:find("animation") then
								animName = "idle"
							end
						end
						for _, kid in ipairs(inst:GetChildren()) do
							scan(kid)
						end
					end
					for _, obj in ipairs(objs) do
						scan(obj)
					end
				end

				if #resolvedIds == 0 then
					table.insert(resolvedIds, "rbxassetid://" .. tostring(catalogId))
				end

				if animName then
					local val = animate:FindFirstChild(animName)
					if val then
						for _, child in ipairs(val:GetChildren()) do
							if child:IsA("Animation") then
								child:Destroy()
							end
						end
						for i, animId in ipairs(resolvedIds) do
							local anim = Instance.new("Animation")
							anim.Name = "Animation" .. i
							anim.AnimationId = animId
							anim.Parent = val
						end
					end
				end
				activeThreads = activeThreads - 1
			end)
		end
	end

	task.spawn(function()
		while activeThreads > 0 do
			task.wait(0.05)
		end
		pcall(function()
			animate.Enabled = false
			task.wait(0.05)
			animate.Enabled = true
		end)
	end)

	lastHXAnimationPack = pack
	Notify(isES and "Animación equipada" or "Animation equipped", LocalizeEmoteName(pack.name))
end

loadingLbl.Text = isES and "CARGANDO EMOTES..." or "LOADING EMOTES..."
TweenService:Create(loadingBar, TweenInfo.new(0.18), {Size = UDim2.new(0.34, 0, 1, 0)}):Play()
LoadEmotes()

loadingLbl.Text = isES and "CARGANDO ANIMACIONES..." or "LOADING ANIMATIONS..."
TweenService:Create(loadingBar, TweenInfo.new(0.18), {Size = UDim2.new(0.52, 0, 1, 0)}):Play()
LoadAnimations()

for _, emote in ipairs(Emotes) do
	EmotesById[emote.id] = emote
	emote._lname = emote.name:lower()
	emote._searchBlob = (tostring(emote.name or "") .. " " .. tostring(emote.creatorName or "") .. " " .. tostring(emote.description or "")):lower()
end

loadingLbl.Text = isES and "PREPARANDO ROBLOX UGC..." or "PREPARING ROBLOX UGC..."
TweenService:Create(loadingBar, TweenInfo.new(0.18), {Size = UDim2.new(0.72, 0, 1, 0)}):Play()
-- AFEM-style UGC results are requested only when the ROBLOX tab is opened/searched.
UGCEmotes = {}

TweenService:Create(loadingBar, TweenInfo.new(0.22), {Size = UDim2.new(1, 0, 1, 0)}):Play()
loadingLbl.Text = (isES and "BIBLIOTECAS LISTAS · %d EMOTES · ROBLOX ONLINE" or "LIBRARIES READY · %d EMOTES · ROBLOX ONLINE"):format(#Emotes)
task.wait(0.35)

do
	pcall(function() TweenService:Create(_bgMusic, TweenInfo.new(2), {Volume = 0}):Play() end)
	pcall(function() TweenService:Create(splash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play() end)
	pcall(function() TweenService:Create(splashBox, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), Rotation = 0}):Play() end)
	task.wait(0.5)
	pcall(function() splashBlur:Destroy() end)
	pcall(function() splash:Destroy() end)
	task.wait(1.5)
	pcall(function() _bgMusic:Destroy() end)
end

(function()
local MakeRow, MakeSectionHeader, MakePillToggle

local ICON_SCALE = 1.0
local BUTTON_SCALE = 1.0
local FONT_SCALE = 1.0


local EMOTE_ICON = "rbxassetid://120313093991132"
local currentData, filtered = Emotes, Emotes
local currentTab = "emotes"
local page, perPage, pages, cols = 1, 14, 1, 7
local cards = {}
local lastHXAnimationPack = nil
local _hxViewport = workspace.CurrentCamera.ViewportSize
local mobileWide = isMobile and _hxViewport.X >= 520 and _hxViewport.Y < 500
local previewStacked = isMobile and not mobileWide
local sideBarW = isMobile and ((_hxViewport.X < 420) and 104 or 112) or 148
local tabBtnS = isMobile and ((_hxViewport.Y < 430) and 34 or 42) or 40
local bottomBarH = 0
local previewPanelW = 0
local previewPanelH = 0
local currentCardSize = 0
local sortMode = "DEFAULT"
local Refresh
local _badEmotes = {}
local _refreshPending = false


local function IsFavorite(id)
	return FavoritesSet[tonumber(id)] == true
end

local MAX_FAVORITES = 25

local function ToggleFavorite(id)
	id = tonumber(id)
	if FavoritesSet[id] then
		FavoritesSet[id] = nil
		for i = #Favorites, 1, -1 do
			if Favorites[i] == id then
				table.remove(Favorites, i)
				break
			end
		end
		SaveData()
		return false
	end

	if #Favorites >= MAX_FAVORITES then
		Notify("Emotes", L.favLimit)
		return false
	end

	FavoritesSet[id] = true
	Favorites[#Favorites + 1] = id
	SaveData()
	return true
end

local function AddToRecent(id)
	id = tonumber(id)
	if not id then return end
	for i = #RecentEmotes, 1, -1 do
		if tonumber(RecentEmotes[i]) == id then table.remove(RecentEmotes, i) end
	end
	table.insert(RecentEmotes, 1, id)
	while #RecentEmotes > MAX_RECENT do table.remove(RecentEmotes) end
	SaveData()
	if currentTab == "recent" and UpdateTabData then UpdateTabData() end
end


local currentAnimTrack = nil
local lastEmoteTime = 0
local PlayEmote

local function HXEffectiveSpeed()
	local spd = math.max(0.05, tonumber(Settings.speed) or 1)
	return Settings.reversePlayback and -spd or spd
end

local function HXApplyTrackTuning(track)
	if not track then return end
	pcall(function() track.Looped = Settings.loopEmote end)
	pcall(function() track:AdjustWeight(math.clamp(tonumber(Settings.animationWeight) or 1, 0.2, 1), 0.08) end)
	pcall(function() track:AdjustSpeed(HXEffectiveSpeed()) end)
end

local function GetAnimator()
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function StopAllTracks()
	local animator = GetAnimator()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function()
				track:Stop(0.1)
			end)
		end
	end
	currentAnimTrack = nil
end

local function ApplySpeedToAllTracks()
	local animator = GetAnimator()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function() track:AdjustSpeed(HXEffectiveSpeed()) end)
		end
	end
end


local function StopEmote(showNotif)
	StopAllTracks()
	if showNotif then Notify(L.stopped, "", 113416463749658) end
	FriendData.currentSyncPartner = nil
	if _genv().HXBroadcastStop then pcall(_genv().HXBroadcastStop) end
end

local _lastPartnerSyncCheck = 0
local _heartbeatConn = RunService.Heartbeat:Connect(function()
	if Settings.stopOnWalk and currentAnimTrack and currentAnimTrack.IsPlaying then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0 and not FriendData.currentSyncPartner then
			StopEmote(false)
		end
	end

	if FriendData.currentSyncPartner and tick() - _lastPartnerSyncCheck >= 0.15 then
		_lastPartnerSyncCheck = tick()
		local partnerPlayer = Players:GetPlayerByUserId(tonumber(FriendData.currentSyncPartner))
		if not partnerPlayer then
			FriendData.currentSyncPartner = nil
			return
		end
		local partnerCharacter = partnerPlayer.Character
		local partnerHumanoid = partnerCharacter and partnerCharacter:FindFirstChildOfClass("Humanoid")
		local partnerAnimator = partnerHumanoid and partnerHumanoid:FindFirstChildOfClass("Animator")
		if partnerHumanoid and partnerHumanoid.MoveDirection.Magnitude > 0 then
			if currentAnimTrack and currentAnimTrack.IsPlaying then StopAllTracks() end
			return
		end
		if partnerAnimator then
			for _, pt in ipairs(partnerAnimator:GetPlayingAnimationTracks()) do
				if pt.IsPlaying and pt.Animation then
					local animId = tonumber(pt.Animation.AnimationId:match("%d+"))
					if animId and EmotesById[animId] then
						local lastId = _genv().lastHXEmote and tonumber(_genv().lastHXEmote.id) or nil
						if lastId ~= animId or not currentAnimTrack or not currentAnimTrack.IsPlaying then
							local spd = Settings.speed > 0 and Settings.speed or 1
							local calcStartTime = workspace:GetServerTimeNow() - (pt.TimePosition / spd)
							PlayEmote(animId, EmotesById[animId].name, true, calcStartTime)
						end
						break
					end
				end
			end
		end
	end
end)

local _animCache = {}

PlayEmote = function(id, name, silent, syncStartTime)
	local animator = GetAnimator()
	if not animator then return end

	StopAllTracks()

	_genv().lastHXEmote = {id = id, name = name}

	task.spawn(function()
		local anim = _animCache[id]

		if not anim then
			local successObj, objects = pcall(function()
				return game:GetObjects("rbxassetid://" .. id)
			end)

			if successObj and objects and #objects > 0 then
				local item = objects[1]
				if item:IsA("Animation") then
					anim = item
				else
					anim = item:FindFirstChildWhichIsA("Animation", true)
				end
			end

			if not anim then
				anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://" .. id
			end

			_animCache[id] = anim
		end

		if _genv().lastHXEmote and _genv().lastHXEmote.id == id then
			local success, err = pcall(function()
				local track = animator:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = Settings.loopEmote
				track:Play(0.1)

				if syncStartTime then
					task.spawn(function()
						local waitTime = 0
						while track.Length <= 0 and waitTime < 3 do
							waitTime = waitTime + task.wait()
						end

						if track.Length > 0 then
							local tNow = workspace:GetServerTimeNow()
							local offset = tNow - tonumber(syncStartTime)
							if offset > 0 then
								pcall(function()
									track.TimePosition = (offset * Settings.speed) % track.Length
								end)
							end
						end
					end)
				end

				task.delay(0.05, function()
					HXApplyTrackTuning(track)
				end)

				currentAnimTrack = track
				AddToRecent(id)
			end)

			if success then
				if not silent then
					local speedTxt = Settings.speed ~= 1 and " (" .. Settings.speed .. "x)" or ""
					Notify(L.playing .. speedTxt, LocalizeEmoteName(name), 129338178452237)
				end
				lastEmoteTime = tick()
				if _genv().HXBroadcastSync and FriendData.syncEmote and not silent then
					pcall(_genv().HXBroadcastSync, id, name, workspace:GetServerTimeNow())
				end
			else
				Notify("Error", L.emoteLoadFail)
			end
		end
	end)
end


local TARGET_PC_CARD = 112
local TARGET_MOBILE_CARD = 86

local function GetDefaultSize()
    local vp = workspace.CurrentCamera.ViewportSize
    local scale = math.clamp(tonumber(Settings.panelScale) or 1, 0.75, 1.35)
    local w, h
    if isMobile then
        w = math.clamp(math.floor(vp.X * 0.76), 260, 430)
        h = math.clamp(math.floor(vp.Y * 0.72), 280, 380)
    else
        w = math.clamp(math.floor(vp.X * 0.46), 540, 640)
        h = math.clamp(math.floor(vp.Y * 0.50), 340, 400)
    end
    w = math.clamp(math.floor(w * scale), isMobile and 235 or 430, math.floor(vp.X * 0.96))
    h = math.clamp(math.floor(h * scale), isMobile and 245 or 300, math.floor(vp.Y * 0.92))
    return UDim2.new(0,w,0,h)
end

main = Instance.new("Frame")
main.Name = "MainMenu"
main.Size = UDim2.new(0, 0, 0, 0)
main.Position = UDim2.fromScale(0.5, 0.5)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = currentTheme.primary
main.BackgroundTransparency = 0.10
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 24)
RegisterTheme(main, "BackgroundColor3", "primary")

local ThemeGradients = {
    Dark = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    Purple = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    Blue = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    Green = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    Red = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    Light = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    MaterialYou = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    FrostedGlass = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
    DarkGlass = {Color3.fromRGB(24,24,24), Color3.fromRGB(2,2,2), 135},
}

local HXAcrylic = {
    Start = function() end,
    Stop = function() end,
}

local _glassApplyBase = ApplyTheme
ApplyTheme = function(name)
	_glassApplyBase(name)
	local isGlass = name == "FrostedGlass" or name == "DarkGlass"
	if isGlass then
		HXAcrylic.Start(name)
	else
		HXAcrylic.Stop()
	end
	TweenService:Create(main, TweenInfo.new(0.3), {BackgroundTransparency = 0.10}):Play()
	local noiseOverlay = main:FindFirstChild("HXGlassNoise")
	if isGlass then
		if not noiseOverlay then
			noiseOverlay = Instance.new("ImageLabel")
			noiseOverlay.Name = "HXGlassNoise"
			noiseOverlay.Size = UDim2.new(1, 0, 1, 0)
			noiseOverlay.BackgroundTransparency = 1
			noiseOverlay.Image = "rbxassetid://9968344672"
			noiseOverlay.ScaleType = Enum.ScaleType.Tile
			noiseOverlay.TileSize = UDim2.new(0, 64, 0, 64)
			noiseOverlay.ZIndex = 1
			noiseOverlay.Parent = main
		end
		noiseOverlay.ImageTransparency = name == "FrostedGlass" and 0.82 or 0.88
	elseif noiseOverlay then
		noiseOverlay:Destroy()
	end
	local gradFrame = main:FindFirstChild("HXGradFrame")
	if not gradFrame then
		gradFrame = Instance.new("Frame")
		gradFrame.Name = "HXGradFrame"
		gradFrame.Size = UDim2.new(1, 0, 1, 0)
		gradFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		gradFrame.BackgroundTransparency = 0
		gradFrame.BorderSizePixel = 0
		gradFrame.ZIndex = 1
		gradFrame.Parent = main
		Instance.new("UICorner", gradFrame).CornerRadius = UDim.new(0, 24)
		local grad = Instance.new("UIGradient")
		grad.Name = "HXMainGrad"
		grad.Parent = gradFrame
	end
	TweenService:Create(gradFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.68}):Play()
	local grad = gradFrame:FindFirstChild("HXMainGrad")
	if grad then
		local g = ThemeGradients[name] or ThemeGradients.Dark
		grad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, g[1]),
			ColorSequenceKeypoint.new(1, g[2]),
		}
		grad.Rotation = g[3]
	end
end

mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255,255,255)
mainStroke.Thickness = 1.45
mainStroke.Transparency = 0.03
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pcall(function() mainStroke.LineJoinMode = Enum.LineJoinMode.Round end)
mainStroke.Parent = main

local mainInnerOutline = Instance.new("Frame")
mainInnerOutline.Name = "HXMainInnerOutline"
mainInnerOutline.Size = UDim2.new(1, -4, 1, -4)
mainInnerOutline.Position = UDim2.new(0, 2, 0, 2)
mainInnerOutline.BackgroundTransparency = 1
mainInnerOutline.BorderSizePixel = 0
mainInnerOutline.ZIndex = 500
mainInnerOutline.Active = false
mainInnerOutline.Parent = main
Instance.new("UICorner", mainInnerOutline).CornerRadius = UDim.new(0, 21)

local mainInnerStroke = Instance.new("UIStroke")
mainInnerStroke.Color = Color3.fromRGB(255,255,255)
mainInnerStroke.Thickness = 1.35
mainInnerStroke.Transparency = 1
mainInnerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pcall(function() mainInnerStroke.LineJoinMode = Enum.LineJoinMode.Round end)
mainInnerStroke.Parent = mainInnerOutline

mainStrokeGrad = Instance.new("UIGradient")
mainStrokeGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255))
mainStrokeGrad.Rotation = 0
mainStrokeGrad.Parent = mainInnerStroke

bgParticles = Instance.new("Frame")
bgParticles.Name = "HXSurfaceDetails"
bgParticles.Size = UDim2.new(1,-4,1,-4)
bgParticles.Position = UDim2.new(0,2,0,2)
bgParticles.BackgroundTransparency = 1
bgParticles.ClipsDescendants = true
bgParticles.ZIndex = 1
bgParticles.Parent = main
Instance.new("UICorner",bgParticles).CornerRadius = UDim.new(0,20)
bgParticles.Visible = true

pcall(function()
    local base = Instance.new("Frame")
    base.Size = UDim2.new(1,0,1,0)
    base.BackgroundColor3 = Color3.fromRGB(5,5,5)
    base.BackgroundTransparency = 0.02
    base.BorderSizePixel = 0
    base.ZIndex = 1
    base.Parent = bgParticles
    Instance.new("UICorner",base).CornerRadius = UDim.new(0,20)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(3,3,3)),
        ColorSequenceKeypoint.new(0.34,Color3.fromRGB(42,42,42)),
        ColorSequenceKeypoint.new(0.68,Color3.fromRGB(16,16,16)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(48,48,48))
    })
    grad.Rotation = 125
    grad.Offset = Vector2.new(-0.35,0)
    grad.Parent = base

    local safeInset = isMobile and 18 or 26
    local animMask = Instance.new("Frame")
    animMask.Name = "HXSurfaceMask"
    animMask.Size = UDim2.new(1,-(safeInset*2),1,-(safeInset*2))
    animMask.Position = UDim2.new(0,safeInset,0,safeInset)
    animMask.BackgroundTransparency = 1
    animMask.BorderSizePixel = 0
    animMask.ClipsDescendants = true
    animMask.ZIndex = 2
    animMask.Parent = bgParticles

    HXCreateStarfield(animMask, 3, isMobile and 58 or 96, 4, 96, 5, 95)

    task.spawn(function()
        local side = false
        while grad.Parent and bgParticles.Parent do
            side = not side
            local tw = TweenService:Create(grad,TweenInfo.new(5.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{
                Rotation=side and 155 or 115,
                Offset=side and Vector2.new(0.35,0.05) or Vector2.new(-0.35,-0.05)
            })
            tw:Play()
            tw.Completed:Wait()
        end
    end)
end)


do
sidebar = Instance.new("Frame")
sidebar.Name = "HXSidebar"
sidebar.Size = UDim2.new(0,sideBarW - 2,1,-4)
sidebar.Position = UDim2.new(0,2,0,2)
sidebar.BackgroundColor3 = currentTheme.sidebar
sidebar.BackgroundTransparency = 0.38
sidebar.BorderSizePixel = 0
sidebar.ClipsDescendants = true
sidebar.ZIndex = 8
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 20)

local navDivider = Instance.new("Frame")
navDivider.Size = UDim2.new(0,1,1,-16)
navDivider.Position = UDim2.new(1,-1,0,8)
navDivider.BackgroundColor3 = Color3.fromRGB(68,68,68)
navDivider.BorderSizePixel = 0
navDivider.ZIndex = 9
navDivider.Parent = sidebar
navDivider.Visible = false

local brand = Instance.new("Frame")
brand.Name = "HXBrand"
brand.Size = UDim2.new(1,-14,0,isMobile and 62 or 82)
brand.Position = UDim2.new(0,7,0,7)
brand.BackgroundColor3 = currentTheme.secondary
brand.BackgroundTransparency = 0.72
brand.BorderSizePixel = 0
brand.ZIndex = 10
brand.Parent = sidebar
Instance.new("UICorner",brand).CornerRadius = UDim.new(0,8)

local brandStroke = Instance.new("UIStroke")
brandStroke.Color = Color3.fromRGB(76,76,76)
brandStroke.Thickness = 1
brandStroke.Transparency = 1
brandStroke.Parent = brand

local brandLogo = Instance.new("ImageLabel")
local brandLogoS = isMobile and 52 or 68
brandLogo.Size = UDim2.new(0, brandLogoS, 0, brandLogoS)
brandLogo.Position = UDim2.new(0.5, 0, 0.5, isMobile and -5 or -6)
brandLogo.AnchorPoint = Vector2.new(0.5, 0.5)
brandLogo.BackgroundTransparency = 1
brandLogo.Image = "rbxassetid://80552458381492"
brandLogo.ImageColor3 = Color3.fromRGB(255,255,255)
brandLogo.ImageTransparency = 0
brandLogo.ScaleType = Enum.ScaleType.Fit
brandLogo.ZIndex = 11
brandLogo.Parent = brand

local brandAccent = Instance.new("Frame")
brandAccent.Size = UDim2.new(0,isMobile and 20 or 34,0,1)
brandAccent.Position = UDim2.new(1,-(isMobile and 27 or 42),1,-9)
brandAccent.BackgroundColor3 = Color3.fromRGB(255,255,255)
brandAccent.BackgroundTransparency = 1
brandAccent.BorderSizePixel = 0
brandAccent.ZIndex = 12
brandAccent.Parent = brand

tabStartY = isMobile and ((_hxViewport.Y < 430) and 62 or 72) or 88
tabBtns = {}
tabLabels = {
    emotes = "EMOTES",
    ugc = "ROBLOX",
    favorites = isES and "FAVORITOS" or "FAVORITES",
    keybinds = isES and "TECLAS" or "KEYBINDS",
    info = isES and "INFORMACIÓN" or "INFO",
    animations = isES and "ANIMACIONES" or "ANIMATIONS",
    tools = "TOOLS",
    recent = isES and "RECIENTES" or "RECENT",
    playlists = isES and "LISTAS" or "PLAYLISTS",
}

local function HXStyleRecentClock(holder, color, transparency)
    if not holder or not holder.Parent then return end
    color = color or Color3.fromRGB(190,190,190)
    transparency = transparency == nil and 0.12 or transparency
    local ring = holder:FindFirstChild("ClockRing")
    if ring then
        local rs = ring:FindFirstChild("ClockStroke")
        if rs then
            rs.Color = color
            rs.Transparency = transparency
        end
    end
    for _, name in ipairs({"ClockHourHand","ClockMinuteHand","ClockCenter"}) do
        local part = holder:FindFirstChild(name)
        if part and part:IsA("GuiObject") then
            part.BackgroundColor3 = color
            part.BackgroundTransparency = transparency
        end
    end
end

local function CreateTabBtn(icon,tabName,yPos)
    local btn = Instance.new("TextButton")
    btn.Name = "Nav_"..tabName
    btn.Size = UDim2.new(1,-14,0,tabBtnS)
    btn.Position = UDim2.new(0,7,0,yPos)
    btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 10
    btn.Parent = sidebar
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = btn
    HXApplyChamfer(btn, {transparent=true, cut=isMobile and 6 or 8})

    -- Slightly emphasize Favorites/Recent, while keeping Tools a little more compact.
    local navIconSize = isMobile and 19 or 22
    if tabName == "favorites" then
        navIconSize = isMobile and 24 or 28
    elseif tabName == "recent" then
        navIconSize = isMobile and 19 or 22
    elseif tabName == "tools" then
        navIconSize = isMobile and 17 or 19
    end

    local iconHolder
    if tabName == "recent" then
        -- Vector clock icon: no uploaded image, no unicode glyph and no backing panel.
        -- This renders consistently even on executors with incomplete fonts/assets.
        iconHolder = Instance.new("Frame")
        iconHolder.Name = "RecentClockIcon"
        iconHolder:SetAttribute("HXClockIcon", true)
        iconHolder.Size = UDim2.fromOffset(navIconSize, navIconSize)
        iconHolder.Position = UDim2.new(0,isMobile and 7 or 10,0.5,0)
        iconHolder.AnchorPoint = Vector2.new(0,0.5)
        iconHolder.BackgroundTransparency = 1
        iconHolder.BorderSizePixel = 0
        iconHolder.ZIndex = 13
        iconHolder.Parent = btn

        local ringSize = math.floor(navIconSize * 0.78)
        local ring = Instance.new("Frame")
        ring.Name = "ClockRing"
        ring.Size = UDim2.fromOffset(ringSize, ringSize)
        ring.Position = UDim2.fromScale(0.5,0.5)
        ring.AnchorPoint = Vector2.new(0.5,0.5)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.ZIndex = 14
        ring.Parent = iconHolder
        local ringCorner = Instance.new("UICorner")
        ringCorner.CornerRadius = UDim.new(1,0)
        ringCorner.Parent = ring
        local ringStroke = Instance.new("UIStroke")
        ringStroke.Name = "ClockStroke"
        ringStroke.Color = Color3.fromRGB(190,190,190)
        ringStroke.Thickness = isMobile and 1.25 or 1.45
        ringStroke.Transparency = 0.12
        ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        ringStroke.Parent = ring

        local hourHand = Instance.new("Frame")
        hourHand.Name = "ClockHourHand"
        hourHand.Size = UDim2.new(0,isMobile and 2 or 3,0,math.floor(ringSize*0.23))
        hourHand.Position = UDim2.fromScale(0.5,0.5)
        hourHand.AnchorPoint = Vector2.new(0.5,1)
        hourHand.Rotation = -48
        hourHand.BackgroundColor3 = Color3.fromRGB(190,190,190)
        hourHand.BackgroundTransparency = 0.12
        hourHand.BorderSizePixel = 0
        hourHand.ZIndex = 15
        hourHand.Parent = iconHolder
        Instance.new("UICorner",hourHand).CornerRadius = UDim.new(1,0)

        local minuteHand = Instance.new("Frame")
        minuteHand.Name = "ClockMinuteHand"
        minuteHand.Size = UDim2.new(0,isMobile and 2 or 3,0,math.floor(ringSize*0.31))
        minuteHand.Position = UDim2.fromScale(0.5,0.5)
        minuteHand.AnchorPoint = Vector2.new(0.5,1)
        minuteHand.Rotation = 18
        minuteHand.BackgroundColor3 = Color3.fromRGB(190,190,190)
        minuteHand.BackgroundTransparency = 0.12
        minuteHand.BorderSizePixel = 0
        minuteHand.ZIndex = 15
        minuteHand.Parent = iconHolder
        Instance.new("UICorner",minuteHand).CornerRadius = UDim.new(1,0)

        local centerDot = Instance.new("Frame")
        centerDot.Name = "ClockCenter"
        centerDot.Size = UDim2.fromOffset(isMobile and 4 or 5,isMobile and 4 or 5)
        centerDot.Position = UDim2.fromScale(0.5,0.5)
        centerDot.AnchorPoint = Vector2.new(0.5,0.5)
        centerDot.BackgroundColor3 = Color3.fromRGB(190,190,190)
        centerDot.BackgroundTransparency = 0.12
        centerDot.BorderSizePixel = 0
        centerDot.ZIndex = 16
        centerDot.Parent = iconHolder
        Instance.new("UICorner",centerDot).CornerRadius = UDim.new(1,0)
    else
        iconHolder = Instance.new("ImageLabel")
        iconHolder.Size = UDim2.fromOffset(navIconSize, navIconSize)
        iconHolder.Position = UDim2.new(0,isMobile and 8 or 12,0.5,0)
        iconHolder.AnchorPoint = Vector2.new(0,0.5)
        iconHolder.BackgroundTransparency = 1
        iconHolder.Image = ResolveAssetImage(icon)
        iconHolder.ImageColor3 = Color3.fromRGB(255,255,255)
        iconHolder.ImageTransparency = 0
        iconHolder.ScaleType = Enum.ScaleType.Fit
        iconHolder.ZIndex = 12
        iconHolder.Parent = btn
    end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-(isMobile and 38 or 50),1,-4)
    label.Position = UDim2.new(0,isMobile and 35 or 46,0,2)
    label.BackgroundTransparency = 1
    label.Text = tabLabels[tabName] or tabName:upper()
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = isMobile and ((_hxViewport.Y < 430) and 9 or 10) or 10
    label.TextScaled = isMobile
    if isMobile then
        local _navTextLimit = Instance.new("UITextSizeConstraint")
        _navTextLimit.MinTextSize = 8
        _navTextLimit.MaxTextSize = 10
        _navTextLimit.Parent = label
    end
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 12
    label.Parent = btn

    btn.MouseEnter:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(18,18,18),BackgroundTransparency=1}):Play()
            TweenService:Create(label,TweenInfo.new(0.15),{TextColor3=Color3.fromRGB(225,225,225)}):Play()
            if iconHolder:GetAttribute("HXClockIcon") then
                HXStyleRecentClock(iconHolder, Color3.fromRGB(255,255,255), 0)
            elseif iconHolder:IsA("TextLabel") then
                TweenService:Create(iconHolder,TweenInfo.new(0.15),{TextColor3=Color3.fromRGB(255,255,255),TextTransparency=0}):Play()
            else
                TweenService:Create(iconHolder,TweenInfo.new(0.15),{ImageColor3=Color3.fromRGB(255,255,255),ImageTransparency=0}):Play()
            end
            HXStyleChamfer(btn,{coreTransparency=0.38,glowTransparency=0.94,color=Color3.fromRGB(220,220,220)})
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1}):Play()
            TweenService:Create(label,TweenInfo.new(0.15),{TextColor3=Color3.fromRGB(170,170,170)}):Play()
            if iconHolder:GetAttribute("HXClockIcon") then
                HXStyleRecentClock(iconHolder, Color3.fromRGB(190,190,190), 0.12)
            elseif iconHolder:IsA("TextLabel") then
                TweenService:Create(iconHolder,TweenInfo.new(0.15),{TextColor3=Color3.fromRGB(255,255,255),TextTransparency=0}):Play()
            else
                TweenService:Create(iconHolder,TweenInfo.new(0.15),{ImageColor3=Color3.fromRGB(190,190,190),ImageTransparency=0.12}):Play()
            end
            HXStyleChamfer(btn,{coreTransparency=0.72,glowTransparency=1,color=Color3.fromRGB(180,180,180)})
        end
    end)

    tabBtns[tabName] = {btn=btn,stroke=stroke,img=iconHolder,label=label,yPos=yPos,primary=true}
    return btn
end

local navGap = isMobile and ((_hxViewport.Y < 430) and 3 or 5) or 5
CreateTabBtn(Icons.Emote,"emotes",tabStartY)
CreateTabBtn("rbxassetid://3576686446","ugc",tabStartY+(tabBtnS+navGap))
CreateTabBtn("rbxassetid://75528584354229","animations",tabStartY+(tabBtnS+navGap)*2)
CreateTabBtn(Icons.FavoriteFull,"favorites",tabStartY+(tabBtnS+navGap)*3)
CreateTabBtn("rbxassetid://9405931578","tools",tabStartY+(tabBtnS+navGap)*4)
CreateTabBtn(Icons.Recent,"recent",tabStartY+(tabBtnS+navGap)*5)

local profile = Instance.new("Frame")
profile.Name = "UserProfile"
profile.Size = UDim2.new(1,-18,0,isMobile and 40 or 48)
profile.Position = UDim2.new(0,9,1,-(isMobile and 47 or 55))
profile.BackgroundColor3 = currentTheme.secondary
profile.BackgroundTransparency = 0.48
profile.BorderSizePixel = 0
profile.ZIndex = 10
profile.Parent = sidebar
Instance.new("UICorner",profile).CornerRadius = UDim.new(0,8)
local profileStroke = Instance.new("UIStroke")
profileStroke.Color = Color3.fromRGB(58,58,58)
profileStroke.Thickness = 1
profileStroke.Transparency = 0.2
profileStroke.Parent = profile

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.new(0,isMobile and 26 or 32,0,isMobile and 26 or 32)
avatar.Position = UDim2.new(0,isMobile and 7 or 8,0.5,0)
avatar.AnchorPoint = Vector2.new(0,0.5)
avatar.BackgroundColor3 = currentTheme.secondary
avatar.BackgroundTransparency = 0.55
avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..tostring(player.UserId).."&w=150&h=150"
avatar.ScaleType = Enum.ScaleType.Crop
avatar.ZIndex = 11
avatar.Parent = profile
Instance.new("UICorner",avatar).CornerRadius = UDim.new(1,0)
local avatarStroke = Instance.new("UIStroke")
avatarStroke.Color = Color3.fromRGB(225,225,225)
avatarStroke.Thickness = 1
avatarStroke.Transparency = 0.28
avatarStroke.Parent = avatar

local userName = Instance.new("TextLabel")
userName.Size = UDim2.new(1,-(isMobile and 39 or 49),1,0)
userName.Position = UDim2.new(0,isMobile and 38 or 46,0,0)
userName.BackgroundTransparency = 1
userName.Text = player.DisplayName or player.Name
userName.TextColor3 = Color3.fromRGB(238,238,238)
userName.Font = Enum.Font.GothamBold
userName.TextSize = isMobile and 7 or 9
userName.TextXAlignment = Enum.TextXAlignment.Left
userName.TextTruncate = Enum.TextTruncate.AtEnd
userName.ZIndex = 11
userName.Parent = profile

local _tabIndicator = nil
local function _UpdateIndicatorGrad() end
end


content = Instance.new("Frame")
content.Size = UDim2.new(1, -sideBarW, 1, 0)
content.Position = UDim2.new(0, sideBarW, 0, 0)
content.BackgroundTransparency = 1
content.ZIndex = 2
content.ClipsDescendants = true
content.Parent = main

local titleH = isMobile and 34 or 36
titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, titleH)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 5
titleBar.Parent = content

local headerSurface = Instance.new("Frame")
headerSurface.Size = UDim2.new(1, -16, 0, titleH - 4)
headerSurface.Position = UDim2.new(0, 8, 0, 2)
headerSurface.BackgroundColor3 = currentTheme.secondary
headerSurface.BackgroundTransparency = 0.36
headerSurface.ZIndex = 4
headerSurface.Parent = titleBar
Instance.new("UICorner", headerSurface).CornerRadius = UDim.new(0, 11)
RegisterTheme(headerSurface, "BackgroundColor3", "secondary")

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = currentTheme.stroke
headerStroke.Thickness = 1
headerStroke.Transparency = 1
headerStroke.Parent = headerSurface
RegisterTheme(headerStroke, "Color", "stroke")

titleOverlay = headerSurface

local titleIconSz = isMobile and 28 or 32
local titleIcon = Instance.new("ImageLabel")
titleIcon.Size = UDim2.new(0, titleIconSz, 0, titleIconSz)
titleIcon.Position = UDim2.new(0, 18, 0.5, 0)
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = ResolveAssetImage(Icons.Emote)
titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
titleIcon.ZIndex = 6
titleIcon.Parent = titleBar
titleIcon.Visible = false
RegisterTheme(titleIcon, "ImageColor3", "text")

title = Instance.new("TextLabel")
title.Size = UDim2.new(1, isMobile and -88 or -110, 0, 24)
title.Position = UDim2.new(0, 18 + titleIconSz + 9, 0, isMobile and 8 or 7)
title.BackgroundTransparency = 1
title.Text = L.emotes
title.TextColor3 = currentTheme.text
title.Font = Enum.Font.GothamBold
title.TextSize = isMobile and 14 or 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6
title.Parent = titleBar
title.Visible = false
RegisterTheme(title, "TextColor3", "text")

local titleSubtitle = Instance.new("TextLabel")
titleSubtitle.Size = UDim2.new(1, isMobile and -88 or -110, 0, 16)
titleSubtitle.Position = UDim2.new(0, 18 + titleIconSz + 9, 0, isMobile and 27 or 29)
titleSubtitle.BackgroundTransparency = 1
titleSubtitle.Text = isES and "Biblioteca de animaciones" or "Animation library"
titleSubtitle.TextColor3 = currentTheme.textDim
titleSubtitle.Font = Enum.Font.Gotham
titleSubtitle.TextSize = isMobile and 9 or 10
titleSubtitle.TextXAlignment = Enum.TextXAlignment.Left
titleSubtitle.ZIndex = 6
titleSubtitle.Parent = titleBar
titleSubtitle.Visible = false
title.Visible = false
RegisterTheme(titleSubtitle, "TextColor3", "textDim")


local _textGrads = {}
local function _ApplyTextGrad(grad)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, currentTheme.text),
        ColorSequenceKeypoint.new(1, currentTheme.text)
    }
end
local function _AddTextGrad(textLabel)
    return nil
end
_updateTitleGrad = function() end

local btnS = isMobile and 30 or 32

local function MakeBtn(icon, px, colorKey, customSize, customCenterY)
	local s = customSize or btnS
	local centerY = customCenterY or (titleH / 2)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, s, 0, s)
	b.Position = UDim2.new(1, px, 0, centerY - s/2)
	b.BackgroundColor3 = currentTheme.tertiary
	b.BackgroundTransparency = 1
	b.Text = ""
	b.ZIndex = 10
	b.Parent = titleBar
	HXApplyChamfer(b, {transparent=true, cut=math.max(5, math.floor(s * 0.24))})

	local useWhite = true

	local isImg = type(icon) == "string" and (string.find(icon, "rbxassetid://") or string.find(icon, "http") or string.find(icon, "rbxthumb://"))
	if isImg then
		local img = Instance.new("ImageLabel")
		local imgSize = math.max(15, math.floor(s * 0.72))
		img.Size = UDim2.new(0, imgSize, 0, imgSize)
		img.Position = UDim2.new(0.5, 0, 0.5, 0)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.BackgroundTransparency = 1
		img.Parent = b
		img.Image = ResolveAssetImage(icon)
		img.ImageColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
		img.ZIndex = 110
		if not useWhite then
			RegisterTheme(img, "ImageColor3", "text")
		end
	else
		if icon == "STOP_SHAPE" then
			b.Text = ""
			local sq = Instance.new("ImageLabel")
			sq.Size = UDim2.new(0.75, 0, 0.75, 0)
			sq.Position = UDim2.new(0.5, 0, 0.5, 0)
			sq.AnchorPoint = Vector2.new(0.5, 0.5)
			sq.BackgroundTransparency = 1
			sq.Image = ResolveAssetImage("rbxassetid://113416463749658")
			sq.ImageColor3 = Color3.new(1, 1, 1)
			sq.ScaleType = Enum.ScaleType.Fit
			sq.ZIndex = 110
			sq.Parent = b
		elseif icon == "CLOSE_SHAPE" then
			b.Text = ""
			local line1 = Instance.new("Frame")
			line1.BorderSizePixel = 0
			line1.Size = UDim2.new(0.40, 0, 0, math.floor(2 * math.max(1, ICON_SCALE)))
			line1.Position = UDim2.new(0.5, 0, 0.5, 0)
			line1.AnchorPoint = Vector2.new(0.5, 0.5)
			line1.Rotation = 45
			line1.BackgroundColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
			line1.ZIndex = 110
			line1.Parent = b
			Instance.new("UICorner", line1).CornerRadius = UDim.new(0, 2)

			local line2 = line1:Clone()
			line2.Rotation = -45
			line2.Parent = b

			if not useWhite then
				RegisterTheme(line1, "BackgroundColor3", "text")
				RegisterTheme(line2, "BackgroundColor3", "text")
			end
		elseif icon == Icons.Minus or icon == "-" then
			b.Text = ""
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.Size = UDim2.new(0.40, 0, 0, math.floor(2 * math.max(1, ICON_SCALE)))
			line.Position = UDim2.new(0.5, 0, 0.5, 0)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
			line.ZIndex = 110
			line.Parent = b
			Instance.new("UICorner", line).CornerRadius = UDim.new(0, 2)
			if not useWhite then
				RegisterTheme(line, "BackgroundColor3", "text")
			end
		elseif icon == Icons.Sort then
			b.Text = icon
			b.TextSize = math.floor((isMobile and 32 or 46) * FONT_SCALE)
		else
			b.Text = icon
			b.TextSize = math.floor((isMobile and 12 or 16) * FONT_SCALE)
		end
		b.TextColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
		b.Font = Enum.Font.GothamBlack
		if not useWhite then
			RegisterTheme(b, "TextColor3", "text")
		end
	end

	b.MouseEnter:Connect(function()
		local s = customSize or btnS
		TweenService:Create(b, TweenInfo.new(0.1), {
			Size = UDim2.new(0, s + 4, 0, s + 4),
			Position = UDim2.new(1, px - 2, 0, centerY - (s + 4)/2)
		}):Play()
	end)
	b.MouseLeave:Connect(function()
		local s = customSize or btnS
		TweenService:Create(b, TweenInfo.new(0.1), {
			Size = UDim2.new(0, s, 0, s),
			Position = UDim2.new(1, px, 0, centerY - s/2)
		}):Play()
	end)
	return b
end

local utilS = isMobile and 22 or 24
local utilY = titleH - (isMobile and 16 or 17)
local topY = isMobile and 17 or 18
local copyEmoteBtn = MakeBtn("rbxassetid://77508802666652", -(utilS*4 + 16), "tertiary", utilS, utilY)
local stopBtn = MakeBtn("STOP_SHAPE", -(utilS*3 + 12), "tertiary", utilS, utilY)
local randBtn = MakeBtn(Icons.Sort, -(utilS*2 + 8), "tertiary", utilS, utilY)
local notifBtn = MakeBtn("rbxassetid://102189770974908", -(utilS + 4), "tertiary", utilS, utilY)
copyEmoteBtn.Visible = false
stopBtn.Visible = false
randBtn.Visible = false
notifBtn.Visible = false
local controlS = isMobile and 24 or 26
local controlGap = isMobile and 6 or 7
local controlRight = isMobile and 10 or 12
local controlY = titleH / 2

local function MakeWindowControl(name, kind, rightOffset)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(0, controlS, 0, controlS)
    b.Position = UDim2.new(1, -rightOffset, 0, controlY - controlS/2)
    b.AnchorPoint = Vector2.new(1, 0)
    b.BackgroundColor3 = Color3.fromRGB(15,15,15)
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0
    b.Text = ""
    b.AutoButtonColor = false
    b.ZIndex = 12
    b.Parent = titleBar
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Thickness = 0.9
    stroke.Transparency = 0.58
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pcall(function() stroke.LineJoinMode = Enum.LineJoinMode.Round end)
    stroke.Parent = b
    HXApplyChamfer(b, {transparent=true, cut=isMobile and 5 or 6, thickness=1.0, glowThickness=1, coreTransparency=0.24, glowTransparency=1, color=Color3.fromRGB(220,220,220)})

    if kind == "minus" then
        local line = Instance.new("Frame")
        line.Size = UDim2.new(0, math.floor(controlS * 0.42), 0, 2)
        line.Position = UDim2.fromScale(0.5, 0.5)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BackgroundColor3 = Color3.fromRGB(255,255,255)
        line.BorderSizePixel = 0
        line.ZIndex = 13
        line.Parent = b
        Instance.new("UICorner", line).CornerRadius = UDim.new(1,0)
    elseif kind == "square" then
        local sq = Instance.new("Frame")
        sq.Size = UDim2.new(0, math.floor(controlS * 0.42), 0, math.floor(controlS * 0.42))
        sq.Position = UDim2.fromScale(0.5, 0.5)
        sq.AnchorPoint = Vector2.new(0.5, 0.5)
        sq.BackgroundTransparency = 1
        sq.BorderSizePixel = 0
        sq.ZIndex = 13
        sq:SetAttribute("HXNoAutoCorner", true)
        sq.Parent = b
        local sqStroke = Instance.new("UIStroke")
        sqStroke.Color = Color3.fromRGB(255,255,255)
        sqStroke.Thickness = 1.0
        sqStroke.Transparency = 0.28
        sqStroke:SetAttribute("HXKeepStroke", true)
        sqStroke.Parent = sq
    else
        for _, rotation in ipairs({45, -45}) do
            local line = Instance.new("Frame")
            line.Size = UDim2.new(0, math.floor(controlS * 0.46), 0, 2)
            line.Position = UDim2.fromScale(0.5, 0.5)
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.Rotation = rotation
            line.BackgroundColor3 = Color3.fromRGB(255,255,255)
            line.BorderSizePixel = 0
            line.ZIndex = 13
            line:SetAttribute("HXNoAutoCorner", true)
            line.Parent = b
        end
    end

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(34,34,34),
            BackgroundTransparency = 1
        }):Play()
        HXStyleChamfer(b,{coreTransparency=0.10,glowTransparency=1,color=Color3.fromRGB(245,245,245)})
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(15,15,15),
            BackgroundTransparency = 1
        }):Play()
        HXStyleChamfer(b,{coreTransparency=0.24,glowTransparency=1,color=Color3.fromRGB(220,220,220)})
    end)

    return b
end

local closeBtn = MakeWindowControl("CloseButton", "close", controlRight)
local maxBtn = MakeWindowControl("MaximizeButton", "square", controlRight + controlS + controlGap)
local minBtn = MakeWindowControl("MinimizeButton", "minus", controlRight + (controlS + controlGap) * 2)

local discordW = isMobile and 76 or 92
local discordRight = controlRight + (controlS * 3) + (controlGap * 2) + (isMobile and 8 or 10)

local discordTopBtn = Instance.new("TextButton")
discordTopBtn.Name = "DiscordCopyButton"
discordTopBtn.Size = UDim2.new(0, discordW, 0, controlS)
discordTopBtn.Position = UDim2.new(1, -discordRight, 0, controlY - controlS/2)
discordTopBtn.AnchorPoint = Vector2.new(1, 0)
discordTopBtn.BackgroundColor3 = Color3.fromRGB(54,54,54)
discordTopBtn.BackgroundTransparency = 1
discordTopBtn.BorderSizePixel = 0
discordTopBtn.Text = "DISCORD"
discordTopBtn.TextColor3 = Color3.fromRGB(245,245,245)
discordTopBtn.TextTransparency = 0
discordTopBtn.TextStrokeTransparency = 1
discordTopBtn.Font = Enum.Font.GothamBold
discordTopBtn.TextSize = isMobile and 8 or 10
discordTopBtn.AutoButtonColor = false
discordTopBtn.ZIndex = 11
discordTopBtn.Parent = titleBar
HXApplyChamfer(discordTopBtn, {transparent=true, cut=isMobile and 6 or 8, coreTransparency=0.52, glowTransparency=0.97})

local universalTopW = isMobile and 58 or 72
local universalTopGap = isMobile and 18 or 26
local universalTop = Instance.new("TextLabel")
universalTop.Name = "UniversalHeaderLabel"
universalTop.Size = UDim2.new(0, universalTopW, 0, controlS)
universalTop.Position = UDim2.new(1, -(discordRight + discordW + universalTopGap), 0, controlY)
universalTop.AnchorPoint = Vector2.new(1, 0.5)
universalTop.BackgroundTransparency = 1
universalTop.Text = "UNIVERSAL"
universalTop.TextColor3 = Color3.fromRGB(235,235,235)
universalTop.TextTransparency = 0
universalTop.TextStrokeTransparency = 1
universalTop.Font = Enum.Font.GothamBold
universalTop.TextSize = isMobile and 8 or 10
universalTop.TextXAlignment = Enum.TextXAlignment.Center
universalTop.TextYAlignment = Enum.TextYAlignment.Center
universalTop.ZIndex = 11
universalTop.Parent = titleBar

discordTopBtn.MouseEnter:Connect(function()
    TweenService:Create(discordTopBtn,TweenInfo.new(0.12),{
        BackgroundColor3=Color3.fromRGB(70,70,70),
        TextColor3=Color3.fromRGB(255,255,255)
    }):Play()
end)
discordTopBtn.MouseLeave:Connect(function()
    TweenService:Create(discordTopBtn,TweenInfo.new(0.12),{
        BackgroundColor3=Color3.fromRGB(54,54,54),
        TextColor3=Color3.fromRGB(245,245,245)
    }):Play()
end)
discordTopBtn.MouseButton1Click:Connect(function()
    pcall(function() if setclipboard then setclipboard("https://discord.gg/sewRzHAG5J") end end)
    Notify(isES and "Copiado" or "Copied", L.discordCopied)
end)

local notifIcon = notifBtn:FindFirstChildWhichIsA("ImageLabel")
if notifIcon then
	notifIcon.Size = UDim2.new(0.65, 0, 0.65, 0)
	notifIcon.Position = UDim2.fromScale(0.5, 0.5)
	notifIcon.AnchorPoint = Vector2.new(0.5, 0.5)
end


if Settings.copyEmoteEnabled then
	RegisterTheme(copyEmoteBtn, "BackgroundColor3", "success")
else
	RegisterTheme(copyEmoteBtn, "BackgroundColor3", "tertiary")
end
RegisterTheme(stopBtn, "BackgroundColor3", "tertiary")
RegisterTheme(randBtn, "BackgroundColor3", "accent")
RegisterTheme(notifBtn, "BackgroundColor3", "tertiary")


local _isPaused = false
local _stopBtnSquare = stopBtn:FindFirstChildWhichIsA("ImageLabel")

local _pauseTextSize = math.floor((isMobile and 14 or 18) * (ICON_SCALE or 1))

local function _SetPauseState(paused)
	_isPaused = paused
	if _stopBtnSquare then
		_stopBtnSquare.Image = paused and ResolveAssetImage("rbxassetid://129338178452237") or ResolveAssetImage("rbxassetid://113416463749658")
	end
	if _hxBottomPauseBtn and _hxBottomPauseBtn.Parent then
		-- Keep BOTH the state icon and its label visible.
		-- Playing => [pause icon PAUSA/PAUSE], Paused => [play icon REANUDAR/RESUME].
		local bottomText = _hxBottomPauseBtn:FindFirstChild("PauseStateText")
		if bottomText and bottomText:IsA("TextLabel") then
			bottomText.Text = paused and (isES and "REANUDAR" or "RESUME") or (isES and "PAUSA" or "PAUSE")
		end
		local bottomIcon = _hxBottomPauseBtn:FindFirstChild("PauseStateIcon")
		if bottomIcon and bottomIcon:IsA("ImageLabel") then
			bottomIcon.Image = paused and ResolveAssetImage("rbxassetid://129338178452237") or ResolveAssetImage("rbxassetid://113416463749658")
		end
	end
	if _onPauseStateChanged then _onPauseStateChanged(paused) end
end

stopBtn.MouseButton1Click:Connect(function()
	if currentAnimTrack and _isPaused then
		pcall(function() currentAnimTrack:AdjustSpeed(HXEffectiveSpeed()) end)
		_SetPauseState(false)
	elseif currentAnimTrack and currentAnimTrack.IsPlaying then
		pcall(function() currentAnimTrack:AdjustSpeed(0) end)
		_SetPauseState(true)
	else
		StopEmote(true)
	end
end)
randBtn.MouseButton1Click:Connect(function()
	if #currentData > 0 then
		local r = currentData[math.random(#currentData)]
		local speedTxt = Settings.speed ~= 1 and " (" .. Settings.speed .. "x)" or ""
		Notify(L.playing .. speedTxt, LocalizeEmoteName(r.name), 129338178452237)
		if r.isUGC then
			task.spawn(function() PlayEmote(ResolveUGCAnimationId(r) or r.id, r.name, true) end)
		else
			PlayEmote(r.id, r.name, true)
		end
	end
end)

local searchH = isMobile and ((_hxViewport.Y < 500) and 30 or 32) or 38
search = Instance.new("TextBox")
search.Name = "EmoteSearch"
search.Size = UDim2.new(1,-24,0,searchH)
search.Position = UDim2.new(0,12,0,titleH+4)
search.BackgroundColor3 = currentTheme.secondary
search.BackgroundTransparency = 1
search.PlaceholderText = isES and "Buscar emote..." or "Search emote..."
search.PlaceholderColor3 = Color3.fromRGB(255,255,255)
search.Text = ""
search.TextColor3 = Color3.fromRGB(255,255,255)
search.TextStrokeTransparency = 1
search.TextSize = isMobile and 11 or 13
search.Font = Enum.Font.Gotham
search.ZIndex = 5
search.ClearTextOnFocus = false
search.Parent = content
local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0,35)
searchPadding.PaddingRight = UDim.new(0,8)
searchPadding.Parent = search
local searchStroke = Instance.new("UIStroke")
searchStroke.Color = Color3.fromRGB(235,235,235)
searchStroke.Thickness = 1.35
searchStroke.Transparency = 0.05
searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
searchStroke.Parent = search
HXApplyChamfer(search, {transparent=true, cut=isMobile and 7 or 9, thickness=1.0, glowThickness=2.4, coreTransparency=0.50, glowTransparency=0.96})

local magnifier = Instance.new("ImageLabel")
magnifier.Size = UDim2.new(0,isMobile and 18 or 21,0,isMobile and 18 or 21)
magnifier.Position = UDim2.new(0,8,0.5,0)
magnifier.AnchorPoint = Vector2.new(0,0.5)
magnifier.BackgroundTransparency = 1
magnifier.Image = ResolveAssetImage(Icons.Search)
magnifier.ImageColor3 = Color3.fromRGB(255,255,255)
magnifier.ScaleType = Enum.ScaleType.Fit
magnifier.ZIndex = 6
magnifier.Parent = search

local function ApplyCurrentSort(list)
    -- DEFAULT is by far the common path: return the already-built list instead of copying it again.
    if sortMode ~= "A-Z" and sortMode ~= "Z-A" then return list or {} end
    local out = {}
    for i,v in ipairs(list or {}) do out[i]=v end
    if sortMode == "A-Z" then
        table.sort(out,function(a,b) return LocalizeEmoteName(a.name):lower() < LocalizeEmoteName(b.name):lower() end)
    else
        table.sort(out,function(a,b) return LocalizeEmoteName(a.name):lower() > LocalizeEmoteName(b.name):lower() end)
    end
    return out
end

local function BuildFilteredForSearch(query, source)
    local q = tostring(query or ""):lower()
    source = source or currentData or {}
    if q == "" then return ApplyCurrentSort(source) end

    local out = {}
    for i = 1, #source do
        local e = source[i]
        if e and not _badEmotes[tostring(e.id)] then
            local blob = e._searchBlob
            if not blob then
                blob = (tostring(e.name or "") .. " " .. tostring(e.creatorName or "") .. " " .. tostring(e.description or "")):lower()
                e._searchBlob = blob
            end
            if blob:find(q, 1, true) then out[#out + 1] = e end
        end
        -- Much larger chunks: yielding every 48 entries made obfuscated builds painfully slow.
        if i % 800 == 0 then task.wait() end
    end
    return ApplyCurrentSort(out)
end

trendingDropdown = Instance.new("Frame")
trendingDropdown.Name = "HXTrendingDropdown"
trendingDropdown.Size = UDim2.new(1, -16, 0, 0)
trendingDropdown.Position = UDim2.new(0, 8, 0, titleH + 4 + searchH + 2)
trendingDropdown.BackgroundColor3 = currentTheme.secondary
trendingDropdown.ZIndex = 250
trendingDropdown.Visible = false
trendingDropdown.ClipsDescendants = true
trendingDropdown.Parent = content
Instance.new("UICorner", trendingDropdown).CornerRadius = UDim.new(0, 8)
local dropdownStroke = Instance.new("UIStroke")
dropdownStroke.Color = currentTheme.accent
dropdownStroke.Thickness = 1.5
dropdownStroke.Transparency = 0.4
dropdownStroke.Parent = trendingDropdown
RegisterTheme(trendingDropdown, "BackgroundColor3", "secondary")
RegisterTheme(dropdownStroke, "Color", "accent")

local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
dropdownLayout.Padding = UDim.new(0, 2)
dropdownLayout.Parent = trendingDropdown

local _cachedTrending = {}
local _lastRecordedQuery = ""
local _lastRecordedAt = 0

local function canShowTrendingDropdown()
    return false
end

local function hideTrendingDropdown()
	if not trendingDropdown then return end
	trendingDropdown.Visible = false
	trendingDropdown.Size = UDim2.new(1, -16, 0, 0)
	for _, child in ipairs(trendingDropdown:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function populateTrendingDropdown(trendingItems)
	if not canShowTrendingDropdown() then
		hideTrendingDropdown()
		return
	end

	for _, child in ipairs(trendingDropdown:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	if not trendingItems or #trendingItems == 0 then
		trendingItems = _cachedTrending
	else
		_cachedTrending = trendingItems
	end

	local itemH = 30
	trendingDropdown.Size = UDim2.new(1, -16, 0, #trendingItems * (itemH + 2) + 4)

	for _, query in ipairs(trendingItems) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -8, 0, itemH)
		btn.Position = UDim2.new(0, 4, 0, 0)
		btn.BackgroundColor3 = currentTheme.tertiary
		btn.BackgroundTransparency = 1
		btn.Text = "        " .. query
		btn.TextColor3 = currentTheme.text
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 13
		btn.ZIndex = 251
		btn.Parent = trendingDropdown
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		RegisterTheme(btn, "TextColor3", "text")

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 16, 0, 16)
		icon.Position = UDim2.new(0, 8, 0.5, -8)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxthumb://type=Asset&id=129818530869054&w=150&h=150"
		icon.ImageColor3 = Color3.fromRGB(255,255,255)
		icon.ZIndex = 252
		icon.Parent = btn
		RegisterTheme(icon, "ImageColor3", "text")

		btn.MouseEnter:Connect(function()
			btn.BackgroundTransparency = 0.5
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundTransparency = 1
		end)

		btn.MouseButton1Click:Connect(function()
			search.Text = query
			trendingDropdown.Visible = false
		end)
	end
end

local function refreshTrendingDropdown()
	if not canShowTrendingDropdown() then
		hideTrendingDropdown()
		return
	end
	populateTrendingDropdown(_cachedTrending)
end

local function recordSearchQuery(raw)
	return
end

search.Focused:Connect(function()
    TweenService:Create(search, TweenInfo.new(0.14), {
        BackgroundTransparency = 0.10,
        BackgroundColor3 = Color3.fromRGB(18,18,18)
    }):Play()
    TweenService:Create(searchStroke, TweenInfo.new(0.14), {
        Thickness = 1.8,
        Transparency = 0
    }):Play()
	if not canShowTrendingDropdown() then return end
	if not search.Visible then return end
	trendingDropdown.Visible = true
	task.spawn(refreshTrendingDropdown)
end)

search.FocusLost:Connect(function(enterPressed)
    TweenService:Create(search, TweenInfo.new(0.14), {
        BackgroundTransparency = 0.24,
        BackgroundColor3 = currentTheme.secondary
    }):Play()
    TweenService:Create(searchStroke, TweenInfo.new(0.14), {
        Thickness = 1.35,
        Transparency = 0.05
    }):Play()
	task.delay(0.18, function()
		if trendingDropdown and not search:IsFocused() then
			hideTrendingDropdown()
		end
	end)
end)

local pageH = isMobile and ((_hxViewport.Y < 500) and 30 or 34) or 42
pageBar = Instance.new("Frame")
pageBar.Size = UDim2.new(1,-24,0,pageH)
pageBar.Position = UDim2.new(0, 12, 1, -(pageH + 10))
pageBar.BackgroundColor3 = currentTheme.secondary
pageBar.BackgroundTransparency = 0.28
pageBar.ZIndex = 5
pageBar.Parent = content
Instance.new("UICorner", pageBar).CornerRadius = UDim.new(0, 11)
RegisterTheme(pageBar, "BackgroundColor3", "secondary")

-- Compact page controls: <  1/N  >  [icon PAUSA/REANUDAR]
-- Keep previous/next close to the page number instead of pinning them to opposite edges.
local pageBtnW = isMobile and 36 or 44
local pageNumW = isMobile and 66 or 80
local pauseBtnW = isMobile and 108 or 136
local pageGap = isMobile and 6 or 8
local pauseGap = isMobile and 14 or 18
local compactControlsW = pageBtnW + pageGap + pageNumW + pageGap + pageBtnW + pauseGap + pauseBtnW
local compactStartX = -math.floor(compactControlsW / 2)

prevBtn = Instance.new("TextButton")
prevBtn.Size = UDim2.new(0, pageBtnW, 1, -4)
prevBtn.Position = UDim2.new(0.5, compactStartX, 0, 2)
prevBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
prevBtn.BackgroundTransparency = 1
prevBtn.Text = ""
prevBtn.AutoButtonColor = false
prevBtn.ZIndex = 6
prevBtn.Parent = pageBar
local prevStroke = Instance.new("UIStroke")
prevStroke.Color = Color3.fromRGB(220,220,220)
prevStroke.Thickness = 1
prevStroke.Transparency = 0.72
prevStroke.Parent = prevBtn
HXApplyChamfer(prevBtn, {transparent=true, cut=isMobile and 5 or 7, coreTransparency=0.50, glowTransparency=0.97})

local function CreateChevron(parent, isNext)
	local container = Instance.new("Frame")
	container.Name = "ChevronIcon"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 7
	container.Parent = parent

	local effScale = math.min(ICON_SCALE, 1.4)
	local len = math.floor(14 * effScale)
	local thick = math.floor(1.6 * math.max(1, effScale))
	local offset = math.floor(len * 0.353)

	local tipX = isNext and offset or -offset
	local dx = isNext and -offset or offset

	local topL = Instance.new("Frame")
	topL.BorderSizePixel = 0
	topL.Size = UDim2.new(0, len, 0, thick)
	topL.AnchorPoint = Vector2.new(0.5, 0.5)
	topL.Position = UDim2.new(0.5, tipX + dx, 0.5, -offset)
	topL.Rotation = isNext and 45 or -45
	topL.BackgroundColor3 = Color3.new(1, 1, 1)
	topL.ZIndex = 7
	topL.Parent = container
	Instance.new("UICorner", topL).CornerRadius = UDim.new(0, 2)

	local botL = Instance.new("Frame")
	botL.BorderSizePixel = 0
	botL.Size = UDim2.new(0, len, 0, thick)
	botL.AnchorPoint = Vector2.new(0.5, 0.5)
	botL.Position = UDim2.new(0.5, tipX + dx, 0.5, offset)
	botL.Rotation = isNext and -45 or 45
	botL.BackgroundColor3 = Color3.new(1, 1, 1)
	botL.ZIndex = 7
	botL.Parent = container
	Instance.new("UICorner", botL).CornerRadius = UDim.new(0, 2)
end

local nextBtn = prevBtn:Clone()
nextBtn.Position = UDim2.new(0.5, compactStartX + pageBtnW + pageGap + pageNumW + pageGap, 0, 2)
nextBtn.Parent = pageBar
HXApplyChamfer(nextBtn, {transparent=true, cut=isMobile and 5 or 7, coreTransparency=0.50, glowTransparency=0.97})

CreateChevron(prevBtn, false)
CreateChevron(nextBtn, true)

local function StylePageButtonHover(btn)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(232,232,232),BackgroundTransparency=1}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=1}):Play()
    end)
end
StylePageButtonHover(prevBtn)
StylePageButtonHover(nextBtn)

pageNum = Instance.new("TextLabel")
pageNum.Size = UDim2.new(0, pageNumW, 1, 0)
pageNum.Position = UDim2.new(0.5, compactStartX + pageBtnW + pageGap, 0, 0)
pageNum.BackgroundTransparency = 1
pageNum.Text = "1/1"
pageNum.TextColor3 = currentTheme.textDim
pageNum.Font = Enum.Font.GothamBold
pageNum.TextScaled = true
pageNum.ZIndex = 6
pageNum.Parent = pageBar
local pageNumLimit = Instance.new("UITextSizeConstraint")
pageNumLimit.MinTextSize = isMobile and 11 or 12
pageNumLimit.MaxTextSize = isMobile and 14 or 17
pageNumLimit.Parent = pageNum
RegisterTheme(pageNum, "TextColor3", "textDim")

_hxBottomPauseBtn = Instance.new("TextButton")
_hxBottomPauseBtn.Name = "BottomPauseButton"
_hxBottomPauseBtn.Size = UDim2.new(0, pauseBtnW, 1, -4)
_hxBottomPauseBtn.Position = UDim2.new(0.5, compactStartX + pageBtnW + pageGap + pageNumW + pageGap + pageBtnW + pauseGap, 0, 2)
_hxBottomPauseBtn.BackgroundColor3 = Color3.fromRGB(54,54,54)
_hxBottomPauseBtn.BackgroundTransparency = 1
_hxBottomPauseBtn.BorderSizePixel = 0
_hxBottomPauseBtn.Text = ""
_hxBottomPauseBtn.AutoButtonColor = false
_hxBottomPauseBtn.ZIndex = 6
_hxBottomPauseBtn.Parent = pageBar
HXApplyChamfer(_hxBottomPauseBtn, {transparent=true, cut=isMobile and 5 or 7, coreTransparency=0.44, glowTransparency=0.96})

local _hxBottomPauseIcon = Instance.new("ImageLabel")
_hxBottomPauseIcon.Name = "PauseStateIcon"
_hxBottomPauseIcon.Size = UDim2.fromOffset(isMobile and 18 or 21, isMobile and 18 or 21)
_hxBottomPauseIcon.Position = UDim2.new(0, isMobile and 12 or 15, 0.5, 0)
_hxBottomPauseIcon.AnchorPoint = Vector2.new(0, 0.5)
_hxBottomPauseIcon.BackgroundTransparency = 1
-- While an emote is playing, show PAUSE. When paused, show PLAY/RESUME.
_hxBottomPauseIcon.Image = ResolveAssetImage("rbxassetid://113416463749658")
_hxBottomPauseIcon.ImageColor3 = Color3.fromRGB(255,255,255)
_hxBottomPauseIcon.ScaleType = Enum.ScaleType.Fit
_hxBottomPauseIcon.ZIndex = 8
_hxBottomPauseIcon.Parent = _hxBottomPauseBtn

local _hxBottomPauseText = Instance.new("TextLabel")
_hxBottomPauseText.Name = "PauseStateText"
_hxBottomPauseText.Size = UDim2.new(1, -(isMobile and 40 or 48), 1, 0)
_hxBottomPauseText.Position = UDim2.new(0, isMobile and 36 or 43, 0, 0)
_hxBottomPauseText.BackgroundTransparency = 1
_hxBottomPauseText.Text = isES and "PAUSA" or "PAUSE"
_hxBottomPauseText.TextColor3 = Color3.fromRGB(255,255,255)
_hxBottomPauseText.Font = Enum.Font.GothamBold
_hxBottomPauseText.TextSize = isMobile and 11 or 13
_hxBottomPauseText.TextStrokeTransparency = 1
_hxBottomPauseText.TextXAlignment = Enum.TextXAlignment.Center
_hxBottomPauseText.TextYAlignment = Enum.TextYAlignment.Center
_hxBottomPauseText.ZIndex = 8
_hxBottomPauseText.Parent = _hxBottomPauseBtn

_hxBottomPauseBtn.MouseEnter:Connect(function()
	TweenService:Create(_hxBottomPauseBtn, TweenInfo.new(0.14), {BackgroundColor3 = Color3.fromRGB(70,70,70)}):Play()
end)
_hxBottomPauseBtn.MouseLeave:Connect(function()
	TweenService:Create(_hxBottomPauseBtn, TweenInfo.new(0.14), {BackgroundColor3 = Color3.fromRGB(54,54,54)}):Play()
end)
_hxBottomPauseBtn.MouseButton1Click:Connect(function()
	if currentAnimTrack and _isPaused then
		pcall(function() currentAnimTrack:AdjustSpeed(HXEffectiveSpeed()) end)
		_SetPauseState(false)
	elseif currentAnimTrack and currentAnimTrack.IsPlaying then
		pcall(function() currentAnimTrack:AdjustSpeed(0) end)
		_SetPauseState(true)
	end
end)

MockPlaylists = Playlists

emptyLbl = Instance.new("TextLabel")
emptyLbl.Size = UDim2.new(1, -20, 0, 50)
emptyLbl.Position = UDim2.fromScale(0.5, 0.45)
emptyLbl.AnchorPoint = Vector2.new(0.5, 0.5)
emptyLbl.BackgroundTransparency = 1
emptyLbl.Text = ""
emptyLbl.TextColor3 = currentTheme.textDim
emptyLbl.Font = Enum.Font.GothamBold
emptyLbl.TextScaled = true
emptyLbl.Visible = false
emptyLbl.ZIndex = 5
emptyLbl.Parent = content
RegisterTheme(emptyLbl, "TextColor3", "textDim")


settingsPanel = Instance.new("ScrollingFrame")
settingsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 28))
settingsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
settingsPanel.BackgroundTransparency = 1
settingsPanel.ScrollBarThickness = isMobile and 6 or 4
settingsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
settingsPanel.Visible = false
settingsPanel.ZIndex = 5
settingsPanel.Parent = content

settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0, 7)
settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Parent = settingsPanel

friendsPanel = Instance.new("ScrollingFrame")
friendsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 28))
friendsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
friendsPanel.BackgroundTransparency = 1
friendsPanel.ScrollBarThickness = isMobile and 6 or 4
friendsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y

playlistsPanel = Instance.new("ScrollingFrame")
playlistsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 28))
playlistsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
playlistsPanel.BackgroundTransparency = 1
playlistsPanel.ScrollBarThickness = isMobile and 6 or 4
playlistsPanel.AutomaticCanvasSize = Enum.AutomaticSize.None
playlistsPanel.CanvasSize = UDim2.new(0,0,0,0)
playlistsPanel.Visible = false
playlistsPanel.ZIndex = 5
playlistsPanel.ZIndex = 5
playlistsPanel.Parent = content

playlistsLayout = Instance.new("UIListLayout")
playlistsLayout.SortOrder = Enum.SortOrder.LayoutOrder
playlistsLayout.Padding = UDim.new(0, 6)
playlistsLayout.Parent = playlistsPanel

playlistTopBar = Instance.new("Frame")
playlistTopBar.Size = UDim2.new(1, 0, 0, 40)
playlistTopBar.BackgroundTransparency = 1
playlistTopBar.LayoutOrder = -1
playlistTopBar.ZIndex = 6
playlistTopBar.Parent = playlistsPanel

playlistSearchBox = Instance.new("Frame")
playlistSearchBox.Size = UDim2.new(1, -50, 1, 0)
playlistSearchBox.BackgroundColor3 = currentTheme.secondary
playlistSearchBox.ZIndex = 7
playlistSearchBox.Parent = playlistTopBar
Instance.new("UICorner", playlistSearchBox).CornerRadius = UDim.new(0, 10)
RegisterTheme(playlistSearchBox, "BackgroundColor3", "secondary")

playlistListSearch = Instance.new("TextBox")
playlistListSearch.Size = UDim2.new(1, -20, 1, 0)
playlistListSearch.Position = UDim2.new(0, 10, 0, 0)
playlistListSearch.BackgroundTransparency = 1
playlistListSearch.Text = ""
playlistListSearch.PlaceholderText = L.searchPlaylists
playlistListSearch.TextColor3 = currentTheme.text
playlistListSearch.PlaceholderColor3 = currentTheme.text
playlistListSearch.Font = Enum.Font.Gotham
playlistListSearch.TextSize = 14
playlistListSearch.TextXAlignment = Enum.TextXAlignment.Left
playlistListSearch.ZIndex = 8
playlistListSearch.Parent = playlistSearchBox
RegisterTheme(playlistListSearch, "TextColor3", "text")
RegisterTheme(playlistListSearch, "PlaceholderColor3", "text")
playlistListSearch:GetPropertyChangedSignal("Text"):Connect(function()
	if RefreshPlaylistsList then RefreshPlaylistsList() end
end)

playlistAddBtn = Instance.new("TextButton")
playlistAddBtn.Size = UDim2.new(0, 40, 0, 40)
playlistAddBtn.Position = UDim2.new(1, -40, 0, 0)
playlistAddBtn.BackgroundColor3 = currentTheme.accent
playlistAddBtn.Text = "+"
playlistAddBtn.TextColor3 = Color3.new(1,1,1)
playlistAddBtn.Font = Enum.Font.GothamBold
playlistAddBtn.TextSize = 24
playlistAddBtn.ZIndex = 7
playlistAddBtn.Parent = playlistTopBar
Instance.new("UICorner", playlistAddBtn).CornerRadius = UDim.new(0, 10)
RegisterTheme(playlistAddBtn, "BackgroundColor3", "accent")

playlistAddBtn.MouseButton1Click:Connect(function()
	_isPlaylistMode = true
	_selectedEmotesForPlaylist = {}
	currentTab = "emotes"
	search.Text = ""
	UpdateTabData()
end)

friendsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
friendsPanel.Visible = false
friendsPanel.ZIndex = 5
friendsPanel.Parent = content
friendsPanelLayout = Instance.new("UIListLayout")
	friendsPanelLayout.Padding = UDim.new(0, 10)
	friendsPanelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	friendsPanelLayout.Parent = friendsPanel

keybindsPanel = Instance.new("ScrollingFrame")
keybindsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 28))
keybindsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
keybindsPanel.BackgroundTransparency = 1
keybindsPanel.ScrollBarThickness = isMobile and 6 or 4
keybindsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
keybindsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
keybindsPanel.Visible = false
keybindsPanel.ZIndex = 5
keybindsPanel.Parent = content
keybindsPanelLayout = Instance.new("UIListLayout")
keybindsPanelLayout.Padding = UDim.new(0, 8)
keybindsPanelLayout.Parent = keybindsPanel

local RefreshKeybindsPanel


do
aboutPanel = Instance.new("ScrollingFrame")
aboutPanel.Name = "UniversalInfo"
aboutPanel.Size = UDim2.new(1,-20,1,-(titleH+bottomBarH+24))
aboutPanel.Position = UDim2.new(0,10,0,titleH+10)
aboutPanel.BackgroundTransparency = 1
aboutPanel.BorderSizePixel = 0
aboutPanel.ScrollBarThickness = 3
aboutPanel.ScrollBarImageColor3 = Color3.fromRGB(150,150,150)
aboutPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
aboutPanel.CanvasSize = UDim2.new(0,0,0,0)
aboutPanel.Visible = false
aboutPanel.ZIndex = 6
aboutPanel.Parent = content
local aboutLayout = Instance.new("UIListLayout")
aboutLayout.Padding = UDim.new(0,8)
aboutLayout.SortOrder = Enum.SortOrder.LayoutOrder
aboutLayout.Parent = aboutPanel

local function MakeInfoBlock(labelText, valueText, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-4,0,isMobile and 58 or 64)
    row.BackgroundColor3 = currentTheme.secondary
    row.BackgroundTransparency = 0.42
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = aboutPanel
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(55,55,55)
    st.Thickness = 1
    st.Parent = row
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-20,0,18)
    label.Position = UDim2.new(0,10,0,9)
    label.BackgroundTransparency = 1
    label.Text = labelText:upper()
    label.TextColor3 = Color3.fromRGB(120,120,120)
    label.Font = Enum.Font.GothamBold
    label.TextSize = isMobile and 8 or 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(1,-20,0,25)
    value.Position = UDim2.new(0,10,0,27)
    value.BackgroundTransparency = 1
    value.Text = tostring(valueText)
    value.TextColor3 = Color3.fromRGB(245,245,245)
    value.Font = Enum.Font.GothamBlack
    value.TextSize = isMobile and 12 or 14
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.TextWrapped = true
    value.Parent = row
    return value
end

local infoHero = Instance.new("Frame")
infoHero.Size = UDim2.new(1,-4,0,isMobile and 90 or 106)
infoHero.BackgroundColor3 = currentTheme.secondary
infoHero.BackgroundTransparency = 0.38
infoHero.BorderSizePixel = 0
infoHero.LayoutOrder = 0
infoHero.Parent = aboutPanel
Instance.new("UICorner",infoHero).CornerRadius = UDim.new(0,7)
local infoHeroStroke = Instance.new("UIStroke")
infoHeroStroke.Color = Color3.fromRGB(225,225,225)
infoHeroStroke.Thickness = 1
infoHeroStroke.Parent = infoHero
local heroRail = Instance.new("Frame")
heroRail.Size = UDim2.new(0,5,1,-22)
heroRail.Position = UDim2.new(0,12,0,11)
heroRail.BackgroundColor3 = Color3.fromRGB(255,255,255)
heroRail.BorderSizePixel = 0
heroRail.Parent = infoHero
local heroText = Instance.new("TextLabel")
heroText.Size = UDim2.new(1,-45,1,-18)
heroText.Position = UDim2.new(0,30,0,9)
heroText.BackgroundTransparency = 1
heroText.Text = "EMOTES\nUNIVERSAL"
heroText.TextColor3 = Color3.fromRGB(255,255,255)
heroText.Font = Enum.Font.GothamBlack
heroText.TextSize = isMobile and 20 or 24
heroText.TextXAlignment = Enum.TextXAlignment.Left
heroText.TextYAlignment = Enum.TextYAlignment.Center
heroText.Parent = infoHero

local _infoVersionValue = MakeInfoBlock(isES and "Versión" or "Version", "V5.0", 1)
local _infoCountValue = MakeInfoBlock(isES and "Cantidad de emotes" or "Emote count", tostring(#Emotes), 2)
local _infoStatusValue = MakeInfoBlock(isES and "Estado" or "Status", isES and "MODO LOCAL" or "LOCAL MODE", 3)
local _infoLanguageValue = MakeInfoBlock(isES and "Idioma" or "Language", isES and "ESPAÑOL" or "ENGLISH", 4)
local _infoExtraValue = MakeInfoBlock(isES and "Información" or "Information", isES and "R15 · Favoritos · Bindings · Playlists · Animaciones" or "R15 · Favorites · Bindings · Playlists · Animations", 5)

end

MakeSectionHeader = function(text, order)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 26)
	container.BackgroundTransparency = 1
	container.LayoutOrder = order
	container.ZIndex = 6
	container.Parent = settingsPanel

	local hdr = Instance.new("TextLabel")
	hdr.Size = UDim2.new(1, -4, 1, 0)
	hdr.BackgroundTransparency = 1
	hdr.Text = text:upper()
	hdr.TextColor3 = currentTheme.accent
	hdr.Font = Enum.Font.GothamBold
	hdr.TextSize = 11
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.ZIndex = 7
	hdr.Parent = container
	RegisterTheme(hdr, "TextColor3", "accent")
	return container
end

MakeRow = function(imgId, title, subtitle, order, customH)
	local iconBoxSz = isMobile and 46 or 54
	local hasDesc = subtitle and subtitle ~= ""
	local h = customH or (hasDesc and 72 or 60)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, h)
	row.BackgroundColor3 = currentTheme.secondary
	row.LayoutOrder = order
	row.ZIndex = 6
	row.Parent = settingsPanel
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 11)
	RegisterTheme(row, "BackgroundColor3", "secondary")
	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = currentTheme.stroke
	rowStroke.Thickness = 1
	rowStroke.Transparency = 0.72
	rowStroke.Parent = row
	RegisterTheme(rowStroke, "Color", "stroke")

	local leftPad = 12
	if imgId and imgId ~= "" then
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, iconBoxSz, 0, iconBoxSz)
		iconBox.AnchorPoint = Vector2.new(0, 0.5)
		iconBox.Position = UDim2.new(0, leftPad, 0.5, 0)
		iconBox.BackgroundColor3 = currentTheme.tertiary
		iconBox.ZIndex = 7
		iconBox.Parent = row
		Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 9)
		RegisterTheme(iconBox, "BackgroundColor3", "tertiary")

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0.85, 0, 0.85, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = ResolveAssetImage("rbxassetid://" .. imgId)
		icon.ImageColor3 = Color3.fromRGB(255,255,255)
		icon.ZIndex = 8
		icon.Parent = iconBox
		RegisterTheme(icon, "ImageColor3", "text")
	end

	local textLeft = (imgId and imgId ~= "") and (leftPad + iconBoxSz + 10) or leftPad
	local rightGap = 72

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = currentTheme.text
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = isMobile and 13 or 14
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 7
	titleLbl.Parent = row
	RegisterTheme(titleLbl, "TextColor3", "text")

	if hasDesc then
		titleLbl.Size = UDim2.new(1, -(textLeft + rightGap), 0, 20)
		titleLbl.Position = UDim2.new(0, textLeft, 0, 12)

		local subLbl = Instance.new("TextLabel")
		subLbl.Size = UDim2.new(1, -(textLeft + rightGap), 0, 18)
		subLbl.Position = UDim2.new(0, textLeft, 0, 33)
		subLbl.BackgroundTransparency = 1
		subLbl.Text = subtitle
		subLbl.TextColor3 = currentTheme.textDim
		subLbl.Font = Enum.Font.Gotham
		subLbl.TextSize = isMobile and 10 or 11
		subLbl.TextXAlignment = Enum.TextXAlignment.Left
		subLbl.TextWrapped = true
		subLbl.ZIndex = 7
		subLbl.Parent = row
		RegisterTheme(subLbl, "TextColor3", "textDim")
	else
		titleLbl.Size = UDim2.new(1, -(textLeft + rightGap), 1, 0)
		titleLbl.Position = UDim2.new(0, textLeft, 0, 0)
	end

	return row
end

MakePillToggle = function(parent, value, onChange)
    local pillW, pillH, pad = 50, 28, 3
    local knobSz = pillH - pad * 2
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0,pillW,0,pillH)
    pill.AnchorPoint = Vector2.new(1,0.5)
    pill.Position = UDim2.new(1,-12,0.5,0)
    pill.BackgroundColor3 = value and Color3.fromRGB(245,245,245) or Color3.fromRGB(35,35,35)
    pill.ZIndex = 8
    pill.Parent = parent
    Instance.new("UICorner",pill).CornerRadius = UDim.new(1,0)
    local pst = Instance.new("UIStroke")
    pst.Color = Color3.fromRGB(75,75,75)
    pst.Thickness = 1
    pst.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,knobSz,0,knobSz)
    knob.AnchorPoint = Vector2.new(0,0.5)
    knob.Position = value and UDim2.new(1,-(knobSz+pad),0.5,0) or UDim2.new(0,pad,0.5,0)
    knob.BackgroundColor3 = value and Color3.fromRGB(0,0,0) or Color3.fromRGB(120,120,120)
    knob.ZIndex = 9
    knob.Parent = pill
    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

    local state = value
    local pillBtn = Instance.new("TextButton")
    pillBtn.Size = UDim2.fromScale(1,1)
    pillBtn.BackgroundTransparency = 1
    pillBtn.Text = ""
    pillBtn.ZIndex = 10
    pillBtn.Parent = pill

    local function SetState(v)
        state = v
        TweenService:Create(pill,TweenInfo.new(0.20),{BackgroundColor3=v and Color3.fromRGB(245,245,245) or Color3.fromRGB(35,35,35)}):Play()
        TweenService:Create(knob,TweenInfo.new(0.20,Enum.EasingStyle.Quad),{
            Position=v and UDim2.new(1,-(knobSz+pad),0.5,0) or UDim2.new(0,pad,0.5,0),
            BackgroundColor3=v and Color3.fromRGB(0,0,0) or Color3.fromRGB(120,120,120)
        }):Play()
    end
    pillBtn.MouseButton1Click:Connect(function()
        state = not state
        SetState(state)
        onChange(state)
    end)
    return SetState
end

MakeSectionHeader(isES and "Apariencia" or "Appearance", 1)

do
	local themeRow = MakeRow("110192525313214", L.theme, "", 2, 52)
	local themeNames = {"Dark", "Purple", "Blue", "Green", "Red", "Light", "MaterialYou", "FrostedGlass", "DarkGlass"}
	local themeDisplay = {
		Dark = isES and "Oscuro" or "Dark", Purple = isES and "Morado" or "Purple", Blue = isES and "Azul" or "Blue",
		Green = isES and "Verde" or "Green", Red = isES and "Rojo" or "Red", Light = isES and "Claro" or "Light",
		MaterialYou = "Material You", FrostedGlass = isES and "Cristal claro" or "Frosted Glass", DarkGlass = isES and "Cristal oscuro" or "Dark Glass"
	}

	local chip = Instance.new("TextButton")
	chip.Size = UDim2.new(0, isMobile and 66 or 76, 0, 26)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -12, 0.5, 0)
	chip.BackgroundColor3 = currentTheme.accent
	chip.Text = themeDisplay[Settings.theme] or Settings.theme
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = isMobile and 10 or 11
	chip.ZIndex = 8
	chip.Parent = themeRow
	Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 9)
	RegisterTheme(chip, "BackgroundColor3", "accent")

	local themeIdx = 1
	for i, n in ipairs(themeNames) do if n == Settings.theme then themeIdx = i end end

	chip.MouseButton1Click:Connect(function()
		themeIdx = themeIdx % #themeNames + 1
		Settings.theme = themeNames[themeIdx]
		chip.Text = themeDisplay[Settings.theme] or Settings.theme
		ApplyTheme(Settings.theme)
		SaveData()
	end)
end

do
	local speedRow = MakeRow("113837085020684", L.speed, "", 3, 78)
	local speeds = {0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3}
	local speedIdx = 4
	for i, s in ipairs(speeds) do if s == Settings.speed then speedIdx = i end end

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Size = UDim2.new(0, 48, 0, 28)
	speedLbl.AnchorPoint = Vector2.new(1, 0)
	speedLbl.Position = UDim2.new(1, -12, 0, 12)
	speedLbl.BackgroundTransparency = 1
	speedLbl.Text = Settings.speed .. "x"
	speedLbl.TextColor3 = currentTheme.accent
	speedLbl.Font = Enum.Font.GothamBlack
	speedLbl.TextSize = isMobile and 14 or 15
	speedLbl.TextXAlignment = Enum.TextXAlignment.Right
	speedLbl.ZIndex = 8
	speedLbl.Parent = speedRow
	RegisterTheme(speedLbl, "TextColor3", "accent")

	local iconBoxSz = isMobile and 46 or 54
	local sliderLeft = 12 + iconBoxSz + 10
	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -(sliderLeft + 12), 0, 6)
	sliderBg.Position = UDim2.new(0, sliderLeft, 1, -20)
	sliderBg.BackgroundColor3 = currentTheme.tertiary
	sliderBg.ZIndex = 8
	sliderBg.Parent = speedRow
	Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
	RegisterTheme(sliderBg, "BackgroundColor3", "tertiary")

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(0, 0, 1, 0)
	sliderFill.BackgroundColor3 = currentTheme.accent
	sliderFill.ZIndex = 9
	sliderFill.Parent = sliderBg
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
	RegisterTheme(sliderFill, "BackgroundColor3", "accent")

	local sliderKnob = Instance.new("TextButton")
	sliderKnob.Size = UDim2.new(0, 18, 0, 18)
	sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
	sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
	sliderKnob.Text = ""
	sliderKnob.ZIndex = 10
	sliderKnob.Parent = sliderBg
	Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

	local function UpdateSpeedUI()
		Settings.speed = speeds[speedIdx]
		speedLbl.Text = Settings.speed .. "x"
		local alpha = (speedIdx - 1) / (#speeds - 1)
		TweenService:Create(sliderFill, TweenInfo.new(0.2), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
		TweenService:Create(sliderKnob, TweenInfo.new(0.2), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
		SaveData()
		ApplySpeedToAllTracks()
		if _onSpeedChanged then _onSpeedChanged() end
	end

	local sliderDragging = false
	sliderKnob.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if sliderDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local ax = math.clamp((inp.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			local ni = math.floor(ax * (#speeds - 1) + 1.5)
			if ni ~= speedIdx then speedIdx = ni; UpdateSpeedUI() end
		end
	end)

	UpdateSpeedUI()
end

MakeSectionHeader(isES and "Comportamiento" or "Behaviour", 9)

do
	local row = MakeRow("99427666057293", L.notif, "", 10)
	MakePillToggle(row, Settings.notifications, function(v)
		Settings.notifications = v
		SaveData()
	end)
end

do
	local row = MakeRow("103179694587186", L.loopText or "Loop", "", 11)
	MakePillToggle(row, Settings.loopEmote, function(v)
		Settings.loopEmote = v
		_genv().autoReloadEnabled_HX = v
		SaveData()
	end)
end

do
	local row = MakeRow("", L.stopOnWalk, L.stopOnWalkDesc, 12)
	MakePillToggle(row, Settings.stopOnWalk, function(v)
		Settings.stopOnWalk = v
		SaveData()
	end)
end

Settings.showHUD = false

MakeSectionHeader(isES and "General" or "General", 19)

do
	local row = MakeRow("76975628127992", L.resetLangLbl, L.resetLangDesc, 20)

	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(0, 62, 0, 30)
	resetBtn.AnchorPoint = Vector2.new(1, 0.5)
	resetBtn.Position = UDim2.new(1, -12, 0.5, 0)
	resetBtn.BackgroundColor3 = currentTheme.critical
	resetBtn.Text = L.resetButton
	resetBtn.TextColor3 = Color3.new(1, 1, 1)
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = isMobile and 11 or 12
	resetBtn.ZIndex = 8
	resetBtn.Parent = row
	Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 10)
	RegisterTheme(resetBtn, "BackgroundColor3", "critical")

	resetBtn.MouseButton1Click:Connect(function()
		Settings.language = nil
		SaveData()
		Notify("Emotes", isES and "Idioma restablecido. Ejecuta el script otra vez para elegir." or "Language reset. Run the script again to choose.")
	end)
end

do
	MakeSectionHeader(isES and "Acerca de & Notas de actualización" or "About & Update Notes", 10)
	local verRow = MakeRow("110192525313214", "V5.0", isES and "Versión del sistema" or "System version", 11, 135)

	local verLbl = Instance.new("TextLabel")
	verLbl.Size = UDim2.new(1, -24, 0, 80)
	verLbl.Position = UDim2.new(0, 12, 0, 48)
	verLbl.BackgroundTransparency = 1
	verLbl.Text = isES and "• Carga asíncrona de emotes\n• Ajuste dinámico de paquetes de animación\n• Correcciones de recorte y ventanas\n• Favoritos, bindings y playlists\n• Sincronización y funciones online"
		or "• Async emote loading\n• Dynamic animation pack slot matching\n• Window clipping fixes\n• Favorites, bindings and playlists\n• Sync and online features"
	verLbl.TextColor3 = currentTheme.textDim
	verLbl.Font = Enum.Font.Gotham
	verLbl.TextSize = isMobile and 10 or 11
	verLbl.TextXAlignment = Enum.TextXAlignment.Left
	verLbl.TextYAlignment = Enum.TextYAlignment.Top
	verLbl.TextWrapped = true
	verLbl.ZIndex = 8
	verLbl.Parent = verRow
	RegisterTheme(verLbl, "TextColor3", "textDim")
end


local PROMPT_TAG = "HXCopyEmotePrompt"

local function MakeCopyPrompt(targetChar)
	local root = targetChar:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if root:FindFirstChild(PROMPT_TAG) then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name              = PROMPT_TAG
	prompt.ActionText        = L.copyEmote
	prompt.ObjectText        = ""
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration      = 0
	prompt.RequiresLineOfSight = false
	prompt.Enabled           = true
	prompt.Parent            = root
	prompt.Triggered:Connect(function()
		local h = targetChar:FindFirstChildOfClass("Humanoid")
		if not h then return end
		local anim = h:FindFirstChildOfClass("Animator")
		if not anim then return end
		for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
			local animId = tonumber(track.Animation.AnimationId:match("%d+"))
			if animId and EmotesById[animId] then
				PlayEmote(animId, EmotesById[animId].name)
				return
			end
		end
	end)
end

local function RemoveCopyPrompt(targetChar)
	local root = targetChar:FindFirstChild("HumanoidRootPart")
	if root then
		local p = root:FindFirstChild(PROMPT_TAG)
		if p then p:Destroy() end
	end
end

local _copyEmoteConns = {}

local function EnableCopyEmotePrompts()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			MakeCopyPrompt(p.Character)
		end
	end
	_copyEmoteConns[#_copyEmoteConns + 1] = Players.PlayerAdded:Connect(function(p)
		_copyEmoteConns[#_copyEmoteConns + 1] = p.CharacterAdded:Connect(function(char)
			if Settings.copyEmoteEnabled then MakeCopyPrompt(char) end
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			_copyEmoteConns[#_copyEmoteConns + 1] = p.CharacterAdded:Connect(function(char)
				if Settings.copyEmoteEnabled then MakeCopyPrompt(char) end
			end)
		end
	end
end

local function DisableCopyEmotePrompts()
	for _, conn in ipairs(_copyEmoteConns) do conn:Disconnect() end
	_copyEmoteConns = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			RemoveCopyPrompt(p.Character)
		end
	end
end

if Settings.copyEmoteEnabled then
	EnableCopyEmotePrompts()
end

copyEmoteBtn.MouseButton1Click:Connect(function()
	Settings.copyEmoteEnabled = not Settings.copyEmoteEnabled
	TweenService:Create(copyEmoteBtn, TweenInfo.new(0.2), {
		BackgroundColor3 = Settings.copyEmoteEnabled and currentTheme.success or currentTheme.critical
	}):Play()
	if Settings.copyEmoteEnabled then
		EnableCopyEmotePrompts()
	else
		DisableCopyEmotePrompts()
	end
	SaveData()
end)

local _syncLock = false
do
local ATTR_REQ  = "VFR_Req"
local ATTR_RESP = "VFR_Resp"
local ATTR_SYNC = "VFR_Sync"
local ATTR_STOP = "VFR_Stop"

local REQ_COOLDOWN        = 5
local REQ_SPAM_WINDOW     = 5
local REQ_SPAM_LIMIT      = 3
local REQ_TIMEOUT_DUR     = 30
local INCOMING_COOLDOWN   = 5

local _reqCooldowns      = {}
local _reqSpamStart      = 0
local _reqSpamCount      = 0
local _reqTimeoutUntil   = 0
local _incomingCooldowns = {}

local function _SaveFriend()
	SaveData()
end

local function _LoadFriend()
end

local function _MyAttr(attr, val)
	pcall(function()
		local c = player.Character
		if c then c:SetAttribute(attr, val) end
	end)
end

ShowFriendRequestPanel = function(senderUserId, senderName)
	local dimmer = Instance.new("Frame")
	dimmer.Size = UDim2.new(1,0,1,0)
	dimmer.BackgroundColor3 = Color3.new(0,0,0)
	dimmer.BackgroundTransparency = 0.45
	dimmer.ZIndex = 98000
	dimmer.Parent = gui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 340, 0, 215)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = currentTheme.secondary
	panel.ZIndex = 98001
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
	local ps = Instance.new("UIStroke", panel); ps.Color = currentTheme.stroke; ps.Thickness = 1.5

	local brand = Instance.new("TextLabel")
	brand.Size = UDim2.new(1, 0, 0, 20); brand.Position = UDim2.new(0,0,0,8)
	brand.BackgroundTransparency = 0.72; brand.Text = FriendL.brandTitle
	brand.TextColor3 = currentTheme.accent; brand.Font = Enum.Font.GothamBold
	brand.TextSize = 11; brand.ZIndex = 98002; brand.Parent = panel

	local av = Instance.new("ImageLabel")
	av.Size = UDim2.new(0,48,0,48); av.Position = UDim2.new(0,14,0,34)
	av.BackgroundTransparency = 1
	av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(senderUserId) .. "&w=150&h=150"
	av.ZIndex = 98002; av.Parent = panel
	Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

	local reqTxt = Instance.new("TextLabel")
	reqTxt.Size = UDim2.new(1,-80,0,48); reqTxt.Position = UDim2.new(0,70,0,34)
	reqTxt.BackgroundTransparency = 1
	reqTxt.Text = string.format(FriendL.requestIncoming, tostring(senderName))
	reqTxt.TextColor3 = currentTheme.text; reqTxt.Font = Enum.Font.Gotham
	reqTxt.TextSize = 12; reqTxt.TextWrapped = true
	reqTxt.TextXAlignment = Enum.TextXAlignment.Left
	reqTxt.TextYAlignment = Enum.TextYAlignment.Center
	reqTxt.ZIndex = 98002; reqTxt.Parent = panel

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1,-28,0,34); bar.Position = UDim2.new(0,14,0,90)
	bar.BackgroundColor3 = currentTheme.tertiary; bar.ZIndex = 98002; bar.Parent = panel
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0,10)

	local cbBtn = Instance.new("TextButton")
	cbBtn.Size = UDim2.new(0,20,0,20); cbBtn.Position = UDim2.new(0,7,0.5,-10)
	cbBtn.BackgroundColor3 = currentTheme.secondary; cbBtn.Text = ""; cbBtn.ZIndex = 98003; cbBtn.Parent = bar
	Instance.new("UICorner", cbBtn).CornerRadius = UDim.new(1,0)
	local cbStroke = Instance.new("UIStroke", cbBtn); cbStroke.Color = currentTheme.stroke; cbStroke.Thickness = 1.5

	local cbDot = Instance.new("Frame")
	cbDot.Size = UDim2.new(0,10,0,10); cbDot.AnchorPoint = Vector2.new(0.5,0.5)
	cbDot.Position = UDim2.new(0.5,0,0.5,0); cbDot.BackgroundColor3 = currentTheme.accent
	cbDot.Visible = FriendData.autoReject; cbDot.ZIndex = 98004; cbDot.Parent = cbBtn
	Instance.new("UICorner", cbDot).CornerRadius = UDim.new(1,0)

	local autoLbl = Instance.new("TextLabel")
	autoLbl.Size = UDim2.new(1,-34,1,0); autoLbl.Position = UDim2.new(0,32,0,0)
	autoLbl.BackgroundTransparency = 1; autoLbl.Text = L.autoRejectLbl
	autoLbl.TextColor3 = currentTheme.textDim; autoLbl.Font = Enum.Font.Gotham
	autoLbl.TextSize = 11; autoLbl.TextXAlignment = Enum.TextXAlignment.Left
	autoLbl.ZIndex = 98003; autoLbl.Parent = bar

	cbBtn.MouseButton1Click:Connect(function()
		FriendData.autoReject = not FriendData.autoReject
		cbDot.Visible = FriendData.autoReject
		_SaveFriend()
	end)

	local function _close()
		pcall(function() dimmer:Destroy() end)
		pcall(function() panel:Destroy() end)
	end

	local rejBtn = Instance.new("TextButton")
	rejBtn.Size = UDim2.new(0.46,0,0,40); rejBtn.Position = UDim2.new(0,14,0,138)
	rejBtn.BackgroundColor3 = currentTheme.critical; rejBtn.Text = L.reject
	rejBtn.TextColor3 = Color3.new(1,1,1); rejBtn.Font = Enum.Font.GothamBold
	rejBtn.TextSize = 13; rejBtn.ZIndex = 98002; rejBtn.Parent = panel
	Instance.new("UICorner", rejBtn).CornerRadius = UDim.new(0,12)

	local accBtn = Instance.new("TextButton")
	accBtn.Size = UDim2.new(0.46,0,0,40); accBtn.Position = UDim2.new(0.54,-14,0,138)
	accBtn.BackgroundColor3 = currentTheme.success; accBtn.Text = L.accept
	accBtn.TextColor3 = Color3.new(1,1,1); accBtn.Font = Enum.Font.GothamBold
	accBtn.TextSize = 13; accBtn.ZIndex = 98002; accBtn.Parent = panel
	Instance.new("UICorner", accBtn).CornerRadius = UDim.new(0,12)

	rejBtn.MouseButton1Click:Connect(function()
		_MyAttr(ATTR_RESP, tostring(senderUserId) .. ":0")
		task.delay(1, function() _MyAttr(ATTR_RESP, "") end)
		_close()
	end)

	accBtn.MouseButton1Click:Connect(function()
		FriendData.friends[tostring(senderUserId)] = {name = senderName, syncEnabled = true, online = Players:GetPlayerByUserId(tonumber(senderUserId)) ~= nil}
		_SaveFriend()
		if RefreshFriendList then RefreshFriendList() end
		_close()
	end)

	if FriendData.autoReject then
		_MyAttr(ATTR_RESP, tostring(senderUserId) .. ":0")
		task.delay(0.5, function() _MyAttr(ATTR_RESP, "") end)
		_close()
	end
end

local function _WatchChar(char, uid, uname)
end

notifPanel = Instance.new("Frame")
notifPanel.Size = isMobile and UDim2.new(0, 260, 0, 300) or UDim2.new(0, 300, 0, 400)
notifPanel.Position = isMobile and UDim2.new(1, -270, 0, 45) or UDim2.new(1, -310, 0, 50)
notifPanel.BackgroundColor3 = currentTheme.primary
notifPanel.ZIndex = 500
notifPanel.Visible = false
notifPanel.Parent = gui
Instance.new("UICorner", notifPanel).CornerRadius = UDim.new(0, 10)
RegisterTheme(notifPanel, "BackgroundColor3", "primary")

npStroke = Instance.new("UIStroke", notifPanel)
npStroke.Color = currentTheme.stroke
npStroke.Thickness = 1
RegisterTheme(npStroke, "Color", "stroke")

npTitle = Instance.new("TextLabel")
npTitle.Size = UDim2.new(1, -20, 0, 40)
npTitle.Position = UDim2.new(0, 10, 0, 0)
npTitle.BackgroundTransparency = 1
npTitle.Text = isES and "Notificaciones" or "Notifications"
npTitle.TextColor3 = currentTheme.text
npTitle.Font = Enum.Font.GothamBold
npTitle.TextSize = 16
npTitle.TextXAlignment = Enum.TextXAlignment.Left
npTitle.ZIndex = 501
npTitle.Parent = notifPanel
RegisterTheme(npTitle, "TextColor3", "text")

npCloseBtn = Instance.new("TextButton")
npCloseBtn.Size = UDim2.new(0, 24, 0, 24)
npCloseBtn.Position = UDim2.new(1, -34, 0, 8)
npCloseBtn.BackgroundColor3 = currentTheme.critical
npCloseBtn.Text = "X"
npCloseBtn.TextColor3 = Color3.new(1,1,1)
npCloseBtn.Font = Enum.Font.GothamBold
npCloseBtn.TextSize = 12
npCloseBtn.ZIndex = 502
npCloseBtn.Parent = notifPanel
Instance.new("UICorner", npCloseBtn).CornerRadius = UDim.new(1,0)
npCloseBtn.MouseButton1Click:Connect(function() notifPanel.Visible = false end)

npScroll = Instance.new("ScrollingFrame")
npScroll.Size = UDim2.new(1, -20, 1, -50)
npScroll.Position = UDim2.new(0, 10, 0, 40)
npScroll.BackgroundTransparency = 1
npScroll.ScrollBarThickness = 0
npScroll.ScrollBarImageColor3 = currentTheme.accent
npScroll.ZIndex = 501
npScroll.Parent = notifPanel
RegisterTheme(npScroll, "ScrollBarImageColor3", "accent")
npLayout = Instance.new("UIListLayout")
npLayout.Padding = UDim.new(0, 6)
npLayout.Parent = npScroll

notifBtn.MouseButton1Click:Connect(function()
	notifPanel.Visible = not notifPanel.Visible
end)

local function ClearNotifications()
	for _, ch in ipairs(npScroll:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
end

local function RenderNotifications(reqs, syncs)
	ClearNotifications()
	reqs = reqs or FriendData.incomingRequests or {}
	syncs = syncs or {}

	for _, r in ipairs(reqs) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 75)
		card.BackgroundColor3 = currentTheme.secondary
		card.ZIndex = 502
		card.Parent = npScroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 13)
		RegisterTheme(card, "BackgroundColor3", "secondary")

		local av = Instance.new("ImageLabel")
		av.Size = UDim2.new(0, 30, 0, 30)
		av.Position = UDim2.new(0, 8, 0, 8)
		av.BackgroundTransparency = 1
		av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. r.userId .. "&w=150&h=150"
		av.ZIndex = 503
		av.Parent = card
		Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

		local nm = Instance.new("TextLabel")
		nm.Size = UDim2.new(1, -50, 0, 30)
		nm.Position = UDim2.new(0, 46, 0, 8)
		nm.BackgroundTransparency = 1
		nm.Text = r.username
		nm.TextColor3 = currentTheme.text
		nm.Font = Enum.Font.GothamBold
		nm.TextSize = 13
		nm.TextXAlignment = Enum.TextXAlignment.Left
		nm.ZIndex = 503
		nm.Parent = card
		RegisterTheme(nm, "TextColor3", "text")

		local btnYes = Instance.new("TextButton")
		btnYes.Size = UDim2.new(0.5, -12, 0, 24)
		btnYes.Position = UDim2.new(0, 8, 0, 42)
		btnYes.BackgroundColor3 = currentTheme.success
		btnYes.Text = isES and "Aceptar" or "Accept"
		btnYes.TextColor3 = Color3.new(1,1,1)
		btnYes.Font = Enum.Font.GothamBold
		btnYes.TextSize = 11
		btnYes.ZIndex = 504
		btnYes.Parent = card
		Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 6)

		local btnNo = Instance.new("TextButton")
		btnNo.Size = UDim2.new(0.5, -12, 0, 24)
		btnNo.Position = UDim2.new(0.5, 4, 0, 42)
		btnNo.BackgroundColor3 = currentTheme.critical
		btnNo.Text = isES and "Rechazar" or "Reject"
		btnNo.TextColor3 = Color3.new(1,1,1)
		btnNo.Font = Enum.Font.GothamBold
		btnNo.TextSize = 11
		btnNo.ZIndex = 504
		btnNo.Parent = card
		Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

		btnYes.MouseButton1Click:Connect(function()
			FriendData.friends[tostring(r.userId)] = {name = r.username, syncEnabled = true, online = Players:GetPlayerByUserId(tonumber(r.userId)) ~= nil}
			_SaveFriend()
			if RefreshFriendList then RefreshFriendList() end
			card:Destroy()
		end)
		btnNo.MouseButton1Click:Connect(function()
			card:Destroy()
		end)
	end

	for _, s in ipairs(syncs) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 95)
		card.BackgroundColor3 = currentTheme.tertiary
		card.ZIndex = 502
		card.Parent = npScroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
		RegisterTheme(card, "BackgroundColor3", "tertiary")

		local emIcon = Instance.new("ImageLabel")
		emIcon.Size = UDim2.new(0, 30, 0, 30)
		emIcon.Position = UDim2.new(0, 8, 0, 8)
		emIcon.BackgroundTransparency = 1
		emIcon.Image = s.icon or ""
		emIcon.ZIndex = 503
		emIcon.Parent = card
		Instance.new("UICorner", emIcon).CornerRadius = UDim.new(1,0)

		local av = Instance.new("ImageLabel")
		av.Size = UDim2.new(0, 30, 0, 30)
		av.Position = UDim2.new(1, -38, 0, 8)
		av.BackgroundTransparency = 1
		av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. s.senderId .. "&w=150&h=150"
		av.ZIndex = 503
		av.Parent = card
		Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

		local msg = Instance.new("TextLabel")
		msg.Size = UDim2.new(1, -80, 0, 30)
		msg.Position = UDim2.new(0, 42, 0, 8)
		msg.BackgroundTransparency = 1
		msg.Text = isES and (s.senderName .. " quiere reproducir " .. LocalizeEmoteName(s.emoteName) .. " contigo") or (s.senderName .. " wants to play " .. LocalizeEmoteName(s.emoteName) .. " with you")
		msg.TextColor3 = currentTheme.text
		msg.Font = Enum.Font.Gotham
		msg.TextSize = 11
		msg.TextWrapped = true
		msg.ZIndex = 503
		msg.Parent = card
		RegisterTheme(msg, "TextColor3", "text")

		local btnPlay = Instance.new("TextButton")
		btnPlay.Size = UDim2.new(0.5, -12, 0, 24)
		btnPlay.Position = UDim2.new(0, 8, 0, 62)
		btnPlay.BackgroundColor3 = Color3.new(0,0,0)
		btnPlay.Text = isES and "Reproducir" or "Play"
		btnPlay.TextColor3 = Color3.new(1,1,1)
		btnPlay.Font = Enum.Font.GothamBold
		btnPlay.TextSize = 11
		btnPlay.ZIndex = 504
		btnPlay.Parent = card
		Instance.new("UICorner", btnPlay).CornerRadius = UDim.new(0, 6)

		local btnNo = Instance.new("TextButton")
		btnNo.Size = UDim2.new(0.5, -12, 0, 24)
		btnNo.Position = UDim2.new(0.5, 4, 0, 62)
		btnNo.BackgroundColor3 = currentTheme.critical
		btnNo.Text = isES and "Rechazar" or "Reject"
		btnNo.TextColor3 = Color3.new(1,1,1)
		btnNo.Font = Enum.Font.GothamBold
		btnNo.TextSize = 11
		btnNo.ZIndex = 504
		btnNo.Parent = card
		Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 6)

		btnPlay.MouseButton1Click:Connect(function()
			FriendData.currentSyncPartner = tostring(s.initiatorId or s.senderId or "")
			PlayEmote(s.emoteId, s.emoteName, true, s.syncStartTime)
			card:Destroy()
		end)
		btnNo.MouseButton1Click:Connect(function() card:Destroy() end)
	end

	npScroll.CanvasSize = UDim2.new(0, 0, 0, npLayout.AbsoluteContentSize.Y + 10)
end
end


local function _WatchAll() end

_genv().HXBroadcastStop = function()
	FriendData.currentSyncPartner = nil
end

_genv().HXBroadcastSync = function(emoteId, emoteName, syncStartTime)
end

local function _MakeFriendToggle(txt, desc, order, getVal, setVal)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,60)
	row.BackgroundColor3 = currentTheme.tertiary
	row.LayoutOrder = order; row.ZIndex = 6; row.Parent = friendsPanel
	Instance.new("UICorner", row).CornerRadius = UDim.new(0,12)
	RegisterTheme(row, "BackgroundColor3", "tertiary")

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(0.55,0,0,22); tl.Position = UDim2.new(0,12,0,8)
	tl.BackgroundTransparency = 1; tl.Text = txt; tl.TextColor3 = currentTheme.text
	tl.Font = Enum.Font.GothamBold; tl.TextSize = isMobile and 11 or 12
	tl.TextXAlignment = Enum.TextXAlignment.Left; tl.ZIndex = 7; tl.Parent = row
	RegisterTheme(tl, "TextColor3", "text")

	local dl = Instance.new("TextLabel")
	dl.Size = UDim2.new(0.55,0,0,26); dl.Position = UDim2.new(0,12,0,30)
	dl.BackgroundTransparency = 1; dl.Text = desc; dl.TextColor3 = currentTheme.textDim
	dl.Font = Enum.Font.Gotham; dl.TextSize = isMobile and 9 or 10
	dl.TextXAlignment = Enum.TextXAlignment.Left; dl.TextWrapped = true; dl.ZIndex = 7; dl.Parent = row
	RegisterTheme(dl, "TextColor3", "textDim")

	local pillW, pillH, pad = 48, 26, 3
	local tb = Instance.new("TextButton")
	tb.Size = UDim2.new(0,pillW,0,pillH); tb.Position = UDim2.new(1,-60,0.5,-pillH/2)
	tb.BackgroundColor3 = getVal() and Color3.fromRGB(245,245,245) or Color3.fromRGB(34,34,34)
	tb.Text = ""; tb.AutoButtonColor = false
	tb.ZIndex = 8; tb.Parent = row
	Instance.new("UICorner", tb).CornerRadius = UDim.new(1,0)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0,pillH-pad*2,0,pillH-pad*2)
	knob.AnchorPoint = Vector2.new(0,0.5)
	knob.Position = getVal() and UDim2.new(1,-((pillH-pad*2)+pad),0.5,0) or UDim2.new(0,pad,0.5,0)
	knob.BackgroundColor3 = getVal() and Color3.fromRGB(0,0,0) or Color3.fromRGB(118,118,118)
	knob.ZIndex = 9; knob.Parent = tb
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

	tb.MouseButton1Click:Connect(function()
		local v = not getVal(); setVal(v)
		TweenService:Create(tb,TweenInfo.new(0.18),{BackgroundColor3=v and Color3.fromRGB(245,245,245) or Color3.fromRGB(34,34,34)}):Play()
		TweenService:Create(knob,TweenInfo.new(0.18),{
			Position=v and UDim2.new(1,-((pillH-pad*2)+pad),0.5,0) or UDim2.new(0,pad,0.5,0),
			BackgroundColor3=v and Color3.fromRGB(0,0,0) or Color3.fromRGB(118,118,118)
		}):Play()
		_SaveFriend()
	end)
end

_MakeFriendToggle(
	FriendL.playEmoteLbl,
	FriendL.playEmoteDesc,
	2,
	function() return FriendData.playFriendEmote end,
	function(v) FriendData.playFriendEmote = v end
)
_MakeFriendToggle(
	FriendL.syncEmoteLbl,
	FriendL.syncEmoteDesc,
	3,
	function() return FriendData.syncEmote end,
	function(v) FriendData.syncEmote = v end
)


do
serverPlayersBtn = Instance.new("TextButton")
serverPlayersBtn.Size = UDim2.new(0, isMobile and 150 or 188, 0, 34)
serverPlayersBtn.BackgroundColor3 = currentTheme.tertiary
serverPlayersBtn.BackgroundTransparency = 0.38
serverPlayersBtn.Text = L.serverPlayersDown
serverPlayersBtn.TextColor3 = Color3.new(1, 1, 1)
serverPlayersBtn.Font = Enum.Font.GothamBold
serverPlayersBtn.TextSize = isMobile and 11 or 12
serverPlayersBtn.LayoutOrder = 0
serverPlayersBtn.ZIndex = 6
serverPlayersBtn.Parent = friendsPanel
Instance.new("UICorner", serverPlayersBtn).CornerRadius = UDim.new(0, 11)

serverPlayersContainer = Instance.new("Frame")
serverPlayersContainer.Size = UDim2.new(1,0,0,0)
serverPlayersContainer.AutomaticSize = Enum.AutomaticSize.Y
serverPlayersContainer.BackgroundTransparency = 1
serverPlayersContainer.Visible = false
serverPlayersContainer.LayoutOrder = 1
serverPlayersContainer.ZIndex = 5
serverPlayersContainer.Parent = friendsPanel
spListLayout = Instance.new("UIListLayout")
spListLayout.Padding = UDim.new(0,6)
spListLayout.Parent = serverPlayersContainer

emptySpLbl = Instance.new("TextLabel")
emptySpLbl.Size = UDim2.new(1,0,0,36); emptySpLbl.BackgroundTransparency = 1
emptySpLbl.Text = L.noOneFound
emptySpLbl.TextColor3 = currentTheme.textDim; emptySpLbl.Font = Enum.Font.Gotham
emptySpLbl.TextSize = 11; emptySpLbl.TextWrapped = true
emptySpLbl.ZIndex = 6; emptySpLbl.Parent = serverPlayersContainer
RegisterTheme(emptySpLbl, "TextColor3", "textDim")

local serverPlayersData = {}

local function RefreshServerPlayersList()
	if not serverPlayersContainer then return end
	for _, ch in ipairs(serverPlayersContainer:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	local hasAny = false
	for _, pdata in ipairs(serverPlayersData) do
		if pdata.userId ~= tostring(player.UserId) and not (FriendData.friends and FriendData.friends[pdata.userId]) then
			hasAny = true
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1,0,0,40); row.BackgroundColor3 = currentTheme.tertiary
			row.ZIndex = 6; row.Parent = serverPlayersContainer
			Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
			RegisterTheme(row, "BackgroundColor3", "tertiary")

			local av = Instance.new("ImageLabel")
			av.Size = UDim2.new(0,30,0,30); av.Position = UDim2.new(0,8,0.5,-15)
			av.BackgroundTransparency = 1
			av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(pdata.userId) .. "&w=150&h=150"
			av.ZIndex = 7; av.Parent = row
			Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

			local nl = Instance.new("TextLabel")
			nl.Size = UDim2.new(1,-100,1,0); nl.Position = UDim2.new(0,46,0,0)
			nl.BackgroundTransparency = 1; nl.Text = pdata.username
			nl.TextColor3 = currentTheme.text; nl.Font = Enum.Font.GothamBold
			nl.TextSize = isMobile and 11 or 12; nl.TextXAlignment = Enum.TextXAlignment.Left
			nl.ZIndex = 7; nl.Parent = row

			local addBtn = Instance.new("TextButton")
			addBtn.Size = UDim2.new(0, 40, 0, 24); addBtn.Position = UDim2.new(1, -48, 0.5, -12)
			addBtn.BackgroundColor3 = currentTheme.accent
			addBtn.Text = "+"
			addBtn.TextColor3 = Color3.new(1,1,1); addBtn.Font = Enum.Font.GothamBold
			addBtn.TextSize = 16
			addBtn.ZIndex = 8; addBtn.Parent = row
			Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)

			addBtn.MouseButton1Click:Connect(function()
				FriendData.friends[tostring(pdata.userId)] = {name = pdata.username, syncEnabled = true, online = true}
				_SaveFriend()
				addBtn.Text = "OK"
				if RefreshFriendList then RefreshFriendList() end
				RefreshServerPlayersList()
			end)
		end
	end
	emptySpLbl.Visible = not hasAny
end

local function RebuildServerPlayersData()
	serverPlayersData = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			serverPlayersData[#serverPlayersData + 1] = {userId = tostring(p.UserId), username = p.Name}
		end
	end
	RefreshServerPlayersList()
end

serverPlayersBtn.MouseButton1Click:Connect(function()
	serverPlayersContainer.Visible = not serverPlayersContainer.Visible
	serverPlayersBtn.Text = serverPlayersContainer.Visible and L.serverPlayersUp or L.serverPlayersDown
	if serverPlayersContainer.Visible then RebuildServerPlayersData() end
end)

local _playerAddedConn = Players.PlayerAdded:Connect(function()
	if serverPlayersContainer.Visible then RebuildServerPlayersData() end
	if RefreshFriendList then RefreshFriendList() end
end)
local _playerRemovingConn = Players.PlayerRemoving:Connect(function()
	if serverPlayersContainer.Visible then RebuildServerPlayersData() end
	if RefreshFriendList then task.defer(RefreshFriendList) end
end)
_friendConns[#_friendConns + 1] = _playerAddedConn
_friendConns[#_friendConns + 1] = _playerRemovingConn
end


do
infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 52)
infoBox.BackgroundColor3 = Color3.fromRGB(59, 59, 59)
infoBox.BackgroundTransparency = 0.4
infoBox.LayoutOrder = 3
infoBox.ZIndex = 5
infoBox.Parent = friendsPanel
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 10)
infoBoxLbl = Instance.new("TextLabel")
infoBoxLbl.Size = UDim2.new(1, -32, 1, 0)
infoBoxLbl.Position = UDim2.new(0, 32, 0, 0)
infoBoxLbl.BackgroundTransparency = 1
infoBoxLbl.Text = L.friendInfoTxt
infoBoxLbl.TextColor3 = Color3.fromRGB(218, 218, 218)
infoBoxLbl.Font = Enum.Font.Gotham
infoBoxLbl.TextSize = 10
infoBoxLbl.TextWrapped = true
infoBoxLbl.TextXAlignment = Enum.TextXAlignment.Left
infoBoxLbl.TextYAlignment = Enum.TextYAlignment.Center
infoBoxLbl.ZIndex = 6
infoBoxLbl.Parent = infoBox
local infoIcon = Instance.new("ImageLabel")
infoIcon.Size = UDim2.new(0, 18, 0, 18)
infoIcon.Position = UDim2.new(0, 8, 0.5, -9)
infoIcon.BackgroundTransparency = 1
infoIcon.Image = ResolveAssetImage(Icons.Info)
infoIcon.ImageColor3 = Color3.fromRGB(255,255,255)
infoIcon.ScaleType = Enum.ScaleType.Fit
infoIcon.ZIndex = 6
infoIcon.Parent = infoBox
end

flHeader = Instance.new("TextLabel")
flHeader.Size = UDim2.new(1,0,0,22); flHeader.BackgroundTransparency = 1
flHeader.Text = L.friendListHeader; flHeader.TextColor3 = currentTheme.textDim
flHeader.Font = Enum.Font.GothamBold; flHeader.TextSize = 11
flHeader.LayoutOrder = 4; flHeader.ZIndex = 5; flHeader.Parent = friendsPanel
RegisterTheme(flHeader, "TextColor3", "textDim")

friendListContainer = Instance.new("Frame")
friendListContainer.Size = UDim2.new(1,0,0,0)
friendListContainer.AutomaticSize = Enum.AutomaticSize.Y
friendListContainer.BackgroundTransparency = 1
friendListContainer.LayoutOrder = 5; friendListContainer.ZIndex = 5; friendListContainer.Parent = friendsPanel
flListLayout = Instance.new("UIListLayout")
flListLayout.Padding = UDim.new(0,6); flListLayout.Parent = friendListContainer

emptyFriendLbl = Instance.new("TextLabel")
emptyFriendLbl.Size = UDim2.new(1,0,0,36); emptyFriendLbl.BackgroundTransparency = 1
emptyFriendLbl.Text = L.noFriends
emptyFriendLbl.TextColor3 = currentTheme.textDim; emptyFriendLbl.Font = Enum.Font.Gotham
emptyFriendLbl.TextSize = 11; emptyFriendLbl.TextWrapped = true
emptyFriendLbl.ZIndex = 6; emptyFriendLbl.Parent = friendListContainer
RegisterTheme(emptyFriendLbl, "TextColor3", "textDim")

RefreshFriendList = function()
	for _, ch in ipairs(friendListContainer:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	local hasAny = false
	for userId, fdata in pairs(FriendData.friends) do
		hasAny = true
		local uid = tonumber(userId)
		local livePlayer = uid and Players:GetPlayerByUserId(uid) or nil
		fdata.online = livePlayer ~= nil
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1,0,0,50); row.BackgroundColor3 = currentTheme.tertiary
		row.ZIndex = 6; row.Parent = friendListContainer
		Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
		RegisterTheme(row, "BackgroundColor3", "tertiary")

		local av = Instance.new("ImageLabel")
		av.Size = UDim2.new(0,36,0,36); av.Position = UDim2.new(0,8,0.5,-18)
		av.BackgroundTransparency = 1
		av.Image = uid and ("rbxthumb://type=AvatarHeadShot&id=" .. uid .. "&w=150&h=150") or ""
		av.ZIndex = 7; av.Parent = row
		Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

		local statusDot = Instance.new("Frame")
		statusDot.Size = UDim2.new(0, 6, 0, 6)
		statusDot.Position = UDim2.new(0, 52, 0, 14)
		statusDot.BackgroundColor3 = fdata.online and currentTheme.success or currentTheme.critical
		statusDot.ZIndex = 7; statusDot.Parent = row
		Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1,0)

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(0, 100, 0, 14)
		statusLbl.Position = UDim2.new(0, 62, 0, 10)
		statusLbl.BackgroundTransparency = 1
		local stxt = isES and (fdata.online and "Activo" or "Inactivo") or (fdata.online and "Active" or "Inactive")
		statusLbl.Text = stxt
		statusLbl.TextColor3 = currentTheme.text
		statusLbl.Font = Enum.Font.GothamMedium
		statusLbl.TextSize = 9
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.ZIndex = 7; statusLbl.Parent = row
		RegisterTheme(statusLbl, "TextColor3", "text")

		local nl = Instance.new("TextLabel")
		nl.Size = UDim2.new(1,-130,0,20); nl.Position = UDim2.new(0,52,0,22)
		nl.BackgroundTransparency = 1; nl.Text = (fdata.name or userId)
		nl.TextColor3 = currentTheme.text; nl.Font = Enum.Font.GothamBold
		nl.TextSize = isMobile and 11 or 12; nl.TextXAlignment = Enum.TextXAlignment.Left
		nl.ZIndex = 7; nl.Parent = row
		RegisterTheme(nl, "TextColor3", "text")

		if not fdata.online then
			row.BackgroundTransparency = 0.5
			av.ImageTransparency = 0.5
			nl.TextTransparency = 0.5
			statusDot.BackgroundTransparency = 0.5
			statusLbl.TextTransparency = 0.5
		end

		local syncBtn = Instance.new("TextButton")
		local isFollowing = tostring(FriendData.currentSyncPartner or "") == tostring(userId)
		syncBtn.Visible = (fdata.online == true)
		syncBtn.Size = UDim2.new(0,56,0,24); syncBtn.Position = UDim2.new(1,-94,0.5,-12)
		syncBtn.BackgroundColor3 = isFollowing and currentTheme.success or currentTheme.stroke
		syncBtn.Text = isFollowing and (isES and "SIGUIENDO" or "FOLLOW") or (isES and "SYNC" or "SYNC")
		syncBtn.TextColor3 = Color3.new(1,1,1); syncBtn.Font = Enum.Font.GothamBold
		syncBtn.TextSize = 9; syncBtn.ZIndex = 7; syncBtn.Parent = row
		Instance.new("UICorner", syncBtn).CornerRadius = UDim.new(0,8)

		syncBtn.MouseButton1Click:Connect(function()
			if tostring(FriendData.currentSyncPartner or "") == tostring(userId) then
				FriendData.currentSyncPartner = nil
				StopEmote(false)
			else
				FriendData.currentSyncPartner = tostring(userId)
				local p = Players:GetPlayerByUserId(uid)
				if p and p.Character then
					local h = p.Character:FindFirstChildOfClass("Humanoid")
					local a = h and h:FindFirstChildOfClass("Animator")
					if a then
						for _, pt in ipairs(a:GetPlayingAnimationTracks()) do
							local animId = pt.Animation and tonumber(pt.Animation.AnimationId:match("%d+"))
							if animId and EmotesById[animId] then
								local startAt = workspace:GetServerTimeNow() - (pt.TimePosition / math.max(Settings.speed, 0.01))
								PlayEmote(animId, EmotesById[animId].name, true, startAt)
								break
							end
						end
					end
				end
			end
			_SaveFriend()
			RefreshFriendList()
		end)

		local rmBtn = Instance.new("TextButton")
		rmBtn.Size = UDim2.new(0,28,0,24); rmBtn.Position = UDim2.new(1,-30,0.5,-12)
		rmBtn.BackgroundColor3 = currentTheme.critical; rmBtn.Text = "-"
		rmBtn.TextColor3 = Color3.new(1,1,1); rmBtn.Font = Enum.Font.GothamBold
		rmBtn.TextSize = 16; rmBtn.ZIndex = 7; rmBtn.Parent = row
		Instance.new("UICorner", rmBtn).CornerRadius = UDim.new(0,8)

		rmBtn.MouseButton1Click:Connect(function()
			FriendData.friends[userId] = nil
			if FriendData.currentSyncPartner == userId then FriendData.currentSyncPartner = nil end
			_SaveFriend(); RefreshFriendList()
		end)
	end

	emptyFriendLbl.Text = isES and "No hay jugadores guardados. Abre Jugadores del servidor para añadir uno." or "No saved players. Open Server Players to add one."
	emptyFriendLbl.Visible = not hasAny
	flHeader.Visible = hasAny
end
RefreshFriendList()


local _prevClean = _genv().HXEmotesCleanup
_genv().HXEmotesCleanup = function()
	if _prevClean then pcall(_prevClean) end
	for _, c in ipairs(_friendConns) do pcall(function() c:Disconnect() end) end
	_friendConns = {}
	pcall(function() _genv().HXBroadcastSync = nil end)
	pcall(function() _genv().HXBroadcastStop = nil end)
end


do
selectedEmote = nil
selectedCardStroke = nil
selectedCardContainer = nil

previewPanel = Instance.new("Frame")
previewPanel.Name = "SelectedEmotePreview"
if previewStacked then
    previewPanel.Size = UDim2.new(1,-24,0,previewPanelH)
    previewPanel.Position = UDim2.new(0,12,0,titleH+searchH+16)
else
    previewPanel.Size = UDim2.new(0,previewPanelW,1,-(titleH+searchH+bottomBarH+32))
    previewPanel.Position = UDim2.new(1,-(previewPanelW+10),0,titleH+searchH+14)
end
previewPanel.BackgroundColor3 = currentTheme.secondary
previewPanel.BackgroundTransparency = 0.34
previewPanel.Visible = false
previewPanel.BorderSizePixel = 0
previewPanel.ZIndex = 12
previewPanel.Parent = content
Instance.new("UICorner",previewPanel).CornerRadius = UDim.new(0,13)
local previewStroke = Instance.new("UIStroke")
previewStroke.Color = Color3.fromRGB(72,72,72)
previewStroke.Thickness = 1
previewStroke.Parent = previewPanel

local previewHeader = Instance.new("TextLabel")
previewHeader.Size = previewStacked and UDim2.new(0.48,0,0,18) or UDim2.new(1,-20,0,22)
previewHeader.Position = UDim2.new(0,10,0,8)
previewHeader.BackgroundTransparency = 1
previewHeader.Text = isES and "VISTA PREVIA" or "PREVIEW"
previewHeader.TextColor3 = Color3.fromRGB(245,245,245)
previewHeader.Font = Enum.Font.GothamBlack
previewHeader.TextSize = previewStacked and 8 or (isMobile and 8 or 10)
previewHeader.TextXAlignment = Enum.TextXAlignment.Left
previewHeader.ZIndex = 13
previewHeader.Parent = previewPanel

local previewRule = Instance.new("Frame")
previewRule.Size = previewStacked and UDim2.new(0.22,0,0,1) or UDim2.new(0,54,0,1)
previewRule.Position = UDim2.new(0,10,0,previewStacked and 27 or 31)
previewRule.BackgroundColor3 = Color3.fromRGB(245,245,245)
previewRule.BackgroundTransparency = 0.18
previewRule.BorderSizePixel = 0
previewRule.ZIndex = 13
previewRule.Parent = previewPanel

previewImage = Instance.new("ImageLabel")
if previewStacked then
    previewImage.Size = UDim2.new(0,86,0,math.max(58,previewPanelH-46))
    previewImage.Position = UDim2.new(0,10,0,36)
else
    previewImage.Size = UDim2.new(1,-20,0,isMobile and 96 or 150)
    previewImage.Position = UDim2.new(0,10,0,40)
end
previewImage.BackgroundColor3 = currentTheme.tertiary
previewImage.BackgroundTransparency = 0.46
previewImage.Image = ""
previewImage.ImageColor3 = Color3.fromRGB(255,255,255)
previewImage.ScaleType = Enum.ScaleType.Fit
previewImage.ZIndex = 13
previewImage.Parent = previewPanel
Instance.new("UICorner",previewImage).CornerRadius = UDim.new(0,7)
local previewImageStroke = Instance.new("UIStroke")
previewImageStroke.Color = Color3.fromRGB(55,55,55)
previewImageStroke.Thickness = 1
previewImageStroke.Parent = previewImage

previewName = Instance.new("TextLabel")
previewName.Size = previewStacked and UDim2.new(1,-112,0,28) or UDim2.new(1,-20,0,isMobile and 26 or 34)
previewName.Position = previewStacked and UDim2.new(0,106,0,34) or UDim2.new(0,10,0,isMobile and 154 or 198)
previewName.BackgroundTransparency = 1
previewName.Text = isES and "SELECCIONA UN EMOTE" or "SELECT AN EMOTE"
previewName.TextColor3 = Color3.fromRGB(245,245,245)
previewName.Font = Enum.Font.GothamBlack
previewName.TextSize = previewStacked and 10 or (isMobile and 9 or 13)
previewName.TextXAlignment = Enum.TextXAlignment.Left
previewName.TextWrapped = true
previewName.TextTruncate = Enum.TextTruncate.AtEnd
previewName.ZIndex = 13
previewName.Parent = previewPanel

previewMeta = Instance.new("TextLabel")
previewMeta.Size = previewStacked and UDim2.new(1,-112,0,16) or UDim2.new(1,-20,0,18)
previewMeta.Position = previewStacked and UDim2.new(0,106,0,63) or UDim2.new(0,10,0,isMobile and 180 or 230)
previewMeta.BackgroundTransparency = 1
previewMeta.Text = "—"
previewMeta.TextColor3 = Color3.fromRGB(112,112,112)
previewMeta.Font = Enum.Font.GothamMedium
previewMeta.TextSize = previewStacked and 7 or (isMobile and 7 or 9)
previewMeta.TextXAlignment = Enum.TextXAlignment.Left
previewMeta.TextTruncate = Enum.TextTruncate.AtEnd
previewMeta.ZIndex = 13
previewMeta.Parent = previewPanel

previewStats = Instance.new("TextLabel")
previewStats.Size = previewStacked and UDim2.new(1,-112,0,34) or UDim2.new(1,-20,0,isMobile and 42 or 52)
previewStats.Position = previewStacked and UDim2.new(0,106,0,80) or UDim2.new(0,10,0,isMobile and 198 or 234)
previewStats.BackgroundTransparency = 1
previewStats.Text = ""
previewStats.Visible = false
previewStats.TextColor3 = Color3.fromRGB(160,160,160)
previewStats.Font = Enum.Font.GothamMedium
previewStats.TextSize = previewStacked and 7 or (isMobile and 7 or 9)
previewStats.TextXAlignment = Enum.TextXAlignment.Left
previewStats.TextYAlignment = Enum.TextYAlignment.Top
previewStats.TextWrapped = true
previewStats.ZIndex = 13
previewStats.Parent = previewPanel

local actionKeyLbl
local actionUseBtn = Instance.new("TextButton")
actionUseBtn.Name = "UseEmoteButton"
if previewStacked then
    actionUseBtn.Size = UDim2.new(1,-112,0,30)
    actionUseBtn.Position = UDim2.new(0,106,1,-36)
else
    actionUseBtn.Size = UDim2.new(1,-64,0,38)
    actionUseBtn.Position = UDim2.new(0,10,1,-48)
end
actionUseBtn.BackgroundColor3 = currentTheme.accent
actionUseBtn.BackgroundTransparency = 0.22
actionUseBtn.Text = isES and "USAR EMOTE" or "USE EMOTE"
actionUseBtn.Visible = false
actionUseBtn.TextColor3 = Color3.fromRGB(255,255,255)
actionUseBtn.Font = Enum.Font.GothamBold
actionUseBtn.TextSize = previewStacked and 10 or (isMobile and 9 or 12)
actionUseBtn.AutoButtonColor = false
actionUseBtn.ZIndex = 14
actionUseBtn.Parent = previewPanel
actionUseBtn.Visible = false
Instance.new("UICorner",actionUseBtn).CornerRadius = UDim.new(0,9)
local useStroke = Instance.new("UIStroke")
useStroke.Color = Color3.fromRGB(245,245,245)
useStroke.Thickness = 1
useStroke.Transparency = 0.12
useStroke.Parent = actionUseBtn

if not previewStacked then
    actionKeyLbl = Instance.new("TextLabel")
    actionKeyLbl.Size = UDim2.new(0,38,0,38)
    actionKeyLbl.Position = UDim2.new(1,-48,1,-48)
    actionKeyLbl.BackgroundColor3 = currentTheme.tertiary
    actionKeyLbl.BackgroundTransparency = 0.40
    actionKeyLbl.Text = ""
    actionKeyLbl.Visible = false
    actionKeyLbl.TextColor3 = Color3.fromRGB(230,230,230)
    actionKeyLbl.Font = Enum.Font.GothamBlack
    actionKeyLbl.TextSize = 11
    actionKeyLbl.ZIndex = 14
    actionKeyLbl.Parent = previewPanel
    Instance.new("UICorner",actionKeyLbl).CornerRadius = UDim.new(0,6)
    local actionKeyStroke = Instance.new("UIStroke")
    actionKeyStroke.Color = Color3.fromRGB(58,58,58)
    actionKeyStroke.Thickness = 1
    actionKeyStroke.Parent = actionKeyLbl
end

if mobileWide then
    previewHeader.Size = UDim2.new(1,-20,0,16)
    previewHeader.TextSize = 7
    previewRule.Position = UDim2.new(0,10,0,27)
    previewImage.Size = UDim2.new(1,-20,0,54)
    previewImage.Position = UDim2.new(0,10,0,34)
    previewName.Size = UDim2.new(1,-20,0,18)
    previewName.Position = UDim2.new(0,10,0,92)
    previewName.TextSize = 8
    previewMeta.Size = UDim2.new(1,-20,0,13)
    previewMeta.Position = UDim2.new(0,10,0,110)
    previewMeta.TextSize = 6
    previewStats.Size = UDim2.new(1,-20,0,20)
    previewStats.Position = UDim2.new(0,10,0,124)
    previewStats.TextSize = 6
    actionUseBtn.Size = UDim2.new(1,-20,0,25)
    actionUseBtn.Position = UDim2.new(0,10,1,-31)
    actionUseBtn.TextSize = 7
    if actionKeyLbl then
        actionKeyLbl.Size = UDim2.new(0,25,0,25)
        actionKeyLbl.Position = UDim2.new(1,-35,1,-31)
        actionKeyLbl.TextSize = 8
    end
end

local function UpdateActionButtonLayout(kb)
    if not actionKeyLbl then return end
    local hasKey = kb and kb.key and tostring(kb.key) ~= ""
    actionKeyLbl.Visible = hasKey and true or false
    actionKeyLbl.Text = hasKey and tostring(kb.key) or ""
    if mobileWide then
        actionUseBtn.Size = UDim2.new(1,hasKey and -48 or -20,0,25)
    else
        actionUseBtn.Size = UDim2.new(1,hasKey and -64 or -20,0,38)
    end
end

bottomBar = Instance.new("Frame")
bottomBar.Name = "HXBottomStatus"
bottomBar.Size = UDim2.new(0,0,0,0)
bottomBar.Position = UDim2.new(0,0,1,0)
bottomBar.BackgroundTransparency = 1
bottomBar.Visible = false
bottomBar.Parent = content

actionSelectedLbl = Instance.new("TextLabel")
actionSelectedLbl.Name = "SelectedEmoteLabel"
actionSelectedLbl.Size = UDim2.new(0,0,0,0)
actionSelectedLbl.BackgroundTransparency = 1
actionSelectedLbl.Text = ""
actionSelectedLbl.Visible = false
actionSelectedLbl.Parent = bottomBar

UpdateSelectedEmoteUI = function(emote,newStroke,newContainer)
    if selectedCardStroke and selectedCardStroke ~= newStroke and selectedCardStroke.Parent then
        selectedCardStroke.Color = Color3.fromRGB(58,58,58)
        selectedCardStroke.Thickness = 1
    end
    if selectedCardContainer and selectedCardContainer ~= newContainer and selectedCardContainer.Parent then
        selectedCardContainer.BackgroundColor3 = currentTheme.secondary
        selectedCardContainer.BackgroundTransparency = 0.62
        HXStyleChamfer(selectedCardContainer,{
            coreTransparency=0.62, glowTransparency=0.98,
            cornerCoreTransparency=0.58, cornerGlowTransparency=0.96,
            cornerCoreThickness=0.95, cornerGlowThickness=2.2,
            color=Color3.fromRGB(190,190,190)
        })
    end

    selectedEmote = emote
    selectedCardStroke = newStroke or selectedCardStroke
    selectedCardContainer = newContainer or selectedCardContainer

    if newStroke and newStroke.Parent then
        TweenService:Create(newStroke,TweenInfo.new(0.14),{Color=Color3.fromRGB(255,255,255),Thickness=1}):Play()
    end
    if newContainer and newContainer.Parent then
        TweenService:Create(newContainer,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(24,24,24),BackgroundTransparency=0.30}):Play()
        -- Selected emote: the complete panel is brighter; corners only get a little extra light.
        -- Thickness remains identical to normal cards so selection never looks larger/fatter.
        HXStyleChamfer(newContainer,{
            coreTransparency=0.08, glowTransparency=0.70,
            cornerCoreTransparency=0.00, cornerGlowTransparency=0.48,
            cornerCoreThickness=0.95, cornerGlowThickness=2.2,
            color=Color3.fromRGB(255,255,255)
        })
    end

    if not emote then
        if previewImage then previewImage.Image = "" end
        if previewName then previewName.Text = isES and "SELECCIONA UN EMOTE" or "SELECT AN EMOTE" end
        if previewMeta then previewMeta.Text = "" end
        if previewStats then previewStats.Text = "" end
        actionSelectedLbl.Text = ""
        UpdateActionButtonLayout(nil)
        return
    end

    if previewImage and previewName and previewMeta then
        if emote.isAnimationPack then
            local packId = tostring(emote.id):gsub("anim_","")
            previewImage.Image = "rbxthumb://type=BundleThumbnail&id="..packId.."&w=420&h=420"
        else
            previewImage.Image = "rbxthumb://type=Asset&id="..tostring(emote.id).."&w=420&h=420"
        end
        previewName.Text = string.upper(LocalizeEmoteName(emote.name))
        previewMeta.Text = emote.isAnimationPack and L.animationPack or ("ID  "..tostring(emote.id))
    end

    local kb = GetKeybind(emote.id)
    if previewStats then previewStats.Text = "" end
    actionSelectedLbl.Text = ""
    UpdateActionButtonLayout(kb)
end

actionUseBtn.MouseEnter:Connect(function()
    TweenService:Create(actionUseBtn,TweenInfo.new(0.16),{BackgroundColor3=Color3.fromRGB(28,28,28),BackgroundTransparency=0.20,TextColor3=Color3.fromRGB(255,255,255)}):Play()
    TweenService:Create(useStroke,TweenInfo.new(0.16),{Transparency=0,Color=Color3.fromRGB(255,255,255)}):Play()
end)
actionUseBtn.MouseLeave:Connect(function()
    TweenService:Create(actionUseBtn,TweenInfo.new(0.16),{BackgroundColor3=currentTheme.tertiary,BackgroundTransparency=0.38,TextColor3=Color3.fromRGB(255,255,255)}):Play()
    TweenService:Create(useStroke,TweenInfo.new(0.16),{Transparency=0.12,Color=Color3.fromRGB(245,245,245)}):Play()
end)
actionUseBtn.MouseButton1Click:Connect(function()
    if not selectedEmote then
        Notify(isES and "Selecciona un emote" or "Select an emote","")
        return
    end
    if FriendData and FriendData.currentSyncPartner then FriendData.currentSyncPartner = nil end
    if selectedEmote.isUGC then
        task.spawn(function() PlayEmote(ResolveUGCAnimationId(selectedEmote) or selectedEmote.id, selectedEmote.name) end)
    else
        PlayEmote(selectedEmote.id,selectedEmote.name)
    end
end)
end

if previewPanel then
    pcall(function() previewPanel:Destroy() end)
    previewPanel = nil
    previewImage = nil
    previewName = nil
    previewMeta = nil
    previewStats = nil
end

local scrollY = (titleH + searchH + 14)
scroll = Instance.new("ScrollingFrame")
scroll.ClipsDescendants = true
scroll.Size = UDim2.new(1,-16,1,-(scrollY+pageH+14))
scroll.Position = UDim2.new(0,8,0,scrollY)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = isMobile and 2 or 3
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarImageColor3 = currentTheme.stroke
scroll.ZIndex = 1
scroll.Parent = content
RegisterTheme(scroll, "ScrollBarImageColor3", "stroke")


local function CalcLayout()
    local PAD = isMobile and 7 or 8
    local w = math.max(scroll.AbsoluteSize.X, 1)
    local target = isMobile and TARGET_MOBILE_CARD or TARGET_PC_CARD
    local minCols = isMobile and 2 or 3
    local maxCols = isMobile and 5 or 7
    cols = math.clamp(math.floor((w + PAD) / (target + PAD)), minCols, maxCols)
    if currentTab == "animations" and w < (isMobile and 360 or 620) then
        cols = math.max(minCols, cols - 1)
    end
    currentCardSize = math.max(isMobile and 54 or 68, (w - PAD * (cols - 1)) / cols)
    local infoH = isMobile and 46 or 40
    local kbH = ((not isMobile) or _isPlaylistMode) and (isMobile and 24 or 26) or 0
    local cardTotalH = currentCardSize + infoH + kbH
    -- Keep a second row populated instead of limiting the page to a single top row.
    local rowsVisible = math.max(2, math.floor(scroll.AbsoluteSize.Y / (cardTotalH + PAD)))
    if currentTab == "ugc" and _ugcPageMode then
        -- AFEM marketplace pages are already bounded (21 items). Show the whole
        -- server page in the scrolling grid and let the arrows request server pages.
        perPage = math.max(1, #filtered)
        pages = 1
        page = 1
    else
        perPage = math.max(cols * 2, cols * rowsVisible)
        pages = math.max(1, math.ceil(#filtered / perPage))
        page = math.clamp(page,1,pages)
    end
end

local function UpdatePageUI()
    if currentTab == "ugc" and _ugcPageMode then
        pageNum.Text = _ugcHasNext and (tostring(_ugcCurrentPage) .. "/…") or (tostring(_ugcCurrentPage) .. "/" .. tostring(_ugcCurrentPage))
        prevBtn.Visible = _ugcHasPrevious
        nextBtn.Visible = _ugcHasNext
    else
        pageNum.Text = page .. "/" .. pages
        local show = pages > 1
        prevBtn.Visible = show
        nextBtn.Visible = show
    end

	if prevBtn:FindFirstChild("ChevronIcon") then
		for _, c in ipairs(prevBtn.ChevronIcon:GetChildren()) do c.BackgroundColor3 = Color3.new(1, 1, 1) end
	end
	if nextBtn:FindFirstChild("ChevronIcon") then
		for _, c in ipairs(nextBtn.ChevronIcon:GetChildren()) do c.BackgroundColor3 = Color3.new(1, 1, 1) end
	end

	pageBar.Visible = scroll.Visible

	local empty = #filtered == 0 and currentTab ~= "settings"
	emptyLbl.Visible = empty
	if empty then
		local q = search and search.Text ~= "" or false
		if q then
			emptyLbl.Text = L.noSearch or "No results found"
		elseif currentTab == "favorites" then
			emptyLbl.Text = L.noFav
		elseif currentTab == "recent" then
			emptyLbl.Text = L.noRecent
		else
			emptyLbl.Text = L.noSearch or "No results found"
		end
	end
end

local function _MarkBadEmote(emoteId)
	local key = tostring(emoteId)
	if _badEmotes[key] then return end
	_badEmotes[key] = true
	for i = #Emotes, 1, -1 do
		if tostring(Emotes[i].id) == key then table.remove(Emotes, i); break end
	end
	EmotesById[tonumber(key)] = nil
	for i = #filtered, 1, -1 do
		if tostring(filtered[i].id) == key then table.remove(filtered, i); break end
	end
	if not _refreshPending then
		_refreshPending = true
		task.delay(0.8, function()
			_refreshPending = false
			if currentTab ~= "settings" and currentTab ~= "friends" and currentTab ~= "keybinds" then
				page = math.clamp(page, 1, math.max(1, math.ceil(#filtered / perPage)))
				Refresh(false)
			end
		end)
	end
end

local function ClearCards()
	for _, c in pairs(cards) do
		if c and c.Parent then
			for _, desc in ipairs(c:GetDescendants()) do
				if desc:IsA("TweenBase") then pcall(function() desc:Cancel() end) end
			end
			c:Destroy()
		end
	end
	cards = {}
	for i = #_textGrads, 1, -1 do
		local g = _textGrads[i]
		if not (g and g.Parent) then
			table.remove(_textGrads, i)
		end
	end
end


local function ShowKeybindDialog(emoteId, emote, isEdit)
    local existing = main:FindFirstChild("HXKeybindOverlay")
    if existing then existing:Destroy() end

    local overlay = Instance.new("TextButton")
    overlay.Name = "HXKeybindOverlay"
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.new(0,0,0)
    overlay.BackgroundTransparency = 0.36
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.ZIndex = 200
    overlay.Parent = main

    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0,0,0,0)
    dialog.Position = UDim2.fromScale(0.5,0.5)
    dialog.AnchorPoint = Vector2.new(0.5,0.5)
    dialog.BackgroundColor3 = currentTheme.secondary
    dialog.BackgroundTransparency = 0.26
    dialog.BorderSizePixel = 0
    dialog.ClipsDescendants = true
    dialog.ZIndex = 201
    dialog.Parent = overlay
    Instance.new("UICorner",dialog).CornerRadius = UDim.new(0,8)
    local dStroke = Instance.new("UIStroke")
    dStroke.Color = Color3.fromRGB(235,235,235)
    dStroke.Thickness = 1
    dStroke.Parent = dialog

    local rail = Instance.new("Frame")
    rail.Size = UDim2.new(0,4,0,46)
    rail.Position = UDim2.new(0,14,0,14)
    rail.BackgroundColor3 = Color3.fromRGB(255,255,255)
    rail.BorderSizePixel = 0
    rail.ZIndex = 202
    rail.Parent = dialog

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1,-44,0,46)
    titleLbl.Position = UDim2.new(0,28,0,12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = isEdit and (isES and "EDITAR BINDING" or "EDIT BINDING") or (isES and "NUEVO BINDING" or "NEW BINDING")
    titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = isMobile and 14 or 16
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 202
    titleLbl.Parent = dialog

    local emoteLbl = Instance.new("TextLabel")
    emoteLbl.Size = UDim2.new(1,-28,0,22)
    emoteLbl.Position = UDim2.new(0,14,0,68)
    emoteLbl.BackgroundTransparency = 1
    emoteLbl.Text = string.upper(LocalizeEmoteName(emote.name))
    emoteLbl.TextColor3 = Color3.fromRGB(135,135,135)
    emoteLbl.Font = Enum.Font.GothamBold
    emoteLbl.TextSize = isMobile and 9 or 10
    emoteLbl.TextXAlignment = Enum.TextXAlignment.Left
    emoteLbl.ZIndex = 202
    emoteLbl.Parent = dialog

    local recordedKey = isEdit and (GetKeybind(emoteId) and GetKeybind(emoteId).key or nil) or nil
    local isRecording = false
    local recordConn, recordTween

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(1,-28,0,54)
    keyBtn.Position = UDim2.new(0,14,0,94)
    keyBtn.BackgroundColor3 = currentTheme.tertiary
    keyBtn.BackgroundTransparency = 0.38
    keyBtn.Text = recordedKey and ("[ "..recordedKey.." ]") or (isES and "PRESIONA UNA TECLA..." or "PRESS A KEY...")
    keyBtn.TextColor3 = recordedKey and Color3.fromRGB(255,255,255) or Color3.fromRGB(165,165,165)
    keyBtn.Font = Enum.Font.GothamBlack
    keyBtn.TextSize = isMobile and 12 or 14
    keyBtn.AutoButtonColor = false
    keyBtn.ZIndex = 202
    keyBtn.Parent = dialog
    Instance.new("UICorner",keyBtn).CornerRadius = UDim.new(0,6)
    local kbStroke = Instance.new("UIStroke")
    kbStroke.Color = Color3.fromRGB(58,58,58)
    kbStroke.Thickness = 1
    kbStroke.Parent = keyBtn

    local helper = Instance.new("TextLabel")
    helper.Size = UDim2.new(1,-28,0,34)
    helper.Position = UDim2.new(0,14,0,156)
    helper.BackgroundTransparency = 1
    helper.Text = isES and "BACKSPACE PARA ELIMINAR   ·   ESC PARA CANCELAR" or "BACKSPACE TO REMOVE   ·   ESC TO CANCEL"
    helper.TextColor3 = Color3.fromRGB(105,105,105)
    helper.Font = Enum.Font.GothamMedium
    helper.TextSize = isMobile and 8 or 9
    helper.TextWrapped = true
    helper.ZIndex = 202
    helper.Parent = dialog

    local function stopRecording()
        isRecording = false
        if recordConn then pcall(function() recordConn:Disconnect() end); recordConn=nil end
        if recordTween then pcall(function() recordTween:Cancel() end); recordTween=nil end
        kbStroke.Transparency = 0
        kbStroke.Color = Color3.fromRGB(58,58,58)
    end

    local function closeDialog()
        stopRecording()
        TweenService:Create(dialog,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,0,0,0)}):Play()
        task.delay(0.16,function() if overlay and overlay.Parent then overlay:Destroy() end end)
    end

    local function beginRecording()
        if isRecording then return end
        isRecording = true
        keyBtn.Text = isES and "PRESIONA UNA TECLA..." or "PRESS A KEY..."
        keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
        kbStroke.Color = Color3.fromRGB(235,235,235)
        recordTween = TweenService:Create(kbStroke,TweenInfo.new(0.28,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=0.55})
        recordTween:Play()
        recordConn = UserInputService.InputBegan:Connect(function(inp,gp)
            if gp or inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local keyName = inp.KeyCode.Name
            if keyName == "Escape" then
                closeDialog()
                return
            elseif keyName == "Backspace" then
                RemoveKeybind(emoteId)
                if currentTab == "keybinds" and RefreshKeybindsPanel then RefreshKeybindsPanel() end
                closeDialog()
                return
            end
            recordedKey = keyName
            stopRecording()
            keyBtn.Text = "[ "..recordedKey.." ]"
            keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
        end)
    end

    keyBtn.MouseButton1Click:Connect(beginRecording)

    local removeBtn = Instance.new("TextButton")
    removeBtn.Size = UDim2.new(0.36,-4,0,36)
    removeBtn.Position = UDim2.new(0,14,1,-50)
    removeBtn.BackgroundColor3 = currentTheme.tertiary
    removeBtn.BackgroundTransparency = 0.34
    removeBtn.Text = isES and "ELIMINAR" or "REMOVE"
    removeBtn.TextColor3 = Color3.fromRGB(175,175,175)
    removeBtn.Font = Enum.Font.GothamBold
    removeBtn.TextSize = isMobile and 9 or 10
    removeBtn.AutoButtonColor = false
    removeBtn.ZIndex = 202
    removeBtn.Parent = dialog
    Instance.new("UICorner",removeBtn).CornerRadius = UDim.new(0,9)

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.64,-18,0,36)
    saveBtn.Position = UDim2.new(0.36,10,1,-50)
    saveBtn.BackgroundColor3 = currentTheme.accent
    saveBtn.BackgroundTransparency = 0.20
    saveBtn.Text = isES and "GUARDAR" or "SAVE"
    saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
    saveBtn.Font = Enum.Font.GothamBlack
    saveBtn.TextSize = isMobile and 10 or 11
    saveBtn.AutoButtonColor = false
    saveBtn.ZIndex = 202
    saveBtn.Parent = dialog
    Instance.new("UICorner",saveBtn).CornerRadius = UDim.new(0,9)
    local saveStroke = Instance.new("UIStroke")
    saveStroke.Color = Color3.fromRGB(225,225,225)
    saveStroke.Thickness = 1
    saveStroke.Transparency = 0.18
    saveStroke.Parent = saveBtn

    removeBtn.MouseButton1Click:Connect(function()
        RemoveKeybind(emoteId)
        if currentTab == "keybinds" and RefreshKeybindsPanel then RefreshKeybindsPanel() end
        closeDialog()
    end)
    saveBtn.MouseButton1Click:Connect(function()
        if not recordedKey then beginRecording(); return end
        SetKeybind(emoteId, emote.name, recordedKey)
        if currentTab == "keybinds" and RefreshKeybindsPanel then RefreshKeybindsPanel() end
        closeDialog()
        Refresh(false)
    end)
    overlay.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.Escape then closeDialog() end
    end)

    local target = isMobile and UDim2.new(0,300,0,250) or UDim2.new(0,390,0,260)
    TweenService:Create(dialog,TweenInfo.new(0.22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=target}):Play()
    task.delay(0.12,beginRecording)
end

RefreshKeybindsPanel = function()
	for _, c in ipairs(keybindsPanel:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local hasAny = false
	for emoteId, kb in pairs(KeybindsSet) do
		if tonumber(emoteId) then
			hasAny = true
			local emote = EmotesById[emoteId]
		local emoteName = emote and LocalizeEmoteName(emote.name) or ("Emote #"..emoteId)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = currentTheme.secondary
		row.BorderSizePixel = 0
		row.ZIndex = 6
		row.Parent = keybindsPanel
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
		local thumb = Instance.new("ImageLabel")
		thumb.Size = UDim2.new(0, 44, 0, 44)
		thumb.Position = UDim2.new(0, 6, 0.5, -22)
		thumb.BackgroundTransparency = 1
		thumb.Image = "rbxthumb://type=Asset&id="..emoteId.."&w=420&h=420"
		thumb.ImageColor3 = Color3.fromRGB(255,255,255)
		thumb.ZIndex = 7
		thumb.Parent = row
		Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -130, 0, 20)
		nameLbl.Position = UDim2.new(0, 56, 0, 8)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = emoteName
		nameLbl.TextColor3 = currentTheme.text
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.ZIndex = 7
		nameLbl.Parent = row
		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(0, 38, 0, 24)
		keyLbl.Position = UDim2.new(0, 56, 0, 28)
		keyLbl.BackgroundColor3 = currentTheme.accent
		keyLbl.Text = kb.key
		keyLbl.TextColor3 = currentTheme.primary
		keyLbl.Font = Enum.Font.GothamBold
		keyLbl.TextSize = 12
		keyLbl.ZIndex = 7
		keyLbl.Parent = row
		Instance.new("UICorner", keyLbl).CornerRadius = UDim.new(0, 6)
		local customName = Instance.new("TextLabel")
		customName.Size = UDim2.new(1, -110, 0, 14)
		customName.Position = UDim2.new(0, 100, 0, 30)
		customName.BackgroundTransparency = 1
		customName.Text = kb.name ~= "" and kb.name or ""
		customName.TextColor3 = currentTheme.textDim
		customName.Font = Enum.Font.Gotham
		customName.TextSize = 11
		customName.TextXAlignment = Enum.TextXAlignment.Left
		customName.ZIndex = 7
		customName.Parent = row
		local delBtn = Instance.new("ImageButton")
		delBtn.Size = UDim2.new(0, 42, 0, 42)
		delBtn.Position = UDim2.new(1, -40, 0.5, -16)
		delBtn.BackgroundColor3 = Color3.fromRGB(82, 82, 82)
		delBtn.Image = ResolveAssetImage(Icons.KeybindRemove)
		delBtn.ImageColor3 = Color3.new(1,1,1)
		delBtn.ZIndex = 7
		delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(1, 0)
		delBtn.MouseButton1Click:Connect(function()
			RemoveKeybind(emoteId)
			RefreshKeybindsPanel()
		end)
		end
	end
	if not hasAny then
		local emptyLbl2 = Instance.new("TextLabel")
		emptyLbl2.Size = UDim2.new(1, 0, 0, 60)
		emptyLbl2.BackgroundTransparency = 1
		emptyLbl2.Text = L.kbEmpty
		emptyLbl2.TextColor3 = currentTheme.textDim
		emptyLbl2.Font = Enum.Font.Gotham
		emptyLbl2.TextSize = 14
		emptyLbl2.ZIndex = 6
		emptyLbl2.Parent = keybindsPanel
	end
end


local function MakeCard(emote, ci, animate)
    local CARD = currentCardSize
    local PAD = isMobile and 7 or 8
    local INFO_H = isMobile and 46 or 40
    local KB_H = ((not isMobile) or _isPlaylistMode) and (isMobile and 24 or 26) or 0
    local TOTAL_H = CARD + INFO_H + KB_H

    local cardContainer = Instance.new("Frame")
    cardContainer.Name = "EmoteCard"
    cardContainer.Size = UDim2.new(0,CARD,0,TOTAL_H)
    cardContainer.BackgroundColor3 = currentTheme.secondary
    cardContainer.BackgroundTransparency = 0.62
    cardContainer.BorderSizePixel = 0
    cardContainer.ZIndex = 2
    cardContainer.Parent = scroll
    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(58,58,58)
    containerStroke.Thickness = 1
    containerStroke.Transparency = 1
    containerStroke.Parent = cardContainer
    HXApplyChamfer(cardContainer, {transparent=false, cut=isMobile and 6 or 8, thickness=0.95, glowThickness=2.2, coreTransparency=0.62, glowTransparency=0.98})

    local col = ci % cols
    local row = math.floor(ci / cols)
    local targetX = col * (CARD + PAD)
    local targetY = PAD + row * (TOTAL_H + PAD)
    cardContainer.Position = UDim2.new(0,targetX,0,animate and targetY+14 or targetY)
    if animate then
        cardContainer.BackgroundTransparency = 1
        task.delay(ci*0.012,function()
            if cardContainer.Parent then
                TweenService:Create(cardContainer,TweenInfo.new(0.20,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
                    Position=UDim2.new(0,targetX,0,targetY),
                    BackgroundTransparency=0.62
                }):Play()
            end
        end)
    end

    local visual = Instance.new("ImageButton")
    visual.Name = "EmotePreview"
    visual.Size = UDim2.new(1,-10,0,CARD-10)
    visual.Position = UDim2.new(0,5,0,5+KB_H)
    visual.BackgroundColor3 = currentTheme.tertiary
    visual.BackgroundTransparency = 0.42
    visual.AutoButtonColor = false
    visual.ScaleType = Enum.ScaleType.Fit
    visual.ImageColor3 = Color3.fromRGB(255,255,255)
    visual.ImageTransparency = animate and 1 or 0
    visual.ZIndex = 3
    visual.Parent = cardContainer
    HXApplyChamfer(visual, {transparent=false, cut=isMobile and 5 or 6, thickness=0.85, glowThickness=1.8, coreTransparency=0.68, glowTransparency=1})

    if emote.isAnimationPack then
        local packId = tostring(emote.id):gsub("anim_", "")
        visual.Image = "rbxthumb://type=BundleThumbnail&id=" .. packId .. "&w=420&h=420"
    else
        visual.Image = "rbxthumb://type=Asset&id=" .. tostring(emote.id) .. "&w=420&h=420"
    end

    if animate then
        task.delay(ci*0.012,function()
            if visual.Parent then
                TweenService:Create(visual,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{ImageTransparency=0}):Play()
            end
        end)
    end

    local visualStroke = Instance.new("UIStroke")
    visualStroke.Color = Color3.fromRGB(48,48,48)
    visualStroke.Thickness = 1
    visualStroke.Parent = visual

    local previewShade = Instance.new("Frame")
    previewShade.Size = UDim2.new(1,0,0,math.max(28,math.floor(CARD*0.30)))
    previewShade.Position = UDim2.new(0,0,1,-math.max(28,math.floor(CARD*0.30)))
    previewShade.BackgroundColor3 = currentTheme.primary
    previewShade.BackgroundTransparency = 0.24
    previewShade.BorderSizePixel = 0
    previewShade.ZIndex = 4
    previewShade.Parent = visual
    Instance.new("UICorner",previewShade).CornerRadius = UDim.new(0,5)
    local shadeGrad = Instance.new("UIGradient")
    shadeGrad.Rotation = 90
    shadeGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(1,0.08)
    }
    shadeGrad.Parent = previewShade

    local previewTag = Instance.new("TextLabel")
    previewTag.Size = UDim2.new(0,isMobile and 42 or 48,0,16)
    previewTag.Position = UDim2.new(0,7,0,7)
    previewTag.BackgroundColor3 = currentTheme.secondary
    previewTag.BackgroundTransparency = 0.30
    previewTag.BackgroundTransparency = 0.12
    previewTag.Text = ""
    previewTag.Visible = false
    previewTag.TextColor3 = Color3.fromRGB(225,225,225)
    previewTag.Font = Enum.Font.GothamBlack
    previewTag.TextSize = isMobile and 7 or 8
    previewTag.ZIndex = 6
    previewTag.Parent = visual
    Instance.new("UICorner",previewTag).CornerRadius = UDim.new(0,4)
    local tagStroke = Instance.new("UIStroke")
    tagStroke.Color = Color3.fromRGB(78,78,78)
    tagStroke.Thickness = 1
    tagStroke.Transparency = 0.25
    tagStroke.Parent = previewTag

    local isFav = IsFavorite(emote.id)
    local favBtn = Instance.new("ImageButton")
    favBtn.Size = UDim2.new(0,isMobile and 20 or 22,0,isMobile and 20 or 22)
    favBtn.Position = UDim2.new(1,-(isMobile and 29 or 33),0,7+KB_H)
    favBtn.BackgroundTransparency = 1
    favBtn.Image = ResolveAssetImage(isFav and Icons.FavoriteFull or Icons.FavoriteEmpty)
    favBtn.ImageColor3 = Color3.fromRGB(255,255,255)
    favBtn.ScaleType = Enum.ScaleType.Fit
    favBtn.AutoButtonColor = false
    favBtn.ZIndex = 9
    favBtn.Parent = cardContainer
    favBtn.Visible = not emote.isAnimationPack

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1,-12,0,isMobile and 24 or 22)
    nameLbl.Position = UDim2.new(0,7,1,-INFO_H+3)
    nameLbl.BackgroundTransparency = 1
    local displayName = LocalizeEmoteName(emote.name)
    nameLbl.Text = string.upper(#displayName>20 and displayName:sub(1,19).."…" or displayName)
    nameLbl.TextColor3 = Color3.fromRGB(245,245,245)
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = isMobile and 10 or 10
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex = 5
    nameLbl.Parent = cardContainer

    local metaLbl = Instance.new("TextLabel")
    metaLbl.Size = UDim2.new(1,-12,0,14)
    metaLbl.Position = UDim2.new(0,7,1,-17)
    metaLbl.BackgroundTransparency = 1
    metaLbl.Text = emote.isAnimationPack and L.animationPack or (emote.isUGC and "ROBLOX" or L.emoteType)
    metaLbl.TextColor3 = Color3.fromRGB(100,100,100)
    metaLbl.Font = Enum.Font.GothamMedium
    metaLbl.TextSize = isMobile and 7 or 8
    metaLbl.TextXAlignment = Enum.TextXAlignment.Left
    metaLbl.TextTruncate = Enum.TextTruncate.AtEnd
    metaLbl.ZIndex = 5
    metaLbl.Parent = cardContainer

    local kbHasBinding = GetKeybind(emote.id) ~= nil
    if (not isMobile) or _isPlaylistMode then
        local kbBtn = Instance.new("TextButton")
        kbBtn.Size = UDim2.new(1,-10,0,KB_H-4)
        kbBtn.Position = UDim2.new(0,5,0,3)
        kbBtn.BackgroundColor3 = _isPlaylistMode and Color3.fromRGB(16,16,16) or Color3.fromRGB(12,12,12)
        kbBtn.BackgroundTransparency = 1
        kbBtn.Text = _isPlaylistMode and (_selectedEmotesForPlaylist[tostring(emote.id)] and (isES and "LISTO" or "DONE") or L.selectEmote) or ((GetKeybind(emote.id) and GetKeybind(emote.id).key) and tostring(GetKeybind(emote.id).key) or (isES and "ASIGNAR" or "BIND"))
        kbBtn.TextColor3 = _isPlaylistMode and Color3.fromRGB(225,225,225) or Color3.fromRGB(165,165,165)
        kbBtn.Font = Enum.Font.GothamBold
        kbBtn.TextSize = isMobile and 8 or 9
        kbBtn.AutoButtonColor = false
        kbBtn.ZIndex = 6
        kbBtn.Parent = cardContainer
        local kst = Instance.new("UIStroke")
        kst.Color = Color3.fromRGB(52,52,52)
        kst.Thickness = 1
        kst.Parent = kbBtn
        HXApplyChamfer(kbBtn, {transparent=true, cut=isMobile and 4 or 5, thickness=0.8, glowThickness=1.6, coreTransparency=0.64, glowTransparency=1})
        kbBtn.MouseButton1Click:Connect(function()
            if _isPlaylistMode then
                local k = tostring(emote.id)
                _selectedEmotesForPlaylist[k] = not _selectedEmotesForPlaylist[k]
                kbBtn.Text = _selectedEmotesForPlaylist[k] and (isES and "LISTO" or "DONE") or L.selectEmote
                kbBtn.BackgroundColor3 = _selectedEmotesForPlaylist[k] and Color3.fromRGB(36,36,36) or Color3.fromRGB(16,16,16)
                kbBtn.TextColor3 = Color3.fromRGB(235,235,235)
                return
            end
            ShowKeybindDialog(emote.id, emote, kbHasBinding)
        end)
    end

    favBtn.MouseEnter:Connect(function()
        TweenService:Create(favBtn,TweenInfo.new(0.14),{ImageTransparency=0.12}):Play()
    end)
    favBtn.MouseLeave:Connect(function()
        TweenService:Create(favBtn,TweenInfo.new(0.14),{ImageTransparency=0}):Play()
    end)
    favBtn.MouseButton1Click:Connect(function()
        isFav = ToggleFavorite(emote.id)
        favBtn.Image = ResolveAssetImage(isFav and Icons.FavoriteFull or Icons.FavoriteEmpty)
        favBtn.ImageColor3 = Color3.fromRGB(255,255,255)
        if currentTab == "favorites" and not isFav then
            task.delay(0.12,function() if currentTab=="favorites" then UpdateTabData() end end)
        end
    end)

    visual.MouseEnter:Connect(function()
        TweenService:Create(visual,TweenInfo.new(0.16),{BackgroundColor3=Color3.fromRGB(22,22,22),Position=UDim2.new(0,5,0,3+KB_H)}):Play()
        TweenService:Create(visualStroke,TweenInfo.new(0.16),{Color=Color3.fromRGB(245,245,245),Thickness=1.35}):Play()
        TweenService:Create(containerStroke,TweenInfo.new(0.16),{Color=Color3.fromRGB(180,180,180)}):Play()
    end)
    visual.MouseLeave:Connect(function()
        TweenService:Create(visual,TweenInfo.new(0.16),{BackgroundColor3=Color3.fromRGB(13,13,13),Position=UDim2.new(0,5,0,5+KB_H)}):Play()
        TweenService:Create(visualStroke,TweenInfo.new(0.16),{Color=Color3.fromRGB(48,48,48),Thickness=1}):Play()
        TweenService:Create(containerStroke,TweenInfo.new(0.16),{Color=(selectedEmote == emote) and Color3.fromRGB(255,255,255) or Color3.fromRGB(58,58,58)}):Play()
        if selectedEmote == emote then
            HXStyleChamfer(cardContainer,{coreTransparency=0.08,glowTransparency=0.70,cornerCoreTransparency=0.00,cornerGlowTransparency=0.48,cornerCoreThickness=0.95,cornerGlowThickness=2.2,color=Color3.fromRGB(255,255,255)})
        else
            HXStyleChamfer(cardContainer,{coreTransparency=0.62,glowTransparency=0.98,cornerCoreTransparency=0.58,cornerGlowTransparency=0.96,cornerCoreThickness=0.95,cornerGlowThickness=2.2,color=Color3.fromRGB(190,190,190)})
        end
    end)

    visual.MouseButton1Click:Connect(function()
        UpdateSelectedEmoteUI(emote, containerStroke, cardContainer)
        TweenService:Create(containerStroke,TweenInfo.new(0.12),{Color=Color3.fromRGB(255,255,255),Thickness=1}):Play()
        TweenService:Create(cardContainer,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(27,27,27),BackgroundTransparency=0.24}):Play()
        HXStyleChamfer(cardContainer,{coreTransparency=0.02,glowTransparency=0.58,cornerCoreTransparency=0.00,cornerGlowTransparency=0.30,cornerCoreThickness=0.95,cornerGlowThickness=2.2,color=Color3.fromRGB(255,255,255)})
        task.delay(0.24,function()
            if cardContainer.Parent then
                TweenService:Create(containerStroke,TweenInfo.new(0.16),{Thickness=1}):Play()
                TweenService:Create(cardContainer,TweenInfo.new(0.16),{BackgroundColor3=(selectedEmote == emote) and Color3.fromRGB(24,24,24) or Color3.fromRGB(8,8,8),BackgroundTransparency=(selectedEmote == emote) and 0.30 or 0.62}):Play()
                if selectedEmote == emote then
                    HXStyleChamfer(cardContainer,{coreTransparency=0.08,glowTransparency=0.70,cornerCoreTransparency=0.00,cornerGlowTransparency=0.48,cornerCoreThickness=0.95,cornerGlowThickness=2.2,color=Color3.fromRGB(255,255,255)})
                else
                    HXStyleChamfer(cardContainer,{coreTransparency=0.62,glowTransparency=0.98,cornerCoreTransparency=0.58,cornerGlowTransparency=0.96,cornerCoreThickness=0.95,cornerGlowThickness=2.2,color=Color3.fromRGB(190,190,190)})
                end
            end
        end)
        if FriendData and FriendData.currentSyncPartner then FriendData.currentSyncPartner=nil end
        if emote.isUGC then
            local cardToken = tostring(emote.id)
            visual.Active = false
            task.spawn(function()
                local playId = ResolveUGCAnimationId(emote) or emote.id
                if visual and visual.Parent and tostring(emote.id) == cardToken then visual.Active = true end
                PlayEmote(playId, emote.name)
            end)
        else
            PlayEmote(emote.id, emote.name)
        end
    end)

    return cardContainer
end


local function UpdateCards(animate, fastMode)
	ClearCards()

	local startIdx = (page - 1) * perPage + 1
	local endIdx = math.min(page * perPage, #filtered)

	local ci = 0
	for i = startIdx, endIdx do
		if filtered[i] then
			cards[i] = MakeCard(filtered[i], ci, animate and not fastMode)
			ci = ci + 1
			if fastMode and ci % 8 == 0 then task.wait() end
		end
	end

	local CARD = currentCardSize
	local PAD = isMobile and 7 or 8
	local INFO_H = isMobile and 46 or 40
	local KB_H = ((not isMobile) or _isPlaylistMode) and (isMobile and 24 or 26) or 0
	local CARD_TOTAL_H = CARD + INFO_H + KB_H

	local rows = math.ceil(ci / math.max(cols, 1))
	scroll.CanvasSize = UDim2.new(0, 0, 0, rows * (CARD_TOTAL_H + PAD) + PAD)
	scroll.CanvasPosition = Vector2.zero

	-- Preload only while browsing normally. Doing this during each search was the main source of stalls after obfuscation.
	local searching = search and search.Text and search.Text ~= ""
	if not fastMode and not searching then
		local _npStart = page * perPage + 1
		local _npEnd   = math.min((page + 1) * perPage, #filtered)
		if _npStart <= _npEnd then
			task.delay(0.25, function()
				local _imgs = {}
				for _i = _npStart, _npEnd do
					local _fe = filtered[_i]
					if _fe and not _badEmotes[tostring(_fe.id)] then
						local _img = Instance.new("ImageLabel")
						_img.Image = "rbxthumb://type=Asset&id=" .. _fe.id .. "&w=420&h=420"
						_imgs[#_imgs + 1] = _img
					end
				end
				if #_imgs > 0 then
					pcall(function() game:GetService("ContentProvider"):PreloadAsync(_imgs) end)
					for _, _img in ipairs(_imgs) do _img:Destroy() end
				end
			end)
		end
	end
end

Refresh = function(animate, fastMode)
	CalcLayout()
	UpdatePageUI()
	UpdateCards(animate ~= false, fastMode == true)
end

prevBtn.MouseButton1Click:Connect(function()
    if currentTab == "ugc" and _ugcPageMode then
        if _ugcHasPrevious and LoadUGCPage then LoadUGCPage("prev") end
        return
    end
	if pages <= 1 then return end
	if page > 1 then
		page = page - 1
	else
		page = pages
	end
	Refresh(true)
end)
nextBtn.MouseButton1Click:Connect(function()
    if currentTab == "ugc" and _ugcPageMode then
        if _ugcHasNext and LoadUGCPage then LoadUGCPage("next") end
        return
    end
	if pages <= 1 then return end
	if page < pages then
		page = page + 1
	else
		page = 1
	end
	Refresh(true)
end)


UpdateTabStyles = function()
    for name,data in pairs(tabBtns) do
        local active = currentTab == name
        TweenService:Create(data.btn,TweenInfo.new(0.17,Enum.EasingStyle.Quad),{
            BackgroundColor3 = active and Color3.fromRGB(30,30,30) or Color3.fromRGB(0,0,0),
            BackgroundTransparency = 1
        }):Play()

        -- Only the SELECTED category gets the bright neon cut-corner treatment.
        if active then
            HXStyleChamfer(data.btn,{coreTransparency=0.06,glowTransparency=0.72,color=Color3.fromRGB(250,250,250)})
        else
            HXStyleChamfer(data.btn,{coreTransparency=0.72,glowTransparency=1,color=Color3.fromRGB(180,180,180)})
        end

        if data.img then
            if data.img:GetAttribute("HXClockIcon") then
                HXStyleRecentClock(data.img, active and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,190,190), active and 0 or 0.12)
            elseif data.img:IsA("ImageLabel") or data.img:IsA("ImageButton") then
                local iconColor = active and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,190,190)
                local iconTransparency = active and 0 or 0.12
                TweenService:Create(data.img,TweenInfo.new(0.17),{ImageColor3=iconColor,ImageTransparency=iconTransparency}):Play()
            elseif data.img:IsA("TextLabel") then
                local textIconColor = active and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,190,190)
                TweenService:Create(data.img,TweenInfo.new(0.17),{TextColor3=textIconColor,TextTransparency=active and 0 or 0.12}):Play()
            end
        end
        if data.label then
            TweenService:Create(data.label,TweenInfo.new(0.17),{TextColor3=active and Color3.fromRGB(255,255,255) or Color3.fromRGB(170,170,170)}):Play()
        end
    end
end

playlistBackBtn = Instance.new("TextButton")
playlistBackBtn.Size = UDim2.new(0, 30, 0, 30)
playlistBackBtn.Position = UDim2.new(0, 8, 0, titleH + 4)
playlistBackBtn.BackgroundColor3 = currentTheme.secondary
playlistBackBtn.Text = "<"
playlistBackBtn.TextColor3 = currentTheme.text
playlistBackBtn.Font = Enum.Font.GothamBold
playlistBackBtn.TextSize = 18
playlistBackBtn.Visible = false
playlistBackBtn.ZIndex = 10
playlistBackBtn.Parent = content
Instance.new("UICorner", playlistBackBtn).CornerRadius = UDim.new(0, 8)
RegisterTheme(playlistBackBtn, "BackgroundColor3", "secondary")
RegisterTheme(playlistBackBtn, "TextColor3", "text")
playlistBackBtn.MouseButton1Click:Connect(function()
	_currentPlaylistId = nil
	search.Text = ""
	UpdateTabData()
end)

playlistDoneBtn = Instance.new("TextButton")
playlistDoneBtn.Size = UDim2.new(0, 50, 0, 30)
playlistDoneBtn.Position = UDim2.new(1, -58, 0, titleH + 4)
playlistDoneBtn.BackgroundColor3 = currentTheme.accent
playlistDoneBtn.Text = L.done
playlistDoneBtn.TextColor3 = Color3.new(1,1,1)
playlistDoneBtn.Font = Enum.Font.GothamBold
playlistDoneBtn.TextSize = 14
playlistDoneBtn.Visible = false
playlistDoneBtn.ZIndex = 10
playlistDoneBtn.Parent = content
Instance.new("UICorner", playlistDoneBtn).CornerRadius = UDim.new(0, 8)
RegisterTheme(playlistDoneBtn, "BackgroundColor3", "accent")

ShowSavePlaylistDialog = function(onSave)
	local success, err = pcall(function()
		local existing = main:FindFirstChild("HXSavePlaylistOverlay")
		if existing then existing:Destroy() end

		local overlay = Instance.new("TextButton")
		overlay.Name = "HXSavePlaylistOverlay"
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 0.5
		overlay.Text = ""
		overlay.AutoButtonColor = false
		overlay.ZIndex = 200
		overlay.Parent = main
		overlay.MouseButton1Click:Connect(function() end)

		local dialog = Instance.new("Frame")
		dialog.Size = UDim2.new(0.85, 0, 0, 180)
		dialog.Position = UDim2.fromScale(0.5, 0.5)
		dialog.AnchorPoint = Vector2.new(0.5, 0.5)
		dialog.BackgroundColor3 = currentTheme.secondary
		dialog.ZIndex = 201
		dialog.Parent = overlay
		Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 16)
		local dStroke = Instance.new("UIStroke")
		dStroke.Color = currentTheme.accent
		dStroke.Thickness = 2
		dStroke.Transparency = 0.4
		dStroke.Parent = dialog

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -16, 0, 36)
		titleLbl.Position = UDim2.new(0, 8, 0, 8)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = L.createPlaylist
		titleLbl.TextColor3 = currentTheme.text
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 16
		titleLbl.ZIndex = 202
		titleLbl.Parent = dialog

		local nameLblTitle = Instance.new("TextLabel")
		nameLblTitle.Size = UDim2.new(0, 100, 0, 24)
		nameLblTitle.Position = UDim2.new(0, 12, 0, 52)
		nameLblTitle.BackgroundTransparency = 1
		nameLblTitle.Text = L.playlistName
		nameLblTitle.TextColor3 = currentTheme.textDim
		nameLblTitle.Font = Enum.Font.GothamBold
		nameLblTitle.TextSize = 13
		nameLblTitle.TextXAlignment = Enum.TextXAlignment.Left
		nameLblTitle.ZIndex = 202
		nameLblTitle.Parent = dialog

		local nameBox = Instance.new("TextBox")
		nameBox.Size = UDim2.new(1, -24, 0, 32)
		nameBox.Position = UDim2.new(0, 12, 0, 78)
		nameBox.BackgroundColor3 = currentTheme.tertiary
		nameBox.PlaceholderText = L.playlistNamePlaceholder
		nameBox.Text = ""
		nameBox.TextColor3 = currentTheme.text
		nameBox.PlaceholderColor3 = currentTheme.textDim
		nameBox.Font = Enum.Font.Gotham
		nameBox.TextSize = 13
		nameBox.ClearTextOnFocus = false
		nameBox.ZIndex = 202
		nameBox.Parent = dialog
		Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 8)
		local nbStroke = Instance.new("UIStroke")
		nbStroke.Color = currentTheme.stroke
		nbStroke.Thickness = 1.5
		nbStroke.Parent = nameBox

		local cancelBtn = Instance.new("TextButton")
		cancelBtn.Size = UDim2.new(0.45, -6, 0, 38)
		cancelBtn.Position = UDim2.new(0, 12, 0, 128)
		cancelBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		cancelBtn.Text = L.kbCancel
		cancelBtn.TextColor3 = Color3.new(1, 1, 1)
		cancelBtn.Font = Enum.Font.GothamBold
		cancelBtn.TextSize = 14
		cancelBtn.ZIndex = 202
		cancelBtn.Parent = dialog
		Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

		local saveBtn = Instance.new("TextButton")
		saveBtn.Size = UDim2.new(0.55, -18, 0, 38)
		saveBtn.Position = UDim2.new(0.45, 6, 0, 128)
		saveBtn.BackgroundColor3 = Color3.fromRGB(129, 129, 129)
		saveBtn.Text = L.kbSave
		saveBtn.TextColor3 = Color3.new(1, 1, 1)
		saveBtn.Font = Enum.Font.GothamBold
		saveBtn.TextSize = 14
		saveBtn.ZIndex = 202
		saveBtn.Parent = dialog
		Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)

		cancelBtn.MouseButton1Click:Connect(function()
			overlay:Destroy()
		end)

		saveBtn.MouseButton1Click:Connect(function()
			local plName = nameBox.Text
			if plName == "" then return end
			onSave(plName)
			overlay:Destroy()
		end)
	end)
	if not success then
		warn("[HX Emotes] ShowSavePlaylistDialog Error: " .. tostring(err))
	end
end

playlistDoneBtn.MouseButton1Click:Connect(function()
	local success, err = pcall(function()
		local emoteIds = {}
		for k, v in pairs(_selectedEmotesForPlaylist) do
			if v then table.insert(emoteIds, tonumber(k)) end
		end

		if #emoteIds == 0 then
			_isPlaylistMode = false
			currentTab = "playlists"
			search.Text = ""
			if RefreshPlaylistsList then RefreshPlaylistsList() end
			UpdateTabData()
			return
		end

		ShowSavePlaylistDialog(function(plName)
			local newId = tostring(math.random(100000, 999999))
			local newPl = {
				id = newId,
				name = plName,
				creator = player.Name,
				creatorId = player.UserId,
				emotes = emoteIds
			}
			table.insert(Playlists, newPl)
			SaveData()

			_isPlaylistMode = false
			currentTab = "playlists"
			search.Text = ""
			if RefreshPlaylistsList then RefreshPlaylistsList() end
			UpdateTabData()
		end)
	end)
	if not success then
		warn("[HX Emotes] playlistDoneBtn.Click Error: " .. tostring(err))
	end
end)

RefreshPlaylistsList = function()
	local success, err = pcall(function()
		print("[HX Emotes] RefreshPlaylistsList running. Playlists count: " .. tostring(#Playlists))
		if not playlistsPanel then
			warn("[HX Emotes] playlistsPanel is NIL inside RefreshPlaylistsList!")
			return
		end

		for _, child in ipairs(playlistsPanel:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		local query = ""
		if playlistListSearch then
			query = playlistListSearch.Text:lower()
		end

		local yOffset = 46

		local sortedPlaylists = {}
		for _, pl in ipairs(Playlists) do
			table.insert(sortedPlaylists, pl)
		end
		table.sort(sortedPlaylists, function(a, b)
			local aFav = PlaylistFavorites[tostring(a.id)] and 1 or 0
			local bFav = PlaylistFavorites[tostring(b.id)] and 1 or 0
			if aFav ~= bFav then
				return aFav > bFav
			end
			return a.name:lower() < b.name:lower()
		end)

		for _, pl in ipairs(sortedPlaylists) do
			if query == "" or pl.name:lower():find(query, 1, true) then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, 0, 0, 60)
				row.BackgroundColor3 = currentTheme.secondary
				row.Text = ""
				row.ZIndex = 6
				row.Parent = playlistsPanel
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
				RegisterTheme(row, "BackgroundColor3", "secondary")

				local av = Instance.new("ImageLabel")
				av.Size = UDim2.new(0, 44, 0, 44)
				av.Position = UDim2.new(0, 8, 0.5, -22)
				av.BackgroundTransparency = 1
				av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. pl.creatorId .. "&w=150&h=150"
				av.ZIndex = 7
				av.Parent = row
				Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)

				local isOwner = tostring(pl.creatorId) == tostring(player.UserId)
				local labelRightOffset = isOwner and -142 or -70

				local favBtn = Instance.new("ImageButton")
				favBtn.Size = UDim2.new(0, 38, 0, 38)
				favBtn.Position = isOwner and UDim2.new(1, -92, 0.5, -19) or UDim2.new(1, -46, 0.5, -19)
				favBtn.BackgroundTransparency = 1
				local isFav = PlaylistFavorites[tostring(pl.id)]
				favBtn.Image = isFav and "rbxthumb://type=Asset&id=89982519956696&w=150&h=150" or "rbxthumb://type=Asset&id=116039663994329&w=150&h=150"
				favBtn.ZIndex = 8
				favBtn.Parent = row

				favBtn.MouseButton1Click:Connect(function()
					local plId = tostring(pl.id)
					PlaylistFavorites[plId] = not PlaylistFavorites[plId]
					SaveData()
					if RefreshPlaylistsList then RefreshPlaylistsList() end
				end)

				local creatorLbl = Instance.new("TextLabel")
				creatorLbl.Size = UDim2.new(1, labelRightOffset, 0, 16)
				creatorLbl.Position = UDim2.new(0, 60, 0, 12)
				creatorLbl.BackgroundTransparency = 1
				creatorLbl.Text = L.createdBy .. pl.creator
				creatorLbl.TextColor3 = currentTheme.text
				creatorLbl.TextTransparency = 0.4
				creatorLbl.Font = Enum.Font.Gotham
				creatorLbl.TextSize = 11
				creatorLbl.TextXAlignment = Enum.TextXAlignment.Left
				creatorLbl.ZIndex = 7
				creatorLbl.Parent = row
				RegisterTheme(creatorLbl, "TextColor3", "text")

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = UDim2.new(1, labelRightOffset, 0, 20)
				nameLbl.Position = UDim2.new(0, 60, 0, 28)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Text = pl.name
				nameLbl.TextColor3 = currentTheme.text
				nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextSize = 16
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.ZIndex = 7
				nameLbl.Parent = row
				RegisterTheme(nameLbl, "TextColor3", "text")

				if isOwner then
					local delBtn = Instance.new("TextButton")
					delBtn.Size = UDim2.new(0, 38, 0, 38)
					delBtn.Position = UDim2.new(1, -46, 0.5, -19)
					delBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
					delBtn.Text = L.deletePlaylist
					delBtn.TextColor3 = Color3.new(1, 1, 1)
					delBtn.Font = Enum.Font.GothamBold
					delBtn.TextSize = 12
					delBtn.ZIndex = 8
					delBtn.Parent = row
					Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 8)

					local _delConfirm = false
					local _delTimer = nil

					delBtn.MouseButton1Click:Connect(function()
						if not _delConfirm then
							_delConfirm = true
							delBtn.Text = L.deleteConfirm
							delBtn.TextSize = 10
							delBtn.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
							if _delTimer then _delTimer:Disconnect() end
							_delTimer = task.delay(3, function()
								if delBtn and delBtn.Parent then
									_delConfirm = false
									delBtn.Text = L.deletePlaylist
									delBtn.TextSize = 12
									delBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
								end
							end)
						else
							_delConfirm = false
							for i, p in ipairs(Playlists) do
								if p.id == pl.id then
									table.remove(Playlists, i)
									break
								end
							end
							SaveData()
							if RefreshPlaylistsList then RefreshPlaylistsList() end
						end
					end)
				end

				row.MouseButton1Click:Connect(function()
					_currentPlaylistId = pl.id
					search.Text = ""
					UpdateTabData()
				end)

				yOffset = yOffset + 66
			end
		end

		playlistsPanel.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
	end)
	if not success then
		warn("[HX Emotes] RefreshPlaylistsList Inner Error: " .. tostring(err))
	end
end

local toolsContentPanel = nil
local RefreshToolsCategory = nil

-- AFEM-style UGC marketplace engine adapted for HX Emotes.
-- It combines AFEM's semantic UGC endpoint with Roblox catalog results, keeps
-- cursor/page state, and resolves the playable animation through Asset Delivery.
local HXUGCMarketplace = {}
HXUGCMarketplace.__index = HXUGCMarketplace

local HX_UGC_PAGE_SIZE = 21
local HX_UGC_ENDPOINTS = {
    FIRST_PAGE = "firstPage",
    SEARCH = "https://catalog.roblox.com/v1/search/items/details?Category=12&Subcategory=39&SortType=Relevance&IncludeNotForSale=true&Limit=30&Keyword=%s",
    DEFAULT = "https://catalog.roblox.com/v1/search/items/details?Category=12&Subcategory=39&SortType=Updated&IncludeNotForSale=true&Limit=30",
    DETAILS = "https://catalog.roblox.com/v1/catalog/items/%d/details?itemType=Asset",
    ASSET_DELIVERY = "https://assetdelivery.roblox.com/v1/assetId/%d",
    EXTERNAL = "https://science.yarhm.com/afemmax/embeddings?search=%s",
}

local function HXUGCRequestText(url)
    -- AFEM uses game:HttpGet. Keep that path first, then fall back to the
    -- executor request API because some executors block one but allow the other.
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and body ~= "" then return body end

    local req = nil
    pcall(function()
        if type(request) == "function" then req = request end
        if not req and type(http_request) == "function" then req = http_request end
        if not req and syn and type(syn.request) == "function" then req = syn.request end
        if not req and http and type(http.request) == "function" then req = http.request end
    end)

    if req then
        local rok, response = pcall(function()
            return req({
                Url = url,
                Method = "GET",
                Headers = {
                    ["Accept"] = "application/json,text/plain,*/*",
                    ["User-Agent"] = "Roblox/WinInet"
                }
            })
        end)
        if rok and type(response) == "table" then
            local responseBody = response.Body or response.body or response.ResponseBody
            if type(responseBody) == "string" and responseBody ~= "" then
                return responseBody
            end
        end
    end
    return nil
end

local function HXUGCRequestJson(url)
    local body = HXUGCRequestText(url)
    if not body then return {} end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
    if ok and type(decoded) == "table" then return decoded end
    return {}
end

local function HXNormalizeUGCItem(item)
    if type(item) ~= "table" then return nil end
    local id = tonumber(item.asset_id or item.id or item.Id or item.AssetId)
    if not id then return nil end

    local creator = item.creatorName or item.CreatorName or item.creator or item.Creator or "Roblox"
    if type(creator) == "table" then
        creator = creator.name or creator.Name or creator.username or creator.Username or "Roblox"
    end

    local em = {
        id = id,
        name = tostring(item.name or item.Name or ("Roblox " .. tostring(id))),
        creatorName = tostring(creator or "Roblox"),
        description = tostring(item.description or item.Description or ""),
        isUGC = true,
    }
    em._searchBlob = (em.name .. " " .. em.creatorName .. " " .. em.description):lower()
    return em
end

function HXUGCMarketplace.new()
    local self = setmetatable({}, HXUGCMarketplace)
    self:ResetState("")
    return self
end

function HXUGCMarketplace:ResetState(query)
    self.searchQuery = tostring(query or "")
    self.cursorHistory = {HX_UGC_ENDPOINTS.FIRST_PAGE}
    self.cursorIndex = 1
    self.cache = {}
    self.externalResults = nil
    self.extOffset = 0
    self.rbxBuffer = {}
    self.rbxCursor = ""
    self.rbxExhausted = false
    self.useNativeFallback = false
    self.nativePages = nil
    self.nativePageLoaded = false
    self.nativeFinished = false
end

function HXUGCMarketplace:_FetchNativePage()
    -- Last-resort fallback only. This does NOT preload the whole Roblox catalog;
    -- it requests one page at a time with the same query and emote-only filter.
    if not AvatarEditorService then return {} end

    if not self.nativePages then
        local ok, pages = pcall(function()
            local params = CatalogSearchParams.new()
            params.SearchKeyword = tostring(self.searchQuery or "")
            params.AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}
            params.IncludeOffSale = true
            params.Limit = 30
            if AvatarEditorService.SearchCatalogAsync then
                return AvatarEditorService:SearchCatalogAsync(params)
            end
            return AvatarEditorService:SearchCatalog(params)
        end)
        if not ok or not pages then
            self.nativeFinished = true
            return {}
        end
        self.nativePages = pages
        self.nativePageLoaded = false
    elseif self.nativePageLoaded then
        local isFinished = false
        pcall(function() isFinished = self.nativePages.IsFinished == true end)
        if isFinished then
            self.nativeFinished = true
            return {}
        end
        local okAdvance = pcall(function() self.nativePages:AdvanceToNextPageAsync() end)
        if not okAdvance then
            self.nativeFinished = true
            return {}
        end
    end

    local okItems, items = pcall(function() return self.nativePages:GetCurrentPage() end)
    if not okItems or type(items) ~= "table" then
        self.nativeFinished = true
        return {}
    end
    self.nativePageLoaded = true
    local isFinished = false
    pcall(function() isFinished = self.nativePages.IsFinished == true end)
    self.nativeFinished = isFinished
    return items
end

function HXUGCMarketplace:FetchEmotes(options)
    options = options or {}
    local query = tostring(options.search ~= nil and options.search or self.searchQuery or "")
    local cursor = options.cursor or HX_UGC_ENDPOINTS.FIRST_PAGE

    if query ~= self.searchQuery then
        self:ResetState(query)
        cursor = HX_UGC_ENDPOINTS.FIRST_PAGE
    end

    local historyIndex = table.find(self.cursorHistory, cursor) or 1
    local cached = self.cache[cursor]
    if cached then
        self.cursorIndex = historyIndex
        return cached.items, cached.nextCursor
    end

    -- AFEM first asks its semantic endpoint for UGC-specific matches. If that
    -- endpoint is unavailable, Roblox results still work as a full fallback.
    if query ~= "" and self.externalResults == nil then
        local response = HXUGCRequestJson(string.format(HX_UGC_ENDPOINTS.EXTERNAL, HttpService:UrlEncode(query)))
        local list = response.emotes or response
        self.externalResults = type(list) == "table" and list or {}
    elseif query == "" and self.externalResults == nil then
        self.externalResults = {}
    end

    local items, seen = {}, {}
    local function push(raw)
        local em = HXNormalizeUGCItem(raw)
        if em and not seen[em.id] then
            seen[em.id] = true
            items[#items + 1] = em
        end
    end

    if self.externalResults and self.extOffset < #self.externalResults then
        while #items < HX_UGC_PAGE_SIZE and self.extOffset < #self.externalResults do
            self.extOffset = self.extOffset + 1
            push(self.externalResults[self.extOffset])
        end
    end

    while #items < HX_UGC_PAGE_SIZE and not self.rbxExhausted do
        if #self.rbxBuffer > 0 then
            local raw = table.remove(self.rbxBuffer, 1)
            push(raw)
        else
            local url
            if query ~= "" then
                url = string.format(HX_UGC_ENDPOINTS.SEARCH, HttpService:UrlEncode(query))
            else
                url = HX_UGC_ENDPOINTS.DEFAULT
            end
            if self.rbxCursor ~= "" then
                url = url .. "&cursor=" .. HttpService:UrlEncode(self.rbxCursor)
            end

            local data = {}
            if self.useNativeFallback then
                data = self:_FetchNativePage()
            else
                local response = HXUGCRequestJson(url)
                data = type(response.data) == "table" and response.data or {}
                local nextCursor = tostring(response.nextPageCursor or "")
                self.rbxCursor = nextCursor

                -- If direct AFEM/Roblox HTTP is blocked or returns no data, switch
                -- automatically to Roblox's native catalog service for this query.
                if #data == 0 then
                    self.useNativeFallback = true
                    self.rbxCursor = ""
                    data = self:_FetchNativePage()
                end
            end

            if #data == 0 then
                self.rbxExhausted = true
                break
            end
            for i = 1, #data do self.rbxBuffer[#self.rbxBuffer + 1] = data[i] end

            if self.useNativeFallback then
                if self.nativeFinished then
                    -- Consume the current native page, then stop.
                    self.rbxExhausted = true
                end
            elseif self.rbxCursor == "" then
                -- Consume the final HTTP buffer, then stop requesting more pages.
                self.rbxExhausted = true
            end
        end
    end

    -- If rbxExhausted became true while a final buffer still has items, consume it.
    while #items < HX_UGC_PAGE_SIZE and #self.rbxBuffer > 0 do
        push(table.remove(self.rbxBuffer, 1))
    end

    local nextCursor = ""
    if (self.externalResults and self.extOffset < #self.externalResults) or #self.rbxBuffer > 0 or not self.rbxExhausted then
        nextCursor = "INT_CUR_" .. tostring(#self.cursorHistory + 1)
    end

    self.cache[cursor] = {items = items, nextCursor = nextCursor}
    self.cursorIndex = historyIndex
    if nextCursor ~= "" and not table.find(self.cursorHistory, nextCursor) then
        self.cursorHistory[#self.cursorHistory + 1] = nextCursor
    end
    return items, nextCursor
end

function HXUGCMarketplace:PreviousFetch()
    if self.cursorIndex <= 1 then return nil, "No previous page" end
    self.cursorIndex = self.cursorIndex - 1
    local cursor = self.cursorHistory[self.cursorIndex]
    return self:FetchEmotes({cursor = cursor})
end

function HXUGCMarketplace:NextFetch()
    if self.cursorIndex < #self.cursorHistory then
        self.cursorIndex = self.cursorIndex + 1
        local cursor = self.cursorHistory[self.cursorIndex]
        return self:FetchEmotes({cursor = cursor})
    end
    local currentCursor = self.cursorHistory[self.cursorIndex]
    local cached = self.cache[currentCursor]
    if cached and cached.nextCursor ~= "" then
        return self:FetchEmotes({cursor = cached.nextCursor})
    end
    return nil, "No more pages"
end

function HXUGCMarketplace:GetEmoteDetails(assetId)
    return HXUGCRequestJson(string.format(HX_UGC_ENDPOINTS.DETAILS, tonumber(assetId) or 0))
end

local function HXExtractAnimationId(content)
    if type(content) ~= "string" then return nil end
    local id = content:match("rbxassetid://(%d+)")
        or content:match("roblox%.com/asset/%?id=(%d+)")
        or content:match("[?&]id=(%d+)")
    return tonumber(id)
end

function HXUGCMarketplace:GetAnimationId(assetId)
    assetId = tonumber(assetId)
    if not assetId then return nil end
    if _ugcAnimCacheMain[assetId] then return _ugcAnimCacheMain[assetId] end

    local resolved
    local delivery = HXUGCRequestJson(string.format(HX_UGC_ENDPOINTS.ASSET_DELIVERY, assetId))
    if type(delivery.location) == "string" and delivery.location ~= "" then
        resolved = HXExtractAnimationId(HXUGCRequestText(delivery.location))
    end

    -- Compatibility fallback for executors where Asset Delivery is blocked or
    -- returns a format without an embedded rbxassetid URL.
    if not resolved then
        local ok, objects = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(assetId)) end)
        if ok and objects and #objects > 0 then
            local root = objects[1]
            local anim = root:IsA("Animation") and root or root:FindFirstChildWhichIsA("Animation", true)
            if anim and anim.AnimationId then
                resolved = tonumber(tostring(anim.AnimationId):match("%d+"))
            end
        end
    end

    if resolved then _ugcAnimCacheMain[assetId] = resolved end
    return resolved
end

local _ugcMarketplace = HXUGCMarketplace.new()

local function HXApplyUGCPage(items, token)
    if token ~= _ugcRequestTokenMain then return end
    local out = {}
    for i = 1, #(items or {}) do
        local em = HXNormalizeUGCItem(items[i]) or items[i]
        if em and tonumber(em.id) then
            out[#out + 1] = em
            EmotesById[tonumber(em.id)] = em
        end
    end
    UGCEmotes = out
    currentData = UGCEmotes
    filtered = ApplyCurrentSort(UGCEmotes)
    page = 1
    _ugcCurrentPage = _ugcMarketplace.cursorIndex
    _ugcHasPrevious = _ugcCurrentPage > 1
    local cursorKey = _ugcMarketplace.cursorHistory[_ugcMarketplace.cursorIndex]
    local cached = cursorKey and _ugcMarketplace.cache[cursorKey]
    _ugcHasNext = cached ~= nil and cached.nextCursor ~= ""
    _ugcSearchBusyMain = false

    if currentTab == "ugc" then
        if emptyLbl and #filtered == 0 then
            emptyLbl.Visible = true
            emptyLbl.Text = isES and "No se encontraron emotes UGC." or "No UGC emotes found."
        end
        if Refresh then Refresh(false, true) end
    end
end

ResolveUGCAnimationId = function(emote)
    if not emote then return nil end
    if emote.playId then return tonumber(emote.playId) end
    local catalogId = tonumber(emote.id)
    if not catalogId then return nil end
    local resolved = _ugcMarketplace:GetAnimationId(catalogId)
    if resolved then emote.playId = resolved end
    return resolved
end

LoadUGCCatalog = function(query)
    _ugcRequestTokenMain = _ugcRequestTokenMain + 1
    local token = _ugcRequestTokenMain
    local q = tostring(query or "")
    _ugcActiveQuery = q
    _ugcSearchBusyMain = true
    _ugcCurrentPage = 1
    _ugcHasPrevious = false
    _ugcHasNext = false

    if currentTab == "ugc" and emptyLbl then
        emptyLbl.Visible = true
        emptyLbl.Text = isES and "Buscando emotes UGC..." or "Searching UGC emotes..."
    end

    task.spawn(function()
        local ok, items = pcall(function()
            return _ugcMarketplace:FetchEmotes({search = q, cursor = HX_UGC_ENDPOINTS.FIRST_PAGE})
        end)
        if token ~= _ugcRequestTokenMain then return end
        if not ok or type(items) ~= "table" then items = {} end
        HXApplyUGCPage(items, token)
    end)
end

LoadUGCPage = function(direction)
    if _ugcSearchBusyMain then return end
    _ugcRequestTokenMain = _ugcRequestTokenMain + 1
    local token = _ugcRequestTokenMain
    _ugcSearchBusyMain = true

    task.spawn(function()
        local ok, items = pcall(function()
            if direction == "prev" then
                return _ugcMarketplace:PreviousFetch()
            end
            return _ugcMarketplace:NextFetch()
        end)
        if token ~= _ugcRequestTokenMain then return end
        if not ok or type(items) ~= "table" then
            _ugcSearchBusyMain = false
            if Refresh then Refresh(false, true) end
            return
        end
        HXApplyUGCPage(items, token)
    end)
end

local function PrintHierarchy(obj, depth)
	depth = depth or 0
	local indent = string.rep("  ", depth)
	local isGui = obj:IsA("GuiObject")
	local transp = "N/A"
	pcall(function()
		if obj:IsA("Frame") or obj:IsA("ScrollingFrame") or obj:IsA("TextBox") or obj:IsA("TextButton") or obj:IsA("ImageLabel") or obj:IsA("TextLabel") then
			transp = tostring(obj.BackgroundTransparency)
		end
	end)
	print(string.format("[Hierarchy] %s%s (%s): Visible=%s, Size=%s, AbsSize=%s, AbsPos=%s, ZIndex=%s, Transp=%s",
		indent,
		obj.Name,
		obj.ClassName,
		tostring(isGui and obj.Visible or "N/A"),
		tostring(isGui and obj.Size or "N/A"),
		tostring(isGui and obj.AbsoluteSize or "N/A"),
		tostring(isGui and obj.AbsolutePosition or "N/A"),
		tostring(isGui and obj.ZIndex or "N/A"),
		transp
	))
	for _, child in ipairs(obj:GetChildren()) do
		PrintHierarchy(child, depth + 1)
	end
end

UpdateTabData = function()
	hideTrendingDropdown()
	if currentTab == "settings" or currentTab == "friends" then
		currentTab = "emotes"
	end
	search.Text = ""
	page = 1

	local isSettings  = false
	local isFriends   = false
	local isKeybinds  = currentTab == "keybinds"
	local isPlaylists = currentTab == "playlists"
	local isAnimations = currentTab == "animations"
	local isTools = currentTab == "tools"
	local isUGC = currentTab == "ugc"
	local isInfo = currentTab == "info"
	settingsPanel.Visible  = isSettings
	friendsPanel.Visible   = isFriends
	keybindsPanel.Visible  = isKeybinds
	aboutPanel.Visible = isInfo
	if toolsContentPanel then toolsContentPanel.Visible = isTools end
	if isTools and RefreshToolsCategory then RefreshToolsCategory() end
	local viewingPlaylist = isPlaylists and (_currentPlaylistId ~= nil)

	if isPlaylists and not viewingPlaylist then
		if RefreshPlaylistsList then RefreshPlaylistsList() end
	end
	playlistsPanel.Visible = isPlaylists and not viewingPlaylist
	local hideNormal = isSettings or isFriends or isKeybinds or isInfo or isTools or (isPlaylists and not viewingPlaylist)
	scroll.Visible  = not hideNormal
	search.Visible  = not hideNormal
	if playlistBackBtn then
		playlistBackBtn.Visible = viewingPlaylist
		playlistDoneBtn.Visible = _isPlaylistMode
		local leftOffset = viewingPlaylist and 46 or 12
		search.Position = UDim2.new(0,leftOffset,0,titleH+4)
		search.Size = UDim2.new(1,-(leftOffset+12),0,searchH)
	end
	local showPreview = false
	if previewPanel then previewPanel.Visible = showPreview end
	if bottomBar then bottomBar.Visible = false end
	pageBar.Visible = not hideNormal

	if not hideNormal and scroll and pageBar then
		if showPreview then
			local emoteScrollY = (titleH+searchH+14)
			scroll.Position = UDim2.new(0,8,0,emoteScrollY)
			if previewStacked then
				scroll.Size = UDim2.new(1,-16,1,-(emoteScrollY+pageH+14))
				pageBar.Size = UDim2.new(1,-24,0,pageH)
			else
				scroll.Size = UDim2.new(1,-16,1,-(emoteScrollY+pageH+14))
				pageBar.Size = UDim2.new(1,-24,0,pageH)
			end
		else
			local fullScrollY = titleH+searchH+14
			scroll.Position = UDim2.new(0,8,0,fullScrollY)
			scroll.Size = UDim2.new(1,-16,1,-(fullScrollY+pageH+14))
			pageBar.Size = UDim2.new(1,-24,0,pageH)
		end
		pageBar.Position = UDim2.new(0,12,1,-(pageH+10))
	end

	if hideNormal then
		emptyLbl.Visible = false
	end
	if isKeybinds then
		if RefreshKeybindsPanel then RefreshKeybindsPanel() end
	end

	if currentTab == "emotes" then
		currentData = Emotes
		if next(_badEmotes) then
			filtered = {}
			for _, e in ipairs(Emotes) do
				if not _badEmotes[tostring(e.id)] then filtered[#filtered + 1] = e end
			end
		else
			filtered = Emotes
		end
		title.Text = L.emotes
		titleIcon.Image = ResolveAssetImage(Icons.Emote)
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
	elseif currentTab == "ugc" then
		currentData = UGCEmotes
		filtered = UGCEmotes
		title.Text = "ROBLOX"
		titleIcon.Image = ResolveAssetImage("rbxassetid://3576686446")
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
        -- AFEM-style marketplace fetch: default updated UGC page on tab open.
        task.defer(function()
            if currentTab == "ugc" and LoadUGCCatalog then LoadUGCCatalog("") end
        end)
	elseif currentTab == "favorites" then
		currentData = {}
		for i = 1, #Favorites do
			local emote = EmotesById[Favorites[i]]
			if emote then
				currentData[#currentData + 1] = emote
			end
		end
		filtered = currentData
		title.Text = L.favorites
		titleIcon.Image = ResolveAssetImage(Icons.FavoriteFull)
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false

	elseif currentTab == "recent" then
		currentData = {}
		for i = 1, #RecentEmotes do
			local emote = EmotesById[RecentEmotes[i]]
			if emote then
				currentData[#currentData + 1] = emote
			end
		end
		filtered = currentData
		title.Text = L.recent
		titleIcon.Image = ResolveAssetImage(Icons.Recent)
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
	elseif currentTab == "playlists" then
		if _currentPlaylistId then
			currentData = {}
			if not MockPlaylists then return end
	for _, pl in ipairs(Playlists) do
				if pl.id == _currentPlaylistId then
					for _, eId in ipairs(pl.emotes) do
						local em = EmotesById[eId]
						if em then table.insert(currentData, em) end
					end
					break
				end
			end
			filtered = currentData
		end
		title.Text = L.playlistsTab
		titleIcon.Image = ResolveAssetImage("rbxassetid://108973165274475")
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
	elseif currentTab == "keybinds" then
		title.Text = L.keybinds
		titleIcon.Image = ResolveAssetImage("rbxassetid://122679509852670")
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
	elseif currentTab == "tools" then
		title.Text = "TOOLS"
		titleIcon.Image = ResolveAssetImage("rbxassetid://9405931578")
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
	elseif currentTab == "info" then
		title.Text = "INFO"
		titleIcon.Image = ""
		titleIcon.Visible = false
	elseif currentTab == "animations" then
		currentData = AnimationPacks
		filtered = AnimationPacks
		title.Text = isES and "Animaciones" or "Animations"
		titleIcon.Image = ResolveAssetImage("rbxassetid://75528584354229")
		titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
		titleIcon.Visible = false
	end

	local tabIconSz = isMobile and 24 or 27
	titleIcon.Size = UDim2.new(0, tabIconSz, 0, tabIconSz)
	titleIcon.Position = UDim2.new(0, 18, 0.5, 0)
	titleIcon.AnchorPoint = Vector2.new(0, 0.5)
	titleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
	title.Position = UDim2.new(0, 18 + tabIconSz + 9, 0, isMobile and 10 or 8)
	title.Size = UDim2.new(1, isMobile and -88 or -110, 0, 24)
	local subtitles = {
		emotes = isES and "Biblioteca de emotes" or "Emote library",
		ugc = isES and "Catálogo de emotes de Roblox" or "Roblox emote catalog",
		animations = isES and "Paquetes de animación" or "Animation packs",
		tools = isES and "Control y configuración" or "Controls and configuration",
		favorites = isES and "Tus emotes guardados" or "Your saved emotes",
		recent = isES and "Reproducidos recientemente" or "Recently played",
		keybinds = isES and "Accesos rápidos" or "Quick shortcuts",
		playlists = isES and "Colecciones personalizadas" or "Custom collections",
		info = isES and "Información del sistema" or "System information",
	}
	titleSubtitle.Text = subtitles[currentTab] or ""
	if not hideNormal then filtered = ApplyCurrentSort(filtered) end

	UpdateTabStyles()
	local shouldRefresh = not isSettings and not isKeybinds and not isFriends and not isInfo and (not isPlaylists or viewingPlaylist)
	if shouldRefresh then Refresh(true) end
end

tabBtns["emotes"].btn.MouseButton1Click:Connect(function() currentTab = "emotes"; UpdateTabData() end)
tabBtns["ugc"].btn.MouseButton1Click:Connect(function() currentTab = "ugc"; UpdateTabData() end)
tabBtns["favorites"].btn.MouseButton1Click:Connect(function() currentTab = "favorites"; UpdateTabData() end)
tabBtns["tools"].btn.MouseButton1Click:Connect(function() currentTab = "tools"; UpdateTabData() end)
tabBtns["recent"].btn.MouseButton1Click:Connect(function() currentTab = "recent"; UpdateTabData() end)
tabBtns["animations"].btn.MouseButton1Click:Connect(function() currentTab = "animations"; UpdateTabData() end)
if tabBtns["playlists"] then tabBtns["playlists"].btn.MouseButton1Click:Connect(function() currentTab = "playlists"; _currentPlaylistId = nil
_isPlaylistMode = false
_selectedEmotesForPlaylist = {}
if RefreshPlaylistsList then RefreshPlaylistsList() end
; UpdateTabData() end) end

local searchToken = 0
local recordToken = 0
local _lastAppliedSearch = nil
local _searchResultCache = {}
local _searchCacheOrder = {}
local _lastSearchTab = nil
local _lastSearchQuery = ""
local _lastSearchResults = nil

local function _SearchCacheKey(tab, q)
    return tostring(tab) .. "|" .. tostring(q)
end

local function _PutSearchCache(tab, q, result)
    local key = _SearchCacheKey(tab, q)
    if _searchResultCache[key] == nil then
        _searchCacheOrder[#_searchCacheOrder + 1] = key
        if #_searchCacheOrder > 18 then
            local oldKey = table.remove(_searchCacheOrder, 1)
            _searchResultCache[oldKey] = nil
        end
    end
    _searchResultCache[key] = result
end

local function ApplySearchNow()
    if currentTab == "settings" or currentTab == "info" or currentTab == "keybinds" or currentTab == "friends" or currentTab == "tools" then return end
    local q = tostring(search.Text or ""):lower()
    if q == _lastAppliedSearch and _lastSearchTab == currentTab then return end

    searchToken = searchToken + 1
    local myToken = searchToken
    _lastAppliedSearch = q

    if #q >= 2 then
        hideTrendingDropdown()
        recordToken = recordToken + 1
        local myRecord = recordToken
        task.delay(10, function()
            if myRecord ~= recordToken then return end
            if not search or search.Text:lower() ~= q then return end
            recordSearchQuery(search.Text)
        end)
    elseif q == "" then
        recordToken = recordToken + 1
    end

    -- UGC uses AFEM-style remote search, so even a one-character query can be sent.
    if currentTab == "ugc" then
        LoadUGCCatalog(q)
        return
    end

    -- Keep the local-library optimization for the built-in emote lists only.
    if q ~= "" and #q < 2 then return end

    local tabAtStart = currentTab
    local source = currentData or {}
    local cached = _searchResultCache[_SearchCacheKey(tabAtStart, q)]
    if cached then
        filtered = cached
        page = 1
        _lastSearchTab, _lastSearchQuery, _lastSearchResults = tabAtStart, q, cached
        Refresh(false, true)
        return
    end

    -- If the new query extends the previous one, search only inside the already
    -- narrowed results instead of scanning the whole library again.
    if _lastSearchTab == tabAtStart and _lastSearchResults and #_lastSearchQuery >= 2 and q:sub(1, #_lastSearchQuery) == _lastSearchQuery then
        source = _lastSearchResults
    end

    task.spawn(function()
        local result = BuildFilteredForSearch(q, source)
        if myToken ~= searchToken or currentTab ~= tabAtStart or tostring(search.Text or ""):lower() ~= q then return end
        _PutSearchCache(tabAtStart, q, result)
        _lastSearchTab, _lastSearchQuery, _lastSearchResults = tabAtStart, q, result
        filtered = result
        page = 1
        Refresh(false, true)
    end)
end

search:GetPropertyChangedSignal("Text"):Connect(function()
    if currentTab == "settings" or currentTab == "info" or currentTab == "keybinds" or currentTab == "friends" or currentTab == "tools" then return end
    searchToken = searchToken + 1
    local myToken = searchToken
    if isMobile then
        if search.Text == "" then
            _lastAppliedSearch = nil
            ApplySearchNow()
        end
        return
    end
    -- One update after typing stops; no grid rebuild per key/word.
    task.delay(0.38, function()
        if myToken ~= searchToken then return end
        ApplySearchNow()
    end)
end)

search.FocusLost:Connect(function(enterPressed)
    if isMobile or enterPressed then
        _lastAppliedSearch = nil
        ApplySearchNow()
    end
end)


do
local iconS = isMobile and 50 or 60
local miniIcon = Instance.new("ImageButton")
miniIcon.Size = UDim2.new(0, iconS, 0, iconS)
miniIcon.Position = UDim2.new(0, 20, 0.5, -iconS/2)
miniIcon.BackgroundColor3 = currentTheme.secondary
miniIcon.BackgroundTransparency = 1
miniIcon.Image = "rbxassetid://72742584610344"
miniIcon.ImageColor3 = Color3.fromRGB(255,255,255)
miniIcon.ScaleType = Enum.ScaleType.Fit
miniIcon.Visible = false
miniIcon.ZIndex = 1000
miniIcon.Parent = gui
Instance.new("UICorner", miniIcon).CornerRadius = UDim.new(0, 14)

local miniIconStroke = Instance.new("UIStroke")
miniIconStroke.Color = currentTheme.accent
miniIconStroke.Thickness = 1.5
miniIconStroke.Transparency = 1
miniIconStroke.Parent = miniIcon

miniIconGrad = Instance.new("UIGradient")
miniIconGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, currentTheme.accent),
	ColorSequenceKeypoint.new(1, currentTheme.stroke)
}
miniIconGrad.Rotation = 45
miniIconGrad.Parent = miniIconStroke


local _hxChamferConn = nil

do
local savedPos, savedSize = nil, nil
local isMaximized = false
local maximizeRestorePos, maximizeRestoreSize = nil, nil
local iconDragging, iconDragStart, iconStartPos = false, nil, nil

miniIcon.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		iconDragging = true
		iconDragStart = input.Position
		iconStartPos = miniIcon.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if iconDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - iconDragStart
		miniIcon.Position = UDim2.new(iconStartPos.X.Scale, iconStartPos.X.Offset + delta.X, iconStartPos.Y.Scale, iconStartPos.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if iconDragging then
			local delta = input.Position - iconDragStart
			if math.abs(delta.X) < 5 and math.abs(delta.Y) < 5 then
				miniIcon.Visible = false
				main.Visible = true
				main.ClipsDescendants = true
				main.Size = UDim2.new(0, 0, 0, 0)
				main.BackgroundTransparency = 1
				main.Rotation = 0

				local targetSize = savedSize or GetDefaultSize()
				local targetPos = savedPos or UDim2.fromScale(0.5, 0.5)
				main.Position = targetPos

				TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = targetSize, BackgroundTransparency = 0}):Play()
				TweenService:Create(mainStroke, TweenInfo.new(0.20), {Transparency = 0.08}):Play()

				task.delay(0.4, function()
					main.ClipsDescendants = true
					if currentTab ~= "settings" then Refresh(true) end
				end)
			end
		end
		iconDragging = false
	end
end)

maxBtn.MouseButton1Click:Connect(function()
    if not main or not main.Parent or not main.Visible then return end
    main.ClipsDescendants = true
    if not isMaximized then
        maximizeRestorePos = main.Position
        maximizeRestoreSize = main.Size
        isMaximized = true
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        local target = UDim2.new(0, math.max(280, math.floor(vp.X * 0.90)), 0, math.max(260, math.floor(vp.Y * 0.90)))
        TweenService:Create(main, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = target,
            Position = UDim2.fromScale(0.5,0.5)
        }):Play()
    else
        isMaximized = false
        TweenService:Create(main, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = maximizeRestoreSize or GetDefaultSize(),
            Position = maximizeRestorePos or UDim2.fromScale(0.5,0.5)
        }):Play()
    end
    task.delay(0.28, function()
        if main and main.Parent and currentTab ~= "settings" then Refresh(false, true) end
    end)
end)

minBtn.MouseButton1Click:Connect(function()
	main.ClipsDescendants = true
	savedPos = main.Position
	savedSize = main.Size

	TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
	TweenService:Create(mainStroke, TweenInfo.new(0.20), {Transparency = 1}):Play()

	task.delay(0.3, function()
		main.Visible = false
		miniIcon.Visible = true
	end)
end)

local function _CleanupScript()
	pcall(function() _heartbeatConn:Disconnect() end)
	pcall(function() if _hxChamferConn then _hxChamferConn:Disconnect() end end)
	pcall(function() _charAddedConn:Disconnect() end)
	pcall(function() if _keybindInputConn then _keybindInputConn:Disconnect() end end)
	pcall(function() DisableCopyEmotePrompts() end)
	pcall(function() StopHUDTracking() end)
	pcall(function() HXAcrylic.Stop() end)
	pcall(function() StopEmote(false) end)
	_genv().HXEmotesCleanup = nil
	_genv().lastHXEmote = nil
	_genv().autoReloadEnabled_HX = nil
	pcall(function() gui:Destroy() end)
end

_genv().HXEmotesCleanup = _CleanupScript

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
	main.ClipsDescendants = true
	TweenService:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1
	}):Play()
	task.delay(0.22, _CleanupScript)
end)
end
end


do
local dragging, dragStart, startPos = false, nil, nil

local function StartDrag(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end

titleBar.InputBegan:Connect(StartDrag)
sidebar.InputBegan:Connect(StartDrag)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local resizeS = isMobile and 28 or 22
resizeBtn = Instance.new("TextButton")
resizeBtn.Size = UDim2.new(0, resizeS, 0, resizeS)
resizeBtn.Position = UDim2.new(1, -resizeS - 3, 1, -resizeS - 3)
resizeBtn.BackgroundColor3 = currentTheme.stroke
resizeBtn.BackgroundTransparency = 0.4
resizeBtn.Text = "/"
resizeBtn.TextColor3 = currentTheme.textDim
resizeBtn.TextSize = isMobile and 12 or 14
resizeBtn.ZIndex = 100
resizeBtn.Parent = main
resizeBtn.Visible = false
Instance.new("UICorner", resizeBtn).CornerRadius = UDim.new(0, 8)

do
local resizing, resizeStart, sizeStart = false, nil, nil
local lastRefreshTime = 0

resizeBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStart = input.Position
		sizeStart = main.AbsoluteSize
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - resizeStart
		local minH = isMobile and 330 or 400
		local newW = math.clamp(sizeStart.X + delta.X, isMobile and 300 or 620, 1000)
		local newH = math.clamp(sizeStart.Y + delta.Y, minH, 700)
		main.Size = UDim2.new(0, newW, 0, newH)

		local now = tick()
		if now - lastRefreshTime > 0.1 then
			lastRefreshTime = now
			if currentTab ~= "settings" then Refresh(false) end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and resizing then
		resizing = false
		if currentTab ~= "settings" then Refresh(false) end
	end
end)
end
end


_genv().autoReloadEnabled_HX = Settings.loopEmote

local _charAddedConn = player.CharacterAdded:Connect(function(newChar)
	local newHum = newChar:WaitForChild("Humanoid", 5)
	if not newHum then return end


	if lastHXAnimationPack then
		task.wait(0.5)
		local newAnimate = newChar:WaitForChild("Animate", 5)
		if newAnimate then
			pcall(function() EquipAnimationPack(lastHXAnimationPack) end)
		end
	end

	if _genv().lastHXEmote and _genv().autoReloadEnabled_HX then
		task.wait(1)
		PlayEmote(_genv().lastHXEmote.id, _genv().lastHXEmote.name, true)
		Notify(L.ready, isES and "Emote reaplicado" or "Emote reapplied")
	end
end)


main.Rotation = 0
local openSize = GetDefaultSize()
TweenService:Create(main, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Size = openSize, BackgroundTransparency = 0}):Play()
TweenService:Create(mainStroke, TweenInfo.new(0.20), {Transparency = 0.08}):Play()

task.wait(0.5)

main.ClipsDescendants = true
ApplyTheme(Settings.theme)
UpdateTabStyles()
UpdateTabData()
local function HXAutoChamferControl(obj)
    if not obj or not obj.Parent or not main or not obj:IsDescendantOf(main) then return end
    if obj:GetAttribute("HXChamfer") then return end
    local n = tostring(obj.Name or "")
    if n:find("Overlay") or n == "GrabArea" then return end

    if obj:IsA("TextBox") then
        HXApplyChamfer(obj, {transparent=true, cut=isMobile and 6 or 8})
        return
    end

    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
        if obj.BackgroundTransparency >= 0.95 then return end
        local a = obj.AbsoluteSize
        local m = main.AbsoluteSize
        if m.X > 0 and m.Y > 0 and a.X > m.X * 0.72 and a.Y > m.Y * 0.45 then return end
        HXApplyChamfer(obj, {transparent=true, cut=isMobile and 5 or 7})
    elseif obj:IsA("Frame") and obj.Name == "EmoteCard" then
        HXApplyChamfer(obj, {transparent=false, cut=isMobile and 6 or 8})
    end
end

for _, _hxObj in ipairs(main:GetDescendants()) do
    pcall(HXAutoChamferControl, _hxObj)
end

_hxChamferConn = gui.DescendantAdded:Connect(function(obj)
    task.defer(function()
        task.wait()
        if obj and obj.Parent then pcall(HXAutoChamferControl, obj) end
    end)
end)


local _keybindInputConn = nil
if not isMobile then
	_keybindInputConn = UserInputService.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local keyName = inp.KeyCode.Name
		for emoteId, kb in pairs(KeybindsSet) do
			if type(kb) == "table" and kb.key == keyName then
				local emote = EmotesById[emoteId]
				if emote then
					PlayEmote(emote.id, emote.name)
				end
				break
			end
		end
	end)
end

task.wait(0.25)
Notify(L.ready, L.emotesAvailable:format(#Emotes))

local function _HXExtend()


local HUD, infoPanel, infoSpeedLbl, comboSlots, comboQueue_UI
local _currentInfoId, _currentInfoName
local _comboLoopEnabled = false
local _comboLoopList    = {}


local ShowEmoteHUD, HideEmoteHUD

local ComboQueue    = {}
local isComboActive = false

local function PlayComboStep(emoteId, emoteName)
	local animator = GetAnimator()
	if not animator then return end

	if currentAnimTrack and currentAnimTrack.IsPlaying then
		currentAnimTrack:Stop(0.3)
		task.wait(0.08)
	end

	local anim = _animCache[emoteId]
	if not anim then
		pcall(function()
			local ok, objects = pcall(function()
				return game:GetObjects("rbxassetid://" .. emoteId)
			end)
			if ok and objects and #objects > 0 then
				local item = objects[1]
				anim = item:IsA("Animation") and item
					or item:FindFirstChildWhichIsA("Animation", true)
			end
			if not anim then
				anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://" .. emoteId
			end
			_animCache[emoteId] = anim
		end)
	end
	if not anim then return end

	pcall(function()
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped   = false

		track:Play(0.3)
		task.delay(0.05, function()
			if track.IsPlaying then
				pcall(function()
					track:AdjustWeight(math.clamp(tonumber(Settings.animationWeight) or 1, 0.2, 1), 0.08)
					track:AdjustSpeed(HXEffectiveSpeed())
				end)
			end
		end)

		currentAnimTrack = track
		_genv().lastHXEmote = {id = emoteId, name = emoteName}
		AddToRecent(emoteId)

		task.defer(function()
			if ShowEmoteHUD then ShowEmoteHUD(emoteId, emoteName) end
		end)

		track.Stopped:Connect(function()
			if not isComboActive then return end
			if #ComboQueue > 0 then
				local nxt = table.remove(ComboQueue, 1)
				PlayComboStep(nxt.id, nxt.name)
			else
				if _comboLoopEnabled and #_comboLoopList > 0 then
					ComboQueue = {}
					for i = 2, #_comboLoopList do
						ComboQueue[#ComboQueue + 1] = _comboLoopList[i]
					end
					PlayComboStep(_comboLoopList[1].id, _comboLoopList[1].name)
				else
					isComboActive = false
					task.defer(function()
						if HideEmoteHUD then HideEmoteHUD() end
					end)
					task.defer(function()
						if comboQueue_UI then comboQueue_UI = {} end
						if comboSlots then
							for j = 1, 3 do
								if comboSlots[j] then
									comboSlots[j].Text = L.slotLabel .. " " .. j
									TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
										BackgroundColor3 = Color3.fromRGB(31, 31, 31)
									}):Play()
								end
							end
						end
					end)
				end
			end
		end)
	end)
end

local function StartCombo(emoteList)
	if #emoteList == 0 then return end
	isComboActive = true
	_comboLoopList = {}
	for _, e in ipairs(emoteList) do
		_comboLoopList[#_comboLoopList + 1] = {id = e.id, name = e.name}
	end
	ComboQueue = {}
	for i = 2, #emoteList do
		ComboQueue[#ComboQueue + 1] = emoteList[i]
	end
	PlayComboStep(emoteList[1].id, emoteList[1].name)
end


local hudTrackerConn = nil
local _hudHideToken  = 0

HUD = Instance.new("Frame")
HUD.Name                   = "HXEmotesHUD"
HUD.Size                   = isMobile and UDim2.new(0, 320, 0, 100) or UDim2.new(0, 500, 0, 104)
HUD.Position               = UDim2.new(0.5, 0, 1, -120)
HUD.AnchorPoint            = Vector2.new(0.5, 1)
HUD.BackgroundColor3       = Color3.fromRGB(8, 8, 8)
HUD.BackgroundTransparency = 0.30
HUD.BorderSizePixel        = 0
HUD.Visible                = false
HUD.ZIndex                 = 500
HUD.ClipsDescendants       = false
HUD.Parent                 = gui
Instance.new("UICorner", HUD).CornerRadius = UDim.new(0, 14)

syncNotice = Instance.new("TextLabel")
syncNotice.Name = "SyncNotice"
syncNotice.Size = UDim2.new(1, 0, 0, 20)
syncNotice.Position = UDim2.new(0, 0, 1, 4)
syncNotice.BackgroundTransparency = 1
syncNotice.Text = ""
syncNotice.TextColor3 = Color3.new(1, 1, 1)
syncNotice.TextTransparency = 0.4
syncNotice.Font = Enum.Font.GothamMedium
syncNotice.TextSize = 11
syncNotice.Visible = false
syncNotice.ZIndex = 500
syncNotice.Parent = HUD

hudStroke = Instance.new("UIStroke")
hudStroke.Color        = currentTheme.stroke
hudStroke.Thickness    = 1.5
hudStroke.Transparency = 0.25
hudStroke.Parent       = HUD

hudFavBtn = Instance.new("ImageButton")
hudFavBtn.Size                   = UDim2.new(0, 22, 0, 22)
hudFavBtn.Position               = UDim2.new(0, 9, 0, 6)
hudFavBtn.BackgroundColor3       = Color3.fromRGB(31, 31, 31)
hudFavBtn.BackgroundTransparency = 0.20
hudFavBtn.Image                  = ResolveAssetImage(Icons.FavoriteEmpty)
hudFavBtn.ImageColor3            = Color3.fromRGB(255,255,255)
hudFavBtn.ZIndex                 = 502
hudFavBtn.Parent                 = HUD
Instance.new("UICorner", hudFavBtn).CornerRadius = UDim.new(1, 0)

local function RefreshHUDFavBtn()
	if not _currentInfoId then return end
	local isFav = IsFavorite(_currentInfoId)
	hudFavBtn.Image      = ResolveAssetImage(isFav and Icons.FavoriteFull or Icons.FavoriteEmpty)
	TweenService:Create(hudFavBtn, TweenInfo.new(0.15), {
		ImageColor3      = Color3.fromRGB(255,255,255),
		BackgroundColor3 = isFav and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(31, 31, 31)
	}):Play()
end

hudFavBtn.MouseButton1Click:Connect(function()
	if not _currentInfoId then return end
	ToggleFavorite(_currentInfoId)
	RefreshHUDFavBtn()
end)

hudInfoBtn = Instance.new("TextButton")
hudInfoBtn.Size                   = UDim2.new(0, 22, 0, 22)
hudInfoBtn.Position               = UDim2.new(0, 9, 0, 32)
hudInfoBtn.BackgroundColor3       = currentTheme.accent
hudInfoBtn.BackgroundTransparency = 0.40
hudInfoBtn.Text                   = "i"
hudInfoBtn.TextColor3             = Color3.new(1, 1, 1)
hudInfoBtn.Font                   = Enum.Font.GothamBold
hudInfoBtn.TextSize               = 12
hudInfoBtn.ZIndex                 = 502
hudInfoBtn.Parent                 = HUD
Instance.new("UICorner", hudInfoBtn).CornerRadius = UDim.new(1, 0)

hudName = Instance.new("TextLabel")
hudName.Size                   = UDim2.new(1, -130, 0, 22)
hudName.Position               = UDim2.new(0, 44, 0, 7)
hudName.BackgroundTransparency = 1
hudName.Text                   = ""
hudName.TextColor3             = Color3.new(1, 1, 1)
hudName.Font                   = Enum.Font.GothamBold
hudName.TextSize               = isMobile and 13 or 15
hudName.TextXAlignment         = Enum.TextXAlignment.Left
hudName.TextTruncate           = Enum.TextTruncate.AtEnd
hudName.ZIndex                 = 501
hudName.Parent                 = HUD

hudCreator = Instance.new("TextLabel")
hudCreator.Size                   = UDim2.new(1, -130, 0, 15)
hudCreator.Position               = UDim2.new(0, 44, 0, 30)
hudCreator.BackgroundTransparency = 1
hudCreator.Text                   = "Emotes"
hudCreator.TextColor3             = Color3.fromRGB(122, 122, 122)
hudCreator.Font                   = Enum.Font.Gotham
hudCreator.TextSize               = isMobile and 10 or 11
hudCreator.TextXAlignment         = Enum.TextXAlignment.Left
hudCreator.ZIndex                 = 501
hudCreator.Parent                 = HUD

hudSliderBg = Instance.new("Frame")
hudSliderBg.Size             = UDim2.new(1, -148, 0, 4)
hudSliderBg.Position         = UDim2.new(0, 44, 0, 54)
hudSliderBg.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
hudSliderBg.ZIndex           = 501
hudSliderBg.Parent           = HUD
Instance.new("UICorner", hudSliderBg).CornerRadius = UDim.new(1, 0)

hudFill = Instance.new("Frame")
hudFill.Size             = UDim2.new(0, 0, 1, 0)
hudFill.BackgroundColor3 = currentTheme.accent
hudFill.ZIndex           = 502
hudFill.Parent           = hudSliderBg
Instance.new("UICorner", hudFill).CornerRadius = UDim.new(1, 0)

hudKnob = Instance.new("TextButton")
hudKnob.Size             = UDim2.new(0, 12, 0, 12)
hudKnob.AnchorPoint      = Vector2.new(0.5, 0.5)
hudKnob.Position         = UDim2.new(0, 0, 0.5, 0)
hudKnob.BackgroundColor3 = Color3.new(1, 1, 1)
hudKnob.Text             = ""
hudKnob.ZIndex           = 503
hudKnob.Parent           = hudSliderBg
Instance.new("UICorner", hudKnob).CornerRadius = UDim.new(1, 0)

hudPauseBtn = Instance.new("ImageButton")
hudPauseBtn.Size                   = UDim2.new(0, 60, 0, 22)
hudPauseBtn.AnchorPoint            = Vector2.new(0.5, 0)
hudPauseBtn.Position               = UDim2.new(0.5, 0, 0, 66)
hudPauseBtn.BackgroundColor3       = Color3.fromRGB(31, 31, 31)
hudPauseBtn.BackgroundTransparency = 0.10
hudPauseBtn.Image                  = ResolveAssetImage("rbxassetid://113416463749658")
hudPauseBtn.ImageColor3            = Color3.new(1, 1, 1)
hudPauseBtn.ScaleType              = Enum.ScaleType.Fit
hudPauseBtn.ZIndex                 = 503
hudPauseBtn.Parent                 = HUD
Instance.new("UICorner", hudPauseBtn).CornerRadius = UDim.new(0, 7)

hudPauseBtnStroke = Instance.new("UIStroke")
hudPauseBtnStroke.Color       = currentTheme.stroke
hudPauseBtnStroke.Thickness   = 1
hudPauseBtnStroke.Transparency = 0.40
hudPauseBtnStroke.Parent      = hudPauseBtn

local function RefreshHudPauseBtn()
	if _isPaused then
		hudPauseBtn.Image = ResolveAssetImage("rbxassetid://129338178452237")
		hudPauseBtn.BackgroundColor3 = currentTheme.accent
	else
		hudPauseBtn.Image = ResolveAssetImage("rbxassetid://113416463749658")
		hudPauseBtn.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	end
end

hudPauseBtn.MouseButton1Click:Connect(function()
	if currentAnimTrack and _isPaused then
		pcall(function() currentAnimTrack:AdjustSpeed(HXEffectiveSpeed()) end)
		_SetPauseState(false)
	elseif currentAnimTrack and currentAnimTrack.IsPlaying then
		pcall(function() currentAnimTrack:AdjustSpeed(0) end)
		_SetPauseState(true)
	end
end)

_onPauseStateChanged = function(paused)
	RefreshHudPauseBtn()
end

local HUD_SPEEDS = {0.1, 0.5, 1, 1.5, 2}
local HUD_LABELS = {"0.1", "0.5", "1x", "1.5", "2x"}
local hudSpeedBtns = {}
local spBtnW   = isMobile and 26 or 30
local spBtnGap = 3
local spTotalW = #HUD_SPEEDS * spBtnW + (#HUD_SPEEDS - 1) * spBtnGap

local function RefreshHUDSpeedBtns()
	for i, btn in ipairs(hudSpeedBtns) do
		local active = math.abs(HUD_SPEEDS[i] - Settings.speed) < 0.01
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = active and currentTheme.accent or Color3.fromRGB(31, 31, 31)
		}):Play()
	end
end

for si, spd in ipairs(HUD_SPEEDS) do
	local xOff = -(spTotalW + 8) + (si - 1) * (spBtnW + spBtnGap)
	local sBtn = Instance.new("TextButton")
	sBtn.Size                   = UDim2.new(0, spBtnW, 0, 20)
	sBtn.Position               = UDim2.new(1, xOff, 0, 7)
	sBtn.BackgroundColor3       = (math.abs(spd - Settings.speed) < 0.01)
		and currentTheme.accent or Color3.fromRGB(31, 31, 31)
	sBtn.BackgroundTransparency = 0.15
	sBtn.Text                   = HUD_LABELS[si]
	sBtn.TextColor3             = Color3.new(1, 1, 1)
	sBtn.Font                   = Enum.Font.GothamBold
	sBtn.TextSize               = 10
	sBtn.ZIndex                 = 502
	sBtn.Parent                 = HUD
	Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 5)
	hudSpeedBtns[si] = sBtn

	sBtn.MouseButton1Click:Connect(function()
		Settings.speed = spd
		if currentAnimTrack and currentAnimTrack.IsPlaying then
			pcall(function() currentAnimTrack:AdjustSpeed((Settings.reversePlayback and -1 or 1) * spd) end)
		end
		RefreshHUDSpeedBtns()
		SaveData()
	end)
end

infoPanel = Instance.new("Frame")
infoPanel.Name                   = "HXEmotesInfoPanel"
infoPanel.Size                   = UDim2.new(0, 270, 0, 260)
infoPanel.Position               = UDim2.new(0, -290, 1, -285)
infoPanel.BackgroundColor3       = Color3.fromRGB(11, 11, 11)
infoPanel.BackgroundTransparency = 0.08
infoPanel.BorderSizePixel        = 0
infoPanel.Visible                = false
infoPanel.ZIndex                 = 700
infoPanel.Parent                 = gui
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 14)

infoPanelStroke = Instance.new("UIStroke")
infoPanelStroke.Color       = currentTheme.accent
infoPanelStroke.Thickness   = 1.5
infoPanelStroke.Transparency = 0.30
infoPanelStroke.Parent      = infoPanel

infoPanelTitle = Instance.new("Frame")
infoPanelTitle.Size             = UDim2.new(1, 0, 0, 36)
infoPanelTitle.BackgroundColor3 = currentTheme.accent
infoPanelTitle.BackgroundTransparency = 0.55
infoPanelTitle.ZIndex           = 701
infoPanelTitle.Active           = true
infoPanelTitle.Parent           = infoPanel
Instance.new("UICorner", infoPanelTitle).CornerRadius = UDim.new(0, 14)
infoPanelTitleOverlay = Instance.new("Frame")
infoPanelTitleOverlay.Size             = UDim2.new(1, 0, 0, 14)
infoPanelTitleOverlay.Position         = UDim2.new(0, 0, 1, -14)
infoPanelTitleOverlay.BackgroundColor3 = currentTheme.accent
infoPanelTitleOverlay.BackgroundTransparency = 0.55
infoPanelTitleOverlay.BorderSizePixel  = 0
infoPanelTitleOverlay.ZIndex           = 701
infoPanelTitleOverlay.Parent           = infoPanelTitle

local infoPanelTitleIcon = Instance.new("ImageLabel")
infoPanelTitleIcon.Size             = UDim2.new(0, 20, 0, 20)
infoPanelTitleIcon.Position         = UDim2.new(0, 10, 0.5, -10)
infoPanelTitleIcon.BackgroundTransparency = 1
infoPanelTitleIcon.Image            = ResolveAssetImage(Icons.Info)
infoPanelTitleIcon.ImageColor3      = Color3.new(1, 1, 1)
infoPanelTitleIcon.ZIndex           = 702
infoPanelTitleIcon.Parent           = infoPanelTitle

infoPanelTitleLbl = Instance.new("TextLabel")
infoPanelTitleLbl.Size                   = UDim2.new(1, -62, 1, 0)
infoPanelTitleLbl.Position               = UDim2.new(0, 36, 0, 0)
infoPanelTitleLbl.BackgroundTransparency = 1
infoPanelTitleLbl.Text                   = L.infoTitle
infoPanelTitleLbl.TextColor3             = Color3.new(1, 1, 1)
infoPanelTitleLbl.Font                   = Enum.Font.GothamBold
infoPanelTitleLbl.TextSize               = 14
infoPanelTitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoPanelTitleLbl.ZIndex                 = 702
infoPanelTitleLbl.Parent                 = infoPanelTitle

infoPanelClose = Instance.new("TextButton")
infoPanelClose.Size             = UDim2.new(0, 24, 0, 24)
infoPanelClose.Position         = UDim2.new(1, -30, 0.5, -12)
infoPanelClose.BackgroundColor3 = Color3.fromRGB(94, 94, 94)
infoPanelClose.BackgroundTransparency = 0.30
infoPanelClose.Text             = ""
infoPanelClose.ZIndex           = 703
infoPanelClose.Parent           = infoPanelTitle
Instance.new("UICorner", infoPanelClose).CornerRadius = UDim.new(1, 0)

do
	local thick = 2
	local lineLen = 10
	local cl1 = Instance.new("Frame")
	cl1.BorderSizePixel = 0
	cl1.Size       = UDim2.new(0, lineLen, 0, thick)
	cl1.AnchorPoint = Vector2.new(0.5, 0.5)
	cl1.Position   = UDim2.fromScale(0.5, 0.5)
	cl1.Rotation   = 45
	cl1.BackgroundColor3 = Color3.new(1, 1, 1)
	cl1.ZIndex     = 704
	cl1.Parent     = infoPanelClose
	Instance.new("UICorner", cl1).CornerRadius = UDim.new(0, 2)
	local cl2 = cl1:Clone()
	cl2.Rotation  = -45
	cl2.Parent    = infoPanelClose
end

infoPanelBody = Instance.new("Frame")
infoPanelBody.Size                   = UDim2.new(1, -24, 1, -46)
infoPanelBody.Position               = UDim2.new(0, 12, 0, 42)
infoPanelBody.BackgroundTransparency = 1
infoPanelBody.ZIndex                 = 701
infoPanelBody.Parent                 = infoPanel

infoEmoteName = Instance.new("TextLabel")
infoEmoteName.Size                   = UDim2.new(1, 0, 0, 22)
infoEmoteName.Position               = UDim2.new(0, 0, 0, 0)
infoEmoteName.BackgroundTransparency = 1
infoEmoteName.Text                   = "—"
infoEmoteName.TextColor3             = Color3.new(1, 1, 1)
infoEmoteName.Font                   = Enum.Font.GothamBold
infoEmoteName.TextSize               = 16
infoEmoteName.TextXAlignment         = Enum.TextXAlignment.Left
infoEmoteName.TextTruncate           = Enum.TextTruncate.AtEnd
infoEmoteName.ZIndex                 = 702
infoEmoteName.Parent                 = infoPanelBody

infoDescLbl = Instance.new("TextLabel")
infoDescLbl.Size                   = UDim2.new(1, 0, 0, 28)
infoDescLbl.Position               = UDim2.new(0, 0, 0, 24)
infoDescLbl.BackgroundTransparency = 1
infoDescLbl.Text                   = "—"
infoDescLbl.TextColor3             = Color3.fromRGB(142, 142, 142)
infoDescLbl.Font                   = Enum.Font.Gotham
infoDescLbl.TextSize               = 11
infoDescLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoDescLbl.TextYAlignment         = Enum.TextYAlignment.Top
infoDescLbl.TextWrapped            = true
infoDescLbl.ZIndex                 = 702
infoDescLbl.Parent                 = infoPanelBody

infoDivider = Instance.new("Frame")
infoDivider.Size             = UDim2.new(1, 0, 0, 1)
infoDivider.Position         = UDim2.new(0, 0, 0, 56)
infoDivider.BackgroundColor3 = Color3.fromRGB(61, 61, 61)
infoDivider.BorderSizePixel  = 0
infoDivider.ZIndex           = 702
infoDivider.Parent           = infoPanelBody

do
	local ic = Instance.new("ImageLabel")
	ic.Size = UDim2.new(0, 13, 0, 13); ic.Position = UDim2.new(0, 0, 0, 63)
	ic.BackgroundTransparency = 1; ic.Image = Icons.Crown; ic.ZIndex = 702
	ic.Parent = infoPanelBody
end
infoCreatorLbl = Instance.new("TextLabel")
infoCreatorLbl.Size                   = UDim2.new(1, -18, 0, 16)
infoCreatorLbl.Position               = UDim2.new(0, 18, 0, 61)
infoCreatorLbl.BackgroundTransparency = 1
infoCreatorLbl.Text                   = "—"
infoCreatorLbl.TextColor3             = Color3.fromRGB(191, 191, 191)
infoCreatorLbl.Font                   = Enum.Font.Gotham
infoCreatorLbl.TextSize               = 12
infoCreatorLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoCreatorLbl.ZIndex                 = 702
infoCreatorLbl.Parent                 = infoPanelBody

do
	local ic = Instance.new("ImageLabel")
	ic.Size = UDim2.new(0, 13, 0, 13); ic.Position = UDim2.new(0, 0, 0, 83)
	ic.BackgroundTransparency = 1; ic.Image = Icons.Emote; ic.ZIndex = 702
	ic.Parent = infoPanelBody
end
infoSpeedLbl = Instance.new("TextLabel")
infoSpeedLbl.Size                   = UDim2.new(1, -18, 0, 16)
infoSpeedLbl.Position               = UDim2.new(0, 18, 0, 81)
infoSpeedLbl.BackgroundTransparency = 1
infoSpeedLbl.Text                   = L.speed .. ": 1x"
infoSpeedLbl.TextColor3             = Color3.fromRGB(162, 162, 162)
infoSpeedLbl.Font                   = Enum.Font.Gotham
infoSpeedLbl.TextSize               = 12
infoSpeedLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoSpeedLbl.ZIndex                 = 702
infoSpeedLbl.Parent                 = infoPanelBody

_onSpeedChanged = function()
	RefreshHUDSpeedBtns()
	if infoSpeedLbl then
		infoSpeedLbl.Text = L.speed .. ": " .. tostring(Settings.speed) .. "x"
	end
end

infoPriceLbl = Instance.new("TextLabel")
infoPriceLbl.Size                   = UDim2.new(1, 0, 0, 16)
infoPriceLbl.Position               = UDim2.new(0, 0, 0, 101)
infoPriceLbl.BackgroundTransparency = 1
infoPriceLbl.Text                   = "—"
infoPriceLbl.TextColor3             = Color3.fromRGB(162, 162, 162)
infoPriceLbl.Font                   = Enum.Font.GothamBold
infoPriceLbl.TextSize               = 12
infoPriceLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoPriceLbl.ZIndex                 = 702
infoPriceLbl.Parent                 = infoPanelBody

infoFavLbl = Instance.new("TextLabel")
infoFavLbl.Size                   = UDim2.new(1, 0, 0, 16)
infoFavLbl.Position               = UDim2.new(0, 0, 0, 120)
infoFavLbl.BackgroundTransparency = 1
infoFavLbl.Text                   = "—"
infoFavLbl.TextColor3             = Color3.fromRGB(162, 162, 162)
infoFavLbl.Font                   = Enum.Font.Gotham
infoFavLbl.TextSize               = 12
infoFavLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoFavLbl.ZIndex                 = 702
infoFavLbl.Parent                 = infoPanelBody

do
	local ic = Instance.new("ImageLabel")
	ic.Size = UDim2.new(0, 13, 0, 13); ic.Position = UDim2.new(0, 0, 0, 141)
	ic.BackgroundTransparency = 1; ic.Image = Icons.Recent; ic.ZIndex = 702
	ic.Parent = infoPanelBody
end
infoDateLbl = Instance.new("TextLabel")
infoDateLbl.Size                   = UDim2.new(1, -18, 0, 16)
infoDateLbl.Position               = UDim2.new(0, 18, 0, 139)
infoDateLbl.BackgroundTransparency = 1
infoDateLbl.Text                   = "—"
infoDateLbl.TextColor3             = Color3.fromRGB(132, 132, 132)
infoDateLbl.Font                   = Enum.Font.Gotham
infoDateLbl.TextSize               = 11
infoDateLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoDateLbl.ZIndex                 = 702
infoDateLbl.Parent                 = infoPanelBody


local copyIdBtn = Instance.new("TextButton")
copyIdBtn.Size             = UDim2.new(0.52, -2, 0, 26)
copyIdBtn.Position         = UDim2.new(0.48, 2, 0, 161)
copyIdBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
copyIdBtn.Text             = L.copyId
copyIdBtn.TextColor3       = Color3.fromRGB(182, 182, 182)
copyIdBtn.Font             = Enum.Font.GothamBold
copyIdBtn.TextSize         = 12
copyIdBtn.ZIndex           = 703
copyIdBtn.Parent           = infoPanelBody
Instance.new("UICorner", copyIdBtn).CornerRadius = UDim.new(0, 8)
local copyIdStroke = Instance.new("UIStroke")
copyIdStroke.Color       = Color3.fromRGB(72, 72, 72)
copyIdStroke.Thickness   = 1
copyIdStroke.Parent      = copyIdBtn

local infoIdLbl = nil

local infoPanelOpen = false
local INFO_OPEN_POS  = UDim2.new(0, 10, 1, -285)
local INFO_CLOSE_POS = UDim2.new(0, -290, 1, -285)

local _copyIdTarget = 0

local function _applyMetaToInfoPanel(meta)
	infoCreatorLbl.Text = (meta.creatorName and meta.creatorName ~= "") and meta.creatorName or "—"
	infoDescLbl.Text    = (meta.description and meta.description ~= "") and meta.description or L.noDesc
	if meta.priceStatus == "Free" or meta.price == 0 then
		infoPriceLbl.Text       = L.freePrice
		infoPriceLbl.TextColor3 = Color3.fromRGB(188, 188, 188)
	elseif meta.price and meta.price > 0 then
		infoPriceLbl.Text       = tostring(meta.price) .. " R$"
		infoPriceLbl.TextColor3 = Color3.fromRGB(203, 203, 203)
	else
		infoPriceLbl.Text       = (meta.priceStatus == "Not for sale" and (isES and "No está en venta" or "Not for sale")) or ((meta.priceStatus and meta.priceStatus ~= "") and meta.priceStatus or "—")
		infoPriceLbl.TextColor3 = Color3.fromRGB(162, 162, 162)
	end
	infoFavLbl.Text = meta.favoriteCount
		and ("♥ " .. tostring(meta.favoriteCount))
		or "—"
	if meta.createdUtc and meta.createdUtc ~= "" then
		infoDateLbl.Text = meta.createdUtc:sub(1, 10)
	else
		infoDateLbl.Text = "—"
	end
	hudCreator.Text = (meta.creatorName and meta.creatorName ~= "") and meta.creatorName or "Emotes"
end

local function _fetchAndCacheMeta(numId, targetId)
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(numId)
	end)
	if not ok or not info then return end

	local price      = info.PriceInRobux
	local isFree     = info.IsPublicDomain or (price and price == 0)
	local isNotSale  = info.IsForSale == false and not isFree

	local meta = {
		creatorName   = tostring((info.Creator and info.Creator.Name) or ""),
		description   = tostring(info.Description or ""),
		price         = isFree and 0 or price,
		priceStatus   = isFree and "Free" or (isNotSale and "Not for sale" or ""),
		favoriteCount = nil,
		createdUtc    = "",
	}

	_emoteMetaCache[numId] = meta

	local eData = EmotesById[numId]
	if eData then
		eData.creatorName   = meta.creatorName
		eData.description   = meta.description
		eData.price         = meta.price
		eData.priceStatus   = meta.priceStatus
		eData.favoriteCount = meta.favoriteCount
		eData.createdUtc    = meta.createdUtc
	end

	if infoPanelOpen and _copyIdTarget == numId then
		_applyMetaToInfoPanel(meta)
	end
end

local function OpenInfoPanel(emoteId, emoteName)
	infoEmoteName.Text  = emoteName and LocalizeEmoteName(emoteName) or "—"
	infoSpeedLbl.Text   = L.speed .. ": " .. tostring(Settings.speed) .. "x"
	infoPanelStroke.Color           = currentTheme.accent
	infoPanelTitle.BackgroundColor3 = currentTheme.accent
	_copyIdTarget = tonumber(emoteId) or 0

	local numId = tonumber(emoteId)

	local meta = _emoteMetaCache[numId]
	if not meta then
		local eData = EmotesById[numId]
		if eData and eData.creatorName ~= "" then
			meta = eData
		end
	end

	if meta then
		_applyMetaToInfoPanel(meta)
	else
		infoCreatorLbl.Text = "…"
		infoDescLbl.Text    = "…"
		infoPriceLbl.Text   = "…"
		infoPriceLbl.TextColor3 = Color3.fromRGB(162, 162, 162)
		infoFavLbl.Text     = "…"
		infoDateLbl.Text    = "…"
		hudCreator.Text     = "Emotes"
		if numId and numId > 0 then
			task.spawn(_fetchAndCacheMeta, numId, numId)
		end
	end

	copyIdBtn.Text = L.copyId .. ": " .. tostring(numId)

	infoPanel.Position = INFO_CLOSE_POS
	infoPanel.Visible  = true
	infoPanelOpen      = true
	TweenService:Create(infoPanel,
		TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = INFO_OPEN_POS}
	):Play()
	TweenService:Create(hudInfoBtn, TweenInfo.new(0.15),
		{BackgroundTransparency = 0.05}):Play()
end

copyIdBtn.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then
			setclipboard(tostring(_copyIdTarget))
		end
	end)
	local orig = copyIdBtn.Text
	copyIdBtn.Text            = L.copied
	copyIdBtn.TextColor3      = Color3.fromRGB(188, 188, 188)
	task.delay(1.5, function()
		copyIdBtn.Text       = orig
		copyIdBtn.TextColor3 = Color3.fromRGB(182, 182, 182)
	end)
end)

local function CloseInfoPanel()
	infoPanelOpen = false
	local curX = infoPanel.AbsolutePosition.X
	local curY = infoPanel.AbsolutePosition.Y
	local exitPos = UDim2.new(0, curX - 300, 0, curY)
	TweenService:Create(infoPanel,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = exitPos}
	):Play()
	TweenService:Create(hudInfoBtn, TweenInfo.new(0.15),
		{BackgroundTransparency = 0.40}):Play()
	task.delay(0.22, function()
		if not infoPanelOpen then infoPanel.Visible = false end
	end)
end

hudInfoBtn.MouseButton1Click:Connect(function()
	if infoPanelOpen then
		CloseInfoPanel()
	else
		OpenInfoPanel(_currentInfoId or 0, _currentInfoName or "Emote")
	end
end)
infoPanelClose.MouseButton1Click:Connect(CloseInfoPanel)

local _ipDragActive     = false
local _ipDragMouseStart = Vector2.zero
local _ipDragPanelStart = Vector2.zero

infoPanelTitle.InputBegan:Connect(function(inp)
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	_ipDragActive     = true
	_ipDragMouseStart = Vector2.new(inp.Position.X, inp.Position.Y)
	_ipDragPanelStart = Vector2.new(
		infoPanel.AbsolutePosition.X,
		infoPanel.AbsolutePosition.Y
	)
end)

UserInputService.InputChanged:Connect(function(inp)
	if not _ipDragActive then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = Vector2.new(inp.Position.X, inp.Position.Y) - _ipDragMouseStart
	infoPanel.Position = UDim2.new(0, _ipDragPanelStart.X + delta.X,
	                               0, _ipDragPanelStart.Y + delta.Y)
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		_ipDragActive = false
	end
end)

local hudKnobDragging = false

hudKnob.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		hudKnobDragging = true
	end
end)

hudSliderBg.InputBegan:Connect(function(inp)
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	if currentAnimTrack and currentAnimTrack.Length and currentAnimTrack.Length > 0 then
		local alpha = math.clamp(
			(inp.Position.X - hudSliderBg.AbsolutePosition.X) / hudSliderBg.AbsoluteSize.X,
			0, 1)
		pcall(function() currentAnimTrack.TimePosition = alpha * currentAnimTrack.Length end)
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		hudKnobDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(inp)
	if not hudKnobDragging then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	if currentAnimTrack and currentAnimTrack.Length and currentAnimTrack.Length > 0 then
		local alpha = math.clamp(
			(inp.Position.X - hudSliderBg.AbsolutePosition.X) / hudSliderBg.AbsoluteSize.X,
			0, 1)
		pcall(function() currentAnimTrack.TimePosition = alpha * currentAnimTrack.Length end)
	end
end)

local function StartHUDTracking()
	if hudTrackerConn then
		hudTrackerConn:Disconnect()
		hudTrackerConn = nil
	end

	hudTrackerConn = RunService.RenderStepped:Connect(function()
		if not currentAnimTrack or not currentAnimTrack.IsPlaying then return end
		local len = currentAnimTrack.Length
		if not len or len <= 0 then return end

		local alpha = math.clamp(currentAnimTrack.TimePosition / len, 0, 1)

		hudFill.Size     = UDim2.new(alpha, 0, 1, 0)
		hudKnob.Position = UDim2.new(alpha, 0, 0.5, 0)

		hudFill.BackgroundColor3    = currentTheme.accent
		hudStroke.Color             = currentTheme.stroke
		hudInfoBtn.BackgroundColor3 = currentTheme.accent
		infoPanelStroke.Color       = currentTheme.accent
	end)
end

local function StopHUDTracking()
	if hudTrackerConn then
		hudTrackerConn:Disconnect()
		hudTrackerConn = nil
	end
end

ShowEmoteHUD = function(emoteId, emoteName)
	if true then return end
	_hudHideToken = _hudHideToken + 1

	_currentInfoId   = emoteId
	_currentInfoName = emoteName

	RefreshHUDFavBtn()
	hudName.Text    = LocalizeEmoteName(emoteName or "Emote")
	hudCreator.Text = "Emotes"

	_isPaused = false
	RefreshHudPauseBtn()

	if infoPanelOpen then
		OpenInfoPanel(emoteId, emoteName)
	end

	local hasSync = false
	if FriendData and FriendData.syncEmote and FriendData.friends then
		for _, f in pairs(FriendData.friends) do
			if f.syncEnabled and f.online then
				hasSync = true
				break
			end
		end
	end
	if hasSync then
		syncNotice.Text = isES and "Tu emote se está enviando a tu amigo; puede tardar entre 5 y 10 segundos." or "Your emote is sending to your friend; this can take 5-10 seconds."
		syncNotice.Visible = true
	else
		syncNotice.Visible = false
	end

	local startY = isMobile and -20 or -88
	local endY = isMobile and -60 or -120

	HUD.Position               = UDim2.new(0.5, 0, 1, startY)
	HUD.BackgroundTransparency = 1
	HUD.Visible                = true

	TweenService:Create(HUD,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 1, endY), BackgroundTransparency = 0.30}
	):Play()

	RefreshHUDSpeedBtns()
	StartHUDTracking()
end

HideEmoteHUD = function()
	_isPaused = false
	RefreshHudPauseBtn()
	if _stopBtnSquare then _stopBtnSquare.Image = ResolveAssetImage("rbxassetid://113416463749658") end
	StopHUDTracking()
	local hideY = isMobile and -20 or -88
	TweenService:Create(HUD,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, 0, 1, hideY), BackgroundTransparency = 1}
	):Play()
	local token = _hudHideToken
	task.delay(0.22, function()
		if HUD and _hudHideToken == token then
			HUD.Visible = false
		end
	end)
	if infoPanelOpen then CloseInfoPanel() end
end


local _origPlayEmote = PlayEmote
PlayEmote = function(id, name, silent, syncStartTime)
	if tostring(id):find("anim_") then
		for _, pack in ipairs(AnimationPacks) do
			if pack.id == id then
				EquipAnimationPack(pack)
				break
			end
		end
		return
	end
	_origPlayEmote(id, name, silent, syncStartTime)
	local myToken = _hudHideToken + 1
	_hudHideToken = myToken
	task.defer(function()
		if _hudHideToken ~= myToken then return end
		if currentAnimTrack then
			ShowEmoteHUD(id, name)
			local tracked = currentAnimTrack
			tracked.Stopped:Connect(function()
				if (currentAnimTrack == tracked or not currentAnimTrack)
				and not isComboActive then
					HideEmoteHUD()
				end
			end)
		end
	end)
end

local _origStopEmote = StopEmote
StopEmote = function(showNotif)
	_origStopEmote(showNotif)
	isComboActive = false
	ComboQueue    = {}
	HideEmoteHUD()
end


comboQueue_UI = {}

local comboRow = MakeRow("", L.comboTitle, "", 25, 196)
comboRow.Size             = UDim2.new(1, 0, 0, 196)
comboRow.ClipsDescendants = true

local comboTitleLbl = comboRow:FindFirstChildWhichIsA("TextLabel")
if comboTitleLbl then
	comboTitleLbl.Size     = UDim2.new(1, -12, 0, 20)
	comboTitleLbl.Position = UDim2.new(0, 10, 0, 5)
	comboTitleLbl.TextSize = 13
end

slotHolder = Instance.new("Frame")
slotHolder.Size             = UDim2.new(1, -12, 0, 36)
slotHolder.Position         = UDim2.new(0, 6, 0, 28)
slotHolder.BackgroundTransparency = 1
slotHolder.ZIndex           = 9
slotHolder.Parent           = comboRow
slotLayout = Instance.new("UIListLayout")
slotLayout.FillDirection    = Enum.FillDirection.Horizontal
slotLayout.Padding          = UDim.new(0, 5)
slotLayout.Parent           = slotHolder

comboSlots = {}
for si = 1, 3 do
	local s = Instance.new("TextButton")
	s.Size             = UDim2.new(0.316, 0, 1, 0)
	s.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	s.Text             = L.slotLabel .. " " .. si
	s.TextColor3       = Color3.fromRGB(122, 122, 122)
	s.Font             = Enum.Font.Gotham
	s.TextSize         = 11
	s.ZIndex           = 9
	s.Parent           = slotHolder
	Instance.new("UICorner", s).CornerRadius = UDim.new(0, 8)
	comboSlots[si] = s
	s.MouseButton1Click:Connect(function()
		if comboQueue_UI[si] then
			table.remove(comboQueue_UI, si)
			for j = 1, 3 do
				local e = comboQueue_UI[j]
				comboSlots[j].Text = e and LocalizeEmoteName(e.name):sub(1,9) or (L.slotLabel .. " " .. j)
				TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
					BackgroundColor3 = e and currentTheme.accent or Color3.fromRGB(31, 31, 31)
				}):Play()
			end
		end
	end)
end

comboBtnHolder = Instance.new("Frame")
comboBtnHolder.Size             = UDim2.new(1, -12, 0, 30)
comboBtnHolder.Position         = UDim2.new(0, 6, 0, 70)
comboBtnHolder.BackgroundTransparency = 1
comboBtnHolder.ZIndex           = 9
comboBtnHolder.Parent           = comboRow
comboBtnLayout = Instance.new("UIListLayout")
comboBtnLayout.FillDirection    = Enum.FillDirection.Horizontal
comboBtnLayout.Padding          = UDim.new(0, 5)
comboBtnLayout.Parent           = comboBtnHolder

addComboBtn = Instance.new("TextButton")
addComboBtn.Size             = UDim2.new(0.5, -2, 1, 0)
addComboBtn.BackgroundColor3 = Color3.fromRGB(94, 94, 94)
addComboBtn.Text             = L.addEmote
addComboBtn.TextColor3       = Color3.new(1, 1, 1)
addComboBtn.Font             = Enum.Font.GothamBold
addComboBtn.TextSize         = 12
addComboBtn.ZIndex           = 9
addComboBtn.Parent           = comboBtnHolder
Instance.new("UICorner", addComboBtn).CornerRadius = UDim.new(0, 8)

playComboBtn = Instance.new("TextButton")
playComboBtn.Size             = UDim2.new(0.5, -2, 1, 0)
playComboBtn.BackgroundColor3 = Color3.fromRGB(119, 119, 119)
playComboBtn.Text             = L.playCombo
playComboBtn.TextColor3       = Color3.new(1, 1, 1)
playComboBtn.Font             = Enum.Font.GothamBold
playComboBtn.TextSize         = 12
playComboBtn.ZIndex           = 9
playComboBtn.Parent           = comboBtnHolder
Instance.new("UICorner", playComboBtn).CornerRadius = UDim.new(0, 8)

loopComboBtn = Instance.new("TextButton")
loopComboBtn.Size             = UDim2.new(1, -12, 0, 26)
loopComboBtn.Position         = UDim2.new(0, 6, 0, 106)
loopComboBtn.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
loopComboBtn.Text             = L.loopText .. ": " .. L.off
loopComboBtn.TextColor3       = Color3.fromRGB(122, 122, 122)
loopComboBtn.Font             = Enum.Font.GothamBold
loopComboBtn.TextSize         = 12
loopComboBtn.ZIndex           = 9
loopComboBtn.Parent           = comboRow
Instance.new("UICorner", loopComboBtn).CornerRadius = UDim.new(0, 8)
loopStroke = Instance.new("UIStroke")
loopStroke.Color        = Color3.fromRGB(62, 62, 62)
loopStroke.Thickness    = 1
loopStroke.Transparency = 0.5
loopStroke.Parent       = loopComboBtn
local loopIcon = Instance.new("ImageLabel")
loopIcon.Size                   = UDim2.new(0, 14, 0, 14)
loopIcon.Position               = UDim2.new(0, 8, 0.5, -7)
loopIcon.BackgroundTransparency = 1
loopIcon.Image                  = ResolveAssetImage(Icons.Refresh)
loopIcon.ImageColor3            = Color3.fromRGB(255,255,255)
loopIcon.ZIndex                 = 10
loopIcon.Parent                 = loopComboBtn
loopComboBtn.TextXAlignment = Enum.TextXAlignment.Center

loopComboBtn.MouseButton1Click:Connect(function()
	_comboLoopEnabled = not _comboLoopEnabled
	if _comboLoopEnabled then
		loopComboBtn.Text             = L.loopText .. ": " .. L.on
		loopComboBtn.TextColor3       = Color3.new(1, 1, 1)
		loopIcon.ImageColor3          = Color3.new(1, 1, 1)
		TweenService:Create(loopComboBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = currentTheme.accent
		}):Play()
		loopStroke.Color = currentTheme.accent
	else
		loopComboBtn.Text             = L.loopText .. ": " .. L.off
		loopComboBtn.TextColor3       = Color3.fromRGB(122, 122, 122)
		loopIcon.ImageColor3          = Color3.fromRGB(255,255,255)
		TweenService:Create(loopComboBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(31, 31, 31)
		}):Play()
		loopStroke.Color = Color3.fromRGB(62, 62, 62)
	end
end)

clearComboBtn = Instance.new("TextButton")
clearComboBtn.Size             = UDim2.new(1, -12, 0, 26)
clearComboBtn.Position         = UDim2.new(0, 6, 0, 138)
clearComboBtn.BackgroundColor3 = Color3.fromRGB(61, 61, 61)
clearComboBtn.Text             = L.clearCombo
clearComboBtn.TextColor3       = Color3.new(1, 1, 1)
clearComboBtn.Font             = Enum.Font.GothamBold
clearComboBtn.TextSize         = 12
clearComboBtn.ZIndex           = 9
clearComboBtn.Parent           = comboRow
Instance.new("UICorner", clearComboBtn).CornerRadius = UDim.new(0, 8)

addComboBtn.MouseButton1Click:Connect(function()
	if #comboQueue_UI >= 3 then return end
	if not _currentInfoId then
		local origCol = addComboBtn.BackgroundColor3
		addComboBtn.BackgroundColor3 = Color3.fromRGB(78, 78, 78)
		addComboBtn.Text = L.selectFirst
		task.delay(0.7, function()
			addComboBtn.BackgroundColor3 = origCol
			addComboBtn.Text = L.addEmote
		end)
		return
	end
	table.insert(comboQueue_UI, {id = _currentInfoId, name = _currentInfoName or "Emote"})
	local idx = #comboQueue_UI
	comboSlots[idx].Text = LocalizeEmoteName(comboQueue_UI[idx].name):sub(1, 9)
	TweenService:Create(comboSlots[idx], TweenInfo.new(0.15), {
		BackgroundColor3 = currentTheme.accent
	}):Play()
end)

playComboBtn.MouseButton1Click:Connect(function()
	if #comboQueue_UI == 0 then return end
	local list = {}
	for _, e in ipairs(comboQueue_UI) do
		table.insert(list, {id = e.id, name = e.name})
	end
	StartCombo(list)
end)

clearComboBtn.MouseButton1Click:Connect(function()
	comboQueue_UI    = {}
	isComboActive    = false
	ComboQueue       = {}
	_comboLoopList   = {}
	if _comboLoopEnabled then
		_comboLoopEnabled             = false
		loopComboBtn.Text             = L.loopText .. ": " .. L.off
		loopComboBtn.TextColor3       = Color3.fromRGB(122, 122, 122)
		loopComboBtn.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
		loopStroke.Color              = Color3.fromRGB(62, 62, 62)
		loopIcon.ImageColor3          = Color3.fromRGB(255,255,255)
	end
	for j = 1, 3 do
		comboSlots[j].Text = L.slotLabel .. " " .. j
		TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(31, 31, 31)
		}):Play()
	end
end)

do
	local _prevApply = ApplyTheme
	ApplyTheme = function(name)
		_prevApply(name)
		if _comboLoopEnabled and loopComboBtn and loopComboBtn.Parent then
			pcall(function()
				loopComboBtn.BackgroundColor3 = currentTheme.accent
				loopStroke.Color             = currentTheme.accent
				loopIcon.ImageColor3         = Color3.new(1, 1, 1)
			end)
		end
	end
end

end

_HXExtend()

-- =========================
-- EMOTES ADVANCED TOOLS
-- =========================
do
    local _toolPanel, _toolBody, _toolTab = nil, nil, "control"
    local _toolTrackerConn = nil
    local _quickDock = nil
    local _floatingButtons = {}
    local _ugcSearchBusy = false

    local function HXButton(parent, textValue, size, pos)
        local b = Instance.new("TextButton")
        b.Size = size
        b.Position = pos or UDim2.new()
        b.BackgroundColor3 = Color3.fromRGB(24,24,24)
        b.BackgroundTransparency = 0.08
        b.BorderSizePixel = 0
        b.Text = textValue
        b.TextColor3 = Color3.fromRGB(245,245,245)
        b.TextStrokeTransparency = 1
        b.Font = Enum.Font.Gotham
        b.TextSize = isMobile and 10 or 12
        b.AutoButtonColor = false
        b.ZIndex = 905
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(38,38,38)}):Play() end)
        b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(24,24,24)}):Play() end)
        return b
    end

    local function HXLabel(parent, txt, h, bold)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,0,0,h or 22)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = bold and Color3.fromRGB(245,245,245) or Color3.fromRGB(170,170,170)
        l.TextStrokeTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = isMobile and 10 or 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 905
        l.Parent = parent
        return l
    end

    local function ClearBody()
        if _toolTrackerConn then _toolTrackerConn:Disconnect(); _toolTrackerConn = nil end
        for _, c in ipairs(_toolBody:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
    end

    local function RefreshQuickDock()
        if not _quickDock then
            _quickDock = Instance.new("Frame")
            _quickDock.Name = "HXQuickSelector"
            _quickDock.AutomaticSize = Enum.AutomaticSize.X
            _quickDock.Size = UDim2.new(0,0,0,isMobile and 42 or 48)
            _quickDock.Position = UDim2.new(0.5,0,0,12)
            _quickDock.AnchorPoint = Vector2.new(0.5,0)
            _quickDock.BackgroundColor3 = Color3.fromRGB(7,7,7)
            _quickDock.BackgroundTransparency = 0.12
            _quickDock.BorderSizePixel = 0
            _quickDock.ZIndex = 1200
            _quickDock.Parent = gui
            Instance.new("UICorner",_quickDock).CornerRadius = UDim.new(0,12)
            local st = Instance.new("UIStroke",_quickDock); st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.35; st.Thickness=1
            local pad=Instance.new("UIPadding",_quickDock); pad.PaddingLeft=UDim.new(0,6); pad.PaddingRight=UDim.new(0,6); pad.PaddingTop=UDim.new(0,5); pad.PaddingBottom=UDim.new(0,5)
            local lay=Instance.new("UIListLayout",_quickDock); lay.FillDirection=Enum.FillDirection.Horizontal; lay.Padding=UDim.new(0,5); lay.VerticalAlignment=Enum.VerticalAlignment.Center
        end
        for _,c in ipairs(_quickDock:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for i, q in ipairs(QuickEmotes) do
            local id = tonumber(type(q)=="table" and q.id or q)
            local e = id and EmotesById[id]
            local name = (type(q)=="table" and q.name) or (e and e.name) or ("#"..tostring(id or "?"))
            local isUGCQuick = type(q)=="table" and q.isUGC == true
            local b = HXButton(_quickDock, LocalizeEmoteName(name):sub(1,isMobile and 5 or 8), UDim2.new(0,isMobile and 42 or 54,1,0))
            b.ZIndex = 1201
            b.MouseButton1Click:Connect(function()
                if not id then return end
                if isUGCQuick then
                    local temp = e or {id=id,name=name,isUGC=true}
                    task.spawn(function() PlayEmote(ResolveUGCAnimationId(temp) or id, name) end)
                else
                    PlayEmote(id,name)
                end
            end)
        end
        _quickDock.Visible = #QuickEmotes > 0
    end

    local function AddSelectedToQuick()
        if not selectedEmote or selectedEmote.isAnimationPack then
            Notify("Emotes", isES and "Selecciona un emote primero." or "Select an emote first.")
            return
        end
        for _,q in ipairs(QuickEmotes) do
            if tonumber(type(q)=="table" and q.id or q) == tonumber(selectedEmote.id) then return end
        end
        if #QuickEmotes >= 8 then table.remove(QuickEmotes,1) end
        QuickEmotes[#QuickEmotes+1] = {id=tonumber(selectedEmote.id), name=selectedEmote.name, isUGC=selectedEmote.isUGC == true}
        SaveData(); RefreshQuickDock()
        Notify("Emotes", isES and "Añadido al selector rápido." or "Added to Quick Selector.")
    end

    local function CreateFloatingSelected()
        if not selectedEmote or selectedEmote.isAnimationPack then
            Notify("Emotes", isES and "Selecciona un emote primero." or "Select an emote first.")
            return
        end
        local data = {id=tonumber(selectedEmote.id), name=selectedEmote.name, isUGC=selectedEmote.isUGC == true}
        local b = Instance.new("TextButton")
        b.Name = "HXFloat_"..tostring(data.id)
        b.Size = UDim2.new(0,isMobile and 58 or 66,0,isMobile and 58 or 66)
        b.Position = UDim2.new(1,-(isMobile and 72 or 82),0.55,#_floatingButtons*8)
        b.AnchorPoint = Vector2.new(1,0.5)
        b.BackgroundColor3 = Color3.fromRGB(10,10,10)
        b.BackgroundTransparency = 0.10
        b.Text = LocalizeEmoteName(data.name):sub(1,isMobile and 7 or 9)
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.TextStrokeTransparency = 1
        b.TextWrapped = true
        b.Font = Enum.Font.Gotham
        b.TextSize = isMobile and 9 or 10
        b.ZIndex = 1190
        b.Parent = gui
        Instance.new("UICorner",b).CornerRadius = UDim.new(1,0)
        local x = Instance.new("TextButton")
        x.Size=UDim2.new(0,18,0,18); x.Position=UDim2.new(1,-15,0,-3); x.BackgroundColor3=Color3.fromRGB(25,25,25); x.Text="X"; x.TextColor3=Color3.new(1,1,1); x.TextSize=8; x.Font=Enum.Font.Gotham; x.ZIndex=1192; x.Parent=b
        Instance.new("UICorner",x).CornerRadius=UDim.new(1,0)
        local dragging=false; local ds; local ps
        b.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=true; ds=inp.Position; ps=b.Position end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
            local d=inp.Position-ds; b.Position=UDim2.new(ps.X.Scale,ps.X.Offset+d.X,ps.Y.Scale,ps.Y.Offset+d.Y)
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end)
        b.MouseButton1Click:Connect(function()
            if dragging then return end
            if data.isUGC then
                task.spawn(function() PlayEmote(ResolveUGCAnimationId(data) or data.id, data.name) end)
            else
                PlayEmote(data.id,data.name)
            end
        end)
        x.MouseButton1Click:Connect(function() b:Destroy() end)
        _floatingButtons[#_floatingButtons+1]=b
    end

    local function MakeControlPage()
        ClearBody()
        HXLabel(_toolBody,isES and "CONTROL AVANZADO" or "ADVANCED CONTROL",24,true)
        local now = HXLabel(_toolBody,isES and "Sin emote reproduciéndose" or "No emote playing",22,false)
        local row=Instance.new("Frame",_toolBody); row.Size=UDim2.new(1,0,0,34); row.BackgroundTransparency=1; row.ZIndex=905
        local pause=HXButton(row,isES and "PAUSA" or "PAUSE",UDim2.new(0.32,-4,1,0),UDim2.new(0,0,0,0))
        local rev=HXButton(row,isES and "REVERSA" or "REVERSE",UDim2.new(0.34,-4,1,0),UDim2.new(0.32,4,0,0))
        local loop=HXButton(row,"LOOP",UDim2.new(0.34,-4,1,0),UDim2.new(0.66,4,0,0))
        local function syncButtons()
            rev.BackgroundColor3 = Settings.reversePlayback and Color3.fromRGB(72,72,72) or Color3.fromRGB(24,24,24)
            loop.BackgroundColor3 = Settings.loopEmote and Color3.fromRGB(72,72,72) or Color3.fromRGB(24,24,24)
        end
        syncButtons()
        pause.MouseButton1Click:Connect(function()
            if not currentAnimTrack then return end
            if _isPaused then currentAnimTrack:AdjustSpeed(HXEffectiveSpeed()); _SetPauseState(false) else currentAnimTrack:AdjustSpeed(0); _SetPauseState(true) end
        end)
        rev.MouseButton1Click:Connect(function()
            Settings.reversePlayback = not Settings.reversePlayback; SaveData(); syncButtons()
            if currentAnimTrack and not _isPaused then pcall(function() currentAnimTrack:AdjustSpeed(HXEffectiveSpeed()) end) end
        end)
        loop.MouseButton1Click:Connect(function()
            Settings.loopEmote = not Settings.loopEmote; SaveData(); syncButtons()
            if currentAnimTrack then pcall(function() currentAnimTrack.Looped=Settings.loopEmote end) end
        end)

        HXLabel(_toolBody,isES and "Velocidad" or "Speed",18,true)
        local srow=Instance.new("Frame",_toolBody); srow.Size=UDim2.new(1,0,0,32); srow.BackgroundTransparency=1
        local minus=HXButton(srow,"-",UDim2.new(0.25,-3,1,0),UDim2.new())
        local sval=HXButton(srow,tostring(Settings.speed).."x",UDim2.new(0.5,-6,1,0),UDim2.new(0.25,3,0,0))
        local plus=HXButton(srow,"+",UDim2.new(0.25,-3,1,0),UDim2.new(0.75,3,0,0))
        local function changeSpeed(d)
            Settings.speed=math.clamp(math.floor((Settings.speed+d)*4+0.5)/4,0.25,3); SaveData(); sval.Text=tostring(Settings.speed).."x"
            if currentAnimTrack and not _isPaused then pcall(function() currentAnimTrack:AdjustSpeed(HXEffectiveSpeed()) end) end
            if _onSpeedChanged then pcall(_onSpeedChanged) end
        end
        minus.MouseButton1Click:Connect(function() changeSpeed(-0.25) end); plus.MouseButton1Click:Connect(function() changeSpeed(0.25) end)

        HXLabel(_toolBody,isES and "Intensidad" or "Intensity",18,true)
        local irow=Instance.new("Frame",_toolBody); irow.Size=UDim2.new(1,0,0,32); irow.BackgroundTransparency=1
        local weights={{0.25,"25%"},{0.5,"50%"},{0.75,"75%"},{1,"100%"}}
        for i,w in ipairs(weights) do
            local ib=HXButton(irow,w[2],UDim2.new(0.25,-4,1,0),UDim2.new((i-1)*0.25,(i-1)*1.3,0,0))
            ib.MouseButton1Click:Connect(function()
                Settings.animationWeight=w[1]; SaveData(); if currentAnimTrack then pcall(function() currentAnimTrack:AdjustWeight(w[1],0.08) end) end
            end)
        end

        HXLabel(_toolBody,isES and "Tiempo / Seek" or "Time / Seek",18,true)
        local seek=Instance.new("TextButton",_toolBody); seek.Size=UDim2.new(1,0,0,30); seek.BackgroundColor3=Color3.fromRGB(18,18,18); seek.Text=""; seek.ZIndex=905; Instance.new("UICorner",seek).CornerRadius=UDim.new(0,8)
        local fill=Instance.new("Frame",seek); fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=Color3.fromRGB(110,110,110); fill.BorderSizePixel=0; fill.ZIndex=906; Instance.new("UICorner",fill).CornerRadius=UDim.new(0,8)
        local time=Instance.new("TextLabel",seek); time.Size=UDim2.new(1,0,1,0); time.BackgroundTransparency=1; time.Text="0.0 / 0.0"; time.TextColor3=Color3.new(1,1,1); time.TextStrokeTransparency=1; time.Font=Enum.Font.Gotham; time.TextSize=isMobile and 9 or 10; time.ZIndex=907
        local function seekTo(inp)
            if not currentAnimTrack or currentAnimTrack.Length<=0 then return end
            local a=math.clamp((inp.Position.X-seek.AbsolutePosition.X)/math.max(seek.AbsoluteSize.X,1),0,1); pcall(function() currentAnimTrack.TimePosition=a*currentAnimTrack.Length end)
        end
        seek.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then seekTo(inp) end end)
        _toolTrackerConn=RunService.Heartbeat:Connect(function()
            if not _toolPanel or not _toolPanel.Visible then return end
            if currentAnimTrack and currentAnimTrack.Length and currentAnimTrack.Length>0 then
                local a=math.clamp(currentAnimTrack.TimePosition/currentAnimTrack.Length,0,1); fill.Size=UDim2.new(a,0,1,0); time.Text=string.format("%.1f / %.1f",currentAnimTrack.TimePosition,currentAnimTrack.Length)
                local le=_genv().lastHXEmote; now.Text=le and LocalizeEmoteName(le.name or "Emote") or (isES and "Reproduciendo" or "Playing")
            else fill.Size=UDim2.new(0,0,1,0); time.Text="0.0 / 0.0" end
        end)
    end

    local function MakeQuickPage()
        ClearBody(); HXLabel(_toolBody,isES and "SELECTOR RÁPIDO" or "QUICK SELECTOR",28,true)
        local a=HXButton(_toolBody,isES and "AÑADIR EMOTE SELECCIONADO AL QUICK" or "ADD SELECTED EMOTE TO QUICK",UDim2.new(1,0,0,34)); a.MouseButton1Click:Connect(AddSelectedToQuick)
        local c=HXButton(_toolBody,isES and "LIMPIAR QUICK SELECTOR" or "CLEAR QUICK SELECTOR",UDim2.new(1,0,0,34)); c.MouseButton1Click:Connect(function() QuickEmotes={}; SaveData(); RefreshQuickDock() end)
        HXLabel(_toolBody,isES and "Selecciona un emote en la biblioteca y usa estas opciones." or "Select an emote in the library, then use these options.",36,false).TextWrapped=true
    end

    local function ApplyCustomAnimations()
        local char=player.Character; local animate=char and char:FindFirstChild("Animate"); if not animate then return end
        for category,raw in pairs(CustomAnimations) do
            local id=tonumber(tostring(raw):match("%d+"))
            local target=animate:FindFirstChild(category:lower())
            if id and target then
                -- Accept either a direct Animation ID or the ID of any pack already loaded by HX.
                for _,pack in ipairs(AnimationPacks or {}) do
                    local packId=tonumber(tostring(pack.id or ""):match("%d+"))
                    if packId == id and tonumber(pack[category]) then
                        id=tonumber(pack[category])
                        break
                    end
                end
                local resolved={}
                pcall(function()
                    local objs=game:GetObjects("rbxassetid://"..id)
                    for _,o in ipairs(objs or {}) do
                        if o:IsA("Animation") then resolved[#resolved+1]=o.AnimationId end
                        for _,d in ipairs(o:GetDescendants()) do if d:IsA("Animation") then resolved[#resolved+1]=d.AnimationId end end
                    end
                end)
                if #resolved==0 then resolved[1]="rbxassetid://"..id end
                for _,ch in ipairs(target:GetChildren()) do if ch:IsA("Animation") then ch:Destroy() end end
                for i,aid in ipairs(resolved) do local an=Instance.new("Animation"); an.Name="HXCustom"..i; an.AnimationId=aid; an.Parent=target end
            end
        end
        pcall(function() animate.Enabled=false; task.wait(0.05); animate.Enabled=true end)
        Notify("Emotes",isES and "Animaciones personalizadas aplicadas." or "Custom animations applied.")
    end

    local function MakePackPage()
        ClearBody(); HXLabel(_toolBody,isES and "EDITOR DE ANIMACIONES" or "ANIMATION EDITOR",24,true)
        HXLabel(_toolBody,isES and "Pon un Animation ID o Pack ID diferente para cada movimiento." or "Set a different Animation ID or Pack ID for each movement.",30,false).TextWrapped=true
        local cats={"Idle","Walk","Run","Jump","Fall","Climb","Swim"}
        for _,cat in ipairs(cats) do
            local row=Instance.new("Frame",_toolBody); row.Size=UDim2.new(1,0,0,30); row.BackgroundTransparency=1
            local l=HXLabel(row,cat,30,true); l.Size=UDim2.new(0.26,0,1,0)
            local box=Instance.new("TextBox",row); box.Size=UDim2.new(0.74,-4,1,0); box.Position=UDim2.new(0.26,4,0,0); box.BackgroundColor3=Color3.fromRGB(18,18,18); box.Text=tostring(CustomAnimations[cat] or ""); box.PlaceholderText="Animation / Pack ID"; box.TextColor3=Color3.new(1,1,1); box.PlaceholderColor3=Color3.fromRGB(100,100,100); box.TextStrokeTransparency=1; box.Font=Enum.Font.Gotham; box.TextSize=isMobile and 9 or 10; box.ClearTextOnFocus=false; box.ZIndex=905; Instance.new("UICorner",box).CornerRadius=UDim.new(0,7)
            box.FocusLost:Connect(function() local id=box.Text:match("%d+"); CustomAnimations[cat]=id and tonumber(id) or nil; SaveData() end)
        end
        local apply=HXButton(_toolBody,isES and "APLICAR" or "APPLY",UDim2.new(1,0,0,34)); apply.MouseButton1Click:Connect(ApplyCustomAnimations)
        local reset=HXButton(_toolBody,isES and "LIMPIAR CONFIGURACIÓN" or "CLEAR CONFIG",UDim2.new(1,0,0,32)); reset.MouseButton1Click:Connect(function() CustomAnimations={}; SaveData(); MakePackPage() end)
    end

    local function MakeSizePage()
        ClearBody(); HXLabel(_toolBody,isES and "TAMAÑO DEL PANEL" or "PANEL SIZE",24,true)
        HXLabel(_toolBody,isES and "Al agrandarlo aparecerán más columnas y más emotes automáticamente." or "Increasing the panel automatically shows more columns and more emotes.",42,false).TextWrapped=true
        local row=Instance.new("Frame",_toolBody); row.Size=UDim2.new(1,0,0,42); row.BackgroundTransparency=1
        local minus=HXButton(row,"-",UDim2.new(0.25,-3,1,0))
        local val=HXButton(row,tostring(math.floor(Settings.panelScale*100)).."%",UDim2.new(0.5,-6,1,0),UDim2.new(0.25,3,0,0))
        local plus=HXButton(row,"+",UDim2.new(0.25,-3,1,0),UDim2.new(0.75,3,0,0))
        local function resize(d)
            Settings.panelScale=math.clamp(math.floor((Settings.panelScale+d)*20+0.5)/20,0.75,1.35); SaveData(); val.Text=tostring(math.floor(Settings.panelScale*100)).."%"
            local target=GetDefaultSize(); TweenService:Create(main,TweenInfo.new(0.22,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=target}):Play()
            task.delay(0.25,function() if scroll and scroll.Parent then Refresh(false,true) end end)
        end
        minus.MouseButton1Click:Connect(function() resize(-0.1) end); plus.MouseButton1Click:Connect(function() resize(0.1) end)
        local reset=HXButton(_toolBody,isES and "RESTABLECER 100%" or "RESET 100%",UDim2.new(1,0,0,34)); reset.MouseButton1Click:Connect(function() Settings.panelScale=1; SaveData(); val.Text="100%"; TweenService:Create(main,TweenInfo.new(0.22),{Size=GetDefaultSize()}):Play(); task.delay(0.25,function() Refresh(false,true) end) end)
    end

    local renderers={control=MakeControlPage,quick=MakeQuickPage,pack=MakePackPage,size=MakeSizePage}
    local function ShowToolTab(name) _toolTab=name; if renderers[name] then renderers[name]() end end

    _toolPanel=Instance.new("Frame")
    _toolPanel.Name="AdvancedTools"
    _toolPanel.Size=UDim2.new(1,-16,1,-(titleH+12))
    _toolPanel.Position=UDim2.new(0,8,0,titleH+4)
    _toolPanel.BackgroundColor3=Color3.fromRGB(6,6,6)
    _toolPanel.BackgroundTransparency=0.22
    _toolPanel.BorderSizePixel=0
    _toolPanel.Visible=false
    _toolPanel.ZIndex=3
    _toolPanel.Parent=content
    toolsContentPanel=_toolPanel
    Instance.new("UICorner",_toolPanel).CornerRadius=UDim.new(0,12)
    local pst=Instance.new("UIStroke",_toolPanel); pst.Color=Color3.fromRGB(255,255,255); pst.Transparency=0.42; pst.Thickness=1

    local tabs=Instance.new("Frame",_toolPanel)
    tabs.Size=UDim2.new(1,-16,0,isMobile and 34 or 38)
    tabs.Position=UDim2.new(0,8,0,8)
    tabs.BackgroundTransparency=1
    tabs.ZIndex=4
    local tl=Instance.new("UIListLayout",tabs)
    tl.FillDirection=Enum.FillDirection.Horizontal
    tl.Padding=UDim.new(0,5)
    tl.HorizontalAlignment=Enum.HorizontalAlignment.Left
    local defs={{"control",isES and "CONTROL" or "CONTROL"},{"quick",isES and "RÁPIDO" or "QUICK"},{"pack",isES and "ANIMACIONES" or "ANIMATIONS"},{"size",isES and "TAMAÑO" or "SIZE"}}
    for _,d in ipairs(defs) do
        local b=HXButton(tabs,d[2],UDim2.new(0.25,-4,1,0))
        b.ZIndex=5
        b.MouseButton1Click:Connect(function() ShowToolTab(d[1]) end)
    end

    _toolBody=Instance.new("ScrollingFrame",_toolPanel)
    _toolBody.Size=UDim2.new(1,-20,1,-(isMobile and 58 or 64))
    _toolBody.Position=UDim2.new(0,10,0,isMobile and 50 or 54)
    _toolBody.BackgroundTransparency=1
    _toolBody.BorderSizePixel=0
    _toolBody.ScrollBarThickness=2
    _toolBody.AutomaticCanvasSize=Enum.AutomaticSize.Y
    _toolBody.CanvasSize=UDim2.new()
    _toolBody.ZIndex=4
    local bodyPad=Instance.new("UIPadding",_toolBody); bodyPad.PaddingBottom=UDim.new(0,8)
    local bodyLay=Instance.new("UIListLayout",_toolBody); bodyLay.Padding=UDim.new(0,6); bodyLay.SortOrder=Enum.SortOrder.LayoutOrder

    local function ForcePlainToolsText(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            obj.TextStrokeTransparency = 1
            obj.Font = Enum.Font.Gotham
        end
    end
    for _, obj in ipairs(_toolPanel:GetDescendants()) do ForcePlainToolsText(obj) end
    _toolPanel.DescendantAdded:Connect(function(obj)
        task.defer(function()
            if obj and obj.Parent then ForcePlainToolsText(obj) end
        end)
    end)

    RefreshToolsCategory=function()
        if not _toolPanel or not _toolPanel.Parent then return end
        _toolPanel.Visible = currentTab == "tools"
        if _toolPanel.Visible then ShowToolTab(_toolTab) end
    end

    RefreshQuickDock()
end

end)()
