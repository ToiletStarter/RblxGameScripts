local GENV = (getgenv and getgenv()) or shared or _G
local SLOT = "__PZ_ESP"
local previous = GENV[SLOT]
if type(previous) == "table" and type(previous.unload) == "function" then
    pcall(previous.unload)
end

local function loadLibrary(path)
    local base = "https://raw.githubusercontent.com/ToiletStarter/RblxGameScripts/refs/heads/main/"
    local function valid(source)
        if type(source) ~= "string" or #source == 0 then
            return false
        end
        if path == "EasyESP.luau" then
            return source:find("Drawing", 1, true) ~= nil and source:find("ESP", 1, true) ~= nil
        end
        return source:find("style_2", 1, true) ~= nil and source:find("UI", 1, true) ~= nil
    end
    local source
    local fetched, remote = pcall(function()
        return game:HttpGet(base .. "libs/" .. path)
    end)
    if fetched and valid(remote) then
        source = remote
    end
    if type(readfile) == "function" then
        if not source then
            local ok, cached = pcall(readfile, path)
            if ok and valid(cached) then
                source = cached
            end
        end
    end
    assert(source, "library load failed: " .. path)
    local chunk = assert(loadstring(source, "=" .. path))
    return chunk()
end

local function valueOf(instance, name)
    if not instance then
        return nil
    end
    local child = instance:FindFirstChild(name)
    if child and child:IsA("ValueBase") then
        return child.Value
    end
    local ok, value = pcall(function()
        return instance:GetAttribute(name)
    end)
    if ok then
        return value
    end
    return nil
end

local function attributeOf(instance, name)
    if not instance then
        return nil
    end
    local ok, value = pcall(function()
        return instance:GetAttribute(name)
    end)
    return ok and value or nil
end

local function firstBasePart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Tool") then
        local handle = instance:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            return handle
        end
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
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end
    return nil
end

local function entityObject(instance)
    if not instance then
        return nil
    end
    if instance:IsA("Model") or instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Tool") then
        return firstBasePart(instance)
    end
    return firstBasePart(instance)
end

local function safeName(instance)
    local ok, name = pcall(function()
        return instance.Name
    end)
    return ok and tostring(name) or "Unknown"
end

local function safeValue(instance, name)
    local ok, value = pcall(valueOf, instance, name)
    return ok and value or nil
end

local function formatNumber(value)
    if type(value) == "number" then
        return tostring(math.floor(value + 0.5))
    end
    return tostring(value)
end

