-- Vehicles (server): plates, owned vehicle rows, vehicle keys.

local vehicle = {}

local function normalisePlate(plate)
    if plate == nil then return nil end
    plate = ObsiLib.util.trim(plate):upper()
    if plate == '' then return nil end
    return plate
end

---@return boolean whether a plate is already owned
function vehicle.plateTaken(plate)
    plate = normalisePlate(plate)
    if not plate then return true end
    local tables = ObsiConfig.VehicleTables
    local def = ObsiLib.framework == 'esx' and tables.esx or tables.qb
    local found = Core.safe(MySQL.scalar.await, ('SELECT 1 FROM `%s` WHERE `%s` = ? LIMIT 1'):format(def.table, def.plate), { plate })
    return found ~= nil
end

---Random unique plate built from ObsiConfig.Plates (nil after 50 failed attempts).
---@return string|nil
function vehicle.generatePlate()
    local cfg = ObsiConfig.Plates
    local random = ObsiLib.util.randomString
    for _ = 1, 50 do
        local plate = (random(cfg.Letters, cfg.LetterSet) .. (cfg.Separator or '') .. random(cfg.Numbers, cfg.NumberSet)):upper()
        if not vehicle.plateTaken(plate) then return plate end
    end
    Core.warn('could not generate a free plate after 50 attempts, widen ObsiConfig.Plates')
    return nil
end

---Stores an owned vehicle for a character.
---@param data { src?: number, owner?: string, model: string, plate?: string, props?: table, garage?: string, price?: number }
---@return string|false plate
function vehicle.saveOwned(data)
    if type(data) ~= 'table' or not Core.text(data.model) then return false end
    local src = tonumber(data.src)
    local owner = data.owner or (src and ObsiLib.player.identifier(src))
    if not owner then return false end

    local plate = normalisePlate(data.plate) or vehicle.generatePlate()
    if not plate then return false end

    local props = type(data.props) == 'table' and data.props or {}
    props.model = props.model or joaat(data.model)
    props.plate = plate

    local inserted
    if ObsiLib.framework == 'esx' then
        local def = ObsiConfig.VehicleTables.esx
        inserted = Core.safe(MySQL.insert.await,
            ('INSERT INTO `%s` (`%s`, `%s`, `%s`, `%s`) VALUES (?, ?, ?, ?)'):format(def.table, def.owner, def.plate, def.vehicle, def.stored),
            { owner, plate, json.encode(props), 1 })
    elseif Core.started('qbx_vehicles') then
        inserted = Core.safe(function()
            return exports.qbx_vehicles:CreatePlayerVehicle({ model = data.model, citizenid = owner, garage = data.garage, props = props })
        end)
    else
        local def = ObsiConfig.VehicleTables.qb
        local license = src and GetPlayerIdentifierByType(src, 'license') or nil
        inserted = Core.safe(MySQL.insert.await,
            ('INSERT INTO `%s` (license, citizenid, vehicle, hash, mods, `%s`, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'):format(def.table, def.plate),
            { license, owner, data.model, joaat(data.model), json.encode(props), plate, data.garage or 'pillboxgarage', 1 })
    end

    if not inserted then return false end

    if ObsiWebhooks and ObsiWebhooks.vehicles and ObsiWebhooks.vehicles ~= '' then
        ObsiLib.log('vehicles', {
            title = 'Vehicle saved',
            fields = {
                { name = 'Owner', value = tostring(src and ObsiLib.player.name(src) or owner), inline = true },
                { name = 'Model', value = data.model, inline = true },
                { name = 'Plate', value = plate, inline = true },
                data.price and { name = 'Price', value = tostring(data.price), inline = true } or nil,
            },
        })
    end

    return plate
end

local KEY_RESOURCES = { 'qbx_vehiclekeys', 'qb-vehiclekeys', 'wasabi_carlock', 'mk_vehiclekeys' }

---Name of the vehicle key resource in use ('none' when unsupported).
function vehicle.keysProvider()
    return Core.integration(ObsiConfig.Integrations.VehicleKeys, KEY_RESOURCES)
end

---Gives vehicle keys to a player.
---@return boolean whether a key resource was asked
function vehicle.giveKeys(src, plate, netId)
    src = tonumber(src)
    if not src then return false end
    plate = normalisePlate(plate)

    local provider = vehicle.keysProvider()
    if provider == 'none' then return false end

    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if provider == 'qbx_vehiclekeys' and entity ~= 0 then
        if Core.safe(function() exports.qbx_vehiclekeys:GiveKeys(src, entity, true) return true end) then return true end
    elseif provider == 'wasabi_carlock' and plate then
        if Core.safe(function() exports.wasabi_carlock:GiveKey(src, plate) return true end) then return true end
    end

    -- The other resources only offer client side APIs.
    TriggerClientEvent('obsi-lib:vehicle:keys', src, netId, plate)
    return true
end

ObsiLib.vehicle = vehicle
exports('generatePlate', vehicle.generatePlate)
