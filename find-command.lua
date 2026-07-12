-- Developer Item Spawner Command (/f)
print("(Loaded) Developer Item Spawner script for GrowSoft")

Roles = {
    ROLE_NONE              = 0,
    ROLE_VIP               = 1,
    ROLE_SUPER_VIP         = 2,
    ROLE_MODERATOR         = 3,
    ROLE_ADMIN             = 4,
    ROLE_COMMUNITY_MANAGER = 5,
    ROLE_CREATOR           = 6,
    ROLE_GOD               = 7,
    ROLE_DEVELOPER         = 51
}

local SPAWN_AMOUNT = 250
local PAGE_SIZE    = 10  -- 10 items per page - compact and fits cleanly

registerLuaCommand({
    command      = "f",
    roleRequired = Roles.ROLE_DEVELOPER,
    description  = "Developer: Open the item search and spawn panel. /f [name]"
})

-- ─── embed_data safe reader ───────────────────────────────────────────────────
-- The GrowSoft engine appends a trailing character to every embed_data value
-- when it comes back in the dialog callback. Strip it exactly like
-- marvelous-missions.lua does: string.sub(data["tab"], 1, -2)
local function edata(val, default)
    if val == nil or val == "" then return default end
    return string.sub(val, 1, -2)
end

-- ─── Categoriser ──────────────────────────────────────────────────────────────
local function categorizeItem(item)
    local name = item:getName():lower()

    -- Wings must be checked first before clothes
    if name:find("wing") then return "wings" end

    -- Locks - match " lock" suffix or starts with "lock"
    if name:find(" lock") or name:match("^lock") or name == "world lock" or name == "diamond lock" then
        return "locks"
    end

    -- Use server item type when available
    if item.getItemType then
        local t = item:getItemType()
        if type(t) == "number" then
            if t == 4 then return "clothes"     end
            if t == 3 then return "backgrounds" end
            if t == 0 or t == 1 or t == 2 then return "blocks" end
        end
    end

    -- Keyword fallback from item info
    local info = ""
    if item.getInfo then
        for _, l in ipairs(item:getInfo() or {}) do
            info = info .. l:lower()
        end
    end

    if info:find("clothing") or info:find("apparel") then return "clothes"     end
    if info:find("background")                        then return "backgrounds" end
    if info:find("block") or info:find("foreground")  then return "blocks"      end

    return "others"
end

-- ─── Style helpers ────────────────────────────────────────────────────────────
local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(18, 18, 28, 245)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 195, 0, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- ─── Build match list ─────────────────────────────────────────────────────────
local function buildMatches(searchQuery, activeCategory)
    local matches = {}
    local total   = getItemsCount() or 0
    local q       = (searchQuery and searchQuery ~= "") and searchQuery:lower() or nil

    for i = 1, total - 1 do
        local item = getItem(i)
        if item then
            local nm = item:getName()
            if nm and nm ~= "" then
                local ok = true
                if q then ok = nm:lower():find(q, 1, true) ~= nil end
                if ok and activeCategory ~= "all" then
                    ok = (categorizeItem(item) == activeCategory)
                end
                if ok then table.insert(matches, item) end
            end
        end
    end
    return matches
end

-- ─── Category label helper ────────────────────────────────────────────────────
local catKeys   = { "all", "blocks", "backgrounds", "clothes", "wings", "locks", "others" }
local catLabels = {
    all         = "All Items",
    blocks      = "Blocks",
    backgrounds = "Backgrounds",
    clothes     = "Clothes",
    wings       = "Wings",
    locks       = "Locks",
    others      = "Others",
}

