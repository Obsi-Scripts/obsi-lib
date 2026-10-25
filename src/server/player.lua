-- Players, jobs, money, licenses and admin checks (server).

local fw = Core.fw

---------------------------------------------------------------------------------------------------
-- ObsiLib.player
---------------------------------------------------------------------------------------------------

local player = {}

---Framework player object (xPlayer / QBCore Player / custom).
function player.get(src)
    return fw.player(tonumber(src))
end

---Online player ids.
---@return number[]
function player.list()
    local list = {}
    for _, id in ipairs(fw.players() or {}) do
        id = tonumber(id)
        if id then list[#list + 1] = id end
    end
    return list
end

---Character identifier (ESX identifier / citizenid).
function player.identifier(src)
    return fw.identifier(tonumber(src))
end

---Character name, falls back to the FiveM name.
function player.name(src)
    src = tonumber(src)
    local name = fw.name(src)
    if type(name) == 'string' and name ~= '' then return name end
    return GetPlayerName(src) or ''
end

---Permission group from the framework.
function player.group(src)
    return fw.group(tonumber(src))
end

---Online source of a character identifier.
function player.fromIdentifier(identifier)
    if not identifier then return nil end
    return fw.sourceOf(identifier)
end

---@return 'male'|'female'
function player.gender(src)
    src = tonumber(src)
    local value = fw.gender(src)
    if value == 'male' or value == 'female' then return value end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and GetEntityModel(ped) == `mp_f_freemode_01` then return 'female' end
    return 'male'
end

---Admin check: ACE permission, whitelisted identifiers, then framework groups.
---@param opts? { ace?: string|false, groups?: string[], identifiers?: string[] } defaults from ObsiConfig.Admin
---@return boolean
function player.isAdmin(src, opts)
    src = tonumber(src)
    if not src or src < 0 then return false end
    if src == 0 then return true end

    local defaults = ObsiConfig.Admin or {}
    opts = type(opts) == 'table' and opts or {}
    local ace = opts.ace
    if ace == nil then ace = defaults.Ace end
    local groups = opts.groups or defaults.Groups or {}
    local identifiers = opts.identifiers or defaults.Identifiers or {}

    if ace and ace ~= '' and IsPlayerAceAllowed(src, ace) then return true end

    if #identifiers > 0 then
        local wanted = {}
        for _, value in ipairs(identifiers) do wanted[value] = true end
        for _, value in ipairs(GetPlayerIdentifiers(src) or {}) do
            if wanted[value] then return true end
        end
        local character = player.identifier(src)
        if character and wanted[character] then return true end
    end

    if #groups > 0 then
        if Core.safe(fw.isAdminGroup, src, groups) then return true end
        for _, group in ipairs(groups) do
            if IsPlayerAceAllowed(src, 'group.' .. group) then return true end
        end
    end

    return false
end

ObsiLib.player = player

---------------------------------------------------------------------------------------------------
-- ObsiLib.job
---------------------------------------------------------------------------------------------------

local job = {}
local jobCache, jobCacheAt = nil, 0

---@return { name: string, label: string, grade: number, gradeLabel: string, onDuty: boolean }
function job.get(src)
    local info = fw.job(tonumber(src))
    if type(info) == 'table' and info.name then return info end
    return { name = 'unemployed', label = 'Unemployed', grade = 0, gradeLabel = '', onDuty = false }
end

---@return boolean
function job.set(src, name, grade)
    src = tonumber(src)
    if not src or type(name) ~= 'string' then return false end
    return fw.setJob(src, name, math.floor(tonumber(grade) or 0)) == true
end

---Changes the job of a character; goes through job.set when the character is online.
---@return boolean
function job.setOffline(identifier, name, grade)
    if not identifier or type(name) ~= 'string' then return false end
    grade = math.floor(tonumber(grade) or 0)
    local online = player.fromIdentifier(identifier)
    if online then return job.set(online, name, grade) end
    return fw.setOfflineJob(identifier, name, grade) == true
end

---@return boolean
function job.setDuty(src, onDuty)
    return fw.setDuty(tonumber(src), onDuty == true) == true
end

---All jobs: { [name] = { label, type, grades = { [level] = { label, payment, isboss } } } } (cached 30 s).
function job.all()
    local now = os.time()
    if jobCache and now - jobCacheAt < 30 then return jobCache end

    local list = {}
    for name, def in pairs(fw.jobs() or {}) do
        if type(def) == 'table' then
            list[name] = { label = def.label or name, type = def.type, grades = Core.normaliseGrades(def.grades) }
        end
    end
    jobCache, jobCacheAt = list, now
    return list
end

---@return boolean
function job.is(src, names)
    local current = job.get(src).name
    if type(names) == 'string' then return current == names end
    if type(names) == 'table' then
        return names[current] == true or Core.inList(names, current)
    end
    return false
end

---Number of online players with a job from ObsiConfig.PoliceJobs.
function job.copsOnline()
    local count = 0
    for _, src in ipairs(player.list()) do
        local info = job.get(src)
        if ObsiConfig.PoliceJobs[info.name] and (not ObsiConfig.CopsRequireDuty or info.onDuty) then
            count = count + 1
        end
    end
    return count
end

ObsiLib.job = job

ObsiLib.callback.register('obsi-lib:cops', function()
    return job.copsOnline()
end)

exports('copsOnline', job.copsOnline)

---------------------------------------------------------------------------------------------------
-- ObsiLib.money
---------------------------------------------------------------------------------------------------

local money = {}

---@param account? string 'cash' (default) | 'bank' | 'black' | custom account
---@return number
function money.get(src, account)
    return tonumber(fw.money(tonumber(src), Core.account(account))) or 0
end

---@return boolean
function money.add(src, amount, account, reason)
    src, amount = tonumber(src), tonumber(amount)
    if not src or not amount or amount <= 0 then return false end
    return fw.addMoney(src, amount, Core.account(account), reason) == true
end

---Removes money only when the balance covers it.
---@return boolean
function money.remove(src, amount, account, reason)
    src, amount = tonumber(src), tonumber(amount)
    if not src or not amount or amount <= 0 then return false end
    account = Core.account(account)
    if money.get(src, account) < amount then return false end
    return fw.removeMoney(src, amount, account, reason) == true
end

---@return boolean
function money.has(src, amount, account)
    return money.get(src, account) >= (tonumber(amount) or 0)
end

ObsiLib.money = money

ObsiLib.callback.register('obsi-lib:money', function(src)
    return { cash = money.get(src, 'cash'), bank = money.get(src, 'bank') }
end)

---------------------------------------------------------------------------------------------------
-- ObsiLib.license
---------------------------------------------------------------------------------------------------

local license = {}

---@return boolean
function license.has(src, name)
    if type(name) ~= 'string' then return false end
    return fw.hasLicense(tonumber(src), name) == true
end

ObsiLib.license = license

ObsiLib.callback.register('obsi-lib:license', function(src, name)
    if type(name) ~= 'string' or #name > 64 then return false end
    return license.has(src, name)
end)
