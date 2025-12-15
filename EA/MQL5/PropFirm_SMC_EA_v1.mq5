//+------------------------------------------------------------------+
//|                                         PropFirm_SMC_EA_v1.mq5   |
//|                                    Smart Money Concepts Strategy |
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

enum ENUM_SETUP_TYPE {
   SETUP_A_OB_FVG,        // Setup A: Order Block + FVG
   SETUP_B_LIQ_SWEEP,     // Setup B: Liquidity Sweep
   SETUP_C_CHOCH          // Setup C: CHoCH Reversal
};

//+------------------------------------------------------------------+
//| Input Parameters - Prop Firm Selection                           |
//+------------------------------------------------------------------+
input group "═══════════ PROP FIRM SETTINGS ═══════════"
input ENUM_PROP_FIRM PropFirmProfile = PROP_FTMO_NORMAL;  // Prop Firm Profile
input ENUM_TRADE_MODE TradeMode = MODE_CHALLENGE;          // Trading Mode

//+------------------------------------------------------------------+
//| Input Parameters - Risk Management                               |
//+------------------------------------------------------------------+
input group "═══════════ RISK MANAGEMENT ═══════════"
input double RiskPercent = 1.5;              // Risk Per Trade (%)
input double MaxDailyDD = 4.5;               // Max Daily Drawdown (%)
input double MaxTotalDD = 9.0;               // Max Total Drawdown (%)
input int MaxTradesPerDay = 4;               // Max Trades Per Day
input int MaxOpenTrades = 2;                 // Max Simultaneous Trades
input double MaxSLPercent = 1.8;             // Max SL as % of Capital (The5ers)
input int SLTimeoutSeconds = 150;            // SL Timeout in Seconds

//+------------------------------------------------------------------+
//| Input Parameters - Strategy                                      |
//+------------------------------------------------------------------+
input group "═══════════ STRATEGY SETTINGS ═══════════"
input bool UseSetupA = true;                 // Use Setup A (OB + FVG)
input bool UseSetupB = true;                 // Use Setup B (Liquidity Sweep)
input bool UseSetupC = false;                // Use Setup C (CHoCH)
input int HTF_Period = PERIOD_H4;            // Higher Timeframe
input int LTF_Period = PERIOD_M5;            // Lower Timeframe Confirmation
input int OB_Lookback = 50;                  // Order Block Lookback
input double MinRR = 1.5;                    // Minimum Risk:Reward

//+------------------------------------------------------------------+
//| Input Parameters - Take Profit                                   |
//+------------------------------------------------------------------+
input group "═══════════ TAKE PROFIT SETTINGS ═══════════"
input double TP1_Percent = 40;               // TP1 Position % (at 1:1)
input double TP2_Percent = 30;               // TP2 Position % (at structure)
input double TP3_Percent = 30;               // TP3 Position % (trailing)
input bool UseTrailingStop = true;           // Use Trailing Stop after TP1
input double TrailingATRMultiplier = 1.5;    // Trailing ATR Multiplier

//+------------------------------------------------------------------+
//| Input Parameters - Filters                                       |
//+------------------------------------------------------------------+
input group "═══════════ FILTERS ═══════════"
input bool UseNewsFilter = true;             // Use News Filter
input int MinutesBeforeNews = 5;             // Minutes Before News
input int MinutesAfterNews = 5;              // Minutes After News
input bool UseSpreadFilter = true;           // Use Spread Filter
input double MaxSpreadPips = 1.5;            // Max Spread (Pips)
input bool UseSessionFilter = true;          // Use Session Filter
input bool TradeLondonKZ = true;             // Trade London Kill Zone
input bool TradeNYKZ = true;                 // Trade NY Kill Zone
input bool TradeLondonClose = false;         // Trade London Close
input bool CloseBeforeWeekend = true;        // Close Before Weekend
input int FridayCloseHour = 20;              // Friday Close Hour (UTC)

//+------------------------------------------------------------------+
//| Input Parameters - Magic Number                                  |
//+------------------------------------------------------------------+
input group "═══════════ EA SETTINGS ═══════════"
input int MagicNumber = 123456;              // Magic Number
input string TradeComment = "SMC_PropFirm";  // Trade Comment
input bool ShowDashboard = true;             // Show Dashboard

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct OrderBlock {
   double high;
   double low;
   double midpoint;
   datetime time;
   bool isBullish;
   bool isValid;
   int touches;
   double strength;
};

