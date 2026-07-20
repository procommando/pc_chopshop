fx_version 'cerulean'
game 'gta5'

author 'ProCommando'
description 'Chop Contracts Custom Script'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
}

lua54 'yes'
