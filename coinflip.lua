-- Coin Flip Minigame script
print("(Loaded) Coin Flip Minigame script for GrowSoft")

math.randomseed(os.time()) -- Seed once at load, same as daily-reward.lua

-- ─── Currency Config ──────────────────────────────────────────────────────────
-- Each currency ID and its WL equivalent value
local CURRENCIES = {
    { id = 242,   value = 1,       name = "WL",  label = "World Lock"    },
    { id = 1796,  value = 100,     name = "DL",  label = "Diamond Lock"  },
    { id = 7188,  value = 10000,   name = "BGL", label = "Blue Gem Lock" },
    { id = 20628, value = 1000000, name = "SPE", label = "Special Lock"  },
}

-- Convenience aliases
local WL_ID  = 242
local DL_ID  = 1796
local BGL_ID = 7188
local SPE_ID = 20628

-- ─── Game Config ──────────────────────────────────────────────────────────────
local COIN_HEAD_ID = 752    -- Flipping Coin icon (HEADS)
local COIN_TAIL_ID = 9240  -- Blarney Coin icon  (TAILS)
local MIN_BET      = 10     -- Minimum bet in WL equivalent
local MAX_BET      = 100000000  -- 100M WL cap

-- ─── Helpers ──────────────────────────────────────────────────────────────────
-- Strip trailing engine-appended byte from embed_data (marvelous-missions.lua pattern)
local function edata(val, default)
    if val == nil or val == "" then return default end
    return string.sub(val, 1, -2)
end

-- Number formatter (same as buy.lua / marvelous-missions.lua)
local function formatNum(num)
    local s = tostring(math.floor(num))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return s:gsub("^,", "")
end

local function applyStyle(player)
    if player.setNextDialogRGBA       then player:setNextDialogRGBA(12, 12, 22, 252)        end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 210, 0, 255) end
end

local function resetStyle(player)
    if player.resetDialogColor then player:resetDialogColor() end
end

-- ─── Session Manager ──────────────────────────────────────────────────────────
local sessions = {}
local function getSession(player)
    local pId = tostring(player:getNetID())
    if not sessions[pId] then sessions[pId] = {} end
    return sessions[pId]
end

-- ─── Multi-Currency Balance System ───────────────────────────────────────────

-- Returns player's total balance as a single WL-equivalent number
local function getTotalBalance(player)
    local total = 0
    for _, cur in ipairs(CURRENCIES) do
        total = total + (player:getItemAmount(cur.id) * cur.value)
    end
    return total
end

-- Returns a formatted breakdown string of the player's holdings per currency
local function getBalanceBreakdown(player)
    local parts = {}
    for _, cur in ipairs(CURRENCIES) do
        local amt = player:getItemAmount(cur.id)
        if amt > 0 then
            table.insert(parts, "`$" .. formatNum(amt) .. "`` `w" .. cur.name .. "``")
        end
    end
    if #parts == 0 then return "`4None``" end
    return table.concat(parts, "  `o|``  ")
end

-- Deduct exactly `amount` WL-equivalent from the player.
-- Breaks large denominations and gives back WL change when needed.
-- Returns true on success, false if balance insufficient.
local function deductBalance(player, amount)
    if amount <= 0 then return true end
    if getTotalBalance(player) < amount then return false end

    local remaining = amount

    -- Work from SMALLEST denomination upward to preserve large ones.
    -- If WL runs out, break one DL into 100 WL change, etc.
    for i = 1, #CURRENCIES do
        if remaining <= 0 then break end
        local cur    = CURRENCIES[i]
        local have   = player:getItemAmount(cur.id)
        if have > 0 then
            -- How many of this denomination do we need (ceiling)?
            local need = math.ceil(remaining / cur.value)
            local take = math.min(need, have)
            -- How much WL value we're actually taking
            local taken_value = take * cur.value
            -- Actual deduction
            player:changeItem(cur.id, -take, 0)
            -- If we over-shot (change needed), give back as WL
            local change = taken_value - remaining
            if change > 0 then
                -- Give back change in the largest possible denominations
                local chg_rem = change
                for j = #CURRENCIES, 1, -1 do
                    local cc = CURRENCIES[j]
                    if chg_rem >= cc.value then
                        local give = math.floor(chg_rem / cc.value)
                        chg_rem = chg_rem - (give * cc.value)
                        if not player:changeItem(cc.id, give, 0) then
                            player:changeItem(cc.id, give, 1)
                        end
                    end
                end
            end
            remaining = remaining - taken_value
            if remaining < 0 then remaining = 0 end
        end
    end

    return remaining <= 0
end

