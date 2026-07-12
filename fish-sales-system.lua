-- ─────────────────────────────────────────────────────────────────────────────
-- Fish Sales System with Fish Boost and Webhook Integration
-- Commands: /sellfish, /fishboost
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Fish Sales System")

local DB_PATH = "fish_inventory.db"
local db = sqlite.open(DB_PATH)

_G.FishBoostActive = _G.FishBoostActive or false

local function getWebhookUrl()
    if type(file) == "table" and type(file.read) == "function" then
        if type(file.exists) == "function" and file.exists("config/fish_webhook.txt") then
            local content = file.read("config/fish_webhook.txt")
            if content and content ~= "" then
                return content
            end
        end
    end
    return ""
end

local function setWebhookUrl(url)
    if type(file) == "table" and type(file.write) == "function" then
        file.write("config/fish_webhook.txt", url)
    end
end

local function sendWebhook(status)
    local WEBHOOK_URL = getWebhookUrl()
    if WEBHOOK_URL == "" then return end
    
    local color = 5814783 -- Blue
    if status == "Started" then
        color = 5763719 -- Green
    elseif status == "Stopped" or status == "Ended" then
        color = 15548997 -- Red
    end
    
    local payload = {
        embeds = {
            {
                title = "🚀 Fish Boost " .. status .. "!",
                description = "The server-wide Fish Boost has " .. string.lower(status) .. ". Fish sales now yield **" .. (status == "Started" and "DOUBLE" or "NORMAL") .. "** World Locks!",
                color = color
            }
        }
    }
    
    -- Try using http.post if available
    if type(http) == "table" and type(http.post) == "function" and type(json) == "table" and type(json.encode) == "function" then
        local post_data = json.encode(payload)
        http.post(WEBHOOK_URL, post_data)
    end
end

local function getTieredReward(weight)
    if weight <= 15 then return 6
    elseif weight <= 30 then return 7
    elseif weight <= 60 then return 8
    elseif weight <= 90 then return 10
    elseif weight <= 120 then return 12
    elseif weight <= 160 then return 13
    elseif weight <= 190 then return 14
    else return 15
    end
end

