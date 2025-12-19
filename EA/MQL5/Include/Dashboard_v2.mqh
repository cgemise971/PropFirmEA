//+------------------------------------------------------------------+
//|                                              Dashboard_v2.mqh    |
//|                        Dashboard Compact pour PropFirm Scalper   |
//|                                                                  |
//| Caracteristiques:                                                |
//| - Max 10-12 lignes (vs 25+ avant)                               |
//| - ASCII simple uniquement (=, -, |, [, ])                       |
//| - Mise a jour toutes les 500ms (pas chaque tick)                |
//| - 3 modes: COMPACT / STANDARD / DEBUG                           |
//+------------------------------------------------------------------+
#ifndef DASHBOARD_V2_MQH
#define DASHBOARD_V2_MQH

//--- Modes d'affichage
enum ENUM_DISPLAY_MODE {
   DISPLAY_OFF,        // Desactive
   DISPLAY_COMPACT,    // Compact (8 lignes)
   DISPLAY_STANDARD,   // Standard (12 lignes)
   DISPLAY_DEBUG       // Debug (20+ lignes)
};

//--- Structure pour les donnees du dashboard
struct DashboardData {
   // Identification
   string eaName;
   string eaVersion;
   string propFirm;
   string symbol;

   // Challenge Progress
   double targetPercent;
   double currentPercent;
   int totalDays;
   int daysElapsed;

   // Risk
   double riskPercent;
   double dailyDD;
   double maxDailyDD;
   double totalDD;
   double maxTotalDD;

   // Trading
   string currentSession;
   bool sessionActive;
   int todayTrades;
   int maxTrades;
   double lastTradePips;
   int consecutiveWins;
   int consecutiveLosses;
   int openPositions;
   double openPnL;

   // Signal
   bool hasSignal;
   string signalType;
   string signalDirection;
   int signalScore;
   int minScore;
   double signalEntry;
   double signalSL;
   double signalTP;

   // Mode special
   bool turboMode;
   double riskMultiplier;

   // Status
   bool canTrade;
   string blockReason;
};

//--- Variables globales du module
datetime g_lastDashboardUpdate = 0;
int g_dashboardUpdateMs = 500;  // Mise a jour toutes les 500ms

