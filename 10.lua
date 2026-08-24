--Made by Zyrovell Roblox:Oyuncu15q Discord:_ege.
-- V5.0 - VEXRO CLOUD
-- OPEN SOURCE FOREVER!

--[[



$$\    $$\ $$$$$$$$\ $$\   $$\ $$$$$$$\   $$$$$$\         $$$$$$\  $$\   $$\       $$$$$$$$\  $$$$$$\  $$$$$$$\        $$\ 
$$ |   $$ |$$  _____|$$ |  $$ |$$  __$$\ $$  __$$\       $$  __$$\ $$$\  $$ |      \__$$  __|$$  __$$\ $$  __$$\       $$ |
$$ |   $$ |$$ |      \$$\ $$  |$$ |  $$ |$$ /  $$ |      $$ /  $$ |$$$$\ $$ |         $$ |   $$ /  $$ |$$ |  $$ |      $$ |
\$$\  $$  |$$$$$\     \$$$$  / $$$$$$$  |$$ |  $$ |      $$ |  $$ |$$ $$\$$ |         $$ |   $$ |  $$ |$$$$$$$  |      $$ |
 \$$\$$  / $$  __|    $$  $$<  $$  __$$< $$ |  $$ |      $$ |  $$ |$$ \$$$$ |         $$ |   $$ |  $$ |$$  ____/       \__|
  \$$$  /  $$ |      $$  /\$$\ $$ |  $$ |$$ |  $$ |      $$ |  $$ |$$ |\$$$ |         $$ |   $$ |  $$ |$$ |                
   \$  /   $$$$$$$$\ $$ /  $$ |$$ |  $$ | $$$$$$  |       $$$$$$  |$$ | \$$ |         $$ |    $$$$$$  |$$ |            $$\ 
    \_/    \________|\__|  \__|\__|  \__| \______/        \______/ \__|  \__|         \__|    \______/ \__|            \__|
                                                                                                                           
                                                                                                                           
                                                                                                                           
]]

pcall(function()
	local b = game:GetService("Lighting"):FindFirstChild("VexroGlassBlur")
	if b then b:Destroy() end
end)
pcall(function()
	local f = workspace:FindFirstChild("VexroGlassBlurFolder")
	if f then f:Destroy() end
end)
local _genv = (type(getgenv) == "function") and getgenv or function() return {} end
if _genv().VexroEmotesCleanup then
	pcall(_genv().VexroEmotesCleanup)
	_genv().VexroEmotesCleanup = nil
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local function debugLog(msg) end

-- ===============================================================
-- VEXRO CLOUD V1 - API SYSTEM
-- ===============================================================
local BASE_URL = "https://vexroscripts.com.tr/api"
local myToken = ""

local mySessionToken = HttpService:GenerateGUID(false)
_genv().VexroSessionToken = mySessionToken

request = request
http_request = http_request
HttpFunc = nil

synLib = syn or (Drawing and Drawing.new and {})
httpLib = http
fluxusLib = fluxus
krnlLoaded = (KRNL_LOADED ~= nil)

if synLib and synLib.request then HttpFunc = synLib.request
elseif httpLib and httpLib.request then HttpFunc = httpLib.request
elseif http_request then HttpFunc = http_request
elseif request then HttpFunc = request
elseif fluxusLib and fluxusLib.request then HttpFunc = fluxusLib.request
elseif krnlLoaded and request then HttpFunc = request end

local function getOrCreateToken()
    if myToken ~= "" then return myToken end
    local tokenFile = "VexroEmotes_Token_" .. tostring(player.UserId) .. ".txt"
    pcall(function()
        if readfile and isfile and isfile(tokenFile) then
            myToken = readfile(tokenFile)
        end
    end)
    if not myToken or myToken == "" then
        local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local temp = {}
        math.randomseed(os.time())
        for i = 1, 32 do
            local rand = math.random(1, #chars)
            table.insert(temp, chars:sub(rand, rand))
        end
        myToken = table.concat(temp)
        pcall(function()
            if writefile then
                writefile(tokenFile, myToken)
            end
        end)
    end
    return myToken
end

local lastApiRequestTime = 0
local function ApiRequest(method, endpoint, body)
	debugLog("ApiRequest: " .. tostring(method) .. " " .. tostring(endpoint))
    if not HttpFunc then 
        print("[Vexro Debug] ApiRequest error: HttpFunc is nil. Please ensure your executor supports Http requests.")
        return nil 
    end
    
    -- Throttle to avoid localtonet 429 Too Many Requests
    while tick() - lastApiRequestTime < 1.2 do
        task.wait(0.1)
    end
    lastApiRequestTime = tick()
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local url = BASE_URL .. endpoint
    local response = nil
    local success, err = pcall(function()
        local reqData = {
            Url = url,
            Method = method,
            Headers = headers
        }
        if method ~= "GET" and method ~= "HEAD" then
            reqData.Body = body and HttpService:JSONEncode(body) or ""
        end
        response = HttpFunc(reqData)
    end)
	debugLog("ApiRequest " .. tostring(endpoint) .. " done. success=" .. tostring(success) .. " status=" .. tostring(response and response.StatusCode or "nil"))
    if not success then
        print("[Vexro Debug] ApiRequest transport error: " .. tostring(err))
        return nil
    end
    if response then
        if response.StatusCode == 200 then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
            if ok then return decoded end
            print("[Vexro Debug] JSON decode error: " .. tostring(response.Body))
        elseif (response.StatusCode == 401 or response.StatusCode == 403) and endpoint ~= "/auth/register" then
            if not _genv().VexroKicked then
                _genv().VexroKicked = true
                _genv().VexroSessionToken = nil -- Kill active loops
                Notify(SafeUtf8Char(0x26A0), "Oturum başka bir cihazda açıldığı için sonlandırıldı.")
            end
            return nil
        else
            print("[Vexro Debug] HTTP error " .. tostring(response.StatusCode) .. ": " .. tostring(response.Body))
        end
    else
        print("[Vexro Debug] Response is nil")
    end
    return nil
end

local old = playerGui:FindFirstChild("VexroEmotes")
if old then old:Destroy() end

-- ===============================================================
-- DATA SYSTEM
-- ===============================================================

local DATA_FILE = "VexroEmotes_Data_" .. tostring(player.UserId) .. ".json"
local Settings = {theme = "Dark", speed = 1, notifications = true, loopEmote = true, language = nil, copyEmoteEnabled = false, stopOnWalk = true, showHUD = true}

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
local _onSpeedChanged
local _onPauseStateChanged
local MAX_RECENT = 20

local _savePending = false
local function SaveData()
	if _savePending then return end
	_savePending = true
	task.delay(0.25, function()
		_savePending = false
		pcall(function()
			-- Write local backup
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
					keybinds = Keybinds,
					playlists = Playlists
				}))
			end
			-- Merge FriendData into Settings for Cloud Sync
			Settings.autoReject = FriendData.autoReject
			Settings.acceptRequests = FriendData.acceptRequests
			Settings.playFriendEmote = FriendData.playFriendEmote
			Settings.syncEmote = FriendData.syncEmote
			
			-- Save to server
			ApiRequest("POST", "/emote/settings", {
				userId = tostring(player.UserId),
				token = getOrCreateToken(),
				action = "save",
				settings = Settings
			})
			ApiRequest("POST", "/emote/keybinds", {
				userId = tostring(player.UserId),
				token = getOrCreateToken(),
				action = "save",
				keybinds = Keybinds
			})
			for _, pl in ipairs(Playlists) do
				if tostring(pl.creatorId) == tostring(player.UserId) then
					task.spawn(function()
						ApiRequest("POST", "/emote/playlist/save", {
							userId = tostring(player.UserId),
							token = getOrCreateToken(),
							playlist = pl
						})
					end)
				end
			end
		end)
	end)
end

local function LoadData()
	debugLog("LoadData starting")
	_genv().VexroServerAccessible = false
	pcall(function()
		-- 1. Load local backup
		if readfile and isfile and isfile(DATA_FILE) then
			local data = HttpService:JSONDecode(readfile(DATA_FILE))
			if data then
				Playlists = {
					{ id = "1", name = "Top 10 TikTok", creator = "Zyrovell", creatorId = 1530132336, emotes = {3576686446, 3576823880, 3576720708} },
					{ id = "2", name = "Chill Vibes", creator = "Oyuncu15q", creatorId = 1530132336, emotes = {3576686446} }
				}
				if data.playlists then
					Playlists = data.playlists
				end
				MockPlaylists = Playlists

				Favorites = {}
				if data.favorites then
					for _, v in pairs(data.favorites) do
						table.insert(Favorites, tonumber(v)) 
					end
				end
				RecentEmotes = {}
				if data.recent then
					for _, v in pairs(data.recent) do
						table.insert(RecentEmotes, tonumber(v))
					end
				end
				if data.settings then
					Settings.theme = data.settings.theme or "Dark"
					Settings.speed = data.settings.speed or 1
					Settings.notifications = data.settings.notifications ~= false
					Settings.loopEmote = data.settings.loopEmote ~= false
					Settings.language = data.settings.language or nil
					Settings.stopOnWalk = data.settings.stopOnWalk ~= false
					Settings.showHUD = data.settings.showHUD ~= false
				end
				if data.friendSettings then
					FriendData.autoReject = data.friendSettings.autoReject == true
					FriendData.acceptRequests = data.friendSettings.acceptRequests ~= false
					FriendData.playFriendEmote = data.friendSettings.playFriendEmote ~= false
					FriendData.syncEmote = data.friendSettings.syncEmote ~= false
				end
				Keybinds = {}
				if data.keybinds then
					for k, v in pairs(data.keybinds) do
						Keybinds[tostring(k)] = v
					end
				end
			end
		end

		-- 2. Call server register & sync settings/keybinds
		local reg = ApiRequest("POST", "/auth/init", {
			username = player.Name,
			userId = tostring(player.UserId),
			token = getOrCreateToken()
		})
		if reg and reg.ok then
			_genv().VexroServerAccessible = true
			-- Save the token returned by the server in case the server rotated or initialized a new one
			if reg.token and reg.token ~= "" then
				myToken = reg.token
				local tokenFile = "VexroEmotes_Token_" .. tostring(player.UserId) .. ".txt"
				pcall(function()
					if writefile then
						writefile(tokenFile, myToken)
					end
				end)
			end
			
			-- Populate player data
			if reg.player then
				local pInfo = reg.player
				if pInfo.settings then
					for k, v in pairs(pInfo.settings) do
						Settings[k] = v
					end
					-- Unpack FriendData from Settings
					if Settings.autoReject ~= nil then FriendData.autoReject = Settings.autoReject end
					if Settings.acceptRequests ~= nil then FriendData.acceptRequests = Settings.acceptRequests end
					if Settings.playFriendEmote ~= nil then FriendData.playFriendEmote = Settings.playFriendEmote end
					if Settings.syncEmote ~= nil then FriendData.syncEmote = Settings.syncEmote end
				end
				if pInfo.keybinds then
					Keybinds = {}
					for k, v in pairs(pInfo.keybinds) do
						Keybinds[tostring(k)] = v
					end
					KeybindsSet = {}
					for k, v in pairs(Keybinds) do
						local num = tonumber(k)
						if num then
							KeybindsSet[num] = v
						else
							KeybindsSet[k] = v
						end
					end
				end
				if pInfo.favorites then
					Favorites = {}
					for _, v in ipairs(pInfo.favorites) do
						table.insert(Favorites, tonumber(v))
					end
					FavoritesSet = {}
					for _, v in ipairs(Favorites) do FavoritesSet[v] = true end
				end
				if pInfo.history then
					RecentEmotes = {}
					for _, item in ipairs(pInfo.history) do
						if type(item) == "table" and item.emote then
							table.insert(RecentEmotes, tonumber(item.emote))
						elseif tonumber(item) then
							table.insert(RecentEmotes, tonumber(item))
						end
					end
				end
			end
		end
		
		-- 3. Load playlists from server
		task.spawn(function()
			local plRes = ApiRequest("GET", "/emote/playlist/list?userId=" .. tostring(player.UserId) .. "&token=" .. getOrCreateToken())
			if plRes and plRes.ok and plRes.playlists then
				Playlists = plRes.playlists
				MockPlaylists = Playlists
				
				-- Sync favorites
				PlaylistFavorites = {}
				if plRes.favoritePlaylists then
					for _, favId in ipairs(plRes.favoritePlaylists) do
						PlaylistFavorites[tostring(favId)] = true
					end
				end
				
				if RefreshPlaylistsList then RefreshPlaylistsList() end
			end
		end)
	end)
	
	-- Post-process Favorites and Keybinds
	FavoritesSet = {}
	for _, v in ipairs(Favorites) do FavoritesSet[v] = true end

	KeybindsSet = {}
	for k, v in pairs(Keybinds) do
		local num = tonumber(k)
		if num then
			KeybindsSet[num] = v
		else
			KeybindsSet[k] = v
		end
	end
end


local function GetKeybind(emoteId) return KeybindsSet[emoteId] end
local function SetKeybind(emoteId, name, keyStr)
	KeybindsSet[emoteId] = {name = name, key = keyStr}
	Keybinds[tostring(emoteId)] = {name = name, key = keyStr}
	SaveData()
end
local function RemoveKeybind(emoteId)
	KeybindsSet[emoteId] = nil
	Keybinds[tostring(emoteId)] = nil
	SaveData()
end

local EmotesById = {}

local _emoteMetaCache = {}

-- ===============================================================
-- UTILITIES
-- ===============================================================

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

local logo = [[

                                                                                  
                                                                               ▄▄ 
██  ██ ██████ ██  ██ █████▄  ▄████▄   ▄████▄ ███  ██   ██████ ▄████▄ █████▄    ██ 
██▄▄██ ██▄▄    ████  ██▄▄██▄ ██  ██   ██  ██ ██ ▀▄██     ██   ██  ██ ██▄▄█▀    ██ 
 ▀██▀  ██▄▄▄▄ ██  ██ ██   ██ ▀████▀   ▀████▀ ██   ██     ██   ▀████▀ ██        ▄▄ 
                                                                                                                                                                                                            
]]

print(logo)

-- ===============================================================
-- THEMES
-- ===============================================================

local Themes = {
    -- Redesigned UI palette. Legacy names are kept so saved settings remain compatible.
    Dark = {
        primary     = Color3.fromRGB(7, 9, 15),
        sidebar     = Color3.fromRGB(10, 13, 22),
        secondary   = Color3.fromRGB(14, 18, 30),
        tertiary    = Color3.fromRGB(20, 25, 40),
        accent      = Color3.fromRGB(110, 92, 255),
        text        = Color3.fromRGB(244, 247, 255),
        textDim     = Color3.fromRGB(143, 151, 174),
        stroke      = Color3.fromRGB(43, 51, 75),
        strokeHover = Color3.fromRGB(91, 111, 172),
        critical    = Color3.fromRGB(255, 82, 112),
        success     = Color3.fromRGB(62, 214, 164)
    },
    Purple = {
        primary     = Color3.fromRGB(10, 7, 18), sidebar = Color3.fromRGB(15, 10, 27), secondary = Color3.fromRGB(22, 15, 37), tertiary = Color3.fromRGB(31, 21, 51),
        accent = Color3.fromRGB(174, 92, 255), text = Color3.fromRGB(250, 246, 255), textDim = Color3.fromRGB(169, 149, 189), stroke = Color3.fromRGB(63, 43, 83), strokeHover = Color3.fromRGB(137, 88, 180), critical = Color3.fromRGB(255, 85, 120), success = Color3.fromRGB(69, 220, 165)
    },
    Blue = {
        primary = Color3.fromRGB(6, 10, 18), sidebar = Color3.fromRGB(8, 15, 26), secondary = Color3.fromRGB(12, 22, 37), tertiary = Color3.fromRGB(17, 31, 50),
        accent = Color3.fromRGB(64, 151, 255), text = Color3.fromRGB(241, 248, 255), textDim = Color3.fromRGB(137, 164, 191), stroke = Color3.fromRGB(33, 64, 95), strokeHover = Color3.fromRGB(67, 124, 180), critical = Color3.fromRGB(255, 83, 103), success = Color3.fromRGB(55, 219, 167)
    },
    Green = {
        primary = Color3.fromRGB(6, 13, 12), sidebar = Color3.fromRGB(8, 19, 17), secondary = Color3.fromRGB(12, 27, 24), tertiary = Color3.fromRGB(17, 38, 33),
        accent = Color3.fromRGB(50, 211, 162), text = Color3.fromRGB(240, 255, 250), textDim = Color3.fromRGB(135, 180, 163), stroke = Color3.fromRGB(31, 72, 61), strokeHover = Color3.fromRGB(60, 145, 119), critical = Color3.fromRGB(255, 89, 109), success = Color3.fromRGB(65, 226, 169)
    },
    Red = {
        primary = Color3.fromRGB(15, 7, 10), sidebar = Color3.fromRGB(23, 10, 14), secondary = Color3.fromRGB(32, 14, 19), tertiary = Color3.fromRGB(44, 20, 26),
        accent = Color3.fromRGB(255, 89, 116), text = Color3.fromRGB(255, 244, 247), textDim = Color3.fromRGB(193, 145, 158), stroke = Color3.fromRGB(82, 38, 49), strokeHover = Color3.fromRGB(171, 75, 99), critical = Color3.fromRGB(255, 65, 86), success = Color3.fromRGB(64, 217, 157)
    },
    Light = {
        primary = Color3.fromRGB(242, 245, 252), sidebar = Color3.fromRGB(232, 237, 248), secondary = Color3.fromRGB(250, 252, 255), tertiary = Color3.fromRGB(226, 232, 244),
        accent = Color3.fromRGB(91, 76, 235), text = Color3.fromRGB(25, 30, 44), textDim = Color3.fromRGB(103, 113, 137), stroke = Color3.fromRGB(198, 207, 226), strokeHover = Color3.fromRGB(145, 157, 187), critical = Color3.fromRGB(221, 64, 88), success = Color3.fromRGB(38, 167, 119)
    },
    MaterialYou = {
        primary = Color3.fromRGB(8, 10, 17), sidebar = Color3.fromRGB(12, 15, 25), secondary = Color3.fromRGB(17, 21, 34), tertiary = Color3.fromRGB(24, 30, 47),
        accent = Color3.fromRGB(124, 113, 255), text = Color3.fromRGB(244, 246, 255), textDim = Color3.fromRGB(151, 157, 180), stroke = Color3.fromRGB(48, 56, 80), strokeHover = Color3.fromRGB(100, 111, 165), critical = Color3.fromRGB(255, 90, 115), success = Color3.fromRGB(63, 214, 163)
    },
    FrostedGlass = {
        primary = Color3.fromRGB(219, 228, 246), sidebar = Color3.fromRGB(207, 217, 239), secondary = Color3.fromRGB(233, 239, 251), tertiary = Color3.fromRGB(244, 247, 255),
        accent = Color3.fromRGB(83, 103, 230), text = Color3.fromRGB(28, 34, 52), textDim = Color3.fromRGB(95, 107, 138), stroke = Color3.fromRGB(170, 185, 216), strokeHover = Color3.fromRGB(118, 139, 185), critical = Color3.fromRGB(211, 62, 86), success = Color3.fromRGB(39, 169, 119)
    },
    DarkGlass = {
        primary = Color3.fromRGB(8, 10, 17), sidebar = Color3.fromRGB(12, 15, 25), secondary = Color3.fromRGB(17, 21, 34), tertiary = Color3.fromRGB(24, 30, 47),
        accent = Color3.fromRGB(100, 113, 255), text = Color3.fromRGB(243, 246, 255), textDim = Color3.fromRGB(142, 151, 176), stroke = Color3.fromRGB(46, 55, 82), strokeHover = Color3.fromRGB(94, 111, 170), critical = Color3.fromRGB(255, 84, 110), success = Color3.fromRGB(61, 213, 162)
    }
}

