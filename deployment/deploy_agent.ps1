#==============================================================================
# AGENT DE DÉPLOIEMENT AUTOMATIQUE - PROPFIRM EA
# Ce script tourne en continu et déploie automatiquement les changements Git
#==============================================================================

param(
    [string]$ConfigPath = "C:\PropFirmEA\Config\project_config.json",
    [string]$GitRepo = "",  # URL du repo Git (à configurer)
    [string]$GitBranch = "main",
    [int]$PollIntervalSeconds = 60,  # Vérifier toutes les 60 secondes
    [switch]$RunOnce,  # Mode one-shot (pour tests)
    [switch]$ForceDeploy  # Forcer le déploiement même sans changements
)

#==============================================================================
# CONFIGURATION
#==============================================================================

$ErrorActionPreference = "Continue"
$script:LastCommitHash = ""
$script:DeployCount = 0

# Charger la configuration
function Load-Config {
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath | ConvertFrom-Json
    } else {
        Write-Error "Configuration non trouvée: $ConfigPath"
        Write-Host "Exécutez d'abord install_mt5_portable.ps1"
        exit 1
    }
}

$Config = Load-Config

# Paths
$ProjectPath = $Config.project_path
$MT5ExpertsPath = $Config.experts_path
$MT5IncludePath = $Config.include_path
$MT5ScriptsPath = $Config.scripts_path
$MT5PresetsPath = $Config.presets_path
$LogPath = $Config.log_path

#==============================================================================
# LOGGING
#==============================================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Console
    $color = switch($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        "DEPLOY"  { "Cyan" }
        default   { "White" }
    }
    Write-Host $logMessage -ForegroundColor $color

    # Fichier
    $logFile = Join-Path $LogPath "deploy_$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

#==============================================================================
# GIT OPERATIONS
#==============================================================================

function Test-GitInstalled {
    try {
        $null = git --version 2>&1
        return $true
    } catch {
        return $false
    }
}

function Initialize-GitRepo {
    param([string]$RepoUrl)

    if (-not (Test-Path $ProjectPath)) {
        New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
    }

    $gitDir = Join-Path $ProjectPath ".git"

    if (-not (Test-Path $gitDir)) {
        Write-Log "Clonage du repository..." "DEPLOY"
        Push-Location $ProjectPath
        try {
            git clone $RepoUrl . 2>&1 | ForEach-Object { Write-Log $_ }
            Write-Log "Repository cloné avec succès" "SUCCESS"
        } catch {
            Write-Log "Erreur de clonage: $_" "ERROR"
        }
        Pop-Location
    }
}

function Get-LatestCommit {
    Push-Location $ProjectPath
    try {
        $hash = git rev-parse HEAD 2>&1
        Pop-Location
        return $hash.Trim()
    } catch {
        Pop-Location
        return ""
    }
}

function Update-Repository {
    Push-Location $ProjectPath
    try {
        Write-Log "Fetch des changements..."
        git fetch origin $GitBranch 2>&1 | ForEach-Object { Write-Log $_ }

        $localHash = git rev-parse HEAD 2>&1
        $remoteHash = git rev-parse "origin/$GitBranch" 2>&1

        if ($localHash -ne $remoteHash) {
            Write-Log "Nouveaux changements détectés!" "DEPLOY"
            Write-Log "Local:  $localHash"
            Write-Log "Remote: $remoteHash"

            # Pull les changements
            git pull origin $GitBranch 2>&1 | ForEach-Object { Write-Log $_ }

            Pop-Location
            return $true
        } else {
            Pop-Location
            return $false
        }
    } catch {
        Write-Log "Erreur Git: $_" "ERROR"
        Pop-Location
        return $false
    }
}

#==============================================================================
# DEPLOYMENT
#==============================================================================

function Deploy-Files {
    Write-Log "========================================" "DEPLOY"
    Write-Log "DÉBUT DU DÉPLOIEMENT #$($script:DeployCount + 1)" "DEPLOY"
    Write-Log "========================================" "DEPLOY"

    $deployedFiles = 0
    $errors = 0

    # Mapping des dossiers source -> destination
    $mappings = @(
        @{
            Source = Join-Path $ProjectPath "EA\MQL5"
            Dest = Join-Path $Config.mt5_path "MQL5\Experts"
            Pattern = "*.mq5"
            Description = "Expert Advisors"
        },
        @{
            Source = Join-Path $ProjectPath "EA\MQL5"
            Dest = Join-Path $Config.mt5_path "MQL5\Experts"
            Pattern = "*.ex5"
            Description = "Expert Advisors (compilés)"
        },
        @{
            Source = Join-Path $ProjectPath "backtests"
            Dest = Join-Path $Config.mt5_path "MQL5\Include"
            Pattern = "*.mqh"
            Description = "Include Files"
        },
        @{
            Source = Join-Path $ProjectPath "backtests"
            Dest = Join-Path $Config.mt5_path "MQL5\Scripts"
            Pattern = "*.mq5"
            Description = "Scripts"
        },
        @{
            Source = Join-Path $ProjectPath "config\profiles"
            Dest = Join-Path $Config.mt5_path "MQL5\Presets"
            Pattern = "*.set"
            Description = "Presets/Configurations"
        }
    )

    foreach ($mapping in $mappings) {
        if (Test-Path $mapping.Source) {
            Write-Log "Déploiement: $($mapping.Description)..."

            # Créer le dossier de destination si nécessaire
            if (-not (Test-Path $mapping.Dest)) {
                New-Item -ItemType Directory -Path $mapping.Dest -Force | Out-Null
            }

            # Copier les fichiers
            $files = Get-ChildItem -Path $mapping.Source -Filter $mapping.Pattern -Recurse -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                try {
                    $destFile = Join-Path $mapping.Dest $file.Name
                    Copy-Item -Path $file.FullName -Destination $destFile -Force
                    Write-Log "  ✓ $($file.Name)" "SUCCESS"
                    $deployedFiles++
                } catch {
                    Write-Log "  ✗ $($file.Name): $_" "ERROR"
                    $errors++
                }
            }
        }
    }

    # Copier aussi les fichiers Python de backtest (optionnel)
    $pythonDest = Join-Path $Config.install_path "Tools"
    if (-not (Test-Path $pythonDest)) {
        New-Item -ItemType Directory -Path $pythonDest -Force | Out-Null
    }

    $pythonFiles = Get-ChildItem -Path (Join-Path $ProjectPath "backtests") -Filter "*.py" -ErrorAction SilentlyContinue
    foreach ($file in $pythonFiles) {
        try {
            Copy-Item -Path $file.FullName -Destination (Join-Path $pythonDest $file.Name) -Force
            Write-Log "  ✓ [Python] $($file.Name)" "SUCCESS"
            $deployedFiles++
        } catch {
            Write-Log "  ✗ [Python] $($file.Name): $_" "ERROR"
            $errors++
        }
    }

    # Résumé
    Write-Log "========================================" "DEPLOY"
    Write-Log "DÉPLOIEMENT TERMINÉ" "DEPLOY"
    Write-Log "  Fichiers déployés: $deployedFiles" "SUCCESS"
    if ($errors -gt 0) {
        Write-Log "  Erreurs: $errors" "ERROR"
    }
    Write-Log "========================================" "DEPLOY"

    $script:DeployCount++

    # Notification (optionnel - peut être étendu)
    Send-Notification -Title "PropFirm EA Deployed" -Message "$deployedFiles fichiers déployés"

    return ($errors -eq 0)
}

