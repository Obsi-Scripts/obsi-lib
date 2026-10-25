--[[
    DISCORD WEBHOOKS (server only - these urls never reach clients)
    Use them with ObsiLib.log('name', { title = '...', message = '...' }).
    A raw https url can also be passed instead of a name.
]]

ObsiWebhooks = {
    main = '',
    vehicles = '',
}

-- Shown in the footer / as the sender of every embed.
ObsiWebhookStyle = {
    username = 'Obsi Scripts',
    avatar = nil,
    color = 0xE5122E,
}
