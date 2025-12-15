#==============================================================================
# INSTALLATION MT5 PORTABLE POUR PROPFIRM EA
# Ce script installe une instance MT5 isolée pour le projet PropFirm
#==============================================================================

param(
    [string]$InstallPath = "C:\PropFirmEA",
    [string]$MT5DownloadUrl = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe",
    [string]$BrokerServer = "ICMarketsSC-Demo",  # Changer selon votre broker
    [switch]$Force
)

# Configuration
$ErrorActionPreference = "Stop"
$MT5PortablePath = "$InstallPath\MT5_PropFirm"
$ProjectPath = "$InstallPath\Project"
$LogPath = "$InstallPath\Logs"

#==============================================================================
# FONCTIONS
#==============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    })

    if (Test-Path $LogPath) {
        Add-Content -Path "$LogPath\install.log" -Value $logMessage
    }
}

function Test-MT5Running {
    param([string]$Path)
    $processes = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue
    foreach ($proc in $processes) {
        if ($proc.Path -like "$Path*") {
            return $true
        }
    }
    return $false
}

function Get-MT5Instances {
    $instances = @()
    $processes = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue
    foreach ($proc in $processes) {
        $instances += @{
            PID = $proc.Id
            Path = $proc.Path
            StartTime = $proc.StartTime
        }
    }
    return $instances
}

#==============================================================================
# MAIN
#==============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     INSTALLATION MT5 PORTABLE - PROPFIRM EA PROJECT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier les instances MT5 existantes
Write-Log "Vérification des instances MT5 existantes..."
$existingMT5 = Get-MT5Instances
if ($existingMT5.Count -gt 0) {
    Write-Log "Instances MT5 détectées:" "WARN"
    foreach ($inst in $existingMT5) {
        Write-Log "  PID: $($inst.PID) - Path: $($inst.Path)" "WARN"
    }
    Write-Host ""
}

# Créer la structure de dossiers
Write-Log "Création de la structure de dossiers..."

$folders = @(
    $InstallPath,
    $MT5PortablePath,
    $ProjectPath,
    $LogPath,
    "$InstallPath\Backups",
    "$InstallPath\Config"
)

foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Log "Créé: $folder"
    }
}

# Vérifier si MT5 est déjà installé
if ((Test-Path "$MT5PortablePath\terminal64.exe") -and -not $Force) {
    Write-Log "MT5 Portable déjà installé dans $MT5PortablePath" "WARN"
    Write-Log "Utilisez -Force pour réinstaller" "WARN"
} else {
    # Télécharger MT5
    Write-Log "Téléchargement de MetaTrader 5..."
    $setupPath = "$env:TEMP\mt5setup.exe"

    try {
        Invoke-WebRequest -Uri $MT5DownloadUrl -OutFile $setupPath -UseBasicParsing
        Write-Log "Téléchargement terminé" "SUCCESS"
    } catch {
        Write-Log "Erreur de téléchargement: $_" "ERROR"
        exit 1
    }

    # Installer en mode portable
    Write-Log "Installation de MT5 en mode portable..."
    Write-Log "IMPORTANT: Choisissez '$MT5PortablePath' comme dossier d'installation!" "WARN"

    # Lancer l'installateur
    Start-Process -FilePath $setupPath -ArgumentList "/auto" -Wait

    Write-Log "Veuillez terminer l'installation manuellement si nécessaire" "WARN"
}

# Créer le fichier de configuration portable
Write-Log "Configuration du mode portable..."
$portableIni = @"
; MT5 Portable Configuration
; Ce fichier force MT5 à utiliser ce dossier pour toutes les données

[Portable]
; Utiliser le dossier local pour les données
DataPath=$MT5PortablePath

[Common]
; Isolation des données
Login=0
Server=$BrokerServer
"@

Set-Content -Path "$MT5PortablePath\portable.ini" -Value $portableIni -Encoding UTF8

