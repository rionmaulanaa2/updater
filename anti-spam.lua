-- Anti-Spam script
print("(Loaded) Anti-Spam script for GrowSoft")

local ccModData = {
    modID = -1000, -- The number should be negative, for example if you wanna add another mod use the ID -1001, make sure it never duplicates
    modName = "Chat Cooldown",
    onAddMessage = "You need to chill a little bit!",
    onRemoveMessage = "You can now be no-chill again.",
    iconID = 660
}

local ccModID = registerLuaPlaymod(ccModData)

local chatCooldowns = {}

onPlayerChatCallback(function(world, player, message)
    if player:hasMod(ccModID) then
        player:onConsoleMessage("`6>>`4Spam detected! ``Please wait a bit before typing anything else.  Please note, any form of bot/macro/auto-paste will get all your accounts banned, so don't do it!")
        return true
    end
    
    local now = os.time() * 1000

    if not chatCooldowns[player:getUserID()] then
        chatCooldowns[player:getUserID()] = {lastChatTime = 0, spamCount = 0}
    end

    local cooldownData = chatCooldowns[player:getUserID()]

    if now - cooldownData.lastChatTime < 1500 then
        cooldownData.spamCount = cooldownData.spamCount + 1

        if cooldownData.spamCount >= 5 then
            player:addMod(ccModID, 10)
            return true
        end
    else
        cooldownData.spamCount = 0
    end

    cooldownData.lastChatTime = now

    return false
end)
