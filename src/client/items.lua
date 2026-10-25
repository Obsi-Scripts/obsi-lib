-- Player items (client, read only - the server decides every change).

local function normalise(raw)
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

local function frameworkList()
    local data = ObsiLib.player.data()
    return normalise(data.inventory or data.items)
end

local adapters = {
    ox = {
        count = function(name, metadata) return tonumber(exports.ox_inventory:GetItemCount(name, metadata)) or 0 end,
        list = function() return normalise(exports.ox_inventory:GetPlayerItems()) end,
    },
    codem = {
        list = function()
            local raw = Core.safe(function() return exports['codem-inventory']:GetClientPlayerInventory() end)
            if type(raw) ~= 'table' then raw = Core.safe(function() return exports['codem-inventory']:getUserInventory() end) end
            return normalise(raw)
        end,
    },
    jaksam = {
        count = function(name, metadata) return tonumber(exports.jaksam_inventory:getTotalItemAmount(name, metadata)) or 0 end,
        list = function()
            local inventory = exports.jaksam_inventory:getInventory()
            return normalise(type(inventory) == 'table' and inventory.items or inventory)
        end,
    },
}

local function adapter()
    local kind = Core.inventoryKind()
    local base = kind == 'custom' and (ObsiEditable and ObsiEditable.inventory or {}) or adapters[kind] or {}
    local patch = ObsiEditable and ObsiEditable.inventoryPatch or {}
    return {
        count = patch.count or base.count,
        list = patch.list or base.list,
    }
end

local items = {}

---Every item the player has: list of { name, count, metadata, slot }.
function items.list()
    local fn = adapter().list
    local list = fn and Core.safe(fn)
    if type(list) == 'table' then return normalise(list) end
    return frameworkList()
end

---@return number
function items.count(name, metadata)
    if type(name) ~= 'string' then return 0 end
    local fn = adapter().count
    local count = fn and Core.safe(fn, name, metadata)
    if count ~= nil then return math.floor(tonumber(count) or 0) end
    local total = 0
    for _, item in ipairs(items.list()) do
        if item.name == name then total = total + item.count end
    end
    return total
end

---@return boolean
function items.has(name, count)
    return items.count(name) >= (tonumber(count) or 1)
end

---@return table<string, number>
function items.counts()
    local counts = {}
    for _, item in ipairs(items.list()) do
        counts[item.name] = (counts[item.name] or 0) + item.count
    end
    return counts
end

ObsiLib.items = items
