//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v7.mq5 |
//|          ADAPTIVE CHALLENGE MODE - Balance Quality & Frequency   |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "7.00"
#property description "V7: Adaptive aggressiveness + More opportunities + Smart management"
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

enum ENUM_TRADING_MODE {
   MODE_AGGRESSIVE,     // More trades, lower quality threshold
   MODE_BALANCED,       // Balance between quantity and quality
   MODE_CONSERVATIVE,   // Fewer trades, higher quality
   MODE_ADAPTIVE        // Auto-adjust based on progress
};

enum ENUM_MARKET_BIAS {
   BIAS_BULLISH,
   BIAS_BEARISH,
   BIAS_NEUTRAL
};

enum ENUM_SETUP_TYPE {
   SETUP_BREAKOUT,
   SETUP_RETEST,
   SETUP_PULLBACK,
   SETUP_REVERSAL,
   SETUP_MOMENTUM
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "========== CHALLENGE SETTINGS =========="
input ENUM_PROP_FIRM PropFirm = PROP_FTMO;
input double ChallengeTarget = 10.0;          // Target profit %
input double InitialBalance = 100000;         // Starting balance
input int ChallengeDays = 30;                 // Days to complete

input group "========== TRADING MODE =========="
input ENUM_TRADING_MODE TradingMode = MODE_ADAPTIVE;  // Trading approach
input int MinScoreAggressive = 3;             // Min score for aggressive
input int MinScoreBalanced = 4;               // Min score for balanced
input int MinScoreConservative = 5;           // Min score for conservative

input group "========== RISK MANAGEMENT =========="
input double BaseRisk = 1.2;                  // Base risk %
input double MaxRisk = 2.0;                   // Maximum risk %
input double MinRisk = 0.5;                   // Minimum risk %
input double MaxDailyDD = 4.0;                // Max daily DD %
input double MaxTotalDD = 8.0;                // Max total DD %
input bool UseCompounding = true;             // Compound profits

input group "========== TRADE LIMITS =========="
input int MaxTradesPerDay = 5;                // Max daily trades
input int MaxOpenTrades = 2;                  // Max simultaneous
input bool AllowHedging = false;              // Allow buy+sell same time
input bool CloseLoserFirst = true;            // Close loser before new trade

input group "========== ENTRY SETTINGS =========="
input bool UseBreakout = true;                // Breakout entries
input bool UseRetest = true;                  // Retest entries
input bool UsePullback = true;                // Pullback entries
input bool UseMomentum = true;                // Momentum entries
input bool UseReversal = false;               // Reversal at extremes
input double MinRR = 1.3;                     // Minimum R:R (lower = more trades)

input group "========== CONFIRMATION =========="
input bool RequirePatternStrict = false;      // Strict pattern requirement
input bool RequireMomentumRSI = true;         // RSI confirmation
input int RSI_Period = 14;
input int RSI_Upper = 65;                     // Upper threshold (not 70)
input int RSI_Lower = 35;                     // Lower threshold (not 30)

input group "========== SESSIONS (Extended) =========="
input bool TradeFrankfurt = true;             // 06-08 UTC
input bool TradeLondon = true;                // 08-12 UTC
input bool TradeNYOpen = true;                // 13-17 UTC
input bool TradeLondonClose = true;           // 15-17 UTC

input group "========== EXIT MANAGEMENT =========="
input double TP1_RR = 1.5;                    // First TP ratio
input double PartialPercent = 50.0;           // Partial close %
input bool UseBreakeven = true;
input double BE_Trigger = 0.8;                // BE at 0.8 RR (earlier)
input bool UseTrailing = true;
input double TrailStart = 1.2;                // Start trailing at 1.2 RR
input double TrailDistance = 0.6;             // Trail distance (ATR mult)

input group "========== STRUCTURE =========="
input ENUM_TIMEFRAMES TF_HTF = PERIOD_H4;
input ENUM_TIMEFRAMES TF_MTF = PERIOD_H1;
input ENUM_TIMEFRAMES TF_Entry = PERIOD_M15;
input int EMA_Fast = 21;
input int EMA_Slow = 50;

input group "========== RANGE =========="
input int AsianStart = 0;                     // Asian start hour UTC
input int AsianEnd = 6;                       // Asian end hour UTC
input int LondonRangeStart = 7;
input int LondonRangeEnd = 9;

input group "========== EA =========="
input int Magic = 789012;
input string TradeComment = "SBv7";
input bool ShowDashboard = true;

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct ChallengeTracker {
   double startBalance;
   double currentBalance;
   double targetBalance;
   double profitPercent;
   double dailyProfit;
   int daysElapsed;
   int daysRemaining;
   double dailyTarget;
   double behindSchedule;     // How much behind target
   bool isAhead;
   bool targetReached;
};

struct AdaptiveSettings {
   int currentMinScore;
   double currentRisk;
   int currentMaxTrades;
   string modeDescription;
   bool isAggressive;
};

struct MarketContext {
   ENUM_MARKET_BIAS htfBias;
   ENUM_MARKET_BIAS mtfBias;
   ENUM_MARKET_BIAS ltfBias;
   int overallBias;           // 1=Bull, -1=Bear, 0=Neutral
   double atr;
   double rsi;
   bool isTrending;
   bool isVolatile;
};

struct RangeData {
   double high;
   double low;
   double mid;
   double size;
   bool isValid;
   int type;                  // 0=Asian, 1=London
};

struct TradeSignal {
   ENUM_SETUP_TYPE type;
   int direction;
   double entry;
   double sl;
   double tp;
   double rr;
   int score;
   string reason;
   bool isValid;
};

struct PositionTracker {
   int longCount;
   int shortCount;
   double totalPnL;
   int todayTrades;
   int todayWins;
   int todayLosses;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo pos;
CAccountInfo acc;

ChallengeTracker g_challenge;
AdaptiveSettings g_adaptive;
MarketContext g_market;
RangeData g_asianRange;
RangeData g_londonRange;
TradeSignal g_signal;
PositionTracker g_positions;

int g_atrHandle, g_rsiHandle;
int g_emaFastHTF, g_emaSlowHTF;
int g_emaFastMTF, g_emaSlowMTF;
int g_emaFastLTF, g_emaSlowLTF;

datetime g_lastBar;
datetime g_startDate;
double g_dayStartBalance;
int g_lastDay = -1;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_challenge.startBalance = (InitialBalance > 0) ? InitialBalance : acc.Balance();
   g_challenge.targetBalance = g_challenge.startBalance * (1 + ChallengeTarget / 100);
   g_startDate = TimeCurrent();
   g_dayStartBalance = acc.Balance();

