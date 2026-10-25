-- Game helpers (client).

local game = {}

---@return number|nil model hash once loaded
function game.requestModel(model, timeoutMs)
    local hash = type(model) == 'string' and joaat(model) or model
    if not hash or not IsModelInCdimage(hash) then return nil end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local limit = GetGameTimer() + (tonumber(timeoutMs) or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > limit then return nil end
        Wait(0)
    end
    return hash
end

---@return boolean
function game.requestAnimDict(dict, timeoutMs)
    if type(dict) ~= 'string' or not DoesAnimDictExist(dict) then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local limit = GetGameTimer() + (tonumber(timeoutMs) or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > limit then return false end
        Wait(0)
    end
    return true
end

---Closest vehicle to coords (default: player) within maxDistance (default 5.0).
---@return number|nil vehicle, number|nil distance
function game.closestVehicle(coords, maxDistance)
    coords = Core.vec3(coords) or GetEntityCoords(PlayerPedId())
    maxDistance = tonumber(maxDistance) or 5.0
    local best, bestDistance
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local distance = #(GetEntityCoords(vehicle) - coords)
        if distance <= maxDistance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = vehicle, distance
        end
    end
    return best, bestDistance
end

---Closest other player within maxDistance (default 3.0).
---@return number|nil playerId, number|nil ped, number|nil distance
function game.closestPlayer(coords, maxDistance)
    coords = Core.vec3(coords) or GetEntityCoords(PlayerPedId())
    maxDistance = tonumber(maxDistance) or 3.0
    local me = PlayerId()
    local best, bestPed, bestDistance
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= me then
            local ped = GetPlayerPed(playerId)
            local distance = #(GetEntityCoords(ped) - coords)
            if distance <= maxDistance and (not bestDistance or distance < bestDistance) then
                best, bestPed, bestDistance = playerId, ped, distance
            end
        end
    end
    return best, bestPed, bestDistance
end

---Vehicle properties through the framework, or a native fallback.
function game.vehicleProps(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return {} end
    local object = Core.frameworkObject()
    if ObsiLib.framework == 'esx' and object and object.Game then
        local props = Core.safe(object.Game.GetVehicleProperties, vehicle)
        if props then return props end
    elseif object and object.Functions and object.Functions.GetVehicleProperties then
        local props = Core.safe(object.Functions.GetVehicleProperties, vehicle)
        if props then return props end
    end

    local primary, secondary = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    local props = {
        model = GetEntityModel(vehicle),
        plate = ObsiLib.util.trim(GetVehicleNumberPlateText(vehicle)),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        color1 = primary, color2 = secondary, pearlescentColor = pearl, wheelColor = wheel,
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        livery = GetVehicleLivery(vehicle),
        mods = {},
    }
    for index = 0, 49 do props.mods[index] = GetVehicleMod(vehicle, index) end
    return props
end

---@return boolean
function game.setVehicleProps(vehicle, props)
    if not vehicle or not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end
    local object = Core.frameworkObject()
    if ObsiLib.framework == 'esx' and object and object.Game then
        if Core.safe(function() object.Game.SetVehicleProperties(vehicle, props) return true end) then return true end
    elseif object and object.Functions and object.Functions.SetVehicleProperties then
        if Core.safe(function() object.Functions.SetVehicleProperties(vehicle, props) return true end) then return true end
    end

    SetVehicleModKit(vehicle, 0)
    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
    if props.color1 and props.color2 then SetVehicleColours(vehicle, props.color1, props.color2) end
    if props.pearlescentColor and props.wheelColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end
    if props.livery then SetVehicleLivery(vehicle, props.livery) end
    for index, value in pairs(props.mods or {}) do
        index = tonumber(index)
        if index and value and value ~= -1 then SetVehicleMod(vehicle, index, value, false) end
    end
    return true
end

local FUEL = { 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lc_fuel' }

local function fuelProvider()
    return Core.integration(ObsiConfig.Integrations.Fuel, FUEL, nil, 'native')
end

---@return number fuel 0 - 100
function game.getFuel(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end
    local provider = fuelProvider()
    local level
    if provider == 'ox_fuel' then
        level = Entity(vehicle).state.fuel
    elseif provider ~= 'native' and provider ~= 'none' then
        level = Core.safe(function() return exports[provider]:GetFuel(vehicle) end)
    end
    return ObsiLib.util.round(tonumber(level) or GetVehicleFuelLevel(vehicle), 1)
end

---@return boolean
function game.setFuel(vehicle, level)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    level = math.max(0.0, math.min(100.0, tonumber(level) or 100.0)) + 0.0
    local provider = fuelProvider()
    if provider == 'ox_fuel' then
        Entity(vehicle).state:set('fuel', level, true)
    elseif provider ~= 'native' and provider ~= 'none' then
        Core.safe(function() exports[provider]:SetFuel(vehicle, level) end)
    end
    SetVehicleFuelLevel(vehicle, level)
    return true
end

---'car' | 'motorcycle' | 'bicycle' | 'boat' | 'plane' | 'helicopter' | 'train' | 'unknown'
function game.vehicleType(vehicle)
    local model = GetEntityModel(vehicle)
    if IsThisModelABicycle(model) then return 'bicycle' end
    if IsThisModelABike(model) then return 'motorcycle' end
    if IsThisModelACar(model) then return 'car' end
    if IsThisModelABoat(model) then return 'boat' end
    if IsThisModelAPlane(model) then return 'plane' end
    if IsThisModelAHeli(model) then return 'helicopter' end
    if IsThisModelATrain(model) then return 'train' end
    return 'unknown'
end

function game.vehicleLocked(vehicle)
    return DoesEntityExist(vehicle) and GetVehicleDoorLockStatus(vehicle) > 1
end

function game.vehicleLightsOn(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local _, lightsOn, highBeams = GetVehicleLightsState(vehicle)
    return lightsOn == 1 or highBeams == 1
end

function game.vehicleEngineOn(vehicle)
    return DoesEntityExist(vehicle) and GetIsVehicleEngineRunning(vehicle)
end

---@return { hash: number, clip: number, total: number }|nil
function game.weaponInfo(ped)
    ped = ped or PlayerPedId()
    local armed, hash = GetCurrentPedWeapon(ped, true)
    if not armed then return nil end
    local _, clip = GetAmmoInClip(ped, hash)
    return { hash = hash, clip = clip, total = GetAmmoInPedWeapon(ped, hash) }
end

---Direction vector from a rotation (degrees).
function game.rotationToDirection(rotation)
    local x, z = math.rad(rotation.x), math.rad(rotation.z)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

---Raycast from the gameplay camera.
---@return boolean hit, vector3 coords, number entity
function game.raycast(distance, flags)
    local origin = GetGameplayCamCoord()
    local target = origin + game.rotationToDirection(GetGameplayCamRot(2)) * (tonumber(distance) or 25.0)
    local handle = StartShapeTestLosProbe(origin.x, origin.y, origin.z, target.x, target.y, target.z, flags or -1, PlayerPedId(), 4)
    local status, hit, coords, _, entity = GetShapeTestResult(handle)
    while status == 1 do
        Wait(0)
        status, hit, coords, _, entity = GetShapeTestResult(handle)
    end
    return hit == 1, coords, entity
end

ObsiLib.game = game
