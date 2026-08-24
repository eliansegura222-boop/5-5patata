--// HX Boat
--// Build A Boat For Treasure - monochrome gamer GUI + optimized utilities
--// Designed for common Roblox executors. Some functions depend on executor APIs.

--====================================================
-- Services / boot
--====================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local ENV = (getgenv and getgenv()) or _G

if ENV.__BABFT_NIGHTFALL_CLEANUP then
    pcall(ENV.__BABFT_NIGHTFALL_CLEANUP)
end

local alive = true
local connections = {}
local cleanupTasks = {}
local activeStates = {}
local characterCollisionCache = {}
local hazardTouchCache = {}
local espPlayerObjects = {}
local espBlockObjects = {}
local flyObjects = {}
local playerFlyObjects = {}
local boatUtilityObjects = {}
local boatCollisionCache = {}
local boatTouchCache = {}
local hiddenPlayerCache = {}
local hiddenBoatCache = {}
local particleCache = {}
local shadowCache = {}
local pressed = {}
local followTarget
local lastSeat
local selectedQuestTarget
local runsCompleted = 0

-- Lightweight world caches. Expensive Workspace scans are throttled instead of
-- running every frame. This is the main performance safeguard for large BABFT maps.
local worldCache = {
    chest = nil, chestAt = 0,
    stages = nil, stagesAt = 0,
    nearestSeat = nil, seatAt = 0, seatRadius = 0,
    boatRoot = nil, boatRootAt = 0,
    teamSpawn = nil, teamSpawnAt = 0, teamKey = nil,
}
local autoCollectTargets = {}
local autoCollectScanAt = 0
local cachedGoldValueObject = nil

local function track(conn)
    connections[#connections + 1] = conn
    return conn
end

local function addCleanup(fn)
    cleanupTasks[#cleanupTasks + 1] = fn
end

local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
end

local function getChar()
    return LP.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local function toast(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "HX Boat",
            Text = ENV.__HX_TR and ENV.__HX_TR(tostring(text)) or tostring(text),
            Duration = 3
        })
    end)
end

--====================================================
-- Helpers: workspace / BABFT
--====================================================
local function isBasePart(x)
    return x and x:IsA("BasePart")
end

local function findFirstPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function getObjectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, pivot = pcall(function() return obj:GetPivot() end)
        if ok then return pivot.Position end
    end
    local p = findFirstPart(obj)
    return p and p.Position or nil
end

local function tpToCFrame(cf)
    local root = getRoot()
    if not root or not cf then return false end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if activeStates.tweenTP and not activeStates._farmTeleporting then
        local speed = tonumber(ENV.__BABFT_TWEEN_SPEED) or 180
        local distance = (root.Position - cf.Position).Magnitude
        local duration = math.clamp(distance / math.max(speed, 1), 0.05, 12)
        local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = cf})
        tw:Play()
        tw.Completed:Wait()
    else
        root.CFrame = cf
    end
    return true
end

local function tpToPart(part, offset)
    if not isBasePart(part) then return false end
    return tpToCFrame(part.CFrame * CFrame.new(offset or Vector3.new(0, 3.5, 0)))
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function containsAny(s, words)
    s = lower(s)
    for _, w in ipairs(words) do
        if string.find(s, w, 1, true) then return true end
    end
    return false
end

local function findChestPart(forceRefresh)
    local now = os.clock()
    if not forceRefresh and worldCache.chest and worldCache.chest.Parent and (now - worldCache.chestAt) < 10 then
        return worldCache.chest
    end

    -- O(N) scan only: do not recursively scan every Model again while already
    -- traversing descendants. Prefer BoatStages, then fall back to Workspace.
    local function scan(scope, canYield)
        if not scope then return nil end
        local best, bestScore
        local descendants = scope:GetDescendants()
        for i, d in ipairs(descendants) do
            if d:IsA("BasePart") then
                local parent = d.Parent
                local grand = parent and parent.Parent
                local ancestry = lower(d.Name .. " " .. (parent and parent.Name or "") .. " " .. (grand and grand.Name or ""))
                local score
                if containsAny(ancestry, {"goldenchest", "treasurechest"}) then
                    score = 120
                elseif containsAny(ancestry, {"treasure", "theend", "chest"}) then
                    score = 85
                elseif lower(d.Name) == "trigger" and containsAny(ancestry, {"treasure", "chest", "theend"}) then
                    score = 105
                end
                if score and (not bestScore or score > bestScore) then
                    best, bestScore = d, score
                    if score >= 120 then break end
                end
            end
            if canYield and i % 260 == 0 then task.wait() end
        end
        return best
    end

    local boatStages = Workspace:FindFirstChild("BoatStages")
    local best = scan(boatStages, true)
    if not best then best = scan(Workspace, true) end

    worldCache.chest = best
    worldCache.chestAt = now
    return best
end

local function getNormalStages()
    local boatStages = Workspace:FindFirstChild("BoatStages")
    if not boatStages then return nil end
    return boatStages:FindFirstChild("NormalStages") or boatStages
end

local function numericSuffix(name)
    return tonumber(string.match(name or "", "(%d+)%s*$"))
end

local function getStageTargets()
    local now = os.clock()
    if worldCache.stages and (now - worldCache.stagesAt) < 15 then
        local valid = true
        for _, info in ipairs(worldCache.stages) do
            if not info.part or not info.part.Parent then valid = false break end
        end
        if valid then return worldCache.stages end
    end

    local holder = getNormalStages()
    local targets = {}
    if not holder then return targets end

    -- Stage discovery is cached. Yield occasionally so large custom maps cannot
    -- monopolize one frame while their stage models are inspected.
    for i, stage in ipairs(holder:GetChildren()) do
        if stage:IsA("Model") or stage:IsA("Folder") then
            local n = lower(stage.Name)
            if not containsAny(n, {"theend", "treasure", "chest"}) then
                local target = stage:FindFirstChild("StageTrigger", true)
                    or stage:FindFirstChild("Trigger", true)
                    or stage:FindFirstChild("TouchPart", true)
                    or stage:FindFirstChild("Checkpoint", true)
                    or stage:FindFirstChild("DarknessPart", true)
                    or findFirstPart(stage)
                if isBasePart(target) then
                    if (target.Size.X > 80 or target.Size.Y > 80 or target.Size.Z > 80)
                        and not containsAny(lower(target.Name), {"trigger", "touch", "checkpoint"}) then

                        local smallest, smallestVolume
                        for _, candidate in ipairs(stage:GetDescendants()) do
                            if candidate:IsA("BasePart") then
                                local cn = lower(candidate.Name)
                                if not containsAny(cn, {"wall", "darkness", "decor", "water"}) then
                                    local volume = candidate.Size.X * candidate.Size.Y * candidate.Size.Z
                                    if not smallestVolume or volume < smallestVolume then
                                        smallest, smallestVolume = candidate, volume
                                    end
                                end
                            end
                        end
                        if smallest then target = smallest end
                    end

                    targets[#targets + 1] = {
                        name = stage.Name,
                        part = target,
                        index = numericSuffix(stage.Name)
                    }
                end
            end
        end
        if i % 6 == 0 then task.wait() end
    end

    local root = getRoot()
    table.sort(targets, function(a, b)
        if a.index and b.index then return a.index < b.index end
        if a.index then return true end
        if b.index then return false end
        if root then return (a.part.Position - root.Position).Magnitude < (b.part.Position - root.Position).Magnitude end
        return a.name < b.name
    end)

    worldCache.stages = targets
    worldCache.stagesAt = now
    return targets
end

local function touchPart(part)
    local root = getRoot()
    if not root or not isBasePart(part) then return false end
    if firetouchinterest then
        pcall(function()
            firetouchinterest(root, part, 0)
            task.wait(0.05)
            firetouchinterest(root, part, 1)
        end)
        return true
    end
    return tpToPart(part, Vector3.new(0, 2, 0))
end

local function finishRun(stepDelay, farmToken)
    if activeStates._finishBusy then return false, "Ya hay una finalización en curso" end
    activeStates._finishBusy = true
    activeStates._farmTeleporting = true

    local okCall, success, message = pcall(function()
        stepDelay = math.max(tonumber(stepDelay) or 0.40, 0.26)
        local root = getRoot()
        if not root then return false, "Personaje no disponible" end

        local stages = getStageTargets()
        if farmToken and activeStates._farmToken ~= farmToken then return false, "Auto Farm detenido" end

        if #stages == 0 then
            local chest = findChestPart()
            if chest and chest.Parent then
                tpToPart(chest, Vector3.new(0, 2, 0))
                task.wait(stepDelay)
                touchPart(chest)
                runsCompleted += 1
                return true
            end
            return false, "No pude localizar los stages"
        end

        for i, info in ipairs(stages) do
            if not alive then return false, "Cerrado" end
            if farmToken and activeStates._farmToken ~= farmToken then return false, "Auto Farm detenido" end
            if not info.part or not info.part.Parent then
                worldCache.stagesAt = 0
                return false, "Los stages cambiaron; reintentando"
            end

            local r = getRoot()
            if not r then return false, "Personaje no disponible" end
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            r.CFrame = info.part.CFrame * CFrame.new(0, 2, 0)

            -- Spread stage work across frames to avoid streaming/render spikes.
            task.wait(stepDelay)
            touchPart(info.part)
            task.wait(0.08)
            if i % 2 == 0 then task.wait() end
        end

        if farmToken and activeStates._farmToken ~= farmToken then return false, "Auto Farm detenido" end
        local chest = findChestPart()
        if chest and chest.Parent then
            local r = getRoot()
            if not r then return false, "Personaje no disponible" end
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            r.CFrame = chest.CFrame * CFrame.new(0, 2, 0)
            task.wait(math.max(stepDelay, 0.35))
            touchPart(chest)
            runsCompleted += 1
            return true
        end
        return false, "Stages recorridos, pero no encontré el cofre final"
    end)

    activeStates._farmTeleporting = false
    activeStates._finishBusy = false

    if not okCall then
        return false, "Error interno: " .. tostring(success)
    end
    return success, message
end

local function findLaunchButton()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            local text = d:IsA("TextButton") and d.Text or ""
            if containsAny(d.Name .. " " .. text, {"launch", "lanzar"}) then
                return d
            end
        end
    end
end

local function launchBoat()
    local button = findLaunchButton()
    if button then
        local fired = false
        if firesignal then
            fired = pcall(function()
                firesignal(button.MouseButton1Click)
                firesignal(button.Activated)
            end)
        end
        if not fired then fired = pcall(function() button:Activate() end) end
        if fired then return true end
    end

    -- Cache the fallback remote and search only ReplicatedStorage. Scanning
    -- game:GetDescendants() every Auto Launch cycle caused large frame spikes.
    local cached = activeStates._launchRemote
    if cached and cached.Parent then
        local ok = pcall(function() cached:FireServer() end)
        if ok then return true end
        activeStates._launchRemote = nil
    end

    local now = os.clock()
    if activeStates._launchScanAt and now - activeStates._launchScanAt < 20 then return false end
    activeStates._launchScanAt = now

    local rs = game:GetService("ReplicatedStorage")
    local descendants = rs:GetDescendants()
    for i, d in ipairs(descendants) do
        if d:IsA("RemoteEvent") and containsAny(d.Name, {"launch", "lanzar"}) then
            activeStates._launchRemote = d
            return pcall(function() d:FireServer() end)
        end
        if i % 240 == 0 then task.wait() end
    end
    return false
end

local function getSeat()
    local hum = getHum()
    if not hum then return nil end
    local seat = hum.SeatPart
    if seat and seat:IsA("BasePart") then return seat end
    return nil
end

--====================================================
-- Persistent positions
--====================================================
local POS_FILE = "BABFT_Nightfall_Positions.json"
local savedPositions = {}

local function serializeCFrame(cf)
    return {cf:GetComponents()}
end

local function deserializeCFrame(t)
    if type(t) ~= "table" or #t < 12 then return nil end
    return CFrame.new(table.unpack(t, 1, 12))
end

local function savePositionsToDisk()
    if not writefile then return end
    pcall(function()
        writefile(POS_FILE, HttpService:JSONEncode(savedPositions))
    end)
end

local function loadPositionsFromDisk()
    if not (readfile and isfile and isfile(POS_FILE)) then return end
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(POS_FILE))
        if type(decoded) == "table" then savedPositions = decoded end
    end)
end

loadPositionsFromDisk()

--====================================================
-- ESP
--====================================================
local function clearPlayerESP()
    for _, o in pairs(espPlayerObjects) do
        if o.highlight then pcall(function() o.highlight:Destroy() end) end
        if o.billboard then pcall(function() o.billboard:Destroy() end) end
    end
    table.clear(espPlayerObjects)
end

local function addPlayerESP(plr)
    if plr == LP or not plr.Character or espPlayerObjects[plr] then return end
    local char = plr.Character
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not root then return end

    local h = Instance.new("Highlight")
    h.Name = "BABFT_PlayerESP"
    h.Adornee = char
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 0.78
    h.OutlineTransparency = 0.05
    h.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "BABFT_PlayerName"
    bb.Adornee = root
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(180, 34)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.Parent = root

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.fromScale(1, 1)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 13
    txt.TextColor3 = Color3.fromRGB(245, 245, 255)
    txt.TextStrokeTransparency = 0.55
    txt.Text = plr.DisplayName .. "  @" .. plr.Name
    txt.Parent = bb

    espPlayerObjects[plr] = {highlight = h, billboard = bb}
end

local function refreshPlayerESP()
    if not activeStates.playerESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do addPlayerESP(plr) end
    for plr, o in pairs(espPlayerObjects) do
        if not plr.Parent or not plr.Character or o.highlight.Adornee ~= plr.Character then
            if o.highlight then pcall(function() o.highlight:Destroy() end) end
            if o.billboard then pcall(function() o.billboard:Destroy() end) end
            espPlayerObjects[plr] = nil
            if plr.Parent and plr.Character then addPlayerESP(plr) end
        end
    end
end

local function clearBlockESP()
    for _, o in ipairs(espBlockObjects) do pcall(function() o:Destroy() end) end
    table.clear(espBlockObjects)
end

local function isCharacterPart(part)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return true end
    end
    return false
end

