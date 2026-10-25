--[[
    FRAMEWORK HOOKS - CLIENT
    ObsiEditable.framework is used when ObsiConfig.Framework = 'custom'.
    ObsiEditable.frameworkPatch overrides single functions on top of any framework.
]]

ObsiEditable = ObsiEditable or {}

ObsiEditable.framework = {
    ---@return table local player data
    playerData = function()
        return {}
    end,

    ---@return table|nil { name, label, grade, gradeLabel, onDuty }
    job = function()
        return nil
    end,

    ---@return 'male'|'female'|nil
    gender = function()
        return nil
    end,
}

ObsiEditable.frameworkPatch = {
    -- job = function() return { name = 'police', label = 'Police', grade = 0, gradeLabel = '', onDuty = true } end,
}
