#!/usr/bin/env python3
"""
PropFirm Validator
Outil de validation rapide des résultats de backtest selon les règles des prop firms
"""

import sys
from datetime import datetime

#==============================================================================
# RÈGLES DES PROP FIRMS
#==============================================================================

PROPFIRM_PROFILES = {
    'FTMO': {
        'name': 'FTMO (Normal)',
        'max_daily_dd': 5.0,
        'max_total_dd': 10.0,
        'profit_target': 10.0,
        'min_trading_days': 4,
        'buffer_daily': 0.5,    # Buffer de sécurité recommandé
        'buffer_total': 1.0,
        'challenge_cost': 540,   # EUR pour $100K
        'profit_split': 80,
        'notes': 'News filter obligatoire, pas de weekend holding'
    },
    'FTMO_SWING': {
        'name': 'FTMO (Swing)',
        'max_daily_dd': 5.0,
        'max_total_dd': 10.0,
        'profit_target': 10.0,
        'min_trading_days': 4,
        'buffer_daily': 0.5,
        'buffer_total': 1.0,
        'challenge_cost': 540,
        'profit_split': 80,
        'notes': 'News trading OK, weekend holding OK, leverage 1:30'
    },
    'E8_ONE': {
        'name': 'E8 Markets One Step',
        'max_daily_dd': 5.0,
        'max_total_dd': 6.0,
        'profit_target': 10.0,
        'min_trading_days': 3,
        'buffer_daily': 0.5,
        'buffer_total': 0.5,
        'challenge_cost': 400,
        'profit_split': 80,
        'notes': 'DD serré (6%), 1-step rapide'
    },
    'E8_CLASSIC': {
        'name': 'E8 Markets Classic',
        'max_daily_dd': 5.0,
        'max_total_dd': 8.0,
        'profit_target': 8.0,
        'min_trading_days': 3,
        'buffer_daily': 0.5,
        'buffer_total': 0.5,
        'challenge_cost': 350,
        'profit_split': 80,
        'notes': '2-step, target plus accessible'
    },
    'FUNDING_PIPS_1STEP': {
        'name': 'Funding Pips 1-Step',
        'max_daily_dd': 4.0,
        'max_total_dd': 6.0,
        'profit_target': 10.0,
        'min_trading_days': 3,
        'buffer_daily': 0.5,
        'buffer_total': 0.5,
        'challenge_cost': 400,
        'profit_split': 80,
        'notes': 'DD journalier le plus strict (4%)'
    },
    'FUNDING_PIPS_2STEP': {
        'name': 'Funding Pips 2-Step',
        'max_daily_dd': 5.0,
        'max_total_dd': 10.0,
        'profit_target': 8.0,
        'min_trading_days': 3,
        'buffer_daily': 0.5,
        'buffer_total': 1.0,
        'challenge_cost': 350,
        'profit_split': 80,
        'notes': 'Target 8%, conditions plus souples'
    },
    'THE5ERS_BOOTCAMP': {
        'name': 'The5ers Bootcamp',
        'max_daily_dd': 100.0,  # Pas de limite en eval
        'max_total_dd': 5.0,
        'profit_target': 6.0,
        'min_trading_days': 0,
        'buffer_daily': 0,
        'buffer_total': 0.5,
        'challenge_cost': 250,
        'profit_split': 50,
        'notes': 'ATTENTION: Règle 2% SL obligatoire!'
    },
    'THE5ERS_HIGHSTAKES': {
        'name': 'The5ers High Stakes',
        'max_daily_dd': 5.0,
        'max_total_dd': 10.0,
        'profit_target': 8.0,
        'min_trading_days': 3,
        'buffer_daily': 0.5,
        'buffer_total': 1.0,
        'challenge_cost': 495,
        'profit_split': 80,
        'notes': '2-step classique'
    }
}

#==============================================================================
# VALIDATEUR
#==============================================================================

