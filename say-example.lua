-- Say Example script
print("(Loaded) Say Example script for GrowSoft")

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

local sayCommandData = {
    command = "say",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "This command allows you to make everyone `$say`` something!"
}

registerLuaCommand(sayCommandData) -- This is just for some places such as role descriptions and help

onPlayerCommandCallback(function(world, player, fullCommand)
    local command, message = fullCommand:match("^(%S+)%s*(.*)")

    if command:lower() == sayCommandData.command then
        if not player:hasRole(sayCommandData.roleRequired) then
            return false
        end
        if message == "" then
            player:onConsoleMessage("`oUsage: /say <`$message``> - Make everyone in this world say something!``")
            return true
        end

        local players = world:getPlayers()
        for i = 1, #players do
            local itPlayer = players[i]
            if not itPlayer:hasMod(-76) then -- -76 is PLAYER_INVISIBLE mod ID
                itPlayer:onTalkBubble(itPlayer:getNetID(), message, 0)
            end
        end

        -- Example if you want to iterate over everyone online:
        -- local playersOnline = getServerPlayers()
        -- The same after

        player:onConsoleMessage("`6>> Everyone says `$" .. message .. "``!``")
        return true
    end
    return false
end)