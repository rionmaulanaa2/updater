-- Starter Pack script
print("(Loaded) Starter Pack script for GrowSoft")

local starterItems = {
    {itemID = 9640, itemCount = 1},
    {itemID = 954, itemCount = 50},
    {itemID = 98, itemCount = 1},
    {itemID = 818, itemCount = 1}
}

local starterGems = 5000

onPlayerRegisterCallback(function(world, player)
    for i, item in ipairs(starterItems) do
        -- Show effect
        world:useItemEffect(player:getNetID(), item.itemID, 0, 250 * (i + 1))
        -- Add the reward to inventory
        if not player:changeItem(item.itemID, item.itemCount, 0) then  -- 0 means add to inv, 1 means to backpack
            -- Add the reward to backpack (always success)
            player:changeItem(item.itemID, item.itemCount, 1)
        end
    end
    player:addGems(starterGems, 1, 0) -- gems, 1 if insta set (no anim), 1 if count towards quests
    -- Example removing gems
    if player:removeGems(25, 0, 0) then
        player:onConsoleMessage("Oh no! I lost 25 gems!")
    end -- If it fails that means player does not have enough gems
    player:onTalkBubble(player:getNetID(), "Received the Starter Pack! You currently have " .. player:getGems() .. " Gems!", 1)
end)
