local GENV = (getgenv and getgenv()) or shared or _G
local SLOT = "__HUSH_ESP"
local previous = GENV[SLOT]
if type(previous) == "table" and type(previous.unload) == "function" then
    pcall(previous.unload)
end

local BASE = "https://raw.githubusercontent.com/ToiletStarter/CantStopMakingReposForThis/refs/heads/main/"
local PERFORMANCE_LEVEL = 2
local PERFORMANCE_PROFILE = ({ "low", "balanced", "high" })[PERFORMANCE_LEVEL] or "balanced"

local session = {
    unloaded = false,
    connections = {},
    state = {
        players = true,
        monsters = true,
        world = true,
        names = true,
        boxes = true,
        health = true,
        distance = true,
        tracers = false,
        playerTracers = false,
        monsterTracers = false,
        skeleton = false,
        arrows = false,
        visibility = true,
        visibilityTint = true,
        hideOccluded = false,
        playerRange = 2500,
        worldRange = 1500,
        monsterRange = 2500,
        boxStyle = "corner",
        colorMode = "static",
        worldBoxes = true,
        worldNames = true,
        worldDistance = true,
        worldTracers = false,
        worldHideOccluded = false,
        customCursor = true,
        vehicles = true,
        containers = true,
        containerDrawers = true,
        containerFridges = true,
        containerCabinets = true,
        containerCrates = true,
        containerLockers = true,
        containerVehicles = true,
        containerOther = true,
        bodies = true,
        pois = true,
        items = true,
        itemsWeapons = true,
        itemsAmmo = true,
        itemsMedical = true,
        itemsRare = true,
        itemsMisc = true,
        mother = true,
    },
}

local function loadLibrary(path)
    local source
    if type(readfile) == "function" then
        local cachedOk, cached = pcall(readfile, path)
        if cachedOk and type(cached) == "string" and #cached > 0 then
            source = cached
        end
    end
    if not source then
        local ok, result = pcall(function()
            return game:HttpGet(BASE .. path)
        end)
        if ok and type(result) == "string" and #result > 0 then
            source = result
        end
    end
    assert(source, "library load failed: " .. path)
    return assert(loadstring(source, "=" .. path))()
end

local function track(connection)
    if connection then
        table.insert(session.connections, connection)
    end
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(session.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    session.connections = {}
end

local function safeName(instance)
    local ok, value = pcall(function()
        return instance.Name
    end)
    return ok and tostring(value) or "Unknown"
end

local function attribute(instance, name)
    local ok, value = pcall(function()
        return instance:GetAttribute(name)
    end)
    return ok and value or nil
end

local function formatNumber(number)
    if type(number) == "number" then
        return tostring(math.floor(number + 0.5))
    end
    return tostring(number)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local ESP = loadLibrary("easyesp/EasyESP.luau")
local UI = loadLibrary("easyui/EasyUi_style_2.luau")

local function pathOf(instance)
    local parts = {}
    local current = instance
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, ".")
end

local worldCaches = {}
for _, category in ipairs({ "vehicles", "containers", "bodies", "pois", "mother", "itemsWeapons", "itemsAmmo", "itemsMedical", "itemsRare", "itemsMisc" }) do
    worldCaches[category] = { list = {}, set = {}, dirty = true }
end

local containerKinds = setmetatable({}, { __mode = "k" })

local poiTerms = { "motel", "checkpoint", "hospital", "policestation", "garage", "carpark", "deepwell", "bunker", "outpost", "gasstation", "diner", "cafe", "school", "warehouse", "workshop", "precinct", "farmhouse", "church" }
local containerTerms = { "container", "crate", "chest", "locker", "drawer", "cabinet", "fridge", "shelf", "stash", "lootbag", "truckload", "weaponcrate" }
local containerModelTerms = { "crate", "chest", "locker", "lootbag", "truckload", "weaponcrate" }
local vehicleNames = { car = true, truck = true, van = true, vehicle = true, boat = true, bike = true, motorcycle = true }

local npcCache = { list = {}, set = {}, dirty = true }

local function markDirty(cache)
    cache.dirty = true
end

local function cachedList(cache)
    if cache.dirty then
        cache.list = {}
        for instance in pairs(cache.set) do
            if instance and instance.Parent then
                table.insert(cache.list, instance)
            else
                cache.set[instance] = nil
            end
        end
        cache.dirty = false
    end
    return cache.list
end

local function candidateFor(instance)
    if not instance then
        return nil
    end
    if instance:IsA("Model") then
        return instance
    end
    return instance:FindFirstAncestorOfClass("Model") or (instance:IsA("BasePart") and instance or nil)
end

local function matches(text, terms)
    text = string.lower(tostring(text or ""))
    for _, term in ipairs(terms) do
        if text:find(term, 1, true) then
            return true
        end
    end
    return false
end

local function isPlayerCharacter(instance)
    return instance and Players:GetPlayerFromCharacter(instance) ~= nil
end

local function hasTerm(text, terms)
    text = string.lower(tostring(text or ""))
    for _, term in ipairs(terms) do
        if text:find(term, 1, true) then
            return true
        end
    end
    return false
end

local function pathHas(instance, term)
    return string.lower(pathOf(instance)):find(term, 1, true) ~= nil
