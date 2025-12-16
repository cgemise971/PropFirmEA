//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v2.mq5 |
//|                         DYNAMIC Asian Range Breakout Strategy    |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "2.00"
#property description "V2: Dynamic range, multiple sessions, adaptive filters"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_PROP_FIRM {
   PROP_FTMO_NORMAL,      // FTMO Normal
   PROP_FTMO_SWING,       // FTMO Swing
   PROP_E8_ONE,           // E8 Markets One Step
   PROP_FUNDING_PIPS,     // Funding Pips
   PROP_THE5ERS,          // The5ers
   PROP_CUSTOM            // Custom Settings
};

enum ENUM_TRADE_MODE {
   MODE_CHALLENGE,        // Challenge Mode (Aggressive)
   MODE_FUNDED            // Funded Mode (Conservative)
};

enum ENUM_RANGE_MODE {
   RANGE_FIXED,           // Fixed Hours (Classic)
   RANGE_DYNAMIC,         // Dynamic (ATR-based)
   RANGE_LOWEST_VOL       // Lowest Volatility Period
};

enum ENUM_ENTRY_MODE {
   ENTRY_BREAKOUT,        // Breakout Only
   ENTRY_PULLBACK,        // Pullback Only (Better RR)
   ENTRY_BOTH             // Both (More Trades)
};

//+------------------------------------------------------------------+
//| Input Parameters - Prop Firm                                     |
//+------------------------------------------------------------------+
input group "========== PROP FIRM =========="
input ENUM_PROP_FIRM PropFirmProfile = PROP_FTMO_NORMAL;  // Prop Firm
input ENUM_TRADE_MODE TradeMode = MODE_CHALLENGE;          // Mode

//+------------------------------------------------------------------+
//| Input Parameters - Risk                                          |
//+------------------------------------------------------------------+
input group "========== RISK MANAGEMENT =========="
input double RiskPercent = 1.5;              // Risk Per Trade (%)
input double MaxDailyDD = 4.5;               // Max Daily DD (%)
input double MaxTotalDD = 9.0;               // Max Total DD (%)
input int MaxTradesPerDay = 5;               // Max Trades/Day
input int MaxOpenTrades = 2;                 // Max Open Trades

//+------------------------------------------------------------------+
//| Input Parameters - Range Settings (DYNAMIC)                      |
//+------------------------------------------------------------------+
input group "========== RANGE SETTINGS =========="
input ENUM_RANGE_MODE RangeMode = RANGE_DYNAMIC;  // Range Calculation Mode
input int AsianStartHour = 0;                // Fixed: Start Hour (UTC)
input int AsianEndHour = 6;                  // Fixed: End Hour (UTC)
input int RangeLookbackBars = 24;            // Dynamic: Lookback Bars (H1)
input double RangeATRMultMin = 0.5;          // Min Range = ATR × this
input double RangeATRMultMax = 3.0;          // Max Range = ATR × this
input bool AutoAdjustRange = true;           // Auto-adjust range to volatility

//+------------------------------------------------------------------+
//| Input Parameters - Entry                                         |
//+------------------------------------------------------------------+
input group "========== ENTRY SETTINGS =========="
input ENUM_ENTRY_MODE EntryMode = ENTRY_BOTH;     // Entry Mode
input double BreakoutBuffer = 2.0;                // Breakout buffer (pips)
input double PullbackPercent = 50.0;              // Pullback entry (% into range)
input int PullbackWaitBars = 6;                   // Max bars to wait for pullback
input double MomentumMinPercent = 30.0;           // Min candle size (% of range)
input bool UseHTFFilter = true;                   // Use HTF Trend Filter
input ENUM_TIMEFRAMES HTF = PERIOD_H1;            // HTF (H1 more reactive than H4)
input int EMAPeriod = 50;                         // EMA Period for trend

