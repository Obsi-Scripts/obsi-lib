-- Release check against github.com/Obsi-Scripts/obsi-lib.

local REPOSITORY = 'Obsi-Scripts/obsi-lib'

local function parse(version)
    local major, minor, patch = tostring(version or ''):match('(%d+)%.(%d+)%.(%d+)')
    if not major then return nil end
    return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function isNewer(latest, current)
    for i = 1, 3 do
        if latest[i] ~= current[i] then return latest[i] > current[i] end
    end
    return false
end

---Checks a GitHub repository's latest release against a resource's version (usable by other Obsi scripts).
---@param resource string resource whose `version` metadata is compared
---@param repository string 'Owner/repo'
function ObsiLib.checkVersion(resource, repository)
    local currentText = GetResourceMetadata(resource, 'version', 0)
    local current = parse(currentText)
    if not current then return end

    PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(repository), function(status, body)
        if status ~= 200 then
            print(('^3[%s] %s^0'):format(resource, Core.t('version_failed', resource, tostring(status))))
            return
        end
        local release = json.decode(body or '') or {}
        if release.prerelease then return end
        local latest = parse(release.tag_name)
        if latest and isNewer(latest, current) then
            print(('^3[%s] %s^0'):format(resource, Core.t('version_outdated', resource, currentText, table.concat(latest, '.'), release.html_url or ('https://github.com/' .. repository .. '/releases'))))
        else
            print(('^2[%s] %s^0'):format(resource, Core.t('version_ok', resource, currentText, ObsiLib.framework, ObsiLib.inventory)))
        end
    end, 'GET', '', { ['User-Agent'] = 'obsi-lib' })
end

if ObsiConfig.VersionCheck ~= false then
    SetTimeout(2500, function()
        ObsiLib.checkVersion(Core.resource, REPOSITORY)
    end)
end
