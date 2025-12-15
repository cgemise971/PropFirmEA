# Stratégie SMC/ICT Institutional Flow

> Stratégie principale basée sur les Smart Money Concepts et la méthodologie ICT
> Remplace la stratégie Trend Following par une approche institutionnelle

---

## Vue d'Ensemble

### Philosophie

Cette stratégie vise à trader **avec** les institutions plutôt que contre elles. Elle identifie:
1. Les zones où les institutions accumulent/distribuent
2. Les mouvements de liquidation des retail traders
3. Les points d'entrée optimaux après confirmation de direction

### Performance Attendue

| Métrique | Challenge Mode | Funded Mode |
|----------|----------------|-------------|
| Win Rate | 55-62% | 52-58% |
| RR Moyen | 1:1.8 - 1:2.5 | 1:1.5 - 1:2 |
| Profit Factor | 1.6 - 2.2 | 1.4 - 1.8 |
| Max Drawdown | 6-8% | 4-5% |
| Trades/Semaine | 8-15 | 5-10 |

---

## Concepts Clés

### 1. Structure de Marché

#### Higher Highs (HH) / Higher Lows (HL) - Uptrend
```
         HH
        /  \
       /    \
      HL     \
     /        HH
    /        /
   HL       /
  /        HL
```

#### Lower Highs (LH) / Lower Lows (LL) - Downtrend
```
   LH
  /  \
 /    \
LL     LH
        \
         LL
          \
           LH
```

#### Break of Structure (BOS)
- **Définition**: Prix casse le dernier swing significatif dans le sens de la tendance
- **Uptrend BOS**: Nouveau Higher High (HH)
- **Downtrend BOS**: Nouveau Lower Low (LL)
- **Signal**: Continuation de tendance confirmée

#### Change of Character (CHoCH)
- **Définition**: Premier signe de retournement potentiel
- **Uptrend CHoCH**: Prix casse sous le dernier Higher Low
- **Downtrend CHoCH**: Prix casse au-dessus du dernier Lower High
- **Signal**: Possible retournement, chercher confirmation

### 2. Order Blocks (OB)

#### Définition
Zone de prix où les institutions ont placé des ordres significatifs. Dernière bougie avant un mouvement impulsif fort.

#### Bullish Order Block
```
       │
       │ Movement impulsif UP
       │
    ┌──┴──┐
    │ OB  │ ← Dernière bougie baissière avant l'impulsion
    └─────┘
       │
```

#### Bearish Order Block
```
       │
    ┌──┴──┐
    │ OB  │ ← Dernière bougie haussière avant l'impulsion
    └─────┘
       │
       │ Movement impulsif DOWN
       │
```

#### Critères de Validité
1. Doit précéder un mouvement impulsif (min 2x ATR)
2. Le mouvement doit créer un BOS
3. Zone = High to Low de la bougie OB
4. Meilleure entrée = 50% de l'OB (Optimal Trade Entry)

### 3. Fair Value Gap (FVG) / Imbalance

#### Définition
Zone de déséquilibre où le prix a bougé trop vite, laissant un "gap" dans la structure.

#### Bullish FVG
```
    Bougie 3: ─┬─   High
               │
    ─────────────── GAP (FVG) → Zone de retour potentiel
               │
    Bougie 1: ─┴─   Low
```
- Gap entre le High de Bougie 1 et le Low de Bougie 3

#### Bearish FVG
```
    Bougie 1: ─┬─   High
               │
    ─────────────── GAP (FVG) → Zone de retour potentiel
               │
    Bougie 3: ─┴─   Low
```
- Gap entre le Low de Bougie 1 et le High de Bougie 3

#### Utilisation
- Le prix tend à "remplir" ces gaps avant de continuer
- Excellentes zones d'entrée en confluence avec OB

### 4. Liquidity Concepts

#### Buy Side Liquidity (BSL)
- Stops des vendeurs au-dessus des highs
- Equal Highs = pool de liquidité
- Les institutions "chassent" ces stops avant de retourner

#### Sell Side Liquidity (SSL)
- Stops des acheteurs en dessous des lows
- Equal Lows = pool de liquidité
- Les institutions "chassent" ces stops avant de retourner