//+------------------------------------------------------------------+
//| Input Parameters - Sessions                                      |
//+------------------------------------------------------------------+
input group "========== TRADING SESSIONS =========="
input bool TradeFrankfurt = true;            // Frankfurt Open (06:00-07:00)
input bool TradeLondon = true;               // London Session (07:00-11:00)
input bool TradeNYOpen = true;               // NY Open (12:00-16:00)
input bool TradeLondonClose = true;          // London Close (15:00-17:00)
input bool TradeAsianBreak = false;          // Asian Breakout (23:00-02:00)

//+------------------------------------------------------------------+
//| Input Parameters - Take Profit                                   |
//+------------------------------------------------------------------+
input group "========== TAKE PROFIT =========="
input double TP1_RR = 1.0;                   // TP1 Risk:Reward
input double TP1_Percent = 50.0;             // TP1 Close % position
input double TP2_RR = 2.0;                   // TP2 Risk:Reward
input double TP2_Percent = 30.0;             // TP2 Close %
input bool UseTrailing = true;               // Use Trailing for remainder
input double TrailingATRMult = 1.0;          // Trailing = ATR × this

//+------------------------------------------------------------------+
//| Input Parameters - Filters                                       |
//+------------------------------------------------------------------+
input group "========== FILTERS =========="
input bool UseSpreadFilter = true;           // Spread Filter
input double MaxSpreadPips = 2.0;            // Max Spread (pips)
input bool UseNewsFilter = true;             // News Filter
input int NewsMinutes = 15;                  // Minutes around news
input bool CloseWeekend = true;              // Close Friday
input int FridayCloseHour = 20;              // Friday close (UTC)
input bool RequireHTFAlignment = false;      // Require HTF trend (strict)

//+------------------------------------------------------------------+
//| Input Parameters - EA                                            |
//+------------------------------------------------------------------+
input group "========== EA SETTINGS =========="
input int MagicNumber = 234567;              // Magic Number
input string TradeComment = "SBv2";          // Comment
input bool ShowDashboard = true;             // Dashboard
input bool DrawRange = true;                 // Draw Range on Chart
input color RangeColor = clrDodgerBlue;      // Range Color
input color BullColor = clrLime;             // Bullish Arrow
input color BearColor = clrRed;              // Bearish Arrow

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct DynamicRange {
   double high;
   double low;
   double size;
   double sizePips;
   datetime startTime;
   datetime endTime;
   bool isValid;
   bool isCalculated;
   bool breakoutUp;
   bool breakoutDown;
   bool pullbackEntryPending;
   int pullbackDirection;      // 1=Long, -1=Short
   int pullbackBarsWaited;
   double pullbackEntryPrice;
};

struct TradeStats {
   int tradesToday;
   double dailyPnL;
   double totalDD;
   double startBalance;
   double dayStartBalance;
   bool dailyLimitHit;
   bool ddLimitHit;
};

struct PropSettings {
   double maxDailyDD;
   double maxTotalDD;
   double riskPct;
   bool newsFilter;
   bool weekendClose;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo posInfo;
CAccountInfo accInfo;

DynamicRange g_range;
TradeStats g_stats;
PropSettings g_prop;

int g_atrHandle;
int g_emaHandle;
datetime g_lastBar;
datetime g_lastRangeDate;
double g_currentATR;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(15);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_stats.startBalance = accInfo.Balance();
   g_stats.dayStartBalance = g_stats.startBalance;
   g_stats.tradesToday = 0;
   g_stats.dailyLimitHit = false;
   g_stats.ddLimitHit = false;

   LoadPropProfile();

   g_atrHandle = iATR(_Symbol, PERIOD_H1, 14);
   if(g_atrHandle == INVALID_HANDLE) {
      Print("ATR indicator failed");
      return INIT_FAILED;
   }

   g_emaHandle = iMA(_Symbol, HTF, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_emaHandle == INVALID_HANDLE) {
      Print("EMA indicator failed");
      return INIT_FAILED;
   }

   ResetRange();

