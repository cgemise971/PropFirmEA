//+------------------------------------------------------------------+
//|                                           BacktestAnalyzer.mq5   |
//|                    Analyseur de résultats de backtest PropFirm   |
//+------------------------------------------------------------------+
#property copyright "PropFirm EA Project"
#property version   "1.00"
#property script_show_inputs

#include "BacktestConfig.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input string ReportFile = "backtest_report.csv";    // Fichier de sortie
input double InitialBalance = 100000;               // Balance initiale
input int    PropFirmType = 0;                      // 0=FTMO, 1=E8, 2=FP, 3=T5

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
BacktestMetrics g_metrics;
PropFirmConstraints g_constraints;
double g_equityCurve[];
double g_dailyPnL[];
datetime g_tradeDates[];

//+------------------------------------------------------------------+
//| Script program start function                                     |
//+------------------------------------------------------------------+
void OnStart() {
   // Charger les contraintes PropFirm
   LoadPropFirmConstraints();

   // Analyser l'historique des trades
   AnalyzeTradeHistory();

   // Calculer les métriques avancées
   CalculateAdvancedMetrics();

   // Vérifier la conformité PropFirm
   CheckPropFirmCompliance();

   // Générer le rapport
   GenerateReport();

   // Afficher le résumé
   DisplaySummary();
}

//+------------------------------------------------------------------+
//| Charger les contraintes PropFirm                                  |
//+------------------------------------------------------------------+
void LoadPropFirmConstraints() {
   switch(PropFirmType) {
      case 0: g_constraints = GetFTMOConstraints(); break;
      case 1: g_constraints = GetE8OneConstraints(); break;
      case 2: g_constraints = GetFundingPips1StepConstraints(); break;
      case 3: g_constraints = GetThe5ersBootcampConstraints(); break;
      default: g_constraints = GetFTMOConstraints();
   }
   Print("Contraintes chargées: ", g_constraints.propFirmName);
}

//+------------------------------------------------------------------+
//| Analyser l'historique des trades                                  |
//+------------------------------------------------------------------+
void AnalyzeTradeHistory() {
   // Sélectionner l'historique complet
   HistorySelect(0, TimeCurrent());

   int totalDeals = HistoryDealsTotal();
   Print("Nombre de deals dans l'historique: ", totalDeals);

   // Variables pour le calcul
   g_metrics.totalTrades = 0;
   g_metrics.winningTrades = 0;
   g_metrics.losingTrades = 0;
   g_metrics.grossProfit = 0;
   g_metrics.grossLoss = 0;

   int consecWins = 0, consecLosses = 0;
   g_metrics.maxConsecWins = 0;
   g_metrics.maxConsecLosses = 0;

   double runningBalance = InitialBalance;
   double peakBalance = InitialBalance;
   double maxDD = 0;

   // Arrays pour equity curve
   ArrayResize(g_equityCurve, 0);
   ArrayResize(g_tradeDates, 0);

   double totalRR = 0;
   double totalDuration = 0;
   datetime lastTradeDate = 0;
   int tradingDaysCount = 0;

   // Map pour les jours de trading
   datetime tradingDays[];
   ArrayResize(tradingDays, 0);

   // Parcourir les deals
   for(int i = 0; i < totalDeals; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // Filtrer les deals de sortie uniquement
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double netProfit = profit + commission + swap;

      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      // Compter les jours de trading uniques
      MqlDateTime dt;
      TimeToStruct(dealTime, dt);
      datetime dayStart = StructToTime(dt) - dt.hour * 3600 - dt.min * 60 - dt.sec;

      bool newDay = true;
      for(int d = 0; d < ArraySize(tradingDays); d++) {
         if(tradingDays[d] == dayStart) {
            newDay = false;
            break;
         }
      }
      if(newDay) {
         int size = ArraySize(tradingDays);
         ArrayResize(tradingDays, size + 1);
         tradingDays[size] = dayStart;
      }

      // Statistiques des trades
      g_metrics.totalTrades++;

      if(netProfit > 0) {
         g_metrics.winningTrades++;
         g_metrics.grossProfit += netProfit;
         consecWins++;
         consecLosses = 0;
         if(consecWins > g_metrics.maxConsecWins)
            g_metrics.maxConsecWins = consecWins;
      }
      else {
         g_metrics.losingTrades++;
         g_metrics.grossLoss += MathAbs(netProfit);
         consecLosses++;
         consecWins = 0;
         if(consecLosses > g_metrics.maxConsecLosses)
            g_metrics.maxConsecLosses = consecLosses;
      }

      // Equity curve
      runningBalance += netProfit;
      int eqSize = ArraySize(g_equityCurve);
      ArrayResize(g_equityCurve, eqSize + 1);
      ArrayResize(g_tradeDates, eqSize + 1);
      g_equityCurve[eqSize] = runningBalance;
      g_tradeDates[eqSize] = dealTime;

      // Drawdown
      if(runningBalance > peakBalance)
         peakBalance = runningBalance;

      double currentDD = (peakBalance - runningBalance) / peakBalance * 100;
      if(currentDD > maxDD)
         maxDD = currentDD;

      // Calcul RR (estimation)
      // Note: Pour un calcul précis, il faudrait stocker SL/TP des trades
   }

   // Résultats finaux
   g_metrics.netProfit = g_metrics.grossProfit - g_metrics.grossLoss;
   g_metrics.tradingDays = ArraySize(tradingDays);
   g_metrics.maxDrawdownPercent = maxDD;

   if(g_metrics.totalTrades > 0) {
      g_metrics.winRate = (double)g_metrics.winningTrades / g_metrics.totalTrades * 100;
   }

   if(g_metrics.grossLoss > 0) {
      g_metrics.profitFactor = g_metrics.grossProfit / g_metrics.grossLoss;
   }

   if(g_metrics.totalTrades > 0) {
      g_metrics.expectedPayoff = g_metrics.netProfit / g_metrics.totalTrades;
   }

   Print("Analyse terminée. Trades: ", g_metrics.totalTrades);
}

