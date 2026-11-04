local GENV = (getgenv and getgenv()) or shared or _G
local SLOT = "__SOD_OBSERVER"
local previous = GENV[SLOT]
if type(previous) == "table" and type(previous.unload) == "function" then
    pcall(previous.unload)
end

local function loadLibrary(fileName, remotePath)
    local function valid(source)
        return type(source) == "string" and #source > 0
    end
    local source
    if type(readfile) == "function" then
        local ok, cached = pcall(readfile, fileName)
        if ok and valid(cached) then
            source = cached
        end
    end
    if not source then
        local url = "https://raw.githubusercontent.com/ToiletStarter/RblxGameScripts/refs/heads/main/" .. remotePath
        local ok, remote = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and valid(remote) then
            source = remote
        end
    end
    assert(source, "library load failed: " .. fileName)
    local chunk = assert(loadstring(source, "=" .. fileName))
    return assert(chunk())
end

local function safeName(instance)
    local ok, value = pcall(function()
        return instance.Name
    end)
    return ok and tostring(value) or "Unknown"
end

local function attr(instance, name)
    if not instance then
        return nil
    end
    local ok, value = pcall(function()
        return instance:GetAttribute(name)
    end)
    return ok and value or nil
end

local function allAttrs(instance)
    local ok, value = pcall(function()
        return instance:GetAttributes()
    end)
    return ok and value or {}
end