local function refreshBlockESP()
    clearBlockESP()
    if not activeStates.blockESP then return end
    local root = getRoot()
    if not root then return end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = getChar()
    if char then params.FilterDescendantsInstances = {char} end
    params.MaxParts = 220

    local ok, nearby = pcall(function()
        return Workspace:GetPartBoundsInRadius(root.Position, 750, params)
    end)
    if not ok or not nearby then return end

    local count = 0
    for _, part in ipairs(nearby) do
        if part:IsA("BasePart")
            and part.Transparency < 1
            and not isCharacterPart(part)
            and (not part.Anchored or containsAny(part.Name, {"block", "boat", "seat", "motor", "jet", "wheel"})) then
            local box = Instance.new("SelectionBox")
            box.Name = "BABFT_BlockESP"
            box.Adornee = part
            box.LineThickness = 0.025
            box.SurfaceTransparency = 1
            box.Parent = part
            espBlockObjects[#espBlockObjects + 1] = box
            count += 1
            if count >= 110 then break end
        end
    end
end

--====================================================
-- Main ScreenGui
--====================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "HX_Boat_Hub"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 2147483647
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(function() Gui.OnTopOfCoreBlur = true end)

if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end

local guiParent
if gethui then
    local ok, result = pcall(gethui)
    if ok and result then guiParent = result end
end
if not guiParent then
    local ok = pcall(function() Gui.Parent = CoreGui end)
    if ok and Gui.Parent then guiParent = CoreGui end
end
if not guiParent then guiParent = LP:WaitForChild("PlayerGui") end
Gui.Parent = guiParent

local Theme = {
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(3, 3, 3),
    panel2 = Color3.fromRGB(8, 8, 8),
    soft = Color3.fromRGB(24, 24, 24),
    accent = Color3.fromRGB(255, 255, 255),
    accent2 = Color3.fromRGB(232, 232, 232),
    text = Color3.fromRGB(248, 248, 248),
    muted = Color3.fromRGB(150, 150, 150),
    danger = Color3.fromRGB(255, 255, 255),
    line = Color3.fromRGB(76, 76, 76),
    good = Color3.fromRGB(255, 255, 255)
}

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    -- Never allow tiny/square-looking corners. Small controls automatically
    -- become capsules/circles when the radius exceeds half their height.
    c.CornerRadius = UDim.new(0, math.max(radius or 16, 14))
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.line
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    pcall(function() s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
    pcall(function() s.LineJoinMode = Enum.LineJoinMode.Round end)
    s.Parent = obj
    return s
end

local function tween(obj, props, time)
    local tw = TweenService:Create(obj, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

--====================================================
-- Language / idioma
--====================================================
ENV.__HX_TEXTS = {
    ["Este script funciona únicamente en Build A Boat For Treasure."] = {es = "Este script funciona únicamente en Build A Boat For Treasure.", en = "This script only works in Build A Boat For Treasure."},
    ["IR AL JUEGO"] = {es = "IR AL JUEGO", en = "GO TO GAME"},
    ["CATEGORÍAS"] = {es = "CATEGORÍAS", en = "CATEGORIES"},
    ["EJECUTAR"] = {es = "EJECUTAR", en = "RUN"},
    ["Buscar..."] = {es = "Buscar...", en = "Search..."},
    ["Buscar jugador..."] = {es = "Buscar jugador...", en = "Search player..."},
    ["Ya hay una finalización en curso"] = {es = "Ya hay una finalización en curso", en = "A finish is already in progress"},
    ["Personaje no disponible"] = {es = "Personaje no disponible", en = "Character unavailable"},
    ["Auto Farm detenido"] = {es = "Farmeo automático detenido", en = "Auto Farm stopped"},
    ["No pude localizar los stages"] = {es = "No pude localizar las etapas", en = "I couldn't locate the stages"},
    ["Cerrado"] = {es = "Cerrado", en = "Closed"},
    ["Los stages cambiaron; reintentando"] = {es = "Las etapas cambiaron; reintentando", en = "The stages changed; retrying"},
    ["Stages recorridos, pero no encontré el cofre final"] = {es = "Etapas recorridas, pero no encontré el cofre final", en = "Stages completed, but I couldn't find the final chest"},
    ["Tu executor no permitió consultar servidores"] = {es = "Tu executor no permitió consultar servidores", en = "Your executor didn't allow server lookup"},
    ["No se pudo leer la lista de servidores"] = {es = "No se pudo leer la lista de servidores", en = "Couldn't read the server list"},
    ["No encontré otro servidor disponible"] = {es = "No encontré otro servidor disponible", en = "I couldn't find another available server"},
    ["Abre el menú de guardar del juego y vuelve a intentarlo"] = {es = "Abre el menú de guardar del juego y vuelve a intentarlo", en = "Open the in-game save menu and try again"},
    ["No pude leer los servidores"] = {es = "No pude leer los servidores", en = "I couldn't read the servers"},
    ["No encontré un servidor con menos jugadores"] = {es = "No encontré un servidor con menos jugadores", en = "I couldn't find a server with fewer players"},
    ["Finalización ejecutada"] = {es = "Finalización ejecutada", en = "Finish completed"},
    ["No se pudo finalizar"] = {es = "No se pudo finalizar", en = "Couldn't finish"},
    ["Quest seleccionada"] = {es = "Misión seleccionada", en = "Quest selected"},
    ["No detecté controles de propulsor compatibles"] = {es = "No detecté controles de propulsor compatibles", en = "I couldn't detect compatible thruster controls"},
    ["Save activado"] = {es = "Guardado activado", en = "Save activated"},
    ["No pude activar Save"] = {es = "No pude activar el guardado", en = "I couldn't activate Save"},
    ["Launch ejecutado"] = {es = "Lanzamiento ejecutado", en = "Launch completed"},
    ["No pude ejecutar el lanzamiento"] = {es = "No pude ejecutar el lanzamiento", en = "I couldn't launch the boat"},
    ["No encontré el cofre final"] = {es = "No encontré el cofre final", en = "I couldn't find the final chest"},
    ["No encontré stages"] = {es = "No encontré etapas", en = "I couldn't find any stages"},
    ["No pude detectar la zona de tu equipo"] = {es = "No pude detectar la zona de tu equipo", en = "I couldn't detect your team area"},
    ["No detecté un barco cercano"] = {es = "No detecté un barco cercano", en = "I couldn't detect a nearby boat"},
    ["No detecté un asiento"] = {es = "No detecté un asiento", en = "I couldn't detect a seat"},
    ["Posiciones eliminadas"] = {es = "Posiciones eliminadas", en = "Saved positions deleted"},
    ["Boat movido"] = {es = "Barco movido", en = "Boat moved"},
    ["No pude detectar jugador/barco"] = {es = "No pude detectar jugador/barco", en = "I couldn't detect the player/boat"},
    ["Anti Water / Anti Damage está ACTIVADO por defecto. HX Boat usa el modo optimizado."] = {es = "Anti agua / Anti daño está ACTIVADO por defecto. HX Boat usa el modo optimizado.", en = "Anti Water / Anti Damage is ENABLED by default. HX Boat uses optimized mode."},
    ["FARM"] = {es = "FARMEO", en = "FARM"},
    ["Finalización, oro y recolección automática."] = {es = "Finalización, oro y recolección automática.", en = "Finishing, gold and automatic collection."},
    ["Auto Farm Gold / Auto Finish"] = {es = "Farmeo automático de oro / Finalización automática", en = "Auto Farm Gold / Auto Finish"},
    ["Completa el recorrido automáticamente para obtener oro."] = {es = "Completa el recorrido automáticamente para obtener oro.", en = "Runs through stages with optimized delays and prevents duplicate executions."},
    ["Auto Finish ahora"] = {es = "Finalizar ahora", en = "Auto Finish Now"},
    ["Completa el recorrido una vez."] = {es = "Completa el recorrido una vez.", en = "Runs one optimized pass without overlapping Auto Farm."},
    ["FINALIZAR"] = {es = "FINALIZAR", en = "FINISH"},
    ["Auto Collect"] = {es = "Recolección automática", en = "Auto Collect"},
    ["Recoge automáticamente recompensas y objetos cercanos."] = {es = "Intenta recoger objetos, cofres y prompts cercanos automáticamente.", en = "Automatically tries to collect nearby pickups, chests and prompts."},
    ["Auto Launch"] = {es = "Lanzamiento automático", en = "Auto Launch"},
    ["Lanza el barco automáticamente cuando sea necesario."] = {es = "Lanza el barco automáticamente cuando sea necesario.", en = "Finds the launch button/remote and activates it automatically."},
    ["Auto Quest compatible"] = {es = "Misión automática compatible", en = "Compatible Auto Quest"},
    ["Completa automáticamente la misión seleccionada cuando esté disponible."] = {es = "Interactúa con el prompt de misión seleccionado cuando el mapa expone misiones/NPCs mediante ProximityPrompt.", en = "Interacts with the selected quest prompt when the map exposes quests/NPCs through ProximityPrompt."},
    ["Quest Selector"] = {es = "Selector de misiones", en = "Quest Selector"},
    ["Elige la misión que quieres automatizar."] = {es = "Busca prompts de misiones/NPCs compatibles y selecciona cuál automatizar.", en = "Finds compatible quest/NPC prompts and lets you choose which one to automate."},
    ["No se detectaron quests compatibles"] = {es = "No se detectaron misiones compatibles", en = "No compatible quests detected"},
    ["No hay misiones compatibles disponibles."] = {es = "No hay misiones compatibles disponibles.", en = "Only quests/NPCs exposed as ProximityPrompt are shown."},
    ["SELECCIONAR"] = {es = "SELECCIONAR", en = "SELECT"},
    ["FARM STATS"] = {es = "ESTADÍSTICAS DE FARMEO", en = "FARM STATS"},
    ["Esperando datos de oro..."] = {es = "Esperando datos de oro...", en = "Waiting for gold data..."},
    ["BARCO"] = {es = "BARCO", en = "BOAT"},
    ["Control de vuelo y velocidad del asiento/barco que estés usando."] = {es = "Control de vuelo y velocidad del asiento/barco que estés usando.", en = "Flight and speed controls for the seat/boat you are using."},
    ["Boat Fly"] = {es = "Vuelo del barco", en = "Boat Fly"},
    ["WASD para moverte, Espacio para subir y Ctrl para bajar."] = {es = "WASD para moverte, Espacio para subir y Ctrl para bajar.", en = "Use WASD to move, Space to go up and Ctrl to go down."},
    ["Boat Speed"] = {es = "Velocidad del barco", en = "Boat Speed"},
    ["Aplica un boost de velocidad mientras conduces un asiento del barco."] = {es = "Aplica un aumento de velocidad mientras conduces un asiento del barco.", en = "Applies a speed boost while you are driving a boat seat."},
    ["Potencia del barco"] = {es = "Potencia del barco", en = "Boat Power"},
    ["Velocidad usada por Boat Fly, Boat Speed y Auto Pilot."] = {es = "Velocidad usada por Vuelo del barco, Velocidad del barco y Piloto automático.", en = "Speed used by Boat Fly, Boat Speed and Auto Pilot."},
    ["Auto Pilot"] = {es = "Piloto automático", en = "Auto Pilot"},
    ["Guía el barco automáticamente hacia el tesoro."] = {es = "Guía el barco automáticamente hacia el tesoro.", en = "Automatically steers and pushes the detected boat toward the Treasure."},
    ["Boat Stabilizer"] = {es = "Estabilizador del barco", en = "Boat Stabilizer"},
    ["Mantiene el barco vertical y reduce giros descontrolados."] = {es = "Mantiene el barco vertical y reduce giros descontrolados.", en = "Keeps the boat upright and reduces uncontrolled spinning."},
    ["Boat Anti Flip"] = {es = "Anti vuelco del barco", en = "Boat Anti Flip"},
    ["Endereza el barco automáticamente si se vuelca."] = {es = "Endereza el barco automáticamente si se vuelca.", en = "Automatically rights the boat when it detects that it has flipped."},
    ["Boat Noclip"] = {es = "Noclip del barco", en = "Boat Noclip"},
    ["Permite que el barco atraviese obstáculos."] = {es = "Desactiva colisiones locales de la estructura conectada al asiento/barco detectado.", en = "Disables local collisions for the assembly connected to the detected seat/boat."},
    ["Protect Boat"] = {es = "Proteger barco", en = "Protect Boat"},
    ["Ayuda a reducir golpes y daños durante el recorrido."] = {es = "Ayuda a reducir golpes y daños durante el recorrido.", en = "Reduces local contact on boat parts; it does not force server-side invincibility."},
    ["Infinite Fuel"] = {es = "Combustible infinito", en = "Infinite Fuel"},
    ["Mantiene el combustible y la energía del barco."] = {es = "Mantiene altos los valores de combustible/carga/energía detectados dentro del barco.", en = "Keeps detected Fuel/Charge/Energy values inside the boat high."},
    ["Propeller / Thruster Control"] = {es = "Control de hélices / propulsores", en = "Propeller / Thruster Control"},
    ["Activa la propulsión disponible del barco."] = {es = "Activa la propulsión disponible del barco.", en = "Activates the boat's available propulsion."},
    ["ACTIVAR"] = {es = "ACTIVAR", en = "ACTIVATE"},
    ["Auto Activate Thrusters"] = {es = "Activar propulsores automáticamente", en = "Auto Activate Thrusters"},
    ["Mantiene la propulsión del barco activada automáticamente."] = {es = "Intenta activar automáticamente los propulsores detectados mientras esté habilitado.", en = "Automatically tries to activate detected thrusters while enabled."},
    ["Auto Sit"] = {es = "Sentarse automáticamente", en = "Auto Sit"},
    ["Busca un asiento cercano del barco y vuelve a sentarte automáticamente."] = {es = "Busca un asiento cercano del barco y vuelve a sentarte automáticamente.", en = "Finds a nearby boat seat and automatically sits you back down."},
    ["Seat Lock"] = {es = "Bloqueo de asiento", en = "Seat Lock"},
    ["Recuerda tu último asiento e intenta volver a sentarte si un obstáculo te expulsa."] = {es = "Recuerda tu último asiento e intenta volver a sentarte si un obstáculo te expulsa.", en = "Remembers your last seat and tries to sit you back down if an obstacle ejects you."},
    ["Anti Seat"] = {es = "Anti asiento", en = "Anti Seat"},
    ["Evita permanecer sentado cuando no quieras usar asientos."] = {es = "Evita permanecer sentado cuando no quieras usar asientos.", en = "Prevents you from staying seated when you do not want to use seats."},
    ["Load Build / Auto Load Slot"] = {es = "Cargar construcción / Cargar slot automáticamente", en = "Load Build / Auto Load Slot"},
    ["Carga rápidamente una construcción guardada."] = {es = "Carga rápidamente una construcción guardada.", en = "Quickly loads a saved build."},
    ["Load Build / Slots"] = {es = "Cargar construcción / Slots", en = "Load Build / Slots"},
    ["No encontré botones Load/Slot"] = {es = "No encontré botones Cargar/Slot", en = "I couldn't find Load/Slot buttons"},
    ["Abre primero el menú de guardar/cargar del juego."] = {es = "Abre primero el menú de guardar/cargar del juego.", en = "Open the in-game save/load menu first."},
    ["Cargar esta opción"] = {es = "Cargar esta opción", en = "Activate this in-game menu button"},
    ["ABRIR SLOTS"] = {es = "ABRIR SLOTS", en = "OPEN SLOTS"},
    ["Auto Save Build"] = {es = "Guardado automático de construcción", en = "Auto Save Build"},
    ["Guarda rápidamente tu construcción actual."] = {es = "Activa el botón Guardar visible del menú oficial cuando esté disponible.", en = "Activates the visible Save button in the official menu when available."},
    ["GUARDAR"] = {es = "GUARDAR", en = "SAVE"},
    ["Instant Launch"] = {es = "Lanzamiento instantáneo", en = "Instant Launch"},
    ["Carga y lanza el barco rápidamente."] = {es = "Carga y lanza el barco rápidamente.", en = "Tries to load the visible slot and launch the boat immediately."},
    ["LANZAR"] = {es = "LANZAR", en = "LAUNCH"},
    ["MOVIMIENTO"] = {es = "MOVIMIENTO", en = "MOVEMENT"},
    ["Controles del personaje y protección básica."] = {es = "Controles del personaje y protección básica.", en = "Character controls and basic protection."},
    ["Noclip"] = {es = "Noclip", en = "Noclip"},
    ["Desactiva colisiones de las partes del personaje mientras esté activo."] = {es = "Desactiva colisiones de las partes del personaje mientras esté activo.", en = "Disables collisions on character parts while enabled."},
    ["Anti Water / Anti Damage"] = {es = "Anti agua / Anti daño", en = "Anti Water / Anti Damage"},
    ["Reduce el daño de agua y otros peligros y ayuda a volver a una zona segura."] = {es = "Bloquea peligros locales conocidos y vuelve a una posición segura si detecta daño.", en = "Blocks known local hazards and returns to a safe position if damage is detected."},
    ["Anti Void"] = {es = "Anti vacío", en = "Anti Void"},
    ["Si caes por debajo del límite del mapa, vuelve a la última posición segura o a tu zona de equipo."] = {es = "Si caes por debajo del límite del mapa, vuelve a la última posición segura o a tu zona de equipo.", en = "If you fall below the map limit, returns you to the last safe position or your team area."},
    ["No Fall / Anti Fall"] = {es = "Sin caída / Anti caída", en = "No Fall / Anti Fall"},
    ["Limita la velocidad de caída para reducir caídas bruscas y mantener una recuperación segura."] = {es = "Limita la velocidad de caída para reducir caídas bruscas y mantener una recuperación segura.", en = "Limits falling speed to reduce hard falls and maintain safer recovery."},
    ["Infinite Jump"] = {es = "Salto infinito", en = "Infinite Jump"},
    ["Permite volver a saltar en el aire usando Espacio."] = {es = "Permite volver a saltar en el aire usando Espacio.", en = "Lets you jump again in the air using Space."},
    ["Player Fly"] = {es = "Vuelo del jugador", en = "Player Fly"},
    ["Vuelo del personaje separado del Boat Fly: WASD, Espacio y Ctrl."] = {es = "Vuelo del personaje separado del vuelo del barco: WASD, Espacio y Ctrl.", en = "Character flight separate from Boat Fly: WASD, Space and Ctrl."},
    ["Player Fly Speed"] = {es = "Velocidad de vuelo del jugador", en = "Player Fly Speed"},
    ["Velocidad usada únicamente por Player Fly."] = {es = "Velocidad usada únicamente por el vuelo del jugador.", en = "Speed used only by Player Fly."},
    ["Gravity"] = {es = "Gravedad", en = "Gravity"},
    ["Ajusta la gravedad del juego."] = {es = "Ajusta la gravedad del juego.", en = "Adjusts the game's gravity."},
    ["Character Speed"] = {es = "Velocidad del personaje", en = "Character Speed"},
    ["Ajusta la velocidad al caminar."] = {es = "Ajusta la velocidad al caminar.", en = "Character WalkSpeed."},
    ["Character Jump"] = {es = "Salto del personaje", en = "Character Jump"},
    ["Ajusta la potencia de salto."] = {es = "Ajusta la potencia de salto.", en = "Character JumpPower / JumpHeight."},
    ["TELEPORT"] = {es = "TELETRANSPORTE", en = "TELEPORT"},
    ["Stages, cofre, posiciones guardadas y jugadores."] = {es = "Etapas, cofre, posiciones guardadas y jugadores.", en = "Stages, chest, saved positions and players."},
    ["Teleport por zonas"] = {es = "Teletransporte por zonas", en = "Teleport by Zones"},
    ["Muestra las zonas disponibles para teletransportarte."] = {es = "Muestra las etapas detectadas en el mapa actual.", en = "Shows the stages detected in the current map."},
    ["Zonas detectadas"] = {es = "Zonas detectadas", en = "Detected Zones"},
    ["No se encontraron stages"] = {es = "No se encontraron etapas", en = "No stages found"},
    ["El mapa todavía puede estar cargando."] = {es = "El mapa todavía puede estar cargando.", en = "The map may still be loading."},
    ["Ir a esta zona"] = {es = "Teletransportar al punto detectado de la etapa", en = "Teleport to the detected stage point"},
    ["TREASURE / COFRE FINAL"] = {es = "TESORO / COFRE FINAL", en = "TREASURE / FINAL CHEST"},
    ["Teleport al final del recorrido"] = {es = "Teletransportar al final del recorrido", en = "Teleport to the end of the route"},
    ["VER ZONAS"] = {es = "VER ZONAS", en = "VIEW ZONES"},
    ["Teleport al cofre"] = {es = "Teletransporte al cofre", en = "Teleport to Chest"},
    ["Localiza el Golden Chest / Treasure del mapa y te lleva a él."] = {es = "Localiza el Golden Chest / Treasure del mapa y te lleva a él.", en = "Finds the map Golden Chest / Treasure and teleports you to it."},
    ["IR AL COFRE"] = {es = "IR AL COFRE", en = "GO TO CHEST"},
    ["Teleport Last Stage"] = {es = "Teletransporte a la última etapa", en = "Teleport to Last Stage"},
    ["Te lleva a la última zona antes del tesoro."] = {es = "Te lleva a la última etapa dinámica detectada antes del Tesoro.", en = "Takes you to the last dynamically detected stage before the Treasure."},
    ["ÚLTIMO STAGE"] = {es = "ÚLTIMA ETAPA", en = "LAST STAGE"},
    ["Return To Team"] = {es = "Volver al equipo", en = "Return to Team"},
    ["Te lleva de vuelta a la zona de tu equipo."] = {es = "Te lleva de vuelta a la zona de tu equipo.", en = "Finds the spawn/area associated with your team and returns to it."},
    ["VOLVER"] = {es = "VOLVER", en = "RETURN"},
    ["Teleport To Boat"] = {es = "Teletransporte al barco", en = "Teleport to Boat"},
    ["Te lleva de vuelta a tu barco."] = {es = "Vuelve a la estructura del barco/asiento más probable.", en = "Returns to the most likely boat/seat assembly."},
    ["IR AL BARCO"] = {es = "IR AL BARCO", en = "GO TO BOAT"},
    ["Teleport To Seat"] = {es = "Teletransporte al asiento", en = "Teleport to Seat"},
    ["Te lleva al asiento de tu barco e intenta sentarte."] = {es = "Te lleva al asiento de tu barco e intenta sentarte.", en = "Finds a nearby seat, teleports you to it and tries to sit you down."},
    ["SENTARSE"] = {es = "SENTARSE", en = "SIT"},
    ["Click TP"] = {es = "TP con clic", en = "Click TP"},
    ["Con el toggle activo, haz clic en el mundo para teletransportarte al punto seleccionado."] = {es = "Con la opción activa, haz clic en el mundo para teletransportarte al punto seleccionado.", en = "With the toggle enabled, click the world to teleport to the selected point."},
    ["Tween TP"] = {es = "TP progresivo", en = "Tween TP"},
    ["Convierte los teleports del hub en desplazamientos progresivos en vez de instantáneos."] = {es = "Convierte los teletransportes del panel en desplazamientos progresivos en vez de instantáneos.", en = "Turns hub teleports into smooth movement instead of instant teleports."},
    ["Tween TP Speed"] = {es = "Velocidad del TP progresivo", en = "Tween TP Speed"},
    ["Velocidad del desplazamiento progresivo."] = {es = "Velocidad del desplazamiento progresivo.", en = "Speed of smooth teleport movement."},
    ["Teleport To Quests / NPCs"] = {es = "Teletransporte a misiones / NPCs", en = "Teleport to Quests / NPCs"},
    ["Muestra misiones y NPC disponibles para teletransportarte."] = {es = "Lista NPCs, misiones y prompts relevantes detectados en el mapa.", en = "Lists relevant NPCs, quests and prompts detected in the map."},
    ["Quests / NPCs"] = {es = "Misiones / NPCs", en = "Quests / NPCs"},
    ["Ir a este objetivo"] = {es = "Teletransportar al objetivo detectado", en = "Teleport to the detected target"},
    ["No se detectaron NPCs/quests"] = {es = "No se detectaron NPCs/misiones", en = "No NPCs/quests detected"},
    ["No hay objetivos disponibles."] = {es = "No hay objetivos disponibles.", en = "The current map does not expose compatible names."},
    ["Guardar posición"] = {es = "Guardar posición", en = "Save Position"},
    ["Guarda tu posición actual para volver a ella más tarde."] = {es = "Guarda tu posición actual para volver a ella más tarde.", en = "Saves your current CFrame; uses a file if the executor supports it."},
    ["Posiciones guardadas"] = {es = "Posiciones guardadas", en = "Saved Positions"},
    ["Abre la lista para teletransportarte o eliminar posiciones."] = {es = "Abre la lista para teletransportarte o eliminar posiciones.", en = "Opens the list to teleport to or delete saved positions."},
    ["No hay posiciones"] = {es = "No hay posiciones", en = "No saved positions"},
    ["Usa “Guardar posición” primero."] = {es = "Usa “Guardar posición” primero.", en = "Use “Save Position” first."},
    ["Click: teletransportar"] = {es = "Clic: teletransportar", en = "Click: teleport"},
    ["Eliminar todas"] = {es = "Eliminar todas", en = "Delete All"},
    ["Borra todas las posiciones guardadas."] = {es = "Borra todas las posiciones guardadas.", en = "Deletes all saved positions."},
    ["ABRIR"] = {es = "ABRIR", en = "OPEN"},
    ["Teleport a jugadores"] = {es = "Teletransporte a jugadores", en = "Teleport to Players"},
    ["Busca jugadores y usa acciones rápidas sobre ellos."] = {es = "Buscador de jugadores con Teletransporte, Espectar, Seguir y Llevar barco al jugador.", en = "Player search with Teleport, Spectate, Follow and Bring Boat To Player."},
    ["Teleport"] = {es = "Teletransportar", en = "Teleport"},
    ["Ir junto a este jugador"] = {es = "Ir junto a este jugador", en = "Teleport next to this player"},
    ["Spectate Player"] = {es = "Espectar jugador", en = "Spectate Player"},
    ["Poner la cámara sobre este jugador"] = {es = "Poner la cámara sobre este jugador", en = "Set the camera to this player"},
    ["Follow Player"] = {es = "Seguir jugador", en = "Follow Player"},
    ["Seguir automáticamente a este jugador"] = {es = "Seguir automáticamente a este jugador", en = "Automatically follow this player"},
    ["Bring Boat To Player"] = {es = "Llevar barco al jugador", en = "Bring Boat To Player"},
    ["Mueve tu barco cerca de este jugador."] = {es = "Mueve tu barco detectado cerca de este jugador cuando tienes control local de la estructura.", en = "Moves your detected boat near this player when you have local control of the assembly."},
    ["Detener Follow / Spectate"] = {es = "Detener seguimiento / espectador", en = "Stop Follow / Spectate"},
    ["Vuelve la cámara a tu personaje y detiene el seguimiento."] = {es = "Vuelve la cámara a tu personaje y detiene el seguimiento.", en = "Returns the camera to your character and stops following."},
    ["Jugadores"] = {es = "Jugadores", en = "Players"},
    ["No hay otros jugadores"] = {es = "No hay otros jugadores", en = "No other players"},
    ["Servidor vacío."] = {es = "Servidor vacío.", en = "Empty server."},
    ["JUGADORES"] = {es = "JUGADORES", en = "PLAYERS"},
    ["VISUALES"] = {es = "VISUALES", en = "VISUALS"},
    ["Resalta jugadores y bloques cercanos."] = {es = "Resalta jugadores y bloques cercanos.", en = "ESP for players and nearby blocks."},
    ["ESP de jugadores"] = {es = "ESP de jugadores", en = "Player ESP"},
    ["Resalta a los demás jugadores y muestra sus nombres."] = {es = "Resaltado AlwaysOnTop + nombre de cada jugador.", en = "AlwaysOnTop highlight + each player name."},
    ["ESP de bloques"] = {es = "ESP de bloques", en = "Block ESP"},
    ["Resalta los bloques cercanos."] = {es = "Resalta los bloques cercanos.", en = "Marks up to 140 nearby blocks/parts with slow refresh to reduce load."},
    ["RENDIMIENTO"] = {es = "RENDIMIENTO", en = "PERFORMANCE"},
    ["Opciones para mejorar el rendimiento visual."] = {es = "Opciones locales para reducir carga gráfica sin tocar tus funciones de farmeo.", en = "Local options to reduce graphics load without affecting farm features."},
    ["FPS Booster"] = {es = "Potenciador de FPS", en = "FPS Booster"},
    ["Reduce efectos gráficos para mejorar los FPS."] = {es = "Reduce efectos gráficos para mejorar los FPS.", en = "Reduces particles, shadows, water and local rendering quality while enabled."},
    ["Hide Other Boats"] = {es = "Ocultar otros barcos", en = "Hide Other Boats"},
    ["Oculta los barcos de otros jugadores."] = {es = "Oculta localmente estructuras de otros asientos/barcos detectados.", en = "Locally hides assemblies from other detected seats/boats."},
    ["Hide Other Players"] = {es = "Ocultar otros jugadores", en = "Hide Other Players"},
    ["Oculta a los demás jugadores."] = {es = "Oculta a los demás jugadores.", en = "Locally hides other players’ characters."},
    ["Remove Water Effects"] = {es = "Quitar efectos del agua", en = "Remove Water Effects"},
    ["Reduce los efectos visuales del agua."] = {es = "Reduce los efectos visuales del agua.", en = "Locally removes Terrain water waves, reflectance and visibility."},
    ["Remove Particles"] = {es = "Quitar partículas", en = "Remove Particles"},
    ["Reduce partículas y efectos visuales."] = {es = "Reduce partículas y efectos visuales.", en = "Reduces particles and visual effects."},
    ["Disable Shadows"] = {es = "Desactivar sombras", en = "Disable Shadows"},
    ["Desactiva las sombras para mejorar el rendimiento."] = {es = "Desactiva las sombras para mejorar el rendimiento.", en = "Locally disables GlobalShadows and CastShadow."},
    ["Low Graphics"] = {es = "Gráficos bajos", en = "Low Graphics"},
    ["Reduce la calidad gráfica para aumentar los FPS."] = {es = "Reduce la calidad gráfica para aumentar los FPS.", en = "Forces low rendering quality and reduces heavy effects."},
    ["SERVIDOR"] = {es = "SERVIDOR", en = "SERVER"},
    ["Reconexión y cambio de servidor."] = {es = "Reconexión y cambio de servidor.", en = "Reconnect and server switching."},
    ["Auto Rejoin"] = {es = "Reconexión automática", en = "Auto Rejoin"},
    ["Vuelve a entrar automáticamente si pierdes la conexión."] = {es = "Vuelve a entrar automáticamente si pierdes la conexión.", en = "If Roblox reports a connection error, tries to return to the same server."},
    ["Anti AFK"] = {es = "Anti AFK", en = "Anti AFK"},
    ["Evita que te expulsen por inactividad."] = {es = "Evita que te expulsen por inactividad.", en = "Prevents inactivity kicks."},
    ["Rejoin"] = {es = "Reconectar", en = "Rejoin"},
    ["Vuelve a entrar al servidor actual."] = {es = "Vuelve a entrar al servidor actual.", en = "Rejoins the current server."},
    ["REJOIN"] = {es = "RECONECTAR", en = "REJOIN"},
    ["Server Hop"] = {es = "Cambiar servidor", en = "Server Hop"},
    ["Busca otro servidor público con espacio disponible."] = {es = "Busca otro servidor público con espacio disponible.", en = "Finds another public server with available space."},
    ["SERVER HOP"] = {es = "CAMBIAR SERVIDOR", en = "SERVER HOP"},
    ["Low Player Server"] = {es = "Servidor con pocos jugadores", en = "Low Player Server"},
    ["Busca entre los servidores públicos disponibles y entra al de menor población encontrado."] = {es = "Busca entre los servidores públicos disponibles y entra al de menor población encontrado.", en = "Searches available public servers and joins the lowest-population one found."},
    ["Auto Crear Barco"] = {es = "Auto Crear Barco", en = "Auto Build Boat"},
    ["Crea automáticamente uno de tres barcos usando tus bloques disponibles."] = {es = "Crea automáticamente uno de tres barcos usando tus bloques disponibles.", en = "Automatically builds one of three boats using your available blocks."},
    ["CONSTRUIR"] = {es = "CONSTRUIR", en = "BUILD"},
    ["Selecciona un barco"] = {es = "Selecciona un barco", en = "Select a Boat"},
    ["Básico"] = {es = "Básico", en = "Basic"},
    ["Lancha compacta con proa definida, casco cerrado, laterales, asiento elevado y motor trasero."] = {es = "Lancha compacta con proa definida, casco cerrado, laterales, asiento elevado y motor trasero.", en = "Small lightweight wooden boat with a seat and basic side protection."},
    ["Intermedio"] = {es = "Intermedio", en = "Intermediate"},
    ["Lancha reforzada con proa en V, cubierta, cockpit abierto, parabrisas y motor trasero."] = {es = "Lancha reforzada con proa en V, cubierta, cockpit abierto, parabrisas y motor trasero.", en = "Wider reinforced hull with better stability and protection."},
    ["Avanzado"] = {es = "Avanzado", en = "Advanced"},
    ["Barco grande con proa escalonada, cubierta completa, cabina abierta, parabrisas y doble motor."] = {es = "Barco grande con proa escalonada, cubierta completa, cabina abierta, parabrisas y doble motor.", en = "Large reinforced hull with double side protection, cabin and seat."},
    ["Ya se está creando un barco."] = {es = "Ya se está creando un barco.", en = "A boat is already being built."},
    ["Desactiva Auto Farm antes de crear un barco."] = {es = "Desactiva Auto Farm antes de crear un barco.", en = "Disable Auto Farm before building a boat."},
    ["No encontré BuildingTool. Abre el modo de construcción e inténtalo otra vez."] = {es = "No encontré BuildingTool. Abre el modo de construcción e inténtalo otra vez.", en = "BuildingTool was not found. Open build mode and try again."},
    ["No pude detectar tu zona de construcción."] = {es = "No pude detectar tu zona de construcción.", en = "I couldn't detect your build zone."},
    ["No encontré los datos de bloques del jugador."] = {es = "No encontré los datos de bloques del jugador.", en = "Player block data was not found."},
    ["Creando nuevo barco. El resultado dependerá de los materiales y de la cantidad que tengas de cada uno."] = {es = "Creando nuevo barco. El resultado dependerá de los materiales y de la cantidad que tengas de cada uno.", en = "Creating a new boat. The result will depend on the materials you own and how many of each you have."},
    ["Motor añadido: "] = {es = "Motor añadido: ", en = "Engine added: "},
    ["No tienes un motor compatible; crearé el barco sin motor."] = {es = "No tienes un motor compatible; crearé el barco sin motor.", en = "You don't have a compatible engine; the boat will be built without one."},
    ["No tienes asiento compatible; crearé el barco sin asiento."] = {es = "No tienes asiento compatible; crearé el barco sin asiento.", en = "You don't have a compatible seat; the boat will be built without one."},
    ["Material principal: "] = {es = "Material principal: ", en = "Main material: "},
    [" · Bloques disponibles usados: "] = {es = " · Bloques disponibles usados: ", en = " · Available blocks used: "},
    ["Creando barco básico..."] = {es = "Creando barco básico...", en = "Building basic boat..."},
    ["Creando barco intermedio..."] = {es = "Creando barco intermedio...", en = "Building intermediate boat..."},
    ["Creando barco avanzado..."] = {es = "Creando barco avanzado...", en = "Building advanced boat..."},
    ["Barco creado correctamente."] = {es = "Barco creado correctamente.", en = "Boat built successfully."},
    ["No se pudo completar el barco: "] = {es = "No se pudo completar el barco: ", en = "The boat could not be completed: "},
    ["Recursos insuficientes"] = {es = "Recursos insuficientes", en = "Insufficient Resources"},
    ["SÍ, COMPRAR Y CONTINUAR"] = {es = "SÍ, COMPRAR Y CONTINUAR", en = "YES, BUY AND CONTINUE"},
    ["NO, CONTINUAR SIN COMPRAR"] = {es = "NO, CONTINUAR SIN COMPRAR", en = "NO, CONTINUE WITHOUT BUYING"},
    ["HX Boat comprará únicamente con el oro del juego y continuará automáticamente."] = {es = "HX Boat comprará únicamente con el oro del juego y continuará automáticamente.", en = "HX Boat will only use your in-game Gold and continue automatically."},
    ["Continuar con los materiales actuales; el barco puede reducirse."] = {es = "Continuar con los materiales actuales; el barco puede reducirse.", en = "Continue with current materials; the boat may be reduced."},
    ["No tienes suficiente oro para comprar lo que falta. Se usará únicamente lo que tengas."] = {es = "No tienes suficiente oro para comprar lo que falta. Se usará únicamente lo que tengas.", en = "You don't have enough Gold to buy the missing resources. Only what you currently own will be used."},
    ["No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida."] = {es = "No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.", en = "There aren't enough materials for the selected size; I'll build a reduced version."},
    ["Compra automática completada. Continuando construcción..."] = {es = "Compra automática completada. Continuando construcción...", en = "Automatic purchase completed. Continuing construction..."},
    ["No pude completar una compra automática; continuaré con los recursos disponibles."] = {es = "No pude completar una compra automática; continuaré con los recursos disponibles.", en = "I couldn't complete an automatic purchase; I'll continue with the available resources."},
    ["Sistema de conducción añadido: Boat Motor + Car Seat."] = {es = "Sistema de conducción añadido: Boat Motor + Car Seat.", en = "Drive system added: Boat Motor + Car Seat."},
    ["No hay Boat Motor o Car Seat disponible; el barco no tendrá conducción normal."] = {es = "No hay Boat Motor o Car Seat disponible; el barco no tendrá conducción normal.", en = "No Boat Motor or Car Seat is available; the boat won't have normal driving controls."},
    ["Completa el recorrido automáticamente para obtener oro."] = {es = "Completa el recorrido automáticamente para obtener oro.", en = "Automatically completes the run to earn Gold."},
    ["Completa el recorrido una vez."] = {es = "Completa el recorrido una vez.", en = "Completes the run once."},
    ["Recoge automáticamente recompensas y objetos cercanos."] = {es = "Recoge automáticamente recompensas y objetos cercanos.", en = "Automatically collects nearby rewards and items."},
    ["Lanza el barco automáticamente cuando sea necesario."] = {es = "Lanza el barco automáticamente cuando sea necesario.", en = "Automatically launches the boat when needed."},
    ["Completa automáticamente la misión seleccionada cuando esté disponible."] = {es = "Completa automáticamente la misión seleccionada cuando esté disponible.", en = "Automatically completes the selected quest when available."},
    ["Elige la misión que quieres automatizar."] = {es = "Elige la misión que quieres automatizar.", en = "Choose the quest you want to automate."},
    ["No hay misiones compatibles disponibles."] = {es = "No hay misiones compatibles disponibles.", en = "No compatible quests are available."},
    ["Guía el barco automáticamente hacia el tesoro."] = {es = "Guía el barco automáticamente hacia el tesoro.", en = "Automatically guides the boat toward the treasure."},
    ["Endereza el barco automáticamente si se vuelca."] = {es = "Endereza el barco automáticamente si se vuelca.", en = "Automatically rights the boat if it flips."},
    ["Permite que el barco atraviese obstáculos."] = {es = "Permite que el barco atraviese obstáculos.", en = "Allows the boat to pass through obstacles."},
    ["Ayuda a reducir golpes y daños durante el recorrido."] = {es = "Ayuda a reducir golpes y daños durante el recorrido.", en = "Helps reduce impacts and damage during the run."},
    ["Mantiene el combustible y la energía del barco."] = {es = "Mantiene el combustible y la energía del barco.", en = "Keeps the boat's fuel and energy available."},
    ["Activa la propulsión disponible del barco."] = {es = "Activa la propulsión disponible del barco.", en = "Activates the boat's available propulsion."},
    ["Mantiene la propulsión del barco activada automáticamente."] = {es = "Mantiene la propulsión del barco activada automáticamente.", en = "Keeps the boat's propulsion activated automatically."},
    ["Carga rápidamente una construcción guardada."] = {es = "Carga rápidamente una construcción guardada.", en = "Quickly loads a saved build."},
    ["Guarda rápidamente tu construcción actual."] = {es = "Guarda rápidamente tu construcción actual.", en = "Quickly saves your current build."},
    ["Carga y lanza el barco rápidamente."] = {es = "Carga y lanza el barco rápidamente.", en = "Quickly loads and launches the boat."},
    ["Reduce el daño de agua y otros peligros y ayuda a volver a una zona segura."] = {es = "Reduce el daño de agua y otros peligros y ayuda a volver a una zona segura.", en = "Reduces damage from water and other hazards and helps return you to safety."},
    ["Ajusta la gravedad del juego."] = {es = "Ajusta la gravedad del juego.", en = "Adjusts the game's gravity."},
    ["Ajusta la velocidad al caminar."] = {es = "Ajusta la velocidad al caminar.", en = "Adjusts walking speed."},
    ["Ajusta la potencia de salto."] = {es = "Ajusta la potencia de salto.", en = "Adjusts jump power."},
    ["Muestra las zonas disponibles para teletransportarte."] = {es = "Muestra las zonas disponibles para teletransportarte.", en = "Shows available areas you can teleport to."},
    ["Te lleva a la última zona antes del tesoro."] = {es = "Te lleva a la última zona antes del tesoro.", en = "Takes you to the last area before the treasure."},
    ["Te lleva de vuelta a la zona de tu equipo."] = {es = "Te lleva de vuelta a la zona de tu equipo.", en = "Takes you back to your team area."},
    ["Te lleva de vuelta a tu barco."] = {es = "Te lleva de vuelta a tu barco.", en = "Takes you back to your boat."},
    ["Te lleva al asiento de tu barco e intenta sentarte."] = {es = "Te lleva al asiento de tu barco e intenta sentarte.", en = "Takes you to your boat seat and tries to sit you down."},
    ["Muestra misiones y NPC disponibles para teletransportarte."] = {es = "Muestra misiones y NPC disponibles para teletransportarte.", en = "Shows quests and NPCs available for teleporting."},
    ["Ir a este objetivo"] = {es = "Ir a este objetivo", en = "Go to this target"},
    ["Guarda tu posición actual para volver a ella más tarde."] = {es = "Guarda tu posición actual para volver a ella más tarde.", en = "Saves your current position so you can return later."},
    ["Busca jugadores y usa acciones rápidas sobre ellos."] = {es = "Busca jugadores y usa acciones rápidas sobre ellos.", en = "Find players and use quick actions on them."},
    ["Mueve tu barco cerca de este jugador."] = {es = "Mueve tu barco cerca de este jugador.", en = "Moves your boat near this player."},
    ["Resalta jugadores y bloques cercanos."] = {es = "Resalta jugadores y bloques cercanos.", en = "Highlights nearby players and blocks."},
    ["Resalta a los demás jugadores y muestra sus nombres."] = {es = "Resalta a los demás jugadores y muestra sus nombres.", en = "Highlights other players and shows their names."},
    ["Resalta los bloques cercanos."] = {es = "Resalta los bloques cercanos.", en = "Highlights nearby blocks."},
    ["Opciones para mejorar el rendimiento visual."] = {es = "Opciones para mejorar el rendimiento visual.", en = "Options to improve visual performance."},
    ["Reduce efectos gráficos para mejorar los FPS."] = {es = "Reduce efectos gráficos para mejorar los FPS.", en = "Reduces graphical effects to improve FPS."},
    ["Oculta los barcos de otros jugadores."] = {es = "Oculta los barcos de otros jugadores.", en = "Hides other players' boats."},
    ["Oculta a los demás jugadores."] = {es = "Oculta a los demás jugadores.", en = "Hides other players."},
    ["Reduce los efectos visuales del agua."] = {es = "Reduce los efectos visuales del agua.", en = "Reduces water visual effects."},
    ["Reduce partículas y efectos visuales."] = {es = "Reduce partículas y efectos visuales.", en = "Reduces particles and visual effects."},
    ["Desactiva las sombras para mejorar el rendimiento."] = {es = "Desactiva las sombras para mejorar el rendimiento.", en = "Disables shadows to improve performance."},
    ["Reduce la calidad gráfica para aumentar los FPS."] = {es = "Reduce la calidad gráfica para aumentar los FPS.", en = "Lowers graphics quality to increase FPS."},
    ["Vuelve a entrar automáticamente si pierdes la conexión."] = {es = "Vuelve a entrar automáticamente si pierdes la conexión.", en = "Automatically rejoins if you lose connection."},
    ["Evita que te expulsen por inactividad."] = {es = "Evita que te expulsen por inactividad.", en = "Prevents inactivity kicks."},
    ["Ir a esta zona"] = {es = "Ir a esta zona", en = "Go to this area"},
    ["Cargar esta opción"] = {es = "Cargar esta opción", en = "Load this option"},
    ["No hay objetivos disponibles."] = {es = "No hay objetivos disponibles.", en = "No targets are available."},
    ["Auto Reparar Barco"] = {es = "Auto Reparar Barco", en = "Auto Repair Boat"},
    ["Repone piezas faltantes y recoloca piezas sueltas cuando sea posible."] = {es = "Repone piezas faltantes y recoloca piezas sueltas cuando sea posible.", en = "Replaces missing parts and repositions loose parts when possible."},
    ["Auto reparación activada."] = {es = "Auto reparación activada.", en = "Auto repair enabled."},
    ["No encontré un barco para reparar."] = {es = "No encontré un barco para reparar.", en = "I couldn't find a boat to repair."},
    ["No encontré piezas reparables en este barco."] = {es = "No encontré piezas reparables en este barco.", en = "I couldn't find repairable parts on this boat."},
    ["Faltan piezas de repuesto para continuar reparando."] = {es = "Faltan piezas de repuesto para continuar reparando.", en = "You need spare parts to continue repairing."},
    ["Pieza reparada automáticamente."] = {es = "Pieza reparada automáticamente.", en = "Part repaired automatically."},
    ["Discord copiado correctamente."] = {es = "Discord copiado correctamente.", en = "Discord copied successfully."},
    ["Lancha compacta con proa definida, casco cerrado, laterales, asiento elevado y motor trasero."] = {es = "Lancha compacta con proa definida, casco cerrado, laterales, asiento elevado y motor trasero.", en = "Compact speedboat with a shaped bow, closed hull, side rails, raised seat and rear motor."},
    ["Lancha reforzada con proa en V, cubierta, cockpit abierto, parabrisas y motor trasero."] = {es = "Lancha reforzada con proa en V, cubierta, cockpit abierto, parabrisas y motor trasero.", en = "Reinforced speedboat with a V-shaped bow, deck, open cockpit, windshield and rear motor."},
    ["Barco grande con proa escalonada, cubierta completa, cabina abierta, parabrisas y doble motor."] = {es = "Barco grande con proa escalonada, cubierta completa, cabina abierta, parabrisas y doble motor.", en = "Large boat with a stepped bow, full deck, open cabin, windshield and twin rear motors."},
    ["AUTO CREAR"] = {es = "AUTO CREAR", en = "AUTO BUILD"},
    ["CREACIÓN AUTOMÁTICA"] = {es = "CREACIÓN AUTOMÁTICA", en = "AUTO BUILD"},
    ["Crea barcos, carros y aviones adaptándose a los materiales disponibles."] = {es = "Crea barcos, carros y aviones adaptándose a los materiales disponibles.", en = "Build boats, cars and planes adapted to your available materials."},
    ["Auto Crear Carro"] = {es = "Auto Crear Carro", en = "Auto Build Car"},
    ["Crea automáticamente un carro funcional en tres niveles usando tus materiales disponibles."] = {es = "Crea automáticamente un carro funcional en tres niveles usando tus materiales disponibles.", en = "Automatically builds a functional car in three levels using your available materials."},
    ["Auto Crear Avión"] = {es = "Auto Crear Avión", en = "Auto Build Plane"},
    ["Crea automáticamente un avión en tres niveles usando tus materiales y componentes disponibles."] = {es = "Crea automáticamente un avión en tres niveles usando tus materiales y componentes disponibles.", en = "Automatically builds a plane in three levels using your available materials and components."},
    ["Selecciona un carro"] = {es = "Selecciona un carro", en = "Select a Car"},
    ["Selecciona un avión"] = {es = "Selecciona un avión", en = "Select a Plane"},
    ["Carro compacto con chasis, cuatro ruedas, asiento de manejo y carrocería ligera."] = {es = "Carro compacto con chasis, cuatro ruedas, asiento de manejo y carrocería ligera.", en = "Compact car with chassis, four wheels, driver seat and lightweight body."},
    ["Carro reforzado con chasis ancho, carrocería, parabrisas, techo parcial y cuatro ruedas."] = {es = "Carro reforzado con chasis ancho, carrocería, parabrisas, techo parcial y cuatro ruedas.", en = "Reinforced car with wide chassis, bodywork, windshield, partial roof and four wheels."},
    ["Carro grande con chasis reforzado, cabina completa, parabrisas, techo y seis ruedas cuando estén disponibles."] = {es = "Carro grande con chasis reforzado, cabina completa, parabrisas, techo y seis ruedas cuando estén disponibles.", en = "Large car with reinforced chassis, full cabin, windshield, roof and six wheels when available."},
    ["Avión ligero con fuselaje, alas, cola, asiento de piloto y propulsión trasera."] = {es = "Avión ligero con fuselaje, alas, cola, asiento de piloto y propulsión trasera.", en = "Light plane with fuselage, wings, tail, pilot seat and rear propulsion."},
    ["Avión reforzado con alas amplias, estabilizadores, cabina y doble propulsión cuando esté disponible."] = {es = "Avión reforzado con alas amplias, estabilizadores, cabina y doble propulsión cuando esté disponible.", en = "Reinforced plane with wider wings, stabilizers, cockpit and twin propulsion when available."},
    ["Avión grande con fuselaje reforzado, alas extensas, cabina, cola completa y propulsión múltiple."] = {es = "Avión grande con fuselaje reforzado, alas extensas, cabina, cola completa y propulsión múltiple.", en = "Large plane with reinforced fuselage, extended wings, cockpit, full tail and multiple propulsion."},
    ["Creando nuevo carro. El resultado dependerá de los materiales y componentes que tengas."] = {es = "Creando nuevo carro. El resultado dependerá de los materiales y componentes que tengas.", en = "Building a new car. The result will depend on the materials and components you own."},
    ["Creando nuevo avión. El resultado dependerá de los materiales y componentes que tengas."] = {es = "Creando nuevo avión. El resultado dependerá de los materiales y componentes que tengas.", en = "Building a new plane. The result will depend on the materials and components you own."},
    ["Carro creado correctamente."] = {es = "Carro creado correctamente.", en = "Car built successfully."},
    ["Avión creado correctamente."] = {es = "Avión creado correctamente.", en = "Plane built successfully."},
    ["No se pudo completar el carro: "] = {es = "No se pudo completar el carro: ", en = "The car could not be completed: "},
    ["No se pudo completar el avión: "] = {es = "No se pudo completar el avión: ", en = "The plane could not be completed: "},
    ["No tienes suficientes ruedas o asiento de manejo; el carro puede crearse sin conducción completa."] = {es = "No tienes suficientes ruedas o asiento de manejo; el carro puede crearse sin conducción completa.", en = "You don't have enough wheels or a driver seat; the car may be built without full driving controls."},
    ["No tienes asiento de piloto o propulsión; el avión puede crearse sin vuelo completo."] = {es = "No tienes asiento de piloto o propulsión; el avión puede crearse sin vuelo completo.", en = "You don't have a pilot seat or propulsion; the plane may be built without full flight controls."},
    ["Sistema de conducción del carro añadido."] = {es = "Sistema de conducción del carro añadido.", en = "Car driving system added."},
    ["Sistema de vuelo del avión añadido."] = {es = "Sistema de vuelo del avión añadido.", en = "Plane flight system added."},
    ["Ya se está creando un vehículo."] = {es = "Ya se está creando un vehículo.", en = "A vehicle is already being built."},
    ["Desactiva Auto Farm antes de crear un vehículo."] = {es = "Desactiva Auto Farm antes de crear un vehículo.", en = "Disable Auto Farm before building a vehicle."},
    ["Continuar con los materiales actuales; el vehículo puede reducirse."] = {es = "Continuar con los materiales actuales; el vehículo puede reducirse.", en = "Continue with current materials; the vehicle may be reduced."},
    ["Farmear para completar"] = {es = "Farmear para completar", en = "Farm to Complete"},
    ["FARMEAR Y COMPRAR"] = {es = "FARMEAR Y COMPRAR", en = "FARM AND BUY"},
    ["CONTINUAR SIN FARMEAR"] = {es = "CONTINUAR SIN FARMEAR", en = "CONTINUE WITHOUT FARMING"},
    ["Te faltan recursos y tu oro actual no alcanza para comprarlos. HX Boat puede farmear hasta conseguir el oro necesario, comprar automáticamente lo faltante y continuar."] = {es = "Te faltan recursos y tu oro actual no alcanza para comprarlos. HX Boat puede farmear hasta conseguir el oro necesario, comprar automáticamente lo faltante y continuar.", en = "You are missing resources and your current Gold is not enough to buy them. HX Boat can farm until it has enough Gold, automatically buy what is missing, and continue."},
    ["Farmeando oro para completar la construcción..."] = {es = "Farmeando oro para completar la construcción...", en = "Farming Gold to complete the build..."},
    ["Oro suficiente. Comprando automáticamente los recursos faltantes..."] = {es = "Oro suficiente. Comprando automáticamente los recursos faltantes...", en = "Enough Gold collected. Automatically buying the missing resources..."},
    ["No pude conseguir suficiente oro para continuar automáticamente."] = {es = "No pude conseguir suficiente oro para continuar automáticamente.", en = "I couldn't collect enough Gold to continue automatically."},
    ["Ya se está farmeando oro para una construcción."] = {es = "Ya se está farmeando oro para una construcción.", en = "Gold is already being farmed for a build."},
    ["Selecciona tu dispositivo"] = {es = "Selecciona tu dispositivo", en = "Select your device"},
    ["Elige cómo quieres que HX Boat adapte la interfaz."] = {es = "Elige cómo quieres que HX Boat adapte la interfaz.", en = "Choose how HX Boat should adapt the interface."},
    ["COMPUTADORA"] = {es = "COMPUTADORA", en = "COMPUTER"},
    ["CELULAR"] = {es = "CELULAR", en = "MOBILE"},
    ["AUTOMÁTICO"] = {es = "AUTOMÁTICO", en = "AUTOMATIC"},
    ["Usar interfaz para computadora."] = {es = "Usar interfaz para computadora.", en = "Use the computer interface."},
    ["Usar interfaz compacta para celular."] = {es = "Usar interfaz compacta para celular.", en = "Use the compact mobile interface."},
    ["Detectar automáticamente el dispositivo."] = {es = "Detectar automáticamente el dispositivo.", en = "Automatically detect the device."},
    ["¿Cómo quieres usar Automático?"] = {es = "¿Cómo quieres usar Automático?", en = "How do you want to use Automatic?"},
    ["SOLO ESTA VEZ"] = {es = "SOLO ESTA VEZ", en = "THIS TIME ONLY"},
    ["USAR SIEMPRE"] = {es = "USAR SIEMPRE", en = "ALWAYS USE"},
    ["Detectará el dispositivo únicamente en esta ejecución."] = {es = "Detectará el dispositivo únicamente en esta ejecución.", en = "It will detect the device only for this run."},
    ["Guardará Automático y lo usará en futuras ejecuciones."] = {es = "Guardará Automático y lo usará en futuras ejecuciones.", en = "Automatic will be saved and used on future runs."},
    ["Auto Farm Materiales"] = {es = "Auto Farm Materiales", en = "Auto Farm Materials"},
    ["Farmea oro y compra automáticamente el material seleccionado."] = {es = "Farmea oro y compra automáticamente el material seleccionado.", en = "Farms Gold and automatically buys the selected material."},
    ["Material objetivo"] = {es = "Material objetivo", en = "Target Material"},
    ["Elige qué material quieres conseguir automáticamente."] = {es = "Elige qué material quieres conseguir automáticamente.", en = "Choose which material you want to obtain automatically."},
    ["Selecciona material"] = {es = "Selecciona material", en = "Select Material"},
    ["Equilibrado"] = {es = "Equilibrado", en = "Balanced"},
    ["Compra primero el material del que tengas menos cantidad."] = {es = "Compra primero el material del que tengas menos cantidad.", en = "Buys the material you currently have the least of first."},
    ["Madera"] = {es = "Madera", en = "Wood"},
    ["Prioriza paquetes de madera."] = {es = "Prioriza paquetes de madera.", en = "Prioritizes Wood packs."},
    ["Piedra"] = {es = "Piedra", en = "Stone"},
    ["Prioriza paquetes de piedra."] = {es = "Prioriza paquetes de piedra.", en = "Prioritizes Stone packs."},
    ["Metal"] = {es = "Metal", en = "Metal"},
    ["Prioriza paquetes de metal."] = {es = "Prioriza paquetes de metal.", en = "Prioritizes Metal packs."},
    ["Titanio"] = {es = "Titanio", en = "Titanium"},
    ["Prioriza paquetes de titanio."] = {es = "Prioriza paquetes de titanio.", en = "Prioritizes Titanium packs."},
    ["Material seleccionado: "] = {es = "Material seleccionado: ", en = "Selected material: "},
    ["Auto Farm Materiales iniciado."] = {es = "Auto Farm Materiales iniciado.", en = "Auto Farm Materials started."},
    ["Auto Farm Materiales detenido."] = {es = "Auto Farm Materiales detenido.", en = "Auto Farm Materials stopped."},
    ["Material comprado automáticamente: "] = {es = "Material comprado automáticamente: ", en = "Material purchased automatically: "},
    ["No pude comprar el material seleccionado."] = {es = "No pude comprar el material seleccionado.", en = "I couldn't purchase the selected material."},
    ["Desactiva Auto Farm Gold antes de usar Auto Farm Materiales."] = {es = "Desactiva Auto Farm Gold antes de usar Auto Farm Materiales.", en = "Disable Auto Farm Gold before using Auto Farm Materials."},
    ["Hay una construcción automática usando el farmeo. Inténtalo cuando termine."] = {es = "Hay una construcción automática usando el farmeo. Inténtalo cuando termine.", en = "An automatic build is currently using the farming system. Try again when it finishes."},
    ["Auto Crear Helicóptero"] = {es = "Auto Crear Helicóptero", en = "Auto Build Helicopter"},
    ["Crea un helicóptero con fuselaje, patines, cola, rotor visual y control de vuelo."] = {es = "Crea un helicóptero con fuselaje, patines, cola, rotor visual y control de vuelo.", en = "Builds a helicopter with fuselage, skids, tail, visual rotor and flight controls."},
    ["Auto Crear Submarino"] = {es = "Auto Crear Submarino", en = "Auto Build Submarine"},
    ["Crea un submarino reforzado con casco cerrado, cabina y propulsión trasera."] = {es = "Crea un submarino reforzado con casco cerrado, cabina y propulsión trasera.", en = "Builds a reinforced submarine with an enclosed hull, cabin and rear propulsion."},
    ["Auto Crear Moto"] = {es = "Auto Crear Moto", en = "Auto Build Motorcycle"},
    ["Crea una moto compacta con chasis, dos ruedas y asiento de manejo."] = {es = "Crea una moto compacta con chasis, dos ruedas y asiento de manejo.", en = "Builds a compact motorcycle with chassis, two wheels and driver seat."},
    ["Auto Crear Tanque"] = {es = "Auto Crear Tanque", en = "Auto Build Tank"},
    ["Crea un tanque reforzado con chasis ancho, ruedas laterales y torreta visual."] = {es = "Crea un tanque reforzado con chasis ancho, ruedas laterales y torreta visual.", en = "Builds a reinforced tank with a wide chassis, side wheels and visual turret."},
    ["Auto Crear Cohete"] = {es = "Auto Crear Cohete", en = "Auto Build Rocket"},
    ["Crea un cohete vertical con fuselaje, punta, aletas y propulsión inferior."] = {es = "Crea un cohete vertical con fuselaje, punta, aletas y propulsión inferior.", en = "Builds a vertical rocket with fuselage, nose, fins and lower propulsion."},
    ["Auto Crear Barco de Farm"] = {es = "Auto Crear Barco de Farm", en = "Auto Build Farm Boat"},
    ["Crea un barco compacto pensado para recorrer stages con poco peso y buena protección."] = {es = "Crea un barco compacto pensado para recorrer stages con poco peso y buena protección.", en = "Builds a compact boat designed for stage runs with low weight and good protection."},
    ["Auto Crear Base/Plataforma"] = {es = "Auto Crear Base/Plataforma", en = "Auto Build Base/Platform"},
    ["Crea una plataforma estable para construir o usar como base."] = {es = "Crea una plataforma estable para construir o usar como base.", en = "Builds a stable platform for building or using as a base."},
    ["Selecciona un helicóptero"] = {es = "Selecciona un helicóptero", en = "Select a Helicopter"},
    ["Selecciona un submarino"] = {es = "Selecciona un submarino", en = "Select a Submarine"},
    ["Selecciona una moto"] = {es = "Selecciona una moto", en = "Select a Motorcycle"},
    ["Selecciona un tanque"] = {es = "Selecciona un tanque", en = "Select a Tank"},
    ["Selecciona un cohete"] = {es = "Selecciona un cohete", en = "Select a Rocket"},
    ["Selecciona un barco de farm"] = {es = "Selecciona un barco de farm", en = "Select a Farm Boat"},
    ["Selecciona una base"] = {es = "Selecciona una base", en = "Select a Base"},
    ["Versión básica, pequeña y económica."] = {es = "Versión básica, pequeña y económica.", en = "Basic, small and economical version."},
    ["Versión intermedia con más estructura y protección."] = {es = "Versión intermedia con más estructura y protección.", en = "Intermediate version with more structure and protection."},
    ["Versión avanzada con mayor tamaño, refuerzo y componentes."] = {es = "Versión avanzada con mayor tamaño, refuerzo y componentes.", en = "Advanced version with larger size, reinforcement and components."},
    ["Creando vehículo automáticamente..."] = {es = "Creando vehículo automáticamente...", en = "Automatically building vehicle..."},
    ["Construcción creada correctamente."] = {es = "Construcción creada correctamente.", en = "Build created successfully."},
    ["No se pudo completar la construcción: "] = {es = "No se pudo completar la construcción: ", en = "The build could not be completed: "},
    ["Faltan componentes para que este vehículo funcione completamente."] = {es = "Faltan componentes para que este vehículo funcione completamente.", en = "Some components are missing for this vehicle to work completely."},
    ["BUSCAR"] = {es = "BUSCAR", en = "SEARCH"},
}

ENV.__HX_TR = function(value)
    local raw = tostring(value or "")
    local pair = ENV.__HX_TEXTS and ENV.__HX_TEXTS[raw]
    if pair then
        return ENV.__HX_LANG == "en" and pair.en or pair.es
    end

    -- Dynamic labels/messages.
    local n = string.match(raw, "^Posición (%d+)$")
    if n then return ENV.__HX_LANG == "en" and ("Position " .. n) or ("Posición " .. n) end
    n = string.match(raw, "^Position (%d+)$")
    if n then return ENV.__HX_LANG == "en" and ("Position " .. n) or ("Posición " .. n) end
    n = string.match(raw, "^Posición (%d+) guardada$")
    if n then return ENV.__HX_LANG == "en" and ("Position " .. n .. " saved") or ("Posición " .. n .. " guardada") end
    n = string.match(raw, "^Position (%d+) saved$")
    if n then return ENV.__HX_LANG == "en" and ("Position " .. n .. " saved") or ("Posición " .. n .. " guardada") end
    n = string.match(raw, "^Position (%d+) guardada$")
    if n then return ENV.__HX_LANG == "en" and ("Position " .. n .. " saved") or ("Posición " .. n .. " guardada") end

    if string.sub(raw, 1, 23) == "Propulsores activados: " then
        local tail = string.sub(raw, 24)
        return ENV.__HX_LANG == "en" and ("Thrusters activated: " .. tail) or raw
    end
    if string.sub(raw, 1, 17) == "Follow activado: " then
        local tail = string.sub(raw, 18)
        return ENV.__HX_LANG == "en" and ("Follow enabled: " .. tail) or ("Seguimiento activado: " .. tail)
    end
    if string.sub(raw, 1, 15) == "Error interno: " then
        local tail = string.sub(raw, 16)
        return ENV.__HX_LANG == "en" and ("Internal error: " .. tail) or raw
    end

    return raw
end

do
    local settingsFile = "HX_Boat_Settings.json"
    local remembered = ENV.__HX_REMEMBERED_LANG
    ENV.__HX_LANG = nil

    if remembered == "es" or remembered == "en" then
        ENV.__HX_LANG = remembered
    elseif readfile and isfile and isfile(settingsFile) then
        pcall(function()
            local data = HttpService:JSONDecode(readfile(settingsFile))
            if type(data) == "table" and data.remember == true and (data.language == "es" or data.language == "en") then
                ENV.__HX_LANG = data.language
                ENV.__HX_REMEMBERED_LANG = data.language
            end
        end)
    end

    if not ENV.__HX_LANG then
        local picker = Instance.new("CanvasGroup")
        picker.Name = "HX_LanguagePicker"
        picker.AnchorPoint = Vector2.new(0.5, 0.5)
        picker.Position = UDim2.fromScale(0.5, 0.5)
        picker.Size = UDim2.fromOffset(430, 280)
        picker.BackgroundTransparency = 1
        picker.GroupTransparency = 1
        picker.ZIndex = 500
        picker.Parent = Gui

        local pickerScale = Instance.new("UIScale")
        pickerScale.Scale = 0.90
        pickerScale.Parent = picker

        local shell = Instance.new("Frame")
        shell.Size = UDim2.fromScale(1, 1)
        shell.BackgroundColor3 = Theme.accent
        shell.BorderSizePixel = 0
        shell.ClipsDescendants = true
        shell.ZIndex = picker.ZIndex
        shell.Parent = picker
        corner(shell, 28)

        local surface = Instance.new("Frame")
        surface.Position = UDim2.fromOffset(4, 4)
        surface.Size = UDim2.new(1, -8, 1, -8)
        surface.BackgroundColor3 = Theme.bg
        surface.BorderSizePixel = 0
        surface.ClipsDescendants = true
        surface.ZIndex = shell.ZIndex + 1
        surface.Parent = shell
        corner(surface, 24)

        local dots = Instance.new("Frame")
        dots.Size = UDim2.fromScale(1, 1)
        dots.BackgroundTransparency = 1
        dots.BorderSizePixel = 0
        dots.ClipsDescendants = true
        dots.ZIndex = surface.ZIndex + 1
        dots.Parent = surface

        local rng = Random.new(727425)
        local pickerAlive = true
        local function moveDot(dot)
            if not pickerAlive or not dot.Parent then return end
            local tw = TweenService:Create(dot, TweenInfo.new(rng:NextNumber(9, 17), Enum.EasingStyle.Linear), {
                Position = UDim2.fromScale(rng:NextNumber(-0.02, 1.02), rng:NextNumber(-0.02, 1.02))
            })
            tw:Play()
            tw.Completed:Connect(function()
                if pickerAlive and dot.Parent then moveDot(dot) end
            end)
        end

        for i = 1, (UserInputService.TouchEnabled and 42 or 62) do
            local dot = Instance.new("Frame")
            local size = rng:NextInteger(1, 4)
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Size = UDim2.fromOffset(size, size)
            dot.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
            dot.BackgroundColor3 = Theme.accent
            dot.BackgroundTransparency = rng:NextNumber(0.20, 0.72)
            dot.BorderSizePixel = 0
            dot.ZIndex = dots.ZIndex + 1
            dot.Parent = dots
            corner(dot, 4)
            moveDot(dot)
        end

        local shade = Instance.new("Frame")
        shade.Size = UDim2.fromScale(1, 1)
        shade.BackgroundColor3 = Theme.panel
        shade.BackgroundTransparency = 0.24
        shade.BorderSizePixel = 0
        shade.ZIndex = surface.ZIndex + 3
        shade.Parent = surface
        corner(shade, 24)

        local logoTitle = Instance.new("TextLabel")
        logoTitle.BackgroundTransparency = 1
        logoTitle.Position = UDim2.fromOffset(24, 26)
        logoTitle.Size = UDim2.new(1, -48, 0, 28)
        logoTitle.Font = Enum.Font.GothamBlack
        logoTitle.Text = "HX Boat"
        logoTitle.TextColor3 = Theme.text
        logoTitle.TextSize = 20
        logoTitle.ZIndex = shade.ZIndex + 2
        logoTitle.Parent = surface

        local chooseTitle = Instance.new("TextLabel")
        chooseTitle.BackgroundTransparency = 1
        chooseTitle.Position = UDim2.fromOffset(24, 58)
        chooseTitle.Size = UDim2.new(1, -48, 0, 34)
        chooseTitle.Font = Enum.Font.GothamSemibold
        chooseTitle.Text = "Selecciona el idioma  •  Select language"
        chooseTitle.TextColor3 = Theme.muted
        chooseTitle.TextSize = 12
        chooseTitle.ZIndex = shade.ZIndex + 2
        chooseTitle.Parent = surface

        local remember = false
        local rememberButton = Instance.new("TextButton")
        rememberButton.AnchorPoint = Vector2.new(0.5, 0)
        rememberButton.Position = UDim2.new(0.5, 0, 0, 190)
        rememberButton.Size = UDim2.fromOffset(230, 36)
        rememberButton.BackgroundColor3 = Theme.panel2
        rememberButton.BorderSizePixel = 0
        rememberButton.AutoButtonColor = false
        rememberButton.Font = Enum.Font.GothamSemibold
        rememberButton.Text = "○  Recordar / Remember me"
        rememberButton.TextColor3 = Theme.text
        rememberButton.TextSize = 11
        rememberButton.ZIndex = shade.ZIndex + 3
        rememberButton.Parent = surface
        corner(rememberButton, 18)

        local function finishLanguage(language)
            ENV.__HX_LANG = language
            ENV.__HX_LANGUAGE_PICKED_THIS_RUN = true
            if remember then
                ENV.__HX_REMEMBERED_LANG = language
                if writefile then
                    pcall(function()
                        writefile(settingsFile, HttpService:JSONEncode({language = language, remember = true}))
                    end)
                end
            else
                ENV.__HX_REMEMBERED_LANG = nil
                if delfile and isfile and isfile(settingsFile) then pcall(delfile, settingsFile) end
            end

            pickerAlive = false
            TweenService:Create(picker, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {GroupTransparency = 1}):Play()
            TweenService:Create(pickerScale, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale = 0.94}):Play()
            task.delay(0.16, function() if picker.Parent then picker:Destroy() end end)
        end

        local function languageButton(label, language, x)
            local button = Instance.new("TextButton")
            button.AnchorPoint = Vector2.new(0.5, 0)
            button.Position = UDim2.new(0.5, x, 0, 112)
            button.Size = UDim2.fromOffset(168, 56)
            button.BackgroundColor3 = Theme.accent
            button.BorderSizePixel = 0
            button.AutoButtonColor = false
            button.Font = Enum.Font.GothamBlack
            button.Text = label
            button.TextColor3 = Theme.bg
            button.TextSize = 13
            button.ZIndex = shade.ZIndex + 3
            button.Parent = surface
            corner(button, 18)

            local scale = Instance.new("UIScale")
            scale.Scale = 1
            scale.Parent = button
            button.MouseEnter:Connect(function() tween(scale, {Scale = 1.035}, 0.10) end)
            button.MouseLeave:Connect(function() tween(scale, {Scale = 1}, 0.10) end)
            button.Activated:Connect(function()
                tween(scale, {Scale = 0.94}, 0.06)
                finishLanguage(language)
            end)
        end

        rememberButton.Activated:Connect(function()
            remember = not remember
            rememberButton.Text = (remember and "●  " or "○  ") .. "Recordar / Remember me"
            tween(rememberButton, {BackgroundColor3 = remember and Theme.soft or Theme.panel2}, 0.10)
        end)

        languageButton("ESPAÑOL", "es", -92)
        languageButton("ENGLISH", "en", 92)

        TweenService:Create(picker, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
        TweenService:Create(pickerScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

        while alive and not ENV.__HX_LANG do task.wait() end
    end
end

--====================================================
-- Device / dispositivo
--====================================================
do
    local deviceFile = "HX_Boat_Device.json"
    ENV.__HX_DEVICE = nil
    ENV.__HX_DEVICE_MODE = nil

    local function detectDevice()
        local camera = Workspace.CurrentCamera
        local viewportX = camera and camera.ViewportSize.X or 1280
        local touch = UserInputService.TouchEnabled
        local keyboard = UserInputService.KeyboardEnabled
        local mouse = UserInputService.MouseEnabled

        -- Phone/tablet detection. Touch laptops with a normal desktop-size
        -- viewport and mouse/keyboard stay in the computer layout.
        if touch and ((not keyboard and not mouse) or viewportX < 900) then
            return "mobile"
        end
        return "desktop"
    end

    -- "Usar siempre" only remembers Automatic. Manual COMPUTER/MOBILE choices
    -- remain one-session choices, exactly as selected by the user.
    if readfile and isfile and isfile(deviceFile) then
        pcall(function()
            local saved = HttpService:JSONDecode(readfile(deviceFile))
            if type(saved) == "table" and saved.automaticAlways == true then
                ENV.__HX_DEVICE_MODE = "automatic"
                ENV.__HX_DEVICE = detectDevice()
            end
        end)
    end

    if not ENV.__HX_DEVICE then
        if ENV.__HX_LANGUAGE_PICKED_THIS_RUN then
            task.wait(0.18)
            ENV.__HX_LANGUAGE_PICKED_THIS_RUN = nil
        end

        local picker = Instance.new("CanvasGroup")
        picker.Name = "HX_DevicePicker"
        picker.AnchorPoint = Vector2.new(0.5, 0.5)
        picker.Position = UDim2.fromScale(0.5, 0.5)
        picker.Size = UDim2.fromOffset(430, 330)
        picker.BackgroundTransparency = 1
        picker.GroupTransparency = 1
        picker.ZIndex = 510
        picker.Parent = Gui

        local pickerScale = Instance.new("UIScale")
        pickerScale.Scale = 0.90
        pickerScale.Parent = picker

        local shell = Instance.new("Frame")
        shell.Size = UDim2.fromScale(1, 1)
        shell.BackgroundColor3 = Theme.accent
        shell.BorderSizePixel = 0
        shell.ClipsDescendants = true
        shell.ZIndex = picker.ZIndex
        shell.Parent = picker
        corner(shell, 28)

        local surface = Instance.new("Frame")
        surface.Position = UDim2.fromOffset(4, 4)
        surface.Size = UDim2.new(1, -8, 1, -8)
        surface.BackgroundColor3 = Theme.bg
        surface.BorderSizePixel = 0
        surface.ClipsDescendants = true
        surface.ZIndex = shell.ZIndex + 1
        surface.Parent = shell
        corner(surface, 24)

        local dots = Instance.new("Frame")
        dots.Size = UDim2.fromScale(1, 1)
        dots.BackgroundTransparency = 1
        dots.BorderSizePixel = 0
        dots.ClipsDescendants = true
        dots.ZIndex = surface.ZIndex + 1
        dots.Parent = surface

        local rng = Random.new(334417)
        local pickerAlive = true
        local function moveDot(dot)
            if not pickerAlive or not dot.Parent then return end
            local tw = TweenService:Create(dot, TweenInfo.new(rng:NextNumber(9, 17), Enum.EasingStyle.Linear), {
                Position = UDim2.fromScale(rng:NextNumber(-0.02, 1.02), rng:NextNumber(-0.02, 1.02))
            })
            tw:Play()
            tw.Completed:Connect(function()
                if pickerAlive and dot.Parent then moveDot(dot) end
            end)
        end

        for i = 1, 48 do
            local dot = Instance.new("Frame")
            local size = rng:NextInteger(1, 4)
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Size = UDim2.fromOffset(size, size)
            dot.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
            dot.BackgroundColor3 = Theme.accent
            dot.BackgroundTransparency = rng:NextNumber(0.20, 0.72)
            dot.BorderSizePixel = 0
            dot.ZIndex = dots.ZIndex + 1
            dot.Parent = dots
            corner(dot, 4)
            moveDot(dot)
        end

        local shade = Instance.new("Frame")
        shade.Size = UDim2.fromScale(1, 1)
        shade.BackgroundColor3 = Theme.panel
        shade.BackgroundTransparency = 0.22
        shade.BorderSizePixel = 0
        shade.ZIndex = surface.ZIndex + 3
        shade.Parent = surface
        corner(shade, 24)

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(24, 22)
        title.Size = UDim2.new(1, -48, 0, 30)
        title.Font = Enum.Font.GothamBlack
        title.Text = ENV.__HX_TR("Selecciona tu dispositivo")
        title.TextColor3 = Theme.text
        title.TextSize = 18
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = shade.ZIndex + 2
        title.Parent = surface

        local subtitle = Instance.new("TextLabel")
        subtitle.BackgroundTransparency = 1
        subtitle.Position = UDim2.fromOffset(24, 52)
        subtitle.Size = UDim2.new(1, -48, 0, 28)
        subtitle.Font = Enum.Font.Gotham
        subtitle.Text = ENV.__HX_TR("Elige cómo quieres que HX Boat adapte la interfaz.")
        subtitle.TextColor3 = Theme.muted
        subtitle.TextSize = 10
        subtitle.TextWrapped = true
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.ZIndex = shade.ZIndex + 2
        subtitle.Parent = surface

        local choiceHolder = Instance.new("Frame")
        choiceHolder.Position = UDim2.fromOffset(24, 90)
        choiceHolder.Size = UDim2.new(1, -48, 1, -112)
        choiceHolder.BackgroundTransparency = 1
        choiceHolder.ZIndex = shade.ZIndex + 2
        choiceHolder.Parent = surface

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 9)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = choiceHolder

        local function closePicker()
            pickerAlive = false
            tween(picker, {GroupTransparency = 1}, 0.16)
            tween(pickerScale, {Scale = 0.94}, 0.16)
            task.delay(0.16, function()
                if picker.Parent then picker:Destroy() end
            end)
        end

        local function clearChoices()
            for _, child in ipairs(choiceHolder:GetChildren()) do
                if not child:IsA("UIListLayout") then child:Destroy() end
            end
        end

        local function chooseDevice(mode)
            ENV.__HX_DEVICE_MODE = mode
            ENV.__HX_DEVICE = mode == "mobile" and "mobile" or "desktop"

            if delfile and isfile and isfile(deviceFile) then
                pcall(delfile, deviceFile)
            end

            closePicker()
        end

        local function makeChoice(label, description, callback)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 61)
            button.BackgroundColor3 = Theme.accent
            button.BorderSizePixel = 0
            button.AutoButtonColor = false
            button.Text = ""
            button.ClipsDescendants = true
            button.ZIndex = choiceHolder.ZIndex + 1
            button.Parent = choiceHolder
            corner(button, 17)

            local inner = Instance.new("Frame")
            inner.Position = UDim2.fromOffset(2, 2)
            inner.Size = UDim2.new(1, -4, 1, -4)
            inner.BackgroundColor3 = Theme.panel2
            inner.BorderSizePixel = 0
            inner.ZIndex = button.ZIndex + 1
            inner.Parent = button
            corner(inner, 15)

            local mainText = Instance.new("TextLabel")
            mainText.Position = UDim2.fromOffset(14, 8)
            mainText.Size = UDim2.new(1, -28, 0, 20)
            mainText.BackgroundTransparency = 1
            mainText.Font = Enum.Font.GothamBlack
            mainText.Text = ENV.__HX_TR(label)
            mainText.TextColor3 = Theme.text
            mainText.TextSize = 12
            mainText.TextXAlignment = Enum.TextXAlignment.Left
            mainText.ZIndex = inner.ZIndex + 1
            mainText.Parent = inner

            local subText = Instance.new("TextLabel")
            subText.Position = UDim2.fromOffset(14, 29)
            subText.Size = UDim2.new(1, -28, 0, 18)
            subText.BackgroundTransparency = 1
            subText.Font = Enum.Font.Gotham
            subText.Text = ENV.__HX_TR(description)
            subText.TextColor3 = Theme.muted
            subText.TextSize = 9
            subText.TextWrapped = true
            subText.TextXAlignment = Enum.TextXAlignment.Left
            subText.ZIndex = inner.ZIndex + 1
            subText.Parent = inner

            local scale = Instance.new("UIScale")
            scale.Scale = 1
            scale.Parent = button

            button.MouseEnter:Connect(function()
                tween(inner, {BackgroundColor3 = Theme.soft}, 0.10)
                tween(scale, {Scale = 1.015}, 0.10)
            end)
            button.MouseLeave:Connect(function()
                tween(inner, {BackgroundColor3 = Theme.panel2}, 0.10)
                tween(scale, {Scale = 1}, 0.10)
            end)
            button.Activated:Connect(function()
                tween(scale, {Scale = 0.97}, 0.06)
                task.spawn(callback)
            end)
        end

        local function showAutomaticChoice()
            clearChoices()
            title.Text = ENV.__HX_TR("¿Cómo quieres usar Automático?")
            subtitle.Text = ENV.__HX_TR("Detectar automáticamente el dispositivo.")

            makeChoice(
                "SOLO ESTA VEZ",
                "Detectará el dispositivo únicamente en esta ejecución.",
                function()
                    ENV.__HX_DEVICE_MODE = "automatic_once"
                    ENV.__HX_DEVICE = detectDevice()

                    if delfile and isfile and isfile(deviceFile) then
                        pcall(delfile, deviceFile)
                    end
                    closePicker()
                end
            )

            makeChoice(
                "USAR SIEMPRE",
                "Guardará Automático y lo usará en futuras ejecuciones.",
                function()
                    ENV.__HX_DEVICE_MODE = "automatic"
                    ENV.__HX_DEVICE = detectDevice()

                    if writefile then
                        pcall(function()
                            writefile(deviceFile, HttpService:JSONEncode({
                                automaticAlways = true
                            }))
                        end)
                    end
                    closePicker()
                end
            )
        end

        makeChoice("COMPUTADORA", "Usar interfaz para computadora.", function()
            chooseDevice("desktop")
        end)

        makeChoice("CELULAR", "Usar interfaz compacta para celular.", function()
            chooseDevice("mobile")
        end)

        makeChoice("AUTOMÁTICO", "Detectar automáticamente el dispositivo.", showAutomaticChoice)

        tween(picker, {GroupTransparency = 0}, 0.22)
        tween(pickerScale, {Scale = 1}, 0.28)

        while alive and not ENV.__HX_DEVICE do task.wait() end
    end
end

-- Only build the full hub inside Build A Boat For Treasure.
-- In every other place, show a lightweight animated redirect panel and stop here.
if game.PlaceId ~= 537413528 then
    local Gate = Instance.new("Frame")
    Gate.Name = "BABFT_OnlyGate"
    Gate.AnchorPoint = Vector2.new(0.5, 0.5)
    Gate.Position = UDim2.fromScale(0.5, 0.5)
    Gate.Size = ENV.__HX_DEVICE == "mobile" and UDim2.fromOffset(390, 205) or UDim2.fromOffset(500, 250)
    Gate.BackgroundTransparency = 1
    Gate.BorderSizePixel = 0
    Gate.ZIndex = 200
    Gate.Parent = Gui

    local GateScale = Instance.new("UIScale")
    GateScale.Scale = 0.90
    GateScale.Parent = Gate

    local GateShell = Instance.new("Frame")
    GateShell.Size = UDim2.fromScale(1, 1)
    GateShell.BackgroundColor3 = Theme.accent
    GateShell.BorderSizePixel = 0
    GateShell.ClipsDescendants = true
    GateShell.ZIndex = Gate.ZIndex
    GateShell.Parent = Gate
    corner(GateShell, 28)

    local GateSurface = Instance.new("Frame")
    GateSurface.Position = UDim2.fromOffset(4, 4)
    GateSurface.Size = UDim2.new(1, -8, 1, -8)
    GateSurface.BackgroundColor3 = Theme.bg
    GateSurface.BorderSizePixel = 0
    GateSurface.ClipsDescendants = true
    GateSurface.ZIndex = Gate.ZIndex + 1
    GateSurface.Parent = GateShell
    corner(GateSurface, 23)

    local GateDots = Instance.new("Frame")
    GateDots.Size = UDim2.fromScale(1, 1)
    GateDots.BackgroundTransparency = 1
    GateDots.BorderSizePixel = 0
    GateDots.ClipsDescendants = true
    GateDots.ZIndex = GateSurface.ZIndex + 1
    GateDots.Parent = GateSurface

    local gateRng = Random.new(913742)
    local gateDotsAlive = true
    local gateTweens = {}
    local function gateTarget()
        return UDim2.fromScale(gateRng:NextNumber(-0.025, 1.025), gateRng:NextNumber(-0.025, 1.025))
    end
    local function animateGateDot(dot)
        if not gateDotsAlive or not dot or not dot.Parent then return end
        local tw = TweenService:Create(
            dot,
            TweenInfo.new(gateRng:NextNumber(8.5, 18.0), Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
            {Position = gateTarget()}
        )
        gateTweens[dot] = tw
        tw:Play()
        local conn
        conn = tw.Completed:Connect(function()
            if conn then conn:Disconnect() end
            gateTweens[dot] = nil
            if gateDotsAlive and dot.Parent then animateGateDot(dot) end
        end)
    end

    for i = 1, (ENV.__HX_DEVICE == "mobile" and 55 or 110) do
        local dot = Instance.new("Frame")
        local roll = gateRng:NextInteger(1, 100)
        local size = roll <= 5 and 5 or (roll <= 18 and 4 or (roll <= 45 and 3 or (roll <= 74 and 2 or 1)))
        dot.Name = "GateDot_" .. i
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(size, size)
        dot.Position = gateTarget()
        dot.BackgroundColor3 = Theme.accent
        dot.BackgroundTransparency = gateRng:NextNumber(0.10, 0.66)
        dot.BorderSizePixel = 0
        dot.ZIndex = GateDots.ZIndex + 1
        dot.Parent = GateDots
        if size >= 3 then corner(dot, math.ceil(size / 2)) end
        animateGateDot(dot)
    end

    local GateShade = Instance.new("Frame")
    GateShade.Size = UDim2.fromScale(1, 1)
    GateShade.BackgroundColor3 = Theme.panel
    GateShade.BackgroundTransparency = 0.28
    GateShade.BorderSizePixel = 0
    GateShade.ZIndex = GateSurface.ZIndex + 3
    GateShade.Parent = GateSurface
    corner(GateShade, 24)

    local GateTitle = Instance.new("TextLabel")
    GateTitle.BackgroundTransparency = 1
    GateTitle.Position = UDim2.fromOffset(28, 40)
    GateTitle.Size = UDim2.new(1, -56, 0, 34)
    GateTitle.Font = Enum.Font.GothamBlack
    GateTitle.Text = "BUILD A BOAT FOR TREASURE"
    GateTitle.TextColor3 = Theme.text
    GateTitle.TextSize = 20
    GateTitle.TextXAlignment = Enum.TextXAlignment.Center
    GateTitle.ZIndex = GateShade.ZIndex + 2
    GateTitle.Parent = GateSurface

    local GateText = Instance.new("TextLabel")
    GateText.BackgroundTransparency = 1
    GateText.Position = UDim2.fromOffset(34, 82)
    GateText.Size = UDim2.new(1, -68, 0, 48)
    GateText.Font = Enum.Font.GothamMedium
    GateText.Text = ENV.__HX_TR("Este script funciona únicamente en Build A Boat For Treasure.")
    GateText.TextWrapped = true
    GateText.TextColor3 = Theme.muted
    GateText.TextSize = 13
    GateText.TextXAlignment = Enum.TextXAlignment.Center
    GateText.TextYAlignment = Enum.TextYAlignment.Center
    GateText.ZIndex = GateShade.ZIndex + 2
    GateText.Parent = GateSurface

    local Go = Instance.new("TextButton")
    Go.AnchorPoint = Vector2.new(0.5, 0)
    Go.Position = UDim2.new(0.5, 0, 0, 155)
    Go.Size = UDim2.fromOffset(200, 46)
    Go.BackgroundColor3 = Theme.accent
    Go.BorderSizePixel = 0
    Go.AutoButtonColor = false
    Go.Font = Enum.Font.GothamBold
    Go.Text = ENV.__HX_TR("IR AL JUEGO")
    Go.TextColor3 = Theme.bg
    Go.TextSize = 12
    Go.ZIndex = GateShade.ZIndex + 3
    Go.Parent = GateSurface
    corner(Go, 18)

    local GoScale = Instance.new("UIScale")
    GoScale.Scale = 1
    GoScale.Parent = Go

    local GateClose = Instance.new("TextButton")
    GateClose.AnchorPoint = Vector2.new(1, 0)
    GateClose.Position = UDim2.new(1, -14, 0, 14)
    GateClose.Size = UDim2.fromOffset(34, 34)
    GateClose.BackgroundColor3 = Theme.panel2
    GateClose.BorderSizePixel = 0
    GateClose.AutoButtonColor = false
    GateClose.Font = Enum.Font.GothamBold
    GateClose.Text = "×"
    GateClose.TextColor3 = Theme.text
    GateClose.TextSize = 17
    GateClose.ZIndex = GateShade.ZIndex + 4
    GateClose.Parent = GateSurface
    corner(GateClose, 17)

    local closingGate = false
    local function closeGate()
        if closingGate then return end
        closingGate = true
        gateDotsAlive = false
        tween(GateScale, {Scale = 0.90}, 0.18)
        tween(GateSurface, {BackgroundTransparency = 0.35}, 0.18)
        task.delay(0.17, function()
            for _, tw in pairs(gateTweens) do pcall(function() tw:Cancel() end) end
            if Gui then pcall(function() Gui:Destroy() end) end
        end)
    end

    Go.MouseEnter:Connect(function() tween(GoScale, {Scale = 1.055}, 0.12) end)
    Go.MouseLeave:Connect(function() tween(GoScale, {Scale = 1}, 0.12) end)
    Go.Activated:Connect(function()
        tween(GoScale, {Scale = 0.94}, 0.08)
        task.delay(0.08, function()
            if Gui and Gui.Parent then
                pcall(function() TeleportService:Teleport(537413528, LP) end)
                tween(GoScale, {Scale = 1}, 0.12)
            end
        end)
    end)
    GateClose.MouseEnter:Connect(function() tween(GateClose, {BackgroundColor3 = Theme.soft}, 0.10) end)
    GateClose.MouseLeave:Connect(function() tween(GateClose, {BackgroundColor3 = Theme.panel2}, 0.10) end)
    GateClose.Activated:Connect(closeGate)

    ENV.__BABFT_NIGHTFALL_CLEANUP = closeGate

    Gate.Position = UDim2.new(0.5, 0, 0.5, 18)
    GateSurface.BackgroundTransparency = 0.28
    tween(Gate, {Position = UDim2.fromScale(0.5, 0.5)}, 0.28)
    tween(GateScale, {Scale = 1}, 0.28)
    tween(GateSurface, {BackgroundTransparency = 0}, 0.28)
    return
end

local PANEL_W, PANEL_H = ENV.__HX_DEVICE == "mobile" and 460 or 650, ENV.__HX_DEVICE == "mobile" and 320 or 440
local PANEL_MIN_W, PANEL_MIN_H = ENV.__HX_DEVICE == "mobile" and 430 or 610, ENV.__HX_DEVICE == "mobile" and 300 or 410
local TOP_H, SIDE_W = ENV.__HX_DEVICE == "mobile" and 48 or 58, ENV.__HX_DEVICE == "mobile" and 122 or 158

-- Main is now only the movable container.
-- No UIStroke is used on the outer panel: the rounded border is made from
-- two nested rounded frames so square stroke artifacts cannot appear.
local Main = Instance.new("CanvasGroup")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
Main.Position = UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
Main.BackgroundTransparency = 1
Main.GroupTransparency = 0
Main.BorderSizePixel = 0
Main.ClipsDescendants = false
Main.ZIndex = 10
Main.Parent = Gui

do
    local scale = Instance.new("UIScale")
    scale.Name = "MotionScale"
    scale.Scale = 1
    scale.Parent = Main
end

local PanelShell = Instance.new("Frame")
PanelShell.Name = "RoundedShell"
PanelShell.Size = UDim2.fromScale(1, 1)
PanelShell.BackgroundColor3 = Theme.accent
PanelShell.BackgroundTransparency = 0
PanelShell.BorderSizePixel = 0
PanelShell.ClipsDescendants = true
PanelShell.ZIndex = Main.ZIndex
PanelShell.Parent = Main
corner(PanelShell, 28)

local PanelSurface = Instance.new("Frame")
PanelSurface.Name = "RoundedSurface"
PanelSurface.Position = UDim2.fromOffset(4, 4)
PanelSurface.Size = UDim2.new(1, -8, 1, -8)
PanelSurface.BackgroundColor3 = Theme.bg
PanelSurface.BackgroundTransparency = 0
PanelSurface.BorderSizePixel = 0
PanelSurface.ClipsDescendants = true
PanelSurface.ZIndex = Main.ZIndex + 1
PanelSurface.Parent = PanelShell
corner(PanelSurface, 23)

-- Smooth animated background: white dots only.
local StarField = Instance.new("Frame")
StarField.Name = "MovingDotsBackground"
StarField.Size = UDim2.fromScale(1, 1)
StarField.BackgroundTransparency = 1
StarField.BorderSizePixel = 0
StarField.ClipsDescendants = true
StarField.ZIndex = PanelSurface.ZIndex + 1
StarField.Parent = PanelSurface

local DOT_COUNT = ENV.__HX_DEVICE == "mobile" and 58 or 120
local dotRng = Random.new(913742)
local movingDots = {}

local function randomDotTarget()
    return UDim2.fromScale(dotRng:NextNumber(-0.025, 1.025), dotRng:NextNumber(-0.025, 1.025))
end

local function animateDot(data)
    if not alive or not data.object or not data.object.Parent then return end

    local dot = data.object
    local target = randomDotTarget()
    local duration = dotRng:NextNumber(8.5, 18.0)

    local tw = TweenService:Create(
        dot,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
        {Position = target}
    )
    data.tween = tw
    tw:Play()

    local conn
    conn = tw.Completed:Connect(function()
        if conn then conn:Disconnect() end
        data.tween = nil
        if alive and dot.Parent then
            animateDot(data)
        end
    end)
end

for i = 1, DOT_COUNT do
    local dot = Instance.new("Frame")
    local roll = dotRng:NextInteger(1, 100)
    local size
    if roll <= 4 then
        size = 6
    elseif roll <= 12 then
        size = 5
    elseif roll <= 26 then
        size = 4
    elseif roll <= 47 then
        size = 3
    elseif roll <= 73 then
        size = 2
    else
        size = 1
    end

    dot.Name = "Dot_" .. i
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Size = UDim2.fromOffset(size, size)
    dot.Position = randomDotTarget()
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.BackgroundTransparency = dotRng:NextNumber(0.08, 0.62)
    dot.BorderSizePixel = 0
    dot.ZIndex = StarField.ZIndex + 1
    dot.Parent = StarField

    if size >= 3 then
        corner(dot, math.ceil(size / 2))
    end

    local data = {object = dot, tween = nil}
    movingDots[#movingDots + 1] = data
    animateDot(data)
end

track(Main:GetPropertyChangedSignal("Visible"):Connect(function()
    for _, data in ipairs(movingDots) do
        local tw = data.tween
        if tw then
            if Main.Visible then
                pcall(function() tw:Play() end)
            else
                pcall(function() tw:Pause() end)
            end
        elseif Main.Visible and alive and data.object and data.object.Parent then
            animateDot(data)
        end
    end
end))

local Top = Instance.new("Frame")
Top.Name = "TopBar"
Top.Size = UDim2.new(1, 0, 0, TOP_H)
Top.BackgroundColor3 = Theme.panel
Top.BackgroundTransparency = 0.10
Top.BorderSizePixel = 0
Top.ZIndex = PanelSurface.ZIndex + 3
Top.Parent = PanelSurface
corner(Top, 20)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(ENV.__HX_DEVICE == "mobile" and 50 or 62, 0)
Title.Size = UDim2.new(1, ENV.__HX_DEVICE == "mobile" and -250 or -315, 1, 0)
Title.Font = Enum.Font.GothamBlack
Title.Text = "HX Boat"
Title.TextColor3 = Theme.text
Title.TextSize = ENV.__HX_DEVICE == "mobile" and 15 or 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = Top.ZIndex + 1
Title.Parent = Top

-- Header logo: same asset used by the floating restore button.
ENV.__HX_HeaderLogo = Instance.new("ImageLabel")
ENV.__HX_HeaderLogo.Name = "HeaderLogo"
ENV.__HX_HeaderLogo.AnchorPoint = Vector2.new(0, 0.5)
ENV.__HX_HeaderLogo.Position = UDim2.new(0, ENV.__HX_DEVICE == "mobile" and 13 or 18, 0.5, 0)
ENV.__HX_HeaderLogo.Size = UDim2.fromOffset(ENV.__HX_DEVICE == "mobile" and 27 or 34, ENV.__HX_DEVICE == "mobile" and 27 or 34)
ENV.__HX_HeaderLogo.BackgroundTransparency = 1
ENV.__HX_HeaderLogo.BorderSizePixel = 0
ENV.__HX_HeaderLogo.Image = "rbxassetid://72742584610344"
ENV.__HX_HeaderLogo.ImageColor3 = Color3.new(1, 1, 1)
ENV.__HX_HeaderLogo.ScaleType = Enum.ScaleType.Fit
ENV.__HX_HeaderLogo.ZIndex = Top.ZIndex + 3
ENV.__HX_HeaderLogo.Parent = Top

-- Discord button.
ENV.__HX_DiscordButton = Instance.new("TextButton")
ENV.__HX_DiscordButton.Name = "DiscordButton"
ENV.__HX_DiscordButton.AnchorPoint = Vector2.new(1, 0.5)
ENV.__HX_DiscordButton.Position = UDim2.new(1, ENV.__HX_DEVICE == "mobile" and -88 or -102, 0.5, 0)
ENV.__HX_DiscordButton.Size = UDim2.fromOffset(ENV.__HX_DEVICE == "mobile" and 76 or 92, ENV.__HX_DEVICE == "mobile" and 28 or 34)
ENV.__HX_DiscordButton.BackgroundColor3 = Theme.accent
ENV.__HX_DiscordButton.BackgroundTransparency = 0.02
ENV.__HX_DiscordButton.BorderSizePixel = 0
ENV.__HX_DiscordButton.AutoButtonColor = false
ENV.__HX_DiscordButton.Font = Enum.Font.GothamBlack
ENV.__HX_DiscordButton.Text = "DISCORD"
ENV.__HX_DiscordButton.TextColor3 = Theme.bg
ENV.__HX_DiscordButton.TextSize = ENV.__HX_DEVICE == "mobile" and 8 or 10
ENV.__HX_DiscordButton.ZIndex = Top.ZIndex + 4
ENV.__HX_DiscordButton.Parent = Top
corner(ENV.__HX_DiscordButton, 17)

do
    local scale = Instance.new("UIScale")
    scale.Name = "HoverScale"
    scale.Scale = 1
    scale.Parent = ENV.__HX_DiscordButton
end

track(ENV.__HX_DiscordButton.MouseEnter:Connect(function()
    tween(ENV.__HX_DiscordButton, {BackgroundColor3 = Color3.fromRGB(224, 224, 224)}, 0.10)
    local scale = ENV.__HX_DiscordButton:FindFirstChild("HoverScale")
    if scale then tween(scale, {Scale = 1.035}, 0.10) end
end))

track(ENV.__HX_DiscordButton.MouseLeave:Connect(function()
    tween(ENV.__HX_DiscordButton, {BackgroundColor3 = Theme.accent}, 0.11)
    local scale = ENV.__HX_DiscordButton:FindFirstChild("HoverScale")
    if scale then tween(scale, {Scale = 1}, 0.11) end
end))

track(ENV.__HX_DiscordButton.MouseButton1Down:Connect(function()
    local scale = ENV.__HX_DiscordButton:FindFirstChild("HoverScale")
    if scale then tween(scale, {Scale = 0.94}, 0.055) end
end))

track(ENV.__HX_DiscordButton.MouseButton1Up:Connect(function()
    local scale = ENV.__HX_DiscordButton:FindFirstChild("HoverScale")
    if scale then tween(scale, {Scale = 1}, 0.08) end
end))

track(ENV.__HX_DiscordButton.Activated:Connect(function()
    local invite = "https://discord.gg/sewRzHAG5J"
    local copied = false

    if setclipboard then
        copied = pcall(setclipboard, invite)
    elseif toclipboard then
        copied = pcall(toclipboard, invite)
    end

    -- Some executors/clients allow opening a browser window directly.
    local opened = pcall(function()
        GuiService:OpenBrowserWindow(invite)
    end)

    if copied then
        toast("Discord copiado correctamente.")
    elseif not opened then
        toast("https://discord.gg/sewRzHAG5J")
    end
end))

local Sub = Instance.new("TextLabel")
Sub.BackgroundTransparency = 1
Sub.Position = UDim2.fromOffset(18, 32)
Sub.Size = UDim2.new(1, -185, 0, 15)
Sub.Font = Enum.Font.GothamMedium
Sub.Text = ""
Sub.Visible = false
Sub.TextColor3 = Theme.muted
Sub.TextSize = 9
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.ZIndex = Top.ZIndex + 1
Sub.Parent = Top

local HeaderLine = Instance.new("Frame")
HeaderLine.Position = UDim2.new(0, 14, 1, -1)
HeaderLine.Size = UDim2.new(1, -28, 0, 1)
HeaderLine.BackgroundColor3 = Theme.accent
HeaderLine.BackgroundTransparency = 0.68
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = Top.ZIndex + 1
HeaderLine.Parent = Top

local Status = Instance.new("TextLabel")
Status.AnchorPoint = Vector2.new(1, 0.5)
Status.Position = UDim2.new(1, -92, 0.5, 0)
Status.Size = UDim2.fromOffset(78, 22)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.GothamBold
Status.Text = ""
Status.Visible = false
Status.TextColor3 = Theme.muted
Status.TextSize = 8
Status.TextXAlignment = Enum.TextXAlignment.Right
Status.ZIndex = Top.ZIndex + 2
Status.Parent = Top

local function topButton(text, x, color)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, x, 0.5, 0)
    b.Size = UDim2.fromOffset(ENV.__HX_DEVICE == "mobile" and 28 or 34, ENV.__HX_DEVICE == "mobile" and 28 or 34)
    b.BackgroundColor3 = Theme.accent
    b.BackgroundTransparency = 0.02
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBlack
    b.Text = text
    b.TextColor3 = Theme.bg
    b.TextSize = ENV.__HX_DEVICE == "mobile" and (text == "×" and 16 or 15) or (text == "×" and 19 or 18)
    b.ZIndex = Top.ZIndex + 3
    b.Parent = Top
    corner(b, 17)

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = b

    track(b.MouseEnter:Connect(function()
        tween(b, {BackgroundColor3 = Color3.fromRGB(224, 224, 224)}, 0.10)
        tween(scale, {Scale = 1.055}, 0.10)
    end))
    track(b.MouseLeave:Connect(function()
        tween(b, {BackgroundColor3 = Theme.accent}, 0.11)
        tween(scale, {Scale = 1}, 0.11)
    end))
    track(b.MouseButton1Down:Connect(function()
        tween(scale, {Scale = 0.88}, 0.055)
    end))
    track(b.MouseButton1Up:Connect(function()
        tween(scale, {Scale = 1}, 0.09)
    end))
    return b
end

local Close = topButton("×", ENV.__HX_DEVICE == "mobile" and -10 or -14, Theme.danger)
local Minimize = topButton("−", ENV.__HX_DEVICE == "mobile" and -44 or -56, Theme.text)

local Sidebar = Instance.new("Frame")
Sidebar.Position = UDim2.fromOffset(0, TOP_H)
Sidebar.Size = UDim2.new(0, SIDE_W, 1, -TOP_H)
Sidebar.BackgroundColor3 = Theme.panel
Sidebar.BackgroundTransparency = 0.05
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = PanelSurface.ZIndex + 2
Sidebar.Parent = PanelSurface
corner(Sidebar, 20)

-- Divider is deliberately OUTSIDE the list container so UIListLayout can
-- never reposition it or push the category buttons off-screen.
local SideDivider = Instance.new("Frame")
SideDivider.AnchorPoint = Vector2.new(1, 0)
SideDivider.Position = UDim2.new(1, -1, 0, 9)
SideDivider.Size = UDim2.new(0, 1, 1, -18)
SideDivider.BackgroundColor3 = Theme.accent
SideDivider.BackgroundTransparency = 0.68
SideDivider.BorderSizePixel = 0
SideDivider.ZIndex = Sidebar.ZIndex + 1
SideDivider.Parent = Sidebar

local NavContainer = Instance.new("Frame")
NavContainer.Name = "NavContainer"
NavContainer.Position = UDim2.fromOffset(10, 10)
NavContainer.Size = UDim2.new(1, -21, 1, -20)
NavContainer.BackgroundTransparency = 1
NavContainer.BorderSizePixel = 0
NavContainer.ZIndex = Sidebar.ZIndex + 2
NavContainer.Parent = Sidebar

local SideList = Instance.new("UIListLayout")
SideList.Padding = UDim.new(0, ENV.__HX_DEVICE == "mobile" and 2 or 5)
SideList.SortOrder = Enum.SortOrder.LayoutOrder
SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideList.Parent = NavContainer

local NavTitle = Instance.new("TextLabel")
NavTitle.LayoutOrder = -20
NavTitle.Size = UDim2.new(1, 0, 0, ENV.__HX_DEVICE == "mobile" and 18 or 24)
NavTitle.BackgroundTransparency = 1
NavTitle.Font = Enum.Font.GothamBlack
NavTitle.Text = ENV.__HX_TR("CATEGORÍAS")
NavTitle.TextColor3 = Theme.text
NavTitle.TextSize = ENV.__HX_DEVICE == "mobile" and 8 or 9
NavTitle.TextXAlignment = Enum.TextXAlignment.Left
NavTitle.ZIndex = NavContainer.ZIndex + 2
NavTitle.Parent = NavContainer

local ContentHolder = Instance.new("Frame")
ContentHolder.Position = UDim2.fromOffset(SIDE_W, TOP_H)
ContentHolder.Size = UDim2.new(1, -SIDE_W, 1, -TOP_H)
ContentHolder.BackgroundTransparency = 1
ContentHolder.BorderSizePixel = 0
ContentHolder.ZIndex = PanelSurface.ZIndex + 2
ContentHolder.Parent = PanelSurface

local pages = {}
local categoryButtons = {}
local currentPage

local categories = {
    {"FARM", "Farm"},
    {"AUTO CREAR", "AutoBuild"},
    {"BARCO", "Boat"},
    {"MOVIMIENTO", "Movement"},
    {"TELEPORT", "Teleport"},
    {"VISUALES", "Visuals"},
    {"SERVIDOR", "Server"},
}

local function makePage(key)
    local sc = Instance.new("ScrollingFrame")
    sc.Name = key
    sc.Size = UDim2.fromScale(1, 1)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 2
    sc.ScrollBarImageColor3 = Theme.accent
    sc.CanvasSize = UDim2.fromOffset(0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.Visible = false
    sc.ZIndex = ContentHolder.ZIndex + 1
    sc.Parent = ContentHolder

    local pageScale = Instance.new("UIScale")
    pageScale.Name = "PageMotion"
    pageScale.Scale = 1
    pageScale.Parent = sc

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 11)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = sc

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 7)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = sc

    pages[key] = sc
    return sc
end

for _, item in ipairs(categories) do makePage(item[2]) end

local function renderCategoryButton(key, selected, hovered)
    local b = categoryButtons[key]
    if not b then return end

    local surface = b:FindFirstChild("Surface")
    local label = b:FindFirstChild("Label")
    local arrow = b:FindFirstChild("Arrow")

    b.BackgroundColor3 = Theme.accent

    if selected then
        if surface then tween(surface, {BackgroundColor3 = Theme.accent}, 0.09) end
        if label then tween(label, {TextColor3 = Theme.bg}, 0.09) end
        if arrow then tween(arrow, {TextColor3 = Theme.bg}, 0.09) end
    else
        local idleColor = hovered and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(5, 5, 5)
        if surface then tween(surface, {BackgroundColor3 = idleColor}, 0.09) end
        if label then tween(label, {TextColor3 = Theme.text}, 0.09) end
        if arrow then tween(arrow, {TextColor3 = Theme.text}, 0.09) end
    end
end

local function selectPage(key)
    if currentPage == key then return end
    currentPage = key

    -- Kill any previous visual state first. No delayed hide and no lateral
    -- movement, so rapid category changes cannot leave pages half-shifted.
    for k, p in pairs(pages) do
        p.Position = UDim2.fromOffset(0, 0)
        local pageScale = p:FindFirstChild("PageMotion")
        if pageScale then pageScale.Scale = 1 end
        p.Visible = false
    end

    local nextPage = pages[key]
    if nextPage then
        local pageScale = nextPage:FindFirstChild("PageMotion")
        if pageScale then pageScale.Scale = 0.985 end
        nextPage.ScrollBarImageTransparency = 1
        nextPage.Visible = true

        if pageScale then tween(pageScale, {Scale = 1}, 0.12) end
        tween(nextPage, {ScrollBarImageTransparency = 0}, 0.12)
    end

    for k in pairs(categoryButtons) do
        renderCategoryButton(k, k == key, false)
    end
end

for i, item in ipairs(categories) do
    local label, key = item[1], item[2]

    -- The button itself is the white rounded outline. A nested rounded surface
    -- creates the dark interior; no UIStroke is required.
    local b = Instance.new("TextButton")
    b.Name = "Category_" .. key
    b.LayoutOrder = i
    b.Size = UDim2.new(1, 0, 0, ENV.__HX_DEVICE == "mobile" and 29 or 40)
    b.BackgroundColor3 = Theme.accent
    b.BackgroundTransparency = 0
    b.BorderSizePixel = 0
    b.ClipsDescendants = true
    b.AutoButtonColor = false
    b.Text = ""
    b.ZIndex = NavContainer.ZIndex + 4
    b.Parent = NavContainer
    corner(b, 16)

    local surface = Instance.new("Frame")
    surface.Name = "Surface"
    surface.Position = UDim2.fromOffset(2, 2)
    surface.Size = UDim2.new(1, -4, 1, -4)
    surface.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    surface.BorderSizePixel = 0
    surface.ClipsDescendants = true
    surface.ZIndex = b.ZIndex + 1
    surface.Parent = b
    corner(surface, 13)

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Position = UDim2.fromOffset(ENV.__HX_DEVICE == "mobile" and 9 or 14, 0)
    lbl.Size = UDim2.new(1, ENV.__HX_DEVICE == "mobile" and -29 or -38, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBlack
    lbl.Text = ENV.__HX_TR(label)
    lbl.TextColor3 = Theme.text
    lbl.TextSize = ENV.__HX_DEVICE == "mobile" and 8 or 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = b.ZIndex + 3
    lbl.Parent = b

    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -7, 0.5, 0)
    arrow.Size = UDim2.fromOffset(13, 20)
    arrow.BackgroundTransparency = 1
    arrow.Font = Enum.Font.GothamBlack
    arrow.Text = ">"
    arrow.TextColor3 = Theme.text
    arrow.TextSize = ENV.__HX_DEVICE == "mobile" and 9 or 11
    arrow.ZIndex = b.ZIndex + 3
    arrow.Parent = b

    categoryButtons[key] = b
    renderCategoryButton(key, false, false)

    track(b.MouseEnter:Connect(function()
        if currentPage ~= key then renderCategoryButton(key, false, true) end
    end))
    track(b.MouseLeave:Connect(function()
        if currentPage ~= key then renderCategoryButton(key, false, false) end
    end))
    track(b.Activated:Connect(function()
        selectPage(key)
    end))
end

local Credit = Instance.new("TextLabel")
Credit.LayoutOrder = 100
Credit.Size = UDim2.new(1, 0, 0, 34)
Credit.BackgroundTransparency = 1
Credit.Font = Enum.Font.GothamMedium
Credit.Text = ""
Credit.Visible = false
Credit.TextColor3 = Color3.fromRGB(125, 125, 125)
Credit.TextSize = 8
Credit.TextWrapped = true
Credit.ZIndex = NavContainer.ZIndex + 2
Credit.Parent = NavContainer

--====================================================
-- Components
--====================================================
local function makeSection(page, titleText, desc)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 52)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.ZIndex = page.ZIndex + 1
    holder.Parent = page

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0, 22)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.Text = ENV.__HX_TR(titleText)
    t.TextColor3 = Theme.text
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = holder.ZIndex + 1
    t.Parent = holder

    local d = Instance.new("TextLabel")
    d.Position = UDim2.fromOffset(0, 24)
    d.Size = UDim2.new(1, 0, 0, 22)
    d.BackgroundTransparency = 1
    d.Font = Enum.Font.Gotham
    d.Text = ENV.__HX_TR(desc or "")
    d.TextColor3 = Theme.muted
    d.TextSize = 11
    d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.ZIndex = holder.ZIndex + 1
    d.Parent = holder
    return holder