local currentTheme = Themes[Settings.theme] or Themes.Dark
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
		local screenGui = playerGui:FindFirstChild("VexroEmotes") or game:GetService("CoreGui"):FindFirstChild("VexroEmotes")
		if not screenGui then
			game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
			return
		end
		
		local container = screenGui:FindFirstChild("NotificationContainer")
		if not container then
			container = Instance.new("Frame")
			container.Name = "NotificationContainer"
			container.Size = UDim2.new(0, 300, 1, -40)
			container.Position = UDim2.new(0.5, -150, 0, 20)
			container.BackgroundTransparency = 1
			container.ZIndex = 30000
			container.Parent = screenGui
			
			local uiList = Instance.new("UIListLayout")
			uiList.Padding = UDim.new(0, 10)
			uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center
			uiList.VerticalAlignment = Enum.VerticalAlignment.Top
			uiList.Parent = container
		end
		
		local theme = currentTheme or Themes.Dark
		
		local wrapper = Instance.new("Frame")
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.new(1, 0, 0, 60)
		wrapper.ClipsDescendants = true
		wrapper.Parent = container
		
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(1, 0, 1, 0)
		toast.Position = UDim2.new(0, 0, -1, -20)
		toast.BackgroundColor3 = theme.secondary
		toast.ZIndex = 30001
		toast.Parent = wrapper
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
		
		local toastStroke = Instance.new("UIStroke")
		toastStroke.Color = theme.stroke
		toastStroke.Thickness = 2
		toastStroke.Parent = toast
		
		local iconOffset = 0
		if iconId then
			local notifIcon = Instance.new("ImageLabel")
			notifIcon.Size = UDim2.new(0, 22, 0, 22)
			notifIcon.AnchorPoint = Vector2.new(0, 0.5)
			notifIcon.Position = UDim2.new(0, 10, 0, 16)
			notifIcon.BackgroundTransparency = 1
			notifIcon.Image = ResolveAssetImage("rbxassetid://" .. tostring(iconId))
			notifIcon.ZIndex = 30003
			notifIcon.Parent = toast
			iconOffset = 28
		end

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -(15 + iconOffset), 0, 25)
		titleLbl.Position = UDim2.new(0, 10 + iconOffset, 0, 5)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = title
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 15
		titleLbl.TextColor3 = theme.text
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.ZIndex = 30002
		titleLbl.Parent = toast
		
		local textLbl = Instance.new("TextLabel")
		textLbl.Size = UDim2.new(1, -15, 0, 25)
		textLbl.Position = UDim2.new(0, 10, 0, 30)
		textLbl.BackgroundTransparency = 1
		textLbl.Text = text
		textLbl.Font = Enum.Font.Gotham
		textLbl.TextSize = 13
		textLbl.TextColor3 = theme.textDim
		textLbl.TextXAlignment = Enum.TextXAlignment.Left
		textLbl.TextWrapped = true
		textLbl.ZIndex = 30002
		textLbl.Parent = toast
		
		TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
		
		task.delay(3, function()
			local outTween = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, -1, -20)})
			outTween:Play()
			task.wait(0.4)
			wrapper:Destroy()
		end)
	end)
end

local VEXRO_REMOTE_URL = "https://raw.githubusercontent.com/zyrovell/Vexro/main/src/vexroemotes.lua"
local VEXRO_LOCAL_RELOAD_PATHS = {
	"vexroemote.txt",
	"vexroemotes.lua",
	"VexroEmotes.lua",
	"C:\\Users\\merte\\Desktop\\vexroemote.txt",
}

local function RunVexroSource(source, label)
	local loader = (type(loadstring) == "function" and loadstring) or (type(load) == "function" and load)
	if type(loader) ~= "function" then
		warn("[Vexro] " .. label .. " failed: loadstring is not available")
		Notify("Vexro", "Executor loadstring desteklemiyor.")
		return false
	end
	if type(source) ~= "string" or source == "" then
		warn("[Vexro] " .. label .. " failed: empty source")
		Notify("Vexro", "Reload kaynagi bos geldi.")
		return false
	end

	local chunk, compileErr = loader(source)
	if type(chunk) ~= "function" then
		warn("[Vexro] " .. label .. " compile failed: " .. tostring(compileErr))
		Notify("Vexro", "Reload scripti derlenemedi.")
		return false
	end

	local ok, runErr = pcall(chunk)
	if not ok then
		warn("[Vexro] " .. label .. " runtime failed: " .. tostring(runErr))
		Notify("Vexro", "Reload calisirken hata verdi.")
		return false
	end
	return true
end

local function ReloadVexro()
	if type(readfile) == "function" and type(isfile) == "function" then
		for _, path in ipairs(VEXRO_LOCAL_RELOAD_PATHS) do
			local ok, exists = pcall(isfile, path)
			if ok and exists then
				local readOk, source = pcall(readfile, path)
				if readOk and RunVexroSource(source, "local reload") then
					return true
				end
			end
		end
	end

	local ok, source = pcall(function()
		return game:HttpGet(VEXRO_REMOTE_URL)
	end)
	if not ok then
		warn("[Vexro] remote reload http failed: " .. tostring(source))
		Notify("Vexro", "Remote reload indirilemedi.")
		return false
	end
	return RunVexroSource(source, "remote reload")
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
		mainStrokeGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, currentTheme.stroke),
			ColorSequenceKeypoint.new(0.33, currentTheme.accent),
			ColorSequenceKeypoint.new(0.66, currentTheme.stroke),
			ColorSequenceKeypoint.new(1, currentTheme.accent)
		}
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

-- ===============================================================
-- GUI
-- ===============================================================

gui = Instance.new("ScreenGui")
gui.Name = "VexroEmotes"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- ===============================================================
-- LANGUAGE SELECTION — ES / EN ONLY
-- ===============================================================

local selectedLang = nil
local rememberLang = false

-- Old saved languages are intentionally discarded in this redesigned build.
if Settings.language == "ES" or Settings.language == "EN" then
    selectedLang = Settings.language
else
    Settings.language = nil
end

if not selectedLang then
    local langTheme = Themes[Settings.theme] or Themes.Dark

    langScreen = Instance.new("Frame")
    langScreen.Size = UDim2.fromScale(1, 1)
    langScreen.BackgroundColor3 = langTheme.primary
    langScreen.ZIndex = 20000
    langScreen.Parent = gui

    local wash = Instance.new("Frame")
    wash.Size = UDim2.fromScale(1, 1)
    wash.BackgroundColor3 = Color3.new(1, 1, 1)
    wash.BackgroundTransparency = 0
    wash.ZIndex = 20000
    wash.Parent = langScreen
    local washGrad = Instance.new("UIGradient")
    washGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, langTheme.primary),
        ColorSequenceKeypoint.new(0.55, langTheme.secondary),
        ColorSequenceKeypoint.new(1, langTheme.primary)
    }
    washGrad.Rotation = 125
    washGrad.Parent = wash

    local glowA = Instance.new("Frame")
    glowA.Size = UDim2.new(0, 340, 0, 340)
    glowA.Position = UDim2.new(0.15, -170, 0.2, -170)
    glowA.BackgroundColor3 = langTheme.accent
    glowA.BackgroundTransparency = 0.86
    glowA.ZIndex = 20000
    glowA.Parent = langScreen
    Instance.new("UICorner", glowA).CornerRadius = UDim.new(1, 0)

    local glowB = glowA:Clone()
    glowB.Position = UDim2.new(0.85, -170, 0.8, -170)
    glowB.BackgroundTransparency = 0.91
    glowB.Parent = langScreen

    langBox = Instance.new("Frame")
    langBox.Size = UDim2.new(0, 0, 0, 0)
    langBox.Position = UDim2.fromScale(0.5, 0.5)
    langBox.AnchorPoint = Vector2.new(0.5, 0.5)
    langBox.BackgroundColor3 = langTheme.secondary
    langBox.ZIndex = 20001
    langBox.Parent = langScreen
    Instance.new("UICorner", langBox).CornerRadius = UDim.new(0, 16)

    local langStroke = Instance.new("UIStroke")
    langStroke.Color = langTheme.stroke
    langStroke.Thickness = 1
    langStroke.Transparency = 0.2
    langStroke.Parent = langBox

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(0, 48, 0, 4)
    accentLine.Position = UDim2.new(0, 24, 0, 22)
    accentLine.BackgroundColor3 = langTheme.accent
    accentLine.ZIndex = 20002
    accentLine.Parent = langBox
    Instance.new("UICorner", accentLine).CornerRadius = UDim.new(1, 0)

    langTitle = Instance.new("TextLabel")
    langTitle.Size = UDim2.new(1, -48, 0, 34)
    langTitle.Position = UDim2.new(0, 24, 0, 38)
    langTitle.BackgroundTransparency = 1
    langTitle.Text = "Choose your language"
    langTitle.TextColor3 = langTheme.text
    langTitle.Font = Enum.Font.GothamBold
    langTitle.TextSize = isMobile and 20 or 24
    langTitle.TextXAlignment = Enum.TextXAlignment.Left
    langTitle.ZIndex = 20002
    langTitle.Parent = langBox

    local langSub = Instance.new("TextLabel")
    langSub.Size = UDim2.new(1, -48, 0, 24)
    langSub.Position = UDim2.new(0, 24, 0, 72)
    langSub.BackgroundTransparency = 1
    langSub.Text = "Selecciona Español o English"
    langSub.TextColor3 = langTheme.textDim
    langSub.Font = Enum.Font.Gotham
    langSub.TextSize = isMobile and 12 or 13
    langSub.TextXAlignment = Enum.TextXAlignment.Left
    langSub.ZIndex = 20002
    langSub.Parent = langBox

    local function MakeLangBtn(titleText, subText, lang, xScale)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.44, 0, 0, 92)
        btn.Position = UDim2.new(xScale, 0, 0, 112)
        btn.BackgroundColor3 = langTheme.tertiary
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 20003
        btn.Parent = langBox
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 13)

        local stroke = Instance.new("UIStroke")
        stroke.Color = langTheme.stroke
        stroke.Thickness = 1
        stroke.Transparency = 0.35
        stroke.Parent = btn

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -20, 0, 30)
        t.Position = UDim2.new(0, 10, 0, 18)
        t.BackgroundTransparency = 1
        t.Text = titleText
        t.TextColor3 = langTheme.text
        t.Font = Enum.Font.GothamBold
        t.TextSize = isMobile and 16 or 18
        t.ZIndex = 20004
        t.Parent = btn

        local s = Instance.new("TextLabel")
        s.Size = UDim2.new(1, -20, 0, 22)
        s.Position = UDim2.new(0, 10, 0, 51)
        s.BackgroundTransparency = 1
        s.Text = subText
        s.TextColor3 = langTheme.textDim
        s.Font = Enum.Font.Gotham
        s.TextSize = isMobile and 11 or 12
        s.ZIndex = 20004
        s.Parent = btn

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.16), {BackgroundColor3 = langTheme.accent}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.16), {Color = langTheme.accent, Transparency = 0}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.16), {BackgroundColor3 = langTheme.tertiary}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.16), {Color = langTheme.stroke, Transparency = 0.35}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            selectedLang = lang
        end)
    end

    MakeLangBtn("Español", "Interfaz en español", "ES", 0.04)
    MakeLangBtn("English", "English interface", "EN", 0.52)

    rememberBtn = Instance.new("TextButton")
    rememberBtn.Size = UDim2.new(0.92, 0, 0, 42)
    rememberBtn.Position = UDim2.new(0.04, 0, 1, -58)
    rememberBtn.BackgroundColor3 = langTheme.tertiary
    rememberBtn.Text = "Remember / Recordar"
    rememberBtn.TextColor3 = langTheme.textDim
    rememberBtn.Font = Enum.Font.GothamMedium
    rememberBtn.TextSize = isMobile and 12 or 13
    rememberBtn.AutoButtonColor = false
    rememberBtn.ZIndex = 20003
    rememberBtn.Parent = langBox
    Instance.new("UICorner", rememberBtn).CornerRadius = UDim.new(0, 11)

    rememberBtn.MouseButton1Click:Connect(function()
        rememberLang = not rememberLang
        TweenService:Create(rememberBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = rememberLang and langTheme.accent or langTheme.tertiary,
            TextColor3 = rememberLang and Color3.new(1,1,1) or langTheme.textDim
        }):Play()
        rememberBtn.Text = rememberLang and "✓ Remember / Recordar" or "Remember / Recordar"
    end)

    local targetSize = isMobile and UDim2.new(0, 350, 0, 285) or UDim2.new(0, 460, 0, 300)
    TweenService:Create(langBox, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = targetSize}):Play()

    repeat task.wait(0.05) until selectedLang

    if rememberLang then
        Settings.language = selectedLang
        SaveData()
    end

    TweenService:Create(langBox, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
    TweenService:Create(langScreen, TweenInfo.new(0.24), {BackgroundTransparency = 1}):Play()
    task.wait(0.24)
    langScreen:Destroy()
end

-- ===============================================================
-- LANGUAGE
-- ===============================================================

local isTR, isES, isAR, isFR, isHI, isPT, isRU = false, selectedLang == "ES", false, false, false, false, false
local L = {
	r6Msg = isES and "Solo R15!" or "R15 only!",
	loading = isES and "Cargando..." or "Loading...",
	madeBy = isES and "Hecho por Oyuncu15q" or "Made by Oyuncu15q",
	search = isES and "Buscar..." or "Search...",
	playing = isES and "Reproduciendo" or "Playing",
	stopped = isES and "Detenido" or "Stopped",
	ready = isES and "Listo!" or "Ready!",
	emotes = isES and "Emotes" or "Emotes",
	favorites = isES and "Favoritos" or "Favorites",
	recent = isES and "Recientes" or "Recent",
	settings = isES and "Ajustes" or "Settings",
	noFav = isES and "Sin favoritos" or "No favorites",
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
	friendInfoTxt = isES and "Agregar amigos permite sincronizar emotes juntos." or "Adding friends lets you sync emotes together.",
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
	serverPlayersDown = isES and "Jugadores en Servidor ▼" or "Server Vexro Players ▼",
	serverPlayersUp = isES and "Jugadores en Servidor ▲" or "Server Vexro Players ▲",
	noOneFound = isES and "Nadie encontrado" or "No one found",
}

local FriendL = {
	brandTitle = isES and "Reproductor de Emotes Vexro" or "Vexro Emote Player",
	requestIncoming = isES and "%s quiere agregarte como amigo." or "%s wants to add you as a friend.",
	playEmoteLbl = isES and "Reproducir emote de amigo" or "Play friend's emote",
	playEmoteDesc = isES and "Se reproduce automáticamente cuando tu amigo lo inicia." or "Plays automatically when your friend starts it.",
	syncEmoteLbl = isES and "Sincronizar emote con amigos" or "Sync emote with friends",
	syncEmoteDesc = isES and "Al reproducirlo, envía la sincronización a tus amigos." or "When played, it sends sync to your friends.",
	syncOn = isES and "Sincronizado" or "Sync",
	syncOff = isES and "Desactivado" or "Off",
}

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

-- ===============================================================
-- R15 CHECK
-- ===============================================================

local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid", 5)
if not hum or hum.RigType == Enum.HumanoidRigType.R6 then
	Notify(SafeUtf8Char(0x274C), L.r6Msg)
	gui:Destroy()
	return
end

local Emotes = {}

-- ===============================================================
-- SPLASH SCREEN
-- ===============================================================

local _bgMusic -- müzik objesi (kapanışta da lazım)
local _splashTheme = Themes[Settings.theme] or Themes.Dark
local _splashPrimary = _splashTheme.primary
local _splashAccent  = _splashTheme.accent
local _splashIsGlass = Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass"

-- GTA IV muzigi
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
splashBlur.Size = 24
splashBlur.Parent = game:GetService("Lighting")

splash = Instance.new("Frame")
splash.Size = UDim2.fromScale(1, 1)
splash.BackgroundColor3 = _splashPrimary
splash.BackgroundTransparency = _splashIsGlass and 0.42 or 0.08
splash.ZIndex = 10000
splash.Parent = gui

splashBgGrad = Instance.new("UIGradient")
splashBgGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,   _splashPrimary),
	ColorSequenceKeypoint.new(0.5, Color3.new(
		math.clamp(_splashPrimary.R + _splashAccent.R * 0.15, 0, 1),
		math.clamp(_splashPrimary.G + _splashAccent.G * 0.15, 0, 1),
		math.clamp(_splashPrimary.B + _splashAccent.B * 0.20, 0, 1)
	)),
	ColorSequenceKeypoint.new(1,   _splashPrimary)
}
splashBgGrad.Rotation = 45
splashBgGrad.Parent = splash

task.spawn(function()
	local rot = 0
	while splash.Parent do
		rot = (rot + 1) % 360
		splashBgGrad.Rotation = rot
		task.wait(0.05)
	end
end)

splashBox = Instance.new("Frame")
splashBox.Size = UDim2.new(0, 0, 0, 0)
splashBox.Position = UDim2.fromScale(0.5, 0.5)
splashBox.AnchorPoint = Vector2.new(0.5, 0.5)
splashBox.BackgroundColor3 = _splashTheme.secondary
splashBox.BackgroundTransparency = _splashIsGlass and 0.30 or 0.02
splashBox.Rotation = 0
splashBox.ZIndex = 10001
splashBox.Parent = splash
Instance.new("UICorner", splashBox).CornerRadius = UDim.new(0, 16)

splashStroke = Instance.new("UIStroke")
splashStroke.Color = _splashAccent
splashStroke.Thickness = 1
splashStroke.Parent = splashBox

splashStrokeGrad = Instance.new("UIGradient")
splashStrokeGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,    _splashAccent),
	ColorSequenceKeypoint.new(0.33, _splashTheme.stroke),
	ColorSequenceKeypoint.new(0.66, _splashAccent),
	ColorSequenceKeypoint.new(1,    _splashAccent)
}
splashStrokeGrad.Parent = splashStroke

task.spawn(function()
	local rot = 0
	while splashStroke.Parent do
		rot = rot + 360
		TweenService:Create(splashStrokeGrad, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {Rotation = rot}):Play()
		task.wait(1.5)
	end
end)

avatarHolder = Instance.new("Frame")
avatarHolder.Size = UDim2.new(1, -24, 0, 50)
avatarHolder.Position = UDim2.new(0, 12, 0, 12)
avatarHolder.BackgroundTransparency = 1
avatarHolder.ZIndex = 10002
avatarHolder.Parent = splashBox

avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.new(0, 44, 0, 44)
avatar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=3164346931&width=150&height=150&format=png"
avatar.ZIndex = 10003
avatar.Parent = avatarHolder
Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

avatarGlow = Instance.new("UIStroke")
avatarGlow.Color = Color3.fromRGB(138, 43, 226)
avatarGlow.Thickness = 2
avatarGlow.Parent = avatar

task.spawn(function()
	while avatar.Parent do
		TweenService:Create(avatarGlow, TweenInfo.new(1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(186, 85, 211)}):Play()
		task.wait(1)
		TweenService:Create(avatarGlow, TweenInfo.new(1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(138, 43, 226)}):Play()
		task.wait(1)
	end
end)

