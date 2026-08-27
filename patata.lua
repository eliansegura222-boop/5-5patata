-- avatar changer v1.1
-- Put in StarterPlayerScripts for your own place, or run as a client LocalScript.

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local GUI_NAME = "UniversalAvatarChanger"
local existing = playerGui:FindFirstChild(GUI_NAME)
if existing then
	existing:Destroy()
end

local LOCAL_ACCESSORY_ATTRIBUTE = "UAC_AssetId"
local LOCAL_GROUP_ATTRIBUTE = "UAC_Group"
local LOCAL_BODY_ATTRIBUTE = "UAC_BodyVisual"
local KORBLOX_RIGHT_LEG_ASSET = 139607718
local AUTO_LOAD_REMOTE_FINITY = false

local function enumItem(enumType, name)
	local ok, value = pcall(function()
		return enumType[name]
	end)
	if ok then
		return value
	end
	return nil
end

local TAB_DEFS = {
	{
		key = "hats",
		label = "Hats",
		placeholder = "Search hats, ex: fedora",
		assetTypes = { enumItem(Enum.AvatarAssetType, "Hat") },
		applyProperty = "HatAccessory",
		mode = "accessory",
	},
	{
		key = "hair",
		label = "Hair",
		placeholder = "Search hair",
		assetTypes = { enumItem(Enum.AvatarAssetType, "HairAccessory") },
		applyProperty = "HairAccessory",
		mode = "accessory",
	},
	{
		key = "faceAccessories",
		label = "Face Acc",
		placeholder = "Search face accessories",
		assetTypes = { enumItem(Enum.AvatarAssetType, "FaceAccessory") },
		applyProperty = "FaceAccessory",
		mode = "accessory",
	},
	{
		key = "faces",
		label = "Faces",
		placeholder = "Search faces",
		assetTypes = { enumItem(Enum.AvatarAssetType, "Face") },
		applyProperty = "Face",
		mode = "single",
	},
	{
		key = "heads",
		label = "Heads",
		placeholder = "Search heads if this client can load them",
		assetTypes = {
			enumItem(Enum.AvatarAssetType, "Head"),
			enumItem(Enum.AvatarAssetType, "DynamicHead"),
		},
		applyProperty = "Head",
		mode = "single",
	},
	{
		key = "body",
		label = "Body",
		placeholder = "Headless / Korblox buttons below",
		assetTypes = {},
		mode = "body",
	},
	{
		key = "applied",
		label = "Applied",
		placeholder = "Currently applied local items",
		assetTypes = {},
		mode = "applied",
	},
	{
		key = "settings",
		label = "Settings",
		placeholder = "Theme and keybind settings",
		assetTypes = {},
		mode = "settings",
	},
}

for _, tab in ipairs(TAB_DEFS) do
	local filtered = {}
	for _, item in ipairs(tab.assetTypes) do
		if item then
			table.insert(filtered, item)
		end
	end
	tab.assetTypes = filtered
end

local TAB_ICONS = {
	hats = "HT",
	hair = "HR",
	faceAccessories = "FA",
	faces = "FC",
	heads = "HD",
	body = "BD",
	applied = "AP",
	settings = "ST",
}

local appliedItems = {}
local appliedOrder = {}
local reapplying = false
local toggleKey = Enum.KeyCode.RightShift
local waitingForKeybind = false
local selectedPreviewItem = nil
local theme = {
	Name = "Aurora",
	Background = Color3.fromRGB(8, 10, 14),
	Panel = Color3.fromRGB(18, 21, 28),
	Panel2 = Color3.fromRGB(28, 33, 42),
	Accent = Color3.fromRGB(85, 185, 255),
	Accent2 = Color3.fromRGB(116, 236, 188),
	Text = Color3.fromRGB(248, 250, 255),
	Muted = Color3.fromRGB(156, 166, 182),
	Danger = Color3.fromRGB(238, 81, 105),
	Glass = 0.18,
	PaneGlass = 0.28,
	TileGlass = 0.2,
}

local themePresets = {
	Aurora = {
		Background = Color3.fromRGB(8, 10, 14),
		Panel = Color3.fromRGB(18, 21, 28),
		Panel2 = Color3.fromRGB(28, 33, 42),
		Accent = Color3.fromRGB(72, 168, 255),
		Accent2 = Color3.fromRGB(90, 220, 170),
	},
	Cherry = {
		Background = Color3.fromRGB(17, 9, 13),
		Panel = Color3.fromRGB(31, 17, 24),
		Panel2 = Color3.fromRGB(46, 25, 35),
		Accent = Color3.fromRGB(255, 91, 126),
		Accent2 = Color3.fromRGB(255, 181, 96),
	},
	Mint = {
		Background = Color3.fromRGB(7, 15, 15),
		Panel = Color3.fromRGB(16, 28, 27),
		Panel2 = Color3.fromRGB(24, 42, 40),
		Accent = Color3.fromRGB(76, 225, 172),
		Accent2 = Color3.fromRGB(97, 175, 255),
	},
	Void = {
		Background = Color3.fromRGB(7, 7, 11),
		Panel = Color3.fromRGB(16, 15, 24),
		Panel2 = Color3.fromRGB(27, 25, 39),
		Accent = Color3.fromRGB(168, 116, 255),
		Accent2 = Color3.fromRGB(255, 106, 213),
	},
}

local function appliedKey(kind, assetId)
	return tostring(kind) .. ":" .. tostring(assetId)
end

local function rememberApplied(item)
	local key = item.key or appliedKey(item.kind, item.assetId)
	item.key = key

	if not appliedItems[key] then
		table.insert(appliedOrder, key)
	end

	appliedItems[key] = item
end

local function forgetApplied(kind, assetId)
	local key = appliedKey(kind, assetId)
	appliedItems[key] = nil

	for index = #appliedOrder, 1, -1 do
		if appliedOrder[index] == key then
			table.remove(appliedOrder, index)
		end
	end