   // Indicators
   g_atrHandle = iATR(_Symbol, TF_MTF, 14);
   g_rsiHandle = iRSI(_Symbol, TF_Entry, RSI_Period, PRICE_CLOSE);

   g_emaFastHTF = iMA(_Symbol, TF_HTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHTF = iMA(_Symbol, TF_HTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_emaFastMTF = iMA(_Symbol, TF_MTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowMTF = iMA(_Symbol, TF_MTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_emaFastLTF = iMA(_Symbol, TF_Entry, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowLTF = iMA(_Symbol, TF_Entry, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   if(g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE) {
      Print("Indicator error");
      return INIT_FAILED;
   }

   Print("=== SESSION BREAKOUT V7 - ADAPTIVE MODE ===");
   Print("Target: ", ChallengeTarget, "% in ", ChallengeDays, " days");
   Print("Mode: ", EnumToString(TradingMode));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_emaFastHTF);
   IndicatorRelease(g_emaSlowHTF);
   IndicatorRelease(g_emaFastMTF);
   IndicatorRelease(g_emaSlowMTF);
   IndicatorRelease(g_emaFastLTF);
   IndicatorRelease(g_emaSlowLTF);
   ObjectsDeleteAll(0, "SBv7_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   datetime barTime = iTime(_Symbol, TF_Entry, 0);
   bool newBar = (barTime != g_lastBar);

   // Always update
   CheckDayReset();
   UpdateChallengeTracker();
   UpdateAdaptiveSettings();
   UpdateMarketContext();
   UpdatePositionTracker();

   // Manage open positions
   ManagePositions();

   // Check if can trade
   if(!CanTrade()) {
      if(ShowDashboard) DisplayDashboard();
      return;
   }

   if(newBar) {
      g_lastBar = barTime;

      // Calculate ranges
      CalculateRanges();

      // Scan for signals
      if(IsInSession()) {
         g_signal = ScanForSignals();

         if(g_signal.isValid && g_signal.score >= g_adaptive.currentMinScore) {
            if(IsDirectionAllowed(g_signal.direction)) {
               ExecuteTrade(g_signal);
            }
         }
      }
   }

   if(ShowDashboard) DisplayDashboard();
}

//+------------------------------------------------------------------+
//| UPDATE CHALLENGE TRACKER                                         |
//+------------------------------------------------------------------+
void UpdateChallengeTracker() {
   g_challenge.currentBalance = acc.Equity();
   g_challenge.profitPercent = ((g_challenge.currentBalance - g_challenge.startBalance) / g_challenge.startBalance) * 100;
   g_challenge.dailyProfit = ((g_challenge.currentBalance - g_dayStartBalance) / g_dayStartBalance) * 100;

   // Days
   int daysPassed = (int)((TimeCurrent() - g_startDate) / 86400);
   g_challenge.daysElapsed = MathMax(1, daysPassed);
   g_challenge.daysRemaining = MathMax(1, ChallengeDays - daysPassed);

   // Expected progress
   double expectedProgress = (ChallengeTarget / ChallengeDays) * g_challenge.daysElapsed;
   g_challenge.behindSchedule = expectedProgress - g_challenge.profitPercent;
   g_challenge.isAhead = (g_challenge.behindSchedule <= 0);

   // Daily target to catch up
   double remaining = ChallengeTarget - g_challenge.profitPercent;
   g_challenge.dailyTarget = remaining / g_challenge.daysRemaining;

   g_challenge.targetReached = (g_challenge.profitPercent >= ChallengeTarget);
}

//+------------------------------------------------------------------+
//| UPDATE ADAPTIVE SETTINGS                                         |
//+------------------------------------------------------------------+
void UpdateAdaptiveSettings() {
   if(TradingMode == MODE_AGGRESSIVE) {
      g_adaptive.currentMinScore = MinScoreAggressive;
      g_adaptive.currentRisk = MathMin(MaxRisk, BaseRisk * 1.3);
      g_adaptive.currentMaxTrades = MaxTradesPerDay + 2;
      g_adaptive.modeDescription = "AGGRESSIVE";
      g_adaptive.isAggressive = true;
   }
   else if(TradingMode == MODE_BALANCED) {
      g_adaptive.currentMinScore = MinScoreBalanced;
      g_adaptive.currentRisk = BaseRisk;
      g_adaptive.currentMaxTrades = MaxTradesPerDay;
      g_adaptive.modeDescription = "BALANCED";
      g_adaptive.isAggressive = false;
   }
   else if(TradingMode == MODE_CONSERVATIVE) {
      g_adaptive.currentMinScore = MinScoreConservative;
      g_adaptive.currentRisk = MathMax(MinRisk, BaseRisk * 0.7);
      g_adaptive.currentMaxTrades = MaxTradesPerDay - 1;
      g_adaptive.modeDescription = "CONSERVATIVE";
      g_adaptive.isAggressive = false;
   }
   else { // MODE_ADAPTIVE
      AdaptBasedOnProgress();
   }

   // Compounding adjustment
   if(UseCompounding && g_challenge.profitPercent > 0) {
      double bonus = g_challenge.profitPercent * 0.05;  // 5% of profit added to risk
      g_adaptive.currentRisk = MathMin(MaxRisk, g_adaptive.currentRisk + bonus);
   }

   // Cap risk based on DD proximity
   double currentDD = -MathMin(0, g_challenge.profitPercent);
   double dailyDD = -MathMin(0, g_challenge.dailyProfit);

   if(currentDD > MaxTotalDD - 2) g_adaptive.currentRisk = MinRisk;
   if(dailyDD > MaxDailyDD - 1.5) g_adaptive.currentRisk = MinRisk;

   // Near target - reduce risk
   if(g_challenge.profitPercent > ChallengeTarget * 0.85) {
      g_adaptive.currentRisk = MathMin(g_adaptive.currentRisk, MinRisk + 0.3);
      g_adaptive.currentMinScore = MinScoreConservative;
      g_adaptive.modeDescription = "PROTECTION";
   }
}

//+------------------------------------------------------------------+
//| ADAPT BASED ON PROGRESS                                          |
//+------------------------------------------------------------------+
void AdaptBasedOnProgress() {
   // Behind schedule - be more aggressive
   if(g_challenge.behindSchedule > 2.0) {
      g_adaptive.currentMinScore = MinScoreAggressive;
      g_adaptive.currentRisk = MathMin(MaxRisk, BaseRisk * 1.4);
      g_adaptive.currentMaxTrades = MaxTradesPerDay + 2;
      g_adaptive.modeDescription = "CATCH-UP";
      g_adaptive.isAggressive = true;
   }
   // Slightly behind - balanced aggressive
   else if(g_challenge.behindSchedule > 0.5) {
      g_adaptive.currentMinScore = MinScoreAggressive;
      g_adaptive.currentRisk = MathMin(MaxRisk, BaseRisk * 1.2);
      g_adaptive.currentMaxTrades = MaxTradesPerDay + 1;
      g_adaptive.modeDescription = "PUSH";
      g_adaptive.isAggressive = true;
   }
   // On track - balanced
   else if(g_challenge.behindSchedule > -1.0) {
      g_adaptive.currentMinScore = MinScoreBalanced;
      g_adaptive.currentRisk = BaseRisk;
      g_adaptive.currentMaxTrades = MaxTradesPerDay;
      g_adaptive.modeDescription = "ON-TRACK";
      g_adaptive.isAggressive = false;
   }
   // Ahead of schedule - conservative
   else {
      g_adaptive.currentMinScore = MinScoreConservative;
      g_adaptive.currentRisk = MathMax(MinRisk, BaseRisk * 0.8);
      g_adaptive.currentMaxTrades = MaxTradesPerDay - 1;
      g_adaptive.modeDescription = "CRUISING";
      g_adaptive.isAggressive = false;
   }
}

//+------------------------------------------------------------------+
//| UPDATE MARKET CONTEXT                                            |
//+------------------------------------------------------------------+
void UpdateMarketContext() {
   // ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0) g_market.atr = atr[0];

   // RSI
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsiHandle, 0, 0, 3, rsi) > 0) g_market.rsi = rsi[0];

   // HTF Bias
   double emaFH[], emaSH[], closeH[];
   ArraySetAsSeries(emaFH, true);
   ArraySetAsSeries(emaSH, true);
   ArraySetAsSeries(closeH, true);

   CopyBuffer(g_emaFastHTF, 0, 0, 3, emaFH);
   CopyBuffer(g_emaSlowHTF, 0, 0, 3, emaSH);
   CopyClose(_Symbol, TF_HTF, 0, 3, closeH);

   if(emaFH[0] > emaSH[0] && closeH[0] > emaFH[0]) g_market.htfBias = BIAS_BULLISH;
   else if(emaFH[0] < emaSH[0] && closeH[0] < emaFH[0]) g_market.htfBias = BIAS_BEARISH;
   else g_market.htfBias = BIAS_NEUTRAL;

   // MTF Bias
   double emaFM[], emaSM[], closeM[];
   ArraySetAsSeries(emaFM, true);
   ArraySetAsSeries(emaSM, true);
   ArraySetAsSeries(closeM, true);

   CopyBuffer(g_emaFastMTF, 0, 0, 3, emaFM);
   CopyBuffer(g_emaSlowMTF, 0, 0, 3, emaSM);
   CopyClose(_Symbol, TF_MTF, 0, 3, closeM);

   if(emaFM[0] > emaSM[0] && closeM[0] > emaFM[0]) g_market.mtfBias = BIAS_BULLISH;
   else if(emaFM[0] < emaSM[0] && closeM[0] < emaFM[0]) g_market.mtfBias = BIAS_BEARISH;
   else g_market.mtfBias = BIAS_NEUTRAL;

   // LTF Bias
   double emaFL[], emaSL[], closeL[];
   ArraySetAsSeries(emaFL, true);
   ArraySetAsSeries(emaSL, true);
   ArraySetAsSeries(closeL, true);

   CopyBuffer(g_emaFastLTF, 0, 0, 3, emaFL);
   CopyBuffer(g_emaSlowLTF, 0, 0, 3, emaSL);
   CopyClose(_Symbol, TF_Entry, 0, 3, closeL);

   if(emaFL[0] > emaSL[0]) g_market.ltfBias = BIAS_BULLISH;
   else if(emaFL[0] < emaSL[0]) g_market.ltfBias = BIAS_BEARISH;
   else g_market.ltfBias = BIAS_NEUTRAL;

   // Overall bias (weighted)
   int biasSum = 0;
   if(g_market.htfBias == BIAS_BULLISH) biasSum += 2;
   else if(g_market.htfBias == BIAS_BEARISH) biasSum -= 2;

   if(g_market.mtfBias == BIAS_BULLISH) biasSum += 1;
   else if(g_market.mtfBias == BIAS_BEARISH) biasSum -= 1;

   if(g_market.ltfBias == BIAS_BULLISH) biasSum += 1;
   else if(g_market.ltfBias == BIAS_BEARISH) biasSum -= 1;

   if(biasSum >= 2) g_market.overallBias = 1;
   else if(biasSum <= -2) g_market.overallBias = -1;
   else g_market.overallBias = 0;

   // Trending check
   g_market.isTrending = (g_market.htfBias != BIAS_NEUTRAL && g_market.mtfBias != BIAS_NEUTRAL);
}

//+------------------------------------------------------------------+
//| UPDATE POSITION TRACKER                                          |
//+------------------------------------------------------------------+
void UpdatePositionTracker() {
   g_positions.longCount = 0;
   g_positions.shortCount = 0;
   g_positions.totalPnL = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol && pos.Magic() == Magic) {
            if(pos.PositionType() == POSITION_TYPE_BUY) g_positions.longCount++;
            else g_positions.shortCount++;
            g_positions.totalPnL += pos.Profit();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CALCULATE RANGES                                                 |
//+------------------------------------------------------------------+
void CalculateRanges() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   // Asian range
   if(h >= AsianEnd && !g_asianRange.isValid) {
      CalcRange(g_asianRange, AsianStart, AsianEnd, 0);
   }

   // London range
   if(h >= LondonRangeEnd && !g_londonRange.isValid) {
      CalcRange(g_londonRange, LondonRangeStart, LondonRangeEnd, 1);
   }
}

void CalcRange(RangeData &range, int startH, int endH, int type) {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   dt.hour = startH; dt.min = 0; dt.sec = 0;
   datetime startTime = StructToTime(dt);

   dt.hour = endH;
   datetime endTime = StructToTime(dt);

   int startBar = iBarShift(_Symbol, PERIOD_M15, startTime);
   int endBar = iBarShift(_Symbol, PERIOD_M15, endTime);

   if(startBar <= 0 || endBar < 0) return;

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int count = startBar - endBar + 1;
   if(count <= 0) return;

   if(CopyHigh(_Symbol, PERIOD_M15, endBar, count, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, endBar, count, lows) <= 0) return;

   range.high = highs[ArrayMaximum(highs)];
   range.low = lows[ArrayMinimum(lows)];
   range.mid = (range.high + range.low) / 2;
   range.size = range.high - range.low;
   range.type = type;

   // Validate size
   double minSize = g_market.atr * 0.3;
   double maxSize = g_market.atr * 3.0;
   range.isValid = (range.size >= minSize && range.size <= maxSize);
}

//+------------------------------------------------------------------+
//| SCAN FOR SIGNALS                                                 |
//+------------------------------------------------------------------+
TradeSignal ScanForSignals() {
   TradeSignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Scan both ranges
   if(g_asianRange.isValid) {
      signal = CheckRangeSignals(g_asianRange, "Asian", bid, ask);
      if(signal.isValid && signal.score >= g_adaptive.currentMinScore) return signal;
   }

   if(g_londonRange.isValid) {
      signal = CheckRangeSignals(g_londonRange, "London", bid, ask);
      if(signal.isValid && signal.score >= g_adaptive.currentMinScore) return signal;
   }

   // Check momentum setup (no range needed)
   if(UseMomentum) {
      signal = CheckMomentumSignal(bid, ask);
      if(signal.isValid && signal.score >= g_adaptive.currentMinScore) return signal;
   }

   return signal;
}

//+------------------------------------------------------------------+
//| CHECK RANGE SIGNALS                                              |
//+------------------------------------------------------------------+
TradeSignal CheckRangeSignals(RangeData &range, string name, double bid, double ask) {
   TradeSignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   double buffer = g_market.atr * 0.1;

   // ===== 1. BREAKOUT =====
   if(UseBreakout) {
      // Bullish breakout
      if(bid > range.high + buffer && bid < range.high + range.size * 0.8) {
         if(g_market.overallBias >= 0) {  // Not against strong bear bias
            signal = BuildSignal(SETUP_BREAKOUT, 1, ask, range.low - buffer, name + " BO Long");
            if(signal.isValid) return signal;
         }
      }
      // Bearish breakout
      if(ask < range.low - buffer && ask > range.low - range.size * 0.8) {
         if(g_market.overallBias <= 0) {  // Not against strong bull bias
            signal = BuildSignal(SETUP_BREAKOUT, -1, bid, range.high + buffer, name + " BO Short");
            if(signal.isValid) return signal;
         }
      }
   }

   // ===== 2. RETEST =====
   if(UseRetest) {
      // Bullish retest (price came back to range high after breakout)
      if(bid >= range.high - range.size * 0.15 && bid <= range.high + buffer) {
         if(g_market.overallBias >= 0 && HasBullishCandle()) {
            signal = BuildSignal(SETUP_RETEST, 1, ask, range.mid - buffer, name + " Retest Long");
            if(signal.isValid) return signal;
         }
      }
      // Bearish retest
      if(ask <= range.low + range.size * 0.15 && ask >= range.low - buffer) {
         if(g_market.overallBias <= 0 && HasBearishCandle()) {
            signal = BuildSignal(SETUP_RETEST, -1, bid, range.mid + buffer, name + " Retest Short");
            if(signal.isValid) return signal;
         }
      }
   }

   // ===== 3. PULLBACK (Inside range, with trend) =====
   if(UsePullback) {
      // Bullish pullback at range low
      if(bid <= range.low + range.size * 0.25 && bid >= range.low - buffer) {
         if(g_market.overallBias == 1 && HasBullishCandle()) {
            signal = BuildSignal(SETUP_PULLBACK, 1, ask, range.low - g_market.atr * 0.3, name + " PB Long");
            if(signal.isValid) return signal;
         }
      }
      // Bearish pullback at range high
      if(ask >= range.high - range.size * 0.25 && ask <= range.high + buffer) {
         if(g_market.overallBias == -1 && HasBearishCandle()) {
            signal = BuildSignal(SETUP_PULLBACK, -1, bid, range.high + g_market.atr * 0.3, name + " PB Short");
            if(signal.isValid) return signal;
         }
      }
   }

   // ===== 4. REVERSAL (At extremes, counter-trend) =====
   if(UseReversal && g_adaptive.isAggressive) {
      // Only in aggressive mode, when RSI shows divergence
      if(bid <= range.low + buffer && g_market.rsi < RSI_Lower && HasBullishCandle()) {
         signal = BuildSignal(SETUP_REVERSAL, 1, ask, range.low - g_market.atr * 0.4, name + " Rev Long");
         if(signal.isValid) return signal;
      }
      if(ask >= range.high - buffer && g_market.rsi > RSI_Upper && HasBearishCandle()) {
         signal = BuildSignal(SETUP_REVERSAL, -1, bid, range.high + g_market.atr * 0.4, name + " Rev Short");
         if(signal.isValid) return signal;
      }
   }

   return signal;
}

//+------------------------------------------------------------------+
//| CHECK MOMENTUM SIGNAL                                            |
//+------------------------------------------------------------------+
TradeSignal CheckMomentumSignal(double bid, double ask) {
   TradeSignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   if(!g_market.isTrending) return signal;

   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyClose(_Symbol, TF_Entry, 0, 5, close);
   CopyHigh(_Symbol, TF_Entry, 0, 5, high);
   CopyLow(_Symbol, TF_Entry, 0, 5, low);

   // Strong momentum candle in direction of trend
   double body = MathAbs(close[1] - close[2]);

   // Bullish momentum
   if(g_market.overallBias == 1 && close[1] > close[2] && body > g_market.atr * 0.4) {
      if(g_market.rsi > 50 && g_market.rsi < RSI_Upper) {
         double sl = low[1] - g_market.atr * 0.2;
         signal = BuildSignal(SETUP_MOMENTUM, 1, ask, sl, "Momentum Long");
         if(signal.isValid) return signal;
      }
   }

   // Bearish momentum
   if(g_market.overallBias == -1 && close[1] < close[2] && body > g_market.atr * 0.4) {
      if(g_market.rsi < 50 && g_market.rsi > RSI_Lower) {
         double sl = high[1] + g_market.atr * 0.2;
         signal = BuildSignal(SETUP_MOMENTUM, -1, bid, sl, "Momentum Short");
         if(signal.isValid) return signal;
      }
   }

   return signal;
}

//+------------------------------------------------------------------+
//| BUILD SIGNAL                                                     |
//+------------------------------------------------------------------+
TradeSignal BuildSignal(ENUM_SETUP_TYPE type, int dir, double entry, double sl, string reason) {
   TradeSignal signal;
   ZeroMemory(signal);
   signal.type = type;
   signal.direction = dir;
   signal.entry = entry;
   signal.sl = sl;
   signal.reason = reason;
   signal.isValid = false;

   // Calculate TP
   double risk = MathAbs(entry - sl);
   signal.tp = (dir == 1) ? entry + risk * TP1_RR : entry - risk * TP1_RR;
   signal.rr = TP1_RR;

   // Check minimum RR
   if(signal.rr < MinRR) return signal;

   // Calculate score
   signal.score = CalculateScore(signal, dir);

   signal.isValid = true;
   return signal;
}

//+------------------------------------------------------------------+
//| CALCULATE SCORE                                                  |
//+------------------------------------------------------------------+
int CalculateScore(TradeSignal &signal, int dir) {
   int score = 0;

   // 1. Bias alignment (0-3 points)
   if(g_market.overallBias == dir) score += 2;
   else if(g_market.overallBias == 0) score += 1;
   // Against bias = 0 points

   // 2. HTF alignment (0-1 point)
   if((g_market.htfBias == BIAS_BULLISH && dir == 1) ||
      (g_market.htfBias == BIAS_BEARISH && dir == -1)) score += 1;

   // 3. RSI confirmation (0-2 points)
   if(RequireMomentumRSI) {
      if(dir == 1 && g_market.rsi > 45 && g_market.rsi < RSI_Upper) score += 1;
      if(dir == -1 && g_market.rsi < 55 && g_market.rsi > RSI_Lower) score += 1;

      // RSI momentum
      double rsi[];
      ArraySetAsSeries(rsi, true);
      CopyBuffer(g_rsiHandle, 0, 0, 3, rsi);
      if(dir == 1 && rsi[0] > rsi[1]) score += 1;
      if(dir == -1 && rsi[0] < rsi[1]) score += 1;
   } else {
      score += 1;  // Base point if not using RSI
   }

   // 4. Candle pattern (0-2 points)
   if(dir == 1 && HasBullishCandle()) score += 1;
   if(dir == -1 && HasBearishCandle()) score += 1;
   if(HasStrongPattern(dir)) score += 1;

   // 5. Setup type bonus
   if(signal.type == SETUP_RETEST) score += 1;
   if(signal.type == SETUP_PULLBACK && g_market.isTrending) score += 1;

   return score;
}

//+------------------------------------------------------------------+
//| CANDLE PATTERN HELPERS                                           |
//+------------------------------------------------------------------+
bool HasBullishCandle() {
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   CopyOpen(_Symbol, TF_Entry, 0, 3, open);
   CopyClose(_Symbol, TF_Entry, 0, 3, close);

   return (close[1] > open[1] && close[1] > close[2]);
}

bool HasBearishCandle() {
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   CopyOpen(_Symbol, TF_Entry, 0, 3, open);
   CopyClose(_Symbol, TF_Entry, 0, 3, close);

   return (close[1] < open[1] && close[1] < close[2]);
}

bool HasStrongPattern(int dir) {
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
   double body2 = MathAbs(close[2] - open[2]);

   // Engulfing
   if(dir == 1 && close[1] > open[1] && close[2] < open[2]) {
      if(body1 > body2 * 1.1) return true;
   }
   if(dir == -1 && close[1] < open[1] && close[2] > open[2]) {
      if(body1 > body2 * 1.1) return true;
   }

   // Pin bar
   double upperWick = high[1] - MathMax(close[1], open[1]);
   double lowerWick = MathMin(close[1], open[1]) - low[1];

   if(dir == 1 && lowerWick > body1 * 1.5) return true;
   if(dir == -1 && upperWick > body1 * 1.5) return true;

   return false;
}

//+------------------------------------------------------------------+
//| CAN TRADE                                                        |
//+------------------------------------------------------------------+
bool CanTrade() {
   // Target reached
   if(g_challenge.targetReached) return false;

   // DD limits
   if(-g_challenge.profitPercent >= MaxTotalDD) {
      CloseAllPositions("Max DD");
      return false;
   }
   if(-g_challenge.dailyProfit >= MaxDailyDD) {
      CloseAllPositions("Daily DD");
      return false;
   }

   // Daily trades limit
   if(g_positions.todayTrades >= g_adaptive.currentMaxTrades) return false;

   // Max open positions
   int totalOpen = g_positions.longCount + g_positions.shortCount;
   if(totalOpen >= MaxOpenTrades) return false;

   return true;
}

//+------------------------------------------------------------------+
//| IS DIRECTION ALLOWED                                             |
//+------------------------------------------------------------------+
bool IsDirectionAllowed(int dir) {
   if(AllowHedging) return true;

   // No positions - any direction allowed
   if(g_positions.longCount == 0 && g_positions.shortCount == 0) return true;

   // Check if same direction
   if(dir == 1 && g_positions.longCount > 0 && g_positions.shortCount == 0) return true;
   if(dir == -1 && g_positions.shortCount > 0 && g_positions.longCount == 0) return true;

   // Opposite direction - check if we should close loser first
   if(CloseLoserFirst && g_positions.totalPnL < 0) {
      CloseAllPositions("Close loser for direction change");
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| IS IN SESSION                                                    |
//+------------------------------------------------------------------+
bool IsInSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(TradeFrankfurt && h >= 6 && h < 8) return true;
   if(TradeLondon && h >= 8 && h < 12) return true;
   if(TradeNYOpen && h >= 13 && h < 17) return true;
   if(TradeLondonClose && h >= 15 && h < 17) return true;

   return false;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(TradeSignal &signal) {
   double lots = CalculateLots(signal.entry, signal.sl);
   if(lots <= 0) return;

   string comment = TradeComment + "_" + IntegerToString(signal.score);
   bool success = false;

   if(signal.direction == 1) {
      success = trade.Buy(lots, _Symbol, signal.entry, signal.sl, signal.tp, comment);
   } else {
      success = trade.Sell(lots, _Symbol, signal.entry, signal.sl, signal.tp, comment);
   }

   if(success) {
      g_positions.todayTrades++;
      Print("TRADE: ", signal.reason, " | Score: ", signal.score, " | Risk: ", DoubleToString(g_adaptive.currentRisk, 2), "%");
   }
}

//+------------------------------------------------------------------+
//| CALCULATE LOTS                                                   |
//+------------------------------------------------------------------+
double CalculateLots(double entry, double sl) {
   double balance = UseCompounding ? g_challenge.currentBalance : g_challenge.startBalance;
   double riskAmt = balance * (g_adaptive.currentRisk / 100);

   double slPips = MathAbs(entry - sl) / _Point / 10;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize == 0 || slPips == 0) return 0;

   double pipVal = tickVal * (_Point * 10 / tickSize);
   double lots = riskAmt / (slPips * pipVal);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / step) * step;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS                                                 |
//+------------------------------------------------------------------+
void ManagePositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != Magic) continue;

      ulong ticket = pos.Ticket();
      double entry = pos.PriceOpen();
      double sl = pos.StopLoss();
      double tp = pos.TakeProfit();
      double lots = pos.Volume();
      bool isLong = (pos.PositionType() == POSITION_TYPE_BUY);

      double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double priceDiff = isLong ? (price - entry) : (entry - price);
      double riskDist = MathAbs(entry - sl);
      double currentRR = (riskDist > 0) ? priceDiff / riskDist : 0;

      // Breakeven
      if(UseBreakeven && currentRR >= BE_Trigger) {
         double beLevel = isLong ? entry + g_market.atr * 0.05 : entry - g_market.atr * 0.05;
         bool needBE = isLong ? (sl < entry) : (sl > entry);
         if(needBE) {
            trade.PositionModify(ticket, beLevel, tp);
         }
      }

      // Partial close
      if(currentRR >= TP1_RR) {
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double closeSize = lots * (PartialPercent / 100);
         if(closeSize >= minLot && lots > minLot * 2) {
            closeSize = MathFloor(closeSize / minLot) * minLot;
            trade.PositionClosePartial(ticket, closeSize);
         }
      }

      // Trailing
      if(UseTrailing && currentRR >= TrailStart) {
         double trailDist = g_market.atr * TrailDistance;
         double newSL = isLong ? price - trailDist : price + trailDist;
         bool shouldTrail = isLong ? (newSL > sl) : (newSL < sl);
         if(shouldTrail) {
            trade.PositionModify(ticket, newSL, tp);
         }
      }
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
   Print("Closed all: ", reason);
}

//+------------------------------------------------------------------+
//| CHECK DAY RESET                                                  |
//+------------------------------------------------------------------+
void CheckDayReset() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(g_lastDay != dt.day) {
      if(g_lastDay != -1) {
         g_dayStartBalance = acc.Balance();
         g_positions.todayTrades = 0;
         g_positions.todayWins = 0;
         g_positions.todayLosses = 0;
         ZeroMemory(g_asianRange);
         ZeroMemory(g_londonRange);
      }
      g_lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| DISPLAY DASHBOARD                                                |
//+------------------------------------------------------------------+
void DisplayDashboard() {
   string s = "\n";
   s += "====== SESSION BREAKOUT V7 - ADAPTIVE ======\n\n";

   // Challenge Progress
   s += "-- CHALLENGE PROGRESS --\n";
   double pct = (g_challenge.profitPercent / ChallengeTarget) * 100;
   s += StringFormat("Progress: %.1f%% / %.1f%% (%.0f%% done)\n",
        g_challenge.profitPercent, ChallengeTarget, MathMin(100, pct));
   s += StringFormat("Balance: %.0f / %.0f\n",
        g_challenge.currentBalance, g_challenge.targetBalance);
   s += StringFormat("Days: %d/%d | Daily target: %.2f%%\n",
        g_challenge.daysElapsed, ChallengeDays, g_challenge.dailyTarget);

   // Progress bar
   int barLen = 20;
   int filled = (int)(MathMin(100, pct) / 100 * barLen);
   s += "[";
   for(int i = 0; i < barLen; i++) s += (i < filled) ? "=" : "-";
   s += "]\n\n";

   // Adaptive Mode
   s += "-- ADAPTIVE MODE --\n";
   s += "Mode: " + g_adaptive.modeDescription;
   if(g_challenge.behindSchedule > 0) s += StringFormat(" (%.1f%% behind)", g_challenge.behindSchedule);
   else s += StringFormat(" (%.1f%% ahead)", -g_challenge.behindSchedule);
   s += "\n";
   s += StringFormat("Min Score: %d | Risk: %.2f%% | Max Trades: %d\n\n",
        g_adaptive.currentMinScore, g_adaptive.currentRisk, g_adaptive.currentMaxTrades);

   // Market Context
   s += "-- MARKET --\n";
   s += "Bias: " + (g_market.overallBias == 1 ? "BULL" : (g_market.overallBias == -1 ? "BEAR" : "NEUTRAL"));
   s += " | RSI: " + DoubleToString(g_market.rsi, 0);
   s += " | Trend: " + (g_market.isTrending ? "YES" : "NO") + "\n";
   s += "Ranges: Asian=" + (g_asianRange.isValid ? "OK" : "--");
   s += " London=" + (g_londonRange.isValid ? "OK" : "--") + "\n\n";

   // Positions
   s += "-- TRADES --\n";
   s += StringFormat("Open: %dL/%dS | PnL: %.2f\n",
        g_positions.longCount, g_positions.shortCount, g_positions.totalPnL);
   s += StringFormat("Today: %d/%d trades | Daily: %.2f%%\n\n",
        g_positions.todayTrades, g_adaptive.currentMaxTrades, g_challenge.dailyProfit);

   // Current Signal
   s += "-- SIGNAL --\n";
   if(g_signal.isValid) {
      s += g_signal.reason + "\n";
      s += StringFormat("Score: %d/%d | RR: %.1f\n",
           g_signal.score, g_adaptive.currentMinScore, g_signal.rr);
   } else {
      s += "Scanning...\n";
   }
   s += "\nSession: " + (IsInSession() ? "ACTIVE" : "CLOSED") + "\n";
   s += "==========================================\n";

   Comment(s);
}
//+------------------------------------------------------------------+
