-- Daily Reward script
print("(Loaded) Daily Reward script for GrowSoft")

math.randomseed(os.time())

Roles = {
    ROLE_NONE = 0,
    ROLE_VIP = 1,
    ROLE_SUPER_VIP = 2,
    ROLE_MODERATOR = 3,
    ROLE_ADMIN = 4,
    ROLE_COMMUNITY_MANAGER = 5,
    ROLE_CREATOR = 6,
    ROLE_GOD = 7,
    ROLE_DEVELOPER = 51
}

function formatTime(targetTime, currentTime)
    local seconds = targetTime - currentTime
    local days = math.floor(seconds / (24 * 3600))
    seconds = seconds % (24 * 3600)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60

    local result = {}

    if days > 0 then
        table.insert(result, days .. " day" .. (days > 1 and "s" or ""))
    end
    if hours > 0 then
        table.insert(result, hours .. " hour" .. (hours > 1 and "s" or ""))
    end
    if minutes > 0 then
        table.insert(result, minutes .. " min" .. (minutes > 1 and "s" or ""))
    end
    if secs > 0 then
        table.insert(result, secs .. " sec" .. (secs > 1 and "s" or ""))
    end

    if #result == 0 then
        return "0s"
    else
        return table.concat(result, " ")
    end
end


local dailyRewardCommandData = {
    command = "getdaily",
    roleRequired = Roles.ROLE_SUPER_VIP,
    description = "This command gives you `$Random Item`` as a daily reward!"
}

registerLuaCommand(dailyRewardCommandData) -- This is just for some places such as role descriptions and help

local cdModData = {
    modID = -1001, -- The number should be negative, for example if you wanna add another mod use the ID -1002, make sure it never duplicates
    modName = "Daily Reward Cooldown",
    onAddMessage = "Next reward tomorrow!",
    onRemoveMessage = "You can claim your daily reward again, use - /" .. dailyRewardCommandData.command,
    iconID = 242
}

local cdModID = registerLuaPlaymod(cdModData)

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == dailyRewardCommandData.command then
        if not player:hasRole(dailyRewardCommandData.roleRequired) then
            return false
        end
        if player:hasMod(cdModID) then
            local modObj = player:getMod(cdModID)
            player:onConsoleMessage("`4Oops: `6You can claim `#daily reward`` again in `#" .. formatTime(modObj:getExpireTime(), os.time()) .. "``.``")
            return true
        end
        player:onDialogRequest(
            "set_default_color|`o\n" ..
            "add_label_with_icon|big|Claim Daily Reward|left|242|\n" ..
            "add_spacer|small|\n" ..
            "add_custom_textbox|Click on a random chest to open it and see what you got!|size:small;|\n" ..
            "add_spacer|small|\n" ..
            "add_button_with_icon|chest0||staticYellowFrame|596||\n" ..
            "add_button_with_icon|chest1||staticYellowFrame|596||\n" ..
            "add_button_with_icon|chest2||staticYellowFrame|596||\n" ..
            "add_button_with_icon||END_LIST|noflags|0||\n" ..
            "end_dialog|daily_reward|Cancel||"
        )
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    if dialogName == "daily_reward" then
        if data["claimed"] ~= nil then
            player:onConsoleMessage("Don't forget to play again tomorrow!")
            return true
        end
        if not player:hasRole(dailyRewardCommandData.roleRequired) then
            return true -- Dont allow to claim the daily reward without having required role for cheaters
        end
        if player:hasMod(cdModID) then
            return true -- Dont allow to claim the daily reward twice for cheaters
        end
        if data["buttonClicked"] == nil then
            return true
        end
        local rewardItems = {2, 2, 242}
        local rewardItem = rewardItems[math.random(1, #rewardItems)]
        local itemObj = getItem(rewardItem)
        player:onConsoleMessage("Congratulations, today you won a " .. itemObj:getName() .. "!")
        local buttonItem0 = data["buttonClicked"] == "chest0" and rewardItem or 596
        local buttonItem1 = data["buttonClicked"] == "chest1" and rewardItem or 596
        local buttonItem2 = data["buttonClicked"] == "chest2" and rewardItem or 596
        player:onDialogRequest(
            "set_default_color|`o\n" ..
            "add_label_with_icon|big|" .. itemObj:getName() .. "|left|" .. rewardItem .. "|\n" ..
            "add_spacer|small|\n" ..
            "embed_data|claimed|1\n" ..
            "add_custom_textbox|`9Woah you won an awesome `$\"" .. itemObj:getName() .. "\"````|size:small;|\n" ..
            "add_spacer|small|\n" ..
            "add_button_with_icon|chest0||staticYellowFrame|" .. buttonItem0 .. "||\n" ..
            "add_button_with_icon|chest1||staticYellowFrame|" .. buttonItem1 .. "||\n" ..
            "add_button_with_icon|chest2||staticYellowFrame|" .. buttonItem2 .. "||\n" ..
            "add_button_with_icon||END_LIST|noflags|0||\n" ..
            "end_dialog|daily_reward||Thank you|"
        )
        -- Add the reward to inventory
        if not player:changeItem(rewardItem, 1, 0) then  -- 0 means add to inv, 1 means to backpack
            -- Add the reward to backpack (always success)
            player:changeItem(rewardItem, 1, 1)
        end
        player:addMod(cdModID, 86400)
        return true
    end
    return false
end)