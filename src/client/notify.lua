-- Notifications (client).
--   ObsiLib.notify({ title, description, type = 'success'|'error'|'warning'|'info', duration (ms), tag, position })
--   ObsiLib.ui.banner({ title, description, duration (ms) })   big centred "shard" message

local QB_TYPES = { success = 'success', error = 'error', warning = 'primary', info = 'primary' }

function ObsiLib.notify(data)
    data = Core.notifyData(data)
    local backend = ObsiConfig.Notify

    if backend == 'esx' then
        local ESX = Core.frameworkObject()
        if ESX then return ESX.ShowNotification(data.description or data.title, data.type, data.duration, data.title) end
    elseif backend == 'qb' then
        local QBCore = Core.frameworkObject()
        if QBCore then return QBCore.Functions.Notify(data.description or data.title, QB_TYPES[data.type], data.duration) end
    elseif backend == 'ox' and Core.started('ox_lib') then
        return TriggerEvent('ox_lib:notify', {
            title = data.title, description = data.description, duration = data.duration,
            type = data.type == 'info' and 'inform' or data.type, position = data.position,
        })
    elseif backend == 'custom' and type(ObsiEditable and ObsiEditable.notify) == 'function' then
        return Core.safe(ObsiEditable.notify, data)
    end

    Core.nui('obsi-lib:notify', data)
end

RegisterNetEvent('obsi-lib:notify', function(data)
    -- Server pushed: always rendered by the built-in UI or the configured backend.
    ObsiLib.notify(data)
end)

exports('notify', ObsiLib.notify)

---Big centred message (GTA "shard").
function ObsiLib.ui.banner(data)
    data = type(data) == 'table' and data or { title = tostring(data) }
    local duration = tonumber(data.duration or data.time) or 4000
    if duration < 100 then duration = duration * 1000 end

    CreateThread(function()
        local scaleform = RequestScaleformMovie('mp_big_message_freemode')
        local timeout = GetGameTimer() + 3000
        while not HasScaleformMovieLoaded(scaleform) do
            if GetGameTimer() > timeout then return end
            Wait(0)
        end

        BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE')
        PushScaleformMovieMethodParameterString(data.title or '')
        PushScaleformMovieMethodParameterString(data.description or data.desc or '')
        EndScaleformMovieMethod()

        local stop = GetGameTimer() + duration
        while GetGameTimer() < stop do
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end
        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end)
end
