#!/usr/bin/env python3
"""
PropFirm Backtest Analyzer
Analyse approfondie des résultats de backtest avec visualisations
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os
import sys

# Pour les graphiques (optionnel)
try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Note: matplotlib non installé. Graphiques désactivés.")

#==============================================================================
# CONFIGURATION PROPFIRM
#==============================================================================

PROPFIRM_RULES = {
    'FTMO': {
        'max_daily_dd': 5.0,
        'max_total_dd': 10.0,
        'profit_target_p1': 10.0,
        'profit_target_p2': 5.0,
        'min_trading_days': 4,
        'profit_split': 80
    },
    'E8_One': {
        'max_daily_dd': 5.0,
        'max_total_dd': 6.0,
        'profit_target_p1': 10.0,
        'profit_target_p2': 0,
        'min_trading_days': 3,
        'profit_split': 80
    },
    'FundingPips_1Step': {
        'max_daily_dd': 4.0,
        'max_total_dd': 6.0,
        'profit_target_p1': 10.0,
        'profit_target_p2': 0,
        'min_trading_days': 3,
        'profit_split': 80
    },
    'The5ers_Bootcamp': {
        'max_daily_dd': 100.0,  # Pas de limite en eval
        'max_total_dd': 5.0,
        'profit_target_p1': 6.0,
        'profit_target_p2': 6.0,
        'min_trading_days': 0,
        'profit_split': 80
    }
}

#==============================================================================
# CLASSE PRINCIPALE
#==============================================================================

class BacktestAnalyzer:
    def __init__(self, initial_balance=100000):
        self.initial_balance = initial_balance
        self.trades = []
        self.equity_curve = []
        self.daily_pnl = {}
        self.metrics = {}

    def load_mt5_report(self, filepath):
        """Charge un rapport MT5 au format CSV ou HTML"""
        if filepath.endswith('.csv'):
            return self._load_csv(filepath)
        elif filepath.endswith('.html') or filepath.endswith('.htm'):
            return self._load_html(filepath)
        else:
            print(f"Format non supporté: {filepath}")
            return False

    def _load_csv(self, filepath):
        """Charge un fichier CSV de trades"""
        try:
            df = pd.read_csv(filepath)
            # Adapter selon le format de votre export
            self.trades_df = df
            print(f"Chargé {len(df)} lignes depuis {filepath}")
            return True
        except Exception as e:
            print(f"Erreur chargement CSV: {e}")
            return False

    def _load_html(self, filepath):
        """Charge un rapport HTML MT5"""
        try:
            tables = pd.read_html(filepath)
            # Le rapport MT5 contient généralement plusieurs tables
            # La table des trades est souvent la plus grande
            for table in tables:
                if len(table) > 10:  # Probablement la table des trades
                    self.trades_df = table
                    break
            print(f"Rapport HTML chargé depuis {filepath}")
            return True
        except Exception as e:
            print(f"Erreur chargement HTML: {e}")
            return False

    def load_from_list(self, trades_list):
        """
        Charge les trades depuis une liste de dictionnaires
        Format: [{'date': datetime, 'profit': float, 'type': 'BUY'/'SELL', ...}, ...]
        """
        self.trades = trades_list
        self._build_equity_curve()
        return True

    def _build_equity_curve(self):
        """Construit la courbe d'équité"""
        balance = self.initial_balance
        self.equity_curve = [{'date': None, 'equity': balance}]

        for trade in self.trades:
            balance += trade.get('profit', 0)
            self.equity_curve.append({
                'date': trade.get('date'),
                'equity': balance
            })

    def calculate_metrics(self):
        """Calcule toutes les métriques de performance"""
        if not self.trades:
            print("Aucun trade à analyser")
            return

        # Métriques de base
        profits = [t['profit'] for t in self.trades if t['profit'] > 0]
        losses = [abs(t['profit']) for t in self.trades if t['profit'] < 0]

        self.metrics['total_trades'] = len(self.trades)
        self.metrics['winning_trades'] = len(profits)
        self.metrics['losing_trades'] = len(losses)
        self.metrics['win_rate'] = len(profits) / len(self.trades) * 100 if self.trades else 0

        self.metrics['gross_profit'] = sum(profits)
        self.metrics['gross_loss'] = sum(losses)
        self.metrics['net_profit'] = self.metrics['gross_profit'] - self.metrics['gross_loss']
        self.metrics['net_profit_pct'] = self.metrics['net_profit'] / self.initial_balance * 100

        self.metrics['profit_factor'] = (
            self.metrics['gross_profit'] / self.metrics['gross_loss']
            if self.metrics['gross_loss'] > 0 else float('inf')
        )

        self.metrics['avg_win'] = np.mean(profits) if profits else 0
        self.metrics['avg_loss'] = np.mean(losses) if losses else 0
        self.metrics['expected_payoff'] = self.metrics['net_profit'] / len(self.trades) if self.trades else 0

        # Drawdown
        self._calculate_drawdown()

        # Séries consécutives
        self._calculate_consecutive_series()

        # Ratios avancés
        self._calculate_advanced_ratios()

        # Jours de trading
        self._calculate_trading_days()

    def _calculate_drawdown(self):
        """Calcule le drawdown maximum et journalier"""
        if not self.equity_curve:
            return

        equities = [e['equity'] for e in self.equity_curve]
        peak = equities[0]
        max_dd = 0
        max_dd_pct = 0

        for equity in equities:
            if equity > peak:
                peak = equity
            dd = peak - equity
            dd_pct = dd / peak * 100
            if dd_pct > max_dd_pct:
                max_dd = dd
                max_dd_pct = dd_pct

        self.metrics['max_drawdown'] = max_dd
        self.metrics['max_drawdown_pct'] = max_dd_pct

        # Drawdown journalier maximum
        self._calculate_daily_drawdown()

    def _calculate_daily_drawdown(self):
        """Calcule le drawdown journalier maximum"""
        daily_pnl = {}

        for trade in self.trades:
            date = trade.get('date')
            if date:
                day = date.date() if hasattr(date, 'date') else date
                if day not in daily_pnl:
                    daily_pnl[day] = 0
                daily_pnl[day] += trade['profit']

        self.daily_pnl = daily_pnl

        if daily_pnl:
            # Calculer le pire jour en %
            worst_day = min(daily_pnl.values())
            worst_day_pct = abs(worst_day) / self.initial_balance * 100
            self.metrics['max_daily_dd_pct'] = worst_day_pct
            self.metrics['worst_day'] = worst_day
        else:
            self.metrics['max_daily_dd_pct'] = 0
            self.metrics['worst_day'] = 0

    def _calculate_consecutive_series(self):
        """Calcule les séries de gains/pertes consécutifs"""
        max_consec_wins = 0
        max_consec_losses = 0
        current_wins = 0
        current_losses = 0

        for trade in self.trades:
            if trade['profit'] > 0:
                current_wins += 1
                current_losses = 0
                max_consec_wins = max(max_consec_wins, current_wins)
            else:
                current_losses += 1
                current_wins = 0
                max_consec_losses = max(max_consec_losses, current_losses)

        self.metrics['max_consec_wins'] = max_consec_wins
        self.metrics['max_consec_losses'] = max_consec_losses

    def _calculate_advanced_ratios(self):
        """Calcule Sharpe, Sortino, Recovery Factor"""
        if not self.trades:
            return

        returns = [t['profit'] / self.initial_balance for t in self.trades]

        # Sharpe Ratio (annualisé)
        avg_return = np.mean(returns)
        std_return = np.std(returns)
        if std_return > 0:
            self.metrics['sharpe_ratio'] = (avg_return * 252) / (std_return * np.sqrt(252))
        else:
            self.metrics['sharpe_ratio'] = 0

        # Sortino Ratio (ne considère que la volatilité négative)
        negative_returns = [r for r in returns if r < 0]
        if negative_returns:
            downside_std = np.std(negative_returns)
            if downside_std > 0:
                self.metrics['sortino_ratio'] = (avg_return * 252) / (downside_std * np.sqrt(252))
            else:
                self.metrics['sortino_ratio'] = 0
        else:
            self.metrics['sortino_ratio'] = float('inf')

        # Recovery Factor
        if self.metrics.get('max_drawdown', 0) > 0:
            self.metrics['recovery_factor'] = self.metrics['net_profit'] / self.metrics['max_drawdown']
        else:
            self.metrics['recovery_factor'] = float('inf')

    def _calculate_trading_days(self):
        """Calcule le nombre de jours de trading"""
        trading_days = set()
        for trade in self.trades:
            date = trade.get('date')
            if date:
                day = date.date() if hasattr(date, 'date') else date
                trading_days.add(day)

        self.metrics['trading_days'] = len(trading_days)

    def check_propfirm_compliance(self, propfirm='FTMO'):
        """Vérifie la conformité avec les règles d'une prop firm"""
        if propfirm not in PROPFIRM_RULES:
            print(f"PropFirm inconnue: {propfirm}")
            return None

        rules = PROPFIRM_RULES[propfirm]
        results = {
            'propfirm': propfirm,
            'checks': {}
        }

        # Check DD total
        dd_total_ok = self.metrics.get('max_drawdown_pct', 100) < rules['max_total_dd']
        results['checks']['max_total_dd'] = {
            'value': self.metrics.get('max_drawdown_pct', 0),
            'limit': rules['max_total_dd'],
            'passed': dd_total_ok
        }

        # Check DD journalier
        dd_daily_ok = self.metrics.get('max_daily_dd_pct', 100) < rules['max_daily_dd']
        results['checks']['max_daily_dd'] = {
            'value': self.metrics.get('max_daily_dd_pct', 0),
            'limit': rules['max_daily_dd'],
            'passed': dd_daily_ok
        }

        # Check profit target
        profit_ok = self.metrics.get('net_profit_pct', 0) >= rules['profit_target_p1']
        results['checks']['profit_target'] = {
            'value': self.metrics.get('net_profit_pct', 0),
            'limit': rules['profit_target_p1'],
            'passed': profit_ok
        }

        # Check trading days
        days_ok = self.metrics.get('trading_days', 0) >= rules['min_trading_days']
        results['checks']['min_trading_days'] = {
            'value': self.metrics.get('trading_days', 0),
            'limit': rules['min_trading_days'],
            'passed': days_ok
        }

        # Résultat global
        results['would_pass'] = all(c['passed'] for c in results['checks'].values())

        # Estimation des gains si funded
        if results['would_pass']:
            estimated_monthly = self.metrics.get('net_profit', 0) * rules['profit_split'] / 100
            results['estimated_payout'] = estimated_monthly

        return results

    def generate_report(self, propfirm='FTMO'):
        """Génère un rapport complet"""
        compliance = self.check_propfirm_compliance(propfirm)

        report = []
        report.append("=" * 70)
        report.append("                    PROPFIRM BACKTEST REPORT")
        report.append("=" * 70)
        report.append(f"\nPropFirm: {propfirm}")
        report.append(f"Initial Balance: ${self.initial_balance:,.2f}")
        report.append("")

        report.append("-" * 70)
        report.append("PERFORMANCE METRICS")
        report.append("-" * 70)
        report.append(f"Net Profit:       ${self.metrics.get('net_profit', 0):,.2f} ({self.metrics.get('net_profit_pct', 0):.2f}%)")
        report.append(f"Gross Profit:     ${self.metrics.get('gross_profit', 0):,.2f}")
        report.append(f"Gross Loss:       ${self.metrics.get('gross_loss', 0):,.2f}")
        report.append(f"Profit Factor:    {self.metrics.get('profit_factor', 0):.2f}")
        report.append(f"Expected Payoff:  ${self.metrics.get('expected_payoff', 0):.2f}")
        report.append("")

        report.append("-" * 70)
        report.append("TRADE STATISTICS")
        report.append("-" * 70)
        report.append(f"Total Trades:     {self.metrics.get('total_trades', 0)}")
        report.append(f"Winning Trades:   {self.metrics.get('winning_trades', 0)}")
        report.append(f"Losing Trades:    {self.metrics.get('losing_trades', 0)}")
        report.append(f"Win Rate:         {self.metrics.get('win_rate', 0):.2f}%")
        report.append(f"Avg Win:          ${self.metrics.get('avg_win', 0):.2f}")
        report.append(f"Avg Loss:         ${self.metrics.get('avg_loss', 0):.2f}")
        report.append(f"Max Consec Wins:  {self.metrics.get('max_consec_wins', 0)}")
        report.append(f"Max Consec Losses:{self.metrics.get('max_consec_losses', 0)}")
        report.append("")

        report.append("-" * 70)
        report.append("RISK METRICS")
        report.append("-" * 70)
        report.append(f"Max Drawdown:     ${self.metrics.get('max_drawdown', 0):,.2f} ({self.metrics.get('max_drawdown_pct', 0):.2f}%)")
        report.append(f"Max Daily DD:     {self.metrics.get('max_daily_dd_pct', 0):.2f}%")
        report.append(f"Sharpe Ratio:     {self.metrics.get('sharpe_ratio', 0):.2f}")
        report.append(f"Sortino Ratio:    {self.metrics.get('sortino_ratio', 0):.2f}")
        report.append(f"Recovery Factor:  {self.metrics.get('recovery_factor', 0):.2f}")
        report.append(f"Trading Days:     {self.metrics.get('trading_days', 0)}")
        report.append("")

        report.append("-" * 70)
        report.append(f"PROPFIRM COMPLIANCE - {propfirm}")
        report.append("-" * 70)

        if compliance:
            for check_name, check_data in compliance['checks'].items():
                status = "✓ PASS" if check_data['passed'] else "✗ FAIL"
                report.append(f"{check_name:20s}: {check_data['value']:.2f} (limit: {check_data['limit']}) [{status}]")

            report.append("")
            report.append("=" * 70)
            if compliance['would_pass']:
                report.append("         ✓ CHALLENGE WOULD BE PASSED SUCCESSFULLY")
                report.append(f"         Estimated Payout: ${compliance.get('estimated_payout', 0):,.2f}")
            else:
                report.append("         ✗ CHALLENGE WOULD NOT PASS")
            report.append("=" * 70)

        return "\n".join(report)

    def plot_equity_curve(self, save_path=None):
        """Génère le graphique de la courbe d'équité"""
        if not HAS_MATPLOTLIB:
            print("matplotlib requis pour les graphiques")
            return

        if not self.equity_curve:
            print("Pas de données d'équité")
            return

        fig, axes = plt.subplots(2, 2, figsize=(14, 10))
        fig.suptitle('PropFirm Backtest Analysis', fontsize=14, fontweight='bold')

        # 1. Equity Curve
        ax1 = axes[0, 0]
        equities = [e['equity'] for e in self.equity_curve]
        ax1.plot(equities, 'b-', linewidth=1)
        ax1.axhline(y=self.initial_balance, color='gray', linestyle='--', alpha=0.5)
        ax1.fill_between(range(len(equities)), self.initial_balance, equities,
                        where=[e >= self.initial_balance for e in equities],
                        color='green', alpha=0.3)
        ax1.fill_between(range(len(equities)), self.initial_balance, equities,
                        where=[e < self.initial_balance for e in equities],
                        color='red', alpha=0.3)
        ax1.set_title('Equity Curve')
        ax1.set_xlabel('Trade #')
        ax1.set_ylabel('Equity ($)')
        ax1.grid(True, alpha=0.3)

        # 2. Drawdown
        ax2 = axes[0, 1]
        drawdowns = []
        peak = equities[0]
        for equity in equities:
            if equity > peak:
                peak = equity
            dd_pct = (peak - equity) / peak * 100
            drawdowns.append(dd_pct)

        ax2.fill_between(range(len(drawdowns)), 0, drawdowns, color='red', alpha=0.5)
        ax2.axhline(y=5, color='orange', linestyle='--', label='Daily DD Limit (5%)')
        ax2.axhline(y=10, color='red', linestyle='--', label='Max DD Limit (10%)')
        ax2.set_title('Drawdown (%)')
        ax2.set_xlabel('Trade #')
        ax2.set_ylabel('Drawdown (%)')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        ax2.invert_yaxis()

        # 3. Distribution des profits
        ax3 = axes[1, 0]
        profits = [t['profit'] for t in self.trades]
        ax3.hist(profits, bins=50, color='steelblue', edgecolor='black', alpha=0.7)
        ax3.axvline(x=0, color='red', linestyle='--')
        ax3.axvline(x=np.mean(profits), color='green', linestyle='--', label=f'Mean: ${np.mean(profits):.2f}')
        ax3.set_title('Profit Distribution')
        ax3.set_xlabel('Profit ($)')
        ax3.set_ylabel('Frequency')
        ax3.legend()
        ax3.grid(True, alpha=0.3)

        # 4. Performance cumulée par jour
        ax4 = axes[1, 1]
        if self.daily_pnl:
            days = sorted(self.daily_pnl.keys())
            cumulative = []
            total = 0
            for day in days:
                total += self.daily_pnl[day]
                cumulative.append(total)

            ax4.bar(range(len(days)), [self.daily_pnl[d] for d in days],
                   color=['green' if self.daily_pnl[d] >= 0 else 'red' for d in days],
                   alpha=0.7)
            ax4.set_title('Daily P&L')
            ax4.set_xlabel('Trading Day')
            ax4.set_ylabel('P&L ($)')
            ax4.axhline(y=0, color='black', linewidth=0.5)
            ax4.grid(True, alpha=0.3)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"Graphique sauvegardé: {save_path}")
        else:
            plt.show()

        plt.close()


