#Requires -RunAsAdministrator
#==============================================================================
# SETUP AUTO DEPLOY - One-click automatic deployment service
#==============================================================================

$ErrorActionPreference = "Continue"

$CONFIG = @{
    GitRepo = "https://github.com/cgemise971/PropFirmEA.git"
    ProjectPath = "C:\PropFirmEA\Project"
    MT5Path = "C:\PropFirmEA\MT5_PropFirm"
    ConfigPath = "C:\PropFirmEA\Config\project_config.json"
    LogPath = "C:\PropFirmEA\Logs"
    TaskName = "PropFirmEA_DeployAgent"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   AUTO DEPLOY SETUP - PropFirm EA" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Git pull
Write-Host "[1/4] Updating from GitHub..." -ForegroundColor Yellow
Push-Location $CONFIG.ProjectPath
$gitOutput = git pull origin main 2>&1
Write-Host "      $gitOutput" -ForegroundColor Gray
Pop-Location
Write-Host "      Done!" -ForegroundColor Green

# 2. Deploy files to MT5
Write-Host "[2/4] Deploying files to MT5..." -ForegroundColor Yellow

$deployments = @(
    @{ Src = "EA\MQL5\*.mq5"; Dst = "MQL5\Experts" },
    @{ Src = "EA\MQL5\*.mqh"; Dst = "MQL5\Include" },
    @{ Src = "config\profiles\*.set"; Dst = "MQL5\Presets" },
    @{ Src = "backtests\*.mqh"; Dst = "MQL5\Include" }
)

foreach ($d in $deployments) {
    $srcPath = Join-Path $CONFIG.ProjectPath $d.Src
    $dstPath = Join-Path $CONFIG.MT5Path $d.Dst

    if (-not (Test-Path $dstPath)) {
        New-Item -ItemType Directory -Path $dstPath -Force | Out-Null
    }

    $files = Get-ChildItem -Path $srcPath -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item $f.FullName -Destination $dstPath -Force
        Write-Host "      + $($f.Name)" -ForegroundColor Gray
    }
}
Write-Host "      Done!" -ForegroundColor Green

# 3. Create scheduled task for continuous deployment
Write-Host "[3/4] Creating auto-deploy service..." -ForegroundColor Yellow

# Remove existing task
Unregister-ScheduledTask -TaskName $CONFIG.TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Create deploy script that runs continuously
$loopScript = @"
`$ErrorActionPreference = 'Continue'
`$projectPath = '$($CONFIG.ProjectPath)'
`$mt5Path = '$($CONFIG.MT5Path)'
`$gitRepo = '$($CONFIG.GitRepo)'
`$logPath = '$($CONFIG.LogPath)'

while (`$true) {
    try {
        `$logFile = Join-Path `$logPath "deploy_`$(Get-Date -Format 'yyyy-MM-dd').log"
        `$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        # Git fetch and check for changes
        Push-Location `$projectPath
        git fetch origin main 2>&1 | Out-Null
        `$local = git rev-parse HEAD
        `$remote = git rev-parse origin/main

        if (`$local -ne `$remote) {
            Add-Content -Path `$logFile -Value "[`$timestamp] Changes detected, deploying..."

            git pull origin main 2>&1 | Out-Null

            # Deploy EA files
            Copy-Item "EA\MQL5\*.mq5" -Destination "`$mt5Path\MQL5\Experts\" -Force -ErrorAction SilentlyContinue
            Copy-Item "config\profiles\*.set" -Destination "`$mt5Path\MQL5\Presets\" -Force -ErrorAction SilentlyContinue
            Copy-Item "backtests\*.mqh" -Destination "`$mt5Path\MQL5\Include\" -Force -ErrorAction SilentlyContinue

            Add-Content -Path `$logFile -Value "[`$timestamp] Deployment complete!"
        }
        Pop-Location
    } catch {
        Add-Content -Path `$logFile -Value "[`$timestamp] Error: `$_"
    }

    Start-Sleep -Seconds 60
}
"@

$scriptPath = "C:\PropFirmEA\Config\auto_deploy_loop.ps1"
Set-Content -Path $scriptPath -Value $loopScript -Encoding UTF8

# Create the scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Hours 0)

Register-ScheduledTask -TaskName $CONFIG.TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "      Done!" -ForegroundColor Green

# 4. Start the service
Write-Host "[4/4] Starting service..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $CONFIG.TaskName
Start-Sleep -Seconds 2
$state = (Get-ScheduledTask -TaskName $CONFIG.TaskName).State
Write-Host "      Service state: $state" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   SETUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Auto-deploy is now ACTIVE" -ForegroundColor White
Write-Host "- Checks GitHub every 60 seconds" -ForegroundColor Gray
Write-Host "- Auto-deploys changes to MT5" -ForegroundColor Gray
Write-Host "- Logs: C:\PropFirmEA\Logs\" -ForegroundColor Gray
Write-Host ""
Write-Host "Files deployed to MT5:" -ForegroundColor Yellow
Get-ChildItem "C:\PropFirmEA\MT5_PropFirm\MQL5\Experts\*.mq5" | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
Write-Host ""
Write-Host "Refresh MT5 Navigator to see the EAs!" -ForegroundColor Cyan
Write-Host ""
