-- Item Exchange Script — Masterpiece UI Rewrite
-- Backend: SQLite + Discord logging (unchanged)
-- UI: Completely redesigned using proven GrowSoft dialog patterns
print("(Loaded) Item Exchange Script for GrowSoft")

-- ─── Constants ────────────────────────────────────────────────────────────────
local MAX_ITEM_STACK   = 250
local EXCHANGE_DB_PATH = "item_exchange.db"
local ITEMS_PER_PAGE   = 5   -- exchange entries per page in player UI

local Config = {
    ANNOUNCEMENT_CHANNEL_ID = "1476917334936387594"
}

-- Roles allowed to manage exchanges (Developer=51, Master=100)
local ALLOWED_MANAGE_ROLES = { 51, 100 }

-- ─── Database Setup ───────────────────────────────────────────────────────────
local db = sqlite.open(EXCHANGE_DB_PATH)

local function initDatabase()
    db:query([[
        CREATE TABLE IF NOT EXISTS exchange_configs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            amount_required INTEGER NOT NULL,
            item_to_give_id INTEGER NOT NULL,
            amount_to_give INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            created_by INTEGER,
            updated_at INTEGER
        )
    ]])
    db:query([[
        CREATE TABLE IF NOT EXISTS exchange_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_userid INTEGER,
            player_name TEXT,
            player_role INTEGER,
            item_id INTEGER,
            item_name TEXT,
            amount_required INTEGER,
            item_given_id INTEGER,
            item_given_name TEXT,
            amount_given INTEGER,
            quantity INTEGER,
            timestamp INTEGER
        )
    ]])
    print("Exchange database initialized")
end
initDatabase()

-- ─── State Storage ────────────────────────────────────────────────────────────
local exchangeConfigs  = {}
local exchangeSessions = {}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
-- Strip trailing engine-appended byte from embed_data (marvelous-missions.lua pattern)
local function edata(val, default)
    if val == nil or val == "" then return default end
    return string.sub(val, 1, -2)
end

local function exchange_getItemName(itemID)
    local item = getItem(itemID)
    return item and item:getName() or ("Item #" .. itemID)
end

local function exchange_getSession(player)
    local netID = tostring(player:getNetID())
    exchangeSessions[netID] = exchangeSessions[netID] or {
        currentConfig = {},
        editingIndex  = nil,
        pendingRemove = nil
    }
    return exchangeSessions[netID]
end

local function hasManageAccess(player)
    for _, roleId in ipairs(ALLOWED_MANAGE_ROLES) do
        if player:hasRole(roleId) then return true end
    end
    return false
end

