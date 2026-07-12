-- ─────────────────────────────────────────────────────────────────────────────
-- Fishing Rod Enchantment System
-- Command: /enchant
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Fishing Rod Enchantment System")

local DB_PATH = "fishing_enchants.db"
local db = sqlite.open(DB_PATH)

local function initDB()
    db:query([[
        CREATE TABLE IF NOT EXISTS enchants (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id    INTEGER NOT NULL,
            rod_item_id  INTEGER NOT NULL,
            enchant_item_id INTEGER NOT NULL,
            rarity       INTEGER NOT NULL,
            created_at   INTEGER
        )
    ]])
    db:query([[
        CREATE TABLE IF NOT EXISTS rod_buffs (
            player_id    INTEGER NOT NULL,
            rod_item_id  INTEGER NOT NULL,
            slot_id      INTEGER NOT NULL,
            buff_type    TEXT NOT NULL,
            buff_level   INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY(player_id, rod_item_id, slot_id)
        )
    ]])
end
initDB()

-- ─── DB Helpers ───────────────────────────────────────────────────────────────

-- Returns all enchantments for a specific player and rod
function getPlayerEnchants(playerID, rodItemID)
    local results = {}
    local rows = db:query(string.format([[
        SELECT * FROM enchants 
        WHERE player_id = %d AND rod_item_id = %d
    ]], playerID, rodItemID))
    
    if rows then
        for _, row in ipairs(rows) do
            table.insert(results, {
                id = tonumber(row.id),
                playerID = tonumber(row.player_id),
                rodItemID = tonumber(row.rod_item_id),
                enchantItemID = tonumber(row.enchant_item_id),
                rarity = tonumber(row.rarity)
            })
        end
    end
    return results
end

local function addEnchant(playerID, rodItemID, enchantItemID, rarity)
    db:query(string.format([[
        INSERT INTO enchants (player_id, rod_item_id, enchant_item_id, rarity, created_at)
        VALUES (%d, %d, %d, %d, %d)
    ]], playerID, rodItemID, enchantItemID, rarity, os.time()))
end

function _G.getRodBuffs(playerID, rodItemID)
    local results = {
        [1] = { type = nil, level = 0 },
        [2] = { type = nil, level = 0 },
        [3] = { type = nil, level = 0 }
    }
    local rows = db:query(string.format([[
        SELECT slot_id, buff_type, buff_level FROM rod_buffs 
        WHERE player_id = %d AND rod_item_id = %d
    ]], playerID, rodItemID))
    
    if rows then
        for _, row in ipairs(rows) do
            local slot = tonumber(row.slot_id)
            if slot and slot >= 1 and slot <= 3 then
                results[slot] = {
                    type = row.buff_type,
                    level = tonumber(row.buff_level)
                }
            end
        end
    end
    return results
end

local function setRodBuff(playerID, rodItemID, slotID, buffType, buffLevel)
    db:query(string.format([[
        INSERT OR REPLACE INTO rod_buffs (player_id, rod_item_id, slot_id, buff_type, buff_level)
        VALUES (%d, %d, %d, '%s', %d)
    ]], playerID, rodItemID, slotID, buffType, buffLevel))
end

