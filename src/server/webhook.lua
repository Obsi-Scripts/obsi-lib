-- Discord webhooks (server). Messages go through a small queue so bursts do not hit Discord rate limits.
--   ObsiLib.log(hook, { title, message, color, fields, footer, image, thumbnail })
--   ObsiLib.webhook.send(hook, rawPayload)
-- hook = name from editable/server/webhooks.lua or a raw https url.

local queue = {}
local running = false
local SPACING = 350 -- ms between requests

local function resolveUrl(hook)
    if type(hook) ~= 'string' or hook == '' then return nil end
    if hook:match('^https://') then return hook end
    local url = ObsiWebhooks and ObsiWebhooks[hook]
    if type(url) == 'string' and url:match('^https://') then return url end
    return nil
end

local function pump()
    if running then return end
    running = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            local done = promise.new()
            PerformHttpRequest(job.url, function(status, _, headers)
                if status == 429 then
                    local retry = tonumber(headers and (headers['retry-after'] or headers['Retry-After'])) or 2
                    table.insert(queue, 1, job)
                    SetTimeout(math.floor(retry * 1000), function() done:resolve() end)
                    return
                end
                if status < 200 or status >= 300 then Core.trace('webhook answered HTTP %s', status) end
                done:resolve()
            end, 'POST', job.body, { ['Content-Type'] = 'application/json' })
            Citizen.Await(done)
            Wait(SPACING)
        end
        running = false
    end)
end

local webhook = {}

---Sends a raw Discord payload ({ content, embeds, username, avatar_url }).
---@return boolean queued
function webhook.send(hook, payload)
    local url = resolveUrl(hook)
    if not url then
        Core.trace('webhook "%s" is not configured', tostring(hook))
        return false
    end
    if type(payload) ~= 'table' then return false end
    local style = ObsiWebhookStyle or {}
    payload.username = payload.username or style.username
    payload.avatar_url = payload.avatar_url or style.avatar
    queue[#queue + 1] = { url = url, body = json.encode(payload) }
    pump()
    return true
end

ObsiLib.webhook = webhook

---Sends one embed.
---@return boolean queued
function ObsiLib.log(hook, data)
    if type(data) == 'string' then data = { message = data } end
    if type(data) ~= 'table' then return false end
    local style = ObsiWebhookStyle or {}

    local fields = {}
    for _, field in pairs(data.fields or {}) do
        if type(field) == 'table' and field.name and field.value then fields[#fields + 1] = field end
    end

    return webhook.send(hook, {
        embeds = { {
            title = data.title,
            description = data.message or data.description,
            color = tonumber(data.color) or style.color,
            fields = #fields > 0 and fields or nil,
            footer = { text = data.footer or ('obsi-lib v%s'):format(ObsiLib.version) },
            image = data.image and { url = data.image } or nil,
            thumbnail = data.thumbnail and { url = data.thumbnail } or nil,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
end

exports('log', ObsiLib.log)
