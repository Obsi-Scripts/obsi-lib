-- Player items (server): one API over ox_inventory, qb-inventory (v2 and legacy forks), codem-inventory,
-- jaksam_inventory, custom hooks and the framework's own item functions.
-- Every write validates its input and removals check the count first, so a failed or partial call never
-- reports success.

local fw = Core.fw

local function itemBox(src, name, action, count)
    -- qb-inventory shows its item popup only when asked; qbx uses ox_inventory and has none.
    if ObsiLib.framework ~= 'qb' then return end
    local def = (fw.items() or {})[name]
    if def then TriggerClientEvent('qb-inventory:client:ItemBox', src, def, action, count) end
end

local function listToCounts(list)
    local counts = {}
    for _, item in pairs(list or {}) do
        if type(item) == 'table' and item.name then
            counts[item.name] = (counts[item.name] or 0) + (tonumber(item.count or item.amount) or 0)
        end
    end
    return counts
end

local function normaliseList(raw)
    local list = {}
    for _, item in pairs(raw or {}) do
        if type(item) == 'table' and item.name then
            local count = tonumber(item.count or item.amount) or 0
            if count > 0 then
                list[#list + 1] = { name = item.name, count = count, metadata = item.metadata or item.info or {}, slot = item.slot }
            end
        end
    end
    return list
end

---------------------------------------------------------------------------------------------------
-- Adapters: add / remove / count / list / slots / canCarry / catalog. nil means "not handled".
---------------------------------------------------------------------------------------------------

local native = {
    add = function(src, name, count, metadata, slot)
        local done = fw.addItem(src, name, count, metadata, slot) == true
        if done then itemBox(src, name, 'add', count) end
        return done
    end,
    remove = function(src, name, count, metadata, slot)
        local done = fw.removeItem(src, name, count, metadata, slot) == true
        if done then itemBox(src, name, 'remove', count) end
        return done
    end,
    count = function(src, name) return tonumber(fw.itemCount(src, name)) or 0 end,
    list = function(src) return fw.inventory(src) or {} end,
    slots = function(src, name) return fw.itemSlots(src, name) or {} end,
    canCarry = function(src, name, count) return fw.canCarry(src, name, count) ~= false end,
    catalog = function() return fw.items() or {} end,
}

local adapters = {}

adapters.ox = {
    add = function(src, name, count, metadata, slot)
        return exports.ox_inventory:AddItem(src, name, count, metadata, slot) == true
    end,
    remove = function(src, name, count, metadata, slot)
        return exports.ox_inventory:RemoveItem(src, name, count, metadata, slot) == true
    end,
    count = function(src, name, metadata)
        return tonumber(exports.ox_inventory:GetItemCount(src, name, metadata)) or 0
    end,
    list = function(src)
        return normaliseList(exports.ox_inventory:GetInventoryItems(src))
    end,
    slots = function(src, name)
        local result = {}
        for _, slot in pairs(exports.ox_inventory:Search(src, 'slots', name) or {}) do
            result[#result + 1] = { slot = slot.slot, count = slot.count, metadata = slot.metadata or {} }
        end
        return result
    end,
    canCarry = function(src, name, count, metadata)
        return exports.ox_inventory:CanCarryItem(src, name, count, metadata) == true
    end,
    catalog = function()
        return exports.ox_inventory:Items()
    end,
}

adapters.qb = {
    add = function(src, name, count, metadata, slot)
        local done = exports['qb-inventory']:AddItem(src, name, count, slot or false, metadata, 'obsi-lib') == true
        if done then itemBox(src, name, 'add', count) end
        return done
    end,
    remove = function(src, name, count, _, slot)
        local done = exports['qb-inventory']:RemoveItem(src, name, count, slot or false, 'obsi-lib') == true
        if done then itemBox(src, name, 'remove', count) end
        return done
    end,
    count = function(src, name)
        return tonumber(exports['qb-inventory']:GetItemCount(src, name)) or 0
    end,
    list = native.list,
    slots = function(src, name)
        local result = {}
        for _, slot in pairs(exports['qb-inventory']:GetItemsByName(src, name) or {}) do
            result[#result + 1] = { slot = slot.slot, count = slot.amount or slot.count, metadata = slot.info or {} }
        end
        return result
    end,
    canCarry = function(src, name, count)
        local ok = exports['qb-inventory']:CanAddItem(src, name, count)
        if type(ok) == 'table' then return ok[1] == true end
        return ok == true
    end,
    catalog = native.catalog,
}

adapters['qb-legacy'] = native
adapters.framework = native

adapters.codem = {
    add = function(src, name, count, metadata, slot)
        return exports['codem-inventory']:AddItem(src, name, count, slot, metadata) ~= false
    end,
    remove = function(src, name, count, _, slot)
        return exports['codem-inventory']:RemoveItem(src, name, count, slot) ~= false
    end,
    count = function(src, name)
        return tonumber(exports['codem-inventory']:GetItemsTotalAmount(src, name)) or 0
    end,
    list = function(src)
        return normaliseList(exports['codem-inventory']:GetInventory(fw.identifier(src), src))
    end,
    catalog = native.catalog,
}

-- jaksam_inventory addresses player inventories by tostring(source).
adapters.jaksam = {
    add = function(src, name, count, metadata, slot)
        return exports.jaksam_inventory:addItem(tostring(src), name, count, metadata, slot) == true
    end,
    remove = function(src, name, count, metadata, slot)
        return exports.jaksam_inventory:removeItem(tostring(src), name, count, metadata, slot) == true
    end,
    count = function(src, name, metadata)
        return tonumber(exports.jaksam_inventory:getTotalItemAmount(tostring(src), name, metadata)) or 0
    end,
    list = function(src)
        local inventory = exports.jaksam_inventory:getInventory(tostring(src))
        return normaliseList(type(inventory) == 'table' and inventory.items or inventory)
    end,
    catalog = native.catalog,
}

adapters.custom = setmetatable({}, {
    __index = function(_, key)
        local hooks = ObsiEditable and ObsiEditable.inventory or {}
        return hooks[key]
    end,
})

local current, currentKind, legacyResource

local function resolve()
    currentKind, legacyResource = Core.inventoryKind()
    local base = adapters[currentKind] or native
    local patched = {}
    for key, fn in pairs(native) do patched[key] = base[key] or fn end
    if currentKind == 'custom' then
        for key in pairs(native) do
            local hook = adapters.custom[key]
            patched[key] = hook and function(...)
                local result = hook(...)
                if result == nil then return native[key](...) end
                return result
            end or native[key]
        end
    end
    for key, fn in pairs(ObsiEditable and ObsiEditable.inventoryPatch or {}) do
        if type(fn) == 'function' then patched[key] = fn end
    end
    current = patched
    Core.trace('inventory adapter: %s', currentKind)
end

---Active adapter (built on first use).
function Core.inv()
    if not current then resolve() end
    return current, currentKind, legacyResource
end

function Core.resetInventory()
    current = nil
    ObsiLib.inventory = Core.detectInventory()
end

---Reads through the adapter; an error or nil answer falls back to the framework's own function.
local function read(key, ...)
    local adapter = Core.inv()
    local packed = table.pack(pcall(adapter[key], ...))
    if packed[1] and packed[2] ~= nil then return table.unpack(packed, 2, packed.n) end
    if not packed[1] then Core.trace('inventory %s failed: %s', key, tostring(packed[2])) end
    if adapter[key] ~= native[key] then
        return Core.safe(native[key], ...)
    end
    return nil
end

---Writes through the adapter. No fallback after an error: the inventory may have applied part of it.
local function write(key, ...)
    local adapter = Core.inv()
    local ok, result = pcall(adapter[key], ...)
    if not ok then
        Core.warn('inventory %s failed: %s', key, tostring(result))
        return false
    end
    return result == true
end

---------------------------------------------------------------------------------------------------
-- ObsiLib.items
---------------------------------------------------------------------------------------------------

local items = {}

---@return boolean
function items.add(src, name, count, metadata, slot)
    src, count = tonumber(src), Core.amount(count)
    if not src or not Core.text(name) or not count then return false end
    return write('add', src, name, count, metadata, slot)
end

---Removes items only when the player owns enough of them.
---@return boolean
function items.remove(src, name, count, metadata, slot)
    src, count = tonumber(src), Core.amount(count)
    if not src or not Core.text(name) or not count then return false end
    if items.count(src, name, metadata) < count then return false end
    return write('remove', src, name, count, metadata, slot)
end

---@return number
function items.count(src, name, metadata)
    src = tonumber(src)
    if not src or not Core.text(name) then return 0 end
    return math.floor(tonumber(read('count', src, name, metadata)) or 0)
end

---@return boolean
function items.has(src, name, count)
    return items.count(src, name) >= (tonumber(count) or 1)
end

---Every item the player has: list of { name, count, metadata, slot }.
function items.list(src)
    src = tonumber(src)
    if not src then return {} end
    return normaliseList(read('list', src) or {})
end

---Item counts: { [name] = count }.
function items.counts(src)
    return listToCounts(items.list(src))
end

---Slots holding an item: list of { slot, count, metadata }.
function items.find(src, name)
    src = tonumber(src)
    if not src or not Core.text(name) then return {} end
    return read('slots', src, name) or {}
end

---@return boolean
function items.canCarry(src, name, count, metadata)
    src, count = tonumber(src), Core.amount(count)
    if not src or not Core.text(name) or not count then return false end
    return read('canCarry', src, name, count, metadata) ~= false
end

local catalogCache, catalogAt = nil, 0

local function imageFor(name, def)
    local templates = ObsiConfig.ItemImages or {}
    local _, kind, legacy = Core.inv()

    if kind == 'ox' then
        local image = def and def.client and def.client.image
        if image then
            if image:find('://', 1, true) then return image end
            return ('nui://ox_inventory/web/images/%s'):format(image)
        end
        return (templates.ox or templates.default):format(name)
    end
    if kind == 'qb' then
        return templates.qb:format(def and def.image or (name .. '.png'))
    end
    if kind == 'qb-legacy' then
        return templates['qb-legacy']:format(legacy or 'qb-inventory', def and def.image or (name .. '.png'))
    end
    return templates.default:format(name)
end

---Item definitions: { [name] = { label, weight, image, description } } (cached).
function items.catalog()
    local now = os.time()
    if catalogCache and now - catalogAt < (ObsiConfig.ItemCatalogCacheSeconds or 60) then return catalogCache end

    local list = {}
    for name, def in pairs(read('catalog') or {}) do
        if type(def) == 'table' then
            list[name] = {
                label = def.label or name,
                weight = tonumber(def.weight) or 0,
                description = def.description,
                image = def.image and def.image:find('://', 1, true) and def.image or imageFor(name, def),
            }
        end
    end
    catalogCache, catalogAt = list, now
    return list
end

---@return string label (the name itself when unknown)
function items.label(name)
    local def = items.catalog()[name]
    return def and def.label or tostring(name)
end

---@return string nui:// image url
function items.image(name)
    local def = items.catalog()[name]
    return def and def.image or imageFor(name, nil)
end

---------------------------------------------------------------------------------------------------
-- Usable items
---------------------------------------------------------------------------------------------------

local useHandlers = {}
local nativeRegistered = {}
local lastUse = {}

local function dispatchUse(src, name, metadata, slot)
    local entry = useHandlers[name]
    src = tonumber(src)
    if not entry or not src then return false end

    -- ox_inventory can report a single use through both the export and the event.
    local key = ('%d:%s:%s'):format(src, name, tostring(slot or 0))
    local now = GetGameTimer()
    if lastUse[key] and now - lastUse[key] < 300 then return true end
    lastUse[key] = now

    local ok, err = pcall(entry, src, name, metadata or {}, slot)
    if not ok then Core.warn('usable item "%s" handler failed: %s', name, tostring(err)) end
    return true
end

---Registers a usable item handler: fn(src, itemName, metadata, slot).
---With ox_inventory the item needs `server = { export = 'obsi-lib.useItem' }` or must be usable (consume = 0).
---@return boolean
function items.useable(name, fn)
    if not Core.text(name) or (type(fn) ~= 'function' and type(fn) ~= 'table') then return false end
    useHandlers[name] = fn

    local owner = Core.caller()
    Core.own(owner, function()
        if useHandlers[name] == fn then useHandlers[name] = nil end
    end)

    local _, kind = Core.inv()
    if kind == 'ox' or nativeRegistered[name] then return true end

    local registered = fw.useable(name, function(src, data)
        local meta = type(data) == 'table' and (data.metadata or data.info) or {}
        dispatchUse(src, name, meta, type(data) == 'table' and data.slot or nil)
    end)
    nativeRegistered[name] = registered == true
    return nativeRegistered[name]
end

AddEventHandler('ox_inventory:usedItem', function(playerId, name, slotId, metadata)
    dispatchUse(playerId, name, metadata, slotId)
end)

-- ox_inventory item definition: server = { export = 'obsi-lib.useItem' }
-- Returning false on 'usingItem' leaves consumption to the handler.
exports('useItem', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    local name = type(item) == 'table' and item.name or item
    if not useHandlers[name] then return end

    local src = type(inventory) == 'table' and inventory.id or inventory
    local slotId, metadata = slot, nil
    if type(slot) == 'table' then
        slotId, metadata = slot.slot, slot.metadata
    else
        local found = Core.safe(function() return exports.ox_inventory:GetSlot(src, slot) end)
        metadata = found and found.metadata
    end

    dispatchUse(src, name, metadata, slotId)
    return false
end)

AddEventHandler('playerDropped', function()
    local prefix = ('%d:'):format(source)
    for key in pairs(lastUse) do
        if key:sub(1, #prefix) == prefix then lastUse[key] = nil end
    end
end)

ObsiLib.items = items
