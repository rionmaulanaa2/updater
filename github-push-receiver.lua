-- github-push-receiver.lua
-- Listens for incoming HTTP file deployments from GitHub Actions.
-- Uses onHTTPRequest (fully synchronous, no yielding = no crashes).
-- DO NOT commit config/deploy_secret.txt to git!
print("(Loaded) GitHub Push Receiver")

local SECRET_PATH = "config/deploy_secret.txt"

local function getDeploySecret()
    if file.exists(SECRET_PATH) then
        local s = file.read(SECRET_PATH)
        if s and s ~= "" then
            -- Trim whitespace/newlines
            return s:gsub("%s+", "")
        end
    end
    return nil
end

local function urlDecode(str)
    str = str:gsub("+", " ")
    str = str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return str
end

onHTTPRequest(function(req)
    local path = req.path or ""

    -- Only handle /deploy-lua requests
    if not path:match("^/deploy%-lua") then
        return
    end

    local token    = path:match("[?&]token=([^&]+)")
    local filePath = path:match("[?&]file=([^&]+)")
    local secret   = getDeploySecret()

    -- Check deploy secret is configured
    if not secret then
        return {
            status  = 503,
            body    = '{"error":"Deploy secret not set. Run /ul setup <secret> in-game."}',
            headers = { ["Content-Type"] = "application/json" }
        }
    end

    -- Verify token
    if not token or token ~= secret then
        return {
            status  = 403,
            body    = '{"error":"Forbidden - invalid token"}',
            headers = { ["Content-Type"] = "application/json" }
        }
    end

    -- Require a file path
    if not filePath or filePath == "" then
        return {
            status  = 400,
            body    = '{"error":"Missing file parameter"}',
            headers = { ["Content-Type"] = "application/json" }
        }
    end

    filePath = urlDecode(filePath)

    -- Security: prevent path traversal attacks
    if filePath:match("%.%.") then
        return {
            status  = 400,
            body    = '{"error":"Invalid path"}',
            headers = { ["Content-Type"] = "application/json" }
        }
    end

    local content = req.body or ""

    -- Create parent directory if needed
    local dirPart = filePath:match("(.+)/[^/]+$")
    if dirPart then
        dir.create(dirPart)
    end

    file.write(filePath, content)

    return {
        status  = 200,
        body    = '{"ok":true,"path":"' .. filePath .. '"}',
        headers = { ["Content-Type"] = "application/json" }
    }
end)