#==============================================================================
# FONCTIONS UTILITAIRES
#==============================================================================

def generate_sample_trades(num_trades=500, win_rate=0.55, avg_rr=1.5):
    """Génère des trades simulés pour tester l'analyseur"""
    import random
    from datetime import datetime, timedelta

    trades = []
    base_date = datetime(2024, 1, 1)
    avg_loss = 100  # $100 par perte en moyenne
    avg_win = avg_loss * avg_rr

    for i in range(num_trades):
        is_win = random.random() < win_rate

        if is_win:
            profit = avg_win * (0.5 + random.random())  # Variation
        else:
            profit = -avg_loss * (0.5 + random.random())

        trade_date = base_date + timedelta(hours=i*4)  # ~6 trades par jour

        trades.append({
            'date': trade_date,
            'profit': profit,
            'type': random.choice(['BUY', 'SELL'])
        })

    return trades


def main():
    """Fonction principale de démonstration"""
    print("\n" + "="*70)
    print("        PROPFIRM BACKTEST ANALYZER - DEMONSTRATION")
    print("="*70 + "\n")

    # Créer l'analyseur
    analyzer = BacktestAnalyzer(initial_balance=100000)

    # Générer des trades de test
    print("Génération de trades simulés...")
    sample_trades = generate_sample_trades(num_trades=500, win_rate=0.57, avg_rr=1.6)
    analyzer.load_from_list(sample_trades)

    # Calculer les métriques
    print("Calcul des métriques...")
    analyzer.calculate_metrics()

    # Générer et afficher le rapport pour différentes prop firms
    for propfirm in ['FTMO', 'E8_One', 'FundingPips_1Step']:
        print("\n")
        report = analyzer.generate_report(propfirm)
        print(report)

    # Générer les graphiques
    if HAS_MATPLOTLIB:
        print("\nGénération des graphiques...")
        analyzer.plot_equity_curve(save_path='backtest_analysis.png')

    print("\n" + "="*70)
    print("Analyse terminée!")
    print("="*70)


if __name__ == "__main__":
    main()
