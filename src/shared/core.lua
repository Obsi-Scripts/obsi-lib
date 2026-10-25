-- Core: creates the public `ObsiLib` table (what other resources receive) and the private `Core`
-- helpers that stay inside this resource. Nothing in the public table relies on metatables, because
-- tables passed through exports lose them.

local RESOURCE = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()

ObsiLib = {
    name = 'obsi-lib',
    version = GetResourceMetadata(RESOURCE, 'version', 0) or '0.0.0',
    side = IS_SERVER and 'server' or 'client',
}

Core = {
    resource = RESOURCE,
    isServer = IS_SERVER,
    locales = {},
}

if RESOURCE ~= 'obsi-lib' then
    print(('^1[obsi-lib] This resource must be named "obsi-lib" (currently "%s"). Other scripts look it up by that name.^0'):format(RESOURCE))
end

---------------------------------------------------------------------------------------------------
-- Protected calls
---------------------------------------------------------------------------------------------------

---Runs fn in pcall and returns its results, or nil when it errors (error is printed in debug mode).
function Core.safe(fn, ...)
    if type(fn) ~= 'function' and type(fn) ~= 'table' then return nil end
    local packed = table.pack(pcall(fn, ...))
    if not packed[1] then
        Core.trace('protected call failed: %s', tostring(packed[2]))
        return nil
    end
    return table.unpack(packed, 2, packed.n)
end

---------------------------------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------------------------------

local LEVELS = {
    error = '^1ERROR^7',
    warn = '^3WARN ^7',
    info = '^5INFO ^7',
    success = '^2 OK  ^7',
    debug = '^6DEBUG^7',
}

local function stringify(value)
    if type(value) == 'table' then
        local ok, encoded = pcall(json.encode, value, { indent = true, sort_keys = true })
        return ok and encoded or tostring(value)
    end
    return tostring(value)
end

local function emit(level, ...)
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = stringify(select(i, ...)) end
    print(('[obsi-lib] %s %s'):format(LEVELS[level] or LEVELS.info, table.concat(parts, ' ')))
end

---Debug-only formatted line.
function Core.trace(fmt, ...)
    if not ObsiConfig.Debug then return end
    local ok, line = pcall(string.format, fmt, ...)
    emit('debug', ok and line or fmt)
end

function Core.warn(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    emit('warn', ok and line or fmt)
end

ObsiLib.debug = {
    ---Prints values with a level tag ('error' | 'warn' | 'info' | 'success' | 'debug').
    print = function(level, ...)
        if not LEVELS[level] then return emit('info', level, ...) end
        emit(level, ...)
    end,

    ---Prints only when ObsiConfig.Debug is on.
    log = function(...)
        if ObsiConfig.Debug then emit('debug', ...) end
    end,

    ---@return boolean
    enabled = function()
        return ObsiConfig.Debug == true
    end,

    ---Pretty JSON string of any value.
    dump = function(value)
        return stringify(value)
    end,
}

---------------------------------------------------------------------------------------------------
-- Locales
---------------------------------------------------------------------------------------------------

---Translated text for key, formatted with the extra arguments. Falls back to English, then to the key.
function Core.t(key, ...)
    local lang = Core.locales[ObsiConfig.Locale] or Core.locales.en or {}
    local text = lang[key] or (Core.locales.en or {})[key] or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

ObsiLib.locale = Core.t

---------------------------------------------------------------------------------------------------
-- Ownership: things other resources register through ObsiLib are cleaned up when they stop
---------------------------------------------------------------------------------------------------

local owned = {}

---Resource that called into obsi-lib (or obsi-lib itself).
function Core.caller()
    local invoking = GetInvokingResource()
    if not invoking or invoking == '' then return RESOURCE end
    return invoking
end

---Registers a cleanup function that runs when `resource` stops.
function Core.own(resource, cleanup)
    if not resource or resource == RESOURCE then return end
    local list = owned[resource]
    if not list then
        list = {}
        owned[resource] = list
    end
    list[#list + 1] = cleanup
end

AddEventHandler('onResourceStop', function(resource)
    local list = owned[resource]
    if not list then return end
    owned[resource] = nil
    for i = 1, #list do
        Core.safe(list[i])
    end
end)

---------------------------------------------------------------------------------------------------
-- Small shared helpers
---------------------------------------------------------------------------------------------------

---Positive integer or nil.
function Core.amount(value)
    local number = math.floor(tonumber(value) or 0)
    if number <= 0 then return nil end
    return number
end

---Non empty string or nil.
function Core.text(value, maxLength)
    if type(value) ~= 'string' or value == '' then return nil end
    if maxLength and #value > maxLength then return nil end
    return value
end

---'male' / 'female' from the many ways frameworks store it.
function Core.gender(value)
    if value == nil then return nil end
    local text = tostring(value):lower()
    if text == '1' or text == 'f' or text == 'female' or text == 'woman' then return 'female' end
    if text == '0' or text == 'm' or text == 'male' or text == 'man' then return 'male' end
    return nil
end

---Vector3 from vector3/vector4/table input.
function Core.vec3(value)
    local kind = type(value)
    if kind == 'vector3' then return value end
    if kind == 'vector4' or kind == 'table' then
        return vector3(
            tonumber(value.x or value[1]) or 0.0,
            tonumber(value.y or value[2]) or 0.0,
            tonumber(value.z or value[3]) or 0.0
        )
    end
    return nil
end