end

local function makeRow(page, titleText, desc)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 68)
    row.BackgroundColor3 = Theme.bg
    row.BackgroundTransparency = 0.10
    row.BorderSizePixel = 0
    row.ClipsDescendants = true
    row.ZIndex = page.ZIndex + 2
    row.Parent = page
    corner(row, 18)

    local accentBar = Instance.new("Frame")
    accentBar.Position = UDim2.fromOffset(0, 10)
    accentBar.Size = UDim2.new(0, 2, 1, -20)
    accentBar.BackgroundColor3 = Theme.accent
    accentBar.BackgroundTransparency = 0.35
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = row.ZIndex + 1
    accentBar.Parent = row
    corner(accentBar, 2)

    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(14, 11)
    t.Size = UDim2.new(1, -150, 0, 20)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = ENV.__HX_TR(titleText)
    t.TextColor3 = Theme.text
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = row.ZIndex + 1
    t.Parent = row

    local d = Instance.new("TextLabel")
    d.Position = UDim2.fromOffset(14, 33)
    d.Size = UDim2.new(1, -150, 0, 21)
    d.BackgroundTransparency = 1
    d.Font = Enum.Font.Gotham
    d.Text = ENV.__HX_TR(desc or "")
    d.TextColor3 = Theme.muted
    d.TextSize = 10
    d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.ZIndex = row.ZIndex + 1
    d.Parent = row
    return row, t, d