#### Liquidity Sweep / Grab
```
      SSL Hunt
         │
    ─────┴───── Equal Lows (Liquidité)
         │
         ▼
    REVERSAL UP après sweep
```

### 5. Kill Zones (Sessions Optimales)

| Kill Zone | Heure (UTC) | Caractéristiques |
|-----------|-------------|------------------|
| Asian | 00:00 - 06:00 | Range formation, peu de volume |
| London Open | 07:00 - 10:00 | Breakouts, haute volatilité |
| NY Open | 12:00 - 15:00 | Continuations ou reversals |
| London Close | 15:00 - 17:00 | Manipulations, fins de mouvements |

**Focus principal**: London Open + NY Open

---

## Règles d'Entrée

### Setup A: Order Block + FVG (Haute Probabilité)

**Conditions d'entrée LONG:**
1. Tendance HTF (H4/D1) = Haussière
2. BOS confirmé sur timeframe de travail (M15/H1)
3. Prix retrace vers un Bullish Order Block
4. FVG présent dans la zone de l'OB
5. Entrée dans Kill Zone (London ou NY)
6. Confirmation LTF (M1/M5): CHoCH haussier

**Conditions d'entrée SHORT:**
1. Tendance HTF (H4/D1) = Baissière
2. BOS confirmé sur timeframe de travail (M15/H1)
3. Prix retrace vers un Bearish Order Block
4. FVG présent dans la zone de l'OB
5. Entrée dans Kill Zone (London ou NY)
6. Confirmation LTF (M1/M5): CHoCH baissier

```
CHECKLIST SETUP A:
□ HTF Bias confirmé
□ BOS sur TF travail
□ Order Block identifié
□ FVG en confluence
□ Kill Zone active
□ LTF confirmation
→ Si 6/6: TRADE VALIDE (RR 1:2 minimum)
→ Si 5/6: Trade possible (RR 1:1.5)
→ Si <5: NO TRADE
```

### Setup B: Liquidity Sweep + OB (Moyen Probabilité)

**Conditions d'entrée:**
1. Identification pool de liquidité (Equal Highs/Lows)
2. Sweep de la liquidité (mèche au-delà)
3. Rejection immédiate
4. Retour vers OB le plus proche
5. Entrée sur test de l'OB

```
        Liquidity Pool
    ═══════════════════════
            │
            ▼ Sweep (mèche)
            │
    ────────┴────────
            │
            ▼ Rejection
            │
       ┌────┴────┐
       │   OB    │ ← ENTRÉE
       └─────────┘
```

### Setup C: CHoCH + First Pullback (Retournement)

**Pour retournement baissier:**
1. Tendance précédente = Haussière
2. CHoCH identifié (casse du dernier HL)
3. Premier pullback vers zone premium (FVG/OB)
4. Confirmation de rejet
5. Entrée short sur rejection

---

## Gestion des Trades

### Stop Loss

#### Placement
- **Sous/Au-dessus de l'Order Block complet**
- **Buffer**: + Spread + 2 pips
- **Max**: 1.8% du capital (compliance The5ers)

```cpp
// Calcul SL pour Bullish OB
double SL = OrderBlockLow - (Spread + 2 * Point);

// Vérification compliance
double SL_Percent = (EntryPrice - SL) / EntryPrice * 100 * Leverage;
if(SL_Percent > MaxSLPercent) {
   // Réduire taille position OU skip trade
}
```

### Take Profit

#### Structure Multi-TP

| TP Level | Position | Target |
|----------|----------|--------|
| TP1 | 40% | 1:1 RR |
| TP2 | 30% | Prochain swing high/low |
| TP3 | 30% | Liquidity pool opposée |

#### Trailing Stop
- Activé après TP1
- Trail sous/au-dessus dernier swing LTF
- Minimum: Break-even après TP1

### Gestion du Risque par Trade

```cpp
// Challenge Mode
double CalculateLotSize_Challenge() {
   double riskAmount = AccountBalance * 0.015;  // 1.5%
   double slPips = MathAbs(EntryPrice - StopLoss) / Point / 10;
   double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   return NormalizeDouble(riskAmount / (slPips * pipValue), 2);
}

// Funded Mode
double CalculateLotSize_Funded() {
   double riskAmount = AccountBalance * 0.0075; // 0.75%
   double slPips = MathAbs(EntryPrice - StopLoss) / Point / 10;
   double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   return NormalizeDouble(riskAmount / (slPips * pipValue), 2);
}
```

