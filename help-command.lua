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
    {
        key   = "dev",
        label = "Developer",
        color = "`6",
        icon  = 5814,
        commands = {
            { cmd = "/setcap", usage = "/setcap", icon = 5814, desc = "Modify global machine capacity. Usage: /setcap <itemID> <value>" },
            { cmd = "/fishmaker", usage = "/fishmaker", icon = 5814, desc = "Open the Developer Custom Fish Generator UI" },
            { cmd = "/f", usage = "/f", icon = 5814, desc = "Developer: Open the item search and spawn panel. /f [name]" },
            { cmd = "/fishexch", usage = "/fishexch", icon = 5814, desc = "Edit virtual fish exchange payouts (e.g. WLs instead of Gems)!" },
            { cmd = "/fishboost", usage = "/fishboost", icon = 5814, desc = "Open UI to toggle the server-wide Fish Boost" },
            { cmd = "/fishwebhook", usage = "/fishwebhook", icon = 5814, desc = "Open UI to configure Fish Boost Discord Webhook" },
            { cmd = "/editfishconfig", usage = "/editfishconfig", icon = 5814, desc = "Edit the fishing.json wait_time for rods!" },
            { cmd = "/fishconfig", usage = "/fishconfig", icon = 5814, desc = "View and understand the server fishing drop table." },
            { cmd = "/fishloot", usage = "/fishloot", icon = 5814, desc = "Developer: Manage Custom Fish Drop Tables dynamically!" },
            { cmd = "/fullscan", usage = "/fullscan", icon = 5814, desc = "Scans economy fully of the Server." },
            { cmd = "/givegems", usage = "/givegems", icon = 5814, desc = "This command allows you to give gems to use this command." },
            { cmd = "/?", usage = "/?", icon = 5814, desc = "Developer Help Panel: shows all registered server commands." },
            { cmd = "/h", usage = "/h", icon = 5814, desc = "Developer Help Panel: shows all registered server commands." },
            { cmd = "/dh", usage = "/dh", icon = 5814, desc = "Developer Help Panel: shows all registered server commands." },
            { cmd = "/manageexchange", usage = "/manageexchange", icon = 5814, desc = "Developer: Manage item exchange configurations." },
            { cmd = "/manageshop", usage = "/manageshop", icon = 5814, desc = "Developer: Manage the Gem Shop listings." },
            { cmd = "/editreferral", usage = "/editreferral", icon = 5814, desc = "Developer: Edit the Referral Milestones" },
            { cmd = "/rs", usage = "/rs", icon = 5814, desc = "This command allows you to use this command." },
            { cmd = "/reloadscripts", usage = "/reloadscripts", icon = 5814, desc = "This command allows you to use this command." },
            { cmd = "/say", usage = "/say", icon = 5814, desc = "This command allows you to make everyone" },
            { cmd = "/setslots", usage = "/setslots", icon = 5814, desc = "This command allows you to set" },
            { cmd = "/update", usage = "/update", icon = 5814, desc = "This command allows you to use this command." },
        }
    },
    {
        key   = "staff",
        label = "Staff",
        color = "`c",
        icon  = 482,
        commands = {
            { cmd = "/getdaily", usage = "/getdaily", icon = 482, desc = "This command gives you" },
            { cmd = "/farmer", usage = "/farmer", icon = 482, desc = "Spawn a Farmer NPC" },
            { cmd = "/demotemyself", usage = "/demotemyself", icon = 482, desc = "This command allows you to use this command." },
        }
    },
    {
        key   = "all",
        label = "All Players",
        color = "`2",
        icon  = 1366,
        commands = {
            { cmd = "/buy", usage = "/buy", icon = 982, desc = "This command allows you to buy items." },
            { cmd = "/coinflip", usage = "/coinflip", icon = 982, desc = "Play the Coin Flip minigame! Bet WL/DL/BGL and double your balance!" },
            { cmd = "/cf", usage = "/cf", icon = 982, desc = "Shortcut for /coinflip" },
            { cmd = "/fishinv", usage = "/fishinv", icon = 982, desc = "Open your personal fishing album to see your custom catches!" },
            { cmd = "/sellfish", usage = "/sellfish", icon = 982, desc = "Sell all your physical Growtopia fish from your inventory for World Locks!" },
            { cmd = "/enchant", usage = "/enchant", icon = 982, desc = "Enchant your fishing rod with custom drops!" },
            { cmd = "/exchange", usage = "/exchange", icon = 982, desc = "Open the Item Exchange Center and browse available trades." },
            { cmd = "/online", usage = "/online", icon = 982, desc = "This command lists all online players, their location, role, and status." },
            { cmd = "/menu", usage = "/menu", icon = 982, desc = "Open the Portal Menu (Tutorial / Cheats / Buy)." },
            { cmd = "/buyvip", usage = "/buyvip", icon = 982, desc = "This command allows you to buy items." },
        }
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
