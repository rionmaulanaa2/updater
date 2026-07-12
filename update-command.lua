-- Update Command script
print("(Loaded) Update Command script for GrowSoft")

local updateCommandData = {
    command = "update",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "This command allows you to `$update`` a server script from a Github link."
}

local updateInfo = "`oUsage: /update <`$filename``> <`$url``> - Downloads a file and saves it to the server.``"

registerLuaCommand(updateCommandData)

onPlayerCommandCallback(function(world, player, fullCommand)
    local command, message = fullCommand:match("^(%S+)%s*(.*)")
    
    if command:lower() == updateCommandData.command then
        if not player:hasRole(updateCommandData.roleRequired) then
            return false
        end

        local filename, url = message:match("^(%S+)%s+(%S+)$")
        
        if not filename or not url then
            player:onConsoleMessage(updateInfo)
            return true
        end

        -- Convert github.com blob links to raw.githubusercontent.com
        if url:find("github%.com") and url:find("/blob/") then
            url = url:gsub("github%.com", "raw.githubusercontent.com")
            url = url:gsub("/blob/", "/")
        end

        player:onConsoleMessage("`oAttempting to download `w" .. filename .. "`` from link...")

        -- We wrap in pcall to avoid crashing if the engine throws an error on invalid URL
        local success, res = pcall(http.get, url)
        
        if success and res then
            local body = ""
            if type(res) == "table" and res.body then
                body = res.body
            elseif type(res) == "string" then
                body = res
            end

            if body and #body > 0 then
                file.write(filename, body)
                player:onConsoleMessage("`2Successfully updated `w" .. filename .. "`2 from Github!``")
                player:onConsoleMessage("`oReloading scripts to apply changes...``")
                reloadScripts()
            else
                player:onConsoleMessage("`4Failed: `oThe downloaded file was empty or invalid.``")
            end
        else
            player:onConsoleMessage("`4Error: `oCould not reach the URL or the HTTP request failed.``")
            if type(res) == "string" then
                player:onConsoleMessage("`4Details: `o" .. res .. "``")
            end
        end

        return true
    end
    
    return false
end)
