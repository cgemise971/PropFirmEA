# CLAUDE.md - Projet PropFirm EA Fleet

## Vue d'Ensemble du Projet

Ce projet vise a creer un systeme automatise d'Expert Advisors (EA) optimise pour:
1. **Passer les challenges** des principales prop firms (FTMO, E8 Markets, Funding Pips, The5ers)
2. **Generer des profits stables** de 5-10% mensuel une fois finance
3. **Scaler** vers une flotte de comptes multi-prop firms

---

## Architecture du Projet

```
PropFirmEA_Project/
├── CLAUDE.md                           # Ce fichier - Directives principales
├── README.md                           # Guide d'installation rapide
│
├── EA/MQL5/                            # Expert Advisors
│   ├── PropFirm_SMC_EA_v1.mq5         # Strategie SMC/ICT
│   ├── PropFirm_SessionBreakout_v1.mq5 # Breakout V1 (basique)
│   ├── PropFirm_SessionBreakout_v2.mq5 # Breakout V2 (dynamique)
│   ├── PropFirm_SessionBreakout_v3.mq5 # Breakout V3 (qualite)
│   └── PropFirm_SessionBreakout_v4.mq5 # Breakout V4 (scanner) [RECOMMANDE]
│
├── strategies/                         # Documentation des strategies
│   ├── SMC_ICT_Strategy.md
│   └── Session_Breakout.md
│
├── config/profiles/                    # Presets par prop firm
│   ├── FTMO_Normal_Challenge.set
│   ├── FTMO_Normal_Funded.set
│   ├── E8_One_Step.set
│   ├── FundingPips_1Step.set
│   ├── The5ers_Bootcamp.set
│   ├── SessionBreakout_FTMO_Challenge.set
│   └── SessionBreakout_E8_OneStep.set
│
├── deployment/                         # Scripts de deploiement RDP
│   ├── bootstrap_rdp.ps1              # Installation one-liner
│   ├── setup_auto_deploy.ps1          # Config auto-sync
│   └── RDP_INSTALLATION_GUIDE.md
│
├── backtests/                          # Outils de backtest
│   ├── BacktestAnalyzer.mq5
│   ├── BacktestConfig.mqh
│   ├── analyze_backtest.py
│   └── propfirm_validator.py
│
├── docs/                               # Documentation
│   ├── PROP_FIRMS_RULES.md
│   ├── RISK_MANAGEMENT.md
│   └── FLEET_SCALING_STRATEGY.md
│
└── Logs/                               # Logs de deploiement
```

---

## Expert Advisors Disponibles

### 1. PropFirm_SMC_EA_v1 (Smart Money Concepts)
**Statut**: Implementé - En test

| Element | Description |
|---------|-------------|
| Strategie | Order Blocks, FVG, BOS/CHoCH |
| Timeframes | H4 (tendance) + M15 (entree) |
| Sessions | London & NY Kill Zones |
| Risk | 1.5% challenge / 0.75% funded |

### 2. PropFirm_SessionBreakout_v4 (RECOMMANDE)
**Statut**: Implementé - Scanner multi-opportunites

| Element | Description |
|---------|-------------|
| Strategie | Multi-range scanner + 4 types d'entrees |
| Ranges | Asian + London + Intraday (3 ranges) |
| Scoring | 0-10 points (min 3 pour trader) |
| Entrees | Breakout, Retest, Failed BO, Structure |
| Detection | Squeeze Bollinger + ADX regime |
| Capacite | 6 trades/jour, 2 positions simultanées |

**4 Types d'Opportunites:**
- **BREAKOUT** - Cassure classique du range
- **RETEST** - Retour sur niveau casse (pullback)
- **FAILED_BO** - Fausse cassure → fade oppose
- **STRUCTURE** - Rebond sur extremite sans cassure

**Systeme de Score:**
- HTF Trend alignment: +3 pts
- Range quality: +2 pts
- ADX trending: +2 pts
- Bollinger squeeze: +2 pts
- Volume confirm: +1 pt

### 3. PropFirm_SessionBreakout_v3 (Qualite)
**Statut**: Implementé - Tres selectif (peu de trades)

- Breakout range + Confluence scoring (min 5/10)
- Retest confirmation obligatoire
- ADX, MTF alignment, regime detection

