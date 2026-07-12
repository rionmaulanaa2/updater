-- Experimental Blocks Example script
print("(Loaded) Experimental Blocks Example script for GrowSoft")

math.randomseed(os.time())

onTileBreakCallback(function(world, player, tile)
    local tileID = tile:getTileID();
    if tileID == 4 then
        local num = math.random(1, 4)
        if num == 1 then
            world:onCreateChatBubble(tile:getPosX() + 10, tile:getPosY() + 15, "`4Lava died``", 0)
            return true
        elseif num == 2 then
            world:onCreateExplosion(tile:getPosX(), tile:getPosY(), 5, 2) -- 5 is radius, 2 is power
            return true
        end
        return false
    end
    return false
end)
