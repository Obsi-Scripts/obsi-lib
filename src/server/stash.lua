-- Stashes (server).
--   ox_inventory      native stashes
--   qb-inventory v2   live inventories, backed by the `inventories` table
--   qb legacy forks   `stashitems` table, opened through the inventory's own UI
--   custom            optional hooks from editable/server/inventory.lua
--   anything else     resource KVP with a small native menu (src/client/stash.lua)

local items = ObsiLib.items
local registry = {}   -- [id] = { label, slots, weight, groups, clientOpen, coords, radius }
local sessions = {}   -- [src] = { id, expires, lastMove } for the KVP menu
local locks = {}

local function settings()
    return ObsiConfig.Stash or {}
end

local function kind()
    local _, inventoryKind = Core.inv()
    return inventoryKind
end

local function customHook(name)
    if kind() ~= 'custom' then return nil end
    local fn = ObsiEditable and ObsiEditable.inventory and ObsiEditable.inventory[name]
    return type(fn) == 'function' and fn or nil
end

---Serialises async writes to one stash so two players can not race on the same rows.
local function locked(id, fn, ...)
    local waited = 0
    while locks[id] do
        Wait(0)
        waited = waited + 1
        if waited > 500 then
            Core.warn('stash "%s" stayed locked, skipping write', id)
            return false
        end
    end
    locks[id] = true
    local packed = table.pack(pcall(fn, ...))
    locks[id] = nil
    if not packed[1] then
        Core.warn('stash "%s" write failed: %s', id, tostring(packed[2]))
        return false
    end
    return table.unpack(packed, 2, packed.n)
end

---------------------------------------------------------------------------------------------------
-- Database store (qb-inventory)
---------------------------------------------------------------------------------------------------

local Database = {}

function Database.table()
    local tables = settings().Tables or {}
    return tables[kind()] or tables['qb-legacy']
end

function Database.load(id)
    local def = Database.table()
    local query = ('SELECT `%s` AS items FROM `%s` WHERE `%s` = ? LIMIT 1'):format(def.column, def.table, def.identifier)
    local rows = Core.safe(MySQL.query.await, query, { id })
    local decoded = rows and rows[1] and rows[1].items and json.decode(rows[1].items) or {}
    local list = {}
    for _, entry in pairs(type(decoded) == 'table' and decoded or {}) do
        if type(entry) == 'table' and entry.name then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b) return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0) end)
    return list
end

function Database.save(id, list)
    local def = Database.table()
    local query = ('INSERT INTO `%s` (`%s`, `%s`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `%s` = VALUES(`%s`)')
        :format(def.table, def.identifier, def.column, def.column, def.column)
    return Core.safe(MySQL.query.await, query, { id, json.encode(list) }) ~= nil
end

function Database.add(id, name, count, metadata)
    return locked(id, function()
        local stash = registry[id]
        local list = Database.load(id)
        local shared = (Core.fw.items() or {})[name] or {}
        local hasMeta = type(metadata) == 'table' and next(metadata) ~= nil

        if not shared.unique and not hasMeta then
            for _, entry in ipairs(list) do
                if entry.name == name and not (type(entry.info) == 'table' and next(entry.info)) then
                    entry.amount = (tonumber(entry.amount) or 0) + count
                    return Database.save(id, list)
                end
            end
        end

        local taken = {}
        for _, entry in ipairs(list) do taken[tonumber(entry.slot) or 0] = true end
        local free
        for slot = 1, stash.slots do
            if not taken[slot] then
                free = slot
                break
            end
        end
        if not free then return false end

        list[#list + 1] = {
            name = name, amount = count, info = metadata or {}, slot = free,
            label = shared.label or name, description = shared.description or '', weight = shared.weight or 0,
            type = shared.type or 'item', unique = shared.unique or false, useable = shared.useable or false,
            image = shared.image or (name .. '.png'), shouldClose = shared.shouldClose or false, combinable = shared.combinable,
        }
        return Database.save(id, list)
    end)
end

