-- Store script
print("(Loaded) Store script for GrowSoft")

function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function formatNum(num)
    local formattedNum = tostring(num)
    formattedNum = formattedNum:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    formattedNum = formattedNum:gsub("^,", "")
    return formattedNum
end

StoreCat = {
    MAIN_MENU = 0,
    LOCKS_MENU = 1,
    ITEMPACK_MENU = 2,
    BIGITEMS_MENU = 3,
    IOTM_MENU = 4,
    TOKEN_MENU = 5
}

ServerEvents = {
    EVENT_VALENTINE = 1,
    EVENT_ECO = 2,
    EVENT_HALLOWEEN = 3,
    EVENT_NIGHT_OF_THE_COMET = 4,
    EVENT_HARVEST = 5,
    EVENT_GROW4GOOD = 6,
    EVENT_EASTER = 7,
    EVENT_ANNIVERSARY = 8
};

DailyEvents = {
    DAILY_EVENT_GEIGER_DAY = 40,
    DAILY_EVENT_DARKMAGE_DAY = 41,
    DAILY_EVENT_SURGERY_DAY = 42,
    DAILY_EVENT_VOUCHER_DAYZ = 43,
    DAILY_EVENT_RAYMAN_DAY = 44,
    DAILY_EVENT_LOCKE_DAY = 45,
    DAILY_EVENT_XP_DAY = 46
};

local storeNavigation = {
    {name = "Features", target = "main_menu", cat = StoreCat.MAIN_MENU, texture = "interface/large/gtps_shop_btn.rttex", texture_y = "0", description = ""},
    {name = "Player Items", target = "locks_menu", cat = StoreCat.LOCKS_MENU, texture = "interface/large/gtps_shop_btn.rttex", texture_y = "1", description = ""},
    {name = "World Building", target = "itempack_menu", cat = StoreCat.ITEMPACK_MENU, texture = "interface/large/gtps_shop_btn.rttex", texture_y = "3", description = ""},
    {name = "Custom Items", target = "bigitems_menu", cat = StoreCat.BIGITEMS_MENU, texture = "interface/large/gtps_shop_btn.rttex", texture_y = "4", description = ""},
    {name = "IOTM", target = "iotm_menu", cat = StoreCat.IOTM_MENU, texture = "interface/large/btn_iotm_store.rttex", texture_y = "4", description = ""},
    {name = "Growtokens", target = "token_menu", cat = StoreCat.TOKEN_MENU, texture = "interface/large/gtps_shop_btn.rttex", texture_y = "2", description = ""}
}

function onPurchaseInventoryUpgrade(player)
    if player:isMaxInventorySpace() then
        return
    end
    local price = 1000 * player:getInventorySize() / 16
    if player:getGems() < price then
        player:onStorePurchaseResult(
            "You can't afford `wUpgrade Backpack (10 slots)``!  You're `$" .. formatNum(price - player:getGems()) .. "`` Gems short."
        )
        player:playAudio("bleep_fail.wav");
        return
    end
    local purchaseResult = "You've purchased `wUpgrade Backpack (10 slots)`` for `$" .. formatNum(price) .. "`` Gems.\n" .."You have `$" .. formatNum(player:getGems()) .. "`` Gems left."
    if player:removeGems(price, 1, 1) then
        player:upgradeInventorySpace(10) -- Size slots
        player:onStorePurchaseResult(
            purchaseResult .. "\n\n" ..
            "`5Received: ``Backpack Upgrade"
        )
        player:onConsoleMessage(purchaseResult);
        player:playAudio("piano_nice.wav");
        onStore(player, StoreCat.LOCKS_MENU)
    end
end

