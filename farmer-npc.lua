-- Farmer NPC script for GrowSoft (Updated by Assistant)
print("(Loaded) Farmer NPC script for GrowSoft")

_G.FarmerNPCs = _G.FarmerNPCs or {}
_G.NextFarmerID = _G.NextFarmerID or 1

-- Helper to safely cast
local function safeNumber(val)
    return tonumber(val) or 0
end

-- Helper to check if a function exists on an object
local function hasFunction(obj, funcName)
    return type(obj[funcName]) == "function"
end

local FARMER_CONFIG_PATH = "config/farmer_npcs.json"

local function loadFarmers()
    if file and hasFunction(file, "read") then
        if hasFunction(file, "exists") and not file.exists(FARMER_CONFIG_PATH) then
            return -- File doesn't exist yet, ignore
        end
        local content = file.read(FARMER_CONFIG_PATH)
        if content and content ~= "" then
            _G.FarmerNPCs = json.decode(content) or {}
            local maxId = 0
            for w, npcs in pairs(_G.FarmerNPCs) do
                for _, n in pairs(npcs) do
                    if tonumber(n.id) and tonumber(n.id) > maxId then maxId = tonumber(n.id) end
                end
            end
            if maxId >= _G.NextFarmerID then _G.NextFarmerID = maxId + 1 end
        end
    end
end

local function saveFarmers()
    if file and hasFunction(file, "write") then
        -- Normalize all keys in memory to strings before saving to prevent mixed key crashes
        local normalized = {}
        for w, npcs in pairs(_G.FarmerNPCs) do
            normalized[tostring(w)] = {}
            for id, n in pairs(npcs) do
                -- Also normalize inventory/equipment to string keys
                local inv = {}
                for k, v in pairs(n.inventory or {}) do inv[tostring(k)] = v end
                n.inventory = inv
                
                local eq = {}
                for k, v in pairs(n.equipment or {}) do eq[tostring(k)] = v end
                n.equipment = eq
                
                normalized[tostring(w)][tostring(id)] = n
            end
        end
        -- Update _G.FarmerNPCs with the clean normalized table
        _G.FarmerNPCs = normalized
        
        local content = json.encode(_G.FarmerNPCs)
        file.write(FARMER_CONFIG_PATH, content)
    end
end

loadFarmers()

local function setBlockSafe(w, tx, ty, itemID)
    local tile = w:getTile(tx, ty)
    if tile then
        w:setTileForeground(tile, itemID, 1)
    end
    return true
end

local function giveOrDropItems(world, player, npc, itemID, amount, forceDrop)
    local amountLeft = math.floor(amount)
    if amountLeft <= 0 then return 0, 0 end
    
    local dropX = npc.x * 32 -- Convert tile coordinate to pixels!
    local dropY = npc.y * 32 -- Convert tile coordinate to pixels!
    local droppedTotal = 0
    
    if not forceDrop and hasFunction(player, "changeItem") and hasFunction(player, "getItemAmount") then
        while amountLeft > 0 do
            local toGive = math.min(amountLeft, 200)
            local preAmt = player:getItemAmount(itemID) or 0
            player:changeItem(itemID, toGive, 0)
            local postAmt = player:getItemAmount(itemID) or 0
            local actuallyGiven = postAmt - preAmt
            
            if actuallyGiven > 0 then
                amountLeft = amountLeft - actuallyGiven
            end
            
            if actuallyGiven < toGive then
                break -- inventory full
            end
        end
    end
    
    droppedTotal = amountLeft
    while amountLeft > 0 do
        local dropAmt = math.min(amountLeft, 250)
        if hasFunction(world, "spawnItem") then
            world:spawnItem(dropX, dropY, itemID, dropAmt)
        end
        amountLeft = amountLeft - dropAmt
    end
    
    return math.floor(amount) - droppedTotal, droppedTotal
end

