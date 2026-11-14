local GENV = (getgenv and getgenv()) or shared or _G
local SLOT = "__VOXEL_ESP_V1"
local GUI_NAME = "VOXEL_ESP_GUI"
local BASE = "https://raw.githubusercontent.com/ToiletStarter/RblxGameScripts/refs/heads/main/libs/"

local previous = GENV[SLOT]
if type(previous) == "table" and type(previous.unload) == "function" then
    pcall(previous.unload, false)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer

local session = {
    unloaded = false,
    connections = {},
    rootConnections = {},
    roots = {},
    caches = {},
    trajectories = {},
    widgets = {},
    configStatus = "Starting",
    state = {
        players = true,
        boxes = true,
        names = true,
        health = true,
        distance = true,
        skeleton = false,
        tracers = false,
        arrows = true,
        flags = false,
        visibility = false,
        hideOccluded = false,
        teamCheck = false,
        playerRange = 3000,
        playerBoxRange = 3000,
        playerNameRange = 3000,
        playerHealthRange = 3000,
        playerDistanceRange = 3000,
        playerSkeletonRange = 1800,
        playerTracerRange = 1800,
        playerArrowRange = 3000,
        boxStyle = "corner",
        playerColor = Color3.fromRGB(110, 205, 255),
        playerNameColor = Color3.fromRGB(235, 240, 250),
        playerDistanceColor = Color3.fromRGB(170, 185, 205),
        playerSkeletonColor = Color3.fromRGB(160, 215, 255),
        playerTracerColor = Color3.fromRGB(110, 205, 255),
        playerArrowColor = Color3.fromRGB(110, 205, 255),
        arrowColorMode = "gradient",
        arrowNearColor = Color3.fromRGB(110, 235, 165),
        arrowFarColor = Color3.fromRGB(255, 105, 120),
        visibleColor = Color3.fromRGB(110, 235, 165),
        hiddenColor = Color3.fromRGB(255, 105, 120),
        world = false,
        worldBoxes = false,
        worldNames = true,
        worldDistance = false,
        worldTracers = false,
        worldHideOccluded = false,
        worldRange = 1200,
        worldLimit = 32,
        containers = false,
        containerRange = 1000,
        containerColor = Color3.fromRGB(255, 205, 90),
        exfil = false,
        exfilRange = 2500,
        exfilColor = Color3.fromRGB(120, 235, 195),
        airdrops = false,
        airdropRange = 2500,
        airdropColor = Color3.fromRGB(255, 150, 80),
        zombies = false,
        zombieBoxes = true,
        zombieNames = true,
        zombieHealth = true,
        zombieDistance = true,
        zombieRange = 1800,
        zombieColor = Color3.fromRGB(255, 105, 120),
        loot = false,
        lootWeapons = false,
        lootAmmo = false,
        lootMedical = false,
        lootFood = false,
        lootDropped = false,
        lootOther = false,
        lootBoxes = false,
        lootNames = true,
        lootDistance = false,
        lootTracers = false,
        lootHideOccluded = false,
        lootRange = 650,
        lootLimit = 36,
        lootColor = Color3.fromRGB(190, 150, 255),
        lootWeaponColor = Color3.fromRGB(255, 125, 95),
        lootAmmoColor = Color3.fromRGB(255, 210, 100),
        lootMedicalColor = Color3.fromRGB(120, 235, 165),
        lootFoodColor = Color3.fromRGB(235, 190, 110),
        lootDroppedColor = Color3.fromRGB(255, 135, 95),
        menuKey = "RightShift",
        customCursor = false,
        fullbright = false,
        combatPreview = false,
        combatFov = 240,
        combatRange = 1500,
        combatVisibleOnly = true,
        combatFriends = false,
        combatAllies = false,
        combatCard = true,
        combatBrackets = true,
        combatLine = true,
        combatLabel = true,
        combatDistance = true,
        combatHealth = true,
        trajectoryOn = false,
        trajectoryLimit = 16,
        trajectoryLifetime = 2,
        trajectoryColor = Color3.fromRGB(255, 180, 95),
    },
}
GENV[SLOT] = session

local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
}
local lightingGuard = false

local esp
local ui
local window
local menuAction
local statusLabel
local countLabel
local configLabel
local combatStatusLabel

