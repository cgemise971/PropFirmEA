//+------------------------------------------------------------------+
//|                                  PropFirm_SessionBreakout_v3.mq5 |
//|                    HIGH QUALITY Breakout - Confluence Based      |
//|                                       Optimized for Prop Firms   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property link      ""
#property version   "3.00"
#property description "V3: Quality over Quantity - Multi-TF Confluence"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_PROP_FIRM {
   PROP_FTMO,             // FTMO
   PROP_E8,               // E8 Markets
   PROP_FUNDING_PIPS,     // Funding Pips
   PROP_THE5ERS,          // The5ers
   PROP_CUSTOM            // Custom
};

enum ENUM_TRADE_MODE {
   MODE_CHALLENGE,        // Challenge (Aggressive)
   MODE_FUNDED            // Funded (Conservative)
};

enum ENUM_MARKET_REGIME {
   REGIME_TRENDING,       // Trending Market
   REGIME_RANGING,        // Ranging Market
   REGIME_VOLATILE,       // High Volatility
   REGIME_UNKNOWN         // Unknown
};

//+------------------------------------------------------------------+
//| Input Parameters - Prop Firm                                     |
//+------------------------------------------------------------------+
input group "========== PROP FIRM =========="
input ENUM_PROP_FIRM PropFirm = PROP_FTMO;         // Prop Firm
input ENUM_TRADE_MODE Mode = MODE_CHALLENGE;        // Mode

//+------------------------------------------------------------------+
//| Input Parameters - Risk                                          |
//+------------------------------------------------------------------+
input group "========== RISK =========="
input double RiskPercent = 1.5;              // Risk %
input double MaxDailyDD = 4.5;               // Max Daily DD %
input double MaxTotalDD = 9.0;               // Max Total DD %
input int MaxTradesDay = 4;                  // Max Trades/Day
input int MaxLosersInRow = 2;                // Max Losers then pause

//+------------------------------------------------------------------+
//| Input Parameters - Quality Filters                               |
//+------------------------------------------------------------------+
input group "========== QUALITY FILTERS =========="
input int MinConfluenceScore = 5;            // Min Score to Trade (1-10)
input bool RequireTrendAlignment = true;     // HTF Trend Required
input bool RequireRetestConfirm = true;      // Wait for Retest
input bool RequireMomentum = true;           // Momentum Confirmation
input double MinADX = 20.0;                  // Min ADX (trend strength)
input bool AvoidRangingMarket = true;        // Skip ranging markets

//+------------------------------------------------------------------+
//| Input Parameters - Multi-Timeframe                               |
//+------------------------------------------------------------------+
input group "========== MULTI-TIMEFRAME =========="
input ENUM_TIMEFRAMES HTF = PERIOD_H4;       // Higher TF (Trend)
input ENUM_TIMEFRAMES MTF = PERIOD_H1;       // Medium TF (Structure)
input ENUM_TIMEFRAMES LTF = PERIOD_M15;      // Lower TF (Entry)
input int EMA_Fast = 21;                     // Fast EMA
input int EMA_Slow = 50;                     // Slow EMA
input int EMA_Trend = 200;                   // Trend EMA

//+------------------------------------------------------------------+
//| Input Parameters - Range                                         |
//+------------------------------------------------------------------+
input group "========== RANGE =========="
input int RangeHours = 6;                    // Range Period (hours)
input double RangeATRMin = 0.5;              // Min Range (ATR mult)
input double RangeATRMax = 2.5;              // Max Range (ATR mult)
input double BreakoutBuffer = 2.0;           // Breakout Buffer (pips)

//+------------------------------------------------------------------+
//| Input Parameters - Entry                                         |
//+------------------------------------------------------------------+
input group "========== ENTRY =========="
input int RetestWaitBars = 8;                // Bars to wait for retest
input double RetestZonePercent = 30.0;       // Retest zone (% into range)
input double MinCandleATR = 0.5;             // Min breakout candle (ATR mult)
input bool UseEngulfing = true;              // Engulfing pattern bonus