function spawnFarmerNPC(world, player, expireTime)
    local owner = world:getOwner()
    if not owner or owner:getUserID() ~= player:getUserID() then
        player:onConsoleMessage("`4You can only spawn a Farmer in a locked world that you own!``")
        return
    end

    local x = player:getBlockPosX()
    local y = player:getBlockPosY()
    local worldName = world:getName()
    
    if not _G.FarmerNPCs[worldName] then
        _G.FarmerNPCs[worldName] = {}
    end
    
    local npcID = _G.NextFarmerID
    _G.NextFarmerID = _G.NextFarmerID + 1
    
    local npc = {
        id = npcID,
        owner = player:getName(),
        spawnerId = player:getUserID(),
        x = x,
        y = y,
        active = false,
        inventory = {}, -- itemID = amount
        equipment = {}, -- itemID = amount
        farmTarget = 0, -- 0 means nothing
        farmRarity = 0,
        tickCounter = 0,
        earnedGems = 0,
        earnedSeeds = {}, -- seedItemID = amount
        seedProgress = 0, -- tracks fraction out of 3
        currentHits = 0,
        state = "IDLE", -- IDLE, PLACING, BREAKING
        expireTime = expireTime
    }
    
    -- Robust visual spawner
    local function spawnVisual(w, tx, ty, itemID)
        -- Removing the mannequin block so there aren't 2 visuals overlapping.
        -- We just spawn the player-like NPC visual.
        -- Spawn the visual NPC overlay that looks like the player
        local npcName = "Farmer_" .. npc.owner
        local bot = nil
        if hasFunction(w, "createNPC") then
            bot = w:createNPC(npcName, tx * 32, ty * 32)
        elseif hasFunction(w, "spawnNPC") then
            w:spawnNPC(25, tx * 32, ty * 32, npcID, npcName)
        end
        
        -- Clothe the NPC to match player
        if bot and hasFunction(w, "setClothing") then
            for i = 0, 9 do
                local c = player:getClothingItemID(i)
                if c and c > 0 then
                    w:setClothing(bot, c)
                    npc.equipment[tostring(i)] = c
                end
            end
        end
    end
    
    spawnVisual(world, x, y, 1420) -- 1420 is Mannequin
    
    _G.FarmerNPCs[worldName][tostring(npcID)] = npc
    saveFarmers()
    player:onConsoleMessage("`2Spawned Auto-Farmer NPC with ID: " .. npcID)
end