local function setLabelText(label, text)
    if type(label) == "table" and type(label.Set) == "function" then
        pcall(label.Set, label, text)
        return
    end
    pcall(function()
        label.Text = text
    end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Workspace = workspace

local ESP = loadLibrary("EasyESP.luau")
local UI = loadLibrary("EasyUi_style_2.luau")

local session = {
    unloaded = false,
    connections = {},
    promptCache = {},
    entityMeta = {},
    catalog = {},
    state = {
        players = true,
        bots = true,
        playerWeapon = true,
        playerAmmo = true,
        playerState = true,
        playerList = false,
        boxes = true,
        names = true,
        health = true,
        distance = true,
        skeleton = false,
        tracers = false,
        arrows = true,
        visibility = true,
        chams = false,
        drops = true,
        containers = true,
        extractions = true,
        extractHud = true,
        interactables = false,
        special = true,
        promptDisabled = false,
        detailText = true,
        range = 3500,
        performance = "balanced",
        colorMode = "team",
    },
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

local function buildCatalog()
    local storage = ReplicatedStorage:FindFirstChild("ToolsStorage")
    if not storage then
        return
    end
    for _, category in ipairs(storage:GetChildren()) do
        for _, item in ipairs(category:GetChildren()) do
            if item:IsA("Tool") then
                session.catalog[item.Name] = {
                    category = category.Name,
                    description = safeValue(item, "ItemDesc"),
                    ammoType = safeValue(item, "AmmoType"),
                    gearTier = safeValue(item, "GearTier"),
                    sellValue = safeValue(item, "SellValue"),
                    itemIcon = safeValue(item, "ItemIconID"),
                }
            end
        end
    end
end

local function itemName(instance)
    local direct = attributeOf(instance, "AttachmentMetadataItemName")
        or attributeOf(instance, "ItemName")
        or safeValue(instance, "ItemName")
        or safeValue(instance, "ShortenedName")
    if direct and tostring(direct) ~= "" then
        return tostring(direct)
    end
    return safeName(instance)
end

local function itemInfo(instance)
    instance = session.entityMeta[instance] or instance
    local name = itemName(instance)
    local entry = session.catalog[name] or {}
    local category = entry.category or attributeOf(instance, "Category") or "Item"
    local description = safeValue(instance, "ItemDesc") or entry.description
    local ammoType = safeValue(instance, "AmmoType") or entry.ammoType
    local tier = safeValue(instance, "GearTier") or entry.gearTier
    local sell = safeValue(instance, "SellValue") or entry.sellValue
    return {
        name = name,
        category = tostring(category),
        description = description and tostring(description) or nil,
        ammoType = ammoType and tostring(ammoType) or nil,
        tier = tier,
        sell = sell,
    }
end

local function heldWeapon(model)
    if not model then
        return nil
    end
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("Tool") or child:FindFirstChild("SPH_Weapon") then
            if child:IsA("Tool") or child:FindFirstChild("SPH_Weapon") then
                return child
            end
        end
    end
    return nil
end

local function weaponInfo(player, model)
    local tool = heldWeapon(model)
    if not tool then
        return nil
    end
    local info = itemInfo(tool)
    local ammoType = info.ammoType or safeValue(tool, "AmmoType")
    local mag = attributeOf(tool, "Magcapacity")
        or attributeOf(tool, "MagCapacity")
        or safeValue(tool, "Magcapacity")
        or safeValue(tool, "MagCapacity")
    local magSize = safeValue(tool, "Magsize") or safeValue(tool, "MagSize")
    local reloading = attributeOf(tool, "MagReloading")
    local reserve
    local ammoStorage = player and player:FindFirstChild("AmmoStorage")
    if ammoStorage and ammoType then
        reserve = safeValue(ammoStorage, tostring(ammoType))
    end
    return {
        name = safeName(tool),
        ammoType = ammoType and tostring(ammoType) or nil,
        mag = mag,
        magSize = magSize,
        reserve = reserve,
        reloading = reloading == true,
        fireMode = safeValue(tool, "FireMode"),
        damage = safeValue(tool, "AverageDamage"),
        penetration = safeValue(tool, "Penetration"),
        durability = safeValue(tool, "Durability"),
        attachments = attributeOf(tool, "AttachmentsJSON"),
    }
end

local function weaponText(player, model)
    local info = weaponInfo(player, model)
    if not info then
        return nil
    end
    local text = info.name
    if info.ammoType then
        text = text .. " " .. info.ammoType
    end
    return text
end

local function ammoText(player, model)
    local info = weaponInfo(player, model)
    if not info then
        return nil
    end
    local mag = info.mag ~= nil and formatNumber(info.mag) or "?"
    local magSize = info.magSize ~= nil and formatNumber(info.magSize) or "?"
    local reserve = info.reserve ~= nil and formatNumber(info.reserve) or "?"
    local text = mag .. "/" .. magSize .. " + " .. reserve
    if info.reloading then
        text = text .. " RELOAD"
    end
    return text
end

local function stateText(player, model)
    local info = weaponInfo(player, model)
    if not info then
        return nil
    end
    local parts = {}
    if info.fireMode ~= nil then
        table.insert(parts, "F" .. tostring(info.fireMode))
    end
    if info.damage ~= nil then
        table.insert(parts, "D" .. formatNumber(info.damage))
    end
    if info.penetration ~= nil then
        table.insert(parts, "P" .. formatNumber(info.penetration))
    end
    if info.durability ~= nil then
        table.insert(parts, "DUR" .. formatNumber(info.durability))
    end
    return #parts > 0 and table.concat(parts, " ") or nil
end

local function updatePrompt(instance)
    if instance:IsA("ProximityPrompt") then
        session.promptCache[instance] = true
    end
end

for _, instance in ipairs(Workspace:GetDescendants()) do
    updatePrompt(instance)
end
track(Workspace.DescendantAdded:Connect(updatePrompt))
track(Workspace.DescendantRemoving:Connect(function(instance)
    session.promptCache[instance] = nil
end))

buildCatalog()

local esp = ESP.new({
    on = true,
    maxRange = session.state.range,
    espRange = session.state.range,
    box = {
        on = true,
        kind = "corner",
        outline = true,
        fill = false,
        mode = "team",
        fade = true,
    },
    name = { on = true, user = false, size = 13 },
    dist = { on = true, size = 11, suf = "m" },
    hp = { on = true, side = "left", text = true, pct = false },
    flags = { on = true, side = "right", size = 10, gap = 1 },
    bones = { on = false },
    head = { on = true, size = 3 },
    gaze = { on = false },
    tracer = { on = false, from = "bottom" },
    arrow = { on = true, dist = true, fill = true },
    vis = { check = true, hide = false, tint = false, points = 3 },
    radar = { on = true, range = 600, names = false, max = 24 },
    list = { on = false, max = 12, hp = true, dist = true, vis = true },
    target = { on = false },
    threat = { on = false },
    chams = { on = false },
    perf = { mode = "auto", entityStep = 4, npcBoxStep = 4, toolStep = 8 },
    npc = {
        on = true,
        box = { on = true, kind = "corner", outline = true, mode = "static" },
        name = { on = true, size = 13 },
        dist = { on = true, size = 11, suf = "m" },
        hp = { on = true, side = "left", text = true },
        flags = { on = true, side = "right", size = 10, gap = 1 },
        bones = { on = false },
        head = { on = true, size = 3 },
        arrow = { on = true, dist = true },
        tracer = { on = false },
        vis = { check = true, hide = false, tint = false, points = 3 },
        chams = { on = false },
        perf = { mode = "auto", entityStep = 4, npcBoxStep = 4, toolStep = 8 },
    },
})
session.esp = esp
esp:theme("carbon")
esp:profile(session.state.performance)
esp.cfg.players.on = true
esp.cfg.npc.on = true

esp:setPlayerLabel(function(player)
    return player.DisplayName or player.Name
end)

esp:setNPCSource(function()
    local result = {}
    local bots = Workspace:FindFirstChild("IngameBots")
    if bots then
        for _, model in ipairs(bots:GetChildren()) do
            if model:IsA("Model") then
                table.insert(result, model)
            end
        end
    end
    local hq = Workspace:FindFirstChild("HQNpcs")
    if hq then
        for _, model in ipairs(hq:GetChildren()) do
            if model:IsA("Model") then
                table.insert(result, model)
            end
        end
    end
    return result
end)

esp:setNPCLabel(function(model)
    return attributeOf(model, "Archetype") or attributeOf(model, "Faction") or model.Name
end)

esp:flag("weapon", function(snapshot)
    local text = weaponText(snapshot.plr, snapshot.char)
    return text and ESP.Toolkit.flag(text, Color3.fromRGB(255, 220, 110)) or nil
end)

esp:flag("ammo", function(snapshot)
    local text = ammoText(snapshot.plr, snapshot.char)
    return text and ESP.Toolkit.flag(text, Color3.fromRGB(170, 220, 255)) or nil
end)

esp:flag("state", function(snapshot)
    local text = stateText(snapshot.plr, snapshot.char)
    return text and ESP.Toolkit.flag(text, Color3.fromRGB(210, 190, 255)) or nil
end)

local function extractionState(instance)
    local requirement = safeValue(instance, "Requirement") == true
    local available = safeValue(instance, "Available") == true
    local ui = instance:FindFirstChild("ExtractUI")
    local visible = ui and ui:IsA("BillboardGui") and ui.Enabled == true
    local status
    local color
    if requirement then
        status = "ITEM REQUIRED"
        color = Color3.fromRGB(255, 170, 70)
    elseif available or visible then
        status = "OPEN"
        color = Color3.fromRGB(90, 255, 130)
    else
        status = "CLOSED"
        color = Color3.fromRGB(150, 170, 190)
    end
    return status, color, safeValue(instance, "ExtractTime")
end

local function extractionLabel(instance)
    local status, _, duration = extractionState(instance)
    local text = safeName(instance) .. " | " .. status
    if duration ~= nil then
        text = text .. " | " .. formatNumber(duration) .. "s"
    end
    return text
end

local function extractionObjects()
    if not session.state.extractions then
        return {}
    end
    local root = Workspace:FindFirstChild("Extractions")
    local result = {}
    for _, instance in ipairs(root and root:GetChildren() or {}) do
        if instance:IsA("BasePart") or instance:IsA("Model") then
            table.insert(result, instance)
        end
    end
    return result
end

local function specialObjects()
    if not session.state.special then
        return {}
    end
    local result = {}
    for _, rootName in ipairs({ "RadiationZones", "AirdropPositions", "LockedRooms" }) do
        local root = Workspace:FindFirstChild(rootName)
        for _, instance in ipairs(root and root:GetChildren() or {}) do
            local object = entityObject(instance)
            if object then
                session.entityMeta[object] = instance
                table.insert(result, object)
            end
        end
    end
    return result
end

local function specialLabel(instance)
    local source = session.entityMeta[instance] or instance
    local parent = source.Parent
    local category = parent and parent.Name or "World"
    return category .. " | " .. safeName(source)
end

local function containerState(instance)
    local configs = instance:FindFirstChild("Configs")
    local looted = configs and safeValue(configs, "Looted") == true
    local cooldown = configs and safeValue(configs, "LootCooldown")
    local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
    local enabled = prompt and prompt.Enabled
    local status = looted and "LOOTED" or "READY"
    if enabled == false then
        status = status .. " LOCKED"
    end
    return status, looted and Color3.fromRGB(150, 160, 170) or Color3.fromRGB(255, 210, 95), cooldown
end

local function containerLabel(instance)
    local owner = safeValue(instance, "CorpseOwner")
    local status, _, cooldown = containerState(instance)
    local prefix
    if attributeOf(instance, "IsNPCCorpse") == true or attributeOf(instance, "CorpseCreated") == true or owner then
        prefix = "CORPSE " .. (owner and tostring(owner) or safeName(instance))
    else
        prefix = safeName(instance)
    end
    local text = prefix .. " | " .. status
    if cooldown ~= nil and tonumber(cooldown) and tonumber(cooldown) > 0 then
        text = text .. " | " .. formatNumber(cooldown) .. "s"
    end
    return text
end

local function containerObjects()
    if not session.state.containers then
        return {}
    end
    local root = Workspace:FindFirstChild("Containers")
    local result = {}
    for _, instance in ipairs(root and root:GetChildren() or {}) do
        if instance:IsA("Model") or instance:IsA("BasePart") then
            table.insert(result, instance)
        end
    end
    return result
end

local function dropLabel(instance)
    local info = itemInfo(instance)
    local text = info.category .. " | " .. info.name
    if info.ammoType then
        text = text .. " | " .. info.ammoType
    end
    if info.tier ~= nil then
        text = text .. " | T" .. formatNumber(info.tier)
    end
    if info.sell ~= nil then
        text = text .. " | $" .. formatNumber(info.sell)
    end
    return text
end

local function dropObjects()
    if not session.state.drops then
        return {}
    end
    local root = Workspace:FindFirstChild("SPH_Workspace")
    local drops = root and root:FindFirstChild("Drops")
    local result = {}
    for _, instance in ipairs(drops and drops:GetChildren() or {}) do
        local object = entityObject(instance)
        if object then
            session.entityMeta[object] = instance
            table.insert(result, object)
        end
    end
    return result
end

local function promptLabel(prompt)
    local object = prompt.Parent
    local title = prompt.ObjectText
    if not title or title == "" then
        title = object and safeName(object) or prompt.Name
    end
    local action = prompt.ActionText
    if action and action ~= "" then
        return tostring(title) .. " | " .. tostring(action)
    end
    return tostring(title)
end

local function promptObjects()
    if not session.state.interactables then
        return {}
    end
    local result = {}
    local seen = {}
    for prompt in pairs(session.promptCache) do
        if prompt and prompt.Parent and (session.state.promptDisabled or prompt.Enabled) then
            local object = entityObject(prompt.Parent)
            if object and not seen[object] then
                seen[object] = true
                table.insert(result, object)
            end
        end
    end
    return result
end

local function objectForPrompt(instance)
    for prompt in pairs(session.promptCache) do
        if prompt and prompt.Parent and entityObject(prompt.Parent) == instance then
            return prompt
        end
    end
    return nil
end

esp:addEnt("pz_drops", {
    get = dropObjects,
    label = dropLabel,
    col = Color3.fromRGB(120, 255, 190),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = 3500,
    priority = 3,
    draw = function(e, id, object, _, x, y, w, h)
        if session.state.detailText then
            local info = itemInfo(object)
            local text = info.description and string.sub(info.description, 1, 28) or nil
            if text then
                e.pool:txt("ent_drop_desc_" .. id, text, x + w * 0.5, y + h + 13, 9, Color3.fromRGB(190, 220, 205), true)
            end
        end
    end,
})

esp:addEnt("pz_containers", {
    get = containerObjects,
    label = containerLabel,
    col = Color3.fromRGB(255, 210, 95),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = 3500,
    priority = 2,
    draw = function(e, id, object, _, x, y, w, h)
        local status, color = containerState(object)
        e.pool:txt("ent_container_status_" .. id, status, x + w * 0.5, y + h + 13, 9, color, true)
    end,
})

esp:addEnt("pz_extractions", {
    get = extractionObjects,
    label = extractionLabel,
    col = Color3.fromRGB(100, 220, 255),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = 0,
    priority = 4,
    draw = function(e, id, object, _, x, y, w, h)
        local status, color, duration = extractionState(object)
        local text = status
        if duration ~= nil then
            text = text .. " | " .. formatNumber(duration) .. "s"
        end
        e.pool:txt("ent_extract_status_" .. id, text, x + w * 0.5, y + h + 13, 9, color, true)
    end,
})

esp:addEnt("pz_interactables", {
    get = promptObjects,
    label = function(object)
        local prompt = objectForPrompt(object)
        return prompt and promptLabel(prompt) or safeName(object)
    end,
    col = Color3.fromRGB(235, 150, 255),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = 2500,
    priority = 2,
})

esp:addEnt("pz_special", {
    get = specialObjects,
    label = specialLabel,
    col = Color3.fromRGB(255, 120, 120),
    box = true,
    name = true,
    dist = true,
    dot = true,
    max = 3500,
    priority = 3,
})

local function nearestExtraction()
    if not session.state.extractions then
        return nil
    end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local extractions = Workspace:FindFirstChild("Extractions")
    if not root or not extractions then
        return nil
    end
    local nearest
    local nearestDistance
    for _, instance in ipairs(extractions:GetChildren()) do
        if instance:IsA("BasePart") or instance:IsA("Model") then
            local part = firstBasePart(instance)
            if part then
                local distance = (root.Position - part.Position).Magnitude
                if not nearestDistance or distance < nearestDistance then
                    nearest = instance
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest, nearestDistance
end

esp:mod({
    name = "pz_extraction_hud",
    on = true,
    screen = function(_, e)
        if not session.state.extractHud then
            return
        end
        local instance, distance = nearestExtraction()
        if not instance or not distance then
            return
        end
        local status, color, duration = extractionState(instance)
        local text = "EXTRACT " .. safeName(instance) .. " | " .. status .. " | " .. formatNumber(distance / 2.8) .. "m"
        if duration ~= nil then
            text = text .. " | " .. formatNumber(duration) .. "s"
        end
        e.pool:txt("ent_pz_extract_hud", text, 18, 18, 13, color, false)
    end,
})

local UIInstance = UI.new({
    title = "Perimeter Zero ESP",
    accent = Color3.fromRGB(100, 220, 255),
    toggleKey = Enum.KeyCode.RightShift,
    watermark = false,
    cursor = false,
    resizable = true,
})
session.ui = UIInstance

local function bindToggle(section, text, flag, default, callback)
    return section:Toggle({
        text = text,
        flag = "pz." .. flag,
        default = default,
        callback = callback,
    })
end

local playersWindow = UIInstance:Window("Players", { x = 30, y = 70, width = 300, height = 410 })
local playerSection = playersWindow:Tab("ESP"):Section("Live targets")
bindToggle(playerSection, "Players", "players", session.state.players, function(value)
    session.state.players = value
    esp.cfg.players.on = value
end)
bindToggle(playerSection, "Bots / NPCs", "bots", session.state.bots, function(value)
    session.state.bots = value
    esp.cfg.npc.on = value
end)
bindToggle(playerSection, "Boxes", "boxes", session.state.boxes, function(value)
    session.state.boxes = value
    esp.cfg.box.on = value
    esp.cfg.npc.box.on = value
end)
bindToggle(playerSection, "Names", "names", session.state.names, function(value)
    session.state.names = value
    esp.cfg.name.on = value
    esp.cfg.npc.name.on = value
end)
bindToggle(playerSection, "Health", "health", session.state.health, function(value)
    session.state.health = value
    esp.cfg.hp.on = value
    esp.cfg.npc.hp.on = value
end)
bindToggle(playerSection, "Distance", "distance", session.state.distance, function(value)
    session.state.distance = value
    esp.cfg.dist.on = value
    esp.cfg.npc.dist.on = value
end)
bindToggle(playerSection, "Player list", "playerList", session.state.playerList, function(value)
    session.state.playerList = value
    esp.cfg.list.on = value
end)
bindToggle(playerSection, "Weapon flag", "playerWeapon", session.state.playerWeapon, function(value)
    session.state.playerWeapon = value
    esp:setFlagEnabled("weapon", value)
end)
bindToggle(playerSection, "Ammo flag", "playerAmmo", session.state.playerAmmo, function(value)
    session.state.playerAmmo = value
    esp:setFlagEnabled("ammo", value)
end)
bindToggle(playerSection, "Weapon detail", "playerState", session.state.playerState, function(value)
    session.state.playerState = value
    esp:setFlagEnabled("state", value)
end)
bindToggle(playerSection, "Skeleton", "skeleton", session.state.skeleton, function(value)
    session.state.skeleton = value
    esp.cfg.bones.on = value
    esp.cfg.npc.bones.on = value
end)
bindToggle(playerSection, "Tracers", "tracers", session.state.tracers, function(value)
    session.state.tracers = value
    esp.cfg.tracer.on = value
    esp.cfg.npc.tracer.on = value
end)
bindToggle(playerSection, "Off-screen arrows", "arrows", session.state.arrows, function(value)
    session.state.arrows = value
    esp.cfg.arrow.on = value
    esp.cfg.npc.arrow.on = value
end)
bindToggle(playerSection, "Visibility checks", "visibility", session.state.visibility, function(value)
    session.state.visibility = value
    esp.cfg.vis.check = value
    esp.cfg.npc.vis.check = value
end)
bindToggle(playerSection, "Highlight chams", "chams", session.state.chams, function(value)
    session.state.chams = value
    esp.cfg.chams.on = value
    esp.cfg.npc.chams.on = value
end)
playerSection:Dropdown({
    text = "Box style",
    flag = "pz.boxKind",
    options = { "corner", "full", "3d", "3dcorner" },
    default = "corner",
    callback = function(value)
        esp.cfg.box.kind = value
        esp.cfg.npc.box.kind = value
    end,
})
playerSection:Dropdown({
    text = "Player colors",
    flag = "pz.colorMode",
    options = { "team", "hp", "dist", "static" },
    default = session.state.colorMode,
    callback = function(value)
        session.state.colorMode = value
        esp.cfg.box.mode = value
    end,
})
playerSection:Dropdown({
    text = "Performance",
    flag = "pz.performance",
    options = { "low", "balanced", "high" },
    default = session.state.performance,
    callback = function(value)
        session.state.performance = value
        esp:profile(value)
    end,
})
playerSection:Slider({
    text = "ESP range",
    flag = "pz.range",
    min = 500,
    max = 6000,
    step = 100,
    decimals = 0,
    default = session.state.range,
    suffix = "m",
    callback = function(value)
        session.state.range = value
        esp.cfg.maxRange = value
        esp.cfg.espRange = value
    end,
})

local worldWindow = UIInstance:Window("World", { x = 350, y = 70, width = 330, height = 350 })
local worldSection = worldWindow:Tab("World ESP"):Section("Raid objects")
bindToggle(worldSection, "Dropped items", "drops", session.state.drops, function(value)
    session.state.drops = value
end)
bindToggle(worldSection, "Containers / corpses", "containers", session.state.containers, function(value)
    session.state.containers = value
end)
bindToggle(worldSection, "Extraction points", "extractions", session.state.extractions, function(value)
    session.state.extractions = value
end)
bindToggle(worldSection, "Nearest extraction HUD", "extractHud", session.state.extractHud, function(value)
    session.state.extractHud = value
end)
bindToggle(worldSection, "Interactables", "interactables", session.state.interactables, function(value)
    session.state.interactables = value
end)
bindToggle(worldSection, "Radiation / airdrop / locked rooms", "special", session.state.special, function(value)
    session.state.special = value
end)
bindToggle(worldSection, "Show disabled prompts", "promptDisabled", session.state.promptDisabled, function(value)
    session.state.promptDisabled = value
end)
bindToggle(worldSection, "Detail text", "detailText", session.state.detailText, function(value)
    session.state.detailText = value
end)
worldSection:Label("Extractions show state, requirement, distance, and time.")
worldSection:Label("Loot labels use the game's ToolsStorage catalog.")

local statusWindow = UIInstance:Window("Status", { x = 710, y = 70, width = 300, height = 230 })
local statusSection = statusWindow:Tab("Observer"):Section("Read-only telemetry")
local statusLabel = statusSection:Label("Loading")
local countLabel = statusSection:Label("Counts")
local extractionLabelState = statusSection:Label("Extractions")
statusSection:Button({
    text = "Refresh prompt cache",
    callback = function()
        session.promptCache = {}
        for _, instance in ipairs(Workspace:GetDescendants()) do
            updatePrompt(instance)
        end
    end,
})
statusSection:Button({
    text = "Unload",
    callback = function()
        if type(session.unload) == "function" then
            session.unload()
        end
    end,
})

local function countChildren(root)
    return root and #root:GetChildren() or 0
end

local function statusUpdate()
    if session.unloaded then
        return
    end
    local inRaid = LocalPlayer:FindFirstChild("InRaid")
    local raidText = inRaid and (inRaid.Value and "IN RAID" or "HQ / NOT IN RAID") or "UNKNOWN RAID STATE"
    local stats = esp:getStats()
    setLabelText(statusLabel, raidText .. " | FPS " .. formatNumber(stats.fpsAvg or stats.fps or 0))
    local bots = Workspace:FindFirstChild("IngameBots")
    local dropsRoot = Workspace:FindFirstChild("SPH_Workspace")
    local drops = dropsRoot and dropsRoot:FindFirstChild("Drops")
    local extractions = Workspace:FindFirstChild("Extractions")
    local containers = Workspace:FindFirstChild("Containers")
    setLabelText(countLabel, "Players " .. tostring(#Players:GetPlayers()) .. " | Bots " .. tostring(countChildren(bots)) .. " | Drops " .. tostring(countChildren(drops)) .. " | Containers " .. tostring(countChildren(containers)) .. " | Drawn " .. tostring(stats.drawn or 0))
    local extractionCount = countChildren(extractions)
    local openCount = 0
    if extractions then
        for _, instance in ipairs(extractions:GetChildren()) do
            local status = extractionState(instance)
            if status == "OPEN" then
                openCount += 1
            end
        end
    end
    local promptCount = 0
    for _ in pairs(session.promptCache) do
        promptCount += 1
    end
    setLabelText(extractionLabelState, "Extractions " .. tostring(extractionCount) .. " | Open " .. tostring(openCount) .. " | Prompts " .. tostring(promptCount))
end

local statusAccumulator = 0
track(RunService.Heartbeat:Connect(function(dt)
    statusAccumulator += dt
    if statusAccumulator >= 0.5 then
        statusAccumulator = 0
        statusUpdate()
    end
end))

function session.snapshot()
    local lines = {}
    local inRaid = LocalPlayer:FindFirstChild("InRaid")
    local stats = esp:getStats()
    table.insert(lines, "place=Perimeter Zero raid=" .. tostring(inRaid and inRaid.Value or false) .. " fps=" .. formatNumber(stats.fpsAvg or stats.fps or 0) .. " roster=" .. tostring(stats.roster or 0) .. " entities=" .. tostring(stats.ents or 0) .. " drawn=" .. tostring(stats.drawn or 0) .. " pool=" .. tostring(stats.pool or 0))
    local extractions = Workspace:FindFirstChild("Extractions")
    for _, instance in ipairs(extractions and extractions:GetChildren() or {}) do
        local status, _, duration = extractionState(instance)
        table.insert(lines, "extract=" .. safeName(instance) .. " status=" .. status .. " time=" .. tostring(duration or "?") .. " requirement=" .. tostring(safeValue(instance, "Requirement")))
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local model = Workspace:FindFirstChild(player.Name)
            local weapon = weaponInfo(player, model)
            if weapon then
                table.insert(lines, "player=" .. player.Name .. " weapon=" .. weapon.name .. " ammoType=" .. tostring(weapon.ammoType or "?") .. " mag=" .. tostring(weapon.mag or "?") .. "/" .. tostring(weapon.magSize or "?") .. " reserve=" .. tostring(weapon.reserve or "unknown"))
            end
        end
    end
    return table.concat(lines, "\n")
end

function session.rescan()
    buildCatalog()
    session.promptCache = {}
    for _, instance in ipairs(Workspace:GetDescendants()) do
        updatePrompt(instance)
    end
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
statusUpdate()
UIInstance:SetVisible(false)
UIInstance:Notify({ title = "Perimeter Zero ESP", text = "Read-only ESP loaded. RightShift opens controls.", kind = "ok", duration = 4 })
esp:start()
print("[PZ_ESP_OK] Perimeter Zero read-only ESP loaded")
print(session.snapshot())