end

local function forgetAppliedKey(key)
	appliedItems[key] = nil

	for index = #appliedOrder, 1, -1 do
		if appliedOrder[index] == key then
			table.remove(appliedOrder, index)
		end
	end
end

local function appliedCount()
	local count = 0
	for _, key in ipairs(appliedOrder) do
		if appliedItems[key] then
			count += 1
		end
	end
	return count
end

local function getHumanoid()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	return character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
end

local function getCharacter()
	return localPlayer.Character or localPlayer.CharacterAdded:Wait()
end

local function loadAsset(assetId)
	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. tostring(assetId))
	end)

	if not ok then
		return nil, tostring(objects)
	end

	if not objects or #objects == 0 then
		return nil, "Asset did not load."
	end

	return objects
end

local function findFirstDescendant(root, predicate)
	if predicate(root) then
		return root
	end

	for _, child in ipairs(root:GetDescendants()) do
		if predicate(child) then
			return child
		end
	end

	return nil
end

local hiddenState = {}

local function rememberVisual(instance)
	if hiddenState[instance] then
		return
	end

	if instance:IsA("BasePart") then
		hiddenState[instance] = {
			Transparency = instance.Transparency,
			LocalTransparencyModifier = instance.LocalTransparencyModifier,
		}
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		hiddenState[instance] = {
			Transparency = instance.Transparency,
		}
	end
end

local function hideVisual(instance)
	rememberVisual(instance)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = 1
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = 1
	end
end

local function restoreVisual(instance)
	local state = hiddenState[instance]
	if not state then
		return
	end

	if instance:IsA("BasePart") then
		instance.Transparency = state.Transparency
		instance.LocalTransparencyModifier = state.LocalTransparencyModifier
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = state.Transparency
	end

	hiddenState[instance] = nil
end

local faceState = nil
local setHeadless
local setKorbloxLike
local reapplyAll

local function findHandleAttachment(handle)
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") then
			return child
		end
	end
	return nil
end

local function findCharacterAttachment(character, attachmentName)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == attachmentName and descendant.Parent:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function manualAttachAccessory(accessory)
	local character = getCharacter()
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return false, "Accessory has no Handle."
	end

	local handleAttachment = findHandleAttachment(handle)
	if not handleAttachment then
		return false, "Accessory handle has no attachment."
	end

	local characterAttachment = findCharacterAttachment(character, handleAttachment.Name)
	if not characterAttachment then
		return false, "Character is missing " .. handleAttachment.Name .. "."
	end

	accessory.Parent = character
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.LocalTransparencyModifier = 0
	handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * handleAttachment.CFrame:Inverse()

	local oldWeld = handle:FindFirstChild("AccessoryWeld")
	if oldWeld then
		oldWeld:Destroy()
	end

	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = characterAttachment.Parent
	weld.C0 = handleAttachment.CFrame
	weld.C1 = characterAttachment.CFrame
	weld.Parent = handle

	return true
end

local function addAccessory(tabKey, assetId)
	local humanoid = getHumanoid()
	if not humanoid then
		return false, "No humanoid found."
	end

	local objects, err = loadAsset(assetId)
	if not objects then
		return false, err
	end

	local accessory
	for _, object in ipairs(objects) do
		accessory = findFirstDescendant(object, function(candidate)
			return candidate:IsA("Accessory")
		end)
		if accessory then
			break
		end
	end

	if not accessory then
		for _, object in ipairs(objects) do
			object:Destroy()
		end
		return false, "Loaded asset is not an accessory."
	end

	accessory.Parent = nil
	accessory:SetAttribute(LOCAL_ACCESSORY_ATTRIBUTE, tostring(assetId))
	accessory:SetAttribute(LOCAL_GROUP_ATTRIBUTE, tabKey)

	local ok, addErr = pcall(function()
		humanoid:AddAccessory(accessory)
	end)

	local handle = accessory:FindFirstChild("Handle")
	local hasWeld = handle and handle:FindFirstChild("AccessoryWeld")
	if ok and hasWeld then
		return true
	end

	local weldOk, weldErr = manualAttachAccessory(accessory)
	if weldOk then
		return true
	end

	return false, ok and tostring(weldErr) or tostring(addErr)
end

local function removeAccessory(tabKey, assetId)
	local character = getCharacter()
	local removed = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory")
			and child:GetAttribute(LOCAL_ACCESSORY_ATTRIBUTE) == tostring(assetId)
			and child:GetAttribute(LOCAL_GROUP_ATTRIBUTE) == tabKey then
			child:Destroy()
			removed += 1
		end
	end
	return true, removed > 0 and ("Removed " .. tostring(removed) .. " local copy.") or "No matching local copy found."
end

local function applyFace(assetId)
	local character = getCharacter()
	local head = character:FindFirstChild("Head")
	if not head then
		return false, "No head found."
	end

	local objects, err = loadAsset(assetId)
	if not objects then
		return false, err
	end

	local sourceDecal
	for _, object in ipairs(objects) do
		sourceDecal = findFirstDescendant(object, function(candidate)
			return candidate:IsA("Decal") and candidate.Texture ~= ""
		end)
		if sourceDecal then
			break
		end
	end

	if not sourceDecal then
		for _, object in ipairs(objects) do
			object:Destroy()
		end
		return false, "Loaded face did not contain a decal."
	end

	local face = head:FindFirstChild("face")
	if not face then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end

	if not faceState then
		faceState = {
			Decal = face,
			Texture = face.Texture,
			Transparency = face.Transparency,
		}
	end

	face.Texture = sourceDecal.Texture
	face.Transparency = 0

	for _, object in ipairs(objects) do
		object:Destroy()
	end

	return true
end

local function restoreFace()
	if not faceState or not faceState.Decal or not faceState.Decal.Parent then
		return false, "No saved face to restore."
	end

	faceState.Decal.Texture = faceState.Texture
	faceState.Decal.Transparency = faceState.Transparency
	faceState = nil
	return true
