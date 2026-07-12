-- Player Profile script
print("(Loaded) Player Profile script for GrowSoft")

function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function formatNum(num)
    local formattedNum = tostring(num)
    formattedNum = formattedNum:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    formattedNum = formattedNum:gsub("^,", "")
    return formattedNum
end

function shortenNumber(number)
    local suffixes = { "", "k", "m", "b", "t" }
    local suffixIndex = 1
    local num = number
    while num >= 1000 and suffixIndex < #suffixes do
        num = num / 1000
        suffixIndex = suffixIndex + 1
    end
    local precision = (num < 10) and 2 or 1
    local formatted = string.format("%." .. precision .. "f%s", num, suffixes[suffixIndex])
    return formatted
end

ProfileCat = {
    INFO_MENU = 0,
    LEVEL_UP_MENU = 1,
    SKILLS_MENU = 2,
    QUESTS_MENU = 3,
    BADGES_MENU = 4,
    CHEATS_MENU = 5,
    LOCKED_WORLDS_MENU = 6
}

PlayerStats = {
    PlacedBlocks = 0,
    HarvestedTrees = 1,
    SmashedBlocks = 2,
    GemsSpent = 3,
    ItemsDisposed = 4,
    ConsumablesUsed = 5,
    ProviderCollected = 6,
    MixedItems = 7,
    FishRevived = 8,
    StarshipFall = 9,
    GhostsCaptured = 10,
    MindGhostsCaptured = 11,
    AnomalizersBroken = 12,
    AnomHammerBroken = 13,
    AnomScytheBroken = 14,
    AnomBonesawBroken = 15,
    AnomAnomarodBroken = 16,
    AnomTrowelBroken = 17,
    AnomCultivatorBroken = 18,
    AnomScannerBroken = 19,
    AnomRollingPinsBroken = 20,
    SurgeriesDone = 21,
    GeigerFinds = 22,
    VillainsDefeated = 23,
    StartopianItemsFound = 24,
    FuelUsed = 25,
    FishTrained = 26,
    RoleUPItemsCrafted = 27,
    CookedItems = 28,
    FiresPutout = 29,
    AncestralUpgraded = 30,
    ChemsynthCreated = 31,
    MaladyCured = 32,
    GhostBossDefeated = 33,
    StarshipsLanded = 34,
    MagicEggsCollected = 35,
    EasterEggsFound = 36,
    UltraPinatasSmashed = 37,
    GrowganothFeed = 38,
    GrowchGifted = 39,
    RarityDonated = 40
}

PlayerClothes = {
    HAIR_ITEM = 0,
    SHIRT_ITEM = 1,
    PANTS_ITEM = 2,
    FEET_ITEM = 3,
    FACE_ITEM = 4,
    HAND_ITEM = 5,
    BACK_ITEM = 6,
    MASK_ITEM = 7,
    NECK_ITEM = 8,
    ANCES_ITEM = 9
}

PlayerSubscriptions = {
    TYPE_SUPPORTER = 0,
    TYPE_SUPER_SUPPORTER = 1,
    TYPE_YEAR_SUBSCRIPTION = 2,
    TYPE_MONTH_SUBSCRIPTION = 3,
    TYPE_GROWPASS = 4,
    TYPE_TIKTOK = 5,
    TYPE_BOOST = 6,
    TYPE_STAFF = 7
}