//+------------------------------------------------------------------+
//| Verifie si le dashboard doit etre mis a jour                    |
//+------------------------------------------------------------------+
bool ShouldUpdateDashboard() {
   datetime now = TimeCurrent();
   if((now - g_lastDashboardUpdate) * 1000 >= g_dashboardUpdateMs) {
      g_lastDashboardUpdate = now;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Cree une barre de progression ASCII                             |
//+------------------------------------------------------------------+
string CreateProgressBar(double percent, int width = 10) {
   int filled = (int)MathRound((MathMin(100, MathMax(0, percent)) / 100.0) * width);
   string bar = "[";
   for(int i = 0; i < width; i++) {
      bar += (i < filled) ? "=" : "-";
   }
   bar += "]";
   return bar;
}

//+------------------------------------------------------------------+
//| Formate les pips avec signe                                     |
//+------------------------------------------------------------------+
string FormatPips(double pips) {
   if(pips >= 0)
      return "+" + DoubleToString(pips, 1) + "p";
   else
      return DoubleToString(pips, 1) + "p";
}

//+------------------------------------------------------------------+
//| Formate le streak (W3 ou L2)                                    |
//+------------------------------------------------------------------+
string FormatStreak(int wins, int losses) {
   if(wins > 0)
      return "W" + IntegerToString(wins);
   else if(losses > 0)
      return "L" + IntegerToString(losses);
   else
      return "--";
}

//+------------------------------------------------------------------+
//| Affichage MODE COMPACT (8 lignes)                               |
//+------------------------------------------------------------------+
string BuildCompactDashboard(DashboardData &data) {
   string s = "\n";

   // Ligne 1: Header
   s += "=== " + data.eaName + " " + data.eaVersion + " | " + data.propFirm + " ===\n";

   // Ligne 2: Progress
   double progressPct = (data.targetPercent > 0) ? (data.currentPercent / data.targetPercent) * 100 : 0;
   s += "Progress: " + DoubleToString(data.currentPercent, 1) + "%/" +
        DoubleToString(data.targetPercent, 0) + "% " +
        CreateProgressBar(progressPct, 10) + " " +
        DoubleToString(progressPct, 0) + "%\n";

   // Ligne 3: Risk & DD
   s += "Risk: " + DoubleToString(data.riskPercent * data.riskMultiplier, 1) + "% | ";
   s += "DD: " + DoubleToString(data.dailyDD, 1) + "%/" + DoubleToString(data.maxDailyDD, 0) + "%";
   if(data.turboMode) s += " [TURBO]";
   s += "\n\n";

   // Ligne 4: Session & Trades
   s += "Session: " + data.currentSession;
   s += (data.sessionActive ? " [ON]" : " [--]");
   s += " | Trades: " + IntegerToString(data.todayTrades) + "/" + IntegerToString(data.maxTrades) + "\n";

   // Ligne 5: Last trade & Streak
   s += "Last: " + FormatPips(data.lastTradePips);
   s += " | Streak: " + FormatStreak(data.consecutiveWins, data.consecutiveLosses);
   s += " | Open: " + IntegerToString(data.openPositions) + "\n\n";

   // Ligne 6-7: Signal
   if(data.hasSignal) {
      s += "Signal: " + data.signalType + " " + data.signalDirection;
      s += " | Score: " + IntegerToString(data.signalScore) + "/" + IntegerToString(data.minScore) + "\n";
      s += "Entry: " + DoubleToString(data.signalEntry, (int)SymbolInfoInteger(data.symbol, SYMBOL_DIGITS));
      s += " | SL: " + DoubleToString(data.signalSL, 0) + "p";
      s += " | TP: " + DoubleToString(data.signalTP, 0) + "p\n";
   } else {
      if(!data.canTrade) {
         s += "Status: BLOCKED - " + data.blockReason + "\n";
      } else {
         s += "Status: Scanning...\n";
      }
   }

   // Ligne 8: Footer
   s += "================================\n";

   return s;
}

//+------------------------------------------------------------------+
//| Affichage MODE STANDARD (12 lignes)                             |
//+------------------------------------------------------------------+
string BuildStandardDashboard(DashboardData &data) {
   string s = "\n";

   // Header
   s += "======================================\n";
   s += "  " + data.eaName + " " + data.eaVersion + "\n";
   s += "  " + data.propFirm + " | " + data.symbol + "\n";
   s += "======================================\n\n";

   // Challenge Progress
   double progressPct = (data.targetPercent > 0) ? (data.currentPercent / data.targetPercent) * 100 : 0;
   s += "CHALLENGE: " + DoubleToString(data.currentPercent, 2) + "% / " +
        DoubleToString(data.targetPercent, 0) + "% target\n";
   s += CreateProgressBar(progressPct, 20) + " " + DoubleToString(progressPct, 0) + "% done\n";
   s += "Days: " + IntegerToString(data.daysElapsed) + "/" + IntegerToString(data.totalDays) + "\n\n";

   // Risk Management
   s += "RISK: " + DoubleToString(data.riskPercent * data.riskMultiplier, 2) + "% per trade\n";
   s += "Daily DD: " + DoubleToString(data.dailyDD, 2) + "% / " + DoubleToString(data.maxDailyDD, 1) + "% max\n";
   s += "Total DD: " + DoubleToString(data.totalDD, 2) + "% / " + DoubleToString(data.maxTotalDD, 1) + "% max\n";
   if(data.turboMode) {
      s += ">>> TURBO MODE ACTIVE (x" + DoubleToString(data.riskMultiplier, 1) + ") <<<\n";
   }
   s += "\n";

   // Trading Status
   s += "SESSION: " + data.currentSession + (data.sessionActive ? " [ACTIVE]" : " [CLOSED]") + "\n";
   s += "Trades today: " + IntegerToString(data.todayTrades) + " / " + IntegerToString(data.maxTrades) + "\n";
   s += "Open positions: " + IntegerToString(data.openPositions);
   s += " | PnL: " + DoubleToString(data.openPnL, 2) + "\n";
   s += "Last: " + FormatPips(data.lastTradePips);
   s += " | Streak: " + FormatStreak(data.consecutiveWins, data.consecutiveLosses) + "\n\n";

   // Current Signal
   s += "SIGNAL:\n";
   if(data.hasSignal) {
      s += "  Type: " + data.signalType + " " + data.signalDirection + "\n";
      s += "  Score: " + IntegerToString(data.signalScore) + "/" + IntegerToString(data.minScore) + "\n";
      s += "  Entry: " + DoubleToString(data.signalEntry, (int)SymbolInfoInteger(data.symbol, SYMBOL_DIGITS)) + "\n";
      s += "  SL: " + DoubleToString(data.signalSL, 0) + " pips | TP: " + DoubleToString(data.signalTP, 0) + " pips\n";
   } else {
      if(!data.canTrade) {
         s += "  BLOCKED: " + data.blockReason + "\n";
      } else {
         s += "  Scanning for opportunities...\n";
      }
   }

   s += "\n======================================\n";

   return s;
}

//+------------------------------------------------------------------+
//| Affichage MODE DEBUG (toutes les infos)                         |
//+------------------------------------------------------------------+
string BuildDebugDashboard(DashboardData &data) {
   string s = BuildStandardDashboard(data);

   // Ajouter infos debug
   s += "\n--- DEBUG INFO ---\n";
   s += "Symbol: " + data.symbol + "\n";
   s += "Spread: " + DoubleToString(SymbolInfoInteger(data.symbol, SYMBOL_SPREAD) / 10.0, 1) + " pips\n";
   s += "Risk Multiplier: " + DoubleToString(data.riskMultiplier, 2) + "\n";
   s += "Consec Wins: " + IntegerToString(data.consecutiveWins) + "\n";
   s += "Consec Losses: " + IntegerToString(data.consecutiveLosses) + "\n";
   s += "Last Update: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n";
   s += "------------------\n";

   return s;
}

//+------------------------------------------------------------------+
//| Fonction principale d'affichage                                 |
//+------------------------------------------------------------------+
void DisplayDashboard(DashboardData &data, ENUM_DISPLAY_MODE mode) {
   if(mode == DISPLAY_OFF) {
      Comment("");
      return;
   }

   // Limiter les mises a jour pour eviter le flickering
   if(!ShouldUpdateDashboard()) return;

   string dashboard = "";

   switch(mode) {
      case DISPLAY_COMPACT:
         dashboard = BuildCompactDashboard(data);
         break;
      case DISPLAY_STANDARD:
         dashboard = BuildStandardDashboard(data);
         break;
      case DISPLAY_DEBUG:
         dashboard = BuildDebugDashboard(data);
         break;
      default:
         dashboard = BuildCompactDashboard(data);
   }

   Comment(dashboard);
}

//+------------------------------------------------------------------+
//| Helper: Initialise les donnees du dashboard avec des valeurs    |
//| par defaut                                                       |
//+------------------------------------------------------------------+
void InitDashboardData(DashboardData &data, string eaName, string version, string propFirm) {
   data.eaName = eaName;
   data.eaVersion = version;
   data.propFirm = propFirm;
   data.symbol = _Symbol;

   data.targetPercent = 10.0;
   data.currentPercent = 0.0;
   data.totalDays = 30;
   data.daysElapsed = 0;

   data.riskPercent = 0.6;
   data.dailyDD = 0.0;
   data.maxDailyDD = 5.0;
   data.totalDD = 0.0;
   data.maxTotalDD = 10.0;

   data.currentSession = "SCANNING";
   data.sessionActive = false;
   data.todayTrades = 0;
   data.maxTrades = 15;
   data.lastTradePips = 0.0;
   data.consecutiveWins = 0;
   data.consecutiveLosses = 0;
   data.openPositions = 0;
   data.openPnL = 0.0;

   data.hasSignal = false;
   data.signalType = "";
   data.signalDirection = "";
   data.signalScore = 0;
   data.minScore = 3;
   data.signalEntry = 0.0;
   data.signalSL = 0.0;
   data.signalTP = 0.0;

   data.turboMode = false;
   data.riskMultiplier = 1.0;

   data.canTrade = true;
   data.blockReason = "";
}

#endif // DASHBOARD_V2_MQH
