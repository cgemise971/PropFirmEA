//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v6.mq5 |
//|        CHALLENGE OPTIMIZER - Smart Capital & Trade Management    |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "6.00"
#property description "V6: Challenge-focused capital management + No hedging + Compounding"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_PROP_FIRM {
   PROP_FTMO,
   PROP_E8,
   PROP_FUNDING_PIPS,
   PROP_THE5ERS,
   PROP_CUSTOM
};

enum ENUM_CHALLENGE_PHASE {
   PHASE_EARLY,      // 0-30% of target - Build foundation
   PHASE_MIDDLE,     // 30-70% of target - Accelerate
   PHASE_FINAL,      // 70-90% of target - Careful growth
   PHASE_PROTECTION  // 90%+ - Protect and close
};

enum ENUM_MARKET_STRUCTURE {
   STRUCTURE_BULLISH,
   STRUCTURE_BEARISH,
   STRUCTURE_RANGING,
   STRUCTURE_UNKNOWN
};

enum ENUM_SETUP_TYPE {
   SETUP_BREAKOUT,
   SETUP_RETEST,
   SETUP_CONTINUATION
};

enum ENUM_CANDLE_PATTERN {
   PATTERN_NONE,
   PATTERN_ENGULFING,
   PATTERN_PIN_BAR,
   PATTERN_INSIDE_BAR_BO,
   PATTERN_REJECTION
};

enum ENUM_TRADE_DIRECTION {
   DIR_NONE,
   DIR_LONG_ONLY,
   DIR_SHORT_ONLY
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "========== PROP FIRM CHALLENGE =========="
input ENUM_PROP_FIRM PropFirm = PROP_FTMO;
input double ChallengeTarget = 10.0;          // Challenge profit target %
input double InitialBalance = 100000;         // Starting balance
input int ChallengeDays = 30;                 // Days to complete challenge

input group "========== CAPITAL MANAGEMENT =========="
input double BaseRisk = 1.0;                  // Base risk % per trade
input double MaxRiskEarly = 1.5;              // Max risk in early phase
input double MaxRiskMiddle = 1.2;             // Max risk in middle phase
input double MaxRiskFinal = 0.8;              // Max risk in final phase
input double MaxRiskProtection = 0.5;         // Max risk in protection phase
input bool UseCompounding = true;             // Compound profits
input double CompoundFactor = 0.5;            // How much of profits to compound (0-1)
input double MaxDailyDD = 4.0;                // Max daily drawdown %
input double MaxTotalDD = 8.0;                // Max total drawdown %
input double DDBuffer = 1.0;                  // Buffer before max DD %

input group "========== TRADE MANAGEMENT =========="
input bool SingleDirectionMode = true;        // Only one direction at a time
input int MaxOpenTrades = 2;                  // Max simultaneous trades
input int MaxTradesPerDay = 3;                // Max trades per day
input bool CloseLoserBeforeNew = true;        // Close losing trade before new one
input double MaxLossToClose = -1.0;           // Close if trade loss exceeds % of balance

input group "========== PROFIT PROTECTION =========="
input bool UseBreakeven = true;               // Move SL to breakeven
input double BreakevenTrigger = 1.0;          // RR to trigger breakeven
input double BreakevenOffset = 0.1;           // Offset above/below entry (ATR)
input bool UseTrailing = true;                // Use trailing stop
input double TrailingTrigger = 1.5;           // RR to start trailing
input double TrailingDistance = 0.8;          // Trailing distance (ATR)
input bool UsePartialClose = true;            // Take partial profits
input double PartialCloseRR = 1.5;            // RR to take partial
input double PartialClosePercent = 50.0;      // % to close at partial

input group "========== STRUCTURE ANALYSIS =========="
input int SwingLookback = 10;
input int StructureBars = 50;
input double MinSwingSize = 0.5;

input group "========== ENTRY REQUIREMENTS =========="
input int MinScore = 6;                       // Min score to trade
input bool RequirePattern = true;
input bool RequireMomentum = true;
input int RSI_Period = 14;
input double MinRR = 1.5;
input double TP1_RR = 1.5;                    // Take Profit 1 R:R ratio

input group "========== SESSIONS =========="
input bool TradeLondon = true;
input bool TradeNY = true;

input group "========== TIMEFRAMES =========="
input ENUM_TIMEFRAMES TF_Structure = PERIOD_H1;
input ENUM_TIMEFRAMES TF_Entry = PERIOD_M15;
input ENUM_TIMEFRAMES TF_HTF = PERIOD_H4;

input group "========== EA =========="
input int Magic = 678901;
input string TradeComment = "SBv6";
input bool Dashboard = true;
input bool DrawLevels = true;

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct ChallengeStatus {
   double startBalance;
   double currentBalance;
   double targetBalance;
   double targetProfit;
   double currentProfit;
   double profitPercent;
   ENUM_CHALLENGE_PHASE phase;
   int daysRemaining;
   int daysElapsed;
   double dailyTargetPercent;
   double todayProfit;
   bool targetReached;
   bool ddBreached;
};

struct RiskManager {
   double currentRisk;
   double maxRiskAllowed;
   double ddBufferRemaining;
   double dailyDDRemaining;
   bool canTrade;
   string blockReason;
};

struct TradeManager {
   ENUM_TRADE_DIRECTION currentDirection;
   int openLongs;
   int openShorts;
   double openPnL;
   double todayTrades;
   double todayWins;
   double todayLosses;
   bool hasWinToday;
};

struct SwingPoint {
   datetime time;
   double price;
   bool isHigh;
   int barIndex;
};

struct MarketStructure {
   ENUM_MARKET_STRUCTURE mtfStructure;
   ENUM_MARKET_STRUCTURE htfStructure;
   int direction;
   double keyResistance;
   double keySupport;
};

struct RangeZone {
   double high;
   double low;
   double mid;
   double size;
   datetime startTime;
   datetime endTime;
   int touchesHigh;
   int touchesLow;
   bool isValid;
   bool isQuality;
   double qualityScore;
};

struct EntrySignal {
   ENUM_SETUP_TYPE setup;
   ENUM_CANDLE_PATTERN pattern;
   int direction;
   double entryPrice;
   double slPrice;
   double tp1Price;
   double tp2Price;
   int score;
   double rr;
   string reason;
   bool isValid;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo pos;
CAccountInfo acc;

ChallengeStatus g_challenge;
RiskManager g_risk;
TradeManager g_trades;
MarketStructure g_structure;
RangeZone g_asianRange;
RangeZone g_londonRange;
EntrySignal g_currentSignal;

SwingPoint g_swingHighs[];
SwingPoint g_swingLows[];

int g_atrHandle, g_rsiHandle;
int g_emaFastH1, g_emaSlowH1;
int g_emaFastH4, g_emaSlowH4;

datetime g_lastBar;
datetime g_challengeStartDate;
double g_atr;
double g_dayStartBalance;
int g_lastDay;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Initialize challenge tracking
   g_challenge.startBalance = (InitialBalance > 0) ? InitialBalance : acc.Balance();
   g_challenge.targetProfit = ChallengeTarget;
   g_challenge.targetBalance = g_challenge.startBalance * (1 + ChallengeTarget / 100);
   g_challenge.daysRemaining = ChallengeDays;
   g_challenge.daysElapsed = 0;
   g_challengeStartDate = TimeCurrent();
   g_dayStartBalance = acc.Balance();
   g_lastDay = -1;

