#==============================================================================
# CONFIGURATION GIT POUR DÉPLOIEMENT AUTOMATIQUE
# Script de configuration initiale sur le RDP
#==============================================================================

param(
    [string]$GitRepo = "",
    [string]$GitBranch = "main",
    [string]$GitUsername = "",
    [string]$GitEmail = "",
    [switch]$UseSSH,
    [switch]$InstallGit
)

$ErrorActionPreference = "Stop"

#==============================================================================
# FONCTIONS
#==============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ">>> $Message" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor DarkGray
}

function Install-GitForWindows {
    Write-Step "Installation de Git for Windows"

    $gitInstaller = "$env:TEMP\GitInstaller.exe"
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"

    Write-Host "Téléchargement de Git..."
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

    Write-Host "Installation silencieuse..."
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait

    # Rafraîchir le PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Remove-Item $gitInstaller -Force

    Write-Host "Git installé avec succès!" -ForegroundColor Green
}

function Test-GitInstalled {
    try {
        $version = git --version 2>&1
        Write-Host "Git détecté: $version" -ForegroundColor Green
        return $true
    } catch {
        return $false
    }
}

function Configure-GitCredentials {
    param(
        [string]$Username,
        [string]$Email
    )

    Write-Step "Configuration des identifiants Git"

    if ($Username) {
        git config --global user.name $Username
        Write-Host "Username configuré: $Username"
    }

    if ($Email) {
        git config --global user.email $Email
        Write-Host "Email configuré: $Email"
    }

    # Credential helper pour HTTPS
    git config --global credential.helper manager

    Write-Host "Credential helper activé (Windows Credential Manager)" -ForegroundColor Green
}

function Setup-SSHKey {
    Write-Step "Configuration des clés SSH"

    $sshDir = "$env:USERPROFILE\.ssh"
    $keyPath = "$sshDir\id_ed25519"

    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    if (-not (Test-Path $keyPath)) {
        Write-Host "Génération d'une nouvelle clé SSH..."

        # Générer la clé
        ssh-keygen -t ed25519 -C "$GitEmail" -f $keyPath -N '""'

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "IMPORTANT: Ajoutez cette clé publique à votre compte GitHub:" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host ""
        Get-Content "$keyPath.pub"
        Write-Host ""
        Write-Host "1. Allez sur https://github.com/settings/keys"
        Write-Host "2. Cliquez 'New SSH key'"
        Write-Host "3. Collez la clé ci-dessus"
        Write-Host ""

        Read-Host "Appuyez sur Entrée une fois la clé ajoutée à GitHub"
    } else {
        Write-Host "Clé SSH existante trouvée: $keyPath"
    }

    # Configurer SSH pour GitHub
    $sshConfig = @"
Host github.com
    HostName github.com
    User git
    IdentityFile $keyPath
    IdentitiesOnly yes
"@

    $sshConfigPath = "$sshDir\config"
    if (-not (Test-Path $sshConfigPath)) {
        Set-Content -Path $sshConfigPath -Value $sshConfig
        Write-Host "Configuration SSH créée"
    }

    # Tester la connexion
    Write-Host "Test de la connexion SSH à GitHub..."
    ssh -T git@github.com 2>&1
}

function Create-DeploymentService {
    Write-Step "Création du service de déploiement"

    $serviceName = "PropFirmEA_DeployAgent"
    $scriptPath = "C:\PropFirmEA\deployment\deploy_agent.ps1"

    # Créer le dossier deployment sur le RDP
    $deployDir = "C:\PropFirmEA\deployment"
    if (-not (Test-Path $deployDir)) {
        New-Item -ItemType Directory -Path $deployDir -Force | Out-Null
    }

    # Copier le script (si on est sur la machine locale)
    $localScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "deploy_agent.ps1"
    if (Test-Path $localScript) {
        Copy-Item -Path $localScript -Destination $scriptPath -Force
        Write-Host "Script de déploiement copié vers $scriptPath"
    }

    # Créer la tâche planifiée
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -GitRepo `"$GitRepo`" -GitBranch `"$GitBranch`""

    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)

    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # Pas de limite

    # Supprimer si existe
    Unregister-ScheduledTask -TaskName $serviceName -Confirm:$false -ErrorAction SilentlyContinue

    # Créer
    Register-ScheduledTask -TaskName $serviceName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Force

    Write-Host "Service '$serviceName' créé et configuré" -ForegroundColor Green
    Write-Host "Le service démarrera automatiquement au boot"

    # Démarrer maintenant
    Start-ScheduledTask -TaskName $serviceName
    Write-Host "Service démarré!" -ForegroundColor Green
}

#==============================================================================
# MAIN
#==============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     CONFIGURATION GIT POUR PROPFIRM EA" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier/Installer Git
if ($InstallGit -or -not (Test-GitInstalled)) {
    $install = Read-Host "Git n'est pas installé. Installer maintenant? (O/N)"
    if ($install -eq "O" -or $install -eq "o") {
        Install-GitForWindows
    } else {
        Write-Host "Git est requis. Installation annulée." -ForegroundColor Red
        exit 1
    }
}

# 2. Demander les informations si non fournies
if (-not $GitRepo) {
    Write-Host ""
    Write-Host "Entrez les informations de votre repository:" -ForegroundColor Yellow
    $GitRepo = Read-Host "URL du repository Git"
}

if (-not $GitUsername) {
    $GitUsername = Read-Host "Votre nom d'utilisateur Git"
}

if (-not $GitEmail) {
    $GitEmail = Read-Host "Votre email Git"
}

# 3. Configurer Git
Configure-GitCredentials -Username $GitUsername -Email $GitEmail

# 4. SSH ou HTTPS?
if ($UseSSH) {
    Setup-SSHKey
}

# 5. Créer le service de déploiement
$createService = Read-Host "Créer le service de déploiement automatique? (O/N)"
if ($createService -eq "O" -or $createService -eq "o") {
    Create-DeploymentService
}

# Résumé
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "              CONFIGURATION TERMINÉE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Repository: $GitRepo"
Write-Host "Branche: $GitBranch"
Write-Host "Username: $GitUsername"
Write-Host ""
Write-Host "PROCHAINES ÉTAPES:" -ForegroundColor Yellow
Write-Host "1. Créez le repository sur GitHub si pas encore fait"
Write-Host "2. Push votre code local vers le repository"
Write-Host "3. L'agent de déploiement synchronisera automatiquement"
Write-Host ""