function onPurchaseItem(player, storeItem, isDailyOffer)
    local requiredServerEvent = storeItem:getRequiredEvent()
    if requiredServerEvent ~= -1 and requiredServerEvent ~= getCurrentServerEvent() then
        return
    end

    if storeItem:isVoucher() and getCurrentServerDailyEvent() ~= DailyEvents.DAILY_EVENT_VOUCHER_DAYZ then
        return
    end

    if storeItem:getItemID() == 10756 then -- Golden egg carton validation
        if getCurrentServerEvent() ~= ServerEvents.EVENT_EASTER then
            return
        end
        local offerActiveTill = getEasterBuyTime(player:getUserID());
        local currentTime = os.time()
        if offerActiveTill - currentTime <= 0 then
            return;
        end
    end

    local itemTitle = storeItem:getTitle()

    if storeItem:getCategory() == "iotm" then
        local IOTMItemObj = getIOTMItem(storeItem:getItemID())
        if IOTMItemObj ~= nil then
            if IOTMItemObj:getAmount() == 0 then
                return
            end
        end
    end

    if isDailyOffer then
        if isDailyOfferPurchased(player:getUserID(), storeItem:getItemID()) then
            return
        end
    end

    -- The code above is validations to prevent hackers from buying items that are not available

    local getItems = storeItem:makePurchaseItems(1) -- 1 is purchase count, due to the complexity of this function it is kept in server itself and not lua.
    
    if #getItems == 0 then
        return
    end

    if not player:canFit(getItems) then
        player:onStorePurchaseResult(
            "You don't have enough space in your inventory for that. You may be carrying too many of one of the items you are trying to purchase or you don't have enough free spaces to fit them all in your backpack!"
        )
        player:playAudio("bleep_fail.wav");
        return
    end

    local price = storeItem:getPrice()

    local currencyName = "Gems"
    local currencyLeft = 0

    if storeItem:isRPC() then
        currencyName = getCurrencyLongName() .. "s"
        if player:getCoins() < price then
            player:onStorePurchaseResult(
                "You can't afford `o" .. itemTitle .. "``!  You're `$" .. formatNum(price - player:getCoins()) .. "`` " .. currencyName .. " short."
            )
            player:playAudio("bleep_fail.wav");
            return
        end
        if not player:removeCoins(price, 1) then
            return
        end
        currencyLeft = player:getCoins()
    elseif storeItem:isGrowtoken() or storeItem:isVoucher() then
        if storeItem:isGrowtoken() then
            currencyName = "Growtokens"
        else
            currencyName = "Vouchers"
        end
        local neededItem = (storeItem:isGrowtoken()) and 1486 or 10858
        local hasItemAmount = player:getItemAmount(neededItem)
        if hasItemAmount < price then
            player:onStorePurchaseResult(
                "You can't afford `o" .. itemTitle .. "``!  You're `$" .. formatNum(price - hasItemAmount) .. "`` " .. currencyName .. " short."
            )
            player:playAudio("bleep_fail.wav");
            return
        end
        if not player:changeItem(neededItem, -price, 0) then
            return
        end
        currencyLeft = player:getItemAmount(neededItem)
    else
        if player:getGems() < price then
            player:onStorePurchaseResult(
                "You can't afford `o" .. itemTitle .. "``!  You're `$" .. formatNum(price - player:getGems()) .. "`` " .. currencyName .. " short."
            )
            player:playAudio("bleep_fail.wav");
            return
        end
        if not player:removeGems(price, 1, 1) then
            return
        end
        currencyLeft = player:getGems()
    end

    local purchasedItems = {}
    local purchasedItemsMessage = {}
    for i = 1, #getItems do
        local itemID = getItems[i][1]
        local itemCount = getItems[i][2]
        player:progressQuests(itemID, itemCount) -- This is needed for player to unlock some item-related achievements or progress quests
        player:changeItem(itemID, itemCount, 0)
        table.insert(purchasedItems, (itemCount == 1) and getItem(itemID):getName() or itemCount .. " " .. getItem(itemID):getName())
        table.insert(purchasedItemsMessage, itemCount .. " `#" .. getItem(itemID):getName() .. "``")
    end

    local purchaseResult = "You've purchased `o" .. itemTitle .. "`` for `$" .. formatNum(price) .. "`` " .. currencyName .. ".\n" .. "You have `$" .. formatNum(currencyLeft) .. "`` " .. currencyName .. " left."

    player:onStorePurchaseResult(
        purchaseResult .. "\n\n" ..
        "`5Received: ``" .. table.concat(purchasedItems, ", ")
    )

    player:onConsoleMessage(purchaseResult);

    for i = 1, #purchasedItemsMessage do
        player:onConsoleMessage("Got " .. purchasedItemsMessage[i] .. ".");
    end

    player:playAudio("piano_nice.wav");

    player:updateGems(0)

    if storeItem:getCategory() == "iotm" then
        local IOTMItemObj = getIOTMItem(storeItem:getItemID())
        if IOTMItemObj ~= nil then
            IOTMItemObj:setAmount(IOTMItemObj:getAmount() - 1)
            if IOTMItemObj:getAmount() == 0 then
                local players = getServerPlayers()
                for i = 1, #players do
                    local itPlayer = players[i]
                    itPlayer:onConsoleMessage("ĭ `4All " .. getItem(storeItem:getItemID()):getName() .. " have been sold out from the store!``");
                    itPlayer:playAudio("gauntlet_spawn.wav");
                end
            end
        end
    end

    if isDailyOffer then
        addDailyOfferPurchased(player:getUserID(), storeItem:getItemID())
    end

    local currentCategory = storeItem:getCategory()

    if isDailyOffer then
        currentCategory = "main"
    else
        if currentCategory ~= "iotm" and currentCategory ~= "voucher" then
            if requiredServerEvent == -1 and storeItem:getItemID() > getRealGTItemsCount() then -- (If custom item)
                currentCategory = "bigitems" -- The "custom items" category
            end
        end
    end

    for i, category in ipairs(storeNavigation) do
        if startsWith(category.target, currentCategory) then
            onStore(player, category.cat)
            return
        end
    end
