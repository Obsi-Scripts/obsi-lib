-- Callbacks (client side).
--   ObsiLib.callback.await(name, payload, timeoutMs) -> values returned by the server handler (blocking)
--   ObsiLib.callback.trigger(name, payload, cb)      -> non-blocking, cb(...) receives the values
--   ObsiLib.callback.register(name, fn)              -> client handler answered to ObsiLib.callback.awaitClient

local waiting = {}
local nextRequest = 0
local handlers = {}

local callback = {}

---Blocking server callback. Call it from a thread (event handler / CreateThread).
---@return ... handler results, nothing on timeout or error
function callback.await(name, payload, timeoutMs)
    if type(name) ~= 'string' then error('ObsiLib.callback.await expects a callback name', 2) end

    nextRequest = nextRequest + 1
    local requestId = nextRequest
    local answer = promise.new()
    waiting[requestId] = answer

    SetTimeout(tonumber(timeoutMs) or 15000, function()
        if waiting[requestId] then
            waiting[requestId] = nil
            answer:resolve(false)
            Core.trace('callback "%s" timed out', name)
        end
    end)

    TriggerServerEvent('obsi-lib:cb:req', name, requestId, payload)

    local packed = Citizen.Await(answer)
    if type(packed) ~= 'table' then return nil end
    return table.unpack(packed, 1, packed.n or #packed)
end

---Non-blocking server callback.
function callback.trigger(name, payload, cb, timeoutMs)
    CreateThread(function()
        local packed = table.pack(callback.await(name, payload, timeoutMs))
        if cb then cb(table.unpack(packed, 1, packed.n)) end
    end)
end

RegisterNetEvent('obsi-lib:cb:res', function(requestId, ok, packed)
    local answer = waiting[requestId]
    if not answer then return end
    waiting[requestId] = nil
    answer:resolve(ok == true and type(packed) == 'table' and packed or false)
end)

---Registers a client handler the server can ask with ObsiLib.callback.awaitClient(src, name, payload).
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

function callback.unregister(name)
    handlers[name] = nil
end

RegisterNetEvent('obsi-lib:cb:ask', function(name, requestId, payload)
    local fn = handlers[name]
    if not fn then
        TriggerServerEvent('obsi-lib:cb:answer', requestId, false)
        return
    end
    local result = table.pack(pcall(fn, payload))
    if not result[1] then
        Core.warn('client callback "%s" failed: %s', name, tostring(result[2]))
        TriggerServerEvent('obsi-lib:cb:answer', requestId, false)
        return
    end
    TriggerServerEvent('obsi-lib:cb:answer', requestId, true, { n = result.n - 1, table.unpack(result, 2, result.n) })
end)

ObsiLib.callback = callback