   Print("Session Breakout V2 initialized - ", EnumToString(RangeMode));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaHandle != INVALID_HANDLE) IndicatorRelease(g_emaHandle);
   ObjectsDeleteAll(0, "SB_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   datetime barTime = iTime(_Symbol, PERIOD_M15, 0);
   bool newBar = (barTime != g_lastBar);

   CheckDayReset();
   UpdateATR();

   if(!PassRiskChecks()) {
      if(ShowDashboard) UpdateDashboard();
      return;
   }

   // Calculate range when needed
   CalculateRangeIfNeeded();

   if(newBar) {
      g_lastBar = barTime;

      if(g_range.isValid && IsInTradingSession()) {
         // Check for breakout
         if(!g_range.breakoutUp && !g_range.breakoutDown) {
            CheckBreakout();
         }

         // Check for pullback entry
         if(g_range.pullbackEntryPending && EntryMode != ENTRY_BREAKOUT) {
            CheckPullbackEntry();
         }
      }

      ManagePositions();
   }

   if(DrawRange && g_range.isCalculated) DrawRangeOnChart();
   if(ShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Load Prop Firm Profile                                           |
//+------------------------------------------------------------------+
void LoadPropProfile() {
   switch(PropFirmProfile) {
      case PROP_FTMO_NORMAL:
         g_prop.maxDailyDD = 4.5;
         g_prop.maxTotalDD = 9.0;
         g_prop.riskPct = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_prop.newsFilter = true;
         g_prop.weekendClose = true;
         break;
      case PROP_FTMO_SWING:
         g_prop.maxDailyDD = 4.5;
         g_prop.maxTotalDD = 9.0;
         g_prop.riskPct = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_prop.newsFilter = false;
         g_prop.weekendClose = false;
         break;
      case PROP_E8_ONE:
         g_prop.maxDailyDD = 4.5;
         g_prop.maxTotalDD = 5.5;
         g_prop.riskPct = (TradeMode == MODE_CHALLENGE) ? 1.2 : 0.6;
         g_prop.newsFilter = false;
         g_prop.weekendClose = false;
         break;
      case PROP_FUNDING_PIPS:
         g_prop.maxDailyDD = 3.5;
         g_prop.maxTotalDD = 5.5;
         g_prop.riskPct = (TradeMode == MODE_CHALLENGE) ? 1.0 : 0.5;
         g_prop.newsFilter = true;
         g_prop.weekendClose = false;
         break;
      case PROP_THE5ERS:
         g_prop.maxDailyDD = 3.0;
         g_prop.maxTotalDD = 4.5;
         g_prop.riskPct = (TradeMode == MODE_CHALLENGE) ? 0.8 : 0.4;
         g_prop.newsFilter = false;
         g_prop.weekendClose = false;
         break;
      default:
         g_prop.maxDailyDD = MaxDailyDD;
         g_prop.maxTotalDD = MaxTotalDD;
         g_prop.riskPct = RiskPercent;
         g_prop.newsFilter = UseNewsFilter;
         g_prop.weekendClose = CloseWeekend;
   }
}

//+------------------------------------------------------------------+
//| Reset Range                                                       |
//+------------------------------------------------------------------+
void ResetRange() {
   g_range.high = 0;
   g_range.low = DBL_MAX;
   g_range.size = 0;
   g_range.sizePips = 0;
   g_range.isValid = false;
   g_range.isCalculated = false;
   g_range.breakoutUp = false;
   g_range.breakoutDown = false;
   g_range.pullbackEntryPending = false;
   g_range.pullbackDirection = 0;
   g_range.pullbackBarsWaited = 0;
}

//+------------------------------------------------------------------+
//| Update ATR                                                        |
//+------------------------------------------------------------------+
void UpdateATR() {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0) {
      g_currentATR = atr[0];
   }
}

//+------------------------------------------------------------------+
//| Calculate Range If Needed                                         |
//+------------------------------------------------------------------+
void CalculateRangeIfNeeded() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                 IntegerToString(dt.mon) + "." +
                                 IntegerToString(dt.day));

   // Reset for new day
   if(today != g_lastRangeDate) {
      ResetRange();
      g_lastRangeDate = today;
   }

   // Calculate based on mode
   if(!g_range.isCalculated) {
      if(RangeMode == RANGE_FIXED) {
         if(dt.hour >= AsianEndHour) {
            CalculateFixedRange();
         }
      }
      else if(RangeMode == RANGE_DYNAMIC) {
         CalculateDynamicRange();
      }
      else {
         CalculateLowestVolRange();
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Fixed Range (Classic Asian)                             |
//+------------------------------------------------------------------+
void CalculateFixedRange() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   dt.hour = AsianStartHour;
   dt.min = 0;
   dt.sec = 0;
   datetime startTime = StructToTime(dt);

   dt.hour = AsianEndHour;
   datetime endTime = StructToTime(dt);

   int startBar = iBarShift(_Symbol, PERIOD_M15, startTime);
   int endBar = iBarShift(_Symbol, PERIOD_M15, endTime);

   if(startBar <= 0 || endBar < 0) return;

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int count = startBar - endBar + 1;
   if(CopyHigh(_Symbol, PERIOD_M15, endBar, count, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, endBar, count, lows) <= 0) return;

   g_range.high = highs[ArrayMaximum(highs)];
   g_range.low = lows[ArrayMinimum(lows)];
   g_range.startTime = startTime;
   g_range.endTime = endTime;

   FinalizeRange();
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Range (ATR-based)                               |
//+------------------------------------------------------------------+
void CalculateDynamicRange() {
   // Find the lowest volatility period in the last X hours
   double highs[], lows[], atrVals[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(atrVals, true);

   int bars = RangeLookbackBars;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, bars, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_H1, 0, bars, lows) <= 0) return;
   if(CopyBuffer(g_atrHandle, 0, 0, bars, atrVals) <= 0) return;

   // Find consolidation zone (lowest range period)
   double minRange = DBL_MAX;
   int bestStart = -1;
   int windowSize = 6;  // 6 hours window

   for(int i = windowSize; i < bars - windowSize; i++) {
      double windowHigh = highs[ArrayMaximum(highs, i, windowSize)];
      double windowLow = lows[ArrayMinimum(lows, i, windowSize)];
      double windowRange = windowHigh - windowLow;

      if(windowRange < minRange && windowRange > 0) {
         minRange = windowRange;
         bestStart = i;
         g_range.high = windowHigh;
         g_range.low = windowLow;
      }
   }

   if(bestStart < 0) return;

   g_range.startTime = iTime(_Symbol, PERIOD_H1, bestStart + windowSize);
   g_range.endTime = iTime(_Symbol, PERIOD_H1, bestStart);

   FinalizeRange();
}

//+------------------------------------------------------------------+
//| Calculate Lowest Volatility Range                                 |
//+------------------------------------------------------------------+
void CalculateLowestVolRange() {
   // Use recent consolidation
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyHigh(_Symbol, PERIOD_H1, 1, 8, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_H1, 1, 8, lows) <= 0) return;

   g_range.high = highs[ArrayMaximum(highs)];
   g_range.low = lows[ArrayMinimum(lows)];
   g_range.startTime = iTime(_Symbol, PERIOD_H1, 8);
   g_range.endTime = iTime(_Symbol, PERIOD_H1, 1);

   FinalizeRange();
}

