-- Detection of the framework, inventory and optional integrations.

---@return boolean
function Core.started(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local FRAMEWORK_ORDER = {
    { resource = 'es_extended', id = 'esx' },
    { resource = 'qbx_core', id = 'qbx' },
    { resource = 'qb-core', id = 'qb' },
}

local FRAMEWORK_IDS = { esx = true, qb = true, qbx = true, custom = true }

---@return 'esx'|'qb'|'qbx'|'custom'
function Core.detectFramework()
    local forced = tostring(ObsiConfig.Framework or 'auto'):lower()
    if forced ~= 'auto' and forced ~= '' then
        if FRAMEWORK_IDS[forced] then return forced end
        Core.warn('ObsiConfig.Framework "%s" is not supported, falling back to auto detection', forced)
    end

    for _, entry in ipairs(FRAMEWORK_ORDER) do
        if Core.started(entry.resource) then return entry.id end
    end
    return 'custom'
end

-- First started resource wins. ox_inventory goes first: it replaces the framework item functions.
Core.INVENTORIES = { 'ox_inventory', 'qb-inventory', 'codem-inventory', 'jaksam_inventory' }

---@return string inventory resource, 'custom' or 'framework'
function Core.detectInventory()
    local forced = ObsiConfig.Inventory or 'auto'
    if forced == 'custom' then return 'custom' end

    if forced ~= 'auto' and forced ~= '' then
        if Core.started(forced) then return forced end
        Core.warn('ObsiConfig.Inventory is "%s" but that resource is not started, using auto detection', forced)
    end

    for _, resource in ipairs(Core.INVENTORIES) do
        if Core.started(resource) then return resource end
    end
    return 'framework'
end

local LEGACY_QB_FORKS = { 'ps-inventory', 'lj-inventory' }

---Inventory flavour used internally: 'ox' | 'qb' (qb-inventory v2+) | 'qb-legacy' (v1, ps, lj) |
---'codem' | 'jaksam' | 'custom' | 'framework'. Second value: the legacy resource name, if any.
function Core.inventoryKind()
    local detected = ObsiLib.inventory or Core.detectInventory()

    if detected == 'ox_inventory' then return 'ox' end
    if detected == 'codem-inventory' then return 'codem' end
    if detected == 'jaksam_inventory' then return 'jaksam' end
    if detected == 'custom' then return 'custom' end

    if detected == 'qb-inventory' then
        local version = GetResourceMetadata('qb-inventory', 'version', 0) or '0'
        local major = tonumber(tostring(version):match('^(%d+)')) or 0
        if major >= 2 then return 'qb' end
        return 'qb-legacy', 'qb-inventory'
    end

    for _, fork in ipairs(LEGACY_QB_FORKS) do
        if Core.started(fork) then return 'qb-legacy', fork end
    end

    return 'framework'
end

---Resolves an integration setting.
---@param setting string|nil the config value ('auto', 'none' or a resource name / alias)
---@param candidates string[] resources tried in order when 'auto'
---@param aliases table|nil lowercase alias -> resource name
---@param fallback string|nil returned when nothing is found (default 'none')
function Core.integration(setting, candidates, aliases, fallback)
    fallback = fallback or 'none'
    local wanted = tostring(setting or 'auto')
    local lower = wanted:lower()

    if lower == 'none' or lower == 'false' then return 'none' end
    if lower ~= 'auto' and lower ~= '' then
        return (aliases and aliases[lower]) or wanted
    end

    for _, resource in ipairs(candidates) do
        if Core.started(resource) then return resource end
    end
    return fallback
end

ObsiLib.framework = Core.detectFramework()
ObsiLib.inventory = Core.detectInventory()

---Re-runs detection (e.g. after starting resources in a different order) and returns the result.
---@return string framework, string inventory
function ObsiLib.detect()
    ObsiLib.framework = Core.detectFramework()
    ObsiLib.inventory = Core.detectInventory()
    return ObsiLib.framework, ObsiLib.inventory
end
