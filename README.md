# PropFirm EA Fleet Project

> Système automatisé d'Expert Advisors optimisé pour les prop firms (FTMO, E8 Markets, Funding Pips, The5ers)

---

## Objectif

Créer et gérer une flotte de comptes prop firm générant **5-10% mensuel** de manière automatisée et respectant toutes les règles des différentes prop firms.

---

## Quick Start

### 1. Prérequis

- MetaTrader 5 (ou MT4)
- VPS avec latence <20ms vers broker
- Capital initial pour challenges (~$1,000-2,000)
- Connaissances de base en trading

### 2. Installation

```bash
# 1. Copier les fichiers EA
cp EA/MQL5/*.mq5 /path/to/MT5/MQL5/Experts/

# 2. Copier les configurations
cp config/profiles/*.set /path/to/MT5/MQL5/Presets/

# 3. Compiler l'EA dans MetaEditor
# Ouvrir PropFirm_SMC_EA_v1.mq5 et compiler (F7)
```

### 3. Configuration

1. Ouvrir MT5
2. Attacher l'EA au graphique (EUR/USD M15 recommandé)
3. Sélectionner le profil prop firm approprié
4. Ajuster le mode (Challenge/Funded)
5. Activer l'AutoTrading

---

## Structure du Projet

```
PropFirmEA_Project/
├── CLAUDE.md                    # Directives du projet
├── README.md                    # Ce fichier
│
├── docs/
│   ├── PROP_FIRMS_RULES.md     # Règles détaillées par prop firm
│   ├── RISK_MANAGEMENT.md      # Guide de gestion du risque
│   └── FLEET_SCALING_STRATEGY.md # Stratégie de scaling
│
├── strategies/
│   ├── SMC_ICT_Strategy.md     # Stratégie principale (Smart Money)
│   ├── Session_Breakout.md     # Stratégie secondaire
│   └── RSI_Divergence.md       # Stratégie tertiaire
│
├── EA/
│   ├── MQL5/
│   │   └── PropFirm_SMC_EA_v1.mq5  # EA principal MT5
│   └── MQL4/
│       └── (à venir)
│
├── config/
│   └── profiles/
│       ├── FTMO_Normal_Challenge.set
│       ├── FTMO_Normal_Funded.set
│       ├── E8_One_Step.set
│       ├── FundingPips_1Step.set
│       └── The5ers_Bootcamp.set
│
├── backtests/                   # Résultats de backtests
├── monitoring/                  # Scripts de monitoring
└── risk_management/             # Outils additionnels
```

---

## Stratégies Incluses

### 1. SMC/ICT Institutional (Principal)

Stratégie basée sur les Smart Money Concepts:
- Order Blocks
- Fair Value Gaps
- Liquidity Sweeps
- Break of Structure / Change of Character

**Performance cible**: WR 55-62%, PF 1.6-2.2

### 2. Session Breakout (Secondaire)

Exploitation des breakouts du range asiatique:
- Range 00:00-06:00 UTC
- Entrée sur breakout London/NY
- Multi-TP avec trailing

**Performance cible**: WR 55-62%, PF 1.4-1.8

### 3. RSI Divergence (Tertiaire)

Mean reversion sur divergences:
- RSI(14) divergences H1/H4
- Confirmation sur structure
- Zones S/R significatives

**Performance cible**: WR 50-55%, PF 1.3-1.6

---

## Prop Firms Supportées

| Prop Firm | DD Max | DD Daily | Profit Split | Scaling |
|-----------|--------|----------|--------------|---------|
| FTMO | 10% | 5% | 80-90% | $2M max |
| E8 Markets | 6-10% | 5% | 80-100% | $1M max |
| Funding Pips | 6-10% | 4-5% | 80-100% | Variable |
| The5ers | 5-10% | 3-5% | 50-100% | $4M max |

---

## Workflow Recommandé

```
PHASE 1 (Mois 1-2): Validation
├── Backtest 5 ans minimum
├── Forward test démo 3 mois
├── Passer 2 premiers challenges
└── Budget: ~$1,500

PHASE 2 (Mois 3-4): Expansion
├── Atteindre 5 comptes funded
├── Premiers payouts
└── Revenus: ~$20,000/mois

PHASE 3 (Mois 5-6): Consolidation
├── Atteindre 8-10 comptes
├── Système automatisé stable
└── Revenus: ~$40,000/mois

PHASE 4 (Mois 7+): Scaling
├── Scaling interne prop firms
├── Expansion horizontale
└── Objectif: $1M+ sous gestion
```

---

## Gestion du Risque

### Circuit Breakers

```
Niveau 1 @ -1.5% jour: Réduire risk 50%
Niveau 2 @ -2.5% jour: Stop 4 heures
Niveau 3 @ -3.5% jour: Stop journée
Niveau 4 @ -4.5% jour: EA OFF
```

### Paramètres par Mode

| Paramètre | Challenge | Funded |
|-----------|-----------|--------|
| Risk/Trade | 1.5% | 0.75% |
| Max DD Daily | 4.5% | 3.5% |
| Max Trades/Jour | 4 | 3 |
| RR Minimum | 1.5 | 1.8 |

---

## Backtesting

### Commande

```bash
# Via terminal MT5 ou script
mt5_backtest --ea=PropFirm_SMC_EA_v1 \
             --symbol=EURUSD \
             --period=M15 \
             --from=2019.01.01 \
             --to=2024.12.01 \
             --deposit=100000 \
             --leverage=100
```

### Métriques Cibles

| Métrique | Minimum | Optimal |
|----------|---------|---------|
| Net Profit | >50% | >100% |
| Profit Factor | >1.5 | >2.0 |
| Win Rate | >50% | >55% |
| Max Drawdown | <10% | <6% |
| Recovery Factor | >3 | >5 |

---

## Monitoring

### Dashboard EA

L'EA affiche en temps réel:
- P&L journalier / total
- Drawdown utilisé vs max
- Trades du jour
- Status des filtres
- Structure de marché

### Alertes

- Push notifications sur mobile
- Email pour alertes critiques
- Logs détaillés dans fichier

---

## FAQ

### Quel capital pour commencer?

~$1,000-1,500 pour 2 premiers challenges.

### Combien de temps pour être rentable?

3-6 mois pour valider et avoir des revenus stables.

### Risque de breach?

~10-15% des comptes/an avec bonne gestion du risque.

### Peut-on utiliser sur plusieurs brokers?

Oui, l'EA est compatible avec tout broker MT5.

### Support?

Documentation complète dans /docs/

---

## Roadmap

- [x] EA principal MQL5
- [x] Profiles prop firms
- [x] Documentation stratégies
- [x] Guide risk management
- [ ] EA MQL4 (conversion)
- [ ] Dashboard web monitoring
- [ ] API intégration news
- [ ] Backtester automatisé
- [ ] Multi-compte manager

---

## Avertissement

Le trading comporte des risques. Les performances passées ne garantissent pas les résultats futurs. Ce projet est fourni à titre éducatif. Utilisez-le à vos propres risques.

---

## Licence

Usage personnel uniquement. Ne pas redistribuer sans autorisation.

---

## Contact

Pour questions ou suggestions, ouvrir une issue dans ce repository.
