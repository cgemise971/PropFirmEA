//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v1.mq5 |
//|                                    Asian Range Breakout Strategy |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "1.00"
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
   PROP_E8_CLASSIC,       // E8 Markets Classic
   PROP_FUNDING_PIPS_1,   // Funding Pips 1-Step
   PROP_FUNDING_PIPS_2,   // Funding Pips 2-Step
   PROP_THE5ERS_BOOT,     // The5ers Bootcamp
   PROP_THE5ERS_HS,       // The5ers High Stakes
   PROP_CUSTOM            // Custom Settings
};

enum ENUM_TRADE_MODE {
   MODE_CHALLENGE,        // Challenge Mode (Aggressive)
   MODE_FUNDED            // Funded Mode (Conservative)
};

enum ENUM_ENTRY_TYPE {
   ENTRY_BREAKOUT,        // Breakout Entry
   ENTRY_PULLBACK,        // Pullback Entry (Better RR)
   ENTRY_BOTH             // Both Methods
};

//+------------------------------------------------------------------+
//| Input Parameters - Prop Firm Selection                           |
//+------------------------------------------------------------------+
input group "========== PROP FIRM SETTINGS =========="
input ENUM_PROP_FIRM PropFirmProfile = PROP_FTMO_NORMAL;  // Prop Firm Profile
input ENUM_TRADE_MODE TradeMode = MODE_CHALLENGE;          // Trading Mode

//+------------------------------------------------------------------+
//| Input Parameters - Risk Management                               |
//+------------------------------------------------------------------+
input group "========== RISK MANAGEMENT =========="
input double RiskPercent = 1.5;              // Risk Per Trade (%)
input double MaxDailyDD = 4.5;               // Max Daily Drawdown (%)
input double MaxTotalDD = 9.0;               // Max Total Drawdown (%)
input int MaxTradesPerDay = 3;               // Max Trades Per Day
input int MaxOpenTrades = 1;                 // Max Simultaneous Trades
input double MaxSLPercent = 1.8;             // Max SL as % of Capital

//+------------------------------------------------------------------+
//| Input Parameters - Asian Range Settings                          |
//+------------------------------------------------------------------+
input group "========== ASIAN RANGE SETTINGS =========="
input int AsianStartHour = 0;                // Asian Start Hour (UTC)
input int AsianEndHour = 6;                  // Asian End Hour (UTC)
input double MinRangePips = 15;              // Minimum Range Size (pips)
input double MaxRangePips = 60;              // Maximum Range Size (pips)
input double RangeATRMin = 0.3;              // Min Range as ATR multiple
input double RangeATRMax = 2.0;              // Max Range as ATR multiple

//+------------------------------------------------------------------+
//| Input Parameters - Breakout Settings                             |
//+------------------------------------------------------------------+
input group "========== BREAKOUT SETTINGS =========="
input ENUM_ENTRY_TYPE EntryType = ENTRY_BREAKOUT;  // Entry Type
input double BreakoutBuffer = 3.0;           // Buffer above/below range (pips)
input double MomentumMinPercent = 50;        // Min candle size (% of range)
input bool RequireCloseOutside = true;       // Require candle close outside
input bool UseHTFFilter = true;              // Use HTF Trend Filter
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H4;  // Higher Timeframe
input int EMA_Fast = 50;                     // Fast EMA Period
input int EMA_Slow = 200;                    // Slow EMA Period

//+------------------------------------------------------------------+
//| Input Parameters - Take Profit                                   |
//+------------------------------------------------------------------+
input group "========== TAKE PROFIT SETTINGS =========="
input double TP1_RR = 1.0;                   // TP1 Risk:Reward Ratio
input double TP1_Percent = 40;               // TP1 Position % to close
input double TP2_RangeMultiple = 1.5;        // TP2 as multiple of range
input double TP2_Percent = 30;               // TP2 Position % to close
input bool UseTrailingStop = true;           // Use Trailing Stop for TP3
input double TrailingATRMultiplier = 1.5;    // Trailing ATR Multiplier

