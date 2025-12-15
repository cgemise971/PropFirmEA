# Guide de Gestion des Risques - PropFirm EA

> Document critique pour la préservation du capital et le respect des règles des prop firms

---

## Table des Matières

1. [Philosophie de Gestion du Risque](#1-philosophie)
2. [Circuit Breakers](#2-circuit-breakers)
3. [Calcul de Position](#3-calcul-de-position)
4. [Gestion du Drawdown](#4-gestion-du-drawdown)
5. [Diversification Multi-Comptes](#5-diversification)
6. [Protocoles d'Urgence](#6-protocoles-durgence)
7. [Monitoring et Alertes](#7-monitoring)

---

## 1. Philosophie de Gestion du Risque {#1-philosophie}

### Principe Fondamental

> **"La préservation du capital prime sur la recherche de profit"**

La survie du compte est la priorité absolue. Un compte qui breach est un investissement perdu (coût du challenge + temps).

### Hiérarchie des Priorités

```
1. Ne JAMAIS atteindre le drawdown max
2. Ne JAMAIS atteindre le drawdown journalier
3. Respecter les règles spécifiques (2% rule, news, etc.)
4. Atteindre le profit target
5. Optimiser les gains
```

### Approche Asymétrique

| Mode | Objectif | Tolérance au Risque |
|------|----------|---------------------|
| Challenge | Passer rapidement | Modérée (1-2% par trade) |
| Funded | Revenus stables | Faible (0.5-0.75% par trade) |

---

## 2. Circuit Breakers {#2-circuit-breakers}

### Système de Niveaux

```
┌─────────────────────────────────────────────────────────────────┐
│                    CIRCUIT BREAKER SYSTEM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ████████████████████████████████████████░░░░░░░░░░  DD = 0%    │
│                                                                  │
│  NIVEAU 1 (Alerte)      @ -1.5% journalier                      │
│  ├── Action: Réduire risk à 50%                                 │
│  ├── Max trades restants: 1                                     │
│  └── Notification: SMS/Email                                    │
│                                                                  │
│  NIVEAU 2 (Warning)     @ -2.5% journalier                      │
│  ├── Action: STOP trading 4 heures                              │
│  ├── Fermer positions en profit                                 │
│  └── Notification: SMS + Call                                   │
│                                                                  │
│  NIVEAU 3 (Critical)    @ -3.5% journalier                      │
│  ├── Action: STOP trading journée complète                      │
│  ├── Fermer TOUTES positions                                    │
│  └── Review obligatoire avant reprise                           │
│                                                                  │
│  NIVEAU 4 (Emergency)   @ -4.5% journalier (buffer final)       │
│  ├── Action: EA désactivé automatiquement                       │
│  ├── Compte en mode observation                                 │
│  └── Intervention manuelle requise                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implémentation Code

```cpp
enum CIRCUIT_BREAKER_LEVEL {
   CB_NORMAL,      // Trading normal
   CB_ALERT,       // Niveau 1 - Risk réduit
   CB_WARNING,     // Niveau 2 - Pause 4h
   CB_CRITICAL,    // Niveau 3 - Stop jour
   CB_EMERGENCY    // Niveau 4 - EA off
};

CIRCUIT_BREAKER_LEVEL GetCircuitBreakerLevel(double dailyDD) {
   if(dailyDD >= 4.5) return CB_EMERGENCY;
   if(dailyDD >= 3.5) return CB_CRITICAL;
   if(dailyDD >= 2.5) return CB_WARNING;
   if(dailyDD >= 1.5) return CB_ALERT;
   return CB_NORMAL;
}

double GetAdjustedRisk(CIRCUIT_BREAKER_LEVEL level, double baseRisk) {
   switch(level) {
      case CB_ALERT:    return baseRisk * 0.5;
      case CB_WARNING:  return 0;
      case CB_CRITICAL: return 0;
      case CB_EMERGENCY: return 0;
      default: return baseRisk;
   }
}
```

### Circuit Breaker Drawdown Total

```
┌─────────────────────────────────────────────────────────────────┐
│                 TOTAL DRAWDOWN PROTECTION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DD Total @ 5%:  Réduire risk à 0.5%                            │
│  DD Total @ 6%:  Max 1 trade/jour, RR minimum 1:2               │
│  DD Total @ 7%:  STOP trading - Analyse requise                 │
│  DD Total @ 8%:  Mode recovery uniquement                       │
│  DD Total @ 9%:  EA OFF - Buffer final avant breach             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Calcul de Position {#3-calcul-de-position}

### Formule Standard

```
Lot Size = (Capital × Risk%) / (SL_pips × Valeur_pip)
```

### Exemple Détaillé

```
Paramètres:
- Capital: $100,000
- Risk: 1.5%
- SL: 25 pips
- Paire: EUR/USD
- Valeur pip (1 lot): $10

Calcul:
Risk Amount = $100,000 × 0.015 = $1,500
SL en $ = 25 pips × $10 × Lots
Lots = $1,500 / (25 × $10) = 6.0 lots
```

### Ajustements Dynamiques

```cpp
double CalculateDynamicLotSize(double baseRisk) {
   double currentDD = GetCurrentDrawdown();
   double adjustedRisk = baseRisk;

   // Réduction progressive basée sur DD
   if(currentDD > 5.0) {
      adjustedRisk *= 0.5;  // 50% reduction
   }
   else if(currentDD > 3.0) {
      adjustedRisk *= 0.75; // 25% reduction
   }

   // Réduction si losing streak
   int consecutiveLosses = GetConsecutiveLosses();
   if(consecutiveLosses >= 3) {
      adjustedRisk *= 0.5;
   }
   else if(consecutiveLosses >= 2) {
      adjustedRisk *= 0.75;
   }

   // Augmentation légère si en profit (compound)
   if(currentDD < 0 && GetMonthlyProfit() > 3.0) {
      adjustedRisk *= 1.1;  // 10% increase max
   }

   return adjustedRisk;
}
```

### Limites The5ers (Règle 2%)

```cpp
bool ValidateSLCompliance(double entry, double sl, double capital) {
   double slPercent = MathAbs(entry - sl) / entry * 100;

   // The5ers: Max 2% SL
   if(PropFirmProfile == PROP_THE5ERS_BOOT) {
      if(slPercent > 1.8) {  // Buffer de 0.2%
         Print("ALERTE: SL dépasse limite 2% - ", slPercent, "%");
         return false;
      }
   }

   return true;
}

// Si SL trop large, ajuster la taille de position
double AdjustLotForSLCompliance(double lots, double entry, double sl) {
   double slPercent = MathAbs(entry - sl) / entry * 100;

   if(slPercent > MaxSLPercent) {
      double ratio = MaxSLPercent / slPercent;
      lots = lots * ratio;
   }

   return NormalizeDouble(lots, 2);
}
```

---

## 4. Gestion du Drawdown {#4-gestion-du-drawdown}

### Types de Drawdown

#### Drawdown Statique (FTMO, Funding Pips)
```
Plancher = Capital Initial × (1 - MaxDD%)

Exemple: $100,000 compte, 10% max DD
Plancher = $100,000 × 0.90 = $90,000

Même si équité monte à $115,000, plancher reste $90,000
```

#### Drawdown Trailing (E8 certains programmes)
```
Plancher = Highest Equity - MaxDD%

Exemple: High Water Mark = $110,000, 8% trailing
Plancher = $110,000 × 0.92 = $101,200

Le plancher monte avec les profits mais ne descend jamais
```

### Stratégie de Recovery

```
┌─────────────────────────────────────────────────────────────────┐
│                    RECOVERY PROTOCOL                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DD atteint 5%:                                                  │
│  ├── Analyse des derniers trades                                │
│  ├── Identifier pattern de pertes                               │
│  ├── Réduire risk à 0.5%                                        │
│  └── Objectif: Regagner 2% avant retour normal                  │
│                                                                  │
│  DD atteint 7%:                                                  │
│  ├── Stop trading minimum 24h                                   │
│  ├── Review complet de la stratégie                             │
│  ├── Backtester conditions récentes                             │
│  ├── Risk @ 0.25% pour recovery                                 │
│  └── Setup A uniquement (haute probabilité)                     │
│                                                                  │
│  DD atteint 8%+:                                                 │
│  ├── Considérer: Accepter la perte vs risquer breach            │
│  ├── Si continuation: Risk @ 0.2%, 1 trade/jour max             │
│  └── Alternative: Nouveau challenge peut être préférable        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Calcul du Coussin de Sécurité

```cpp
double CalculateSafetyBuffer() {
   double maxDD = g_propSettings.maxTotalDD;
   double currentDD = GetCurrentDrawdown();
   double remainingDD = maxDD - currentDD;

   // Buffer minimum: 1%
   double minBuffer = 1.0;

   // Buffer recommandé: 2% au-dessus du niveau critique
   double recommendedBuffer = 2.0;

   if(remainingDD < minBuffer) {
      return 0;  // STOP TRADING
   }

   if(remainingDD < recommendedBuffer) {
      return (remainingDD - minBuffer) / remainingDD;  // Ratio de réduction
   }

   return 1.0;  // Trading normal
}
```

---

## 5. Diversification Multi-Comptes {#5-diversification}

### Stratégie de Flotte

```
┌─────────────────────────────────────────────────────────────────┐
│                 FLEET MANAGEMENT STRATEGY                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OBJECTIF: 10 comptes funded = $1,000,000 capital géré          │
│                                                                  │
│  RÉPARTITION:                                                    │
│  ┌──────────────┬────────┬─────────┬──────────────────────┐     │
│  │ Prop Firm    │ Comptes│ Capital │ Stratégie            │     │
│  ├──────────────┼────────┼─────────┼──────────────────────┤     │
│  │ FTMO         │ 3      │ $300K   │ SMC + Session Break  │     │
│  │ E8 Markets   │ 3      │ $300K   │ SMC + Liquidity      │     │
│  │ Funding Pips │ 2      │ $200K   │ SMC Conservative     │     │
│  │ The5ers      │ 2      │ $200K   │ SMC (2% rule comp.)  │     │
│  └──────────────┴────────┴─────────┴──────────────────────┘     │
│                                                                  │
│  AVANTAGES:                                                      │
│  ✓ Si 1 compte breach, 9 autres continuent                      │
│  ✓ Diversification des règles et restrictions                   │
│  ✓ Meilleur ratio payout (différentes dates)                    │
│  ✓ Scaling parallèle possible                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Décorrélation des Stratégies

| Compte | Paires | Session | Stratégie |
|--------|--------|---------|-----------|
| 1-2 | EUR/USD, GBP/USD | London | SMC OB+FVG |
| 3-4 | USD/JPY, EUR/JPY | Tokyo/NY | Session Breakout |
| 5-6 | Gold, Indices | NY | Liquidity Sweep |
| 7-8 | EUR/GBP, AUD/USD | London | Mean Reversion |
| 9-10 | Mix | All | Hybrid Adaptive |

### Gestion des Corrélations

```cpp
// Éviter trades corrélés simultanés
bool CheckCorrelation(string symbol1, string symbol2) {
   // Paires EUR fortement corrélées
   if(StringFind(symbol1, "EUR") >= 0 && StringFind(symbol2, "EUR") >= 0) {
      return true;  // Corrélés
   }

   // USD contre plusieurs paires
   if(StringFind(symbol1, "USD") >= 0 && StringFind(symbol2, "USD") >= 0) {
      // Vérifier si même direction
      return true;
   }

   // JPY safe-haven
   if(StringFind(symbol1, "JPY") >= 0 && StringFind(symbol2, "JPY") >= 0) {
      return true;
   }

   return false;
}

// Limiter exposition corrélée
double GetCorrelatedExposure(string newSymbol) {
   double totalExposure = 0;

   for(int i = 0; i < PositionsTotal(); i++) {
      if(positionInfo.SelectByIndex(i)) {
         if(CheckCorrelation(newSymbol, positionInfo.Symbol())) {
            totalExposure += positionInfo.Volume();
         }
      }
   }

   return totalExposure;
}
```

---

## 6. Protocoles d'Urgence {#6-protocoles-durgence}

### Événements Déclencheurs

```
┌─────────────────────────────────────────────────────────────────┐
│                  EMERGENCY PROTOCOLS                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FLASH CRASH DÉTECTÉ:                                           │
│  Condition: Move > 5× ATR en < 5 minutes                        │
│  Action: Fermer toutes positions, stop EA 1 heure               │
│                                                                  │
│  SPREAD ANOMALIE:                                                │
│  Condition: Spread > 10× normal                                 │
│  Action: Pas de nouveaux trades, trailing tight sur existants   │
│                                                                  │
│  CONNEXION PERDUE:                                               │
│  Condition: Pas de tick > 30 secondes                           │
│  Action: Alerte, SL/TP déjà en place (broker-side)              │
│                                                                  │
│  NEWS NON-ANTICIPÉE:                                             │
│  Condition: Volatilité soudaine sans news calendrier            │
│  Action: Réduire positions de 50%, élargir SL temporairement    │
│                                                                  │
│  DRAWDOWN RAPIDE:                                                │
│  Condition: -2% en < 1 heure                                    │
│  Action: Stop trading, analyse, intervention manuelle           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Code de Protection Flash Crash

```cpp
bool DetectFlashCrash() {
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(g_atrHandle, 0, 0, 20, atr);

   double avgATR = 0;
   for(int i = 5; i < 20; i++) avgATR += atr[i];
   avgATR /= 15;

   // Move des 5 dernières minutes
   double high5min = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, 5, 0));
   double low5min = iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, 5, 0));
   double move5min = high5min - low5min;

   if(move5min > avgATR * 5) {
      Print("FLASH CRASH DÉTECTÉ! Move: ", move5min, " vs ATR: ", avgATR);
      return true;
   }

   return false;
}
```

---

## 7. Monitoring et Alertes {#7-monitoring}

### Dashboard de Risque

```
╔═══════════════════════════════════════════════════════════════╗
║                    RISK MONITOR DASHBOARD                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                                 ║
║  DAILY P&L:     [████████████░░░░░░░░]  +2.1% / -4.5%         ║
║  TOTAL DD:      [██░░░░░░░░░░░░░░░░░░]  1.2% / 9.0%           ║
║  TRADES TODAY:  [████░░░░░░░░░░░░░░░░]  2 / 4                  ║
║  OPEN RISK:     [███░░░░░░░░░░░░░░░░░]  1.5%                   ║
║                                                                 ║
║  STATUS: ● NORMAL                                               ║
║                                                                 ║
║  ┌─────────────────────────────────────────────────────────┐   ║
║  │ Position 1: EUR/USD LONG  +45 pips  Risk: 0.75%         │   ║
║  │ Position 2: GBP/USD SHORT -12 pips  Risk: 0.75%         │   ║
║  └─────────────────────────────────────────────────────────┘   ║
║                                                                 ║
║  ALERTES RÉCENTES:                                              ║
║  [14:32] Spread élevé sur GBP/USD - Trade skipped              ║
║  [09:15] News filter activé - NFP                               ║
║                                                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

### Système d'Alertes

```cpp
enum ALERT_LEVEL {
   ALERT_INFO,
   ALERT_WARNING,
   ALERT_CRITICAL,
   ALERT_EMERGENCY
};

void SendAlert(ALERT_LEVEL level, string message) {
   string prefix = "";

   switch(level) {
      case ALERT_INFO:
         prefix = "[INFO] ";
         break;
      case ALERT_WARNING:
         prefix = "[WARNING] ";
         PlaySound("alert.wav");
         break;
      case ALERT_CRITICAL:
         prefix = "[CRITICAL] ";
         PlaySound("alert2.wav");
         SendNotification(prefix + message);  // Push notification
         break;
      case ALERT_EMERGENCY:
         prefix = "[EMERGENCY] ";
         PlaySound("alert2.wav");
         SendNotification(prefix + message);
         SendMail("EA EMERGENCY", prefix + message);  // Email
         break;
   }

   Print(prefix + message);
}

// Usage
void CheckAndAlert() {
   double dailyDD = GetDailyDrawdown();

   if(dailyDD >= 4.0) {
      SendAlert(ALERT_EMERGENCY, "Daily DD at " + DoubleToString(dailyDD, 2) + "%!");
   }
   else if(dailyDD >= 3.0) {
      SendAlert(ALERT_CRITICAL, "Daily DD approaching limit: " + DoubleToString(dailyDD, 2) + "%");
   }
   else if(dailyDD >= 2.0) {
      SendAlert(ALERT_WARNING, "Daily DD elevated: " + DoubleToString(dailyDD, 2) + "%");
   }
}
```

### Logs et Reporting

```cpp
void LogTrade(string action, double lots, double price, double sl, double tp) {
   string logEntry = StringFormat(
      "%s | %s | %s | Lots: %.2f | Price: %.5f | SL: %.5f | TP: %.5f | Risk: %.2f%% | DD: %.2f%%",
      TimeToString(TimeCurrent()),
      _Symbol,
      action,
      lots,
      price,
      sl,
      tp,
      CalculateTradeRisk(lots, price, sl),
      GetCurrentDrawdown()
   );

   // Écrire dans fichier log
   int handle = FileOpen("PropFirmEA_Trades.log", FILE_WRITE|FILE_READ|FILE_TXT);
   if(handle != INVALID_HANDLE) {
      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, logEntry + "\n");
      FileClose(handle);
   }

   Print(logEntry);
}
```

### Rapport Journalier Automatique

```cpp
void GenerateDailyReport() {
   string report = "";
   report += "═══════════════════════════════════════\n";
   report += "      DAILY TRADING REPORT\n";
   report += "      " + TimeToString(TimeCurrent(), TIME_DATE) + "\n";
   report += "═══════════════════════════════════════\n";
   report += "Profile: " + EnumToString(PropFirmProfile) + "\n";
   report += "Mode: " + EnumToString(TradeMode) + "\n";
   report += "───────────────────────────────────────\n";
   report += "PERFORMANCE:\n";
   report += StringFormat("  Trades: %d\n", g_stats.tradesToday);
   report += StringFormat("  Win Rate: %.1f%%\n", GetDailyWinRate());
   report += StringFormat("  P&L: %.2f%%\n", g_stats.dailyPnL);
   report += StringFormat("  Profit Factor: %.2f\n", GetDailyProfitFactor());
   report += "───────────────────────────────────────\n";
   report += "RISK:\n";
   report += StringFormat("  Max DD Today: %.2f%%\n", GetMaxDailyDD());
   report += StringFormat("  Total DD: %.2f%%\n", g_stats.totalDD);
   report += StringFormat("  Circuit Breaker: %s\n", EnumToString(GetCircuitBreakerLevel(GetDailyDrawdown())));
   report += "───────────────────────────────────────\n";
   report += "ACCOUNT:\n";
   report += StringFormat("  Balance: $%.2f\n", AccountInfoDouble(ACCOUNT_BALANCE));
   report += StringFormat("  Equity: $%.2f\n", AccountInfoDouble(ACCOUNT_EQUITY));
   report += StringFormat("  Remaining DD: %.2f%%\n", g_propSettings.maxTotalDD - g_stats.totalDD);
   report += "═══════════════════════════════════════\n";

   // Envoyer par email ou notification
   SendMail("Daily Report - " + TimeToString(TimeCurrent(), TIME_DATE), report);
}
```

---

## Checklist Quotidienne

```markdown
## PRÉ-SESSION
□ Vérifier équité vs plancher DD
□ Vérifier DD journalier disponible
□ Consulter calendrier économique
□ Vérifier spread actuel
□ Confirmer Kill Zone active

## PENDANT SESSION
□ Monitorer DD en temps réel
□ Vérifier circuit breaker status
□ Logger chaque trade
□ Respecter max trades/jour

## POST-SESSION
□ Générer rapport journalier
□ Analyser trades du jour
□ Calculer métriques (WR, PF, etc.)
□ Planifier ajustements si nécessaire
□ Backup des logs
```

---

## Conclusion

La gestion du risque est le facteur #1 de succès sur les prop firms. Un système robuste de circuit breakers, un calcul de position rigoureux, et un monitoring constant sont essentiels pour:

1. **Passer les challenges** sans breach
2. **Maintenir les comptes funded** sur le long terme
3. **Générer des revenus stables** via les payouts

**Règle d'or**: Il vaut mieux rater un trade que de breach un compte.
