--[[
    NOTIFY HOOK - SERVER
    Used when ObsiConfig.Notify = 'custom'.

    data = { title, description, type = 'success'|'error'|'warning'|'info', duration (ms), tag, position }
]]

ObsiEditable = ObsiEditable or {}

ObsiEditable.notify = function(src, data)
    -- Example: TriggerClientEvent('my_notify:show', src, data.title, data.description, data.type)
    TriggerClientEvent('obsi-lib:notify', src, data)
end