   // Initialize trade manager
   g_trades.currentDirection = DIR_NONE;

   // Indicators
   g_atrHandle = iATR(_Symbol, TF_Structure, 14);
   g_rsiHandle = iRSI(_Symbol, TF_Entry, RSI_Period, PRICE_CLOSE);
   g_emaFastH1 = iMA(_Symbol, TF_Structure, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH1 = iMA(_Symbol, TF_Structure, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_emaFastH4 = iMA(_Symbol, TF_HTF, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH4 = iMA(_Symbol, TF_HTF, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE) {
      Print("Indicator initialization failed");
      return INIT_FAILED;
   }

   ArrayResize(g_swingHighs, 0);
   ArrayResize(g_swingLows, 0);

   Print("=== SESSION BREAKOUT V6 - CHALLENGE OPTIMIZER ===");
   Print("Target: ", DoubleToString(g_challenge.targetBalance, 2), " (", DoubleToString(ChallengeTarget, 1), "%)");
   Print("Days: ", ChallengeDays);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_emaFastH1);
   IndicatorRelease(g_emaSlowH1);
   IndicatorRelease(g_emaFastH4);
   IndicatorRelease(g_emaSlowH4);
   ObjectsDeleteAll(0, "SBv6_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   datetime barTime = iTime(_Symbol, TF_Entry, 0);
   bool newBar = (barTime != g_lastBar);

   // Update core systems
   CheckDayReset();
   UpdateATR();
   UpdateChallengeStatus();
   UpdateRiskManager();
   UpdateTradeManager();

   // Manage existing positions (always)
   ManageOpenPositions();

   // Check if trading is allowed
   if(!g_risk.canTrade) {
      if(Dashboard) ShowDashboard();
      return;
   }

   if(newBar) {
      g_lastBar = barTime;

      // Structure analysis
      AnalyzeMarketStructure();
      CalculateRanges();

      // Look for entries
      if(IsInTradingSession() && CanOpenNewTrade()) {
         g_currentSignal = ScanForSignal();

         if(g_currentSignal.isValid && g_currentSignal.score >= MinScore) {
            // Check direction constraint
            if(IsDirectionAllowed(g_currentSignal.direction)) {
               ExecuteSignal(g_currentSignal);
            }
         }
      }
   }

   if(DrawLevels) DrawOnChart();
   if(Dashboard) ShowDashboard();
}

//+------------------------------------------------------------------+
//| UPDATE CHALLENGE STATUS                                          |
//+------------------------------------------------------------------+
void UpdateChallengeStatus() {
   g_challenge.currentBalance = acc.Equity();
   g_challenge.currentProfit = g_challenge.currentBalance - g_challenge.startBalance;
   g_challenge.profitPercent = (g_challenge.currentProfit / g_challenge.startBalance) * 100;
   g_challenge.todayProfit = ((g_challenge.currentBalance - g_dayStartBalance) / g_dayStartBalance) * 100;

   // Days calculation
   int daysPassed = (int)((TimeCurrent() - g_challengeStartDate) / 86400);
   g_challenge.daysElapsed = daysPassed;
   g_challenge.daysRemaining = MathMax(0, ChallengeDays - daysPassed);

   // Daily target to stay on track
   if(g_challenge.daysRemaining > 0) {
      double remainingTarget = ChallengeTarget - g_challenge.profitPercent;
      g_challenge.dailyTargetPercent = remainingTarget / g_challenge.daysRemaining;
   } else {
      g_challenge.dailyTargetPercent = 0;
   }

   // Determine phase
   double progressPercent = (g_challenge.profitPercent / ChallengeTarget) * 100;

   if(progressPercent >= 90) {
      g_challenge.phase = PHASE_PROTECTION;
   } else if(progressPercent >= 70) {
      g_challenge.phase = PHASE_FINAL;
   } else if(progressPercent >= 30) {
      g_challenge.phase = PHASE_MIDDLE;
   } else {
      g_challenge.phase = PHASE_EARLY;
   }

   // Check if target reached
   g_challenge.targetReached = (g_challenge.profitPercent >= ChallengeTarget);

   // Check DD breach
   double totalDD = ((g_challenge.startBalance - g_challenge.currentBalance) / g_challenge.startBalance) * 100;
   double dailyDD = -g_challenge.todayProfit;
   g_challenge.ddBreached = (totalDD >= MaxTotalDD || dailyDD >= MaxDailyDD);
}

//+------------------------------------------------------------------+
//| UPDATE RISK MANAGER                                              |
//+------------------------------------------------------------------+
void UpdateRiskManager() {
   // Calculate remaining DD buffer
   double totalDD = ((g_challenge.startBalance - g_challenge.currentBalance) / g_challenge.startBalance) * 100;
   double dailyDD = -g_challenge.todayProfit;

   g_risk.ddBufferRemaining = MaxTotalDD - DDBuffer - totalDD;
   g_risk.dailyDDRemaining = MaxDailyDD - DDBuffer - dailyDD;

   // Determine max allowed risk based on phase
   switch(g_challenge.phase) {
      case PHASE_EARLY:
         g_risk.maxRiskAllowed = MaxRiskEarly;
         break;
      case PHASE_MIDDLE:
         g_risk.maxRiskAllowed = MaxRiskMiddle;
         break;
      case PHASE_FINAL:
         g_risk.maxRiskAllowed = MaxRiskFinal;
         break;
      case PHASE_PROTECTION:
         g_risk.maxRiskAllowed = MaxRiskProtection;
         break;
   }

   // Further reduce if close to DD limits
   if(g_risk.ddBufferRemaining < 2.0) {
      g_risk.maxRiskAllowed = MathMin(g_risk.maxRiskAllowed, 0.5);
   }
   if(g_risk.dailyDDRemaining < 1.5) {
      g_risk.maxRiskAllowed = MathMin(g_risk.maxRiskAllowed, 0.3);
   }

   // Calculate current risk (base + compounding bonus)
   g_risk.currentRisk = BaseRisk;
   if(UseCompounding && g_challenge.profitPercent > 0) {
      double compoundBonus = g_challenge.profitPercent * CompoundFactor * 0.1;
      g_risk.currentRisk = MathMin(BaseRisk + compoundBonus, g_risk.maxRiskAllowed);
   }
   g_risk.currentRisk = MathMin(g_risk.currentRisk, g_risk.maxRiskAllowed);

   // Determine if can trade
   g_risk.canTrade = true;
   g_risk.blockReason = "";

   if(g_challenge.targetReached) {
      g_risk.canTrade = false;
      g_risk.blockReason = "TARGET REACHED! Challenge complete.";
   }
   else if(g_challenge.ddBreached) {
      g_risk.canTrade = false;
      g_risk.blockReason = "DD LIMIT BREACHED!";
      CloseAllPositions("DD Breach");
   }
   else if(g_risk.ddBufferRemaining < 0.5) {
      g_risk.canTrade = false;
      g_risk.blockReason = "Too close to max DD";
   }
   else if(g_risk.dailyDDRemaining < 0.5) {
      g_risk.canTrade = false;
      g_risk.blockReason = "Too close to daily DD limit";
   }
}

//+------------------------------------------------------------------+
//| UPDATE TRADE MANAGER                                             |
//+------------------------------------------------------------------+
void UpdateTradeManager() {
   g_trades.openLongs = 0;
   g_trades.openShorts = 0;
   g_trades.openPnL = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol && pos.Magic() == Magic) {
            if(pos.PositionType() == POSITION_TYPE_BUY) {
               g_trades.openLongs++;
            } else {
               g_trades.openShorts++;
            }
            g_trades.openPnL += pos.Profit();
         }
      }
   }

