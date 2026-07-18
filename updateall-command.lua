-- updateall-command.lua
-- /ul setup <secret>  → saves deploy secret to config/deploy_secret.txt
-- /ul                 → shows the current system status
-- The actual file updating is done by GitHub Actions pushing to onHTTPRequest.
print("(Loaded) Update All / GitHub Auto-Deploy command")

local SECRET_PATH = "config/deploy_secret.txt"
local ROLE_DEVELOPER = 51

registerLuaCommand({
    command      = "ul",
    roleRequired = ROLE_DEVELOPER,
    description  = "GitHub Auto-Deploy setup and status. Usage: /ul | /ul setup <secret>"
})

registerLuaCommand({
    command      = "updatelua",
    roleRequired = ROLE_DEVELOPER,
    description  = "Alias for /ul."
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)")
    if not cmd then cmd = fullCommand end
    cmd = cmd:lower()
    if cmd:sub(1, 1) == "/" then cmd = cmd:sub(2) end

    if cmd ~= "ul" and cmd ~= "updatelua" then
        return false
    end

    if not player:hasRole(ROLE_DEVELOPER) then
        return false
    end

    args = args or ""
    local subcmd, value = args:match("^(%S+)%s*(.*)")
    subcmd = (subcmd or ""):lower()

    -- /ul setup <secret>  → write deploy secret
    if subcmd == "setup" then
        if value == "" then
            player:onConsoleMessage("`4Usage: `/ul setup <your-secret-password>``")
            player:onConsoleMessage("`oExample: `/ul setup MyStr0ngSecret123``")
            return true
        end

        dir.create("config")
        file.write(SECRET_PATH, value)
        player:onConsoleMessage("`2Deploy secret saved!``")
        player:onConsoleMessage("`oNow add these two secrets to your GitHub repo:``")
        player:onConsoleMessage("`w  DEPLOY_SECRET   `o= the secret you just typed``")
        player:onConsoleMessage("`w  GTPS_SERVER_URL `o= your GTPS Cloud server HTTP URL``")
        player:onConsoleMessage("`oGo to: `wGitHub repo → Settings → Secrets → Actions``")
        return true
    end

    -- /ul  → show status
    local secretExists = file.exists(SECRET_PATH)
    player:onConsoleMessage("`6=== GitHub Auto-Deploy Status ===``")

    if secretExists then
        player:onConsoleMessage("`2✔ Deploy secret is configured.``")
    else
        player:onConsoleMessage("`4✘ Deploy secret NOT set!``")
        player:onConsoleMessage("`oRun: `w/ul setup <your-secret>`` `oto configure.``")
    end

    player:onConsoleMessage("`o``")
    player:onConsoleMessage("`wHow it works:``")
    player:onConsoleMessage("`o1. Edit your Lua files locally on your PC``")
    player:onConsoleMessage("`o2. git push to GitHub (main branch)``")
    player:onConsoleMessage("`o3. GitHub Action auto-sends all files to this server``")
    player:onConsoleMessage("`o4. Type `w/reload`` `oin-game to apply the new scripts!``")
    player:onConsoleMessage("`o``")
    player:onConsoleMessage("`oYou can also trigger manually from GitHub:``")
    player:onConsoleMessage("`wGitHub repo → Actions → Auto Deploy → Run workflow``")

    return true
end)
