--[[
	HEXA | +1 Speed Monkey Escape Hub | Keyless

	Game-specific systems:
	  - Wins / Steps / Treadmills / Worlds / Stages / Rebirth progression
	  - Trails/Tails, Auras, Charms, Potions, Chests, Secrets & Events
	  - Dynamic teleports, collection radius, presets and live session stats
	  - God Mode: anti-death remote + water/flood/lava/crusher/closing-wall protection
	  - Anti Void, Auto Respawn/Resume, Noclip, Infinite Jump, Server Hop
	  - High-priority CoreGui interface + draggable minimized mini panel

	Languages: Spanish / English
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes", 15)
local Map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 15)
local Data = LocalPlayer:WaitForChild("Data", 15)

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
	StayStill = false,
	FarmDelay = 0.35,
	SmartFarmDelay = false,
	RunInPlace = false,
	AutoTreadmill = false,
	TreadmillMode = "Auto",
	FarmWorldMode = "Auto",
	StageMode = "Auto",
	AutoBestStage = false,
	BuyTrail = false,
	BuyAura = false,
	BuyUpgrades = false,
	EquipBestTrail = false,
	EquipBestAura = false,
	BuyCharms = false,
	AutoRebirth = false,
	RebirthMode = "Instant",
	MinRebirthLevel = 50,
	BestWorld = false,
	JoinRace = false,
	WinRace = false,
	GodMode = false,
	Bananas = false,
	Tacos = false,
	LuckyBlocks = false,
	HackerPortals = false,
	OpenChests = false,
	AutoSecretEvent = false,
	CollectRadius = 250,
	CollectNearestFirst = true,
	FreeReward = false,
	OfflineEarnings = false,
	StreakRewards = false,
	BestCharms = false,
	SpeedPotion = false,
	WinsPotion = false,
	WalkSpeedEnabled = false,
	WalkSpeedValue = 32,
	InfiniteJump = false,
	Noclip = false,
	IgnoreHazards = false,
	AntiFall = false,
	AutoRespawn = false,
	AntiAFK = false,
	AutoRejoin = false,
	AutoResume = false,
	PerformanceMode = false,
}

local AUTO_KEYS = {
	"FarmWins", "FarmSteps", "StayStill", "SmartFarmDelay", "RunInPlace", "AutoTreadmill", "AutoBestStage",
	"BuyTrail", "BuyAura", "BuyUpgrades", "EquipBestTrail", "EquipBestAura", "BuyCharms",
	"AutoRebirth", "BestWorld", "JoinRace", "WinRace", "GodMode", "Bananas", "Tacos",
	"LuckyBlocks", "HackerPortals", "OpenChests", "AutoSecretEvent", "FreeReward",
	"OfflineEarnings", "StreakRewards", "BestCharms", "SpeedPotion", "WinsPotion",
	"WalkSpeedEnabled", "InfiniteJump", "Noclip", "IgnoreHazards", "AntiFall", "AutoRespawn",
	"AntiAFK", "AutoRejoin", "AutoResume", "PerformanceMode",
}

local lastRun = {}
local hubRunning = true

-- +1 Speed Monkey Escape defaults. Live detection is still used so updates to
-- worlds/stages/treadmills do not require rewriting the whole hub.
local GAME_INFO = {
	Name = "+1 Speed Monkey Escape",
	PlaceId = 114697347887839,
	WorldCount = 5,
	StageCount = 9,
	ShardCount = 9,
	VoidY = -30,
	KnownHazards = {
		"lava", "water", "flood", "tsunami", "kill", "death", "hazard", "trap",
		"crusher", "crush", "press", "axe", "car", "traffic", "spike", "acid",
		"movingwall", "movingwalls", "closingwall", "closingwalls", "wallcrusher",
		"deathwall", "wallkill", "rolling", "boulder", "shark"
	},
}


local function normalizeName(v)
	return string.lower((tostring(v):gsub("[%s_%-%./]", "")))
end

local function getRemote(name)
	if not Remotes then return nil end
	local direct = Remotes:FindFirstChild(name)
	if direct then return direct end
	local wanted = normalizeName(name)
	for _, obj in ipairs(Remotes:GetDescendants()) do
		if normalizeName(obj.Name) == wanted then
			return obj
		end
	end
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


-- The current game client reports course deaths through Remotes.Died. If the
-- executor supports metamethod hooks, block only that report while God Mode is
-- enabled. The hook stays installed but becomes inert when God Mode is OFF.
local antiDeathHookInstalled = false
local function installGameAntiDeathHook()
	if antiDeathHookInstalled then return true end
	if not hookmetamethod or not newcclosure or not getnamecallmethod then return false end
	local diedRemote = getRemote("Died")
	if not diedRemote then return false end
	local ok = pcall(function()
		local previous
		previous = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if S.GodMode and self == diedRemote and (method == "FireServer" or method == "InvokeServer") then
				return nil
			end
			return previous(self, ...)
		end))
	end)
	antiDeathHookInstalled = ok
	return ok
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

local function cfgModule(name)
	local config = RS:FindFirstChild("Config")
	local f = config and config:FindFirstChild(name)
	if not f then return nil end
	local ok, m = pcall(require, f)
	return ok and m or nil
end

local function farmWins()
	local worldValue = dataChild("World")
	if not Map or not worldValue then return end
	local w = Map:FindFirstChild("World" .. tostring(worldValue.Value))
	local stages = w and w:FindFirstChild("Stages")
	if not stages then return end
	for _, stage in ipairs(stages:GetChildren()) do
		local win = stage:FindFirstChild("NormalWin")
		local btn = win and win:FindFirstChild("Button")
		if btn then
			touchPart(btn)
			task.wait(0.05)
		end
	end
end

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

local function bestWorldNumber()
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

local function valueNumber(obj)
	if not obj then return 0 end
	local raw = obj.Value
	if type(raw) == "number" then return raw end
	local n = tonumber(tostring(raw):gsub(",", ""))
	return n or 0
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
	local score = 0
	for _, attr in ipairs({ "Reward", "Wins", "Speed", "Multiplier", "Level", "Stage", "Index", "Price", "Requirement" }) do
		local v = obj:GetAttribute(attr)
		if type(v) == "number" then score = math.max(score, v) end
	end
	local n = tonumber(tostring(obj.Name):match("(%d+)%D*$")) or tonumber(tostring(obj.Name):match("(%d+)")) or 0
	return math.max(score, n)
end

local function getWorldObjects()
	local result = {}
	if not Map then return result end
	for _, obj in ipairs(Map:GetChildren()) do
		local n = tonumber(tostring(obj.Name):match("[Ww]orld%s*(%d+)")) or tonumber(tostring(obj.Name):match("(%d+)"))
		if n and (obj:IsA("Folder") or obj:IsA("Model")) then
			table.insert(result, { number = n, object = obj, name = obj.Name })
		end
	end
	table.sort(result, function(a, b) return a.number < b.number end)
	return result
end

local function selectedWorldNumber()
	if S.FarmWorldMode == "Auto" then return bestWorldNumber() end
	local n = tonumber(tostring(S.FarmWorldMode):match("(%d+)"))
	return n or (dataChild("World") and tonumber(dataChild("World").Value)) or 1
end

local function getWorldObject(worldNumber)
	for _, info in ipairs(getWorldObjects()) do
		if info.number == worldNumber then return info.object end
	end
	return Map and Map:FindFirstChild("World" .. tostring(worldNumber)) or nil
end

local function stageNumber(stage)
	return tonumber(tostring(stage and stage.Name or ""):match("(%d+)")) or math.floor(scoreObject(stage))
end

local function getStages(worldNumber)
	local world = getWorldObject(worldNumber)
	local folder = world and (world:FindFirstChild("Stages") or world:FindFirstChild("Stage"))
	local result, seen = {}, {}
	if folder then
		for _, obj in ipairs(folder:GetChildren()) do
			if (obj:IsA("Folder") or obj:IsA("Model") or obj:IsA("BasePart")) and not seen[obj] then
				seen[obj] = true; table.insert(result, obj)
			end
		end
	elseif world then
		for _, obj in ipairs(world:GetDescendants()) do
			if tostring(obj.Name):match("[Ss]tage%s*%d+") and (obj:IsA("Folder") or obj:IsA("Model") or obj:IsA("BasePart")) and not seen[obj] then
				seen[obj] = true; table.insert(result, obj)
			end
		end
	end
	table.sort(result, function(a, b) return stageNumber(a) < stageNumber(b) end)
	return result
end

local function isStageUsable(stage)
	if not stage then return false end
	local locked = stage:GetAttribute("Locked")
	local unlocked = stage:GetAttribute("Unlocked")
	if locked == true or unlocked == false then return false end
	local levelReq = tonumber(stage:GetAttribute("LevelRequirement") or stage:GetAttribute("LevelRequired") or stage:GetAttribute("RequiredLevel") or 0) or 0
	local rebirthReq = tonumber(stage:GetAttribute("RebirthRequirement") or stage:GetAttribute("RebirthsRequired") or stage:GetAttribute("RequiredRebirths") or 0) or 0
	return getDataNumber("Level", "Lvl", "PlayerLevel") >= levelReq and getDataNumber("Rebirths") >= rebirthReq
end

