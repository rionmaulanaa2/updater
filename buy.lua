-- Buy script
print("(Loaded) Buy script for GrowSoft")

function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function formatNum(num)
    local formattedNum = tostring(num)
    formattedNum = formattedNum:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    formattedNum = formattedNum:gsub("^,", "")
    return formattedNum
end

local buyItems = {}
local searchableItems = ""

function setupBuyItems()
    -- You can also change prices of items, for example:
    getItem(1782):setPrice(90000) -- Change Dragon Of Legend price to 90000 World Locks

    buyItems = {}
    print("Loading buy items")
    local searchData = {}
    local totalItems = getItemsCount()
    for i = 0, totalItems - 1, 2 do -- Skips Seeds
        local item = getItem(i)
        local itemPrice = item:getPrice() -- It returns real-gt item price
        if itemPrice ~= 0 and not item:isObtainable() then -- If the item has price and is NOT obtainable from any other ways
            table.insert(buyItems, item) -- Add it to buy items list
            table.insert(searchData, i .. "," .. itemPrice * 2000) -- Add it to the search dialog system
        end
    end
    print("Total buy items: " .. formatNum(#buyItems))
    searchableItems = table.concat(searchData, ",")
end

setupBuyItems()

Roles = {
    ROLE_NONE = 0
}

local buyCommandData = {
    command = "buy",
    roleRequired = Roles.ROLE_NONE,
    description = "This command allows you to buy `$items`` for gems!"
}

registerLuaCommand(buyCommandData) -- This is just for some places such as role descriptions and help

function onBuyMenu(player, searchStr)
    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`wPurchase Items & Blocks``|left|6016|\n" ..
        "add_smalltext|Welcome, here you can purchase various items and blocks for gems, there are total of `$" .. formatNum(#buyItems) .. "`` items available!|left|\n" ..
        "add_smalltext|Search for the item you're looking for, if its available it will show up!|left|\n" ..
        "add_spacer|small|\n" ..
        "add_text_input|searchFixedName|Search by Name:|" .. searchStr .. "|50|\n" ..
        "add_spacer|small|\n" ..
        "add_searchable_item_list|" .. searchableItems .. "|listType:iconGrid;resultLimit:6|searchFixedName|\n" ..
        "add_spacer|small|\n" ..
        "add_smalltext|Can't find the item you're looking for? Try inputting a more precise name and make sure you spelled the name of the item correctly!|left|\n" ..
        "add_spacer|small|\n" ..
        "add_custom_button|close|textLabel:Close;middle_colour:80543231;border_colour:80543231;|\n" ..
        "end_dialog|buy|||\n" ..
        "add_quick_exit|"
    )
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local command, message = fullCommand:match("^(%S+)%s*(.*)")
    if command:lower() == buyCommandData.command then
        onBuyMenu(player, message)
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    if dialogName == "buy" then
        if data["buttonClicked"] == nil then
            return true
        end
        if startsWith(data["buttonClicked"], "searchableItemListButton_") then
            local itemID, expectedPrice, index = data["buttonClicked"]:match("searchableItemListButton_(%d+)_(%d+)_(%d+)")
            itemID = tonumber(itemID)
            expectedPrice = tonumber(expectedPrice)
            index = tonumber(index)
            for i = 1, #buyItems do
                local item = buyItems[i]
                if item:getID() == itemID then
                    local gemsPrice = item:getPrice() * 2000;
                    if gemsPrice ~= expectedPrice then
                        return true
                    end
                    if data["confirmPurchase"] == nil then
                        player:onDialogRequest(
                            "set_default_color|`o\n" ..
                            "add_label_with_icon|big|`wPurchase Confirmation``|left|1366|\n" ..
                            "add_spacer|small|\n" ..
                            "embed_data|confirmPurchase|1\n" ..
                            "add_textbox|`4You'll give:``|left|\n" ..
                            "add_spacer|small|\n" ..
                            "add_label_with_icon|small|(`w" .. formatNum(gemsPrice) .. "``) " .. getItem(112):getName() .. "|left|" .. getItem(112):getID() .. "|\n" ..
                            "add_spacer|small|\n" ..
                            "add_textbox|`2You'll get:``|left|\n" ..
                            "add_spacer|small|\n" ..
                            "add_label_with_icon|small|(`w1``) " .. item:getName() .. "|left|" .. item:getID() .. "|\n" ..
                            "add_spacer|small|\n" ..
                            "add_textbox|Are you sure you want to make this purchase?|left|\n" ..
                            "add_spacer|small|\n" ..
                            "add_custom_button|cancel|textLabel:Cancel;middle_colour:80543231;border_colour:80543231;|\n" ..
                            "add_custom_button|" .. data["buttonClicked"] .. "|textLabel:OK;middle_colour:431888895;border_colour:431888895;anchor:cancel;left:1;margin:40,0;|\n" ..
                            "end_dialog|buy|||\n" ..
                            "add_quick_exit|"
                        )
                        return true
                    end
                    if player:getGems() < gemsPrice then
                        player:onTalkBubble(player:getNetID(), "I can't afford it!", 1)
                        return true
                    end
                    if player:removeGems(gemsPrice, 0, 1) then
                        if not player:changeItem(item:getID(), 1, 0) then
                            player:changeItem(item:getID(), 1, 1)
                        end
                        player:onTalkBubble(player:getNetID(), "Purchased `91 " .. item:getName() .. "`` for `9" .. formatNum(gemsPrice) .. " gems``!", 0)
                        return true
                    end
                    return true
                end
            end
            return true
        end
        return true
    end
    return false
end)
