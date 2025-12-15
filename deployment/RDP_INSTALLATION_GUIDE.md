# Guide d'Installation RDP - PropFirm EA

> Guide complet pour déployer le système PropFirm EA sur votre serveur RDP

---

## Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ARCHITECTURE FINALE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  VOTRE PC LOCAL                                 VOTRE RDP/VPS               │
│  ┌───────────────────┐                         ┌───────────────────────┐    │
│  │                   │                         │                       │    │
│  │  Claude Code      │    git push             │  Deploy Agent         │    │
│  │  ┌─────────────┐  │ ─────────────────────►  │  (auto-sync Git)      │    │
│  │  │ PropFirmEA  │  │                         │         │             │    │
│  │  │ Project     │  │                         │         ▼             │    │
│  │  └─────────────┘  │                         │  ┌─────────────────┐  │    │
│  │                   │                         │  │ MT5 PropFirm    │  │    │
│  └───────────────────┘                         │  │ (Portable)      │  │    │
│                                                │  └─────────────────┘  │    │
│                         GitHub                 │                       │    │
│                      ┌──────────┐              │  ┌─────────────────┐  │    │
│                      │   Repo   │              │  │ MT5 Existant    │  │    │
│                      │ PropFirm │              │  │ (Autre projet)  │  │    │
│                      └──────────┘              │  └─────────────────┘  │    │
│                                                │                       │    │
│                                                └───────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Prérequis

### Sur le RDP/VPS

- Windows 10/11 ou Windows Server 2016+
- Droits administrateur
- Connexion Internet stable
- Au moins 4GB RAM disponibles
- 10GB d'espace disque libre

### Comptes nécessaires

- [ ] Compte GitHub (gratuit)
- [ ] Compte broker avec accès démo (IC Markets, Pepperstone, etc.)

---

## Installation Étape par Étape

### Étape 1: Préparation Locale (Sur votre PC)

#### 1.1 Créer le Repository GitHub

```bash
# 1. Allez sur https://github.com/new
# 2. Nom: PropFirmEA (ou autre)
# 3. Privé recommandé
# 4. NE PAS initialiser avec README (on push notre code)
```

#### 1.2 Initialiser Git dans le projet

```powershell
# Ouvrir PowerShell dans le dossier du projet
cd C:\Users\cgemi\PropFirmEA_Project

# Initialiser Git
git init

# Créer .gitignore
@"
# MT5 Generated Files
*.ex5
*.ex4
logs/
*.log

# IDE
.vscode/
.idea/

# System
Thumbs.db
.DS_Store

# Sensitive
*.env
credentials.json
"@ | Out-File -FilePath .gitignore -Encoding UTF8

# Premier commit
git add .
git commit -m "Initial commit: PropFirm EA Project"

# Connecter à GitHub (remplacer par votre URL)
git remote add origin https://github.com/VOTRE_USERNAME/PropFirmEA.git
git branch -M main
git push -u origin main
```

### Étape 2: Installation sur le RDP

#### 2.1 Se connecter au RDP

```
1. Ouvrir "Connexion Bureau à Distance" (mstsc)
2. Entrer l'IP de votre VPS
3. Se connecter avec vos identifiants
```

#### 2.2 Télécharger les scripts d'installation

**Option A: Via PowerShell (recommandé)**

```powershell
# Ouvrir PowerShell en tant qu'Administrateur

# Créer le dossier de base
New-Item -ItemType Directory -Path "C:\PropFirmEA" -Force
cd C:\PropFirmEA

# Télécharger les scripts depuis votre repo
# (Remplacer par l'URL de votre repo)
$repoUrl = "https://raw.githubusercontent.com/VOTRE_USERNAME/PropFirmEA/main"

Invoke-WebRequest -Uri "$repoUrl/deployment/install_mt5_portable.ps1" -OutFile "install_mt5_portable.ps1"
Invoke-WebRequest -Uri "$repoUrl/deployment/deploy_agent.ps1" -OutFile "deploy_agent.ps1"
Invoke-WebRequest -Uri "$repoUrl/deployment/setup_git_sync.ps1" -OutFile "setup_git_sync.ps1"
```

