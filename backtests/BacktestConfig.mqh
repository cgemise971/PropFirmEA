//+------------------------------------------------------------------+
//|                                            BacktestConfig.mqh    |
//|                         Configuration pour backtests PropFirm    |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property strict

//+------------------------------------------------------------------+
//| Structures de Configuration                                       |
//+------------------------------------------------------------------+
struct BacktestSettings {
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime startDate;
   datetime endDate;
   double   initialDeposit;
   int      leverage;
   double   spread;           // Spread fixe en points (0 = variable)
   double   commission;       // Commission par lot
   int      slippage;         // Slippage en points
   string   profileName;
};

struct PropFirmConstraints {
   string   propFirmName;
   double   maxDailyDD;       // %
   double   maxTotalDD;       // %
   double   profitTarget;     // % (Phase 1)
   double   profitTarget2;    // % (Phase 2, 0 si 1-step)
   int      minTradingDays;
   bool     newsRestriction;
   bool     weekendRestriction;
   double   maxSLPercent;     // Pour The5ers
};

struct BacktestMetrics {
   // Performance
   double   netProfit;
   double   grossProfit;
   double   grossLoss;
   double   profitFactor;
   double   expectedPayoff;

   // Trades
   int      totalTrades;
   int      winningTrades;
   int      losingTrades;
   double   winRate;
   int      maxConsecWins;
   int      maxConsecLosses;

   // Drawdown
   double   maxDrawdown;
   double   maxDrawdownPercent;
   double   maxDailyDrawdown;
   double   avgDrawdown;

   // Ratios
   double   sharpeRatio;
   double   sortinoRatio;
   double   recoveryFactor;
   double   avgRRRatio;

   // Time
   double   avgTradeDuration;  // En heures
   int      tradingDays;
   double   profitPerDay;

   // PropFirm Specific
   bool     wouldPassChallenge;
   bool     ddLimitBreached;
   bool     dailyDDBreached;
   int      daysToTarget;
};

//+------------------------------------------------------------------+
//| Configurations Prédéfinies                                        |
//+------------------------------------------------------------------+
PropFirmConstraints GetFTMOConstraints() {
   PropFirmConstraints c;
   c.propFirmName = "FTMO";
   c.maxDailyDD = 5.0;
   c.maxTotalDD = 10.0;
   c.profitTarget = 10.0;
   c.profitTarget2 = 5.0;
   c.minTradingDays = 4;
   c.newsRestriction = true;
   c.weekendRestriction = true;
   c.maxSLPercent = 100.0;  // Pas de limite spécifique
   return c;
}

PropFirmConstraints GetE8OneConstraints() {
   PropFirmConstraints c;
   c.propFirmName = "E8 One Step";
   c.maxDailyDD = 5.0;
   c.maxTotalDD = 6.0;
   c.profitTarget = 10.0;
   c.profitTarget2 = 0.0;   // 1-step
   c.minTradingDays = 3;
   c.newsRestriction = false;
   c.weekendRestriction = false;
   c.maxSLPercent = 100.0;
   return c;
}

PropFirmConstraints GetFundingPips1StepConstraints() {
   PropFirmConstraints c;
   c.propFirmName = "Funding Pips 1-Step";
   c.maxDailyDD = 4.0;
   c.maxTotalDD = 6.0;
   c.profitTarget = 10.0;
   c.profitTarget2 = 0.0;
   c.minTradingDays = 3;
   c.newsRestriction = true;  // En funded
   c.weekendRestriction = false;
   c.maxSLPercent = 100.0;
   return c;
}

PropFirmConstraints GetThe5ersBootcampConstraints() {
   PropFirmConstraints c;
   c.propFirmName = "The5ers Bootcamp";
   c.maxDailyDD = 100.0;    // Pas de limite daily en eval
   c.maxTotalDD = 5.0;
   c.profitTarget = 6.0;
   c.profitTarget2 = 6.0;   // Même target pour chaque phase
   c.minTradingDays = 0;
   c.newsRestriction = false;
   c.weekendRestriction = false;
   c.maxSLPercent = 2.0;    // CRITIQUE
   return c;
}

//+------------------------------------------------------------------+
//| Scénarios de Backtest Standard                                    |
//+------------------------------------------------------------------+
BacktestSettings GetStandardBacktest(string symbol = "EURUSD") {
   BacktestSettings s;
   s.symbol = symbol;
   s.timeframe = PERIOD_M15;
   s.startDate = D'2019.01.01';
   s.endDate = D'2024.12.01';
   s.initialDeposit = 100000;
   s.leverage = 100;
   s.spread = 0;          // Variable
   s.commission = 7.0;    // $7 per lot round trip
   s.slippage = 10;       // 1 pip
   s.profileName = "Standard_5Y";
   return s;
}

BacktestSettings GetStressTestBacktest(string symbol = "EURUSD") {
   BacktestSettings s;
   s.symbol = symbol;
   s.timeframe = PERIOD_M15;
   s.startDate = D'2020.02.01';  // COVID crash
   s.endDate = D'2020.06.01';
   s.initialDeposit = 100000;
   s.leverage = 100;
   s.spread = 30;         // Spread élargi (stress)
   s.commission = 7.0;
   s.slippage = 30;       // 3 pips (stress)
   s.profileName = "Stress_COVID";
   return s;
}

BacktestSettings GetVolatilityTestBacktest(string symbol = "EURUSD") {
   BacktestSettings s;
   s.symbol = symbol;
   s.timeframe = PERIOD_M15;
   s.startDate = D'2022.01.01';  // Haute volatilité Fed
   s.endDate = D'2022.12.31';
   s.initialDeposit = 100000;
   s.leverage = 100;
   s.spread = 15;
   s.commission = 7.0;
   s.slippage = 20;
   s.profileName = "Volatility_2022";
   return s;
}

BacktestSettings GetRecentBacktest(string symbol = "EURUSD") {
   BacktestSettings s;
   s.symbol = symbol;
   s.timeframe = PERIOD_M15;
   s.startDate = D'2024.01.01';
   s.endDate = D'2024.12.01';
   s.initialDeposit = 100000;
   s.leverage = 100;
   s.spread = 0;
   s.commission = 7.0;
   s.slippage = 10;
   s.profileName = "Recent_2024";
   return s;
}
//+------------------------------------------------------------------+