end

function onPurchaseItemReq(player, storeItemID)
    if storeItemID == 9412 then
        onPurchaseInventoryUpgrade(player)
        return
    end
    local storeItems = getStoreItems()
    for i = 1, #storeItems do
        local storeItem = storeItems[i]
        if storeItem:getItemID() == storeItemID then
            onPurchaseItem(player, storeItem, false)
            return
        end
    end
    local eventOffers = getEventOffers()
    for i = 1, #eventOffers do
        local storeItem = eventOffers[i]
        if storeItem:getItemID() == storeItemID then
            onPurchaseItem(player, storeItem, true)
            return
        end
    end
    local activeDailyOffers = getActiveDailyOffers()
    for i = 1, #activeDailyOffers do
        local storeItem = activeDailyOffers[i]
        if storeItem:getItemID() == storeItemID then
            onPurchaseItem(player, storeItem, true)
            return
        end
    end
end

function makeStoreButton(player, storeItem, isDailyOffer)
    -- This part of the code is probably most complex, i would recommend not to edit anything here
    -- you can of course edit some text if you want

    local itemTitle = storeItem:getTitle()
    local itemDescription = storeItem:getDescription()
    
    local getItems = {}
    local giveItems = storeItem:getItems()
    for i = 1, #giveItems do
        local itemID = giveItems[i][1]
        local itemCount = giveItems[i][2]
        table.insert(getItems, itemCount .. " " .. getItem(itemID):getName())
    end

    local itemsDescription = table.concat(getItems, ", ") .. "."

    if storeItem:getItemsDescription() ~= "" then
        itemsDescription = storeItem:getItemsDescription()
    end
    
    local isUnlocked = true
    local iotmItemStock = ""
    local extraDescription = ""
    if storeItem:getCategory() == "iotm" then
        local IOTMItemObj = getIOTMItem(storeItem:getItemID())
        if IOTMItemObj ~= nil then
            if IOTMItemObj:getAmount() == 0 then
                iotmItemStock = "`4Out of Stock``"
                isUnlocked = false
                extraDescription = "<CR><CR>`5Note:`` This item is sold out, check again later."
            else
                iotmItemStock = "`wIn stock: " .. formatNum(IOTMItemObj:getAmount()) .. "``"
                extraDescription = "<CR><CR>`5Note:`` There are " .. formatNum(IOTMItemObj:getAmount()) .. " items in stock."
            end
        end
    end

    if isDailyOffer then
        if isDailyOfferPurchased(player:getUserID(), storeItem:getItemID()) then
            iotmItemStock = "`2Purchased``"
            isUnlocked = false
            extraDescription = "<CR><CR>`5Note:`` You already purchased this offer."
        end
    end
    
    local itemDescription = "`2You Get:`` " .. itemsDescription .. "<CR><CR>`5Description:`` " .. itemDescription .. extraDescription

    if storeItem:getItemID() == 10756 then -- Event special store items that require some progression, currently theres only one
        local progressStr = ""
        local bigButtonTitleStr = ""
        
        if storeItem:getItemID() == 10756 then
            local offerActiveTill = getEasterBuyTime(player:getUserID());
            local currentTime = os.time()
            if offerActiveTill - currentTime <= 0 then
                local hasEggs = getEasterEggs(player:getUserID());
                isUnlocked = false
                progressStr = hasEggs .. " / 1000 Magic Eggs Used"
            else
                bigButtonTitleStr = formatStoreTime(offerActiveTill, currentTime) .. " left"
            end
        end

        local eventSpecialButtonString = string.format(
            "add_button|%s|`o%s``|%s|%s|%s|%s|%s|0|%s||-1|-1||-1|-1|%s|%s|%s|0|%s|    %s    |%s|%s|%s|CustomParams:|",
            storeItem:getItemID(),
            itemTitle,
            storeItem:getTexture(),
            (storeItem:isRPC()) and "" or itemDescription,
            storeItem:getTexturePosX(),
            storeItem:getTexturePosY(),
            (storeItem:isRPC() or storeItem:isVoucher()) and "" or (storeItem:isGrowtoken()) and -storeItem:getPrice() or storeItem:getPrice(),
            (storeItem:isRPC()) and getCurrencyIcon() .. " " .. formatNum(storeItem:getPrice()) .. " " .. getCurrencyMediumName() or "",
            (storeItem:isRPC()) and itemDescription or "",
            (isUnlocked == true) and "1" or "0",
            storeItem:getTexture(),
            (isUnlocked == false) and tonumber(storeItem:getTexturePosY()) + 1 or storeItem:getTexturePosY(),
            progressStr,
            (bigButtonTitleStr == "") and iotmItemStock or bigButtonTitleStr,
            (storeItem:isRPC()) and "-1" or "0",
            (storeItem:isVoucher()) and storeItem:getPrice() or "0"
        )
        return eventSpecialButtonString
    end

    local buttonString = string.format( -- It looks complex because idk if theres better way to format a string in lua
        "add_button|%s|`o%s``|%s|%s|%s|%s|%s|0|%s||-1|-1||-1|-1|%s|%s|||||%s|%s|%s|CustomParams:|",
        storeItem:getItemID(),
        itemTitle,
        storeItem:getTexture(),
        (storeItem:getItemID() == 0) and "OPENDIALOG&warptogrowganoth" or (storeItem:getItemID() == 10794) and "OPENDIALOG&donatemenu" or (storeItem:isRPC()) and "" or itemDescription,
        storeItem:getTexturePosX(),
        storeItem:getTexturePosY(),
        (storeItem:isRPC() or storeItem:isVoucher()) and "" or (storeItem:isGrowtoken()) and -storeItem:getPrice() or storeItem:getPrice(),
        (storeItem:isRPC()) and getCurrencyIcon() .. " " .. formatNum(storeItem:getPrice()) .. " " .. getCurrencyMediumName() or "",
        (storeItem:isRPC()) and itemDescription or "",
        (isUnlocked == true) and "1" or "0",
        iotmItemStock,
        (storeItem:isRPC()) and "-1" or "0",
        (storeItem:isVoucher()) and storeItem:getPrice() or "0"
    )
    return buttonString
