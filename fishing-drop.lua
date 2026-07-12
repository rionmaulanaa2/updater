-- Fishing Drop Override Script
-- Uses: onPlayerCatchFishCallback(world, player, itemID, itemCount)
-- Docs: https://docs.nperma.my.id/docs/callback-event.html#onplayercatchfishcallback
-- NOTE: Bite time cannot be controlled via Lua API (no setBiteTime function in engine).
--       This script controls WHAT drops when a fish is caught.
print("(Loaded) Fishing Drop Override script for GrowSoft")

math.randomseed(os.time())

-- ─── Config ───────────────────────────────────────────────────────────────────
local DB_PATH = "fishing_enchants.db"
local enchant_db = sqlite.open(DB_PATH)

local INV_DB_PATH = "fish_inventory.db"
local inv_db = sqlite.open(INV_DB_PATH)

-- Each entry in DROP_TABLE is one possible catch outcome.
-- Fields:
--   itemID  : item to give the player
--   count   : how many to give
--   weight  : relative probability weight (higher = more common)
--              e.g. weight 100 is 10x more likely than weight 10
--   label   : friendly name shown in console (cosmetic only)
--
-- Total weight of all entries = denominator for probability.
-- Example: weight 50 out of total 200 = 25% chance.

local DROP_TABLE = {
    -- ── Common drops ────────────────────────────────────────────────
    { itemID = 112,    count = 10,  weight = 80,  label = "Gems (10)"            },
    { itemID = 112,   count = 20,  weight = 70,  label = "Gems (20)"            },
    { itemID = 112,    count = 50,  weight = 60,  label = "Gems (50)"            },
    -- ── Uncommon drops ──────────────────────────────────────────────
    { itemID = 112,  count = 100,  weight = 30,  label = "Gems (100)"      },
    { itemID = 112,  count = 200, weight = 25,  label = "Gems (200)"       },
    -- ── Rare drops ──────────────────────────────────────────────────
    { itemID = 112, count = 350,  weight = 10,  label = "Gems (350) "    },
    { itemID = 112, count = 1000,  weight = 3,   label = "Gems (1000) "   },
    -- ─── Ultra rare ──────────────────────────────────────────────────
    { itemID = 112,count = 100000,  weight = 1,   label = "Gems (100000) "    },
}

-- ─── Exclusive Rod (25014) Drops ──────────────────────────────────────────────
local EXCLUSIVE_ROD_ID = 25014

-- Make it global so the loot manager script can access it if needed
EXCLUSIVE_DROP_TABLE = {}

local LOOT_DB_PATH = "fishing_loot.db"
local loot_db = sqlite.open(LOOT_DB_PATH)

loot_db:query([[
    CREATE TABLE IF NOT EXISTS custom_loot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        weight INTEGER NOT NULL,
        label TEXT NOT NULL,
        is_virtual INTEGER NOT NULL DEFAULT 1
    )
]])

