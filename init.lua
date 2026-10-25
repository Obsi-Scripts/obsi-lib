-- obsi-lib import.
-- Add `shared_script '@obsi-lib/init.lua'` to your fxmanifest and the global `ObsiLib` is ready on both sides.

if GetResourceState('obsi-lib') ~= 'started' and GetResourceState('obsi-lib') ~= 'starting' then
    error('^1[obsi-lib] obsi-lib must be started before ' .. GetCurrentResourceName() .. '^0', 0)
end

ObsiLib = exports['obsi-lib']:get()
