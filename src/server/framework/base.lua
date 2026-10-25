-- Framework adapter registry (server).
-- Each adapter file registers a factory in Core.frameworks[id]. The active adapter is built lazily on
-- first use, so the order in which obsi-lib and the framework start does not matter as long as the
-- framework is running before the first call.
--
-- Adapter interface (every function optional, missing ones return nil):
--   players() player(src) identifier(src) name(src) group(src)
--   job(src) setJob(src, job, grade) setOfflineJob(identifier, job, grade) setDuty(src, state) jobs()
--   sourceOf(identifier) gender(src) isAdminGroup(src, groups)
--   money(src, account) addMoney(src, amount, account, reason) removeMoney(src, amount, account, reason)
--   hasLicense(src, license) items() useable(name, handler)
--   native inventory: addItem(src, name, count, metadata, slot) removeItem(src, name, count, metadata, slot)
--                     itemCount(src, name) canCarry(src, name, count) itemSlots(src, name) inventory(src)

Core.frameworks = {}

local active

local function noop() return nil end

local function build()
    local id = Core.detectFramework()
    local factory = Core.frameworks[id] or Core.frameworks.custom
    local ok, adapter = pcall(factory, id)

    if not ok or type(adapter) ~= 'table' then
        Core.warn('framework adapter "%s" failed to load (%s), using the custom hooks', id, tostring(adapter))
        adapter = Core.frameworks.custom('custom')
        id = 'custom'
    end

    -- Server owner patches from editable/server/framework.lua win over any adapter.
    for key, fn in pairs(ObsiEditable and ObsiEditable.frameworkPatch or {}) do
        if type(fn) == 'function' then adapter[key] = fn end
    end

    ObsiLib.framework = id
    Core.trace('framework adapter: %s', id)
    return adapter
end

---Proxy to the active adapter: Core.fw.money(src, 'cash') etc. Unknown functions are no-ops.
Core.fw = setmetatable({}, {
    __index = function(_, key)
        if not active then active = build() end
        local value = active[key]
        if value == nil then return noop end
        return value
    end,
})

---Rebuilds the adapter (used by ObsiLib.detect()).
function Core.resetFramework()
    active = nil
end

-- Money account aliases shared by the adapters.
Core.ACCOUNT_ALIASES = {
    cash = 'cash', money = 'cash',
    bank = 'bank',
    black = 'black', black_money = 'black', dirty = 'black',
}

---Normalises an account name to 'cash' | 'bank' | 'black' | the given custom name.
function Core.account(name)
    local text = tostring(name or 'cash')
    return Core.ACCOUNT_ALIASES[text:lower()] or text
end

---@return boolean
function Core.inList(list, value)
    if value == nil then return false end
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

---Builds a normalised grade table from any framework's job definition.
function Core.normaliseGrades(grades)
    local result = {}
    for key, grade in pairs(grades or {}) do
        if type(grade) == 'table' then
            local level = tonumber(grade.grade) or tonumber(key)
            if level then
                result[level] = {
                    label = grade.label or grade.name or tostring(level),
                    payment = grade.payment or grade.salary or 0,
                    isboss = grade.isboss == true or grade.isBoss == true or grade.name == 'boss',
                }
            end
        end
    end
    return result
end

local wrappedDetect = ObsiLib.detect
function ObsiLib.detect()
    Core.resetFramework()
    if Core.resetInventory then Core.resetInventory() end
    return wrappedDetect()
end
