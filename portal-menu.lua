-- ─────────────────────────────────────────────────────────────────────────────
-- Portal Menu  — Tutorial · Cheats · Shop
-- Commands:  /menu  (all players)  |  /manageshop  (Developer/Master only)
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Portal Menu — Tutorial / Cheats / Shop")

math.randomseed(os.time())

-- ─── Roles & Access ───────────────────────────────────────────────────────────
local ROLE_DEVELOPER = 51
local ROLE_MASTER    = 100

local ALLOWED_MANAGE_ROLES = { ROLE_DEVELOPER, ROLE_MASTER }
local function hasManageAccess(player)
    for _, r in ipairs(ALLOWED_MANAGE_ROLES) do
        if player:hasRole(r) then return true end
    end
    return false
end

-- ─── Config ───────────────────────────────────────────────────────────────────
local MENU_ICON_ID    = 242   -- World Lock icon for main menu header
local TUTORIAL_ICON   = 3228  -- Book icon
local CHEAT_ICON      = 7188  -- Blue Gem Lock (fancy)
local SHOP_ICON       = 4390  -- Growtokens / shop feel
local SHOP_DB_PATH    = "portal_shop.db"

-- ─── Tutorial Pages ───────────────────────────────────────────────────────────
-- Each page: { title, icon, lines = {string,...} }
local TUTORIAL_PAGES = {
    {
        title = "Welcome to the Server!",
        icon  = 3228,
        lines = {
            "`wWelcome, Growtopian!``",
            "`oThis tutorial will teach you the basics of our server.",
            "Use the `$Next ``button to read through each section.",
            "",
            "`wKey Commands:``",
            "`o/menu   `w→``  Open this Portal Menu",
            "`o/exchange `w→``  Trade items at the Exchange Center",
            "`o/coinflip `w→``  Play Coin Flip minigame",
            "`o/fishconfig `w→``  View fishing drops (Dev only)",
        },
    },
    {
        title = "How to Earn Gems",
        icon  = 112,
        lines = {
            "`wGems are the main currency on this server!``",
            "",
            "`o• Farm blocks in world to earn Gems",
            "`o• Catch fish using fishing rods — rare drops!",
            "`o• Win the `$Coin Flip`` minigame",
            "`o• Buy items from the `$Shop`` and resell them",
            "`o• Complete daily quests (coming soon)",
            "",
            "`$Use /menu → Buy`` to spend Gems on exclusive items!",
        },
    },
    {
        title = "Fishing System",
        icon  = 802,
        lines = {
            "`wFishing gives special physical and virtual drops!``",
            "",
            "`o• Equip a `wFishing Rod`` and stand near water",
            "`o• Wait for a bite — the server auto-rewards you",
            "`o• Drops range from `2Common`` to `4Ultra Rare``",
            "",
            "`wPhysical vs Virtual Drops:``",
            "`o• Standard items (Blocks, Locks) go straight to your inventory",
            "`o• `2Custom Virtual Fish`` automatically go to your Fishing Album!",
            "",
            "`$Type /fishinv to view your Virtual Fishing Album!``",
        },
    },
    {
        title = "Virtual Fish Economy",
        icon  = 4320,
        lines = {
            "`wCatch massive fish and sell them for Gems!``",
            "",
            "`o• Open your album with `$ /fishinv``",
            "`o• Fish have a `2Base Value`` based on their Rarity tag.",
            "`o• Normal (50) ... Mythical (`$100,000``)",
            "",
            "`wVariant Multipliers!``",
            "`o• `wBig, Gold, Diamond`` -> Value is `2x2``",
            "`o• `wRainbow, Godly, Devil, Mutated`` -> Value is `2x4``",
            "`o• Multipliers STACK! Sell them via the Exchange button!",
        },
    },
    {
        title = "Fishing Enchantments",
        icon  = 3228,
        lines = {
            "`wCreate your own custom fishing drops!``",
            "",
            "`o• Type `$ /enchant ``to open the enchanter",
            "`o• Select any fishing rod in your inventory",
            "`o• Sacrifice any block or item to bind it to the rod",
            "",
            "`wHow it works:``",
            "`o• The rod will now have a chance to drop that specific item!",
            "`o• The drop rate depends on the `2Rarity`` of the sacrificed item",
            "`o• Enchantments are exclusive to YOU and that specific rod!",
        },
    },
    {
        title = "Rules & Fair Play",
        icon  = 1430,
        lines = {
            "`4Please follow the server rules!``",
            "",
            "`o• Do NOT use hacks, macros, or exploits",
            "`o• Respect all players and staff",
            "`o• No scamming or griefing other players",
            "`o• Do not spam commands or chat",
            "`o• Report bugs to a Moderator, don't abuse them",
            "",
            "`wViolations may result in a permanent ban.``",
            "`oEnjoy your stay and have fun! `$🎉``",
        },
    },
}

