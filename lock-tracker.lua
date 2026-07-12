-- Anti-Duplication Lock Tracker
local CONFIG_FILE = "./config/locks_pool.json"
local LOCK_IDS = {242, 1796, 7188, 20628} -- WL, DL, BGL, BlackGL

local online_players = {}

local pool_data = {
    max_pools = {
        ["242"] = 1000000000,
        ["1796"] = 10000000,
        ["7188"] = 100000,
        ["20628"] = 1000
    },
    current_pools = {
        ["242"] = 0,
        ["1796"] = 0,
        ["7188"] = 0,
        ["20628"] = 0
    },
    tracking = {
        ["242"] = {},
        ["1796"] = {},
        ["7188"] = {},
        ["20628"] = {}
    }
}

local function savePoolConfig()
    local content = json.encode(pool_data)
    file.write(CONFIG_FILE, content)
end

local function loadPoolConfig()
    if file.exists(CONFIG_FILE) then
        local content = file.read(CONFIG_FILE)
        if content and content ~= "" then
            pool_data = json.decode(content)
        end
    else
        savePoolConfig()
    end
end

loadPoolConfig()

local function startAuditLoop()
    if _G.audit_timer_id then
        timer.clear(_G.audit_timer_id)
        _G.audit_timer_id = nil
    end
    local interval = pool_data.audit_interval or 60
    if interval > 0 then
        _G.audit_timer_id = timer.setInterval(interval, function()
            for uid, p in pairs(online_players) do
                if p then _G.auditPlayerInventory(p) end
            end
        end)
    end
end
startAuditLoop()

local function isTrackedLock(itemID)
    for _, id in pairs(LOCK_IDS) do
        if tonumber(id) == tonumber(itemID) then return true end
    end
    return false
end

local function recalculateGlobalPools()
    for _, id in pairs(LOCK_IDS) do
        local strId = tostring(id)
        local total = 0
        if pool_data.tracking[strId] then
            for loc, amount in pairs(pool_data.tracking[strId]) do
                total = total + amount
            end
        end
        pool_data.current_pools[strId] = total
    end
    savePoolConfig()
end

local function trackItemLocation(itemID, locationKey, amount)
    local strId = tostring(itemID)
    if not pool_data.tracking[strId] then pool_data.tracking[strId] = {} end
    
    -- Ensure we don't drop below 0
    if not pool_data.tracking[strId][locationKey] then
        pool_data.tracking[strId][locationKey] = 0
    end
    
    local old_amount = pool_data.tracking[strId][locationKey]
    pool_data.tracking[strId][locationKey] = amount
    
    -- If amount is 0, clean up
    if pool_data.tracking[strId][locationKey] <= 0 then
        pool_data.tracking[strId][locationKey] = nil
    end
    
    recalculateGlobalPools()
end