//+------------------------------------------------------------------+
//| Input Parameters - Exit                                          |
//+------------------------------------------------------------------+
input group "========== EXIT =========="
input double TP1_RR = 1.5;                   // TP1 R:R
input double TP1_ClosePercent = 50.0;        // TP1 Close %
input double TP2_RR = 2.5;                   // TP2 R:R
input double TP2_ClosePercent = 30.0;        // TP2 Close %
input bool UseBreakeven = true;              // Move to BE after TP1
input double TrailingATRMult = 1.2;          // Trailing (ATR mult)

//+------------------------------------------------------------------+
//| Input Parameters - Sessions                                      |
//+------------------------------------------------------------------+
input group "========== SESSIONS =========="
input bool TradeLondon = true;               // London (07-11 UTC)
input bool TradeNY = true;                   // NY (13-17 UTC)
input bool TradeLondonNYOverlap = true;      // Overlap (13-16 UTC)
input bool AvoidMonday = true;               // Skip Monday morning
input bool AvoidFriday = true;               // Skip Friday afternoon

//+------------------------------------------------------------------+
//| Input Parameters - EA                                            |
//+------------------------------------------------------------------+
input group "========== EA =========="
input int Magic = 345678;                    // Magic Number
input string Comment_ = "SBv3";              // Comment
input bool Dashboard = true;                 // Show Dashboard
input bool DrawLevels = true;                // Draw on Chart

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct RangeData {
   double high;
   double low;
   double mid;
   double size;
   double sizePips;
   datetime calcTime;
   bool valid;
   int breakoutDir;        // 1=up, -1=down, 0=none
   bool retestPending;
   int retestDir;
   int retestBarsWaited;
};

struct ConfluenceData {
   int score;              // Total score 0-10
   bool htfTrendUp;
   bool mtfTrendUp;
   bool ltfMomentum;
   bool adxStrong;
   bool volumeOK;
   bool sessionOK;
   bool retestOK;
   bool engulfingOK;
   ENUM_MARKET_REGIME regime;
};

struct TradeData {
   int todayTrades;
   int todayWins;
   int todayLosses;
   int consecutiveLosses;
   double dailyPnL;
   double totalDD;
   double startBalance;
   double dayStartBalance;
   bool paused;
};

struct PropData {
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

RangeData g_range;
ConfluenceData g_conf;
TradeData g_trade;
PropData g_prop;

int g_atrHandle, g_adxHandle;
int g_emaFastHTF, g_emaSlowHTF, g_emaTrendHTF;
int g_emaFastMTF, g_emaSlowMTF;
int g_emaFastLTF;

datetime g_lastBar;
datetime g_lastRangeCalc;
double g_atr;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Initialize stats
   g_trade.startBalance = acc.Balance();
   g_trade.dayStartBalance = g_trade.startBalance;
   g_trade.paused = false;

   LoadPropSettings();

   // Create indicators
   g_atrHandle = iATR(_Symbol, MTF, 14);
   g_adxHandle = iADX(_Symbol, MTF, 14);

