-- Block Drops Example script
print("(Loaded) Block Drops Example script for GrowSoft")

-- Uncomment this part of code if u want it to have any effect

-- math.randomseed(os.time())
 
-- onTileBreakCallback(function(world, player, tile)
    -- local tileID = tile:getTileID();
    -- if tileID == 2 then -- Dirt
        -- if math.random(1, 100) <= 50 then -- Give Dirt 50% Chance to drop Rock
            -- world:spawnItem(tile:getPosX(), tile:getPosY(), 10, 1)
            -- If you wanna get player position: player:getPosX() player:getPosY()
            -- player:onTalkBubble(player:getNetID(), "Wow u found rock!", 0)
            -- player:onTextOverlay("Wow u found rock!")
            -- return true -- Prevent the default action
        -- end
        -- return false -- Dont prevent the default action of Dirt dropping gems and seeds / xp
    -- end
    -- return false
-- end)
