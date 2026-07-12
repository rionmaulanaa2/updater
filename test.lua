local npc = {
    active = true,
    lastHitTime = 1000,
    expireTime = 1010,
    farmTarget = 2,
    inventory = { ["2"] = 100 },
    currentHits = 0,
    earnedGems = 0,
    seedProgress = 0,
    earnedSeeds = {},
    isDespawning = false,
    x = 1, y = 1
}

local droppedBlocks = 0
local droppedSeeds = 0

local function giveOrDropItems(world, player, npc, itemID, amount, forceDrop)
    if itemID == npc.farmTarget then
        droppedBlocks = droppedBlocks + amount
    else
        droppedSeeds = droppedSeeds + amount
    end
    return 0, amount
end

local function processFarmerOffline(npc, nowTime)
    local now = nowTime
    local isExpired = false
    local tickTime = now
    
    if npc.isDespawning then return end

    if npc.expireTime and now >= npc.expireTime then
        isExpired = true
        tickTime = npc.expireTime
    end

    if npc.active then
        if not npc.lastHitTime then npc.lastHitTime = tickTime end
        local elapsed = tickTime - npc.lastHitTime
        if elapsed >= 1 then
            npc.lastHitTime = tickTime
            
            if npc.farmTarget > 0 and (npc.inventory[tostring(npc.farmTarget)] or 0) > 0 then
                npc.currentHits = (npc.currentHits or 0) + (2 * elapsed)
                if npc.currentHits >= 8 then
                    local blocksBroken = math.floor(npc.currentHits / 8)
                    npc.currentHits = npc.currentHits % 8
                    local available = npc.inventory[tostring(npc.farmTarget)]
                    if blocksBroken > available then blocksBroken = available end
                    npc.inventory[tostring(npc.farmTarget)] = available - blocksBroken
                end
            end
        end
    end

    if isExpired then
        npc.isDespawning = true
        if npc.farmTarget > 0 then
            local stored = npc.inventory[tostring(npc.farmTarget)] or 0
            if stored > 0 then
                giveOrDropItems(nil, nil, npc, npc.farmTarget, stored, true)
                npc.inventory[tostring(npc.farmTarget)] = 0
            end
        end
    end
end

-- Simulate ticks
processFarmerOffline(npc, 1005)
processFarmerOffline(npc, 1015)

print("Inventory left: " .. (npc.inventory["2"] or 0))
print("Dropped blocks: " .. droppedBlocks)
