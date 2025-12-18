//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v4.mq5 |
//|                    MULTI-OPPORTUNITY SCANNER - More Trades       |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "4.00"
#property description "V4: Multi-range scanner + More opportunities"
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

enum ENUM_RANGE_TYPE {
   RANGE_ASIAN,
   RANGE_LONDON,
   RANGE_INTRADAY
};

enum ENUM_SETUP_TYPE {
   SETUP_BREAKOUT,
   SETUP_RETEST,
   SETUP_FAILED_BO,
   SETUP_STRUCTURE
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
input int MaxTradesDay = 6;
input int MaxOpenTrades = 2;

input group "========== MULTI-RANGE SCANNER =========="
input bool UseAsianRange = true;           // Asian Range (00-06 UTC)
input bool UseLondonRange = true;          // London Range (07-10 UTC)
input bool UseIntradayRange = true;        // Intraday micro-ranges
input int IntradayRangeHours = 3;          // Intraday range period
input bool UseVolatilitySqueeze = true;    // Detect compression zones

input group "========== ENTRY TYPES =========="
input bool TradeBreakouts = true;          // Classic Breakout
input bool TradeRetests = true;            // Retest Entry
input bool TradeFailedBreakouts = true;    // Failed BO Reversal
input bool TradeStructure = true;          // S/R Bounce

input group "========== OPPORTUNITY SCANNER =========="
input int MinOpportunityScore = 3;         // Min Score (1-10) - Lower = More trades
input bool UseBiasFilter = true;           // Directional Bias
input bool UseCompressionBonus = true;     // Bonus for squeeze
input double MinRR = 1.2;                  // Minimum R:R

input group "========== CONFLUENCE =========="
input ENUM_TIMEFRAMES HTF = PERIOD_H4;
input ENUM_TIMEFRAMES MTF = PERIOD_H1;
input ENUM_TIMEFRAMES LTF = PERIOD_M15;
input int EMA_Fast = 21;
input int EMA_Slow = 50;
input double MinADX = 18.0;                // Lower = More trades

input group "========== EXIT =========="
input double TP1_RR = 1.5;
input double TP1_Percent = 50.0;
input double TP2_RR = 2.5;
input bool UseTrailing = true;
input double TrailingATR = 1.0;

input group "========== SESSIONS =========="
input bool TradeLondonSession = true;      // 07-16 UTC
input bool TradeNYSession = true;          // 13-21 UTC
input bool TradeAsianSession = false;      // 00-06 UTC (optional)

input group "========== EA =========="
input int Magic = 456789;
input string TradeComment = "SBv4";
input bool Dashboard = true;
input bool DrawLevels = true;

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct RangeInfo {
   ENUM_RANGE_TYPE type;
   double high;
   double low;
   double mid;
   double size;
   datetime startTime;
   datetime endTime;
   bool valid;
   bool breakoutUp;
   bool breakoutDown;
   bool failedBreakout;
   int failedDir;
};

struct Opportunity {
   ENUM_SETUP_TYPE setup;
   ENUM_RANGE_TYPE rangeType;
   int direction;          // 1=Long, -1=Short
   double entryPrice;
   double slPrice;
   double tpPrice;
   int score;
   double rr;
   bool valid;
   string reason;
};

struct MarketBias {
   int htfBias;            // 1=Bull, -1=Bear, 0=Neutral
   int mtfBias;
   int ltfBias;
   double adx;
   bool isTrending;
   bool isCompressed;
   double bbWidth;
};

struct Stats {
   int todayTrades;
   int todayWins;
   int todayLosses;
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

RangeInfo g_asianRange;
RangeInfo g_londonRange;
RangeInfo g_intradayRange;

Opportunity g_opportunities[];
MarketBias g_bias;
Stats g_stats;
PropSettings g_prop;

int g_atrHandle, g_adxHandle, g_bbHandle;
int g_emaFastHTF, g_emaSlowHTF;
int g_emaFastMTF, g_emaSlowMTF;
int g_emaFastLTF;

datetime g_lastBar;
datetime g_lastScan;
double g_atr;
int g_opportunityCount;

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
   g_atrHandle = iATR(_Symbol, MTF, 14);
   g_adxHandle = iADX(_Symbol, MTF, 14);
   g_bbHandle = iBands(_Symbol, MTF, 20, 0, 2.0, PRICE_CLOSE);

