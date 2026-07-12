-- Referral System script
print("(Loaded) Referral System script for GrowSoft")

local Config = {
    Command = "referral",
    ReferrerRewardGems = 5000,
    ReferredRewardGems = 2000,
    CodeLength = 6
}

local MILESTONES_PATH = "config/referral_milestones.json"
local DB_PATH = "referrals.db"
local db = sqlite.open(DB_PATH)

local admin_sessions = {}
local PAGE_SIZE = 10

local function initDB()
    db:query([[
        CREATE TABLE IF NOT EXISTS referral_codes (
            user_id INTEGER PRIMARY KEY,
            code TEXT UNIQUE,
            total_referred INTEGER DEFAULT 0,
            unclaimed_gems INTEGER DEFAULT 0
        )
    ]])
    db:query("ALTER TABLE referral_codes ADD COLUMN highest_milestone INTEGER DEFAULT 0")
    
    db:query([[
        CREATE TABLE IF NOT EXISTS referral_tracking (
            user_id INTEGER PRIMARY KEY,
            referred_by INTEGER
        )
    ]])
end
initDB()

local function readMilestones()
    if type(file) == "table" and type(file.exists) == "function" and not file.exists(MILESTONES_PATH) then
        return {
            { required = 5, rewardName = "10,000 Gems", rewardGems = 10000, icon = 112 },
            { required = 10, rewardName = "25,000 Gems", rewardGems = 25000, icon = 112 },
            { required = 25, rewardName = "1x Diamond Lock", rewardItem = 482, rewardAmount = 1, icon = 482 },
            { required = 50, rewardName = "1x Blue Gem Lock", rewardItem = 7188, rewardAmount = 1, icon = 7188 }
        }
    end

    local content = file.read(MILESTONES_PATH)
    if not content or content == "" then
        -- Default fallback
        local default = {
            { required = 5, rewardName = "10,000 Gems", rewardGems = 10000, icon = 112 },
            { required = 10, rewardName = "25,000 Gems", rewardGems = 25000, icon = 112 },
            { required = 25, rewardName = "1x Diamond Lock", rewardItem = 482, rewardAmount = 1, icon = 482 },
            { required = 50, rewardName = "1x Blue Gem Lock", rewardItem = 7188, rewardAmount = 1, icon = 7188 }
        }
        return default
    end
    return json.decode(content) or {}
end

local function writeMilestones(data)
    -- ensure sorted by required invites
    table.sort(data, function(a, b) return (tonumber(a.required) or 0) < (tonumber(b.required) or 0) end)
    local content = json.encode(data)
    file.write(MILESTONES_PATH, content)
end

-- If JSON file doesn't exist, create it with defaults
if type(file) == "table" and type(file.exists) == "function" and not file.exists(MILESTONES_PATH) then
    writeMilestones(readMilestones())
end

