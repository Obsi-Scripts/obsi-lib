--[[
    obsi-lib configuration (shared, readable by clients - never put secrets here).
    Discord webhook urls live in editable/server/webhooks.lua (server only).
]]

ObsiConfig = {}

-- Language of built-in texts: 'en' or 'pl' (other codes fall back to 'en').
ObsiConfig.Locale = 'en'

-- Extra console output (bridge resolution, protected call errors, state changes).
ObsiConfig.Debug = false

-- Check github.com/Obsi-Scripts/obsi-lib releases on start.
ObsiConfig.VersionCheck = true

-- Framework: 'auto' | 'esx' | 'qb' | 'qbx' | 'custom'
-- 'custom' uses the functions you write in editable/server/framework.lua and editable/client/framework.lua.
ObsiConfig.Framework = 'auto'

-- Inventory: 'auto' | 'ox_inventory' | 'qb-inventory' | 'codem-inventory' | 'jaksam_inventory' | 'custom'
-- 'auto' picks the first started one; without any of them the framework's own item functions are used
-- (also covers ps-inventory / lj-inventory). 'custom' uses editable/server/inventory.lua and editable/client/inventory.lua.
ObsiConfig.Inventory = 'auto'

-- Notifications: 'obsi' (built-in UI) | 'esx' | 'qb' | 'ox' (ox_lib) | 'custom' (editable/*/notify.lua)
ObsiConfig.Notify = 'obsi'

-- Third party integrations. 'auto' detects the started resource, 'none' disables, or force a resource name.
ObsiConfig.Integrations = {
    Banking = 'auto',     -- 'Renewed-Banking' | 'okokBanking' | 'qb-banking' | 'qb-management' | 'esx_society' | 'none'
    VehicleKeys = 'auto', -- 'qbx_vehiclekeys' | 'qb-vehiclekeys' | 'wasabi_carlock' | 'mk_vehiclekeys' | 'none'
    Target = 'auto',      -- 'ox_target' | 'qb-target' | 'none'
    Clothing = 'auto',    -- 'illenium-appearance' | 'fivem-appearance' | 'qb-clothing' | 'esx_skin' | 'none'
    Fuel = 'auto',        -- 'ox_fuel' | 'LegacyFuel' | 'cdn-fuel' | 'ps-fuel' | 'lc_fuel' | 'native'
    Sound = 'auto',       -- 'xsound' | 'nui' (built-in player only) | 'none'
}

-- Jobs counted by ObsiLib.job.copsOnline().
ObsiConfig.PoliceJobs = {
    police = true,
    sheriff = true,
}
-- Only count officers that are on duty (QBCore / QBX and ESX forks with a duty flag).
ObsiConfig.CopsRequireDuty = false

-- ObsiLib.player.isAdmin defaults.
ObsiConfig.Admin = {
    Ace = 'command',                           -- ACE permission, false to skip
    Groups = { 'admin', 'superadmin', 'god' }, -- framework groups
    Identifiers = {},                          -- e.g. 'license:abc...', 'discord:123...', character identifiers
}

-- Built-in UI (Obsi look). Accent is any hex colour.
ObsiConfig.UI = {
    Accent = '#e5122e',
    Notify = {
        Position = 'top-right', -- 'top-right' | 'top-left' | 'top' | 'right' | 'left' | 'bottom-right' | 'bottom-left'
        Duration = 5000,        -- ms, default when a notification has none
        MaxVisible = 5,
    },
    Progress = {
        Offset = 14,     -- distance from the bottom of the screen in vh
        CancelKey = 73,  -- control id (73 = X)
        CancelLabel = 'X',
    },
    TextUI = {
        Position = 'left', -- 'left' | 'right' | 'top' | 'bottom'
    },
}

-- Sounds (built-in NUI player and server relays).
ObsiConfig.Sound = {
    DefaultVolume = 0.5,
    DefaultRange = 20.0,       -- metres, positional sounds
    MaxBroadcastRange = 250.0, -- metres, cap for client requested broadcasts
    BroadcastCooldown = 1000,  -- ms between broadcasts per player
    AllowRemoteUrls = false,   -- let clients broadcast http(s) urls to other players (off: only short file names)
}

-- Plate generator (ObsiLib.vehicle.generatePlate).
ObsiConfig.Plates = {
    Letters = 4,
    Numbers = 4,
    LetterSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    NumberSet = '0123456789',
    Separator = '',
}

-- Owned vehicle tables (ObsiLib.vehicle.saveOwned / plate uniqueness).
ObsiConfig.VehicleTables = {
    esx = { table = 'owned_vehicles', owner = 'owner', plate = 'plate', vehicle = 'vehicle', stored = 'stored' },
    qb = { table = 'player_vehicles', plate = 'plate' },
}

-- Stashes without ox_inventory / qb-inventory are kept in resource KVP with a small native menu.
ObsiConfig.Stash = {
    KvpPrefix = 'obsi_stash_',
    SessionSeconds = 600,
    DefaultSlots = 50,
    DefaultWeight = 100000,
    -- Database tables used for qb-inventory stashes.
    Tables = {
        ['qb'] = { table = 'inventories', identifier = 'identifier', column = 'items' },
        ['qb-legacy'] = { table = 'stashitems', identifier = 'stash', column = 'items' },
    },
}

-- Used by ObsiLib.job.setOffline when the player is not online.
ObsiConfig.OfflineJobTables = {
    esx = { table = 'users', job = 'job', grade = 'job_grade', identifier = 'identifier' },
    qb = { table = 'players', column = 'job', identifier = 'citizenid' },
}

-- Item image url templates (ObsiLib.items.image). %s = item name or image file.
ObsiConfig.ItemImages = {
    ox = 'nui://ox_inventory/web/images/%s.png',
    qb = 'nui://qb-inventory/html/images/%s',
    ['qb-legacy'] = 'nui://%s/html/images/%s',
    default = 'nui://ox_inventory/web/images/%s.png',
}
ObsiConfig.ItemCatalogCacheSeconds = 60

-- Extra icon names for ObsiLib.target (short name -> FontAwesome class), merged over the built-in map.
ObsiConfig.TargetIcons = {}

-- Developer tools (client).
ObsiConfig.DevTools = {
    CoordsCommand = 'obsicoords', -- raycast pointer that prints the hit coordinates, false to disable
}