   // Determine current direction
   if(g_trades.openLongs > 0 && g_trades.openShorts == 0) {
      g_trades.currentDirection = DIR_LONG_ONLY;
   } else if(g_trades.openShorts > 0 && g_trades.openLongs == 0) {
      g_trades.currentDirection = DIR_SHORT_ONLY;
   } else if(g_trades.openLongs == 0 && g_trades.openShorts == 0) {
      g_trades.currentDirection = DIR_NONE;
   }
   // If both exist (shouldn't happen), don't change direction
}

//+------------------------------------------------------------------+
//| IS DIRECTION ALLOWED                                             |
//+------------------------------------------------------------------+
bool IsDirectionAllowed(int signalDir) {
   if(!SingleDirectionMode) return true;

   // No open positions - any direction allowed
   if(g_trades.currentDirection == DIR_NONE) return true;

   // Check if signal matches current direction
   if(signalDir == 1 && g_trades.currentDirection == DIR_LONG_ONLY) return true;
   if(signalDir == -1 && g_trades.currentDirection == DIR_SHORT_ONLY) return true;

   // Opposite direction - not allowed
   return false;
}

//+------------------------------------------------------------------+
//| CAN OPEN NEW TRADE                                               |
//+------------------------------------------------------------------+
bool CanOpenNewTrade() {
   // Max trades per day
   if(g_trades.todayTrades >= MaxTradesPerDay) return false;

   // Max open positions
   int totalOpen = g_trades.openLongs + g_trades.openShorts;
   if(totalOpen >= MaxOpenTrades) return false;

   // In protection phase - be very selective
   if(g_challenge.phase == PHASE_PROTECTION) {
      // Only trade if we have room to lose
      if(g_challenge.profitPercent < ChallengeTarget + 1.0) {
         return false;  // Don't risk falling below target
      }
   }

   // If we have a losing trade open, handle it first
   if(CloseLoserBeforeNew && g_trades.openPnL < 0) {
      double lossPct = (g_trades.openPnL / g_challenge.currentBalance) * 100;
      if(lossPct < MaxLossToClose) {
         // Don't open new trade until loser is handled
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| MANAGE OPEN POSITIONS                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != Magic) continue;

      ulong ticket = pos.Ticket();
      double entry = pos.PriceOpen();
      double sl = pos.StopLoss();
      double tp = pos.TakeProfit();
      double lots = pos.Volume();
      bool isLong = (pos.PositionType() == POSITION_TYPE_BUY);
      double profit = pos.Profit();

      double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double priceDiff = isLong ? (price - entry) : (entry - price);
      double riskDist = MathAbs(entry - sl);
      double currentRR = (riskDist > 0) ? priceDiff / riskDist : 0;

      // 1. BREAKEVEN
      if(UseBreakeven && currentRR >= BreakevenTrigger) {
         double beLevel = isLong ? entry + g_atr * BreakevenOffset : entry - g_atr * BreakevenOffset;
         bool shouldMoveBE = isLong ? (sl < entry) : (sl > entry);

         if(shouldMoveBE) {
            trade.PositionModify(ticket, beLevel, tp);
         }
      }

      // 2. PARTIAL CLOSE
      if(UsePartialClose && currentRR >= PartialCloseRR) {
         // Check if we haven't already taken partial (by checking lot size)
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double expectedPartial = lots * (1 - PartialClosePercent / 100);

         if(lots > expectedPartial + minLot) {
            double closeSize = NormalizeVolume(lots * (PartialClosePercent / 100));
            if(closeSize >= minLot) {
               trade.PositionClosePartial(ticket, closeSize);
            }
         }
      }

      // 3. TRAILING STOP
      if(UseTrailing && currentRR >= TrailingTrigger) {
         double trailDist = g_atr * TrailingDistance;
         double newSL = isLong ? price - trailDist : price + trailDist;

         bool shouldTrail = isLong ? (newSL > sl) : (newSL < sl);
         if(shouldTrail) {
            trade.PositionModify(ticket, newSL, tp);
         }
      }

      // 4. CLOSE EXCESSIVE LOSER
      if(CloseLoserBeforeNew && profit < 0) {
         double lossPct = (profit / g_challenge.currentBalance) * 100;
         if(lossPct < MaxLossToClose) {
            trade.PositionClose(ticket);
            Print("Closed losing position: ", lossPct, "% loss");
         }
      }

      // 5. PROTECTION PHASE - Lock in profits
      if(g_challenge.phase == PHASE_PROTECTION && profit > 0) {
         // Tighten trailing significantly
         double tightTrail = g_atr * 0.5;
         double newSL = isLong ? price - tightTrail : price + tightTrail;
         bool shouldTighten = isLong ? (newSL > sl) : (newSL < sl);
         if(shouldTighten) {
            trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| NORMALIZE VOLUME                                                 |
//+------------------------------------------------------------------+
double NormalizeVolume(double lots) {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / step) * step;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| CALCULATE LOTS (with compounding)                                |
//+------------------------------------------------------------------+
double CalculateLots(double entry, double sl) {
   double balance = UseCompounding ? g_challenge.currentBalance : g_challenge.startBalance;
   double riskAmt = balance * (g_risk.currentRisk / 100);

   double slPips = MathAbs(entry - sl) / _Point / 10;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize == 0 || slPips == 0) return 0;

   double pipVal = tickVal * (_Point * 10 / tickSize);
   double lots = riskAmt / (slPips * pipVal);

   return NormalizeVolume(lots);
}

//+------------------------------------------------------------------+
//| Update ATR                                                        |
//+------------------------------------------------------------------+
void UpdateATR() {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0) {
      g_atr = atr[0];
   }
}

//+------------------------------------------------------------------+
//| Check Day Reset                                                   |
//+------------------------------------------------------------------+
void CheckDayReset() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(g_lastDay != dt.day) {
      if(g_lastDay != -1) {
         // Record previous day results
         if(g_challenge.todayProfit > 0) g_trades.hasWinToday = true;

         // Reset daily stats
         g_dayStartBalance = acc.Balance();
         g_trades.todayTrades = 0;
         g_trades.todayWins = 0;
         g_trades.todayLosses = 0;
         g_trades.hasWinToday = false;

         // Reset ranges
         ZeroMemory(g_asianRange);
         ZeroMemory(g_londonRange);
      }
      g_lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE ANALYSIS (from V5)                              |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure() {
   ArrayResize(g_swingHighs, 0);
   ArrayResize(g_swingLows, 0);

   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int bars = StructureBars + SwingLookback * 2;
   if(CopyHigh(_Symbol, TF_Structure, 0, bars, high) <= 0) return;
   if(CopyLow(_Symbol, TF_Structure, 0, bars, low) <= 0) return;
   if(CopyClose(_Symbol, TF_Structure, 0, bars, close) <= 0) return;

   datetime times[];
   ArraySetAsSeries(times, true);
   CopyTime(_Symbol, TF_Structure, 0, bars, times);

   // Find swing points
   for(int i = SwingLookback; i < StructureBars; i++) {
      if(IsSwingHigh(high, i, SwingLookback)) {
         SwingPoint sp;
         sp.price = high[i];
         sp.time = times[i];
         sp.isHigh = true;
         sp.barIndex = i;

         if(ArraySize(g_swingLows) > 0) {
            double lastLow = g_swingLows[ArraySize(g_swingLows) - 1].price;
            if(MathAbs(sp.price - lastLow) >= g_atr * MinSwingSize) {
               int size = ArraySize(g_swingHighs);
               ArrayResize(g_swingHighs, size + 1);
               g_swingHighs[size] = sp;
            }
         } else {
            int size = ArraySize(g_swingHighs);
            ArrayResize(g_swingHighs, size + 1);
            g_swingHighs[size] = sp;
         }
      }

      if(IsSwingLow(low, i, SwingLookback)) {
         SwingPoint sp;
         sp.price = low[i];
         sp.time = times[i];
         sp.isHigh = false;
         sp.barIndex = i;

         if(ArraySize(g_swingHighs) > 0) {
            double lastHigh = g_swingHighs[ArraySize(g_swingHighs) - 1].price;
            if(MathAbs(lastHigh - sp.price) >= g_atr * MinSwingSize) {
               int size = ArraySize(g_swingLows);
               ArrayResize(g_swingLows, size + 1);
               g_swingLows[size] = sp;
            }
         } else {
            int size = ArraySize(g_swingLows);
            ArrayResize(g_swingLows, size + 1);
            g_swingLows[size] = sp;
         }
      }
   }

   DetermineStructure();
   AnalyzeHTFStructure();
}

bool IsSwingHigh(double &high[], int index, int lookback) {
   double pivot = high[index];
   for(int i = 1; i <= lookback; i++) {
      if(high[index - i] >= pivot) return false;
      if(high[index + i] >= pivot) return false;
   }
   return true;
}

bool IsSwingLow(double &low[], int index, int lookback) {
   double pivot = low[index];
   for(int i = 1; i <= lookback; i++) {
      if(low[index - i] <= pivot) return false;
      if(low[index + i] <= pivot) return false;
   }
   return true;
}

void DetermineStructure() {
   int numHighs = ArraySize(g_swingHighs);
   int numLows = ArraySize(g_swingLows);

   g_structure.mtfStructure = STRUCTURE_UNKNOWN;
   g_structure.direction = 0;

   if(numHighs < 2 || numLows < 2) {
      g_structure.mtfStructure = STRUCTURE_RANGING;
      return;
   }

   SwingPoint sh1 = g_swingHighs[0];
   SwingPoint sh2 = g_swingHighs[1];
   SwingPoint sl1 = g_swingLows[0];
   SwingPoint sl2 = g_swingLows[1];

   g_structure.keyResistance = sh1.price;
   g_structure.keySupport = sl1.price;

   bool higherHigh = (sh1.price > sh2.price);
   bool higherLow = (sl1.price > sl2.price);
   bool lowerHigh = (sh1.price < sh2.price);
   bool lowerLow = (sl1.price < sl2.price);

   if(higherHigh && higherLow) {
      g_structure.mtfStructure = STRUCTURE_BULLISH;
      g_structure.direction = 1;
   }
   else if(lowerHigh && lowerLow) {
      g_structure.mtfStructure = STRUCTURE_BEARISH;
      g_structure.direction = -1;
   }
   else {
      g_structure.mtfStructure = STRUCTURE_RANGING;
      g_structure.direction = 0;
   }
}

void AnalyzeHTFStructure() {
   double emaFast[], emaSlow[], close[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(close, true);

   CopyBuffer(g_emaFastH4, 0, 0, 5, emaFast);
   CopyBuffer(g_emaSlowH4, 0, 0, 5, emaSlow);
   CopyClose(_Symbol, TF_HTF, 0, 5, close);

   bool emaBullish = (emaFast[0] > emaSlow[0]);
   bool priceAboveEMA = (close[0] > emaFast[0]);
   bool emaRising = (emaFast[0] > emaFast[2]);

   bool emaBearish = (emaFast[0] < emaSlow[0]);
   bool priceBelowEMA = (close[0] < emaFast[0]);
   bool emaFalling = (emaFast[0] < emaFast[2]);

   if(emaBullish && priceAboveEMA && emaRising) {
      g_structure.htfStructure = STRUCTURE_BULLISH;
   }
   else if(emaBearish && priceBelowEMA && emaFalling) {
      g_structure.htfStructure = STRUCTURE_BEARISH;
   }
   else {
      g_structure.htfStructure = STRUCTURE_RANGING;
   }
}

//+------------------------------------------------------------------+
//| CALCULATE RANGES                                                 |
//+------------------------------------------------------------------+
void CalculateRanges() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(h >= 6 && !g_asianRange.isValid) {
      CalculateRangeZone(g_asianRange, 0, 6);
   }

   if(h >= 10 && !g_londonRange.isValid) {
      CalculateRangeZone(g_londonRange, 7, 10);
   }
}

void CalculateRangeZone(RangeZone &zone, int startHour, int endHour) {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   dt.hour = startHour;
   dt.min = 0;
   dt.sec = 0;
   datetime startTime = StructToTime(dt);

   dt.hour = endHour;
   datetime endTime = StructToTime(dt);

   int startBar = iBarShift(_Symbol, PERIOD_M15, startTime);
   int endBar = iBarShift(_Symbol, PERIOD_M15, endTime);

   if(startBar <= 0 || endBar < 0) return;

   double highs[], lows[], closes[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);

   int count = startBar - endBar + 1;
   if(count <= 0) return;

   if(CopyHigh(_Symbol, PERIOD_M15, endBar, count, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, endBar, count, lows) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_M15, endBar, count, closes) <= 0) return;

   zone.high = highs[ArrayMaximum(highs)];
   zone.low = lows[ArrayMinimum(lows)];
   zone.mid = (zone.high + zone.low) / 2;
   zone.size = zone.high - zone.low;
   zone.startTime = startTime;
   zone.endTime = endTime;

   double minSize = g_atr * 0.4;
   double maxSize = g_atr * 2.5;

   if(zone.size < minSize || zone.size > maxSize) {
      zone.isValid = false;
      return;
   }

   double touchZone = zone.size * 0.1;
   zone.touchesHigh = 0;
   zone.touchesLow = 0;

   for(int i = 0; i < count; i++) {
      if(highs[i] >= zone.high - touchZone) zone.touchesHigh++;
      if(lows[i] <= zone.low + touchZone) zone.touchesLow++;
   }

   int outsideBars = 0;
   for(int i = 0; i < count; i++) {
      if(closes[i] > zone.high || closes[i] < zone.low) outsideBars++;
   }

   double insideRatio = 1.0 - ((double)outsideBars / count);
   double touchScore = MathMin(1.0, (zone.touchesHigh + zone.touchesLow) / 6.0);
   zone.qualityScore = (insideRatio * 60) + (touchScore * 40);

   zone.isValid = (zone.touchesHigh >= 2 || zone.touchesLow >= 2);
   zone.isQuality = (zone.qualityScore >= 60);
}

//+------------------------------------------------------------------+
//| SCAN FOR SIGNAL                                                  |
//+------------------------------------------------------------------+
EntrySignal ScanForSignal() {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(g_asianRange.isValid) {
      signal = CheckRangeForSignal(g_asianRange, "Asian", bid, ask);
      if(signal.isValid && signal.score >= MinScore) return signal;
   }

   if(g_londonRange.isValid) {
      signal = CheckRangeForSignal(g_londonRange, "London", bid, ask);
      if(signal.isValid && signal.score >= MinScore) return signal;
   }

   return signal;
}

EntrySignal CheckRangeForSignal(RangeZone &zone, string zoneName, double bid, double ask) {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   double buffer = g_atr * 0.15;

   // BREAKOUT
   if(bid > zone.high + buffer && bid < zone.high + zone.size) {
      if(g_structure.direction >= 0) {
         signal = BuildSignal(zone, zoneName, SETUP_BREAKOUT, 1, bid, ask);
         if(signal.isValid) return signal;
      }
   }

   if(ask < zone.low - buffer && ask > zone.low - zone.size) {
      if(g_structure.direction <= 0) {
         signal = BuildSignal(zone, zoneName, SETUP_BREAKOUT, -1, bid, ask);
         if(signal.isValid) return signal;
      }
   }

   // RETEST
   if(bid > zone.high - zone.size * 0.2 && bid <= zone.high + buffer) {
      if(g_structure.direction == 1) {
         signal = BuildSignal(zone, zoneName, SETUP_RETEST, 1, bid, ask);
         if(signal.isValid) return signal;
      }
   }

   if(ask < zone.low + zone.size * 0.2 && ask >= zone.low - buffer) {
      if(g_structure.direction == -1) {
         signal = BuildSignal(zone, zoneName, SETUP_RETEST, -1, bid, ask);
         if(signal.isValid) return signal;
      }
   }

   // CONTINUATION
   if(bid <= zone.low + zone.size * 0.3 && bid >= zone.low - buffer) {
      if(g_structure.direction == 1 && g_structure.htfStructure == STRUCTURE_BULLISH) {
         signal = BuildSignal(zone, zoneName, SETUP_CONTINUATION, 1, bid, ask);
         if(signal.isValid) return signal;
      }
   }

   if(ask >= zone.high - zone.size * 0.3 && ask <= zone.high + buffer) {
      if(g_structure.direction == -1 && g_structure.htfStructure == STRUCTURE_BEARISH) {
         signal = BuildSignal(zone, zoneName, SETUP_CONTINUATION, -1, bid, ask);
         if(signal.isValid) return signal;
      }
   }

   return signal;
}

EntrySignal BuildSignal(RangeZone &zone, string zoneName, ENUM_SETUP_TYPE setup, int dir, double bid, double ask) {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.setup = setup;
   signal.direction = dir;
   signal.isValid = false;

   // Pattern check
   ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(dir);
   if(RequirePattern && pattern == PATTERN_NONE) {
      return signal;
   }
   signal.pattern = pattern;

   // Momentum check
   if(RequireMomentum && !IsMomentumAligned(dir)) {
      return signal;
   }

   // Entry, SL, TP
   if(dir == 1) {
      signal.entryPrice = ask;
      signal.slPrice = (setup == SETUP_RETEST) ? zone.mid - g_atr * 0.1 : zone.low - g_atr * 0.2;
      signal.tp1Price = ask + (ask - signal.slPrice) * TP1_RR;
      signal.tp2Price = ask + (ask - signal.slPrice) * 2.5;
   } else {
      signal.entryPrice = bid;
      signal.slPrice = (setup == SETUP_RETEST) ? zone.mid + g_atr * 0.1 : zone.high + g_atr * 0.2;
      signal.tp1Price = bid - (signal.slPrice - bid) * TP1_RR;
      signal.tp2Price = bid - (signal.slPrice - bid) * 2.5;
   }

   double risk = MathAbs(signal.entryPrice - signal.slPrice);
   double reward = MathAbs(signal.tp1Price - signal.entryPrice);
   signal.rr = (risk > 0) ? reward / risk : 0;

   if(signal.rr < MinRR) {
      return signal;
   }

   signal.score = CalculateScore(signal, zone, dir);
   signal.reason = zoneName + " " + EnumToString(setup) + " " + (dir == 1 ? "Long" : "Short");
   signal.isValid = true;

   return signal;
}

ENUM_CANDLE_PATTERN DetectCandlePattern(int dir) {
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   CopyOpen(_Symbol, TF_Entry, 0, 4, open);
   CopyHigh(_Symbol, TF_Entry, 0, 4, high);
   CopyLow(_Symbol, TF_Entry, 0, 4, low);
   CopyClose(_Symbol, TF_Entry, 0, 4, close);

   double body1 = MathAbs(close[1] - open[1]);
   double upperWick1 = high[1] - MathMax(close[1], open[1]);
   double lowerWick1 = MathMin(close[1], open[1]) - low[1];
   bool bullCandle1 = (close[1] > open[1]);
   bool bearCandle1 = (close[1] < open[1]);

   double body2 = MathAbs(close[2] - open[2]);
   bool bullCandle2 = (close[2] > open[2]);
   bool bearCandle2 = (close[2] < open[2]);

   // PIN BAR
   if(dir == 1 && lowerWick1 > body1 * 2.0 && lowerWick1 > upperWick1 * 2.0) {
      if(close[1] > (high[1] + low[1]) / 2) return PATTERN_PIN_BAR;
   }
   if(dir == -1 && upperWick1 > body1 * 2.0 && upperWick1 > lowerWick1 * 2.0) {
      if(close[1] < (high[1] + low[1]) / 2) return PATTERN_PIN_BAR;
   }

   // ENGULFING
   if(dir == 1 && bullCandle1 && bearCandle2) {
      if(body1 > body2 * 1.2 && close[1] > open[2] && open[1] < close[2]) return PATTERN_ENGULFING;
   }
   if(dir == -1 && bearCandle1 && bullCandle2) {
      if(body1 > body2 * 1.2 && close[1] < open[2] && open[1] > close[2]) return PATTERN_ENGULFING;
   }

   // REJECTION
   if(dir == 1 && bullCandle1 && body1 > g_atr * 0.3 && close[1] > high[2]) return PATTERN_REJECTION;
   if(dir == -1 && bearCandle1 && body1 > g_atr * 0.3 && close[1] < low[2]) return PATTERN_REJECTION;

   // INSIDE BAR BO
   bool isInsideBar2 = (high[2] < high[3] && low[2] > low[3]);
   if(isInsideBar2) {
      if(dir == 1 && close[1] > high[2]) return PATTERN_INSIDE_BAR_BO;
      if(dir == -1 && close[1] < low[2]) return PATTERN_INSIDE_BAR_BO;
   }

   return PATTERN_NONE;
}

bool IsMomentumAligned(int dir) {
   double rsi[];
   ArraySetAsSeries(rsi, true);
   CopyBuffer(g_rsiHandle, 0, 0, 3, rsi);

   if(dir == 1) {
      return (rsi[0] > rsi[1] && rsi[0] < 70 && rsi[0] > 40);
   }
   if(dir == -1) {
      return (rsi[0] < rsi[1] && rsi[0] > 30 && rsi[0] < 60);
   }

   return false;
}

int CalculateScore(EntrySignal &signal, RangeZone &zone, int dir) {
   int score = 0;

   // Structure
   if(g_structure.direction == dir) score += 3;
   else if(g_structure.direction == 0) score += 1;

   // HTF
   if(g_structure.htfStructure == STRUCTURE_BULLISH && dir == 1) score += 1;
   if(g_structure.htfStructure == STRUCTURE_BEARISH && dir == -1) score += 1;

   // Pattern
   if(signal.pattern == PATTERN_ENGULFING || signal.pattern == PATTERN_PIN_BAR) score += 2;
   else if(signal.pattern != PATTERN_NONE) score += 1;

   // Range quality
   if(zone.isQuality) score += 2;
   else if(zone.qualityScore >= 50) score += 1;

   // Momentum
   if(IsMomentumAligned(dir)) score += 2;

   return score;
}

//+------------------------------------------------------------------+
//| EXECUTE SIGNAL                                                   |
//+------------------------------------------------------------------+
void ExecuteSignal(EntrySignal &signal) {
   double lots = CalculateLots(signal.entryPrice, signal.slPrice);
   if(lots <= 0) return;

   string comment = TradeComment + "_" + EnumToString(signal.setup) + "_S" + IntegerToString(signal.score);
   bool success = false;

   if(signal.direction == 1) {
      success = trade.Buy(lots, _Symbol, signal.entryPrice, signal.slPrice, signal.tp1Price, comment);
   } else {
      success = trade.Sell(lots, _Symbol, signal.entryPrice, signal.slPrice, signal.tp1Price, comment);
   }

   if(success) {
      g_trades.todayTrades++;
      Print("=== TRADE EXECUTED ===");
      Print("Phase: ", EnumToString(g_challenge.phase));
      Print("Risk: ", DoubleToString(g_risk.currentRisk, 2), "%");
      Print("Signal: ", signal.reason);
      Print("Score: ", signal.score, "/10");
      Print("Lots: ", lots);
   }
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol && pos.Magic() == Magic) {
            trade.PositionClose(pos.Ticket());
         }
      }
   }
   Print("All positions closed: ", reason);
}

