# Règles Détaillées des Prop Firms

> Document de référence pour la configuration des EA selon les contraintes de chaque prop firm.
> Dernière mise à jour: Décembre 2024

---

## Table des Matières

1. [FTMO](#1-ftmo)
2. [E8 Markets](#2-e8-markets)
3. [Funding Pips](#3-funding-pips)
4. [The5ers](#4-the5ers)
5. [Tableau Comparatif](#5-tableau-comparatif)
6. [Paramètres EA Recommandés](#6-paramètres-ea-recommandés)

---

## 1. FTMO

### 1.1 Structure d'Évaluation

| Phase | Profit Target | Durée | Min Trading Days |
|-------|---------------|-------|------------------|
| FTMO Challenge | 10% | Illimitée | 4 jours |
| Verification | 5% | Illimitée | 4 jours |
| Funded Account | Aucun | - | - |

### 1.2 Règles de Drawdown

#### Maximum Daily Loss (DD Journalier)
- **Limite**: 5% du capital initial
- **Calcul**: Somme des pertes réalisées + pertes flottantes
- **Reset**: Chaque jour à 00:00 (heure du serveur)
- **Conséquence si dépassé**: Échec immédiat

```
Exemple: Compte $100,000
DD Journalier Max = $5,000
Si P&L jour (réalisé + flottant) atteint -$5,000 → BREACH
```

#### Maximum Loss (DD Total)
- **Limite**: 10% du capital initial
- **Type**: Statique (ne trail pas)
- **Calcul**: Basé sur le capital initial, pas le plus haut atteint

```
Exemple: Compte $100,000
Équité minimum autorisée = $90,000
Même si équité monte à $115,000, le plancher reste $90,000
```

### 1.3 Types de Comptes

#### Normal Account
- **Leverage**: 1:100
- **News Trading**: INTERDIT (2 min avant/après high impact)
- **Weekend Holding**: INTERDIT
- **Hedging**: Autorisé (même compte)

#### Swing Account
- **Leverage**: 1:30
- **News Trading**: AUTORISÉ
- **Weekend Holding**: AUTORISÉ
- **Hedging**: Autorisé (même compte)

### 1.4 Règles Additionnelles

- **EA/Robots**: AUTORISÉ
- **Copy Trading**: INTERDIT (entre comptes FTMO)
- **Limite de Capital**: $400,000 max combiné
- **Payout**: Tous les 14-60 jours
- **Profit Split**: 80% (90% après scaling)

### 1.5 Scaling Plan

Conditions (cycle de 4 mois):
1. Profit net ≥ 10%
2. Minimum 2 payouts effectués
3. Solde positif en fin de période

Récompense: +25% de capital, profit split → 90%

### 1.6 Paramètres EA pour FTMO

```cpp
// Configuration FTMO - Challenge Mode
#define FTMO_MAX_DD_DAILY      4.5    // Buffer de 0.5%
#define FTMO_MAX_DD_TOTAL      9.0    // Buffer de 1%
#define FTMO_RISK_PER_TRADE    1.5
#define FTMO_MAX_TRADES_DAY    5
#define FTMO_NEWS_FILTER       true   // Compte Normal
#define FTMO_NEWS_MINUTES      5      // Minutes avant/après news
#define FTMO_WEEKEND_CLOSE     true   // Compte Normal

// Configuration FTMO - Funded Mode
#define FTMO_FUNDED_RISK       0.75
#define FTMO_FUNDED_DD_DAILY   3.5
#define FTMO_FUNDED_DD_TOTAL   7.0
```

---

## 2. E8 Markets

### 2.1 Programmes Disponibles

#### E8 One (1-Step)
| Paramètre | Valeur |
|-----------|--------|
| Profit Target | 10% |
| Daily DD | 5% |
| Max DD | 6% (statique) |
| Min Trading Days | 3 jours |
| Durée | Illimitée |

#### E8 Classic (2-Step)
| Phase | Profit Target | Daily DD | Max DD |
|-------|---------------|----------|--------|
| Phase 1 | 8-10% | 5% | 8-10% |
| Phase 2 | 5% | 5% | 8-10% |

#### E8 Track (3-Step)
| Phase | Profit Target |
|-------|---------------|
| Phase 1 | 6% |
| Phase 2 | 3% |
| Phase 3 | 3% |
- Max DD: 6% (statique)

### 2.2 Règles de Drawdown

#### EOD Trailing Drawdown (certains programmes)
- Se calcule à la fin de chaque journée
- Trail vers le haut basé sur le plus haut solde en clôture
- **Attention**: Plus restrictif que drawdown statique

#### Daily Drawdown
- 5% calculé sur la base du solde de début de journée
- Inclut pertes réalisées ET flottantes

### 2.3 Règles de Trading

**AUTORISÉ:**
- Scalping, Day Trading, Swing Trading
- EAs et robots
- Trading de news (sauf E8 Trader accounts)
- Weekend holding

**INTERDIT:**
- Hedging entre comptes multiples
- Arbitrage de latence
- News straddling
- HFT exploitant les inefficiences
- Manipulation serveur

### 2.4 Profit Split & Payouts

- **Profit Split**: 80% (jusqu'à 100% personnalisable)
- **Premier Payout**: Après 8 jours
- **Payouts suivants**: Toutes les 2 semaines
- **Scaling**: +1% de drawdown par retrait (jusqu'à 14%)

### 2.5 Paramètres EA pour E8

```cpp
// Configuration E8 - One Step
#define E8_ONE_DD_DAILY        4.5
#define E8_ONE_DD_TOTAL        5.5    // 6% - buffer
#define E8_ONE_TARGET          10.0

// Configuration E8 - Classic
#define E8_CLASSIC_DD_DAILY    4.5
#define E8_CLASSIC_DD_TOTAL    7.5    // 8% - buffer
#define E8_CLASSIC_TARGET_P1   8.0
#define E8_CLASSIC_TARGET_P2   5.0

#define E8_RISK_CHALLENGE      1.5
#define E8_RISK_FUNDED         0.75
#define E8_MAX_TRADES_DAY      4
```

---

## 3. Funding Pips

### 3.1 Programmes d'Évaluation

#### 1-Step Challenge
| Paramètre | Valeur |
|-----------|--------|
| Profit Target | 10% |
| Daily DD | 4% |
| Max DD | 6% (statique) |
| Min Trading Days | 3 jours |

#### 2-Step Challenge
| Phase | Profit Target | Daily DD | Max DD |
|-------|---------------|----------|--------|
| Phase 1 | 8% | 5% | 10% |
| Phase 2 | 5% | 5% | 10% |

#### X 2-Step Challenge
| Phase | Profit Target | Daily DD | Max DD |
|-------|---------------|----------|--------|
| Phase 1 | 10% | 4% | 8% |
| Phase 2 | 5% | 4% | 8% |

#### 3-Step Challenge
| Phase | Profit Target |
|-------|---------------|
| Phase 1 | 5% |
| Phase 2 | 5% |
| Phase 3 | 5% |
- Daily DD: 5%, Max DD: 10%

### 3.2 Règles de Drawdown

- **Type**: Statique (basé sur capital initial)
- **Calcul Daily DD**: Reset à minuit (heure serveur)
- **Inclut**: Pertes réalisées + flottantes

### 3.3 Règles de Trading

**ÉVALUATION:**
- News Trading: AUTORISÉ
- EAs: AUTORISÉ
- Weekend Holding: AUTORISÉ

**COMPTE FUNDED (Master Account):**
- **News Restriction**: Profits non comptés si trade ouvert/fermé 5 min avant/après news high impact
- EAs: AUTORISÉ
- Weekend Holding: AUTORISÉ

**INTERDIT (Tous comptes):**
- Gap Trading
- HFT / Server Spamming
- Arbitrage (latence, reverse, long-short)
- Tick Scalping
- Hedging
- Toxic Trading Flow

### 3.4 Profit Split & Payouts

- **Profit Split**: 80% → 100%
- **Payout Day**: Chaque mardi
- **Délai traitement**: 1-3 jours ouvrés
- **Minimum retrait**: 1% du capital

### 3.5 Paramètres EA pour Funding Pips

```cpp
// Configuration FundingPips - 1-Step
#define FP_1STEP_DD_DAILY      3.5    // 4% - buffer
#define FP_1STEP_DD_TOTAL      5.5    // 6% - buffer
#define FP_1STEP_TARGET        10.0

// Configuration FundingPips - 2-Step
#define FP_2STEP_DD_DAILY      4.5
#define FP_2STEP_DD_TOTAL      9.0
#define FP_2STEP_TARGET_P1     8.0
#define FP_2STEP_TARGET_P2     5.0

// Funded Account
#define FP_FUNDED_NEWS_FILTER  true
#define FP_FUNDED_NEWS_MINUTES 5
#define FP_FUNDED_RISK         0.5    // Conservateur
```

---

## 4. The5ers

### 4.1 Programmes Disponibles

#### Bootcamp
| Phase | Profit Target | Max DD | Daily DD |
|-------|---------------|--------|----------|
| Phase 1-3 | 6% chaque | 5% | Aucun |
| Funded | - | 4% | 3% |

**Règle Spéciale - 2% Rule:**
- SL obligatoire ≤ 2% dans les 3 minutes après ouverture
- Violation = avertissement
- 5 violations = compte fermé

#### High Stakes (2-Step)
| Phase | Profit Target | Daily DD | Max DD |
|-------|---------------|----------|--------|
| Phase 1 | 8% | 5% | 10% |
| Phase 2 | 5% | 5% | 10% |

#### Hyper Growth (1-Step)
| Paramètre | Valeur |
|-----------|--------|
| Profit Target | Variable |
| Daily DD | 5% |
| Max DD | 6% (statique) |

### 4.2 Règles de Drawdown

#### Calcul spécifique The5ers
- Basé sur le **MAX(Balance, Equity)** à la clôture du jour
- Ne change pas intraday
- Reset après clôture de la journée de trading

#### Limites par Programme
| Programme | Daily DD | Max DD |
|-----------|----------|--------|
| Bootcamp (Eval) | Aucun | 5% |
| Bootcamp (Funded) | 3% | 4% |
| High Stakes | 5% | 10% |
| Hyper Growth | 5% | 6% |

### 4.3 Règles de Trading

**AUTORISÉ:**
- Weekend Holding: OUI
- Overnight Holding: OUI
- News Trading: OUI (Bootcamp)
- EAs: OUI

**INTERDIT:**
- HFT (trades de quelques secondes)
- Bracketing autour des news
- Copy Trading entre comptes

**RÈGLE CRITIQUE - Bootcamp:**
```
VIOLATION si:
- Pas de SL dans les 3 minutes
- SL > 2% du capital
5 violations = ACCOUNT TERMINATED
```

### 4.4 Profit Split & Scaling

- **Profit Split Initial**: 50-80% selon programme
- **Scaling**: +5% capital pour chaque +5% profit
- **Maximum**: $4,000,000 (ou $2M selon programme)
- **Top Performers**: Jusqu'à 100% profit split

### 4.5 Paramètres EA pour The5ers

```cpp
// Configuration The5ers - Bootcamp
#define T5_BOOT_DD_TOTAL       4.5    // 5% - buffer
#define T5_BOOT_MAX_SL_PCT     1.8    // 2% - buffer (CRITIQUE)
#define T5_BOOT_SL_TIMEOUT     150    // Secondes (3min - buffer)
#define T5_BOOT_TARGET         6.0

// Configuration The5ers - High Stakes
#define T5_HS_DD_DAILY         4.5
#define T5_HS_DD_TOTAL         9.0
#define T5_HS_TARGET_P1        8.0
#define T5_HS_TARGET_P2        5.0

// Bootcamp Funded
#define T5_FUNDED_DD_DAILY     2.5    // 3% - buffer
#define T5_FUNDED_DD_TOTAL     3.5    // 4% - buffer
#define T5_FUNDED_RISK         0.5    // TRÈS conservateur
```

---

## 5. Tableau Comparatif

### 5.1 Challenges 2-Step (Standard)

| Prop Firm | Target P1 | Target P2 | Daily DD | Max DD | Min Days |
|-----------|-----------|-----------|----------|--------|----------|
| FTMO | 10% | 5% | 5% | 10% | 4 |
| E8 Markets | 8-10% | 5% | 5% | 8-10% | 3 |
| Funding Pips | 8% | 5% | 5% | 10% | 3 |
| The5ers HS | 8% | 5% | 5% | 10% | 3 |

### 5.2 Challenges 1-Step

| Prop Firm | Target | Daily DD | Max DD | Min Days |
|-----------|--------|----------|--------|----------|
| E8 One | 10% | 5% | 6% | 3 |
| Funding Pips 1-Step | 10% | 4% | 6% | 3 |
| The5ers Hyper | Variable | 5% | 6% | - |

### 5.3 Comptes Funded

| Prop Firm | Daily DD | Max DD | Profit Split | Scaling Max |
|-----------|----------|--------|--------------|-------------|
| FTMO | 5% | 10% | 80-90% | $2M |
| E8 Markets | 5% | 8-14% | 80-100% | $1M |
| Funding Pips | 4-5% | 6-10% | 80-100% | Variable |
| The5ers | 3-5% | 4-10% | 50-100% | $4M |

### 5.4 Restrictions Trading

| Prop Firm | News | Weekend | EA | Hedging |
|-----------|------|---------|----|---------|
| FTMO Normal | NON | NON | OUI | OUI (même compte) |
| FTMO Swing | OUI | OUI | OUI | OUI |
| E8 Markets | OUI* | OUI | OUI | NON (multi-compte) |
| Funding Pips | OUI** | OUI | OUI | NON |
| The5ers | OUI | OUI | OUI | NON (multi-compte) |

*E8: Restrictions sur certains comptes
**Funding Pips Funded: Profits non comptés 5min autour news

---

## 6. Paramètres EA Recommandés

### 6.1 Mode Challenge Universel

Ces paramètres respectent les règles les plus strictes:

```cpp
//+------------------------------------------------------------------+
//| CONFIGURATION CHALLENGE - MULTI PROP FIRM                        |
//+------------------------------------------------------------------+
input group "=== Risk Management ==="
input double RiskPercent = 1.5;              // Risk par trade (%)
input double MaxDailyDD = 3.5;               // DD Journalier max (%) - Universal safe
input double MaxTotalDD = 5.5;               // DD Total max (%) - Pour 1-Step
input int MaxTradesPerDay = 4;               // Trades max par jour
input int MaxOpenTrades = 2;                 // Positions simultanées max

input group "=== Stop Loss (The5ers Compliant) ==="
input double MaxSLPercent = 1.8;             // SL Max en % du capital
input int SLTimeoutSeconds = 150;            // Timeout pour placer SL

input group "=== News Filter ==="
input bool UseNewsFilter = true;             // Filtrer les news
input int MinutesBeforeNews = 5;             // Minutes avant news
input int MinutesAfterNews = 5;              // Minutes après news
input bool FilterHighImpact = true;          // Filtrer High Impact
input bool FilterMediumImpact = false;       // Filtrer Medium Impact

input group "=== Weekend/Session ==="
input bool CloseBeforeWeekend = true;        // Fermer avant weekend
input int FridayCloseHour = 20;              // Heure fermeture vendredi (UTC)
input int TradingStartHour = 7;              // Début trading (UTC)
input int TradingEndHour = 17;               // Fin trading (UTC)
```

### 6.2 Mode Funded Universel

```cpp
//+------------------------------------------------------------------+
//| CONFIGURATION FUNDED - CONSERVATIVE                              |
//+------------------------------------------------------------------+
input group "=== Risk Management ==="
input double RiskPercent = 0.5;              // Risk par trade (%)
input double MaxDailyDD = 2.0;               // DD Journalier max (%)
input double MaxTotalDD = 3.5;               // DD Total max (%)
input int MaxTradesPerDay = 3;               // Trades max par jour
input int MaxOpenTrades = 1;                 // Positions simultanées max

input group "=== Profit Protection ==="
input bool UseTrailingEquity = true;         // Trailing sur équité
input double LockProfitAt = 3.0;             // Lock profit à X%
input double LockProfitDD = 1.5;             // DD autorisé après lock
```

### 6.3 Profils par Prop Firm

```cpp
enum PROP_FIRM_PROFILE {
   PROFILE_FTMO_NORMAL,
   PROFILE_FTMO_SWING,
   PROFILE_E8_ONE,
   PROFILE_E8_CLASSIC,
   PROFILE_FUNDING_PIPS_1STEP,
   PROFILE_FUNDING_PIPS_2STEP,
   PROFILE_THE5ERS_BOOTCAMP,
   PROFILE_THE5ERS_HIGHSTAKES,
   PROFILE_CUSTOM
};

void LoadPropFirmProfile(PROP_FIRM_PROFILE profile) {
   switch(profile) {
      case PROFILE_FTMO_NORMAL:
         RiskPercent = 1.5;
         MaxDailyDD = 4.5;
         MaxTotalDD = 9.0;
         UseNewsFilter = true;
         CloseBeforeWeekend = true;
         break;

      case PROFILE_FTMO_SWING:
         RiskPercent = 1.5;
         MaxDailyDD = 4.5;
         MaxTotalDD = 9.0;
         UseNewsFilter = false;
         CloseBeforeWeekend = false;
         break;

      case PROFILE_E8_ONE:
         RiskPercent = 1.2;
         MaxDailyDD = 4.5;
         MaxTotalDD = 5.5;
         UseNewsFilter = false;
         break;

      case PROFILE_FUNDING_PIPS_1STEP:
         RiskPercent = 1.0;
         MaxDailyDD = 3.5;
         MaxTotalDD = 5.5;
         UseNewsFilter = true;  // Pour funded
         break;

      case PROFILE_THE5ERS_BOOTCAMP:
         RiskPercent = 1.0;
         MaxDailyDD = 99.0;     // Pas de limite en eval
         MaxTotalDD = 4.5;
         MaxSLPercent = 1.8;    // CRITIQUE
         break;
   }
}
```

---

## Sources

- [FTMO Official Rules](https://ftmo.com/en/trading-rules/)
- [E8 Markets](https://e8markets.com/)
- [Funding Pips](https://fundingpips.com/)
- [The5ers](https://the5ers.com/)
- [FTMO Drawdowns Explained](https://ftmo.com/en/drawdowns/)
- [The Trusted Prop - Comparatifs](https://thetrustedprop.com/)