local function findStageBySelection(worldNumber)
	local stages = getStages(worldNumber)
	if #stages == 0 then return nil end
	if S.StageMode ~= "Auto" then
		local wanted = normalizeName(S.StageMode)
		local wantedNumber = tonumber(tostring(S.StageMode):match("(%d+)"))
		for _, stage in ipairs(stages) do
			if normalizeName(stage.Name) == wanted or (wantedNumber and stageNumber(stage) == wantedNumber) then return stage end
		end
	end
	if S.AutoBestStage or S.StageMode == "Auto" then
		for i = #stages, 1, -1 do
			if isStageUsable(stages[i]) then return stages[i] end
		end
		return stages[#stages]
	end
	return nil
end

local function findStageWinPart(stage)
	if not stage then return nil end
	for _, name in ipairs({ "NormalWin", "Win", "Finish", "Checkpoint", "WinPlate", "Reward" }) do
		local obj = stage:FindFirstChild(name, true)
		if obj then
			local btn = obj:FindFirstChild("Button", true) or objectPart(obj)
			if btn and btn:IsA("BasePart") then return btn end
		end
	end
	for _, obj in ipairs(stage:GetDescendants()) do
		if obj:IsA("BasePart") then
			local n = normalizeName(obj.Name)
			if n == "win" or n == "finish" or n == "checkpoint" or n == "button" then return obj end
		end
	end
	return nil
end

local function findReturnPart(worldNumber)
	local world = getWorldObject(worldNumber)
	for _, root in ipairs({ world, Map, workspace }) do
		if root then
			for _, name in ipairs({ "Return", "ReturnButton", "ReturnToStart", "Back", "Spawn", "Start" }) do
				local obj = root:FindFirstChild(name, true)
				local part = objectPart(obj)
				if part then return part end
			end
		end
	end
	return nil
end

local function ensureWorld(worldNumber)
	local world = dataChild("World")
	if world and tonumber(world.Value) == worldNumber then return true end
	if fireRemote("TeleportWorld", worldNumber) or fireRemote("ChangeWorld", worldNumber) or fireRemote("WorldTeleport", worldNumber) then
		task.wait(0.7)
		return true
	end
	local target = getWorldObject(worldNumber)
	local part = objectPart(target)
	local root = hrp()
	if root and part then root.CFrame = part.CFrame + Vector3.new(0, 4, 0); return true end
	return false
end

local farmCycleCount = 0
local lastFarmCycleTime = 0
local adaptiveFarmDelay = S.FarmDelay
local lastSmartWins = nil

local function farmWinsAdvanced()
	local started = os.clock()
	local worldNumber = selectedWorldNumber()
	ensureWorld(worldNumber)
	local stages = getStages(worldNumber)
	if #stages == 0 then return end
	local targets = {}
	if S.StageMode ~= "Auto" or S.AutoBestStage then
		local chosen = findStageBySelection(worldNumber)
		if chosen then table.insert(targets, chosen) end
	else
		for _, stage in ipairs(stages) do if isStageUsable(stage) then table.insert(targets, stage) end end
	end
	local returnPart = findReturnPart(worldNumber)
	for _, stage in ipairs(targets) do
		local btn = findStageWinPart(stage)
		if btn then
			touchPart(btn)
			task.wait(math.max(0.04, adaptiveFarmDelay * 0.22))
			if returnPart then touchPart(returnPart); task.wait(0.04) end
		end
	end
	farmCycleCount += 1
	lastFarmCycleTime = os.clock() - started
end

local function treadmillMultiplier(obj)
	if not obj then return 0 end
	local best = scoreObject(obj)
	for _, attr in ipairs({ "Multiplier", "SpeedMultiplier", "Boost", "Speed" }) do
		local v = tonumber(obj:GetAttribute(attr))
		if v then best = math.max(best, v) end
	end
	local name = tostring(obj.Name)
	local x = tonumber(name:match("[xX]%s*(%d+%.?%d*)"))
	if x then best = math.max(best, x) end
	if string.find(normalizeName(name), "quantum", 1, true) then best += 100000 end
	return best
end

local function isTreadmillUsable(obj)
	if not obj then return false end
	if obj:GetAttribute("Locked") == true or obj:GetAttribute("Unlocked") == false then return false end
	local n = normalizeName(obj.Name)
	for _, bad in ipairs({ "robux", "gamepass", "viponly", "premiumonly" }) do if string.find(n, bad, 1, true) then return false end end
	for _, attr in ipairs({ "Robux", "RobuxPrice", "GamepassId", "PassId" }) do
		local v = tonumber(obj:GetAttribute(attr))
		if v and v > 0 then return false end
	end
	local req = tonumber(obj:GetAttribute("RebirthRequirement") or obj:GetAttribute("RebirthsRequired") or 0) or 0
	if getDataNumber("Rebirths") < req then return false end
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = normalizeName(d.Text)
			if string.find(t, "robux", 1, true) or string.find(t, "gamepass", 1, true) or string.find(t, "purchase", 1, true) then return false end
		end
	end
	return true
end

local function getTreadmills()
	local result, seen = {}, {}
	for _, root in ipairs({ Map, workspace }) do
		if root then
			for _, obj in ipairs(root:GetDescendants()) do
				local n = normalizeName(obj.Name)
				if string.find(n, "treadmill", 1, true) or string.find(n, "runningmachine", 1, true) or string.find(n, "belt", 1, true) then
					local candidate = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model") or obj
					if candidate and not seen[candidate] and objectPart(candidate) then seen[candidate] = true; table.insert(result, candidate) end
				end
			end
		end
	end
	table.sort(result, function(a, b) return treadmillMultiplier(a) < treadmillMultiplier(b) end)
	return result
end

local function selectedTreadmill()
	local mills = getTreadmills()
	if #mills == 0 then return nil end
	if S.TreadmillMode ~= "Auto" then
		local wanted = normalizeName(S.TreadmillMode)
		for _, mill in ipairs(mills) do if normalizeName(mill.Name) == wanted then return mill end end
	end
	for i = #mills, 1, -1 do if isTreadmillUsable(mills[i]) then return mills[i] end end
	return mills[#mills]
end

local function useTreadmill(mill)
	mill = mill or selectedTreadmill()
	local root, part = hrp(), objectPart(mill)
	if not root or not part then return false end
	root.CFrame = part.CFrame + Vector3.new(0, 3.2, 0)
	for _, obj in ipairs(mill:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and fireproximityprompt then pcall(fireproximityprompt, obj) end
		if obj:IsA("ClickDetector") and fireclickdetector then pcall(fireclickdetector, obj) end
	end
	touchPart(part)
	return true
end

local runPulse = false
local function runInPlacePulse()
	local h, root = humanoid(), hrp()
	if not h or not root then return end
	runPulse = not runPulse
	local direction = runPulse and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
	h:Move(direction, true)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.new(direction.X * 8, root.AssemblyLinearVelocity.Y, direction.Z * 8)
	end)
end

local function autoFarmSteps()
	local mill = selectedTreadmill()
	if mill and isTreadmillUsable(mill) then useTreadmill(mill) else runInPlacePulse() end
	for _, remoteName in ipairs({ "AddStep", "GainSpeed", "TrainSpeed", "AddSpeed" }) do fireRemote(remoteName) end
end

local function ownedContains(folderName, name)
	local owned = dataChild(folderName)
	if not owned then return false end
	if owned:FindFirstChild(tostring(name)) then return true end
	for _, obj in ipairs(owned:GetChildren()) do
		if normalizeName(obj.Name) == normalizeName(name) then return true end
		if tostring(obj.Value) == tostring(name) then return true end
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

local function buyCharms()
	local cfg = cfgModule("Charms") or cfgModule("Charm")
	if type(cfg) ~= "table" then return false end
	return pcall(function() buyFromConfig(cfg, "BuyCharm", "UnlockedCharms") end)
end

local function usePotionKind(kind)
	local potions = dataChild("Potions")
	if not potions then return end
	local wanted = normalizeName(kind)
	for _, pot in ipairs(potions:GetChildren()) do
		local n = normalizeName(pot.Name)
		if string.find(n, wanted, 1, true) then fireRemote("UsePotion", pot.Name) end
	end
end

local session = {
	startClock = os.clock(),
	startWins = getDataNumber("Wins"),
	startRebirths = getDataNumber("Rebirths"),
	startRaces = getDataNumber("RaceWins", "RacesWon", "Races"),
	collected = 0,
}

local function getCollectRadius()
	if S.CollectRadius >= 10000 then return math.huge end
	return math.max(1, S.CollectRadius)
end

local function collectMatchingNames(names)
	local root = hrp()
	if not root then return 0 end
	local wanted = {}
	for _, n in ipairs(names) do wanted[normalizeName(n)] = true end
	local radius = getCollectRadius()
	local candidates, seen = {}, {}
	for _, base in ipairs({ workspace, Map }) do
		if base then
			for _, obj in ipairs(base:GetDescendants()) do
				if obj:IsA("BasePart") then
					local namesToCheck = { normalizeName(obj.Name) }
					local ancestor = obj.Parent
					for _ = 1, 4 do
						if not ancestor then break end
						table.insert(namesToCheck, normalizeName(ancestor.Name)); ancestor = ancestor.Parent
					end
					local match = false
					for _, candidateName in ipairs(namesToCheck) do
						if wanted[candidateName] then match = true; break end
						for key in pairs(wanted) do
							local singular = key:gsub("s$", "")
							if string.find(candidateName, key, 1, true) or (singular ~= "" and string.find(candidateName, singular, 1, true)) then match = true; break end
						end
						if match then break end
					end
					if match and not seen[obj] then
						local dist = (obj.Position - root.Position).Magnitude
						if dist <= radius then seen[obj] = true; table.insert(candidates, { part = obj, distance = dist }) end
					end
				end
			end
		end
	end
	if S.CollectNearestFirst then table.sort(candidates, function(a, b) return a.distance < b.distance end) end
	for _, item in ipairs(candidates) do touchPart(item.part); session.collected += 1; task.wait(0.015) end
	return #candidates
end

local function collectChests()
	collectMatchingNames({ "SkullChest", "SkullChests", "Chest", "Chests", "TreasureChest" })
	for _, remoteName in ipairs({ "OpenSkullChest", "SpinSkullChest", "OpenChest", "SpinChest", "ClaimChest" }) do fireRemote(remoteName) end
end

local function collectSecretEvents()
	collectMatchingNames({ "SecretDoor", "EventDoor", "Quantum", "QuantumEvent", "EventPortal", "Secret", "Event" })
	for _, remoteName in ipairs({ "EnterSecretDoor", "EnterSecret", "JoinEvent", "EnterEvent", "RushQuantumEvent", "TeleportQuantum" }) do fireRemote(remoteName) end
end

local function teleportToObject(obj)
	local root, part = hrp(), objectPart(obj)
	if root and part then root.CFrame = part.CFrame + Vector3.new(0, 4, 0); return true end
	return false
end

local function teleportBestTreadmill()
	return teleportToObject(selectedTreadmill())
end

local function teleportStageSelection()
	local worldNumber = selectedWorldNumber()
	ensureWorld(worldNumber)
	return teleportToObject(findStageBySelection(worldNumber))
end

local function teleportSpawn()
	for _, name in ipairs({ "Return", "Spawn", "SpawnLocation", "Lobby", "Start" }) do
		local obj = workspace:FindFirstChild(name, true)
		if obj and teleportToObject(obj) then return true end
	end
	if LocalPlayer.RespawnLocation then return teleportToObject(LocalPlayer.RespawnLocation) end
	return false
end

local function manualBestUpgrade()
	pcall(buyUpgrades)
	local trails = cfgModule("Trails")
	if type(trails) == "table" then
		pcall(buyFromConfig, trails, "BuyTrail", "UnlockedTrails")
	else
		trails = cfgModule("Tails")
		if type(trails) == "table" then pcall(buyFromConfig, trails, "BuyTail", "UnlockedTails") end
	end
	local auras = cfgModule("Auras")
	if type(auras) == "table" then pcall(buyFromConfig, auras, "BuyAura", "UnlockedAuras") end
	pcall(buyCharms)
	task.wait(0.1)
	pcall(equipBestTrail); pcall(equipBestAura)
	fireRemote("EquipBestCharms", "Speed"); fireRemote("EquipBestCharms", "Wins")
end

local function currentLevel()
	return getDataNumber("Level", "Lvl", "PlayerLevel")
end

local function shouldRebirth()
	if S.RebirthMode == "Instant" then return true end
	return currentLevel() >= S.MinRebirthLevel
end

local lastSafeCFrame = nil
local function updateAntiFall()
	local root = hrp()
	if not root then return end
	if root.Position.Y < -25 then
		if lastSafeCFrame then root.CFrame = lastSafeCFrame + Vector3.new(0, 3, 0) else teleportSpawn() end
		root.AssemblyLinearVelocity = Vector3.zero
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	if hit and root.AssemblyLinearVelocity.Magnitude < 120 then lastSafeCFrame = root.CFrame end
end

local noclipOriginal = {}
local function applyNoclip(enabled)
	local c = LocalPlayer.Character
	if not c then return end
	for _, obj in ipairs(c:GetDescendants()) do
		if obj:IsA("BasePart") then
			if enabled then
				if noclipOriginal[obj] == nil then noclipOriginal[obj] = obj.CanCollide end
				obj.CanCollide = false
			elseif noclipOriginal[obj] ~= nil then
				obj.CanCollide = noclipOriginal[obj]
				noclipOriginal[obj] = nil
			end
		end
	end
end

local hazardOriginal = {}
local HAZARD_TERMS = GAME_INFO.KnownHazards
local godConnections = {}
local godSafeCFrame = nil
local godOriginalMaxHealth = nil
local godOriginalBreakJoints = nil
local godOriginalRequiresNeck = nil
local godForceField = nil

local function clearGodConnections()
	for _, c in ipairs(godConnections) do pcall(function() c:Disconnect() end) end
	table.clear(godConnections)
end

local function nameLooksHazardous(obj)
	local current = obj
	for _ = 1, 4 do
		if not current then break end
		local n = normalizeName(current.Name)
		for _, term in ipairs(HAZARD_TERMS) do if string.find(n, normalizeName(term), 1, true) then return true end end
		current = current.Parent
	end
	return false
end

local function neutralizeHazardPart(obj)
	local character = LocalPlayer.Character
	if not obj or not obj:IsA("BasePart") or (character and obj:IsDescendantOf(character)) or not nameLooksHazardous(obj) then return false end
	if not hazardOriginal[obj] then hazardOriginal[obj] = { touch = obj.CanTouch, collide = obj.CanCollide, query = obj.CanQuery } end
	pcall(function() obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false end)
	return true
end

local function applyIgnoreHazards(enabled)
	if not enabled then
		for part, state in pairs(hazardOriginal) do
			if part and part.Parent then pcall(function() part.CanTouch = state.touch; part.CanCollide = state.collide; if state.query ~= nil then part.CanQuery = state.query end end) end
			hazardOriginal[part] = nil
		end
		return
	end
	local root = hrp(); if not root then return end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and nameLooksHazardous(obj) and (obj.Position - root.Position).Magnitude < 900 then neutralizeHazardPart(obj) end
	end
end

local function rescueFromHazard()
	local root, h = hrp(), humanoid(); if not root or not h then return end
	if godSafeCFrame then root.CFrame = godSafeCFrame + Vector3.new(0, 3, 0) else teleportSpawn() end
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
		h.PlatformStand = false; h.Sit = false; h:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

local function refreshGodSafePosition()
	local root, h = hrp(), humanoid(); if not root or not h or h:GetState() == Enum.HumanoidStateType.Swimming then return end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { LocalPlayer.Character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params)
	if hit and not nameLooksHazardous(hit.Instance) and root.Position.Y > GAME_INFO.VoidY + 10 then godSafeCFrame = root.CFrame end
end

local function reinforceGodMode()
	if not S.GodMode then return end
	local h, root = humanoid(), hrp(); if not h or not root then return end
	pcall(function()
		h.BreakJointsOnDeath = false; h.RequiresNeck = false
		h:SetStateEnabled(Enum.HumanoidStateType.Dead, false); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		h.PlatformStand = false
		if h.MaxHealth < 1000000 then h.MaxHealth = 1000000 end
		if h.Health < h.MaxHealth then h.Health = h.MaxHealth end
	end)
	local state = h:GetState()
	if state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Dead or root.Position.Y < GAME_INFO.VoidY then rescueFromHazard() else refreshGodSafePosition() end
end

local function setGodMode(enabled)
	S.GodMode = enabled == true
	clearGodConnections()
	if not S.GodMode then
		if not S.IgnoreHazards then applyIgnoreHazards(false) end
		local h = humanoid()
		if h then pcall(function()
			h:SetStateEnabled(Enum.HumanoidStateType.Dead, true); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			if godOriginalBreakJoints ~= nil then h.BreakJointsOnDeath = godOriginalBreakJoints end
			if godOriginalRequiresNeck ~= nil then h.RequiresNeck = godOriginalRequiresNeck end
			if godOriginalMaxHealth and godOriginalMaxHealth > 0 then h.MaxHealth = godOriginalMaxHealth; h.Health = math.min(h.Health, h.MaxHealth) end
		end) end
		if godForceField then pcall(function() godForceField:Destroy() end); godForceField = nil end
		godSafeCFrame = nil
		return
	end
	installGameAntiDeathHook()
	local character, h = LocalPlayer.Character, humanoid(); if not character or not h then return end
	godOriginalMaxHealth = h.MaxHealth; godOriginalBreakJoints = h.BreakJointsOnDeath; godOriginalRequiresNeck = h.RequiresNeck
	godSafeCFrame = nil; refreshGodSafePosition()
	godForceField = Instance.new("ForceField"); godForceField.Name = "HEXA_GodMode"; godForceField.Visible = false; godForceField.Parent = character
	table.insert(godConnections, workspace.DescendantAdded:Connect(function(obj)
		if not S.GodMode then return end
		task.defer(function() if obj and obj.Parent and obj:IsA("BasePart") and nameLooksHazardous(obj) then neutralizeHazardPart(obj) end end)
	end))
	table.insert(godConnections, h.HealthChanged:Connect(function(health)
		if not S.GodMode then return end
		if health <= 1 then rescueFromHazard() end
		pcall(function() h.Health = h.MaxHealth end)
	end))
	table.insert(godConnections, h.StateChanged:Connect(function(_, newState)
		if S.GodMode and (newState == Enum.HumanoidStateType.Swimming or newState == Enum.HumanoidStateType.Dead or newState == Enum.HumanoidStateType.FallingDown) then task.defer(rescueFromHazard) end
	end))
	applyIgnoreHazards(true); reinforceGodMode()
end

local perfOriginal = {}
local function setPerformanceMode(enabled)
	if not enabled then
		for obj, old in pairs(perfOriginal) do
			if obj and obj.Parent then pcall(function() obj.Enabled = old end) end
			perfOriginal[obj] = nil
		end
		return
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			if perfOriginal[obj] == nil then perfOriginal[obj] = obj.Enabled end
			obj.Enabled = false
		end
	end
end

local function requestJson(url)
	local body = nil
	local req = (syn and syn.request) or http_request or request
	if req then
		local ok, response = pcall(req, { Url = url, Method = "GET" })
		if ok and response then body = response.Body or response.body end
	end
	if not body then
		pcall(function() body = game:HttpGet(url) end)
	end
	if not body then return nil end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
	return ok and decoded or nil
end

local TeleportService = game:GetService("TeleportService")
local function hopServer(lowOnly)
	local cursor = ""
	local best = nil
	for _ = 1, 3 do
		local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
		if cursor ~= "" then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
		local data = requestJson(url)
		if type(data) ~= "table" or type(data.data) ~= "table" then break end
		for _, server in ipairs(data.data) do
			if server.id ~= game.JobId and tonumber(server.playing) and tonumber(server.maxPlayers) and server.playing < server.maxPlayers then
				if not best or (lowOnly and server.playing < best.playing) then best = server end
				if not lowOnly then break end
			end
		end
		if best and not lowOnly then break end
		cursor = data.nextPageCursor or ""
		if cursor == "" then break end
	end
	if best then pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, best.id, LocalPlayer); return true end
	return false
end

local function rejoinCurrent()
	pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
end

local function panicStop()
	for _, key in ipairs(AUTO_KEYS) do S[key] = false end
	local root = hrp(); if root then root.Anchored = false end
	local h = humanoid(); if h then h:Move(Vector3.zero, false) end
	setGodMode(false); applyNoclip(false); applyIgnoreHazards(false); setPerformanceMode(false)
end

local function collectFromFolder(folderName)
	local map = {
		Bananas = { "Bananas", "Banana", "BananaNormal", "BananaRare" },
		Tacos = { "Tacos", "Taco" },
		LuckyBlocks = { "LuckyBlocks", "LuckyBlock", "Lucky Block" },
		HackerPortals = { "HackerPortals", "HackerPortal", "Hacker Portal" },
	}
	return collectMatchingNames(map[folderName] or { folderName })
end


local streakNames = { "SlimeTail", "FlowerTail", "SkullChest" }

-- ================= CEVRILER =================

local L = {
	en = {
		tabMain = "Farm", tabProgress = "Progress", tabTeleport = "Teleport", tabPlayer = "Player", tabRewards = "Rewards",
		secFarm = "Autofarm", secTraining = "Speed Training", secSelectors = "Farm Selectors", secPresets = "Presets",
		secBuy = "Auto Purchase & Equip", secRebirth = "Rebirth & Potions", secRace = "Race",
		secCollect = "Auto Collect", secTeleport = "Teleports", secMovement = "Movement & Protection", secSystem = "System",
		secStatus = "Live Farm Status", secSession = "Session Statistics",
		farmWins = "Auto Farm Wins", farmSteps = "Auto Farm Steps", stayStill = "Stay Still", farmSpeed = "Farm Delay (s)", smartDelay = "Smart Farm Delay",
		autoTreadmill = "Auto Best Treadmill", treadmillSelector = "Treadmill", runInPlace = "Auto Run In Place",
		worldSelector = "Farm World", stageSelector = "Stage", autoBestStage = "Auto Best Stage",
		buyTrail = "Auto Buy Trail", buyAura = "Auto Buy Aura", buyUpgrades = "Auto Buy Upgrades",
		equipTrail = "Auto Equip Best Trail", equipAura = "Auto Equip Best Aura", buyCharms = "Auto Buy Charms", bestNow = "Best Upgrade Now",
		rebirth = "Smart Auto Rebirth", rebirthMode = "Rebirth Mode", minRebirth = "Minimum Rebirth Level", bestWorld = "Auto Best World",
		speedPotion = "Auto Speed Potion", winsPotion = "Auto Wins Potion", charms = "Auto Equip Best Charms",
		joinRace = "Auto Join Race", winRace = "Auto Win Race", godMode = "God Mode",
		bananas = "Collect Bananas", tacos = "Collect Tacos", lucky = "Collect Lucky Blocks", portals = "Collect Hacker Portals",
		openChests = "Auto Open Chests", secretEvent = "Auto Secret / Event", collectRadius = "Collect Radius", nearestFirst = "Collect Nearest First",
		freeReward = "Auto Free Reward", offline = "Auto Offline Earnings", streak = "Auto Streak Rewards",
		tpTreadmill = "Teleport to Best Treadmill", tpStage = "Teleport to Selected Stage", tpSpawn = "Teleport to Return / Spawn",
		walkSpeed = "Custom WalkSpeed", walkSpeedValue = "WalkSpeed", infJump = "Infinite Jump", noclip = "Noclip", ignoreHazards = "Ignore Hazards",
		antiFall = "Anti Fall / Anti Void", autoRespawn = "Auto Respawn + Resume", antiAFK = "Anti AFK", autoRejoin = "Auto Rejoin on Disconnect",
		autoResume = "Auto Resume", performance = "Performance Mode", serverHop = "Server Hop", lowHop = "Low Server Hop", panic = "PANIC STOP — Disable All Autos",
		presetFull = "Preset: Full Auto", presetSpeed = "Preset: Farm Speed", presetProgress = "Preset: Progression",
		worldTeleportPrefix = "Teleport World ",
		statusWaiting = "Reading live data...", sessionWaiting = "Session started",
		loaded = "HEXA loaded",
		closeTitle = "Exit HEXA?", closeDesc = "If you close this panel, the hub will stop and you will need to execute the script again to reopen it.", cancelBtn = "Go Back", closeBtn = "Exit", closeTag = "CONFIRM",
		miniTitle = "SPEED MONKEY SCAPE", miniSub = "HEXA • minimized", restoreMini = "RESTORE", rebirthInstant = "As soon as possible", rebirthHold = "Wait for minimum level", allMap = "Entire map",
	},
	es = {
		tabMain = "Farm", tabProgress = "Progreso", tabTeleport = "Teletransporte", tabPlayer = "Jugador", tabRewards = "Recompensas",
		secFarm = "Autofarm", secTraining = "Entrenamiento de Velocidad", secSelectors = "Selectores de Farm", secPresets = "Presets",
		secBuy = "Compra y Equipado Automático", secRebirth = "Rebirth y Pociones", secRace = "Carreras",
		secCollect = "Recolección Automática", secTeleport = "Teletransportes", secMovement = "Movimiento y Protección", secSystem = "Sistema",
		secStatus = "Estado del Farm en Vivo", secSession = "Estadísticas de Sesión",
		farmWins = "Farmear Victorias Auto", farmSteps = "Farmear Pasos Auto", stayStill = "Quedarse Quieto", farmSpeed = "Retraso del Farm (s)", smartDelay = "Retraso Inteligente",
		autoTreadmill = "Mejor Treadmill Auto", treadmillSelector = "Treadmill", runInPlace = "Correr en el Sitio Auto",
		worldSelector = "Mundo de Farm", stageSelector = "Stage", autoBestStage = "Mejor Stage Auto",
		buyTrail = "Comprar Estelas Auto", buyAura = "Comprar Auras Auto", buyUpgrades = "Comprar Mejoras Auto",
		equipTrail = "Equipar Mejor Estela Auto", equipAura = "Equipar Mejor Aura Auto", buyCharms = "Comprar Charms Auto", bestNow = "Mejor Mejora Ahora",
		rebirth = "Rebirth Inteligente", rebirthMode = "Modo de Rebirth", minRebirth = "Nivel Mínimo para Rebirth", bestWorld = "Mejor Mundo Auto",
		speedPotion = "Poción de Velocidad Auto", winsPotion = "Poción de Victorias Auto", charms = "Equipar Mejores Charms Auto",
		joinRace = "Unirse a Carreras Auto", winRace = "Ganar Carreras Auto", godMode = "Modo Dios",
		bananas = "Recoger Plátanos", tacos = "Recoger Tacos", lucky = "Recoger Lucky Blocks", portals = "Recoger Hacker Portals",
		openChests = "Abrir Cofres Auto", secretEvent = "Secret / Event Auto", collectRadius = "Radio de Recolección", nearestFirst = "Recoger el Más Cercano Primero",
		freeReward = "Recompensa Gratis Auto", offline = "Ganancias Offline Auto", streak = "Recompensas de Racha Auto",
		tpTreadmill = "TP al Mejor Treadmill", tpStage = "TP al Stage Seleccionado", tpSpawn = "TP a Return / Spawn",
		walkSpeed = "WalkSpeed Personalizado", walkSpeedValue = "WalkSpeed", infJump = "Salto Infinito", noclip = "Noclip", ignoreHazards = "Ignorar Peligros",
		antiFall = "Anti Caída / Anti Void", autoRespawn = "Auto Respawn + Continuar", antiAFK = "Anti AFK", autoRejoin = "Auto Rejoin al Desconectarse",
		autoResume = "Auto Continuar", performance = "Modo Rendimiento", serverHop = "Cambiar de Servidor", lowHop = "Servidor con Poca Gente", panic = "PANIC STOP — Apagar Todos los Autos",
		presetFull = "Preset: Full Auto", presetSpeed = "Preset: Farm Speed", presetProgress = "Preset: Progression",
		worldTeleportPrefix = "Teletransportar Mundo ",
		statusWaiting = "Leyendo datos en vivo...", sessionWaiting = "Sesión iniciada",
		loaded = "HEXA cargado",
		closeTitle = "¿Salir de HEXA?", closeDesc = "Si cierras este panel, el hub se detendrá y tendrás que ejecutar el script otra vez para volver a abrirlo.", cancelBtn = "Volver", closeBtn = "Salir", closeTag = "CONFIRMAR",
		miniTitle = "SPEED MONKEY SCAPE", miniSub = "HEXA • minimizado", restoreMini = "ABRIR", rebirthInstant = "Apenas pueda", rebirthHold = "Esperar nivel mínimo", allMap = "Todo el mapa",
	},
}

-- ================= ANA DÖNGÜ =================

task.spawn(function()
	while hubRunning do
		local now = os.clock()

		if S.FarmWins and ready("farm", adaptiveFarmDelay, now) then
			if S.SmartFarmDelay then
				local currentWins = getDataNumber("Wins")
				if lastSmartWins ~= nil then
					if currentWins <= lastSmartWins then adaptiveFarmDelay = math.min(2, adaptiveFarmDelay + 0.05)
					else adaptiveFarmDelay = math.max(S.FarmDelay, adaptiveFarmDelay - 0.03) end
				end
				lastSmartWins = currentWins
			else
				adaptiveFarmDelay = S.FarmDelay
				lastSmartWins = nil
			end
			pcall(farmWinsAdvanced)
		end

		if S.FarmSteps and ready("steps", 0.75, now) then pcall(autoFarmSteps) end
		if S.AutoTreadmill and ready("treadmill", 1.5, now) then pcall(useTreadmill, selectedTreadmill()) end
		if S.RunInPlace and ready("runplace", 0.18, now) then pcall(runInPlacePulse) end

		if S.StayStill and not S.FarmWins then
			local root = hrp()
			if root and not root.Anchored then root.Anchored = true end
		else
			local root = hrp()
			if root and root.Anchored then root.Anchored = false end
		end

		if S.BuyTrail and ready("trail", 3, now) then
			local t = cfgModule("Trails")
			if type(t) == "table" then pcall(buyFromConfig, t, "BuyTrail", "UnlockedTrails")
			else t = cfgModule("Tails"); if type(t) == "table" then pcall(buyFromConfig, t, "BuyTail", "UnlockedTails") end end
		end
		if S.BuyAura and ready("aura", 3, now) then
			local a = cfgModule("Auras")
			if type(a) == "table" then pcall(buyFromConfig, a, "BuyAura", "UnlockedAuras") end
		end
		if S.BuyUpgrades and ready("upg", 3, now) then pcall(buyUpgrades) end
		if S.EquipBestTrail and ready("equiptrail", 4, now) then pcall(equipBestTrail) end
		if S.EquipBestAura and ready("equipaura", 4, now) then pcall(equipBestAura) end
		if S.BuyCharms and ready("buycharms", 4, now) then pcall(buyCharms) end

		if S.AutoRebirth and ready("rebirth", 3, now) and shouldRebirth() then
			pcall(function() fireRemote("Rebirth") end)
		end
		if S.BestWorld and ready("world", 5, now) then pcall(autoBestWorld) end

		if S.JoinRace and ready("joinrace", 2, now) and not LocalPlayer:GetAttribute("InRace") then
			pcall(function() fireRemote("JoinRace") end)
		end
		if S.WinRace and ready("winrace", 0.5, now) and LocalPlayer:GetAttribute("InRace") then
			local races = Map and Map:FindFirstChild("Races")
			local root = hrp()
			if races and root then
				local nearest, dist = nil, math.huge
				for _, r in ipairs(races:GetChildren()) do
					local fin = r:FindFirstChild("RaceFinish", true) or r:FindFirstChild("Finish", true)
					if fin and fin:IsA("BasePart") then
						local d = (fin.Position - root.Position).Magnitude
						if d < dist then dist, nearest = d, fin end
					end
				end
				if nearest then root.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 3, 0)); task.wait(0.05); touchPart(nearest) end
			end
		end

		if S.GodMode and ready("godmode", 0.08, now) then pcall(reinforceGodMode) end

		if S.Bananas and ready("ban", 1, now) then pcall(collectFromFolder, "Bananas") end
		if S.Tacos and ready("tac", 1, now) then pcall(collectFromFolder, "Tacos") end
		if S.LuckyBlocks and ready("lucky", 1, now) then pcall(collectFromFolder, "LuckyBlocks") end
		if S.HackerPortals and ready("portal", 1, now) then pcall(collectFromFolder, "HackerPortals") end
		if S.OpenChests and ready("chests", 2, now) then pcall(collectChests) end
		if S.AutoSecretEvent and ready("secret", 3, now) then pcall(collectSecretEvents) end

		if S.FreeReward and ready("free", 10, now) then pcall(function() fireRemote("ClaimFreeReward") end) end
		if S.OfflineEarnings and ready("offline", 15, now) then pcall(function() fireRemote("RequestOfflineEarnings"); fireRemote("ClaimOfflineEarnings") end) end
		if S.StreakRewards and ready("streak", 15, now) then
			local streakClaimed = dataChild("StreakClaimed")
			for _, name in ipairs(streakNames) do
				if not streakClaimed or not streakClaimed:FindFirstChild(name) then fireRemote("ClaimStreakReward", name) end
			end
		end
		if S.BestCharms and ready("charms", 15, now) then
			pcall(function() fireRemote("EquipBestCharms", "Speed"); fireRemote("EquipBestCharms", "Wins") end)
		end
		if S.SpeedPotion and ready("speedpot", 20, now) then pcall(usePotionKind, "speed") end
		if S.WinsPotion and ready("winspot", 20, now) then pcall(usePotionKind, "win") end

		if S.WalkSpeedEnabled then
			local h = humanoid()
			if h and h.WalkSpeed ~= S.WalkSpeedValue then h.WalkSpeed = S.WalkSpeedValue end
		end
		if S.Noclip then pcall(applyNoclip, true) elseif next(noclipOriginal) then pcall(applyNoclip, false) end
		if (S.IgnoreHazards or S.GodMode) and ready("hazards", 0.75, now) then pcall(applyIgnoreHazards, true) elseif not S.IgnoreHazards and not S.GodMode and next(hazardOriginal) then pcall(applyIgnoreHazards, false) end
		if S.AntiFall and ready("antifall", 0.15, now) then pcall(updateAntiFall) end
		if (S.AutoRespawn or S.GodMode) and ready("respawn", 1.25, now) then
			local h = humanoid()
			if not h or h.Health <= 0 then fireRemote("Respawn"); fireRemote("Spawn"); fireRemote("RequestRespawn") end
		end
		if S.PerformanceMode and ready("performance", 5, now) then pcall(setPerformanceMode, true) elseif not S.PerformanceMode and next(perfOriginal) then pcall(setPerformanceMode, false) end

		task.wait(0.05)
	end