//+------------------------------------------------------------------+
//| Input Parameters - Filters                                       |
//+------------------------------------------------------------------+
input group "========== FILTERS =========="
input bool UseSpreadFilter = true;           // Use Spread Filter
input double MaxSpreadPips = 1.5;            // Max Spread (pips)
input bool TradeLondonOpen = true;           // Trade London Open (07:00-10:00)
input bool TradeNYOpen = true;               // Trade NY Open (12:00-15:00)
input bool UseNewsFilter = true;             // Use News Filter
input int NewsFilterMinutes = 30;            // Minutes around high-impact news
input bool CloseBeforeWeekend = true;        // Close positions before weekend
input int FridayCloseHour = 20;              // Friday close hour (UTC)

//+------------------------------------------------------------------+
//| Input Parameters - EA Settings                                   |
//+------------------------------------------------------------------+
input group "========== EA SETTINGS =========="
input int MagicNumber = 234567;              // Magic Number
input string TradeComment = "SB_PropFirm";   // Trade Comment
input bool ShowDashboard = true;             // Show Dashboard
input bool DrawRangeOnChart = true;          // Draw Asian Range on Chart
input color RangeColor = clrDodgerBlue;      // Range Rectangle Color
input color BreakoutColor = clrLime;         // Breakout Arrow Color

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct AsianRange {
   double high;
   double low;
   double midpoint;
   double size;           // In points
   double sizePips;       // In pips
   datetime startTime;
   datetime endTime;
   bool isValid;
   bool isCalculated;
   bool breakoutOccurred;
   int breakoutDirection; // 1 = Long, -1 = Short, 0 = None
};

struct TradeStats {
   int tradesToday;
   double dailyPnL;
   double totalDD;
   double startingBalance;
   double dailyStartBalance;
   datetime lastTradeTime;
   bool dailyLimitReached;
   bool ddLimitReached;
};

struct PropFirmSettings {
   double maxDailyDD;
   double maxTotalDD;
   double riskPercent;
   bool newsFilter;
   bool weekendClose;
   double maxSLPercent;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo positionInfo;
CAccountInfo accountInfo;

AsianRange g_asianRange;
TradeStats g_stats;
PropFirmSettings g_propSettings;

int g_atrHandle;
int g_emaFastHandle;
int g_emaSlowHandle;

double g_initialBalance;
datetime g_lastBarTime;
datetime g_lastRangeDate;
bool g_tradeTakenToday;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Store initial balance
   g_initialBalance = accountInfo.Balance();
   g_stats.startingBalance = g_initialBalance;
   g_stats.dailyStartBalance = g_initialBalance;
   g_stats.tradesToday = 0;
   g_stats.dailyPnL = 0;
   g_stats.dailyLimitReached = false;
   g_stats.ddLimitReached = false;
   g_tradeTakenToday = false;

   // Load prop firm profile
   LoadPropFirmProfile();

   // Initialize indicators
   g_atrHandle = iATR(_Symbol, PERIOD_H1, 14);
   if(g_atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR indicator");
      return INIT_FAILED;
   }

   if(UseHTFFilter) {
      g_emaFastHandle = iMA(_Symbol, HTF_Timeframe, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowHandle = iMA(_Symbol, HTF_Timeframe, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

      if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE) {
         Print("Error creating EMA indicators");
         return INIT_FAILED;
      }
   }

   // Initialize range
   ResetAsianRange();

   Print("PropFirm Session Breakout EA initialized");
   Print("Mode: ", EnumToString(TradeMode));
   Print("Profile: ", EnumToString(PropFirmProfile));
   Print("Asian Range: ", AsianStartHour, ":00 - ", AsianEndHour, ":00 UTC");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);

   // Clean up chart objects
   ObjectsDeleteAll(0, "AsianRange_");

