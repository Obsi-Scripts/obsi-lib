-- Developer tools (client): a camera pointer that prints the coordinates it hits.
-- Toggle with /<ObsiConfig.DevTools.CoordsCommand>, left click copies the line to the console, ESC / X closes.

local command = ObsiConfig.DevTools and ObsiConfig.DevTools.CoordsCommand
if not command or command == '' then return end

local running = false

RegisterCommand(command, function()
    running = not running
    if not running then return end

    CreateThread(function()
        local hex = ObsiConfig.UI.Accent or '#e5122e'
        local r, g, b = hex:match('#(%x%x)(%x%x)(%x%x)')
        r, g, b = tonumber(r or 'f2', 16), tonumber(g or 'a5', 16), tonumber(b or '41', 16)

        while running do
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 73, true)

            local hit, coords = ObsiLib.game.raycast(1000.0)
            if hit then
                local origin = GetEntityCoords(PlayerPedId())
                DrawLine(origin.x, origin.y, origin.z, coords.x, coords.y, coords.z, r, g, b, 220)
                DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.08, 0.08, 0.08, r, g, b, 220, false, false, 2, false, nil, nil, false)
                if IsDisabledControlJustPressed(0, 24) then
                    print(Core.t('devtools_coords', coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId())))
                end
            end

            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 73) then running = false end
            Wait(0)
        end
    end)
end, false)
