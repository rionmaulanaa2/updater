-- Set Slots Command script
print("(Loaded) Set Slots Command script for GrowSoft")

function formatNum(num)
    local formattedNum = tostring(num)
    formattedNum = formattedNum:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    formattedNum = formattedNum:gsub("^,", "")
    return formattedNum
end

function findMatch(avList, searchName)
    for _, player in ipairs(avList) do
        if player:getCleanName():lower() == searchName:lower() then
            return {player}
        end
    end
    return nil
end

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

local setSlotsCommandData = {
    command = "setslots",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "This command allows you to set `$players`` autofarm slots."
}

local setSlotsInfo = "`oUsage: /setslots <`$full or first part of a name``> <`$amount``> - Set user autofarm slots, works even if they are offline!``"

registerLuaCommand(setSlotsCommandData) -- This is just for some places such as role descriptions and help

onPlayerCommandCallback(function(world, player, fullCommand)
    local command, message = fullCommand:match("^(%S+)%s*(.*)")
    
    if command:lower() == setSlotsCommandData.command then
        if not player:hasRole(setSlotsCommandData.roleRequired) then
            return false
        end

        local slotsUser, slotAmount = message:match("^(%S+)%s+(%d+)$")
        
        if not slotsUser or not slotAmount then
            player:onConsoleMessage(setSlotsInfo)
            return true
        end

        slotAmount = tonumber(slotAmount)
        
        if not slotAmount or slotAmount <= 0 then
            player:onConsoleMessage(setSlotsInfo)
            return true
        end

        local foundPlayers = getPlayerByName(slotsUser)

        if #foundPlayers == 0 then
            player:onConsoleMessage("`4Oops: `oThere is nobody currently in this server with a name starting with `w" .. slotsUser .. "``.")
            return true
        end
        
        if #foundPlayers > 1 then
            local matchedPlayers = findMatch(foundPlayers, slotsUser)
            if matchedPlayers then
                foundPlayers = matchedPlayers
            else
                local possible_matches = {}
                local limit = math.min(#foundPlayers, 3)
                
                for i = 1, limit do
                    table.insert(possible_matches, "`w" .. foundPlayers[i]:getName() .. "``")
                end

                local extra_count = #foundPlayers - 3
                local extra_info = extra_count > 0 and (" and `w" .. formatNum(extra_count) .. "`` more...") or "."

                player:onConsoleMessage("`oError, more than one person's name in this server starts with `w" .. slotsUser .. "``. Be more specific. Possible matches: " .. table.concat(possible_matches, ", ") .. extra_info)

                return true
            end
        end

        local targetPlayer = foundPlayers[1]

        targetPlayer:getAutofarm():setSlots(slotAmount)

        player:onConsoleMessage("`6>> Set `$" .. formatNum(slotAmount) .. " Autofarm slots`` to " .. targetPlayer:getCleanName() .. ".``")

        return true
    end
    
    return false
end)