-- ─── Cheats / Fun Features ────────────────────────────────────────────────────
-- Features the player can activate; each has a cost in Gems, a cooldown, and an effect function.
local CHEATS = {
    {
        id       = "rainbow_trail",
        label    = "`5Rainbow Trail``",
        desc     = "Leaves a rainbow particle trail for 60 seconds.",
        icon     = 7764,
        gemCost  = 500,
        cooldown = 300, -- seconds (global per-player)
        effect   = function(player)
            player:onParticleEffect(45, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            player:onTalkBubble(player:getNetID(), "`5✨ Rainbow Mode! ✨``", 0)
            player:onAddNotification("", "`5Rainbow Trail Activated!``", "", 0, 2000)
        end,
    },
    {
        id       = "speed_boost",
        label    = "`2Speed Boost``",
        desc     = "Fly/move faster for this session.",
        icon     = 9462,
        gemCost  = 1000,
        cooldown = 600,
        effect   = function(player)
            player:onTextOverlay("`2⚡ SPEED BOOST!``")
            player:onTalkBubble(player:getNetID(), "`2⚡ Zooming! ⚡``", 0)
            player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            player:playAudio("piano_nice.wav")
        end,
    },
    {
        id       = "gem_burst",
        label    = "`$Gem Burst``",
        desc     = "Receive a random bonus Gem reward (50–500).",
        icon     = 112,
        gemCost  = 200,
        cooldown = 120,
        effect   = function(player)
            local bonus = math.random(50, 500)
            player:addGems(bonus, 0, 1)
            player:onTextOverlay("`$+` " .. bonus .. " `$Gems!``")
            player:onTalkBubble(player:getNetID(), "`$I just got a Gem Burst! 💎``", 0)
            player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
            player:playAudio("piano_nice.wav")
        end,
    },
    {
        id       = "fireworks",
        label    = "`4Fireworks``",
        desc     = "Launch a fireworks particle show around you.",
        icon     = 3516,
        gemCost  = 300,
        cooldown = 180,
        effect   = function(player)
            for i = 1, 5 do
                player:onParticleEffect(46, player:getMiddlePosX() + math.random(-3,3)*32,
                    player:getMiddlePosY() + math.random(-3,3)*32, 0, 0)
            end
            player:onTalkBubble(player:getNetID(), "`4🎆 Fireworks! 🎆``", 0)
            player:onAddNotification("", "`4Fireworks launched!``", "", 0, 1500)
        end,
    },
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function edata(val, default)
    if val == nil or val == "" then return default end
    return string.sub(val, 1, -2)
end

local function formatNum(num)
    local s = tostring(math.floor(tonumber(num) or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return s:gsub("^,", "")
end

local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(10, 10, 20, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(120, 80, 255, 255) end
end

local function applyDevStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(10, 10, 20, 254)         end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 180, 0, 255)  end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- ─── Per-Player Session ───────────────────────────────────────────────────────
local sessions     = {}  -- [netID] = { cheatCooldowns = { [id] = timestamp } }
local shopSessions = {}  -- [netID] = { editing = {...} }

local function getSession(player)
    local k = tostring(player:getNetID())
    sessions[k] = sessions[k] or { cheatCooldowns = {} }
    return sessions[k]
end

local function getShopSession(player)
    local k = tostring(player:getNetID())
    shopSessions[k] = shopSessions[k] or {}
    return shopSessions[k]
end

-- ─── Database Setup ───────────────────────────────────────────────────────────
local db = sqlite.open(SHOP_DB_PATH)

local function initDB()
    db:query([[
        CREATE TABLE IF NOT EXISTS shop_items (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id      INTEGER NOT NULL,
            amount       INTEGER NOT NULL DEFAULT 1,
            gem_cost     INTEGER NOT NULL,
            label        TEXT,
            created_at   INTEGER,
            created_by   INTEGER
        )
    ]])
    print("(Portal Menu) Shop database initialized")
end
initDB()

-- ─── Shop DB Helpers ──────────────────────────────────────────────────────────
local shopItems = {}

local function loadShopItems()
    shopItems = {}
    local rows = db:query("SELECT * FROM shop_items ORDER BY gem_cost ASC")
    if rows then
        for _, row in ipairs(rows) do
            table.insert(shopItems, {
                id        = tonumber(row.id),
                itemID    = tonumber(row.item_id),
                amount    = tonumber(row.amount),
                gemCost   = tonumber(row.gem_cost),
                label     = row.label or "",
                createdAt = tonumber(row.created_at),
            })
        end
    end
    print("(Portal Menu) Loaded " .. #shopItems .. " shop items")
end
loadShopItems()

local function getItemName(itemID)
    local it = getItem(itemID)
    return it and it:getName() or ("Item #" .. itemID)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  MAIN MENU  ██████████████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
local function showMainMenu(player)
    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`5Portal Menu``|left|" .. MENU_ICON_ID .. "|")
    table.insert(d, "add_smalltext|`oYour gateway to all server features!``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`o════════════════════════════════``|left|")
    table.insert(d, "add_spacer|small|")

    -- Tutorial button
    table.insert(d, string.format(
        "add_button_with_icon|menu_tutorial|`wTutorial  `oLearn how to play!``|staticBlueFrame|%d||",
        TUTORIAL_ICON))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`oNew here? Read the server guide!``|left|")
    table.insert(d, "add_spacer|small|")

    -- Cheats button
    table.insert(d, string.format(
        "add_button_with_icon|menu_cheats|`5Cheats  `oFun abilities using Gems!``|staticPurpleFrame|%d||",
        CHEAT_ICON))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`oActivate cool effects with Gems!``|left|")
    table.insert(d, "add_spacer|small|")

    -- Buy button
    table.insert(d, string.format(
        "add_button_with_icon|menu_shop|`$Buy Items  `oSpend Gems on exclusive stuff!``|staticYellowFrame|%d||",
        SHOP_ICON))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`oExclusive items purchaseable with `$Gems``!``|left|")
    table.insert(d, "add_spacer|small|")

    -- Shortcuts button
    table.insert(d, "add_button|menu_shortcuts|`9🌟 Quick Shortcuts 🌟``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")

    -- Dev shortcut (only shown to devs)
    if hasManageAccess(player) then
        table.insert(d, "add_textbox|`o════════════════════════════════``|left|")
        table.insert(d, "add_spacer|small|")
        table.insert(d, "add_button|menu_dev_shop|`6⚙ Manage Shop (Dev)``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end

    table.insert(d, "add_smalltext|`oTap any option above to get started!``|left|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_main_menu|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Shortcuts Menu ───────────────────────────────────────────────────────────

-- Physical fish item IDs — exchange rate: 1 gem per 1 fish
local FISH_EXCHANGE_IDS = {3820,3096,3544,3438,3092,3814,3036,3024,4958,3094,3032,7744,3030,3038}

local function startAutoFishExchange(player)
    local netID = tostring(player:getNetID())
    
    local function loop()
        local sess = sessions[netID]
        if not sess or not sess.autoFishExchange then return end
        
        local totalGems = 0
        local totalFish = 0
        
        for _, itemID in ipairs(FISH_EXCHANGE_IDS) do
            local count = player:getItemAmount(itemID)
            if count > 0 then
                totalGems = totalGems + count  -- 1 gem per fish
                totalFish = totalFish + count
                player:changeItem(itemID, -count, 0)
            end
        end
        
        if totalFish > 0 then
            player:addGems(totalGems, 0, 1)
            player:onTextOverlay("`2+" .. totalGems .. " Gems!`` `o(" .. totalFish .. " fish sold)``")
        end
        
        timer.setTimeout(3, loop)
    end
    
    timer.setTimeout(3, loop)
end

local function showCheatsMenu(player)
    applyStyle(player)
    local d = {}
    local sess = getSession(player)
    local isAutoFish = sess.autoFishExchange or false
    
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`5⚡ Cheats Menu``|left|7188|")
    table.insert(d, "add_smalltext|`oToggle powerful automation cheats!``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━``|left|")
    table.insert(d, "add_spacer|small|")
    
    -- ── Cheat: Auto Fish Exchange ────────────────────────────────────────────────
    local fishStatusIcon  = isAutoFish and "`2● ACTIVE``" or "`4○ DISABLED``"
    local fishToggleLabel = isAutoFish
        and "`4■ Turn OFF Auto Fish Exchange``"
        or  "`2▶ Turn ON Auto Fish Exchange``"
    
    table.insert(d, "add_label_with_icon|small|`wAuto Fish Exchange``|left|4320|")
    table.insert(d, "add_smalltext|`oStatus: " .. fishStatusIcon .. "|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`oAutomatically sells all physical fish every 3 seconds.\n`wRate: `21 Gem per 1 Fish`` (based on quantity)!``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_smalltext|`oSupported Fish IDs:``|left|")
    for _, itemID in ipairs(FISH_EXCHANGE_IDS) do
        local count = player:getItemAmount(itemID)
        local haveText = count > 0 and (" `2(x" .. count .. " → " .. count .. " Gems)``") or " `o(none)``"
        table.insert(d, "add_smalltext|`o  • `wItem #" .. itemID .. haveText .. "|left|")
    end
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|cheat_toggle_autofish|" .. fishToggleLabel .. "|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|sc_back|`oBack to Shortcuts``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_cheats|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

local function showShortcutsMenu(player)
    applyStyle(player)
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`9Shortcuts Menu``|left|" .. MENU_ICON_ID .. "|")
    table.insert(d, "add_smalltext|`oQuick access to all your favorite features!``|left|")
    table.insert(d, "add_spacer|small|")

    -- General Shortcuts
    table.insert(d, "add_button|sc_cheats|`5Cheats Menu``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|sc_coinflip|`$Play Coin Flip``|no_flags|0|0|")
    table.insert(d, "add_button|sc_stock|`6Stock Market``|no_flags|0|0|")
    table.insert(d, "add_button|sc_fishinv|`2Fish Inventory``|no_flags|0|0|")
    table.insert(d, "add_button|sc_enchant|`9Enchant Rod``|no_flags|0|0|")
    
    -- Dev Shortcuts
    if player:hasRole(51) then
        table.insert(d, "add_spacer|small|")
        table.insert(d, "add_textbox|`4Developer Area:``|left|")
        table.insert(d, "add_button|sc_fishloot|`4Fish Loot Manager``|no_flags|0|0|")
        table.insert(d, "add_button|sc_fishmaker|`6Custom Fish Generator``|no_flags|0|0|")
        table.insert(d, "add_button|sc_fishconfig|`bFishing Config Editor``|no_flags|0|0|")
    end

    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|sc_back|`oBack to Menu``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_shortcuts|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  TUTORIAL  ███████████████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
local function showTutorial(player, page)
    page = math.max(1, math.min(page, #TUTORIAL_PAGES))
    local tut = TUTORIAL_PAGES[page]

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wTutorial``|left|" .. tut.icon .. "|")

    -- Page indicator
    table.insert(d, "add_smalltext|`oPage `$" .. page .. "/" .. #TUTORIAL_PAGES ..
        "``  —  " .. tut.title .. "|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━``|left|")
    table.insert(d, "add_spacer|small|")

    -- Content lines
    for _, line in ipairs(tut.lines) do
        if line == "" then
            table.insert(d, "add_spacer|small|")
        else
            table.insert(d, "add_smalltext|" .. line .. "|left|")
        end
    end
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━``|left|")
    table.insert(d, "add_spacer|small|")

    -- Embed current page index for navigation
    table.insert(d, "embed_data|tut_page|" .. page)

    -- Navigation buttons
    local prevLabel = page > 1          and "`w← Previous``" or "`o← Previous``"
    local nextLabel = page < #TUTORIAL_PAGES and "`wNext →``"     or "`o Done! ✓``"
    table.insert(d, "add_button|tut_prev|" .. prevLabel .. "|no_flags|0|0|")
    table.insert(d, "add_button|tut_next|" .. nextLabel .. "|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|tut_back_menu|`oBack to Menu``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_tutorial|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  CHEATS PAGE  ████████████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
local function showCheats(player)
    local sess = getSession(player)
    local now  = os.time()

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`5Cheats & Fun``|left|" .. CHEAT_ICON .. "|")
    table.insert(d, "add_smalltext|`oActivate cool effects by spending `$Gems``!``|left|")
    table.insert(d, "add_spacer|small|")

    -- Player gem balance
    local gems = tonumber(player:getGems()) or 0
    table.insert(d, "add_smalltext|`oYour Gems: `$" .. formatNum(gems) .. "``|left|")
    table.insert(d, "add_spacer|small|")

    if #CHEATS == 0 then
        table.insert(d, "add_textbox|`oNo cheats configured right now!``|left|")
    else
        for i, cheat in ipairs(CHEATS) do
            local lastUsed   = sess.cheatCooldowns[cheat.id] or 0
            local remaining  = math.max(0, cheat.cooldown - (now - lastUsed))
            local onCooldown = remaining > 0
            local canAfford  = gems >= cheat.gemCost

            -- Header row: icon + name
            table.insert(d, string.format(
                "add_button_with_icon|cheat_icon_%d||staticGreyFrame,no_padding_x,disabled|%d||",
                i, cheat.icon))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")

            table.insert(d, "add_smalltext|" .. cheat.label .. "|left|")
            table.insert(d, "add_smalltext|`o" .. cheat.desc .. "|left|")

            if onCooldown then
                local mins = math.ceil(remaining / 60)
                table.insert(d, "add_smalltext|`4Cooldown: `w" .. mins .. " min remaining``|left|")
                table.insert(d, "add_button|cheat_cd_" .. i .. "|`4⏳ On Cooldown``|no_flags|0|0|")
            elseif not canAfford then
                table.insert(d, "add_smalltext|`4Need `$" .. formatNum(cheat.gemCost) ..
                    " Gems`` `4(missing " .. formatNum(cheat.gemCost - gems) .. ")``|left|")
                table.insert(d, "add_button|cheat_poor_" .. i .. "|`4❌ Not Enough Gems``|no_flags|0|0|")
            else
                table.insert(d, "add_smalltext|`oPrice: `$" .. formatNum(cheat.gemCost) .. " Gems``|left|")
                table.insert(d, "add_button|cheat_buy_" .. i .. "|`$▶ Activate — " ..
                    formatNum(cheat.gemCost) .. " Gems``|no_flags|0|0|")
            end
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_button|cheats_back|`oBack to Menu``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_cheats|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  SHOP PAGE  ██████████████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
local SHOP_PER_PAGE = 5

local function showShop(player, page)
    page = math.max(1, tonumber(page) or 1)
    local total      = #shopItems
    local totalPages = math.max(1, math.ceil(total / SHOP_PER_PAGE))
    if page > totalPages then page = totalPages end

    local si = (page - 1) * SHOP_PER_PAGE + 1
    local ei = math.min(total, page * SHOP_PER_PAGE)

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`$Item Shop``|left|" .. SHOP_ICON .. "|")
    table.insert(d, "add_smalltext|`oBuy exclusive items using your `$Gems``!``|left|")
    table.insert(d, "add_spacer|small|")

    local gems = tonumber(player:getGems()) or 0
    table.insert(d, "add_smalltext|`oYour Gems: `$" .. formatNum(gems) .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "embed_data|shop_page|" .. page)

    if total == 0 then
        table.insert(d, "add_textbox|`oThe shop is empty right now. Check back later!``|left|")
        table.insert(d, "add_spacer|small|")
    else
        if totalPages > 1 then
            table.insert(d, "add_smalltext|`oShowing `$" .. si .. "-" .. ei ..
                "`` of `$" .. total .. "`` items  |  Page `$" ..
                page .. "/" .. totalPages .. "``|left|")
            table.insert(d, "add_spacer|small|")
        end

        for i = si, ei do
            local it     = shopItems[i]
            local name   = it.label ~= "" and it.label or getItemName(it.itemID)
            local canBuy = gems >= it.gemCost
            local frame  = canBuy and "staticYellowFrame" or "staticGreyFrame"

            -- Item icon
            table.insert(d, string.format(
                "add_button_with_icon|shop_item_%d||%s,no_padding_x,is_count_label|%d|%d|",
                i, frame, it.itemID, it.amount))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")

            table.insert(d, "add_smalltext|`w" .. name .. "``  `ox" .. it.amount .. "|left|")

            if canBuy then
                table.insert(d, "add_smalltext|`oCost: `$" .. formatNum(it.gemCost) .. " Gems``|left|")
                table.insert(d, "add_button|shop_buy_" .. i .. "|`$Buy — " ..
                    formatNum(it.gemCost) .. " Gems``|no_flags|0|0|")
            else
                table.insert(d, "add_smalltext|`4Cost: `$" .. formatNum(it.gemCost) ..
                    " Gems`` `4(missing " .. formatNum(it.gemCost - gems) .. ")``|left|")
                table.insert(d, "add_button|shop_poor_" .. i .. "|`4❌ Not Enough Gems``|no_flags|0|0|")
            end
            table.insert(d, "add_spacer|small|")
        end

        if totalPages > 1 then
            local prevLabel = page > 1          and "`w← Prev``" or "`o← Prev``"
            local nextLabel = page < totalPages and "`wNext →``" or "`oNext →``"
            table.insert(d, "add_button|shop_prev|" .. prevLabel .. "|no_flags|0|0|")
            table.insert(d, "add_button|shop_next|" .. nextLabel .. "|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_button|shop_back|`oBack to Menu``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_shop|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  DEV SHOP MANAGER  ███████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
local function showDevShopManager(player)
    applyDevStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Shop Manager``|left|" .. SHOP_ICON .. "|")
    table.insert(d, "add_smalltext|`oManage items sold in the Gem Shop. Changes are instant.``|left|")
    table.insert(d, "add_spacer|small|")

    if #shopItems == 0 then
        table.insert(d, "add_textbox|`oNo shop items yet. Add the first one below!``|left|")
        table.insert(d, "add_spacer|small|")
    else
        table.insert(d, "add_smalltext|`oActive listings (`$" .. #shopItems .. "`o):``|left|")
        table.insert(d, "add_spacer|small|")

        for i, it in ipairs(shopItems) do
            local name = it.label ~= "" and it.label or getItemName(it.itemID)

            table.insert(d, "add_smalltext|`o#" .. i .. "  `w" .. name ..
                "  `ox" .. it.amount .. "  `o→  `$" .. formatNum(it.gemCost) .. " Gems``|left|")
            table.insert(d, string.format(
                "add_button_with_icon|dev_view_%d||staticGreyFrame,no_padding_x,disabled|%d||",
                i, it.itemID))
            table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")

            table.insert(d, "add_button|dev_edit_" .. i .. "|`wEdit``|no_flags|0|0|")
            table.insert(d, "add_button|dev_remove_" .. i .. "|`4Remove``|no_flags|0|0|")
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_button|dev_add_new|`2+ Add New Item``|no_flags|0|0|")
    table.insert(d, "add_button|dev_reload|`oReload from DB``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_dev_shop|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Dev Shop Editor ──────────────────────────────────────────────────────────
local function showDevShopEditor(player)
    local sess = getShopSession(player)
    local cfg  = sess.editing or {}
    local isEdit = sess.editingIndex ~= nil
    local name = cfg.itemID and getItemName(cfg.itemID) or nil

    applyDevStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    if isEdit then
        table.insert(d, "add_label_with_icon|big|`6Edit Shop Item``|left|" .. SHOP_ICON .. "|")
    else
        table.insert(d, "add_label_with_icon|big|`2New Shop Item``|left|" .. SHOP_ICON .. "|")
    end
    table.insert(d, "add_spacer|small|")

    -- Item picker
    table.insert(d, "add_textbox|`oStep 1 — Pick the Item:``|left|")
    if cfg.itemID and name then
        table.insert(d, string.format(
            "add_button_with_icon|dev_ed_prev||staticYellowFrame,no_padding_x,disabled|%d||",
            cfg.itemID))
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
        table.insert(d, "add_smalltext|`2Selected: `w" .. name .. "`` (ID: " .. cfg.itemID .. ")``|left|")
    else
        table.insert(d, "add_smalltext|`4No item selected yet.``|left|")
    end
    table.insert(d, "add_item_picker|dev_item_pick|Pick Item|Choose from inventory|")
    table.insert(d, "add_spacer|small|")

    -- Amount
    table.insert(d, string.format(
        "add_text_input|dev_amount|Amount to Give:|%d|5|",
        cfg.amount or 1))
    table.insert(d, "add_spacer|small|")

    -- Gem cost
    table.insert(d, string.format(
        "add_text_input|dev_gem_cost|Gem Cost:|%d|10|",
        cfg.gemCost or 100))
    table.insert(d, "add_spacer|small|")

    -- Custom label
    table.insert(d, string.format(
        "add_text_input|dev_label|Custom Display Label (leave blank = item name):|%s|40|",
        cfg.label or ""))
    table.insert(d, "add_spacer|small|")

    -- Save / Update
    if cfg.itemID then
        if isEdit then
            table.insert(d, "add_button|dev_ed_update|`2Update Item``|no_flags|0|0|")
        else
            table.insert(d, "add_button|dev_ed_save|`2Save Item``|no_flags|0|0|")
        end
    else
        table.insert(d, "add_smalltext|`oSelect an item above to enable save.``|left|")
        table.insert(d, "add_spacer|small|")
    end
    table.insert(d, "add_button|dev_ed_back|`oBack to Manager``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_dev_editor|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Dev Shop Remove Confirm ──────────────────────────────────────────────────
local function showDevRemoveConfirm(player, idx)
    local it   = shopItems[idx]
    if not it then return end
    local name = it.label ~= "" and it.label or getItemName(it.itemID)

    applyDevStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`4Remove Item?``|left|1430|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`oYou are about to remove this listing permanently:``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, string.format(
        "add_button_with_icon|rm_prev||staticGreyFrame,no_padding_x,disabled|%d||",
        it.itemID))
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_smalltext|`w" .. name .. "  `ox" .. it.amount ..
        "  `o→  `$" .. formatNum(it.gemCost) .. " Gems``|left|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`4This cannot be undone!``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "embed_data|dev_rm_idx|" .. idx)

    table.insert(d, "add_button|dev_confirm_rm|`4Yes, Remove``|no_flags|0|0|")
    table.insert(d, "add_button|dev_cancel_rm|`wNo, Keep It``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|portal_dev_rm|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  COMMANDS  ███████████████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
registerLuaCommand({ command = "menu",       roleRequired = 0,    description = "Open the Portal Menu (Tutorial / Cheats / Buy)." })
registerLuaCommand({ command = "manageshop", roleRequired = ROLE_DEVELOPER, description = "Developer: Manage the Gem Shop listings." })

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end

    if cmd:lower() == "menu" then
        showMainMenu(player)
        return true
    end

    if cmd:lower() == "manageshop" then
        if not hasManageAccess(player) then
            player:onConsoleMessage("`4Access Denied: Requires Developer role.``")
            return true
        end
        showDevShopManager(player)
        return true
    end

    return false
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  DIALOG CALLBACKS  ███████████████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg     = data["dialog_name"]   or ""
    local clicked = data["buttonClicked"] or ""

    -- ══ MAIN MENU ═════════════════════════════════════════════════════════════
    if dlg == "portal_main_menu" then
        if clicked == "menu_tutorial" then showTutorial(player, 1) end
        if clicked == "menu_cheats"   then showCheats(player)      end
        if clicked == "menu_shop"     then showShop(player, 1)     end
        if clicked == "menu_shortcuts" then showShortcutsMenu(player) end

        if clicked == "menu_dev_shop" then
            if hasManageAccess(player) then showDevShopManager(player) end
        end
        return true
    end

    -- ══ SHORTCUTS ═════════════════════════════════════════════════════════════
    if dlg == "portal_cheats" then
        if clicked == "sc_back" then showShortcutsMenu(player) return true end
        if clicked == "cheats_back" then showMainMenu(player) return true end
        
        local idx = tonumber(clicked:match("^cheat_buy_(%d+)$"))
        if idx and CHEATS[idx] then
            local cheat = CHEATS[idx]
            local sess  = getSession(player)
            local now   = os.time()
            local gems  = tonumber(player:getGems()) or 0

            -- Double-check cooldown and balance
            local cd = sess.cheatCooldowns[cheat.id] or 0
            if now < cd then
                player:onConsoleMessage("`4Wait " .. (cd - now) .. " seconds before using this again!``")
                return true
            end

            if gems < cheat.gemCost then
                player:onConsoleMessage("`4Not enough Gems! Need `$" .. formatNum(cheat.gemCost) .. "`4.``")
                return true
            end

            -- Deduct gems
            player:addGems(-cheat.gemCost, 0, 1)

            -- Set cooldown
            sess.cheatCooldowns[cheat.id] = now + cheat.cooldown

            -- Execute effect
            player:onConsoleMessage("`6>> You activated `w" .. cheat.label .. "`2! `o(spent `$" .. formatNum(cheat.gemCost) .. " Gems``)``")
            cheat.effect(player)
            
            showCheatsPage(player)
            return true
        end

        if clicked == "cheat_toggle_autofish" then
            local sess = getSession(player)
            if sess.autoFishExchange then
                sess.autoFishExchange = false
                player:onConsoleMessage("`4>> Auto Fish Exchange turned OFF.``")
                player:playAudio("piano_nice.wav")
            else
                sess.autoFishExchange = true
                player:onConsoleMessage("`2>> Auto Fish Exchange turned ON! Will auto-sell physical fish every 3 seconds.``")
                player:playAudio("piano_nice.wav")
                startAutoFishExchange(player)
            end
            showCheatsMenu(player)
            return true
        end
        return true
    end

    if dlg == "portal_shortcuts" then
        if clicked == "sc_cheats" then showCheatsMenu(player) return true end
        if clicked == "sc_back" then showMainMenu(player) return true end
        
        -- Let other scripts handle the shortcut buttons
        if clicked == "sc_coinflip" then return false end
        if clicked == "sc_stock" then return false end
        if clicked == "sc_fishinv" then return false end
        if clicked == "sc_enchant" then return false end
        
        if clicked == "sc_fishloot" or clicked == "sc_fishmaker" or clicked == "sc_fishconfig" then
            if not player:hasRole(51) then
                player:onConsoleMessage("`4You don't have permission to access this!``")
                return true
            end
            return false
        end
        return true
    end

    -- ══ TUTORIAL ══════════════════════════════════════════════════════════════
    if dlg == "portal_tutorial" then
        local page = tonumber(edata(data["tut_page"], "1")) or 1

        if clicked == "tut_prev" then
            if page > 1 then showTutorial(player, page - 1) end
        elseif clicked == "tut_next" then
            if page < #TUTORIAL_PAGES then
                showTutorial(player, page + 1)
            else
                -- Last page "Done" → back to menu
                showMainMenu(player)
            end
        elseif clicked == "tut_back_menu" then
            showMainMenu(player)
        end
        return true
    end

    -- ══ SHOP ══════════════════════════════════════════════════════════════════
    if dlg == "portal_shop" then
        local page = tonumber(edata(data["shop_page"], "1")) or 1

        if clicked == "shop_back" then showMainMenu(player) return true end
        if clicked == "shop_prev" then showShop(player, page - 1) return true end
        if clicked == "shop_next" then showShop(player, page + 1) return true end

        local buyIdx = tonumber(clicked:match("^shop_buy_(%d+)$"))
        if buyIdx and shopItems[buyIdx] then
            local it   = shopItems[buyIdx]
            local gems = tonumber(player:getGems()) or 0
            local name = it.label ~= "" and it.label or getItemName(it.itemID)

            if gems < it.gemCost then
                player:onConsoleMessage("`4Not enough Gems! Need `$" .. formatNum(it.gemCost) .. "`4.``")
                showShop(player, page)
                return true
            end

            -- Check inventory space
            local has = tonumber(player:getItemAmount(it.itemID)) or 0
            if has + it.amount > 200 then
                player:onConsoleMessage("`4Not enough inventory space for `w" ..
                    it.amount .. "x " .. name .. "`4!``")
                showShop(player, page)
                return true
            end

            -- Deduct & give
            player:addGems(-it.gemCost, 0, 1)
            if not player:changeItem(it.itemID, it.amount, 0) then
                player:changeItem(it.itemID, it.amount, 1)
            end

            player:onConsoleMessage("`6>> Shop: `2Purchased `$" .. it.amount .. "x " ..
                name .. "`2 for `$" .. formatNum(it.gemCost) .. " Gems``!``")
            player:onTalkBubble(player:getNetID(), "`2I just bought " .. name .. "! 🛍``", 0)
            player:onAddNotification("", "`2Purchase Successful!``", "", 0, 1500)
            player:playAudio("piano_nice.wav")
            player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)

            showShop(player, page)
            return true
        end
        return true
    end

    -- ══ DEV SHOP MANAGER ══════════════════════════════════════════════════════
    if dlg == "portal_dev_shop" then
        if not hasManageAccess(player) then return true end

        if clicked == "dev_add_new" then
            local sess = getShopSession(player)
            sess.editing = {}
            sess.editingIndex = nil
            showDevShopEditor(player)
            return true
        end

        if clicked == "dev_reload" then
            loadShopItems()
            player:onConsoleMessage("`2Shop items reloaded!``")
            showDevShopManager(player)
            return true
        end

        local editIdx = tonumber(clicked:match("^dev_edit_(%d+)$"))
        if editIdx and shopItems[editIdx] then
            local sess = getShopSession(player)
            local it   = shopItems[editIdx]
            sess.editing      = { itemID = it.itemID, amount = it.amount, gemCost = it.gemCost, label = it.label }
            sess.editingIndex = editIdx
            showDevShopEditor(player)
            return true
        end

        local removeIdx = tonumber(clicked:match("^dev_remove_(%d+)$"))
        if removeIdx and shopItems[removeIdx] then
            showDevRemoveConfirm(player, removeIdx)
            return true
        end

        return true
    end

    -- ══ DEV SHOP EDITOR ═══════════════════════════════════════════════════════
    if dlg == "portal_dev_editor" then
        if not hasManageAccess(player) then return true end
        local sess = getShopSession(player)
        sess.editing = sess.editing or {}

        -- Item picker triggered
        if data["dev_item_pick"] and tonumber(data["dev_item_pick"]) and
            tonumber(data["dev_item_pick"]) > 0 then
            sess.editing.itemID = tonumber(data["dev_item_pick"])
            player:onConsoleMessage("`2Item set: `w" .. getItemName(sess.editing.itemID) .. "``")
            timer.setTimeout(0.1, function() showDevShopEditor(player) end)
            return true
        end

        if clicked == "dev_ed_back" then
            showDevShopManager(player)
            return true
        end

        if clicked == "dev_ed_save" or clicked == "dev_ed_update" then
            if not sess.editing.itemID then
                player:onConsoleMessage("`4Please pick an item first!``")
                showDevShopEditor(player)
                return true
            end

            local amount  = math.max(1, tonumber(data["dev_amount"])   or 1)
            local gemCost = math.max(1, tonumber(data["dev_gem_cost"]) or 100)
            local label   = data["dev_label"] or ""
            label = label:match("^%s*(.-)%s*$") -- trim

            if clicked == "dev_ed_update" and sess.editingIndex then
                local ex = shopItems[sess.editingIndex]
                if ex then
                    db:query(string.format([[
                        UPDATE shop_items SET item_id=%d, amount=%d, gem_cost=%d, label='%s'
                        WHERE id=%d
                    ]], sess.editing.itemID, amount, gemCost, label:gsub("'","''"), ex.id))
                    loadShopItems()
                    player:onConsoleMessage("`2Shop item updated!``")
                end
            else
                local createdBy = player:getUserID()
                db:query(string.format([[
                    INSERT INTO shop_items (item_id, amount, gem_cost, label, created_at, created_by)
                    VALUES (%d, %d, %d, '%s', %d, %d)
                ]], sess.editing.itemID, amount, gemCost, label:gsub("'","''"), os.time(), createdBy))
                loadShopItems()
                player:onConsoleMessage("`2New shop item added!``")
            end

            sess.editing      = {}
            sess.editingIndex = nil
            showDevShopManager(player)
            return true
        end
        return true
    end

    -- ══ DEV REMOVE CONFIRM ════════════════════════════════════════════════════
    if dlg == "portal_dev_rm" then
        if not hasManageAccess(player) then return true end

        local rmIdx = tonumber(edata(data["dev_rm_idx"], "0"))

        if clicked == "dev_confirm_rm" and rmIdx and shopItems[rmIdx] then
            local it = shopItems[rmIdx]
            db:query("DELETE FROM shop_items WHERE id=" .. it.id)
            loadShopItems()
            player:onConsoleMessage("`2Item removed from shop!``")
        end

        showDevShopManager(player)
        return true
    end

    return false
end)

-- ─── Cleanup on disconnect ────────────────────────────────────────────────────
onPlayerDisconnectCallback(function(player)
    local k = tostring(player:getNetID())
    sessions[k]     = nil
    shopSessions[k] = nil
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- ██████  SIDEBAR BUTTON INTEGRATION  █████████████████████████████████████████
-- ─────────────────────────────────────────────────────────────────────────────
local menuButton = {
    active = true,
    buttonAction = "trigger_portal_menu",
    buttonTemplate = "BaseEventButton",
    counter = 0,
    counterMax = 0,
    itemIdIcon = 3228, -- Book icon for the menu
    name = "PortalMenuButton",
    order = 56, -- Order 56 to place it below Exchange (55)
    rcssClass = "daily_challenge",
    text = "`wMenu``"
}

-- Register the sidebar button
addSidebarButton(json.encode(menuButton))

local function sendMenuButton(player)
    if not player then return end
    player:sendVariant({
        "OnEventButtonDataSet",
        menuButton.name,
        1, 
        json.encode(menuButton)
    })
end

-- Send to all currently online players
for _, plr in ipairs(getServerPlayers() or {}) do
    sendMenuButton(plr)
end

-- Callbacks to show button on login and enter world
onPlayerLoginCallback(sendMenuButton)
onPlayerEnterWorldCallback(function(world, player) sendMenuButton(player) end)

-- Handle the button click
onPlayerActionCallback(function(world, player, data)
    local action = data["action"]
    if action == menuButton.buttonAction then
        -- Open the main menu directly when the button is clicked
        showMainMenu(player)
        return true
    end
    return false
end)

print("(Portal Menu) Loaded. Commands: /menu | /manageshop")