   Comment("");
   Print("PropFirm Session Breakout EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);
   bool newBar = (currentBarTime != g_lastBarTime);

   // Update daily stats at day change
   CheckDayChange();

   // Risk Management Checks
   if(!PassRiskChecks()) {
      if(ShowDashboard) UpdateDashboard();
      return;
   }

   // Calculate Asian Range after Asian session ends
   CalculateAsianRangeIfNeeded();

   // Process on new bar
   if(newBar) {
      g_lastBarTime = currentBarTime;

      // Check for breakout if range is valid and no trade taken
      if(g_asianRange.isValid && !g_asianRange.breakoutOccurred) {
         if(IsInTradingSession() && CanOpenNewTrade()) {
            CheckForBreakout();
         }
      }

      // Manage open positions
      ManageOpenPositions();
   }

   // Draw range on chart
   if(DrawRangeOnChart && g_asianRange.isCalculated) {
      DrawAsianRange();
   }

   // Update dashboard
   if(ShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Load Prop Firm Profile                                           |
//+------------------------------------------------------------------+
void LoadPropFirmProfile() {
   switch(PropFirmProfile) {
      case PROP_FTMO_NORMAL:
         g_propSettings.maxDailyDD = 4.5;
         g_propSettings.maxTotalDD = 9.0;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_propSettings.newsFilter = true;
         g_propSettings.weekendClose = true;
         g_propSettings.maxSLPercent = 5.0;
         break;

      case PROP_FTMO_SWING:
         g_propSettings.maxDailyDD = 4.5;
         g_propSettings.maxTotalDD = 9.0;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_propSettings.newsFilter = false;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 5.0;
         break;

      case PROP_E8_ONE:
         g_propSettings.maxDailyDD = 4.5;
         g_propSettings.maxTotalDD = 5.5;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.2 : 0.6;
         g_propSettings.newsFilter = false;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 5.0;
         break;

      case PROP_E8_CLASSIC:
         g_propSettings.maxDailyDD = 4.5;
         g_propSettings.maxTotalDD = 7.5;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_propSettings.newsFilter = false;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 5.0;
         break;

      case PROP_FUNDING_PIPS_1:
         g_propSettings.maxDailyDD = 3.5;
         g_propSettings.maxTotalDD = 5.5;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.0 : 0.5;
         g_propSettings.newsFilter = true;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 5.0;
         break;

      case PROP_FUNDING_PIPS_2:
         g_propSettings.maxDailyDD = 4.5;
         g_propSettings.maxTotalDD = 9.0;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_propSettings.newsFilter = true;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 5.0;
         break;

      case PROP_THE5ERS_BOOT:
         g_propSettings.maxDailyDD = 99.0;  // No daily limit
         g_propSettings.maxTotalDD = 4.5;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.0 : 0.5;
         g_propSettings.newsFilter = false;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 1.8;  // CRITICAL
         break;

      case PROP_THE5ERS_HS:
         g_propSettings.maxDailyDD = 4.5;
         g_propSettings.maxTotalDD = 9.0;
         g_propSettings.riskPercent = (TradeMode == MODE_CHALLENGE) ? 1.5 : 0.75;
         g_propSettings.newsFilter = false;
         g_propSettings.weekendClose = false;
         g_propSettings.maxSLPercent = 5.0;
         break;

      default:  // PROP_CUSTOM
         g_propSettings.maxDailyDD = MaxDailyDD;
         g_propSettings.maxTotalDD = MaxTotalDD;
         g_propSettings.riskPercent = RiskPercent;
         g_propSettings.newsFilter = UseNewsFilter;
         g_propSettings.weekendClose = CloseBeforeWeekend;
         g_propSettings.maxSLPercent = MaxSLPercent;
         break;
   }
}

//+------------------------------------------------------------------+
//| Reset Asian Range                                                 |
//+------------------------------------------------------------------+
void ResetAsianRange() {
   g_asianRange.high = 0;
   g_asianRange.low = 0;
   g_asianRange.midpoint = 0;
   g_asianRange.size = 0;
   g_asianRange.sizePips = 0;
   g_asianRange.startTime = 0;
   g_asianRange.endTime = 0;
   g_asianRange.isValid = false;
   g_asianRange.isCalculated = false;
   g_asianRange.breakoutOccurred = false;
   g_asianRange.breakoutDirection = 0;
}

//+------------------------------------------------------------------+
//| Calculate Asian Range If Needed                                   |
//+------------------------------------------------------------------+
void CalculateAsianRangeIfNeeded() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // Check if we need to calculate new range
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                  IntegerToString(dt.mon) + "." +
                                  IntegerToString(dt.day));

   // New day - reset range
   if(today != g_lastRangeDate) {
      ResetAsianRange();
      g_lastRangeDate = today;
      g_tradeTakenToday = false;
   }

   // Calculate range after Asian session ends
   if(!g_asianRange.isCalculated && dt.hour >= AsianEndHour) {
      CalculateAsianRange();
   }
}

//+------------------------------------------------------------------+
//| Calculate Asian Range                                             |
//+------------------------------------------------------------------+
void CalculateAsianRange() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // Build Asian session start/end times
   dt.hour = AsianStartHour;
   dt.min = 0;
   dt.sec = 0;
   datetime asianStart = StructToTime(dt);