//+------------------------------------------------------------------+
//| Calculer les métriques avancées                                   |
//+------------------------------------------------------------------+
void CalculateAdvancedMetrics() {
   // Recovery Factor
   if(g_metrics.maxDrawdownPercent > 0) {
      double maxDDAmount = InitialBalance * g_metrics.maxDrawdownPercent / 100;
      g_metrics.recoveryFactor = g_metrics.netProfit / maxDDAmount;
   }

   // Profit par jour
   if(g_metrics.tradingDays > 0) {
      g_metrics.profitPerDay = g_metrics.netProfit / g_metrics.tradingDays;
   }

   // Sharpe Ratio (simplifié)
   // Note: Calcul complet nécessiterait les rendements quotidiens
   if(ArraySize(g_equityCurve) > 1) {
      double returns[];
      ArrayResize(returns, ArraySize(g_equityCurve) - 1);

      for(int i = 1; i < ArraySize(g_equityCurve); i++) {
         returns[i-1] = (g_equityCurve[i] - g_equityCurve[i-1]) / g_equityCurve[i-1];
      }

      double avgReturn = 0, stdDev = 0;
      for(int i = 0; i < ArraySize(returns); i++) {
         avgReturn += returns[i];
      }
      avgReturn /= ArraySize(returns);

      for(int i = 0; i < ArraySize(returns); i++) {
         stdDev += MathPow(returns[i] - avgReturn, 2);
      }
      stdDev = MathSqrt(stdDev / ArraySize(returns));

      if(stdDev > 0) {
         // Annualisé (252 jours de trading)
         g_metrics.sharpeRatio = (avgReturn * 252) / (stdDev * MathSqrt(252));
      }
   }

   // Calcul du Daily Drawdown Maximum
   CalculateMaxDailyDrawdown();
}

//+------------------------------------------------------------------+
//| Calculer le drawdown journalier maximum                          |
//+------------------------------------------------------------------+
void CalculateMaxDailyDrawdown() {
   if(ArraySize(g_equityCurve) < 2) return;

   g_metrics.maxDailyDrawdown = 0;

   datetime currentDay = 0;
   double dayStartEquity = InitialBalance;
   double dayMinEquity = InitialBalance;

   for(int i = 0; i < ArraySize(g_equityCurve); i++) {
      MqlDateTime dt;
      TimeToStruct(g_tradeDates[i], dt);
      datetime thisDay = StructToTime(dt) - dt.hour * 3600 - dt.min * 60 - dt.sec;

      if(thisDay != currentDay) {
         // Nouveau jour
         if(currentDay != 0) {
            double dailyDD = (dayStartEquity - dayMinEquity) / dayStartEquity * 100;
            if(dailyDD > g_metrics.maxDailyDrawdown) {
               g_metrics.maxDailyDrawdown = dailyDD;
            }
         }
         currentDay = thisDay;
         dayStartEquity = (i > 0) ? g_equityCurve[i-1] : InitialBalance;
         dayMinEquity = g_equityCurve[i];
      }

      if(g_equityCurve[i] < dayMinEquity) {
         dayMinEquity = g_equityCurve[i];
      }
   }

   // Dernier jour
   double dailyDD = (dayStartEquity - dayMinEquity) / dayStartEquity * 100;
   if(dailyDD > g_metrics.maxDailyDrawdown) {
      g_metrics.maxDailyDrawdown = dailyDD;
   }
}

