-- Reload Scripts script
print("(Loaded) Reload Scripts for GrowSoft")

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

local rsCommandData = {
    command = "rs",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "This command allows you to `$reload`` scripts."
}

local reloadScriptsCommandData = {
    command = "reloadscripts",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "This command allows you to `$reload`` scripts."
}

registerLuaCommand(rsCommandData) -- This is just for some places such as role descriptions and help
registerLuaCommand(reloadScriptsCommandData) -- This is just for some places such as role descriptions and help

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == rsCommandData.command or command:lower() == reloadScriptsCommandData.command then
        if not player:hasRole(rsCommandData.roleRequired) then
            return false
        end
        reloadScripts()
        player:onConsoleMessage("`6>> Scripts have been `$reloaded``!``")
        return true
    end
    return false
end)