   g_emaFastHTF = iMA(_Symbol, HTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHTF = iMA(_Symbol, HTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_emaTrendHTF = iMA(_Symbol, HTF, EMA_Trend, 0, MODE_EMA, PRICE_CLOSE);

   g_emaFastMTF = iMA(_Symbol, MTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowMTF = iMA(_Symbol, MTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   g_emaFastLTF = iMA(_Symbol, LTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);

   if(g_atrHandle == INVALID_HANDLE || g_adxHandle == INVALID_HANDLE) {
      Print("Indicator creation failed");
      return INIT_FAILED;
   }

   ResetRange();
   Print("Session Breakout V3 - Quality Mode initialized");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_adxHandle);
   IndicatorRelease(g_emaFastHTF);
   IndicatorRelease(g_emaSlowHTF);
   IndicatorRelease(g_emaTrendHTF);
   IndicatorRelease(g_emaFastMTF);
   IndicatorRelease(g_emaSlowMTF);
   IndicatorRelease(g_emaFastLTF);

   ObjectsDeleteAll(0, "SBv3_");
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

   if(!PassRiskChecks()) {
      if(Dashboard) ShowDashboard();
      return;
   }

   // Check if paused due to losses
   if(g_trade.paused) {
      if(Dashboard) ShowDashboard();
      return;
   }

   // Calculate range
   CalculateRange();

   if(newBar) {
      g_lastBar = barTime;

      // Update confluence analysis
      AnalyzeConfluence();

      // Check market regime
      if(AvoidRangingMarket && g_conf.regime == REGIME_RANGING) {
         if(Dashboard) ShowDashboard();
         return;
      }

      if(g_range.valid && IsGoodSession()) {
         // Look for breakout
         if(g_range.breakoutDir == 0) {
            CheckForBreakout();
         }

         // Check retest entry
         if(g_range.retestPending) {
            CheckRetestEntry();
         }
      }

      // Manage positions
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
//| Reset Range                                                       |
//+------------------------------------------------------------------+
void ResetRange() {
   g_range.high = 0;
   g_range.low = DBL_MAX;
   g_range.valid = false;
   g_range.breakoutDir = 0;
   g_range.retestPending = false;
   g_range.retestDir = 0;
   g_range.retestBarsWaited = 0;
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
//| Calculate Range                                                   |
//+------------------------------------------------------------------+
void CalculateRange() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   datetime now = TimeGMT();
   datetime rangeStart = now - (RangeHours * 3600);

   // Recalculate every hour
   if(now - g_lastRangeCalc < 3600 && g_range.valid) return;

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int startBar = iBarShift(_Symbol, MTF, rangeStart);
   if(startBar <= 0) return;

   if(CopyHigh(_Symbol, MTF, 0, startBar, highs) <= 0) return;
   if(CopyLow(_Symbol, MTF, 0, startBar, lows) <= 0) return;

   g_range.high = highs[ArrayMaximum(highs)];
   g_range.low = lows[ArrayMinimum(lows)];
   g_range.mid = (g_range.high + g_range.low) / 2;
   g_range.size = g_range.high - g_range.low;
   g_range.sizePips = g_range.size / _Point / 10;
   g_range.calcTime = now;
   g_lastRangeCalc = now;

   // Validate with ATR
   double minSize = g_atr * RangeATRMin;
   double maxSize = g_atr * RangeATRMax;

   g_range.valid = (g_range.size >= minSize && g_range.size <= maxSize);
}

//+------------------------------------------------------------------+
//| Analyze Confluence                                                |
//+------------------------------------------------------------------+
void AnalyzeConfluence() {
   g_conf.score = 0;

   // 1. HTF Trend (3 points)
   double emaFastHTF[], emaSlowHTF[], emaTrendHTF[], closeHTF[];
   ArraySetAsSeries(emaFastHTF, true);
   ArraySetAsSeries(emaSlowHTF, true);
   ArraySetAsSeries(emaTrendHTF, true);
   ArraySetAsSeries(closeHTF, true);

   CopyBuffer(g_emaFastHTF, 0, 0, 2, emaFastHTF);
   CopyBuffer(g_emaSlowHTF, 0, 0, 2, emaSlowHTF);
   CopyBuffer(g_emaTrendHTF, 0, 0, 2, emaTrendHTF);
   CopyClose(_Symbol, HTF, 0, 2, closeHTF);

   g_conf.htfTrendUp = (emaFastHTF[0] > emaSlowHTF[0] && closeHTF[0] > emaTrendHTF[0]);
   bool htfTrendDown = (emaFastHTF[0] < emaSlowHTF[0] && closeHTF[0] < emaTrendHTF[0]);

   if(g_conf.htfTrendUp || htfTrendDown) g_conf.score += 3;

   // 2. MTF Structure (2 points)
   double emaFastMTF[], emaSlowMTF[];
   ArraySetAsSeries(emaFastMTF, true);
   ArraySetAsSeries(emaSlowMTF, true);

   CopyBuffer(g_emaFastMTF, 0, 0, 2, emaFastMTF);
   CopyBuffer(g_emaSlowMTF, 0, 0, 2, emaSlowMTF);

   g_conf.mtfTrendUp = (emaFastMTF[0] > emaSlowMTF[0]);
   bool mtfTrendDown = (emaFastMTF[0] < emaSlowMTF[0]);

   // Alignment bonus
   if((g_conf.htfTrendUp && g_conf.mtfTrendUp) || (htfTrendDown && mtfTrendDown)) {
      g_conf.score += 2;
   }

   // 3. ADX Strength (2 points)
   double adx[], plusDI[], minusDI[];
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(plusDI, true);
   ArraySetAsSeries(minusDI, true);

   CopyBuffer(g_adxHandle, 0, 0, 1, adx);
   CopyBuffer(g_adxHandle, 1, 0, 1, plusDI);
   CopyBuffer(g_adxHandle, 2, 0, 1, minusDI);

   g_conf.adxStrong = (adx[0] >= MinADX);
   if(g_conf.adxStrong) g_conf.score += 2;

   // 4. Market Regime
   if(adx[0] >= 25) {
      g_conf.regime = REGIME_TRENDING;
   }
   else if(adx[0] < 20) {
      g_conf.regime = REGIME_RANGING;
   }
   else {
      g_conf.regime = REGIME_UNKNOWN;
   }

   // 5. Session Quality (1 point)
   g_conf.sessionOK = IsGoodSession();
   if(g_conf.sessionOK) g_conf.score += 1;

   // 6. LTF Momentum (2 points) - checked at entry
   double emaFastLTF[], closeLTF[];
   ArraySetAsSeries(emaFastLTF, true);
   ArraySetAsSeries(closeLTF, true);

   CopyBuffer(g_emaFastLTF, 0, 0, 3, emaFastLTF);
   CopyClose(_Symbol, LTF, 0, 3, closeLTF);

   g_conf.ltfMomentum = (closeLTF[1] > emaFastLTF[1] && closeLTF[1] > closeLTF[2]);
   // Points added at entry validation
}

//+------------------------------------------------------------------+
//| Check For Breakout                                                |
//+------------------------------------------------------------------+
void CheckForBreakout() {
   double close[], open[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyClose(_Symbol, LTF, 0, 3, close) <= 0) return;
   if(CopyOpen(_Symbol, LTF, 0, 3, open) <= 0) return;
   if(CopyHigh(_Symbol, LTF, 0, 3, high) <= 0) return;
   if(CopyLow(_Symbol, LTF, 0, 3, low) <= 0) return;

   double buffer = BreakoutBuffer * 10 * _Point;
   double candleSize = MathAbs(close[1] - open[1]);
   double minCandle = g_atr * MinCandleATR;

   // Check engulfing pattern
   bool bullEngulf = (close[1] > open[1] && close[1] > high[2] && open[1] < low[2]);
   bool bearEngulf = (close[1] < open[1] && close[1] < low[2] && open[1] > high[2]);

   // BULLISH BREAKOUT
   if(close[1] > g_range.high + buffer && close[1] > open[1]) {
      if(candleSize >= minCandle) {
         // Check trend alignment
         if(!RequireTrendAlignment || g_conf.htfTrendUp) {
            g_range.breakoutDir = 1;

            int score = g_conf.score;
            if(g_conf.ltfMomentum) score += 2;
            if(bullEngulf && UseEngulfing) score += 1;

            Print("BULLISH BREAKOUT detected - Score: ", score, "/10");

            if(RequireRetestConfirm) {
               // Wait for retest
               g_range.retestPending = true;
               g_range.retestDir = 1;
               g_range.retestBarsWaited = 0;
               Print("Waiting for retest...");
            }
            else if(score >= MinConfluenceScore) {
               ExecuteTrade(true, score);
            }
         }
      }
   }

   // BEARISH BREAKOUT
   if(close[1] < g_range.low - buffer && close[1] < open[1]) {
      if(candleSize >= minCandle) {
         bool htfTrendDown = !g_conf.htfTrendUp;
         if(!RequireTrendAlignment || htfTrendDown) {
            g_range.breakoutDir = -1;

            int score = g_conf.score;
            if(!g_conf.ltfMomentum) score += 2;  // Bearish momentum
            if(bearEngulf && UseEngulfing) score += 1;

            Print("BEARISH BREAKOUT detected - Score: ", score, "/10");

            if(RequireRetestConfirm) {
               g_range.retestPending = true;
               g_range.retestDir = -1;
               g_range.retestBarsWaited = 0;
               Print("Waiting for retest...");
            }
            else if(score >= MinConfluenceScore) {
               ExecuteTrade(false, score);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Retest Entry                                                |
//+------------------------------------------------------------------+
void CheckRetestEntry() {
   g_range.retestBarsWaited++;

   if(g_range.retestBarsWaited > RetestWaitBars) {
      g_range.retestPending = false;
      Print("Retest timeout - entry cancelled");
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double retestZone = g_range.size * (RetestZonePercent / 100);

   // Long retest - price pulls back to range high
   if(g_range.retestDir == 1) {
      double retestLevel = g_range.high + retestZone;

      if(bid <= g_range.high && bid >= g_range.high - retestZone) {
         // Check for rejection candle
         double close[], open[];
         ArraySetAsSeries(close, true);
         ArraySetAsSeries(open, true);
         CopyClose(_Symbol, LTF, 0, 2, close);
         CopyOpen(_Symbol, LTF, 0, 2, open);

         // Bullish candle at support
         if(close[1] > open[1]) {
            int score = g_conf.score + 2;  // Retest bonus
            g_conf.retestOK = true;

            Print("RETEST CONFIRMED (Long) - Score: ", score, "/10");

            if(score >= MinConfluenceScore) {
               ExecuteTrade(true, score);
               g_range.retestPending = false;
            }
         }
      }
   }

   // Short retest - price pulls back to range low
   if(g_range.retestDir == -1) {
      if(ask >= g_range.low && ask <= g_range.low + retestZone) {
         double close[], open[];
         ArraySetAsSeries(close, true);
         ArraySetAsSeries(open, true);
         CopyClose(_Symbol, LTF, 0, 2, close);
         CopyOpen(_Symbol, LTF, 0, 2, open);

         // Bearish candle at resistance
         if(close[1] < open[1]) {
            int score = g_conf.score + 2;
            g_conf.retestOK = true;

            Print("RETEST CONFIRMED (Short) - Score: ", score, "/10");

            if(score >= MinConfluenceScore) {
               ExecuteTrade(false, score);
               g_range.retestPending = false;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(bool isLong, int score) {
   if(g_trade.todayTrades >= MaxTradesDay) return;
   if(CountPositions() >= 1) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;

   double entry, sl, tp1, tp2;

   // Structure-based SL
   if(isLong) {
      entry = ask;
      // SL below range low with buffer
      sl = g_range.low - (g_atr * 0.5);
      double risk = entry - sl;
      tp1 = entry + (risk * TP1_RR);
      tp2 = entry + (risk * TP2_RR);
   }
   else {
      entry = bid;
      // SL above range high with buffer
      sl = g_range.high + (g_atr * 0.5);
      double risk = sl - entry;
      tp1 = entry - (risk * TP1_RR);
      tp2 = entry - (risk * TP2_RR);
   }

   // Validate RR
   double riskPips = MathAbs(entry - sl) / _Point / 10;
   double rewardPips = MathAbs(tp1 - entry) / _Point / 10;
   double rr = rewardPips / riskPips;

   if(rr < 1.0) {
      Print("RR too low: ", rr, " - skipping trade");
      return;
   }

   double lots = CalculateLots(entry, sl);
   if(lots <= 0) return;

   string comment = Comment_ + "_S" + IntegerToString(score);
   bool success = false;

   if(isLong) {
      success = trade.Buy(lots, _Symbol, entry, sl, tp1, comment);
   }
   else {
      success = trade.Sell(lots, _Symbol, entry, sl, tp1, comment);
   }

   if(success) {
      g_trade.todayTrades++;
      Print("=== TRADE EXECUTED ===");
      Print("Direction: ", (isLong ? "LONG" : "SHORT"));
      Print("Score: ", score, "/10");
      Print("Entry: ", entry, " SL: ", sl, " TP1: ", tp1);
      Print("RR: ", DoubleToString(rr, 2));
      Print("Lots: ", lots);
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
      double currentSL = pos.StopLoss();
      double currentTP = pos.TakeProfit();
      double profit = pos.Profit();
      ulong ticket = pos.Ticket();
      bool isLong = (pos.PositionType() == POSITION_TYPE_BUY);

      double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double risk = MathAbs(entry - currentSL);

      // Move to breakeven after TP1 hit
      if(UseBreakeven && profit > 0) {
         double tp1Level = isLong ? entry + (risk * TP1_RR) : entry - (risk * TP1_RR);
         bool tp1Hit = isLong ? (price >= tp1Level) : (price <= tp1Level);

         if(tp1Hit) {
            double newSL = entry + (isLong ? (5 * _Point * 10) : -(5 * _Point * 10));
            if((isLong && newSL > currentSL) || (!isLong && newSL < currentSL)) {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
      }

      // Trailing stop
      double trailDist = g_atr * TrailingATRMult;
      if(isLong && price - entry > trailDist) {
         double newSL = price - trailDist;
         if(newSL > currentSL) {
            trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else if(!isLong && entry - price > trailDist) {
         double newSL = price + trailDist;
         if(newSL < currentSL) {
            trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Is Good Session                                                   |
//+------------------------------------------------------------------+
bool IsGoodSession() {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   int dow = dt.day_of_week;

   // Avoid Monday morning
   if(AvoidMonday && dow == 1 && h < 8) return false;

   // Avoid Friday afternoon
   if(AvoidFriday && dow == 5 && h >= 16) return false;

   // London session
   if(TradeLondon && h >= 7 && h < 11) return true;

   // NY session
   if(TradeNY && h >= 13 && h < 17) return true;

   // Overlap (best time)
   if(TradeLondonNYOverlap && h >= 13 && h < 16) return true;

   return false;
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
//| Check Day Reset                                                   |
//+------------------------------------------------------------------+
void CheckDayReset() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   static int lastDay = -1;

   if(lastDay != dt.day) {
      if(lastDay != -1) {
         g_trade.dayStartBalance = acc.Balance();
         g_trade.dailyPnL = 0;
         g_trade.todayTrades = 0;
         g_trade.todayWins = 0;
         g_trade.todayLosses = 0;
         g_trade.consecutiveLosses = 0;
         g_trade.paused = false;
         ResetRange();
      }
      lastDay = dt.day;
   }
}

//+------------------------------------------------------------------+
//| Pass Risk Checks                                                  |
//+------------------------------------------------------------------+
bool PassRiskChecks() {
   double equity = acc.Equity();
   g_trade.dailyPnL = ((equity - g_trade.dayStartBalance) / g_trade.dayStartBalance) * 100;
   g_trade.totalDD = ((g_trade.startBalance - equity) / g_trade.startBalance) * 100;

   if(g_trade.dailyPnL <= -g_prop.maxDailyDD) {
      CloseAll("Daily DD Limit");
      return false;
   }

   if(g_trade.totalDD >= g_prop.maxTotalDD) {
      CloseAll("Total DD Limit");
      return false;
   }

   // Pause after consecutive losses
   if(g_trade.consecutiveLosses >= MaxLosersInRow) {
      g_trade.paused = true;
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
   Print("Closed all: ", reason);
}

//+------------------------------------------------------------------+
//| Draw On Chart                                                     |
//+------------------------------------------------------------------+
void DrawOnChart() {
   if(!g_range.valid) return;

   string boxName = "SBv3_Range";
   ObjectDelete(0, boxName);

   datetime endTime = TimeCurrent() + PeriodSeconds(PERIOD_H4);
   ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, g_range.calcTime - (RangeHours * 3600), g_range.high, endTime, g_range.low);
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);

   // Breakout levels
   string highLine = "SBv3_High";
   ObjectDelete(0, highLine);
   ObjectCreate(0, highLine, OBJ_HLINE, 0, 0, g_range.high);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_DASH);

   string lowLine = "SBv3_Low";
   ObjectDelete(0, lowLine);
   ObjectCreate(0, lowLine, OBJ_HLINE, 0, 0, g_range.low);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_DASH);
}

//+------------------------------------------------------------------+
//| Show Dashboard                                                    |
//+------------------------------------------------------------------+
void ShowDashboard() {
   string s = "";
   s += "═════════════════════════════════════════\n";
   s += "    SESSION BREAKOUT V3 - QUALITY MODE\n";
   s += "═════════════════════════════════════════\n";
   s += "Profile: " + EnumToString(PropFirm) + " | " + EnumToString(Mode) + "\n";
   s += "─────────────────────────────────────────\n";
   s += "           CONFLUENCE SCORE\n";
   s += "─────────────────────────────────────────\n";
   s += StringFormat("Score: %d / 10 (Min: %d)\n", g_conf.score, MinConfluenceScore);
   s += "HTF Trend: " + (g_conf.htfTrendUp ? "UP" : "DOWN") + " | ";
   s += "MTF: " + (g_conf.mtfTrendUp ? "UP" : "DOWN") + "\n";
   s += "ADX: " + (g_conf.adxStrong ? "STRONG" : "WEAK") + " | ";
   s += "Regime: " + EnumToString(g_conf.regime) + "\n";
   s += "─────────────────────────────────────────\n";
   s += "              RANGE\n";
   s += "─────────────────────────────────────────\n";
   s += StringFormat("High: %.5f | Low: %.5f\n", g_range.high, g_range.low);
   s += StringFormat("Size: %.1f pips | Valid: %s\n", g_range.sizePips, (g_range.valid ? "YES" : "NO"));
   s += "Breakout: " + (g_range.breakoutDir > 0 ? "BULLISH" : (g_range.breakoutDir < 0 ? "BEARISH" : "NONE")) + "\n";
   if(g_range.retestPending) {
      s += StringFormat("Retest Pending: %s (bar %d/%d)\n",
           (g_range.retestDir > 0 ? "LONG" : "SHORT"),
           g_range.retestBarsWaited, RetestWaitBars);
   }
   s += "─────────────────────────────────────────\n";
   s += "              RISK\n";
   s += "─────────────────────────────────────────\n";
   s += StringFormat("Daily: %.2f%% / -%.2f%%\n", g_trade.dailyPnL, g_prop.maxDailyDD);
   s += StringFormat("Total DD: %.2f%% / %.2f%%\n", g_trade.totalDD, g_prop.maxTotalDD);
   s += StringFormat("Trades: %d/%d | Losses: %d/%d\n",
        g_trade.todayTrades, MaxTradesDay,
        g_trade.consecutiveLosses, MaxLosersInRow);
   if(g_trade.paused) s += ">>> PAUSED (loss limit) <<<\n";
   s += "─────────────────────────────────────────\n";
   s += "Session: " + (IsGoodSession() ? "ACTIVE" : "WAITING") + "\n";
   s += "═════════════════════════════════════════\n";

   Comment(s);
}

//+------------------------------------------------------------------+
//| OnTrade - Track wins/losses                                       |
//+------------------------------------------------------------------+
void OnTrade() {
   static int lastDeals = 0;

   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();

   if(totalDeals > lastDeals) {
      ulong ticket = HistoryDealGetTicket(totalDeals - 1);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == Magic) {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            if(profit > 0) {
               g_trade.todayWins++;
               g_trade.consecutiveLosses = 0;
            }
            else if(profit < 0) {
               g_trade.todayLosses++;
               g_trade.consecutiveLosses++;
            }
         }
      }
   }
   lastDeals = totalDeals;
}
//+------------------------------------------------------------------+