end

local function actionButton(page, titleText, desc, callback, buttonText)
    local row = makeRow(page, titleText, desc)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, -12, 0.5, 0)
    b.Size = UDim2.fromOffset(112, 38)
    b.BackgroundColor3 = Theme.accent
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBold
    b.Text = ENV.__HX_TR(buttonText or "EJECUTAR")
    b.TextColor3 = Theme.bg
    b.TextSize = 10
    b.ZIndex = row.ZIndex + 3
    b.Parent = row
    corner(b, 16)
    local bScale = Instance.new("UIScale")
    bScale.Scale = 1
    bScale.Parent = b
    track(b.MouseEnter:Connect(function()
        tween(b, {BackgroundColor3 = Theme.text}, 0.10)
        tween(bScale, {Scale = 1.035}, 0.10)
    end))
    track(b.MouseLeave:Connect(function()
        tween(b, {BackgroundColor3 = Theme.accent}, 0.10)
        tween(bScale, {Scale = 1}, 0.10)
    end))
    track(b.Activated:Connect(function()
        tween(bScale, {Scale = 0.94}, 0.07)
        task.delay(0.07, function() if alive and bScale.Parent then tween(bScale, {Scale = 1}, 0.11) end end)
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then toast("Error: " .. tostring(err)) end
        end)
    end))
    return b, row
end

local function toggleRow(page, titleText, desc, stateKey, default, callback)
    activeStates[stateKey] = default == true
    local row = makeRow(page, titleText, desc)
    local toggle = Instance.new("TextButton")
    toggle.AnchorPoint = Vector2.new(1, 0.5)
    toggle.Position = UDim2.new(1, -14, 0.5, 0)
    toggle.Size = UDim2.fromOffset(50, 26)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Text = ""
    toggle.ZIndex = row.ZIndex + 3
    toggle.Parent = row
    corner(toggle, 13)

    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Size = UDim2.fromOffset(18, 18)
    dot.BorderSizePixel = 0
    dot.ZIndex = toggle.ZIndex + 1
    dot.Parent = toggle
    corner(dot, 9)

    local function render(instant)
        local on = activeStates[stateKey]
        local propsToggle = {BackgroundColor3 = on and Theme.accent or Theme.soft}
        local propsDot = {
            Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
            BackgroundColor3 = on and Theme.bg or Theme.muted
        }
        if instant then
            for k,v in pairs(propsToggle) do toggle[k] = v end
            for k,v in pairs(propsDot) do dot[k] = v end
        else
            tween(toggle, propsToggle, 0.16)
            tween(dot, propsDot, 0.16)
        end
    end

    render(true)
    track(toggle.Activated:Connect(function()
        activeStates[stateKey] = not activeStates[stateKey]
        render(false)
        if callback then
            task.spawn(function()
                callback(activeStates[stateKey])
                if alive and toggle.Parent then render(false) end
            end)
        end
    end))
    return toggle, row
end

local function sliderRow(page, titleText, desc, minValue, maxValue, defaultValue, step, callback)
    local row, title = makeRow(page, titleText, desc)
    row.Size = UDim2.new(1, 0, 0, 84)
    title.Size = UDim2.new(1, -90, 0, 20)

    local valueLabel = Instance.new("TextLabel")
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, -16, 0, 11)
    valueLabel.Size = UDim2.fromOffset(70, 20)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextColor3 = Theme.text
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = row.ZIndex + 2
    valueLabel.Parent = row

    local bar = Instance.new("Frame")
    bar.Position = UDim2.new(0, 16, 1, -20)
    bar.Size = UDim2.new(1, -32, 0, 5)
    bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bar.BorderSizePixel = 0
    bar.ZIndex = row.ZIndex + 2
    bar.Parent = row
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Theme.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = bar.ZIndex + 1
    fill.Parent = bar
    corner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Theme.accent
    knob.BorderSizePixel = 0
    knob.ZIndex = fill.ZIndex + 1
    knob.Parent = bar
    corner(knob, 7)

    local current = defaultValue
    local dragging = false
    local function quantize(v)
        local q = math.floor(((v - minValue) / step) + 0.5) * step + minValue
        return math.clamp(q, minValue, maxValue)
    end
    local function setValue(v, fire)
        current = quantize(v)
        local alpha = (current - minValue) / (maxValue - minValue)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(current)
        if fire and callback then callback(current) end
    end
    local function fromInput(input)
        local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        setValue(minValue + (maxValue - minValue) * alpha, true)
    end

    track(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(input)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    setValue(defaultValue, true)
    return {Get = function() return current end, Set = function(v) setValue(v, true) end}, row
end

--====================================================
-- Modal / dynamic lists
--====================================================
local ModalShade = Instance.new("TextButton")
ModalShade.Name = "ModalShade"
ModalShade.Size = UDim2.fromScale(1, 1)
ModalShade.BackgroundColor3 = Color3.new(0, 0, 0)
ModalShade.BackgroundTransparency = 0.38
ModalShade.BorderSizePixel = 0
ModalShade.Text = ""
ModalShade.AutoButtonColor = false
ModalShade.Visible = false
ModalShade.ZIndex = 70
ModalShade.Parent = PanelSurface

local Modal = Instance.new("Frame")
Modal.AnchorPoint = Vector2.new(0.5, 0.5)
Modal.Position = UDim2.fromScale(0.5, 0.5)
Modal.Size = ENV.__HX_DEVICE == "mobile" and UDim2.fromOffset(330, 250) or UDim2.fromOffset(430, 360)
Modal.BackgroundColor3 = Theme.bg
Modal.BorderSizePixel = 0
Modal.ClipsDescendants = true
Modal.Visible = false
Modal.ZIndex = ModalShade.ZIndex + 1
Modal.Parent = PanelSurface
corner(Modal, 24)

do
    local scale = Instance.new("UIScale")
    scale.Name = "MotionScale"
    scale.Scale = 1
    scale.Parent = Modal
end
Modal:SetAttribute("AnimationToken", 0)

local ModalTitle = Instance.new("TextLabel")
ModalTitle.Position = UDim2.fromOffset(16, 12)
ModalTitle.Size = UDim2.new(1, -62, 0, 28)
ModalTitle.BackgroundTransparency = 1
ModalTitle.Font = Enum.Font.GothamBold
ModalTitle.TextColor3 = Theme.text
ModalTitle.TextSize = ENV.__HX_DEVICE == "mobile" and 12 or 15
ModalTitle.TextXAlignment = Enum.TextXAlignment.Left
ModalTitle.ZIndex = Modal.ZIndex + 2
ModalTitle.Parent = Modal

local ModalClose = Instance.new("TextButton")
ModalClose.AnchorPoint = Vector2.new(1, 0)
ModalClose.Position = UDim2.new(1, -10, 0, 10)
ModalClose.Size = UDim2.fromOffset(ENV.__HX_DEVICE == "mobile" and 27 or 32, ENV.__HX_DEVICE == "mobile" and 27 or 32)
ModalClose.BackgroundColor3 = Theme.bg
ModalClose.BorderSizePixel = 0
ModalClose.Font = Enum.Font.GothamBold
ModalClose.Text = "×"
ModalClose.TextColor3 = Theme.text
ModalClose.TextSize = 15
ModalClose.ZIndex = Modal.ZIndex + 3
ModalClose.Parent = Modal
corner(ModalClose, 16)

local ModalScroll = Instance.new("ScrollingFrame")
ModalScroll.Position = UDim2.fromOffset(12, 52)
ModalScroll.Size = UDim2.new(1, -24, 1, -64)
ModalScroll.BackgroundTransparency = 1
ModalScroll.BorderSizePixel = 0
ModalScroll.ScrollBarThickness = 3
ModalScroll.ScrollBarImageColor3 = Theme.accent
ModalScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ModalScroll.CanvasSize = UDim2.fromOffset(0, 0)
ModalScroll.ZIndex = Modal.ZIndex + 2
ModalScroll.Parent = Modal

local ModalList = Instance.new("UIListLayout")
ModalList.Padding = UDim.new(0, 7)
ModalList.SortOrder = Enum.SortOrder.LayoutOrder
ModalList.Parent = ModalScroll

local function closeModal()
    if not Modal.Visible then
        ModalShade.Visible = false
        return
    end
    Modal:SetAttribute("AnimationToken", (Modal:GetAttribute("AnimationToken") or 0) + 1)
    local token = Modal:GetAttribute("AnimationToken")
    tween(Modal.MotionScale, {Scale = 0.94}, 0.13)
    tween(Modal, {Position = UDim2.new(0.5, 0, 0.5, 10), BackgroundTransparency = 0.22}, 0.13)
    tween(ModalShade, {BackgroundTransparency = 1}, 0.13)
    task.delay(0.12, function()
        if token ~= Modal:GetAttribute("AnimationToken") then return end
        Modal.Visible = false
        ModalShade.Visible = false
        Modal.Position = UDim2.fromScale(0.5, 0.5)
        Modal.BackgroundTransparency = 0
        Modal.MotionScale.Scale = 1
        ModalShade.BackgroundTransparency = 0.38
    end)
end

local function clearModal()
    for _, c in ipairs(ModalScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function modalButton(text, subtext, callback, danger)
    -- White rounded outer shell so every option is clearly separated.
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 54)
    b.BackgroundColor3 = Theme.accent
    b.BackgroundTransparency = 0
    b.BorderSizePixel = 0
    b.ClipsDescendants = true
    b.AutoButtonColor = false
    b.Text = ""
    b.ZIndex = ModalScroll.ZIndex + 2
    b.Parent = ModalScroll
    corner(b, 16)

    -- Dark inner surface leaves a clean 2px white rounded border.
    local surface = Instance.new("Frame")
    surface.Name = "Surface"
    surface.Position = UDim2.fromOffset(2, 2)
    surface.Size = UDim2.new(1, -4, 1, -4)
    surface.BackgroundColor3 = Theme.panel2
    surface.BackgroundTransparency = 0
    surface.BorderSizePixel = 0
    surface.ClipsDescendants = true
    surface.ZIndex = b.ZIndex + 1
    surface.Parent = b
    corner(surface, 14)

    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(13, 7)
    t.Size = UDim2.new(1, -26, 0, 18)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = ENV.__HX_TR(text)
    t.TextColor3 = danger and Theme.danger or Theme.text
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = surface.ZIndex + 1
    t.Parent = surface

    local s = Instance.new("TextLabel")
    s.Position = UDim2.fromOffset(13, 28)
    s.Size = UDim2.new(1, -26, 0, 17)
    s.BackgroundTransparency = 1
    s.Font = Enum.Font.Gotham
    s.Text = ENV.__HX_TR(subtext or "")
    s.TextColor3 = Theme.muted
    s.TextSize = 9
    s.TextWrapped = true
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.TextYAlignment = Enum.TextYAlignment.Center
    s.ZIndex = surface.ZIndex + 1
    s.Parent = surface

    local modalBtnScale = Instance.new("UIScale")
    modalBtnScale.Scale = 1
    modalBtnScale.Parent = b

    track(b.MouseEnter:Connect(function()
        tween(surface, {BackgroundColor3 = Color3.fromRGB(18, 18, 18)}, 0.10)
        tween(modalBtnScale, {Scale = 1.012}, 0.10)
    end))
    track(b.MouseLeave:Connect(function()
        tween(surface, {BackgroundColor3 = Theme.panel2}, 0.10)
        tween(modalBtnScale, {Scale = 1}, 0.10)
    end))
    track(b.Activated:Connect(function()
        tween(modalBtnScale, {Scale = 0.985}, 0.055)
        task.delay(0.055, function()
            if alive and modalBtnScale.Parent then
                tween(modalBtnScale, {Scale = 1}, 0.09)
            end
        end)
        task.spawn(callback)
    end))
    return b
end

local function modalSearchBox(placeholder, callback)
    local box = Instance.new("TextBox")
    box.Name = "SearchBox"
    box.LayoutOrder = -1000
    box.Size = UDim2.new(1, -4, 0, 42)
    box.BackgroundColor3 = Theme.panel2
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.PlaceholderText = ENV.__HX_TR(placeholder or "Buscar...")
    box.PlaceholderColor3 = Theme.muted
    box.Text = ""
    box.TextColor3 = Theme.text
    box.TextSize = 12
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ZIndex = ModalScroll.ZIndex + 3
    box.Parent = ModalScroll
    corner(box, 16)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 13)
    pad.PaddingRight = UDim.new(0, 13)
    pad.Parent = box

    track(box:GetPropertyChangedSignal("Text"):Connect(function()
        if callback then callback(box.Text) end
    end))
    return box
end

local function openModal(titleText, builder)
    Modal:SetAttribute("AnimationToken", (Modal:GetAttribute("AnimationToken") or 0) + 1)
    clearModal()
    ModalTitle.Text = ENV.__HX_TR(titleText)
    builder()
    ModalShade.Visible = true
    Modal.Visible = true
    ModalShade.BackgroundTransparency = 1
    Modal.Position = UDim2.new(0.5, 0, 0.5, 14)
    Modal.Size = ENV.__HX_DEVICE == "mobile" and UDim2.fromOffset(330, 250) or UDim2.fromOffset(430, 360)
    Modal.BackgroundTransparency = 0.18
    Modal.MotionScale.Scale = 0.92
    tween(ModalShade, {BackgroundTransparency = 0.38}, 0.18)
    tween(Modal, {Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0}, 0.20)
    tween(Modal.MotionScale, {Scale = 1}, 0.22)
end

track(ModalClose.Activated:Connect(closeModal))
track(ModalShade.Activated:Connect(closeModal))

--====================================================
-- Draggable main + floating restore button
--====================================================
local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPos
    local dragInput

    track(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end))

    track(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

makeDraggable(Top, Main)

local Bubble = Instance.new("ImageButton")
Bubble.Name = "RestoreBubble"
Bubble.Size = UDim2.fromOffset(60, 60)
Bubble.Position = UDim2.new(1, -88, 0.5, -29)
Bubble.BackgroundColor3 = Theme.bg
Bubble.BackgroundTransparency = 0.04
Bubble.BorderSizePixel = 0
Bubble.AutoButtonColor = false
Bubble.Image = "rbxassetid://72742584610344"
Bubble.ImageColor3 = Color3.new(1, 1, 1)
Bubble.ImageTransparency = 0
Bubble.ScaleType = Enum.ScaleType.Fit
Bubble.Visible = false
Bubble.ZIndex = 90
Bubble.Parent = Gui
corner(Bubble, 30)

local bubbleDragging = false
local bubbleStart
local bubbleStartPos
local bubbleMoved = false
local bubbleDragInput
track(Bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        bubbleDragging = true
        bubbleMoved = false
        bubbleStart = input.Position
        bubbleStartPos = Bubble.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then bubbleDragging = false end
        end)
    end
end))
track(Bubble.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then bubbleDragInput = input end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if bubbleDragging and input == bubbleDragInput then
        local delta = input.Position - bubbleStart
        if delta.Magnitude > 4 then bubbleMoved = true end
        Bubble.Position = UDim2.new(
            bubbleStartPos.X.Scale, bubbleStartPos.X.Offset + delta.X,
            bubbleStartPos.Y.Scale, bubbleStartPos.Y.Offset + delta.Y
        )
    end
end))
track(Bubble.Activated:Connect(function()
    if bubbleMoved or Main:GetAttribute("Restoring") then return end
    Main:SetAttribute("Restoring", true)

    TweenService:Create(
        Bubble,
        TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            Size = UDim2.fromOffset(50, 50),
            ImageTransparency = 0.28,
            BackgroundTransparency = 0.18
        }
    ):Play()

    task.delay(0.085, function()
        if not alive then return end

        Bubble.Visible = false
        Bubble.Size = UDim2.fromOffset(60, 60)
        Bubble.ImageTransparency = 0
        Bubble.BackgroundTransparency = 0.04

        -- Preserve the exact position where the user left the panel.
        -- Only opacity is animated, so it cannot drift or slip under itself.
        Main.GroupTransparency = 1
        Main.Visible = true
        PanelShell.BackgroundTransparency = 0.45

        TweenService:Create(
            Main,
            TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {GroupTransparency = 0}
        ):Play()
        TweenService:Create(
            PanelShell,
            TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0}
        ):Play()

        task.delay(0.22, function()
            if alive and Main then
                Main.GroupTransparency = 0
                Main:SetAttribute("Restoring", false)
            end
        end)
    end)
end))

--====================================================
-- Feature implementations
--====================================================
local walkSpeed = 16
local jumpPower = 50
ENV.__HX_boatSpeed = 120
ENV.__HX_tweenTPSpeed = 180
ENV.__HX_safeCFrame = nil
ENV.__HX_lastHealth = nil
ENV.__HX_initialGravity = Workspace.Gravity
ENV.__HX_initialGlobalShadows = Lighting.GlobalShadows
ENV.__HX_initialQuality = nil
ENV.__HX_initialTerrain = {
    WaterWaveSize = Workspace.Terrain.WaterWaveSize,
    WaterWaveSpeed = Workspace.Terrain.WaterWaveSpeed,
    WaterReflectance = Workspace.Terrain.WaterReflectance,
    WaterTransparency = Workspace.Terrain.WaterTransparency,
}
pcall(function() ENV.__HX_initialQuality = settings().Rendering.QualityLevel end)

ENV.__HX_farmStartedAt = nil
ENV.__HX_farmAccumulated = 0
ENV.__HX_sessionGoldStart = nil
ENV.__HX_lastKnownGold = nil
ENV.__HX_sessionGoldEarned = 0
ENV.__HX_playerFlySpeed = 90
ENV.__HX_lastSeatAttempt = 0

local function getFarmElapsed()
    local elapsed = ENV.__HX_farmAccumulated
    if ENV.__HX_farmStartedAt then elapsed += os.clock() - ENV.__HX_farmStartedAt end
    return elapsed
end

local function getGoldValue()
    if cachedGoldValueObject and cachedGoldValueObject.Parent then
        return tonumber(cachedGoldValueObject.Value)
    end

    local leaderstats = LP:FindFirstChild("leaderstats")
    if leaderstats then
        for _, v in ipairs(leaderstats:GetChildren()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) and containsAny(v.Name, {"gold", "oro"}) then
                cachedGoldValueObject = v
                return tonumber(v.Value)
            end
        end
    end
    for _, v in ipairs(LP:GetDescendants()) do
        if (v:IsA("IntValue") or v:IsA("NumberValue")) and containsAny(v.Name, {"gold", "oro"}) then
            cachedGoldValueObject = v
            return tonumber(v.Value)
        end
    end
    return nil
end

local function getTeamSpawn()
    local now = os.clock()
    local team = LP.Team
    local teamKey = team and (team.Name .. ":" .. tostring(team.TeamColor)) or "none"
    if worldCache.teamSpawn and worldCache.teamSpawn.Parent and worldCache.teamKey == teamKey and (now - worldCache.teamSpawnAt) < 8 then
        return worldCache.teamSpawn
    end

    local found
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            if team and not d.Neutral and d.TeamColor == team.TeamColor then found = d break end
            if team and containsAny(d.Name, {lower(team.Name), "spawn", "zone"}) then found = found or d end
        end
    end
    if not found and team then
        local teamName = lower(team.Name)
        local best, bestScore
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = lower(d.Name .. " " .. (d.Parent and d.Parent.Name or ""))
                local score = 0
                if string.find(n, teamName, 1, true) then score += 5 end
                if containsAny(n, {"zone", "build", "spawn", "team"}) then score += 3 end
                if score > 0 and (not bestScore or score > bestScore) then best, bestScore = d, score end
            end
        end
        found = best
    end

    worldCache.teamSpawn = found
    worldCache.teamSpawnAt = now
    worldCache.teamKey = teamKey
    return found
end
local function getNearestSeat(maxDistance)
    local root = getRoot()
    if not root then return nil end
    maxDistance = maxDistance or 450
    local now = os.clock()
    local cached = worldCache.nearestSeat
    if cached and cached.Parent and (cached.Position - root.Position).Magnitude <= maxDistance and (now - worldCache.seatAt) < 2.5 then
        return cached
    end
    if (now - worldCache.seatAt) < 2.5 and worldCache.seatRadius >= maxDistance then return nil end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = getChar()
    if char then params.FilterDescendantsInstances = {char} end
    params.MaxParts = 350

    local best, dist = nil, maxDistance
    local ok, nearby = pcall(function()
        return Workspace:GetPartBoundsInRadius(root.Position, maxDistance, params)
    end)
    if ok and nearby then
        for _, d in ipairs(nearby) do
            if (d:IsA("VehicleSeat") or d:IsA("Seat")) and not isCharacterPart(d) then
                local m = (d.Position - root.Position).Magnitude
                if m < dist then best, dist = d, m end
            end
        end
    end

    worldCache.nearestSeat = best
    worldCache.seatAt = now
    worldCache.seatRadius = maxDistance
    return best
end

local function getBoatRoot()
    local now = os.clock()
    local seat = getSeat()
    if seat and seat.Parent then
        lastSeat = seat
        local root = seat.AssemblyRootPart or seat
        worldCache.boatRoot = root
        worldCache.boatRootAt = now
        return root
    end

    if lastSeat and lastSeat.Parent then
        local root = lastSeat.AssemblyRootPart or lastSeat
        worldCache.boatRoot = root
        worldCache.boatRootAt = now
        return root
    end

    if worldCache.boatRoot and worldCache.boatRoot.Parent and (now - worldCache.boatRootAt) < 1.25 then
        return worldCache.boatRoot
    end

    seat = getNearestSeat(500)
    if seat then
        lastSeat = seat
        local root = seat.AssemblyRootPart or seat
        worldCache.boatRoot = root
        worldCache.boatRootAt = now
        return root
    end

    worldCache.boatRoot = nil
    worldCache.boatRootAt = now
    return nil
end

local function getBoatParts()
    local root = getBoatRoot()
    if not root then return {}, nil end
    local parts = {root}
    local ok, connected = pcall(function() return root:GetConnectedParts(true) end)
    if ok and type(connected) == "table" then parts = connected end
    return parts, root
end

local function setPartCache(cache, part, property, value)
    if cache[part] == nil then
        local ok, old = pcall(function() return part[property] end)
        if ok then cache[part] = old end
    end
    pcall(function() part[property] = value end)
end

local function restorePartCache(cache, property)
    for part, old in pairs(cache) do
        if part and part.Parent then pcall(function() part[property] = old end) end
    end
    table.clear(cache)
end

local function setNoclip(enabled)
    if not enabled then
        for part, old in pairs(characterCollisionCache) do
            if part and part.Parent then pcall(function() part.CanCollide = old end) end
        end
        table.clear(characterCollisionCache)
    end
end

local function setAntiHazard(enabled)
    if not enabled then
        for part, old in pairs(hazardTouchCache) do
            if part and part.Parent then pcall(function() part.CanTouch = old end) end
        end
        table.clear(hazardTouchCache)
        return
    end

    local descendants = Workspace:GetDescendants()
    for i, d in ipairs(descendants) do
        if d:IsA("BasePart") and containsAny(d.Name, {"water", "lava", "acid", "toxic", "damage", "kill", "hazard"}) then
            if hazardTouchCache[d] == nil then hazardTouchCache[d] = d.CanTouch end
            pcall(function() d.CanTouch = false end)
        end
        if i % 300 == 0 then task.wait() end
    end
end

local function destroyFlyObjects()
    for _, obj in pairs(flyObjects) do if obj then pcall(function() obj:Destroy() end) end end
    table.clear(flyObjects)
end