local function processFarmerOffline(world, npc)
    local now = os.time()
    local isExpired = false
    local tickTime = now
    
    -- Fast exit if already despawned in memory
    if npc.isDespawning then return end

    if npc.expireTime and now >= npc.expireTime then
        isExpired = true
        tickTime = npc.expireTime
    end

    if npc.active then
        if not npc.lastHitTime then npc.lastHitTime = tickTime end
        local elapsed = tickTime - npc.lastHitTime
        if elapsed < 0 then elapsed = 0 end -- Prevent time drift/negative elapsed bugs
        if elapsed >= 1 then
            npc.lastHitTime = tickTime
            
            if npc.farmTarget > 0 and (npc.inventory[tostring(npc.farmTarget)] or 0) > 0 then
                if not npc.farmRarity or npc.farmRarity <= 1 then
                    local r = 1
                    local itm = _G.getItem and _G.getItem(npc.farmTarget) or (getItem and getItem(npc.farmTarget))
                    if itm and hasFunction(itm, "getRarity") then
                        r = tonumber(itm:getRarity()) or 1
                    end
                    npc.farmRarity = r
                end
                
                -- 2 hits per second elapsed
                npc.currentHits = (npc.currentHits or 0) + (2 * elapsed)
                
                if npc.currentHits >= 8 then
                    local blocksBroken = math.floor(npc.currentHits / 8)
                    npc.currentHits = npc.currentHits % 8
                    
                    local available = npc.inventory[tostring(npc.farmTarget)]
                    if blocksBroken > available then
                        blocksBroken = available
                    end
                    
                    npc.inventory[tostring(npc.farmTarget)] = available - blocksBroken
                    npc.earnedGems = (npc.earnedGems or 0) + (blocksBroken * (npc.farmRarity or 1))
                    
                    npc.seedProgress = (npc.seedProgress or 0) + blocksBroken
                    if npc.seedProgress >= 3 then
                        local newSeeds = math.floor(npc.seedProgress / 3)
                        npc.seedProgress = npc.seedProgress % 3
                        npc.earnedSeeds = npc.earnedSeeds or {}
                        local seedID = tostring(npc.farmTarget + 1)
                        npc.earnedSeeds[seedID] = (npc.earnedSeeds[seedID] or 0) + newSeeds
                    end
                end
            else
                npc.currentHits = 0 -- Reset hits if out of blocks
            end
        end
    else
        npc.lastHitTime = tickTime
    end

    if isExpired then
        npc.isDespawning = true
        -- Despawn Protocol
        local wName = world:getName()
        
        -- Drop blocks and CLEAR memory to prevent doubling!
        if npc.farmTarget > 0 then
            local stored = npc.inventory[tostring(npc.farmTarget)] or 0
            if stored > 0 then
                giveOrDropItems(world, nil, npc, npc.farmTarget, stored, true)
                npc.inventory[tostring(npc.farmTarget)] = 0
            end
        end
        
        -- Drop seeds and CLEAR memory
        if npc.earnedSeeds then
            for sID, sAmt in pairs(npc.earnedSeeds) do
                if tonumber(sAmt) > 0 then
                    giveOrDropItems(world, nil, npc, tonumber(sID), tonumber(sAmt), true)
                    npc.earnedSeeds[sID] = 0
                end
            end
        end
        
        -- Drop gems fallback and CLEAR memory
        if (npc.earnedGems or 0) > 0 then
            local ownerOnline = false
            if type(getPlayerByName) == "function" or hasFunction(getPlayerByName, "call") then
                local found = getPlayerByName(npc.owner)
                if found and #found > 0 then
                    for _, p in ipairs(found) do
                        if p:getCleanName() == npc.owner then
                            p:addGems(npc.earnedGems, 0, 1)
                            p:onConsoleMessage("`2Received " .. npc.earnedGems .. " gems from an expired Farmer NPC.``")
                            ownerOnline = true
                            break
                        end
                    end
                end
            end
            if not ownerOnline then
                -- Drop gems as item 112
                giveOrDropItems(world, nil, npc, 112, npc.earnedGems, true)
            end
            npc.earnedGems = 0
        end
        
        -- Remove NPC bot from world
        if hasFunction(world, "getAllNPC") and hasFunction(world, "removeNPC") then
            local allNPCs = world:getAllNPC() or {}
            for _, bot in pairs(allNPCs) do
                local bName = ""
                if hasFunction(bot, "getName") then bName = bot:getName() or "" end
                if string.find(bName, "Farmer_") then
                    local bx = math.floor(bot:getPosX() / 32)
                    local by = math.floor(bot:getPosY() / 32)
                    if bx == npc.x and math.abs(by - npc.y) <= 5 then
                        world:removeNPC(bot)
                    end
                end
            end
        end
        
        -- Delete from DB
        if _G.FarmerNPCs[wName] then
            for k, v in pairs(_G.FarmerNPCs[wName]) do
                if v == npc then
                    _G.FarmerNPCs[wName][k] = nil
                    break
                end
            end
            saveFarmers()
        end
        return
    end
end