   dt.hour = AsianEndHour;
   datetime asianEnd = StructToTime(dt);

   // Get bar indices
   int startBar = iBarShift(_Symbol, PERIOD_M15, asianStart);
   int endBar = iBarShift(_Symbol, PERIOD_M15, asianEnd);

   if(startBar < 0 || endBar < 0 || startBar <= endBar) {
      Print("Cannot calculate Asian range - invalid bars");
      g_asianRange.isValid = false;
      g_asianRange.isCalculated = true;
      return;
   }

   // Copy price data
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int barsCount = startBar - endBar + 1;
   if(CopyHigh(_Symbol, PERIOD_M15, endBar, barsCount, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, endBar, barsCount, lows) <= 0) return;

   // Find high and low
   g_asianRange.high = highs[ArrayMaximum(highs)];
   g_asianRange.low = lows[ArrayMinimum(lows)];
   g_asianRange.midpoint = (g_asianRange.high + g_asianRange.low) / 2;
   g_asianRange.size = (g_asianRange.high - g_asianRange.low) / _Point;
   g_asianRange.sizePips = g_asianRange.size / 10;
   g_asianRange.startTime = asianStart;
   g_asianRange.endTime = asianEnd;
   g_asianRange.isCalculated = true;

   // Validate range
   ValidateAsianRange();

   Print("Asian Range calculated: High=", g_asianRange.high,
         " Low=", g_asianRange.low,
         " Size=", g_asianRange.sizePips, " pips",
         " Valid=", g_asianRange.isValid);
}

//+------------------------------------------------------------------+
//| Validate Asian Range                                              |
//+------------------------------------------------------------------+
void ValidateAsianRange() {
   // Check minimum/maximum pip size
   if(g_asianRange.sizePips < MinRangePips) {
      Print("Range too small: ", g_asianRange.sizePips, " < ", MinRangePips);
      g_asianRange.isValid = false;
      return;
   }

   if(g_asianRange.sizePips > MaxRangePips) {
      Print("Range too large: ", g_asianRange.sizePips, " > ", MaxRangePips);
      g_asianRange.isValid = false;
      return;
   }

   // Check ATR ratio
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0) {
      g_asianRange.isValid = false;
      return;
   }

   double atrPips = atr[0] / _Point / 10;
   double rangeATRRatio = g_asianRange.sizePips / atrPips;

   if(rangeATRRatio < RangeATRMin) {
      Print("Range/ATR too low: ", rangeATRRatio, " < ", RangeATRMin);
      g_asianRange.isValid = false;
      return;
   }

   if(rangeATRRatio > RangeATRMax) {
      Print("Range/ATR too high: ", rangeATRRatio, " > ", RangeATRMax);
      g_asianRange.isValid = false;
      return;
   }

   g_asianRange.isValid = true;
}

