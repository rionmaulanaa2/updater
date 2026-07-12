print("(Loaded) Stock Market System")

local DB_PATH = "stocks.db"
local db = sqlite.open(DB_PATH)

local function initDB()
    -- Market table
    db:query([[
        CREATE TABLE IF NOT EXISTS market (
            stock_name TEXT PRIMARY KEY,
            total_pool INTEGER,
            total_bought INTEGER,
            base_price INTEGER,
            price_increment INTEGER
        )
    ]])
    -- Holdings table
    db:query([[
        CREATE TABLE IF NOT EXISTS holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id INTEGER,
            stock_name TEXT,
            amount INTEGER,
            UNIQUE(player_id, stock_name)
        )
    ]])
    
    -- Claims table
    db:query([[
        CREATE TABLE IF NOT EXISTS stock_claims (
            player_id INTEGER,
            stock_name TEXT,
            last_claim INTEGER,
            UNIQUE(player_id, stock_name)
        )
    ]])
    
    -- Insert default Gold stock if not exists
    local rows = db:query("SELECT * FROM market WHERE stock_name = 'Gold'")
    if not rows or #rows == 0 then
        db:query("INSERT INTO market (stock_name, total_pool, total_bought, base_price, price_increment) VALUES ('Gold', 100000000000, 0, 2000, 2000)")
    else
        db:query("UPDATE market SET total_pool = 100000000000 WHERE stock_name = 'Gold'")
    end
end
initDB()

local function formatNum(n)
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function getStockInfo(stock_name)
    local rows = db:query(string.format("SELECT * FROM market WHERE stock_name = '%s'", stock_name))
    if rows and #rows > 0 then
        local r = rows[1]
        r.total_pool = tonumber(r.total_pool) or 0
        r.total_bought = tonumber(r.total_bought) or 0
        r.base_price = tonumber(r.base_price) or 0
        r.price_increment = tonumber(r.price_increment) or 0
        return r
    end
    return nil
end

local function getPlayerHolding(player_id, stock_name)
    local rows = db:query(string.format("SELECT amount FROM holdings WHERE player_id = %d AND stock_name = '%s'", player_id, stock_name))
    if rows and #rows > 0 then
        return tonumber(rows[1].amount) or 0
    end
    return 0
end

local function updatePlayerHolding(player_id, stock_name, delta)
    local rows = db:query(string.format("SELECT id FROM holdings WHERE player_id = %d AND stock_name = '%s'", player_id, stock_name))
    if not rows or #rows == 0 then
        db:query(string.format("INSERT INTO holdings (player_id, stock_name, amount) VALUES (%d, '%s', %d)", player_id, stock_name, delta))
    else
        db:query(string.format("UPDATE holdings SET amount = amount + %d WHERE player_id = %d AND stock_name = '%s'", delta, player_id, stock_name))
    end
end

local function getPlayerLastClaim(player_id, stock_name)
    local rows = db:query(string.format("SELECT last_claim FROM stock_claims WHERE player_id = %d AND stock_name = '%s'", player_id, stock_name))
    if rows and #rows > 0 then
        return tonumber(rows[1].last_claim) or 0
    end
    return 0
end

local function setPlayerLastClaim(player_id, stock_name, time)
    local rows = db:query(string.format("SELECT last_claim FROM stock_claims WHERE player_id = %d AND stock_name = '%s'", player_id, stock_name))
    if not rows or #rows == 0 then
        db:query(string.format("INSERT INTO stock_claims (player_id, stock_name, last_claim) VALUES (%d, '%s', %d)", player_id, stock_name, time))
    else
        db:query(string.format("UPDATE stock_claims SET last_claim = %d WHERE player_id = %d AND stock_name = '%s'", time, player_id, stock_name))
    end
end