end

local function isPoiCandidate(candidate)
    return candidate:IsA("Model") and hasTerm(safeName(candidate), poiTerms)
end

local function isBodyCandidate(candidate)
    return candidate:IsA("Model") and (pathHas(candidate, ".bodies.") or attribute(candidate, "Ragdoll") == true)
end

local function isMotherCandidate(candidate)
    return candidate:IsA("Model") and (string.lower(safeName(candidate)) == "mother" or pathHas(candidate, ".mothermouthful."))
end

local function isMonsterCandidate(candidate)
    return candidate:IsA("Model") and (pathHas(candidate, ".monsters.") or pathHas(candidate, ".walkers.") or attribute(candidate, "Kind") ~= nil)
end

local function isVehicleCandidate(candidate)
    if not candidate:IsA("Model") then
        return false
    end
    return attribute(candidate, "Drivable") ~= nil or attribute(candidate, "CarKind") ~= nil or attribute(candidate, "VehicleType") ~= nil
end

local function itemCategory(candidate)
    local name = string.lower(safeName(candidate))
    local detail = string.lower(tostring(attribute(candidate, "ItemType") or attribute(candidate, "Category") or attribute(candidate, "DisplayName") or ""))
    local text = name .. " " .. detail
    if attribute(candidate, "RareFind") == true or hasTerm(text, { "access", "keycard", "badge", "credential", "pass" }) then
        return "itemsRare"
    end
    if hasTerm(text, { "ammo", "bullet", "shell", "powder", "nails" }) then
        return "itemsAmmo"
    end
    if hasTerm(text, { "med", "medical", "bandage", "water", "food", "crackers" }) then
        return "itemsMedical"
    end
    if hasTerm(text, { "gun", "shotgun", "pistol", "rifle", "launcher", "silencer", "grip", "barrel", "weapon" }) then
        return "itemsWeapons"
    end
    return "itemsMisc"
end

local function isWorldFind(candidate)
    local name = string.lower(safeName(candidate))
    return pathHas(candidate, ".worldfinds.") or name:sub(1, 8) == "dropped_" or name:sub(1, 5) == "find_"
end

local function addWorldCandidate(instance, category)
    local candidate = instance
    if not candidate or not candidate.Parent or isPlayerCharacter(candidate) then
        return
    end
    local cache = worldCaches[category]
    if cache and not cache.set[candidate] then
        cache.set[candidate] = true
        markDirty(cache)
    end
end

local function removeWorldCandidate(instance)
    local candidate = instance
    if instance and instance:IsA("ProximityPrompt") then
        candidate = instance.Parent
    elseif instance and not instance:IsA("Model") and not instance:IsA("BasePart") then
        candidate = candidateFor(instance) or instance
    end
    for _, cache in pairs(worldCaches) do
        if cache.set[candidate] then
            cache.set[candidate] = nil
            markDirty(cache)
        end
    end
end

local function containerKind(anchor, containerType)
    local value = string.lower(tostring(containerType or safeName(anchor)))
    if hasTerm(value, { "drawer" }) then
        return "drawers"
    end
    if hasTerm(value, { "fridge", "refrigerator" }) then
        return "fridges"
    end
    if hasTerm(value, { "cabinet", "shelf", "medical" }) then
        return "cabinets"
    end
    if hasTerm(value, { "crate", "chest", "supply", "weapon" }) then
        return "crates"
    end
    if hasTerm(value, { "locker", "container" }) then
        return "lockers"
    end
    if hasTerm(value, { "cartrunk", "truck", "cargo", "vehicle" }) then
        return "vehicles"
    end
    return "other"
end

local function containerEnabled(kind)
    return session.state["container" .. kind:sub(1, 1):upper() .. kind:sub(2)] == true
end

