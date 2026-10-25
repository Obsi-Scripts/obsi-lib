-- Client core: framework objects and the NUI bridge.

local frameworkObject

---ESX shared object / QBCore core object (nil for custom frameworks).
function Core.frameworkObject()
    if frameworkObject ~= nil then return frameworkObject or nil end
    local id = ObsiLib.framework
    if id == 'esx' then
        frameworkObject = Core.safe(function() return exports.es_extended:getSharedObject() end)
    elseif id == 'qb' or id == 'qbx' then
        frameworkObject = Core.safe(function() return exports['qb-core']:GetCoreObject() end)
            or Core.safe(function() return exports.qbx_core:GetCoreObject() end)
    end
    frameworkObject = frameworkObject or false
    return frameworkObject or nil
end

---------------------------------------------------------------------------------------------------
-- NUI bridge. Messages sent before the page reports ready are queued.
---------------------------------------------------------------------------------------------------

local nuiReady = false
local pending = {}

function Core.nui(action, data)
    if not nuiReady then
        pending[#pending + 1] = { action = action, data = data }
        return
    end
    SendNUIMessage({ action = action, data = data })
end

local function uiConfig()
    local ui = ObsiConfig.UI
    return {
        accent = ui.Accent,
        notify = { position = ui.Notify.Position, max = ui.Notify.MaxVisible, duration = ui.Notify.Duration },
        progress = { offset = ui.Progress.Offset, cancelLabel = ui.Progress.CancelLabel },
        textui = { position = ui.TextUI.Position },
        strings = {
            cancel = Core.t('progress_cancel'),
            press = Core.t('textui_press'),
            notice = Core.t('notify_title'),
        },
    }
end

local function markReady()
    if nuiReady then return end
    nuiReady = true
    SendNUIMessage({ action = 'obsi-lib:config', data = uiConfig() })
    for i = 1, #pending do
        SendNUIMessage(pending[i])
    end
    pending = {}
end

RegisterNUICallback('ready', function(_, cb)
    cb(true)
    nuiReady = false
    markReady()
end)

-- Fallback when the page loaded before this script registered the callback.
SetTimeout(4000, markReady)

---Changes the UI accent colour at runtime (hex string).
function Core.setAccent(hex)
    if type(hex) ~= 'string' or not hex:match('^#%x%x%x%x%x%x$') then return false end
    ObsiConfig.UI.Accent = hex
    Core.nui('obsi-lib:config', uiConfig())
    return true
end

ObsiLib.ui = ObsiLib.ui or {}
ObsiLib.ui.setAccent = Core.setAccent