PlayerStatus = {
	PLAYER_ONLINE = 0,
	PLAYER_BUSY = 1,
	PLAYER_AWAY = 2
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

function onProfile(world, player, cat, flags)
    local tabData = ""

    if cat == ProfileCat.INFO_MENU then
        local activeEffectsInfo = {}
        local activeEffects = player:getMods()

        for i = 1, #activeEffects do
            local activeEffect = activeEffects[i]
            local modName = activeEffect:getName(player)
            if modName ~= "" then
                local modItemID = activeEffect:getItemID()
                local modExpireTime = activeEffect:getExpireTime()
                local timeLeft = (modExpireTime ~= 0) and " (" .. formatTime(modExpireTime, os.time()) .. " left)" or ""
                local showDescription = ""
                if player:getClothingItemID(PlayerClothes.HAND_ITEM) == 2286 then -- If player is wearing dead geiger counter, show the charge
                    showDescription = " `o" .. activeEffect:getDescription(player) .. "``"
                end
                table.insert(activeEffectsInfo, "add_label_with_icon|small|`w" .. modName .. "``" .. timeLeft .. showDescription .. "|left|" .. modItemID .. "|")
            end
        end

        local peopleInWorld = world:getVisiblePlayersCount() -- gets players that dont have the player_invisible mod

        local supporterStatus = "You are not yet a `2Supporter`` or `5Super Supporter``."
        if player:getSubscription(PlayerSubscriptions.TYPE_SUPER_SUPPORTER) ~= nil then
            supporterStatus = "You are a `5Super Supporter`` and have the `wRecycler`` and `w/warp``."
        elseif player:getSubscription(PlayerSubscriptions.TYPE_SUPPORTER) ~= nil then
            supporterStatus = "You are a `5Supporter`` and have the `wRecycler``."
        end

        local standingOnNote = ""
        if world:getOwner() ~= nil then
            local standingOnTile = world:getTile(player:getBlockPosX(), player:getBlockPosY())
            if standingOnTile ~= nil then
                standingOnNote = "add_textbox|`oYou are standing on the note \"" .. standingOnTile:getNote() .. "\".``|left|\n"
            end
        end

        local playtimeHours = string.format("%.2f", player:getPlaytime() / 3600)

        local onlineStatusBanner = "interface/large/gui_wrench_online_status_1green.rttex"
        if player:getOnlineStatus() == PlayerStatus.PLAYER_AWAY then
            onlineStatusBanner = "interface/large/gui_wrench_online_status_2yellow.rttex"
        elseif player:getOnlineStatus() == PlayerStatus.PLAYER_BUSY then
            onlineStatusBanner = "interface/large/gui_wrench_online_status_3red.rttex"
        end

        local homeWorldInfo = ""
        local homeWorldID = player:getHomeWorldID()
        if homeWorldID ~= 0 then
            local homeWorld = getWorld(homeWorldID) -- p.s theres also now getWorldByName("START")
            if homeWorld ~= nil then
                homeWorldInfo = "add_smalltext|`oHome World: " .. homeWorld:getName() .. "``|left|\n"
            end
        end

        local corruptedSouls = ""

        if getCurrentServerEvent() == ServerEvents.EVENT_HALLOWEEN then
            corruptedSouls = "add_textbox|`oYou have `w" .. formatNum(getCorruptedSouls(player:getUserID())) .. "`` Corrupted Souls.``|left|\n"
        end

        tabData = 
        "add_progress_bar|" .. player:getName() .. "|big|Level " ..  player:getLevel() .. "|" .. (player:getLevel() == getMaxLevel() and player:getRequiredXP() or player:getXP()) .. "|" .. player:getRequiredXP() .. "|" .. (player:getLevel() == getMaxLevel() and "(MAX!)" or "(" .. shortenNumber(player:getXP()) .. "/" .. shortenNumber(player:getRequiredXP()) .. ")") .. "|4294967295|\n" .. 
        "add_spacer|small|\n" ..
        player:getSubscriptionInfo() ..
        player:getProfileGuildInfo() ..
        player:getProfileGuildJoinButton() ..
        player:getProfileAccessButton() ..
        player:getCardBattleInfo() ..
        "set_custom_spacing|x:5;y:10|\n" ..
        "add_custom_button|open_personalize_profile|image:interface/large/gui_wrench_personalize_profile.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|set_online_status|image:" .. onlineStatusBanner .. ";image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|billboard_edit|image:interface/large/gui_wrench_edit_billboard.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|wardrobe_customization|image:interface/large/gui_wrench_wardrobe.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|seed_diary_customization|image:interface/large/gui_wrench_seed_diary.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|notebook_edit|image:interface/large/gui_wrench_notebook.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|goals|image:interface/large/gui_wrench_goals_quests.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|bonus|image:interface/large/gui_wrench_daily_bonus_active.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|my_worlds|image:interface/large/gui_wrench_my_worlds.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|alist|image:interface/large/gui_wrench_achievements.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_label|(" .. player:getUnlockedAchievementsCount() .. "/" .. getAchievementsCount() .. ")|target:alist;top:0.72;left:0.5;size:small|\n" ..
        "add_custom_button|emojis|image:interface/large/gui_wrench_growmojis.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|marvelous_missions|image:interface/large/gui_wrench_marvelous_missions.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|title_edit|image:interface/large/gui_wrench_title.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|wrench_customization|image:interface/large/gui_wrench_customization.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|trades|image:interface/large/gui_wrench_trades.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|backpack|image:interface/large/cgui_wrench_backpack.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_label|(" .. player:getBackpackUsedSize() .. " items)|target:backpack;top:0.72;left:0.5;size:small|\n" ..
        "add_custom_button|mentorship|image:interface/large/cgui_wrench_mentorship.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|vouchers|image:interface/large/cgui_wrench_vouchers.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|name_title_edit|image:interface/large/cgui_wrench_name_titles.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|open_worldlock_storage|image:interface/large/gui_wrench_auction.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|tab_" .. ProfileCat.LEVEL_UP_MENU + 1 .. "|image:interface/large/gui_wrench_c_level_rewards.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|tab_" .. ProfileCat.SKILLS_MENU + 1 .. "|image:interface/large/gui_wrench_c_skills.rttex;image_size:400,260;width:0.19;|\n" ..
        "add_custom_button|tab_" .. ProfileCat.CHEATS_MENU + 1 .. "|image:interface/large/gui_wrench_c_cheats.rttex;image_size:400,260;width:0.19;|\n" ..
        ((player:getGuildID() ~= 0) and "add_custom_button|guild_notebook|image:interface/large/gui_wrench_guild_notebook.rttex;image_size:400,260;width:0.19;|\n" or "") ..
        ((getCurrentServerEvent() == ServerEvents.EVENT_GROW4GOOD) and "add_custom_button|g4g|image:interface/large/gui_wrench_g4g.rttex;image_size:400,260;width:0.19;|\n" or "") ..
        ((world:isGameActive() and world:getOwner():getUserID() == player:getUserID()) and "add_custom_button|end_game|image:interface/large/gui_wrench_end_game.rttex;image_size:400,260;width:0.19;|\n" or "") ..
        player:getTransformProfileButtons() ..
        "add_custom_break|\n" ..
        "add_spacer|small|\n" ..
        ((player:getDiscordID() == "0") and "add_button|link_discord|`2Link Discord``|no_flags|0|0|\n" or "add_button|unlink_discord|`4Unlink Discord``|no_flags|0|0|\n") ..
        "add_button|favorite_items|View Favorited Items|no_flags|0|0|\n" ..
        "add_button|view_worn_clothes|View Worn Clothes|no_flags|0|0|\n" ..
        "set_custom_spacing|x:0;y:0|\n" ..
        ((#activeEffectsInfo > 0) and "add_textbox|`wActive effects:``|left|\n" .. table.concat(activeEffectsInfo, "\n") .. "\nadd_spacer|small|\n" or "")  ..
        "add_smalltext|Fires Put Out: " .. formatNum(player:getStats(PlayerStats.FiresPutout)) .. "|left|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|`oYou have `w" .. player:getInventorySize() .. "`` backpack slots.``|left|\n" ..
        corruptedSouls ..
        "add_textbox|`oCurrent world: `w" .. player:getWorldName() .. "`` (`w" .. math.floor(player:getPosX() / 32 + 1) .. "``, `w" .. math.floor(player:getPosY() / 32 + 1) .. "``) (`w" .. formatNum(peopleInWorld) .. "`` " .. ((peopleInWorld == 1) and "person" or "peoples") .. ")````|left|\n" ..
        homeWorldInfo ..
        "add_textbox|`o" .. supporterStatus .. "``|left|\n" ..
        standingOnNote ..
        "add_spacer|small|\n" ..
        "add_textbox|`oTotal time played is `w" .. playtimeHours .. "`` hours.  This account was created `w" .. player:getAccountCreationDateStr() .. "`` days ago.``|left|\n" ..
        "add_spacer|small|\n"
    else
        tabData = player:getClassicProfileContent(cat, flags)
    end

    player:onDialogRequest(
        "embed_data|netID|" .. player:getNetID() .. "\n" ..
        "embed_data|flags|" .. flags .. "\n" ..
        "add_popup_name|WrenchMenu|\n" ..
        "set_default_color|`o\n" ..
        tabData ..
        "end_dialog|" .. ((cat == ProfileCat.INFO_MENU) and "playerProfile" or "manoProfile") .. "||" .. ((cat == ProfileCat.INFO_MENU or cat == ProfileCat.LEVEL_UP_MENU or cat == ProfileCat.QUESTS_MENU or cat == ProfileCat.LOCKED_WORLDS_MENU or cat == ProfileCat.SKILLS_MENU) and "Continue" or "") .. "|\n" ..
        "add_quick_exit|"
    )
end

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    if dialogName == "playerProfile" then
        if data["buttonClicked"] ~= nil then
            if data["buttonClicked"] == "trades" then
                player:onTradeScanUI()
                return true
            end
            if data["buttonClicked"] == "end_game" then
                world:onGameWinHighestScore()
                return true
            end
            if data["buttonClicked"] == "g4g" then
                player:onGrow4GoodUI()
                return true
            end
            if data["buttonClicked"] == "guild_notebook" then
                player:onGuildNotebookUI()
                return true
            end
            if data["buttonClicked"] == "emojis" then
                player:onGrowmojiUI()
                return true
            end
            if data["buttonClicked"] == "bonus" then
                player:onGrowpassUI()
                return true
            end
            if data["buttonClicked"] == "notebook_edit" then
                player:onNotebookUI()
                return true
            end
            if data["buttonClicked"] == "billboard_edit" then
                player:onBillboardUI()
                return true
            end
            if data["buttonClicked"] == "open_personalize_profile" then
                player:onPersonalizeWrenchUI()
                return true
            end
            if data["buttonClicked"] == "set_online_status" then
                player:onOnlineStatusUI()
                return true
            end
            if data["buttonClicked"] == "favorite_items" then
                player:onFavItemsUI()
                return true
            end
            if data["buttonClicked"] == "goals" then
                onProfile(world, player, ProfileCat.QUESTS_MENU, tonumber(string.sub(data["flags"], 1, -2)))
                return true
            end
            if data["buttonClicked"] == "my_worlds" then
                onProfile(world, player, ProfileCat.LOCKED_WORLDS_MENU, tonumber(string.sub(data["flags"], 1, -2)))
                return true
            end
            if data["buttonClicked"] == "unlink_discord" then
                player:onUnlinkDiscordUI()
                return true
            end
            if data["buttonClicked"] == "link_discord" then
                player:onLinkDiscordUI()
                return true
            end
            if data["buttonClicked"] == "view_worn_clothes" then
                player:onClothesUI(player) -- player is the Target player (whos content will be shown) (not required)
                return true
            end
            if data["buttonClicked"] == "alist" then
                player:onAchievementsUI(player) -- player is the Target player (whos content will be shown) (not required)
                return true
            end
            if data["buttonClicked"] == "title_edit" then
                player:onTitlesUI(player) -- player is the Target player (whos content will be shown) (not required)
                return true
            end
            if data["buttonClicked"] == "wrench_customization" then
                player:onWrenchIconsUI(player) -- player is the Target player (whos content will be shown) (not required)
                return true
            end
            if data["buttonClicked"] == "name_title_edit" then
                player:onNameIconsUI(player) -- player is the Target player (whos content will be shown) (not required)
                return true
            end
            if data["buttonClicked"] == "wardrobe_customization" then
                player:sendVariant({"OnDialogRequestRML", "show_wardrobe_main_ui"})
                return true
            end
            if data["buttonClicked"] == "seed_diary_customization" then
                player:sendVariant({"OnDialogRequestRML", "show_seed_diary_ui"})
                return true
            end
            if data["buttonClicked"] == "open_worldlock_storage" then
                player:sendVariant({"OnDialogRequestRML", "show_world_lock_storage"})
                return true
            end
            if data["buttonClicked"] == "vouchers" then
                player:onVouchersUI()
                return true
            end
            if data["buttonClicked"] == "mentorship" then
                player:onMentorshipUI()
                return true
            end
            if data["buttonClicked"] == "backpack" then
                player:onBackpackUI(player) -- player is the Target player (whos content will be shown) (not required)
                return true
            end
            if startsWith(data["buttonClicked"], "tab_") then
                local tabNum = tonumber(data["buttonClicked"]:sub(5))
                onProfile(world, player, tabNum - 1, tonumber(string.sub(data["flags"], 1, -2)))
            end
        end
        return false
    end
    return false
end)

onPlayerProfileRequest(function(world, player, tabID, flags)
    onProfile(world, player, tabID - 1, flags)
    return true
end)