-- Global function to reload the table from DB
function loadExclusiveDropTable()
    EXCLUSIVE_DROP_TABLE = {}
    local rows = loot_db:query("SELECT * FROM custom_loot")
    if rows then
        for _, row in ipairs(rows) do
            table.insert(EXCLUSIVE_DROP_TABLE, {
                itemID    = tonumber(row.item_id),
                count     = tonumber(row.count),
                weight    = tonumber(row.weight),
                label     = row.label,
                isVirtual = (tonumber(row.is_virtual) == 1),
                iconID    = tonumber(row.item_id)
            })
        end
    end
    if recomputeWeight then recomputeWeight() end
    print("(Fishing) Loaded " .. #EXCLUSIVE_DROP_TABLE .. " custom fish drops from DB.")
end

-- Set to true to let the engine ALSO give its default drop on top of yours.
-- Set to false to REPLACE the default drop entirely (recommended for custom fishing).
local GIVE_DEFAULT_DROP = true

-- Developer role (for /fishconfig command)
local ROLE_DEVELOPER = 51

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function formatNum(num)
    local s = tostring(math.floor(tonumber(num) or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return s:gsub("^,", "")
end

local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(10, 10, 20, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(0, 200, 120, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- Pre-compute total weight for random selection (recalculated when table changes)
local totalWeight = 0
local totalExclusiveWeight = 0

local function recomputeWeight()
    totalWeight = 0
    totalExclusiveWeight = 0
    for _, entry in ipairs(DROP_TABLE) do
        totalWeight = totalWeight + (entry.weight or 0)
    end
    for _, entry in ipairs(EXCLUSIVE_DROP_TABLE) do
        totalExclusiveWeight = totalExclusiveWeight + (entry.weight or 0)
    end
end
-- Initial load of DB triggers recomputeWeight
loadExclusiveDropTable()

-- Weighted random pick from a specific table
local function pickDrop(tbl, maxWeight)
    if maxWeight <= 0 or #tbl == 0 then return nil end
    local roll = math.random(1, maxWeight)
    local cumulative = 0
    for _, entry in ipairs(tbl) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry
        end
    end
    return tbl[#tbl] -- fallback
end

onPlayerCatchFishCallback(function(world, player, itemID, itemCount)
    -- itemID / itemCount = what the ENGINE would normally give
    -- We pick our own drop from the weighted table instead

    -- Slot 5 is the HAND_ITEM slot
    local equippedRod = player:getClothingItemID(5)
    local isExclusiveRod = (equippedRod == EXCLUSIVE_ROD_ID)
    
    -- Clone the appropriate base table for this catch
    local currentPool = {}
    local currentTotalWeight = 0
    
    local baseTable = isExclusiveRod and EXCLUSIVE_DROP_TABLE or DROP_TABLE
    for _, entry in ipairs(baseTable) do
        table.insert(currentPool, entry)
        currentTotalWeight = currentTotalWeight + entry.weight
    end

    -- Query personal enchantments for this specific rod
    local userID = player:getUserID()
    local enchants = enchant_db:query(string.format(
        "SELECT enchant_item_id, rarity FROM enchants WHERE player_id = %d AND rod_item_id = %d",
        userID, equippedRod
    ))

    -- Process Enchantments Independently!
    if enchants and #enchants > 0 then
        for _, row in ipairs(enchants) do
            local eItemID = tonumber(row.enchant_item_id)
            local eRarity = tonumber(row.rarity)
            
            -- Calculate drop rate (100 - rarity)%
            -- E.g. Rarity 80 -> 20% chance to drop on every catch!
            local chance = math.max(1, 100 - eRarity)
            if eRarity > 99 then chance = 1 end
            
            if math.random(1, 100) <= chance then
                -- They won the enchantment drop!
                if not player:changeItem(eItemID, 1, 0) then
                    player:changeItem(eItemID, 1, 1) -- fallback: backpack
                end
                
                player:onConsoleMessage(
                    "`6>> Fishing: `9[ENCHANTMENT DROP] `2Your enchanted rod pulled up item ID: " .. eItemID .. "!``"
                )
                player:onTalkBubble(player:getNetID(), "`9My rod's enchantment glowed!``", 0)
                player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            end
        end
    end

    -- ─── Stat Buff Processing ──────────────────────────────────────────
    local twinCatchLevel = 0
    local luckyStrikeLevel = 0
    if _G.getRodBuffs then
        local buffs = _G.getRodBuffs(userID, equippedRod)
        for i = 1, 3 do
            if buffs[i].type == "Twin Catch" then
                twinCatchLevel = twinCatchLevel + buffs[i].level
            elseif buffs[i].type == "Lucky Strike" then
                luckyStrikeLevel = luckyStrikeLevel + buffs[i].level
            end
        end
    end

    local luckyChance = luckyStrikeLevel * 0.001 -- e.g. 1000 DLs = 1.0%
    local forceVariant = false
    if luckyChance > 0 and (math.random() * 100.0) <= luckyChance then
        forceVariant = true
    end

    local drop = nil
    if forceVariant then
        -- Build variant-only pool
        local variantPool = {}
        local vTotal = 0
        for _, entry in ipairs(currentPool) do
            -- Variants have prefixes like `4Devil or [Rare]
            if entry.label:match("%[") or entry.label:match("`[49256e]") then
                table.insert(variantPool, entry)
                vTotal = vTotal + entry.weight
            end
        end
        if #variantPool > 0 then
            drop = pickDrop(variantPool, vTotal)
            if drop then
                player:onConsoleMessage("`6>> Lucky Strike! `eYour rod forced a rare variant!``")
            end
        end
    end

    if not drop then
        drop = pickDrop(currentPool, currentTotalWeight)
    end

    if not drop then
        -- No entries in drop table — allow default drop through
        return false
    end

    -- Apply Twin Catch
    local finalCount = drop.count
    local twinCatchChance = twinCatchLevel * 0.1
    local isDoubled = false
    if twinCatchChance > 0 and (math.random() * 100.0) <= twinCatchChance then
        finalCount = finalCount * 2
        isDoubled = true
        player:onConsoleMessage("`6>> Twin Catch! `eYour rod doubled the loot!``")
    end

    if drop.isVirtual then
        -- Handle virtual fish inventory logic
        local userID = player:getUserID()
        local iconID = drop.iconID or 4320
        local fishWeight = math.random(10, 500) / 10.0 -- Random weight between 1.0kg and 50.0kg
        
        -- Check if player already caught this fish
        local rows = inv_db:query(string.format("SELECT * FROM inventory WHERE player_id=%d AND fish_name='%s'", userID, drop.label))
        if rows and #rows > 0 then
            local currentMax = tonumber(rows[1].max_weight) or 0
            local newMax = math.max(currentMax, fishWeight)
            inv_db:query(string.format("UPDATE inventory SET total_caught = total_caught + %d, max_weight = %f, last_caught = %d WHERE player_id=%d AND fish_name='%s'", 
                finalCount, newMax, os.time(), userID, drop.label))
        else
            inv_db:query(string.format("INSERT INTO inventory (player_id, fish_name, icon_id, total_caught, max_weight, last_caught) VALUES (%d, '%s', %d, %d, %f, %d)", 
                userID, drop.label, iconID, finalCount, fishWeight, os.time()))
        end
        
        -- Virtual feedback
        player:onConsoleMessage("`6>> Fishing: `2You caught a virtual `$" .. drop.label .. "`` `o(" .. string.format("%.1f", fishWeight) .. " kg)! Saved to `/fishinv`.``")
        player:onTalkBubble(player:getNetID(), "`wI just caught a virtual `$" .. drop.label .. "`w!``", 0)
        player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
        
        return not GIVE_DEFAULT_DROP
    end

    -- Give standard physical drop to player
    if not player:changeItem(drop.itemID, finalCount, 0) then
        player:changeItem(drop.itemID, finalCount, 1) -- fallback: backpack
    end

    -- Console message feedback
    player:onConsoleMessage(
        "`6>> Fishing: `2You caught `$" .. formatNum(finalCount) .. "x " .. drop.label ..
        "``! (rolled " .. drop.weight .. "/" .. totalWeight .. " chance)``"
    )
    
    -- Make the player say out loud what they got so everyone sees
    player:onTalkBubble(player:getNetID(), "`wI just fished up `$" .. formatNum(finalCount) .. "x " .. drop.label .. "`w!``", 0)

    -- Particle + sound effect at player position
    player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)

    -- Return false = engine still gives its own default drop PLUS ours
    -- Return true  = engine gives ONLY our drop (suppress default)
    return not GIVE_DEFAULT_DROP
end)

-- ─── /fishconfig command (Developer only) ─────────────────────────────────────
-- Shows the current drop table with weights and chances.

registerLuaCommand({
    command      = "fishconfig",
    roleRequired = ROLE_DEVELOPER,
    description  = "View and understand the server fishing drop table."
})

registerLuaCommand({
    command      = "fishmaker",
    roleRequired = ROLE_DEVELOPER,
    description  = "Open the Developer Custom Fish Generator UI"
})

local function showFishConfig(player)
    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wFishing Drop Config``|left|802|")
    table.insert(d, "add_smalltext|`oServer fishing drop table. Edit `wfishing-drop.lua`` to change drops.``|left|")
    table.insert(d, "add_spacer|small|")

    -- Mode indicator
    local modeLabel = GIVE_DEFAULT_DROP
        and "`2ADDITIVE`` `o(custom + engine default drop)``"
        or  "`4REPLACE``  `o(custom drop only, engine default suppressed)``"
    table.insert(d, "add_smalltext|`oMode: " .. modeLabel .. "|left|")
    table.insert(d, "add_smalltext|`oTotal weight pool: `$" .. formatNum(totalWeight) .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`wDrop Table (`$" .. #DROP_TABLE .. "`` entries):``|left|")
    table.insert(d, "add_spacer|small|")

    for i, entry in ipairs(DROP_TABLE) do
        local chance = totalWeight > 0
            and string.format("%.2f%%", (entry.weight / totalWeight) * 100)
            or  "N/A"
        -- Icon shows what item it is
        table.insert(d, string.format(
            "add_button_with_icon|fc_item_%d||staticGreyFrame,no_padding_x,disabled|%d||",
            i, entry.itemID))
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
        table.insert(d, "add_smalltext|`w" .. entry.label
            .. "``  `ox" .. entry.count
            .. "  |  weight: `$" .. entry.weight
            .. "``  |  chance: `2" .. chance .. "``|left|")
        table.insert(d, "add_spacer|small|")
    end

    table.insert(d, "add_smalltext|`oTo modify: edit the `wDROP_TABLE`` in `wfishing-drop.lua`` and `/rs`` to reload.``|left|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fishconfig_dialog|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── /fishmaker UI and Logic ──────────────────────────────────────────────────
local function getCombinations(arr)
    local results = {{}}
    for i = 1, #arr do
        local el = arr[i]
        local currentLen = #results
        for j = 1, currentLen do
            local newCombo = {}
            for k = 1, #results[j] do table.insert(newCombo, results[j][k]) end
            table.insert(newCombo, el)
            table.insert(results, newCombo)
        end
    end
    return results
end

local function isSafeID(id)
    local itm = getItem(id)
    if not itm then return true end
    local name = itm:getName()
    if not name or name == "" or name == "Blank" or name:sub(1, 5) == "item_" then return true end
    return false
end

local function showFishMakerUI(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wCustom Fish Generator``|left|4320|")
    table.insert(d, "add_smalltext|`oGenerate multiple custom fish combinations at once!|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|base_id|Base Fish Item ID:|4320|5|")
    table.insert(d, "add_smalltext|`o(e.g., 4320 for Bass)|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|base_name|Base Name:|Kraken|30|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|prefixes|Prefixes (comma separated):|Diamond, Mutated, Rainbow|60|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|start_id|Starting Target ID:|25010|10|")
    table.insert(d, "end_dialog|fishmaker_submit|Cancel|Generate!|\nadd_quick_exit|")
    player:onDialogRequest(table.concat(d, "\n"))
    resetStyle(player)
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == "fishconfig" then
        if not player:hasRole(ROLE_DEVELOPER) then
            player:onConsoleMessage("`4Access Denied: `o/fishconfig requires Developer role.``")
            return true
        end
        showFishConfig(player)
        return true
    end

    if cmd:lower() == "fishmaker" then
        if not player:hasRole(ROLE_DEVELOPER) then
            player:onConsoleMessage("`4Access Denied: `o/fishmaker requires Developer role.``")
            return true
        end
        showFishMakerUI(player)
        return true
    end

    return false
end)

onPlayerDialogCallback(function(world, player, data)
    if data["dialog_name"] == "fishmaker_submit" then
        if data["buttonClicked"] ~= "1" then return true end

        local base_id = tonumber(data["base_id"]) or 0
        local base_name = data["base_name"] or ""
        local prefixes_str = data["prefixes"] or ""
        local start_id = tonumber(data["start_id"]) or 25010
        
        if base_id <= 0 or base_name == "" then return true end
        local baseItem = getItem(base_id)
        if not baseItem then return true end

        local prefixes = {}
        for p in prefixes_str:gmatch("[^,]+") do
            local trimmed = p:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then table.insert(prefixes, trimmed) end
        end

        local combos = getCombinations(prefixes)
        local current_id = start_id
        local generatedCount = 0
        
        local luaBlock = "\n-- Auto-Generated by /fishmaker\n"
        luaBlock = luaBlock .. "do\n"
        
        for _, combo in ipairs(combos) do
            local fullName = (#combo > 0 and (table.concat(combo, " ") .. " " .. base_name)) or base_name
            while not isSafeID(current_id) do current_id = current_id + 1 end
            
            local tgt = getItem(current_id)
            if tgt then
                tgt:setName(fullName)
                tgt:setTexture(baseItem:getTexture())
                tgt:setTextureX(baseItem:getTextureX())
                tgt:setTextureY(baseItem:getTextureY())
                tgt:setTextureHash(baseItem:getTextureHash())
                tgt:setCategoryType(baseItem:getCategoryType())
                tgt:setActionType(baseItem:getActionType())
            end
            
            luaBlock = luaBlock .. string.format("    local tgt = getItem(%d)\n", current_id)
            luaBlock = luaBlock .. string.format("    if tgt then tgt:setName(%q) tgt:setTexture(%q) tgt:setTextureX(%d) tgt:setTextureY(%d) end\n", fullName, baseItem:getTexture(), baseItem:getTextureX(), baseItem:getTextureY())
            
            player:onConsoleMessage("`2>> Generated: `w" .. fullName .. " `o(ID: " .. current_id .. ")``")
            current_id = current_id + 1
            generatedCount = generatedCount + 1
        end
        luaBlock = luaBlock .. "end\n"
        
        local f = io.open("custom-fish-data.lua", "a")
        if f then f:write(luaBlock) f:close() end

        player:onTalkBubble(player:getNetID(), "`2Generated " .. generatedCount .. " custom fishes!``", 0)
        return true
    end
    return false
end)
