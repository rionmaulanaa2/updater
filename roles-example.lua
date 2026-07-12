-- Roles Example script
print("(Loaded) Roles Example script for GrowSoft")

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

local buyVIPCommandData = {
    command = "buyvip",
    roleRequired = Roles.ROLE_NONE,
    description = "This command allows you to buy `$VIP`` role for 100 Diamond Lock!"
}

local demoteMyselfCommandData = {
    command = "demotemyself",
    roleRequired = Roles.ROLE_VIP, -- At least VIP
    description = "This command allows you to `$demote`` yourself!"
}

registerLuaCommand(buyVIPCommandData) -- This is just for some places such as role descriptions and help
registerLuaCommand(demoteMyselfCommandData) -- This is just for some places such as role descriptions and help

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == demoteMyselfCommandData.command then
        if not player:hasRole(demoteMyselfCommandData.roleRequired) then
            return false
        end
        player:setRole(Roles.ROLE_NONE)
        return true
    end
    if command:lower() == buyVIPCommandData.command then
        if player:hasRole(Roles.ROLE_VIP) then
            player:onConsoleMessage("`4Oops: `6You already have `#VIP`` role.``")
            return true
        end
        local hasDiamondLocks = player:getItemAmount(1796)
        if hasDiamondLocks < 100 then
            player:onConsoleMessage("`4Oops: `6You cannot afford `#VIP`` role, you're `#" .. 100 - hasDiamondLocks .. "`` Diamond Locks short!``")
            return true
        end
        if player:changeItem(1796, -100, 0) then
            player:setRole(Roles.ROLE_VIP)
            player:onTalkBubble(player:getNetID(), "Purchased VIP Role for 100 Diamond Locks!", 0)
            return true
        end
        player:onConsoleMessage("`4Oops: `6Something went wrong``")
        return true
    end
    return false
end)