//+------------------------------------------------------------------+
//| Finalize Range Calculation                                        |
//+------------------------------------------------------------------+
void FinalizeRange() {
   g_range.size = g_range.high - g_range.low;
   g_range.sizePips = g_range.size / _Point / 10;
   g_range.isCalculated = true;

   // Dynamic validation based on ATR
   double minSize = g_currentATR * RangeATRMultMin;
   double maxSize = g_currentATR * RangeATRMultMax;

   if(g_range.size >= minSize && g_range.size <= maxSize) {
      g_range.isValid = true;
      Print("Range Valid: ", g_range.sizePips, " pips (ATR=", g_currentATR/_Point/10, ")");
   }
   else {
      // Auto-adjust if enabled
      if(AutoAdjustRange && g_range.size < minSize) {
         // Expand range slightly
         double expand = (minSize - g_range.size) / 2;
         g_range.high += expand;
         g_range.low -= expand;
         g_range.size = g_range.high - g_range.low;
         g_range.sizePips = g_range.size / _Point / 10;
         g_range.isValid = true;
         Print("Range Auto-Adjusted: ", g_range.sizePips, " pips");
      }
      else {
         g_range.isValid = false;
         Print("Range Invalid: ", g_range.sizePips, " pips (need ", minSize/_Point/10, "-", maxSize/_Point/10, ")");
      }
   }
}

