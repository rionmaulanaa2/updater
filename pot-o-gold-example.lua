-- Pot-O-Gold Gems Drop Example script
print("(Loaded) Pot-O-Gold Gems Drop Example script for GrowSoft")

math.randomseed(os.time())

onTileBreakCallback(function(world, player, tile)
    local tileID = tile:getTileID();
    if tileID == 542 then -- Pot O' Gold
        world:onLoot(player, tile, math.random(99, 100))
        world:addXP(player, tile:getTileItem():getRarity())
        return true
    end
    return false
end)
