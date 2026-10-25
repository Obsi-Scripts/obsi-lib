-- Clothing bridge (client): illenium-appearance, fivem-appearance, qb-clothing, esx_skin / skinchanger.
-- Outfit format (appearance style):
--   { components = { { component_id, drawable, texture } }, props = { { prop_id, drawable, texture } } }
-- qb-clothing `outfitData` tables and esx_skin `tshirt_1` style tables are converted automatically.
--   ObsiLib.clothing.get()         current outfit
--   ObsiLib.clothing.apply(outfit) wear an outfit (the current look is remembered)
--   ObsiLib.clothing.restore()     back to the saved civilian clothes
--   ObsiLib.clothing.provider()

local saved

local COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = { 0, 1, 2, 6, 7 }

-- name -> { kind = 'component' | 'prop', id } per clothing format
local QB_KEYS = {
    mask = { 'component', 1 }, arms = { 'component', 3 }, pants = { 'component', 4 }, bag = { 'component', 5 },
    shoes = { 'component', 6 }, accessory = { 'component', 7 }, ['t-shirt'] = { 'component', 8 }, vest = { 'component', 9 },
    decals = { 'component', 10 }, torso2 = { 'component', 11 },
    hat = { 'prop', 0 }, glass = { 'prop', 1 }, ear = { 'prop', 2 }, watch = { 'prop', 6 }, bracelet = { 'prop', 7 },
}
local ESX_KEYS = {
    mask = { 'component', 1 }, arms = { 'component', 3 }, pants = { 'component', 4 }, bags = { 'component', 5 },
    shoes = { 'component', 6 }, chain = { 'component', 7 }, tshirt = { 'component', 8 }, bproof = { 'component', 9 },
    decals = { 'component', 10 }, torso = { 'component', 11 },
    helmet = { 'prop', 0 }, glasses = { 'prop', 1 }, ears = { 'prop', 2 }, watches = { 'prop', 6 }, bracelets = { 'prop', 7 },
}

local PROVIDERS = { 'illenium-appearance', 'fivem-appearance', 'qb-clothing', 'skinchanger' }
local ALIASES = { illenium = 'illenium-appearance', fivem = 'fivem-appearance', qb = 'qb-clothing', esx_skin = 'skinchanger', skinchanger = 'skinchanger' }

local clothing = {}

---'illenium-appearance' | 'fivem-appearance' | 'qb-clothing' | 'skinchanger' | 'none'
function clothing.provider()
    return Core.integration(ObsiConfig.Integrations.Clothing, PROVIDERS, ALIASES)
end

local function isAppearance(provider)
    return provider == 'illenium-appearance' or provider == 'fivem-appearance'
end

