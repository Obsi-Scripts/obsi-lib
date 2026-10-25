-- Callbacks (server side).
--   ObsiLib.callback.register(name, fn)          fn(src, payload) -> any values (may yield)
--   ObsiLib.callback.call(name, src, payload)    run a registered handler locally
--   ObsiLib.callback.awaitClient(src, name, payload, timeoutMs) -> values returned by the client handler
--
-- Wire format: 'obsi-lib:cb:req' (name, requestId, payload) -> 'obsi-lib:cb:res' (requestId, ok, packed)

local handlers = {}
local inFlight = {}     -- [src] = number of client requests being handled
local MAX_IN_FLIGHT = 32
local waiting = {}      -- [requestId] = { src, promise }
local nextRequest = 0

local callback = {}

---@param name string
---@param fn fun(src: number, payload: any): ...
function callback.register(name, fn)
    if type(name) ~= 'string' or type(fn) ~= 'function' and type(fn) ~= 'table' then
        error('ObsiLib.callback.register expects (name: string, fn: function)', 2)
    end
    handlers[name] = fn
    local owner = Core.caller()
    Core.own(owner, function()
        if handlers[name] == fn then handlers[name] = nil end
    end)
end

---@param name string
function callback.unregister(name)
    handlers[name] = nil
end

---Runs a registered handler directly (no network).
function callback.call(name, src, payload)
    local fn = handlers[name]
    if not fn then return nil end
    return fn(src, payload)
end

RegisterNetEvent('obsi-lib:cb:req', function(name, requestId, payload)
    local src = source
    if type(name) ~= 'string' or #name > 128 then return end
    if type(requestId) ~= 'number' then return end

    local fn = handlers[name]
    if not fn then
        TriggerClientEvent('obsi-lib:cb:res', src, requestId, false)
        return
    end

    local busy = inFlight[src] or 0
    if busy >= MAX_IN_FLIGHT then
        Core.trace('player %s exceeded %d pending callbacks (%s)', src, MAX_IN_FLIGHT, name)
        TriggerClientEvent('obsi-lib:cb:res', src, requestId, false)
        return
    end
    inFlight[src] = busy + 1

    local result = table.pack(pcall(fn, src, payload))
    inFlight[src] = math.max(0, (inFlight[src] or 1) - 1)

    if not result[1] then
        Core.warn('callback "%s" failed for player %s: %s', name, src, tostring(result[2]))
        TriggerClientEvent('obsi-lib:cb:res', src, requestId, false)
        return
    end

    TriggerClientEvent('obsi-lib:cb:res', src, requestId, true, { n = result.n - 1, table.unpack(result, 2, result.n) })
end)

---Asks a client handler (registered with ObsiLib.callback.register on the client) for an answer.
---@return ... values returned by the client, nothing on timeout / error
function callback.awaitClient(src, name, payload, timeoutMs)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return nil end

    nextRequest = nextRequest + 1
    local requestId = nextRequest
    local answer = promise.new()
    waiting[requestId] = { src = src, promise = answer }

    SetTimeout(tonumber(timeoutMs) or 10000, function()
        local entry = waiting[requestId]
        if entry then
            waiting[requestId] = nil
            entry.promise:resolve(false)
        end
    end)

    TriggerClientEvent('obsi-lib:cb:ask', src, name, requestId, payload)

    local packed = Citizen.Await(answer)
    if type(packed) ~= 'table' then return nil end
    return table.unpack(packed, 1, packed.n or #packed)
end

RegisterNetEvent('obsi-lib:cb:answer', function(requestId, ok, packed)
    local src = source
    local entry = waiting[requestId]
    -- Only the player that was asked may answer.
    if not entry or entry.src ~= src then return end
    waiting[requestId] = nil
    entry.promise:resolve(ok == true and type(packed) == 'table' and packed or false)
end)

AddEventHandler('playerDropped', function()
    local src = source
    inFlight[src] = nil
    for requestId, entry in pairs(waiting) do
        if entry.src == src then
            waiting[requestId] = nil
            entry.promise:resolve(false)
        end
    end
end)

ObsiLib.callback = callback
