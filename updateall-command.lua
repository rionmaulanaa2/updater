-- Update All Command script
print("(Loaded) Update All from Github script for GrowSoft")

local CONFIG_PATH = "config/github_updater.json"

local ROLE_DEVELOPER = 51

registerLuaCommand({
    command = "ul",
    roleRequired = ROLE_DEVELOPER,
    description = "This command fetches and updates all scripts from the configured Github repository."
})

registerLuaCommand({
    command = "updatelua",
    roleRequired = ROLE_DEVELOPER,
    description = "This command fetches and updates all scripts from the configured Github repository."
})

local function readConfig()
    if not file.exists(CONFIG_PATH) then return nil end
    local content = file.read(CONFIG_PATH)
    if content and content ~= "" then
        local dec = json.decode(content)
        if type(dec) == "table" then return dec end
    end
    return nil
end

local function writeConfig(data)
    -- ensure config dir exists
    dir.create("config")
    local content = json.encode(data)
    if content then
        file.write(CONFIG_PATH, content)
        return true
    end
    return false
end

local function showConfigUI(player)
    local config = readConfig() or {}
    local defaultRepo = config.repo or "Owner/RepoName"
    local defaultBranch = config.branch or "main"

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Github Auto-Updater``|left|5814|")
    table.insert(d, "add_smalltext|`oSetup the Github repository to pull files from.``|left|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_textbox|`oGithub Repo (e.g. GrowSoft/GrowtopiaServer):``|left|")
    table.insert(d, "add_text_input|repo||" .. defaultRepo .. "|64|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`oBranch Name (e.g. main or master):``|left|")
    table.insert(d, "add_text_input|branch||" .. defaultBranch .. "|32|")
    table.insert(d, "add_spacer|small|")
    
    table.insert(d, "add_button|save_gh_config|`2Save Config``|no_flags|0|0|")
    table.insert(d, "add_button|gh_close|`oCancel``|no_flags|0|0|")

    player:onDialogRequest(
        table.concat(d, "\n") .. "\n" ..
        "end_dialog|github_updater_config|Close||\n" ..
        "add_quick_exit|"
    )
end

local function handleFileDownload(repo, branch, item, player)
    local rawUrl = "https://raw.githubusercontent.com/" .. repo .. "/" .. branch .. "/" .. item.path
    -- We pass a callback as the second argument
    http.get(rawUrl, function(dlRes)
        if dlRes then
            local dlBody = type(dlRes) == "table" and dlRes.body or dlRes
            if dlBody and type(dlBody) == "string" and #dlBody > 0 then
                local dirPath = item.path:match("(.+)/[^/]+$")
                if dirPath then
                    dir.create(dirPath)
                end
                file.write(item.path, dlBody)
            end
        end
    end)
end

local function executeUpdateAll(player, config)
    player:onConsoleMessage("`oAttempting to fetch latest files from GitHub API...``")
    local repo = config.repo
    local branch = config.branch

    local apiUrl = "https://api.github.com/repos/" .. repo .. "/git/trees/" .. branch .. "?recursive=1"
    
    -- Attempting to use a callback approach in case http.get supports it to bypass yielding
    http.get(apiUrl, function(res)
        if not res then
            player:onConsoleMessage("`4Failed to reach Github API. Check repo name and internet connection.``")
            return
        end

        local body = type(res) == "table" and res.body or res
        if type(body) == "string" and not body:match("^%s*{") then
            player:onConsoleMessage("`4Error: API did not return JSON. It might be blocking the request.``")
            return
        end

        local data = json.decode(body)
        if data and type(data) == "table" and data.tree then
            local count = 0
            for _, item in ipairs(data.tree) do
                if item.type == "blob" then
                    if item.path:match("%.lua$") or item.path:match("%.json$") or item.path:match("%.txt$") or item.path:match("%.md$") then
                        handleFileDownload(repo, branch, item, player)
                        count = count + 1
                    end
                end
            end
            player:onConsoleMessage("`2Successfully queued `w" .. count .. "`2 files for download!``")
            player:onConsoleMessage("`oDownloads happen in the background. Please wait 3-5 seconds and then run /reload.``")
        else
            player:onConsoleMessage("`4Failed to parse Github API response.``")
        end
    end)
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)")
    if not cmd then cmd = fullCommand end
    cmd = cmd:lower()
    -- Strip leading slash if present
    if cmd:sub(1, 1) == "/" then cmd = cmd:sub(2) end
    
    if cmd == "ul" or cmd == "updatelua" then
        if not player:hasRole(ROLE_DEVELOPER) then
            return false
        end
        
        args = args or ""

        if args:lower() == "config" then
            showConfigUI(player)
            return true
        end

        local config = readConfig()
        if not config or not config.repo or not config.branch then
            player:onConsoleMessage("`4Github Updater is not configured yet!``")
            showConfigUI(player)
            return true
        end

        executeUpdateAll(player, config)

        return true
    end
    
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local clicked = data["buttonClicked"] or ""

    if dlg == "github_updater_config" then
        if clicked == "gh_close" then
            return true
        end
        
        if clicked == "save_gh_config" then
            local repo = data["repo"] or ""
            local branch = data["branch"] or ""
            
            if repo == "" or branch == "" then
                player:onConsoleMessage("`4Repo and Branch cannot be empty!``")
                return true
            end
            
            local configData = {
                repo = repo,
                branch = branch
            }
            
            if writeConfig(configData) then
                player:onConsoleMessage("`2Github Auto-Updater config saved!``")
                player:onConsoleMessage("`oYou can now type `/ul` to fetch all files.``")
            else
                player:onConsoleMessage("`4Failed to save config. Check console logs.``")
            end
            return true
        end
    end

    return false
end)
