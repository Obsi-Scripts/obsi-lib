--[[
    INVENTORY HOOKS - CLIENT
    ObsiEditable.inventory is used when ObsiConfig.Inventory = 'custom' (return nil to fall back to the
    framework's player data). ObsiEditable.inventoryPatch overrides single functions on any inventory.
]]

ObsiEditable = ObsiEditable or {}

ObsiEditable.inventory = {
    ---@return number|nil
    count = function(name)
        return nil
    end,

    ---@return table|nil list of { name, count, metadata, slot }
    list = function()
        return nil
    end,
}

ObsiEditable.inventoryPatch = {}
