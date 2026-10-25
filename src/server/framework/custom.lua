-- Custom framework adapter (server): the functions from editable/server/framework.lua, with safe
-- defaults for anything left out. Native item functions defer to editable/server/inventory.lua.

Core.frameworks.custom = function()
    local hooks = ObsiEditable and ObsiEditable.framework or {}
    local inventory = ObsiEditable and ObsiEditable.inventory or {}
    local adapter = {}

    for key, fn in pairs(hooks) do
        if type(fn) == 'function' then adapter[key] = fn end
    end

    adapter.players = adapter.players or function()
        local list = {}
        for _, id in ipairs(GetPlayers()) do list[#list + 1] = tonumber(id) end
        return list
    end
    adapter.name = adapter.name or function(src) return GetPlayerName(src) or '' end
    adapter.money = adapter.money or function() return 0 end

    adapter.addItem = adapter.addItem or function(src, name, count, metadata, slot)
        return inventory.add and inventory.add(src, name, count, metadata, slot) == true or false
    end
    adapter.removeItem = adapter.removeItem or function(src, name, count, metadata, slot)
        return inventory.remove and inventory.remove(src, name, count, metadata, slot) == true or false
    end
    adapter.itemCount = adapter.itemCount or function(src, name)
        return inventory.count and tonumber(inventory.count(src, name)) or 0
    end
    adapter.canCarry = adapter.canCarry or function(src, name, count)
        if inventory.canCarry then return inventory.canCarry(src, name, count) ~= false end
        return true
    end
    adapter.itemSlots = adapter.itemSlots or function(src, name)
        return inventory.slots and inventory.slots(src, name) or {}
    end
    adapter.inventory = adapter.inventory or function(src)
        return inventory.list and inventory.list(src) or {}
    end

    return adapter
end