# Créer le fichier de démarrage
Write-Log "Création du script de démarrage..."
$startScript = @"
@echo off
REM Démarrage MT5 PropFirm (Instance Isolée)
REM =========================================

echo Starting MT5 PropFirm Instance...
echo Path: $MT5PortablePath

REM Vérifier qu'on ne lance pas l'autre MT5 par erreur
cd /d "$MT5PortablePath"
start "" "terminal64.exe" /portable

echo MT5 PropFirm started.
"@

Set-Content -Path "$InstallPath\Start_MT5_PropFirm.bat" -Value $startScript -Encoding ASCII

# Créer le script d'arrêt
$stopScript = @"
@echo off
REM Arrêt MT5 PropFirm (Instance Isolée)
REM ====================================

echo Stopping MT5 PropFirm Instance...

REM Trouver et arrêter uniquement l'instance PropFirm
for /f "tokens=2" %%a in ('tasklist /v /fi "imagename eq terminal64.exe" ^| findstr /i "PropFirm"') do (
    echo Killing PID: %%a
    taskkill /PID %%a /F
)

echo Done.
"@

Set-Content -Path "$InstallPath\Stop_MT5_PropFirm.bat" -Value $stopScript -Encoding ASCII

# Créer le fichier de configuration du projet
Write-Log "Création de la configuration du projet..."
$configJson = @{
    project_name = "PropFirmEA"
    install_path = $InstallPath
    mt5_path = $MT5PortablePath
    project_path = $ProjectPath
    log_path = $LogPath
    broker_server = $BrokerServer
    created_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    mt5_data_path = "$MT5PortablePath\MQL5"
    experts_path = "$MT5PortablePath\MQL5\Experts"
    include_path = "$MT5PortablePath\MQL5\Include"
    scripts_path = "$MT5PortablePath\MQL5\Scripts"
    presets_path = "$MT5PortablePath\MQL5\Presets"
} | ConvertTo-Json -Depth 3

Set-Content -Path "$InstallPath\Config\project_config.json" -Value $configJson -Encoding UTF8

# Créer les liens symboliques pour faciliter l'accès (optionnel)
Write-Log "Création des raccourcis..."

# Raccourci bureau
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\MT5 PropFirm.lnk")
$Shortcut.TargetPath = "$InstallPath\Start_MT5_PropFirm.bat"
$Shortcut.WorkingDirectory = $InstallPath
$Shortcut.Description = "Démarrer MT5 PropFirm (Instance Isolée)"
$Shortcut.Save()

# Résumé
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "              INSTALLATION TERMINÉE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Log "Installation Path: $InstallPath" "SUCCESS"
Write-Log "MT5 Portable Path: $MT5PortablePath" "SUCCESS"
Write-Log "Project Path: $ProjectPath" "SUCCESS"
Write-Host ""
Write-Host "STRUCTURE CRÉÉE:" -ForegroundColor Yellow
Write-Host "  $InstallPath\"
Write-Host "  ├── MT5_PropFirm\          # Instance MT5 isolée"
Write-Host "  │   └── MQL5\"
Write-Host "  │       ├── Experts\       # Vos EAs"
Write-Host "  │       ├── Include\       # Fichiers include"
Write-Host "  │       ├── Scripts\       # Scripts"
Write-Host "  │       └── Presets\       # Configurations"
Write-Host "  ├── Project\               # Code source (Git)"
Write-Host "  ├── Logs\                  # Logs de déploiement"
Write-Host "  ├── Config\                # Configuration"
Write-Host "  ├── Start_MT5_PropFirm.bat # Démarrer MT5"
Write-Host "  └── Stop_MT5_PropFirm.bat  # Arrêter MT5"
Write-Host ""
Write-Host "PROCHAINES ÉTAPES:" -ForegroundColor Yellow
Write-Host "  1. Lancer Start_MT5_PropFirm.bat"
Write-Host "  2. Configurer votre compte broker dans MT5"
Write-Host "  3. Exécuter le script de déploiement"
Write-Host ""