//+------------------------------------------------------------------+
//| Vérifier la conformité PropFirm                                   |
//+------------------------------------------------------------------+
void CheckPropFirmCompliance() {
   // Vérifier DD total
   g_metrics.ddLimitBreached = (g_metrics.maxDrawdownPercent >= g_constraints.maxTotalDD);

   // Vérifier DD journalier
   g_metrics.dailyDDBreached = (g_metrics.maxDailyDrawdown >= g_constraints.maxDailyDD);

   // Vérifier si le challenge serait passé
   double profitPercent = g_metrics.netProfit / InitialBalance * 100;

   g_metrics.wouldPassChallenge =
      (profitPercent >= g_constraints.profitTarget) &&
      (!g_metrics.ddLimitBreached) &&
      (!g_metrics.dailyDDBreached) &&
      (g_metrics.tradingDays >= g_constraints.minTradingDays);

   // Estimer jours pour atteindre target
   if(g_metrics.profitPerDay > 0 && g_metrics.tradingDays > 0) {
      double targetProfit = InitialBalance * g_constraints.profitTarget / 100;
      g_metrics.daysToTarget = (int)MathCeil(targetProfit / g_metrics.profitPerDay);
   }
}

//+------------------------------------------------------------------+
//| Générer le rapport                                                |
//+------------------------------------------------------------------+
void GenerateReport() {
   int handle = FileOpen(ReportFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE) {
      Print("Erreur ouverture fichier: ", GetLastError());
      return;
   }

   // En-tête
   FileWrite(handle, "Metric", "Value", "Target", "Status");

   // Performance
   FileWrite(handle, "--- PERFORMANCE ---", "", "", "");
   FileWrite(handle, "Net Profit ($)", DoubleToString(g_metrics.netProfit, 2), "", "");
   FileWrite(handle, "Net Profit (%)", DoubleToString(g_metrics.netProfit / InitialBalance * 100, 2),
             DoubleToString(g_constraints.profitTarget, 1) + "%",
             (g_metrics.netProfit / InitialBalance * 100 >= g_constraints.profitTarget) ? "PASS" : "FAIL");
   FileWrite(handle, "Gross Profit", DoubleToString(g_metrics.grossProfit, 2), "", "");
   FileWrite(handle, "Gross Loss", DoubleToString(g_metrics.grossLoss, 2), "", "");
   FileWrite(handle, "Profit Factor", DoubleToString(g_metrics.profitFactor, 2), ">1.5", (g_metrics.profitFactor >= 1.5) ? "GOOD" : "LOW");

   // Trades
   FileWrite(handle, "--- TRADES ---", "", "", "");
   FileWrite(handle, "Total Trades", IntegerToString(g_metrics.totalTrades), ">500", (g_metrics.totalTrades >= 500) ? "GOOD" : "LOW");
   FileWrite(handle, "Winning Trades", IntegerToString(g_metrics.winningTrades), "", "");
   FileWrite(handle, "Losing Trades", IntegerToString(g_metrics.losingTrades), "", "");
   FileWrite(handle, "Win Rate (%)", DoubleToString(g_metrics.winRate, 2), ">52%", (g_metrics.winRate >= 52) ? "GOOD" : "LOW");
   FileWrite(handle, "Max Consec. Wins", IntegerToString(g_metrics.maxConsecWins), "", "");
   FileWrite(handle, "Max Consec. Losses", IntegerToString(g_metrics.maxConsecLosses), "<6", (g_metrics.maxConsecLosses < 6) ? "GOOD" : "RISK");

   // Drawdown
   FileWrite(handle, "--- DRAWDOWN ---", "", "", "");
   FileWrite(handle, "Max Drawdown (%)", DoubleToString(g_metrics.maxDrawdownPercent, 2),
             "<" + DoubleToString(g_constraints.maxTotalDD, 1) + "%",
             (!g_metrics.ddLimitBreached) ? "PASS" : "BREACH");
   FileWrite(handle, "Max Daily DD (%)", DoubleToString(g_metrics.maxDailyDrawdown, 2),
             "<" + DoubleToString(g_constraints.maxDailyDD, 1) + "%",
             (!g_metrics.dailyDDBreached) ? "PASS" : "BREACH");

   // Ratios
   FileWrite(handle, "--- RATIOS ---", "", "", "");
   FileWrite(handle, "Sharpe Ratio", DoubleToString(g_metrics.sharpeRatio, 2), ">1.0", (g_metrics.sharpeRatio >= 1.0) ? "GOOD" : "LOW");
   FileWrite(handle, "Recovery Factor", DoubleToString(g_metrics.recoveryFactor, 2), ">3.0", (g_metrics.recoveryFactor >= 3.0) ? "GOOD" : "LOW");
   FileWrite(handle, "Expected Payoff", DoubleToString(g_metrics.expectedPayoff, 2), "", "");

   // PropFirm
   FileWrite(handle, "--- PROPFIRM COMPLIANCE ---", "", "", "");
   FileWrite(handle, "PropFirm", g_constraints.propFirmName, "", "");
   FileWrite(handle, "Trading Days", IntegerToString(g_metrics.tradingDays),
             ">=" + IntegerToString(g_constraints.minTradingDays),
             (g_metrics.tradingDays >= g_constraints.minTradingDays) ? "PASS" : "FAIL");
   FileWrite(handle, "Est. Days to Target", IntegerToString(g_metrics.daysToTarget), "", "");
   FileWrite(handle, "Would Pass Challenge", g_metrics.wouldPassChallenge ? "YES" : "NO", "", g_metrics.wouldPassChallenge ? "PASS" : "FAIL");

   FileClose(handle);
   Print("Rapport généré: ", ReportFile);
}