local function formatNum(num)
    local s = tostring(math.floor(tonumber(num) or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return s:gsub("^,", "")
end

local function compressLocksAndGive(world, player, total_wl)
    local rewards = { [242] = total_wl }
    
    if total_wl > 0 then
        local new_black = math.floor(total_wl / 1000000)
        total_wl = total_wl % 1000000
        
        local new_bgl = math.floor(total_wl / 10000)
        total_wl = total_wl % 10000
        
        local new_dl = math.floor(total_wl / 100)
        local new_wl = total_wl % 100
        
        rewards[20628] = new_black
        rewards[7188] = new_bgl
        rewards[1796] = new_dl
        rewards[242] = new_wl
    end
    
    for id, qty in pairs(rewards) do
        if qty > 0 then
            local currentAmt = player:getItemAmount(id) or 0
            
            local success = player:changeItem(id, qty, 0)
            if not success then
                success = player:changeItem(id, qty, 1)
            end
            
            local newAmt = player:getItemAmount(id) or 0
            
            if success and newAmt < (currentAmt + qty) then
                local lost = (currentAmt + qty) - newAmt
                
                local toDrop = lost
                while toDrop > 0 do
                    local dropChunk = math.min(toDrop, 200)
                    world:spawnItem(player:getPosX(), player:getPosY(), id, dropChunk)
                    toDrop = toDrop - dropChunk
                end
                
                player:onConsoleMessage("`4Notice: `oYour inventory couldn't hold everything! Dropped `$" .. lost .. "x`` locks on the ground!``")
            elseif not success then
                local toDrop = qty
                while toDrop > 0 do
                    local dropChunk = math.min(toDrop, 200)
                    world:spawnItem(player:getPosX(), player:getPosY(), id, dropChunk)
                    toDrop = toDrop - dropChunk
                end
                
                player:onConsoleMessage("`4Inventory full! `oDropped `$" .. qty .. "x`` locks on the ground at your position.``")
            end
        end
    end
    return true
end

local FISH_IDS = {
    [3026] = true, -- Catfish
    [3438] = true, -- Seahorse
    [3544] = true, -- Picasso
    [3820] = true, -- Orca
    [4296] = true, -- Training Fish
    [4320] = true, -- Bass
    [4322] = true, -- Trout
    [4324] = true, -- Salmon
    [4326] = true, -- Catfish
    [4328] = true, -- Marlin
    [4330] = true, -- Tuna
    [4332] = true, -- Rainbow Trout
    [4334] = true, -- Goldfish
    [4336] = true, -- Sea Bass
    [4338] = true, -- Snapper
    [4340] = true, -- Carp
    [4342] = true, -- Sunfish
    [4344] = true, -- Mahi-Mahi
    [4346] = true, -- Blobfish
    [4348] = true, -- Sturgeon
    [4350] = true, -- Anglerfish
    [4352] = true, -- Coelacanth
    [4354] = true, -- Flounder
    [4356] = true, -- Halibut
    [4358] = true, -- Mackerel
    [4360] = true, -- Swordfish
    [4362] = true, -- Tigerfish
    [4364] = true, -- Walleye
    [4366] = true, -- Yellowfin Tuna
    [4368] = true, -- Blue Marlin
    [4370] = true, -- Clownfish
    [4372] = true, -- Pufferfish
    [4374] = true, -- Lionfish
}

local function showFishBoostUI(player)
    local status = _G.FishBoostActive and "`2ACTIVE``" or "`4INACTIVE``"
    local buttonStr = _G.FishBoostActive and "add_button|toggle_fishboost|`4Stop Fish Boost``|no_flags|0|0|" or "add_button|toggle_fishboost|`2Start Fish Boost``|no_flags|0|0|"
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wFish Boost Control``|left|4320|")
    table.insert(d, "add_smalltext|`oManage the server-wide Fish Boost event.``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_smalltext|`oCurrent Status: " .. status .. "|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, buttonStr)
    table.insert(d, "add_button|open_webhook_ui|`wConfigure Webhook``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "end_dialog|fish_boost_ui|Close||\nadd_quick_exit|")
    
    player:onDialogRequest(table.concat(d, "\n"))
end

local function showWebhookUI(player)
    local currentUrl = getWebhookUrl()
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wDiscord Webhook Config``|left|4320|")
    table.insert(d, "add_smalltext|`oSet the webhook URL for Fish Boost notifications.``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|webhook_url|Webhook URL:|" .. currentUrl .. "|100|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "end_dialog|fish_webhook_ui|Cancel|Save|\nadd_quick_exit|")
    player:onDialogRequest(table.concat(d, "\n"))
end

local function showFishSellUI(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wFish Market``|left|4320|")
    table.insert(d, "add_smalltext|`oSelect a fish from your inventory to sell, or sell them all at once!``|left|")
    table.insert(d, "add_spacer|small|")
    
    local hasFish = false
    
    for itemID = 1, 10000 do
        if FISH_IDS[itemID] then
            local lbs = player:getItemAmount(itemID)
            if lbs and lbs > 0 then
                hasFish = true
                local itemName = "Fish ID " .. itemID
                if type(getItem) == "function" then
                    local it = getItem(itemID)
                    if it and type(it.getName) == "function" then
                        itemName = it:getName()
                    end
                end
                
                table.insert(d, string.format("add_checkbox|chk_fish_%d|`w%s `o(%d lbs)``|0|", itemID, itemName, lbs))
            end
        end
    end
    
    if hasFish then
        table.insert(d, "add_spacer|small|")
        table.insert(d, "add_button|sell_fish_selected|`9Sell Selected Fish``|no_flags|0|0|")
        table.insert(d, "add_button|sell_fish_all|`2$$ Sell All Fish $$``|no_flags|0|0|")
    else
        table.insert(d, "add_smalltext|`4You don't have any physical fish to sell! Catch some first.``|left|")
    end
    
    table.insert(d, "add_spacer|small|")
    table.insert(d, "end_dialog|fish_sell_main_ui|Close||\nadd_quick_exit|")
    player:onDialogRequest(table.concat(d, "\n"))
end

local function showFishConfirmUI(player, targetItem)
    local totalWl = 0
    local isAll = (targetItem == "all")
    local selectedIds = {}
    
    if not isAll then
        for idStr in targetItem:gmatch("%d+") do
            selectedIds[tonumber(idStr)] = true
        end
    end
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wConfirm Sale``|left|4320|")
    table.insert(d, "add_spacer|small|")
    
    local hasItems = false
    
    for itemID = 1, 10000 do
        if FISH_IDS[itemID] then
            if isAll or selectedIds[itemID] then
                local lbs = player:getItemAmount(itemID)
                if lbs and lbs > 0 then
                    hasItems = true
                    local wl = getTieredReward(lbs)
                    totalWl = totalWl + wl
                    
                    local itemName = "Fish ID " .. itemID
                    if type(getItem) == "function" then
                        local it = getItem(itemID)
                        if it and type(it.getName) == "function" then
                            itemName = it:getName()
                        end
                    end
                    
                    table.insert(d, "add_smalltext|`o" .. itemName .. ": `w" .. lbs .. " lbs`` -> `$" .. wl .. " WL``|left|")
                end
            end
        end
    end
    
    if not hasItems then
        player:onConsoleMessage("`4Oops: `oYou don't have enough fish for this transaction!``")
        return
    end
    
    if _G.FishBoostActive then
        totalWl = totalWl * 2
    end
    
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_smalltext|`oExpected Total Payout: `$" .. totalWl .. " World Locks``" .. (_G.FishBoostActive and " `5(2x BOOST!)``" or "") .. "|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_smalltext|`4Warning: `oThis action cannot be undone!``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|confirm_sell_" .. targetItem .. "|`2Confirm Sale``|no_flags|0|0|")
    table.insert(d, "add_button|cancel_sell|`4Cancel``|no_flags|0|0|")
    
    table.insert(d, "end_dialog|fish_sell_confirm_ui|Close||\nadd_quick_exit|")
    player:onDialogRequest(table.concat(d, "\n"))
end

-- Command registrations
registerLuaCommand({
    command      = "fishboost",
    roleRequired = 51,
    description  = "Open UI to toggle the server-wide Fish Boost"
})

registerLuaCommand({
    command      = "fishwebhook",
    roleRequired = 51,
    description  = "Open UI to configure Fish Boost Discord Webhook"
})

registerLuaCommand({
    command      = "sellfish",
    roleRequired = 0,
    description  = "Sell all your physical Growtopia fish from your inventory for World Locks!"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == "fishboost" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access Denied: `oYou do not have permission to use this command.``")
            return true
        end
        
        showFishBoostUI(player)
        return true
    end

    if cmd:lower() == "fishwebhook" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access Denied: `oYou do not have permission to use this command.``")
            return true
        end
        
        showWebhookUI(player)
        return true
    end
    
    if cmd:lower() == "sellfish" then
        showFishSellUI(player)
        return true
    end
    
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    if data["dialog_name"] == "fish_boost_ui" then
        if data["buttonClicked"] == "toggle_fishboost" then
            if not player:hasRole(51) then return true end
            
            _G.FishBoostActive = not _G.FishBoostActive
            local statusStr = _G.FishBoostActive and "Started" or "Ended"
            
            player:onConsoleMessage("`6>> `oFish Boost has been " .. (_G.FishBoostActive and "`2Activated" or "`4Deactivated") .. "`o!``")
            
            -- Send webhook
            sendWebhook(statusStr)
            
            -- Refresh UI
            showFishBoostUI(player)
        elseif data["buttonClicked"] == "open_webhook_ui" then
            if not player:hasRole(51) then return true end
            showWebhookUI(player)
        end
        return true
    end
    
    if data["dialog_name"] == "fish_webhook_ui" then
        if data["buttonClicked"] == "1" then
            if not player:hasRole(51) then return true end
            local newUrl = data["webhook_url"] or ""
            setWebhookUrl(newUrl)
            player:onConsoleMessage("`2>> `oFish Boost Webhook URL has been updated and saved!``")
            showFishBoostUI(player)
        elseif data["buttonClicked"] == "0" then
            -- Back to main boost UI if cancelled
            if player:hasRole(51) then
                showFishBoostUI(player)
            end
        end
        return true
    end
    
    if data["dialog_name"] == "fish_sell_main_ui" then
        if data["buttonClicked"] == "sell_fish_all" then
            showFishConfirmUI(player, "all")
        elseif data["buttonClicked"] == "sell_fish_selected" then
            local selected = {}
            for k, v in pairs(data) do
                if k:match("^chk_fish_(%d+)$") and v == "1" then
                    table.insert(selected, k:match("^chk_fish_(%d+)$"))
                end
            end
            
            if #selected == 0 then
                player:onConsoleMessage("`4Oops: `oYou didn't select any fish to sell!``")
                showFishSellUI(player)
                return true
            end
            
            showFishConfirmUI(player, table.concat(selected, ","))
        end
        return true
    end
    
    if data["dialog_name"] == "fish_sell_confirm_ui" then
        if data["buttonClicked"] == "cancel_sell" then
            showFishSellUI(player)
            return true
        end
        
        if data["buttonClicked"] then
            local confirmTarget = data["buttonClicked"]:match("^confirm_sell_(.+)$")
            if confirmTarget then
                local totalWorldLocks = 0
                local totalFishSold = 0
                
                local isAll = (confirmTarget == "all")
                local selectedIds = {}
                if not isAll then
                    for idStr in confirmTarget:gmatch("%d+") do
                        selectedIds[tonumber(idStr)] = true
                    end
                end
                
                for itemID = 1, 10000 do
                    if FISH_IDS[itemID] then
                        if isAll or selectedIds[itemID] then
                            local lbs = player:getItemAmount(itemID)
                            if lbs and lbs > 0 then
                                totalWorldLocks = totalWorldLocks + getTieredReward(lbs)
                                player:changeItem(itemID, -lbs, 0)
                                totalFishSold = totalFishSold + lbs
                            end
                        end
                    end
                end
                
                if totalFishSold > 0 then
                    if _G.FishBoostActive then
                        totalWorldLocks = totalWorldLocks * 2
                    end
                    
                    if compressLocksAndGive(world, player, totalWorldLocks) then
                        local boostMsg = _G.FishBoostActive and " `5(Fish Boost 2x Active!)``" or "``"
                        player:onConsoleMessage("`2>> Success: `oSold `w" .. formatNum(totalFishSold) .. " lbs `oof fish for `$" .. formatNum(totalWorldLocks) .. " World Locks``!" .. boostMsg)
                        player:onParticleEffect(45, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
                    end
                else
                    player:onConsoleMessage("`4Oops: `oTransaction failed or fish no longer in inventory!``")
                end
            end
        end
        return true
    end
    
    return false
end)
