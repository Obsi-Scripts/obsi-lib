-- Keybinds (client): rebindable in GTA settings > Key Bindings > FiveM.
--   local bind = ObsiLib.keybind.add({
--       name = 'open_tablet', description = 'Open tablet', key = 'F5', mapper = 'keyboard',
--       onPress = function() end, onRelease = function() end,
--   })
--   bind.disable(true)  bind.isPressed()  bind.currentKey()

local binds = {}

local keybind = {}

function keybind.add(data)
    if type(data) ~= 'table' or not Core.text(data.name) then error('ObsiLib.keybind.add needs a name', 2) end
    if binds[data.name] then
        Core.warn('keybind "%s" already exists, returning the existing one', data.name)
        return binds[data.name]
    end

    local command = data.name
    local disabled, pressed = data.disabled == true, false
    local onPress, onRelease = data.onPress, data.onRelease
    local hash = joaat('+' .. command) | 0x80000000

    local bind = { name = command, description = data.description, defaultKey = data.key }

    function bind.disable(state)
        disabled = state ~= false
        if disabled then pressed = false end
    end

    function bind.isDisabled()
        return disabled
    end

    function bind.isPressed()
        return pressed
    end

    ---Key currently bound by the player (e.g. 'F5').
    function bind.currentKey()
        return (GetControlInstructionalButton(0, hash, true) or ''):sub(3)
    end

    RegisterCommand('+' .. command, function()
        if disabled or IsPauseMenuActive() then return end
        pressed = true
        if onPress then Core.safe(onPress, bind) end
    end, false)

    RegisterCommand('-' .. command, function()
        if not pressed then return end
        pressed = false
        if onRelease then Core.safe(onRelease, bind) end
    end, false)

    RegisterKeyMapping('+' .. command, data.description or command, data.mapper or 'keyboard', data.key or '')

    SetTimeout(500, function()
        TriggerEvent('chat:removeSuggestion', '/+' .. command)
        TriggerEvent('chat:removeSuggestion', '/-' .. command)
    end)

    binds[command] = bind
    -- Commands can not be unregistered; the bind goes quiet when its owner stops.
    Core.own(Core.caller(), function()
        disabled, onPress, onRelease = true, nil, nil
        binds[command] = nil
    end)
    return bind
end

function keybind.get(name)
    return binds[name]
end

ObsiLib.keybind = keybind
