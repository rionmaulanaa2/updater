# ============================================================
# GT Rion Updater Daemon v2.0 - File Watcher Mode
# 
# INSTRUCTIONS:
#   1. Run this script ONCE on your PC and keep it open.
#   2. It watches for a trigger file written by the Lua /ul command.
#   3. When triggered, it runs 'git pull' to update all scripts.
#   4. Type /ulstatus in-game to check the result.
#
# To start: Right-click this file -> "Run with PowerShell"
#   OR run: powershell -ExecutionPolicy Bypass -File updater-daemon.ps1
# ============================================================

$ProjectPath   = $PSScriptRoot
$TriggerFile   = Join-Path $ProjectPath "_update_trigger.txt"
$StatusFile    = Join-Path $ProjectPath "_update_status.txt"
$HeartbeatFile = Join-Path $ProjectPath "_daemon_alive.txt"
$PollIntervalMs = 1000   # Check every 1 second

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  GT Rion Updater Daemon v2.0" -ForegroundColor Cyan
Write-Host "  File Watcher Mode" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Project Path : $ProjectPath" -ForegroundColor White
Write-Host "Watching     : _update_trigger.txt" -ForegroundColor White
Write-Host ""
Write-Host "Keep this window open." -ForegroundColor Yellow
Write-Host "Type /ul in-game to trigger an update." -ForegroundColor Yellow
Write-Host "Type /ulstatus in-game to check progress." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Write heartbeat so Lua can detect the daemon is running
Set-Content -Path $HeartbeatFile -Value "running" -Encoding UTF8
Write-Host "[OK] Daemon is running. Heartbeat file created." -ForegroundColor Green
Write-Host ""

# Clean up on exit
$null = Register-EngineEvent PowerShell.Exiting -Action {
    if (Test-Path $HeartbeatFile) { Remove-Item $HeartbeatFile -Force }
    Write-Host "Daemon stopped. Heartbeat removed." -ForegroundColor Gray
}

try {
    while ($true) {
        Start-Sleep -Milliseconds $PollIntervalMs

        # Refresh heartbeat timestamp every 10 seconds so Lua knows we're alive
        if ((Get-Date).Second % 10 -eq 0) {
            Set-Content -Path $HeartbeatFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Encoding UTF8
        }

        # Check if the trigger file was written by the Lua /ul command
        if (Test-Path $TriggerFile) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Trigger detected! Running git pull..." -ForegroundColor Cyan

            # Clear old status
            if (Test-Path $StatusFile) { Remove-Item $StatusFile -Force }

            # Run git pull
            $Output = & git -C $ProjectPath pull origin main 2>&1
            $ExitCode = $LASTEXITCODE

            # Delete trigger file to signal "done processing"
            Remove-Item $TriggerFile -Force -ErrorAction SilentlyContinue

            if ($ExitCode -eq 0) {
                $StatusMsg = "OK: git pull successful! " + ($Output | Select-Object -Last 1)
                Write-Host "[OK] $StatusMsg" -ForegroundColor Green
            } else {
                $StatusMsg = "ERR: git pull failed (exit $ExitCode) - " + ($Output | Select-Object -Last 1)
                Write-Host "[ERR] $StatusMsg" -ForegroundColor Red
            }

            # Write result for /ulstatus to read
            Set-Content -Path $StatusFile -Value $StatusMsg -Encoding UTF8

            Write-Host ""
        }
    }
} catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
} finally {
    if (Test-Path $HeartbeatFile) { Remove-Item $HeartbeatFile -Force }
    Write-Host "Daemon stopped." -ForegroundColor Gray
}