local function ensureBoatFlyObjects(seat)
    if flyObjects.seat == seat and flyObjects.velocity and flyObjects.velocity.Parent then return end
    destroyFlyObjects()

    local vel = Instance.new("BodyVelocity")
    vel.Name = "BABFT_BoatFlyVelocity"
    vel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    vel.P = 30000
    vel.Velocity = Vector3.zero
    vel.Parent = seat

    local gyro = Instance.new("BodyGyro")
    gyro.Name = "BABFT_BoatFlyGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 30000
    gyro.D = 700
    gyro.CFrame = seat.CFrame
    gyro.Parent = seat

    flyObjects.seat = seat
    flyObjects.velocity = vel
    flyObjects.gyro = gyro
end

local function getMoveVector()
    Camera = Workspace.CurrentCamera or Camera
    if not Camera then return Vector3.zero end
    local dir = Vector3.zero
    local look = Camera.CFrame.LookVector
    local right = Camera.CFrame.RightVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    local flatRight = Vector3.new(right.X, 0, right.Z)
    if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
    if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

    if pressed.W then dir += flatLook end
    if pressed.S then dir -= flatLook end
    if pressed.D then dir += flatRight end
    if pressed.A then dir -= flatRight end
    if pressed.Space then dir += Vector3.yAxis end
    if pressed.Ctrl then dir -= Vector3.yAxis end
    return dir.Magnitude > 0 and dir.Unit or Vector3.zero
end

local keyMap = {
    [Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S", [Enum.KeyCode.D] = "D",
    [Enum.KeyCode.Space] = "Space", [Enum.KeyCode.LeftControl] = "Ctrl", [Enum.KeyCode.RightControl] = "Ctrl"
}
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = keyMap[input.KeyCode]
    if k then pressed[k] = true end

    if activeStates.infiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local hum = getHum()
        if hum and hum.Health > 0 then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end

    if activeStates.clickTP and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = input.Position
        local function inside(obj)
            if not obj or not obj.Visible then return false end
            local a, z = obj.AbsolutePosition, obj.AbsoluteSize
            return pos.X >= a.X and pos.X <= a.X + z.X and pos.Y >= a.Y and pos.Y <= a.Y + z.Y
        end
        if not inside(Main) and not inside(Bubble) then
            local mouse = LP:GetMouse()
            if mouse and mouse.Hit then task.spawn(function() tpToCFrame(mouse.Hit * CFrame.new(0, 3, 0)) end) end
        end
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    local k = keyMap[input.KeyCode]
    if k then pressed[k] = false end
end))

local function doAutoCollect()
    local root = getRoot()
    if not root then return end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = getChar()
    if char then params.FilterDescendantsInstances = {char} end
    params.MaxParts = 220

    local ok, nearby = pcall(function()
        return Workspace:GetPartBoundsInRadius(root.Position, 280, params)
    end)
    if not ok or not nearby then return end

    local touched = 0
    for _, d in ipairs(nearby) do
        if d:IsA("BasePart") then
            if containsAny(d.Name, {"gold", "collect", "pickup", "treasure", "chest"}) and firetouchinterest then
                pcall(function()
                    firetouchinterest(root, d, 0)
                    firetouchinterest(root, d, 1)
                end)
                touched += 1
            end

            if fireproximityprompt then
                local prompt = d:FindFirstChildOfClass("ProximityPrompt")
                if prompt and prompt.Enabled and (d.Position - root.Position).Magnitude <= prompt.MaxActivationDistance + 8 then
                    pcall(fireproximityprompt, prompt)
                end
            end
        end
        if touched >= 18 then break end
    end
end

local function rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
end

