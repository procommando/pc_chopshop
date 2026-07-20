Config = Config or {}

Config.Debug = false

-- =========================
-- Chop Zones
-- =========================
Config.ChopZones = {
    { coords = vector3(-56.77, -1196.27, 28.02), radius = 50.0 },
    { coords = vector3(2904.32, 4493.33, 48.07), radius = 25.0 },
    { coords = vector3(-1173.10, -2031.73, 13.42), radius = 50.0 },
    { coords = vector3(108.28, 6643.02, 31.44), radius = 25.0 },
}

-- =========================
-- Contract Flow
-- =========================
Config.ContractCooldownSeconds = 120

Config.ContractVehicleCountMin = 2
Config.ContractVehicleCountMax = 2

Config.RequiredPartsPerVehicle = 4

-- UI/Feedback tuning (used by client)
Config.Feedback = {
    -- Adds the "Chop Status" option in third-eye to explain why nothing shows
    statusOptionEnabled = true,

    texts = {
        notInZone = "Not in a chop zone.",
        noMatchingContract = "No active contract targets this vehicle.",
        cooldown = "Cooldown active (%ds). Lay low.",
        needMoreParts = "Need %d more part(s) before you can finish.",
        readyToFinish = "Ready to FINISH chop.",
    }
}

-- Optional: enable/disable reconnect rebuild pass (server)
Config.Persistence = {
    enabled = true, -- when true, server runs ResyncOnJoin to re-apply tooltip info cleanly
}

-- =========================
-- Certificate Rewards
-- =========================
Config.CertificateRewards = {
    easy   = { markedbills_min = 2,  markedbills_max = 5  },
    medium = { markedbills_min = 5,  markedbills_max = 10 },
    hard   = { markedbills_min = 10, markedbills_max = 18 },
}

-- =========================
-- Items
-- =========================
Config.Items = {
    contract_easy   = 'chop_contract_easy',
    contract_medium = 'chop_contract_medium',
    contract_hard   = 'chop_contract_hard',

    cert_easy   = 'chop_cert_easy',
    cert_medium = 'chop_cert_medium',
    cert_hard   = 'chop_cert_hard',

    part_door   = 'chop_part_door',
    part_wheel  = 'chop_part_wheel',
    part_bonnet = 'chop_part_bonnet',
    part_trunk  = 'chop_part_trunk',

    markedbills = 'markedbills',
}

-- =========================
-- Physical Consistency Indices
-- =========================
Config.Physical = {
    -- GTA doors: 0=LF, 1=RF, 2=LR, 3=RR, 4=hood, 5=trunk
    doorIndices = { driver = 0, passenger = 1, rearLeft = 2, rearRight = 3, hood = 4, trunk = 5 },

    -- Tyre indices used by natives:
    -- Common mapping in GTA: 0=FL, 1=FR, 4=RL, 5=RR
    tyreIndices = { frontLeft = 0, frontRight = 1, rearLeft = 4, rearRight = 5 },
}

