-- obsi-lib by Obsi Scripts - https://github.com/Obsi-Scripts/obsi-lib
-- Licensed under GPL-3.0, see LICENSE.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

name 'obsi-lib'
author 'Obsi Scripts'
version '1.0.1'
repository 'https://github.com/Obsi-Scripts/obsi-lib'
description 'Obsi Scripts shared library: framework and inventory bridge, UI (notify, progress, text UI, sounds) and gameplay helpers'

dependencies {
    'oxmysql',
}

-- Load order matters: config -> core -> locales -> detection -> utilities -> editable hooks -> modules -> export.
shared_scripts {
    'editable/shared/config.lua',
    'src/shared/core.lua',
    'locales/en.lua',
    'locales/pl.lua',
    'src/shared/detect.lua',
    'src/shared/util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'editable/server/framework.lua',
    'editable/server/inventory.lua',
    'editable/server/notify.lua',
    'editable/server/webhooks.lua',
    'src/server/framework/base.lua',
    'src/server/framework/esx.lua',
    'src/server/framework/qb.lua',
    'src/server/framework/custom.lua',
    'src/server/callback.lua',
    'src/server/player.lua',
    'src/server/society.lua',
    'src/server/items.lua',
    'src/server/stash.lua',
    'src/server/vehicle.lua',
    'src/server/notify.lua',
    'src/server/sound.lua',
    'src/server/state.lua',
    'src/server/webhook.lua',
    'src/server/version.lua',
    'src/shared/export.lua',
}

client_scripts {
    'editable/client/framework.lua',
    'editable/client/inventory.lua',
    'editable/client/notify.lua',
    'src/client/core.lua',
    'src/client/callback.lua',
    'src/client/state.lua',
    'src/client/player.lua',
    'src/client/items.lua',
    'src/client/stash.lua',
    'src/client/notify.lua',
    'src/client/progress.lua',
    'src/client/textui.lua',
    'src/client/sound.lua',
    'src/client/dui.lua',
    'src/client/point.lua',
    'src/client/keybind.lua',
    'src/client/target.lua',
    'src/client/clothing.lua',
    'src/client/game.lua',
    'src/client/vehicle.lua',
    'src/client/devtools.lua',
    'src/shared/export.lua',
}

ui_page 'web/build/index.html'

files {
    'init.lua',
    'web/build/index.html',
    'web/build/**/*',
}
