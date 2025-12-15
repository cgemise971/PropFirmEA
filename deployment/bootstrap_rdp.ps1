#Requires -RunAsAdministrator
#==============================================================================
# BOOTSTRAP PROPFIRM EA - AUTOMATIC INSTALLATION
# Run this ONE command on your RDP to install everything
#==============================================================================

param(
    [string]$GitRepo = "https://github.com/cgemise971/PropFirmEA.git",
    [string]$InstallPath = "C:\PropFirmEA",
    [string]$BrokerServer = "ICMarketsSC-Demo",
    [switch]$SkipMT5Install,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$CONFIG = @{
    GitRepo = $GitRepo
    InstallPath = $InstallPath
    MT5Path = "$InstallPath\MT5_PropFirm"
    ProjectPath = "$InstallPath\Project"
    LogPath = "$InstallPath\Logs"
    BrokerServer = $BrokerServer
    GitDownloadUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
    MT5DownloadUrl = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
}

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch($Status) {
        "SUCCESS" { "Green" }
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "STEP"    { "Cyan" }
        default   { "White" }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites..." "STEP"

    if (-not (Test-Administrator)) {
        Write-Step "This script must be run as Administrator!" "ERROR"
        exit 1
    }
    Write-Step "Administrator rights: OK" "SUCCESS"

    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 10
        Write-Step "Internet connection: OK" "SUCCESS"
    } catch {
        Write-Step "No internet connection!" "ERROR"
        exit 1
    }

    $existingMT5 = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue
    if ($existingMT5) {
        Write-Step "Existing MT5 instance(s) detected - our install will be ISOLATED" "WARN"
    }
}

function Install-GitIfNeeded {
    Write-Step "Checking Git..." "STEP"

    try {
        $gitVersion = git --version 2>&1
        Write-Step "Git already installed: $gitVersion" "SUCCESS"
        return
    } catch {
        Write-Step "Git not found, installing..." "WARN"
    }

    $gitInstaller = "$env:TEMP\GitInstaller.exe"

    Write-Step "Downloading Git for Windows..."
    Invoke-WebRequest -Uri $CONFIG.GitDownloadUrl -OutFile $gitInstaller -UseBasicParsing

    Write-Step "Installing Git silently..."
    $process = Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-" -Wait -PassThru

    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = $machinePath + ";" + $userPath

    $gitPath = "C:\Program Files\Git\cmd"
    if (Test-Path $gitPath) {
        $env:Path = $env:Path + ";" + $gitPath
    }

    Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
    Write-Step "Git installed successfully" "SUCCESS"
}

