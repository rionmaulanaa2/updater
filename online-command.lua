-- Online Players Command script
print("(Loaded) Online Players Command script for GrowSoft")

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

local PlayerStatus = {
    PLAYER_ONLINE = 0,
    PLAYER_BUSY = 1,
    PLAYER_AWAY = 2
}

local onlineCommandData = {
    command = "online",
    roleRequired = Roles.ROLE_NONE,
    description = "This command lists all online players, their location, role, and status."
}

registerLuaCommand(onlineCommandData)

local function getPlayerRoleName(player)
    if player:hasRole(Roles.ROLE_DEVELOPER) then return "`5Developer``" end
    if player:hasRole(Roles.ROLE_GOD) then return "`eGod``" end
    if player:hasRole(Roles.ROLE_CREATOR) then return "`pCreator``" end
    if player:hasRole(Roles.ROLE_COMMUNITY_MANAGER) then return "`pCommunity Manager``" end
    if player:hasRole(Roles.ROLE_ADMIN) then return "`cAdmin``" end
    if player:hasRole(Roles.ROLE_MODERATOR) then return "`bMod``" end
    if player:hasRole(Roles.ROLE_SUPER_VIP) then return "`#Super VIP``" end
    if player:hasRole(Roles.ROLE_VIP) then return "`^VIP``" end
    return "`oPlayer``"
end

local function getPlayerStatusStr(player)
    local status = player:getOnlineStatus()
    if status == PlayerStatus.PLAYER_BUSY then
        return "`4Busy``"
    elseif status == PlayerStatus.PLAYER_AWAY then
        return "`6Away``"
    else
        return "`2Online``"
    end
end

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == onlineCommandData.command then
        local playersOnline = getServerPlayers() or {}
        local count = 0
        local dialogLines = {}
        local isStaff = player:hasRole(Roles.ROLE_MODERATOR) or player:hasRole(Roles.ROLE_ADMIN) or player:hasRole(Roles.ROLE_DEVELOPER)

        for i = 1, #playersOnline do
            local targetPlayer = playersOnline[i]
            local isInvisible = targetPlayer:hasMod(-76) -- -76 is PLAYER_INVISIBLE mod ID

            -- Regular players shouldn't see invisible staff
            if not isInvisible or isStaff then
                count = count + 1
                local name = targetPlayer:getCleanName()
                local role = getPlayerRoleName(targetPlayer)
                local status = getPlayerStatusStr(targetPlayer)
                local loc = targetPlayer:getWorldName() or "EXIT"
                
                -- Determine icon based on role/status
                local iconID = 1366 -- Default wrench icon
                if targetPlayer:hasRole(Roles.ROLE_DEVELOPER) or targetPlayer:hasRole(Roles.ROLE_ADMIN) then
                    iconID = 6016 -- Badge/Shield icon
                elseif targetPlayer:hasRole(Roles.ROLE_MODERATOR) then
                    iconID = 482 -- Blue star/lock badge
                end

                local line = string.format("add_label_with_icon|small|`w%s`` (%s) - Status: %s | Loc: `9%s``%s|left|%d|", 
                    name, role, status, loc, isInvisible and " `4(Invisible)``" or "", iconID)
                table.insert(dialogLines, line)
            end
        end

        player:onDialogRequest(
            "set_default_color|`o\n" ..
            "add_label_with_icon|big|`wOnline Players (" .. count .. ")``|left|982|\n" ..
            "add_spacer|small|\n" ..
            "add_textbox|Here are the players currently online and active on the server:|left|\n" ..
            "add_spacer|small|\n" ..
            table.concat(dialogLines, "\n") .. "\n" ..
            "add_spacer|small|\n" ..
            "end_dialog|online_players_dialog|OK||\n" ..
            "add_quick_exit|"
        )

        player:onConsoleMessage("`6>> Found `$" .. count .. "`` online players.``")
        return true
    end
    return false
end)