end)


-- ================= PREMIUM CUSTOM UI =================
-- Full custom interface: no external UI library is required.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")

UserInputService.JumpRequest:Connect(function()
	if S.InfiniteJump then
		local h = humanoid()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

LocalPlayer.Idled:Connect(function()
	if S.AntiAFK then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end
end)

local rejoinDebounce = false
pcall(function()
	GuiService.ErrorMessageChanged:Connect(function(message)
		if S.AutoRejoin and not rejoinDebounce and tostring(message) ~= "" then
			rejoinDebounce = true
			task.delay(1, rejoinCurrent)
		end
	end)
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.8)
	if S.WalkSpeedEnabled then local h = humanoid(); if h then h.WalkSpeed = S.WalkSpeedValue end end
	if S.GodMode then pcall(setGodMode, true) end
	if S.Noclip then pcall(applyNoclip, true) end
	if S.IgnoreHazards or S.GodMode then pcall(applyIgnoreHazards, true) end
	if S.AutoResume then lastRun.farm = nil; lastRun.steps = nil; lastRun.treadmill = nil end
end)

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

	if key == "main" then
		-- Farm / treadmill
		makeIconPart(icon, UDim2.fromOffset(size - 3, 3), UDim2.fromOffset(1, size - 5), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, size - 7), UDim2.fromOffset(size - 5, 2), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 7, 2), UDim2.fromOffset(4, 3), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(5, 2), UDim2.fromOffset(3, 7), THEME.Muted, 2, -25)
	elseif key == "progress" then
		-- Progression / rising bars
		makeIconPart(icon, UDim2.fromOffset(3, 5), UDim2.fromOffset(2, size - 6), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, 9), UDim2.fromOffset(7, size - 10), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, 13), UDim2.fromOffset(12, size - 14), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(8, 2), UDim2.fromOffset(7, 3), THEME.Muted, 2, -28)
	elseif key == "teleport" then
		-- Teleport / target portal
		makeIconPart(icon, UDim2.fromOffset(size - 4, 3), UDim2.fromOffset(2, 2), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 4, 3), UDim2.fromOffset(2, size - 5), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, size - 4), UDim2.fromOffset(2, 2), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(3, size - 4), UDim2.fromOffset(size - 5, 2), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(5, 5), UDim2.fromOffset(math.floor(size/2)-2, math.floor(size/2)-2), THEME.Muted, 99, 0)
	elseif key == "player" then
		-- Player silhouette
		makeIconPart(icon, UDim2.fromOffset(7, 7), UDim2.fromOffset(math.floor(size/2)-3, 1), THEME.Muted, 99, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 5, 8), UDim2.fromOffset(2, 9), THEME.Muted, 5, 0)
	elseif key == "rewards" then
		-- Trophy
		makeIconPart(icon, UDim2.fromOffset(size - 10, size - 9), UDim2.fromOffset(5, 3), THEME.Muted, 3, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(2, 4), THEME.Muted, 3, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 6), UDim2.fromOffset(size - 6, 4), THEME.Muted, 3, 0)
		makeIconPart(icon, UDim2.fromOffset(4, 5), UDim2.fromOffset(math.floor(size / 2) - 2, size - 7), THEME.Muted, 2, 0)
		makeIconPart(icon, UDim2.fromOffset(size - 8, 3), UDim2.fromOffset(4, size - 3), THEME.Muted, 2, 0)
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

