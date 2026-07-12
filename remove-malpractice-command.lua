print("(Loaded) Remove Malpractice Command v3")

local ROLE_DEVELOPER = 51

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    cmd = cmd:lower()
    
    if cmd == "clearmalpractice" or cmd == "curemalpractice" or cmd == "rmmalpractice" then
        if not player:hasRole(ROLE_DEVELOPER) then
            return false
        end
        
        local targetName = fullCommand:match("^%S+%s+(.*)$")
        local target = player
        
        if targetName and targetName ~= "" then
            target = world:getPlayerByName(targetName)
            if not target then
                player:onConsoleMessage("`4Player not found in this world!``")
                return true
            end
        end
        
        local found = false
        
        -- Try to remove by setting duration to 0
        if type(target.getMods) == "function" and type(target.addMod) == "function" then
            local mods = target:getMods()
            if mods then
                for i = 1, #mods do
                    local mod = mods[i]
                    if mod and type(mod.getName) == "function" then
                        local name = mod:getName(target)
                        player:onConsoleMessage("`wChecking Mod: " .. (name or "Unknown") .. "``")
                        if name and name:lower():find("malpractice") then
                            found = true
                            if type(mod.getItemID) == "function" then
                                local mId = mod:getItemID()
                                player:onConsoleMessage("`wFound Malpractice with ItemID: " .. tostring(mId) .. "``")
                                -- Overwrite the mod with 0 duration to remove it
                                target:addMod(mId, 0)
                            end
                        end
                    end
                end
            end
        end
        
        if found then
            target:onConsoleMessage("`2>> Your malpractice status was removed!``")
            target:playAudio("piano_nice.wav")
            if target:getNetID() ~= player:getNetID() then
                player:onConsoleMessage("`2>> Removed malpractice status from " .. target:getCleanName() .. "``")
            end
        else
            player:onConsoleMessage("`4Could not find a 'Malpractice' status on the player!``")
            player:onConsoleMessage("`w(If they still have it, it might be stored differently in this engine.)``")
        end
        
        return true
    end
    
    return false
end)