   g_emaFastHTF = iMA(_Symbol, HTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHTF = iMA(_Symbol, HTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_emaFastMTF = iMA(_Symbol, MTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowMTF = iMA(_Symbol, MTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_emaFastLTF = iMA(_Symbol, LTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);

   if(g_atrHandle == INVALID_HANDLE || g_adxHandle == INVALID_HANDLE || g_bbHandle == INVALID_HANDLE) {
      Print("Indicator error");
      return INIT_FAILED;
   }

   ArrayResize(g_opportunities, 0);
   ResetRanges();

   Print("Session Breakout V4 - Multi-Opportunity Scanner");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_adxHandle);
   IndicatorRelease(g_bbHandle);
   IndicatorRelease(g_emaFastHTF);
   IndicatorRelease(g_emaSlowHTF);
   IndicatorRelease(g_emaFastMTF);
   IndicatorRelease(g_emaSlowMTF);
   IndicatorRelease(g_emaFastLTF);
   ObjectsDeleteAll(0, "SBv4_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   datetime barTime = iTime(_Symbol, LTF, 0);
   bool newBar = (barTime != g_lastBar);

   CheckDayReset();
   UpdateIndicators();
   UpdateMarketBias();

   if(!PassRiskChecks()) {
      if(Dashboard) ShowDashboard();
      return;
   }

   // Calculate all ranges
   CalculateRanges();

   if(newBar) {
      g_lastBar = barTime;

      // Scan for opportunities every 15 min
      if(IsInTradingSession()) {
         ScanOpportunities();
         ProcessOpportunities();
      }

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
//| Reset Ranges                                                      |
//+------------------------------------------------------------------+
void ResetRanges() {
   ResetRange(g_asianRange, RANGE_ASIAN);
   ResetRange(g_londonRange, RANGE_LONDON);
   ResetRange(g_intradayRange, RANGE_INTRADAY);
}

void ResetRange(RangeInfo &range, ENUM_RANGE_TYPE type) {
   range.type = type;
   range.high = 0;
   range.low = DBL_MAX;
   range.valid = false;
   range.breakoutUp = false;
   range.breakoutDown = false;
   range.failedBreakout = false;
   range.failedDir = 0;
}

//+------------------------------------------------------------------+
//| Update Indicators                                                 |
//+------------------------------------------------------------------+
void UpdateIndicators() {
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0) {
      g_atr = atr[0];
   }
}

//+------------------------------------------------------------------+
//| Update Market Bias                                                |
//+------------------------------------------------------------------+
void UpdateMarketBias() {
   // HTF Bias
   double emaFastHTF[], emaSlowHTF[], closeHTF[];
   ArraySetAsSeries(emaFastHTF, true);
   ArraySetAsSeries(emaSlowHTF, true);
   ArraySetAsSeries(closeHTF, true);

   CopyBuffer(g_emaFastHTF, 0, 0, 2, emaFastHTF);
   CopyBuffer(g_emaSlowHTF, 0, 0, 2, emaSlowHTF);
   CopyClose(_Symbol, HTF, 0, 2, closeHTF);

   if(emaFastHTF[0] > emaSlowHTF[0] && closeHTF[0] > emaFastHTF[0])
      g_bias.htfBias = 1;
   else if(emaFastHTF[0] < emaSlowHTF[0] && closeHTF[0] < emaFastHTF[0])
      g_bias.htfBias = -1;
   else
      g_bias.htfBias = 0;

   // MTF Bias
   double emaFastMTF[], emaSlowMTF[];
   ArraySetAsSeries(emaFastMTF, true);
   ArraySetAsSeries(emaSlowMTF, true);

   CopyBuffer(g_emaFastMTF, 0, 0, 2, emaFastMTF);
   CopyBuffer(g_emaSlowMTF, 0, 0, 2, emaSlowMTF);

   g_bias.mtfBias = (emaFastMTF[0] > emaSlowMTF[0]) ? 1 : -1;

   // LTF Bias
   double emaFastLTF[], closeLTF[];
   ArraySetAsSeries(emaFastLTF, true);
   ArraySetAsSeries(closeLTF, true);

   CopyBuffer(g_emaFastLTF, 0, 0, 2, emaFastLTF);
   CopyClose(_Symbol, LTF, 0, 2, closeLTF);

   g_bias.ltfBias = (closeLTF[0] > emaFastLTF[0]) ? 1 : -1;

   // ADX
   double adx[];
   ArraySetAsSeries(adx, true);
   CopyBuffer(g_adxHandle, 0, 0, 1, adx);
   g_bias.adx = adx[0];
   g_bias.isTrending = (adx[0] >= MinADX);

   // Bollinger compression
   double bbUpper[], bbLower[], bbMid[];
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(bbMid, true);

   CopyBuffer(g_bbHandle, 1, 0, 20, bbUpper);
   CopyBuffer(g_bbHandle, 2, 0, 20, bbLower);

   // Current BB width vs average
   double currentWidth = bbUpper[0] - bbLower[0];
   double avgWidth = 0;
   for(int i = 0; i < 20; i++) {
      avgWidth += bbUpper[i] - bbLower[i];
   }
   avgWidth /= 20;

   g_bias.bbWidth = currentWidth;
   g_bias.isCompressed = (currentWidth < avgWidth * 0.7);  // Squeeze detected
}

//+------------------------------------------------------------------+
//| Calculate All Ranges                                              |
//+------------------------------------------------------------------+
void CalculateRanges() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   // Asian Range (calculate after 06:00)
   if(UseAsianRange && h >= 6 && !g_asianRange.valid) {
      CalculateRange(g_asianRange, 0, 6);
   }

   // London Range (calculate after 10:00)
   if(UseLondonRange && h >= 10 && !g_londonRange.valid) {
      CalculateRange(g_londonRange, 7, 10);
   }

   // Intraday Range (recalculate every few hours)
   if(UseIntradayRange) {
      datetime now = TimeCurrent();
      if(now - g_intradayRange.endTime > IntradayRangeHours * 3600 || !g_intradayRange.valid) {
         CalculateIntradayRange();
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Fixed Time Range                                        |
//+------------------------------------------------------------------+
void CalculateRange(RangeInfo &range, int startHour, int endHour) {
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
   range.startTime = startTime;
   range.endTime = endTime;

   // Validate
   double minSize = g_atr * 0.3;
   double maxSize = g_atr * 3.0;
   range.valid = (range.size >= minSize && range.size <= maxSize);
}

//+------------------------------------------------------------------+
//| Calculate Intraday Range                                          |
//+------------------------------------------------------------------+
void CalculateIntradayRange() {
   datetime now = TimeCurrent();
   datetime startTime = now - (IntradayRangeHours * 3600);

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int bars = IntradayRangeHours * 4;  // M15 bars
   if(CopyHigh(_Symbol, PERIOD_M15, 0, bars, highs) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M15, 0, bars, lows) <= 0) return;

   g_intradayRange.high = highs[ArrayMaximum(highs)];
   g_intradayRange.low = lows[ArrayMinimum(lows)];
   g_intradayRange.mid = (g_intradayRange.high + g_intradayRange.low) / 2;
   g_intradayRange.size = g_intradayRange.high - g_intradayRange.low;
   g_intradayRange.startTime = startTime;
   g_intradayRange.endTime = now;

   double minSize = g_atr * 0.2;
   double maxSize = g_atr * 2.5;
   g_intradayRange.valid = (g_intradayRange.size >= minSize && g_intradayRange.size <= maxSize);
}

//+------------------------------------------------------------------+
//| Scan Opportunities                                                |
//+------------------------------------------------------------------+
void ScanOpportunities() {
   ArrayResize(g_opportunities, 0);
   g_opportunityCount = 0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Scan each valid range
   if(g_asianRange.valid) {
      ScanRangeOpportunities(g_asianRange, bid, ask);
   }

   if(g_londonRange.valid) {
      ScanRangeOpportunities(g_londonRange, bid, ask);
   }

   if(g_intradayRange.valid) {
      ScanRangeOpportunities(g_intradayRange, bid, ask);
   }

   // Sort by score
   SortOpportunities();
}

//+------------------------------------------------------------------+
//| Scan Range for Opportunities                                      |
//+------------------------------------------------------------------+
void ScanRangeOpportunities(RangeInfo &range, double bid, double ask) {
   double buffer = g_atr * 0.1;

   // 1. BREAKOUT OPPORTUNITIES
   if(TradeBreakouts) {
      // Bullish breakout
      if(!range.breakoutUp && bid > range.high + buffer) {
         CheckBreakoutSetup(range, 1, bid, ask);
      }
      // Bearish breakout
      if(!range.breakoutDown && ask < range.low - buffer) {
         CheckBreakoutSetup(range, -1, bid, ask);
      }
   }

   // 2. RETEST OPPORTUNITIES (after breakout)
   if(TradeRetests) {
      if(range.breakoutUp && bid <= range.high && bid >= range.high - range.size * 0.3) {
         CheckRetestSetup(range, 1, bid, ask);
      }
      if(range.breakoutDown && ask >= range.low && ask <= range.low + range.size * 0.3) {
         CheckRetestSetup(range, -1, bid, ask);
      }
   }

   // 3. FAILED BREAKOUT (FADE)
   if(TradeFailedBreakouts) {
      CheckFailedBreakout(range, bid, ask);
   }

   // 4. STRUCTURE BOUNCE
   if(TradeStructure) {
      // Near range high (resistance)
      if(ask >= range.high - range.size * 0.1 && ask <= range.high + buffer) {
         CheckStructureSetup(range, -1, bid, ask);  // Short at resistance
      }
      // Near range low (support)
      if(bid <= range.low + range.size * 0.1 && bid >= range.low - buffer) {
         CheckStructureSetup(range, 1, bid, ask);   // Long at support
      }
   }
}

//+------------------------------------------------------------------+
//| Check Breakout Setup                                              |
//+------------------------------------------------------------------+
void CheckBreakoutSetup(RangeInfo &range, int dir, double bid, double ask) {
   Opportunity opp;
   opp.setup = SETUP_BREAKOUT;
   opp.rangeType = range.type;
   opp.direction = dir;
   opp.valid = true;
   opp.score = 0;

   // Entry & SL
   if(dir == 1) {
      opp.entryPrice = ask;
      opp.slPrice = range.low - g_atr * 0.3;
      opp.tpPrice = ask + (ask - opp.slPrice) * TP1_RR;
   } else {
      opp.entryPrice = bid;
      opp.slPrice = range.high + g_atr * 0.3;
      opp.tpPrice = bid - (opp.slPrice - bid) * TP1_RR;
   }

   // Calculate RR
   double risk = MathAbs(opp.entryPrice - opp.slPrice);
   double reward = MathAbs(opp.tpPrice - opp.entryPrice);
   opp.rr = (risk > 0) ? reward / risk : 0;

   if(opp.rr < MinRR) {
      opp.valid = false;
      return;
   }

   // SCORING
   opp.score = CalculateScore(dir, opp.setup);
   opp.reason = "Breakout " + EnumToString(range.type);

   if(opp.score >= MinOpportunityScore) {
      AddOpportunity(opp);

      // Mark breakout
      if(dir == 1) range.breakoutUp = true;
      else range.breakoutDown = true;
   }
}

//+------------------------------------------------------------------+
//| Check Retest Setup                                                |
//+------------------------------------------------------------------+
void CheckRetestSetup(RangeInfo &range, int dir, double bid, double ask) {
   // Check for rejection candle
   double close[], open[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   CopyClose(_Symbol, LTF, 0, 3, close);
   CopyOpen(_Symbol, LTF, 0, 3, open);

   bool rejection = false;
   if(dir == 1 && close[1] > open[1] && close[1] > close[2]) rejection = true;
   if(dir == -1 && close[1] < open[1] && close[1] < close[2]) rejection = true;

   if(!rejection) return;

   Opportunity opp;
   opp.setup = SETUP_RETEST;
   opp.rangeType = range.type;
   opp.direction = dir;
   opp.valid = true;

   if(dir == 1) {
      opp.entryPrice = ask;
      opp.slPrice = range.low - g_atr * 0.2;  // Tighter SL on retest
      opp.tpPrice = ask + (ask - opp.slPrice) * TP1_RR;
   } else {
      opp.entryPrice = bid;
      opp.slPrice = range.high + g_atr * 0.2;
      opp.tpPrice = bid - (opp.slPrice - bid) * TP1_RR;
   }

   double risk = MathAbs(opp.entryPrice - opp.slPrice);
   double reward = MathAbs(opp.tpPrice - opp.entryPrice);
   opp.rr = (risk > 0) ? reward / risk : 0;

   if(opp.rr < MinRR) return;

   opp.score = CalculateScore(dir, opp.setup) + 1;  // Bonus for retest
   opp.reason = "Retest " + EnumToString(range.type);

   if(opp.score >= MinOpportunityScore) {
      AddOpportunity(opp);
   }
}

//+------------------------------------------------------------------+
//| Check Failed Breakout Setup                                       |
//+------------------------------------------------------------------+
void CheckFailedBreakout(RangeInfo &range, double bid, double ask) {
   // Failed bullish breakout = price went above, now back inside
   if(range.breakoutUp && !range.failedBreakout) {
      if(bid < range.high && bid > range.mid) {
         // Check bearish momentum
         double close[], open[];
         ArraySetAsSeries(close, true);
         ArraySetAsSeries(open, true);
         CopyClose(_Symbol, LTF, 0, 3, close);
         CopyOpen(_Symbol, LTF, 0, 3, open);

         if(close[1] < open[1] && close[1] < close[2]) {
            Opportunity opp;
            opp.setup = SETUP_FAILED_BO;
            opp.rangeType = range.type;
            opp.direction = -1;  // Short after failed long breakout
            opp.entryPrice = bid;
            opp.slPrice = range.high + g_atr * 0.3;
            opp.tpPrice = range.low;

            double risk = opp.slPrice - opp.entryPrice;
            double reward = opp.entryPrice - opp.tpPrice;
            opp.rr = (risk > 0) ? reward / risk : 0;

            if(opp.rr >= MinRR) {
               opp.score = CalculateScore(-1, opp.setup) + 2;  // Bonus for failed BO
               opp.reason = "Failed BO Short";
               opp.valid = true;

               if(opp.score >= MinOpportunityScore) {
                  AddOpportunity(opp);
                  range.failedBreakout = true;
                  range.failedDir = -1;
               }
            }
         }
      }
   }

   // Failed bearish breakout
   if(range.breakoutDown && !range.failedBreakout) {
      if(ask > range.low && ask < range.mid) {
         double close[], open[];
         ArraySetAsSeries(close, true);
         ArraySetAsSeries(open, true);
         CopyClose(_Symbol, LTF, 0, 3, close);
         CopyOpen(_Symbol, LTF, 0, 3, open);

         if(close[1] > open[1] && close[1] > close[2]) {
            Opportunity opp;
            opp.setup = SETUP_FAILED_BO;
            opp.rangeType = range.type;
            opp.direction = 1;
            opp.entryPrice = ask;
            opp.slPrice = range.low - g_atr * 0.3;
            opp.tpPrice = range.high;

            double risk = opp.entryPrice - opp.slPrice;
            double reward = opp.tpPrice - opp.entryPrice;
            opp.rr = (risk > 0) ? reward / risk : 0;

            if(opp.rr >= MinRR) {
               opp.score = CalculateScore(1, opp.setup) + 2;
               opp.reason = "Failed BO Long";
               opp.valid = true;

               if(opp.score >= MinOpportunityScore) {
                  AddOpportunity(opp);
                  range.failedBreakout = true;
                  range.failedDir = 1;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Structure Setup                                             |
//+------------------------------------------------------------------+
void CheckStructureSetup(RangeInfo &range, int dir, double bid, double ask) {
   // Need rejection candle
   double close[], open[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyClose(_Symbol, LTF, 0, 3, close);
   CopyOpen(_Symbol, LTF, 0, 3, open);
   CopyHigh(_Symbol, LTF, 0, 3, high);
   CopyLow(_Symbol, LTF, 0, 3, low);

   bool pinBar = false;
   double body = MathAbs(close[1] - open[1]);
   double upperWick = high[1] - MathMax(close[1], open[1]);
   double lowerWick = MathMin(close[1], open[1]) - low[1];

   // Long setup: bullish pin bar at support
   if(dir == 1 && lowerWick > body * 2 && close[1] > open[1]) pinBar = true;
   // Short setup: bearish pin bar at resistance
   if(dir == -1 && upperWick > body * 2 && close[1] < open[1]) pinBar = true;

   if(!pinBar) return;

   Opportunity opp;
   opp.setup = SETUP_STRUCTURE;
   opp.rangeType = range.type;
   opp.direction = dir;
   opp.valid = true;

   if(dir == 1) {
      opp.entryPrice = ask;
      opp.slPrice = low[1] - g_atr * 0.1;
      opp.tpPrice = range.high;
   } else {
      opp.entryPrice = bid;
      opp.slPrice = high[1] + g_atr * 0.1;
      opp.tpPrice = range.low;
   }

   double risk = MathAbs(opp.entryPrice - opp.slPrice);
   double reward = MathAbs(opp.tpPrice - opp.entryPrice);
   opp.rr = (risk > 0) ? reward / risk : 0;

   if(opp.rr < MinRR) return;

   opp.score = CalculateScore(dir, opp.setup);
   opp.reason = "Structure " + (dir == 1 ? "Support" : "Resistance");

   if(opp.score >= MinOpportunityScore) {
      AddOpportunity(opp);
   }
}

//+------------------------------------------------------------------+
//| Calculate Score                                                   |
//+------------------------------------------------------------------+
int CalculateScore(int dir, ENUM_SETUP_TYPE setup) {
   int score = 0;

   // Bias alignment
   if(UseBiasFilter) {
      if(g_bias.htfBias == dir) score += 2;
      if(g_bias.mtfBias == dir) score += 1;
      if(g_bias.ltfBias == dir) score += 1;
   } else {
      score += 2;  // Base score if no filter
   }

   // Trending market
   if(g_bias.isTrending) score += 1;

   // Compression bonus
   if(UseCompressionBonus && g_bias.isCompressed) score += 2;

   // Setup type bonus
   if(setup == SETUP_RETEST) score += 1;
   if(setup == SETUP_FAILED_BO) score += 2;

   return score;
}

//+------------------------------------------------------------------+
//| Add Opportunity                                                   |
//+------------------------------------------------------------------+
void AddOpportunity(Opportunity &opp) {
   int size = ArraySize(g_opportunities);
   ArrayResize(g_opportunities, size + 1);
   g_opportunities[size] = opp;
   g_opportunityCount++;
}

//+------------------------------------------------------------------+
//| Sort Opportunities by Score                                       |
//+------------------------------------------------------------------+
void SortOpportunities() {
   int n = ArraySize(g_opportunities);
   for(int i = 0; i < n - 1; i++) {
      for(int j = 0; j < n - i - 1; j++) {
         if(g_opportunities[j].score < g_opportunities[j + 1].score) {
            Opportunity temp = g_opportunities[j];
            g_opportunities[j] = g_opportunities[j + 1];
            g_opportunities[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process Opportunities                                             |
//+------------------------------------------------------------------+
void ProcessOpportunities() {
   if(g_stats.todayTrades >= MaxTradesDay) return;
   if(CountPositions() >= MaxOpenTrades) return;

   for(int i = 0; i < ArraySize(g_opportunities); i++) {
      if(!g_opportunities[i].valid) continue;
      if(g_opportunities[i].score < MinOpportunityScore) continue;

      // Check if we already have position in same direction
      if(HasPositionInDirection(g_opportunities[i].direction)) continue;

      ExecuteOpportunity(g_opportunities[i]);

      if(CountPositions() >= MaxOpenTrades) break;
      if(g_stats.todayTrades >= MaxTradesDay) break;
   }
}

//+------------------------------------------------------------------+
//| Has Position In Direction                                         |
//+------------------------------------------------------------------+
bool HasPositionInDirection(int dir) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(pos.SelectByIndex(i)) {
         if(pos.Symbol() == _Symbol && pos.Magic() == Magic) {
            if(dir == 1 && pos.PositionType() == POSITION_TYPE_BUY) return true;
            if(dir == -1 && pos.PositionType() == POSITION_TYPE_SELL) return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute Opportunity                                               |
//+------------------------------------------------------------------+
void ExecuteOpportunity(Opportunity &opp) {
   double lots = CalculateLots(opp.entryPrice, opp.slPrice);
   if(lots <= 0) return;

   string comment = TradeComment + "_" + EnumToString(opp.setup) + "_S" + IntegerToString(opp.score);
   bool success = false;

   if(opp.direction == 1) {
      success = trade.Buy(lots, _Symbol, opp.entryPrice, opp.slPrice, opp.tpPrice, comment);
   } else {
      success = trade.Sell(lots, _Symbol, opp.entryPrice, opp.slPrice, opp.tpPrice, comment);
   }

   if(success) {
      g_stats.todayTrades++;
      Print("=== TRADE: ", opp.reason, " ===");
      Print("Score: ", opp.score, " | RR: ", DoubleToString(opp.rr, 2));
      Print("Entry: ", opp.entryPrice, " SL: ", opp.slPrice, " TP: ", opp.tpPrice);
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
//| Is In Trading Session                                             |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;

   if(TradeLondonSession && h >= 7 && h < 16) return true;
   if(TradeNYSession && h >= 13 && h < 21) return true;
   if(TradeAsianSession && (h >= 0 && h < 6)) return true;

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
         g_stats.todayWins = 0;
         g_stats.todayLosses = 0;
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
   // Asian Range
   if(g_asianRange.valid) {
      DrawRangeBox("SBv4_Asian", g_asianRange, clrDodgerBlue);
   }

   // London Range
   if(g_londonRange.valid) {
      DrawRangeBox("SBv4_London", g_londonRange, clrOrange);
   }

   // Intraday Range
   if(g_intradayRange.valid) {
      DrawRangeBox("SBv4_Intraday", g_intradayRange, clrGray);
   }
}

void DrawRangeBox(string name, RangeInfo &range, color clr) {
   ObjectDelete(0, name);
   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H1);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, range.startTime, range.high, endTime, range.low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Show Dashboard                                                    |
//+------------------------------------------------------------------+
void ShowDashboard() {
   string s = "";
   s += "══════════════════════════════════════════\n";
   s += "    SESSION BREAKOUT V4 - MULTI-SCANNER\n";
   s += "══════════════════════════════════════════\n";
   s += EnumToString(PropFirm) + " | " + EnumToString(Mode) + "\n";
   s += "──────────────────────────────────────────\n";
   s += "              MARKET BIAS\n";
   s += "──────────────────────────────────────────\n";
   s += "HTF: " + (g_bias.htfBias > 0 ? "BULL" : (g_bias.htfBias < 0 ? "BEAR" : "NEUTRAL"));
   s += " | MTF: " + (g_bias.mtfBias > 0 ? "BULL" : "BEAR");
   s += " | LTF: " + (g_bias.ltfBias > 0 ? "BULL" : "BEAR") + "\n";
   s += "ADX: " + DoubleToString(g_bias.adx, 1);
   s += " | Trend: " + (g_bias.isTrending ? "YES" : "NO");
   s += " | Squeeze: " + (g_bias.isCompressed ? "YES" : "NO") + "\n";
   s += "──────────────────────────────────────────\n";
   s += "              RANGES\n";
   s += "──────────────────────────────────────────\n";
   s += "Asian:    " + (g_asianRange.valid ? "VALID" : "---") + (g_asianRange.breakoutUp ? " [BO UP]" : (g_asianRange.breakoutDown ? " [BO DN]" : "")) + "\n";
   s += "London:   " + (g_londonRange.valid ? "VALID" : "---") + (g_londonRange.breakoutUp ? " [BO UP]" : (g_londonRange.breakoutDown ? " [BO DN]" : "")) + "\n";
   s += "Intraday: " + (g_intradayRange.valid ? "VALID" : "---") + "\n";
   s += "──────────────────────────────────────────\n";
   s += "           OPPORTUNITIES: " + IntegerToString(g_opportunityCount) + "\n";
   s += "──────────────────────────────────────────\n";

   for(int i = 0; i < MathMin(3, ArraySize(g_opportunities)); i++) {
      s += StringFormat("%d. %s [%d] RR:%.1f\n",
           i + 1,
           g_opportunities[i].reason,
           g_opportunities[i].score,
           g_opportunities[i].rr);
   }

   s += "──────────────────────────────────────────\n";
   s += "              STATS\n";
   s += "──────────────────────────────────────────\n";
   s += StringFormat("Daily: %.2f%% | DD: %.2f%%\n", g_stats.dailyPnL, g_stats.totalDD);
   s += StringFormat("Trades: %d/%d | Open: %d/%d\n", g_stats.todayTrades, MaxTradesDay, CountPositions(), MaxOpenTrades);
   s += "Session: " + (IsInTradingSession() ? "ACTIVE" : "CLOSED") + "\n";
   s += "══════════════════════════════════════════\n";

   Comment(s);
}
//+------------------------------------------------------------------+
