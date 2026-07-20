local QBCore = exports['qb-core']:GetCoreObject()

local function dbg(...)
    if Config.Debug then print('[pc_chopshop]', ...) end
end

-- ========= BASIC HELPERS =========
local function normalizePlate(plate)
    plate = plate or ''
    plate = string.upper(plate)
    plate = plate:gsub('%s+', '')
    return plate
end

local function isOwnedVehicle(plate)
    if not Config.StolenOnly then return false end
    plate = normalizePlate(plate)
    if plate == '' then return true end -- fail closed

    local tbl = Config.OwnedVehiclesTable
    local col = Config.OwnedVehiclesPlateColumn
    local result = MySQL.scalar.await(("SELECT 1 FROM `%s` WHERE `%s` = ? LIMIT 1"):format(tbl, col), { plate })
    return result ~= nil
end

local function tierFromItem(itemName)
    if itemName == Config.Items.contract_easy then return 'easy' end
    if itemName == Config.Items.contract_medium then return 'medium' end
    if itemName == Config.Items.contract_hard then return 'hard' end
    return nil
end

local function certTierFromItem(itemName)
    if itemName == Config.Items.cert_easy then return 'easy' end
    if itemName == Config.Items.cert_medium then return 'medium' end
    if itemName == Config.Items.cert_hard then return 'hard' end
    return nil
end

