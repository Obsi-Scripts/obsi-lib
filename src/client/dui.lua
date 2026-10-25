-- DUI (client): browser textures.
--   local screen = ObsiLib.dui.create({ url = 'https://...', width = 1280, height = 720 })
--   screen.dict / screen.texture   runtime texture dictionary and name
--   screen.setUrl(url)  screen.send(table)  screen.replace(txd, txn)  screen.restore(txd, txn)  screen.destroy()
-- Instances are plain tables with closures so they survive being returned through exports.

local instances = {}
local counter = 0

local dui = {}

function dui.create(opts)
    opts = type(opts) == 'table' and opts or { url = opts }
    if type(opts.url) ~= 'string' then error('ObsiLib.dui.create needs a url', 2) end

    counter = counter + 1
    local id = ('obsi_dui_%d_%d'):format(GetGameTimer(), counter)
    local width, height = math.floor(tonumber(opts.width) or 1280), math.floor(tonumber(opts.height) or 720)

    local handle = CreateDui(opts.url, width, height)
    local dict, texture = id .. '_txd', id .. '_tex'
    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(dict), texture, GetDuiHandle(handle))

    local replaced = {}
    local alive = true
    local instance = { id = id, dict = dict, texture = texture, handle = handle, url = opts.url, width = width, height = height }

    function instance.setUrl(url)
        if not alive or type(url) ~= 'string' then return end
        instance.url = url
        SetDuiUrl(handle, url)
    end

    function instance.send(message)
        if not alive then return end
        SendDuiMessage(handle, json.encode(message))
    end

    ---Shows this DUI in place of an existing game texture.
    function instance.replace(originalDict, originalTexture)
        if not alive then return end
        AddReplaceTexture(originalDict, originalTexture, dict, texture)
        replaced[originalDict .. ':' .. originalTexture] = { originalDict, originalTexture }
    end

    function instance.restore(originalDict, originalTexture)
        RemoveReplaceTexture(originalDict, originalTexture)
        replaced[originalDict .. ':' .. originalTexture] = nil
    end

    function instance.destroy()
        if not alive then return end
        alive = false
        for _, pair in pairs(replaced) do RemoveReplaceTexture(pair[1], pair[2]) end
        SetDuiUrl(handle, 'about:blank')
        DestroyDui(handle)
        instances[id] = nil
        Core.trace('dui %s destroyed', id)
    end

    instances[id] = instance
    Core.own(Core.caller(), instance.destroy)
    Core.trace('dui %s created (%s)', id, opts.url)
    return instance
end

---@return table|nil instance by id
function dui.get(id)
    return instances[id]
end

ObsiLib.dui = dui

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Core.resource then return end
    for _, instance in pairs(instances) do Core.safe(instance.destroy) end
end)
