-- Developer Help Panel - /? command
print("(Loaded) Developer Help Panel script for GrowSoft")

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

-- ─── embed_data safe reader ───────────────────────────────────────────────────
-- Engine appends a trailing char to embed_data values (marvelous-missions.lua pattern)
local function edata(val, default)
    if val == nil or val == "" then return default end
    return string.sub(val, 1, -2)
end

-- ─── Command Registry ──────────────────────────────────────────────────────────
-- Categories and all commands in the server, organized by role access and purpose.
-- Icons use well-known Growtopia item IDs confirmed from across the codebase.

local CATEGORIES = {
    -- ══════════════════════════════════
    --  DEVELOPER (role 51)
    -- ══════════════════════════════════
    {
        key   = "dev",
        label = "Developer",
        color = "`6",
        icon  = 5814,
        commands = {
            -- Fish System
            { cmd = "/fishexch",         usage = "/fishexch",                   desc = "Edit virtual fish exchange payouts (e.g. WLs instead of Gems)." },
            { cmd = "/fishmaker",        usage = "/fishmaker",                  desc = "Open the Developer Custom Fish Generator UI to create custom fish." },
            { cmd = "/fishconfig",       usage = "/fishconfig",                 desc = "View and understand the server fishing drop table." },
            { cmd = "/editfishconfig",   usage = "/editfishconfig",             desc = "Edit the fishing.json wait_time per rod type." },
            { cmd = "/fishloot",         usage = "/fishloot",                   desc = "Manage Custom Fish Drop Tables dynamically (add or remove drops)." },
            { cmd = "/fishboost",        usage = "/fishboost",                  desc = "Toggle the server-wide Fish Boost event (doubles fish sell rewards)." },
            { cmd = "/fishwebhook",      usage = "/fishwebhook",                desc = "Configure the Discord Webhook URL for Fish Boost event notifications." },
            -- Economy and Shop
            { cmd = "/fullscan",         usage = "/fullscan",                   desc = "Scan the entire server economy (locks, gems, items)." },
            { cmd = "/manageexchange",   usage = "/manageexchange",             desc = "Manage item exchange configurations (add, edit, remove trade listings)." },
            { cmd = "/manageshop",       usage = "/manageshop",                 desc = "Manage the Gem Shop listings in the Portal Menu." },
            { cmd = "/setcap",           usage = "/setcap <itemID> <value>",    desc = "Modify the global machine capacity limit for a specific item ID." },
            { cmd = "/givegems",         usage = "/givegems <player> <amount>", desc = "Give gems to a specific player." },
            { cmd = "/setslots",         usage = "/setslots <player> <slots>",  desc = "Set a player\'s autofarm slot limit." },
            -- Expired Locks and Anti-Dupe
            { cmd = "/expiredlocks",     usage = "/expiredlocks",               desc = "Open the Expired Locks System UI (enable/disable, set thresholds)." },
            { cmd = "/lockaudit",        usage = "/lockaudit",                  desc = "Manually audit your own inventory lock balance against the server pool." },
            { cmd = "/locktrack",        usage = "/locktrack",                  desc = "Open the Lock Tracker and Anti-Dupe management UI." },
            -- Referral
            { cmd = "/editreferral",     usage = "/editreferral",               desc = "Edit Referral Program milestone rewards (items, gems, invite counts)." },
            -- Items and World
            { cmd = "/f",                usage = "/f [name]",                   desc = "Open the item search and spawn panel to find and give items in-game." },
            -- Chat Channels
            { cmd = "/devchat",          usage = "/devchat <message>",          desc = "Send a message in the private Developer Chat channel." },
            -- Scripts and Maintenance
            { cmd = "/ul",               usage = "/ul [config]",                desc = "Fetch and update all scripts from the configured GitHub repository." },
            { cmd = "/updatelua",        usage = "/updatelua [config]",         desc = "Alias for /ul. Fetch and update all scripts from GitHub." },
            { cmd = "/rs",               usage = "/rs",                         desc = "Reload all server scripts instantly." },
            { cmd = "/reloadscripts",    usage = "/reloadscripts",              desc = "Alias for /rs. Reload all server scripts." },
            { cmd = "/say",              usage = "/say <message>",              desc = "Broadcast a message to everyone visible in the world." },
            -- Moderation
            { cmd = "/clearmalpractice", usage = "/clearmalpractice [player]", desc = "Remove the Malpractice status from yourself or a target player." },
            { cmd = "/curemalpractice",  usage = "/curemalpractice [player]",  desc = "Alias for /clearmalpractice." },
            { cmd = "/rmmalpractice",    usage = "/rmmalpractice [player]",    desc = "Alias for /clearmalpractice." },
            -- Help Panel
            { cmd = "/?",                usage = "/?",                          desc = "Open this Developer Help Panel." },
            { cmd = "/h",                usage = "/h",                          desc = "Alias for /?. Open the Developer Help Panel." },
            { cmd = "/dh",               usage = "/dh",                        desc = "Alias for /?. Open the Developer Help Panel." },
        }
    },
    -- ══════════════════════════════════
    --  STAFF / VIP (role 1-3)
    -- ══════════════════════════════════
    {
        key   = "staff",
        label = "Staff / VIP",
        color = "`c",
        icon  = 482,
        commands = {
            { cmd = "/getdaily",     usage = "/getdaily",         desc = "Claim your daily reward (random item drop). Available once per day." },
            { cmd = "/farmer",       usage = "/farmer",           desc = "Spawn a Farmer NPC in the current world." },
            { cmd = "/demotemyself", usage = "/demotemyself",     desc = "Demote yourself from your current VIP or Staff role." },
            { cmd = "/vipchat",      usage = "/vipchat <message>",desc = "Send a message in the private VIP Chat channel." },
        }
    },
    -- ══════════════════════════════════
    --  ALL PLAYERS (role 0)
    -- ══════════════════════════════════
    {
        key   = "all",
        label = "All Players",
        color = "`2",
        icon  = 1366,
        commands = {
            { cmd = "/buy",      usage = "/buy [search]", desc = "Browse and purchase items and blocks from the server shop for gems." },
            { cmd = "/buyvip",   usage = "/buyvip",       desc = "Purchase the VIP role for 100 Diamond Locks." },
            { cmd = "/menu",     usage = "/menu",         desc = "Open the Portal Menu (Tutorial, Cheats, Buy)." },
            { cmd = "/online",   usage = "/online",       desc = "List all online players, their world, role, and current status." },
            { cmd = "/exchange", usage = "/exchange",     desc = "Open the Item Exchange Center and browse available item trades." },
            { cmd = "/coinflip", usage = "/coinflip",     desc = "Play the Coin Flip minigame. Bet WL/DL/BGL and try to double your balance." },
            { cmd = "/cf",       usage = "/cf",           desc = "Alias for /coinflip. Quick shortcut to the Coin Flip minigame." },
            { cmd = "/fishinv",  usage = "/fishinv",      desc = "Open your personal fishing album to view all your custom fish catches." },
            { cmd = "/sellfish", usage = "/sellfish",     desc = "Sell physical Growtopia fish from your inventory for World Locks." },
            { cmd = "/enchant",  usage = "/enchant",      desc = "Enchant your fishing rod with custom item drops and buffs." },
            { cmd = "/wallet",   usage = "/wallet",       desc = "Open your Virtual Wallet. Exchange gems for locks, transfer, or withdraw." },
            { cmd = "/referral", usage = "/referral",     desc = "Open the Referral Program. Share your invite code and earn milestone rewards." },
            { cmd = "/stock",    usage = "/stock",        desc = "Open the Stock Market menu to buy, sell, and trade stocks." },
            { cmd = "/market",   usage = "/market",       desc = "Alias for /stock. Open the Stock Market menu." },
            { cmd = "/news",     usage = "/news",         desc = "View the latest server news and announcements." },
        }
    }
}