//+------------------------------------------------------------------+
//| Afficher le résumé                                                |
//+------------------------------------------------------------------+
void DisplaySummary() {
   string summary = "";
   summary += "\n";
   summary += "╔═══════════════════════════════════════════════════════════════╗\n";
   summary += "║                    BACKTEST ANALYSIS REPORT                    ║\n";
   summary += "╠═══════════════════════════════════════════════════════════════╣\n";
   summary += "║ PropFirm: " + g_constraints.propFirmName + "                                          ║\n";
   summary += "╠═══════════════════════════════════════════════════════════════╣\n";
   summary += "║                         PERFORMANCE                            ║\n";
   summary += "╠───────────────────────────────────────────────────────────────╣\n";
   summary += StringFormat("║ Net Profit:     $%-10.2f (%.2f%%)                        ║\n",
              g_metrics.netProfit, g_metrics.netProfit / InitialBalance * 100);
   summary += StringFormat("║ Profit Factor:  %-6.2f                                      ║\n", g_metrics.profitFactor);
   summary += StringFormat("║ Win Rate:       %.1f%%                                        ║\n", g_metrics.winRate);
   summary += "╠───────────────────────────────────────────────────────────────╣\n";
   summary += "║                          RISK                                  ║\n";
   summary += "╠───────────────────────────────────────────────────────────────╣\n";
   summary += StringFormat("║ Max Drawdown:   %.2f%% (Limit: %.1f%%)  %s               ║\n",
              g_metrics.maxDrawdownPercent, g_constraints.maxTotalDD,
              g_metrics.ddLimitBreached ? "[BREACH]" : "[OK]    ");
   summary += StringFormat("║ Max Daily DD:   %.2f%% (Limit: %.1f%%)  %s               ║\n",
              g_metrics.maxDailyDrawdown, g_constraints.maxDailyDD,
              g_metrics.dailyDDBreached ? "[BREACH]" : "[OK]    ");
   summary += StringFormat("║ Sharpe Ratio:   %.2f                                        ║\n", g_metrics.sharpeRatio);
   summary += StringFormat("║ Recovery:       %.2f                                        ║\n", g_metrics.recoveryFactor);
   summary += "╠───────────────────────────────────────────────────────────────╣\n";
   summary += "║                       CHALLENGE RESULT                         ║\n";
   summary += "╠───────────────────────────────────────────────────────────────╣\n";
   summary += StringFormat("║ Total Trades:   %d                                           ║\n", g_metrics.totalTrades);
   summary += StringFormat("║ Trading Days:   %d                                            ║\n", g_metrics.tradingDays);
   summary += StringFormat("║ Days to Target: ~%d                                           ║\n", g_metrics.daysToTarget);
   summary += "╠═══════════════════════════════════════════════════════════════╣\n";

   if(g_metrics.wouldPassChallenge) {
      summary += "║           ✓ CHALLENGE WOULD BE PASSED SUCCESSFULLY           ║\n";
   }
   else {
      summary += "║           ✗ CHALLENGE WOULD NOT PASS                          ║\n";
      if(g_metrics.ddLimitBreached)
         summary += "║             - Max DD limit breached                           ║\n";
      if(g_metrics.dailyDDBreached)
         summary += "║             - Daily DD limit breached                         ║\n";
      if(g_metrics.netProfit / InitialBalance * 100 < g_constraints.profitTarget)
         summary += "║             - Profit target not reached                       ║\n";
   }

   summary += "╚═══════════════════════════════════════════════════════════════╝\n";

   Print(summary);
}
//+------------------------------------------------------------------+
