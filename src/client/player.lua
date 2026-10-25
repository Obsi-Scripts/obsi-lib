-- Local player, job, money and licenses (client).

local adapters = {}

adapters.esx = {
    playerData = function()
        local ESX = Core.frameworkObject()
        return ESX and ESX.GetPlayerData() or {}
    end,
    job = function()
        local ESX = Core.frameworkObject()
        local job = ESX and ESX.GetPlayerData().job
        if not job then return nil end
        return { name = job.name, label = job.label or job.name, grade = tonumber(job.grade) or 0, gradeLabel = job.grade_label or '', onDuty = job.onDuty ~= false }
    end,
    gender = function()
        local ESX = Core.frameworkObject()
        return ESX and Core.gender(ESX.GetPlayerData().sex) or nil
    end,
}

adapters.qb = {
    playerData = function()
        if ObsiLib.framework == 'qbx' then
            local data = Core.safe(function() return exports.qbx_core:GetPlayerData() end)
            if data then return data end
        end
        local QBCore = Core.frameworkObject()
        return QBCore and QBCore.Functions.GetPlayerData() or {}
    end,
    job = function()
        local job = adapters.qb.playerData().job
        if not job then return nil end
        local grade = type(job.grade) == 'table' and job.grade or { level = job.grade, name = '' }
        return { name = job.name, label = job.label or job.name, grade = tonumber(grade.level) or 0, gradeLabel = grade.name or '', onDuty = job.onduty == true }
    end,
    gender = function()
        local info = adapters.qb.playerData().charinfo
        return info and Core.gender(info.gender) or nil
    end,
}
adapters.qbx = adapters.qb

local active

local function fw()
    if active then return active end
    local base = ObsiLib.framework == 'custom' and (ObsiEditable and ObsiEditable.framework or {}) or adapters[ObsiLib.framework] or {}
    active = {}
    for key, fn in pairs(base) do active[key] = fn end
    for key, fn in pairs(ObsiEditable and ObsiEditable.frameworkPatch or {}) do
        if type(fn) == 'function' then active[key] = fn end
    end
    return active
end

local function call(key, ...)
    local fn = fw()[key]
    if not fn then return nil end
    return Core.safe(fn, ...)
end

---------------------------------------------------------------------------------------------------
-- ObsiLib.player
---------------------------------------------------------------------------------------------------

local player = {}

---Framework player data table.
function player.data()
    return call('playerData') or {}
end

---@return 'male'|'female'
function player.gender()
    local value = call('gender')
    if value == 'male' or value == 'female' then return value end
    return GetEntityModel(PlayerPedId()) == `mp_f_freemode_01` and 'female' or 'male'
end

---@return boolean
function player.isDead()
    local ped = PlayerPedId()
    return IsEntityDead(ped) or IsPedFatallyInjured(ped)
end

ObsiLib.player = player

---------------------------------------------------------------------------------------------------
-- ObsiLib.job
---------------------------------------------------------------------------------------------------

local job = {}

---@return { name: string, label: string, grade: number, gradeLabel: string, onDuty: boolean }
function job.get()
    local info = call('job')
    if type(info) == 'table' and info.name then return info end
    return { name = 'unemployed', label = 'Unemployed', grade = 0, gradeLabel = '', onDuty = false }
end

---@param names string|string[]|table<string, boolean>
---@return boolean
function job.is(names)
    local current = job.get().name
    if type(names) == 'string' then return current == names end
    if type(names) ~= 'table' then return false end
    if names[current] == true then return true end
    for _, name in ipairs(names) do
        if name == current then return true end
    end
    return false
end

---Number of police officers online (asks the server).
function job.copsOnline()
    return ObsiLib.callback.await('obsi-lib:cops') or 0
end

ObsiLib.job = job

---------------------------------------------------------------------------------------------------
-- ObsiLib.money / ObsiLib.license (server is the source of truth)
---------------------------------------------------------------------------------------------------

ObsiLib.money = {
    ---Cash and bank balance. Blocking without cb, or async with cb(cash, bank).
    get = function(cb)
        if cb then
            ObsiLib.callback.trigger('obsi-lib:money', nil, function(result)
                result = result or {}
                cb(result.cash or 0, result.bank or 0)
            end)
            return
        end
        local result = ObsiLib.callback.await('obsi-lib:money') or {}
        return result.cash or 0, result.bank or 0
    end,
}

ObsiLib.license = {
    ---Blocking without cb, or async with cb(has).
    has = function(name, cb)
        if cb then
            ObsiLib.callback.trigger('obsi-lib:license', name, function(has) cb(has == true) end)
            return
        end
        return ObsiLib.callback.await('obsi-lib:license', name) == true
    end,
}
