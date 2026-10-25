-- Generic helpers exposed as ObsiLib.util.

local util = {}

---Clamped percentage of value / max (0 - 100).
function util.percent(value, max)
    value, max = tonumber(value) or 0, tonumber(max) or 0
    if max == 0 then return 0 end
    return math.max(0, math.min(100, value * 100 / max))
end

---Rounds to `decimals` places (default 0).
function util.round(value, decimals)
    local factor = 10 ^ (tonumber(decimals) or 0)
    return math.floor((tonumber(value) or 0) * factor + 0.5) / factor
end

---Clamps value into [min, max].
function util.clamp(value, min, max)
    return math.max(min, math.min(max, tonumber(value) or min))
end

---Trims whitespace.
function util.trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

---Splits a string by a single character separator.
function util.split(value, separator)
    local parts = {}
    for part in tostring(value or ''):gmatch(('[^%s]+'):format(separator or ',')) do
        parts[#parts + 1] = part
    end
    return parts
end

---Random string of `length` characters taken from `charset`.
function util.randomString(length, charset)
    charset = charset or 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local out = {}
    for i = 1, math.max(0, math.floor(tonumber(length) or 0)) do
        local index = math.random(1, #charset)
        out[i] = charset:sub(index, index)
    end
    return table.concat(out)
end

---'discord:123' -> '123'
function util.identifierValue(identifier)
    return tostring(identifier or ''):match('[^:]+$')
end

---Thousands separated number, e.g. 12500 -> '12 500'.
function util.formatNumber(value, separator)
    separator = separator or ' '
    local number = math.floor(tonumber(value) or 0)
    local digits = tostring(math.abs(number))
    local out = digits:reverse():gsub('(%d%d%d)', '%1' .. separator:gsub('%%', '%%%%')):reverse()
    if out:sub(1, #separator) == separator then out = out:sub(#separator + 1) end
    return (number < 0 and '-' or '') .. out
end

if Core.isServer then
    ---Discord id of a player (server only).
    function util.discordId(src)
        for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
            if identifier:sub(1, 8) == 'discord:' then return identifier:sub(9) end
        end
        return nil
    end

    ---All identifiers of a player keyed by type (server only), e.g. { license = 'license:..', discord = 'discord:..' }.
    function util.identifiers(src)
        local result = {}
        for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
            local kind = identifier:match('^([^:]+):')
            if kind then result[kind] = identifier end
        end
        return result
    end
end

ObsiLib.util = util

-- Notification payload shared by the client and server notify functions.
local TYPES = { success = true, error = true, warning = true, info = true }

---Normalises a notification table (shared field names for every backend).
function Core.notifyData(data)
    if type(data) == 'string' then data = { description = data } end
    data = type(data) == 'table' and data or {}
    local kind = data.type == 'inform' and 'info' or data.type
    local duration = tonumber(data.duration or data.time) or ObsiConfig.UI.Notify.Duration
    if duration < 100 then duration = duration * 1000 end -- seconds were passed

    return {
        title = data.title or data.label,
        description = data.description or data.desc or data.message or data.text,
        type = TYPES[kind] and kind or 'info',
        duration = duration,
        tag = data.tag,
        position = data.position,
        icon = data.icon,
    }
end

