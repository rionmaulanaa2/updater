-- Virtual Wallet & Gem Exchange System
local WALLET_DB = "config/wallets.json"
local POOL_DB = "config/locks_pool.json"

local wallet_data = {
    wallets = {},
    name_to_id = {}
}

local PRICES = {
    ["242"] = 2000, -- WL
    ["1796"] = 200000, -- DL
    ["7188"] = 20000000, -- BGL
    ["20628"] = 2000000000 -- BlackGL
}

local LOCK_NAMES = {
    ["242"] = "World Lock",
    ["1796"] = "Diamond Lock",
    ["7188"] = "Blue Gem Lock",
    ["20628"] = "Black Gem Lock"
}

local function saveWallet()
    file.write(WALLET_DB, json.encode(wallet_data))
end

local function loadWallet()
    if file.exists(WALLET_DB) then
        local content = file.read(WALLET_DB)
        if content and content ~= "" then
            wallet_data = json.decode(content)
        end
    else
        saveWallet()
    end
end
loadWallet()

local function getWallet(userId)
    local strId = tostring(userId)
    if not wallet_data.wallets[strId] then
        wallet_data.wallets[strId] = {
            ["242"] = 0,
            ["1796"] = 0,
            ["7188"] = 0,
            ["20628"] = 0
        }
    end
    return wallet_data.wallets[strId]
end

-- Hook into login to map name to ID
onPlayerLoginCallback(function(player)
    local name = player:getRealCleanName()
    local uid = player:getUserID()
    if name and uid then
        wallet_data.name_to_id[name:lower()] = tostring(uid)
        saveWallet()
    end
end)

local function buildMainMenu(player)
    local uid = player:getUserID()
    local wallet = getWallet(uid)
    local gems = player:getGems() or 0
    
    local d = "set_default_color|`o\nadd_label_with_icon|big|`wVirtual Wallet``|left|1446|\nadd_spacer|small|\n"
    d = d .. "add_label_with_icon|small|`wWallet ID: `2" .. uid .. "``|left|18|\n"
    d = d .. "add_label_with_icon|small|`wYour Gems: `2" .. gems .. "``|left|112|\nadd_spacer|small|\n"
    
    d = d .. "add_label_with_icon|small|`wWorld Locks: `2" .. (wallet["242"] or 0) .. "``|left|242|\n"
    d = d .. "add_label_with_icon|small|`wDiamond Locks: `2" .. (wallet["1796"] or 0) .. "``|left|1796|\n"
    d = d .. "add_label_with_icon|small|`wBlue Gem Locks: `2" .. (wallet["7188"] or 0) .. "``|left|7188|\n"
    d = d .. "add_label_with_icon|small|`wBlack Gem Locks: `2" .. (wallet["20628"] or 0) .. "``|left|20628|\n"
    
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|w_exchange|`5Exchange Gems for Locks|\n"
    d = d .. "add_button|w_transfer|`wTransfer Locks to Player|\n"
    d = d .. "add_button|w_withdraw|`3Withdraw to Inventory|\n"
    d = d .. "end_dialog|wallet_main|Close||\nadd_quick_exit|\n"
    
    return d
end

local function buildExchangeMenu()
    local d = "set_default_color|`o\nadd_label_with_icon|big|`wGem Exchange``|left|112|\nadd_spacer|small|\n"
    d = d .. "add_textbox|`wPrices:\n- WL: 2,000 Gems\n- DL: 200,000 Gems\n- BGL: 20,000,000 Gems\n- BlackGL: 2,000,000,000 Gems|left|\n"
    
    d = d .. "add_text_input|exc_amount|Amount to buy:|1|5|\n"
    d = d .. "add_button|exc_buy_242|`wBuy World Locks|\n"
    d = d .. "add_button|exc_buy_1796|`wBuy Diamond Locks|\n"
    d = d .. "add_button|exc_buy_7188|`wBuy Blue Gem Locks|\n"
    d = d .. "add_button|exc_buy_20628|`wBuy Black Gem Locks|\n"
    
    d = d .. "add_spacer|small|\nadd_button|w_main_back|`wBack to Wallet|\n"
    d = d .. "end_dialog|wallet_exchange|Close||\nadd_quick_exit|\n"
    return d