madeByLbl = Instance.new("TextLabel")
madeByLbl.Size = UDim2.new(1, -54, 1, 0)
madeByLbl.Position = UDim2.new(0, 52, 0, 0)
madeByLbl.BackgroundTransparency = 1
madeByLbl.Text = L.madeBy
madeByLbl.TextColor3 = _splashTheme.textDim
madeByLbl.Font = Enum.Font.GothamBold
madeByLbl.TextScaled = true
madeByLbl.TextXAlignment = Enum.TextXAlignment.Left
madeByLbl.ZIndex = 10003
madeByLbl.Parent = avatarHolder

logo = Instance.new("TextLabel")
logo.Size = UDim2.new(1, -24, 0, 60)
logo.Position = UDim2.new(0, 12, 0, 70)
logo.BackgroundTransparency = 1
logo.Text = "Vexro Emotes"
logo.TextColor3 = _splashTheme.text
logo.Font = Enum.Font.GothamBlack
logo.TextScaled = true
logo.ZIndex = 10003
logo.Parent = splashBox

logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,    _splashAccent),
	ColorSequenceKeypoint.new(0.25, _splashTheme.stroke),
	ColorSequenceKeypoint.new(0.5,  _splashAccent),
	ColorSequenceKeypoint.new(0.75, _splashTheme.stroke),
	ColorSequenceKeypoint.new(1,    _splashAccent)
}
logoGrad.Parent = logo

task.spawn(function()
	while logo.Parent do
		TweenService:Create(logoGrad, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)}):Play()
		task.wait(2)
		TweenService:Create(logoGrad, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(-1, 0)}):Play()
		task.wait(2)
	end
end)

loadingLbl = Instance.new("TextLabel")
loadingLbl.Size = UDim2.new(1, 0, 0, 30)
loadingLbl.Position = UDim2.new(0, 0, 0, 140)
loadingLbl.BackgroundTransparency = 1
loadingLbl.Text = L.loading
loadingLbl.TextColor3 = _splashTheme.textDim
loadingLbl.Font = Enum.Font.GothamBold
loadingLbl.TextSize = 16
loadingLbl.ZIndex = 10003
loadingLbl.Parent = splashBox

task.spawn(function()
	local dots = {"", ".", "..", "..."}
	local i = 1
	while loadingLbl.Parent do
		loadingLbl.Text = "Vexro Emotes " .. L.loading .. dots[i]
		i = i % 4 + 1
		task.wait(0.4)
	end
end)

loadingBarBg = Instance.new("Frame")
loadingBarBg.Size = UDim2.new(0.8, 0, 0, 6)
loadingBarBg.Position = UDim2.new(0.1, 0, 0, 175)
loadingBarBg.BackgroundColor3 = _splashTheme.tertiary
loadingBarBg.ZIndex = 10003
loadingBarBg.Parent = splashBox
Instance.new("UICorner", loadingBarBg).CornerRadius = UDim.new(1, 0)

loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.new(0, 0, 1, 0)
loadingBar.BackgroundColor3 = _splashAccent
loadingBar.ZIndex = 10004
loadingBar.Parent = loadingBarBg
Instance.new("UICorner", loadingBar).CornerRadius = UDim.new(1, 0)

loadingBarGrad = Instance.new("UIGradient")
loadingBarGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, _splashAccent),
	ColorSequenceKeypoint.new(0.5, _splashTheme.stroke),
	ColorSequenceKeypoint.new(1, _splashAccent)
}
loadingBarGrad.Parent = loadingBar

discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0.85, 0, 0, 42)
discordBtn.Position = UDim2.new(0.075, 0, 1, -55)
discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
discordBtn.Text = "Discord: 4Bs9WYSabf"
discordBtn.TextColor3 = Color3.new(1, 1, 1)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = 14
discordBtn.ZIndex = 10003
discordBtn.Parent = splashBox
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 10)

discordBtn.MouseButton1Click:Connect(function()
	pcall(function() if setclipboard then setclipboard("https://discord.gg/4Bs9WYSabf") end end)
	Notify(SafeUtf8Char(0x2705), L.copied)
end)

local splashSize = isMobile and UDim2.new(0, 320, 0, 240) or UDim2.new(0, 420, 0, 270)
TweenService:Create(splashBox, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = splashSize, Rotation = 0}):Play()

-- ===============================================================
-- EMOTE LOADING
-- ===============================================================

TweenService:Create(loadingBar, TweenInfo.new(0.5), {Size = UDim2.new(0.3, 0, 1, 0)}):Play()
task.wait(0.3)

local function LoadEmotes()
	debugLog("LoadEmotes starting")
	local success, result = pcall(function()
		local response = game:HttpGet("https://vexroscripts.com.tr/emotes.json?t=" .. tick())
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
		local response = game:HttpGet("https://vexroscripts.com.tr/animations.json?t=" .. tick())
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
	
	lastVexroAnimationPack = pack
	Notify("🎨 " .. (isES and "Animación equipada" or "Animation Equipped"), pack.name)
end

LoadData()
LoadEmotes()
LoadAnimations()

for _, emote in ipairs(Emotes) do
	EmotesById[emote.id] = emote
	emote._lname = emote.name:lower()
end
TweenService:Create(loadingBar, TweenInfo.new(1), {Size = UDim2.new(1, 0, 1, 0)}):Play()
task.wait(1)

loadingLbl.Text = SafeUtf8Char(0x2705) .. " " .. #Emotes .. " emotes!"
task.wait(1)

-- Loading bitti: splash kapat + müzik 2 saniyede kısıl
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

local MakeRow, MakeSectionHeader, MakePillToggle

-- ===============================================================
-- UI SIZE SETTINGS
-- ===============================================================
local ICON_SCALE = 1.0
local BUTTON_SCALE = 1.0
local FONT_SCALE = 1.0

-- ===============================================================
-- VARIABLES
-- ===============================================================

local EMOTE_ICON = "rbxassetid://120313093991132"
local currentData, filtered = Emotes, Emotes
local currentTab = "emotes"
local page, perPage, pages, cols = 1, 14, 1, 7
local cards = {}
local lastVexroAnimationPack = nil
local sideBarW = isMobile and 58 or 150
local tabBtnS = isMobile and 42 or 40
local bottomBarH = isMobile and 24 or 22
local currentCardSize = 0
local _badEmotes = {}
local _refreshPending = false

-- ===============================================================
-- FAVORITES & RECENT
-- ===============================================================

local function IsFavorite(id)
	return FavoritesSet[tonumber(id)] == true
end

local MAX_FAVORITES = 25

local function ToggleFavorite(id)
	id = tonumber(id)
	if FavoritesSet[id] then
		-- Optimistic remove
		FavoritesSet[id] = nil
		for i = #Favorites, 1, -1 do
			if Favorites[i] == id then
				table.remove(Favorites, i)
				break
			end
		end
		SaveData()
		task.spawn(function()
			ApiRequest("POST", "/emote/favorite", {
				userId = tostring(player.UserId),
				token = getOrCreateToken(),
				emoteId = tostring(id),
				action = "remove"
			})
		end)
		return false
	end
	
	if #Favorites >= MAX_FAVORITES then
		Notify("⭐ " .. L.favLimit, "")
		return false
	end
	
	-- Optimistic add
	FavoritesSet[id] = true
	Favorites[#Favorites + 1] = id
	SaveData()
	task.spawn(function()
		ApiRequest("POST", "/emote/favorite", {
			userId = tostring(player.UserId),
			token = getOrCreateToken(),
			emoteId = tostring(id),
			action = "add"
		})
	end)
	return true
end

local function AddToRecent(id)
	id = tonumber(id)
	task.spawn(function()
		local res = ApiRequest("POST", "/emote/history/add", {
			userId = tostring(player.UserId),
			token = getOrCreateToken(),
			emoteId = tostring(id)
		})
		if res and res.status == "success" and res.history then
			RecentEmotes = res.history
			SaveData()
			if currentTab == "recent" and UpdateTabData then
				UpdateTabData()
			end
		end
	end)
end

-- ===============================================================
-- EMOTE & SPEED SYSTEM
-- ===============================================================

local currentAnimTrack = nil
local lastEmoteTime = 0

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
			pcall(function() track:AdjustSpeed(Settings.speed) end)
		end
	end
end


local function StopEmote(showNotif)
	StopAllTracks()
	if showNotif then Notify(L.stopped, "", 113416463749658) end
	if FriendData.currentSyncPartner then
		pcall(function()
			ApiRequest("POST", "/emote/sync/status", {
				userId = tostring(player.UserId),
				token = getOrCreateToken(),
				targetId = FriendData.currentSyncPartner,
				action = "cancel"
			})
		end)
		FriendData.currentSyncPartner = nil
	end
	if _genv().VexroBroadcastStop then
		pcall(_genv().VexroBroadcastStop)
	end
end

local _heartbeatConn = RunService.Heartbeat:Connect(function()
	if Settings.stopOnWalk and currentAnimTrack and currentAnimTrack.IsPlaying then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.MoveDirection.Magnitude > 0 then
				StopEmote(false)
			end
		end
		
		-- Instant sync partner walk & emote change detection
		if FriendData.currentSyncPartner then
			local partnerPlayer = Players:GetPlayerByUserId(tonumber(FriendData.currentSyncPartner))
			if partnerPlayer and partnerPlayer.Character then
				local partnerHumanoid = partnerPlayer.Character:FindFirstChildOfClass("Humanoid")
				if partnerHumanoid then
					if partnerHumanoid.MoveDirection.Magnitude > 0 then
						StopEmote(false)
					else
						local partnerAnimator = partnerHumanoid:FindFirstChildOfClass("Animator")
						if partnerAnimator then
							local tracks = partnerAnimator:GetPlayingAnimationTracks()
							for _, pt in ipairs(tracks) do
								if pt.Priority == Enum.AnimationPriority.Action4 and pt.IsPlaying and pt.Animation then
									local animIdStr = pt.Animation.AnimationId:match("%d+")
									if animIdStr then
										local animId = tonumber(animIdStr)
										if animId and _genv().lastVexroEmote and _genv().lastVexroEmote.id ~= animId then
											if EmotesById and EmotesById[animId] then
												local spd = Settings.speed > 0 and Settings.speed or 1
												local calcStartTime = workspace:GetServerTimeNow() - (pt.TimePosition / spd)
												PlayEmote(animId, EmotesById[animId].name, true, calcStartTime)
												break
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)

local _animCache = {}

local function PlayEmote(id, name, silent, syncStartTime)
	local animator = GetAnimator()
	if not animator then return end
	
	StopAllTracks()
	
	_genv().lastVexroEmote = {id = id, name = name}
	
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
		
		if _genv().lastVexroEmote and _genv().lastVexroEmote.id == id then
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
					track:AdjustSpeed(Settings.speed)
				end)
				
				currentAnimTrack = track
				AddToRecent(id)
			end)
			
			if success then
				if not silent then
					local speedTxt = Settings.speed ~= 1 and " (" .. Settings.speed .. "x)" or ""
					Notify(L.playing .. speedTxt, name, 129338178452237)
				end
				lastEmoteTime = tick()
				if _genv().VexroBroadcastSync and FriendData.syncEmote and not silent then
					pcall(_genv().VexroBroadcastSync, id, name, workspace:GetServerTimeNow())
				end
			else
				Notify(SafeUtf8Char(0x274C), L.emoteLoadFail)
			end
		end
	end)
end

-- ===============================================================
-- MAIN MENU
-- ===============================================================

local TARGET_PC_CARD = 92
local TARGET_MOBILE_CARD = 64

local function GetDefaultSize()
	local PAD = isMobile and 4 or 6
	local targetCard = isMobile and TARGET_MOBILE_CARD or TARGET_PC_CARD
	
	local perfectWidth = (targetCard * 7) + (PAD * 6) + sideBarW + 20
	
	local vp = workspace.CurrentCamera.ViewportSize
	local finalW = math.clamp(perfectWidth, 400, vp.X * 0.95)
	
	local cardH = targetCard + (targetCard * 0.3 * 2) + PAD
	local perfectHeight = (cardH * 2) + 60 + bottomBarH + 20
	
	local tabCount = not isMobile and 8 or 7
	local minH = (isMobile and 8 or 62) + (tabBtnS + 6) * (tabCount - 1) + tabBtnS + 16
	local finalH = math.clamp(math.max(perfectHeight, minH), minH, math.max(minH, vp.Y * 0.95))
	
	return UDim2.new(0, finalW, 0, finalH)
end

main = Instance.new("Frame")
main.Name = "MainMenu"
main.Size = UDim2.new(0, 0, 0, 0)
main.Position = UDim2.fromScale(0.5, 0.5)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = currentTheme.primary
main.BackgroundTransparency = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
RegisterTheme(main, "BackgroundColor3", "primary")

local ThemeGradients = {
	Dark        = {Color3.fromRGB(22, 22, 30),  Color3.fromRGB(10, 10, 14),  135},
	Purple      = {Color3.fromRGB(28, 18, 48),  Color3.fromRGB(10, 6, 18),   135},
	Blue        = {Color3.fromRGB(18, 28, 52),  Color3.fromRGB(6, 10, 20),   135},
	Green       = {Color3.fromRGB(16, 32, 22),  Color3.fromRGB(6, 12, 8),    135},
	Red         = {Color3.fromRGB(48, 16, 18),  Color3.fromRGB(18, 6, 8),    135},
	Light       = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 228, 238), 135},
	MaterialYou = {Color3.fromRGB(30, 34, 50),  Color3.fromRGB(12, 14, 20),  135},
	FrostedGlass= {Color3.fromRGB(230, 238, 255), Color3.fromRGB(190, 205, 235), 135},
	DarkGlass   = {Color3.fromRGB(24, 24, 34),  Color3.fromRGB(8, 8, 12),    135},
}

local VexroAcrylic = (function()
	local api = {}
	local folder, body, mesh, dof
	local conns = {}

	local function disconnectAll()
		for _, conn in ipairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
		conns = {}
	end

	function api.Stop()
		disconnectAll()
		if body then pcall(function() body:Destroy() end) end
		if folder then pcall(function() folder:Destroy() end) end
		if dof then pcall(function() dof:Destroy() end) end
		body, mesh, folder, dof = nil, nil, nil, nil
	end

	local function viewportPointToWorld(point, distance)
		local camera = workspace.CurrentCamera
		if not camera then return Vector3.new() end
		return camera:ViewportPointToRay(point.X, point.Y, distance).Origin
	end

	local function getViewportOffset()
		if gui.IgnoreGuiInset then
			local ok, inset = pcall(function()
				return game:GetService("GuiService"):GetGuiInset()
			end)
			if ok and inset then return inset end
		end
		return Vector2.new()
	end

	local function createBody()
		local part = Instance.new("Part")
		part.Name = "VexroGlassBody"
		part.Color = Color3.new(0, 0, 0)
		part.Material = Enum.Material.Glass
		part.Size = Vector3.new(1, 1, 0)
		part.Anchored = true
		part.CanCollide = false
		part.Locked = true
		part.CastShadow = false
		part.Transparency = 0.985

		local partMesh = Instance.new("SpecialMesh")
		partMesh.MeshType = Enum.MeshType.Brick
		partMesh.Offset = Vector3.new(0, 0, -0.000001)
		partMesh.Parent = part

		return part, partMesh
	end

	function api.Start(themeName)
		if isMobile then return end
		if body and body.Parent then
			if dof then
				dof.InFocusRadius = themeName == "FrostedGlass" and 0.08 or 0.12
				dof.NearIntensity = themeName == "FrostedGlass" and 0.85 or 1
			end
			body.Transparency = themeName == "FrostedGlass" and 0.985 or 0.99
			return
		end

		api.Stop()

		folder = Instance.new("Folder")
		folder.Name = "VexroGlassBlurFolder"
		folder.Parent = workspace

		body, mesh = createBody()
		body.Parent = folder

		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "VexroGlassBlur"
		dof.FarIntensity = 0
		dof.InFocusRadius = themeName == "FrostedGlass" and 0.08 or 0.12
		dof.NearIntensity = themeName == "FrostedGlass" and 0.85 or 1
		dof.Parent = game:GetService("Lighting")

		local positions = {
			topLeft = Vector2.new(),
			topRight = Vector2.new(),
			bottomRight = Vector2.new(),
		}

		local function updatePositions()
			local size = main.AbsoluteSize
			local inset = getViewportOffset()
			local pad = math.clamp(math.min(size.X, size.Y) * 0.035, 10, 18)
			local pos = main.AbsolutePosition + inset + Vector2.new(pad, pad)
			local clippedSize = Vector2.new(math.max(size.X - pad * 2, 1), math.max(size.Y - pad * 2, 1))
			positions.topLeft = pos
			positions.topRight = pos + Vector2.new(clippedSize.X, 0)
			positions.bottomRight = pos + clippedSize
		end

		local function render()
			if not body or not mesh or not main or not main.Parent then return end
			local camera = workspace.CurrentCamera
			if not camera then return end

			local size = main.AbsoluteSize
			if not gui.Enabled or not main.Visible or size.X <= 2 or size.Y <= 2 then
				body.Transparency = 1
				return
			end

			body.Transparency = themeName == "FrostedGlass" and 0.985 or 0.99
			updatePositions()

			local distance = 0.002
			local topLeft3D = viewportPointToWorld(positions.topLeft, distance)
			local topRight3D = viewportPointToWorld(positions.topRight, distance)
			local bottomRight3D = viewportPointToWorld(positions.bottomRight, distance)
			local width = (topRight3D - topLeft3D).Magnitude
			local height = (topRight3D - bottomRight3D).Magnitude

			body.CFrame = CFrame.fromMatrix(
				(topLeft3D + bottomRight3D) / 2,
				camera.CFrame.XVector,
				camera.CFrame.YVector,
				camera.CFrame.ZVector
			)
			mesh.Scale = Vector3.new(width, height, 0)
		end

		table.insert(conns, main:GetPropertyChangedSignal("AbsolutePosition"):Connect(render))
		table.insert(conns, main:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
		table.insert(conns, main:GetPropertyChangedSignal("Visible"):Connect(render))
		table.insert(conns, gui:GetPropertyChangedSignal("Enabled"):Connect(render))
		table.insert(conns, RunService.RenderStepped:Connect(render))
		table.insert(conns, main.Destroying:Connect(api.Stop))

		render()
	end

	return api
end)()

local _glassApplyBase = ApplyTheme
ApplyTheme = function(name)
	_glassApplyBase(name)
	local isGlass = name == "FrostedGlass" or name == "DarkGlass"
	if isGlass then
		VexroAcrylic.Start(name)
	else
		VexroAcrylic.Stop()
	end
	TweenService:Create(main, TweenInfo.new(0.3), {BackgroundTransparency = isGlass and 0.18 or 0}):Play()
	local noiseOverlay = main:FindFirstChild("VexroGlassNoise")
	if isGlass then
		if not noiseOverlay then
			noiseOverlay = Instance.new("ImageLabel")
			noiseOverlay.Name = "VexroGlassNoise"
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
	local gradFrame = main:FindFirstChild("VexroGradFrame")
	if not gradFrame then
		gradFrame = Instance.new("Frame")
		gradFrame.Name = "VexroGradFrame"
		gradFrame.Size = UDim2.new(1, 0, 1, 0)
		gradFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		gradFrame.BackgroundTransparency = 0
		gradFrame.BorderSizePixel = 0
		gradFrame.ZIndex = 1
		gradFrame.Parent = main
		Instance.new("UICorner", gradFrame).CornerRadius = UDim.new(0, 14)
		local grad = Instance.new("UIGradient")
		grad.Name = "VexroMainGrad"
		grad.Parent = gradFrame
	end
	TweenService:Create(gradFrame, TweenInfo.new(0.3), {BackgroundTransparency = isGlass and 0.45 or 0}):Play()
	local grad = gradFrame:FindFirstChild("VexroMainGrad")
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
mainStroke.Color = currentTheme.stroke
mainStroke.Thickness = 1
mainStroke.Transparency = 0.12
mainStroke.Parent = main
RegisterTheme(mainStroke, "Color", "stroke")

mainStrokeGrad = Instance.new("UIGradient")
mainStrokeGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, currentTheme.accent),
    ColorSequenceKeypoint.new(0.28, currentTheme.stroke),
    ColorSequenceKeypoint.new(0.72, currentTheme.stroke),
    ColorSequenceKeypoint.new(1, currentTheme.accent)
}
mainStrokeGrad.Rotation = 0
mainStrokeGrad.Parent = mainStroke

