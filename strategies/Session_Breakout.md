# Stratégie Session Breakout

> Stratégie secondaire exploitant les breakouts du range asiatique pendant les sessions London/NY

---

## Concept

### Principe

Le marché forme généralement un range pendant la session asiatique (faible volume). L'ouverture de Londres ou New York provoque souvent un breakout directionnel de ce range.

### Avantages pour Prop Firms

- **Win Rate élevé**: 55-62% avec bons filtres
- **SL Contrôlé**: Basé sur le range (prévisible)
- **Timing précis**: Trades en Kill Zones uniquement
- **Automatisable**: Règles mécaniques claires

---

## Définition du Range Asiatique

### Horaires (UTC)

| Élément | Heure UTC |
|---------|-----------|
| Début Range | 00:00 |
| Fin Range | 06:00 |
| London Open | 07:00 |
| NY Open | 12:00 |

### Calcul du Range

```cpp
struct AsianRange {
   double high;
   double low;
   double midpoint;
   double size;
   datetime startTime;
   datetime endTime;
   bool isValid;
};

AsianRange CalculateAsianRange() {
   AsianRange range;

   // Trouver le début de la session asiatique (00:00 UTC du jour)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime asianStart = StructToTime(dt);

   // Fin à 06:00 UTC
   datetime asianEnd = asianStart + 6 * 3600;

   // Calculer High/Low
   int startBar = iBarShift(_Symbol, PERIOD_M15, asianStart);
   int endBar = iBarShift(_Symbol, PERIOD_M15, asianEnd);

   if(startBar < 0 || endBar < 0) {
      range.isValid = false;
      return range;
   }

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   CopyHigh(_Symbol, PERIOD_M15, endBar, startBar - endBar + 1, highs);
   CopyLow(_Symbol, PERIOD_M15, endBar, startBar - endBar + 1, lows);

   range.high = highs[ArrayMaximum(highs)];
   range.low = lows[ArrayMinimum(lows)];
   range.midpoint = (range.high + range.low) / 2;
   range.size = (range.high - range.low) / _Point;
   range.startTime = asianStart;
   range.endTime = asianEnd;

   // Validité: Range pas trop petit ni trop grand
   double atr = iATR(_Symbol, PERIOD_H1, 14, 0);
   range.isValid = (range.size >= atr * 0.3 && range.size <= atr * 2.0);

   return range;
}
```

---

## Règles d'Entrée

### Breakout Long

```
CONDITIONS:
1. Range asiatique valide (pas trop étroit/large)
2. Prix casse au-dessus du High du range
3. Momentum confirmé: Bougie de breakout > 50% du range
4. Volume: Supérieur à la moyenne 20 périodes
5. Spread < 1.5 pips
6. Pas de news high impact dans 30 min

ENTRÉE:
- Sur clôture de bougie au-dessus du range high + buffer
- Ou sur pullback vers le range high (meilleur RR)
```

### Breakout Short

```
CONDITIONS:
1. Range asiatique valide
2. Prix casse en dessous du Low du range
3. Momentum confirmé: Bougie de breakout > 50% du range
4. Volume: Supérieur à la moyenne 20 périodes
5. Spread < 1.5 pips
6. Pas de news high impact dans 30 min

ENTRÉE:
- Sur clôture de bougie en dessous du range low - buffer
- Ou sur pullback vers le range low
```

### Filtres Additionnels

```cpp
bool ValidateBreakout(AsianRange &range, bool isLong) {
   // 1. Momentum (taille bougie breakout)
   double close[], open[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   CopyClose(_Symbol, PERIOD_M15, 0, 2, close);
   CopyOpen(_Symbol, PERIOD_M15, 0, 2, open);

   double candleSize = MathAbs(close[1] - open[1]);
   if(candleSize < range.size * _Point * 0.5) return false;

   // 2. Direction correcte
   if(isLong && close[1] < open[1]) return false;  // Bougie baissière
   if(!isLong && close[1] > open[1]) return false; // Bougie haussière

   // 3. HTF Bias (optionnel mais recommandé)
   double ema50 = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema200 = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(isLong && ema50 < ema200) return false;  // Contre-tendance
   if(!isLong && ema50 > ema200) return false; // Contre-tendance

   // 4. ATR filter (volatilité suffisante)
   double atr = iATR(_Symbol, PERIOD_H1, 14, 0);
   double avgATR = 0;
   double atrBuffer[20];
   CopyBuffer(iATR(_Symbol, PERIOD_H1, 14), 0, 0, 20, atrBuffer);
   for(int i = 0; i < 20; i++) avgATR += atrBuffer[i];
   avgATR /= 20;

   if(atr < avgATR * 0.8) return false;  // Volatilité trop basse

   return true;
}
```

---

## Gestion de Position

### Stop Loss

```
MÉTHODE 1 (Standard):
- Long: SL = Range Low - (Spread + 5 pips buffer)
- Short: SL = Range High + (Spread + 5 pips buffer)

MÉTHODE 2 (ATR-based):
- SL = 1.5 × ATR(14) depuis l'entrée

CHOIX:
- Utiliser le PLUS LARGE des deux pour éviter stops prématurés
- Mais vérifier compliance avec règles prop firm (ex: 2% max The5ers)
```

### Take Profit (Multi-TP)

```
TP1 (40% position): 1:1 Risk/Reward
TP2 (30% position): Extension du range (1.5× range size)
TP3 (30% position): Trailing stop ou niveau technique

EXEMPLE:
- Range: 30 pips
- Entry Long: 1.1030 (breakout)
- SL: 1.0995 (35 pips)
- TP1: 1.1065 (35 pips = 1:1)
- TP2: 1.1085 (55 pips = 1.5× range)
- TP3: Trailing ou structure
```