**Option B: Copie manuelle**

```
1. Copier le dossier "deployment" depuis votre PC local
2. Via RDP, coller dans C:\PropFirmEA\
```

#### 2.3 Installer MT5 Portable

```powershell
# Toujours en PowerShell Admin
cd C:\PropFirmEA

# Exécuter le script d'installation
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install_mt5_portable.ps1
```

**Ce que fait ce script:**
- Crée la structure `C:\PropFirmEA\`
- Télécharge et installe MT5 dans `C:\PropFirmEA\MT5_PropFirm\`
- Configure le mode portable (isolation des données)
- Crée les scripts de démarrage/arrêt

#### 2.4 Configurer MT5 PropFirm

```
1. Lancer: C:\PropFirmEA\Start_MT5_PropFirm.bat
2. Dans MT5:
   - Fichier > Ouvrir un compte
   - Sélectionner votre broker (ex: IC Markets)
   - Créer/connecter compte démo
3. Vérifier que cette instance est SÉPARÉE de votre autre MT5
```

#### 2.5 Configurer le Déploiement Automatique

```powershell
# Exécuter le script de configuration Git
.\setup_git_sync.ps1

# Suivre les instructions:
# - Entrer l'URL de votre repo GitHub
# - Configurer vos identifiants Git
# - Créer le service de déploiement
```

---

## Configuration du Service de Déploiement

### Méthode 1: Tâche Planifiée (Recommandé)

Le script `setup_git_sync.ps1` crée automatiquement une tâche planifiée qui:
- Démarre au boot du serveur
- Vérifie les changements Git toutes les 60 secondes
- Déploie automatiquement vers MT5

**Vérifier le statut:**

```powershell
# Voir la tâche
Get-ScheduledTask -TaskName "PropFirmEA_DeployAgent"

# Voir les logs
Get-Content "C:\PropFirmEA\Logs\deploy_*.log" -Tail 50

# Redémarrer manuellement
Start-ScheduledTask -TaskName "PropFirmEA_DeployAgent"
```

### Méthode 2: Service Windows (Avancé)

Pour une solution plus robuste, on peut créer un service Windows:

```powershell
# Installer NSSM (Non-Sucking Service Manager)
# Télécharger depuis https://nssm.cc/download

nssm install PropFirmEA_Deploy "powershell.exe" "-ExecutionPolicy Bypass -File C:\PropFirmEA\deploy_agent.ps1 -GitRepo https://github.com/USER/REPO.git"
nssm set PropFirmEA_Deploy DisplayName "PropFirm EA Deploy Agent"
nssm set PropFirmEA_Deploy Description "Auto-deploy PropFirm EA from Git"
nssm set PropFirmEA_Deploy Start SERVICE_AUTO_START
nssm start PropFirmEA_Deploy
```

---

## Workflow Quotidien

### Développement (Sur votre PC local avec Claude Code)

```bash
# 1. Faire vos modifications
# 2. Tester localement si possible

# 3. Commiter et pusher
git add .
git commit -m "feat: Amélioration du filtre de news"
git push origin main

# 4. Le RDP synchronise automatiquement (< 60 secondes)
```

### Vérification sur le RDP

```powershell
# Voir les derniers déploiements
Get-Content "C:\PropFirmEA\Logs\deploy_$(Get-Date -Format 'yyyy-MM-dd').log" -Tail 20

# Vérifier que les fichiers sont à jour
dir "C:\PropFirmEA\MT5_PropFirm\MQL5\Experts\"
```

---

## Isolation des Instances MT5

### Comment ça fonctionne

```
C:\
├── [Votre MT5 existant]           # NE PAS TOUCHER
│   └── MQL5\
│       └── Experts\               # Vos autres EAs
│
└── PropFirmEA\                    # NOTRE PROJET
    ├── MT5_PropFirm\              # Instance MT5 isolée
    │   ├── terminal64.exe
    │   ├── portable.ini           # Force le mode portable
    │   └── MQL5\
    │       └── Experts\           # Nos EAs uniquement
    │
    └── Project\                   # Code source (Git)