local function auditPlayerInventory(player)
    if not player then return end
    local playerName = player:getName()
    local inventoryKey = "Inventory:" .. playerName
    
    for _, lockId in pairs(LOCK_IDS) do
        local strId = tostring(lockId)
        
        -- Safe Initialization
        if type(pool_data.tracking) ~= "table" then pool_data.tracking = {} end
        if type(pool_data.current_pools) ~= "table" then pool_data.current_pools = {} end
        if type(pool_data.max_pools) ~= "table" then pool_data.max_pools = {} end
        
        if not pool_data.tracking[strId] then pool_data.tracking[strId] = {} end
        if not pool_data.current_pools[strId] then pool_data.current_pools[strId] = 0 end
        if not pool_data.max_pools[strId] then pool_data.max_pools[strId] = 0 end
        
        local amount = player:getItemAmount(lockId)
        if not amount or amount == 0 then
            -- Fallback to checking backpack if getItemAmount fails
            if type(player.getItemAmountBackpack) == "function" then
                amount = player:getItemAmountBackpack(lockId) or 0
            else
                amount = 0
            end
        end
        
        -- Check if enforcing max limits
        if amount > 0 then
            local currentTotal = pool_data.current_pools[strId] or 0
            local maxAllowed = pool_data.max_pools[strId] or 0
            local previouslyTracked = pool_data.tracking[strId][inventoryKey] or 0
            
            local newAddition = amount - previouslyTracked
            
            if newAddition > 0 and maxAllowed > 0 and (currentTotal + newAddition) > maxAllowed then
                -- Pool limit reached! Revert the excess items.
                local excess = (currentTotal + newAddition) - maxAllowed
                if excess > amount then excess = amount end -- safety
                
                player:changeItem(lockId, -excess, 0)
                amount = amount - excess
                
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4[Anti-Dupe] `wGlobal pool limit reached for lock ID " .. lockId .. ". Excess removed."})
            end
        end
        
        trackItemLocation(lockId, inventoryKey, amount)
    end
end
_G.auditPlayerInventory = auditPlayerInventory

onPlayerLoginCallback(function(player)
    if player and player:getUserID() then
        online_players[player:getUserID()] = player
    end
    auditPlayerInventory(player)
end)

onPlayerDisconnectCallback(function(player)
    auditPlayerInventory(player)
    if player and player:getUserID() then
        online_players[player:getUserID()] = nil
    end
end)

if onPlayerTrashItemCallback then
    onPlayerTrashItemCallback(function(player, itemID, amount)
        if player then auditPlayerInventory(player) end
    end)
end

onTilePlacedCallback(function(world, player, tile)
    if not world or not player or not tile then return end
    
    local fg = tile:getTileForeground()
    local bg = tile:getTileBackground()
    
    local lock_type = nil
    if isTrackedLock(fg) then lock_type = fg end
    if isTrackedLock(bg) then lock_type = bg end
    
    if lock_type then
        local worldName = world:getName()
        local worldKey = "World:" .. worldName
        
        local current = 0
        if pool_data.tracking[tostring(lock_type)] and pool_data.tracking[tostring(lock_type)][worldKey] then
            current = pool_data.tracking[tostring(lock_type)][worldKey]
        end
        
        trackItemLocation(lock_type, worldKey, current + 1)
        
        -- Also audit player since they placed it from inventory
        auditPlayerInventory(player)
    end
end)

onTileBreakCallback(function(world, player, tile)
    if not world or not player or not tile then return end
    
    local fg = tile:getTileForeground()
    local bg = tile:getTileBackground()
    
    local lock_type = nil
    if isTrackedLock(fg) then lock_type = fg end
    if isTrackedLock(bg) then lock_type = bg end
    
    if lock_type then
        local worldName = world:getName()
        local worldKey = "World:" .. worldName
        
        local current = 0
        if pool_data.tracking[tostring(lock_type)] and pool_data.tracking[tostring(lock_type)][worldKey] then
            current = pool_data.tracking[tostring(lock_type)][worldKey]
        end
        
        if current > 0 then
            trackItemLocation(lock_type, worldKey, current - 1)
        end
        
        -- Audit player since they likely picked it up
        auditPlayerInventory(player)
    end
end)

local function buildTrackListDialog(lockId, lockName)
    local dialog = "set_default_color|`o\nadd_label_with_icon|big|`w" .. lockName .. " Track List``|left|" .. lockId .. "|\nadd_spacer|small|\n"
    local trackingTable = pool_data.tracking[tostring(lockId)] or {}
    
    local sortedList = {}
    for loc, amount in pairs(trackingTable) do
        table.insert(sortedList, {loc = loc, amount = amount})
    end
    table.sort(sortedList, function(a, b) return a.amount > b.amount end)
    
    local limit = 50
    for i, entry in ipairs(sortedList) do
        if i > limit then break end
        dialog = dialog .. "add_label_with_icon|small|`o" .. entry.loc .. " `w: " .. entry.amount .. "``|left|18|\n"
    end
    
    if #sortedList == 0 then
        dialog = dialog .. "add_label_with_icon|small|`oNo data found.``|left|18|\n"
    end
    
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|back_lock_main|`wBack|\n"
    dialog = dialog .. "end_dialog|lock_tracker_list|Close||\nadd_quick_exit|\n"
    return dialog
end

local function buildMainDialog()
    local dialog = "set_default_color|`o\nadd_label_with_icon|big|`wAnti-Dupe Lock Tracker``|left|20628|\nadd_spacer|small|\n"
    
    local lockNames = {["242"] = "World Lock", ["1796"] = "Diamond Lock", ["7188"] = "Blue Gem Lock", ["20628"] = "Black Gem Lock"}
    
    for _, id in ipairs(LOCK_IDS) do
        local strId = tostring(id)
        local current = pool_data.current_pools[strId] or 0
        local max = pool_data.max_pools[strId] or 0
        local name = lockNames[strId] or "Unknown"
        
        dialog = dialog .. "add_label_with_icon|small|`w" .. name .. " Pool: `2" .. current .. "`w / " .. max .. "``|left|" .. strId .. "|\n"
        dialog = dialog .. "add_button|track_" .. strId .. "|`wView " .. name .. " Track List|\n"
    end
    
    dialog = dialog .. "add_label_with_icon|small|`wAudit Loop Interval: `2" .. (pool_data.audit_interval or 60) .. " seconds``|left|32|\n"
    dialog = dialog .. "add_button|change_audit|`wChange Audit Time|\n"
    
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "end_dialog|lock_tracker_main|Close||\nadd_quick_exit|\n"
    return dialog
