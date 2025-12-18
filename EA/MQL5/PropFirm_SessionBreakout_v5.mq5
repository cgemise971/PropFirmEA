//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v5.mq5 |
//|       STRUCTURE-BASED SCANNER - Quality Direction Detection      |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "5.00"
#property description "V5: Real market structure + Quality zones + Pattern confirmation"
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

enum ENUM_TRADE_MODE {
   MODE_CHALLENGE,
   MODE_FUNDED
};

enum ENUM_MARKET_STRUCTURE {
   STRUCTURE_BULLISH,    // HH + HL
   STRUCTURE_BEARISH,    // LH + LL
   STRUCTURE_RANGING,    // No clear direction
   STRUCTURE_UNKNOWN
};

enum ENUM_SETUP_TYPE {
   SETUP_BREAKOUT,
   SETUP_RETEST,
   SETUP_REVERSAL,       // At key level with structure shift
   SETUP_CONTINUATION    // With trend pullback
};

enum ENUM_CANDLE_PATTERN {
   PATTERN_NONE,
   PATTERN_ENGULFING,
   PATTERN_PIN_BAR,
   PATTERN_INSIDE_BAR_BO,
   PATTERN_REJECTION
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "========== PROP FIRM =========="
input ENUM_PROP_FIRM PropFirm = PROP_FTMO;
input ENUM_TRADE_MODE Mode = MODE_CHALLENGE;

input group "========== RISK =========="
input double RiskPercent = 1.5;
input double MaxDailyDD = 4.5;
input double MaxTotalDD = 9.0;
input int MaxTradesDay = 4;
input int MaxOpenTrades = 2;

input group "========== STRUCTURE ANALYSIS =========="
input int SwingLookback = 10;              // Bars to identify swing points
input int StructureBars = 50;              // Bars for structure analysis
input bool RequireStructureAlignment = true; // Direction must match structure
input double MinSwingSize = 0.5;           // Min swing size (ATR multiplier)

input group "========== RANGE DETECTION =========="
input bool UseAsianRange = true;           // Asian Range (00-06 UTC)
input bool UseLondonRange = true;          // London Range (07-10 UTC)
input int MinRangeTouches = 2;             // Min touches to validate S/R
input double MaxRangeATR = 2.5;            // Max range size (ATR)
input double MinRangeATR = 0.4;            // Min range size (ATR)

input group "========== ENTRY REQUIREMENTS =========="
input bool RequireCandlePattern = true;    // Require confirmation pattern
input bool RequireMomentumAlign = true;    // RSI alignment
input int RSI_Period = 14;
input int RSI_OB = 70;                     // Overbought
input int RSI_OS = 30;                     // Oversold

input group "========== SCORING (Min 6/10) =========="
input int MinScore = 6;                    // Minimum score to trade
input int StructureWeight = 3;             // Structure alignment weight
input int PatternWeight = 2;               // Candle pattern weight
input int RangeQualityWeight = 2;          // Range quality weight
input int MomentumWeight = 2;              // Momentum weight
input int HTFWeight = 1;                   // HTF alignment weight

input group "========== EXIT =========="
input double TP1_RR = 1.5;
input double TP1_Percent = 50.0;
input double TP2_RR = 2.5;
input bool UseTrailing = true;
input double TrailingATR = 1.2;
input double MinRR = 1.5;

input group "========== SESSIONS =========="
input bool TradeLondon = true;             // 07-11 UTC (High volume)
input bool TradeNYOpen = true;             // 13-16 UTC (High volume)
input bool TradeOverlap = true;            // 13-16 UTC (London+NY)

input group "========== TIMEFRAMES =========="
input ENUM_TIMEFRAMES TF_Structure = PERIOD_H1;   // Structure analysis TF
input ENUM_TIMEFRAMES TF_Entry = PERIOD_M15;      // Entry TF
input ENUM_TIMEFRAMES TF_HTF = PERIOD_H4;         // HTF confirmation

input group "========== EA =========="
input int Magic = 567890;
input string TradeComment = "SBv5";
input bool Dashboard = true;
input bool DrawLevels = true;
input bool VerboseLog = true;

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct SwingPoint {
   datetime time;
   double price;
   bool isHigh;           // true = swing high, false = swing low
   int barIndex;
};

struct MarketStructure {
   ENUM_MARKET_STRUCTURE htfStructure;
   ENUM_MARKET_STRUCTURE mtfStructure;
   SwingPoint lastHH;
   SwingPoint lastHL;
   SwingPoint lastLH;
   SwingPoint lastLL;
   int direction;         // 1=Bullish, -1=Bearish, 0=Ranging
   double keyResistance;
   double keySupport;
   bool breakOfStructure; // Recent BOS
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
   bool isQuality;        // Has multiple touches + clean edges
   double consolidationScore; // 0-100 how clean is the range
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

struct Stats {
   int todayTrades;
   double dailyPnL;
   double totalDD;
   double startBalance;
   double dayStartBalance;
};

struct PropSettings {
   double maxDailyDD;
   double maxTotalDD;
   double riskPct;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo pos;
CAccountInfo acc;

MarketStructure g_structure;
RangeZone g_asianRange;
RangeZone g_londonRange;
EntrySignal g_currentSignal;
Stats g_stats;
PropSettings g_prop;

SwingPoint g_swingHighs[];
SwingPoint g_swingLows[];

int g_atrHandle, g_rsiHandle;
int g_emaFastH1, g_emaSlowH1;
int g_emaFastH4, g_emaSlowH4;

datetime g_lastBar;
double g_atr;
string g_statusMsg;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_stats.startBalance = acc.Balance();
   g_stats.dayStartBalance = g_stats.startBalance;