//+------------------------------------------------------------------+
//| Check for Breakout                                                |
//+------------------------------------------------------------------+
void CheckForBreakout() {
   double close[], open[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyClose(_Symbol, PERIOD_M15, 0, 3, close) <= 0) return;
   if(CopyOpen(_Symbol, PERIOD_M15, 0, 3, open) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_M15, 0, 3, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, 0, 3, low) <= 0) return;

   double bufferPoints = BreakoutBuffer * 10 * _Point;
   double breakoutHigh = g_asianRange.high + bufferPoints;
   double breakoutLow = g_asianRange.low - bufferPoints;

   // Check for bullish breakout
   if(close[1] > breakoutHigh) {
      if(ValidateBreakout(true, close[1], open[1], high[1] - low[1])) {
         ExecuteBreakoutTrade(true);
         return;
      }
   }

   // Check for bearish breakout
   if(close[1] < breakoutLow) {
      if(ValidateBreakout(false, close[1], open[1], high[1] - low[1])) {
         ExecuteBreakoutTrade(false);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Validate Breakout                                                 |
//+------------------------------------------------------------------+
bool ValidateBreakout(bool isLong, double closePrice, double openPrice, double candleSize) {
   // 1. Check momentum (candle size)
   double minCandleSize = g_asianRange.size * _Point * (MomentumMinPercent / 100);
   if(candleSize < minCandleSize) {
      Print("Breakout rejected: Candle size too small");
      return false;
   }

   // 2. Check candle direction matches breakout
   if(isLong && closePrice < openPrice) {
      Print("Breakout rejected: Bearish candle on long breakout");
      return false;
   }
   if(!isLong && closePrice > openPrice) {
      Print("Breakout rejected: Bullish candle on short breakout");
      return false;
   }

   // 3. Check HTF trend filter
   if(UseHTFFilter) {
      if(!CheckHTFTrend(isLong)) {
         Print("Breakout rejected: Against HTF trend");
         return false;
      }
   }

   // 4. Check spread
   if(UseSpreadFilter) {
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point / _Point / 10;
      if(spread > MaxSpreadPips) {
         Print("Breakout rejected: Spread too high (", spread, ")");
         return false;
      }
   }

   // 5. Check news
   if(g_propSettings.newsFilter && IsHighImpactNews()) {
      Print("Breakout rejected: High impact news nearby");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check HTF Trend                                                   |
//+------------------------------------------------------------------+
bool CheckHTFTrend(bool isLong) {
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);

   if(CopyBuffer(g_emaFastHandle, 0, 0, 1, emaFast) <= 0) return true;
   if(CopyBuffer(g_emaSlowHandle, 0, 0, 1, emaSlow) <= 0) return true;

   if(isLong && emaFast[0] < emaSlow[0]) return false;  // Against trend
   if(!isLong && emaFast[0] > emaSlow[0]) return false; // Against trend

   return true;
}

//+------------------------------------------------------------------+
//| Execute Breakout Trade                                            |
//+------------------------------------------------------------------+
void ExecuteBreakoutTrade(bool isLong) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid) / _Point;

   double entryPrice, sl, tp1, tp2;
   double bufferPoints = (5 + spread/10) * 10 * _Point;  // 5 pips + spread

   if(isLong) {
      entryPrice = ask;
      sl = g_asianRange.low - bufferPoints;
      double slDistance = entryPrice - sl;
      tp1 = entryPrice + (slDistance * TP1_RR);
      tp2 = entryPrice + (g_asianRange.size * _Point * TP2_RangeMultiple);
   }
   else {
      entryPrice = bid;
      sl = g_asianRange.high + bufferPoints;
      double slDistance = sl - entryPrice;
      tp1 = entryPrice - (slDistance * TP1_RR);
      tp2 = entryPrice - (g_asianRange.size * _Point * TP2_RangeMultiple);
   }

   // Calculate lot size
   double lots = CalculateLotSize(entryPrice, sl);
   if(lots <= 0) {
      Print("Invalid lot size");
      return;
   }

   // Validate SL percentage
   double slPercent = MathAbs(entryPrice - sl) / entryPrice * 100;
   if(slPercent > g_propSettings.maxSLPercent) {
      Print("SL exceeds max allowed: ", slPercent, "% > ", g_propSettings.maxSLPercent, "%");
      lots = lots * (g_propSettings.maxSLPercent / slPercent);
      lots = NormalizeDouble(lots, 2);
   }

   // Execute trade
   string comment = TradeComment + (isLong ? "_Long" : "_Short");
   bool success = false;

   if(isLong) {
      success = trade.Buy(lots, _Symbol, entryPrice, sl, tp1, comment);
   }
   else {
      success = trade.Sell(lots, _Symbol, entryPrice, sl, tp1, comment);
   }

   if(success) {
      g_asianRange.breakoutOccurred = true;
      g_asianRange.breakoutDirection = isLong ? 1 : -1;
      g_stats.tradesToday++;
      g_stats.lastTradeTime = TimeCurrent();
      g_tradeTakenToday = true;

      Print("TRADE EXECUTED: ", (isLong ? "BUY" : "SELL"),
            " | Lots: ", lots,
            " | Entry: ", entryPrice,
            " | SL: ", sl,
            " | TP1: ", tp1);

      // Draw breakout arrow
      if(DrawRangeOnChart) {
         DrawBreakoutArrow(isLong, entryPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss) {
   double riskAmount = accountInfo.Balance() * (g_propSettings.riskPercent / 100);
   double slPips = MathAbs(entryPrice - stopLoss) / _Point / 10;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize == 0 || slPips == 0) return 0;

   double pipValue = tickValue * (_Point * 10 / tickSize);
   double lots = riskAmount / (slPips * pipValue);

   // Normalize
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / lotStep) * lotStep;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Symbol() != _Symbol) continue;
      if(positionInfo.Magic() != MagicNumber) continue;

      double openPrice = positionInfo.PriceOpen();
      double currentSL = positionInfo.StopLoss();
      double currentTP = positionInfo.TakeProfit();
      double profit = positionInfo.Profit();
      ulong ticket = positionInfo.Ticket();
      bool isLong = (positionInfo.PositionType() == POSITION_TYPE_BUY);

      // Apply trailing stop after position is in profit
      if(UseTrailingStop && profit > 0) {
         ApplyTrailingStop(ticket, openPrice, currentSL, currentTP, isLong);
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, double openPrice, double currentSL, double currentTP, bool isLong) {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0) return;

   double trailDistance = atr[0] * TrailingATRMultiplier;
   double currentPrice = isLong ?
      SymbolInfoDouble(_Symbol, SYMBOL_BID) :
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(isLong) {
      // Need minimum profit before trailing
      if(currentPrice - openPrice < trailDistance) return;

      double newSL = currentPrice - trailDistance;
      if(newSL > currentSL && newSL > openPrice) {
         trade.PositionModify(ticket, newSL, currentTP);
      }
   }
   else {
      if(openPrice - currentPrice < trailDistance) return;

      double newSL = currentPrice + trailDistance;
      if(newSL < currentSL && newSL < openPrice) {
         trade.PositionModify(ticket, newSL, currentTP);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Day Change                                                  |
//+------------------------------------------------------------------+
void CheckDayChange() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   static int lastDay = -1;
   if(lastDay != dt.day) {
      if(lastDay != -1) {
         g_stats.dailyStartBalance = accountInfo.Balance();
         g_stats.dailyPnL = 0;
         g_stats.tradesToday = 0;
         g_stats.dailyLimitReached = false;
         Print("New trading day. Stats reset.");
      }
      lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| Risk Management Checks                                           |
//+------------------------------------------------------------------+
bool PassRiskChecks() {
   double currentEquity = accountInfo.Equity();

   // Calculate daily P&L
   g_stats.dailyPnL = ((currentEquity - g_stats.dailyStartBalance) / g_stats.dailyStartBalance) * 100;

   // Calculate total drawdown
   g_stats.totalDD = ((g_stats.startingBalance - currentEquity) / g_stats.startingBalance) * 100;

   // Check daily drawdown
   if(g_stats.dailyPnL <= -g_propSettings.maxDailyDD) {
      if(!g_stats.dailyLimitReached) {
         Print("ALERT: Daily DD limit reached! ", g_stats.dailyPnL, "%");
         g_stats.dailyLimitReached = true;
         CloseAllPositions("Daily DD Limit");
      }
      return false;
   }

   // Check total drawdown
   if(g_stats.totalDD >= g_propSettings.maxTotalDD) {
      if(!g_stats.ddLimitReached) {
         Print("ALERT: Total DD limit reached! ", g_stats.totalDD, "%");
         g_stats.ddLimitReached = true;
         CloseAllPositions("Total DD Limit");
      }
      return false;
   }

   // Weekend close
   if(g_propSettings.weekendClose && IsWeekendClose()) {
      CloseAllPositions("Weekend Close");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Is In Trading Session                                             |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;

   // London Open: 07:00 - 10:00 UTC
   if(TradeLondonOpen && hour >= 7 && hour < 10) return true;

   // NY Open: 12:00 - 15:00 UTC
   if(TradeNYOpen && hour >= 12 && hour < 15) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Is Weekend Close                                                  |
//+------------------------------------------------------------------+
bool IsWeekendClose() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   if(dt.day_of_week == 5 && dt.hour >= FridayCloseHour) return true;
   if(dt.day_of_week == 6 || dt.day_of_week == 0) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Is High Impact News                                               |
//+------------------------------------------------------------------+
bool IsHighImpactNews() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // NFP Friday
   if(dt.day_of_week == 5 && dt.day <= 7 &&
      dt.hour == 13 && dt.min >= (30 - NewsFilterMinutes) && dt.min <= (30 + NewsFilterMinutes)) {
      return true;
   }

   // Add more news events as needed
   return false;
}

//+------------------------------------------------------------------+
//| Can Open New Trade                                                |
//+------------------------------------------------------------------+
bool CanOpenNewTrade() {
   if(g_stats.tradesToday >= MaxTradesPerDay) return false;
   if(CountOpenTrades() >= MaxOpenTrades) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Count Open Trades                                                 |
//+------------------------------------------------------------------+
int CountOpenTrades() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(positionInfo.SelectByIndex(i)) {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == MagicNumber) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close All Positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason) {
   Print("Closing all positions: ", reason);

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Symbol() != _Symbol) continue;
      if(positionInfo.Magic() != MagicNumber) continue;

      trade.PositionClose(positionInfo.Ticket());
   }
}

//+------------------------------------------------------------------+
//| Draw Asian Range on Chart                                         |
//+------------------------------------------------------------------+
void DrawAsianRange() {
   string objName = "AsianRange_Box";

   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H4);

   // Delete old object
   ObjectDelete(0, objName);

   // Draw rectangle
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                g_asianRange.startTime, g_asianRange.high,
                endTime, g_asianRange.low);

   ObjectSetInteger(0, objName, OBJPROP_COLOR, RangeColor);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);

   // High line
   string highLine = "AsianRange_High";
   ObjectDelete(0, highLine);
   ObjectCreate(0, highLine, OBJ_HLINE, 0, 0, g_asianRange.high);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, RangeColor);
   ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_DOT);

   // Low line
   string lowLine = "AsianRange_Low";
   ObjectDelete(0, lowLine);
   ObjectCreate(0, lowLine, OBJ_HLINE, 0, 0, g_asianRange.low);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, RangeColor);
   ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| Draw Breakout Arrow                                               |
