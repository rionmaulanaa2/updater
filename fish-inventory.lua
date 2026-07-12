-- ─────────────────────────────────────────────────────────────────────────────
-- Virtual Fish Inventory System
-- Command: /fishinv
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Virtual Fish Inventory System")

local DB_PATH = "fish_inventory.db"
local db = sqlite.open(DB_PATH)

local function initDB()
    db:query([[
        CREATE TABLE IF NOT EXISTS inventory (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id    INTEGER NOT NULL,
            fish_name    TEXT NOT NULL,
            icon_id      INTEGER NOT NULL,
            total_caught INTEGER NOT NULL DEFAULT 1,
            max_weight   REAL NOT NULL DEFAULT 0.0,
            last_caught  INTEGER
        )
    ]])
end
initDB()

-- ─── Economy Calculator ───────────────────────────────────────────────────────
_G.calculateFishValue = function(player, fishName)
    local baseVal = 50
    local rarityMatch = fishName:match("%[(.-)%]")
    if rarityMatch then
        local r = rarityMatch:lower()
        if r == "normal" then baseVal = 50
        elseif r == "rare" then baseVal = 100
        elseif r == "super rare" then baseVal = 250
        elseif r == "ultra rare" then baseVal = 1000
        elseif r == "legendary" then baseVal = 10000
        elseif r == "mythical" then baseVal = 100000
        end
    end

    local multiplier = 1
    local nameLower = fishName:lower()
    
    -- x2 Multipliers
    for _, v in ipairs({"gold", "diamond", "big"}) do
        if nameLower:find(v) then multiplier = multiplier * 2 end
    end
    
    -- x4 Multipliers
    for _, v in ipairs({"rainbow", "godly", "mutated", "devil"}) do
        if nameLower:find(v) then multiplier = multiplier * 4 end
    end
    
    local finalVal = baseVal * multiplier
    
    -- Apply Master Fisher stat buff!
    if player and _G.getRodBuffs then
        local equippedRod = player:getClothingItemID(5)
        local buffs = _G.getRodBuffs(player:getUserID(), equippedRod)
        local masterFisherLevel = 0
        for i = 1, 3 do
            if buffs[i].type == "Master Fisher" then
                masterFisherLevel = masterFisherLevel + buffs[i].level
            end
        end
        if masterFisherLevel > 0 then
            -- 0.001% per level
            local bonus = finalVal * (masterFisherLevel * 0.00001)
            finalVal = finalVal + bonus
        end
    end
    
    return math.floor(finalVal)
end