---

## Filtres et Confluences

### Filtres Obligatoires

1. **Spread Filter**
   - Max spread: 1.5 pips (majors), 2.5 pips (minors)
   - Skip trade si spread > limite

2. **News Filter**
   - Pas de trade 5 min avant/après high impact
   - Source: ForexFactory, Investing.com

3. **Session Filter**
   - Trade uniquement dans Kill Zones
   - Éviter Asian range (sauf si swing trade HTF)

4. **Volatility Filter**
   - ATR(14) > moyenne mobile ATR(50)
   - Éviter marchés trop calmes

### Confluences Bonus

| Confluence | Points |
|------------|--------|
| HTF Order Block + LTF OB | +2 |
| FVG dans OB | +2 |
| Round Number (ex: 1.1000) | +1 |
| Previous Day High/Low | +1 |
| Session High/Low | +1 |
| Fibonacci 61.8% / 78.6% | +1 |

**Score minimum pour trade:**
- Challenge Mode: 4 points
- Funded Mode: 5 points

---

## Implémentation EA

### Structure du Code

```cpp
//+------------------------------------------------------------------+
//| SMC/ICT Strategy - Core Functions                                |
//+------------------------------------------------------------------+

// Structure pour Order Block
struct OrderBlock {
   double high;
   double low;
   double midpoint;
   datetime time;
   bool isBullish;
   bool isValid;
   int touches;
};

// Structure pour FVG
struct FairValueGap {
   double upper;
   double lower;
   datetime time;
   bool isBullish;
   bool isFilled;
};

// Structure pour Market Structure
struct MarketStructure {
   double lastHH;
   double lastHL;
   double lastLH;
   double lastLL;
   int trend;  // 1 = Up, -1 = Down, 0 = Range
   bool bosConfirmed;
   bool chochDetected;
};
```

### Détection Order Block

```cpp
bool DetectOrderBlock(int shift, OrderBlock &ob) {
   // Vérifier si bougie précède un mouvement impulsif
   double candleRange = High[shift] - Low[shift];
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14, shift);

   // Mouvement suivant doit être > 2x ATR
   double moveAfter = 0;
   for(int i = shift - 1; i >= shift - 3 && i >= 0; i--) {
      moveAfter += MathAbs(Close[i] - Open[i]);
   }

   if(moveAfter < atr * 2) return false;

   // Déterminer direction
   bool bullishMove = Close[shift - 3] > High[shift];
   bool bearishMove = Close[shift - 3] < Low[shift];

   if(bullishMove && Close[shift] < Open[shift]) {
      // Bullish OB (dernière bougie baissière avant montée)
      ob.high = High[shift];
      ob.low = Low[shift];
      ob.midpoint = (ob.high + ob.low) / 2;
      ob.time = Time[shift];
      ob.isBullish = true;
      ob.isValid = true;
      ob.touches = 0;
      return true;
   }

   if(bearishMove && Close[shift] > Open[shift]) {
      // Bearish OB (dernière bougie haussière avant descente)
      ob.high = High[shift];
      ob.low = Low[shift];
      ob.midpoint = (ob.high + ob.low) / 2;
      ob.time = Time[shift];
      ob.isBullish = false;
      ob.isValid = true;
      ob.touches = 0;
      return true;
   }

   return false;
}
```

### Détection FVG

```cpp
bool DetectFVG(int shift, FairValueGap &fvg) {
   // Vérifier gap entre bougie 1 et bougie 3
   double candle1High = High[shift + 2];
   double candle1Low = Low[shift + 2];
   double candle3High = High[shift];
   double candle3Low = Low[shift];

   // Bullish FVG: Low[3] > High[1]
   if(candle3Low > candle1High) {
      fvg.upper = candle3Low;
      fvg.lower = candle1High;
      fvg.time = Time[shift + 1];
      fvg.isBullish = true;
      fvg.isFilled = false;
      return true;
   }

   // Bearish FVG: High[3] < Low[1]
   if(candle3High < candle1Low) {
      fvg.upper = candle1Low;
      fvg.lower = candle3High;
      fvg.time = Time[shift + 1];
      fvg.isBullish = false;
      fvg.isFilled = false;
      return true;
   }

   return false;
}
```