struct FairValueGap {
   double upper;
   double lower;
   datetime time;
   bool isBullish;
   bool isFilled;
};

struct MarketStructure {
   double lastHH;
   double lastHL;
   double lastLH;
   double lastLL;
   int trend;           // 1 = Up, -1 = Down, 0 = Range
   bool bosConfirmed;
   bool chochDetected;
   datetime lastUpdate;
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

OrderBlock g_bullishOBs[];
OrderBlock g_bearishOBs[];
FairValueGap g_fvgs[];
MarketStructure g_marketStructure;
TradeStats g_stats;
PropFirmSettings g_propSettings;

double g_initialBalance;
datetime g_lastBarTime;
int g_htfHandle;
int g_atrHandle;

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

   // Load prop firm profile
   LoadPropFirmProfile();

   // Initialize indicators
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR indicator");
      return INIT_FAILED;
   }

   // Initialize arrays
   ArrayResize(g_bullishOBs, 0);
   ArrayResize(g_bearishOBs, 0);
   ArrayResize(g_fvgs, 0);

   Print("PropFirm SMC EA initialized successfully");
   Print("Mode: ", EnumToString(TradeMode));
   Print("Profile: ", EnumToString(PropFirmProfile));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   Comment("");
   Print("PropFirm SMC EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (currentBarTime != g_lastBarTime);

   // Update daily stats at day change
   CheckDayChange();

   // Risk Management Checks (every tick)
   if(!PassRiskChecks()) {
      if(ShowDashboard) UpdateDashboard();
      return;
   }

   // Process on new bar only
   if(newBar) {
      g_lastBarTime = currentBarTime;

      // Update market structure
      UpdateMarketStructure();

      // Detect Order Blocks
      DetectOrderBlocks();

      // Detect FVGs
      DetectFVGs();

      // Check for trade setups
      if(CanOpenNewTrade()) {
         CheckTradeSetups();
      }

      // Manage open positions
      ManageOpenPositions();
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
         g_propSettings.maxDailyDD = 99.0;  // No daily limit in eval
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
//| Check Day Change                                                  |
//+------------------------------------------------------------------+
void CheckDayChange() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   static int lastDay = -1;
   if(lastDay != dt.day) {
      if(lastDay != -1) {
         // New day started
         g_stats.dailyStartBalance = accountInfo.Balance();
         g_stats.dailyPnL = 0;
         g_stats.tradesToday = 0;
         g_stats.dailyLimitReached = false;
         Print("New trading day. Daily stats reset.");
      }
      lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| Risk Management Checks                                           |
//+------------------------------------------------------------------+
bool PassRiskChecks() {
   double currentBalance = accountInfo.Balance();
   double currentEquity = accountInfo.Equity();

   // Calculate daily P&L
   g_stats.dailyPnL = ((currentEquity - g_stats.dailyStartBalance) / g_stats.dailyStartBalance) * 100;

   // Calculate total drawdown
   g_stats.totalDD = ((g_stats.startingBalance - currentEquity) / g_stats.startingBalance) * 100;

   // Check daily drawdown
   if(g_stats.dailyPnL <= -g_propSettings.maxDailyDD) {
      if(!g_stats.dailyLimitReached) {
         Print("ALERT: Daily drawdown limit reached! ", g_stats.dailyPnL, "%");
         g_stats.dailyLimitReached = true;
         CloseAllPositions("Daily DD Limit");
      }
      return false;
   }

   // Check total drawdown
   if(g_stats.totalDD >= g_propSettings.maxTotalDD) {
      if(!g_stats.ddLimitReached) {
         Print("ALERT: Total drawdown limit reached! ", g_stats.totalDD, "%");
         g_stats.ddLimitReached = true;
         CloseAllPositions("Total DD Limit");
      }
      return false;
   }

   // Weekend close check
   if(g_propSettings.weekendClose && IsWeekendClose()) {
      CloseAllPositions("Weekend Close");
      return false;
   }

   // News filter
   if(g_propSettings.newsFilter && IsHighImpactNews()) {
      return false;
   }

   // Spread filter
   if(UseSpreadFilter && !PassSpreadFilter()) {
      return false;
   }

   // Session filter
   if(UseSessionFilter && !IsInKillZone()) {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if Weekend Close                                           |
//+------------------------------------------------------------------+
bool IsWeekendClose() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // Friday after close hour
   if(dt.day_of_week == 5 && dt.hour >= FridayCloseHour) return true;

   // Saturday or Sunday
   if(dt.day_of_week == 6 || dt.day_of_week == 0) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check Kill Zone                                                   |
//+------------------------------------------------------------------+
bool IsInKillZone() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int hour = dt.hour;

   // London Kill Zone: 07:00 - 10:00 UTC
   if(TradeLondonKZ && hour >= 7 && hour < 10) return true;

   // NY Kill Zone: 12:00 - 15:00 UTC
   if(TradeNYKZ && hour >= 12 && hour < 15) return true;

   // London Close: 15:00 - 17:00 UTC
   if(TradeLondonClose && hour >= 15 && hour < 17) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check High Impact News                                           |
//+------------------------------------------------------------------+
bool IsHighImpactNews() {
   // Placeholder - In production, integrate with news calendar API
   // For now, check for common high impact times
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // NFP Friday (first Friday of month, 13:30 UTC)
   if(dt.day_of_week == 5 && dt.day <= 7 && dt.hour == 13 && dt.min >= 25 && dt.min <= 35) {
      return true;
   }

   // FOMC (Wednesday 19:00 UTC typically)
   // Add more news events as needed

   return false;
}

//+------------------------------------------------------------------+
//| Pass Spread Filter                                               |
//+------------------------------------------------------------------+
bool PassSpreadFilter() {
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point / _Point / 10;
   return spread <= MaxSpreadPips;
}

//+------------------------------------------------------------------+
//| Can Open New Trade                                               |
//+------------------------------------------------------------------+
bool CanOpenNewTrade() {
   // Check max trades per day
   if(g_stats.tradesToday >= MaxTradesPerDay) return false;

   // Check max open trades
   int openTrades = CountOpenTrades();
   if(openTrades >= MaxOpenTrades) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Count Open Trades                                                |
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
//| Update Market Structure                                          |
//+------------------------------------------------------------------+
void UpdateMarketStructure() {
   int lookback = 100;
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback, lows) <= 0) return;

   // Find swing points
   double swingHighs[];
   double swingLows[];
   int swingHighBars[];
   int swingLowBars[];

   ArrayResize(swingHighs, 0);
   ArrayResize(swingLows, 0);
   ArrayResize(swingHighBars, 0);
   ArrayResize(swingLowBars, 0);

   for(int i = 2; i < lookback - 2; i++) {
      // Swing High
      if(highs[i] > highs[i+1] && highs[i] > highs[i+2] &&
         highs[i] > highs[i-1] && highs[i] > highs[i-2]) {
         int size = ArraySize(swingHighs);
         ArrayResize(swingHighs, size + 1);
         ArrayResize(swingHighBars, size + 1);
         swingHighs[size] = highs[i];
         swingHighBars[size] = i;
      }
      // Swing Low
      if(lows[i] < lows[i+1] && lows[i] < lows[i+2] &&
         lows[i] < lows[i-1] && lows[i] < lows[i-2]) {
         int size = ArraySize(swingLows);
         ArrayResize(swingLows, size + 1);
         ArrayResize(swingLowBars, size + 1);
         swingLows[size] = lows[i];
         swingLowBars[size] = i;
      }
   }

   // Analyze structure
   if(ArraySize(swingHighs) >= 2 && ArraySize(swingLows) >= 2) {
      g_marketStructure.lastHH = swingHighs[0];
      g_marketStructure.lastHL = swingLows[0];

      // Determine trend
      if(swingHighs[0] > swingHighs[1] && swingLows[0] > swingLows[1]) {
         g_marketStructure.trend = 1;  // Uptrend
      }
      else if(swingHighs[0] < swingHighs[1] && swingLows[0] < swingLows[1]) {
         g_marketStructure.trend = -1;  // Downtrend
      }
      else {
         g_marketStructure.trend = 0;  // Range
      }

      // Check BOS
      double close[];
      ArraySetAsSeries(close, true);
      CopyClose(_Symbol, PERIOD_CURRENT, 0, 5, close);

      g_marketStructure.bosConfirmed = false;
      g_marketStructure.chochDetected = false;

      if(g_marketStructure.trend == 1 && close[0] > g_marketStructure.lastHH) {
         g_marketStructure.bosConfirmed = true;
      }
      else if(g_marketStructure.trend == -1 && close[0] < g_marketStructure.lastLL) {
         g_marketStructure.bosConfirmed = true;
      }

      // Check CHoCH
      if(g_marketStructure.trend == 1 && close[0] < g_marketStructure.lastHL) {
         g_marketStructure.chochDetected = true;
      }
      else if(g_marketStructure.trend == -1 && close[0] > g_marketStructure.lastLH) {
         g_marketStructure.chochDetected = true;
      }
   }

   g_marketStructure.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks() {
   // Clear old OBs
   ArrayResize(g_bullishOBs, 0);
   ArrayResize(g_bearishOBs, 0);

   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, OB_Lookback, open) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, OB_Lookback, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, OB_Lookback, low) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, OB_Lookback, close) <= 0) return;

   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(g_atrHandle, 0, 0, OB_Lookback, atr);

   for(int i = 5; i < OB_Lookback - 3; i++) {
      // Calculate move after candle
      double moveAfter = 0;
      for(int j = i - 1; j >= i - 3 && j >= 0; j--) {
         moveAfter += MathAbs(close[j] - open[j]);
      }

      // Need significant move (> 2x ATR)
      if(moveAfter < atr[i] * 2) continue;

      // Bullish OB: Bearish candle before bullish move
      if(close[i] < open[i] && close[i-3] > high[i]) {
         OrderBlock ob;
         ob.high = high[i];
         ob.low = low[i];
         ob.midpoint = (ob.high + ob.low) / 2;
         ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
         ob.isBullish = true;
         ob.isValid = true;
         ob.touches = 0;
         ob.strength = moveAfter / atr[i];

         int size = ArraySize(g_bullishOBs);
         ArrayResize(g_bullishOBs, size + 1);
         g_bullishOBs[size] = ob;
      }

      // Bearish OB: Bullish candle before bearish move
      if(close[i] > open[i] && close[i-3] < low[i]) {
         OrderBlock ob;
         ob.high = high[i];
         ob.low = low[i];
         ob.midpoint = (ob.high + ob.low) / 2;
         ob.time = iTime(_Symbol, PERIOD_CURRENT, i);
         ob.isBullish = false;
         ob.isValid = true;
         ob.touches = 0;
         ob.strength = moveAfter / atr[i];

         int size = ArraySize(g_bearishOBs);
         ArrayResize(g_bearishOBs, size + 1);
         g_bearishOBs[size] = ob;
      }
   }

   // Validate OBs - invalidate if price has passed through
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 0; i < ArraySize(g_bullishOBs); i++) {
      if(currentPrice < g_bullishOBs[i].low) {
         g_bullishOBs[i].isValid = false;
      }
   }

   for(int i = 0; i < ArraySize(g_bearishOBs); i++) {
      if(currentPrice > g_bearishOBs[i].high) {
         g_bearishOBs[i].isValid = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps                                           |
//+------------------------------------------------------------------+
void DetectFVGs() {
   ArrayResize(g_fvgs, 0);

   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 50, low) <= 0) return;

   for(int i = 2; i < 47; i++) {
      // Bullish FVG: Low[i] > High[i+2]
      if(low[i] > high[i+2]) {
         FairValueGap fvg;
         fvg.upper = low[i];
         fvg.lower = high[i+2];
         fvg.time = iTime(_Symbol, PERIOD_CURRENT, i+1);
         fvg.isBullish = true;
         fvg.isFilled = false;

         // Check if filled
         for(int j = i - 1; j >= 0; j--) {
            if(low[j] <= fvg.lower) {
               fvg.isFilled = true;
               break;
            }
         }

         if(!fvg.isFilled) {
            int size = ArraySize(g_fvgs);
            ArrayResize(g_fvgs, size + 1);
            g_fvgs[size] = fvg;
         }
      }

      // Bearish FVG: High[i] < Low[i+2]
      if(high[i] < low[i+2]) {
         FairValueGap fvg;
         fvg.upper = low[i+2];
         fvg.lower = high[i];
         fvg.time = iTime(_Symbol, PERIOD_CURRENT, i+1);
         fvg.isBullish = false;
         fvg.isFilled = false;

         // Check if filled
         for(int j = i - 1; j >= 0; j--) {
            if(high[j] >= fvg.upper) {
               fvg.isFilled = true;
               break;
            }
         }

         if(!fvg.isFilled) {
            int size = ArraySize(g_fvgs);
            ArrayResize(g_fvgs, size + 1);
            g_fvgs[size] = fvg;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Trade Setups                                               |
//+------------------------------------------------------------------+
void CheckTradeSetups() {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Setup A: Order Block + FVG
   if(UseSetupA) {
      // Check Bullish Setup
      if(g_marketStructure.trend == 1 || g_marketStructure.bosConfirmed) {
         for(int i = 0; i < ArraySize(g_bullishOBs); i++) {
            if(!g_bullishOBs[i].isValid) continue;

            // Price in OB zone
            if(bid <= g_bullishOBs[i].high && bid >= g_bullishOBs[i].low) {
               // Check FVG confluence
               bool hasFVG = false;
               for(int j = 0; j < ArraySize(g_fvgs); j++) {
                  if(g_fvgs[j].isBullish &&
                     g_fvgs[j].lower >= g_bullishOBs[i].low &&
                     g_fvgs[j].upper <= g_bullishOBs[i].high) {
                     hasFVG = true;
                     break;
                  }
               }

               // Calculate RR
               double sl = g_bullishOBs[i].low - (10 * _Point);
               double tp = g_marketStructure.lastHH;
               double rr = (tp - ask) / (ask - sl);

               if(rr >= MinRR) {
                  int score = CalculateConfluenceScore(true, hasFVG);
                  int minScore = (TradeMode == MODE_CHALLENGE) ? 4 : 5;

                  if(score >= minScore) {
                     ExecuteTrade(ORDER_TYPE_BUY, ask, sl, tp, "Setup_A_Long");
                     g_bullishOBs[i].touches++;
                     return;
                  }
               }
            }
         }
      }

      // Check Bearish Setup
      if(g_marketStructure.trend == -1 || g_marketStructure.bosConfirmed) {
         for(int i = 0; i < ArraySize(g_bearishOBs); i++) {
            if(!g_bearishOBs[i].isValid) continue;

            // Price in OB zone
            if(ask >= g_bearishOBs[i].low && ask <= g_bearishOBs[i].high) {
               // Check FVG confluence
               bool hasFVG = false;
               for(int j = 0; j < ArraySize(g_fvgs); j++) {
                  if(!g_fvgs[j].isBullish &&
                     g_fvgs[j].lower >= g_bearishOBs[i].low &&
                     g_fvgs[j].upper <= g_bearishOBs[i].high) {
                     hasFVG = true;
                     break;
                  }
               }

               // Calculate RR
               double sl = g_bearishOBs[i].high + (10 * _Point);
               double tp = g_marketStructure.lastLL;
               double rr = (bid - tp) / (sl - bid);

               if(rr >= MinRR) {
                  int score = CalculateConfluenceScore(false, hasFVG);
                  int minScore = (TradeMode == MODE_CHALLENGE) ? 4 : 5;

                  if(score >= minScore) {
                     ExecuteTrade(ORDER_TYPE_SELL, bid, sl, tp, "Setup_A_Short");
                     g_bearishOBs[i].touches++;
                     return;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Confluence Score                                       |
//+------------------------------------------------------------------+
int CalculateConfluenceScore(bool isBullish, bool hasFVG) {
   int score = 0;

   // HTF trend alignment (+2)
   if((isBullish && g_marketStructure.trend == 1) ||
      (!isBullish && g_marketStructure.trend == -1)) {
      score += 2;
   }

   // FVG confluence (+2)
   if(hasFVG) score += 2;

   // BOS confirmed (+1)
   if(g_marketStructure.bosConfirmed) score += 1;

   // Kill Zone (+1)
   if(IsInKillZone()) score += 1;

   // Round number (+1)
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double roundNumber = MathRound(price / 0.01) * 0.01;
   if(MathAbs(price - roundNumber) < 0.0005) score += 1;

   return score;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double price, double sl, double tp, string setup) {
   // Calculate lot size
   double lots = CalculateLotSize(price, sl);
   if(lots <= 0) {
      Print("Invalid lot size calculated");
      return;
   }

   // Validate SL percentage (The5ers compliance)
   double slPercent = MathAbs(price - sl) / price * 100;
   if(slPercent > g_propSettings.maxSLPercent) {
      Print("SL exceeds maximum allowed: ", slPercent, "% > ", g_propSettings.maxSLPercent, "%");
      // Adjust lot size instead of skipping
      lots = lots * (g_propSettings.maxSLPercent / slPercent);
      lots = NormalizeDouble(lots, 2);
   }

   string comment = TradeComment + "_" + setup;

   if(orderType == ORDER_TYPE_BUY) {
      if(trade.Buy(lots, _Symbol, price, sl, tp, comment)) {
         g_stats.tradesToday++;
         g_stats.lastTradeTime = TimeCurrent();
         Print("BUY order opened: ", lots, " lots at ", price);
      }
   }
   else {
      if(trade.Sell(lots, _Symbol, price, sl, tp, comment)) {
         g_stats.tradesToday++;
         g_stats.lastTradeTime = TimeCurrent();
         Print("SELL order opened: ", lots, " lots at ", price);
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

   if(tickSize == 0) return 0;

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

      // Trailing stop after TP1
      if(UseTrailingStop && profit > 0) {
         double atr[];
         ArraySetAsSeries(atr, true);
         CopyBuffer(g_atrHandle, 0, 0, 1, atr);
         double trailDistance = atr[0] * TrailingATRMultiplier;

         if(positionInfo.PositionType() == POSITION_TYPE_BUY) {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double newSL = bid - trailDistance;
            if(newSL > currentSL && newSL > openPrice) {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
         else {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double newSL = ask + trailDistance;
            if(newSL < currentSL && newSL < openPrice) {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason) {
   Print("Closing all positions. Reason: ", reason);

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Symbol() != _Symbol) continue;
      if(positionInfo.Magic() != MagicNumber) continue;

      trade.PositionClose(positionInfo.Ticket());
   }
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard() {
   string dashboard = "";
   dashboard += "═══════════════════════════════════════\n";
   dashboard += "       PROPFIRM SMC EA v1.0\n";
   dashboard += "═══════════════════════════════════════\n";
   dashboard += "Profile: " + EnumToString(PropFirmProfile) + "\n";
   dashboard += "Mode: " + EnumToString(TradeMode) + "\n";
   dashboard += "───────────────────────────────────────\n";
   dashboard += "       RISK STATUS\n";
   dashboard += "───────────────────────────────────────\n";
   dashboard += StringFormat("Daily P&L: %.2f%% / -%.2f%%\n",
                            g_stats.dailyPnL, g_propSettings.maxDailyDD);
   dashboard += StringFormat("Total DD:  %.2f%% / %.2f%%\n",
                            g_stats.totalDD, g_propSettings.maxTotalDD);
   dashboard += StringFormat("Trades Today: %d / %d\n",
                            g_stats.tradesToday, MaxTradesPerDay);
   dashboard += StringFormat("Open Trades: %d / %d\n",
                            CountOpenTrades(), MaxOpenTrades);
   dashboard += "───────────────────────────────────────\n";
   dashboard += "       MARKET STRUCTURE\n";
   dashboard += "───────────────────────────────────────\n";
   dashboard += "Trend: " + (g_marketStructure.trend == 1 ? "BULLISH" :
                            (g_marketStructure.trend == -1 ? "BEARISH" : "RANGE")) + "\n";
   dashboard += "BOS: " + (g_marketStructure.bosConfirmed ? "YES" : "NO") + "\n";
   dashboard += "CHoCH: " + (g_marketStructure.chochDetected ? "YES" : "NO") + "\n";
   dashboard += StringFormat("Bullish OBs: %d\n", ArraySize(g_bullishOBs));
   dashboard += StringFormat("Bearish OBs: %d\n", ArraySize(g_bearishOBs));
   dashboard += StringFormat("Active FVGs: %d\n", ArraySize(g_fvgs));
   dashboard += "───────────────────────────────────────\n";
   dashboard += "Kill Zone: " + (IsInKillZone() ? "ACTIVE" : "INACTIVE") + "\n";
   dashboard += "═══════════════════════════════════════\n";

   Comment(dashboard);
}
//+------------------------------------------------------------------+
