-- Points (client): coordinate triggers.
--   local p = ObsiLib.point.add({
--       coords = vec3(...), distance = 2.0,
--       onEnter = function(point) end, onExit = function(point) end,
--       inside = function(point) end,    -- every frame while in range
--       ... any extra fields are kept on the point
--   })
--   p.remove()   ObsiLib.point.remove(p.id)   ObsiLib.point.closest()   ObsiLib.point.nearby()   ObsiLib.point.all()
-- Points belong to the resource that created them and disappear when it stops.

local points = {}
local inRange = {}
local closest
local counter = 0

local point = {}

function point.remove(id)
    local entry = points[id]
    if not entry then return end
    points[id] = nil
    inRange[id] = nil
    if closest == entry then closest = nil end
end

---@return table point
function point.add(data)
    if type(data) ~= 'table' then error('ObsiLib.point.add expects a table', 2) end
    local coords = Core.vec3(data.coords)
    if not coords then error('ObsiLib.point.add needs coords', 2) end

    counter = counter + 1
    local id = counter
    data.id = id
    data.coords = coords
    data.distance = tonumber(data.distance) or 2.0
    data.resource = Core.caller()
    data.remove = function() point.remove(id) end

    points[id] = data
    Core.own(data.resource, function() point.remove(id) end)
    return data
end

function point.get(id)
    return points[id]
end

function point.all()
    return points
end

---Points the player is currently inside.
function point.nearby()
    local list = {}
    for id in pairs(inRange) do list[#list + 1] = points[id] end
    return list
end

function point.closest()
    return closest
end

ObsiLib.point = point

local function fire(entry, key)
    local fn = entry[key]
    if not fn then return end
    local ok, err = pcall(fn, entry)
    if not ok then
        entry[key] = nil
        Core.warn('point %d %s failed and was disabled: %s', entry.id, key, tostring(err))
    end
end

-- Distance sweep (300 ms) and per-frame `inside` callbacks.
CreateThread(function()
    local frameLoop = false

    while true do
        local position = GetEntityCoords(PlayerPedId())
        local best, bestDistance

        for id, entry in pairs(points) do
            local distance = #(position - entry.coords)
            if distance <= entry.distance then
                entry.currentDistance = distance
                if not inRange[id] then
                    inRange[id] = true
                    fire(entry, 'onEnter')
                end
                if not bestDistance or distance < bestDistance then best, bestDistance = entry, distance end
            elseif inRange[id] then
                inRange[id] = nil
                entry.currentDistance = nil
                fire(entry, 'onExit')
            end
        end

        if closest and closest ~= best then closest.isClosest = nil end
        closest = best
        if best then best.isClosest = true end

        if not frameLoop and next(inRange) then
            frameLoop = true
            CreateThread(function()
                while next(inRange) do
                    for id in pairs(inRange) do
                        local entry = points[id]
                        if entry and entry.inside then fire(entry, 'inside') end
                    end
                    Wait(0)
                end
                frameLoop = false
            end)
        end

        Wait(300)
    end
end)
