# Guide de Backtesting PropFirm EA

> Guide complet pour valider votre stratégie avant de lancer un challenge

---

## Table des Matières

1. [Préparation](#1-préparation)
2. [Configuration MT5](#2-configuration-mt5)
3. [Lancer un Backtest](#3-lancer-un-backtest)
4. [Analyser les Résultats](#4-analyser-les-résultats)
5. [Critères de Validation](#5-critères-de-validation)
6. [Optimisation](#6-optimisation)
7. [Forward Test](#7-forward-test)

---

## 1. Préparation

### 1.1 Données Historiques de Qualité

**IMPORTANT**: Les données par défaut de MT5 sont insuffisantes!

```
OPTIONS POUR DONNÉES TICK:
┌────────────────────────────────────────────────────────────────┐
│ Source                  │ Qualité │ Coût      │ Période        │
├─────────────────────────┼─────────┼───────────┼────────────────┤
│ Dukascopy               │ 99%     │ Gratuit   │ 2003+          │
│ TrueFX                  │ 99%     │ Gratuit   │ 2009+          │
│ TickStory               │ 99%     │ ~$50      │ 2003+          │
│ MT5 Default             │ ~90%    │ Gratuit   │ Variable       │
└────────────────────────────────────────────────────────────────┘

RECOMMANDATION: Dukascopy ou TickStory pour backtests sérieux
```

### 1.2 Télécharger les Données

**Option A: Via MT5 (données de base)**
```
1. Outils > Options > Graphiques
2. Cocher "Unlimited bars in chart"
3. Ouvrir graphique EUR/USD M1
4. Clic droit > Rafraîchir
5. Attendre le téléchargement complet
```

**Option B: Données tick externes (recommandé)**
```
1. Télécharger depuis Dukascopy/TickStory
2. Convertir au format MT5 (.hst ou .csv)
3. Importer via Outils > Centre d'historique
```

### 1.3 Fichiers Requis

```
Avant de commencer, vérifier:
□ PropFirm_SMC_EA_v1.mq5 compilé (PropFirm_SMC_EA_v1.ex5)
□ BacktestConfig.mqh dans le dossier Include
□ BacktestAnalyzer.mq5 compilé
□ Profil .set correspondant à la prop firm ciblée
□ Données historiques 2019-2024 minimum
```

---

## 2. Configuration MT5

### 2.1 Paramètres du Strategy Tester

```
ACCÉDER AU TESTEUR:
Vue > Testeur de Stratégie (Ctrl+R)

CONFIGURATION:
┌────────────────────────────────────────────────────────────────┐
│ Paramètre          │ Valeur Recommandée                        │
├────────────────────┼───────────────────────────────────────────┤
│ Expert             │ PropFirm_SMC_EA_v1                        │
│ Symbole            │ EURUSD (ou paire cible)                   │
│ Période            │ M15 (timeframe de travail)                │
│ Date De            │ 2019.01.01                                │
│ Date À             │ 2024.12.01                                │
│ Forward            │ Non (d'abord sans)                        │
│ Délais             │ 0 ms                                      │
│ Modèle             │ Chaque tick basé sur des ticks réels      │
│ Dépôt              │ 100000                                    │
│ Devise             │ USD                                       │
│ Effet de levier    │ 1:100                                     │
│ Optimisation       │ Désactivé (pour le premier test)          │
└────────────────────────────────────────────────────────────────┘
```

### 2.2 Charger un Profil PropFirm

```
1. Cliquer sur "Paramètres de l'Expert"
2. Cliquer sur "Charger" (icône dossier)
3. Sélectionner le profil:
   - FTMO_Normal_Challenge.set
   - E8_One_Step.set
   - FundingPips_1Step.set
   - The5ers_Bootcamp.set
4. Vérifier les paramètres chargés
5. Cliquer OK
```

---

## 3. Lancer un Backtest

### 3.1 Backtest Standard (5 ans)

```
CONFIGURATION:
- Période: 2019.01.01 - 2024.12.01
- Modèle: Chaque tick basé sur des ticks réels
- Spread: 0 (variable)

COMMANDES:
1. Configurer comme ci-dessus
2. Cliquer "Démarrer"
3. Attendre la fin (peut prendre 5-30 min selon PC)
4. Analyser l'onglet "Résultats"
```

### 3.2 Tests de Stress

**Test COVID Crash (Février-Juin 2020)**
```
- Date De: 2020.02.01
- Date À: 2020.06.01
- Spread: 30 points (fixe - simuler spread élargi)
- Slippage: 30 points

OBJECTIF: Vérifier que l'EA survit aux conditions extrêmes
CRITÈRE: Max DD < 10% même en conditions de stress
```

**Test Haute Volatilité (2022)**
```
- Date De: 2022.01.01
- Date À: 2022.12.31
- Spread: 15 points
- Slippage: 20 points

OBJECTIF: Performance en période de forte volatilité Fed
```

**Test Récent (2024)**
```
- Date De: 2024.01.01
- Date À: 2024.12.01
- Spread: Variable
- Slippage: 10 points

OBJECTIF: Confirmer que la stratégie fonctionne sur données récentes
```

### 3.3 Multi-Paires (Optionnel)

```
Tester séparément sur:
□ EUR/USD (spread ~0.8-1.2 pips)
□ GBP/USD (spread ~1.0-1.5 pips)
□ USD/JPY (spread ~0.8-1.2 pips)

COMPARER:
- Win rate par paire
- Profit factor par paire
- Drawdown par paire
```

---

## 4. Analyser les Résultats

### 4.1 Métriques Clés dans MT5

```
ONGLET "RÉSULTATS":
┌────────────────────────────────────────────────────────────────┐
│ Métrique              │ Où la trouver │ Valeur cible          │
├───────────────────────┼───────────────┼───────────────────────┤
│ Profit net            │ Résumé        │ > 50% sur 5 ans       │
│ Profit factor         │ Résumé        │ > 1.5                 │
│ Recovery factor       │ Résumé        │ > 3.0                 │
│ Sharpe ratio          │ Résumé        │ > 1.0                 │
│ Drawdown max          │ Graphique     │ < 8%                  │
│ Trades                │ Résumé        │ > 500                 │
│ Win rate              │ Calculer      │ > 52%                 │
└────────────────────────────────────────────────────────────────┘
```

### 4.2 Exporter et Analyser avec Python

```bash
# 1. Exporter le rapport MT5
# Clic droit sur résultats > Exporter > HTML ou CSV

# 2. Lancer l'analyseur Python
cd C:\Users\cgemi\PropFirmEA_Project\backtests
python analyze_backtest.py

# 3. Ou charger votre propre fichier:
# Modifier le script pour pointer vers votre export
```

### 4.3 Utiliser le Script MQL5

```
DANS MT5:
1. Fichier > Ouvrir dossier de données
2. Naviguer vers MQL5/Scripts
3. Copier BacktestAnalyzer.mq5
4. Compiler
5. Exécuter sur un graphique après le backtest
6. Voir le rapport dans l'onglet "Experts"
```

### 4.4 Interpréter la Courbe d'Équité

```
BONNE COURBE:
     │    ╭──────────╮
     │   ╱            ╲╱╲_____╱╲
     │  ╱                       ╲___
     │ ╱
     │╱
     └─────────────────────────────────
     Croissance régulière, drawdowns limités

MAUVAISE COURBE:
     │       ╱╲
     │      ╱  ╲    ╱╲
     │╱╲__╱    ╲__╱  ╲___╱╲____
     │                        ╲
     └─────────────────────────────────
     Volatile, drawdowns profonds, pas de tendance
```

---

## 5. Critères de Validation

### 5.1 Checklist PropFirm

```
VALIDATION POUR FTMO $100K:

OBLIGATOIRE (si un seul échoue = STOP):
□ Max Drawdown < 10%         Résultat: ____%
□ Max Daily DD < 5%          Résultat: ____%
□ Pas de breach sur 5 ans    Résultat: ____

RECOMMANDÉ (pour robustesse):
□ Profit > 100% sur 5 ans    Résultat: ____%
□ Profit Factor > 1.5        Résultat: ____
□ Win Rate > 52%             Résultat: ____%
□ Recovery Factor > 3        Résultat: ____
□ Sharpe Ratio > 1.0         Résultat: ____
□ Max Consec Losses < 6      Résultat: ____
□ Trades > 500               Résultat: ____
□ Rentable sur 2022 (stress) Résultat: ____
□ Rentable sur 2024 (récent) Résultat: ____
```

### 5.2 Score de Confiance

```python
def calculate_confidence_score(metrics):
    score = 0
    max_score = 100

    # Profit Factor (20 points)
    if metrics['profit_factor'] >= 2.0: score += 20
    elif metrics['profit_factor'] >= 1.5: score += 15
    elif metrics['profit_factor'] >= 1.3: score += 10

    # Win Rate (15 points)
    if metrics['win_rate'] >= 60: score += 15
    elif metrics['win_rate'] >= 55: score += 12
    elif metrics['win_rate'] >= 52: score += 8

    # Max Drawdown (25 points)
    if metrics['max_dd'] <= 5: score += 25
    elif metrics['max_dd'] <= 7: score += 20
    elif metrics['max_dd'] <= 9: score += 10

    # Recovery Factor (15 points)
    if metrics['recovery_factor'] >= 5: score += 15
    elif metrics['recovery_factor'] >= 3: score += 10
    elif metrics['recovery_factor'] >= 2: score += 5

    # Sharpe Ratio (15 points)
    if metrics['sharpe'] >= 2.0: score += 15
    elif metrics['sharpe'] >= 1.5: score += 12
    elif metrics['sharpe'] >= 1.0: score += 8

    # Nombre de trades (10 points)
    if metrics['trades'] >= 1000: score += 10
    elif metrics['trades'] >= 500: score += 7
    elif metrics['trades'] >= 300: score += 4

    return score

# INTERPRÉTATION:
# 80-100: Excellent - Prêt pour challenge
# 60-79:  Bon - Peut tenter mais prudence
# 40-59:  Moyen - Optimisation recommandée
# <40:    Insuffisant - Ne pas lancer de challenge
```

---

## 6. Optimisation

### 6.1 Paramètres à Optimiser

```
OPTIMISATION GÉNÉTIQUE MT5:

Paramètres principaux:
□ RiskPercent: 0.5 - 2.0, pas 0.25
□ MaxDailyDD: 3.0 - 4.5, pas 0.5
□ MinRR: 1.2 - 2.0, pas 0.2
□ OB_Lookback: 30 - 70, pas 10

Paramètres secondaires:
□ TP1_Percent: 30 - 50, pas 5
□ TrailingATRMultiplier: 1.0 - 2.0, pas 0.25

NE PAS OPTIMISER:
- MaxTotalDD (fixé par prop firm)
- Filtres de news/session (garder activés)
```

### 6.2 Éviter l'Overfitting

```
RÈGLES ANTI-OVERFITTING:

1. SPLIT TEMPOREL:
   - In-Sample: 2019-2022 (optimisation)
   - Out-of-Sample: 2023-2024 (validation)

2. WALK-FORWARD:
   - Optimiser sur 12 mois
   - Tester sur 3 mois suivants
   - Répéter

3. MULTI-PAIRES:
   - Optimiser sur EUR/USD
   - Valider sur GBP/USD et USD/JPY
   - Si ça marche sur les 3 = robuste

4. NOMBRE DE TRADES:
   - Minimum 500 trades en backtest
   - Idéalement 1000+

5. SIMPLICITÉ:
   - Moins de paramètres = plus robuste
   - Si vous avez besoin de 20 paramètres, la stratégie est fragile
```

### 6.3 Process d'Optimisation

```
ÉTAPE 1: Test Initial
- Paramètres par défaut
- Noter les métriques de base

ÉTAPE 2: Optimisation Grossière
- Grands pas entre les valeurs
- Identifier la zone optimale

ÉTAPE 3: Optimisation Fine
- Petits pas dans la zone optimale
- Sélectionner top 5 configurations

ÉTAPE 4: Validation Out-of-Sample
- Tester les 5 configs sur 2023-2024
- Choisir celle qui performe le mieux

ÉTAPE 5: Test de Robustesse
- Tester sur autres paires
- Tester en conditions de stress
- Confirmer la stabilité
```

---

## 7. Forward Test

### 7.1 Configuration Démo

```
APRÈS VALIDATION BACKTEST:

1. Ouvrir compte démo chez broker ECN
   - IC Markets, Pepperstone, etc.
   - Même conditions que compte réel

2. Installer l'EA sur VPS
   - Latence < 20ms
   - Uptime 99.9%

3. Configurer le monitoring
   - Alertes email/SMS
   - Dashboard de suivi

4. Durée: Minimum 4-6 semaines
   - Idéalement 3 mois
   - Couvrir différentes conditions de marché
```

### 7.2 Journaling Forward Test

```markdown
## Forward Test Log

### Semaine 1 (Date: _______)
- Trades: ___
- Win Rate: ___%
- P&L: $____ (__%)
- Max DD: __%
- Notes: _______

### Semaine 2 (Date: _______)
...

### Comparaison Backtest vs Forward:
| Métrique | Backtest | Forward | Delta |
|----------|----------|---------|-------|
| Win Rate |          |         |       |
| PF       |          |         |       |
| Avg Win  |          |         |       |
| Max DD   |          |         |       |
```

### 7.3 Critères pour Passer au Réel

```
CHECKLIST AVANT CHALLENGE:

□ Forward test > 4 semaines
□ Forward win rate dans ±5% du backtest
□ Forward PF dans ±0.3 du backtest
□ Pas de drawdown > 5% en forward
□ EA stable sans crashes
□ VPS fiable (pas de déconnexions)
□ Process de monitoring en place
□ Budget challenge disponible
□ Plan de gestion émotionnelle prêt

Si TOUS les critères sont cochés → GO!
```

---

## Ressources

### Outils

```
TÉLÉCHARGEMENT DONNÉES:
- https://www.dukascopy.com/swiss/english/marketwatch/historical/
- https://www.truefx.com/
- https://tickstory.com/

ANALYSE:
- Python + Pandas + Matplotlib
- Excel pour analyses rapides

VPS:
- ForexVPS.net
- BeeksFX
- AWS/Google Cloud (avancé)
```

### Commandes Utiles

```bash
# Analyser un export MT5
python analyze_backtest.py --file rapport.csv --propfirm FTMO

# Générer rapport comparatif
python analyze_backtest.py --compare rapport1.csv rapport2.csv

# Graphiques uniquement
python analyze_backtest.py --file rapport.csv --plot-only
```

---

## Conclusion

Le backtesting est la **fondation** de votre succès en prop firm. Un backtest rigoureux vous permettra de:

1. **Valider** que la stratégie fonctionne
2. **Quantifier** les risques réels
3. **Prédire** les performances futures
4. **Éviter** de perdre de l'argent sur des challenges voués à l'échec

**Règle d'or**: Si le backtest n'est pas convaincant, ne lancez PAS de challenge.
