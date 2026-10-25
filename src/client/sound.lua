-- Sounds (client). The built-in NUI player handles everything; positional sounds keep their volume
-- updated from the distance to the listener (linear falloff to 0 at `range`).
--
--   ObsiLib.sound.play(file, opts) -> id                 only for you
--   ObsiLib.sound.playAt(coords, file, opts) -> id       only for you, positional
--   ObsiLib.sound.broadcast(file, opts)                  everybody around you (server checked)
--   ObsiLib.sound.unbroadcast(id)
--   ObsiLib.sound.stop(id) / stopAll()
--   ObsiLib.sound.setVolume(id, volume) / setPosition(id, coords) / setRange(id, range)
--   ObsiLib.sound.url(id, url, opts)                     xsound when running, NUI player otherwise
--   ObsiLib.sound.seek(id, seconds) / exists(id) / provider()
-- opts = { id?, volume?, loop?, range?, coords? }
-- file = short name (web/build/sounds/<name>.mp3), 'nui://resource/path.ogg' or an https url.

local cfg = ObsiConfig.Sound
local tracked = {} -- positional NUI sounds: [id] = { coords, range, base, last }
local active = {}  -- every NUI sound id we started
local xsoundIds = {}
local counter = 0

local function nextId()
    counter = counter + 1
    return ('obsi:%d'):format(counter)
end

local function clamp(volume)
    return math.max(0.0, math.min(1.0, tonumber(volume) or cfg.DefaultVolume))
end

local function falloff(entry)
    local distance = #(GetEntityCoords(PlayerPedId()) - entry.coords)
    return entry.base * math.max(0.0, 1.0 - distance / entry.range)
end

local sound = {}

---'xsound' | 'nui' | 'none'
function sound.provider()
    local setting = tostring(ObsiConfig.Integrations.Sound or 'auto'):lower()
    if setting == 'none' then return 'none' end
    if setting ~= 'nui' and Core.started('xsound') then return 'xsound' end
    return 'nui'
end

local function nuiPlay(id, file, volume, loop)
    active[id] = true
    Core.nui('obsi-lib:sound', { op = 'play', id = id, file = file, volume = volume, loop = loop == true })
end

---@return string|nil id
function sound.play(file, opts)
    if type(file) ~= 'string' or file == '' or sound.provider() == 'none' then return nil end
    opts = type(opts) == 'table' and opts or {}
    local id = opts.id or nextId()
    tracked[id] = nil
    nuiPlay(id, file, clamp(opts.volume), opts.loop)
    return id
end

---@return string|nil id
function sound.playAt(coords, file, opts)
    coords = Core.vec3(coords)
    if not coords or type(file) ~= 'string' or file == '' or sound.provider() == 'none' then return nil end
    opts = type(opts) == 'table' and opts or {}
    local id = opts.id or nextId()
    local entry = { coords = coords, range = math.max(0.5, tonumber(opts.range) or cfg.DefaultRange), base = clamp(opts.volume) }
    entry.last = falloff(entry)
    tracked[id] = entry
    nuiPlay(id, file, entry.last, opts.loop)
    return id
end

---Plays a sound around you for every player in range (server validates range, rate and file).
function sound.broadcast(file, opts)
    opts = type(opts) == 'table' and opts or {}
    TriggerServerEvent('obsi-lib:sound:broadcast', file, {
        id = opts.id, volume = opts.volume, loop = opts.loop == true, range = opts.range,
    })
end

---Stops a sound you broadcast with an id.
function sound.unbroadcast(id)
    if type(id) == 'string' then TriggerServerEvent('obsi-lib:sound:unbroadcast', id) end
end

function sound.stop(id)
    if id == nil then return end
    if xsoundIds[id] then
        xsoundIds[id] = nil
        Core.safe(function() exports.xsound:Destroy(id) end)
        return
    end
    tracked[id] = nil
    if active[id] then
        active[id] = nil
        Core.nui('obsi-lib:sound', { op = 'stop', id = id })
    end
end

