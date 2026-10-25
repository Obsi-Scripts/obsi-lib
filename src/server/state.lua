-- Client state push (server): writes a key into a player's reactive client state.
--   ObsiLib.state.push(target, key, value)    target = player id or -1

local RESERVED = { ped = true, vehicle = true, seat = true, weapon = true, playerId = true, serverId = true }

local state = {}

---@return boolean
function state.push(target, key, value)
    target = tonumber(target)
    if not target or type(key) ~= 'string' or key == '' or #key > 64 then return false end
    if RESERVED[key] then
        Core.warn('state key "%s" is maintained by the client and can not be pushed', key)
        return false
    end
    TriggerClientEvent('obsi-lib:state:push', target, key, value)
    return true
end

ObsiLib.state = state