function Initialize-ProjectStructure {
    Write-Step "Creating project structure..." "STEP"

    $directories = @(
        $CONFIG.InstallPath,
        $CONFIG.MT5Path,
        $CONFIG.ProjectPath,
        $CONFIG.LogPath,
        ($CONFIG.InstallPath + "\Config"),
        ($CONFIG.InstallPath + "\Backups")
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Write-Step "Structure created: $($CONFIG.InstallPath)" "SUCCESS"

    Write-Step "Cloning GitHub repository..." "STEP"

    $gitDir = $CONFIG.ProjectPath + "\.git"
    if (Test-Path $gitDir) {
        Write-Step "Repository already cloned, updating..." "WARN"
        Push-Location $CONFIG.ProjectPath
        git pull origin main 2>&1 | Out-Null
        Pop-Location
    } else {
        if (Test-Path $CONFIG.ProjectPath) {
            Remove-Item -Path ($CONFIG.ProjectPath + "\*") -Recurse -Force -ErrorAction SilentlyContinue
        }
        git clone $CONFIG.GitRepo $CONFIG.ProjectPath 2>&1 | Out-Null
    }

    Write-Step "Repository cloned successfully" "SUCCESS"
}

function Install-MT5Portable {
    if ($SkipMT5Install) {
        Write-Step "MT5 installation skipped (-SkipMT5Install)" "WARN"
        return
    }

    Write-Step "Installing MetaTrader 5 (Portable)..." "STEP"

    $mt5Exe = $CONFIG.MT5Path + "\terminal64.exe"
    if (Test-Path $mt5Exe) {
        Write-Step "MT5 already installed in $($CONFIG.MT5Path)" "WARN"
        $portableIni = "[Portable]`nDataPath=" + $CONFIG.MT5Path
        $iniPath = $CONFIG.MT5Path + "\portable.ini"
        Set-Content -Path $iniPath -Value $portableIni -Encoding ASCII
        Write-Step "Portable mode configured" "SUCCESS"
        return
    }

    $mt5Installer = "$env:TEMP\mt5setup.exe"
    Write-Step "Downloading MetaTrader 5..."
    Invoke-WebRequest -Uri $CONFIG.MT5DownloadUrl -OutFile $mt5Installer -UseBasicParsing

    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Yellow
    Write-Host "  IMPORTANT: In MT5 installer:" -ForegroundColor Yellow
    Write-Host "  1. Click 'Settings'" -ForegroundColor Yellow
    Write-Host "  2. Change path to:" -ForegroundColor Yellow
    Write-Host "     $($CONFIG.MT5Path)" -ForegroundColor White
    Write-Host "  3. Complete installation" -ForegroundColor Yellow
    Write-Host "  ============================================" -ForegroundColor Yellow
    Write-Host ""

    Start-Process -FilePath $mt5Installer -Wait

    if (Test-Path $mt5Exe) {
        $portableIni = "[Portable]`nDataPath=" + $CONFIG.MT5Path
        $iniPath = $CONFIG.MT5Path + "\portable.ini"
        Set-Content -Path $iniPath -Value $portableIni -Encoding ASCII
        Write-Step "MT5 installed and configured in portable mode" "SUCCESS"
    } else {
        Write-Step "MT5 not found in expected path" "ERROR"
        Write-Step "Please reinstall MT5 in: $($CONFIG.MT5Path)" "ERROR"
    }

    Remove-Item $mt5Installer -Force -ErrorAction SilentlyContinue
}

function Deploy-EAFiles {
    Write-Step "Deploying EA files to MT5..." "STEP"

    $totalDeployed = 0

    # Deploy MQ5 files to Experts
    $srcExperts = $CONFIG.ProjectPath + "\EA\MQL5\*.mq5"
    $dstExperts = $CONFIG.MT5Path + "\MQL5\Experts"
    if (-not (Test-Path $dstExperts)) { New-Item -ItemType Directory -Path $dstExperts -Force | Out-Null }
    $files = Get-ChildItem -Path $srcExperts -ErrorAction SilentlyContinue
    foreach ($f in $files) { Copy-Item $f.FullName -Destination $dstExperts -Force; $totalDeployed++ }

    # Deploy MQH files to Include
    $srcInclude = $CONFIG.ProjectPath + "\backtests\*.mqh"
    $dstInclude = $CONFIG.MT5Path + "\MQL5\Include"
    if (-not (Test-Path $dstInclude)) { New-Item -ItemType Directory -Path $dstInclude -Force | Out-Null }
    $files = Get-ChildItem -Path $srcInclude -ErrorAction SilentlyContinue
    foreach ($f in $files) { Copy-Item $f.FullName -Destination $dstInclude -Force; $totalDeployed++ }

    # Deploy Scripts
    $srcScripts = $CONFIG.ProjectPath + "\backtests\*.mq5"
    $dstScripts = $CONFIG.MT5Path + "\MQL5\Scripts"
    if (-not (Test-Path $dstScripts)) { New-Item -ItemType Directory -Path $dstScripts -Force | Out-Null }
    $files = Get-ChildItem -Path $srcScripts -ErrorAction SilentlyContinue
    foreach ($f in $files) { Copy-Item $f.FullName -Destination $dstScripts -Force; $totalDeployed++ }

    # Deploy Presets
    $srcPresets = $CONFIG.ProjectPath + "\config\profiles\*.set"
    $dstPresets = $CONFIG.MT5Path + "\MQL5\Presets"
    if (-not (Test-Path $dstPresets)) { New-Item -ItemType Directory -Path $dstPresets -Force | Out-Null }
    $files = Get-ChildItem -Path $srcPresets -ErrorAction SilentlyContinue
    foreach ($f in $files) { Copy-Item $f.FullName -Destination $dstPresets -Force; $totalDeployed++ }

    Write-Step "Total deployed: $totalDeployed files" "SUCCESS"
}

function Install-DeployService {
    Write-Step "Configuring auto-deploy service..." "STEP"

    $serviceName = "PropFirmEA_DeployAgent"
    $deployScript = $CONFIG.ProjectPath + "\deployment\deploy_agent.ps1"
    $configPath = $CONFIG.InstallPath + "\Config\project_config.json"

    $actionArg = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$deployScript`" -GitRepo `"$($CONFIG.GitRepo)`" -ConfigPath `"$configPath`""

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArg
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Hours 0)

    Unregister-ScheduledTask -TaskName $serviceName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $serviceName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

    Start-ScheduledTask -TaskName $serviceName
    Write-Step "Service '$serviceName' created and started" "SUCCESS"
}