-- Soft ambient shapes replace the old particle field.
bgParticles = Instance.new("Frame")
bgParticles.Name = "AmbientLayer"
bgParticles.Size = UDim2.new(1, 0, 1, 0)
bgParticles.BackgroundTransparency = 1
bgParticles.ClipsDescendants = true
bgParticles.ZIndex = 1
bgParticles.Parent = main

local ambientA = Instance.new("Frame")
ambientA.Size = UDim2.new(0, 360, 0, 360)
ambientA.Position = UDim2.new(1, -220, 0, -220)
ambientA.BackgroundColor3 = currentTheme.accent
ambientA.BackgroundTransparency = 0.94
ambientA.ZIndex = 1
ambientA.Parent = bgParticles
Instance.new("UICorner", ambientA).CornerRadius = UDim.new(1, 0)
RegisterTheme(ambientA, "BackgroundColor3", "accent")

local ambientB = ambientA:Clone()
ambientB.Size = UDim2.new(0, 260, 0, 260)
ambientB.Position = UDim2.new(0, -130, 1, -100)
ambientB.BackgroundTransparency = 0.965
ambientB.Parent = bgParticles

-- ===============================================================
-- NAVIGATION RAIL
-- ===============================================================

sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, sideBarW, 1, 0)
sidebar.BackgroundColor3 = currentTheme.sidebar
sidebar.BorderSizePixel = 0
sidebar.ClipsDescendants = true
sidebar.ZIndex = 8
sidebar.Parent = main
RegisterTheme(sidebar, "BackgroundColor3", "sidebar")

local navDivider = Instance.new("Frame")
navDivider.Size = UDim2.new(0, 1, 1, -24)
navDivider.Position = UDim2.new(1, -1, 0, 12)
navDivider.BackgroundColor3 = currentTheme.stroke
navDivider.BackgroundTransparency = 0.35
navDivider.BorderSizePixel = 0
navDivider.ZIndex = 9
navDivider.Parent = sidebar
RegisterTheme(navDivider, "BackgroundColor3", "stroke")

local tabStartY = isMobile and 8 or 62
if not isMobile then
    local brand = Instance.new("Frame")
    brand.Size = UDim2.new(1, -18, 0, 42)
    brand.Position = UDim2.new(0, 9, 0, 10)
    brand.BackgroundColor3 = currentTheme.tertiary
    brand.ZIndex = 10
    brand.Parent = sidebar
    Instance.new("UICorner", brand).CornerRadius = UDim.new(0, 11)
    RegisterTheme(brand, "BackgroundColor3", "tertiary")

    local brandDot = Instance.new("Frame")
    brandDot.Size = UDim2.new(0, 9, 0, 9)
    brandDot.Position = UDim2.new(0, 13, 0.5, -4)
    brandDot.BackgroundColor3 = currentTheme.accent
    brandDot.ZIndex = 11
    brandDot.Parent = brand
    Instance.new("UICorner", brandDot).CornerRadius = UDim.new(1, 0)
    RegisterTheme(brandDot, "BackgroundColor3", "accent")

    local brandText = Instance.new("TextLabel")
    brandText.Size = UDim2.new(1, -34, 1, 0)
    brandText.Position = UDim2.new(0, 30, 0, 0)
    brandText.BackgroundTransparency = 1
    brandText.Text = "VEXRO  /  EMOTES"
    brandText.TextColor3 = currentTheme.text
    brandText.Font = Enum.Font.GothamBold
    brandText.TextSize = 11
    brandText.TextXAlignment = Enum.TextXAlignment.Left
    brandText.ZIndex = 11
    brandText.Parent = brand
    RegisterTheme(brandText, "TextColor3", "text")
end

local tabBtns = {}
local tabLabels = {
    emotes = isES and "Emotes" or "Emotes",
    animations = isES and "Animaciones" or "Animations",
    favorites = isES and "Favoritos" or "Favorites",
    recent = isES and "Recientes" or "Recent",
    friends = isES and "Amigos" or "Friends",
    keybinds = isES and "Teclas" or "Keybinds",
    playlists = isES and "Listas" or "Playlists",
    settings = isES and "Ajustes" or "Settings",
}

local function CreateTabBtn(icon, tabName, yPos, customScale, rawImage)
    local btn = Instance.new("TextButton")
    btn.Size = isMobile and UDim2.new(0, tabBtnS, 0, tabBtnS) or UDim2.new(1, -16, 0, tabBtnS)
    btn.Position = isMobile and UDim2.new(0.5, -tabBtnS/2, 0, yPos) or UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = currentTheme.tertiary
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 10
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = currentTheme.stroke
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = btn
    RegisterTheme(stroke, "Color", "stroke")

    local isUrl = type(icon) == "string" and (string.find(icon, "rbxassetid://") or string.find(icon, "http") or string.find(icon, "rbxthumb://"))
    local imgElement = nil
    local iconSize = isMobile and 22 or 20
    if isUrl then
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(0, iconSize, 0, iconSize)
        img.Position = isMobile and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 12, 0.5, 0)
        img.AnchorPoint = isMobile and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)
        img.BackgroundTransparency = 1
        img.Image = rawImage or ResolveAssetImage(icon)
        img.ImageColor3 = currentTheme.textDim
        img.ZIndex = 12
        img.Parent = btn
        RegisterTheme(img, "ImageColor3", "textDim")
        imgElement = img
    else
        local glyph = Instance.new("TextLabel")
        glyph.Size = UDim2.new(0, iconSize + 4, 0, iconSize + 4)
        glyph.Position = isMobile and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 10, 0.5, 0)
        glyph.AnchorPoint = isMobile and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)
        glyph.BackgroundTransparency = 1
        glyph.Text = icon
        glyph.TextColor3 = currentTheme.textDim
        glyph.Font = Enum.Font.GothamBold
        glyph.TextSize = 17
        glyph.ZIndex = 12
        glyph.Parent = btn
        RegisterTheme(glyph, "TextColor3", "textDim")
        imgElement = glyph
    end

    local label = nil
    if not isMobile then
        label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -46, 1, 0)
        label.Position = UDim2.new(0, 42, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = tabLabels[tabName] or tabName
        label.TextColor3 = currentTheme.textDim
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 12
        label.Parent = btn
        RegisterTheme(label, "TextColor3", "textDim")
    end

    btn.MouseEnter:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(btn, TweenInfo.new(0.14), {BackgroundTransparency = 0.55}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(btn, TweenInfo.new(0.14), {BackgroundTransparency = 1}):Play()
        end
    end)

    tabBtns[tabName] = {btn = btn, stroke = stroke, img = imgElement, label = label, yPos = yPos}
    return btn
end

CreateTabBtn(Icons.Emote, "emotes", tabStartY)
CreateTabBtn("rbxassetid://75528584354229", "animations", tabStartY + tabBtnS + 6, 0.85)
CreateTabBtn(Icons.FavoriteFull, "favorites", tabStartY + (tabBtnS + 6) * 2)
CreateTabBtn(Icons.Recent, "recent", tabStartY + (tabBtnS + 6) * 3)
CreateTabBtn("rbxassetid://115725480722697", "friends", tabStartY + (tabBtnS + 6) * 4)
if not isMobile then
    CreateTabBtn(Icons.Keybind, "keybinds", tabStartY + (tabBtnS + 6) * 5)
    CreateTabBtn("rbxassetid://108973165274475", "playlists", tabStartY + (tabBtnS + 6) * 6, 1.15)
    CreateTabBtn(Icons.Settings, "settings", tabStartY + (tabBtnS + 6) * 7)
else
    CreateTabBtn("rbxassetid://108973165274475", "playlists", tabStartY + (tabBtnS + 6) * 5, 1.15)
    CreateTabBtn(Icons.Settings, "settings", tabStartY + (tabBtnS + 6) * 6)
end

local _indS = 3
local _tabIndicator = Instance.new("Frame")
_tabIndicator.Name = "TabIndicator"
_tabIndicator.Size = UDim2.new(0, _indS, 0, tabBtnS - 14)
_tabIndicator.Position = UDim2.new(0, 2, 0, tabStartY + 7)
_tabIndicator.BackgroundColor3 = currentTheme.accent
_tabIndicator.ZIndex = 13
_tabIndicator.Parent = sidebar
Instance.new("UICorner", _tabIndicator).CornerRadius = UDim.new(1, 0)
RegisterTheme(_tabIndicator, "BackgroundColor3", "accent")

local function _UpdateIndicatorGrad() end

-- ===============================================================
-- CONTENT
-- ===============================================================

content = Instance.new("Frame")
content.Size = UDim2.new(1, -sideBarW, 1, 0)
content.Position = UDim2.new(0, sideBarW, 0, 0)
content.BackgroundTransparency = 1
content.ZIndex = 2
content.ClipsDescendants = true
content.Parent = main

local titleH = isMobile and 44 or 54
titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, titleH)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 5
titleBar.Parent = content

local headerSurface = Instance.new("Frame")
headerSurface.Size = UDim2.new(1, -16, 1, -10)
headerSurface.Position = UDim2.new(0, 8, 0, 5)
headerSurface.BackgroundColor3 = currentTheme.secondary
headerSurface.BackgroundTransparency = 0.12
headerSurface.ZIndex = 4
headerSurface.Parent = titleBar
Instance.new("UICorner", headerSurface).CornerRadius = UDim.new(0, 12)
RegisterTheme(headerSurface, "BackgroundColor3", "secondary")

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = currentTheme.stroke
headerStroke.Thickness = 1
headerStroke.Transparency = 0.45
headerStroke.Parent = headerSurface
RegisterTheme(headerStroke, "Color", "stroke")

titleOverlay = headerSurface

local titleIconSz = isMobile and 24 or 27
local titleIcon = Instance.new("ImageLabel")
titleIcon.Size = UDim2.new(0, titleIconSz, 0, titleIconSz)
titleIcon.Position = UDim2.new(0, 18, 0.5, 0)
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = ResolveAssetImage(Icons.Emote)
titleIcon.ImageColor3 = currentTheme.accent
titleIcon.ZIndex = 6
titleIcon.Parent = titleBar
RegisterTheme(titleIcon, "ImageColor3", "accent")

title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -220, 0, 24)
title.Position = UDim2.new(0, 18 + titleIconSz + 9, 0, isMobile and 10 or 8)
title.BackgroundTransparency = 1
title.Text = L.emotes
title.TextColor3 = currentTheme.text
title.Font = Enum.Font.GothamBold
title.TextSize = isMobile and 15 or 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6
title.Parent = titleBar
RegisterTheme(title, "TextColor3", "text")

local titleSubtitle = Instance.new("TextLabel")
titleSubtitle.Size = UDim2.new(1, -220, 0, 16)
titleSubtitle.Position = UDim2.new(0, 18 + titleIconSz + 9, 0, isMobile and 27 or 29)
titleSubtitle.BackgroundTransparency = 1
titleSubtitle.Text = isES and "Biblioteca de animaciones" or "Animation library"
titleSubtitle.TextColor3 = currentTheme.textDim
titleSubtitle.Font = Enum.Font.Gotham
titleSubtitle.TextSize = isMobile and 9 or 10
titleSubtitle.TextXAlignment = Enum.TextXAlignment.Left
titleSubtitle.ZIndex = 6
titleSubtitle.Parent = titleBar
RegisterTheme(titleSubtitle, "TextColor3", "textDim")

local _textGrads = {}
local function _ApplyTextGrad(grad)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, currentTheme.text),
        ColorSequenceKeypoint.new(1, currentTheme.text)
    }
end
local function _AddTextGrad(textLabel)
    -- Kept as a compatibility hook for labels created later in the script.
    return nil
end
_updateTitleGrad = function() end

local btnS = isMobile and 28 or 30

local function MakeBtn(icon, px, colorKey, customSize)
	local s = customSize or btnS
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, s, 0, s)
	b.Position = UDim2.new(1, px, 0.5, -s/2)
	b.BackgroundColor3 = currentTheme.tertiary
	b.Text = ""
	b.ZIndex = 10
	b.Parent = titleBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
	
	local useWhite = (colorKey == "critical" or colorKey == "accent" or colorKey == "success")
	
	local isImg = type(icon) == "string" and (string.find(icon, "rbxassetid://") or string.find(icon, "http") or string.find(icon, "rbxthumb://"))
	if isImg then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0, math.floor(42 * ICON_SCALE), 0, math.floor(42 * ICON_SCALE))
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
			Position = UDim2.new(1, px - 2, 0.5, -(s + 4)/2)
		}):Play()
	end)
	b.MouseLeave:Connect(function()
		local s = customSize or btnS
		TweenService:Create(b, TweenInfo.new(0.1), {
			Size = UDim2.new(0, s, 0, s),
			Position = UDim2.new(1, px, 0.5, -s/2)
		}):Play()
	end)
	return b
end

local copyEmoteBtn = MakeBtn("rbxassetid://77508802666652", -(btnS*6 + 30), "critical")
local stopBtn = MakeBtn("STOP_SHAPE", -(btnS*5 + 24), "critical")
local randBtn = MakeBtn(Icons.Sort, -(btnS*4 + 18), "accent")
local notifBtn = MakeBtn("rbxassetid://102189770974908", -(btnS*3 + 12), "tertiary")
local minBtn = MakeBtn("-", -(btnS*2 + 6), "textDim")
local closeBtn = MakeBtn("CLOSE_SHAPE", -(btnS + 2), "critical")

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
RegisterTheme(minBtn, "BackgroundColor3", "stroke")
RegisterTheme(closeBtn, "BackgroundColor3", "critical")

local _isPaused = false
local _stopBtnSquare = stopBtn:FindFirstChildWhichIsA("ImageLabel")

local _pauseTextSize = math.floor((isMobile and 14 or 18) * (ICON_SCALE or 1))

local function _SetPauseState(paused)
	_isPaused = paused
	if _stopBtnSquare then
		_stopBtnSquare.Image = paused and ResolveAssetImage("rbxassetid://129338178452237") or ResolveAssetImage("rbxassetid://113416463749658")
	end
	if _onPauseStateChanged then _onPauseStateChanged(paused) end
end

stopBtn.MouseButton1Click:Connect(function()
	if currentAnimTrack and _isPaused then
		pcall(function() currentAnimTrack:AdjustSpeed(Settings.speed) end)
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
		Notify("[~] " .. L.playing .. speedTxt, r.name)
		PlayEmote(r.id, r.name, true)
	end
end)

local searchH = isMobile and 32 or 38
search = Instance.new("TextBox")
search.Size = UDim2.new(1, -24, 0, searchH)
search.Position = UDim2.new(0, 12, 0, titleH + 8)
search.BackgroundColor3 = currentTheme.tertiary
search.PlaceholderText = L.search
search.PlaceholderColor3 = currentTheme.textDim
search.Text = ""
search.TextColor3 = currentTheme.text
search.TextSize = isMobile and 13 or 15
search.Font = Enum.Font.Gotham
search.ZIndex = 5
search.ClearTextOnFocus = false
search.Parent = content
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 12)
Instance.new("UIPadding", search).PaddingLeft = UDim.new(0, 10)
RegisterTheme(search, "BackgroundColor3", "tertiary")
RegisterTheme(search, "TextColor3", "text")

-- Trending Dropdown UI
trendingDropdown = Instance.new("Frame")
trendingDropdown.Name = "VexroTrendingDropdown"
trendingDropdown.Size = UDim2.new(1, -16, 0, 0)
trendingDropdown.Position = UDim2.new(0, 8, 0, titleH + 6 + searchH + 2)
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

local _cachedTrending = {"TikTok", "Chill", "Korobeiniki", "Dance", "Catalog"}
local _lastRecordedQuery = ""
local _lastRecordedAt = 0

local function canShowTrendingDropdown()
	return currentTab ~= "settings"
		and currentTab ~= "friends"
		and currentTab ~= "keybinds"
		and currentTab ~= "favorites"
		and currentTab ~= "recent"
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
		icon.ImageColor3 = currentTheme.accent
		icon.ZIndex = 252
		icon.Parent = btn
		RegisterTheme(icon, "ImageColor3", "accent")

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

	-- Show cached/fallback immediately so throttle never blanks the dropdown
	populateTrendingDropdown(_cachedTrending)

	local res = ApiRequest("GET", "/emote/search/trending")
	local trendingItems = {}
	if res and res.ok and type(res.trending) == "table" then
		trendingItems = res.trending
	end
	if #trendingItems > 0 then
		populateTrendingDropdown(trendingItems)
	end
end

local function recordSearchQuery(raw)
	local q = string.match(tostring(raw or ""), "^%s*(.-)%s*$") or ""
	if q == "" or #q < 2 then return end
	if q == _lastRecordedQuery and (tick() - _lastRecordedAt) < 8 then return end
	_lastRecordedQuery = q
	_lastRecordedAt = tick()
	task.spawn(function()
		ApiRequest("POST", "/emote/search/record", {
			userId = tostring(player.UserId),
			token = getOrCreateToken(),
			query = q
		})
	end)
end

search.Focused:Connect(function()
	if not canShowTrendingDropdown() then return end
	if not search.Visible then return end
	trendingDropdown.Visible = true
	task.spawn(refreshTrendingDropdown)
end)

search.FocusLost:Connect(function(enterPressed)
	task.delay(0.18, function()
		if trendingDropdown and not search:IsFocused() then
			hideTrendingDropdown()
		end
	end)
end)

local pageH = isMobile and 30 or 36
pageBar = Instance.new("Frame")
pageBar.Size = UDim2.new(1, -24, 0, pageH)
pageBar.Position = UDim2.new(0, 12, 1, -(pageH + bottomBarH + 8))
pageBar.BackgroundColor3 = currentTheme.secondary
pageBar.BackgroundTransparency = 0.28
pageBar.ZIndex = 5
pageBar.Parent = content
Instance.new("UICorner", pageBar).CornerRadius = UDim.new(0, 10)
RegisterTheme(pageBar, "BackgroundColor3", "secondary")

local pageBtnW = isMobile and 45 or 60

prevBtn = Instance.new("TextButton")
prevBtn.Size = UDim2.new(0, pageBtnW, 1, -4)
prevBtn.Position = UDim2.new(0, 2, 0, 2)
prevBtn.BackgroundColor3 = currentTheme.accent
prevBtn.Text = ""
prevBtn.ZIndex = 6
prevBtn.Parent = pageBar
Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 8)
RegisterTheme(prevBtn, "BackgroundColor3", "accent")

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
nextBtn.Position = UDim2.new(1, -(pageBtnW + 2), 0, 2)
nextBtn.Parent = pageBar