### Détection Structure de Marché

```cpp
void UpdateMarketStructure(MarketStructure &ms) {
   int lookback = 50;
   double swings[];
   int swingTypes[];  // 1 = High, -1 = Low

   // Identifier les swings
   for(int i = 2; i < lookback; i++) {
      // Swing High
      if(High[i] > High[i+1] && High[i] > High[i+2] &&
         High[i] > High[i-1] && High[i] > High[i-2]) {
         // Ajouter swing high
      }
      // Swing Low
      if(Low[i] < Low[i+1] && Low[i] < Low[i+2] &&
         Low[i] < Low[i-1] && Low[i] < Low[i-2]) {
         // Ajouter swing low
      }
   }

   // Analyser structure
   // ... (logique HH/HL/LH/LL)

   // Détecter BOS
   if(ms.trend == 1 && Close[0] > ms.lastHH) {
      ms.bosConfirmed = true;
   }

   // Détecter CHoCH
   if(ms.trend == 1 && Close[0] < ms.lastHL) {
      ms.chochDetected = true;
   }
}
```

### Kill Zone Check

```cpp
bool IsInKillZone() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;

   // London Kill Zone: 07:00 - 10:00 UTC
   if(hour >= 7 && hour < 10) return true;

   // NY Kill Zone: 12:00 - 15:00 UTC
   if(hour >= 12 && hour < 15) return true;

   // London Close: 15:00 - 17:00 UTC (optional)
   if(UseLondonClose && hour >= 15 && hour < 17) return true;

   return false;
}
```

---

## Backtesting Guidelines

### Paramètres de Backtest

| Paramètre | Valeur |
|-----------|--------|
| Période | 2019-2024 (5 ans minimum) |
| Qualité ticks | 99% (tick data réel) |
| Spread | Variable (réaliste) |
| Commission | Inclure |
| Slippage | 1-2 pips |

### Métriques Cibles

| Métrique | Minimum | Optimal |
|----------|---------|---------|
| Net Profit | >50% | >100% |
| Profit Factor | >1.5 | >2.0 |
| Win Rate | >50% | >55% |
| Max Drawdown | <10% | <6% |
| Sharpe Ratio | >1.0 | >1.5 |
| Recovery Factor | >3 | >5 |
| Total Trades | >500 | >1000 |

### Validation

1. **In-Sample** (2019-2022): Optimisation
2. **Out-of-Sample** (2023-2024): Validation
3. **Forward Test** (3 mois démo): Confirmation

---

## Journaling Template

```markdown
## Trade #XXX - [DATE]

**Setup**: [A/B/C]
**Pair**: [EURUSD/GBPUSD/etc]
**Direction**: [LONG/SHORT]

### Pre-Trade Checklist
- [ ] HTF Bias:
- [ ] BOS confirmé:
- [ ] Order Block identifié:
- [ ] FVG confluence:
- [ ] Kill Zone:
- [ ] LTF confirmation:
- [ ] News check:

### Entry Details
- Entry Price:
- Stop Loss:
- TP1 (40%):
- TP2 (30%):
- TP3 (30%):
- Risk %:
- Lot Size:

### Confluences (Score: X/10)
- [ ] HTF OB
- [ ] FVG
- [ ] Round Number
- [ ] PDH/PDL
- [ ] Session H/L
- [ ] Fib Level

### Result
- Outcome: [WIN/LOSS/BE]
- P&L:
- R Multiple:
- Notes:

### Screenshot
[Insérer screenshot]
```

---

## Sources et Références

- [Smart Money Concepts Guide](https://www.mindmathmoney.com/articles/smart-money-concepts-the-ultimate-guide-to-trading-like-institutional-investors-in-2025)
- [ICT Order Flow Concepts](https://www.forexfactory.com/thread/1347624-learn-ict-order-flow-smart-money-concepts)
- [FXOpen SMC Guide](https://fxopen.com/blog/en/smart-money-concept-and-how-to-use-it-in-trading/)
- [XS Smart Money Guide](https://www.xs.com/en/blog/smart-money-concept/)
