-- Stashes (client). The server opens every stash; a client may only ask for stashes registered with
-- clientOpen = true. Without a stash capable inventory a small native menu is drawn here.

ObsiLib.stash = {
    ---Asks the server to open a stash registered with clientOpen = true.
    open = function(id)
        if id == nil then return false end
        TriggerServerEvent('obsi-lib:stash:open', tostring(id))
        return true
    end,
}

-- qb-inventory v1 / ps-inventory / lj-inventory open stashes through their own events.
RegisterNetEvent('obsi-lib:stash:legacy', function(id, _, slots, weight)
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = weight, slots = slots })
    TriggerEvent('inventory:client:SetCurrentStash', id)
end)

---------------------------------------------------------------------------------------------------
-- Native menu (KVP stashes)
---------------------------------------------------------------------------------------------------

local menu -- { data, view = 'stash' | 'pocket', cursor, amount }

local ACCENT = { 242, 165, 65 }

local function accentRgb()
    local hex = ObsiConfig.UI.Accent or '#e5122e'
    local r, g, b = hex:match('#(%x%x)(%x%x)(%x%x)')
    if not r then return ACCENT end
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

local function text(value, x, y, scale, colour, font)
    SetTextFont(font or 0)
    SetTextScale(scale, scale)
    SetTextColour(colour[1], colour[2], colour[3], colour[4] or 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(x, y)
end

local function rows()
    local list = {}
    if menu.view == 'stash' then
        list[1] = { label = Core.t('stash_deposit'), view = 'pocket' }
        for _, entry in ipairs(menu.data.items or {}) do
            list[#list + 1] = { label = entry.label or entry.name, count = entry.count, item = entry.name, direction = 'take' }
        end
    else
        list[1] = { label = Core.t('stash_back'), view = 'stash' }
        for _, entry in ipairs(menu.data.inventory or {}) do
            list[#list + 1] = { label = entry.label or entry.name, count = entry.count, item = entry.name, direction = 'put' }
        end
    end
    return list
end

local function close()
    if not menu then return end
    menu = nil
    TriggerServerEvent('obsi-lib:stash:close')
end

local WHITE, MUTED, PANEL, ROW = { 230, 230, 230 }, { 139, 144, 150 }, { 23, 25, 28, 235 }, { 31, 34, 38, 235 }

local function draw(list)
    local accent = accentRgb()
    local x, y, width = 0.03, 0.22, 0.2
    local rowHeight, visible = 0.03, 12
    local first = math.max(1, math.min(menu.cursor - 5, #list - visible + 1))
    local shown = math.min(visible, #list)
    local height = 0.085 + shown * rowHeight + 0.035

    DrawRect(x + width / 2, y + height / 2, width, height, PANEL[1], PANEL[2], PANEL[3], PANEL[4])
    DrawRect(x + width / 2, y + 0.001, width, 0.002, accent[1], accent[2], accent[3], 255)
    text((menu.data.label or Core.t('stash_title')):upper(), x + 0.008, y + 0.012, 0.36, WHITE, 4)
    text(Core.t('stash_slots', menu.data.used or 0, menu.data.slots or 0), x + 0.008, y + 0.045, 0.26, MUTED)

    for index = first, math.min(#list, first + visible - 1) do
        local row = list[index]
        local rowY = y + 0.075 + (index - first) * rowHeight
        local selected = index == menu.cursor
        local colour = selected and ROW or PANEL
        DrawRect(x + width / 2, rowY + rowHeight / 2, width - 0.008, rowHeight - 0.003, colour[1], colour[2], colour[3], colour[4])
        if selected then DrawRect(x + 0.0055, rowY + rowHeight / 2, 0.0015, rowHeight - 0.003, accent[1], accent[2], accent[3], 255) end

        local label = row.label
        if row.count then label = ('%s  x%d'):format(label, row.count) end
        if selected and row.direction then label = ('%s   < %d >'):format(label, menu.amount) end
        text(label, x + 0.012, rowY + 0.005, 0.28, selected and WHITE or MUTED)
    end

    if #list <= 1 then
        text(Core.t('stash_empty'), x + 0.012, y + 0.075 + rowHeight + 0.005, 0.26, MUTED)
    end
    text(Core.t('stash_help'), x + 0.008, y + height - 0.028, 0.22, MUTED)
end

local function run()
    CreateThread(function()
        while menu do
            local list = rows()
            menu.cursor = math.max(1, math.min(menu.cursor, #list))
            local row = list[menu.cursor]
            local fast = IsDisabledControlPressed(0, 21) and 10 or 1

            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- push to talk
            draw(list)

            if IsDisabledControlJustPressed(0, 172) then
                menu.cursor, menu.amount = menu.cursor - 1, 1
            elseif IsDisabledControlJustPressed(0, 173) then
                menu.cursor, menu.amount = menu.cursor + 1, 1
            elseif IsDisabledControlJustPressed(0, 174) then
                menu.amount = math.max(1, menu.amount - fast)
            elseif IsDisabledControlJustPressed(0, 175) then
                menu.amount = math.min(row and row.count or 1, menu.amount + fast)
            elseif IsDisabledControlJustPressed(0, 191) and row then
                if row.view then
                    menu.view, menu.cursor, menu.amount = row.view, 1, 1
                elseif row.direction then
                    TriggerServerEvent('obsi-lib:stash:move', menu.data.id, row.direction, row.item, math.min(menu.amount, row.count))
                end
            elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                close()
            end

            if ObsiLib.player.isDead() then close() end
            Wait(0)
        end
    end)
end

RegisterNetEvent('obsi-lib:stash:menu', function(data)
    if type(data) ~= 'table' then return end
    if menu then
        menu.data = data
        menu.amount = 1
        return
    end
    menu = { data = data, view = 'stash', cursor = 1, amount = 1 }
    run()
end)