function sound.stopAll()
    for id in pairs(xsoundIds) do sound.stop(id) end
    tracked, active = {}, {}
    Core.nui('obsi-lib:sound', { op = 'stopAll' })
end

function sound.setVolume(id, volume)
    volume = clamp(volume)
    if xsoundIds[id] then
        return Core.safe(function() exports.xsound:setVolume(id, volume) end)
    end
    local entry = tracked[id]
    if entry then
        entry.base = volume
        return
    end
    if active[id] then Core.nui('obsi-lib:sound', { op = 'volume', id = id, volume = volume }) end
end

function sound.setPosition(id, coords)
    coords = Core.vec3(coords)
    if not coords then return end
    if xsoundIds[id] then
        return Core.safe(function() exports.xsound:Position(id, coords) end)
    end
    if tracked[id] then tracked[id].coords = coords end
end

function sound.setRange(id, range)
    range = math.max(0.5, tonumber(range) or cfg.DefaultRange)
    if xsoundIds[id] then
        return Core.safe(function() exports.xsound:Distance(id, range) end)
    end
    if tracked[id] then tracked[id].range = range end
end

---Seeks an xsound sound to `seconds`.
function sound.seek(id, seconds)
    if xsoundIds[id] then Core.safe(function() exports.xsound:setTimeStamp(id, tonumber(seconds) or 0) end) end
end

---@return boolean
function sound.exists(id)
    if xsoundIds[id] then
        return Core.safe(function() return exports.xsound:soundExists(id) end) == true
    end
    return active[id] == true
end

---Url sound; positional when opts.coords is given. Uses xsound when it runs, the NUI player otherwise.
---@return string|nil id
function sound.url(id, url, opts)
    if type(id) ~= 'string' or type(url) ~= 'string' then return nil end
    opts = type(opts) == 'table' and opts or {}
    local provider = sound.provider()
    if provider == 'none' then return nil end

    if provider == 'xsound' then
        local volume, loop = clamp(opts.volume), opts.loop == true
        local coords = Core.vec3(opts.coords)
        local ok = Core.safe(function()
            if coords then
                exports.xsound:PlayUrlPos(id, url, volume, coords, loop)
                if opts.range then exports.xsound:Distance(id, tonumber(opts.range)) end
            else
                exports.xsound:PlayUrl(id, url, volume, loop)
            end
            return true
        end)
        if ok then
            xsoundIds[id] = true
            return id
        end
    end

    opts.id = id
    if opts.coords then return sound.playAt(opts.coords, url, opts) end
    return sound.play(url, opts)
end

ObsiLib.sound = sound

-- Live distance falloff for positional NUI sounds.
CreateThread(function()
    while true do
        if next(tracked) then
            for id, entry in pairs(tracked) do
                local volume = falloff(entry)
                if math.abs(volume - (entry.last or -1)) > 0.01 then
                    entry.last = volume
                    Core.nui('obsi-lib:sound', { op = 'volume', id = id, volume = volume })
                end
            end
            Wait(100)
        else
            Wait(500)
        end
    end
end)

RegisterNUICallback('sound:ended', function(data, cb)
    cb(true)
    local id = type(data) == 'table' and data.id
    if id then
        tracked[id] = nil
        active[id] = nil
    end
end)

-- Server relays
RegisterNetEvent('obsi-lib:sound:play', function(data)
    if type(data) ~= 'table' then return end
    sound.play(data.file, data)
end)

RegisterNetEvent('obsi-lib:sound:playAt', function(data)
    if type(data) ~= 'table' then return end
    local coords = Core.vec3(data.coords)
    local range = tonumber(data.range) or cfg.DefaultRange
    if not coords then return end
    -- One-shots out of earshot are skipped; loops are kept so walking closer makes them audible.
    if not data.loop and #(GetEntityCoords(PlayerPedId()) - coords) > range then return end
    sound.playAt(coords, data.file, data)
end)

RegisterNetEvent('obsi-lib:sound:stop', function(id)
    sound.stop(id)
end)

exports('playSound', sound.play)
exports('playSoundAt', sound.playAt)
exports('stopSound', sound.stop)