local LANGS = {
	{ code = "es", label = "Español" },
	{ code = "en", label = "English" },
}

local LANG_PREF_FILE = "hexa_language_pref.json"

local function loadRememberedLanguage()
	if not (readfile and isfile) then return nil end
	local ok, content = pcall(readfile, LANG_PREF_FILE)
	if not ok or not content or content == "" then return nil end
	local okData, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not okData or type(data) ~= "table" then return nil end
	local code = data.language
	if data.remember and (code == "es" or code == "en") then
		return code
	end
	return nil
end

local function saveRememberedLanguage(code)
	if not writefile then return end
	pcall(function()
		writefile(LANG_PREF_FILE, HttpService:JSONEncode({ remember = true, language = code }))
	end)
end

local function clearRememberedLanguage()
	if delfile and isfile and isfile(LANG_PREF_FILE) then
		pcall(delfile, LANG_PREF_FILE)
	end
end

local function createLanguageFlag(parent, code)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(46, 32)
	holder.Position = UDim2.new(0, 11, 0.5, -16)
	holder.BackgroundColor3 = THEME.Panel2
	holder.BorderSizePixel = 0
	holder.Parent = parent
	corner(holder, 8)
	local clip = Instance.new("Frame")
	clip.Size = UDim2.new(1, -2, 1, -2)
	clip.Position = UDim2.fromOffset(1, 1)
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Parent = holder
	corner(clip, 7)

	if code == "es" then
		local top = Instance.new("Frame")
		top.Size = UDim2.new(1, 0, 0.26, 0)
		top.BackgroundColor3 = Color3.fromRGB(188, 38, 38)
		top.BorderSizePixel = 0
		top.Parent = clip

		local middle = Instance.new("Frame")
		middle.Position = UDim2.new(0, 0, 0.26, 0)
		middle.Size = UDim2.new(1, 0, 0.48, 0)
		middle.BackgroundColor3 = Color3.fromRGB(241, 195, 54)
		middle.BorderSizePixel = 0
		middle.Parent = clip

		local bottom = Instance.new("Frame")
		bottom.AnchorPoint = Vector2.new(0, 1)
		bottom.Position = UDim2.new(0, 0, 1, 0)
		bottom.Size = UDim2.new(1, 0, 0.26, 0)
		bottom.BackgroundColor3 = Color3.fromRGB(188, 38, 38)
		bottom.BorderSizePixel = 0
		bottom.Parent = clip
	else
		clip.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
		local stripeCount = 7
		for i = 0, stripeCount - 1 do
			local stripe = Instance.new("Frame")
			stripe.Position = UDim2.new(0, 0, i / stripeCount, 0)
			stripe.Size = UDim2.new(1, 0, 1 / stripeCount, 1)
			stripe.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(182, 44, 44) or Color3.fromRGB(245, 245, 245)
			stripe.BorderSizePixel = 0
			stripe.Parent = clip
		end
		local canton = Instance.new("Frame")
		canton.Size = UDim2.new(0.46, 0, 0.58, 0)
		canton.BackgroundColor3 = Color3.fromRGB(36, 59, 123)
		canton.BorderSizePixel = 0
		canton.Parent = clip
	end

	stroke(holder, THEME.Line, 0.35, 1)
	return holder
