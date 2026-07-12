print("(Loaded) http script for GTPS Cloud")

_G.serverStartTime = _G.serverStartTime or os.time()
_G.HighestPlaytimeName = _G.HighestPlaytimeName or "None"
_G.HighestPlaytimeValue = _G.HighestPlaytimeValue or 0

local function getParam(url, key)
    local v = url:match('[?&]' .. key .. '=([^&]*)')
    return v
end

onPlayerLeaveWorldCallback(function(world, player)
    local pTime = player:getPlaytime()
    if pTime > _G.HighestPlaytimeValue then
        _G.HighestPlaytimeValue = pTime
        _G.HighestPlaytimeName = player:getCleanName()
    end
end)

onHTTPRequest(function(req)

    local fullPath = req.path
    local path = fullPath:match("([^?]+)") or fullPath
    
    local responseHeaders = {
        ["Content-Type"] = "application/json"
    }

    if path == "/status" then
        local count = #getServerPlayers()
        local uptimeSeconds = os.time() - _G.serverStartTime
        local hours = math.floor(uptimeSeconds / 3600)
        local minutes = math.floor((uptimeSeconds % 3600) / 60)
        local seconds = math.floor(uptimeSeconds % 60)
        local uptimeString = hours .. "h " .. minutes .. "m " .. seconds .. "s"

        return {
            status = 200,
            body = '{"server_status": "online", "players_online": '..count..', "record_online": 0, "uptime": "'..uptimeString..'"}',
            headers = responseHeaders
        }
    end

    if path == "/eventactive" then
        local eventID = 0
        local eventName = "No Active Event"
        if type(getServerCurrentEvent) == "function" then eventID = getServerCurrentEvent() end
        if type(getCurrentEventDescription) == "function" then eventName = getCurrentEventDescription() end
        local cleanEventName = eventName:gsub("`.", "")

        return {
            status = 200,
            body = '{"event_id": '..eventID..', "event_name": "'..cleanEventName..'"}',
            headers = responseHeaders
        }
    end

    if path == "/topworlds" then
        local topWorld = "None"
        local visitorCount = 0
        local worldObj = getTopWorldByVisitors()
        if worldObj then
            topWorld = worldObj:getName()
            visitorCount = worldObj:getPlayersCount(1)
        end

        return {
            status = 200,
            body = '{"top_world_name": "'..topWorld..'", "current_visitors": '..visitorCount..'}',
            headers = responseHeaders
        }
    end

    if path == "/toprich" then
        local allAccounts = getAllPlayers()
        local dataList = {}

        for i = 1, #allAccounts do
            local p = allAccounts[i]
            local name = p:getCleanName() or "Unknown"
            local wl = p:getItemAmount(242)
            local dl = p:getItemAmount(1796)
            local bgl = p:getItemAmount(7188)
            local blgl = p:getItemAmount(20628)
            
            table.insert(dataList, string.format(
                '{"name": "%s", "world_lock": %d, "diamond_lock": %d, "blue_gem_lock": %d, "black_gem_lock": %d}',
                name, wl, dl, bgl, blgl
            ))
        end

        return {
            status = 200,
            body = '{"players": [' .. table.concat(dataList, ",") .. ']}',
            headers = responseHeaders
        }
    end

    if path == "/topgrowth" then
        local currentTopName = _G.HighestPlaytimeName
        local currentTopVal = _G.HighestPlaytimeValue

        local onlinePlayers = getServerPlayers()
        for i = 1, #onlinePlayers do
            local p = onlinePlayers[i]
            local pTime = p:getPlaytime()
            if pTime > currentTopVal then
                currentTopVal = pTime
                currentTopName = p:getCleanName()
            end
        end

        return {
            status = 200,
            body = '{"player_name": "'..currentTopName..'", "hours_played": '..math.floor(currentTopVal / 3600)..'}',
            headers = responseHeaders
        }
    end

    if path == "/servereconomy" then
        local totalAcc = #getAllPlayers()
        return {
            status = 200,
            body = '{"total_accounts": '..totalAcc..'}',
            headers = responseHeaders
        }
    end

    if path == "/checkallaccounts" then
        local allAccounts = getAllPlayers()
        local allData = {}

        for i = 1, #allAccounts do
            local p = allAccounts[i]
            if p then
                local invItems = {}

                for itemId = 1, 30000 do
                    local amt = p:getItemAmount(itemId)
                    if type(amt) == "number" and amt > 0 then
                        local itemInfo = getItem(itemId)
                        local itemName = itemInfo and itemInfo:getName() or "Unknown Item"
                        table.insert(invItems, string.format(
                            '{"id": %d, "name": "%s", "amount": %d}', 
                            itemId, itemName:gsub('"', '\\"'), amt
                        ))
                    end
                end

                local name = tostring(p:getCleanName() or "Unknown")
                local level = tonumber(p:getLevel()) or 0
                local gems = tonumber(p:getGems()) or 0
                local status = p:getOnlineStatus() and "Online" or "Offline"

                local rId = 0
                local rName = "player"

                if p:hasRole(51) then rId = 51; rName = "Developer Role"
                elseif p:hasRole(8) then rId = 8; rName = "Provider"
                elseif p:hasRole(7) then rId = 7; rName = "STAFF UNLI"
                elseif p:hasRole(6) then rId = 6; rName = "STAFF"
                elseif p:hasRole(4) then rId = 4; rName = "Admin Role"
                elseif p:hasRole(3) then rId = 3; rName = "Moderator Role"
                elseif p:hasRole(2) then rId = 2; rName = "Change Nick"
                elseif rId == 1 or p:hasRole(1) then rId = 1; rName = "VIP Role"
                else

                    local rawRole = p:getRole()
                    if type(rawRole) == "table" then
                        rId = tonumber(rawRole.id) or tonumber(rawRole.level) or 0
                    else
                        rId = tonumber(rawRole) or 0
                    end

                end

                table.insert(allData, string.format(
                    '{"name": "%s", "status": "%s", "level": %d, "gems": %d, "role_id": %d, "role_name": "%s", "inventory": [%s]}',
                    name, status, level, gems, rId, rName, table.concat(invItems, ",")
                ))
            end
        end

        return {
            status = 200,
            body = '{"total_accounts": '..#allAccounts..', "data": [' .. table.concat(allData, ",") .. ']}',
            headers = responseHeaders
        }
    end

    if path == "/playerachievements" then
        local allPlayers = getAllPlayers()
        local achievementData = {}

        for i = 1, #allPlayers do
            local p = allPlayers[i]

            if p and p.getUnlockedAchievementsCount then
                local unlocked = p:getUnlockedAchievementsCount() or 0
                local totalPossible = 0

                if p.getAchievementsCount then
                    totalPossible = p:getAchievementsCount() or 0
                end

                if unlocked > 0 then
                    local isOnline = p:getOnlineStatus() and "Online" or "Offline"
                    
                    table.insert(achievementData, string.format(
                        '{"name": "%s", "unlocked": %d, "total": %d, "status": "%s"}',
                        p:getCleanName(), unlocked, totalPossible, isOnline
                    ))
                end
            end
        end

        table.sort(achievementData, function(a, b)

            return a > b
        end)

        return {
            status = 200,
            body = '{"total_players_tracked": '..#achievementData..', "data": [' .. table.concat(achievementData, ",") .. ']}',
            headers = responseHeaders
        }
    end

    if path == "/gemexp" then
        local gemMult = 1
        local xpMult = 1

        if type(getGemEvent) == "function" then 
            gemMult = getGemEvent() 
        end
        
        if type(getXPEvent) == "function" then 
            xpMult = getXPEvent() 
        end

        return {
            status = 200,
            body = string.format('{"status": "success", "gem_multiplier": %d, "xp_multiplier": %d}', gemMult, xpMult),
            headers = responseHeaders
        }
    end

if path == "/itemcount" then
        local count = 0
        if type(getRealGTItemsCount) == "function" then
            count = getRealGTItemsCount()
        end

        return {
            status = 200,
            body = '{"status": "success", "total_items": ' .. count .. '}',
            headers = responseHeaders
        }
    end

if path == "/alllogs" then
        local allAccounts = getAllPlayers()
        local allLogs = {}

        for i = 1, #allAccounts do
            local p = allAccounts[i]
            
            if p then
                local rawName = p:getCleanName() or ""
                local lowerName = rawName:lower()
                
                -- FILTER KETAT:
                -- 1. Skip kalau Role 51 (Dev)
                -- 2. Skip kalau nama mengandung "_" (biasanya bot atau guest)
                -- 3. Skip kalau nama depannya "newbie"
                -- 4. Skip kalau namanya kosong atau terlalu pendek (belom daftar GrowID)
                
                local isDev = p:hasRole(51)
                local isNewbie = lowerName:find("newbie") ~= nil
                local hasUnderscore = rawName:find("_") ~= nil
                local isRegistered = (rawName ~= "" and #rawName > 2)

                if not isDev and not isNewbie and not hasUnderscore and isRegistered then
                    
                    -- 1. Ambil IP History
                    local ipList = table.concat(p:getIPHistory() or {}, ", ")
                    
                    -- 2. Ambil Alts (Convert userdata ke Nama)
                    local altsTable = p:getAltAccounts() or {}
                    local cleanedAlts = {}
                    
                    for _, alt in ipairs(altsTable) do
                        if type(alt) == "userdata" and alt.getCleanName then
                            table.insert(cleanedAlts, alt:getCleanName())
                        elseif type(alt) == "string" then
                            table.insert(cleanedAlts, alt)
                        end
                    end
                    
                    local altsList = table.concat(cleanedAlts, ", ")
                    local status = p:getOnlineStatus() and "Online" or "Offline"
                    local cleanNameJSON = rawName:gsub('"', '\\"')

                    table.insert(allLogs, string.format(
                        '{"name": "%s", "status": "%s", "ip_history": "%s", "alts": "%s"}',
                        cleanNameJSON, status, ipList, altsList
                    ))
                end
            end
        end

        return {
            status = 200,
            body = '{"total_filtered": '..#allLogs..', "data": [' .. table.concat(allLogs, ",") .. ']}',
            headers = responseHeaders
        }
    end

    if path == "/rolequest" then
        local roleDay = 1
        local roleNames = {
            [1] = "Jack of all Trades Day",
            [2] = "Surgery Day",
            [3] = "Fishing Day",
            [4] = "Farmer Day",
            [5] = "Builder Day",
            [6] = "Chef Day",
            [7] = "Star Captain’s Day"
        }

        if type(getRoleQuestDay) == "function" then
            roleDay = getRoleQuestDay()
        end

        local currentRole = roleNames[roleDay] or "Unknown Day"

        return {
            status = 200,
            body = string.format('{"status": "success", "day_id": %d, "role_name": "%s"}', roleDay, currentRole),
            headers = responseHeaders
        }
    end

    return { status = 404, body = '{"error": "not found"}', headers = responseHeaders }
end)