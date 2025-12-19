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
│   ├── PropFirm_Scalper_v8.mq5        # Scalper V8 [RECOMMANDE CHALLENGES]
│   ├── PropFirm_SMC_EA_v1.mq5         # Strategie SMC/ICT
│   ├── PropFirm_SessionBreakout_v1.mq5 # Breakout V1 (basique)
│   ├── PropFirm_SessionBreakout_v2.mq5 # Breakout V2 (dynamique)
│   ├── PropFirm_SessionBreakout_v3.mq5 # Breakout V3 (qualite)
│   ├── PropFirm_SessionBreakout_v4.mq5 # Breakout V4 (scanner)
│   ├── PropFirm_SessionBreakout_v5.mq5 # Breakout V5 (structure)
│   ├── PropFirm_SessionBreakout_v6.mq5 # Breakout V6 (optimizer)
│   └── PropFirm_SessionBreakout_v7.mq5 # Breakout V7 (adaptive)
│
├── EA/MQL5/Include/                    # Modules partages
│   └── Dashboard_v2.mqh               # Dashboard compact lisible
│
├── strategies/                         # Documentation des strategies
│   ├── SMC_ICT_Strategy.md
│   ├── Session_Breakout.md
│   └── Scalper_Strategy.md            # Scalper V8 documentation
│
├── config/profiles/                    # Presets par prop firm
│   ├── Scalper_FTMO_Challenge.set     # V8 Scalper presets
│   ├── Scalper_FTMO_Funded.set
│   ├── Scalper_E8_OneStep.set
│   ├── Scalper_FundingPips_1Step.set
│   ├── Scalper_The5ers_Bootcamp.set
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

### 1. PropFirm_Scalper_v8 (RECOMMANDE CHALLENGES)
**Statut**: Implementé - Scalping haute frequence

| Element | Description |
|---------|-------------|
| Strategie | Scalping multi-paires, 4 types d'entrees |
| Timeframe | M5 |
| Paires | EURUSD, GBPUSD, USDJPY, XAUUSD |
| Sessions | London Open/Peak, NY Open/Peak, London Close |
| Risk | 0.5-0.8% par trade |
| Capacite | 12-15 trades/jour, 2 positions max |

**4 Types d'Entrees:**
- **MOMENTUM** - Bougie forte > 40% range horaire
- **MICRO_BREAKOUT** - Cassure range 1H + 3 pips
- **PULLBACK** - Retour sur EMA21 dans tendance
- **REVERSAL** - RSI extreme + pin bar (optionnel)

**Caracteristiques Cles:**
- Compounding agressif (+25% apres 3 wins, +50% apres 5 wins)
- Mode Turbo si retard challenge (auto-adaptatif)
- Dashboard compact V2 (lisible, 8 lignes)
- Exit time-based (20 min max)
- Partial close 50% a TP1, trail le reste

**Performance Cible:** 10-15% mensuel

### 2. PropFirm_SMC_EA_v1 (Smart Money Concepts)
**Statut**: Implementé - En test

| Element | Description |
|---------|-------------|
| Strategie | Order Blocks, FVG, BOS/CHoCH |
| Timeframes | H4 (tendance) + M15 (entree) |
| Sessions | London & NY Kill Zones |
| Risk | 1.5% challenge / 0.75% funded |

### 3. PropFirm_SessionBreakout (v1-v7)
**Statut**: Anciennes versions - Remplacees par V8

| Version | Description | Limite |
|---------|-------------|--------|
| V7 | Adaptive mode | Trop conservateur |
| V6 | Challenge optimizer | ~2-3% mensuel |
| V5 | Structure-based | Peu de trades |
| V4 | Multi-opportunity | 6 trades/jour max |
| V3 | Quality scoring | Tres selectif |
| V2 | Dynamic range | Multiple sessions |
| V1 | Basic breakout | Range fixe |

> Note: Ces versions sont conservees pour reference mais le **Scalper V8** est recommande pour les challenges.

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

| Metrique | Minimum | Cible | V8 Scalper |
|----------|---------|-------|------------|
| Win Rate | 50% | 55-60% | 52%+ |
| Profit Factor | 1.2 | 1.4+ | 1.3+ |
| Max DD | <8% | <5% | <5% |
| RR Moyen | 1:1 | 1:1.5+ | 1:1.2 |
| Trades/mois | 15+ | 25+ | 200+ |
| Profit mensuel | 5% | 10% | 12-15% |
| Backtest | 6 mois | 12+ mois | 6 mois |

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

- [x] Creer Scalper V8 haute frequence
- [x] Dashboard compact V2 (lisible)
- [x] Multi-paires (EURUSD, GBPUSD, USDJPY, XAUUSD)
- [x] Mode Turbo adaptatif
- [ ] Backtester V8 sur 6-12 mois
- [ ] Ajouter filtre de news API
- [ ] Creer EA RSI Divergence (alternative)
- [ ] Dashboard de monitoring temps reel (web)

---

## Repository

**GitHub**: https://github.com/cgemise971/PropFirmEA

**Branches:**
- `main` - Production (deploye sur RDP)
- `develop` - Developpement (tests)