function Database.remove(id, name, count)
    return locked(id, function()
        local list = Database.load(id)
        local total = 0
        for _, entry in ipairs(list) do
            if entry.name == name then total = total + (tonumber(entry.amount) or 0) end
        end
        if total < count then return false end

        local left, kept = count, {}
        for _, entry in ipairs(list) do
            local amount = tonumber(entry.amount) or 0
            if entry.name == name and left > 0 then
                local take = math.min(left, amount)
                amount, left = amount - take, left - take
                entry.amount = amount
            end
            if amount > 0 then kept[#kept + 1] = entry end
        end
        return Database.save(id, kept)
    end)
end

---------------------------------------------------------------------------------------------------
-- KVP store (no stash capable inventory)
---------------------------------------------------------------------------------------------------

local Kvp = { cache = {} }

function Kvp.key(id)
    return (settings().KvpPrefix or 'obsi_stash_') .. id
end

function Kvp.load(id)
    if Kvp.cache[id] then return Kvp.cache[id] end
    local raw = GetResourceKvpString(Kvp.key(id))
    local decoded = raw and json.decode(raw)
    local list = type(decoded) == 'table' and decoded or {}
    Kvp.cache[id] = list
    return list
end

function Kvp.save(id, list)
    Kvp.cache[id] = list
    SetResourceKvp(Kvp.key(id), json.encode(list))
    return true
end

-- KVP operations never yield, so each one runs atomically.
function Kvp.add(id, name, count, metadata)
    local stash = registry[id]
    local list = Kvp.load(id)
    local hasMeta = type(metadata) == 'table' and next(metadata) ~= nil

    if not hasMeta then
        for _, entry in ipairs(list) do
            if entry.name == name and not (type(entry.metadata) == 'table' and next(entry.metadata)) then
                entry.count = (tonumber(entry.count) or 0) + count
                return Kvp.save(id, list)
            end
        end
    end

    if #list >= stash.slots then return false end
    list[#list + 1] = { name = name, count = count, metadata = metadata or {} }
    return Kvp.save(id, list)
end

function Kvp.remove(id, name, count)
    local list = Kvp.load(id)
    local total = 0
    for _, entry in ipairs(list) do
        if entry.name == name then total = total + (tonumber(entry.count) or 0) end
    end
    if total < count then return false end

    local left, kept = count, {}
    for _, entry in ipairs(list) do
        local amount = tonumber(entry.count) or 0
        if entry.name == name and left > 0 then
            local take = math.min(left, amount)
            amount, left = amount - take, left - take
            entry.count = amount
        end
        if amount > 0 then kept[#kept + 1] = entry end
    end
    return Kvp.save(id, kept)
end

---------------------------------------------------------------------------------------------------
-- qb-inventory v2 live inventory
---------------------------------------------------------------------------------------------------

local function qbLive(id)
    if Core.safe(function() return exports['qb-inventory']:GetInventory(id) end) then return true end
    local def = registry[id]
    local slots = {}
    for _, entry in ipairs(Database.load(id)) do slots[tonumber(entry.slot) or (#slots + 1)] = entry end
    return Core.safe(function()
        exports['qb-inventory']:CreateInventory(id, { label = def.label, maxweight = def.weight, slots = def.slots })
        exports['qb-inventory']:SetInventory(id, slots)
        return true
    end) == true
end

---------------------------------------------------------------------------------------------------
-- ObsiLib.stash
---------------------------------------------------------------------------------------------------

local stash = {}

---Registers (or updates) a stash.
---@param id string
---@param opts? { label?: string, slots?: number, weight?: number, groups?: table, clientOpen?: boolean, coords?: vector3, radius?: number }
---  clientOpen lets clients open it with ObsiLib.stash.open(id) on the client; coords + radius add a distance check.
---@return boolean
function stash.register(id, opts)
    if id == nil then return false end
    id = tostring(id)
    opts = type(opts) == 'table' and opts or {}

    registry[id] = {
        label = opts.label or id,
        slots = math.floor(tonumber(opts.slots) or settings().DefaultSlots or 50),
        weight = math.floor(tonumber(opts.weight) or settings().DefaultWeight or 100000),
        groups = opts.groups,
        clientOpen = opts.clientOpen == true,
        coords = opts.coords and Core.vec3(opts.coords) or nil,
        radius = tonumber(opts.radius) or 3.0,
    }
    local def = registry[id]

    if kind() == 'ox' then
        return Core.safe(function()
            exports.ox_inventory:RegisterStash(id, def.label, def.slots, def.weight, false, def.groups, def.coords)
            return true
        end) == true
    end

    local hook = customHook('registerStash')
    if hook then return Core.safe(hook, id, def) ~= false end
    return true
end

local function ensure(id, overrides)
    id = tostring(id)
    local def = registry[id]
    if not def then
        stash.register(id, overrides)
        return registry[id]
    end
    if type(overrides) == 'table' then
        local changed = (overrides.label and overrides.label ~= def.label)
            or (overrides.slots and tonumber(overrides.slots) ~= def.slots)
            or (overrides.weight and tonumber(overrides.weight) ~= def.weight)
        if changed then
            stash.register(id, {
                label = overrides.label or def.label, slots = overrides.slots or def.slots, weight = overrides.weight or def.weight,
                groups = def.groups, clientOpen = def.clientOpen, coords = def.coords, radius = def.radius,
            })
        end
    end
    return registry[id]
end

---@return boolean
function stash.add(id, name, count, metadata)
    count = Core.amount(count)
    if id == nil or not Core.text(name) or not count then return false end
    id = tostring(id)
    ensure(id)

    local hook = customHook('stashAdd')
    if hook then return Core.safe(hook, id, name, count, metadata) == true end

    local current = kind()
    if current == 'ox' then
        return Core.safe(function() return exports.ox_inventory:AddItem(id, name, count, metadata) end) == true
    end
    if current == 'qb' then
        if qbLive(id) then
            local done = Core.safe(function() return exports['qb-inventory']:AddItem(id, name, count, false, metadata, 'obsi-lib') end)
            if done ~= nil then return done == true end
        end
        return Database.add(id, name, count, metadata) == true
    end
    if current == 'qb-legacy' then return Database.add(id, name, count, metadata) == true end
    return Kvp.add(id, name, count, metadata) == true
end

---@return boolean
function stash.remove(id, name, count)
    count = Core.amount(count)
    if id == nil or not Core.text(name) or not count then return false end
    id = tostring(id)
    ensure(id)

    local hook = customHook('stashRemove')
    if hook then return Core.safe(hook, id, name, count) == true end

    local current = kind()
    if current == 'ox' then
        if stash.count(id, name) < count then return false end
        return Core.safe(function() return exports.ox_inventory:RemoveItem(id, name, count) end) == true
    end
    if current == 'qb' then
        if qbLive(id) then
            if stash.count(id, name) < count then return false end
            local done = Core.safe(function() return exports['qb-inventory']:RemoveItem(id, name, count, false, 'obsi-lib') end)
            if done ~= nil then return done == true end
        end
        return Database.remove(id, name, count) == true
    end
    if current == 'qb-legacy' then return Database.remove(id, name, count) == true end
    return Kvp.remove(id, name, count) == true
end

---Contents: list of { name, count, metadata }.
function stash.items(id)
    if id == nil then return {} end
    id = tostring(id)
    ensure(id)
    local result = {}

    local hook = customHook('stashItems')
    if hook then return Core.safe(hook, id) or result end

    local current = kind()
    if current == 'ox' then
        for _, slot in pairs(Core.safe(function() return exports.ox_inventory:GetInventoryItems(id) end) or {}) do
            if type(slot) == 'table' and slot.name then
                result[#result + 1] = { name = slot.name, count = slot.count, metadata = slot.metadata or {} }
            end
        end
        return result
    end

    if current == 'qb' and qbLive(id) then
        local live = Core.safe(function() return exports['qb-inventory']:GetInventory(id) end)
        if live and live.items then
            for _, slot in pairs(live.items) do
                if type(slot) == 'table' and slot.name then
                    result[#result + 1] = { name = slot.name, count = tonumber(slot.amount or slot.count) or 0, metadata = slot.info or {} }
                end
            end
            return result
        end
    end

    if current == 'qb' or current == 'qb-legacy' then
        for _, entry in ipairs(Database.load(id)) do
            result[#result + 1] = { name = entry.name, count = tonumber(entry.amount) or 0, metadata = entry.info or {} }
        end
        return result
    end

    for _, entry in ipairs(Kvp.load(id)) do
        result[#result + 1] = { name = entry.name, count = tonumber(entry.count) or 0, metadata = entry.metadata or {} }
    end
    return result
end

---@return number
function stash.count(id, name)
    if kind() == 'ox' then
        local count = Core.safe(function() return exports.ox_inventory:GetItemCount(tostring(id), name) end)
        if count then return math.floor(tonumber(count) or 0) end
    end
    local total = 0
    for _, entry in ipairs(stash.items(id)) do
        if entry.name == name then total = total + (tonumber(entry.count) or 0) end
    end
    return total
end

local function sendMenu(src, id)
    local def = registry[id]
    local content, pocket = {}, {}
    for _, entry in ipairs(stash.items(id)) do
        content[#content + 1] = { name = entry.name, count = entry.count, label = items.label(entry.name) }
    end
    for name, count in pairs(items.counts(src)) do
        pocket[#pocket + 1] = { name = name, count = count, label = items.label(name) }
    end
    table.sort(pocket, function(a, b) return a.label < b.label end)

    TriggerClientEvent('obsi-lib:stash:menu', src, {
        id = id, label = def.label, slots = def.slots, used = #content, items = content, inventory = pocket,
    })
end

---Opens a stash for a player (server decides; works for every inventory).
---@param overrides? { label?: string, slots?: number, weight?: number }
---@return boolean
function stash.open(src, id, overrides)
    src = tonumber(src)
    if not src or id == nil then return false end
    id = tostring(id)
    local def = ensure(id, overrides)

    local hook = customHook('openStash')
    if hook then return Core.safe(hook, src, id, def) == true end

    local current = kind()
    if current == 'ox' then
        return Core.safe(function() exports.ox_inventory:forceOpenInventory(src, 'stash', id) return true end) == true
    end
    if current == 'qb' then
        return Core.safe(function()
            exports['qb-inventory']:OpenInventory(src, id, { label = def.label, maxweight = def.weight, slots = def.slots })
            return true
        end) == true
    end
    if current == 'qb-legacy' then
        TriggerClientEvent('obsi-lib:stash:legacy', src, id, def.label, def.slots, def.weight)
        return true
    end

    sessions[src] = { id = id, expires = os.time() + (settings().SessionSeconds or 600), lastMove = 0 }
    sendMenu(src, id)
    return true
end

ObsiLib.stash = stash

---------------------------------------------------------------------------------------------------
-- Client requests
---------------------------------------------------------------------------------------------------

local function jobAllowed(src, groups)
    if type(groups) ~= 'table' then return true end
    local info = ObsiLib.job.get(src)
    local needed = groups[info.name]
    if needed == nil then
        for _, name in ipairs(groups) do
            if name == info.name then return true end
        end
        return false
    end
    return info.grade >= (tonumber(needed) or 0)
end

RegisterNetEvent('obsi-lib:stash:open', function(id)
    local src = source
    if type(id) ~= 'string' or #id > 128 then return end
    local def = registry[id]
    if not def or not def.clientOpen then return end
    if not jobAllowed(src, def.groups) then return end
    if def.coords then
        local ped = GetPlayerPed(src)
        if ped == 0 or #(GetEntityCoords(ped) - def.coords) > def.radius + 2.0 then return end
    end
    stash.open(src, id)
end)

local function refuse(src, key)
    ObsiLib.notify(src, { title = Core.t('stash_title'), description = Core.t(key), type = 'error' })
end

RegisterNetEvent('obsi-lib:stash:move', function(id, direction, name, amount)
    local src = source
    local session = sessions[src]
    if not session or session.id ~= id or session.expires < os.time() then return end

    local now = GetGameTimer()
    if now - session.lastMove < 150 then return end
    session.lastMove = now

    amount = Core.amount(amount)
    if not Core.text(name, 64) or not amount then return end

    if direction == 'take' then
        if stash.count(id, name) < amount then
            refuse(src, 'stash_not_enough_stash')
        elseif not items.canCarry(src, name, amount) then
            refuse(src, 'stash_cannot_carry')
        elseif stash.remove(id, name, amount) then
            if not items.add(src, name, amount) then
                stash.add(id, name, amount)
                refuse(src, 'stash_cannot_carry')
            end
        end
    elseif direction == 'put' then
        if items.count(src, name) < amount then
            refuse(src, 'stash_not_enough_player')
        elseif items.remove(src, name, amount) then
            if not stash.add(id, name, amount) then
                items.add(src, name, amount)
                refuse(src, 'stash_full')
            end
        end
    else
        return
    end

    session.expires = os.time() + (settings().SessionSeconds or 600)
    sendMenu(src, id)
end)

RegisterNetEvent('obsi-lib:stash:close', function()
    sessions[source] = nil
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