   LoadPropSettings();

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
   ResetRanges();

   Print("Session Breakout V5 - Structure-Based Scanner Initialized");
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
   ObjectsDeleteAll(0, "SBv5_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   datetime barTime = iTime(_Symbol, TF_Entry, 0);
   bool newBar = (barTime != g_lastBar);

   CheckDayReset();
   UpdateATR();

   if(!PassRiskChecks()) {
      if(Dashboard) ShowDashboard();
      return;
   }

   if(newBar) {
      g_lastBar = barTime;

      // 1. Analyze market structure
      AnalyzeMarketStructure();

      // 2. Calculate ranges
      CalculateRanges();

      // 3. Look for entry signals
      if(IsInTradingSession() && CanTrade()) {
         g_currentSignal = ScanForSignal();

         if(g_currentSignal.isValid && g_currentSignal.score >= MinScore) {
            ExecuteSignal(g_currentSignal);
         }
      }

      // 4. Manage positions
      ManagePositions();
   }

   if(DrawLevels) DrawOnChart();
   if(Dashboard) ShowDashboard();
}

//+------------------------------------------------------------------+
//| Load Prop Settings                                                |
//+------------------------------------------------------------------+
void LoadPropSettings() {
   switch(PropFirm) {
      case PROP_FTMO:
         g_prop.maxDailyDD = 4.5;
         g_prop.maxTotalDD = 9.0;
         g_prop.riskPct = (Mode == MODE_CHALLENGE) ? 1.5 : 0.75;
         break;
      case PROP_E8:
         g_prop.maxDailyDD = 4.5;
         g_prop.maxTotalDD = 7.5;
         g_prop.riskPct = (Mode == MODE_CHALLENGE) ? 1.2 : 0.6;
         break;
      case PROP_FUNDING_PIPS:
         g_prop.maxDailyDD = 3.5;
         g_prop.maxTotalDD = 5.5;
         g_prop.riskPct = (Mode == MODE_CHALLENGE) ? 1.0 : 0.5;
         break;
      case PROP_THE5ERS:
         g_prop.maxDailyDD = 3.0;
         g_prop.maxTotalDD = 4.5;
         g_prop.riskPct = (Mode == MODE_CHALLENGE) ? 0.8 : 0.4;
         break;
      default:
         g_prop.maxDailyDD = MaxDailyDD;
         g_prop.maxTotalDD = MaxTotalDD;
         g_prop.riskPct = RiskPercent;
   }
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
//| CORE: Analyze Market Structure (HH/HL/LH/LL)                     |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure() {
   // Clear old swings
   ArrayResize(g_swingHighs, 0);
   ArrayResize(g_swingLows, 0);

   // Get price data
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

   // Find swing highs and lows
   for(int i = SwingLookback; i < StructureBars; i++) {
      // Check for swing high
      if(IsSwingHigh(high, i, SwingLookback)) {
         SwingPoint sp;
         sp.price = high[i];
         sp.time = times[i];
         sp.isHigh = true;
         sp.barIndex = i;

         // Only add if significant size
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

      // Check for swing low
      if(IsSwingLow(low, i, SwingLookback)) {
         SwingPoint sp;
         sp.price = low[i];
         sp.time = times[i];
         sp.isHigh = false;
         sp.barIndex = i;

         // Only add if significant size
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

   // Determine structure
   DetermineStructure();

   // HTF Structure
   AnalyzeHTFStructure();
}

//+------------------------------------------------------------------+
//| Is Swing High                                                     |
//+------------------------------------------------------------------+
bool IsSwingHigh(double &high[], int index, int lookback) {
   double pivot = high[index];
   for(int i = 1; i <= lookback; i++) {
      if(high[index - i] >= pivot) return false;
      if(high[index + i] >= pivot) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Is Swing Low                                                      |
//+------------------------------------------------------------------+
bool IsSwingLow(double &low[], int index, int lookback) {
   double pivot = low[index];
   for(int i = 1; i <= lookback; i++) {
      if(low[index - i] <= pivot) return false;
      if(low[index + i] <= pivot) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Determine Structure (Bullish/Bearish/Ranging)                    |
//+------------------------------------------------------------------+
void DetermineStructure() {
   int numHighs = ArraySize(g_swingHighs);
   int numLows = ArraySize(g_swingLows);

   g_structure.mtfStructure = STRUCTURE_UNKNOWN;
   g_structure.direction = 0;
   g_structure.breakOfStructure = false;

   if(numHighs < 2 || numLows < 2) {
      g_structure.mtfStructure = STRUCTURE_RANGING;
      return;
   }

   // Get last 2 swing highs and lows (most recent first in array after sorting)
   SwingPoint sh1 = g_swingHighs[0];  // Most recent swing high
   SwingPoint sh2 = g_swingHighs[1];  // Previous swing high
   SwingPoint sl1 = g_swingLows[0];   // Most recent swing low
   SwingPoint sl2 = g_swingLows[1];   // Previous swing low

   // Store for reference
   g_structure.keyResistance = sh1.price;
   g_structure.keySupport = sl1.price;

   // Check for Higher Highs and Higher Lows (Bullish)
   bool higherHigh = (sh1.price > sh2.price);
   bool higherLow = (sl1.price > sl2.price);

   // Check for Lower Highs and Lower Lows (Bearish)
   bool lowerHigh = (sh1.price < sh2.price);
   bool lowerLow = (sl1.price < sl2.price);

   if(higherHigh && higherLow) {
      g_structure.mtfStructure = STRUCTURE_BULLISH;
      g_structure.direction = 1;
      g_structure.lastHH = sh1;
      g_structure.lastHL = sl1;

      // Check for Break of Structure (price broke above last HH)
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentPrice > sh1.price) {
         g_structure.breakOfStructure = true;
      }
   }
   else if(lowerHigh && lowerLow) {
      g_structure.mtfStructure = STRUCTURE_BEARISH;
      g_structure.direction = -1;
      g_structure.lastLH = sh1;
      g_structure.lastLL = sl1;

      // Check for Break of Structure (price broke below last LL)
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentPrice < sl1.price) {
         g_structure.breakOfStructure = true;
      }
   }
   else {
      g_structure.mtfStructure = STRUCTURE_RANGING;
      g_structure.direction = 0;
   }
}

//+------------------------------------------------------------------+
//| Analyze HTF Structure                                             |
//+------------------------------------------------------------------+
void AnalyzeHTFStructure() {
   double emaFast[], emaSlow[], close[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(close, true);

   CopyBuffer(g_emaFastH4, 0, 0, 5, emaFast);
   CopyBuffer(g_emaSlowH4, 0, 0, 5, emaSlow);
   CopyClose(_Symbol, TF_HTF, 0, 5, close);

   // Simple HTF trend based on EMA + price position + EMA slope
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
//| Reset Ranges                                                      |
//+------------------------------------------------------------------+
void ResetRanges() {
   ZeroMemory(g_asianRange);
   ZeroMemory(g_londonRange);
   g_asianRange.isValid = false;
   g_londonRange.isValid = false;
}

//+------------------------------------------------------------------+
//| Calculate Ranges                                                  |
//+------------------------------------------------------------------+
void CalculateRanges() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   // Asian Range (calculate after 06:00)
   if(UseAsianRange && h >= 6 && !g_asianRange.isValid) {
      CalculateRangeZone(g_asianRange, 0, 6);
   }

   // London Range (calculate after 10:00)
   if(UseLondonRange && h >= 10 && !g_londonRange.isValid) {
      CalculateRangeZone(g_londonRange, 7, 10);
   }
}

//+------------------------------------------------------------------+
//| Calculate Range Zone with Quality Check                          |
//+------------------------------------------------------------------+
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

   // Size validation
   double minSize = g_atr * MinRangeATR;
   double maxSize = g_atr * MaxRangeATR;

   if(zone.size < minSize || zone.size > maxSize) {
      zone.isValid = false;
      return;
   }

   // Count touches to high and low
   double touchZone = zone.size * 0.1;  // 10% of range
   zone.touchesHigh = 0;
   zone.touchesLow = 0;

   for(int i = 0; i < count; i++) {
      if(highs[i] >= zone.high - touchZone) zone.touchesHigh++;
      if(lows[i] <= zone.low + touchZone) zone.touchesLow++;
   }

   // Calculate consolidation score (how clean is the range)
   // - Multiple touches = good
   // - Price staying inside = good
   // - No wild spikes = good

   int outsideBars = 0;
   for(int i = 0; i < count; i++) {
      if(closes[i] > zone.high || closes[i] < zone.low) outsideBars++;
   }

   double insideRatio = 1.0 - ((double)outsideBars / count);
   double touchScore = MathMin(1.0, (zone.touchesHigh + zone.touchesLow) / 6.0);

   zone.consolidationScore = (insideRatio * 60) + (touchScore * 40);

   // Validate
   zone.isValid = (zone.touchesHigh >= MinRangeTouches || zone.touchesLow >= MinRangeTouches);
   zone.isQuality = (zone.consolidationScore >= 60 && zone.touchesHigh >= 2 && zone.touchesLow >= 2);
}

//+------------------------------------------------------------------+
//| CORE: Scan For Signal                                            |
//+------------------------------------------------------------------+
EntrySignal ScanForSignal() {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Check each valid range
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

//+------------------------------------------------------------------+
//| Check Range For Signal                                            |
//+------------------------------------------------------------------+
EntrySignal CheckRangeForSignal(RangeZone &zone, string zoneName, double bid, double ask) {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.isValid = false;

   double buffer = g_atr * 0.15;

   // ========================================
   // 1. BREAKOUT WITH STRUCTURE ALIGNMENT
   // ========================================

   // Bullish breakout (price above range high)
   if(bid > zone.high + buffer && bid < zone.high + zone.size) {
      // MUST be in bullish structure or ranging (not bearish)
      if(g_structure.direction >= 0) {
         signal = BuildBreakoutSignal(zone, zoneName, 1, bid, ask);
         if(signal.isValid && signal.score >= MinScore) return signal;
      }
   }

   // Bearish breakout (price below range low)
   if(ask < zone.low - buffer && ask > zone.low - zone.size) {
      // MUST be in bearish structure or ranging (not bullish)
      if(g_structure.direction <= 0) {
         signal = BuildBreakoutSignal(zone, zoneName, -1, bid, ask);
         if(signal.isValid && signal.score >= MinScore) return signal;
      }
   }

   // ========================================
   // 2. RETEST ENTRY (After breakout)
   // ========================================

   // Bullish retest (broke up, came back to test)
   if(bid > zone.high - zone.size * 0.2 && bid <= zone.high + buffer) {
      if(g_structure.direction == 1) {  // Must be bullish structure
         signal = BuildRetestSignal(zone, zoneName, 1, bid, ask);
         if(signal.isValid && signal.score >= MinScore) return signal;
      }
   }

   // Bearish retest
   if(ask < zone.low + zone.size * 0.2 && ask >= zone.low - buffer) {
      if(g_structure.direction == -1) {  // Must be bearish structure
         signal = BuildRetestSignal(zone, zoneName, -1, bid, ask);
         if(signal.isValid && signal.score >= MinScore) return signal;
      }
   }

   // ========================================
   // 3. CONTINUATION (Pullback in trend)
   // ========================================

   // Bullish continuation at zone low
   if(bid <= zone.low + zone.size * 0.3 && bid >= zone.low - buffer) {
      if(g_structure.direction == 1 && g_structure.htfStructure == STRUCTURE_BULLISH) {
         signal = BuildContinuationSignal(zone, zoneName, 1, bid, ask);
         if(signal.isValid && signal.score >= MinScore) return signal;
      }
   }

   // Bearish continuation at zone high
   if(ask >= zone.high - zone.size * 0.3 && ask <= zone.high + buffer) {
      if(g_structure.direction == -1 && g_structure.htfStructure == STRUCTURE_BEARISH) {
         signal = BuildContinuationSignal(zone, zoneName, -1, bid, ask);
         if(signal.isValid && signal.score >= MinScore) return signal;
      }
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Build Breakout Signal                                             |
//+------------------------------------------------------------------+
EntrySignal BuildBreakoutSignal(RangeZone &zone, string zoneName, int dir, double bid, double ask) {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.setup = SETUP_BREAKOUT;
   signal.direction = dir;
   signal.isValid = false;

   // Check for candle pattern
   ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(dir);
   if(RequireCandlePattern && pattern == PATTERN_NONE) {
      return signal;
   }
   signal.pattern = pattern;

   // Check momentum
   if(RequireMomentumAlign && !IsMomentumAligned(dir)) {
      return signal;
   }

   // Entry, SL, TP
   if(dir == 1) {
      signal.entryPrice = ask;
      signal.slPrice = zone.low - g_atr * 0.2;
      signal.tp1Price = ask + (ask - signal.slPrice) * TP1_RR;
      signal.tp2Price = ask + (ask - signal.slPrice) * TP2_RR;
   } else {
      signal.entryPrice = bid;
      signal.slPrice = zone.high + g_atr * 0.2;
      signal.tp1Price = bid - (signal.slPrice - bid) * TP1_RR;
      signal.tp2Price = bid - (signal.slPrice - bid) * TP2_RR;
   }

   // Check RR
   double risk = MathAbs(signal.entryPrice - signal.slPrice);
   double reward = MathAbs(signal.tp1Price - signal.entryPrice);
   signal.rr = (risk > 0) ? reward / risk : 0;

   if(signal.rr < MinRR) {
      return signal;
   }

   // Calculate score
   signal.score = CalculateSignalScore(signal, zone, dir);
   signal.reason = zoneName + " Breakout " + (dir == 1 ? "Long" : "Short");
   signal.isValid = true;

   return signal;
}

//+------------------------------------------------------------------+
//| Build Retest Signal                                               |
//+------------------------------------------------------------------+
EntrySignal BuildRetestSignal(RangeZone &zone, string zoneName, int dir, double bid, double ask) {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.setup = SETUP_RETEST;
   signal.direction = dir;
   signal.isValid = false;

   // Retest REQUIRES candle pattern (rejection)
   ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(dir);
   if(pattern == PATTERN_NONE) {
      return signal;
   }
   signal.pattern = pattern;

   // Momentum should be aligned
   if(!IsMomentumAligned(dir)) {
      return signal;
   }

   // Entry, SL, TP (tighter SL for retest)
   if(dir == 1) {
      signal.entryPrice = ask;
      signal.slPrice = zone.mid - g_atr * 0.1;
      signal.tp1Price = ask + (ask - signal.slPrice) * TP1_RR;
      signal.tp2Price = ask + (ask - signal.slPrice) * TP2_RR;
   } else {
      signal.entryPrice = bid;
      signal.slPrice = zone.mid + g_atr * 0.1;
      signal.tp1Price = bid - (signal.slPrice - bid) * TP1_RR;
      signal.tp2Price = bid - (signal.slPrice - bid) * TP2_RR;
   }

   double risk = MathAbs(signal.entryPrice - signal.slPrice);
   double reward = MathAbs(signal.tp1Price - signal.entryPrice);
   signal.rr = (risk > 0) ? reward / risk : 0;

   if(signal.rr < MinRR) {
      return signal;
   }

   signal.score = CalculateSignalScore(signal, zone, dir) + 1;  // Bonus for retest
   signal.reason = zoneName + " Retest " + (dir == 1 ? "Long" : "Short");
   signal.isValid = true;

   return signal;
}

//+------------------------------------------------------------------+
//| Build Continuation Signal                                         |
//+------------------------------------------------------------------+
EntrySignal BuildContinuationSignal(RangeZone &zone, string zoneName, int dir, double bid, double ask) {
   EntrySignal signal;
   ZeroMemory(signal);
   signal.setup = SETUP_CONTINUATION;
   signal.direction = dir;
   signal.isValid = false;

   // Continuation REQUIRES strong pattern
   ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(dir);
   if(pattern != PATTERN_ENGULFING && pattern != PATTERN_PIN_BAR) {
      return signal;
   }
   signal.pattern = pattern;

   // Entry, SL, TP
   if(dir == 1) {
      signal.entryPrice = ask;
      signal.slPrice = zone.low - g_atr * 0.15;
      signal.tp1Price = zone.high + zone.size * 0.5;
      signal.tp2Price = zone.high + zone.size;
   } else {
      signal.entryPrice = bid;
      signal.slPrice = zone.high + g_atr * 0.15;
      signal.tp1Price = zone.low - zone.size * 0.5;
      signal.tp2Price = zone.low - zone.size;
   }

   double risk = MathAbs(signal.entryPrice - signal.slPrice);
   double reward = MathAbs(signal.tp1Price - signal.entryPrice);
   signal.rr = (risk > 0) ? reward / risk : 0;

   if(signal.rr < MinRR) {
      return signal;
   }

   signal.score = CalculateSignalScore(signal, zone, dir) + 2;  // Bonus for continuation
   signal.reason = zoneName + " Continuation " + (dir == 1 ? "Long" : "Short");
   signal.isValid = true;

   return signal;
}

//+------------------------------------------------------------------+
//| Detect Candle Pattern                                             |
//+------------------------------------------------------------------+
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

   // Candle 1 = completed candle (index 1)
   double body1 = MathAbs(close[1] - open[1]);
   double upperWick1 = high[1] - MathMax(close[1], open[1]);
   double lowerWick1 = MathMin(close[1], open[1]) - low[1];
   double range1 = high[1] - low[1];
   bool bullCandle1 = (close[1] > open[1]);
   bool bearCandle1 = (close[1] < open[1]);

   // Candle 2 = previous candle (index 2)
   double body2 = MathAbs(close[2] - open[2]);
   bool bullCandle2 = (close[2] > open[2]);
   bool bearCandle2 = (close[2] < open[2]);

   // ========== PIN BAR ==========
   // Bullish pin bar: Long lower wick, small body at top
   if(dir == 1) {
      if(lowerWick1 > body1 * 2.0 && lowerWick1 > upperWick1 * 2.0) {
         if(close[1] > (high[1] + low[1]) / 2) {  // Close in upper half
            return PATTERN_PIN_BAR;
         }
      }
   }
   // Bearish pin bar: Long upper wick, small body at bottom
   if(dir == -1) {
      if(upperWick1 > body1 * 2.0 && upperWick1 > lowerWick1 * 2.0) {
         if(close[1] < (high[1] + low[1]) / 2) {  // Close in lower half
            return PATTERN_PIN_BAR;
         }
      }
   }

   // ========== ENGULFING ==========
   // Bullish engulfing
   if(dir == 1 && bullCandle1 && bearCandle2) {
      if(body1 > body2 * 1.2 && close[1] > open[2] && open[1] < close[2]) {
         return PATTERN_ENGULFING;
      }
   }
   // Bearish engulfing
   if(dir == -1 && bearCandle1 && bullCandle2) {
      if(body1 > body2 * 1.2 && close[1] < open[2] && open[1] > close[2]) {
         return PATTERN_ENGULFING;
      }
   }

   // ========== REJECTION ==========
   // Strong momentum candle in direction
   if(dir == 1 && bullCandle1 && body1 > g_atr * 0.3) {
      if(close[1] > high[2]) {  // Closed above previous high
         return PATTERN_REJECTION;
      }
   }
   if(dir == -1 && bearCandle1 && body1 > g_atr * 0.3) {
      if(close[1] < low[2]) {  // Closed below previous low
         return PATTERN_REJECTION;
      }
   }

   // ========== INSIDE BAR BREAKOUT ==========
   // Current candle breaks out of inside bar
   bool isInsideBar2 = (high[2] < high[3] && low[2] > low[3]);
   if(isInsideBar2) {
      if(dir == 1 && close[1] > high[2]) return PATTERN_INSIDE_BAR_BO;
      if(dir == -1 && close[1] < low[2]) return PATTERN_INSIDE_BAR_BO;
   }

   return PATTERN_NONE;
}

//+------------------------------------------------------------------+
//| Is Momentum Aligned                                               |
//+------------------------------------------------------------------+
bool IsMomentumAligned(int dir) {
   double rsi[];
   ArraySetAsSeries(rsi, true);
   CopyBuffer(g_rsiHandle, 0, 0, 3, rsi);

   // For longs: RSI should be rising and not overbought
   if(dir == 1) {
      if(rsi[0] > rsi[1] && rsi[0] < RSI_OB && rsi[0] > 40) {
         return true;
      }
   }
   // For shorts: RSI should be falling and not oversold
   if(dir == -1) {
      if(rsi[0] < rsi[1] && rsi[0] > RSI_OS && rsi[0] < 60) {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calculate Signal Score                                            |
//+------------------------------------------------------------------+
int CalculateSignalScore(EntrySignal &signal, RangeZone &zone, int dir) {
   int score = 0;

   // 1. STRUCTURE ALIGNMENT (Most important)
   if(RequireStructureAlignment) {
      if(g_structure.direction == dir) {
         score += StructureWeight;  // Full points for alignment
      }
      else if(g_structure.direction == 0) {
         score += StructureWeight / 2;  // Half points for ranging
      }
      // No points if against structure
   } else {
      score += StructureWeight / 2;  // Base score if not filtering
   }

   // 2. HTF ALIGNMENT
   if(g_structure.htfStructure == STRUCTURE_BULLISH && dir == 1) score += HTFWeight;
   if(g_structure.htfStructure == STRUCTURE_BEARISH && dir == -1) score += HTFWeight;

   // 3. CANDLE PATTERN
   if(signal.pattern == PATTERN_ENGULFING) score += PatternWeight;
   else if(signal.pattern == PATTERN_PIN_BAR) score += PatternWeight;
   else if(signal.pattern == PATTERN_INSIDE_BAR_BO) score += PatternWeight - 1;
   else if(signal.pattern == PATTERN_REJECTION) score += PatternWeight - 1;

   // 4. RANGE QUALITY
   if(zone.isQuality) score += RangeQualityWeight;
   else if(zone.consolidationScore >= 50) score += RangeQualityWeight / 2;

   // 5. MOMENTUM
   if(IsMomentumAligned(dir)) score += MomentumWeight;

   return score;
}

//+------------------------------------------------------------------+
//| Execute Signal                                                    |
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
      g_stats.todayTrades++;
      if(VerboseLog) {
         Print("=== TRADE EXECUTED ===");
         Print("Signal: ", signal.reason);
         Print("Pattern: ", EnumToString(signal.pattern));
         Print("Structure: ", EnumToString(g_structure.mtfStructure));
         Print("Score: ", signal.score, "/10");
         Print("RR: ", DoubleToString(signal.rr, 2));
         Print("Entry: ", signal.entryPrice, " SL: ", signal.slPrice, " TP: ", signal.tp1Price);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Lots                                                    |
//+------------------------------------------------------------------+
double CalculateLots(double entry, double sl) {
   double riskAmt = acc.Balance() * (g_prop.riskPct / 100);
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
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != Magic) continue;

      double entry = pos.PriceOpen();
      double sl = pos.StopLoss();
      double tp = pos.TakeProfit();
      ulong ticket = pos.Ticket();
      bool isLong = (pos.PositionType() == POSITION_TYPE_BUY);

      double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Trailing
      if(UseTrailing && pos.Profit() > 0) {
         double trail = g_atr * TrailingATR;
         if(isLong && price - entry > trail) {
            double newSL = price - trail;
            if(newSL > sl) trade.PositionModify(ticket, newSL, tp);
         }
         else if(!isLong && entry - price > trail) {
            double newSL = price + trail;
            if(newSL < sl) trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count Positions                                                   |
//+------------------------------------------------------------------+
int CountPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol && pos.Magic() == Magic) count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Can Trade                                                         |
//+------------------------------------------------------------------+
bool CanTrade() {
   if(g_stats.todayTrades >= MaxTradesDay) return false;
   if(CountPositions() >= MaxOpenTrades) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Is In Trading Session                                             |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(TradeLondon && h >= 7 && h < 11) return true;
   if(TradeNYOpen && h >= 13 && h < 16) return true;
   if(TradeOverlap && h >= 13 && h < 16) return true;

   return false;
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
         g_stats.dayStartBalance = acc.Balance();
         g_stats.todayTrades = 0;
         ResetRanges();
      }
      lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| Pass Risk Checks                                                  |
//+------------------------------------------------------------------+
bool PassRiskChecks() {
   double equity = acc.Equity();
   g_stats.dailyPnL = ((equity - g_stats.dayStartBalance) / g_stats.dayStartBalance) * 100;
   g_stats.totalDD = ((g_stats.startBalance - equity) / g_stats.startBalance) * 100;

   if(g_stats.dailyPnL <= -g_prop.maxDailyDD) {
      CloseAll("Daily DD");
      return false;
   }

   if(g_stats.totalDD >= g_prop.maxTotalDD) {
      CloseAll("Total DD");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Close All                                                         |
//+------------------------------------------------------------------+
void CloseAll(string reason) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol && pos.Magic() == Magic) {
            trade.PositionClose(pos.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw On Chart                                                     |
//+------------------------------------------------------------------+
void DrawOnChart() {
   // Ranges
   if(g_asianRange.isValid) DrawRangeBox("SBv5_Asian", g_asianRange, clrDodgerBlue);
   if(g_londonRange.isValid) DrawRangeBox("SBv5_London", g_londonRange, clrOrange);

   // Key levels from structure
   if(g_structure.keyResistance > 0) {
      DrawHLine("SBv5_Resistance", g_structure.keyResistance, clrRed);
   }
   if(g_structure.keySupport > 0) {
      DrawHLine("SBv5_Support", g_structure.keySupport, clrGreen);
   }

   // Swing points
   for(int i = 0; i < MathMin(4, ArraySize(g_swingHighs)); i++) {
      DrawSwingPoint("SBv5_SH_" + IntegerToString(i), g_swingHighs[i], clrRed);
   }
   for(int i = 0; i < MathMin(4, ArraySize(g_swingLows)); i++) {
      DrawSwingPoint("SBv5_SL_" + IntegerToString(i), g_swingLows[i], clrGreen);
   }
}

void DrawRangeBox(string name, RangeZone &range, color clr) {
   ObjectDelete(0, name);
   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H1);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, range.startTime, range.high, endTime, range.low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, range.isQuality ? STYLE_SOLID : STYLE_DOT);
}

void DrawHLine(string name, double price, color clr) {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
}

void DrawSwingPoint(string name, SwingPoint &sp, color clr) {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_ARROW, 0, sp.time, sp.price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, sp.isHigh ? 234 : 233);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Show Dashboard                                                    |
//+------------------------------------------------------------------+
void ShowDashboard() {
   string s = "";
   s += "==============================================\n";
   s += "   SESSION BREAKOUT V5 - STRUCTURE BASED\n";
   s += "==============================================\n";
   s += EnumToString(PropFirm) + " | " + EnumToString(Mode) + "\n";
   s += "----------------------------------------------\n";

   // Structure
   s += "           MARKET STRUCTURE\n";
   s += "----------------------------------------------\n";
   s += "MTF: " + GetStructureString(g_structure.mtfStructure) + "\n";
   s += "HTF: " + GetStructureString(g_structure.htfStructure) + "\n";
   s += "Direction: " + (g_structure.direction == 1 ? "BULLISH" : (g_structure.direction == -1 ? "BEARISH" : "NEUTRAL")) + "\n";
   s += "BOS: " + (g_structure.breakOfStructure ? "YES" : "NO") + "\n";
   s += "----------------------------------------------\n";

   // Key levels
   s += "Key Resistance: " + DoubleToString(g_structure.keyResistance, _Digits) + "\n";
   s += "Key Support: " + DoubleToString(g_structure.keySupport, _Digits) + "\n";
   s += "Swings: " + IntegerToString(ArraySize(g_swingHighs)) + " HI / " + IntegerToString(ArraySize(g_swingLows)) + " LO\n";
   s += "----------------------------------------------\n";

   // Ranges
   s += "                RANGES\n";
   s += "----------------------------------------------\n";
   s += "Asian:  " + (g_asianRange.isValid ? ("VALID " + (g_asianRange.isQuality ? "[HQ]" : "[LQ]")) : "---") + "\n";
   if(g_asianRange.isValid) {
      s += "  Score: " + IntegerToString((int)g_asianRange.consolidationScore) + "% | Touches: " + IntegerToString(g_asianRange.touchesHigh) + "H/" + IntegerToString(g_asianRange.touchesLow) + "L\n";
   }
   s += "London: " + (g_londonRange.isValid ? ("VALID " + (g_londonRange.isQuality ? "[HQ]" : "[LQ]")) : "---") + "\n";
   s += "----------------------------------------------\n";

   // Current signal
   s += "             CURRENT SIGNAL\n";
   s += "----------------------------------------------\n";
   if(g_currentSignal.isValid) {
      s += "Setup: " + g_currentSignal.reason + "\n";
      s += "Pattern: " + EnumToString(g_currentSignal.pattern) + "\n";
      s += "Score: " + IntegerToString(g_currentSignal.score) + "/" + IntegerToString(MinScore) + " min\n";
      s += "RR: " + DoubleToString(g_currentSignal.rr, 2) + "\n";
   } else {
      s += "No valid signal\n";
   }
   s += "----------------------------------------------\n";

   // Stats
   s += "                STATS\n";
   s += "----------------------------------------------\n";
   s += StringFormat("Daily: %.2f%% | DD: %.2f%%\n", g_stats.dailyPnL, g_stats.totalDD);
   s += StringFormat("Trades: %d/%d | Open: %d/%d\n", g_stats.todayTrades, MaxTradesDay, CountPositions(), MaxOpenTrades);
   s += "Session: " + (IsInTradingSession() ? "ACTIVE" : "CLOSED") + "\n";
   s += "==============================================\n";

   Comment(s);
}

string GetStructureString(ENUM_MARKET_STRUCTURE str) {
   switch(str) {
      case STRUCTURE_BULLISH: return "BULLISH (HH+HL)";
      case STRUCTURE_BEARISH: return "BEARISH (LH+LL)";
      case STRUCTURE_RANGING: return "RANGING";
      default: return "UNKNOWN";
   }
}
//+------------------------------------------------------------------+