function openFarmerDialog(player, npc)
    local w = player:getWorld()
    processFarmerOffline(w, npc)
    if not npc.spawnerId then
        if w and hasFunction(w, "getOwner") then
            local owner = w:getOwner()
            if owner then npc.spawnerId = owner:getUserID() end
        end
    end

    if npc.spawnerId and npc.spawnerId ~= player:getUserID() and not player:hasRole(51) then
        player:onConsoleMessage("`4This Farmer belongs to someone else! You cannot use it.")
        return
    end

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wFarmer NPC Manager``|left|25|")
    table.insert(d, "add_smalltext|Owner: `2" .. npc.owner .. "``|")
    table.insert(d, "add_smalltext|Status: " .. (npc.active and "`2Active" or "`4Inactive") .. "|")
    if npc.farmTarget > 0 then
        table.insert(d, "add_label_with_icon|small|Target Block (ID: " .. npc.farmTarget .. ")|left|" .. npc.farmTarget .. "|")
    else
        table.insert(d, "add_label_with_icon|small|Target Block: None|left|0|")
    end
    
    -- Inventory overview
    local totalBlocks = 0
    for id, amt in pairs(npc.inventory) do
        totalBlocks = totalBlocks + safeNumber(amt)
    end
    table.insert(d, "add_smalltext|Stored Blocks: " .. totalBlocks .. "|")
    
    local rarity = npc.farmRarity or 0
    local totalSeeds = 0
    if npc.earnedSeeds then
        for _, amt in pairs(npc.earnedSeeds) do
            totalSeeds = totalSeeds + safeNumber(amt)
        end
    end
    
    table.insert(d, "add_smalltext|Gems Earned: `2" .. (npc.earnedGems or 0) .. "``|")
    table.insert(d, "add_smalltext|Seeds Earned: `2" .. totalSeeds .. "``|")
    table.insert(d, "add_smalltext|Est. Earnings: `2" .. (900 * rarity) .. " Gems/Hour``|")
    
    table.insert(d, "add_spacer|small|")
    local timeLeft = (npc.expireTime or 0) - os.time()
    if timeLeft < 0 then timeLeft = 0 end
    local days = math.floor(timeLeft / 86400)
    local hours = math.floor((timeLeft % 86400) / 3600)
    local mins = math.floor((timeLeft % 3600) / 60)
    local secs = timeLeft % 60
    local timeStr = string.format("%dd %dh %dm %ds", days, hours, mins, secs)
    
    table.insert(d, "add_smalltext|`oTime Left: `2" .. timeStr .. "``|left|")
    table.insert(d, "add_button|btn_farmer_take_" .. npc.id .. "|Take Blocks|noflags|0|0|")
    if npc.active then
        table.insert(d, "add_button|btn_farmer_toggle_" .. npc.id .. "|`4Stop Farming``|noflags|0|0|")
    else
        table.insert(d, "add_button|btn_farmer_toggle_" .. npc.id .. "|`2Start Farming``|noflags|0|0|")
    end
    
    table.insert(d, "add_button|btn_farmer_claim_" .. npc.id .. "|Claim Gems|noflags|0|0|")
    table.insert(d, "add_button|btn_farmer_claimseeds_" .. npc.id .. "|Claim Seeds|noflags|0|0|")
    
    table.insert(d, "add_button|btn_farmer_add_" .. npc.id .. "|Add Blocks|noflags|0|0|")
    table.insert(d, "add_button|btn_farmer_remove_" .. npc.id .. "|`4Remove Farmer``|noflags|0|0|")
    table.insert(d, "add_button|btn_farmer_close|Close|noflags|0|0|")
    table.insert(d, "end_dialog|farmer_manager|Cancel||")
    
    local dialogStr = table.concat(d, "\n") .. "\n"
    player:onDialogRequest(dialogStr)
end

local farmerCommandData = {
    command = "farmer",
    roleRequired = 3, -- Moderator
    description = "Spawn a Farmer NPC"
}

if type(registerLuaCommand) == "function" then
    registerLuaCommand(farmerCommandData)
