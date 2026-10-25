--[[
    FRAMEWORK HOOKS - SERVER

    ObsiEditable.framework
        Full implementation used when ObsiConfig.Framework = 'custom'. Fill in what your framework supports;
        anything left out falls back to a safe default (nil / false / 0).

    ObsiEditable.frameworkPatch
        Optional overrides applied on top of ANY framework (esx / qb / qbx / custom). Put a function here
        with the same name as below to replace just that piece, e.g. a different gender source.
]]

ObsiEditable = ObsiEditable or {}

ObsiEditable.framework = {
    ---@return number[] online player ids
    players = function()
        local list = {}
        for _, id in ipairs(GetPlayers()) do list[#list + 1] = tonumber(id) end
        return list
    end,

    ---@param src number
    ---@return table|nil your framework's player object
    player = function(src)
        return nil
    end,

    ---@param src number
    ---@return string|nil unique character identifier
    identifier = function(src)
        return nil
    end,

    ---@param src number
    ---@return string character name
    name = function(src)
        return GetPlayerName(src) or ''
    end,

    ---@param src number
    ---@return string|nil permission group
    group = function(src)
        return nil
    end,

    ---@param src number
    ---@return table|nil { name, label, grade, gradeLabel, onDuty }
    job = function(src)
        return nil
    end,

    ---@return boolean
    setJob = function(src, job, grade)
        return false
    end,

    ---@return boolean
    setOfflineJob = function(identifier, job, grade)
        return false
    end,

    ---@return boolean
    setDuty = function(src, onDuty)
        return false
    end,

    ---@return table { [name] = { label, grades = { [grade] = { label, payment, isboss } } } }
    jobs = function()
        return {}
    end,

    ---@return number|nil online source of a character identifier
    sourceOf = function(identifier)
        return nil
    end,

    ---@return 'male'|'female'|nil
    gender = function(src)
        return nil
    end,

    ---@param groups string[]
    ---@return boolean
    isAdminGroup = function(src, groups)
        return false
    end,

    ---@param account string 'cash' | 'bank' | 'black' | custom
    ---@return number
    money = function(src, account)
        return 0
    end,

    ---@return boolean
    addMoney = function(src, amount, account, reason)
        return false
    end,

    ---@return boolean
    removeMoney = function(src, amount, account, reason)
        return false
    end,

    ---@return boolean
    hasLicense = function(src, license)
        return false
    end,

    ---@return table { [name] = { label, weight } } item definitions
    items = function()
        return {}
    end,

    ---@param handler fun(src: number, data: table|nil)
    ---@return boolean registered
    useable = function(name, handler)
        return false
    end,
}

ObsiEditable.frameworkPatch = {
    -- gender = function(src) return 'male' end,
}