//+------------------------------------------------------------------+
void DrawBreakoutArrow(bool isLong, double price) {
   string objName = "AsianRange_Breakout_" + TimeToString(TimeCurrent());

   ObjectCreate(0, objName, isLong ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, TimeCurrent(), price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, BreakoutColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard() {
   string dashboard = "";
   dashboard += "================================================\n";
   dashboard += "    PROPFIRM SESSION BREAKOUT EA v1.0\n";
   dashboard += "================================================\n";
   dashboard += "Profile: " + EnumToString(PropFirmProfile) + "\n";
   dashboard += "Mode: " + EnumToString(TradeMode) + "\n";
   dashboard += "------------------------------------------------\n";
   dashboard += "         ASIAN RANGE STATUS\n";
   dashboard += "------------------------------------------------\n";

   if(g_asianRange.isCalculated) {
      dashboard += StringFormat("High: %.5f\n", g_asianRange.high);
      dashboard += StringFormat("Low: %.5f\n", g_asianRange.low);
      dashboard += StringFormat("Size: %.1f pips\n", g_asianRange.sizePips);
      dashboard += "Valid: " + (g_asianRange.isValid ? "YES" : "NO") + "\n";
      dashboard += "Breakout: " + (g_asianRange.breakoutOccurred ?
                  (g_asianRange.breakoutDirection > 0 ? "LONG" : "SHORT") : "NONE") + "\n";
   }
   else {
      dashboard += "Calculating...\n";
   }

   dashboard += "------------------------------------------------\n";
   dashboard += "         RISK STATUS\n";
   dashboard += "------------------------------------------------\n";
   dashboard += StringFormat("Daily P&L: %.2f%% / -%.2f%%\n",
                            g_stats.dailyPnL, g_propSettings.maxDailyDD);
   dashboard += StringFormat("Total DD: %.2f%% / %.2f%%\n",
                            g_stats.totalDD, g_propSettings.maxTotalDD);
   dashboard += StringFormat("Trades Today: %d / %d\n",
                            g_stats.tradesToday, MaxTradesPerDay);
   dashboard += StringFormat("Open Trades: %d / %d\n",
                            CountOpenTrades(), MaxOpenTrades);
   dashboard += "------------------------------------------------\n";
   dashboard += "Session: " + (IsInTradingSession() ? "ACTIVE" : "INACTIVE") + "\n";
   dashboard += "================================================\n";

   Comment(dashboard);
}
//+------------------------------------------------------------------+