### Trailing Stop

```cpp
void ApplyTrailingStop(ulong ticket, double entryPrice, bool isLong) {
   if(!positionInfo.SelectByTicket(ticket)) return;

   double currentSL = positionInfo.StopLoss();
   double currentPrice = isLong ?
      SymbolInfoDouble(_Symbol, SYMBOL_BID) :
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Trailing basé sur ATR
   double atr[];
   CopyBuffer(g_atrHandle, 0, 0, 1, atr);
   double trailDistance = atr[0] * 1.5;

   if(isLong) {
      // Profit minimum avant trailing
      if(currentPrice - entryPrice < trailDistance) return;

      double newSL = currentPrice - trailDistance;
      if(newSL > currentSL && newSL > entryPrice) {
         trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
      }
   }
   else {
      if(entryPrice - currentPrice < trailDistance) return;

      double newSL = currentPrice + trailDistance;
      if(newSL < currentSL && newSL < entryPrice) {
         trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
      }
   }
}
```

---

## Variantes

### 1. Breakout Pullback Entry

```
Au lieu d'entrer sur le breakout:
1. Attendre breakout initial
2. Attendre pullback vers le range high/low
3. Entrer sur rejection (bougie de confirmation)

AVANTAGE: Meilleur RR (SL plus serré)
INCONVÉNIENT: Moins de trades (pullback pas toujours)
```

### 2. Failed Breakout (Fade)

```
Si le breakout échoue:
1. Prix casse au-dessus du range high
2. Rejette et revient dans le range
3. SHORT sur cassure du range low (ou vice-versa)

SIGNAL: Liquidité chassée puis retournement
WIN RATE: Plus bas mais RR élevé (1:2 - 1:3)
```

### 3. Range Expansion

```
Pour ranges très étroits (< 0.5× ATR):
1. Expansion souvent violente
2. Utiliser TP plus agressifs
3. Trailing dès le début

Pour ranges larges (> 1.5× ATR):
1. Réduire taille position
2. TP conservateurs
3. Ou skip le trade
```

---

## Statistiques Attendues

| Métrique | Value |
|----------|-------|
| Win Rate | 55-62% |
| RR Moyen | 1:1.3 - 1:1.8 |
| Profit Factor | 1.4 - 1.8 |
| Trades/Semaine | 3-5 |
| Max Consec. Losses | 3-4 |
| Best Pairs | EUR/USD, GBP/USD, USD/JPY |

---

## Configuration EA

```cpp
//+------------------------------------------------------------------+
//| Session Breakout - Input Parameters                              |
//+------------------------------------------------------------------+
input group "=== RANGE SETTINGS ==="
input int AsianStartHour = 0;          // Asian Session Start (UTC)
input int AsianEndHour = 6;            // Asian Session End (UTC)
input double MinRangePips = 15;        // Minimum Range Size (pips)
input double MaxRangePips = 60;        // Maximum Range Size (pips)
input double RangeATRMin = 0.3;        // Min Range as ATR multiple
input double RangeATRMax = 2.0;        // Max Range as ATR multiple

input group "=== BREAKOUT SETTINGS ==="
input double BreakoutBuffer = 3;       // Pips above/below range for entry
input double MomentumMinPercent = 50;  // Min candle size as % of range
input bool UseHTFFilter = true;        // Use HTF trend filter
input ENUM_TIMEFRAMES HTF = PERIOD_H4; // Higher Timeframe
input int EMAPeriodFast = 50;          // Fast EMA Period
input int EMAPeriodSlow = 200;         // Slow EMA Period

input group "=== TAKE PROFIT ==="
input double TP1_RR = 1.0;             // TP1 Risk:Reward
input double TP1_Percent = 40;         // TP1 Position %
input double TP2_RangeMultiple = 1.5;  // TP2 as multiple of range
input double TP2_Percent = 30;         // TP2 Position %
input bool UseTrailing = true;         // Use Trailing for TP3
input double TrailingATRMult = 1.5;    // Trailing ATR Multiplier

input group "=== FILTERS ==="
input double MaxSpread = 1.5;          // Maximum Spread (pips)
input bool TradeLondonOpen = true;     // Trade London Open
input bool TradeNYOpen = true;         // Trade NY Open
input int NewsFilterMinutes = 30;      // Minutes around news to avoid
```

---

## Combinaison avec SMC

```
SYNERGIES:
1. Range High/Low souvent = Liquidity Pools
2. Breakout peut être confirmé par BOS
3. Pullback entry = retour vers OB potentiel
4. Failed breakout = Liquidity Sweep setup

EXEMPLE COMBO:
- Asian Range High = Equal Highs (BSL)
- Breakout initial = Sweep de liquidité
- Rejection = CHoCH sur M5
- Retour dans range = Entrée vers OB
```

---

## Journaling Template

```markdown
## Session Breakout Trade #XXX

**Date**:
**Session**: [London/NY]
**Pair**:

### Range Details
- Asian High:
- Asian Low:
- Range Size (pips):
- Valid: [Y/N]

### Entry
- Direction: [Long/Short]
- Entry Price:
- Entry Time:
- Trigger: [Breakout/Pullback]

### Risk Management
- SL:
- TP1:
- TP2:
- TP3 Method:
- Risk %:

### Filters Passed
- [ ] Momentum check
- [ ] HTF alignment
- [ ] Spread OK
- [ ] No news
- [ ] Volume OK

### Result
- Outcome:
- P&L:
- Exit Reason:
- Notes:
```