local function pickUnique(list, count)
    local pool = {}
    for _, v in ipairs(list) do pool[#pool + 1] = string.lower(v) end
    local picked = {}
    count = math.min(count, #pool)
    for i = 1, count do
        local idx = math.random(1, #pool)
        picked[#picked + 1] = pool[idx]
        table.remove(pool, idx)
    end
    return picked
end

-- ========= REP (metadata) =========
local function getRep(Player)
    local md = Player.PlayerData.metadata or {}
    return tonumber(md.chop_rep) or 0
end

local function getLevel(Player)
    local md = Player.PlayerData.metadata or {}
    return tonumber(md.chop_level) or math.floor(getRep(Player) / (Config.Rep.repPerLevel or 25))
end

local function setRep(Player, rep)
    Player.Functions.SetMetaData('chop_rep', rep)
    Player.Functions.SetMetaData('chop_level', math.floor(rep / (Config.Rep.repPerLevel or 25)))
end

local function repBonusMult(level)
    if not Config.Rep or not Config.Rep.bonusByLevel then return 1.0 end
    local mult = 1.0
    for _, row in ipairs(Config.Rep.bonusByLevel) do
        if level >= row.level then mult = row.mult end
    end
    return mult
end

-- ========= PINNING (metadata) =========
local function pinKey()
    return (Config.Pinning and Config.Pinning.metadataKey) or 'chop_pinned_contract'
end

local function getPinned(Player)
    local md = Player.PlayerData.metadata or {}
    local k = pinKey()
    return md[k]
end

local function setPinned(Player, contractIdOrNil)
    local k = pinKey()
    Player.Functions.SetMetaData(k, contractIdOrNil)
end

-- ========= QUALITY ROLL =========
local function rollQuality(tier, level)
    if not (Config.PartQuality and Config.PartQuality.enabled) then
        return 'standard'
    end

    local base = (Config.PartQuality.chances and Config.PartQuality.chances[tier]) or { rusty = 50, standard = 45, pristine = 5 }
    local rusty = tonumber(base.rusty) or 50
    local standard = tonumber(base.standard) or 45
    local pristine = tonumber(base.pristine) or 5

    local bonus = (tonumber(Config.PartQuality.pristineBonusPerLevel) or 0) * (tonumber(level) or 0)
    if bonus > 25 then bonus = 25 end -- cap

    pristine = pristine + bonus

    local take = bonus
    if rusty >= take then
        rusty = rusty - take
        take = 0
    else
        take = take - rusty
        rusty = 0
    end

    if take > 0 then
        if standard >= take then
            standard = standard - take
        else
            standard = 0
        end
    end

    local total = rusty + standard + pristine
    if total <= 0 then return 'standard' end

    rusty = (rusty / total) * 100
    standard = (standard / total) * 100
    pristine = (pristine / total) * 100

    local r = math.random() * 100
    if r <= rusty then return 'rusty' end
    if r <= (rusty + standard) then return 'standard' end
    return 'pristine'
end

-- ========= CONTRACT CORE =========
local function rewardCertificate(src, tier)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local r = Config.CertificateRewards[tier]
    if not r then return end

    local amount = math.random(r.markedbills_min, r.markedbills_max)

    if Config.Rep and Config.Rep.enabled then
        local lvl = getLevel(Player)
        amount = math.floor(amount * repBonusMult(lvl))
        if amount < 1 then amount = 1 end
    end

    Player.Functions.AddItem(Config.Items.markedbills, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items.markedbills], 'add', amount)
end

local function newContractId()
    return tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

local function listHasValue(t, v)
    if type(t) ~= "table" then return false end
    for _, x in ipairs(t) do
        if x == v then return true end
    end
    return false
end

local function prettyVehicleName(model)
    model = string.lower(model or '')
    local v = QBCore.Shared.Vehicles and QBCore.Shared.Vehicles[model]
    if v and v.brand and v.name then
        return (v.brand .. " " .. v.name)
    end
    return model
end

local function buildContractInfo(tier)
    local pool = Config.VehiclePools[tier] or {}
    local count = math.random(Config.ContractVehicleCountMin, Config.ContractVehicleCountMax)
    local vehicles = pickUnique(pool, count)

    return {
        contractId = newContractId(),
        started = true,
        tier = tier,

        vehicles = vehicles, -- remaining list (shrinks)
        allVehicles = (function()
            local copy = {}
            for i = 1, #vehicles do copy[i] = vehicles[i] end
            return copy
        end)(),
        completed = {},

        target = vehicles[1],
        targetHash = joaat(vehicles[1]),

        partsDone = 0,
        requiredParts = Config.RequiredPartsPerVehicle,

        removed = { doors = {}, wheels = {}, hood = false, trunk = false },

        cooldownUntil = 0, -- os.time()
    }
end

-- ========= TOOLTIP (Pinned + Vehicles ONLY) =========
local function applyTooltipInfo(info, isPinned)
    local keep = {
        contractId = true, started = true, tier = true,
        vehicles = true, allVehicles = true, completed = true,
        target = true, targetHash = true,
        partsDone = true, requiredParts = true,
        removed = true, cooldownUntil = true,
    }

    for k, _ in pairs(info) do
        if not keep[k] then
            info[k] = nil
        end
    end

    info["Pinned"] = isPinned and "YES" or "NO"

    local lines = {}
    local sourceList = info.allVehicles or info.vehicles or {}
    info.completed = info.completed or {}

    for i = 1, #sourceList do
        local model = sourceList[i]
        local pretty = prettyVehicleName(model)

        if listHasValue(info.completed, model) then
            lines[#lines + 1] = ("• <span style='opacity:0.55;'><s>%s</s></span>"):format(pretty)
        else
            lines[#lines + 1] = ("• %s"):format(pretty)
        end
    end

    if #lines > 0 then
        info["Vehicles"] = "\n" .. table.concat(lines, "\n")
    else
        info["Vehicles"] = "\n• None"
    end
end

local function findContractItem(Player, contractId)
    local items = Player.PlayerData.items or {}
    for slot, item in pairs(items) do
        if item and item.info and item.info.contractId == contractId then
            return slot, item
        end
    end
    return nil, nil
end

local function updateItemInfo(Player, slot, item, newInfo)
    local pinned = getPinned(Player)
    applyTooltipInfo(newInfo, pinned and pinned == newInfo.contractId)

    Player.Functions.RemoveItem(item.name, 1, slot)
    Player.Functions.AddItem(item.name, 1, slot, newInfo)
end

-- ========= RESYNC/PERSIST ON RECONNECT =========
RegisterNetEvent('pc_chopshop:server:ResyncOnJoin', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Just ensure the item tooltip info is clean/consistent after reconnect.
    local items = Player.PlayerData.items or {}
    for slot, item in pairs(items) do
        if item and item.info and item.info.started and item.info.contractId then
            if item.name == Config.Items.contract_easy
            or item.name == Config.Items.contract_medium
            or item.name == Config.Items.contract_hard then
                local info = item.info
                updateItemInfo(Player, slot, item, info)
            end
        end
    end
end)

-- ========= CALLBACKS =========
QBCore.Functions.CreateCallback('pc_chopshop:server:GetActiveContracts', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local pinned = getPinned(Player)
    local out = {}

    local items = Player.PlayerData.items or {}
    for slot, item in pairs(items) do
        if item and item.info and item.info.started and item.info.contractId then
            local info = item.info
            out[#out + 1] = {
                slot = slot,
                name = item.name,
                contractId = info.contractId,
                tier = info.tier,
                target = info.target,
                targetHash = info.targetHash,
                partsDone = info.partsDone or 0,
                requiredParts = info.requiredParts or Config.RequiredPartsPerVehicle,
                cooldownUntil = info.cooldownUntil or 0,
                remaining = (info.vehicles and #info.vehicles) or 0,
                pinned = (pinned and pinned == info.contractId) or false,
            }
        end
    end

    cb(out)
end)

QBCore.Functions.CreateCallback('pc_chopshop:server:GetPinned', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    cb(getPinned(Player))
end)

QBCore.Functions.CreateCallback('pc_chopshop:server:GetCertCounts', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local function count(itemName)
        local it = Player.Functions.GetItemByName(itemName)
        return (it and it.amount) or 0
    end

    cb({
        easy = count(Config.Items.cert_easy),
        medium = count(Config.Items.cert_medium),
        hard = count(Config.Items.cert_hard),
    })
end)

-- ========= USEABLE CONTRACT ITEMS =========
local function registerUseableContract(itemName)
    QBCore.Functions.CreateUseableItem(itemName, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player or not item then return end

        local tier = tierFromItem(itemName)
        if not tier then
            TriggerClientEvent('QBCore:Notify', source, 'Invalid contract item.', 'error')
            return
        end

        -- Toggle PIN if started
        if item.info and item.info.started and Config.Pinning and Config.Pinning.enabled then
            local pinned = getPinned(Player)
            if pinned and pinned == item.info.contractId then
                setPinned(Player, nil)
            else
                setPinned(Player, item.info.contractId)
            end

            updateItemInfo(Player, item.slot, item, item.info)
            return
        end

        -- Rep requirement
        if Config.Rep and Config.Rep.enabled then
            local rep = getRep(Player)
            local req = (Config.Rep.requirements and Config.Rep.requirements[tier]) or 0
            if rep < req then
                TriggerClientEvent('QBCore:Notify', source, ('You need %d chop rep for %s contracts.'):format(req, tier), 'error')
                return
            end
        end

        local info = buildContractInfo(tier)
        updateItemInfo(Player, item.slot, item, info)

        TriggerClientEvent('QBCore:Notify', source, 'Contract started. Find the vehicles to chop!', 'success')
    end)
end

registerUseableContract(Config.Items.contract_easy)
registerUseableContract(Config.Items.contract_medium)
registerUseableContract(Config.Items.contract_hard)

-- ========= REMOVE PART =========
RegisterNetEvent('pc_chopshop:server:RemovePart', function(contractId, partType, slotIndex, plate, vehHash)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local invSlot, item = findContractItem(Player, contractId)
    if not invSlot or not item or not item.info or not item.info.started then
        TriggerClientEvent('QBCore:Notify', src, 'Contract not found.', 'error')
        return
    end

    local info = item.info
    plate = normalizePlate(plate)

    local cd = (tonumber(info.cooldownUntil) or 0) - os.time()
    if cd > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Cooldown active. Wait %ds.'):format(cd), 'error')
        return
    end

    if Config.StolenOnly and isOwnedVehicle(plate) then
        TriggerClientEvent('QBCore:Notify', src, 'Player-owned vehicle. Stolen only.', 'error')
        return
    end

    if not vehHash or tonumber(vehHash) ~= tonumber(info.targetHash) then
        TriggerClientEvent('QBCore:Notify', src, ('Wrong vehicle. Target: %s'):format(info.target or 'unknown'), 'error')
        return
    end

    info.partsDone = tonumber(info.partsDone) or 0
    info.requiredParts = tonumber(info.requiredParts) or Config.RequiredPartsPerVehicle

    if info.partsDone >= info.requiredParts then
        TriggerClientEvent('QBCore:Notify', src, 'Enough parts removed. Finish the chop.', 'error')
        return
    end

    info.removed = info.removed or { doors = {}, wheels = {}, hood = false, trunk = false }

    local giveItem = nil

    if partType == 'door' then
        slotIndex = tonumber(slotIndex)
        if slotIndex == nil then return TriggerClientEvent('QBCore:Notify', src, 'Bad door slot.', 'error') end
        if info.removed.doors[slotIndex] then return TriggerClientEvent('QBCore:Notify', src, 'Door already removed.', 'error') end
        info.removed.doors[slotIndex] = true
        giveItem = Config.Items.part_door

    elseif partType == 'wheel' then
        slotIndex = tonumber(slotIndex)
        if slotIndex == nil then return TriggerClientEvent('QBCore:Notify', src, 'Bad wheel slot.', 'error') end
        if info.removed.wheels[slotIndex] then return TriggerClientEvent('QBCore:Notify', src, 'Wheel already removed.', 'error') end
        info.removed.wheels[slotIndex] = true
        giveItem = Config.Items.part_wheel

    elseif partType == 'hood' then
        if info.removed.hood then return TriggerClientEvent('QBCore:Notify', src, 'Bonnet already removed.', 'error') end
        info.removed.hood = true
        giveItem = Config.Items.part_bonnet

    elseif partType == 'trunk' then
        if info.removed.trunk then return TriggerClientEvent('QBCore:Notify', src, 'Trunk already removed.', 'error') end
        info.removed.trunk = true
        giveItem = Config.Items.part_trunk

    else
        TriggerClientEvent('QBCore:Notify', src, 'Invalid part type.', 'error')
        return
    end

    info.partsDone = info.partsDone + 1
    updateItemInfo(Player, invSlot, item, info)

    if giveItem then
        local quality = rollQuality(info.tier, getLevel(Player))
        local qLabel = (Config.PartQuality and Config.PartQuality.labels and Config.PartQuality.labels[quality]) or quality

        Player.Functions.AddItem(giveItem, 1, false, {
            quality = quality,
            quality_label = qLabel,
            source_tier = info.tier,
        })
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[giveItem], 'add', 1)
        TriggerClientEvent('QBCore:Notify', src, ('Part quality: %s'):format(qLabel), 'primary')
    end
end)

-- ========= FINISH CHOP =========
RegisterNetEvent('pc_chopshop:server:FinishChop', function(contractId, plate, vehHash)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local invSlot, item = findContractItem(Player, contractId)
    if not invSlot or not item or not item.info or not item.info.started then
        TriggerClientEvent('QBCore:Notify', src, 'Contract not found.', 'error')
        return
    end

    local info = item.info
    plate = normalizePlate(plate)

    local cd = (tonumber(info.cooldownUntil) or 0) - os.time()
    if cd > 0 then
        TriggerClientEvent('QBCore:Notify', src, ('Cooldown active. Wait %ds.'):format(cd), 'error')
        return
    end

    if Config.StolenOnly and isOwnedVehicle(plate) then
        TriggerClientEvent('QBCore:Notify', src, 'Player-owned vehicle. Stolen only.', 'error')
        return
    end

    if not vehHash or tonumber(vehHash) ~= tonumber(info.targetHash) then
        TriggerClientEvent('QBCore:Notify', src, ('Wrong vehicle. Target: %s'):format(info.target or 'unknown'), 'error')
        return
    end

    info.partsDone = tonumber(info.partsDone) or 0
    info.requiredParts = tonumber(info.requiredParts) or Config.RequiredPartsPerVehicle
    if info.partsDone < info.requiredParts then
        TriggerClientEvent('QBCore:Notify', src, ('Remove %d parts first.'):format(info.requiredParts), 'error')
        return
    end

    -- Rep gain
    if Config.Rep and Config.Rep.enabled then
        local rep = getRep(Player)
        local gain = (Config.Rep.gainPerVehicle and Config.Rep.gainPerVehicle[info.tier]) or 0
        rep = rep + gain
        setRep(Player, rep)
        TriggerClientEvent('QBCore:Notify', src, ('Chop rep +%d (Total %d)'):format(gain, rep), 'primary')
    end

    -- Mark completed
    info.completed = info.completed or {}
    table.insert(info.completed, info.target)

    -- Remove target from vehicles list
    if info.vehicles and #info.vehicles > 0 and info.vehicles[1] == info.target then
        table.remove(info.vehicles, 1)
    else
        if info.vehicles then
            for i = #info.vehicles, 1, -1 do
                if info.vehicles[i] == info.target then table.remove(info.vehicles, i) break end
            end
        end
    end

    -- reset per-car state
    info.partsDone = 0
    info.removed = { doors = {}, wheels = {}, hood = false, trunk = false }
    info.cooldownUntil = os.time() + Config.ContractCooldownSeconds

    -- next target?
    if info.vehicles and #info.vehicles > 0 then
        info.target = info.vehicles[1]
        info.targetHash = joaat(info.target)
        updateItemInfo(Player, invSlot, item, info)
        TriggerClientEvent('QBCore:Notify', src, 'Chopped. Find the next car!', 'success')
        return
    end

    -- Convert to certificate
    local certItem = (info.tier == 'easy' and Config.Items.cert_easy)
        or (info.tier == 'medium' and Config.Items.cert_medium)
        or Config.Items.cert_hard

    Player.Functions.RemoveItem(item.name, 1, invSlot)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], 'remove', 1)

    Player.Functions.AddItem(certItem, 1, false, { tier = info.tier, contractId = info.contractId })
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[certItem], 'add', 1)

    local pinned = getPinned(Player)
    if pinned and pinned == info.contractId then
        setPinned(Player, nil)
    end

    TriggerClientEvent('QBCore:Notify', src, 'Contract completed! You got a certificate.', 'success')
end)

-- ========= SELL PARTS =========
local function addMoney(Player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local pay = (Config.Chopping and Config.Chopping.payItem) or 'cash'
    if pay == 'cash' then
        Player.Functions.AddMoney('cash', amount, 'Chopping-parts')
    else
        Player.Functions.AddItem(Config.Items.markedbills, amount)
        TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items[Config.Items.markedbills], 'add', amount)
    end
end

local function partTypeFromItemName(itemName)
    if itemName == Config.Items.part_door then return 'door' end
    if itemName == Config.Items.part_wheel then return 'wheel' end
    if itemName == Config.Items.part_bonnet then return 'bonnet' end
    if itemName == Config.Items.part_trunk then return 'trunk' end
    return nil
end

local function qualityFromInfo(info)
    if not info then return 'standard' end
    local q = info.quality
    if q ~= 'rusty' and q ~= 'standard' and q ~= 'pristine' then
        return 'standard'
    end
    return q
end

local function getPartUnitPrice(partType, quality)
    if not Config.Chopping or not Config.Chopping.prices then return 0 end
    local t = Config.Chopping.prices[partType]
    if not t then return 0 end
    return tonumber(t[quality]) or 0
end

RegisterNetEvent('pc_chopshop:server:SellParts', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not (Config.Chopping and Config.Chopping.enabled) then
        return TriggerClientEvent('QBCore:Notify', src, 'Chopping sales disabled.', 'error')
    end

    local items = Player.PlayerData.items or {}
    local batchLeft = (Config.Chopping.sellBatchSize or 50)

    local soldCount = 0
    local totalPay = 0

    for slot, item in pairs(items) do
        if batchLeft <= 0 then break end
        if item and item.amount and item.amount > 0 then
            local pType = partTypeFromItemName(item.name)
            if pType then
                local q = qualityFromInfo(item.info)
                local unit = getPartUnitPrice(pType, q)
                if unit > 0 then
                    local take = math.min(item.amount, batchLeft)

                    Player.Functions.RemoveItem(item.name, take, slot)
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], 'remove', take)

                    soldCount = soldCount + take
                    totalPay = totalPay + (unit * take)
                    batchLeft = batchLeft - take
                end
            end
        end
    end

    if soldCount <= 0 or totalPay <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You have no chop parts to sell.', 'error')
        return
    end

    addMoney(Player, totalPay)
    TriggerClientEvent('QBCore:Notify', src, ('Sold %d parts for $%d.'):format(soldCount, totalPay), 'success')
end)

-- ========= CASH CERTIFICATE =========
RegisterNetEvent('pc_chopshop:server:CashCertificate', function(certItemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local tier = certTierFromItem(certItemName)
    if not tier then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid certificate.', 'error')
        return
    end

    local item = Player.Functions.GetItemByName(certItemName)
    if not item or item.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have that certificate.', 'error')
        return
    end

    Player.Functions.RemoveItem(certItemName, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[certItemName], 'remove', 1)

    rewardCertificate(src, tier)
    TriggerClientEvent('QBCore:Notify', src, 'Paid. Pleasure doing business.', 'success')
end)
