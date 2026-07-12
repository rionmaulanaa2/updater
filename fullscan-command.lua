print(">> (Loading) Economy Scanner by SecretUser")

-- [Micro-Optimizations] Localizing Global Pointers to avoid _G Hash Lookups
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local math_floor = math.floor
local math_min = math.min
local t_insert = table.insert
local t_sort = table.sort

local CONFIG = {
    ALLOWED_ROLE = 51,
    HIDDEN_ROLES = {51, 52},
    MAX_TOP_HOLDERS = 15,
    MAX_WORLDS_TO_SCAN = 1000,
}

local function formatNum(amount)
    if not amount or amount == 0 then return "0" end
    local formatted = tostring(amount)
    while true do  
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function removeColors(text)
    if not text then return "" end
    return text:gsub("`.", "")
end

local function findItemID(input)
    if tonumber(input) then 
        return tonumber(input) 
    end
    
    local targetName = input:lower()
    if targetName == "gems" or targetName == "gem" then 
        return 112 
    end
    
    local maxCheck = 20000 
    if getItemsCount then 
        local c = getItemsCount()
        if c < maxCheck then maxCheck = c end
    end

    if getItem then
        for i = 1, maxCheck do
            local item = getItem(i)
            if item and item.getName then
                local itemName = item:getName():lower()
                if itemName == targetName or itemName:find(targetName, 1, true) then
                    return i
                end
            end
        end
    end
    
    return nil
end

local function isHiddenRole(player)
    if not player or not player.hasRole then return false end
    
    for _, roleID in ipairs(CONFIG.HIDDEN_ROLES) do
        if player:hasRole(roleID) then
            return true
        end
    end
    return false
end

local function scanPlayers(itemID, isGems)
    local allHolders = {}
    local visibleHolders = {}
    local totalInPlayers = 0
    
    
    local allPlayers = nil
    local method = "none"

    if getAllPlayers then
        allPlayers = getAllPlayers()
        if allPlayers and #allPlayers > 0 then
            method = "getAllPlayers"
        end
    end
    
    if not allPlayers or #allPlayers == 0 then
        if getServerPlayers then
            allPlayers = getServerPlayers()
            if allPlayers and #allPlayers > 0 then
                method = "getServerPlayers"
            end
        end
    end
    
    if not allPlayers or #allPlayers == 0 then
        return visibleHolders, totalInPlayers
    end
    
    local scannedCount = 0
    for _, targetPlayer in ipairs(allPlayers) do
        if targetPlayer then
            scannedCount = scannedCount + 1
            
            local amount = 0
            if isGems then
                if targetPlayer.getGems then
                    amount = targetPlayer:getGems()
                end
            else
                if targetPlayer.getItemAmount then
                    amount = targetPlayer:getItemAmount(itemID)
                end
            end
            if amount > 0 then
                local shouldHide = isHiddenRole(targetPlayer)
                
                if not shouldHide then
                    totalInPlayers = totalInPlayers + amount
                end
                
                local playerName = "Unknown"
                if targetPlayer.getName then
                    playerName = targetPlayer:getRealCleanName()
                end
                
                local userID = 0
                if targetPlayer.getUserID then
                    userID = targetPlayer:getUserID()
                end
                
                local holderData = {
                    name = playerName,
                    userID = userID,
                    amount = amount
                }
                
                table.insert(allHolders, holderData)
                
                local shouldHide = isHiddenRole(targetPlayer)
                if not shouldHide then
                    table.insert(visibleHolders, holderData)
                end
            end
        end
    end
    
    return visibleHolders, totalInPlayers
end

local function scanWorlds(itemID)
    local totalPlaced = 0
    local totalDropped = 0
    local worldsScanned = 0
        
    local activeWorlds = getActiveWorlds()
    if not activeWorlds then
        return totalPlaced, totalDropped, worldsScanned
    end
    
    for _, world in ipairs(activeWorlds) do
        if type(world) == "userdata" and worldsScanned < CONFIG.MAX_WORLDS_TO_SCAN then
            worldsScanned = worldsScanned + 1
            
            local width = world:getWorldSizeX()
            local height = world:getWorldSizeY()
            
            if width and height and width > 0 and height > 0 then
                for x = 0, width - 1 do
                    for y = 0, height - 1 do
                        local tile = world:getTile(x, y)
                        if tile then
                            if tile:getTileForeground() == itemID then 
                                totalPlaced = totalPlaced + 1 
                            end
                            if tile:getTileBackground() == itemID then 
                                totalPlaced = totalPlaced + 1 
                            end
                        end
                    end
                end
            end
            
            local objects = world:getDroppedItems()
            if objects then
                for _, obj in pairs(objects) do
                    if type(obj) == "table" or type(obj) == "userdata" then
                        if obj:getItemID() == itemID then
                            local c = obj:getItemCount()
                            if not c then c = 1 end
                            totalDropped = totalDropped + c
                        end
                    end
                end
            end
        end
    end
    
    return totalPlaced, totalDropped, worldsScanned
end