end

local function buildTransferMenu()
    local d = "set_default_color|`o\nadd_label_with_icon|big|`wTransfer Virtual Locks``|left|242|\nadd_spacer|small|\n"
    
    d = d .. "add_text_input|tr_target|Recipient Name or Wallet ID:||30|\n"
    d = d .. "add_text_input|tr_amount|Amount to Send:|1|5|\n"
    
    d = d .. "add_button|tr_send_242|`wSend World Locks|\n"
    d = d .. "add_button|tr_send_1796|`wSend Diamond Locks|\n"
    d = d .. "add_button|tr_send_7188|`wSend Blue Gem Locks|\n"
    d = d .. "add_button|tr_send_20628|`wSend Black Gem Locks|\n"
    
    d = d .. "add_spacer|small|\nadd_button|w_main_back|`wBack to Wallet|\n"
    d = d .. "end_dialog|wallet_transfer|Close||\nadd_quick_exit|\n"
    return d
end

local function buildWithdrawMenu()
    local d = "set_default_color|`o\nadd_label_with_icon|big|`wWithdraw Virtual Locks``|left|242|\nadd_spacer|small|\n"
    d = d .. "add_textbox|`wNote: Withdrawing is subject to global server anti-dupe caps.|left|\n"
    
    d = d .. "add_text_input|wd_amount|Amount to withdraw:|1|5|\n"
    
    d = d .. "add_button|wd_get_242|`wWithdraw World Locks|\n"
    d = d .. "add_button|wd_get_1796|`wWithdraw Diamond Locks|\n"
    d = d .. "add_button|wd_get_7188|`wWithdraw Blue Gem Locks|\n"
    d = d .. "add_button|wd_get_20628|`wWithdraw Black Gem Locks|\n"
    
    d = d .. "add_spacer|small|\nadd_button|w_main_back|`wBack to Wallet|\n"
    d = d .. "end_dialog|wallet_withdraw|Close||\nadd_quick_exit|\n"
    return d
end

onPlayerCommandCallback(function(world, player, command)
    local cmd = command:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == "wallet" then
        player:onDialogRequest(buildMainMenu(player))
        return true
    end
    
    return false
end)

-- Checks against locks_pool if possible
local function checkPoolLimit(lockId, amount)
    if not file.exists(POOL_DB) then return true end
    local content = file.read(POOL_DB)
    if not content or content == "" then return true end
    
    local pool = json.decode(content)
    if not pool then return true end
    
    local current = pool.current_pools[tostring(lockId)] or 0
    local max = pool.max_pools[tostring(lockId)] or 0
    
    if (current + amount) > max then
        return false
    end
    return true
end

