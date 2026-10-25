-- Notifications (server).
-- ObsiLib.notify(src, { title, description, type, duration, tag, position })
-- `src` may be -1 for everybody. Aliases accepted: desc / message / text, label, time.

local QB_TYPES = { success = 'success', error = 'error', warning = 'primary', info = 'primary' }

function ObsiLib.notify(src, data)
    src = tonumber(src)
    if not src then return end
    data = Core.notifyData(data)
    local backend = ObsiConfig.Notify

    if backend == 'esx' then
        TriggerClientEvent('esx:showNotification', src, data.description or data.title, data.type, data.duration, data.title)
    elseif backend == 'qb' then
        TriggerClientEvent('QBCore:Notify', src, data.description or data.title, QB_TYPES[data.type], data.duration)
    elseif backend == 'ox' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = data.title, description = data.description, duration = data.duration,
            type = data.type == 'info' and 'inform' or data.type,
        })
    elseif backend == 'custom' and type(ObsiEditable and ObsiEditable.notify) == 'function' then
        Core.safe(ObsiEditable.notify, src, data)
    else
        TriggerClientEvent('obsi-lib:notify', src, data)
    end
end

exports('notify', ObsiLib.notify)
