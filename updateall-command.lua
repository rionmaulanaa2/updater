-- Update All Command script
-- Uses file.write to drop a trigger file on disk.
-- The updater-daemon.ps1 watches for that file and runs git pull.
-- No HTTP calls needed = no crashes, no blocks.
print("(Loaded) Update All from Github script for GrowSoft")

local CONFIG_PATH  = "config/github_updater.json"
local TRIGGER_FILE = "_update_trigger.txt"   -- daemon watches this file
local STATUS_FILE  = "_update_status.txt"    -- daemon writes result here

local ROLE_DEVELOPER = 51

registerLuaCommand({
    command = "ul",
    roleRequired = ROLE_DEVELOPER,
    description = "Triggers the Updater Daemon to git pull all latest scripts from Github."
})

registerLuaCommand({
    command = "updatelua",
    roleRequired = ROLE_DEVELOPER,
    description = "Alias for /ul. Triggers the Updater Daemon to git pull all latest scripts from Github."
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
    local defaultRepo   = config.repo   or "Owner/RepoName"
    local defaultBranch = config.branch or "main"

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`6Github Auto-Updater``|left|5814|")
    table.insert(d, "add_smalltext|`oSetup the Github repository to pull files from.``|left|")
    table.insert(d, "add_spacer|small|")

    table.insert(d, "add_textbox|`oGithub Repo (e.g. rionmaulanaa2/updater):``|left|")
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

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)")
    if not cmd then cmd = fullCommand end
    cmd = cmd:lower()
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

        -- Check if the daemon is even running by looking for a heartbeat file
        if not file.exists("_daemon_alive.txt") then
            player:onConsoleMessage("`4Updater Daemon is NOT running!``")
            player:onConsoleMessage("`oPlease start `wupdater-daemon.ps1`` `oon your PC first!``")
            player:onConsoleMessage("`oRun: `wpowershell -ExecutionPolicy Bypass -File updater-daemon.ps1``")
            return true
        end

        -- Write the trigger file — daemon detects this and runs git pull
        -- file.write is synchronous, works in any callback, no HTTP needed!
        file.write(TRIGGER_FILE, os.time())
        
        player:onConsoleMessage("`6>> `oUpdate trigger sent to Updater Daemon!``")
        player:onConsoleMessage("`oThe daemon is now running `wgit pull`` `oin the background.``")
        player:onConsoleMessage("`oWait `w5 seconds`` `othen type `w/ulstatus`` `oto check progress.``")

        return true
    end

    if cmd == "ulstatus" then
        if not player:hasRole(ROLE_DEVELOPER) then
            return false
        end

        if file.exists(TRIGGER_FILE) then
            player:onConsoleMessage("`eDaemon is still working... please wait a few more seconds.``")
        elseif file.exists(STATUS_FILE) then
            local status = file.read(STATUS_FILE)
            if status and status ~= "" then
                if status:match("^OK") then
                    player:onConsoleMessage("`2Update complete! `o" .. status .. "``")
                    player:onConsoleMessage("`oType `w/reload`` `oto apply the new scripts!``")
                else
                    player:onConsoleMessage("`4Update failed: `o" .. status .. "``")
                end
            else
                player:onConsoleMessage("`oNo status available yet. Is the daemon running?``")
            end
        else
            player:onConsoleMessage("`oNo update has been triggered yet. Type `/ul` to update.``")
        end
        return true
    end

    return false
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg     = data["dialog_name"] or ""
    local clicked = data["buttonClicked"] or ""

    if dlg == "github_updater_config" then
        if clicked == "gh_close" then
            return true
        end

        if clicked == "save_gh_config" then
            local repo   = data["repo"]   or ""
            local branch = data["branch"] or ""

            if repo == "" or branch == "" then
                player:onConsoleMessage("`4Repo and Branch cannot be empty!``")
                return true
            end

            local configData = { repo = repo, branch = branch }

            if writeConfig(configData) then
                player:onConsoleMessage("`2Github Auto-Updater config saved!``")
                player:onConsoleMessage("`oMake sure `wupdater-daemon.ps1`` `ois running on your PC!``")
                player:onConsoleMessage("`oType `/ul` to trigger an update.``")
            else
                player:onConsoleMessage("`4Failed to save config. Check console logs.``")
            end
            return true
        end
    end

    return false
end)
