-- ─────────────────────────────────────────────────────────────────────────────
-- Role Chat System
-- /vipchat <msg>  → Only players with VIP role or above can see it
-- /devchat <msg>  → Only players with Developer role can see it
-- ─────────────────────────────────────────────────────────────────────────────
print("(Loaded) Role Chat System")

-- ─── Role IDs ─────────────────────────────────────────────────────────────────
local ROLE_NONE      = 0
local ROLE_VIP       = 1
local ROLE_DEVELOPER = 51

-- ─── Chat Channels ────────────────────────────────────────────────────────────
-- Each channel defines:
--   command     : the slash command (without /)
--   senderRole  : minimum role required to SEND in this channel
--   viewerRole  : minimum role required to SEE this channel
--   tag         : colored prefix shown in chat
--   icon        : item icon shown in talk bubble (optional visual)
local CHAT_CHANNELS = {
    {
        command    = "vipchat",
        senderRole = ROLE_VIP,
        viewerRole = ROLE_VIP,
        tag        = "`#[VIP]`` ",
        color      = "`#",      -- gold
        label      = "VIP Chat",
    },
    {
        command    = "devchat",
        senderRole = ROLE_DEVELOPER,
        viewerRole = ROLE_DEVELOPER,
        tag        = "`6[DEV]`` ",
        color      = "`6",      -- orange
        label      = "Dev Chat",
    },
}

-- ─── Register Commands ────────────────────────────────────────────────────────
for _, ch in ipairs(CHAT_CHANNELS) do
    registerLuaCommand({
        command      = ch.command,
        roleRequired = ch.senderRole,
        description  = "Send a message in the " .. ch.label .. " channel (role-restricted)."
    })
end

-- ─── Helper: role name for display ───────────────────────────────────────────
local function getRoleTag(player)
    if player:hasRole(ROLE_DEVELOPER) then return "`6[DEV]``" end
    if player:hasRole(6)              then return "`5[GOD]``" end
    if player:hasRole(5)              then return "`p[CM]``"  end
    if player:hasRole(4)              then return "`4[ADMIN]``" end
    if player:hasRole(3)              then return "`6[MOD]``" end
    if player:hasRole(2)              then return "`9[SVIP]``" end
    if player:hasRole(ROLE_VIP)       then return "`#[VIP]``" end
    return ""
end

-- ─── Command Handler ──────────────────────────────────────────────────────────
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, message = fullCommand:match("^(%S+)%s*(.*)")
    if not cmd then return false end
    cmd = cmd:lower()

    for _, ch in ipairs(CHAT_CHANNELS) do
        if cmd == ch.command then
            -- Check sender has required role
            if not player:hasRole(ch.senderRole) then
                player:onConsoleMessage(
                    "`4Access Denied: `oYou need the `w" .. ch.label ..
                    "`o role or above to use this channel.``"
                )
                return true
            end

            -- Empty message guard
            if not message or message:match("^%s*$") then
                player:onConsoleMessage(
                    "`oUsage: `w/" .. ch.command .. " <message>``"
                )
                return true
            end

            -- Build the formatted chat line
            local senderName  = player:getCleanName()
            local senderTag   = getRoleTag(player)
            local chatLine    = ch.tag .. senderTag .. " `w" .. senderName .. ": ``" .. ch.color .. message .. "``"

            -- Broadcast only to players with viewerRole or above
            local players  = world:getPlayers()
            local sentTo   = 0

            for i = 1, #players do
                local p = players[i]
                if p:hasRole(ch.viewerRole) then
                    p:onConsoleMessage(chatLine)
                    sentTo = sentTo + 1
                end
            end

            -- Confirm to sender
            player:onConsoleMessage(
                "`o[" .. ch.label .. "] `2Message sent to " .. sentTo .. " player(s).``"
            )

            return true
        end
    end

    return false
end)