-- Pay out `amount` WL-equivalent to the player in smart denominations
-- (largest first to keep inventory compact).
local function payoutBalance(player, amount)
    if amount <= 0 then return end
    local remaining = amount

    -- Give highest denomination first for inventory efficiency
    for i = #CURRENCIES, 1, -1 do
        local cur = CURRENCIES[i]
        if remaining >= cur.value then
            local give = math.floor(remaining / cur.value)
            remaining  = remaining - (give * cur.value)
            if not player:changeItem(cur.id, give, 0) then
                player:changeItem(cur.id, give, 1) -- fallback: backpack
            end
        end
    end
end

-- ─── Register Commands ────────────────────────────────────────────────────────
registerLuaCommand({
    command      = "coinflip",
    roleRequired = 0,
    description  = "Play the Coin Flip minigame! Bet WL/DL/BGL and double your balance!"
})
registerLuaCommand({
    command      = "cf",
    roleRequired = 0,
    description  = "Shortcut for /coinflip"
})

-- ─── Screen 1: Bet & Pick ─────────────────────────────────────────────────────
function showBetScreen(player, lastBet)
    lastBet = math.max(MIN_BET, math.floor(lastBet or MIN_BET))

    local totalBal    = getTotalBalance(player)
    local breakdown   = getBalanceBreakdown(player)

    applyStyle(player)

    local d = {}

    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`$Coin Flip``|left|" .. COIN_HEAD_ID .. "|")
    table.insert(d, "add_smalltext|`oFlip the coin and win `$2x`` your bet — or lose it all!``|left|")
    table.insert(d, "add_spacer|small|")

    -- Balance breakdown (shows all currencies the player holds)
    table.insert(d, "add_textbox|`oYour Balance:``|left|")
    table.insert(d, "add_smalltext|" .. breakdown .. "|left|")
    table.insert(d, "add_smalltext|`oTotal: `$" .. formatNum(totalBal) .. " WL equivalent``|left|")
    table.insert(d, "add_spacer|small|")

    -- Currency info (so player knows the exchange rates)
    table.insert(d, "add_smalltext|`oRates: `w1 DL`o=`$100 WL``  `w1 BGL`o=`$10,000 WL``  `w1 SPE`o=`$1,000,000 WL``|left|")
    table.insert(d, "add_spacer|small|")

    -- Bet input
    table.insert(d, "add_text_input|bet_amount|Bet Amount (WL equivalent):|" .. lastBet .. "|10|")
    table.insert(d, "add_spacer|small|")

    -- Quick bet buttons
    table.insert(d, "add_smalltext|`oQuick Bet:``|left|")
    table.insert(d, "add_button|qbet_10|`o10 WL``|no_flags|0|0|")
    table.insert(d, "add_button|qbet_100|`o100 WL (1 DL)``|no_flags|0|0|")
    table.insert(d, "add_button|qbet_1000|`o1,000 WL``|no_flags|0|0|")
    table.insert(d, "add_button|qbet_10000|`o10,000 WL (1 BGL)``|no_flags|0|0|")
    table.insert(d, "add_button|qbet_100000|`o100,000 WL``|no_flags|0|0|")
    table.insert(d, "add_button|qbet_1000000|`o1,000,000 WL (1 SPE)``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")

    -- Side selection icons (daily-reward.lua staticBlueFrame + END_LIST pattern)
    table.insert(d, "add_textbox|`wPick a side to flip the coin!``|left|")
    table.insert(d, "add_checkbox|auto_bet|`5Auto-Bet (Repeats until stopped)``|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "embed_data|last_bet|" .. lastBet)
    table.insert(d, "add_button_with_icon|flip_head|`wHEADS``|staticBlueFrame|" .. COIN_HEAD_ID .. "||")
    table.insert(d, "add_button_with_icon|flip_tail|`wTAILS``|staticBlueFrame|" .. COIN_TAIL_ID .. "||")
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_smalltext|`oTap `wHEADS`` or `wTAILS`` to confirm your bet and flip!``|left|")
    table.insert(d, "add_smalltext|`oMin: `w" .. formatNum(MIN_BET) .. " WL``  |  All bets are in `$WL equivalent``.|left|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|cf_bet|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)
end

