local QBCore = exports['qb-core']:GetCoreObject()

local cache = { list = {}, ts = 0 }
local pinnedId = nil
local spawnedScrapPeds = {}

-- forward declarations
local matchingContracts

-- ========= TIME / COOLDOWN =========
local function nowEpoch()
    -- FiveM network/cloud time in seconds (safe client-side)
    return GetCloudTimeAsInt()
end

local function secondsLeft(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return 0 end
    local now = nowEpoch()
    if ts <= now then return 0 end
    return ts - now
end

local function isOnCooldown(contract)
    if not contract or not contract.cooldownUntil then return false, 0 end
    local remaining = (tonumber(contract.cooldownUntil) or 0) - nowEpoch()
    if remaining > 0 then return true, remaining end
    return false, 0
end

-- ========= UTIL =========
local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    return model
end

local function inChopZone()
    local p = GetEntityCoords(PlayerPedId())
    for _, z in ipairs(Config.ChopZones) do
        if #(p - z.coords) <= z.radius then return true end
    end
    return false
end

local function getVehModelHash(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return GetEntityModel(veh)
end

local function getVehiclePlate(veh)
    if veh == 0 then return nil end
    return GetVehicleNumberPlateText(veh)
end

-- ========= ANIMS / PROGRESS =========
local function ensureAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
end

local function playDismantleAnim(ms)
    local ped = PlayerPedId()
    local dict = "mini@repair"
    local anim = "fixing_a_player"
    ensureAnimDict(dict)
    TaskPlayAnim(ped, dict, anim, 8.0, 8.0, ms, 1, 0.0, false, false, false)
end

local function stopAnim()
    ClearPedTasks(PlayerPedId())
end

local function doProgress(label, timeMs, cb)
    QBCore.Functions.Progressbar(
        "pc_chopshop_action",
        label,
        timeMs,
        false,
        true,
        { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
        {},
        {},
        {},
        function() cb(true) end,
        function() cb(false) end
    )
end

-- ========= SYNC CACHE / PIN =========
local function refreshPinned(cb)
    if not (Config.Pinning and Config.Pinning.enabled) then
        pinnedId = nil
        return cb(pinnedId)
    end

    QBCore.Functions.TriggerCallback('pc_chopshop:server:GetPinned', function(id)
        pinnedId = id
        cb(pinnedId)
    end)
end

local function refreshContracts(cb)
    local now = GetGameTimer()
    if cache.ts ~= 0 and (now - cache.ts) < 1200 then
        return cb(cache.list)
    end

    QBCore.Functions.TriggerCallback('pc_chopshop:server:GetActiveContracts', function(list)
        cache.list = list or {}
        cache.ts = GetGameTimer()
        cb(cache.list)
    end)
end

-- Keep contract cache/pin fresh so qb-target canInteract can be synchronous
CreateThread(function()
    Wait(1000)
    while true do
        refreshPinned(function() end)
        refreshContracts(function() end)
        Wait(1500)
    end
end)

-- Persist/rebuild on reconnect
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('pc_chopshop:server:ResyncOnJoin')
    cache.ts = 0
    refreshPinned(function() end)
    refreshContracts(function() end)
end)

-- ========= CONTRACT MATCHING =========
matchingContracts = function(vehHash, list, wantFinish)
    local out = {}
    local now = nowEpoch()

    for _, c in ipairs(list or {}) do
        if tonumber(c.targetHash) == tonumber(vehHash) then
            local cd = (tonumber(c.cooldownUntil) or 0) - now
            local cooldownOk = cd <= 0

            local partsDone = tonumber(c.partsDone) or 0
            local req = tonumber(c.requiredParts) or Config.RequiredPartsPerVehicle

            local canFinish = cooldownOk and partsDone >= req
            local canRemove = cooldownOk and partsDone < req

            if wantFinish and canFinish then out[#out+1] = c end
            if (not wantFinish) and canRemove then out[#out+1] = c end
        end
    end

    return out
end

local function contractsForVeh(vehHash, list)
    local out = {}
    for _, c in ipairs(list or {}) do
        if tonumber(c.targetHash) == tonumber(vehHash) then
            out[#out+1] = c
        end
    end
    return out
end

local function anyFinishReadyForVeh(vehHash)
    return #matchingContracts(vehHash, cache.list, true) > 0
end

local function anyPartReadyForVeh(vehHash)
    return #matchingContracts(vehHash, cache.list, false) > 0
end

-- RULE: once finish is ready, ONLY show Finish Chop
local function canShowPartOptions(ent)
    if not inChopZone() then return false end
    local vehHash = getVehModelHash(ent)
    if not vehHash then return false end
    if anyFinishReadyForVeh(vehHash) then return false end
    return anyPartReadyForVeh(vehHash)
end

local function canShowFinishOption(ent)
    if not inChopZone() then return false end
    local vehHash = getVehModelHash(ent)
    if not vehHash then return false end
    return anyFinishReadyForVeh(vehHash)
end

-- ========= STATUS OPTION =========
local function showChopStatus(ent)
    if not inChopZone() then
        QBCore.Functions.Notify("Not in a chop zone.", "error")
        return
    end

    local vehHash = getVehModelHash(ent)
    if not vehHash then return end

    refreshPinned(function()
        refreshContracts(function(list)
            local all = contractsForVeh(vehHash, list)
            if #all == 0 then
                QBCore.Functions.Notify("No active contract targets this vehicle.", "error")
                return
            end

            -- Prefer pinned contract if it matches this vehicle
            local c = all[1]
            if pinnedId then
                for _, x in ipairs(all) do
                    if x.contractId == pinnedId then c = x break end
                end
            end

            local cd = secondsLeft(c.cooldownUntil)
            local partsDone = tonumber(c.partsDone) or 0
            local req = tonumber(c.requiredParts) or Config.RequiredPartsPerVehicle
            local remaining = tonumber(c.remaining) or 0

            if cd > 0 then
                QBCore.Functions.Notify(("Cooldown active (%ds). Lay low."):format(cd), "error")
                return
            end

            if partsDone >= req then
                QBCore.Functions.Notify(("Ready to FINISH chop. (Contract %s | Remaining cars: %d)"):format(c.contractId, remaining), "success")
            else
                QBCore.Functions.Notify(("Need %d more part(s) before you can finish. (Contract %s | Remaining cars: %d)"):format(req - partsDone, c.contractId, remaining), "primary")
            end
        end)
    end)
end

-- ========= MENU PICKER =========
local function chooseContract(matches, title, onPick)
    if pinnedId then
        for _, c in ipairs(matches) do
            if c.contractId == pinnedId then
                return onPick(c)
            end
        end
    end

    if #matches == 1 then
        return onPick(matches[1])
    end

    local menu = { { header = title, isMenuHeader = true } }

    table.sort(matches, function(a, b)
        if a.contractId == pinnedId then return true end
        if b.contractId == pinnedId then return false end
        return tostring(a.contractId) < tostring(b.contractId)
    end)

    for _, c in ipairs(matches) do
        local cd = secondsLeft(c.cooldownUntil)
        local pinTag = (pinnedId and c.contractId == pinnedId) and " [PINNED]" or ""
        local txt = ("Tier: %s | Parts: %d/%d | Remaining: %d | CD: %ds"):format(
            c.tier, c.partsDone, c.requiredParts, c.remaining or 0, cd
        )

        menu[#menu+1] = {
            header = ("Contract %s%s"):format(c.contractId, pinTag),
            txt = txt,
            params = { event = 'pc_chopshop:client:PickContract', args = { contract = c } }
        }
    end

    menu[#menu+1] = { header = "Close", params = { event = "qb-menu:client:closeMenu" } }
    _G.__PC_CHOPSHOP_ONPICK = onPick
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('pc_chopshop:client:PickContract', function(data)
    exports['qb-menu']:closeMenu()
    if _G.__PC_CHOPSHOP_ONPICK then
        _G.__PC_CHOPSHOP_ONPICK(data.contract)
    end
end)

-- ========= PHYSICAL CONSISTENCY CHECKS =========
local function doorAlreadyRemoved(veh, doorIndex)
    return IsVehicleDoorDamaged(veh, doorIndex)
end

local function wheelAlreadyRemoved(veh, tyreIndex)
    return IsVehicleTyreBurst(veh, tyreIndex, false)
end

-- ========= VISUALS =========
local function breakDoor(veh, doorIndex)
    SetVehicleDoorOpen(veh, doorIndex, false, false)
    Wait(200)
    SetVehicleDoorBroken(veh, doorIndex, true)
end

local function burstWheel(veh, tyreIndex)
    SetVehicleTyreBurst(veh, tyreIndex, true, 1000.0)
end

local function openAndBreak(veh, doorIndex)
    SetVehicleDoorOpen(veh, doorIndex, false, false)
    Wait(300)
    SetVehicleDoorBroken(veh, doorIndex, true)
end

-- ========= FLOWS =========
local function doRemovePartFlow(entity, contract, partType, slotIndex)
    local onCd, seconds = isOnCooldown(contract)
    if onCd then
        QBCore.Functions.Notify(("You're on cooldown. Wait %ds."):format(seconds), "error")
        return
    end

    -- physical consistency (client-side)
    if partType == 'door' then
        if doorAlreadyRemoved(entity, slotIndex) then
            QBCore.Functions.Notify("That door is already removed.", "error")
            return
        end
    elseif partType == 'wheel' then
        if wheelAlreadyRemoved(entity, slotIndex) then
            QBCore.Functions.Notify("That wheel is already removed.", "error")
            return
        end
    elseif partType == 'hood' then
        if doorAlreadyRemoved(entity, 4) then
            QBCore.Functions.Notify("The bonnet is already removed.", "error")
            return
        end
    elseif partType == 'trunk' then
        if doorAlreadyRemoved(entity, 5) then
            QBCore.Functions.Notify("The trunk is already removed.", "error")
            return
        end
    end

    local ms = 6500
    playDismantleAnim(ms)

    doProgress("Removing part...", ms, function(ok)
        stopAnim()
        if not ok then
            QBCore.Functions.Notify("Cancelled.", "error")
            return
        end

        -- visuals
        if partType == 'door' then breakDoor(entity, slotIndex)
        elseif partType == 'wheel' then burstWheel(entity, slotIndex)
        elseif partType == 'hood' then openAndBreak(entity, 4)
        elseif partType == 'trunk' then openAndBreak(entity, 5)
        end

        TriggerServerEvent(
            'pc_chopshop:server:RemovePart',
            contract.contractId,
            partType,
            slotIndex,
            getVehiclePlate(entity),
            getVehModelHash(entity)
        )

        cache.ts = 0
        refreshPinned(function() end)
    end)
end

local function doFinishFlow(entity, contract)
    local onCd, seconds = isOnCooldown(contract)
    if onCd then
        QBCore.Functions.Notify(("You're on cooldown. Wait %ds."):format(seconds), "error")
        return
    end

    TriggerServerEvent(
        'pc_chopshop:server:FinishChop',
        contract.contractId,
        getVehiclePlate(entity),
        getVehModelHash(entity)
    )

    cache.ts = 0
    refreshPinned(function() end)

    Wait(900)
    if DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteVehicle(entity)
    end
end

-- ========= VEHICLE THIRD-EYE =========
CreateThread(function()
    Wait(700)
    refreshPinned(function() end)

    exports['qb-target']:AddGlobalVehicle({
        options = {
            -- Always available in chop zone: explains why nothing else shows
            { icon="fas fa-info-circle", label="Chop Status", canInteract=function(ent) return inChopZone() end,
              action=function(ent) showChopStatus(ent) end },

            { icon="fas fa-door-open", label="Remove Door (Driver)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'door', 0) end)
            end },

            { icon="fas fa-door-open", label="Remove Door (Passenger)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'door', 1) end)
            end },

            { icon="fas fa-door-open", label="Remove Door (Rear Left)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'door', 2) end)
            end },

            { icon="fas fa-door-open", label="Remove Door (Rear Right)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'door', 3) end)
            end },

            { icon="fas fa-circle", label="Remove Wheel (Front Left)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'wheel', 0) end)
            end },

            { icon="fas fa-circle", label="Remove Wheel (Front Right)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'wheel', 1) end)
            end },

            { icon="fas fa-circle", label="Remove Wheel (Rear Left)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'wheel', 4) end)
            end },

            { icon="fas fa-circle", label="Remove Wheel (Rear Right)", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'wheel', 5) end)
            end },

            { icon="fas fa-car", label="Remove Bonnet", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'hood', 4) end)
            end },

            { icon="fas fa-box", label="Remove Trunk", canInteract=function(ent) return canShowPartOptions(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, false)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready for parts.", "error") end
                chooseContract(matches, "Apply to which contract?", function(c) doRemovePartFlow(ent, c, 'trunk', 5) end)
            end },

            { icon="fas fa-check", label="Finish Chop", canInteract=function(ent) return canShowFinishOption(ent) end, action=function(ent)
                local vehHash = getVehModelHash(ent)
                local matches = matchingContracts(vehHash, cache.list, true)
                if #matches == 0 then return QBCore.Functions.Notify("No matching contract ready to finish.", "error") end
                chooseContract(matches, "Finish which contract?", function(c) doFinishFlow(ent, c) end)
            end },
        },
        distance = 2.5
    })
end)

-- ========= NPC MENU =========
local openChoppingMenu

RegisterNetEvent('pc_chopshop:client:SellParts', function()
    TriggerServerEvent('pc_chopshop:server:SellParts')
end)

RegisterNetEvent('pc_chopshop:client:CashCert', function(certItem)
    TriggerServerEvent('pc_chopshop:server:CashCertificate', certItem)
end)

openChoppingMenu = function()
    QBCore.Functions.TriggerCallback('pc_chopshop:server:GetCertCounts', function(counts)
        counts = counts or {}

        local menu = {
            { header = "Chopping", isMenuHeader = true },
            {
                header = "Sell Chop Parts",
                txt = "Sell your door/wheel/bonnet/trunk parts (quality affects price)",
                params = { event = "pc_chopshop:client:SellParts" }
            },
        }

        local anyCert = (counts.easy or 0) > 0 or (counts.medium or 0) > 0 or (counts.hard or 0) > 0
        if anyCert then
            menu[#menu+1] = { header = "Cash Chop Certificate", isMenuHeader = true }

            if (counts.easy or 0) > 0 then
                menu[#menu+1] = {
                    header = ("Cash Certificate (Easy) x%d"):format(counts.easy),
                    txt = "Hand in your Easy certificate for payment",
                    params = { event = "pc_chopshop:client:CashCert", args = Config.Items.cert_easy }
                }
            end

            if (counts.medium or 0) > 0 then
                menu[#menu+1] = {
                    header = ("Cash Certificate (Medium) x%d"):format(counts.medium),
                    txt = "Hand in your Medium certificate for payment",
                    params = { event = "pc_chopshop:client:CashCert", args = Config.Items.cert_medium }
                }
            end

            if (counts.hard or 0) > 0 then
                menu[#menu+1] = {
                    header = ("Cash Certificate (Hard) x%d"):format(counts.hard),
                    txt = "Hand in your Hard certificate for payment",
                    params = { event = "pc_chopshop:client:CashCert", args = Config.Items.cert_hard }
                }
            end
        end

        menu[#menu+1] = { header = "Close", params = { event = "qb-menu:client:closeMenu" } }
        exports['qb-menu']:openMenu(menu)
    end)
end

CreateThread(function()
    if not (Config.Chopping and Config.Chopping.enabled) then return end
    Wait(900)

    for _, cfg in ipairs(Config.Chopping.NPCs or {}) do
        local model = loadModel(cfg.model)
        local ped = CreatePed(0, model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end

        spawnedScrapPeds[#spawnedScrapPeds+1] = ped

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = "fas fa-recycle",
                    label = "Chopping Services",
                    action = function()
                        openChoppingMenu()
                    end
                }
            },
            distance = Config.Chopping.targetDistance or 2.0
        })
    end
end)