-- =========================
-- Vehicle pools by contract tier
-- =========================
Config.VehiclePools = {
    easy = {
    --[[
    ██████╗      ██████╗██╗      █████╗ ███████╗███████╗
    ██╔══██╗    ██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
    ██║  ██║    ██║     ██║     ███████║███████╗███████╗
    ██║  ██║    ██║     ██║     ██╔══██║╚════██║╚════██║
    ██████╔╝    ╚██████╗███████╗██║  ██║███████║███████║
    ╚═════╝      ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]

        'dilettante',
        'asea',
        'emperor',
        'washington',
        'voodoo',
        'tornado',
        'burrito3',
        'rumpo',
        'speedo',
        'youga',

    },

    medium = {
    --[[
    ██████╗     ██████╗██╗      █████╗ ███████╗███████╗
    ██╔════╝    ██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
    ██║         ██║     ██║     ███████║███████╗███████╗
    ██║         ██║     ██║     ██╔══██║╚════██║╚════██║
    ╚██████╗    ╚██████╗███████╗██║  ██║███████║███████║
    ╚═════╝     ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]

        'panto',
        'prairie',
        'baller',
        'baller2',
        'cavalcade',
        'cavalcade2',
        'habanero',
        'patriot',
        'radi',
        'faction',
        'rebel',
        'bobcatxl',
        

    --[[
    ██████╗      ██████╗██╗      █████╗ ███████╗███████╗
    ██╔══██╗    ██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
    ██████╔╝    ██║     ██║     ███████║███████╗███████╗
    ██╔══██╗    ██║     ██║     ██╔══██║╚════██║╚════██║
    ██████╔╝    ╚██████╗███████╗██║  ██║███████║███████║
    ╚═════╝      ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]

        'fugitive',
        'intruder',
        'tailgater',
        'schafter2',
        'asterope2',
        'landstalker2',
        'jackal',
        'oracle2',
        'sentinel',
        'sentinel2',
        'buccaneer',
        'phoenix',
        'picador',
        'ruiner',
        'sabregt',
        'buffalo',
        'buffalo2',
        'sultan',
        'bison',

    },

    hard = {
    --[[
    █████╗      ██████╗██╗      █████╗ ███████╗███████╗
    ██╔══██╗    ██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
    ███████║    ██║     ██║     ███████║███████╗███████╗
    ██╔══██║    ██║     ██║     ██╔══██║╚════██║╚════██║
    ██║  ██║    ╚██████╗███████╗██║  ██║███████║███████║
    ╚═╝  ╚═╝     ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]

        'exemplar',
        'felon',
        'banshee',
        'comet2',
        'elegy2',
        'feltzer2',
        'kuruma',
        'lynx',
        'ninef',
        'ninef2',
        'seven70',
        'specter',
    }
}


Config.StolenOnly = true
Config.OwnedVehiclesTable = 'player_vehicles'
Config.OwnedVehiclesPlateColumn = 'plate'

-- =========================
-- Rep System
-- =========================
Config.Rep = {
    enabled = true,

    repPerLevel = 100,

    requirements = {
        easy = 0,
        medium = 0,
        hard = 0,
    },

    gainPerVehicle = {
        easy = 1,
        medium = 2,
        hard = 3,
    },

    bonusByLevel = {
        { level = 0,  mult = 1.00 },
        { level = 5,  mult = 1.50 },
        { level = 10, mult = 2.00 },
        { level = 15, mult = 2.50 },
        { level = 20, mult = 3.00 },
        { level = 25, mult = 3.50 },
        { level = 30, mult = 4.00 },
        { level = 35, mult = 4.50 },
        { level = 40, mult = 5.00 },
        { level = 45, mult = 5.50 },
        { level = 50, mult = 6.00 },
    }
}

-- =========================
-- Contract Pinning
-- =========================
Config.Pinning = {
    enabled = true,
    metadataKey = 'chop_pinned_contract',
}

-- =========================
-- Part Quality Tiers
-- =========================
Config.PartQuality = {
    enabled = true,

    chances = {
        easy   = { rusty = 90, standard = 9,  pristine = 1 },
        medium = { rusty = 85, standard = 13, pristine = 2 },
        hard   = { rusty = 80, standard = 17, pristine = 3 },
    },

    pristineBonusPerLevel = 0.25, -- level 10 => +2.5% pristine
    labels = {
        rusty = "Rusty",
        standard = "Standard",
        pristine = "Pristine",
    }
}

-- =========================
-- Chopping Buyer/Reward NPC
-- =========================
Config.Chopping = {
    enabled = true,

    NPCs = {
        {
            model = `s_m_m_dockwork_01`,
            coords = vector4(2908.0408, 4501.0029, 48.0748, 147.3925),
            scenario = 'WORLD_HUMAN_CLIPBOARD',
        },
        {
            model = `s_m_m_dockwork_01`,
            coords = vector4(111.9186, 6637.6543, 31.7911, 44.0673),
            scenario = 'WORLD_HUMAN_CLIPBOARD',
        },
        {
            model = `s_m_m_dockwork_01`,
            coords = vector4(-61.5313, -1181.3973, 28.0261, 189.4019),
            scenario = 'WORLD_HUMAN_CLIPBOARD',
        },
        {
            model = `s_m_m_dockwork_01`,
            coords = vector4(-1167.0627, -2020.0959, 13.1605, 143.7509),
            scenario = 'WORLD_HUMAN_CLIPBOARD',
        },
    },

    targetDistance = 2.0,
    sellBatchSize = 50,

    -- 'cash' OR 'markedbills'
    payItem = 'markedbills',

    prices = {
        door   = { rusty = 15, standard = 50, pristine = 100 },
        wheel  = { rusty = 15, standard = 50, pristine = 100 },
        bonnet = { rusty = 15, standard = 50, pristine = 100 },
        trunk  = { rusty = 15, standard = 50, pristine = 100 },
    }
}

