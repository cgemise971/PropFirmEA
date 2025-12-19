//+------------------------------------------------------------------+
//|                                       PropFirm_Scalper_v8.mq5    |
//|                                                                  |
//|  SCALPER HAUTE FREQUENCE - CHALLENGE OPTIMIZER                   |
//|                                                                  |
//|  Objectif: 10-15% mensuel sur challenges prop firms              |
//|  Strategie: Scalping multi-paires, multi-sessions               |
//|  Frequence: 12-15 trades/jour                                   |
//|                                                                  |
//|  Caracteristiques:                                               |
//|  - 4 paires: EURUSD, GBPUSD, USDJPY, XAUUSD                     |
//|  - 4 types d'entrees: Momentum, Breakout, Pullback, Reversal    |
//|  - Compounding agressif (+25% apres 3 wins, +50% apres 5 wins)  |
//|  - Mode Turbo si retard sur challenge                           |
//|  - Dashboard compact et lisible                                  |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Fleet"
#property version   "8.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "Include\Dashboard_v2.mqh"

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_PROP_FIRM {
   PROP_FTMO,           // FTMO (10% DD, 5% daily)
   PROP_E8,             // E8 Markets (8% DD, 5% daily)
   PROP_FUNDINGPIPS,    // Funding Pips (6% DD, 4% daily)
   PROP_THE5ERS         // The5ers (5% DD, 3% daily)
};

enum ENUM_SCALP_MODE {
   MODE_CONSERVATIVE,   // Conservateur (moins de trades)
   MODE_BALANCED,       // Equilibre (recommande)
   MODE_AGGRESSIVE      // Agressif (plus de trades)
};

enum ENUM_ENTRY_TYPE {
   ENTRY_MOMENTUM,      // Momentum (bougie forte)
   ENTRY_BREAKOUT,      // Micro-Breakout (range 1H)
   ENTRY_PULLBACK,      // Pullback EMA21
   ENTRY_REVERSAL       // Reversal RSI extreme
};

//+------------------------------------------------------------------+
//| INPUTS - CONFIGURATION PRINCIPALE                               |
//+------------------------------------------------------------------+
input group "=== PROP FIRM ==="
input ENUM_PROP_FIRM PropFirm = PROP_FTMO;              // Prop Firm
input double ChallengeTarget = 10.0;                     // Objectif Challenge (%)
input int ChallengeDays = 30;                            // Jours du Challenge

input group "=== MODE SCALPING ==="
input ENUM_SCALP_MODE ScalpMode = MODE_BALANCED;        // Mode de Trading
input bool EnableTurboMode = true;                       // Activer Mode Turbo

input group "=== RISK MANAGEMENT ==="
input double BaseRiskPercent = 0.4;                      // Risk par Trade (%) - reduit pour proteger DD
input double MaxDailyDD = 4.0;                           // Max DD Journalier (%)
input double MaxTotalDD = 8.0;                           // Max DD Total (%)
input int MaxTradesPerDay = 12;                          // Max Trades/Jour
input int MaxOpenPositions = 2;                          // Max Positions Ouvertes
input int MaxConsecutiveLosses = 5;                      // Max Pertes Consecutives (non bloquant)

input group "=== TYPES D'ENTREES ==="
input bool UseMomentum = true;                           // Entrees Momentum
input bool UseMicroBreakout = true;                      // Entrees Micro-Breakout
input bool UsePullback = true;                           // Entrees Pullback EMA
input bool UseReversal = false;                          // Entrees Reversal (risque)

input group "=== PARAMETRES ENTREE ==="
input double MomentumMinStrength = 40.0;                 // Force Momentum Min (% range)
input int RSI_Period = 14;                               // Periode RSI
input int RSI_MomentumUpper = 55;                        // RSI Momentum Haut
input int RSI_MomentumLower = 45;                        // RSI Momentum Bas
input int RSI_ReversalUpper = 75;                        // RSI Reversal Haut
input int RSI_ReversalLower = 25;                        // RSI Reversal Bas
input int EMA_Fast = 21;                                 // EMA Rapide
input int EMA_Slow = 50;                                 // EMA Lente
input int MinSignalScore = 4;                            // Score Minimum Signal (augmente pour qualite)

input group "=== STOP LOSS & TAKE PROFIT ==="
input double SL_Pips = 7.0;                              // Stop Loss (pips base EURUSD)
input double TP1_RR = 1.0;                               // TP1 Ratio (close 50%)
input double TP1_ClosePercent = 50.0;                    // % Position a TP1
input double TP2_RR = 1.5;                               // TP2 Ratio (trail reste)
input double BE_TriggerRR = 0.5;                         // Breakeven Trigger (RR)
input int MaxHoldMinutes = 20;                           // Temps Max Position (min)

input group "=== SESSIONS (UTC) ==="
input bool TradeLondonOpen = true;                       // London Open (07-09)
input bool TradeLondonPeak = true;                       // London Peak (09-12)
input bool TradeNYOpen = true;                           // NY Open (13-15)
input bool TradeNYPeak = true;                           // NY Peak (14-17)
input bool TradeLondonClose = true;                      // London Close (15-17)

