-- Target bridge (client): ox_target / qb-target with one option format.
--   option = { name, label, icon, distance = 2.0, canInteract = fn(entity) -> bool, onSelect = fn(entity) }
--   ObsiLib.target.addSphere(name, coords, radius, options)
--   ObsiLib.target.addBox(name, coords, size, heading, options)
--   ObsiLib.target.addEntity(entity, options)   ObsiLib.target.removeEntity(entity, optionNames?)
--   ObsiLib.target.remove(name)   ObsiLib.target.provider()   ObsiLib.target.icon(name)
-- `icon` accepts a FontAwesome class ('fas fa-box') or a short name ('box', 'car', 'key' ...).

local zones = {}    -- [name] = { provider, handle, owner }
local entities = {} -- [entity] = { [optionName] = label }

-- Short icon names -> FontAwesome classes. Extend with ObsiConfig.TargetIcons.
local ICONS = {
    box = 'fa-box', ['box-open'] = 'fa-box-open', package = 'fa-box', archive = 'fa-box-archive', bag = 'fa-bag-shopping',
    cart = 'fa-cart-shopping', store = 'fa-store', wallet = 'fa-wallet', money = 'fa-money-bill', card = 'fa-credit-card',
    coins = 'fa-coins', receipt = 'fa-receipt', tag = 'fa-tag', gem = 'fa-gem',
    car = 'fa-car', truck = 'fa-truck', key = 'fa-key', lock = 'fa-lock', unlock = 'fa-lock-open', parking = 'fa-square-parking',
    gas = 'fa-gas-pump', wrench = 'fa-wrench', hammer = 'fa-hammer', tools = 'fa-screwdriver-wrench',
    door = 'fa-door-open', ['door-closed'] = 'fa-door-closed', house = 'fa-house', building = 'fa-building',
    user = 'fa-user', users = 'fa-users', id = 'fa-id-card', badge = 'fa-id-badge', shield = 'fa-shield-halved',
    hand = 'fa-hand', handshake = 'fa-handshake', eye = 'fa-eye', search = 'fa-magnifying-glass', info = 'fa-circle-info',
    shirt = 'fa-shirt', chair = 'fa-chair', couch = 'fa-couch', bed = 'fa-bed', tv = 'fa-tv', laptop = 'fa-laptop',
    phone = 'fa-phone', tablet = 'fa-tablet-screen-button', clipboard = 'fa-clipboard-list', file = 'fa-file-lines',
    food = 'fa-utensils', burger = 'fa-burger', pizza = 'fa-pizza-slice', coffee = 'fa-mug-hot', beer = 'fa-beer-mug-empty',
    wine = 'fa-wine-glass', snow = 'fa-snowflake', fire = 'fa-fire', water = 'fa-droplet', leaf = 'fa-leaf',
    medkit = 'fa-kit-medical', pills = 'fa-pills', heart = 'fa-heart', music = 'fa-music', camera = 'fa-camera',
    gear = 'fa-gear', settings = 'fa-gear', chart = 'fa-chart-line', clock = 'fa-clock', bell = 'fa-bell',
    star = 'fa-star', check = 'fa-check', x = 'fa-xmark', plus = 'fa-plus', minus = 'fa-minus', trash = 'fa-trash',
    save = 'fa-floppy-disk', pin = 'fa-location-dot', map = 'fa-map', gun = 'fa-gun', box_weapon = 'fa-person-rifle',
}

local PROVIDERS = { 'ox_target', 'qb-target' }
local ALIASES = { ox = 'ox_target', ox_target = 'ox_target', qb = 'qb-target', ['qb-target'] = 'qb-target' }

local target = {}

---'ox_target' | 'qb-target' | 'none' (resolved live)
function target.provider()
    return Core.integration(ObsiConfig.Integrations.Target, PROVIDERS, ALIASES)
end

---@return string FontAwesome class
function target.icon(name)
    if type(name) ~= 'string' or name == '' then return 'fas fa-circle' end
    if name:find('^fa') then return name end
    local custom = ObsiConfig.TargetIcons and ObsiConfig.TargetIcons[name]
    if custom then return custom end
    return 'fas ' .. (ICONS[name] or 'fa-circle')
end

local function entityOrNil(entity)
    if not entity or entity == 0 then return nil end
    return entity
end

local function guard(fn, entity)
    if not fn then return nil end
    return function(data)
        local ent = type(data) == 'table' and data.entity or data
        return Core.safe(fn, entityOrNil(ent))
    end
end

local function oxOptions(options)
    local list = {}
    for index, option in ipairs(options or {}) do
        local canInteract = option.canInteract
        list[index] = {
            name = option.name or ('obsi_%d'):format(index),
            label = option.label,
            icon = target.icon(option.icon),
            distance = tonumber(option.distance) or 2.0,
            canInteract = canInteract and function(entity) return Core.safe(canInteract, entityOrNil(entity)) == true end or nil,
            onSelect = guard(option.onSelect),
        }
    end
    return list
end

