-- Expired Locks System
local EXPIRED_LOCKS_DB = "expired_locks.db"
local CONFIG_FILE = "./config/expired_locks.json"
local db = sqlite.open(EXPIRED_LOCKS_DB)

db:query([[
    CREATE TABLE IF NOT EXISTS players (
        userid INTEGER PRIMARY KEY,
        last_online INTEGER,
        role INTEGER
    );
]])

db:query([[
    CREATE TABLE IF NOT EXISTS locks (
        world TEXT,
        x INTEGER,
        y INTEGER,
        owner_id INTEGER,
        lock_type INTEGER,
        PRIMARY KEY (world, x, y)
    );
]])

local config = {
    enabled = false,
    seconds_needed = 15552000, -- Default: 180 days in seconds
    affected_roles = {}, -- Array of role IDs whose locks CAN expire (empty means all except developers maybe? No, let's just make it a whitelist of roles that are affected)
    affected_locks = {202, 204, 206, 242}
}

local function saveConfig()
    local content = json.encode(config)
    file.write(CONFIG_FILE, content)
end

local function loadConfig()
    if file.exists(CONFIG_FILE) then
        local content = file.read(CONFIG_FILE)
        if content and content ~= "" then
            config = json.decode(content)
            -- Migrate old config
            if config.days_needed then
                config.seconds_needed = config.days_needed * 86400
                config.days_needed = nil
                saveConfig()
            end
        end
    else
        saveConfig()
    end
end

-- Initialize
loadConfig()

local function isLockAffected(itemID)
    for _, id in pairs(config.affected_locks) do
        if tonumber(id) == tonumber(itemID) then return true end
    end
    return false
end

local function isRoleAffected(playerRoles)
    if #config.affected_roles == 0 then return true end -- If empty, all roles affected
    
    if type(playerRoles) == "table" then
        for _, pRole in pairs(playerRoles) do
            for _, id in pairs(config.affected_roles) do
                if tonumber(id) == tonumber(pRole) then return true end
            end
        end
        return false
    end
    
    for _, id in pairs(config.affected_roles) do
        if tonumber(id) == tonumber(playerRoles) then return true end
    end
    return false
end

local function updatePlayerOnline(player)
    if not player then return end
    local userid = player:getUserID()
    local role = player:getRole()
    local roleStr = ""
    
    if type(role) == "table" then
        roleStr = json.encode(role)
    else
        roleStr = tostring(role)
    end
    
    local now = os.time()
    
    local stmt = string.format("INSERT OR REPLACE INTO players (userid, last_online, role) VALUES (%d, %d, '%s')", userid, now, roleStr)
    db:query(stmt)
end

onPlayerLoginCallback(function(player)
    updatePlayerOnline(player)
end)

onPlayerDisconnectCallback(function(player)
    updatePlayerOnline(player)
end)

onTilePlacedCallback(function(world, player, tile)
    if not world or not player or not tile then return end
    local bg = tile:getTileBackground()
    local fg = tile:getTileForeground()
    
    if isLockAffected(fg) or isLockAffected(bg) then
        local lock_type = fg
        if isLockAffected(bg) then lock_type = bg end
        
        local worldName = world:getName()
        local x = tile:getPosX()
        local y = tile:getPosY()
        local userid = player:getUserID()
        
        local stmt = string.format("INSERT OR REPLACE INTO locks (world, x, y, owner_id, lock_type) VALUES ('%s', %d, %d, %d, %d)", worldName, x, y, userid, lock_type)
        db:query(stmt)
    end
end)

onTileBreakCallback(function(world, player, tile)
    if not world or not tile then return end
    local bg = tile:getTileBackground()
    local fg = tile:getTileForeground()
    
    if isLockAffected(fg) or isLockAffected(bg) then
        local worldName = world:getName()
        local x = tile:getPosX()
        local y = tile:getPosY()
        
        local stmt = string.format("DELETE FROM locks WHERE world = '%s' AND x = %d AND y = %d", worldName, x, y)
        db:query(stmt)
    end
end)

onPlayerPunchCallback(function(world, player, x, y)
    if not config.enabled then return end
    if not world or not player then return end
    
    local tile = world:getTile(x, y)
    if not tile then return end
    
    local fg = tile:getTileForeground()
    if isLockAffected(fg) then
        local worldName = world:getName()
        
        -- Try to get owner from DB
        local stmt = string.format("SELECT owner_id FROM locks WHERE world = '%s' AND x = %d AND y = %d", worldName, x, y)
        local result = db:query(stmt)
        
        local ownerID = nil
        if result and #result > 0 then
            ownerID = tonumber(result[1].owner_id)
        end
        
        -- Fallback to World Owner for World Lock, or if not in DB
        if not ownerID then
            local wOwner = world:getOwner()
            if wOwner and tonumber(wOwner) > 0 then
                ownerID = tonumber(wOwner)
            end
        end
        
        if ownerID then
            -- Get owner's last online and role
            local pStmt = string.format("SELECT last_online, role FROM players WHERE userid = %d", ownerID)
            local pResult = db:query(pStmt)
            
            if pResult and #pResult > 0 then
                local lastOnline = tonumber(pResult[1].last_online) or 0
                local roleStr = pResult[1].role or "1"
                local role = roleStr
                
                if type(roleStr) == "string" and roleStr:sub(1,1) == "[" then
                    role = json.decode(roleStr)
                end
                
                if isRoleAffected(role) then
                    local now = os.time()
                    local secondsOffline = now - lastOnline
                    
                    if secondsOffline >= config.seconds_needed then
                        -- Lock is expired! Destroy it!
                        player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4[Expired Locks] `wThis lock has expired and has been destroyed!"})
                        world:setTileForeground(x, y, 0)
                        
                        -- Spawn the lock item so they can pick it up or it drops
                        world:spawnItem(fg, x, y, 1)
                        world:onCreateExplosion(x, y, 1)
                        player:playAudio("explode.wav")
                        
                        -- Clean up DB
                        local dStmt = string.format("DELETE FROM locks WHERE world = '%s' AND x = %d AND y = %d", worldName, x, y)
                        db:query(dStmt)
                    end
                end
            end
        end
    end
end)

-- UI Command
onPlayerCommandCallback(function(world, player, command)
    local cmd = command:match("^(%S+)")
    if not cmd then return false end
    if cmd:lower() == "expiredlocks" then
        if not player:hasRole(51) then
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`4You don't have permission to use this command."})
            return true
        end
        
        local dialog = "set_default_color|`o\nadd_label_with_icon|big|`wExpired Locks System``|left|242|\nadd_spacer|small|\n"
        
        if config.enabled then
            dialog = dialog .. "add_button|toggle_expired_locks|`2Enabled`w (Click to Disable)|\n"
        else
            dialog = dialog .. "add_button|toggle_expired_locks|`4Disabled`w (Click to Enable)|\n"
        end
        
        dialog = dialog .. "add_text_input|seconds_needed|Seconds Needed:|" .. tostring(config.seconds_needed) .. "|10|\n"
        dialog = dialog .. "add_text_input|affected_roles|Affected Roles (Comma sep):|" .. table.concat(config.affected_roles, ",") .. "|30|\n"
        dialog = dialog .. "add_text_input|affected_locks|Affected Locks (Comma sep):|" .. table.concat(config.affected_locks, ",") .. "|30|\n"
        
        dialog = dialog .. "add_spacer|small|\nadd_button|save_expired_locks|`wSave Settings|\n"
        dialog = dialog .. "end_dialog|expired_locks_menu|Close||\nadd_quick_exit|\n"
        
        player:onDialogRequest(dialog)
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    local buttonName = data["buttonClicked"] or ""

    if dialogName == "expired_locks_menu" then
        if buttonName == "toggle_expired_locks" then
            config.enabled = not config.enabled
            saveConfig()
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`oExpired Locks System is now " .. (config.enabled and "`2Enabled" or "`4Disabled")})
            -- Re-open dialog
            player:doRawPacket(2, "action|input\n|text|/expiredlocks")
            return true
        elseif buttonName == "save_expired_locks" then
            if data["seconds_needed"] then
                config.seconds_needed = tonumber(data["seconds_needed"]) or config.seconds_needed
            end
            
            if data["affected_roles"] then
                local roles = {}
                for r in string.gmatch(data["affected_roles"], "%d+") do
                    table.insert(roles, tonumber(r))
                end
                config.affected_roles = roles
            end
            
            if data["affected_locks"] then
                local locks = {}
                for l in string.gmatch(data["affected_locks"], "%d+") do
                    table.insert(locks, tonumber(l))
                end
                config.affected_locks = locks
            end
            
            saveConfig()
            player:sendVariant({v0 = "OnConsoleMessage", v1 = "`oExpired Locks System settings saved!"})
            return true
        end
    end
    return false
end)

print("Loaded Expired Locks System")