function Send-Notification {
    param(
        [string]$Title,
        [string]$Message
    )

    # Windows Toast Notification (Windows 10+)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)

        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PropFirm EA").Show($toast)
    } catch {
        # Silently fail if notifications not available
    }
}

#==============================================================================
# SERVICE MODE
#==============================================================================

function Start-DeploymentLoop {
    Write-Log "========================================" "INFO"
    Write-Log "DÉMARRAGE DE L'AGENT DE DÉPLOIEMENT" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Repository: $GitRepo"
    Write-Log "Branche: $GitBranch"
    Write-Log "Intervalle: $PollIntervalSeconds secondes"
    Write-Log "MT5 Path: $($Config.mt5_path)"
    Write-Log ""

    # Initialiser le repo si nécessaire
    if ($GitRepo) {
        Initialize-GitRepo -RepoUrl $GitRepo
    }

    # Déploiement initial
    if ($ForceDeploy -or $RunOnce) {
        Deploy-Files
    }

    if ($RunOnce) {
        Write-Log "Mode RunOnce - Arrêt de l'agent" "INFO"
        return
    }

    # Boucle principale
    Write-Log "Entrée en mode surveillance..." "INFO"

    while ($true) {
        try {
            $hasChanges = Update-Repository

            if ($hasChanges) {
                Deploy-Files
            }
        } catch {
            Write-Log "Erreur dans la boucle principale: $_" "ERROR"
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }
}

#==============================================================================
# INSTALLATION EN TANT QUE SERVICE
#==============================================================================

function Install-AsScheduledTask {
    param(
        [string]$TaskName = "PropFirmEA_DeployAgent"
    )

    Write-Log "Installation de la tâche planifiée..." "INFO"

    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`" -GitRepo `"$GitRepo`" -GitBranch `"$GitBranch`""

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

    Write-Log "Tâche planifiée '$TaskName' installée" "SUCCESS"
    Write-Log "L'agent démarrera automatiquement au boot" "INFO"
}

function Uninstall-ScheduledTask {
    param(
        [string]$TaskName = "PropFirmEA_DeployAgent"
    )

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Tâche planifiée '$TaskName' supprimée" "SUCCESS"
}

#==============================================================================
# MAIN
#==============================================================================

# Vérifier Git
if (-not (Test-GitInstalled)) {
    Write-Log "Git n'est pas installé! Installez Git for Windows." "ERROR"
    Write-Host "Téléchargez Git: https://git-scm.com/download/win"
    exit 1
}

# Menu si aucun repo spécifié
if (-not $GitRepo) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "     PROPFIRM EA - AGENT DE DÉPLOIEMENT" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Aucun repository Git spécifié."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\deploy_agent.ps1 -GitRepo 'https://github.com/user/repo.git'"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -GitRepo         URL du repository Git"
    Write-Host "  -GitBranch       Branche à suivre (défaut: main)"
    Write-Host "  -PollInterval    Intervalle en secondes (défaut: 60)"
    Write-Host "  -RunOnce         Déployer une fois et quitter"
    Write-Host "  -ForceDeploy     Forcer le déploiement initial"
    Write-Host ""
    Write-Host "Pour installer en service:"
    Write-Host "  .\deploy_agent.ps1 -GitRepo '...' | Install-AsScheduledTask"
    Write-Host ""

    # Mode interactif
    $GitRepo = Read-Host "Entrez l'URL du repository Git (ou appuyez sur Entrée pour déploiement local)"

    if ([string]::IsNullOrWhiteSpace($GitRepo)) {
        Write-Log "Mode déploiement local (sans Git)" "INFO"
        $ForceDeploy = $true
        $RunOnce = $true

        # Utiliser le chemin local
        $ProjectPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
        Write-Log "Source: $ProjectPath" "INFO"

        Deploy-Files
        exit 0
    }
}

# Démarrer l'agent
Start-DeploymentLoop