function Create-HelperScripts {
    Write-Step "Creating helper scripts..." "STEP"

    # Start MT5
    $startScript = "@echo off`r`necho Starting MT5 PropFirm...`r`ncd /d `"$($CONFIG.MT5Path)`"`r`nstart `"`" `"terminal64.exe`" /portable`r`ntimeout /t 3"
    $startPath = $CONFIG.InstallPath + "\Start_MT5.bat"
    [System.IO.File]::WriteAllText($startPath, $startScript)

    # Stop MT5
    $stopScript = "@echo off`r`necho Stopping MT5 PropFirm...`r`ntaskkill /F /IM terminal64.exe 2>nul`r`ntimeout /t 2"
    $stopPath = $CONFIG.InstallPath + "\Stop_MT5.bat"
    [System.IO.File]::WriteAllText($stopPath, $stopScript)

    # Status
    $statusScript = "@echo off`r`necho === PropFirm EA Status ===`r`ntasklist /FI `"IMAGENAME eq terminal64.exe`"`r`nschtasks /query /TN `"PropFirmEA_DeployAgent`"`r`npause"
    $statusPath = $CONFIG.InstallPath + "\Status.bat"
    [System.IO.File]::WriteAllText($statusPath, $statusScript)

    # Manual Deploy
    $manualScript = "@echo off`r`ncd /d `"$($CONFIG.ProjectPath)`"`r`ngit pull origin main`r`npowershell -ExecutionPolicy Bypass -File `"$($CONFIG.ProjectPath)\deployment\deploy_agent.ps1`" -RunOnce -ForceDeploy`r`npause"
    $manualPath = $CONFIG.InstallPath + "\Manual_Deploy.bat"
    [System.IO.File]::WriteAllText($manualPath, $manualScript)

    # Config JSON
    $configObj = @{
        project_name = "PropFirmEA"
        install_path = $CONFIG.InstallPath
        mt5_path = $CONFIG.MT5Path
        project_path = $CONFIG.ProjectPath
        log_path = $CONFIG.LogPath
        git_repo = $CONFIG.GitRepo
        experts_path = $CONFIG.MT5Path + "\MQL5\Experts"
        include_path = $CONFIG.MT5Path + "\MQL5\Include"
        scripts_path = $CONFIG.MT5Path + "\MQL5\Scripts"
        presets_path = $CONFIG.MT5Path + "\MQL5\Presets"
    }
    $configJson = $configObj | ConvertTo-Json -Depth 3
    $configJsonPath = $CONFIG.InstallPath + "\Config\project_config.json"
    [System.IO.File]::WriteAllText($configJsonPath, $configJson)

    # Desktop shortcut
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcutPath = [Environment]::GetFolderPath("Desktop") + "\PropFirm EA.lnk"
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $startPath
        $Shortcut.WorkingDirectory = $CONFIG.InstallPath
        $Shortcut.Save()
        Write-Step "Desktop shortcut created" "SUCCESS"
    } catch {
        Write-Step "Could not create desktop shortcut" "WARN"
    }

    Write-Step "Helper scripts created" "SUCCESS"
}

function Show-Summary {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "       INSTALLATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Installed to: $($CONFIG.InstallPath)" -ForegroundColor White
    Write-Host ""
    Write-Host "  STRUCTURE:" -ForegroundColor Yellow
    Write-Host "  - MT5_PropFirm\    : Isolated MT5 instance" -ForegroundColor Gray
    Write-Host "  - Project\         : Source code (Git synced)" -ForegroundColor Gray
    Write-Host "  - Start_MT5.bat    : Launch MT5 PropFirm" -ForegroundColor Gray
    Write-Host "  - Stop_MT5.bat     : Stop MT5 PropFirm" -ForegroundColor Gray
    Write-Host "  - Manual_Deploy.bat: Force deployment" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  AUTO-DEPLOY SERVICE: Active" -ForegroundColor Green
    Write-Host "  - Checks GitHub every 60 seconds" -ForegroundColor White
    Write-Host "  - Auto-deploys changes to MT5" -ForegroundColor White
    Write-Host ""
    Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  1. Double-click 'PropFirm EA' on desktop" -ForegroundColor White
    Write-Host "  2. Connect your broker account in MT5" -ForegroundColor White
    Write-Host "  3. The EA will be in Navigator > Expert Advisors" -ForegroundColor White
    Write-Host ""
}

# MAIN
Clear-Host
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "       PROPFIRM EA - AUTOMATIC INSTALLER" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Install Path: $($CONFIG.InstallPath)" -ForegroundColor Gray
Write-Host "  Git Repo: $($CONFIG.GitRepo)" -ForegroundColor Gray
Write-Host ""

try {
    Test-Prerequisites
    Install-GitIfNeeded
    Initialize-ProjectStructure
    Install-MT5Portable
    Deploy-EAFiles
    Install-DeployService
    Create-HelperScripts
    Show-Summary
} catch {
    Write-Step "ERROR: $_" "ERROR"
    Write-Step "Installation failed. Check logs in $($CONFIG.LogPath)" "ERROR"
    exit 1
}