//+------------------------------------------------------------------+
//| IS IN TRADING SESSION                                            |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(TradeLondon && h >= 7 && h < 11) return true;
   if(TradeNY && h >= 13 && h < 16) return true;

   return false;
}

//+------------------------------------------------------------------+
//| DRAW ON CHART                                                    |
//+------------------------------------------------------------------+
void DrawOnChart() {
   if(g_asianRange.isValid) DrawRangeBox("SBv6_Asian", g_asianRange, clrDodgerBlue);
   if(g_londonRange.isValid) DrawRangeBox("SBv6_London", g_londonRange, clrOrange);

   if(g_structure.keyResistance > 0) DrawHLine("SBv6_Res", g_structure.keyResistance, clrRed);
   if(g_structure.keySupport > 0) DrawHLine("SBv6_Sup", g_structure.keySupport, clrGreen);
}

void DrawRangeBox(string name, RangeZone &range, color clr) {
   ObjectDelete(0, name);
   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H1);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, range.startTime, range.high, endTime, range.low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void DrawHLine(string name, double price, color clr) {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
}

//+------------------------------------------------------------------+
//| SHOW DASHBOARD                                                   |
//+------------------------------------------------------------------+
void ShowDashboard() {
   string s = "";
   s += "##################################################\n";
   s += "   SESSION BREAKOUT V6 - CHALLENGE OPTIMIZER\n";
   s += "##################################################\n\n";

   // Challenge Progress
   s += "--------------- CHALLENGE PROGRESS ---------------\n";
   s += StringFormat("Target: %.1f%% | Current: %.2f%%\n", ChallengeTarget, g_challenge.profitPercent);
   s += StringFormat("Balance: %.2f / %.2f\n", g_challenge.currentBalance, g_challenge.targetBalance);

   // Progress bar
   double progress = MathMin(100, (g_challenge.profitPercent / ChallengeTarget) * 100);
   int barLen = 20;
   int filled = (int)(progress / 100 * barLen);
   s += "[";
   for(int i = 0; i < barLen; i++) {
      s += (i < filled) ? "#" : "-";
   }
   s += "] " + DoubleToString(progress, 1) + "%\n\n";

   s += "Phase: " + GetPhaseString(g_challenge.phase) + "\n";
   s += StringFormat("Days: %d/%d remaining\n", g_challenge.daysRemaining, ChallengeDays);
   s += StringFormat("Daily target: %.2f%%\n\n", g_challenge.dailyTargetPercent);

   // Risk Management
   s += "--------------- RISK MANAGEMENT ---------------\n";
   s += StringFormat("Current Risk: %.2f%% (Max: %.2f%%)\n", g_risk.currentRisk, g_risk.maxRiskAllowed);
   s += StringFormat("DD Buffer: %.2f%% | Daily: %.2f%%\n", g_risk.ddBufferRemaining, g_risk.dailyDDRemaining);
   s += StringFormat("Today P/L: %.2f%%\n\n", g_challenge.todayProfit);

   // Trade Status
   s += "--------------- TRADE STATUS ---------------\n";
   s += "Direction: " + GetDirectionString(g_trades.currentDirection) + "\n";
   s += StringFormat("Open: %d Long / %d Short\n", g_trades.openLongs, g_trades.openShorts);
   s += StringFormat("Today: %d trades | Open P/L: %.2f\n\n", (int)g_trades.todayTrades, g_trades.openPnL);

   // Market Structure
   s += "--------------- MARKET STRUCTURE ---------------\n";
   s += "MTF: " + GetStructureString(g_structure.mtfStructure) + "\n";
   s += "HTF: " + GetStructureString(g_structure.htfStructure) + "\n\n";

   // Current Signal
   s += "--------------- SIGNAL ---------------\n";
   if(g_currentSignal.isValid) {
      s += g_currentSignal.reason + "\n";
      s += "Score: " + IntegerToString(g_currentSignal.score) + "/10\n";
   } else {
      s += "No valid signal\n";
   }
   s += "\n";

   // Status
   s += "--------------- STATUS ---------------\n";
   if(!g_risk.canTrade) {
      s += "BLOCKED: " + g_risk.blockReason + "\n";
   } else {
      s += "ACTIVE - Scanning for opportunities\n";
   }
   s += "Session: " + (IsInTradingSession() ? "OPEN" : "CLOSED") + "\n";
   s += "##################################################\n";

   Comment(s);
}

string GetPhaseString(ENUM_CHALLENGE_PHASE phase) {
   switch(phase) {
      case PHASE_EARLY: return "EARLY (Building)";
      case PHASE_MIDDLE: return "MIDDLE (Accelerating)";
      case PHASE_FINAL: return "FINAL (Careful)";
      case PHASE_PROTECTION: return "PROTECTION (Securing)";
      default: return "UNKNOWN";
   }
}

string GetDirectionString(ENUM_TRADE_DIRECTION dir) {
   switch(dir) {
      case DIR_NONE: return "NONE (Any allowed)";
      case DIR_LONG_ONLY: return "LONG ONLY";
      case DIR_SHORT_ONLY: return "SHORT ONLY";
      default: return "UNKNOWN";
   }
}

string GetStructureString(ENUM_MARKET_STRUCTURE str) {
   switch(str) {
      case STRUCTURE_BULLISH: return "BULLISH";
      case STRUCTURE_BEARISH: return "BEARISH";
      case STRUCTURE_RANGING: return "RANGING";
      default: return "UNKNOWN";
   }
}
//+------------------------------------------------------------------+