end

local function applySingle(tabKey, assetId)
	if tabKey == "faces" then
		return applyFace(assetId)
	end

	return addAccessory(tabKey, assetId)
end

local function applyStoredItem(item)
	if item.kind == "accessory" then
		removeAccessory(item.tabKey, item.assetId)
		return addAccessory(item.tabKey, item.assetId)
	elseif item.kind == "single" then
		if item.tabKey ~= "faces" then
			removeAccessory(item.tabKey, item.assetId)
		end
		return applySingle(item.tabKey, item.assetId)
	elseif item.kind == "headless" then
		return setHeadless(true)
	elseif item.kind == "korblox" then
		return setKorbloxLike(true)
	end

	return false, "Unknown applied item type."
end

function setHeadless(enabled)
	local character = getCharacter()
	local head = character:FindFirstChild("Head")
	if not head then
		return false, "No head found."
	end

	if enabled then
		hideVisual(head)
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				hideVisual(child)
			end
		end
	else
		restoreVisual(head)
		for _, child in ipairs(head:GetChildren()) do
			restoreVisual(child)
		end
	end

	return true
end

function setKorbloxLike(enabled)
	local character = getCharacter()
	local humanoid = getHumanoid()
	local rigType = humanoid and humanoid.RigType or Enum.HumanoidRigType.R15

	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute(LOCAL_BODY_ATTRIBUTE) == "KorbloxRightLeg" then
			child:Destroy()
		end
	end

	local function restoreOriginals(names)
		for _, name in ipairs(names) do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				restoreVisual(part)
				for _, child in ipairs(part:GetChildren()) do
					restoreVisual(child)
				end
			end
		end
	end

	if not enabled then
		restoreOriginals({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" })
		return true
	end

	local objects, err = loadAsset(KORBLOX_RIGHT_LEG_ASSET)
	if not objects then
		return false, err
	end

	local sourceParts = {}
	for _, object in ipairs(objects) do
		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("MeshPart") and (descendant.Name == "RightUpperLeg" or descendant.Name == "RightLowerLeg" or descendant.Name == "RightFoot") then
				sourceParts[descendant.Name] = descendant
			end
		end
		if object:IsA("MeshPart") and (object.Name == "RightUpperLeg" or object.Name == "RightLowerLeg" or object.Name == "RightFoot") then
			sourceParts[object.Name] = object
		end
	end

	if not sourceParts.RightUpperLeg or not sourceParts.RightLowerLeg or not sourceParts.RightFoot then
		for _, object in ipairs(objects) do
			object:Destroy()
		end
		return false, "Korblox leg mesh parts did not load."
	end

	local visualModel = Instance.new("Model")
	visualModel.Name = "UAC_KorbloxRightLeg"
	visualModel:SetAttribute(LOCAL_BODY_ATTRIBUTE, "KorbloxRightLeg")
	visualModel.Parent = character

	local function prepClone(source, name)
		local clone = source:Clone()
		clone.Name = "UAC_" .. name
		clone:SetAttribute(LOCAL_BODY_ATTRIBUTE, "KorbloxRightLeg")
		clone.Anchored = false
		clone.CanCollide = false
		clone.Massless = true
		clone.LocalTransparencyModifier = 0

		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("WrapTarget") or descendant:IsA("Attachment") or descendant:IsA("JointInstance") then
				descendant:Destroy()
			end
		end

		clone.Parent = visualModel
		return clone
	end

	local function weldClone(clone, targetPart, offset)
		clone.CFrame = targetPart.CFrame * (offset or CFrame.new())
		local weld = Instance.new("WeldConstraint")
		weld.Name = "UAC_KorbloxWeld"
		weld.Part0 = clone
		weld.Part1 = targetPart
		weld.Parent = clone
	end

	if rigType == Enum.HumanoidRigType.R6 then
		local rightLeg = character:FindFirstChild("Right Leg")
		if not rightLeg or not rightLeg:IsA("BasePart") then
			visualModel:Destroy()
			for _, object in ipairs(objects) do
				object:Destroy()
			end
			return false, "No R6 Right Leg found."
		end

		hideVisual(rightLeg)
		for _, child in ipairs(rightLeg:GetChildren()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				hideVisual(child)
			end
		end

		local scale = math.clamp(rightLeg.Size.Y / 2, 0.75, 1.6)
		local upper = prepClone(sourceParts.RightUpperLeg, "RightUpperLeg")
		local lower = prepClone(sourceParts.RightLowerLeg, "RightLowerLeg")
		local foot = prepClone(sourceParts.RightFoot, "RightFoot")

		upper.Size = sourceParts.RightUpperLeg.Size * scale
		lower.Size = sourceParts.RightLowerLeg.Size * scale
		foot.Size = sourceParts.RightFoot.Size * scale

		weldClone(upper, rightLeg, CFrame.new(0, rightLeg.Size.Y * 0.24, 0))
		weldClone(lower, rightLeg, CFrame.new(0, -rightLeg.Size.Y * 0.18, 0))
		weldClone(foot, rightLeg, CFrame.new(0, -rightLeg.Size.Y * 0.48, -rightLeg.Size.Z * 0.18))
	else
		local partNames = { "RightUpperLeg", "RightLowerLeg", "RightFoot" }
		for _, name in ipairs(partNames) do
			local targetPart = character:FindFirstChild(name)
			if targetPart and targetPart:IsA("BasePart") then
				hideVisual(targetPart)
				for _, child in ipairs(targetPart:GetChildren()) do
					if child:IsA("Decal") or child:IsA("Texture") then
						hideVisual(child)
					end
				end

				local clone = prepClone(sourceParts[name], name)
				clone.Size = targetPart.Size
				weldClone(clone, targetPart)
			end
		end
	end

	for _, object in ipairs(objects) do
		object:Destroy()
	end

	return true
end

local function make(instanceType, props, parent)
	local instance = Instance.new(instanceType)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = make("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local root = make("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 18, 19),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(790, 500),
	ZIndex = 2,
	ClipsDescendants = true,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, root)
local rootBackdrop = make("Frame", {
	Name = "Backdrop",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -8),
	ZIndex = 0,
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, rootBackdrop)
make("UIStroke", {
	Color = Color3.fromRGB(42, 42, 46),
	Thickness = 1,
	Transparency = 0.25,
}, root)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 170, 210)),
	}),
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, root)

