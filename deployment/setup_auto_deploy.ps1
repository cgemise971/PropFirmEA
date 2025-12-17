#Requires -RunAsAdministrator
# ONE-CLICK AUTO DEPLOY SETUP

Write-Host "Setting up auto-deploy..." -ForegroundColor Cyan

# 1. Create sync script
$syncScript = @'
while($true) {
    try {
        cd "C:\PropFirmEA\Project"
        $old = git rev-parse HEAD 2>$null
        git pull origin main 2>$null | Out-Null
        $new = git rev-parse HEAD 2>$null
        if($old -ne $new) {
            Copy-Item "EA\MQL5\*.mq5" "C:\PropFirmEA\MT5_PropFirm\MQL5\Experts\" -Force 2>$null
            Copy-Item "config\profiles\*.set" "C:\PropFirmEA\MT5_PropFirm\MQL5\Presets\" -Force 2>$null
            "$(Get-Date): Deployed" >> "C:\PropFirmEA\Logs\sync.log"
        }
    } catch {}
    Start-Sleep 60
}
'@

New-Item -Path "C:\PropFirmEA\Logs" -ItemType Directory -Force | Out-Null
$syncScript | Out-File "C:\PropFirmEA\sync.ps1" -Force

# 2. Remove old task if exists
Unregister-ScheduledTask -TaskName "PropFirmEA_AutoSync" -Confirm:$false -ErrorAction SilentlyContinue

# 3. Create new task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -EP Bypass -File C:\PropFirmEA\sync.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
Register-ScheduledTask -TaskName "PropFirmEA_AutoSync" -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force | Out-Null

# 4. Start now
Start-ScheduledTask -TaskName "PropFirmEA_AutoSync"

# 5. First sync
cd "C:\PropFirmEA\Project"
git pull origin main 2>$null
Copy-Item "EA\MQL5\*.mq5" "C:\PropFirmEA\MT5_PropFirm\MQL5\Experts\" -Force 2>$null
Copy-Item "config\profiles\*.set" "C:\PropFirmEA\MT5_PropFirm\MQL5\Presets\" -Force 2>$null

Write-Host ""
Write-Host "DONE! Auto-sync is now ACTIVE" -ForegroundColor Green
Write-Host "- Checks GitHub every 60 seconds" -ForegroundColor Gray
Write-Host "- Auto-deploys to MT5" -ForegroundColor Gray
Write-Host ""
Get-ScheduledTask -TaskName "PropFirmEA_AutoSync" | Select-Object TaskName, State