class PropFirmValidator:
    def __init__(self, profile_name='FTMO'):
        if profile_name not in PROPFIRM_PROFILES:
            raise ValueError(f"Profil inconnu: {profile_name}")
        self.profile = PROPFIRM_PROFILES[profile_name]
        self.profile_name = profile_name

    def validate(self, metrics: dict) -> dict:
        """
        Valide les métriques contre les règles de la prop firm

        metrics attendus:
        - net_profit_pct: Profit net en %
        - max_dd_pct: Drawdown maximum en %
        - max_daily_dd_pct: Drawdown journalier max en %
        - trading_days: Nombre de jours de trading
        - profit_factor: Profit Factor
        - win_rate: Win rate en %
        - total_trades: Nombre total de trades
        """
        results = {
            'profile': self.profile['name'],
            'timestamp': datetime.now().isoformat(),
            'checks': {},
            'score': 0,
            'max_score': 100,
            'recommendation': '',
            'warnings': []
        }

        # 1. Vérification DD Total (25 points)
        max_dd = metrics.get('max_dd_pct', 100)
        limit_dd = self.profile['max_total_dd']
        safe_dd = limit_dd - self.profile['buffer_total']

        results['checks']['max_total_dd'] = {
            'value': max_dd,
            'limit': limit_dd,
            'safe_limit': safe_dd,
            'passed': max_dd < limit_dd,
            'safe': max_dd < safe_dd
        }

        if max_dd < safe_dd:
            results['score'] += 25
        elif max_dd < limit_dd:
            results['score'] += 15
            results['warnings'].append(f"DD proche de la limite ({max_dd:.1f}% vs {limit_dd}%)")

        # 2. Vérification DD Journalier (25 points)
        daily_dd = metrics.get('max_daily_dd_pct', 100)
        limit_daily = self.profile['max_daily_dd']
        safe_daily = limit_daily - self.profile['buffer_daily']

        results['checks']['max_daily_dd'] = {
            'value': daily_dd,
            'limit': limit_daily,
            'safe_limit': safe_daily,
            'passed': daily_dd < limit_daily,
            'safe': daily_dd < safe_daily
        }

        if daily_dd < safe_daily:
            results['score'] += 25
        elif daily_dd < limit_daily:
            results['score'] += 15
            results['warnings'].append(f"DD journalier proche de la limite ({daily_dd:.1f}% vs {limit_daily}%)")

        # 3. Vérification Profit Target (20 points)
        profit = metrics.get('net_profit_pct', 0)
        target = self.profile['profit_target']

        results['checks']['profit_target'] = {
            'value': profit,
            'limit': target,
            'passed': profit >= target,
            'margin': profit - target
        }

        if profit >= target * 1.5:
            results['score'] += 20
        elif profit >= target:
            results['score'] += 15
        elif profit >= target * 0.8:
            results['score'] += 5

        # 4. Vérification Trading Days (10 points)
        days = metrics.get('trading_days', 0)
        min_days = self.profile['min_trading_days']

        results['checks']['trading_days'] = {
            'value': days,
            'limit': min_days,
            'passed': days >= min_days
        }

        if days >= min_days:
            results['score'] += 10

        # 5. Métriques de Qualité (20 points)
        pf = metrics.get('profit_factor', 0)
        wr = metrics.get('win_rate', 0)
        trades = metrics.get('total_trades', 0)

        results['checks']['quality'] = {
            'profit_factor': pf,
            'win_rate': wr,
            'total_trades': trades
        }

        # Profit Factor (8 points)
        if pf >= 2.0:
            results['score'] += 8
        elif pf >= 1.5:
            results['score'] += 6
        elif pf >= 1.3:
            results['score'] += 3

        # Win Rate (6 points)
        if wr >= 58:
            results['score'] += 6
        elif wr >= 55:
            results['score'] += 4
        elif wr >= 52:
            results['score'] += 2

        # Nombre de trades (6 points)
        if trades >= 1000:
            results['score'] += 6
        elif trades >= 500:
            results['score'] += 4
        elif trades >= 300:
            results['score'] += 2
        else:
            results['warnings'].append(f"Peu de trades ({trades}) - résultats moins fiables")

        # Résultat global
        results['would_pass'] = all([
            results['checks']['max_total_dd']['passed'],
            results['checks']['max_daily_dd']['passed'],
            results['checks']['profit_target']['passed'],
            results['checks']['trading_days']['passed']
        ])

        # Recommandation
        if results['would_pass'] and results['score'] >= 80:
            results['recommendation'] = "EXCELLENT - Prêt pour le challenge"
            results['confidence'] = "HIGH"
        elif results['would_pass'] and results['score'] >= 60:
            results['recommendation'] = "BON - Peut tenter le challenge avec prudence"
            results['confidence'] = "MEDIUM"
        elif results['would_pass']:
            results['recommendation'] = "PASSABLE - Risqué, amélioration recommandée"
            results['confidence'] = "LOW"
        else:
            results['recommendation'] = "NE PAS LANCER - Optimisation nécessaire"
            results['confidence'] = "NONE"

        # Calcul ROI potentiel
        if results['would_pass']:
            challenge_cost = self.profile['challenge_cost']
            potential_payout = 100000 * (profit / 100) * (self.profile['profit_split'] / 100)
            results['potential_roi'] = {
                'challenge_cost': challenge_cost,
                'potential_payout': potential_payout,
                'roi_pct': (potential_payout / challenge_cost - 1) * 100
            }

        return results

    def print_report(self, results: dict):
        """Affiche un rapport formaté"""
        print("\n" + "="*70)
        print("            PROPFIRM VALIDATION REPORT")
        print("="*70)
        print(f"\nProfile: {results['profile']}")
        print(f"Date: {results['timestamp']}")
        print(f"Notes: {self.profile['notes']}")

        print("\n" + "-"*70)
        print("RULE CHECKS")
        print("-"*70)

        # DD Total
        dd = results['checks']['max_total_dd']
        status = "✓ PASS" if dd['passed'] else "✗ FAIL"
        safe_status = "(SAFE)" if dd['safe'] else "(AT RISK)" if dd['passed'] else ""
        print(f"Max DD Total:     {dd['value']:.2f}% / {dd['limit']}% [{status}] {safe_status}")

        # DD Daily
        dd = results['checks']['max_daily_dd']
        status = "✓ PASS" if dd['passed'] else "✗ FAIL"
        safe_status = "(SAFE)" if dd['safe'] else "(AT RISK)" if dd['passed'] else ""
        print(f"Max Daily DD:     {dd['value']:.2f}% / {dd['limit']}% [{status}] {safe_status}")

        # Profit
        pt = results['checks']['profit_target']
        status = "✓ PASS" if pt['passed'] else "✗ FAIL"
        margin = f"(+{pt['margin']:.1f}%)" if pt['margin'] > 0 else f"({pt['margin']:.1f}%)"
        print(f"Profit Target:    {pt['value']:.2f}% / {pt['limit']}% [{status}] {margin}")

        # Trading Days
        td = results['checks']['trading_days']
        status = "✓ PASS" if td['passed'] else "✗ FAIL"
        print(f"Trading Days:     {td['value']} / {td['limit']} [{status}]")

        print("\n" + "-"*70)
        print("QUALITY METRICS")
        print("-"*70)
        q = results['checks']['quality']
        print(f"Profit Factor:    {q['profit_factor']:.2f}")
        print(f"Win Rate:         {q['win_rate']:.1f}%")
        print(f"Total Trades:     {q['total_trades']}")

        print("\n" + "-"*70)
        print("VALIDATION SCORE")
        print("-"*70)
        score = results['score']
        max_score = results['max_score']
        bar_length = 40
        filled = int(bar_length * score / max_score)
        bar = "█" * filled + "░" * (bar_length - filled)
        print(f"Score: [{bar}] {score}/{max_score}")

        print(f"\nConfidence: {results['confidence']}")
        print(f"Recommendation: {results['recommendation']}")

        if results['warnings']:
            print("\n⚠️  WARNINGS:")
            for w in results['warnings']:
                print(f"   - {w}")

        if results.get('potential_roi'):
            print("\n" + "-"*70)
            print("POTENTIAL ROI (if passed)")
            print("-"*70)
            roi = results['potential_roi']
            print(f"Challenge Cost:   €{roi['challenge_cost']}")
            print(f"Potential Payout: ${roi['potential_payout']:,.2f}")
            print(f"ROI:              {roi['roi_pct']:.0f}%")

        print("\n" + "="*70)
        if results['would_pass']:
            print("           ✓ CHALLENGE COULD BE PASSED")
        else:
            print("           ✗ WOULD NOT PASS - DO NOT LAUNCH")
        print("="*70 + "\n")