local function serverHop()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local body
    local ok, result = pcall(function() return game:HttpGet(url) end)
    if ok then body = result end

    if not body then
        local req = (syn and syn.request) or http_request or request
        if req then
            local okReq, response = pcall(req, {Url = url, Method = "GET"})
            if okReq and response then body = response.Body end
        end
    end

    if not body then
        toast("Tu executor no permitió consultar servidores")
        return
    end

    local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okJson or type(data) ~= "table" or type(data.data) ~= "table" then
        toast("No se pudo leer la lista de servidores")
        return
    end

    local candidates = {}
    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            candidates[#candidates + 1] = server
        end
    end
    if #candidates == 0 then
        toast("No encontré otro servidor disponible")
        return
    end
    local target = candidates[math.random(1, #candidates)]
    TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LP)
end

local function clearPlayerFlyObjects()
    for _, obj in pairs(playerFlyObjects) do
        if obj then pcall(function() obj:Destroy() end) end
    end
    table.clear(playerFlyObjects)
end

local function ensurePlayerFlyObjects(root)
    if playerFlyObjects.root == root and playerFlyObjects.velocity and playerFlyObjects.velocity.Parent then return end
    clearPlayerFlyObjects()
    local vel = Instance.new("BodyVelocity")
    vel.Name = "BABFT_PlayerFlyVelocity"
    vel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    vel.P = 30000
    vel.Velocity = Vector3.zero
    vel.Parent = root

    local gyro = Instance.new("BodyGyro")
    gyro.Name = "BABFT_PlayerFlyGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 30000
    gyro.D = 650
    gyro.CFrame = root.CFrame
    gyro.Parent = root

    playerFlyObjects.root = root
    playerFlyObjects.velocity = vel
    playerFlyObjects.gyro = gyro
end

local function clearBoatUtilityObjects()
    for _, obj in pairs(boatUtilityObjects) do
        if obj and typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
    end
    table.clear(boatUtilityObjects)
end

local function ensureBoatGyro(root)
    if boatUtilityObjects.root == root and boatUtilityObjects.gyro and boatUtilityObjects.gyro.Parent then
        return boatUtilityObjects.gyro
    end
    clearBoatUtilityObjects()
    local gyro = Instance.new("BodyGyro")
    gyro.Name = "BABFT_BoatUtilityGyro"
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    gyro.P = 45000
    gyro.D = 900
    gyro.CFrame = root.CFrame
    gyro.Parent = root
    boatUtilityObjects.root = root
    boatUtilityObjects.gyro = gyro
    return gyro
end

local function setBoatNoclip(enabled)
    if not enabled then
        activeStates._boatNoclipAt = nil
        restorePartCache(boatCollisionCache, "CanCollide")
        return
    end
    local now = os.clock()
    if activeStates._boatNoclipAt and now - activeStates._boatNoclipAt < 3.5 then return end
    activeStates._boatNoclipAt = now
    local parts = getBoatParts()
    for i, part in ipairs(parts) do
        if part:IsA("BasePart") then setPartCache(boatCollisionCache, part, "CanCollide", false) end
    end
end

local function setBoatProtection(enabled)
    if not enabled then
        activeStates._boatProtectAt = nil
        restorePartCache(boatTouchCache, "CanTouch")
        return
    end
    local now = os.clock()
    if activeStates._boatProtectAt and now - activeStates._boatProtectAt < 3.5 then return end
    activeStates._boatProtectAt = now
    local parts = getBoatParts()
    for i, part in ipairs(parts) do
        if part:IsA("BasePart") then setPartCache(boatTouchCache, part, "CanTouch", false) end
    end
end

local function getThrusterObjects()
    local parts = getBoatParts()
    local found, seen = {}, {}
    for _, part in ipairs(parts) do
        local node = part
        for _ = 1, 3 do
            if node and not seen[node] and containsAny(node.Name, {"thruster", "propeller", "jet", "motor", "rocket"}) then
                seen[node] = true
                found[#found + 1] = node
            end
            node = node and node.Parent
        end
    end
    return found
end

local function activateThrusters()
    local found = getThrusterObjects()
    local activated = 0
    for _, obj in ipairs(found) do
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("ProximityPrompt") and fireproximityprompt then
                pcall(fireproximityprompt, d)
                activated += 1
            elseif d:IsA("ClickDetector") and fireclickdetector then
                pcall(fireclickdetector, d)
                activated += 1
            elseif d:IsA("BoolValue") and containsAny(d.Name, {"enabled", "active", "on"}) then
                pcall(function() d.Value = true end)
                activated += 1
            end
        end
    end
    return activated
end

local function refillFuel()
    local now = os.clock()
    local root = getBoatRoot()
    if not root then return 0 end

    local cache = activeStates._fuelValues
    if type(cache) ~= "table" or activeStates._fuelRoot ~= root or not activeStates._fuelScanAt or now - activeStates._fuelScanAt > 8 then
        cache = {}
        activeStates._fuelValues = cache
        activeStates._fuelRoot = root
        activeStates._fuelScanAt = now
        local parts = getBoatParts()
        local seen = {}
        for i, part in ipairs(parts) do
            local parent = part.Parent
            if parent and not seen[parent] then
                seen[parent] = true
                for _, d in ipairs(parent:GetDescendants()) do
                    if (d:IsA("NumberValue") or d:IsA("IntValue")) and containsAny(d.Name, {"fuel", "charge", "energy"}) then
                        cache[#cache + 1] = d
                    end
                end
            end
        end
    end

    local changed = 0
    for i = #cache, 1, -1 do
        local d = cache[i]
        if not d or not d.Parent then
            table.remove(cache, i)
        else
            pcall(function() d.Value = math.max(tonumber(d.Value) or 0, 999999) end)
            changed += 1
        end
    end
    return changed
end

local function isVisibleGuiObject(obj)
    local cur = obj
    while cur and cur:IsA("GuiObject") do
        if not cur.Visible then return false end
        cur = cur.Parent
    end
    return true
end

local function guiButtonLabel(button)
    local text = ""
    if button:IsA("TextButton") then text = button.Text or "" end
    if text == "" then
        for _, d in ipairs(button:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then
                text ..= " " .. d.Text
            end
        end
    end
    return string.gsub((button.Name or "") .. " " .. text, "^%s+", "")
end

local function findGameButtons(words)
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local results = {}
    if not pg then return results end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("ImageButton")) and not d:IsDescendantOf(Gui) and isVisibleGuiObject(d) then
            local label = lower(guiButtonLabel(d))
            for _, word in ipairs(words) do
                if string.find(label, lower(word), 1, true) then
                    results[#results + 1] = {button = d, label = guiButtonLabel(d)}
                    break
                end
            end
        end
    end
    return results
end

local function activateGuiButton(button)
    if not button or not button.Parent then return false end
    local ok = false
    if firesignal then
        ok = pcall(function()
            firesignal(button.Activated)
            if button:IsA("TextButton") or button:IsA("ImageButton") then firesignal(button.MouseButton1Click) end
        end)
    end
    if not ok then ok = pcall(function() button:Activate() end) end
    return ok
end

local function autoSaveBuild()
    local buttons = findGameButtons({"save", "guardar"})
    if #buttons == 0 then
        toast("Abre el menú de guardar del juego y vuelve a intentarlo")
        return false
    end
    return activateGuiButton(buttons[1].button)
end

local function instantLaunch()
    local loads = findGameButtons({"load", "cargar"})
    if #loads > 0 then
        activateGuiButton(loads[1].button)
        task.wait(0.8)
    end
    return launchBoat()
end

local function getQuestTargets()
    local now = os.clock()
    local cached = activeStates._questTargets
    if type(cached) == "table" and activeStates._questScanAt and now - activeStates._questScanAt < 15 then
        local valid = {}
        for _, prompt in ipairs(cached) do if prompt and prompt.Parent then valid[#valid + 1] = prompt end end
        activeStates._questTargets = valid
        return valid
    end

    local results = {}
    local descendants = Workspace:GetDescendants()
    for i, d in ipairs(descendants) do
        if d:IsA("ProximityPrompt") then
            local ancestry = d.Name .. " " .. d.ActionText .. " " .. d.ObjectText
            local cur = d.Parent
            for _ = 1, 3 do
                if cur then ancestry ..= " " .. cur.Name; cur = cur.Parent end
            end
            if containsAny(ancestry, {"quest", "mission", "npc", "misión", "mision"}) then
                results[#results + 1] = d
                if #results >= 40 then break end
            end
        end
        if i % 320 == 0 then task.wait() end
    end
    activeStates._questTargets = results
    activeStates._questScanAt = now
    return results
end

local function interactQuestPrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    local part = prompt.Parent:IsA("BasePart") and prompt.Parent or findFirstPart(prompt.Parent)
    if part then tpToPart(part, Vector3.new(0, 3, 0)) end
    task.wait(0.15)
    if fireproximityprompt then
        return pcall(fireproximityprompt, prompt)
    end
    return false
end

local function lowPlayerServer()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local body
    local ok, result = pcall(function() return game:HttpGet(url) end)
    if ok then body = result end
    if not body then
        local req = (syn and syn.request) or http_request or request
        if req then
            local okReq, response = pcall(req, {Url = url, Method = "GET"})
            if okReq and response then body = response.Body end
        end
    end
    if not body then return toast("Tu executor no permitió consultar servidores") end
    local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okJson or not data or type(data.data) ~= "table" then return toast("No pude leer los servidores") end
    table.sort(data.data, function(a, b) return (a.playing or 999) < (b.playing or 999) end)
    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LP)
            return
        end
    end
    toast("No encontré un servidor con menos jugadores")
end

local function restoreHiddenPlayers()
    for part, old in pairs(hiddenPlayerCache) do
        if part and part.Parent then pcall(function() part.LocalTransparencyModifier = old end) end
    end
    table.clear(hiddenPlayerCache)
end

local function applyHideOtherPlayers()
    if not activeStates.hideOtherPlayers then return restoreHiddenPlayers() end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            for _, d in ipairs(plr.Character:GetDescendants()) do
                if d:IsA("BasePart") then
                    if hiddenPlayerCache[d] == nil then hiddenPlayerCache[d] = d.LocalTransparencyModifier end
                    d.LocalTransparencyModifier = 1
                end
            end
        end
    end
end

local function restoreHiddenBoats()
    for part, old in pairs(hiddenBoatCache) do
        if part and part.Parent then pcall(function() part.LocalTransparencyModifier = old end) end
    end
    table.clear(hiddenBoatCache)
end

local function applyHideOtherBoats()
    if not activeStates.hideOtherBoats then return restoreHiddenBoats() end
    local root = getRoot()
    if not root then return end
    local ownRoot = getBoatRoot()
    local own = {}
    if ownRoot then
        local okOwn, parts = pcall(function() return ownRoot:GetConnectedParts(true) end)
        if okOwn then for _, p in ipairs(parts) do own[p] = true end end
        own[ownRoot] = true
    end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = getChar()
    if char then params.FilterDescendantsInstances = {char} end
    params.MaxParts = 500

    local ok, nearby = pcall(function()
        return Workspace:GetPartBoundsInRadius(root.Position, 1200, params)
    end)
    if not ok or not nearby then return end

    local processedRoots = {}
    for _, seat in ipairs(nearby) do
        if (seat:IsA("Seat") or seat:IsA("VehicleSeat")) and not isCharacterPart(seat) then
            local assembly = seat.AssemblyRootPart or seat
            if not processedRoots[assembly] and not own[assembly] then
                processedRoots[assembly] = true
                local okParts, parts = pcall(function() return assembly:GetConnectedParts(true) end)
                if okParts then
                    for _, p in ipairs(parts) do
                        if p:IsA("BasePart") and not own[p] then
                            if hiddenBoatCache[p] == nil then hiddenBoatCache[p] = p.LocalTransparencyModifier end
                            p.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
        end
    end
end

local function applyPerformanceState()
    local disableParticles = activeStates.removeParticles or activeStates.fpsBooster
    local disableShadows = activeStates.disableShadows or activeStates.fpsBooster or activeStates.lowGraphics
    local removeWater = activeStates.removeWaterEffects or activeStates.fpsBooster or activeStates.lowGraphics
    local lowQuality = activeStates.lowGraphics or activeStates.fpsBooster

    -- One Workspace pass maximum. The previous build could traverse the entire
    -- map multiple times for one graphics update.
    if disableParticles or disableShadows then
        local descendants = Workspace:GetDescendants()
        for i, d in ipairs(descendants) do
            if disableParticles and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")) then
                if particleCache[d] == nil then particleCache[d] = d.Enabled end
                d.Enabled = false
            end
            if disableShadows and d:IsA("BasePart") then
                if shadowCache[d] == nil then shadowCache[d] = d.CastShadow end
                d.CastShadow = false
            end
            if i % 320 == 0 then task.wait() end
        end
    end

    if not disableParticles then
        for d, old in pairs(particleCache) do if d and d.Parent then pcall(function() d.Enabled = old end) end end
        table.clear(particleCache)
    end

    if disableShadows then
        Lighting.GlobalShadows = false
    else
        Lighting.GlobalShadows = ENV.__HX_initialGlobalShadows
        for d, old in pairs(shadowCache) do if d and d.Parent then pcall(function() d.CastShadow = old end) end end
        table.clear(shadowCache)
    end

    if removeWater then
        pcall(function()
            Workspace.Terrain.WaterWaveSize = 0
            Workspace.Terrain.WaterWaveSpeed = 0
            Workspace.Terrain.WaterReflectance = 0
            Workspace.Terrain.WaterTransparency = 1
        end)
    else
        pcall(function()
            Workspace.Terrain.WaterWaveSize = ENV.__HX_initialTerrain.WaterWaveSize
            Workspace.Terrain.WaterWaveSpeed = ENV.__HX_initialTerrain.WaterWaveSpeed
            Workspace.Terrain.WaterReflectance = ENV.__HX_initialTerrain.WaterReflectance
            Workspace.Terrain.WaterTransparency = ENV.__HX_initialTerrain.WaterTransparency
        end)
    end

    pcall(function()
        if lowQuality then settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        elseif ENV.__HX_initialQuality then settings().Rendering.QualityLevel = ENV.__HX_initialQuality end
    end)
end

--====================================================
-- Populate UI
--====================================================
-- FARM
makeSection(pages.Farm, "FARM", "Finalización, oro y recolección automática.")

toggleRow(pages.Farm, "Auto Farm Gold / Auto Finish",
    "Completa el recorrido automáticamente para obtener oro.",
    "autoFarm", false, function(on)
        if on and activeStates._buildFarmBusy then
            activeStates.autoFarm = false
            toast("Ya se está farmeando oro para una construcción.")
            return
        end

        if on and activeStates._materialFarmBusy then
            activeStates.autoFarm = false
            toast("Auto Farm Materiales detenido.")
            return
        end

        activeStates._farmToken = (tonumber(activeStates._farmToken) or 0) + 1
        local token = activeStates._farmToken

        if on then
            if not ENV.__HX_farmStartedAt then ENV.__HX_farmStartedAt = os.clock() end
            task.spawn(function()
                while alive and activeStates.autoFarm and activeStates._farmToken == token do
                    if getRoot() and not activeStates._finishBusy then
                        local ok, msg = finishRun(0.40, token)
                        if not ok and msg and msg ~= "Auto Farm detenido" and msg ~= "Ya hay una finalización en curso" then
                            toast(msg)
                        end

                        -- Do not immediately hammer every stage again while the
                        -- game is still streaming/resetting after the Treasure.
                        local cooldown = ok and 6.0 or 2.0
                        local waited = 0
                        while waited < cooldown and alive and activeStates.autoFarm and activeStates._farmToken == token do
                            task.wait(0.5)
                            waited += 0.5
                        end
                    else
                        task.wait(0.75)
                    end
                end
            end)
        elseif ENV.__HX_farmStartedAt then
            ENV.__HX_farmAccumulated += os.clock() - ENV.__HX_farmStartedAt
            ENV.__HX_farmStartedAt = nil
        end
    end)

actionButton(pages.Farm, "Auto Finish ahora", "Completa el recorrido una vez.", function()
    local ok, msg = finishRun(0.40)
    toast(ok and "Finalización ejecutada" or (msg or "No se pudo finalizar"))
end, "FINALIZAR")

activeStates._materialFarmMode = activeStates._materialFarmMode or "balanced"

actionButton(
    pages.Farm,
    "Material objetivo",
    "Elige qué material quieres conseguir automáticamente.",
    function()
        openModal("Selecciona material", function()
            modalButton("Equilibrado", "Compra primero el material del que tengas menos cantidad.", function()
                activeStates._materialFarmMode = "balanced"
                closeModal()
                toast(ENV.__HX_TR("Material seleccionado: ") .. ENV.__HX_TR("Equilibrado"))
            end)

            modalButton("Madera", "Prioriza paquetes de madera.", function()
                activeStates._materialFarmMode = "wood"
                closeModal()
                toast(ENV.__HX_TR("Material seleccionado: ") .. ENV.__HX_TR("Madera"))
            end)

            modalButton("Piedra", "Prioriza paquetes de piedra.", function()
                activeStates._materialFarmMode = "stone"
                closeModal()
                toast(ENV.__HX_TR("Material seleccionado: ") .. ENV.__HX_TR("Piedra"))
            end)

            modalButton("Metal", "Prioriza paquetes de metal.", function()
                activeStates._materialFarmMode = "metal"
                closeModal()
                toast(ENV.__HX_TR("Material seleccionado: ") .. ENV.__HX_TR("Metal"))
            end)

            modalButton("Titanio", "Prioriza paquetes de titanio.", function()
                activeStates._materialFarmMode = "titanium"
                closeModal()
                toast(ENV.__HX_TR("Material seleccionado: ") .. ENV.__HX_TR("Titanio"))
            end)
        end)
    end,
    "SELECCIONAR"
)

toggleRow(
    pages.Farm,
    "Auto Farm Materiales",
    "Farmea oro y compra automáticamente el material seleccionado.",
    "autoFarmMaterials",
    false,
    function(on)
        activeStates._materialFarmToken = (tonumber(activeStates._materialFarmToken) or 0) + 1
        local token = activeStates._materialFarmToken

        if not on then
            activeStates._materialFarmBusy = false
            toast("Auto Farm Materiales detenido.")
            return
        end

        if activeStates.autoFarm then
            activeStates.autoFarmMaterials = false
            toast("Desactiva Auto Farm Gold antes de usar Auto Farm Materiales.")
            return
        end

        if activeStates._buildFarmBusy or activeStates.autoBuildBoatBusy then
            activeStates.autoFarmMaterials = false
            toast("Hay una construcción automática usando el farmeo. Inténtalo cuando termine.")
            return
        end

        activeStates._materialFarmBusy = true
        toast("Auto Farm Materiales iniciado.")

        task.spawn(function()
            local failures = 0

            while alive
                and activeStates.autoFarmMaterials
                and activeStates._materialFarmToken == token do

                if activeStates._buildFarmBusy or activeStates.autoBuildBoatBusy then
                    task.wait(1.0)
                    continue
                end

                local data = LP:FindFirstChild("Data")
                local shopRemote = Workspace:FindFirstChild("ItemBoughtFromShop")

                if not data or not shopRemote or not shopRemote:IsA("RemoteEvent") then
                    failures += 1
                    if failures >= 8 then
                        activeStates.autoFarmMaterials = false
                        break
                    end
                    task.wait(1.5)
                    continue
                end

                local mode = activeStates._materialFarmMode or "balanced"

                local function materialStock(name)
                    local obj = data:FindFirstChild(name)
                    return obj and math.max(0, math.floor(tonumber(obj.Value) or 0)) or 0
                end

                local materialOptions = {
                    wood = {
                        label = "Madera",
                        product = "Wood Block",
                        internal = "WoodBlock",
                        price = 250
                    },
                    stone = {
                        label = "Piedra",
                        product = "Stone Block",
                        internal = "StoneBlock",
                        price = 275
                    },
                    metal = {
                        label = "Metal",
                        product = "Metal Block",
                        internal = "MetalBlock",
                        price = 325
                    },
                    titanium = {
                        label = "Titanio",
                        product = "Titanium Block",
                        internal = "TitaniumBlock",
                        price = 400
                    }
                }

                local selected = materialOptions[mode]
                if mode == "balanced" or not selected then
                    local lowestKey, lowestStock
                    for _, key in ipairs({"wood", "stone", "metal", "titanium"}) do
                        local option = materialOptions[key]
                        local amount = materialStock(option.internal)
                        if lowestStock == nil or amount < lowestStock then
                            lowestKey, lowestStock = key, amount
                        end
                    end
                    selected = materialOptions[lowestKey or "wood"]
                end

                local gold = tonumber(getGoldValue()) or 0

                if gold < selected.price then
                    local beforeGold = gold
                    local ok, msg = finishRun(0.40)

                    if ok then
                        failures = 0

                        local waited = 0
                        while waited < 7
                            and alive
                            and activeStates.autoFarmMaterials
                            and activeStates._materialFarmToken == token do

                            task.wait(0.5)
                            waited += 0.5

                            if (tonumber(getGoldValue()) or 0) > beforeGold and waited >= 2 then
                                break
                            end
                        end

                        task.wait(0.8)
                    else
                        failures += 1
                        if msg and msg ~= "Auto Farm detenido" and msg ~= "Ya hay una finalización en curso" then
                            toast(msg)
                        end
                        if failures >= 8 then
                            activeStates.autoFarmMaterials = false
                            break
                        end
                        task.wait(1.5)
                    end
                else
                    local beforeStock = materialStock(selected.internal)
                    local beforeGold = gold

                    local okPurchase = pcall(function()
                        shopRemote:FireServer(selected.product)
                    end)

                    if okPurchase then
                        task.wait(0.55)

                        local afterStock = materialStock(selected.internal)
                        local afterGold = tonumber(getGoldValue()) or beforeGold

                        if afterStock > beforeStock or afterGold < beforeGold then
                            failures = 0
                            toast(
                                ENV.__HX_TR("Material comprado automáticamente: ")
                                .. ENV.__HX_TR(selected.label)
                            )
                            task.wait(0.65)
                        else
                            failures += 1
                            if failures >= 5 then
                                toast("No pude comprar el material seleccionado.")
                                activeStates.autoFarmMaterials = false
                                break
                            end
                            task.wait(1.0)
                        end
                    else
                        failures += 1
                        if failures >= 5 then
                            toast("No pude comprar el material seleccionado.")
                            activeStates.autoFarmMaterials = false
                            break
                        end
                        task.wait(1.0)
                    end
                end
            end

            activeStates._materialFarmBusy = false
        end)
    end
)

toggleRow(pages.Farm, "Auto Collect", "Recoge automáticamente recompensas y objetos cercanos.", "autoCollect", false)

toggleRow(pages.Farm, "Auto Launch", "Lanza el barco automáticamente cuando sea necesario.", "autoLaunch", false, function(on)
    activeStates._launchToken = (tonumber(activeStates._launchToken) or 0) + 1
    local token = activeStates._launchToken
    if on then
        task.spawn(function()
            while alive and activeStates.autoLaunch and activeStates._launchToken == token do
                launchBoat()
                for _ = 1, 8 do
                    if not alive or not activeStates.autoLaunch or activeStates._launchToken ~= token then break end
                    task.wait(0.5)
                end
            end
        end)
    end
end)

toggleRow(pages.Farm, "Auto Quest compatible", "Completa automáticamente la misión seleccionada cuando esté disponible.", "autoQuest", false)

actionButton(pages.Farm, "Quest Selector", "Elige la misión que quieres automatizar.", function()
    openModal("Quest Selector", function()
        local quests = getQuestTargets()
        if #quests == 0 then
            modalButton("No se detectaron quests compatibles", "No hay misiones compatibles disponibles.", function() end)
            return
        end
        for i, prompt in ipairs(quests) do
            local parentName = prompt.Parent and prompt.Parent.Name or "NPC"
            modalButton(string.format("%02d · %s", i, prompt.ObjectText ~= "" and prompt.ObjectText or parentName), prompt.ActionText ~= "" and prompt.ActionText or prompt.Name, function()
                selectedQuestTarget = prompt
                closeModal()
                toast("Quest seleccionada")
            end)
        end
    end)
end, "SELECCIONAR")

local farmStatsRow, farmStatsTitle, farmStatsDesc = makeRow(pages.Farm, "FARM STATS", "Esperando datos de oro...")
farmStatsRow.Size = UDim2.new(1, 0, 0, 92)
farmStatsTitle.Size = UDim2.new(1, -32, 0, 20)
farmStatsDesc.Size = UDim2.new(1, -32, 0, 46)
farmStatsDesc.TextYAlignment = Enum.TextYAlignment.Top

-- AUTO BUILD
makeSection(pages.AutoBuild, "CREACIÓN AUTOMÁTICA", "Crea barcos, carros y aviones adaptándose a los materiales disponibles.")

-- Farm exclusivo de una construcción pendiente.
-- Solo se usa cuando el oro ACTUAL no cubre el coste total estimado.
activeStates._farmGoldForBuild = function(targetGold, resumeCallback)
    if activeStates.autoFarmMaterials then
        activeStates.autoFarmMaterials = false
        activeStates._materialFarmToken = (tonumber(activeStates._materialFarmToken) or 0) + 1
        activeStates._materialFarmBusy = false
    end

    if activeStates._buildFarmBusy then
        toast("Ya se está farmeando oro para una construcción.")
        return
    end

    activeStates._buildFarmBusy = true
    activeStates._buildFarmTarget = math.max(0, math.floor(tonumber(targetGold) or 0))
    activeStates._buildFarmToken = (tonumber(activeStates._buildFarmToken) or 0) + 1
    local token = activeStates._buildFarmToken

    closeModal()
    toast("Farmeando oro para completar la construcción...")

    task.spawn(function()
        local failures = 0

        while alive
            and activeStates._buildFarmBusy
            and activeStates._buildFarmToken == token
            and (tonumber(getGoldValue()) or 0) < activeStates._buildFarmTarget do

            local beforeGold = tonumber(getGoldValue()) or 0
            local ok, msg = finishRun(0.40)

            if ok then
                failures = 0

                -- Espera a que el juego entregue el oro/resetee la ronda.
                local waited = 0
                while waited < 7
                    and alive
                    and activeStates._buildFarmBusy
                    and activeStates._buildFarmToken == token
                    and (tonumber(getGoldValue()) or 0) < activeStates._buildFarmTarget do

                    task.wait(0.5)
                    waited += 0.5

                    if (tonumber(getGoldValue()) or 0) > beforeGold and waited >= 2 then
                        break
                    end
                end

                task.wait(1.0)
            else
                failures += 1
                if msg and msg ~= "Ya hay una finalización en curso" then
                    toast(msg)
                end

                if failures >= 8 then break end
                task.wait(2.0)
            end
        end

        local reachedTarget = alive
            and activeStates._buildFarmToken == token
            and (tonumber(getGoldValue()) or 0) >= (activeStates._buildFarmTarget or 0)

        activeStates._buildFarmBusy = false
        activeStates._buildFarmTarget = nil

        if reachedTarget then
            toast("Oro suficiente. Comprando automáticamente los recursos faltantes...")
            task.wait(0.35)
            if resumeCallback then task.spawn(resumeCallback) end
        elseif alive and activeStates._buildFarmToken == token then
            toast("No pude conseguir suficiente oro para continuar automáticamente.")
        end
    end)
end

actionButton(pages.AutoBuild, "Auto Crear Barco", "Crea automáticamente uno de tres barcos usando tus bloques disponibles.", function()
    openModal("Selecciona un barco", function()
        local function buildPreset(level, purchaseChoice)
            if activeStates.autoBuildBoatBusy then
                toast("Ya se está creando un barco.")
                return
            end
            if activeStates.autoFarm or activeStates._finishBusy then
                toast("Desactiva Auto Farm antes de crear un barco.")
                return
            end

            local data = LP:FindFirstChild("Data")
            if not data then
                toast("No encontré los datos de bloques del jugador.")
                return
            end

            -- Only structural materials are counted toward the hull.
            local structureNames = {
                "WoodBlock", "SmoothWoodBlock", "StoneBlock", "RustedBlock",
                "MetalBlock", "IronBlock", "SteelBlock", "ConcreteBlock",
                "BrickBlock", "MarbleBlock", "CoalBlock", "TitaniumBlock",
                "ObsidianBlock", "PlasticBlock", "GlassBlock", "SandBlock"
            }

            local function stock(name)
                local obj = data:FindFirstChild(name)
                return obj and tonumber(obj.Value) or 0
            end

            local function structuralStock()
                local total = 0
                for _, name in ipairs(structureNames) do
                    total += math.max(0, math.floor(stock(name)))
                end
                return total
            end

            local selectedTarget = level == "advanced" and 150 or (level == "intermediate" and 82 or 42)
            local missingHull = math.max(selectedTarget - structuralStock(), 0)
            local missingDrive = stock("BoatMotor") <= 0 or stock("CarSeat") <= 0
            local gold = tonumber(getGoldValue()) or 0

            -- Material packs contain 50 blocks. Use one predictable material
            -- pack per preset so the required Gold can be calculated before asking.
            local materialPackPrice = level == "advanced" and 400 or (level == "intermediate" and 325 or 250)
            local materialPacksNeeded = math.ceil(missingHull / 50)
            local requiredGold = (materialPacksNeeded * materialPackPrice) + (missingDrive and 450 or 0)

            if purchaseChoice == nil and (missingHull > 0 or missingDrive) then
                if gold >= requiredGold then
                    -- The player can already afford EVERYTHING missing:
                    -- ask only whether they want HX Boat to buy it.
                    openModal("Recursos insuficientes", function()
                        local info
                        if ENV.__HX_LANG == "en" then
                            info = string.format(
                                "Missing hull blocks: %d · Gold: %d / %d%s",
                                missingHull,
                                gold,
                                requiredGold,
                                missingDrive and " · Boat Motor/Car Seat missing" or ""
                            )
                        else
                            info = string.format(
                                "Bloques de casco faltantes: %d · Oro: %d / %d%s",
                                missingHull,
                                gold,
                                requiredGold,
                                missingDrive and " · Falta Boat Motor/Car Seat" or ""
                            )
                        end

                        modalButton(
                            "SÍ, COMPRAR Y CONTINUAR",
                            info .. "\n" .. ENV.__HX_TR("HX Boat comprará únicamente con el oro del juego y continuará automáticamente."),
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, true)
                            end
                        )

                        modalButton(
                            "NO, CONTINUAR SIN COMPRAR",
                            "Continuar con los materiales actuales; el barco puede reducirse.",
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, false)
                            end
                        )
                    end)
                else
                    -- Only here do we offer farming: current Gold does NOT cover
                    -- the full estimated purchase.
                    openModal("Farmear para completar", function()
                        local info
                        if ENV.__HX_LANG == "en" then
                            info = string.format(
                                "Current Gold: %d · Needed: %d · Missing Gold: %d",
                                gold,
                                requiredGold,
                                math.max(requiredGold - gold, 0)
                            )
                        else
                            info = string.format(
                                "Oro actual: %d · Necesario: %d · Oro faltante: %d",
                                gold,
                                requiredGold,
                                math.max(requiredGold - gold, 0)
                            )
                        end

                        modalButton(
                            "FARMEAR Y COMPRAR",
                            info .. "\n" .. ENV.__HX_TR("Te faltan recursos y tu oro actual no alcanza para comprarlos. HX Boat puede farmear hasta conseguir el oro necesario, comprar automáticamente lo faltante y continuar."),
                            function()
                                closeModal()
                                activeStates._farmGoldForBuild(requiredGold, function()
                                    buildPreset(level, true)
                                end)
                            end
                        )

                        modalButton(
                            "CONTINUAR SIN FARMEAR",
                            "Continuar con los materiales actuales; el barco puede reducirse.",
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, false)
                            end
                        )
                    end)
                end
                return
            end

            activeStates.autoBuildBoatBusy = true
            closeModal()
            toast("Creando nuevo barco. El resultado dependerá de los materiales y de la cantidad que tengas de cada uno.")
            task.wait(0.20)

            local okBuild, errBuild = pcall(function()
                local char = getChar()
                local hum = getHum()
                local root = getRoot()
                if not char or not hum or not root then error("Personaje no disponible") end

                local tool = char:FindFirstChild("BuildingTool")
                if not tool then
                    local backpack = LP:FindFirstChildOfClass("Backpack")
                    local backpackTool = backpack and backpack:FindFirstChild("BuildingTool")
                    if backpackTool then
                        hum:EquipTool(backpackTool)
                        task.wait(0.18)
                        tool = char:FindFirstChild("BuildingTool") or backpackTool
                    end
                end
                if not tool then
                    local playerBuild = Workspace:FindFirstChild(LP.Name)
                    tool = playerBuild and playerBuild:FindFirstChild("BuildingTool")
                end

                local rf = tool and tool:FindFirstChild("RF", true)
                if not rf or not rf:IsA("RemoteFunction") then
                    error(ENV.__HX_TR("No encontré BuildingTool. Abre el modo de construcción e inténtalo otra vez."))
                end

                data = LP:FindFirstChild("Data")
                if not data then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local function liveStock(name)
                    local obj = data:FindFirstChild(name)
                    return obj and tonumber(obj.Value) or 0
                end

                local function liveStructuralStock()
                    local total = 0
                    for _, name in ipairs(structureNames) do
                        total += math.max(0, math.floor(liveStock(name)))
                    end
                    return total
                end

                ----------------------------------------------------------------
                -- OPTIONAL PURCHASE FLOW
                -- Uses the game's own shop event; the server still validates
                -- the product and deducts the player's normal in-game Gold.
                ----------------------------------------------------------------
                if purchaseChoice == true then
                    local shopRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
                    local boughtAnything = false

                    local function buyProduct(productName, price, watchNames)
                        if not shopRemote or not shopRemote:IsA("RemoteEvent") then return false end
                        local currentGold = tonumber(getGoldValue()) or 0
                        if currentGold < price then return false end

                        local before = 0
                        for _, n in ipairs(watchNames) do before += liveStock(n) end

                        local ok = pcall(function()
                            shopRemote:FireServer(productName)
                        end)
                        if not ok then return false end

                        task.wait(0.50)

                        local after = 0
                        for _, n in ipairs(watchNames) do after += liveStock(n) end
                        local newGold = tonumber(getGoldValue()) or currentGold
                        return after > before or newGold < currentGold
                    end

                    if liveStock("BoatMotor") <= 0 or liveStock("CarSeat") <= 0 then
                        if buyProduct("Boat Motor", 450, {"BoatMotor", "CarSeat"}) then
                            boughtAnything = true
                        end
                    end

                    local target = level == "advanced" and 150 or (level == "intermediate" and 82 or 42)
                    local productName = level == "advanced" and "Titanium Block"
                        or (level == "intermediate" and "Metal Block" or "Wood Block")
                    local internalName = level == "advanced" and "TitaniumBlock"
                        or (level == "intermediate" and "MetalBlock" or "WoodBlock")
                    local packPrice = level == "advanced" and 400
                        or (level == "intermediate" and 325 or 250)

                    local packsNeeded = math.ceil(math.max(target - liveStructuralStock(), 0) / 50)
                    for _ = 1, packsNeeded do
                        if not buyProduct(productName, packPrice, {internalName}) then break end
                        boughtAnything = true
                    end

                    if boughtAnything then
                        toast("Compra automática completada. Continuando construcción...")
                    else
                        toast("No pude completar una compra automática; continuaré con los recursos disponibles.")
                    end
                    task.wait(0.15)
                end

                ----------------------------------------------------------------
                -- BUILD ZONE + ORIGIN
                ----------------------------------------------------------------
                local zone
                for _, v in ipairs(Workspace:GetChildren()) do
                    local teamValue = v:FindFirstChild("TeamColor")
                    if teamValue then
                        local okTeam, value = pcall(function() return teamValue.Value end)
                        if okTeam and value == LP.TeamColor then
                            zone = v
                            break
                        end
                    end
                end
                if not zone then zone = getTeamSpawn() end

                local zonePart = zone and (zone:IsA("BasePart") and zone or findFirstPart(zone))
                if not zonePart then
                    error(ENV.__HX_TR("No pude detectar tu zona de construcción."))
                end

                local totalAvailable = liveStructuralStock()
                local buildLevel = level
                if level == "advanced" and totalAvailable < 150 then
                    buildLevel = totalAvailable >= 82 and "intermediate" or "basic"
                    toast("No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.")
                elseif level == "intermediate" and totalAvailable < 82 then
                    buildLevel = "basic"
                    toast("No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.")
                end

                if totalAvailable < 15 then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local localRoot = zonePart.CFrame:PointToObjectSpace(root.Position)
                local margin = buildLevel == "advanced" and 9 or (buildLevel == "intermediate" and 7 or 5)
                local halfX = math.max((zonePart.Size.X * 0.5) - margin, 0)
                local halfZ = math.max((zonePart.Size.Z * 0.5) - margin, 0)
                local clampedX = math.clamp(localRoot.X, -halfX, halfX)
                local clampedZ = math.clamp(localRoot.Z, -halfZ, halfZ)
                local topLocal = Vector3.new(clampedX, (zonePart.Size.Y * 0.5) + 1.5, clampedZ)
                local basePosition = zonePart.CFrame:PointToWorldSpace(topLocal)

                local look = root.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
                flatLook = flatLook.Unit
                local origin = CFrame.lookAt(basePosition, basePosition + flatLook)

                ----------------------------------------------------------------
                -- INVENTORY + MATERIAL SELECTION
                ----------------------------------------------------------------
                local remaining = {}
                for _, name in ipairs(structureNames) do
                    local n = liveStock(name)
                    if n > 0 then remaining[name] = math.floor(n) end
                end
                for _, name in ipairs({
                    "BoatMotor", "WinterBoatMotor", "UltraBoatMotor",
                    "CarSeat", "PilotSeat", "Seat"
                }) do
                    local n = liveStock(name)
                    if n > 0 then remaining[name] = math.floor(n) end
                end

                local function countOf(name)
                    return remaining[name] or 0
                end

                local function reserve(name, amount)
                    amount = amount or 1
                    if countOf(name) < amount then return false end
                    remaining[name] = countOf(name) - amount
                    return true
                end

                local materialPriority
                if buildLevel == "basic" then
                    materialPriority = {
                        "WoodBlock", "SmoothWoodBlock", "StoneBlock", "RustedBlock",
                        "PlasticBlock", "MetalBlock", "IronBlock", "SteelBlock",
                        "ConcreteBlock", "TitaniumBlock", "ObsidianBlock"
                    }
                elseif buildLevel == "intermediate" then
                    materialPriority = {
                        "MetalBlock", "IronBlock", "SteelBlock", "StoneBlock",
                        "ConcreteBlock", "BrickBlock", "MarbleBlock", "WoodBlock",
                        "SmoothWoodBlock", "TitaniumBlock", "ObsidianBlock"
                    }
                else
                    materialPriority = {
                        "TitaniumBlock", "ObsidianBlock", "MetalBlock", "SteelBlock",
                        "IronBlock", "ConcreteBlock", "MarbleBlock", "BrickBlock",
                        "StoneBlock", "WoodBlock", "SmoothWoodBlock"
                    }
                end

                local function bestMaterial()
                    local best, bestCount
                    for _, name in ipairs(materialPriority) do
                        local n = countOf(name)
                        if n > 0 and (not bestCount or n > bestCount) then
                            best, bestCount = name, n
                        end
                    end
                    return best
                end

                local primaryMaterial = bestMaterial()
                if not primaryMaterial then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local points = {}
                local function add(x, y, z, role)
                    points[#points + 1] = {x = x, y = y, z = z, role = role or "hull"}
                end

                ----------------------------------------------------------------
                -- BOAT SHAPES
                --
                -- The hull is intentionally designed from bow to stern:
                -- narrow pointed bow (-Z), wider center section, flat stern (+Z),
                -- raised gunwales, a clear cockpit and dedicated motor mounts.
                ----------------------------------------------------------------
                if buildLevel == "basic" then
                    -- BASIC: compact 3-wide speedboat.
                    -- Lower hull: pointed bow gradually opens into a full-width body.
                    for z = -4, 3 do
                        local width = z == -4 and 0 or 1
                        for x = -width, width do
                            add(x, 0, z, "hull")
                        end
                    end

                    -- Raised bow cap so the front reads as an actual prow.
                    add(0, 1, -4, "armor")
                    add(-1, 1, -3, "armor")
                    add(0, 1, -3, "armor")
                    add(1, 1, -3, "armor")

                    -- Side gunwales, leaving the cockpit open in the middle.
                    for z = -2, 2 do
                        add(-1, 1, z, "armor")
                        add(1, 1, z, "armor")
                    end

                    -- Flat stern/transom plus a dedicated central motor mount.
                    add(-1, 1, 3, "armor")
                    add(0, 1, 3, "armor")
                    add(1, 1, 3, "armor")

                    -- Small foredeck in front of the driver.
                    add(-1, 1, -2, "hull")
                    add(0, 1, -2, "hull")
                    add(1, 1, -2, "hull")

                elseif buildLevel == "intermediate" then
                    -- INTERMEDIATE: 5-wide reinforced speedboat with V-like bow.
                    for z = -5, 4 do
                        local width
                        if z == -5 then
                            width = 0
                        elseif z == -4 then
                            width = 1
                        else
                            width = 2
                        end
                        for x = -width, width do
                            add(x, 0, z, "hull")
                        end
                    end

                    -- Raised center deck ahead/behind the cockpit, but leave
                    -- the driver's pedestal position completely free.
                    for _, z in ipairs({-3, -2, 2, 3}) do
                        add(0, 1, z, "hull")
                    end

                    -- Bow deck follows the widening hull instead of forming a box.
                    add(0, 1, -5, "armor")
                    for x = -1, 1 do add(x, 1, -4, "armor") end
                    for x = -2, 2 do add(x, 1, -3, "armor") end

                    -- Side rails from the bow shoulders to the stern.
                    for z = -2, 4 do
                        add(-2, 1, z, "armor")
                        add(2, 1, z, "armor")
                    end

                    -- Rear deck / transom with a dedicated central engine mount.
                    for x = -2, 2 do
                        add(x, 1, 4, "armor")
                    end

                    -- Cockpit floor around an open center seat position.
                    add(-1, 1, 0, "hull")
                    add(1, 1, 0, "hull")
                    add(-1, 1, 1, "hull")
                    add(1, 1, 1, "hull")

                    -- Windshield frame one grid step in front of the driver.
                    add(-1, 2, -1, "glass")
                    add(0, 2, -1, "glass")
                    add(1, 2, -1, "glass")

                else
                    -- ADVANCED: 7-wide cruiser-style hull with stepped bow.
                    for z = -6, 5 do
                        local width
                        if z == -6 then
                            width = 0
                        elseif z == -5 then
                            width = 1
                        elseif z == -4 then
                            width = 2
                        else
                            width = 3
                        end
                        for x = -width, width do
                            add(x, 0, z, "hull")
                        end
                    end

                    -- Raised center deck with an open cockpit in the middle.
                    for _, z in ipairs({-4, -3, -2, 2, 3, 4}) do
                        add(0, 1, z, "hull")
                    end

                    -- Stepped prow: each layer follows the actual bow width.
                    add(0, 1, -6, "armor")
                    for x = -1, 1 do add(x, 1, -5, "armor") end
                    for x = -2, 2 do add(x, 1, -4, "armor") end
                    for x = -2, 2 do add(x, 2, -4, "armor") end

                    -- Full side gunwales.
                    for z = -3, 5 do
                        add(-3, 1, z, "armor")
                        add(3, 1, z, "armor")
                    end

                    -- Interior deck strips; center stays open around the driver.
                    for z = -2, 3 do
                        add(-2, 1, z, "hull")
                        add(2, 1, z, "hull")
                    end

                    -- Rear transom with two dedicated motor mounting pads.
                    for x = -3, 3 do
                        add(x, 1, 5, "armor")
                    end

                    -- Open cabin behind the driver.
                    for z = 1, 3 do
                        add(-2, 2, z, "armor")
                        add(2, 2, z, "armor")
                    end
                    for x = -2, 2 do
                        add(x, 2, 3, "armor")
                    end

                    -- Windshield across the front of the cabin.
                    for x = -2, 2 do
                        add(x, 2, -1, "glass")
                    end

                    -- Raised roof only over the rear cabin, never over the seat.
                    for x = -2, 2 do
                        add(x, 3, 2, "armor")
                        add(x, 3, 3, "armor")
                    end
                end

                ----------------------------------------------------------------
                -- PLACEMENT
                ----------------------------------------------------------------
                local placed = 0
                local usedMaterials = {}
                local delayPerBlock = ENV.__HX_DEVICE == "mobile" and 0.080 or 0.055

                local function materialForRole(role)
                    if role == "glass" then
                        if countOf("GlassBlock") > 0 then return "GlassBlock" end
                        if countOf(primaryMaterial) > 0 then return primaryMaterial end
                    end

                    if role == "armor" then
                        local armorPriority = buildLevel == "advanced"
                            and {"ObsidianBlock", "TitaniumBlock", "MetalBlock", "SteelBlock", "IronBlock", "ConcreteBlock", "StoneBlock", "WoodBlock"}
                            or {"MetalBlock", "SteelBlock", "IronBlock", "ConcreteBlock", "StoneBlock", "WoodBlock", "SmoothWoodBlock"}
                        for _, name in ipairs(armorPriority) do
                            if countOf(name) > 0 then return name end
                        end
                    end
                    if countOf(primaryMaterial) > 0 then return primaryMaterial end
                    return bestMaterial()
                end

                local function placeNamed(blockName, worldCF)
                    if not blockName or countOf(blockName) <= 0 then return false end
                    local idObject = data:FindFirstChild(blockName)
                    if not idObject then return false end

                    local before = tonumber(idObject.Value) or 0
                    if before <= 0 then return false end

                    local relativeCF = zonePart.CFrame:ToObjectSpace(worldCF)
                    local okPlace = pcall(function()
                        rf:InvokeServer(
                            blockName,
                            before,
                            zonePart,
                            relativeCF,
                            true,
                            worldCF,
                            false
                        )
                    end)

                    if not okPlace then return false end
                    task.wait(0.025)

                    local after = tonumber(idObject.Value) or before
                    -- Most executors/game versions update Data immediately.
                    -- Even if replication is delayed, reserve locally once RF returned.
                    reserve(blockName, 1)
                    usedMaterials[blockName] = (usedMaterials[blockName] or 0) + 1
                    placed += 1
                    return true
                end

                if buildLevel == "basic" then
                    toast("Creando barco básico...")
                elseif buildLevel == "intermediate" then
                    toast("Creando barco intermedio...")
                else
                    toast("Creando barco avanzado...")
                end

                for i, item in ipairs(points) do
                    if not alive then error("Cerrado") end
                    local material = materialForRole(item.role)
                    if not material then break end

                    local worldCF = origin * CFrame.new(item.x * 2, item.y * 2, item.z * 2)
                    placeNamed(material, worldCF)

                    if i % 12 == 0 then
                        task.wait(delayPerBlock * 2)
                    else
                        task.wait(delayPerBlock)
                    end
                end

                ----------------------------------------------------------------
                -- DRIVING SYSTEM FIX
                --
                -- Important order:
                -- 1. Boat Motor(s) mounted directly on the stern structure
                -- 2. Car Seat LAST
                --
                -- The motor must belong to the same physical assembly as the hull.
                -- The Car Seat is then placed last so it can bind to the mounted
                -- motors without leaving a controllable loose motor behind.
                ----------------------------------------------------------------
                local function firstOwned(candidates)
                    for _, name in ipairs(candidates) do
                        if countOf(name) > 0 and data:FindFirstChild(name) then
                            return name
                        end
                    end
                    return nil
                end

                local motorName = firstOwned({"UltraBoatMotor", "WinterBoatMotor", "BoatMotor"})
                local driverSeatName = firstOwned({"CarSeat"})

                local desiredMotors = buildLevel == "advanced" and 2 or 1
                local motorCount = motorName and math.min(desiredMotors, countOf(motorName)) or 0

                if motorName and motorCount > 0 then
                    -- IMPORTANT: motors are mounted ON the stern structure, not
                    -- behind it. In the previous build there was a small physical
                    -- gap: the Car Seat could control the motor, but the motor was
                    -- not part of the hull assembly and detached after launch.
                    --
                    -- These coordinates intentionally sink the motor base slightly
                    -- into the stern mounting block so BABFT creates one connected
                    -- physical assembly when the block is placed.
                    local motorZGrid = buildLevel == "basic" and 3 or (buildLevel == "intermediate" and 4 or 5)
                    local motorHeight = 4.5

                    for n = 1, motorCount do
                        local xGrid = 0
                        if motorCount == 2 then
                            xGrid = n == 1 and -2 or 2
                        end

                        local motorCF = origin * CFrame.new(
                            xGrid * 2,
                            motorHeight,
                            motorZGrid * 2
                        )

                        placeNamed(motorName, motorCF)

                        -- Give the server time to create the physical connection
                        -- before another ability block is added.
                        task.wait(0.32)
                    end

                    -- Let every motor finish replicating before the Car Seat is
                    -- placed and performs its automatic binding pass.
                    task.wait(0.38)
                end

                -- Place the controller only AFTER the motors so it can bind to them.
                -- The cockpit is intentionally elevated above the hull. A structural
                -- pedestal is placed first, then the seat is placed one full grid
                -- level above it so the seat cannot be embedded between hull blocks.
                if driverSeatName and countOf(driverSeatName) > 0 then
                    -- Driver sits near the center of mass, facing the bow.
                    -- The cockpit is never filled by hull generation.
                    local cockpitZ = buildLevel == "basic" and 0 or (buildLevel == "intermediate" and 0 or 0)
                    local pedestalMaterial = materialForRole("hull")

                    if pedestalMaterial then
                        local pedestalCF = origin * CFrame.new(0, 2, cockpitZ * 2)
                        placeNamed(pedestalMaterial, pedestalCF)
                        task.wait(0.10)
                    end

                    local seatCF = origin * CFrame.new(0, 5.5, cockpitZ * 2)
                    placeNamed(driverSeatName, seatCF)
                    task.wait(0.90)
                end

                if motorCount > 0 and driverSeatName then
                    toast("Sistema de conducción añadido: Boat Motor + Car Seat.")
                else
                    -- A normal Seat can still be added for sitting, but it is not
                    -- treated as a steering controller.
                    if countOf("Seat") > 0 then
                        local seatCF = origin * CFrame.new(0, 2, 0)
                        placeNamed("Seat", seatCF)
                    end
                    toast("No hay Boat Motor o Car Seat disponible; el barco no tendrá conducción normal.")
                end

                ----------------------------------------------------------------
                -- Refresh seat/boat caches.
                ----------------------------------------------------------------
                worldCache.boatRoot = nil
                worldCache.nearestSeat = nil
                worldCache.boatRootAt = 0
                worldCache.seatAt = 0

                if placed <= 0 then
                    error("BuildingTool rechazó las colocaciones")
                end

                toast(
                    ENV.__HX_TR("Material principal: ")
                    .. tostring(primaryMaterial)
                    .. ENV.__HX_TR(" · Bloques disponibles usados: ")
                    .. tostring(placed)
                )
            end)

            activeStates.autoBuildBoatBusy = false

            if okBuild then
                toast("Barco creado correctamente.")
            else
                toast(ENV.__HX_TR("No se pudo completar el barco: ") .. tostring(errBuild))
            end
        end

        modalButton("Básico", "Lancha compacta con proa definida, casco cerrado, laterales, asiento elevado y motor trasero.", function()
            buildPreset("basic")
        end)

        modalButton("Intermedio", "Lancha reforzada con proa en V, cubierta, cockpit abierto, parabrisas y motor trasero.", function()
            buildPreset("intermediate")
        end)

        modalButton("Avanzado", "Barco grande con proa escalonada, cubierta completa, cabina abierta, parabrisas y doble motor.", function()
            buildPreset("advanced")
        end)
    end)
end, "CONSTRUIR")

-- Shared filtered builder for CAR and PLANE.
-- It intentionally uses the same safeguards as Auto Crear Barco:
-- inventory checks, Gold purchase confirmation, preset downgrade,
-- nearest valid build position and one-build-at-a-time locking.
activeStates._openAutoVehicle = function(kind)
    local isCar = kind == "car"
    openModal(isCar and "Selecciona un carro" or "Selecciona un avión", function()
        local function buildPreset(level, purchaseChoice)
            if activeStates.autoBuildBoatBusy then
                toast("Ya se está creando un vehículo.")
                return
            end
            if activeStates.autoFarm or activeStates._finishBusy then
                toast("Desactiva Auto Farm antes de crear un vehículo.")
                return
            end

            local data = LP:FindFirstChild("Data")
            if not data then
                toast("No encontré los datos de bloques del jugador.")
                return
            end

            local structureNames = {
                "WoodBlock", "SmoothWoodBlock", "StoneBlock", "RustedBlock",
                "MetalBlock", "IronBlock", "SteelBlock", "ConcreteBlock",
                "BrickBlock", "MarbleBlock", "CoalBlock", "TitaniumBlock",
                "ObsidianBlock", "PlasticBlock", "GlassBlock", "SandBlock"
            }

            local wheelCandidates = {
                "Wheel", "SmallWheel", "CarWheel", "FrontWheel", "BackWheel"
            }
            local planePropulsionCandidates = {
                "JetTurbine", "Jet", "UltraThruster", "Thruster", "Rocket"
            }

            local function stock(name)
                local obj = data:FindFirstChild(name)
                return obj and tonumber(obj.Value) or 0
            end

            local function structuralStock()
                local total = 0
                for _, name in ipairs(structureNames) do
                    total += math.max(0, math.floor(stock(name)))
                end
                return total
            end

            local function bestOwned(candidates)
                local best, bestCount
                for _, name in ipairs(candidates) do
                    local amount = stock(name)
                    if amount > 0 and (not bestCount or amount > bestCount) then
                        best, bestCount = name, amount
                    end
                end
                return best, bestCount or 0
            end

            local target
            if isCar then
                target = level == "advanced" and 118 or (level == "intermediate" and 76 or 40)
            else
                target = level == "advanced" and 142 or (level == "intermediate" and 88 or 48)
            end

            local missingStructure = math.max(target - structuralStock(), 0)
            local componentMissing
            local componentPacksNeeded = 0

            if isCar then
                local wheelStock = 0
                for _, wheelName in ipairs(wheelCandidates) do
                    wheelStock += math.max(0, math.floor(stock(wheelName)))
                end

                local neededWheels = level == "advanced" and 6 or 4
                local missingWheels = math.max(neededWheels - wheelStock, 0)
                local seatMissing = stock("CarSeat") <= 0

                -- New Car Pack = Car Seat + 4 wheels.
                componentPacksNeeded = math.max(
                    math.ceil(missingWheels / 4),
                    seatMissing and 1 or 0
                )
                componentMissing = componentPacksNeeded > 0
            else
                local propulsionStock = 0
                for _, propulsionName in ipairs(planePropulsionCandidates) do
                    propulsionStock += math.max(0, math.floor(stock(propulsionName)))
                end

                local neededPropulsion = level == "advanced" and 3 or (level == "intermediate" and 2 or 1)
                local seatMissing = stock("PilotSeat") <= 0
                local propulsionMissing = propulsionStock < neededPropulsion

                -- Plane Blocks contains 3 Jet Turbines + Pilot Seat.
                componentPacksNeeded = (seatMissing or propulsionMissing) and 1 or 0
                componentMissing = componentPacksNeeded > 0
            end

            local gold = tonumber(getGoldValue()) or 0
            local materialPackPrice = level == "advanced" and 400 or (level == "intermediate" and 325 or 250)
            local materialPacksNeeded = math.ceil(missingStructure / 50)
            local componentGold = isCar and (componentPacksNeeded * 750) or (componentPacksNeeded * 4000)
            local requiredGold = (materialPacksNeeded * materialPackPrice) + componentGold

            if purchaseChoice == nil and (missingStructure > 0 or componentMissing) then
                if gold >= requiredGold then
                    -- Enough Gold for the complete missing set -> ask to purchase.
                    openModal("Recursos insuficientes", function()
                        local info
                        if ENV.__HX_LANG == "en" then
                            info = string.format(
                                "Missing structural blocks: %d · Gold: %d / %d%s",
                                missingStructure,
                                gold,
                                requiredGold,
                                componentMissing and " · Vehicle components missing" or ""
                            )
                        else
                            info = string.format(
                                "Bloques estructurales faltantes: %d · Oro: %d / %d%s",
                                missingStructure,
                                gold,
                                requiredGold,
                                componentMissing and " · Faltan componentes del vehículo" or ""
                            )
                        end

                        modalButton(
                            "SÍ, COMPRAR Y CONTINUAR",
                            info .. "\n" .. ENV.__HX_TR("HX Boat comprará únicamente con el oro del juego y continuará automáticamente."),
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, true)
                            end
                        )

                        modalButton(
                            "NO, CONTINUAR SIN COMPRAR",
                            "Continuar con los materiales actuales; el vehículo puede reducirse.",
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, false)
                            end
                        )
                    end)
                else
                    -- Not enough Gold for the full missing set -> and ONLY then
                    -- offer temporary farming.
                    openModal("Farmear para completar", function()
                        local info
                        if ENV.__HX_LANG == "en" then
                            info = string.format(
                                "Current Gold: %d · Needed: %d · Missing Gold: %d",
                                gold,
                                requiredGold,
                                math.max(requiredGold - gold, 0)
                            )
                        else
                            info = string.format(
                                "Oro actual: %d · Necesario: %d · Oro faltante: %d",
                                gold,
                                requiredGold,
                                math.max(requiredGold - gold, 0)
                            )
                        end

                        modalButton(
                            "FARMEAR Y COMPRAR",
                            info .. "\n" .. ENV.__HX_TR("Te faltan recursos y tu oro actual no alcanza para comprarlos. HX Boat puede farmear hasta conseguir el oro necesario, comprar automáticamente lo faltante y continuar."),
                            function()
                                closeModal()
                                activeStates._farmGoldForBuild(requiredGold, function()
                                    buildPreset(level, true)
                                end)
                            end
                        )

                        modalButton(
                            "CONTINUAR SIN FARMEAR",
                            "Continuar con los materiales actuales; el vehículo puede reducirse.",
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, false)
                            end
                        )
                    end)
                end
                return
            end

            activeStates.autoBuildBoatBusy = true
            closeModal()

            if isCar then
                toast("Creando nuevo carro. El resultado dependerá de los materiales y componentes que tengas.")
            else
                toast("Creando nuevo avión. El resultado dependerá de los materiales y componentes que tengas.")
            end
            task.wait(0.20)

            local okBuild, errBuild = pcall(function()
                local char = getChar()
                local hum = getHum()
                local root = getRoot()
                if not char or not hum or not root then error("Personaje no disponible") end

                local tool = char:FindFirstChild("BuildingTool")
                if not tool then
                    local backpack = LP:FindFirstChildOfClass("Backpack")
                    local backpackTool = backpack and backpack:FindFirstChild("BuildingTool")
                    if backpackTool then
                        hum:EquipTool(backpackTool)
                        task.wait(0.18)
                        tool = char:FindFirstChild("BuildingTool") or backpackTool
                    end
                end
                if not tool then
                    local playerBuild = Workspace:FindFirstChild(LP.Name)
                    tool = playerBuild and playerBuild:FindFirstChild("BuildingTool")
                end

                local rf = tool and tool:FindFirstChild("RF", true)
                if not rf or not rf:IsA("RemoteFunction") then
                    error(ENV.__HX_TR("No encontré BuildingTool. Abre el modo de construcción e inténtalo otra vez."))
                end

                data = LP:FindFirstChild("Data")
                if not data then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local function liveStock(name)
                    local obj = data:FindFirstChild(name)
                    return obj and tonumber(obj.Value) or 0
                end

                local function liveStructuralStock()
                    local total = 0
                    for _, name in ipairs(structureNames) do
                        total += math.max(0, math.floor(liveStock(name)))
                    end
                    return total
                end

                local function bestLive(candidates)
                    local best, bestCount
                    for _, name in ipairs(candidates) do
                        local amount = liveStock(name)
                        if amount > 0 and (not bestCount or amount > bestCount) then
                            best, bestCount = name, amount
                        end
                    end
                    return best, bestCount or 0
                end

                ------------------------------------------------------------
                -- OPTIONAL SHOP PURCHASES
                ------------------------------------------------------------
                if purchaseChoice == true then
                    local shopRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
                    local boughtAnything = false

                    local function buyProduct(productName, watchNames, minimumGold)
                        if not shopRemote or not shopRemote:IsA("RemoteEvent") then return false end
                        local beforeGold = tonumber(getGoldValue()) or 0
                        if beforeGold < (minimumGold or 0) then return false end

                        local before = 0
                        for _, n in ipairs(watchNames) do before += liveStock(n) end

                        local ok = pcall(function()
                            shopRemote:FireServer(productName)
                        end)
                        if not ok then return false end

                        task.wait(0.50)

                        local after = 0
                        for _, n in ipairs(watchNames) do after += liveStock(n) end
                        local afterGold = tonumber(getGoldValue()) or beforeGold
                        return after > before or afterGold < beforeGold
                    end

                    local targetNow
                    if isCar then
                        targetNow = level == "advanced" and 118 or (level == "intermediate" and 76 or 40)
                    else
                        targetNow = level == "advanced" and 142 or (level == "intermediate" and 88 or 48)
                    end

                    -- Materials: predictable 50-block package per preset.
                    local productName = level == "advanced" and "Titanium Block"
                        or (level == "intermediate" and "Metal Block" or "Wood Block")
                    local internalName = level == "advanced" and "TitaniumBlock"
                        or (level == "intermediate" and "MetalBlock" or "WoodBlock")
                    local packPrice = level == "advanced" and 400
                        or (level == "intermediate" and 325 or 250)

                    local materialPacks = math.ceil(math.max(targetNow - liveStructuralStock(), 0) / 50)
                    for _ = 1, materialPacks do
                        if not buyProduct(productName, {internalName}, packPrice) then break end
                        boughtAnything = true
                    end

                    if isCar then
                        local function liveWheelTotal()
                            local total = 0
                            for _, name in ipairs(wheelCandidates) do
                                total += math.max(0, math.floor(liveStock(name)))
                            end
                            return total
                        end

                        local wanted = level == "advanced" and 6 or 4
                        local missingWheels = math.max(wanted - liveWheelTotal(), 0)
                        local carPacks = math.max(
                            math.ceil(missingWheels / 4),
                            liveStock("CarSeat") <= 0 and 1 or 0
                        )

                        for _ = 1, carPacks do
                            if not buyProduct(
                                "New Car Pack",
                                {"CarSeat", "FrontWheel", "BackWheel", "Wheel", "SmallWheel", "CarWheel"},
                                750
                            ) then
                                break
                            end
                            boughtAnything = true
                        end
                    else
                        local propulsionTotal = 0
                        for _, name in ipairs(planePropulsionCandidates) do
                            propulsionTotal += math.max(0, math.floor(liveStock(name)))
                        end

                        local wanted = level == "advanced" and 3 or (level == "intermediate" and 2 or 1)
                        if liveStock("PilotSeat") <= 0 or propulsionTotal < wanted then
                            if buyProduct(
                                "Plane Blocks",
                                {"PilotSeat", "JetTurbine", "Jet", "UltraThruster", "Thruster", "Rocket"},
                                4000
                            ) then
                                boughtAnything = true
                            end
                        end
                    end

                    if boughtAnything then
                        toast("Compra automática completada. Continuando construcción...")
                    else
                        toast("No pude completar una compra automática; continuaré con los recursos disponibles.")
                    end
                    task.wait(0.15)
                end

                ------------------------------------------------------------
                -- BUILD ZONE + NEAREST POSITION
                ------------------------------------------------------------
                local zone
                for _, v in ipairs(Workspace:GetChildren()) do
                    local teamValue = v:FindFirstChild("TeamColor")
                    if teamValue then
                        local okTeam, value = pcall(function() return teamValue.Value end)
                        if okTeam and value == LP.TeamColor then
                            zone = v
                            break
                        end
                    end
                end
                if not zone then zone = getTeamSpawn() end

                local zonePart = zone and (zone:IsA("BasePart") and zone or findFirstPart(zone))
                if not zonePart then
                    error(ENV.__HX_TR("No pude detectar tu zona de construcción."))
                end

                local totalAvailable = liveStructuralStock()
                local buildLevel = level
                local advancedTarget = isCar and 118 or 142
                local intermediateTarget = isCar and 76 or 88

                if level == "advanced" and totalAvailable < advancedTarget then
                    buildLevel = totalAvailable >= intermediateTarget and "intermediate" or "basic"
                    toast("No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.")
                elseif level == "intermediate" and totalAvailable < intermediateTarget then
                    buildLevel = "basic"
                    toast("No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.")
                end

                if totalAvailable < 18 then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local localRoot = zonePart.CFrame:PointToObjectSpace(root.Position)
                local margin
                if isCar then
                    margin = buildLevel == "advanced" and 11 or (buildLevel == "intermediate" and 9 or 7)
                else
                    margin = buildLevel == "advanced" and 16 or (buildLevel == "intermediate" and 13 or 10)
                end
                local halfX = math.max((zonePart.Size.X * 0.5) - margin, 0)
                local halfZ = math.max((zonePart.Size.Z * 0.5) - margin, 0)
                local clampedX = math.clamp(localRoot.X, -halfX, halfX)
                local clampedZ = math.clamp(localRoot.Z, -halfZ, halfZ)
                local topLocal = Vector3.new(clampedX, (zonePart.Size.Y * 0.5) + 1.5, clampedZ)
                local basePosition = zonePart.CFrame:PointToWorldSpace(topLocal)

                local look = root.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
                flatLook = flatLook.Unit
                local origin = CFrame.lookAt(basePosition, basePosition + flatLook)

                ------------------------------------------------------------
                -- INVENTORY + MATERIAL SELECTION
                ------------------------------------------------------------
                local remaining = {}
                for _, name in ipairs(structureNames) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = math.floor(amount) end
                end

                local componentNames = isCar
                    and {"CarSeat", "Wheel", "SmallWheel", "CarWheel", "FrontWheel", "BackWheel"}
                    or {"PilotSeat", "Jet", "UltraThruster", "Thruster", "Rocket"}

                for _, name in ipairs(componentNames) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = math.floor(amount) end
                end

                local function countOf(name)
                    return remaining[name] or 0
                end

                local function reserve(name, amount)
                    amount = amount or 1
                    if countOf(name) < amount then return false end
                    remaining[name] = countOf(name) - amount
                    return true
                end

                local materialPriority
                if buildLevel == "basic" then
                    materialPriority = {
                        "WoodBlock", "SmoothWoodBlock", "StoneBlock", "PlasticBlock",
                        "RustedBlock", "MetalBlock", "IronBlock", "SteelBlock",
                        "ConcreteBlock", "TitaniumBlock", "ObsidianBlock"
                    }
                elseif buildLevel == "intermediate" then
                    materialPriority = {
                        "MetalBlock", "IronBlock", "SteelBlock", "StoneBlock",
                        "ConcreteBlock", "BrickBlock", "MarbleBlock", "WoodBlock",
                        "SmoothWoodBlock", "TitaniumBlock", "ObsidianBlock"
                    }
                else
                    materialPriority = {
                        "TitaniumBlock", "ObsidianBlock", "MetalBlock", "SteelBlock",
                        "IronBlock", "ConcreteBlock", "MarbleBlock", "BrickBlock",
                        "StoneBlock", "WoodBlock", "SmoothWoodBlock"
                    }
                end

                local function bestMaterial()
                    local best, bestCount
                    for _, name in ipairs(materialPriority) do
                        local amount = countOf(name)
                        if amount > 0 and (not bestCount or amount > bestCount) then
                            best, bestCount = name, amount
                        end
                    end
                    return best
                end

                local primaryMaterial = bestMaterial()
                if not primaryMaterial then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local points = {}
                local function add(x, y, z, role, rotation)
                    points[#points + 1] = {
                        x = x, y = y, z = z,
                        role = role or "hull",
                        rotation = rotation
                    }
                end

                ------------------------------------------------------------
                -- VEHICLE GEOMETRY
                ------------------------------------------------------------
                if isCar then
                    if buildLevel == "basic" then
                        -- Compact 3-wide × 6-long chassis.
                        for z = -3, 2 do
                            for x = -1, 1 do add(x, 0, z, "hull") end
                        end
                        -- Hood / bumpers.
                        for x = -1, 1 do
                            add(x, 1, -3, "armor")
                            add(x, 1, 2, "armor")
                        end
                        -- Side body, cockpit remains open.
                        for z = -1, 1 do
                            add(-1, 1, z, "armor")
                            add(1, 1, z, "armor")
                        end
                        add(0, 1, -2, "hull")

                    elseif buildLevel == "intermediate" then
                        -- Wider 5 × 7 chassis.
                        for z = -3, 3 do
                            for x = -2, 2 do add(x, 0, z, "hull") end
                        end
                        for x = -2, 2 do
                            add(x, 1, -3, "armor")
                            add(x, 1, 3, "armor")
                        end
                        for z = -2, 2 do
                            add(-2, 1, z, "armor")
                            add(2, 1, z, "armor")
                        end
                        -- Hood and windshield.
                        for x = -1, 1 do add(x, 1, -2, "hull") end
                        for x = -1, 1 do add(x, 2, -1, "glass") end
                        -- Partial roof behind the driver.
                        for x = -1, 1 do add(x, 3, 1, "armor") end

                    else
                        -- Long reinforced 5 × 9 chassis with cabin.
                        for z = -4, 4 do
                            for x = -2, 2 do add(x, 0, z, "hull") end
                        end
                        for x = -2, 2 do
                            add(x, 1, -4, "armor")
                            add(x, 1, 4, "armor")
                        end
                        for z = -3, 3 do
                            add(-2, 1, z, "armor")
                            add(2, 1, z, "armor")
                        end
                        -- Hood, windshield and full roof.
                        for z = -3, -2 do
                            for x = -1, 1 do add(x, 1, z, "hull") end
                        end
                        for x = -1, 1 do add(x, 2, -1, "glass") end
                        for z = 0, 2 do
                            add(-1, 2, z, "armor")
                            add(1, 2, z, "armor")
                        end
                        for z = 0, 2 do
                            for x = -1, 1 do add(x, 3, z, "armor") end
                        end
                    end
                else
                    if buildLevel == "basic" then
                        -- Narrow fuselage.
                        for z = -5, 5 do add(0, 0, z, "hull") end
                        for z = -3, 3 do add(0, 1, z, "hull") end
                        -- Main wings.
                        for x = -4, 4 do add(x, 0, 0, "hull") end
                        for x = -2, 2 do add(x, 0, 1, "hull") end
                        -- Tail plane + vertical fin.
                        for x = -2, 2 do add(x, 1, 4, "armor") end
                        add(0, 2, 4, "armor")
                        add(0, 3, 4, "armor")
                        -- Nose.
                        add(0, 1, -4, "armor")
                        add(0, 2, -3, "glass")

                    elseif buildLevel == "intermediate" then
                        -- 3-wide fuselage.
                        for z = -6, 6 do
                            for x = -1, 1 do add(x, 0, z, "hull") end
                        end
                        for z = -4, 4 do add(0, 1, z, "hull") end
                        -- Broad tapered wings.
                        for x = -6, 6 do add(x, 0, 0, "hull") end
                        for x = -5, 5 do add(x, 0, 1, "hull") end
                        for x = -3, 3 do add(x, 0, 2, "hull") end
                        -- Tail.
                        for x = -3, 3 do add(x, 1, 5, "armor") end
                        add(0, 2, 5, "armor")
                        add(0, 3, 5, "armor")
                        add(0, 4, 5, "armor")
                        -- Cockpit windshield.
                        for x = -1, 1 do add(x, 2, -2, "glass") end

                    else
                        -- Reinforced 3-wide long fuselage.
                        for z = -7, 7 do
                            for x = -1, 1 do add(x, 0, z, "hull") end
                        end
                        for z = -5, 5 do
                            add(-1, 1, z, "armor")
                            add(0, 1, z, "hull")
                            add(1, 1, z, "armor")
                        end
                        -- Large layered wings.
                        for x = -8, 8 do add(x, 0, 0, "hull") end
                        for x = -7, 7 do add(x, 0, 1, "hull") end
                        for x = -5, 5 do add(x, 0, 2, "hull") end
                        for x = -3, 3 do add(x, 1, 1, "armor") end
                        -- Full tail assembly.
                        for x = -4, 4 do add(x, 1, 6, "armor") end
                        for y = 2, 5 do add(0, y, 6, "armor") end
                        -- Cockpit.
                        for x = -1, 1 do
                            add(x, 2, -2, "glass")
                            add(x, 2, -1, "glass")
                        end
                        add(-1, 3, -1, "armor")
                        add(0, 3, -1, "armor")
                        add(1, 3, -1, "armor")
                    end
                end

                ------------------------------------------------------------
                -- PLACEMENT
                ------------------------------------------------------------
                local placed = 0
                local delayPerBlock = ENV.__HX_DEVICE == "mobile" and 0.080 or 0.055

                local function materialForRole(role)
                    if role == "glass" then
                        if countOf("GlassBlock") > 0 then return "GlassBlock" end
                        if countOf(primaryMaterial) > 0 then return primaryMaterial end
                    end
                    if role == "armor" then
                        local armorPriority = buildLevel == "advanced"
                            and {"ObsidianBlock", "TitaniumBlock", "MetalBlock", "SteelBlock", "IronBlock", "ConcreteBlock", "StoneBlock", "WoodBlock"}
                            or {"MetalBlock", "SteelBlock", "IronBlock", "ConcreteBlock", "StoneBlock", "WoodBlock", "SmoothWoodBlock"}
                        for _, name in ipairs(armorPriority) do
                            if countOf(name) > 0 then return name end
                        end
                    end
                    if countOf(primaryMaterial) > 0 then return primaryMaterial end
                    return bestMaterial()
                end

                local function placeNamed(blockName, worldCF)
                    if not blockName or countOf(blockName) <= 0 then return false end
                    local idObject = data:FindFirstChild(blockName)
                    if not idObject then return false end
                    local available = tonumber(idObject.Value) or 0
                    if available <= 0 then return false end

                    local okPlace = pcall(function()
                        rf:InvokeServer(
                            blockName,
                            available,
                            zonePart,
                            zonePart.CFrame:ToObjectSpace(worldCF),
                            true,
                            worldCF,
                            false
                        )
                    end)
                    if not okPlace then return false end

                    reserve(blockName, 1)
                    placed += 1
                    return true
                end

                for i, item in ipairs(points) do
                    if not alive then error("Cerrado") end
                    local material = materialForRole(item.role)
                    if not material then break end

                    local worldCF = origin * CFrame.new(item.x * 2, item.y * 2, item.z * 2)
                    if item.rotation then worldCF *= item.rotation end
                    placeNamed(material, worldCF)

                    if i % 12 == 0 then
                        task.wait(delayPerBlock * 2)
                    else
                        task.wait(delayPerBlock)
                    end
                end

                ------------------------------------------------------------
                -- VEHICLE COMPONENTS
                ------------------------------------------------------------
                local function firstOwned(candidates)
                    local best, bestCount
                    for _, name in ipairs(candidates) do
                        local amount = countOf(name)
                        if amount > 0 and (not bestCount or amount > bestCount) then
                            best, bestCount = name, amount
                        end
                    end
                    return best, bestCount or 0
                end

                if isCar then
                    local neededWheels = buildLevel == "advanced" and 6 or 4
                    local wheelCount = 0
                    for _, name in ipairs(wheelCandidates) do
                        wheelCount += math.max(0, countOf(name))
                    end
                    wheelCount = math.min(neededWheels, wheelCount)

                    local function pickWheel(forFront)
                        local preferred = forFront
                            and {"FrontWheel", "Wheel", "SmallWheel", "CarWheel", "BackWheel"}
                            or {"BackWheel", "Wheel", "SmallWheel", "CarWheel", "FrontWheel"}
                        for _, name in ipairs(preferred) do
                            if countOf(name) > 0 then return name end
                        end
                        return nil
                    end

                    -- Wheels touch the chassis directly and are added before CarSeat.
                    if wheelCount >= 4 then
                        local wheelZs
                        if wheelCount >= 6 then
                            wheelZs = {-3, 0, 3}
                        elseif buildLevel == "basic" then
                            wheelZs = {-2, 2}
                        else
                            wheelZs = {-2.5, 2.5}
                        end

                        local wheelX = buildLevel == "basic" and 2 or 3
                        local made = 0
                        for axleIndex, z in ipairs(wheelZs) do
                            for _, x in ipairs({-wheelX, wheelX}) do
                                if made >= wheelCount then break end

                                local wheelName = pickWheel(axleIndex == 1)
                                if not wheelName then break end

                                made += 1
                                local wheelCF = origin
                                    * CFrame.new(x * 2, 1.8, z * 2)
                                    * CFrame.Angles(0, 0, math.rad(90))
                                placeNamed(wheelName, wheelCF)
                                task.wait(0.16)
                            end
                        end
                    end

                    local hadCarSeat = countOf("CarSeat") > 0
                    if hadCarSeat then
                        -- Clear central cockpit; seat is placed last to bind wheels.
                        local seatCF = origin * CFrame.new(0, 5.5, 0)
                        placeNamed("CarSeat", seatCF)
                        task.wait(0.75)
                    end

                    if wheelCount >= 4 and hadCarSeat then
                        toast("Sistema de conducción del carro añadido.")
                    else
                        toast("No tienes suficientes ruedas o asiento de manejo; el carro puede crearse sin conducción completa.")
                    end
                else
                    local propulsionName, propulsionStock = firstOwned(planePropulsionCandidates)
                    local wantedPropulsion = buildLevel == "advanced" and 3 or (buildLevel == "intermediate" and 2 or 1)
                    local propulsionCount = math.min(wantedPropulsion, propulsionStock)
                    local tailZ = buildLevel == "basic" and 5 or (buildLevel == "intermediate" and 6 or 7)

                    if propulsionName and propulsionCount > 0 then
                        for n = 1, propulsionCount do
                            local xOffset = 0
                            if propulsionCount == 2 then
                                xOffset = n == 1 and -1.5 or 1.5
                            elseif propulsionCount >= 3 then
                                local slots = {-2.5, 0, 2.5}
                                xOffset = slots[n] or 0
                            end

                            -- Mounted directly on the rear fuselage/tail structure.
                            local propCF = origin
                                * CFrame.new(xOffset * 2, 4.2, tailZ * 2)
                                * CFrame.Angles(0, math.rad(180), 0)
                            placeNamed(propulsionName, propCF)
                            task.wait(0.28)
                        end
                        task.wait(0.30)
                    end

                    local hadPilotSeat = countOf("PilotSeat") > 0
                    if hadPilotSeat then
                        local pilotCF = origin * CFrame.new(0, 5.5, -1.5 * 2)
                        placeNamed("PilotSeat", pilotCF)
                        task.wait(0.80)
                    end

                    if propulsionCount > 0 and hadPilotSeat then
                        toast("Sistema de vuelo del avión añadido.")
                    else
                        toast("No tienes asiento de piloto o propulsión; el avión puede crearse sin vuelo completo.")
                    end
                end

                worldCache.boatRoot = nil
                worldCache.nearestSeat = nil
                worldCache.boatRootAt = 0
                worldCache.seatAt = 0

                if placed <= 0 then
                    error("BuildingTool rechazó las colocaciones")
                end
            end)

            activeStates.autoBuildBoatBusy = false

            if okBuild then
                toast(isCar and "Carro creado correctamente." or "Avión creado correctamente.")
            else
                toast(
                    ENV.__HX_TR(isCar and "No se pudo completar el carro: " or "No se pudo completar el avión: ")
                    .. tostring(errBuild)
                )
            end
        end

        if isCar then
            modalButton("Básico", "Carro compacto con chasis, cuatro ruedas, asiento de manejo y carrocería ligera.", function()
                buildPreset("basic")
            end)
            modalButton("Intermedio", "Carro reforzado con chasis ancho, carrocería, parabrisas, techo parcial y cuatro ruedas.", function()
                buildPreset("intermediate")
            end)
            modalButton("Avanzado", "Carro grande con chasis reforzado, cabina completa, parabrisas, techo y seis ruedas cuando estén disponibles.", function()
                buildPreset("advanced")
            end)
        else
            modalButton("Básico", "Avión ligero con fuselaje, alas, cola, asiento de piloto y propulsión trasera.", function()
                buildPreset("basic")
            end)
            modalButton("Intermedio", "Avión reforzado con alas amplias, estabilizadores, cabina y doble propulsión cuando esté disponible.", function()
                buildPreset("intermediate")
            end)
            modalButton("Avanzado", "Avión grande con fuselaje reforzado, alas extensas, cabina, cola completa y propulsión múltiple.", function()
                buildPreset("advanced")
            end)
        end
    end)
end

actionButton(
    pages.AutoBuild,
    "Auto Crear Carro",
    "Crea automáticamente un carro funcional en tres niveles usando tus materiales disponibles.",
    function() activeStates._openAutoVehicle("car") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Avión",
    "Crea automáticamente un avión en tres niveles usando tus materiales y componentes disponibles.",
    function() activeStates._openAutoVehicle("plane") end,
    "CONSTRUIR"
)

--====================================================
-- EXTRA AUTO BUILD TYPES
-- Helicopter / Submarine / Motorcycle / Tank / Rocket /
-- Farm Boat / Base
--====================================================
activeStates._openExtraAutoBuild = function(kind)
    local titles = {
        helicopter = "Selecciona un helicóptero",
        submarine = "Selecciona un submarino",
        motorcycle = "Selecciona una moto",
        tank = "Selecciona un tanque",
        rocket = "Selecciona un cohete",
        farmboat = "Selecciona un barco de farm",
        base = "Selecciona una base",
    }

    openModal(titles[kind] or "CREACIÓN AUTOMÁTICA", function()
        local function buildPreset(level, purchaseChoice)
            if activeStates.autoBuildBoatBusy then
                toast("Ya se está creando un vehículo.")
                return
            end
            if activeStates.autoFarm or activeStates._finishBusy or activeStates._materialFarmBusy then
                toast("Desactiva Auto Farm antes de crear un vehículo.")
                return
            end

            local data = LP:FindFirstChild("Data")
            if not data then
                toast("No encontré los datos de bloques del jugador.")
                return
            end

            local structureNames = {
                "WoodBlock", "SmoothWoodBlock", "StoneBlock", "RustedBlock",
                "MetalBlock", "IronBlock", "SteelBlock", "ConcreteBlock",
                "BrickBlock", "MarbleBlock", "CoalBlock", "TitaniumBlock",
                "ObsidianBlock", "PlasticBlock", "GlassBlock", "SandBlock"
            }
            local wheelCandidates = {
                "FrontWheel", "BackWheel", "Wheel", "SmallWheel", "CarWheel"
            }
            local propulsionCandidates = {
                "JetTurbine", "Jet", "UltraThruster", "Thruster", "Rocket"
            }
            local boatMotorCandidates = {
                "UltraBoatMotor", "WinterBoatMotor", "BoatMotor"
            }

            local function stock(name)
                local obj = data:FindFirstChild(name)
                return obj and math.max(0, math.floor(tonumber(obj.Value) or 0)) or 0
            end

            local function totalOf(names)
                local total = 0
                for _, name in ipairs(names) do total += stock(name) end
                return total
            end

            local function structuralStock()
                return totalOf(structureNames)
            end

            local targets = {
                helicopter = {basic = 55, intermediate = 90, advanced = 140},
                submarine = {basic = 65, intermediate = 105, advanced = 155},
                motorcycle = {basic = 28, intermediate = 42, advanced = 62},
                tank = {basic = 75, intermediate = 120, advanced = 175},
                rocket = {basic = 38, intermediate = 62, advanced = 92},
                farmboat = {basic = 38, intermediate = 58, advanced = 82},
                base = {basic = 50, intermediate = 105, advanced = 180},
            }

            local target = (targets[kind] and targets[kind][level]) or 55
            local missingStructure = math.max(target - structuralStock(), 0)
            local materialPackPrice = level == "advanced" and 400 or (level == "intermediate" and 325 or 250)
            local materialPacksNeeded = math.ceil(missingStructure / 50)

            local componentCost = 0
            local componentMissing = false

            if kind == "motorcycle" then
                local missingWheels = math.max(2 - totalOf(wheelCandidates), 0)
                componentMissing = missingWheels > 0 or stock("CarSeat") <= 0
                componentCost = componentMissing and 750 or 0

            elseif kind == "tank" then
                local wanted = level == "advanced" and 8 or (level == "intermediate" and 6 or 4)
                local missingWheels = math.max(wanted - totalOf(wheelCandidates), 0)
                local packs = math.max(math.ceil(missingWheels / 4), stock("CarSeat") <= 0 and 1 or 0)
                componentMissing = packs > 0
                componentCost = packs * 750

            elseif kind == "helicopter" or kind == "rocket" then
                local wanted = kind == "helicopter"
                    and (level == "advanced" and 3 or (level == "intermediate" and 2 or 1))
                    or (level == "advanced" and 3 or (level == "intermediate" and 2 or 1))
                componentMissing = stock("PilotSeat") <= 0 or totalOf(propulsionCandidates) < wanted
                componentCost = componentMissing and 4000 or 0

            elseif kind == "submarine" or kind == "farmboat" then
                local wanted = level == "advanced" and 2 or 1
                componentMissing = stock("CarSeat") <= 0 or totalOf(boatMotorCandidates) < wanted
                componentCost = componentMissing and 450 or 0
            end

            local requiredGold = (materialPacksNeeded * materialPackPrice) + componentCost
            local gold = tonumber(getGoldValue()) or 0

            if purchaseChoice == nil and (missingStructure > 0 or componentMissing) then
                if gold >= requiredGold then
                    openModal("Recursos insuficientes", function()
                        local info
                        if ENV.__HX_LANG == "en" then
                            info = string.format(
                                "Missing blocks: %d · Gold: %d / %d%s",
                                missingStructure,
                                gold,
                                requiredGold,
                                componentMissing and " · Components missing" or ""
                            )
                        else
                            info = string.format(
                                "Bloques faltantes: %d · Oro: %d / %d%s",
                                missingStructure,
                                gold,
                                requiredGold,
                                componentMissing and " · Faltan componentes" or ""
                            )
                        end

                        modalButton(
                            "SÍ, COMPRAR Y CONTINUAR",
                            info .. "\n" .. ENV.__HX_TR("HX Boat comprará únicamente con el oro del juego y continuará automáticamente."),
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, true)
                            end
                        )

                        modalButton(
                            "NO, CONTINUAR SIN COMPRAR",
                            "Continuar con los materiales actuales; el vehículo puede reducirse.",
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, false)
                            end
                        )
                    end)
                else
                    openModal("Farmear para completar", function()
                        local info
                        if ENV.__HX_LANG == "en" then
                            info = string.format(
                                "Current Gold: %d · Needed: %d · Missing Gold: %d",
                                gold,
                                requiredGold,
                                math.max(requiredGold - gold, 0)
                            )
                        else
                            info = string.format(
                                "Oro actual: %d · Necesario: %d · Oro faltante: %d",
                                gold,
                                requiredGold,
                                math.max(requiredGold - gold, 0)
                            )
                        end

                        modalButton(
                            "FARMEAR Y COMPRAR",
                            info .. "\n" .. ENV.__HX_TR("Te faltan recursos y tu oro actual no alcanza para comprarlos. HX Boat puede farmear hasta conseguir el oro necesario, comprar automáticamente lo faltante y continuar."),
                            function()
                                closeModal()
                                activeStates._farmGoldForBuild(requiredGold, function()
                                    buildPreset(level, true)
                                end)
                            end
                        )

                        modalButton(
                            "CONTINUAR SIN FARMEAR",
                            "Continuar con los materiales actuales; el vehículo puede reducirse.",
                            function()
                                closeModal()
                                task.spawn(buildPreset, level, false)
                            end
                        )
                    end)
                end
                return
            end

            activeStates.autoBuildBoatBusy = true
            closeModal()
            toast("Creando vehículo automáticamente...")
            task.wait(0.18)

            local okBuild, errBuild = pcall(function()
                local char = getChar()
                local hum = getHum()
                local root = getRoot()
                if not char or not hum or not root then error("Personaje no disponible") end

                local tool = char:FindFirstChild("BuildingTool")
                if not tool then
                    local backpack = LP:FindFirstChildOfClass("Backpack")
                    local backpackTool = backpack and backpack:FindFirstChild("BuildingTool")
                    if backpackTool then
                        hum:EquipTool(backpackTool)
                        task.wait(0.18)
                        tool = char:FindFirstChild("BuildingTool") or backpackTool
                    end
                end
                if not tool then
                    local playerBuild = Workspace:FindFirstChild(LP.Name)
                    tool = playerBuild and playerBuild:FindFirstChild("BuildingTool")
                end

                local rf = tool and tool:FindFirstChild("RF", true)
                if not rf or not rf:IsA("RemoteFunction") then
                    error(ENV.__HX_TR("No encontré BuildingTool. Abre el modo de construcción e inténtalo otra vez."))
                end

                data = LP:FindFirstChild("Data")
                if not data then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local function liveStock(name)
                    local obj = data:FindFirstChild(name)
                    return obj and math.max(0, math.floor(tonumber(obj.Value) or 0)) or 0
                end

                local function liveTotal(names)
                    local total = 0
                    for _, name in ipairs(names) do total += liveStock(name) end
                    return total
                end

                local function liveStructural()
                    return liveTotal(structureNames)
                end

                --------------------------------------------------------
                -- PURCHASE FILTER
                --------------------------------------------------------
                if purchaseChoice == true then
                    local shopRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
                    local boughtAnything = false

                    local function buyProduct(productName, watchNames, price)
                        if not shopRemote or not shopRemote:IsA("RemoteEvent") then return false end
                        local beforeGold = tonumber(getGoldValue()) or 0
                        if beforeGold < price then return false end

                        local before = 0
                        for _, name in ipairs(watchNames) do before += liveStock(name) end

                        local ok = pcall(function()
                            shopRemote:FireServer(productName)
                        end)
                        if not ok then return false end

                        task.wait(0.50)

                        local after = 0
                        for _, name in ipairs(watchNames) do after += liveStock(name) end
                        local afterGold = tonumber(getGoldValue()) or beforeGold
                        return after > before or afterGold < beforeGold
                    end

                    local productName = level == "advanced" and "Titanium Block"
                        or (level == "intermediate" and "Metal Block" or "Wood Block")
                    local internalName = level == "advanced" and "TitaniumBlock"
                        or (level == "intermediate" and "MetalBlock" or "WoodBlock")
                    local packPrice = level == "advanced" and 400
                        or (level == "intermediate" and 325 or 250)

                    local packs = math.ceil(math.max(target - liveStructural(), 0) / 50)
                    for _ = 1, packs do
                        if not buyProduct(productName, {internalName}, packPrice) then break end
                        boughtAnything = true
                    end

                    if kind == "motorcycle" then
                        if liveStock("CarSeat") <= 0 or liveTotal(wheelCandidates) < 2 then
                            if buyProduct(
                                "New Car Pack",
                                {"CarSeat", "FrontWheel", "BackWheel", "Wheel", "SmallWheel", "CarWheel"},
                                750
                            ) then boughtAnything = true end
                        end

                    elseif kind == "tank" then
                        local wanted = level == "advanced" and 8 or (level == "intermediate" and 6 or 4)
                        local missing = math.max(wanted - liveTotal(wheelCandidates), 0)
                        local carPacks = math.max(math.ceil(missing / 4), liveStock("CarSeat") <= 0 and 1 or 0)

                        for _ = 1, carPacks do
                            if not buyProduct(
                                "New Car Pack",
                                {"CarSeat", "FrontWheel", "BackWheel", "Wheel", "SmallWheel", "CarWheel"},
                                750
                            ) then break end
                            boughtAnything = true
                        end

                    elseif kind == "helicopter" or kind == "rocket" then
                        local wanted = level == "advanced" and 3 or (level == "intermediate" and 2 or 1)
                        if liveStock("PilotSeat") <= 0 or liveTotal(propulsionCandidates) < wanted then
                            if buyProduct(
                                "Plane Blocks",
                                {"PilotSeat", "JetTurbine", "Jet", "UltraThruster", "Thruster", "Rocket"},
                                4000
                            ) then boughtAnything = true end
                        end

                    elseif kind == "submarine" or kind == "farmboat" then
                        local wanted = level == "advanced" and 2 or 1
                        if liveStock("CarSeat") <= 0 or liveTotal(boatMotorCandidates) < wanted then
                            if buyProduct("Boat Motor", {"BoatMotor", "CarSeat"}, 450) then
                                boughtAnything = true
                            end
                        end
                    end

                    if boughtAnything then
                        toast("Compra automática completada. Continuando construcción...")
                    end
                    task.wait(0.12)
                end

                --------------------------------------------------------
                -- BUILD ZONE + NEAREST ORIGIN
                --------------------------------------------------------
                local zone
                for _, v in ipairs(Workspace:GetChildren()) do
                    local teamValue = v:FindFirstChild("TeamColor")
                    if teamValue then
                        local okTeam, value = pcall(function() return teamValue.Value end)
                        if okTeam and value == LP.TeamColor then
                            zone = v
                            break
                        end
                    end
                end
                if not zone then zone = getTeamSpawn() end

                local zonePart = zone and (zone:IsA("BasePart") and zone or findFirstPart(zone))
                if not zonePart then error(ENV.__HX_TR("No pude detectar tu zona de construcción.")) end

                local currentStock = liveStructural()
                local levelTargets = targets[kind] or targets.helicopter
                local buildLevel = level
                if level == "advanced" and currentStock < levelTargets.advanced then
                    buildLevel = currentStock >= levelTargets.intermediate and "intermediate" or "basic"
                    toast("No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.")
                elseif level == "intermediate" and currentStock < levelTargets.intermediate then
                    buildLevel = "basic"
                    toast("No hay suficientes materiales para el tamaño seleccionado; crearé una versión reducida.")
                end

                if currentStock < math.min(levelTargets.basic, 18) then
                    error(ENV.__HX_TR("No encontré los datos de bloques del jugador."))
                end

                local marginMap = {
                    helicopter = {basic = 11, intermediate = 14, advanced = 17},
                    submarine = {basic = 10, intermediate = 13, advanced = 16},
                    motorcycle = {basic = 6, intermediate = 7, advanced = 8},
                    tank = {basic = 9, intermediate = 12, advanced = 14},
                    rocket = {basic = 7, intermediate = 8, advanced = 10},
                    farmboat = {basic = 7, intermediate = 9, advanced = 11},
                    base = {basic = 9, intermediate = 13, advanced = 17},
                }
                local margin = (marginMap[kind] and marginMap[kind][buildLevel]) or 10

                local localRoot = zonePart.CFrame:PointToObjectSpace(root.Position)
                local halfX = math.max((zonePart.Size.X * 0.5) - margin, 0)
                local halfZ = math.max((zonePart.Size.Z * 0.5) - margin, 0)
                local clampedX = math.clamp(localRoot.X, -halfX, halfX)
                local clampedZ = math.clamp(localRoot.Z, -halfZ, halfZ)
                local basePosition = zonePart.CFrame:PointToWorldSpace(
                    Vector3.new(clampedX, (zonePart.Size.Y * 0.5) + 1.5, clampedZ)
                )

                local look = root.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
                flatLook = flatLook.Unit
                local origin = CFrame.lookAt(basePosition, basePosition + flatLook)

                --------------------------------------------------------
                -- INVENTORY
                --------------------------------------------------------
                local remaining = {}
                for _, name in ipairs(structureNames) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = amount end
                end
                for _, name in ipairs(wheelCandidates) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = amount end
                end
                for _, name in ipairs(propulsionCandidates) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = amount end
                end
                for _, name in ipairs(boatMotorCandidates) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = amount end
                end
                for _, name in ipairs({"CarSeat", "PilotSeat"}) do
                    local amount = liveStock(name)
                    if amount > 0 then remaining[name] = amount end
                end

                local function countOf(name)
                    return remaining[name] or 0
                end

                local function reserve(name)
                    if countOf(name) <= 0 then return false end
                    remaining[name] = countOf(name) - 1
                    return true
                end

                local materialPriority = buildLevel == "advanced"
                    and {"TitaniumBlock", "ObsidianBlock", "MetalBlock", "SteelBlock", "IronBlock", "ConcreteBlock", "StoneBlock", "WoodBlock"}
                    or (buildLevel == "intermediate"
                        and {"MetalBlock", "IronBlock", "SteelBlock", "StoneBlock", "ConcreteBlock", "WoodBlock", "SmoothWoodBlock"}
                        or {"WoodBlock", "SmoothWoodBlock", "StoneBlock", "PlasticBlock", "MetalBlock", "IronBlock"})

                local function bestMaterial()
                    local best, bestCount
                    for _, name in ipairs(materialPriority) do
                        local amount = countOf(name)
                        if amount > 0 and (not bestCount or amount > bestCount) then
                            best, bestCount = name, amount
                        end
                    end
                    return best
                end

                local primaryMaterial = bestMaterial()
                if not primaryMaterial then error("Sin materiales") end

                local points = {}
                local function add(x, y, z, role)
                    points[#points + 1] = {x = x, y = y, z = z, role = role or "hull"}
                end

                --------------------------------------------------------
                -- GEOMETRY
                --------------------------------------------------------
                if kind == "helicopter" then
                    local len = buildLevel == "advanced" and 5 or (buildLevel == "intermediate" and 4 or 3)
                    local width = buildLevel == "advanced" and 2 or 1

                    for z = -len, 1 do
                        for x = -width, width do add(x, 0, z, "hull") end
                    end
                    for z = -2, 0 do
                        add(-width, 1, z, "armor")
                        add(width, 1, z, "armor")
                    end
                    for z = 2, len + 3 do add(0, 1, z, "hull") end
                    add(0, 2, len + 3, "armor")
                    add(0, 3, len + 3, "armor")

                    local rotor = buildLevel == "advanced" and 6 or (buildLevel == "intermediate" and 5 or 4)
                    for x = -rotor, rotor do add(x, 4, -1, "armor") end
                    for z = -rotor - 1, rotor - 1 do add(0, 4, z, "armor") end

                    for z = -2, 1 do
                        add(-width - 1, -1, z, "armor")
                        add(width + 1, -1, z, "armor")
                    end

                elseif kind == "submarine" then
                    local len = buildLevel == "advanced" and 6 or (buildLevel == "intermediate" and 5 or 4)
                    local width = buildLevel == "advanced" and 2 or 1

                    for z = -len, len do
                        local currentWidth = math.abs(z) == len and 0 or width
                        for x = -currentWidth, currentWidth do add(x, 0, z, "hull") end
                    end
                    for z = -len + 1, len - 1 do
                        add(-width, 1, z, "armor")
                        add(width, 1, z, "armor")
                    end
                    for z = -2, 2 do add(0, 2, z, "armor") end
                    add(0, 3, 0, "glass")
                    add(-width - 1, 1, len - 1, "armor")
                    add(width + 1, 1, len - 1, "armor")

                elseif kind == "motorcycle" then
                    local len = buildLevel == "advanced" and 4 or 3
                    for z = -len, len do add(0, 0, z, "hull") end
                    add(0, 1, -2, "armor")
                    add(0, 1, -1, "armor")
                    add(-1, 1, 1, "armor")
                    add(1, 1, 1, "armor")
                    if buildLevel ~= "basic" then
                        add(-1, 0, 0, "hull")
                        add(1, 0, 0, "hull")
                    end

                elseif kind == "tank" then
                    local len = buildLevel == "advanced" and 5 or (buildLevel == "intermediate" and 4 or 3)
                    local width = buildLevel == "advanced" and 3 or 2
                    for z = -len, len do
                        for x = -width, width do add(x, 0, z, "hull") end
                    end
                    for z = -len + 1, len - 1 do
                        add(-width, 1, z, "armor")
                        add(width, 1, z, "armor")
                    end
                    for x = -1, 1 do
                        for z = -1, 1 do add(x, 2, z, "armor") end
                    end
                    add(0, 3, 0, "armor")
                    for z = -5, -2 do add(0, 3, z, "armor") end

                elseif kind == "rocket" then
                    local height = buildLevel == "advanced" and 13 or (buildLevel == "intermediate" and 10 or 7)
                    local width = buildLevel == "advanced" and 2 or 1

                    for y = 0, height do
                        if y < height - 2 then
                            for x = -width, width do
                                add(x, y, 0, y % 3 == 0 and "armor" or "hull")
                            end
                        else
                            add(0, y, 0, "armor")
                        end
                    end

                    for _, x in ipairs({-width - 1, width + 1}) do
                        add(x, 0, 0, "armor")
                        add(x, 1, 0, "armor")
                    end
                    add(0, 0, -width - 1, "armor")
                    add(0, 0, width + 1, "armor")

                elseif kind == "farmboat" then
                    local len = buildLevel == "advanced" and 5 or (buildLevel == "intermediate" and 4 or 3)
                    local width = buildLevel == "advanced" and 2 or 1

                    for z = -len, len do
                        local currentWidth = z == -len and 0 or width
                        for x = -currentWidth, currentWidth do add(x, 0, z, "hull") end
                    end
                    for z = -len + 1, len do
                        add(-width, 1, z, "armor")
                        add(width, 1, z, "armor")
                    end
                    for x = -width, width do add(x, 1, -len + 1, "armor") end
                    if buildLevel == "advanced" then
                        for z = -1, 2 do
                            add(-width, 2, z, "armor")
                            add(width, 2, z, "armor")
                        end
                    end

                else
                    local radius = buildLevel == "advanced" and 7 or (buildLevel == "intermediate" and 5 or 3)
                    for x = -radius, radius do
                        for z = -radius, radius do
                            add(x, 0, z, "hull")
                        end
                    end

                    if buildLevel ~= "basic" then
                        for x = -radius, radius do
                            add(x, 1, -radius, "armor")
                            add(x, 1, radius, "armor")
                        end
                        for z = -radius + 1, radius - 1 do
                            add(-radius, 1, z, "armor")
                            add(radius, 1, z, "armor")
                        end
                    end

                    if buildLevel == "advanced" then
                        for _, x in ipairs({-radius, radius}) do
                            for _, z in ipairs({-radius, radius}) do
                                add(x, 2, z, "armor")
                                add(x, 3, z, "armor")
                            end
                        end
                    end
                end

                --------------------------------------------------------
                -- PLACEMENT
                --------------------------------------------------------
                local placed = 0
                local delayPerBlock = ENV.__HX_DEVICE == "mobile" and 0.080 or 0.055

                local function materialForRole(role)
                    if role == "glass" and countOf("GlassBlock") > 0 then return "GlassBlock" end
                    if role == "armor" then
                        for _, name in ipairs({
                            "ObsidianBlock", "TitaniumBlock", "MetalBlock", "SteelBlock",
                            "IronBlock", "ConcreteBlock", "StoneBlock", "WoodBlock"
                        }) do
                            if countOf(name) > 0 then return name end
                        end
                    end
                    if countOf(primaryMaterial) > 0 then return primaryMaterial end
                    return bestMaterial()
                end

                local function placeNamed(name, cf)
                    if not name or countOf(name) <= 0 then return false end
                    local idObject = data:FindFirstChild(name)
                    if not idObject then return false end
                    local available = tonumber(idObject.Value) or 0
                    if available <= 0 then return false end

                    local okPlace = pcall(function()
                        rf:InvokeServer(
                            name,
                            available,
                            zonePart,
                            zonePart.CFrame:ToObjectSpace(cf),
                            true,
                            cf,
                            false
                        )
                    end)

                    if not okPlace then return false end
                    reserve(name)
                    placed += 1
                    return true
                end

                for i, item in ipairs(points) do
                    if not alive then error("Cerrado") end
                    local material = materialForRole(item.role)
                    if not material then break end

                    placeNamed(
                        material,
                        origin * CFrame.new(item.x * 2, item.y * 2, item.z * 2)
                    )

                    if i % 12 == 0 then
                        task.wait(delayPerBlock * 2)
                    else
                        task.wait(delayPerBlock)
                    end
                end

                --------------------------------------------------------
                -- COMPONENTS
                --------------------------------------------------------
                local function firstOwned(candidates)
                    for _, name in ipairs(candidates) do
                        if countOf(name) > 0 and data:FindFirstChild(name) then return name end
                    end
                    return nil
                end

                if kind == "motorcycle" or kind == "tank" then
                    local wanted = kind == "motorcycle"
                        and 2
                        or (buildLevel == "advanced" and 8 or (buildLevel == "intermediate" and 6 or 4))
                    local made = 0
                    local vehicleWidth = kind == "motorcycle" and 1.5 or (buildLevel == "advanced" and 4 or 3)
                    local axleZs = kind == "motorcycle"
                        and {-2.8, 2.8}
                        or (wanted >= 8 and {-4, -1.5, 1.5, 4} or (wanted >= 6 and {-3, 0, 3} or {-2.5, 2.5}))

                    for axleIndex, z in ipairs(axleZs) do
                        for _, x in ipairs(kind == "motorcycle" and {0} or {-vehicleWidth, vehicleWidth}) do
                            if made >= wanted then break end
                            local candidates = axleIndex == 1
                                and {"FrontWheel", "Wheel", "SmallWheel", "CarWheel", "BackWheel"}
                                or {"BackWheel", "Wheel", "SmallWheel", "CarWheel", "FrontWheel"}
                            local wheel = firstOwned(candidates)
                            if wheel then
                                local wheelCF = origin
                                    * CFrame.new(x * 2, 1.7, z * 2)
                                    * CFrame.Angles(0, 0, math.rad(90))
                                placeNamed(wheel, wheelCF)
                                made += 1
                                task.wait(0.16)
                            end
                        end
                    end

                    if countOf("CarSeat") > 0 then
                        local y = kind == "motorcycle" and 4.5 or 5.5
                        placeNamed("CarSeat", origin * CFrame.new(0, y, 0))
                        task.wait(0.75)
                    end

                elseif kind == "submarine" or kind == "farmboat" then
                    local motor = firstOwned(boatMotorCandidates)
                    local wanted = buildLevel == "advanced" and 2 or 1
                    local stern = kind == "submarine"
                        and (buildLevel == "advanced" and 6 or (buildLevel == "intermediate" and 5 or 4))
                        or (buildLevel == "advanced" and 5 or (buildLevel == "intermediate" and 4 or 3))

                    if motor then
                        for n = 1, math.min(wanted, countOf(motor)) do
                            local x = wanted == 2 and (n == 1 and -1.5 or 1.5) or 0
                            placeNamed(motor, origin * CFrame.new(x * 2, 4.5, stern * 2))
                            task.wait(0.30)
                        end
                        task.wait(0.35)
                    end

                    if countOf("CarSeat") > 0 then
                        placeNamed("CarSeat", origin * CFrame.new(0, 5.5, 0))
                        task.wait(0.80)
                    end

                elseif kind == "helicopter" or kind == "rocket" then
                    local propulsion = firstOwned(propulsionCandidates)
                    local wanted = buildLevel == "advanced" and 3 or (buildLevel == "intermediate" and 2 or 1)

                    if propulsion then
                        if kind == "rocket" then
                            local slots = wanted >= 3 and {-2, 0, 2} or (wanted == 2 and {-1.5, 1.5} or {0})
                            for n = 1, math.min(wanted, countOf(propulsion)) do
                                local x = slots[n] or 0
                                local cf = origin
                                    * CFrame.new(x * 2, 1.5, 0)
                                    * CFrame.Angles(math.rad(-90), 0, 0)
                                placeNamed(propulsion, cf)
                                task.wait(0.28)
                            end
                        else
                            local slots = wanted >= 3 and {-2, 0, 2} or (wanted == 2 and {-1.5, 1.5} or {0})
                            for n = 1, math.min(wanted, countOf(propulsion)) do
                                local x = slots[n] or 0
                                local cf = origin
                                    * CFrame.new(x * 2, 3.8, 2)
                                    * CFrame.Angles(0, math.rad(180), 0)
                                placeNamed(propulsion, cf)
                                task.wait(0.28)
                            end
                        end
                        task.wait(0.30)
                    end

                    if countOf("PilotSeat") > 0 then
                        local seatCF = kind == "rocket"
                            and (origin * CFrame.new(0, 6, 0))
                            or (origin * CFrame.new(0, 5.5, -2))
                        placeNamed("PilotSeat", seatCF)
                        task.wait(0.80)
                    end
                end

                worldCache.boatRoot = nil
                worldCache.nearestSeat = nil
                worldCache.boatRootAt = 0
                worldCache.seatAt = 0

                if placed <= 0 then error("BuildingTool rechazó las colocaciones") end
            end)

            activeStates.autoBuildBoatBusy = false

            if okBuild then
                toast("Construcción creada correctamente.")
            else
                toast(ENV.__HX_TR("No se pudo completar la construcción: ") .. tostring(errBuild))
            end
        end

        modalButton("Básico", "Versión básica, pequeña y económica.", function()
            buildPreset("basic")
        end)
        modalButton("Intermedio", "Versión intermedia con más estructura y protección.", function()
            buildPreset("intermediate")
        end)
        modalButton("Avanzado", "Versión avanzada con mayor tamaño, refuerzo y componentes.", function()
            buildPreset("advanced")
        end)
    end)