local titleBar = make("Frame", {
	Name = "TitleBar",
	BackgroundColor3 = Color3.fromRGB(18, 18, 19),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 32),
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, titleBar)

local titleMask = make("Frame", {
	BackgroundColor3 = titleBar.BackgroundColor3,
	BackgroundTransparency = titleBar.BackgroundTransparency,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 1, -8),
	Size = UDim2.new(1, 0, 0, 8),
}, titleBar)

make("Frame", {
	BackgroundColor3 = theme.Accent,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
}, titleBar)

make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamSemibold,
	Position = UDim2.fromOffset(86, 0),
	Size = UDim2.new(0, 190, 1, 0),
	Text = "AVATAR CHANGER V1.1",
	TextColor3 = theme.Text,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local hour = tonumber(os.date("%H")) or 12
local greetingText = hour < 12 and "Good morning" or (hour < 18 and "Good afternoon" or "Good evening")
local greeting = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.fromOffset(306, 0),
	Size = UDim2.new(1, -360, 1, 0),
	Text = greetingText .. ", " .. localPlayer.Name .. " - preview, apply, respawn-ready.",
	TextColor3 = theme.Muted,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local closeButton = make("TextButton", {
	BackgroundColor3 = theme.Panel2,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(1, -36, 0, 8),
	Size = UDim2.fromOffset(22, 22),
	Text = "X",
	TextColor3 = theme.Text,
	TextSize = 13,
}, titleBar)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, closeButton)
closeButton.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

local iconRail = make("Frame", {
	Name = "IconRail",
	BackgroundColor3 = Color3.fromRGB(36, 35, 41),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(1, 1),
	Size = UDim2.new(0, 68, 1, -2),
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, iconRail)

local iconRailMask = make("Frame", {
	BackgroundColor3 = iconRail.BackgroundColor3,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Position = UDim2.new(1, -6, 0, 0),
	Size = UDim2.new(0, 6, 1, 0),
}, iconRail)

local sectionRail = make("Frame", {
	Name = "SectionRail",
	BackgroundColor3 = Color3.fromRGB(31, 31, 34),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(70, 0),
	Size = UDim2.new(0, 220, 1, 0),
}, root)

local sectionTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamSemibold,
	Position = UDim2.fromOffset(22, 28),
	Size = UDim2.new(1, -44, 0, 34),
	Text = "Hats",
	TextColor3 = theme.Text,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
}, sectionRail)

local sectionSubtitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.fromOffset(22, 66),
	Size = UDim2.new(1, -44, 0, 44),
	Text = "Search hats, ex: fedora",
	TextColor3 = theme.Muted,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, sectionRail)

local tabBar = make("Frame", {
	Name = "Tabs",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(13, 96),
	Size = UDim2.new(1, -26, 1, -140),
}, iconRail)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, tabBar)

local searchBox = make("TextBox", {
	Name = "SearchBox",
	BackgroundColor3 = theme.Panel,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	PlaceholderColor3 = Color3.fromRGB(140, 146, 158),
	PlaceholderText = "Search",
	Position = UDim2.fromOffset(310, 64),
	Size = UDim2.new(1, -440, 0, 36),
	Text = "",
	TextColor3 = theme.Text,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, searchBox)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
}, searchBox)

local searchButton = make("TextButton", {
	BackgroundColor3 = theme.Accent,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamSemibold,
	Position = UDim2.new(1, -112, 0, 64),
	Size = UDim2.fromOffset(92, 36),
	Text = "Search",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 14,
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, searchButton)

local status = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.fromOffset(310, 108),
	Size = UDim2.new(1, -330, 0, 20),
	Text = "Search catalog items, then apply them locally.",
	TextColor3 = Color3.fromRGB(172, 178, 190),
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
}, root)

local scroller = make("ScrollingFrame", {
	Name = "Results",
	Active = true,
	BackgroundColor3 = theme.Panel,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(310, 278),
	ScrollBarImageColor3 = Color3.fromRGB(118, 127, 144),
	ScrollBarThickness = 5,
	Size = UDim2.new(1, -330, 1, -294),
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, scroller)
make("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.9,
}, scroller)

local grid = make("UIGridLayout", {
	CellPadding = UDim2.fromOffset(8, 8),
	CellSize = UDim2.fromOffset(104, 150),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, scroller)
make("UIPadding", {
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	PaddingTop = UDim.new(0, 8),
}, scroller)

grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroller.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 18)
end)

local previewPanel = make("Frame", {
	Name = "PreviewPanel",
	BackgroundColor3 = theme.Panel,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(310, 138),
	Size = UDim2.new(1, -330, 0, 122),
}, root)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, previewPanel)
make("UIStroke", {
	Color = theme.Accent,
	Thickness = 1,
	Transparency = 0.34,
}, previewPanel)

local previewTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamSemibold,
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.new(1, -24, 0, 20),
	Text = "Preview",
	TextColor3 = theme.Text,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, previewPanel)

local previewImage = make("ImageLabel", {
	BackgroundColor3 = theme.Panel2,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Image = "",
	Position = UDim2.fromOffset(12, 38),
	ScaleType = Enum.ScaleType.Fit,
	Size = UDim2.fromOffset(72, 72),
}, previewPanel)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, previewImage)
make("UIStroke", {
	Color = Color3.fromRGB(255, 255, 255),
	Thickness = 1,
	Transparency = 0.88,
}, previewImage)