end

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == "farmer" then
        local owner = world:getOwner()
        if not owner or owner:getUserID() ~= player:getUserID() then
            player:onConsoleMessage("`4You can only spawn a Farmer in a locked world that you own!``")
            return true
        end
        player:onDialogRequest(table.concat({
            "set_default_color|`o",
            "add_label_with_icon|big|`wPurchase Farmer NPC``|left|1420|",
            "add_spacer|small|",
            "add_smalltext|`oSelect a duration to spawn the Farmer NPC.``|",
            "add_smalltext|`oLocks will be automatically converted if you don't have enough WLs.``|",
            "add_spacer|small|",
            "add_button|buy_farmer_10s|`w10 Seconds (1 WL)``|noflags|0|0|",
            "add_button|buy_farmer_30m|`w30 Minutes (180 WL)``|noflags|0|0|",
            "add_button|buy_farmer_1h|`w1 Hour (350 WL)``|noflags|0|0|",
            "add_button|buy_farmer_6h|`w6 Hours (2000 WL)``|noflags|0|0|",
            "add_button|buy_farmer_12h|`w12 Hours (3500 WL)``|noflags|0|0|",
            "add_button|buy_farmer_1d|`w1 Day (6500 WL)``|noflags|0|0|",
            "end_dialog|farmer_purchase|Cancel||"
        }, "\n") .. "\n")
        return true
    end
    return false
end)

onPlayerWrenchCallback(function(world, player, wrenchingPlayer)
    -- wrenchingPlayer can be an NPC
    if hasFunction(wrenchingPlayer, "getType") and safeNumber(wrenchingPlayer:getType()) == 25 then
        local wName = world:getName()
        if _G.FarmerNPCs[wName] then
            for id, npc in pairs(_G.FarmerNPCs[wName]) do
            processFarmerOffline(world, npc)
                -- Approximate matching if we don't have direct access
                if math.abs(npc.x - wrenchingPlayer:getBlockPosX()) <= 1 and math.abs(npc.y - wrenchingPlayer:getBlockPosY()) <= 1 then
                    openFarmerDialog(player, npc)
                    return true
                end
            end
        end
    end
    return false
end)