CreateChevron(prevBtn, false)
CreateChevron(nextBtn, true)
RegisterTheme(nextBtn, "BackgroundColor3", "accent")

pageNum = Instance.new("TextLabel")
pageNum.Size = UDim2.new(1, -(pageBtnW*2 + 16), 1, 0)
pageNum.Position = UDim2.new(0, pageBtnW + 8, 0, 0)
pageNum.BackgroundTransparency = 1
pageNum.Text = "1/1"
pageNum.TextColor3 = currentTheme.textDim
pageNum.Font = Enum.Font.GothamBold
pageNum.TextScaled = true
pageNum.ZIndex = 6
pageNum.Parent = pageBar
RegisterTheme(pageNum, "TextColor3", "textDim")

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

-- ===============================================================
-- SETTINGS PANEL
-- ===============================================================

settingsPanel = Instance.new("ScrollingFrame")
settingsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
settingsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
settingsPanel.BackgroundTransparency = 1
settingsPanel.ScrollBarThickness = isMobile and 6 or 4
settingsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
settingsPanel.Visible = false
settingsPanel.ZIndex = 5
settingsPanel.Parent = content

settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0, 6)
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Parent = settingsPanel

friendsPanel = Instance.new("ScrollingFrame")
friendsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
friendsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
friendsPanel.BackgroundTransparency = 1
friendsPanel.ScrollBarThickness = isMobile and 6 or 4
friendsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y

playlistsPanel = Instance.new("ScrollingFrame")
playlistsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
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
keybindsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
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

-- ---------------------------------------------------------------
-- Yardımcı: bölüm başlığı
-- ---------------------------------------------------------------
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

-- ---------------------------------------------------------------
-- Yardımcı: ayar satırı (ikon + başlık + opsiyonel açıklama)
-- ---------------------------------------------------------------
MakeRow = function(imgId, title, subtitle, order, customH)
	local iconBoxSz = isMobile and 46 or 54
	local hasDesc = subtitle and subtitle ~= ""
	local h = customH or (hasDesc and 72 or 60)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, h)
	row.BackgroundColor3 = currentTheme.secondary
	row.LayoutOrder = order
	row.ZIndex = 6
	row.Parent = settingsPanel
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 11)
	RegisterTheme(row, "BackgroundColor3", "secondary")
	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = currentTheme.stroke
	rowStroke.Thickness = 1
	rowStroke.Transparency = 0.55
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
		icon.ImageColor3 = currentTheme.accent
		icon.ZIndex = 8
		icon.Parent = iconBox
		RegisterTheme(icon, "ImageColor3", "accent")
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

-- ---------------------------------------------------------------
-- Yardımcı: pill toggle anahtarı
-- ---------------------------------------------------------------
MakePillToggle = function(parent, value, onChange)
	local pillW, pillH, pad = 50, 28, 3
	local knobSz = pillH - pad * 2

	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(0, pillW, 0, pillH)
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -12, 0.5, 0)
	pill.BackgroundColor3 = value and currentTheme.success or currentTheme.stroke
	pill.ZIndex = 8
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, knobSz, 0, knobSz)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = value
		and UDim2.new(1, -(knobSz + pad), 0.5, 0)
		or  UDim2.new(0, pad, 0.5, 0)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.ZIndex = 9
	knob.Parent = pill
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = value
	local pillBtn = Instance.new("TextButton")
	pillBtn.Size = UDim2.fromScale(1, 1)
	pillBtn.BackgroundTransparency = 1
	pillBtn.Text = ""
	pillBtn.ZIndex = 10
	pillBtn.Parent = pill

	local function SetState(v)
		state = v
		TweenService:Create(pill, TweenInfo.new(0.22), {
			BackgroundColor3 = v and currentTheme.success or currentTheme.stroke
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
			Position = v and UDim2.new(1, -(knobSz + pad), 0.5, 0) or UDim2.new(0, pad, 0.5, 0)
		}):Play()
	end

	pillBtn.MouseButton1Click:Connect(function()
		state = not state
		SetState(state)
		onChange(state)
	end)

	return SetState
end

-- ===============================================================
-- GÖRÜNÜM
-- ===============================================================
MakeSectionHeader(isES and "Apariencia" or "Appearance", 1)

do
	local themeRow = MakeRow("110192525313214", L.theme, "", 2)
	local themeNames = {"Dark", "Purple", "Blue", "Green", "Red", "Light", "MaterialYou", "FrostedGlass", "DarkGlass"}

	local chip = Instance.new("TextButton")
	chip.Size = UDim2.new(0, 80, 0, 30)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -12, 0.5, 0)
	chip.BackgroundColor3 = currentTheme.accent
	chip.Text = Settings.theme
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = isMobile and 10 or 11
	chip.ZIndex = 8
	chip.Parent = themeRow
	Instance.new("UICorner", chip).CornerRadius = UDim.new(1, 0)
	RegisterTheme(chip, "BackgroundColor3", "accent")

	local themeIdx = 1
	for i, n in ipairs(themeNames) do if n == Settings.theme then themeIdx = i end end

	chip.MouseButton1Click:Connect(function()
		themeIdx = themeIdx % #themeNames + 1
		Settings.theme = themeNames[themeIdx]
		chip.Text = Settings.theme
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

-- ===============================================================
-- DAVRANIŞ
-- ===============================================================
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
		_genv().autoReloadEnabled_Vexro = v
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

do
	local row = MakeRow("", L.showHUD, L.showHUDDesc, 13)
	MakePillToggle(row, Settings.showHUD, function(v)
		Settings.showHUD = v
		if not v then HideEmoteHUD() end
		SaveData()
	end)
end

-- ===============================================================
-- GENEL
-- ===============================================================
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
		Notify("Vexro", isES and "Idioma restablecido. Ejecuta el script otra vez para elegir." or "Language reset. Run the script again to choose.")
	end)
end

do
	MakeSectionHeader(isES and "Acerca de & Notas de actualización" or "About & Update Notes", 10)
	local verRow = MakeRow("110192525313214", "V5.0 - VEXRO CLOUD", isES and "Versión más reciente de VEXRO Cloud" or "Latest VEXRO Cloud version", 11, 135)
	
	local verLbl = Instance.new("TextLabel")
	verLbl.Size = UDim2.new(1, -24, 0, 80)
	verLbl.Position = UDim2.new(0, 12, 0, 48)
	verLbl.BackgroundTransparency = 1
	verLbl.Text = isES and "• Carga asíncrona de emotes\n• Ajuste dinámico de paquetes de animación\n• Correcciones de recorte y ventanas\n• Mejoras visuales de tarjetas\n• Integración con Vexro Cloud"
		or "• Async emote loading\n• Dynamic animation pack slot matching\n• Window clipping fixes\n• Card visual improvements\n• Vexro Cloud integration"
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



local PROMPT_TAG = "VexroCopyEmotePrompt"

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

-- ===============================================================
-- ===============================================================
-- ===============================================================
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
    -- Loaded dynamically from server
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
	brand.BackgroundTransparency = 1; brand.Text = FriendL.brandTitle
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
		local res = ApiRequest("POST", "/friends/request/accept", {
			userId = tostring(player.UserId),
			token = getOrCreateToken(),
			targetId = tostring(senderUserId)
		})
		if res and res.status == "success" then
			FriendData.friends[tostring(senderUserId)] = {name = senderName, syncEnabled = true}
			RefreshFriendList()
			Notify(L.friendReqAcceptedYou:format(tostring(senderName)), "", nil)
		end
		_close()
	end)

	if FriendData.autoReject then
		_MyAttr(ATTR_RESP, tostring(senderUserId) .. ":0")
		task.delay(0.5, function() _MyAttr(ATTR_RESP, "") end)
		_close()
	end
end

-- Network-based Watch / Polling loops replacing character attributes
local function _WatchChar(char, uid, uname)
    -- Stubbed: Handled by server sync status polling loop
end

-- NOTIFICATION PANEL
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
npScroll.ScrollBarThickness = 4
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
			btnYes.Text = "..."
			task.spawn(function()
				ApiRequest("POST", "/friends/request/accept", { userId = tostring(player.UserId), targetId = tostring(r.userId), token = getOrCreateToken() })
				card:Destroy()
			end)
		end)
		btnNo.MouseButton1Click:Connect(function()
			card:Destroy()
		end)
	end
	
	-- Render Sync Requests
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
		msg.Text = isES and (s.senderName .. " quiere reproducir " .. s.emoteName .. " contigo") or (s.senderName .. " wants to play " .. s.emoteName .. " with you")
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
			btnPlay.Text = "..."
			task.spawn(function()
				ApiRequest("POST", "/emote/sync/status", { userId = tostring(player.UserId), token = getOrCreateToken(), syncId = s.syncId, status = "accepted" })
				FriendData.currentSyncPartner = s.initiatorId
				PlayEmote(s.emoteId, s.emoteName, true, s.syncStartTime)
				card:Destroy()
			end)
		end)
		btnNo.MouseButton1Click:Connect(function()
			task.spawn(function()
				ApiRequest("POST", "/emote/sync/status", { userId = tostring(player.UserId), token = getOrCreateToken(), syncId = s.syncId, status = "rejected" })
				card:Destroy()
			end)
		end)
	end
	
	npScroll.CanvasSize = UDim2.new(0, 0, 0, npLayout.AbsoluteContentSize.Y + 10)
end
end


-- Active loop for server polling (Friends list, Sync status, Incoming Sync Requests, Heartbeats)
task.spawn(function()
    while task.wait(3) do
        if _genv().VexroSessionToken ~= mySessionToken then break end
        pcall(function()
            -- 1. Heartbeat
            local activeEmote = nil
            if currentAnimTrack and currentAnimTrack.IsPlaying then
                activeEmote = _genv().lastVexroEmote
            end
            ApiRequest("POST", "/session/heartbeat", {
                userId = tostring(player.UserId),
                token = getOrCreateToken(),
                jobId = game.JobId ~= "" and game.JobId or "Studio_" .. tostring(game.PlaceId),
                activeEmote = activeEmote,
                syncPartner = FriendData.currentSyncPartner
            })

            -- 2. Fetch friends and incoming requests
            local res = ApiRequest("GET", "/friends/list?userId=" .. tostring(player.UserId) .. "&token=" .. getOrCreateToken())
            if res and res.status == "success" then
                -- Rebuild FriendData.friends
                local newFriends = {}
                for _, f in ipairs(res.friends) do
                    newFriends[tostring(f.userId)] = {
                        name = f.username,
                        syncEnabled = true,
                        online = f.online
                    }
                end
                FriendData.friends = newFriends
                FriendData.isLoaded = true
                RefreshFriendList()

                -- Handle incoming requests
                if res.incomingRequests then
                    FriendData.incomingRequests = res.incomingRequests
                    RenderNotifications()
                end
            end

        end)
    end
end)

-- 2.5-second interval for fast sync polling & active sync heartbeat
task.spawn(function()
    while task.wait(2.5) do
        if _genv().VexroSessionToken ~= mySessionToken then break end
        pcall(function()
            -- Poll incoming Sync requests instantly
            if FriendData.syncEmote then
                local syncRes = ApiRequest("POST", "/emote/sync/status", {
                    userId = tostring(player.UserId),
                    token = getOrCreateToken(),
                    action = "poll_incoming"
                })
                if syncRes and syncRes.status == "success" and syncRes.incomingRequests then
                    FriendData.incomingSyncs = {}
                    for _, sreq in ipairs(syncRes.incomingRequests) do
                        if FriendData.playFriendEmote then
                            -- Auto-accept sync
                            ApiRequest("POST", "/emote/sync/status", {
                                userId = tostring(player.UserId),
                                token = getOrCreateToken(),
                                syncId = sreq.syncId,
                                status = "accepted"
                            })
                            FriendData.currentSyncPartner = sreq.initiatorId
                            local reqAnimId = tonumber(sreq.emoteId)
                            if not (_genv().lastVexroEmote and _genv().lastVexroEmote.id == reqAnimId) then
                                PlayEmote(reqAnimId, sreq.emoteName, true, sreq.syncStartTime)
                            end
                        else
                            table.insert(FriendData.incomingSyncs, sreq)
                        end
                    end
                    RenderNotifications()
                end
            end

            -- Sync partner heartbeat
            if FriendData.currentSyncPartner and currentAnimTrack and currentAnimTrack.IsPlaying then
                local hbRes = ApiRequest("POST", "/session/heartbeat", {
                    userId = tostring(player.UserId),
                    token = getOrCreateToken(),
                    jobId = game.JobId ~= "" and game.JobId or "Studio_" .. tostring(game.PlaceId),
                    activeEmote = _genv().lastVexroEmote,
                    syncPartner = FriendData.currentSyncPartner
                })
                
                if hbRes and hbRes.syncCancelled then
                    FriendData.currentSyncPartner = nil
                    StopAllTracks()
                    Notify(L.stopped, "Partner stopped the emote", 113416463749658)
                    if _genv().VexroBroadcastStop then pcall(_genv().VexroBroadcastStop) end
                end
            end
        end)
    end
end)

local function _WatchAll()
    -- Handled in our main polling task above
end

-- Add friend mode removed



_genv().VexroBroadcastStop = function()
	_MyAttr(ATTR_STOP, tostring(tick()))
	FriendData.currentSyncPartner = nil
	pcall(function()
		ApiRequest("POST", "/emote/sync/status", {
			userId = tostring(player.UserId),
			token = getOrCreateToken(),
			action = "cancel_all"
		})
	end)
end