#==============================================================================
# COMPARATEUR MULTI-PROPFIRM
#==============================================================================

def compare_all_propfirms(metrics: dict):
    """Compare les résultats sur toutes les prop firms"""
    print("\n" + "="*80)
    print("                    MULTI-PROPFIRM COMPARISON")
    print("="*80)

    print(f"\n{'PropFirm':<25} {'DD OK':<8} {'Daily OK':<10} {'Profit OK':<12} {'Score':<8} {'Status'}")
    print("-"*80)

    results_list = []
    for profile_name in PROPFIRM_PROFILES:
        validator = PropFirmValidator(profile_name)
        results = validator.validate(metrics)

        dd_ok = "✓" if results['checks']['max_total_dd']['passed'] else "✗"
        daily_ok = "✓" if results['checks']['max_daily_dd']['passed'] else "✗"
        profit_ok = "✓" if results['checks']['profit_target']['passed'] else "✗"

        status = "PASS" if results['would_pass'] else "FAIL"
        status_color = status

        print(f"{PROPFIRM_PROFILES[profile_name]['name']:<25} {dd_ok:<8} {daily_ok:<10} {profit_ok:<12} {results['score']:<8} {status_color}")

        results_list.append({
            'profile': profile_name,
            'name': PROPFIRM_PROFILES[profile_name]['name'],
            'score': results['score'],
            'would_pass': results['would_pass'],
            'cost': PROPFIRM_PROFILES[profile_name]['challenge_cost']
        })

    # Recommandation
    print("\n" + "-"*80)
    print("RECOMMENDATION:")

    passing = [r for r in results_list if r['would_pass']]
    if passing:
        best = max(passing, key=lambda x: (x['score'], -x['cost']))
        print(f"  Best option: {best['name']} (Score: {best['score']}, Cost: €{best['cost']})")
    else:
        print("  ⚠️  No prop firm would be passed with current metrics.")
        print("  Recommendation: Optimize the strategy before launching any challenge.")

    print("="*80 + "\n")