end

actionButton(
    pages.AutoBuild,
    "Auto Crear Helicóptero",
    "Crea un helicóptero con fuselaje, patines, cola, rotor visual y control de vuelo.",
    function() activeStates._openExtraAutoBuild("helicopter") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Submarino",
    "Crea un submarino reforzado con casco cerrado, cabina y propulsión trasera.",
    function() activeStates._openExtraAutoBuild("submarine") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Moto",
    "Crea una moto compacta con chasis, dos ruedas y asiento de manejo.",
    function() activeStates._openExtraAutoBuild("motorcycle") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Tanque",
    "Crea un tanque reforzado con chasis ancho, ruedas laterales y torreta visual.",
    function() activeStates._openExtraAutoBuild("tank") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Cohete",
    "Crea un cohete vertical con fuselaje, punta, aletas y propulsión inferior.",
    function() activeStates._openExtraAutoBuild("rocket") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Barco de Farm",
    "Crea un barco compacto pensado para recorrer stages con poco peso y buena protección.",
    function() activeStates._openExtraAutoBuild("farmboat") end,
    "CONSTRUIR"
)

actionButton(
    pages.AutoBuild,
    "Auto Crear Base/Plataforma",
    "Crea una plataforma estable para construir o usar como base.",
    function() activeStates._openExtraAutoBuild("base") end,
    "CONSTRUIR"
)

-- BOAT
makeSection(pages.Boat, "BARCO", "Control de vuelo y velocidad del asiento/barco que estés usando.")

toggleRow(pages.Boat, "Boat Fly", "WASD para moverte, Espacio para subir y Ctrl para bajar.", "boatFly", false, function(on)
    if not on then destroyFlyObjects() end
end)