onTileWrenchCallback(function(world, player, tile)
    local wName = world:getName()
    if _G.FarmerNPCs[wName] then
        for id, npc in pairs(_G.FarmerNPCs[wName]) do
            processFarmerOffline(world, npc)
            local tileGridX = math.floor(tile:getPosX() / 32)
            local tileGridY = math.floor(tile:getPosY() / 32)
            if tileGridX == npc.x and tileGridY == npc.y then
                openFarmerDialog(player, npc)
                return true
            end
        end
    end
    return false
end)
onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"]
    local button = data["buttonClicked"]

    if dialogName == "farmer_purchase" then
        if string.match(button or "", "^buy_farmer_") then
            -- Verify world ownership first
            local owner = world:getOwner()
            if not owner or owner:getUserID() ~= player:getUserID() then
                player:onConsoleMessage("`4You can only spawn a Farmer in a locked world that you own!``")
                return true
            end
            
            local wlCost = 50
            local duration = 0
            if button == "buy_farmer_10s" then wlCost = 1; duration = 10
            elseif button == "buy_farmer_30m" then wlCost = 180; duration = 1800
            elseif button == "buy_farmer_1h" then wlCost = 350; duration = 3600
            elseif button == "buy_farmer_6h" then wlCost = 2000; duration = 21600
            elseif button == "buy_farmer_12h" then wlCost = 3500; duration = 43200
            elseif button == "buy_farmer_1d" then wlCost = 6500; duration = 86400
            else return true end
            
            local wlCount = player:getItemAmount(242)
            local dlCount = player:getItemAmount(1796)
            local bglCount = player:getItemAmount(7188)
            
            local totalWL = wlCount + (dlCount * 100) + (bglCount * 10000)
            if totalWL < wlCost then
                player:onConsoleMessage("`4You do not have enough Locks! You need 50 World Locks.``")
                return true
            end
            
            local wlNeeded = wlCost - wlCount
            if wlNeeded > 0 then
                -- Need to convert DL or BGL
                local dlNeeded = math.ceil(wlNeeded / 100)
                if dlNeeded > dlCount then
                    -- Convert BGL to DL
                    local bglNeeded = math.ceil((dlNeeded - dlCount) / 100)
                    player:changeItem(7188, -bglNeeded, 0)
                    player:changeItem(1796, bglNeeded * 100, 0)
                    dlCount = dlCount + (bglNeeded * 100)
                    player:onConsoleMessage("`oConverted " .. bglNeeded .. " Blue Gem Lock(s) to Diamond Locks.``")
                end
                
                -- Now convert DL to WL
                player:changeItem(1796, -dlNeeded, 0)
                player:changeItem(242, dlNeeded * 100, 0)
                player:onConsoleMessage("`oConverted " .. dlNeeded .. " Diamond Lock(s) to World Locks.``")
            end
            
            -- Deduct WL cost
            player:changeItem(242, -wlCost, 0)
            
            -- Spawn Farmer
            local expireTime = os.time() + duration
            spawnFarmerNPC(world, player, expireTime)
        end
        return true
    end

    if dialogName == "farmer_manager" then
        if not button or button == "" or button == "btn_farmer_close" then
            return true
        end
        
        local wName = world:getName()
        if not _G.FarmerNPCs[wName] then return true end
        
        for id, npc in pairs(_G.FarmerNPCs[wName]) do
            processFarmerOffline(world, npc)
            if button == "btn_farmer_toggle_" .. id then
                if not npc.active then
                    -- Trying to turn ON
                    if npc.farmTarget == 0 or (npc.inventory[tostring(npc.farmTarget)] or 0) <= 0 then
                        player:onConsoleMessage("`4You must add blocks to the Farmer before starting it!``")
                        return true
                    end
                end
                npc.active = not npc.active
                player:onConsoleMessage("Farmer NPC is now " .. (npc.active and "`2Active" or "`4Inactive"))
                saveFarmers()
                openFarmerDialog(player, npc)
                return true
            elseif button == "btn_farmer_claim_" .. id then
                if (npc.earnedGems or 0) > 0 then
                    local given = false
                    if hasFunction(player, "addGems") then
                        player:addGems(npc.earnedGems, 0, 1)
                        given = true
                    end
                    if given then
                        player:onConsoleMessage("`2Claimed " .. npc.earnedGems .. " gems from Farmer!")
                        npc.earnedGems = 0
                        saveFarmers()
                    else
                        player:onConsoleMessage("`4Failed to claim gems.")
                    end
                else
                    player:onConsoleMessage("`4Farmer hasn't earned any gems yet!")
                end
                return true
            elseif button == "btn_farmer_claimseeds_" .. id then
                local givenAny = false
                local totalDropped = 0
                if npc.earnedSeeds then
                    for sID, sAmt in pairs(npc.earnedSeeds) do
                        if safeNumber(sAmt) > 0 then
                            local given, dropped = giveOrDropItems(world, player, npc, tonumber(sID), safeNumber(sAmt), true)
                            if given > 0 or dropped > 0 then
                                givenAny = true
                                totalDropped = totalDropped + dropped
                            end
                        end
                    end
                end
                if givenAny then
                    npc.earnedSeeds = {}
                    saveFarmers()
                    if totalDropped > 0 then
                        player:onConsoleMessage("`2Seeds dropped directly into the world (" .. totalDropped .. " total).")
                    else
                        player:onConsoleMessage("`2Claimed all seeds from Farmer!")
                    end
                else
                    player:onConsoleMessage("`4Farmer hasn't earned any seeds yet!")
                end
                return true
            elseif button == "btn_farmer_take_" .. id then
                if npc.farmTarget > 0 then
                    local stored = npc.inventory[tostring(npc.farmTarget)] or 0
                    if stored > 0 then
                        local given, dropped = giveOrDropItems(world, player, npc, npc.farmTarget, stored, false)
                        
                        if dropped > 0 then
                            player:onConsoleMessage("`2Retrieved blocks! Inventory full, dropped " .. dropped .. " on the ground.")
                        else
                            player:onConsoleMessage("`2Successfully retrieved " .. given .. " blocks.")
                        end
                        
                        npc.inventory[tostring(npc.farmTarget)] = 0
                        npc.farmTarget = 0
                        npc.farmRarity = 1
                        npc.state = "IDLE"
                        saveFarmers()
                        openFarmerDialog(player, npc)
                    else
                        player:onConsoleMessage("`4Farmer doesn't have any blocks stored.")
                    end
                end
                openFarmerDialog(player, npc)
                return true
            elseif button == "btn_farmer_add_" .. id then
                player:onDialogRequest(table.concat({
                    "set_default_color|`o",
                    "add_label_with_icon|small|Add Blocks|left|25|",
                    "add_item_picker|item_id|Pick Block to Add|Choose a block from your inventory!|",
                    "add_text_input|amount|Quantity|1|5|",
                    "add_button|submit_add|Add|noflags|0|0|",
                    "end_dialog|farmer_add_input_" .. id .. "|Cancel||"
                }, "\n") .. "\n")
                return true
            elseif button == "btn_farmer_remove_" .. id then
                player:onDialogRequest(table.concat({
                    "set_default_color|`o",
                    "add_label_with_icon|big|`4Remove Farmer?|left|32|",
                    "add_smalltext|Are you sure you want to remove this Farmer?|left|",
                    "add_smalltext|`4Stored blocks and seeds will be dropped on the ground!``|left|",
                    "add_smalltext|`2Unclaimed gems will be added to your balance.``|left|",
                    "add_spacer|small|",
                    "add_button|btn_farmer_confirmremove_" .. id .. "|`4Confirm Remove|noflags|0|0|",
                    "add_button|btn_farmer_cancelremove_" .. id .. "|`2Cancel|noflags|0|0|",
                    "end_dialog|farmer_manager|Cancel||"
                }, "\n") .. "\n")
                return true
            elseif button == "btn_farmer_cancelremove_" .. id then
                openFarmerDialog(player, npc)
                return true
            elseif button == "btn_farmer_confirmremove_" .. id then
                if npc.farmTarget > 0 then
                    local stored = npc.inventory[tostring(npc.farmTarget)] or 0
                    if stored > 0 then
                        giveOrDropItems(world, player, npc, npc.farmTarget, stored, true)
                    end
                end
                
                if npc.earnedSeeds then
                    for sID, sAmt in pairs(npc.earnedSeeds) do
                        if safeNumber(sAmt) > 0 then
                            giveOrDropItems(world, player, npc, tonumber(sID), safeNumber(sAmt), true)
                        end
                    end
                end
                
                if npc.earnedGems > 0 then
                    player:addGems(npc.earnedGems, 0, 1)
                    player:onConsoleMessage("`2Received " .. npc.earnedGems .. " gems from the removed Farmer.")
                end
                
                if hasFunction(world, "getAllNPC") and hasFunction(world, "removeNPC") then
                    local allNPCs = world:getAllNPC() or {}
                    for _, bot in pairs(allNPCs) do
                        local bName = ""
                        if hasFunction(bot, "getName") then bName = bot:getName() or "" end
                        if string.find(bName, "Farmer_") then
                            local bx = math.floor(bot:getPosX() / 32)
                            local by = math.floor(bot:getPosY() / 32)
                            if bx == npc.x and math.abs(by - npc.y) <= 5 then
                                world:removeNPC(bot)
                            end
                        end
                    end
                end
                
                _G.FarmerNPCs[wName][id] = nil
                saveFarmers()
                player:onConsoleMessage("`2Removed Farmer NPC.")
                return true
            end
        end
        
        return true
    end
    
    -- Handle Add Input
    if dialogName and string.match(dialogName, "^farmer_add_input_(%d+)") then
        local idStr = string.match(dialogName, "^farmer_add_input_(%d+)")
        local id = tostring(idStr)
        local wName = world:getName()
        if _G.FarmerNPCs[wName] and _G.FarmerNPCs[wName][id] then
            local npc = _G.FarmerNPCs[wName][id]
            processFarmerOffline(world, npc)
            local itemID = safeNumber(data["item_id"])
            local amount = safeNumber(data["amount"])
            
            if npc.farmTarget > 0 and itemID ~= npc.farmTarget and itemID > 0 then
                player:onConsoleMessage("`4Farmer is currently targeting Block ID " .. npc.farmTarget .. ". Take those blocks out first!``")
                return true
            end
            
            if itemID <= 0 then
                player:onConsoleMessage("`4You must select a block from the item picker!``")
                return true
            end
            if amount <= 0 then
                player:onConsoleMessage("`4Amount must be greater than 0!``")
                return true
            end
            
            if itemID > 0 and amount > 0 then
                -- Verify it's a block
                local isBlock = true
                if itemID % 2 ~= 0 then
                    isBlock = false -- Odd IDs are seeds/non-blocks in GT
                end
                
                -- Extra hardcoded check for locks and tools
                local invalidIDs = {[18]=true, [32]=true, [202]=true, [204]=true, [206]=true, [242]=true, [1796]=true, [7188]=true}
                if invalidIDs[itemID] then isBlock = false end
                
                if not isBlock then
                    player:onConsoleMessage("`4You can only add valid blocks! No seeds, clothes, tools, or locks allowed.")
                    return true
                end

                local currentAmount = 0
                if hasFunction(player, "getItemAmount") then
                    currentAmount = player:getItemAmount(itemID)
                end
                
                if currentAmount >= amount then
                    if hasFunction(player, "changeItem") then
                        player:changeItem(itemID, -amount, 0) -- 0 ensures it takes from main inventory
                    end
                    npc.inventory[tostring(itemID)] = (npc.inventory[tostring(itemID)] or 0) + amount
                    if npc.farmTarget == 0 then
                        npc.farmTarget = itemID
                        local r = 1
                        local itm = _G.getItem and _G.getItem(itemID) or (getItem and getItem(itemID))
                        if itm and hasFunction(itm, "getRarity") then
                            r = tonumber(itm:getRarity()) or 1
                        end
                        npc.farmRarity = r
                    end
                    saveFarmers()
                    player:onConsoleMessage("`2Added " .. amount .. " blocks to Farmer.")
                else
                    player:onConsoleMessage("`4You don't have enough of that item! You only have " .. currentAmount .. ".")
                end
            end
        end
        return true
    end

    return false
