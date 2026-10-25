--[[
    INVENTORY HOOKS - SERVER

    ObsiEditable.inventory
        Full implementation used when ObsiConfig.Inventory = 'custom'. Return nil from a function to let
        obsi-lib fall back to the framework's own item functions.

    ObsiEditable.inventoryPatch
        Optional overrides applied on top of ANY detected inventory (same function names).

    Stash functions are optional: leave them out and obsi-lib keeps custom stashes in resource KVP with
    its own small menu.
]]

ObsiEditable = ObsiEditable or {}

ObsiEditable.inventory = {
    ---@return boolean|nil
    add = function(src, name, count, metadata, slot)
        return nil
    end,

    ---@return boolean|nil
    remove = function(src, name, count, metadata, slot)
        return nil
    end,

    ---@return number|nil
    count = function(src, name, metadata)
        return nil
    end,

    ---@return table|nil list of { name, count, metadata, slot }
    list = function(src)
        return nil
    end,

    ---@return table|nil list of { slot, count, metadata }
    slots = function(src, name)
        return nil
    end,

    ---@return boolean|nil
    canCarry = function(src, name, count, metadata)
        return nil
    end,

    ---@return table|nil { [name] = { label, weight, image } }
    catalog = function()
        return nil
    end,

    -- registerStash = function(id, def) return true end,          -- def = { label, slots, weight, groups }
    -- openStash = function(src, id, def) return true end,
    -- stashAdd = function(id, name, count, metadata) return true end,
    -- stashRemove = function(id, name, count) return true end,
    -- stashItems = function(id) return {} end,                    -- list of { name, count, metadata }
}

ObsiEditable.inventoryPatch = {
    -- canCarry = function(src, name, count, metadata) return true end,
}