local previewName = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamSemibold,
	Position = UDim2.fromOffset(96, 38),
	Size = UDim2.new(1, -112, 0, 38),
	Text = "Select an item",
	TextColor3 = theme.Text,
	TextSize = 15,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, previewPanel)

local previewMeta = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.fromOffset(96, 74),
	Size = UDim2.new(1, -112, 0, 38),
	Text = "Click any catalog tile to preview it here.",
	TextColor3 = theme.Muted,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, previewPanel)

local previewApply = make("TextButton", {
	BackgroundColor3 = theme.Accent2,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamSemibold,
	Position = UDim2.new(1, -132, 0, 8),
	Size = UDim2.fromOffset(120, 30),
	Text = "Apply Preview",
	TextColor3 = Color3.fromRGB(8, 12, 18),
	TextSize = 14,
}, previewPanel)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, previewApply)
previewApply.MouseEnter:Connect(function()
	TweenService:Create(previewApply, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = theme.Accent,
	}):Play()
end)
previewApply.MouseLeave:Connect(function()
	TweenService:Create(previewApply, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = theme.Accent2,
	}):Play()
end)

local previewHint = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.new(1, -132, 0, 82),
	Size = UDim2.fromOffset(120, 28),
	Text = "Toggle UI: RightShift",
	TextColor3 = theme.Muted,
	TextSize = 12,
	TextWrapped = true,
}, previewPanel)

local selectedTab = TAB_DEFS[1]
local tabButtons = {}
local currentPages = nil

local function setStatus(text, isError)
	status.Text = text
	status.TextColor3 = isError and Color3.fromRGB(255, 135, 135) or Color3.fromRGB(172, 178, 190)
end

local function updatePreview(item)
	selectedPreviewItem = item
	if not item then
		previewImage.Image = ""
		previewName.Text = "Select an item"
		previewMeta.Text = "Click any catalog tile to preview it here."
		return
	end

	previewImage.Image = "rbxthumb://type=Asset&id=" .. tostring(item.Id) .. "&w=420&h=420"
	previewName.Text = item.Name or ("Asset " .. tostring(item.Id))
	previewMeta.Text = selectedTab.label .. " | Asset ID " .. tostring(item.Id) .. "\nThis is how it will look before local apply."
end

local function applyCatalogItem(item)
	local ok, err
	if selectedTab.mode == "accessory" then
		ok, err = addAccessory(selectedTab.key, item.Id)
	else
		ok, err = applySingle(selectedTab.key, item.Id)
	end
	if ok then
		rememberApplied({
			key = selectedTab.mode == "single" and ("single:" .. selectedTab.key) or nil,
			kind = selectedTab.mode,
			tabKey = selectedTab.key,
			assetId = item.Id,
			name = item.Name or ("Asset " .. tostring(item.Id)),
			image = "rbxthumb://type=Asset&id=" .. tostring(item.Id) .. "&w=150&h=150",
		})
	end
	setStatus(ok and ("Applied " .. tostring(item.Name or item.Id)) or ("Apply failed: " .. tostring(err)), not ok)
end

local function clearResults()
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function styleTabs()
	for tabKey, button in pairs(tabButtons) do
		local active = selectedTab.key == tabKey
		button.BackgroundColor3 = active and theme.Accent or theme.Panel2
		button.BackgroundTransparency = 0
		button.TextColor3 = active and Color3.fromRGB(8, 12, 18) or Color3.fromRGB(218, 221, 229)
	end
	sectionTitle.Text = selectedTab.label
	sectionSubtitle.Text = selectedTab.placeholder
	searchBox.PlaceholderText = selectedTab.placeholder
	searchBox.Visible = selectedTab.mode ~= "body" and selectedTab.mode ~= "applied" and selectedTab.mode ~= "settings"
	searchButton.Visible = selectedTab.mode ~= "body" and selectedTab.mode ~= "applied" and selectedTab.mode ~= "settings"
end