local function capture(ped)
    local components, props = {}, {}
    for _, id in ipairs(COMPONENTS) do
        components[#components + 1] = { component_id = id, drawable = GetPedDrawableVariation(ped, id), texture = GetPedTextureVariation(ped, id) }
    end
    for _, id in ipairs(PROPS) do
        props[#props + 1] = { prop_id = id, drawable = GetPedPropIndex(ped, id), texture = GetPedPropTextureIndex(ped, id) }
    end
    return { model = GetEntityModel(ped), components = components, props = props }
end

local function push(target, slot, drawable, texture)
    if slot[1] == 'component' then
        target.components[#target.components + 1] = { component_id = slot[2], drawable = drawable, texture = texture }
    else
        target.props[#target.props + 1] = { prop_id = slot[2], drawable = drawable, texture = texture }
    end
end

---Any supported outfit format -> appearance format (nil when nothing recognisable).
local function toAppearance(outfit)
    if type(outfit) ~= 'table' then return nil end
    if outfit.components or outfit.props then
        return { model = outfit.model, components = outfit.components or {}, props = outfit.props or {} }
    end

    local source = outfit.outfitData or outfit
    local result = { components = {}, props = {} }

    for key, slot in pairs(QB_KEYS) do
        local entry = source[key]
        if type(entry) == 'table' and entry.item ~= nil then
            push(result, slot, tonumber(entry.item) or (slot[1] == 'prop' and -1 or 0), tonumber(entry.texture) or 0)
        end
    end
    if #result.components + #result.props > 0 then return result end

    for key, slot in pairs(ESX_KEYS) do
        local drawable = key == 'arms' and source.arms or source[key .. '_1']
        if drawable ~= nil then
            local texture = key == 'arms' and source.arms_2 or source[key .. '_2']
            push(result, slot, tonumber(drawable) or (slot[1] == 'prop' and -1 or 0), tonumber(texture) or 0)
        end
    end
    if #result.components + #result.props > 0 then return result end
    return nil
end

local function toFormat(outfit, keys, esxStyle)
    local out = {}
    local function find(kind, id)
        for key, slot in pairs(keys) do
            if slot[1] == kind and slot[2] == id then return key end
        end
    end
    for _, c in ipairs(outfit.components or {}) do
        local key = find('component', c.component_id)
        if key then
            if not esxStyle then
                out[key] = { item = c.drawable, texture = c.texture }
            elseif key == 'arms' then
                out.arms, out.arms_2 = c.drawable, c.texture
            else
                out[key .. '_1'], out[key .. '_2'] = c.drawable, c.texture
            end
        end
    end
    for _, p in ipairs(outfit.props or {}) do
        local key = find('prop', p.prop_id)
        if key then
            if esxStyle then
                out[key .. '_1'], out[key .. '_2'] = p.drawable, p.texture
            else
                out[key] = { item = p.drawable, texture = p.texture }
            end
        end
    end
    return out
end

local function applyNatives(ped, outfit)
    for _, c in ipairs(outfit.components or {}) do
        if c.component_id and c.component_id ~= 0 and c.component_id ~= 2 then
            SetPedComponentVariation(ped, c.component_id, c.drawable or 0, c.texture or 0, 0)
        end
    end
    for _, p in ipairs(outfit.props or {}) do
        if p.prop_id then
            if (p.drawable or -1) < 0 then
                ClearPedProp(ped, p.prop_id)
            else
                SetPedPropIndex(ped, p.prop_id, p.drawable, p.texture or 0, true)
            end
        end
    end
end

---@return table outfit in appearance format
function clothing.get()
    local provider = clothing.provider()
    if isAppearance(provider) then
        local appearance = Core.safe(function() return exports[provider]:getPedAppearance(PlayerPedId()) end)
        if appearance and appearance.components then
            return { model = appearance.model, components = appearance.components, props = appearance.props or {} }
        end
    end
    return capture(PlayerPedId())
end

---@return boolean
function clothing.apply(outfit)
    local normalised = toAppearance(outfit)
    if not normalised then return false end

    local ped = PlayerPedId()
    local provider = clothing.provider()

    if not saved then
        saved = isAppearance(provider) and Core.safe(function() return exports[provider]:getPedAppearance(ped) end) or capture(ped)
    end

    if isAppearance(provider) then
        local ok = Core.safe(function()
            exports[provider]:setPedComponents(ped, normalised.components)
            exports[provider]:setPedProps(ped, normalised.props)
            return true
        end)
        if ok then return true end
    elseif provider == 'qb-clothing' then
        TriggerEvent('qb-clothing:client:loadOutfit', { outfitData = toFormat(normalised, QB_KEYS, false) })
        return true
    elseif provider == 'skinchanger' then
        local applied = promise.new()
        TriggerEvent('skinchanger:getSkin', function(skin)
            TriggerEvent('skinchanger:loadClothes', skin, toFormat(normalised, ESX_KEYS, true))
            applied:resolve(true)
        end)
        SetTimeout(1000, function() if applied.state == 0 then applied:resolve(false) end end)
        if Citizen.Await(applied) then return true end
    end

    applyNatives(ped, normalised)
    return true
end

---@return boolean
function clothing.restore()
    local provider = clothing.provider()
    local ESX = ObsiLib.framework == 'esx' and Core.frameworkObject() or nil
    local done = false

    if provider == 'illenium-appearance' then
        TriggerEvent('illenium-appearance:client:reloadSkin', true)
        done = true
    elseif provider == 'qb-clothing' then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        done = true
    elseif (provider == 'skinchanger' or provider == 'fivem-appearance') and ESX then
        done = Core.safe(function()
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                if not skin then return end
                if provider == 'skinchanger' then
                    TriggerEvent('skinchanger:loadSkin', skin)
                else
                    exports['fivem-appearance']:setPlayerAppearance(skin)
                end
            end)
            return true
        end) == true
    end

    if not done and saved then
        local ped = PlayerPedId()
        if isAppearance(provider) and saved.headBlend then
            done = Core.safe(function() exports[provider]:setPedAppearance(ped, saved) return true end) == true
        end
        if not done then
            applyNatives(ped, saved)
            done = true
        end
    end

    saved = nil
    return done
end

ObsiLib.clothing = clothing
