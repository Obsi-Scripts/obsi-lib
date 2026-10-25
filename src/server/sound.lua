-- Sounds (server): relays to the built-in NUI player on clients.
--   ObsiLib.sound.play(target, file, opts)        target = player id or -1
--   ObsiLib.sound.playAt(coords, file, opts)      positional, every player in opts.range hears it with falloff
--   ObsiLib.sound.stop(target, id)
-- opts = { id?, volume?, loop?, range? }

local cfg = ObsiConfig.Sound
local lastBroadcast = {}
local ownedBroadcasts = {} -- [src] = { [id] = true }

local function clampVolume(volume)
    return math.max(0.0, math.min(1.0, tonumber(volume) or cfg.DefaultVolume))
end

---Short file names map to web/build/sounds/<name>.mp3; full urls are kept.
local function validFile(file, allowRemote)
    if type(file) ~= 'string' or file == '' or #file > 256 then return false end
    if file:find('://', 1, true) then
        if not allowRemote then return false end
        return file:match('^https?://') ~= nil or file:match('^nui://') ~= nil
    end
    return file:match('^[%w_%-/]+$') ~= nil and not file:find('..', 1, true)
end

local function validId(id)
    return id == nil or (type(id) == 'string' and id ~= '' and #id <= 64)
end

local sound = {}

---@return boolean
function sound.play(target, file, opts)
    target = tonumber(target)
    opts = type(opts) == 'table' and opts or {}
    if not target or not validFile(file, true) or not validId(opts.id) then return false end
    TriggerClientEvent('obsi-lib:sound:play', target, { file = file, id = opts.id, volume = clampVolume(opts.volume), loop = opts.loop == true })
    return true
end

---@return boolean
function sound.playAt(coords, file, opts)
    opts = type(opts) == 'table' and opts or {}
    coords = Core.vec3(coords)
    local range = tonumber(opts.range) or cfg.DefaultRange
    if not coords or not validFile(file, true) or not validId(opts.id) or range <= 0 then return false end
    TriggerClientEvent('obsi-lib:sound:playAt', -1, {
        coords = coords, range = range, file = file, id = opts.id, volume = clampVolume(opts.volume), loop = opts.loop == true,
    })
    return true
end

---@return boolean
function sound.stop(target, id)
    target = tonumber(target)
    if not target or not validId(id) or id == nil then return false end
    TriggerClientEvent('obsi-lib:sound:stop', target, id)
    return true
end

ObsiLib.sound = sound

-- A client asks to play a sound around itself. Range, rate and file are checked here; the sound is
-- anchored to the player's server side position, never to coords sent by the client.
RegisterNetEvent('obsi-lib:sound:broadcast', function(file, opts)
    local src = source
    opts = type(opts) == 'table' and opts or {}

    local now = GetGameTimer()
    if lastBroadcast[src] and now - lastBroadcast[src] < cfg.BroadcastCooldown then return end
    lastBroadcast[src] = now

    local range = tonumber(opts.range) or cfg.DefaultRange
    if range <= 0 or range > cfg.MaxBroadcastRange then return end
    if not validFile(file, cfg.AllowRemoteUrls) or not validId(opts.id) then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local id = opts.id and ('%d:%s'):format(src, opts.id) or nil
    if id then
        ownedBroadcasts[src] = ownedBroadcasts[src] or {}
        ownedBroadcasts[src][id] = true
    end

    TriggerClientEvent('obsi-lib:sound:playAt', -1, {
        coords = GetEntityCoords(ped), range = range, file = file, id = id,
        volume = clampVolume(opts.volume), loop = opts.loop == true,
    })
end)

-- A client stops a sound it broadcast earlier (only its own).
RegisterNetEvent('obsi-lib:sound:unbroadcast', function(id)
    local src = source
    if not validId(id) or id == nil then return end
    local full = ('%d:%s'):format(src, id)
    if not (ownedBroadcasts[src] and ownedBroadcasts[src][full]) then return end
    ownedBroadcasts[src][full] = nil
    TriggerClientEvent('obsi-lib:sound:stop', -1, full)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastBroadcast[src] = nil
    for id in pairs(ownedBroadcasts[src] or {}) do
        TriggerClientEvent('obsi-lib:sound:stop', -1, id)
    end
    ownedBroadcasts[src] = nil
end)

exports('playSound', sound.play)
exports('playSoundAt', sound.playAt)
exports('stopSound', sound.stop)