local function itemCard(item)
	local card = make("Frame", {
		BackgroundColor3 = theme.Panel2,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, scroller)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, card)
	make("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.9,
	}, card)
	card.MouseEnter:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = Color3.fromRGB(36, 36, 39),
		}):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = theme.Panel2,
		}):Play()
	end)

	local image = make("ImageLabel", {
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Image = "rbxthumb://type=Asset&id=" .. tostring(item.Id) .. "&w=150&h=150",
		Position = UDim2.fromOffset(6, 6),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(92, 62),
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, image)
	local previewClick = make("TextButton", {
		BackgroundTransparency = 1,
		Position = image.Position,
		Size = image.Size,
		Text = "",
	}, card)
	previewClick.MouseButton1Click:Connect(function()
		updatePreview(item)
		setStatus("Previewing " .. tostring(item.Name or item.Id), false)
	end)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(6, 74),
		Size = UDim2.fromOffset(92, 32),
		Text = item.Name or ("Asset " .. tostring(item.Id)),
		TextColor3 = Color3.fromRGB(242, 244, 248),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)

	local apply = make("TextButton", {
		BackgroundColor3 = theme.Accent2,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		Position = UDim2.fromOffset(6, 114),
		Size = selectedTab.mode == "accessory" and UDim2.fromOffset(58, 24) or UDim2.fromOffset(92, 24),
		Text = selectedTab.mode == "accessory" and "Add" or "Apply",
		TextColor3 = Color3.fromRGB(8, 12, 18),
		TextSize = 12,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, apply)

	apply.MouseButton1Click:Connect(function()
		updatePreview(item)
		applyCatalogItem(item)
	end)

	if selectedTab.mode == "accessory" then
		local remove = make("TextButton", {
			BackgroundColor3 = theme.Danger,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Position = UDim2.fromOffset(68, 114),
			Size = UDim2.fromOffset(30, 24),
			Text = "-",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
		}, card)
		make("UICorner", { CornerRadius = UDim.new(0, 2) }, remove)

		remove.MouseButton1Click:Connect(function()
			local ok, err = removeAccessory(selectedTab.key, item.Id)
			if ok then
				forgetApplied("accessory", item.Id)
			end
			setStatus(ok and ("Removed " .. tostring(item.Name or item.Id)) or ("Remove failed: " .. tostring(err)), not ok)
		end)
	end
end

local function removeAppliedItem(item)
	if item.kind == "accessory" then
		removeAccessory(item.tabKey, item.assetId)
	elseif item.kind == "single" then
		if item.tabKey == "faces" then
			restoreFace()
		else
			removeAccessory(item.tabKey, item.assetId)
		end
	elseif item.kind == "headless" then
		setHeadless(false)
	elseif item.kind == "korblox" then
		setKorbloxLike(false)
	end

	forgetAppliedKey(item.key)
	return true
end

local function appliedCard(item)
	local card = make("Frame", {
		BackgroundColor3 = theme.Panel2,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, scroller)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, card)
	make("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 1,
		Transparency = 0.9,
	}, card)

	local image = make("ImageLabel", {
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Image = item.image or "",
		Position = UDim2.fromOffset(8, 8),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(106, 72),
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, image)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(8, 84),
		Size = UDim2.fromOffset(106, 34),
		Text = item.name or tostring(item.assetId or item.kind),
		TextColor3 = Color3.fromRGB(242, 244, 248),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)

	local reapplyButton = make("TextButton", {
		BackgroundColor3 = theme.Accent2,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		Position = UDim2.fromOffset(8, 122),
		Size = UDim2.fromOffset(106, 24),
		Text = "Reapply",
		TextColor3 = Color3.fromRGB(8, 12, 18),
		TextSize = 12,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, reapplyButton)

	local removeButton = make("TextButton", {
		BackgroundColor3 = theme.Danger,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		Position = UDim2.fromOffset(8, 150),
		Size = UDim2.fromOffset(106, 24),
		Text = "Remove",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 12,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 2) }, removeButton)

	reapplyButton.MouseButton1Click:Connect(function()
		local ok, err = applyStoredItem(item)
		setStatus(ok and ("Reapplied " .. tostring(item.name)) or ("Reapply failed: " .. tostring(err)), not ok)
	end)

	removeButton.MouseButton1Click:Connect(function()
		removeAppliedItem(item)
		setStatus("Removed " .. tostring(item.name) .. " from Applied.", false)
		task.defer(function()
			if selectedTab.mode == "applied" then
				clearResults()
				for _, key in ipairs(appliedOrder) do
					local applied = appliedItems[key]
					if applied then
						appliedCard(applied)
					end
				end
			end
		end)
	end)
end

local function showApplied()
	clearResults()
	local count = appliedCount()
	setStatus(count == 0 and "Nothing is currently remembered." or ("Remembered " .. tostring(count) .. " applied item(s)."), count == 0)

	for _, key in ipairs(appliedOrder) do
		local item = appliedItems[key]
		if item then
			appliedCard(item)
		end
	end
end

local function showBodyTools()
	clearResults()
	setStatus("Body edits are local visibility changes. They do not call ApplyDescription.", false)

	local holder = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 260),
	}, scroller)

	local layout = make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)

	local function bodyButton(label, detail, callback)
		local button = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = theme.Panel2,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Size = UDim2.new(1, 0, 0, 54),
			Text = label .. "\n" .. detail,
			TextColor3 = Color3.fromRGB(244, 246, 250),
			TextSize = 14,
			TextWrapped = true,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0, 2) }, button)
		make("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1,
			Transparency = 0.9,
		}, button)
		button.MouseButton1Click:Connect(callback)
		return button
	end

	bodyButton("Apply Headless", "Hides your head and face locally on this client.", function()
		local ok, err = setHeadless(true)
		if ok then
			rememberApplied({
				key = "body:headless",
				kind = "headless",
				name = "Headless",
				image = "rbxthumb://type=Asset&id=134082579&w=150&h=150",
			})
		end
		setStatus(ok and "Applied Headless locally." or ("Headless failed: " .. tostring(err)), not ok)
	end)

	bodyButton("Remove Headless", "Shows your locally hidden head and face again.", function()
		local ok, err = setHeadless(false)
		if ok then
			forgetAppliedKey("body:headless")
		end
		setStatus(ok and "Head restored locally." or ("Head restore failed: " .. tostring(err)), not ok)
	end)

	bodyButton("Apply Korblox Right Leg", "Hides lower right leg parts locally for a Korblox-like look.", function()
		local ok, err = setKorbloxLike(true)
		if ok then
			rememberApplied({
				key = "body:korblox",
				kind = "korblox",
				name = "Korblox Right Leg",
				image = "rbxthumb://type=Asset&id=139607718&w=150&h=150",
			})
		end
		setStatus(ok and "Applied Korblox-like right leg locally." or ("Korblox failed: " .. tostring(err)), not ok)
	end)

	bodyButton("Remove Korblox Right Leg", "Shows your locally hidden right leg parts again.", function()
		local ok, err = setKorbloxLike(false)
		if ok then
			forgetAppliedKey("body:korblox")
		end
		setStatus(ok and "Right leg restored locally." or ("Right leg restore failed: " .. tostring(err)), not ok)
	end)

	task.defer(function()
		scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
	end)
end

