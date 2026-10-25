-- Society / business accounts (server).
-- Supported: Renewed-Banking, okokBanking, qb-banking, qb-management, esx_society (esx_addonaccount).

local BANKS = { 'Renewed-Banking', 'okokBanking', 'qb-banking', 'qb-management', 'esx_society' }
local ALIASES = {
    renewed = 'Renewed-Banking', ['renewed-banking'] = 'Renewed-Banking',
    okok = 'okokBanking', okokbanking = 'okokBanking',
    ['qb-banking'] = 'qb-banking', ['qb-management'] = 'qb-management',
    esx = 'esx_society', esx_society = 'esx_society',
}

local function bank()
    local name = Core.integration(ObsiConfig.Integrations.Banking, BANKS, ALIASES)
    if name == 'esx_society' and not Core.started('esx_addonaccount') then return 'none' end
    return name
end

-- Per bank: balance(account), create(account, balance), deposit(account, amount), withdraw(account, amount)
local drivers = {
    ['Renewed-Banking'] = {
        balance = function(account) return exports['Renewed-Banking']:getAccountMoney(account) end,
        create = function(account, balance) return exports['Renewed-Banking']:CreateJobAccount({ name = account, label = account }, balance) end,
        deposit = function(account, amount) return exports['Renewed-Banking']:addAccountMoney(account, amount) end,
        withdraw = function(account, amount) return exports['Renewed-Banking']:removeAccountMoney(account, amount) end,
    },
    ['qb-banking'] = {
        balance = function(account) return exports['qb-banking']:GetAccountBalance(account) end,
        create = function(account, balance) return exports['qb-banking']:CreateJobAccount(account, balance) end,
        deposit = function(account, amount) return exports['qb-banking']:AddMoney(account, amount, 'obsi-lib') end,
        withdraw = function(account, amount) return exports['qb-banking']:RemoveMoney(account, amount, 'obsi-lib') end,
    },
    ['qb-management'] = {
        balance = function(account) return exports['qb-management']:GetAccount(account) end,
        deposit = function(account, amount) return exports['qb-management']:AddMoney(account, amount) end,
        withdraw = function(account, amount) return exports['qb-management']:RemoveMoney(account, amount) end,
    },
    okokBanking = {
        balance = function(account) return exports.okokBanking:GetAccount(account) end,
        deposit = function(account, amount) return exports.okokBanking:AddMoney(account, amount) end,
        withdraw = function(account, amount) return exports.okokBanking:RemoveMoney(account, amount) end,
    },
}

local function esxShared(account)
    local result = promise.new()
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. account, function(shared) result:resolve(shared or false) end)
    SetTimeout(3000, function() if result.state == 0 then result:resolve(false) end end)
    return Citizen.Await(result)
end

local function toNumber(value)
    if type(value) == 'table' then value = value.balance or value.amount or value.money end
    return tonumber(value)
end

local society = {}

---Name of the banking resource in use ('none' when unsupported).
function society.provider()
    return bank()
end

---@return number|nil balance of a job / society account
function society.balance(account)
    if type(account) ~= 'string' or account == '' then return nil end
    local name = bank()
    if name == 'esx_society' then
        local shared = esxShared(account)
        return shared and tonumber(shared.money) or nil
    end
    local driver = drivers[name]
    return driver and toNumber(Core.safe(driver.balance, account)) or nil
end

---@return boolean
function society.deposit(account, amount)
    amount = tonumber(amount)
    if type(account) ~= 'string' or not amount or amount <= 0 then return false end
    local name = bank()
    if name == 'esx_society' then
        local shared = esxShared(account)
        return shared and Core.safe(function() shared.addMoney(amount) return true end) == true or false
    end
    local driver = drivers[name]
    return driver and Core.safe(driver.deposit, account, amount) ~= false or false
end

---@return boolean
function society.withdraw(account, amount)
    amount = tonumber(amount)
    if type(account) ~= 'string' or not amount or amount <= 0 then return false end
    local current = society.balance(account)
    if not current or current < amount then return false end
    local name = bank()
    if name == 'esx_society' then
        local shared = esxShared(account)
        return shared and Core.safe(function() shared.removeMoney(amount) return true end) == true or false
    end
    local driver = drivers[name]
    return driver and Core.safe(driver.withdraw, account, amount) ~= false or false
end

---Forces the balance of a society account (creates the account when the bank supports it).
---@return boolean handled by a banking resource
function society.sync(account, balance)
    if type(account) ~= 'string' or account == '' then return false end
    balance = math.max(0, math.floor(tonumber(balance) or 0))
    local name = bank()
    if name == 'none' then return false end

    if name == 'esx_society' then
        local shared = esxShared(account)
        return shared and Core.safe(function() shared.setMoney(balance) return true end) == true or false
    end

    local driver = drivers[name]
    if not driver then return false end

    local current = toNumber(Core.safe(driver.balance, account))
    if current == nil then
        if not driver.create then return false end
        Core.safe(driver.create, account, balance)
        current = toNumber(Core.safe(driver.balance, account))
        if current == nil then return false end
    end

    current = math.floor(current)
    if balance > current then
        Core.safe(driver.deposit, account, balance - current)
    elseif balance < current then
        Core.safe(driver.withdraw, account, current - balance)
    end
    return true
end

ObsiLib.society = society