_genv().VexroBroadcastSync = function(emoteId, emoteName, syncStartTime)
	if not FriendData or not FriendData.friends then return end
	task.spawn(function()
		ApiRequest("POST", "/emote/sync/broadcast", {
			userId = tostring(player.UserId),
			emoteId = tostring(emoteId),
			emoteName = tostring(emoteName),
			jobId = game.JobId ~= "" and game.JobId or "Studio_" .. tostring(game.PlaceId),
			syncStartTime = syncStartTime and tostring(syncStartTime) or tostring(workspace:GetServerTimeNow()),
			token = getOrCreateToken()
		})
	end)
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

	local tb = Instance.new("TextButton")
	tb.Size = UDim2.new(0.38,0,0,30); tb.Position = UDim2.new(0.58,0,0.5,-15)
	tb.BackgroundColor3 = getVal() and currentTheme.success or currentTheme.critical
	tb.Text = getVal() and L.on or L.off
	tb.TextColor3 = Color3.new(1,1,1); tb.Font = Enum.Font.GothamBold
	tb.TextSize = isMobile and 11 or 12; tb.ZIndex = 8; tb.Parent = row
	Instance.new("UICorner", tb).CornerRadius = UDim.new(0,10)

	tb.MouseButton1Click:Connect(function()
		local v = not getVal(); setVal(v)
		tb.Text = v and L.on or L.off
		TweenService:Create(tb, TweenInfo.new(0.2), {
			BackgroundColor3 = v and currentTheme.success or currentTheme.critical
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
serverPlayersBtn.Size = UDim2.new(1, 0, 0, 38)
serverPlayersBtn.BackgroundColor3 = currentTheme.stroke
serverPlayersBtn.Text = L.serverPlayersDown
serverPlayersBtn.TextColor3 = Color3.new(1, 1, 1)
serverPlayersBtn.Font = Enum.Font.GothamBold
serverPlayersBtn.TextSize = isMobile and 11 or 12
serverPlayersBtn.LayoutOrder = 0
serverPlayersBtn.ZIndex = 6
serverPlayersBtn.Parent = friendsPanel
Instance.new("UICorner", serverPlayersBtn).CornerRadius = UDim.new(0, 10)
RegisterTheme(serverPlayersBtn, "BackgroundColor3", "accent")

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
				addBtn.Text = "..."
				task.spawn(function()
					local res = ApiRequest("POST", "/friends/request/send", {
						userId = tostring(player.UserId),
						targetId = tostring(pdata.userId),
						token = getOrCreateToken()
					})
					if res and res.status == "success" then
						addBtn.Text = "OK"
						addBtn.BackgroundColor3 = currentTheme.success
					else
						addBtn.Text = "Err"
						if res and res.error then
							Notify(SafeUtf8Char(0x274C), res.error)
						end
					end
				end)
			end)
		end
	end
	emptySpLbl.Visible = not hasAny
end

serverPlayersBtn.MouseButton1Click:Connect(function()
	serverPlayersContainer.Visible = not serverPlayersContainer.Visible
	if serverPlayersContainer.Visible then
		serverPlayersBtn.Text = L.serverPlayersUp
	else
		serverPlayersBtn.Text = L.serverPlayersDown
	end
end)

task.spawn(function()
	while task.wait(10) do
		if _genv().VexroSessionToken ~= mySessionToken then break end
		if not gui or not gui.Parent then break end
		if serverPlayersContainer.Visible then
			local res = ApiRequest("GET", "/friends/players-in-server?jobId=" .. (game.JobId ~= "" and game.JobId or "Studio_" .. tostring(game.PlaceId)) .. "&userId=" .. tostring(player.UserId) .. "&token=" .. getOrCreateToken())
			if res and res.status == "success" and res.players then
				-- compare array 
				local changed = false
				if #res.players ~= #serverPlayersData then
					changed = true
				else
					for i, p in ipairs(res.players) do
						if serverPlayersData[i].userId ~= p.userId then changed = true; break end
					end
				end
				if changed then
					serverPlayersData = res.players
					RefreshServerPlayersList()
				end
			end
		end
	end
end)
end



do
infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 52)
infoBox.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
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
infoBoxLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
infoBoxLbl.Font = Enum.Font.Gotham
infoBoxLbl.TextSize = 10
infoBoxLbl.TextWrapped = true
infoBoxLbl.TextXAlignment = Enum.TextXAlignment.Left
infoBoxLbl.TextYAlignment = Enum.TextYAlignment.Center
infoBoxLbl.ZIndex = 6
infoBoxLbl.Parent = infoBox
local infoIcon = Instance.new("TextLabel")
infoIcon.Size = UDim2.new(0, 24, 0, 24)
infoIcon.Position = UDim2.new(0, 6, 0.5, -12)
infoIcon.BackgroundTransparency = 1
infoIcon.Text = "ℹ"
infoIcon.TextColor3 = Color3.fromRGB(150, 190, 255)
infoIcon.Font = Enum.Font.GothamBold
infoIcon.TextSize = 14
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
		local stxt = fdata.online and "Aktif" or "Pasif"
		if not isTR then stxt = fdata.online and "Active" or "Inactive" end
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
		syncBtn.Visible = (fdata.online == true)
		syncBtn.Size = UDim2.new(0,46,0,24); syncBtn.Position = UDim2.new(1,-84,0.5,-12)
		syncBtn.BackgroundColor3 = fdata.syncEnabled and currentTheme.success or currentTheme.critical
		syncBtn.Text = fdata.syncEnabled and FriendL.syncOn or FriendL.syncOff
		syncBtn.TextColor3 = Color3.new(1,1,1); syncBtn.Font = Enum.Font.GothamBold
		syncBtn.TextSize = 10; syncBtn.ZIndex = 7; syncBtn.Parent = row
		Instance.new("UICorner", syncBtn).CornerRadius = UDim.new(0,8)

		syncBtn.MouseButton1Click:Connect(function()
			fdata.syncEnabled = not fdata.syncEnabled
			syncBtn.Text = fdata.syncEnabled and FriendL.syncOn or FriendL.syncOff
			TweenService:Create(syncBtn, TweenInfo.new(0.2), {
				BackgroundColor3 = fdata.syncEnabled and currentTheme.success or currentTheme.critical
			}):Play()
			_SaveFriend()
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
	
	if not FriendData.isLoaded then
		emptyFriendLbl.Text = isES and "Cargando..." or "Loading..."
		emptyFriendLbl.Visible = true
		flHeader.Visible = false
	else
		emptyFriendLbl.Text = L.noFriends
		emptyFriendLbl.Visible = not hasAny
		flHeader.Visible = hasAny
	end
end
RefreshFriendList()



local _prevClean = _genv().VexroEmotesCleanup
_genv().VexroEmotesCleanup = function()
	-- Graceful logout (Wait for server confirmation before closing)
	pcall(function()
		ApiRequest("POST", "/session/logout", {
			userId = tostring(player.UserId),
			token = getOrCreateToken()
		})
	end)
	if _prevClean then pcall(_prevClean) end
	for _, c in ipairs(_friendConns) do pcall(function() c:Disconnect() end) end
	_friendConns = {}
	_SetAddMode(false)
	pcall(function() _genv().VexroBroadcastSync = nil end)
	pcall(function() _genv().VexroBroadcastStop = nil end)
end

-- ===============================================================

bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(1, 0, 0, bottomBarH)
bottomBar.Position = UDim2.new(0, 0, 1, -bottomBarH)
bottomBar.BackgroundColor3 = currentTheme.tertiary
bottomBar.ZIndex = 15
bottomBar.Parent = content
Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 14)
RegisterTheme(bottomBar, "BackgroundColor3", "tertiary")

bottomOverlay = Instance.new("Frame")
bottomOverlay.Size = UDim2.new(1, 0, 0, 8)
bottomOverlay.BackgroundColor3 = currentTheme.tertiary
bottomOverlay.BorderSizePixel = 0
bottomOverlay.ZIndex = 14
bottomOverlay.Parent = bottomBar
RegisterTheme(bottomOverlay, "BackgroundColor3", "tertiary")

grip = Instance.new("Frame")
grip.Size = UDim2.new(0, 40, 0, 4)
grip.Position = UDim2.new(0.5, -20, 0.5, -2)
grip.BackgroundColor3 = currentTheme.textDim
grip.ZIndex = 16
grip.Parent = bottomBar
Instance.new("UICorner", grip).CornerRadius = UDim.new(1, 0)
RegisterTheme(grip, "BackgroundColor3", "textDim")

local scrollY = titleH + searchH + 14
scroll = Instance.new("ScrollingFrame")
scroll.ClipsDescendants = true
scroll.Size = UDim2.new(1, -16, 1, -(scrollY + pageH + bottomBarH + 18))
scroll.Position = UDim2.new(0, 8, 0, scrollY)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = isMobile and 3 or 5
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarImageColor3 = currentTheme.stroke
scroll.ZIndex = 1
scroll.Parent = content
RegisterTheme(scroll, "ScrollBarImageColor3", "stroke")

-- ===============================================================
-- CARD SYSTEM (RESPONSIVE GRID)
-- ===============================================================

local function CalcLayout()
	local PAD = isMobile and 4 or 6
	local w = scroll.AbsoluteSize.X
	
	local minCardSize = isMobile and TARGET_MOBILE_CARD or TARGET_PC_CARD
	
	cols = math.floor(w / (minCardSize + PAD))
	if cols < 1 then cols = 1 end
	
	currentCardSize = (w - (PAD * (cols - 1))) / cols
	
	local NAME_H = math.clamp(currentCardSize * 0.35, 18, 28)
	local FAV_H = math.clamp(currentCardSize * 0.3, 18, 24)
	local CARD_TOTAL_H = currentCardSize + NAME_H + FAV_H
	
	local rowsVisible = math.floor(scroll.AbsoluteSize.Y / (CARD_TOTAL_H + PAD))
	if rowsVisible < 1 then rowsVisible = 1 end
	
	perPage = cols * rowsVisible
	
	pages = math.max(1, math.ceil(#filtered / perPage))
	page = math.clamp(page, 1, pages)
end

local function UpdatePageUI()
	pageNum.Text = page .. "/" .. pages
	local show = pages > 1
	prevBtn.Visible = show
	nextBtn.Visible = show
	
	if prevBtn:FindFirstChild("ChevronIcon") then 
		for _, c in ipairs(prevBtn.ChevronIcon:GetChildren()) do c.BackgroundColor3 = Color3.new(0, 0, 0) end
	end
	if nextBtn:FindFirstChild("ChevronIcon") then 
		for _, c in ipairs(nextBtn.ChevronIcon:GetChildren()) do c.BackgroundColor3 = Color3.new(0, 0, 0) end
	end
	
	pageBar.Visible = scroll.Visible and pages > 1
	
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

-- ===============================================================
-- KEYBIND DIALOG
-- ===============================================================

local function ShowKeybindDialog(emoteId, emote, isEdit)
	local existing = main:FindFirstChild("VexroKeybindOverlay")
	if existing then existing:Destroy() end

	local overlay = Instance.new("TextButton")
	overlay.Name = "VexroKeybindOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.ZIndex = 200
	overlay.Parent = main
	overlay.MouseButton1Click:Connect(function() end)

	local dialog = Instance.new("Frame")
	dialog.Size = UDim2.new(0.85, 0, 0, 260)
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
	titleLbl.Text = isEdit and L.editKeybind or L.newKeybind
	titleLbl.TextColor3 = currentTheme.text
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.ZIndex = 202
	titleLbl.Parent = dialog

	local nameLblTitle = Instance.new("TextLabel")
	nameLblTitle.Size = UDim2.new(0, 60, 0, 24)
	nameLblTitle.Position = UDim2.new(0, 12, 0, 52)
	nameLblTitle.BackgroundTransparency = 1
	nameLblTitle.Text = L.kbName
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
	nameBox.PlaceholderText = emote.name
	nameBox.Text = isEdit and (GetKeybind(emoteId) and GetKeybind(emoteId).name or "") or ""
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

	local atamaLbl = Instance.new("TextLabel")
	atamaLbl.Size = UDim2.new(0, 80, 0, 24)
	atamaLbl.Position = UDim2.new(0, 12, 0, 122)
	atamaLbl.BackgroundTransparency = 1
	atamaLbl.Text = L.kbAssign
	atamaLbl.TextColor3 = currentTheme.textDim
	atamaLbl.Font = Enum.Font.GothamBold
	atamaLbl.TextSize = 13
	atamaLbl.TextXAlignment = Enum.TextXAlignment.Left
	atamaLbl.ZIndex = 202
	atamaLbl.Parent = dialog

	local recordedKey = isEdit and (GetKeybind(emoteId) and GetKeybind(emoteId).key or nil) or nil
	local isRecording = false
	local recordConn

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(1, -24, 0, 36)
	keyBtn.Position = UDim2.new(0, 12, 0, 148)
	keyBtn.BackgroundColor3 = currentTheme.tertiary
	keyBtn.Text = recordedKey and ("[" .. recordedKey .. "]") or L.kbRecording
	keyBtn.TextColor3 = recordedKey and currentTheme.accent or currentTheme.textDim
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 13
	keyBtn.ZIndex = 202
	keyBtn.Parent = dialog
	Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 8)
	local kbStroke = Instance.new("UIStroke")
	kbStroke.Color = currentTheme.stroke
	kbStroke.Thickness = 1.5
	kbStroke.Parent = keyBtn

	keyBtn.MouseButton1Click:Connect(function()
		if isRecording then return end
		isRecording = true
		keyBtn.Text = "..."
		kbStroke.Color = currentTheme.accent
		TweenService:Create(kbStroke, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7}):Play()
		local UIS2 = game:GetService("UserInputService")
		recordConn = UIS2.InputBegan:Connect(function(inp, gp)
			if gp then return end
			if inp.UserInputType == Enum.UserInputType.Keyboard then
				recordedKey = inp.KeyCode.Name
				isRecording = false
				recordConn:Disconnect()
				keyBtn.Text = "[" .. recordedKey .. "]"
				keyBtn.TextColor3 = currentTheme.accent
				kbStroke.Color = currentTheme.stroke
				TweenService:Create(kbStroke, TweenInfo.new(0.1), {Transparency = 0}):Play()
			end
		end)
	end)

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0.45, -6, 0, 38)
	cancelBtn.Position = UDim2.new(0, 12, 0, 208)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	cancelBtn.Text = L.kbCancel
	cancelBtn.TextColor3 = Color3.new(1, 1, 1)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextSize = 14
	cancelBtn.ZIndex = 202
	cancelBtn.Parent = dialog
	Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0.55, -18, 0, 38)
	saveBtn.Position = UDim2.new(0.45, 6, 0, 208)
	saveBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	saveBtn.Text = L.kbSave
	saveBtn.TextColor3 = Color3.new(1, 1, 1)
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 14
	saveBtn.ZIndex = 202
	saveBtn.Parent = dialog
	Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)

	cancelBtn.MouseButton1Click:Connect(function()
		if recordConn then pcall(function() recordConn:Disconnect() end) end
		overlay:Destroy()
	end)

	local _KB_BLACKLIST = {Unknown=true, Backspace=true, Delete=true, Escape=true,
		Return=true, Tab=true, CapsLock=true, LeftShift=true, RightShift=true,
		LeftControl=true, RightControl=true, LeftAlt=true, RightAlt=true,
		LeftMeta=true, RightMeta=true, Insert=true, Home=true, End=true,
		PageUp=true, PageDown=true, NumLock=true, ScrollLock=true, Pause=true, Print=true}

	saveBtn.MouseButton1Click:Connect(function()
		if not recordedKey then return end
		if _KB_BLACKLIST[recordedKey] then
			keyBtn.Text = L.kbInvalidKey or "Invalid key!"
			keyBtn.TextColor3 = Color3.fromRGB(220, 50, 50)
			task.delay(1.5, function()
				if recordedKey then
					keyBtn.Text = "[" .. recordedKey .. "]"
					keyBtn.TextColor3 = currentTheme.accent
				end
			end)
			return
		end
		if recordConn then pcall(function() recordConn:Disconnect() end) end
		local kbName = nameBox.Text ~= "" and nameBox.Text or emote.name
		SetKeybind(emoteId, kbName, recordedKey)
		overlay:Destroy()
		Refresh(false)
		if currentTab == "keybinds" and RefreshKeybindsPanel then RefreshKeybindsPanel() end
	end)

	dialog.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(dialog, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.new(0.85, 0, 0, 260)}):Play()
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
		local emoteName = emote and emote.name or ("Emote #"..emoteId)
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
		delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
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

-- ===============================================================
-- CARD SYSTEM
-- ===============================================================

local function MakeCard(emote, ci, animate)
	local CARD = currentCardSize
	local PAD = isMobile and 4 or 6

	local NAME_H = math.clamp(CARD * 0.35, 18, 28)
	local FAV_H = math.clamp(CARD * 0.3, 18, 24)
	local KB_H = ((not isMobile) or _isPlaylistMode) and math.clamp(CARD * 0.45, 30, 40) or 0
	local CARD_TOTAL_H = KB_H + CARD + NAME_H + FAV_H

	local cardContainer = Instance.new("Frame")
	cardContainer.Size = UDim2.new(0, CARD, 0, CARD_TOTAL_H)
	cardContainer.BackgroundTransparency = 1
	cardContainer.ZIndex = 2
	cardContainer.Parent = scroll
	
	local col = ci % cols
	local row = math.floor(ci / cols)
	
	local targetX = col * (CARD + PAD)
	local targetY = PAD + row * (CARD_TOTAL_H + PAD)
	
	if animate then
		cardContainer.Position = UDim2.new(0, targetX, 0, targetY + 30)
		cardContainer.BackgroundTransparency = 1
		
		task.delay(ci * 0.02, function()
			if cardContainer.Parent then
				TweenService:Create(cardContainer, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
					Position = UDim2.new(0, targetX, 0, targetY)
				}):Play()
			end
		end)
	else
		cardContainer.Position = UDim2.new(0, targetX, 0, targetY)
	end
	
	local card = Instance.new("ImageButton")
	card.Size = UDim2.new(1, 0, 0, CARD)
	card.Position = UDim2.new(0, 0, 0, KB_H)
	card.BackgroundColor3 = currentTheme.tertiary
	card.ScaleType = Enum.ScaleType.Fit
	card.ZIndex = 3
	card.Parent = cardContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	
	if emote.isAnimationPack then
		local packId = tostring(emote.id):gsub("anim_", "")
		card.Image = "rbxthumb://type=BundleThumbnail&id=" .. packId .. "&w=420&h=420"
	else
		card.Image = "rbxthumb://type=Asset&id=" .. emote.id .. "&w=420&h=420"
	end
	card.BackgroundColor3 = currentTheme.tertiary

	if not emote.isAnimationPack then
		task.spawn(function()
			local _done = false
			local function _onResult(_, status)
				if _done then return end
				_done = true
				if status == Enum.AssetFetchStatus.Failure then
					task.defer(function()
						if cardContainer and cardContainer.Parent then cardContainer:Destroy() end
						_MarkBadEmote(emote.id)
					end)
				end
			end
			task.delay(15, function() _onResult(nil, Enum.AssetFetchStatus.Failure) end)
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({card}, _onResult)
			end)
		end)
	end
	
	if animate then
		card.ImageTransparency = 1
		task.delay(ci * 0.02, function()
			if card.Parent then
				TweenService:Create(card, TweenInfo.new(0.25), {ImageTransparency = 0}):Play()
			end
		end)
	end
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = currentTheme.accent
	stroke.Thickness = 2
	stroke.Transparency = 0.6
	stroke.Parent = card
	
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -4, 0, NAME_H - 2) 
	nameLbl.Position = UDim2.new(0, 2, 0, KB_H + CARD)
	nameLbl.BackgroundColor3 = currentTheme.secondary
	nameLbl.BackgroundTransparency = 0.28
	nameLbl.Text = #emote.name > 20 and emote.name:sub(1, 19) .. "…" or emote.name
	nameLbl.TextColor3 = currentTheme.text
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextScaled = true
	nameLbl.TextWrapped = true 
	nameLbl.Active = true 
	nameLbl.ZIndex = 3
	nameLbl.Parent = cardContainer
	Instance.new("UICorner", nameLbl).CornerRadius = UDim.new(0, 8)
	_AddTextGrad(nameLbl)

	nameLbl.MouseEnter:Connect(function()
		TweenService:Create(nameLbl, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, 4, 0, NAME_H + 4),
			Rotation = 0
		}):Play()
	end)
	
	nameLbl.MouseLeave:Connect(function()
		TweenService:Create(nameLbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(1, -4, 0, NAME_H - 2),
			Rotation = 0
		}):Play()
	end)
	
	
	local isFav = IsFavorite(emote.id)
	local favBtn = Instance.new("TextButton")
	favBtn.Size = UDim2.new(1, 0, 0, FAV_H)
	favBtn.Position = UDim2.new(0, 0, 0, KB_H + CARD + NAME_H)
	favBtn.BackgroundColor3 = currentTheme.tertiary
	favBtn.BackgroundTransparency = 0.25
	favBtn.Text = ""
	favBtn.ZIndex = 4
	favBtn.Parent = cardContainer
	Instance.new("UICorner", favBtn).CornerRadius = UDim.new(0, 8)

	local favIcon = Instance.new("TextLabel")
	local iconSize = isMobile and 28 or 34
	favIcon.Size = UDim2.new(0, iconSize, 0, iconSize)
	favIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	favIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	favIcon.BackgroundTransparency = 1
	favIcon.Text = isFav and SafeUtf8Char(0x2605) or SafeUtf8Char(0x2606)
	favIcon.TextColor3 = isFav and Color3.fromRGB(255, 215, 0) or currentTheme.accent
	favIcon.Font = Enum.Font.SourceSansLight
	favIcon.TextSize = isMobile and 26 or 32
	favIcon.TextScaled = false
	favIcon.ZIndex = 50
	favIcon.Parent = favBtn
	
	favBtn.MouseEnter:Connect(function()
		TweenService:Create(favBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
			BackgroundColor3 = isFav and currentTheme.tertiary or currentTheme.accent,
			Size = UDim2.new(1, 6, 0, FAV_H + 6),
			Rotation = 0
		}):Play()
	end)
	favBtn.MouseLeave:Connect(function()
		TweenService:Create(favBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			BackgroundColor3 = isFav and currentTheme.tertiary or currentTheme.stroke,
			Size = UDim2.new(1, 0, 0, FAV_H),
			Rotation = 0
		}):Play()
	end)
	
	favBtn.MouseButton1Click:Connect(function()
		isFav = ToggleFavorite(emote.id)
		
		if isFav then
			favIcon.Text = SafeUtf8Char(0x2605)
			favIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
		else
			favIcon.Text = SafeUtf8Char(0x2606)
			favIcon.TextColor3 = currentTheme.accent
		end
		
		TweenService:Create(favBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = isFav and currentTheme.tertiary or currentTheme.stroke
		}):Play()
		
		if isFav then
			favIcon.Size = UDim2.new(0, 0, 0, 0)
			TweenService:Create(favIcon, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, iconSize + 6, 0, iconSize + 6)
			}):Play()
			task.delay(0.2, function()
				TweenService:Create(favIcon, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {
					Size = UDim2.new(0, iconSize, 0, iconSize)
				}):Play()
			end)
			
			local ripple = Instance.new("Frame")
			ripple.Size = UDim2.new(0, 0, 0, 0)
			ripple.Position = UDim2.fromScale(0.5, 0.5)
			ripple.AnchorPoint = Vector2.new(0.5, 0.5)
			ripple.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			ripple.BackgroundTransparency = 0.3
			ripple.ZIndex = 4
			ripple.Parent = favBtn
			Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)
			
			TweenService:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(2, 0, 2, 0),
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.4, function() if ripple then ripple:Destroy() end end)
		else
			TweenService:Create(favIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, iconSize - 4, 0, iconSize - 4)
			}):Play()
			task.delay(0.2, function()
				TweenService:Create(favIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, iconSize, 0, iconSize)
				}):Play()
			end)
		end
		
		if currentTab == "favorites" then
			task.delay(0.4, function()
				if currentTab == "favorites" then UpdateTabData() end
			end)
		end
	end)

	local kbHasBinding = GetKeybind(emote.id) ~= nil
	if (not isMobile) or _isPlaylistMode then
		local kbBtn = Instance.new("TextButton")
		kbBtn.Size = UDim2.new(1, 0, 0, KB_H)
		kbBtn.Position = UDim2.new(0, 0, 0, 0)
		kbBtn.BackgroundColor3 = _isPlaylistMode and Color3.fromRGB(0, 120, 255) or currentTheme.accent
		kbBtn.BackgroundTransparency = _isPlaylistMode and 0 or 1
		kbBtn.Text = _isPlaylistMode and L.selectEmote or ""
		kbBtn.TextColor3 = Color3.new(1,1,1)
		kbBtn.Font = Enum.Font.GothamBold
		kbBtn.TextSize = 12
		kbBtn.ZIndex = 4
		if _isPlaylistMode then
			kbBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
		end
		kbBtn.ClipsDescendants = true
		kbBtn.Parent = cardContainer
		Instance.new("UICorner", kbBtn).CornerRadius = UDim.new(0, 4)

		local kbIcon = Instance.new("ImageLabel")
		kbIcon.Size = UDim2.new(0.95, 0, 0.95, 0)
		kbIcon.Position = UDim2.fromScale(0.5, 0.5)
		kbIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		kbIcon.BackgroundTransparency = 1
		kbIcon.ScaleType = Enum.ScaleType.Fit
		if _isPlaylistMode then
			kbIcon.Image = ""
		else
			kbIcon.Image = ResolveAssetImage(kbHasBinding and Icons.KeybindActive or Icons.Keybind)
		end
		kbIcon.ImageColor3 = kbHasBinding and currentTheme.accent or currentTheme.textDim
		kbIcon.ZIndex = 5
		kbIcon.Active = false
		kbIcon.Visible = not _isPlaylistMode
		kbIcon.Parent = kbBtn

		kbBtn.MouseEnter:Connect(function()
			local isSel = _selectedEmotesForPlaylist and _selectedEmotesForPlaylist[tostring(emote.id)]
			local targetCol
			if _isPlaylistMode then
				if isSel then
					targetCol = Color3.fromRGB(40, 180, 100)
				else
					targetCol = Color3.fromRGB(0, 150, 255)
				end
			else
				targetCol = kbHasBinding and currentTheme.tertiary or currentTheme.accent
			end
			TweenService:Create(kbBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
				BackgroundColor3 = targetCol,
				BackgroundTransparency = _isPlaylistMode and 0 or 1,
				Size = UDim2.new(1, 6, 0, KB_H + 6),
				Rotation = 0
			}):Play()
		end)
		kbBtn.MouseLeave:Connect(function()
			local isSel = _selectedEmotesForPlaylist and _selectedEmotesForPlaylist[tostring(emote.id)]
			local targetCol
			if _isPlaylistMode then
				if isSel then
					targetCol = Color3.fromRGB(46, 204, 113)
				else
					targetCol = Color3.fromRGB(0, 120, 255)
				end
			else
				targetCol = currentTheme.stroke
			end
			TweenService:Create(kbBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				BackgroundColor3 = targetCol,
				BackgroundTransparency = _isPlaylistMode and 0 or 1,
				Size = UDim2.new(1, 0, 0, KB_H),
				Rotation = 0
			}):Play()
		end)

		local function _UpdateSelectState()
		local isSel = _selectedEmotesForPlaylist[tostring(emote.id)]
		print("[Vexro Emotes] _UpdateSelectState: " .. tostring(emote.name) .. " isSel=" .. tostring(isSel))
		kbBtn.Text = isSel and "" or L.selectEmote
		kbIcon.Image = isSel and "rbxthumb://type=Asset&id=120391439283611&w=150&h=150" or ""
		if _isPlaylistMode then
			kbIcon.Visible = isSel
			kbIcon.ImageColor3 = Color3.new(1, 1, 1)
			if isSel then
				kbBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
				kbBtn.BackgroundTransparency = 0
			else
				kbBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
				kbBtn.BackgroundTransparency = 0
			end
		else
			kbIcon.Visible = true
		end
	end
	if _isPlaylistMode then _UpdateSelectState() end

	kbBtn.MouseButton1Click:Connect(function()
		print("[Vexro Emotes] kbBtn clicked: " .. tostring(emote.name) .. " isPlaylistMode=" .. tostring(_isPlaylistMode))
		if _isPlaylistMode then
			local k = tostring(emote.id)
			_selectedEmotesForPlaylist[k] = not _selectedEmotesForPlaylist[k]
			_UpdateSelectState()
			return
		end

			ShowKeybindDialog(emote.id, emote, kbHasBinding)
		end)

		local longPressTimer = nil
		local longPressOverlay = nil

		local function ShowRemoveOverlay()
			if not GetKeybind(emote.id) then return end
			if longPressOverlay then return end
			longPressOverlay = Instance.new("Frame")
			longPressOverlay.Size = UDim2.new(1, 0, 0, 0)
			longPressOverlay.Position = UDim2.new(0, 0, 1, 0)
			longPressOverlay.AnchorPoint = Vector2.new(0, 1)
			longPressOverlay.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
			longPressOverlay.BackgroundTransparency = 0.2
			longPressOverlay.ZIndex = 15
			longPressOverlay.ClipsDescendants = true
			longPressOverlay.Parent = card
			Instance.new("UICorner", longPressOverlay).CornerRadius = UDim.new(0, 8)
			TweenService:Create(longPressOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0)
			}):Play()
			local removeIcon = Instance.new("ImageButton")
			removeIcon.Size = UDim2.new(0, 42, 0, 42)
			removeIcon.Position = UDim2.fromScale(0.5, 0.5)
			removeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			removeIcon.BackgroundTransparency = 1
			removeIcon.Image = ResolveAssetImage(Icons.KeybindRemove)
			removeIcon.ImageColor3 = Color3.new(1, 1, 1)
			removeIcon.ZIndex = 16
			removeIcon.Parent = longPressOverlay
			removeIcon.MouseButton1Click:Connect(function()
				RemoveKeybind(emote.id)
				kbHasBinding = false
				kbIcon.Image = ResolveAssetImage(Icons.Keybind)
				kbIcon.ImageColor3 = currentTheme.textDim
				if longPressOverlay then longPressOverlay:Destroy(); longPressOverlay = nil end
			end)
			task.delay(2.5, function()
				if longPressOverlay then
					TweenService:Create(longPressOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
					task.delay(0.2, function()
						if longPressOverlay then longPressOverlay:Destroy(); longPressOverlay = nil end
					end)
				end
			end)
		end

		local pressStart = 0
		card.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				pressStart = tick()
				longPressTimer = task.delay(0.6, ShowRemoveOverlay)
			end
		end)
		card.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				if longPressTimer then task.cancel(longPressTimer); longPressTimer = nil end
				if tick() - pressStart < 0.4 and longPressOverlay then
					longPressOverlay:Destroy(); longPressOverlay = nil
				end
			end
		end)
	end

	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, 0, 0, CARD),
			Rotation = 0
		}):Play()
		local hoverColor = currentTheme.strokeHover or currentTheme.accent
		TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0, Thickness = 1.5, Color = hoverColor}):Play()
	end)

	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(1, 0, 0, CARD),
			Rotation = 0
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.38, Thickness = 1, Color = currentTheme.accent}):Play()
	end)
	
	
	card.MouseButton1Click:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0.9, 0, 0, CARD * 0.9)}):Play()
		
		task.delay(0.1, function()
			TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {Size = UDim2.new(1, 0, 0, CARD)}):Play()
		end)
		
		TweenService:Create(stroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(80, 220, 120)}):Play()
		task.delay(0.3, function()
			if card.Parent then
				TweenService:Create(stroke, TweenInfo.new(0.2), {Color = currentTheme.accent}):Play()
			end
		end)
		
		if FriendData and FriendData.currentSyncPartner then
			FriendData.currentSyncPartner = nil
		end
		PlayEmote(emote.id, emote.name)
	end)

	return cardContainer