local function getEconomyData(itemID)
    local totalEconomy = 0
    local inPlayers = 0
    local inWorlds = 0
    
    if getEcoQuantity then
        totalEconomy = getEcoQuantity(itemID) or 0
    end
    
    if getEcoQuantityPlayers then
        inPlayers = getEcoQuantityPlayers(itemID) or 0
    end
    
    if getEcoQuantityWorlds then
        inWorlds = getEcoQuantityWorlds(itemID) or 0
    end
    
    return totalEconomy, inPlayers, inWorlds
end

if registerLuaCommand then
    registerLuaCommand({
        command = "fullscan",
        roleRequired = CONFIG.ALLOWED_ROLE,
        description = "Scans economy fully of the Server."
    })
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = {}
    for word in fullCommand:gmatch("%S+") do 
        table.insert(args, word) 
    end
    
    if #args == 0 then return false end

    local cmd = args[1]:lower()
    if cmd:sub(1, 1) == "/" then cmd = cmd:sub(2) end

    if cmd == "fullscan" then
        if not player.hasRole or not player:hasRole(CONFIG.ALLOWED_ROLE) then
            player:onConsoleMessage("`4Unknown command. `oEnter `$/?`` for a list of valid commands.``")
            return true
        end

        if #args < 2 then
            player:onConsoleMessage("`oUsage: /fullscan <item id or name> - `$(This will fully scan of server economy. You can see Top 15 Holders in game what ever you scanned!)``")
            return true
        end

        local itemInput = table.concat(args, " ", 2)
        local itemID = findItemID(itemInput)

        if not itemID or itemID == 0 then
            player:onConsoleMessage("`oItem not found: " .. itemInput .. "``")
            return true
        end

        local itemName = "Unknown"
        local isGems = (itemID == 112)
        
        if isGems then
            itemName = "Gems"
        else
            local itemDef = getItem(itemID)
            if itemDef and itemDef.getName then
                itemName = itemDef:getName()
            end
        end

        player:onConsoleMessage("`oItem: " .. itemName .. " (ID: " .. itemID .. ")``")
        
        local totalEco, ecoInPlayers, ecoInWorlds = getEconomyData(itemID)
        local holders, scannedPlayerTotal = scanPlayers(itemID, isGems)
        
        local placedCount = 0
        local droppedCount = 0
        local worldsScanned = 0
        
        if not isGems then
            placedCount, droppedCount, worldsScanned = scanWorlds(itemID)
        end
        ecoInPlayers = scannedPlayerTotal
        
        local mathWorlds = totalEco - ecoInPlayers
        if mathWorlds > 0 then
            ecoInWorlds = mathWorlds
        else
            ecoInWorlds = 0
        end

        local manualScanTotal = (placedCount or 0) + (droppedCount or 0)
        if manualScanTotal > ecoInWorlds then
            ecoInWorlds = manualScanTotal
        end

        local totalCalculatedEco = ecoInPlayers + ecoInWorlds
        if totalCalculatedEco > totalEco then
            totalEco = totalCalculatedEco
        end
        
        table.sort(holders, function(a, b) return a.amount > b.amount end)
        
        if totalEco > 0 then
            player:onConsoleMessage("`oTotal: `$" .. formatNum(totalEco) .. "``")
            
            if ecoInPlayers > 0 then
                local playerPercent = math.floor((ecoInPlayers / totalEco) * 100)
                player:onConsoleMessage("`oIn Players: `$" .. formatNum(ecoInPlayers) .. " `o(" .. playerPercent .. "%)``")
            end   
            if ecoInWorlds > 0 then
                local worldPercent = math.floor((ecoInWorlds / totalEco) * 100)
                player:onConsoleMessage("`oIn Worlds: `$" .. formatNum(ecoInWorlds) .. " `o(" .. worldPercent .. "%)``")
            end
        else
            player:onConsoleMessage("`oTotal: `$" .. formatNum(scannedPlayerTotal) .. "``")
            if scannedPlayerTotal > 0 then
                 player:onConsoleMessage("`oIn Players: `$" .. formatNum(scannedPlayerTotal) .. " `o(100%)``")
            end
        end
        
        if not isGems then
            player:onConsoleMessage("`oWorlds Scanned: `$" .. worldsScanned .. "``")
            player:onConsoleMessage("`oIn Worlds Total: `$" .. formatNum(ecoInWorlds) .. "``")
            
            player:onConsoleMessage("`oPlaced Blocks (scanned): `$" .. formatNum(placedCount or 0) .. "``")
            player:onConsoleMessage("`oDropped Items (scanned): `$" .. formatNum(droppedCount or 0) .. "``")
        end
        
        local totalPlayers = getAllPlayers() and #getAllPlayers() or 0
        player:onConsoleMessage("`oTotal Accounts: `$" .. totalPlayers .. "``")
        
        if #holders > 0 then
            player:onConsoleMessage("")
            player:onConsoleMessage("`oTop 15 Leaderboard``")
            for i = 1, math.min(CONFIG.MAX_TOP_HOLDERS, #holders) do
                local h = holders[i]
                player:onConsoleMessage("`o#" .. i .. " `w" .. h.name .. "`o: `$" .. formatNum(h.amount) .. "``")
            end
        else
            player:onConsoleMessage("`oNo holders found.``")
        end
        
        return true
    end
    
    return false
end)