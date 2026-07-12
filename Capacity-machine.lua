-- Capacity-machine script
print("(Loaded) Capacity-machine script for GTPS Cloud")

registerLuaCommand({
    command = "setcap",
    roleRequired = 51,
    description = "Modify global machine capacity. Usage: /setcap <itemID> <value>"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)")
    
    if cmd == "setcap" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access Denied: `oInsufficient permissions.")
            return true
        end

        local targetID, capValue = args:match("^(%d+)%s+(%d+)$")
        
        if not targetID or not capValue then
            player:onConsoleMessage("`4Invalid Syntax! `oUsage: `w/setcap <itemID> <capacity>")
            return true
        end

        targetID = tonumber(targetID)
        capValue = tonumber(capValue)

        local itemData = getItem(targetID)
        
        if itemData then
            local previousCap = itemData:getMachineCap()
            itemData:setMachineCap(capValue)
            
            player:onConsoleMessage("`2Success! `w" .. itemData:getName() .. " (ID: " .. targetID .. ")")
            player:onConsoleMessage("`oCapacity updated: `w" .. previousCap .. " `2-> `w" .. capValue)
        else
            player:onConsoleMessage("`4Error: `oItem ID `w" .. targetID .. " `onot found in database.")
        end

        return true
    end

    return false
end)