local function qbOptions(options)
    local list, distance = {}, 0.0
    for index, option in ipairs(options or {}) do
        local canInteract = option.canInteract
        distance = math.max(distance, tonumber(option.distance) or 2.0)
        list[index] = {
            num = index,
            label = option.label,
            icon = target.icon(option.icon),
            canInteract = canInteract and function(entity) return Core.safe(canInteract, entityOrNil(entity)) == true end or nil,
            action = guard(option.onSelect),
        }
    end
    return { options = list, distance = distance > 0 and distance or 2.0 }
end

local function track(name, provider, handle)
    zones[name] = { provider = provider, handle = handle }
    local owner = Core.caller()
    Core.own(owner, function() target.remove(name) end)
end

---@return any zone handle or nil
function target.addSphere(name, coords, radius, options)
    local provider = target.provider()
    coords = Core.vec3(coords)
    if provider == 'none' or not Core.text(name) or not coords then return nil end
    target.remove(name)
    radius = tonumber(radius) or 1.5

    if provider == 'ox_target' then
        local handle = Core.safe(function()
            return exports.ox_target:addSphereZone({ name = name, coords = coords, radius = radius, debug = ObsiConfig.Debug, options = oxOptions(options) })
        end)
        if handle then track(name, provider, handle) end
        return handle
    end

    local ok = Core.safe(function()
        exports['qb-target']:AddCircleZone(name, coords, radius, { name = name, debugPoly = ObsiConfig.Debug, useZ = true }, qbOptions(options))
        return true
    end)
    if ok then track(name, provider, name) end
    return ok and name or nil
end

---@param size number|vector3|table
---@return any zone handle or nil
function target.addBox(name, coords, size, heading, options)
    local provider = target.provider()
    coords = Core.vec3(coords)
    if provider == 'none' or not Core.text(name) or not coords then return nil end
    target.remove(name)

    local box = type(size) == 'number' and vector3(size, size, size) or Core.vec3(size) or vector3(1.0, 1.0, 1.0)
    heading = tonumber(heading) or 0.0

    if provider == 'ox_target' then
        local handle = Core.safe(function()
            return exports.ox_target:addBoxZone({ name = name, coords = coords, size = box, rotation = heading, debug = ObsiConfig.Debug, options = oxOptions(options) })
        end)
        if handle then track(name, provider, handle) end
        return handle
    end

    local ok = Core.safe(function()
        exports['qb-target']:AddBoxZone(name, coords, box.x, box.y, {
            name = name, heading = heading, debugPoly = ObsiConfig.Debug, minZ = coords.z - box.z / 2, maxZ = coords.z + box.z / 2,
        }, qbOptions(options))
        return true
    end)
    if ok then track(name, provider, name) end
    return ok and name or nil
end

function target.remove(name)
    local zone = name and zones[name]
    if not zone then return end
    zones[name] = nil
    if zone.provider == 'ox_target' then
        Core.safe(function() exports.ox_target:removeZone(zone.handle) end)
    else
        Core.safe(function() exports['qb-target']:RemoveZone(zone.handle) end)
    end
end

---@return boolean
function target.addEntity(entity, options)
    local provider = target.provider()
    if provider == 'none' or not entity or entity == 0 then return false end

    local known = entities[entity] or {}
    for _, option in ipairs(options or {}) do
        if option.name then known[option.name] = option.label end
    end
    entities[entity] = known

    local owner = Core.caller()
    Core.own(owner, function() target.removeEntity(entity) end)

    if provider == 'ox_target' then
        return Core.safe(function() exports.ox_target:addLocalEntity(entity, oxOptions(options)) return true end) == true
    end
    return Core.safe(function() exports['qb-target']:AddTargetEntity(entity, qbOptions(options)) return true end) == true
end

---@param names? string|string[] option names; nil removes every option added through obsi-lib
function target.removeEntity(entity, names)
    local provider = target.provider()
    if provider == 'none' or not entity then return end
    local known = entities[entity] or {}
    local list = names and (type(names) == 'table' and names or { names }) or nil

    if provider == 'ox_target' then
        local all = {}
        if not list then for optionName in pairs(known) do all[#all + 1] = optionName end end
        Core.safe(function() exports.ox_target:removeLocalEntity(entity, list or (#all > 0 and all or nil)) end)
    else
        local labels = {}
        if list then
            for _, optionName in ipairs(list) do labels[#labels + 1] = known[optionName] or optionName end
        else
            for _, label in pairs(known) do labels[#labels + 1] = label end
        end
        Core.safe(function() exports['qb-target']:RemoveTargetEntity(entity, #labels > 0 and labels or nil) end)
    end

    if list then
        for _, optionName in ipairs(list) do known[optionName] = nil end
        if not next(known) then entities[entity] = nil end
    else
        entities[entity] = nil
    end
end

ObsiLib.target = target

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Core.resource then return end
    for name in pairs(zones) do target.remove(name) end
    for entity in pairs(entities) do target.removeEntity(entity) end
end)