local function formatNum(num)
    local s = tostring(math.floor(tonumber(num) or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return s:gsub("^,", "")
end

-- ─── UI Helpers ───────────────────────────────────────────────────────────────
local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(20, 50, 70, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(0, 150, 255, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- ─── UI: Fish Inventory Album ─────────────────────────────────────────────────
function showFishInventory(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9My Fishing Album``|left|4320|")
    table.insert(d, "add_smalltext|`oA collection of all your caught virtual and custom fishes!``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`o════════════════════════════════``|left|")
    table.insert(d, "add_spacer|small|")
    
    local userID = player:getUserID()
    local rows = db:query(string.format("SELECT * FROM inventory WHERE player_id = %d ORDER BY total_caught DESC", userID))
    
    if not rows or #rows == 0 then
        table.insert(d, "add_textbox|`oYou haven't caught any custom fish yet. Get out there and fish!``|left|")
    else
        table.insert(d, "add_smalltext|`oClick 'Exchange' to sell your fish for gems!``|left|")
        table.insert(d, "add_button|sell_all_fish|`$Exchange ALL Fish!``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
        for i, row in ipairs(rows) do
            local fishName = row.fish_name
            local iconID = tonumber(row.icon_id)
            local count = tonumber(row.total_caught)
            local weight = tonumber(row.max_weight)
            local val = _G.calculateFishValue(player, fishName)
            
            table.insert(d, string.format("add_button_with_icon|noop%d||staticBlueFrame,no_padding_x,disabled|%d||", i, iconID))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
            table.insert(d, "add_smalltext|`w" .. fishName .. "``|left|")
            table.insert(d, "add_smalltext|`oCaught: `$" .. count .. "x  `o|  Value: `2" .. formatNum(val) .. " Gems``|left|")
            table.insert(d, "add_button|sellfish_" .. row.id .. "|`2Exchange``|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|fishinv_close|`oClose``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fish_inventory_dialog|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── UI: Sell Prompt ──────────────────────────────────────────────────────────
local sessions = {}
local function getSession(player)
    local id = tostring(player:getNetID())
    if not sessions[id] then sessions[id] = {} end
    return sessions[id]
end

local function readFishExchangeConfig()
    if type(file.read) == "function" then
        local content = file.read("config/fish_exchange.json")
        if content and content ~= "" then
            return json.decode(content) or {}
        end
    end
    return {}
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

local function getFishCustomReward(config, fishName)
    if config[fishName] then return config[fishName] end
    local lowerName = fishName:lower()
    for baseName, rewardData in pairs(config) do
        if rewardData.variants and string.find(lowerName, baseName:lower(), 1, true) then
            return rewardData
        end
    end
    return nil
end

local function compressLocks(rewards)
    local wl = rewards[242] or 0
    local dl = rewards[1796] or 0
    local bgl = rewards[7188] or 0
    local black = rewards[20628] or 0
    
    local total_wl = wl + (dl * 100) + (bgl * 10000) + (black * 1000000)
    
    if total_wl > 0 then
        rewards[242] = nil
        rewards[1796] = nil
        rewards[7188] = nil
        rewards[20628] = nil
        
        local new_black = math.floor(total_wl / 1000000)
        total_wl = total_wl % 1000000
        
        local new_bgl = math.floor(total_wl / 10000)
        total_wl = total_wl % 10000
        
        local new_dl = math.floor(total_wl / 100)
        local new_wl = total_wl % 100
        
        if new_black > 0 then rewards[20628] = new_black end
        if new_bgl > 0 then rewards[7188] = new_bgl end
        if new_dl > 0 then rewards[1796] = new_dl end
        if new_wl > 0 then rewards[242] = new_wl end
    end
    return rewards
end

local function showSellAllPrompt(player)
    local userID = player:getUserID()
    local rows = db:query(string.format("SELECT * FROM inventory WHERE player_id = %d", userID))
    if not rows or #rows == 0 then return end
    
    local config = readFishExchangeConfig()
    local totalGems = 0
    local totalFish = 0
    local customRewards = {}
    
    for _, row in ipairs(rows) do
        local count = tonumber(row.total_caught) or 0
        if count > 0 then
            totalFish = totalFish + count
            local custom = getFishCustomReward(config, row.fish_name)
            
            if custom then
                local rID = tonumber(custom.id) or -1
                local rQty = (tonumber(custom.qty) or 1) * count
                if rID == -1 then
                    totalGems = totalGems + rQty
                else
                    customRewards[rID] = (customRewards[rID] or 0) + rQty
                end
            else
                totalGems = totalGems + (_G.calculateFishValue(player, row.fish_name) * count)
            end
        end
    end
    
    customRewards = compressLocks(customRewards)
    
    local sess = getSession(player)
    sess.sellAllAmount = totalGems
    sess.sellAllCount = totalFish
    sess.customRewards = customRewards
    
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`4Exchange All Fish!``|left|112|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_textbox|`4WARNING: `oThis will sell EVERY fish in your entire virtual album!``|left|")
    table.insert(d, "add_smalltext|`oTotal Fish Being Sold: `$" .. totalFish .. "x``|left|")
    table.insert(d, "add_smalltext|`oTotal Gems You Will Receive: `2" .. formatNum(totalGems) .. " Gems``|left|")
    if next(customRewards) then
        table.insert(d, "add_smalltext|`oItem Rewards:``|left|")
        for rID, rQty in pairs(customRewards) do
            table.insert(d, "add_label_with_icon|small|   `w" .. rQty .. "x " .. getItemName(rID) .. "``|left|" .. rID .. "|")
        end
    end
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|do_sell_all|`2YES, Exchange Everything!``|no_flags|0|0|")
    table.insert(d, "add_button|cancel_sell|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fish_sell_all_prompt|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

local function showSellPrompt(player, rowID)
    local userID = player:getUserID()
    local rows = db:query(string.format("SELECT * FROM inventory WHERE id = %d AND player_id = %d", rowID, userID))
    if not rows or #rows == 0 then return end
    
    local row = rows[1]
    local val = _G.calculateFishValue(player, row.fish_name)
    local maxCount = tonumber(row.total_caught)
    
    local sess = getSession(player)
    sess.sellRowID = rowID
    
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`2Exchange Fish``|left|" .. row.icon_id .. "|")
    table.insert(d, "add_spacer|small|")
    
    local config = readFishExchangeConfig()
    local custom = getFishCustomReward(config, row.fish_name)
    local valStr = ""
    local valIcon = 112
    if custom then
        local rID = tonumber(custom.id) or -1
        local rQty = tonumber(custom.qty) or 1
        if rID == -1 then
            valStr = "`2" .. formatNum(rQty) .. " Gems (Custom)``"
        else
            valStr = "`w" .. rQty .. "x " .. getItemName(rID) .. " (Custom)``"
            valIcon = rID
        end
    else
        valStr = "`2" .. formatNum(val) .. " Gems``"
    end
    
    table.insert(d, "add_smalltext|`oYou are about to sell: `w" .. row.fish_name .. "``|left|")
    table.insert(d, "add_smalltext|`oYou currently have: `$" .. maxCount .. "x``|left|")
    table.insert(d, "add_label_with_icon|small|`oValue per fish: " .. valStr .. "|left|" .. valIcon .. "|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_text_input|sell_amount|Amount to Sell:|1|10|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|do_sell_fish|`2Confirm Sale``|no_flags|0|0|")
    table.insert(d, "add_button|cancel_sell|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fish_sell_prompt|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Commands ─────────────────────────────────────────────────────────────────
registerLuaCommand({
    command      = "fishinv",
    roleRequired = 0,
    description  = "Open your personal fishing album to see your custom catches!"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    if cmd:lower() == "fishinv" then
        showFishInventory(player)
        return true
    end
    return false
end)

-- ─── Dialog Callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"]
    local clicked = data["buttonClicked"]

    if dlg == "portal_shortcuts" and clicked == "sc_fishinv" then
        showFishInventory(player)
        return true
    end

    if dlg == "fish_inventory_dialog" then
        if clicked == "sell_all_fish" then
            showSellAllPrompt(player)
            return true
        end
        if clicked then
            local sellID = tonumber(clicked:match("^sellfish_(%d+)$"))
            if sellID then
                showSellPrompt(player, sellID)
                return true
            end
        end
        return true
    end
    
    if dlg == "fish_sell_all_prompt" then
        if clicked == "cancel_sell" then
            showFishInventory(player)
            return true
        end
        if clicked == "do_sell_all" then
            local sess = getSession(player)
            local totalGems = sess.sellAllAmount or 0
            local totalFish = sess.sellAllCount or 0
            local customRewards = sess.customRewards or {}
            
            if totalFish > 0 then
                local userID = player:getUserID()
                db:query(string.format("DELETE FROM inventory WHERE player_id = %d", userID))
                
                if totalGems > 0 then
                    player:addGems(totalGems, 0, 1)
                end
                
                customRewards = compressLocks(customRewards)
                
                for rID, rQty in pairs(customRewards) do
                    if not player:changeItem(rID, rQty, 0) then
                        if not player:changeItem(rID, rQty, 1) then
                            world:spawnItem(player:getPosX(), player:getPosY(), rID, rQty)
                            player:onConsoleMessage("`4Inventory full! Dropped " .. rQty .. "x " .. getItemName(rID) .. " on the ground.``")
                        end
                    end
                end
                
                player:onConsoleMessage("`2>> Mass Exchange: Sold " .. totalFish .. " fish! (Gained " .. formatNum(totalGems) .. " Gems and Custom Rewards)``")
                player:onParticleEffect(45, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            end
            
            sess.sellAllAmount = nil
            sess.sellAllCount = nil
            sess.customRewards = nil
            showFishInventory(player)
            return true
        end
        return true
    end
    
    if dlg == "fish_sell_prompt" then
        if clicked == "cancel_sell" then
            showFishInventory(player)
            return true
        end
        if clicked == "do_sell_fish" then
            local sess = getSession(player)
            local rowID = sess.sellRowID
            if not rowID then return true end
            
            local amt = math.floor(tonumber(data["sell_amount"]) or 0)
            if amt <= 0 then
                player:onConsoleMessage("`4Invalid amount.``")
                return true
            end
            
            local userID = player:getUserID()
            local rows = db:query(string.format("SELECT * FROM inventory WHERE id = %d AND player_id = %d", rowID, userID))
            if not rows or #rows == 0 then return true end
            
            local row = rows[1]
            local currentCount = tonumber(row.total_caught)
            
            if amt > currentCount then
                player:onConsoleMessage("`4You don't have that many to sell!``")
                return true
            end
            
            local config = readFishExchangeConfig()
            local customReward = getFishCustomReward(config, row.fish_name)
            
            if customReward then
                local rID = tonumber(customReward.id) or -1
                local rQty = tonumber(customReward.qty) or 1
                local totalRewardQty = rQty * amt
                
                if rID == -1 then
                    player:addGems(totalRewardQty, 0, 1)
                    player:onConsoleMessage("`2>> Sold " .. amt .. "x " .. row.fish_name .. " for " .. formatNum(totalRewardQty) .. " Gems! (Custom Rate)``")
                else
                    local rewardsToGive = { [rID] = totalRewardQty }
                    rewardsToGive = compressLocks(rewardsToGive)
                    
                    local msg = ""
                    for id, qty in pairs(rewardsToGive) do
                        if not player:changeItem(id, qty, 0) then
                            if not player:changeItem(id, qty, 1) then
                                world:spawnItem(player:getPosX(), player:getPosY(), id, qty)
                                player:onConsoleMessage("`4Inventory full! Dropped " .. qty .. "x " .. getItemName(id) .. " on the ground.``")
                            end
                        end
                        msg = msg .. qty .. "x " .. getItemName(id) .. " "
                    end
                    
                    player:onConsoleMessage("`2>> Sold " .. amt .. "x " .. row.fish_name .. " for " .. msg .. "! (Custom Rate)``")
                end
            else
                local valPerFish = _G.calculateFishValue(player, row.fish_name)
                local totalVal = valPerFish * amt
                player:addGems(totalVal, 0, 1)
                player:onConsoleMessage("`2>> Sold " .. amt .. "x " .. row.fish_name .. " for " .. formatNum(totalVal) .. " Gems!``")
            end
            
            -- Deduct fish
            if amt == currentCount then
                db:query(string.format("DELETE FROM inventory WHERE id = %d", rowID))
            else
                db:query(string.format("UPDATE inventory SET total_caught = total_caught - %d WHERE id = %d", amt, rowID))
            end
            
            player:onParticleEffect(45, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            
            sess.sellRowID = nil
            showFishInventory(player)
            return true
        end
        return true
    end

    return false
end)

onPlayerDisconnectCallback(function(player)
    local k = tostring(player:getNetID())
    sessions[k] = nil
end)
