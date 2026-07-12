-- Tile Wrench Example script
print("(Loaded) Tile Wrench Example script for GrowSoft")

onTileWrenchCallback(function(world, player, tile)
    local tileID = tile:getTileID();
    if tileID == 4358 then -- Sales-Man Standee
        local itemObj = getItem(tileID)
        player:onConsoleMessage("You have wrenched " .. itemObj:getName())
        return true
    end
    return false
end)