toggleRow(pages.Boat, "Boat Speed", "Aplica un boost de velocidad mientras conduces un asiento del barco.", "ENV.__HX_boatSpeed", false)

sliderRow(pages.Boat, "Potencia del barco", "Velocidad usada por Boat Fly, Boat Speed y Auto Pilot.", 40, 450, 120, 10, function(v)
    ENV.__HX_boatSpeed = v
end)

toggleRow(pages.Boat, "Auto Pilot", "Guía el barco automáticamente hacia el tesoro.", "autoPilot", false)
toggleRow(pages.Boat, "Boat Stabilizer", "Mantiene el barco vertical y reduce giros descontrolados.", "boatStabilizer", false)
toggleRow(pages.Boat, "Boat Anti Flip", "Endereza el barco automáticamente si se vuelca.", "boatAntiFlip", false)
toggleRow(pages.Boat, "Boat Noclip", "Permite que el barco atraviese obstáculos.", "boatNoclip", false, setBoatNoclip)
toggleRow(pages.Boat, "Auto Reparar Barco", "Repone piezas faltantes y recoloca piezas sueltas cuando sea posible.", "autoRepairBoat", false, function(on)
    activeStates._repairToken = (tonumber(activeStates._repairToken) or 0) + 1
    local token = activeStates._repairToken

    if not on then
        activeStates._repairSnapshot = nil
        activeStates._repairRoot = nil
        activeStates._repairBusy = false
        return
    end

    local parts, boatRoot = getBoatParts()
    if not boatRoot or #parts <= 1 then
        activeStates.autoRepairBoat = false
        toast("No encontré un barco para reparar.")
        return
    end

    local data = LP:FindFirstChild("Data")
    if not data then
        activeStates.autoRepairBoat = false
        toast("No encontré piezas reparables en este barco.")
        return
    end

    local snapshot = {}
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") and part ~= boatRoot then
            local item = data:FindFirstChild(part.Name)
            if item and (item:IsA("IntValue") or item:IsA("NumberValue")) then
                snapshot[#snapshot + 1] = {
                    part = part,
                    name = part.Name,
                    relative = boatRoot.CFrame:ToObjectSpace(part.CFrame),
                    lastAttempt = 0,
                }
            end
        end
    end

    if #snapshot == 0 then
        activeStates.autoRepairBoat = false
        toast("No encontré piezas reparables en este barco.")
        return
    end

    activeStates._repairSnapshot = snapshot
    activeStates._repairRoot = boatRoot
    toast("Auto reparación activada.")

    task.spawn(function()
        while alive and activeStates.autoRepairBoat and activeStates._repairToken == token do
            if not activeStates.autoBuildBoatBusy
                and not activeStates.autoFarm
                and not activeStates._finishBusy
                and not activeStates._repairBusy then

                activeStates._repairBusy = true

                local currentRoot = getBoatRoot() or activeStates._repairRoot
                local char = getChar()
                local hum = getHum()
                local repairData = LP:FindFirstChild("Data")

                if currentRoot and currentRoot.Parent and char and hum and repairData then
                    local tool = char:FindFirstChild("BuildingTool")
                    if not tool then
                        local backpack = LP:FindFirstChildOfClass("Backpack")
                        tool = backpack and backpack:FindFirstChild("BuildingTool")
                    end
                    if not tool then
                        local playerBuild = Workspace:FindFirstChild(LP.Name)
                        tool = playerBuild and playerBuild:FindFirstChild("BuildingTool")
                    end

                    local rf = tool and tool:FindFirstChild("RF", true)
                    local zone = getTeamSpawn()
                    local zonePart = zone and (zone:IsA("BasePart") and zone or findFirstPart(zone))
                    local repairsThisPass = 0
                    local noStock = false
                    local now = os.clock()

                    for _, entry in ipairs(activeStates._repairSnapshot or {}) do
                        if repairsThisPass >= 3 then break end

                        local expected = currentRoot.CFrame * entry.relative
                        local part = entry.part

                        if part and part.Parent then
                            -- Recover pieces that became detached but still exist.
                            local assembly = part.AssemblyRootPart or part
                            if assembly ~= currentRoot and (part.Position - expected.Position).Magnitude > 3.5 then
                                pcall(function()
                                    part.AssemblyLinearVelocity = Vector3.zero
                                    part.AssemblyAngularVelocity = Vector3.zero
                                    part.CFrame = expected
                                end)
                                repairsThisPass += 1
                            end
                        elseif now - (entry.lastAttempt or 0) >= 2.0 then
                            entry.lastAttempt = now
                            local stockObj = repairData:FindFirstChild(entry.name)
                            local available = stockObj and tonumber(stockObj.Value) or 0

                            if available > 0 and rf and rf:IsA("RemoteFunction") and zonePart then
                                local okPlace = pcall(function()
                                    rf:InvokeServer(
                                        entry.name,
                                        stockObj.Value,
                                        zonePart,
                                        zonePart.CFrame:ToObjectSpace(expected),
                                        true,
                                        expected,
                                        false
                                    )
                                end)

                                if okPlace then
                                    task.wait(0.08)

                                    -- Re-link the snapshot entry to the newly placed part.
                                    local params = OverlapParams.new()
                                    params.FilterType = Enum.RaycastFilterType.Exclude
                                    params.FilterDescendantsInstances = {char}
                                    params.MaxParts = 40

                                    local okNear, nearby = pcall(function()
                                        return Workspace:GetPartBoundsInRadius(expected.Position, 2.5, params)
                                    end)

                                    if okNear and nearby then
                                        local nearest, distance
                                        for _, candidate in ipairs(nearby) do
                                            if candidate:IsA("BasePart") and candidate.Name == entry.name then
                                                local d = (candidate.Position - expected.Position).Magnitude
                                                if not distance or d < distance then
                                                    nearest, distance = candidate, d
                                                end
                                            end
                                        end
                                        if nearest then entry.part = nearest end
                                    end

                                    repairsThisPass += 1
                                end
                            else
                                noStock = true
                            end
                        end
                    end

                    if noStock then
                        local lastNotice = tonumber(activeStates._repairNoStockAt) or 0
                        if now - lastNotice >= 15 then
                            activeStates._repairNoStockAt = now
                            toast("Faltan piezas de repuesto para continuar reparando.")
                        end
                    end
                end

                activeStates._repairBusy = false
            end

            for _ = 1, 5 do
                if not alive or not activeStates.autoRepairBoat or activeStates._repairToken ~= token then break end
                task.wait(0.2)
            end
        end

        activeStates._repairBusy = false
    end)
end)

toggleRow(pages.Boat, "Protect Boat", "Ayuda a reducir golpes y daños durante el recorrido.", "protectBoat", false, setBoatProtection)
toggleRow(pages.Boat, "Infinite Fuel", "Mantiene el combustible y la energía del barco.", "infiniteFuel", false)

actionButton(pages.Boat, "Propeller / Thruster Control", "Activa la propulsión disponible del barco.", function()
    local n = activateThrusters()
    toast(n > 0 and ("Propulsores activados: " .. n) or "No detecté controles de propulsor compatibles")
end, "ACTIVAR")

toggleRow(pages.Boat, "Auto Activate Thrusters", "Mantiene la propulsión del barco activada automáticamente.", "autoThrusters", false)

toggleRow(pages.Boat, "Auto Sit", "Busca un asiento cercano del barco y vuelve a sentarte automáticamente.", "autoSit", false)
toggleRow(pages.Boat, "Seat Lock", "Recuerda tu último asiento e intenta volver a sentarte si un obstáculo te expulsa.", "seatLock", false)
toggleRow(pages.Boat, "Anti Seat", "Evita permanecer sentado cuando no quieras usar asientos.", "antiSeat", false)

actionButton(pages.Boat, "Load Build / Auto Load Slot", "Carga rápidamente una construcción guardada.", function()
    openModal("Load Build / Slots", function()
        local buttons = findGameButtons({"load", "slot", "cargar"})
        if #buttons == 0 then
            modalButton("No encontré botones Load/Slot", "Abre primero el menú de guardar/cargar del juego.", function() end)
            return
        end
        for i, item in ipairs(buttons) do
            modalButton(string.format("%02d · %s", i, item.label ~= "" and item.label or item.button.Name), "Cargar esta opción", function()
                activateGuiButton(item.button)
                closeModal()
            end)
        end
    end)
end, "ABRIR SLOTS")

actionButton(pages.Boat, "Auto Save Build", "Guarda rápidamente tu construcción actual.", function()
    toast(autoSaveBuild() and "Save activado" or "No pude activar Save")
end, "GUARDAR")

actionButton(pages.Boat, "Instant Launch", "Carga y lanza el barco rápidamente.", function()
    toast(instantLaunch() and "Launch ejecutado" or "No pude ejecutar el lanzamiento")
end, "LANZAR")

-- MOVEMENT
makeSection(pages.Movement, "MOVIMIENTO", "Controles del personaje y protección básica.")

toggleRow(pages.Movement, "Noclip", "Desactiva colisiones de las partes del personaje mientras esté activo.", "noclip", false, setNoclip)

toggleRow(pages.Movement, "Anti Water / Anti Damage", "Reduce el daño de agua y otros peligros y ayuda a volver a una zona segura.", "antiHazard", true, setAntiHazard)
task.spawn(setAntiHazard, true)
toggleRow(pages.Movement, "Anti Void", "Si caes por debajo del límite del mapa, vuelve a la última posición segura o a tu zona de equipo.", "antiVoid", false)
toggleRow(pages.Movement, "No Fall / Anti Fall", "Limita la velocidad de caída para reducir caídas bruscas y mantener una recuperación segura.", "noFall", false)
toggleRow(pages.Movement, "Infinite Jump", "Permite volver a saltar en el aire usando Espacio.", "infiniteJump", false)
toggleRow(pages.Movement, "Player Fly", "Vuelo del personaje separado del Boat Fly: WASD, Espacio y Ctrl.", "playerFly", false, function(on)
    if not on then clearPlayerFlyObjects() end
end)

sliderRow(pages.Movement, "Player Fly Speed", "Velocidad usada únicamente por Player Fly.", 30, 300, 90, 10, function(v)
    ENV.__HX_playerFlySpeed = v
end)

sliderRow(pages.Movement, "Gravity", "Ajusta la gravedad del juego.", 0, 300, math.floor(ENV.__HX_initialGravity + 0.5), 5, function(v)
    Workspace.Gravity = v
end)

sliderRow(pages.Movement, "Character Speed", "Ajusta la velocidad al caminar.", 16, 150, 16, 1, function(v)
    walkSpeed = v
    local hum = getHum()
    if hum then pcall(function() hum.WalkSpeed = v end) end
end)
sliderRow(pages.Movement, "Character Jump", "Ajusta la potencia de salto.", 50, 250, 50, 5, function(v)
    jumpPower = v
    local hum = getHum()
    if hum then
        pcall(function() hum.JumpPower = v end)
        pcall(function() hum.JumpHeight = math.max(7.2, v / 7) end)
    end
end)

-- TELEPORT
makeSection(pages.Teleport, "TELEPORT", "Stages, cofre, posiciones guardadas y jugadores.")

actionButton(pages.Teleport, "Teleport por zonas", "Muestra las zonas disponibles para teletransportarte.", function()
    openModal("Zonas detectadas", function()
        local stages = getStageTargets()
        if #stages == 0 then
            modalButton("No se encontraron stages", "El mapa todavía puede estar cargando.", function() end)
            return
        end
        for i, info in ipairs(stages) do
            modalButton(string.format("%02d  ·  %s", i, info.name), "Ir a esta zona", function()
                tpToPart(info.part, Vector3.new(0, 3, 0))
                closeModal()
            end)
        end
        local chest = findChestPart()
        if chest then
            modalButton("TREASURE / COFRE FINAL", "Teleport al final del recorrido", function()
                tpToPart(chest, Vector3.new(0, 3, 0))
                closeModal()
            end)
        end
    end)
end, "VER ZONAS")

actionButton(pages.Teleport, "Teleport al cofre", "Localiza el Golden Chest / Treasure del mapa y te lleva a él.", function()
    local chest = findChestPart()
    if chest then
        tpToPart(chest, Vector3.new(0, 3, 0))
        touchPart(chest)
    else
        toast("No encontré el cofre final")
    end
end, "IR AL COFRE")

actionButton(pages.Teleport, "Teleport Last Stage", "Te lleva a la última zona antes del tesoro.", function()
    local stages = getStageTargets()
    local last = stages[#stages]
    if last then tpToPart(last.part, Vector3.new(0, 3, 0)) else toast("No encontré stages") end
end, "ÚLTIMO STAGE")

actionButton(pages.Teleport, "Return To Team", "Te lleva de vuelta a la zona de tu equipo.", function()
    local zone = getTeamSpawn()
    if zone then tpToPart(zone, Vector3.new(0, 4, 0)) else toast("No pude detectar la zona de tu equipo") end
end, "VOLVER")

actionButton(pages.Teleport, "Teleport To Boat", "Te lleva de vuelta a tu barco.", function()
    local boat = getBoatRoot()
    if boat then tpToCFrame(boat.CFrame * CFrame.new(0, 5, 0)) else toast("No detecté un barco cercano") end
end, "IR AL BARCO")

actionButton(pages.Teleport, "Teleport To Seat", "Te lleva al asiento de tu barco e intenta sentarte.", function()
    local seat = getSeat() or lastSeat or getNearestSeat(500)
    local hum = getHum()
    if not seat or not hum then return toast("No detecté un asiento") end
    tpToCFrame(seat.CFrame * CFrame.new(0, 2.5, 0))
    task.wait(0.15)
    pcall(function() seat:Sit(hum) end)
    lastSeat = seat
end, "SENTARSE")

toggleRow(pages.Teleport, "Click TP", "Con el toggle activo, haz clic en el mundo para teletransportarte al punto seleccionado.", "clickTP", false)
toggleRow(pages.Teleport, "Tween TP", "Convierte los teleports del hub en desplazamientos progresivos en vez de instantáneos.", "tweenTP", false)
sliderRow(pages.Teleport, "Tween TP Speed", "Velocidad del desplazamiento progresivo.", 50, 500, 180, 10, function(v)
    ENV.__HX_tweenTPSpeed = v
    ENV.__BABFT_TWEEN_SPEED = v
end)

actionButton(pages.Teleport, "Teleport To Quests / NPCs", "Muestra misiones y NPC disponibles para teletransportarte.", function()
    openModal("Quests / NPCs", function()
        local seen, count = {}, 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            if count >= 50 then break end
            if (d:IsA("Model") or d:IsA("BasePart")) and containsAny(d.Name, {"quest", "npc", "mission", "giver"}) then
                local part = d:IsA("BasePart") and d or findFirstPart(d)
                if part and not seen[d] then
                    seen[d] = true
                    count += 1
                    modalButton(d.Name, "Ir a este objetivo", function()
                        tpToPart(part, Vector3.new(0, 3, 0))
                        closeModal()
                    end)
                end
            end
        end
        if count == 0 then modalButton("No se detectaron NPCs/quests", "No hay objetivos disponibles.", function() end) end
    end)
end, "BUSCAR")

actionButton(pages.Teleport, "Guardar posición", "Guarda tu posición actual para volver a ella más tarde.", function()
    local root = getRoot()
    if not root then return toast("Personaje no disponible") end
    local name = (ENV.__HX_LANG == "en" and "Position " or "Posición ") .. tostring(#savedPositions + 1)
    savedPositions[#savedPositions + 1] = {name = name, cframe = serializeCFrame(root.CFrame)}
    savePositionsToDisk()
    toast(name .. " guardada")
end, "GUARDAR")

actionButton(pages.Teleport, "Posiciones guardadas", "Abre la lista para teletransportarte o eliminar posiciones.", function()
    openModal("Posiciones guardadas", function()
        if #savedPositions == 0 then
            modalButton("No hay posiciones", "Usa “Guardar posición” primero.", function() end)
            return
        end
        for i, item in ipairs(savedPositions) do
            modalButton(item.name or ("Posición " .. i), "Click: teletransportar", function()
                local cf = deserializeCFrame(item.cframe)
                if cf then tpToCFrame(cf) end
                closeModal()
            end)
        end
        modalButton("Eliminar todas", "Borra todas las posiciones guardadas.", function()
            table.clear(savedPositions)
            savePositionsToDisk()
            closeModal()
            toast("Posiciones eliminadas")
        end, true)
    end)
end, "ABRIR")

actionButton(pages.Teleport, "Teleport a jugadores", "Busca jugadores y usa acciones rápidas sobre ellos.", function()
    local function openPlayerActions(plr)
        openModal(plr.DisplayName .. "  @" .. plr.Name, function()
            modalButton("Teleport", "Ir junto a este jugador", function()
                local char = plr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then tpToCFrame(root.CFrame * CFrame.new(3, 0, 0)) end
                closeModal()
            end)
            modalButton("Spectate Player", "Poner la cámara sobre este jugador", function()
                local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    Camera = Workspace.CurrentCamera or Camera
                    if Camera then Camera.CameraSubject = hum end
                end
                closeModal()
            end)
            modalButton("Follow Player", "Seguir automáticamente a este jugador", function()
                followTarget = plr
                activeStates.followPlayer = true
                closeModal()
                toast("Follow activado: " .. plr.DisplayName)
            end)
            modalButton("Bring Boat To Player", "Mueve tu barco cerca de este jugador.", function()
                local targetRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local boat = getBoatRoot()
                if targetRoot and boat then
                    boat.AssemblyLinearVelocity = Vector3.zero
                    boat.AssemblyAngularVelocity = Vector3.zero
                    boat.CFrame = targetRoot.CFrame * CFrame.new(8, 2, 0)
                    toast("Boat movido")
                else
                    toast("No pude detectar jugador/barco")
                end
                closeModal()
            end)
            modalButton("Detener Follow / Spectate", "Vuelve la cámara a tu personaje y detiene el seguimiento.", function()
                followTarget = nil
                activeStates.followPlayer = false
                local hum = getHum()
                Camera = Workspace.CurrentCamera or Camera
                if hum and Camera then Camera.CameraSubject = hum end
                closeModal()
            end, true)
        end)
    end

    openModal("Jugadores", function()
        local rows = {}
        modalSearchBox("Buscar jugador...", function(query)
            query = lower(query)
            for plr, button in pairs(rows) do
                local hay = lower(plr.DisplayName .. " " .. plr.Name)
                button.Visible = query == "" or string.find(hay, query, 1, true) ~= nil
            end
        end)
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                count += 1
                local b = modalButton(plr.DisplayName, "@" .. plr.Name, function() openPlayerActions(plr) end)
                rows[plr] = b
            end
        end
        if count == 0 then modalButton("No hay otros jugadores", "Servidor vacío.", function() end) end
    end)
end, "JUGADORES")

-- VISUALS
makeSection(pages.Visuals, "VISUALES", "Resalta jugadores y bloques cercanos.")

toggleRow(pages.Visuals, "ESP de jugadores", "Resalta a los demás jugadores y muestra sus nombres.", "playerESP", false, function(on)
    if on then refreshPlayerESP() else clearPlayerESP() end
end)

toggleRow(pages.Visuals, "ESP de bloques", "Resalta los bloques cercanos.", "blockESP", false, function(on)
    if on then refreshBlockESP() else clearBlockESP() end
end)

makeSection(pages.Visuals, "RENDIMIENTO", "Opciones para mejorar el rendimiento visual.")
toggleRow(pages.Visuals, "FPS Booster", "Reduce efectos gráficos para mejorar los FPS.", "fpsBooster", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Hide Other Boats", "Oculta los barcos de otros jugadores.", "hideOtherBoats", false, function(on) if on then applyHideOtherBoats() else restoreHiddenBoats() end end)
toggleRow(pages.Visuals, "Hide Other Players", "Oculta a los demás jugadores.", "hideOtherPlayers", false, function(on) if on then applyHideOtherPlayers() else restoreHiddenPlayers() end end)
toggleRow(pages.Visuals, "Remove Water Effects", "Reduce los efectos visuales del agua.", "removeWaterEffects", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Remove Particles", "Reduce partículas y efectos visuales.", "removeParticles", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Disable Shadows", "Desactiva las sombras para mejorar el rendimiento.", "disableShadows", false, function() applyPerformanceState() end)
toggleRow(pages.Visuals, "Low Graphics", "Reduce la calidad gráfica para aumentar los FPS.", "lowGraphics", false, function() applyPerformanceState() end)

-- SERVER
makeSection(pages.Server, "SERVIDOR", "Reconexión y cambio de servidor.")

toggleRow(pages.Server, "Auto Rejoin", "Vuelve a entrar automáticamente si pierdes la conexión.", "autoRejoin", false)
toggleRow(pages.Server, "Anti AFK", "Evita que te expulsen por inactividad.", "antiAFK", false)

actionButton(pages.Server, "Rejoin", "Vuelve a entrar al servidor actual.", rejoin, "REJOIN")
actionButton(pages.Server, "Server Hop", "Busca otro servidor público con espacio disponible.", serverHop, "SERVER HOP")
actionButton(pages.Server, "Low Player Server", "Busca entre los servidores públicos disponibles y entra al de menor población encontrado.", lowPlayerServer, "BUSCAR")

selectPage("Farm")

--====================================================
-- Runtime loops (optimized)
--====================================================
ENV.__HX_lastNoclipUpdate = 0
ENV.__HX_lastMovementUpdate = 0
ENV.__HX_lastSafetySample = 0

track(RunService.Stepped:Connect(function()
    if not alive or not activeStates.noclip then return end
    local now = os.clock()
    if now - ENV.__HX_lastNoclipUpdate < 0.12 then return end
    ENV.__HX_lastNoclipUpdate = now

    local char = getChar()
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                if characterCollisionCache[d] == nil then characterCollisionCache[d] = d.CanCollide end
                d.CanCollide = false
            end
        end
    end
end))

track(RunService.Heartbeat:Connect(function()
    if not alive then return end
    local now = os.clock()
    local hum = getHum()
    local root = getRoot()

    -- Character stats do not need to be rewritten 60 times per second.
    if hum and now - ENV.__HX_lastMovementUpdate >= 0.20 then
        ENV.__HX_lastMovementUpdate = now
        pcall(function() if hum.WalkSpeed ~= walkSpeed then hum.WalkSpeed = walkSpeed end end)
        pcall(function() if hum.JumpPower ~= jumpPower then hum.JumpPower = jumpPower end end)
        local desiredJumpHeight = math.max(7.2, jumpPower / 7)
        pcall(function() if math.abs(hum.JumpHeight - desiredJumpHeight) > 0.05 then hum.JumpHeight = desiredJumpHeight end end)
    end

    if hum and root then
        -- Safety features are cheap but do not need Heartbeat frequency.
        -- ~8 Hz is responsive enough and removes dozens of checks per second.
        if now - ENV.__HX_lastSafetySample >= 0.12 then
            ENV.__HX_lastSafetySample = now

            if not activeStates._farmTeleporting and hum.Health > 0 and hum.FloorMaterial ~= Enum.Material.Air and root.Position.Y > Workspace.FallenPartsDestroyHeight + 35 then
                ENV.__HX_safeCFrame = root.CFrame
            end

            if activeStates.antiHazard and not activeStates._farmTeleporting then
                local damaged = ENV.__HX_lastHealth and hum.Health < ENV.__HX_lastHealth
                if damaged and ENV.__HX_safeCFrame then
                    root.CFrame = ENV.__HX_safeCFrame * CFrame.new(0, 3, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                    pcall(function() hum.Health = hum.MaxHealth end)
                end
            end

            if activeStates.antiVoid and not activeStates._farmTeleporting and root.Position.Y <= Workspace.FallenPartsDestroyHeight + 28 then
                local rescue = ENV.__HX_safeCFrame
                if not rescue then
                    local teamSpawn = getTeamSpawn()
                    rescue = teamSpawn and (teamSpawn.CFrame * CFrame.new(0, 5, 0)) or CFrame.new(0, 50, 0)
                else
                    rescue = rescue * CFrame.new(0, 4, 0)
                end
                root.AssemblyLinearVelocity = Vector3.zero
                root.CFrame = rescue
            end

            if activeStates.noFall and root.AssemblyLinearVelocity.Y < -55 then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, -24, v.Z)
            end
            ENV.__HX_lastHealth = hum.Health
        end
    else
        ENV.__HX_lastHealth = nil
    end

    if activeStates.playerFly and root then
        ensurePlayerFlyObjects(root)
        local dir = getMoveVector()
        playerFlyObjects.velocity.Velocity = dir * ENV.__HX_playerFlySpeed
        Camera = Workspace.CurrentCamera or Camera
        if Camera then
            local look = Camera.CFrame.LookVector
            local horizontal = Vector3.new(look.X, 0, look.Z)
            if horizontal.Magnitude > 0.01 then
                playerFlyObjects.gyro.CFrame = CFrame.lookAt(root.Position, root.Position + horizontal.Unit)
            end
        end
    elseif next(playerFlyObjects) then
        clearPlayerFlyObjects()
    end

    if activeStates.followPlayer and followTarget and followTarget.Parent and root then
        local targetRoot = followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local desired = targetRoot.CFrame * CFrame.new(3, 0, 3)
            root.CFrame = root.CFrame:Lerp(desired, 0.22)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    elseif activeStates.followPlayer and (not followTarget or not followTarget.Parent) then
        activeStates.followPlayer = false
        followTarget = nil
    end

    local seatFeatureActive = activeStates.antiSeat or activeStates.seatLock or activeStates.autoSit
        or activeStates.boatFly or activeStates.ENV.__HX_boatSpeed or activeStates.boatAntiFlip
        or activeStates.autoPilot or activeStates.boatStabilizer

    if hum and seatFeatureActive then
        local seatNow = hum.SeatPart
        if seatNow then lastSeat = seatNow end
        if activeStates.antiSeat and seatNow then
            hum.Sit = false
            hum.Jump = true
        elseif not seatNow and now - ENV.__HX_lastSeatAttempt > 0.8 then
            if activeStates.seatLock and lastSeat and lastSeat.Parent then
                ENV.__HX_lastSeatAttempt = now
                pcall(function() lastSeat:Sit(hum) end)
            elseif activeStates.autoSit then
                local candidate = lastSeat and lastSeat.Parent and lastSeat or getNearestSeat(220)
                if candidate then
                    ENV.__HX_lastSeatAttempt = now
                    lastSeat = candidate
                    pcall(function() candidate:Sit(hum) end)
                end
            end
        end
    end

    local boatRealtime = activeStates.boatFly or activeStates.ENV.__HX_boatSpeed or activeStates.boatAntiFlip
        or activeStates.autoPilot or activeStates.boatStabilizer
    local seat = boatRealtime and getSeat() or nil

    if activeStates.boatFly and seat then
        ensureBoatFlyObjects(seat)
        local dir = getMoveVector()
        flyObjects.velocity.Velocity = dir * ENV.__HX_boatSpeed
        Camera = Workspace.CurrentCamera or Camera
        if Camera then
            local look = Camera.CFrame.LookVector
            local horizontal = Vector3.new(look.X, 0, look.Z)
            if horizontal.Magnitude > 0.01 then
                flyObjects.gyro.CFrame = CFrame.lookAt(seat.Position, seat.Position + horizontal.Unit)
            end
        end
    elseif activeStates.boatFly and not seat then
        destroyFlyObjects()
    elseif not activeStates.boatFly and next(flyObjects) then
        destroyFlyObjects()
    end

    if activeStates.ENV.__HX_boatSpeed and seat and not activeStates.boatFly then
        local throttle = 0
        if seat:IsA("VehicleSeat") then throttle = seat.ThrottleFloat end
        if pressed.W then throttle = 1 elseif pressed.S then throttle = -1 end
        if throttle ~= 0 then
            local look = seat.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then seat.AssemblyLinearVelocity = flat.Unit * ENV.__HX_boatSpeed * throttle end
        end
    end

    -- Critical optimization: never search the Workspace for a boat when no
    -- realtime boat feature is enabled.
    local boatRoot = boatRealtime and getBoatRoot() or nil
    if boatRoot and not activeStates.boatFly then
        if activeStates.boatAntiFlip and boatRoot.CFrame.UpVector.Y < 0.35 then
            local look = boatRoot.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            boatRoot.AssemblyAngularVelocity = Vector3.zero
            boatRoot.CFrame = CFrame.lookAt(boatRoot.Position, boatRoot.Position + flat.Unit)
        end

        if activeStates.autoPilot then
            local chest = findChestPart()
            local pos = chest and chest.Position
            if pos then
                local delta = pos - boatRoot.Position
                local flat = Vector3.new(delta.X, 0, delta.Z)
                if flat.Magnitude > 10 then
                    boatRoot.AssemblyLinearVelocity = flat.Unit * ENV.__HX_boatSpeed + Vector3.new(0, math.clamp(delta.Y * 0.6, -25, 25), 0)
                    local gyro = ensureBoatGyro(boatRoot)
                    gyro.CFrame = CFrame.lookAt(boatRoot.Position, boatRoot.Position + flat.Unit)
                else
                    boatRoot.AssemblyLinearVelocity = Vector3.zero
                end
            end
        elseif activeStates.boatStabilizer then
            local look = boatRoot.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            local gyro = ensureBoatGyro(boatRoot)
            gyro.CFrame = CFrame.lookAt(boatRoot.Position, boatRoot.Position + flat.Unit)
        elseif next(boatUtilityObjects) then
            clearBoatUtilityObjects()
        end
    elseif not boatRealtime and next(boatUtilityObjects) then
        clearBoatUtilityObjects()
    end
end))

-- Lightweight maintenance loop. Expensive map scans are cached inside the
-- feature functions and this loop is intentionally slower than the old build.
task.spawn(function()
    while alive do
        if activeStates.autoCollect then pcall(doAutoCollect) end
        if activeStates.playerESP then pcall(refreshPlayerESP) end
        if activeStates.boatNoclip then pcall(setBoatNoclip, true) end
        if activeStates.protectBoat then pcall(setBoatProtection, true) end
        if activeStates.infiniteFuel then pcall(refillFuel) end
        if activeStates.hideOtherPlayers then pcall(applyHideOtherPlayers) end

        local gold = getGoldValue()
        if gold ~= nil then
            if ENV.__HX_sessionGoldStart == nil then ENV.__HX_sessionGoldStart = gold end
            if ENV.__HX_lastKnownGold ~= nil and gold > ENV.__HX_lastKnownGold then ENV.__HX_sessionGoldEarned += gold - ENV.__HX_lastKnownGold end
            ENV.__HX_lastKnownGold = gold
        end
        local elapsed = getFarmElapsed()
        local perMinute = elapsed > 0 and (ENV.__HX_sessionGoldEarned / elapsed) * 60 or 0
        local perHour = perMinute * 60
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        farmStatsDesc.Text = string.format(
            ENV.__HX_LANG == "en"
                and "Gold earned: +%s   ·   Runs: %d\nFarm: %02d:%02d   ·   Gold/min: %.1f   ·   Est. Gold/h: %.0f"
                or "Oro ganado: +%s   ·   Recorridos: %d\nFarmeo: %02d:%02d   ·   Oro/min: %.1f   ·   Est. Oro/h: %.0f",
            tostring(ENV.__HX_sessionGoldEarned), runsCompleted, mins, secs, perMinute, perHour
        )
        task.wait(2.0)
    end
end)

task.spawn(function()
    while alive do
        if activeStates.blockESP then pcall(refreshBlockESP) end
        if activeStates.autoThrusters then pcall(activateThrusters) end
        if activeStates.hideOtherBoats then pcall(applyHideOtherBoats) end
        if activeStates.autoQuest then
            if not selectedQuestTarget or not selectedQuestTarget.Parent then
                local quests = getQuestTargets()
                selectedQuestTarget = quests[1]
            end
            if selectedQuestTarget then pcall(interactQuestPrompt, selectedQuestTarget) end
        end
        task.wait(6.0)
    end
end)

-- Process newly-created hazards/effects incrementally instead of rescanning the
-- entire Workspace every few seconds.
track(Workspace.DescendantAdded:Connect(function(d)
    if not alive then return end

    if activeStates.antiHazard and d:IsA("BasePart") and containsAny(d.Name, {"water", "lava", "acid", "toxic", "damage", "kill", "hazard"}) then
        if hazardTouchCache[d] == nil then hazardTouchCache[d] = d.CanTouch end
        pcall(function() d.CanTouch = false end)
    end

    local disableParticles = activeStates.removeParticles or activeStates.fpsBooster
    if disableParticles and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")) then
        if particleCache[d] == nil then particleCache[d] = d.Enabled end
        pcall(function() d.Enabled = false end)
    end

    local disableShadows = activeStates.disableShadows or activeStates.fpsBooster or activeStates.lowGraphics
    if disableShadows and d:IsA("BasePart") then
        if shadowCache[d] == nil then shadowCache[d] = d.CastShadow end
        pcall(function() d.CastShadow = false end)
    end

    if activeStates.autoCollect and #autoCollectTargets < 180 then
        if (d:IsA("BasePart") and containsAny(d.Name, {"gold", "collect", "pickup", "treasure", "chest"})) or d:IsA("ProximityPrompt") then
            autoCollectTargets[#autoCollectTargets + 1] = d
        end
    end
end))

track(LP.Idled:Connect(function()
    if not alive or not activeStates.antiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

track(Players.PlayerAdded:Connect(function(plr)
    track(plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if activeStates.playerESP then refreshPlayerESP() end
    end))
end))

track(Players.PlayerRemoving:Connect(function(plr)
    if followTarget == plr then
        followTarget = nil
        activeStates.followPlayer = false
        local hum = getHum()
        Camera = Workspace.CurrentCamera or Camera
        if hum and Camera then pcall(function() Camera.CameraSubject = hum end) end
    end
    local o = espPlayerObjects[plr]
    if o then
        if o.highlight then pcall(function() o.highlight:Destroy() end) end
        if o.billboard then pcall(function() o.billboard:Destroy() end) end
        espPlayerObjects[plr] = nil
    end
end))

track(LP.CharacterAdded:Connect(function()
    table.clear(characterCollisionCache)
    ENV.__HX_safeCFrame = nil
    ENV.__HX_lastHealth = nil
    lastSeat = nil
    worldCache.nearestSeat = nil
    worldCache.boatRoot = nil
    worldCache.seatAt = 0
    worldCache.boatRootAt = 0
    clearPlayerFlyObjects()
    task.wait(1)
end))

pcall(function()
    track(GuiService.ErrorMessageChanged:Connect(function(msg)
        if alive and activeStates.autoRejoin and msg and msg ~= "" then
            task.wait(1.5)
            rejoin()
        end
    end))
end)

--====================================================
-- Minimize / close / cleanup
--====================================================
local function cleanup()
    if not alive then return end
    alive = false
    for k in pairs(activeStates) do activeStates[k] = false end

    setNoclip(false)
    setAntiHazard(false)
    setBoatNoclip(false)
    setBoatProtection(false)
    destroyFlyObjects()
    clearPlayerFlyObjects()
    clearBoatUtilityObjects()
    clearPlayerESP()
    clearBlockESP()
    restoreHiddenPlayers()
    restoreHiddenBoats()
    applyPerformanceState()
    Workspace.Gravity = ENV.__HX_initialGravity
    ENV.__BABFT_TWEEN_SPEED = nil
    followTarget = nil

    local hum = getHum()
    if hum then
        pcall(function() hum.WalkSpeed = 16 end)
        pcall(function() hum.JumpPower = 50 end)
        pcall(function() hum.JumpHeight = 7.2 end)
        Camera = Workspace.CurrentCamera or Camera
        if Camera then pcall(function() Camera.CameraSubject = hum end) end
    end

    disconnectAll()

    for _, fn in ipairs(cleanupTasks) do pcall(fn) end
    table.clear(cleanupTasks)

    if Gui then pcall(function() Gui:Destroy() end) end
    if ENV.__BABFT_NIGHTFALL_CLEANUP == cleanup then ENV.__BABFT_NIGHTFALL_CLEANUP = nil end
end

ENV.__BABFT_NIGHTFALL_CLEANUP = cleanup

track(Minimize.Activated:Connect(function()
    if Main:GetAttribute("Minimizing") or Main:GetAttribute("Restoring") then return end
    Main:SetAttribute("Minimizing", true)
    closeModal()

    -- Stable minimize: no Position/Size/Rotation changes.
    -- The panel fades as one CanvasGroup, preserving its dragged location.
    TweenService:Create(
        Main,
        TweenInfo.new(0.17, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
        {GroupTransparency = 1}
    ):Play()
    TweenService:Create(
        PanelShell,
        TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
        {BackgroundTransparency = 0.45}
    ):Play()

    task.delay(0.165, function()
        if alive then
            Main.Visible = false
            Main.GroupTransparency = 0
            PanelShell.BackgroundTransparency = 0
            Main:SetAttribute("Minimizing", false)

            Bubble.Size = UDim2.fromOffset(46, 46)
            Bubble.ImageTransparency = 0.18
            Bubble.BackgroundTransparency = 0.14
            Bubble.Visible = true

            TweenService:Create(
                Bubble,
                TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {
                    Size = UDim2.fromOffset(60, 60),
                    ImageTransparency = 0,
                    BackgroundTransparency = 0.04
                }
            ):Play()
        end
    end)
end))

Main:SetAttribute("Closing", false)
Main:SetAttribute("Minimizing", false)
Main:SetAttribute("Restoring", false)

track(Close.Activated:Connect(function()
    if Main:GetAttribute("Closing") or not alive then return end
    Main:SetAttribute("Closing", true)
    closeModal()

    TweenService:Create(
        Main,
        TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
        {GroupTransparency = 1}
    ):Play()
    TweenService:Create(
        PanelShell,
        TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
        {BackgroundTransparency = 0.60}
    ):Play()

    task.delay(0.20, cleanup)
end))

-- Stable entrance: fade the entire UI without moving or resizing the panel.
Main.GroupTransparency = 1
PanelShell.BackgroundTransparency = 0.55

TweenService:Create(
    Main,
    TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    {GroupTransparency = 0}
):Play()
TweenService:Create(
    PanelShell,
    TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    {BackgroundTransparency = 0}
):Play()

toast("Anti Water / Anti Damage está ACTIVADO por defecto. HX Boat usa el modo optimizado.")
