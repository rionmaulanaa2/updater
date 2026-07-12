# ============================================================
# GT Rion Updater Daemon
# Run this once on your PC, keep it in the background.
# The in-game /ul command will send a signal to this script
# which then runs git pull and updates your server scripts.
# ============================================================

$ProjectPath = $PSScriptRoot
$Port = 8765
$Listener = $null

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  GT Rion Updater Daemon v1.0" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Project Path : $ProjectPath" -ForegroundColor White
Write-Host "Listening on : http://localhost:$Port/update" -ForegroundColor White
Write-Host ""
Write-Host "Keep this window open. When a developer types" -ForegroundColor Yellow
Write-Host "/ul in-game, this script will automatically" -ForegroundColor Yellow
Write-Host "run 'git pull' and update all Lua files!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host "====================================" -ForegroundColor Cyan

try {
    $Listener = New-Object System.Net.HttpListener
    $Listener.Prefixes.Add("http://localhost:$Port/")
    $Listener.Start()

    Write-Host "[OK] Daemon is running and waiting..." -ForegroundColor Green
    Write-Host ""

    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        $Path = $Request.Url.AbsolutePath

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Request received: $Path" -ForegroundColor White

        if ($Path -eq "/update") {
            Write-Host "[*] Running git pull in: $ProjectPath" -ForegroundColor Cyan

            $Result = & git -C $ProjectPath pull origin main 2>&1
            $ExitCode = $LASTEXITCODE

            Write-Host $Result -ForegroundColor (if ($ExitCode -eq 0) { "Green" } else { "Red" })

            if ($ExitCode -eq 0) {
                Write-Host "[OK] Git pull successful!" -ForegroundColor Green
                $Body = "OK: git pull successful"
            } else {
                Write-Host "[ERR] Git pull failed with exit code $ExitCode" -ForegroundColor Red
                $Body = "ERR: git pull failed - $Result"
            }

            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $Response.StatusCode = 200
            $Response.ContentLength64 = $Bytes.Length
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Response.Close()

            Write-Host ""
        } else {
            # Handle preflight / health check
            $Body = "GT Rion Updater Daemon running. POST to /update to trigger git pull."
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $Response.StatusCode = 200
            $Response.ContentLength64 = $Bytes.Length
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Response.Close()
        }
    }
} catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
} finally {
    if ($Listener -ne $null -and $Listener.IsListening) {
        $Listener.Stop()
        $Listener.Close()
    }
    Write-Host "Daemon stopped." -ForegroundColor Gray
}