end

local function UpdateCards(animate)
	ClearCards()
	
	local startIdx = (page - 1) * perPage + 1
	local endIdx = math.min(page * perPage, #filtered)
	
	local ci = 0
	for i = startIdx, endIdx do
		if filtered[i] then
			cards[i] = MakeCard(filtered[i], ci, animate)
			ci = ci + 1
		end
	end
	
	local CARD = currentCardSize
	local PAD = isMobile and 4 or 6
	local NAME_H = math.clamp(CARD * 0.35, 18, 28)
	local FAV_H = math.clamp(CARD * 0.3, 18, 24)
	local CARD_TOTAL_H = CARD + NAME_H + FAV_H
	
	local rows = math.ceil(ci / math.max(cols, 1))
	scroll.CanvasSize = UDim2.new(0, 0, 0, rows * (CARD_TOTAL_H + PAD) + PAD)
	scroll.CanvasPosition = Vector2.zero

	local _npStart = page * perPage + 1
	local _npEnd   = math.min((page + 1) * perPage, #filtered)
	if _npStart <= _npEnd then
		task.spawn(function()
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

local function Refresh(animate)
	CalcLayout()
	UpdatePageUI()
	UpdateCards(animate ~= false)
end

prevBtn.MouseButton1Click:Connect(function()
	if pages <= 1 then return end
	if page > 1 then 
		page = page - 1
	else 
		page = pages
	end
	Refresh(true)
end)
nextBtn.MouseButton1Click:Connect(function()
	if pages <= 1 then return end
	if page < pages then 
		page = page + 1
	else 
		page = 1
	end
	Refresh(true)
end)

-- ===============================================================
-- TAB SYSTEM
-- ===============================================================

UpdateTabStyles = function()
    for name, data in pairs(tabBtns) do
        local active = currentTab == name
        TweenService:Create(data.btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundColor3 = active and currentTheme.tertiary or currentTheme.tertiary,
            BackgroundTransparency = active and 0.05 or 1
        }):Play()
        data.stroke.Transparency = active and 0.65 or 1

        local iconColor = active and currentTheme.accent or currentTheme.textDim
        if data.img then
            if data.img:IsA("ImageLabel") then
                TweenService:Create(data.img, TweenInfo.new(0.18), {ImageColor3 = iconColor}):Play()
            elseif data.img:IsA("TextLabel") then
                TweenService:Create(data.img, TweenInfo.new(0.18), {TextColor3 = iconColor}):Play()
            end
        end
        if data.label then
            TweenService:Create(data.label, TweenInfo.new(0.18), {
                TextColor3 = active and currentTheme.text or currentTheme.textDim
            }):Play()
            data.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end

        if active and _tabIndicator then
            TweenService:Create(_tabIndicator, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 2, 0, data.yPos + 7)
            }):Play()
        end
    end
end

playlistBackBtn = Instance.new("TextButton")
playlistBackBtn.Size = UDim2.new(0, 30, 0, 30)
playlistBackBtn.Position = UDim2.new(0, 8, 0, titleH + 6)
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
playlistDoneBtn.Position = UDim2.new(1, -58, 0, titleH + 6)
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
		local existing = main:FindFirstChild("VexroSavePlaylistOverlay")
		if existing then existing:Destroy() end

		local overlay = Instance.new("TextButton")
		overlay.Name = "VexroSavePlaylistOverlay"
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
		cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
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
		saveBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
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
		warn("[Vexro Emotes] ShowSavePlaylistDialog Error: " .. tostring(err))
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
		warn("[Vexro Emotes] playlistDoneBtn.Click Error: " .. tostring(err))
	end
end)