-- ─── Screen 2: Result ─────────────────────────────────────────────────────────
-- Called AFTER bet has been deducted. Handles flip, payout, and result dialog.
local function showResult(player, chosenSide, betAmount)
    -- Coin flip
    local roll       = math.random(0, 1)
    local resultSide = roll == 0 and "heads" or "tails"
    local won        = (chosenSide == resultSide)

    local resultIconID = roll == 0 and COIN_HEAD_ID or COIN_TAIL_ID
    local resultLabel  = roll == 0 and "HEADS" or "TAILS"
    local choseLabel   = chosenSide == "heads" and "HEADS" or "TAILS"

    -- Payout if won: return bet + prize = betAmount * 2
    if won then
        payoutBalance(player, betAmount * 2)
    end

    local newBal     = getTotalBalance(player)
    local newBreak   = getBalanceBreakdown(player)

    -- Effects
    if won then
        player:onTextOverlay("`2YOU WIN! `$+" .. formatNum(betAmount) .. " WL``!``")
        player:onAddNotification("", "`$COIN FLIP WIN!``", "", 0, 2000)
        player:onTalkBubble(player:getNetID(), "`2I won " .. formatNum(betAmount) .. " WL!``", 0)
        player:playAudio("piano_nice.wav")
        player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
        player:onConsoleMessage(
            "`6>> CoinFlip: `2YOU WON `$" .. formatNum(betAmount) ..
            " WL eq``! | Coin: `w" .. resultLabel ..
            "`` | New Balance: `$" .. formatNum(newBal) .. " WL eq``")
    else
        player:onTextOverlay("`4You lost... -" .. formatNum(betAmount) .. " WL``")
        player:playAudio("bleep_fail.wav")
        player:onConsoleMessage(
            "`6>> CoinFlip: `4You LOST `$" .. formatNum(betAmount) ..
            " WL eq``. | Coin: `w" .. resultLabel ..
            "`` | New Balance: `$" .. formatNum(newBal) .. " WL eq``")
    end

    applyStyle(player)

    local d = {}
    table.insert(d, "set_default_color|`o")

    if won then
        table.insert(d, "add_label_with_icon|big|`2YOU WIN!``|left|" .. resultIconID .. "|")
    else
        table.insert(d, "add_label_with_icon|big|`4YOU LOSE!``|left|" .. resultIconID .. "|")
    end
    table.insert(d, "add_spacer|small|")

    -- Preserve last bet for Play Again
    table.insert(d, "embed_data|last_bet|" .. betAmount)

    -- Result coin icon (staticYellowFrame like daily-reward.lua)
    table.insert(d, "add_textbox|`oThe coin landed on:``|left|")
    table.insert(d, "add_button_with_icon|noop||staticYellowFrame,disabled|" .. resultIconID .. "||")
    table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    table.insert(d, "add_spacer|small|")

    -- Round summary
    table.insert(d, "add_smalltext|`oYou chose:   `w" .. choseLabel .. "``|left|")
    table.insert(d, "add_smalltext|`oResult:          `w" .. resultLabel .. "``|left|")
    table.insert(d, "add_smalltext|`oBet Amount:  `w" .. formatNum(betAmount) .. " WL eq``|left|")
    table.insert(d, "add_spacer|small|")

    -- Win/loss amount
    if won then
        table.insert(d, "add_textbox|`2+ " .. formatNum(betAmount) .. " WL equivalent won!``|left|")
    else
        table.insert(d, "add_textbox|`4- " .. formatNum(betAmount) .. " WL equivalent lost!``|left|")
    end

    -- New balance breakdown
    table.insert(d, "add_smalltext|`oNew Balance:``|left|")
    table.insert(d, "add_smalltext|" .. newBreak .. "|left|")
    table.insert(d, "add_smalltext|`oTotal: `$" .. formatNum(newBal) .. " WL equivalent``|left|")
    table.insert(d, "add_spacer|small|")

    local sess = getSession(player)
    local isAuto = sess.cf_auto and sess.cf_auto.active

    if isAuto then
        table.insert(d, "add_button|cf_stop_auto|`4🛑 Stop Auto-Bet``|no_flags|0|0|")
    else
        table.insert(d, "add_button|cf_again|`wPlay Again``|no_flags|0|0|")
    end

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|cf_result|Close||\n" ..
        "add_quick_exit|"
    )
    resetStyle(player)

    if isAuto then
        local netID = player:getNetID()
        local round = sess.cf_auto.round
        timer.setTimeout(1.5, function()
            local pSess = sessions[tostring(netID)]
            if not pSess or not pSess.cf_auto or not pSess.cf_auto.active or pSess.cf_auto.round ~= round then
                return
            end
            
            -- Check balance
            local totalBal = getTotalBalance(player)
            if totalBal < betAmount then
                pSess.cf_auto.active = false
                player:onConsoleMessage("`4Auto-Bet stopped: Not enough balance!``")
                return
            end
            
            -- Deduct & flip
            if deductBalance(player, betAmount) then
                pSess.cf_auto.round = pSess.cf_auto.round + 1
                showResult(player, chosenSide, betAmount)
            else
                pSess.cf_auto.active = false
            end
        end)
    end