//+------------------------------------------------------------------+
//| Check if in Trading Session                                       |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(TradeFrankfurt && h >= 6 && h < 7) return true;
   if(TradeLondon && h >= 7 && h < 11) return true;
   if(TradeNYOpen && h >= 12 && h < 16) return true;
   if(TradeLondonClose && h >= 15 && h < 17) return true;
   if(TradeAsianBreak && (h >= 23 || h < 2)) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check Breakout                                                    |
//+------------------------------------------------------------------+
void CheckBreakout() {
   double close[], open[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyClose(_Symbol, PERIOD_M15, 0, 3, close) <= 0) return;
   if(CopyOpen(_Symbol, PERIOD_M15, 0, 3, open) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_M15, 0, 3, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, 0, 3, low) <= 0) return;

   double buffer = BreakoutBuffer * 10 * _Point;
   double candleSize = MathAbs(close[1] - open[1]);
   double minCandle = g_range.size * (MomentumMinPercent / 100);

   // BULLISH BREAKOUT
   if(close[1] > g_range.high + buffer) {
      if(candleSize >= minCandle || !RequireHTFAlignment) {
         if(CheckHTFTrend(true) || !RequireHTFAlignment) {
            if(CheckFilters()) {
               g_range.breakoutUp = true;

               if(EntryMode == ENTRY_BREAKOUT || EntryMode == ENTRY_BOTH) {
                  ExecuteTrade(true, "Breakout");
               }

               if(EntryMode == ENTRY_PULLBACK || EntryMode == ENTRY_BOTH) {
                  g_range.pullbackEntryPending = true;
                  g_range.pullbackDirection = 1;
                  g_range.pullbackBarsWaited = 0;
                  g_range.pullbackEntryPrice = g_range.high + (g_range.size * PullbackPercent / 100);
               }
            }
         }
      }
   }

   // BEARISH BREAKOUT
   if(close[1] < g_range.low - buffer) {
      if(candleSize >= minCandle || !RequireHTFAlignment) {
         if(CheckHTFTrend(false) || !RequireHTFAlignment) {
            if(CheckFilters()) {
               g_range.breakoutDown = true;

               if(EntryMode == ENTRY_BREAKOUT || EntryMode == ENTRY_BOTH) {
                  ExecuteTrade(false, "Breakout");
               }

               if(EntryMode == ENTRY_PULLBACK || EntryMode == ENTRY_BOTH) {
                  g_range.pullbackEntryPending = true;
                  g_range.pullbackDirection = -1;
                  g_range.pullbackBarsWaited = 0;
                  g_range.pullbackEntryPrice = g_range.low - (g_range.size * PullbackPercent / 100);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Pullback Entry                                              |
//+------------------------------------------------------------------+
void CheckPullbackEntry() {
   g_range.pullbackBarsWaited++;

   if(g_range.pullbackBarsWaited > PullbackWaitBars) {
      g_range.pullbackEntryPending = false;
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Long pullback
   if(g_range.pullbackDirection == 1) {
      if(bid <= g_range.high && bid >= g_range.pullbackEntryPrice) {
         if(CheckFilters()) {
            ExecuteTrade(true, "Pullback");
            g_range.pullbackEntryPending = false;
         }
      }
   }

   // Short pullback
   if(g_range.pullbackDirection == -1) {
      if(ask >= g_range.low && ask <= g_range.pullbackEntryPrice) {
         if(CheckFilters()) {
            ExecuteTrade(false, "Pullback");
            g_range.pullbackEntryPending = false;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check HTF Trend                                                   |
//+------------------------------------------------------------------+
bool CheckHTFTrend(bool isLong) {
   if(!UseHTFFilter) return true;

   double ema[], close[];
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(close, true);

   if(CopyBuffer(g_emaHandle, 0, 0, 1, ema) <= 0) return true;
   if(CopyClose(_Symbol, HTF, 0, 1, close) <= 0) return true;

   if(isLong) return close[0] > ema[0];
   return close[0] < ema[0];
}

//+------------------------------------------------------------------+
//| Check Filters                                                     |
//+------------------------------------------------------------------+
bool CheckFilters() {
   // Spread
   if(UseSpreadFilter) {
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / 10.0;
      if(spread > MaxSpreadPips) return false;
   }

   // News (simplified)
   if(g_prop.newsFilter) {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      // NFP check
      if(dt.day_of_week == 5 && dt.day <= 7 && dt.hour == 13) return false;
   }

   // Weekend
   if(g_prop.weekendClose) {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      if(dt.day_of_week == 5 && dt.hour >= FridayCloseHour) return false;
   }

   // Max trades
   if(g_stats.tradesToday >= MaxTradesPerDay) return false;
   if(CountPositions() >= MaxOpenTrades) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(bool isLong, string setup) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid);

   double entry, sl, tp1;
   double buffer = (5 * _Point * 10) + spread;

   if(isLong) {
      entry = ask;
      sl = g_range.low - buffer;
      double risk = entry - sl;
      tp1 = entry + (risk * TP1_RR);
   }
   else {
      entry = bid;
      sl = g_range.high + buffer;
      double risk = sl - entry;
      tp1 = entry - (risk * TP1_RR);
   }

   double lots = CalculateLots(entry, sl);
   if(lots <= 0) return;

   string comment = TradeComment + "_" + setup;
   bool success = false;

   if(isLong) {
      success = trade.Buy(lots, _Symbol, entry, sl, tp1, comment);
   }
   else {
      success = trade.Sell(lots, _Symbol, entry, sl, tp1, comment);
   }

   if(success) {
      g_stats.tradesToday++;
      Print("TRADE: ", (isLong ? "BUY" : "SELL"), " ", lots, " @ ", entry,
            " SL=", sl, " TP=", tp1, " [", setup, "]");

      if(DrawRange) {
         string name = "SB_Arrow_" + TimeToString(TimeCurrent());
         ObjectCreate(0, name, isLong ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, TimeCurrent(), entry);
         ObjectSetInteger(0, name, OBJPROP_COLOR, isLong ? BullColor : BearColor);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLots(double entry, double sl) {
   double riskAmt = accInfo.Balance() * (g_prop.riskPct / 100);
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
//| Manage Positions                                                  |
//+------------------------------------------------------------------+
void ManagePositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      if(posInfo.Magic() != MagicNumber) continue;

      if(UseTrailing && posInfo.Profit() > 0) {
         ApplyTrailing(posInfo.Ticket(), posInfo.PriceOpen(),
                       posInfo.StopLoss(), posInfo.TakeProfit(),
                       posInfo.PositionType() == POSITION_TYPE_BUY);
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                               |
//+------------------------------------------------------------------+
void ApplyTrailing(ulong ticket, double open, double sl, double tp, bool isLong) {
   double trail = g_currentATR * TrailingATRMult;
   double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(isLong) {
      if(price - open < trail) return;
      double newSL = price - trail;
      if(newSL > sl && newSL > open) {
         trade.PositionModify(ticket, newSL, tp);
      }
   }
   else {
      if(open - price < trail) return;
      double newSL = price + trail;
      if(newSL < sl && newSL < open) {
         trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Count Positions                                                   |
//+------------------------------------------------------------------+
int CountPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(posInfo.SelectByIndex(i)) {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == MagicNumber) count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check Day Reset                                                   |
//+------------------------------------------------------------------+
void CheckDayReset() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   static int lastDay = -1;

   if(lastDay != dt.day) {
      if(lastDay != -1) {
         g_stats.dayStartBalance = accInfo.Balance();
         g_stats.dailyPnL = 0;
         g_stats.tradesToday = 0;
         g_stats.dailyLimitHit = false;
      }
      lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| Pass Risk Checks                                                  |
//+------------------------------------------------------------------+
bool PassRiskChecks() {
   double equity = accInfo.Equity();
   g_stats.dailyPnL = ((equity - g_stats.dayStartBalance) / g_stats.dayStartBalance) * 100;
   g_stats.totalDD = ((g_stats.startBalance - equity) / g_stats.startBalance) * 100;

   if(g_stats.dailyPnL <= -g_prop.maxDailyDD) {
      if(!g_stats.dailyLimitHit) {
         Print("DAILY DD LIMIT HIT: ", g_stats.dailyPnL, "%");
         g_stats.dailyLimitHit = true;
         CloseAll("Daily DD");
      }
      return false;
   }

   if(g_stats.totalDD >= g_prop.maxTotalDD) {
      if(!g_stats.ddLimitHit) {
         Print("TOTAL DD LIMIT HIT: ", g_stats.totalDD, "%");
         g_stats.ddLimitHit = true;
         CloseAll("Total DD");
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Close All                                                         |
//+------------------------------------------------------------------+
void CloseAll(string reason) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(posInfo.SelectByIndex(i)) {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == MagicNumber) {
            trade.PositionClose(posInfo.Ticket());
         }
      }
   }
   Print("Closed all: ", reason);
}

//+------------------------------------------------------------------+
//| Draw Range on Chart                                               |
//+------------------------------------------------------------------+
void DrawRangeOnChart() {
   string boxName = "SB_Range";
   ObjectDelete(0, boxName);

   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H4);
   ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, g_range.startTime, g_range.high, endTime, g_range.low);
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, RangeColor);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);

   string highLine = "SB_High";
   ObjectDelete(0, highLine);
   ObjectCreate(0, highLine, OBJ_HLINE, 0, 0, g_range.high);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, RangeColor);
   ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_DOT);

   string lowLine = "SB_Low";
   ObjectDelete(0, lowLine);
   ObjectCreate(0, lowLine, OBJ_HLINE, 0, 0, g_range.low);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, RangeColor);
   ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard() {
   string s = "";
   s += "═══════════════════════════════════════\n";
   s += "   SESSION BREAKOUT V2 - " + EnumToString(RangeMode) + "\n";
   s += "═══════════════════════════════════════\n";
   s += "Profile: " + EnumToString(PropFirmProfile) + "\n";
   s += "───────────────────────────────────────\n";
   s += "         RANGE (" + (g_range.isValid ? "VALID" : "INVALID") + ")\n";
   s += "───────────────────────────────────────\n";
   s += StringFormat("High: %.5f | Low: %.5f\n", g_range.high, g_range.low);
   s += StringFormat("Size: %.1f pips | ATR: %.1f pips\n", g_range.sizePips, g_currentATR/_Point/10);
   s += "Breakout: " + (g_range.breakoutUp ? "UP" : (g_range.breakoutDown ? "DOWN" : "NONE")) + "\n";
   if(g_range.pullbackEntryPending) {
      s += "Pullback Pending: " + (g_range.pullbackDirection > 0 ? "LONG" : "SHORT") + "\n";
   }
   s += "───────────────────────────────────────\n";
   s += "         RISK STATUS\n";
   s += "───────────────────────────────────────\n";
   s += StringFormat("Daily: %.2f%% / -%.2f%%\n", g_stats.dailyPnL, g_prop.maxDailyDD);
   s += StringFormat("Total DD: %.2f%% / %.2f%%\n", g_stats.totalDD, g_prop.maxTotalDD);
   s += StringFormat("Trades: %d/%d | Open: %d/%d\n", g_stats.tradesToday, MaxTradesPerDay, CountPositions(), MaxOpenTrades);
   s += "───────────────────────────────────────\n";
   s += "Session: " + (IsInTradingSession() ? "ACTIVE" : "WAITING") + "\n";
   s += "═══════════════════════════════════════\n";

   Comment(s);
}
//+------------------------------------------------------------------+