end

function onStore(player, cat)
    local currentCategory = ""
    local storeCategories = {}
    for i, category in ipairs(storeNavigation) do
        local isCurrentCategory = (category.cat == cat) and "1" or "0"
        if isCurrentCategory == "1" then
            currentCategory = category.target
        end
        local tabString = string.format(
            "add_tab_button|%s|%s|%s|%s|%s|%s|0|0||||-1|-1|||0|0|CustomParams:|",
            category.target,
            category.name,
            category.texture,
            category.description,
            isCurrentCategory,
            category.texture_y
        )
        table.insert(storeCategories, tabString)
    end

    local storeContent = {}

    if cat == StoreCat.MAIN_MENU then
        table.insert(storeContent, "add_big_banner|interface/large/gui_store_alert.rttex|0|0|You have `9" .. formatNum(player:getCoins()) .. " " .. getCurrencyLongName() .. "s " .. getCurrencyIcon() .. "``. You can purchase more by joining our discord via `$/discord`` command!|")

        local topPlayer = getTopPlayerByBalance()
        local topWorld = getTopWorldByVisitors()
        if topWorld ~= nil and topPlayer ~= nil then
            local worldOwner = topWorld:getOwner()
            local worldInfo = ""
            if worldOwner ~= nil then
                worldInfo = " (By " .. worldOwner:getName() .. ")"
            end
            table.insert(storeContent, "add_button|top_players_and_worlds|`oTop Player & World ĕ``|interface/large/gtps/store_buttons/store_new_p.rttex||2|5|0|0|||-1|-1||-1|-1|`#Best Player``: " .. topPlayer:getCleanName() .. " (ā " .. formatNum(topPlayer:getTotalWorldLocks()) .. ")<CR>`#Best World``:  " .. topWorld:getName() .. worldInfo .. "|0|||||World: " .. topWorld:getName() .. " Player: " .. topPlayer:getCleanName() .. "|0|0|CustomParams:|") -- Top Button
        elseif topWorld ~= nil then
            local worldOwner = topWorld:getOwner()
            local worldInfo = ""
            if worldOwner ~= nil then
                worldInfo = " (By " .. worldOwner:getName() .. ")"
            end
            table.insert(storeContent, "add_button|top_players_and_worlds|`oTop Player & World ĕ``|interface/large/gtps/store_buttons/store_new_p.rttex||2|5|0|0|||-1|-1||-1|-1|`#Best Player``: None!<CR>`#Best World``:  " .. topWorld:getName() .. worldInfo .. "|0|||||World: " .. topWorld:getName() .. " Player: None!|-1|0|CustomParams:|") -- Top Button
        elseif topPlayer ~= nil then
            table.insert(storeContent, "add_button|top_players_and_worlds|`oTop Player & World ĕ``|interface/large/gtps/store_buttons/store_new_p.rttex||2|5|0|0|||-1|-1||-1|-1|`#Best Player``: " .. topPlayer:getCleanName() .. " (ā " .. formatNum(topPlayer:getTotalWorldLocks()) .. ")<CR>`#Best World``:  None!|0|||||World: None! Player: " .. topPlayer:getCleanName() .. "|0|0|CustomParams:|") -- Top Button
        end

        table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|0|") -- "GTPS Store" banner
    elseif cat == StoreCat.LOCKS_MENU then
        table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|7|") -- "Player Items" banner
        if not player:isMaxInventorySpace() then -- Manually add inventory upgrade option
            local inventoryUpgradePrice = 1000 * player:getInventorySize() / 16
            table.insert(storeContent, "add_button|9412|`0Upgrade Backpack`` (`w10 Slots``)|interface/large/store_buttons/store_buttons.rttex|`2You Get:`` 10 Additional Backpack Slots.<CR><CR>`5Description:`` Sewing an extra pocket onto your backpack will allow you to store `$10`` additional item types.  How else are you going to fit all those toilets and doors?|0|1|" .. inventoryUpgradePrice .. "|0|||-1|-1||-1|-1||1||||||0|0|CustomParams:|")
        end
    elseif cat == StoreCat.ITEMPACK_MENU then
        table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|8|") -- "Tool Items" banner
    elseif cat == StoreCat.BIGITEMS_MENU then
        table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|9|") -- "Custom Items" banner
    elseif cat == StoreCat.IOTM_MENU then
        table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|19|") -- "Creative Items" banner
    elseif cat == StoreCat.TOKEN_MENU then
        table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|11|") -- "Token Items" banner
    end

    local storeItems = getStoreItems() -- All store items
    for i = 1, #storeItems do
        local storeItem = storeItems[i]

        if storeItem:getTexture() ~= "_label_" then
            local itemCategory = storeItem:getCategory()
            local requiredServerEvent = storeItem:getRequiredEvent()

            -- Since the store update is made as optional (with the support for old one) and without changes to json store configs,
            -- we will need to change some old item categories to the new ones (Move all custom items to custom category)
            if itemCategory ~= "iotm" and itemCategory ~= "voucher" then
                if requiredServerEvent == -1 and storeItem:getItemID() > getRealGTItemsCount() then -- (If custom item)
                    itemCategory = "bigitems" -- The "custom items" category
                end
            end
            
            if itemCategory == "voucher" and getCurrentServerDailyEvent() == DailyEvents.DAILY_EVENT_VOUCHER_DAYZ then
                itemCategory = "main"
            end

            if startsWith(currentCategory, itemCategory) then
                if requiredServerEvent == -1 or requiredServerEvent == getCurrentServerEvent() then
                    table.insert(storeContent, makeStoreButton(player, storeItem, false))
                end
            end
        end
    end

    if cat == StoreCat.MAIN_MENU then
        local eventOffers = getEventOffers()
        local bannerInserted = false
        for i = 1, #eventOffers do
            local eventOffer = eventOffers[i]
            if eventOffer:getRequiredEvent() == getCurrentServerEvent() then
                if not bannerInserted then
                    table.insert(storeContent, "add_banner|interface/large/gtps_store_overlays.rttex|0|19|") -- Limited Items (Event special items here)
                    bannerInserted = true
                end
                table.insert(storeContent, makeStoreButton(player, eventOffer, true))
            end
        end
        table.insert(storeContent, "add_banner|interface/large/gui_shop_featured_header.rttex|0|2|") -- Get More Gems (Active daily offers here)
        local activeDailyOffers = getActiveDailyOffers()
        for i = 1, #activeDailyOffers do
            local activeDailyOffer = activeDailyOffers[i]
            table.insert(storeContent, makeStoreButton(player, activeDailyOffer, true))
        end
        table.insert(storeContent, "add_button|redeem_code|Redeem Code|interface/large/store_buttons/store_buttons40.rttex|OPENDIALOG&showredeemcodewindow|1|5|0|0|||-1|-1||-1|-1||1||||||0|0|CustomParams:|") -- Redeem Button
    end

    player:onStoreRequest(
        "set_description_text|Welcome to the `2Growtopia Store``! Select the item you'd like more info on.`o `wWant to get `5Supporter`` status? Any Gem purchase (or `526000`` Gems earned with free `5Tapjoy`` offers) will make you one. You'll get new skin colors, the `5Recycle`` tool to convert unwanted items into Gems, and more bonuses!\n" ..
        "enable_tabs|1\n" ..
        table.concat(storeCategories, "\n") .. "\n" ..
        table.concat(storeContent, "\n")
    )