end)

onWorldLoaded(function(world)
    local wName = world:getName()
    if not _G.FarmerNPCs[wName] then return end
    
    -- When a world loads, ensure physical NPCs exist for this world's farmers
    if hasFunction(world, "getAllNPC") then
        local allNPCs = world:getAllNPC() or {}
        for id, npc in pairs(_G.FarmerNPCs[wName]) do
            processFarmerOffline(world, npc)
            local hasPhysical = false
            for _, bot in pairs(allNPCs) do
                local bName = ""
                if hasFunction(bot, "getName") then bName = bot:getName() or "" end
                
                if string.find(bName, "Farmer_") then
                    local bx = math.floor(bot:getPosX() / 32)
                    local by = math.floor(bot:getPosY() / 32)
                    
                    -- Gravity causes bots to fall. Check exact X, and within 5 tiles Y
                    if bx == npc.x and math.abs(by - npc.y) <= 5 then
                        hasPhysical = true
                        break
                    end
                end
            end
            if not hasPhysical then
                if hasFunction(world, "createNPC") then
                    local bot = world:createNPC("Farmer_" .. (npc.owner or "Unknown"), npc.x * 32, npc.y * 32)
                    if bot and hasFunction(world, "setClothing") and npc.equipment then
                        for i = 0, 9 do
                            local c = npc.equipment[tostring(i)]
                            if c and tonumber(c) > 0 then
                                world:setClothing(bot, tonumber(c))
                            end
                        end
                    end
                end
            end
        end
    end
end)