input group "=== MULTI-PAIRES ==="
input bool TradeEURUSD = true;                           // EURUSD
input bool TradeGBPUSD = true;                           // GBPUSD
input bool TradeUSDJPY = true;                           // USDJPY
input bool TradeXAUUSD = true;                           // XAUUSD (active)

input group "=== FILTRES ==="
input double MaxSpreadPips = 1.5;                        // Spread Max (pips)
input bool UseHTFFilter = true;                          // Filtre Tendance H1
input bool UseSpreadFilter = true;                       // Filtre Spread

input group "=== AFFICHAGE ==="
input ENUM_DISPLAY_MODE DisplayMode = DISPLAY_COMPACT;  // Mode Dashboard
input int MagicNumber = 888888;                          // Magic Number

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SymbolConfig {
   string symbol;
   double spreadAvg;
   double slMultiplier;
   double tpMultiplier;
   int maxTradesDay;
   int digits;
   double point;
   double pipValue;
};

struct ScalpSignal {
   bool isValid;
   string symbol;
   ENUM_ENTRY_TYPE entryType;
   int direction;           // 1 = Long, -1 = Short
   double entryPrice;
   double slPrice;
   double tpPrice;
   double slPips;
   double tpPips;
   int score;
   string reason;
   datetime timestamp;
};

struct ChallengeProgress {
   double startBalance;
   double currentBalance;
   double targetBalance;
   double profitPercent;
   double dailyProfit;
   double dailyDD;
   double totalDD;
   int daysElapsed;
   double dailyTarget;
   bool isBehind;
   double behindPercent;
};

struct TradingStats {
   int todayTrades;
   int totalTrades;
   int consecutiveWins;
   int consecutiveLosses;
   double lastTradePips;
   double todayPnL;
   int openPositions;
   double openPnL;
   datetime lastTradeTime;
   datetime dayStart;
   bool pauseTrading;
   datetime pauseUntil;
};

struct RiskManager {
   double currentRisk;
   double riskMultiplier;
   bool canTrade;
   string blockReason;
   bool turboActive;
   int adjustedMaxTrades;
   int adjustedMinScore;
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo posInfo;

// Configurations paires
SymbolConfig g_symbols[];
int g_symbolCount = 0;

// Etats
ChallengeProgress g_challenge;
TradingStats g_stats;
RiskManager g_risk;
DashboardData g_dashboard;

// Indicateurs handles
int g_rsiHandle[];
int g_emaFastHandle[];
int g_emaSlowHandle[];
int g_atrHandle[];

// Divers
datetime g_lastBarTime = 0;
bool g_initialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Configuration Trade
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Initialiser les paires
   InitSymbols();

   // Initialiser les indicateurs
   if(!InitIndicators()) {
      Print("Erreur initialisation indicateurs");
      return INIT_FAILED;
   }

   // Initialiser les structures
   InitChallenge();
   InitStats();
   InitRisk();

   // Initialiser le dashboard
   InitDashboardData(g_dashboard, "SCALPER", "V8", GetPropFirmName());

   g_initialized = true;
   Print("=== PropFirm Scalper V8 Initialise ===");
   Print("Paires actives: ", g_symbolCount);
   Print("Mode: ", EnumToString(ScalpMode));
   Print("Risk: ", BaseRiskPercent, "%");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Liberer les handles indicateurs
   for(int i = 0; i < g_symbolCount; i++) {
      if(g_rsiHandle[i] != INVALID_HANDLE) IndicatorRelease(g_rsiHandle[i]);
      if(g_emaFastHandle[i] != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle[i]);
      if(g_emaSlowHandle[i] != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle[i]);
      if(g_atrHandle[i] != INVALID_HANDLE) IndicatorRelease(g_atrHandle[i]);
   }

