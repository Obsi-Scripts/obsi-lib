-- Progress bar (client).
--   ObsiLib.ui.progress(data) -> boolean   blocking, true when finished, false when cancelled / refused
--   ObsiLib.ui.cancelProgress()
--   ObsiLib.ui.progressActive() -> boolean
--
-- data = {
--   label, description, duration (ms, default 5000), cancelable (bool),
--   anim = { dict, clip, flag = 49 } or { scenario = 'WORLD_HUMAN_...' },
--   prop = { model, bone = 60309, pos = vec3, rot = vec3 } or a list of those,
--   disable = { move, sprint, car, combat, mouse } (booleans), keys = { 'E', 'F', ... } extra keys to block,
--   allowDead (bool),
-- }

local active

local DISABLE_GROUPS = {
    move = { 30, 31, 36, 21, 22, 44 },
    sprint = { 21 },
    car = { 63, 64, 71, 72, 75 },
    combat = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264 },
    mouse = { 1, 2, 106 },
}

local KEY_CONTROLS = {
    E = 38, F = 23, G = 47, H = 74, K = 311, L = 182, M = 244, N = 249, Q = 44, R = 45, T = 245, U = 303, X = 73, Y = 246, Z = 20,
    B = 29, C = 26, V = 0, TAB = 37, SPACE = 22, ENTER = 18, BACKSPACE = 177, ESC = 322, LEFTSHIFT = 21, LEFTCTRL = 36, LEFTALT = 19,
    ['1'] = 157, ['2'] = 158, ['3'] = 160, ['4'] = 164, ['5'] = 165,
}

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not hash or not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(0)
    end
    return hash
end

local function loadDict(dict)
    if not dict or not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

local function attach(ped, def)
    local hash = loadModel(def.model)
    if not hash then return nil end
    local coords = GetEntityCoords(ped)
    local object = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    local pos, rot = Core.vec3(def.pos) or vector3(0.0, 0.0, 0.0), Core.vec3(def.rot) or vector3(0.0, 0.0, 0.0)
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, def.bone or 60309), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 0, true)
    SetModelAsNoLongerNeeded(hash)
    return object
end

local function blockedControls(data)
    local list = {}
    for group, enabled in pairs(type(data.disable) == 'table' and data.disable or {}) do
        if enabled and DISABLE_GROUPS[group] then
            for _, control in ipairs(DISABLE_GROUPS[group]) do list[#list + 1] = control end
        end
    end
    local keys = data.keys or (type(data.inputBlock) == 'table' and data.inputBlock.keys) or {}
    for _, key in ipairs(keys) do
        local control = type(key) == 'number' and key or KEY_CONTROLS[tostring(key):upper()]
        if control then list[#list + 1] = control end
    end
    return list
end

---@return boolean finished
function ObsiLib.ui.progress(data)
    data = type(data) == 'table' and data or {}
    if active then return false end

    local ped = PlayerPedId()
    if not data.allowDead and ObsiLib.player.isDead() then return false end

    local duration = math.max(100, math.floor(tonumber(data.duration or data.time) or 5000))
    local cancelable = data.cancelable == true or data.canCancel == true
    local cancelKey = ObsiConfig.UI.Progress.CancelKey or 73
    local blocked = blockedControls(data)

    active = { cancelled = false }

    -- Animation / scenario
    local anim = data.anim or data.animation
    local scenario = data.scenario or (type(anim) == 'table' and anim.scenario)
    local animDict, animClip
    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    elseif type(anim) == 'table' and anim.dict and loadDict(anim.dict) then
        animDict, animClip = anim.dict, anim.clip or anim.name or anim.anim
        TaskPlayAnim(ped, animDict, animClip, anim.blendIn or 3.0, anim.blendOut or 3.0, -1, anim.flag or 49, 0, false, false, false)
    end

    -- Props
    local props = {}
    if type(data.prop) == 'table' then
        local list = data.prop.model and { data.prop } or data.prop
        for _, def in ipairs(list) do
            local object = def.model and attach(ped, def)
            if object then props[#props + 1] = object end
        end
    end

    Core.nui('obsi-lib:progress', {
        op = 'start',
        label = data.label or data.title or '',
        description = data.description or data.text,
        duration = duration,
        cancelable = cancelable,
    })

    local finishAt = GetGameTimer() + duration
    local finished = false
    while true do
        if active.cancelled then break end
        if GetGameTimer() >= finishAt then
            finished = true
            break
        end
        for i = 1, #blocked do DisableControlAction(0, blocked[i], true) end
        if cancelable and IsControlJustPressed(0, cancelKey) then break end
        if not data.allowDead and ObsiLib.player.isDead() then break end
        if animDict and not IsEntityPlayingAnim(ped, animDict, animClip, 3) then
            TaskPlayAnim(ped, animDict, animClip, 3.0, 3.0, -1, (anim and anim.flag) or 49, 0, false, false, false)
        end
        Wait(0)
    end

    Core.nui('obsi-lib:progress', { op = 'stop', completed = finished })

    if scenario then
        ClearPedTasks(ped)
    elseif animDict then
        StopAnimTask(ped, animDict, animClip, 1.0)
        RemoveAnimDict(animDict)
    end
    for _, object in ipairs(props) do
        if DoesEntityExist(object) then
            DetachEntity(object, true, true)
            DeleteEntity(object)
        end
    end

    active = nil
    return finished
end

function ObsiLib.ui.cancelProgress()
    if active then active.cancelled = true end
end

---@return boolean
function ObsiLib.ui.progressActive()
    return active ~= nil
end

exports('progress', ObsiLib.ui.progress)
exports('cancelProgress', ObsiLib.ui.cancelProgress)
exports('progressActive', ObsiLib.ui.progressActive)
