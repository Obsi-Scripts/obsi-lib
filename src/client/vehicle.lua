-- Vehicle keys (client side of ObsiLib.vehicle.giveKeys).

local KEY_RESOURCES = { 'qbx_vehiclekeys', 'qb-vehiclekeys', 'wasabi_carlock', 'mk_vehiclekeys' }

local vehicle = {}

function vehicle.keysProvider()
    return Core.integration(ObsiConfig.Integrations.VehicleKeys, KEY_RESOURCES)
end

---Gives keys for a vehicle through the client API of the key resource.
---@return boolean
function vehicle.giveKeys(entity, plate)
    if (not plate or plate == '') and entity and entity ~= 0 and DoesEntityExist(entity) then
        plate = GetVehicleNumberPlateText(entity)
    end
    plate = plate and ObsiLib.util.trim(plate):upper() or nil

    local provider = vehicle.keysProvider()
    if provider == 'qb-vehiclekeys' or provider == 'qbx_vehiclekeys' then
        if plate then TriggerEvent('vehiclekeys:client:SetOwner', plate) end
        return plate ~= nil
    elseif provider == 'wasabi_carlock' then
        return plate ~= nil and Core.safe(function() exports.wasabi_carlock:GiveKey(plate) return true end) == true
    elseif provider == 'mk_vehiclekeys' then
        return entity ~= nil and entity ~= 0 and Core.safe(function() exports.mk_vehiclekeys:AddKey(entity) return true end) == true
    end
    return false
end

ObsiLib.vehicle = vehicle

RegisterNetEvent('obsi-lib:vehicle:keys', function(netId, plate)
    local entity = 0
    if netId then
        local timeout = GetGameTimer() + 3000
        while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < timeout do Wait(50) end
        if NetworkDoesNetworkIdExist(netId) then entity = NetToVeh(netId) end
    end
    vehicle.giveKeys(entity, plate)
end)