#==============================================================================
# MAIN
#==============================================================================

def interactive_mode():
    """Mode interactif pour saisir les métriques"""
    print("\n" + "="*60)
    print("     PROPFIRM VALIDATOR - Interactive Mode")
    print("="*60)

    print("\nEntrez vos métriques de backtest:\n")

    try:
        metrics = {
            'net_profit_pct': float(input("Profit net (%): ")),
            'max_dd_pct': float(input("Max Drawdown (%): ")),
            'max_daily_dd_pct': float(input("Max Daily Drawdown (%): ")),
            'trading_days': int(input("Jours de trading: ")),
            'profit_factor': float(input("Profit Factor: ")),
            'win_rate': float(input("Win Rate (%): ")),
            'total_trades': int(input("Nombre total de trades: "))
        }

        print("\nProp firms disponibles:")
        for i, name in enumerate(PROPFIRM_PROFILES.keys()):
            print(f"  {i+1}. {PROPFIRM_PROFILES[name]['name']}")
        print(f"  0. Comparer toutes")

        choice = int(input("\nChoisir (0 pour toutes): "))

        if choice == 0:
            compare_all_propfirms(metrics)
        else:
            profile_name = list(PROPFIRM_PROFILES.keys())[choice - 1]
            validator = PropFirmValidator(profile_name)
            results = validator.validate(metrics)
            validator.print_report(results)

    except (ValueError, IndexError) as e:
        print(f"Erreur de saisie: {e}")


def demo_mode():
    """Mode démo avec des métriques exemple"""
    print("\n[DEMO MODE - Métriques simulées]\n")

    # Métriques de démonstration
    demo_metrics = {
        'net_profit_pct': 45.0,      # 45% de profit
        'max_dd_pct': 6.5,           # 6.5% max drawdown
        'max_daily_dd_pct': 3.2,     # 3.2% max daily
        'trading_days': 85,          # 85 jours de trading
        'profit_factor': 1.72,       # PF de 1.72
        'win_rate': 56.3,            # 56.3% win rate
        'total_trades': 742          # 742 trades
    }

    print("Métriques de test:")
    for k, v in demo_metrics.items():
        print(f"  {k}: {v}")

    compare_all_propfirms(demo_metrics)

    # Rapport détaillé FTMO
    validator = PropFirmValidator('FTMO')
    results = validator.validate(demo_metrics)
    validator.print_report(results)


def main():
    print("\n" + "="*60)
    print("          PROPFIRM VALIDATOR v1.0")
    print("="*60)
    print("\nOptions:")
    print("  1. Mode interactif (saisir vos métriques)")
    print("  2. Mode démo (métriques exemple)")
    print("  3. Quitter")

    try:
        choice = input("\nChoix (1/2/3): ").strip()

        if choice == '1':
            interactive_mode()
        elif choice == '2':
            demo_mode()
        else:
            print("Au revoir!")

    except KeyboardInterrupt:
        print("\n\nInterrompu.")


if __name__ == "__main__":
    main()
