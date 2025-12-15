#Requires -RunAsAdministrator
#==============================================================================
# BOOTSTRAP PROPFIRM EA - INSTALLATION AUTOMATIQUE COMPLÈTE
#
# Ce script fait TOUT automatiquement:
# 1. Installe Git (si nécessaire)
# 2. Clone le repository
# 3. Installe MT5 Portable (isolé)
# 4. Configure le déploiement automatique
# 5. Lance le service
#
# USAGE: Exécuter UNE SEULE commande dans PowerShell Admin sur le RDP
#==============================================================================

param(
    [string]$GitRepo = "https://github.com/cgemise971/PropFirmEA.git",
    [string]$InstallPath = "C:\PropFirmEA",
    [string]$BrokerServer = "ICMarketsSC-Demo",
    [switch]$SkipMT5Install,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Accélère les téléchargements

#==============================================================================
# CONFIGURATION
#==============================================================================

$CONFIG = @{
    GitRepo = $GitRepo
    InstallPath = $InstallPath
    MT5Path = "$InstallPath\MT5_PropFirm"
    ProjectPath = "$InstallPath\Project"
    LogPath = "$InstallPath\Logs"
    BrokerServer = $BrokerServer
    GitDownloadUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
    MT5DownloadUrl = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
    PollInterval = 60
}

#==============================================================================
# FONCTIONS UTILITAIRES
#==============================================================================

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch($Status) {
        "SUCCESS" { "Green" }
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "STEP"    { "Cyan" }
        default   { "White" }
    }
    $prefix = switch($Status) {
        "SUCCESS" { "[OK]" }
        "ERROR"   { "[X]" }
        "WARN"    { "[!]" }
        "STEP"    { "[>]" }
        default   { "[*]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color

    # Log to file
    $logDir = $CONFIG.LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "$logDir\bootstrap.log" -Value "[$timestamp] [$Status] $Message" -ErrorAction SilentlyContinue
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║   ██████╗ ██████╗  ██████╗ ██████╗ ███████╗██╗██████╗ ███╗   ███╗  ║" -ForegroundColor Cyan
    Write-Host "  ║   ██╔══██╗██╔══██╗██╔═══██╗██╔══██╗██╔════╝██║██╔══██╗████╗ ████║  ║" -ForegroundColor Cyan
    Write-Host "  ║   ██████╔╝██████╔╝██║   ██║██████╔╝█████╗  ██║██████╔╝██╔████╔██║  ║" -ForegroundColor Cyan
    Write-Host "  ║   ██╔═══╝ ██╔══██╗██║   ██║██╔═══╝ ██╔══╝  ██║██╔══██╗██║╚██╔╝██║  ║" -ForegroundColor Cyan
    Write-Host "  ║   ██║     ██║  ██║╚██████╔╝██║     ██║     ██║██║  ██║██║ ╚═╝ ██║  ║" -ForegroundColor Cyan
    Write-Host "  ║   ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ║" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║              INSTALLATION AUTOMATIQUE - v1.0                  ║" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#==============================================================================
# ÉTAPE 1: VÉRIFICATIONS PRÉLIMINAIRES
#==============================================================================

function Test-Prerequisites {
    Write-Step "Vérification des prérequis..." "STEP"

    # Admin check
    if (-not (Test-Administrator)) {
        Write-Step "Ce script doit être exécuté en tant qu'Administrateur!" "ERROR"
        Write-Host "Clic droit sur PowerShell > Exécuter en tant qu'administrateur" -ForegroundColor Yellow
        exit 1
    }
    Write-Step "Droits administrateur: OK" "SUCCESS"

    # Internet check
    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 10
        Write-Step "Connexion Internet: OK" "SUCCESS"
    } catch {
        Write-Step "Pas de connexion Internet!" "ERROR"
        exit 1
    }

    # Check existing MT5 instances
    $existingMT5 = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue
    if ($existingMT5) {
        Write-Step "Instance(s) MT5 existante(s) détectée(s):" "WARN"
        foreach ($proc in $existingMT5) {
            Write-Host "    PID: $($proc.Id) - Path: $($proc.Path)" -ForegroundColor Yellow
        }
        Write-Step "Notre installation sera ISOLÉE de ces instances" "INFO"
    }
}

#==============================================================================
# ÉTAPE 2: INSTALLATION DE GIT
#==============================================================================

function Install-GitIfNeeded {
    Write-Step "Vérification de Git..." "STEP"

    try {
        $gitVersion = git --version 2>&1
        Write-Step "Git déjà installé: $gitVersion" "SUCCESS"
        return
    } catch {
        Write-Step "Git non trouvé, installation en cours..." "WARN"
    }

    $gitInstaller = "$env:TEMP\GitInstaller.exe"

    Write-Step "Téléchargement de Git for Windows..."
    Invoke-WebRequest -Uri $CONFIG.GitDownloadUrl -OutFile $gitInstaller -UseBasicParsing

    Write-Step "Installation silencieuse de Git..."
    $process = Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Step "Erreur installation Git (code: $($process.ExitCode))" "ERROR"
        exit 1
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Add Git to current session
    $gitPath = "C:\Program Files\Git\cmd"
    if (Test-Path $gitPath) {
        $env:Path += ";$gitPath"
    }

    Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue

    Write-Step "Git installé avec succès" "SUCCESS"
}

#==============================================================================
# ÉTAPE 3: CRÉATION STRUCTURE ET CLONE
#==============================================================================

function Initialize-ProjectStructure {
    Write-Step "Création de la structure du projet..." "STEP"

    # Create directories
    $directories = @(
        $CONFIG.InstallPath,
        $CONFIG.MT5Path,
        $CONFIG.ProjectPath,
        $CONFIG.LogPath,
        "$($CONFIG.InstallPath)\Config",
        "$($CONFIG.InstallPath)\Backups"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Write-Step "Structure créée: $($CONFIG.InstallPath)" "SUCCESS"

    # Clone repository
    Write-Step "Clonage du repository GitHub..." "STEP"

    if (Test-Path "$($CONFIG.ProjectPath)\.git") {
        Write-Step "Repository déjà cloné, mise à jour..." "WARN"
        Push-Location $CONFIG.ProjectPath
        git pull origin main 2>&1 | Out-Null
        Pop-Location
    } else {
        # Clean directory if exists but not a repo
        if (Test-Path $CONFIG.ProjectPath) {
            Remove-Item -Path "$($CONFIG.ProjectPath)\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        git clone $CONFIG.GitRepo $CONFIG.ProjectPath 2>&1 | Out-Null
    }

    Write-Step "Repository cloné avec succès" "SUCCESS"
}

#==============================================================================
# ÉTAPE 4: INSTALLATION MT5 PORTABLE
#==============================================================================

function Install-MT5Portable {
    if ($SkipMT5Install) {
        Write-Step "Installation MT5 ignorée (-SkipMT5Install)" "WARN"
        return
    }

    Write-Step "Installation de MetaTrader 5 (Portable)..." "STEP"

    # Check if already installed
    if (Test-Path "$($CONFIG.MT5Path)\terminal64.exe") {
        Write-Step "MT5 déjà installé dans $($CONFIG.MT5Path)" "WARN"

        # Just ensure portable mode is configured
        $portableIni = @"
[Portable]
DataPath=$($CONFIG.MT5Path)
"@
        Set-Content -Path "$($CONFIG.MT5Path)\portable.ini" -Value $portableIni -Encoding UTF8
        Write-Step "Mode portable configuré" "SUCCESS"
        return
    }

    # Download MT5
    $mt5Installer = "$env:TEMP\mt5setup.exe"
    Write-Step "Téléchargement de MetaTrader 5..."
    Invoke-WebRequest -Uri $CONFIG.MT5DownloadUrl -OutFile $mt5Installer -UseBasicParsing

    # Create portable.ini BEFORE installation to hint installer
    $portableIni = @"
[Portable]
DataPath=$($CONFIG.MT5Path)
"@

    Write-Step "Lancement de l'installateur MT5..." "WARN"
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║  IMPORTANT: Dans l'installateur MT5:                       ║" -ForegroundColor Yellow
    Write-Host "  ║                                                            ║" -ForegroundColor Yellow
    Write-Host "  ║  1. Cliquez 'Settings'                                     ║" -ForegroundColor Yellow
    Write-Host "  ║  2. Changez le chemin vers:                                ║" -ForegroundColor Yellow
    Write-Host "  ║     $($CONFIG.MT5Path)" -ForegroundColor White
    Write-Host "  ║  3. Terminez l'installation                                ║" -ForegroundColor Yellow
    Write-Host "  ║                                                            ║" -ForegroundColor Yellow
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""

    # Launch installer
    Start-Process -FilePath $mt5Installer -Wait

    # Verify installation
    if (Test-Path "$($CONFIG.MT5Path)\terminal64.exe") {
        # Configure portable mode
        Set-Content -Path "$($CONFIG.MT5Path)\portable.ini" -Value $portableIni -Encoding UTF8
        Write-Step "MT5 installé et configuré en mode portable" "SUCCESS"
    } else {
        Write-Step "MT5 non trouvé dans $($CONFIG.MT5Path)" "ERROR"
        Write-Step "Veuillez réinstaller MT5 dans le bon dossier" "ERROR"

        # Offer to retry
        $retry = Read-Host "Relancer l'installateur? (O/N)"
        if ($retry -eq "O" -or $retry -eq "o") {
            Start-Process -FilePath $mt5Installer -Wait
        }
    }

    Remove-Item $mt5Installer -Force -ErrorAction SilentlyContinue
}

#==============================================================================
# ÉTAPE 5: DÉPLOIEMENT DES FICHIERS EA
#==============================================================================

function Deploy-EAFiles {
    Write-Step "Déploiement des fichiers EA vers MT5..." "STEP"

    $deployments = @(
        @{
            Source = "$($CONFIG.ProjectPath)\EA\MQL5\*.mq5"
            Dest = "$($CONFIG.MT5Path)\MQL5\Experts"
            Name = "Expert Advisors (.mq5)"
        },
        @{
            Source = "$($CONFIG.ProjectPath)\backtests\*.mqh"
            Dest = "$($CONFIG.MT5Path)\MQL5\Include"
            Name = "Include Files (.mqh)"
        },
        @{
            Source = "$($CONFIG.ProjectPath)\backtests\*.mq5"
            Dest = "$($CONFIG.MT5Path)\MQL5\Scripts"
            Name = "Scripts (.mq5)"
        },
        @{
            Source = "$($CONFIG.ProjectPath)\config\profiles\*.set"
            Dest = "$($CONFIG.MT5Path)\MQL5\Presets"
            Name = "Presets (.set)"
        }
    )

    $totalDeployed = 0

    foreach ($deployment in $deployments) {
        # Create destination if needed
        if (-not (Test-Path $deployment.Dest)) {
            New-Item -ItemType Directory -Path $deployment.Dest -Force | Out-Null
        }

        $files = Get-ChildItem -Path $deployment.Source -ErrorAction SilentlyContinue
        if ($files) {
            foreach ($file in $files) {
                Copy-Item -Path $file.FullName -Destination $deployment.Dest -Force
                $totalDeployed++
            }
            Write-Step "$($deployment.Name): $($files.Count) fichiers" "SUCCESS"
        }
    }

    Write-Step "Total déployé: $totalDeployed fichiers" "SUCCESS"
}

#==============================================================================
# ÉTAPE 6: CONFIGURATION DU SERVICE AUTO-DEPLOY
#==============================================================================

function Install-DeployService {
    Write-Step "Configuration du service de déploiement automatique..." "STEP"

    $serviceName = "PropFirmEA_DeployAgent"
    $deployScript = "$($CONFIG.ProjectPath)\deployment\deploy_agent.ps1"

    # Create the scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$deployScript`" -GitRepo `"$($CONFIG.GitRepo)`" -ConfigPath `"$($CONFIG.InstallPath)\Config\project_config.json`""

    $trigger = New-ScheduledTaskTrigger -AtStartup

    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0)

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $serviceName -Confirm:$false -ErrorAction SilentlyContinue

    # Create new task
    Register-ScheduledTask -TaskName $serviceName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Force | Out-Null

    Write-Step "Service '$serviceName' créé" "SUCCESS"

    # Start the service
    Start-ScheduledTask -TaskName $serviceName
    Write-Step "Service démarré" "SUCCESS"
}

#==============================================================================
# ÉTAPE 7: CRÉATION FICHIERS HELPER
#==============================================================================

function Create-HelperScripts {
    Write-Step "Création des scripts helper..." "STEP"

    # Start MT5 script
    $startScript = @"
@echo off
echo Starting MT5 PropFirm (Isolated Instance)...
cd /d "$($CONFIG.MT5Path)"
start "" "terminal64.exe" /portable
echo MT5 PropFirm started.
timeout /t 3
"@
    Set-Content -Path "$($CONFIG.InstallPath)\Start_MT5.bat" -Value $startScript -Encoding ASCII

    # Stop MT5 script
    $stopScript = @"
@echo off
echo Stopping MT5 PropFirm...
taskkill /F /FI "WINDOWTITLE eq *PropFirm*" 2>nul
taskkill /F /FI "MODULES eq $($CONFIG.MT5Path)\*" 2>nul
echo Done.
timeout /t 2
"@
    Set-Content -Path "$($CONFIG.InstallPath)\Stop_MT5.bat" -Value $stopScript -Encoding ASCII

    # Status script
    $statusScript = @"
@echo off
echo.
echo ========================================
echo   PropFirm EA - Status
echo ========================================
echo.
echo MT5 Processes:
tasklist /FI "IMAGENAME eq terminal64.exe" 2>nul | findstr terminal64
echo.
echo Deploy Service:
schtasks /query /TN "PropFirmEA_DeployAgent" 2>nul | findstr -i "running ready"
echo.
echo Recent Deployments:
type "$($CONFIG.LogPath)\deploy_*.log" 2>nul | findstr /C:"DEPLOY" | more
echo.
pause
"@
    Set-Content -Path "$($CONFIG.InstallPath)\Status.bat" -Value $statusScript -Encoding ASCII

    # Manual deploy script
    $manualDeployScript = @"
@echo off
echo Manual deployment...
cd /d "$($CONFIG.ProjectPath)"
git pull origin main
powershell -ExecutionPolicy Bypass -File "$($CONFIG.ProjectPath)\deployment\deploy_agent.ps1" -RunOnce -ForceDeploy
pause
"@
    Set-Content -Path "$($CONFIG.InstallPath)\Manual_Deploy.bat" -Value $manualDeployScript -Encoding ASCII

    # Project config
    $configJson = @{
        project_name = "PropFirmEA"
        install_path = $CONFIG.InstallPath
        mt5_path = $CONFIG.MT5Path
        project_path = $CONFIG.ProjectPath
        log_path = $CONFIG.LogPath
        git_repo = $CONFIG.GitRepo
        broker_server = $CONFIG.BrokerServer
        created_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        experts_path = "$($CONFIG.MT5Path)\MQL5\Experts"
        include_path = "$($CONFIG.MT5Path)\MQL5\Include"
        scripts_path = "$($CONFIG.MT5Path)\MQL5\Scripts"
        presets_path = "$($CONFIG.MT5Path)\MQL5\Presets"
    } | ConvertTo-Json -Depth 3

    Set-Content -Path "$($CONFIG.InstallPath)\Config\project_config.json" -Value $configJson -Encoding UTF8

    # Desktop shortcut
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\PropFirm EA.lnk")
        $Shortcut.TargetPath = "$($CONFIG.InstallPath)\Start_MT5.bat"
        $Shortcut.WorkingDirectory = $CONFIG.InstallPath
        $Shortcut.Description = "Démarrer MT5 PropFirm"
        $Shortcut.Save()
        Write-Step "Raccourci bureau créé" "SUCCESS"
    } catch {
        Write-Step "Impossible de créer le raccourci bureau" "WARN"
    }

    Write-Step "Scripts helper créés" "SUCCESS"
}

#==============================================================================
# ÉTAPE 8: RÉSUMÉ FINAL
#==============================================================================

function Show-Summary {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                                               ║" -ForegroundColor Green
    Write-Host "  ║            INSTALLATION TERMINÉE AVEC SUCCÈS!                ║" -ForegroundColor Green
    Write-Host "  ║                                                               ║" -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  STRUCTURE INSTALLÉE:" -ForegroundColor Yellow
    Write-Host "  $($CONFIG.InstallPath)\" -ForegroundColor White
    Write-Host "  ├── MT5_PropFirm\        <- MT5 Isolé (ne touche pas votre autre MT5)" -ForegroundColor Gray
    Write-Host "  ├── Project\             <- Code source (synchronisé avec GitHub)" -ForegroundColor Gray
    Write-Host "  ├── Logs\                <- Logs de déploiement" -ForegroundColor Gray
    Write-Host "  ├── Start_MT5.bat        <- Démarrer MT5 PropFirm" -ForegroundColor Gray
    Write-Host "  ├── Stop_MT5.bat         <- Arrêter MT5 PropFirm" -ForegroundColor Gray
    Write-Host "  ├── Status.bat           <- Voir le statut" -ForegroundColor Gray
    Write-Host "  └── Manual_Deploy.bat    <- Forcer un déploiement" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  DÉPLOIEMENT AUTOMATIQUE:" -ForegroundColor Yellow
    Write-Host "  - Service: PropFirmEA_DeployAgent (actif)" -ForegroundColor White
    Write-Host "  - Intervalle: Vérifie GitHub toutes les 60 secondes" -ForegroundColor White
    Write-Host "  - Les modifications sur GitHub sont auto-déployées vers MT5" -ForegroundColor White
    Write-Host ""
    Write-Host "  PROCHAINES ÉTAPES:" -ForegroundColor Yellow
    Write-Host "  1. Double-cliquez sur 'PropFirm EA' sur le bureau" -ForegroundColor White
    Write-Host "  2. Connectez votre compte broker dans MT5" -ForegroundColor White
    Write-Host "  3. L'EA 'PropFirm_SMC_EA' sera disponible dans Navigator" -ForegroundColor White
    Write-Host ""
    Write-Host "  WORKFLOW QUOTIDIEN:" -ForegroundColor Yellow
    Write-Host "  - Modifiez le code sur votre PC avec Claude Code" -ForegroundColor White
    Write-Host "  - Faites 'git push'" -ForegroundColor White
    Write-Host "  - Les fichiers sont automatiquement déployés sur ce RDP!" -ForegroundColor White
    Write-Host ""
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

# Show banner
if (-not $Silent) {
    Show-Banner
}

Write-Host "  Installation Path: $($CONFIG.InstallPath)" -ForegroundColor Gray
Write-Host "  Git Repository: $($CONFIG.GitRepo)" -ForegroundColor Gray
Write-Host ""

# Execute steps
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
    Write-Step "ERREUR: $_" "ERROR"
    Write-Step "L'installation a échoué. Vérifiez les logs dans $($CONFIG.LogPath)" "ERROR"
    exit 1
}