local function applyThemePreset(name)
	local preset = themePresets[name]
	if not preset then
		return
	end

	theme.Name = name
	for key, value in pairs(preset) do
		theme[key] = value
	end

	root.BackgroundColor3 = theme.Background
	titleBar.BackgroundColor3 = theme.Panel
	titleMask.BackgroundColor3 = theme.Panel
	iconRail.BackgroundColor3 = theme.Panel2
	iconRailMask.BackgroundColor3 = theme.Panel2
	sectionRail.BackgroundColor3 = theme.Panel
	searchBox.BackgroundColor3 = theme.Panel
	scroller.BackgroundColor3 = theme.Panel
	previewPanel.BackgroundColor3 = theme.Panel
	previewImage.BackgroundColor3 = theme.Panel2
	root.BackgroundTransparency = 0
	titleBar.BackgroundTransparency = 0
	iconRail.BackgroundTransparency = 0
	iconRailMask.BackgroundTransparency = 0
	sectionRail.BackgroundTransparency = 0
	searchBox.BackgroundTransparency = 0
	scroller.BackgroundTransparency = 0
	previewPanel.BackgroundTransparency = 0
	previewImage.BackgroundTransparency = 0
	searchButton.BackgroundColor3 = theme.Accent
	previewApply.BackgroundColor3 = theme.Accent2
	greeting.TextColor3 = theme.Muted
	previewTitle.TextColor3 = theme.Text
	previewName.TextColor3 = theme.Text
	previewMeta.TextColor3 = theme.Muted
	previewHint.TextColor3 = theme.Muted
	closeButton.BackgroundColor3 = theme.Panel2
	styleTabs()
	setStatus("Theme changed to " .. name .. ".", false)
end

local function showSettings()
	clearResults()
	setStatus("Customize theme and toggle keybind.", false)

	local holder = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 360),
	}, scroller)

	local layout = make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)

	local function settingButton(label, detail, callback)
		local button = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = theme.Panel2,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Size = UDim2.new(1, 0, 0, 54),
			Text = label .. "\n" .. detail,
			TextColor3 = theme.Text,
			TextSize = 14,
			TextWrapped = true,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0, 2) }, button)
		make("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1,
			Transparency = 0.9,
		}, button)
		button.MouseButton1Click:Connect(callback)
	end

	settingButton("Keybind", "Current: " .. toggleKey.Name .. " - click then press any keyboard key.", function()
		waitingForKeybind = true
		setStatus("Press a key to set the UI toggle keybind.", false)
		previewHint.Text = "Waiting for key..."
	end)

	local dropdownOpen = false
	local themeRows = {}
	local themeDropdown = settingButton("Theme", "Current: " .. theme.Name .. "  v", function()
		dropdownOpen = not dropdownOpen
		for _, row in ipairs(themeRows) do
			row.Visible = dropdownOpen
		end
	end)

	local names = {}
	for name in pairs(themePresets) do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in ipairs(names) do
		local row = make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = Color3.fromRGB(24, 24, 26),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamSemibold,
			Size = UDim2.new(1, 0, 0, 38),
			Text = name,
			TextColor3 = theme.Text,
			TextSize = 14,
			Visible = false,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
		row.MouseButton1Click:Connect(function()
			applyThemePreset(name)
			themeDropdown.Text = "Theme\nCurrent: " .. name .. "  v"
			dropdownOpen = false
			for _, optionRow in ipairs(themeRows) do
				optionRow.Visible = false
			end
		end)
		table.insert(themeRows, row)
	end

	task.defer(function()
		scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
	end)
end

