-- Loaded last on each side: hands the finished ObsiLib table to other resources.

exports('get', function()
    return ObsiLib
end)

AddEventHandler('obsi-lib:get', function(cb)
    if type(cb) == 'function' then cb(ObsiLib) end
end)

Core.trace('ready on %s (framework: %s, inventory: %s)', ObsiLib.side, ObsiLib.framework, ObsiLib.inventory)