-- ─── UI Helpers ───────────────────────────────────────────────────────────────
local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(15, 25, 40, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(0, 200, 255, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

local sessions = {}
local function getSession(player)
    local netID = tostring(player:getNetID())
    sessions[netID] = sessions[netID] or {}
    return sessions[netID]
end

local function getItemName(itemID)
    local it = getItem(itemID)
    return it and it:getName() or ("Item #" .. itemID)
end

local function getItemRarity(itemID)
    local it = getItem(itemID)
    return it and tonumber(it:getRarity()) or 0
end

-- ─── UI: Main Menu ────────────────────────────────────────────────────────────
function showEnchantMenu(player)
    local sess = getSession(player)
    sess.selectedRod = nil
    sess.selectedItem = nil

    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9Rod Enchanter``|left|3228|")
    table.insert(d, "add_smalltext|`oCombine a Fishing Rod with a block to grant it special fishing abilities. This enchantment is exclusive to YOU!``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_button|enc_select_rod|`w1. Select a Fishing Rod``|no_flags|0|0|")
    table.insert(d, "add_button|enc_view_my|`oView My Enchantments``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|enchant_main|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── UI: Select Rod ───────────────────────────────────────────────────────────
local function showRodSelection(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9Select Rod``|left|3228|")
    table.insert(d, "add_smalltext|`oPick which Fishing Rod from your inventory you want to enchant.``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_item_picker|enc_pick_rod|Pick a Rod|Choose from inventory|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|enc_back_main|`oBack``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|enchant_rod_sel|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end


-- ─── UI: Rod Menu (Branching) ────────────────────────────────────────────────
local function showRodMenu(player)
    local sess = getSession(player)
    local rodName = getItemName(sess.selectedRod)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9Rod Enchanter``|left|3228|")
    table.insert(d, "add_smalltext|`oSelected Rod: `w" .. rodName .. "``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|enc_type_drop|`w1. Manage Item Drop Enchantment``|no_flags|0|0|")
    table.insert(d, "add_button|enc_type_buff|`52. Manage Stat Buff Slots``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|enc_back_rod_sel|`oBack``|no_flags|0|0|")
    
    player:onDialogRequest(table.concat(d, "\n") .. "\nend_dialog|enchant_rod_menu|Close||\nadd_quick_exit|")
    resetStyle(player)
end

-- ─── UI: Stat Buff Slots ──────────────────────────────────────────────────────
local function showStatBuffUI(player)
    local sess = getSession(player)
    local rodID = sess.selectedRod
    local rodName = getItemName(rodID)
    local buffs = _G.getRodBuffs(player:getUserID(), rodID)
    
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`5Stat Buff Slots``|left|3228|")
    table.insert(d, "add_smalltext|`oRod: `w" .. rodName .. "``|left|")
    table.insert(d, "add_spacer|small|")
    
    for slot = 1, 3 do
        local b = buffs[slot]
        table.insert(d, "add_textbox|`oSlot " .. slot .. ":``|left|")
        if b.type == nil or b.type == "nil" then
            table.insert(d, "add_button|enc_buff_slot_" .. slot .. "|`w< Empty Slot >``|no_flags|0|0|")
        else
            table.insert(d, "add_button|enc_buff_slot_" .. slot .. "|`5" .. b.type .. " `w(Lv. " .. b.level .. ")``|no_flags|0|0|")
        end
        table.insert(d, "add_spacer|small|")
    end
    
    table.insert(d, "add_button|enc_back_rod_menu|`oBack``|no_flags|0|0|")
    player:onDialogRequest(table.concat(d, "\n") .. "\nend_dialog|enchant_buff_main|Close||\nadd_quick_exit|")
    resetStyle(player)
end

-- ─── UI: Pick Buff Type ───────────────────────────────────────────────────────
local function showBuffPicker(player)
    local sess = getSession(player)
    local slot = sess.selectedBuffSlot
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`5Pick a Buff (Slot " .. slot .. ")``|left|3228|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|enc_pickbuff_Lucky Strike|`9Lucky Strike `o(Uses Diamond Locks)``|no_flags|0|0|")
    table.insert(d, "add_smalltext|`o+0.001% per level chance to catch Variant fish.``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|enc_pickbuff_Twin Catch|`5Twin Catch `o(Uses Mythical Fish)``|no_flags|0|0|")
    table.insert(d, "add_smalltext|`o+0.1% per level chance to double your drops.``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|enc_pickbuff_Master Fisher|`6Master Fisher `o(Uses Special Locks)``|no_flags|0|0|")
    table.insert(d, "add_smalltext|`o+0.001% per level to Virtual Fish base sell value.``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|enc_back_buff_main|`oBack``|no_flags|0|0|")
    player:onDialogRequest(table.concat(d, "\n") .. "\nend_dialog|enchant_buff_picker|Close||\nadd_quick_exit|")
    resetStyle(player)
end

-- ─── UI: Buff Upgrade ─────────────────────────────────────────────────────────
local function showBuffUpgrade(player)
    local sess = getSession(player)
    local slot = sess.selectedBuffSlot
    local rodID = sess.selectedRod
    local buffs = _G.getRodBuffs(player:getUserID(), rodID)
    local b = buffs[slot]
    
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`5Upgrade " .. b.type .. "``|left|3228|")
    table.insert(d, "add_smalltext|`oCurrent Level: `w" .. b.level .. "``|left|")
    table.insert(d, "add_spacer|small|")
    
    local cost = 1 + math.floor(b.level / 5)
    local reqItem = ""
    if b.type == "Lucky Strike" then
        reqItem = "Diamond Lock"
    elseif b.type == "Twin Catch" then
        reqItem = "Any Mythical Fish"
    elseif b.type == "Master Fisher" then
        reqItem = "Special Lock"
    end
    
    table.insert(d, "add_textbox|`oCost per level: `w" .. cost .. "x " .. reqItem .. "``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|enc_upgrade_buff|`2Consume " .. cost .. "x " .. reqItem .. " to Upgrade!``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|enc_remove_buff|`4Remove Buff (Reset Slot)``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|enc_back_buff_main|`oBack``|no_flags|0|0|")
    
    player:onDialogRequest(table.concat(d, "\n") .. "\nend_dialog|enchant_buff_upgrade|Close||\nadd_quick_exit|")
    resetStyle(player)
end

-- ─── UI: Select Enchant Item ──────────────────────────────────────────────────

local function showItemSelection(player)
    local sess = getSession(player)
    local rodName = getItemName(sess.selectedRod)

    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9Select Material``|left|3228|")
    table.insert(d, "add_smalltext|`oSelected Rod: `w" .. rodName .. "``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_smalltext|`oPick a block/item to sacrifice. Its rarity will determine the drop chance!``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_item_picker|enc_pick_item|Pick Material|Choose from inventory|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|enc_back_main|`oCancel``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|enchant_item_sel|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── UI: Confirm Enchant ──────────────────────────────────────────────────────
local function showConfirmEnchant(player)
    local sess = getSession(player)
    local rodName = getItemName(sess.selectedRod)
    local itemName = getItemName(sess.selectedItem)
    local rarity = getItemRarity(sess.selectedItem)
    
    -- Prevent blank/seed/invalid enchants if needed, but we'll allow most items
    if rarity == 0 then
        player:onConsoleMessage("`4Warning: `oThis item has rarity 0, so it will have a VERY high drop rate!``")
    end

    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9Confirm Enchant``|left|3228|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_smalltext|`oYou are about to enchant your `w" .. rodName .. "``!|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, string.format("add_button_with_icon|noop1||staticGreyFrame,no_padding_x,disabled|%d||", sess.selectedItem))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`oSacrifice: `w1x " .. itemName .. "``|left|")
    table.insert(d, "add_smalltext|`oItem Rarity: `$" .. rarity .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`4This will permanently consume the item!``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_button|enc_do_it|`2✨ ENCHANT ✨``|no_flags|0|0|")
    table.insert(d, "add_button|enc_back_main|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|enchant_confirm|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── UI: View Enchantments ────────────────────────────────────────────────────
local function showMyEnchantments(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9My Enchantments``|left|3228|")
    table.insert(d, "add_spacer|small|")
    
    local userID = player:getUserID()
    local rows = db:query(string.format("SELECT * FROM enchants WHERE player_id = %d", userID))
    
    if not rows or #rows == 0 then
        table.insert(d, "add_textbox|`oYou don't have any fishing enchantments yet.``|left|")
    else
        table.insert(d, "add_smalltext|`oYour active enchantments:``|left|")
        table.insert(d, "add_spacer|small|")
        for i, row in ipairs(rows) do
            local rodName = getItemName(tonumber(row.rod_item_id))
            local itemName = getItemName(tonumber(row.enchant_item_id))
            local rarity = tonumber(row.rarity)
            local dropChance = math.max(1, 100 - rarity)
            
            table.insert(d, "add_label_with_icon|small|`w" .. itemName .. "``|left|" .. tonumber(row.enchant_item_id) .. "|")
            table.insert(d, "add_smalltext|`oAttached to Rod: `w" .. rodName .. "``|left|")
            table.insert(d, "add_smalltext|`oItem Rarity: `$" .. rarity .. " `o(Drop Chance: `2" .. dropChance .. "%`o)``|left|")
            table.insert(d, "add_button|enc_remove_block_" .. row.id .. "|`4Remove Enchantment `o(`250,000 Gems`o)``|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|enc_back_main|`oBack``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|enchant_list|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Commands ─────────────────────────────────────────────────────────────────
registerLuaCommand({
    command      = "enchant",
    roleRequired = 0,
    description  = "Enchant your fishing rod with custom drops!"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    if cmd:lower() == "enchant" then
        showEnchantMenu(player)
        return true
    end
    return false
end)

-- ─── Dialog Callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg     = data["dialog_name"]   or ""
    local clicked = data["buttonClicked"] or ""

    if dlg == "portal_shortcuts" and clicked == "sc_enchant" then
        showEnchantMenu(player)
        return true
    end

    if dlg == "enchant_main" then
        if clicked == "enc_select_rod" then showRodSelection(player) return true end
        if clicked == "enc_view_my" then showMyEnchantments(player) return true end
        return true
    end

    if dlg == "enchant_rod_sel" then
        if clicked == "enc_back_main" then showEnchantMenu(player) return true end
        
        local itemPick = tonumber(data["enc_pick_rod"])
        if itemPick and itemPick > 0 then
            local sess = getSession(player)
            -- Verify they actually have the item
            if player:getItemAmount(itemPick) > 0 then
                sess.selectedRod = itemPick
                timer.setTimeout(0.1, function() showRodMenu(player) end)
            else
                player:onConsoleMessage("`4You don't have that item in your inventory!``")
                showRodSelection(player)
            end
            return true
        end
        return true
    end


    if dlg == "enchant_rod_menu" then
        if clicked == "enc_back_rod_sel" then showRodSelection(player) return true end
        if clicked == "enc_type_drop" then showItemSelection(player) return true end
        if clicked == "enc_type_buff" then showStatBuffUI(player) return true end
        return true
    end

    if dlg == "enchant_buff_main" then
        if clicked == "enc_back_rod_menu" then showRodMenu(player) return true end
        
        local slot = tonumber(clicked:match("^enc_buff_slot_(%d)$"))
        if slot then
            local sess = getSession(player)
            sess.selectedBuffSlot = slot
            local rodID = sess.selectedRod
            local buffs = _G.getRodBuffs(player:getUserID(), rodID)
            local b = buffs[slot]
            if b.type == nil or b.type == "nil" then
                showBuffPicker(player)
            else
                showBuffUpgrade(player)
            end
            return true
        end
        return true
    end

    if dlg == "enchant_buff_picker" then
        if clicked == "enc_back_buff_main" then showStatBuffUI(player) return true end
        
        local buffType = clicked:match("^enc_pickbuff_(.+)$")
        if buffType then
            local sess = getSession(player)
            setRodBuff(player:getUserID(), sess.selectedRod, sess.selectedBuffSlot, buffType, 1)
            player:playAudio("piano_nice.wav")
            player:onConsoleMessage("`2>> Successfully equipped " .. buffType .. " to Slot " .. sess.selectedBuffSlot .. "!``")
            showStatBuffUI(player)
            return true
        end
        return true
    end

    if dlg == "enchant_buff_upgrade" then
        if clicked == "enc_back_buff_main" then showStatBuffUI(player) return true end
        
        if clicked == "enc_remove_buff" then
            local sess = getSession(player)
            setRodBuff(player:getUserID(), sess.selectedRod, sess.selectedBuffSlot, "nil", 0)
            player:onConsoleMessage("`4>> Removed buff from slot!``")
            showStatBuffUI(player)
            return true
        end
        
        if clicked == "enc_upgrade_buff" then
            local sess = getSession(player)
            local rodID = sess.selectedRod
            local slot = sess.selectedBuffSlot
            local buffs = _G.getRodBuffs(player:getUserID(), rodID)
            local b = buffs[slot]
            
            local hasItem = false
            
            local cost = 1 + math.floor(b.level / 5)
            
            if b.type == "Lucky Strike" then
                if player:getItemAmount(1796) >= cost then
                    player:changeItem(1796, -cost, 0)
                    hasItem = true
                else
                    player:onConsoleMessage("`4Failed: You don't have enough Diamond Locks! (Need " .. cost .. ")``")
                end
            elseif b.type == "Twin Catch" then
                local inv_db = sqlite.open("fish_inventory.db")
                local rows = inv_db:query("SELECT * FROM inventory WHERE player_id = " .. player:getUserID() .. " AND fish_name LIKE '%[Mythical]%' AND total_caught >= " .. cost .. " LIMIT 1")
                if rows and #rows > 0 then
                    inv_db:query("UPDATE inventory SET total_caught = total_caught - " .. cost .. " WHERE id = " .. rows[1].id)
                    hasItem = true
                else
                    player:onConsoleMessage("`4Failed: You don't have enough Mythical Fish in your /fishinv! (Need " .. cost .. " of one type)``")
                end
            elseif b.type == "Master Fisher" then
                if player:getItemAmount(20628) >= cost then
                    player:changeItem(20628, -cost, 0)
                    hasItem = true
                else
                    player:onConsoleMessage("`4Failed: You don't have enough Special Locks! (Need " .. cost .. ")``")
                end
            end
            
            if hasItem then
                setRodBuff(player:getUserID(), rodID, slot, b.type, b.level + 1)
                player:playAudio("piano_nice.wav")
                player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
                player:onConsoleMessage("`2>> Upgrade Successful! " .. b.type .. " is now Level " .. (b.level + 1) .. "!``")
                showBuffUpgrade(player)
            end
            return true
        end
        return true
    end

    if dlg == "enchant_item_sel" then

        if clicked == "enc_back_main" then showEnchantMenu(player) return true end
        
        local itemPick = tonumber(data["enc_pick_item"])
        if itemPick and itemPick > 0 then
            local sess = getSession(player)
            -- Check inventory and prevent sacrificing the rod itself accidentally if they only have 1
            if player:getItemAmount(itemPick) > 0 then
                sess.selectedItem = itemPick
                timer.setTimeout(0.1, function() showConfirmEnchant(player) end)
            else
                player:onConsoleMessage("`4You don't have that item in your inventory!``")
                showItemSelection(player)
            end
            return true
        end
        return true
    end

    if dlg == "enchant_confirm" then
        if clicked == "enc_back_main" then showEnchantMenu(player) return true end
        
        if clicked == "enc_do_it" then
            local sess = getSession(player)
            if not sess.selectedRod or not sess.selectedItem then return true end

            -- Final verification
            if player:getItemAmount(sess.selectedItem) <= 0 then
                player:onConsoleMessage("`4Failed: You no longer have the material item!``")
                return true
            end

            -- Deduct item (Consume 1)
            player:changeItem(sess.selectedItem, -1, 0)

            -- Add to DB
            local userID = player:getUserID()
            local rarity = getItemRarity(sess.selectedItem)
            
            -- Prevent duplicate exact enchantments
            local exists = db:query(string.format(
                "SELECT id FROM enchants WHERE player_id=%d AND rod_item_id=%d AND enchant_item_id=%d",
                userID, sess.selectedRod, sess.selectedItem
            ))
            
            if exists and #exists > 0 then
                player:onConsoleMessage("`4You already enchanted this item onto this rod! (But we kept your item anyway just to be safe...)``")
                -- Give item back
                player:changeItem(sess.selectedItem, 1, 0)
                return true
            end

            addEnchant(userID, sess.selectedRod, sess.selectedItem, rarity)

            -- Effects
            player:onConsoleMessage("`6>> Enchantment: `9Successfully enchanted `w" .. getItemName(sess.selectedRod) .. "`9 with `w" .. getItemName(sess.selectedItem) .. "`9!``")
            player:playAudio("piano_nice.wav")
            player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            
            sess.selectedRod = nil
            sess.selectedItem = nil
            showMyEnchantments(player)
            return true
        end
        return true
    end

    if dlg == "enchant_list" then
        if clicked == "enc_back_main" then showEnchantMenu(player) return true end
        
        local rmIdx = tonumber(clicked:match("^enc_remove_block_(%d+)$"))
        if rmIdx then
            if player:removeGems(50000, 1, 1) then
                db:query(string.format("DELETE FROM enchants WHERE id = %d AND player_id = %d", rmIdx, player:getUserID()))
                player:onConsoleMessage("`2>> Successfully removed the enchantment for 50,000 Gems!``")
                player:playAudio("success.wav")
                showMyEnchantments(player)
            else
                player:onConsoleMessage("`4>> You don't have enough Gems! (Requires 50,000)``")
            end
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