```

### Points Importants

1. **Données séparées**: Chaque MT5 a ses propres données dans son dossier
2. **Configurations séparées**: Les paramètres ne se mélangent pas
3. **Comptes séparés**: Vous pouvez avoir des comptes différents sur chaque instance
4. **Processus séparés**: Les deux MT5 tournent indépendamment

### Vérification de l'Isolation

```powershell
# Voir tous les MT5 en cours d'exécution
Get-Process -Name "terminal64" | Select-Object Id, Path, StartTime

# Devrait montrer 2 processus avec des chemins différents:
# - Votre MT5 existant
# - C:\PropFirmEA\MT5_PropFirm\terminal64.exe
```

---

## Dépannage

### Le déploiement ne fonctionne pas

```powershell
# 1. Vérifier que Git est installé
git --version

# 2. Vérifier le service
Get-ScheduledTask -TaskName "PropFirmEA_DeployAgent" | Select-Object State

# 3. Voir les erreurs
Get-Content "C:\PropFirmEA\Logs\deploy_*.log" -Tail 100 | Select-String "ERROR"

# 4. Tester manuellement
cd C:\PropFirmEA\Project
git pull origin main
```

### MT5 ne démarre pas

```powershell
# 1. Vérifier les processus
Get-Process -Name "terminal64" -ErrorAction SilentlyContinue

# 2. Lancer manuellement pour voir les erreurs
cd C:\PropFirmEA\MT5_PropFirm
.\terminal64.exe /portable

# 3. Vérifier les logs MT5
Get-Content "C:\PropFirmEA\MT5_PropFirm\logs\*.log" -Tail 50
```

### Conflit avec l'autre MT5

```powershell
# Vérifier que les chemins sont bien séparés
Get-Process -Name "terminal64" | ForEach-Object {
    Write-Host "PID: $($_.Id) - Path: $($_.Path)"
}

# Si conflit, redémarrer l'instance PropFirm
C:\PropFirmEA\Stop_MT5_PropFirm.bat
Start-Sleep -Seconds 5
C:\PropFirmEA\Start_MT5_PropFirm.bat
```

---

## Sécurité

### Recommandations

1. **Repository privé**: Gardez votre code sur un repo GitHub privé
2. **Identifiants**: Ne commitez JAMAIS de mots de passe ou clés API
3. **Firewall**: Le RDP ne devrait exposer que le port RDP (3389)
4. **2FA**: Activez l'authentification à deux facteurs sur GitHub

### Fichier .env (si nécessaire)

```bash
# Créer sur le RDP uniquement (pas dans Git)
# C:\PropFirmEA\Config\.env

BROKER_LOGIN=12345678
BROKER_PASSWORD=secret
BROKER_SERVER=ICMarketsSC-Demo
```

---

## Checklist d'Installation

### Sur votre PC local

- [ ] Repository GitHub créé
- [ ] Code pushé sur GitHub
- [ ] Webhook configuré (optionnel)

### Sur le RDP

- [ ] Scripts téléchargés dans `C:\PropFirmEA\`
- [ ] MT5 Portable installé et configuré
- [ ] Compte broker connecté dans MT5 PropFirm
- [ ] Git installé et configuré
- [ ] Service de déploiement actif
- [ ] Premier déploiement réussi
- [ ] EA visible dans MT5

### Test Final

- [ ] Modifier un fichier localement
- [ ] `git push`
- [ ] Vérifier le déploiement sur RDP (< 60s)
- [ ] EA mis à jour dans MT5

---

## Support

Si vous rencontrez des problèmes:

1. Vérifiez les logs: `C:\PropFirmEA\Logs\`
2. Vérifiez le statut Git: `cd C:\PropFirmEA\Project && git status`
3. Redémarrez le service de déploiement