local function renderPage(page)
	clearResults()
	for _, item in ipairs(page) do
		itemCard(item)
	end
	if #page == 0 then
		setStatus("No results found.", true)
	else
		setStatus("Showing " .. tostring(#page) .. " results. Click a photo tile to apply.", false)
	end
end

local function doSearch()
	if selectedTab.mode == "body" then
		showBodyTools()
		return
	end
	if selectedTab.mode == "applied" then
		showApplied()
		return
	end
	if selectedTab.mode == "settings" then
		showSettings()
		return
	end

	local query = searchBox.Text
	if query:gsub("%s+", "") == "" then
		setStatus("Type something to search first.", true)
		return
	end

	if #selectedTab.assetTypes == 0 then
		setStatus("This tab is not supported in this Roblox client.", true)
		return
	end

	setStatus("Searching...", false)
	clearResults()

	local params = CatalogSearchParams.new()
	params.SearchKeyword = query
	params.AssetTypes = selectedTab.assetTypes
	params.SortType = Enum.CatalogSortType.Relevance
	params.Limit = 30

	local ok, pages = pcall(function()
		return AvatarEditorService:SearchCatalog(params)
	end)

	if not ok then
		currentPages = nil
		setStatus("Search failed: " .. tostring(pages), true)
		return
	end

	currentPages = pages
	renderPage(pages:GetCurrentPage())
end

local function selectTabByKey(tabKey)
	for _, tab in ipairs(TAB_DEFS) do
		if tab.key == tabKey then
			selectedTab = tab
			styleTabs()
			if tab.mode == "body" then
				showBodyTools()
			elseif tab.mode == "applied" then
				showApplied()
			elseif tab.mode == "settings" then
				showSettings()
			else
				clearResults()
				setStatus("Search " .. tab.label .. " and apply results locally.", false)
			end
			return true
		end
	end

	return false
end

local function tryBuildFinityPanel()
	local ok, err = pcall(function()
		local Finity = rawget(shared, "Finity")
			or rawget(shared, "ProjectFinity")
			or rawget(shared, "finity")

		if not Finity then
			if not AUTO_LOAD_REMOTE_FINITY then
				error("Project Finity is not preloaded. Set AUTO_LOAD_REMOTE_FINITY to true only if you approve loading http://finity.vip/scripts/finity_lib.lua.")
			end
			Finity = loadstring(game:HttpGet("http://finity.vip/scripts/finity_lib.lua"))()
			shared.Finity = Finity
		end

		local finityWindow = Finity.new(true)
		finityWindow.ChangeToggleKey(Enum.KeyCode.RightShift)

		local searchCategory = finityWindow:Category("Avatar")
		local searchSector = searchCategory:Sector("Catalog Search")
		local bodySector = searchCategory:Sector("Body")
		local appliedSector = searchCategory:Sector("Applied")

		local tabByLabel = {
			Hats = "hats",
			Hair = "hair",
			["Face Accessories"] = "faceAccessories",
			Faces = "faces",
			Heads = "heads",
		}

		searchSector:Cheat("Label", "avatar changer v1.1")
		searchSector:Cheat("Dropdown", "Search Tab", function(option)
			selectTabByKey(tabByLabel[option] or "hats")
		end, {
			options = { "Hats", "Hair", "Face Accessories", "Faces", "Heads" },
			default = "Hats",
		})
		searchSector:Cheat("Textbox", "Search", function(value)
			searchBox.Text = tostring(value or "")
		end, {
			placeholder = "fedora",
		})
		searchSector:Cheat("Button", "Run Search", function()
			root.Visible = true
			doSearch()
		end)
		searchSector:Cheat("Button", "Toggle Results Panel", function()
			root.Visible = not root.Visible
		end)

		bodySector:Cheat("Button", "Apply Headless", function()
			local okHeadless = setHeadless(true)
			if okHeadless then
				rememberApplied({
					key = "body:headless",
					kind = "headless",
					name = "Headless",
					image = "rbxthumb://type=Asset&id=134082579&w=150&h=150",
				})
			end
		end)
		bodySector:Cheat("Button", "Remove Headless", function()
			if setHeadless(false) then
				forgetAppliedKey("body:headless")
			end
		end)
		bodySector:Cheat("Button", "Apply Korblox Right Leg", function()
			local okKorblox = setKorbloxLike(true)
			if okKorblox then
				rememberApplied({
					key = "body:korblox",
					kind = "korblox",
					name = "Korblox Right Leg",
					image = "rbxthumb://type=Asset&id=" .. tostring(KORBLOX_RIGHT_LEG_ASSET) .. "&w=150&h=150",
				})
			end
		end)
		bodySector:Cheat("Button", "Remove Korblox Right Leg", function()
			if setKorbloxLike(false) then
				forgetAppliedKey("body:korblox")
			end
		end)

		appliedSector:Cheat("Button", "Show Applied Tab", function()
			root.Visible = true
			selectTabByKey("applied")
		end)
		appliedSector:Cheat("Button", "Reapply All", function()
			task.spawn(reapplyAll)
		end)
		appliedSector:Cheat("Button", "Clear Remembered", function()
			for _, key in ipairs(table.clone(appliedOrder)) do
				local item = appliedItems[key]
				if item then
					removeAppliedItem(item)
				end
			end
			if selectedTab.mode == "applied" then
				showApplied()
			end
		end)
	end)

	if not ok then
		setStatus("Finity panel unavailable; using built-in panel. " .. tostring(err), true)
	else
		setStatus("Project Finity panel loaded. Press RightShift to toggle it.", false)
	end
end

for index, tab in ipairs(TAB_DEFS) do
	local button = make("TextButton", {
		BackgroundColor3 = theme.Panel2,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		LayoutOrder = index,
		Size = UDim2.fromOffset(44, 44),
		Text = TAB_ICONS[tab.key] or "•",
		TextColor3 = Color3.fromRGB(205, 211, 222),
		TextSize = 15,
	}, tabBar)
	make("UICorner", { CornerRadius = UDim.new(0, 9) }, button)
	button:SetAttribute("TabKey", tab.key)
	button:SetAttribute("TabLabel", tab.label)
	tabButtons[tab.key] = button

	button.MouseButton1Click:Connect(function()
		selectedTab = tab
		styleTabs()
		if tab.mode == "body" then
			showBodyTools()
		elseif tab.mode == "applied" then
			showApplied()
		elseif tab.mode == "settings" then
			showSettings()
		else
			clearResults()
			setStatus("Search " .. tab.label .. " and apply results locally.", false)
		end
	end)
end

searchButton.MouseButton1Click:Connect(doSearch)
searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doSearch()
	end
end)

previewApply.MouseButton1Click:Connect(function()
	if not selectedPreviewItem then
		setStatus("Select an item to preview first.", true)
		return
	end
	if selectedTab.mode ~= "accessory" and selectedTab.mode ~= "single" then
		setStatus("Switch to a catalog tab before applying the preview.", true)
		return
	end
	applyCatalogItem(selectedPreviewItem)
end)

local dragging = false
local dragStart
local rootStart

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		rootStart = root.Position
	end
end)

titleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - dragStart
	root.Position = UDim2.new(rootStart.X.Scale, rootStart.X.Offset + delta.X, rootStart.Y.Scale, rootStart.Y.Offset + delta.Y)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if waitingForKeybind then
		waitingForKeybind = false
		toggleKey = input.KeyCode
		previewHint.Text = "Toggle UI: " .. toggleKey.Name
		setStatus("Toggle keybind set to " .. toggleKey.Name .. ".", false)
		return
	end

	if input.KeyCode == toggleKey then
		root.Visible = not root.Visible
	end
end)

local function pulse()
	root.Size = UDim2.fromOffset(770, 484)
	TweenService:Create(root, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(790, 500),
	}):Play()
end

function reapplyAll()
	if reapplying then
		return
	end

	reapplying = true
	hiddenState = {}
	faceState = nil

	task.wait(1)
	getHumanoid()

	local applied = 0
	for _, key in ipairs(appliedOrder) do
		local item = appliedItems[key]
		if item then
			local ok = applyStoredItem(item)
			if ok then
				applied += 1
			end
			task.wait(0.08)
		end
	end

	reapplying = false
	if applied > 0 then
		setStatus("Reapplied " .. tostring(applied) .. " item(s) after respawn.", false)
	end
end

localPlayer.CharacterAdded:Connect(function()
	task.spawn(reapplyAll)
end)

styleTabs()
pulse()
if AUTO_LOAD_REMOTE_FINITY or rawget(shared, "Finity") or rawget(shared, "ProjectFinity") or rawget(shared, "finity") then
	task.spawn(tryBuildFinityPanel)
end
searchBox.Text = "fedora"
doSearch()