local function basePart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        if instance.PrimaryPart then
            return instance.PrimaryPart
        end
        local root = instance:FindFirstChild("HumanoidRootPart", true)
        if root and root:IsA("BasePart") then
            return root
        end
    end
    if instance:IsA("Tool") then
        local handle = instance:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            return handle
        end
    end
    for _, child in ipairs(instance:GetDescendants()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

local function objectPosition(instance)
    local part = basePart(instance)
    return part and part.Position or nil
end

local function entityObject(instance)
    return (instance:IsA("Model") or instance:IsA("BasePart") or instance:IsA("Tool")) and instance or nil
end

local function textValue(value, fallback)
    if value == nil then
        return fallback
    end
    local text = tostring(value)
    if text == "" then
        return fallback
    end
    return text:gsub("\n", " "):sub(1, 120)
end

local function setLabelText(label, text)
    if type(label) == "table" and type(label.Set) == "function" then
        pcall(label.Set, label, text)
        return
    end
    pcall(function()
        label.Text = tostring(text)
    end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer

local ESP = loadLibrary("EasyESP.luau", "libs/EasyESP.luau")
local UI = loadLibrary("EasyUi_style_2.luau", "libs/EasyUi_style_2.luau")

local session = {
    unloaded = false,
    connections = {},
    state = {
        master = false,
        players = false,
        boxes = false,
        names = false,
        health = false,
        distance = false,
        arrows = false,
        skeleton = false,
        tracers = false,
        radar = false,
        list = false,
        loot = false,
        exits = false,
        entity = false,
        entityPath = false,
        entityHud = false,
        debugRoute = false,
        detail = false,
        nameMode = "display",
        playerRange = 1800,
        lootRange = 2500,
        exitRange = 3500,
        trailMax = 80,
        prediction = 1.5,
        refresh = 0.35,
    },
    lootObjects = {},
    exitObjects = {},
    rangeSpecs = {},
    entity = nil,
    trail = {},
    lastEntityPosition = nil,
    lastTrailAt = 0,
    nextRefresh = 0,
}

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

local function entityCandidates()
    local result = {}
    local seen = {}
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and not seen[child] then
            local kind = attr(child, "EntityKind")
            local owner = attr(child, "PlayerEntity")
            if kind ~= nil or owner ~= nil or attr(child, "HeardByMe") ~= nil then
                seen[child] = true
                table.insert(result, child)
            end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and not seen[character] then
            local kind = attr(character, "EntityKind")
            local owner = attr(character, "PlayerEntity")
            if kind ~= nil or owner ~= nil or attr(character, "HeardByMe") ~= nil then
                seen[character] = true
                table.insert(result, character)
            end
        end
    end
    return result
end

local function targetText(model)
    local names = { "Target", "TargetName", "TargetPlayer", "TargetUserId", "Focus", "FocusName", "FocusUserId", "HuntTarget" }
    for _, name in ipairs(names) do
        local value = attr(model, name)
        if value ~= nil then
            if typeof(value) == "Instance" and value:IsA("Player") then
                return value.DisplayName or value.Name
            end
            local numeric = tonumber(value)
            if numeric then
                local player = Players:GetPlayerByUserId(numeric)
                if player then
                    return player.DisplayName or player.Name
                end
            end
            return textValue(value, "unknown")
        end
    end
    return "unknown"
end

local function ownerText(model)
    local value = attr(model, "PlayerEntity")
    local numeric = tonumber(value)
    if numeric then
        local player = Players:GetPlayerByUserId(numeric)
        if player then
            return player.DisplayName or player.Name
        end
        return tostring(numeric)
    end
    return textValue(value, "unknown")
end

local function entityInfo()
    local candidates = entityCandidates()
    local model = candidates[1]
    if not model then
        session.entity = nil
        return nil
    end
    local root = model:FindFirstChild("HumanoidRootPart") or basePart(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    local data = {
        model = model,
        root = root,
        humanoid = hum,
        kind = textValue(attr(model, "EntityKind"), safeName(model)),
        state = textValue(attr(model, "State"), "unknown"),
        target = targetText(model),
        owner = ownerText(model),
        stimulus = textValue(attr(model, "Stimulus"), "unknown"),
        nav = textValue(attr(model, "Nav"), "unknown"),
        route = textValue(attr(model, "DbgRoute"), "unknown"),
        guess = textValue(attr(model, "DbgGuess"), "unknown"),
        guessTop = textValue(attr(model, "DbgGuessTop"), "unknown"),
        aware = textValue(attr(model, "DbgAwareAtHide"), "unknown"),
        hideWatch = textValue(attr(model, "DbgHideWatch"), "unknown"),
        heard = attr(model, "HeardByMe") == true,
        seenAgo = attr(model, "DbgSeenAgo"),
        velocity = root and root.AssemblyLinearVelocity or Vector3.new(),
        position = root and root.Position or nil,
        moveDirection = hum and hum.MoveDirection or Vector3.new(),
        walkTo = hum and hum.WalkToPoint or Vector3.new(),
    }
    session.entity = data
    return data
end

local function collectLoot()
    local result = {}
    local seen = {}
    for _, rootName in ipairs({ "LootItems", "MyLoot", "Corpses", "Gadgets" }) do
        local root = Workspace:FindFirstChild(rootName)
        if root then
            for _, child in ipairs(root:GetChildren()) do
                if not seen[child] and (attr(child, "Loot") == true or attr(child, "Dropped") == true or rootName == "Corpses") then
                    local object = entityObject(child)
                    if object then
                        seen[object] = true
                        table.insert(result, object)
                    end
                end
            end
        end
    end
    return result
end

local function collectExits()
    local result = {}
    local seen = {}
    local activeMap = Workspace:FindFirstChild("ActiveMap")
    if activeMap then
        for _, child in ipairs(activeMap:GetDescendants()) do
            if child:IsA("BasePart") and (attr(child, "ExitPoint") == true or child.Name == "Exit Box") then
                if not seen[child] then
                    seen[child] = true
                    table.insert(result, child)
                end
            elseif child:IsA("Model") and child.Name == "Exit Sign - Lit" and not seen[child] then
                seen[child] = true
                table.insert(result, child)
            end
        end
    end
    return result
end

local function lootLabel(instance)
    local key = attr(instance, "ItemKey") or safeName(instance)
    local owner = attr(instance, "CorpseOwner")
    local prefix = owner and "CORPSE | " .. tostring(owner) or "LOOT | " .. tostring(key)
    local rarity = attr(instance, "Rarity")
    local value = attr(instance, "Value")
    local weight = attr(instance, "Weight")
    local text = prefix
    if rarity then
        text = text .. " | " .. tostring(rarity)
    end
    if value then
        text = text .. " | $" .. tostring(value)
    end
    if weight then
        text = text .. " | " .. tostring(weight) .. "kg"
    end
    return text
end

local function exitLabel(instance)
    local name = safeName(instance)
    if name == "Exit Box" or name == "ExitPoint" then
        name = "Exit"
    end
    return "EXIT | " .. name
end

local function lootDescription(instance)
    if not session.state.detail then
        return nil
    end
    local parts = {}
    local xp = attr(instance, "XP")
    local spot = attr(instance, "SpotId")
    if xp then
        table.insert(parts, "XP " .. tostring(xp))
    end
    if spot then
        table.insert(parts, tostring(spot))
    end
    return #parts > 0 and table.concat(parts, " | ") or nil
end

local function refreshObjects()
    session.lootObjects = collectLoot()
    session.exitObjects = collectExits()
end

local function trackEntity(dt)
    local info = entityInfo()
    if not info or not info.position then
        session.trail = {}
        session.lastEntityPosition = nil
        return
    end
    session.lastTrailAt += dt
    if session.lastTrailAt < 0.1 then
        return
    end
    session.lastTrailAt = 0
    if not session.lastEntityPosition or (info.position - session.lastEntityPosition).Magnitude >= 0.5 then
        table.insert(session.trail, { position = info.position, time = os.clock() })
        session.lastEntityPosition = info.position
        while #session.trail > session.state.trailMax do
            table.remove(session.trail, 1)
        end
    end
end

refreshObjects()

local esp = ESP.new({
    on = false,
    maxRange = session.state.playerRange,
    espRange = session.state.playerRange,
    players = { on = false },
    box = { on = false, kind = "corner", outline = true, fill = false, mode = "hp", fade = true },
    name = { on = false, mode = session.state.nameMode, size = 13 },
    dist = { on = false, size = 11, suf = "m" },
    hp = { on = false, side = "left", text = true, pct = false },
    flags = { on = false, side = "right", size = 10, gap = 1 },
    bones = { on = false },
    tracer = { on = false, from = "bottom" },
    arrow = { on = false, dist = true, fill = true },
    vis = { check = false, hide = false, tint = false, points = 3 },
    radar = { on = false, range = 900, names = false, max = 24 },
    list = { on = false, max = 12, hp = true, dist = true, vis = false },
    chams = { on = false },
    npc = { on = false },
    perf = { mode = "auto", entityStep = 2, npcBoxStep = 4, toolStep = 8 },
})
session.esp = esp
esp:theme("carbon")
esp:profile("balanced")

esp:setPlayerLabel(function(player)
    local character = player.Character
    local kind = character and attr(character, "EntityKind")
    local name
    if session.state.nameMode == "username" then
        name = player.Name
    elseif session.state.nameMode == "both" then
        name = (player.DisplayName or player.Name) .. " (" .. player.Name .. ")"
    else
        name = player.DisplayName or player.Name
    end
    if kind then
        return name .. " [ENTITY]"
    end
    return name
end)

esp:flag("sod_role", function(snapshot)
    local character = snapshot.char
    local kind = character and attr(character, "EntityKind")
    if kind then
        return { "ENTITY " .. tostring(kind), Color3.fromRGB(255, 110, 125) }
    end
    return nil
end)

esp:flag("sod_state", function(snapshot)
    local character = snapshot.char
    if not character then
        return nil
    end
    local state = attr(character, "State")
    local stimulus = attr(character, "Stimulus")
    if state then
        local text = tostring(state)
        if stimulus then
            text = text .. " / " .. tostring(stimulus)
        end
        return { text, Color3.fromRGB(255, 210, 120) }
    end
    return nil
end)

esp:flag("sod_heard", function(snapshot)
    local character = snapshot.char
    if character and attr(character, "HeardByMe") == true then
        return { "HEARD", Color3.fromRGB(255, 170, 90) }
    end
    return nil
end)

esp:setFlagEnabled("sod_role", true)
esp:setFlagEnabled("sod_state", true)
esp:setFlagEnabled("sod_heard", true)

session.rangeSpecs.loot = esp:addEnt("sod_loot", {
    get = function()
        return session.state.loot and session.lootObjects or {}
    end,
    label = lootLabel,
    col = Color3.fromRGB(120, 255, 190),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = session.state.lootRange,
    priority = 3,
    draw = function(e, id, object, _, x, y, w, h)
        local detail = lootDescription(object)
        if detail then
            e.pool:txt("sod_loot_detail_" .. id, detail, x + w * 0.5, y + h + 12, 9, Color3.fromRGB(190, 220, 205), true)
        end
    end,
})

session.rangeSpecs.exits = esp:addEnt("sod_exits", {
    get = function()
        return session.state.exits and session.exitObjects or {}
    end,
    label = exitLabel,
    col = Color3.fromRGB(100, 220, 255),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = session.state.exitRange,
    priority = 4,
})

local function nearestExit()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end
    local best
    local bestDistance
    for _, object in ipairs(session.exitObjects) do
        local position = objectPosition(object)
        if position then
            local distance = (root.Position - position).Magnitude
            if not bestDistance or distance < bestDistance then
                best = object
                bestDistance = distance
            end
        end
    end
    return best, bestDistance
end

local function entityHudText(info)
    if not info then
        return "ENTITY | none observed"
    end
    local text = "ENTITY " .. tostring(info.kind) .. " | " .. tostring(info.state)
    text = text .. " | target " .. tostring(info.target)
    text = text .. " | " .. tostring(info.stimulus)
    if info.heard then
        text = text .. " | HEARD"
    end
    return text
end

local function entityRouteText(info)
    if not info then
        return "route unknown"
    end
    if info.nav ~= "unknown" then
        return "NAV " .. info.nav
    end
    if info.route ~= "unknown" then
        return "ROUTE " .. info.route
    end
    return "ROUTE observed trail only"
end

esp:mod({
    name = "sod_observer_hud",
    on = true,
    screen = function(state, e)
        local s = state.session
        local info = s.entity
        if s.state.entityHud then
            e.pool:txt("sod_entity_hud", entityHudText(info), 18, 18, 13, info and Color3.fromRGB(255, 130, 145) or Color3.fromRGB(170, 180, 195), false)
            e.pool:txt("sod_entity_route", entityRouteText(info), 18, 36, 11, Color3.fromRGB(220, 190, 140), false)
        end
        if s.state.entityPath and info and info.position then
            local lastX, lastY, lastDepth
            for i, point in ipairs(s.trail) do
                local x, y, depth = e:project(point.position)
                if lastX and lastDepth > 0 and depth > 0 then
                    local alpha = 0.25 + 0.65 * (i / math.max(#s.trail, 1))
                    e.pool:line("sod_path_" .. i, lastX, lastY, x, y, Color3.fromRGB(255, 120, 135), 2, alpha, 11)
                end
                if depth > 0 then
                    e.pool:dot("sod_path_dot_" .. i, x, y, 2, Color3.fromRGB(255, 170, 150), true, 0.7, 10, 1, 11)
                end
                lastX, lastY, lastDepth = x, y, depth
            end
            local velocity = info.velocity
            if velocity.Magnitude > 0.1 and s.state.prediction > 0 then
                local px, py, pd = e:project(info.position + velocity * s.state.prediction)
                local sx, sy, sd = e:project(info.position)
                if sd > 0 and pd > 0 then
                    e.pool:line("sod_prediction", sx, sy, px, py, Color3.fromRGB(255, 220, 110), 2, 0.95, 12)
                    e.pool:dot("sod_prediction_dot", px, py, 4, Color3.fromRGB(255, 220, 110), true, 0.95, 16, 1, 12)
                end
            end
        end
        local exit, distance = nearestExit()
        if s.state.exits and exit and distance then
            e.pool:txt("sod_exit_hud", "EXIT " .. exitLabel(exit) .. " | " .. tostring(math.floor(distance + 0.5)) .. "m", 18, 56, 12, Color3.fromRGB(105, 225, 255), false)
        end
    end,
})

local UIInstance = UI.new({
    title = "Steal Or Die Observer",
    name = "SOD_Observer_Style2",
    accent = Color3.fromRGB(100, 220, 255),
    toggleKey = Enum.KeyCode.RightShift,
    watermark = false,
    customCursor = false,
    resizable = true,
})
session.ui = UIInstance

local function bindToggle(section, text, key, default, callback, context)
    return section:Toggle({
        text = text,
        flag = "sod." .. key,
        default = default,
        callback = callback,
        context = context,
    })
end

local function rangeContext(text, get, set)
    return function()
        return {
            {
                kind = "slider",
                text = text,
                min = 250,
                max = 6000,
                step = 250,
                suffix = "m",
                get = get,
                set = set,
            },
        }
    end
end

local visuals = UIInstance:Window("Visuals", { x = 28, y = 66, width = 315, height = 410 })
local playerSection = visuals:Tab("Players"):Section("Player ESP")
playerSection:Label("All overlays start disabled. Enable the master switch first.")
bindToggle(playerSection, "Enable overlays", "master", session.state.master, function(value)
    session.state.master = value
    esp.cfg.on = value
end)
bindToggle(playerSection, "Players", "players", session.state.players, function(value)
    session.state.players = value
    esp.cfg.players.on = value
end, rangeContext("Player range", function()
    return session.state.playerRange
end, function(value)
    session.state.playerRange = value
    esp.cfg.maxRange = value
    esp.cfg.espRange = value
end))
bindToggle(playerSection, "Boxes", "boxes", session.state.boxes, function(value)
    session.state.boxes = value
    esp.cfg.box.on = value
end)
bindToggle(playerSection, "Names", "names", session.state.names, function(value)
    session.state.names = value
    esp.cfg.name.on = value
end)
bindToggle(playerSection, "Health", "health", session.state.health, function(value)
    session.state.health = value
    esp.cfg.hp.on = value
end)
bindToggle(playerSection, "Distance", "distance", session.state.distance, function(value)
    session.state.distance = value
    esp.cfg.dist.on = value
end)
bindToggle(playerSection, "Off-screen arrows", "arrows", session.state.arrows, function(value)
    session.state.arrows = value
    esp.cfg.arrow.on = value
end)
bindToggle(playerSection, "Skeleton", "skeleton", session.state.skeleton, function(value)
    session.state.skeleton = value
    esp.cfg.bones.on = value
end)
bindToggle(playerSection, "Tracers", "tracers", session.state.tracers, function(value)
    session.state.tracers = value
    esp.cfg.tracer.on = value
end)
bindToggle(playerSection, "Radar", "radar", session.state.radar, function(value)
    session.state.radar = value
    esp.cfg.radar.on = value
end)
bindToggle(playerSection, "Player list", "list", session.state.list, function(value)
    session.state.list = value
    esp.cfg.list.on = value
end)
playerSection:Dropdown({
    text = "Player name",
    flag = "sod.nameMode",
    options = { "display", "username", "both" },
    default = session.state.nameMode,
    callback = function(value)
        session.state.nameMode = value
        esp.cfg.name.mode = value
    end,
})
playerSection:Dropdown({
    text = "Box style",
    flag = "sod.box",
    options = { "corner", "full", "3d", "3dcorner" },
    default = "corner",
    callback = function(value)
        esp.cfg.box.kind = value
    end,
})
playerSection:Label("Right-click any option for its range, keybind, and control menu.")

local world = UIInstance:Window("World", { x = 360, y = 66, width = 315, height = 330 })
local worldSection = world:Tab("Markers"):Section("World objects")
bindToggle(worldSection, "Loot items", "loot", session.state.loot, function(value)
    session.state.loot = value
end, rangeContext("Loot range", function()
    return session.state.lootRange
end, function(value)
    session.state.lootRange = value
    session.rangeSpecs.loot.max = value
end))
bindToggle(worldSection, "Exit markers", "exits", session.state.exits, function(value)
    session.state.exits = value
end, rangeContext("Exit range", function()
    return session.state.exitRange
end, function(value)
    session.state.exitRange = value
    session.rangeSpecs.exits.max = value
end))
bindToggle(worldSection, "Item detail", "detail", session.state.detail, function(value)
    session.state.detail = value
end)
bindToggle(worldSection, "Entity HUD", "entityHud", session.state.entityHud, function(value)
    session.state.entityHud = value
end)
bindToggle(worldSection, "Observed entity path", "entityPath", session.state.entityPath, function(value)
    session.state.entityPath = value
end)
bindToggle(worldSection, "Debug route text", "debugRoute", session.state.debugRoute, function(value)
    session.state.debugRoute = value
end)
worldSection:Label("Right-click any option for its range, keybind, and control menu.")
worldSection:Label("No movement, world transparency, fullbright, remote calls, or input automation are included.")
worldSection:Button({
    text = "Rescan loot and exits",
    callback = refreshObjects,
})

local entityWindow = UIInstance:Window("Entity", { x = 692, y = 66, width = 330, height = 340 })
local entitySection = entityWindow:Tab("Tracking"):Section("Passive entity telemetry")
local entityLabel = entitySection:Label("Entity: none")
local stateLabel = entitySection:Label("State: unknown")
local targetLabel = entitySection:Label("Target: unknown")
local navLabel = entitySection:Label("Nav: unknown")
local routeLabel = entitySection:Label("Route: unknown")
entitySection:Slider({
    text = "Trail points",
    flag = "sod.trailMax",
    min = 10,
    max = 160,
    step = 5,
    decimals = 0,
    default = session.state.trailMax,
    callback = function(value)
        session.state.trailMax = value
        while #session.trail > value do
            table.remove(session.trail, 1)
        end
    end,
})
entitySection:Slider({
    text = "Prediction seconds",
    flag = "sod.prediction",
    min = 0,
    max = 4,
    step = 0.1,
    decimals = 1,
    default = session.state.prediction,
    callback = function(value)
        session.state.prediction = value
    end,
})
entitySection:Button({
    text = "Clear observed trail",
    callback = function()
        session.trail = {}
        session.lastEntityPosition = nil
    end,
})

local statusWindow = UIInstance:Window("Status", { x = 28, y = 492, width = 315, height = 230 })
local statusSection = statusWindow:Tab("Observer"):Section("Live state")
local statusLabel = statusSection:Label("Loading")
local countLabel = statusSection:Label("Counts")
local exitLabelState = statusSection:Label("Exit")
statusSection:Button({
    text = "Refresh now",
    callback = function()
        refreshObjects()
        entityInfo()
    end,
})
statusSection:Button({
    text = "Unload observer",
    callback = function()
        if type(session.unload) == "function" then
            session.unload()
        end
    end,
})

local function countArray(value)
    return value and #value or 0
end

local function updateLabels()
    local info = session.entity
    if info then
        setLabelText(entityLabel, "Entity: " .. tostring(info.kind) .. " | owner " .. tostring(info.owner))
        setLabelText(stateLabel, "State: " .. tostring(info.state) .. " | stimulus " .. tostring(info.stimulus) .. (info.heard and " | heard" or ""))
        setLabelText(targetLabel, "Target: " .. tostring(info.target))
        setLabelText(navLabel, "Nav: " .. tostring(info.nav))
        setLabelText(routeLabel, "Route: " .. (session.state.debugRoute and tostring(info.route) or "hidden"))
        setLabelText(statusLabel, "Entity " .. tostring(info.kind) .. " | " .. tostring(info.state) .. " | trail " .. tostring(#session.trail))
    else
        setLabelText(entityLabel, "Entity: none")
        setLabelText(stateLabel, "State: unknown")
        setLabelText(targetLabel, "Target: unknown")
        setLabelText(navLabel, "Nav: unknown")
        setLabelText(routeLabel, "Route: unknown")
        setLabelText(statusLabel, "Entity none | trail 0")
    end
    setLabelText(countLabel, "Players " .. tostring(#Players:GetPlayers()) .. " | Loot " .. tostring(countArray(session.lootObjects)) .. " | Exits " .. tostring(countArray(session.exitObjects)))
    local exit, distance = nearestExit()
    setLabelText(exitLabelState, exit and ("Nearest exit " .. exitLabel(exit) .. " | " .. tostring(math.floor(distance + 0.5)) .. "m") or "Nearest exit unknown")
end

local accumulator = 0
track(RunService.Heartbeat:Connect(function(dt)
    if session.unloaded then
        return
    end
    accumulator += dt
    trackEntity(dt)
    if accumulator >= session.state.refresh then
        accumulator = 0
        refreshObjects()
        updateLabels()
    end
end))

function session.snapshot()
    local info = session.entity
    local exit, distance = nearestExit()
    local lines = {
        "place=Steal Or Die observer=read-only players=" .. tostring(#Players:GetPlayers()),
        "loot=" .. tostring(#session.lootObjects) .. " exits=" .. tostring(#session.exitObjects) .. " trail=" .. tostring(#session.trail),
    }
    if info then
        table.insert(lines, "entity=" .. tostring(info.kind) .. " state=" .. tostring(info.state) .. " target=" .. tostring(info.target) .. " stimulus=" .. tostring(info.stimulus) .. " heard=" .. tostring(info.heard))
        table.insert(lines, "nav=" .. tostring(info.nav) .. " route=" .. tostring(info.route))
    else
        table.insert(lines, "entity=none")
    end
    if exit and distance then
        table.insert(lines, "exit=" .. exitLabel(exit) .. " distance=" .. tostring(math.floor(distance + 0.5)))
    end
    return table.concat(lines, "\n")
end

function session.rescan()
    refreshObjects()
    entityInfo()
    updateLabels()
    return session.snapshot()
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
        UIInstance:Destroy()
    end)
    if GENV[SLOT] == session then
        GENV[SLOT] = nil
    end
end

GENV[SLOT] = session
UIInstance:SetVisible(false)
updateLabels()
esp:start()
print("[SOD_OBSERVER_OK] read-only observer loaded")
print(session.snapshot())