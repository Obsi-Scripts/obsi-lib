-- ESX Legacy adapter (server).

Core.frameworks.esx = function()
    local ESX = exports.es_extended:getSharedObject()
    local offline = ObsiConfig.OfflineJobTables.esx
    local ACCOUNTS = { cash = 'money', bank = 'bank', black = 'black_money' }

    local function accountName(account)
        local normalised = Core.account(account)
        return ACCOUNTS[normalised] or normalised
    end

    local function xPlayerOf(src)
        return ESX.GetPlayerFromId(src)
    end

    local esx = {}

    function esx.player(src)
        return xPlayerOf(src)
    end

    function esx.players()
        local list = {}
        for _, entry in pairs(ESX.GetPlayers() or {}) do
            list[#list + 1] = type(entry) == 'table' and entry.source or tonumber(entry)
        end
        return list
    end

    function esx.identifier(src)
        local xPlayer = xPlayerOf(src)
        return xPlayer and xPlayer.identifier or nil
    end

    function esx.name(src)
        local xPlayer = xPlayerOf(src)
        if xPlayer then
            local full = Core.safe(function() return xPlayer.getName() end)
            if type(full) == 'string' and full ~= '' then return full end
            local first, last = Core.safe(xPlayer.get, 'firstName'), Core.safe(xPlayer.get, 'lastName')
            if first and last then return ('%s %s'):format(first, last) end
        end
        return GetPlayerName(src) or ''
    end

    function esx.group(src)
        local xPlayer = xPlayerOf(src)
        return xPlayer and Core.safe(xPlayer.getGroup) or nil
    end

    function esx.job(src)
        local xPlayer = xPlayerOf(src)
        local job = xPlayer and xPlayer.job
        if not job then return nil end
        return {
            name = job.name,
            label = job.label or job.name,
            grade = tonumber(job.grade) or 0,
            gradeLabel = job.grade_label or job.grade_name or '',
            onDuty = job.onDuty ~= false,
        }
    end

    function esx.setJob(src, name, grade)
        local xPlayer = xPlayerOf(src)
        if not xPlayer then return false end
        if ESX.DoesJobExist and not ESX.DoesJobExist(name, grade) then return false end
        return Core.safe(function() xPlayer.setJob(name, grade) return true end) == true
    end

    function esx.setOfflineJob(identifier, name, grade)
        local query = ('UPDATE `%s` SET `%s` = ?, `%s` = ? WHERE `%s` = ?'):format(offline.table, offline.job, offline.grade, offline.identifier)
        local affected = Core.safe(MySQL.update.await, query, { name, grade, identifier })
        return (tonumber(affected) or 0) > 0
    end

    function esx.setDuty(src, onDuty)
        local xPlayer = xPlayerOf(src)
        local job = xPlayer and xPlayer.job
        if not job then return false end
        -- Plain ESX has no duty flag; forks that expose job.onDuty accept a third setJob argument.
        if job.onDuty == nil or job.onDuty == onDuty then return true end
        return Core.safe(function() xPlayer.setJob(job.name, job.grade, onDuty) return true end) == true
    end

    function esx.jobs()
        local jobs = Core.safe(ESX.GetJobs)
        if type(jobs) == 'table' and next(jobs) then return jobs end

        jobs = {}
        for _, row in ipairs(Core.safe(MySQL.query.await, 'SELECT name, label FROM jobs') or {}) do
            jobs[row.name] = { label = row.label, grades = {} }
        end
        for _, row in ipairs(Core.safe(MySQL.query.await, 'SELECT job_name, grade, name, label, salary FROM job_grades') or {}) do
            local job = jobs[row.job_name]
            if job then
                job.grades[tonumber(row.grade) or 0] = { grade = row.grade, name = row.name, label = row.label, salary = row.salary }
            end
        end
        return jobs
    end

    function esx.sourceOf(identifier)
        local xPlayer = Core.safe(ESX.GetPlayerFromIdentifier, identifier)
        return xPlayer and xPlayer.source or nil
    end

    function esx.gender(src)
        local xPlayer = xPlayerOf(src)
        if not xPlayer then return nil end
        local value = Core.gender(Core.safe(xPlayer.get, 'sex') or (xPlayer.variables and xPlayer.variables.sex))
        if value then return value end
        local rows = Core.safe(MySQL.query.await, 'SELECT sex FROM users WHERE identifier = ?', { xPlayer.identifier })
        return rows and rows[1] and Core.gender(rows[1].sex) or nil
    end

    function esx.isAdminGroup(src, groups)
        return Core.inList(groups, esx.group(src))
    end

    function esx.money(src, account)
        local xPlayer = xPlayerOf(src)
        if not xPlayer then return 0 end
        local entry = Core.safe(xPlayer.getAccount, accountName(account))
        return entry and tonumber(entry.money) or 0
    end

    function esx.addMoney(src, amount, account, reason)
        local xPlayer = xPlayerOf(src)
        if not xPlayer then return false end
        return Core.safe(function() xPlayer.addAccountMoney(accountName(account), amount, reason) return true end) == true
    end

    function esx.removeMoney(src, amount, account, reason)
        local xPlayer = xPlayerOf(src)
        if not xPlayer or esx.money(src, account) < amount then return false end
        return Core.safe(function() xPlayer.removeAccountMoney(accountName(account), amount, reason) return true end) == true
    end

    function esx.hasLicense(src, license)
        if not Core.started('esx_license') then return false end
        local answer = promise.new()
        TriggerEvent('esx_license:checkLicense', src, license, function(has) answer:resolve(has == true) end)
        SetTimeout(5000, function() if answer.state == 0 then answer:resolve(false) end end)
        return Citizen.Await(answer)
    end

    function esx.items()
        local list = {}
        local source = ESX.Items or Core.safe(ESX.GetItems)
        if type(source) == 'table' and next(source) then
            for name, def in pairs(source) do list[name] = { label = def.label or name, weight = def.weight or 0 } end
            return list
        end
        for _, row in ipairs(Core.safe(MySQL.query.await, 'SELECT name, label, weight FROM items') or {}) do
            list[row.name] = { label = row.label or row.name, weight = tonumber(row.weight) or 0 }
        end
        return list
    end

    function esx.useable(name, handler)
        return Core.safe(function()
            ESX.RegisterUsableItem(name, function(src, _, data) handler(src, data) end)
            return true
        end) == true
    end

    -- Native ESX inventory (used when no dedicated inventory adapter exists).

    function esx.canCarry(src, name, count)
        local xPlayer = xPlayerOf(src)
        if not xPlayer then return false end
        if not xPlayer.canCarryItem then return true end
        return Core.safe(xPlayer.canCarryItem, name, count) ~= false
    end

    function esx.addItem(src, name, count, metadata)
        local xPlayer = xPlayerOf(src)
        if not xPlayer or not esx.canCarry(src, name, count) then return false end
        return Core.safe(function() xPlayer.addInventoryItem(name, count, metadata) return true end) == true
    end

    function esx.removeItem(src, name, count)
        local xPlayer = xPlayerOf(src)
        if not xPlayer or esx.itemCount(src, name) < count then return false end
        return Core.safe(function() xPlayer.removeInventoryItem(name, count) return true end) == true
    end

    function esx.itemCount(src, name)
        local xPlayer = xPlayerOf(src)
        local item = xPlayer and Core.safe(xPlayer.getInventoryItem, name)
        return item and tonumber(item.count) or 0
    end

    function esx.itemSlots(src, name)
        local count = esx.itemCount(src, name)
        if count <= 0 then return {} end
        return { { slot = nil, count = count, metadata = {} } }
    end

    function esx.inventory(src)
        local xPlayer = xPlayerOf(src)
        local list = {}
        for _, item in pairs(xPlayer and Core.safe(xPlayer.getInventory) or {}) do
            if type(item) == 'table' and item.name and (tonumber(item.count) or 0) > 0 then
                list[#list + 1] = { name = item.name, count = tonumber(item.count), metadata = item.metadata or {}, slot = item.slot }
            end
        end
        return list
    end

    return esx
end