local function formatNum(n)
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function generateRandomCode(len)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local res = ""
    for i = 1, len do
        local r = math.random(1, #charset)
        res = res .. charset:sub(r, r)
    end
    return res
end

local function getPlayerCodeData(user_id)
    local rows = db:query(string.format("SELECT * FROM referral_codes WHERE user_id = %d", user_id))
    if rows and #rows > 0 then
        local r = rows[1]
        r.user_id = tonumber(r.user_id) or 0
        r.total_referred = tonumber(r.total_referred) or 0
        r.unclaimed_gems = tonumber(r.unclaimed_gems) or 0
        r.highest_milestone = tonumber(r.highest_milestone) or 0
        return r
    end
    return nil
end

local function getCodeOwner(code)
    code = tostring(code):match("^%s*(.-)%s*$"):upper()
    local rows = db:query(string.format("SELECT * FROM referral_codes WHERE code = '%s'", code))
    if rows and #rows > 0 then
        local r = rows[1]
        r.user_id = tonumber(r.user_id) or 0
        return r
    end
    return nil
end

local function hasBeenReferred(user_id)
    local rows = db:query(string.format("SELECT referred_by FROM referral_tracking WHERE user_id = %d", user_id))
    return (rows and #rows > 0)
end

local function generateAndSaveCode(user_id)
    local newCode
    local maxAttempts = 10
    for i = 1, maxAttempts do
        newCode = generateRandomCode(Config.CodeLength)
        if not getCodeOwner(newCode) then
            break
        end
    end
    
    db:query(string.format("INSERT INTO referral_codes (user_id, code, total_referred, unclaimed_gems, highest_milestone) VALUES (%d, '%s', 0, 0, 0)", user_id, newCode))
    return newCode
end

-- ADMIN UI FUNCTIONS
local function showAdminMain(player)
    local milestones = readMilestones()
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Referral Milestones Editor``|left|3228|")
    table.insert(d, "add_smalltext|`oManage the rewards players get for inviting friends.``|left|")
    table.insert(d, "add_spacer|small|")
    
    for i, ms in ipairs(milestones) do
        table.insert(d, "add_label_with_icon|small|`w" .. ms.required .. " Invites: " .. ms.rewardName .. "``|left|" .. (ms.icon or 112) .. "|")
        table.insert(d, "add_button|ref_admin_edit_" .. i .. "|`5Edit``|no_flags|0|0|")
        table.insert(d, "add_button|ref_admin_del_" .. i .. "|`4Delete``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end
    
    table.insert(d, "add_button|ref_admin_add|`2+ Add New Milestone``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|ref_admin_close|`oClose``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|ref_admin_main|Close||\n" ..
        "add_quick_exit|"
    )
end

local function showAdminEdit(player, index)
    local milestones = readMilestones()
    local session = admin_sessions[tostring(player:getNetID())] or {}
    
    if index > 0 and not session.initialized then
        local ms = milestones[index]
        if ms then
            session.required = ms.required
            if ms.rewardGems then
                session.rewardType = "gems"
                session.rewardAmount = ms.rewardGems
                session.rewardName = ms.rewardName
                session.icon = ms.icon or 112
            else
                session.rewardType = "item"
                session.rewardItem = ms.rewardItem
                session.rewardAmount = ms.rewardAmount
                session.rewardName = ms.rewardName
                session.icon = ms.icon or 112
            end
        end
        session.initialized = true
    elseif index == 0 and not session.initialized then
        session.required = 100
        session.rewardType = "gems"
        session.rewardAmount = 1000
        session.rewardName = "1000 Gems"
        session.icon = 112
        session.initialized = true
    end
    
    session.editingIndex = index
    admin_sessions[tostring(player:getNetID())] = session
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Edit Milestone``|left|" .. session.icon .. "|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_textbox|`oTarget Invites Required:``|left|")
    table.insert(d, "add_text_input|input_req||" .. tostring(session.required) .. "|10|")
    
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`oCurrent Reward: `w" .. session.rewardName .. "``|left|")
    table.insert(d, "add_button|ref_admin_change_item|`9Change Reward Item``|no_flags|0|0|")
    
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_textbox|`oReward Quantity/Amount:``|left|")
    table.insert(d, "add_text_input|input_amt||" .. tostring(session.rewardAmount) .. "|10|")
    
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|ref_admin_save|`2Save Milestone``|no_flags|0|0|")
    table.insert(d, "add_button|ref_admin_back|`oBack to List``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|ref_admin_edit|Close||\n" ..
        "add_quick_exit|"
    )
end

local function showAdminSearch(player, searchQuery, page)
    searchQuery = searchQuery or ""
    page = page or 1
    local session = admin_sessions[tostring(player:getNetID())]
    if not session then return end
    
    local matches = {}
    table.insert(matches, { id = 112, name = "Gems", isGems = true })
    
    local q = (searchQuery ~= "") and searchQuery:lower() or nil
    local totalItems = getItemsCount() or 0
    for i = 1, totalItems - 1 do
        local item = getItem(i)
        if item then
            local nm = item:getName()
            if nm and nm ~= "" then
                if not q or nm:lower():find(q, 1, true) then
                    table.insert(matches, { id = item:getID(), name = nm, isGems = false })
                end
            end
        end
    end
    
    local total = #matches
    local totalPages = math.max(1, math.ceil(total / PAGE_SIZE))
    if page > totalPages then page = totalPages end
    
    local si = (page - 1) * PAGE_SIZE + 1
    local ei = math.min(total, page * PAGE_SIZE)
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Select Reward Item``|left|6016|")
    
    table.insert(d, "embed_data|st_q|" .. searchQuery)
    table.insert(d, "embed_data|st_page|" .. tostring(page))
    
    table.insert(d, "add_text_input|sq|Search Item:|"..searchQuery.."|22|")
    table.insert(d, "add_button|btn_search_item|`wSearch``|no_flags|0|0|")
    table.insert(d, "add_spacer|small|")
    
    if total > 0 then
        table.insert(d, "add_smalltext|Found " .. total .. " items (Page " .. page .. "/" .. totalPages .. ")|left|")
        for i = si, ei do
            local m = matches[i]
            local prefix = m.isGems and "selgem_" or "selitem_"
            table.insert(d, "add_button_with_icon|" .. prefix .. m.id .. "|`w" .. m.name .. "``|staticGreyFrame,no_padding_x|" .. m.id .. "||")
        end
        table.insert(d, "add_button_with_icon||END_LIST|noflags|0||")
    else
        table.insert(d, "add_smalltext|`4No items found.``|left|")
    end
    
    table.insert(d, "add_spacer|small|")
    
    if totalPages > 1 then
        if page > 1 then table.insert(d, "add_button|btn_prev_item|`w<< Prev``|no_flags|0|0|") end
        if page < totalPages then table.insert(d, "add_button|btn_next_item|`wNext >>``|no_flags|0|0|") end
    end
    
    table.insert(d, "add_button|btn_cancel_search|`oCancel``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|ref_admin_search|Close||\n" ..
        "add_quick_exit|"
    )
end

local function applyTheme(player)
    if player.setNextDialogRGBA then player:setNextDialogRGBA(20, 20, 30, 245) end
    if player.setNextDialogBorderRGBA then player:setNextDialogBorderRGBA(255, 210, 0, 255) end
end

-- PLAYER REFERRAL UI
local function showReferralMenu(player)
    local user_id = tonumber(player:getUserID())
    if not user_id then return end

    local codeData = getPlayerCodeData(user_id)
    local isReferred = hasBeenReferred(user_id)
    local milestones = readMilestones()
    
    applyTheme(player)
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`wReferral Program``|left|7188|")
    table.insert(d, "add_smalltext|`oInvite your friends and earn epic rewards!``|left|")
    table.insert(d, "add_spacer|small|")
    
    if codeData then
        -- Stats Dashboard
        table.insert(d, "add_label_with_icon|small|`9Your Dashboard``|left|3228|")
        table.insert(d, "add_textbox|`oYour Referral Code: `w" .. codeData.code .. "``|left|")
        table.insert(d, "add_textbox|`oTotal Friends Invited: `2" .. codeData.total_referred .. "``|left|")
        table.insert(d, "add_textbox|`oPending Sign-up Bonuses: `$" .. formatNum(codeData.unclaimed_gems) .. " Gems``|left|")
        
        if codeData.unclaimed_gems > 0 then
            table.insert(d, "add_spacer|small|")
            table.insert(d, "add_button_with_icon|ref_claim|`2Claim Pending Gems``|staticYellowFrame|112|")
        end
        table.insert(d, "add_spacer|small|")
        
        -- Progression
        table.insert(d, "add_label_with_icon|small|`5Progression Milestones``|left|482|")
        table.insert(d, "add_smalltext|`oUnlock these exclusive rewards as you invite more friends.``|left|")
        
        for i, ms in ipairs(milestones) do
            local icon = ms.icon or 112
            if codeData.highest_milestone >= ms.required then
                -- Claimed
                table.insert(d, "add_button_with_icon||`w" .. ms.required .. " Invites: " .. ms.rewardName .. " `2(CLAIMED)``|staticGreyFrame|" .. icon .. "|")
            elseif codeData.total_referred >= ms.required then
                -- Ready to claim
                table.insert(d, "add_button_with_icon|ref_ms_" .. i .. "|`2CLAIM REWARD: " .. ms.rewardName .. "``|staticYellowFrame|" .. icon .. "|")
            else
                -- Locked
                table.insert(d, "add_button_with_icon||`w" .. ms.required .. " Invites: " .. ms.rewardName .. " `4(" .. codeData.total_referred .. "/" .. ms.required .. ")``|noflags|" .. icon .. "|")
            end
        end
        table.insert(d, "add_spacer|small|")
        
    else
        table.insert(d, "add_label_with_icon|small|`9Welcome!``|left|3228|")
        table.insert(d, "add_textbox|`oYou don't have a referral code yet! Generate one to invite friends and earn `$" .. formatNum(Config.ReferrerRewardGems) .. " Gems`` for each friend!|left|")
        table.insert(d, "add_button|ref_generate|`9Generate My Code``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end
    
    if not isReferred then
        table.insert(d, "add_label_with_icon|small|`2Sign-Up Bonus``|left|112|")
        table.insert(d, "add_smalltext|`oWere you invited by a friend? Enter their code to claim `$" .. formatNum(Config.ReferredRewardGems) .. " Gems``!|left|")
        table.insert(d, "add_text_input|ref_input_code|Code:||15|")
        table.insert(d, "add_button|ref_submit_code|`2Claim Bonus``|no_flags|0|0|")
        table.insert(d, "add_spacer|small|")
    end
    
    table.insert(d, "add_button|ref_close|`oClose``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|referral_menu|Close||\n" ..
        "add_quick_exit|"
    )
    
    if player.resetDialogColor then player:resetDialogColor() end
end

registerLuaCommand({
    command = Config.Command,
    roleRequired = 0,
    description = "Open the Referral System menu"
})

registerLuaCommand({
    command = "editreferral",
    roleRequired = 51,
    description = "Developer: Edit the Referral Milestones"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == Config.Command then
        showReferralMenu(player)
        return true
    end
    
    if cmd:lower() == "editreferral" then
        if player:hasRole(51) then
            showAdminMain(player)
        else
            player:onConsoleMessage("`4You do not have permission to use this command!``")
        end
        return true
    end
    
    return false
end)

local function edata(val, default)
    if val == nil or val == "" then return default end
    return string.sub(val, 1, -2)
end

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local clicked = data["buttonClicked"] or ""
    local user_id = tonumber(player:getUserID())
    if not user_id then return false end
    
    -- ADMIN MENU CALLBACKS
    if dlg == "ref_admin_main" then
        if not player:hasRole(51) then return true end
        if clicked == "ref_admin_close" then return true end
        if clicked == "ref_admin_add" then
            admin_sessions[tostring(player:getNetID())] = {}
            showAdminEdit(player, 0)
            return true
        end
        if clicked:sub(1, 15) == "ref_admin_edit_" then
            local idx = tonumber(clicked:sub(16))
            admin_sessions[tostring(player:getNetID())] = {}
            showAdminEdit(player, idx)
            return true
        end
        if clicked:sub(1, 14) == "ref_admin_del_" then
            local idx = tonumber(clicked:sub(15))
            local msList = readMilestones()
            table.remove(msList, idx)
            writeMilestones(msList)
            player:onConsoleMessage("`4>> Milestone deleted.``")
            showAdminMain(player)
            return true
        end
        return true
    end
    
    if dlg == "ref_admin_edit" then
        if not player:hasRole(51) then return true end
        local session = admin_sessions[tostring(player:getNetID())]
        if not session then return true end
        
        session.required = tonumber(data["input_req"]) or session.required
        session.rewardAmount = tonumber(data["input_amt"]) or session.rewardAmount
        
        if clicked == "ref_admin_back" then
            showAdminMain(player)
            return true
        end
        
        if clicked == "ref_admin_change_item" then
            showAdminSearch(player, "", 1)
            return true
        end
        
        if clicked == "ref_admin_save" then
            local msList = readMilestones()
            local newMs = { required = session.required, icon = session.icon }
            if session.rewardType == "gems" then
                newMs.rewardGems = session.rewardAmount
                newMs.rewardName = formatNum(session.rewardAmount) .. " Gems"
            else
                newMs.rewardItem = session.rewardItem
                newMs.rewardAmount = session.rewardAmount
                newMs.rewardName = formatNum(session.rewardAmount) .. "x " .. (session.rewardName:gsub("^%d+x ", ""))
            end
            
            if session.editingIndex == 0 then
                table.insert(msList, newMs)
            else
                msList[session.editingIndex] = newMs
            end
            
            writeMilestones(msList)
            player:playAudio("success.wav")
            player:onConsoleMessage("`2>> Milestone saved successfully!``")
            showAdminMain(player)
            return true
        end
        return true
    end
    
    if dlg == "ref_admin_search" then
        if not player:hasRole(51) then return true end
        local session = admin_sessions[tostring(player:getNetID())]
        if not session then return true end
        
        local sq = edata(data["st_q"], "")
        local page = tonumber(edata(data["st_page"], "1")) or 1
        
        if clicked == "btn_cancel_search" then
            showAdminEdit(player, session.editingIndex)
            return true
        elseif clicked == "btn_search_item" then
            showAdminSearch(player, data["sq"] or "", 1)
            return true
        elseif clicked == "btn_prev_item" then
            showAdminSearch(player, sq, page - 1)
            return true
        elseif clicked == "btn_next_item" then
            showAdminSearch(player, sq, page + 1)
            return true
        elseif clicked:sub(1, 7) == "selgem_" then
            session.rewardType = "gems"
            session.rewardName = "Gems"
            session.icon = 112
            showAdminEdit(player, session.editingIndex)
            return true
        elseif clicked:sub(1, 8) == "selitem_" then
            local itemID = tonumber(clicked:sub(9))
            local item = getItem(itemID)
            if item then
                session.rewardType = "item"
                session.rewardItem = itemID
                session.rewardName = item:getName()
                session.icon = itemID
            end
            showAdminEdit(player, session.editingIndex)
            return true
        end
        return true
    end
    
    -- REGULAR REFERRAL CALLBACKS
    if dlg == "referral_menu" then
        if clicked == "ref_close" then return true end
        
        if clicked == "ref_generate" then
            if not getPlayerCodeData(user_id) then
                local code = generateAndSaveCode(user_id)
                player:onConsoleMessage("`2Successfully generated your referral code: `w" .. code .. "``!")
                player:playAudio("success.wav")
            end
            showReferralMenu(player)
            return true
        end
        
        if clicked == "ref_claim" then
            local codeData = getPlayerCodeData(user_id)
            if codeData and codeData.unclaimed_gems > 0 then
                local amount = codeData.unclaimed_gems
                db:query(string.format("UPDATE referral_codes SET unclaimed_gems = 0 WHERE user_id = %d", user_id))
                player:addGems(amount, 0, 1)
                player:playAudio("cash_register.wav")
                player:onConsoleMessage("`2>> You successfully claimed `$" .. formatNum(amount) .. " Gems`` from your referrals!``")
            end
            showReferralMenu(player)
            return true
        end
        
        if clicked:sub(1, 7) == "ref_ms_" then
            local msIndex = tonumber(clicked:sub(8))
            local codeData = getPlayerCodeData(user_id)
            local milestones = readMilestones()
            
            if msIndex and codeData then
                local ms = milestones[msIndex]
                if ms and codeData.total_referred >= ms.required and codeData.highest_milestone < ms.required then
                    
                    local previousRequired = 0
                    if msIndex > 1 then
                        previousRequired = milestones[msIndex-1].required
                    end
                    
                    if codeData.highest_milestone < previousRequired then
                        player:onConsoleMessage("`4Please claim your previous milestones first!``")
                        showReferralMenu(player)
                        return true
                    end
                    
                    db:query(string.format("UPDATE referral_codes SET highest_milestone = %d WHERE user_id = %d", ms.required, user_id))
                    
                    if ms.rewardGems then
                        player:addGems(ms.rewardGems, 0, 1)
                    end
                    if ms.rewardItem and ms.rewardAmount then
                        if not player:changeItem(ms.rewardItem, ms.rewardAmount, 0) then
                            player:changeItem(ms.rewardItem, ms.rewardAmount, 1)
                        end
                    end
                    
                    player:playAudio("success.wav")
                    player:onParticleEffect(46, player:getMiddlePosX(), player:getMiddlePosY(), 0, 0)
                    player:onConsoleMessage("`2>> Congratulations! You reached a milestone and received: " .. ms.rewardName .. "!``")
                end
            end
            showReferralMenu(player)
            return true
        end
        
        if clicked == "ref_submit_code" then
            if hasBeenReferred(user_id) then
                player:onConsoleMessage("`4You have already used a referral code!``")
                showReferralMenu(player)
                return true
            end
            
            local inputCode = data["ref_input_code"] or ""
            inputCode = inputCode:match("^%s*(.-)%s*$"):upper()
            
            if inputCode == "" then
                player:onConsoleMessage("`4Please enter a valid code!``")
                showReferralMenu(player)
                return true
            end
            
            local ownerData = getCodeOwner(inputCode)
            
            if not ownerData then
                player:onConsoleMessage("`4Invalid referral code!``")
                showReferralMenu(player)
                return true
            end
            
            if ownerData.user_id == user_id then
                player:onConsoleMessage("`4You cannot use your own referral code!``")
                showReferralMenu(player)
                return true
            end
            
            db:query(string.format("INSERT INTO referral_tracking (user_id, referred_by) VALUES (%d, %d)", user_id, ownerData.user_id))
            db:query(string.format("UPDATE referral_codes SET total_referred = total_referred + 1, unclaimed_gems = unclaimed_gems + %d WHERE user_id = %d", Config.ReferrerRewardGems, ownerData.user_id))
            
            player:addGems(Config.ReferredRewardGems, 0, 1)
            player:playAudio("cash_register.wav")
            player:onConsoleMessage("`2>> You successfully used a referral code and received `$" .. formatNum(Config.ReferredRewardGems) .. " Gems``!``")
            
            showReferralMenu(player)
            return true
        end
        
        return true
    end
    
    return false
end)
