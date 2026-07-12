-- ─────────────────────────────────────────────────────────────────────────────
-- Procedural Developer Fishing Loot Manager
-- Command: /fishloot
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Procedural Developer Fishing Loot Manager")

local DB_PATH = "fishing_loot.db"
local db = sqlite.open(DB_PATH)

local ROLE_DEVELOPER = 51

-- ─── UI Helpers ───────────────────────────────────────────────────────────────
local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(30, 10, 10, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 100, 0, 255) end
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

local function formatPrefix(prefix)
    local pLower = prefix:lower()
    if pLower == "devil" then
        return "`4" .. prefix .. "`w"
    elseif pLower == "diamond" then
        return "`9" .. prefix .. "`w"
    elseif pLower == "big" then
        return "`2" .. prefix .. "`w"
    elseif pLower == "mutated" then
        return "`5" .. prefix .. "`w"
    elseif pLower == "godly" then
        return "`6" .. prefix .. "`w"
    elseif pLower == "rainbow" then
        local rainbowStr = ""
        local colors = {"`4", "`6", "`e", "`2", "`9", "`p", "`5"}
        for i = 1, #prefix do
            local c = prefix:sub(i, i)
            local colorCode = colors[((i - 1) % #colors) + 1]
            rainbowStr = rainbowStr .. colorCode .. c
        end
        return rainbowStr .. "`w"
    else
        return "`w" .. prefix .. "`w"
    end
end

-- ─── UI: Main Manager Menu ──────────────────────────────────────────────────────
function showLootMenu(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`4Procedural Loot Manager``|left|802|")
    table.insert(d, "add_smalltext|`oManage the custom fishing drop table dynamically.``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_button|loot_view_active|`w1. Manage Active Loot Table``|no_flags|0|0|")
    table.insert(d, "add_button|loot_generate|`22. Generate Virtual Fish Family``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fishloot_main|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── UI: Manage Active Loot ───────────────────────────────────────────────────
local function showActiveLoot(player, page)
    page = page or 1
    local PER_PAGE = 10
    
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`4Active Custom Loot``|left|802|")
    table.insert(d, "add_spacer|small|")

    local countRow = db:query("SELECT COUNT(*) as cnt FROM custom_loot")
    local totalItems = (countRow and countRow[1]) and tonumber(countRow[1].cnt) or 0
    local totalPages = math.max(1, math.ceil(totalItems / PER_PAGE))
    
    if totalItems == 0 then
        table.insert(d, "add_textbox|`oThe custom drop table is completely empty!``|left|")
    else
        table.insert(d, "add_smalltext|`oTotal Virtual Fish: `$" .. totalItems .. "``|left|")
        table.insert(d, "add_spacer|small|")
        
        local offset = (page - 1) * PER_PAGE
        local rows = db:query(string.format("SELECT * FROM custom_loot ORDER BY weight DESC LIMIT %d OFFSET %d", PER_PAGE, offset))
        
        for i, row in ipairs(rows or {}) do
            local itemID = tonumber(row.item_id)
            local weight = tonumber(row.weight)
            local isVirtual = tonumber(row.is_virtual) == 1
            
            table.insert(d, string.format("add_button_with_icon|noop%d||staticGreyFrame,no_padding_x,disabled|%d||", i, itemID))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
            
            local virtTag = isVirtual and "`9[Virtual]`` " or "`2[Physical]`` "
            table.insert(d, "add_smalltext|" .. virtTag .. "`w" .. row.label .. "  `o(Weight: `$" .. weight .. "`o)``|left|")
            table.insert(d, "add_button|loot_remove_" .. row.id .. "|`4Remove``|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
        
        if totalPages > 1 then
            table.insert(d, "embed_data|active_page|" .. page)
            local pBtn = page > 1 and "`w← Prev``" or "`o← Prev``"
            local nBtn = page < totalPages and "`wNext →``" or "`oNext →``"
            table.insert(d, "add_button|loot_prev_page|" .. pBtn .. "|no_flags|0|0|")
            table.insert(d, "add_button|loot_next_page|" .. nBtn .. "|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_button|loot_wipe_all|`4Wipe Entire Drop Table``|no_flags|0|0|")
    table.insert(d, "add_button|loot_back_main|`oBack``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fishloot_active|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── UI: Generate Virtual Fish Family ─────────────────────────────────────────
local function showGenerateUI(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`2Procedural Generator``|left|802|")
    table.insert(d, "add_smalltext|`oGenerate hundreds of virtual fish combinations automatically!``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_text_input|gen_basename|Base Name:|Kraken|30|")
    table.insert(d, "add_smalltext|`o(e.g., Kraken, Whale, Bass)``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_text_input|gen_icon|Base Icon ID:|4320|10|")
    table.insert(d, "add_smalltext|`o(This icon is used in the /fishinv UI for all generated variants)``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_text_input|gen_prefixes|Prefixes (comma separated):|Rainbow, Mutated, Diamond, Skeleton, Big, Devil|120|")
    table.insert(d, "add_smalltext|`o(e.g., The system generates combinations like 'Diamond Mutated Kraken')``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_text_input|gen_baseweight|Base Drop Weight (Base Fish):|1000|10|")
    table.insert(d, "add_smalltext|`o(Higher weight = drops more often. Common=1000, UltraRare=1)``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_text_input|gen_penalty|Rarity Penalty:|5|5|")
    table.insert(d, "add_smalltext|`o(For every prefix a fish has, its weight is divided by this number. e.g. 5)``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_text_input|gen_rarity|Rarity Tag:|Normal|20|")
    table.insert(d, "add_smalltext|`o(e.g., Normal, Rare, Super Rare, Ultra Rare, Legendary, Mythical)``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_button|loot_do_generate|`2Generate & Add to Loot Table``|no_flags|0|0|")
    table.insert(d, "add_button|loot_back_main|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fishloot_gen|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Commands ─────────────────────────────────────────────────────────────────
registerLuaCommand({
    command      = "fishloot",
    roleRequired = ROLE_DEVELOPER,
    description  = "Developer: Manage Custom Fish Drop Tables dynamically!"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    if cmd:lower() == "fishloot" then
        if not player:hasRole(ROLE_DEVELOPER) then
            player:onConsoleMessage("`4Access Denied: Requires Developer role.``")
            return true
        end
        showLootMenu(player)
        return true
    end
    return false
end)

-- ─── Dialog Callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg     = data["dialog_name"]   or ""
    local clicked = data["buttonClicked"] or ""

    if dlg == "portal_shortcuts" and clicked == "sc_fishloot" then
        showLootMenu(player)
        return true
    end

    if dlg == "fishloot_main" then
        if clicked == "loot_view_active" then showActiveLoot(player, 1) return true end
        if clicked == "loot_generate" then showGenerateUI(player) return true end
        return true
    end

    if dlg == "fishloot_active" then
        local page = tonumber(data["active_page"] and data["active_page"]:sub(1,-2)) or 1
        
        if clicked == "loot_back_main" then showLootMenu(player) return true end
        if clicked == "loot_prev_page" then showActiveLoot(player, math.max(1, page - 1)) return true end
        if clicked == "loot_next_page" then showActiveLoot(player, page + 1) return true end
        
        if clicked == "loot_wipe_all" then
            db:query("DELETE FROM custom_loot")
            player:onConsoleMessage("`4>> Wiped all custom drops!``")
            if loadExclusiveDropTable then loadExclusiveDropTable() end
            showActiveLoot(player, 1)
            return true
        end
        
        local rmIdx = tonumber(clicked:match("^loot_remove_(%d+)$"))
        if rmIdx then
            db:query(string.format("DELETE FROM custom_loot WHERE id = %d", rmIdx))
            player:onConsoleMessage("`4>> Removed item from loot table!``")
            
            -- Trigger reload in fishing-drop.lua!
            if loadExclusiveDropTable then loadExclusiveDropTable() end
            
            showActiveLoot(player, page)
            return true
        end
        return true
    end

    if dlg == "fishloot_gen" then
        if clicked == "loot_back_main" then showLootMenu(player) return true end
        
        if clicked == "loot_do_generate" then
            local baseName = data["gen_basename"] or ""
            local iconID = tonumber(data["gen_icon"]) or 4320
            local prefixStr = data["gen_prefixes"] or ""
            local baseWeight = tonumber(data["gen_baseweight"]) or 1000
            local penalty = tonumber(data["gen_penalty"]) or 5
            local rarityTag = data["gen_rarity"] or ""
            
            if baseName == "" or penalty <= 0 then return true end
            
            local prefixes = {}
            for p in prefixStr:gmatch("[^,]+") do
                local trimmed = p:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then table.insert(prefixes, trimmed) end
            end

            local combos = getCombinations(prefixes)
            local generatedCount = 0
            
            -- Determine Rarity Color
            local rColor = "`o"
            local rLower = rarityTag:lower()
            if rLower == "rare" then rColor = "`3"
            elseif rLower == "super rare" then rColor = "`b"
            elseif rLower == "ultra rare" then rColor = "`c"
            elseif rLower == "legendary" then rColor = "`6"
            elseif rLower == "mythical" then rColor = "`5"
            end
            local formattedRarity = ""
            if rarityTag ~= "" then
                formattedRarity = " " .. rColor .. "[" .. rarityTag .. "]`w"
            end
            
            for _, combo in ipairs(combos) do
                local prefixCount = #combo
                local formattedCombo = {}
                for _, p in ipairs(combo) do
                    table.insert(formattedCombo, formatPrefix(p))
                end
                
                local fullName = (prefixCount > 0 and (table.concat(formattedCombo, " ") .. " `w" .. baseName)) or ("`w" .. baseName)
                fullName = fullName .. formattedRarity
                
                -- Calculate weight: baseWeight / (penalty ^ prefixCount)
                local weight = math.floor(baseWeight / (math.pow(penalty, prefixCount)))
                if weight < 1 then weight = 1 end
                
                -- Insert into SQLite (is_virtual = 1 for purely virtual procedural fish)
                db:query(string.format(
                    "INSERT INTO custom_loot (item_id, count, weight, label, is_virtual) VALUES (%d, 1, %d, '%s', 1)",
                    iconID, weight, fullName:gsub("'", "''")
                ))
                
                generatedCount = generatedCount + 1
            end
            
            player:onConsoleMessage("`2>> Successfully generated and injected `w" .. generatedCount .. "`2 virtual fish combinations into the active drop table!``")
            
            -- Trigger reload in fishing-drop.lua!
            if loadExclusiveDropTable then loadExclusiveDropTable() end
            
            showActiveLoot(player, 1)
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