end

local function showLanguagePicker(onSelect)
	local remembered = loadRememberedLanguage()
	if remembered then
		onSelect(remembered)
		return
	end

	destroyOldGui("HexaLanguagePremium")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HexaLanguagePremium"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2147483647
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	pcall(function() gui.OnTopOfCoreBlur = true end)
	parentGui(gui)

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = THEME.Black
	dim.BackgroundTransparency = 0.16
	dim.BorderSizePixel = 0
	dim.Parent = gui

	for i = 1, 3 do
		local band = Instance.new("Frame")
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.25 + (i - 1) * 0.25)
		band.Size = UDim2.new(1.35, 0, 0, 1)
		band.Rotation = -7
		band.BackgroundColor3 = THEME.Brown
		band.BackgroundTransparency = 0.76 + (i - 1) * 0.06
		band.BorderSizePixel = 0
		band.Parent = dim
	end

	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(900, 600)
	local compact = vp.X < 620
	local pickerW = math.min(compact and 360 or 430, math.max(290, vp.X - 28))
	local pickerH = math.min(compact and 340 or 320, math.max(280, vp.Y - 60))
	local rememberValue = false

	local shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 10)
	shadow.Size = UDim2.fromOffset(pickerW + 12, pickerH + 12)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.38
	shadow.BorderSizePixel = 0
	shadow.Parent = dim
	shadow.Visible = false
	corner(shadow, 24)

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(pickerW, pickerH)
	frame.BackgroundColor3 = THEME.Panel
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = dim
	corner(frame, 22)
	neonStroke(frame, THEME.BrownNeon, 0.20, 1.4)

	local brand = makeLabel(frame, "HEXA", compact and 24 or 28, THEME.White, Enum.Font.GothamBold)
	brand.Position = UDim2.fromOffset(24, 18)
	brand.Size = UDim2.new(1, -48, 0, 34)

	local sub = makeLabel(frame, "ENGLISH / ESPAÑOL", compact and 10 or 11, THEME.Brown3, Enum.Font.GothamMedium)
	sub.Position = UDim2.fromOffset(24, 48)
	sub.Size = UDim2.new(1, -48, 0, 20)

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(24, 78)
	divider.Size = UDim2.new(1, -48, 0, 1)
	divider.BackgroundColor3 = THEME.Line
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local choose = makeLabel(frame, "SELECT LANGUAGE / SELECCIONA IDIOMA", compact and 11 or 12, THEME.Muted, Enum.Font.GothamBold)
	choose.Position = UDim2.fromOffset(24, 90)
	choose.Size = UDim2.new(1, -48, 0, 22)

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
	rememberCard.BackgroundColor3 = THEME.Card
	rememberCard.BorderSizePixel = 0
	rememberCard.Parent = frame
	corner(rememberCard, 14)
	stroke(rememberCard, THEME.Line, 0.52, 0.8)

	local rememberText = makeLabel(rememberCard, "Remember / Recordar", compact and 11 or 12, THEME.White, Enum.Font.GothamMedium)
	rememberText.Position = UDim2.fromOffset(14, 0)
	rememberText.Size = UDim2.new(1, -88, 1, 0)

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Position = UDim2.new(1, -12, 0.5, 0)
	toggle.Size = UDim2.fromOffset(50, 26)
	toggle.BackgroundColor3 = THEME.Panel2
	toggle.BorderSizePixel = 0
	toggle.Text = ""
	toggle.AutoButtonColor = false
	toggle.Parent = rememberCard
	corner(toggle, 99)
	stroke(toggle, THEME.Line, 0.56, 0.8)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = THEME.White
	knob.BorderSizePixel = 0
	knob.Parent = toggle
	corner(knob, 99)

	local function refreshRememberToggle()
		tween(toggle, 0.15, { BackgroundColor3 = rememberValue and THEME.Brown or THEME.Panel2 })
		tween(knob, 0.15, { Position = rememberValue and UDim2.fromOffset(27, 3) or UDim2.fromOffset(3, 3) })
	end
	refreshRememberToggle()
	toggle.MouseButton1Click:Connect(function()
		rememberValue = not rememberValue
		refreshRememberToggle()
	end)

	for i, lang in ipairs(LANGS) do
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = i
		btn.Size = UDim2.new(1, 0, 0, compact and 50 or 54)
		btn.BackgroundColor3 = THEME.Card
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = list
		corner(btn, 14)
		local st = stroke(btn, THEME.Line, 0.54, 0.8)

		createLanguageFlag(btn, lang.code)

		local label = makeLabel(btn, lang.label, compact and 14 or 15, THEME.White, Enum.Font.GothamMedium)
		label.Position = UDim2.fromOffset(68, 0)
		label.Size = UDim2.new(1, -82, 1, 0)

		btn.MouseEnter:Connect(function()
			tween(btn, 0.15, { BackgroundColor3 = THEME.CardHover })
			st.Color = THEME.Brown2
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.15, { BackgroundColor3 = THEME.Card })
			st.Color = THEME.Line
		end)
		btn.MouseButton1Click:Connect(function()
			if rememberValue then
				saveRememberedLanguage(lang.code)
			else
				clearRememberedLanguage()
			end
			tween(frame, 0.15, { BackgroundTransparency = 1 })
			task.delay(0.12, function()
				if gui then gui:Destroy() end
				onSelect(lang.code)
			end)
		end)
	end