### 4. PropFirm_SessionBreakout_v2 (Dynamique)
**Statut**: Implementé - Plus agressif

- Range dynamique (ATR-based)
- Multiple sessions (Frankfurt, London, NY, London Close)
- Entrees Breakout + Pullback

### 5. PropFirm_SessionBreakout_v1 (Basique)
**Statut**: Implementé - Version simple

- Range fixe Asian (00-06 UTC)
- Breakout simple

---

## Deploiement RDP (Auto-Sync)

### Installation initiale (une seule fois)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm "https://raw.githubusercontent.com/cgemise971/PropFirmEA/main/deployment/bootstrap_rdp.ps1" | iex
```

### Activer l'auto-sync
```powershell
cd C:\PropFirmEA\Project
git pull
powershell -EP Bypass -File deployment\setup_auto_deploy.ps1
```

### Verifier le service
```powershell
Get-ScheduledTask -TaskName "PropFirmEA_AutoSync" | Select-Object State
```

**Fonctionnement:**
- Verifie GitHub toutes les 60 secondes
- Deploie automatiquement les changements vers MT5
- Logs dans `C:\PropFirmEA\Logs\sync.log`

---

## Workflow de Developpement

```
[PC Local]                    [GitHub]                    [RDP/VPS]
    │                            │                            │
    │  1. Modifier code          │                            │
    │  2. git push ─────────────>│                            │
    │                            │  3. Auto-sync (60s) ──────>│
    │                            │                            │  4. Deploie vers MT5
    │                            │                            │  5. EA mis a jour
```

---

## Regles Prop Firms (Resume)

| Prop Firm | DD Total | DD Daily | Profit Target | News Filter |
|-----------|----------|----------|---------------|-------------|
| FTMO Normal | 10% | 5% | 10% + 5% | Oui |
| FTMO Swing | 10% | 5% | 10% + 5% | Non |
| E8 One Step | 8% | 5% | 8% | Non |
| Funding Pips | 6% | 4% | 8% | Oui |
| The5ers | 5% | 3% | 6% | Non |

---

## Metriques de Validation

Avant mise en production sur challenge:

| Metrique | Minimum | Cible |
|----------|---------|-------|
| Win Rate | 50% | 55-60% |
| Profit Factor | 1.3 | 1.5+ |
| Max DD | <8% | <5% |
| RR Moyen | 1:1.2 | 1:1.5+ |
| Trades/mois | 15+ | 25+ |
| Backtest | 6 mois | 12+ mois |

---

## Commandes Utiles

### Git
```bash
git status
git add .
git commit -m "description"
git push origin main
```

### MT5 (sur RDP)
```powershell
# Lancer MT5
C:\PropFirmEA\Start_MT5.bat

# Voir les EAs deployes
dir C:\PropFirmEA\MT5_PropFirm\MQL5\Experts\

# Forcer sync manuel
cd C:\PropFirmEA\Project && git pull
Copy-Item "EA\MQL5\*.mq5" "C:\PropFirmEA\MT5_PropFirm\MQL5\Experts\" -Force
```

---

## Conventions de Code

### Nommage
- Fichiers EA: `PropFirm_[Strategy]_v[Version].mq5`
- Fonctions: `PascalCase`
- Variables: `camelCase`
- Constantes: `UPPER_SNAKE_CASE`

### Structure EA Standard
```mql5
// 1. Inputs
input group "=== PROP FIRM ==="
input ENUM_PROP_FIRM PropFirm = PROP_FTMO;

// 2. Structures
struct TradeData { ... };

// 3. Globals
CTrade trade;
TradeData g_trade;

// 4. OnInit / OnDeinit / OnTick

// 5. Strategy Functions

// 6. Risk Management Functions

// 7. Utility Functions
```

---

## Prochaines Etapes

- [ ] Creer EA RSI Divergence (3eme strategie)
- [ ] Optimiser Session Breakout V3 via backtest
- [ ] Ajouter filtre de news API
- [ ] Dashboard de monitoring temps reel
- [ ] Multi-paires (GBPUSD, USDJPY)

---

## Repository

**GitHub**: https://github.com/cgemise971/PropFirmEA

**Branches:**
- `main` - Production (deploye sur RDP)
- `develop` - Developpement (tests)
