-- Login Message script
print("(Loaded) Login Message script Kon")

onPlayerLoginCallback(function(player)
    local name = player:getCleanName()
    local level = player:getLevel() or 1
    local playtimeHours = string.format("%.2f", (player:getPlaytime() or 0) / 3600)
    
    -- Play a welcome chime
    player:playAudio("piano_nice.wav")
    
    -- Show a stylish screen overlay
    player:onTextOverlay("`2Welcome back, `w" .. name .. "``!``")
    
    -- Float a bubble above their avatar
    player:onTalkBubble(player:getNetID(), "`2Glad to have you back!``", 0)
    
    -- Print a gorgeous console card
    player:onConsoleMessage("`6==================================================")
    player:onConsoleMessage("`6>> `2Welcome back to `wKon PS``, `5" .. name .. "``!``")
    player:onConsoleMessage("`6>> `oYour Level: `w" .. level .. "`` | Playtime: `w" .. playtimeHours .. " hours``")
    player:onConsoleMessage("`6>> `oType `$/discord`` to join our community or `$/news`` for updates!")
    player:onConsoleMessage("`6==================================================")
end)