end

local function buildUI(T, languageCode)
	destroyOldGui("HexaPremiumHub")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HexaPremiumHub"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2147483647
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	pcall(function() gui.OnTopOfCoreBlur = true end)
	parentGui(gui)

	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1000, 700)
	local compact = vp.X < 760
	local windowW = compact and math.floor(math.min(340, math.max(300, vp.X - 22))) or math.floor(math.min(700, math.max(590, vp.X - 170)))
	local windowH = compact and math.floor(math.min(500, math.max(400, vp.Y - 40))) or math.floor(math.min(470, math.max(400, vp.Y - 130)))
	local sideW = compact and math.max(104, math.floor(windowW * 0.31)) or 168
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

	local navHolder = Instance.new("Frame")
	navHolder.BackgroundTransparency = 1
	navHolder.Position = UDim2.fromOffset(compact and 8 or 12, 46)
	navHolder.Size = UDim2.new(1, -(compact and 16 or 24), 0, compact and 214 or 270)
	navHolder.Parent = side

	local navLayout = Instance.new("UIListLayout")
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Padding = UDim.new(0, compact and 5 or 7)
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
	local toggleSetters = {}
	local activeDropdown = nil

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

		local t = makeLabel(titleRow, string.upper(titleText), compact and 10 or 11, THEME.Muted, Enum.Font.GothamBold)
		t.Position = UDim2.fromOffset(17, 0)
		t.Size = UDim2.new(1, -17, 1, 0)

		return section
	end

	local function createToggle(section, titleText, initial, callback, stateKey)
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
		local function setState(value, animated, invoke)
			state = value == true
			render(animated ~= false)
			if invoke ~= false then pcall(callback, state) end
		end
		row.MouseButton1Click:Connect(function() setState(not state, true, true) end)
		if stateKey then toggleSetters[stateKey] = setState end
		return row, setState
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
		row.MouseButton1Click:Connect(function() task.spawn(callback) end)
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

		local function formatSliderValue(v)
			if step >= 1 then return tostring(math.floor(v + 0.5)) end
			return string.format("%.2f", v)
		end
		local valueLabel = makeLabel(valueBox, formatSliderValue(defaultValue), compact and 9 or 10, THEME.Brown3, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
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
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
			valueLabel.Text = formatSliderValue(current)
			pcall(callback, current)
		end

		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
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
			end
		end)
		return row
	end

	local function createDropdown(section, titleText, currentValue, optionsProvider, callback)
		local row = Instance.new("TextButton")
		row.BackgroundColor3 = THEME.Card
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, compact and 50 or 54)
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = section
		corner(row, 10)
		stroke(row, THEME.Line, 0.70, 0.8)

		local label = makeLabel(row, titleText, compact and 10 or 11, THEME.White, Enum.Font.GothamMedium)
		label.Position = UDim2.fromOffset(compact and 12 or 14, 0)
		label.Size = UDim2.new(0.56, -10, 1, 0)
		label.TextTruncate = Enum.TextTruncate.AtEnd

		local valueLabel = makeLabel(row, tostring(currentValue), compact and 9 or 10, THEME.Brown3, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
		valueLabel.AnchorPoint = Vector2.new(1, 0)
		valueLabel.Position = UDim2.new(1, -(compact and 28 or 32), 0, 0)
		valueLabel.Size = UDim2.new(0.44, -8, 1, 0)
		valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local arrow = makeLabel(row, "⌄", compact and 13 or 14, THEME.Muted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		arrow.AnchorPoint = Vector2.new(1, 0)
		arrow.Position = UDim2.new(1, -6, 0, 0)
		arrow.Size = UDim2.fromOffset(22, compact and 50 or 54)

		local current = tostring(currentValue)
		row.MouseButton1Click:Connect(function()
			if activeDropdown and activeDropdown.Parent then activeDropdown:Destroy(); activeDropdown = nil end
			local options = type(optionsProvider) == "function" and optionsProvider() or optionsProvider
			if type(options) ~= "table" or #options == 0 then return end
			local popupGui = Instance.new("ScreenGui")
			popupGui.Name = "HexaDropdown"
			popupGui.ResetOnSpawn = false
			popupGui.IgnoreGuiInset = true
			popupGui.DisplayOrder = 2147483647
			popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
			parentGui(popupGui)
			activeDropdown = popupGui

			local maxVisible = math.min(#options, 7)
			local itemH = compact and 35 or 38
			local pop = Instance.new("ScrollingFrame")
			pop.BackgroundColor3 = THEME.Black2
			pop.BorderSizePixel = 0
			pop.ScrollBarThickness = 3
			pop.ScrollBarImageColor3 = THEME.Brown2
			pop.Size = UDim2.fromOffset(math.max(170, row.AbsoluteSize.X), maxVisible * itemH + 10)
			local px = row.AbsolutePosition.X
			local py = row.AbsolutePosition.Y + row.AbsoluteSize.Y + 4
			local cam = workspace.CurrentCamera
			local viewY = cam and cam.ViewportSize.Y or 720
			if py + pop.Size.Y.Offset > viewY - 8 then py = math.max(8, row.AbsolutePosition.Y - pop.Size.Y.Offset - 4) end
			pop.Position = UDim2.fromOffset(px, py)
			pop.CanvasSize = UDim2.fromOffset(0, #options * itemH + 10)
			pop.ZIndex = 200
			pop.Parent = popupGui
			corner(pop, 12); neonStroke(pop, THEME.BrownNeon, 0.25, 0.8); padding(pop, 5, 5, 5, 5)
			local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 4); layout.Parent = pop
			for _, option in ipairs(options) do
				local opt = Instance.new("TextButton")
				opt.Size = UDim2.new(1, -5, 0, itemH - 4)
				opt.BackgroundColor3 = tostring(option) == current and THEME.Brown or THEME.Card
				opt.BorderSizePixel = 0
				opt.Text = tostring(option)
				opt.TextColor3 = THEME.White
				opt.TextSize = compact and 9 or 10
				opt.Font = Enum.Font.GothamMedium
				opt.ZIndex = 201
				opt.Parent = pop
				corner(opt, 8)
				opt.MouseButton1Click:Connect(function()
					current = tostring(option); valueLabel.Text = current
					pcall(callback, current)
					if activeDropdown then activeDropdown:Destroy(); activeDropdown = nil end
				end)
			end
		end)
		return row, function(value)
			current = tostring(value); valueLabel.Text = current; pcall(callback, current)
		end
	end

	local function createInfoBlock(section, initialText)
		local box = Instance.new("Frame")
		box.BackgroundColor3 = THEME.Card
		box.BorderSizePixel = 0
		box.Size = UDim2.new(1, 0, 0, compact and 104 or 112)
		box.Parent = section
		corner(box, 10); stroke(box, THEME.Line, 0.70, 0.8)
		local label = makeLabel(box, initialText or "", compact and 9 or 10, THEME.White, Enum.Font.Code)
		label.Position = UDim2.fromOffset(12, 8)
		label.Size = UDim2.new(1, -24, 1, -16)
		label.TextWrapped = true; label.TextYAlignment = Enum.TextYAlignment.Top
		return label
	end

	local function setToggleKey(key, value, animated)
		local setter = toggleSetters[key]
		if setter then setter(value, animated ~= false, true) else S[key] = value == true end
	end

	local function applyPreset(kind)
		local desired = {}
		if kind == "full" then
			desired = { FarmWins=true, SmartFarmDelay=true, BuyTrail=true, BuyAura=true, BuyUpgrades=true, EquipBestTrail=true, EquipBestAura=true, BuyCharms=true, AutoRebirth=true, BestWorld=true, FreeReward=true, OfflineEarnings=true, StreakRewards=true, BestCharms=true, SpeedPotion=true, WinsPotion=true, OpenChests=true, AutoSecretEvent=true, AutoResume=true, AntiFall=true, IgnoreHazards=true }
		elseif kind == "speed" then
			desired = { FarmSteps=true, AutoTreadmill=true, RunInPlace=true, SpeedPotion=true, AutoResume=true, AntiFall=true }
		else
			desired = { FarmWins=true, SmartFarmDelay=true, BuyTrail=true, BuyAura=true, BuyUpgrades=true, EquipBestTrail=true, EquipBestAura=true, BuyCharms=true, AutoRebirth=true, BestWorld=true, BestCharms=true, FreeReward=true, OfflineEarnings=true, StreakRewards=true, AutoResume=true }
		end
		for key, value in pairs(desired) do setToggleKey(key, value, true) end
	end

	local function worldOptions()
		local out = { "Auto" }
		local worlds = getWorldObjects()
		if #worlds > 0 then for _, info in ipairs(worlds) do table.insert(out, "World " .. tostring(info.number)) end
		else for i = 1, GAME_INFO.WorldCount do table.insert(out, "World " .. i) end end
		return out
	end
	local function stageOptions()
		local out = { "Auto" }
		local stages = getStages(selectedWorldNumber())
		if #stages > 0 then for _, stage in ipairs(stages) do table.insert(out, stage.Name) end
		else for i = 1, GAME_INFO.StageCount do table.insert(out, "Stage " .. i) end end
		return out
	end
	local function treadmillOptions()
		local out = { "Auto" }
		for _, mill in ipairs(getTreadmills()) do table.insert(out, mill.Name) end
		return out
	end

	local farmPage = createPage("main", T.tabMain)
	local progressPage = createPage("progress", T.tabProgress)
	local teleportPage = createPage("teleport", T.tabTeleport)
	local playerPage = createPage("player", T.tabPlayer)
	local rewardPage = createPage("rewards", T.tabRewards)

	local farmSec = createSection(farmPage, T.secFarm)
	createToggle(farmSec, T.farmWins, S.FarmWins, function(v) S.FarmWins = v end, "FarmWins")
	createToggle(farmSec, T.farmSteps, S.FarmSteps, function(v) S.FarmSteps = v end, "FarmSteps")
	createToggle(farmSec, T.stayStill, S.StayStill, function(v) S.StayStill = v; if not v then local root = hrp(); if root then root.Anchored = false end end end, "StayStill")
	createToggle(farmSec, T.smartDelay, S.SmartFarmDelay, function(v) S.SmartFarmDelay = v end, "SmartFarmDelay")
	createSlider(farmSec, T.farmSpeed, 0.05, 2, S.FarmDelay, 0.05, function(v) S.FarmDelay = v; adaptiveFarmDelay = v end)

	local trainingSec = createSection(farmPage, T.secTraining)
	createToggle(trainingSec, T.autoTreadmill, S.AutoTreadmill, function(v) S.AutoTreadmill = v end, "AutoTreadmill")
	createDropdown(trainingSec, T.treadmillSelector, S.TreadmillMode, treadmillOptions, function(v) S.TreadmillMode = v end)
	createToggle(trainingSec, T.runInPlace, S.RunInPlace, function(v) S.RunInPlace = v end, "RunInPlace")

	local selectorSec = createSection(farmPage, T.secSelectors)
	createDropdown(selectorSec, T.worldSelector, S.FarmWorldMode, worldOptions, function(v) S.FarmWorldMode = v end)
	createDropdown(selectorSec, T.stageSelector, S.StageMode, stageOptions, function(v) S.StageMode = v end)
	createToggle(selectorSec, T.autoBestStage, S.AutoBestStage, function(v) S.AutoBestStage = v end, "AutoBestStage")

	local presetSec = createSection(farmPage, T.secPresets)
	createButton(presetSec, T.presetFull, function() applyPreset("full") end)
	createButton(presetSec, T.presetSpeed, function() applyPreset("speed") end)
	createButton(presetSec, T.presetProgress, function() applyPreset("progress") end)

	local buySec = createSection(progressPage, T.secBuy)
	createToggle(buySec, T.buyTrail, S.BuyTrail, function(v) S.BuyTrail = v end, "BuyTrail")
	createToggle(buySec, T.buyAura, S.BuyAura, function(v) S.BuyAura = v end, "BuyAura")
	createToggle(buySec, T.buyUpgrades, S.BuyUpgrades, function(v) S.BuyUpgrades = v end, "BuyUpgrades")
	createToggle(buySec, T.equipTrail, S.EquipBestTrail, function(v) S.EquipBestTrail = v end, "EquipBestTrail")
	createToggle(buySec, T.equipAura, S.EquipBestAura, function(v) S.EquipBestAura = v end, "EquipBestAura")
	createToggle(buySec, T.buyCharms, S.BuyCharms, function(v) S.BuyCharms = v end, "BuyCharms")
	createButton(buySec, T.bestNow, manualBestUpgrade)

	local rebirthSec = createSection(progressPage, T.secRebirth)
	createToggle(rebirthSec, T.rebirth, S.AutoRebirth, function(v) S.AutoRebirth = v end, "AutoRebirth")
	createDropdown(rebirthSec, T.rebirthMode, T.rebirthInstant, { T.rebirthInstant, T.rebirthHold }, function(v) S.RebirthMode = (v == T.rebirthInstant) and "Instant" or "Minimum" end)
	createSlider(rebirthSec, T.minRebirth, 1, 500, S.MinRebirthLevel, 1, function(v) S.MinRebirthLevel = math.floor(v) end)
	createToggle(rebirthSec, T.bestWorld, S.BestWorld, function(v) S.BestWorld = v end, "BestWorld")
	createToggle(rebirthSec, T.speedPotion, S.SpeedPotion, function(v) S.SpeedPotion = v end, "SpeedPotion")
	createToggle(rebirthSec, T.winsPotion, S.WinsPotion, function(v) S.WinsPotion = v end, "WinsPotion")
	createToggle(rebirthSec, T.charms, S.BestCharms, function(v) S.BestCharms = v end, "BestCharms")

	local raceSec = createSection(progressPage, T.secRace)
	createToggle(raceSec, T.joinRace, S.JoinRace, function(v) S.JoinRace = v end, "JoinRace")
	createToggle(raceSec, T.winRace, S.WinRace, function(v) S.WinRace = v end, "WinRace")

	local tpSec = createSection(teleportPage, T.secTeleport)
	createButton(tpSec, T.tpTreadmill, teleportBestTreadmill)
	createDropdown(tpSec, T.stageSelector, S.StageMode, stageOptions, function(v) S.StageMode = v end)
	createButton(tpSec, T.tpStage, teleportStageSelection)
	createButton(tpSec, T.tpSpawn, teleportSpawn)
	local maxWorldButton = GAME_INFO.WorldCount
	for _, info in ipairs(getWorldObjects()) do maxWorldButton = math.max(maxWorldButton, info.number) end
	for i = 1, maxWorldButton do
		local worldNumber = i
		createButton(tpSec, T.worldTeleportPrefix .. tostring(worldNumber), function() ensureWorld(worldNumber) end)
	end

	local moveSec = createSection(playerPage, T.secMovement)
	createToggle(moveSec, T.walkSpeed, S.WalkSpeedEnabled, function(v) S.WalkSpeedEnabled = v end, "WalkSpeedEnabled")
	createSlider(moveSec, T.walkSpeedValue, 0, 500, S.WalkSpeedValue, 1, function(v) S.WalkSpeedValue = math.floor(v) end)
	createToggle(moveSec, T.infJump, S.InfiniteJump, function(v) S.InfiniteJump = v end, "InfiniteJump")
	createToggle(moveSec, T.noclip, S.Noclip, function(v) S.Noclip = v; pcall(applyNoclip, v) end, "Noclip")
	createToggle(moveSec, T.ignoreHazards, S.IgnoreHazards, function(v) S.IgnoreHazards = v; if not v and not S.GodMode then pcall(applyIgnoreHazards, false) else pcall(applyIgnoreHazards, true) end end, "IgnoreHazards")
	createToggle(moveSec, T.antiFall, S.AntiFall, function(v) S.AntiFall = v end, "AntiFall")
	createToggle(moveSec, T.godMode, S.GodMode, function(v) setGodMode(v) end, "GodMode")

	local systemSec = createSection(playerPage, T.secSystem)
	createToggle(systemSec, T.autoRespawn, S.AutoRespawn, function(v) S.AutoRespawn = v end, "AutoRespawn")
	createToggle(systemSec, T.antiAFK, S.AntiAFK, function(v) S.AntiAFK = v end, "AntiAFK")
	createToggle(systemSec, T.autoRejoin, S.AutoRejoin, function(v) S.AutoRejoin = v end, "AutoRejoin")
	createToggle(systemSec, T.autoResume, S.AutoResume, function(v) S.AutoResume = v end, "AutoResume")
	createToggle(systemSec, T.performance, S.PerformanceMode, function(v) S.PerformanceMode = v; pcall(setPerformanceMode, v) end, "PerformanceMode")
	createButton(systemSec, T.serverHop, function() hopServer(false) end)
	createButton(systemSec, T.lowHop, function() hopServer(true) end)
	createButton(systemSec, T.panic, function()
		panicStop()
		for _, key in ipairs(AUTO_KEYS) do local setter = toggleSetters[key]; if setter then setter(false, true, false) end end
	end)

	local statusSec = createSection(playerPage, T.secStatus)
	local statusLabel = createInfoBlock(statusSec, T.statusWaiting)
	local sessionSec = createSection(playerPage, T.secSession)
	local sessionLabel = createInfoBlock(sessionSec, T.sessionWaiting)

	local collectSec = createSection(rewardPage, T.secCollect)
	createToggle(collectSec, T.bananas, S.Bananas, function(v) S.Bananas = v end, "Bananas")
	createToggle(collectSec, T.tacos, S.Tacos, function(v) S.Tacos = v end, "Tacos")
	createToggle(collectSec, T.lucky, S.LuckyBlocks, function(v) S.LuckyBlocks = v end, "LuckyBlocks")
	createToggle(collectSec, T.portals, S.HackerPortals, function(v) S.HackerPortals = v end, "HackerPortals")
	createToggle(collectSec, T.openChests, S.OpenChests, function(v) S.OpenChests = v end, "OpenChests")
	createToggle(collectSec, T.secretEvent, S.AutoSecretEvent, function(v) S.AutoSecretEvent = v end, "AutoSecretEvent")
	createDropdown(collectSec, T.collectRadius, tostring(S.CollectRadius), { "50", "100", "250", "500", T.allMap }, function(v) S.CollectRadius = (v == T.allMap) and 10000 or (tonumber(v) or 250) end)
	createToggle(collectSec, T.nearestFirst, S.CollectNearestFirst, function(v) S.CollectNearestFirst = v end, "CollectNearestFirst")

	local rewardSec = createSection(rewardPage, T.tabRewards)
	createToggle(rewardSec, T.freeReward, S.FreeReward, function(v) S.FreeReward = v end, "FreeReward")
	createToggle(rewardSec, T.offline, S.OfflineEarnings, function(v) S.OfflineEarnings = v end, "OfflineEarnings")
	createToggle(rewardSec, T.streak, S.StreakRewards, function(v) S.StreakRewards = v end, "StreakRewards")

	task.spawn(function()
		while gui.Parent and hubRunning do
			local elapsed = math.max(1, os.clock() - session.startClock)
			local wins = getDataNumber("Wins")
			local rebirths = getDataNumber("Rebirths")
			local races = getDataNumber("RaceWins", "RacesWon", "Races")
			local speed = getDataNumber("Speed", "Steps", "CurrentSpeed")
			if speed == 0 then local h = humanoid(); speed = h and h.WalkSpeed or 0 end
			local winsGain = math.max(0, wins - session.startWins)
			local winsPerHour = math.floor((winsGain / elapsed) * 3600)
			local worldObj = dataChild("World")
			local currentWorld = worldObj and tostring(worldObj.Value) or tostring(selectedWorldNumber())
			if languageCode == "es" then
				statusLabel.Text = string.format("Wins/h: %s\nVelocidad: %s\nMundo: %s   Stage: %s\nRebirths: %s   Ciclo: %.2fs", tostring(winsPerHour), tostring(math.floor(speed)), currentWorld, S.StageMode, tostring(math.floor(rebirths)), lastFarmCycleTime)
				sessionLabel.Text = string.format("Wins ganadas: %s\nRebirths: %s   Carreras: %s\nObjetos recogidos: %s\nCiclos: %s   Tiempo: %02d:%02d:%02d", tostring(math.floor(winsGain)), tostring(math.max(0, math.floor(rebirths - session.startRebirths))), tostring(math.max(0, math.floor(races - session.startRaces))), tostring(session.collected), tostring(farmCycleCount), math.floor(elapsed/3600), math.floor(elapsed/60)%60, math.floor(elapsed)%60)
			else
				statusLabel.Text = string.format("Wins/h: %s\nSpeed: %s\nWorld: %s   Stage: %s\nRebirths: %s   Cycle: %.2fs", tostring(winsPerHour), tostring(math.floor(speed)), currentWorld, S.StageMode, tostring(math.floor(rebirths)), lastFarmCycleTime)
				sessionLabel.Text = string.format("Wins gained: %s\nRebirths: %s   Races: %s\nItems collected: %s\nCycles: %s   Time: %02d:%02d:%02d", tostring(math.floor(winsGain)), tostring(math.max(0, math.floor(rebirths - session.startRebirths))), tostring(math.max(0, math.floor(races - session.startRaces))), tostring(session.collected), tostring(farmCycleCount), math.floor(elapsed/3600), math.floor(elapsed/60)%60, math.floor(elapsed)%60)
			end
			task.wait(0.5)
		end
	end)

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
			if activeDropdown and activeDropdown.Parent then activeDropdown:Destroy(); activeDropdown = nil end
			for k, pg in pairs(pages) do pg.Visible = k == key end
			for k, data in pairs(navButtons) do
				setNavButtonState(data, k == key, false)
			end
			currentPage = key
		end)
		navButtons[key] = { button = b, icon = icon, stroke = navStroke, fill = fill, glow = glow, innerShade = innerShade }
		return b
	end

	createNavButton("main", T.tabMain, 1)
	createNavButton("progress", T.tabProgress, 2)
	createNavButton("teleport", T.tabTeleport, 3)
	createNavButton("player", T.tabPlayer, 4)
	createNavButton("rewards", T.tabRewards, 5)

	-- Activate first page without relying on a synthetic button click.
	pages.main.Visible = true
	currentPage = "main"
	do
		local data = navButtons.main
		setNavButtonState(data, true, true)
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
	mini.Size = UDim2.fromOffset(compact and 228 or 282, compact and 58 or 64)
	mini.BackgroundColor3 = THEME.Black2
	mini.BorderSizePixel = 0
	mini.Visible = false
	mini.ZIndex = 150
	mini.Active = true
	mini.Parent = gui
	corner(mini, 15); neonStroke(mini, THEME.BrownNeon, 0.18, 0.8); gradient(mini, THEME.Black2, THEME.Panel2, 0)

	local restore = Instance.new("TextButton")
	restore.Name = "Restore"
	restore.Position = UDim2.fromOffset(7, 7)
	restore.Size = UDim2.fromOffset(compact and 48 or 58, compact and 44 or 50)
	restore.BackgroundColor3 = THEME.Brown
	restore.BorderSizePixel = 0
	restore.Text = compact and "↗" or T.restoreMini
	restore.TextColor3 = THEME.White
	restore.TextSize = compact and 17 or 9
	restore.Font = Enum.Font.GothamBold
	restore.AutoButtonColor = false
	restore.ZIndex = 153
	restore.Parent = mini
	corner(restore, 11); neonStroke(restore, THEME.Brown3, 0.22, 0.7)

	local miniTitle = makeLabel(mini, T.miniTitle, compact and 9 or 11, THEME.White, Enum.Font.GothamBold)
	miniTitle.Position = UDim2.fromOffset(compact and 62 or 72, 8)
	miniTitle.Size = UDim2.new(1, compact and -110 or -132, 0, compact and 21 or 23)
	miniTitle.TextTruncate = Enum.TextTruncate.AtEnd; miniTitle.ZIndex = 152
	local miniSub = makeLabel(mini, T.miniSub, compact and 8 or 9, THEME.Brown3, Enum.Font.GothamMedium)
	miniSub.Position = UDim2.fromOffset(compact and 62 or 72, compact and 29 or 32)
	miniSub.Size = UDim2.new(1, compact and -110 or -132, 0, compact and 18 or 20)
	miniSub.TextTruncate = Enum.TextTruncate.AtEnd; miniSub.ZIndex = 152

	local miniLogo = Instance.new("ImageLabel")
	miniLogo.Name = "Logo"
	miniLogo.AnchorPoint = Vector2.new(1, 0.5)
	miniLogo.Position = UDim2.new(1, -7, 0.5, 0)
	miniLogo.Size = UDim2.fromOffset(compact and 42 or 48, compact and 42 or 48)
	miniLogo.BackgroundTransparency = 1
	miniLogo.BorderSizePixel = 0
	miniLogo.Image = "rbxassetid://80552458381492"
	miniLogo.ScaleType = Enum.ScaleType.Fit
	miniLogo.ZIndex = 152
	miniLogo.Parent = mini

	local miniDragging = false
	local miniDragStart, miniStartPos, miniDragInput
	mini.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			miniDragging = true; miniDragStart = input.Position; miniStartPos = mini.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then miniDragging = false end end)
		end
	end)
	mini.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then miniDragInput = input end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if miniDragging and input == miniDragInput then
			local delta = input.Position - miniDragStart
			mini.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
		end
	end)

	local function setMinimized(value)
		minimized = value
		if activeDropdown and activeDropdown.Parent then activeDropdown:Destroy(); activeDropdown = nil end
		main.Visible = not value
		shadow.Visible = false
		mini.Visible = value
	end
	minimize.MouseButton1Click:Connect(function() setMinimized(true) end)
	restore.MouseButton1Click:Connect(function() setMinimized(false) end)

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

		cancel.MouseButton1Click:Connect(function() blocker:Destroy() end)
		yes.MouseButton1Click:Connect(function()
			hubRunning = false
			panicStop()
			if activeDropdown and activeDropdown.Parent then activeDropdown:Destroy(); activeDropdown = nil end
			gui:Destroy()
		end)
	end
	close.MouseButton1Click:Connect(showCloseModal)

	-- Entry animation.
	local finalPos = main.Position
	main.Position = UDim2.new(finalPos.X.Scale, finalPos.X.Offset, finalPos.Y.Scale, finalPos.Y.Offset + 18)
	main.BackgroundTransparency = 1
	shadow.BackgroundTransparency = 1
	tween(main, 0.28, { Position = finalPos, BackgroundTransparency = 0 }, Enum.EasingStyle.Quint)
	shadow.BackgroundTransparency = 1

	notify(T.loaded, 4)
end

showLanguagePicker(function(code)
	buildUI(L[code] or L.en, code)
end)