onPlayerDialogCallback(function(world, player, data)
    local dName = data["dialog_name"] or ""
    local bName = data["buttonClicked"] or ""
    
    if dName == "wallet_main" then
        if bName == "w_exchange" then
            player:onDialogRequest(buildExchangeMenu())
            return true
        elseif bName == "w_transfer" then
            player:onDialogRequest(buildTransferMenu())
            return true
        elseif bName == "w_withdraw" then
            player:onDialogRequest(buildWithdrawMenu())
            return true
        end
    
    elseif dName == "wallet_exchange" then
        if bName == "w_main_back" then
            player:onDialogRequest(buildMainMenu(player))
            return true
        elseif bName:sub(1, 8) == "exc_buy_" then
            local lockId = bName:sub(9)
            local amountStr = data["exc_amount"] or ""
            local amount = math.floor(tonumber(amountStr) or 0)
            
            if amount <= 0 then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Invalid amount. Must be a positive whole number."})
                return true
            end
            
            local price_per = PRICES[lockId]
            if not price_per then return true end
            
            local total_cost = math.floor(price_per * amount)
            
            -- Prevent 32-bit integer overflow which causes C++ to reject the number (bad argument #2)
            if total_cost > 2147483647 or total_cost < 0 then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Total gem cost exceeds maximum limit! Please buy in smaller quantities."})
                return true
            end
            
            local current_gems = tonumber(player:getGems()) or 0
            
            if current_gems < total_cost then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4You don't have enough gems!"})
                return true
            end
            
            if not checkPoolLimit(lockId, amount) then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Server Anti-Dupe Global Pool for this lock has reached its max limit! Cannot buy."})
                return true
            end
            
            player:removeGems(total_cost)
            local uid = tostring(player:getUserID())
            local wallet = getWallet(uid)
            wallet[lockId] = (wallet[lockId] or 0) + amount
            saveWallet()
            
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`2Successfully bought `w" .. amount .. " " .. (LOCK_NAMES[lockId] or "Lock") .. "(s)!"})
            if _G.auditPlayerInventory then _G.auditPlayerInventory(player) end
            player:onDialogRequest(buildMainMenu(player))
            return true
        end
        
    elseif dName == "wallet_transfer" then
        if bName == "w_main_back" then
            player:onDialogRequest(buildMainMenu(player))
            return true
        elseif bName:sub(1, 8) == "tr_send_" then
            local lockId = bName:sub(9)
            local amountStr = data["tr_amount"] or ""
            local amount = math.floor(tonumber(amountStr) or 0)
            local target = data["tr_target"]
            
            if amount <= 0 then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Invalid amount. Must be a positive whole number."})
                return true
            end
            
            if not target or target == "" then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Please specify a target."})
                return true
            end
            
            local targetId = nil
            if tonumber(target) then
                targetId = tostring(tonumber(target))
            else
                targetId = wallet_data.name_to_id[target:lower()]
            end
            
            if not targetId then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Target player or Wallet ID not found in database."})
                return true
            end
            
            local uid = tostring(player:getUserID())
            if targetId == uid then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4You cannot send to yourself."})
                return true
            end
            
            local wallet = getWallet(uid)
            if (wallet[lockId] or 0) < amount then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4You don't have enough virtual locks in your wallet."})
                return true
            end
            
            -- Do transfer
            wallet[lockId] = wallet[lockId] - amount
            local targetWallet = getWallet(targetId)
            targetWallet[lockId] = (targetWallet[lockId] or 0) + amount
            saveWallet()
            
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`2Successfully transferred `w" .. amount .. " " .. (LOCK_NAMES[lockId] or "Lock") .. "(s) to Wallet ID " .. targetId})
            player:onDialogRequest(buildMainMenu(player))
            return true
        end
        
    elseif dName == "wallet_withdraw" then
        if bName == "w_main_back" then
            player:onDialogRequest(buildMainMenu(player))
            return true
        elseif bName:sub(1, 7) == "wd_get_" then
            local lockId = bName:sub(8)
            local amountStr = data["wd_amount"] or ""
            local amount = math.floor(tonumber(amountStr) or 0)
            
            if amount <= 0 then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Invalid amount. Must be a positive whole number."})
                return true
            end
            
            local uid = tostring(player:getUserID())
            local wallet = getWallet(uid)
            if (wallet[lockId] or 0) < amount then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4You don't have enough virtual locks in your wallet."})
                return true
            end
            
            -- We assume giving item to inventory
            -- Note: lock-tracker.lua will automatically audit their inventory on login/disconnect/etc
            -- but to be safe, we check pool limits before giving physical items.
            if not checkPoolLimit(lockId, amount) then
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Anti-Dupe Global Limit reached. Cannot withdraw."})
                return true
            end
            
            wallet[lockId] = wallet[lockId] - amount
            saveWallet()
            player:changeItem(tonumber(lockId), amount, 0)
            
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`2Successfully withdrew `w" .. amount .. " " .. (LOCK_NAMES[lockId] or "Lock") .. "(s) to inventory!"})
            if _G.auditPlayerInventory then _G.auditPlayerInventory(player) end
            player:onDialogRequest(buildMainMenu(player))
            return true
        end
    end
    
    return false
end)

print("Loaded Virtual Wallet System")
