-- ─────────────────────────────────────────────────────────────────────────────
-- Fishing Config Editor
-- Command: /editfishconfig (Developer Only)
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Fishing Config Editor")

local ROLE_DEVELOPER = 51
local FISHING_CONFIG_PATH = "config/fishing.json"

registerLuaCommand({
    command      = "editfishconfig",
    roleRequired = ROLE_DEVELOPER,
    description  = "Edit the fishing.json wait_time for rods!"
})

local sessions = {}

local function readConfig()
    local content = file.read(FISHING_CONFIG_PATH)
    if not content or content == "" then return nil end
    return json.decode(content)
end

local function writeConfig(data)
    local content = json.encode(data)
    file.write(FISHING_CONFIG_PATH, content)
    return true
end

local function getWaitTime(config, rodID)
    if not config or not config.config or not config.config.wait_time then return nil end
    for _, entry in ipairs(config.config.wait_time) do
        if entry[1] == rodID then
            return entry[2]
        end
    end
    return nil
end

local function setWaitTime(config, rodID, newTime)
    if not config.config.wait_time then
        config.config.wait_time = {}
    end
    
    -- Check if it exists and update or remove
    for i, entry in ipairs(config.config.wait_time) do
        if entry[1] == rodID then
            if newTime == nil then
                table.remove(config.config.wait_time, i)
            else
                entry[2] = newTime
            end
            return
        end
    end
    
    -- If we get here and newTime is not nil, add it
    if newTime ~= nil then
        table.insert(config.config.wait_time, {rodID, newTime})
    end
end

local function showMainEditor(player)
    local config = readConfig()
    if not config then
        player:onConsoleMessage("`4Error: Could not read config/fishing.json!``")
        return
    end

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Fishing Config Editor``|left|3228|")
    table.insert(d, "add_smalltext|`oSelect a rod below to edit its wait time!``|left|")
    table.insert(d, "add_spacer|small|")

    local allowedRods = config.config.allowed_rods or {}
    for _, rodID in ipairs(allowedRods) do
        local itemName = ""
        if _G.getItemName then itemName = _G.getItemName(rodID) end
        if itemName == "" then itemName = "Rod Item #" .. rodID end
        
        local currentWait = getWaitTime(config, rodID)
        local waitText = currentWait and ("`2" .. currentWait .. " ms``") or "`4Default``"
        
        table.insert(d, "add_label_with_icon|small|`w" .. itemName .. "``|left|" .. rodID .. "|")
        table.insert(d, "add_smalltext|`oWait Time: " .. waitText .. "|left|")
        table.insert(d, "add_button|edit_wait_" .. rodID .. "|`5Edit Wait Time``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end

    table.insert(d, "add_button|fce_close|`oClose``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fishing_config_main|Close||\n" ..
        "add_quick_exit|"
    )
end

local function showEditWaitTime(player, rodID)
    local config = readConfig()
    if not config then return end
    
    local itemName = ""
    if _G.getItemName then itemName = _G.getItemName(rodID) end
    if itemName == "" then itemName = "Rod Item #" .. rodID end
    
    local currentWait = getWaitTime(config, rodID)
    local defaultInput = currentWait and tostring(currentWait) or ""
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Edit Wait Time``|left|" .. rodID .. "|")
    table.insert(d, "add_smalltext|`oRod: `w" .. itemName .. "``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_textbox|`oEnter the new wait time (in milliseconds). Leave blank to revert to default!``|left|")
    table.insert(d, "add_text_input|new_wait_time||" .. defaultInput .. "|10|")
    table.insert(d, "add_spacer|small|")
    
    -- Store the rod ID in a hidden button/input or just use sessions
    sessions[tostring(player:getNetID())] = { editingRod = rodID }
    
    table.insert(d, "add_button|fce_save_wait|`2Save Changes``|no_flags|0|0|")
    table.insert(d, "add_button|fce_back|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fishing_config_edit|Close||\n" ..
        "add_quick_exit|"
    )
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == "debugglobals" then
        if player:hasRole(51) then
            local found = {}
            for k, v in pairs(_G) do
                if type(k) == "string" and type(v) == "function" then
                    local lk = k:lower()
                    if lk:find("file") or lk:find("write") or lk:find("save") or lk:find("json") or lk:find("read") or lk:find("config") then
                        table.insert(found, k)
                    end
                end
            end
            player:onConsoleMessage("Found: " .. table.concat(found, ", "))
        end
        return true
    end

    if cmd:lower() == "editfishconfig" then
        if player:hasRole(ROLE_DEVELOPER) then
            showMainEditor(player)
        else
            player:onConsoleMessage("`4You don't have permission to use this command!``")
        end
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local clicked = data["buttonClicked"] or ""

    if dlg == "portal_shortcuts" and clicked == "sc_fishconfig" then
        if player:hasRole(51) then showMainEditor(player) end
        return true
    end

    if dlg == "fishing_config_main" then
        if clicked == "fce_close" then return true end
        
        local rodID = tonumber(clicked:match("^edit_wait_(%d+)$"))
        if rodID then
            showEditWaitTime(player, rodID)
            return true
        end
        return true
    end
    
    if dlg == "fishing_config_edit" then
        if clicked == "fce_back" then
            showMainEditor(player)
            return true
        end
        
        if clicked == "fce_save_wait" then
            local sess = sessions[tostring(player:getNetID())]
            if not sess or not sess.editingRod then return true end
            
            local rodID = sess.editingRod
            local inputStr = data["new_wait_time"] or ""
            local newWait = tonumber(inputStr)
            
            local config = readConfig()
            if config then
                setWaitTime(config, rodID, newWait)
                if writeConfig(config) then
                    if newWait then
                        player:onConsoleMessage("`2>> Saved wait time for rod " .. rodID .. " as " .. newWait .. " ms!``")
                    else
                        player:onConsoleMessage("`2>> Reverted wait time for rod " .. rodID .. " to default!``")
                    end
                else
                    player:onConsoleMessage("`4>> Error writing to config/fishing.json!``")
                end
            end
            
            showMainEditor(player)
            return true
        end
        return true
    end

    return false
end)