end

onPlayerActionCallback(function(world, player, data)
    local actionName = data["action"] or ""
    if actionName == "donatemenu" then
        player:onGrow4GoodDonate()
        return true
    end
    if actionName == "warptogrowganoth" then
        if player:getWorldName() == "GROWGANOTH" then
            player:onTextOverlay("You're already here!")
            return true
        end
        player:enterWorld("GROWGANOTH", "Entering Growganoth...")
        return true
    end
    if actionName == "showredeemcodewindow" then
        player:onRedeemMenu()
        return true
    end
    if actionName == "storenavigate" then
        if data["item"] ~= nil then
            if data["selection"] ~= nil then
                if startsWith(data["selection"], "s_") then
                    return false
                end
            end
            for i, category in ipairs(storeNavigation) do
                if startsWith(category.target, data["item"]) then
                    onStore(player, category.cat)
                    return true
                end
            end
            return true
        end
        return true
    end
    if actionName == "buy" then
        if data["item"] ~= nil then
            for i, category in ipairs(storeNavigation) do
                if startsWith(category.target, data["item"]) then
                    onStore(player, category.cat)
                    return true
                end
            end
            local itemID = tonumber(data["item"])
            onPurchaseItemReq(player, itemID)
            return true
        end
        return true
    end
    if actionName == "killstore" then
        return true
    end
    return false
end)

onStoreRequest(function(world, player) -- Added so the lua store can be requested via server itself as well
    onStore(player, StoreCat.MAIN_MENU)
    return true
end)