local function formatNum(num)
    local s = tostring(math.floor(tonumber(num) or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return s:gsub("^,", "")
end

-- Style helpers (dark navy + gold border, same as coinflip/find-command)
local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(10, 10, 20, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 200, 0, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- ─── Discord Logging (unchanged) ──────────────────────────────────────────────
local function exchange_sendDiscordLog(title, description, color)
    if not Config.ANNOUNCEMENT_CHANNEL_ID or Config.ANNOUNCEMENT_CHANNEL_ID == "" then return end
    if DiscordBot and DiscordBot.messageCreate then
        DiscordBot.messageCreate(Config.ANNOUNCEMENT_CHANNEL_ID, "", {}, 0, 0, {
            title = title, description = description, color = color or 5793266,
        })
    else
        print("[Discord Log] " .. title .. " - " .. description)
    end
end

local function exchange_formatTransactionLog(player, exchange, quantity, totalCost, totalReward)
    local playerName = player:getRealCleanName() or player:getName() or "Unknown"
    local userID     = player:getUserID()
    local roleName   = "Player"
    if player:hasRole(100) then roleName = "Master"
    elseif player:hasRole(51) then roleName = "Developer"
    elseif player:hasRole(5)  then roleName = "Super Moderator"
    elseif player:hasRole(4)  then roleName = "Moderator"
    elseif player:hasRole(3)  then roleName = "Guardian"
    elseif player:hasRole(2)  then roleName = "Super VIP"
    elseif player:hasRole(1)  then roleName = "VIP"
    end
    return string.format(
        "**Player:** %s (ID: %d)\n**Role:** %s\n**Quantity:** %dx\n\n**📤 Gave:** %d x %s\n**📥 Received:** %d x %s",
        playerName, userID, roleName, quantity,
        totalCost, exchange_getItemName(exchange.itemID),
        totalReward, exchange_getItemName(exchange.itemToGiveID)
    )
end

local function exchange_formatManageLog(player, action, config, oldConfig)
    local playerName = player:getRealCleanName() or player:getName() or "Unknown"
    local userID     = player:getUserID()
    local roleName   = player:hasRole(100) and "Master" or "Developer"
    local reqName    = exchange_getItemName(config.itemID)
    local giveName   = exchange_getItemName(config.itemToGiveID)
    local configText = string.format("%d x %s → %d x %s", config.amountRequired, reqName, config.amount, giveName)
    local desc = string.format(
        "**Staff:** %s (ID: %d) [%s]\n**Action:** %s\n**Configuration:** %s",
        playerName, userID, roleName, action, configText
    )
    if oldConfig then
        local oldReqName  = exchange_getItemName(oldConfig.itemID)
        local oldGiveName = exchange_getItemName(oldConfig.itemToGiveID)
        desc = desc .. "\n**Previous:** " ..
            string.format("%d x %s → %d x %s", oldConfig.amountRequired, oldReqName, oldConfig.amount, oldGiveName)
    end
    return desc
end

-- ─── Database Operations (unchanged) ─────────────────────────────────────────
local function exchange_getNextId()
    local rows = db:query("SELECT MAX(id) as max_id FROM exchange_configs")
    if rows and rows[1] and rows[1].max_id then return rows[1].max_id + 1 end
    return 1
end

local function exchange_loadConfigs()
    exchangeConfigs = {}
    local rows = db:query("SELECT * FROM exchange_configs ORDER BY id ASC")
    if rows then
        for _, row in ipairs(rows) do
            table.insert(exchangeConfigs, {
                id             = row.id,
                itemID         = row.item_id,
                amountRequired = row.amount_required,
                itemToGiveID   = row.item_to_give_id,
                amount         = row.amount_to_give,
                created_at     = row.created_at,
                created_by     = row.created_by
            })
        end
    end
    print(string.format("Loaded %d exchange configurations from database", #exchangeConfigs))
end

local function exchange_addConfig(config, player)
    local created_by = player and player:getUserID() or 0
    db:query(string.format([[
        INSERT INTO exchange_configs (item_id, amount_required, item_to_give_id, amount_to_give, created_at, created_by, updated_at)
        VALUES (%d, %d, %d, %d, %d, %d, %d)
    ]], config.itemID, config.amountRequired, config.itemToGiveID, config.amount, os.time(), created_by, os.time()))
    local idQuery = db:query("SELECT last_insert_rowid() as last_id")
    config.id = (idQuery and idQuery[1]) and idQuery[1].last_id or exchange_getNextId()
    table.insert(exchangeConfigs, config)
    return config
end

local function exchange_updateConfig(index, config, player)
    local existing = exchangeConfigs[index]
    if not existing then return false end
    db:query(string.format([[
        UPDATE exchange_configs
        SET item_id = %d, amount_required = %d, item_to_give_id = %d, amount_to_give = %d, updated_at = %d
        WHERE id = %d
    ]], config.itemID, config.amountRequired, config.itemToGiveID, config.amount, os.time(), existing.id))
    config.id = existing.id
    exchangeConfigs[index] = config
    return true
end

local function exchange_removeConfig(index)
    local config = exchangeConfigs[index]
    if not config then return false end
    db:query(string.format("DELETE FROM exchange_configs WHERE id = %d", config.id))
    table.remove(exchangeConfigs, index)
    return true
end

local function exchange_logTransaction(player, exchange, quantity, totalCost, totalReward)
    local userID     = player:getUserID()
    local playerName = player:getRealCleanName() or player:getName() or "Unknown"
    local playerRole = 0
    for _, roleId in ipairs(ALLOWED_MANAGE_ROLES) do
        if player:hasRole(roleId) then playerRole = roleId break end
    end
    db:query(string.format([[
        INSERT INTO exchange_logs (player_userid, player_name, player_role, item_id, item_name, amount_required,
                                   item_given_id, item_given_name, amount_given, quantity, timestamp)
        VALUES (%d, '%s', %d, %d, '%s', %d, %d, '%s', %d, %d, %d)
    ]], userID, playerName:gsub("'", "''"), playerRole,
        exchange.itemID, exchange_getItemName(exchange.itemID):gsub("'", "''"), exchange.amountRequired,
        exchange.itemToGiveID, exchange_getItemName(exchange.itemToGiveID):gsub("'", "''"), exchange.amount,
        quantity, os.time()))
    exchange_sendDiscordLog("🔄 Item Exchange Completed",
        exchange_formatTransactionLog(player, exchange, quantity, totalCost, totalReward), 3447003)
end

local function exchange_logManageAction(player, action, config, oldConfig)
    local color = 0
    if action == "Added"   then color = 3066993
    elseif action == "Updated" then color = 15844367
    elseif action == "Removed" then color = 15158332
    end
    exchange_sendDiscordLog("⚙️ Exchange Configuration " .. action,
        exchange_formatManageLog(player, action, config, oldConfig), color)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████████████  MASTERPIECE UI FUNCTIONS  ██████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── [PLAYER] Main Exchange List ──────────────────────────────────────────────
-- Shows paginated list of all active exchange configs.
-- Each entry: item to give (grey, display) | arrow | item to receive (yellow, clickable).
local function exchange_showPlayerDialog(player, page)
    page = math.max(1, tonumber(page) or 1)

    local total      = #exchangeConfigs
    local totalPages = math.max(1, math.ceil(total / ITEMS_PER_PAGE))
    if page > totalPages then page = totalPages end

    local si = (page - 1) * ITEMS_PER_PAGE + 1
    local ei = math.min(total, page * ITEMS_PER_PAGE)

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wExchange Center``|left|12592|")
    table.insert(d, "add_smalltext|`oTrade your items for something better! Tap the `$yellow`` item to start exchanging.``|left|")
    table.insert(d, "add_spacer|small|")

    -- State embed
    table.insert(d, "embed_data|ex_page|" .. page)

    if total == 0 then
        table.insert(d, "add_textbox|`oNo exchange configurations are available right now. Check back later!``|left|")
        table.insert(d, "add_spacer|small|")
    else
        -- Page info
        if totalPages > 1 then
            table.insert(d, "add_smalltext|`oShowing `$" .. si .. "-" .. ei
                .. "`` of `$" .. total .. "`` exchanges  |  Page `$"
                .. page .. "/" .. totalPages .. "``|left|")
            table.insert(d, "add_spacer|small|")
        end

        -- Exchange rows
        for i = si, ei do
            local cfg     = exchangeConfigs[i]
            local reqName = exchange_getItemName(cfg.itemID)
            local givName = exchange_getItemName(cfg.itemToGiveID)

            -- ── Exchange entry header (plain text, wraps safely on its own line)
            table.insert(d, "add_textbox|`o#" .. i .. "  Exchange``|left|")

            -- ── Icon row: icons ONLY — no long text inside button labels.
            -- Long names in button labels cause text to collide in the horizontal row.
            -- Count badges show via is_count_label flag on the item icon itself.
            table.insert(d, string.format(
                "add_button_with_icon|ex_req_%d||staticGreyFrame,no_padding_x,is_count_label,disabled|%d|%d|",
                i, cfg.itemID, cfg.amountRequired))
            -- Arrow separator
            table.insert(d, "add_button_with_icon|ex_arrow_" .. i .. "||noflags,disabled|11162||")
            -- Yellow frame = tappable to start exchange
            table.insert(d, string.format(
                "add_button_with_icon|ex_give_%d||staticYellowFrame,no_padding_x,is_count_label|%d|%d|",
                i, cfg.itemToGiveID, cfg.amount))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")

            -- ── Item name labels on their OWN lines (add_smalltext wraps naturally,
            -- never overlaps with adjacent buttons or other text)
            table.insert(d, "add_smalltext|`oGive: `w" .. formatNum(cfg.amountRequired)
                .. "x " .. reqName .. "``|left|")
            table.insert(d, "add_smalltext|`oGet:  `$" .. formatNum(cfg.amount)
                .. "x " .. givName .. "``|left|")

            -- ── Inventory availability hint
            local playerHas = tonumber(player:getItemAmount(cfg.itemID)) or 0
            local canAfford = playerHas >= (tonumber(cfg.amountRequired) or 0)
            if canAfford then
                table.insert(d, "add_smalltext|`2You have " .. formatNum(playerHas)
                    .. "x — ready to exchange! ✓``|left|")
            else
                table.insert(d, "add_smalltext|`4You have " .. formatNum(playerHas)
                    .. "x  (need " .. formatNum(cfg.amountRequired) .. "x)``|left|")
            end
            table.insert(d, "add_spacer|small|")
        end

        -- Pagination buttons
        if totalPages > 1 then
            local prevLabel = page > 1          and "`w<< Previous``" or "`o<< Previous``"
            local nextLabel = page < totalPages and "`wNext >>``"     or "`oNext >>``"
            table.insert(d, "add_button|ex_prev|" .. prevLabel .. "|no_flags|0|0|")
            table.insert(d, "add_button|ex_next|" .. nextLabel .. "|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_smalltext|`oAll exchanges are instant. Results are logged automatically.``|left|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|exchange_player_dialog|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── [PLAYER] Quantity Confirm Dialog ─────────────────────────────────────────
local function exchange_showQuantityDialog(player, index)
    local cfg = exchangeConfigs[index]
    if not cfg then return end

    local reqName  = exchange_getItemName(cfg.itemID)
    local giveName = exchange_getItemName(cfg.itemToGiveID)
    local playerHas = tonumber(player:getItemAmount(cfg.itemID)) or 0
    local amountReq = tonumber(cfg.amountRequired) or 0

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wConfirm Exchange``|left|" .. cfg.itemToGiveID .. "|")
    table.insert(d, "add_spacer|small|")

    -- Exchange preview: what player gives vs what they get
    table.insert(d, "add_textbox|`oYou will give:``|left|")
    table.insert(d, string.format(
        "add_button_with_icon|noop_req||staticGreyFrame,no_padding_x,disabled|%d||",
        cfg.itemID))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`w" .. formatNum(amountReq) .. "x " .. reqName .. "`` per exchange``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`oYou will receive:``|left|")
    table.insert(d, string.format(
        "add_button_with_icon|noop_give||staticYellowFrame,no_padding_x,disabled|%d||",
        cfg.itemToGiveID))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`$" .. formatNum(cfg.amount) .. "x " .. giveName .. "`` per exchange``|left|")
    table.insert(d, "add_spacer|small|")

    -- Inventory status
    local canDo = playerHas >= amountReq
    local balColor = canDo and "`2" or "`4"
    table.insert(d, "add_smalltext|" .. balColor
        .. "Your " .. reqName .. ": " .. formatNum(playerHas) .. "x``|left|")
    table.insert(d, "add_spacer|small|")

    -- Quantity input
    table.insert(d, "add_text_input|exchange_qty_input|How many times? (max " .. MAX_ITEM_STACK .. "):|1|4|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_smalltext|`oTap `wConfirm`` or close to cancel.``|left|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|exchange_confirm_qty_" .. index .. "|Cancel|Confirm|\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── [MANAGER] Main Manager Panel ─────────────────────────────────────────────
-- Shows all exchange configs with Edit and Remove per row.
local function exchange_showMainMenu(player)
    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wExchange Manager``|left|12592|")
    table.insert(d, "add_smalltext|`oManage all item exchange configurations. Changes take effect immediately.``|left|")
    table.insert(d, "add_spacer|small|")

    if #exchangeConfigs == 0 then
        table.insert(d, "add_textbox|`oNo exchange configurations yet. Add your first one below!``|left|")
        table.insert(d, "add_spacer|small|")
    else
        table.insert(d, "add_smalltext|`oActive exchanges (`$" .. #exchangeConfigs .. "`o):``|left|")
        table.insert(d, "add_spacer|small|")

        for i, cfg in ipairs(exchangeConfigs) do
            local reqName  = exchange_getItemName(cfg.itemID)
            local giveName = exchange_getItemName(cfg.itemToGiveID)

            -- Row header
            table.insert(d, "add_smalltext|`o#" .. i
                .. "  `w" .. formatNum(cfg.amountRequired) .. "x " .. reqName
                .. "  `o→  `$" .. formatNum(cfg.amount) .. "x " .. giveName .. "``|left|")

            -- Icon pair preview (display only, disabled)
            table.insert(d, string.format(
                "add_button_with_icon|mgr_view_req_%d||staticGreyFrame,no_padding_x,disabled|%d||",
                i, cfg.itemID))
            table.insert(d, "add_button_with_icon|mgr_arrow_" .. i .. "||noflags,disabled|11162||")
            table.insert(d, string.format(
                "add_button_with_icon|mgr_view_give_%d||staticYellowFrame,no_padding_x,disabled|%d||",
                i, cfg.itemToGiveID))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")

            -- Action buttons for this row
            table.insert(d, "add_button|mgr_edit_" .. i .. "|`wEdit``|no_flags|0|0|")
            table.insert(d, "add_button|mgr_remove_" .. i .. "|`4Remove``|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    -- Footer actions
    table.insert(d, "add_button|exchange_add_new|`2+ Add New Exchange``|no_flags|0|0|")
    table.insert(d, "add_button|exchange_reload|`oReload from Database``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|exchange_main_menu|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── [MANAGER] Editor Dialog ──────────────────────────────────────────────────
-- Add new or edit existing exchange config.
local function exchange_showEditor(player)
    local session = exchange_getSession(player)
    local cfg     = session.currentConfig or {}
    local isEdit  = session.editingIndex ~= nil

    local reqName  = cfg.itemID       and exchange_getItemName(cfg.itemID)       or nil
    local giveName = cfg.itemToGiveID and exchange_getItemName(cfg.itemToGiveID) or nil

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    if isEdit then
        table.insert(d, "add_label_with_icon|big|`wEdit Exchange``|left|12592|")
    else
        table.insert(d, "add_label_with_icon|big|`wNew Exchange``|left|12592|")
    end
    table.insert(d, "add_spacer|small|")

    -- ── Give Item (what player pays) ─────────────────────────────────────────
    table.insert(d, "add_textbox|`oStep 1 — Item to Give (player pays):``|left|")
    if cfg.itemID and reqName then
        -- Show selected item icon
        table.insert(d, string.format(
            "add_button_with_icon|ed_req_prev||staticGreyFrame,no_padding_x,disabled|%d||",
            cfg.itemID))
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
        table.insert(d, "add_smalltext|`2Selected: `w" .. reqName .. "`` (ID: " .. cfg.itemID .. ")``|left|")
    else
        table.insert(d, "add_smalltext|`4No item selected yet.``|left|")
    end
    table.insert(d, "add_item_picker|exchange_req_item|Pick Required Item|Click to pick from inventory|")
    table.insert(d, string.format(
        "add_text_input|exchange_req_amount|Amount Required:|%d|5|",
        cfg.amountRequired or 1))
    table.insert(d, "add_spacer|small|")

    -- ── Receive Item (what player gets) ──────────────────────────────────────
    table.insert(d, "add_textbox|`oStep 2 — Item to Receive (player gets):``|left|")
    if cfg.itemToGiveID and giveName then
        table.insert(d, string.format(
            "add_button_with_icon|ed_give_prev||staticYellowFrame,no_padding_x,disabled|%d||",
            cfg.itemToGiveID))
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
        table.insert(d, "add_smalltext|`2Selected: `w" .. giveName .. "`` (ID: " .. cfg.itemToGiveID .. ")``|left|")
    else
        table.insert(d, "add_smalltext|`4No item selected yet.``|left|")
    end
    table.insert(d, "add_item_picker|exchange_give_item|Pick Reward Item|Click to pick from inventory|")
    table.insert(d, string.format(
        "add_text_input|exchange_give_amount|Amount to Give:|%d|5|",
        cfg.amount or 1))
    table.insert(d, "add_spacer|small|")

    -- ── Preview ───────────────────────────────────────────────────────────────
    if cfg.itemID and cfg.itemToGiveID then
        table.insert(d, "add_smalltext|`oPreview:``|left|")
        table.insert(d, string.format(
            "add_button_with_icon|ed_pv_req||staticGreyFrame,no_padding_x,disabled|%d||",
            cfg.itemID))
        table.insert(d, "add_button_with_icon|ed_pv_arr||noflags,disabled|11162||")
        table.insert(d, string.format(
            "add_button_with_icon|ed_pv_give||staticYellowFrame,no_padding_x,disabled|%d||",
            cfg.itemToGiveID))
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
        table.insert(d, "add_spacer|small|")

        -- Save / Update button only when both items selected
        if isEdit then
            table.insert(d, "add_button|exchange_update|`2Update Exchange``|no_flags|0|0|")
        else
            table.insert(d, "add_button|exchange_save|`2Save Exchange``|no_flags|0|0|")
        end
    else
        table.insert(d, "add_smalltext|`oSelect both items to enable the save button.``|left|")
        table.insert(d, "add_spacer|small|")
    end

    table.insert(d, "add_button|exchange_back|`oBack to Manager``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|exchange_editor|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── [MANAGER] Remove Confirm Dialog ─────────────────────────────────────────
local function exchange_showRemoveConfirm(player, index)
    local session = exchange_getSession(player)
    session.pendingRemove = index

    local cfg = exchangeConfigs[index]
    if not cfg then return end

    local reqName  = exchange_getItemName(cfg.itemID)
    local giveName = exchange_getItemName(cfg.itemToGiveID)

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`4Remove Exchange?``|left|1430|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`oYou are about to permanently remove this exchange configuration:``|left|")
    table.insert(d, "add_spacer|small|")

    -- Visual of what will be removed
    table.insert(d, string.format(
        "add_button_with_icon|rm_req||staticGreyFrame,no_padding_x,disabled|%d||",
        cfg.itemID))
    table.insert(d, "add_button_with_icon|rm_arr||noflags,disabled|11162||")
    table.insert(d, string.format(
        "add_button_with_icon|rm_give||staticYellowFrame,no_padding_x,disabled|%d||",
        cfg.itemToGiveID))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`w" .. formatNum(cfg.amountRequired) .. "x " .. reqName
        .. "  `o→  `$" .. formatNum(cfg.amount) .. "x " .. giveName .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`4This action cannot be undone!``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_button|exchange_confirm_remove|`4Yes, Remove It``|no_flags|0|0|")
    table.insert(d, "add_button|exchange_cancel_remove|`wNo, Keep It``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|exchange_remove_confirm|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Editor Item Picker Handler (unchanged logic) ─────────────────────────────
local function exchange_handleEditorItemPicker(player, data)
    local session = exchange_getSession(player)
    session.currentConfig = session.currentConfig or {}

    if data.exchange_req_item and tonumber(data.exchange_req_item) and tonumber(data.exchange_req_item) > 0 then
        local itemID = tonumber(data.exchange_req_item)
        session.currentConfig.itemID = itemID
        player:onConsoleMessage("`2Required item set: `w" .. exchange_getItemName(itemID) .. "``")
    end

    if data.exchange_give_item and tonumber(data.exchange_give_item) and tonumber(data.exchange_give_item) > 0 then
        local itemID = tonumber(data.exchange_give_item)
        session.currentConfig.itemToGiveID = itemID
        player:onConsoleMessage("`2Reward item set: `w" .. exchange_getItemName(itemID) .. "``")
    end

    timer.setTimeout(0.1, function()
        exchange_showEditor(player)
    end)
end

-- ─── Command Registration ─────────────────────────────────────────────────────
registerLuaCommand({
    command      = "exchange",
    roleRequired = 0,
    description  = "Open the Item Exchange Center and browse available trades."
})
registerLuaCommand({
    command      = "manageexchange",
    roleRequired = 51,
    description  = "Developer: Manage item exchange configurations."
})

-- ─── Command Handlers ─────────────────────────────────────────────────────────
onPlayerCommandCallback(function(world, player, fullCommand)
    local command = fullCommand:match("^(%S+)")
    if not command then return false end

    if command:lower() == "exchange" then
        if #exchangeConfigs == 0 then
            player:onConsoleMessage("`4No exchange configurations available right now.``")
            return true
        end
        exchange_showPlayerDialog(player, 1)
        player:playAudio("spell1.wav")
        return true
    end

    if command:lower() == "manageexchange" then
        if not hasManageAccess(player) then
            player:onConsoleMessage("`4Access Denied: `oThis command requires Developer or Master role.``")
            return true
        end
        exchange_showMainMenu(player)
        return true
    end

    return false
end)

-- ─── Dialog Callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dialogName    = data["dialog_name"]    or ""
    local buttonClicked = data["buttonClicked"]  or ""

    -- ══ PLAYER: Main Exchange List ════════════════════════════════════════════
    if dialogName == "exchange_player_dialog" then
        -- Pagination (embed_data → strip trailing byte)
        local page = tonumber(edata(data["ex_page"], "1")) or 1

        if buttonClicked == "ex_prev" then
            exchange_showPlayerDialog(player, page - 1)
            return true
        elseif buttonClicked == "ex_next" then
            exchange_showPlayerDialog(player, page + 1)
            return true
        end

        -- Tap yellow reward button to open quantity dialog
        local idx = buttonClicked:match("^ex_give_(%d+)$")
        if idx then
            idx = tonumber(idx)
            if idx and exchangeConfigs[idx] then
                exchange_showQuantityDialog(player, idx)
            end
            return true
        end

        return true
    end

    -- ══ PLAYER: Quantity Confirm ══════════════════════════════════════════════
    local qIdx = tonumber(dialogName:match("^exchange_confirm_qty_(%d+)$"))
    if qIdx and exchangeConfigs[qIdx] then
        local exchange = exchangeConfigs[qIdx]

        local qtyInput = data["exchange_qty_input"] or "1"
        if not qtyInput:match("^%d+$") then
            player:onConsoleMessage("`4Error: `oPlease enter a valid number.``")
            player:playAudio("bleep_fail.wav")
            exchange_showQuantityDialog(player, qIdx)
            return true
        end

        local qty = math.max(1, math.min(MAX_ITEM_STACK, tonumber(qtyInput) or 1))
        local totalCost   = exchange.amountRequired * qty
        local totalReward = exchange.amount * qty

        local playerHas    = player:getItemAmount(exchange.itemID)
        local rewardAmount = player:getItemAmount(exchange.itemToGiveID)

        if playerHas < totalCost then
            player:onConsoleMessage("`4Error: `oNot enough items! Need `w"
                .. formatNum(totalCost) .. "x`` `$" .. exchange_getItemName(exchange.itemID)
                .. "``, you have `w" .. formatNum(playerHas) .. "x``.``")
            player:onTalkBubble(player:getNetID(), "`4Not enough items!", 0)
            player:playAudio("bleep_fail.wav")
            exchange_showQuantityDialog(player, qIdx)
            return true
        end

        if rewardAmount + totalReward > MAX_ITEM_STACK then
            player:onConsoleMessage("`4Error: `oNot enough inventory space for `w"
                .. formatNum(totalReward) .. "x`` `$" .. exchange_getItemName(exchange.itemToGiveID) .. "``.``")
            player:playAudio("bleep_fail.wav")
            exchange_showQuantityDialog(player, qIdx)
            return true
        end

        -- Execute exchange
        player:changeItem(exchange.itemID, -totalCost, 0)
        if not player:changeItem(exchange.itemToGiveID, totalReward, 0) then
            player:changeItem(exchange.itemToGiveID, totalReward, 1)
        end

        player:onConsoleMessage("`6>> Exchange: `2Gave `$" .. formatNum(totalCost) .. "x``"
            .. " `w" .. exchange_getItemName(exchange.itemID)
            .. "``  →  Received `$" .. formatNum(totalReward) .. "x``"
            .. " `w" .. exchange_getItemName(exchange.itemToGiveID) .. "``.``")
        player:onTalkBubble(player:getNetID(), "`2Exchange Complete!", 0)
        player:onAddNotification("", "`2Exchange Successful!``", "", 0, 1500)
        player:playAudio("piano_nice.wav")
        player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)

        exchange_logTransaction(player, exchange, qty, totalCost, totalReward)

        -- Return to exchange list at same page
        exchange_showPlayerDialog(player, 1)
        return true
    end

    -- ══ MANAGER: Editor ═══════════════════════════════════════════════════════
    if dialogName == "exchange_editor" then
        -- Item picker triggers
        if data.exchange_req_item or data.exchange_give_item then
            if hasManageAccess(player) then
                exchange_handleEditorItemPicker(player, data)
            end
            return true
        end

        if not hasManageAccess(player) then return true end

        local session = exchange_getSession(player)

        if buttonClicked == "exchange_back" then
            exchange_showMainMenu(player)
            return true
        end

        if buttonClicked == "exchange_save" or buttonClicked == "exchange_update" then
            local reqAmount  = math.max(1, tonumber(data.exchange_req_amount)  or 1)
            local giveAmount = math.max(1, tonumber(data.exchange_give_amount) or 1)

            if not session.currentConfig.itemID then
                player:onConsoleMessage("`4Error: `oPlease select the item to give (Step 1).``")
                exchange_showEditor(player)
                return true
            end
            if not session.currentConfig.itemToGiveID then
                player:onConsoleMessage("`4Error: `oPlease select the item to receive (Step 2).``")
                exchange_showEditor(player)
                return true
            end

            session.currentConfig.amountRequired = reqAmount
            session.currentConfig.amount         = giveAmount

            if session.editingIndex then
                local oldConfig = exchangeConfigs[session.editingIndex]
                exchange_updateConfig(session.editingIndex, session.currentConfig, player)
                player:onConsoleMessage("`2Exchange configuration updated!``")
                exchange_logManageAction(player, "Updated", session.currentConfig, oldConfig)
            else
                exchange_addConfig(session.currentConfig, player)
                player:onConsoleMessage("`2New exchange configuration added!``")
                exchange_logManageAction(player, "Added", session.currentConfig, nil)
            end

            exchange_showMainMenu(player)
            return true
        end

        return true
    end

    -- ══ MANAGER: Main Menu ════════════════════════════════════════════════════
    if dialogName == "exchange_main_menu" then
        if not hasManageAccess(player) then return true end

        if buttonClicked == "exchange_add_new" then
            local session = exchange_getSession(player)
            session.currentConfig = {}
            session.editingIndex  = nil
            exchange_showEditor(player)
            return true
        end

        if buttonClicked == "exchange_reload" then
            exchange_loadConfigs()
            player:onConsoleMessage("`2Exchange configurations reloaded from database!``")
            exchange_showMainMenu(player)
            return true
        end

        -- Edit button: mgr_edit_<index>
        local editIdx = tonumber(buttonClicked:match("^mgr_edit_(%d+)$"))
        if editIdx and exchangeConfigs[editIdx] then
            local session = exchange_getSession(player)
            session.currentConfig = {}
            for k, v in pairs(exchangeConfigs[editIdx]) do
                session.currentConfig[k] = v
            end
            session.editingIndex = editIdx
            exchange_showEditor(player)
            return true
        end

        -- Remove button: mgr_remove_<index>
        local removeIdx = tonumber(buttonClicked:match("^mgr_remove_(%d+)$"))
        if removeIdx and exchangeConfigs[removeIdx] then
            exchange_showRemoveConfirm(player, removeIdx)
            return true
        end

        return true
    end

    -- ══ MANAGER: Remove Confirm ═══════════════════════════════════════════════
    if dialogName == "exchange_remove_confirm" then
        if not hasManageAccess(player) then return true end

        local session = exchange_getSession(player)

        if buttonClicked == "exchange_confirm_remove" and session.pendingRemove then
            local oldConfig = exchangeConfigs[session.pendingRemove]
            if oldConfig then
                exchange_removeConfig(session.pendingRemove)
                player:onConsoleMessage("`2Exchange configuration removed!``")
                exchange_logManageAction(player, "Removed", oldConfig, nil)
                session.pendingRemove = nil
            end
        elseif buttonClicked == "exchange_cancel_remove" then
            session.pendingRemove = nil
        end

        exchange_showMainMenu(player)
        return true
    end

    return false
end)

-- ─── Cleanup sessions on disconnect ──────────────────────────────────────────
onPlayerDisconnectCallback(function(player)
    local netID = tostring(player:getNetID())
    if exchangeSessions[netID] then exchangeSessions[netID] = nil end
end)

-- ─── Initialization ───────────────────────────────────────────────────────────
exchange_loadConfigs()
print("(Item Exchange) Loaded with " .. #exchangeConfigs .. " configurations from SQLite")
print("(Item Exchange) Discord logging: "
    .. (Config.ANNOUNCEMENT_CHANNEL_ID ~= "" and "ENABLED" or "DISABLED"))