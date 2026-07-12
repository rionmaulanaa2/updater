print("(Loaded) Fish Exchange Config Editor")

local ROLE_DEVELOPER = 51
local CONFIG_PATH = "config/fish_exchange.json"

registerLuaCommand({
    command      = "fishexch",
    roleRequired = ROLE_DEVELOPER,
    description  = "Edit virtual fish exchange payouts (e.g. WLs instead of Gems)!"
})

local sessions = {}

local function getSession(player)
    local id = player:getNetID()
    if not sessions[id] then sessions[id] = {} end
    return sessions[id]
end

local function readConfig()
    -- Read config safely
    if type(file.read) == "function" then
        local content = file.read(CONFIG_PATH)
        if content and content ~= "" then
            return json.decode(content) or {}
        end
    end
    return {}
end

local function writeConfig(data)
    local content = json.encode(data)
    file.write(CONFIG_PATH, content)
end

local function getItemName(itemID)
    if type(getItem) == "function" then
        local item = getItem(itemID)
        if item and type(item.getName) == "function" then
            return item:getName()
        end
    end
    return "Item ID " .. itemID
end

local function showMainUI(player)
    local config = readConfig()
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wFish Exchange Editor``|left|112|")
    table.insert(d, "add_smalltext|`oMap virtual fishes to custom rewards! (ID -1 means give Gems)``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|fe_add|`$Add New Mapping``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")

    local count = 0
    for fishName, reward in pairs(config) do
        count = count + 1
        local rID = tonumber(reward.id) or -1
        local rQty = tonumber(reward.qty) or 1
        local applyV = reward.variants and " `w(All Sizes)``" or " `o(Exact Only)``"
        
        local rewardStr = rID == -1 and ("`2" .. rQty .. " Gems``") or ("`w" .. rQty .. "x " .. getItemName(rID) .. "``")
        local iconID = rID == -1 and 112 or rID
        
        table.insert(d, "add_label_with_icon|small|`w" .. fishName .. applyV .. " `o-> " .. rewardStr .. "|left|" .. iconID .. "|")
        table.insert(d, "add_button|fe_edit_" .. fishName .. "|`5Edit``|no_flags|0|0|")
        table.insert(d, "add_button|fe_rm_" .. fishName .. "|`4Remove``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end
    
    if count == 0 then
        table.insert(d, "add_smalltext|`4No custom mappings found. All fish will give standard Gems.``|left|")
    end

    table.insert(d, "add_button|fe_close|`oClose``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fe_main_ui|Close||\n" ..
        "add_quick_exit|"
    )
end

local function showEditUI(player, editFishName)
    local config = readConfig()
    
    local fName = editFishName or ""
    local rID = -1
    local rQty = 1
    local applyV = 0
    
    if editFishName and config[editFishName] then
        rID = config[editFishName].id
        rQty = config[editFishName].qty
        applyV = config[editFishName].variants and 1 or 0
    end
    
    local sess = getSession(player)
    sess.editTarget = editFishName -- nil means new mapping
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`w" .. (editFishName and "Edit" or "Add") .. " Mapping``|left|112|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_text_input|fish_name|Fish Name (Exact or Base):|" .. fName .. "|32|")
    table.insert(d, "add_text_input|reward_id|Reward Item ID (-1 for Gems):|" .. rID .. "|10|")
    table.insert(d, "add_text_input|reward_qty|Reward Quantity:|" .. rQty .. "|10|")
    table.insert(d, "add_checkbox|apply_variants|Apply to all sizes/prefixes?|" .. applyV .. "|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|fe_save|`2Save Mapping``|no_flags|0|0|")
    table.insert(d, "add_button|fe_cancel|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fe_edit_ui|Close||\n" ..
        "add_quick_exit|"
    )
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    if cmd:lower() == "fishexch" then
        if not player:hasRole(ROLE_DEVELOPER) then return false end
        showMainUI(player)
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"]
    local clicked = data["buttonClicked"]

    if dlg == "fe_main_ui" then
        if clicked == "fe_add" then
            showEditUI(player, nil)
            return true
        end
        
        local rmMatch = clicked:match("^fe_rm_(.+)$")
        if rmMatch then
            local config = readConfig()
            config[rmMatch] = nil
            writeConfig(config)
            player:onConsoleMessage("`4>> Removed mapping for " .. rmMatch .. "``")
            showMainUI(player)
            return true
        end
        
        local edMatch = clicked:match("^fe_edit_(.+)$")
        if edMatch then
            showEditUI(player, edMatch)
            return true
        end
    end
    
    if dlg == "fe_edit_ui" then
        if clicked == "fe_cancel" then
            showMainUI(player)
            return true
        end
        if clicked == "fe_save" then
            local fName = data["fish_name"]
            local rID = tonumber(data["reward_id"])
            local rQty = tonumber(data["reward_qty"])
            local applyV = (data["apply_variants"] == "1")
            
            if not fName or fName == "" or not rID or not rQty then
                player:onConsoleMessage("`4>> Invalid input! Make sure fields are correct.``")
                showMainUI(player)
                return true
            end
            
            local config = readConfig()
            local sess = getSession(player)
            
            -- If we were editing an existing one, remove the old name in case they renamed it
            if sess.editTarget and sess.editTarget ~= fName then
                config[sess.editTarget] = nil
            end
            
            config[fName] = { id = rID, qty = math.floor(rQty), variants = applyV }
            writeConfig(config)
            
            player:onConsoleMessage("`2>> Saved mapping for " .. fName .. "!``")
            showMainUI(player)
            return true
        end
    end
    return false
end)