-- ─── Main Spawner Dialog ──────────────────────────────────────────────────────
local function showSpawner(player, searchQuery, activeCategory, currentPage)
    currentPage    = math.max(1, tonumber(currentPage) or 1)
    activeCategory = activeCategory or "all"
    searchQuery    = searchQuery    or ""

    local matches    = buildMatches(searchQuery, activeCategory)
    local total      = #matches
    local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
    if currentPage > totalPages then currentPage = totalPages end

    local si = (currentPage - 1) * PAGE_SIZE + 1
    local ei = math.min(total, currentPage * PAGE_SIZE)

    applyStyle(player)

    -- ── Build dialog string directly (no table concat performance issue)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wDev Item Spawner``|left|6016|")
    table.insert(d, "add_smalltext|Search items by name, filter by category, tap an item to spawn 250.|left|")
    table.insert(d, "add_spacer|small|")

    -- State embed
    table.insert(d, "embed_data|st_q|"    .. searchQuery)
    table.insert(d, "embed_data|st_cat|"  .. activeCategory)
    table.insert(d, "embed_data|st_page|" .. currentPage)

    -- ── Category filter buttons using standard add_button (no overflow risk)
    table.insert(d, "add_textbox|`oFilter category:``|left|")
    for _, key in ipairs(catKeys) do
        local lbl = (activeCategory == key)
                    and ("`2[ " .. catLabels[key] .. " ]``")
                    or  ("`o"   .. catLabels[key] .. "``")
        table.insert(d, "add_button|cat_" .. key .. "|" .. lbl .. "|no_flags|0|0|")
    end
    table.insert(d, "add_spacer|small|")

    -- ── Search field
    table.insert(d, "add_text_input|sq|Search by name (partial ok):|" .. searchQuery .. "|22|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|btn_search|`wSearch``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")

    -- ── Result count / page info
    if total > 0 then
        table.insert(d, "add_smalltext|`oFound `$" .. total
            .. "`` items  |  Page `$" .. currentPage
            .. "`` of `$" .. totalPages
            .. "`` (`$" .. si .. "-" .. ei .. "``)``|left|")
    else
        table.insert(d, "add_smalltext|`4No items match your search or filter.``|left|")
    end
    table.insert(d, "add_spacer|small|")

    -- ── Item list using add_button_with_icon (icon + name beside it, no overflow)
    -- Format: add_button_with_icon|buttonID|label|flags|itemID|count|
    -- staticGreyFrame,no_padding_x shows the item icon cleanly with label to the right
    if total > 0 then
        for i = si, ei do
            local item = matches[i]
            local cat  = categorizeItem(item)
            -- Color code the category prefix label
            local catColor = "`o"
            if     cat == "blocks"      then catColor = "`2"
            elseif cat == "locks"       then catColor = "`q"
            elseif cat == "backgrounds" then catColor = "`9"
            elseif cat == "clothes"     then catColor = "`5"
            elseif cat == "wings"       then catColor = "`e"
            end

            local label = catColor .. item:getName() .. "`` `o(ID:" .. item:getID() .. ")``"
            table.insert(d, string.format(
                "add_button_with_icon|pick_%d|%s|staticGreyFrame,no_padding_x|%d||",
                item:getID(), label, item:getID()
            ))
        end
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    end

    table.insert(d, "add_spacer|small|")

    -- ── Pagination buttons
    if totalPages > 1 then
        local prevLbl = currentPage > 1
                        and "`w<< Prev``"
                        or  "`o<< Prev``"
        local nextLbl = currentPage < totalPages
                        and "`wNext >>``"
                        or  "`oNext >>``"
        table.insert(d, "add_button|btn_prev|" .. prevLbl .. "|no_flags|0|0|")
        table.insert(d, "add_button|btn_next|" .. nextLbl .. "|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fs_main|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Item Detail Dialog ───────────────────────────────────────────────────────
local function showDetail(player, itemID, sq, cat, page)
    local item = getItem(itemID)
    if not item then return end

    local cat_label = categorizeItem(item):upper()

    local infoRows = {}
    if item.getInfo then
        for _, ln in ipairs(item:getInfo() or {}) do
            if ln and ln ~= "" then
                table.insert(infoRows, "add_smalltext|" .. ln .. "|left|")
            end
        end
    end

    applyStyle(player)

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`w" .. item:getName() .. "``|left|" .. itemID .. "|")
    table.insert(d, "add_spacer|small|")

    -- State for back navigation
    table.insert(d, "embed_data|dt_id|"   .. itemID)
    table.insert(d, "embed_data|dt_q|"    .. (sq   or ""))
    table.insert(d, "embed_data|dt_cat|"  .. (cat  or "all"))
    table.insert(d, "embed_data|dt_page|" .. (page or 1))

    -- Item details
    table.insert(d, "add_smalltext|`oItem ID:`` `w" .. itemID .. "``|left|")
    table.insert(d, "add_smalltext|`oCategory:`` `$" .. cat_label .. "``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`5Description:`` `o" .. item:getDescription() .. "``|left|")

    -- Extra info from DB
    if #infoRows > 0 then
        table.insert(d, "add_spacer|small|")
        table.insert(d, "add_smalltext|`oItem Info:``|left|")
        for _, row in ipairs(infoRows) do
            table.insert(d, row)
        end
    end

    table.insert(d, "add_spacer|small|")

    -- Icon preview (single item icon displayed via icon grid)
    table.insert(d, "add_button_with_icon|preview_icon||staticBlueFrame,disabled|" .. itemID .. "||")
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_spacer|small|")

    -- Action buttons
    table.insert(d, "add_button|do_spawn|`2Spawn " .. SPAWN_AMOUNT .. "x " .. item:getName() .. "``|no_flags|0|0|")
    table.insert(d, "add_button|do_back|`oBack to list``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|fs_detail|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Command Entry ────────────────────────────────────────────────────────────
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, msg = fullCommand:match("^(%S+)%s*(.*)")
    if cmd:lower() ~= "f" then return false end

    if not player:hasRole(Roles.ROLE_DEVELOPER) then
        player:onConsoleMessage("`4Access Denied: `oThe /f command requires Developer role.``")
        return true
    end

    showSpawner(player, msg, "all", 1)
    return true
end)

-- ─── Dialog Callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""

    -- ── Main spawner panel ──────────────────────────────────────────────────
    if dlg == "fs_main" then
        if not player:hasRole(Roles.ROLE_DEVELOPER) then return true end

        -- Strip trailing engine-appended character from all embed_data values
        local sq      = edata(data["st_q"],    "")
        local cat     = edata(data["st_cat"],   "all")
        local page    = tonumber(edata(data["st_page"], "1")) or 1
        local clicked = data["buttonClicked"] or ""

        -- Category switch buttons
        for _, key in ipairs(catKeys) do
            if clicked == "cat_" .. key then
                showSpawner(player, sq, key, 1)
                return true
            end
        end

        if clicked == "btn_search" then
            -- Search box value comes from text_input, NOT embed_data — no strip needed
            local newQuery = data["sq"] or ""
            showSpawner(player, newQuery, cat, 1)
            return true
        elseif clicked == "btn_prev" then
            showSpawner(player, sq, cat, page - 1)
            return true
        elseif clicked == "btn_next" then
            showSpawner(player, sq, cat, page + 1)
            return true
        elseif clicked:sub(1, 5) == "pick_" then
            local id = tonumber(clicked:sub(6))
            if id then showDetail(player, id, sq, cat, page) end
            return true
        end

        return true
    end

    -- ── Item detail panel ────────────────────────────────────────────────────
    if dlg == "fs_detail" then
        if not player:hasRole(Roles.ROLE_DEVELOPER) then return true end

        -- Strip trailing engine-appended character from all embed_data values
        local id      = tonumber(edata(data["dt_id"],   "0"))
        local sq      = edata(data["dt_q"],    "")
        local cat     = edata(data["dt_cat"],   "all")
        local page    = tonumber(edata(data["dt_page"], "1")) or 1
        local clicked = data["buttonClicked"] or ""

        if clicked == "do_back" then
            showSpawner(player, sq, cat, page)
            return true
        elseif clicked == "do_spawn" and id then
            local item = getItem(id)
            if item then
                if not player:changeItem(id, SPAWN_AMOUNT, 0) then
                    player:changeItem(id, SPAWN_AMOUNT, 1)
                end
                player:playAudio("piano_nice.wav")
                player:onConsoleMessage(
                    "`6>> Spawner: `2Gave `$" .. SPAWN_AMOUNT ..
                    "x`` `w" .. item:getName() ..
                    "`` (ID: " .. id .. ").``")
                showDetail(player, id, sq, cat, page)
            end
            return true
        end

        return true
    end

    return false
end)