   Comment("");
   Print("=== PropFirm Scalper V8 Arrete ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if(!g_initialized) return;

   // Verifier nouveau jour
   CheckNewDay();

   // Mettre a jour le challenge progress
   UpdateChallengeProgress();

   // Mettre a jour le risk manager
   UpdateRiskManager();

   // Gerer les positions ouvertes (TOUJOURS)
   ManageOpenPositions();

   // Verifier si on peut trader
   if(!g_risk.canTrade) {
      UpdateDashboardData();
      DisplayDashboard(g_dashboard, DisplayMode);
      return;
   }

   // Verifier pause trading
   if(g_stats.pauseTrading && TimeCurrent() < g_stats.pauseUntil) {
      UpdateDashboardData();
      DisplayDashboard(g_dashboard, DisplayMode);
      return;
   }
   g_stats.pauseTrading = false;

   // Nouvelle bougie M5?
   if(!IsNewBar(PERIOD_M5)) {
      UpdateDashboardData();
      DisplayDashboard(g_dashboard, DisplayMode);
      return;
   }

   // Scanner les signaux sur toutes les paires
   for(int i = 0; i < g_symbolCount; i++) {
      // Verifier si on peut encore trader cette paire
      if(!CanTradeSymbol(g_symbols[i].symbol)) continue;

      // Verifier la session
      if(!IsInTradingSession()) continue;

      // Scanner le signal
      ScalpSignal signal;
      if(ScanSignal(i, signal)) {
         // Executer le trade
         if(ExecuteTrade(signal)) {
            g_stats.lastTradeTime = TimeCurrent();
            g_stats.todayTrades++;
         }
      }
   }

   // Mettre a jour le dashboard
   UpdateDashboardData();
   DisplayDashboard(g_dashboard, DisplayMode);
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade() {
   // Mettre a jour les stats apres un trade
   UpdateTradeStats();
}

//+------------------------------------------------------------------+
//| INITIALISATION DES PAIRES                                       |
//+------------------------------------------------------------------+
void InitSymbols() {
   g_symbolCount = 0;

   // Compter les paires actives
   int count = 0;
   if(TradeEURUSD) count++;
   if(TradeGBPUSD) count++;
   if(TradeUSDJPY) count++;
   if(TradeXAUUSD) count++;

   ArrayResize(g_symbols, count);
   ArrayResize(g_rsiHandle, count);
   ArrayResize(g_emaFastHandle, count);
   ArrayResize(g_emaSlowHandle, count);
   ArrayResize(g_atrHandle, count);

   // EURUSD - Reference
   if(TradeEURUSD && SymbolSelect("EURUSD", true)) {
      g_symbols[g_symbolCount].symbol = "EURUSD";
      g_symbols[g_symbolCount].spreadAvg = 0.8;
      g_symbols[g_symbolCount].slMultiplier = 1.0;
      g_symbols[g_symbolCount].tpMultiplier = 1.0;
      g_symbols[g_symbolCount].maxTradesDay = 5;
      g_symbols[g_symbolCount].digits = (int)SymbolInfoInteger("EURUSD", SYMBOL_DIGITS);
      g_symbols[g_symbolCount].point = SymbolInfoDouble("EURUSD", SYMBOL_POINT);
      g_symbols[g_symbolCount].pipValue = g_symbols[g_symbolCount].point * 10;
      g_symbolCount++;
   }

   // GBPUSD - Plus volatile
   if(TradeGBPUSD && SymbolSelect("GBPUSD", true)) {
      g_symbols[g_symbolCount].symbol = "GBPUSD";
      g_symbols[g_symbolCount].spreadAvg = 1.2;
      g_symbols[g_symbolCount].slMultiplier = 1.2;
      g_symbols[g_symbolCount].tpMultiplier = 1.2;
      g_symbols[g_symbolCount].maxTradesDay = 4;
      g_symbols[g_symbolCount].digits = (int)SymbolInfoInteger("GBPUSD", SYMBOL_DIGITS);
      g_symbols[g_symbolCount].point = SymbolInfoDouble("GBPUSD", SYMBOL_POINT);
      g_symbols[g_symbolCount].pipValue = g_symbols[g_symbolCount].point * 10;
      g_symbolCount++;
   }

   // USDJPY
   if(TradeUSDJPY && SymbolSelect("USDJPY", true)) {
      g_symbols[g_symbolCount].symbol = "USDJPY";
      g_symbols[g_symbolCount].spreadAvg = 1.0;
      g_symbols[g_symbolCount].slMultiplier = 1.1;
      g_symbols[g_symbolCount].tpMultiplier = 1.1;
      g_symbols[g_symbolCount].maxTradesDay = 4;
      g_symbols[g_symbolCount].digits = (int)SymbolInfoInteger("USDJPY", SYMBOL_DIGITS);
      g_symbols[g_symbolCount].point = SymbolInfoDouble("USDJPY", SYMBOL_POINT);
      g_symbols[g_symbolCount].pipValue = g_symbols[g_symbolCount].point * 100; // JPY = 2 decimals
      g_symbolCount++;
   }

   // XAUUSD - Tres volatile
   if(TradeXAUUSD && SymbolSelect("XAUUSD", true)) {
      g_symbols[g_symbolCount].symbol = "XAUUSD";
      g_symbols[g_symbolCount].spreadAvg = 2.5;
      g_symbols[g_symbolCount].slMultiplier = 2.0;
      g_symbols[g_symbolCount].tpMultiplier = 2.0;
      g_symbols[g_symbolCount].maxTradesDay = 3;
      g_symbols[g_symbolCount].digits = (int)SymbolInfoInteger("XAUUSD", SYMBOL_DIGITS);
      g_symbols[g_symbolCount].point = SymbolInfoDouble("XAUUSD", SYMBOL_POINT);
      g_symbols[g_symbolCount].pipValue = g_symbols[g_symbolCount].point * 10;
      g_symbolCount++;
   }
}

//+------------------------------------------------------------------+
//| INITIALISATION DES INDICATEURS                                  |
//+------------------------------------------------------------------+
bool InitIndicators() {
   for(int i = 0; i < g_symbolCount; i++) {
      string sym = g_symbols[i].symbol;

      g_rsiHandle[i] = iRSI(sym, PERIOD_M5, RSI_Period, PRICE_CLOSE);
      g_emaFastHandle[i] = iMA(sym, PERIOD_M5, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowHandle[i] = iMA(sym, PERIOD_M5, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      g_atrHandle[i] = iATR(sym, PERIOD_M5, 14);

      if(g_rsiHandle[i] == INVALID_HANDLE || g_emaFastHandle[i] == INVALID_HANDLE ||
         g_emaSlowHandle[i] == INVALID_HANDLE || g_atrHandle[i] == INVALID_HANDLE) {
         Print("Erreur creation indicateur pour ", sym);
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| INITIALISATION CHALLENGE                                         |
//+------------------------------------------------------------------+
void InitChallenge() {
   g_challenge.startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_challenge.currentBalance = g_challenge.startBalance;
   g_challenge.targetBalance = g_challenge.startBalance * (1 + ChallengeTarget / 100);
   g_challenge.profitPercent = 0;
   g_challenge.dailyProfit = 0;
   g_challenge.dailyDD = 0;
   g_challenge.totalDD = 0;
   g_challenge.daysElapsed = 0;
   g_challenge.dailyTarget = ChallengeTarget / ChallengeDays;
   g_challenge.isBehind = false;
   g_challenge.behindPercent = 0;
}

//+------------------------------------------------------------------+
//| INITIALISATION STATS                                             |
//+------------------------------------------------------------------+
void InitStats() {
   g_stats.todayTrades = 0;
   g_stats.totalTrades = 0;
   g_stats.consecutiveWins = 0;
   g_stats.consecutiveLosses = 0;
   g_stats.lastTradePips = 0;
   g_stats.todayPnL = 0;
   g_stats.openPositions = 0;
   g_stats.openPnL = 0;
   g_stats.lastTradeTime = 0;
   g_stats.dayStart = TimeCurrent();
   g_stats.pauseTrading = false;
   g_stats.pauseUntil = 0;
}

//+------------------------------------------------------------------+
//| INITIALISATION RISK                                              |
//+------------------------------------------------------------------+
void InitRisk() {
   g_risk.currentRisk = BaseRiskPercent;
   g_risk.riskMultiplier = 1.0;
   g_risk.canTrade = true;
   g_risk.blockReason = "";
   g_risk.turboActive = false;
   g_risk.adjustedMaxTrades = MaxTradesPerDay;
   g_risk.adjustedMinScore = MinSignalScore;
}

//+------------------------------------------------------------------+
//| VERIFIER NOUVEAU JOUR                                            |
//+------------------------------------------------------------------+
void CheckNewDay() {
   MqlDateTime now, dayStart;
   TimeToStruct(TimeCurrent(), now);
   TimeToStruct(g_stats.dayStart, dayStart);

   if(now.day != dayStart.day) {
      // Nouveau jour - reset stats journalieres
      g_stats.todayTrades = 0;
      g_stats.todayPnL = 0;
      g_stats.dayStart = TimeCurrent();
      g_challenge.dailyProfit = 0;
      g_challenge.dailyDD = 0;
      g_challenge.daysElapsed++;

      Print("=== Nouveau jour de trading ===");
      Print("Jour ", g_challenge.daysElapsed, "/", ChallengeDays);
   }
}

//+------------------------------------------------------------------+
//| MISE A JOUR PROGRESS CHALLENGE                                   |
//+------------------------------------------------------------------+
void UpdateChallengeProgress() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   g_challenge.currentBalance = balance;
   g_challenge.profitPercent = ((balance - g_challenge.startBalance) / g_challenge.startBalance) * 100;

   // Daily DD (depuis debut de journee)
   double dailyHigh = balance; // Simplification
   g_challenge.dailyDD = 0; // A calculer correctement avec historique

   // Total DD depuis high watermark
   g_challenge.totalDD = MathMax(0, ((g_challenge.startBalance - equity) / g_challenge.startBalance) * 100);

   // Verifier si en retard
   double expectedProgress = ((double)g_challenge.daysElapsed / ChallengeDays) * ChallengeTarget;
   g_challenge.behindPercent = expectedProgress - g_challenge.profitPercent;
   g_challenge.isBehind = g_challenge.behindPercent > (ChallengeTarget * 0.1); // 10% de retard = behind
}

//+------------------------------------------------------------------+
//| MISE A JOUR RISK MANAGER                                         |
//| Logique basee sur le DD utilise, pas les pertes consecutives    |
//+------------------------------------------------------------------+
void UpdateRiskManager() {
   g_risk.canTrade = true;
   g_risk.blockReason = "";

   // Calculer le % de DD utilise (daily et total)
   double dailyDDUsedPercent = (MaxDailyDD > 0) ? (g_challenge.dailyDD / MaxDailyDD) * 100 : 0;
   double totalDDUsedPercent = (MaxTotalDD > 0) ? (g_challenge.totalDD / MaxTotalDD) * 100 : 0;
   double ddUsedPercent = MathMax(dailyDDUsedPercent, totalDDUsedPercent);

   // SEUL blocage: si DD >= 90% du max autorise
   if(ddUsedPercent >= 90) {
      g_risk.canTrade = false;
      g_risk.blockReason = StringFormat("DD %.0f%% - Protection", ddUsedPercent);
      return;
   }

   // Check trades count
   if(g_stats.todayTrades >= g_risk.adjustedMaxTrades) {
      g_risk.canTrade = false;
      g_risk.blockReason = "Max trades reached";
      return;
   }

   // Check open positions
   g_stats.openPositions = CountOpenPositions();
   if(g_stats.openPositions >= MaxOpenPositions) {
      g_risk.canTrade = false;
      g_risk.blockReason = "Max positions open";
      return;
   }

   // PAS DE BLOCAGE par consecutive losses - on ajuste le risk a la place

   // Calculer le risk multiplier de base
   g_risk.riskMultiplier = 1.0;

   // === AJUSTEMENT BASÉ SUR LE DD UTILISÉ ===
   // Plus on utilise de DD, plus on reduit le risk (mais on continue a trader)
   if(ddUsedPercent >= 70) {
      // DD 70-90%: risk reduit a 40%
      g_risk.riskMultiplier = 0.40;
   } else if(ddUsedPercent >= 50) {
      // DD 50-70%: risk reduit a 60%
      g_risk.riskMultiplier = 0.60;
   } else if(ddUsedPercent >= 30) {
      // DD 30-50%: risk reduit a 80%
      g_risk.riskMultiplier = 0.80;
   }
   // DD < 30%: risk normal (1.0)

   // === BONUS WINS CONSECUTIFS (seulement si DD < 50%) ===
   if(ddUsedPercent < 50) {
      if(g_stats.consecutiveWins >= 5) {
         g_risk.riskMultiplier *= 1.50;  // +50%
      } else if(g_stats.consecutiveWins >= 3) {
         g_risk.riskMultiplier *= 1.25;  // +25%
      }
   }

   // === MALUS LOSSES CONSECUTIFS (reduction, pas blocage) ===
   if(g_stats.consecutiveLosses >= 4) {
      g_risk.riskMultiplier *= 0.50;  // -50% apres 4 pertes
   } else if(g_stats.consecutiveLosses >= 2) {
      g_risk.riskMultiplier *= 0.70;  // -30% apres 2 pertes
   }

   // Mode Turbo si active et en retard (seulement si DD < 60%)
   g_risk.turboActive = false;
   if(EnableTurboMode && g_challenge.isBehind && g_challenge.behindPercent > 10 && ddUsedPercent < 60) {
      g_risk.turboActive = true;
      g_risk.riskMultiplier *= 1.3;
      g_risk.adjustedMaxTrades = MaxTradesPerDay + 5;
      g_risk.adjustedMinScore = MathMax(2, MinSignalScore - 1);
   } else {
      g_risk.adjustedMaxTrades = MaxTradesPerDay;
      g_risk.adjustedMinScore = MinSignalScore;
   }

   // Ajustement mode scalping
   switch(ScalpMode) {
      case MODE_CONSERVATIVE:
         g_risk.riskMultiplier *= 0.8;
         g_risk.adjustedMaxTrades = (int)(MaxTradesPerDay * 0.7);
         break;
      case MODE_AGGRESSIVE:
         g_risk.riskMultiplier *= 1.2;
         g_risk.adjustedMaxTrades = (int)(MaxTradesPerDay * 1.3);
         break;
   }

   // Limiter le multiplier entre 0.3 et 2.0
   g_risk.riskMultiplier = MathMax(0.3, MathMin(2.0, g_risk.riskMultiplier));

   g_risk.currentRisk = BaseRiskPercent * g_risk.riskMultiplier;
}

//+------------------------------------------------------------------+
//| VERIFIER SI NOUVELLE BARRE                                       |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf) {
   datetime barTime = iTime(_Symbol, tf, 0);
   if(barTime != g_lastBarTime) {
      g_lastBarTime = barTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| VERIFIER SESSION TRADING                                         |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   // London Open 07-09
   if(TradeLondonOpen && h >= 7 && h < 9) return true;

   // London Peak 09-12
   if(TradeLondonPeak && h >= 9 && h < 12) return true;

   // NY Open 13-15
   if(TradeNYOpen && h >= 13 && h < 15) return true;

   // NY Peak 14-17
   if(TradeNYPeak && h >= 14 && h < 17) return true;

   // London Close 15-17
   if(TradeLondonClose && h >= 15 && h < 17) return true;

   return false;
}

//+------------------------------------------------------------------+
//| OBTENIR NOM SESSION COURANTE                                     |
//+------------------------------------------------------------------+
string GetCurrentSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(h >= 7 && h < 9) return "LONDON OPEN";
   if(h >= 9 && h < 12) return "LONDON PEAK";
   if(h >= 13 && h < 15) return "NY OPEN";
   if(h >= 14 && h < 17) return "NY PEAK";
   if(h >= 15 && h < 17) return "LONDON CLOSE";
   if(h >= 0 && h < 7) return "ASIAN";

   return "OFF HOURS";
}

//+------------------------------------------------------------------+
//| PEUT-ON TRADER CE SYMBOLE?                                       |
//+------------------------------------------------------------------+
bool CanTradeSymbol(string symbol) {
   // Verifier le spread
   if(UseSpreadFilter) {
      double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) / 10.0;
      if(spread > MaxSpreadPips) return false;
   }

   // Compter les trades aujourd'hui sur ce symbole
   int symbolTrades = CountTodayTradesForSymbol(symbol);

   // Trouver la config du symbole
   for(int i = 0; i < g_symbolCount; i++) {
      if(g_symbols[i].symbol == symbol) {
         if(symbolTrades >= g_symbols[i].maxTradesDay) return false;
         break;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| SCANNER SIGNAL POUR UN SYMBOLE                                   |
//+------------------------------------------------------------------+
bool ScanSignal(int symbolIndex, ScalpSignal &signal) {
   string sym = g_symbols[symbolIndex].symbol;

   signal.isValid = false;
   signal.symbol = sym;
   signal.score = 0;
   signal.reason = "";

   // Obtenir les donnees
   double rsi[], emaFast[], emaSlow[], atr[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(g_rsiHandle[symbolIndex], 0, 0, 5, rsi) < 5) return false;
   if(CopyBuffer(g_emaFastHandle[symbolIndex], 0, 0, 5, emaFast) < 5) return false;
   if(CopyBuffer(g_emaSlowHandle[symbolIndex], 0, 0, 5, emaSlow) < 5) return false;
   if(CopyBuffer(g_atrHandle[symbolIndex], 0, 0, 5, atr) < 5) return false;

   double close[], open[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyClose(sym, PERIOD_M5, 0, 10, close) < 10) return false;
   if(CopyOpen(sym, PERIOD_M5, 0, 10, open) < 10) return false;
   if(CopyHigh(sym, PERIOD_M5, 0, 10, high) < 10) return false;
   if(CopyLow(sym, PERIOD_M5, 0, 10, low) < 10) return false;

   int direction = 0;
   ENUM_ENTRY_TYPE entryType = ENTRY_MOMENTUM;
   string reason = "";
   int score = 0;

   // === SIGNAL MOMENTUM ===
   if(UseMomentum) {
      double candleBody = MathAbs(close[1] - open[1]);
      double candleRange = high[1] - low[1];
      double rangeHour = high[ArrayMaximum(high, 0, 12)] - low[ArrayMinimum(low, 0, 12)];

      bool isBullish = close[1] > open[1];
      bool isBearish = close[1] < open[1];
      double strength = (rangeHour > 0) ? (candleBody / rangeHour) * 100 : 0;

      if(strength >= MomentumMinStrength) {
         if(isBullish && rsi[1] > RSI_MomentumLower && rsi[1] < RSI_MomentumUpper) {
            direction = 1;
            entryType = ENTRY_MOMENTUM;
            reason = "MOMENTUM LONG";
            score = 3;
         }
         else if(isBearish && rsi[1] > RSI_MomentumLower && rsi[1] < RSI_MomentumUpper) {
            direction = -1;
            entryType = ENTRY_MOMENTUM;
            reason = "MOMENTUM SHORT";
            score = 3;
         }
      }
   }

   // === SIGNAL MICRO BREAKOUT ===
   if(UseMicroBreakout && direction == 0) {
      double hourHigh = high[ArrayMaximum(high, 0, 12)];
      double hourLow = low[ArrayMinimum(low, 0, 12)];
      double breakBuffer = atr[1] * 0.2;

      if(close[1] > hourHigh + breakBuffer && close[2] <= hourHigh) {
         direction = 1;
         entryType = ENTRY_BREAKOUT;
         reason = "BREAKOUT LONG";
         score = 3;
      }
      else if(close[1] < hourLow - breakBuffer && close[2] >= hourLow) {
         direction = -1;
         entryType = ENTRY_BREAKOUT;
         reason = "BREAKOUT SHORT";
         score = 3;
      }
   }

   // === SIGNAL PULLBACK ===
   if(UsePullback && direction == 0) {
      bool uptrend = emaFast[1] > emaSlow[1];
      bool downtrend = emaFast[1] < emaSlow[1];

      // Pullback vers EMA21 dans tendance
      if(uptrend && low[1] <= emaFast[1] && close[1] > emaFast[1]) {
         direction = 1;
         entryType = ENTRY_PULLBACK;
         reason = "PULLBACK LONG";
         score = 4;
      }
      else if(downtrend && high[1] >= emaFast[1] && close[1] < emaFast[1]) {
         direction = -1;
         entryType = ENTRY_PULLBACK;
         reason = "PULLBACK SHORT";
         score = 4;
      }
   }

   // === SIGNAL REVERSAL ===
   if(UseReversal && direction == 0) {
      // Pin bar + RSI extreme
      double body = MathAbs(close[1] - open[1]);
      double upperWick = high[1] - MathMax(close[1], open[1]);
      double lowerWick = MathMin(close[1], open[1]) - low[1];

      if(rsi[1] < RSI_ReversalLower && lowerWick > body * 2 && close[1] > open[1]) {
         direction = 1;
         entryType = ENTRY_REVERSAL;
         reason = "REVERSAL LONG";
         score = 2;
      }
      else if(rsi[1] > RSI_ReversalUpper && upperWick > body * 2 && close[1] < open[1]) {
         direction = -1;
         entryType = ENTRY_REVERSAL;
         reason = "REVERSAL SHORT";
         score = 2;
      }
   }

   // Pas de signal
   if(direction == 0) return false;

   // Bonus de score
   // +1 si EMA alignees
   if((direction == 1 && emaFast[1] > emaSlow[1]) ||
      (direction == -1 && emaFast[1] < emaSlow[1])) {
      score++;
   }

   // +1 si RSI confirme
   if((direction == 1 && rsi[1] > 50) ||
      (direction == -1 && rsi[1] < 50)) {
      score++;
   }

   // Verifier score minimum
   if(score < g_risk.adjustedMinScore) return false;

   // Filtre HTF
   if(UseHTFFilter) {
      int htfHandle = iMA(sym, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      double htfEma[];
      ArraySetAsSeries(htfEma, true);
      if(CopyBuffer(htfHandle, 0, 0, 2, htfEma) >= 2) {
         if(direction == 1 && close[1] < htfEma[1]) {
            IndicatorRelease(htfHandle);
            return false;
         }
         if(direction == -1 && close[1] > htfEma[1]) {
            IndicatorRelease(htfHandle);
            return false;
         }
      }
      IndicatorRelease(htfHandle);
   }

   // Construire le signal
   double slPips = SL_Pips * g_symbols[symbolIndex].slMultiplier;
   double tpPips = slPips * TP1_RR * g_symbols[symbolIndex].tpMultiplier;

   signal.isValid = true;
   signal.direction = direction;
   signal.entryType = entryType;
   signal.reason = reason;
   signal.score = score;
   signal.slPips = slPips;
   signal.tpPips = tpPips;
   signal.timestamp = TimeCurrent();

   // Prix d'entree
   if(direction == 1) {
      signal.entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
      signal.slPrice = signal.entryPrice - slPips * g_symbols[symbolIndex].pipValue;
      signal.tpPrice = signal.entryPrice + tpPips * g_symbols[symbolIndex].pipValue;
   } else {
      signal.entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
      signal.slPrice = signal.entryPrice + slPips * g_symbols[symbolIndex].pipValue;
      signal.tpPrice = signal.entryPrice - tpPips * g_symbols[symbolIndex].pipValue;
   }

   return true;
}

//+------------------------------------------------------------------+
//| EXECUTER UN TRADE                                                |
//+------------------------------------------------------------------+
bool ExecuteTrade(ScalpSignal &signal) {
   if(!signal.isValid) return false;

   // Calculer la taille de lot
   double lots = CalculateLots(signal.symbol, signal.slPips);
   if(lots <= 0) return false;

   // Comment du trade
   string comment = StringFormat("SCALP_%s_%d", EnumToString(signal.entryType), signal.score);

   bool result = false;
   if(signal.direction == 1) {
      result = trade.Buy(lots, signal.symbol, signal.entryPrice, signal.slPrice, signal.tpPrice, comment);
   } else {
      result = trade.Sell(lots, signal.symbol, signal.entryPrice, signal.slPrice, signal.tpPrice, comment);
   }

   if(result) {
      Print("Trade ouvert: ", signal.reason, " | Lots: ", lots, " | Score: ", signal.score);
      return true;
   } else {
      Print("Erreur trade: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| CALCULER LA TAILLE DE LOT                                        |
//+------------------------------------------------------------------+
double CalculateLots(string symbol, double slPips) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (g_risk.currentRisk / 100);

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double pipValue = tickValue * (point * 10 / tickSize);
   double lots = riskAmount / (slPips * pipValue);

   // Normaliser
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / stepLot) * stepLot;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| GESTION DES POSITIONS OUVERTES                                   |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
   g_stats.openPositions = 0;
   g_stats.openPnL = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != MagicNumber) continue;

      g_stats.openPositions++;
      g_stats.openPnL += posInfo.Profit();

      string sym = posInfo.Symbol();
      ulong ticket = posInfo.Ticket();
      double entry = posInfo.PriceOpen();
      double sl = posInfo.StopLoss();
      double tp = posInfo.TakeProfit();
      double lots = posInfo.Volume();
      bool isLong = (posInfo.PositionType() == POSITION_TYPE_BUY);
      datetime openTime = posInfo.Time();

      double price = isLong ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);
      double priceDiff = isLong ? (price - entry) : (entry - price);
      double risk = MathAbs(entry - sl);
      double currentRR = (risk > 0) ? priceDiff / risk : 0;

      // === BREAKEVEN ===
      if(currentRR >= BE_TriggerRR && sl != entry) {
         double beLevel = isLong ? entry + risk * 0.1 : entry - risk * 0.1;
         bool needBE = isLong ? (sl < beLevel) : (sl > beLevel);
         if(needBE) {
            trade.PositionModify(ticket, beLevel, tp);
         }
      }

      // === PARTIAL CLOSE at TP1 ===
      if(currentRR >= TP1_RR) {
         double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
         double closeSize = lots * (TP1_ClosePercent / 100);
         closeSize = MathFloor(closeSize / minLot) * minLot;

         if(closeSize >= minLot && lots > minLot) {
            trade.PositionClosePartial(ticket, closeSize);
         }
      }

      // === TIME EXIT ===
      if(MaxHoldMinutes > 0) {
         int minutesOpen = (int)((TimeCurrent() - openTime) / 60);
         if(minutesOpen >= MaxHoldMinutes) {
            // Si proche de BE, fermer
            if(MathAbs(priceDiff) < risk * 0.3) {
               trade.PositionClose(ticket);
               Print("Time exit: position fermee apres ", minutesOpen, " minutes");
            }
         }
      }

      // === TRAILING STOP apres TP1 ===
      if(currentRR >= TP1_RR) {
         // Trouver la config du symbole
         double atrValue = 0;
         for(int j = 0; j < g_symbolCount; j++) {
            if(g_symbols[j].symbol == sym) {
               double atrBuf[];
               ArraySetAsSeries(atrBuf, true);
               if(CopyBuffer(g_atrHandle[j], 0, 0, 1, atrBuf) > 0) {
                  atrValue = atrBuf[0];
               }
               break;
            }
         }

         if(atrValue > 0) {
            double trailDist = atrValue * 0.4;
            double newSL = isLong ? price - trailDist : price + trailDist;
            bool shouldTrail = isLong ? (newSL > sl) : (newSL < sl);
            if(shouldTrail) {
               trade.PositionModify(ticket, newSL, tp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| COMPTER POSITIONS OUVERTES                                       |
//+------------------------------------------------------------------+
int CountOpenPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber) {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| COMPTER TRADES AUJOURD'HUI POUR UN SYMBOLE                      |
//+------------------------------------------------------------------+
int CountTodayTradesForSymbol(string symbol) {
   int count = 0;
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   HistorySelect(dayStart, TimeCurrent());
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == symbol &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| MISE A JOUR DES STATS APRES TRADE                               |
//+------------------------------------------------------------------+
void UpdateTradeStats() {
   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   HistorySelect(dayStart, TimeCurrent());

   // Trouver le dernier deal cloture
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {

         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         double netProfit = profit + commission + swap;

         // Mettre a jour les streaks
         if(netProfit > 0) {
            g_stats.consecutiveWins++;
            g_stats.consecutiveLosses = 0;
            g_stats.lastTradePips = 10; // Approximation
         } else {
            g_stats.consecutiveLosses++;
            g_stats.consecutiveWins = 0;
            g_stats.lastTradePips = -7; // Approximation
         }

         g_stats.totalTrades++;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| OBTENIR NOM PROP FIRM                                            |
//+------------------------------------------------------------------+
string GetPropFirmName() {
   switch(PropFirm) {
      case PROP_FTMO: return "FTMO";
      case PROP_E8: return "E8";
      case PROP_FUNDINGPIPS: return "FUNDPIPS";
      case PROP_THE5ERS: return "THE5ERS";
   }
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| MISE A JOUR DONNEES DASHBOARD                                    |
//+------------------------------------------------------------------+
void UpdateDashboardData() {
   g_dashboard.propFirm = GetPropFirmName();
   g_dashboard.symbol = _Symbol;

   g_dashboard.targetPercent = ChallengeTarget;
   g_dashboard.currentPercent = g_challenge.profitPercent;
   g_dashboard.totalDays = ChallengeDays;
   g_dashboard.daysElapsed = g_challenge.daysElapsed;

   g_dashboard.riskPercent = BaseRiskPercent;
   g_dashboard.dailyDD = g_challenge.dailyDD;
   g_dashboard.maxDailyDD = MaxDailyDD;
   g_dashboard.totalDD = g_challenge.totalDD;
   g_dashboard.maxTotalDD = MaxTotalDD;

   g_dashboard.currentSession = GetCurrentSession();
   g_dashboard.sessionActive = IsInTradingSession();
   g_dashboard.todayTrades = g_stats.todayTrades;
   g_dashboard.maxTrades = g_risk.adjustedMaxTrades;
   g_dashboard.lastTradePips = g_stats.lastTradePips;
   g_dashboard.consecutiveWins = g_stats.consecutiveWins;
   g_dashboard.consecutiveLosses = g_stats.consecutiveLosses;
   g_dashboard.openPositions = g_stats.openPositions;
   g_dashboard.openPnL = g_stats.openPnL;

   g_dashboard.hasSignal = false; // Sera mis a jour si signal actif
   g_dashboard.turboMode = g_risk.turboActive;
   g_dashboard.riskMultiplier = g_risk.riskMultiplier;
   g_dashboard.canTrade = g_risk.canTrade;
   g_dashboard.blockReason = g_risk.blockReason;
}