local function track(connection)
    if connection then
        session.connections[#session.connections + 1] = connection
    end
    return connection
end

local function disconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function make(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties or {}) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function setLabel(label, value)
    if type(label) == "table" and type(label.Set) == "function" then
        label:Set(value)
        return
    end
    pcall(function()
        label.Text = tostring(value)
    end)
end

local function encode(value)
    if typeof(value) == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    end
    if type(value) == "table" then
        local result = {}
        for key, child in pairs(value) do
            result[key] = encode(child)
        end
        return result
    end
    return value
end

local function decode(value)
    if type(value) ~= "table" then
        return value
    end
    if value.__type == "Color3" then
        return Color3.new(
            math.clamp(tonumber(value.r) or 1, 0, 1),
            math.clamp(tonumber(value.g) or 1, 0, 1),
            math.clamp(tonumber(value.b) or 1, 0, 1)
        )
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = decode(child)
    end
    return result
end

local function stateCopy()
    return decode(encode(session.state))
end

local CONFIG_DIR = "voxel_esp"
local CONFIG_FILE = CONFIG_DIR .. "/default.json"
local AUTOLOAD_FILE = CONFIG_DIR .. "/autoload.txt"

local function ensureConfigFolder()
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(CONFIG_DIR) then
        pcall(makefolder, CONFIG_DIR)
    end
end

local function configPath()
    if type(isfile) == "function" and type(readfile) == "function" and isfile(AUTOLOAD_FILE) then
        local ok, name = pcall(readfile, AUTOLOAD_FILE)
        if ok and type(name) == "string" then
            local clean = name:gsub("[^%w_%-]", "")
            if clean ~= "" then
                return CONFIG_DIR .. "/" .. clean .. ".json"
            end
        end
    end
    return CONFIG_FILE
end

local function mergeState(saved)
    if type(saved) ~= "table" then
        return
    end
    for key, default in pairs(session.state) do
        local value = saved[key]
        if value ~= nil and typeof(value) == typeof(default) then
            session.state[key] = value
        end
    end
end

local function loadConfig()
    ensureConfigFolder()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        session.configStatus = "Filesystem unavailable"
        return false
    end
    if type(writefile) == "function" and not isfile(AUTOLOAD_FILE) then
        pcall(writefile, AUTOLOAD_FILE, "default")
    end
    local path = configPath()
    if not isfile(path) then
        session.configStatus = "Defaults"
        return false
    end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" or raw == "" then
        session.configStatus = "Read failed"
        return false
    end
    local decodedOk, payload = pcall(HttpService.JSONDecode, HttpService, raw)
    if not decodedOk or type(payload) ~= "table" or payload.version ~= 1 then
        session.configStatus = "Defaults after migration"
        return false
    end
    mergeState(decode(payload.state or {}))
    session.configStatus = "Loaded " .. path
    return true
end

local function saveConfig()
    if type(writefile) ~= "function" then
        session.configStatus = "Filesystem unavailable"
        return false
    end
    ensureConfigFolder()
    local ok, raw = pcall(HttpService.JSONEncode, HttpService, { version = 1, state = encode(stateCopy()) })
    if not ok then
        session.configStatus = "Encode failed"
        return false
    end
    local path = configPath()
    local wrote = pcall(writefile, path, raw)
    if wrote and type(readfile) == "function" then
        local readOk, stored = pcall(readfile, path)
        wrote = readOk and stored == raw
    end
    session.configStatus = wrote and "Saved " .. path or "Write failed"
    return wrote
end

local function setAutoload(enabled)
    if type(writefile) ~= "function" then
        session.configStatus = "Filesystem unavailable"
        return false
    end
    ensureConfigFolder()
    if enabled then
        local ok = pcall(writefile, AUTOLOAD_FILE, "default")
        session.configStatus = ok and "Autoload enabled" or "Autoload write failed"
        return ok
    end
    if type(isfile) == "function" and isfile(AUTOLOAD_FILE) and type(delfile) == "function" then
        local ok = pcall(delfile, AUTOLOAD_FILE)
        session.configStatus = ok and "Autoload cleared" or "Autoload clear failed"
        return ok
    end
    session.configStatus = "Autoload already clear"
    return true
end

local function restoreLighting()
    lightingGuard = true
    Lighting.Brightness = originalLighting.Brightness
    Lighting.ClockTime = originalLighting.ClockTime
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.Ambient = originalLighting.Ambient
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    Lighting.ExposureCompensation = originalLighting.ExposureCompensation
    lightingGuard = false
end

local function applyFullbright()
    if lightingGuard then
        return
    end
    if not session.state.fullbright then
        restoreLighting()
        return
    end
    lightingGuard = true
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(210, 210, 210)
    Lighting.OutdoorAmbient = Color3.fromRGB(210, 210, 210)
    Lighting.ExposureCompensation = 0
    lightingGuard = false
end

local function bindLightingGuard()
    for _, property in ipairs({ "Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient", "ExposureCompensation" }) do
        track(Lighting:GetPropertyChangedSignal(property):Connect(function()
            if session.state.fullbright and not lightingGuard then
                applyFullbright()
            end
        end))
    end
end

local function loadLibrary(path)
    local filename = path:match("([^/]+)$")
    local source
    if type(readfile) == "function" then
        for _, candidate in ipairs({ path, "libs/" .. filename, filename }) do
            local ok, value = pcall(readfile, candidate)
            if ok and type(value) == "string" and #value > 0 then
                source = value
                break
            end
        end
    end
    if not source then
        local ok, value = pcall(function()
            return game:HttpGet(BASE .. filename)
        end)
        if ok and type(value) == "string" and #value > 0 then
            source = value
        end
    end
    assert(source, "library load failed: " .. path)
    return assert(loadstring(source, "=" .. path))()
end

local function clearGuiRoots()
    local parent
    if type(gethui) == "function" then
        local ok, value = pcall(gethui)
        if ok then
            parent = value
        end
    end
    parent = parent or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    if not parent then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == GUI_NAME then
            pcall(function()
                child:Destroy()
            end)
        end
    end
end

local function isDrawable(instance)
    return instance and (instance:IsA("Model") or instance:IsA("BasePart"))
end

local function safeName(instance)
    local ok, value = pcall(function()
        return instance.Name
    end)
    return ok and tostring(value) or "Unknown"
end

local function safePosition(instance)
    if not instance then
        return nil
    end
    local ok, position = pcall(function()
        if instance:IsA("BasePart") then
            return instance.Position
        end
        if instance:IsA("Model") then
            return instance:GetPivot().Position
        end
    end)
    return ok and position or nil
end

local function safeNumber(instance, names)
    if not instance then
        return nil
    end
    for _, name in ipairs(names) do
        local value = instance:GetAttribute(name)
        if tonumber(value) ~= nil then
            return tonumber(value)
        end
        local child = instance:FindFirstChild(name)
        if child and child:IsA("ValueBase") then
            local childValue = child.Value
            if tonumber(childValue) ~= nil then
                return tonumber(childValue)
            end
        end
    end
    return nil
end

local function safeDistance(instance)
    local camera = Workspace.CurrentCamera
    local position = safePosition(instance)
    if not camera or not position then
        return math.huge
    end
    return (camera.CFrame.Position - position).Magnitude
end

local function cacheNew()
    return { set = {}, list = {}, dirty = true, selection = {}, selectionAt = 0 }
end

session.caches.pickups = cacheNew()
session.caches.containers = cacheNew()

local function cacheMarkDirty(cache)
    cache.dirty = true
    cache.selection = {}
end

local function cacheAdd(cache, instance)
    if isDrawable(instance) and not cache.set[instance] then
        cache.set[instance] = true
        cacheMarkDirty(cache)
    end
end

local function cacheRemove(cache, instance)
    if cache.set[instance] then
        cache.set[instance] = nil
        cacheMarkDirty(cache)
    end
end

local function cacheList(cache)
    if cache.dirty then
        table.clear(cache.list)
        for instance in pairs(cache.set) do
            if instance and instance.Parent and instance:IsDescendantOf(Workspace) then
                cache.list[#cache.list + 1] = instance
            else
                cache.set[instance] = nil
            end
        end
        cache.dirty = false
    end
    return cache.list
end

local function attachCache(name, root)
    local cache = session.caches[name]
    local old = session.rootConnections[name]
    if old then
        disconnect(old.added)
        disconnect(old.removed)
    end
    session.roots[name] = root
    table.clear(cache.set)
    cacheMarkDirty(cache)
    if not root then
        session.rootConnections[name] = nil
        return
    end
    for _, child in ipairs(root:GetChildren()) do
        cacheAdd(cache, child)
    end
    local added = root.ChildAdded:Connect(function(child)
        cacheAdd(cache, child)
    end)
    local removed = root.ChildRemoved:Connect(function(child)
        cacheRemove(cache, child)
    end)
    session.rootConnections[name] = { added = added, removed = removed }
    track(added)
    track(removed)
end

local function resolveRoots()
    local interactable = Workspace:FindFirstChild("Interactable")
    attachCache("pickups", interactable and interactable:FindFirstChild("PickUps"))
    attachCache("containers", interactable and interactable:FindFirstChild("Containers"))
end

local function selectedCache(name, limit, range, predicate)
    local cache = session.caches[name]
    local now = os.clock()
    if cache.selectionAt and now - cache.selectionAt < 0.2 then
        return cache.selection
    end
    local ranked = {}
    local maxCount = math.max(1, math.floor(limit or 1))
    for _, instance in ipairs(cacheList(cache)) do
        if instance.Parent and safePosition(instance) and (not predicate or predicate(instance)) then
            local distance = safeDistance(instance)
            if range <= 0 or distance <= range then
                ranked[#ranked + 1] = { instance = instance, distance = distance }
            end
        end
    end
    table.sort(ranked, function(a, b)
        return a.distance < b.distance
    end)
    table.clear(cache.selection)
    for index = 1, math.min(#ranked, maxCount) do
        cache.selection[index] = ranked[index].instance
    end
    cache.selectionAt = now
    return cache.selection
end

local function directChildren(parent, childName)
    local root = parent and Workspace:FindFirstChild(parent)
    if childName then
        root = root and root:FindFirstChild(childName)
    end
    local result = {}
    if root then
        for _, child in ipairs(root:GetChildren()) do
            if isDrawable(child) then
                result[#result + 1] = child
            end
        end
    end
    return result
end

local function rankedInstances(source, limit, range)
    local ranked = {}
    for _, instance in ipairs(source or {}) do
        local distance = safeDistance(instance)
        if range <= 0 or distance <= range then
            ranked[#ranked + 1] = { instance = instance, distance = distance }
        end
    end
    table.sort(ranked, function(a, b)
        return a.distance < b.distance
    end)
    local result = {}
    for index = 1, math.min(#ranked, math.max(1, math.floor(limit or 1))) do
        result[index] = ranked[index].instance
    end
    return result
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function hasAny(text, values)
    for _, value in ipairs(values) do
        if text:find(value, 1, true) then
            return true
        end
    end
    return false
end

local function pickupKind(instance)
    if instance:GetAttribute("SOA_Deployed") == true or CollectionService:HasTag(instance, "SOADeployedProp") then
        return "deployed"
    end
    if instance:GetAttribute("DroppedFromInventory") == true or instance:FindFirstChild("LastDropped") then
        return "dropped"
    end
    if instance:FindFirstChild("Ammo") then
        return "ammo"
    end
    local name = lower(instance.Name)
    if hasAny(name, { "rifle", "shotgun", "pistol", "smg", "carbine", "machine gun", "revolver", "sniper", "crossbow", "sword", "knife" }) then
        return "weapons"
    end
    if hasAny(name, { "ammo", "round", "cartridge", "magazine", "bullet", "shell" }) then
        return "ammo"
    end
    if hasAny(name, { "med", "bandage", "tourniquet", "surgery", "quick revive", "first aid", "splint", "painkiller" }) then
        return "medical"
    end
    if hasAny(name, { "food", "drink", "water", "coffee", "juice", "soda", "burger", "chicken", "canned", "bread", "apple", "donut", "cookie", "tea", "milk" }) then
        return "food"
    end
    return "other"
end

local function pickupLabel(instance, prefix)
    local amount = safeNumber(instance, { "Ammo", "AmmoCount", "Amount", "Count", "Quantity", "Stack" })
    local text = prefix .. " | " .. safeName(instance)
    if amount ~= nil then
        text = text .. " x" .. tostring(math.floor(amount + 0.5))
    end
    return text
end

local function lootSource(kind)
    return selectedCache("pickups", session.state.lootLimit, session.state.lootRange, function(instance)
        return pickupKind(instance) == kind
    end)
end

local function droppedSource()
    return selectedCache("pickups", session.state.lootLimit, session.state.lootRange, function(instance)
        return pickupKind(instance) == "dropped"
    end)
end

local function otherLootSource()
    return selectedCache("pickups", session.state.lootLimit, session.state.lootRange, function(instance)
        local kind = pickupKind(instance)
        return kind == "other" or kind == "deployed"
    end)
end

local function worldText(category, instance)
    if category == "container" then
        return "CONTAINER | " .. safeName(instance)
    end
    if category == "exfil" then
        return "EXFIL | " .. safeName(instance)
    end
    if category == "airdrop" then
        return "AIRDROP | " .. safeName(instance)
    end
    return tostring(category) .. " | " .. safeName(instance)
end

local function worldSource(category)
    if category == "containers" then
        return selectedCache("containers", session.state.worldLimit, session.state.containerRange)
    end
    if category == "exfil" then
        return rankedInstances(directChildren("ExfilFlare"), session.state.worldLimit, session.state.exfilRange)
    end
    if category == "airdrop" then
        local items = directChildren("Airdrops", "Storage")
        local extra = directChildren("Airdrops", "Container")
        for _, item in ipairs(extra) do
            items[#items + 1] = item
        end
        return rankedInstances(items, session.state.worldLimit, session.state.airdropRange)
    end
    return {}
end

local function zombieSource()
    local root = Workspace:FindFirstChild("Zombies")
    local result = {}
    if root then
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
                result[#result + 1] = child
            end
        end
    end
    return result
end

local function playerReach()
    return math.max(
        session.state.playerRange,
        session.state.playerBoxRange,
        session.state.playerNameRange,
        session.state.playerHealthRange,
        session.state.playerDistanceRange,
        session.state.playerSkeletonRange,
        session.state.playerTracerRange,
        session.state.playerArrowRange
    )
end

local function activeRenderer()
    return session.state.players or session.state.world or session.state.loot or session.state.zombies
end

local function applyPlayerState()
    if not esp then
        return
    end
    local state = session.state
    local reach = playerReach()
    esp.cfg.on = activeRenderer()
    esp.cfg.players.on = state.players
    esp.cfg.team = state.teamCheck
    esp.cfg.maxRange = reach
    esp.cfg.espRange = reach
    esp.cfg.flags.on = state.flags
    esp.cfg.box.on = state.boxes
    esp.cfg.box.range = state.playerBoxRange
    esp.cfg.box.kind = state.boxStyle
    esp.cfg.box.col = state.playerColor
    esp.cfg.box.hpFull = state.visibleColor
    esp.cfg.box.hpLow = state.hiddenColor
    esp.cfg.name.on = state.names
    esp.cfg.name.range = state.playerNameRange
    esp.cfg.name.col = state.playerNameColor
    esp.cfg.hp.on = state.health
    esp.cfg.hp.range = state.playerHealthRange
    esp.cfg.hp.full = state.visibleColor
    esp.cfg.hp.low = state.hiddenColor
    esp.cfg.dist.on = state.distance
    esp.cfg.dist.range = state.playerDistanceRange
    esp.cfg.dist.col = state.playerDistanceColor
    esp.cfg.bones.on = state.skeleton
    esp.cfg.bones.range = state.playerSkeletonRange
    esp.cfg.bones.col = state.playerSkeletonColor
    esp.cfg.tracer.on = state.tracers
    esp.cfg.tracer.range = state.playerTracerRange
    esp.cfg.tracer.col = state.playerTracerColor
    esp.cfg.arrow.on = state.arrows
    esp.cfg.arrow.range = state.playerArrowRange
    esp.cfg.arrow.col = state.playerArrowColor
    esp.cfg.arrow.colorMode = state.arrowColorMode
    esp.cfg.arrow.colNear = state.arrowNearColor
    esp.cfg.arrow.colFar = state.arrowFarColor
    esp.cfg.vis.check = state.visibility
    esp.cfg.vis.hide = state.hideOccluded
    esp.cfg.vis.tint = state.visibility
    esp.cfg.head.on = false
    esp.cfg.gaze.on = false
    esp.cfg.npc.on = state.zombies
    esp.cfg.npc.maxRange = state.zombieRange
    esp.cfg.npc.espRange = state.zombieRange
    esp.cfg.npc.box.on = state.zombieBoxes
    esp.cfg.npc.name.on = state.zombieNames
    esp.cfg.npc.hp.on = state.zombieHealth
    esp.cfg.npc.dist.on = state.zombieDistance
    esp.cfg.npc.box.col = state.zombieColor
    esp.cfg.npc.name.col = state.zombieColor
    esp.cfg.npc.hp.full = state.visibleColor
    esp.cfg.npc.hp.low = state.hiddenColor
    esp.cfg.npc.dist.col = state.zombieColor
    esp.cfg.npc.vis.check = state.visibility
    esp.cfg.npc.vis.hide = state.hideOccluded
end

local function applyWorldState()
    if not esp then
        return
    end
    local state = session.state
    esp.cfg.on = activeRenderer()
    for _, spec in pairs(session.worldSpecs or {}) do
        spec.box = state.worldBoxes
        spec.name = state.worldNames
        spec.dist = state.worldDistance
        spec.tracer = state.worldTracers
        spec.visCheck = state.worldHideOccluded
        spec.hideOccluded = state.worldHideOccluded
    end
    local defs = session.worldDefs or {}
    for category, definition in pairs(defs) do
        local spec = session.worldSpecs[category]
        if spec then
            spec.col = state[definition.colorKey]
            spec.max = state[definition.rangeKey]
        end
    end
    for category, definition in pairs(session.lootDefs or {}) do
        local spec = session.worldSpecs[category]
        if spec then
            spec.box = state.lootBoxes
            spec.name = state.lootNames
            spec.dist = state.lootDistance
            spec.tracer = state.lootTracers
            spec.visCheck = state.lootHideOccluded
            spec.hideOccluded = state.lootHideOccluded
            spec.col = state[definition.colorKey]
            spec.max = state.lootRange
        end
    end
end

local function applyCombatState()
    if not esp then
        return
    end
    local state = session.state
    local target = esp.cfg.target
    target.on = state.combatPreview
    target.fov = state.combatFov
    target.range = state.combatRange
    target.showFov = state.combatPreview
    target.visOnly = state.combatVisibleOnly
    target.friends = state.combatFriends
    target.allies = state.combatAllies
    target.card = state.combatCard
    target.brackets = state.combatBrackets
    target.line = state.combatLine
    target.label = state.combatLabel
    target.dist = state.combatDistance
    target.hp = state.combatHealth
end

local function pruneTrajectories(now)
    for index = #session.trajectories, 1, -1 do
        if session.trajectories[index].expires <= now then
            table.remove(session.trajectories, index)
        end
    end
    while #session.trajectories > session.state.trajectoryLimit do
        table.remove(session.trajectories, 1)
    end
end

local function bindTrajectoryObserver()
    local connections = ReplicatedStorage:FindFirstChild("Connections")
    local event = connections and connections:FindFirstChild("CombatTrajectories")
    session.trajectoryAvailable = event and event:IsA("RemoteEvent") or false
    if not session.trajectoryAvailable then
        return
    end
    track(event.OnClientEvent:Connect(function(ownerId, records)
        if type(records) ~= "table" then
            return
        end
        local now = os.clock()
        for _, record in ipairs(records) do
            if type(record) == "table" and typeof(record.a) == "Vector3" and typeof(record.b) == "Vector3" then
                session.trajectories[#session.trajectories + 1] = {
                    a = record.a,
                    b = record.b,
                    owner = ownerId,
                    expires = now + session.state.trajectoryLifetime,
                }
            end
        end
        pruneTrajectories(now)
    end))
end

local function applyAll()
    applyPlayerState()
    applyWorldState()
    applyCombatState()
end

local function syncWidgets()
    for key, widget in pairs(session.widgets) do
        local stateKey = key:match("^voxel_esp%.(.+)$")
        if stateKey and session.state[stateKey] ~= nil then
            widget:Set(session.state[stateKey], true)
        end
    end
end

local function registerWidget(key, widget)
    session.widgets["voxel_esp." .. key] = widget
    return widget
end

local function bindToggle(section, text, key, callback)
    return registerWidget(key, section:Toggle({
        text = text,
        flag = "voxel_esp." .. key,
        default = session.state[key],
        callback = function(value)
            session.state[key] = value
            if callback then
                callback()
            end
            applyAll()
        end,
    }))
end

local function bindSlider(section, text, key, minValue, maxValue, step, suffix, callback)
    return registerWidget(key, section:Slider({
        text = text,
        flag = "voxel_esp." .. key,
        min = minValue,
        max = maxValue,
        step = step,
        decimals = 0,
        suffix = suffix,
        default = session.state[key],
        callback = function(value)
            session.state[key] = value
            if callback then
                callback(value)
            end
            applyAll()
        end,
    }))
end

local function bindDropdown(section, text, key, options, callback)
    return registerWidget(key, section:Dropdown({
        text = text,
        flag = "voxel_esp." .. key,
        options = options,
        default = session.state[key],
        callback = function(value)
            session.state[key] = value
            if callback then
                callback(value)
            end
            applyAll()
        end,
    }))
end

local function bindColor(section, text, key, callback)
    return registerWidget(key, section:Colorpicker({
        text = text,
        flag = "voxel_esp." .. key,
        default = session.state[key],
        callback = function(value)
            session.state[key] = value
            if callback then
                callback(value)
            end
            applyAll()
        end,
    }))
end

local function buildWorldSpecs()
    session.worldSpecs = {}
    session.worldDefs = {
        containers = { source = function() return worldSource("containers") end, label = function(instance) return worldText("container", instance) end, colorKey = "containerColor", rangeKey = "containerRange", priority = 2, enabled = function() return session.state.world and session.state.containers end },
        exfil = { source = function() return worldSource("exfil") end, label = function(instance) return worldText("exfil", instance) end, colorKey = "exfilColor", rangeKey = "exfilRange", priority = 9, enabled = function() return session.state.world and session.state.exfil end },
        airdrop = { source = function() return worldSource("airdrop") end, label = function(instance) return worldText("airdrop", instance) end, colorKey = "airdropColor", rangeKey = "airdropRange", priority = 8, enabled = function() return session.state.world and session.state.airdrops end },
    }
    session.lootDefs = {
        weapons = { kind = "weapons", label = "WEAPON", colorKey = "lootWeaponColor" },
        ammo = { kind = "ammo", label = "AMMO", colorKey = "lootAmmoColor" },
        medical = { kind = "medical", label = "MEDICAL", colorKey = "lootMedicalColor" },
        food = { kind = "food", label = "FOOD", colorKey = "lootFoodColor" },
        dropped = { kind = "dropped", label = "DROPPED", colorKey = "lootDroppedColor" },
        other = { kind = "other", label = "LOOT", colorKey = "lootColor" },
    }
    for category, definition in pairs(session.worldDefs) do
        local spec = esp:addEnt("voxel_world_" .. category, {
            get = function()
                if not definition.enabled() then
                    return {}
                end
                return definition.source()
            end,
            label = definition.label,
            col = session.state[definition.colorKey],
            box = false,
            name = true,
            dist = false,
            dot = true,
            max = session.state[definition.rangeKey],
            priority = definition.priority,
        })
        session.worldSpecs[category] = spec
    end
    for category, definition in pairs(session.lootDefs) do
        local spec = esp:addEnt("voxel_loot_" .. category, {
            get = function()
                local key = category == "weapons" and "lootWeapons" or category == "ammo" and "lootAmmo" or category == "medical" and "lootMedical" or category == "food" and "lootFood" or category == "dropped" and "lootDropped" or "lootOther"
                if not session.state.loot or not session.state[key] then
                    return {}
                end
                if category == "weapons" then
                    return lootSource("weapons")
                end
                if category == "ammo" then
                    return lootSource("ammo")
                end
                if category == "medical" then
                    return lootSource("medical")
                end
                if category == "food" then
                    return lootSource("food")
                end
                if category == "dropped" then
                    return droppedSource()
                end
                return otherLootSource()
            end,
            label = function(instance)
                return pickupLabel(instance, definition.label)
            end,
            col = session.state[definition.colorKey],
            box = false,
            name = true,
            dist = false,
            dot = true,
            max = session.state.lootRange,
            priority = (category == "weapons" or category == "dropped") and 7 or 3,
        })
        session.worldSpecs[category] = spec
    end
end

local function clearRoots()
    for _, pair in pairs(session.rootConnections) do
        disconnect(pair.added)
        disconnect(pair.removed)
    end
    session.rootConnections = {}
end

local function bindMenu()
    menuAction = "VOXEL_ESP_MENU_TOGGLE"
    ContextActionService:UnbindAction(menuAction)
    local key = Enum.KeyCode[session.state.menuKey] or Enum.KeyCode.RightShift
    ContextActionService:BindActionAtPriority(menuAction, function(_, inputState)
        if UserInputService:GetFocusedTextBox() then
            return Enum.ContextActionResult.Pass
        end
        if inputState == Enum.UserInputState.Begin and not session.unloaded then
            ui:Toggle()
        end
        return Enum.ContextActionResult.Sink
    end, false, 3000, key)
end

local function refreshStatus()
    if session.unloaded or not statusLabel then
        return
    end
    local stats = esp and esp:getStats() or {}
    local pickupCount = #cacheList(session.caches.pickups)
    local containerCount = #cacheList(session.caches.containers)
    setLabel(statusLabel, "FPS " .. tostring(math.floor((stats.fpsAvg or 0) + 0.5)) .. " | Drawn " .. tostring(stats.drawn or 0) .. " | Pool " .. tostring(stats.pool or 0))
    setLabel(countLabel, "Players " .. tostring(#Players:GetPlayers()) .. " | Pickups " .. tostring(pickupCount) .. " | Containers " .. tostring(containerCount) .. " | Zombies " .. tostring(#zombieSource()))
    setLabel(configLabel, "Config: " .. tostring(session.configStatus) .. " | Range " .. tostring(session.state.playerRange) .. "m")
    if combatStatusLabel then
        local target = esp and esp.target
        local targetName = target and target.plr and target.plr.DisplayName or "none"
        local trajectoryState = session.trajectoryAvailable and "available" or "unavailable"
        setLabel(combatStatusLabel, "Preview target: " .. tostring(targetName) .. " | Trajectories: " .. tostring(#session.trajectories) .. " | Feed: " .. trajectoryState)
    end
end

function session.snapshot()
    local stats = esp and esp:getStats() or {}
    return {
        readOnly = true,
        remoteCalls = false,
        hooks = false,
        inputSynthesis = false,
        worldMutation = false,
        localAppearanceOverrides = session.state.fullbright,
        fullbright = session.state.fullbright,
        running = not session.unloaded,
        guiName = GUI_NAME,
        players = #Players:GetPlayers(),
        pickups = #cacheList(session.caches.pickups),
        containers = #cacheList(session.caches.containers),
        zombies = #zombieSource(),
        combatPreview = session.state.combatPreview,
        trajectoryOn = session.state.trajectoryOn,
        trajectories = #session.trajectories,
        trajectoryAvailable = session.trajectoryAvailable == true,
        playerRange = session.state.playerRange,
        lootRange = session.state.lootRange,
        stats = stats,
        config = configPath(),
    }
end

function session.unload(persist)
    if session.unloaded then
        return
    end
    session.unloaded = true
    if persist ~= false then
        pcall(saveConfig)
    end
    session.state.fullbright = false
    restoreLighting()
    if menuAction then
        pcall(ContextActionService.UnbindAction, ContextActionService, menuAction)
        menuAction = nil
    end
    clearRoots()
    for _, connection in ipairs(session.connections) do
        disconnect(connection)
    end
    session.connections = {}
    if esp then
        pcall(function()
            esp:destroy()
        end)
        esp = nil
    end
    if ui then
        pcall(function()
            ui:Destroy()
        end)
        ui = nil
    end
    clearGuiRoots()
    if GENV[SLOT] == session then
        GENV[SLOT] = nil
    end
end

local function boot()
    loadConfig()
    bindLightingGuard()
    applyFullbright()
    clearGuiRoots()
    resolveRoots()
    track(Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Interactable" or child.Name == "Airdrops" or child.Name == "Zombies" or child.Name == "ExfilFlare" then
            task.defer(resolveRoots)
        end
    end))
    local interactable = Workspace:FindFirstChild("Interactable")
    if interactable then
        track(interactable.ChildAdded:Connect(function(child)
            if child.Name == "PickUps" or child.Name == "Containers" then
                task.defer(resolveRoots)
            end
        end))
    end

    local ESP = loadLibrary("easyesp/EasyESP.luau")
    local UI = loadLibrary("easyui/EasyUi_style_2.luau")

    esp = ESP.new({
        on = true,
        players = { on = session.state.players },
        box = { on = session.state.boxes, kind = session.state.boxStyle, col = session.state.playerColor, outline = true, fill = false, hpFull = session.state.visibleColor, hpLow = session.state.hiddenColor },
        name = { on = session.state.names, col = session.state.playerNameColor, size = 13 },
        dist = { on = session.state.distance, col = session.state.playerDistanceColor, size = 11, suf = "m" },
        hp = { on = session.state.health, side = "left", text = true, full = session.state.visibleColor, low = session.state.hiddenColor },
        bones = { on = session.state.skeleton, col = session.state.playerSkeletonColor },
        tracer = { on = session.state.tracers, from = "bottom", col = session.state.playerTracerColor },
        arrow = { on = session.state.arrows, col = session.state.playerArrowColor, colorMode = session.state.arrowColorMode, colNear = session.state.arrowNearColor, colFar = session.state.arrowFarColor, dist = true, fill = true },
        vis = { check = session.state.visibility, hide = session.state.hideOccluded, tint = session.state.visibility, points = 3 },
        radar = { on = false },
        perf = { mode = "auto", entityStep = 3, boxStep = 2, toolStep = 14 },
    })
    esp:theme("carbon")
    esp:profile("balanced")
    esp:setPlayerLabel(function(player)
        return tostring(player.DisplayName or player.Name) .. "  @" .. tostring(player.Name)
    end)
    esp:setNPCSource(zombieSource)
    esp:setNPCLabel(function(model)
        return "ZOMBIE | " .. safeName(model)
    end)
    esp:setTargetInfo(function(snapshot)
        local character = snapshot.plr and snapshot.plr.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if not tool then
            return "UNARMED"
        end
        local ammo = safeNumber(tool, { "Ammo", "AmmoCount", "Magazine", "Mag", "CurrentAmmo" })
        if ammo ~= nil then
            return tostring(tool.Name) .. " | " .. tostring(math.floor(ammo + 0.5)) .. " ammo"
        end
        return tostring(tool.Name)
    end)
    esp:mod({
        name = "voxel_trajectory_preview",
        on = true,
        screen = function(_, renderer)
            if not session.state.trajectoryOn then
                return
            end
            local now = os.clock()
            pruneTrajectories(now)
            for index, record in ipairs(session.trajectories) do
                local ax, ay, ad, aon = renderer:project(record.a)
                local bx, by, bd, bon = renderer:project(record.b)
                if aon and bon and ad > 0 and bd > 0 then
                    renderer.pool:line("voxel_traj_" .. tostring(index), ax, ay, bx, by, session.state.trajectoryColor, 1, 0.8, 35)
                end
            end
        end,
    })
    bindTrajectoryObserver()
    esp:flag("tool", function(snapshot)
        local character = snapshot.plr and snapshot.plr.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if tool then
            return { tool.Name, Color3.fromRGB(255, 210, 110) }
        end
    end)
    esp:flag("state", function(snapshot)
        if snapshot.hum then
            return { tostring(snapshot.hum:GetState()):gsub("Enum.HumanoidStateType.", ""), Color3.fromRGB(190, 200, 220) }
        end
    end)
    esp:setFlagEnabled("tool", true)
    esp:setFlagEnabled("state", true)

    buildWorldSpecs()
    applyAll()
    esp:start()
    session.esp = esp

    ui = UI.new({
        name = GUI_NAME,
        title = "VOXEL",
        separator = " | ",
        compact = true,
        customCursor = false,
        accent = Color3.fromRGB(110, 205, 255),
        toggleKey = false,
        watermark = false,
        resizable = true,
    })
    session.ui = ui
    ui:SetToggleKey(false)
    ui:SetCursorVisible(session.state.customCursor)
    window = ui:Window("ESP", { x = 34, y = 58, width = 520, height = 560 })

    local visualTab = window:Tab("Visuals")
    local playersTab = visualTab:SubTab("Players")
    local worldTab = visualTab:SubTab("World")
    local lootTab = visualTab:SubTab("Loot")
    local combatTab = window:Tab("Combat")
    local miscTab = window:Tab("Status")

    local playerMain = playersTab:Section("Player overlay")
    local playerGrid = playerMain:Grid(2)
    local playerLeft = playerGrid:Column(1)
    local playerRight = playerGrid:Column(2)
    bindToggle(playerLeft, "Player ESP", "players")
    bindToggle(playerLeft, "Boxes", "boxes")
    bindToggle(playerLeft, "Names", "names")
    bindToggle(playerLeft, "Health", "health")
    bindToggle(playerLeft, "Distance", "distance")
    bindToggle(playerRight, "Skeleton", "skeleton")
    bindToggle(playerRight, "Tracers", "tracers")
    bindToggle(playerRight, "Off-screen arrows", "arrows")
    bindToggle(playerRight, "Info flags", "flags")
    bindToggle(playerRight, "Visibility checks", "visibility")
    bindToggle(playerRight, "Hide occluded", "hideOccluded")
    bindToggle(playerRight, "Team check", "teamCheck")

    local playerRanges = playersTab:Section("Per-channel ranges")
    local rangeGrid = playerRanges:Grid(2)
    local rangeLeft = rangeGrid:Column(1)
    local rangeRight = rangeGrid:Column(2)
    bindSlider(rangeLeft, "Player range", "playerRange", 250, 5000, 250, "m", function(value)
        session.state.playerBoxRange = value
        session.state.playerNameRange = value
        session.state.playerHealthRange = value
        session.state.playerDistanceRange = value
        session.state.playerSkeletonRange = value
        session.state.playerTracerRange = value
        session.state.playerArrowRange = value
        syncWidgets()
    end)
    bindSlider(rangeLeft, "Boxes", "playerBoxRange", 100, 5000, 100, "m")
    bindSlider(rangeLeft, "Names", "playerNameRange", 100, 5000, 100, "m")
    bindSlider(rangeRight, "Health", "playerHealthRange", 100, 5000, 100, "m")
    bindSlider(rangeRight, "Distance", "playerDistanceRange", 100, 5000, 100, "m")
    bindSlider(rangeRight, "Skeleton", "playerSkeletonRange", 100, 5000, 100, "m")
    bindSlider(rangeRight, "Tracers", "playerTracerRange", 100, 5000, 100, "m")
    bindSlider(rangeRight, "Arrows", "playerArrowRange", 100, 5000, 100, "m")

    local playerStyle = playersTab:Section("Appearance")
    local styleGrid = playerStyle:Grid(2)
    local styleLeft = styleGrid:Column(1)
    local styleRight = styleGrid:Column(2)
    bindDropdown(styleLeft, "Box style", "boxStyle", { "corner", "box", "3d", "3dcorner" })
    bindDropdown(styleLeft, "Arrow mode", "arrowColorMode", { "static", "gradient", "range" })
    bindColor(styleLeft, "Player color", "playerColor")
    bindColor(styleLeft, "Name color", "playerNameColor")
    bindColor(styleRight, "Visible color", "visibleColor")
    bindColor(styleRight, "Hidden color", "hiddenColor")
    bindColor(styleRight, "Arrow near", "arrowNearColor")
    bindColor(styleRight, "Arrow far", "arrowFarColor")

    local worldMain = worldTab:Section("World markers")
    local worldGrid = worldMain:Grid(2)
    local worldLeft = worldGrid:Column(1)
    local worldRight = worldGrid:Column(2)
    bindToggle(worldLeft, "World ESP", "world")
    bindToggle(worldLeft, "Containers", "containers")
    bindToggle(worldLeft, "Exfil flares", "exfil")
    bindToggle(worldLeft, "Airdrop storage", "airdrops")
    bindToggle(worldRight, "Boxes", "worldBoxes")
    bindToggle(worldRight, "Names", "worldNames")
    bindToggle(worldRight, "Distance", "worldDistance")
    bindToggle(worldRight, "Tracers", "worldTracers")
    bindToggle(worldRight, "Hide occluded", "worldHideOccluded")
    bindSlider(worldRight, "Marker cap", "worldLimit", 8, 96, 8, "")
    bindSlider(worldRight, "World range", "worldRange", 250, 5000, 250, "m")

    local worldRanges = worldTab:Section("World category ranges")
    local worldRangeGrid = worldRanges:Grid(2)
    local worldRangeLeft = worldRangeGrid:Column(1)
    local worldRangeRight = worldRangeGrid:Column(2)
    bindSlider(worldRangeLeft, "Containers", "containerRange", 100, 5000, 100, "m")
    bindSlider(worldRangeLeft, "Exfil flares", "exfilRange", 100, 5000, 100, "m")
    bindSlider(worldRangeLeft, "Airdrops", "airdropRange", 100, 5000, 100, "m")
    bindColor(worldRangeLeft, "Container color", "containerColor")
    bindColor(worldRangeLeft, "Exfil color", "exfilColor")
    bindColor(worldRangeRight, "Airdrop color", "airdropColor")
    bindToggle(worldRangeRight, "Zombies", "zombies")
    bindToggle(worldRangeRight, "Zombie boxes", "zombieBoxes")
    bindToggle(worldRangeRight, "Zombie names", "zombieNames")
    bindToggle(worldRangeRight, "Zombie health", "zombieHealth")
    bindToggle(worldRangeRight, "Zombie distance", "zombieDistance")
    bindSlider(worldRangeRight, "Zombie range", "zombieRange", 100, 5000, 100, "m")
    bindColor(worldRangeRight, "Zombie color", "zombieColor")

    local lootMain = lootTab:Section("Loot filters")
    local lootGrid = lootMain:Grid(2)
    local lootLeft = lootGrid:Column(1)
    local lootRight = lootGrid:Column(2)
    bindToggle(lootLeft, "Loot ESP", "loot")
    bindToggle(lootLeft, "Weapons", "lootWeapons")
    bindToggle(lootLeft, "Ammo", "lootAmmo")
    bindToggle(lootLeft, "Medical", "lootMedical")
    bindToggle(lootRight, "Food and drink", "lootFood")
    bindToggle(lootRight, "Dropped items", "lootDropped")
    bindToggle(lootRight, "Other items", "lootOther")
    bindToggle(lootRight, "Boxes", "lootBoxes")
    bindToggle(lootRight, "Names", "lootNames")
    bindToggle(lootRight, "Distance", "lootDistance")
    bindToggle(lootRight, "Tracers", "lootTracers")
    bindToggle(lootRight, "Hide occluded", "lootHideOccluded")

    local lootRanges = lootTab:Section("Loot budget")
    local lootRangeGrid = lootRanges:Grid(2)
    local lootRangeLeft = lootRangeGrid:Column(1)
    local lootRangeRight = lootRangeGrid:Column(2)
    bindSlider(lootRangeLeft, "Loot range", "lootRange", 100, 2500, 50, "m")
    bindSlider(lootRangeLeft, "Marker cap", "lootLimit", 8, 96, 8, "")
    bindColor(lootRangeLeft, "General loot", "lootColor")
    bindColor(lootRangeRight, "Weapons", "lootWeaponColor")
    bindColor(lootRangeRight, "Ammo", "lootAmmoColor")
    bindColor(lootRangeRight, "Medical", "lootMedicalColor")
    bindColor(lootRangeRight, "Food", "lootFoodColor")
    bindColor(lootRangeRight, "Dropped", "lootDroppedColor")

    local combatMain = combatTab:Section("Passive target preview")
    local combatGrid = combatMain:Grid(2)
    local combatLeft = combatGrid:Column(1)
    local combatRight = combatGrid:Column(2)
    bindToggle(combatLeft, "Target preview", "combatPreview")
    bindSlider(combatLeft, "Preview FOV", "combatFov", 40, 500, 10, "px")
    bindSlider(combatLeft, "Preview range", "combatRange", 100, 5000, 100, "m")
    bindToggle(combatLeft, "Visible only", "combatVisibleOnly")
    bindToggle(combatLeft, "Include friends", "combatFriends")
    bindToggle(combatLeft, "Include allies", "combatAllies")
    bindToggle(combatRight, "Target card", "combatCard")
    bindToggle(combatRight, "Brackets", "combatBrackets")
    bindToggle(combatRight, "Snapline", "combatLine")
    bindToggle(combatRight, "Label", "combatLabel")
    bindToggle(combatRight, "Distance", "combatDistance")
    bindToggle(combatRight, "Health", "combatHealth")

    local trajectorySection = combatTab:Section("Observed trajectories")
    local trajectoryGrid = trajectorySection:Grid(2)
    local trajectoryLeft = trajectoryGrid:Column(1)
    local trajectoryRight = trajectoryGrid:Column(2)
    bindToggle(trajectoryLeft, "Trajectory preview", "trajectoryOn")
    bindSlider(trajectoryLeft, "Trajectory cap", "trajectoryLimit", 4, 32, 4, "")
    bindSlider(trajectoryLeft, "Lifetime", "trajectoryLifetime", 1, 5, 1, "s")
    bindColor(trajectoryLeft, "Trajectory color", "trajectoryColor")
    trajectoryRight:Label("Client-visible trajectory telemetry only. No shot remotes, aim redirection, input synthesis, or firing automation.")
    combatStatusLabel = trajectoryRight:Label("Preview target: none | Trajectories: 0")

    local interface = miscTab:Section("Interface and config")
    local interfaceGrid = interface:Grid(2)
    local interfaceLeft = interfaceGrid:Column(1)
    local interfaceRight = interfaceGrid:Column(2)
    bindDropdown(interfaceLeft, "Menu key", "menuKey", { "RightShift", "Insert", "F6", "F7" }, function()
        bindMenu()
    end)
    bindToggle(interfaceLeft, "Fullbright", "fullbright", applyFullbright)
    bindToggle(interfaceLeft, "Custom cursor", "customCursor", function()
        ui:SetCursorVisible(session.state.customCursor)
    end)
    interfaceLeft:Button({ text = "Save config", callback = function()
        saveConfig()
        refreshStatus()
    end })
    interfaceLeft:Button({ text = "Reload config", callback = function()
        loadConfig()
        syncWidgets()
        applyAll()
        refreshStatus()
    end })
    interfaceRight:Button({ text = "Enable autoload", callback = function()
        setAutoload(true)
        refreshStatus()
    end })
    interfaceRight:Button({ text = "Clear autoload", callback = function()
        setAutoload(false)
        refreshStatus()
    end })
    interfaceRight:Button({ text = "Unload", callback = function()
        session.unload()
    end })

    local status = miscTab:Section("Live status")
    statusLabel = status:Label("Loading")
    countLabel = status:Label("Counts")
    configLabel = status:Label("Config")
    status:Label("Read-only client-visible ESP. World loot is capped and nearest-first to keep the overlay readable.")

    bindMenu()
    ui:SetVisible(false)
    refreshStatus()

    local elapsed = 0
    track(RunService.Heartbeat:Connect(function(dt)
        if session.unloaded then
            return
        end
        elapsed += dt
        if elapsed >= 0.5 then
            elapsed = 0
            refreshStatus()
        end
    end))

    print("[VOXEL_ESP_LOAD] true")
end

local ok, err = xpcall(boot, debug.traceback)
if not ok then
    session.error = err
    pcall(session.unload, false)
    error(err, 0)
end
