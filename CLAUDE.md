# CLAUDE.md - Projet PropFirm EA Fleet

## Vue d'Ensemble du Projet

Ce projet vise à créer un système automatisé d'Expert Advisors (EA) optimisé pour:
1. **Passer les challenges** des principales prop firms (FTMO, E8 Markets, Funding Pips, The5ers)
2. **Générer des profits stables** de 5-10% mensuel une fois financé
3. **Scaler** vers une flotte de comptes multi-prop firms

---

## Architecture du Projet

```
PropFirmEA_Project/
├── CLAUDE.md                    # Ce fichier - Directives principales
├── docs/                        # Documentation
│   ├── PROP_FIRMS_RULES.md     # Règles détaillées de chaque prop firm
│   ├── STRATEGY_GUIDE.md       # Guide des stratégies
│   └── RISK_MANAGEMENT.md      # Gestion des risques
├── strategies/                  # Définitions des stratégies
│   ├── SMC_ICT_Strategy.md     # Stratégie Smart Money Concepts
│   ├── Session_Breakout.md     # Stratégie Breakout Session
│   └── RSI_Divergence.md       # Stratégie RSI Divergence
├── EA/                          # Code des Expert Advisors
│   ├── MQL5/                   # Code MetaTrader 5
│   └── MQL4/                   # Code MetaTrader 4
├── config/                      # Fichiers de configuration
│   ├── challenge_mode.set      # Paramètres mode challenge
│   ├── funded_mode.set         # Paramètres mode financé
│   └── prop_firm_profiles/     # Profils par prop firm
├── backtests/                   # Résultats de backtests
├── monitoring/                  # Scripts de monitoring
└── risk_management/             # Outils de gestion du risque
```

---

## Objectifs Principaux

### Phase Challenge (Agressif-Contrôlé)
- **Objectif**: Atteindre 10% en 15-25 jours de trading
- **Risk/Trade**: 1.5% - 2%
- **DD Journalier Max**: 3.5% (buffer de sécurité)
- **Trades/Jour**: 2-4 maximum
- **Win Rate Cible**: 55%+
- **RR Moyen**: 1:1.5

### Phase Funded (Conservateur-Scalable)
- **Objectif**: 5-8% mensuel stable
- **Risk/Trade**: 0.5% - 0.75%
- **DD Journalier Max**: 2%
- **Trades/Jour**: 1-3 maximum
- **Profit Factor Cible**: 1.5+

---

## Règles Critiques à Respecter

### FTMO
- DD Max: 10% (statique)
- DD Journalier: 5%
- Profit Target: 10% (Phase 1), 5% (Phase 2)
- Min Trading Days: 4 jours
- Leverage: 1:100 (Normal), 1:30 (Swing)

### E8 Markets
- DD Max: 8-10% selon programme
- DD Journalier: 5%
- Profit Target: 8-10% (Phase 1), 5% (Phase 2)
- Min Trading Days: 3 jours

### Funding Pips
- DD Max: 6-10% selon challenge
- DD Journalier: 4-5%
- Profit Target: 8-10%
- Min Trading Days: 3 jours

### The5ers
- DD Max: 5-10% selon programme
- DD Journalier: 3-5%
- Règle 2%: SL obligatoire sous 2% dans les 3 minutes

---

## Stratégies Implémentées

### 1. SMC/ICT Institutional (Principal)
Stratégie basée sur les Smart Money Concepts:
- Order Blocks (zones institutionnelles)
- Fair Value Gaps (FVG)
- Liquidity Sweeps
- Break of Structure (BOS) / Change of Character (CHoCH)
- Kill Zones (London, NY)

### 2. Session Breakout (Secondaire)
- Breakout du range asiatique
- Confirmation de momentum
- Multi-TP avec trailing

### 3. RSI Divergence (Tertiaire)
- Divergences sur niveaux S/R
- Mean reversion contrôlée

---

## Commandes de Développement

```bash
# Compiler EA MQL5
mql5_compile EA/MQL5/PropFirmEA.mq5

# Lancer backtest
mt5_backtest --ea=PropFirmEA --period=2022.01-2024.12 --pair=EURUSD

# Optimisation
mt5_optimize --ea=PropFirmEA --params=config/optimization.set
```

---

## Métriques de Validation

Avant mise en production, l'EA doit atteindre:

| Métrique | Minimum | Cible |
|----------|---------|-------|
| Win Rate | 50% | 55-60% |
| Profit Factor | 1.3 | 1.5-2.0 |
| Max DD | <8% | <6% |
| Recovery Factor | >2 | >3 |
| Sharpe Ratio | >1 | >1.5 |
| Trades (backtest) | 500+ | 1000+ |
| Période test | 2 ans | 5 ans |

---

## Workflow de Développement

1. **Définir la stratégie** dans `/strategies/`
2. **Implémenter le code** dans `/EA/MQL5/` ou `/EA/MQL4/`
3. **Backtester** sur données historiques (min 2 ans)
4. **Optimiser** les paramètres
5. **Forward test** sur compte démo (3 mois minimum)
6. **Valider** les métriques
7. **Déployer** sur challenge prop firm

---

## Conventions de Code

### Nommage
- Fonctions: `PascalCase` (ex: `CalculateLotSize`)
- Variables: `camelCase` (ex: `riskPercent`)
- Constantes: `UPPER_SNAKE_CASE` (ex: `MAX_DD_DAILY`)
- Fichiers EA: `PropFirm_[Strategy]_v[Version].mq5`

### Structure EA
```mql5
//+------------------------------------------------------------------+
//| Includes et Defines                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {}

//+------------------------------------------------------------------+
//| Strategy Functions                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Risk Management Functions                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Utility Functions                                                 |
//+------------------------------------------------------------------+
```

---

## Notes Importantes

1. **Toujours respecter les règles de drawdown** - C'est la priorité absolue
2. **Ne jamais trader sans filtre de news** sur compte Normal/Standard
3. **Tester sur démo** avant toute mise en production
4. **Documenter chaque modification** de stratégie ou paramètres
5. **Versionner le code** avec Git pour traçabilité

---

## Ressources

- [FTMO Rules](https://ftmo.com/en/trading-rules/)
- [E8 Markets](https://e8markets.com/)
- [Funding Pips](https://fundingpips.com/)
- [The5ers](https://the5ers.com/)
- [ICT/SMC Concepts](https://www.mindmathmoney.com/articles/smart-money-concepts-the-ultimate-guide-to-trading-like-institutional-investors-in-2025)