local function filteredList(cache, predicate)
    local list = cachedList(cache)
    if not predicate then
        return list
    end
    local filtered = {}
    for _, instance in ipairs(list) do
        if predicate(instance) then
            filtered[#filtered + 1] = instance
        end
    end
    return filtered
end

local function inspectPrompt(prompt)
    local anchor = prompt.Parent
    if not anchor or pathHas(anchor, ".bodies.") then
        return
    end
    local promptName = string.lower(prompt.Name)
    if promptName:find("pickup", 1, true) or promptName:find("collect", 1, true) or promptName:find("take", 1, true) or promptName:find("grab", 1, true) then
        local item = candidateFor(anchor) or anchor
        if item and not isBodyCandidate(item) and not isMonsterCandidate(item) then
            addWorldCandidate(item, itemCategory(item))
        end
        return
    end
    local containerType = attribute(anchor, "ContainerType")
    local anchorName = string.lower(safeName(anchor))
    if containerType or promptName:find("search", 1, true) or promptName:find("loot", 1, true) or anchorName:find("lootbag", 1, true) or pathHas(anchor, ".lootbags.") then
        containerKinds[anchor] = containerKind(anchor, containerType)
        addWorldCandidate(anchor, "containers")
    end
end

local function classifyWorldCandidate(candidate)
    if not candidate or not candidate.Parent or isPlayerCharacter(candidate) then
        return
    end
    if isBodyCandidate(candidate) then
        addWorldCandidate(candidate, "bodies")
        return
    end
    if isPoiCandidate(candidate) then
        addWorldCandidate(candidate, "pois")
        return
    end
    if isMotherCandidate(candidate) then
        addWorldCandidate(candidate, "mother")
        return
    end
    if isMonsterCandidate(candidate) then
        return
    end
    if isVehicleCandidate(candidate) then
        addWorldCandidate(candidate, "vehicles")
        return
    end
    if isWorldFind(candidate) then
        addWorldCandidate(candidate, itemCategory(candidate))
        return
    end
    if candidate:IsA("Model") and hasTerm(safeName(candidate), containerModelTerms) then
        containerKinds[candidate] = containerKind(candidate)
        addWorldCandidate(candidate, "containers")
    end
end

local function inspectWorldInstance(instance)
    if instance:IsA("ProximityPrompt") then
        inspectPrompt(instance)
        return
    end
    local candidate = candidateFor(instance)
    if candidate ~= instance then
        return
    end
    classifyWorldCandidate(candidate)
end

local function addNpcCandidate(instance)
    local model = candidateFor(instance)
    if not model or not model.Parent or model == LocalPlayer.Character or isPlayerCharacter(model) or not model:IsA("Model") then
        return
    end
    if not isMonsterCandidate(model) then
        return
    end
    if model:FindFirstChildOfClass("Humanoid") and not npcCache.set[model] then
        npcCache.set[model] = true
        markDirty(npcCache)
    end
end

local function removeNpcCandidate(instance)
    local model = candidateFor(instance) or instance
    if npcCache.set[model] then
        npcCache.set[model] = nil
        markDirty(npcCache)
    end
end

local function inspectNpcInstance(instance)
    if instance:IsA("Model") then
        addNpcCandidate(instance)
    end
end

local initialInstances = workspace:GetDescendants()
local initialIndex = 1
track(workspace.DescendantAdded:Connect(function(instance)
    inspectWorldInstance(instance)
    inspectNpcInstance(instance)
end))
track(workspace.DescendantRemoving:Connect(function(instance)
    removeWorldCandidate(instance)
    removeNpcCandidate(instance)
end))
track(RunService.Heartbeat:Connect(function()
    if session.unloaded then
        return
    end
    local processed = 0
    while initialIndex <= #initialInstances and processed < 160 do
        local instance = initialInstances[initialIndex]
        initialIndex += 1
        if instance and instance.Parent then
            inspectWorldInstance(instance)
            inspectNpcInstance(instance)
        end
        processed += 1
    end
    if initialIndex > #initialInstances then
        initialInstances = {}
    end
end))

local function makeConfig()
    return {
        on = true,
        maxRange = session.state.playerRange,
        espRange = session.state.playerRange,
        players = { on = session.state.players },
        box = { on = session.state.boxes, kind = session.state.boxStyle, col = Color3.fromRGB(245, 245, 245), outline = true, fill = false, mode = "static", fade = false, hpFull = Color3.fromRGB(100, 235, 160), hpLow = Color3.fromRGB(255, 105, 120) },
        name = { on = session.state.names, size = 13 },
        dist = { on = session.state.distance, size = 11, suf = "m" },
        hp = { on = session.state.health, side = "left", text = true, pct = false },
        flags = { on = true },
        bones = { on = session.state.skeleton },
        tracer = { on = session.state.playerTracers, from = "bottom" },
        arrow = { on = session.state.arrows, dist = true, fill = true },
        vis = { check = session.state.visibility, hide = session.state.hideOccluded, tint = session.state.visibilityTint, points = 3 },
        chams = { on = false },
        perf = { mode = "manual", entityStep = PERFORMANCE_LEVEL == 1 and 2 or 1, visStep = PERFORMANCE_LEVEL == 1 and 3 or 2, boxStep = 1, toolStep = 10 },
        npc = { on = session.state.monsters, box = { on = session.state.boxes, kind = session.state.boxStyle, col = Color3.fromRGB(255, 75, 85), outline = true, mode = "static", hpFull = Color3.fromRGB(255, 170, 80), hpLow = Color3.fromRGB(255, 70, 100) }, name = { on = session.state.names, size = 13 }, dist = { on = session.state.distance, size = 11, suf = "m" }, hp = { on = session.state.health, side = "left", text = true }, flags = { on = true }, bones = { on = session.state.skeleton }, arrow = { on = session.state.arrows, dist = true }, tracer = { on = session.state.monsterTracers }, vis = { check = session.state.visibility, hide = session.state.hideOccluded, tint = session.state.visibilityTint, points = 3 }, perf = { mode = "manual", npcBoxStep = 1, cullMax = PERFORMANCE_LEVEL == 1 and 50 or PERFORMANCE_LEVEL == 2 and 100 or 140 }, chams = { on = false } },
    }
end

local esp = ESP.new(makeConfig())
session.esp = esp
esp:theme("carbon")
esp:profile(PERFORMANCE_PROFILE)
esp.cfg.box.col = Color3.fromRGB(245, 245, 245)
esp.cfg.box.mode = "static"
esp.cfg.box.fade = false
esp.cfg.name.col = Color3.fromRGB(245, 245, 245)
esp.cfg.dist.col = Color3.fromRGB(245, 245, 245)
esp.cfg.tracer.col = Color3.fromRGB(245, 245, 245)
esp.cfg.arrow.col = Color3.fromRGB(245, 245, 245)
esp.cfg.bones.col = Color3.fromRGB(245, 245, 245)
esp.cfg.flags.col = Color3.fromRGB(245, 245, 245)
esp.cfg.npc.box.col = Color3.fromRGB(255, 75, 85)
esp.cfg.npc.box.mode = "static"
esp.cfg.npc.name.col = Color3.fromRGB(255, 75, 85)
esp.cfg.npc.dist.col = Color3.fromRGB(255, 75, 85)
esp.cfg.npc.tracer.col = Color3.fromRGB(255, 75, 85)
esp.cfg.npc.arrow.col = Color3.fromRGB(255, 75, 85)
esp.cfg.npc.bones.col = Color3.fromRGB(255, 75, 85)
esp.cfg.perf.mode = "manual"
esp.cfg.npc.maxRange = session.state.monsterRange
esp.cfg.npc.espRange = session.state.monsterRange
esp.cfg.perf.entityStep = PERFORMANCE_LEVEL == 1 and 2 or 1
esp.cfg.perf.frameSkip = 0
esp.cfg.perf.boxStep = 1
esp.cfg.perf.visStep = PERFORMANCE_LEVEL == 1 and 3 or 2
esp.cfg.npc.perf.npcBoxStep = 1
esp.cfg.flags.on = true
esp.cfg.npc.flags.on = true
for _, flag in ipairs({ "hp", "tool", "spd", "friend" }) do
    esp:setFlagEnabled(flag, false)
end
esp:setFlagEnabled("vis", session.state.visibility)
esp:setPlayerLabel(function(player)
    return "PLAYER | " .. (player.DisplayName or player.Name)
end)
esp:setNPCSource(function()
    return session.state.monsters and cachedList(npcCache) or {}
end)
esp:setNPCLabel(function(model)
    return "ENEMY | " .. tostring(attribute(model, "Archetype") or attribute(model, "Role") or attribute(model, "Kind") or safeName(model))
end)

local function applyVisibility(enabled)
    session.state.visibility = enabled
    session.state.visibilityTint = enabled
    esp.cfg.vis.check = enabled
    esp.cfg.vis.tint = enabled
    esp.cfg.vis.hide = session.state.hideOccluded and enabled
    esp.cfg.npc.vis.check = enabled
    esp.cfg.npc.vis.tint = enabled
    esp.cfg.npc.vis.hide = session.state.hideOccluded and enabled
    esp:setFlagEnabled("vis", enabled)
end

local function applyHideOccluded(enabled)
    session.state.hideOccluded = enabled
    esp.cfg.vis.hide = enabled and session.state.visibility
    esp.cfg.npc.vis.hide = enabled and session.state.visibility
end

local worldSpecs = {}
local function contentsText(instance)
    local container = instance:FindFirstChild("Contents") or instance:FindFirstChild("Items") or instance:FindFirstChild("Inventory") or instance:FindFirstChild("Loot")
    if not container then
        return nil
    end
    local count = #container:GetChildren()
    return count > 0 and (" [" .. tostring(count) .. "]") or " [empty]"
end

local function addWorld(id, category, prefix, color, stateKey, options)
    stateKey = stateKey or category
    options = options or {}
    worldSpecs[category] = esp:addEnt(id, {
        get = function()
            if not session.state.world or not session.state[stateKey] or (options.masterState and not session.state[options.masterState]) then
                return {}
            end
            return filteredList(worldCaches[category], options.filter)
        end,
        label = function(instance)
            return prefix .. " | " .. safeName(instance) .. (contentsText(instance) or "")
        end,
        col = color,
        boxAllowed = options.box ~= false,
        scale = options.scale or 1,
        box = options.box ~= false and session.state.worldBoxes or false,
        name = session.state.worldNames,
        dist = session.state.worldDistance,
        tracer = session.state.worldTracers,
        hideOccluded = session.state.worldHideOccluded,
        visCheck = session.state.worldHideOccluded,
        dot = true,
        max = session.state.worldRange,
        priority = 2,
    })
end

addWorld("hush_vehicles", "vehicles", "VEHICLE", Color3.fromRGB(100, 200, 255))
addWorld("hush_containers", "containers", "CONTAINER", Color3.fromRGB(255, 175, 65), nil, { filter = function(instance) return containerEnabled(containerKinds[instance] or "other") end })
addWorld("hush_bodies", "bodies", "BODY", Color3.fromRGB(220, 70, 80))
addWorld("hush_mother", "mother", "MOTHER", Color3.fromRGB(255, 35, 35), nil, { scale = 0.75 })
addWorld("hush_pois", "pois", "POI", Color3.fromRGB(255, 210, 90), nil, { box = false, scale = 0.2 })
addWorld("hush_items_weapons", "itemsWeapons", "ITEM | WEAPON", Color3.fromRGB(120, 185, 255), "itemsWeapons", { masterState = "items" })
addWorld("hush_items_ammo", "itemsAmmo", "ITEM | AMMO", Color3.fromRGB(190, 135, 255), "itemsAmmo", { masterState = "items" })
addWorld("hush_items_medical", "itemsMedical", "ITEM | MEDICAL", Color3.fromRGB(110, 235, 150), "itemsMedical", { masterState = "items" })
addWorld("hush_items_rare", "itemsRare", "ITEM | RARE", Color3.fromRGB(255, 220, 75), "itemsRare", { masterState = "items" })
addWorld("hush_items_misc", "itemsMisc", "ITEM | MISC", Color3.fromRGB(185, 185, 195), "itemsMisc", { masterState = "items" })

local function applyWorldVisuals()
    for _, spec in pairs(worldSpecs) do
        spec.box = spec.boxAllowed and session.state.worldBoxes or false
        spec.name = session.state.worldNames
        spec.dist = session.state.worldDistance
        spec.tracer = session.state.worldTracers
        spec.hideOccluded = session.state.worldHideOccluded
        spec.visCheck = session.state.worldHideOccluded
        spec.max = session.state.worldRange
    end
end

local function clearExistingGui()
    local root = gethui and gethui() or (LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"))
    if not root then
        return
    end
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == "HUSH_ESP_GUI" then
            pcall(function()
                child:Destroy()
            end)
        end
    end
end

clearExistingGui()
local ui = UI.new({ name = "HUSH_ESP_GUI", title = "HUSH", separator = " | ", compact = true, customCursor = true, accent = Color3.fromRGB(100, 220, 255), toggleKey = Enum.KeyCode.RightShift, watermark = false, resizable = true })
session.ui = ui
local window = ui:Window("ESP", { x = 30, y = 55, width = 390, height = 520 })

local contextColors = {
    { name = "White", color = Color3.fromRGB(245, 245, 245) },
    { name = "Cyan", color = Color3.fromRGB(100, 200, 255) },
    { name = "Gold", color = Color3.fromRGB(255, 210, 90) },
    { name = "Red", color = Color3.fromRGB(255, 75, 85) },
    { name = "Green", color = Color3.fromRGB(110, 235, 150) },
    { name = "Purple", color = Color3.fromRGB(190, 135, 255) },
    { name = "Orange", color = Color3.fromRGB(255, 165, 70) },
}

local function visualContext(getColor, setColor, getHide, setHide)
    return function()
        local entries = {}
        if getHide and setHide then
            table.insert(entries, { kind = "toggle", text = "Hide occluded", get = getHide, set = setHide })
        end
        if getColor and setColor then
            table.insert(entries, { kind = "color", text = "Color", colors = contextColors, get = getColor, set = setColor })
        end
        return entries
    end
end

local contexts = {
    names = visualContext(function() return esp.cfg.name.col end, function(value) esp.cfg.name.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    boxes = visualContext(function() return esp.cfg.box.col end, function(value) esp.cfg.box.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    health = visualContext(function() return esp.cfg.hp.full end, function(value) esp.cfg.hp.full = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    distance = visualContext(function() return esp.cfg.dist.col end, function(value) esp.cfg.dist.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    tracers = visualContext(function() return esp.cfg.tracer.col end, function(value) esp.cfg.tracer.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    skeleton = visualContext(function() return esp.cfg.bones.col end, function(value) esp.cfg.bones.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    arrows = visualContext(function() return esp.cfg.arrow.col end, function(value) esp.cfg.arrow.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    visibility = visualContext(function() return esp.cfg.box.hpFull end, function(value) esp.cfg.box.hpFull = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsters = visualContext(function() return esp.cfg.npc.box.col end, function(value) esp.cfg.npc.box.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsterNames = visualContext(function() return esp.cfg.npc.name.col end, function(value) esp.cfg.npc.name.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsterHealth = visualContext(function() return esp.cfg.npc.hp.full end, function(value) esp.cfg.npc.hp.full = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsterDistance = visualContext(function() return esp.cfg.npc.dist.col end, function(value) esp.cfg.npc.dist.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsterTracers = visualContext(function() return esp.cfg.npc.tracer.col end, function(value) esp.cfg.npc.tracer.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsterSkeleton = visualContext(function() return esp.cfg.npc.bones.col end, function(value) esp.cfg.npc.bones.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
    monsterArrows = visualContext(function() return esp.cfg.npc.arrow.col end, function(value) esp.cfg.npc.arrow.col = value end, function() return session.state.hideOccluded end, applyHideOccluded),
}

local function worldContext(category)
    return visualContext(function() return worldSpecs[category].col end, function(value) worldSpecs[category].col = value end, function() return session.state.worldHideOccluded end, function(value) session.state.worldHideOccluded = value; applyWorldVisuals() end)
end

local function toggle(section, text, key, callback, context)
    return section:Toggle({ text = text, flag = "hush." .. key, default = session.state[key], callback = callback, context = context })
end

local playersTab = window:Tab("Players")
local playerOverlay = playersTab:Section("Overlay")
local playerGrid = playerOverlay:Grid(2, { gap = 5 })
toggle(playerGrid:Column(1), "Player ESP", "players", function(enabled)
    session.state.players = enabled
    esp.cfg.players.on = enabled
end)
toggle(playerGrid:Column(2), "Names", "names", function(enabled)
    session.state.names = enabled
    esp.cfg.name.on = enabled
    esp.cfg.npc.name.on = enabled
end, contexts.names)
toggle(playerGrid:Column(2), "Boxes", "boxes", function(enabled)
    session.state.boxes = enabled
    esp.cfg.box.on = enabled
    esp.cfg.npc.box.on = enabled
end, contexts.boxes)
toggle(playerGrid:Column(2), "Health", "health", function(enabled)
    session.state.health = enabled
    esp.cfg.hp.on = enabled
    esp.cfg.npc.hp.on = enabled
end, contexts.health)
toggle(playerGrid:Column(1), "Distance", "distance", function(enabled)
    session.state.distance = enabled
    esp.cfg.dist.on = enabled
    esp.cfg.npc.dist.on = enabled
end, contexts.distance)
toggle(playerGrid:Column(2), "Player tracers", "playerTracers", function(enabled)
    session.state.playerTracers = enabled
    esp.cfg.tracer.on = enabled
end, contexts.tracers)
toggle(playerGrid:Column(1), "Skeleton", "skeleton", function(enabled)
    session.state.skeleton = enabled
    esp.cfg.bones.on = enabled
    esp.cfg.npc.bones.on = enabled
end, contexts.skeleton)
toggle(playerGrid:Column(2), "Off-screen arrows", "arrows", function(enabled)
    session.state.arrows = enabled
    esp.cfg.arrow.on = enabled
    esp.cfg.npc.arrow.on = enabled
end, contexts.arrows)
toggle(playerGrid:Column(1), "Visibility checks", "visibility", applyVisibility, contexts.visibility)
toggle(playerGrid:Column(2), "Hide occluded", "hideOccluded", applyHideOccluded)

local playerStyle = playersTab:Section("Appearance")
local styleGrid = playerStyle:Grid(2, { gap = 5 })
styleGrid:Column(1):Dropdown({ text = "Box style", flag = "hush.boxStyle", options = { "corner", "full", "3d", "3dcorner" }, default = session.state.boxStyle, callback = function(value)
    session.state.boxStyle = value
    esp.cfg.box.kind = value
    esp.cfg.npc.box.kind = value
end })
styleGrid:Column(2):Dropdown({ text = "Color mode", flag = "hush.colorMode", options = { "team", "hp", "dist", "static" }, default = session.state.colorMode, callback = function(value)
    session.state.colorMode = value
    esp.cfg.box.mode = value
end })
styleGrid:Column(1):Colorpicker({ text = "Player color", flag = "hush.playerColor", default = esp.cfg.box.col, callback = function(value)
    esp.cfg.box.col = value
end })
styleGrid:Column(2):Colorpicker({ text = "Hidden color", flag = "hush.hiddenColor", default = esp.cfg.box.hpLow, callback = function(value)
    esp.cfg.box.hpLow = value
    esp.cfg.npc.box.hpLow = value
end })
playersTab:Section("Range"):Slider({ text = "Player range", flag = "hush.playerRange", min = 250, max = 5000, step = 250, decimals = 0, default = session.state.playerRange, suffix = "m", callback = function(value)
    session.state.playerRange = value
    esp.cfg.maxRange = value
    esp.cfg.espRange = value
    applyWorldVisuals()
end })

local worldTab = window:Tab("World")
local worldOverlay = worldTab:Section("World objects")
local worldGrid = worldOverlay:Grid(2, { gap = 5 })
toggle(worldGrid:Column(1), "World ESP", "world", function(enabled) session.state.world = enabled end)
toggle(worldGrid:Column(2), "Vehicles", "vehicles", function(enabled) session.state.vehicles = enabled end, worldContext("vehicles"))
toggle(worldGrid:Column(1), "Containers", "containers", function(enabled) session.state.containers = enabled end, worldContext("containers"))
toggle(worldGrid:Column(2), "Bodies", "bodies", function(enabled) session.state.bodies = enabled end, worldContext("bodies"))
toggle(worldGrid:Column(1), "Points of interest", "pois", function(enabled) session.state.pois = enabled end, worldContext("pois"))
toggle(worldGrid:Column(2), "Items", "items", function(enabled) session.state.items = enabled end, worldContext("itemsWeapons"))
toggle(worldGrid:Column(1), "Boxes", "worldBoxes", function(enabled) session.state.worldBoxes = enabled; applyWorldVisuals() end)
toggle(worldGrid:Column(1), "Names", "worldNames", function(enabled) session.state.worldNames = enabled; applyWorldVisuals() end)
toggle(worldGrid:Column(2), "Hide occluded", "worldHideOccluded", function(enabled) session.state.worldHideOccluded = enabled; applyWorldVisuals() end)
toggle(worldGrid:Column(2), "Distance", "worldDistance", function(enabled) session.state.worldDistance = enabled; applyWorldVisuals() end)
toggle(worldGrid:Column(1), "Tracers", "worldTracers", function(enabled) session.state.worldTracers = enabled; applyWorldVisuals() end)
local containerFilter = worldTab:Section("Container filters")
local containerFilterGrid = containerFilter:Grid(2, { gap = 5 })
toggle(containerFilterGrid:Column(1), "Drawers", "containerDrawers", function(enabled) session.state.containerDrawers = enabled end)
toggle(containerFilterGrid:Column(2), "Fridges", "containerFridges", function(enabled) session.state.containerFridges = enabled end)
toggle(containerFilterGrid:Column(1), "Cabinets and shelves", "containerCabinets", function(enabled) session.state.containerCabinets = enabled end)
toggle(containerFilterGrid:Column(2), "Crates and chests", "containerCrates", function(enabled) session.state.containerCrates = enabled end)
toggle(containerFilterGrid:Column(1), "Lockers", "containerLockers", function(enabled) session.state.containerLockers = enabled end)
toggle(containerFilterGrid:Column(2), "Vehicle cargo", "containerVehicles", function(enabled) session.state.containerVehicles = enabled end)
toggle(containerFilterGrid:Column(1), "Other containers", "containerOther", function(enabled) session.state.containerOther = enabled end)
local itemSection = worldTab:Section("Floor items")
local itemStatus = itemSection:Label("Viewing: Weapons")
itemSection:Dropdown({ text = "View category", flag = "hush.itemCategory", options = { "Weapons", "Ammo", "Medical", "Rare", "Misc" }, default = "Weapons", callback = function(value) itemStatus:Set("Viewing: " .. tostring(value)) end })
local itemFilterGrid = itemSection:Grid(2, { gap = 5 })
toggle(itemFilterGrid:Column(1), "Weapons", "itemsWeapons", function(enabled) session.state.itemsWeapons = enabled end, worldContext("itemsWeapons"))
toggle(itemFilterGrid:Column(2), "Ammo", "itemsAmmo", function(enabled) session.state.itemsAmmo = enabled end, worldContext("itemsAmmo"))
toggle(itemFilterGrid:Column(1), "Medical", "itemsMedical", function(enabled) session.state.itemsMedical = enabled end, worldContext("itemsMedical"))
toggle(itemFilterGrid:Column(2), "Rare and access cards", "itemsRare", function(enabled) session.state.itemsRare = enabled end, worldContext("itemsRare"))
toggle(itemFilterGrid:Column(1), "Miscellaneous", "itemsMisc", function(enabled) session.state.itemsMisc = enabled end, worldContext("itemsMisc"))
itemSection:Label("Verified floor-item groups: weapons, ammo, medical, rare/access cards, and miscellaneous pickups.")
local worldStyle = worldTab:Section("Color coding")
local worldColors = worldStyle:Grid(2, { gap = 5 })
worldColors:Column(1):Colorpicker({ text = "Vehicle color", flag = "hush.vehicleColor", default = worldSpecs.vehicles.col, callback = function(value) worldSpecs.vehicles.col = value end })
worldColors:Column(2):Colorpicker({ text = "Container color", flag = "hush.containerColor", default = worldSpecs.containers.col, callback = function(value) worldSpecs.containers.col = value end })
worldColors:Column(1):Colorpicker({ text = "Body color", flag = "hush.bodyColor", default = worldSpecs.bodies.col, callback = function(value) worldSpecs.bodies.col = value end })
worldColors:Column(2):Colorpicker({ text = "POI color", flag = "hush.poiColor", default = worldSpecs.pois.col, callback = function(value) worldSpecs.pois.col = value end })
worldColors:Column(1):Colorpicker({ text = "Weapon item color", flag = "hush.weaponItemColor", default = worldSpecs.itemsWeapons.col, callback = function(value) worldSpecs.itemsWeapons.col = value end })
worldColors:Column(2):Colorpicker({ text = "Ammo item color", flag = "hush.ammoItemColor", default = worldSpecs.itemsAmmo.col, callback = function(value) worldSpecs.itemsAmmo.col = value end })
worldColors:Column(1):Colorpicker({ text = "Medical item color", flag = "hush.medicalItemColor", default = worldSpecs.itemsMedical.col, callback = function(value) worldSpecs.itemsMedical.col = value end })
worldColors:Column(2):Colorpicker({ text = "Rare item color", flag = "hush.rareItemColor", default = worldSpecs.itemsRare.col, callback = function(value) worldSpecs.itemsRare.col = value end })
worldTab:Section("Range"):Slider({ text = "World range", flag = "hush.worldRange", min = 250, max = 5000, step = 250, decimals = 0, default = session.state.worldRange, suffix = "m", callback = function(value)
    session.state.worldRange = value
    applyWorldVisuals()
end })
worldTab:Section("Performance"):Label("World entities use an event-fed cache and a throttled entity pass instead of rescanning Workspace every frame.")

local monstersTab = window:Tab("Monsters")
local monsterOverlay = monstersTab:Section("Humanoid monsters")
local monsterGrid = monsterOverlay:Grid(2, { gap = 5 })
toggle(monsterGrid:Column(1), "Monster ESP", "monsters", function(enabled) session.state.monsters = enabled; esp.cfg.npc.on = enabled end, contexts.monsters)
toggle(monsterGrid:Column(2), "Boxes", "boxes", function(enabled) session.state.boxes = enabled; esp.cfg.npc.box.on = enabled end, contexts.monsters)
toggle(monsterGrid:Column(2), "Names", "names", function(enabled) session.state.names = enabled; esp.cfg.npc.name.on = enabled end, contexts.monsterNames)
toggle(monsterGrid:Column(1), "Health", "health", function(enabled) session.state.health = enabled; esp.cfg.npc.hp.on = enabled end, contexts.monsterHealth)
toggle(monsterGrid:Column(2), "Distance", "distance", function(enabled) session.state.distance = enabled; esp.cfg.npc.dist.on = enabled end, contexts.monsterDistance)
toggle(monsterGrid:Column(1), "Monster tracers", "monsterTracers", function(enabled) session.state.monsterTracers = enabled; esp.cfg.npc.tracer.on = enabled end, contexts.monsterTracers)
toggle(monsterGrid:Column(2), "Skeleton", "skeleton", function(enabled) session.state.skeleton = enabled; esp.cfg.npc.bones.on = enabled end, contexts.monsterSkeleton)
toggle(monsterGrid:Column(1), "Off-screen arrows", "arrows", function(enabled) session.state.arrows = enabled; esp.cfg.npc.arrow.on = enabled end, contexts.monsterArrows)
toggle(monsterGrid:Column(2), "Visibility checks", "visibility", function(enabled) applyVisibility(enabled) end, contexts.visibility)
local specialMonster = monstersTab:Section("Special enemies")
local specialMonsterGrid = specialMonster:Grid(2, { gap = 5 })
toggle(specialMonsterGrid:Column(1), "Mother", "mother", function(enabled) session.state.mother = enabled end, worldContext("mother"))
local monsterStyle = monstersTab:Section("Appearance")
local monsterStyleGrid = monsterStyle:Grid(2, { gap = 5 })
monsterStyleGrid:Column(1):Dropdown({ text = "Box style", flag = "hush.monsterBoxStyle", options = { "corner", "full", "3d", "3dcorner" }, default = session.state.boxStyle, callback = function(value) esp.cfg.npc.box.kind = value end })
monsterStyleGrid:Column(2):Colorpicker({ text = "Monster color", flag = "hush.monsterNpcColor", default = esp.cfg.npc.box.col, callback = function(value) esp.cfg.npc.box.col = value end })
monstersTab:Section("Range"):Slider({ text = "Monster range", flag = "hush.monsterRange", min = 250, max = 5000, step = 250, decimals = 0, default = session.state.monsterRange, suffix = "m", callback = function(value)
    session.state.monsterRange = value
    esp.cfg.npc.maxRange = value
    esp.cfg.npc.espRange = value
end })
monstersTab:Section("Target state"):Label("Target identity is shown only when the game exposes a client-readable target field; no target claim is generated when it is unavailable.")

local status = playersTab:Section("Status")
local statusLabel = status:Label("Loading")
local countLabel = status:Label("Counts")
toggle(status, "Custom cursor", "customCursor", function(enabled) session.state.customCursor = enabled; ui:SetCursorVisible(enabled) end)
status:Button({ text = "Unload", callback = function() if session.unload then session.unload() end end })

local elapsed = 0
track(RunService.Heartbeat:Connect(function(dt)
    if session.unloaded then
        return
    end
    elapsed += dt
    if elapsed < 0.5 then
        return
    end
    elapsed = 0
    local stats = esp:getStats()
    statusLabel:Set("FPS " .. formatNumber(stats.fpsAvg or stats.fps or 0) .. " | Performance " .. tostring(PERFORMANCE_LEVEL))
    countLabel:Set("Players " .. tostring(#Players:GetPlayers()) .. " | Monsters " .. tostring(#cachedList(npcCache)) .. " | Drawn " .. tostring(stats.drawn or 0) .. " | Entities " .. tostring(stats.ents or 0))
end))

function session.snapshot()
    local stats = esp:getStats()
    local itemCount = #cachedList(worldCaches.itemsWeapons) + #cachedList(worldCaches.itemsAmmo) + #cachedList(worldCaches.itemsMedical) + #cachedList(worldCaches.itemsRare) + #cachedList(worldCaches.itemsMisc)
    return "hush_esp players=" .. tostring(#Players:GetPlayers()) .. " monsters=" .. tostring(#cachedList(npcCache)) .. " drawn=" .. tostring(stats.drawn or 0) .. " entities=" .. tostring(stats.ents or 0) .. " vehicles=" .. tostring(#cachedList(worldCaches.vehicles)) .. " containers=" .. tostring(#cachedList(worldCaches.containers)) .. " bodies=" .. tostring(#cachedList(worldCaches.bodies)) .. " mother=" .. tostring(#cachedList(worldCaches.mother)) .. " pois=" .. tostring(#cachedList(worldCaches.pois)) .. " items=" .. tostring(itemCount) .. " playerRange=" .. tostring(session.state.playerRange) .. " worldRange=" .. tostring(session.state.worldRange) .. " monsterRange=" .. tostring(session.state.monsterRange) .. " performance=" .. tostring(PERFORMANCE_LEVEL)
end

function session.unload()
    if session.unloaded then
        return
    end
    session.unloaded = true
    disconnectAll()
    pcall(function()
        esp:destroy()
    end)
    pcall(function()
        ui:Destroy()
    end)
    if GENV[SLOT] == session then
        GENV[SLOT] = nil
    end
end

GENV[SLOT] = session
esp:start()
ui:SetVisible(false)
ui:Notify({ title = "HUSH | ESP", text = "Optimized read-only ESP loaded. RightShift opens controls.", kind = "ok", duration = 4 })
print("[HUSH_ESP_OK] " .. session.snapshot())