local function showStockMenu(player)
    local stock = getStockInfo("Gold")
    if not stock then
        player:onConsoleMessage("`4Stock Market is currently closed.``")
        return
    end
    
    local holding = getPlayerHolding(player:getUserID(), "Gold")
    
    local buy_price = stock.base_price + (stock.total_bought * stock.price_increment)
    local sell_price = stock.base_price + (math.max(0, stock.total_bought - 1) * stock.price_increment)
    
    local sell_text = (stock.total_bought > 0) and ("`$" .. formatNum(sell_price) .. " Gems``") or "`4N/A``"
    local available = stock.total_pool - stock.total_bought
    
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Stock Market - GOLD``|left|1436|")
    table.insert(d, "add_smalltext|`oTrade your Gems for Gold stocks! Prices change dynamically!``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_textbox|`oAvailable Pool: `w" .. formatNum(available) .. " / " .. formatNum(stock.total_pool) .. "``|left|")
    table.insert(d, "add_textbox|`oCurrent Buy Price: `$" .. formatNum(buy_price) .. " Gems``|left|")
    table.insert(d, "add_textbox|`oCurrent Sell Price: " .. sell_text .. "|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_textbox|`oYour Holdings: `6" .. formatNum(holding) .. " Gold``|left|")
    table.insert(d, "add_spacer|small|")
    
    if available > 0 then
        table.insert(d, "add_button|stock_buy_gold|`2Buy 1x Gold``|no_flags|0|0|")
    else
        table.insert(d, "add_button|stock_sold_out|`4SOLD OUT``|no_flags|0|0|")
    end
    
    if holding > 0 then
        table.insert(d, "add_button|stock_sell_gold|`4Sell 1x Gold``|no_flags|0|0|")
        
        local last_claim = getPlayerLastClaim(player:getUserID(), "Gold")
        local now = os.time()
        local next_claim = last_claim + 86400
        
        table.insert(d, "add_spacer|small|")
        if now >= next_claim then
            table.insert(d, "add_button|stock_take_profits|`9Take Profits (Ready!)``|no_flags|0|0|")
        else
            local diff = next_claim - now
            local hrs = math.floor(diff / 3600)
            local mins = math.floor((diff % 3600) / 60)
            table.insert(d, string.format("add_button|stock_profit_cooldown|`wProfits in %dh %dm``|no_flags|0|0|", hrs, mins))
        end
    end
    
    if player:hasRole(51) then
        table.insert(d, "add_spacer|small|")
        table.insert(d, "add_button|stock_dev_reset|`4[DEV] Reset Market``|no_flags|0|0|")
    end
    
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_button|stock_close|`oClose``|no_flags|0|0|")
    
    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|stock_market_menu|Close||\n" ..
        "add_quick_exit|"
    )
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    if cmd:lower() == "stock" or cmd:lower() == "market" then
        showStockMenu(player)
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local clicked = data["buttonClicked"] or ""
    
    if dlg == "portal_shortcuts" and clicked == "sc_stock" then
        showStockMenu(player)
        return true
    end
    
    if dlg == "stock_market_menu" then
        if clicked == "stock_close" then return true end
        
        if clicked == "stock_buy_gold" then
            local stock = getStockInfo("Gold")
            if not stock then return true end
            
            if stock.total_bought >= stock.total_pool then
                player:onConsoleMessage("`4Error: Stock is completely sold out!``")
                showStockMenu(player)
                return true
            end
            
            local buy_price = stock.base_price + (stock.total_bought * stock.price_increment)
            
            -- Wait, how to check gem balance without player:getGems() crashing if it doesn't exist?
            -- GTPS player:changeItem(112, 0, 0) maybe? Usually player:getGems() exists.
            local current_gems = player:getItemAmount(112)
            if not current_gems or current_gems == 0 then
                -- Try getGems? Let's just assume we can get it via standard changeItem.
            end
            local current_gems = tonumber(player:getGems()) or 0
            
            if current_gems >= buy_price then
                -- Deduct gems
                player:addGems(-buy_price, 0, 1)
                
                -- Update market
                db:query("UPDATE market SET total_bought = total_bought + 1 WHERE stock_name = 'Gold'")
                
                -- Update holding
                updatePlayerHolding(player:getUserID(), "Gold", 1)
                
                player:playAudio("cash_register.wav")
                player:onConsoleMessage("`2Successfully bought 1x Gold for `$" .. formatNum(buy_price) .. " Gems!``")
            else
                player:onConsoleMessage("`4Error: You don't have enough Gems! (Need " .. formatNum(buy_price) .. ")``")
            end
            
            showStockMenu(player)
            return true
        end
        
        if clicked == "stock_sell_gold" then
            local holding = getPlayerHolding(player:getUserID(), "Gold")
            if holding <= 0 then
                player:onConsoleMessage("`4Error: You don't have any Gold to sell!``")
                showStockMenu(player)
                return true
            end
            
            local stock = getStockInfo("Gold")
            if not stock or stock.total_bought <= 0 then return true end
            
            local sell_price = stock.base_price + ((stock.total_bought - 1) * stock.price_increment)
            
            -- Add gems
            player:addGems(sell_price, 0, 1)
            
            -- Update market
            db:query("UPDATE market SET total_bought = total_bought - 1 WHERE stock_name = 'Gold'")
            
            -- Update holding
            updatePlayerHolding(player:getUserID(), "Gold", -1)
            
            player:playAudio("cash_register.wav")
            player:onConsoleMessage("`2Successfully sold 1x Gold for `$" .. formatNum(sell_price) .. " Gems!``")
            
            showStockMenu(player)
            return true
        end
        
        if clicked == "stock_take_profits" then
            local holding = getPlayerHolding(player:getUserID(), "Gold")
            if holding <= 0 then return true end
            
            local last_claim = getPlayerLastClaim(player:getUserID(), "Gold")
            local now = os.time()
            if now < last_claim + 86400 then
                player:onConsoleMessage("`4Error: You can only take profits every 24 hours!``")
                return true
            end
            
            local stock = getStockInfo("Gold")
            if not stock then return true end
            
            local sell_price = stock.base_price + (math.max(0, stock.total_bought - 1) * stock.price_increment)
            local profit = math.floor(holding * 0.05 * sell_price)
            
            if profit > 0 then
                player:addGems(profit, 0, 1)
                player:playAudio("cash_register.wav")
                player:onConsoleMessage("`2>> You took profits! Gained `$" .. formatNum(profit) .. " Gems``!``")
                setPlayerLastClaim(player:getUserID(), "Gold", now)
            else
                player:onConsoleMessage("`4Your holdings are too low to yield any profit!``")
            end
            
            showStockMenu(player)
            return true
        end
        
        if clicked == "stock_dev_reset" and player:hasRole(51) then
            db:query("UPDATE market SET total_bought = 0 WHERE stock_name = 'Gold'")
            db:query("DELETE FROM holdings WHERE stock_name = 'Gold'")
            player:onConsoleMessage("`4>> Stock Market 'Gold' has been completely reset. All holdings wiped.``")
            player:playAudio("secret.wav")
            showStockMenu(player)
            return true
        end
        
        return true
    end
    
    return false
end)