-- ─── Style helpers ────────────────────────────────────────────────────────────
local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(10, 10, 20, 254)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 200, 0, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- ─── Help Dialog Builder ──────────────────────────────────────────────────────
local PAGE_SIZE = 6  -- commands visible per page per category

local function showHelp(player, activeCat, page)
    activeCat = activeCat or "dev"
    page      = math.max(1, tonumber(page) or 1)

    -- Find active category data
    local catData = nil
    for _, c in ipairs(CATEGORIES) do
        if c.key == activeCat then catData = c break end
    end
    if not catData then catData = CATEGORIES[1] end

    local cmds      = catData.commands
    local total     = #cmds
    local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
    if page > totalPages then page = totalPages end

    local si = (page - 1) * PAGE_SIZE + 1
    local ei = math.min(total, page * PAGE_SIZE)

    applyStyle(player)
    local d = {}

    -- ── Header
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wDeveloper Help Panel``|left|5814|")
    table.insert(d, "add_smalltext|`oAll registered server commands — tap a category to filter.``|left|")
    table.insert(d, "add_spacer|small|")

    -- ── State embeds
    table.insert(d, "embed_data|hcat|"  .. activeCat)
    table.insert(d, "embed_data|hpage|" .. page)

    -- ── Category tab buttons (one per line — proven no-overflow pattern)
    table.insert(d, "add_textbox|`oFilter by access level:``|left|")
    for _, cat in ipairs(CATEGORIES) do
        local isActive = (cat.key == activeCat)
        local label = isActive
            and ("`$[ " .. cat.color .. cat.label .. "`` ]``")
            or  ("`o"   .. cat.label .. "``")
        table.insert(d, "add_button|hcat_" .. cat.key .. "|" .. label .. "|no_flags|0|0|")
    end
    table.insert(d, "add_spacer|small|")

    -- ── Page / count info
    if totalPages > 1 then
        table.insert(d, "add_smalltext|`o"
            .. catData.color .. catData.label .. "`` commands  `o|  Page `$"
            .. page .. "`` of `$" .. totalPages .. "``|left|")
    else
        table.insert(d, "add_smalltext|`o"
            .. catData.color .. catData.label .. "`` commands  (`$"
            .. total .. "`` total)``|left|")
    end
    table.insert(d, "add_spacer|small|")

    -- ── Command list using clean textboxes ──
    for i = si, ei do
        local cmd = cmds[i]
        table.insert(d, "add_textbox|▪ " .. catData.color .. cmd.cmd .. "`` `w(" .. cmd.usage .. ")``|left|")
        table.insert(d, "add_textbox|   `o" .. cmd.desc .. "``|left|")
    end
    table.insert(d, "add_spacer|small|")

    -- ── Pagination
    if totalPages > 1 then
        local prevLabel = page > 1          and "`w<< Prev``" or "`o<< Prev``"
        local nextLabel = page < totalPages and "`wNext >>``" or "`oNext >>``"
        table.insert(d, "add_button|hprev|" .. prevLabel .. "|no_flags|0|0|")
        table.insert(d, "add_button|hnext|" .. nextLabel .. "|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|help_main|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Command Detail Dialog ────────────────────────────────────────────────────
local function showDetail(player, catKey, cmdIndex, prevPage)
    local catData = nil
    for _, c in ipairs(CATEGORIES) do
        if c.key == catKey then catData = c break end
    end
    if not catData then return end

    local cmd = catData.commands[cmdIndex]
    if not cmd then return end

    applyStyle(player)
    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|" .. catData.color .. cmd.cmd .. "``|left|" .. cmd.icon .. "|")
    table.insert(d, "add_spacer|small|")

    -- State for back button
    table.insert(d, "embed_data|dcat|"  .. catKey)
    table.insert(d, "embed_data|dpage|" .. prevPage)

    -- Icon preview
    table.insert(d, "add_button_with_icon|noop||staticBlueFrame,disabled|" .. cmd.icon .. "||")
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_spacer|small|")

    -- Details
    table.insert(d, "add_smalltext|`oCommand:``|left|")
    table.insert(d, "add_textbox|`$" .. cmd.cmd .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_smalltext|`oUsage:``|left|")
    table.insert(d, "add_textbox|`w" .. cmd.usage .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_smalltext|`oAccess:``|left|")
    table.insert(d, "add_textbox|" .. catData.color .. catData.label .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_smalltext|`oDescription:``|left|")
    table.insert(d, "add_textbox|`o" .. cmd.desc .. "``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_button|hback|`oBack to list``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|help_detail|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Register command ─────────────────────────────────────────────────────────
registerLuaCommand({
    command      = "?",
    roleRequired = Roles.ROLE_DEVELOPER,
    description  = "Developer Help Panel: shows all registered server commands."
})
registerLuaCommand({
    command      = "h",
    roleRequired = Roles.ROLE_DEVELOPER,
    description  = "Developer Help Panel: shows all registered server commands."
})
registerLuaCommand({
    command      = "dh",
    roleRequired = Roles.ROLE_DEVELOPER,
    description  = "Developer Help Panel: shows all registered server commands."
})

-- ─── Command handler ──────────────────────────────────────────────────────────
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    if cmd ~= "?" and cmd:lower() ~= "h" and cmd:lower() ~= "dh" then return false end

    if not player:hasRole(Roles.ROLE_DEVELOPER) then
        player:onConsoleMessage("`4Access Denied: `oThe /" .. cmd .. " command requires Developer role.``")
        return true
    end

    showHelp(player, "dev", 1)
    return true
end)

-- ─── Dialog callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg     = data["dialog_name"] or ""
    local clicked = data["buttonClicked"] or ""

    -- ── Main help panel ────────────────────────────────────────────────────────
    if dlg == "help_main" then
        if not player:hasRole(Roles.ROLE_DEVELOPER) then return true end

        -- Strip trailing engine byte from embed_data (marvelous-missions.lua pattern)
        local cat  = edata(data["hcat"],  "dev")
        local page = tonumber(edata(data["hpage"], "1")) or 1

        -- Category switch
        for _, catObj in ipairs(CATEGORIES) do
            if clicked == "hcat_" .. catObj.key then
                showHelp(player, catObj.key, 1)
                return true
            end
        end

        if clicked == "hprev" then
            showHelp(player, cat, page - 1)
            return true
        elseif clicked == "hnext" then
            showHelp(player, cat, page + 1)
            return true
        elseif clicked:sub(1, 5) == "hcmd_" then
            -- Find correct category's command by index
            local idx = tonumber(clicked:sub(6))
            if idx then
                showDetail(player, cat, idx, page)
            end
            return true
        end

        return true
    end

    -- ── Detail panel ──────────────────────────────────────────────────────────
    if dlg == "help_detail" then
        if not player:hasRole(Roles.ROLE_DEVELOPER) then return true end

        local cat  = edata(data["dcat"],  "dev")
        local page = tonumber(edata(data["dpage"], "1")) or 1

        if clicked == "hback" then
            showHelp(player, cat, page)
            return true
        end
        return true
    end

    return false
end)