end

local function buildAuditConfigDialog()
    local dialog = "set_default_color|`o\nadd_label_with_icon|big|`wAudit Configuration``|left|32|\nadd_spacer|small|\n"
    dialog = dialog .. "add_text_input|audit_time|Interval (seconds):|" .. (pool_data.audit_interval or 60) .. "|5|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|save_audit|`wSave Interval|\n"
    dialog = dialog .. "add_button|back_lock_main|`wBack|\n"
    dialog = dialog .. "end_dialog|lock_tracker_config|Close||\nadd_quick_exit|\n"
    return dialog
end

onPlayerCommandCallback(function(world, player, command)
    local cmd = command:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == "lockaudit" then
        if not player:hasRole(51) then return true end
        auditPlayerInventory(player)
        player:sendVariant({v0 = "OnConsoleMessage", v1 = "`2Inventory Audited manually!"})
        return true
    end
    
    if cmd:lower() == "locktrack" then
        if not player:hasRole(51) then
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4No permission."})
            return true
        end
        player:onDialogRequest(buildMainDialog())
        return true
    end
    
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    local buttonName = data["buttonClicked"] or ""

    if dialogName == "lock_tracker_main" or dialogName == "lock_tracker_list" or dialogName == "lock_tracker_config" then
        if not player:hasRole(51) then return false end
        
        if buttonName == "back_lock_main" then
            player:onDialogRequest(buildMainDialog())
            return true
        elseif buttonName == "change_audit" then
            player:onDialogRequest(buildAuditConfigDialog())
            return true
        elseif buttonName == "save_audit" then
            local newTime = tonumber(data["audit_time"])
            if newTime and newTime >= 5 then
                pool_data.audit_interval = newTime
                savePoolConfig()
                startAuditLoop()
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`2Audit interval updated to " .. newTime .. " seconds!"})
            else
                player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4Invalid interval. Must be at least 5 seconds."})
            end
            player:onDialogRequest(buildMainDialog())
            return true
        elseif buttonName:sub(1, 6) == "track_" then
            local lockIdStr = buttonName:sub(7)
            local lockNames = {["242"] = "World Lock", ["1796"] = "Diamond Lock", ["7188"] = "Blue Gem Lock", ["20628"] = "Black Gem Lock"}
            local name = lockNames[lockIdStr] or "Lock"
            player:onDialogRequest(buildTrackListDialog(lockIdStr, name))
            return true
        end
    end
    return false
end)

print("Loaded Anti-Duplication Lock Tracker")