end

-- ─── Command Handler ──────────────────────────────────────────────────────────
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    local cmdLow = cmd:lower()
    if cmdLow ~= "coinflip" and cmdLow ~= "cf" then return false end

    showBetScreen(player, MIN_BET)
    return true
end)

-- ─── Dialog Callbacks ─────────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    local dlg     = data["dialog_name"]   or ""
    local clicked = data["buttonClicked"] or ""

    if dlg == "portal_shortcuts" and clicked == "sc_coinflip" then
        showBetScreen(player)
        return true
    end

    -- ── Bet / Pick screen ──────────────────────────────────────────────────────
    if dlg == "cf_bet" then

        -- Quick-bet presets (just reload screen with prefilled amount)
        local quickBets = {
            qbet_10      = 10,
            qbet_100     = 100,
            qbet_1000    = 1000,
            qbet_10000   = 10000,
            qbet_100000  = 100000,
            qbet_1000000 = 1000000,
        }
        if quickBets[clicked] then
            showBetScreen(player, quickBets[clicked])
            return true
        end

        -- Must be HEADS or TAILS to proceed
        local chosenSide = nil
        if     clicked == "flip_head" then chosenSide = "heads"
        elseif clicked == "flip_tail" then chosenSide = "tails"
        else return true end

        -- ── Validate bet ──────────────────────────────────────────────────────
        -- data["bet_amount"] comes from add_text_input — no embed_data strip needed
        local betAmount = tonumber(data["bet_amount"] or "")

        local sess = getSession(player)
        if data["auto_bet"] == "1" then
            sess.cf_auto = {
                active = true,
                side = chosenSide,
                betAmount = betAmount,
                round = (sess.cf_auto and sess.cf_auto.round or 0) + 1
            }
        else
            if sess.cf_auto then sess.cf_auto.active = false end
        end

        if not betAmount then
            player:onConsoleMessage("`4Error: `oEnter a valid number for your bet.``")
            showBetScreen(player, MIN_BET)
            return true
        end

        betAmount = math.floor(betAmount)

        if betAmount < MIN_BET then
            player:onConsoleMessage(
                "`4Error: `oMinimum bet is `w" .. formatNum(MIN_BET) ..
                " WL``. Cannot bet below that!``")
            showBetScreen(player, MIN_BET)
            return true
        end

        if betAmount > MAX_BET then
            player:onConsoleMessage(
                "`4Error: `oMaximum bet is `w" .. formatNum(MAX_BET) .. " WL``.``")
            showBetScreen(player, MAX_BET)
            return true
        end

        -- ── Check total balance across all currencies ──────────────────────────
        local totalBal = getTotalBalance(player)
        if totalBal < betAmount then
            player:onConsoleMessage(
                "`4Error: `oNot enough balance! You have `$" ..
                formatNum(totalBal) .. " WL equivalent`` but need `w" ..
                formatNum(betAmount) .. " WL``.``")
            showBetScreen(player, math.max(MIN_BET, math.min(betAmount, totalBal)))
            return true
        end

        -- ── Deduct bet across currencies ───────────────────────────────────────
        if not deductBalance(player, betAmount) then
            player:onConsoleMessage("`4Error: `oFailed to deduct your bet. Please try again.``")
            showBetScreen(player, betAmount)
            return true
        end

        -- ── Flip! ─────────────────────────────────────────────────────────────
        showResult(player, chosenSide, betAmount)
        return true
    end

    -- ── Result screen ──────────────────────────────────────────────────────────
    if dlg == "cf_result" then
        local sess = getSession(player)
        
        if clicked == "cf_again" then
            -- embed_data → strip trailing engine byte (marvelous-missions.lua pattern)
            local lastBet = tonumber(edata(data["last_bet"], tostring(MIN_BET))) or MIN_BET
            lastBet = math.max(MIN_BET, math.min(lastBet, MAX_BET))
            showBetScreen(player, lastBet)
            return true
        elseif clicked == "cf_stop_auto" then
            if sess.cf_auto then sess.cf_auto.active = false end
            player:onConsoleMessage("`4Auto-Bet stopped!``")
            
            local lastBet = tonumber(edata(data["last_bet"], tostring(MIN_BET))) or MIN_BET
            lastBet = math.max(MIN_BET, math.min(lastBet, MAX_BET))
            showBetScreen(player, lastBet)
            return true
        elseif clicked == "" then
            -- Dialog closed (e.g. they walked away or pressed ESC)
            if sess.cf_auto then sess.cf_auto.active = false end
        end
        return true
    end

    return false
end)
