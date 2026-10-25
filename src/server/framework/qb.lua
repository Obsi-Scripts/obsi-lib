-- QBCore and QBX adapter (server). QBX is served by the same adapter with qbx_core exports where they exist.

local function buildQb(id)
    local isQbx = id == 'qbx' or Core.started('qbx_core')
    local QBCore

    if Core.started('qb-core') then
        QBCore = Core.safe(function() return exports['qb-core']:GetCoreObject() end)
    end
    if not QBCore and Core.started('qbx_core') then
        QBCore = Core.safe(function() return exports.qbx_core:GetCoreObject() end)
    end
    if not QBCore and not isQbx then error('qb-core core object is unavailable') end

    local offline = ObsiConfig.OfflineJobTables.qb
    local ACCOUNTS = { cash = 'cash', bank = 'bank', black = 'black_money' }

    local function accountName(account)
        local normalised = Core.account(account)
        return ACCOUNTS[normalised] or normalised
    end

    local function playerOf(src)
        if isQbx then
            local player = Core.safe(function() return exports.qbx_core:GetPlayer(src) end)
            if player then return player end
        end
        return QBCore and QBCore.Functions.GetPlayer(src) or nil
    end

    local function dataOf(src)
        local player = playerOf(src)
        return player and player.PlayerData or nil
    end

    local function rawJobs()
        if isQbx then
            local jobs = Core.safe(function() return exports.qbx_core:GetJobs() end)
            if jobs then return jobs end
        end
        return QBCore and QBCore.Shared and QBCore.Shared.Jobs or {}
    end

    local qb = {}

    function qb.player(src)
        return playerOf(src)
    end

    function qb.players()
        local list = {}
        local ids = QBCore and QBCore.Functions.GetPlayers() or GetPlayers()
        for _, entry in pairs(ids or {}) do
            list[#list + 1] = type(entry) == 'table' and entry.PlayerData and entry.PlayerData.source or tonumber(entry)
        end
        return list
    end

    function qb.identifier(src)
        local data = dataOf(src)
        return data and data.citizenid or nil
    end

    function qb.name(src)
        local data = dataOf(src)
        local info = data and data.charinfo
        if info and (info.firstname or info.lastname) then
            return ObsiLib.util.trim(('%s %s'):format(info.firstname or '', info.lastname or ''))
        end
        return GetPlayerName(src) or ''
    end

    function qb.group(src)
        if QBCore and QBCore.Functions.GetPermission then
            local permission = Core.safe(QBCore.Functions.GetPermission, src)
            if type(permission) == 'table' then
                for group, allowed in pairs(permission) do
                    if allowed then return group end
                end
            elseif type(permission) == 'string' then
                return permission
            end
        end
        local data = dataOf(src)
        return data and data.group or nil
    end

    function qb.job(src)
        local data = dataOf(src)
        local job = data and data.job
        if not job then return nil end
        local grade = type(job.grade) == 'table' and job.grade or { level = job.grade, name = '' }
        return {
            name = job.name,
            label = job.label or job.name,
            grade = tonumber(grade.level) or 0,
            gradeLabel = grade.name or '',
            onDuty = job.onduty == true,
        }
    end

    function qb.setJob(src, name, grade)
        if isQbx then
            local citizenid = qb.identifier(src)
            local done = citizenid and Core.safe(function()
                exports.qbx_core:AddPlayerToJob(citizenid, name, grade)
                exports.qbx_core:SetPlayerPrimaryJob(citizenid, name)
                return true
            end)
            if done then return true end
        end
        local player = playerOf(src)
        if not player then return false end
        return Core.safe(function() return player.Functions.SetJob(name, grade) ~= false end) == true
    end

    local function jobPayload(name, grade)
        local def = rawJobs()[name] or { label = name, grades = {} }
        local gradeDef = def.grades and (def.grades[grade] or def.grades[tostring(grade)]) or {}
        return {
            name = name,
            label = def.label or name,
            type = def.type,
            payment = gradeDef.payment or 0,
            onduty = false,
            isboss = gradeDef.isboss == true,
            grade = { name = gradeDef.name or tostring(grade), level = grade },
        }
    end

    function qb.setOfflineJob(identifier, name, grade)
        if isQbx then
            local done = Core.safe(function()
                exports.qbx_core:AddPlayerToJob(identifier, name, grade)
                exports.qbx_core:SetPlayerPrimaryJob(identifier, name)
                return true
            end)
            if done then return true end
        end
        local query = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ?'):format(offline.table, offline.column, offline.identifier)
        local affected = Core.safe(MySQL.update.await, query, { json.encode(jobPayload(name, grade)), identifier })
        return (tonumber(affected) or 0) > 0
    end

    function qb.setDuty(src, onDuty)
        if isQbx then
            if Core.safe(function() exports.qbx_core:SetJobDuty(src, onDuty) return true end) then return true end
        end
        local player = playerOf(src)
        if not player then return false end
        if player.PlayerData.job and player.PlayerData.job.onduty == onDuty then return true end
        local done = Core.safe(function() player.Functions.SetJobDuty(onDuty) return true end) == true
        if done then
            TriggerClientEvent('QBCore:Client:SetDuty', src, onDuty)
            TriggerEvent('QBCore:Server:SetDuty', src, onDuty)
        end
        return done
    end

    function qb.jobs()
        return rawJobs()
    end

    function qb.sourceOf(identifier)
        local player
        if isQbx then
            player = Core.safe(function() return exports.qbx_core:GetPlayerByCitizenId(identifier) end)
        end
        player = player or (QBCore and Core.safe(QBCore.Functions.GetPlayerByCitizenId, identifier))
        return player and player.PlayerData and player.PlayerData.source or nil
    end

    function qb.gender(src)
        local data = dataOf(src)
        return data and data.charinfo and Core.gender(data.charinfo.gender) or nil
    end

    function qb.isAdminGroup(src, groups)
        for _, group in ipairs(groups or {}) do
            if QBCore and Core.safe(QBCore.Functions.HasPermission, src, group) then return true end
        end
        return false
    end

    function qb.money(src, account)
        local data = dataOf(src)
        return data and data.money and tonumber(data.money[accountName(account)]) or 0
    end

    function qb.addMoney(src, amount, account, reason)
        local player = playerOf(src)
        if not player then return false end
        return Core.safe(player.Functions.AddMoney, accountName(account), amount, reason or 'obsi-lib') ~= false
    end

    function qb.removeMoney(src, amount, account, reason)
        local player = playerOf(src)
        if not player or qb.money(src, account) < amount then return false end
        return Core.safe(player.Functions.RemoveMoney, accountName(account), amount, reason or 'obsi-lib') == true
    end

    function qb.hasLicense(src, license)
        local data = dataOf(src)
        local meta = data and data.metadata or {}
        local list = meta.licences or meta.licenses or {}
        return list[license] == true
    end

    function qb.items()
        if isQbx and Core.started('ox_inventory') then
            local items = Core.safe(function() return exports.ox_inventory:Items() end)
            if items then return items end
        end
        return QBCore and QBCore.Shared and QBCore.Shared.Items or {}
    end

    function qb.useable(name, handler)
        return Core.safe(function()
            local wrapped = function(src, data) handler(src, data) end
            if isQbx then
                exports.qbx_core:CreateUseableItem(name, wrapped)
            else
                QBCore.Functions.CreateUseableItem(name, wrapped)
            end
            return true
        end) == true
    end

    -- Native inventory through Player.Functions (qb-inventory v1, ps-inventory, lj-inventory ...).

    function qb.canCarry()
        return true
    end

    function qb.addItem(src, name, count, metadata, slot)
        local player = playerOf(src)
        if not player then return false end
        return Core.safe(player.Functions.AddItem, name, count, slot or false, metadata) == true
    end

    function qb.removeItem(src, name, count, _, slot)
        local player = playerOf(src)
        if not player or qb.itemCount(src, name) < count then return false end
        return Core.safe(player.Functions.RemoveItem, name, count, slot or false) == true
    end

    function qb.itemCount(src, name)
        local total = 0
        for _, item in ipairs(qb.inventory(src)) do
            if item.name == name then total = total + item.count end
        end
        return total
    end

    function qb.itemSlots(src, name)
        local result = {}
        for _, item in ipairs(qb.inventory(src)) do
            if item.name == name then result[#result + 1] = { slot = item.slot, count = item.count, metadata = item.metadata } end
        end
        return result
    end

    function qb.inventory(src)
        local data = dataOf(src)
        local list = {}
        for _, item in pairs(data and data.items or {}) do
            if type(item) == 'table' and item.name then
                local count = tonumber(item.amount or item.count) or 0
                if count > 0 then
                    list[#list + 1] = { name = item.name, count = count, metadata = item.info or item.metadata or {}, slot = item.slot }
                end
            end
        end
        return list
    end

    return qb
end

Core.frameworks.qb = buildQb
Core.frameworks.qbx = buildQb