RefreshPlaylistsList = function()
	local success, err = pcall(function()
		print("[Vexro Emotes] RefreshPlaylistsList running. Playlists count: " .. tostring(#Playlists))
		if not playlistsPanel then
			warn("[Vexro Emotes] playlistsPanel is NIL inside RefreshPlaylistsList!")
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

				-- narrow labels to leave room for delete and favorite buttons
				local isOwner = tostring(pl.creatorId) == tostring(player.UserId)
				local labelRightOffset = isOwner and -142 or -70

				-- Favorite button
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
					local isCurrentlyFav = PlaylistFavorites[plId]
					PlaylistFavorites[plId] = not isCurrentlyFav
					
					task.spawn(function()
						ApiRequest("POST", "/emote/playlist/favorite", {
							userId = tostring(player.UserId),
							token = getOrCreateToken(),
							playlistId = plId,
							action = PlaylistFavorites[plId] and "add" or "remove"
						})
					end)
					
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

				-- Delete button (only for playlists owned by the player)
				if isOwner then
					local delBtn = Instance.new("TextButton")
					delBtn.Size = UDim2.new(0, 38, 0, 38)
					delBtn.Position = UDim2.new(1, -46, 0.5, -19)
					delBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
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
							-- First tap: ask for confirmation
							_delConfirm = true
							delBtn.Text = L.deleteConfirm
							delBtn.TextSize = 10
							delBtn.BackgroundColor3 = Color3.fromRGB(220, 80, 20)
							-- Auto reset after 3 seconds if not confirmed
							if _delTimer then _delTimer:Disconnect() end
							_delTimer = task.delay(3, function()
								if delBtn and delBtn.Parent then
									_delConfirm = false
									delBtn.Text = L.deletePlaylist
									delBtn.TextSize = 12
									delBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
								end
							end)
						else
							-- Second tap: actually delete
							_delConfirm = false
							for i, p in ipairs(Playlists) do
								if p.id == pl.id then
									table.remove(Playlists, i)
									break
								end
							end
							task.spawn(function()
								ApiRequest("POST", "/emote/playlist/delete", {
									userId = tostring(player.UserId),
									token = getOrCreateToken(),
									playlistId = tostring(pl.id)
								})
							end)
							SaveData()
							if RefreshPlaylistsList then RefreshPlaylistsList() end
						end
					end)
				end

				row.MouseButton1Click:Connect(function()
					-- Don't open playlist if a delete button exists (handled separately)
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
		warn("[Vexro Emotes] RefreshPlaylistsList Inner Error: " .. tostring(err))
	end
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
	search.Text = ""
	page = 1
	
	local isSettings  = currentTab == "settings"
	local isFriends   = currentTab == "friends"
	local isKeybinds  = currentTab == "keybinds"
	local isPlaylists = currentTab == "playlists"
	local isAnimations = currentTab == "animations"
	settingsPanel.Visible  = isSettings
	friendsPanel.Visible   = isFriends
	keybindsPanel.Visible  = isKeybinds
	local viewingPlaylist = isPlaylists and (_currentPlaylistId ~= nil)
	
	if isPlaylists and not viewingPlaylist then
		if RefreshPlaylistsList then RefreshPlaylistsList() end
	end
	playlistsPanel.Visible = isPlaylists and not viewingPlaylist
	local hideNormal = isSettings or isFriends or isKeybinds or (isPlaylists and not viewingPlaylist)
	scroll.Visible  = not hideNormal
	search.Visible  = not hideNormal
	if playlistBackBtn then
		playlistBackBtn.Visible = viewingPlaylist
		playlistDoneBtn.Visible = _isPlaylistMode
		search.Position = UDim2.new(0, viewingPlaylist and 46 or 8, 0, (titleH + 6))
		if _isPlaylistMode then
			search.Size = UDim2.new(1, -80, 0, searchH)
		else
			search.Size = UDim2.new(1, viewingPlaylist and -54 or -16, 0, searchH)
		end
	end
	pageBar.Visible = not hideNormal
		task.delay(0.1, function()
		pcall(function()
			if playlistsPanel then
				print("[Vexro Emotes] Delayed check: playlistsPanel Parent=" .. tostring(playlistsPanel.Parent and playlistsPanel.Parent.Name or "nil") .. ", Visible=" .. tostring(playlistsPanel.Visible) .. ", Size=" .. tostring(playlistsPanel.Size) .. ", AbsSize=" .. tostring(playlistsPanel.AbsoluteSize) .. ", AbsPos=" .. tostring(playlistsPanel.AbsolutePosition) .. ", ZIndex=" .. tostring(playlistsPanel.ZIndex) .. ", CanvasSize=" .. tostring(playlistsPanel.CanvasSize))
				for _, child in ipairs(playlistsPanel:GetChildren()) do
					print("[Vexro Emotes] Delayed child: Name=" .. child.Name .. ", Class=" .. child.ClassName .. ", Size=" .. tostring(child:IsA("GuiObject") and child.Size or "N/A") .. ", AbsSize=" .. tostring(child:IsA("GuiObject") and child.AbsoluteSize or "N/A") .. ", AbsPos=" .. tostring(child:IsA("GuiObject") and child.AbsolutePosition or "N/A") .. ", Visible=" .. tostring(child:IsA("GuiObject") and child.Visible or "N/A"))
					if child.Name == "playlistTopBar" then
						for _, sub in ipairs(child:GetChildren()) do
							print("[Vexro Emotes]   Sub-child: Name=" .. sub.Name .. ", Class=" .. sub.ClassName .. ", Size=" .. tostring(sub:IsA("GuiObject") and sub.Size or "N/A") .. ", AbsSize=" .. tostring(sub:IsA("GuiObject") and sub.AbsoluteSize or "N/A") .. ", AbsPos=" .. tostring(sub:IsA("GuiObject") and sub.AbsolutePosition or "N/A") .. ", Visible=" .. tostring(sub:IsA("GuiObject") and sub.Visible or "N/A"))
						end
					end
				end
			else
				print("[Vexro Emotes] Delayed check: playlistsPanel is NIL")
			end
			print("[Hierarchy] --- START CONTENT HIERARCHY ---")
			if content then
				PrintHierarchy(content)
			end
			print("[Hierarchy] --- END CONTENT HIERARCHY ---")
		end)
	end)
	
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
		titleIcon.ImageColor3 = currentTheme.text
		titleIcon.Visible = true
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
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true

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
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "settings" then
		title.Text = L.settings
		titleIcon.Image = ResolveAssetImage(Icons.Settings)
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
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
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "friends" then
		title.Text = L.friendTab
		titleIcon.Image = ResolveAssetImage("rbxassetid://115725480722697")
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "keybinds" then
		title.Text = L.keybinds
		titleIcon.Image = ResolveAssetImage("rbxassetid://122679509852670")
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "animations" then
		currentData = AnimationPacks
		filtered = AnimationPacks
		title.Text = isES and "Animaciones" or "Animations"
		titleIcon.Image = ResolveAssetImage("rbxassetid://75528584354229")
		titleIcon.ImageColor3 = currentTheme.text
		titleIcon.Visible = true
	end
	
	local tabIconSz = isMobile and 24 or 27
	titleIcon.Size = UDim2.new(0, tabIconSz, 0, tabIconSz)
	titleIcon.Position = UDim2.new(0, 18, 0.5, 0)
	titleIcon.AnchorPoint = Vector2.new(0, 0.5)
	titleIcon.ImageColor3 = currentTheme.accent
	title.Position = UDim2.new(0, 18 + tabIconSz + 9, 0, isMobile and 10 or 8)
	title.Size = UDim2.new(1, -220, 0, 24)
	local subtitles = {
		emotes = isES and "Biblioteca de emotes" or "Emote library",
		animations = isES and "Paquetes de animación" or "Animation packs",
		favorites = isES and "Tus emotes guardados" or "Your saved emotes",
		recent = isES and "Reproducidos recientemente" or "Recently played",
		friends = isES and "Conecta y sincroniza" or "Connect and sync",
		keybinds = isES and "Accesos rápidos" or "Quick shortcuts",
		playlists = isES and "Colecciones personalizadas" or "Custom collections",
		settings = isES and "Preferencias de la interfaz" or "Interface preferences",
	}
	titleSubtitle.Text = subtitles[currentTab] or ""
	
	UpdateTabStyles()
	local shouldRefresh = not isSettings and not isKeybinds and not isFriends and (not isPlaylists or viewingPlaylist)
	if shouldRefresh then Refresh(true) end
end

tabBtns["emotes"].btn.MouseButton1Click:Connect(function() currentTab = "emotes"; UpdateTabData() end)
tabBtns["favorites"].btn.MouseButton1Click:Connect(function() currentTab = "favorites"; UpdateTabData() end)

tabBtns["recent"].btn.MouseButton1Click:Connect(function() currentTab = "recent"; UpdateTabData() end)
tabBtns["animations"].btn.MouseButton1Click:Connect(function() currentTab = "animations"; UpdateTabData() end)
tabBtns["settings"].btn.MouseButton1Click:Connect(function() currentTab = "settings"; UpdateTabData() end)
tabBtns["friends"].btn.MouseButton1Click:Connect(function() currentTab = "friends"; UpdateTabData() end)
if tabBtns["playlists"] then tabBtns["playlists"].btn.MouseButton1Click:Connect(function() currentTab = "playlists"; _currentPlaylistId = nil
_isPlaylistMode = false
_selectedEmotesForPlaylist = {}
if RefreshPlaylistsList then RefreshPlaylistsList() end
; UpdateTabData() end) end
if not isMobile then tabBtns["keybinds"].btn.MouseButton1Click:Connect(function() currentTab = "keybinds"; UpdateTabData() end) end

local searchToken = 0
local recordToken = 0
search:GetPropertyChangedSignal("Text"):Connect(function()
	if currentTab == "settings" then return end
	searchToken = searchToken + 1
	local myToken = searchToken
	task.wait(0.08)
	if myToken ~= searchToken then return end
	local q = search.Text:lower()
	if #q >= 2 then
		hideTrendingDropdown()
		-- Record the final query only after 10 seconds of inactivity.
		recordToken = recordToken + 1
		local myRecord = recordToken
		task.delay(10, function()
			if myRecord ~= recordToken then return end
			if not search or search.Text:lower() ~= q then return end
			recordSearchQuery(search.Text)
		end)
	elseif q == "" and search:IsFocused() and search.Visible then
		recordToken = recordToken + 1
		if canShowTrendingDropdown() then
			trendingDropdown.Visible = true
			task.spawn(refreshTrendingDropdown)
		else
			hideTrendingDropdown()
		end
	end
	filtered = {}
	for i = 1, #currentData do
		local e = currentData[i]
		if not _badEmotes[tostring(e.id)] and (q == "" or (#q <= #(e._lname or e.name) and (e._lname or e.name:lower()):find(q, 1, true))) then
			filtered[#filtered + 1] = e
		end
	end
	page = 1
	Refresh(true)
end)

-- ===============================================================
-- MINI ICON
-- ===============================================================

do
local iconS = isMobile and 50 or 60
local miniIcon = Instance.new("ImageButton")
miniIcon.Size = UDim2.new(0, iconS, 0, iconS)
miniIcon.Position = UDim2.new(0, 20, 0.5, -iconS/2)
miniIcon.BackgroundColor3 = currentTheme.secondary
miniIcon.Image = "rbxassetid://88874992610290"
miniIcon.Visible = false
miniIcon.ZIndex = 1000
miniIcon.Parent = gui
Instance.new("UICorner", miniIcon).CornerRadius = UDim.new(0, 14)

local miniIconStroke = Instance.new("UIStroke")
miniIconStroke.Color = currentTheme.accent
miniIconStroke.Thickness = 1.5
miniIconStroke.Parent = miniIcon

miniIconGrad = Instance.new("UIGradient")
miniIconGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, currentTheme.accent),
	ColorSequenceKeypoint.new(1, currentTheme.stroke)
}
miniIconGrad.Rotation = 45
miniIconGrad.Parent = miniIconStroke

task.spawn(function()
	while miniIcon.Parent do
		if miniIcon.Visible then
			TweenService:Create(miniIcon, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = UDim2.new(0, iconS + 4, 0, iconS + 4)}):Play()
			task.wait(1)
			TweenService:Create(miniIcon, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = UDim2.new(0, iconS, 0, iconS)}):Play()
			task.wait(1)
		else
			task.wait(0.5)
		end
	end
end)

do
local savedPos, savedSize = nil, nil
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
				TweenService:Create(mainStroke, TweenInfo.new(0.35), {Transparency = 0}):Play()
				
				task.delay(0.4, function()
					main.ClipsDescendants = true
					if currentTab ~= "settings" then Refresh(true) end
				end)
			end
		end
		iconDragging = false
	end
end)

minBtn.MouseButton1Click:Connect(function()
	main.ClipsDescendants = true
	savedPos = main.Position
	savedSize = main.Size
	
	TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
	TweenService:Create(mainStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
	
	task.delay(0.3, function()
		main.Visible = false
		miniIcon.Visible = true
	end)
end)

local function _CleanupScript()
	pcall(function() _heartbeatConn:Disconnect() end)
	pcall(function() _charAddedConn:Disconnect() end)
	pcall(function() if _keybindInputConn then _keybindInputConn:Disconnect() end end)
	pcall(function() DisableCopyEmotePrompts() end)
	pcall(function() StopHUDTracking() end)
	pcall(function() VexroAcrylic.Stop() end)
	-- Oynanan emote'u durdur
	pcall(function() StopEmote(false) end)
	-- Sunucuya disconnect bildir
	pcall(function()
		ApiRequest("POST", "/session/disconnect", {
			userId = tostring(player.UserId),
			token  = getOrCreateToken(),
		})
	end)
	_genv().VexroEmotesCleanup = nil
	_genv().lastVexroEmote = nil
	_genv().autoReloadEnabled_Vexro = nil
	pcall(function() gui:Destroy() end)
end

_genv().VexroEmotesCleanup = _CleanupScript

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

-- ===============================================================
-- DRAG & RESIZE
-- ===============================================================

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
bottomBar.InputBegan:Connect(StartDrag)
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
		local tabCount = not isMobile and 8 or 7
		local minH = (isMobile and 8 or 62) + (tabBtnS + 6) * (tabCount - 1) + tabBtnS + 16
		local newW = math.clamp(sizeStart.X + delta.X, 400, 1200)
		local newH = math.clamp(sizeStart.Y + delta.Y, minH, 800)
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

-- ===============================================================
-- CHARACTER RESPAWN & AUTO-RELOAD
-- ===============================================================

_genv().autoReloadEnabled_Vexro = Settings.loopEmote

local _charAddedConn = player.CharacterAdded:Connect(function(newChar)
	local newHum = newChar:WaitForChild("Humanoid", 5)
	if not newHum then return end
	
	if newHum.RigType == Enum.HumanoidRigType.R6 then
		Notify(SafeUtf8Char(0x274C), L.r6Msg)
		task.wait(2)
		gui:Destroy()
		return
	end
	
	if lastVexroAnimationPack then
		task.wait(0.5)
		local newAnimate = newChar:WaitForChild("Animate", 5)
		if newAnimate then
			pcall(function() EquipAnimationPack(lastVexroAnimationPack) end)
		end
	end
	
	if _genv().lastVexroEmote and _genv().autoReloadEnabled_Vexro then
		task.wait(1)
		PlayEmote(_genv().lastVexroEmote.id, _genv().lastVexroEmote.name, true)
		Notify("[R]", L.ready or "Emote reapplied")
	end
end)

-- ===============================================================
-- INITIALIZE
-- ===============================================================

main.Rotation = 0
local openSize = GetDefaultSize()
TweenService:Create(main, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Size = openSize, BackgroundTransparency = 0}):Play()
TweenService:Create(mainStroke, TweenInfo.new(0.45), {Transparency = 0}):Play()

task.wait(0.5)

main.ClipsDescendants = true
ApplyTheme(Settings.theme)
UpdateTabStyles()
UpdateTabData()

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
Notify(SafeUtf8Char(0x2705) .. " " .. L.ready, #Emotes .. " emotes")

-- ================================================================
-- VEXRO EXTENDED MODULES v1.0
-- Bölüm 1: Dinamik Tema  |  Bölüm 2: Animation Blending & Combo
-- Bölüm 3: Canlı Emote HUD  |  Bölüm 4: Entegrasyon
-- NOT: do...end bloğu Lua'nın 200 local sınırını aşmamak için
-- ================================================================
local function _VexroExtend()

-- ----------------------------------------------------------------
-- ----------------------------------------------------------------



local HUD, infoPanel, infoSpeedLbl, comboSlots, comboQueue_UI
local _currentInfoId, _currentInfoName
local _comboLoopEnabled = false
local _comboLoopList    = {}


-- ----------------------------------------------------------------
-- BÖLÜM 2 — ANİMASYON BLENDING & SEQUENCING (Combo Sistemi)
-- AnimationTrack:Play(0.3) ile 0.3s fade-in/out harmanlama,
-- Stopped sinyali ile otomatik sıralama, max 3 emote combo.
-- ----------------------------------------------------------------

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
				track:AdjustSpeed(Settings.speed)
			end
		end)

		currentAnimTrack = track
		_genv().lastVexroEmote = {id = emoteId, name = emoteName}
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
										BackgroundColor3 = Color3.fromRGB(30, 30, 46)
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

-- ----------------------------------------------------------------
-- BÖLÜM 3 — CANLI EMOTE HUD (Alt-Orta Şeffaf Panel)
-- RenderStepped canlı slider, hız butonları (0.1x–2x),
-- bilgi popup, sürüklenebilir knob, Disconnect ile FPS koruması.
-- ----------------------------------------------------------------

local hudTrackerConn = nil
local _hudHideToken  = 0

HUD = Instance.new("Frame")
HUD.Name                   = "VexroHUD"
HUD.Size                   = isMobile and UDim2.new(0, 320, 0, 100) or UDim2.new(0, 500, 0, 104)
HUD.Position               = UDim2.new(0.5, 0, 1, -120)
HUD.AnchorPoint            = Vector2.new(0.5, 1)
HUD.BackgroundColor3       = Color3.fromRGB(8, 8, 12)
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
hudFavBtn.BackgroundColor3       = Color3.fromRGB(30, 30, 46)
hudFavBtn.BackgroundTransparency = 0.20
hudFavBtn.Image                  = ResolveAssetImage(Icons.FavoriteEmpty)
hudFavBtn.ImageColor3            = currentTheme.accent
hudFavBtn.ZIndex                 = 502
hudFavBtn.Parent                 = HUD
Instance.new("UICorner", hudFavBtn).CornerRadius = UDim.new(1, 0)

local function RefreshHUDFavBtn()
	if not _currentInfoId then return end
	local isFav = IsFavorite(_currentInfoId)
	hudFavBtn.Image      = ResolveAssetImage(isFav and Icons.FavoriteFull or Icons.FavoriteEmpty)
	TweenService:Create(hudFavBtn, TweenInfo.new(0.15), {
		ImageColor3      = isFav and Color3.fromRGB(255, 215, 0) or currentTheme.accent,
		BackgroundColor3 = isFav and Color3.fromRGB(55, 45, 10) or Color3.fromRGB(30, 30, 46)
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
hudCreator.Text                   = "Vexro Emotes"
hudCreator.TextColor3             = Color3.fromRGB(120, 120, 145)
hudCreator.Font                   = Enum.Font.Gotham
hudCreator.TextSize               = isMobile and 10 or 11
hudCreator.TextXAlignment         = Enum.TextXAlignment.Left
hudCreator.ZIndex                 = 501
hudCreator.Parent                 = HUD

hudSliderBg = Instance.new("Frame")
hudSliderBg.Size             = UDim2.new(1, -148, 0, 4)
hudSliderBg.Position         = UDim2.new(0, 44, 0, 54)
hudSliderBg.BackgroundColor3 = Color3.fromRGB(42, 42, 58)
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
hudPauseBtn.BackgroundColor3       = Color3.fromRGB(30, 30, 46)
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
		hudPauseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
	end
end

hudPauseBtn.MouseButton1Click:Connect(function()
	if currentAnimTrack and _isPaused then
		pcall(function() currentAnimTrack:AdjustSpeed(Settings.speed) end)
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
			BackgroundColor3 = active and currentTheme.accent or Color3.fromRGB(30, 30, 46)
		}):Play()
	end
end

for si, spd in ipairs(HUD_SPEEDS) do
	local xOff = -(spTotalW + 8) + (si - 1) * (spBtnW + spBtnGap)
	local sBtn = Instance.new("TextButton")
	sBtn.Size                   = UDim2.new(0, spBtnW, 0, 20)
	sBtn.Position               = UDim2.new(1, xOff, 0, 7)
	sBtn.BackgroundColor3       = (math.abs(spd - Settings.speed) < 0.01)
		and currentTheme.accent or Color3.fromRGB(30, 30, 46)
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
			pcall(function() currentAnimTrack:AdjustSpeed(spd) end)
		end
		RefreshHUDSpeedBtns()
		SaveData()
	end)
end

infoPanel = Instance.new("Frame")
infoPanel.Name                   = "VexroInfoPanel"
infoPanel.Size                   = UDim2.new(0, 270, 0, 260)
infoPanel.Position               = UDim2.new(0, -290, 1, -285)
infoPanel.BackgroundColor3       = Color3.fromRGB(10, 10, 18)
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
infoPanelClose.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
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
infoDescLbl.TextColor3             = Color3.fromRGB(140, 140, 165)
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
infoDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
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
infoCreatorLbl.TextColor3             = Color3.fromRGB(140, 200, 255)
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
infoSpeedLbl.TextColor3             = Color3.fromRGB(160, 160, 185)
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
infoPriceLbl.TextColor3             = Color3.fromRGB(160, 160, 185)
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
infoFavLbl.TextColor3             = Color3.fromRGB(160, 160, 185)
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
infoDateLbl.TextColor3             = Color3.fromRGB(130, 130, 155)
infoDateLbl.Font                   = Enum.Font.Gotham
infoDateLbl.TextSize               = 11
infoDateLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoDateLbl.ZIndex                 = 702
infoDateLbl.Parent                 = infoPanelBody





local copyIdBtn = Instance.new("TextButton")
copyIdBtn.Size             = UDim2.new(0.52, -2, 0, 26)
copyIdBtn.Position         = UDim2.new(0.48, 2, 0, 161)
copyIdBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
copyIdBtn.Text             = L.copyId
copyIdBtn.TextColor3       = Color3.fromRGB(180, 180, 210)
copyIdBtn.Font             = Enum.Font.GothamBold
copyIdBtn.TextSize         = 12
copyIdBtn.ZIndex           = 703
copyIdBtn.Parent           = infoPanelBody
Instance.new("UICorner", copyIdBtn).CornerRadius = UDim.new(0, 8)
local copyIdStroke = Instance.new("UIStroke")
copyIdStroke.Color       = Color3.fromRGB(70, 70, 100)
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
		infoPriceLbl.TextColor3 = Color3.fromRGB(100, 220, 130)
	elseif meta.price and meta.price > 0 then
		infoPriceLbl.Text       = tostring(meta.price) .. " R$"
		infoPriceLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		infoPriceLbl.Text       = (meta.priceStatus and meta.priceStatus ~= "") and meta.priceStatus or "—"
		infoPriceLbl.TextColor3 = Color3.fromRGB(160, 160, 185)
	end
	infoFavLbl.Text = meta.favoriteCount
		and ("♥ " .. tostring(meta.favoriteCount))
		or "—"
	if meta.createdUtc and meta.createdUtc ~= "" then
		infoDateLbl.Text = meta.createdUtc:sub(1, 10)
	else
		infoDateLbl.Text = "—"
	end
	hudCreator.Text = (meta.creatorName and meta.creatorName ~= "") and meta.creatorName or "Vexro Emotes"
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
	infoEmoteName.Text  = emoteName or "—"
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
		infoPriceLbl.TextColor3 = Color3.fromRGB(160, 160, 185)
		infoFavLbl.Text     = "…"
		infoDateLbl.Text    = "…"
		hudCreator.Text     = "Vexro Emotes"
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
	copyIdBtn.TextColor3      = Color3.fromRGB(100, 220, 130)
	task.delay(1.5, function()
		copyIdBtn.Text       = orig
		copyIdBtn.TextColor3 = Color3.fromRGB(180, 180, 210)
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
	if not Settings.showHUD then return end
	_hudHideToken = _hudHideToken + 1

	_currentInfoId   = emoteId
	_currentInfoName = emoteName

	RefreshHUDFavBtn()
	hudName.Text    = emoteName or "Emote"
	hudCreator.Text = "Vexro Emotes"

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

-- ----------------------------------------------------------------
-- BOLUM 4 - HUD & BLENDING ENTEGRASYONU
-- ----------------------------------------------------------------

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

-- ----------------------------------------------------------------
-- BOLUM 5 - COMBO SIRASI
-- ----------------------------------------------------------------

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
	s.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
	s.Text             = L.slotLabel .. " " .. si
	s.TextColor3       = Color3.fromRGB(120, 120, 148)
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
				comboSlots[j].Text = e and e.name:sub(1,9) or ("Slot " .. j)
				TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
					BackgroundColor3 = e and currentTheme.accent or Color3.fromRGB(30,30,46)
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
addComboBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 170)
addComboBtn.Text             = L.addEmote
addComboBtn.TextColor3       = Color3.new(1, 1, 1)
addComboBtn.Font             = Enum.Font.GothamBold
addComboBtn.TextSize         = 12
addComboBtn.ZIndex           = 9
addComboBtn.Parent           = comboBtnHolder
Instance.new("UICorner", addComboBtn).CornerRadius = UDim.new(0, 8)

playComboBtn = Instance.new("TextButton")
playComboBtn.Size             = UDim2.new(0.5, -2, 1, 0)
playComboBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
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
loopComboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
loopComboBtn.Text             = L.loopText .. ": " .. L.off
loopComboBtn.TextColor3       = Color3.fromRGB(120, 120, 148)
loopComboBtn.Font             = Enum.Font.GothamBold
loopComboBtn.TextSize         = 12
loopComboBtn.ZIndex           = 9
loopComboBtn.Parent           = comboRow
Instance.new("UICorner", loopComboBtn).CornerRadius = UDim.new(0, 8)
loopStroke = Instance.new("UIStroke")
loopStroke.Color        = Color3.fromRGB(60, 60, 90)
loopStroke.Thickness    = 1
loopStroke.Transparency = 0.5
loopStroke.Parent       = loopComboBtn
local loopIcon = Instance.new("ImageLabel")
loopIcon.Size                   = UDim2.new(0, 14, 0, 14)
loopIcon.Position               = UDim2.new(0, 8, 0.5, -7)
loopIcon.BackgroundTransparency = 1
loopIcon.Image                  = ResolveAssetImage(Icons.Refresh)
loopIcon.ImageColor3            = Color3.fromRGB(120, 120, 148)
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
		loopComboBtn.TextColor3       = Color3.fromRGB(120, 120, 148)
		loopIcon.ImageColor3          = Color3.fromRGB(120, 120, 148)
		TweenService:Create(loopComboBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(30, 30, 46)
		}):Play()
		loopStroke.Color = Color3.fromRGB(60, 60, 90)
	end
end)

clearComboBtn = Instance.new("TextButton")
clearComboBtn.Size             = UDim2.new(1, -12, 0, 26)
clearComboBtn.Position         = UDim2.new(0, 6, 0, 138)
clearComboBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
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
		addComboBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		addComboBtn.Text = L.selectFirst
		task.delay(0.7, function()
			addComboBtn.BackgroundColor3 = origCol
			addComboBtn.Text = L.addEmote
		end)
		return
	end
	table.insert(comboQueue_UI, {id = _currentInfoId, name = _currentInfoName or "Emote"})
	local idx = #comboQueue_UI
	comboSlots[idx].Text = (comboQueue_UI[idx].name):sub(1, 9)
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
		loopComboBtn.TextColor3       = Color3.fromRGB(120, 120, 148)
		loopComboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
		loopStroke.Color              = Color3.fromRGB(60, 60, 90)
		loopIcon.ImageColor3          = Color3.fromRGB(120, 120, 148)
	end
	for j = 1, 3 do
		comboSlots[j].Text = L.slotLabel .. " " .. j
		TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(30, 30, 46)
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
_VexroExtend()
